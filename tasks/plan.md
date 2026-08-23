# UI Localization Implementation Plan

Status: First-party implementation is automated-test complete as of 2026-08-23. Remaining gates are macOS GUI verification, dependency/system observation, and final merge review.

`SPEC-ui-localization.md` is authoritative.

## Goal

Deliver a FineTune-owned UI language preference with `Auto`, `English`, and `简体中文`, complete English/Simplified Chinese first-party resources, stable persistence, preserved regional formatting, and no unrelated behavior changes.

## Approved language behavior

- `Auto` persists as the existing `system` raw value.
- Auto maps the first preferred system UI language to `zh-Hans` for Chinese and `en` for every other case.
- Explicit English resolves to `en`.
- Explicit Simplified Chinese resolves to `zh-Hans`.
- Only FineTune-owned UI is controlled by this runtime language selector.

Do not restore the earlier Follow System semantics.

## Completed implementation sequence

### 1. Foundation

Completed:

- stable `AppLanguage` persistence
- backward-compatible settings decoding
- `zh-Hans` project localization registration
- `Localizable.xcstrings`
- `InfoPlist.xcstrings`
- centralized `LocalizationContext`
- region-preserving presentation locale
- deterministic Auto resolver and tests

### 2. Reusable localization boundaries

Completed:

- shared Settings presentation types preserve localization intent
- enum/action display values localize independently of raw identifiers
- dynamic app/device/profile/user names remain plain dynamic values
- AppKit String-only boundaries resolve deferred resources at presentation time

### 3. Settings

Completed first-party localization across General, Audio, Shortcuts, Updates, About, Settings window title, reset confirmation, helper components, and relevant accessibility/help copy.

The language selector exposes exactly `Auto`, `English`, and `简体中文`.

### 4. Menu bar and shared rows

Completed first-party localization for popup shell, Output/Input presentation, edit/reorder modes, app/device rows, shared controls, permission presentation, fallback text, help, and accessibility resources.

### 5. EQ, AutoEQ, and device detail

Completed first-party localization while keeping user preset names, AutoEQ external names, device facts, UIDs/PIDs, and technical units stable.

### 6. AppKit, notifications, errors, and privacy metadata

Completed:

- FineTune-owned AppKit messages
- Bluetooth user-facing error presentation
- localized privacy purpose strings
- FineTune reconnect/disconnect/default-device notifications through `DeviceNotificationPresentation`

The AudioEngine notification integration is `b556b5019b8dc21931416094b0a5c5dc0d30647d` and passed CI #83.

### 7. Completeness and adversarial review

Completed automated/source-review work:

- Phase 7 inventory
- Chinese presentation regression tests
- catalog completeness tests for known Phase 7 resources
- main-vs-feature comparison
- focused adversarial review of sensitive presentation changes
- exact diff review of AudioEngine notification integration
- no observed release, signing, appcast, or dependency-upgrade drift

## Dependency/system boundary verdict

### Sparkle 2.8.1

Sparkle ships Simplified Chinese resources. FineTune uses its standard updater UI. Sparkle resolves standard strings from its framework bundle, so FineTune's runtime locale override does not guarantee control of updater language when native macOS application language differs.

A custom Sparkle user driver is outside scope.

### KeyboardShortcuts 2.4.0

KeyboardShortcuts ships `zh-Hans` resources. Its Recorder and conflict-alert strings use the package resource bundle. FineTune-owned shortcut labels follow FineTune's runtime language; dependency-owned Recorder strings are not guaranteed to do so under a mismatched native app language.

Forking/replacing the package solely for language forcing is outside scope.

### macOS-owned UI

FineTune controls its purpose strings and custom messages. macOS controls privacy-prompt chrome and standard panel controls.

## Current automated verification

CI #83 at `b556b5019b8dc21931416094b0a5c5dc0d30647d` passed:

- Build
- Test
- test-result upload
- complete workflow job

Run id: `32638398426`

Job id: `97191501640`

Any later documentation or code head must receive a fresh successful CI before being called the final green head.

## Remaining execution plan

### A. Synchronize project records

Update:

- `SPEC-ui-localization.md`
- `TECHNICAL-BACKGROUND-ui-localization.md`
- `IMPLEMENTATION-READINESS-ui-localization.md`
- `tasks/phase7-localization-inventory.md`
- `tasks/todo.md`
- `HANDOFF.md`
- PR #5 description

All records must use Auto semantics and current CI truth.

### B. Verify the final documentation head

After the docs-only commit:

1. compare it against the current production-code head
2. require docs-only differences
3. wait for a fresh CI run
4. require Build and Test green

### C. macOS GUI smoke matrix

When a suitable macOS runtime is available, verify:

- explicit English
- explicit Simplified Chinese
- Auto with Chinese first preferred language
- Auto with non-Chinese first preferred language

Review Settings, all popup sizes, Output/Input, edit states, EQ, AutoEQ representative states, device details, permission presentation, notifications, help, and accessibility presentation.

Check clipping, overlap, wrapping, truncation, and translation quality.

### D. Observe dependency/system surfaces

Record actual language used by:

- Sparkle standard updater
- KeyboardShortcuts Recorder and conflict alerts
- privacy-prompt chrome
- standard file-panel controls

Do not reinterpret these dependency/system surfaces as FineTune-owned failures unless the approved scope changes.

### E. Final merge review

Before merge authorization:

1. re-fetch `main` and PR head
2. compare final branch against `main`
3. confirm no unrelated release/signing/appcast/dependency/audio behavior drift
4. confirm final CI green
5. confirm manual GUI review evidence if available
6. update handoff with final truth
7. keep PR #5 unmerged until explicit authorization

## Engineering constraints

- no `AppleLanguages` mutation
- no bundle swizzling
- no custom translation dictionary
- no dynamic `String` localization convenience API
- no dependency fork solely for runtime language forcing
- no custom Sparkle user driver without separate approval
- no changes to persisted identifiers for presentation reasons
- no drive-by audio/routing/hotkey refactors

Use the smallest change that satisfies the approved first-party localization requirement.
