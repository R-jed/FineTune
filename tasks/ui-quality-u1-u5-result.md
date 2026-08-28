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

## U1–U5 Source Closure Candidate

Status: AUTOMATED SOURCE PASS / REAL-MACHINE AND INSTRUMENTS PENDING

This section records the frozen-spec source closure after the post-review repair pass. It does not override the real-machine, VoiceOver/Full Keyboard Access, A/B, or measured-performance exit gates.

### Product commits

`b6814af6f30eb47a99b11dae1e609e8793dcb30f` — `fix(ui): close U1-U5 source quality gaps`

`4598ac27faee2fb941e1e1899b0da445cfd9b3a8` — `fix(accessibility): align zero-volume HUD announcement`

`8c42245eab2596a55a85e508b86c4e89efd13bb2` — `refactor(ui): remove popup output command pass-through`

### Source closure

- U1 now uses shared presentation and command seams instead of row/HUD-specific mute and volume formulas. `AppVolumeCommandPlan` owns per-App mapping/order; `OutputVolumeCommandPlan` owns backend-aware hardware/DDC/software ordering; output commands recover the stored pre-mute software/DDC value before user adjustments. Explicit unmute with no usable history uses the shared 50% display-domain fallback. A visible zero remains mute-equivalent without forcing the explicit mute Boolean.
- Media keys, popup keyboard commands, global App shortcuts, Tahoe interactive HUD writes, device rows, App rows, input rows, Classic/Tahoe HUD presentation, and the speaker menu-bar icon now converge on those seams. DDC direct writes publish volume/mute callbacks so the final target is not left stale after DDC restore ordering.
- Device HUD accessibility announcements also derive their muted-equivalent state through `VolumePresentationState`. An explicit `mute == false` state whose visible volume is 0% now announces as muted-equivalent instead of contradicting the HUD's icon/slider presentation.
- The popup's one-use output-command forwarding helper was removed after source closure; device rows now call the existing `DeviceVolumeMonitor.applyOutputCommand` seam directly. This is a behavior-preserving entropy reduction and does not introduce a new command path.
- U2 source ownership is reduced to one semantic animation owner for the audited structural interactions, with Reduce Motion routing at those owners. Popup geometry follows SwiftUI intermediate sizes without adding a second AppKit interpolation owner. This is source closure only; rapid-reversal and rendered motion acceptance remain real-machine gates.
- U3 uses `PopupDevicePriorityEditMode` as the Output/Input edit owner. Output edit contains output-device priority plus App visibility/pin/reorder management; Input edit remains input-priority only. App reordering reuses `AppListPresentationOrder.reorderTarget` and the existing engine mutation path. Programmatic row selection uses minimal unanchored reveal, and audited vertical scroll areas reserve trailing content space.
- U3 Compact source budget now closes without deleting a control: 422 pt available / 422 pt minimum. Comfortable is 454 / 442 and Spacious is 496 / 462. These figures include the popup trailing scroll gutter, expandable-row padding, 96 pt App identity minimum, current density slider widths, and current control spacing. Whether 96 pt is sufficiently readable and whether the final control spacing/management placement is preferable remain A/B and real-machine questions.
- U4 source gates now use the 20 pt minimum actionable target where source geometry is explicit, keep user-facing informational text at or above 10 pt, avoid scaling native Toggles, preserve true-zero slider fill, and use automatic Settings scroll indicators. Remaining sub-10-pt matches in the audited UI are decorative SF Symbols rather than informational text.
- U5 Output-edit App rows expose conditional `Move Up` / `Move Down` custom accessibility actions from the same canonical reorder availability used by pointer controls. Boundary actions are omitted by the canonical target policy; no accessibility-only reorder algorithm was added.

### Deterministic coverage added or extended

- shared visible-zero rounding boundary (`0.004 → 0%`, `0.006 → 1%`)
- App command order, zero contract, and 50% explicit-unmute fallback
- software/DDC output command order and zero-history fallback
- muted software/DDC stored-volume recovery
- outer media-key use of stored output volume and HUD result
- shortcut zero-volume semantics
- Output-vs-Input edit ownership and repeated tab-transition cleanup policy
- HUD percentage/presentation convergence through `VolumePresentationState`
- zero-volume device HUD accessibility announcement with the explicit mute flag cleared

### Verification evidence

- On the `b6814af` source-closure candidate, focused U1/U3 suites passed, the complete non-UI suite passed with 926 tests / 0 failures / 0 skipped, and the Debug Build passed.
- On the subsequent `4598ac2` HUD accessibility delta, `swiftc -parse` passed for the changed production/test files and `git diff --check` passed. The local bridge rejected the Xcode-beta developer path while the host `xcode-select` remained on CommandLineTools, so no local post-delta Xcode test/build pass is claimed.
- Exact-head CI for `4598ac27faee2fb941e1e1899b0da445cfd9b3a8` passed in GitHub Actions run `33178180776`: both Build and Test completed successfully.
- On the behavior-preserving `8c42245` simplification delta, `swiftc -parse FineTune/Views/MenuBarPopupView.swift` and `git diff --check` passed. Its final verification is intentionally folded into the next exact-head PR CI together with this result-only documentation update.
- Independent CURRENT source reviews after `4598ac2` found no remaining U1, U2, U3, or U4 Critical/Required source blocker. A separate five-axis correctness/readability/architecture/security/source-proven-performance review also found no remaining Critical/Required source blocker. U5 source-level reorder availability/actions remain closed; VoiceOver/FKA behavior and performance stay gated by real-machine/Instruments evidence.
- Fixed-point review passed after the product commits; no unexpected worker write or unreviewed production-file drift was observed. The only local working-tree change after the product push is this result document.

The existing test harness still emits SwiftUI warnings when a few tests inspect `@State`-backed views without mounting them. Those warning-producing test patterns predate this closure pass; the current `U1CrossSurfacePresentationTests` changes only update row initializer seams. They are not counted as a new product regression.

### Pending frozen exit gates

Final merge readiness remains HOLD until all of the following are completed on the final exact head:

- U1 real-machine App/output/input/Tahoe/Classic/menu-icon parity, including physical hardware/DDC behavior where applicable
- U2 rapid-reversal, Reduce Motion, reorder feel, and Output/Input transition acceptance
- U3 Compact/Comfortable/Spacious representative-name matrix, forced-scroll overlap checks, and the required native-segmented-vs-custom A/B decision
- U4 Light/Dark Liquid Glass hierarchy, true-zero slider resting affordance, native-control hit geometry where source cannot prove it, and final density/spacing visual acceptance
- U5 Full Keyboard Access and VoiceOver discoverability/focus/action/announcement matrix
- U5 Instruments measurements for the frozen performance scenarios; no static performance hypothesis is promoted to pass or blocker without measurement

The pull request must remain Draft/unmerged while any item above is pending.
