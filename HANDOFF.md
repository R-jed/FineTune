# FineTune Project Handoff

Last updated: 2026-08-23

This file is the starting context for future development sessions on this repository. Read it before changing code, then verify any time-sensitive details against the repository itself.

## Project identity

FineTune is a macOS menu bar audio-control application. It can control per-app volume, boost app gain, route apps to different output devices, manage output/input device levels, provide per-app EQ and AutoEQ headphone correction, handle global shortcuts and media keys, and display its own volume HUD.

Repository: `R-jed/FineTune`

Upstream origin used to bootstrap this repository: `ronitsingh10/FineTune`

Bootstrap baseline:

- Upstream branch: `main`
- Upstream commit: `2285279d36d3f8115c1c2d4aecd904f1bdf96a51`
- Upstream tree: `cfc960ed5e09651c8876aa42c2443adffe0705a5`
- Upstream release represented by that snapshot: v1.9.0
- License: GNU GPL v3
- Original copyright notice must be preserved.

The initial `R-jed/FineTune` snapshot was verified at the Git tree level against the upstream tree before project-specific development began. Later commits in this repository intentionally diverge from that upstream snapshot.

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

A change is not complete until the relevant tests and build pass. For UI work, also verify the affected window or menu bar surface manually when possible.

## Repository structure

Main application code lives in `FineTune/`.

Key areas:

- `FineTune/FineTuneApp.swift`: application composition and lifetime wiring. Creates the audio engine and long-lived services, declares the Settings scene and FluidMenuBarExtra.
- `FineTune/Audio/`: audio capture, routing, gain, EQ, device volume backends and related audio logic.
- `FineTune/Coordination/`: coordination and service-level orchestration.
- `FineTune/Models/`: domain models and state representations.
- `FineTune/Settings/`: persisted settings, migrations, settings-facing types and state.
- `FineTune/Shortcuts/`: global shortcuts and related command handling.
- `FineTune/Utilities/`: shared utilities and platform helpers.
- `FineTune/Views/`: SwiftUI and AppKit-backed presentation code.
- `FineTune/Views/MenuBarPopupView.swift`: large central menu bar popup surface. Treat changes here carefully because it is already a large file.
- `FineTune/Views/Settings/`: Settings window root, reusable Settings components, and tab content.
- `FineTuneTests/`: unit and integration-style tests.
- `.github/workflows/ci.yml`: build and test CI.
- `.github/workflows/release.yml`: signed/notarized release process and Sparkle appcast generation.

## Architecture notes

`FineTuneApp` creates a single `SettingsManager` and injects it through the production graph via `AudioEngine`. Settings UI receives the same manager with Swift Observation (`@Bindable`). This makes `SettingsManager` the natural owner for new persisted app-wide preferences.

The Settings window is a SwiftUI `TabView` with General, Audio, Shortcuts, Updates, and About sections. Window appearance is already user-selectable and is applied through both SwiftUI and AppKit bridges.

The app mixes SwiftUI-localizable view initializers such as `Text`, `Label`, `Button`, and custom component APIs that currently accept plain `String`. A localization implementation must account for both paths. Do not assume that converting only visible `Text("...")` calls is sufficient.

Several enums use English display strings through `CustomStringConvertible` or raw values, including appearance, popup size, menu bar icon style and volume hotkey step. Persisted values must stay stable when presentation labels are localized. Do not change Codable/raw persistence identifiers merely to translate UI text.

## Current UI language state

The repository already contains `README.zh-CN.md`, but the application UI is effectively English-only. Visible text is hardcoded across Settings, menu bar popup, pickers, dialogs, permission/error surfaces, device UI and supporting presentation types.

The next planned feature is full application UI localization with an in-app language selector. Initial scope:

- English
- Simplified Chinese (`zh-Hans`)
- A user-facing language selector in Settings
- Complete translation of user-visible application UI, including dialogs, menu bar popup, Settings, pickers, labels, permission/help text, empty states and user-facing errors
- Stable English/internal identifiers for persistence, URLs, commands and programmatic keys
- Tests or automated checks that make missing localization coverage visible

Do not implement this as a table of ad-hoc ternaries. Use the native Apple localization system and keep localization resources as the source of truth.

## Known upstream-specific references

Because the repository began as a faithful upstream snapshot, several user-facing and release paths still refer to `ronitsingh10/FineTune`, including README download/release links and parts of the release/appcast workflow.

Do not silently rewrite these while working on unrelated features. Treat repository ownership/release migration as its own reviewed change.

The release workflow also depends on signing, notarization, Sparkle and repository secrets. A normal feature change must not alter release secrets or signing assumptions unless that work is explicitly in scope.

## Development rules for future sessions

Before implementation:

1. Read this file, the relevant source files and tests.
2. Establish the exact behavioral goal and success criteria.
3. For framework-specific decisions, verify the current pattern against official Apple or dependency documentation that matches the project version.
4. Prefer the smallest architectural change that solves the whole requirement cleanly.

During implementation:

- Branch from `main` using a short-lived feature/fix/refactor branch.
- Keep `main` usable.
- Make focused commits with one logical concern each.
- Preserve persisted data compatibility unless a migration is explicitly designed and tested.
- Keep feature-specific logic in the owning module.
- Avoid adding new dependencies when Foundation, SwiftUI, AppKit or existing packages already solve the problem.
- Do not mix drive-by refactors with feature behavior.
- For large files such as `MenuBarPopupView.swift`, prefer extraction when a change would add another independent responsibility.

Before merge:

- Review correctness, readability, architecture, security and performance.
- Run the relevant tests and full build.
- Check for user-facing regressions and missing states.
- Compare behavior against `main` for the changed feature.
- Review the final diff for accidental unrelated changes.

## Localization initiative handoff

When continuing the language feature, begin by reading the localization plan/spec committed with or after this handoff, then re-scan the current tree for new user-facing literals before implementation. The codebase may change between sessions, so a string inventory captured once is evidence for a baseline, not a permanent whitelist.

For Simplified Chinese, translations should read like native macOS product UI. Keep technical product names and established terms consistent across the popup, Settings and dialogs. Test layout with Chinese because translated lengths and line breaks differ from English even when Chinese often appears visually shorter.
