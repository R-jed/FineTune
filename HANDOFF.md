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

`main` remains the stable base for the localization work. The current implementation is on `feature/ui-localization` in PR #5.

Latest verified implementation head before this handoff update: `366bcc534f4ca03dfc650c2e66da66399ef37886`.

PR #5 is open and unmerged. Its title and body now describe the implementation rather than the obsolete planning-only state. Do not merge it without explicit authorization.

Localization implementation is in progress. Phases 1 through 5 have automated Build and Test verification. Phase 6 is partially implemented and verified.

Recent verified CI milestones:

- Phase 1 foundation: CI #15 passed Build and Test.
- Phase 2 reusable localization boundaries and display resources: CI #21 and CI #22 passed Build and Test.
- Phase 3 Settings localization: CI #24 passed generated string symbols, Build, Test, and result upload.
- Phase 4 popup and shared component localization: completed and verified in later green CI runs before Phase 5.
- Phase 5 EQ, AutoEQ, and device-detail localization: final device presentation regression commit `982bd63fa4f49a6d344e70007ab640493ba2c179` passed CI #52.
- Phase 6 notification presentation helper and tests: head `dd00d1d2f905bc2028fb840d8ecee67bb2d611a7` passed CI #56.
- Phase 6 AutoEQ AppKit file-panel message, import error, and profile-loading error boundaries: head `13335db3fea48412f104e0bfcc689fd1c3722acd` passed CI #60.
- Refined Simplified Chinese privacy purpose strings in `InfoPlist.xcstrings`: commit `f281bec691032e344fcc7d530da29c30793b333d` passed CI #62.
- Built-product Info.plist localization verification: commit `366bcc534f4ca03dfc650c2e66da66399ef37886` passed CI #63. The unit test reads `zh-Hans/InfoPlist.strings` from the built FineTune.app and verifies all three privacy purpose values.

CI #23 previously failed during generated string-symbol generation because `Reset all settings?` and `Reset All Settings` normalized to the same generated symbol. The fix uses semantic key `settings.reset.confirmationTitle` with `Reset all settings?` as its English default value. Keep this pattern when two visible strings normalize to the same generated symbol.

CI #59 was cancelled because a newer branch commit superseded it. Do not count cancelled runs as verification. The superseding implementation passed CI #60.

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

- `FineTune/FineTuneApp.swift`: application composition, lifetime wiring, Settings scene, and FluidMenuBarExtra.
- `FineTune/Audio/`: audio capture, routing, gain, EQ, device volume backends and related logic.
- `FineTune/Audio/Engine/AudioEngine.swift`: core audio orchestration and the current production device-notification call sites. Treat this large file as high risk.
- `FineTune/Coordination/`: coordination and service orchestration.
- `FineTune/Models/`: domain models and state representations.
- `FineTune/Settings/`: persisted settings, migrations, settings-facing types and state.
- `FineTune/Shortcuts/`: global shortcuts and command handling.
- `FineTune/Utilities/LocalizationContext.swift`: central runtime localization policy for FineTune-owned UI.
- `FineTune/Utilities/DeviceNotificationPresentation.swift`: localized presentation helper for FineTune-owned audio-device notifications.
- `FineTune/Views/`: SwiftUI and AppKit-backed presentation code.
- `FineTune/Views/MenuBarPopupView.swift`: large central menu bar popup surface, including the AutoEQ import `NSOpenPanel` call site.
- `FineTune/Views/Settings/`: Settings root, reusable Settings components and tab content.
- `FineTune/Localizable.xcstrings`: first-party UI localization source of truth.
- `FineTune/InfoPlist.xcstrings`: localized Info.plist purpose strings.
- `FineTuneTests/InfoPlistLocalizationTests.swift`: verifies compiled Simplified Chinese privacy purpose resources from the built application bundle.
- `FineTuneTests/`: unit and integration-style tests.
- `.github/workflows/ci.yml`: build and test CI.
- `.github/workflows/release.yml`: signed and notarized release process plus Sparkle appcast generation.

## Localization architecture

Supported in-app language policies:

- Follow System, persisted as `system`.
- English, persisted as `en`.
- Simplified Chinese, persisted as `zh-Hans`.

`AppLanguage` raw values are persistence identifiers. Do not rename them for presentation reasons.

`LocalizationContext` is the focused runtime localization boundary. Follow System applies no FineTune-defined locale override. Explicit English or Simplified Chinese changes language and script while preserving the user's current region through `Locale.Components`.

Both FineTune SwiftUI roots consume the selected language. Explicit language changes update FineTune-owned UI without requiring application relaunch. Follow System leaves native bundle and macOS per-app language behavior intact.

