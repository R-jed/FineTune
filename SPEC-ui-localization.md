# Spec: Application UI Localization

Status: Current approved product specification as of 2026-08-23.

## Objective

Ship complete English and Simplified Chinese localization for all FineTune-owned user interface surfaces while preserving existing behavior, persisted settings compatibility, external identity values, and regional formatting preferences.

The in-app language selector exposes exactly:

- `Auto`
- `English`
- `简体中文`

FineTune-owned UI supports exactly two runtime languages: `en` and `zh-Hans`.

## Auto semantics

`Auto` is the default product behavior. For persistence compatibility it continues to use the existing `.system` enum case and raw value `system`.

Auto reads only the first preferred system UI language and maps it to a supported FineTune language:

- any Chinese language identifier -> `zh-Hans`
- every non-Chinese language identifier -> `en`
- missing or unusable preferred-language data -> `en`

Required examples:

- `zh-Hans-CN` -> `zh-Hans`
- `zh-Hant-TW` -> `zh-Hans`
- `zh_CN` -> `zh-Hans`
- `zh` -> `zh-Hans`
- `en-AU` -> `en`
- `ja-JP` -> `en`
- `fr-FR` -> `en`
- empty preferred-language list -> `en`
- `["ja-JP", "zh-Hans"]` -> `en`

Do not add Traditional Chinese UI, Japanese UI, region-specific UI variants, a CLDR-style fallback chain, or a large mapping table.

## Stable persisted identities

Keep these raw values unchanged:

- `.system` -> `system`
- `.english` -> `en`
- `.simplifiedChinese` -> `zh-Hans`

Old settings payloads without a language field must decode to `.system`, whose current product meaning is Auto.

Display labels are presentation values and must never become persistence identifiers.

## Runtime localization boundary

FineTune's in-app selector controls FineTune-owned presentation. It does not change the process-wide macOS application language.

`AppLanguage` owns the stable preference and deterministic resolution to `en` or `zh-Hans`.

`LocalizationContext` owns first-party runtime localization. It must:

- produce one concrete supported FineTune language for every selector state
- preserve the user's region for regional formatting
- provide the locale used by FineTune SwiftUI roots
- resolve deferred `LocalizedStringResource` values at final Foundation/AppKit String boundaries

Do not scatter locale construction through individual views.

Do not mutate `AppleLanguages`, swizzle `Bundle`, or force process-wide language state.

## String Catalog architecture

Use Apple's String Catalog system as the first-party source of truth:

- `FineTune/Localizable.xcstrings` for FineTune-owned UI
- `FineTune/InfoPlist.xcstrings` for localized Info.plist values

English remains the source/development language. Simplified Chinese is `zh-Hans`.

Keep existing application-target localization settings, including generated catalog symbols and Swift localization extraction.

Do not introduce a second localization dictionary or generation framework.

## Localization-aware presentation types

Preserve localization intent through reusable components and cross-layer presentation values.

Use `LocalizedStringResource` for static FineTune-owned values that are passed between layers or resolved later.

Resolve to plain `String` only when the destination API requires `String`, for example:

- AppKit window/panel messages
- accessibility announcements
- notification title/body
- other final Foundation/AppKit presentation boundaries

Do not add a generic dynamic-string localization API that accepts arbitrary `String` keys. Dynamic external content must remain outside string lookup.

## First-party coverage requirement

All FineTune-owned user-facing text must have English and Simplified Chinese presentation, including:

- Settings root and every tab
- language selector
- reset confirmation and Settings window title
- menu bar popup Output/Input modes
- normal and edit/reorder modes
- app, inactive-app, device, input, Bluetooth, and edit rows
- shared pickers, controls, help text, and tooltips
- permission banners
- EQ and built-in preset/category presentation
- AutoEQ browse/search/loading/favorites/import/error/correction/preamp states
- device inspector and detail surfaces
- FineTune-owned AppKit messages
- FineTune notifications
- FineTune-owned lower-layer user-facing errors/status
- accessibility labels/descriptions and announcements
- plural/interpolated first-party text
- locale-sensitive first-party formatted status text
- localized Info.plist privacy purpose strings

## Dynamic and technical values

Do not translate or use as localization keys:

- application names
- audio-device names
- user-created EQ preset names
- AutoEQ external profile/model/source names
- device UIDs
- PIDs
- bundle identifiers
- shortcut/persistence keys
- URL schemes
- SF Symbol names
- versions and build numbers
- standard technical identifiers and protocol tokens
- external data values

Technical units may remain standard while surrounding prose localizes.

## Detached SwiftUI roots

Any detached `NSHostingView` is a localization boundary.

The selected FineTune locale must propagate to every FineTune-owned detached root, including shared dropdown/popover hosts and FineTune HUD roots.

