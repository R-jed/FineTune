# FineTune UI Quality U1–U5 Result

## U1 Slice 1

Status: COMPLETE

Scope boundary: pure presentation semantics plus minimal App Row and Tahoe HUD integration. U1 Slice 2 has not started.

### Product commit

`fc8e2689a38a86a5eb78515510f5aa00366099e3` — `feat(ui): add U1 presentation state seam`

### Verified behavior

- `VolumePresentationState` is the pure seam for visible volume, mute-equivalent state, source activity, and unmute restoration.
- Explicit mute preserves the stored backend volume while the UI presents slider 0 and 0%.
- Explicit unmute restores a meaningful stored value; zero/no-history falls back to 50%.
- `AppPresenceGroup` freezes hidden, pinned, normal, and absent grouping semantics without changing ordering yet.
- App row drag, scroll-wheel adjustment, and typed values above zero now unmute consistently; zero does not spuriously unmute.
- App zero-volume explicit unmute now uses the shared 50% fallback instead of the previous App-only 100% jump.
- Tahoe HUD consumes the same presentation seam, so muted non-zero device volume presents 0% while retaining the underlying stored volume.
- Source-activity semantics remain independent from visible mute. VU wiring is unchanged in this slice.

### Scope control

Production diff from RED head `032f63c6b5d1ab3634649ac0ee840a7a102f93cb` is limited to:

- `FineTune/Models/AudioPresentationState.swift`
- `FineTune/Views/Rows/AppRowControls.swift`
- `FineTune/Views/HUD/TahoeStyleHUD.swift`

No audio engine, routing, persistence, tap lifetime, process discovery, output/input device row, Classic HUD, menu-bar icon, pin ordering, or motion-system implementation was changed.

### Verification

CI run #287 (`33090886389`) ran on exact product SHA `fc8e2689a38a86a5eb78515510f5aa00366099e3`:

- Build: PASS
- Complete non-UI Tests: PASS
- Test result upload: PASS

### Result and lesson

The contradiction could be fixed at a small presentation seam without changing backend audio state. Direct manipulation still needs a local transient value while the backend catches up; keeping that transient state inside the view avoids moving UI timing concerns into the model.

Next allowed work is U1 Slice 2 only when explicitly resumed. This result does not claim U1–U5 completion or final merge readiness.

## U5 Slice 7 — Reorder Accessibility Automation

Status: AUTOMATED PASS / REAL-MACHINE PENDING

Scope boundary: accessible App reorder alternatives only. This does not claim the full U5 accessibility matrix or measured-performance gate.

### Product commit

`6e27e3f64cebbeb108ebe338b150453388e86482` — `feat(ui): add accessible app reordering`

### Verified behavior

- Active and pinned-inactive App identity elements expose `Move Up` and `Move Down` accessibility actions when the corresponding move is valid.
- The accessibility path reuses `AppListPresentationOrder.reorderTarget` and the existing `AudioEngine.moveApp` / `AppListCoordinator` mutation path.
- No second accessibility-only ordering algorithm was introduced.
- Actions are omitted at the outer list boundaries and at the Pinned/Normal group boundary.
- Existing pointer drag behavior and the hidden visual drag-handle accessibility treatment remain unchanged.
- Volume, mute, route, EQ, pin, and other nested controls remain separate sibling controls rather than being merged into the reorder accessibility element.

### Deterministic coverage

`AppListPresentationOrderTests` covers:

- valid adjacent movement inside the Pinned group
- valid adjacent movement inside the Normal group
- rejection at the Pinned/Normal boundary
- rejection at the first and last list boundaries

`AppReorderGroupBoundaryTests` also proves the underlying mutation seam rejects cross-group writes while still allowing same-group reorder.

### Verification

CI run #307 (`33109250811`) ran on exact product SHA `6e27e3f64cebbeb108ebe338b150453388e86482`:

- Build: PASS
- Complete non-UI Tests: PASS
- Test result upload: PASS

Fixed-point product diff from `5b03b45afd396aa87af61f256cdc07a753f59cd4` is limited to:

- `FineTune/FineTuneApp.swift`
- `FineTune/Views/Components/AppReorderAccessibility.swift`
- `FineTune/Views/Rows/AppRow.swift`
- `FineTune/Views/Rows/InactiveAppRow.swift`

### Review result

Standards axis: PASS for the automated slice. The change stays on `@MainActor`, does not touch audio callbacks, routing, persistence, DSP, or process discovery, and keeps row-owned state unchanged.

Specification axis: AUTOMATED PASS / EXIT GATE PENDING. The source and tests satisfy the U5.2 reorder semantics, but the U5 Slice 7 exit gate explicitly requires real-machine Full Keyboard Access and VoiceOver validation.

### Pending real-machine acceptance

Do not mark Slice 7 complete until a real Mac verifies:

- `Move Up` / `Move Down` are discoverable and callable through VoiceOver on active and pinned-inactive Apps
- boundary actions are absent when movement is invalid
- focus remains usable for nested volume, mute, route, EQ, and pin controls
- the reordered position is reflected/announced acceptably after the action
- popup focus, Escape, outside-click, and modal/picker behavior satisfy the full U5 keyboard/VoiceOver matrix

### Performance note

The accessibility modifier queries `audioEngine.displayableApps` when deriving available actions. `displayableApps` reconstructs and sorts the presentation list. This is a static performance hypothesis only. Per U5 policy, it must be measured with the final-head Instruments scenarios before any optimization is justified.

### Result and lesson

The safest accessibility path is to reuse the same pure target policy and mutation seam as pointer reorder, with the persistence coordinator retaining an independent fail-close boundary. Automated correctness can prove ordering semantics, but it cannot prove VoiceOver discoverability, Full Keyboard Access behavior, focus hierarchy, or announcement quality.

U5 Slice 8 must not start until the Slice 7 real-machine exit gate passes. Final merge readiness remains HOLD.
