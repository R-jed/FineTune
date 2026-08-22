# Spec: Application UI Localization

Status: Draft for human review. Planning only. No localization feature code has been implemented on this branch yet.

## Objective

Add first-class UI language selection to FineTune and ship a complete Simplified Chinese localization for FineTune-owned user interface surfaces while preserving the existing English experience and all persisted settings compatibility.

The language selector will support:

- Follow System
- English (`en`)
- 简体中文 (`zh-Hans`)

New and existing installations default to Follow System unless the user explicitly chooses a language.

The selected language should apply immediately to FineTune-owned UI without requiring an app relaunch.

## Current-State Audit

### Confirmed architecture

- `FineTuneApp` creates the production `SettingsManager` once and the Settings scene and menu bar popup share it through the app graph.
- `AppSettings` is `Codable` and already uses `decodeIfPresent` defaults for backward compatibility.
- The Settings window is a SwiftUI `TabView` with General, Audio, Shortcuts, Updates, and About tabs.
- The menu bar popup is another independent SwiftUI root.
- The project uses Xcode file-system-synchronized groups for `FineTune/`, so application resources added under that directory are picked up by the target without hand-maintaining normal PBX file references.
- `Info.plist` contains English privacy usage descriptions for audio capture, microphone, and Bluetooth.
- Sparkle 2.8.1 owns its standard updater window through `SPUStandardUpdaterController`.

### Confirmed localization debt

The application UI is currently effectively English-only. A Chinese README exists, but it does not localize the application.

User-visible text is spread across:

- Settings root, tabs, reusable Settings components, dialogs, and window title
- Menu bar popup headers, footer, edit mode, empty states, help text, and accessibility labels
- App and device rows
- Device inspector and device detail controls
- EQ and user-preset UI
- AutoEQ browse/search/status/import UI
- Permission banners
- Bluetooth connection states and errors
- AppKit file panels
- FineTune-generated notifications and user-facing errors
- Update status text owned by FineTune

Several reusable APIs currently erase localization information by converting display text to plain `String` before rendering. `SettingsRow` and `SettingsSection` are confirmed examples.

Several settings/command enums also mix stable internal values with English presentation text. Examples include appearance, popup size, volume hotkey step, menu bar icon style, and shortcut action display names. Their persistence identifiers must remain stable.

### Platform/dependency boundaries

FineTune can control the locale of its own SwiftUI hierarchy and can explicitly resolve localized resources for its own AppKit/string surfaces.

Two surfaces are not fully controlled by FineTune's SwiftUI locale override:

1. macOS-owned privacy permission dialogs. Their usage-description strings can and must be localized in the application bundle, but the system chooses which localization to present.
2. Sparkle's standard updater UI. Sparkle ships its own localizations and the framework historically delegates language choice to macOS. A SwiftUI environment locale override does not prove that the standard updater window will switch with FineTune's in-app selector.

The implementation must verify Sparkle 2.8.1 behavior. If the standard updater cannot follow the selected in-app language, do not claim that dependency-owned updater UI switches dynamically. A custom Sparkle user driver is a separate scope decision because it materially increases maintenance and update-security surface area.

## Technical Direction

### Native localization resources

Use Apple's String Catalog system as the source of truth for FineTune-owned UI text.

Primary resource:

- `FineTune/Localizable.xcstrings`

Languages:

- English as development/source language
- Simplified Chinese (`zh-Hans`)

For localized `Info.plist` privacy strings, use a supported localized InfoPlist resource under the application target so macOS can select the correct usage descriptions.

Do not create a custom dictionary of English-to-Chinese strings and do not scatter language conditionals through views.

### App language model

Add a stable Codable `AppLanguage` preference with internal raw values that do not depend on display text:

- `system`
- `en`
- `zh-Hans`

Add it to `AppSettings` with a default of `.system` and decode it with `decodeIfPresent` so older `settings.json` files continue to load without migration failure.

The display names for language choices are presentation values. They must not be the persistence identifiers.

### SwiftUI locale propagation

Resolve the selected `AppLanguage` to a Swift `Locale`:

- system -> `.autoupdatingCurrent`
- en -> `Locale(identifier: "en")`
- zh-Hans -> `Locale(identifier: "zh-Hans")`

Apply the locale to both user-interface roots that need to update live:

- Settings hierarchy
- menu bar popup hierarchy

The selected value must be observable through the existing `SettingsManager` graph so changing the Picker immediately re-renders both roots when they are active.

### Deferred localization for non-SwiftUI boundaries

Use `LocalizedStringResource` for reusable presentation values and strings that must be resolved later. This is especially important for:

- enum display names
- custom components that currently accept `String`
- accessibility/help text that passes through custom APIs
- AppKit window/file-panel strings
- FineTune-generated notification strings
- formatted status/error strings

For an explicit in-app language override, resolve deferred resources against the selected locale at the final `String` boundary. Avoid assuming that `String(localized: ..., locale:)` by itself changes the language used for lookup. Apple's documentation distinguishes interpolation locale from resource lookup and exposes `LocalizedStringResource.locale` specifically for deferred localization in another locale.

### Reusable component boundaries

Refactor reusable UI components that represent static user-facing text to preserve localizable types instead of collapsing them into `String` too early.

Confirmed candidates include:

- `SettingsRow`
- `SettingsSection`
- `SectionHeader`
- `AboutLinkChip`
- presentation labels in picker/segmented-control components

Use plain `String` only for genuinely dynamic/user/system-provided content such as:

- application names
- audio-device names
- user-created EQ preset names
- AutoEQ profile/model names
- UIDs and bundle identifiers
- version/build values
- error payloads that have already been intentionally localized at their source

### Stable identifiers

Do not translate or change:

- Codable/raw persistence values
- shortcut action keys
- bundle identifiers
- URL scheme values
- device UIDs
- stored application identifiers
- SF Symbol names
- Sparkle signing/update identifiers

Presentation strings may be localized independently of these values.

### Interpolation, plurals, dates, and numbers

Use String Catalog interpolation and plural variants for count-bearing text such as ignored-app counts.

Locale-sensitive date/relative-date/number formatting must follow the selected app locale for FineTune-owned UI. `UpdatesTab` currently uses `RelativeDateTimeFormatter` without an explicit selected locale and must be corrected.

Technical units that are standard symbols, such as `kHz`, `dB`, `PID`, and version numbers, should remain technically correct while their surrounding labels and sentences are localized.

## Chinese Language Quality

The Chinese UI should read as native macOS product text, not word-for-word translation.

Terminology should remain consistent across all surfaces. Initial terminology direction:

- Settings -> 设置
- General -> 通用
- Audio -> 音频
- Shortcuts -> 快捷键
- Updates -> 更新
- About -> 关于
- Output Device -> 输出设备
- Input Device -> 输入设备
- Volume -> 音量
- Mute -> 静音
- Preset -> 预设
- Equalizer / EQ -> 均衡器 / EQ, depending on available space and surrounding context
- Follow System / System Default -> 跟随系统 / 系统默认, chosen according to control context
- AutoEQ remains `AutoEQ` as the product/technology name
- FineTune remains `FineTune`

The translation pass must review context rather than applying one global replacement to every English word.

## Commands

Canonical build command:

```bash
xcodebuild build \
  -project FineTune.xcodeproj \
  -scheme FineTune \
  -configuration Debug \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO
```

Canonical test command:

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

## Project Structure for This Feature

Expected additions/changes are intentionally localized to the existing ownership boundaries:

```text
FineTune/
  Localizable.xcstrings             # FineTune-owned UI strings
  zh-Hans.lproj/                    # Info.plist localization resource if required
  Settings/
    SettingsManager.swift           # persisted AppLanguage field
    Types/                           # AppLanguage and localized presentation resources
  Views/
    Settings/                       # language selector + Settings localization
    Components/                     # reusable localizable component boundaries
    Rows/                           # app/device/inspector localization
    Sheets/                         # sheet/detail localization
    EQPanelView.swift               # EQ localization
    MenuBarPopupView.swift          # popup localization only, no new localization subsystem
  Utilities/                        # centralized non-view localization helper only if required
FineTuneTests/
  ...                               # persistence, locale, resource and regression tests
```

Do not turn `MenuBarPopupView.swift` into a localization service. The file is already large. Shared locale resolution belongs in Settings/Utilities or another focused type.

## Testing Strategy

### Unit tests

Add focused tests for:

- `AppLanguage` raw values and locale resolution
- decoding an older settings payload that lacks the new language field
- encoding/decoding each language choice
- existing settings persistence identifiers remaining unchanged
- localized presentation resources resolving in English and Simplified Chinese for representative keys
- plural/interpolated ignored-app count strings
- locale-sensitive update timestamp/status formatting

### Existing regression tests

Run the existing full FineTune test suite. Localization must not alter audio, routing, hotkey, media-key, EQ, DDC, settings migration, or device behavior.

### UI/localization verification

Verify at minimum in both English and Simplified Chinese:

- Settings window: every tab
- menu bar popup: Output/Input tabs, normal mode and edit mode
- Compact, Comfortable, and Spacious popup sizes
- app rows and device rows
- EQ panel and user preset save/rename flow
- AutoEQ search, favorites, import, loading, and failure states
- permission banner
- device detail/inspector UI
- Bluetooth connection states
- empty/ignored-app states
- update settings/status
- About tab
- file import panel message
- FineTune-generated notification content

Check for clipping, truncation, overlap, broken line wrapping, and English leftovers.

### Dependency/system verification

Explicitly verify:

- Sparkle 2.8.1 update window language when FineTune's in-app language differs from macOS application language
- macOS privacy prompt behavior with localized InfoPlist resources

Record these results. Do not infer behavior from the main SwiftUI locale.

## Boundaries

### Always

- Preserve GPL v3 and upstream copyright notices.
- Keep persistence identifiers stable.
- Use native Apple localization resources/APIs.
- Keep English fully functional as the source language.
- Translate accessibility labels, help text, errors, empty states, and notifications, not only visible primary labels.
- Run full tests and build before merge.
- Perform a manual English-versus-Chinese UI review before merge.

### Ask before expanding scope

- Replacing Sparkle's standard updater user driver with a custom updater UI.
- Changing update/signing/appcast behavior.
- Renaming the FineTune product.
- Adding languages beyond English and Simplified Chinese.
- Changing existing persistence/raw values.
- Changing the app's release/versioning scheme.

### Never

- Set undocumented `AppleLanguages` defaults or use bundle-swizzling hacks to force language changes.
- Store translated display names as persistence keys.
- Translate user-provided/system-provided names.
- Implement localization with view-by-view `if language == ...` conditionals.
- Claim complete Chinese coverage without running the coverage and visual checks.

## Success Criteria

The feature is complete only when all of the following are true:

1. General Settings exposes a Language selector with Follow System, English, and 简体中文.
2. Existing users with old settings files load successfully and default to Follow System.
3. Changing English <-> Simplified Chinese updates FineTune-owned Settings and menu bar UI immediately without relaunch.
4. All FineTune-owned user-facing text has English and Simplified Chinese localization, including accessibility/help/error/notification text.
5. No persistence keys, command keys, routing identifiers, device identifiers, or user content change because of localization.
6. Count/interpolated/date/number text follows the selected locale where FineTune owns formatting.
7. Chinese UI passes layout review across all Settings tabs and all three popup sizes.
8. Full test suite passes without weakening existing tests.
9. Debug build succeeds using the repository's CI build command.
10. A final source scan finds no unexplained first-party English-only user-facing literals in production Swift code.
11. Sparkle and macOS-owned surface behavior has been tested and documented accurately; unsupported dynamic override behavior is not hidden.

## Risks and Mitigations

### Risk: plain String boundaries silently bypass extraction

Mitigation: fix reusable component/presentation types before bulk translation and use deferred localizable resources.

### Risk: persistence corruption from translating raw values

Mitigation: stable raw values plus separate localized display resources, with Codable regression tests.

### Risk: partial language switching

Mitigation: one persisted `AppLanguage`, one locale-resolution path, both SwiftUI roots wired to it, and a centralized resolver for non-SwiftUI surfaces.

### Risk: dependency-owned updater does not follow in-app locale

Mitigation: explicit Sparkle 2.8.1 verification before calling the feature complete; keep custom user driver as a separately approved option.

### Risk: incomplete string inventory

Mitigation: combine String Catalog extraction/build feedback with a source audit for plain-String AppKit/custom-component boundaries and final visual review.

## Official References

- Apple, Localizing and varying text with a string catalog: https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog
- Apple, Preparing your app's text for translation: https://developer.apple.com/documentation/xcode/preparing-your-apps-text-for-translation
- Apple, SwiftUI EnvironmentValues.locale: https://developer.apple.com/documentation/swiftui/environmentvalues/locale
- Apple, LocalizedStringResource: https://developer.apple.com/documentation/foundation/localizedstringresource
- Apple, LocalizedStringResource.locale: https://developer.apple.com/documentation/foundation/localizedstringresource/locale
- Apple, Supporting multiple languages in your app: https://developer.apple.com/documentation/xcode/supporting-multiple-languages-in-your-app
- Apple, Localization testing guidance: https://developer.apple.com/localization/
- Apple, Localizing Info.plist values: https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html
- Sparkle source/release baseline: https://github.com/sparkle-project/Sparkle

## Open Decision Before Implementation

The only material scope decision that may emerge from implementation verification is Sparkle's dependency-owned update window. The default plan is to localize every FineTune-owned surface and test Sparkle 2.8.1. If Sparkle does not follow the in-app language selector, replacing its standard UI with a custom user driver requires explicit approval because that is a separate update-system feature, not a translation-only change.
