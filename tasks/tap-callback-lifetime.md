# Tap callback processor-generation contract

## Problem

`ProcessTapController` determines primary/secondary callback role from callback IDs, then later reads DSP processor references from controller-wide primary/secondary properties.

During crossfade promotion those facts are published separately:

1. secondary processor references are moved into the primary properties;
2. secondary properties are cleared;
3. only afterwards is the secondary callback ID promoted to primary.

A callback can determine its role before step 1 and read processors after step 1. In that window an old-primary callback can read the newly promoted secondary processors while the secondary callback is still using the same processor objects. The biquad processors have mutable delay buffers and must never be driven concurrently by two HAL callbacks.

The existing 500 ms retention of the old primary processors does not prevent this generation mix-up. It only keeps old objects alive.

Async invalidation has a related generation boundary: callback IDs are invalidated immediately while CoreAudio teardown finishes later. A subsequent activation must use fresh processor state so a pre-invalidation callback can never observe processors created for the new activation.

## Required behavior

- Each IO proc closure captures one stable `TapProcessorState` at creation time.
- `processAudioCallback` obtains DSP processors only from that captured state, never by selecting controller-wide primary/secondary processor properties from the callback role.
- Primary/secondary promotion changes controller ownership of processor generations without changing the state captured by either existing IO proc.
- A promoted secondary IO proc keeps using the same processor state it used while secondary.
- The retired primary IO proc keeps using its old processor state until CoreAudio releases that closure.
- Invalidation rotates controller processor generations before a later activation can populate new processors.
- Failed/re-entrant secondary creation resets the secondary processor generation even when CoreAudio resources have already been cleared.
- Ordinary EQ/AutoEQ/loudness updates continue to target the currently owned primary and secondary generations.
- No lock, allocation, logging, actor hop, or wait is added to the HAL callback.
- No dependency on draft PR #6, #7, or #8.

## Test seam

`TapProcessorGenerations` is the seam. Tests must prove:

1. an IO proc state captured before promotion keeps its original identity;
2. promotion makes the former secondary generation the controller's primary generation and creates a fresh secondary generation;
3. reset creates fresh primary and secondary generations so a later activation cannot mutate state captured by an old callback.

## Acceptance criteria

1. Crossfade promotion no longer moves four processor pointers independently across callback roles.
2. The fixed 500 ms old-primary processor retention block is removed.
3. Every IO proc creation path captures a stable processor generation and passes it to `processAudioCallback`.
4. `processAudioCallback` does not read controller-wide EQ/AutoEQ/loudness processor properties.
5. Build and full non-UI test suite pass on the final exact head.
6. Final diff remains narrowly scoped to callback processor-generation ownership.