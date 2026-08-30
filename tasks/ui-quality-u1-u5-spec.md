# FineTune UI Quality U1–U5 Specification

Status: specification frozen for planning; implementation not started

Branch: `feat/reorder-liquid-glass-ui`

Specification baseline: `d2e77b6ff0df1f350684d24fee52ae4a37041ac5`

Original popup-iteration fixed point: `639af28e4a8123e1bbc655591a6586c2b8420c17`

## Purpose

This document turns the post-implementation UI review into five buildable workstreams with explicit state semantics, Human Interface Guidelines acceptance criteria, test seams, and a repair plan.

The five workstreams are:

1. U1 — Presentation Semantics
2. U2 — Interaction and Motion System
3. U3 — Popup Information Architecture
4. U4 — Visual and Liquid Glass System
5. U5 — Accessibility and Performance Acceptance

The sequence is intentional. U1 defines what state means to the user. U2 defines how state changes. U3 lays out those states and controls. U4 establishes the visual system. U5 is the final independent acceptance gate.

No production code should be changed from this document alone. Each implementation slice must preserve the fixed-point functional behavior unless the slice explicitly changes user-facing UI semantics below.

## Evidence classification

Use these labels throughout implementation and review:

- **CONFIRMED** — directly observed in current source or real-machine screenshots/behavior already reviewed.
- **TARGET** — product behavior specified by this document.
- **INFERENCE** — plausible design/performance risk that requires a prototype or measurement.
- **MEASUREMENT REQUIRED** — cannot be promoted to a defect without real-machine or Instruments evidence.

## Current quality status matrix

| Axis | Current status | Gate to pass |
| --- | --- | --- |
| Core audio/business behavior | PASS | Must remain unchanged except explicit U1 presentation semantics |
| Automated non-UI regression suite | PASS | Exact-head Build + complete non-UI Tests remain green |
| Presentation semantics | FAIL | U1 state matrix passes across App, output, input, and HUD surfaces |
| Interaction consistency | FAIL | U2 interaction contracts pass for pointer, scroll wheel, keyboard, and typed input |
| Motion system | FAIL | U2 motion matrix passes with no time lock and complete Reduce Motion coverage |
| Popup information architecture | FAIL | U3 row density, edit-mode ownership, pin grouping, and scrollbar clearance pass |
| Light/Dark Liquid Glass visual system | FAIL | U4 visual acceptance passes on real hardware |
| Control target sizing | FAIL | U4/U5 minimum target rules pass |
| Text legibility | FAIL | U4 text-size rules pass |
| Drag accessibility | FAIL | U5 VoiceOver/keyboard reorder alternatives pass |
| Keyboard and VoiceOver | PENDING REAL-MACHINE | U5 matrix passes |
| SwiftUI/AppKit performance | PENDING INSTRUMENTS | U5 A/B profile gate passes |
| Final merge readiness | HOLD | U1–U5 + exact-head CI + real-machine acceptance all pass |

---

# U1 — Presentation Semantics

## Problem statement

FineTune currently allows individual views to derive visible volume, mute, source activity, pin, active/inactive, and offline presentation independently. This creates contradictory states. Examples confirmed in the current UI include a muted source still showing its stored percentage, a zero-percent App using a mute-style icon with a separate unmute restoration rule, and Classic/Tahoe HUDs presenting mute differently.

## Solution

Create one pure presentation seam that converts underlying audio/settings state into user-visible state. Views consume the derived presentation values and continue sending commands through existing audio/settings mutation paths.

The seam must not own DSP, routing, Core Audio state, persistence, tap lifetime, or process discovery.

### U1.1 Volume state vocabulary

Use the following terms consistently:

- **stored volume** — the persisted/current non-presentation volume value used by the underlying audio path.
- **mute state** — explicit mute Boolean where the backend supports it.
- **display volume** — the value shown by the slider and percentage.
- **effective output** — whether audible output is currently zero because of mute or zero volume.
- **source activity** — whether the source is emitting audio before the visible mute/volume presentation is applied.

