# FineTune Project Handoff

Last updated: 2026-08-27

Read this file before changing code. Re-fetch the active branch head and every sensitive file before each write.

## Project identity

FineTune is a macOS menu bar audio-control application. It controls per-app volume and gain, application routing, output and input device levels, EQ, AutoEQ, global shortcuts, media keys, notifications, and FineTune-owned volume HUDs.

Repository: `R-jed/FineTune`

Upstream bootstrap source: `ronitsingh10/FineTune`

Bootstrap commit: `2285279d36d3f8115c1c2d4aecd904f1bdf96a51`

License: GNU GPL v3. Preserve the original copyright notice.

## Branch and PR topology

`main` remains the stable base and must not be changed or merged into without explicit authorization.

PR #10 remains the single Draft integration baseline:

- branch: `integration/full-product-acceptance`
- head: `d0f8dc7162218996ef5dc5b5bcf789ce6f47a2f4`
- exact-head CI #240 / run `32979014417`: Build passed, complete non-UI Tests passed, test-result upload passed
- PR state: open, Draft, unmerged

The latest validated product code is one commit ahead of that integration baseline on the temporary Loudness lifetime verification branch:

- branch: `fix/loudness-equalizer-rt-lifetime`
- head: `639af28e4a8123e1bbc655591a6586c2b8420c17`
- parent: `d0f8dc7162218996ef5dc5b5bcf789ce6f47a2f4`
- exact-head CI #269 / run `33047168061`: completed successfully
- PR #12: open, Draft, unmerged, verification carrier only, do not merge

The next UI iteration starts from the validated `639af28e...` product tree on:

- branch: `feat/reorder-liquid-glass-ui`

This branch is for the combined reorder-motion and menu-bar Liquid Glass iteration. Keep it short-lived and do not merge to `main`.

## Product language specification

FineTune-owned UI supports exactly two languages:

- English
- Simplified Chinese

The in-app selector exposes exactly:

- `Auto`
- `English`
- `简体中文`

Persisted enum identities remain stable:

- `.system` -> `system`
- `.english` -> `en`
- `.simplifiedChinese` -> `zh-Hans`

`Auto` reads only the first preferred system UI language and maps it to one supported UI language:

- any Chinese identifier -> `zh-Hans`
- every non-Chinese identifier -> `en`
- missing or unusable preferred-language data -> `en`
- only the first preferred language controls the result

Do not add Traditional Chinese UI, Japanese UI, region-specific UI variants, or a large language fallback table without a new product requirement.

## Completed work

### Localization and presentation boundaries

Completed and source-reviewed localization work includes:

- runtime `Auto`, English, and Simplified Chinese language selection with stable persistence
- locale propagation into Settings, menu-bar content, detached popovers, Tahoe HUD, Classic HUD, and per-app HUD hosting roots
- localized Settings, popup, shared controls, EQ, AutoEQ, device presentation, permission presentation, help, accessibility copy, Bluetooth failures, notifications, and privacy-purpose strings
- typed Bluetooth connection failure state
- centralized HUD presentation with Chinese regression coverage
- device notification presentation connected to all three production `AudioEngine` notification paths
- semantic localized fallbacks for missing disconnect/default device names
- localized device-icon category headers, Chinese category search, and localized accessibility descriptors
- localized AutoEQ catalog failure presentation while detailed network diagnostics remain in logs
- generated String Catalog collision handling without disabling generated symbols globally
- dynamic application names, device names, AutoEQ profile/source names, user preset names, UIDs, PIDs, bundle identifiers, versions, URLs, and other external identity values remain verbatim

`LocalizationContext` remains the first-party runtime localization boundary. Preserve `LocalizedStringResource` until the final String-only AppKit or notification boundary.

### App discovery, identity, pinning, and visibility

Completed product behavior includes:

- regular running applications can remain visible without requiring live audio output
- pinned inactive applications retain a stable representation when the process is unavailable
- hiding is reversible presentation state and restoration stays in the existing secondary menu
- pin remains a first-level app-row control
- the unpinned visual state uses the native `pin.slash` symbol
- durable app state is keyed by `persistenceIdentifier`; PID is only the current process representative
- representative identity changes reset transient tap ownership and `VolumeState` before persisted settings are reapplied
- discovery fingerprints include durable identity, process objects, helper state, and source-audio state

Do not regress this into live-audio-only app discovery or PID-owned persistence.

### Routing, taps, DSP, and realtime lifetime work

Completed code-level work includes:

- running-app routing and tap ownership repair across representative process changes
- first-sound routing prearm implementation for quiet already-running apps
- source-activity metering and weak-signal state handling
- Biquad setup retirement based on a real realtime-reader quiescent point
- tap processor-generation ownership so HAL callbacks retain the generation they are processing
- ordered settings and DSP state publication repairs introduced during the integration line

