#!/usr/bin/env python3
"""Генератор звуков и музыки для Quiet Waters: Fishing.

Запуск из корня проекта:  python3 tools/generate_audio.py
Требуются numpy и scipy. Скрипт создаёт mono 16-bit WAV в audio/ и audio/sfx/.
Три исходные мелодии (forest_lake, mountain_lake, reed_bay) не трогает.
"""
import os
import sys
import wave

import numpy as np
from scipy import signal

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rng = np.random.default_rng(20260930)


def save(path, x, peak=0.85):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", os.path.relpath(path, ROOT), len(x) / SR, "s")


def t_of(sec):
    return np.arange(int(sec * SR)) / SR


def noise(sec):
    return rng.standard_normal(int(sec * SR))


def lowpass(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def highpass(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def env_ad(n, attack, decay_tau):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t / decay_tau)


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def loopable(x, fade):
    """Делает отрезок бесшовным: хвост подмешивается в начало."""
    n = int(fade * SR)
    head = x[:n] * np.linspace(0, 1, n)
    tail = x[-n:] * np.linspace(1, 0, n)
    out = x[:-n].copy()
    out[:n] += tail
    out[:n] = head + tail
    return out


def reverb(x, wet=0.25, decay=1.6):
    n = int(decay * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-t * 5.0 / decay)
    ir = lowpass(ir, 4500)
    ir /= np.sqrt(np.sum(ir ** 2))
    y = signal.fftconvolve(x, ir)[: len(x)]
    return x * (1 - wet) + y * wet * 2.2


def fold_tail(buf, length):
    """Свернуть хвост реверберации на начало для идеальной петли."""
    out = buf[:length].copy()
    extra = buf[length:]
    out[: len(extra)] += extra
    return out


# ---------------------------------------------------------------- инструменты
def bell(freq, dur, brightness=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = np.sin(2 * np.pi * freq * t) * np.exp(-t / (dur * 0.35))
    y += 0.35 * brightness * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t / (dur * 0.12))
    y += 0.18 * brightness * np.sin(2 * np.pi * freq * 5.4 * t) * np.exp(-t / (dur * 0.06))
    return y * np.clip(t / 0.004, 0, 1)


def pluck(freq, dur, damp=0.5):
    """Karplus-Strong."""
    n = int(dur * SR)
    period = int(SR / freq)
    y = np.zeros(n + period)
    y[:period] = rng.uniform(-1, 1, period)
    y[:period] = lowpass(y[:period], 6000, 1)
    for i in range(period, n + period):
        y[i] = damp * (y[i - period] + y[i - period - 1 if i - period - 1 >= 0 else 0]) * 0.999
    y = y[:n]
    return y * np.clip(np.arange(n) / SR / 0.002, 0, 1) * np.exp(-np.arange(n) / SR / (dur * 0.6))


def pluck_fast(freq, dur, damp=0.498):
    n = int(dur * SR)
    period = max(2, int(round(SR / freq)))
    buf = rng.uniform(-1, 1, period)
    out = np.zeros(n)
    out[:period] = buf
    pos = period
    prev = buf
    while pos < n:
        cur = damp * (prev + np.roll(prev, 1)) * 1.002
        end = min(n, pos + period)
        out[pos:end] = cur[: end - pos]
        prev = cur
        pos += period
    return out * np.exp(-np.arange(n) / SR / (dur * 0.7))


def piano(freq, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for k, amp in enumerate([1.0, 0.5, 0.33, 0.22, 0.12, 0.08], start=1):
        y += amp * np.sin(2 * np.pi * freq * k * (1 + 0.0004 * k * k) * t) * np.exp(-t / (dur * 0.5 / (1 + 0.4 * k)))
    return y * np.clip(t / 0.003, 0, 1)


def marimba(freq, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = np.sin(2 * np.pi * freq * t) * np.exp(-t / 0.35)
    y += 0.4 * np.sin(2 * np.pi * freq * 4.0 * t) * np.exp(-t / 0.06)
    return y * np.clip(t / 0.002, 0, 1)


def steel(freq, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    mod = np.sin(2 * np.pi * freq * 2.0 * t) * 1.6 * np.exp(-t / 0.25)
    y = np.sin(2 * np.pi * freq * t + mod) * np.exp(-t / 0.5)
    return y * np.clip(t / 0.003, 0, 1)


def pad(freqs, dur, warm=1.0, detune=0.003):
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for f in freqs:
        for d in (-detune, 0, detune):
            y += np.sin(2 * np.pi * f * (1 + d) * t + rng.uniform(0, 6.28))
            y += 0.3 * warm * np.sin(2 * np.pi * f * 2 * (1 + d) * t)
    a = np.clip(t / (dur * 0.35), 0, 1) * np.clip((dur - t) / (dur * 0.35), 0, 1)
    return y * a / (len(freqs) * 3)


def bass(freq, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 2 * t)
    return y * env_ad(n, 0.01, dur * 0.6)


def add(buf, note, start):
    i = int(start * SR)
    if i >= len(buf):
        return
    seg = note[: len(buf) - i]
    buf[i : i + len(seg)] += seg


# ---------------------------------------------------------------- музыка
def compose(cfg):
    bpm = cfg["bpm"]
    beat = 60.0 / bpm
    bars = cfg["bars"]
    beats_per_bar = cfg.get("beats", 4)
    length = bars * beats_per_bar * beat
    tail = 3.0
    buf = np.zeros(int((length + tail) * SR))
    progression = cfg["prog"]  # список аккордов (midi корней + тип)
    scale = cfg["scale"]
    root = cfg["root"]
    r = np.random.default_rng(cfg["seed"])
    for bar in range(bars):
        chord = progression[bar % len(progression)]
        base = root + chord[0]
        tones = [base + i for i in chord[1]]
        t0 = bar * beats_per_bar * beat
        dur = beats_per_bar * beat
        if cfg.get("pad", True):
            add(buf, pad([midi(m) for m in tones], dur + 0.8, cfg.get("warm", 1.0)) * cfg.get("pad_gain", 0.6), t0)
        if cfg.get("bass"):
            for b in cfg["bass"]:
                add(buf, bass(midi(base - 12), beat * 1.6) * 0.5, t0 + b * beat)
        # арпеджио / ритм
        inst = cfg["inst"]
        pattern = cfg["pattern"]
        for step, (pos, deg) in enumerate(pattern):
            if deg is None:
                continue
            note_m = tones[deg % len(tones)] + 12 * (deg // len(tones)) + cfg.get("oct", 12)
            f = midi(note_m)
            add(buf, inst(f, cfg.get("note_dur", 2.0)) * cfg.get("gain", 0.5), t0 + pos * beat)
        # мелодия
        if cfg.get("melody") and r.random() < cfg.get("melody_prob", 0.7):
            pos = 0.0
            while pos < beats_per_bar - 0.4:
                if r.random() < 0.72:
                    m = root + scale[int(r.integers(0, len(scale)))] + cfg.get("mel_oct", 24)
                    add(buf, cfg["mel_inst"](midi(m), cfg.get("mel_dur", 2.5)) * cfg.get("mel_gain", 0.45), t0 + pos * beat)
                pos += cfg.get("mel_step", 1.0)
    buf = reverb(buf, cfg.get("wet", 0.3), cfg.get("decay", 2.2))
    out = fold_tail(buf, int(length * SR))
    return out


TRACKS = {
    "winter_lake": dict(bpm=62, bars=16, root=57, seed=11, scale=[0, 3, 5, 7, 10, 12, 15], prog=[(0, (0, 3, 7, 12)), (-4, (0, 4, 7, 11)), (-2, (0, 3, 7, 10)), (-5, (0, 4, 7, 12))],
                        inst=bell, pattern=[(0, 0), (0.75, 2), (1.5, 1), (2.5, 3), (3.25, 2)], note_dur=3.0, gain=0.28, melody=True, mel_inst=bell, mel_gain=0.32, mel_dur=3.5, mel_step=2.0, pad_gain=0.5, wet=0.4, decay=3.0),
    "moon_lake": dict(bpm=54, bars=16, root=50, seed=12, scale=[0, 2, 3, 5, 7, 9, 10, 12], prog=[(0, (0, 3, 7)), (5, (0, 4, 7)), (3, (0, 4, 7)), (-2, (0, 4, 7))],
                      inst=piano, pattern=[(0, 0), (1.5, 2), (3, 1)], note_dur=4.0, gain=0.3, melody=True, mel_inst=piano, mel_gain=0.4, mel_dur=3.5, mel_step=2.0, pad_gain=0.9, wet=0.45, decay=3.4, bass=[0]),
    "swamp_mist": dict(bpm=70, bars=16, root=45, seed=13, scale=[0, 3, 5, 6, 7, 10, 12], prog=[(0, (0, 3, 7)), (3, (0, 4, 7)), (-2, (0, 4, 7)), (0, (0, 3, 7))],
                       inst=marimba, pattern=[(0, 0), (1, 1), (2, 2), (3, 1)], note_dur=1.6, gain=0.42, melody=True, mel_inst=marimba, mel_gain=0.4, mel_dur=1.5, mel_step=1.0, oct=12, warm=0.4, pad_gain=0.55, wet=0.35, decay=2.4, bass=[0, 2]),
    "rain_bay": dict(bpm=76, bars=16, root=52, seed=14, scale=[0, 2, 4, 7, 9, 12], prog=[(0, (0, 3, 7, 10)), (-4, (0, 4, 7, 11)), (-7, (0, 3, 7, 10)), (-5, (0, 4, 7, 10))],
                     inst=piano, pattern=[(0, 0), (0.5, 1), (1, 2), (1.5, 3), (2, 2), (2.5, 1), (3, 2), (3.5, 1)], note_dur=2.4, gain=0.26, melody=True, mel_inst=piano, mel_gain=0.32, mel_dur=3.0, mel_step=2.0, pad_gain=0.45, wet=0.42, decay=3.0),
    "hot_springs": dict(bpm=66, bars=16, root=55, seed=15, scale=[0, 2, 4, 6, 7, 9, 11], prog=[(0, (0, 4, 7, 11)), (2, (0, 4, 7, 11)), (-3, (0, 4, 7, 10)), (5, (0, 4, 7, 11))],
                        inst=bell, pattern=[(0, 0), (1, 1), (2, 3), (3, 2)], note_dur=2.6, gain=0.24, melody=True, mel_inst=bell, mel_gain=0.34, mel_dur=3.2, mel_step=1.5, pad_gain=0.7, wet=0.42, decay=3.2),
    "tropical_lagoon": dict(bpm=100, bars=16, root=55, seed=16, scale=[0, 2, 4, 7, 9, 12, 14], prog=[(0, (0, 4, 7)), (5, (0, 4, 7)), (7, (0, 4, 7)), (5, (0, 4, 7))],
                            inst=steel, pattern=[(0, 0), (0.75, 1), (1.5, 2), (2, 1), (2.75, 2), (3.5, 0)], note_dur=1.4, gain=0.34, melody=True, mel_inst=steel, mel_gain=0.4, mel_dur=1.4, mel_step=0.75, melody_prob=0.9, pad_gain=0.35, wet=0.3, decay=1.8, bass=[0, 1.5, 2.5]),
    "crimson_forest": dict(bpm=82, bars=16, root=57, seed=17, scale=[0, 2, 3, 5, 7, 8, 10, 12], prog=[(0, (0, 3, 7)), (-2, (0, 4, 7)), (-4, (0, 4, 7)), (-5, (0, 4, 7))],
                           inst=pluck_fast, pattern=[(0, 0), (0.5, 1), (1, 2), (1.5, 1), (2, 0), (2.5, 1), (3, 2), (3.5, 1)], note_dur=1.8, gain=0.5, melody=True, mel_inst=pluck_fast, mel_gain=0.55, mel_dur=1.6, mel_step=1.0, pad_gain=0.4, wet=0.32, decay=2.2, bass=[0, 2]),
    "aurora": dict(bpm=50, bars=12, root=53, seed=18, scale=[0, 2, 4, 6, 7, 9, 11, 14], prog=[(0, (0, 4, 7, 11)), (2, (0, 4, 7, 9)), (7, (0, 4, 7, 11)), (4, (0, 3, 7, 10))],
                   inst=bell, pattern=[(0, 0), (0.5, 1), (1, 2), (1.5, 3), (2, 2), (2.5, 3), (3, 1), (3.5, 0)], oct=24, note_dur=3.6, gain=0.16, melody=True, mel_inst=bell, mel_gain=0.26, mel_dur=4.0, mel_step=2.0, pad_gain=1.0, warm=1.5, wet=0.5, decay=4.0),
}


# ---------------------------------------------------------------- эффекты
def sfx_click():
    t = t_of(0.09)
    y = np.sin(2 * np.pi * 1200 * t) * np.exp(-t / 0.018) + 0.5 * np.sin(2 * np.pi * 1800 * t) * np.exp(-t / 0.01)
    return y


def sfx_hover():
    t = t_of(0.06)
    return np.sin(2 * np.pi * 900 * t) * np.exp(-t / 0.014) * 0.5


def sfx_back():
    t = t_of(0.16)
    f = 900 - 500 * t / 0.16
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.05)


def sfx_cast():
    n = noise(0.85)
    t = t_of(0.85)
    sweep = bandpass(n, 400, 3500, 1)
    fc = np.linspace(0, 1, len(t))
    env = np.sin(np.pi * fc) ** 1.5
    y = (highpass(n, 600) * (1 - fc) + highpass(n, 3200) * fc) * env
    return y * 0.7 + sweep * env * 0.3


def sfx_splash(dur=1.0, size=1.0):
    n = noise(dur)
    t = t_of(dur)
    body = lowpass(n, 1800 * size) * np.exp(-t / (0.16 * size + 0.05))
    spray = highpass(n, 2500) * np.exp(-t / 0.09) * 0.4
    y = body + spray
    for i in range(int(5 * size) + 2):
        st = rng.uniform(0.02, dur * 0.6)
        f = rng.uniform(500, 1400)
        tt = np.arange(int(0.12 * SR)) / SR
        b = np.sin(2 * np.pi * (f + 900 * tt) * tt) * np.exp(-tt / 0.03) * 0.25
        j = int(st * SR)
        y[j : j + len(b)] += b[: len(y) - j]
    return y * np.clip(t / 0.004, 0, 1)


def sfx_bite():
    t = t_of(0.35)
    f = 260 * np.exp(-t * 7) + 120
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.09)
    y += highpass(noise(0.35), 1500) * np.exp(-t / 0.03) * 0.3
    return y


def sfx_hook():
    t = t_of(0.4)
    y = highpass(noise(0.4), 800) * np.exp(-t / 0.03) * 0.8
    y += np.sin(2 * np.pi * 180 * t) * np.exp(-t / 0.08)
    y += 0.5 * np.sin(2 * np.pi * 540 * t) * np.exp(-t / 0.05)
    return y


def sfx_reel():
    """Тик-трещотка катушки: 1 секунда, петля."""
    y = np.zeros(SR)
    for i in range(14):
        j = int(i / 14 * SR)
        tt = t_of(0.02)
        c = (np.sin(2 * np.pi * (2400 + 300 * (i % 2)) * tt) + 0.4 * noise(0.02)) * np.exp(-tt / 0.004)
        y[j : j + len(c)] += c
    y += lowpass(noise(1), 300) * 0.05
    return y


def sfx_warn():
    t = t_of(0.3)
    return (np.sign(np.sin(2 * np.pi * 330 * t)) * 0.4 + np.sin(2 * np.pi * 495 * t) * 0.3) * np.exp(-t / 0.12)


def arpeggio(notes, gap, inst=bell, dur=0.9):
    buf = np.zeros(int((gap * len(notes) + dur) * SR))
    for i, m in enumerate(notes):
        add(buf, inst(midi(m), dur), i * gap)
    return buf


def sfx_catch():
    return reverb(arpeggio([72, 76, 79, 84, 88], 0.09, bell, 1.2), 0.25, 1.2)


def sfx_new_species():
    a = arpeggio([67, 72, 76, 79, 84, 88, 91], 0.075, bell, 1.6)
    return reverb(a, 0.3, 1.6)


def sfx_coin():
    t = t_of(0.5)
    y = np.sin(2 * np.pi * 1568 * t) * np.exp(-t / 0.1)
    y[int(0.07 * SR) :] += np.sin(2 * np.pi * 2093 * t[: len(t) - int(0.07 * SR)]) * np.exp(-t[: len(t) - int(0.07 * SR)] / 0.18)
    return y


def sfx_buy():
    buf = np.zeros(int(0.9 * SR))
    for i, m in enumerate([76, 83, 88]):
        add(buf, bell(midi(m), 0.6, 0.8), i * 0.07)
    return buf


def sfx_fail():
    t = t_of(0.7)
    f = 330 * np.exp(-t * 1.2)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.3) * 0.7


def sfx_escape():
    t = t_of(0.5)
    y = highpass(noise(0.5), 1200) * np.exp(-t / 0.07) * 0.6
    y += sfx_fail()[: len(t)] * 0.5
    return y


def sfx_flap():
    return sfx_splash(0.45, 0.4) * 0.8


def sfx_thunder():
    n = noise(3.6)
    t = t_of(3.6)
    y = lowpass(n, 180, 2) * (np.exp(-t / 0.9) * np.clip(t / 0.05, 0, 1))
    y += lowpass(n, 500, 1) * np.exp(-t / 0.25) * np.clip(t / 0.02, 0, 1) * 0.6
    mod = 0.6 + 0.4 * np.sin(2 * np.pi * 7 * t)
    return y * mod


def sfx_open():
    t = t_of(0.5)
    a = np.sin(2 * np.pi * 440 * t) * np.exp(-t / 0.2)
    a += np.sin(2 * np.pi * 660 * t) * np.exp(-t / 0.2) * 0.6
    return a


def sfx_reelin():
    t = t_of(0.7)
    return bandpass(noise(0.7), 900, 2200) * (0.5 + 0.5 * np.sin(2 * np.pi * 20 * t)) * np.exp(-t / 0.5) * 0.4


# ---------------------------------------------------------------- атмосфера (петли 12 сек)
AMB_LEN = 14.0


def lap(sec, level=1.0):
    n = noise(sec)
    t = t_of(sec)
    swell = 0.55 + 0.45 * np.sin(2 * np.pi * (t / 5.2) + 1.0) ** 2
    y = lowpass(n, 700) * swell * 0.55
    y += lowpass(highpass(n, 300), 1600) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 3.1)) ** 3 * 0.35
    return y * level


