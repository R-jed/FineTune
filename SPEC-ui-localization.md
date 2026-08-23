# Spec: Application UI Localization

Status: Reviewed and implementation-ready as of 2026-08-23. This document defines the approved scope and architecture for the first implementation pass.

## Objective

Add a first-class UI language preference to FineTune and ship a complete Simplified Chinese localization for all FineTune-owned user interface surfaces while preserving the existing English experience, regional formatting behavior, and persisted settings compatibility.

The in-app language selector supports:

- Follow System
- English (`en`)
- 简体中文 (`zh-Hans`)

New and existing installations default to Follow System unless the user explicitly chooses a language.

Explicit English or Simplified Chinese selection should update FineTune-owned UI immediately without requiring an app relaunch. Follow System must preserve the language macOS selects for the FineTune application.

## Terminology and Platform Boundary

Two different language concepts exist on macOS and must stay separate.

### macOS application language

macOS can select a language for an individual application through System Settings > General > Language & Region. Bundle resource lookup and dependency/system UI can use this application language. Apple recommends the native per-app language mechanism for whole-application language selection.

### FineTune runtime UI language

FineTune may apply a runtime locale override to its own SwiftUI and Foundation presentation resources when the user explicitly selects English or Simplified Chinese inside FineTune.

This runtime override controls FineTune-owned UI. It does not change the process-wide macOS application language and does not guarantee that Sparkle, KeyboardShortcuts, privacy prompts, or standard AppKit panel chrome will switch with it.

The product requirement for this feature is therefore:

- FineTune-owned UI switches immediately for explicit English or Simplified Chinese selection.
- Follow System leaves native macOS application-language selection untouched.
- Dependency/system-owned UI behavior is tested and documented accurately.
- No private preference mutation, `AppleLanguages` manipulation, bundle swizzling, or other unsupported process-language forcing is used.

## Confirmed Repository Baseline

- FineTune is a macOS SwiftUI menu bar application.
- `FineTuneApp` creates the production `SettingsManager`; Settings and the menu bar popup share that settings graph.
- `AppSettings` is `Codable` and already uses backward-compatible `decodeIfPresent` patterns.
- The Settings window contains General, Audio, Shortcuts, Updates, and About tabs.
- The menu bar popup is a separate SwiftUI root.
- The project uses Xcode file-system-synchronized groups for `FineTune/`.
- Xcode development region is English.
- Project `knownRegions` currently contains `en` and `Base`; `zh-Hans` must be added.
- The application target already enables:
  - `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`
  - `STRING_CATALOG_GENERATE_SYMBOLS = YES`
  - `SWIFT_EMIT_LOC_STRINGS = YES`
- `Info.plist` currently contains English-only purpose strings for audio capture, microphone, and Bluetooth.
- `Package.resolved` pins:
  - Sparkle 2.8.1
  - KeyboardShortcuts 2.4.0
  - FluidMenuBarExtra 1.5.1
  - swift-snapshot-testing 1.18.7
- Sparkle 2.8.1 ships Simplified Chinese resources.
- KeyboardShortcuts 2.4.0 ships `zh-Hans` resources.

The planning baseline CI run for commit `084cfa996e9b3bcd1b50dc9c1fdb16e37bf0e334` completed successfully, including Build and Test.

## Confirmed Localization Debt

The application UI is currently effectively English-only. A Chinese README does not localize the shipping application.

User-visible first-party text exists across:

- Settings root, tabs, dialogs, reusable Settings components, and window title
- menu bar popup headers, footer, edit mode, empty states, help text, and accessibility labels
- app and device rows
- device inspector and device detail controls
- EQ and built-in preset presentation
- AutoEQ browse, search, status, import, errors, and controls
- permission banners
- Bluetooth connection states and errors
- AppKit file-panel custom messages
- FineTune-generated notifications and lower-layer user-facing errors
- update status and relative-date text

Several shared APIs currently erase localization intent by converting static presentation text to plain `String` before rendering. `SettingsRow` and `SettingsSection` are confirmed examples.

Several persisted or command types also combine stable internal identifiers with English display text. Appearance, popup size, volume hotkey step, menu bar icon style, shortcut actions, and device volume tiers are confirmed examples. Their stored identifiers must remain stable.

## Approved Localization Architecture

### 1. Native String Catalogs

Use Apple's String Catalog system as the source of truth.

Application resources:

