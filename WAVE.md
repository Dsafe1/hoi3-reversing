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

## The convoy windows wave - making and managing convoys by hand, and the go-to box

> **LANDED 2026-11-08**, two fragments merged, launched on the maintainer's word ("Ok go ahead"), the next of the gaps in OpenHOI3's readme, *What of the interface is missing*. The write-up is
> `findings/FINDINGS-convoywindows.md`.

**The question, for OpenHOI3**: how a player makes, inspects, changes and cancels a convoy, and the box that jumps the map to a province. **What is known before reading.** `CProductionView::OnConvoyButton` (rva `0x4023F0`), `CConvoySettings::Update` (rva `0x3E3310`), `CCountry::CreateConvoy` (rva `0xFD2E0`), the commands' `LoadKey`s (`CCreateConvoyCommand`, `CCancelConvoyCommand`, `CChangeEscortsInConvoyCommand`, `CChangeResourcesInConvoyCommand`). Files: `interface/convoys.gui`, `tfh/interface/convoys.gui`, `interface/goto.gui`; `FINDINGS-convoys.md`, `FINDINGS-convoylines.md`.

| reader | brief | fragment |
| --- | --- | --- |
| **A** | **The convoy windows**: `convoy_creation_window`, `convoy_details`, `convoy_settings`, the production screen's `convoy_queue` rows and `convoy_button`, the map while a route is being picked, and the commands they post. | `convoywindows.json` |
| the collecting session | **The go-to box**: `goto_box`, `button_goto`. | `gotobox.json` |

---

## The top screens wave - the top bar's Theatres, Statistics and Strategic Warfare

> **LANDED 2026-11-08**, three fragments merged, launched on the maintainer's word ("Commit this, then continue"), the next of the gaps in OpenHOI3's readme, *What of the interface is missing*. The write-up is
> `findings/FINDINGS-topscreens.md`.

**The question, for OpenHOI3**: the three windows the top bar's dead buttons open - every element, what fills it, and what can be done there. **What is known before reading.** The buttons' observers are in
`FINDINGS-topbar.md` (`topbarbutton_theatre` +0x110, `topbarbutton_statistics` +0x270, `swm_open` +0x29C, disabled in a scenario); `CTopBar::OnTheatreButton` (rva `0x2CEF90`). RTTI: `CTheatreView`, `CStatisticsLedger`, `TStatisticsLedger`, `CGraphicalTableLedger`, `CPieChartLedgerGraphical`, `CTableLedgerItem`.
Recorded: `CGraphicalTableLedger::CGraphicalTableLedger` (`0x391970`), `LedgerPage_Update` (`0x3C1ED0`), `LedgerPage_Buildings` (`0x39F500`), `BuildLedgerColumnTooltip` (`0x3C3510`); `FINDINGS-ledgericons.md`. Files: `tfh/interface/country_theatres.gui`, `interface/hoi3ledger.gui`, `tfh/interface/hoi3ledgericons.gui`, `tfh/interface/stratwarfaremanager.gui`.
OpenHOI3 holds what these show: the theatres (`theatres.md`), the agents and their plans (`agents.md`), `CStrategicWarfare` (`politics.md`), and the save's `income_statistics`, `nation_size_statistics` and `inflation_statistics`.

