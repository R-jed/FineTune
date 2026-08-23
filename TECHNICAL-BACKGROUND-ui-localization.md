# Technical Background: FineTune UI Localization

Last validated: 2026-08-23

This document records the platform and dependency facts behind `SPEC-ui-localization.md` and `tasks/plan.md`. It exists to separate confirmed behavior from implementation assumptions before the localization feature is coded.

## Executive conclusion

FineTune can ship a complete Simplified Chinese localization for all FineTune-owned UI using Apple's current String Catalog toolchain. The project is already configured for Xcode 26 string extraction and generated String Catalog symbols.

There are two distinct concepts that must stay separate during implementation:

1. The macOS application language. This is the language selected by macOS for the application bundle. macOS supports a per-app language choice in System Settings. Apple recommends using this platform mechanism for the application language.
2. A FineTune-owned runtime locale override. SwiftUI and Foundation APIs can resolve FineTune-owned strings for a selected locale while the process remains in a different macOS application language. This can provide immediate switching for FineTune-owned surfaces, but it does not automatically change dependency-owned or macOS-owned UI.

The product requirement currently asks for an in-app language selector. Therefore the implementation may use a FineTune-owned runtime locale override for FineTune UI, while treating the native macOS application-language mechanism as the authoritative whole-application language boundary. Do not describe the runtime override as changing the process-wide macOS application language.

## 1. Apple's supported localization model

Apple's current Xcode guidance uses String Catalogs as the primary localization resource format.

Confirmed behavior from Apple documentation and WWDC sessions:

- `Localizable.xcstrings` is the default String Catalog for application strings.
- Xcode discovers localizable strings during builds and keeps String Catalog entries in sync with localizable source APIs.
- Most SwiftUI string literals passed to localizable view APIs are extracted automatically.
- Custom views must preserve localization-aware types. Apple explicitly demonstrates `LocalizedStringResource` for custom declarations that pass localizable strings between layers.
- String Catalogs support interpolation, plural variants, translator comments and multiple string tables.
- Xcode 26 can generate type-safe Swift symbols from String Catalog entries.
- Apple recommends starting with source extraction and using generated symbols when stronger organization or type safety is valuable.

Primary sources:

- https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog
- https://developer.apple.com/videos/play/wwdc2023/10155/
- https://developer.apple.com/videos/play/wwdc2025/225/

### Implication for FineTune

FineTune should use a hybrid style:

- Keep straightforward view-local literals readable at the call site and let Xcode extract them.
- Use `LocalizedStringResource` for reusable components, enum/action presentation values, strings crossing view/model boundaries, and AppKit/notification strings that are resolved later.
- Prefer generated String Catalog symbols where a stable typed reference improves safety, especially for non-view presentation resources and strings reused in multiple places.

Do not create a parallel home-grown localization dictionary.

## 2. FineTune's Xcode project is already localization-ready

The current application target already has the relevant Xcode settings enabled in both Debug and Release:

- `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`
- `STRING_CATALOG_GENERATE_SYMBOLS = YES`
- `SWIFT_EMIT_LOC_STRINGS = YES`

The tests intentionally disable generated catalog symbols and localization extraction, which is reasonable because the shipping resources belong to the application target.

The missing project-level localization registration is `zh-Hans`. The project currently declares only:

- `en`
- `Base`

Implementation therefore needs to add Simplified Chinese to the project's known localization regions and verify the built application bundle contains the corresponding resources.

Repository evidence:

- `FineTune.xcodeproj/project.pbxproj`

### Planning correction

Earlier planning treated generated String Catalog symbols as something that might need to be enabled. That is no longer an open question. They are already enabled for the FineTune application target.

## 3. Custom SwiftUI component boundaries matter

Apple's localization extraction is type-aware. A string literal passed directly to a localizable SwiftUI API can be extracted, while an application-specific API that accepts a plain `String` can erase that intent before rendering.

FineTune currently has confirmed examples:

- `SettingsRow` accepts `String` for title and description.
- `SettingsSection` accepts `String?` for its title.
- presentation values such as shortcut names and several enum descriptions are exposed as plain English `String` values.

These are architectural localization boundaries, not translation-only work.

Apple's recommended localization-aware types include:

- `LocalizedStringKey` for SwiftUI-only string-key flows.
- `LocalizedStringResource` for values that need to be represented, stored temporarily or passed between APIs before final localization.

Source:

- https://developer.apple.com/videos/play/wwdc2023/10155/
- https://developer.apple.com/documentation/swiftui/preparing-views-for-localization

### FineTune direction

Prefer `LocalizedStringResource` for shared FineTune component APIs when the value may need to cross a boundary. Keep plain `String` for genuinely dynamic content such as device names, application names, user-created preset names, profile/model names, UIDs and externally supplied text.

## 4. Runtime locale and string lookup are not the same thing

A subtle Foundation behavior matters for FineTune's in-app selector.

Apple documents that the `locale` parameter on the ordinary `String(localized:..., locale:)` family is used to localize interpolated values such as numbers. It does not by itself change which localization the system uses to look up the string resource.

