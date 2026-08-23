# Phase 7 Localization Completeness Inventory

Date: 2026-08-24
Branch: `feature/ui-localization`
PR: #5

This document records the current first-party localization audit. It does not authorize merge.

## Classification rules

Localize FineTune-owned user-facing copy, including help, accessibility text, notifications, errors, status, fallback labels, and custom AppKit presentation.

Keep external or technical identity values verbatim, including app names, device names, user preset names, AutoEQ profile/model/source names, UIDs, PIDs, bundle identifiers, URLs, SF Symbols, persistence keys, protocol tokens, standard technical units, and developer logs.

Preserve `LocalizedStringResource` until the final String-only boundary. Keep `FineTune/Localizable.xcstrings` as the single first-party UI catalog and `FineTune/InfoPlist.xcstrings` for localized Info.plist values.

## First-party completeness work verified

The source audit found and addressed these real gaps:

- Settings and menu-bar roots receive the selected FineTune locale
- detached popover `NSHostingView` roots receive the selected locale
- Tahoe, Classic, and per-app HUD roots receive the selected locale
- HUD static text and accessibility announcements are centralized through localized presentation
- mute/help copy preserves localizable resource typing
- Bluetooth connection failures use typed state and localize at presentation
- static accessibility labels are separated from dynamic values
- permission-banner and shared-control catalog resources are present
- generated String Catalog collisions for ` (off)` and `Volume boost:` are handled without disabling generated symbols globally
- built-in EQ and AutoEQ first-party presentation is localized while external profile/source names remain verbatim
- device inspector/detail presentation is localized while technical facts remain stable
- all three production `AudioEngine` notification methods use `DeviceNotificationPresentation`
- missing notification fallback device names resolve through semantic localized resources
- device-icon category headers, representative Chinese category search, help, and accessibility descriptors follow the selected locale
- AutoEQ catalog failure presentation no longer exposes the fetcher's English runtime diagnostic string in the Chinese UI

## Final source-review fixes

A concurrent device-icon localization commit introduced a compile regression:

`5ebf8735936b4cc2d52668c2282f4015bb5d161a`

CI #85 failed because `LocalizedStringResource` was passed to the wrong `String(localized:locale:)` overload in `DeviceIconPicker` and its test.

The repair retained the typed resource boundary:

- `603a2731f2829d4d2a0e08de8afcf8934e203acc` corrected production device-icon resource resolution
- `5a5272ce26004e64c62e8eb6140185d1ee6ad832` corrected the resource-resolution test to use `LocalizationContext`

The final source review also found a real AutoEQ presentation leak. `AutoEQFetcher.FetchState.error(String)` carries English diagnostics such as catalog/network failures and `AutoEQSearchPanel` rendered that string verbatim. Commit:

`ad4e09077e708de0989b4e5ceb9bab5d8e22c03e`

changed only the panel's catalog-failure presentation to the existing localized `Failed to load` resource. Detailed diagnostics remain available to the fetcher/logging path.

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

## Catalog and automated coverage

The full current String Catalog blob was rechecked after a truncated API response initially caused false-negative searches. Confirmed resources include:

- `Auto` -> `自动`
- `Single` -> `单设备`
- `Multi` -> `多设备`
- `System Audio` -> `系统音频`
- device-icon category and accessibility resources
- EQ and AutoEQ resources
- device-inspector resources
- Bluetooth failure resources
- notification reconnect/disconnect/default-change resources
- `notification.noFallbackDevice` -> `无可用设备`
- `notification.defaultOutputFallback` -> `默认输出设备`
- HUD semantic resources including `hud.muted`
- `Failed to load` -> `无法加载`

Do not repeat the earlier false conclusion that `System Audio`, `Single`, or `hud.muted` are absent. That conclusion came from searching a truncated file response rather than the full blob.

The legacy `Follow System` catalog entry remains unused. Removing that single unused manual entry is optional cleanup and is not worth a risky large-catalog rewrite by itself.

Automated tests cover representative first-party resources across Settings, popup/device presentation, EQ, AutoEQ, device inspector, device-icon discovery, shared Phase 7 resources, HUD presentation, notification presentation, privacy strings, persistence compatibility, and Auto language resolution.

## CI state

Verified production-code head before the final documentation refresh:

`ad4e09077e708de0989b4e5ceb9bab5d8e22c03e`

