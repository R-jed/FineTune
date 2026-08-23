# UI Localization Implementation Plan

Status: Reviewed and implementation-ready as of 2026-08-23. Follow `SPEC-ui-localization.md` when any lower-level task wording is ambiguous.

## Goal

Deliver an in-app FineTune UI language preference with Follow System, English, and Simplified Chinese while preserving existing settings compatibility, native macOS per-app language behavior, regional formatting preferences, and all non-presentation behavior.

## Dependency Order

```text
foundation + language semantics
          |
          v
localizable component boundaries
          |
          +-------------------+
          |                   |
          v                   v
   Settings surfaces      popup/common rows
          |                   |
          +---------+---------+
                    |
                    v
          EQ / AutoEQ / device detail
                    |
                    v
   AppKit / notifications / InfoPlist catalog
                    |
                    v
      completeness + visual verification
                    |
                    v
       dependency/system boundary verdict
                    |
                    v
          final regression + review
```

The order is intentional. Shared presentation boundaries and language semantics must be correct before bulk translation.

## Phase 1: Localization Foundation

### Change

- Add `AppLanguage` with stable Codable raw values: `system`, `en`, `zh-Hans`.
- Add `language` to `AppSettings`, default `.system`.
- Decode with `decodeIfPresent` for old settings compatibility.
- Add `zh-Hans` to Xcode project `knownRegions`.
- Add `FineTune/Localizable.xcstrings`.
- Add `FineTune/InfoPlist.xcstrings` for localizable privacy purpose strings.
- Reuse existing application-target settings:
  - `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`
  - `STRING_CATALOG_GENERATE_SYMBOLS = YES`
  - `SWIFT_EMIT_LOC_STRINGS = YES`
- Add one focused localization-context type.

### Language semantics

Follow System:

- produce no FineTune SwiftUI locale override
- let native macOS application-language and bundle lookup continue normally
- do not substitute `.autoupdatingCurrent` as a language override

Explicit English or Simplified Chinese:

- apply a FineTune-owned runtime locale override to first-party SwiftUI roots
- construct the presentation locale from the selected language/script while retaining current user region preferences where supported
- use `Locale.Components` for the language/region composition
- provide a deferred `LocalizedStringResource` resolver for non-SwiftUI first-party strings

### Verification checkpoint

- old settings fixtures decode unchanged
- each language choice round-trips through persistence
- existing persisted/raw identifiers remain unchanged
- `.system` produces no app-defined SwiftUI language override
- English and `zh-Hans` produce the intended language/script
- explicit language selection retains current region behavior in focused tests
- project metadata contains `zh-Hans`
- String Catalog resources build successfully

## Phase 2: Repair Localizable Presentation Boundaries

### Change

Refactor static presentation APIs that currently collapse localizable text into plain `String`.

Priority candidates:

- `SettingsRow`
- `SettingsSection`
- `SectionHeader`
- `AboutLinkChip`
- Settings picker/segmented-control labels
- `ShortcutAction.displayName`
- `AppearancePreference.description`
- `MenuBarPopupSize.description`
- `VolumeHotkeyStep.description`
- menu bar icon style labels
- device volume-tier display names

Use `LocalizedStringResource` when text crosses layers or resolves later. Keep straightforward SwiftUI literals at readable call sites where automatic extraction is sufficient. Use generated String Catalog symbols where typed reuse materially improves safety.

### Verification checkpoint

- existing Codable tests still pass
- representative shared components resolve English and Chinese correctly
- no localization service logic is added to `MenuBarPopupView.swift`
- dynamic application/device/user/profile names still use plain dynamic strings

## Phase 3: Language Selector and Settings Localization

### Change

Add a Language row to General Settings near appearance/theme controls.

Choices:

- Follow System
- English
- 简体中文

Localize:

- Settings window title
- tab labels
- General and reset confirmation
- Audio
- Shortcuts
- Updates
- About
- helper cards/components
- help and accessibility strings

Update relative-date/status formatting to use the feature localization context while preserving user region conventions.

