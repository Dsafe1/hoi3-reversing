# The front end: the main menu and the single-player lobby

Read 2026-11-06, statically, in copies of the Ghidra project, by two readers - A the main menu and the front end's coming
and going, B the single-player lobby - for OpenHOI3's main menu. Fragments `frontend-mainmenu.json` and
`frontend-lobby.json`. Addresses are rvas unless marked VA (VA = rva + 0x400000); only valid for this build. **[exe]**
hardcoded in the executable, **[mod: file]** what a file may change. `confirmed` unless marked.

**Where the readers met**: both read `CGameSetup`'s slots 1, 2, 3 and 13 and named them differently. Slots 1 to 3 are
`CFrontEndView`'s Prepare, Show and Hide, which are pure in the base, and the lobby's bodies take those names; slot 13 is
`CGameSetup::BuildBookmarkLists`. B's account of Show stands: it calls `CGameSetup::OnNewGameTab` (`0x315100`), which
shows the bookmarks and fills nothing - A had it filling the save list.

**Corrections to the record**: `CFrontEnd::Enter` was a guess ("Enter is the guess") and is the screen-enter slot;
`GameSettings +0x174` `simple` is settled (A.1); Ghidra's RTTI pass mislabels `0x2F3050` as a `CFrontendSettingsScreen`
constructor (it is the front end's Reload) and `CGameSetup`'s slots 1-5 as Save/SaveContents/Load/LoadKey/AfterLoad
(trap 4: CGameSetup's CPersistent family sits at +0xC); `selected_fog` is the form of government, not fog of war.

**Not in the record, a hand edit for whoever wants it**: `CFrontEnd` is 0x8B0 bytes (`new(0x8B0)` at each construction);
the merge does not add a size to a struct already recorded.

## A. The main menu

### A.1 Coming up, and which panel shows first

**One front end per visit.** Every way into the front end - the startup load, the tutorial's exit-to-menu branch of
`ProcessSessionEndRequests`, and the end-of-game screen's Exit - builds a new 0x8B0-byte `CFrontEnd` and makes it the
pending screen. The run loop's swap (VA `0xA913A0`) calls the outgoing screen's slot 4 (Leave), deletes it, calls the new
screen's slots 2, 3 (`CFrontEnd::Enter`) and 5, and hands over.

**`CFrontEnd::Enter`** (`0x2EEF00`), in order: clears the players (`CGameState::ClearPlayers`); shows the LOAD_GFX line;
`InitialiseGraphicalMap`; `CEU3Idler::Enter`, which makes the tooltip box; **`CFrontEnd::Reload`**, which builds the
panels; hands the map the front end's camera; clears the map's province pictures, air icons and air-base circles and
refreshes the colour textures; sets **the map style to 2, the political style [exe]**, layer mask `0xFF9A`, with no map
mode set; `in_game` = 0 and `tutorial_id` = 0; **where `tutorial_active` is set, switches to the tutorial list (view 6)**
- how leaving a tutorial lands there; and makes the hidden right-click menu.

**`CFrontEnd::Reload`** (`0x2F3050`, slot 0 of the CReloadDispatcher table at +0xB0, so its `this` is 0xB0 into the
object): makes `country_selection_panel` [mod: interface/temp_frontend.gui] and shows it with its sub-windows hidden;
makes the `lobby` window [mod: interface/lobby.gui] and hides it; builds a vector of **nine** views, hiding all but view 0;
wires the four quickstart buttons; and **picks the first panel from `simple` [mod: settings.txt `simple=`]** - `no` the
main menu, `yes` the Quick Start panel.

| slot | view | built from |
| --- | --- | --- |
| 0 | main menu, `CFrontEndState` | `mainmenu_panel`, shown at once |
| 1 | never built | null |
| 2 | settings window, `CFrontendSettingsScreen` | `menu_settings` |
| 3 | lobby, `CGameSetup` | `lobby` |
| 4 | multiplayer menu, `CMultiplayerMenuView` | `multiplayer_menu`, `multiplayer_connect_menu` |
| 5 | `CMetaserverInterface` | |
| 6 | tutorial list, `CTutorialScreen` | `tutorial_panel` |
| 7 | credits, `CCreditsScreen` | |
| 8 | Quick Start, `CEasymodeView` | `easymode_panel` |

`simple`'s default in the settings constructor is 1, and the install's template `settings.txt` says `simple=yes`, so a
player with no settings file of their own sees Quick Start first (*inferred* from the default; a fresh install was not
watched). The maintainer's file says `simple=no`. An interface reload, and the settings window's Back and Apply
(`CFrontendSettingsScreen::Close`), clear `simple` and go back to the main menu.

**The view protocol** (`CFrontEndView`, slots 1-4 pure): a change of panel (`CFrontEnd_SwitchView`, `0x2F1280`) calls the
old view's slot 3 (Hide), stores the index at +0x760, and calls the new view's slot 1 (Prepare) and slot 2 (Show); it also
hides the store window, and keeps `simple` in step for views 0 and 8.

**`version_label`** [exe for the format]: the application's version name - `HoI3 v4.02`, built in the application's
constructor; that this is the string the formatter reads is *inferred* - then ` (`, four letters A-Z from the checksum
(its sum, >>4, >>8 and >>12, each mod 26) and `)` - exactly, since 2026-11-13: the sum is `CVersion`'s `data` plus
`executable`, the shifts arithmetic and each remainder C's made positive, and the name is confirmed the formatter's
(`FINDINGS-checksum.md`, section 4); and where a mod is loaded, `    Mod: ` and the mod's localised name. The
lobby's `checksum` label gets the same text.

### A.2 The main menu's buttons

No main-menu button has a tooltip: `CFrontEnd::GetTooltip` (slot 20) asks only slot 109, which answers only `gamesetup`
and `micro`, and asks the map only while the lobby is up; the `.gui` entries carry none.

| button | does |
| --- | --- |
| `single_player_button` | **Opens the lobby**: session mode 0 (single player) and `skip_automation_keys` clear (`SetFrontEndSessionMode`); `CGameSetup::BuildBookmarkLists` (B.1); the store window hidden; the camera's keep flag cleared, so the camera returns to (2900, 1600) when the lobby is left; the main menu hidden; then the lobby's Prepare and Show (B.1) - Show hides `country_selection_panel`, the backdrop with it, and shows `lobby` |
| `multi_player_button` | mode 1; the multiplayer menu (view 4) |
| `nudge_button` | sets `nudge_requested` (+0x766); **always hidden** - by `CFrontEndState::Show` and again every frame by `CFrontEnd::Update`. What reads the flag was not traced |
| `tutorial_button` | the tutorial list (view 6); the Quick Start panel's is the same handler |
| `settings_button` | the settings window (view 2), `FINDINGS-settingswindow.md` |
| `credits_button` | credits (view 7) |
| `gg_micro_button` | the GamersGate store window (`micro_interface`, microgui.gui), *inferred*; wired only where the window has the button |
| `exit_button` | greys exit, settings, single, multi, credits and tutorial at once, stops the music, sets `quit_requested` (+0x76D) and posts the quit message. **No question, no save** |
| homepage, forum, facebook, twitter | open a hardcoded address [exe]: heartsofirongame.com, the Paradox forum's Hearts of Iron 3 board, facebook `Heartsofiron`, twitter `HeartsOfIron3` |
| `toggle_quick_normal` | FE_TOGGLE, "Quick Start": `simple` = 1 and the Quick Start panel |

A thirteenth glue at `CFrontEndState +0xC` would set mode 0 and switch to view 1, which is never built; neither the
constructor nor the destructor attaches it, so it is dead (*inferred*: only those two bodies were searched).

### A.3 What is behind the menus

**The map is drawn every frame in the front end** (`CFrontEnd_Render`) and its camera updated, **but on the main menu
none of it shows**: `country_selection_panel` is full-screen, a tiled `Background` under a centred 1600x1200 fully opaque
`frontend_backdrop` (every sampled pixel alpha 255), and no code names either - they are simply part of the window. That
the map is covered is *inferred* from the art and the layout. **The lobby is where the map shows**: its Show hides the
whole window and its Hide shows it again. Which map mode's colours style 2 draws was not read.

**A province click on the main menu does nothing**: `CFrontEnd::Update` (`0x2EDD60`, slot 1) stores the province under a
released left button at the map's +0x60D0 and, where it has an owner, hands it to the current view's slot 5 - an empty
`ret 4` in every view but the lobby. The map has a tooltip only while the lobby is up.

Each frame besides: the title theme `music/titletheme_heartsofiron.mp3` while the window is active and the master volume
above nought [exe path]; F11 saves `Screenshots/HoI3_<n>.bmp`; Shift and the right button bring the reload menu
(`FINDINGS-leftovermenus.md`, A.3).

### A.4 The Quick Start panel

`easymode_panel`: four quickstart buttons, tutorial, exit, and FE_TOGGLE_NORMAL "Custom Start", which sets `simple` = 0
and goes to the main menu. **Each quickstart starts a game with no lobby**: the date set, the history run to it, a human
made, the generator seeded and the seed posted, the tag made the played country, the automation set, `launch_requested`
raised; the game starts at the next frame. Dates and tags [exe]: GER 1939.9.1, USA **1936.1.1**, JAP 1941.12.7, SOV
1941.6.22. The wiring and the strings are confirmed; the middle of the bodies *inferred*.

### A.5 Leaving for a game

`CFrontEnd::LaunchGame` (`0x2F07A0`) is called every frame by Update and returns at once unless `launch_requested`
(+0x765) is set; while it is, the render draws nothing. It installs the in-game screen, and the swap runs
`CFrontEnd::Leave` (`0x2F0140`, slot 4): the observers detached, `lobby` and `country_selection_panel` destroyed, the nine
views and the store deleted.

### A.6 Back from a game

**There is no direct quit to the menu.** Resign opens a `CQuitDialog` "RESIGN"; OK calls `RequestGameOver`, and
`ProcessSessionEndRequests` builds a `CBackEndIdler`, the end-of-game screen of `backend.gui`. Its Exit
(`CBackEndIdler::OnExitButton`, `0x20BAF0`) runs `ResetGameStateToStartDate(1)` and builds a new front end, entered the
next frame. The tutorial's end goes the same way. On the way down the in-game screen's Leave clears `in_game`, the game
state is put back to its start date with the players cleared, and Enter clears them again and builds every panel anew;
**neither path saves**. **The front end comes back at the main menu or the Quick Start panel, by `simple` - never at the
lobby** - but at the tutorial list while `tutorial_active` is set. Quit goes to the desktop.

### A.7 Not established

What reads `nudge_requested` (the map editor's `CNudgeIdler`, presumably); which map mode's colours the front-end map
uses; the second tooltip box at +0x204, pinned at (10, 10); the camera's +0x354 to +0x356 beyond "keep position"; the
quickstarts' five automation entries; views 4, 5 and 7's slots and `CTutorialScreen`'s constructor.

## B. The single-player lobby (`lobby`)

The session mode global is 0 for single player, 1 for a host and 2 for a client (*inferred* from its writer and
`FINDINGS-settingswindow.md`).

### B.1 Opening, and the four tabs

**On opening** [exe]: single player's button runs `CGameSetup::BuildBookmarkLists` (`0x308980`, slot 13) - the lists
emptied and a row a bookmark added, and in single player or as host `CGameSetup::SelectDefaultBookmark` (`0x307BF0`):
history run from the current tick to the defines' `start_date` [mod: defines.lua], every country refreshed, the map
redrawn, and **a selection of the first bookmark in `bookmarks.txt`'s order posted**. Then the lobby becomes view 3:
Prepare (`0x307610`) clears the chosen start, in single player unmarks the simulated provinces and empties the custom-game
settings, sets the `checksum` text, hides `lobby_chat_edit`, adds the local player and clears "a save is loaded"; Show
(`0x3085A0`) hides the front end's own window and shows the lobby, so the map is behind it, and calls `OnNewGameTab` - **so
the lobby always opens on Historical Start** - and enables the four tabs (disables them on a client).

**The tabs**: a clicked tab takes frame 2 and the others frame 1, and shows its window, hiding the other three -
`newgame_tab` `bookmarks`, `savedgame_tab` `save_games`, `scenario_tab` `scenarios`, `cgm_tab` `cgm_bookmarks` (the last
two only identified). The labels - FE_HISTORICAL_START, FE_SCENARIOS, FE_CUSTOM_GAMES, FE_SAVED_GAMES - are the `.gui`'s.
`OnNewGameTab` (`0x315100`) does nothing while a load is pending, and **posts a CResetGame where the state came from a
save** (its Execute not read); `OnSavedGamesTab` (`0x3154B0`) has no such test.

### B.2 Bookmarks

From `common/bookmarks.txt` [mod], **in file order** (`CBookmarkList_Load`, `0x2ECFB0`); `is_cgm = yes` ones go to the
custom games' list; a `country` that is none is logged `Bad tag X in bookmark Y` and dropped.

**A row** is `bookmark_entry` [mod: temp_frontend.gui] (`CBookmarkEntry`, `0x303180`): the button `bookmark`'s sprite is
the bookmark's `icon` (`GFX_bg_startdate_1936`); `title` the localised `name`; `date` the date in FormatHourDate's form,
` %d:00, %d %s, %d` with a leading space. Each frame the row whose name is the chosen start's, in the matching list, shows
frame 2. No tooltip.

**A click** posts a CSelectBookmark; executed, the front end's slot 84 resets the camera's bounds to the whole map and
calls `CGameSetup::SelectBookmark` (`0x30ED60`, slot 7): "a save is loaded" and the scenario cleared; the name stored;
**the date held between the defines' `start_date` and `end_date`** [mod: defines.lua] and a CSetHistoryDate posted with it,
which moves the world (its Execute not read); two chat lines, the name in colour and the description; **a `shield` for
each of the bookmark's `country` entries**, in file order, centred on `shield_position` (lower middle, y -260) and
`shield_offset` (66) apart [mod: lobby.gui], each with SHORTCUT_SHIELD "$TAG$ is an interesting choice during this period.
Click to select it." - a click chooses that country and, with no scenario, centres the map on its capital; and
`year_label` written again. **The bookmark's countries are shortcuts only**: any country may be chosen on the map (B.4).

### B.3 Saves

**The list** [exe]: `save games`, or `mod/<mod>/save games`, through the same sorted listing as the in-game save dialog
(`FINDINGS-ingamemenu.md`, C.2) - the whole search path, the extension matched with case, names with a byte at or above
0x80 left out, **newest first by modification time**, the autosaves among them; made afresh each time the tab is pressed.
**Nothing is ticked and nothing loads on opening.**

**A row** (`CSavegameItem`, window `savegameentry`): checkbox `save_game`; `shield` the save's `player`, read by position
from the header - the date first, `player` second, or third after `scenario`; none with no `player`; `title` the file name
cut at its first `.hoi3`; `date` the header's first value in FormatHourDate's form.

**Choosing a row** - its checkbox, or anywhere on it, which ticks the checkbox (`CGameSetup::OnSaveRowChecked`,
`0x3167A0`):

1. a CClearBookmark: no bookmark, the shields gone, `year_label`'s name `SAVED_GAMES` ("Saved Game");
2. the row ticked, every other unticked, its file name stored;
3. **the load begins at once** (`CGameSetup::BeginSaveTransfer`, `0x3169E0`): the file read and checksummed (`Sending
   <name> with chksum <n>` in the log), the chat saying TRANSERING_SAVE "Savegame transfer started...";
4. a later frame of `CGameSetup::Update` (`0x309C90`) marks "a save is loaded" and, once every player's transfer is done,
   calls LoadSaveFile (`FINDINGS-savegame.md`, A), copies difficulty, game mode and automation from the loaded state,
   says "Savegame transfer done." and "Save Game Loaded...", refreshes every country and redraws the map: **the save's
   world is on the map**;
5. **in single player**, Update then calls the loaded row's click (`CSavegameItem::OnClicked`, `0x304560`): with the
   save's `player` known, the map centred on its capital, that capital handed to the province-click path - which chooses
   its owner - and a CSetCountryControllerCommand posted for it where the human does not already have it. **So the save's
   `player` is the country chosen, out of the row's header read** - `CGameState::LoadKey` ignores `player`. With no
   `player` in the header, nothing is chosen.

Choosing another row loads again; LoadFromSave resets the session. That a single-player transfer completes at once is
*inferred* (the player list holding only the local player).

### B.4 Choosing a country

**On the map** [exe]: the front end hands the lobby's slot 5 (`CGameSetup::OnProvinceClicked`, `0x30C0B0`) a mouse event
the interface did not take, with the province under the pointer, only where its owner is not nought - sea and unowned
land do nothing. It posts a CSetCountryControllerCommand for **the owner, not the controller**, and plays `click`. Its only
other test is a scenario's list of countries. **Nothing tests a loaded save or the rebels**: a save may be played as any
country.

**Otherwise**: the bookmark's shields (B.2) and the save's `player` (B.3). **There is no list of countries**:
`country_selection_panel` is the front end's backdrop window, and `select_nation_label`'s FE_NATION_TO_PLAY is nowhere in
the image (the positive control: `year_label` found its one reference by the same search).

**`CSetCountryControllerCommand::Execute`** (`0x2D3390`, *inferred*): the human's previous country, where no other human
holds it, unplayed and given to the AI ("AI will control X"); the new one played, and for this machine's human
**`state->player` and the map's player** set to it ("Local player will control X"); `controllers_changed` (+0xC0) set,
which redraws the panel.

**Who may be played**: Play wants every human's country to own a province - not the rebels, and not a country that does
not exist on the date (NOT_EXIST).

### B.5 The `singleplayer` panel

Made again whenever a controller changes or `year_label` is written; with no country chosen it is hidden and its texts
emptied. Otherwise:

| element | shows |
| --- | --- |
| `player_shield` | the country's shield; a click centres the map on a capital out of the lobby's own player record (whether that follows the chosen country is not settled) |
| `selected_nation_label` | the country's name |
| `selected_fog` | **the government's display name**, the form of government |
| `icon_factions` | shown with the faction's frame where its faction is a real one (slot 7); hidden otherwise |
| `head_of_state_label` | FE_HEAD_OF_STATE, "Head of state", static |
| `head_of_state` | the name of the minister in the `head_of_state` post |
| `photo_head_of_state` | `gfx/pictures/portraits/<picture>.tga` [mod], over `GFX_empty_position` |
| `wars_label` | **ATWAR "At War." where any of its diplomacy statuses holds a war, else ATPEACE "At Peace."** - the `.gui`'s FE_AT_WAR "At war:" overwritten; a list of enemies is made and never shown |
| `year_label` | WORLD_YEAR, "§Y$NAME$§W, $DAY$ of $MONTH$, $YEAR$" - NAME the chosen bookmark's name or "Saved Game", the date the game state's (a save's after a load); written again whenever the tick changes (`CGameSetup_RefreshYearLabel`, `0x314BD0`) |
| `select_label` | FE_SELECT_NATION, "Click on the map to select a nation...", static and named by no code |

**No element of the panel has a tooltip**: the lobby's (`0x310A40`, slot 6) answers only for `play_button`, a start-date
shield, kick and ban, and `victoryconditions_button` while greyed; the rest goes to the victory conditions window.

**`victoryconditions_button`**: pressable only with no save loaded and where a check *inferred* to be "the country leads
its faction" holds; greyed it says VC_BUTTON_DISABLED_INVALID "Only countries that are faction leaders can select victory
conditions." or VC_BUTTON_DISABLED_SAVE "Cannot reselect victory conditions when loading a saved game."; it opens the
victory conditions window.

### B.6 Play and Back

**Play may be pressed**, asked each frame, where `CGameSetup_CanStart` (`0x30DF80`, *inferred*) holds and the session may
post commands - always in single player. It fails with a load pending, the victory conditions window open, no human, or a
human's country nought or owning no province; then by the tab: **Historical Start** - unless a save is loaded or a custom
bookmark or scenario is chosen, CANT_START_REASON_SELECT_BOOKMARK; **Saved Games** - only once a save is loaded,
CANT_START_REASON_SELECT_SAVE_GAME "Please select the Save Game first."; the other two tabs have their own. Play's tooltip
gives the first problem in this order: MP_FEW_PLAYERS (multiplayer under two humans), NOT_SELECT "All players must select
a country.", NOT_EXIST "$TAG$ does not exist at this time.", then the CANT_START reason.

**Pressing Play** (`CGameSetup::OnPlay`, `0x30E5B0`, *inferred*), single player: **for a new game only**, the seed taken
from a clock and the draw count set to nought - a loaded game posts what the globals already hold; the difficulty, game
mode and automation posted where they differ from the state's, and the chosen victory conditions; a CSetRandomSeed and a
**CLobbyStartGame**. That one's Execute sets the front end's +0x764 (`CFrontEnd::RequestLobbyStart`, slots 67/68); at the
lobby's next frame, where `CanStart` still holds, `CGameSetup_StartGame` (`0x30E9B0`) checks the victory conditions once,
makes a fresh session named `Launch` and sets the launch flag +0x765, which the front end turns into `LaunchGame` - the
same for both kinds of game (`FINDINGS-savegame.md`, A.1). **So at Play a new game and a save differ only in the seed**;
the save was loaded in the lobby, and the in-game screen's Enter makes the rest of the difference.

**Back** (`CGameSetup::OnBack`, `0x30D010`, *inferred*): the local player posted again, the commands pumped, the option
choices posted, **ResetGameStateToStartDate(true)**, and view 0, the main menu (view 5 online). **A loaded save or a
chosen start is thrown away.**

### B.7 What looks wrong and is the original's

1. Choosing a save loads it at once; every click on another row loads again.
2. A map click after a load changes the country, so a save may be played as anyone, its player handed to the AI.
3. A province click chooses its owner, not its controller.
4. `wars_label` says only "At War." or "At Peace.", over the `.gui`'s "At war:".
5. A save row's country is a read of the header by position, not the parsed save.
6. Going from a loaded save to the Historical Start tab posts a CResetGame; the Saved Games tab never asks for a pending load.
7. A bookmark's date is held to the defines' range.
8. The year label names a save "Saved Game".

### B.8 Not established

Which mouse button picks a province (the event's +0x10 == 3 test not decoded); CSetHistoryDate's and CResetGame's
Executes; ~~VA `0x717D60`, which posts the option choices~~ (read: C.3, `CGameSetup_PostOptionChoices`); whether `player_shield` centres on the chosen country (the lobby's
+0x430/+0x434 - a displacement search found no store to either); that a single-player transfer completes the same or the
next frame; what button frames 1 and 2 and state 3 look like; the custom-game and scenario tabs' bodies.

## C. The lobby's options (`option_window`)

Read 2026-11-06 by a third reader, fragment `frontend-options.json`. **Corrections to the record**:
`CGameSetup_SyncOptionsFromGameState`'s "fog row" is the Armies row; `CHuman +0x48` (`ai_entry5`) is the Armies level -
7 Player Control, 3 Corps, 2 Armies, 1 Army Groups, 0 Theatres, which is the 7 of a save's `ai` list (checked by the
collecting session: rva `0x318338` compares it with 7, `0x3183C8` writes 7); `CSetGamePlayOptions::Execute` is not the only
writer of difficulty and game mode, `CGamePlaySettings::LoadKey` writes both directly; `OnPlay` posts the options
unconditionally, and for a loaded save too, where B.6 had "where they differ"; the difficulty's texts are the `DIFF_*` keys;
and the panel has seven rows, not six.

### C.1 Made, placed, shown, greyed

**Made once by the lobby's constructor** [exe] from `interface/options.gui` [mod] - only the base game's `interface/` has
it - as **a window of its own, not a child of `lobby`**, where its file puts it: `UPPER_RIGHT`, x -260, y 200. An interface
reload makes it again (`CGameSetup::Reload`, rva `0x31A050`, read in part). **Shown** by
`CGameSetup_SyncOptionsFromGameState` (rva `0x317880`): as the lobby opens, whichever tab, after each save loaded in the
lobby, and after a reload. **Hidden** only by Back and Play; the lobby's Hide leaves it alone. Two more glues, a hide and a
hide-and-post (`0x317D40`, `0x318880`), are attached by nothing (*inferred* dead: a displacement scan found every attach of
the arrows' glues and none of these). **Greyed**: on a multiplayer client the four difficulty and game-mode arrows
(`CGameSetup_AttachOptionButtons`, `0x3188B0`); the areas' arrows never; **nothing greys it for a loaded save**. **No
tooltip**: its names are read only by the code that wires the arrows and writes the boxes (that the window is outside the
lobby's `gamesetup` tooltip group is *inferred* from A.2's tooltip routine).

### C.2 The controls

| control | label [mod: localisation] | values in order [exe] |
| --- | --- | --- |
| `difficulty` | FE_DIFFICULTY "Difficulty:" | 0 DIFF_VERY_EASY, 1 DIFF_EASY, 2 DIFF_NORMAL, 3 DIFF_HARD, 4 DIFF_VERY_HARD |
| `arcade` | FE_ARCADE "Game Mode" | 0 STANDARD_MODE "Normal", 1 ARCADE_MODE "Arcade" |
| `diplomacy` (row 0) | FE_SETTING_DIPLOMACY | 0 OPT_PLAYER_CONTROL "Player Control", 1 OPT_AICONTROL "Ai Control" |
| `production` (row 1) | FE_SETTING_PRODUCTION | the same two |
| `technology` (row 2) | FE_SETTING_TECHNOLOGY | 0 Player Control, 1 Ai Control, 2 TECH_AUTOMATED "Research AI", 3 LEADERSHIP_AUTOMATED "Slider AI" |
| `politics` (row 3) | FE_SETTING_POLITICS | Player Control, Ai Control |
| `intel` (row 4) | FE_SETTING_INTEL "Intelligence" | Player Control, Ai Control |
| none (row 5) | FE_SETTING_UNITINTERFACE "Armies" | Player Control, OPT_AI_CORP, OPT_AI_ARMY, OPT_AI_ARMY_GROUP, OPT_AI_THEATER |
| none (row 6) | no label | Player Control, Ai Control |

Rows 5 and 6 are built and posted, but nothing looks for a box or arrows for them, and no element name for them is in the
image: **a mod cannot show them** [exe]. Each row's `_box` "Ruler" is overwritten. **The arrows wrap** both ways [exe]
(`CGameSetup::OnDifficultyPrev`/`Next` `0x31A7D0`/`0x31A810`, `OnGameModePrev`/`Next` `0x31A860`/`0x31A8A0`, the areas'
shared `OnOptionNext`/`OnOptionPrev` `0x31A8F0`/`0x31A990`). **Every press applies at once** - written and posted (C.3), the
panel drawn again (`CGameSetup::RefreshOptionsWindow`, `0x319300`) and, for each choice now different from the game
state's, OPTION_CHANGED "$FROM$ has changed to: $TO$" in the lobby's chat (`CGameSetup_SayOptionChanged`, `0x319D60`,
*inferred*), the label's colon kept: "Difficulty: has changed to: Hard". **Defaults**: the state's difficulty (2, Normal,
from its constructor), game mode 0, and Player Control everywhere - a new player record (`CHuman::CHuman`, `0x27AFA0`) has
every flag nought (*inferred*: `0x444040` read as far as "resize to 7"), the technology setting nought and the Armies level 7.

### C.3 Where each choice is kept

**Difficulty and game mode** are the game state's `CGamePlaySettings` - difficulty at +8, game mode at +0xC - saved as
`gameplaysettings = { setgameplayoptions = { <difficulty> <mode> } }`, set through a **CSetGamePlayOptions** of the two,
which `CGameSetup_PostOptionChoices` (`0x317D60`) alone constructs: at every arrow press and at Play and Back, in single
player or as host, **whether anything changed or not**. Its Execute writes both and draws every machine's panel again. A save
or a mod's `gameplaysettings.txt` writes both directly (`CGamePlaySettings::LoadKey`, `0x28A550`; any other key reads
address 0, *inferred* crash).

**The areas, Armies and row 6** are the local player's `CHuman`, written by the lobby directly and not by a command - in a
save's top-level `ai = { a b c d e f g }`:

| entry | holds |
| --- | --- |
| 0 to 4 | the areas in CAI's AUTOMATIONTYPE order - Diplomacy, Production, Technology, Politics, Intelligence - each 0 Player Control, 1 Ai Control |
| 5 | the Armies level (`CHuman +0x48`): 7 Player Control, 3 Corps, 2 Armies, 1 Army Groups, 0 Theatres (that these are command levels is *inferred* from the labels) |
| 6 | automatic deployment, row 6 |

Rows 0, 1, 3, 4 and 6 are written to their flag only while under 2; **row 2 (Technology) is written to
`automate_tech_sliders` (0 to 3), not to flag 2**; row 5 to the Armies level as 7, 3, 2, 1, 0. `automate_sliders` and
`automate_trade` are not on the panel. **A loaded save comes back into the panel** - difficulty, mode, flags, technology
setting and Armies level - but the redraw at Sync's end reads every row from the flags again, so the Armies row ends as flag
5, and the next post writes the Armies level from it: a save whose Armies level is not 7 loses it at Play (*inferred*).
**A loaded save's difficulty and game mode may be changed in the lobby**, and Play applies the change.

### C.4 In game

The country screens' header - "POLITICS / Normal" with arrows - is `automation_setting` with `mode_arrow_left` and
`mode_arrow_right` [mod: `country_*.gui`], **the same player record**: diplomacy, production, politics and espionage flags
0, 1, 3 and 4, OPT_NORMAL "Normal" (the lobby's "Player Control") or OPT_AICONTROL, the arrows wrapping, each press
re-applying the player's delegation and opening the screen again; the technology screen the Technology setting, Normal, Ai
Control, Research AI, Slider AI, wrapping 0 to 3, **and flag 2 set to whether it is nought, which the lobby never does**
(`CTechnologyView::NextAutomationSetting`/`PreviousAutomationSetting`, `0x422290`/`0x422600`;
`UpdateAutomationLine`, `0x422970`); the theatre screen is made with index 4 and has no `automation_setting`. The production
screen's second selector (`slider_arrow_*`) is `automate_sliders`, with no counterpart in the lobby. Difficulty and game
mode have no selector in play.

**What each screen stops taking the mouse under the AI** (slot 14 of each view, called from slot 11, which then has
`mode_arrow_left`, `mode_arrow_right` and `close_button` take it again whatever the setting). **Nothing is greyed.** Slot
38 of the interface's elements, which all of this calls, is **whether the element takes the mouse** - read 2026-11-06,
after the maintainer reported that the original greys nothing under the AI, and recorded until then as *likely*
greying:

- on a window (`CFixedWindow::SetTakesMouse`, rva `0x6C4030`) it stores the byte and hands it to every child of both
  lists, as `FINDINGS-guistatic.md` had it;
- on a button (`GuiButton_SetTakesMouse`, rva `0x6CFFD0`, the four button widget tables) it stores byte `+0x84`, and the
  button's mouse handler (`GuiButton_HandleMouse`, rva `0x6CFBE0`) **returns at once where it is nought** - the press is
  not run and the event is not marked handled, so the click passes through;
- a checkbox the same with `+0x135` (rva `0x65EB30`, tested by its handler); a list hands it to every row's window (rva
  `0x68BF20`); a scrollbar to its four parts (rva `0x6A0870`); in seventeen other tables - text boxes, icons and the rest
  - it is the shared `ret 4` and does nothing.

**Nothing in it touches how an element is drawn.** A button's disabled state - the one it greys by - is its slot 47,
which sets its state (`+0x64`) to 3; slot 46 clears it and slot 48 asks it. So under the AI the original's screen looks
exactly as before and its controls simply do not answer: *confirmed* off the bytes, and *what the maintainer saw* is the
first half of it.

| screen | when | what stops taking the mouse |
| --- | --- | --- |
| politics | flag 3 is 1 | the whole window (the base's, inherited) |
| production | flag 1 is 1 | the whole window but `auto_deployment_checkbox` and `theatres_assign_button` (`CProductionView::ApplyAutomation`, rva `0x3FBC70`) |
| diplomacy | flag 0 is 1 | `decisions_listbox` and `diploaction_list` alone (`FINDINGS-diplomacyview.md`, D.7) |
| intelligence | flag 4 is 1 | `own_priority`, `country_info`, `own_country_info` and every row's `priority` (`FINDINGS-espionage.md`, D.1) |
| technology | the Technology setting | read 2026-11-06 (`CTechnologyView::ApplyAutomation`, rva `0x421DE0`), below |

The technology screen goes by the Technology setting itself, not by flag 2, and stops two windows apart - the screen and
`country_leadership_sliders`: Normal neither; **Ai Control** the screen and the sliders; **Research AI** the screen alone;
**Slider AI** the sliders alone. Where it stops the screen it has every folder's `techtree_` + key button, `tech_tree`,
`tech_categories` and `current_research` with each row's three backgrounds take the mouse again - so the tree and the
queue stay usable and the detail panel does not. The intelligence screen likewise has `unit_queue` and
`country_info_sections` - the Production and Ministers buttons - take it again inside the panel it stops.

### C.5 What looks wrong and is the original's

1. A press applies at once, not at Play, and posts even when nothing changed.
2. The Armies row and an unlabelled seventh exist with no box or arrows; the Armies level is written from flag 5 at every post.
3. The lobby's Technology row leaves flag 2 alone; the in-game arrows set it.
4. A loaded save's difficulty and game mode may be changed.
5. One value is "Player Control" in the lobby and "Normal" on the screens.
6. The chat line keeps the label's colon.
7. A choice's text is drawn with no test of its index.
8. A `gameplaysettings` block with another key reads address 0 (*inferred*).

### C.6 Not established

`0x30D3E0` beyond its head (whether OPTION_CHANGED stays local); that the seven flags start nought; what reads a choice's
serial number; the window's slot 11, called after Show; what the two unattached glues were for; the middle of
`CGameSetup::Reload`'s tail. **Hand decisions left for whoever wants them**: `CGameSetup +0x410` is a whole `CHuman`
(constructed there), which would fold `local_human_id` +0x42C into it; `CGameState +0x70` is an embedded `CHuman`, whose
+0x2C and +0x30 are `CCurrentGameState`'s `automate_sliders` +0x9C and `automate_tech_sliders` +0xA0; and
`CCurrentGameState +0xC90` is an embedded `CGamePlaySettings`, recorded as `void*`.

## D. What the options do in a running game

Read 2026-11-06 by a fourth reader, fragment `options-effects.json`. **How the readers were found**: for difficulty and game
mode a displacement sweep of `.text` for `[reg+0xC98]` and `[reg+0xC9C]`, each hit sorted - the positive control the same
sweep for `in_game` `+0xDA4`, which finds its known writers; nothing reads them through the embedded settings object. For
automation, every one of the 115 calls of `CGameState::GetLocalPlayer` followed forward to each field and flag it reaches,
inlined copies found only in SaveContents and the lobby; the positive control the known reads of [6] in `ProcessAI` and [1]
in `SendDistribution`. **Corrections**: `GetDifficultyCombatModifier`'s open mapping is settled (D.1; checked by the
collecting session on the jump table at VA `0x4DFADC`); the "twenty-odd" arcade sites are 16 in 12 functions;
`FINDINGS-ministers.md` B.8's auto-deploy checkbox and its [5]/`+0x48` items are settled (D.3).

### D.1 Difficulty

**Two readers in play, and nothing else.**

1. **A country's static modifier, made again each day** (`RebuildStaticModifiers`, step 20 of `FINDINGS-countrymodifier.md`
   section 2): a country of `played_countries_array` takes the level's `_player` block, every other its `_ai` block, Normal
   none. Which block goes with which level is [exe]; what is in them is [mod: common/static_modifiers.txt]. Their Finest
   Hour's:

| | 0 Very Easy | 1 Easy | 2 Normal | 3 Hard | 4 Very Hard |
| --- | --- | --- | --- | --- | --- |
| a human's country | `very_easy_player`: manpower +50%, revolt risk -3, IC +50%, resources +50%, supply consumption -25%, supply throughput +100%, naval base efficiency +100% | `easy_player`: manpower +25%, revolt risk -1, IC and resources +25%, throughput and naval base +25% | nothing | `hard_player`: IC and resources -10%, throughput and naval base -25% | `very_hard_player`: IC and resources -25%, throughput and naval base -50% |
| every other | `very_easy_ai`: IC and resources -25% | `easy_ai`: empty | nothing | `hard_ai`: IC and resources +25%, consumption -25%, throughput and naval base +25% | `very_hard_ai`: IC and resources +100%, consumption -50%, throughput and naval base +50% |

2. **A combat modifier** (`BM_DIFFICULTY`, `GetDifficultyCombatModifier`, rva `0xDF9B0`): on land, at sea, in the air and on
   both sides of a bombing, for every unit of a human's country, attacking and defending: +2, +1, 0, -1, -2 for levels 0
   to 4 [exe], times `COMBAT_DIFFICULTY_IMPACT` [mod: common/defines.lua, 0.2] - +0.4 to -0.4. Nobody else's units.

Nothing else reads it - not research, organisation, costs, events or the AI's choices - and no Lua accessor does. **"A
human's" is any played country**, not only the local player's.

### D.2 Game mode (0 Normal, 1 Arcade, asked as above nought)

Six of its 22 sites are outside a game; **the other 16, in 12 functions, are all supply** [exe] - Arcade replaces the
network with drawing from the capital:

- a unit draws supplies and fuel from its owner's capital pool, not its province (`CUnit::ConsumeSuppliesAndFuel`);
- supplies and fuel made all go to the pool, not over the core home area's factory provinces (`CDistributeSupply::Distribute`,
  `CCountry::ConvertCrudeOilToFuel`);
- no network: the daily supply pass returns at once (`RunDailySupplyPass`), and the day leaves out the depots' distances,
  the supply order, the farthest-first sort and the greatest distance (`RunDailyPass`, rva `0x282C20`);
- no supply convoys: none made, any four days old or more removed with its ships freed (`CCountry::MaintainSupplyConvoys`,
  `0xFDF40`), the convoy dialog's `create_supply` greyed (`CConvoySettings::Update`, `0x3E3310`, *inferred* name);
- a country's day's use of supplies and fuel is the sum of its units' needs (`CCountry::RebuildNeighbours`, `0xE21E0`);
- a new game's filling runs one pass with no province arrays and no daily pass (`RunSupplyAndConvoyIterations`, `0x278AB0`);
- the Supply map mode's button `mapmode_8` greyed every frame (`CInGameIdler::Update`, `0x2559D0`); the unit panel's supply
  lines read the owner's acting capital (`CUnitStatusEntry::Update`, `0x359330`);
- the land agent's weight for a front province's distance from its depot a flat 100 (`CAIUnit_ManageLandUnits`).

### D.3 The player's automation

**Only the local player's record is asked** (`GetLocalPlayer`), so in multiplayer another human's country goes by the local
player's flags. The flags are 0 or 1, the setter refusing anything else (`CHuman_SetAutomation`, `0x28A6B0`, whose one
caller is the `ai` key's load); `automate_tech_sliders` (+0x30) 0 none, 1 sliders and research, 2 research, 3 the
leadership sliders; `automate_sliders` (+0x2C) 0 to 3; `automate_trade` (+0x34) yes or no. **Changes in play are written
at once, not as commands**: the screens' arrows make or destroy the minister (`ApplyPlayerDelegation`); at the start the
ministers are made with the country's AI (`CreateMinisters`), none in a scenario.

| setting | what runs for the played country while it is set |
| --- | --- |
| [0] diplomacy | **the foreign minister**: each day the offers answered and `ForeignMinister_Tick` - decisions, pacts, influence, wars proposed and declared (`FINDINGS-foreignminister.md`); the Lua trading for it each hour, the player told nothing of the trades (`CTradeAction::Apply`); the diplomacy screen greyed. **Events are not answered for the player**: firing asks only `+0x28` and `nopopup` |
| [1] production | **the production minister**: each day the AI's `BalanceProductionSliders` branch and `ProductionMinister_Tick`, units, buildings and convoys ordered; the player's own slider level ignored and his slider moves not sent (`SendDistribution`); **the AI strategy's walk of missions and victory conditions runs for a played country only while [1] is 1**; alerts 5 (supplies and money) and 8 silenced; the production screen greyed but for auto-deploy and the theatres' assignment (`CProductionView::ApplyAutomation`, `0x3FBC70`) |
| technology (+0x30) | **the tech minister** where not nought: each day `TechMinister_Tick(sliders, research)` - 1 both, 2 research, 3 sliders. Flag [2] silences alerts 7 (free research slots) and 9 (technology far ahead); the technology screen's arrows keep [2] equal to whether +0x30 is not nought, the lobby writes +0x30 alone |
| [3] politics | **the politics minister**: laws, ministers, mobilisation - a law still costs money, the country being played; alert 6 silenced; the screen greyed |
| [4] intelligence | **the intelligence minister**: each day `IntelligenceMinister_Tick`; the screen greyed |
| [5] / +0x48 Armies | **nothing**: saved, loaded and shown in the lobby only |
| [6] auto-deploy | `DeployFinishedUnits` for the played country **every hour**, where an AI country's runs daily; toggled by `auto_deployment_checkbox` (`CProductionView::OnAutoDeploymentToggled`, `0x3FC710`, a direct write) |
| `automate_sliders` 1 to 3 | each day `BalanceProductionSliders` for the player at that level, only while [1] is not 1; the production screen's arrows apply it at once; alerts 5 and 8 silenced while it is above nought |
| `automate_trade` | each hour the player's pending trade proposals rolled against the AI's acceptance (a private `rand` seeded 1), and the Lua proposing trades for it; trade messages left out |

The Lua cannot see any of it: `IsAIControlledForPlayer` (`CAI_IsAIControlled`, `0x4E9190`) is registered and no script
calls it. `CHuman +0x4C` is each human's own date, read only by the multiplayer clock's sync (*inferred*).

### D.4 What looks wrong and is the original's

- The played country's strategy walk hangs on the **production** flag.
- Alerts 7 and 9 ask flag [2], not the +0x30 the minister is made from, and the lobby never sets [2].
- The Armies setting does nothing.
- Difficulty's two blocks part on any human, not the local player.
- Automation changes are local writes, not commands.

### D.5 Not settled

Slot 48's meaning on the Supply button; whether every gated alert's flag starts clear; `create_resource`'s condition (read
in outline only); what writes `CHuman +0x4C`; whether flag [2] starts at nought.