### U1.2 Volume presentation state matrix

| Stored volume | Muted | Source activity | Display slider | Display percent | Mute control | Activity meter | Unmute result |
| ---: | :---: | :---: | ---: | ---: | --- | --- | --- |
| > 0 | false | active | stored mapped value | stored mapped percent | unmuted symbol | may animate from source activity | unchanged |
| > 0 | false | idle | stored mapped value | stored mapped percent | unmuted symbol | idle | unchanged |
| > 0 | true | active | 0 | 0% | muted symbol | may still show source activity | restore stored volume |
| > 0 | true | idle | 0 | 0% | muted symbol | idle | restore stored volume |
| 0 | false | any | 0 | 0% | muted-equivalent visual | activity remains source-derived | explicit volume increase unmutes |
| 0 | true | any | 0 | 0% | muted symbol | activity remains source-derived | restore remembered non-zero volume, otherwise 50% |

### U1.3 Cross-surface rules

The matrix above applies to:

- active App rows
- pinned inactive App rows where the control remains meaningful
- output-device rows
- input-device rows, using microphone mute symbols
- Tahoe HUD
- Classic HUD
- menu-bar volume icon state where it represents the same output state

The following are explicit product decisions:

1. Muting does not visually preserve a non-zero percentage. The UI displays 0% while mute remains active.
2. Muting must not destroy the stored pre-mute value.
3. Dragging, keyboard adjustment, scroll-wheel adjustment, or typing a value above 0 while muted unmutes through one shared command path.
4. Typing exactly 0 and dragging to 0 use the same zero-volume contract.
5. If an explicit unmute is requested while no non-zero value can be restored, use 50% as the shared fallback. This matches the existing software-device fallback and removes the current App-specific 100% jump.
6. The VU/source meter represents source activity and is therefore allowed to remain active while the App is muted.
7. A muted or zero-output state must remain visually distinguishable from an offline/inactive state.

### U1.4 App presence and pin state matrix

| Process state | Pinned | Hidden | Main list presence | Visual emphasis | Order group |
| --- | :---: | :---: | --- | --- | --- |
| active | no | no | visible | normal | Normal |
| active | yes | no | visible | normal | Pinned |
| inactive | yes | no | visible | secondary status treatment, controls that remain valid stay legible | Pinned |
| inactive | no | no | absent after existing cleanup rules | n/a | n/a |
| any | any | yes | hidden from normal main list | n/a | Hidden management only |

Pin means “keep this App in the primary list and keep it in the Pinned group.” Within Pinned and Normal groups, preserve explicit user order. Toggling pin changes group membership while retaining a deterministic order.

## User stories

1. As a user, I want every muted volume surface to show 0%, so I can read audible state without translating hidden internal values.
2. As a user, I want unmute to restore the value I was using before mute, so mute behaves reversibly.
3. As a user, I want adjusting volume above zero to unmute consistently whether I drag, scroll, press a key, or type a number.
4. As a user, I want a zero-volume App to behave consistently with a zero-volume device.
5. As a user, I want the activity meter to tell me whether an App is producing audio even when I muted its output.
6. As a user, I want inactive Apps to look inactive without making valid controls look disabled.
7. As a user, I want pinned Apps to appear in an obvious pinned group so the pin symbol has predictable meaning.
8. As a user, I want hidden Apps to stay out of the normal list and be managed only from the relevant management context.

## Implementation decisions

- Introduce one pure derived presentation model or equivalent pure functions at the highest reusable seam.
- Do not duplicate mute/display-volume calculations in individual rows or HUDs.
- Reuse existing mutation methods for actual volume/mute changes.
- Avoid a new persistence field unless a failing test proves the existing stored-volume information cannot satisfy the restoration contract.
- Reuse the existing 50% software-device fallback as the no-history fallback for explicit unmute from zero.
- Keep source-activity metering independent from mute presentation.

## Testing decisions

Highest seam first:

1. Pure presentation-state tests covering every row in the U1 matrix.
2. Existing volume/mute model tests for command behavior and restoration.
3. Focused row/HUD presentation tests only where a state cannot be proven at the pure seam.
4. Real-machine checks for App, output device, input device, Tahoe HUD, Classic HUD, and menu-bar icon parity.

Tests assert user-observable state and command results, not private view implementation.

---

# U2 — Interaction and Motion System

## Problem statement

FineTune currently mixes multiple springs, scale effects, rotations, matched geometry, window resizing, and time-based guards. Frequent actions can feel overly elastic, and the EQ toggle currently blocks repeated input for about 400 ms. Reduce Motion is handled in several components but not through one complete policy.

## Solution

Define a small semantic motion system. Each interaction has one animation owner, is interruptible, and preserves immediate user control.

### U2.1 Interaction contract

The same logical change must behave consistently from:

- pointer click
- pointer drag
- scroll wheel where supported
- keyboard arrows/shortcuts
- typed percentage entry
- VoiceOver action in U5

No input method may silently bypass mute restoration, clamping, ordering, or persistence rules owned by the shared command seam.

### U2.2 Motion matrix

| Interaction | Motion class | Target behavior | Reduce Motion |
| --- | --- | --- | --- |
| Mute, Pin, Boost state change | immediate state feedback | color/symbol state change; no semantic hover inversion; avoid decorative rotation; no operation lock | immediate |
| Button press | immediate feedback | restrained system/native press feedback; no stacked custom scale effects | system/minimal |
| Volume/EQ slider drag | direct manipulation | 1:1 with pointer; no smoothing lag | unchanged direct manipulation |
| Row reorder | spatial manipulation | dragged row follows pointer; siblings settle with one shared glide | direct movement, minimal/no decorative glide |
| EQ expand/collapse | structural transition | smooth, interruptible, reversible from current progress | immediate or short fade/size transition |
| Device detail expand/collapse | structural transition | same family as EQ | immediate or short transition |
| Output/Input switch | view-mode transition | one owner, short and stable; no stacked content + selector + window springs | immediate or short crossfade |
| Popup size change | window transition | smooth and coalesced; no queued resize backlog | immediate frame update |
| Settings gear hover | none | no 180-degree rotation | none |

### U2.3 Hard motion rules

1. No time-boxed interaction lock for EQ, tabs, pin, mute, or expandable panels.
2. A repeated click during an animation reverses or retargets from the current rendered state.
3. A single state change must not be animated by multiple unrelated parent/child animation modifiers.
4. Hover must never preview the opposite semantic state. Hover can change emphasis only.
5. Frequent controls should prefer native system feedback over extra decorative motion.
6. Reduce Motion must remove decorative transforms and long positional easing while preserving all functionality.
7. Animation scope must be local to the state being animated.

## User stories

1. As a user, I want a second EQ click to work immediately even if the first transition is still running.
2. As a user, I want mute and pin to feel instant because I use them frequently.
3. As a user, I want dragging and sliders to track my pointer exactly.
4. As a user, I want Output/Input switching to feel like a single view change rather than several animations firing together.
5. As a Reduce Motion user, I want the complete popup to remain usable without decorative movement.

## Implementation decisions

- Remove the EQ timing guard and let SwiftUI animation interruption handle reversal.
- Replace duplicated animation constants with semantic motion tokens only where more than one call site truly shares a contract.
- Prototype the Output/Input selector with native segmented Picker behavior before retaining the custom matched-geometry implementation.
- Keep custom motion only when it provides product value that the system component does not provide.
- Coalesce popup geometry-driven frame changes only if U5 measurement shows duplicate/queued resize work; do not add debounce from static suspicion.

## Testing decisions

- Deterministic tests for command/state transitions.
- A regression test that performs EQ open → immediate close without waiting.
- A regression test for repeated Output/Input switching and edit-mode cleanup.
- Reduce Motion tests at the state/transaction seam where possible.
- Real-machine 20x rapid-interaction acceptance for EQ, tabs, mute, pin, and expandable device detail.

