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
    crag_sounds()
    music()
    arcade_sounds()
    print("wrote", len(list(OUT.glob("*.wav"))), "placeholder sounds to", OUT)


def crag_sounds():
    """The holds and the moments of a climb. Made after the sounds above so
    those stay byte-identical."""
    # Catching a dyno: a slap of hands on rock and a puff of chalk.
    n = seconds(0.28)
    t = np.arange(n) / RATE
    x = lowpass(rng.normal(0, 1, n), 0.55) * env(n, 0.0008, 0.025) * 1.6
    x += np.sin(2 * np.pi * 180 * t) * env(n, 0.001, 0.05) * 0.7
    x += lowpass(rng.normal(0, 1, n), 0.2) * env(n, 0.03, 0.08) * 0.5
    write("catch", x)
    # A sloper: skin sliding on smooth stone, soft and long.
    n = seconds(0.32)
    t = np.arange(n) / RATE
    write("sloper", lowpass(rng.normal(0, 1, n), 0.12) * np.sin(np.pi * t / t[-1]) * 1.3)
    # A pocket: fingers into a hole, a short hollow knock.
    n = seconds(0.16)
    t = np.arange(n) / RATE
    x = np.sin(2 * np.pi * 420 * t) * env(n, 0.0005, 0.02) * 0.6
    x += lowpass(rng.normal(0, 1, n), 0.4) * env(n, 0.0005, 0.012) * 0.6
    write("pocket", x)
    # A jug: a big, firm grab.
    n = seconds(0.22)
    t = np.arange(n) / RATE
    x = lowpass(rng.normal(0, 1, n), 0.3) * env(n, 0.001, 0.04) * 1.5
    x += np.sin(2 * np.pi * 120 * t) * env(n, 0.001, 0.06) * 0.6
    write("jug", x)
    # The top: three warm rising notes and a ring.
    n = seconds(1.6)
    t = np.arange(n) / RATE
    x = np.zeros(n)
    for i, f in enumerate((392.0, 523.25, 659.25)):
        at = seconds(0.11 * i)
        m = n - at
        x[at:] += (np.sin(2 * np.pi * f * t[:m]) + 0.35 * np.sin(2 * np.pi * 2 * f * t[:m])) * env(m, 0.004, 0.45) * 0.28
    write("topout", x)


def arcade_sounds():
    """Short cues for the replay loop, made last (own noise source) so the
    sounds above stay byte-identical."""
    # A new record: a quick bright two-note lift, under half a second.
    n = seconds(0.45)
    t = np.arange(n) / RATE
    x = np.zeros(n)
    for i, f in enumerate((783.99, 1174.66)):
        at = seconds(0.07 * i)
        m = n - at
        x[at:] += (np.sin(2 * np.pi * f * t[:m]) + 0.25 * np.sin(2 * np.pi * 3 * f * t[:m])) * env(m, 0.002, 0.16) * 0.3
    write("record", x)
    # A perfect catch: a crisp high ping on top of the slap.
    n = seconds(0.2)
    t = np.arange(n) / RATE
    write("perfect", np.sin(2 * np.pi * 1318.5 * t) * env(n, 0.001, 0.06) * 0.35)


def music():
    """Music: quiet, sparse, looping. A soft pad on two chords and a slow
    plucked line in a pentatonic scale, so it sits under the wind instead
    of over it. Each loop ends where it starts."""
    def pluck(f, n):
        t = np.arange(n) / RATE
        return (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t) + 0.1 * np.sin(2 * np.pi * 3 * f * t)) * env(n, 0.006, 0.6)

    def pad(freqs, n):
        t = np.arange(n) / RATE
        x = sum(np.sin(2 * np.pi * f * t + i) for i, f in enumerate(freqs)) / len(freqs)
        return x * np.sin(np.pi * t / t[-1]) ** 2

    for name, bars, chords, line, tempo in (
        ("music_crag", 8, [(196.0, 293.66, 392.0), (174.61, 261.63, 349.23)], [392, 440, 523.25, 587.33, 659.25, 587.33, 523.25, 440], 2.0),
        ("music_camp", 8, [(146.83, 220.0, 293.66), (130.81, 196.0, 261.63)], [293.66, 329.63, 392, 440, 392, 329.63, 293.66, 261.63], 2.4),
    ):
        bar = seconds(tempo)
        n = bar * bars
        x = np.zeros(n)
        for b in range(bars):
            x[b * bar:(b + 1) * bar] += pad(chords[(b // 2) % 2], bar) * 0.16
        prng = np.random.default_rng(5)
        for b in range(bars):
            for beat in (0, 2) if b % 2 == 0 else (1,):
                at = b * bar + beat * bar // 4
                m = min(seconds(1.6), n - at)
                f = line[(b * 3 + beat) % len(line)]
                x[at:at + m] += pluck(f, m) * 0.14 * prng.uniform(0.7, 1.0)
        fade = seconds(0.05)
        x[:fade] *= np.linspace(0, 1, fade)
        x[-fade:] *= np.linspace(1, 0, fade)
        write(name, x)


if __name__ == "__main__":
    main()
