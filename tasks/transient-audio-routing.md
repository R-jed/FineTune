# Transient audio routing repair

## Goal

An app with an explicit FineTune audio policy must not leak app-owned transient audio to the macOS default output while FineTune is authorized and healthy.

The repair must also distinguish app-owned Core Audio output from sounds delegated to macOS system services. A delegated alert or notification follows the system-sounds output path and must not be presented as if FineTune can route it through the originating app's process tap.

## Confirmed current behavior

- Running user-facing apps are discoverable before they own a Core Audio process object.
- A quiet app is represented with an empty `processObjectIDs` array.
- `AudioEngine.ensureTapExists` does not create a process tap while `processObjectIDs` is empty.
- When the Core Audio process-object set changes, `AudioEngine` retires the existing tap and provisions from the new process-object set.
- `ProcessTapController` uses `.mutedWhenTapped`, so original process output is only suppressed after a tap exists and is active.
- `AudioProcessMonitor` filters system audio daemons such as `systemsoundserverd` and notification services from the user-app list.
- FineTune already controls `kAudioHardwarePropertyDefaultSystemOutputDevice` separately through the System Sounds setting.

## Newly identified gap

The previous app-discovery repair intentionally deferred tap creation until Core Audio process objects appeared. Its acceptance criteria proved that saved state is applied after an object becomes available, but did not prove that the first audible buffer is intercepted.

For apps that create a Core Audio process object only for a short effect, the current lifecycle can be:

1. The app is visible and has a saved explicit route, but no tap exists.
2. A short sound starts and a Core Audio process object appears.
3. The process-list notification is delivered on the main queue and `AudioProcessMonitor` performs a full refresh.
4. `AudioEngine` receives the updated app and creates/activates a tap.
5. Audio rendered before tap activation can still reach the original output.
6. If the process object disappears, the tap is retired and the next transient repeats the same lifecycle.

This is a source-level timing risk. Whether a specific third-party app creates and destroys its Core Audio process object around each sound still requires real-machine evidence.

## Separate system-delegated sound case

Some applications may ask macOS to play an alert or notification on their behalf. In that case the Core Audio producer can be a system daemon rather than the requesting app.

FineTune cannot infer per-app ownership from the audio process alone when the system service does not expose that attribution. Such audio should follow FineTune's System Sounds device setting. Runtime diagnostics must classify this case before changing per-app tap behavior.

## Preferred design investigation

Re-open the Core Audio features that were explicitly out of scope in the earlier app-discovery repair:

- `CATapDescription.bundleIDs`
- `CATapDescription.isProcessRestoreEnabled`

Investigate whether an explicitly configured quiet app with a known bundle ID can have a private `.mutedWhenTapped` tap armed before `processObjectIDs` becomes non-empty, and whether process-restore semantics can keep that tap associated across short-lived audio-process churn.

Do not assume this works from API shape alone. Prove the behavior on the supported macOS baseline before making it the production path.

For helper-backed apps, preserve the existing responsible-app attribution. A parent app bundle ID may not be the bundle ID of the actual audio helper, so the implementation must not regress helper/XPC routing.

## Fallback design investigation

If bundle-ID pre-arming cannot reliably intercept the first buffer:

- separate time-critical Core Audio process-object provisioning from the full UI discovery refresh;
- avoid unnecessary main-queue hops between the HAL process-list notification and tap provisioning;
- measure notification-to-tap-active latency with monotonic timestamps;
- retain safe tap state across inactive periods where the underlying Core Audio process object remains valid.

A faster reactive path is an optimization, not a hard no-leak guarantee if the process object does not exist until rendering begins.

## Acceptance criteria

### App-owned transient audio

- With system default output A and an explicit FineTune route to output B, the first audible transient from an already-running app is heard only on B.
- Repeated short transients remain on B after idle periods.
- A Core Audio process-object disappear/reappear cycle does not cause a transient to leak to A.
- Existing continuous-playback routing, volume, mute, EQ, AutoEQ, multi-device output, and tap lifetime tests remain green.
- Helper-backed apps keep one user-facing identity and retain correct routing.

### System-delegated audio

- A diagnostic run can determine whether the audible producer is the app's process/helper or a filtered system daemon.
- Sounds produced by the macOS system-sounds path follow FineTune's System Sounds device selection.
- FineTune does not claim that a per-app route controls a system-delegated sound when Core Audio exposes no originating-app attribution.

### Safety

- Capture remains fail-closed behind authorization.
- No global/system tap is introduced merely to solve a per-app transient.
- No background/system-daemon rows are added to the normal app list.
- No stale process-object IDs are retained as valid tap targets after HAL destroys them.
- No new blocking, allocation, logging, or Objective-C work is added to the real-time audio callback.

## Required tests

- Replace the misleading assumption that "process object returns and tap rebuilds" is sufficient first-sound coverage with explicit provisioning/lifecycle tests.
- Test the quiet-app explicit-route pre-arm decision independently of UI state.
- Test process-object churn without losing the configured route.
- Test helper-backed identity separately from direct bundle-ID ownership.
- Preserve the existing PID-reuse and representative-PID migration safety tests.

## Real-machine diagnostic gate

Before selecting the production strategy, reproduce with a short-sound app using three distinct outputs where possible:

- A: macOS default output
- B: FineTune per-app explicit route
- C: FineTune System Sounds explicit route

Record which device produces the transient and correlate it with AudioProcessMonitor/tap lifecycle timestamps. This distinguishes app-owned first-buffer leakage from macOS system-delegated playback.
