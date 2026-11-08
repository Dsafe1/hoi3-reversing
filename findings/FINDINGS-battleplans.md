# Battle plans: the window and the plans

*Addresses are rvas; offsets are for this build only. Text keys are as the install's tables give them, Windows-1252. Confidence: confirmed unless a line says inferred.*

## 1. The two buttons on the menu bar

`menubar_plans_toggle` and `menubar_plans_open` are declared in `menubar.gui`, LOWER_RIGHT at (-36,-227) and (-36,-194), `clicksound = click`. The toggle has `shortcut = "b"`; open has none. Their sprites are `GFX_bp_toggle_visible` (2 frames) and `GFX_bp_open_manager`. Neither is ever hidden.

- **Toggle** (`CInGameIdler::OnPlansToggle`): flips the manager's show-on-map flag (+0x3B8, set to 1 by the manager's constructor and never saved). Frame 1 is on, 2 is off. Tooltip `BP_TOGGLE_TOOLTIP` "Show/Hide the current battle plans."
- **While the window is up, every frame, the toggle is disabled** (button slot 47), and it is enabled (slot 46) otherwise.
- **Open** (`CInGameIdler::OnPlansOpen`): manager slot 3 (hide) if the window is up, slot 2 (show) otherwise. Tooltip `BP_OPEN_TOOLTIP` "Open/Close the battle plan editor."
- Neither handler touches the game speed or any country screen, so opening the window does not pause. Both were read whole.