| reader | brief | fragment |
| --- | --- | --- |
| **A** | **The theatres screen**: `country_theatres` and its rows `theatre_entry` and `area_entry`, `topcolor_theatres`, `selected_theatre` - who makes it, how it opens and shuts, each list, each element, every action and what it posts, `goto_button`, `build`, a `stance`, every tooltip. | `screens-theatres.json` |
| **B** | **Statistics**: `ledger` whole with `no_pie_data_window` and `topcolor_statistics` - how it opens, its pages and their buttons (`ledger_overview`, `ledger_economy`, `ledger_misc`, `ledger_military`, `previous_button`, `next_button`, `prev_graph_button`, `next_graph_button`, `checkbox_autosend`), every table, graph and pie chart: which figures, of whom, how they are kept (the save's three statistics), sorted, drawn and told. | `screens-ledger.json` |
| **C** | **The strategic warfare manager**: `swm_window` and `swm_list_entry` - how it opens, its tabs (`tab_naval`, `tab_air`, `tab_land`), `listbox_countries` and each row, `select_all`, `select_present`, `select_none`, `duration_1..3`, what is drawn on the map, what is being measured, every tooltip. | `screens-swm.json` |

---

## The end-of-game wave - how a game ends, and the windows that show the victory conditions

> **LANDED 2026-11-08**, launched on the maintainer's word ("continue with those missing UIs"), the first of the gaps in OpenHOI3's readme, *What of the
> interface is missing*: a game there has no ending. Two fragments merged (27 address entries new, 6 revised; 5 structs declared, 31 struct fields); the write-up is
> `findings/FINDINGS-endgame.md`, indexed in `CANDIDATES.md`. **Corrected**: the "goals window" is `vc_window`; the dialog's faction and its tie rule; the back end recalculates
> its tiers and reads no winner. Left open: the shield's icon slot, the back end's camera, and multiplayer's repeated pause past the end date.

**The question, for OpenHOI3**: everything between a game's last hour and the main menu, and the windows that say how near it is. Their rules are read
(`FINDINGS-factionplay.md`, C: the day's test, 12 to win, what counts as met, the alert), their screens are not.

**What is known before reading.** `CInGameIdler::ShowVictoryConfirmDialog` (rva `0x271A10`) makes the `VCConfirm` dialog (`0x270C20`, from VA `0x670C20`), which
`FINDINGS-factionplay.md` C.8 and C.11 leave open: how it picks Victory or Defeat and which faction it names, and what `CInGameIdler` slots 27 and 95 do.
`CConfirmVictoryConditionResign::OnAgree` (`0x271320`), `CInGameIdler::RequestGameOver` (`0x24C010`), `ProcessSessionEndRequests` (`0x2542B0`), which builds a
`CBackEndIdler` (RTTI: 110 slots, 16 introduced; `CBackEndIdler::OnExitButton` `0x20BAF0`). `interface/backend.gui`: `back_end` with `Exit`, per-faction `*_members`
and `*_goals`, `factions`; rows `backend_faction_member_entry` and `end_vc_entry`. `interface/vc_interface.gui`: `vc_window`, `vc_list`, rows `vc_entry` (update at
VA `0x6D2990`, the list not read; opened from where is not known). `interface/victory_conditions.gui`: the lobby's `victory_conditions_window`, `conditions_list`, rows
`condition_entry`, `accept_button`, `cancel_button` (`CSelectVictoryConditionsView::OnAccept` `0x31B9E0`, `CGameSetup::OnVictoryConditionsButton` `0x31AA30`,
`CVictoryConditionItem`, `CVictoryConditionsView`). `menubar_goals_button` calls `CInGameIdler::ToggleGoals` (`0x249F70`), of a window not identified. Alert 14,
`alert_victory_conditions`.

| reader | brief | fragment |
| --- | --- | --- |
| **A** | **The end**: `VCConfirm` whole - victory or defeat, the faction, its two buttons, what Continue leaves the game doing - slots 27 and 95, the end date's gates in `CInGameIdler::Update`, `CConfirmVictoryConditionResign`, and `CBackEndIdler` whole: what it does on entry, every element of `back_end` and its two rows, what each list shows and in what order, the tooltips, the music or pictures, Exit. | `endgame-backend.json` |
| **B** | **The windows**: `vc_window` whole - who opens it, every element, each row of `vc_list`, in what order, its tooltips, the day's update; the lobby's `victory_conditions_window` - who may open it, the rows, a click, Accept and Cancel; alert 14's tooltip; and the goals window behind `menubar_goals_button`: which window it is, or that it is nothing. | `endgame-vc.json` |

---

## The map cache wave - how the original builds `map/cache` out of the map files

> **LANDED 2026-11-08**, launched on the maintainer's word ("continue with the map cache") for OpenHOI3, which draws the
> map from the original's own cache and so gets the flat map for any map the original has not built a cache for. Five
> fragments merged (39 address entries new, 8 revised; 2 structs declared, 40 struct fields); the write-up is
> `findings/FINDINGS-mapcache.md`, indexed in `CANDIDATES.md`. **Every product agrees byte for byte on both maps**, each
> reader's script run again by the collecting session. One rva was given as its VA and is corrected in the record.
> **Left open**: which `rand()` callers make the noise's starting count, which varies by run, so a rebuilt beach matches
> the original's only given its count; what template +0x21 means; no reader of map.bin's bit 0x10 was found.

**The question, for OpenHOI3**: everything needed to make the cache's drawing half again from `map/` alone, **exactly** -
`all_quads.bin` and `quad_index.bin`, the 1,774 `quad_textures/quad_texture_<n>.dds`, `border_adj.bin`,
`border_bitmap.bin` and `map.bin`. The movement half (`adjacencies.bin`, `navaldist.bin`, `climate.bin`) OpenHOI3 already
computes and checks edge for edge; `provincecache.bin` is the province raster (`FINDINGS-mapbuild.md`) and is not wanted.

**What is known before reading.** `FINDINGS-mapdraw.md` has the formats as the *loaders* read them: A.1 the record's seven
pieces (`QuadCache_LoadTile`, rva `0x474970`) and the vertex declarations, A.3 the terrain-index texture's size and its
contents *measured* on two tiles, B.7 `border_adj.bin`, `border_bitmap.bin` (its byte 0 and 3 codes measured, the
`CBorderManager_FillBitmap` ladder at rva `0x434910` not checked branch by branch) and `map.bin`'s head and list (the
raster half unread, values 0..48), C.6 map.bin's river sources, C.7 the surf records and `MapShore_GenerateWavePixels`
(rva `0x46F140`) whole. **Unread**: `CProvinceManager_BuildQuads` (rva `0x45A580`, 0xE8A bytes: 'REcreating quads', five
VirtualAllocs, writes the two files and the textures) and under it the per-tile builder `0x4727B0` ('Province quad is too
large'), `0x474F00` (0x5CA, no strings - the record writer, *inferred*), `QuadBuild_EdgeVertices` (`0x4754D0`, 0x20FD,
named and summarised only), `TempBorderVertices_Weld` (`0x472560`), the beach builder `0x470700` (0x1AAB, with
`0x4705F0`, `0x4704E0`, `0x470330`), the per-pixel builders `0x46EB60` and `0x46EB20` past their surf call,
`CreateTerrainOffsetTexture` (`0x469080`, with `0x468F50`) and `MapBinCache_Build` (`0x873C0`). Two things measured and
not explained: the land mesh's edges bend off the pixel grid (triangle area 4,041,885 against 4,041,291 pixels), and
one border quad sits ~45 px off its pixel.

| reader | brief | fragment |
| --- | --- | --- |
| **A** | **The land mesh and the files**: `CProvinceManager_BuildQuads` whole - tile order, the scratch buffers, what is written where and in what order (quad_index.bin's head, all_quads.bin's records, the dword before V in piece 1, `quad_format.bin`); `0x474F00`; and `0x4727B0`'s land half - which provinces a tile takes and in what order, **how a province's pixels become vertices and triangles** (the bend), the vertex order, the index groups. | `mapcache-land.json` |
| **B** | **The borders**: `QuadBuild_EdgeVertices` and `TempBorderVertices_Weld` whole - pieces 3 and 4 of a record (each border vertex's position, slot and colour) and `border_adj.bin` (which pixels, in what order); the quad off its pixel. | `mapcache-borders.json` |
| **C** | **The beaches and the surf's order**: `0x470700` and its helpers, `0x46EB60`/`0x46EB20` whole - pieces 5, 6 and 7 of a record: the beach strip's vertices, smoothing and indices, and the order the per-tile walk visits pixels in. | `mapcache-beaches.json` |
| **D** | **The two rasters**: `CBorderManager_FillBitmap` branch by branch (`border_bitmap.bin`, all four bytes) and `MapBinCache_Build`'s raster half (`map.bin` whole: its head's figures, values 16 and 32 and whether anything reads them). | `mapcache-rasters.json` |
| **E** | **The terrain-index textures**: `CreateTerrainOffsetTexture` and `0x468F50` - the mapping from terrain.bmp's index to the texel's, the four channels, what lies outside the land, and the `.dds` as written (header, format, size). | `mapcache-terrainindex.json` |

**The oracle**: TFH's shipped cache, `tfh/map/cache`, stamp `93E125C4`; and a second map, BlackICE's, whose cache the
original built in the player's folder (`Documents\Paradox Interactive\Hearts of Iron III\BlackICE GitHub\map\cache`,
from the mod repository's `map/`). Each reader reproduces its products from the map files in a Python script and reports
**how many bytes of each file agree**, for both maps; a rule is not finished until the files agree whole or every
difference is explained.

---

## The saved-battle wave - what a battle in a save holds, and what a load rebuilds of it

> **LANDED 2026-11-05**, launched on the maintainer's word ("Go ahead") for OpenHOI3's savegame loader, whose third
> increment had read everything of a save but the battles. Two fragments merged (20 address entries new, 14 revised; 22
> struct fields); the write-up is `findings/FINDINGS-savedbattle.md`, indexed in `CANDIDATES.md`. **Corrected**:
> `CLandCombatant::LoadKey` reads `retreat` too, naval `positioning` is fixed point, the battle's AfterLoad sets up the
> attacker's front twice and the defender's never, and the "second `type=`" in a history entry was a census artefact.
> Left open: readers of a side's own-countries list and casualty vectors, what sets a side's "lost" byte, and whether a
> new game (not a load) empties the finished battles.

**The question, for OpenHOI3**: the savegame wave named every key the battle readers' switches take
(`CCombat::LoadKey` rva `0x16E0B0`, `CCombatant::LoadKey` `0x164DD0`, the land, naval, air and bomber combatants'
`0x169040`, `0x168D80`, `0x16DED0`, `0x15FDF0`, `CCombatHistoryEntry::LoadKey` `0x2F5F0`) and recorded the writers
(`CCombatManager::SaveContents` `0x2FC00`, `CCombat::SaveContents` `0x16E210`, the history's `0x2FAB0`, `0x2F410`), but
not **which field each key fills, what index orders each array, when each key is written, and what a load rebuilds**
of everything a battle holds that the save does not. `CCombat` and `CCombatant` are already well fielded in the record.
The oracle is the maintainer's saves: `Ireland1938_08_03_14.hoi3` has 4 land battles and 3 land bombings,
`Germany1936_09_02_21.hoi3` a ground bombing, `Ireland1936_02_02_04.hoi3` an air battle, a land bombing and a land
battle, `Ireland1937_07_05_02.hoi3` and `_11_02_21` a naval battle; no save has a naval bombing. The finished battles'
`type` runs 1 to 6 across them.

| reader | brief | fragment |
| --- | --- | --- |
| **A** | **A live battle and its sides**: CCombat's and CCombatant's keys to fields (`day`, `duration`, `dice`, `unit`, `losses`, `size` and its index, `tactic` and what it indexes, `sunk_ship`), the land side's `front` and `reserves`, the naval and air sides' `positioning`; each combatant's SaveContents in order with its conditions; how `CCombatManager::LoadKey` makes each kind; and **every AfterLoad and Enter-time step that rebuilds what is not saved** - a unit's own list of battles, the retreat list, `front_set_up`, the tactic figures, `begun`/`concluded`/`ended`, `is_convoy_battle`, the casualty vectors, the target lists, `positioning_roll`, the combat modifiers. | `saved-battle.json` |
| **B** | **Bombings, finished battles and sunk ships**: CBomberCombatant's `strength`, `building`, `pool` and `current_producing` - field, length and index order of each; which bombing kind is which and how a bombing's sides differ from a battle's; `CCombatHistoryEntry`'s `type` numbering (1 to 6) and `convoy`, how its list is kept and pruned; and the top-level `sunk_ships` block, writer and reader, what each entry holds and what refers to it. | `saved-bombing.json` |

---

## The savegame wave - how a game is loaded and saved

> **LANDED 2026-11-04**, launched on the maintainer's word ("Ok go ahead") after he chose for OpenHOI3 the original's
> `.hoi3` format both ways. Three fragments merged (85 address entries new, 12 revised; 13 struct fields); the write-up is
> `findings/FINDINGS-savegame.md`, indexed in `CANDIDATES.md`. **Corrected the list below**: the province and country
> blocks stand between `fired_events` and `sunk_ships`. Left open there: whether a loaded game starts paused, Lua on the
> load path, the class at `CGameState +0xD68`, the meaning of `setgameplayoptions`' numbers, and three embedded objects
> the record types as pointers.

**The question, for OpenHOI3**: everything a loader and a writer need beyond what the record holds piecemeal - the
order of the top-level blocks and of every block's keys, the keys written only sometimes, the id scheme, what a load
takes from the save and what from the install, and what the original recalculates after a load and before the first
hour. The oracle is the maintainer's 45 saves in `Documents\Paradox Interactive\Hearts of Iron III\save games` (read
only; never copy one), of which `Germany1936_01_01_00.hoi3` is the start date and the January 1936 ones have units on the
move.

**What is known before reading.** `LoadSaveFile` (rva `0x27CAE0`) builds a CParseContext over a file and calls
`CGameState::LoadFromSave` (rva `0x27CE30`); its only callers are gamesetup.cpp (`0x30A5C6`, the lobby) and the tutorial
screen. `CPersistent::Load` (rva `0x67C050`, slot 3 of 747 classes), `CPersistent::Save` (rva `0x5BB10`, slot 1), slot 2
SaveContents and slot 5 AfterLoad (`CCountry`, `CUnit`, `CSubUnit`, `CLeader`, `CMilitaryConstruction`,
`CStrategicWarfare`, `CTechnologyDataBase::AfterLoadAll`). Recorded SaveContents: CCountry, CProvince, CConvoy, CWeather,
CWeatherManager, CWeatherFront, CDiplomacy, CDiplomacyStatus, CRelation and kin, CTradeRoute, CCasusBelli, CAIStrategy,
CNavy, CArmy, CConstruction and its lines, CAlignment, CIdeologyData, CLeaderHistory, CTraitGainTracker, and the commands.
`FINDINGS-save.md` has the value writers (`%d.%03d`, bools, quoted strings); `ghidra/saveTokens.json` the key tokens.
`FINDINGS-session.md` and `FINDINGS-startup.md` have what a game's entry runs. A start save's top level, in order:
`date player ai automate_trade automate_sliders automate_tech_sliders rebel convoy theatre unit flags gameplaysettings
victory_conditions seed count id fired_events sunk_ships weather faction diplomacy combat active_war previous_war
income_statistics nation_size_statistics inflation_statistics strategic_warfare`, then 101 country blocks and 14,168
province blocks (their order to be read).

| reader | brief | fragment |
| --- | --- | --- |
| **A** | **The load path**: `LoadSaveFile` and `CGameState::LoadFromSave` whole - what is reset, what the install is read for and what the save, how each top-level key is dispatched, the order the AfterLoads run in, and **everything recalculated after a load before the first hour** (modifiers, supply networks, intelligence, the AI's state, the two first days or not), and how that differs from a new game. What the lobby does around it. | `save-load.json` |
| **B** | **The writer's top level and the id scheme**: the function that writes the whole save - every top-level key in order with its writer, the order of the country and province blocks, the counters (`rebel convoy theatre unit count id`), `seed`, `fired_events`, `sunk_ships`, `combat`, the wars and statistics - and the `{ id type }` pairs: what `type` numbers name, how ids are minted and kept. **A census**: for every block a save holds outside the unit tree, which class writes it and whether its SaveContents/LoadKey is recorded. | `save-toplevel.json` |
| **C** | **The unit tree and the country's military blocks**: the SaveContents and LoadKey of CUnit and every unit level (theatre, army group, army, corps, division, navy, air), CSubUnit (regiment, ship, wing), the orders and air missions, leaders (`active_leaders`), `military_construction` and the other queue lines, `saved_templates` - every key in order, the ones written only sometimes, and what AfterLoad fills in. **A census** of the same kind for these. | `save-units.json` |

---

## The game options wave - the in-game settings window

> **LANDED 2026-11-04**, launched on the maintainer's word ("Ok continue with the options") after the in-game menu was
> built in OpenHOI3 with Game Options greyed. Three fragments merged (61 address entries new, 5 revised; 5 structs
> declared, 88 struct fields); the write-up is `findings/FINDINGS-settingswindow.md`, indexed in `CANDIDATES.md`. That Apply with
> nothing needing a restart closes the whole menu the maintainer confirmed in the original the same day. Left open there:
> what `simple` and `categories` mean, which `settings.txt` a mod reads, and the suspect "text colours" of `GameSettings_GetTextColours`.

**The question, for OpenHOI3**: `interface/settings.gui`'s (and `tfh/interface/settings.gui`'s, which differs) window
`menu_settings_ingame`, which the in-game menu's `menu_options_button` opens (`FINDINGS-ingamemenu.md`, A.4: the
`CIngameSettingsScreen` at `CInGameIdler +0x1D2C`, 0x3E0 bytes, constructor VA `0x6FB710`, made by Enter at VA `0x66061D`;
slot 1 shows it, slot 2 hides it, slot 3 answers whether it is shown, slot 5 (VA `0x6FB8D0`) closes it back through
`CInGameIdler::CloseMenu`). It holds `settings_label`, `settings_bg`, four tabs `settings_tab_1`..`_4` with
`gamesettings_label`, `videosettings_label`, `audiosettings_label`, `controlssettings_label`, and four windows:
- `menu_settings_GAME`: `autosave_label`, `autosave_value`, `decrease_autosave_button`, `increase_autosave_button`,
  `ApplyButton`; and `BackButton` beside the windows;
