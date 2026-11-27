"""Build-time only: align supplied Switch photographs to existing hit targets."""
import cv2
import numpy as np
from prepare_nxnative_skins import prepare_photo

NAMES = ("SwitchNeonTouch.jpg", "SwitchNeonBluetooth.jpg",
         "SwitchPearlTouch.jpg", "SwitchPearlBluetooth.jpg")

def switch_photos(assets):
    present=[(assets/name).is_file() for name in NAMES]
    if not any(present):
        return {}
    if not all(present):
        raise ValueError("Upload all four Switch photo reference JPGs together")
    result={}
    for white, prefix, touch_name, blank_name in (
        (False, "switchNeon", NAMES[0], NAMES[1]),
        (True, "switchPearl", NAMES[2], NAMES[3])):
        touch=cv2.imread(str(assets/touch_name), cv2.IMREAD_COLOR)
        blank=cv2.imread(str(assets/blank_name), cv2.IMREAD_COLOR)
        if touch is None or blank is None:
            raise ValueError("Unreadable Switch skin photograph")
        touch=cv2.resize(touch,(1792,1008),interpolation=cv2.INTER_AREA)
        # Preserve the established native Look-above-ABXY mapping in previews.
        touch=prepare_photo(touch,False)
        h,w=blank.shape[:2]
        # Remove the baked settings gear: the real animated gear is a layer.
        mask=np.zeros((h,w),np.uint8)
        cy=.797 if white else .709
        cv2.ellipse(mask,(round(w*.5),round(h*cy)),
                    (round(w*.024),round(h*.042)),0,0,360,255,-1)
        blank=cv2.inpaint(blank,mask,5,cv2.INPAINT_TELEA)
        # Align panel seams and display edges; retain photo textures, not flat fills.
        srcx=[0,.054,.174,.199,.801,.826,.946,1] if white else [0,.041,.167,.193,.807,.833,.96,1]
        srcy=[0,.135,.168,.749,.86,1] if white else [0,.189,.213,.672,.759,1]
        dstx=[0,.059,.244,.258,.742,.756,.94,1]
        dsty=[0,.122,.168,.737,.865,1]
        x=np.interp(np.linspace(0,1,1792),dstx,srcx)*(w-1)
        y=np.interp(np.linspace(0,1,1008),dsty,srcy)*(h-1)
        mx,my=np.meshgrid(x.astype(np.float32),y.astype(np.float32))
        shell=cv2.remap(blank,mx,my,cv2.INTER_LINEAR,borderMode=cv2.BORDER_REPLICATE)
        for name,img in ((prefix+"Touch",touch),(prefix+"Blank",shell)):
            ok,data=cv2.imencode(".jpg",img,[cv2.IMWRITE_JPEG_QUALITY,94])
            if not ok: raise ValueError("Could not encode "+name)
            result[name]=data.tobytes()
    return result
