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
- Original copyright notice must be preserved

The initial `R-jed/FineTune` snapshot was verified at the Git tree level against the upstream tree before project-specific development began. Later commits intentionally diverge from that snapshot.

## Current development state

`main` remains the stable base for the localization work. The current localization implementation is on `feature/ui-localization` in PR #5.

Latest verified localization implementation commit before this handoff update: `4426c7dd0e66354817932da5eda6462223588794`.

PR #5 is open and unmerged. Do not merge it without explicit authorization.

Localization implementation is in progress. Phases 1 through 3 have automated verification. Phase 4 is the next implementation phase.

Verified CI milestones:

- Phase 1 foundation: CI #15 passed Build and Test
- Phase 2 reusable localization boundaries and display resources: CI #21 and CI #22 passed Build and Test
- Phase 3 Settings localization: CI #24 passed string symbol generation, Build, Test, and test-result upload

CI #23 failed during string-symbol generation because `Reset all settings?` and `Reset All Settings` normalized to the same generated symbol. The fix uses a semantic localization key, `settings.reset.confirmationTitle`, with `Reset all settings?` as its default English value. Keep this pattern in mind when two visible strings would generate the same String Catalog symbol.

## Current platform and dependencies

FineTune targets macOS 15.0 or later. The release workflow currently builds on macOS 26 runners.

Important Swift Package dependencies pinned in `Package.resolved`:

- FluidMenuBarExtra 1.5.1
- KeyboardShortcuts 2.4.0
- Sparkle 2.8.1
- swift-snapshot-testing 1.18.7
- swift-custom-dump 1.3.3
- SwiftSyntax 602.0.0
- XCTest Dynamic Overlay 1.8.1

Do not upgrade dependencies casually. Read the relevant changelog or migration guidance, change one dependency or tightly related group at a time, and verify the lockfile diff.

## Build and test commands

The repository CI defines the canonical build and test path.

Build:

```bash
xcodebuild build \
  -project FineTune.xcodeproj \
  -scheme FineTune \
  -configuration Debug \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO
```

Test:

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

A change is not complete until the relevant tests and build pass. UI work also needs manual verification of affected macOS surfaces when that environment is available.

## Repository structure

Main application code lives in `FineTune/`.

Key areas:

- `FineTune/FineTuneApp.swift`: application composition, lifetime wiring, Settings scene, and FluidMenuBarExtra
- `FineTune/Audio/`: audio capture, routing, gain, EQ, device volume backends and related logic
- `FineTune/Coordination/`: coordination and service orchestration
- `FineTune/Models/`: domain models and state representations
- `FineTune/Settings/`: persisted settings, migrations, settings-facing types and state
- `FineTune/Shortcuts/`: global shortcuts and command handling
- `FineTune/Utilities/LocalizationContext.swift`: central runtime localization policy for FineTune-owned UI
- `FineTune/Views/`: SwiftUI and AppKit-backed presentation code
- `FineTune/Views/MenuBarPopupView.swift`: large central menu bar popup surface. Keep localization logic out of this file when it can live in focused presentation helpers
- `FineTune/Views/Settings/`: Settings root, reusable Settings components and tab content
- `FineTune/Localizable.xcstrings`: first-party UI localization source of truth
- `FineTune/InfoPlist.xcstrings`: localized Info.plist purpose strings
- `FineTuneTests/`: unit and integration-style tests
- `.github/workflows/ci.yml`: build and test CI
- `.github/workflows/release.yml`: signed and notarized release process plus Sparkle appcast generation

## Localization architecture

Supported in-app language policies:

- Follow System, persisted as `system`
- English, persisted as `en`
- Simplified Chinese, persisted as `zh-Hans`

`AppLanguage` raw values are persistence identifiers. Do not rename them for presentation reasons.

`LocalizationContext` is the focused runtime localization boundary. Follow System applies no FineTune-defined locale override. Explicit English or Simplified Chinese changes language and script while preserving the user's current region through `Locale.Components`.

Both FineTune SwiftUI roots consume the selected language. Explicit language changes therefore update FineTune-owned UI without requiring application relaunch. Follow System leaves native bundle and macOS per-app language behavior intact.

Use `LocalizedStringResource` through reusable presentation boundaries and resolve to `String` only at final AppKit or other String-only boundaries. Reusable Settings components have already been changed to keep localizable resources instead of flattening static UI copy into ordinary strings.

When a boundary contains genuinely dynamic external text such as an application name, device name, user preset name, AutoEQ profile name, UID, PID, bundle ID, version or build value, render that dynamic value verbatim. Do not send external names through localization lookup.

`STRING_CATALOG_GENERATE_SYMBOLS = YES` remains enabled. Do not disable generated symbols to work around bad keys. When two English strings would normalize to the same symbol, use an explicit semantic key with `LocalizedStringResource(_:defaultValue:...)` and add that semantic key to `Localizable.xcstrings`.

## Verified localization implementation

### Phase 1: foundation

Implemented and verified:

- `AppLanguage` with Follow System, English and Simplified Chinese
- backward-compatible settings persistence with default `.system`
- `zh-Hans` Xcode region registration
- `Localizable.xcstrings` and `InfoPlist.xcstrings`
- `LocalizationContext`
- no explicit locale injection for Follow System
- explicit English and Chinese presentation locale while retaining region
- runtime language policy applied to both main SwiftUI roots
- persistence, locale and catalog regression tests

