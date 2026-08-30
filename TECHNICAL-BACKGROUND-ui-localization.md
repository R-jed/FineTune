# Technical Background: FineTune UI Localization

Last validated: 2026-08-24

This document records the platform and dependency facts that matter for the current localization implementation. `SPEC-ui-localization.md` defines product behavior.

## Current conclusion

FineTune provides immediate English/Simplified Chinese switching for FineTune-owned presentation without changing the process-wide macOS application language.

The product selector is `Auto`, `English`, and `简体中文`.

`Auto` has superseded the earlier Follow System design. The persisted raw value `system` remains for compatibility, but current runtime behavior always maps FineTune-owned UI to either `en` or `zh-Hans`.

The current first-party source review has found no remaining automated/source localization blocker. Runtime and visual proof still requires a real macOS GUI environment.

## String Catalog model

FineTune uses Apple's String Catalog toolchain:

- `FineTune/Localizable.xcstrings` for FineTune-owned UI
- `FineTune/InfoPlist.xcstrings` for localizable Info.plist values

The application target enables String Catalog generated symbols and Swift localization extraction.

Generated symbols remain enabled globally. Two known manual catalog entries disable symbol generation individually to avoid name collisions:

- ` (off)`
- `Volume boost:`

The legacy `Follow System` catalog entry remains unused. Removing that one unused manual resource is optional cleanup and is intentionally deferred because it has no runtime effect and is not worth a noisy catalog-only rewrite.

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

This matters because localization intent can be lost when static copy is converted to a plain `String` too early.

Resolve to `String` only at final String-only APIs, including notification content and AppKit presentation.

Do not add a convenience API that accepts arbitrary dynamic String keys. CI #79 demonstrated the value of preserving the typed localization boundary.

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
- SF Symbol identifiers
- protocol and persistence keys
- other external identity values

Notification presentation tests verify dynamic device names remain verbatim.

## Detached hosting roots

A detached `NSHostingView` does not automatically inherit the parent FineTune locale in the way required by this architecture.

FineTune explicitly propagates the resolved locale into:

- shared popover/dropdown hosts
- Tahoe HUD
- Classic HUD
- per-app HUD roots

Future detached hosting roots must be treated as locale boundaries.

## Device-icon discovery

Device icon category names originate from the internal icon catalog, while presentation needs to follow the selected FineTune locale.

The current implementation keeps SF Symbol identifiers verbatim and exposes typed localized resources for known category titles. Representative Simplified Chinese category searches such as `耳机`, `麦克风`, and `显示器` are covered by tests.

CI #85 exposed an invalid `String(localized:locale:)` overload use during this work. The repair kept the `LocalizedStringResource` boundary and resolves through `LocalizationContext` where a final `String` is required.

## AutoEQ error boundary

`AutoEQFetcher` may carry detailed English runtime diagnostics for network/catalog failures. These are diagnostic/internal values and must not be rendered verbatim as FineTune-owned Chinese UI.

The current `AutoEQSearchPanel` uses localized FineTune-owned `Failed to load` presentation for catalog failure while detailed fetch diagnostics remain available to the lower-level state/logging path.

External AutoEQ profile/model/source names continue to render verbatim.

## Sparkle 2.8.1

FineTune uses `SPUStandardUpdaterController`.

Confirmed from Sparkle 2.8.1 source:

- Sparkle ships Chinese localization resources.
- `SPUStandardUserDriver` uses Sparkle localization helpers.
- standard UI strings resolve from the Sparkle framework bundle.

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
- package strings are resolved through the package resource bundle.

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

Verified production-code head:

`ad4e09077e708de0989b4e5ceb9bab5d8e22c03e`

CI #87 passed Build, Test, test-result upload, and the complete workflow job.

Run id: `32651747504`.

Job id: `97224371006`.

Verified documentation-synchronized head before this technical-background refresh:

`0b94ebe5343f93a564fc3a54898edb45591ccada`

CI #88 also passed Build, Test, test-result upload, and the complete workflow job.

The feature branch was compared against `main` at that head and was ahead 89, behind 0, with 67 changed files. The comparison showed no dependency upgrade, release, signing, entitlement, or appcast drift. The `AudioEngine` diff remains limited to notification presentation integration rather than audio-routing/default-device behavior changes.

## Source-review state

The final source review covers PR-changed files and high-risk unchanged presentation boundaries under `Views`, `Settings`, `Utilities`, `Coordination`, audio permission/monitor presentation, and menu-bar support code.

Observed first-party presentation is catalog-backed/localized or intentionally dynamic/technical. Logging-only English strings are not classified as UI.

`SettingsManager.createUserPreset` retains a defensive `"Untitled"` fallback, but the shipping `EQPanelView` trims and rejects empty names before calling it. The fallback is therefore not exposed through the reviewed product UI.

## What remains unverified here

The current execution environment cannot run FineTune's macOS GUI, so these remain manual runtime checks:

- visual clipping and layout in all required Chinese states
- live switching across every surface
- live notification appearance and GUI accessibility behavior
- live dependency/system language under mismatched native application language and FineTune runtime language

Direct local repository cloning is also unavailable in the current container because `github.com` DNS resolution fails. Source completeness conclusions therefore combine exact GitHub file reads, Git diffs, String Catalog regression tests, focused source review, and CI rather than a local whole-repository regex scan.

Do not convert these environment limitations into claims of completed visual testing.