The first-sound routing implementation is present in code, but the physical first-transient acceptance test remains a real-machine gate and must not be marked passed until observed.

### Settings persistence ordering

The settings write path has been repaired so an older debounced write cannot overwrite a newer flush.

The deterministic regression test now drives `SettingsWriteCoordinator` directly rather than depending on `SettingsManager`'s 500 ms debounce/MainActor scheduling. This preserves the stale-write-versus-flush proof without adding timing guesses to the test.

### Loudness Equalization realtime lifetime repair

The latest completed code-level iteration removes the fixed 500 ms lifetime guess previously used when replacing `LoudnessEqualizer` instances.

Final validated commit:

`639af28e4a8123e1bbc655591a6586c2b8420c17`

The focused product diff from `d0f8dc...` contains exactly six files:

- `FineTune/Audio/Engine/ProcessTapController.swift`
- `FineTune/Audio/Engine/RealtimeRetainedReference.swift`
- `FineTune/Audio/Engine/TapProcessorGenerations.swift`
- `FineTune/Audio/Loudness/LoudnessEqualizer.swift`
- `FineTuneTests/ProcessingPipelineTests.swift`
- `FineTuneTests/RealtimeRetainedReferenceTests.swift`

The implementation:

- introduces `RealtimeRetainedReference<Value: AnyObject>`
- reuses the existing `RealtimeQuiescenceGate` instead of duplicating reader-count and epoch logic
- lets realtime readers borrow the current Loudness processor only for the narrow DSP block that needs it
- publishes replacements from the main-actor-owned writer side
- retires replaced objects only after real reader quiescence
- performs final ARC release on the retirement path, away from the HAL callback
- removes the old `DispatchQueue.asyncAfter(... + 0.5)` lifetime grace period

The final lifecycle test suspends the retirement queue, proves the reader can exit without deinitializing the old object, and proves release occurs only after the retirement path is resumed.

Exact-head CI #269 on `639af28e...` passed Build, complete non-UI Tests, and test-result upload.

PR #12 exists only as a red/green verification carrier and must remain Draft and unmerged until it is absorbed or closed by an explicit integration step.

### Existing UI and interaction work

Completed UI behavior includes:

- device priority editing for both output and input devices
- shared `RowReorderDragState` midpoint-crossing logic for vertical reorder gestures
- fast multi-row crossing support in the reorder state machine
- drag offset correction after each adjacent swap so the dragged row stays under the pointer
- drag shadow and z-index lifting for device and app row containers
- EQ expand/collapse behavior and keyboard navigation integration
- hidden-app restoration through the existing secondary menu
- per-app volume wheel adjustment only when Option is held, preserving ordinary list scrolling
- menu-bar icon state updates and crossfade behavior
- Settings, HUD, media-key, notification, Bluetooth, EQ, AutoEQ, and device-detail presentation accumulated on the integration line

One previous handoff claim is intentionally corrected here: App dragging is not currently a complete whole-row interaction. The reorder state and row offset behavior exist, but the active and inactive App `DragGesture` is attached only to the app name/routing-subtitle region. Slider, mute, device picker, EQ, icon, VU meter, and other row areas do not start the drag. Real-machine testing exposed this as an incomplete App reorder UI.

## Verified CI truth

Important exact-head green states include:

- `ad4e09077e708de0989b4e5ceb9bab5d8e22c03e`: localization source-review fixes passed Build and Tests
- `83bf4f880246cf959e7cc1f668e181c37ea88ac9`: later integration Build and complete non-UI Tests passed
- `f7c8caa32079c770aac935fef13fd406b2536908`: app-list interaction and deterministic settings-ordering test repair passed
- `d0f8dc7162218996ef5dc5b5bcf789ce6f47a2f4`: current PR #10 integration baseline, exact-head CI #240 passed
- `639af28e4a8123e1bbc655591a6586c2b8420c17`: Loudness realtime lifetime repair, exact-head CI #269 passed

Intermediate red CI runs were used as evidence and repaired from their actual logs. Do not discard those failures as noise when reviewing the history.

## Local acceptance evidence reported on 2026-08-27

The local acceptance machine reported the following before the current UI iteration:

- current local branch was `fix/loudness-equalizer-rt-lifetime`
- local HEAD matched `639af28e4a8123e1bbc655591a6586c2b8420c17`
- worktree was clean
- local Debug `xcodebuild` completed with `BUILD SUCCEEDED`
- `codesign --verify --deep --strict` passed on the built app
- app entitlements included the source-declared `audio-input`, `bluetooth`, and `network.client` values
- the Debug app was ad-hoc signed, with no TeamIdentifier, which is acceptable for the current local development test path
- the local Git remote fetch refspec was repaired from a stale single-branch refspec to the standard wildcard fetch refspec
- the current local environment required the complete Xcode beta developer directory rather than the standalone Command Line Tools selection
- the outer WorkBuddy sandbox was reported to conflict with nested Xcode/SPM sandbox execution on that machine; disabling the outer sandbox allowed the build to pass

