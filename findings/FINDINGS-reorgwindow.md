# The reorganise window: `reorg_window`, two units handing brigades between them

*The reorganise wave, 2026-11-04, two readers, read statically for OpenHOI3 and set against the maintainer's two
screenshots of the original's window - two land divisions in one province, and two fleets in one port. Every address is
valid only for this build of `hoi3_tfh.exe`; VAs unless marked rva.*

## In one line

The multi-unit panel's `reorganizebutton`, with exactly two units selected, opens `CReorgPanel`: the first unit's
brigades down the left, the second's down the right, in each unit's own order, each row its brigade's name, men or
percentage, model level, type, counter and two bars, made once and never updated, with **an arrow that is never greyed**
and posts `CTransferSubUnitCommand` to the other side. **The command decides** - `CUnit_CanTakeSubUnit`'s eleven tests,
silently - and a refused press does nothing. The window refills a list when its row count stops matching, shuts when
the two units part, and **disbands a unit left empty as it closes**. Fleets add a positioning penalty, printed without
the x100 the unit panel applies, and a ratio of capitals, screens and transports that counts no submarine.

**Corrected**: `CTransferSubUnitCommand::Execute`'s entry (the test "not read past" its battle check; the player told
only of the player's own units); `UnitList_MayReorganise`'s base clause (a carrier's only); `CReorgWindow_ElementTooltip`
(fleets only, and final); `CInGameIdler +0x1358`'s type.

## A. The window (`CReorgPanel`, `CReorgEntry`)

*Reader A's synopsis.* It read the reorganise window whole (`CReorgPanel`, `CReorgEntry`, VA 0x763000-0x765200) and
accounted for every figure on the maintainer's two screenshots but the greyed "Select" button, which is not the window's
(most likely a selected unit's row showing beside it - inference). Four things correct earlier assumptions:
**`transferbutton` is never greyed or hidden by the window** - nothing in it calls the refusal test 0xE1010, any refusal
is the command's; **the window does not rebuild after a click** - the per-frame test 0x7646D0 refills a list when its row
count stops matching its unit's brigade count, and closes the window only when the two units are in different
provinces; **closing the window disbands a unit left with no brigades** (a `CDisbandCommand`); and **the positioning
penalty is printed without the x100 the unit panel applies**, so 5% reads `0.050%`. `CReorgWindow_ElementTooltip` was
revised: its tooltip comes only where either unit is a fleet, and because the window's answer is final,
`transferbutton` shows the brigade summary (not `TRANSFER_SUB`) and `closebutton` nothing.

Addresses are VAs unless written as rva. Facts are read off the bytes unless marked *inferred*. The decompilations come
from a copy of `Hoi3_v12.1.2` and were each checked against the disassembly.

### A.1 What the window is

`CReorgPanel` has no virtual table and no RTTI of its own; the RTTI export knows it only by its
`CButtonObserverGlue<CReorgPanel>` (VA 0x15D99E8).
- **Made once.** `CInGameIdler::Enter` allocates 0x4C bytes (0x65F067), calls `CReorgPanel::CReorgPanel(this, screen)`
  (0x763D10, `ret 8`) and stores the result at idler +0x1358 (0x65F0AC).
- **Trap 2:** the constructor starts on the very byte after the transfer handler's `ret 4` at 0x763D0D, with no padding.

The constructor, in order:
1. Lays the glue in at +0xC: vftable, owner = panel at +0x10, its slot-1 handler `CReorgPanel::OnClose` (0x763F50) at
   +0x2C.
2. Sets **+0x39 = 1** (needs a fill).
3. Makes `reorg_window` through the screen's gui (screen slot 14, then slot 11 with the screen's slot 16).
4. Finds `positioning_left` / `_right` / `ships_ratio_left` / `_right` into +0x3C / +0x40 / +0x44 / +0x48.
5. Registers the glue on `closebutton`.
6. Hides the window and sets **+0x38 = 0** (not shown).

**Nothing in the code names `reorg_label`, `reorg_bg` or `band_reorg_regiment`.** `image.findBytes` finds none of the
three strings anywhere in the image; the positive controls, `unitname_2` and `positioning_right`, are found. So they show
what the file gives them:
- `reorg_label` is `UNIT_PANEL`, "Reorganise Unit" - **the window's title**.
- `reorg_bg` is `gfx/interface/reorg_bg.dds`. **The two tab-like headers and the double-headed arrow between them are
  drawn in that picture**; the texture has no text.
- The four fleet text boxes and their default text `UNIT_PANEL` exist only in Their Finest Hour's `unitpanel.gui`. The
  base game's window lacks them.

### A.2 The fill, the two sides, the row order

`CInGameIdler::OnReorganiseButton` puts the first selected unit at +4 and the second at +8, sets +0x39, calls
`CReorgPanel_Fill` (0x764960, panel in ESI) and shows the window. The fill:
1. **`left_list` gets the left unit's (first selected) brigades** from the template `reorg_entry`, each row's target
   being the right unit.
2. **`right_list` gets the right unit's (second selected) brigades** from `reorg_entry_right`, each row's target being
   the left unit. So SS-Verfugungstruppe, selected first, is on the left, and its rows' arrows point right (the left
   template's `transferbutton` is `GFX_button_arrow_right`, the right one's `GFX_button_arrow_left`).
