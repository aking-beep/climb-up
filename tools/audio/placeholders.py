"""
Placeholder sound effects and ambience for the Godot prototype, synthesized
from noise and simple tones so every sound is project-owned. They are
stand-ins for recorded or designed audio (see godot/assets/audio/README.md).

    python3 tools/audio/placeholders.py
"""

import wave
from pathlib import Path

import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parents[2] / "godot" / "assets" / "audio" / "placeholder"
rng = np.random.default_rng(11)


def write(name, x):
    x = np.clip(x, -1, 1)
    data = (x * 32767 * 0.9).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def lowpass(x, a):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def env(n, attack, decay):
    t = np.arange(n) / RATE
    return np.minimum(1, t / max(attack, 1e-4)) * np.exp(-t / decay)


def seconds(s):
    return int(RATE * s)


def footstep(kind, i):
    n = seconds(0.16)
    noise = rng.normal(0, 1, n)
    if kind == "dirt":
        x = lowpass(noise, 0.18) * env(n, 0.004, 0.035) * 2.2
    else:  # rock: sharper click plus grit
        x = lowpass(noise, 0.5) * env(n, 0.001, 0.02) * 1.6
        x += np.sin(2 * np.pi * (900 + 120 * i) * np.arange(n) / RATE) * env(n, 0.0005, 0.008) * 0.3
    return x


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for i in range(3):
        write(f"step_dirt_{i}", footstep("dirt", i))
        write(f"step_rock_{i}", footstep("rock", i))
    for i in range(2):  # a hand finding a hold: short scrape
        n = seconds(0.22)
        x = lowpass(rng.normal(0, 1, n), 0.35) * env(n, 0.01, 0.06) * 1.4
        write(f"grip_{i}", x)
    # Loose rock trickling away.
    n = seconds(1.2)
    x = np.zeros(n)
    for k in range(18):
        at = int(rng.uniform(0, n - seconds(0.1)))
        m = seconds(0.08)
        x[at:at + m] += lowpass(rng.normal(0, 1, m), 0.6) * env(m, 0.001, 0.015) * rng.uniform(0.3, 1)
    write("rockfall", x * np.linspace(1, 0.3, n))
    # A tired breath out.
    n = seconds(0.9)
    t = np.arange(n) / RATE
    x = lowpass(rng.normal(0, 1, n), 0.08) * np.sin(np.pi * t / t[-1]) ** 2 * 1.5
    write("breath", x)
    # Slip: a scuff and a thud.
    n = seconds(0.5)
    t = np.arange(n) / RATE
    x = lowpass(rng.normal(0, 1, n), 0.4) * env(n, 0.002, 0.08)
    x += np.sin(2 * np.pi * 70 * t) * env(n, 0.002, 0.12) * 0.9
    write("slip", x)
    # Interaction chime: two soft partials.
    n = seconds(0.6)
    t = np.arange(n) / RATE
    x = (np.sin(2 * np.pi * 660 * t) + 0.5 * np.sin(2 * np.pi * 990 * t)) * env(n, 0.005, 0.18) * 0.35
    write("chime", x)
    # Cairn reached: lower, warmer.
    x = (np.sin(2 * np.pi * 440 * t) + 0.4 * np.sin(2 * np.pi * 660 * t)) * env(n, 0.01, 0.25) * 0.35
    write("cairn", x)
    # Wind loop: filtered noise with slow swells. Ends where it starts.
    n = seconds(8.0)
    t = np.arange(n) / RATE
    swell = 0.55 + 0.45 * np.sin(2 * np.pi * t / 8.0) * np.sin(2 * np.pi * t / 2.0 + 1)
    x = lowpass(rng.normal(0, 1, n), 0.05) * swell * 2.4
    fade = seconds(0.25)
    x[:fade] *= np.linspace(0, 1, fade)
    x[-fade:] *= np.linspace(1, 0, fade)
    write("wind_loop", x)
    # A gust: rising, then falling, brighter noise.
    n = seconds(1.6)
    t = np.arange(n) / RATE
    x = lowpass(rng.normal(0, 1, n), 0.18) * np.sin(np.pi * t / t[-1]) ** 1.5 * 1.8
    write("gust", x)
    # Camp ambience: low air and a crackle of fire. Loops.
    n = seconds(6.0)
    x = lowpass(rng.normal(0, 1, n), 0.02) * 1.2
    for k in range(60):
        at = int(rng.uniform(0, n - 200))
        x[at:at + 120] += rng.normal(0, 1, 120) * env(120, 0.0005, 0.002) * rng.uniform(0.2, 0.6)
    x[:fade] *= np.linspace(0, 1, fade)
    x[-fade:] *= np.linspace(1, 0, fade)
    write("camp_loop", x)
    # The crag. Made after everything above so those stay byte-identical.
    # A clip: the gate snapping shut, two quick metal clicks and a short ring.
    n = seconds(0.22)
    t = np.arange(n) / RATE
    x = np.zeros(n)
    for at, f in ((0, 3100), (seconds(0.035), 2600)):
        m = n - at
        x[at:] += np.sin(2 * np.pi * f * t[:m]) * env(m, 0.0003, 0.03) * 0.5
        x[at:at + 200] += rng.normal(0, 1, 200) * env(200, 0.0002, 0.002) * 0.6
    write("clip", x)
    # Chalk: a soft dry puff.
    n = seconds(0.25)
    write("chalk", lowpass(rng.normal(0, 1, n), 0.25) * env(n, 0.02, 0.06) * 1.1)
    # A lead fall: rope running through the draws, a rising whoosh.
    n = seconds(0.6)
    x = rng.normal(0, 1, n)
    x = lowpass(x, 0.35) - lowpass(x, 0.05)
    write("whip", x * np.linspace(0.1, 1.0, n) ** 2 * env(n, 0.3, 0.25) * 2.5)
    # Hitting the ground: a low thump.
    n = seconds(0.35)
    t = np.arange(n) / RATE
    x = np.sin(2 * np.pi * (70 - 30 * t / t[-1]) * t) * env(n, 0.002, 0.09) * 1.2
    x += lowpass(rng.normal(0, 1, n), 0.1) * env(n, 0.001, 0.05) * 0.8
    write("thud", x)
    print("wrote", len(list(OUT.glob("*.wav"))), "placeholder sounds to", OUT)


if __name__ == "__main__":
    main()
