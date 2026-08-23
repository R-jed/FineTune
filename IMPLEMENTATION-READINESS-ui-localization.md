# Implementation Readiness Review: UI Localization

Date: 2026-08-24

Status: Historical planning gate, reconciled with the current approved language semantics and verification state.

This file records why the localization architecture was approved. Current product behavior is defined by `SPEC-ui-localization.md`, and current implementation state is recorded in `HANDOFF.md`.

## Decision

APPROVED architecture for FineTune-owned UI localization.

The first-party implementation has progressed beyond this planning gate. The verified production-code head `ad4e09077e708de0989b4e5ceb9bab5d8e22c03e` passed CI #87, and the documentation-synchronized head `0b94ebe5343f93a564fc3a54898edb45591ccada` passed CI #88.

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

Source review confirms the boundary:

- Sparkle standard updater text is resolved from the Sparkle framework bundle.
- KeyboardShortcuts Recorder/conflict text is resolved from the package resource bundle.
- both dependencies ship Chinese resources.
- FineTune's custom runtime locale does not guarantee control of those dependency bundle lookups when native application language differs.

The original scope decision still stands:

- no custom Sparkle user driver without separate approval.
- no KeyboardShortcuts fork/replacement solely for runtime-language forcing.
- no `AppleLanguages` mutation or bundle swizzling.

macOS privacy-prompt chrome and standard panel controls remain system-owned surfaces.

## Verification progress since readiness approval

Completed after this planning gate:

- localization foundation and persistence.
- Auto language resolver and first-preferred-language tests.
- first-party Settings and popup localization.
- shared component boundary fixes.
- EQ/AutoEQ/device presentation localization.
- detached popover/HUD locale propagation.
- privacy-purpose localization.
- typed Bluetooth error presentation.
- FineTune notification presentation and AudioEngine integration.
- Chinese regression tests.
- String Catalog collision fixes.
- device-icon category/search/accessibility localization.
- typed resource-boundary repair after CI #85 exposed an invalid localization overload.
- AutoEQ catalog-failure presentation repair so English fetch diagnostics are not rendered verbatim in Chinese UI.
- full-repository drift review and high-risk unchanged presentation review.

Verified production-code head:

`ad4e09077e708de0989b4e5ceb9bab5d8e22c03e`

CI #87 passed Build, Test, test-result upload, and the complete job.

Verified documentation-synchronized head before this readiness refresh:

`0b94ebe5343f93a564fc3a54898edb45591ccada`

CI #88 also passed Build, Test, test-result upload, and the complete job.

At that head, comparison against `main` was ahead 89, behind 0, with 67 changed files and no dependency, release, signing, entitlement, or appcast drift observed.

## Remaining gate

Architecture readiness and current automated/source verification are no longer blockers.

Remaining work before merge authorization is runtime evidence and final-head confirmation:

- macOS visual smoke review in English, Simplified Chinese, and Auto cases.
- clipping/wrapping/translation-quality review across the required Settings and popup states.
- representative runtime checks for Output/Input, edit, EQ, AutoEQ, permission, Bluetooth, device-detail, notifications, help, and accessibility.
- live observation of dependency/system-owned surfaces where practical.
- if the local macOS review produces code changes, fresh Build and Test on that exact resulting head.
- final branch comparison immediately before merge review.

PR #5 must stay unmerged until explicit authorization.
