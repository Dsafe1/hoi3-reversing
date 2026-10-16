# The next wave

**This file holds one thing: the wave that is planned but has not run.** It exists because the plan
used to live in `CANDIDATES.md`, which is five hundred lines of queue and archive, and finding the
plan in it was a search rather than a glance.

The contract, so the two files do not drift:

| | |
| --- | --- |
| **`WAVE.md`** (this file) | the plan for the wave that has **not launched**. Overwritten by the next plan |
| `CANDIDATES.md` | the standing queue and the archive. **A wave's result goes there**, not here, along with the area-level backlog a plan is chosen from |

So: plan here -> launch -> write the result into `CANDIDATES.md` -> replace this file with the next
plan. If this file describes a wave that has already landed, it is stale and `CANDIDATES.md` is the
truth.

---

## The selection wave - the drag box, Shift and several units selected

> **LANDED 2026-10-16.** Two briefs, merged (74 address entries, 70 landed; 3 structs declared, 40 fields; apply
> `failed: 0`, `struct fields: 0`); the write-up is `findings/FINDINGS-selection.md` sections A and B, indexed in
> `CANDIDATES.md`, where seven things it left are queued. Input slot 11 is Alt, not the box's keep-modifier: that is
> Shift.

Planned 2026-10-16, for OpenHOI3, on the maintainer's word that day: before the headless run, "some useability
improvements - implement the drag-box-selection; implement the shift-multiselect for units (combines with the drag
box)". OpenHOI3 selects one unit at a time, or several provinces with Shift; it has the single unit panel, the
counters with their ring, the right click that orders the selected unit, and the province view. Two briefs; the
write-up is **a new `findings/FINDINGS-selection.md`**, sections A and B.

**What is known and is not to be redone** - cite it; re-read on the listing only to settle what follows, to raise an
`inferred` record or to correct one:

- `FINDINGS-provinceview.md` section A.1: the selection's listener, `CSelectable_Select` (rva `0xAD620`),
  `Selection_CanAdd` (`0xAD6B0`, one kind: 0 army, 1 fleet, 2 air, 3 province), `Selection_Remove` (`0xAD680`),
  `Selection_Clear` (`0xAD6F0`), `CInGameIdler::ClearSelection`, `CInGameIdler::Select` (slot 38); the plain click and
  the Shift-click (input slot 10) **on a province**; and one line on the box: "selects only the player's own units
  inside it - land units over land, fleets, air units - clearing first unless a modifier (input slot 11) is held. No
  province is ever box-selected." - **not read to the rule**.
- `FINDINGS-buildingqueue.md` (end): `CInGameIdler_HandleInput` (rva `0x252540`) read in part - the release of the left
  button with nothing dragged while a deployment is placed.
- `FINDINGS-movement.md` section 1: `CUnit::OrderToProvince` (slot 6, rva `0x1C1AD0`), "what a right click on the map
  reaches for each selected unit", `append` the Shift key; the caller that loops over the selection not looked for.
- `FINDINGS-scrollbar.md`: input slot 10 Shift by the maintainer's word, slot 12 Ctrl `likely`; the key codes behind
  the slots not traced.
- `FINDINGS-counters.md`: a counter's `selection` word (`+0x1B0`, 0 none, 1 white, 2 `color1`, 3 `color2`), its slot 23
  that sets it, the hit test, only the top counter of a stack clickable; `FINDINGS-seaair.md` section 6: a click on a
  port or an air base cycles the player's units there.
- `FINDINGS-transport.md` section C.3: `multi_unitpanel` (`CInGameIdler +0x1368`) and its three carrying buttons -
  `load_multiunit`, `load_on_air_multiunit`, `unmount_multiunit` - with their finders, clicks and tooltips;
  `CInGameIdler_UpdatePanels` (rva `0x250700`) read in part: "a selection waiting at +0x1DE4 replaces the current one,
  keeping only units of the first one's kind", one row - the single panel; two or more - the multi panel.
- `FINDINGS-unitpanel.md`: the header row of the single panel is the same `unitpanel` window, of the same class, as a
  row of the list of several selected units; `CInGameIdler` slot 34 (VA `0x6639E0`) adds a row to the selection list;
  `FINDINGS-guilive.md` and `FINDINGS-gui.md`: `unitlist_start` (0, 144) and `unitlist_offset` (16, 40).

**What OpenHOI3 needs that is not settled**, by brief:

| brief | what it settles | starting points |
| --- | --- | --- |
| **A. Selecting** | **The left button over the map, whole**: `CInGameIdler_HandleInput`'s press, move and release arms - when a press becomes a drag (a distance in pixels? a time?), what is drawn while it is held (a rectangle? the `Selection` mesh, `selection_projection`? its colour and line), and on release **which units the box takes**: tested how (each counter's screen rectangle, the unit's map point projected, the province's point?), whose (the player's only?), which (land units only over land? a fleet in port, an air unit at its base, a unit aboard a ship or a plane, a unit in a battle, the units under a stack's top counter, headquarters and their children), in what order they join, and how the one-kind rule applies (the waiting selection at `+0x1DE4` keeping the first one's kind - which is "first": the box's order, a preference for land?), and what of the province view and the deploy menu. **The keys**: which keys input slots 10, 11 and 12 are (trace the input object's slots to key codes), what slot 11 does to the box (adds to the selection? toggles?). **A click on a unit's counter** with Shift and without: toggling a unit already selected, adding one of another kind, a Shift-click on a stack's top counter (does it cycle, add the stack, add the top?), on a port or an air base, a click on a counter with several selected; a double click if any. **The right click with several selected**: the loop that calls `CUnit::OrderToProvince` for each - in which order, one sound or one per unit, what of a mix the one-kind rule forbids, the air units' and fleets' right click with several (`FINDINGS-airorders.md` section 6 has one air unit), and the province tooltip's warning and distance lines with several. **The counters**: which `selection` word each selected counter gets (all 1? the first another?) and the stack's top. Any keyboard shortcut on the selection (select all? Ctrl and a number to keep a group?) | VA `0x652540` (rva `0x252540`), `0x6416D0` (the hovered thing), `0x64D850`, `0x650700` (the `+0x1DE4` arm), `0x4AD620`, `0x4AD6B0`, `0x4AD680`, `0x4AD6F0`, `0x5C1AD0`; `CInGameIdler +0x1304` (the selection), `+0x12E0` (the down byte), `+0x1DE4`; `FINDINGS-provinceview.md` A.1, `FINDINGS-movement.md` 1, `FINDINGS-counters.md`, `FINDINGS-scrollbar.md`, `FINDINGS-camera.md` |
| **B. Several on screen** | **The multi-unit panel**, `multi_unitpanel` in `tfh/interface/unitpanel.gui`: when it shows and where (`unitlist_start`, `unitlist_offset`), its `desc` text (key and variables), **the list of rows** - `CInGameIdler` slot 34 (VA `0x6639E0`) and whatever builds, orders, scrolls (`multiunit_slider`: how many rows show, the step) and refreshes them; what each row shows (the `unitpanel` header row - cite `FINDINGS-unitpanel.md`, read only what differs for a row of the list); **a click on a row** (left, right, with Shift: select that unit alone? take it out?), its tooltip. **Every button and checkbox of `multi_unitpanel`** but the three carrying ones (cite C.3): `upgrade_all`, `prio_checkbox`, `reinf_checkbox`, `upgrade_checkbox`, `detach_multiunit`, `highercomm_multiunit`, `reorganizebutton`, `mergebutton`, `disband_multiunit`, `close_multiunit` and any other in it - when each shows, when it is enabled, its tooltip (`CInGameIdler::GetElementTooltip`) and what it posts or does, for which of the selected units; what a checkbox shows when the selected units disagree. **The other windows with several selected**: the orders window for several fleets or air units (does a mission go to every one? `FINDINGS-airorders.md`, `FINDINGS-seaair.md`), the hierarchy's lines on the map, the leader button, the battle rows. **What changes the list**: a selected unit destroyed, merged, gone aboard, out of the player's hands - taken out of the selection where? | VA `0x650700` (rva `0x250700`), `0x6639E0`, `CInGameIdler +0x1368`, `+0xD28` (the rows), `CInGameIdler::GetElementTooltip`; `FINDINGS-transport.md` C.3, `FINDINGS-unitpanel.md`, `FINDINGS-unitpaneltooltips.md`, `FINDINGS-reorganise.md`, `FINDINGS-guilive.md`, `FINDINGS-airorders.md` |

**Measurable afterwards, by OpenHOI3**: nothing a save keeps; `--click` with a drag (`d560,140>760,340`) and Shift, and
the maintainer's eye.
