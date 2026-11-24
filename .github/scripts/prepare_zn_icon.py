#!/usr/bin/env python3
"""Install the selected opaque 1024x1024 ZN icon in every app icon appearance."""
from pathlib import Path
import json
import struct
import shutil
import subprocess

root = Path(__file__).resolve().parents[2]
source = root / "Resources" / "ZNIcon.png"
data = source.read_bytes()
if data[:8] != b"\x89PNG\r\n\x1a\n" or len(data) < 33 or data[12:16] != b"IHDR":
    raise SystemExit("ZNIcon.png must be a PNG.")
w, h, depth, colour = struct.unpack(">IIBB", data[16:26])
if (w,h,depth,colour) != (1024,1024,8,2):
    raise SystemExit("Use the provided opaque RGB 1024x1024 ZNIcon.png.")
for name in ("AppIcon", "AppIconGrey"):
    asset = root / "Resources" / "Assets.xcassets" / (name + ".appiconset")
    contents = json.loads((asset / "Contents.json").read_text())
    for entry in contents["images"]:
        shutil.copyfile(source, asset / entry["filename"])
for name, pixels in (("AppIconGrey60x60@2x.png",120),("AppIconGrey76x76@2x~ipad.png",152)):
    subprocess.run(["sips","-z",str(pixels),str(pixels),str(source),"--out",str(root/"Resources"/name)],check=True)
print("ZN icon applied to standard, dark, tinted and alternate icon slots.")
