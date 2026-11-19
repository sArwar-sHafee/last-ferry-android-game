"""Render two short, non-looping pieces for encounters; assets ship in the APK."""
from pathlib import Path
import subprocess
import numpy as np

rate = 24000
folder = Path(__file__).resolve().parents[1] / "game/audio"
for name, duration, root in [("pursuit", 7.4, 73.416), ("undertow", 8.6, 58.27)]:
    t = np.arange(round(duration * rate)) / rate
    score = np.zeros_like(t)
    beats = [0, .75, 1.5, 2.15, 2.72, 3.22, 3.66, 4.05, 4.44, 4.85] if name == "pursuit" else [0, 1.4, 2.7, 3.45, 4.5, 5.65]
    for i, beat in enumerate(beats):
        u = np.maximum(0, t - beat)
        note = root * (1, 1.05946, 1.4983, 1.4142)[i % 4]
        env = (t >= beat) * (1 - np.exp(-u * 22)) * np.exp(-u * 2.8)
        score += env * (.22*np.sin(2*np.pi*note*u) + .10*np.sin(2*np.pi*2.003*note*u) + .05*np.sin(2*np.pi*5.01*note*u))
    swell = np.sin(np.pi*t/duration)**2
    bowed = np.sin(2*np.pi*root*3*t + .4*np.sin(t*22)) + .45*np.sin(2*np.pi*root*3.13*t)
    score += .13*swell*bowed*(.75+.25*np.cos(t*8.5))
    stereo = np.stack([score, .86*score+.14*np.roll(score, 193)], axis=1)
    stereo *= np.minimum(1, (duration-t)*2)[:, None]
    subprocess.run(["ffmpeg","-loglevel","error","-y","-f","f32le","-ar",str(rate),"-ac","2","-i","-","-c:a","libvorbis","-q:a","4",str(folder/(name+".ogg"))],input=stereo.astype("<f4").tobytes(),check=True)
