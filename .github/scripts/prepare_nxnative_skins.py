"""Prepare final photo skins once during the build, not while playing."""
import cv2
import numpy as np

# A, B, X, Y. Normalized geometry measured in the original photographs.
LAYOUT = {
    True: dict(size=(923,2000), face=[(.8743,.6459),(.7469,.7041),(.7482,.5817),(.6169,.6459)],
        final=[(.857,.817),(.747,.868),(.748,.766),(.638,.817)],
        look=(.7469,.8361), newlook=(.7466,.6449), radius=78, stick_radius=130, face_scale=.82,
        shoulders=[(.119,.504),(.283,.504),(.719,.504),(.879,.504)], glyph=(32,18),
        dpad=(.249,.646), left=(.2438,.8379), bottom=[(.3452,.9357),(.4999,.9363),(.6559,.9339)]),
    False: dict(size=(1792,1008), face=[(.8856,.3613),(.8401,.4411),(.8401,.2804),(.7945,.3613)],
        final=[(.8836,.6185),(.8381,.6983),(.8381,.5376),(.7925,.6185)],
        look=(.8381,.6185), newlook=(.8401,.3613), radius=46, stick_radius=86, face_scale=1.,
        shoulders=[(.1318,.1827),(.2038,.1827),(.8006,.1827),(.8757,.1827)], glyph=(27,11),
        dpad=(.159,.362), left=(.159,.6161), bottom=[(.4122,.7982),(.4999,.7982),(.5869,.7994)])
}

def prepare_photo(source, portrait):
    cfg=LAYOUT[portrait]; w,h=cfg['size']
    if source is None or source.shape[:2]!=(h,w):
        raise ValueError(f"Expected original photo of {w}x{h}")
    def pt(p): return (round(p[0]*w),round(p[1]*h))
    mask=np.zeros((h,w),np.uint8)
    for p in cfg['face']: cv2.circle(mask,pt(p),cfg['radius']+4,255,-1)
    cv2.circle(mask,pt(cfg['look']),cfg['stick_radius']+3,255,-1)
    gx,gy=cfg['glyph']; right=cfg['shoulders'][2:]
    for p in right:
        x,y=pt(p);cv2.rectangle(mask,(x-gx-3,y-gy-3),(x+gx+3,y+gy+3),255,-1)
    # Reconstruct only previous button silhouettes; never clear a large
    # rectangle that can cover the gear, +, or neighbouring buttons.
    result=cv2.inpaint(source,mask,5,cv2.INPAINT_TELEA)
    def copy_circle(origin,dest,radius,scale=1.):
        x,y=pt(origin); dx,dy=pt(dest);r=radius
        patch=source[y-r:y+r+1,x-r:x+r+1].copy()
        yy,xx=np.ogrid[-r:r+1,-r:r+1]
        a=np.clip((r-np.sqrt(xx*xx+yy*yy))/7,0,1).astype(np.float32)
        nr=round(r*scale); side=2*nr+1
        if scale!=1:
            patch=cv2.resize(patch,(side,side),interpolation=cv2.INTER_AREA)
            a=cv2.resize(a,(side,side),interpolation=cv2.INTER_AREA)
        roi=result[dy-nr:dy+nr+1,dx-nr:dx+nr+1]
        if roi.shape!=patch.shape: raise ValueError('Button outside canvas')
        roi[:]=np.rint(roi*(1-a[...,None])+patch*a[...,None]).astype(np.uint8)
    copy_circle(cfg['look'],cfg['newlook'],cfg['stick_radius'])
    for p,d in zip(cfg['face'],cfg['final']): copy_circle(p,d,cfg['radius'],cfg['face_scale'])
    # Swap the actual printed shoulder glyphs without replacing their rims.
    for orig,dest in zip(right,right[::-1]):
        x,y=pt(orig);dx,dy=pt(dest)
        patch=source[y-gy:y+gy+1,x-gx:x+gx+1]
        yy,xx=np.ogrid[-gy:gy+1,-gx:gx+1]
        a=np.clip(np.minimum(gx-np.abs(xx),gy-np.abs(yy))/5,0,1).astype(np.float32)[...,None]
        roi=result[dy-gy:dy+gy+1,dx-gx:dx+gx+1]
        roi[:]=np.rint(roi*(1-a)+patch*a).astype(np.uint8)
    return result

