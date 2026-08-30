# FineTune Project Handoff

Last updated: 2026-08-27

Read this file before changing code. Re-fetch the active branch head and every sensitive file before each write. Treat GitHub CI and real-machine acceptance as separate evidence axes.

## Project identity

FineTune is a macOS menu bar audio-control application. It controls per-app volume and gain, application routing, output and input device levels, EQ, AutoEQ, global shortcuts, media keys, notifications, and FineTune-owned volume HUDs.

Repository: `R-jed/FineTune`

Upstream bootstrap source: `ronitsingh10/FineTune`

Bootstrap commit: `2285279d36d3f8115c1c2d4aecd904f1bdf96a51`

License: GNU GPL v3. Preserve the original copyright notice.

## Branch and PR topology

`main` remains the stable base. Do not merge or modify it without explicit authorization.

Important Draft validation branches:

- PR #10: `integration/full-product-acceptance`, validated integration baseline `d0f8dc7162218996ef5dc5b5bcf789ce6f47a2f4`
- PR #12: `fix/loudness-equalizer-rt-lifetime`, validated product head `639af28e4a8123e1bbc655591a6586c2b8420c17`
- PR #14: `feat/reorder-liquid-glass-ui`, current UI iteration and CI validation carrier

PR #14 must remain Draft and unmerged until explicit authorization after real-machine/UI acceptance.

The fixed-point baseline for the current UI iteration is:

`639af28e4a8123e1bbc655591a6586c2b8420c17`

Do not let unrelated integration or `main` movement silently change this review boundary.

## Current UI iteration

Task specification:

- `tasks/reorder-liquid-glass-ui.md`
- `tasks/reorder-liquid-glass-ui-architecture.md`
- `tasks/reorder-liquid-glass-ui-result.md`

Current code-level state:

- active App, inactive App, output device, and input device rows use one shared reorder handle and dragged-row appearance
- App label/name area remains draggable
- slider, mute, device picker, EQ, pin/hide, App activation, and other controls retain independent pointer behavior
- `RowReorderDragState` remains the canonical midpoint/origin-adjustment state machine
- reverse-direction and upper/lower boundary regression tests are present
- durable `DisplayableApp.id` identity is used for App row/navigation identity where persistence identity is required
- reorder motion uses the shared `(0.16, 1, 0.3, 1)` timing family
- row transactions suppress reorder animation when Reduce Motion is enabled

The popup host now belongs to FineTune:

- `FineTuneMenuBarExtra` owns the real `NSStatusItem`
- `FineTuneMenuBarPopupPanel` owns the popup `NSPanel`
- global shortcut toggling calls the owned popup directly
- `MenuBarIconCoordinator` receives the real owned `NSStatusBarButton`
- popup lifecycle filtering uses `FineTuneMenuBarPopupPanel` instead of a third-party class-name string
- popup frame calculation is a deterministic function with normal, left/right boundary, and dynamic-resize/top-anchor tests
- macOS 26+ creates `NSGlassEffectView()` and installs the real SwiftUI hosting view through `contentView`
- older supported systems use one `.popover` `NSVisualEffectView` fallback
- the popup content layer no longer adds a second runtime material/tint surface

Do not reintroduce private status-bar-window discovery, recursive `NSApp.windows` scanning, synthetic clicks, or third-party window-class string matching.

## Liquid Glass API truth

The current Xcode SDK disproved an earlier assumption that FineTune should assign:

```swift
glass.style = .regular
glass.cornerRadius = ...
```

Do not restore those assignments.

The approved modern host pattern is:

```swift
let glass = NSGlassEffectView()
glass.contentView = content
```

The real content belongs in `NSGlassEffectView.contentView`. Let AppKit control the standard Liquid Glass presentation and system accessibility adaptation.

Do not stack a second `.popover`, a fixed white/black root tint, or decorative glass sibling behind the hosting view.

## FluidMenuBarExtra clean break

FluidMenuBarExtra is no longer a runtime or package dependency of the current UI branch.

The clean break removes it from:

- the app target framework build phase
- app target package product dependencies
- Xcode project package references
- `XCSwiftPackageProductDependency`
- `XCRemoteSwiftPackageReference`
- `Package.resolved`

The lock-file `originHash` was regenerated for the remaining root package set.

Do not preserve a compatibility path merely to keep Fluid alive. If behavior parity is missing, fix the FineTune-owned host directly and verify it.

## Automated evidence for the UI iteration

CI failures in this iteration were useful evidence:

- CI #270 exposed Swift 6 ObservableObject visibility and explicit `self` compile issues
- CI #271 exposed invalid `NSGlassEffectView` API assumptions
- later CI exposed additional host-isolation/test integration issues that were repaired at source

Dependency-clean-break SHA:

`b00f8761f4ef7a602e9bacb1e01362ad60036612`

Exact-head CI #279 / run `33065012491` passed on that SHA:

- Build
- complete non-UI Tests
- test-result upload

History cleanup may move the branch to a new commit SHA without changing the final tree. After any such rewrite or later code/doc change, re-run exact-head Build + complete non-UI Tests and use that new run as the automated acceptance evidence.

Never infer real-machine/UI acceptance from CI.

## Real-machine/UI gates still pending

The current UI iteration is not complete until the actual built app passes the applicable matrix.

