# FineTune Project Handoff

Last updated: 2026-08-23

This file is the starting context for future development sessions on this repository. Read it before changing code, then verify time-sensitive details against the repository itself.

## Project identity

FineTune is a macOS menu bar audio-control application. It controls per-app volume, app gain, application routing, output and input device levels, per-app EQ, AutoEQ headphone correction, global shortcuts, media keys, and a FineTune-owned volume HUD.

Repository: `R-jed/FineTune`

Upstream origin used to bootstrap this repository: `ronitsingh10/FineTune`

Bootstrap baseline:

- Upstream branch: `main`
- Upstream commit: `2285279d36d3f8115c1c2d4aecd904f1bdf96a51`
- Upstream tree: `cfc960ed5e09651c8876aa42c2443adffe0705a5`
- Upstream release represented by that snapshot: v1.9.0
- License: GNU GPL v3
- Preserve the original copyright notice

The initial `R-jed/FineTune` snapshot was verified at Git tree level against the upstream tree before project-specific development began. Later commits intentionally diverge from that snapshot.

## Current development state

Stable base: `main`

Active localization branch: `feature/ui-localization`

Pull request: #5, `feat: add English and Simplified Chinese UI localization`

Current branch HEAD at this handoff update: `c61a3f06c50899d5b79b314674c74e5f055e59a0`

PR #5 is open and unmerged. Do not merge it without explicit authorization.

Localization work is still in progress. Do not describe the feature as complete until the final Build/Test gate, source inventory, and manual UI review are finished.

### Current CI truth

- CI #73 at `4aa029d51cc5486c983b8f14fce45fb44ec5aaba` passed Build and Test after the centralized HUD presentation work.
- CI #77 at `9dba16c55a806299ddcda35387c70287a2871a82` failed during Build because String Catalog generated-symbol names collided for `Off` versus ` (off)` and `Volume boost` versus `Volume boost:`.
- `c61a3f06c50899d5b79b314674c74e5f055e59a0` disables symbol generation only for the two colliding catalog entries.
- CI #78 at `c61a3f06c50899d5b79b314674c74e5f055e59a0` confirms Build succeeds, but Test fails.
- CI #78 workflow run id: `32624329468`.
- CI #78 job id: `97157217040`.
- The exact failing test assertion has not yet been verified from the available log response. Do not guess the cause. A later green CI may supersede this blocker, but any remaining failure must be diagnosed from its exact test output.

## Current platform and dependency facts

- Swift language mode: Swift 6.0.
- macOS deployment target used by the app/test configuration: 15.4.
- `STRING_CATALOG_GENERATE_SYMBOLS = YES` for the application target.
- `SWIFT_EMIT_LOC_STRINGS = YES` for the application target.
- FluidMenuBarExtra 1.5.1.
- KeyboardShortcuts 2.4.0.
- Sparkle 2.8.1.

Do not upgrade dependencies as part of localization unless required and separately reviewed.

## Product language specification

FineTune UI supports exactly two languages:

- English.
- Simplified Chinese.

The language preference exposes exactly three choices:

- `Auto`.
- `English`.
- `简体中文`.

`Auto` is the default preference. Internally the existing enum case and persisted raw value `system` must be retained for backward compatibility. The product-facing wording and behavior are `Auto`; do not restore the old `Follow System` semantics.

### Auto mapping rule

Auto reads the first preferred system UI language and maps it to one of the two supported FineTune UI languages:

- Any Chinese language identifier maps to `zh-Hans`.
- Every non-Chinese language maps to `en`.
- Missing or unusable preferred-language data maps to `en`.

Required examples:

- `zh-Hans-CN` -> `zh-Hans`.
- `zh-Hant-TW` -> `zh-Hans`.
- `zh_CN` -> `zh-Hans`.
- `en-AU` -> `en`.
- `ja-JP` -> `en`.
- `fr-FR` -> `en`.
- Empty preferred-language list -> `en`.

Do not add Traditional Chinese UI, Japanese UI, region-specific UI variants, a CLDR-style fallback chain, or a large language mapping table. Keep the resolver deterministic and small.

### Runtime localization boundary

`AppLanguage` owns the stable persisted identity and the mapping to a supported FineTune UI language.