---

# U3 — Popup Information Architecture

## Problem statement

The popup currently gives too many controls equal horizontal priority. The App controls group is fixed-size, causing the App label to absorb compression. Edit mode always includes App visibility management, including while viewing input devices. Scroll indicators can overlap trailing actions. Pin semantics are not reflected as a visible grouping.

## Solution

Rebuild the popup hierarchy around primary audio tasks, context-specific management, and predictable grouping while keeping FineTune fast for expert use.

### U3.1 Primary row hierarchy

Always prioritize:

1. App/device identity and status
2. Mute
3. Volume slider
4. Percentage

Secondary fast controls may remain directly visible when width permits:

- Boost
- Route
- EQ

Management controls belong to the editing/management layer where practical:

- Pin
- Hide
- Reorder handle

A prototype may keep one or more management actions in the normal row if moving them would materially reduce FineTune's fast-control value. The final choice must be based on the Compact/Comfortable/Spacious A/B prototype, not on preserving the current layout by default.

### U3.2 Compression rules

- App/device names get a meaningful minimum readable width before optional controls consume space.
- Do not solve width pressure by reducing text below the U4 minimum.
- Avoid a trailing controls container that unconditionally claims its ideal width if that makes common App names truncate prematurely.
- Compact mode may hide or consolidate secondary controls before violating control-target or text-size gates.
- Tooltip/help remains available for genuinely truncated long names.

### U3.3 Output/Input ownership

Output and Input are closely related views and share a switcher.

- Output edit mode owns output-device priority plus App visibility/pin/reorder management.
- Input edit mode owns input-device priority only.
- App visibility management must not appear under Input.
- Switching Output/Input exits or reconciles the previous edit mode deterministically before presenting the next pane.

### U3.4 Scrolling

- Any vertical scroll area reserves a trailing interaction-safe gutter.
- Scrollbars must never cover Pin, Hide, EQ, Route, or reorder controls.
- Settings pages use automatic/system scroll indicators unless real-machine testing proves the content is fully visible without scrolling.
- The popup may use overlay/system scroll indicators, but controls must remain clear of their active region.
- Programmatic keyboard scrolling moves only as far as necessary to keep the selected row visible.

### U3.5 Pin grouping

Primary App list order:

1. Pinned Apps, in user order
2. Normal active Apps, in user order with deterministic fallback for unseen Apps

Pinned inactive Apps remain in the Pinned group with secondary inactive presentation.

## User stories

1. As a user, I want common App names to remain readable in normal popup sizes.
2. As a user, I want volume controls to remain immediately available without every management action competing for width.
3. As a user, I want Input edit mode to show only input-related management.
4. As a user, I want the scrollbar to stay away from interactive controls.
5. As a user, I want pinned Apps to appear together at the top in my chosen order.

## Implementation decisions

- Preserve the existing durable App identity and reorder state machine.
- Refactor layout priority before changing underlying App ordering storage.
- Preserve explicit `appOrder` as the ordering source inside the Pinned and Normal groups where possible.
- Prototype native `.pickerStyle(.segmented)` for Output/Input against the current custom control.
- Do not introduce another popup navigation architecture unless the existing single-view approach cannot meet the matrix.

## Testing decisions

- Pure ordering tests for Pinned/Normal/Hidden grouping.
- Edit-mode content tests for Output vs Input ownership.
- Snapshot/visual tests across all three popup sizes for representative short, medium, and very long App names where stable enough.
- Real-machine scrollbar overlap checks using enough rows to force scrolling.

---

# U4 — Visual and Liquid Glass System

## Problem statement

The popup host now owns a correct single modern glass boundary, but content-level visual decisions still include very small controls/text, scaled system controls, repeated card borders, hidden scroll indicators, and several legacy visual tokens/helpers. Light appearance remains the highest-risk visual acceptance surface.

## Solution

Keep one popup-level Liquid Glass host, use native/system controls where practical, use standard content-layer materials sparingly, and enforce macOS legibility/target-size rules.

