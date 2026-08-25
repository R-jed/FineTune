# RT biquad lifetime repair

## Problem

`BiquadProcessor` currently publishes `vDSP_biquad_Setup` with ordinary shared storage and retires the old setup after a fixed 500 ms delay. `resetDelayBuffers()` and `updateSampleRate()` also rely on `_isEnabled` plus `OSMemoryBarrier()` before mutating delay buffers from the main thread.

Those mechanisms do not prove that a HAL callback which already entered `process()` has stopped using the old setup or delay buffers. Fixed wall-clock delay is a heuristic, not a lifetime boundary.

## Scope

This task repairs the lifetime contract inside `BiquadProcessor` only. It does not broaden into the rest of `ProcessTapController`'s `nonisolated(unsafe)` state in this PR.

## Required behavior

1. The realtime callback must never take a lock, allocate, log, perform I/O, or sleep.
2. Entry to `process()` must register as an active realtime reader before it reads the enabled flag or active setup.
3. The active setup pointer and enabled flag must use real atomic storage.
4. Replacing a setup must publish the new pointer atomically.
5. An old setup may be destroyed only after a real quiescent point has occurred after publication of the replacement.
6. Delay buffers may be cleared only after processing is atomically disabled and all readers that could have entered before that disable have passed a quiescent point.
7. Ordinary EQ coefficient changes continue to preserve delay-buffer state, matching existing audible behavior.
8. Sample-rate changes continue to reset delay-buffer state.
9. The implementation must remove the fixed 500 ms setup-retirement heuristic and `OSMemoryBarrier()` dependency from `BiquadProcessor`.
10. Existing signal-domain behavior and tests must remain green.

## Design

Use Swift's `Synchronization.Atomic` primitives. Keep the concurrency mechanism as an internal seam inside the biquad implementation.

The internal module tracks:

- active realtime reader count
- a monotonically increasing quiescence epoch, advanced whenever the reader count reaches zero

A writer publishes a new setup, then waits off the realtime thread for a quiescence epoch that proves all readers which could have observed the old setup are gone. New readers after publication may delay reclamation but cannot make reclamation unsafe.

## Acceptance criteria

- no `OSMemoryBarrier()` in `BiquadProcessor`
- no fixed-delay setup destruction in `BiquadProcessor`
- deterministic tests cover quiescence waiting and the case where a new reader starts after the required quiescent point
- full build and non-UI test suite pass on the exact branch head
- branch diff is limited to this lifetime repair, its tests, and this task record
