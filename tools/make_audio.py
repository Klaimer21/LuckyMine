"""Синтез звуков и музыки LuckyMine без внешних библиотек (чистый Python): python3 tools/make_audio.py
Пишет WAV в assets/audio/: эффекты (sfx_*.wav, 32 кГц) и семь музыкальных петель по зонам (music_N.wav, 16 кГц, моно).
Петли бесшовные: хвосты нот заворачиваются в начало. Параметры зон — в SPECS ниже."""
import math
import sys
import os
import random
import struct
import wave

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
SR_FX = 32000
SR_MU = 16000
TAU = 2.0 * math.pi


def write_wav(name, samples, sr, peak=0.9, fade=0.02):
    samples = list(samples)
    for i in range(min(len(samples), int(sr * fade))):      # короткий спад в конце: без щелчка
        samples[-1 - i] *= i / (sr * fade)
    top = max(1e-9, max(abs(x) for x in samples))
    scale = peak / top if top > peak else 1.0
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x * scale)) * 32767)) for x in samples))


def tone(sr, freq, dur, partials, attack=0.004):
    """Сумма гармоник [(отношение частоты, громкость, скорость затухания)], общая огибающая с атакой."""
    n = int(sr * dur)
    out = [0.0] * n
    for ratio, amp, decay in partials:
        f = TAU * freq * ratio / sr
        d = decay / sr
        for i in range(n):
            out[i] += amp * math.sin(f * i) * math.exp(-d * i)
    a = max(1, int(sr * attack))
    for i in range(min(a, n)):
        out[i] *= i / a
    return out


def noise(sr, dur, seed, lowpass=0.5, decay=10.0):
    rng = random.Random(seed)
    n = int(sr * dur)
    out = []
    lp = 0.0
    for i in range(n):
        lp += (rng.uniform(-1, 1) - lp) * lowpass
        out.append(lp * math.exp(-decay * i / sr))
    return out