For an explicit different-language lookup, Apple documents `LocalizedStringResource` as the deferred resource container. Its `locale` can be changed before resolving it using `String(localized:)`.

Source:

- https://developer.apple.com/documentation/swift/string/init(localized:options:)

### Implication for FineTune

A non-SwiftUI localization resolver must not assume that passing `Locale(identifier: "zh-Hans")` to an arbitrary `String(localized:...)` overload changes the resource lookup language.

For AppKit messages, notifications, lower-layer user-facing errors and other strings that must explicitly follow the FineTune selector:

1. represent the message as `LocalizedStringResource`;
2. apply the selected locale to the resource;
3. resolve it at the final `String` boundary.

This behavior should have focused tests in English and Simplified Chinese before large-scale UI conversion begins.

## 5. macOS already has a native per-app language mechanism

Apple's current localization guidance confirms that macOS users can choose the language of an individual application from System Settings > General > Language & Region.

Apple's WWDC guidance for app-specific languages also states:

- do not manually set the application language in code;
- if an app wants to expose an affordance for changing its application language, Apple's preferred model is to direct the user to the system app-language setting;
- changing the native application language causes the application to relaunch in that language.

Sources:

- https://developer.apple.com/localization/
- https://developer.apple.com/videos/play/wwdc2019/403/
- https://support.apple.com/guide/mac-help/change-the-system-language-mh26684/mac

### Important design distinction

FineTune's requested in-app selector and macOS's application language are not equivalent mechanisms.

The planned SwiftUI `EnvironmentValues.locale` override can make FineTune-owned SwiftUI content respond immediately. Explicit `LocalizedStringResource` resolution can do the same for FineTune-owned non-SwiftUI text. Neither mechanism proves that Sparkle, package-owned UI, privacy prompts or standard AppKit panels have changed their application language.

Therefore implementation and testing must use these terms precisely:

- `selected FineTune UI language` for the runtime override;
- `macOS application language` for the system-selected bundle language.

If product requirements later demand one language across every first-party, dependency and system-owned surface, the native macOS application-language mechanism is the cleanest supported consistency boundary, with a relaunch tradeoff.

## 6. Info.plist localization should use InfoPlist.xcstrings

The current FineTune `Info.plist` contains three user-visible privacy purpose strings:

- `NSAudioCaptureUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSBluetoothAlwaysUsageDescription`

Apple's modern String Catalog workflow supports a catalog named `InfoPlist.xcstrings`. Xcode populates known localizable Info.plist keys into this catalog during the build, and translations can be managed there.

Sources:

- https://developer.apple.com/videos/play/wwdc2023/10155/
- https://developer.apple.com/documentation/uikit/requesting-access-to-protected-resources

### Planning correction

Prefer:

- `FineTune/InfoPlist.xcstrings`

for these privacy strings.

The earlier draft plan mentioned a traditional `zh-Hans.lproj/InfoPlist.strings` resource. That legacy mechanism remains valid, but `InfoPlist.xcstrings` better matches this Xcode 26 project and the project's existing String Catalog preference.

The implementation should verify that Xcode extracts the three current keys from `FineTune/Info.plist` and that the built `.app` contains the translated values.

## 7. String Catalog symbols are useful here, but should not dominate view code

Xcode 26 can generate static `LocalizedStringResource` symbols from String Catalog entries. Apple documents that generated symbols can be used directly in SwiftUI and Foundation, and can generate functions for interpolated resources.

FineTune already has `STRING_CATALOG_GENERATE_SYMBOLS = YES`, so this capability is available without a new build-system change.

Source:

- https://developer.apple.com/videos/play/wwdc2025/225/

### Recommended usage

Use generated symbols selectively for:

- enum and shortcut presentation names;
- reusable component labels;
- notification titles/bodies;
- AppKit messages;
- shared formatted/interpolated messages;
- strings where a typo in a manual key would be costly.

For simple one-off SwiftUI literals, source extraction remains easier to read and is Apple's recommended starting point.

## 8. KeyboardShortcuts 2.4.0 already contains Simplified Chinese resources

FineTune pins `KeyboardShortcuts` 2.4.0.

Confirmed upstream facts:

- the package explicitly supports localization resources;
- release 2.4.0 included localization fixes;
- the exact 2.4.0 tag contains `Sources/KeyboardShortcuts/Localization/zh-Hans.lproj/Localizable.strings`;
- that Simplified Chinese resource includes recorder text, shortcut-conflict warnings, system-shortcut guidance, buttons and key names.

Sources:

- https://github.com/sindresorhus/KeyboardShortcuts/releases/tag/2.4.0
- https://raw.githubusercontent.com/sindresorhus/KeyboardShortcuts/2.4.0/Sources/KeyboardShortcuts/Localization/zh-Hans.lproj/Localizable.strings

### Implication

The dependency has the Chinese translations we need. The remaining question is selection behavior.

A FineTune SwiftUI locale override may or may not cause all package-internal localized resource lookups to use FineTune's selected UI language, depending on how the dependency resolves its package resources. That must be tested in the running 2.4.0 recorder instead of inferred.

Do not fork or replace the package solely because it owns localized UI unless verification proves a real blocking inconsistency.

