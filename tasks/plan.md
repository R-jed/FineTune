# UI Localization Implementation Plan

Status: Draft planning artifact. Implementation starts only after review of `SPEC-ui-localization.md`.

## Goal

Deliver an application-level language preference with English and Simplified Chinese localization while preserving existing settings compatibility and all non-presentation behavior.

## Dependency Order

```text
localization foundation
        |
        v
localizable component boundaries
        |
        +-------------------+
        |                   |
        v                   v
Settings surfaces       popup/common surfaces
        |                   |
        +---------+---------+
                  |
                  v
          EQ / AutoEQ / device detail
                  |
                  v
      AppKit / notifications / InfoPlist
                  |
                  v
        coverage + layout verification
                  |
                  v
          Sparkle boundary verdict
```

The order is intentional. Translating views before fixing the shared presentation boundaries would create rework and leave hidden English strings behind.

## Phase 1: Localization Foundation

### Change

- Add `AppLanguage` with stable Codable raw values: `system`, `en`, `zh-Hans`.
- Add `language` to `AppSettings`, default `.system`.
- Decode with `decodeIfPresent` for backward compatibility.
- Add a single locale-resolution API for the selected language.
- Add `FineTune/Localizable.xcstrings` with English source and Simplified Chinese target language.
- Wire the resolved locale into the Settings root and menu bar popup root.
- Add a small deferred-localization resolver for FineTune-owned non-SwiftUI boundaries only if required.

### Verification checkpoint

- Existing settings fixtures decode unchanged.
- New language setting round-trips through settings persistence.
- All pre-existing raw values remain byte-for-byte compatible.
- A minimal test view/resource resolves a known key differently under `en` and `zh-Hans`.
- Build succeeds before moving on.

## Phase 2: Repair Localizable Presentation Boundaries

### Change

Refactor reusable components and presentation properties that currently collapse static UI text into plain `String`.

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
- menu-bar icon style labels
- device volume-tier display names

Prefer `LocalizedStringResource` where a value is passed between layers or resolved later. Use SwiftUI-native localizable types directly when the text never leaves the view hierarchy.

### Verification checkpoint

- Codable/raw-value tests still pass without changes to stored identifiers.
- Reusable components render a known English and Chinese resource correctly.
- No new localization service logic is added to `MenuBarPopupView.swift`.

## Phase 3: Add the Language Selector and Localize Settings

### Change

Add a Language row to General Settings near appearance/theme controls.

Selector choices:

- Follow System
- English
- 简体中文

Localize:

- tab labels
- window title
- General tab and reset confirmation
- Audio tab
- Shortcuts tab
- Updates tab
- About tab
- Settings helper cards/components
- accessibility/help strings on these surfaces

Update locale-sensitive update status formatting so relative dates follow the selected locale.

### Verification checkpoint

- Switch language while Settings is open and confirm all FineTune-owned Settings text updates immediately.
- Close/reopen Settings and verify selected language persists.
- Re-launch app and verify persistence.
- Verify no Settings layout clipping at 720 x 560 in both languages.

## Phase 4: Localize Menu Bar Popup and Common Rows

### Change

Localize FineTune-owned text in:

- `MenuBarPopupView`
- output/input toggle help
- edit/reorder mode
- default-device fallbacks
- app section and empty states
- ignored-app count strings using catalog interpolation/plural support
- donation/quit/settings actions and accessibility labels
- app rows and inactive rows
- device rows and input rows
- paired Bluetooth rows
- device/app edit rows
- device picker and shared dropdown/radio/mute components
- permission banner

Do not translate application names, device names, user preset names, or profile names.

### Verification checkpoint

- English and Chinese popup smoke test in Compact, Comfortable, and Spacious modes.
- Normal mode, device edit mode, app edit mode, Output and Input tabs.
- Keyboard navigation still works and user-visible help/accessibility text changes language.
- Ignored-app count strings render correctly for representative counts.

## Phase 5: Localize EQ, AutoEQ, and Device Inspector

### Change

Localize:

- EQ panel headings, picker labels, save/rename fields, help, and accessibility text
- built-in EQ preset/category presentation labels where they are first-party display text
- AutoEQ status, search, favorites, loading, import, errors, correction/preamp controls, and accessibility text
- device inspector row labels
- device detail volume-tier labels, automatic-detection text, software-volume option, callouts, and hog-mode messages

Preserve as raw/dynamic content:

- AutoEQ model/profile names
- measurement/source names when sourced externally
- user EQ preset names
- numeric frequencies and standard technical units
- PIDs, UIDs, device names

### Verification checkpoint