Use `LocalizedStringResource` through reusable presentation boundaries and resolve to `String` only at final AppKit or other String-only boundaries. At an AppKit String boundary, create a focused `LocalizationContext` and resolve only the FineTune-owned text that AppKit requires as `String`.

When a boundary contains genuinely dynamic external text such as an application name, device name, user preset name, AutoEQ profile name, UID, PID, bundle ID, version or build value, render that dynamic value verbatim. Do not send external names through localization lookup.

`STRING_CATALOG_GENERATE_SYMBOLS = YES` remains enabled. Do not disable generated symbols to work around bad keys. When two English strings normalize to the same symbol, use an explicit semantic key with `LocalizedStringResource(_:defaultValue:...)` and add that semantic key to `Localizable.xcstrings`.

Keep one first-party UI catalog, `FineTune/Localizable.xcstrings`. Do not create a second general-purpose localization framework or hard-code Chinese branches in presentation code.

## Verified localization implementation

### Phase 1: foundation

Implemented and verified:

- `AppLanguage` with Follow System, English and Simplified Chinese.
- backward-compatible settings persistence with default `.system`.
- `zh-Hans` Xcode region registration.
- `Localizable.xcstrings` and `InfoPlist.xcstrings`.
- `LocalizationContext`.
- no explicit locale injection for Follow System.
- explicit English and Chinese presentation locale while retaining region.
- runtime language policy applied to both main SwiftUI roots.
- persistence, locale and catalog regression tests.

### Phase 2: reusable presentation boundaries

Implemented and verified:

- reusable Settings and section components preserve localizable resources.
- explicit verbatim paths exist for legitimate dynamic strings.
- localized display resources exist for language, appearance, popup size, volume hotkey step, menu bar icon style, HUD style, shortcut actions and volume-control tier.
- migrated production call sites use presentation resources instead of persistence IDs.
- shortcut repeat behavior was preserved after review caught an accidental `supportsRepeat` deletion.

### Phase 3: Settings window

Implemented and verified:

- General, Audio, Shortcuts, Updates and About Settings copy participates in Simplified Chinese localization.
- General contains the in-app language selector.
- Settings window title resolves through `LocalizationContext`.
- explicit English and Chinese selection updates Settings-owned text live through observed settings state.
- Updates uses selected presentation language for `RelativeDateTimeFormatter` while preserving region.
- version and build values remain verbatim while static labels localize.
- Accessibility and media-key Settings surfaces participate in localization.
- representative English and Simplified Chinese resource tests cover Settings copy.
- reset confirmation uses a semantic key to avoid generated-symbol collision.

### Phase 4: menu bar popup and shared components

Implemented and automatedly verified:

- `ModeToggle` localizes Single and Multi without changing stable mode identity.
- `DevicePicker` localizes System Audio, Select, multi-device copy and routing summaries while keeping actual device names verbatim.
- popup actions and common rows localize Settings, Donate, Quit, device headings, Bluetooth guidance, paired-device labels, app empty states, ignored-app counts, reorder controls and accessibility/help copy.
- No Output and No Input are treated as FineTune-owned fallback copy.
- dynamic application and device names remain verbatim.

### Phase 5: EQ, AutoEQ and device details

Implemented and automatedly verified through CI #52:

- built-in EQ preset and category identities remain stable while display names localize.
- user EQ preset names stay verbatim.
- AutoEQ profile IDs, names, measurement sources and imported external data stay verbatim.
- AutoEQ static UI, search, favorites, correction/preamp controls and import actions localize.
- device edit rows and icon picker localize static controls while preserving device names, UIDs and SF Symbol identifiers.
- device icon category identity/search keywords stay stable; display labels localize separately.
- `DeviceInspectorInfo` stores `TransportType` as device fact instead of a prebuilt English transport label.
- Device Inspector labels such as Transport, Sample rate, Format and Device ID localize in the presentation layer.
- sample rates, PCM format strings, device UID, PID and external process names remain verbatim.
- exclusive-use presentation keeps PID/process facts separate from localizable sentence structure.
- Chinese wording was reviewed for user-facing clarity, including `设备详情`, `连接方式`, `恢复默认图标`, `采样率`, `独占使用`, and `使用 FineTune 软件音量控制`.
- Phase 5 localization regression tests verify representative Chinese wording and dynamic-data preservation.

## Phase 6: current work

Phase 6 covers AppKit-only first-party text, FineTune-owned notifications, user-facing errors, and Info.plist built-bundle verification.

### Verified Phase 6 work

