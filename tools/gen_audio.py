"""Synthesizes the game's SFX into assets/audio/ (stdlib only).

Run from the repo root:  python tools/gen_audio.py

Escape sounds ship as five "voices"; each stage randomly plays one of them
(see lib/game/sfx.dart). Every voice is pre-rendered at eight semitone steps
so a combo climbs in pitch as lines leave the board:

- esc_marimba_0..7.wav : warm wooden mallet
- esc_pluck_0..7.wav   : short plucked string (Karplus-Strong)
- esc_blip_0..7.wav    : clean two-tone UI blip
- esc_bubble_0..7.wav  : playful upward bloop/pop
- esc_whoosh_0..7.wav  : airy noise swoosh + pop tail

- block.wav            : low thud for a blocked tap
- clear.wav            : ascending arpeggio on level clear
- fail.wav             : descending tones on out-of-hearts
"""
import math
import os
import random
import struct
import wave

SR = 44100
BASE = 523.25  # C5, escape base pitch (combo step 0)
STEPS = 8      # esc_<voice>_0..7, one per semitone of combo climb


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


def _env(t, attack, tau):
    """Linear attack over `attack` s, then exponential decay with time-constant `tau`."""
    if t < attack:
        return t / attack if attack > 0 else 1.0
    return math.exp(-(t - attack) / tau)


def _norm(samples, peak=0.62):
    m = max((abs(s) for s in samples), default=0.0) or 1.0
    return [s / m * peak for s in samples]


# ----- escape voices (base-pitch synths; caller passes the stepped frequency) -----

def v_marimba(f, dur=0.28):
    rng = random.Random(1)
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        y = (
            math.sin(2 * math.pi * f * t) * math.exp(-t / 0.13)
            + 0.35 * math.sin(2 * math.pi * 3.9 * f * t) * math.exp(-t / 0.05)
            + 0.15 * math.sin(2 * math.pi * 9.2 * f * t) * math.exp(-t / 0.02)
        )
        click = (rng.random() * 2 - 1) * math.exp(-t / 0.004) * 0.25
        out.append(y * _env(t, 0.001, 0.13) + click)
    return _norm(out)


def v_pluck(f, dur=0.26):
    n = int(SR * dur)
    N = max(2, int(SR / f))
    rng = random.Random(2)
    buf = [rng.gauss(0, 1) for _ in range(N)]
    out = [0.0] * n
    for i in range(n):
        out[i] = buf[i % N]
        nxt = (i + 1) % N
        buf[i % N] = 0.5 * (buf[i % N] + buf[nxt]) * 0.996
    out = [out[i] * _env(i / SR, 0.001, 0.14) for i in range(n)]
    return _norm(out)


def v_blip(f, dur=0.14):
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        y = (math.sin(2 * math.pi * f * t) + 0.5 * math.sin(2 * math.pi * 1.5 * f * t))
        y *= math.exp(-t / 0.045)
        out.append(y * _env(t, 0.001, 0.045))
    return _norm(out)


def v_bubble(f, dur=0.16):
    out = []
    ph = 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        fr = f * (0.6 + 0.9 * (1 - math.exp(-t / 0.02)))  # quick upward bend
        ph += 2 * math.pi * fr / SR
        out.append(math.sin(ph) * math.exp(-t / 0.05) * _env(t, 0.001, 0.05))
    return _norm(out)


def v_whoosh(f, dur=0.20):
    rng = random.Random(3)
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        noise = rng.gauss(0, 1)
        sw = noise * math.exp(-((t - 0.03) ** 2) / (2 * 0.02 ** 2)) * 0.5
        pop = math.sin(2 * math.pi * f * t) * math.exp(-t / 0.045) if t > 0.02 else 0.0
        out.append(sw + pop * 0.9)
    return _norm(out)


VOICES = {
    "marimba": v_marimba,
    "pluck": v_pluck,
    "blip": v_blip,
    "bubble": v_bubble,
    "whoosh": v_whoosh,
}


# ----- non-escape SFX (unchanged) -----

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
    for name, fn in VOICES.items():
        for step in range(STEPS):
            freq = BASE * (2 ** (step / 12))
            write_wav(os.path.join(out_dir, f"esc_{name}_{step}.wav"), fn(freq))
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
