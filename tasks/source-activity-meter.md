# Source Activity Meter

## Objective

Make the per-app 8-segment meter a truthful source-activity peak meter. It represents the app's captured source signal before FineTune volume, EQ, loudness processing, limiting, and device output.

This meter is not a LUFS loudness meter and is not an output clipping meter.

## Current Problems

1. The HAL callback scans only every `mNumberChannels`-th Float, so an interleaved right-channel-only transient can be missed.
2. The callback applies a fixed `0.3` EMA to each audio buffer. The result depends on callback buffer cadence and suppresses short peaks before the UI can observe them.
3. `VUMeter` owns a `Task`-based peak-hold state machine. A naturally completed decay task remains non-nil and can leave later peaks stuck.
4. UI decay subtracts a fixed linear amplitude per frame while describing the behavior in dB. The decay is therefore not time- or dB-consistent.
5. A below-floor peak can light the bottom peak indicator because its index defaults to zero.

## Researched Pattern

Use the established metering pattern found across Apple Accelerate-based audio code and mature audio frameworks:

- compute maximum absolute sample magnitude across the complete source buffer;
- use immediate attack;
- keep a short transient hold so a 30 fps UI cannot miss a one-buffer peak;
- release according to elapsed audio time in dB per second;
- keep the SwiftUI meter as a renderer, not the owner of meter timing state.

No new third-party dependency is required. The implementation uses Apple Accelerate/vDSP.

## Contract

### Measurement point

The meter measures the captured app source before FineTune gain and DSP. User mute continues to show source activity using the existing muted visual treatment. `_forceSilence` continues to bypass the meter during destructive switching.

### Peak extraction

For the trailing Core Audio tap input buffers that are actually mapped into FineTune's output path:

- inspect every Float sample, regardless of channel layout;
- compute maximum magnitude, including negative samples;
- combine the mapped tap buffers with `max`;
- clamp the display signal to `0...1`.

Hardware input buffers that are not part of the app tap path are excluded from metering. This also avoids assuming interleaved or non-interleaved channel layout for the source scan.

### Ballistics

- attack: immediate;
- transient hold: 100 ms of audio time;
- release: 24 dB per second;
- floor: -60 dBFS, below which the display snaps to zero;
- timing: derived from `frameCount / sampleRate`, so behavior is independent of callback buffer size and device sample rate;
- if the hold expires partway through a callback buffer, only the held frames are exempt from release and the remaining frames decay immediately.

The constants are UI behavior choices, not a claim of BBC PPM, VU, LUFS, or another broadcast standard.

## Scope Boundaries

In scope:

- source peak extraction;
- source-meter ballistics;
- removal of `VUMeter`'s task-based peak state;
- deterministic unit tests for peak extraction and ballistics;
- documentation of source-meter semantics.

Out of scope:

- post-DSP/output metering;
- LUFS/RMS perceived loudness;
- true-peak oversampling;
- changing the app mute/output DSP behavior;
- replacing all per-row UI polling timers with a shared ticker;
- broad replacement of existing `nonisolated(unsafe)` audio-thread state with synchronization primitives.

## Implementation Plan

- [x] Add tests for all-channel absolute peak extraction and time-based ballistics.
- [x] Add a small RT-safe meter helper backed by Accelerate/vDSP.
- [x] Replace callback EMA/first-channel scan with the helper.
- [x] Configure primary/secondary meter timing from each tap's actual sample rate and preserve correct state through crossfade promotion.
- [x] Make `VUMeter` a pure renderer of the published source level.
- [ ] Run build and full non-UI test suite on the exact head commit.
- [x] Review the final diff for RT safety, scope, stale comments, duplicated bar-count state, and dead meter state.

## Acceptance Criteria

1. A full-scale one-buffer transient reaches display level `1.0` immediately and remains observable for at least 100 ms of audio time.
2. A negative full-scale sample is detected as magnitude `1.0`.
3. A right-channel-only transient in interleaved stereo data is detected.
4. A silent signal after the hold period decays by 24 dB after one second, independent of how that second is divided into buffers, including a hold boundary that lands mid-buffer.
5. Equivalent elapsed time at 44.1 kHz and 48 kHz produces equivalent meter decay within floating-point tolerance.
6. Values below -60 dBFS settle to zero.
7. `VUMeter` contains no `Task`, timer, or internal peak-decay state.
8. Muted apps can still display source activity using muted colors.
9. The HAL callback performs no memory allocation, locking, Objective-C messaging, file/network I/O, or logging as part of metering.
10. Exact-head CI build and tests pass before the task is considered complete.

## Verification Record

Implementation and static adversarial review are complete on the feature branch. Exact-head CI remains the final gate. CI evidence is recorded on PR #7 so documenting the result does not mutate the verified commit afterward.