### U4.1 Liquid Glass hierarchy

Modern macOS path:

- one popup-level `NSGlassEffectView`
- real hosted SwiftUI content is the glass `contentView`
- no redundant popup-level standard material or fixed white/black tint layered over the host
- content cards use normal content surfaces/standard materials only when needed for hierarchy
- avoid turning every row into an independent glass surface

Older supported macOS path:

- one isolated standard `.popover` material fallback
- same semantic content and interaction behavior as the modern path

### U4.2 Control sizing

Apple HIG reference values for macOS:

- default control target: 28 × 28 pt
- minimum control target: 20 × 20 pt

FineTune acceptance:

- no actionable pointer target below 20 × 20 pt
- primary row actions should target 24–28 pt where layout permits
- visual glyph may remain 12–14 pt inside the larger hit region
- spacing between adjacent controls must make accidental activation unlikely

### U4.3 Typography

Apple HIG reference values for macOS:

- default custom/system text size: 13 pt
- minimum: 10 pt

FineTune acceptance:

- no user-facing information text below 10 pt
- body/row names target 13 pt
- secondary labels target 10–12 pt
- 9 pt EQ/card/status text must be raised or replaced by an appropriate system text style
- do not use smaller type as the solution to popup width pressure

### U4.4 Native controls

- Prefer native SwiftUI controls for standard behavior when they can meet the product requirement.
- Use `controlSize` instead of scaling a system Toggle to 70%.
- Prototype system segmented Picker before maintaining the custom Output/Input selector.
- Keep the native Slider accessibility/focus behavior visible enough that the control reads as interactive at rest.
- The custom track must render a true zero-length accent fill at 0 instead of forcing a minimum accent segment.

### U4.5 Settings visual hierarchy

- Reduce card-within-card framing where spacing, headings, and separators already establish grouping.
- Preserve semantic grouping and destructive-action clarity.
- Use automatic scroll indicators for Settings pages that can overflow.
- Keep Light, Dark, and System appearances structurally identical.

### U4.6 Legacy cleanup

After functional/visual changes are proven:

- remove or rename obsolete no-op visual helpers/tokens that no longer represent runtime behavior
- migrate soft-deprecated SwiftUI syntax only inside touched UI seams when low risk; do not turn U4 into a broad cleanup campaign

## User stories

1. As a user, I want controls to be easy to hit without making the popup look oversized.
2. As a user, I want every label to remain legible in Light and Dark mode.
3. As a user, I want FineTune to feel native to current macOS rather than like stacked custom frosted cards.
4. As a user, I want the same hierarchy in Light, Dark, and System appearances.
5. As a user, I want standard controls to behave like other Mac controls.

## Testing decisions

Real-machine visual matrix:

- Light / Dark / System
- bright wallpaper / dark wallpaper
- Compact / Comfortable / Spacious
- Reduce Transparency on/off
- Increase Contrast on/off
- Reduce Motion on/off
- current system Liquid Glass appearance preferences when exposed by the OS
- long names and forced scrolling

Automated checks should cover token invariants and pure layout/state decisions where stable; pixel-perfect tests must not become a substitute for real-machine material acceptance.

---

# U5 — Accessibility and Performance Acceptance

## Problem statement

FineTune has strong custom popup keyboard navigation, but drag reordering currently relies on pointer gestures and hides the drag handle from accessibility. Full Keyboard Access and VoiceOver behavior for nested row controls still requires real-machine confirmation. Performance risks around per-row timers, geometry-driven window resize, large App reorder lists, and glass/shadow compositing remain unmeasured.

## Solution

Treat accessibility and measured performance as release gates after U1–U4. Add accessible alternative actions at existing mutation seams and profile the exact final head on the host Mac with Instruments.

### U5.1 Accessibility action matrix

