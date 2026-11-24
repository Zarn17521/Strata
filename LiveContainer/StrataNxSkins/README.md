# Official photo-based NxNative controller skins

These are the ONLY photo sources for the two built-in styles. **Do not replace
these with the old vector-only synthetic design.**

Copy the four binary files from the supplied Strata photo-skin package into
this directory, keeping the names exactly as written:

- `PearlPortrait.png` — original user-provided 923 x 2000 white portrait PNG
- `PearlLandscape.jpg` — original user-provided 1792 x 1008 white landscape JPG
- `AmoledPortrait.png` — graphite/black recoloring of the same portrait photo
- `AmoledLandscape.jpg` — graphite/black recoloring of the same landscape photo

The source images retain their ORIGINAL geometry. Keep the originals unchanged. The build-time preparation isolates each circular control, repairs its previous background, and swaps R/ZR lettering. Portrait ABXY is raised and resized to preserve + and gear. AMOLED is recoloured from the corrected Pearl geometry for readable graphite buttons. The supplied dark photos remain reference assets. Prepared photos are marked to skip runtime rearrangement; ZN remains a separate native overlay. Both orientations share the measured native hit centres.

Before Xcode archive, `.github/scripts/embed_nxnative_skins.py` converts the
binary images to a generated `LiveContainer/StrataNxPhotoData.h` header.
No first-launch imports or extra asset databases are needed. OpenCV runs only on the build runner. The images are included in the compiled LiveContainerShared framework
and are cached in memory with the selected theme.

Until ALL FOUR binary files exist here, the build prints a warning and uses
the pre-existing vector fallback; it will not falsely claim that the exact
photo skins are already bundled.

To minimize RAM, only two full-resolution images are cached at once, and
Settings previews are rendered at one-third of source resolution.
