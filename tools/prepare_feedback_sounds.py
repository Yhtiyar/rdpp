"""Deterministic, quiet bundled feedback cues; no network or runtime synthesis."""
import math
from pathlib import Path
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / 'assets/sounds'
# A short confirmation, warm clue, reward phrase, keepsake, and time-ready phrase.
CUES = {
    'correct': [(659.25, .10), (880, .12)],
    'retry': [(392, .12), (440, .14)],
    'batchComplete': [(523.25, .15), (659.25, .15), (783.99, .15), (1046.5, .25)],
    'milestone': [(523.25, .14), (783.99, .14), (1046.5, .20), (1318.5, .30)],
    'timeReady': [(880, .12), (659.25, .12), (1046.5, .26)],
}
for name, notes in CUES.items():
    rate = 22050
    samples = []
    for freq, duration in notes:
        for i in range(round(rate * duration)):
            t = i / rate
            envelope = min(1, t / .012) * max(0, 1 - t / duration) ** 2
            value = .18 * envelope * (math.sin(2 * math.pi * freq * t) + .12 * math.sin(4 * math.pi * freq * t))
            samples.append(struct.pack('<h', round(value * 32767)))
    with wave.open(str(ROOT / f'{name}.wav'), 'w') as output:
        output.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        output.writeframes(b''.join(samples))
