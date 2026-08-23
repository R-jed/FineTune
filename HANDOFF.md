# FineTune Project Handoff

Last updated: 2026-08-23

Read this file before changing code. Verify time-sensitive state against the repository before every write.

## Project identity

FineTune is a macOS menu bar audio-control application. It controls per-app volume and gain, application routing, output and input device levels, per-app EQ, AutoEQ headphone correction, global shortcuts, media keys, and FineTune-owned volume HUDs.

Repository: `R-jed/FineTune`

Upstream bootstrap source: `ronitsingh10/FineTune`

Bootstrap commit: `2285279d36d3f8115c1c2d4aecd904f1bdf96a51`

Bootstrap tree: `cfc960ed5e09651c8876aa42c2443adffe0705a5`

License: GNU GPL v3. Preserve the original copyright notice.

## Current development state

Stable base: `main`

Active branch: `feature/ui-localization`

Pull request: #5, `feat: add English and Simplified Chinese UI localization`

Verified implementation head before this documentation update: `07b34f766de0c50b6a5a244771eaf066083e1ad6`

PR #5 is open and unmerged. Do not merge it without explicit authorization.

Localization work is still in progress because production device notifications in `AudioEngine.swift`, the final source inventory, and manual runtime smoke tests remain.

## Current CI truth

- CI #73 at `4aa029d51cc5486c983b8f14fce45fb44ec5aaba` passed Build and Test after centralized HUD localization.
- CI #77 at `9dba16c55a806299ddcda35387c70287a2871a82` failed during String Catalog generated-symbol generation because `Off` collided with ` (off)` and `Volume boost` collided with `Volume boost:`.
- `c61a3f06c50899d5b79b314674c74e5f055e59a0` disables symbol generation only for the two colliding manual entries.
- CI #78 and the docs-only CI #79 both reached a Test failure. This proved the failure predated the Auto-language implementation.
- The CI #79 uploaded `.xcresult` artifact was inspected. The exact root cause was a test-target compile error in `FineTuneTests/LocalizedPresentationTests.swift`: `phase7CompletenessResources()` declared its source values as dynamic `String`, then passed them to `LocalizationContext.localized(_:)`, which intentionally accepts `LocalizedStringResource`.
- `07b34f766de0c50b6a5a244771eaf066083e1ad6` fixes that test boundary by using `LocalizedStringResource` without adding a production `String` localization overload.
- CI #81 at `07b34f766de0c50b6a5a244771eaf066083e1ad6` passed Build, Test, test-result upload, and the complete job.

CI #81 is the current verified automated baseline.

## Platform and dependency facts

- Swift language mode: Swift 6.0.
- macOS deployment target: 15.4.
- App target `STRING_CATALOG_GENERATE_SYMBOLS = YES`.
- App target `SWIFT_EMIT_LOC_STRINGS = YES`.
- FluidMenuBarExtra 1.5.1.
- KeyboardShortcuts 2.4.0.
- Sparkle 2.8.1.

Do not change dependencies as part of localization unless required and separately reviewed.

## Product language specification

FineTune UI supports exactly two languages:

- English.
- Simplified Chinese.

The language preference exposes exactly three choices:

- `Auto`.
- `English`.
- `简体中文`.

`Auto` is the default. Internally the existing enum case `.system` and persisted raw value `system` are retained for backward compatibility.

Auto reads the first preferred system UI language and maps it to one of FineTune's two UI languages:

- Any Chinese language identifier maps to `zh-Hans`.
- Every non-Chinese language maps to `en`.
- Missing or unusable preferred-language data maps to `en`.
- Only the first preferred language controls the result.

Verified examples include:

- `zh-Hans-CN` -> `zh-Hans`.
- `zh-Hant-TW` -> `zh-Hans`.
- `zh_CN` -> `zh-Hans`.
- `zh` -> `zh-Hans`.
- `en-AU` -> `en`.
- `ja-JP` -> `en`.
- `fr-FR` -> `en`.
- empty list -> `en`.
- `["ja-JP", "zh-Hans"]` -> `en`.