`LocalizationContext` is the central runtime localization boundary for FineTune-owned UI and String-only AppKit boundaries. Under the current product specification every selected mode, including Auto, must resolve to a concrete supported FineTune locale: `en` or `zh-Hans`. Arbitrary system languages such as French or Japanese must not leak through to FineTune-owned UI.

Keep dynamic external values verbatim. This includes application names, device names, user preset names, AutoEQ profile names, UIDs, PIDs, bundle identifiers, version/build values, URLs, and other external identity values.

Use `LocalizedStringResource` through presentation layers and resolve to `String` only at final String-only boundaries.

Keep one first-party UI catalog: `FineTune/Localizable.xcstrings`. Do not create a second localization framework or hard-code Chinese branches in Swift UI code.

## Localization implementation completed so far

Earlier phases established Settings persistence, String Catalogs, reusable presentation resources, Settings localization, menu bar popup localization, EQ/AutoEQ/device-detail localization, Info.plist localization, and AppKit localization boundaries.

Phase 7 completeness work added or refined the following:

- `c455da0dfce401ca6c09d5df420d1e573f8deefd`: propagate locale into detached popovers through `PopoverHost`.
- `550649ee4e5b19728613a7abaa19125fd12876cc`: type Bluetooth connection errors so presentation can localize them safely.
- `e37f721befda4e14a79791644be1387897ea09d3`: preserve localizable mute help text as `LocalizedStringResource`.
- `c5406797077eeffd73acc051f860e4b0fd7a8a15`: propagate locale into Tahoe, Classic, and per-app HUD hosting roots.
- `7db0217...` and `31b1176564721391d9a9f20d9d2d82597ba2d0c0`: add notification presentation helpers and fallback tests.
- `7dfd1d07db54d6d8c33372157eb72ff501145325`: preserve AutoEQ dynamic profile names while localizing the static `(off)` suffix.
- `4aa029d51cc5486c983b8f14fce45fb44ec5aaba`: centralize FineTune HUD localized presentation. CI #73 passed Build and Test for this state.
- `016c9bb16624904d3189f3504dbb890281a6503f`: separate dynamic accessibility values from localizable static labels.
- `c980d68ca1874f20a10902fd613b236daff6a6a6`: complete the Phase 7 String Catalog additions then known.
- `2c58ea85e21f38e21dab9f1f699928ba535ff661`: add Simplified Chinese presentation regression tests.
- `9dba16c55a806299ddcda35387c70287a2871a82`: add Phase 7 catalog coverage regression tests.
- `c61a3f06c50899d5b79b314674c74e5f055e59a0`: resolve generated-symbol collisions by disabling symbol generation only on the two colliding source entries.

`tasks/phase7-localization-inventory.md` is the working inventory for this completeness pass.

## Detached SwiftUI roots

Detached `NSHostingView` roots were a real runtime localization gap. Current fixes explicitly propagate the FineTune locale into:

- dropdown/popover hosts through `PopoverHost`;
- Tahoe HUD;
- Classic HUD;
- per-app HUD roots.

Keep this architecture when changing locale resolution. Do not reintroduce root-specific ad hoc language logic.

## Current immediate work

### 1. Replace old Follow System behavior with Auto

Current `AppLanguage.system` still displays `Follow System` and returns no language identifier. Current `LocalizationContext` therefore allows the host locale to pass through. This conflicts with the approved product specification.

Required implementation:

- Keep `.system` and raw persisted value `system`.
- Display `Auto` in English and `自动` in Simplified Chinese.
- Resolve Auto from `Locale.preferredLanguages` or an injected preferred-language list for tests.
- Map any first preferred language beginning with Chinese language identifier `zh` to `zh-Hans`.
- Map everything else, including an empty list, to `en`.
- Explicit English always resolves to `en`.
- Explicit Simplified Chinese always resolves to `zh-Hans`.
- Keep the resolver simple and deterministic.

Replace old tests that assert Follow System preserves arbitrary locale/region. New tests must cover the mapping examples above and confirm Auto always produces one of the two supported UI locales.

### 2. Update String Catalog wording

`FineTune/Localizable.xcstrings` still contains `Follow System`. Replace the product-facing entry with `Auto` and provide Simplified Chinese value `自动`.