## 9. Sparkle 2.8.1 already contains strong Simplified Chinese coverage

FineTune pins Sparkle 2.8.1 and currently uses `SPUStandardUpdaterController`, which encapsulates Sparkle's standard user interface.

Confirmed upstream facts:

- Sparkle 2.8.1 explicitly added missing Simplified Chinese and Traditional Chinese localizations.
- The Simplified Chinese resource is under `Sparkle/zh_CN.lproj/Sparkle.strings` in the 2.8.1 source tree.
- the 2.8 localization work consolidated updater strings into the main Sparkle string resource and tested update-alert/permission UI in multiple languages.
- Sparkle provides `SPUUserDriver` if an application needs to replace the standard updater UI with its own UI.

Sources:

- https://github.com/sparkle-project/Sparkle/releases/tag/2.8.1
- https://github.com/sparkle-project/Sparkle/commit/927adb667f788da4de0affe5da67d5abe7b99112
- https://sparkle-project.org/documentation/custom-user-interfaces/

### Implication

Translation availability is not the main Sparkle risk. The unresolved issue is language selection when FineTune's custom UI language differs from the macOS application language.

A custom Sparkle user driver is intentionally out of the default localization scope because Sparkle documents multiple responsibilities that a custom driver must handle, including:

- update permission requests;
- update states;
- installation authorization scenarios;
- update presentation/focus behavior;
- release-note and automatic-update interaction expectations.

Replacing the standard user driver solely to force FineTune's runtime UI language would materially increase updater maintenance and should require a separate decision.

## 10. System-owned UI remains outside the runtime override

Even with complete FineTune resources, these surfaces are controlled partly or fully outside FineTune's view hierarchy:

- macOS privacy permission prompt chrome;
- standard `NSOpenPanel` controls;
- Sparkle standard updater UI;
- dependency-owned resource lookups.

FineTune can localize its own privacy purpose strings and its custom `NSOpenPanel.message`, but it should not claim to control the language of the surrounding macOS UI unless a platform test proves it.

This distinction is part of the completion criteria, not an optional documentation detail.

## 11. Revised implementation recommendation

Based on the validated platform background, the cleanest implementation remains:

1. Register `zh-Hans` as a project localization.
2. Add `Localizable.xcstrings` for FineTune-owned UI.
3. Add `InfoPlist.xcstrings` for privacy purpose strings.
4. Add a stable persisted `AppLanguage` value for the product's requested in-app UI-language selector.
5. Preserve `LocalizedStringResource` through shared components and presentation types.
6. Use Xcode's already-enabled generated String Catalog symbols selectively at cross-layer boundaries.
7. Apply the selected locale to both FineTune SwiftUI roots.
8. Resolve FineTune-owned AppKit/notification strings explicitly through `LocalizedStringResource` with the selected locale.
9. Keep persistence identifiers independent from display labels.
10. Verify KeyboardShortcuts 2.4.0, Sparkle 2.8.1 and macOS-owned surfaces against the native macOS application language and the FineTune UI-language override as separate test variables.

## 12. Required verification matrix

At minimum, test these language combinations:

| macOS application language | FineTune UI selection | Expected FineTune-owned UI | What this case proves |
| --- | --- | --- | --- |
| English | Follow System | English | baseline |
| English | English | English | explicit English |
| English | 简体中文 | Simplified Chinese | runtime override works for FineTune-owned UI |
| 简体中文 | Follow System | Simplified Chinese | native bundle localization works |
| 简体中文 | English | English | reverse runtime override works |
| 简体中文 | 简体中文 | Simplified Chinese | aligned native/custom language |

For each meaningful case, inspect:

- Settings;
- menu bar popup;
- EQ and AutoEQ;
- device inspector;
- notifications and custom AppKit messages;
- `KeyboardShortcuts.Recorder`;
- Sparkle standard updater UI;
- standard file-panel chrome;
- privacy purpose strings where testable.

Record which language each dependency/system surface actually uses.

## 13. What is confirmed and what remains unverified

Confirmed:

- FineTune's Xcode target already enables String Catalog preference, generated symbols and Swift localization extraction.
- `zh-Hans` still needs project localization registration.
- Apple recommends String Catalogs and localization-aware custom component types.
- `LocalizedStringResource.locale` supports deferred explicit-language lookup.
- `InfoPlist.xcstrings` is the modern path for privacy purpose-string localization.
- macOS supports native per-app language selection.
- KeyboardShortcuts 2.4.0 ships Simplified Chinese resources.
- Sparkle 2.8.1 ships updated Simplified Chinese resources.
- Sparkle custom UI is a materially larger updater responsibility.

Still requires implementation-time verification:

- whether every FineTune SwiftUI root re-renders correctly under a runtime locale change;
- how KeyboardShortcuts 2.4.0 chooses package localization under FineTune's runtime override;
- how Sparkle 2.8.1 chooses its standard UI localization when native app language and FineTune UI language differ;
- macOS standard file-panel and permission-prompt chrome language under mismatched language selections;
- actual Chinese layout quality and String Catalog coverage after implementation.

These unresolved points must remain test items. They must not be converted into assumptions in code or release notes.
