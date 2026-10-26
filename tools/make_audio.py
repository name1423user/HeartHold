#!/usr/bin/env python3
"""Hearthold の自作の音(警告音・効果音・昼夜の BGM)を合成して assets/audio/*.wav に書く。

使い方: python3 tools/make_audio.py
22050Hz・モノラル・16bit。乱数は固定なので、何度作っても同じ音になる。
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def note(freq, seconds, volume=0.5, shape="sine", attack=0.01, release=0.15):
    samples = []
    count = int(RATE * seconds)
    for i in range(count):
        t = i / RATE
        phase = 2 * math.pi * freq * t
        if shape == "sine":
            v = math.sin(phase)
        elif shape == "pluck":
            v = math.sin(phase) * 0.7 + math.sin(phase * 2) * 0.2 + math.sin(phase * 3) * 0.1
            v *= math.exp(-3.0 * t)
        elif shape == "horn":
            v = math.sin(phase) * 0.6 + math.sin(phase * 2) * 0.3 + math.sin(phase * 3) * 0.15
        else:
            v = math.sin(phase)
        env = 1.0
        if t < attack:
            env = t / attack
        elif t > seconds - release:
            env = max(0.0, (seconds - t) / release)
        samples.append(v * env * volume)
    return samples


def noise(seconds, volume=0.5, decay=20.0, seed=1):
    rng = random.Random(seed)
    out = []
    last = 0.0
    for i in range(int(RATE * seconds)):
        t = i / RATE
        last = last * 0.6 + rng.uniform(-1, 1) * 0.4
        out.append(last * math.exp(-decay * t) * volume)
    return out


def mix(*tracks):
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for track in tracks:
        for i, v in enumerate(track):
            out[i] += v
    return out


def concat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-6, max(abs(v) for v in samples))
    scale = min(1.0, 0.9 / peak)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * scale)) * 32767)) for v in samples))


def melody(notes, beat, shape, volume=0.4):
    out = []
    for freq, beats in notes:
        out.extend(note(freq, beat * beats, volume, shape, release=beat * beats * 0.5) if freq > 0 else silence(beat * beats))
    return out


# 音の高さ(Hz)
C4, D4, E4, F4, G4, A4, B4 = 261.6, 293.7, 329.6, 349.2, 392.0, 440.0, 493.9
C5, D5, E5, G5, A5 = 523.3, 587.3, 659.3, 784.0, 880.0
A3, C3, E3, G3, D3 = 220.0, 130.8, 164.8, 196.0, 146.8


def main():
    # 警告音(種類ごと)
    save("alert_raid", concat(note(220, 0.35, 0.6, "horn"), silence(0.05), note(220, 0.35, 0.6, "horn"), silence(0.05), note(196, 0.6, 0.6, "horn")))
    save("alert_applicant", concat(note(E5, 0.25, 0.5, "pluck"), note(G5, 0.25, 0.5, "pluck"), note(C5 * 2, 0.5, 0.5, "pluck")))
    save("alert_faint", concat(note(A4, 0.2, 0.5), note(F4, 0.2, 0.5), note(D4, 0.4, 0.5)))
    save("alert_hunger", concat(note(G4, 0.2, 0.4, "pluck"), silence(0.05), note(E4, 0.3, 0.4, "pluck")))
    save("alert_death", concat(note(A3, 0.5, 0.5, "horn"), note(F4 / 2, 0.5, 0.5, "horn"), note(E3, 0.9, 0.5, "horn")))
    save("alert_notice", note(A5, 0.15, 0.4, "pluck"))
    # 効果音
    save("sfx_chop", mix(noise(0.25, 0.8, 25.0, 2), note(110, 0.12, 0.6, "pluck")))
    save("sfx_dig", mix(noise(0.35, 0.9, 12.0, 3), note(70, 0.2, 0.4, "pluck")))
    save("sfx_build_done", concat(note(C5, 0.15, 0.4, "pluck"), note(E5, 0.15, 0.4, "pluck"), note(G5, 0.4, 0.4, "pluck")))
    # BGM(ループ)。昼は明るい長調、夜はゆっくりした短調
    day_notes = [(G4, 1), (A4, 1), (C5, 2), (A4, 1), (G4, 1), (E4, 2), (D4, 1), (E4, 1), (G4, 2), (A4, 1), (G4, 1), (E4, 2),
                 (G4, 1), (A4, 1), (C5, 2), (D5, 1), (C5, 1), (A4, 2), (G4, 1), (E4, 1), (D4, 2), (C4, 4)]
    day_bass = [(C3, 4), (A3 / 2, 4), (F4 / 4, 4), (G3, 4), (C3, 4), (A3 / 2, 4), (G3, 4), (C3, 4)]
    beat = 0.3
    save("bgm_day", mix(melody(day_notes, beat, "pluck", 0.4), melody(day_bass, beat, "sine", 0.25)))
    night_notes = [(A4, 2), (C5, 2), (E5, 4), (D5, 2), (C5, 2), (B4, 4), (A4, 2), (G4, 2), (E4, 4), (A4, 8)]
    night_bass = [(A3 / 2, 8), (E3, 8), (D3, 8), (A3 / 2, 8)]
    beat = 0.4
    save("bgm_night", mix(melody(night_notes, beat, "sine", 0.3), melody(night_bass, beat, "sine", 0.2)))


if __name__ == "__main__":
    main()
