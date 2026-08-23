# Implementation Readiness Review: UI Localization

Date: 2026-08-23

Decision: APPROVED FOR FIRST IMPLEMENTATION PASS

This review closes the planning gate for FineTune UI localization. It records what was checked, what was corrected, what remains a runtime verification boundary, and why implementation can begin.

## Reviewed Inputs

Repository planning artifacts:

- `SPEC-ui-localization.md`
- `TECHNICAL-BACKGROUND-ui-localization.md`
- `tasks/plan.md`
- `tasks/todo.md`
- root `HANDOFF.md`

Repository implementation facts checked:

- Xcode project localization settings
- `knownRegions`
- `Info.plist` privacy purpose strings
- `Package.resolved`
- shared Settings/presentation patterns identified during source audit
- Sparkle integration through `SPUStandardUpdaterController`

External technical background checked against current Apple/Sparkle/KeyboardShortcuts sources through Exa.

## Baseline Verification

Planning branch baseline commit before final plan corrections:

`084cfa996e9b3bcd1b50dc9c1fdb16e37bf0e334`

GitHub Actions CI run #9 completed successfully.

Confirmed successful steps:

- Checkout
- Xcode setup
- Build
- Test
- test-results upload

This establishes a green pre-implementation baseline. No application source code was changed by the planning PR before this readiness review.

## Corrections Made During Final Review

### 1. Follow System semantics

Earlier planning mapped Follow System to an explicit `.autoupdatingCurrent` locale override.

That was rejected during final review.

Apple distinguishes current locale/region from the running application's localization language. A macOS user can also choose a language specifically for FineTune in Language & Region settings.

Final rule:

- Follow System applies no FineTune-defined SwiftUI language override.
- Native bundle/application-language lookup remains authoritative.
- Explicit English or Simplified Chinese applies the FineTune-owned runtime override.

This prevents the new feature from breaking native per-app language selection.

### 2. Language and region are separate

Earlier planning used simple language-only locales for explicit switching.

Final rule:

- explicit selection changes FineTune UI language/script
- current user region preferences are retained where supported
- `Locale.Components` is used by a focused localization context rather than constructing locales independently in views
- tests must cover a non-default region

This avoids changing date, number, measurement, and similar regional conventions just because the user changes UI language.

### 3. Info.plist localization resource

Earlier planning allowed a traditional localized InfoPlist resource directory.

Final rule for this Xcode 26 project:

- use `FineTune/InfoPlist.xcstrings`
- keep English purpose strings in the source `Info.plist`
- add Simplified Chinese translations for audio capture, microphone, and Bluetooth purpose strings
- verify compiled bundle inclusion

### 4. Xcode String Catalog capabilities

The application target already enables:

- `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`
- `STRING_CATALOG_GENERATE_SYMBOLS = YES`
- `SWIFT_EMIT_LOC_STRINGS = YES`

No additional localization generation subsystem is required.

### 5. Dependency localization facts

Pinned dependency versions were rechecked from `Package.resolved`:

- Sparkle 2.8.1
- KeyboardShortcuts 2.4.0

Sparkle 2.8.1 includes updated Simplified Chinese resources.

KeyboardShortcuts 2.4.0 includes `zh-Hans` resources.

Their remaining risk is runtime language-selection behavior when FineTune's explicit UI language differs from the native macOS application language.

## Architecture Approval

Approved implementation shape:

1. stable `AppLanguage` persisted preference
2. one focused localization context
3. no override for Follow System
4. explicit English/Chinese first-party runtime override
5. region-preserving locale construction
6. String Catalog source of truth
7. `LocalizedStringResource` for text crossing presentation boundaries
8. shared component refactor before bulk translation
9. `InfoPlist.xcstrings` for privacy purpose strings
10. complete source/bundle/layout/regression verification before merge

This is considered a simple, maintainable architecture for the current requirement. A global language singleton, manual translation dictionary, `AppleLanguages` mutation, and bundle-swizzling approach were rejected.

## Remaining Verification Boundaries

These are implementation-time checks and do not block starting first-party work:

- Sparkle standard updater language under runtime override
- KeyboardShortcuts Recorder/conflict UI language under runtime override
- macOS privacy prompt chrome language
- standard `NSOpenPanel` chrome language

If those surfaces do not follow FineTune's runtime selector, record the limitation.

Separate approval is required before:

- implementing a custom Sparkle user driver
- replacing standard macOS file panels for language control
- forking/replacing KeyboardShortcuts solely for runtime language control

## Required Implementation Sequence

Use the order in `tasks/plan.md`.

The first implementation increment should contain only the localization foundation:

- `AppLanguage`
- backward-compatible settings persistence
- `zh-Hans` project registration
- `Localizable.xcstrings`
- `InfoPlist.xcstrings` scaffold
- focused localization context
- Follow System no-override behavior
- explicit region-preserving locale behavior
- focused tests

Run focused tests and a Debug build before moving to reusable-component refactoring.

## Final Gate Result

No unresolved Critical or Required architecture blocker remains for FineTune-owned UI localization.

Implementation can begin on `feature/ui-localization`.

Do not merge to `main` until the full success criteria in `SPEC-ui-localization.md` are demonstrated.