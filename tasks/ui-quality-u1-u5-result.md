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
