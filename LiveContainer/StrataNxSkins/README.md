# Official photo-based NxNative controller skins

These are the ONLY photo sources for the two built-in styles. **Do not replace
these with the old vector-only synthetic design.**

Copy the four binary files from the supplied Strata photo-skin package into
this directory, keeping the names exactly as written:

- `PearlPortrait.png` — original user-provided 923 x 2000 white portrait PNG
- `PearlLandscape.jpg` — original user-provided 1792 x 1008 white landscape JPG
- `AmoledPortrait.png` — graphite/black recoloring of the same portrait photo
- `AmoledLandscape.jpg` — graphite/black recoloring of the same landscape photo

The source images retain their ORIGINAL geometry. Do not pre-swap buttons:
`StrataNxDrawRearrangedArtwork` uses the measured input coordinates to swap
Look/ABXY and relabel R/ZR, while the lower-left ZN logo is drawn separately.
This is identical in Portrait and Landscape.

Before Xcode archive, `.github/scripts/embed_nxnative_skins.py` converts the
binary images to a generated `LiveContainer/StrataNxPhotoData.h` header.
No network downloads, first-launch imports, or extra asset databases are
needed. The images are included in the compiled LiveContainerShared framework
and are cached in memory with the selected theme.

Until ALL FOUR binary files exist here, the build prints a warning and uses
the pre-existing vector fallback; it will not falsely claim that the exact
photo skins are already bundled.

To minimize RAM, only two full-resolution images are cached at once, and
Settings previews are rendered at one-third of source resolution.
