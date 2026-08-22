# UI Localization Task List

Status: Draft. Do not mark a task complete without running its stated verification.

## Foundation

- [ ] Task: Add stable app-language preference
  - Acceptance: `AppLanguage` supports `system`, `en`, and `zh-Hans`; `AppSettings` persists it; old settings without the field decode as Follow System.
  - Verify: focused Codable/settings tests plus existing settings fixture tests.
  - Files: `FineTune/Settings/SettingsManager.swift`, one focused type file under `FineTune/Settings/Types/`, tests.

- [ ] Task: Register Simplified Chinese as a project localization
  - Acceptance: Xcode project `knownRegions` contains `zh-Hans` while English remains the development region.
  - Verify: inspect `project.pbxproj`, build, and inspect the built app localization resources.
  - Files: `FineTune.xcodeproj/project.pbxproj`.

- [ ] Task: Add native localization catalog
  - Acceptance: `FineTune/Localizable.xcstrings` contains English source localization and Simplified Chinese localization and is included in the app target.
  - Verify: build and inspect catalog/resource inclusion in the built product.
  - Files: `FineTune/Localizable.xcstrings`.

- [ ] Task: Propagate selected locale to both SwiftUI roots
  - Acceptance: Settings and menu bar popup use the same observable selected locale and can change while the app is running.
  - Verify: focused locale test or manual smoke proof plus build.
  - Files: `FineTune/FineTuneApp.swift` and/or focused root-view files, localization helper if needed.

- [ ] Task: Add deferred localization resolver for non-view boundaries
  - Acceptance: a `LocalizedStringResource` can be resolved explicitly in English or Simplified Chinese without changing global process language.
  - Verify: unit tests for at least two locales and an interpolated string.
  - Files: one focused localization utility/type file, tests.

## Shared presentation boundaries

- [ ] Task: Make Settings reusable components preserve localizable resources
  - Acceptance: `SettingsRow` and `SettingsSection` no longer force static user-facing content through plain `String`; call sites remain readable.
  - Verify: build and representative English/Chinese render/resource tests.
  - Files: `SettingsRow.swift`, `SettingsSection.swift`, directly affected callers.

- [ ] Task: Make common label components localization-safe
  - Acceptance: shared first-party components such as `SectionHeader` and `AboutLinkChip` can receive localizable static labels without translating dynamic names.
  - Verify: build and source review of component APIs.
  - Files: affected files under `FineTune/Views/Components/` and `FineTune/Views/Settings/Components/`.

- [ ] Task: Separate localized display names from stable enum/action identifiers
  - Acceptance: appearance, popup size, hotkey step, icon style, shortcut action, and device-tier presentation can localize while raw/Codable keys remain unchanged.
  - Verify: existing Codable tests plus new localized-display tests.
  - Files: `SettingsUITypes.swift`, `ShortcutAction.swift`, related presentation types and tests.

## Settings UI

- [ ] Task: Add Language selector to General Settings
  - Acceptance: choices are Follow System, English, and 简体中文; selection persists and updates FineTune-owned UI live.
  - Verify: switch values in a running Settings window, reopen Settings, relaunch app, confirm persistence.
  - Files: `GeneralTab.swift`, localized resources, tests as appropriate.

- [ ] Task: Localize Settings root and General tab
  - Acceptance: tab/window/general/reset UI has complete English and Simplified Chinese resources including help/accessibility text.
  - Verify: visual review at 720 x 560 in both languages.
  - Files: `SettingsRootView.swift`, `GeneralTab.swift`, related Settings components/catalog.

- [ ] Task: Localize Audio Settings
  - Acceptance: every first-party label, description and picker option is localized; dynamic device names remain unchanged.
  - Verify: visual review in both languages and build.
  - Files: `AudioTab.swift`, `SystemSoundsDevicePicker.swift`, catalog.

- [ ] Task: Localize Shortcuts Settings
  - Acceptance: sections, action display names, descriptions, media-key/HUD text, help/accessibility text are localized; shortcut raw keys remain stable.
  - Verify: shortcut persistence tests and visual review.
  - Files: `ShortcutsTab.swift`, `ShortcutAction.swift`, related components/catalog/tests.

- [ ] Task: Localize Updates Settings and selected-locale date formatting
  - Acceptance: FineTune-owned update text is localized and relative date/status formatting follows selected app locale.
  - Verify: deterministic formatter/resource tests for `en` and `zh-Hans`.
  - Files: `UpdatesTab.swift`, localization helper/catalog/tests.

- [ ] Task: Localize About Settings
  - Acceptance: first-party About labels/actions are localized while `FineTune`, license identifier and copyright attribution remain correct.
  - Verify: visual review in both languages.
  - Files: `AboutTab.swift`, `AboutLinkChip.swift`, catalog.

## Menu bar and common rows

- [ ] Task: Localize menu bar popup shell
  - Acceptance: header, tabs/help, reorder mode, fallback device text, footer actions, app-section labels, empty states, ignored counts, help and accessibility text are localized.
  - Verify: both languages in normal/edit modes and Output/Input tabs.
  - Files: `MenuBarPopupView.swift`, catalog, focused helper only if needed.

- [ ] Task: Localize count/interpolated popup strings correctly
  - Acceptance: ignored-app counts use catalog interpolation/plural handling and do not concatenate English fragments.
  - Verify: resource tests for representative counts in both locales.
  - Files: popup/localization resources/tests.