These are local-machine observations reported from the acceptance run. Keep them distinct from GitHub CI evidence.

`com.apple.security.device.audio-input` does not by itself prove Screen & System Audio Recording TCC permission. Runtime audio-capture authorization still requires physical acceptance.

## Current known gaps and failed acceptance items

### App reorder UI

Current status: implementation incomplete, real-machine UI acceptance failed.

Confirmed code behavior:

- `RowReorderDragState` already provides midpoint crossing and origin correction
- `MenuBarPopupView.updateAppDrag` already performs adjacent reorder operations
- active and inactive rows already apply drag offset, shadow, and z-index
- the drag gesture is only attached to the app name/routing-subtitle region
- active row SwiftUI identity also needs review so `persistenceIdentifier` is the stable identity used consistently through reorder animation and keyboard navigation

The next iteration must make the App reorder interaction discoverable and consistent without stealing gestures from slider, mute, picker, EQ, or other controls.

### Output and input device reorder motion

Output and input device edit rows already share `DeviceEditRow` and `deviceDragState`, so their basic behavior is aligned. The visual motion, easing, lifted appearance, drop settling, reverse-direction behavior, and Reduce Motion handling should be reviewed and unified with App reorder behavior in the next iteration.

### macOS 26/27 Liquid Glass

Current status: research complete, product implementation not started.

Current menu popup background stack contains redundant custom material layers:

1. `FluidMenuBarExtra` 1.5.1 creates a custom `NSPanel` whose root `contentView` is `NSVisualEffectView(material: .popover)`.
2. FineTune `MenuBarPopupView` calls `darkGlassBackground()`, which adds another `NSVisualEffectView(material: .popover)`.
3. FineTune adds `popupOverlay`, currently 50% white in light appearance and 40% black in dark appearance.

This double material plus fixed tint overlay suppresses the native Liquid Glass response, especially in light appearance, and also constrains dark appearance to a manually darkened frosted surface.

Apple guidance for modern macOS Liquid Glass favors native system surfaces, avoiding redundant custom backgrounds, and using `NSGlassEffectView` for custom AppKit glass. `NSGlassEffectView` must own its real `contentView`; it should not be placed as a decorative sibling behind the content.

The next implementation must cover Light, Dark, and System appearance together. It must also respect Reduce Transparency, Increase Contrast, Reduce Motion, and the user's system Liquid Glass appearance behavior.

Do not solve this by stacking another `.glassEffect()` on top of the existing two `.popover` materials.

### Runtime gates still pending

The following remain real-machine acceptance gates:

- first-sound routing: system default A, target app routed to B, restart FineTune while target app is running and quiet, then verify the first short transient is heard only on B
- repeat first-sound routing after idle and process-object churn
- sleep/wake restoration
- physical device switching across built-in, USB, and Bluetooth outputs as available
- permission denial, grant, and recovery behavior
- subjective UI and microinteraction smoke
- complete reorder behavior after the next UI repair
- Liquid Glass appearance after the next UI repair

Do not infer these from CI.

## Next combined UI iteration

The next planned slice is maintained in `tasks/reorder-liquid-glass-ui.md`.

The combined iteration has two coordinated but separately testable goals:

1. unify continuous vertical reorder motion for Apps, inactive Apps, output devices, and input devices
2. adopt a correct macOS 26/27 Liquid Glass host for the entire status-bar popup across Light, Dark, and System appearances

They are grouped because both are popup/UI-shell work and require the same real-machine visual acceptance pass. Their implementation boundaries must remain independent so a Liquid Glass host change cannot silently alter reorder semantics, and reorder work cannot touch audio or realtime code.

## Swift and concurrency constraints

The project currently builds with:

- Swift language version 6.0
- `SWIFT_APPROACHABLE_CONCURRENCY = YES`
- no explicit `SWIFT_DEFAULT_ACTOR_ISOLATION` setting in the current target configuration
- no explicit project-level `SWIFT_STRICT_CONCURRENCY` override visible in the current target configuration

The popup, reorder state ownership, AppKit window hosting, and SwiftUI view mutations are UI-bound. Keep their mutable state on the main actor or in SwiftUI state. Do not introduce `Task.detached`, `@unchecked Sendable`, `@preconcurrency`, or `nonisolated(unsafe)` for this UI iteration.

If a delayed UI transition or window-host callback is needed, separate waiting/background work from main-actor mutation instead of adding new unsafe concurrency escapes.

## Liquid Glass architecture decision boundary

