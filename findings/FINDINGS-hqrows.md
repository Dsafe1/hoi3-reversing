# The unit panel's rows for a headquarters under an AI

*Read 2026-11-09 for OpenHOI3's unit panel. Static reading of `hoi3_tfh.exe`, decompiled headless
off a copy of the Ghidra project with the record applied, the joins of strings and the
fall-throughs read in the listing. Addresses are VAs. Every line is `confirmed` unless it says
otherwise. Nothing here was watched in a running game. Continues `FINDINGS-unitpanel.md`, section
2; `FINDINGS-agents.md` section D has what the plan's stances and powers mean, and is not repeated.*

**In one line.** Five rows, gated alike; three stance rows that are one window with a different
field behind it, each opening a shared list and posting a change of its own stance on the plan; a
row of two bars and a text saying what the plan is short of, neither of which takes a click.

## 0. When the rows exist, and in what order

`CSingleUnitPanel::Rebuild` (`0x762780`) adds them, each behind its own copy of the same test,
after `CObjectivesEntry` (row 5 of `FINDINGS-unitpanel.md`'s table):

    oob_level < 4  and  CUnit::HasAgentAbove(unit)        - each of the five, tested separately

in the order `CUnitStanceEntry`, `CUnitAirStanceEntry`, `CUnitNavalStanceEntry`,
`CPowerRatioEntry`, `CDesiredAssetsEntry`. Rebuild fetches the child window
`sup_stance_change_window` (window slot `+0x6C`) and hides it at `0x762AB3`, then hands that window
to the three stance rows as their third constructor argument. **`CUnit::HasAgentAbove` is true for
the unit's own agent too** (`ai_agent`, `+0x198`, seeded from the unit, then any agent up the chain
overrides it), so a corps of a player's automated army shows the rows too, with the buttons greyed
(section 1).

**Who has an agent.** On the player's own side an agent appears when the player ticks
`automate_checkbox`: the handler (`0x74F9D0`, registered in `CObjectivesEntry`'s constructor at
`0x74E52A`, the element's name by order and `inferred`) takes the player's `CEU3AI` and the
**highest agent in the unit's chain** (the unit's own or one above); none - `CEU3AI::CreateUnitAgent`,
slot 76, the selection refreshed, `CAIUnit::SetArea`; one - `CEU3AI_RemoveAgent` on that agent and
the selection refreshed - **the unit stays selected, by the maintainer's word of 2026-11-09, for all that the call hands the screen a null unit**. **Corrected against `FINDINGS-aiunit.md` and `FINDINGS-aiplans.md`, which
put the call in `CObjectivesEntry` slot 22**: slot 22 (`0x74F910`, `ret 4`) only answers whether an
element is the entry's own, by comparing `tac_aggro_bg`, `aggro_TrackButton` and
`aggro_SliderButton`. A loaded game's played country gets agents through
`CreateAgentsForPlannedUnits` (`FINDINGS-agents.md` A.2).

**A foreign unit:** no row tests the owner, but a foreign unit cannot be selected
(`FINDINGS-selection.md`, section A: "A foreign unit's counter. Slot 2 refuses it"), so these rows
appear only for the player's own units. An AI-run country's plan is not reachable from here.

## 1. A stance row: the window and what it shows

Window `sup_unit_stance`, 254 x 28: the icon `stance_bg` (`GFX_unit_bg_28`) and the button `stance`
(`GFX_stance_button`, a plain sprite, `Arial12_bold_black`, at x 26, y -4, shortcut `s`). All three
stance rows use this one window. No frame is ever set on either element.

**Update, each frame** (slot 9 of the observer table; ground `0x751350`):

| element | what it is given |
| --- | --- |
| `stance`, text | the localised name of the unit's plan stance (`PlanStanceName` on `plan_stance`), through the button's text setter |
| `stance`, greying | disabled where any unit **above** this one has an agent; otherwise enabled |

The test walks up the chain from the unit's **parent** and keeps the last non-null `ai_agent` it
meets; the unit's own agent does not count. So **only the unit that holds the agent may be pressed**;
a subordinate shows its own stance, greyed. The stance shown is read off the unit itself, not the
agent's.

**Tooltip** (slot 13; ground `0x7516E0`): `text` = the description of the current stance, for any
element of the row (`element` is not read). Nothing in `delayed` or `delayed_extra`. The button's
shortcut line is added by the tooltip mechanism (`FINDINGS-tooltips.md` section 4, `SHORTCUT`).