- [ ] Task: Localize app-row controls
  - Acceptance: AppRow, InactiveAppRow, AppEditRow and shared row controls have localized first-party text; app names remain untouched.
  - Verify: source scan plus popup smoke review.
  - Files: affected files under `FineTune/Views/Rows/`, shared components/catalog.

- [ ] Task: Localize device-row and picker controls
  - Acceptance: DeviceRow, InputDeviceRow, DeviceEditRow, PairedDeviceRow, DevicePicker and shared picker controls are localized; device names remain untouched.
  - Verify: output/input/Bluetooth visual states in both languages.
  - Files: affected row/component files/catalog.

- [ ] Task: Localize permission banner
  - Acceptance: access-required text, system-settings guidance and actions are localized.
  - Verify: authorized/denied/not-yet-requested states reviewed.
  - Files: `PermissionBannerView.swift`, catalog.

## EQ, AutoEQ and device inspector

- [ ] Task: Localize EQ UI
  - Acceptance: preset controls, save/rename UI, help and accessibility labels are localized; user preset names and technical frequency labels remain unchanged.
  - Verify: save, rename, cancel and preset selection in both languages.
  - Files: `EQPanelView.swift`, EQ picker/components/catalog.

- [ ] Task: Localize built-in EQ presentation labels
  - Acceptance: first-party preset/category names are localized without changing stored EQ values or user preset names.
  - Verify: EQ matching/preset tests and UI review.
  - Files: EQ model/presentation files, catalog/tests.

- [ ] Task: Localize AutoEQ UI
  - Acceptance: empty/loading/status/search/favorites/import/error/correction/preamp text and accessibility labels are localized; profile/model/source names remain external/dynamic content.
  - Verify: no-selection, selected, loading, search, favorites, import success/failure states.
  - Files: `AutoEQSearchPanel.swift`, related AutoEQ picker/components/catalog.

- [ ] Task: Localize device inspector and detail UI
  - Acceptance: first-party row labels, volume-tier names, automatic-detection text, software-volume option, callouts and hog-mode sentences are localized; UIDs/PIDs/device names/units remain correct.
  - Verify: hardware/DDC/software cases, hog-mode text and error state in both languages.
  - Files: `DeviceDetailSheet.swift`, `DeviceInspectorInfo.swift`, inspector views/catalog/tests.

## AppKit, notifications and bundle metadata

- [ ] Task: Localize FineTune-owned AppKit strings
  - Acceptance: window title and AutoEQ file-panel custom message follow selected app language.
  - Verify: open Settings and file panel in both languages; separately record system-owned file-panel chrome language.
  - Files: relevant AppKit bridge/menu popup files, localization helper/catalog.

- [ ] Task: Localize FineTune-generated notifications and lower-layer user-facing errors
  - Acceptance: notification title/body and intentionally user-facing errors resolve through selected FineTune language before presentation.
  - Verify: focused unit tests plus manual/controlled notification check.
  - Files: notification/error producers, catalog/tests.

- [ ] Task: Localize privacy usage descriptions in the bundle
  - Acceptance: Simplified Chinese resources exist for audio capture, microphone and Bluetooth usage descriptions while English source values remain valid.
  - Verify: built app resource inspection and platform prompt test where practical.
  - Files: `FineTune/Info.plist`, localized InfoPlist resource under `FineTune/`.

## Completeness and dependency boundaries

- [ ] Task: Run final production string inventory
  - Acceptance: every remaining English string literal in shipping Swift code is classified; no unexplained first-party English-only user-facing literal remains.
  - Verify: documented scan results plus review of String Catalog extraction/build feedback.
  - Files: no behavior change required; add documentation/tests only if useful.

- [ ] Task: Verify built Simplified Chinese localization registration
  - Acceptance: `zh-Hans` is registered in the Xcode project and expected Chinese application and InfoPlist localization resources exist in the built app.
  - Verify: inspect project metadata and built bundle, not source files alone.
  - Files: documentation only unless a registration/resource inclusion defect is found.

- [ ] Task: Verify Sparkle 2.8.1 language behavior
  - Acceptance: standard updater language behavior is recorded for English/Chinese FineTune selection against relevant macOS app-language combinations.
  - Verify: actual updater-window test, not inference.
  - Files: documentation only unless a separately approved custom user driver is required.

- [ ] Task: Verify dependency/system-owned controls
  - Acceptance: `KeyboardShortcuts.Recorder`, macOS privacy prompts and standard `NSOpenPanel` chrome behavior are recorded when FineTune language differs from macOS application language.
  - Verify: actual UI observation in the relevant states.
  - Files: documentation only unless separately approved replacement UI is required.

- [ ] Task: Perform Chinese layout/adversarial review
  - Acceptance: no clipping, overlap, unintended truncation, unreadable line wrapping or English remnants in all supported FineTune-owned surfaces.
  - Verify: Settings all tabs plus popup Compact/Comfortable/Spacious, Output/Input, edit mode, EQ/AutoEQ/detail/error states.
  - Files: only corrective UI/localization changes found by review.

- [ ] Task: Run full regression suite and build
  - Acceptance: existing and new tests pass; Debug build succeeds; no relevant new warnings are unexplained.
  - Verify: canonical `xcodebuild test` followed by canonical `xcodebuild build` from `SPEC-ui-localization.md`.
  - Files: none unless a real failure requires a scoped fix.

- [ ] Task: Final five-axis code review and main comparison
  - Acceptance: correctness, readability, architecture, security and performance review has no unresolved Required/Critical findings; diff contains no release/signing/repository ownership drift.
  - Verify: compare feature branch to `main`, review tests/logs and document verification story.
  - Files: only scoped fixes from review.
