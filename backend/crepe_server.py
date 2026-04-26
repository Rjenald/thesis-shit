"""
Huni App - CREPE Pitch Detection Backend  (crepe_server.py)
============================================================
Real-time pitch detection over WebSocket using CREPE full model.

Endpoints
---------
  WS  ws://0.0.0.0:8000/pitch    - stream PCM-16LE bytes, receive JSON frames
  GET http://0.0.0.0:8000/health - liveness check

JSON response per audio chunk
------------------------------
  {"frequency": 440.0, "confidence": 0.95, "note": "A4", "cents": -5.2}

Audio format expected from Flutter
------------------------------------
  Encoding    : PCM 16-bit signed little-endian (pcm16bits)
  Channels    : 1 (mono)
  Sample rate : 44 100 Hz

Model
-----
  Uses CREPE full model (22M parameters) for highest accuracy.
  Looks for ./crepe_full_best.keras - falls back to built-in full model.

Run
---
  python crepe_server.py
"""

from __future__ import annotations

import json
import logging
import math
import os
import re
import struct
import sys
from contextlib import asynccontextmanager
from pathlib import Path

import crepe
import numpy as np
import resampy
import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

# ── Logging ──────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("crepe_server")

# ── Config ────────────────────────────────────────────────────────────────────

FLUTTER_SAMPLE_RATE: int = int(os.getenv("FLUTTER_SAMPLE_RATE", "44100"))
CREPE_SAMPLE_RATE: int = 16_000
PROCESS_EVERY_MS: int = int(os.getenv("PROCESS_EVERY_MS", "150"))
CONFIDENCE_THRESH: float = float(os.getenv("CONFIDENCE_THRESH", "0.50"))
CREPE_MODEL_PATH: str = os.getenv("CREPE_MODEL_PATH", "./crepe_full_best.keras")
CREPE_STEP_SIZE: int = int(os.getenv("CREPE_STEP_SIZE", "10"))
HOST: str = os.getenv("HOST", "0.0.0.0")
PORT: int = int(os.getenv("PORT", "8000"))

BYTES_PER_SAMPLE: int = 2
PROCESS_BYTES: int = int(
    FLUTTER_SAMPLE_RATE * (PROCESS_EVERY_MS / 1000) * BYTES_PER_SAMPLE
)

# ── Note utilities ────────────────────────────────────────────────────────────

_NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
_A4_HZ = 440.0
_A4_MIDI = 69