Ground stances, by `plan_stance` (`PlanStanceName`, `PlanStanceDescription` `0x8E0250`):

| value | text | tooltip |
| --- | --- | --- |
| 0 | `STANCE_WITHDRAW` | `STANCE_WITHDRAW_DESC` |
| 1 | `STANCE_PREPARE` | `STANCE_PREPARE_DESC` |
| 2 | `STANCE_DEFEND` | `STANCE_DEFEND_DESC` |
| 3 | `STANCE_ATTACK` | `STANCE_ATTACK_DESC` |
| 4 | `STANCE_BLITZ` | `STANCE_BLITZ_DESC` |

Any other value: both empty.

## 2. Pressing it: the list, and a pick

**Press** (`CUnitStanceEntry::OnStance`, `0x7515D0`). If the row holds a popup (`+0x80`), it hides
that popup's window and frees the popup, **and goes straight on** (the listing: `0x75160F` free, then
`0x751617` `push 8; call operator new`): the decompiler's `free(...); return` is the `free` mark
`ghidra/README.md` describes. So **a second press of the button rebuilds the list and does not close
it.** A new 8-byte popup is made (`+4` the window), kept at `+0x80`.

**The list** (`StancePopup_FillGround` `0x750C40`). In `sup_stance_change_window`, its list box `list`
(child, `+0x7C`) is emptied, then one `CStanceChangeEntry` per stance is added in ascending order - 5
rows for ground - then the window's corner is set to the row's corner and the window is shown. The
corner comes from `row window +0x18` slot 15 (`0xAC3590`, which answers `+0x228` of the sub-object,
i.e. window `+0x240`, the position `CFixedWindow::SetPosition` stores) and goes to the change
window's `SetPosition` (slot 6, packed `x | y << 16`, screen pixels from the upper left). So the
list opens over the row itself, and the `.gui`'s `position = { x=0 y=252 }` does not apply to it.

**A row of the list** (`0x750660`). Window `sup_stance_change`, 254 x 20, the button `stance`
(`GFX_stance_entry`, a `textSpriteType`, `Arial12_bold_black`, at x 32, y 1, no frames set) whose text
is `PlanStanceName` of the row's stance, set once in the constructor. No tooltip: the panel's
dispatcher `CSingleUnitPanel_ElementTooltip` (`0x762670`) walks only the panel's `list`, so an element
of this list has an empty tooltip. No greying: the current stance is not marked or skipped and a row
for it can be picked.

**A pick** (`0x750850`, then `0x751560`) - the ground arm:

    agent = row->unit->ai_agent
    if agent: agent->SetPlanStance(stance)              (slot 77, vftable +0x134)
    hide the popup's window; free the popup; row +0x80 = 0
    hide the change window

No test against the current stance. Since the button can only be pressed on the unit holding the
agent, `agent` is that unit's; were the row pressed with no agent on the unit, nothing would be posted.