def mix(*tracks):
    n = max(len(t[1]) if isinstance(t, tuple) else len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        gain, data = t if isinstance(t, tuple) else (1.0, t)
        for i, v in enumerate(data):
            out[i] += gain * v
    return out


def delayed(data, seconds, sr, total):
    pad = [0.0] * int(seconds * sr)
    out = pad + list(data)
    return out + [0.0] * max(0, int(total * sr) - len(out))


def sweep(sr, f0, f1, dur, decay=3.0):
    n = int(sr * dur)
    out = []
    phase = 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * (i / n)
        phase += TAU * f / sr
        out.append(math.sin(phase) * math.exp(-decay * i / n))
    return out


# ---------------------------------------------------------------- эффекты

def make_sfx():
    sr = SR_FX
    # удар камня: три варианта
    for k, (low, body) in enumerate([(70, 0.55), (84, 0.5), (62, 0.6)], 1):
        n = noise(sr, 0.3, 100 + k, 0.35, 16.0)
        thump = tone(sr, low, 0.3, [(1, 0.8, 28)])
        click = noise(sr, 0.05, 200 + k, 0.9, 140.0)
        write_wav(f"sfx_crack{k}.wav", mix((body, n), thump, (0.35, click)), sr, 0.8)
    # находки: медь, железо, золото, алмаз
    # без нот: только шум разной «твёрдости» (глухой стук меди, звонкий лязг железа, блеск золота и алмаза)
    write_wav("sfx_ore1.wav", noise(sr, 0.12, 301, 0.45, 45.0), sr, 0.6)
    write_wav("sfx_ore2.wav", mix(noise(sr, 0.14, 302, 0.7, 40.0), (0.5, noise(sr, 0.05, 303, 0.95, 120.0))), sr, 0.6)
    gold = mix(noise(sr, 0.2, 304, 0.9, 28.0), delayed(noise(sr, 0.12, 305, 0.95, 50.0), 0.06, sr, 0.22))
    write_wav("sfx_ore3.wav", gold, sr, 0.62)
    diamond = mix(noise(sr, 0.2, 306, 0.97, 32.0), delayed(noise(sr, 0.14, 307, 0.97, 45.0), 0.05, sr, 0.25),
                  delayed(noise(sr, 0.12, 308, 0.97, 55.0), 0.1, sr, 0.25))
    write_wav("sfx_ore4.wav", diamond, sr, 0.65)
    # динамит и взрывы
    boom = mix((0.8, noise(sr, 1.4, 7, 0.12, 3.2)), (1.0, sweep(sr, 90, 28, 1.4, 4.0)), (0.5, noise(sr, 0.08, 8, 0.95, 60.0)))
    write_wav("sfx_boom.wav", boom, sr, 0.9)
    write_wav("sfx_boss_hit.wav", mix(tone(sr, 95, 0.25, [(1, 0.9, 22)]), (0.5, noise(sr, 0.16, 9, 0.5, 30.0))), sr, 0.8)
    shards = mix(*[delayed(tone(sr, f, 0.7, [(1, 0.3, 6), (2.7, 0.15, 10)]), 0.05 * i, sr, 1.0)
                   for i, f in enumerate([1568, 2093, 1760, 2637, 2349, 3136])])
    write_wav("sfx_boss_break.wav", mix(boom[: int(sr * 1.0)], (0.8, shards)), sr, 0.9)
    # золотая глыба: мерцание
    shimmer = mix(*[(0.18, [x * (0.5 + 0.5 * math.sin(TAU * (6 + k) * i / sr)) for i, x in enumerate(tone(sr, 880 * (1 + 0.25 * k), 0.9, [(1, 1, 3)]))]) for k in range(5)])
    write_wav("sfx_golden.wav", shimmer, sr, 0.6)
    # лихорадка: растущий аккорд
    rush = mix(sweep(sr, 220, 880, 0.7, 1.2), (0.6, tone(sr, 523, 0.9, [(1, 0.4, 3), (1.5, 0.3, 3), (2, 0.2, 3)])))
    write_wav("sfx_rush.wav", rush, sr, 0.7)
    # престиж: гонг; смена зоны: низкий аккорд
    gong = tone(sr, 110, 3.0, [(1, 0.5, 1.4), (1.5, 0.3, 1.8), (2.02, 0.35, 2.4), (2.99, 0.2, 3.2), (4.1, 0.15, 4.5)], 0.01)
    write_wav("sfx_gong.wav", gong, sr, 0.85)
    swell = mix(*[tone(sr, f, 2.2, [(1, 0.5, 1.2), (2, 0.2, 2)], 0.35) for f in (98, 147, 196)])
    write_wav("sfx_zone.wav", swell, sr, 0.8)
    # награда и покупка
    coin = mix(tone(sr, 1175, 0.4, [(1, 0.5, 9), (2, 0.2, 14)]), delayed(tone(sr, 1568, 0.5, [(1, 0.5, 8), (2, 0.2, 14)]), 0.07, sr, 0.5))
    write_wav("sfx_coin.wav", coin, sr, 0.65)
    jingle = mix(*[delayed(tone(sr, f, 0.8, [(1, 0.4, 5), (2, 0.2, 9)]), 0.11 * i, sr, 1.2) for i, f in enumerate([523, 659, 784, 1047])])
    write_wav("sfx_claim.wav", jingle, sr, 0.7)
    write_wav("sfx_tick.wav", mix(tone(sr, 1400, 0.06, [(1, 0.6, 60)], 0.001), (0.3, noise(sr, 0.04, 11, 0.9, 80.0))), sr, 0.5)


# ---------------------------------------------------------------- музыка

def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


SPECS = [
    {"root": 57, "scale": [0, 3, 5, 7, 10], "prog": [0, 3, 2, 4], "bpm": 66, "melody": "marimba", "density": 0.22, "perc": None, "texture": 0.020, "pad": 0.5, "seed": 1},
    {"root": 50, "scale": [0, 2, 3, 5, 7, 9, 10], "prog": [0, 3, 4, 2], "bpm": 76, "melody": "marimba", "density": 0.30, "perc": "shaker", "texture": 0.012, "pad": 0.55, "seed": 2},
    {"root": 52, "scale": [0, 1, 3, 5, 7, 8, 10], "prog": [0, 1, 0, 4], "bpm": 84, "melody": "metal", "density": 0.24, "perc": "kick", "texture": 0.008, "pad": 0.45, "seed": 3},
    {"root": 60, "scale": [0, 2, 4, 7, 9], "prog": [0, 2, 3, 1], "bpm": 96, "melody": "kalimba", "density": 0.50, "perc": "hat", "texture": 0.0, "pad": 0.5, "seed": 4},
    {"root": 54, "scale": [0, 2, 4, 6, 7, 9, 11], "prog": [0, 4, 1, 5], "bpm": 62, "melody": "glass", "density": 0.20, "perc": None, "texture": 0.010, "pad": 0.6, "seed": 5},
    {"root": 38, "scale": [0, 2, 3, 5, 7, 8, 11], "prog": [0, 5, 3, 6], "bpm": 100, "melody": "low", "density": 0.18, "perc": "heavy", "texture": 0.020, "pad": 0.5, "seed": 6},
    {"root": 36, "scale": [0, 2, 3, 5, 7, 8, 10], "prog": [0, 0, 5, 4], "bpm": 60, "melody": "glass", "density": 0.12, "perc": "heart", "texture": 0.015, "pad": 0.7, "seed": 7},
]
MELODY = {
    "marimba": [(1, 0.7, 6), (3.9, 0.25, 14), (9.2, 0.1, 30)],
    "kalimba": [(1, 0.6, 7), (5.4, 0.3, 18)],
    "metal": [(1, 0.5, 5), (2.76, 0.3, 8), (5.4, 0.2, 12), (8.93, 0.1, 18)],
    "glass": [(1, 0.5, 1.8), (2.0, 0.25, 2.6), (3.0, 0.15, 3.6)],
    "low": [(1, 0.6, 4), (2, 0.25, 7), (3, 0.15, 10)],
}


def build_track(spec, index):
    sr = SR_MU
    rng = random.Random(spec["seed"])
    beats = 32
    spb = 60.0 / spec["bpm"]
    n = int(beats * spb * sr)
    buf = [0.0] * n

    def add(start, samples, gain):
        base = int(start * sr)
        for i, v in enumerate(samples):
            buf[(base + i) % n] += v * gain

    scale = spec["scale"]

    def degree_note(d, octave=0):
        o, k = divmod(d, len(scale))
        return spec["root"] + scale[k] + 12 * (o + octave)

    # аккорды: по 8 долей, три голоса через ступень, мягкий медленный пэд
    for c, d in enumerate(spec["prog"]):
        start = c * 8 * spb
        for step in (0, 2, 4):
            f = midi(degree_note(d + step, 1))
            for detune in (0.997, 1.003):
                pad = tone(sr, f * detune, 8 * spb * 1.15, [(1, 0.5, 0.0), (2, 0.12, 0.0)], 1.6)
                # плавный спад в конце, чтобы не было щелчка на стыках
                m = len(pad)
                fade = int(sr * 1.4)
                for i in range(fade):
                    pad[m - 1 - i] *= i / fade
                add(start, pad, spec["pad"] * 0.12)
        bass = tone(sr, midi(degree_note(d, -1)), 8 * spb * 0.95, [(1, 0.8, 0.0), (2, 0.1, 0.0)], 0.3)
        m = len(bass)
        for i in range(int(sr * 0.5)):
            bass[m - 1 - i] *= i / (sr * 0.5)
        add(start, bass, 0.22)
    # мелодия
    kind = spec["melody"]
    octave = 2 if kind == "glass" else (0 if kind == "low" else 1)
    last = 0
    for e in range(beats * 2):
        if rng.random() < spec["density"]:
            last = max(0, min(len(scale) * 2, last + rng.choice([-2, -1, 0, 1, 2])))
            f = midi(degree_note(last, octave))
            dur = {"glass": 3.0, "low": 1.6, "metal": 1.4}.get(kind, 1.1)
            add(e * spb / 2, tone(sr, f, dur, MELODY[kind], 0.005), 0.16 if kind != "kalimba" else 0.13)
            if kind == "kalimba" and rng.random() < 0.6:       # короткие арпеджио
                add(e * spb / 2 + spb / 4, tone(sr, f * 1.5, 0.8, MELODY[kind], 0.005), 0.08)
    # ударные
    perc = spec["perc"]
    for beat in range(beats):
        t = beat * spb
        if perc == "kick":
            add(t, mix(tone(sr, 62, 0.25, [(1, 0.9, 16)]), (0.2, noise(sr, 0.03, beat + 40, 0.8, 90.0))), 0.20)
        elif perc == "heavy":
            add(t, mix(tone(sr, 52, 0.4, [(1, 1.0, 9)]), (0.3, noise(sr, 0.05, beat + 40, 0.7, 70.0))), 0.30)
            if beat % 2 == 1:
                add(t + spb / 2, noise(sr, 0.12, beat + 80, 0.35, 28.0), 0.10)
        elif perc == "heart":
            if beat % 2 == 0:
                add(t, tone(sr, 48, 0.3, [(1, 1.0, 12)]), 0.28)
                add(t + spb * 0.33, tone(sr, 44, 0.3, [(1, 1.0, 12)]), 0.20)
        elif perc == "shaker":
            add(t + spb / 2, noise(sr, 0.07, beat + 60, 0.9, 50.0), 0.06)
        elif perc == "hat":
            add(t + spb / 2, noise(sr, 0.04, beat + 60, 0.95, 90.0), 0.07)
            add(t, noise(sr, 0.03, beat + 90, 0.95, 90.0), 0.04)
    # текстура: ветер (шум с медленной огибающей)
    if spec["texture"] > 0:
        trng = random.Random(spec["seed"] + 50)
        lp = 0.0
        lp2 = 0.0
        for i in range(n):
            lp += (trng.uniform(-1, 1) - lp) * 0.05
            lp2 += (lp - lp2) * 0.2
            buf[i] += lp2 * spec["texture"] * 6.0 * (0.6 + 0.4 * math.sin(TAU * 2 * i / n))
    # мягкое ограничение и нормализация
    top = max(abs(x) for x in buf) or 1.0
    scale_out = 0.7 / top
    for i in range(n):
        x = buf[i] * scale_out
        buf[i] = math.tanh(x * 1.2) / 1.2
    write_wav(f"music_{index}.wav", buf, sr, 0.7, fade=0.0)


def main():
    os.makedirs(OUT, exist_ok=True)
    make_sfx()
    if "sfx" in sys.argv[1:]:
        print("звуки готовы:", OUT)
        return
    for i, spec in enumerate(SPECS):
        build_track(spec, i)
        print("музыка", i, "готова")
    print("звуки готовы:", OUT)


if __name__ == "__main__":
    main()