### Phase 2: reusable presentation boundaries

Implemented and verified:

- `SettingsRow`, `SettingsSection`, `AboutLinkChip` and `SectionHeader` preserve localizable resources
- explicit verbatim paths exist for legitimate dynamic strings
- localized display resources exist for language, appearance, popup size, volume hotkey step, menu bar icon style, HUD style, shortcut actions and volume-control tier
- production display call sites use `displayName` instead of persistence `rawValue` or old English `description` where migrated
- shortcut repeat behavior was preserved after review caught an accidental `supportsRepeat` deletion

### Phase 3: Settings window

Implemented and verified:

- General, Audio, Shortcuts, Updates and About tab copy has Simplified Chinese catalog coverage for the Phase 3 Settings scope
- General contains the in-app language selector
- Settings window title resolves through `LocalizationContext`
- explicit English and Chinese selection can update Settings-owned text live through the observed settings state
- Updates uses the selected presentation language for `RelativeDateTimeFormatter` while preserving the user's region
- version and build values remain verbatim while the static `Version` prefix localizes
- Accessibility prompt and media-key offline Settings surfaces participate in localization
- representative English and Simplified Chinese resource tests cover Settings copy
- reset confirmation uses a semantic key to avoid String Catalog generated-symbol collision

The Settings implementation still depends on shared components such as `DevicePicker`. Those shared components are part of Phase 4 and may still expose English text inside an otherwise localized Settings tab until Phase 4 is complete.

## Next implementation phase

Phase 4 covers the menu bar popup and shared components used by that popup and Settings.

Known boundaries already identified:

- `ModeToggle` stores `Single` and `Multi` as ordinary `String`; move static labels to `LocalizedStringResource`
- `DevicePicker` mixes static UI copy with dynamic device names in ordinary `String` properties
- keep device names verbatim while localizing `System Audio`, `Select`, multi-device counts and routing summaries
- menu bar popup still contains `Drag or type a number to set priority`, reorder/done labels, Settings, Donate, Quit, empty states, Bluetooth guidance, `Paired`, `Apps`, ignored-app counts and related accessibility/help text
- default device fallbacks `No Output` and `No Input` are static FineTune copy even though successful device names are dynamic external values
- interpolated counts such as ignored-app counts must remain localizable resources rather than prebuilt English strings

Do not put a localization service or a large translation switch inside `MenuBarPopupView.swift`. Keep static resources native to SwiftUI where possible and extract focused presentation helpers where a String-only or mixed static/dynamic boundary requires it.

## Remaining localization work after Phase 4

The planned later phases still include:

- EQ, AutoEQ and device-detail surfaces
- AppKit-only messages, custom notifications and user-facing errors
- Info.plist built-bundle verification
- a completeness inventory that classifies every production English literal as localized, stable identifier, SF/API/system text, debug/log text, dynamic external text, or test/preview text
- dependency and platform behavior verification for KeyboardShortcuts, Sparkle, privacy UI and standard AppKit panels
- final English and Simplified Chinese layout smoke tests

Manual runtime verification is still required for this matrix:

1. Native macOS application language English with FineTune Follow System
2. Native macOS application language Chinese with FineTune Follow System
3. Native macOS application language English with FineTune explicit Chinese
4. Native macOS application language Chinese with FineTune explicit English

Check FineTune-owned UI separately from dependency and system-owned UI. Do not claim Sparkle, KeyboardShortcuts, privacy prompts or standard AppKit panel controls follow FineTune's runtime override until observed.

## Known upstream-specific references

Because the repository began as a faithful upstream snapshot, several user-facing and release paths still refer to `ronitsingh10/FineTune`, including README download/release links and parts of the release/appcast workflow.

Do not silently rewrite these while working on localization. Treat repository ownership and release migration as a separate reviewed change.

The release workflow depends on signing, notarization, Sparkle and repository secrets. Localization work must not alter release secrets, signing assumptions or appcast behavior unless that scope is explicitly approved.

## Development rules for future sessions

Before implementation:

1. Read this file, the localization spec/plan, relevant source files and tests.
2. Establish the exact behavioral goal and success criteria for the current phase.
3. Verify framework-specific decisions against current official Apple or dependency documentation.
4. Prefer the smallest architectural change that solves the whole requirement cleanly.

During implementation:

- Keep `main` usable
- Make focused commits with one logical concern each
- Preserve persisted data compatibility unless a migration is explicitly designed and tested
- Keep feature-specific logic in the owning module
- Avoid new dependencies when Foundation, SwiftUI, AppKit or current packages already solve the problem
- Do not mix drive-by refactors with localization behavior
- Protect large files such as `MenuBarPopupView.swift` from gaining another independent responsibility
- Re-read the feature branch head before each write and use fast-forward updates only

Before merge:

- Review correctness, readability, architecture, security, performance and test evidence
- Run the full relevant Build and Test path
- Compare the feature branch with `main` for unrelated drift
- Smoke-test affected UI in both languages where possible
- Complete the dependency and system-surface behavior matrix
- Review the final string inventory
- Keep PR #5 unmerged until explicit merge authorization is given
