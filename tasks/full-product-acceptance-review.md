# Full Product Acceptance Review

Status: active integration review before local macOS acceptance.

Baseline: PR #10 (`integration/full-product-acceptance`).

This review treats the integrated product as one system. Earlier PR titles do not define the final behavior when later work changes the product contract.

## App discovery and visibility invariants

1. A running regular macOS application remains visible even when it is not currently producing audio.
2. Pinning means the app remains represented after its process exits. Pinning does not control whether a currently running app is visible.
3. Unpinning a running app never starts an audio-activity grace timer and never hides it merely because it is quiet.
4. Hiding is reversible presentation state. Hiding must preserve pin state, app order, volume, mute, boost, EQ, device routing, and multi-device selection.
5. Restoring a hidden app restores the same product state. A manually added inactive pinned app must reappear after Hide → Restore.

## App identity and tap invariants

1. `persistenceIdentifier` is the durable app identity. PID is only the current process representative.
2. A tap may belong to only one current app identity.
3. When one bundle has multiple processes and the representative PID changes, the old representative tap must be retired before a new representative tap is provisioned.
4. When macOS reuses a PID for another app identity, the old tap and all transient `VolumeState` fields must be discarded before settings for the new identity are applied.
5. Process-list change detection must include app identity, not only PID, Core Audio object IDs, and audio-active state.

## Existing behavior preservation

1. App volume sliders retain mouse-wheel adjustment.
2. Active and inactive app rows use the same stable `PopupKeyboardNavModel.RowID.app(persistenceID:)` identity so keyboard auto-scroll and EQ expansion target the rendered row.
3. Source-activity metering remains the PR #7 behavior.
4. Biquad realtime quiescence and tap processor-generation ownership remain the PR #8/#9 behavior.

## Persistence invariant

Settings writes must be ordered. An older debounced save may never finish after a newer save or termination flush and overwrite newer state. A synchronous flush must drain prior queued writes and leave the current in-memory snapshot last on disk.

## Acceptance gates

Before local macOS acceptance:

- every confirmed blocker in this document is repaired at the root cause
- focused regression tests pass
- the complete repository non-UI test suite passes on the exact integration head
- Build passes on the exact integration head
- final diff review finds no temporary workflows/scripts or unrelated product drift introduced by the repairs

PR #10 remains Draft and unmerged until explicit authorization.