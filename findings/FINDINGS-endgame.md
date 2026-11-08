# How a game ends

*The end-of-game wave, 2026-11-08 (`WAVE.md`, `CANDIDATES.md`). What lies between a game's last hour and the main menu, and the windows that say how near it is; the rules of the conditions themselves are `FINDINGS-factionplay.md`, C. Read statically: there is no save or file that holds what these screens show. Addresses are VAs unless a line says rva.*

## A. The end

*Fragment `endgame-backend.json`. Localisation is the same in `localisation` and `tfh/localisation`. `interface/backend.gui` and `interface/eu3dialog.gui` exist only in the base install; TFH ships no copy, BlackICE ships its own `backend.gui` and `backend.gfx` (not read). Positive control: every string `FINDINGS-factionplay.md` quoted for the dialog comes out of this reading unchanged.*

### A.1 The dialog `VCConfirm` (constructor rva `0x270C20`, a `CConfirmVictoryConditionResign`, 0x6C bytes)

*Confirmed from the bytes.*

**Who it names.** The dialog works this out itself; the caller passes nothing. Walk the game state's list of factions (`+0xCE4`, node data +0, next +8; the save writes them in that order: axis, allies, comintern). For each, count its chosen conditions (manager `+0x18[f]`, the factions' index found in manager `+0x8`, a faction the manager does not hold counting 0) with the met byte set.

    if (best <= count) { best = count; winner = faction }

Starting from 0: a tie goes to the **last** faction in the list, and with nothing met the winner is the last one (comintern).

**Title** (element `Title`):

- winner is the played country's own faction (`CCountry +0xD8`): `CONFIRM_VC_VICTORY` "Victory!";
- otherwise `CONFIRM_VC_DEFEAT` "Defeat!" - a country in no faction holds the null faction, so it always sees Defeat.

**Text** (element `Description`): `CONFIRM_VC_TEXT` "§Y$FACTION$§W has achieved their victory conditions.\nDo you want to continue playing or resign the current game?", `$FACTION$` being the winner's localised name (`CFaction` slot 6; so Axis, Allies, Comintern).

**The end date's dialog says nothing different.** Same code, same words, naming the faction with most met (last on a tie) whether or not anybody achieved anything. So on 1 Jan 1948 with nobody at 12, the player is told comintern (or whoever leads) "has achieved their victory conditions".

**Elements** (from the file): window 500x280; `Background` button, `default_popup_banner` icon, `Title` (Arial_17, centred, 500x32), `Description` (Arial14_black, centred, 360x200), `AgreeButton` "VC_RESIGN" ("Resign", ENTER) at 264,200 and `DeclineButton` "VC_CONTINUE" ("Continue", ESCAPE) at 104,200. The file's position -250,-140 CENTER is overridden: the constructor sets the position to (screen_w/2 - w/2, screen_h/2 - h/2), each a truncating int division.

**Buttons.** Resign is slot 5, `CConfirmVictoryConditionResign::OnAgree`: `RequestGameOver` (slot 74), the same end as the menu's Resign. Continue is the base's slot 6, `CEU3Dialog::Close`: only closes.

### A.2 Slot 75 and what Continue leaves

`ShowVictoryConfirmDialog` (rva `0x271A10`), *confirmed*:

1. if `+0x12E1` is clear: make and add the dialog, set `+0x12E1`. This byte is cleared by the constructor and written nowhere else (three sites in all, by `fieldchain`), and it is not saved, so a load shows the dialog again where the route fires again.
2. then, on **every** call: where slot 95 (`IsPaused`, `+0x12D8`) answers no, slot 27 (`TogglePause`).

`TogglePause` in multiplayer posts a `CPauseGame` (0x5C bytes, made with the local player and 0 at `0x6D7F10`); otherwise it sets `+0x12D8 = 1` (a tutorial can stop it).

**Who calls it, and what follows.**

- *The victory route* (`VictoryConditions_DailyCheck`, the last thing `RunDailyPass` does): once, then `game_finished` stops the test. So: the game pauses as the dialog comes up, Continue only closes it, the game **stays paused**, and the player unpauses and plays on with `game_finished` set and no further dialog. *Confirmed by the reading of each step; not run.*
- *The end date.* `CInGameIdler::Update` at `0x655C19`: with a scenario (`state +0xD0C`), `tick > CScenario +0xAC` calls slot 76; with none, `tick > defines +0xC (end_date)` calls slot 75. Strictly after: `jle` skips equality. **There is no gate on the test**: from the head of Update every edge lands at `0x655B91` and the test follows. It runs every frame, paused or not, in single player and multiplayer alike. So past the end date: the dialog comes up once, but slot 27 fires on any frame the game is not paused, so the clock cannot be run past the end date. The only way on is Resign, from this dialog or the in-game menu.
- In multiplayer the same test would post a `CPauseGame` every frame while unpaused; how the queue handles the repeats was not read.

