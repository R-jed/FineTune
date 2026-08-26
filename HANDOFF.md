# FineTune Project Handoff

Last updated: 2026-08-26

Read this file before changing code. Re-fetch the branch head and every sensitive file before each write.

## Project identity

FineTune is a macOS menu bar audio-control application. It controls per-app volume and gain, application routing, output and input device levels, EQ, AutoEQ, global shortcuts, media keys, and FineTune-owned volume HUDs.

Repository: `R-jed/FineTune`

Upstream bootstrap source: `ronitsingh10/FineTune`

Bootstrap commit: `2285279d36d3f8115c1c2d4aecd904f1bdf96a51`

License: GNU GPL v3. Preserve the original copyright notice.

## Active development state

Stable base: `main`

Active acceptance branch: `integration/full-product-acceptance`

Pull request: #10, `integration: full product acceptance`

PR #10 integrates the current product/UI/localization work with running-app discovery, source-activity metering, Biquad realtime quiescence, tap processor-generation ownership, identity/lifecycle repairs, and ordered settings persistence.

Verified integration-code head before this handoff refresh:

`83bf4f880246cf959e7cc1f668e181c37ea88ac9`

CI #152 on that exact code head passed Build, the complete non-UI Test suite, test-result upload, and the complete job.

PR #10 is Draft and unmerged. Do not merge it without explicit authorization. The next gate is local macOS acceptance on the final exact head.

A documentation-only commit may follow the verified code head above. Do not treat that as product-code drift. Re-fetch the current branch head before starting work and confirm any later CI result.

The localization source work originated on PR #5. Historical localization details below remain useful, but PR #10 is the current acceptance baseline.

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

`Auto` is the product behavior of the persisted `.system` case. It reads only the first preferred system UI language and maps it to one supported UI language:

- any Chinese identifier -> `zh-Hans`
- every non-Chinese identifier -> `en`
- missing or unusable preferred-language data -> `en`
- only the first preferred language controls the result

Verified examples include `zh-Hans-CN`, `zh-Hant-TW`, `zh_CN`, and `zh` mapping to `zh-Hans`; `en-AU`, `ja-JP`, and `fr-FR` mapping to `en`; an empty list mapping to `en`; and `["ja-JP", "zh-Hans"]` mapping to `en` because only the first item controls Auto.

Do not reintroduce the earlier Follow System runtime semantics. Do not add Traditional Chinese UI, Japanese UI, region-specific UI variants, or a large language fallback table.

## Localization architecture

`AppLanguage` owns stable persistence identity and deterministic resolution to `en` or `zh-Hans`.

`LocalizationContext` is the first-party runtime localization boundary. It forces FineTune-owned presentation to one supported language while retaining the user's region for regional formatting.

Preserve `LocalizedStringResource` while text crosses SwiftUI or presentation layers. Resolve to plain `String` only at final String-only boundaries such as AppKit APIs and `UNMutableNotificationContent`.

Do not add a generic `localized(_ key: String)` production overload. CI #79 demonstrated why the typed resource boundary matters.

Keep dynamic external identity values verbatim, including application names, audio-device names, user EQ preset names, AutoEQ profile/model/source names, UIDs, PIDs, bundle identifiers, versions, build numbers, URLs, SF Symbol identifiers, and technical identifiers.

Keep one first-party UI catalog: `FineTune/Localizable.xcstrings`. `FineTune/InfoPlist.xcstrings` is dedicated to localized Info.plist values.

Detached `NSHostingView` roots are explicit locale boundaries. Current fixes cover shared popovers, Tahoe HUD, Classic HUD, and per-app HUD roots.

## Verified implementation state

Completed and source-reviewed work includes:

- runtime `Auto`, English, and Simplified Chinese language selection with stable persistence
- locale propagation into Settings, menu-bar content, detached popovers, and all FineTune HUD hosting roots
- localized Settings, popup, shared controls, EQ, AutoEQ, device presentation, permission presentation, help, accessibility copy, Bluetooth failures, notifications, and privacy-purpose strings
- typed Bluetooth connection failure state
- centralized HUD presentation with Chinese regression coverage
- device notification presentation connected to all three production `AudioEngine` notification paths
- semantic localized fallbacks for missing disconnect/default device names
- dynamic application, device, AutoEQ profile/source, and user preset names kept verbatim
- generated String Catalog collision handling without disabling generated symbols globally
- localized device-icon category headers, Chinese category search, and localized accessibility descriptors
- localized AutoEQ catalog failure presentation while detailed network diagnostics remain in logs

The notification integration is commit:

`b556b5019b8dc21931416094b0a5c5dc0d30647d`

The final localization source-review fixes are:

