# Technical Background: FineTune UI Localization

Last validated: 2026-08-23

This document records the platform and dependency facts that matter for the current localization implementation. `SPEC-ui-localization.md` defines product behavior.

## Current conclusion

FineTune can provide immediate English/Simplified Chinese switching for FineTune-owned presentation without changing the process-wide macOS application language.

The current product selector is `Auto`, `English`, and `简体中文`.

`Auto` has superseded the earlier Follow System design. The persisted raw value `system` remains for compatibility, but current runtime behavior always maps FineTune-owned UI to either `en` or `zh-Hans`.

## String Catalog model

FineTune uses Apple's String Catalog toolchain:

- `FineTune/Localizable.xcstrings` for FineTune-owned UI
- `FineTune/InfoPlist.xcstrings` for localizable Info.plist values

The application target already enables String Catalog preference, generated symbols, and Swift localization extraction.

Generated symbols remain enabled globally. Two known manual catalog entries disable symbol generation individually to avoid name collisions:

- ` (off)`
- `Volume boost:`

## Runtime language and native application language

Two language boundaries must remain distinct.

### FineTune runtime UI language

`AppLanguage` and `LocalizationContext` control FineTune-owned presentation.

The selected FineTune language is always concrete:

- `en`
- `zh-Hans`

The presentation locale retains the user's region where supported so changing UI language does not silently change regional date/number conventions.

### macOS application language

Bundle resource lookup outside FineTune's custom presentation layer can still use the native macOS application language and user language preferences.

FineTune's runtime override does not rewrite that process-wide bundle language.

This distinction is why dependency/system surfaces may use a different language from FineTune-owned UI when the user chooses a conflicting explicit FineTune language.

## Deferred localization

FineTune uses `LocalizedStringResource` for static first-party text that crosses layers or is resolved later.

This is important because localization intent can be lost when static copy is converted to a plain `String` too early.

Resolve to `String` only at final String-only APIs, including notification content and AppKit presentation.

Do not add a convenience API that accepts arbitrary dynamic String keys. The CI #79 failure showed the value of preserving the typed localization boundary.

## Dynamic external values

Keep these outside localization lookup:

- application names
- device names
- user-created EQ preset names
- AutoEQ profile/model/source names
- UIDs and PIDs
- bundle identifiers
- versions/build numbers
- URLs
- SF Symbols
- protocol and persistence keys
- other external identity values

The notification presentation tests explicitly verify dynamic device names remain verbatim.

## Detached hosting roots

A detached `NSHostingView` does not automatically inherit the parent FineTune locale in the way required by this architecture.

FineTune explicitly propagates the resolved locale into:

- shared popover/dropdown hosts
- Tahoe HUD
- Classic HUD
- per-app HUD roots

Future detached hosting roots must be treated as locale boundaries.

## Sparkle 2.8.1

FineTune uses `SPUStandardUpdaterController`.

Confirmed from Sparkle 2.8.1 source:

- Sparkle ships Chinese localization resources.
- `SPUStandardUserDriver` uses Sparkle localization helpers.
- `SULocalizations.h` resolves standard UI strings through `NSLocalizedStringFromTableInBundle` using the Sparkle framework bundle.

Implication:

FineTune's SwiftUI/Foundation runtime locale override does not force the Sparkle framework bundle to use FineTune's selected runtime language.

If native macOS application language and FineTune language differ, the Sparkle standard updater is not guaranteed to match the FineTune selector.

Replacing the standard user driver with a custom `SPUUserDriver` would increase updater responsibilities and is outside the approved scope.

Rejected approaches:

- `AppleLanguages` mutation
- bundle swizzling
- private localization forcing
- custom Sparkle UI solely for this selector

## KeyboardShortcuts 2.4.0

Confirmed from tag 2.4.0 source:

- `zh-Hans.lproj` is included.
- `RecorderCocoa` owns visible placeholder/conflict-alert text.
- package strings are resolved through `NSLocalizedString(self, bundle: .module, ...)`.

Implication:

FineTune-owned shortcut section labels and descriptions follow `LocalizationContext`, but package-owned Recorder strings use the package bundle's native localization selection. A conflicting FineTune runtime language does not guarantee package-owned text switches with it.

Forking/replacing KeyboardShortcuts solely to force runtime language behavior is outside scope.

## macOS-owned UI

FineTune can localize:

- privacy purpose-string values through `InfoPlist.xcstrings`
- FineTune-owned custom panel messages

macOS owns:

- privacy-prompt chrome
- standard file-panel controls
- other system-owned chrome

The in-app FineTune selector does not claim control over those surfaces.

## Production verification state

Current production localization code at `b556b5019b8dc21931416094b0a5c5dc0d30647d` passed CI #83 Build and Test.

The AudioEngine notification integration was created from an exact source blob, reviewed as a detached candidate, corrected for an accidental missing final newline, rebuilt as one clean commit, compared, and then advanced with a non-force branch update.

This is the preferred workflow for future large sensitive files.

## What remains unverified here

The current environment cannot run FineTune's macOS GUI, so the following remain manual runtime checks:

- visual clipping and layout in all required Chinese states
- live switching across every surface
- live dependency/system language under mismatched native application language and FineTune runtime language
- accessibility behavior that requires the running GUI

Direct local repository cloning is also unavailable in the current container because `github.com` DNS resolution fails. Source completeness conclusions therefore combine exact GitHub file reads, Git diffs, String Catalog regression tests, focused source review, and CI rather than a local whole-repository regex scan.

Do not convert these environment limitations into claims of completed visual testing.
