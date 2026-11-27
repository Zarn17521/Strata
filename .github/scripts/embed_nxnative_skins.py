#!/usr/bin/env python3
"""Embed user-supplied NxNative skin PHOTOGRAPHS into LiveContainerShared.

The four compressed image files are part of the app source. Generate an
Objective-C header at build time so both the normal host process and the
LiveProcess guest extension can use exactly the same controller photographs.
Prepare individual controls with OpenCV at build time, not during gameplay.
"""
import base64
from pathlib import Path

root = Path(__file__).resolve().parents[2]
assets = root / "LiveContainer" / "StrataNxSkins"
header = root / "LiveContainer" / "StrataNxPhotoData.h"
inputs = {
    "pearlPortrait": "PearlPortrait.png",
    "pearlLandscape": "PearlLandscape.jpg",
    "amoledPortrait": "AmoledPortrait.png",
    "amoledLandscape": "AmoledLandscape.jpg",
}
missing = [n for n in inputs.values() if not (assets / n).is_file()]
if missing:
    header.unlink(missing_ok=True)
    print("::warning::Exact photo skins are not yet bundled. Upload to "
          "LiveContainer/StrataNxSkins: " + ", ".join(missing))
    print("Older builds keep the compatible vector fallback until uploaded.")
    raise SystemExit(0)

from prepare_nxnative_skins import final_assets

prepared = final_assets(assets)
from prepare_switch_photos import switch_photos
switch = switch_photos(assets)
prepared.update(switch)
parts = [
    "// Generated at build time. Do not commit this file.\n",
    "#pragma once\n",
    "#define STRATA_NX_PREPARED_PHOTOS 1\n",
    "#define STRATA_NX_BLANK_PHOTOS 1\n",
]
if switch:
    parts.append("#define STRATA_NX_SWITCH_PHOTOS 1\n")
for key, filename in list(inputs.items()) + [(k+'Blank',v+' (button-free)') for k,v in inputs.items()] + [(k,k) for k in switch]:
    binary = prepared[key]
    encoded = base64.b64encode(binary).decode("ascii")
    parts.append(f"static const char StrataSkin_{key}[] =\n")
    parts.extend(f'    "{encoded[i:i+256]}"\n'
                 for i in range(0, len(encoded), 256))
    parts.append(";\n")
    print(f"Embedded {filename}: {len(binary)} bytes")

parts.extend([
    "static NSData *StrataNxPackedPhotoData(BOOL portrait, BOOL dark) {\n",
    "    const char *data = dark\n",
    "        ? (portrait ? StrataSkin_amoledPortrait : StrataSkin_amoledLandscape)\n",
    "        : (portrait ? StrataSkin_pearlPortrait : StrataSkin_pearlLandscape);\n",
    "    return [[NSData alloc] initWithBase64EncodedString:\n",
    "        [NSString stringWithUTF8String:data] options:0];\n",
    "}\n",
    "static NSData *StrataNxPackedBlankPhotoData(BOOL portrait, BOOL dark) {\n",
    "    const char *data = dark\n",
    "        ? (portrait ? StrataSkin_amoledPortraitBlank : StrataSkin_amoledLandscapeBlank)\n",
    "        : (portrait ? StrataSkin_pearlPortraitBlank : StrataSkin_pearlLandscapeBlank);\n",
    "    return [[NSData alloc] initWithBase64EncodedString:\n",
    "        [NSString stringWithUTF8String:data] options:0];\n",
    "}\n",
])
if switch:
    parts.append("""static NSData *StrataNxPackedSwitchPhotoData(BOOL white, BOOL controls) {
    const char *data = white
        ? (controls ? StrataSkin_switchPearlTouch : StrataSkin_switchPearlBlank)
        : (controls ? StrataSkin_switchNeonTouch : StrataSkin_switchNeonBlank);
    return [[NSData alloc] initWithBase64EncodedString:
        [NSString stringWithUTF8String:data] options:0];
}
""")
header.write_text("".join(parts), encoding="ascii")
print(f"Generated {header.relative_to(root)} ({header.stat().st_size} bytes)")
