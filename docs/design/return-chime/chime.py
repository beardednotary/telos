"""Renders assets/music/return-chime.wav: the sound of a squad coming home.

Two struck bell tones a fifth apart, the second answering the first. Made
here rather than licensed, so there is no credit to carry and it can be
retuned by editing a number.

    python docs/design/return-chime/chime.py
"""
import wave
from pathlib import Path

import numpy as np

RATE = 44100
LENGTH = 2.2  # seconds, including the tail

# Partials of a small bell: (ratio to the strike note, level, decay seconds).
# The slightly stretched upper ratios are what make it a bell, not an organ.
PARTIALS = [
    (0.5, 0.18, 1.6),  # hum, an octave under
    (1.0, 1.00, 1.2),
    (2.0, 0.34, 0.7),
    (2.76, 0.16, 0.45),
    (4.07, 0.07, 0.3),
]


def strike(freq: float, start: float, level: float) -> np.ndarray:
    t = np.arange(int(RATE * LENGTH)) / RATE - start
    out = np.zeros_like(t)
    on = t >= 0
    for ratio, amp, decay in PARTIALS:
        out[on] += amp * np.sin(2 * np.pi * freq * ratio * t[on]) * np.exp(
            -t[on] / decay)
    # A 6 ms attack, so the strike is soft rather than a click.
    out[on] *= np.minimum(t[on] / 0.006, 1)
    return out * level


def main() -> None:
    # C# and G#, the root and fifth of the camp track's C# minor, low enough
    # to sit with it rather than ring over it.
    cs4, gs4 = 277.18, 415.30
    sound = strike(cs4, 0.0, 1.0) + strike(gs4, 0.16, 0.8)
    # A short room: two quiet echoes, so it does not end dry.
    for delay, gain in ((0.043, 0.22), (0.089, 0.12)):
        n = int(RATE * delay)
        sound[n:] += gain * sound[:-n]
    # Fade the last 300 ms to true silence.
    tail = int(RATE * 0.3)
    sound[-tail:] *= np.linspace(1, 0, tail) ** 2
    sound *= 0.7 / np.abs(sound).max()  # headroom; the app sets the volume

    out = Path(__file__).resolve().parents[3] / 'assets/music/return-chime.wav'
    with wave.open(str(out), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((sound * 32767).astype('<i2').tobytes())
    print(out, out.stat().st_size, 'bytes')


if __name__ == '__main__':
    main()