def wind(sec, level=1.0, fc=(180, 700)):
    n = noise(sec)
    t = t_of(sec)
    slow = 0.5 + 0.5 * np.sin(2 * np.pi * t / 9.0 + 0.4) * np.sin(2 * np.pi * t / 5.3)
    y = bandpass(n, fc[0], fc[1], 2) * (0.25 + slow)
    return y * level


def chirps(sec, count, lo=2500, hi=5200, gain=0.4, seed=0):
    r = np.random.default_rng(seed)
    y = np.zeros(int(sec * SR))
    for _ in range(count):
        start = r.uniform(0, sec - 1.0)
        base = r.uniform(lo, hi)
        for k in range(int(r.integers(2, 6))):
            d = r.uniform(0.05, 0.11)
            tt = np.arange(int(d * SR)) / SR
            f = base * (1 + 0.4 * np.sin(2 * np.pi * r.uniform(8, 22) * tt) + r.uniform(-0.3, 0.5) * tt / d)
            c = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / d) ** 2
            j = int((start + k * (d + 0.03)) * SR)
            y[j : j + len(c)] += c[: len(y) - j] * gain
    return y


def crickets(sec, freq=4300, gain=0.25):
    t = t_of(sec)
    pulse = (np.sin(2 * np.pi * 26 * t) > 0.2).astype(float) * (np.sin(2 * np.pi * 1.7 * t) > -0.3)
    y = np.sin(2 * np.pi * freq * t) * lowpass(pulse, 200, 1)
    y += 0.6 * np.sin(2 * np.pi * (freq * 1.12) * t) * lowpass(np.roll(pulse, int(0.31 * SR)), 200, 1)
    return y * gain


