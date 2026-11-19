"""Synthesize the harbor's original score, room ambience, and mechanical cues."""
from pathlib import Path
import subprocess
import numpy as np
from scipy.signal import butter, sosfilt
R=22050
rng=np.random.default_rng(441)
out=Path(__file__).resolve().parents[1]/"game/audio"
def timeline(seconds):
    return np.arange(round(seconds*R))/R
def tone(t,f):
    return np.sin(2*np.pi*f*t)
def noise(t,hz):
    n=sosfilt(butter(2,hz,fs=R,output="sos"),rng.standard_normal(len(t)))
    return n/max(abs(n).max(),1e-6)
def save(name,a):
    # Raw stereo comes through stdin, so the operating-system drive needs no scratch file.
    if a.ndim==1:a=np.stack([a,a],axis=1)
    a=np.clip(a,-.97,.97)
    subprocess.run(["ffmpeg","-hide_banner","-loglevel","error","-y","-f","f32le","-ar",str(R),"-ac","2","-i","-","-c:a","libvorbis","-q:a","4",str(out/(name+".ogg"))],input=a.astype("<f4").tobytes(),check=True)
def horn(t,f):
    env=(1-np.exp(-t*5))*np.minimum(1,np.maximum(0,t[-1]-t)*2.4)
    wob=t+.00045*np.sin(2*np.pi*t*2)
    return env*(tone(wob,f)+.52*tone(wob,f*2)+.31*tone(wob,f*3.006)+.14*tone(wob,4*f))*0.20
for i,(name,low) in enumerate([("estuary",55),("pumphall",48),("lantern",73.416)]):
    t=timeline(32);channels=[]
    for side in range(2):
        surf=noise(t,650+i*350)*(.14+.10*np.sin(2*np.pi*t/8+side*.22)**3)
        wind=noise(t,145)*.22
        chord=(tone(t,low)+.39*tone(t,1.5*low)+.19*tone(t,2*low))* (.045+.025*tone(t,.0625))
        for j,f in enumerate((low*3,low*4,low*4.5,low*3.5625)):
            local=(t-4*j-2)%32
            chord+=tone(local,f+.06*side)*np.exp(-local*.44)*(1-np.exp(-local*3))*.047
        if i==1: chord+=np.maximum(0,tone(t,.625))**5 * noise(t,420)*.18
        a=surf+wind+chord
        fade=np.minimum(1,np.minimum(t,t[-1]-t)*2.5)
        channels.append(a*fade)
    save(name,np.stack(channels,axis=1))
for name,dur,f in [("engage",.32,147),("step",.12,71),("land",.22,52),("splash",.85,110),(" ratchet".strip(),.18,490),("glass",.66,617),("flow",.49,186),("crate",.28,83),("save",1.3,293.66),("signal",2.6,116.54)]:
    t=timeline(dur)
    if name=="signal":a=horn(t,f)
    elif name in ("glass","save"):
        a=(tone(t,f)+.38*tone(t,f*2.01)+.23*tone(t,f*2.99))*.23*np.exp(-t*4)*(1-np.exp(-t*40))
    else:
        a=(.65*noise(t,1000 if name!="splash" else 3500)+.24*tone(t,f*np.exp(-t*.6))+.08*tone(t,f*2.4))*np.exp(-t*3.8/dur)*(1-np.exp(-t*160))
    save(name,a*np.minimum(1,(dur-t)*40))
t=timeline(18);a=np.zeros_like(t)
for beat,notes in [(0,(146.83,220)),(3,(164.81,246.94)),(6,(196,293.66)),(9,(220,329.63)),(12,(146.83,220,293.66,369.99))]:
    local=t-beat;env=np.where(local>=0,(1-np.exp(-np.maximum(local,0)*2))*np.exp(-np.maximum(local,0)*.42),0)
    for f in notes:a+=env*(tone(local,f)+.24*tone(local,f*2.003))*.09
save("homecoming",a*np.minimum(1,(18-t)*2))