Do not add Traditional Chinese UI, Japanese UI, region-specific UI variants, a CLDR-style fallback chain, or a large language mapping table.

## Auto implementation now verified

`AppLanguage.system` is still the persisted compatibility identity, while its display resource is now `Auto`.

`AppLanguage.resolvedLanguageIdentifier(preferredLanguages:)` deterministically resolves every preference to `en` or `zh-Hans`.

`LocalizationContext` now always produces a concrete FineTune locale. It preserves the user's region for regional formatting while forcing FineTune-owned UI language to one of the two supported languages.

The SwiftUI root locale modifier now takes a concrete `Locale`. Detached popover and HUD hosting roots continue to receive the same resolved locale.

The main String Catalog already contained the `Auto` key with Simplified Chinese value `自动`, so the language-selector change required no large catalog rewrite. The old `Follow System` catalog entry is currently unused and can be reviewed during final catalog cleanup.

Persistence compatibility is retained:

- `.system` raw value remains `system`.
- `.english` remains `en`.
- `.simplifiedChinese` remains `zh-Hans`.
- legacy `AppSettings` payloads without a language still decode to `.system`, which now means Auto.

## Localization implementation completed so far

Earlier phases established settings persistence, String Catalogs, Settings localization, menu bar popup localization, EQ and AutoEQ localization, device-detail localization, Info.plist localization, and AppKit String boundaries.

Important Phase 7 work:

- `c455da0dfce401ca6c09d5df420d1e573f8deefd`: propagate locale into detached popovers through `PopoverHost`.
- `550649ee4e5b19728613a7abaa19125fd12876cc`: replace Bluetooth user-facing string errors with typed connection errors.
- `e37f721befda4e14a79791644be1387897ea09d3`: keep mute help text as `LocalizedStringResource`.
- `c5406797077eeffd73acc051f860e4b0fd7a8a15`: propagate locale into Tahoe, Classic, and per-app HUD hosting roots.
- `31b1176564721391d9a9f20d9d2d82597ba2d0c0`: notification presentation fallback tests.
- `7dfd1d07db54d6d8c33372157eb72ff501145325`: keep AutoEQ profile names verbatim while localizing the static `(off)` suffix.
- `4aa029d51cc5486c983b8f14fce45fb44ec5aaba`: centralize FineTune HUD localized presentation.
- `016c9bb16624904d3189f3504dbb890281a6503f`: separate dynamic accessibility values from localizable static labels.
- `c980d68ca1874f20a10902fd613b236daff6a6a6`: add Phase 7 String Catalog coverage.
- `2c58ea85e21f38e21dab9f1f699928ba535ff661`: add Simplified Chinese presentation regression tests.
- `9dba16c55a806299ddcda35387c70287a2871a82`: add Phase 7 catalog completeness tests.
- `c61a3f06c50899d5b79b314674c74e5f055e59a0`: resolve known generated-symbol collisions.
- `6249a458ee40ed11ea936c4d788deaccc9ef8d34`: implement Auto UI-language resolution and replace old Follow System runtime semantics.
- `07b34f766de0c50b6a5a244771eaf066083e1ad6`: preserve `LocalizedStringResource` typing in the Phase 7 completeness test. CI #81 passed fully.

`tasks/phase7-localization-inventory.md` remains the working completeness inventory.

## Localization boundaries to preserve

FineTune-owned static UI text should stay localizable.

Dynamic external identity values stay verbatim, including application names, device names, user preset names, AutoEQ profile names, UIDs, PIDs, bundle identifiers, versions, build numbers, and URLs.

Use `LocalizedStringResource` through SwiftUI and reusable presentation code. Resolve to `String` only at final String-only boundaries such as AppKit and notification content.

Do not add a generic `localized(_ key: String)` convenience overload. The CI #79 failure demonstrated why keeping the typed boundary matters.

Keep `FineTune/Localizable.xcstrings` as the single first-party UI catalog. `FineTune/InfoPlist.xcstrings` remains dedicated to localized Info.plist purpose strings.

Detached `NSHostingView` roots are explicit locale boundaries. Current fixes cover dropdown/popover hosting, Tahoe HUD, Classic HUD, and per-app HUD.