Reorder:

- active Apps
- inactive Apps
- output devices
- input devices
- up/down one row
- fast multi-row crossing
- reverse direction before release
- release between thresholds
- persistence after leaving edit mode/reopening
- Compact, Comfortable, and Spacious popup sizes
- slider, mute, picker, EQ, pin/hide, and App activation remain conflict-free

Popup and Liquid Glass:

- Light, Dark, and System appearance
- bright and dark wallpapers
- System appearance changes while the popup is in use
- Reduce Transparency
- Increase Contrast
- Reduce Motion
- available system Liquid Glass appearance preferences
- global shortcut open/close
- keyboard focus/navigation
- Escape and outside-click dismissal
- dynamic popup resize with stable top anchoring
- status-item highlight
- menu icon crossfade
- multi-display positioning where available

Do not mark these passed without observation on the acceptance machine.

## Core product invariants

### Localization

FineTune-owned UI supports exactly:

- English
- Simplified Chinese

The in-app selector exposes:

- `Auto`
- `English`
- `简体中文`

Persisted identities remain:

- `.system` -> `system`
- `.english` -> `en`
- `.simplifiedChinese` -> `zh-Hans`

`Auto` uses the first preferred system UI language. Chinese maps to `zh-Hans`; other or unusable values map to `en`.

Dynamic application/device/profile/preset names, UIDs, PIDs, bundle identifiers, versions, URLs, and other external identity values stay verbatim.

### App discovery and durable identity

Do not regress app discovery into live-audio-only discovery.

Regular running applications may remain visible without current audio output. Pinned inactive applications retain a stable representation when the process is unavailable.

Durable app state is keyed by `persistenceIdentifier`. PID/process identity is only the current representative.

Representative changes must not silently transfer stale transient tap/process ownership.

### Routing, taps, DSP, and realtime lifetime

The integration line contains source-level repairs for:

- representative-process routing/tap ownership
- quiet-app first-sound routing prearm
- source-activity metering and weak-signal handling
- Biquad realtime-reader quiescence
- tap processor-generation ownership
- Loudness Equalization lifetime retirement using real reader quiescence

Do not replace those lifetime protocols with fixed time delays.

Physical first-transient routing, sleep/wake, device switching, and permission recovery remain real-machine gates unless a later handoff records actual acceptance evidence.

### Settings ordering

An older debounced settings write must never overwrite a newer flush.

`SettingsWriteCoordinator` deterministic regression coverage exists for this ordering contract. Do not reintroduce timing-guess tests or parallel unordered persistence writes.

## Swift and concurrency constraints

Current project settings include:

- Swift 6.0
- `SWIFT_APPROACHABLE_CONCURRENCY = YES`
- no explicit app-target default actor isolation override
- unit-test target default actor isolation is MainActor

UI/AppKit ownership rules:

- popup host state is main-actor owned
- AppKit window/status-item mutation stays on the main actor
- SwiftUI reorder state stays inside SwiftUI/main-actor ownership
- event-monitor callbacks must hop to `@MainActor` before touching AppKit/SwiftUI-owned mutable state if callback isolation is not guaranteed

Do not add UI fixes using:

- `Task.detached`
- `nonisolated(unsafe)`
- `@unchecked Sendable`
- semaphores
- ad-hoc locks
- background mutation of SwiftUI/AppKit state

A delayed UI transition should keep the wait cancellable/lifecycle-aware and keep the actual UI mutation on the main actor.

## Dependency/system boundaries

Current important packages include Sparkle, KeyboardShortcuts, and SnapshotTesting. FluidMenuBarExtra has been removed from the UI branch.

Do not fork or rewrite package-owned UI without a concrete product requirement.

macOS owns privacy-prompt chrome, file-panel controls, standard accessibility adaptations, and native Liquid Glass behavior. FineTune should adapt its own content and host boundaries rather than fight those system surfaces.

## Scope discipline for the UI iteration

The diff from `639af28e...` should stay inside:

- menu-bar host/popup UI
- reorder row/components
- menu-bar icon/shortcut bridge needed by the owned host
- deterministic UI/geometry tests
- Xcode dependency metadata
- task/handoff documentation

Keep these production subsystems out unless a failing test proves a direct regression caused by this UI work:

- audio routing algorithms
- process discovery
- source activity metering
- realtime DSP/lifetime ownership
- settings write ordering
- EQ/AutoEQ DSP
- signing
- release/appcast

## Review and completion rules

Before claiming the automated axis is complete:

1. compare the final tree against fixed point `639af28e...`
2. review code quality, Swift concurrency, dependency graph, entropy, and Git history
3. confirm PR #14 is still Draft and unmerged
4. run exact-head Build
5. run the complete non-UI Test suite
6. confirm test-result upload

Before claiming the whole UI iteration is complete, the real-machine/UI matrix above must also pass.

Known low-severity cleanup candidates that do not currently create a second runtime popup surface:

- the historical no-op `darkGlassBackground()` content helper
- the old popup-overlay design token/its token-level test

Treat these as entropy to remove when doing so can be verified cleanly. Do not revive their old visual behavior.

## Next action

Finish history cleanup only after the final tree is settled, then run exact-head CI on the history-cleaned HEAD. If that is green, automated acceptance can be reported PASS while real-machine/UI acceptance remains Pending.
