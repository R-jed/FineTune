# FineTune Project Handoff

Last updated: 2026-08-23

Read this file before changing code. Re-fetch the branch head and any sensitive file before every write.

## Project identity

FineTune is a macOS menu bar audio-control application. It controls per-app volume and gain, application routing, output and input device levels, EQ, AutoEQ, global shortcuts, media keys, and FineTune-owned volume HUDs.

Repository: `R-jed/FineTune`

Upstream bootstrap source: `ronitsingh10/FineTune`

Bootstrap commit: `2285279d36d3f8115c1c2d4aecd904f1bdf96a51`

License: GNU GPL v3. Preserve the original copyright notice.

## Active development state

Stable base: `main`

Active branch: `feature/ui-localization`

Pull request: #5, `feat: add English and Simplified Chinese UI localization`

Verified production implementation head before this documentation refresh:

`b556b5019b8dc21931416094b0a5c5dc0d30647d`

PR #5 is open and unmerged. Do not merge it without explicit authorization.

## Product language specification

FineTune-owned UI supports exactly two languages:

- English
- Simplified Chinese

The in-app selector exposes exactly:

- `Auto`
- `English`
- `简体中文`

The persisted enum identities remain stable:

- `.system` -> `system`
- `.english` -> `en`
- `.simplifiedChinese` -> `zh-Hans`

`Auto` is the product behavior of the persisted `.system` case. It reads only the first preferred system UI language and maps it to one of FineTune's two supported UI languages:

- any Chinese identifier -> `zh-Hans`
- every non-Chinese identifier -> `en`
- missing or unusable preferred-language data -> `en`

Verified examples include `zh-Hans-CN`, `zh-Hant-TW`, `zh_CN`, and `zh` mapping to `zh-Hans`; `en-AU`, `ja-JP`, and `fr-FR` mapping to `en`; an empty list mapping to `en`; and `["ja-JP", "zh-Hans"]` mapping to `en` because only the first item controls Auto.

Do not reintroduce the earlier Follow System runtime semantics. Do not add Traditional Chinese UI, Japanese UI, region-specific UI variants, or a large language fallback table.

## Localization architecture

`AppLanguage` owns stable persistence identity and the deterministic mapping to `en` or `zh-Hans`.

`LocalizationContext` is the first-party runtime localization boundary. It forces FineTune-owned presentation to one supported language while retaining the user's region for regional formatting.

Use `LocalizedStringResource` while text crosses SwiftUI or presentation layers. Resolve to plain `String` only at final String-only boundaries such as AppKit APIs and `UNMutableNotificationContent`.

Do not add a generic `localized(_ key: String)` production overload. CI #79 exposed why keeping the typed resource boundary matters.

Keep dynamic external identity values verbatim, including application names, audio-device names, user EQ preset names, AutoEQ profile/model/source names, UIDs, PIDs, bundle identifiers, versions, build numbers, URLs, and technical identifiers.

Keep one first-party UI catalog: `FineTune/Localizable.xcstrings`. `FineTune/InfoPlist.xcstrings` is dedicated to localized Info.plist values.

Detached `NSHostingView` roots are explicit locale boundaries. Current fixes cover shared popovers, Tahoe HUD, Classic HUD, and per-app HUD roots.

## Verified implementation state

Important completed work includes:

- locale propagation into detached popovers and HUD hosting roots
- typed Bluetooth connection errors with localized presentation
- localization-safe mute/help resources
- centralized HUD presentation
- dynamic accessibility values separated from static localizable labels
- AutoEQ profile names kept verbatim while FineTune-owned state copy localizes
- Phase 7 String Catalog coverage and Chinese regression tests
- generated-symbol collision handling for the two known manual catalog entries
- deterministic Auto language resolution and persistence compatibility
- FineTune device reconnect, disconnect, and default-device-change notifications connected to `DeviceNotificationPresentation`

The notification integration is commit:

`b556b5019b8dc21931416094b0a5c5dc0d30647d`

It changed only `FineTune/Audio/Engine/AudioEngine.swift` relative to its parent, with 27 additions and 11 deletions. The change preserves notification enablement, notification identifiers, `content.sound = nil`, delivery callbacks, error logging, device routing, and default-device behavior. Device names remain verbatim. Missing fallback names are localized inside `DeviceNotificationPresentation`.

## CI truth

Key history:

- CI #73 passed after centralized HUD presentation.
- CI #77 found generated String Catalog symbol collisions.
- CI #78 and #79 reached the same test-target compile failure.
- The CI #79 `.xcresult` proved the exact cause was a test tuple typed as dynamic `String` and passed into a `LocalizedStringResource` boundary.
- `07b34f766de0c50b6a5a244771eaf066083e1ad6` fixed that test typing without weakening production localization APIs. CI #81 passed fully.
- CI #82 at `6a3a62c7d2ce91f394e4c5b055f7fecd0daf9268` passed fully.
- CI #83 at `b556b5019b8dc21931416094b0a5c5dc0d30647d` passed Build, Test, test-result upload, and the complete workflow job.

