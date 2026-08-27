# Reorder Motion + Liquid Glass UI Result

Status: automated functional axis passed; static performance review completed; measured performance and real-machine/UI axes pending

Branch: `feat/reorder-liquid-glass-ui`
Fixed-point baseline: `639af28e4a8123e1bbc655591a6586c2b8420c17`

## Implemented

Reorder interaction:

- active App, inactive App, output device, and input device rows share one drag handle and dragged-row visual treatment
- App label/name area remains a drag target
- slider, mute, device picker, EQ, pin/hide, and other controls keep independent pointer interactions
- durable `DisplayableApp.id` is used for App row/navigation identity instead of representative process identity
- existing midpoint/origin-adjustment state machine is preserved
- reverse-direction and upper/lower boundary regression tests are present
- Reduce Motion is propagated through row transaction animation suppression

Menu-bar host:

- FineTune owns the real `NSStatusItem` and `NSPanel`
- global shortcut toggles the owned popup directly
- menu-bar icon updates target the owned `NSStatusBarButton` directly
- popup lifecycle/visibility filtering uses `FineTuneMenuBarPopupPanel`
- popup positioning is isolated as a deterministic function with normal, screen-edge, and dynamic-resize tests
- macOS 26+ hosts the real SwiftUI content in `NSGlassEffectView.contentView`
- older supported macOS uses one `.popover` `NSVisualEffectView` fallback
- FineTune no longer stacks a second popup material or fixed popup tint on the host surface
- FluidMenuBarExtra has been removed from the Xcode target dependency graph and `Package.resolved`

## CI evidence

CI failures were treated as product evidence and repaired from actual compiler/API errors:

- CI #270 exposed Swift 6 ObservableObject visibility and explicit `self` issues
- CI #271 exposed invalid assumptions that `NSGlassEffectView.style` could be assigned and that the previous `cornerRadius` usage matched the current SDK
- the implementation was corrected to the standard `NSGlassEffectView()` plus `contentView` containment model

Exact dependency-clean-break head before final history cleanup:

`b00f8761f4ef7a602e9bacb1e01362ad60036612`

CI #279 / run `33065012491` completed successfully on that exact SHA:

- Build passed
- complete non-UI Tests passed
- test-result upload passed

Final history-cleaned product HEAD:

`b20c5e3301a1c087de2399eef47dbfdd5085333e`

CI #283 / run `33066051188` completed successfully on that exact SHA:

- Build passed
- complete non-UI Tests passed
- test-result upload passed

The automated functional axis is final for `b20c5e3...`. Any later documentation-only closure commit must repeat the exact-head CI gate before that newer branch HEAD is called fully verified.

## Source-review result

Fixed-point diff review against `639af28e...` is limited to the menu-bar host, popup/reorder UI, Xcode dependency metadata, and deterministic tests. No audio routing, process discovery, realtime DSP, settings persistence, signing, release, or appcast production code is part of this UI iteration.

Swift Concurrency review:

- AppKit host state is main-actor owned
- direct popup controller protocol/class are main-actor isolated
- no new `Task.detached`
- no new `nonisolated(unsafe)`
- no new `@unchecked Sendable`
- no semaphore/lock workaround was introduced for UI ordering

Dependency review:

- FluidMenuBarExtra runtime/package references are removed from `project.pbxproj`
- its lock-file pin is removed
- `Package.resolved` origin hash was regenerated for the remaining root package set

Known low-severity entropy:

- legacy content-layer names such as the no-op `darkGlassBackground()` helper and the old popup-overlay token/tests still exist even though the owned host supplies the popup surface
- these do not add a second runtime material layer, but they should be considered cleanup candidates rather than evidence of current popup behavior

## Performance stress review

Static performance review against fixed point `639af28e...` found no confirmed performance regression in the product diff.

Confirmed findings:

- `RowReorderDragState` performs constant-time arithmetic/state updates per midpoint check and introduces no I/O, locks, or task creation
- repeated App reorder persistence is protected by `SettingsManager.scheduleSave()` cancellation plus a 500 ms debounce, so rapid adjacent swaps do not create a disk-write storm
- direct `NSStatusBarButton` attachment removes the fixed-point implementation's recursive `NSApp.windows` button search and initial retry loop
- direct popup-controller attachment removes the old discovery/synthetic-action path
- PR #13 changes `MenuBarPopupView` App reorder identity and popup-window filtering, but does not change the existing `updateAppDrag` reorder algorithm

Unverified hot paths that require measured stress testing:

- App dragging still rebuilds and sorts `audioEngine.displayableApps` on drag updates, and each adjacent swap calls `AudioEngine.moveApp`, which rebuilds that list again before `SettingsManager.moveApp`; this is primarily pre-existing scaling cost and should be measured with unusually large App lists
- the FineTune-owned popup host reports every SwiftUI geometry-size change through a new main-actor `Task` and calls animated `NSWindow.setFrame`; rapid EQ/device-detail expansion, popup density changes, or other repeated size changes could create overlapping main-thread resize work
- dragged-row shadow and Liquid Glass compositing cost are GPU/UI costs that functional unit tests cannot validate
- no current CI test records SwiftUI/AppKit frame time, dropped frames, peak RSS, allocations, or main-thread task backlog

Measured stress gate:

- compare the branch against `639af28e...` on the same Mac and OS build
- exercise large App lists at 100, 250, and 500 synthetic rows where a debug harness is available
- drag top-to-bottom and bottom-to-top repeatedly, including fast multi-row and direction reversals
- open/close the popup 100 times through both the status item and global shortcut
- expand/collapse App EQ and device detail 100 times and cycle Compact/Comfortable/Spacious while recording popup resize behavior
- drive rapid volume/mute/default-device changes and verify menu icon updates do not accumulate animation or image-allocation work
- record Time Profiler, Core Animation, Allocations, main-thread responsiveness, dropped frames, peak RSS, and object/monitor counts
- investigate a repeatable regression of about 10% or more in p95 main-thread work or peak RSS relative to the fixed point, any monotonic memory growth, any accumulating event monitor/window count, or visible frame/task backlog

Performance status: static review passed with unverified hot paths. The measured performance axis remains pending. No production optimization should be made from static suspicion alone.

## Real-machine/UI acceptance still required

Do not mark the iteration complete until the actual app passes:

- active App reorder
- inactive App reorder
- output device reorder
- input device reorder
- reverse and fast multi-row dragging
- slider, mute, picker, EQ, pin/hide, and App activation gesture isolation
- Compact, Comfortable, and Spacious popup sizes
- Light, Dark, and System appearance
- bright and dark wallpaper backgrounds
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
- measured performance stress gate above

The PR must remain Draft and unmerged until explicit authorization after real-machine/UI and measured performance acceptance.