- `menu_settings_VIDEO`: resolution, refresh rate and multisampling (`*_label`, `*_value`, `decrease_*_button`,
  `increase_*_button`), the sliders `gamma_slider`, `counter_slider` (`slider_label`), `counter_scale_slider`, and the
  checkboxes `counters_checkbox`, `hierarchy_checkbox`, `unit_name_checkbox`, `trees_checkbox`, `water_checkbox`;
- `menu_settings_AUDIO`: `mastervolume_slider`, `effectvolume_slider`, `musicvolume_slider`;
- `menu_settings_CONTROLS`: `scrollspeed_slider`, `zoomspeed_slider`, `legacy_camera_checkbox`;
- and the file's `SettingsMustRestartWindow` (`MustRestartTextBox`, `MustRestart_OK_Button`).
The front end's `menu_settings` is the same layout for `CFrontendSettingsScreen`. OpenHOI3 reads the player's
`settings.txt` and has never written it (its `docs/compatibility.md`, entry 13).

**What is known before reading.** RTTI: `CSettingsScreen` (6 slots, 5 introduced), its two children
`CIngameSettingsScreen` (6 slots, 1 introduced: slot 5) and `CFrontendSettingsScreen` (also `CFrontEndView@0x3dc`, 20
slots). `CIngameSettingsScreen`'s slots: 0 `0x6FB790`, 1 `0x6FB880`, 2 `0x6FB5E0`, 3 `0x6F6860`, 4 `0x6F6870`, 5
`0x6FB8D0`. Nothing from VA `0x6F2860` (`CFrontEnd_FillRightClickMenu`) to `0x6FC000` is recorded. Element names are
referenced at: `menu_settings_ingame` VA `0x6FB72E` (the constructor); `menu_settings` `0x6F3BC1`; `menu_settings_GAME`
`0x6F6590` and five more; `settings_tab_1` `0x6F626D`; `ApplyButton` `0x6F6215` and three more; `BackButton` `0x6F61B8`
and ten more; `autosave_value` `0x6F6928` and two more (beside a read of the settings' `+0x15C`, the autosave frequency);
`resolution_value` `0x6F865C`; `legacy_camera_checkbox` `0x6F8442`. Recorded: `GetGameSettings` (rva `0x5FF30`, the
0x18C-byte singleton `settings.txt` is read into), `CSettings::LoadKey` (rva `0x601D0`), `CMapRenderingOptions::LoadKey`
(rva `0x5F630`), `AutosaveFrequency_FromString` / `_ToString` (rva `0x5FFB0` / `0x600C0`); `FINDINGS-autosave.md` has the
frequencies, `FINDINGS-counters.md` and `FINDINGS-camera.md` the counter settings.

| reader | brief | fragment |
| --- | --- | --- |
| **A** | **The window**: `CSettingsScreen` and `CIngameSettingsScreen` - construction, the six slots, show and hide, the four tabs (which window each shows, which is up first), **Apply** (what it does with every tab's choices, when the must-restart window comes up and what it says), **Back** and closing (are unapplied choices kept or dropped? Escape?), whether the game pauses, tooltips, greying; **the Game tab** whole (`autosave_value`: the values in order, wrapping, its text). How `CFrontendSettingsScreen` differs, in a paragraph. | `settings-window.json` |
| **B** | **The Video tab** whole: resolution, refresh rate and multisampling - where each list comes from, its order, the text of a value, the buttons' ends and greying; `gamma_slider`, `counter_slider` and `counter_scale_slider` - range, step, text, the setting each holds; the five checkboxes - the setting each holds; **for each control: applied at once or only on Apply, and whether it needs a restart.** | `settings-video.json` |
| **C** | **The Audio and Controls tabs** whole (the three volumes, scroll speed, zoom speed, `legacy_camera_checkbox`: range, step, the setting each holds, at once or on Apply) - and **the writer of `settings.txt`**: where and when it is written, the folder, every key in its order and format, which field of the settings object each is. | `settings-audio-controls.json` |

**The oracle**: the maintainer's `settings.txt` (`Documents\Paradox Interactive\Hearts of Iron III\settings.txt`), which
the original wrote - every key the writer is read to write should be in it, in that order.

---

## The in-game menu wave - the menu, its save dialog and its message settings

> **LANDED 2026-11-04.** Launched on the maintainer's screenshot of the original's menu, which the reading agrees with.
> Three fragments merged (40 address entries new, 9 revised; 4 structs declared, 28 struct fields); the write-up is
> `findings/FINDINGS-ingamemenu.md`, indexed in `CANDIDATES.md`, with corrections carried into
> `FINDINGS-autosave.md` and `FINDINGS-messageshow.md`. Left open there: what `CBackEndIdler` shows and which of two
> handlers takes Escape. That closing the menu after a subwindow leaves the game paused the maintainer confirmed in the
> original the same day.

**The question, for OpenHOI3**: `interface/menubar.gui`'s (and `tfh/interface/menubar.gui`'s, the same in this part)
window `menu` - an icon `menu` and `menu_panel` with six buttons, `menu_save_button` (`MENU_BAR_SAVE_GAME`),
`menu_options_button` (`MENU_BAR_GAME_OPTIONS`), `menu_resign_button` (`MENU_BAR_GAME_RESIGN`), `menu_message_button`
(`MENU_BAR_MESSAGE_SETTINGS`), `menu_quit_button` (`MENU_BAR_QUIT`) and `menu_close_button` (`MENU_BAR_CLOSE`, shortcut
`ESCAPE`) - and the two windows of the same file it opens: `menu_save` (list `games` of `save_game_entry` rows, the
checkbox `game`; `filename_label`, edit box `game_name`, `save`, `cancel` on `ESCAPE`) and `menu_message_settings`
(`messagesettings_label`, seven category tabs `messagecat_*` with their texts, list `settings` of `message_entry` rows -
`message`, `text`, the checkboxes `messageicon_pause`, `_log`, `_dialog`, `_map` - and `reset`, `close`). OpenHOI3 builds
none of it; it has no saving, loading or main menu, and its messages are built (`docs/mechanics/messages.md`).

**What is known before reading.** The menu's names are referenced in `CInGameIdler::Enter` (rva `0x25A2B0`, *inferred*):
`menu` at VA `0x65E677`/`0x65E714`, `menu_panel` at `0x65E79F` ... `0x65EBD2` beside each button's name (`menu_close_button`
`0x65E778`, `menu_resign_button` `0x65E84F`, `menu_quit_button` `0x65E926`, `menu_save_button` `0x65E9FD`,
`menu_message_button` `0x65EAD4`, `menu_options_button` `0x65EBAB`); `menu_panel` and `menu_save_button` again in
`CInGameIdler::Update` (rva `0x2559D0`, VA `0x655D3C`/`0x655D64`) and `menu_panel` at VA `0x66BD91` (a function from VA
`0x66BD10`); `menu_save` and `menu_message_settings` at `0x66BE80` (called after a country view shuts,
`FINDINGS-outliner.md`). Classes (RTTI): `CQuitDialog`, `CConfirmVictoryConditionResign`, `CSavegameItem`,
`CMessageSettingsItem`, `CMessageSettingWindow`, `CSettingsScreen`. Recorded: `CInGameIdler_FillMessageSettings`
(`0x26F710`), `CInGameIdler::OnMessageSettingsRowClick` (`0x26FE50`), `CMessageSettingsItem::OnCheckbox` (`0x26DDF0`),
`CInGameIdler::CloseMessageSettings` (`0x2701B0`, *inferred*), `CMessageSettingWindow` (`0x299CD0`, `OnOk`, `OnCancel`,
`Update`), `SaveGameFromDialog` (`0x271370`); `FINDINGS-messageshow.md` has the settings panel's list.

