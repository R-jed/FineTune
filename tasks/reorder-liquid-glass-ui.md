# Reorder Motion + macOS Liquid Glass UI Iteration

Status: planned, implementation not started

Branch: `feat/reorder-liquid-glass-ui`

Starting product head: `639af28e4a8123e1bbc655591a6586c2b8420c17`

## Goal

Deliver one popup-focused UI iteration with two coordinated outcomes:

1. active Apps, inactive Apps, output devices, and input devices use one continuous vertical reorder motion language
2. the whole status-bar popup uses a macOS 26/27-appropriate Liquid Glass host in Light, Dark, and System appearances without redundant custom material layers

The two outcomes share one branch and one final real-machine visual acceptance pass. Their product logic remains independent and should land as separate atomic commits before the final verification commit/history cleanup.

## Confirmed problems

### App reorder interaction is incomplete

The current product already has:

- `RowReorderDragState`
- midpoint crossing
- fast multi-row crossing
- origin correction after adjacent swaps
- App reorder calls in `MenuBarPopupView`
- drag offset, shadow, and z-index on active and inactive App rows

The current App drag gesture starts only from the app name/routing-subtitle region. This is difficult to discover and creates a mismatch with device priority editing.

The old handoff statement that App rows already expose a complete whole-row drag target was incorrect and has been removed.

### Device reorder works but the motion system is duplicated

Output and input devices already share `DeviceEditRow` and `deviceDragState`, with a clear `line.3.horizontal` handle.

App rows and device rows duplicate the same drag visual primitives:

- `offset`
- `shadow`
- `zIndex`
- animation suppression while dragging

They should share one visual treatment and one motion timing family.

### Popup surface is over-layered

The current popup renders through three background layers:

1. FluidMenuBarExtra 1.5.1 `NSVisualEffectView(.popover)`
2. FineTune `darkGlassBackground()` adding another `NSVisualEffectView(.popover)`
3. FineTune `popupOverlay`, 50% white in Light and 40% black in Dark

This creates a manually tinted frosted surface that does not provide the intended modern Liquid Glass result.

Apple guidance for Liquid Glass favors system-owned surfaces, removing redundant custom backgrounds, and using `NSGlassEffectView` when a custom AppKit glass host is required.

## Non-goals

Do not change:

- audio routing algorithms
- process discovery behavior
- source activity metering
- Biquad realtime lifetime logic
- tap processor-generation ownership
- Loudness Equalization lifetime logic
- settings write ordering
- app persistence semantics
- pin/hide semantics
- EQ or AutoEQ DSP
- release/signing/appcast behavior
- `main`

Do not migrate the complete popup lifecycle to a new architecture in the same change unless the current host cannot satisfy the Liquid Glass acceptance contract with a narrow adaptation.

## Design principles

- Reuse existing reorder mechanics before adding new state.
- Make drag affordance obvious.
- Do not let reorder gestures steal slider, button, menu, picker, or EQ gestures.
- Use stable durable identity for reorder animation.
- The dragged row follows the pointer without layout-animation lag.
- Other rows glide into their new positions.
- Use one motion curve family for Apps and devices.
- Respect Reduce Motion.
- Use native Liquid Glass APIs when supported.
- Do not stack glass on glass.
- Keep content rows and EQ/device-detail cards in the content layer rather than converting every card to an independent glass surface.
- Let Light, Dark, System, accessibility, and system Liquid Glass preferences drive the final material.

## Workstream A: continuous reorder motion

### A1. Stable identity audit

Use `persistenceIdentifier` consistently for App reorder identity, SwiftUI row identity, and keyboard navigation identity where those identities represent the durable App.

Review the current active App row `.id(app.id)` override. Remove or replace it if it causes SwiftUI to treat the same durable App as a new row when its representative PID changes.

Acceptance:

- an App remains the same reorder item when its representative process changes
- active to pinned-inactive transitions do not create reorder identity ambiguity
- reordering does not reset unrelated row state

### A2. Shared drag appearance

Extract a small shared modifier or component for vertical reorder appearance. Conceptually:

```swift
.reorderDragAppearance(
    isDragging: isDragging,
    offset: dragOffset,
    reduceMotion: accessibilityReduceMotion
)
```

It should own only visual movement treatment:

- `offset(y:)`
- drag `zIndex`
- drag shadow
- optional very small lift/scale if it improves real-machine feel
- suppression of implicit animation on the actively dragged row

Do not move reorder data logic into the modifier.

Use the same modifier in:

- `AppRow`
- `InactiveAppRow`
- `DeviceEditRow`

### A3. Shared motion timings

Use the React reference motion family as the target feel:

`cubic-bezier(.16, 1, .3, 1)`

SwiftUI equivalent:

```swift
Animation.timingCurve(0.16, 1, 0.3, 1, duration: ...)
```

Use one named timing for adjacent-row glide and one named settling timing only if two durations are demonstrably needed.

Avoid a proliferation of nearly identical animation constants.

Reduce Motion behavior:

- preserve functional reordering
- remove decorative lift/scale and long glide
- use immediate or minimal positional settling

### A4. App drag affordance

Add a clear reorder handle using the same `line.3.horizontal` visual language as device priority editing.

The handle is the guaranteed drag target.

Also allow dragging from the App name/routing-subtitle/appropriate empty label area if it can be done without conflicting with app activation or text help behavior.

Do not attach the reorder `DragGesture` across the entire row HStack because the row contains:

- volume slider
- mute
- boost
- device picker
- EQ toggle
- pin/hide actions
- other controls that need their own pointer interactions

The App icon should retain activation semantics unless a deliberate product decision changes that behavior.

### A5. Midpoint and reverse-direction behavior

Keep `RowReorderDragState` unchanged unless a failing test proves an algorithm defect.

Add tests for:

- downward crossing
- upward crossing
- fast multi-row crossing
- exact midpoint behavior
- switching dragged row
- reset
- reverse direction after a completed adjacent swap
- lower and upper boundary clamping

If reverse-direction behavior already passes, do not refactor the state machine for style reasons.

### A6. Device parity

Output and input devices already share `DeviceEditRow`. Preserve that structure.

Verify both tabs have identical:

- pointer tracking
- midpoint threshold
- adjacent-row glide
- drag lift
- drop settling
- Reduce Motion behavior

Do not split output and input reorder into separate implementations.

## Workstream B: popup Liquid Glass

### B1. Surface hierarchy rule

On macOS 26/27, the target hierarchy is one popup-level glass surface containing the real SwiftUI content.

Do not render:

- Fluid `.popover` material
- plus FineTune `.popover` material
- plus a fixed white/black overlay

at the same time.

For older supported macOS versions, a standard material fallback is allowed and should be isolated behind one compatibility boundary.

### B2. Remove FineTune's redundant root treatment on the modern path

`MenuBarPopupView` should stop adding a second `NSVisualEffectView(.popover)` on the modern Liquid Glass path.

`popupOverlay` must not apply its fixed 50% white / 40% black tint on the modern path.

Do not globally delete appearance tokens if they are still needed by legacy fallback or other windows. Remove only obsolete uses after reference search.

### B3. Host implementation decision gate

FluidMenuBarExtra 1.5.1 hardcodes `NSVisualEffectView(.popover)` as `FluidMenuBarExtraWindow.contentView`.

Preferred order of implementation:

1. Build the smallest proof that FineTune can remove its redundant second material/overlay while preserving all popup lifecycle behavior.
2. Compare that result on the macOS 27 acceptance machine against a true native Liquid Glass reference.
3. If the remaining Fluid host is still a standard frosted material, move the glass boundary into the host itself using `NSGlassEffectView` on macOS 26+.

A true custom host implementation must follow Apple's containment rule:

```text
NSGlassEffectView
    contentView = real hosting/content view
```

Do not add `NSGlassEffectView` as a decorative sibling behind the SwiftUI content.

### B4. Dependency adaptation constraints

If FluidMenuBarExtra must be adapted, choose the smallest maintainable ownership model.