| Feature | Pointer | Keyboard | VoiceOver | Acceptance |
| --- | --- | --- | --- | --- |
| Row selection/navigation | yes | existing arrow navigation | readable focus/selection | pass on real machine |
| Mute | click | row shortcut/control path | named action/control | state announced correctly |
| Volume | drag/scroll | arrows + typed entry | adjustable action/control | all paths follow U1 rules |
| Route picker | click | Full Keyboard Access | native/custom accessible control | can open, choose, dismiss |
| EQ | click | Return/Space where selected | named control/action | opens/closes without time lock |
| Pin | click | Full Keyboard Access/action | named action | state and result announced |
| Reorder | drag | Move Up / Move Down alternative | custom actions | pointer drag is never the only path |
| Popup dismiss | outside click/Escape | Escape | Escape/accessibility escape behavior | deterministic |

### U5.2 Reorder accessibility

- Keep the visual drag handle discoverable for pointer users.
- Add “Move Up” and “Move Down” accessibility actions to the logical row, reusing the existing reorder mutation/state/order seam.
- Disable or omit an action at the corresponding list boundary.
- Announce/reflect the resulting position through normal accessibility state where practical.
- Do not create a second reorder algorithm for accessibility.

### U5.3 Keyboard acceptance

Verify on a real Mac:

- popup obtains intended focus on open
- up/down row navigation
- left/right volume adjustment
- Shift-modified volume step where supported
- M mute shortcut
- Return/Space activation
- Tab Output/Input behavior
- numeric percentage entry, commit, backspace, Escape cancel
- nested text fields retain editing keys without row activation
- Full Keyboard Access can reach nested primary controls that need individual focus

### U5.4 Performance measurement plan

Use the SwiftUI Instruments template on the host Mac for the final implementation head. Record the immediate pre-U1 baseline (`d2e77b6...`) and the final U1–U4 head on the same Mac, same macOS build, same display configuration, and same scripted interactions.

Also retain `639af28e...` as the historical popup-iteration fixed point for broader comparison.

Scenarios:

1. popup open/close 100x through status item
2. popup open/close 100x through global shortcut
3. Output/Input toggle 100x
4. EQ expand/collapse 100x including rapid reversal
5. device detail expand/collapse 100x
6. Compact/Comfortable/Spacious cycle 100x
7. App/device drag top-to-bottom and bottom-to-top, including reversals
8. 100/250/500 synthetic App rows if a debug-only harness is added
9. rapid mute/volume/default-device/icon-state changes
10. idle for 60 seconds after stress to detect retained tasks/objects

Record:

- SwiftUI update causes and hot views
- main-thread running coverage / CPU hotspots
- animation hitches and visible dropped-frame behavior
- allocations
- peak RSS
- `NSPanel` count
- global/local event-monitor count where observable
- timer wakeups and timer count
- main-actor task accumulation
- popup resize calls and whether work continues after input stops

Investigation threshold:

- repeatable ~10% or greater regression in p95 main-thread work or peak RSS versus `d2e77b6...`
- any monotonic RSS/object growth across repeated open/close cycles
- any accumulating panel/event-monitor count
- visible hitching that is reproducible and attributable to the changed path
- resize or main-actor work continuing after user input has stopped

The 10% threshold starts investigation. It does not automatically prove a defect.

### U5.5 Static performance hypotheses that must remain hypotheses until measured

- one 30 fps timer per active App row may create unnecessary wakeups at large row counts
- geometry-size changes that create main-actor tasks and animated `NSWindow` frame changes may queue under rapid structural changes
- repeated `displayableApps` reconstruction/sorting during drag may scale poorly at synthetic large-list sizes
- drag shadow + Liquid Glass compositing may raise GPU/render cost

Do not optimize any of these solely from static inspection.

---

# HIG and first-party acceptance basis

Only first-party Apple sources are normative for this specification.

1. Apple HIG — Accessibility: macOS default control size 28 × 28 pt, minimum 20 × 20 pt; sufficiently sized controls and spacing reduce interaction errors.  
   https://developer.apple.com/design/human-interface-guidelines/accessibility

2. Apple HIG — Typography: macOS default text size 13 pt, minimum 10 pt; test legibility across contexts and avoid solving readability with thin/small type.  
   https://developer.apple.com/design/human-interface-guidelines/typography