def frogs(sec, count, gain=0.5, seed=1):
    r = np.random.default_rng(seed)
    y = np.zeros(int(sec * SR))
    for _ in range(count):
        st = r.uniform(0, sec - 1.0)
        f0 = r.uniform(110, 190)
        for k in range(int(r.integers(1, 4))):
            d = 0.16
            tt = np.arange(int(d * SR)) / SR
            f = f0 * (1 + 0.5 * tt / d)
            c = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.4 + np.sin(2 * np.pi * np.cumsum(f) / SR)
            c = lowpass(c, 900) * np.sin(np.pi * tt / d) ** 1.4
            j = int((st + k * 0.22) * SR)
            y[j : j + len(c)] += c[: len(y) - j] * gain
    return y


def rain(sec, level=1.0):
    n = noise(sec)
    y = highpass(n, 1500) * 0.5 + bandpass(n, 500, 1500) * 0.35
    t = t_of(sec)
    return y * (0.85 + 0.15 * np.sin(2 * np.pi * t / 4.7)) * level


def bubbles(sec, count, seed=3, gain=0.4):
    r = np.random.default_rng(seed)
    y = np.zeros(int(sec * SR))
    for _ in range(count):
        st = r.uniform(0, sec - 0.4)
        f = r.uniform(250, 900)
        tt = np.arange(int(0.18 * SR)) / SR
        c = np.sin(2 * np.pi * np.cumsum(f * (1 + 6 * tt)) / SR) * np.exp(-tt / 0.04)
        j = int(st * SR)
        y[j : j + len(c)] += c[: len(y) - j] * gain * r.uniform(0.4, 1)
    return y


