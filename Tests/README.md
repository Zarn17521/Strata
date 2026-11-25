# Focused regression checks

Run from the repository root on macOS with Xcode command-line tools installed. These checks do not launch guest apps or prove successful device JIT.

```sh
swiftc LiveContainerSwiftUI/Views/LiveBoardHomeLayout.swift Tests/home-widget-tests/main.swift -o /tmp/strata-home-check
/tmp/strata-home-check
swiftc -framework JavaScriptCore ShareExtension/StrataJITScriptSafety.swift Tests/jit-script-tests/main.swift -o /tmp/strata-script-check
/tmp/strata-script-check
clang -fobjc-arc -fblocks -framework Foundation -I LiveProcess -I MultitaskSupport LiveProcess/StrataJITGuestGate.m Tests/guest-gate-tests/main.m -o /tmp/strata-gate-check
/tmp/strata-gate-check
```

The Home checks cover preference migration, widget occupancy and reflow, resizing, page removal with app-library preservation, folders, persistence, and repeated rearrangement. The source release's validation report also records targeted simulator checks; the local UI harness uses fixture icons and no guest execution.

R26 refresh scheduling policy:

```sh
swiftc LiveContainerSwiftUI/Views/StrataRefreshPolicy.swift Tests/refresh-policy-tests/main.swift -o /tmp/strata-refresh-check
/tmp/strata-refresh-check
```

These checks cover the 1–5 day bounds, exact due-time boundaries, initial refresh and one-hour automatic retry throttling. They do not prove iOS background scheduling or successful SideStore signing.

R27 Tools layout persistence and recovery:

```sh
swiftc LiveContainerSwiftUI/Views/StrataToolsLayout.swift Tests/tools-layout-tests/main.swift -o /tmp/strata-tools-check
/tmp/strata-tools-check
```

R28 automation schedule and disconnect policy:

```sh
swiftc SideStoreSupport/StrataAutomationPolicy.swift Tests/automation-policy-tests/main.swift -o /tmp/strata-automation-check
/tmp/strata-automation-check
```

Tests cover 1–5 day due checks, disabled schedules, retry throttling, active-refresh suppression, and conservative VPN cleanup while JIT remains active. They do not prove that iOS will run a Personal Automation or complete a self-update without interruption.

# Launcher artwork and layout regressions

```sh
python3 Tests/launcher-stability-tests.py
```

This verifies source-level invariants for separately bounded thumbnail caching,
cover retention during asynchronous replacement, selected-item restoration, and
launch lifecycle recovery. It also guards SideStore's dedicated icon extraction
and the compact Shelf long-press menu. Built-in skin checks cover the 26 theme cards, bundled image templates, and
removal of Skin Collections and Skin Studio; controller press/release effects
remain covered. It does not replace iOS rendering
or interaction tests. The checks also cover shared Classic/Wide/Full Screen
selection, the NxNative skin-settings section order, picture cards for all 26
built-in themes, and Full Screen's native-input feedback path.