3. Apple HIG — Gestures: custom gestures must be discoverable and must not be the only way to perform an important action.  
   https://developer.apple.com/design/human-interface-guidelines/gestures

4. Apple HIG — Drag and drop: Mac users can perform drag/drop with pointing devices, Full Keyboard Access, or VoiceOver.  
   https://developer.apple.com/design/human-interface-guidelines/drag-and-drop

5. SwiftUI Accessible Controls: `accessibilityAction` and related APIs expose actions to VoiceOver and other assistive technologies.  
   https://developer.apple.com/documentation/swiftui/accessible-controls

6. Apple HIG — Segmented controls: use segmented controls for closely related choices/state and keep grouping/selection clear.  
   https://developer.apple.com/design/human-interface-guidelines/segmented-controls

7. Apple HIG — Popovers: keep transient interfaces focused, support outside-click dismissal, show one at a time, avoid excessive size, and transition smoothly when resizing.  
   https://developer.apple.com/design/human-interface-guidelines/popovers

8. Apple HIG — Motion: motion should support meaning, avoid unnecessary motion in frequent interactions, respect accessibility preferences, and avoid forcing users to wait for animation completion before acting again.  
   https://developer.apple.com/design/human-interface-guidelines/motion

9. Apple HIG — Materials: use Liquid Glass as a functional layer and use it sparingly; standard materials remain appropriate for content-layer hierarchy.  
   https://developer.apple.com/design/human-interface-guidelines/materials

10. AppKit `NSGlassEffectView.contentView`: the supported containment point for content embedded in the glass effect.  
    https://developer.apple.com/documentation/appkit/nsglasseffectview/contentview

11. SwiftUI `MenuBarExtra`: data-rich menu-bar extras may use the window style, confirming that complex menu-bar utilities can legitimately present a popover-like window rather than a simple menu.  
    https://developer.apple.com/documentation/swiftui/menubarextra

# Repair research findings

## Confirmed source-level findings

1. App row controls currently derive slider display from stored volume even when `isMuted` is true; mute only changes icon/opacity.
2. The App mute button treats displayed 0% as a muted-equivalent state and restores directly to 100% on explicit unmute from zero.
3. Software device unmute already restores a remembered volume and falls back to 50% if no non-zero value is available.
4. The custom slider forces the accent fill to at least its track height, so a zero value still renders a short colored segment.
5. The EQ toggle has a time guard and clears it after roughly 0.4 seconds.
6. Output/Input switching is driven by a spring while the selector also uses matched geometry and the popup host may resize from geometry changes.
7. The Settings gear rotates 180 degrees on hover.
8. App controls use a fixed-size trailing group, giving the label region most compression pressure.
9. Edit mode always includes App visibility management, regardless of Output/Input tab.
10. `DesignTokens.Dimensions.minTouchTarget` is 16 pt, below Apple's 20 pt macOS minimum guidance.
11. Several user-visible type tokens/labels use 9 pt, below Apple's 10 pt macOS minimum guidance.
12. The visual reorder handle is hidden from accessibility and no equivalent Move Up/Move Down path is currently specified.
13. The current FineTune-owned popup host correctly embeds SwiftUI content as `NSGlassEffectView.contentView` on the modern path.

## Reasonable inferences requiring prototype or measurement

1. A native segmented Picker may reduce custom animation/focus complexity for Output/Input without reducing functionality.
2. Reallocating row width from secondary/management actions to App identity should reduce premature name truncation.
3. A shared presentation model should eliminate several current UI contradictions without changing audio internals.
4. Coalescing popup resize work may improve structural transitions if Instruments shows queued frame updates.
5. A shared activity clock may reduce wakeups if Instruments confirms per-row timer overhead at realistic list sizes.

# Planned implementation slices

Implementation must be tracer-bullet and independently verifiable.

## Slice 1 — U1 pure presentation seam

