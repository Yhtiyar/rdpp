"""Render LittleWins' original playful, bubbly UI sounds entirely offline.

Requires Python 3 + NumPy (only at authoring time). No samples, soundfonts,
paid APIs, or runtime synthesis. Run from anywhere:
    python3 tools/prepare_feedback_sounds.py

The palette combines elastic synth gestures, rounded liquid pops, airy
build-ups, and sustained harmonic rewards. Each celebration has a pickup,
an impact, and an answering phrase. Every cue starts with tactile feedback.
"""

import argparse
from pathlib import Path
import wave

import numpy as np


RATE = 48000
ROOT = Path(__file__).resolve().parents[1]
TAU = 2 * np.pi


def timeline(seconds):
    return np.arange(round(seconds * RATE), dtype=np.float64) / RATE


def fade(signal, attack=0.002, release=0.04):
    """Zero both boundaries, including the tails of overlapping notes."""
    signal = signal.copy()
    a = min(len(signal), max(2, round(attack * RATE)))
    r = min(len(signal), max(2, round(release * RATE)))
    signal[:a] *= np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    signal[-r:] *= np.cos(np.linspace(0, np.pi / 2, r)) ** 2
    return signal


def frequency(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def air(seconds, seed, low=600, high=5500):
    """Band-limited, reproducible noise for soft transients and airy accents."""
    n = len(timeline(seconds))
    rng = np.random.default_rng(seed)
    bins = np.fft.rfftfreq(n, 1 / RATE)
    spectrum = np.fft.rfft(rng.normal(size=n))
    band = (1 - np.exp(-(bins / low) ** 4)) * np.exp(-(bins / high) ** 4)
    shaped = np.fft.irfft(spectrum * band, n=n)
    return shaped / max(np.std(shaped), 1e-9)


def gel(hz=740, seconds=0.25, elastic=0.38, color=0.65, hold=0):
    """A soft FM gesture that scoops up and settles, with a velvety attack.

    Its shape comes from moving pitch and timbre, not a sequence of notes.
    Integer-ratio FM avoids a metallic bell; longer reward gestures keep a
    little harmonic body during their hold, then soften into the release.
    """
    t = timeline(seconds)
    bend = 1 - elastic * np.exp(-t / 0.017) + 0.075 * np.exp(-t / 0.060)
    phase = TAU * np.cumsum(hz * bend) / RATE
    modulation = color * (0.13 + 0.87 * np.exp(-t / 0.055)) * np.sin(2 * phase)
    signal = np.sin(phase + modulation)
    signal += 0.10 * np.sin(2 * phase) * np.exp(-t / 0.045)
    signal = np.tanh(signal * 1.22) / 1.22
    envelope = (1 - np.exp(-t / 0.0025)) * np.exp(-np.maximum(t - hold, 0) / (seconds / 4.7))
    return fade(signal * envelope, 0.0015, 0.035)


def pop(start=620, end=340, seconds=0.085):
    """Rounded liquid droplet with a very short, softly saturated impact."""
    t = timeline(seconds)
    bend = end * t + (start - end) * 0.015 * (1 - np.exp(-t / 0.015))
    signal = np.sin(TAU * bend) + 0.18 * np.sin(TAU * bend * 2)
    signal = np.tanh(signal * 1.4) / 1.4
    return fade(signal * np.exp(-t / 0.026), 0.002, 0.025)


def fizz(seconds=0.09, seed=1):
    t = timeline(seconds)
    envelope = (1 - np.exp(-t / 0.002)) * np.exp(-t / 0.015)
    return fade(air(seconds, seed, 1800, 7000) * envelope, 0.0015, 0.02)


def swell(seconds=0.24, seed=1):
    """A soft, rising air gesture leading into the reward's main impact."""
    t = timeline(seconds)
    progress = t / seconds
    envelope = np.sin(np.pi * progress) ** 1.5 * (0.25 + progress)
    return fade(air(seconds, seed, 700, 4300) * envelope, 0.018, 0.012)


def bloom(midis, seconds=0.75, hold=0.12):
    """A warm, sustained synth reward chord with a shaped, gentle release."""
    t = timeline(seconds)
    signal = np.zeros_like(t)
    for index, midi in enumerate(midis):
        f = frequency(midi)
        phase = TAU * f * (t - 0.002 * (1 - np.exp(-t / 0.026)))
        tone = np.sin(phase + 0.17 * index)
        brightness = 0.30 + 0.70 * np.exp(-t / 0.14)
        tone += 0.26 * np.sin(phase * 2) * brightness
        tone += 0.09 * np.sin(phase * 3) * brightness
        tone += 0.025 * np.sin(phase * 4) * np.exp(-t / 0.07)
        signal += tone / len(midis)
    envelope = (1 - np.exp(-t / 0.018)) * np.exp(-np.maximum(t - hold, 0) / (seconds / 5.5))
    return fade(signal * envelope, 0.006, 0.14)


class Cue:
    def __init__(self, seconds):
        self.audio = np.zeros((round(seconds * RATE), 2))

    def add(self, sound, at=0, level=1, pan=0):
        start = round(at * RATE)
        n = min(len(sound), len(self.audio) - start)
        angle = (pan + 1) * np.pi / 4
        stereo = np.array([np.cos(angle), np.sin(angle)])
        self.audio[start:start + n] += sound[:n, None] * stereo * level
        return self

    def finish(self, target_db=-20, room=0.055):
        dry = self.audio
        mixed = dry.copy()
        # Short reflections keep the attack immediate. The dry signal stays
        # dominant and positively correlated when folded down to mono.
        for delay, gain in [(0.012, 0.5), (0.023, 0.32), (0.037, 0.18)]:
            offset = round(delay * RATE)
            mixed[offset:] += dry[:-offset, ::-1] * room * gain
        for channel in range(2):
            mixed[:, channel] = fade(mixed[:, channel], 0.001, 0.035)
        mixed -= np.mean(mixed, axis=0)
        for channel in range(2):
            mixed[:, channel] = fade(mixed[:, channel], 0.001, 0.025)
        # Active 20 ms windows avoid amplifying long tails just to match a
        # short confirmation. These are RMS targets, not integrated LUFS.
        block = round(RATE * 0.02)
        windows = mixed[:len(mixed) // block * block].reshape(-1, block, 2)
        power = np.mean(windows**2, axis=(1, 2))
        active = power[power > power.max() * 0.025]
        rms = np.sqrt(np.mean(active))
        gain = 10 ** (target_db / 20) / max(rms, 1e-9)
        gain = min(gain, 10 ** (-4 / 20) / np.max(np.abs(mixed)))
        mixed *= gain
        # Remove inaudible padding while preserving the audible release.
        audible = np.flatnonzero(np.max(np.abs(mixed), axis=1) > 10 ** (-64 / 20))
        end = min(len(mixed), audible[-1] + 1 + round(0.020 * RATE))
        mixed = mixed[:end]
        for channel in range(2):
            mixed[:, channel] = fade(mixed[:, channel], 0.0005, 0.012)
        return mixed


def compose():
    """Liquid gestures with E-major harmony reserved for larger rewards."""
    cues = {}

    cue = Cue(0.10)
    cue.add(pop(610, 330, 0.065), level=0.65)
    cue.add(fizz(0.045, 2), level=0.055)
    cues['tap'] = cue.finish(-26, room=0.02)

    # A complete little win: pickup, lift, warm landing, and a bright answer.
    cue = Cue(0.83)
    cue.add(pop(570, 320, 0.09), level=0.42)
    cue.add(gel(659, 0.32, elastic=0.42, hold=0.025), at=0.006, level=0.44, pan=-0.08)
    cue.add(gel(988, 0.39, elastic=0.26, color=0.38, hold=0.04), at=0.125, level=0.25, pan=0.10)
    cue.add(bloom([64, 71, 80], 0.61, hold=0.13), at=0.17, level=0.46)
    cue.add(pop(1480, 1120, 0.09), at=0.335, level=0.08, pan=-0.12)
    cue.add(gel(1319, 0.28, elastic=0.17, color=0.24), at=0.405, level=0.10, pan=0.12)
    cue.add(fizz(0.065, 10), at=0.002, level=0.035)
    cues['correct'] = cue.finish(-20.0, room=0.075)

    cue = Cue(0.49)
    cue.add(pop(360, 265, 0.08), level=0.28)
    cue.add(gel(420, 0.27, elastic=0.20, color=0.24), at=0.004, level=0.50)
    cue.add(gel(554, 0.28, elastic=0.18, color=0.17), at=0.16, level=0.23)
    cues['retry'] = cue.finish(-24.0, room=0.025)

    cue = Cue(1.58)
    cue.add(pop(540, 235, 0.10), level=0.40)
    cue.add(gel(659, 0.35), at=0.005, level=0.38, pan=-0.12)
    cue.add(gel(831, 0.32, elastic=0.30), at=0.145, level=0.31, pan=0.12)
    cue.add(swell(0.25, 22), at=0.14, level=0.055)
    cue.add(pop(350, 180, 0.14), at=0.385, level=0.42)
    cue.add(bloom([52, 64, 71, 80], 0.88, hold=0.19), at=0.39, level=0.75)
    cue.add(gel(1319, 0.49, elastic=0.25, color=0.35, hold=0.055), at=0.40, level=0.23)
    cue.add(fizz(0.08, 20), at=0.003, level=0.04)
    cue.add(fizz(0.13, 21), at=0.392, level=0.085)
    cue.add(gel(1480, 0.32, elastic=0.17, color=0.20), at=0.73, level=0.095, pan=-0.15)
    cue.add(gel(1319, 0.44, elastic=0.20, color=0.25), at=0.88, level=0.14, pan=0.12)
    cue.add(bloom([64, 71, 80], 0.70, hold=0.08), at=0.84, level=0.24)
    cue.add(pop(1850, 1460, 0.09), at=1.07, level=0.045, pan=0.18)
    cues['batchComplete'] = cue.finish(-19.5, room=0.10)

    # A longer payoff: spring upward, build anticipation, land, then answer.
    cue = Cue(2.42)
    cue.add(pop(520, 210, 0.10), level=0.38)
    cue.add(gel(659, 0.37, elastic=0.48, hold=0.02), at=0.006, level=0.40, pan=-0.13)
    cue.add(gel(988, 0.42, elastic=0.42, hold=0.035), at=0.175, level=0.31, pan=0.14)
    cue.add(swell(0.42, 31), at=0.18, level=0.08)
    cue.add(pop(310, 165, 0.17), at=0.595, level=0.45)
    cue.add(gel(165, 0.34, elastic=0.12, color=0.35), at=0.60, level=0.16)
    cue.add(gel(1319, 0.58, elastic=0.22, color=0.35, hold=0.08), at=0.61, level=0.24)
    cue.add(bloom([52, 64, 71, 80], 1.22, hold=0.24), at=0.60, level=0.80)
    cue.add(fizz(0.16, 30), at=0.602, level=0.10)
    cue.add(gel(1480, 0.37, elastic=0.20, color=0.23), at=1.04, level=0.13, pan=-0.12)
    cue.add(gel(1319, 0.50, elastic=0.16, color=0.23, hold=0.035), at=1.23, level=0.18, pan=0.12)
    cue.add(bloom([64, 71, 76, 80], 1.03, hold=0.16), at=1.30, level=0.30)
    for at, start, end, pan in [(1.50, 1700, 1280, -0.22), (1.69, 1900, 1440, 0.22), (1.83, 1660, 1320, 0.05)]:
        cue.add(pop(start, end, 0.095), at, level=0.040, pan=pan)
    cues['milestone'] = cue.finish(-19.0, room=0.14)

    cue = Cue(1.15)
    cue.add(pop(390, 570, 0.075), level=0.30)
    cue.add(gel(554, 0.35, elastic=0.45), at=0.006, level=0.42, pan=-0.08)
    cue.add(gel(831, 0.39, elastic=0.28, hold=0.03), at=0.16, level=0.24, pan=0.10)
    cue.add(swell(0.17, 41), at=0.14, level=0.035)
    cue.add(bloom([64, 71, 80], 0.77, hold=0.16), at=0.31, level=0.50)
    cue.add(gel(1109, 0.40, elastic=0.17, color=0.20), at=0.38, level=0.12)
    cue.add(fizz(0.10, 40), at=0.312, level=0.04)
    cue.add(pop(1460, 1110, 0.08), at=0.68, level=0.05, pan=0.12)
    cues['timeReady'] = cue.finish(-21.0, room=0.085)

    # Old names remain compatible; one authoring source owns every sound.
    cues['success'] = cues['batchComplete']
    cues['try_again'] = cues['retry']
    return cues


def write_wav(path, audio):
    # Deterministic TPDF dither, without a silent tail hiss.
    rng = np.random.default_rng(20260927)
    dither = (rng.random(audio.shape) - rng.random(audio.shape)) / 65536
    dither[np.abs(audio) < 1 / 65536] = 0
    pcm = np.rint(np.clip(audio + dither, -1, 1) * 32767).astype('<i2')
    with wave.open(str(path), 'wb') as output:
        output.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
        output.writeframes(pcm.tobytes())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'assets/sounds')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    for name, audio in compose().items():
        path = args.output / f'{name}.wav'
        write_wav(path, audio)
        peak = 20 * np.log10(np.max(np.abs(audio)))
        print(f'{name:14s} {len(audio) / RATE:4.2f}s  peak {peak:5.1f} dBFS  {path.stat().st_size / 1024:5.0f} KiB')


if __name__ == '__main__':
    main()