def amoled_from_pearl(source, portrait):
    cfg=LAYOUT[portrait];w,h=cfg['size']
    gray=cv2.cvtColor(source,cv2.COLOR_BGR2GRAY).astype(np.float32)
    control=np.zeros((h,w),np.uint8); lettering=np.zeros_like(control)
    def pt(p): return (round(p[0]*w),round(p[1]*h))
    def circle(m,p,r): cv2.circle(m,pt(p),r,255,-1)
    def rect(m,p,rx,ry):
        x,y=pt(p);cv2.rectangle(m,(x-rx,y-ry),(x+rx,y+ry),255,-1)
    def pill(m,p,rx,ry):
        x,y=pt(p);dx=max(0,rx-ry)
        cv2.rectangle(m,(x-dx,y-ry),(x+dx,y+ry),255,-1)
        cv2.circle(m,(x-dx,y),ry,255,-1);cv2.circle(m,(x+dx,y),ry,255,-1)
    for p in cfg['final']:
        circle(control,p,round((cfg['radius']-3)*cfg['face_scale']))
        rect(lettering,p,25 if portrait else 17,25 if portrait else 17)
    for p in (cfg['left'],cfg['newlook']): circle(control,p,cfg['stick_radius']-3)
    for p in cfg['shoulders']:
        pill(control,p,77 if portrait else 43,37 if portrait else 21)
        rect(lettering,p,29 if portrait else 24,18 if portrait else 11)
    x,y=pt(cfg['dpad']);r=183 if portrait else 102;a=57 if portrait else 33
    cv2.rectangle(control,(x-a,y-r),(x+a,y+r),255,-1)
    cv2.rectangle(control,(x-r,y-a),(x+r,y+a),255,-1)
    for dx,dy in ((-r*.60,0),(r*.60,0),(0,-r*.60),(0,r*.60)):
        rect(lettering,((x+dx)/w,(y+dy)/h),30 if portrait else 19,30 if portrait else 19)
    for i,p in enumerate(cfg['bottom']):
        circle(control,p,(60 if portrait else (45 if i==1 else 36)))
        rect(lettering,p,32 if portrait else 21,32 if portrait else 21)
    control=cv2.GaussianBlur(control,(0,0),2).astype(np.float32)/255
    lettering=cv2.GaussianBlur(lettering,(0,0),1).astype(np.float32)/255
    # Recolour the corrected Pearl art, retaining its geometry and bevels.
    # The previous supplied dark files lacked readable button lettering.
    shell=gray*0.045
    key=np.interp(gray,[0,65,145,205,255],[4,16,35,58,105])
    value=shell*(1-control)+key*control
    white=np.clip((205-gray)/65,0,1)*lettering*control
    value=value*(1-white)+245*white
    return np.clip(np.stack([value*1.08,value*1.035,value],axis=-1),0,255).astype(np.uint8)

def button_free_photo(image, portrait):
    cfg=LAYOUT[portrait]; w,h=cfg['size']
    mask=np.zeros((h,w),np.uint8)
    def pt(p): return (round(p[0]*w),round(p[1]*h))
    def circle(p,r): cv2.circle(mask,pt(p),r,255,-1)
    def pill(p,rx,ry):
        x,y=pt(p); dx=max(0,rx-ry)
        cv2.rectangle(mask,(x-dx,y-ry),(x+dx,y+ry),255,-1)
        cv2.circle(mask,(x-dx,y),ry,255,-1)
        cv2.circle(mask,(x+dx,y),ry,255,-1)
    for p in cfg['final']:
        circle(p,round(cfg['radius']*cfg['face_scale'])+5)
    for p in (cfg['left'],cfg['newlook']):
        circle(p,cfg['stick_radius']+6)
    for p in cfg['shoulders']:
        pill(p,82 if portrait else 49,42 if portrait else 25)
    x,y=pt(cfg['dpad']); r=188 if portrait else 107; a=63 if portrait else 39
    cv2.rectangle(mask,(x-a,y-r),(x+a,y+r),255,-1)
    cv2.rectangle(mask,(x-r,y-a),(x+r,y+a),255,-1)
    for i,p in enumerate(cfg['bottom']):
        circle(p,(65 if portrait else (48 if i==1 else 41)))
    return cv2.inpaint(image,mask,5,cv2.INPAINT_TELEA)

def final_assets(assets):
    output={}
    for portrait,suffix,ext in [(True,'Portrait','.png'),(False,'Landscape','.jpg')]:
        original=cv2.imread(str(assets/('Pearl'+suffix+ext)),cv2.IMREAD_COLOR)
        dark_reference=cv2.imread(str(assets/('Amoled'+suffix+ext)),cv2.IMREAD_COLOR)
        w,h=LAYOUT[portrait]['size']
        if dark_reference is None or dark_reference.shape[:2]!=(h,w):
            raise ValueError('Missing or invalid AMOLED reference: '+suffix)
        pearl=prepare_photo(original,portrait)
        dark=amoled_from_pearl(pearl,portrait)
        for theme,image in [('pearl',pearl),('amoled',dark)]:
            options=[cv2.IMWRITE_PNG_COMPRESSION,6] if portrait else [cv2.IMWRITE_JPEG_QUALITY,96]
            ok,data=cv2.imencode(ext,image,options)
            if not ok: raise ValueError('Could not encode '+theme+suffix)
            output[theme+suffix]=data.tobytes()
            blank=button_free_photo(image,portrait)
            ok,data=cv2.imencode(ext,blank,options)
            if not ok: raise ValueError('Could not encode blank '+theme+suffix)
            output[theme+suffix+'Blank']=data.tobytes()
    return output