`FluidMenuBarExtra` 1.5.1 currently hardcodes an `NSVisualEffectView(.popover)` as the panel content view. FineTune depends on the package for animated resizing, status-item highlighting, screen-edge positioning, and existing popup lifecycle behavior.

Do not migrate to native `MenuBarExtra(.window)` inside this UI slice unless the implementation plan explicitly proves parity for:

- programmatic popup toggle from global shortcuts
- dynamic content-size animation
- status-item highlight behavior
- keyboard focus
- dismissal behavior
- multi-display positioning
- existing menu-bar icon coordinator behavior

Avoid runtime reparenting hacks that introspect and reshuffle FluidMenuBarExtra's private hosting hierarchy after creation.

The preferred implementation should either use a narrowly owned host abstraction or a minimal, reviewable dependency adaptation that replaces the legacy material only on supported systems while preserving the existing window behavior.

Older supported macOS versions need a standard material fallback.

## Dependency and system boundaries

### Sparkle 2.8.1

FineTune uses `SPUStandardUpdaterController`. Sparkle-owned UI follows the dependency's localization and native application-language behavior. Do not replace its user driver in this UI slice.

### KeyboardShortcuts 2.4.0

FineTune-owned labels follow FineTune localization. Recorder placeholders and dependency-owned conflict alerts remain dependency-owned. Do not fork this package in this UI slice.

### FluidMenuBarExtra 1.5.1

Current package revision:

`3ce81bd0e5ab0ae5b027076482f4bd86be30162c`

Its `FluidMenuBarExtraWindow` creates a custom `NSPanel` and uses `.popover` `NSVisualEffectView` as the root content view. This is the key dependency boundary for the Liquid Glass implementation.

### macOS-owned UI

FineTune can localize its own copy and can choose its own custom popup host. macOS owns privacy-prompt chrome, standard file-panel controls, system accessibility adaptations, and the final platform appearance of native Liquid Glass.

## Sensitive files for the next iteration

Treat these as high risk or high-attention:

- `FineTune/Views/MenuBarPopupView.swift`
- `FineTune/Views/Rows/AppRow.swift`
- `FineTune/Views/Rows/InactiveAppRow.swift`
- `FineTune/Views/Rows/AppRowWithLevelPolling.swift`
- `FineTune/Views/Rows/DeviceEditRow.swift`
- `FineTune/Views/Components/RowReorderDragState.swift`
- `FineTune/Views/DesignSystem/ViewModifiers.swift`
- `FineTune/Views/DesignSystem/VisualEffectBackground.swift`
- `FineTune/Views/DesignSystem/DesignTokens.swift`
- `FineTune/Views/DesignSystem/WindowAppearanceBridge.swift`
- `FineTune/FineTuneApp.swift`
- `FineTune/Shortcuts/MenuBarPopupController.swift`
- `FineTune/Views/MenuBar/MenuBarIconCoordinator.swift`
- `FineTune.xcodeproj/project.pbxproj`
- `FineTune.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `FineTuneTests/RowReorderDragStateTests.swift`

Audio, routing, DSP, settings persistence, and Loudness lifetime files are out of scope for the next UI slice unless a failing test proves an actual cross-boundary regression.

## Development rules

Before writing product code:

1. Re-fetch the active branch head.
2. Re-fetch every exact file being changed.
3. Verify the behavior and success criteria in `tasks/reorder-liquid-glass-ui.md`.
4. Check the current Apple API and dependency source when an assumption matters.
5. Prefer the smallest design that removes duplication and keeps old-system fallback isolated.

During implementation:

1. Keep reorder mechanics and Liquid Glass host changes logically separable in the diff.
2. Reuse `RowReorderDragState` unless tests demonstrate a real algorithm defect.
3. Keep App and device reorder visual treatment shared where practical.
4. Do not attach a reorder gesture across controls that already own drag/click gestures.
5. Keep Liquid Glass to the functional popup layer and important controls; do not turn every content card into independent glass.
6. Respect Light, Dark, System, Reduce Transparency, Increase Contrast, and Reduce Motion.
7. Do not add fixed-time lifetime guesses, unsafe concurrency escapes, or legacy fallback paths beyond the explicit old-system visual fallback.

Before claiming completion:

1. Run Build and the complete non-UI Test suite from the final exact head.
2. Review the exact final diff against `639af28e...` for this UI iteration and against the integration baseline for accidental drift.
3. Verify no audio, realtime, routing, settings persistence, signing, release, or appcast code changed unless explicitly required.
4. Perform real-machine reorder acceptance for active Apps, inactive Apps, output devices, and input devices.
5. Perform real-machine Liquid Glass acceptance in Light, Dark, and System appearances, with contrasting wallpapers and accessibility settings.
6. Re-run first-sound and sleep/wake gates if the popup-host change can affect lifecycle timing.
7. Keep PR #10 and any short-lived verification PR Draft and unmerged until explicit authorization.