**What closes the list.** Picking a row; `Rebuild` hides the window on every rebuild, and an entry's
destructor (`0x751290`) frees its popup and hides the window (so does its siblings', and the rows are
rebuilt when the panel's list is). No click outside closes it. The stance rows share the one change
window: opening another row's list empties and refills it, and the first row's popup pointer stays set
until that row's next press (harmless: it holds only the window).

**Effect on the plan, ground** (`CAIUnit::SetPlanStance`, `FINDINGS-agents.md` D.2): `stance_set`
(`+0x80`) is set; a `CSetPlanAttributesCommand(unit, stance, 3, 3, -1000, -1000)` is posted; the same
for every child agent (parent first); then `UpdatePlanAxis`, `RebuildOpsAreaProvinceRecords` when the
stance is 0, `ScoreOpsAreaProvinces`; the held-back vector `+0x15C` is emptied, clearing each
division's `+0x2C8`; `+0x86` `replan_subordinates` is set. The command's `Execute` writes
`plan_stance` (`+0x208`) and calls `CUnit::RefreshPlanForceNeeds`, which is why the desired assets row
(section 5) follows the pick; it also writes `active` = 1 (`CUnitPlan::SetActive`).

**Who may press.** The button is enabled only for the unit holding the agent; the row exists only for
a selected unit, and a foreign unit cannot be selected. So in practice **only the top automated
headquarters of the player's own country**; an AI-run country's plan cannot be reached from here.

**Later passes.** For an agent of the played country, `ProcessAI` does not run `UpdateUnitStances`
(`FINDINGS-agents.md` A.2, step 13: the played country gets only the invasion ranking), so a pick is
not overwritten by the AI's stance pass. The stances are read by what follows, as for any agent
(`FINDINGS-agents.md` D, `FINDINGS-moving.md`); a reset (`CUnitPlan::SetActive(0)`: stance 2, air and
naval 1) is the plan switched off.

## 3. Air and naval: what differs

| | ground | air | naval |
| --- | --- | --- | --- |
| class | `CUnitStanceEntry` | `CUnitAirStanceEntry` (`0x751F50`) | `CUnitNavalStanceEntry` (`0x751790`) |
| plan field read | `plan_stance` (`+0x208`) | `plan_air_stance` (`+0x20C`) | `plan_naval_stance` (`+0x210`) |
| name | `PlanStanceName` | `PlanAirStanceName` | `PlanNavalStanceName` |
| description | `PlanStanceDescription` | `PlanAirStanceDescription` `0x8E0870` | `PlanNavalStanceDescription` `0x8E0E10` |
| rows in the list | 5 (0 to 4) | 3 (0 to 2) | 3 (0 to 2) |
| list row class | `CStanceChangeEntry` | `CAirStanceChangeEntry` `0x750860` | `CNavalStanceChangeEntry` `0x750A50` |
| a pick | the agent's `SetPlanStance` | `CSetPlanAttributesCommand(unit, 5, stance, 3, -1000, -1000)` (`0x7523F0`) | `CSetPlanAttributesCommand(unit, 5, 3, stance, -1000, -1000)` (`0x751C30`) |

The argument 5 is the command's "leave ground stance alone", 3 the same for air or naval, a negative
power likewise; so an air or naval pick is **one command on this unit alone** - no agent consulted,
no child agent, no `UpdatePlanAxis`, no `stance_set`. Its `Execute` writes the one field and calls
`CUnitPlan::SetActive(true)` too (the constructor fixes `active` to 1); only the ground branch of
`Execute` calls `RefreshPlanForceNeeds`.

Air and naval names and descriptions, values 0, 1, 2: `STANCE_AIR_PREPARE`, `_DEFEND`, `_ATTACK`
with `_DESC`, and `STANCE_NAVAL_PREPARE`, `_DEFEND`, `_ATTACK` with `_DESC`.

The three rows' greying, tooltip and list-opening are the same code on their own fields (sections 1
and 2). The ground ctor's `if (+0x7C)` before hiding the change window is the only asymmetry beside
those.

## 4. The power ratio row: `CPowerRatioEntry`

Window `sup_power_ratios`, 254 x 28: `power_bg` (`GFX_unit_bg_power`), the bars `our_power_value`
(x 11) and `enemy_power_value` (x 164), both `power_progress` (a `progressbartype`, 145 x 16,
`progress.fx`), and the text boxes `our_power_text` (x 4) and `enemy_power_text` (x 159), 155 wide,
centred, `Arial12_bold_black`, holding the `.gui`'s own keys `OUR_POWER` ("Our Power") and
`ESTIMATED_POWER` ("Estimated Enemy Power"). Constructor `0x74DCE0` (the unit at `+0x28`, then its
own update); **the entry never touches the two text boxes.**

**The bars** (`0x74DDE0`, each frame), on `plan_our_power` (`+0x27C`) and `plan_their_power`
(`+0x280`), thousandths:

    big    = max(our, their)
    scale  = big * 1000 / 100000                 (64-bit where it would overflow; so big / 100, cut)
    if scale > 0:  our'   = our   * 1000 / scale      (64-bit, cut)
                   their' = their * 1000 / scale      (64-bit, cut)
    else:          our'   = our,  their' = their
    our_power_value   = our'   / 1000          (whole percent, through the element's +0x48)
    enemy_power_value = their' / 1000

So the larger side's bar is about full and the other in proportion to it. With `big` under 0.100 the
two figures stay raw thousandths and divide to 0: both bars empty. A figure can be 0 for one side.

**Tooltips** (`0x74DFA0`), by the element's name (`text` only):

| element | text |
| --- | --- |
| `our_power_value` | `OUR_POWER` rendered, `: `, `FormatFixedPoint(our_power, 1)` |
| `enemy_power_value` | `THEIR_POWER` rendered, `: `, `FormatFixedPoint(their_power, 1)` |

`FormatFixedPoint(v, 1)` is v / 1000, truncated, one decimal. Note the enemy's label in the tooltip
is `THEIR_POWER` ("Their Power") and on the row `ESTIMATED_POWER`. **Any other element gives an empty
tooltip** - see *Not established* on the two text boxes.

## 5. The desired assets row: `CDesiredAssetsEntry`

