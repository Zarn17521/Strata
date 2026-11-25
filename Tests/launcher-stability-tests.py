#!/usr/bin/env python3
"""Static regression checks for launcher artwork and layout identity rules."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
store = (ROOT / "LiveContainerSwiftUI/Views/LiveBoardArtworkStore.swift").read_text()
switchboard = (ROOT / "LiveContainerSwiftUI/Views/StrataSwitchboard.swift").read_text()

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
    "redundant tile identity override removed": ".id(key)" not in switchboard,
    "launcher work does not restart on a fixed timer": "DispatchQueue.main.asyncAfter" not in switchboard,
    "failed launches have an explicit recovery signal": "launchFailedNotification" in switchboard and "launchFailedNotification" in (ROOT / "LiveContainerSwiftUI/Views/AppList/LCAppListView.swift").read_text(),
}

failed = [name for name, passed in checks.items() if not passed]
for name, passed in checks.items():
    print(("PASS" if passed else "FAIL") + ": " + name)
if failed:
    raise SystemExit(1)