## Immediate remaining production blocker

`FineTune/Audio/Engine/AudioEngine.swift` still constructs three FineTune-owned device notifications in English.

Current exact blob SHA at the verified head: `cd3d07e6ac0f34c17b447b8b2920e51827dc2903`.

Required minimal integration:

1. In device disconnect handling, stop constructing the user-facing fallback string `none` at the call site. Pass `fallbackDevice?.name` as `String?`.
2. `showDisconnectNotification` should accept `fallbackName: String?` and build presentation through `DeviceNotificationPresentation.disconnected(...)` using `settingsManager.appSettings.language`.
3. `showReconnectNotification` should build presentation through `DeviceNotificationPresentation.reconnected(...)` using the current app language.
4. In default-device handling, preserve the device name as optional for presentation. Logging may use `newDeviceName ?? newDefaultUID`.
5. `showDefaultChangedNotification` should accept `String?` and use `DeviceNotificationPresentation.defaultChanged(...)`.
6. Assign `content.title` and `content.body` from the presentation helper.
7. Preserve notification enablement conditions, `content.sound = nil`, request identifiers, callbacks, and `UNUserNotificationCenter.current().add` behavior.

Existing presentation resources and tests already cover English and Simplified Chinese copy, including semantic fallbacks `notification.noFallbackDevice` and `notification.defaultOutputFallback`.

`AudioEngine.swift` is close to 100 KB. The repository connector writes existing files as whole-file replacements. Do not blind-write this file. Reconstruct from the exact current blob, compare a detached candidate, and move the branch only when the diff is limited to the intended notification regions.

The file has been re-read in line ranges against the current blob during the session. No production AudioEngine write has been made yet after CI #81.

## Final verification gates before merge authorization

The localization feature remains incomplete until all relevant gates pass:

1. Production device notifications use `DeviceNotificationPresentation`.
2. Full Build succeeds after the notification integration.
3. Full unit Test succeeds after the notification integration.
4. Phase 7 source inventory is re-run and all remaining English literals are classified.
5. Dynamic external identity values remain verbatim.
6. English, Simplified Chinese, and Auto are manually smoke-tested when a macOS UI runtime is available.
7. Dependency-owned and system-owned UI is reviewed separately. Do not claim Sparkle, KeyboardShortcuts, macOS privacy prompts, or standard AppKit controls follow FineTune's runtime language until observed.
8. Compare the final feature branch with `main` for unrelated drift.
9. Perform a final adversarial review of translation quality, locale propagation, persistence compatibility, and generated String Catalog behavior.
10. PR #5 stays unmerged until explicit authorization.

## Repository areas to treat carefully

- `FineTune/Audio/Engine/AudioEngine.swift`: large core orchestration file, high blast radius.
- `FineTune/Localizable.xcstrings`: large String Catalog, verify exact diffs.
- `FineTune/Views/MenuBarPopupView.swift`: large central UI surface.
- `FineTune/Utilities/LocalizationContext.swift`: central runtime language policy.
- `FineTune/Settings/Types/AppLanguage.swift`: persisted language identity and resolver.
- `.github/workflows/ci.yml`: canonical Build/Test behavior.

## Development rules for future sessions

Before every implementation step:

1. Read this file and the relevant inventory/specification.
2. Re-fetch the branch head and exact file blobs before writing.
3. Establish the behavior and success criteria.
4. Use official framework documentation when a framework assumption matters.
5. Prefer the smallest change that solves the full requirement.

During implementation:

- Keep `main` usable.
- Use focused commits.
- Preserve persisted-data compatibility unless a migration is explicitly designed and tested.
- Avoid drive-by refactors.
- Keep external identity values out of localization lookup.
- For large or sensitive files, construct and compare a detached candidate before moving the branch.
- Do not overwrite concurrent work.

Before claiming completion:

- Verify Build and Test.
- Diagnose failures from exact logs or `.xcresult` evidence.
- Re-run the source inventory.
- Compare against `main` for unrelated changes.
- Record the verified state here.
- Keep PR #5 unmerged until explicit merge authorization.