def hz_to_note_and_cents(frequency: float) -> tuple[str, float]:
    if frequency <= 0.0:
        return "", 0.0
    midi_float = 12.0 * math.log2(frequency / _A4_HZ) + _A4_MIDI
    nearest_midi = round(midi_float)
    cents = (midi_float - nearest_midi) * 100.0
    nearest_midi = max(0, min(127, nearest_midi))
    octave = (nearest_midi // 12) - 1
    note_name = f"{_NOTE_NAMES[nearest_midi % 12]}{octave}"
    return note_name, round(cents, 2)


# ── Model loading ─────────────────────────────────────────────────────────────

class _ModelState:
    loaded: bool = False
    model_label: str = "crepe-full (built-in)"


_model_state = _ModelState()


def _load_model() -> None:
    custom_path = os.path.abspath(CREPE_MODEL_PATH)
    if os.path.isfile(custom_path):
        log.info("Loading CREPE full model weights from: %s", custom_path)
        try:
            model = crepe.core.build_and_load_model("full")
            try:
                model.load_weights(custom_path)
                _model_state.model_label = (
                    f"crepe-full (custom: {os.path.basename(custom_path)})"
                )
                log.info("Custom weights loaded successfully.")
            except Exception:
                log.warning("Weight file incompatible - using built-in weights.")
                crepe.core.build_and_load_model("full")
                _model_state.model_label = "crepe-full (built-in)"
        except Exception as exc:
            log.warning("Failed (%s) - using built-in full model.", exc)
            crepe.core.build_and_load_model("full")
            _model_state.model_label = "crepe-full (built-in)"
    else:
        log.info("No custom weights found - loading built-in CREPE full model...")
        crepe.core.build_and_load_model("full")
        _model_state.model_label = "crepe-full (built-in)"

    _model_state.loaded = True
    log.info("CREPE model ready: %s", _model_state.model_label)


# ── Lifespan ──────────────────────────────────────────────────────────────────

@asynccontextmanager
async def _lifespan(application: FastAPI):
    log.info("=" * 55)
    log.info("  Huni CREPE Pitch Detection Server")
    log.info("  WebSocket : ws://%s:%d/pitch", HOST, PORT)
    log.info("  Health    : http://%s:%d/health", HOST, PORT)
    log.info("  Model     : CREPE Full (22M parameters)")
    log.info("=" * 55)
    try:
        _load_model()
    except Exception as exc:
        log.critical("Cannot start - CREPE failed to load: %s", exc)
        sys.exit(1)
    yield
    log.info("Server shutting down.")


# ── FastAPI ───────────────────────────────────────────────────────────────────

app = FastAPI(
    title="Huni CREPE Pitch API",
    version="4.0.0",
    lifespan=_lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health():
    return {"status": "ok", "model": _model_state.model_label}


# ── Songs catalog ─────────────────────────────────────────────────────────────

# Path to Flutter songs_data.dart  (two levels up from backend/)
_SONGS_DART = Path(__file__).parent.parent / "lib" / "data" / "songs_data.dart"
_songs_cache: list[dict] | None = None


def _load_songs_catalog() -> list[dict]:
    """Parse songs_data.dart and return a list of song dicts."""
    global _songs_cache
    if _songs_cache is not None:
        return _songs_cache

    try:
        source = _SONGS_DART.read_text(encoding="utf-8")
        # Match every map literal in kAllSongs — handles escaped apostrophes
        pattern = (
            r"\{'title':\s*'((?:[^'\\]|\\.)*)',\s*"
            r"'artist':\s*'((?:[^'\\]|\\.)*)',\s*"
            r"'image':\s*'((?:[^'\\]|\\.)*)',\s*"
            r"'language':\s*'((?:[^'\\]|\\.)*)'\}"
        )
        matches = re.findall(pattern, source)
        _songs_cache = [
            {
                "title":    m[0].replace("\\'", "'"),
                "artist":   m[1].replace("\\'", "'"),
                "image":    m[2],
                "language": m[3],
            }
            for m in matches
        ]
        log.info("Songs catalog loaded: %d songs from songs_data.dart", len(_songs_cache))
    except Exception as exc:
        log.warning("Could not load songs_data.dart: %s — returning empty catalog", exc)
        _songs_cache = []

    return _songs_cache


@app.get("/songs")
async def get_songs(language: str | None = None):
    """
    Return the full OPM song catalog.

    Optional query param: ?language=Tagalog  or  ?language=Bisaya
    """
    catalog = _load_songs_catalog()
    if language:
        catalog = [s for s in catalog if s["language"].lower() == language.lower()]
    return {"songs": catalog, "count": len(catalog)}


# ── WebSocket pitch endpoint ──────────────────────────────────────────────────

@app.websocket("/pitch")
async def pitch_websocket(websocket: WebSocket):
    client_id = (
        f"{websocket.client.host}:{websocket.client.port}"
        if websocket.client else "unknown"
    )
    await websocket.accept()
    log.info("[WS] Client connected - %s", client_id)

    pcm_buffer = bytearray()

    try:
        while True:
            raw: bytes = await websocket.receive_bytes()
            if not raw:
                continue
            pcm_buffer.extend(raw)

            if len(pcm_buffer) < PROCESS_BYTES:
                continue

            chunk = bytes(pcm_buffer[:PROCESS_BYTES])
            pcm_buffer = pcm_buffer[PROCESS_BYTES:]

            # 1. PCM int16-LE -> float32
            n_samples = len(chunk) // BYTES_PER_SAMPLE
            if n_samples == 0:
                continue
            samples = np.array(
                struct.unpack(f"<{n_samples}h", chunk), dtype=np.float32
            ) / 32768.0

            # 2. Resample 44100 -> 16000 Hz
            audio_16k = resampy.resample(
                samples, FLUTTER_SAMPLE_RATE, CREPE_SAMPLE_RATE
            )

            # 3. CREPE full model pitch prediction
            try:
                _time_arr, freq_arr, conf_arr, _activation = crepe.predict(
                    audio_16k,
                    CREPE_SAMPLE_RATE,
                    model_capacity="full",
                    viterbi=False,
                    verbose=0,
                    step_size=CREPE_STEP_SIZE,
                )
            except Exception as exc:
                log.warning("[WS] CREPE predict error: %s", exc)
                await _send_silence(websocket)
                continue

            # 4. Best frame
            if len(conf_arr) > 0:
                best_idx = int(np.argmax(conf_arr))
                best_conf = float(conf_arr[best_idx])
                best_freq = (
                    float(freq_arr[best_idx])
                    if best_conf >= CONFIDENCE_THRESH else 0.0
                )
            else:
                best_conf = 0.0
                best_freq = 0.0

            # 5. Note + cents
            note, cents = hz_to_note_and_cents(best_freq)

            # 6. Send to Flutter
            await websocket.send_text(json.dumps({
                "frequency": round(best_freq, 4),
                "confidence": round(best_conf, 4),
                "note": note,
                "cents": cents,
            }))

    except WebSocketDisconnect:
        log.info("[WS] Client disconnected - %s", client_id)
    except Exception as exc:
        log.error("[WS] Error: %s", exc, exc_info=True)
        try:
            await websocket.close(code=1011)
        except Exception:
            pass


async def _send_silence(websocket: WebSocket) -> None:
    try:
        await websocket.send_text(
            json.dumps({"frequency": 0.0, "confidence": 0.0, "note": "", "cents": 0.0})
        )
    except Exception:
        pass


if __name__ == "__main__":
    uvicorn.run("crepe_server:app", host=HOST, port=PORT, log_level="info", reload=False)