| reader | brief | fragment |
| --- | --- | --- |
| **A** | **The menu**: what makes it and **what opens it** (a key, a button of the menu bar, Escape?) and whether the game pauses; each of the six buttons - what a press does, when it is greyed or hidden (`CInGameIdler::Update`'s `menu_save_button`: multiplayer, ironman?), its tooltip; **Resign** (`CConfirmVictoryConditionResign`: its text, its two answers, what resigning does to the game) and **Quit** (`CQuitDialog`: its text, where it goes - the desktop, the front end); Close and Escape; what `0x66BD10` does with `menu_panel`. **Game Options**: say only what it opens and how - the settings window itself is the next wave's. | `ingame-menu.json` |
| **B** | **The message settings window** (`menu_message_settings`) whole: how it opens and closes (revise `CloseMessageSettings`), the seven category tabs and what each filters, the `settings` list's rows - which types, in what order, each checkbox's meaning and what a click changes, `message` and `CMessageSettingWindow` (a type's own dialog?) - `reset`, and **where the choices are kept** (a file such as `messagetypes_custom.txt`? read or written when?). Extend, do not repeat, what the record and `FINDINGS-messageshow.md` hold. | `message-settings.json` |
| **C** | **The save dialog** (`menu_save`): how it opens, what `games` lists (which folder, which files, in what order) and a `save_game_entry` row (`CSavegameItem`), what `filename_label` and `game_name` show and the name offered, what `save` does up to the writer (`SaveGameFromDialog`: the file name, the folder, an existing file, multiplayer) and `cancel`; whether the game pauses. **Not the save writer itself**, and not loading. | `save-dialog.json` |

**The oracle**: the maintainer's screenshot of the original's menu over the map - the picture `GFX_menu` at its head and
the six buttons in the file's order, Close apart below.

---

## The leftovers wave - the right-click menu and the five side menus

> **LANDED 2026-11-04.** Three fragments merged (75 address entries new, 3 revised; 18 structs declared, 55 struct
> fields); the write-up is `findings/FINDINGS-leftovermenus.md`, indexed in `CANDIDATES.md`. Both files are leftovers:
> the right-click menu never shows in game and is a developer's reload in the front end (Shift and the right button,
> inferred to show - a ten-second test in the original); the side menus' top-bar handlers are never attached, so none of
> the five opens. Left open there: whether the front end's menu really draws, `0x41E510`, what fills `CCountry +0xD70`
> / `+0xD80`.

**The question, for OpenHOI3**: two interface files nothing in the base game's screens seems to reach. The maintainer's
word, 2026-11-04: they "may be leftover from other games that used the same engine. Lets build them, but we may
deactivate them again." **After this wave lands nothing is built until he says so** (his word, the same day).

- **`interface/rightclickmenu.gui`**: `rightClickMenu` with `options`, rows `right_click_entry` (a `button`) and
  `empty_right_click_entry`. Classes `CRightClickItemInterface` and its three items `CRightClickBuildUnitsItem`,
  `CRightClickCloseItem`, `CRightClickReloadItem` (RTTI, each also a `CStandardlistboxItem` at +4). The window's name is
  referenced at VA `0x6494D4` (inside `CInGameIdler::CInGameIdler`, `0x2474A0`) and `0x6EFFDF` (inside
  `CFrontEnd::Enter`); `right_click_entry` at VA `0x697EC6`, `0x6982B8`, `0x6986B6` (functions starting `0x697EA0`,
  `0x698290`, `0x698690`); `empty_right_click_entry` at VA `0x675582`/`0x675692` (function `0x6754B0`) and
  `0x6F2932`/`0x6F2A42` (function `0x6F2860`).
- **`tfh/interface/sidebar.gui`**: six windows; `sidebar_deploy` is the deploy menu, **already read and built** and not
  part of this wave. The other five - `sidebar_provinces`, `sidebar_army`, `sidebar_air`, `sidebar_naval`,
  `sidebar_combat` - each a `sidebar_view_*` icon and `title_view_*` text, the army, air and naval ones a `unit_queue`
  list; rows `unitbrowse_entry` (`expand`, `select_frame`, `counter_type`, `counter_size`, `name`, `location`) and
  `basebrowse_entry` (`name`, `size`); `browser_offset`. Classes `CSideMenu` (9 slots) and `CSideMenuProvinces`,
  `CSideMenuArmy`, `CSideMenuAir`, `CSideMenuNaval`, `CSideMenuCombat`, `CSideMenuMouseObserver`; rows `CBrowserItem`,
  `CUnitBrowserEntry`, `CAirBrowserEntry` / `CAirBaseBrowserEntry` / `CAirUnitBrowserEntry`, `CNavalBrowserEntry` /
  `CNavalBaseBrowserEntry` / `CNavalUnitBrowserEntry`. Recorded already: `CSideMenu::IsShown` (`0x424120`, slot 4),
  `CInGameIdler_OpenSideMenu` (`0x2655C0`, *inferred*, by number, 5 the deploy menu) and `CInGameIdler_CloseSideMenus`
  (`0x265320`, *inferred*, the vector at `CInGameIdler +0xD10`).
- **What opens them**: `CInGameIdler_OpenSideMenu` has seven callers - `CInGameIdler::OnAlertClicked` (VA `0x64AEB2`) and
  **six top-bar handlers just after `CTopBar::OnTheatreButton`** (VA `0x6CF0D6` ... `0x6CFC75`). **The buttons those
  would answer, `button_viewprovinces`, `_viewarmy`, `_viewair`, `_viewnaval`, `_viewcombat` and `_viewdeploy`, are
  commented out in the base game's `topbar.gui`, in Their Finest Hour's and in BlackICE's.** So in play, as shipped,
  nothing of the player's may reach them - which the wave should confirm or refute (a key, another caller, a console
  command).