Allowed approaches, in preference order after the proof step:

1. a narrowly reviewable package adaptation that changes only the window surface primitive while preserving Fluid lifecycle behavior
2. a small FineTune-owned host abstraction if it can preserve current Fluid behavior with less long-term complexity than carrying a package fork

Avoid:

- runtime KVC or view-tree reparenting hacks to move Fluid's private `NSHostingView` after window creation
- adding another glass layer inside the existing visual-effect hierarchy
- copying the entire dependency into FineTune without proving that the smaller adaptation is insufficient
- migrating to native `MenuBarExtra(.window)` inside this slice without parity proof

### B5. Native MenuBarExtra remains a future clean-break option

A later clean-break can remove FluidMenuBarExtra in favor of SwiftUI `MenuBarExtra(.window)` or a FineTune-owned status-item host.

That future migration requires explicit parity proof for:

- global-shortcut programmatic opening
- popup resizing
- status-item highlight
- keyboard focus
- dismissal
- multi-display anchoring
- status icon mutation/crossfade

Do not combine that architectural migration with this visual iteration unless the current host blocks the required result and the migration is separately approved.

### B6. Light, Dark, and System

Modern Liquid Glass must be tested as one adaptive system.

Light:

- no fixed white wash
- preserve legibility over bright and dark wallpapers
- visible native glass response

Dark:

- no fixed 40% black wash
- preserve depth and environment response
- text and controls remain legible

System:

- changing macOS appearance updates the popup without reopening or stale frames
- `WindowAppearanceBridge` remains only if it is still necessary to honor FineTune's explicit Light/Dark/System preference at the host window boundary

### B7. Accessibility and user settings

Real-machine acceptance must cover:

- Reduce Transparency
- Increase Contrast
- Reduce Motion
- available macOS 27 Liquid Glass appearance preferences

Prefer system adaptation over FineTune-specific overrides.

### B8. Content-layer restraint

Do not convert every row/card into Liquid Glass.

Keep:

- device rows
- App rows
- EQ content
- device detail content

as content-layer UI using existing adaptive colors/materials where appropriate.

Use interactive glass only for important top-level controls if it materially improves the result and if the platform API is available. A little goes a long way.

## Concurrency plan

Current project settings confirm:

- Swift 6.0
- Approachable Concurrency enabled
- no explicit target default actor isolation override found

This iteration is UI-bound.

Rules:

- SwiftUI reorder state stays in `@State` / main-actor UI ownership
- AppKit window/surface configuration stays on the main actor
- no `Task.detached`
- no new `nonisolated(unsafe)`
- no `@unchecked Sendable`
- no semaphore/lock workaround for UI ordering
- no background mutation of SwiftUI/AppKit state

If asynchronous waiting is needed for visual/lifecycle coordination, keep the waiting separate from main-actor mutation and make cancellation/lifecycle ownership explicit.

## Expected file scope

Likely reorder files:

- `FineTune/Views/MenuBarPopupView.swift`
- `FineTune/Views/Rows/AppRow.swift`
- `FineTune/Views/Rows/InactiveAppRow.swift`
- `FineTune/Views/Rows/AppRowWithLevelPolling.swift` only if API forwarding changes
- `FineTune/Views/Rows/DeviceEditRow.swift`
- `FineTune/Views/Components/RowReorderDragState.swift` only if tests expose a defect
- `FineTune/Views/DesignSystem/ViewModifiers.swift` or one small new reorder modifier file
- `FineTuneTests/RowReorderDragStateTests.swift`

Likely Liquid Glass files:

- `FineTune/Views/MenuBarPopupView.swift`
- `FineTune/Views/DesignSystem/VisualEffectBackground.swift`
- `FineTune/Views/DesignSystem/DesignTokens.swift` only for dead root-overlay cleanup
- `FineTune/Views/DesignSystem/WindowAppearanceBridge.swift` only if host ownership requires it
- `FineTune/FineTuneApp.swift` only if menu host wiring changes
- `FineTune/Shortcuts/MenuBarPopupController.swift` only if host behavior changes
- `FineTune/Views/MenuBar/MenuBarIconCoordinator.swift` only if status-item discovery changes
- SwiftPM/project files only if a dependency adaptation is required