Do not add per-view ad hoc language branches.

## Notifications

FineTune-generated reconnect, disconnect, and default-device-change notifications must use `DeviceNotificationPresentation` with the current `AppLanguage`.

Requirements:

- dynamic device names remain verbatim
- missing disconnect fallback resolves through a localized semantic resource
- missing default output name resolves through a localized semantic resource
- notification enablement conditions remain unchanged
- notification request identifiers remain unchanged
- sound behavior remains unchanged
- notification delivery/error callbacks remain unchanged
- audio routing/default-device behavior remains unchanged

## Chinese language quality

Chinese text should read as native macOS product copy. Translation quality, action semantics, width, wrapping, and context must be reviewed visually.

Keep product and established technical names such as `FineTune`, `AutoEQ`, `EQ`, `PID`, and standard audio units where appropriate.

## Dependency and system boundaries

The first-party runtime-language guarantee ends at UI owned by FineTune.

### Sparkle 2.8.1

FineTune uses `SPUStandardUpdaterController`. Sparkle owns its standard update window and ships Simplified Chinese resources.

Sparkle standard strings are looked up from the Sparkle framework bundle. The FineTune runtime locale override does not change that bundle's native localization selection.

If native macOS application language and FineTune runtime language differ, the Sparkle window is not guaranteed to match the FineTune selector.

Replacing `SPUStandardUserDriver` with a custom updater UI is outside this feature scope because it expands update presentation, authorization, installation, and security responsibilities.

### KeyboardShortcuts 2.4.0

KeyboardShortcuts ships `zh-Hans` resources. Its package-owned Recorder and conflict-alert text is resolved from the package resource bundle.

FineTune-owned shortcut labels/descriptions follow the FineTune selector. Package-owned strings are not guaranteed to follow a conflicting FineTune runtime language.

Do not fork or replace the package solely to force runtime language behavior without separate approval.

### macOS-owned UI

FineTune owns its privacy purpose-string values and custom panel message. macOS owns privacy-prompt chrome and standard panel controls.

Do not claim the FineTune selector controls system-owned chrome.

## Automated verification requirements

Maintain focused tests for:

- stable `AppLanguage` raw values
- old settings payload compatibility
- round-trip language persistence
- deterministic Auto resolution
- first-preferred-language precedence
- explicit language resolution
- region preservation
- representative first-party resources across every major UI area
- dynamic external values remaining unchanged
- notification singular/plural and fallback behavior
- privacy purpose-string translations
- generated String Catalog integrity relevant to the implementation

Run the full existing FineTune test suite without weakening tests.

Canonical verification remains the repository CI Build and Test workflow.

## Runtime and visual verification requirements

Before merge authorization, review FineTune in an actual macOS GUI environment in English, Simplified Chinese, and Auto where relevant.

Inspect at minimum:

- Settings every tab at its target size
- popup Compact, Comfortable, and Spacious
- Output and Input
- normal and edit modes
- app/device/Bluetooth rows
- EQ flows
- AutoEQ representative states
- permission banners
- device inspector/detail states
- update status and About
- custom AppKit messages
- notification presentation

Review clipping, overlap, wrapping, truncation, untranslated first-party text, help text, and accessibility presentation.

Record Sparkle, KeyboardShortcuts, privacy-prompt, and standard-panel behavior separately as dependency/system observations.

## Source completeness guard

Classify remaining shipping Swift literals as one of:

1. localized FineTune-owned presentation
2. stable internal identifier
3. SF Symbol/API/system key
4. log/debug/developer-only text
5. user/system/external dynamic content
6. test/preview-only text

Any unexplained FineTune-owned English-only user-facing literal blocks merge.

## Success criteria

The feature can be considered ready for merge review only when:

1. Auto, English, and 简体中文 expose the approved behavior.
2. Persistence compatibility remains intact.
3. Explicit FineTune languages update active FineTune-owned UI without relaunch.
4. Auto always maps to `en` or `zh-Hans` according to the approved rule.
5. Regional formatting preferences are retained.
6. FineTune-owned user-facing text has English and Simplified Chinese coverage.
7. External identities remain unchanged.
8. FineTune AppKit and notification boundaries follow the selected FineTune language.
9. `zh-Hans`, `Localizable.xcstrings`, and `InfoPlist.xcstrings` build correctly.
10. full Build and Test pass on the final head.
11. final source review finds no unexplained first-party English-only presentation.
12. Chinese layout passes manual visual review.
13. dependency/system behavior is documented accurately without claiming runtime control FineTune does not have.
14. the final branch comparison contains no unrelated release, signing, appcast, dependency, repository-ownership, or audio-engine behavior drift.
15. PR #5 remains unmerged until explicit authorization.