- Add the smallest pure presentation model/functions for mute, display volume, restoration fallback, activity independence, and App presence grouping.
- Add exhaustive state-table tests first.
- Wire one App surface and one HUD surface through the seam.
- Verify no audio-engine mutation behavior changes beyond the explicit 0%-unmute contract.

Exit gate: U1 pure tests green + App/Tahoe parity proven.

## Slice 2 — U1 remaining surface parity

- Wire output, input, inactive App, Classic HUD, and relevant menu-bar icon presentation.
- Remove duplicated local presentation formulas only after parity tests exist.

Exit gate: full U1 matrix green.

## Slice 3 — U2 interaction/motion cleanup

- Remove EQ time lock.
- Normalize volume input paths through shared command behavior.
- Remove semantic hover inversion and decorative gear rotation.
- Remove stacked press/motion effects where system feedback is sufficient.
- Centralize only genuinely shared semantic motion values.

Exit gate: rapid-reversal and Reduce Motion tests + real-machine 20x interaction pass.

## Slice 4 — U2/U3 Output/Input prototype gate

Build two short-lived implementations behind a debug/prototype seam:

A. current custom selector with one animation owner
B. native segmented Picker

Compare:

- keyboard focus
- VoiceOver
- Light/Dark appearance
- transition smoothness
- control target size
- implementation complexity

Keep only the winning implementation. Delete the prototype seam before finalizing.

Exit gate: documented A/B decision with real-machine evidence.

## Slice 5 — U3 popup hierarchy

- Output-only App management.
- Pinned/Normal grouping.
- Row width priority and optional-control consolidation.
- Scrollbar-safe trailing gutter.
- Long-name behavior across all popup sizes.

Exit gate: U3 automated ordering/content tests + screenshot/real-machine matrix.

## Slice 6 — U4 visual/native-control pass

- Raise minimum hit regions.
- Raise sub-10-pt user-facing text.
- Remove scaled system Toggle treatment.
- Fix slider true-zero fill and resting affordance.
- Simplify Settings framing and restore automatic scroll discoverability where needed.
- Preserve single Liquid Glass host and legacy fallback boundary.

Exit gate: HIG sizing/typography checks + Light/Dark/System matrix.

## Slice 7 — U5 accessibility

- Add Move Up/Move Down accessibility actions using existing reorder mutations.
- Validate nested control focus and VoiceOver labels/actions.
- Validate Escape/outside-click/modal behavior.

Exit gate: full keyboard + VoiceOver real-machine matrix.

## Slice 8 — U5 measured performance

- Record baseline and final Instruments traces.
- Run scripted stress scenarios.
- Optimize only evidence-backed regressions.
- Re-record after any optimization.

Exit gate: performance gate passes with saved evidence and no unresolved measured regression.

# Verification policy

Every production slice must pass before moving to the next:

1. focused tests for the slice
2. complete non-UI test suite
3. Build
4. fixed-point diff inspection
5. exact-head CI
6. real-machine checks when the slice changes visual/interaction behavior

The final branch remains Draft and unmerged until:

- U1 PASS
- U2 PASS
- U3 PASS
- U4 PASS
- U5 keyboard/VoiceOver PASS
- U5 measured performance PASS
- final exact-head Build + complete non-UI Tests PASS
- no unexplained production diff outside the approved UI seams

# Out of scope

Do not change as part of U1–U5 unless a failing test proves a direct dependency:

- process discovery policy
- tap lifecycle/reconciliation
- Core Audio routing algorithms
- realtime DSP
- EQ/AutoEQ signal processing math
- Loudness Equalization lifetime
- settings write-order coordinator
- release/signing/appcast
- unrelated localization architecture
- `main`

# Planning result

The recommended order is U1 → U2 → U3 → U4 → U5. Do not start with cosmetic cleanup. The current highest-leverage seam is U1 because the same mute/volume contradiction is already duplicated across multiple surfaces. The first implementation ticket should therefore be a test-first pure presentation-state slice, followed by one App + one HUD integration to prove the seam before broad rollout.