Window `sup_desired_assets`, 254 x 55: `assets_bg` (`GFX_unit_bg_assets`) and the text box `desired`
(`Arial12_black`, x 10, y 1, centred, 305 x 52). Constructor `0x752F40` (the unit at `+0x28`) does not
call its own update, so the row's text arrives with the first update of the list.

**What it reads.** `plan_subunit_group_difference` (`CUnit +0x6C`/`+0x70`, a `std::vector<int>` per
subunit type), **only where its length equals the subunit database's count**; otherwise as if empty.
This is the **group difference**: `UpdatePlanForceNeeds` sums each type's want-minus-have onto one
representative type per group (`SubUnitTypeGroup`; `FINDINGS-topscreens.md`, `FINDINGS-forceneeds.md`),
so the row names the representative type of each group the plan is short of. It is not `+0x7C`
(`plan_subunit_needed`, what the theatre screen's `immediate_needs` reads) and not the plain per-type
`+0x5C`. Entries over 0 count; 0 and negative (a surplus) are skipped.

**The text** (`0x753030`, each frame), per entry over 0, in type order, joined with `, `:

    <n> §W£<key>§b

(`n` the entry, `key` the definition's `+8` unit type key, as in the files; the three-byte ` §W£` and
the two-byte `§b` are literals, `0x15D7A30` and `0x15B66FC`). `£` and a type's key draw that type's
counter in text (the middle of `GFX_counter_` + key, the same mechanism a tooltip uses), so the row
reads as numbers and counter pictures. Then:

    WE_NEED rendered, ": ", the list          where something is short
    WE_NEED rendered, " ", TRADE_NOTHING      where nothing is

("We need: 3 [counter], 1 [counter]" and "We need Nothing").

**The tooltip** (`0x753A00`), only for the element named `desired`: `text` = `AGENT_NEED_DESC` rendered
("The estimated minimum force needs of this unit") then `:\n`, then for each entry over 0 a line of
`<n> <name>\n`, `name` the definition's slot 6 (the localised type name). The length test on the
vector applies again.

**Clicks.** Neither `CPowerRatioEntry` nor `CDesiredAssetsEntry` builds a glue or registers a button,
and their tables' slot 4 is the base's: **clicking either row does nothing.** Search: both constructors
read whole; a row's `slot 4` compared with `CUnitViewBaseEntry` by `vtable.py`.

## 6. Hard-coded or mod-able

- Exe-hardcoded: the gate (level, agent), the order of the rows, the five and three stances, the
  scale of the bars, the 1-decimal format, the joins and their literals, the row's vector
  (`+0x6C`) and the walk that greys the button.
- Mod-able: the `.gui` windows and elements (`single_unitpanel.gui`), the sprites
  (`unitpanel.gfx`), the localisation keys `STANCE_*`, `OUR_POWER`, `THEIR_POWER`,
  `ESTIMATED_POWER`, `WE_NEED`, `TRADE_NOTHING`, `AGENT_NEED_DESC`, and the subunit keys and counters
  the desired assets row draws.

## 7. The headquarters row's other two boxes

`CObjectivesEntry`'s constructor (`0x74E450`) registers three handlers beside the names `automate_checkbox`, `reorg_hq_checkbox` and `aggression_checkbox`, in that order: `0x74F9D0`, `0x74FC60`, `0x74FD70`. `0x74FC60` posts `CActivateUnitPlanCommand(unit, true, !allow_hq_reorg)`. `0x74FD70` posts `CToggleUnitAggressionCommand(unit, !has_own_aggression)`. The aggression is read by `CUnit::GetAggressiveness`, the only thing that uses it, for a battle's pick of tactic.

## Not established

1. ~~Whether the two power bars' tooltips can ever be reached.~~ **They cannot: the maintainer hovered over them in the original on 2026-11-09 and none shows.** The text boxes `our_power_text` and `enemy_power_text` are declared after the bars and cover them (155 wide, 32 high, against bars 145 by 16), so the routine's two answers are dead.
2. **`shortcut = "s"` on three buttons.** All three stance rows carry the same shortcut in the one
   `.gui`; which of them a keypress reaches when several are shown was not read.
3. **Whether slot 76's theatre adoption can overwrite a pick.** `CEU3AI`'s theatre pass calls slot 76
   on a played country's agents (`FINDINGS-agents.md` A.3), and its adoption posts stance 1, air and
   naval 0 once a level-0 agent adopts its theatre. How often a played agent can reach that again after
   the player picks a stance was not followed.
