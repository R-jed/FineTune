# UI Localization Task List

Status: Reviewed and implementation-ready as of 2026-08-23. Do not mark a task complete without running its stated verification.

## Foundation

- [ ] Task: Add stable app-language preference
  - Acceptance: `AppLanguage` supports `system`, `en`, and `zh-Hans`; `AppSettings` persists it; old settings without the field decode as Follow System.
  - Verify: focused Codable/settings tests plus existing settings fixture tests.
  - Files: `FineTune/Settings/SettingsManager.swift`, one focused type file under `FineTune/Settings/Types/`, tests.

- [ ] Task: Register Simplified Chinese as a project localization
  - Acceptance: Xcode project `knownRegions` contains `zh-Hans` while English remains the development region.
  - Verify: inspect `project.pbxproj`, build, and inspect built app localizations.
  - Files: `FineTune.xcodeproj/project.pbxproj`.

- [ ] Task: Add native String Catalog resources
  - Acceptance: `FineTune/Localizable.xcstrings` and `FineTune/InfoPlist.xcstrings` are included in the app target; English remains the source language and Simplified Chinese is complete.
  - Verify: build and inspect compiled app resources.
  - Files: both String Catalogs.

- [ ] Task: Preserve native behavior for Follow System
  - Acceptance: `.system` produces no FineTune-defined SwiftUI locale override and leaves native macOS application-language bundle selection intact.
  - Verify: focused test of localization-context output plus manual test with a macOS per-app language override.
  - Files: focused localization-context type, root integration, tests.

- [ ] Task: Add explicit English and Chinese runtime UI override
  - Acceptance: explicit English or Simplified Chinese creates a first-party presentation locale with the requested language/script while retaining the user's current region where supported.
  - Verify: unit tests for language/script and retained regional behavior using `Locale.Components`.
  - Files: localization-context type, tests.

- [ ] Task: Propagate explicit locale to both SwiftUI roots
  - Acceptance: Settings and menu bar popup share the same observable explicit override; Follow System injects no override.
  - Verify: focused locale test plus manual live-switch smoke test.
  - Files: `FineTune/FineTuneApp.swift` and/or focused root views.

- [ ] Task: Add deferred first-party localization resolver
  - Acceptance: `LocalizedStringResource` resolves correctly in English and Simplified Chinese for non-SwiftUI boundaries without mutating global process language.
  - Verify: unit tests for two languages, interpolation, and Follow System default-bundle behavior.
  - Files: focused localization helper/context, tests.

## Shared Presentation Boundaries

- [ ] Task: Make Settings components localization-safe
  - Acceptance: `SettingsRow` and `SettingsSection` no longer force static user-facing copy through plain `String`.
  - Verify: build and representative resource/render tests.
  - Files: `SettingsRow.swift`, `SettingsSection.swift`, directly affected callers.

- [ ] Task: Make common first-party label components localization-safe
  - Acceptance: `SectionHeader`, `AboutLinkChip`, and similar static-label components preserve localizable presentation types while dynamic names remain plain strings.
  - Verify: source review and build.
  - Files: affected shared components.

- [ ] Task: Separate localized display names from stable identifiers
  - Acceptance: appearance, popup size, hotkey step, icon style, shortcut action, and device-tier display names localize without changing raw/Codable keys.
  - Verify: existing Codable tests plus new localized-display tests.
  - Files: `SettingsUITypes.swift`, `ShortcutAction.swift`, related presentation types/tests.

## Settings UI

- [ ] Task: Add Language selector to General Settings
  - Acceptance: choices are Follow System, English, and 简体中文; explicit choices update FineTune-owned UI live; Follow System restores native application-language behavior.
  - Verify: switch all choices while Settings is open, reopen Settings, relaunch app, and test a macOS per-app language override.
  - Files: `GeneralTab.swift`, localized resources, tests as appropriate.