- Test EQ save and rename in both languages.
- Test AutoEQ no-selection, selected, loading, search, favorites, import success, and import failure states.
- Verify device inspector and detail layout for long Chinese callout text.
- Existing EQ/AutoEQ/device behavior tests remain green.

## Phase 6: Localize Non-SwiftUI and System-Bundle Text

### Change

Localize FineTune-owned strings that resolve outside normal SwiftUI `Text` handling:

- `WindowTitleBridge` input
- `NSOpenPanel.message` for AutoEQ import
- FineTune-generated user notifications
- user-facing error strings produced below the view layer
- any AppKit alert/menu text discovered by the final source scan

Add Simplified Chinese InfoPlist localization for:

- `NSAudioCaptureUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSBluetoothAlwaysUsageDescription`

Keep the product name `FineTune` unchanged.

### Verification checkpoint

- Explicit locale resolver produces correct English/Chinese strings for AppKit boundaries.
- Bundle contains the expected Simplified Chinese InfoPlist localization.
- Trigger or inspect FineTune notification content in both languages.
- Trigger AutoEQ file picker from each language and verify its custom message.

## Phase 7: Localization Completeness Guard

### Change

Run a production-source audit after String Catalog extraction/build.

Classify every remaining English string literal in production Swift as one of:

1. user-facing and localized
2. stable internal identifier
3. SF Symbol/API/system key
4. log/debug/developer-only text
5. user/system-provided dynamic content
6. test/preview-only text

Any unexplained first-party user-facing literal blocks merge.

Add tests that exercise a representative set of resources from every major UI area in English and Simplified Chinese. Avoid a brittle test that merely duplicates the entire catalog in code.

### Verification checkpoint

- No unexplained English-only first-party user-facing literals remain.
- String Catalog has translations for all shipping keys used by the feature.
- Build produces no new localization warnings that are left unexplained.

## Phase 8: Dependency and Platform Boundary Verification

### Sparkle 2.8.1

Test the standard updater window under these combinations:

- macOS/app language English, FineTune selector English
- macOS/app language English, FineTune selector Simplified Chinese
- macOS/app language Simplified Chinese, FineTune selector Simplified Chinese

Record whether Sparkle follows FineTune's selector or macOS application language.

If Sparkle cannot follow the in-app selector, stop at the documented boundary and request explicit approval before replacing the standard `SPUStandardUpdaterController` user driver. Do not expand update-system scope automatically.

### macOS privacy prompts

Verify the localized privacy strings are present in the built application bundle. The system owns language selection for its permission UI, so document the observed behavior accurately.

## Phase 9: Full Regression and Review

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

### Manual/adversarial review

Compare against `main` and challenge these failure modes:

- language change accidentally modifies stored settings identifiers
- old settings file fails to decode
- one of the two SwiftUI roots remains on the old language
- custom component still treats localized resource as plain nonlocalizable String
- English appears in Chinese mode because it comes from a lower layer
- Chinese is applied to user/device/profile names that must remain untouched
- interpolated count grammar is hardcoded
- update timestamps use the wrong locale
- tooltip/accessibility text remains English
- fixed layouts clip or overlap
- audio/routing/hotkey behavior changes despite presentation-only scope

### Merge criteria

Merge only when:

- all Required review findings are resolved
- tests pass
- build passes
- both languages have completed UI smoke review
- final diff contains no unrelated release/signing/repository-link changes
- Sparkle/system-owned localization limitations are documented from actual verification

## Change Sizing and Commit Strategy

Keep feature work reviewable. Suggested commit sequence:

1. `feat: add app language preference and locale foundation`
2. `refactor: preserve localizable text through UI components`
3. `feat: localize Settings and add language selector`
4. `feat: localize menu bar and row controls`
5. `feat: localize EQ AutoEQ and device inspector`
6. `feat: localize AppKit notifications and privacy strings`
7. `test: add localization coverage and persistence regression tests`
8. `docs: record localization verification and dependency boundaries`

If any commit grows too broad, split by owning UI area. Do not combine unrelated repository ownership or release migration with this feature.

## Official Implementation Sources

Use these as the authority during implementation:

- https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog
- https://developer.apple.com/documentation/xcode/preparing-your-apps-text-for-translation
- https://developer.apple.com/documentation/swiftui/environmentvalues/locale
- https://developer.apple.com/documentation/foundation/localizedstringresource
- https://developer.apple.com/documentation/foundation/localizedstringresource/locale
- https://developer.apple.com/documentation/xcode/supporting-multiple-languages-in-your-app
- https://developer.apple.com/localization/
- https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html
