# Phase 7 Localization Completeness Inventory

Date: 2026-08-23
Branch: `feature/ui-localization`
PR: #5

This is an audit record. It does not mark Phase 7 complete and does not authorize merge.

## Classification rules

- Localize FineTune-owned user-facing copy, including help text, accessibility text, notifications, inline errors, and fallback labels.
- Keep app names, device names, user preset names, AutoEQ profile/model/source names, UIDs, PIDs, units, URLs, SF Symbol names, persistence keys, protocol tokens, and log/debug text verbatim.
- Prefer `LocalizedStringResource` at SwiftUI presentation boundaries.
- Resolve to `String` only at boundaries that require `String`, using `LocalizationContext` and the selected `AppLanguage`.
- Do not introduce a second general-purpose string catalog. New first-party UI strings belong in `FineTune/Localizable.xcstrings`.

## Required: detached SwiftUI roots lose the selected FineTune locale

### `FineTune/Views/HUD/HUDWindowController.swift`

The Tahoe, Classic, and per-app HUDs are hosted in independent `NSHostingView` roots. They currently apply the preferred color scheme but do not propagate FineTune's resolved locale.

Required change:

- Resolve the locale from `settingsManager.appSettings.language`.
- Apply the same locale override semantics used by the Settings and menu-bar roots to every HUD hosting root.
- Preserve Follow System behavior by leaving the locale unforced when `LocalizationContext.overrideLocale` is `nil`.

### `FineTune/Views/Components/PopoverHost.swift`

`PopoverHost` creates another independent `NSHostingView` and currently propagates appearance only. This affects all consumers, including `DropdownMenu`, `GroupedDropdownMenu`, `DevicePicker`, and `AutoEQPicker`.

Required change:

- Read the parent SwiftUI `locale` environment in `PopoverHost`.
- Propagate that locale into the hosted root in both initial creation and content updates.
- Fix the shared host once rather than patching each picker separately.

## Required: user-facing text is assembled as plain `String`

### HUD presentation

Files:

- `FineTune/Views/HUD/HUDWindowController.swift`
- `FineTune/Views/HUD/TahoeStyleHUD.swift`
- `FineTune/Views/HUD/ClassicStyleHUD.swift`

Confirmed FineTune-owned English includes:

- `Unknown device`
- `Muted`
- `Unmuted`
- `Not controlled by FineTune`
- `FineTune isn't controlling this app yet`
- device/app volume accessibility sentences
- muted/unmuted accessibility sentences
- not-controlled accessibility sentences

Required change:

- Keep dynamic device/app names verbatim.
- Move static wording to localizable resources.
- Resolve AppKit accessibility announcements through `LocalizationContext` before passing them to `NSAccessibility.post`.
- Use localizable resource values directly for SwiftUI accessibility labels/status text where possible.

### `FineTune/Views/Components/MuteButton.swift`

`BaseMuteButton` accepts help copy as plain `String`, and `InputMuteButton` supplies microphone-specific English strings.

Required change:

- Change static help-copy parameters from `String` to `LocalizedStringResource`.
- Localize `Mute`, `Unmute`, `Mute microphone`, and `Unmute microphone`.

### `FineTune/Views/Rows/DeviceRow.swift`

The AutoEQ subtitle currently constructs `"<profile name> (off)"` as a plain `String` and later renders the complete value verbatim.

Required change:

- Keep the external AutoEQ profile name verbatim.
- Localize only FineTune-owned `off` state copy through a localizable interpolated presentation value.

### `FineTune/Audio/Monitors/BluetoothDeviceMonitor.swift`

`connectionErrors` is currently `[String: String]`, and the monitor writes `Couldn't connect` and `Connection timed out` directly into state rendered by `PairedDeviceRow`.

Required change:

- Replace display-string state with a typed connection error, for example `BluetoothConnectionError` with `couldNotConnect` and `timedOut` cases.
- Convert the typed error to localized presentation at the UI boundary.
- Keep IOBluetooth return values, MAC addresses, and logger messages outside localization.

This removes UI-language knowledge from the Bluetooth monitor instead of embedding localized strings in a lower audio layer.

## Required: catalog entries missing for already-localizable SwiftUI call sites

The current main `FineTune/Localizable.xcstrings` has no matching entries for the following confirmed production copy families. The SwiftUI call sites are already capable of localization or need only the small type corrections described above.

### Permission banner

`FineTune/Views/Components/PermissionBannerView.swift`

- `Audio capture access required`
- `Enable in System Settings → Privacy & Security → Screen & System Audio Recording`
- `Open System Settings`
- `Grant Access`

### Shared controls and rows

- `FineTune/Views/Components/EditablePercentage.swift`: `Edit volume percentage`
- `FineTune/Views/Components/MuteButton.swift`: `Mute`, `Unmute`, `Mute microphone`, `Unmute microphone`
- `FineTune/Views/Components/RadioButton.swift`: `Default device`, `Set as default`
- `FineTune/Views/Components/BoostChevrons.swift`: the localizable `Volume boost` help/accessibility interpolation
- `FineTune/Views/Rows/AppEditRow.swift`: `Pin app`, `Unpin app`, `Ignore app`, `Stop ignoring`
- `FineTune/Views/Rows/AppRowControls.swift`: `Close Equalizer`
- `FineTune/Views/Rows/PairedDeviceRow.swift`: `Connect`
- `FineTune/Views/Rows/AppRow.swift`: the localizable `Open <app name>` accessibility interpolation

### Source-fix entries to add in the same catalog pass

The source fixes above will also need catalog entries for:

- HUD static copy and accessibility sentence templates
- Bluetooth connection failure and timeout presentation
- AutoEQ disabled-state interpolation
- notification fallback labels described below

## Required: connect the three `AudioEngine` notification call sites to the existing helper

`FineTune/Utilities/DeviceNotificationPresentation.swift` already owns tested English/Simplified-Chinese notification presentation for reconnect, disconnect, and default-device-change events.

`FineTune/Audio/Engine/AudioEngine.swift` still constructs the three production notifications directly in English.

Required change:

- `showReconnectNotification`: call `DeviceNotificationPresentation.reconnected(...)`.
- `showDisconnectNotification`: call `DeviceNotificationPresentation.disconnected(...)`.
- `showDefaultChangedNotification`: call `DeviceNotificationPresentation.defaultChanged(...)`.
- Supply `settingsManager.appSettings.language` to all three helper calls.
- Leave notification delivery and identifier behavior unchanged.

Two additional FineTune-owned fallback strings are currently created inside `AudioEngine` and must not remain English-only:

- disconnect fallback: `none`
- unresolved new default output: `Default Output`

Preferred design:

- Change the helper to accept optional fallback/default device names.
- Resolve `nil` to localized semantic fallback resources inside `DeviceNotificationPresentation`.
- Preserve real device names verbatim.
- Add focused English and Simplified-Chinese tests for the nil fallback cases before changing the `AudioEngine` call sites.

## Confirmed already safe or intentionally verbatim

No source change is required for the following items from this pass:

- `SettingsRow` and `SettingsSection` already use `LocalizedStringResource` for first-party static presentation.
- `AudioTab` therefore passes its static labels through a localization-safe shared boundary.
- `ShortcutAction.displayName`, Settings UI enum `displayName` values, EQ category/preset display values, and `ModeToggle` use localized presentation types while stable raw/Codable values stay unchanged.
- `EQPresetPicker` uses `EQPreset.displayName` for built-in presets and `Text(verbatim:)` for user preset names.
- `DeviceIconPicker` maps the five built-in category names to localized resources and keeps SF Symbol identifiers/search keywords verbatim.
- `SystemSoundsDevicePicker` has no first-party copy of its own.
- `VolumeSlider` has no additional first-party copy beyond `EditablePercentage`.
- `InputDeviceRow` has no additional first-party copy beyond the shared controls.
- `VUMeter`, `DeviceBadge`, `ExpandableGlassRow`, and `LiquidGlassSlider` have no additional shipping copy requiring localization in this pass.
- `URLHandler` strings are URL protocol tokens and logs.
- `AccessibilityPermissionService` strings are API constants, settings URLs, and logs.
- `AudioRecordingPermission` strings are API/SPI identifiers and logs.
- `UpdateManager` delegates updater chrome to Sparkle; dependency-language behavior remains a separate manual boundary check.
- `MenuBarPopupController` uses `FineTune` as the product/accessibility identity used to locate the status item; it must stay stable.
- `BoostLevel` labels `1x` through `4x` are numeric multiplier notation and remain verbatim.
- app names, device names, user preset names, AutoEQ external names, SF Symbols, persistence identifiers, and technical units remain verbatim by design.

## Safe edit strategy

### `FineTune/Localizable.xcstrings`

Use one JSON-aware/catalog-aware edit against the existing main catalog. Do not create another catalog and do not replace the catalog from a hand-reconstructed copy.

Verification before commit:

1. Parse the resulting file as JSON.
2. Confirm all pre-existing keys remain present.
3. Confirm every added entry has source English and Simplified Chinese values as intended.
4. Confirm interpolation placeholders match between source and Chinese translations.
5. Build with Xcode so String Catalog diagnostics can report stale or invalid entries.
6. Review the catalog diff separately from behavioral source changes where practical.

### `FineTune/Audio/Engine/AudioEngine.swift`

Do not use a complete-file replacement through the current GitHub contents API. The file is about 100 KB and only three localized notification methods plus two fallback expressions need changes; whole-file reconstruction creates disproportionate truncation and accidental-edit risk.

Safe implementation requires a patch-capable working tree or equivalent line-level edit mechanism:

1. Patch only the three notification methods and the two fallback expressions.
2. Run focused notification-presentation tests.
3. Run the canonical Debug build.
4. Run the canonical test suite excluding UI tests.
5. Inspect `git diff -- FineTune/Audio/Engine/AudioEngine.swift` and require the diff to contain only the intended notification integration.
6. Compare the branch against `main` before merge review.

The current ChatGPT GitHub connector exposes complete-file replacement for an existing file, so it is not an acceptable write path for this `AudioEngine.swift` change.

## Verification gates before Phase 7 can be called complete

- All Required items above are implemented.
- The main String Catalog parses and contains the added English/Chinese resources.
- Explicit English, explicit Simplified Chinese, and Follow System behavior are checked for HUD and shared popovers.
- Bluetooth failure/timeout states are checked in both explicit languages.
- Permission banner states are checked in both explicit languages.
- Notification reconnect/disconnect/default-change presentation is checked in both explicit languages, including nil fallback names.
- Dynamic app/device/profile/user-preset names remain verbatim.
- `xcodebuild build -project FineTune.xcodeproj -scheme FineTune -configuration Debug CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO` passes.
- `xcodebuild test -project FineTune.xcodeproj -scheme FineTune -configuration Debug -skip-testing:FineTuneUITests CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO -resultBundlePath build/TestResults.xcresult` passes.
- Final diff has no unrelated audio-engine, release, signing, appcast, dependency, or repository drift.
- PR #5 remains unmerged until explicit authorization.
