# UI Localization Task List

Status: Updated from verified repository state on 2026-08-23. A checked item means its stated automated/source verification has been demonstrated. Manual GUI items remain open until observed in a macOS UI runtime.

## Foundation

- [x] Stable `AppLanguage` persistence with raw values `system`, `en`, and `zh-Hans`.
- [x] Backward-compatible decoding of older settings without a language field.
- [x] Simplified Chinese project localization registration.
- [x] `FineTune/Localizable.xcstrings` and `FineTune/InfoPlist.xcstrings` added and built.
- [x] Central `LocalizationContext` implemented.
- [x] Explicit language presentation preserves current region behavior in focused tests.
- [x] Auto semantics implemented and tested.
  - Chinese first preferred language -> `zh-Hans`.
  - Every other first preferred language -> `en`.
  - Empty/unusable list -> `en`.
  - Only the first preferred language controls the result.
- [x] Settings and menu-bar roots use the shared resolved FineTune locale.
- [x] Deferred `LocalizedStringResource` resolution is used for first-party non-SwiftUI String boundaries.

## Shared presentation boundaries

- [x] Settings shared components preserve localizable presentation types.
- [x] Common first-party label components preserve localization intent.
- [x] Localized display values are separated from stable raw/Codable identifiers.
- [x] Dynamic app/device/profile/user names remain outside localization lookup.

## Settings

- [x] General Settings exposes `Auto`, `English`, and `简体中文`.
- [x] Settings root and General first-party text localized.
- [x] Audio Settings first-party text localized.
- [x] Shortcuts Settings first-party labels/descriptions localized.
- [x] Updates Settings first-party text and feature-aware formatting localized.
- [x] About Settings first-party text localized.

## Menu bar and common rows

- [x] Menu bar popup shell first-party text localized.
- [x] Count/interpolated popup presentation covered by localized resources/tests.
- [x] App-row first-party controls localized.
- [x] Device-row and picker first-party controls localized.
- [x] Permission presentation resources localized.
- [x] Shared help/accessibility resources from the Phase 7 audit localized.

## EQ, AutoEQ, and device presentation

- [x] EQ first-party UI localized.
- [x] Built-in EQ preset/category display labels localized without changing stored model values.
- [x] AutoEQ first-party UI localized while external profile/model/source names remain verbatim.
- [x] Device inspector/detail first-party presentation localized while technical values remain stable.
- [x] AutoEQ disabled-state suffix localized without localizing the dynamic profile name.

## Detached roots and HUD

- [x] Shared popover hosting propagates FineTune locale.
- [x] Tahoe HUD root propagates FineTune locale.
- [x] Classic HUD root propagates FineTune locale.
- [x] Per-app HUD roots propagate FineTune locale.
- [x] HUD static copy and accessibility presentation centralized and tested.

## AppKit, notifications, errors, and privacy metadata

- [x] FineTune-owned AppKit String presentation localized.
- [x] Bluetooth connection errors converted to typed state and localized at presentation.
- [x] FineTune reconnect/disconnect/default-device notification presentation implemented and tested.
- [x] Production `AudioEngine` notification methods connected to `DeviceNotificationPresentation`.
- [x] Nil disconnect fallback and nil default-output fallback localized semantically.
- [x] Dynamic device names remain verbatim in notification tests.
- [x] Privacy purpose strings have English and Simplified Chinese resources.

## Catalog and regression protection

- [x] Phase 7 catalog completeness regression tests added for known audited resources.
- [x] Simplified Chinese presentation regression tests added.
- [x] Generated String Catalog collisions for ` (off)` and `Volume boost:` fixed without disabling generated symbols globally.
- [x] Typed localization boundary retained after CI #79 failure analysis.
- [x] `notification.noFallbackDevice` Chinese resource verified.
- [x] `notification.defaultOutputFallback` Chinese resource verified.

## Build and source review

- [x] CI #81 passed after localization test-boundary repair.
- [x] CI #82 passed on the previous handoff head.
- [x] CI #83 passed after production AudioEngine notification integration.
  - Run `32638398426`.
  - Job `97191501640`.
- [x] AudioEngine candidate diff reviewed before branch advancement.
- [x] AudioEngine production diff limited to notification presentation integration.
- [x] Feature branch compared with `main`; no observed dependency upgrade, release, signing, or appcast drift.
- [x] Adversarial spot checks found presentation/localization changes rather than unrelated business-logic changes.
- [ ] Fresh CI on the final documentation-synchronized branch head.

## Dependency and system boundaries

- [x] Sparkle 2.8.1 source behavior reviewed.
  - Simplified Chinese resources exist.
  - Standard UI resolves from the Sparkle framework bundle.
  - FineTune runtime locale does not guarantee control of Sparkle standard-window language.
  - Custom Sparkle user driver remains outside scope.
- [x] KeyboardShortcuts 2.4.0 source behavior reviewed.
  - `zh-Hans` resources exist.
  - package-owned Recorder text uses the package resource bundle.
  - FineTune runtime locale does not guarantee control of package-owned Recorder/conflict-alert language.
  - dependency replacement solely for this purpose remains outside scope.
- [x] macOS-owned surface boundary classified.
  - FineTune owns purpose-string values and custom messages.
  - macOS owns privacy-prompt and standard-panel chrome language.
- [ ] Observe Sparkle standard updater in a live mismatched native/FineTune language matrix.
- [ ] Observe KeyboardShortcuts Recorder/conflict alerts in the live matrix.
- [ ] Observe privacy-prompt and standard-panel chrome where practical.

## Manual macOS GUI verification

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
- [ ] EQ representative flows.
- [ ] AutoEQ no-selection, selected, loading, search, favorites, import success, and import failure states.
- [ ] Permission presentation.
- [ ] Device inspector/detail states.
- [ ] FineTune notification display.
- [ ] Help/accessibility presentation.
- [ ] Review clipping, overlap, wrapping, truncation, and translation quality.

## Final merge gate

- [ ] Final branch head has green Build and Test.
- [ ] Manual macOS GUI review evidence is recorded when a runtime is available.
- [ ] Dependency/system observations are recorded accurately.
- [ ] Final `main` comparison is re-run immediately before merge review.
- [ ] `HANDOFF.md` reflects the final head and verification truth.
- [ ] PR #5 remains unmerged until explicit authorization.