The plans are drawn when **the show-on-map flag is on or the window is up** (render gate in `CInGameIdler::Update`'s drawing, read at VA 0x656ED9 and 0x6571C7): for each plan of the shown list with `visible` set. So several plans are on the map at once, and turning the toggle off still leaves them visible while the window is open.

## 2. The window

There is one `CBattlePlanManager` per in-game screen (+0x1DE8), 0x3C0 bytes, made in `CInGameIdler::Enter` from the screen and its interface parent, then hidden at once (slot 3). Its `Reload` (slot 0) tears down and rebuilds: reads `bp_settings.txt` (B), takes the played country, fills the lists, finds every element by name, hides `tools`, `options_window` and `text_prompt_window`, builds the option buttons (B), and lands on tab 0.

`battleplans_window` is `LOWER_RIGHT` at (-400,-550), 300x300, `moveable = 1`. `close_button` (302,7, `GFX_close_button`) calls slot 3.

- **Show** (slot 2): window shown, tab 0, save mode off, list refilled, action rows and tools refreshed. Rename mode is not cleared.
- **Hide** (slot 3): if a live plan is selected its drawn objects lose their selection; window hidden. Modes are left as they were.
- It is not modal. Each frame, while up, the function at `0x12AA0` first compares the played country with the copy at +0x3A0: a difference rescans the lists and returns to tab 0. It then updates the list box and sets each tab's frame to 1 for the chosen tab and 2 otherwise.
- **Does a map click still select?** Yes, unless a drawing tool takes it. Only on tab 0 with a live plan of the player's country selected are mouse events marked consumed: tools 1 to 5 always take a left press; the select tool 0 takes it only with Ctrl or Shift held (slots 12 and 10 of the keyboard). Otherwise the click goes on to the ordinary map handling. Detail is B's. `UpdateMapInput` runs before `CInGameIdler_HandleInput`.
- Selection of units is not changed by opening or closing the window (no call to it in either handler).

`bg` is declared in the file and not looked up by name.

## 3. The tabs

Tab 0 Current, 1 Historical, 2 Saved, in +0x34C.

| element | title key, text | tooltip key, text |
| --- | --- | --- |
| tab_current | `BP_TAB_CURRENT` "Current Plans" (`tab_current_title`) | `BP_TOOLTIP_TAB_CURRENT` "List of current battle plans." |
| tab_historical | `BP_TAB_HISTORICAL` "Historical Plans" (`tab_historical_title`) | `BP_TOOLTIP_TAB_HISTORICAL` "List of historical battle plans.\nClick §YImport§! to add the selected one to your current plans." |
| tab_saved | no title box and no `BP_TAB_SAVED` key; the art has its words | `BP_TOOLTIP_TAB_SAVED` "List of your saved battle plans.\nClick §YImport§! to add the selected one to your current plans." |

Clicking a tab sets the tab and refills the list; `tab_current` and `tab_historical` also turn save mode off, `tab_saved` does not. None of the three clears rename mode.

Which row of buttons shows (`BattlePlanManager_RefreshActions`): the tab's `actions_list_*` when neither save nor rename mode is on; the other two lists are always hidden. In either mode the rows go and `save_confirm`, `save_cancel` and `save_editbox` show.

Lists, in order:

- **Current (+0x360)**: the played country's own plans in their own order, then for every other country by id, each plan with `shared` set whose author's `Allies` list holds the player's country (`BattlePlanManager_RebuildShown`).
- **Historical (+0x370)**: every file of the folder of the played country's tag (no extension filter), one row each, read by header only. A row whose header fails is destroyed. Order is what the enumeration returns.
- **Saved (+0x380)**: the same for the saved folder, except that **a file whose header fails stays a row**: title "?" unless its title was read, country id 0.

Historical and Saved are scanned in `Reload` and when the played country changes; Saved also after a save or a delete.

## 4. The list and its rows

`listbox_plans` at (23,48), 293x212. Rows are `battleplan_entry`, 281x35, a `CBattlePlanEntry` holding a checkbox `background_button` and these elements:

| element | what fills it |
| --- | --- |
| `flag` | `GFX_flag_tiny`, frame set to the plan's country id |
| `title` | the plan's title, set each frame |
| `file_path` | **only on a file row**: the file name after the last `/` and before the first `.` |
| `visibility` | `GFX_bp_visibility_icon`, shown only for a live plan; frame 1 when visible, 2 when not |
| `share_with_allies` | `GFX_bp_share_with_allies`, shown only for a live plan of the player's country; frame 1 shared, 2 not |
| `countries` | never looked up; the file puts it far off the row |

`background_button`'s +0x136 is set where the plan's country is the player's and clear otherwise; a box with it clear is drawn in its last frame (0xA81AA0). *Inferred: an allied row is drawn disabled; whether it can still be clicked was not read.*

Clicks: `background_button` selects the row and ticks it. `visibility` flips the plan's `visible` with no test of whose plan it is. `share_with_allies` flips `shared` where the plan is live and of the manager's country, and sets `dirty`.

Selection: when the list is refilled, the row already selected names the selected plan (+0x390). If none is selected, the first row whose plan is of the manager's country is selected and ticked. Allied rows are never auto-picked. On Save, Rename and the tools the plan must be live and of the player's country; a selection on a file row is only for `load_plan` and `delete_plan`.

Tooltips of a row: `share_with_allies` gives `BP_TOOLTIP_SHARE_PLAN` "Toggle §Ysharing§! currently selected plan with your §Gally members§!."; where the plan is shared, a delayed half `BP_SHARED_WITH` "Shared with:" and a line `\n- @TAG Name` for each ally of the author, or `\n- §Y` + `NONE` ("None") + `§!` where there are none. `visibility` gives `BP_TOOLTIP_VISIBILITY` "Toggle plan visibility on the map." Nothing else on the row answers.

## 5. The actions

No button is ever greyed. A press with no eligible plan simply does nothing.

| button | tooltip | condition | does |
| --- | --- | --- | --- |
| `new_plan` | `BP_TOOLTIP_NEW_PLAN` "Create new plan." | none | new plan, title `BP_NEW_PLAN` "New Plan", country the player's, `live`, `visible`, `dirty`; appended to the country's list; refilled, selected, **rename opened on it** |
| `remove_plan` | `BP_TOOLTIP_REMOVE_PLAN` "Delete currently selected plan." | selected plan live and the player's | `CConfirmDeletePlan`, mode 1 |
| `share_plan` | | | **no such name in the executable**: dead (the file parks it at x 99948) |
| `save_plan` | `BP_TOOLTIP_SAVE_PLAN` "Save currently selected plan to file." | selected plan live and the player's | plan_to_save = it, save mode on, tab 2, name box filled with the title |
| `rename_plan` | `BP_TOOLTIP_RENAME_PLAN` "Rename currently selected plan." | selected plan live and the player's | rename mode on, name box filled with the title |
| `load_plan` (both tabs) | `BP_TOOLTIP_IMPORT_PLAN` "Add selected plan to your current plans." | a file row selected | a new plan read whole, drawn, `visible`, appended to the list of **the country named in the file**; the shown list rebuilt; the row and the tab stay |
| `delete_plan` | `BP_TOOLTIP_REMOVE_PLAN` | a file row selected | `CConfirmDeletePlan`, mode 0 |

Save and rename: `save_confirm` shows `BP_SAVE_PLAN_CONFIRM` "Save Plan" in save mode and `SM_APPLY` "Apply" in rename mode; `save_cancel` is `BP_SAVE_PLAN_CANCEL` "Cancel".

`save_confirm`:

- **Rename mode**: a non-empty box becomes the title (`dirty` set), mode off.
- **Save mode**: the text trimmed of whitespace. Empty does nothing and the mode stays. Any byte 0x80 or above, or `/` or `\`, opens `DefaultInfoDialog` titled `BP_FAILED_SAVE_FILE` "Failed to save the battle plans.", described `BP_ILLEGAL_FILE_NAME` "File name contains illegal characters!", and the mode stays.
- Otherwise `.pln` is appended unless the last `.` is past the first character and the text from it is exactly `.pln` (case-sensitive compare).
- Path = saved folder + `/` + name. Existing file: `CConfirmSavePlan` (`DefaultConfirm`, description `BP_SAVE_PLAN_PROMPT` "Battle Plan already exists!\nDo you want to overwrite?"); confirm writes it, cancel closes and leaves save mode on. Not existing: written at once.
- After a write: saved folder rescanned, save mode off, tab 2.

`save_cancel`: from save mode, mode off, stays tab 2; from rename, mode off, tab 0.

In save mode on the Saved tab, picking a file row fills the name box with its name (`BattlePlanManager_OnSavedRowChosen`).

Delete dialogs (`CConfirmDeletePlan`, `DefaultConfirm`): mode 0 `BP_DELETE_SAVED_PLAN_PROMPT` "Are you sure that you want to delete the saved battle plan?", confirm deletes the file through PHYSFS and rescans, tab 2; mode 1 `BP_DELETE_CURRENT_PLAN_PROMPT` "Are you sure that you want to delete the current battle plan?", confirm posts a `CBattlePlanDeleteCommand`.

The bytes at VA 0x1A8554C and 0x1A8554D are set and cleared by these two dialogs and read by nothing (address scan over `.text`).

`text_prompt_window` (`text_editbox`, `apply` with `SM_APPLY`) is the text tool's and is read in B's write-up.

## 6. The plan as data

A plan is a 0x260-byte object with no RTTI class. Fields as in the table above. It has no id of its own: it is identified by its country and its position in that country's list. The manager keeps one vector of plans per country (+0x350, one 0x10-byte vector per country id). Nothing caps the count of plans or the title length.

`live` (+0x1F0) is 1 for a whole plan and 0 for a header-only row of a tab. `dirty` (+0x21C) is set by a new plan, a rename, a load, a share toggle and any drawn change.

Records (the file form; the drawn objects are B's):

- Arrow and border, 0x58: points vector +0, type +0x10, colour +0x2C, transform +0x30/+0x34, text +0x38, ignore_smoothing +0x54.
- Icon, 0x34: position +0/+4, type +8, colour +0x24, rotation +0x28, transform +0x2C/+0x30.
- Text, 0x34: position +0/+4, text +8, scale +0x24, rotation +0x28, transform +0x2C/+0x30.

## 7. The format, in both directions

Written by `BattlePlan_Serialize`, read positionally by `BattlePlan_Read`: each key is compared with the next one expected, and a missing key is simply not consumed. The two match key for key, and shipped files follow it.

    title="..."
    country="TAG"
    [visibility=yes|no]            only in a saved game
    arrows_count=N
      control_points={x y x y ...}  and  text="..."   N times
      matrix_transforms={ ... }  ignore_smoothing={ ... }  type={ ... }  color={ ... }
    icons_count=M
      positions={ ... }  matrix_transforms={ ... }  type={ ... }  color={ ... }  rotation={ ... }
    texts_count=K
      positions={ ... }  matrix_transforms={ ... }  text="..."  K times  scale={ ... }  rotation={ ... }
    is_battle_plan_shared=yes|no
    borders_count=B
      control_points={ ... }  text="..."  B times
      matrix_transforms={ ... }  ignore_smoothing={ ... }  type={ ... }  color={ ... }

- A block with no entries is not written at all. With `N` = 0 none of that section's blocks follow.
- Coordinates are `floor((value + 0.0005) * 1000)` as an int on the way out and `int / 1000.0` as a float on the way in.
- `control_points` holds x then y for one arrow or border; `ignore_smoothing` is a list of integers (-1 in the shipped files).
- Every block prints as `key=` then `{` on the next line, then the values separated by single spaces, then ` }`.
- `visibility` is written only while +0x1CD is set, and only `CGameState::SaveContents` sets it, for its own write. A `.pln` never carries it, so a file row loaded gets `visible` = 1 from the handler instead.
- A read ends with `dirty` = 1, `live` = 1, path cleared.
- `full` = 1 (file and save writes): the records are first rebuilt from the drawn objects and emptied afterwards. `full` = 0 is for the send command, whose plan copy already holds records.
- The command form carries `index` and a `battle_plan = { ... }` block written with `full` = 0.

## 8. Files

- **Saved**: `battle plans/<TAG>`, or `mod/<X>/battle plans/<TAG>` where the settings name a mod, one file per plan: `<name>.pln`. On disk the save games for a mod are in `Documents\...\<mod folder>\save games`, so *inferred* the same mapping applies to `battle plans`. The maintainer has no such folder yet.
- **Historical**: `battleplans/historical/<TAG>` through the game's search paths, or `mod/<X>/battleplans/historical/<TAG>`, which then replaces rather than adds. The install has 53 files in folders ENG, FRA, GER, ITA, JAP, SOV, USA. **17 of them contain only `#empty`** and fail the header test, which is how those are removed from the list. BlackICE ships its own `battleplans` folder with `bp_settings.txt` and `historical`.
- The enumerator (`ListFilesWithExtension`, called with no extension) drops names with a byte of 0x80 or above and directories.
- Header read requires `title` first then `country` second, a non-empty title, and a country other than id 0.
- The startup at 0x633F54 and 0x63404A passes `battleplans` with `.pln` to the function at VA 0xAB3E00 alongside `.txt`. *Inferred: the startup file checksum.*
- Encoding is the game's text (Windows-1252).

## 9. Sharing

A plan is shared by flipping `shared` on its row. There is no `share_plan` action.

- **Sending** (`BattlePlanManager_SendChangedPlans`, called each frame from the in-game update only in a multiplayer game, screen +0x68): every 2.0 seconds of the clock, for each plan in the player's own list with `dirty` set: `dirty` cleared and a `CBattlePlanSendCommand` posted with a copy and its index. In single player it is never called.
- **`CBattlePlanSendCommand`** (0x44): plan copy +0x3C, index +0x40, token `battle_plan_send` 0x80C.
  - IsValid: the plan pointer is not null.
  - Execute on the author's machine: nothing.
  - Execute on every other machine: in the author's country list; at or beyond the end the list is padded with nulls and the copy appended (ownership moves, drawn); otherwise the plan at that index has its drawing replaced, title and shared flag copied. Then the shown list is rebuilt and, on tab 0, the list refilled.
  - A null left by padding would be dereferenced by the rebuild: the code assumes plans arrive in index order.
- **`CBattlePlanDeleteCommand`** (0x48): country +0x3C, index +0x44, token `battle_plan_delete` 0x80D. Execute, on every machine, removes that entry from that country's list if the index is in range. It is the only way a current plan is removed, also in single player. The index is the plan's position in the shown list, which is correct because the player's own plans lead it.
- Receivers see the plan in Current only if `shared` is set and the author's `Allies` holds them. A received plan is `visible` = 1 from `CBattlePlanSendCommand::LoadKey`. No message, alert or sound is raised. Unsharing sends the flag and the plan simply drops out of allies' lists.
- **Nothing reaches the AI.** Every reader of the manager pointer (screen +0x1DE8) is known from a byte scan of the displacement: the screen's constructor and destructor, `Enter`, the two buttons, `Update` and drawing, its tooltip routine, `SaveContents`, and the two commands.

## 10. The saved game

`CGameState::SaveContents`, where the screen has a manager: for each country in the game's order, for each plan in that country's list (allied plans included): a `battle_plan = { ... }` block written by `BattlePlan_Serialize` with `full` = 1 and +0x1CD set around the call.

On load: `CGameState::LoadKey`'s `battle_plan` case makes a plan and reads it into the vector at +0xD58. `CGameState::ResetSession` frees that vector.

`CInGameIdler::Enter`, for a loaded game only (`loaded_from_save`), for each plan in +0xD58: sets its screen, builds its drawing, and appends it to the country list named in the plan; then the vector is emptied and the shown list rebuilt. A plan's `visible` comes from its `visibility` key. In multiplayer every loaded plan is then sent because `dirty` is set by the read.

The maintainer's saves hold no `battle_plan` block (`^battle_plan=` over the save games folder), so this part rests on the reading and on the shipped files for the keys only.

## 11. Declared in the file and not touched

`bg`, `share_plan` and `countries`, as above. `tab_current_title` and `tab_historical_title` get no code; their text is the file's `text`. The keys of `bp_settings.txt` are B's.

## What is not established

- What a click on a row whose background box has +0x136 clear does (an allied row).
- The physical folder for `mod/<X>/battle plans` (the Documents layout says `<mod name>/`; not traced through the mount).
- The order of a list beyond "as the enumeration returns it"; the sort inside PHYSFS was not read here.
- Whether a pending delete on one machine can race a send of the same plan; the index would shift. Not exercised.
- What `0xA90140` and the halfword +0x40 of the edit box do exactly; they are taken as giving it focus (inferred, the same pair the other screens use).
- No game has been run: everything here is read, and the only file oracle is the shipped `.pln` set.

Frontier: 0x7EC0 (records from the drawn objects), 0x8AF0 (drawn objects from the records), 0x2A00 (clear drawing), 0x73C0 (unselect objects); all left to reader B's drawing work.
