"""
Huni App — CREPE Pitch Detection Backend  (crepe_server.py)
============================================================
<<<<<<< HEAD
Real-time pitch detection over WebSocket using CREPE full model.

Endpoints
---------
  WS  ws://0.0.0.0:8000/pitch    — stream PCM-16LE bytes, receive JSON frames
  GET http://0.0.0.0:8000/health — liveness check
=======
Real-time pitch detection over WebSocket with full note/cents output.

Endpoints
---------
  WS  ws://0.0.0.0:8000/ws/pitch   — stream PCM-16LE bytes, receive JSON frames
  GET http://0.0.0.0:8000/health   — liveness check
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f

JSON response per audio chunk
------------------------------
  {"frequency": 440.0, "confidence": 0.95, "note": "A4", "cents": -5.2}

<<<<<<< HEAD
=======
  frequency  : detected pitch in Hz  (0.0 = no pitch / silence)
  confidence : CREPE confidence 0.0–1.0
  note       : nearest note name e.g. "A4"  (empty string when frequency == 0)
  cents      : deviation from nearest note in cents  (0.0 when frequency == 0)

>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
Audio format expected from Flutter
------------------------------------
  Encoding : PCM 16-bit signed little-endian (pcm16bits)
  Channels : 1 (mono)
  Sample rate : 44 100 Hz

<<<<<<< HEAD
Model
-----
  Uses CREPE full model (22M parameters) for highest accuracy.
  Looks for ./crepe_full_best.keras — falls back to built-in full model.
=======
Model loading
-------------
  1. Looks for CREPE_MODEL_PATH env var (or ./crepe_tiny_best.keras by default).
  2. If that file exists the weights are loaded into a CREPE tiny network.
  3. If the file is missing CREPE's own built-in tiny model weights are used.
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f

Run
---
  python crepe_server.py
<<<<<<< HEAD
=======
  uvicorn crepe_server:app --host 0.0.0.0 --port 8000
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
"""

from __future__ import annotations

import json
import logging
import math
import os
import struct
import sys
from contextlib import asynccontextmanager
<<<<<<< HEAD
=======
from typing import Optional
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f

import crepe
import numpy as np
import resampy
import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

# ── Logging ───────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("crepe_server")

<<<<<<< HEAD
# ── Config ────────────────────────────────────────────────────────────────────

FLUTTER_SAMPLE_RATE: int = int(os.getenv("FLUTTER_SAMPLE_RATE", "44100"))
CREPE_SAMPLE_RATE: int = 16_000
PROCESS_EVERY_MS: int = int(os.getenv("PROCESS_EVERY_MS", "150"))
CONFIDENCE_THRESH: float = float(os.getenv("CONFIDENCE_THRESH", "0.50"))
CREPE_MODEL_PATH: str = os.getenv("CREPE_MODEL_PATH", "./crepe_full_best.keras")
=======
# ── Config (override via environment variables) ────────────────────────────────

FLUTTER_SAMPLE_RATE: int = int(os.getenv("FLUTTER_SAMPLE_RATE", "44100"))
CREPE_SAMPLE_RATE: int = 16_000          # CREPE always expects 16 kHz
PROCESS_EVERY_MS: int = int(os.getenv("PROCESS_EVERY_MS", "150"))
CONFIDENCE_THRESH: float = float(os.getenv("CONFIDENCE_THRESH", "0.50"))
CREPE_MODEL_PATH: str = os.getenv("CREPE_MODEL_PATH", "./crepe_tiny_best.keras")
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
CREPE_STEP_SIZE: int = int(os.getenv("CREPE_STEP_SIZE", "10"))
HOST: str = os.getenv("HOST", "0.0.0.0")
PORT: int = int(os.getenv("PORT", "8000"))

<<<<<<< HEAD
BYTES_PER_SAMPLE: int = 2
PROCESS_BYTES: int = int(
    FLUTTER_SAMPLE_RATE * (PROCESS_EVERY_MS / 1000) * BYTES_PER_SAMPLE
)

# ── Note utilities ─────────────────────────────────────────────────────────────

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


# ── Model loading ──────────────────────────────────────────────────────────────

class _ModelState:
    loaded: bool = False
    model_label: str = "crepe-full (built-in)"