- `FineTune/Localizable.xcstrings` for FineTune-owned UI strings
- `FineTune/InfoPlist.xcstrings` for localizable Info.plist values, including privacy purpose strings

Languages:

- English as source/development language
- Simplified Chinese (`zh-Hans`)

Add `zh-Hans` to the Xcode project's known localization regions and verify the built `.app` contains the expected localization resources.

The application target already has String Catalog extraction and generated symbol support enabled. Do not add a second localization generation system.

### 2. Stable AppLanguage Preference

Add a focused `AppLanguage` type with stable Codable raw values:

- `system`
- `en`
- `zh-Hans`

Add `language` to `AppSettings` with default `.system` and backward-compatible decoding.

Display names are localized presentation values and must never become persistence identifiers.

### 3. Follow System Means No FineTune Locale Override

`system` must not map to `.autoupdatingCurrent` as an explicit SwiftUI language override.

When `AppLanguage == .system`:

- do not inject an application-defined locale into FineTune's SwiftUI roots
- allow native bundle/application-language selection to continue normally
- resolve non-SwiftUI localized resources using default bundle behavior

This preserves any per-app language the user selected for FineTune in macOS Language & Region settings.

### 4. Explicit Language Override Preserves Region

When the user selects English or Simplified Chinese, FineTune applies an explicit first-party UI language override.

Language and region are separate preferences. Switching UI language must not silently change the user's regional conventions for dates, numbers, measurement, first day of week, or similar formatting.

Use a small localization-context type that can provide:

- whether a SwiftUI locale override is active
- the explicit language/script (`en` or `zh-Hans`)
- a presentation locale created from the selected language/script while retaining the user's current region where supported
- a deferred resource resolver for Foundation/AppKit boundaries

`Locale.Components` is the preferred Foundation mechanism for combining an explicit language/script with current regional preferences. Add unit tests for both language selection and retained region behavior.

Do not scatter locale construction across individual views.

### 5. SwiftUI Root Propagation

Apply the explicit runtime locale only when the user chooses English or Simplified Chinese.

The two required roots are:

- Settings hierarchy
- menu bar popup hierarchy

The selected value must remain observable through the existing `SettingsManager` graph so an explicit language change re-renders active FineTune-owned UI immediately.

Follow System must leave those roots unmodified by FineTune language injection.

### 6. Deferred Localization Outside SwiftUI

Use `LocalizedStringResource` for reusable presentation values and text that crosses layers or must be resolved later.

Confirmed uses include:

- enum/action display names
- reusable custom-component labels
- accessibility/help text passed through helper APIs
- AppKit window title and file-panel custom message
- FineTune-generated notification text
- lower-layer user-facing status/error text

For explicit FineTune language selection, set the resource locale before resolving it to `String`. Do not assume the `locale:` argument of the basic `String(localized:)` initializer changes bundle language lookup; Apple documents that argument primarily for interpolation formatting.

### 7. Reusable Component Boundaries

Refactor static presentation APIs so localization metadata survives until rendering.

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

Use plain `String` for genuinely dynamic/user/system-provided content such as:

- application names
- audio-device names
- user-created EQ preset names
- AutoEQ profile/model names
- measurement/source names provided by external data
- UIDs, bundle identifiers, PIDs
- version/build values

### 8. Stable Identifiers

Do not translate or change:

- Codable/raw persistence values
- shortcut action keys
- bundle identifiers
- URL schemes
- device UIDs
- stored application identifiers
- SF Symbol names
- Sparkle signing/update identifiers
- AutoEQ external profile identifiers

Presentation strings localize independently of these values.

### 9. Interpolation, Plurals, Dates, and Numbers

Use String Catalog interpolation and plural variants for count-bearing first-party strings such as ignored-app counts.

FineTune-owned formatting must respect the selected UI language while retaining the user's regional conventions. `UpdatesTab` currently uses `RelativeDateTimeFormatter` without an explicit feature-aware formatting context and must be corrected.

Standard technical units and identifiers such as `kHz`, `dB`, `PID`, version numbers, and numeric frequencies remain technically accurate while surrounding prose is localized.

## Chinese Language Quality

The Chinese UI should read as native macOS product text rather than literal word-for-word translation.

Initial terminology direction:

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
- Equalizer / EQ -> 均衡器 / EQ depending on context and available space
- Follow System -> 跟随系统
- System Default -> 系统默认 when that wording better matches the control context
- AutoEQ remains `AutoEQ`
- FineTune remains `FineTune`