### Verification checkpoint

- explicit English <-> Chinese switches all FineTune-owned Settings text live
- Follow System restores native application-language behavior
- selection persists after closing/reopening Settings and relaunching FineTune
- no clipping at 720 x 560 in either explicit language
- changing UI language does not change stored regional preferences

## Phase 4: Menu Bar Popup and Common Rows

### Change

Localize FineTune-owned text in:

- `MenuBarPopupView`
- Output/Input tab/help text
- edit/reorder mode
- default-device fallbacks
- app section and empty states
- ignored-app count strings using catalog interpolation/plural support
- Settings/Donate/Quit and accessibility labels
- app/inactive/edit rows
- output/input/Bluetooth device rows
- device/app edit rows
- device picker/shared dropdown/radio/mute controls
- permission banner

Do not translate application names, device names, user presets, or external profile names.

### Verification checkpoint

- English and Chinese smoke test in Compact, Comfortable, and Spacious popup sizes
- Output and Input
- normal mode, device edit mode, app edit mode
- keyboard navigation remains correct
- help/accessibility strings change with explicit language
- representative ignored-app counts resolve correctly

## Phase 5: EQ, AutoEQ, and Device Inspector

### Change

Localize:

- EQ headings and controls
- built-in EQ preset/category presentation labels
- save/rename/cancel/help/accessibility text
- AutoEQ empty/loading/status/search/favorites/import/error/correction/preamp text
- device inspector labels
- device-detail volume-tier names
- automatic-detection text
- software-volume option and callouts
- hog-mode messages

Preserve external/dynamic content:

- user preset names
- AutoEQ profile/model names
- external measurement/source names
- numeric frequency labels
- standard technical units
- PID/UID/device names

### Verification checkpoint

- EQ save/rename/cancel/preset flows work in both languages
- AutoEQ no-selection, selected, loading, search, favorites, import success/failure states reviewed
- inspector/detail long Chinese text has no clipping or misleading wrapping
- existing EQ/AutoEQ/device behavior tests remain green

## Phase 6: AppKit, Notifications, Errors, and InfoPlist

### Change

Localize FineTune-owned non-SwiftUI presentation strings:

- Settings window-title bridge input
- `NSOpenPanel.message` for AutoEQ import
- FineTune-generated notification title/body
- intentionally user-facing lower-layer error/status strings
- any additional first-party AppKit menu/alert text found by source scan

Populate `InfoPlist.xcstrings` translations for:

- `NSAudioCaptureUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSBluetoothAlwaysUsageDescription`

Keep product name `FineTune` unchanged.

### Verification checkpoint

- explicit resolver produces correct English/Chinese output for AppKit/notification boundaries
- built app contains `InfoPlist.xcstrings` compiled resources and Chinese purpose strings
- AutoEQ custom file-panel message follows explicit FineTune UI language
- record the language used by system-owned file-panel controls
- privacy prompt behavior is observed where practical

## Phase 7: Completeness Guard

### Change

Run production-source inventory after String Catalog extraction/build.

Classify every remaining English literal in shipping Swift code as:

1. localized user-facing copy
2. stable internal identifier
3. SF Symbol/API/system key
4. log/debug/developer-only text
5. user/system/external dynamic content
6. test/preview-only text

Any unexplained first-party user-facing literal blocks merge.

### Verification checkpoint

- no unexplained English-only first-party user-facing literals remain
- all shipping keys used by the feature have English and Simplified Chinese values
- no relevant new localization warning remains unexplained
- `zh-Hans`, `Localizable.xcstrings`, and `InfoPlist.xcstrings` are present in the built application as expected

## Phase 8: Dependency and Platform Boundary Verification

### Sparkle 2.8.1

Sparkle already ships Simplified Chinese resources. Test the standard updater window under at least:

- native macOS app language English + FineTune Follow System
- native macOS app language Simplified Chinese + FineTune Follow System
- native macOS app language English + FineTune explicit Simplified Chinese
- native macOS app language Simplified Chinese + FineTune explicit English

