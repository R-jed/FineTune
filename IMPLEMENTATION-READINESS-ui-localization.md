# Implementation Readiness Review: UI Localization

Date: 2026-08-23

Status: Historical planning gate, updated with the current approved language semantics.

This file records why the localization architecture was approved. Current product behavior is defined by `SPEC-ui-localization.md`, and current implementation state is recorded in `HANDOFF.md`.

## Decision

APPROVED architecture for FineTune-owned UI localization.

The first-party implementation has since progressed beyond this planning gate and passed automated Build/Test verification through CI #83 at `b556b5019b8dc21931416094b0a5c5dc0d30647d`.

## Product-semantics update

The original readiness review used the label Follow System. That product behavior was later superseded by `Auto`.

Current approved selector:

- `Auto`
- `English`
- `简体中文`

For backward compatibility Auto retains the existing `.system` enum identity and raw persisted value `system`.

Auto deterministically maps the first preferred system UI language to a supported FineTune UI language:

- Chinese -> `zh-Hans`
- every other case -> `en`
- missing/unusable preferred language -> `en`

Only the first preferred language controls Auto.

Do not use the old no-override Follow System behavior as implementation guidance.

## Architecture that remains approved

The following decisions remain valid:

1. Keep stable persisted language identifiers.
2. Use Apple's String Catalogs as the first-party source of truth.
3. Keep one focused runtime localization context.
4. Preserve the user's region when changing FineTune UI language.
5. Preserve `LocalizedStringResource` through reusable presentation boundaries.
6. Resolve to plain `String` only at final String-only APIs.
7. Keep dynamic app/device/profile/user content out of localization lookup.
8. Localize Info.plist purpose strings through `InfoPlist.xcstrings`.
9. Propagate the selected locale into detached FineTune SwiftUI hosting roots.
10. Avoid process-wide language mutation, bundle swizzling, and private localization forcing.

## Dependency boundaries

Pinned versions remain:

- Sparkle 2.8.1
- KeyboardShortcuts 2.4.0

Source review now confirms the earlier risk boundary:

- Sparkle standard updater text is resolved from the Sparkle framework bundle.
- KeyboardShortcuts Recorder/conflict text is resolved from the package resource bundle.
- both dependencies ship Chinese resources
- FineTune's custom runtime locale does not guarantee control of those dependency bundle lookups when native application language differs

The original scope decision still stands:

- no custom Sparkle user driver without separate approval
- no KeyboardShortcuts fork/replacement solely for runtime-language forcing
- no `AppleLanguages` mutation or bundle swizzling

macOS privacy-prompt chrome and standard panel controls remain system-owned surfaces.

## Verification progress since readiness approval

Completed after this planning gate:

- localization foundation and persistence
- Auto language resolver
- first-party Settings and popup localization
- shared component boundary fixes
- EQ/AutoEQ/device presentation localization
- detached popover/HUD locale propagation
- privacy-purpose localization
- typed Bluetooth error presentation
- FineTune notification presentation and AudioEngine integration
- Chinese regression tests
- String Catalog collision fixes
- main-branch drift review and adversarial source spot checks

CI #83 passed Build and Test after the final production AudioEngine notification integration.

## Remaining gate

Architecture readiness is no longer the blocker.

Remaining work before merge authorization is runtime evidence:

- macOS visual smoke review in English, Simplified Chinese, and Auto cases
- clipping/wrapping/translation-quality review
- live observation of dependency/system-owned surfaces where practical
- fresh green CI on the final documentation-synchronized head
- final branch comparison immediately before merge review

PR #5 must stay unmerged until explicit authorization.