3. The fleet figures (A.4), then the window is shown and +0x38 = 1.

Each list goes through `CReorgPanel_FillList` (0x764D90, `ret 0x20`: unit in ECX, list in EDX, target and the template
name by value on the stack): it keeps the list's scrollbar position (scrollbar +0xF8, slot 4; -1.0 with no scrollbar),
builds a row maker {in-game screen, target, template}, calls `CReorgPanel_SyncList` (0x770210) with the unit's brigade
list, and puts the scrollbar back at `(int)floor((pos + 0.0005) * 1000)`.

`CReorgPanel_SyncList` walks the rows and the brigades together: a row whose brigade (+0x28) is this brigade and whose
target (+0x50) is the maker's target is **kept as it is**; otherwise a later row that matches is moved up to here;
failing that, a new `CReorgEntry` is inserted before the row. Leftover brigades get appended rows (at most 128 in one
pass); leftover rows are removed. **So the rows follow the unit's own brigade order (CUnit +0x38)**, which is the order of
the screenshots' lists. A row that survives a refill is the same object with the figures it was made with (A.3).

### A.3 A row (`CReorgEntry`, 0xC8 bytes)

The constructor is 0x7630F0, `ret 0x14`: (this, screen, brigade, target, template name). The row's window from the
template goes into +0x20; the brigade into a `CRef` at +0x28 (read through `CRef_ResolveDirect`, which skips the -8,
because a CSubUnit's CPersistent is at +0); the **target**, the other side's unit, into a `CRef` at +0x50; a
`CButtonObserverGlue<CReorgEntry>` (0x50 bytes) at +0x78 has its slot-1 handler `CReorgEntry::OnTransfer` and is
registered on `transferbutton`.

| element | what it shows | the screenshots |
| --- | --- | --- |
| `subunit_name` | the brigade's name (CSubUnit slot 8, the string at +0x68) | "Leibstandarte SS 'Adolf Hitler'", "Deutschland" |
| `subunit_strength` | the brigade's slot 13. A brigade: `CRegiment::StrengthText` = `FormatMen` = strength x 100, cut to a whole man. A ship or wing: `CShip::StrengthText` = FormatFixedPoint(strength, 0) + `%` | Leibstandarte at `strength=29.996` -> **2,999**; Pionier-Bataillon 114 at 10.000 -> **1,000**; ships at 100.000 -> **100%** |
| `subunit_level` | IntToRoman(index of `CHistoricalModel::PickBestModel`(the owner's models of the type, brigade) + 1); **I** where there is no model | "II", "I", "IV" |
| `subunit_type` | the definition's name (its slot 6) | "Waffen SS", "Light Armour", "Heavy Cruiser" |
| `counter_type` | sprite `GFX_counter_` + the definition's key, where that sprite exists (StringHashFind); otherwise the file's `GFX_temp_unit_icon`. No intel test (CUnitView has one) | the counter at each row's left |
| `counter_size` | frame 1 | |
| `org_bar` | `(int)(100 x org / max(definition +0xF0 max_organisation, org))` - **the definition's own figure**, unlike the unit panel's row, which uses `CSubUnit::GetMaxOrganisation`; so no officer ratio, commander bonus or reserve penalty in the divisor | the first small bar |
| `str_bar` | `(int)(100 x strength / max(CSubUnit::GetMaxStrength(0,0), strength))` | the second small bar |
| `band_reorg_regiment` | untouched; the file's `GFX_brigade_band` | |

Last, the row's window and its elements get the group string `<id type>_<id>` of the brigade, through the call that gives
the diplomatic icons `diplo_message`.

**A row is never updated.** `CReorgEntry` overrides only its two slot 0s. Primary slot 8, a list row's per-frame update,
is the shared empty `ret` 0xABF890. So the strength, organisation and bars are as they stood when the row was made, and a
kept row (A.2) keeps them. *Inferred from the table, not observed.*

**`transferbutton`.**
- **It is never disabled or hidden.** No code in the window touches its state, and 0xE1010 has five callers (0x4850A0,
  0x5DCCF3, 0x5EB680, 0x736596, 0x73AAC4), none in 0x763000-0x765200. The string `transferbutton` (0x15D2524) has two
  references: the constructor's 0x763273, and the idler's tooltip name table at 0x6C78FA. This matches the screenshots:
  an arrow on every row, none greyed.
- **What a click does** (`CReorgEntry::OnTransfer`, 0x763A90): it resolves the target and the brigade; if either is gone
  it does nothing. Otherwise it plays the `click` sound (unless already playing) and posts
  **`CTransferSubUnitCommand(target's id pair CUnit +0x10/+0x14, brigade)`** to the session's command channel
  (in_game_screen slot 18 -> +0x38 -> slot 6). This is the transfer site 0x763C53.
- **It has no test of its own.** Whether the move happens is up to the command (section B).
- **It does not rebuild the lists.** The next frame's `CReorgPanel_Update` notices the brigade counts no longer match the
  rows and refills both.

### A.4 Positioning penalty and units ratio - and why land shows neither

`CReorgPanel_Fill` asks CUnit slot 16 (IsNaval) of both units. **Where neither is a fleet, the four text boxes are
hidden**; that is why the land screenshot has neither figure. Where one is, all four are written and shown, the left ones
for the first unit and the right ones for the second.

**Positioning** (`CReorgPanel::WritePositioning`, 0x764010):
- p = `NavalStackingPositionPenalty` of a one-entry list holding the unit. From the record: hull summed off the unit's
  combined definition, minus NAVAL_STACK_POS_HULL_LIMIT, times NAVAL_STACK_POS_PENALTY_HULL_MULT / 1000, capped at
  NAVAL_STACK_POS_PENALTY_MAX. Those three are defines and mod-able.
- Text: `POSITIONING_PENALTY` ("Positioning Penalty: $VAL$") with VAL = colour + FormatFixedPoint(p, 3) + `%§!`.
- **Green only at no penalty, red otherwise.** The colour is `§G` where p < floor(1.5f) = 1, which is exe-hardcoded (the
  shared literal at VA 0x17179AC). p is never negative, so it is green only at 0.
- **p is printed raw, in thousandths, with no x100.** A penalty of 50 (5%) reads `0.050%`, where the unit panel's
  `positioning` shows 5%: its fill multiplies by 100000/1000 at 0x754AA3, and nothing between 0x76408D and 0x7640F7 scales
  p. A display slip in the original, confirmed from the bytes. The screenshots show only 0, as "0.000%" in green on both
  sides.

**Units ratio** (`CReorgPanel_WriteUnitsRatio`, 0x764240):
- It counts the unit's brigades that are ships (`is_ship` +0x2E): `is_transport` -> transports; else `is_capital` ->
  capitals; else anything **but `is_sub`** -> screens; **a submarine is counted nowhere.**
- Text: `UNIT_RATIO` ("Units Ratio: $RAT$") with RAT = `§G`capitals`§! / §G`screens`§! / §G`transports`§!`. **All three are
  always green.** The flags come from the unit files (mod-able); the grouping is exe-hardcoded.
- Schlachtflotte reads 2 / 7 / 0: two heavy cruisers (`capital = yes` in `tfh/units/heavy_cruiser.txt`) are capitals, and
  five light cruisers, Emden and the destroyer flotilla make seven screens. I. Unterseebootsflotte reads 0 / 0 / 0,
  because `submarine.txt` has `is_sub = yes`.

### A.5 The test that keeps it open (`CReorgPanel_Update`, 0x7646D0)

`CInGameIdler_UpdatePanels` asks this every frame the window is up (0x650914); false means close.
- **It is false only where the two units' current provinces (CUnit +0x130) differ.** There is no battle, path, retreat,
  owner or selection-kind test here. The record already says the row add and remove (selection changes) close the window
  separately.
- Otherwise it sets `unitname_1` and `unitname_2` to the left and right units' full names (CUnit slot 7, GetName) **every
  frame**.
- Then it hides, refills and clears +0x39 where +0x39 is set, or where either list's row count (list slot 10) differs
  from its unit's regiments_count (+0x40). It answers true.

### A.6 Closing (`CReorgPanel_Close`, 0x764B90)

Reached from `closebutton` (`CReorgPanel::OnClose` -> idler slot 50 `CloseReorganiseWindow`), from UpdatePanels on a false
test, and from the row add and remove (0x663C0B, 0x664386). It:
1. hides the window;
2. for each unit, **posts a `CDisbandCommand` if it has no brigades left**, and otherwise clears CUnit **+0x159**;
3. sets +0x38 = 0.

CUnit +0x159 is the byte `CCreateUnitCommand::Execute` copies its `is_allowed_empty` into, and `CUnit::UpdateHourly` acts
on an empty unit only while it is clear (0x5BA011). Recorded as `is_allowed_empty`, following the command's name, which
is itself inferred.

*Not established:* what keeps a unit emptied while the window is open alive until the close. The window never sets
+0x159, and the transfer command's Execute is not among its writers (fieldchain). Section B answers that the last
brigade may move; what `UpdateHourly` then does with the empty unit before the close was not read.

### A.7 Tooltips

`CInGameIdler::GetElementTooltip` asks `CReorgWindow_ElementTooltip` (0x764F40) whenever the window is shown and holds the
element (0x6C5392-0x6C53E1), then jumps straight to its common exit (0x6C9450), which only positions the result. **The
window's answer is final, even when empty.**
- `ships_ratio_left` / `_right`, **where either unit is a fleet**: `REORG_WND_SHIPS_RATIO_DESC`, "Ratio of
  §YCapitals§!/§YScreens§!/§YTransports§!".
- Any element of a row - including **`transferbutton`**, the bars and the counter - shows the brigade's
  `CSubUnit_SummaryTooltip`. The idler's name table entries `transferbutton` -> `TRANSFER_SUB` and `closebutton` -> `CLOSE`
  are never reached from inside this window.
- Everything else (`closebutton`, the positioning lines, the names, the label) gets an empty tooltip.

### A.8 Accounting for the screenshots

| figure | where it comes from |
| --- | --- |
| Title "Reorganise Unit" | `reorg_label`'s file text `UNIT_PANEL`; no code touches it |
| Headers and double arrow | drawn in `reorg_bg.dds` |
| Names in the headers | `unitname_1` = first selected, `unitname_2` = second, rewritten every frame |
| Which unit on which side | +4 left = first selected, +8 right = second |
| Row order | the unit's own brigade list |
| A row's name / number / second line | A.3 |
| Bars | org against the definition's maximum, strength against GetMaxStrength |
| Arrows | the template's sprite, always enabled; none greyed and none missing, by construction |
| Positioning / ratio and colours | A.4; land shows neither because both units fail IsNaval |
| "Close" | `closebutton`'s file text `CLOSE` |

**The greyed "Select" button is not the window's.** `reorg_window` and its rows hold no button but `closebutton` and
`transferbutton`, and the constructor finds only `closebutton`. The only button with the text "Select" in `unitpanel.gui`
is `only_unit_from_selection_button`, at x = 322 in the 400-wide `unitpanel` row of a selected unit; the multi-unit list
draws those rows at the screen's left. `reorg_window` sits at x = 418 with its background at -99, so its left edge is at
about x = 319. *Inferred:* the "Select" button at the window's top left is a selected unit's row showing at the window's
edge. Why it looks greyed is not established.

### A.9 Left open

- `0x370860` (moves a list row; four callers, a template) and the glue constructor `0x36FBA0` are read only by their use
  here.
- The `+0x1C` table's slot-0 thunk `0x7726B0` is unrecorded (the fragment's `slots_noted`).
- CSubUnit slot 8 (0xAC6C50) is folded with `CEU3DialogGuiType` slot 8 (trap 4), so it is left unnamed.
- The unit at `0x5EB970` writes CUnit +0x159 = 1 at 0x5EBA9E and was not identified; it sits near
  `CUnitSplitCommand::LoadKey`.

## B. What may be moved

*Reader B's synopsis.* It set out to read the transfer refusal test `0xE1010` whole and to find what
`CTransferSubUnitCommand::Execute` does beyond its record. The record already had `0xE1010` as `CUnit_CanTakeSubUnit`
(from `FINDINGS-moving.md`), and the bytes confirm its eleven tests and their order; the reading sharpens four points -
the double count in the carrier-room test, that the "receiver has wings" CAG test fires on any sub-unit the receiver
holds, that the division cap applies to a land receiver at any `oob_level`, and an explicit list of what the test never
asks (no owner check, nothing about the last brigade, no sea, port or transport test). **Corrected rather than added**:
`Execute`'s entry still said the test was "not read past" its battle check; its "the player is told" is really gated on
the receiver's owner being the player; `UnitList_MayReorganise`'s "same base" clause applies only to a carrier base; and
**no call to `0xE1010` lies in the reorganise window** (VA `0x763000`-`0x765200`) - the two interface callers are a drag
and drop route: dropping a brigade on a unit row, and the row's hover highlight during the drag.

### B.1 The test, `CUnit_CanTakeSubUnit` (`0xE1010`)

It runs from `0xE1010` to the last `ret 0xC` at `0xE118C`, then one `int3`, then `CanBuildDivision` (`0xE1190`). The
receiver comes in EAX; the country, the sub-unit and a flag `sameProvince` come on the stack. The bytes were read whole
and every branch was traced to one of its two exits. It answers **false** at the first of these that holds:

1. **The receiver is fighting** (`combats_count +0x11C > 0`). *Hardcoded.*
2. **The sub-unit's type is not buildable** (definition `+0x58`, `is_buildable +0x36` clear). In the base game that is
   `hq_brigade` and `partisan_brigade`, the two types with `is_buildable = no`. *Mod-able: the unit file.*
3. **The kinds differ.** A land sub-unit (`CSubUnit` slot 9, which only `CRegiment` overrides) needs a land receiver
   (`CUnit` slot 15). An air one (slot 11, `CWing`) needs an air receiver (slot 17). A naval one (slot 10, `CShip`) needs
   a naval receiver (slot 16). *Hardcoded; which class a type becomes follows its unit file.*
4. **The receiver is all carrier air groups** (`CUnit_AllSubUnitsAreCag`: every wing `is_cag`, and at least one wing)
   **and the sub-unit is not a CAG**. *The rule is hardcoded; `is_cag` is mod-able.*
5. **No room on a carrier.**
   - It applies when the sub-unit is a CAG, the receiver's base (`+0x98`) answers `CUnitBase` slot 1 `IsCarrier`, and
     that base's ship (`CUnitBaseCarrier +0x18`) is set.
   - It refuses when `carrier_size / 1000` is **not above** (the wings of the air units on the carrier's list, `+4`) +
     (the receiver's own `regiments_count`).
   - So if the receiver is itself on that list, which is likely but not checked, its wings count twice: the room needed
     is then `others + 2 x own + 1`, not `others + own + 1`.
   - *`carrier_size` is mod-able; the arithmetic is hardcoded.*

Then, **only where the sub-unit has a current unit** (`+0xB0`):

6. **It is that unit's HQ brigade:** the first brigade of a unit whose `oob_level` is under 4 (theatre, army group, army
   or corps). *Hardcoded.*
7. **CAG mismatch:** the receiver holds **any** sub-unit and `AllSubUnitsAreCag` answers differently for the two units.
   Land and naval units always answer false, so this only bites between a CAG air group and a non-CAG one. *Hardcoded.*
8. **Either unit is on loan** (`expeditionary_owner +0x290`). *Hardcoded.*
9. **The current unit is fighting.** *Hardcoded.*
10. **`sameProvince` is set and their `current_province_ptr` (`+0x130`) differ.** *Hardcoded.*

Last, with or without a current unit:

11. **The receiver is land and already holds `CCountry_GetMaxBrigadesInDivision(country)` brigades or more.** That limit
    is `(BRIGADES_IN_DIVISION + technology division_size) / 1000`.
    - It applies at **every** `oob_level`, so a corps' or theatre's unit counts its own brigades against it just as a
      division does.
    - *Mod-able: `BRIGADES_IN_DIVISION` is 4 in TFH and 7 in BlackICE's `common/defines.lua`. In TFH only
      `superior_firepower` adds `division_size = 1`.*

Otherwise it answers **true**.

**What it never asks** (the whole body is 0x17F bytes, and this is the complete list of fields it reads, so these are not
search negatives):
- No owner is compared: not the sub-unit's unit's, not the receiver's, not the `country` argument.
- Nothing about what the old unit keeps: **a unit's last brigade, ship or wing may leave**.
- No province kind, port, or "aboard a transport" test. Two units at sea in one sea province pass; so do a carried
  division and one ashore in the fleet's port, provided both carry that province in `+0x130` (that passengers do is
  inferred from `CheckTransportOverload`'s record).
- No movement, retreat, attack delay or AI-agent test. Those are `UnitList_MayReorganise`'s.
- No limit on the ships of a fleet or the wings of an air unit beyond the carrier rule.
- No test that the current unit is not the receiver.

**The fourth argument gates test 10 and nothing else.** The five callers (`findRefs --callers 0x4E1010`, exactly five):

| caller | what it passes |
| --- | --- |
| `CTransferSubUnitCommand::Execute` (`0x1DCCF3`) | the receiver's owner's country, 1 |
| the unrecorded split helper `0x1EB620` (`0x1EB680`) | the receiver's owner's country, 1 |
| `CMilitaryConstruction::Deliver` (`0x850A0`) | 0, testing a finished line's target unit against the new unit's first brigade |
| `UnitRows_HandleDrop` (`0x33AAC4`) | 1, unless a deployment callback is pending (`drag +0x98`) |
| `UnitRow_UpdateSubUnitDragHover` (`0x336596`) | 1, unless its last argument is set |

**The reorganise window does not call it.** A chunk-decode of VA `0x763000`-`0x765200` found its own
`CTransferSubUnitCommand` constructor call at `0x763C53` (the positive control) and no call to `0x4E1010`, `0x4E1360` or
`0x5D1220`.

### B.2 What `Execute` adds (`0x1DCB40`)

- **Before the test:** the client-only early return, and the resolution of both ids. The global byte `0x1A857BF` is
  saved, set to 1, and **restored to its old value** on both exits.
- **The test:** one call, with `sameProvince = 1`. **A refusal is silent**: no message, no sound. Execute itself tests
  nothing else.
- **The move:** `RemoveRegimentFromUnit` from the old unit, `AddRegimentToUnit` to the receiver, `avatar_stale` set.
- **The receiver's leader:** it gets `AssignBestLeader` only if it is not land or now has more than one brigade, has no
  real leader, and its country has `auto_assign_leaders`.
- **The old unit:** if left empty, or if it is a land unit left with one brigade, its leader becomes `CLeader::null()`. A
  naval old unit gets `CheckTransportOverload`. **The old unit is never removed here, however empty.**
- **Naming:** a receiver whose name is under two characters is named with `MakeUnitName`.
- **Only if the receiver's owner id equals `CCurrentGameState +0xC34`** (the id half of `player +0xC30`): the interface
  is poked for both units (`0x739BC0`), and `TRANSFEREDSUBUNIT` is raised with SUB, OLD and NEW. OLD is read off the old
  unit **with no null test**, so Execute assumes the brigade has a unit whenever the player is the owner (inferred
  consequence).
- **A carrier ship** (`carrier_size > 0`, naval) brings its `air` list (`CShip +0xDC`): each air unit is detached from
  its parent and attached under the receiver.
- **Last, unless client-only:** both units re-enter their own provinces; a receiver of exactly one brigade gets
  `CheckForCombat`; the receiver's intel level is refreshed.

### B.3 The second interface route: drag and drop (inferred in its details)

**`UnitRows_HandleDrop` (`0x33A7C0`, `ret 0x1C`)** takes a dragged unit, sub-unit or leader and the mouse point, and
walks a window's rows (its `+0x148`). On the row under the point:
- **A unit:** `CUnit_MayTakeSubordinate`, then `CAttachUnitCommand`.
- **A brigade not already the row's:** the test above, then `CTransferSubUnitCommand`. A pending deploy-menu callback is
  consulted first, and that callback's presence is what turns `sameProvince` off.
- **A leader:** `MayTakeLeader` both ways, then one or two `CAssignLeaderCommand`s, which is a swap.

**`UnitRow_UpdateSubUnitDragHover` (`0x336490`)** is the row's look during a brigade drag: frame 2 while hovered over a
unit that may take the brigade; frame 1 and (likely) disabled where it may not, or where the brigade is already that
unit's. Neither the row's window nor the drag object's class was identified.

### B.4 `UnitList_MayReorganise` and the helper it shares

It calls `CUnit_AllSubUnitsAreCag` (`0x1D1220`) on the first unit, as tests 4 and 7 do, and inlines the same loop for
each unit. Its base clause (`0x4E0B15`-`0x4E0B45`) compares bases **only when the first unit is air and its base answers
`IsCarrier`**. So two air groups to be reorganised must be on one carrier; a province base is not compared. Its record
said "with a base, the same base".

### B.5 Against the maintainer's screenshots

- **Last brigade or ship:** nothing refuses it, so the lone submarine's arrow agrees with the test. If it moves,
  I. Unterseebootsflotte is left empty with the null leader, and Execute does not remove it.
- **Schlachtflotte:** no ship limit, and no carrier involved. Every row may move either way; agrees.
- **3. Panzer-Division to SS-Verfugungstruppe:** allowed, since SS-VT has 3 brigades against a limit of 4.
- **SS-Verfugungstruppe to 3. Panzer-Division:** **refused in plain TFH** - the Panzer division already holds 4 and the
  limit is 4, unless Germany has `superior_firepower` - and **allowed in BlackICE**, whose limit is 7. So every arrow
  present agrees with the test only if the screenshots are from BlackICE (or Germany has the doctrine); otherwise the
  window simply does not grey by this rule, consistent with it never calling the test, and pressing such an arrow posts a
  command that Execute silently drops.
- **No HQ brigades appear** in either screenshot, so nothing should grey for tests 2 or 6; agrees.

### B.6 Not established

- Whether a carrier's air groups are on its own `CUnitBaseCarrier +4` list, which is what makes the double count real.
- The split helper `0x1EB620`, `0x339CA0` (the drop handler's caller), `0x739BC0`, `0x336810`, `0x33BAF0`, and `0x1D5D20`
  (the naval twin of `UnitList_CountAirSubUnits`) - all in the fragment's `frontier`.
- `CUnit +0x98 home_base_ptr`'s comment still says "its class has not been identified"; it is a `CUnitBase*`, a province
  base or a carrier base, and the record has no `CUnitBase` struct to type it with.