Record whether Sparkle follows native application language or the FineTune runtime override.

If Sparkle does not follow the runtime override, document the limitation. Do not replace `SPUStandardUpdaterController` or implement a custom `SPUUserDriver` without separate approval.

### KeyboardShortcuts 2.4.0

The dependency already ships `zh-Hans` strings. Test Recorder UI and conflict warnings under the same native-app-language versus FineTune-runtime-override distinction.

Do not fork/replace the dependency solely to force runtime language behavior without approval.

### macOS-owned UI

Record behavior for:

- privacy prompt chrome
- standard `NSOpenPanel` controls

FineTune controls its purpose strings and custom panel message. macOS owns standard chrome language.

## Phase 9: Full Regression and Adversarial Review

### Automated verification

Run:

```bash
xcodebuild test \
  -project FineTune.xcodeproj \
  -scheme FineTune \
  -configuration Debug \
  -skip-testing:FineTuneUITests \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO \
  -resultBundlePath build/TestResults.xcresult
```

Then:

```bash
xcodebuild build \
  -project FineTune.xcodeproj \
  -scheme FineTune \
  -configuration Debug \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO
```

### Adversarial review

Compare feature branch against `main` and challenge:

- old settings fail to decode
- localization changes persistence/raw values
- Follow System accidentally overrides native per-app language
- explicit language selection changes region formatting unexpectedly
- one SwiftUI root remains on the old language
- source localization exists but built resources are missing
- custom components still erase localization intent through plain `String`
- lower-layer first-party strings stay English
- user/device/profile names are translated accidentally
- plural/interpolated grammar is hardcoded
- relative dates use wrong language or wrong region conventions
- help/accessibility text remains English
- Chinese layout clips or overlaps
- system/dependency-owned UI is incorrectly claimed as FineTune-controlled
- audio/routing/hotkey/EQ behavior changes despite presentation-only scope

## Merge Criteria

Merge only when:

- all Required/Critical findings are resolved
- full test suite passes
- Debug build passes
- `zh-Hans` is registered and shipped
- `Localizable.xcstrings` and `InfoPlist.xcstrings` build correctly
- English and Chinese FineTune-owned UI smoke review is complete
- final source inventory is clean
- dependency/system behavior is recorded from actual observation
- final diff has no unrelated release/signing/appcast/repository-ownership/audio-engine changes

## Commit Strategy

Keep changes reviewable and verify after each coherent increment.

Suggested sequence:

1. `feat: add localization foundation and language preference`
2. `refactor: preserve localizable presentation resources`
3. `feat: localize Settings and add language selector`
4. `feat: localize menu bar and common rows`
5. `feat: localize EQ AutoEQ and device inspector`
6. `feat: localize AppKit notifications and privacy strings`
7. `test: add localization and persistence regression coverage`
8. `docs: record localization verification and platform boundaries`

Split further by owning UI area if a commit becomes difficult to review.

## Implementation Sources

Use these as authority during implementation:

- https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog
- https://developer.apple.com/documentation/swiftui/preparing-views-for-localization
- https://developer.apple.com/documentation/foundation/localizedstringresource
- https://developer.apple.com/documentation/swift/string/init(localized:options:)
- https://developer.apple.com/documentation/foundation/locale/components
- https://developer.apple.com/documentation/xcode/supporting-multiple-languages-in-your-app
- https://developer.apple.com/localization/
- https://developer.apple.com/videos/play/wwdc2019/403/
- https://developer.apple.com/videos/play/wwdc2023/10155/
- https://developer.apple.com/videos/play/wwdc2025/225/
- https://sparkle-project.org/documentation/custom-user-interfaces/
- https://github.com/sparkle-project/Sparkle/releases/tag/2.8.1
- https://github.com/sindresorhus/KeyboardShortcuts

## Readiness Decision

The first implementation pass may begin. No unresolved architecture blocker remains for FineTune-owned localization.

Dependency/system-owned language behavior remains a verification checkpoint. Replacing those UI owners remains outside scope until separately approved.