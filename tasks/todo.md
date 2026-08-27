# UI Localization Task List

Status: Updated from verified repository state on 2026-08-24. Checked source/automated items have evidence. Manual macOS GUI items remain open until observed in a real UI runtime.

## Foundation and architecture

- [x] Stable `AppLanguage` persistence with raw values `system`, `en`, and `zh-Hans`.
- [x] Backward-compatible decoding of older settings without a language field.
- [x] Simplified Chinese project localization registration.
- [x] `FineTune/Localizable.xcstrings` and `FineTune/InfoPlist.xcstrings` added and built.
- [x] Central `LocalizationContext` implemented.
- [x] User region preserved for regional formatting in focused tests.
- [x] Auto semantics implemented and tested.
  - Chinese first preferred language -> `zh-Hans`.
  - Every other first preferred language -> `en`.
  - Empty/unusable list -> `en`.
  - Only the first preferred language controls the result.
- [x] Settings and menu-bar roots use the shared resolved FineTune locale.
- [x] Detached popover and HUD roots receive the selected FineTune locale.
- [x] `LocalizedStringResource` is retained through first-party presentation boundaries and resolved only at final String-only boundaries.
- [x] Dynamic app/device/profile/user identity values remain outside localization lookup.

## First-party UI coverage

- [x] General Settings exposes `Auto`, `English`, and `简体中文`.
- [x] Settings tabs and shared Settings controls localized.
- [x] Menu-bar popup shell and common row controls localized.
- [x] Permission presentation localized.
- [x] EQ built-in presentation localized without changing stored preset identity.
- [x] AutoEQ first-party UI localized while external profile/model/source names remain verbatim.
- [x] Device inspector/detail presentation localized while technical values remain stable.
- [x] Bluetooth connection failures use typed state and localized presentation.
- [x] FineTune reconnect/disconnect/default-device notifications use localized presentation.
- [x] Missing disconnect/default device fallback names localize semantically.
- [x] FineTune-owned AppKit messages localize at the String boundary.
- [x] Privacy purpose strings have English and Simplified Chinese resources.
- [x] HUD static copy and accessibility presentation centralized and tested.
- [x] Shared help and accessibility copy from the source audit localized.

## Final source-review fixes

- [x] Device-icon category headers localize.
- [x] Device-icon search accepts representative Simplified Chinese category queries such as `耳机`, `麦克风`, and `显示器`.
- [x] Device-icon accessibility descriptors use localized category presentation while SF Symbol identifiers remain verbatim.
- [x] CI #85 compile regression from the wrong `String(localized:locale:)` overload diagnosed from exact logs.
- [x] Device-icon resource resolution repaired without adding a generic dynamic-string localization API.
- [x] Device-icon tests use `LocalizationContext` as the typed localization boundary.
- [x] AutoEQ catalog failure no longer renders the fetcher's English runtime error string verbatim.
- [x] AutoEQ catalog failure reuses existing localized `Failed to load` copy; detailed fetch diagnostics remain internal/logged.
- [x] Defensive `SettingsManager.createUserPreset` `Untitled` fallback reviewed. Shipping `EQPanelView` prevents empty names before this call, so the fallback is not exposed through the reviewed product UI.

## Catalog and regression protection

- [x] Phase 7 catalog completeness tests cover known audited resources.
- [x] Simplified Chinese presentation regression tests exist.
- [x] Generated String Catalog collisions for ` (off)` and `Volume boost:` fixed without disabling generated symbols globally.
- [x] `notification.noFallbackDevice` Chinese resource verified.
- [x] `notification.defaultOutputFallback` Chinese resource verified.
- [x] Device-picker, mode-toggle, EQ, AutoEQ, device-inspector, Bluetooth, notification, and HUD resources rechecked in the full catalog blob.

## Build and source review

- [x] CI #81 passed after localization test-boundary repair.
- [x] CI #82 passed on the earlier handoff state.
- [x] CI #83 passed after production AudioEngine notification integration.
- [x] CI #84 passed on the documentation-synchronized state.
- [x] CI #85 failure root cause identified and repaired.
- [x] CI #87 passed on verified production-code head `ad4e09077e708de0989b4e5ceb9bab5d8e22c03e`.
  - Run `32651747504`.
  - Job `97224371006`.
  - Build, Test, test-result upload, and complete job all succeeded.
- [x] AudioEngine candidate diff reviewed before branch advancement.
- [x] AudioEngine production diff limited to notification presentation integration.
- [x] High-risk unchanged presentation files under Views, Settings, Utilities, Coordination, and menu-bar support were reviewed for user-facing localization boundaries.
- [x] Existing false-negative catalog searches caused by a truncated API response were corrected by checking the full catalog blob.
- [x] `HANDOFF.md` refreshed with the verified code baseline and final source-review findings.

## Dependency and system boundaries

- [x] Sparkle 2.8.1 source behavior reviewed.
  - Simplified Chinese resources exist.
  - Standard UI resolves from the Sparkle framework bundle.
  - FineTune runtime locale does not guarantee control of Sparkle standard-window language.
  - Custom Sparkle user driver remains outside scope.
- [x] KeyboardShortcuts 2.4.0 source behavior reviewed.
  - `zh-Hans` resources exist.
  - Package-owned Recorder text uses the package resource bundle.
  - FineTune runtime locale does not guarantee control of package-owned Recorder/conflict-alert language.
  - Dependency replacement solely for this purpose remains outside scope.
- [x] macOS-owned surface boundary classified.
  - FineTune owns purpose-string values and custom messages.
  - macOS owns privacy-prompt and standard-panel chrome language.
- [ ] Observe Sparkle standard updater in a live mismatched native/FineTune language matrix.
- [ ] Observe KeyboardShortcuts Recorder/conflict alerts in the live matrix.
- [ ] Observe privacy-prompt and standard-panel chrome where practical.

## Manual macOS GUI verification for the local agent

- [ ] Explicit English Settings review at target size.
- [ ] Explicit Simplified Chinese Settings review at target size.
- [ ] Auto with Chinese first preferred language.
- [ ] Auto with non-Chinese first preferred language.
- [ ] Popup Compact layout.
- [ ] Popup Comfortable layout.
- [ ] Popup Spacious layout.
- [ ] Output and Input presentation.
- [ ] Device edit and app edit states.
- [ ] App/device/Bluetooth rows.
- [ ] Device-icon picker category headers, Chinese search, help, and VoiceOver labels.
- [ ] EQ representative flows.
- [ ] AutoEQ no-selection, selected, loading, search, favorites, import success, import failure, and catalog failure states.
- [ ] Permission presentation.
- [ ] Device inspector/detail states.
- [ ] FineTune notification display.
- [ ] Help/accessibility presentation.
- [ ] Review clipping, overlap, wrapping, truncation, visual balance, and Chinese translation quality.

## Final merge gate

- [ ] Re-fetch the actual final branch head immediately before merge review and confirm Build and Test are green.
- [ ] Manual macOS GUI review evidence is recorded.
- [ ] Dependency/system observations are recorded accurately.
- [ ] Final `main` comparison is re-run immediately before merge review.
- [ ] No unrelated release, signing, appcast, dependency, or business-logic drift is present.
- [ ] PR #5 remains unmerged until explicit authorization is given.