`DeviceNotificationPresentation` exists and has tests for English and Simplified Chinese notification copy. It provides natural singular/plural presentation for reconnect, disconnect and default-device-change notifications while keeping device names verbatim. The helper/resources/tests passed CI #56.

Important limitation: production notification methods inside `AudioEngine.swift` still directly construct English titles and bodies such as `Audio Device Reconnected` and `app(s)`. The helper is not yet connected to those three production call sites. Therefore FineTune-owned device notifications are not complete yet.

Do not claim notification localization complete until `showReconnectNotification`, `showDisconnectNotification`, and `showDefaultChangedNotification` use `DeviceNotificationPresentation` with `settingsManager.appSettings.language` and the full Build/Test gate passes.

`MenuBarPopupView` now resolves the FineTune-owned `NSOpenPanel.message` for AutoEQ imports through `LocalizationContext`, and AutoEQ import/profile-loading errors preserve localizable static copy while leaving external profile names verbatim. The required Chinese catalog entries already exist. This path passed CI #60.

`InfoPlist.xcstrings` contains English and Simplified Chinese privacy purpose strings for audio capture, Bluetooth, and microphone access. The Chinese copy was refined for user-facing clarity in `f281bec691032e344fcc7d530da29c30793b333d`, which passed CI #62.

`FineTuneTests/InfoPlistLocalizationTests.swift` verifies the compiled product rather than only the source catalog. It locates the FineTune app bundle during the host-based unit test, opens `zh-Hans/InfoPlist.strings`, and checks all three final Chinese privacy purpose values. This passed CI #63. Built-bundle Info.plist localization is therefore automatedly verified.

### Next safe Phase 6 work

1. Localize the FineTune-owned permission banner copy in `PermissionBannerView` through the existing catalog. The SwiftUI literals already participate in localization; the remaining work is catalog coverage and regression tests. Candidate Chinese wording:
   - `Audio capture access required` -> `需要系统音频录制权限`
   - `Enable in System Settings → Privacy & Security → Screen & System Audio Recording` -> `请在“系统设置” → “隐私与安全性” → “屏幕与系统音频录制”中启用`
   - `Open System Settings` -> `打开系统设置`
   - `Grant Access` -> `授予权限`
2. Connect the validated notification presentation helper to the three production `AudioEngine` notification methods using a safe patch mechanism. `AudioEngine.swift` is close to 100 KB; avoid replacing the whole file through a whole-file connector write merely to change a few lines.
3. Complete the inventory of remaining user-visible error strings and AppKit String boundaries. Keep logs/debug messages in English unless they are actually surfaced to users.

`URLHandler.swift` was reviewed during Phase 6 and contains logging only; its English diagnostics are not user-visible UI and should not be added to the localization catalog.

System-owned controls inside standard `NSOpenPanel`, macOS privacy dialogs, Sparkle UI and KeyboardShortcuts UI remain separate verification boundaries. Do not replace standard system panels or fork dependencies solely to force FineTune's in-app runtime language without explicit approval.

## Remaining work after Phase 6

- completeness inventory that classifies every production English literal as localized, stable identifier, SF/API/system text, debug/log text, dynamic external text, or test/preview text.
- dependency and platform behavior verification for KeyboardShortcuts, Sparkle, privacy UI and standard AppKit panels.
- final English and Simplified Chinese layout smoke tests.
- final adversarial review of translation quality, dynamic-data boundaries, persistence identity and unrelated drift.

Manual runtime verification is still required for this matrix:

1. Native macOS application language English with FineTune Follow System.
2. Native macOS application language Chinese with FineTune Follow System.
3. Native macOS application language English with FineTune explicit Chinese.
4. Native macOS application language Chinese with FineTune explicit English.

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

- Keep `main` usable.
- Make focused commits with one logical concern each.
- Preserve persisted data compatibility unless a migration is explicitly designed and tested.
- Keep feature-specific logic in the owning module.
- Avoid new dependencies when Foundation, SwiftUI, AppKit or current packages already solve the problem.
- Do not mix drive-by refactors with localization behavior.
- Protect large files such as `MenuBarPopupView.swift` and `AudioEngine.swift` from gaining unrelated responsibilities.
- Re-read the feature branch head before each write and use fast-forward updates only.
- If concurrent commits appear, compare them before writing; do not overwrite another worker's changes.

Before merge:

- Review correctness, readability, architecture, security, performance and test evidence.
- Run the full relevant Build and Test path.
- Compare the feature branch with `main` for unrelated drift.
- Smoke-test affected UI in both languages where possible.
- Complete the dependency and system-surface behavior matrix.
- Review the final string inventory.
- Keep PR #5 unmerged until explicit merge authorization is given.
