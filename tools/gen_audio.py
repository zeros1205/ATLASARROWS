"""Synthesizes the game's SFX into assets/audio/ (stdlib only).

Run from the repo root:  python tools/gen_audio.py

- pop_0..pop_7.wav : escape pop, rising a semitone per combo step
- block.wav        : low thud for a blocked tap
- clear.wav        : ascending arpeggio on level clear
- fail.wav         : descending tones on out-of-hearts
"""
import math
import os
import random
import struct
import wave

SR = 44100


def write_wav(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(
            b"".join(
                struct.pack("<h", max(-32767, min(32767, int(s * 32767))))
                for s in samples
            )
        )


def env(t, attack=0.004, decay=28.0):
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * math.exp(-t * decay)


def pop(freq, dur=0.16):
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        f = freq * (1 + 0.25 * t / dur)  # slight upward chirp = "whoosh-pop"
        ph = 2 * math.pi * f * t
        s = (math.sin(ph) + 0.35 * math.sin(2 * ph)) * env(t)
        out.append(0.55 * s)
    return out


def block(dur=0.2):
    rng = random.Random(7)
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        f = 115 * (1 - 0.4 * t / dur)
        s = math.sin(2 * math.pi * f * t) * math.exp(-t * 18)
        n = (rng.random() * 2 - 1) * math.exp(-t * 60) * 0.3
        out.append(0.6 * (s + n))
    return out


def tone_seq(freqs, note=0.12, gap=0.085, decay=16.0):
    total = gap * (len(freqs) - 1) + note + 0.35
    out = [0.0] * int(SR * total)
    for k, f in enumerate(freqs):
        start = int(SR * gap * k)
        for i in range(int(SR * note * 2.5)):
            if start + i >= len(out):
                break
            t = i / SR
            s = (math.sin(2 * math.pi * f * t) + 0.3 * math.sin(4 * math.pi * f * t))
            out[start + i] += 0.4 * s * math.exp(-t * decay)
    peak = max(abs(s) for s in out) or 1.0
    return [s / peak * 0.75 for s in out]


def main():
    root = os.path.join(os.path.dirname(__file__), "..")
    out_dir = os.path.join(root, "assets", "audio")
    os.makedirs(out_dir, exist_ok=True)
    base = 660.0  # E5
    for i in range(8):
        write_wav(
            os.path.join(out_dir, f"pop_{i}.wav"), pop(base * (2 ** (i / 12)))
        )
    write_wav(os.path.join(out_dir, "block.wav"), block())
    write_wav(
        os.path.join(out_dir, "clear.wav"),
        tone_seq([523.25, 659.25, 783.99, 1046.5]),
    )
    write_wav(
        os.path.join(out_dir, "fail.wav"),
        tone_seq([392.0, 311.13, 246.94], note=0.16, gap=0.14, decay=12.0),
    )
    print("wrote", sorted(os.listdir(out_dir)))


if __name__ == "__main__":
    main()