Every translation pass must review UI context, width, tone, and action semantics. Global search-and-replace translation is not acceptable.

## First-Party Coverage Requirement

The implementation must cover all FineTune-owned user-facing text, including:

- Settings all tabs
- Settings window title and reset confirmation
- menu bar Output/Input tabs
- normal and edit/reorder modes
- app rows and inactive-app rows
- output/input/Bluetooth device rows
- app/device edit rows and picker controls
- permission banner
- EQ panel and built-in preset/category presentation
- AutoEQ empty/loading/search/favorites/import/error/correction/preamp states
- device inspector and detail panel
- FineTune-owned AppKit strings
- FineTune notifications
- FineTune-owned lower-layer errors/status
- help text and tooltips
- accessibility labels/descriptions
- plural/interpolated strings
- locale-sensitive first-party formatted status text

Do not count user-provided, device-provided, profile-provided, or OS/dependency-provided text as untranslated first-party copy.

## Dependency and System Boundaries

### Sparkle 2.8.1

Sparkle 2.8.1 includes updated Simplified Chinese resources. FineTune currently uses `SPUStandardUpdaterController`, so Sparkle owns the standard update window.

Implementation must test whether the standard updater follows:

- native macOS application language
- FineTune's explicit runtime UI language override

If Sparkle does not follow the FineTune runtime override, record that boundary. Replacing `SPUStandardUserDriver` with a custom `SPUUserDriver` is outside the approved localization implementation scope because it expands update-state, authorization, installation, and security responsibilities.

### KeyboardShortcuts 2.4.0

KeyboardShortcuts 2.4.0 already ships Simplified Chinese resources. Test the visible Recorder UI and conflict warnings under native app-language and FineTune runtime-override combinations.

Do not fork or replace the dependency solely to force runtime language behavior without separate approval.

### macOS-Owned UI

The app can localize its privacy purpose strings and FineTune-owned `NSOpenPanel.message`, but macOS owns the language of privacy prompt chrome and standard file-panel controls.

Test and document observed behavior. Do not claim FineTune controls those surfaces unless actual verification proves it.

## Project Structure

Expected changes remain within existing ownership boundaries:

```text
FineTune.xcodeproj/
  project.pbxproj                    # register zh-Hans
FineTune/
  Localizable.xcstrings             # FineTune-owned UI
  InfoPlist.xcstrings               # privacy purpose strings
  Settings/
    SettingsManager.swift           # persisted AppLanguage field
    Types/                           # AppLanguage / localization context
  Views/
    Settings/
    Components/
    Rows/
    Sheets/
    EQPanelView.swift
    MenuBarPopupView.swift
  Utilities/                         # focused resolver only if ownership fits better here
FineTuneTests/
  ...                                # persistence/localization/regression tests
```

Do not turn `MenuBarPopupView.swift` into a localization service. Shared localization behavior belongs in a focused type.

## Required Automated Tests

Add focused tests for:

- `AppLanguage` stable raw values
- old settings payloads decoding without the language field
- round-trip persistence of all language choices
- Follow System producing no FineTune SwiftUI locale override
- explicit English and Simplified Chinese producing the intended language/script
- explicit language override retaining current regional conventions
- deferred `LocalizedStringResource` resolution in both supported explicit languages
- existing persistence identifiers remaining unchanged
- representative localized presentation values from every major UI area
- plural/interpolated ignored-app counts
- feature-aware relative-date/status formatting
- built-in EQ presentation labels without changing EQ model values

Run the existing full FineTune test suite without weakening existing tests.

## Required Build and UI Verification

Canonical build:

```bash
xcodebuild build \
  -project FineTune.xcodeproj \
  -scheme FineTune \
  -configuration Debug \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO
```

Canonical test:

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

Verify visually in English and Simplified Chinese:

- Settings every tab at 720 x 560
- popup Compact, Comfortable, and Spacious
- Output and Input
- normal, device-edit, and app-edit modes
- app/device/Bluetooth rows
- EQ save/rename/cancel/preset flows
- AutoEQ no-selection, selected, loading, search, favorites, import success, import failure
- permission banner states
- device inspector/detail states
- update status
- About
- AutoEQ file-panel custom message
- notification content

Review clipping, overlap, line wrapping, truncation, untranslated first-party copy, and accessibility/help strings.

## Final Source Completeness Guard

After String Catalog extraction/build, classify every remaining English string literal in shipping Swift code as one of:

1. localized user-facing copy
2. stable internal identifier
3. SF Symbol/API/system key
4. log/debug/developer-only text
5. user/system/external dynamic content
6. test/preview-only text

Any unexplained first-party user-facing English literal blocks merge.

Also verify:

- `zh-Hans` exists in project localization metadata
- `Localizable.xcstrings` and `InfoPlist.xcstrings` are present in the built product as expected
- privacy purpose strings resolve in Simplified Chinese
- no relevant localization warnings remain unexplained

## Success Criteria

The feature is complete only when all of the following are true:

1. General Settings exposes Follow System, English, and 简体中文.
2. Existing settings files load successfully and default the new field to Follow System.
3. Follow System leaves native macOS application-language behavior untouched.
4. Explicit English and Simplified Chinese update FineTune-owned active UI immediately.
5. Explicit UI language selection retains the user's regional formatting preferences.
6. All FineTune-owned user-facing text has English and Simplified Chinese resources, including accessibility, help, error, notification, and AppKit-owned first-party text.
7. No persistence, shortcut, routing, device, bundle, or external profile identifier changes because of localization.
8. Interpolated/plural/relative-date text is localized correctly.
9. Chinese layout passes all required visual states and popup sizes.
10. `zh-Hans`, `Localizable.xcstrings`, and `InfoPlist.xcstrings` are registered and shipped correctly.
11. Full test suite passes.
12. Debug build succeeds.
13. Final source scan finds no unexplained first-party English-only user-facing literals.
14. Sparkle, KeyboardShortcuts, privacy prompts, and standard file-panel behavior are tested and documented accurately.
15. Final diff contains no unrelated release, signing, appcast, repository-ownership, or audio-engine changes.

## Scope Boundaries

Always:

- preserve GPL v3 and upstream copyright notices
- keep persisted/internal identifiers stable
- use Apple-supported localization APIs and resources
- preserve English behavior
- preserve user regional conventions during explicit UI language override
- verify before marking tasks complete

Separate approval is required for:

- custom Sparkle user driver or replacement update UI
- custom replacement for standard macOS file panels solely for language control
- forking/replacing third-party UI solely for runtime language control
- update/signing/appcast changes
- product rename
- additional languages beyond English and Simplified Chinese
- persistence/raw-value migrations unrelated to adding the new language field

Never:

- mutate undocumented `AppleLanguages` preferences
- use bundle-swizzling language hacks
- store translated labels as persistence keys
- translate user/device/profile names
- implement localization with view-by-view language conditionals
- describe system/dependency-owned UI as FineTune-controlled without verified evidence
- claim complete Chinese coverage before automated, source, bundle, and visual verification

## Official References

- Apple, Localizing and varying text with a string catalog: https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog
- Apple, Preparing views for localization: https://developer.apple.com/documentation/swiftui/preparing-views-for-localization
- Apple, LocalizedStringResource: https://developer.apple.com/documentation/foundation/localizedstringresource
- Apple, `String.init(localized:options:)`: https://developer.apple.com/documentation/swift/string/init(localized:options:)
- Apple, Locale.Components: https://developer.apple.com/documentation/foundation/locale/components
- Apple, Supporting multiple languages in your app: https://developer.apple.com/documentation/xcode/supporting-multiple-languages-in-your-app
- Apple, Localization: https://developer.apple.com/localization/
- Apple, WWDC19 Creating Great Localized Experiences with Xcode 11: https://developer.apple.com/videos/play/wwdc2019/403/
- Apple, WWDC23 Discover String Catalogs: https://developer.apple.com/videos/play/wwdc2023/10155/
- Apple, WWDC25 Code-along: Explore localization with Xcode: https://developer.apple.com/videos/play/wwdc2025/225/
- Sparkle custom UI documentation: https://sparkle-project.org/documentation/custom-user-interfaces/
- Sparkle 2.8.1 release: https://github.com/sparkle-project/Sparkle/releases/tag/2.8.1
- KeyboardShortcuts repository/localization documentation: https://github.com/sindresorhus/KeyboardShortcuts

## Implementation Authorization

The architecture above has no remaining blocker for the first implementation pass.

Implementation may begin on `feature/ui-localization` after this reviewed specification is committed. Dependency/system-owned language behavior remains a verification task during implementation and does not block first-party localization work. Any proposal to replace Sparkle, KeyboardShortcuts, or macOS-owned UI requires separate approval.