- `5ebf8735936b4cc2d52668c2282f4015bb5d161a`: device-icon discovery localization was introduced, but CI #85 found an invalid `String(localized:locale:)` overload use
- `603a2731f2829d4d2a0e08de8afcf8934e203acc`: corrected the device-icon resource resolution boundary
- `5a5272ce26004e64c62e8eb6140185d1ee6ad832`: corrected the corresponding tests to use the typed localization boundary
- `ad4e09077e708de0989b4e5ceb9bab5d8e22c03e`: localized the AutoEQ catalog failure state using existing FineTune-owned catalog copy

The AutoEQ fix intentionally leaves `AutoEQFetcher`'s detailed English diagnostic strings in its internal state/logging path. The user-facing panel no longer renders those strings verbatim.

## Integrated acceptance invariants

The current acceptance contract is maintained in `tasks/full-product-acceptance-review.md`. In particular:

- running regular applications stay visible without requiring live audio
- pinning preserves inactive representation, while hiding is reversible presentation state
- `persistenceIdentifier` is durable app identity and PID is only the current process representative
- tap ownership and transient `VolumeState` are reset when representative identity changes
- source-activity metering, Biquad realtime quiescence, and tap processor-generation ownership retain their reviewed behavior
- settings persistence is ordered so an older debounced write cannot overwrite a newer flush

Do not weaken these invariants to preserve older implementation shortcuts.

## CI truth

Important history:

- CI #73 passed after centralized HUD presentation.
- CI #77 found generated String Catalog symbol collisions.
- CI #78 and #79 exposed a test-only type error at the typed localization boundary.
- CI #81 passed after that test-boundary repair.
- CI #82 passed on the pre-notification handoff state.
- CI #83 passed after production `AudioEngine` notification integration.
- CI #84 passed on the documentation-synchronized branch state.
- CI #85 failed during Build because `DeviceIconPicker` and its test used the wrong `String(localized:locale:)` overload with `LocalizedStringResource`.
- CI #87 at `ad4e09077e708de0989b4e5ceb9bab5d8e22c03e` passed Build, Test, test-result upload, and the complete job after the localization source-review fixes.
- CI #148 exposed one localization test-environment failure while validating a staged settings-write repair; the failure was unrelated to settings write ordering.
- The settings-write repair was then committed to source, the temporary CI source-rewrite/writeback path was removed, and later fixes restored the full suite.
- CI #152 at `83bf4f880246cf959e7cc1f668e181c37ea88ac9` passed Build, the complete non-UI Test suite, test-result upload, and the complete job.

CI #152 details:

- run id: `32914781316`
- job id: `98016182625`

Treat `83bf4f880246cf959e7cc1f668e181c37ea88ac9` as the verified integration-code baseline before this handoff refresh. If the current branch head is a later documentation-only commit, inspect its diff and exact-head CI before assuming product code changed.

## Full-repository review findings

The source review covered both PR-changed files and high-risk presentation, app-discovery, settings-persistence, audio-lifetime, and identity boundaries.

Confirmed examples include:

- `ThemeTilePicker`, popup-size controls, and Shortcuts use localized display resources rather than English `description` values
- `UpdatesTab` formats relative dates with `LocalizationContext.presentationLocale`
- `MenuBarPopupView` localizes its custom AutoEQ `NSOpenPanel.message` and keeps imported external names verbatim
- `DeviceDetailSheet` uses localizable tier resources
- `AppRowControls`, `RadioButton`, `EditablePercentage`, `PermissionBannerView`, and app/device edit controls use catalog-backed SwiftUI copy
- `URLHandler` user-like English strings are logs, not presentation
- `UpdateManager` delegates standard updater UI to Sparkle, which is a dependency-owned localization boundary
- menu-bar icon coordinator strings are identity/logging values rather than localized interface prose
- running-app discovery fingerprints include durable identity, process objects, helper state, and source-audio state
- same-PID identity replacement rebuilds transient volume state before persisted settings are applied
- HAL callbacks retain their processor generation instead of dynamically borrowing a replacement generation
- Biquad setup retirement waits for a real realtime-reader quiescent point
- `SettingsManager` serializes persistence writes and its termination flush drains older queued writes

The review also rechecked the full current String Catalog blob after a truncated API response initially produced false-negative searches. Current catalog entries include device-picker, mode-toggle, EQ, AutoEQ, device-inspector, Bluetooth, notification, and HUD resources. Do not repeat the earlier false conclusion that `System Audio`, `Single`, or `hud.muted` are missing.

## Defensive `Untitled` fallback

`SettingsManager.createUserPreset` retains a defensive fallback to `"Untitled"` when called with an empty name.

The shipping `EQPanelView` save flow trims the name, disables save for empty input, and guards empty submission before calling `createUserPreset`. The reviewed product UI therefore does not expose the defensive fallback. User-entered preset names remain verbatim by design.

