# UI Iteration Architecture Decision

Status: implemented, automated verification passed, real-machine acceptance pending

Branch: `feat/reorder-liquid-glass-ui`
Starting product SHA: `639af28e4a8123e1bbc655591a6586c2b8420c17`

## Capability map

| Module id | Responsibility | Depends on |
|---|---|---|
| `reorder-motion` | Continuous App/device row reordering, stable identity, shared drag appearance | existing `RowReorderDragState` |
| `popup-glass-host` | FineTune-owned status item/panel host, native Liquid Glass surface, legacy material fallback | existing `MenuBarPopupView` content |

Build order: `reorder-motion` -> `popup-glass-host` -> joint automated and real-machine acceptance.

The modules are independently testable. A failure in one must not be hidden by the other.

## Research decision

The former FluidMenuBarExtra 1.5.1 host hardcoded `NSVisualEffectView(material: .popover)` as the panel content view. FineTune then added a second `.popover` visual effect and a fixed light/dark overlay.

Apple's current AppKit guidance requires custom Liquid Glass content to be hosted through `NSGlassEffectView.contentView`, and recommends removing custom visual-effect backgrounds from popovers/sheets that would interfere with the glass input colors.

A community Fluid fork swaps the outer view class to `NSGlassEffectView` but still adds the `NSHostingView` as an arbitrary subview. That does not satisfy the documented content containment contract and is not accepted as the product solution.

Native SwiftUI `MenuBarExtra(.window)` was also rejected for this slice because FineTune requires verified parity for programmatic global-shortcut opening, dynamic sizing, status-item highlighting, keyboard focus, dismissal, multi-display anchoring, and direct icon updates. Public API/research did not provide enough first-party evidence to claim those behaviors were all preserved.

## Approved popup host architecture

FineTune owns the menu-bar presentation boundary directly:

```text
FineTuneMenuBarExtra
  NSStatusItem
  NSPanel
    macOS 26+
      NSGlassEffectView()
        contentView = NSHostingView<MenuBarPopupView>
    older supported macOS
      NSVisualEffectView(material: .popover)
        contentView = NSHostingView<MenuBarPopupView>
```

Do not assign a custom `style` or `cornerRadius` to `NSGlassEffectView`. The current SDK proved the earlier `style = .regular` assumption invalid. The supported implementation creates the standard glass view and installs the real hosting view through `contentView`, allowing AppKit to own the standard Liquid Glass appearance.

The host preserves the useful prior behaviors with less indirection:

- click status item to open/close
- status item remains highlighted while popup is open
- popup anchors below the owning status item and clamps to the active screen
- dynamic SwiftUI content-size changes keep the top edge anchored
- outside/app-deactivation dismissal
- fade on dismissal, respecting Reduce Motion
- direct programmatic `toggle()` for global shortcuts
- direct status-button ownership for `MenuBarIconCoordinator`

This removes the need for:

- FluidMenuBarExtra runtime dependency
- private `NSStatusBarWindow.statusItem` KVC discovery
- synthetic mouse events for global-shortcut toggling
- recursive `NSApp.windows` scanning to locate the FineTune status button
- popup visibility filtering based on a third-party window class name
- the second FineTune root `NSVisualEffectView(.popover)`
- fixed 50% white / 40% black popup overlays on the popup surface

## Reorder architecture

Keep `RowReorderDragState` as the canonical midpoint/origin-adjustment state machine unless new tests demonstrate a defect.

The duplicated row visual treatment is centralized in one shared reorder modifier and handle. App and inactive-App rows expose the same `line.3.horizontal` handle as device rows while their label area remains draggable. Interactive controls retain their own gestures.

Use durable `DisplayableApp.id` persistence identity consistently for App row reorder/navigation identity.

Use one cubic timing family matching the requested reference: `(0.16, 1, 0.3, 1)`. Reduce Motion preserves ordering while row transactions suppress reorder animation.

## Concurrency boundary

All popup host and reorder mutations are UI-owned and stay on the main actor / SwiftUI state boundary.

Do not introduce:

- `Task.detached`
- `nonisolated(unsafe)`
- `@unchecked Sendable`
- semaphores or ad-hoc locks for UI ordering

Any event-monitor callback that may arrive outside actor isolation must explicitly hop to `@MainActor` before touching AppKit or SwiftUI-owned state.

## Verification gates

Automated, passed on the dependency-clean-break head before final history cleanup:

- reorder reverse-direction and boundary tests
- popup controller and geometry tests
- exact-head Debug Build
- complete non-UI Test suite
- test-result upload
- dependency graph review confirming FluidMenuBarExtra is removed from the Xcode project and `Package.resolved`

Real machine, still pending:

- active/inactive App reorder and output/input device reorder
- Slider, mute, picker, EQ, pin and App activation remain conflict-free
- Light/Dark/System Liquid Glass on contrasting wallpapers
- Reduce Transparency, Increase Contrast, Reduce Motion
- global shortcut toggle, keyboard focus, dismissal, resize, status highlight, icon crossfade
- multi-display positioning where available

The iteration remains incomplete until the applicable real-machine visual gates pass.
