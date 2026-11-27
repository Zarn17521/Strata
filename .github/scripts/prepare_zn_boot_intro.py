"""Recreate the approved 5-second Elegant boot intro from its original vector
silhouette and original synthesized startup audio. No game assets or music."""
import math, subprocess, tempfile, wave
from pathlib import Path
import cv2
import numpy as np

W,H=1280,720
OUT=Path("Resources/ZN_Library_Boot_Intro_Elegant.mp4")
POSTER=Path("Resources/ZN_Boot_Intro_Elegant_Preview.png")
# Traced from the approved final logo artwork, not a font bundled into the app.
MAIN=[
[819,227,805,235,796,244,790,255,787,266,787,280,793,297,803,308,815,315,830,320,875,328,885,335,887,341,884,348,877,353,869,355,857,355,844,350,837,342,835,335,783,335,785,346,790,358,803,373,815,381,827,386,844,390,882,390,902,385,916,378,929,367,935,358,939,348,940,327,934,312,925,303,912,296,895,291,863,286,848,282,841,276,840,267,842,263,849,258,856,256,868,256,878,260,885,267,887,276,936,276,934,261,929,250,924,243,911,232,899,226,885,222,871,220,850,220,835,222],
[694,231,681,223,671,220,643,220,633,223,621,230,610,241,605,249,604,223,552,223,552,387,605,387,605,289,610,275,617,268,627,264,639,264,649,268,656,275,660,285,661,387,713,387,713,271,708,251,702,240],
[741,155,731,245,767,245,791,155],
[342,155,342,202,458,203,339,345,339,387,528,387,528,340,409,339,527,197,527,155]]
SUB=[
[792,518,810,547,810,567,816,567,816,548,835,518,826,519,814,540,811,538,799,518],
[733,518,733,567,739,567,740,548,751,548,761,567,769,567,758,548,765,543,768,537,768,529,765,523,755,518],
[681,518,663,567,670,567,672,559,675,554,694,554,697,558,699,566,707,567,689,518],
[604,518,604,567,610,567,611,548,622,548,632,567,640,567,629,548,636,543,639,537,639,529,636,523,626,518],
[541,518,541,567,564,567,572,564,576,559,577,552,575,547,567,542,574,536,575,529,573,524,569,520,563,518],
[505,518,505,567,511,567,511,518],
[449,518,449,567,479,567,478,561,455,560,455,518]]
HOLES=[
[739,524,751,523,759,526,762,531,760,539,752,543,740,543],
[685,525,693,547,692,549,677,548,683,527],
[610,524,622,523,630,526,633,531,631,539,623,543,611,543],
[547,546,563,545,569,549,570,556,565,561,548,562],
[547,524,564,524,568,528,568,535,561,540,548,540]]
def mask(outer, holes=()):
    a=np.zeros((H*3,W*3),np.uint8)
    for p in outer: cv2.fillPoly(a,[(np.array(p,np.int32).reshape(-1,2)*3)],255)
    for p in holes: cv2.fillPoly(a,[(np.array(p,np.int32).reshape(-1,2)*3)],0)
    return cv2.resize(a,(W,H),interpolation=cv2.INTER_AREA).astype(np.float32)/255
M,S=mask(MAIN),mask(SUB,HOLES)
X=np.arange(W,dtype=np.float32)[None,:]
def ease(a):
    a=np.clip(a,0,1);return a*a*(3-2*a)
def render(t):
    edge=274+ease((t-.20)/2.25)*731
    edge2=404+ease((t-2.2)/.85)*476
    m=M*ease((edge-X+16)/32);s=S*ease((edge2-X+12)/24)
    gl=np.exp(-((X-edge)/27)**2)*m*(1-ease((t-2.35)/.30))
    gl2=np.exp(-((X-edge2)/18)**2)*s*(1-ease((t-3.0)/.25))
    a=np.maximum(m,s);shine=gl+gl2
    gm=cv2.GaussianBlur(a,(0,0),14)
    rgb=np.zeros((H,W,3),np.uint8)
    rgb[:,:,0]=np.uint8(np.clip(255*a+gm*95*(1-ease((t-2.9)/.9))*(1-a),0,255))
    rgb[:,:,1]=np.uint8(np.clip(12*a+shine*135,0,255))
    rgb[:,:,2]=np.uint8(np.clip(25*a+shine*128,0,255))
    return rgb
def sound(path):
    sr=48000;n=sr*5;audio=np.zeros((n,2));rng=np.random.default_rng(24)
    def tone(start,length,f,amp,pan=0,decay=5):
        nn=min(int(length*sr),n-int(start*sr));tt=np.arange(nn)/sr
        env=(1-np.exp(-tt/.008))*np.exp(-tt*decay/max(length,.1))
        sig=(np.sin(2*np.pi*f*tt)+.24*np.sin(2*np.pi*f*2.01*tt)+.075*np.sin(2*np.pi*f*3.99*tt))*env*amp
        idx=int(start*sr);audio[idx:idx+nn,0]+=sig*math.sqrt((1-pan)/2);audio[idx:idx+nn,1]+=sig*math.sqrt((1+pan)/2)
    for st,f,p in [(.28,220,-.4),(.75,330,.2),(1.17,440,-.15),(1.55,550,.25),(1.91,660,-.2),(2.20,825,.25),(2.55,990,0)]:tone(st,.5,f,.12,p,4)
    for f,amp,p in [(164.81,.17,0),(329.63,.11,-.35),(493.88,.09,.3),(659.25,.055,0),(987.77,.032,.25)]:tone(3.03,1.8,f,amp,p,3.7)
    for st in [.28,1.45,2.55,3.03]:
        tt=np.arange(int(.12*sr))/sr;sig=(.045*rng.normal(size=tt.size)+.13*np.sin(2*np.pi*(110*tt-120*tt*tt)))*np.exp(-tt*48)
        i=int(st*sr);audio[i:i+len(tt)]+=sig[:,None]
    for delay,gain in [(0.075,.13),(.15,.07)]:
        d=int(sr*delay);audio[d:]+=audio[:-d].copy()*gain
    audio*=np.minimum(1,np.arange(n)[::-1]/(.15*sr))[:,None];audio=np.tanh(audio*1.3)
    with wave.open(str(path),'wb') as wf:
        wf.setnchannels(2);wf.setsampwidth(2);wf.setframerate(sr);wf.writeframes((audio*32767).astype('<i2').tobytes())
if __name__=="__main__":
    OUT.parent.mkdir(parents=True,exist_ok=True)
    if not OUT.exists():
        with tempfile.TemporaryDirectory() as td:
            wav=Path(td)/"intro.wav";sound(wav)
            p=subprocess.Popen(["ffmpeg","-y","-loglevel","error","-f","rawvideo","-pix_fmt","rgb24","-s","1280x720","-r","30","-i","-","-i",str(wav),"-c:v","libx264","-preset","fast","-crf","16","-pix_fmt","yuv420p","-c:a","aac","-b:a","160k","-t","5","-movflags","+faststart",str(OUT)],stdin=subprocess.PIPE)
            for i in range(150):p.stdin.write(render(i/30).tobytes())
            p.stdin.close()
            if p.wait()!=0:raise RuntimeError("ffmpeg intro generation failed")
    if not POSTER.exists():
        subprocess.run(["ffmpeg","-y","-loglevel","error","-ss","4.5","-i",str(OUT),"-frames:v","1",str(POSTER)],check=True)