- [ ] Task: Localize Settings root and General tab
  - Acceptance: tab/window/general/reset UI has complete English and Simplified Chinese resources including help/accessibility text.
  - Verify: visual review at 720 x 560 in both explicit languages.
  - Files: `SettingsRootView.swift`, `GeneralTab.swift`, related components/catalog.

- [ ] Task: Localize Audio Settings
  - Acceptance: every first-party label, description, and picker option is localized; dynamic device names remain unchanged.
  - Verify: visual review in both languages and build.
  - Files: `AudioTab.swift`, `SystemSoundsDevicePicker.swift`, catalog.

- [ ] Task: Localize Shortcuts Settings
  - Acceptance: sections, action display names, descriptions, media-key/HUD text, help/accessibility text are localized; shortcut raw keys remain stable.
  - Verify: shortcut persistence tests and visual review.
  - Files: `ShortcutsTab.swift`, `ShortcutAction.swift`, related components/catalog/tests.

- [ ] Task: Localize Updates Settings with language-aware, region-preserving formatting
  - Acceptance: FineTune-owned update text uses selected UI language while relative dates retain user regional conventions.
  - Verify: deterministic formatter/resource tests for English and `zh-Hans` with at least one non-default region.
  - Files: `UpdatesTab.swift`, localization context/catalog/tests.

- [ ] Task: Localize About Settings
  - Acceptance: first-party About labels/actions are localized while `FineTune`, license identifier, and attribution remain correct.
  - Verify: visual review in both languages.
  - Files: `AboutTab.swift`, `AboutLinkChip.swift`, catalog.

## Menu Bar and Common Rows

- [ ] Task: Localize menu bar popup shell
  - Acceptance: header, tabs/help, reorder mode, fallback device text, footer actions, app-section labels, empty states, ignored counts, help, and accessibility text are localized.
  - Verify: both explicit languages in normal/edit modes and Output/Input tabs.
  - Files: `MenuBarPopupView.swift`, catalog, focused helper only if needed.

- [ ] Task: Localize count/interpolated popup strings correctly
  - Acceptance: ignored-app counts use String Catalog interpolation/plural handling and do not concatenate language fragments.
  - Verify: resource tests for representative counts.
  - Files: popup/catalog/tests.

- [ ] Task: Localize app-row controls
  - Acceptance: AppRow, InactiveAppRow, AppEditRow, and shared controls localize first-party copy; app names remain untouched.
  - Verify: source scan plus popup smoke review.
  - Files: affected files under `FineTune/Views/Rows/`, shared components/catalog.

- [ ] Task: Localize device-row and picker controls
  - Acceptance: DeviceRow, InputDeviceRow, DeviceEditRow, PairedDeviceRow, DevicePicker, and shared picker controls localize first-party copy; device names remain untouched.
  - Verify: output/input/Bluetooth states in both languages.
  - Files: affected row/component files/catalog.

- [ ] Task: Localize permission banner
  - Acceptance: access-required text, system-settings guidance, and actions are localized.
  - Verify: authorized, denied, and not-yet-requested states reviewed.
  - Files: `PermissionBannerView.swift`, catalog.

## EQ, AutoEQ, and Device Inspector

- [ ] Task: Localize EQ UI
  - Acceptance: preset controls, save/rename/cancel UI, help, and accessibility labels are localized; user preset names and technical frequency labels remain unchanged.
  - Verify: save, rename, cancel, and preset selection in both languages.
  - Files: `EQPanelView.swift`, EQ picker/components/catalog.

- [ ] Task: Localize built-in EQ presentation labels
  - Acceptance: first-party preset/category names localize without changing stored EQ values or user preset names.
  - Verify: EQ matching/preset tests and UI review.
  - Files: EQ model/presentation files, catalog/tests.

- [ ] Task: Localize AutoEQ UI
  - Acceptance: empty/loading/status/search/favorites/import/error/correction/preamp text and accessibility labels are localized; external profile/model/source names remain dynamic content.
  - Verify: no-selection, selected, loading, search, favorites, import success/failure states.
  - Files: `AutoEQSearchPanel.swift`, related components/catalog.

