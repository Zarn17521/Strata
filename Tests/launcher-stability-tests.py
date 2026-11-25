#!/usr/bin/env python3
"""Static regression checks for launcher artwork and layout identity rules."""
from pathlib import Path
import hashlib
import re

ROOT = Path(__file__).resolve().parents[1]
store = (ROOT / "LiveContainerSwiftUI/Views/LiveBoardArtworkStore.swift").read_text()
switchboard = (ROOT / "LiveContainerSwiftUI/Views/StrataSwitchboard.swift").read_text()
icons = (ROOT / "LiveContainerSwiftUI/Views/LiveBoardIconStore.swift").read_text()
built_in_skins = (ROOT / "LiveContainerSwiftUI/Views/StrataNxBuiltInSkins.swift").read_text()
guest_controls = (ROOT / "LiveContainer/StrataGuestControls.m").read_text()
settings = (ROOT / "LiveContainerSwiftUI/Views/StrataSettingsApp.swift").read_text()

theme_ids = re.findall(r'\.init\(id: "([^"]+)"', built_in_skins)
artwork_root = ROOT / "Resources/NxThemeArtwork"
artwork_files = {f"{theme}-{orientation}.jpg" for theme in theme_ids for orientation in ("portrait", "landscape")}
project = (ROOT / "LiveContainer.xcodeproj/project.pbxproj").read_text()

checks = {
    "thumbnail cache is independent": "private let thumbnailCache = NSCache<NSString, UIImage>()" in store,
    "thumbnail decode is bounded": "thumbnail ? 192" in store,
    "thumbnail budget is bounded": "thumbnailCache.totalCostLimit = lowMemory ? 512 * 1024 : 2 * 1024 * 1024" in store,
    "thumbnail cache is trimmed": "thumbnailCache.removeAllObjects()" in store,
    "cover retains the previous decoded image": "loaded ?? lastReady" in switchboard,
    "mapped artwork avoids icon flash": "store.hasArtwork(for: key, kind: .cover, mode: \"switchboard\")" in switchboard,
    "layout appearance restores selection": "proxy.scrollTo(selectedKey, anchor: .center)" in switchboard,
    "library appearance preserves a still-valid selection": "if !filtered.contains(where: { liveBoardAppKey($0) == selectedKey })" in switchboard,
    "filter changes repair only invalid selections": ".onChange(of: filtered.map(liveBoardAppKey))" in switchboard,
    "Cinematic cover keeps a stable per-game identity": ".id(key)" in switchboard and ".id(liveBoardAppKey(selected))" in switchboard,
    "launcher work does not restart on a fixed timer": "DispatchQueue.main.asyncAfter" not in switchboard,
    "failed launches have an explicit recovery signal": "launchFailedNotification" in switchboard and "launchFailedNotification" in (ROOT / "LiveContainerSwiftUI/Views/AppList/LCAppListView.swift").read_text(),
    "custom app icon still takes precedence": icons.index("if let custom = LiveBoardAppCustomization.shared.image(app)") < icons.index("if let sideStore = app.appInfo as? BuiltInSideStoreAppInfo"),
    "SideStore uses its dedicated icon extraction": "sideStore.iconIsDarkIcon(dark)" in icons,
    "SideStore gets a stable builtin cache identity": "isBuiltInSideStore ? \"builtin:sidestore\"" in icons,
    "icon cache falls back when bundle path is unavailable": "bundlePath ?? app.bundleIdentifier" in icons,
    "Shelf long-press opens scrollable options": 'Button("Options…"' in switchboard and 'shelfOptionsApp = LiveBoardAppearanceSelection(app: app)' in switchboard and '.sheet(item: $shelfOptionsApp' in switchboard and 'Form {' in switchboard and 'appOptions(selection.app' in switchboard,
    "Skin Collection and Skin Studio are removed": "Skin Collections" not in settings and "Strata Custom Skin Studio" not in settings and "customskin" not in settings and not (ROOT / "LiveContainerSwiftUI/Views/StrataCustomSkinStudio.swift").exists(),
    "Built-in skin page follows the requested section order": settings.index('Toggle("Enable NxNative Skin"') < settings.index('Text("Game Display")') < settings.index('Section("Portrait & Landscape")') < settings.index('Text("Built-in Skin")'),
    "Built-in skin grid shows pictures for all 26 themes": 'LazyVGrid(columns: themeGridColumns' in settings and 'Image(uiImage: image)' in settings and 'ForEach(availableSkins)' in settings and 'originalSkins + StrataNxBuiltInSkin.all' in settings,
    "Custom Skin Main templates exist": all((ROOT / path).is_file() for path in (
        "LiveContainerSwiftUI/Assets.xcassets/MainLandscape.imageset/MainLandscape.jpg",
        "LiveContainerSwiftUI/Assets.xcassets/MainPortrait.imageset/MainPortrait.jpg",
        "LiveContainerSwiftUI/Assets.xcassets/ZeldaClassicEdition.imageset/ZeldaClassicEdition.jpg",
    )),
    "Custom skin layers persist in the shared app group": '"ZNCustomSkinMainLayersV1"' in (ROOT / "LiveContainer/StrataGuestControls.m").read_text(),
    "Guest skin renderer draws saved custom layers": '"ZNCustomSkinMainLayersV1"' in guest_controls and "drawCustomSkinLayersPortrait" in guest_controls,
    "26 unique character and Zelda game themes are listed once": len(re.findall(r'\.init\(id: "kirby"', built_in_skins)) == 1 and len(re.findall(r'\.init\(id:', built_in_skins)) == 26,
    "all 52 unique artwork files match the saved catalog IDs":
        len(artwork_files) == 52 and artwork_files == {p.name for p in artwork_root.glob("*.jpg")}
        and len({hashlib.sha256(p.read_bytes()).digest() for p in artwork_root.glob("*.jpg")}) == 52,
    "shared framework packages the artwork folder":
        "path = Resources/NxThemeArtwork" in project
        and "NxThemeArtwork in Resources" in project.split("E1292BD42DCA3B660065E12D /* Resources */ = {", 1)[1].split("runOnlyForDeploymentPostprocessing", 1)[0],
    "picker and gameplay use the same source with bounded picker decoding":
        'StrataNxSkinPreviewImageForTheme(!landscape, dark, layout, theme.id)' in settings
        and 'StrataNxLoadThemeArtwork(identifier, portrait, YES)' in guest_controls
        and 'StrataNxLoadThemeArtwork(self.themeIdentifier, portrait, NO)' in guest_controls
        and 'kCGImageSourceThumbnailMaxPixelSize: @640' in guest_controls,
    "theme colors are shared with the guest renderer": set(re.findall(r'\.init\(id: "([^"]+)"', built_in_skins)) == set(re.findall(r'@"([^"]+)": @\[@', guest_controls)),
    "controller presses glow and depress then release": all(key in guest_controls for key in ("zn.press.glow", "zn.press.down", "zn.press.lift")),
    "all themes share Classic Wide and Full Screen options": all(f'("{name}", "{tag}")' in settings for name, tag in (("Classic", "classic"), ("Wide", "wide"), ("Full Screen", "full"))) and '"StrataNxDisplayLayout"' in settings,
    "Full Screen keeps native touch while applying themed press feedback": 'fullScreenMode = YES' in guest_controls and "nativeRoleForPoint" in guest_controls and "StrataNxHookPadVisualEvents(); // native positions" in guest_controls,
}

failed = [name for name, passed in checks.items() if not passed]
for name, passed in checks.items():
    print(("PASS" if passed else "FAIL") + ": " + name)
if failed:
    raise SystemExit(1)