def gulls(sec, count, seed=5, gain=0.35):
    r = np.random.default_rng(seed)
    y = np.zeros(int(sec * SR))
    for _ in range(count):
        st = r.uniform(0, sec - 1.2)
        f0 = r.uniform(1300, 1800)
        d = 0.75
        tt = np.arange(int(d * SR)) / SR
        f = f0 * (1 + 0.45 * np.sin(np.pi * tt / d) - 0.2 * tt / d) + 40 * np.sin(2 * np.pi * 34 * tt)
        c = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / d) ** 0.7
        c += 0.35 * np.sin(2 * np.pi * np.cumsum(f * 2) / SR)
        j = int(st * SR)
        y[j : j + len(c)] += c[: len(y) - j] * gain
    return y


def owl(sec, count, seed=6, gain=0.4):
    r = np.random.default_rng(seed)
    y = np.zeros(int(sec * SR))
    for _ in range(count):
        st = r.uniform(0, sec - 2.2)
        for k, (d, f) in enumerate([(0.3, 360), (0.5, 320)]):
            tt = np.arange(int(d * SR)) / SR
            c = np.sin(2 * np.pi * f * tt) * np.sin(np.pi * tt / d) ** 1.5
            j = int((st + k * 0.42) * SR)
            y[j : j + len(c)] += c[: len(y) - j] * gain
    return y