If a future caller can reach `createUserPreset` with an empty name from user-facing UI, revisit this decision at that call site rather than making stored preset identity locale-dependent without a product requirement.

## Dependency and system boundaries

The approved scope is complete Simplified Chinese coverage for FineTune-owned UI. The in-app runtime selector does not change the process-wide macOS application language.

### Sparkle 2.8.1

FineTune uses `SPUStandardUpdaterController`.

Sparkle standard UI resolves strings from the Sparkle framework bundle. FineTune's `LocalizationContext` does not control that bundle lookup. Sparkle's standard update window therefore follows native bundle/application language selection and is not guaranteed to follow FineTune's in-app selector under a language mismatch.

Do not replace `SPUStandardUserDriver`, mutate `AppleLanguages`, swizzle bundles, or add another process-language forcing mechanism in this PR. A custom updater UI requires a separate product/security decision.

### KeyboardShortcuts 2.4.0

The package includes `zh-Hans` resources. Package-owned Recorder text resolves from the package resource bundle.

FineTune-owned Shortcuts labels and descriptions follow the FineTune selector. Recorder placeholders and dependency-owned conflict alerts are not guaranteed to follow FineTune's runtime override when native application language differs.

Do not fork or replace the dependency solely to force this behavior without separate approval.

### macOS-owned UI

FineTune ships localized privacy purpose strings and can localize its own custom panel messages. macOS owns privacy-prompt chrome and standard file-panel controls. Their language remains a native platform/application-language boundary.

## What remains unproven

Automated CI cannot substitute for local macOS runtime acceptance. Do not claim the following have been visually or physically verified until they are observed on the acceptance machine:

- every Settings tab in English, Simplified Chinese, and Auto
- Compact, Comfortable, and Spacious popup layout
- all Output/Input/edit/EQ/AutoEQ/device-detail states
- clipping, wrapping, truncation, visual balance, and translation quality
- live notification appearance and VoiceOver/help behavior
- Sparkle, KeyboardShortcuts, privacy prompts, and standard file-panel chrome under native/FineTune language mismatch
- permission denial and later grant/recovery behavior
- quiet-running app visibility across launch/termination and representative-PID changes
- routing and tap behavior across real output devices and app lifecycle transitions
- sleep/wake and application termination persistence behavior

The local macOS acceptance pass must cover the relevant runtime matrix before merge authorization.

## Final gates before merge authorization

1. Re-fetch the current PR #10 head and confirm exact-head CI is green.
2. Perform the macOS GUI smoke matrix in explicit English, explicit Simplified Chinese, and both Auto resolution directions.
3. Check Compact, Comfortable, and Spacious popup layouts for clipping, overlap, wrapping, and truncation.
4. Exercise representative Output/Input, edit, EQ, AutoEQ, permission, Bluetooth, device-detail, notification, help, and accessibility states.
5. Exercise app discovery, quiet-running visibility, Hide/Restore, representative-PID changes, routing, sleep/wake, and termination persistence on real macOS hardware.
6. Observe dependency/system-owned language behavior accurately and record it as a boundary without silently extending scope.
7. Recompare the final PR #10 branch with `main` for unrelated release, signing, appcast, dependency, or business-logic drift.
8. Keep PR #10 Draft and unmerged until explicit authorization.

## Sensitive files

Treat these as high risk:

- `FineTune/Audio/Engine/AudioEngine.swift`
- `FineTune/Audio/Engine/ProcessTapController.swift`
- `FineTune/Audio/EQ/BiquadProcessor.swift`
- `FineTune/Audio/Monitors/AudioProcessMonitor.swift`
- `FineTune/Settings/SettingsManager.swift`
- `FineTune/Localizable.xcstrings`
- `FineTune/Views/MenuBarPopupView.swift`
- `FineTune/Utilities/LocalizationContext.swift`
- `FineTune/Settings/Types/AppLanguage.swift`
- `.github/workflows/ci.yml`

For large or sensitive files, reconstruct from the exact current blob, build a detached candidate, compare the resulting Git diff, and only then advance the acceptance branch.

## Development rules

Before writing:

1. Re-fetch the branch/PR head.
2. Re-fetch every exact file being changed.
3. Verify the requested behavior and success criteria.
4. Check official framework or dependency source documentation when an assumption matters.

Before claiming completion:

1. Verify Build and Test from the final branch head.
2. Diagnose failures from exact logs or `.xcresult` evidence.
3. Review the final diff against `main`.
4. Separate automated facts from manual/runtime observations.
5. Update handoff evidence only when it adds substantive information. Do not create an endless documentation-head recursion merely to record the SHA of the previous documentation commit.
6. Do not merge PR #10 without explicit authorization.
