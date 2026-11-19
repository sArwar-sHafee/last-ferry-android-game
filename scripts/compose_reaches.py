"""Render original short looping chapter ambiences from surf, machinery and bird motifs."""
from pathlib import Path
import subprocess
import numpy as np
from scipy.signal import butter, sosfilt

rate = 22050
t = np.arange(rate * 18) / rate
out = Path(__file__).resolve().parents[1] / "game/audio"
# Wind cutoff, pulse spacing, resonant frequency, decay, sweep, water intensity.
profiles = [
    (530, 6, 248, .7, -65, .55), (310, 1.5, 68, 4, -12, .32),
    (2700, .75, 1680, 11, 430, .12), (820, 3, 140, 9, -40, .55),
    (1600, 6, 48, 1, -10, .85), (720, 1.5, 208, 19, -45, .18),
    (490, .375, 180, 24, -80, .18), (1100, .5, 71, 19, -35, .21),
    (290, 1.125, 57, 4, -14, .25), (780, 3, 790, 8, 120, .17),
    (850, 3, 610, 2, 4, .12), (680, .75, 135, 17, -40, .20),
    (400, 4.5, 390, 3, 8, .24), (2200, 6, 44, .9, -9, .81),
    (520, 9, 138, .5, 1, .31)]
# Each entry specifies an audible foreground event, in addition to the room tone.
# Times and pitches are fixed so the chapter beds remain reproducible.
motifs = [
    ("gull", [2, 2.6, 11], 720), ("engine", [1, 10], 41),
    ("birds", [.9, 2.2, 5.7, 9, 9.4, 14], 1500), ("drip", [2, 3.2, 7.4, 15.5], 680),
    ("breaker", [1, 7.5, 13], 0), ("chain", [2, 2.13, 2.4, 7, 7.18, 14], 340),
    ("rail", list(np.arange(.3, 17, .72)), 115), ("hooves", list(np.arange(.2, 17, .52)), 78),
    ("pressure", [1, 5.5, 10, 14.5], 60), ("echo", [1, 6.4, 12], 940),
    ("glass", [2, 6, 11, 15], 790), ("slats", list(np.arange(1, 17, 1.2)), 162),
    ("bell", [3, 12], 518), ("thunder", [1, 8, 14], 35), ("horn", [4, 12], 108)]
def foreground(index, side, noise):
    kind, times, pitch = motifs[index]
    result = np.zeros_like(t)
    for n, onset in enumerate(times):
        local = np.maximum(0, t - onset - side*.012)
        attack = 1 - np.exp(-local * 65)
        pitch0 = pitch*(1 + .025*(n%3))
        if kind in ("gull", "birds"):
            bend = 200 if kind == "birds" else -95
            event = np.sin(2*np.pi*(pitch0*local+bend*np.sin(local*6))) * np.exp(-local*4)
        elif kind in ("breaker", "pressure", "thunder"):
            rate0 = 1.1 if kind == "breaker" else 2.0
            event = (noise*2 + .24*np.sin(2*np.pi*pitch0*local))*local*5*np.exp(-local*rate0)
        elif kind in ("hooves", "rail", "slats", "chain"):
            event = np.zeros_like(t)
            for delay in (0, .13 if kind=="hooves" else .08):
                beat = np.maximum(0,local-delay)
                event += (1-np.exp(-beat*150))*np.exp(-beat*20)*(noise+.9*np.sin(2*np.pi*pitch0*beat))
        elif kind in ("engine", "horn"):
            env = (1-np.exp(-local*1.4))*np.exp(-local*.65)
            phase = 2*np.pi*pitch0*local
            event = env*(np.sin(phase)+.56*np.sin(phase*2)+.22*np.sin(phase*3))
        else:
            event = np.sin(2*np.pi*pitch0*local)*np.exp(-local*(5 if kind in ("drip","echo") else 2))
            event += .45*np.sin(2*np.pi*pitch0*2.41*local)*np.exp(-local*4)
            if kind=="echo":
                for delay in (.24,.49):
                    beat = np.maximum(0,local-delay)
                    event += .4*np.sin(2*np.pi*pitch0*beat)*np.exp(-beat*6)
        result += attack*event
    return result

for index, (hz, period, freq, decay, sweep, water) in enumerate(profiles):
    rng = np.random.default_rng(1400 + index)
    channels = []
    for side in range(2):
        noise = sosfilt(butter(2, hz, fs=rate, output="sos"), rng.normal(size=len(t)))
        noise /= np.max(np.abs(noise))
        phase = (t + side * .025) % period
        pulse = np.exp(-phase * decay) * np.minimum(1, phase * 25)
        resonance = np.sin(2*np.pi*(freq*phase + sweep*phase**2*.5))
        wind = noise*(.16 + water*(.55+.45*np.cos(2*np.pi*t/6))**2)
        fade = np.minimum(1, np.minimum(t, t[-1]-t)*8)
        channels.append((.70*wind + .09*pulse*resonance + .21*foreground(index,side,noise))*fade)
    subprocess.run(["ffmpeg","-loglevel","error","-y","-f","f32le","-ar",str(rate),
                    "-ac","2","-i","-","-c:a","libvorbis",str(out/f"reach{index:02}.ogg")],
                   input=np.stack(channels,axis=1).astype("<f4").tobytes(),check=True)