CI #83 details:

- run id: `32638398426`
- job id: `97191501640`

Treat CI #83 as the current verified production-code baseline until a later head supersedes it.

## Dependency and system boundaries

The approved scope is complete Simplified Chinese coverage for FineTune-owned UI. The in-app runtime selector does not change the process-wide macOS application language.

### Sparkle 2.8.1

FineTune uses `SPUStandardUpdaterController`.

Sparkle 2.8.1 contains Simplified Chinese resources. Its standard UI resolves strings from the Sparkle framework bundle through `NSLocalizedStringFromTableInBundle`. Bundle localization follows native user/application language selection, not FineTune's `LocalizationContext`.

Therefore selecting Simplified Chinese only inside FineTune does not guarantee that Sparkle's standard update window switches to Chinese when macOS still selects another application language.

Do not replace `SPUStandardUserDriver`, mutate `AppleLanguages`, swizzle bundles, or introduce another process-language forcing mechanism as part of this PR. A custom updater UI would materially expand updater and security responsibilities and requires a separate decision.

### KeyboardShortcuts 2.4.0

The package includes `zh-Hans` resources. Its `RecorderCocoa` resolves package-owned text through `NSLocalizedString(..., bundle: .module)`.

FineTune-owned shortcut section labels and descriptions follow the FineTune runtime language. Package-owned recorder placeholder/conflict-alert text follows the package bundle's native localization selection and is not guaranteed to follow FineTune's runtime override.

Do not fork or replace the dependency solely to force this behavior without separate approval.

### macOS-owned UI

FineTune ships Chinese privacy purpose strings in `InfoPlist.xcstrings` and can localize its own custom panel messages. macOS still owns privacy-prompt chrome and standard panel controls. Their language follows platform application/system localization behavior, outside FineTune's runtime locale override.

## Final audit state

Confirmed:

- first-party language policy is deterministic and tested
- persistence compatibility is tested
- representative first-party Settings, popup, EQ, AutoEQ, device, HUD, help, accessibility, Bluetooth, notification, and privacy resources have English and Simplified Chinese coverage
- notification semantic fallbacks `none` and `Default Output` have Chinese resources and tests
- current production code passes CI #83
- feature branch is ahead of `main` with no observed release, signing, appcast, or dependency-upgrade drift
- adversarial spot checks of device-volume presentation, device-inspector presentation, and HUD style presentation found localization-only changes

Still not proven in this environment:

- live macOS GUI layout in every required English, Simplified Chinese, and Auto state
- clipping, wrapping, truncation, and visual quality across every popup size and Settings tab
- live observation of Sparkle, KeyboardShortcuts, privacy prompts, and standard file-panel chrome under mismatched native application language versus FineTune runtime language

The current execution environment cannot run FineTune's macOS GUI, and direct repository clone is unavailable because GitHub DNS is blocked in the local container. Do not claim those manual checks were completed.

## Final gates before merge authorization

1. Keep Build and Test green on the final branch head.
2. Keep the Phase 7 inventory and this handoff synchronized with the actual branch.
3. Perform the macOS GUI smoke matrix when an appropriate runtime is available.
4. Review Chinese layout, translation quality, accessibility/help copy, and live language switching.
5. Record dependency/system surface observations accurately.
6. Compare the final feature branch against `main` for unrelated drift.
7. Keep PR #5 unmerged until explicit authorization.

## Sensitive files

Treat these as high risk:

- `FineTune/Audio/Engine/AudioEngine.swift`
- `FineTune/Localizable.xcstrings`
- `FineTune/Views/MenuBarPopupView.swift`
- `FineTune/Utilities/LocalizationContext.swift`
- `FineTune/Settings/Types/AppLanguage.swift`
- `.github/workflows/ci.yml`

For large or sensitive files, reconstruct from an exact current blob, build a detached candidate, compare the resulting Git diff, and only then advance the branch. During the AudioEngine integration this process caught and removed an accidental missing final newline before production branch advancement.

## Development rules

Before writing:

1. Re-fetch the branch/PR head.
2. Re-fetch the exact files being changed.
3. Verify the requested behavior and success criteria.
4. Check official framework/source documentation when an assumption matters.

Before claiming completion:

1. Verify Build and Test from the final head.
2. Diagnose any failure from exact logs or `.xcresult` evidence.
3. Review the final diff against `main`.
4. Separate automated facts from manual/runtime observations.
5. Update this handoff.
6. Do not merge PR #5 without explicit authorization.
