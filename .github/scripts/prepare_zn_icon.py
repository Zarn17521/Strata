#!/usr/bin/env python3
"""Install the selected opaque 1024x1024 ZN icon in every app icon appearance."""
from pathlib import Path
import json
import struct
import shutil
import subprocess
import zlib
import sys
import plistlib

root = Path(__file__).resolve().parents[2]
source = root / "Resources" / "ZNIcon.png"
data = source.read_bytes()
if data[:8] != b"\x89PNG\r\n\x1a\n" or len(data) < 33 or data[12:16] != b"IHDR":
    raise SystemExit("ZNIcon.png must be a PNG.")
w, h, depth, colour = struct.unpack(">IIBB", data[16:26])
if (w,h,depth,colour) != (1024,1024,8,2):
    raise SystemExit("Use the provided opaque RGB 1024x1024 ZNIcon.png.")
def normalize_monochrome_png(data):
    offset = 8
    chunks = []
    while offset + 12 <= len(data):
        n = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset+4:offset+8]
        payload = data[offset+8:offset+8+n]
        if len(payload) != n:
            raise ValueError("Truncated PNG")
        crc = struct.unpack_from(">I", data, offset+8+n)[0]
        if zlib.crc32(kind + payload) & 0xffffffff != crc:
            raise ValueError("PNG checksum mismatch")
        if kind == b"IDAT":
            chunks.append(payload)
        offset += 12+n
    raw = zlib.decompress(b"".join(chunks))
    stride = 1 + 1024*3
    if len(raw) != 1024*stride:
        raise ValueError("Invalid PNG scanline count")
    # Only repair the known old encoder signature: Sub-filtered red-only data.
    if any(raw[y*stride] != 1 for y in range(1024)):
        return data
    if any(raw[y*stride+2:(y+1)*stride:3].strip(b"\x00") or
           raw[y*stride+3:(y+1)*stride:3].strip(b"\x00") for y in range(1024)):
        return data
    result = bytearray(raw)
    for y in range(1024):
        start=y*stride
        for x in range(1024):
            i=start+1+x*3
            result[i+1]=result[i+2]=result[i]
    def chunk(kind, payload):
        return struct.pack(">I", len(payload))+kind+payload+struct.pack(">I",zlib.crc32(kind+payload)&0xffffffff)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR",data[16:29]) +
            chunk(b"IDAT",zlib.compress(result,9)) + chunk(b"IEND",b""))

data = normalize_monochrome_png(data)
source.write_bytes(data)

def package_icons(app):
    # Explicit loose PNGs for IPA readers, alongside the compiled asset catalog.
    # Use distinct names so actool-generated primary icon assets stay untouched.
    variants = {"ZNPrimaryIcon.png":60, "ZNPrimaryIcon@2x.png":120,
                "ZNPrimaryIcon@3x.png":180, "ZNPrimaryIconPad.png":76,
                "ZNPrimaryIconPad@2x.png":152, "ZNPrimaryIconPadPro@2x.png":167}
    for name, pixels in variants.items():
        target=app/name
        subprocess.run(["sips","-s","format","png","-z",str(pixels),str(pixels),str(source),"--out",str(target)],check=True)
        png=target.read_bytes()
        if png[:8] != b"\x89PNG\r\n\x1a\n" or struct.unpack(">II",png[16:24]) != (pixels,pixels):
            raise SystemExit("Invalid packaged icon: "+name)
    plist=app/"Info.plist"
    with plist.open("rb") as stream:
        info=plistlib.load(stream)
    # Preserve alternate icons and all other actool metadata.
    for key, names in (("CFBundleIcons",["ZNPrimaryIcon"]),("CFBundleIcons~ipad",["ZNPrimaryIconPad","ZNPrimaryIconPadPro"])):
        primary=info.setdefault(key,{}).setdefault("CFBundlePrimaryIcon",{})
        primary["CFBundleIconName"]="AppIcon"
        primary["CFBundleIconFiles"]=names
    info["CFBundleIconFiles"]=["ZNPrimaryIcon"]
    info["CFBundleIconFile"]="ZNPrimaryIcon.png"
    with plist.open("wb") as stream:
        plistlib.dump(info,stream,fmt=plistlib.FMT_BINARY,sort_keys=False)
    print("Verified explicit IPA icon files and iPhone/iPad icon metadata.")

if len(sys.argv)>1:
    if len(sys.argv)!=3 or sys.argv[1]!="--package":
        raise SystemExit("Usage: prepare_zn_icon.py [--package APP_PATH]")
    package_icons(Path(sys.argv[2]))
    raise SystemExit(0)

for name in ("AppIcon", "AppIconGrey"):
    asset = root / "Resources" / "Assets.xcassets" / (name + ".appiconset")
    contents = json.loads((asset / "Contents.json").read_text())
    for entry in contents["images"]:
        shutil.copyfile(source, asset / entry["filename"])
for name, pixels in (("AppIconGrey60x60@2x.png",120),("AppIconGrey76x76@2x~ipad.png",152)):
    subprocess.run(["sips","-z",str(pixels),str(pixels),str(source),"--out",str(root/"Resources"/name)],check=True)
print("ZN icon applied to standard, dark, tinted and alternate icon slots.")