Preserve the prior `generatesSymbol: false` metadata for ` (off)` and `Volume boost:`.

Because the catalog is large, use a detached candidate commit and inspect the exact diff before moving the feature branch.

### 3. Restore green Build/Test

After Auto implementation, run the repository CI path. Do not treat Build success alone as completion. If Test fails, inspect the exact test name and assertion before changing production code.

Canonical CI commands:

```bash
xcodebuild build \
  -project FineTune.xcodeproj \
  -scheme FineTune \
  -configuration Debug \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO
```

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

### 4. Connect localized notification presentation to AudioEngine

`DeviceNotificationPresentation` exists and is tested, but `FineTune/Audio/Engine/AudioEngine.swift` still constructs the three device notification titles/bodies directly in English.

Required production integration after the Auto work is controlled:

- `showReconnectNotification` uses `DeviceNotificationPresentation`.
- `showDisconnectNotification` accepts an optional fallback device name rather than constructing user-facing `none` at the call site.
- `showDefaultChangedNotification` accepts an optional device name rather than constructing user-facing `Default Output` at the call site.
- Presentation uses `settingsManager.appSettings.language`.
- Preserve dynamic device names verbatim.
- Preserve `UNNotificationRequest` identifiers.
- Preserve `content.sound = nil`.
- Preserve the existing notification delivery calls.

`AudioEngine.swift` is close to 100 KB. Do not use an unsafe blind whole-file replacement. Fetch the exact current blob, construct a candidate from that blob, compare the candidate diff, and fast-forward only if the diff contains the intended notification regions.

## Final verification gates before merge authorization

The feature is not complete until all relevant gates pass:

1. Full Build succeeds.
2. Full unit Test succeeds.
3. Auto mapping tests cover Chinese, English, unsupported system languages, and empty preferred-language data.
4. Explicit English and Simplified Chinese behavior remains correct.
5. `Localizable.xcstrings` retains existing keys and intended Phase 7 translations without unrelated churn.
6. Production notification call sites use localized presentation helpers.
7. Phase 7 source inventory is re-run and every remaining English literal is classified correctly.
8. Dynamic external data remains verbatim.
9. FineTune-owned UI is manually smoke-tested in Auto, English, and Simplified Chinese when a macOS runtime is available.
10. Dependency-owned and system-owned UI is reviewed separately. Do not claim Sparkle, KeyboardShortcuts, macOS privacy prompts, or standard system panel controls follow FineTune runtime language until observed.
11. Compare the final feature branch with `main` for unrelated drift.
12. PR #5 remains unmerged until explicit authorization.

## Repository areas to treat carefully

- `FineTune/Audio/Engine/AudioEngine.swift`: large core orchestration file, high blast radius.
- `FineTune/Localizable.xcstrings`: large generated/edited catalog, verify exact diffs.
- `FineTune/Views/MenuBarPopupView.swift`: large central UI surface.
- `FineTune/Utilities/LocalizationContext.swift`: central runtime language policy.
- `FineTune/Settings/Types/AppLanguage.swift`: persisted language identity and supported-language resolver.
- `.github/workflows/ci.yml`: canonical Build/Test behavior.

## Development rules for future sessions

Before implementation:

1. Read this file, the active localization inventory/specification, relevant source files, and tests.
2. Re-fetch the feature branch head before writing.
3. Establish the exact behavior and success criteria.
4. Verify framework-specific assumptions against source or official documentation when needed.
5. Prefer the smallest change that solves the full requirement cleanly.

During implementation:

- Keep `main` usable.
- Make focused commits with one logical concern each.
- Preserve persisted-data compatibility unless a migration is explicitly designed and tested.
- Avoid drive-by refactors.
- Keep dynamic external identity values out of localization lookup.
- Re-read branch HEAD before each write.
- Use fast-forward ref updates only.
- For large or sensitive files, create and compare a detached candidate before updating the branch.
- If concurrent commits appear, inspect them before writing and never overwrite them blindly.

Before claiming completion:

- Verify Build and Test.
- Inspect failing logs rather than guessing.
- Review behavior and source inventory.
- Compare against `main` for unrelated changes.
- Record the final verified state here.
- Keep PR #5 unmerged until explicit merge authorization is given.
