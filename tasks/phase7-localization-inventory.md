# Phase 7 Localization Completeness Inventory

Date: 2026-08-23
Branch: `feature/ui-localization`
PR: #5

This document records the current completeness audit. It does not authorize merge.

## Classification rules

Localize FineTune-owned user-facing copy, including help, accessibility text, notifications, errors, status, fallback labels, and custom AppKit presentation.

Keep external or technical identity values verbatim, including app names, device names, user preset names, AutoEQ profile/model/source names, UIDs, PIDs, bundle identifiers, URLs, SF Symbols, persistence keys, protocol tokens, standard technical units, and developer logs.

Preserve `LocalizedStringResource` until the final String-only boundary. Keep `FineTune/Localizable.xcstrings` as the single first-party UI catalog and `FineTune/InfoPlist.xcstrings` for localized Info.plist values.

## First-party completeness work verified

The Phase 7 pass found and addressed the following real gaps:

- detached popover `NSHostingView` roots now receive the selected FineTune locale
- Tahoe, Classic, and per-app HUD roots now receive the selected locale
- HUD static text and accessibility announcements are centralized through localized presentation
- mute/help copy preserves localizable resource typing
- Bluetooth connection failures use typed state and localize at presentation
- AutoEQ external profile names remain verbatim while FineTune-owned disabled-state copy localizes
- static accessibility labels are separated from dynamic values
- missing permission-banner and shared-control catalog entries were added
- generated String Catalog collisions for ` (off)` and `Volume boost:` were resolved without disabling catalog symbols globally
- device notification presentation has English and Simplified Chinese tests, including semantic fallback names
- all three production `AudioEngine` notification methods now use `DeviceNotificationPresentation`

## Device notification integration

Verified production commit:

`b556b5019b8dc21931416094b0a5c5dc0d30647d`

Relative to its parent, only `FineTune/Audio/Engine/AudioEngine.swift` changed.

The implementation:

- passes an optional fallback device name on disconnect
- resolves missing fallback through `notification.noFallbackDevice`
- passes an optional default-device name to default-change presentation
- resolves missing default name through `notification.defaultOutputFallback`
- uses the current `settingsManager.appSettings.language`
- keeps real device names verbatim
- preserves notification enablement, identifiers, sound behavior, delivery callbacks, error logging, and audio routing/default-device behavior

The candidate was built from the exact source blob and compared before advancing the production branch. An accidental missing final newline in the first candidate was detected and rejected before production advancement.

## Catalog and automated coverage

Confirmed catalog entries include:

- `Auto` -> `自动`
- `notification.noFallbackDevice` -> `无可用设备`
- `notification.defaultOutputFallback` -> `默认输出设备`
- notification reconnect/disconnect/default-change resources
- Phase 7 permission, shared-control, Bluetooth, HUD, help, and accessibility resources

The legacy `Follow System` catalog entry remains unused. Removing it is optional cleanup and is not worth a risky large-catalog rewrite by itself.

Automated tests cover representative first-party resources across Settings, popup/device presentation, EQ, AutoEQ, device inspector, Phase 7 shared resources, HUD presentation, notification presentation, privacy strings, persistence compatibility, and Auto language resolution.

CI #83 at `b556b5019b8dc21931416094b0a5c5dc0d30647d` passed Build, Test, test-result upload, and the complete job.

## Auto language policy

The earlier Follow System behavior has been superseded.

The selector is now:

- `Auto`
- `English`
- `简体中文`

`Auto` retains the persisted raw value `system` for backward compatibility but always resolves FineTune-owned UI to one concrete supported language:

- first preferred language is Chinese -> `zh-Hans`
- first preferred language is anything else -> `en`
- no usable preferred language -> `en`

Only the first preferred language controls the result.

## Dynamic values verified as intentionally verbatim

No localization lookup should be applied to:

- application names
- audio-device names
- user-created EQ preset names
- AutoEQ external profile/model/source names
- device UIDs and PIDs
- bundle IDs
- version/build values
- URLs
- SF Symbol names
- technical identifiers and protocol keys

The notification tests explicitly verify dynamic device names remain unchanged in both English and Simplified Chinese presentation.

## Dependency and system boundaries

### Sparkle 2.8.1

FineTune uses `SPUStandardUpdaterController`.

Sparkle 2.8.1 ships Chinese resources, but its standard UI resolves strings from the Sparkle framework bundle. FineTune's runtime locale override does not control that bundle lookup. The standard updater therefore follows native bundle/application language selection rather than being guaranteed to follow FineTune's in-app selector.

Replacing the standard Sparkle user driver is outside the approved scope.

### KeyboardShortcuts 2.4.0

The package ships `zh-Hans` resources. `RecorderCocoa` resolves its package-owned strings through `NSLocalizedString(..., bundle: .module)`.

FineTune's shortcut section labels/descriptions follow the FineTune selector. Recorder placeholders and dependency-owned conflict alerts are not guaranteed to follow the FineTune runtime override when native application language differs.

Forking or replacing KeyboardShortcuts solely to force this behavior is outside the approved scope.

### macOS-owned surfaces

FineTune localizes its own privacy purpose strings and custom AppKit messages. macOS owns privacy-prompt chrome and standard panel controls. Their language remains a native system/application-language boundary.

## Main-branch drift review

The feature branch was compared against `main` after the AudioEngine integration.

Confirmed observations:

- no dependency version upgrade was introduced
- no release/appcast/signing change was observed
- AudioEngine changes are limited to notification presentation wiring
- adversarial spot checks of `DeviceVolumeProviding`, `DeviceInspectorInfoGrid`, and `HUDStyleSegmentedControl` showed presentation/localization changes rather than unrelated business-logic changes

This is strong review evidence, but it is not a substitute for the final visual runtime matrix.

## Environment limitations

The current execution environment cannot run the macOS GUI.

A direct local clone for an additional machine regex scan was also unavailable because the container could not resolve `github.com`. Current conclusions therefore rely on exact GitHub source reads, Git diffs, String Catalog tests, focused source review, and CI.

Do not claim the following have been visually verified here:

- Settings every tab at target size
- popup Compact, Comfortable, and Spacious layouts
- all Output/Input/edit/EQ/AutoEQ/device-detail states
- live clipping, wrapping, or truncation behavior
- live Sparkle/KeyboardShortcuts/system-dialog language under mismatched native and FineTune languages

## Phase 7 verdict

FineTune-owned production localization blockers found by the Phase 7 source audit have been implemented and are green under automated Build/Test verification.

The remaining completion gate is runtime and visual verification on macOS, plus accurate observation of dependency/system-owned surfaces. Those surfaces are explicitly outside the first-party runtime-language guarantee.

PR #5 must remain unmerged until explicit authorization.
