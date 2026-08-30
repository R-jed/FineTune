# App discovery and audio state repair

## Goal

Running user-facing macOS applications must be discoverable before they produce audio. FineTune must keep audio capture fail-closed behind the existing capture permission and Core Audio process-object requirements.

## Confirmed problem

The current branch seeds `AudioProcessMonitor.activeApps` from `NSWorkspace.runningApplications`, but `AudioEngine` only starts that monitor after capture permission is authorized. A silent running app can therefore remain undiscovered until permission is granted.

A running app with no Core Audio process object is represented by an `AudioApp` with an empty `processObjectIDs` array. That state currently exposes two regressions:

1. `setEQSettings` returns before persistence when no tap exists.
2. Restoring multi-device state attempts tap creation before recording the primary presentation route, so a silent app can have no `appDeviceRouting` entry and fail to render.

## Design

Keep the existing model and helper-attribution logic. Make the smallest lifecycle correction:

- Start `AudioProcessMonitor` independently of capture authorization.
- Keep tap creation, persisted audio application, and health monitoring permission-gated.
- Treat persisted app settings as source of truth. Runtime taps consume those settings when available.
- Restore multi-device presentation state before attempting tap creation.
- Do not add bundle-ID tap pre-arming or process-restore behavior in this repair.

## Non-goals

- No rewrite of `AudioProcessMonitoring` into a new snapshot protocol.
- No change to helper/XPC responsibility resolution.
- No expansion of the background-process allowlist or denylist.
- No `CATapDescription.bundleIDs` or `isProcessRestoreEnabled` experiment.
- No unrelated localization, ordering, or device-priority changes.

## Acceptance criteria

- `AudioEngine.start()` starts app discovery when capture permission is denied.
- A silent running app can persist EQ settings without a tap.
- A silent running app with saved multi-device routing has a primary display route and remains visible.
- When Core Audio process objects later appear, the saved multi-device state provisions the tap without requiring the user to reconfigure the app.
- Tap creation still requires capture authorization and non-empty process object IDs.
- Existing build and test suite passes on the exact repair head.
- Final diff against the repair base contains only the intended lifecycle, persistence, routing-state, specification, and regression-test changes.

## Runtime smoke checks after automated validation

On macOS, verify representative regular apps and helper-backed audio apps through these transitions: launch before playback, start playback, pause longer than the stale cleanup grace period, resume, quit, and relaunch. Confirm system/background services do not appear as independent rows.