| reader | brief | fragment |
| --- | --- | --- |
| **A** | **The right-click menu**: who makes it (`CInGameIdler`'s constructor, `CFrontEnd::Enter`) and **what shows it** - which click, where, under what gate (a developer switch?); its rows and their order, what `empty_right_click_entry` is and why `PopMapMode` and `LaunchGame` ask for it; each of the three items - its text, what a click does (build units, close, reload: of what?), when it is shown or greyed; tooltips; how it closes. | `rightclick-menu.json` |
| **B** | **The side menus' frame, and the provinces, army and combat menus**: `CSideMenu`'s nine slots and the frame (the window, its title and icon, show, hide, the mouse observer, `browser_offset`); `CInGameIdler_OpenSideMenu` and `CloseSideMenus` read whole - which number is which menu, one at a time or not; **the six top-bar handlers** - which button each is bound to, and whether anything reaches them with the buttons absent (a shortcut, the glue's registration on a missing button); then `CSideMenuProvinces`, `CSideMenuArmy` and `CSideMenuCombat` - what each lists, in what order, how `unitbrowse_entry` (`CUnitBrowserEntry`) is filled - name, location, counter, the `expand` tree - what a click on a row, `expand` and `select_frame` does, every tooltip. | `sidemenu-land.json` |
| **C** | **The air and naval side menus**: `CSideMenuAir`, `CSideMenuNaval` and their rows - `basebrowse_entry` for a base (`name`, `size`: what size?) and `unitbrowse_entry` for a unit under it (`CAirBaseBrowserEntry`, `CAirUnitBrowserEntry`, `CNavalBaseBrowserEntry`, `CNavalUnitBrowserEntry`, and their parents `CAirBrowserEntry`, `CNavalBrowserEntry`) - which bases are listed and in what order, which units under each, what a click does, every tooltip. **The frame and `CBrowserItem`/`CUnitBrowserEntry` are B's**; say where C's rows lean on them. | `sidemenu-sea-air.json` |

**The oracle**: none in play - the menus cannot be opened in the shipped game, by the reading so far. The maintainer
knows the original; ask him only what the bytes leave open.

---

## The reorganise wave - the window two units hand brigades between

> **LANDED 2026-11-04.** Launched on the maintainer's word with two screenshots of the original's window (two land
> divisions, two fleets), every figure on which the readings account for but a greyed "Select" button, taken to be a
> selected unit's row beside the window. Two fragments merged (18 address entries new, 4 revised; 2 structs declared, 17
> struct fields); the write-up is `findings/FINDINGS-reorgwindow.md`, indexed in `CANDIDATES.md`. Left open there: what
> keeps an emptied unit alive until the close, and the row-moving template `0x370860`.

**The question, for OpenHOI3**: `reorg_window` in `interface/unitpanel.gui`, which the multi-unit panel's
`reorganizebutton` brings up with exactly two units selected - `CInGameIdler::OnReorganiseButton` (`0x26BC70`) gives the
window at `CInGameIdler +0x1358` the first and the second in selection order, sets its byte `+0x39`, fills it (VA
`0x764960`) and shows it; `CloseReorganiseWindow` (`0x256DF0`) shuts it when the window's own test (VA `0x7646D0`) fails;
the button is greyed by `UnitList_MayReorganise` (`0xE0A30`; `FINDINGS-selection.md`, B.4). OpenHOI3 shows the button and
builds nothing behind it. The brigade's move is `CTransferSubUnitCommand` (`0x1DCA90`, `Execute` `0x1DCB40`), already read
for the AI's regrouping and built in OpenHOI3 - **its refusal test `0xE1010(unit, country, subunit, 1)` was read only to
its battle check**.

**What is known before reading.** The classes are `CReorgPanel` and `CReorgEntry` (RTTI; glue tables VA `0x15D99E8` and
`0x15D99BC`, `CReorgEntry`'s own `0x15D9924`/`0x15D995C`). The code sits around VA `0x763000`-`0x765200`: the fill
`0x764960`, the test `0x7646D0`, the close `0x764B90`, the transfer site `0x763C53` (one of the command's two interface
callers; the other is `0x33AB6C`), and the recorded `CReorgWindow_ElementTooltip` (`0x364F40`). The file's elements:
`reorg_bg`, `positioning_left` / `_right`, `ships_ratio_left` / `_right`, `reorg_label`, `unitname_1` / `_2`, `closebutton`,
`left_list` / `right_list`; each row `reorg_entry` (left) or `reorg_entry_right` with `band_reorg_regiment`,
`counter_type`, `counter_size`, `subunit_name`, `subunit_type`, `subunit_level`, `subunit_strength`, `org_bar`, `str_bar` and
`transferbutton`.

| reader | brief | fragment |
| --- | --- | --- |
| **A** | **The window** (`CReorgPanel`, `CReorgEntry`, VA `0x763000`-`0x765200`): the constructor and every slot; the fill - what `unitname_1`/`_2`, `reorg_label`, `positioning_*` and `ships_ratio_*` show and in what format, which list holds which unit, the order of the rows; each row's figures, its counter and band, its bars; **`transferbutton`** - when it is greyed and what it posts, for which brigade to which unit, and whether the lists are made again after; the test that shuts the window; `closebutton`; every tooltip (the recorded one included). | `reorg-window.json` |
| **B** | **What may be moved**: `0xE1010(unit, country, subunit, 1)` read whole - every kind of brigade against every kind of unit (land, naval, air; headquarters; a division's limits), the last brigade, a unit at sea or in a port, and what its fourth argument changes - and whatever else `CTransferSubUnitCommand::Execute` refuses or does that the record does not yet say. **Do not record the window's functions**; they are A's. | `reorg-transfer.json` |

**The oracle**: the maintainer's eye, and screenshots of the original's reorganise window - two land divisions in one
province, and two fleets in one port - asked for before the build.

---

## The land orders wave - the window a land unit is given a strategic redeployment or a support attack from

> **LANDED 2026-11-04.** Launched on the maintainer's two screenshots of the original's window (Reppen, his own; Brodnica,
> an enemy's), every figure on which the readings account for. Two fragments merged (24 address entries new, 2 revised in
> their comments; 1 struct declared, 10 struct fields); the write-up is `findings/FINDINGS-landorders.md`, indexed in
> `CANDIDATES.md`. Left open there: `CreateOrder`'s arguments, the radio observer's wiring, the date formatter.

**The question, for OpenHOI3**: `land_unit_order` in `interface/orders.gui`, the original's `CLandOrdersView`, which a
land unit's right click brings up with Ctrl held (the maintainer's word, 2026-10-19) - `CInGameIdler::OpenOrdersView`
(`0x277260`) makes it as mode 2, 0x198 bytes (`FINDINGS-seaair.md`, section 1, whose table gives the three constructors
as VAs: the land one is **VA `0x73C270`, rva `0x33C270`**). It is the only way a player gives a land unit a strategic
redeployment or a support attack, and OpenHOI3 has neither window nor rows. The naval and air views are read whole
(`CNavalOrdersView` at `0x33DB50`, `CAirOrdersView` at `0x3400C0`), so the land one is expected to follow their shape.

**What is known before reading.** The land view's code is VA `0x73C270`-`0x73DB50`, just above the naval constructor.
Two of its functions are recorded: `LandOrdersView_IsMoveOrder` (`0x33CB00`, whether the chosen order at `+0x140` is
`move_order`) and `LandOrdersView_EstimateArrival` (`0x33D460`, the *Synchronise Arrival* estimate - the latest hour any
selected unit would arrive at the view's province `+0x34`; `FINDINGS-weathersim.md`, C.4). The file's elements:
`background`, `title`, the list `orders_list` filled from the `order_entry` template, `sync_checkbox` and `sync_title`,
`daytime_title`, `daytime_icon` (`GFX_prov_daynight`) and `daytime_icondesc`, `cancel` and `accept`. The orders the
record has on the land side: `CMoveOrder`, `CStrategicRedeploymentOrder` (type 0x5A4, table rva `0x11C5ADC`),
`CSupportAttackOrder` (type 0x4E5); `CSetOrderCommand` is what the other two views' accept posts.

| reader | brief | fragment |
| --- | --- | --- |
| **A** | **The window** (VA `0x73C270`-`0x73DB50`, and the land branch of `OpenOrdersView`): the constructor - what it wires, what it writes into `title`, which orders it makes and in what order, and which it lists greyed or leaves out; its `AddOrder`, the radio group's observer, `Update` (slot 2), `accept` - which command per selected unit, with what fields, for which units of the selection - and `cancel`; **`sync_checkbox`** - its default, what it changes in the command (the arrival hour of `EstimateArrival`?), and whether it is kept between windows; **the daytime row** - what `daytime_icondesc` says and which frame the icon shows; the tooltips (slot 6) of every element; which key brings the window up (the `CInGameIdler +0x1C` slot 12 of `FINDINGS-seaair.md`, section 1). | `land-orders-view.json` |
| **B** | **The rows**: for every order class the constructor offers (from A's list, or the constructor's `CreateOrder` calls if read first - **do not record the constructor itself**, it is A's) - its slot 6 name and localisation key, what decides whether it may be given here (valid target, range, the unit's state, a province of the enemy's or our own), the tooltip of a row that cannot be given, and what the order does once given only as far as OpenHOI3's `moving.md` and `movement.md` do not already say. Start from `CStrategicRedeploymentOrder` and `CSupportAttackOrder`. | `land-orders-rows.json` |

**The oracle**: the maintainer's eye, and a screenshot of the original's land orders window, a unit selected and Ctrl
and the right click given on a province of its own country and on an enemy's, asked for before the build.

---

## The outliner wave - the list down the side of the in-game screen

> **LANDED 2026-11-03.** Launched the same day on the maintainer's word "You can launch the wave", with three screenshots
> of the original's outliner as the oracle, every figure in which the readings account for. Three fragments merged (114
> address entries, 111 new; 11 structs declared, 67 struct fields; apply `failed: 0`, `struct fields: 0`); the write-up
> is `findings/FINDINGS-outliner.md`, indexed in `CANDIDATES.md`. It explains the 30-widget leak of `FINDINGS-guilive.md`
> and finds the province row of the file dead. For OpenHOI3's interface: the outliner is the first of the windows its files
> declare that has no code there (`interface/outliner.gui`, window `outliner`). Nothing of it has been read: the record
> has `CCombatMember::BuildTooltip` (`0x2A9E90`, inferred), `BuildOutlinerHeaderTooltip` (`0x2AE0D0`) and
> `CTopBar::SyncOutliner` (`0x2CB920`, inferred, the top bar's `topbar_outlinerbutton`), and `FINDINGS-guilive.md` its
> widgets live.

**What is known before reading.** The code sits in VA `0x6A3000`-`0x6B6A00`: 121 function starts, 2 recorded. The rows
are `COutLinerMember` and nine subclasses - `CTitleMember`, `CArmyMember`, `CNavyMember`, `CAirMember`, `CCombatMember`,
`CNavalCombatMember`, `CAirCombatMember`, `CBombCombatMember`, `CAlliedObjectiveMember` - which override slots 0, 8 and
12 to 16 (and 17 for the three unit rows). The file's elements: the nine view switches `outliner_view_landunits`,
`_airunits`, `_navalunits`, `_landcombat`, `_aircombat`, `_navalcombat`, `_bombonus`, `_bombonthem`, `_ao`; the list
`outliner_list`; the configuration window `outliner_configuration` with `outliner_configuration_entry` rows; and the row
windows `outliner_header_entry`, `outliner_province_entry` (`occupied`, `siege`), `outliner_combat_entry`,
`outliner_standard_entry`, `outliner_top_unit_entry` (`expand_button`, `movment`), `outliner_unit_entry` and
`outliner_allied_objective_entry`. String references: `outliner` at VA `0x6A3588`, `outliner_configuration` `0x6A3695`,
the view switches `0x6A3A06`-`0x6A3C66`, `outliner_list` `0x6A46C4`-`0x6A873F`, the combat entry `0x6A9B38`-`0x6B50F9`,
the header entry `0x6ADF36`, the top unit entry `0x6AE955`-`0x6B2B53`, the allied objective entry `0x6B5706`.

| reader | brief | fragment |
| --- | --- | --- |
| **A** | **The window and its list** (VA `0x6A3000`-`0x6A9A00`, and `CTopBar::SyncOutliner`): what builds it and where it is shown; the nine switches and the configuration window - what each shows or hides, its default, whether it is saved and where; **what the list holds and in what order** - which units, battles, provinces and objectives, grouped under which titles; when it is rebuilt (each frame, each hour, on a change); what a click, a double click and a right click on a row do (select, centre the map, open a window). | `outliner-window.json` |
| **B** | **The unit rows** - `CArmyMember`, `CNavyMember`, `CAirMember`, the top-unit entry with its expand button and the unit entry under it: every override's slot, the text and `info_text` written (which figures, in what format), the `movment` icon's frames and what picks one, what expands and collapses, the tooltip, and what selecting one does. | `outliner-unit-rows.json` |
| **C** | **The other rows** - `CTitleMember`, the four battle rows, `CAlliedObjectiveMember`, the province entry with `occupied` and `siege`, and the header's tooltip (`0x2AE0D0`): what each row says and shows, its tooltip, and what a click on it does. | `outliner-other-rows.json` |

**The oracle**: the maintainer's eye, and a screenshot of the original's outliner with units, a battle and a besieged
province in it, asked for before the build.

---

## The start technology wave - what brings a country's technology up to date before the first screen

> **LANDED 2026-11-02.** Launched the same day on the maintainer's word "continue with your suggestion". Both readers
> reached `0xD59D0`, `SetUpCountryLawsAndTechnologyForNewGame`, and each one's simulation reproduces all 476 levels; the
> write-up is `findings/FINDINGS-starttech.md`, indexed in `CANDIDATES.md`, where what it left is queued. The function
> also moves every country's laws before the first screen.

**The question, for OpenHOI3**: a new game in the original gives countries technology levels their history files do
not. In the start save `Germany1936_01_01_00.hoi3` **476 levels in 101 countries** stand above the history - Germany
22, France and Britain 21, Japan 20, China 17 - and **453 of them are exactly the highest level of that technology due
before 1936** (`start_year` for level 1, `first_offset` and `additional_offset` above it; `CTechnologyStatus::GetYear`,
`CTechnology_YearPenalty`); the other 23, all small countries, part of the way there. They come in whole sets by kind
of unit - militia equipment in 66 countries, agriculture, supply production, cavalry, artillery, anti-tank, anti-air,
destroyers, light tanks, armoured cars, mountain infantry - and **some 12,000 levels as far behind are left alone**.
No technology has progress or leadership on it in the save, and all 1316 abilities are the history's, so it is not
research; no Lua command sets a level, so it is not the AI's script; the player's country gets it too. OpenHOI3 does
not give it, and its China fights with level-0 infantry equipment against the original's level 1 and falls in six
months to the original's thirteen and a half (`OpenHOI3/docs/mechanics/headless.md`, section 4).

Already tried as the selection rule and **not** it (OpenHOI3's `SaveCheck techgap`, `resources.md` section 5): the
levels the country's units or orders hold (29 of 476), the unit types it has (192, with over 500 raised that the save
leaves), every level its history file gives at any later date (66), its own model files (47).

| reader | brief | fragment |
| --- | --- | --- |
| **A** | **From the data.** Every writer of a country's technology level - `CTechnologyStatus`'s level array (`+0x218`, `CTechnologyStatus::GetLevel` at `0x133130`) - and which of them is not research, the history's `technology` block, an effect or a command. Read that one whole: the selection rule, the level given, the year it is reckoned against, what else it writes (abilities? models?). | `start-tech-writers.json` |
| **B** | **From the timeline.** The new-game path from the history loaded to the first screen - the two days, the entry pass, `CInGameIdler::Enter` - and every call on it that touches technology; reach the same function by that road, say when it runs and for whom, and whether a loaded save runs it again. | `start-tech-path.json` |

**The oracle**: `raised.txt` in the collecting session's scratchpad, one line a level - country, technology, the save's
level, the history's, the level due - and the start save itself. A reading is right when it predicts China's 17 and
Germany's 22 and leaves Germany's 36 behind ones alone.

---

## The moving wave - the military AI's third piece: moving and attacking

> **LANDED 2026-10-19.** Six readers, A to F below, on the maintainer's word "Ok lets go" (2026-10-17; relaunched on
> 2026-10-19 after the first launch hit the usage limit before any reader's first step). Six fragments merged (72 address
> entries, 43 new; 1 struct declared, 40 struct fields; apply `failed: 0`, `struct fields: 0`); the write-up is
> `findings/FINDINGS-moving.md`, indexed in `CANDIDATES.md`, where what it left is queued. The attack's candidates are
> taken lowest cost first; the division need's weight sum is never divided, and the capital's naval floor gives every
> European Soviet theatre 18; the AI's sea targeting asks for no sighting; an invasion's "load at night" stage sends
> carrier aircraft; the AI's leader pass only fills leaderless units.

**The question, for OpenHOI3's stage 5 - the military AI's third piece**: what moves a unit and makes it attack. The
second piece built the theatres, the agents, the order of battle and every plan; nothing yet marches a division to a
front, sends a fleet or a wing at the enemy, lands anyone on a coast - or settles the division need the built balancing
waits on. Six readers, A to F; the write-up is **a new `findings/FINDINGS-moving.md`**, sections A to F.

**Already read, not to be redone - cite it; re-read only to settle a listed leftover or to correct**:

- `FINDINGS-agents.md` - the pass, the agent tick's 22 rows (A.2 numbers them; rows 10, 12, 15, 17, 18, 19, 21 are this
  wave's), the regrouping, the plan whole, and the movers between theatres (F.1-F.5, divisions, fleets, transports, air).
- `FINDINGS-aiconsumer.md` - `CAIUnit_ManageLandUnits` (row 21) phases 1-3 whole: the front-province scoring, the
  committing of units one at a time against the odds bars, the calling-off. Its *What is not established* is reader B's
  list.
- `FINDINGS-attackodds.md` - `CAIUnit::EstimateAttackOdds` (`0x4D93B0`) whole: a damage ratio.
- `FINDINGS-aihelpers.md` - the AI's own combat modifier model (`0x4D8C50` attack, `0x4D8590` defence).
- `FINDINGS-airnaval4.md` - air phase 4's mission assignment; the naval convoy-escort and rebase block.
- `FINDINGS-airstance.md` - who sets the air stance; who fills the four `air_target_provinces_*` lists.
- `FINDINGS-invasion.md` - `CEU3AI::PickInvasionLandingProvince` whole. `FINDINGS-theatre2.md` - `CAIInvasion`'s stage
  machine, named `likely` from one read.
- `FINDINGS-aiplans.md`, `FINDINGS-aiunit.md`, `FINDINGS-theatres.md` - the plan's slots, the class, the theatres.

**The oracle.** The five saves (one game, Germany played): **Italy is at war with Ethiopia in all of them - the one
running war**, so Italy's land block runs every third hour and *Cdo. Sup. Africa* is the one plan at stance 4 with a
`path`; 12 plans in `_01_04_12` carry an embark/debark pair, all ports; between `_01_01_00` and `_01_04_12` 429 units
change place. OpenHOI3's built check (`SaveCheck agents`) leaves concrete targets: the Soviet Home Command holds 3
divisions against the save's 18 (the division need), `our_power` agrees in 22 of 106 and `their_power` in 78 of 106.

| reader | brief | fragment |
| --- | --- | --- |
| **A** | **The land block - who marches where.** Rows 10 and 15: `0x4B1820` (`CAIUnit_UpdateThreatenedProvinces`); `0x4CC450` (the land block's first call, clears `full_pass_pending`) and `0x4CC020`, `0x4D7F80` (sets it back), `0x4CC690` (gated on the air-transports vector `+0x10C` - a paradrop planner?) - all four whole: how a division is given a province to stand in (garrisons, reserves, the walk to the front), which command each posts, and how this meets the per-division `CSetAIParamCommand(unit, target, staging)` targets. With them: which order kinds `0x4E5` and `0x56C` are (slot 86 skips a unit under one), `CUnit +0x2C9` (disqualifies a candidate, one reader at `0x4D6CE0`), `CCountry +0xF50` (tested `> 0` beside `at_war` to run the land pass at all). | `land-block.json` |
| **B** | **Attacking's open ends** - `FINDINGS-aiconsumer.md`'s *not established*, off the bytes: slot 86 (`0x4C7540`, the veto - what disqualifies a unit); slot 88 (`0x4BE560`, a float against 95.0); slot 89 (`0x4BE7E0`, the enemy's power at a province); **`0x49AAB0`, the stand-down primitive** - what command it posts, whether a cancelled attack stops or reverses; slot 17's sign on one `CCombat` subclass (the land body disengages `> 0.5`, the naval `< 0.5` complemented - which is "losing"); `CMapProvince +0x330`/`+0x354` (the unsupplied-attacker port test); `CAIUnit +0x12C`'s contents (`FINDINGS-opsarea.md` item 7's `m mod n`). | `attack-vetoes-and-standdown.json` |
| **C** | **The division need's arithmetic** - what OpenHOI3's balancing waits on. `CAIUnit::EstimateAreaNeed` (`0x4B82F0`) tail, VA `0x8B8F26`-`0x8B9098`, instruction by instruction: the integer score sum divided by 1000.0 and rounded by `fistp`, the float sum carried through the recursion into the focus areas of `+0x338`, and **which of the two is divided by the area's provinces (at most 40)**; `CAIUnit::EstimateTheatreNeed` (`0x4B9610`) whole; `their_power` exact (`0x4B5210`/`0x4B60F0`'s enemy side - the save agrees only 78 of 106); France's 0.5% in `our_power` and how a figure under 1.000 passed the whole-number gate on its first post (`0x4E1D00`?); `0x508C30`. The check: the Soviet Home Command's 18 divisions, and the saves' `our_power`/`their_power`. | `division-need.json` |
| **D** | **Fleets and aircraft to their targets.** `CEU3AI_AssignSeaTargetsToAgents` (`0x48C140`) whole - what fills `+0x25C` (sightings gained), `+0x26C` (lost) and `+0xD8` (`submarine_want`), which `DistributeFleetsToTheatres` and the naval-bomber want read; `CAIUnit_ManageNavalUnits` (`0x4D0880`) rows the regroup (section C) and the convoy/rebase block (`FINDINGS-airnaval4.md`) did not cover - who is sent to sea, to patrol, to intercept, and when; `CAIUnit_ManageAirUnits` (`0x4CD890`) likewise beyond phase 4 and the regroup; `BuildAirTargetProvinceLists` (row 12) against `FINDINGS-airstance.md` - settle what it left. Small leftovers in reach: `0xD52A0`'s war branch (the fleet-to-port route test), `0xE1010` past its combat test (is a transfer refused?), `0x4B4200`'s province score, which way `InsertUnitByRange` keeps its order. | `sea-and-air-targets.json` |
| **E** | **Invasions.** The `CEU3AI` side whole: `PlanAmphibiousInvasion` (`0x492190`) with `AddTransportNeed` (`0x4935DE`), `AddBrigadeNeed` (`0x493756`), `CreateInvasionAgent` (`0x493B18`); `RankInvasionAreas` (`0x495530`); `PruneInvasions` (`0x491BE0`); `RebuildWeakEnemyPorts` (`0x4972E0`); `AbandonInvasionArea` (`0x494C40`); `ProcessAI_UpdateInvasionAgents` (`0x489887`). Then `CAIInvasion`'s tick off the bytes, raising `FINDINGS-theatre2.md`'s `likely` names: `DoTick` (`0x49FB40`), `PickLandingSite` (`0x49FBC0`), `MarchLandForceToPort` (`0x4A01F0`), `LoadTransportsAtNight` (`0x4A0610`), `SailAndIssueInvasionOrder` (`0x4A09B0`), `UnitCanReachObjectiveOverland` (`0x4A11B0`), `IsInvasionOver` (`0x4A12F0`), `AddUnit` (`0x4A1680`), `ReleaseUnitOutsidePortArea` (`0x4A18E0`). `PickInvasionLandingProvince` is read whole - cite it. | `invasions.json` |
| **F** | **Sealift and the pass's remainders.** `CAIUnit::AssignAreaTargetsAndSealift` (`0x4C4370`, 12.7 KB) **off the bytes** - `FINDINGS-agents.md` E.6 has its shape from the decompiler alone: the head's per-division targets by area need and the `CSetAIParamCommand(unit, target, staging)` it posts (and that command's `Execute`), the land-or-sea split, the tail's embark/debark vote, and the pickers `0x4C3AF0` (the port), `0x4C3940`, `0x4C3D50`; `CEU3AI_RecallStrandedLandUnits` (`0x498870`) whole; `AI_ReassignLeaders` (`0x498EF0`) whole - raise it from `inferred`, what it moves and by what rule against `FINDINGS-leaderassign.md`. | `sealift-and-leaders.json` |

**Measurable afterwards, by OpenHOI3**: the 4 January and 20 April saves beside a run - divisions standing on the
fronts' provinces, the two powers whole, the Soviet divisions balanced, embark/debark pairs posted - and the headless
run's Spanish Civil War and Italy's war in Ethiopia no longer frozen.

---

## The agent wave - the order of battle the AI builds under its theatres, and each theatre's plan

> **LANDED 2026-10-17.** Five readers, A to E below, on the maintainer's word "Continue with the next step" after the
> theatre wave; five fragments and a follow-up merged (89 address entries, 55 new and 34 revised, 6 structs, 76 struct
> fields; apply `failed: 0`, `struct fields: 0`); the write-up is `findings/FINDINGS-agents.md`, indexed in
> `CANDIDATES.md`, where what it left is queued. **The counts below are wrong**: they keyed units by id alone, and
> serials of two id types collide (reader B). Keyed by the whole id, 382 units are new - 93 army groups, 96 armies under
> army groups and 1 under a theatre, 89 corps, 87 navies and 16 air units - 44 gone (31 navies, 13 air units) and 599
> change parent; and no ops area changes between `_01_04_12` and `_01_07_14`, an empty one not being saved (reader E).
> **A sixth reader, F**, was sent the same day for the four movers between theatres A had only named, once OpenHOI3's check
> showed what they do (section F); its fragment `movers-between-theatres.json` merged, 18 entries, apply clean. **A seventh, G**, found
> what had already spread the history's units over the theatres by the start save - the sort at each country's first AI
> pass, `0x48D560` (section G), 1555 of 1555 parents - correcting A's first frame and `FINDINGS-theatres.md` K and O.

**The question, for OpenHOI3's stage 5 - the military AI's second piece**: what the AI's unit agents (`CAIUnit`, one per
theatre and below) do to the order of battle and to each theatre's plan in a new game's first days. Moving units and
attacking (`CAIUnit_ManageLandUnits`, naval, air, `CAIInvasion`) are the third piece and **out of this wave** except
where a reader must know which of them a call is.

**The oracle.** `Germany1936_01_01_00.hoi3` is a new game after its two days and first hour; `_01_04_12` three and a
half days later; `_01_07_14` and `_01_08_07` later still, all with Germany played and every other country the AI's.
Between the first two, **285 units are new and 40 gone**: 66 army groups under theatres, 70 armies under army groups,
67 corps under armies, 63 navies and 14 air units under theatres, one army under a theatre and 4 corps under navies; the
40 gone are all fleets (30) and air units (10), so fleets and air units are regrouped. 661 units change parent, 429
change place. From `_01_04_12` to `_01_07_14` only 13 change parent, so **the reorganisation is a first-days thing**.
Every theatre headquarters but the played country's (106 of 108) carries a `plan` block by `_01_04_12` - `active`,
`stance`, `air_stance`, `naval_stance`, `our_power`, `their_power`, `embark`, `debark`, `ops_area`, `min` (58 counts, one a
sub-unit type) - and from `_01_04_12` to `_01_07_14` stance, the two other stances and `min` agree for all 106, the ops
area for 90, the powers for 99. Scratch scripts that print these are in the collecting session's
`scratchpad/agents/` (`unitdiff.py`, `plandiff.py`, `planowners.py`).

**Already read, not to be redone**: `FINDINGS-aiunit.md` (the class, its tick's staggers, its slots), `FINDINGS-aiplans.md`
(slot 76 whole, slot 78's head, slot 84, the objective generator's formula, the stance decider's shape),
`FINDINGS-aitheatre.md` and `FINDINGS-theatre2.md` (the theatre layer's map, `CAIInvasion`), `FINDINGS-aiconsumer.md`
(`ManageLandUnits` - the third piece's), `FINDINGS-aifields.md`, `FINDINGS-theatres.md` (the theatres themselves, read
whole the day before). `ProcessAI` (rva `0x4894E0`) and `CAIUnit::Tick` (slot 73, rva `0x4B0730`) are named in the record
with their callees partly named; each reader starts from them.

| reader | brief |
| --- | --- |
| **A** | **The pass and the agents' life.** `ProcessAI` whole in order, every `CEU3AI` helper it calls named at least by purpose (`0x49A800`, `0x48C140`, `0x491BE0`, `0x495530`, `0x498870`, `0x48DCF0`, `0x499C80`, `0x48E490`, `0x490DB0`, `0x48FBB0`, `0x48F2B0`, `0x499280`, `0x499A10`, `CEU3AI_DisbandTheatrelessHQs`, `RebuildPriorityProvinces`, the `CProvinceFloat_2` call); `CreateAgentsForTheatres`, `EnsureAgentForArea` and their callers, `0x4AC390`, an agent's enabling, `SetUnit`/`ClearUnit` (slots 63, 64), what removes an agent; `CEU3AI +0x2C` (`runs_units`), `+0xA5`, `+0xA6`; and slot 73's gates and the flag bytes `+0x80`-`+0x88` - which callee of the tick is which, so B to E can be pointed at theirs. |
| **B** | **Higher commands made.** Slot 85 (rva `0x4C20C0`) whole - when the agent makes an army group, army or corps (`CCreateHigherCommand`) and what it attaches under it (`CAttachUnitCommand`); slot 82 (`CSetCommandLevel`, every hour); `CAIUnit_PullHeadquartersIn`, `CAIUnit_MoveAgentUnitToCommandProvince`; the observer slots 17-19 (`0x4D5320`); and the `Execute` of `CCreateHigherCommand`, `CAttachUnitCommand` and `CSetCommandLevel` - what each changes, the new unit's id, name (`#st Army Group`), place and leader. The check is the 66/70/67 ladder above. |
| **C** | **Subordinates and fleets regrouped.** Slot 78 (rva `0x4B1D10`-`0x4B32DF`) whole, which `FINDINGS-aiplans.md` read only to its head; slot 79 (`0x4B32E0`, detach and expedition, `vf_80` and `ManageExpeditions` as the tick calls them); the three `CTransferSubUnitCommand` sites (`0x4CE90E`, `0x4D1341`, `0x4D1BEB`) and what they are in; and whatever merges or splits fleets and air units into new ones under a theatre (the 63 navies, 14 air units and 40 gone) - with `CDetachUnitCommand`, `CTransferSubUnitCommand` and any merge command's `Execute`. |
| **D** | **The plan's figures: stance, powers, objectives.** `CEU3AI::UpdateUnitStances` (rva `0x4912D0`) whole - the 0-4 value and the air and naval stances; `CAIUnit_ComputePlanForces` and `CAIUnit_ComputePlanForcesAndPower` and the power estimator `0x4B60F0` - `our_power` and `their_power`; `GenerateUnitObjectives` (`0x4980E0`) and `RebuildPriorityProvinces` with `CCountry +0x4A8` and `CEU3AI +0x118`; `CSetPlanAttributesCommand`'s and `CSetPlanObjectivesCommand`'s `Execute`; what `active` is. |
| **E** | **The plan's area: ops area, axis, embark and debark, `min`.** `CAIUnit::SetArea` (rva `0x4BA5A0`, 5.4 KB) and `GetArea`; `UpdatePlanAxis` (`0x4C3330`); `ReplanSubtree`'s callees `0x4BBB50`, `0x4BC860`, `0x4BCD60`, `0x4BDF30`, `0x4BD270`; `RebuildFocusOwnerAreas`; `CSetPlanOpsAreaCommand`, `CSetPlanAxisCommand` (embark and debark?), `CSetPlanForcesCommand` and `CUnit::RefreshPlanForceNeeds` - what the save's `min` is and how it is counted; the `0x4DCAE0` float at `+0x368`; and slot 76's fallback's double post (`FINDINGS-aiplans.md` step 7), against the saves. |

---

## The theatre wave - fronts, theatres and their headquarters

> **LANDED 2026-10-17.** Read by the collecting session alone, on the maintainer's word that day ("Ok lets do the
> military AI"), cut by that session into pieces with fronts and theatres first; one fragment merged (36 addresses new,
> 9 revised, one vftable slot, 48 struct fields; apply `failed: 0`, `struct fields: 0`); the write-up is
> `findings/FINDINGS-theatres.md`, indexed in `CANDIDATES.md`, where three things it left are queued. The cached tags
> past slot 28 were not in the array's order, and a unit name is kept per country; with both corrected OpenHOI3's check
> agreed in all 108 of the start save's theatres.

The question, for OpenHOI3's stage 5: what the AI's theatres are, where they come from and when, and the headquarters
each is given - the start save holds every country's, so it is the check. **The next piece is the unit agents**
(`CAIUnit`): what moves the units and puts the history's top-level commands under a theatre.

---

## The AI strategy wave - who each country fears, courts, antagonises and protects

> **LANDED 2026-10-16.** Read by the collecting session alone, on the maintainer's word that day ("go ahead with it",
> the AI strategy before the military AI); two fragments merged (25 addresses new, 5 revised, 4 struct fields, and a
> correction moving one entry off its virtual address; apply `failed: 0`, `struct fields: 0`); the write-up is
> `findings/FINDINGS-aistrategy.md`, indexed in `CANDIDATES.md`, where three things it left are queued. Every country's
> strategy is rebuilt every ten days, not a handful of times a year; the base game's victory conditions antagonise the
> controllers of the provinces they name. A third fragment the same day read the walk's other twelve bodies and
> corrected `protect`'s cap to 6 and 12, both found by OpenHOI3's check against the start save, which then agreed in
> every list for all 78 countries.

The question, for OpenHOI3's stage 5: what fills `CAIStrategy`'s lists. OpenHOI3's foreign minister answered
`GetFriendliness`, `GetAntagonism`, `GetThreat` and `GetProtectionism` with 0, so no AI offered a NAP, a guarantee or an
alliance in 180 days. The start save holds every country's strategy, so it is the check.

---

## The foreign minister wave - the AI's decisions and its prepared wars, then the whole minister

> **LANDED 2026-10-16.** Read by the collecting session alone, on the maintainer's word that day ("continue with
> decisions"); two fragments merged (6 addresses new, 2 revised, 2 signatures placed whole; apply `failed: 0`,
> `struct fields: 0`); the write-up is `findings/FINDINGS-foreignminister.md`, indexed in `CANDIDATES.md`, where four
> things it left are queued. The decision score is rounded to the nearest, not cut; the readiness test a prepared war
> waits on counts the theatre layer's fronts.

> **Second pass LANDED the same day**, on the maintainer's word "Complete the foreign minister": every engine method
> `ForeignMinister_Tick` reaches that was unread - 14 addresses new and the constructor revised (`foreign-minister-api.json`;
> apply `failed: 0`, `struct fields: 0`); `FINDINGS-foreignminister.md` section I. The minister's skip-once byte is set by
> its constructor, so its first work does nothing.

The question, for OpenHOI3's stage 5: what the foreign minister's day does around `ExecuteDiploDecisions` - read
2026-10-12 (`FINDINGS-eventfire.md` 2.4) - and in particular the prepared wars four countries' scripts tie a decision to
(`PrepareWarDecision`): Germany's Danzig, Italy's Albania and Greece, Japan's Marco Polo Bridge.

---

## The ministers wave - research and production for the countries nobody plays

> **LANDED 2026-10-16.** Four briefs, merged (105 address entries, 91 landed; 8 structs declared, 59 fields; apply
> `failed: 0`, `struct fields: 0`); the write-up is `findings/FINDINGS-ministers.md` sections A to D, indexed in
> `CANDIDATES.md`, where seven things it left are queued. `ProductionMinister_Tick` runs every day, not on the 1st and
> the 15th; the `automate_*` keys are not delegation flags.

Planned 2026-10-16, for OpenHOI3's stage 5, the AI, on the maintainer's word that day ("go ahead with the next
step"): the tech and production ministers first, because OpenHOI3's headless run of 1936 to 1948 showed a world with no
research, no production and sliders frozen where a new game left them (`OpenHOI3/docs/mechanics/headless.md`). Both
ministers are the install's Lua - `TechMinister_Tick` in `script/ai_tech_minister.lua`, `ProductionMinister_Tick` and
`BalanceProductionSliders` in `script/ai_production_minister.lua`, with `ai_support_functions.lua` (`Support.CreateUnit`,
`Support.CalculateExpenseResourceFactor`), `utils.lua` and the countries' files under `script/country/` - so what is
needed from the executable is **what calls them, when, with what, and what each engine method they reach answers**, and
what the commands they post do. Four briefs; the write-up is **a new `findings/FINDINGS-ministers.md`**, sections A to D.

**What is known and is not to be redone** - cite it; re-read on the listing only to settle what follows, to raise an
`inferred` record or to correct one:

- `FINDINGS-ai.md`: the five ministers, `CEU3AI::CreateMinisters`, the hourly `ProcessAI` on TBB workers, the schedule -
  **tech at the hour `(id + 3) mod 24`, production at `(id + 5) mod 24`**; the tech minister's monthly re-plan
  (`0x8AECA0`, `0x8AEF40`, not read) and its two bytes `+0x5C`/`+0x5D` handed to `TechMinister_Tick`; the production
  minister's `0x899770(OwnerAI)` (not read), its gate (`+0x5C < 0` or day of month `% 14 == 0`) and the float
  `*0x4EE560(country) / 1000` (not read); `CAITechMinister::OnCountryEvent` (slot 47, `likely`, what it is not
  established). Records: `CAITechMinister::DoWork` (rva `0x4AEAD0`), `CAIProductionMinister::DoWork` (`0x4A22E0`),
  `Lua_TechMinister_Tick` (`0x4AF280`), `Lua_ProductionMinister_Tick` (`0x4A2B00`), `CAITechMinister::CAITechMinister`
  (`0x4AE7D0`), `LuaProxy_BalanceProductionSliders` (`0x110160`, `inferred`) and its `_Call` (`0x10D570`, `inferred`).
- `FINDINGS-luaapi.md` and `FINDINGS-luahost.md`: the bridge, a failed call, `CFixedPoint:Get()` in single precision,
  the iterators (storage order, stopping at the first null), equality, the per-thread state.
- `FINDINGS-government.md` section E and `FINDINGS-espionage.md` section E: how the politics and intelligence ministers
  were read - the pattern to follow.
- `FINDINGS-tradeaid.md`: `BalanceLendLeaseSliders` is called from the daily pass's cold block;
  `CChangeLendLeaseDistributionCommand::Execute`; `GetMaxLendLeaseFraction`.
- `FINDINGS-leadership.md` and the record: `CCountry::GetAllowedResearchSlots` (rva `0xE0170`, `confirmed`).
- `FINDINGS-buildqueue.md`, `FINDINGS-builders.md`, `FINDINGS-buildingqueue.md`, `FINDINGS-convoylines.md`,
  `FINDINGS-production.md`, `FINDINGS-ic.md`: the queue, a unit's and a building's price, `IsBuildingAllowed`,
  `CConstructBuildingCommand`, `CConstructConvoyCommand`, `CConstructUnitCommand` as the player's windows post them;
  `CountMaxUnitsStillBuildable` (`inferred`). `FINDINGS-techtooltip.md`: `CTechnology::CheckResearchAllowed`.
- `ghidra/luabind.json`: every Lua method's function and every constructor's signature, below by brief.

**What OpenHOI3 needs that is not settled**, by brief (rvas; the export's addresses are VAs, `+0x400000`):

| brief | what it settles | starting points (rva) |
| --- | --- | --- |
| **A. The tech minister** | **The exe's side**: `CAITechMinister::DoWork` re-read whole - the monthly re-plan `0x8AECA0` and `0x8AEF40` (what its two vectors hold, what reads them - do they decide anything, or only feed the Lua?), what `vbSliders` and `vbResearch` (`+0x5C`/`+0x5D`) are for a country nobody plays, slot 47 `OnCountryEvent` and the object `0x557E00` builds (a command? posted when?). **What the script reaches**: `CAITechMinister:CanResearch(tech)` (`0x4AF190`) against `CTechnology:CanResearch` (`0x135760`) and `CTechnologyStatus:CanResearch` (`0x133950`); `CCountry` `GetNumberOfCurrentResearch` (`0x4E81F0`), `GetCurrentResearch` (`0xE01F0`, which list, in which order), `GetTotalLeadership` (`0xF4E00`), `GetOfficerRatio` (`0x17C60`), `GetDiplomaticInfluence` (`0xF4E20`), `CalculateNumberOfActiveInfluences` (`0xFBEA0`, `likely`), `GetNumOfPorts` (`0xE2170`), `GetNumOfAirfields` (`0xE2180`), `GetTechnologyStatus` (`0x17BA0`); `CTechnologyDataBase` `GetTechnologies` (order), `GetTechnology(name)` (`0x4EA1D0`, an unknown name?), `GetLatestTechYear` (`0x4EA290`); `CTechnology:GetFolder` (`0xC8530`) and the folder's `GetKey`; `CTechnologyStatus` `GetLevel` (`0x133130`), `GetYear(tech, level)` (`0x133380`), `IsBuildingAvailable` (`0x133110`), `IsUnitAvailable` (`0x133020`); `CBuildingDataBase.GetBuilding(name)` (`0x4E9F80`). **The two commands**: `CStartResearchCommand(tag, tech)` - its constructor and `Execute`: where the technology goes in the queue, what it refuses (already queued, not allowed, a full queue?), whether it moves anything already there; `CChangeLeadershipCommand(tag, nco, diplomacy, espionage, research)` - the four floats' order against the four leadership shares, how a float becomes the share (rounding, the 15-bit kind), any normalising or clamping, and what of the player's own sliders it touches. **`math.random`** in the AI's Lua states: which `rand` it is (the CRT's, the game's?), its seeding, and whether each worker thread's state has its own | `0x4AEAD0`, `0x4AECA0`, `0x4AEF40`, `0x4AE9B0`, `0x157E00`, `0x4AF190`, `0x135760`, `0x133950`, the export's functions above, `luabind.json`'s `CStartResearchCommand` and `CChangeLeadershipCommand`; `FINDINGS-ai.md`, `FINDINGS-luahost.md`, `FINDINGS-leadership.md`, `FINDINGS-techtooltip.md`, `FINDINGS-research*`/`FINDINGS-techdecay.md` |
| **B. The production minister** | **The exe's side**: `CAIProductionMinister::DoWork` re-read whole - `0x899770(OwnerAI)` and what `0x4EE560` answers (VA; rva `0xEE560` is the export's `CCountry::CalcDesperation`, so the cached `+0x5C` is likely the country's desperation - settle it); **the daily `BalanceProductionSliders` call** from `RunCountryDailyPass` (`0xDC203`, `0xDC2EC`) and the two at VA `0x805BAA`/`0x805FBB`: for whom (nobody's country? the player's with automated sliders?), how often, and every argument - `prioSelection` (the `SLIDER_AUTOMATION_LEVEL`), the six values (the current shares, needs, as fractions?) and `bHasReinforceBonus`; **`CAI.FastNormalizeByPriority`** (`0x4E9250`) whole - the priority orders it walks, what it caps each share at, what `factor_left` is; **`CChangeInvestmentCommand(tag, lendlease, consumer, production, supply, reinforce, upgrade)`** - constructor and `Execute`: the floats into the shares, rounding, normalising; **`PrioritizeBuildQueue`** (`0x4A2720`) whole; `CountTransportsUnderConstruction` (`0x4A24D0`) and `CountEscortsUnderConstruction` (`0x4A25E0`). **What happens to an AI country's finished unit**: who places it, where, when (the deploy that the player does by hand) - and its finished building and convoys if anything differs from the player's | `0x4A22E0`, `0x499770`, `0xEE560`?, `0x110160`, `0x10D570`, `0xDC203`, `0xDC2EC`, `0x405BAA`, `0x405FBB`, `0x4E9250`, `0x4A2720`, `0x4A24D0`, `0x4A25E0`; `FINDINGS-ai.md`, `FINDINGS-tradeaid.md`, `FINDINGS-production.md`, `FINDINGS-buildqueue.md`, `FINDINGS-unitstart.md` |
| **C. The production script's units and constructions** | `CAI:GetProductionSubUnitCounts` (`0x4E8190`) and `GetDeployedSubUnitCounts` (`0x4E8180`): which arrays, filled where and when, what counts (brigades by type index? units waiting to be placed, aboard, in a theatre?); the `CArray*` classes' `GetAt`/`SetAt`/`GetSize` (index base, out of range); `CSubUnitDataBase.GetSubUnitList` (order), `CSubUnitDefinition` `GetIndex` (`0x6832A0`), `IsRegiment` (`0x62D10`), `IsCag` (`0xC8350`), `GetBuildCostMP`; `CCountry` `GetConstructions` (`0xF56B0`, order) with `CConstruction` `IsMilitary`, `GetMilitary`, `GetCost` (`0x837C0`: the line's whole cost, a day's?), `GetSize`, `CMilitaryConstruction` `IsLand`/`IsAir`/`IsNaval`/`GetBrigades`, `CBrigadeConstructionDefinition:GetType`; `GetICPart(ProductionCategory)` (`0x103D10`) and `CDistributionSetting`'s constants; `GetUsedIC` (`0xF4B60`); `HasExtraManpowerLeft` (`0x4E81E0`); `CountMaxUnitsStillBuildable` (`0xE13A0`, raise from `inferred`); `GetDissent` (`0xF8AE0`); `HasActiveLendLeaseToAnyone` (`0x1089A0`); `GetEscorts` (`0x17C30`), `GetTotalConvoyTransports` (`0x4E8200`), `GetTotalNeededConvoyTransports` (`0x4E8210`); `CalcDesperation` (`0xEE560`); **`CConstructUnitCommand(tag, list, province, count, reserve, CNullTag(), CID())`** - the Lua constructor and what the command then does with each argument (count as parallel lines or a serial run? reserve; the province not the country's; the two last), against the player's order (`FINDINGS-builders.md`); `SubUnitList()`/`Append`, `CID()`, `CNullTag()` | the export's functions above; `FINDINGS-builders.md`, `FINDINGS-buildqueue.md`, `FINDINGS-ic.md`, `FINDINGS-production.md`, `FINDINGS-tradeaid.md`, `FINDINGS-convoylines.md`, `FINDINGS-trade2.md` (which names the two `CAI` counts) |
| **D. The production script's provinces and buildings** | `CBuildingDataBase.GetBuilding(name)` (`0x4E9F80`; an unknown name - BlackICE's `infrastructure` against TFH's `infra`?), `CBuilding:GetIndex`; `CProvince` `GetBuilding(building)` (`0xA3B60`) with `CProvinceBuilding:GetMax` (`0x17A70`: built level or working level?), `HasBuilding` (`0xA3900`), `GetCurrentConstructionLevel` (`0xA3930`: levels under construction, whose?), `IsFrontProvince(bool)` (`0xA56B0`, recorded `CProvince::HasHostileLandNeighbour` `likely` - what the flag is), `GetController`, `GetOwner`; `CCountry` `GetControlledProvinces` (order), `GetTotalCoreBuildingLevels(index)` (`0xE21A0`), `GetRandomUnderGroundTarget` (`0x109920` - which generator, which provinces), `IsBuildingAllowed`, `GetBuildCost(building)`, `GetConvoyBuildCost`, `GetEscortBuildCost`; **`CConstructBuildingCommand(tag, building, province, count)`** - the Lua constructor and **`IsValid`**, what it tests, against the province view's order (`FINDINGS-buildingqueue.md`); **`CConstructConvoyCommand(tag, escort, count)`**'s Lua constructor (`FINDINGS-convoylines.md` has the command) | the export's functions above; `FINDINGS-buildingqueue.md`, `FINDINGS-provinceview.md`, `FINDINGS-convoylines.md`, `FINDINGS-undergrounds*`, `FINDINGS-occupation.md` |

**Measurable afterwards, by OpenHOI3**: the save of 20 April 1936 (`Germany1936_04_20_03.hoi3`) beside a new game run to
that hour - every AI country's research queue and technology levels, its six production shares and four leadership
shares, its build queue's lines by kind, its convoys - and the headless run's world no longer frozen.