- [ ] Task: Localize device inspector and detail UI
  - Acceptance: first-party row labels, tier names, auto-detection text, software-volume option, callouts, and hog-mode sentences are localized; UIDs/PIDs/device names/units remain correct.
  - Verify: hardware/DDC/software cases, hog-mode text, and error state in both languages.
  - Files: `DeviceDetailSheet.swift`, `DeviceInspectorInfo.swift`, inspector views/catalog/tests.

## AppKit, Notifications, Errors, and Bundle Metadata

- [ ] Task: Localize FineTune-owned AppKit strings
  - Acceptance: window title and AutoEQ file-panel custom message follow explicit FineTune UI language; Follow System uses normal bundle behavior.
  - Verify: open Settings and file panel in all three language modes; separately record system-owned file-panel chrome language.
  - Files: relevant AppKit bridge/menu popup files, localization context/catalog.

- [ ] Task: Localize FineTune-generated notifications and lower-layer user-facing errors
  - Acceptance: notification title/body and intentionally user-facing lower-layer text resolve through the FineTune localization context before presentation.
  - Verify: focused unit tests plus controlled notification/error checks.
  - Files: notification/error producers, catalog/tests.

- [ ] Task: Localize privacy purpose strings with `InfoPlist.xcstrings`
  - Acceptance: English and Simplified Chinese values exist for audio capture, microphone, and Bluetooth usage descriptions.
  - Verify: build, inspect compiled app resources, and observe a platform prompt where practical.
  - Files: `FineTune/Info.plist`, `FineTune/InfoPlist.xcstrings`.

## Completeness and Dependency Boundaries

- [ ] Task: Run final production string inventory
  - Acceptance: every remaining English literal in shipping Swift code is classified; no unexplained first-party English-only user-facing literal remains.
  - Verify: documented scan results plus String Catalog build feedback.

- [ ] Task: Verify built Simplified Chinese localization registration
  - Acceptance: `zh-Hans` is registered and compiled application resources include expected `Localizable` and `InfoPlist` localizations.
  - Verify: inspect project metadata and built bundle.

- [ ] Task: Verify Sparkle 2.8.1 language behavior
  - Acceptance: updater behavior is recorded under native English/Chinese app language and opposite FineTune explicit runtime language combinations.
  - Verify: actual updater-window test.
  - Files: documentation only unless separately approved custom updater work is requested.

- [ ] Task: Verify KeyboardShortcuts 2.4.0 language behavior
  - Acceptance: Recorder UI and conflict warnings are observed under native app-language and FineTune runtime-override combinations; bundled `zh-Hans` support is confirmed in practice.
  - Verify: actual UI observation.
  - Files: documentation only unless a real integration defect is found.

- [ ] Task: Verify macOS-owned controls
  - Acceptance: privacy prompt chrome and standard `NSOpenPanel` control language are recorded when FineTune explicit language differs from native app language.
  - Verify: actual UI observation.

- [ ] Task: Perform Chinese layout/adversarial review
  - Acceptance: no clipping, overlap, unintended truncation, unreadable wrapping, misleading translation, or first-party English remnants remain.
  - Verify: Settings all tabs plus popup Compact/Comfortable/Spacious, Output/Input, edit mode, EQ/AutoEQ/detail/error states.

- [ ] Task: Run full regression suite and build
  - Acceptance: existing and new tests pass; Debug build succeeds; no relevant new warnings are unexplained.
  - Verify: canonical `xcodebuild test` followed by canonical `xcodebuild build` from `SPEC-ui-localization.md`.

- [ ] Task: Final main comparison and five-axis code review
  - Acceptance: correctness, readability, architecture, security, and performance review has no unresolved Required/Critical finding; no unrelated release/signing/appcast/repository/audio-engine drift exists.
  - Verify: compare feature branch against `main`, inspect tests/logs, and record verification evidence.