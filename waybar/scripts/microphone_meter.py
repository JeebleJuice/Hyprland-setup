#!/usr/bin/env python3
"""Stream the default microphone's level to Waybar as a vertical fill meter."""

from __future__ import annotations

import array
import json
import math
import signal
import subprocess
import sys
import time
from collections import deque


SAMPLE_RATE = 8000
UPDATE_SECONDS = 0.20
SAMPLES_PER_UPDATE = int(SAMPLE_RATE * UPDATE_SECONDS)
BYTES_PER_UPDATE = SAMPLES_PER_UPDATE * 2

recorder: subprocess.Popen[bytes] | None = None
running = True


def run_pactl(*arguments: str) -> str:
    try:
        return subprocess.run(
            ["pactl", *arguments],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=1.5,
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def source_state() -> tuple[str, bool, str]:
    source = run_pactl("get-default-source")
    if not source:
        return "", False, ""

    muted = run_pactl("get-source-mute", source).endswith("yes")
    volume_output = run_pactl("get-source-volume", source)
    volume = "?"
    for word in volume_output.split():
        if word.endswith("%") and word[:-1].isdigit():
            volume = word
            break
    return source, muted, volume


def emit(text: str, tooltip: str, css_class: str) -> None:
    print(
        json.dumps({"text": text, "tooltip": tooltip, "class": css_class}),
        flush=True,
    )


def stop_recorder() -> None:
    global recorder
    if recorder is not None:
        recorder.terminate()
        try:
            recorder.wait(timeout=0.5)
        except subprocess.TimeoutExpired:
            recorder.kill()
        recorder = None


def handle_exit(_signum: int, _frame: object) -> None:
    global running
    running = False
    stop_recorder()


def start_recorder(source: str) -> bool:
    global recorder
    stop_recorder()
    try:
        recorder = subprocess.Popen(
            [
                "parec",
                f"--device={source}",
                "--raw",
                "--format=s16le",
                "--channels=1",
                f"--rate={SAMPLE_RATE}",
                "--latency-msec=50",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        return True
    except OSError:
        recorder = None
        return False


def audio_dbfs(raw_audio: bytes) -> float:
    samples = array.array("h")
    samples.frombytes(raw_audio)
    if sys.byteorder != "little":
        samples.byteswap()
    if not samples:
        return -96.0

    rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples))
    return 20.0 * math.log10(max(rms, 1.0) / 32768.0)


signal.signal(signal.SIGTERM, handle_exit)
signal.signal(signal.SIGINT, handle_exit)

noise_samples: deque[float] = deque(maxlen=50)
display_level = 0.0
active_source = ""
last_state_check = 0.0
muted = False
volume = "?"
last_emitted_class = ""
last_level_emit = 0.0

while running:
    now = time.monotonic()
    if now - last_state_check >= 0.5:
        source, muted, volume = source_state()
        last_state_check = now

        if not source:
            stop_recorder()
            active_source = ""
            emit("󰍭", "No microphone is available", "unavailable")
            time.sleep(0.5)
            continue

        if muted:
            stop_recorder()
            active_source = source
            noise_samples.clear()
            display_level = 0.0
            # This matched Material Design pair retains the diagonal mute line
            # without shifting the microphone body between states.
            emit("󰍭", f"Microphone muted · {volume}\n{source}", "muted")
            time.sleep(0.25)
            continue

        if recorder is None or recorder.poll() is not None or source != active_source:
            active_source = source
            noise_samples.clear()
            display_level = 0.0
            if not start_recorder(source):
                emit("󰍭", "Could not monitor the microphone", "unavailable")
                time.sleep(1.0)
                continue

    if recorder is None or recorder.stdout is None:
        time.sleep(0.1)
        continue

    raw_audio = recorder.stdout.read(BYTES_PER_UPDATE)
    if len(raw_audio) != BYTES_PER_UPDATE:
        stop_recorder()
        time.sleep(0.2)
        continue

    measured_dbfs = audio_dbfs(raw_audio)
    noise_samples.append(measured_dbfs)
    ordered_noise = sorted(noise_samples)
    noise_floor = ordered_noise[max(0, len(ordered_noise) // 5 - 1)]

    # Ignore the first 2 dB above the rolling room/device noise floor; another
    # 16 dB fills the capsule. Decay smooths the visible meter.
    raw_level = max(0.0, min(1.0, (measured_dbfs - noise_floor - 2.0) / 16.0))
    display_level = max(raw_level, display_level * 0.70)
    css_class = f"level-{round(display_level * 10)}"

    # Repaint immediately for a visible meter-step change, but avoid making
    # Waybar redraw for every insignificant dB fluctuation.
    emit_now = time.monotonic()
    if css_class != last_emitted_class or emit_now - last_level_emit >= 1.0:
        emit(
            "󰍬",
            f"Microphone input · {volume} · {measured_dbfs:.1f} dBFS\n{active_source}\nLeft-click to mute · Scroll to adjust",
            css_class,
        )
        last_emitted_class = css_class
        last_level_emit = emit_now

stop_recorder()
