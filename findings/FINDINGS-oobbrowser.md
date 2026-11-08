# The order of battle browser

Everything here was read out of `hoi3_tfh.exe` statically, against the install's `interface/oobbrowser.gui` and `tfh/interface/oobbrowser.gui`. Addresses are rvas. Only valid for this build. The vocabulary is confirmed / likely / inferred; what is not marked is confirmed. The maintainer's saves were not used as an oracle: nothing here is checkable against one, the browser being a view.

## 1. Which file wins

Their Finest Hour's `tfh/interface/oobbrowser.gui` is the one read: it adds `split_button` (Shift-less shortcut `x`) and the child window `split_window` to `oobbrowser`. The base file has neither. `Rebuild` looks up `split_window` unconditionally, so this executable expects the TFH file. `oobbrowser.gfx` in `tfh` adds only `GFX_oob_split_button` (2 frames).

**The file declares and the code never touches**: `oob_bg` (the label's picture), the `Background` buttons of both windows, and the `oob_label` of the split window, which does not exist in the split window of the file anyway. `leader_traits` is touched only on the floating leader row.

## 2. What opens it and what shuts it

**One object, for the whole game.** `CInGameIdler::Enter` makes one `COOBBrowser` (0x304 bytes, the screen's +0x1360), and the screen's slot 105 answers it. It is never made again. A reload of the interface runs `Rebuild`.

**The only way to open it is the screen's slot 104** (0x2788B0, reached from the single unit panel's `oob_button` through the thunk 0x3624E0, tooltip `UW_OPEN_OOB_BROWSER`). The file gives that button no `shortcut`.

- **Slot 104 does nothing unless the single unit panel exists** (+0x135C non-null). When the browser is shown it is closed, and the panel returns to the browser's x.
- **Otherwise it opens**, `COOBBrowser::Open`, and `ScrollToUnit(selected unit)`. The panel moves to the browser's x plus `TotalWidth`.
- Opening **does not pause** the game (no pause call in `Open` or slot 104). It is **not modal** and it does nothing to the map.

**It shuts on its own**, each by `COOBBrowser::Close`:

- every frame in `CInGameIdler::Update`, whenever the number of selected unit rows (`unit_rows_count`, +0xD28) is **not exactly 1**;
- `CInGameIdler::AddUnitRow` when the count reaches 2;
- `CInGameIdler::RemoveUnitRow` when it reaches 1;
- slot 104 when pressed again.

So the browser lives exactly as long as one unit stays selected.

**A country screen does not close it**: I found no `+0x1360` in `OpenCountryView` (0x2656D0). A press on a row, though, closes an open country view (slot 93; see section 8).

**The panel and the browser side by side**: the panel's x is `browser x + COOBBrowser_TotalWidth` whenever the browser is up, in `CInGameIdler::Update`, `AddUnitRow` and the deploy menu's hide; `0x664160` places the browser by the deploy menu's width.

## 3. The two windows

`oobbrowser` is at file position (0, 109), width 373. `Open` sets **its height to screen height - 260**, and `list` keeps the same difference from the window's height. `split_window` is its child at x = 373, 373 wide; `Rebuild` hides it, and `Open` hides it again.

| element | what it does | key and text |
| --- | --- | --- |
| `oob_label` | set by `Open` | `OOB_LABEL` = `$COUNTRY_ADJ$ Order of Battle`, COUNTRY_ADJ the player's adjective |
| `collapse_button` | empties the list and refills the roots; shortcut `m` on the main window | `OOB_COLLAPSE_ALL` = Collapse All |
| `uncollapse_button` | `ExpandAll`; shortcut `m` | `OOB_EXPAND_ALL` = Expand All |
| `theatre_forces_button` | `CEU3AI_SortUnitsIntoTheatres(player's AI, true)` (0x3FC950, the country's +0x1D8) | `THEATRE_ASSIGN_TROOPS` = Theatre Forces; tooltip `THEATRE_ASSIGN_TROOPS_DESC` = Automatically assigns forces to the best theatres. |
| `focus_button` (both) | `ScrollToUnit` of the selected unit on that list; shortcut `f` on the main | `OOB_GO_TO_SELECTED` = Go To Selected |
| `split_button` | toggles the split window; on opening it copies the main list first. Shortcut `x` | no text; frame 2 where the split window is shown, else 1 |
| `match_views_button` (split) | copy main to split, one way only; shortcut `v` | `OOB_MATCH_VIEWS` = Match Views (TFH table) |

`collapse_button` and `uncollapse_button` share one position. Each frame, on each window that is shown, **`uncollapse_button` shows where no row is indented and `collapse_button` shows where any is**.

**Tooltips:** only `theatre_forces_button` has one of its own (`COOBBrowser_ElementTooltip`). The other buttons have none but their text. A row's tooltip is section 7.

**Greying:** `theatre_forces_button` is disabled in a custom game whose local player's record has its flag set (`GetCustomGameSettings` first byte, then the settings' +0x5C vector's element byte at +4 for that human; `FUN_004208B0`, left in `frontier`). The same gate stops a drag being picked up. OpenHOI3 has no custom game, so it can ignore it.

## 4. The tree

**The tree's root is the player's whole order of battle, not the selected unit and not a theatre.** `FillRoots` walks the player's country's units (`CCountry +0xBAC`, list order) and gives a row at level 0 to every unit with no `higher_oob_unit` (+0x1E0). A child's list is `CUnit +0x1E4` in its own order, the attach order.

**Rows are indented by level**: a row's window x is `level * 16` (`COOBUnitEntry_Refresh`, the shift by 4). The file's own `oob_unit_entry` is 380 wide and the list 333, so a deep row runs under the scrollbar's side.

**Expansion is not remembered as a per-unit flag.** A row is expanded exactly when the next row is deeper. `RemoveBelow` deletes those rows when a row is closed, and `AddChildren` puts in only the **direct children** when it is opened. `ExpandAll` opens everything recursively (`AddSubtree`); `collapse_button` empties the list.

**Rebuilding**: `RefreshList`, each frame, for each list:

- any row whose unit no longer resolves makes the whole list empty and refill its roots, and that loses the expansion;
- `tree_changed_queue` units are moved one by one (`RepositionUnit`);
- `row_changed_queue` units' rows are redrawn.

Who tells it:

- **Row changed** (`QueueRowChanged`): `CAssignLeaderCommand::Execute` (both units), `CTransferSubUnitCommand::Execute` (both units), `CUnitSplitCommand::Execute`, `CUnitDeployment::JoinUnit`, and a leader's change of rank. These are only for the player.
- **Tree changed** (`QueueTreeChanged`): `CAttachUnitCommand::Execute`, `CDetachUnitCommand::Execute`, `CCreateHigherCommand::Execute`, `CUnitDeployment::DeployAt`, `CUnitSplitCommand::Execute`.

`RepositionUnit`: any existing row of the unit is removed with its children rows; with no parent the row is appended at level 0; with a parent whose row is **on the list and expanded** it goes at level parent+1 at the end of the parent's children; otherwise the row is left out. Where the unit is selected, `ScrollToUnit`.

**Rows are pooled**, two pools of `COOBUnitEntry*` by list, handed out in order; a list's clear only resets the used count, except where a swap in `CopyList` and `RemoveBelow` keeps the pool's used/unused order correct.

**`ScrollToUnit`** (does nothing with `follow_selection` off; see section 8): opens every row above the unit, then a scroll offset from `-visibleRows`, +1 for each row up to the unit's and +1 per following deeper row while at least three visible rows remain, floored at 0, set as `floor((f + 0.0005) * 1000)` thousandths. Taken together: the row ends at the bottom of the view, or higher so its children show.

## 5. The row: `oob_unit_entry` / `oob_actual_entry`

A `COOBUnitEntry`, 0x168 bytes. The unit is held as a persistent reference, re-resolved each use. `OOBEntry_FillUnit` writes:

| element | filled with |
| --- | --- |
| `unit_name` | the unit's name (slot 7 of CUnit) |
| `unit_info` | `£type ` for each of its first five brigades, the type key after `£`; `...` after five where more remain |
| `leader_photo` | `gfx/pictures/portraits/%s.tga` of the leader's portrait (+0xA8), the null leader's where none; shown. Over this the row's tooltip is the leader's own |
| `counter_type` | `GFX_counter_` + the first brigade's type where the unit's `intel_level` (+0x1F8) is 3 or more and it has a brigade with a definition, else `GFX_counter_` + empty |
| `counter_size` | frame by oob_level: theatre 6, army group 5, army 4, corps 3, a division 1 with one brigade or 2 with more, a fleet 2, otherwise (an air unit) 1 |
| `expand_button` | frame 2 where the next row is deeper (open), 1 otherwise; shown only where the unit has children (`+0x1EC` count). Inference on the last part: read as visible against hidden; a test of slot 48 of the button sits before the show/hide, not named in the record |
| `drag_button` | the row's background, `GFX_oobentry_bg` 4 frames: **frame 2 is the selected unit's row** and any row a valid drop is under; 1 otherwise; while a drag is on, disabled where the drop is not allowed |

There is no colour on any of it beyond the `£`/`§` of the texts.

## 6. The floating rows, and there is no leader list

`oob_leader_entry` and a second `oob_unit_entry` are made once, hidden, and shown only while dragging. **Nothing puts `oob_leader_entry` in a list**: the string has one reference in the image, the template load in the constructor. So the brief's "leader list, order, filter" does not exist in this window. The strings `leader_name`, `leader_rank`, `leader_info`, `leader_traits` are read only for the floating row and the leader window.

`OOBEntry_FillLeader` (the floating row):

- `leader_name`: rank name, a space, the name;
- `leader_rank`: frame = rank (+0x6C);
- `leader_photo`: portrait;
- `leader_info`: `LEADER_SKILL` + ` §Y` + skill + `§b ` + `LEADER_XP` + ` §Y` + `FormatFixedPoint(experience percent * 100000 / 1000, 2 decimals)` + `%`; where his unit is naval or air, `\n§b ` + `LEADER_COMMAND_SIZE` + ` §G` or ` §R` (`CUnit::LeaderHasRankForCommand`) + `CLeader::CommandSize` + space + `SHIPS_LABEL`/`PLANES_LABEL` (ships / air wings);
- `leader_traits`: a `CTraitEntry` for each trait (+0x30).

## 7. A row's tooltip (`COOBUnitEntry_BuildTooltip`)

Over `leader_photo`: the leader's own tooltip (slot 9), where he exists. Over the row's window, the main line:

    §Y<leader's name>§W\n        (only where he exists; his name, +0x4C)
    <unit name>\n
    <province name>\n
    <n> £<type> {NN{NN ...\n      (one line per brigade type held, `%d £%s `; a `{NN` per brigade)

The bar is `{%02d` with `NN = strength * 1000 / max_strength * 10 / 1000` (tenths, truncated; a definition with no maximum gives 0). The delayed half is `OOB_UNDER_COMMAND` = "Total under command:\n", then `%d %s\n` per oob_level strictly below this unit, level 1 `NUM_GROUPS` (Army group(s)), 2 `NUM_ARMIES` (Army(s)), 3 `NUM_CORPS` (Corps), 4 `NUM_DIVISONS` (Division(s), the key is spelled so), 5 `NUM_SHIPS` (Fleet(s)), 6 `NUM_WINGS` (Squadron(s)), 7 `NUM_UNKNOWNS` (Unknown(s)), a blank line, then every brigade of the subtree by type in `%d £%s  ` (two spaces). Level 0, a theatre, has no word and cannot be below anything.

## 8. Clicking and selection

A row's `drag_button` and `leader_photo` have two handlers each (the glue's first and second). On a click (`COOBUnitEntry::OnClick`), where the unit exists and is selectable:

1. deselect it if selected;
2. `follow_selection` (+0xF5) off;
3. an open country view is closed (screen's slot 93);
4. the selection cleared and the unit selected (slot 34 path, so `AddUnitRow` runs);
5. the map centred on the unit's province (slot 47);
6. `follow_selection` back on.

So selecting from a row does not scroll the list. A selection made anywhere else while the browser is up does: `AddUnitRow` and the deploy menu's hide call `ScrollToUnit`, and any row reposition of a selected unit does too. `expand_button` calls `COOBBrowser_ToggleRow`.

## 9. Dragging: what can be dragged, what it posts

The press handlers start it: a row's `drag_button` a unit (`BeginDragUnit`), its `leader_photo` the unit's leader (`BeginDragLeader`). Nothing in the browser drags a brigade or a ship; they arrive from the unit panel's sub-unit rows (`CSubUnitEntry`, `BeginDragSubUnit`), and from the unit panel's child rows and the outliner (`BeginDragUnit`), `CUnitView::OnLeaderButton` (`BeginDragLeader`) and the deploy menu's mouse observer (with a `CDropAndAssignUnitDeploymentCallback`). Those windows are thus all drop sources into this object, which is `COOBBrowser`, the in-game screen's slot 105 object that `FINDINGS-outliner.md` named without identifying.

**Drag state**, `drag_state` (+0x9C), in `COOBBrowser::Update` each frame: 1 picked up, 2 the mouse's position noted, 3 once the mouse is more than **2 pixels** from that point on either axis. Nothing happens below 3.

**While dragging** (button held and state 3): the template row follows the mouse: `oob_unit_entry` at (x, y) with `expand_button` hidden and `drag_button` disabled, filled by `OOBEntry_FillUnit` or `OOBEntry_FillSubUnit`; `oob_leader_entry` at (x + 10, y). Rows update (section 5); a row hovered for **1.0 second** (accumulated in `elapsed` while the point is inside) opens, where it is closed. The list under the mouse scrolls by `COOBBrowser_AutoScroll`: above the top or below the bottom edge, a counter moves by `sqrt(distance) * elapsed`, one line each time it passes 1.0.

**On release**, `UnitRows_HandleDrop` (already recorded, 0x33A7C0) on the main list, and on the split list if the main answered false:

- **A unit on a row**: `CUnit_MayTakeSubordinate(row's unit, unit, 0)` (commander's level strictly lower; land commander below a theatre takes at most five land subordinates; naval or air only under level 3 or below - see that record). Allowed: a deployment callback, where present, is handed the row's unit and cleared, and a **`CAttachUnitCommand(unit, row's unit)`** is posted. +0xF8/+0x120 keep the two references.
- **A brigade/ship/wing**: `CUnit_CanTakeSubUnit(row's unit, its owner's country, sub, sameProvince = no callback pending)` (the eleven tests in its record), then **`CTransferSubUnitCommand(row's unit, sub)`**.
- **A leader**: `CUnit::MayTakeLeader(row's unit, leader)` and, where the row's unit has a real leader, `MayTakeLeader(the dropped leader's unit, that leader)`: then **`CAssignLeaderCommand(row's unit, leader, 0)`** and, in the second case, **`CAssignLeaderCommand(his old unit, the row's old leader, 0)`**, a swap.

Commands' `Execute`: already recorded (`CAttachUnitCommand::Execute` - `CUnit_AttachToParent`, which itself refuses a mismatch of owner or level; `CTransferSubUnitCommand::Execute`; `CAssignLeaderCommand::Execute`). There is no undo: `COOBChange` is a country-history entry, and the only record of a drop beyond the command is the two unread CRefs at +0xF8/+0x120.

**A drop that is not on a row does nothing.** The hover tests (`UnitRow_UpdateUnitDragHover`, the sub-unit's already recorded, `UnitRow_UpdateLeaderDragHover`) repeat the same conditions to colour the rows. The unit-on-a-row hover and the hover-open use the row's own unit against the dragged one.

## 10. The second view

`split_window` is a second list of the same kind beside the first, with the same collapse, expand, focus and rows. It starts hidden. `split_button` shows it (copying the main list first, with its scroll) and hides it. `match_views_button` is only `CopyList` from main to split. The two lists are otherwise independent: separate pools, separate scroll, separate expansion. Rows and drags work on both identically; `UnitRows_HandleDrop` tries main first.

## 11. What is not established

- Slot 48 of a button, tested before `expand_button` is shown or hidden. Read as "is hidden" for that one call (inferred); only the visible result (hidden with no children) is confirmed.
- The readers of `last_drop_target` (+0xF8) and `last_dropped_unit` (+0x120): written by a unit drop and cleared by `Close`; no reader in this class's code. The image was not swept for them.
- `FUN_004208B0`'s flag: which custom-game condition the record's +4 byte is. Left in the frontier; OpenHOI3 has no custom game.
- The exact visual appearance of `drag_button`'s four frames and when frames 3 and 4 arise (no code here sets them).
- Whether a `CCreateHigherCommand`-created headquarters is on the tree by `QueueTreeChanged` alone: yes from the call site, but the new unit's row only appears if its parent's row is expanded or it is a root, by the rules in section 4.
- `COOBChange::Apply`'s direction flag: likely, from the sibling history entries.

## 12. Oddities kept as read

- `theatre_forces_button` is on the main window only, and the split window has none.
- `NUM_DIVISONS` is the key's spelling.
- `unit_info` stops at five brigades with `...`.
- Expansion is lost whenever any row's unit dies, because the list is rebuilt from the roots.
- `split_button` always copies the main list onto the split list on opening, losing whatever the split list had.

Frontier: `0x4208B0` (a custom-game flag for the local player), and `UnitRows_HandleDrop`'s and `UnitRow_UpdateSubUnitDragHover`'s comments, which still say the drag object's owner is unread. It is `COOBBrowser`.