CI #87 passed Build, Test, test-result upload, and the complete job.

- run id: `32651747504`
- job id: `97224371006`

Earlier relevant CI:

- CI #83 passed after production AudioEngine notification integration
- CI #84 passed after the earlier documentation synchronization
- CI #85 failed on the device-icon localization compile regression and directly exposed the invalid overload use

A later documentation-only branch head may exist after this inventory refresh. Re-fetch it and check its CI rather than treating the documentation commit as a new production-code baseline.

## Auto language policy

The earlier Follow System behavior has been superseded.

The selector is:

- `Auto`
- `English`
- `简体中文`

`Auto` retains persisted raw value `system` for backward compatibility and always resolves FineTune-owned UI to one concrete supported language:

- first preferred language is Chinese -> `zh-Hans`
- first preferred language is anything else -> `en`
- no usable preferred language -> `en`

Only the first preferred language controls the result. The user's current region remains available for regional formatting.

## Dynamic values intentionally verbatim

Do not localize:

- application names
- audio-device names
- user-created EQ preset names
- AutoEQ external profile/model/source names
- device UIDs and PIDs
- bundle IDs
- version/build values
- URLs
- SF Symbol identifiers
- technical identifiers and protocol keys

The notification tests explicitly verify dynamic device names remain unchanged in both supported languages.

`SettingsManager.createUserPreset` still has a defensive `"Untitled"` fallback for an empty name. The reviewed shipping `EQPanelView` trims and rejects empty input before calling that API, so this fallback is not exposed by the current product UI. If a future user-facing caller can pass an empty name, revisit the fallback at that boundary rather than making stored user preset identity locale-dependent without a requirement.

## Dependency and system boundaries

### Sparkle 2.8.1

FineTune uses `SPUStandardUpdaterController`.

Sparkle standard UI resolves strings from the Sparkle framework bundle. FineTune's runtime locale override does not control that bundle lookup. Standard updater UI is therefore not guaranteed to follow FineTune's in-app selector when native application language differs.

Replacing the standard Sparkle user driver or forcing process language is outside the approved scope.

### KeyboardShortcuts 2.4.0

The package ships `zh-Hans` resources. Package-owned Recorder strings resolve from the package resource bundle.

FineTune-owned Shortcuts labels/descriptions follow the FineTune selector. Recorder placeholders and dependency-owned conflict alerts are not guaranteed to follow FineTune's runtime override during a native/FineTune language mismatch.

Forking or replacing KeyboardShortcuts solely to force this behavior is outside the approved scope.

### macOS-owned surfaces

FineTune localizes its privacy purpose-string values and its own custom AppKit messages. macOS owns privacy-prompt chrome and standard panel controls, which remain native platform/application-language surfaces.

## Full-repository drift review

The final review included PR-changed files and targeted high-risk unchanged presentation files under `Views`, `Settings`, `Utilities`, `Coordination`, and menu-bar support code.

Observed first-party presentation boundaries are either catalog-backed/localized or intentionally dynamic/technical. Logging-only English strings were not classified as UI.

The final feature branch still requires one last compare against `main` immediately before merge review. Earlier compares showed no dependency upgrade, release, signing, or appcast drift and no unrelated AudioEngine business-logic changes.

## Environment limitations

The current execution environment cannot run the macOS GUI.

A direct local clone for an additional machine regex scan was also unavailable because the container could not resolve `github.com`. Current conclusions rely on exact GitHub source reads, Git diffs, full String Catalog inspection, focused source review, tests, and CI.

Do not claim these have been visually verified here:

- every Settings tab in English, Simplified Chinese, and Auto
- Compact, Comfortable, and Spacious popup layouts
- every Output/Input/edit/EQ/AutoEQ/device-detail state
- live clipping, wrapping, truncation, visual quality, and translation quality
- live notification appearance and VoiceOver/help behavior
- live Sparkle, KeyboardShortcuts, privacy-prompt, and standard file-panel behavior under native/FineTune language mismatch

## Phase 7 verdict

At verified production-code head `ad4e09077e708de0989b4e5ceb9bab5d8e22c03e`, the first-party localization blockers found by source review are implemented and CI #87 is green.

The remaining gate is local macOS GUI/runtime verification plus final dependency/system observation and a fresh `main` comparison immediately before merge review.

PR #5 must remain unmerged until explicit authorization.