=======
# Derived constants
BYTES_PER_SAMPLE: int = 2  # int16 LE
PROCESS_BYTES: int = int(FLUTTER_SAMPLE_RATE * (PROCESS_EVERY_MS / 1000) * BYTES_PER_SAMPLE)

# ── Note utilities ─────────────────────────────────────────────────────────────

_NOTE_NAMES: list[str] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
_A4_HZ: float = 440.0
_A4_MIDI: int = 69


def hz_to_note_and_cents(frequency: float) -> tuple[str, float]:
    """Return (note_name, cents_deviation) for a given frequency in Hz.

    Returns ("", 0.0) for non-positive frequencies.
    Cents are in the range (-50, +50].
    """
    if frequency <= 0.0:
        return "", 0.0

    # MIDI note number (floating point)
    midi_float = 12.0 * math.log2(frequency / _A4_HZ) + _A4_MIDI

    # Nearest semitone
    nearest_midi = round(midi_float)
    cents = (midi_float - nearest_midi) * 100.0

    # Clamp to valid MIDI range (0–127)
    nearest_midi = max(0, min(127, nearest_midi))
    octave = (nearest_midi // 12) - 1
    note_idx = nearest_midi % 12
    note_name = f"{_NOTE_NAMES[note_idx]}{octave}"

    return note_name, round(cents, 2)


# ── Model state ───────────────────────────────────────────────────────────────

class _ModelState:
    """Holds the loaded CREPE model and tracks which source was used."""

    loaded: bool = False
    custom_weights: bool = False
    model_label: str = "crepe-tiny (built-in)"

    # CREPE stores its model graph in a module-level variable after the first
    # call to crepe.build_and_load_model().  We trigger that eagerly at startup
    # so the first WebSocket frame is not slow.
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f


_model_state = _ModelState()


def _load_model() -> None:
<<<<<<< HEAD
    custom_path = os.path.abspath(CREPE_MODEL_PATH)
    if os.path.isfile(custom_path):
        log.info("Loading CREPE full model weights from: %s", custom_path)
        try:
            model = crepe.core.build_and_load_model("full")
            try:
                model.load_weights(custom_path)
                _model_state.model_label = f"crepe-full (custom: {os.path.basename(custom_path)})"
                log.info("Custom weights loaded successfully.")
            except Exception:
                log.warning("Weight file incompatible — using built-in weights.")
                crepe.core.build_and_load_model("full")
                _model_state.model_label = "crepe-full (built-in)"
        except Exception as exc:
            log.warning("Failed (%s) — using built-in full model.", exc)
            crepe.core.build_and_load_model("full")
            _model_state.model_label = "crepe-full (built-in)"
    else:
        log.info("No custom weights found — downloading built-in CREPE full model...")
        crepe.core.build_and_load_model("full")
        _model_state.model_label = "crepe-full (built-in)"
=======
    """Pre-load the CREPE tiny model at startup."""
    custom_path = os.path.abspath(CREPE_MODEL_PATH)
    if os.path.isfile(custom_path):
        log.info("Loading custom CREPE weights from: %s", custom_path)
        try:
            # CREPE exposes build_and_load_model for capacity selection.
            # After loading we override the weights from the custom file.
            model = crepe.build_and_load_model("tiny")
            model.load_weights(custom_path)
            _model_state.custom_weights = True
            _model_state.model_label = f"crepe-tiny (custom: {os.path.basename(custom_path)})"
            log.info("Custom weights loaded successfully.")
        except Exception as exc:
            log.warning(
                "Failed to load custom weights (%s). Falling back to built-in tiny model.", exc
            )
            _load_builtin_model()
    else:
        log.info(
            "Custom model not found at '%s'. Using built-in CREPE tiny model.", custom_path
        )
        _load_builtin_model()
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f

    _model_state.loaded = True
    log.info("CREPE model ready: %s", _model_state.model_label)


<<<<<<< HEAD
=======
def _load_builtin_model() -> None:
    """Force-load the built-in CREPE tiny weights."""
    try:
        crepe.build_and_load_model("tiny")
        _model_state.custom_weights = False
        _model_state.model_label = "crepe-tiny (built-in)"
    except Exception as exc:
        log.error("CREPE model failed to load: %s", exc)
        raise


>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
# ── Lifespan ──────────────────────────────────────────────────────────────────

@asynccontextmanager
async def _lifespan(application: FastAPI):
<<<<<<< HEAD
=======
    """Startup / shutdown lifecycle hook."""
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
    log.info("=" * 55)
    log.info("  Huni CREPE Pitch Detection Server")
    log.info("  WebSocket : ws://%s:%d/pitch", HOST, PORT)
    log.info("  Health    : http://%s:%d/health", HOST, PORT)
<<<<<<< HEAD
    log.info("  Model     : CREPE Full (22M parameters)")
    log.info("=" * 55)
    try:
        _load_model()
    except Exception as exc:
        log.critical("Cannot start — CREPE failed to load: %s", exc)
        sys.exit(1)
    yield
    log.info("Server shutting down.")


# ── FastAPI ───────────────────────────────────────────────────────────────────

app = FastAPI(
    title="Huni CREPE Pitch API",
    version="4.0.0",
    lifespan=_lifespan,
)

=======
    log.info("  Model path: %s", os.path.abspath(CREPE_MODEL_PATH))
    log.info("=" * 55)

    try:
        _load_model()
    except Exception as exc:
        log.critical("Cannot start server — CREPE failed to initialise: %s", exc)
        sys.exit(1)

    yield  # --- server is running ---

    log.info("Server shutting down.")


# ── FastAPI application ────────────────────────────────────────────────────────

app = FastAPI(
    title="Huni CREPE Pitch API",
    version="2.0.0",
    description="Real-time pitch detection backend for the Huni vocal training app.",
    lifespan=_lifespan,
)

# Allow all origins so the Flutter app (any IP) can reach the server.
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


<<<<<<< HEAD
@app.get("/health")
async def health():
    return {"status": "ok", "model": _model_state.model_label}
=======
# ── REST endpoints ─────────────────────────────────────────────────────────────

@app.get("/")
async def root():
    return {
        "service": "Huni CREPE Pitch Detection Server",
        "version": "2.0.0",
        "websocket": f"ws://{HOST}:{PORT}/ws/pitch",
        "health": f"http://{HOST}:{PORT}/health",
        "model": _model_state.model_label,
    }


@app.get("/health")
async def health():
    """Liveness probe.  Flutter calls this to decide whether to use the server."""
    return {
        "status": "ok",
        "model": _model_state.model_label,
    }
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f


# ── WebSocket pitch endpoint ───────────────────────────────────────────────────

@app.websocket("/pitch")
async def pitch_websocket(websocket: WebSocket):
<<<<<<< HEAD
    client_id = (
        f"{websocket.client.host}:{websocket.client.port}"
        if websocket.client else "unknown"
    )
    await websocket.accept()
    log.info("[WS] Client connected — %s", client_id)
=======
    """
    Accept raw PCM-16LE mono 44100 Hz bytes from Flutter.
    Respond with JSON pitch frames:
        {"frequency": 440.0, "confidence": 0.95, "note": "A4", "cents": -5.2}
    """
    client_id = f"{websocket.client.host}:{websocket.client.port}" if websocket.client else "unknown"
    await websocket.accept()
    log.info("[WS] Client connected  — %s", client_id)
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f

    pcm_buffer = bytearray()

    try:
        while True:
<<<<<<< HEAD
=======
            # ── Receive raw bytes from Flutter ────────────────────────────────
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
            raw: bytes = await websocket.receive_bytes()
            if not raw:
                continue
            pcm_buffer.extend(raw)

<<<<<<< HEAD
            if len(pcm_buffer) < PROCESS_BYTES:
                continue

            chunk = bytes(pcm_buffer[:PROCESS_BYTES])
            pcm_buffer = pcm_buffer[PROCESS_BYTES:]

            # 1. PCM int16-LE → float32
            n_samples = len(chunk) // BYTES_PER_SAMPLE
            if n_samples == 0:
                continue
            samples = np.array(
                struct.unpack(f"<{n_samples}h", chunk), dtype=np.float32
            ) / 32768.0

            # 2. Resample 44100 → 16000 Hz
            audio_16k = resampy.resample(
                samples, FLUTTER_SAMPLE_RATE, CREPE_SAMPLE_RATE
            )

            # 3. CREPE full model pitch prediction
=======
            # Wait until we have a full processing chunk
            if len(pcm_buffer) < PROCESS_BYTES:
                continue

            # Consume exactly one chunk
            chunk = bytes(pcm_buffer[:PROCESS_BYTES])
            pcm_buffer = pcm_buffer[PROCESS_BYTES:]

            # ── 1. Decode PCM int16-LE → float32 [-1, 1] ─────────────────────
            n_samples = len(chunk) // BYTES_PER_SAMPLE
            if n_samples == 0:
                continue
            samples: np.ndarray = np.array(
                struct.unpack(f"<{n_samples}h", chunk),
                dtype=np.float32,
            ) / 32768.0

            # ── 2. Resample 44100 Hz → 16000 Hz ──────────────────────────────
            audio_16k: np.ndarray = resampy.resample(
                samples, FLUTTER_SAMPLE_RATE, CREPE_SAMPLE_RATE
            )

            # ── 3. Run CREPE pitch estimation ─────────────────────────────────
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
            try:
                _time_arr, freq_arr, conf_arr, _activation = crepe.predict(
                    audio_16k,
                    CREPE_SAMPLE_RATE,
<<<<<<< HEAD
                    model_capacity="full",
=======
                    model_capacity="tiny",
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
                    viterbi=False,
                    verbose=0,
                    step_size=CREPE_STEP_SIZE,
                )
            except Exception as exc:
                log.warning("[WS] CREPE predict error: %s", exc)
                await _send_silence(websocket)
                continue

<<<<<<< HEAD
            # 4. Best frame
            if len(conf_arr) > 0:
                best_idx = int(np.argmax(conf_arr))
                best_conf = float(conf_arr[best_idx])
                best_freq = (
                    float(freq_arr[best_idx])
                    if best_conf >= CONFIDENCE_THRESH else 0.0
                )
=======
            # ── 4. Pick highest-confidence frame ─────────────────────────────
            if len(conf_arr) > 0:
                best_idx = int(np.argmax(conf_arr))
                best_conf = float(conf_arr[best_idx])
                best_freq = float(freq_arr[best_idx]) if best_conf >= CONFIDENCE_THRESH else 0.0
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
            else:
                best_conf = 0.0
                best_freq = 0.0

<<<<<<< HEAD
            # 5. Note + cents
            note, cents = hz_to_note_and_cents(best_freq)

            # 6. Send to Flutter
            await websocket.send_text(json.dumps({
                "frequency": round(best_freq, 4),
                "confidence": round(best_conf, 4),
                "note": note,
                "cents": cents,
            }))
=======
            # ── 5. Derive note name & cents deviation ─────────────────────────
            note, cents = hz_to_note_and_cents(best_freq)

            # ── 6. Send JSON result to Flutter ────────────────────────────────
            result = json.dumps(
                {
                    "frequency": round(best_freq, 4),
                    "confidence": round(best_conf, 4),
                    "note": note,
                    "cents": cents,
                }
            )
            await websocket.send_text(result)
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f

    except WebSocketDisconnect:
        log.info("[WS] Client disconnected — %s", client_id)
    except Exception as exc:
<<<<<<< HEAD
        log.error("[WS] Error: %s", exc, exc_info=True)
        try:
            await websocket.close(code=1011)
=======
        log.error("[WS] Unexpected error for client %s: %s", client_id, exc, exc_info=True)
        try:
            await websocket.close(code=1011, reason="Internal server error")
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
        except Exception:
            pass


async def _send_silence(websocket: WebSocket) -> None:
<<<<<<< HEAD
=======
    """Send a zero-frequency frame (silence/error fallback)."""
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
    try:
        await websocket.send_text(
            json.dumps({"frequency": 0.0, "confidence": 0.0, "note": "", "cents": 0.0})
        )
    except Exception:
        pass


<<<<<<< HEAD
if __name__ == "__main__":
    uvicorn.run("crepe_server:app", host=HOST, port=PORT, log_level="info", reload=False)
=======
# ── Entry point ────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    uvicorn.run(
        "crepe_server:app",
        host=HOST,
        port=PORT,
        log_level="info",
        # reload=False intentional — model is loaded once at startup
        reload=False,
    )
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