**A third way to the end with no dialog.** `ProcessSessionEndRequests` (rva `0x2542B0`): each frame, the played country with `NumberOfOwnedProvinces < 1`, not tagged `REB`, and the idler's `+5` (`map_painting`) clear, sets `game_over_requested` itself and goes to the back end that frame.

### A.3 `RequestGameOver` to the back end

`RequestGameOver` (slot 74, rva `0x24C010`) sets `+0x1CD9`. `ProcessSessionEndRequests` the same frame: releases `[0x1A857E8]`; in multiplayer installs the placeholder session; frees `+0x1D28`; calls the music object's slot 4 (a stop, *inferred*); runs `0xA7C820` (the gui's `+0x238 = 1` and slot 12 on each of its entries); makes the 0x600-byte `CBackEndIdler` (`MakeBackEndIdler`) and installs it as the pending screen.

`MakeBackEndIdler` constructs the idler, points the map's listener at it, calls `SetInGameScreen`, sets `g_MessageHandler +0x30 = 0`. It **does not reset the game state.** `CEU3Application::Run`'s swap then runs the outgoing screen's Leave (this is what clears `in_game` at `0x662337`), slot 2 with the application's +0xE4/+0xE8, slot 3 (Enter), slot 5 (a stub).

**The world behind it.** The game state lives on behind the back end, untouched until Exit. `CBackEndIdler::Update` (slot 1) pumps the two sessions, so commands that arrive still run, and otherwise runs only the interface: nothing calls the tick, the map or the AI. Slots 14 onward are getters. Enter runs once.

**What Enter shows** (every element of `back_end`, *confirmed*; the text is set once at entry and not refreshed):

| element | what it shows |
| --- | --- |
| `loser_background` | **Never touched.** The default picture, under everything |
| `allies_won`, `axis_won`, `comintern_won` | Hidden at entry. The winning faction's `<tag>_won` is shown if a tier was reached, none for Stalemate |
| `player_shield` | the played country's flag (slot 53 by id, then the icon's slot 73, not read) |
| `player_shield_right` | looked up and guarded; commented out in the file |
| `country_value` | the played country's localised name (`CountryNameOfCountry`) |
| `result` | the tier text, A.3.1 |
| `Exit` | `EXIT` "EXIT", the button; wired to `CBackEndIdler::OnExitButton`. No shortcut |
| `factions` | **Declared in the file and touched by nothing**: no string names it, and no call finds it. An empty list box |

**Per faction.** Three, hard-coded by name and in this order: `allies`, `axis`, `comintern` (`FindFactionByName` over the ideology groups; a name that is not there answers the null faction). `<f>` below is the faction's own tag:

| element | what it shows |
| --- | --- |
| `<f>_icon` | button frame = the faction's `icon` (`+0x3C`; 1 to 3, `GFX_icon_factions` has 3 frames) |
| `<f>_label` | the faction's localised name (`CFaction` slot 6) |
| `<f>_members` | an overlapping box of `backend_faction_member_entry` rows, one per country in `Members` (`+0x28`, a `CList<CCountryTag>`, in the list's order); the row is a 32x32 window whose `flag` icon (`GFX_minishield`) is given the country by id (slot 53) |
| `<f>_goals` | a list of `end_vc_entry` rows, one per condition in `chosen[f]` in that vector's order |
| `<f>_vc` | `END_VICTORY_CONDITIONS` "$NUM$ of $TOTAL$ Victory Conditions", NUM = rows met, TOTAL = rows |
| `<f>_vp` | `END_VICTORY_POINTS` "Victory Points: $NUM$", NUM = `Progress` (`+0xAC`) / 1000, truncated |
| `<f>_progress` | a progress bar (`endgame_progress_small`, `progressbartype`) filled by slot 18 with `points * 100 / the three factions' points added together`, truncated; where that sum is 0, the bare `points * 100` |

Each `end_vc_entry` row: `name` = `GetText(condition's name)` (the name is itself the key, e.g. `operation_sealion` "Operation Sealion"); `date` set **only where the condition is met**, to `Date_FormatYearMonthDay(condition +0x64, abbreviated 1, with_hour 0)` = "YEAR Mon D" (the date it last came to hold, per `FINDINGS-factionplay.md` C.6, in a 68-pixel field); `background` frame 1 when not met, 2 when met (`GFX_victorycondition_entry_bg`, 2 frames). A row object is a 0x28-byte generic list entry holding its window at +0x20 (vftables `0x15FE808`/`0x15FE838`; the same object for both kinds of row; the second kind's constructor is `0xA8BBD0`).

#### A.3.1 The result, worked out at entry from the state as it stands

For each faction f, with the other two o1 and o2, `met` being the count of chosen conditions met today and `vp` the points of `<f>_vp`:

    tier(f) = 5
    if met[f] >= to_win and met[f] > met[o1] and met[f] > met[o2]:
        tier(f) = 0 if vp[f] > vp[o1] + vp[o2] else 1
    elif vp[f] > vp[o1] and vp[f] > vp[o2]:
        if vp[f] > vp[o1] + vp[o2]: tier(f) = 2
        elif met[f] > met[o1] and met[f] > met[o2]: tier(f) = 3

to_win is manager `+0x3C` (defines' `VICTORY_CONDITIONS_TO_WIN`, 12). A six-slot array then records, for each tier, the index of the last faction (order allies, axis, comintern) to land on it, and the first filled slot wins in the order tier 0, 1, 2, 3. Each tier asks a strict maximum, so no two factions collide on one. None of this looks at `game_finished`, at the winner the daily test saw, or at who met 12 first: a condition lost before the end stops counting (it is "met today").

| tier | text (`result`) |
| --- | --- |
| 0 | the ideology group's localised name, a space, and `WORLD_ORDER` "World Order!" (e.g. "Fascism World Order!", key `fascism` "Fascism"; `Group_GetLocalisedName` of the faction's ideology group) - the same words whoever is playing |
| 1 | `STRATEGIC_VICTORY` "Strategic Victory!" where the faction is the player's own, otherwise `STRATEGIC_DEFEAT` "Strategic Defeat!" |
| 2 | `OPERATIONAL_VICTORY` "Operational Victory!" or `OPERATIONAL_DEFEAT` "Operational Defeat!", likewise |
| 3 | `TACTICAL_VICTORY` "Tactical Victory!" or `TACTICAL_DEFEAT` "Tactical Defeat!", likewise |
| none | `STALEMATE` "Stalemate", no `_won` picture |

So a player in no faction always sees Defeat in tiers 1 to 3 (`CCountry +0xD8` is never 0 in play). A further arm where the pointer is 0 reads the winner's slot at index -1; it cannot be reached (*inferred* from the null faction being a real object, `FINDINGS-factionplay.md` C.3).

Worked example: resigning on the first day of a 1936 start, factions' points 263 / 115 / 173 (allies / axis / comintern), none met. Allies are strictly most in points but not more than the other two added, and not strictly most in met: nobody qualifies. "Stalemate".

**Music.** If `CSettings +0x80` (the music volume, `GetGameSettings()+0x80`) is above 0: `music/victorymarchverdi.mp3` where the winner is the player's own faction, `music/diesiraeintro.mp3` otherwise (a Stalemate included, there being no winner). Through the music object's slot 2 (the `0xAB8CD0` singleton; a `CNullMusic` until a device replaces it). Both files are in `music/`.

**Tooltips.** None: every tooltip entry in the file is empty, and the screen's two tooltip slots (20 at `0x69ECD0`, 109 at `0x776F20`) both answer an empty text.

**Exit.** `CBackEndIdler::OnExitButton` (rva `0x20BAF0`): application input slot 4(1), `ResetGameStateToStartDate(1)`, slot 4(0), gui `+0x238 = 1`, the gui's entries' slot 12, a new `CFrontEnd` (`new(0x8B0)`), the swap. The front end comes up on the main menu.

### A.4 What looks wrong but is what the bytes do

1. A tie in the dialog goes to the last faction in the list: with no conditions met the end date's dialog names the comintern.
2. The dialog's "$FACTION$ has achieved their victory conditions" is said even when nobody has.
3. The dialog says Victory or Defeat by the top faction, and the back end's own tier logic can then say something else entirely: it counts points as well, is strict where the dialog takes ties, and does not read the dialog's choice. A faction with 12 conditions and the most points but not more than the other two added gives a Strategic rather than a World Order, and a Defeat title can precede a Tactical Victory.
4. Past the end date the game can be paused and Resigned from but not played on.
5. A bar's fill is the faction's share among the three factions only, not of the world's points (1172), which is what the diplomacy screen's bar uses.

### A.5 Not established

- `CFaction`'s tag when `FindFactionByName` answers the null faction (a mod renaming a faction): the element lookups then fail on `<null tag>_*` names; not traced.
- Icon slot 73 on `player_shield` (`0xAA27E0`): the shield's rotation or texture step; not read.
- Multiplayer: how the repeated `CPauseGame` past the end date behaves; `CPauseGame::Execute` at `0x6D8040` was only skimmed.
- What exactly the back end's camera/viewport at `+0x258`/`+0x25C` is for (made by `0xA702E0`, no reader in Update found by this reading).
- Which of the back end's input slots is which button (the code reads slots 8 and 22 of `+0xC4`, *inferred* left and right).

Frontier: `0x23D4B0` (the dialog base's constructor), `0x68BBD0` (the generic list-entry row), `0x2D8040` (`CPauseGame::Execute`), `0x6A27E0` (icon slot 73), `0x28F180`.

## B. The victory-condition windows

*Fragment `endgame-vc.json`. Read from the decompile of a project copy and the listing; no window was seen on screen. `confirmed` throughout unless marked. The figures are tagged [exe] (hard-coded) or [mod] (a define or file). Positive control: `"%d / %d"` of met and 15 (`FINDINGS-factionplay.md` C.7) comes out of `VCWindow_SetFactionProgress`, and the start save's chosen lists are each faction's 15 primaries in the file's order.*

### B.1 One window, three doors

`CVictoryConditionsView` (`vc_window` of `interface/vc_interface.gui`; TFH has no copy, its `.gfx` is overridden) is made in `CInGameIdler::CInGameIdler` (`push 0x7C` at 0x6493E3, the call at 0x64942B) and kept at `+0x1D48`. **The goals window behind `menubar_goals_button` is this window.** It starts hidden. It is not behind a pause: neither `ToggleGoals`, the update, nor the close handler touches the game's pause, so the game goes on running.

It opens through `CInGameIdler::ToggleGoals` (rva `0x249F70`), from:

- `menubar_goals_button`. No shortcut in the `.gui`; nothing greys it (the name is referenced only at its bind and its tooltip).
- Alert 14 (B.4), which only ever opens it.
- There is no key.

`ToggleGoals`: if hidden, show, raise, set the view's faction to nought (so the update rebuilds), run the update at once and **hide the Strategic Effects window** (`+0x1D4C`). If shown, hide. The button's tooltip is `VC_BUTTON_TOOLTIP` "Victory Conditions" (the text half only).

Closing: `close_button` (buttonText `CLOSE` "Close", `shortcut = "ESCAPE"` in the file) hides the window and does nothing else (generic handler 0x7D8760).

### B.2 The update and the elements

`CVictoryConditionsView::Update` runs each frame while the window is shown and from `ToggleGoals` (the frame's call is in `UpdateTutorialAndAuxWindows`). It does nothing if the window is hidden or there is no player.

**When the player's faction differs from the one the list was built for** (and always after a `ToggleGoals` show), by the faction's tag [exe, exact string compare]:

- `axis`: `vc_bg_axis` shown, the other two hidden. `allies`: `vc_bg_allies`. `comintern`: `vc_bg_com`.
- Then the rows are rebuilt (B.3) and the list shown.
- **Any other tag** (the null faction): all three pictures hidden and `vc_list` hidden, and the arm runs every frame because the stored faction is not updated in it. Nothing else is said for this case: the text `vc_nofaction_label` (`VC_YOU_ARE_NOT_PART_OF_ANY_FACTION` "You are not part of any faction") is touched by no code (the string is not in the image) and is simply visible, standing behind the faction pictures (*inferred* from file order, with the pictures opaque at its place, alpha 255 measured on the `.dds`).

**Once a day** (when the day of the year, (tick - 43800000) / 24 less whole years, changes; first show, -1), for `axis`, `allies` and `comintern` regardless of which the player is in, `VCWindow_SetFactionProgress`:

- `vc_<f>_progress_text` = `"%d / %d"` of met and `NUMBER_OF_VICTORY_CONDITIONS` [mod define, 15], overwriting the file's placeholder "7/15".
- The bar `vc_<f>_progress` (a `progressbartype` sprite, on the icon's slot 18) = met x 100 / 15, integer.
- Then each row's background is refreshed (B.3).

A faction whose tag is missing is skipped, so it keeps whatever it last showed. The window counts toward 15 while the game ends at 12.

Static elements, from the file: `vc_bg`, `vc_label` (`VC_VICTORY_CONDITIONS` "Victory Conditions"), `vc_allies_text` (`VC_ALLIES` "Allies"), `vc_axis_text` (`VC_AXIS` "Axis"), `vc_com_text` (`VC_COMINTERN` "Comintern").

**No element of the window has a tooltip of its own**; only rows answer (B.3). `close_button` has the shortcut line only.

### B.3 The rows of `vc_list`

`RebuildList`: hide the list, store the faction, take the matching entry of **chosen** (`conditions +0x18`, not `all`), add rows until there are as many as conditions, remove any surplus from the end, bind each in order, lay out, show. A faction the conditions do not hold touches no row (this does not arise in the shipped game).

- **Which and whose:** the player's faction's chosen conditions (15), and no other faction's.
- **Order:** the `chosen` vector, which is the order of the last `CChooseVictoryConditionsCommand`'s list. For a start that is the file's order (`VictoryConditions_PostChosen` walks `all`). Checked against `Germany1936_01_01_00.hoi3`: the three lists there are exactly the file's primaries in file order. After a lobby choice it is the ticks' order, with random additions at the end (B.5).
- **Row elements** (`vc_entry`, 500 x 30): `vc_entry_bg`, `vc_name` (the localised name, `GetText` of the condition's key, e.g. `operation_sealion` "Operation Sealion", all 85 conditions have a key), `vc_info` (an icon nothing writes to).
- **What met looks like:** only the background frame. `vc_entry_bg` frame **1 when not met, 2 when met** (`GFX_vc_entry_bg`, `noOfFrames = 2`, 712 x 32 a frame: frame 1 grey, frame 2 amber, measured on the `.dds`). `met` is `+0x68`, rewritten daily, not sticky.
- **The date is not shown.** No routine of the window reads the condition's `+0x64`.
- **Rebinding:** rows are bound on every rebuild and repainted once a day.
- **Tooltip:** `CInGameIdler::GetElementTooltip`, while the window is shown, asks `CVictoryConditionsView_ElementTooltip`: the row owning the element (any element of the row: background, name, icon) answers with the condition's trigger, `CAndTrigger::GetBlockText(out, scope, redWhen = false, depth = 0)`, in the `text` half, in an empty scope (country `---`/0). By `FINDINGS-script.md`: no header at depth 0, each child's line with a red or green asterisk by whether it holds now.

### B.4 Alert 14

Shown or hidden by `CAlertManager_Update` (VA 0x606C3E to 0x606CD9, once every three seconds of its clock): over the faction list `+0xCE4`, skipping the player's faction, `met x 100 / VICTORY_CONDITIONS_TO_WIN >= 75` for any [75 exe; to_win a mod define, 12, so 9 met].

Tooltip (`CAlertManager_VictoryConditionsTooltip`, reached by alert index 14 in `CAlertManager_IconTooltip`):

- `text` = `VC_ALERT` "§GVictory Conditions§W".
- `delayed` = `VC_DANGER` "§Y$FACTION$§W have completed §R$NUM$§W victory conditions." with the faction's localised name and its met count, for each faction passing the same test. **Each overwrites the last, so the tooltip names only the last such faction in the list's order.**

`<name>_instant` and `<name>_delayed` are not used for this alert (neither key is in the tables).

A click (`CInGameIdler::OnAlertClicked`, slot 80): side menus and the orders view close first; then `ToggleGoals` **if the window is hidden**, and nothing if it is shown.

### B.5 The lobby's window

`CSelectVictoryConditionsView` (`victory_conditions_window`, `interface/victory_conditions.gui`), 0xA4 bytes, made by `CGameSetup::CGameSetup` (0x70543D) and kept at `+0x8B0`; starts hidden.

**Who may open it.** `victoryconditions_button` (`tfh/interface/lobby.gui`) is enabled, each frame by `CGameSetup::Update`, only when **no save is loaded and `VictoryConditions_PlayerMayChoose`** holds: the player has a country, its faction is valid (vf_7), and the country is the faction's first member (`Members.first`, its leader) **or a scenario is running** (`+0xD0C`) [exe]. While greyed its tooltip is `VC_BUTTON_DISABLED_SAVE` "Cannot reselect victory conditions when loading a saved game." if a save is loaded, else `VC_BUTTON_DISABLED_INVALID` "Only countries that are faction leaders can select victory conditions."; none when enabled. The button only opens the window if it is hidden. Play cannot be pressed while it is up (`CGameSetup_CanStart`, already recorded).

**Rows of `conditions_list`** (`condition_entry`), `RebuildList`: **every** condition of the player's faction in the file's order (`conditions +0x28`, 33/22/30 by faction in TFH, [mod file]), each with `background`, `active` (checkbox, ticked where the chosen byte `+0x69` is set), `name` (localised). The header `vclobby_label` is written: `VC_FACTION_HEADER` "$FACTION$ Victory Conditions" with the faction's localised name; the file's "Axis Victory Conditions" is overwritten.

**A click** toggles the checkbox, and nothing else: no observer is hooked, and **there is no limit**. Update each frame writes `info` = `"%d / %d"` of ticked and `NUMBER_OF_VICTORY_CONDITIONS` [mod define]; when they differ the count is red (`"§R%d§W / %d"`, format at 0x15D5E58). Update also hides the window if `PlayerMayChoose` no longer holds, and if the player's faction has changed it closes, reopens and rebuilds it (the ticks are lost).

**Tooltips** (`CSelectVictoryConditionsView::ElementTooltip`, reached at the end of the lobby's slot 6, because the window and `accept_button` carry the group `gamesetup`): `accept_button`: `VC_ACCEPT_DISABLED` "§R$NUM$§W conditions selected, will randomly add/remove to §Y$TOTAL$§W." **only while ticked differs from the number**; a row's element: the same `VictoryConditionItem_Tooltip`; all else none.

**Accept** (`VC_ACCEPT` "Accept") is **never greyed**, despite the key's name. `OnAccept`: where the player's faction is valid, the ticked rows' names and date strings, in list order, are fitted (`VictoryConditions_FitChoiceToCount`: if too many, random pairs removed; if too few, random conditions of the faction's `all` not already named are appended, on a Mersenne Twister seeded from `_time64`, so it is not replayable) and posted as one `CChooseVictoryConditionsCommand(faction, list)`; the window is hidden. **Cancel** (`VC_CANCEL` "Cancel") only hides it, and the next opening rebuilds the ticks from the chosen bytes.

### B.6 What looks wrong but is what the bytes do

1. The window counts toward 15, the game ends at 12, and the alert fires at 9 of 12.
2. `VC_ACCEPT_DISABLED` is a tooltip on a button never disabled.
3. "You are not part of any faction" is shown only by being uncovered; no code addresses it.
4. Alert 14's delayed line names only the last matching faction.
5. A faction's window and bars are shown only for the exact tags `axis`, `allies`, `comintern`, whatever a mod calls others.
6. Opening `vc_window` closes the Strategic Effects window and vice versa.

### B.7 Not established

- That later `.gui` elements draw over earlier ones, which is what hides the no-faction label when a picture is up (*inferred*).
- What `GetBlockText` actually prints for a province-numbered block with `controller = { faction = axis }`: the generic machinery only.
- That slot 18 reads as a percent on a `progressbartype` sprite (*inferred*: 0 to 100 passed, the sprite has no frames).
- Multiplayer: which player's `player` governs these windows on a client.
- Nothing was watched in a running game.

**Corrections.** `CInGameIdler::ToggleGoals` goes from inferred to confirmed; `CSelectVictoryConditionsView::OnAccept`'s "any member can send its faction's choice" holds only for the button, because in a campaign only the faction's first member can open the window (in a scenario, anyone). `FINDINGS-unitpaneltooltips.md` calls `CVictoryConditionsView_ElementTooltip` by its old name, `IdlerWindow1D48_ElementTooltip`.

Frontier: rva `0x3D8760` (generic hide), `0x2070D0` (alert 15's tooltip), `0x208730` and `0x208580` (alert hide and refresh), `0x682040` and `0x6820F0` (checkbox states), `0x4C710` (date string in `FitChoiceToCount`).