Keep audio and persistence files out of the diff.

## Commit plan

Keep the combined branch reviewable with atomic commits:

1. `docs: refresh project handoff before UI iteration`
2. `docs: plan reorder and Liquid Glass UI iteration`
3. `fix(ui): unify continuous reorder interaction`
4. `feat(ui): adopt adaptive menu Liquid Glass`
5. test or cleanup commit only if it represents a distinct verified correction

Before final integration, squash only if it improves reviewability and preserves useful red/green evidence.

## Automated verification

Before implementation:

- capture exact branch head
- run or confirm baseline Build and complete non-UI Tests for the starting product SHA

During reorder work:

- run `RowReorderDragStateTests`
- run any new identity/interaction contract tests
- build after the smallest functional change

During Liquid Glass work:

- add unit tests only for deterministic policy/host decisions that can be meaningfully tested
- do not create brittle tests that assert Apple private view hierarchy or pixel values of dynamic glass
- use snapshot tests for stable FineTune-owned content where they add value, not for OS glass optics

Final automated gate:

- exact-head Build
- complete non-UI Tests
- test-result upload
- final diff review against `639af28e...`

## Real-machine reorder acceptance

Test with at least three items so midpoint crossing and multi-row travel are observable.

For active Apps:

- drag down one row
- drag up one row
- drag across multiple rows quickly
- reverse direction before release
- release between thresholds
- confirm row follows pointer without lag/jump
- confirm neighbors glide rather than teleport
- confirm slider still drags volume
- confirm mute, device picker, EQ, pin/hide controls still click normally
- confirm App icon activation still works

Repeat for pinned inactive Apps.

For output devices:

- repeat the same directional/multi-row tests through the handle
- confirm priority persists after leaving edit mode/reopening

Repeat for input devices.

Test Compact, Comfortable, and Spacious popup sizes.

## Real-machine Liquid Glass acceptance

Test on macOS 27 with the latest SDK-built app available on the acceptance machine.

Matrix:

- Light + bright wallpaper
- Light + dark wallpaper
- Dark + bright wallpaper
- Dark + dark wallpaper
- System Light -> Dark while popup is in use
- System Dark -> Light while popup is in use
- Reduce Transparency on/off
- Increase Contrast on/off
- Reduce Motion on/off
- available system Liquid Glass appearance preference variants

Verify:

- one coherent popup surface
- no white/black fixed wash
- no double-blur look
- no background flash while opening/closing
- no flash while EQ expands/collapses
- no visual seam during popup resize
- text remains legible
- hover states remain clear
- scroll content remains readable
- keyboard navigation remains visible
- global shortcut opens/closes the popup correctly
- status item highlight behavior remains correct
- menu icon crossfade remains correct
- multi-display positioning remains correct if available

## Cross-feature regression gates

Because the popup host is long-lived UI around audio controls, perform a short smoke after the visual work:

- app discovery still updates
- volume controls still mutate audio
- mute/unmute still works
- device selection still works
- EQ expand/collapse still works
- source activity meter still updates
- Settings opens correctly
- global shortcuts still work

Then re-run the independent product gates:

- first-sound routing A -> B
- idle/process-object churn first-sound repeat
- sleep/wake

## Completion criteria

Do not mark this iteration complete until all are true:

- final diff is limited to the planned UI/host/test/doc scope
- exact-head Build passes
- complete non-UI Tests pass
- reorder real-machine acceptance passes for active Apps, inactive Apps, output devices, and input devices
- Light/Dark/System Liquid Glass matrix passes on macOS 27
- accessibility appearance checks pass
- no regression in popup opening, resizing, keyboard focus, dismissal, status-item highlight, global shortcut toggle, or menu icon behavior
- final source review finds no duplicate reorder visual logic that should have been shared
- final source review finds no redundant modern popup material/overlay layer
- PRs remain Draft and unmerged until explicit authorization