def shimmer(sec, gain=0.3):
    t = t_of(sec)
    y = np.zeros_like(t)
    for f, ph in [(196, 0.0), (294, 1.3), (392, 2.1), (588, 0.7)]:
        y += np.sin(2 * np.pi * f * t + ph + 0.4 * np.sin(2 * np.pi * 0.11 * t)) * (0.5 + 0.5 * np.sin(2 * np.pi * (0.07 + f / 6000) * t + ph))
    return y * gain / 4


def ambient(name):
    L = AMB_LEN
    if name == "forest":
        y = lap(L, 0.8) + wind(L, 0.35) + chirps(L, 9, seed=1, gain=0.22)
    elif name == "mountain":
        y = lap(L, 0.55) + wind(L, 0.9, (200, 900)) + chirps(L, 2, 1800, 3200, 0.2, seed=2)
    elif name == "reed":
        y = lap(L, 0.7) + crickets(L, 4100, 0.16) + frogs(L, 4, 0.35, seed=4) + wind(L, 0.2)
    elif name == "winter":
        y = wind(L, 1.0, (120, 600)) + lap(L, 0.2) + shimmer(L, 0.1)
    elif name == "night":
        y = lap(L, 0.6) + crickets(L, 4700, 0.3) + owl(L, 2, seed=7, gain=0.32) + wind(L, 0.15)
    elif name == "swamp":
        y = lap(L, 0.5) + frogs(L, 11, 0.5, seed=8) + bubbles(L, 8, seed=9, gain=0.35) + crickets(L, 3800, 0.14)
    elif name == "rain":
        y = rain(L, 1.0) + lap(L, 0.5) + wind(L, 0.25)
    elif name == "hot":
        y = bubbles(L, 26, seed=10, gain=0.35) + lowpass(noise(L), 350) * 0.32 + wind(L, 0.3, (200, 800)) + lap(L, 0.3)
    elif name == "tropical":
        y = lap(L, 1.05) + gulls(L, 3, seed=11, gain=0.28) + wind(L, 0.2) + chirps(L, 5, 3200, 6000, 0.14, seed=12)
    elif name == "autumn":
        y = wind(L, 0.65, (250, 1100)) + lap(L, 0.5) + chirps(L, 4, seed=13, gain=0.18) + highpass(noise(L), 3500) * 0.05
    elif name == "aurora":
        y = wind(L, 0.7, (100, 500)) + shimmer(L, 0.7) + lap(L, 0.2)
    else:
        raise ValueError(name)
    return loopable(y, 2.0)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "sfx":
        only = "sfx"
    elif len(sys.argv) > 1 and sys.argv[1] == "music":
        only = "music"
    elif len(sys.argv) > 1 and sys.argv[1] == "ambient":
        only = "ambient"
    else:
        only = "all"
    if only in ("all", "sfx"):
        table = {
            "click": sfx_click, "hover": sfx_hover, "back": sfx_back, "cast": sfx_cast,
            "splash": lambda: sfx_splash(1.1, 1.0), "splash_small": lambda: sfx_splash(0.6, 0.5), "bite": sfx_bite, "hook": sfx_hook,
            "reel": sfx_reel, "warn": sfx_warn, "catch": sfx_catch, "new_species": sfx_new_species,
            "coin": sfx_coin, "buy": sfx_buy, "fail": sfx_fail, "escape": sfx_escape,
            "flap": sfx_flap, "thunder": sfx_thunder, "open": sfx_open, "reelin": sfx_reelin,
        }
        for name, fn in table.items():
            save(os.path.join(ROOT, "audio", "sfx", name + ".wav"), fn(), 0.8)
    if only in ("all", "ambient"):
        for name in ["forest", "mountain", "reed", "winter", "night", "swamp", "rain", "hot", "tropical", "autumn", "aurora"]:
            save(os.path.join(ROOT, "audio", "ambient_" + name + ".wav"), ambient(name), 0.7)
    if only in ("all", "music"):
        for name, cfg in TRACKS.items():
            save(os.path.join(ROOT, "audio", name + ".wav"), compose(cfg), 0.5)


if __name__ == "__main__":
    main()
