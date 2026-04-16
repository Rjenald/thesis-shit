"""
Huni App — Python CREPE Pitch Detection Backend
================================================
Real-time pitch detection via WebSocket.
Flutter streams PCM-16LE audio bytes → this server runs CREPE → returns Hz + confidence.

Run:
    python app.py
    OR
    uvicorn app:app --host 0.0.0.0 --port 8000
"""

import json
import struct
import numpy as np
import crepe
import resampy
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
import uvicorn

app = FastAPI(title="Huni Pitch API", version="1.0.0")

# ── Config ────────────────────────────────────────────────────────────────────
FLUTTER_SAMPLE_RATE = 44100   # Flutter records at 44100 Hz
CREPE_SAMPLE_RATE   = 16000   # CREPE expects 16000 Hz
PROCESS_EVERY_MS    = 150     # send prediction every 150ms of audio
CONFIDENCE_THRESH   = 0.5     # ignore predictions below this

# Pre-calculate buffer size
BYTES_PER_SAMPLE    = 2       # int16 = 2 bytes
PROCESS_BYTES       = int(FLUTTER_SAMPLE_RATE * (PROCESS_EVERY_MS / 1000) * BYTES_PER_SAMPLE)


# ── Health check ──────────────────────────────────────────────────────────────

@app.get("/")
async def root():
    return {"status": "running", "model": "CREPE tiny", "port": 8000}

@app.get("/health")
async def health():
    return {"status": "ok"}


# ── WebSocket pitch endpoint ──────────────────────────────────────────────────

@app.websocket("/pitch")
async def pitch_websocket(websocket: WebSocket):
    """
    Flutter connects here and streams raw PCM-16LE mono audio bytes.
    Server responds with JSON: {"frequency": 261.6, "confidence": 0.87}
    frequency = 0.0 means no pitch detected (silence or noise).
    """
    await websocket.accept()
    print(f"[WS] Client connected: {websocket.client}")

    pcm_buffer = bytearray()

    try:
        while True:
            raw = await websocket.receive_bytes()
            pcm_buffer.extend(raw)

            # Process when we have enough audio
            if len(pcm_buffer) < PROCESS_BYTES:
                continue

            chunk = bytes(pcm_buffer[:PROCESS_BYTES])
            pcm_buffer = pcm_buffer[PROCESS_BYTES:]  # consume processed bytes

            # ── 1. Decode PCM int16-LE → float32 ─────────────────────────────
            n_samples = len(chunk) // BYTES_PER_SAMPLE
            samples = np.array(
                struct.unpack(f'<{n_samples}h', chunk),
                dtype=np.float32
            ) / 32768.0

            # ── 2. Resample 44100 → 16000 Hz ─────────────────────────────────
            audio_16k = resampy.resample(samples, FLUTTER_SAMPLE_RATE, CREPE_SAMPLE_RATE)

            # ── 3. Run CREPE ──────────────────────────────────────────────────
            time_arr, freq_arr, conf_arr, _ = crepe.predict(
                audio_16k,
                CREPE_SAMPLE_RATE,
                model_capacity='tiny',
                viterbi=False,
                verbose=0,
                step_size=10,
            )

            # ── 4. Pick the best (highest confidence) frame ───────────────────
            if len(conf_arr) > 0:
                best_idx = int(np.argmax(conf_arr))
                best_conf = float(conf_arr[best_idx])
                best_freq = float(freq_arr[best_idx]) if best_conf >= CONFIDENCE_THRESH else 0.0
            else:
                best_conf = 0.0
                best_freq = 0.0

            # ── 5. Send result back to Flutter ────────────────────────────────
            result = json.dumps({"frequency": best_freq, "confidence": best_conf})
            await websocket.send_text(result)

    except WebSocketDisconnect:
        print(f"[WS] Client disconnected: {websocket.client}")
    except Exception as e:
        print(f"[WS] Error: {e}")


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("=" * 50)
    print("  Huni Pitch Detection Server")
    print("  CREPE model: tiny")
    print("  URL: ws://0.0.0.0:8000/pitch")
    print("  Health: http://0.0.0.0:8000/health")
    print("=" * 50)
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
