# The savegame: how a game is loaded and how it is written

*The savegame wave, 2026-11-04: three readers, read statically out of `hoi3_tfh.exe` with `scripts/disasm.py`,
`scripts/findRefs.py`, `scripts/switchmap.py` and copies of the Ghidra project, and set against the maintainer's saves in
`Documents\Paradox Interactive\Hearts of Iron III\save games`. Only valid for this build. For OpenHOI3, whose maintainer
chose the original's `.hoi3` format both ways: OpenHOI3 to load the original's saves and to write saves the original
loads. `FINDINGS-save.md` has the value writers this builds on.*

**The wave in one paragraph.** **A save is loaded in the lobby, before Play** (section A): the session reset, the
history registry emptied, the four id counters put back to 1, then one parse through a 36-key switch, each object's
AfterLoad running as its own block closes. Nothing of the install is read again but the event files; the history is not
replayed; the played country and the random generator are **not** taken from the save. `CInGameIdler::Enter` then runs
**none of a new game's two days and first hour** - only re-derivations (modifiers, intelligence, supply, convoys, the AI's
theatres) and one AI pass for each country - so a loaded game's first hour is the hour after its `date`. **The top
level** (section B) is written in a fixed order - `date`, `player`, the player's automation, the four counters, flags,
settings, `seed`, `count`, the `id` blocks, `fired_events`, **every province in id order, every country in
`common/countries.txt`'s order**, `sunk_ships`, weather, factions, diplomacy, battles, wars, statistics - every key
agreeing with all 33 saves; ids are {type, serial} pairs, four fixed-type counters and a high space of type 4713 in a
game of one player. **The unit tree** (section C) is written from each country's parentless units down, carried units
only by their carrier and a carrier's air groups only inside its ship; the save keeps only the leaders in service and
only their state, never a brigade's `historical_model`, and every key agrees with seven saves.

**Corrected in the record**: `LoadFromSave` has three callers, a multiplayer client parsing from memory; `CGameState::
LoadKey` has 36 keys, `player`, `seed` and `count` among the ignored; `CPersistent::Load` is `__thiscall` and skips the
AfterLoad of an object whose block closes with a parse message pending; `COrder::LoadKey` has a ninth key,
`death_date`; **a leader's history is never saved** (`CLeaderHistory::SaveContents`); `CMilitaryConstruction::LoadKey`
reads its brigades as sub-unit type names; `CUnit::LoadKey` hands any other key to `CreateOrder` and deletes a unit block
with no `location`; and the province and country blocks stand between `fired_events` and `sunk_ships`, not after
`strategic_warfare`. **Raised and not changed**: `CGameState` +0xAEC, +0xB24 and +0xC90 are embedded objects, not the
pointers the record types them as (section B); `CGameState +0xD40` is indexed by country, not by group (section B);
`CSetRandomSeed::LoadKey` (`0x2D7D40`) reads `seed` as well as `count` (section A).

**For OpenHOI3, the two lists that matter most**: what a loader must run after reading a save, and must not, is A.9;
what a writer must put where is B.2 and C.1-C.8, with the date first and the player second (A.6), since the original's
save list reads a save's head by position.

| section | reader | fragment |
| --- | --- | --- |
| A, the load path | A | `fragments/merged/save-load.json` |
| B, the top level and the id scheme | B | `fragments/merged/save-toplevel.json` |
| C, the unit tree and the military blocks | C | `fragments/merged/save-units.json` |

## A. The load path

*Reader A. Read 2026-11-04, statically. Addresses are VAs unless marked rva (rva = VA - 0x400000). **[exe]** is
hardcoded in the executable, **[mod: file]** a file may change it.*

**Synopsis.** The aim was how the original loads a savegame, from `LoadSaveFile` / `CGameState::LoadFromSave` to the
first hour, set beside a new game; it is settled. The save is loaded **in the lobby, before Play**, through a 36-key
token switch; each object's AfterLoad runs as its own block closes, with no pass afterwards; and `CInGameIdler::Enter`'s
thirteen `loaded_from_save` tests decide what is rebuilt - **a loaded game runs none of the new game's two days and first
hour**, only a short set of re-derivations and one AI pass per country. **Corrected rather than added**: `LoadFromSave`
has three callers, not two - a multiplayer client parses the save from memory at `0x30BA34`; `LoadSaveFile`'s argument is
a path string, and it has a streaming fallback arm; `CGameState::LoadKey` has 36 keys, not 31 - `start_date` stores to
+0xBE0, which Ghidra shows discarded, and `player`, `seed` and `count` are thrown away; `CPersistent::Load` is
`__thiscall`, not `__stdcall`, and skips the AfterLoad of an object whose block closes while a parse message is pending;
the lobby's three load arms are server / matching client / other client, not "single player / multiplayer"; and
`ResetSession` is read whole beyond its head - it deletes every CEU3AI, and `StartAI` in the idler's constructor makes
them again.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| 0x27CAE0 | LoadSaveFile | revised | confirmed | path typed `Hoi3CString*`; whole-file read with a streaming catch arm; no version test; callers re-labelled server and matching client |
| 0x27CE30 | CGameState::LoadFromSave | revised | confirmed | the full ordered body, with the history-registry clear and the discarded slot-64 call; the catch skips steps 9-11; **three callers, not two** |
| 0x27FCB0 | CGameState::LoadKey | revised | confirmed | 36 keys with their destinations; `player` ignored; `start_date` to +0xBE0; the default arm - a number a province, a tag a country, anything else silent; `seed`/`count` dropped |
| 0x67C050 | CPersistent::Load | revised | confirmed | signature `__stdcall` -> `__thiscall`; the dispatch loop; AfterLoad only when parse+0xC == 0, at the close of each block |
| 0x27BAF0 | CGameState::ResetSession | revised | inferred | old text kept, plus the whole body's clears in order, and what it does not write (tick, +0xBE0, player, in_game) |
| 0x25A2B0 | CInGameIdler::Enter | revised | inferred | old text kept, plus all 13 load/new branches and what runs for both |
| 0x2ED650 | CFrontEnd::GetApplication | new | confirmed | slot 64, `mov eax,[ecx+0x210]`; its answer unused on the load path |
| 0x1F4880 | HistoryDatabase_Construct | new | inferred | builds the 0x5C-byte history registry at [0x1A88BC0] |
| 0x1F57C0 | HistoryDatabase_Clear | new | inferred | empties that registry; LoadFromSave calls it; Ghidra mislabels it a CDiplomaticHistory constructor |
| 0x1FA950 | HistoryDatabase_SetGlobal | new | confirmed | installs the registry; trap-2 pair with 0x1FA9A0 (two int3) |
| 0x5E690 | ScenarioList_FindByName | new | inferred | list in EAX, name on the stack (no_signature); finds a scenario by name |
| 0x5E5D0 | ScenarioList_GetOrCreate | new | inferred | makes the empty list at [0x1A85564] |
| 0x283A50 | RecountBuildingProvinces | new | inferred | fills CBuilding +0x98; Enter runs it for a loaded game only |
| 0x288000 | AllocateProvinceIntelArrays | new | inferred | slot 6 on every province; new game only |
| 0x96330 | CProvince::AllocateIntel | new | confirmed | slot 6 of CProvince and CMapProvince: the +0x370 intel bytes, 0 or 9 by fog of war |
| 0x28A0A0 | RebuildConvoyIndexes | new | inferred | per-province and per-area convoy vectors; Enter (both kinds of game), and hourly and daily |
| 0x283FD0 | ValidateProvinceData | new | inferred | logs IC / naval base / owner-controller inconsistencies; both kinds of game |
| 0x62E20 | GameStrategicWarfare_SetUpForNewGame | new | inferred | gives +0xD68 the player's tag; new game only |
| 0x309C90 | CGameSetup::Update | new | inferred | slot 4 of the lobby, and the three load arms |
| 0x317880 | CGameSetup_SyncOptionsFromGameState | new | inferred | copies difficulty, arcade mode and automation from the loaded state into the lobby |
| 0x303BF0 | CSavegameItem::CSavegameItem | new | inferred | the lobby's save-list row (no_signature); the only reader of a save's header, reading positionally |

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| CGameState | 0xBE0 | start_tick | int | new |
| CCurrentGameState | 0xBE0 | start_tick | int | new |
| CGameState | 0xD58 | battle_plans | void* | new |
| CCurrentGameState | 0xD58 | battle_plans | void* | new |
| CBuilding | 0x98 | provinces_built | int | new |

Vftable slots: CFrontEnd 64, CProvince/CMapProvince 6, CGameSetup 4, CGameState/CCurrentGameState 4 (LoadKey),
CInGameIdler 3 (a repeat of the existing record). *Left for later*: `CSetRandomSeed::LoadKey` (`0x2D7D40`) has `seed`
(0x356 -> +0x3C) beside `count` (0x3A0 -> +0x40), where the record lists only `count`.

### A.1 The entry points, and the file

**Three ways in**, all from the front end; the in-game screen never loads a save [exe]:

- **The lobby, `CGameSetup` slot 4** (rva `0x309C90`, "CGameSetup::Update", the name inferred). All three arms run while a
  load is pending (CGameSetup +0x6C4, inferred), each clearing the byte `0x1A857BF` around the parse. Which arm is single
  player rests on session +0x34 meaning "server", not read.
  1. **The server** (a single-player game, or a multiplayer host): at `0x70B08B` `LoadSaveFile(state, "save games/" +
     name)`, or `mod/<mod>/save games/<name>` while a mod is active [mod: the active mod's name], once every client's
     transfer reports done and only while +0x6C5 ("loaded") is clear; then the lobby lines `SAVE_TRANSFER_DONE` and
     `SAVE_LOADED`.
  2. **A multiplayer client whose own file matches the transfer** (same name, transfer +0xB0 equal to +0x6B4): at
     `0x70B73C` its local copy.
  3. **Any other multiplayer client**: at `0x70BA34` it logs `Received `, calls `CGameState::LoadFromSave` straight on a
     stream over the bytes it was sent, and **writes those bytes into its own `save games/` folder**.
- **The tutorial**, `CTutorialScreen::OnTutorialButtonPressed` at `0x71D933`: it sets `tutorial_active` (+0xD9D),
  `tutorial_id` (+0xDA0) and **`player` (+0xC30) from the tutorial's own definition**, then loads `tutorial/<file>` if the
  tutorial has one, else calls `ResetGameStateToStartDate(0)` and `ExecuteHistoryToDate`.
- **So the save is loaded in the lobby, before Play** [exe]. `CFrontEnd::LaunchGame` loads nothing: it logs
  `Start-date:`/`Country:`, calls `AssignHumanControllers`, makes the `CInGameIdler` and the next screen - the same for a
  load and a new game.

**`LoadSaveFile` (rva `0x27CAE0`)** opens the path (VirtualFile_Open), reads the whole file into a byte vector, wraps it in
a stream, a Tokenizer and a CParseContext named `UNNAMED_SESSION`, and calls LoadFromSave. A catch funclet (`0x67CD77`)
opens the file again and tokenizes straight off it - *inferred* a fallback for a failed in-memory read; which exception it
catches was not read. **There is no version check, no checksum and no header test anywhere on the path** [exe]: the
bodies of LoadSaveFile, LoadFromSave and CGameState::LoadKey were read whole and none compares a version, and a save has
no version key at its top level (checked on `Germany1936_01_01_00` and `Ireland1938_08_25_03`).

### A.2 What is reset before reading, and what of the install is read again

`CGameState::LoadFromSave` (rva `0x27CE30`), in order [exe]:

1. **`CGameState::ResetSession`** - the game state object is reused, never replaced (`FINDINGS-session.md`). Its whole
   body (the decompilation cross-checked against a forward call listing): zeroes supply-network dirty,
   `loaded_from_save`, +0xC8C, the frame accumulator and the game speed; empties every resource's strategic-resource
   province list; deletes the rebel factions; runs **every province through CProvince_ResetState (twice) and every country
   through CCountry_Reset**; frees sunk ships and the last pride; frees relations; **deletes every combat**; empties the
   game state's flags; **takes every attacker and defender out of every war (no history recorded) and deletes the war**,
   emptying the active, previous and undeclared war lists; **deletes every CEU3AI** in `ai_agents` (+0x114); clears the
   three statistics objects, the fired-events registry (+0xC38) and `fired_events_loaded` (+0xC44); empties the allied
   objectives; calls MarkSimulatedProvinces(state, 0) and empties `scenario_name`; resets the selection groups; frees
   the battle plans (+0xD58); clears the strategic warfare at +0xD68. **It does not write `tick`, `start_tick` (+0xBE0),
   `player` or `in_game`** (no such displacement in `0x67BAF0`..`0x67CAA7`; a write through a register holding state+N
   would not show).
2. **The history registry at [0x1A88BC0] emptied** (HistoryDatabase_Clear): a CDiplomaticHistory, a CWarHistory, two
   collections of history containers and two CWar lists.
3. The discarded `GetApplication` call.
4. `ResetGlobalIdCounters`: the rebel, unit, convoy and theatre counters back to 1. **The leader counter (`0x130AF10`) is
   not among them.**
5. `loaded_from_save` = 1.
6. `SetInGameScreen` with the screen read at `0x27CEB2`.
7. `RebuildStrategicResourceProvinces` over the provinces the reset just emptied.
8. **The parse**: CPersistent::Load on the game state (A.3, A.4).
9. The scenario looked up by `scenario_name` - empty, so nothing, unless the save carried `scenario`.
10. `MarkSimulatedProvinces`: with no scenario, every province is simulated.
11. `RebuildStrategicResourceProvinces` and `UpdateStrategicResources`.

**What of the install is read again** [exe]:
- **read again on a load**: **the event files** - `LoadEvents` throws the list away and reads `events/` again inside
  CInGameIdler::Enter, for both kinds of game [mod: events/*.txt]; and the custom-game block at the end of Enter
  (`cgm_settings.txt`), not followed;
- **not read again**: the `common/` databases, the map and the order-of-battle files (`LoadOobFile` runs only on the
  new-game arm); **the history files are not replayed** - no call to ExecuteHistoryToDate in LoadSaveFile, LoadFromSave,
  CGameSetup slot 4's load arms or Enter;
- **objects survive the load and are filled again**: the country, province and database objects are the ones startup
  made, the save's blocks filling them in place after the reset. The game state's country list is the country
  database's, not the save's (`FINDINGS-session2.md`).

### A.3 How each top-level key is dispatched

`CPersistent::Load` on the game state calls `CGameState::LoadKey` (rva `0x27FCB0`, a token switch) for each key [exe]:

| key(s) | goes to |
| --- | --- |
| `date` | `tick` (+0xBDC) |
| `start_date` | `start_tick` (+0xBE0); never written by the maintainer's saves |
| `unit` `leader` `rebel` `theatre` `convoy` | the id counters (atoi) |
| `id` | a {id type} pair; a type in this machine's high space (0x1268 + word[0x1A857EC]) hands the id to `0x69D4B0` (section B); any other type dropped |
| `ai_seed` | reseeds the AI generator, draws = 0; absent from all saves checked |
| `flags`, `gameplaysettings` (+0xC90) [mod: a mod's gameplaysettings.txt uses the same grammar], `victory_conditions`, `diplomacy`, `combat`, `weather`, the three `*_statistics` | that object's slot 3 |
| `active_war`, `previous_war`, `undeclared_war`, `rebel_faction` | a new object, loaded and appended to its list |
| `faction` | inner keys matched by name token against the ideology groups' factions; an unmatched name dropped |
| `sunk_ships`, `fired_events`, `allied_objectives`, `selectionGroups`, `battle_plan`, `strategic_warfare` | their own readers; `fired_events` kept as id pairs until Enter |
| `scenario` | looked up and applied at once |
| `controller`, `ai`, `automate_trade`, `automate_sliders`, `automate_tech_sliders` | the local CHuman; the last four only while +0xCF4 is clear |
| **`player`** | **ignored** (`je` to the epilogue) |
| **a number** n, 1 <= n < the province count | province n's slot 3 (atoi, so `12abc` would reach province 12) |
| **any other key** | its first three letters through `CCountryDataBase::GetTag`; a tag with an id reaches countries[id]'s slot 3 |
| **anything else** - the top-level `seed` and `count` among them | **dropped silently, no message** |

So **a loaded game's random generator is not restored from the save** (*inferred* from `seed` and `count` being
dropped), and **the played country is never taken from the save** [exe].

### A.4 When the AfterLoads run, and what a parse error does

`CPersistent::Load` (rva `0x67C050`) [exe]: **each object's slot 5 (AfterLoad) runs at the close of its own block**, after
its last key - a child's before its parent's (a brigade's before its unit's, a unit's before its country's). **There is
no pass afterwards**: the game state's own slot 5 is the empty stub. Blocks a LoadKey reads by its own loop get no
AfterLoad from it: a faction matched by name, `sunk_ships`, `fired_events`, `strategic_warfare`, `battle_plan`. **Where the
parse context holds a message** as a block closes, it logs `persistent.cpp` line 39 - `Error: "<text>" in file:
"<file>" near line: ` - frees the messages and **skips that object's AfterLoad**; later objects keep theirs. An unknown
key makes no message, so it never reaches that path.

### A.5 Everything recalculated before the first hour: loaded against new

Between the parse and the first hour, in order: LoadFromSave's tail (A.2, steps 9-11); in the lobby `RefreshAllCountries`
(each country's neighbours, the after-diplomacy rebuild and `RunIntelRefresh`), the front end's map refreshed
(`0x641D90`/`0x641D50`, or `Map_RefreshColourTextures`), and the lobby's options synced from the state; at launch
`AssignHumanControllers`, then `CInGameIdler::CInGameIdler`, which calls `CGameState::StartAI` (`0x64921B`) - **a fresh
CEU3AI for every country, loaded or not**; the save holds none - with two new-game-only branches (`0x648CD2`: `0x5F5450`
on the history registry with &tick, not read; `0x648EFD`: every active war's +0xC = tick); then `CInGameIdler::Enter`,
whose thirteen tests of `loaded_from_save` are [exe] unless marked:

| | **new game** | **loaded game** |
| --- | --- | --- |
| start_tick | = tick | kept as the object held it - the writer never saves it and ResetSession does not clear it |
| fired events | - | resolved into the registry after the events are read again (ResolveSavedFiredEvents) |
| per province, first pass (both) | modifier, latitude, climate | the same |
| strategic resources | not worked out until the first daily pass | UpdateStrategicResources (and twice already in LoadFromSave) |
| per country (both): EnsureCapital, triggered modifiers (not REB, owns land), static modifiers, rules, leadership, max manpower, IC, blockade, at-war/enemies, effective neutrality | + ActivateRankedLeaders | active leaders from the save; UpdateAtWarAndEnemies given `suppressDemobilise` = 1, so **a country mobilised at peace is not demobilised** |
| per-country set-up | laws and technology for the start [mod: technologies, laws], `LoadOobFile` [mod: history/units], SetUpCountryForNewGame, unit totals, IC shares, officers, the build queue priced again, history threat spread | **only CCountry::UpdateManpowerAfterMobilising** |
| units | named, starting experience [mod: modifiers 52/77 from technologies/laws] | intel level, avatar, ShowMoving, EnterProvince |
| units (both) | parent relink, trespass marks, combat markers | the same |
| combats (both) | each side's combat modifiers applied again | the same |
| per province, second pass | night flag; **temperature seeded at its target**; modifier; **the history `revolt` carried out** (SpawnFullRevoltInProvince); a fix-up of REB-owned provinces (not read) | night flag from the saved tick; modifier only; the save's weather kept |
| per country, after "information caches" (both) | neighbours, after-diplomacy, static modifiers, the 6+4 distributions, research; **CAIStrategy::Rebuild only where the strategy is neither `initialized` nor `static`** | the same; a saved strategy (`initialized=yes`) kept |
| supply (both) | PickDepot for every supply group, depots for provinces still at 0, RebuildSupplyNetwork | the same |
| **the block at `0x65C7F0`** | RebuildStrategicResourceProvinces, **the weather pre-roll** (INITIAL_SIMULATION_HOURS_AHEAD [mod: defines.lua]; not in a tutorial), AllocateProvinceIntelArrays, **the first RunDailyPass, RunSupplyAndConvoyIterations (the filling, the second day, the month, the hour)** | **skipped entirely**; RecountBuildingProvinces instead |
| after (both) | RebuildConvoyIndexes, RemoveLandlessCountriesFromWars, neighbours and after-diplomacy again | the same, + CAIStrategy::RefreshTheatreProvinces(strategy, 1) and every theatre's StampProvinces and RebuildAreas |
| strategic warfare | bound to the player's tag | kept as the save's block names it, even if the lobby picks another country (*inferred*) |
| end (both) | RunIntelRefresh, units entered again, ValidateProvinceData (logs only; whether it also corrects was not read), `in_game` = 1 | the same, + **one `ProcessAI` for every country with a CEU3AI unless multiplayer**, after clearing every country's `theatres_dirty`; + battle plans handed to the CBattlePlanManager |

**So a loaded game's first hour is simply the hour after `date`.** Nothing runs in place of the two days but the
re-derivations above and one AI pass.

### A.6 The played country, the lobby, multiplayer

The played country is set by the `CSetCountryControllerCommand` the lobby posts, whose Execute (slot 6, VA `0x6D3390`)
writes `player` and `played_countries` [exe]; the tutorial writes `player` directly. **The only reader of a save's
`player` is the lobby's list row**, `CSavegameItem::CSavegameItem`, which reads positionally [exe]: the first pair's value
is taken as the date, whatever its key; a second pair `scenario` is looked up; the next pair, if it is `player`, gives the
shield. **So an OpenHOI3 writer must put `date` first and `player` second** (third after `scenario`), or the original's
list shows a wrong date or no shield. How the lobby defaults its selection to that row's tag was not read.

### A.7 Errors

An exception while the file is parsed is caught in LoadFromSave: it logs `gamestate.cpp:570` on channel 0x10004, `Failed
to load save file File exception: <text>`, and returns - **the scenario, the simulation marking and the strategic
resources are skipped, `loaded_from_save` stays 1, and the caller is not told**. Parse messages cost only the open
object its AfterLoad (A.4); unknown keys are silent (A.3); there is no version check (A.1).

### A.8 Not established

- Whether the install's history containers live in the registry LoadFromSave empties: ResetGameStateToStartDate also
  clears it and then replays history, which does not fit; not resolved.
- `0x5F5450`, `0x28BA80`, `0x408AF0`, `0x641D90`/`0x641D50`, `0x68A6B0` (the `ai` arm).
- What session +0x34 and CGameSetup +0x6C4 really are.
- Whether a loaded game starts paused.
- Lua on the load path: not looked for.
- Who reads +0xBE0: a scan of game-state loads found only Enter's write; a `this`-register reader would not show.
- `CAIStrategy`'s `rebuild_tick` (+0x10) is not a save key, so a loaded strategy's ten-day clock starts from whatever the
  object holds (*inferred*).

### A.9 For an OpenHOI3 loader

**Run after reading a save, in order:**
1. Reset the whole session - countries, provinces, wars, combats, AI objects, flags, statistics, the fired-event
   registry, selection groups, battle plans, strategic warfare; the rebel, unit, convoy and theatre counters to 1; the
   clock, start_tick and the leader counter left as they were; the recorded history emptied.
2. Parse with A.3's dispatch, each object finished (its AfterLoad) as its block closes.
3. The scenario (none for an ordinary save), then the strategic-resource provinces and levels.
4. The played country chosen outside the save (the lobby); every country's neighbours and intelligence made again.
5. A fresh AI object for each country.
6. The event files read again, then the saved fired events resolved.
7. A.5's "both" and "loaded" rows, in that order - ending with intelligence, one AI pass for each country (single
   player) and the battle plans.

**Must not, on a load**: run the two days, the filling, the month or the first hour; pre-roll the weather or seed
temperatures; read the order-of-battle files, move laws, buy technology or price the build queue again; activate ranked
leaders, name units or give starting experience; carry out history revolts, or replay history at all; set start_tick, or
set up the strategic warfare for the player; demobilise a mobilised country at peace; take the played country from
`player`, or restore the generator from `seed`/`count` - the original does neither; stop or warn on an unknown key, a
province number out of range, or a tag that is no country - the original drops each silently. Being stricter and
reporting them is OpenHOI3's choice.

## B. The top level and the id scheme

*Reader B. Read 2026-11-04, statically, and set against all 33 saves in the maintainer's `save games` folder.
Addresses are VAs unless marked rva. **[exe]** is hardcoded in the executable, **[mod: file]** a file may change it.*

**Synopsis.** The aim was how a save's top level is written and how ids work across a save; both are settled.
`CGameState::SaveContents` (rva `0x27E6F0`) is read whole, and every top-level key's order, source and gate agrees with
all 33 of the maintainer's saves. The id scheme has two halves: four fixed-type serial counters the save carries
(`rebel` type 39, `convoy` 42, `theatre` 45, `unit` 41), and a per-peer "high" id space - fresh ids minted in type
0x1268 + peer number (4713 in single player) and kept across a load through the `id` blocks. **Corrected rather than
added**: `WAVE.md`'s list put the country and province blocks after `strategic_warfare`; they sit **between
`fired_events` and `sunk_ships`**, provinces first (1..14168 ascending), then countries in `common/countries.txt`'s order
(REB..VEN). `FINDINGS-save.md`'s two open items are closed: the CSaveWriter is built on the stack by both writers, and
its +0x0 is the vftable at VA `0x15FD940`. And `CGameState` +0xAEC, +0xB24 and +0xC90 are **embedded objects, not
pointers** - flagged, not changed in the record.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| 0x27E6F0 | CGameState::SaveContents | new | confirmed | the whole top level in order, with every gate |
| 0x69D410 | PersistentIds_CollectHighest | new | confirmed | fills 0x1267 {type 0x1268+i, highest serial} slots from both id registries |
| 0x69D3D0 | PersistentIds_NoteHighest | new | confirmed | one object's step: keeps the larger serial per high type |
| 0x69D4B0 | PersistentIds_SetSpace | new | confirmed | sets the minting type offset (DI) and serial (ECX); called by startup (1,0), the MP connect handler (peer id,0), a lazy init and LoadKey's `id` arm |
| 0x6789F0 | SaveWriteIdPair | new | confirmed | writes `{ id=N type=T }`; memory order is {type, serial} |
| 0x608D0 | SaveWriteIntVector | new | confirmed | `key={ a b c }`, writes nothing when the vector is empty |
| 0x678AF0 | SaveWriteNamedObject | new | confirmed | string key `=` object->Save (country tags, dates, sunk ships) |
| 0x2FC00 | CCombatManager::SaveContents | new | confirmed | each live battle under its own token, then `history` |
| 0x16E210 | CCombat::SaveContents | new | confirmed | location, day, duration, attacker, defender, terrain (7 combat classes) |
| 0x2FAB0 | CCombatHistory::SaveContents | new | confirmed | `history={ {entry} ... }` through 0x33FE0 |
| 0x2F410 | CCombatHistoryEntry::SaveContents | new | confirmed | location, attacker, defender, end_date, convoy?, type |
| 0x64EC90 | CWar::SaveContents | new | confirmed | name, limited, attacker*, defender*, revolutionary_war?, action, original_*, war_goal* |
| 0x75E70 | CUndeclaredWar::SaveContents | new | inferred | attacker*, defender*, region* (no save to check against) |
| 0x1F3B10 | CGraphStatistics::SaveContents | new | confirmed | one `ledger_data` per 0x44-byte item |
| 0x1F35F0 | SGraphStatisticsItem::SaveContents | new | confirmed | ledger_data_y, ledger_data_x, name |
| 0x123400 | CFaction::SaveContents | new | confirmed | progress, then one `country` per member (also CNullFaction) |
| 0x144AA0 | CVictoryConditionManager::SaveContents | new | inferred | `faction={ name date ... factionname }` per faction, then game_finished |
| 0x28A5E0 | CGamePlaySettings::SaveContents | new | confirmed | `setgameplayoptions={ ... }` |
| 0xB91C0 | CRebelFaction::SaveContents | new | inferred | id, type, name, country, target*, independence, government, province, army*, provinces |
| 0x28D180 | CSelectionGroupWriter::SaveContents | new | inferred | tag, then each non-empty group; read back by CSelectionGroupReader |
| 0x130B20 | CStrategicWarfare::SaveContents | new | confirmed | a country's alliance / convoy / ground_bombing lists |
| 0x65330 | GameStrategicWarfare_SaveContents | new | inferred | the top-level `strategic_warfare`: player, count, entries; the class is unknown |
| 0x47C0 | BattlePlan_Serialize | new | inferred | one battle plan (title, country, arrows, icons, texts, borders...) |
| 0x4D740 | CFlags::SaveContents | new | confirmed | at CFlags@0x24: tree walk, `name=yes` only for set flags, sorted |
| 0x4D760 | CFlags::LoadKey | new | confirmed | every key is a flag name; the value is `yes` or not |
| 0x77060 | CVariables::SaveContents | new | confirmed | at CVariables@0x24 -> SaveSubtree (named before only in prose) |
| 0x77080 | CVariables::LoadKey | new | confirmed | every key is a variable name; the value is fixed-point |
| 0x123BB0 | CGoodsPool::SaveContents | new | confirmed | the seven goods in order, each left out when zero |
| 0x132430 | CTechnologyStatus::SaveContents | new | confirmed | every technology `name={level progress(5dp) leadership}` in database order |
| 0x132230 | CTechnologyStatus::LoadKey | new | inferred | its loader; progress capped at 0x8000 |
| 0x5B8C0 | CTimedModifier::SaveContents | new | confirmed | modifier, date |
| 0x5C7BE0 | CActiveMission::SaveContents | new | confirmed | type, scope, parent_scope, start_date, owner? |
| 0x1FCDA0 | CHistoryContainer::SaveContents | new | inferred | history entries, dated ones under their date (CProvinceHistory/CCountryHistory slot 2) |

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| CSaveWriter | 0xD | owns_stream | bool | new |
| CGameState | 0x60 | humans | CHuman* | new |
| CCurrentGameState | 0x60 | humans | CHuman* | new |
| CGameState | 0xCE4 | factions_first | void* | new |
| CCurrentGameState | 0xCE4 | factions_first | void* | new |

vftable_slots for every holder, including `CFlags@0x24` and `CVariables@0x24`.

**Flagged, not in the fragment**: (a) `CGameState`/`CCurrentGameState` +0xAEC `weather`, +0xB24 `diplomacy` and +0xC90
`gameplay_settings` are recorded as `void*`; the writer calls them as `mov eax,[esi+0xAEC]; mov edx,[eax+4]; lea
ecx,[esi+0xAEC]; call edx`, so each is an **embedded** object (CWeatherManager, CDiplomacy, CGamePlaySettings) - not
retyped, neither CDiplomacy nor CGamePlaySettings having a recorded size. (b) The `CGameState +0xD40` comment says the
array is "indexed by the group's own id"; the writer indexes it by **country index**, 0xA0 bytes a country holding 10
groups of 0x10.

### B.1 How a save starts

Both writers - `SaveGameFromDialog` (rva `0x271370`) and the autosave writer (rva `0x24FF80`) - do the same [exe]: open a
0x3C-byte file object through VirtualFile_Open and give it a 1 MiB write buffer; build a `CSaveWriter` on the stack
(vftable VA `0x15FD940` at +0, depth +4, the stream +8, binary +0xC taken from the stream's +0x13 - text in both -,
owns_stream +0xD = 1); set depth to **-1** and call the game state's slot 1, `CPersistent::Save`; delete the stream,
which closes the file. This settles `FINDINGS-save.md`'s "where a CSaveWriter is constructed" and its "+0x0 unsettled":
+0x0 is the vftable, and nothing writes `mov [reg+4],-1` because depth is set on a stack local. With depth -1,
`SaveBeginBlock` writes no brace for the root: the top-level keys stand at column 0, and the file ends with the known
single surplus `}` [exe].

### B.2 The top level, in order

From `CGameState::SaveContents`, rva `0x27E6F0`, slot 2 of CGameState and CCurrentGameState. Every key is [exe].

1. `date`: the tick (+0xBDC) as a date string.
2. `scenario`: the string at +8 of [+0xD0C], **only when +0xD0C is set**. None of the 33 saves has it.
3. `player`: the tag at +0xC30, quoted.
4. **Only when the in-game screen's +0x68 (multiplayer) is clear**, the local player's CHuman (GetLocalPlayer inlined:
   the chain at +0x60 linked on +0x54, matched on +0x1C against in_game_screen slot 18's +0x6C, falling back to the
   CHuman at +0x70): `ai`, the seven automation flags with element 5 replaced by CHuman +0x48, through
   SaveWriteIntVector; `automate_trade` (yes/no), `automate_sliders`, `automate_tech_sliders`. **So a multiplayer save
   carries none of these four.**
5. `rebel`, `convoy`, `theatre`, `unit`: the four next-id counters as plain ints (g_rebel_id, g_convoy_id,
   g_theatre_id, g_unit_id).
6. `flags`: the CFlags at +0xC4, its CPersistent part at +0xE8.
7. `gameplaysettings`: the embedded CGamePlaySettings at +0xC90.
8. `victory_conditions`: the object at [+0xD08].
9. `seed` (g_random_seed), then `count` (g_random_draws).
10. `id`: zero or more `id={ id=N type=T }` blocks (B.3).
11. `rebel_faction`: one per CRebelFaction in the list at +0xC7C.
12. `fired_events={ id={...} ... }`: the fire_only_once registry, bucket order - empty in every save of the
    maintainer's.
13. **Every province**: for each entry of the vector at +0xB8C in vector order whose id (+0xD0) is not 0, `<id>=` and its
    Save; index 0, a placeholder, skipped. The saves run 1..14168 ascending.
14. **Every country**: index 1 to GetCountryCount()-1, as `<tag>={...}` through SaveWriteNamedObject; **index 0 skipped** -
    the null country `---`, which shows as the first `ledger_data` name in nation_size_statistics. The order is the
    countries vector's, which is `common/countries.txt`'s [mod: common/countries.txt]: REB, GER, ENG ... VEN - checked
    for all 101 tags in two saves.
15. `sunk_ships={ <ownertag>={ship} ... }`: the list at +0x20, each ship under its own owner's tag (CSubUnit +0x94).
16. `weather`: the embedded CWeatherManager at +0xAEC.
17. `faction={` written as raw tokens with no newline and no depth change; then for each CFaction in the list at +0xCE4
    whose name token (+0xB8) is set, `<name>={...}`; then `}`. That is why a save shows `faction={axis=` on one line
    with the factions at column 0.
18. `diplomacy` (embedded at +0xB24), then `combat` (the embedded CCombatManager at +0xB5C).
19. `active_war`: one per CWar in the list at +0xC00; then `previous_war`: one per node of +0xC20; then
    `undeclared_war`: one per node of +0xC10 - **after** previous_war, though its field sits between the other two.
20. `income_statistics`, `nation_size_statistics`, `inflation_statistics`: the CGraphStatistics at [+0xC6C], [+0xC70],
    [+0xC74].
21. `allied_objectives`: triples (province, q, country index) out of +0xB9C; absent when empty.
22. `selectionGroups`: one per country index with any non-empty group among its ten at +0xD40 + index x 0xA0, written
    through a throwaway CSelectionGroupWriter (vftable VA `0x15CF694`).
23. `strategic_warfare={ player=.. count=N ... }`: GameStrategicWarfare_SaveContents on [+0xD68].
24. `battle_plan={...}`: one per plan, **only while the in-game screen's +0x1DE8 is set**, per country.

**Written only sometimes**: `scenario`, the four CHuman keys, `rebel_faction`, the `id` blocks, `undeclared_war`,
`allied_objectives`, `selectionGroups`, `battle_plan`, and any number of wars. **Never written**, though
CGameState::LoadKey reads them: `ai_seed`, `controller`, `leader`, `start_date` - from the function's complete list of
key immediates, which holds every key the 33 saves hold, the positive control. **Against the saves**: all 33 share one
key sequence, differing only in the number of `active_war` blocks (1-4) and the `previous_war` count (2).

**Two writer quirks a byte-faithful writer needs** [exe]: a country's `organization=` and `popularity=` come out at
column 0; `faction={axis=` is on one line.

### B.3 The id scheme

**What `type` names.** An id is a pair {type, serial}: in memory the type comes first, in a save the serial is written
first. The type numbers [exe]:

| type | names | where checked |
| --- | --- | --- |
| 37 (0x25) | leaders | FindPersistentById's comment |
| 39 (0x27) | rebel factions | the minting site at VA `0x4BAB31`, g_rebel_id |
| 40 (0x28) | events | CReferenceObject::SetId's comment |
| 41 (0x29) | units and sub-units made from history, and their military constructions | VA `0x5A9188`, g_unit_id |
| 42 | convoys | g_convoy_id; read off the saves, so inferred |
| 45 (0x2D) | theatres | VA `0x8AA168`, g_theatre_id |
| 4712 + n | anything minted in play by peer n | 4713 in single player |

In the saves 4713 shows on new regiments, armies, corps, constructions and deployments. The `type` keys with values 0-5
are something else - `combat` history kinds and trade and patrol keys, not ids.

**The fixed counters.** The four top-level counters each hold the **next** serial for their type. The new-game reset at
rva `0x23A330` sets them to 1, which is why every save of the maintainer's has `rebel=1`. Loading an object that has an
id raises the counter to id+1 (shown for sub-units at VA `0x5A914D`-`0x5A9159`), so the counter in the save and the
objects agree. The start save has `convoy=262` with 261 convoys [exe].

**The high id space.** `CReferenceObject::AssignNewId` mints {0x1268 + word[0x1A857EC], ++[0x1A857F8]}.
PersistentIds_SetSpace decides the offset [exe]: WinMain's startup sets offset 1 and serial 0; the multiplayer handler
that names 'CONNECTED' sets the session's local id, so **each peer mints in its own type and two peers cannot collide**;
a lazy initialiser sets 0.

**How the save keeps it.** PersistentIds_CollectHighest records, for every high type, the largest serial among all
registered objects; SaveContents then raises it with each military construction's not-yet-registered pending ids (the
line's +0x58/+0x5C and each brigade's +0x10/+0x14; CConstruction slot 17 is true only for CMilitaryConstruction). Every
non-zero entry is written in ascending type, so a single-player save has exactly one `id` block, type 4713.

**How a load keeps new ids from colliding.** CGameState::LoadKey's `id` arm (VA `0x67FD44`-`0x67FD79`) calls SetSpace with
the saved serial **only for the pair whose type is this machine's own minting type**, so the next fresh id is serial+1;
pairs of other types are ignored. A pair that collides on load is minted again by SetId (recorded) [exe]. *Inferred, not
checked*: a multiplayer save loaded by a peer whose local id differs from the writer's restores no counter for its own
type, and its serials restart from 0.

### B.4 Census: blocks outside the unit tree

"before" is already in `project.json` before this fragment; "new" added by it.

| block | where | class | SaveContents | LoadKey |
| --- | --- | --- | --- | --- |
| flags | top / country / province | CFlags@0x24 | 0x4D740 new | 0x4D760 new |
| variables | country | CVariables@0x24 | 0x77060 new | 0x77080 new |
| gameplaysettings | top | CGamePlaySettings | 0x28A5E0 new | 0x28A550 before |
| victory_conditions | top | CVictoryConditionManager | 0x144AA0 new | 0x144920 before |
| id, fired_events | top | inline + SaveWriteIdPair | in CGameState::SaveContents | CGameState::LoadKey 0x27FCB0 before |
| rebel_faction | top | CRebelFaction | 0xB91C0 new | 0xB9420 before |
| `<id>=` | top | CProvince | 0x95020 before | 0x95880 before |
| `<tag>=` | top | CCountry | 0xCFCE0 before | 0xCCDA0 before |
| sunk_ships entries | top | CShip (section C) | VA 0x5ADD30 not recorded here | 0x1ADBF0 before |
| weather | top | CWeatherManager | 0xB5F60 before | 0xB5FA0 before |
| faction entries | top | CFaction / CNullFaction | 0x123400 new | 0x1227E0 before |
| diplomacy | top | CDiplomacy | 0x60DB60 before | 0x60D5C0 before |
| combat | top | CCombatManager | 0x2FC00 new | 0x2FC60 before |
| combat: live battle | combat | CCombat family | 0x16E210 new | 0x16E0B0 before |
| combat: history | combat | CCombatHistory / CCombatHistoryEntry | 0x2FAB0 / 0x2F410 new | 0x2FAD0 / 0x2F5F0 before |
| active_war, previous_war | top | CWar | 0x64EC90 new | 0x64E610 before |
| undeclared_war | top | CUndeclaredWar | 0x75E70 new | 0x75A60 before |
| *_statistics, ledger_data | top | CGraphStatistics / SGraphStatisticsItem | 0x1F3B10 / 0x1F35F0 new | 0x1F3A70 / 0x1F35A0 before |
| allied_objectives, ai | top | int vector | SaveWriteIntVector 0x608D0 new | LoadKey inline |
| selectionGroups | top | CSelectionGroupWriter | 0x28D180 new | CSelectionGroupReader::LoadKey 0x28CFA0 before |
| strategic_warfare | top | object at +0xD68 (class unknown) | 0x65330 new | not read |
| battle_plan | top | battle plan | 0x47C0 new | not read |
| strategic_warfare | country | CStrategicWarfare | 0x130B20 new | 0x1309B0 before |
| pool, home, usage, to, back, convoyed_out, traded_* (country); pool, throughput, last_throughput, drawn, last_drawn, current_producing, max_producing (province) | country / province | CGoodsPool | 0x123BB0 new | ReadSave 0x123A90 before |
| technology | country | CTechnologyStatus | 0x132430 new | 0x132230 new |
| organization, popularity | country | CIdeologyData | 0x128520 before | 0x128540 before |
| modifier | country / province | CTimedModifier | 0x5B8C0 new | 0x5B7F0 before |
| `<tag>=` | country | CDiplomacyStatus (one per other country that **owns at least one province**, its own tag included, so REB never appears) | 0x648430 before | 0x648190 before |
| ministers | country | CCountry_SaveMinisterIds | 0xF0B70 before | (LoadPossibleMinisterIds) |
| active_mission | country | CActiveMission | 0x5C7BE0 new | 0x5C7A20 before |
| ai_hard_strategy, ai_event_strategy, ai | country | CAIStrategy | 0x4A4860 before | 0x4A40B0 before |
| alignment | country | CAlignment | 0xC31E0 before | 0xC31B0 before |
| convoy | country | CConvoy | 0xC5600 before | 0xC5320 before |
| history | province | CProvinceHistory (CHistoryContainer) | 0x1FCDA0 new | 0x1FCC10 before |
| weather | province | CWeather | 0xB1FF0 before | 0xB20C0 before |
| distribution, leadership | country | five-decimal list writer 0x10FD70 | not recorded | inline |
| slider_locks, spy_priority, spy_mission, cabinet, shared_technologies, lendlease_targets, lend_lease_from, lend_lease_from_yesterday | country | int vectors | 0x608D0 new | inline |
| spy_allocation, covert_ops_points, lendlease_distributions, lendlease_effectiveness, lend_lease_from_values, lend_lease_from_yesterday_values, spy_date, historical_friends | country | list writers 0xC8050 / 0x10FEE0 | not recorded | inline |

The unit tree's blocks are section C's: theatre and below, the queue lines, active_leaders, saved_templates and
unit_deployment.

**A country block's key order**, from CCountry::SaveContents's own key immediates [exe]:
- **start**: `human=yes` (only for a played country), flags, variables, capital, acting_capital, government_in_exile
  (only when set), strategic_warfare;
- **goods pools**: pool, home, usage, to, back, convoyed_out, traded_for, traded_for_sans_allied, traded_away,
  traded_away_sans_allied;
- **battles and technology**: land/air/naval_battles_fought (each only when above 0), technology, one
  `<category>=<level>` per technology category, research (one per queued technology);
- **dates and figures**: last_election, last_surrender, election, duration, remove_fow (one per entry),
  last_rebel_acceptance (only when more than a year old), war_exhaustion, diplo_influence, spiescaught;
- **politics**: distribution, leadership, organization, popularity, neutrality, officers, government, one key per filled
  post, one per law group, ideology, modifier (one per active modifier);
- **military**: manpower, nukes, the construction lines, the four auto_* flags, active_leaders, the unit tree, the
  `<tag>` diplomacy statuses, ministers, saved_templates;
- **missions and AI**: active_mission, last_mission_cancel, last_mission (conditional), ai_hard_strategy,
  ai_event_strategy, ai, slider_locks, historical_friends;
- **end**: mobilize (only when set), alignment, dissent, national_unity, escorts, convoys, convoy (one per convoy), spies,
  the spy_* keys, covert_ops_points, cabinet, prov_vp, offmap_vp, shared_technologies, the lend-lease keys,
  lend_lease_income, lend_lease_income_yesterday, effective_neutrality, highest_threat.

**A province block's key order** is in CProvince::SaveContents's record (rva `0x95020`); the Ireland 1938 save agrees,
the building keys between strategic_resource and history.

### B.5 Not settled

- The class at CGameState +0xD68, and what its strategic_warfare entries are.
- The order of CUndeclaredWar's three loops.
- CRebelFaction's and selectionGroups' key order: no save of the maintainer's has them.
- The second `type=` inside a combat history entry in the Ireland 1938 save; read 0x33FE0's trailing word token first.
- Which setting each number of `setgameplayoptions` is.
- Whether a victory condition's date is the date it was met.
- The keys inside non-empty country strategic_warfare lists.
- Frontier, not named: 0x33FE0, 0x28DC70, 0x626F0, 0x10FD70 (the five-decimal list writer, used for `distribution` and
  `leadership`), 0x10FEE0 (the word-pair list writer), 0xC8050, 0xA810, 0x130B60, 0x28A650, 0x4D6E0 (the flag tree
  walk), 0x69D630, 0x69D930, and the 'CONNECTED' handler at VA `0x708190`.

## C. The unit tree and the country's military blocks

*Reader C. Read 2026-11-04, statically, and set against seven of the maintainer's saves - about 14,000 unit blocks,
29,400 brigade blocks, 24,441 active-leader entries, 651 military lines and 707 template blocks. Offsets are the objects'
own; CUnit, CArmy, CNavy and CAir keep their CPersistent at +8, so the code reads every unit field at "offset - 8" from
`this`. **[exe]** is hardcoded in the executable, **[mod: file]** a file may change it.*

**Synopsis.** The aim was how the original writes and reads the military part of a save - every unit level, brigade,
order and mission, the active leaders, the production and deployment lines and the saved templates. The writer, the
loader and the AfterLoad are settled for all of them, and the key order agrees with seven saves. **Corrected rather than
added**: `COrder::LoadKey` has a ninth key, `death_date` (switchmap.py stops before it and picks up two false cases from
the next function); **a leader's history is never saved** - the `CLeaderHistory::SaveContents` comment said it was written
whole on every save; `CMilitaryConstruction::LoadKey` reads its brigade lines as sub-unit type names, where the record
said anything else was dropped; `CUnit::LoadKey` reads orders and missions through its default case (`CreateOrder`) and
deletes any unit block with no `location`; and `CUnit::AfterLoad`'s "fixes up the rest" is spelled out.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| 0x1B8170 | CUnit::SaveContents | new | confirmed | the common body of every unit block: key order, when each key is written, and where children, carried units and carriers go |
| 0x1D06B0 | CAir::SaveContents | new | confirmed | CUnit's keys, then the land units the air unit carries, each under its level key |
| 0x1A92A0 | CSubUnit::SaveContents | new | confirmed | the regiment/ship/wing block; never writes `historical_model` |
| 0x1ADD30 | CShip::SaveContents | new | confirmed | sub-unit keys plus `air` for each of a carrier's air groups (the only place they are written) |
| 0x17FDB0 | CLeader::SaveContents | new | confirmed | rank, skill (only if changed), current_experience (15-bit fixed), gainable_trait, trait |
| 0x187530 | COrder::SaveContents | new | confirmed | province, target, stance, start_date, death_date, return_to_base, time, priority, stop |
| 0x19AEE0 | CNavalOrder::SaveContents | new | confirmed | COrder's keys, then its own return_to_base/priority (so they appear twice), capital, sub_unit, other |
| 0x19B620 | CRebaseOrder::SaveContents | new | confirmed | thunk to CNavalOrder's; also used by CReserveOrder and CNavalTransportOrder |
| 0x19C9F0 | CPatrolOrder::SaveContents | new | confirmed | `provinces` is an {id type} reference to the shadowed fleet, always written |
| 0x1A0320 | CConvoyRaid::SaveContents | new | confirmed | naval order plus `attack` (int at +0x4C) |
| 0x19FD70 | CConvoyEscortOrder::SaveContents | new | confirmed | naval order plus province, direction, convoy |
| 0x19E130 | CNavalInterceptOrder::SaveContents | new | confirmed | resolves and caches its target, writes `provinces` {id type} only if it resolves |
| 0x19E920 | CNavalSortieOrder::SaveContents | new | confirmed | naval order plus start, one provinces line each, current |
| 0x19BF70 | CJoinFleetOrder::SaveContents | new | confirmed | naval order plus `join_fleet` {id type} |
| 0x189CD0 | CAirOrder::SaveContents | new | confirmed | COrder's keys, return_to_base and priority again, provinces lines, one `<air type>=N.000` per air type |
| 0x1964A0 | CAirReserveOrder::SaveContents | new | confirmed | thunk to CAirOrder's |
| 0x197E30 | CJoinAirOrder::SaveContents | new | confirmed | air order plus a second `target` |
| 0x193A80 | CRebaseToCarrierMission::SaveContents | new | confirmed | air order plus `carrier_target` |
| 0x190880 | CParadropMission::SaveContents | new | confirmed | writes `message` before the air order's keys |
| 0x195240 | CNukeMission::SaveContents | new | confirmed | air order plus `nukes` |
| 0x1953A0 | CTransportSuppliesOrder::SaveContents | new | confirmed | air order plus `supplies`, `fuel` |
| 0x4DF160 | CUnitPlan::SaveContents | new | confirmed | the `plan` block's key order and which keys are optional |
| 0x843F0 | CMilitaryConstruction::SaveContents | new | confirmed | shared line keys, then name, unit, manpower, target, is_reserve+factor, brigades, accumulated_* |
| 0x83080 | CBrigadeConstructionDefinition::SaveContents | new | confirmed | id, name, model, experience, upgrading_from_subunit(_str) |
| 0x17E3C0 | CUnitDeployment::SaveContents | new | confirmed | id, then the one unit, which has no location |
| 0x82A30 | CUnitDeployment::GetType | new | confirmed | slot 8, returns the `unit_deployment` token |
| 0x17EEA0 | CBuildingDeployment::SaveContents | new | confirmed | id, building |
| 0x17EFD0 | CDivisionTemplate::Save | new | confirmed | slot 1 override: a block of bare type names at column 0 |
| 0x17F0A0 | CDivisionTemplate::Load | new | confirmed | slot 3 override: bare words looked up as types, unknown ones dropped |
| 0x1D3660 | CUnit::HasDescendant | new | confirmed | recursive subtree test; used only by the two save writers |
| 0x1B9650 | CUnit_SaveTokenForOobLevel | new | confirmed | unit level to block key (the inverse of CUnit_OobLevelForToken) |
| 0xA810 | SaveWriteIntList | new | confirmed | `key={ a b }`, nothing at all for an empty list (path, path2, model) |
| 0xA3C0 | ParseIntList | new | inferred | reads `{ a b }` into a CList<int>; whether it clears the list first was not read |
| 0x67B5A0 | ParseLongFloat | new | confirmed | reads a 64-bit 15-bit fixed value (leader current_experience) |
| 0xD2740 | CCountry_CopyDefaultTemplates | new | confirmed | copies default templates and pads to 12 with `PW_TEMPLATE_n` |
| 0x103660 | CCountry_LoadTemplates | new | confirmed | reads `name={types}` entries into a template vector |
| 0x17D270 | AfterLoad_KeepLoadedId | new | confirmed | six-instruction AfterLoad folded across 5 tables; named for no class on purpose (`slots_noted`) |
| 0x186FE0 | COrder::LoadKey | revised | confirmed | was 8 keys; now 9 with `death_date`, plus where each key lands |
| 0x1B80D0 | CUnit::AfterLoad | revised | confirmed | adds what it does where a location exists: definition rebuild, clear +0x48, avatar rebuild, EnterProvince again, CheckBase |
| 0x1B6E90 | CUnit::LoadKey | revised | confirmed | adds: default case to CreateOrder, child units deleted without a location, sub-unit naming, location checks |
| 0x840C0 | CMilitaryConstruction::LoadKey | revised | confirmed | adds: a sub-unit type name as a key builds a brigade definition |
| 0x1D0520 | CAir::LoadKey | revised | confirmed | adds: land units are boarded with CAir::Board; `base` has no air-base check |
| 0x1F28E0 | CLeaderHistory::SaveContents | revised | confirmed | **corrected**: a leader's history is not written into a save |

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| CUnit | 0x48 | loading | uint8_t | new (name inferred: set by all six loaders before Load, cleared in AfterLoad) |
| CUnit | 0x49 | saved_this_pass | uint8_t | new |
| CBrigadeConstructionDefinition | 0x3C | upgrading_from_strength | int | new (meaning inferred from the key name) |

### C.1 Where it sits in a country block (CCountry::SaveContents, `0x4D124C`-`0x4D1717`)

After `nukes`, in this order [exe]:

1. **The production queue**: one list, CCountry +0xF40, in queue order, each line under its own key from its slot 10 -
   `military_construction`, `building_construction` or `convoy_construction` - so the three kinds interleave (23
   countries in two saves do: `military_construction building_construction military_construction`).
2. `auto_maintain_convoy`, `auto_supply_convoy`, `auto_resource_convoy`, `auto_assign_leaders` (+0x748-0x74B), yes/no
   every time.
3. `active_leaders = { ... }`: each leader of +0xE00, in list order, as `<id>=` and his block. **The `<id>=` is written
   with no indent, so it stands at column 0** (only SaveWriteValue is called).
4. **The units**: the flag +0x49 cleared on every unit of +0xBAC, then each unit **with no parent** (+0x1E0 null) written
   under its level's key - skipping units based on a carrier and carried land units (C.3). In practice the theatres,
   with the odd parentless fleet, air unit or division.
5. **The deployment pool**, +0x688: `unit_deployment` and `building_deployment`, the key from each entry's slot 8.
6. Section B's part: diplomacy per country (+0xE28), pending diplomatic actions (+0xF24) and `ministers`.
7. `saved_templates = { <name>={ types } ... }` from +0x148, each template under its name.

**Loading** (CCountry::LoadKey, `0xCCDA0`):
- **units at country level** (`theatre`/`armygroup`/`army`/`corps`/`division`, `navy`, `air`): the unit built, +0x48 set,
  the level taken from the key, slot 28 called with the country's interface host, the owner copied and the block read;
  with a location it goes to CCountry::AddUnit, **without one it is deleted** [exe];
- **military and building lines** are enqueued and then read; **convoy lines are read and then enqueued**. Enqueuing
  zeroes the line's location and stamps the country;
- **deployments** are read and passed to CCountry_AddDeployment;
- `active_leaders` loops over `<id>=` entries until `}`: the leader found by `{type 0x25, id}` - he must already exist,
  leaders coming from `history/leaders` [mod: history/leaders] - his Load called and he appended to +0xE00, with no test
  for duplicates. An id that matches no leader is skipped; what that does to the parse of his block was not checked;
- `saved_templates` empties +0x148 and reads the save's templates as written. `default_templates` (the country's file
  [mod: common/countries]) is read into +0x138, then CCountry_CopyDefaultTemplates copies it into +0x148 and **pads to 12
  with empty `PW_TEMPLATE_<index>`** [exe] - why every save's block has exactly twelve entries;
- a legacy country-level `leader = { id type }` appends a leader to active_leaders; the current writer never writes it.

### C.2 A unit block (CUnit::SaveContents)

The order is fixed [exe]; bracketed keys only when the condition holds:

`id` {id type}; `name`; [`base` - air units and fleets only, when the base is a province; a carrier is not written];
[`leader` {id type=37} - when not CNullLeader]; [`previous`]; `movement_progress`; [`arrow_state` - when not 0];
[`path` {ids} - when not empty]; [`location`]; [`retreat=yes`]; [`dig_in` - when above 0]; [`attack_delay` - when above
0]; [`combat_hours` - when above 0]; `is_prioritized`, `can_reinforce`, `can_upgrade` (yes/no), `fuel`, `supplies`
(fixed); the brigades - `regiment`, `ship` or `wing`, each by its own Save; the child units (C.3); [the order, under its
own key]; [`start_date` - a date string, when not the null date]; [`disengage` + `possible_retreat` - when disengage
above 0]; [`end_date` - when not the null date]; [`track=yes` - CUnit +0x95, shadowed by a patrol]; [`was_paradropped=yes`]; [`plan` - only while the
plan is active and the unit is a corps or above; in all saves only theatres have one]; [`expeditionary_owner` +
`expeditionary_date`]; [`aggression_enabled=yes` + `aggression_setting`]; [`country_intel` { flattened (country,
duration, level) triples }]. **`is_reserve` is read but never written at unit level.**

*Corrected 2026-11-05, measured and not re-read in the bytes*: this said `start_date` and `end_date` came together and
the disengage pair after both. In every save where a unit has all four - 14 fleets in four saves of 1936 to 1941, found
by OpenHOI3's writer setting its output beside them - the pair stands **between** the two dates.

Each level's own tail: **CArmy** [`target` above 0], [`staging_province` above 0], [`parent` {id type} - only when
carried by a fleet or by air]; **CNavy** each carried unit under its level key, then `at_sea` (the after-battle wait),
always last; **CAir** each carried land unit - none in any save.

**Reading back**, CUnit::LoadKey (40 keys, the same switch as the order-of-battle files) stores each key in the field the
writer reads:
- **any key not among the 40 goes to `CreateOrder`**: one of the 33 order kinds reads its block and becomes the unit's
  order (+0xB0); an order already there is not freed;
- **a child block without `location` is deleted** [exe];
- a land child is hung under its parent only if the parent is a land unit; it is added to its owner's unit list either
  way;
- a brigade with no name gets one: a ship or wing through `CCountry::MakeSubUnitName`, a regiment `<n>. <unit name>`;
- a regiment inherits the unit's `is_reserve`;
- **`location`**: in a game not loaded from a save, an unknown province puts the unit in province 1 with an error, and
  enemy ground or under 20% infrastructure is only logged; **in a loaded game none of these checks run** (the
  `loaded_from_save` gate, +0xD9C).

**CUnit::AfterLoad**: **the id** - a block's id is kept and the global counter (`0x170AF78`) pushed past it; a unit with
no id gets the counter's next value with type 41. **Only where the unit has a location**: `RebuildDefinition(unit,
true)`, +0x48 cleared, `RebuildAvatar`, `EnterProvince` again, CheckBase (fleets and air units only).

### C.3 What goes where in the tree [exe]

Children are written in list order; a child already written (+0x49 set) is skipped. **An air group based on a carrier
is written only inside its `ship` block, as `air`, with no `base`** - all 98 in four saves are so. **A land unit carried
by a fleet or by air is written only by its carrier**, with `parent` pointing back to its land superior; on load
CNavy::LoadKey and CAir::LoadKey put it aboard (CNavy's zeroing `dig_in` and `staging_province`), and the parent link is
restored as the game is entered (`CUnit_RelinkLoadedParent`). The one exception: where the carrying fleet is in the
carried unit's own subtree (CUnit::HasDescendant), the fleet is written in the carried unit's place - else it would never
be written. Land keys inside a `navy` or `air` block always build a CArmy.

### C.4 Brigades (CSubUnit::SaveContents; CShip adds `air`)

`id`, `name`, [`home`], `type`, `organisation`, `strength`, `highest`, `experience`, [`is_reserve=yes`], [`pride=yes`],
[`current_distance` - only while in battle], [`builder`], [`sunk_by`], then one `<tech>={level progress}` line per
technology. Unit types come from [mod: units/*.txt], technologies from [mod: technologies]. **`historical_model` is never
saved**, so CSubUnit::AfterLoad skips the model and strength-cap steps for every brigade loaded from a save.

### C.5 Orders and missions [exe]

Every order writes COrder's keys: [`province`], [`target` - when not the null pair], `stance`, `start_date`,
`death_date`, `return_to_base`, `time`, `priority`, `stop`.

**Naval orders** add their own `return_to_base` and `priority` again, then `capital`, `sub_unit`, `other` (on load both
copies go into CNavalOrder's own fields). Tails: `patrol` - `provinces`, an {id type} reference to the fleet it shadows,
always written, followed by a blank line; `convoy_raid` - `attack`; `join_fleet` - `join_fleet` {id type}; `intercept` -
`provinces` {id type} - its own reference, the fleet its search found, not COrder's `target` - only where that resolves, followed by a blank line too; `sortie` - `start`, one `provinces` line each, `current`;
`convoy_escort` - `province`, `direction`, `convoy`; `rebase`, `reserves`, `transport` - nothing more; `invasion` -
`transport` (recorded).

**Air orders** add `return_to_base` and `priority` a second time (the same fields), then one `provinces = N` line each,
then `<air type>=N.000` for every type with `type = air` [mod: units], the int times 1000, read back with `%i`. Tails:
`paradrop_mission` - **`message` first, before the base keys**; `rebase_to_carrier` - `carrier_target`; `join_air` - a
second `target`, which on load takes both, followed by a blank line; `nuke_mission` - `nukes`; `transport_supplies_mission` - `supplies` and
`fuel`.

*The two blank lines added 2026-11-05 are measured in the saves, not read in the bytes*: all 28 `join_air` blocks of the
maintainer's 45 saves end in one, and the 3 of 6 naval `intercept` blocks that write `provinces`, where none of the
other order blocks - 7,198 of 14 kinds, the other intercepts among them - but `patrol`'s 1,230 has one. What an
intercept's `provinces` is, and why three write none, is C.11.

Others: `support_attack` - `combat=yes` only after it has joined its battle; `strategic_redeployment` - the plain COrder
keys; `none` is never written; `move_order` would be written but is in none of the 45 saves, a right-click move setting a
`path` and no order. No unit carries a `combat` key: the battles are the top-level `combat` block (section B).

### C.6 Plans (CUnitPlan::SaveContents)

`active`, [`allow_hq_reorg`], `stance`, `air_stance`, `naval_stance`, [`path`], [`path2`], `our_power`, `their_power`,
`embark`, `debark`, [`ops_area`], [`fallback_line`], one `objective { province priority }` each, [`min`].

### C.7 Leaders

The save keeps **only the leaders in service, and only their state**: `rank`, [`skill` - only where it differs from the
file's], `current_experience` (15-bit fixed, printed `2000.00000`), [`gainable_trait { <trait>=progress ... duration
current }`] and [`trait { names }`]. On load, traits already held are not added twice. Name, country, type, picture,
loyalty, maximum skill and history all come back from [mod: history/leaders, common/traits.txt]; CLeader::PostLoad then
raises skill and experience to their floors (recorded).

### C.8 Production lines and the deployment pool

**Shared line keys**: `id`, `size`, `cost`, `duration`, `progress`, `status`, [`location`], [`country`], [`builder`].

**`military_construction`** then adds [`name` - only when 2 or more characters long], `unit` {id type}, `manpower`,
[`target`], [`is_reserve=yes` with `factor`], one `<type> = { id [name] model [experience]
[upgrading_from_subunit(_str)] }` per brigade, `accumulated_experiance`, `accumulated_progress`. On load a key that is a
sub-unit type name rebuilds that brigade; a line with no `unit` gets new ids from CMilitaryConstruction::AfterLoad
(recorded).

`building_construction` adds `building` and [`count`]; `convoy_construction` a second `status` (yes/no), which zeroes the
day's share when loaded (recorded). `unit_deployment` is `id` and one unit with no `location` (CUnit::AfterLoad then gives
it the id only); `building_deployment` is `id` and `building`.

### C.9 Census

| key | where | class | SaveContents | LoadKey |
| --- | --- | --- | --- | --- |
| theatre/armygroup/army/corps/division | country, unit, fleet, air, deployment | CArmy | 0x1CECD0 rec. (+CUnit 0x1B8170 new) | 0x1CEC40 rec. -> 0x1B6E90 rev. |
| navy | country, unit, deployment | CNavy | 0x1CFAA0 rec. | 0x1CF6A0 rec. |
| air | country, unit, ship, deployment | CAir | 0x1D06B0 new | 0x1D0520 rev. |
| regiment / wing | unit | CRegiment / CWing | 0x1A92A0 new | 0x1A8BF0 rec. |
| ship | fleet | CShip | 0x1ADD30 new | 0x1ADBF0 rec. |
| `<tech>={l p}` | brigade | CSubUnit node | in 0x1A92A0 | default of 0x1A8BF0 |
| plan | unit | CUnitPlan | 0x4DF160 new | 0x4DF720 rec. |
| objective | plan | (objective class) | not read | not read |
| order keys (33 kinds) | unit | COrder family | the function table | CreateOrder 0x183AA0 + each class's slot 4 (rec.) |
| active_leaders `<id>=` | country | CLeader | 0x17FDB0 new | 0x17F800 rec.; list loop in 0xCCDA0 |
| gainable_trait | leader | CTraitGainTracker | 0x74710 rec. | 0x74610 rec. |
| military_construction | country | CMilitaryConstruction | 0x843F0 new (+0x834A0 rec.) | 0x840C0 rev. (+0x83200) |
| `<type>={...}` | military line | CBrigadeConstructionDefinition | 0x83080 new | 0x82DD0 rec. |
| building_construction | country | CBuildingConstruction | 0x85A80 rec. | 0x85980 rec. |
| convoy_construction | country | CConvoyConstruction | 0x866F0 rec. | 0x866B0 rec. |
| unit_deployment | country | CUnitDeployment | 0x17E3C0 new | 0x17E080 rec. |
| building_deployment | country | CBuildingDeployment | 0x17EEA0 new | 0x17EDB0 rec. |
| saved_templates / default_templates | country | CDivisionTemplate | 0x17EFD0 (slot 1) new | 0x17F0A0 (slot 3) new; 0x103660 new |
| auto_* (4) | country | CCountry | in 0xCFCE0 | ParseBool in 0xCCDA0 |

AfterLoads: CUnit `0x1B80D0` (revised), CSubUnit `0x1A9130`, CMilitaryConstruction `0x848A0`, CLeader `0x17FF60`
(recorded), and the `0x17D270` fold for building and convoy lines and both deployments (new).

### C.10 Not established

- What reads CUnit +0x48; the name `loading` rests on its writers.
- The objective class's own writer; its keys come from the saves only.
- The two province-list-to-vector copies inside CUnitPlan::SaveContents, not followed instruction by instruction.
- What an unknown leader id inside `active_leaders` does to the rest of the parse.
- Whether active_leaders and the country's unit lists are emptied before a load fills them (section A).
- Known only from the code, in none of the maintainer's saves: `convoy_escort`, `intercept`, `sortie`, `join_air`,
  `building_deployment` and land units carried by air; `move_order` is in none of the 45.
- For OpenHOI3: `historical_model` is absent from every save, so a save's brigades must not have their historical model
  applied again.
- Frontier: the date formatter `0x4C710` and the decimal-to-15-bit converter `0x6697F0`.

### C.11 Three questions from the writer: the order keys nothing holds, a deployment's number, an intercept's fleet

*Read 2026-11-05, statically, for OpenHOI3's save writer, and set against the maintainer's 45 saves.*

**Synopsis.** OpenHOI3's writer left out the order keys it holds nothing of, and asked what the original does without
them and whether anything reads them; what number a deployment needs; and when an intercept writes its fleet. **The
naval order's `capital`, `sub_unit` and `other` are nought for good**: the constructor zeroes them and the routine meant
to count a fleet's ships into them counts into a by-value copy and keeps nothing. **An air order's figure per unit type
is a vector of noughts** the constructor sizes to the unit database. **`stop` is -1.000 from every constructor**, the
stance's organisation limit where CSetOrderCommand gives the order, and **read by nothing found but the writer**. A
deployment's number was already in the record (section 4 of `FINDINGS-buildqueue.md`): its unit's number and one,
and one loaded with none is never registered and cannot be found. **Corrected**: an intercept's `provinces` is not its
target resolving or not - it is a reference of its own, the fleet its search found, apart from COrder's `target`.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| 0x19A900 | CNavalOrder::CNavalOrder | new | confirmed | every naval order's constructor: stop -1000, capital, sub_unit and other nought, then the count that keeps nothing |
| 0x19B170 | CNavalOrder_CountShipsByKind | new | confirmed | counts capital ships, submarines and the rest but transports into its own by-value arguments; the counts are lost |
| 0x188D40 | CAirOrder::CAirOrder | new | confirmed | every air order's constructor: stop -1000, by_unit_type made at the database's size |
| 0x1888B0 | CAirOrder_MakeByUnitType | new | confirmed | a vector of one int per unit type, every one nought |
| 0x19E130 | CNavalInterceptOrder::SaveContents | revised | confirmed | `provinces` is the intercept's own reference (+0x48, its pair +0x4C/+0x50), not COrder's `target` |

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| COrder | 0x24 | stop | int | revised - every constructor's -1000, the command's stance limit, the engine's own orders, no reader found |
| CNavalOrder | 0x3C | capital | int | revised - nought for good but from a save |
| CNavalOrder | 0x40 | sub_unit | int | revised - the same |
| CNavalOrder | 0x44 | other | int | revised - the same |
| CAirOrder | 0x34 | by_unit_type | int* | revised - the begin of a vector at the database's size, all nought; the live "null" not reconciled |

**`capital`, `sub_unit`, `other`** [exe]. `CNavalOrder::CNavalOrder` writes COrder's defaults, then nought into all
three, copies the three onto the stack and calls `CNavalOrder_CountShipsByKind` with them. That walks the fleet's
ships and adds one to the first for a capital ship (`is_capital`), else to the second for a submarine (`is_sub`), else to
the third for anything not a transport (`is_transport`), each `add [ebp+N], 1` into its own argument slot, and returns
with `ret 0xC`. Nothing stores the counts back. So outside a save the three are nought for ever, which every one of the
1,594 naval orders in the saves bears out, and **a block that leaves them out loads the same as one that writes them
nought**.

**The air order's figure per unit type** [exe]. `CAirOrder::CAirOrder` makes `by_unit_type` through
`CAirOrder_MakeByUnitType`: the vector resized to the unit database's definition count and every entry set to nought.
The loader stores a `<type>=` line at that type's index; the writer writes one line per air type. All 2,546 air orders
in the saves write nought for all eleven, so **leaving the lines out loads the same**. The record's live reading, "null
on 356 of 357 air orders", cannot be the begin pointer of a vector made at the database's size; the two are not
reconciled.

**`stop`** [exe]. Every order constructor writes -1000 (six immediate stores, one per constructor: COrder's,
CMoveOrder's, CSupportAttackOrder's, CStrategicRedeploymentOrder's, CAirOrder's, CNavalOrder's). `CSetOrderCommand::Execute`
then writes the command's figure, or where that is nought or less `AGGRESSIVE_`, `DEFENSIVE_` or
`PASSIVE_ORGANISATION_LIMIT` by the stance [mod: common/defines.lua - TFH 0.20, 0.30, 0.50]. The factory's other 19 call
sites make null orders (token 0x18D) but two: `CUnit::CheckOrderAndCombat`'s move order (0x255) and its carrier
protection (0x56C), given unasked to an air unit based on a carrier with a null order (`FINDINGS-transport.md`). Those
keep -1.000 - which is why, in the saves, 1,553 carrier protections have -1.000 and null dates and the 101 commanded ones
0.300, and every other order 0.300 (or 0.200, three times, an aggressive one). **What reads it**: nothing found but
COrder::SaveContents. Three searches, each with a positive control: no slot of any of the 34 order classes' vftables
reads `[ecx+0x24]` (slot 19's stance getter, `[ecx+0x20]`, is found in all 34); no recorded function of an order class
reads `[reg+0x24]` but the writer; and no code that loads a unit's order (`+0xB0`) reads its `+0x24` within ten
instructions (the same scan finds eight reads of the order's province, `+0xC`). *Inferred*, then, that a missing `stop`
- the constructor's -1.000 - changes nothing in play; an unrecorded function reading it through another path is not
ruled out.

**A deployment's number** [exe], already recorded: `CMilitaryConstruction::Deliver` makes its `CUnitDeployment` with
the id (the unit's type, the unit's number + 1), and moves the line's unit number on by two for the next of a series.
`AfterLoad_KeepLoadedId` registers a loaded deployment's id only where it is not 0/0 and mints none, and the deploy menu
(`CDeploymentEntry::OnSelect`), `CInGameIdler::GetDeploymentBeingPlaced` and `CDeployUnitCommand` all find a deployment
by its id. So **a `unit_deployment` written with no `id` loads as a deployment nothing can find, and its unit can never be
placed**. Every line the original makes leaves the number after the unit's free for it: a file's line passes over two
(CMilitaryConstruction::AfterLoad), and the player's own in the saves do too - unit 4940, deployment 4941, first brigade
4944 in `Ireland1938_08_25_03`.

**An intercept's `provinces`** [exe, and the saves]. `CNavalInterceptOrder::SaveContents` resolves the pair at
`+0x4C/+0x50` - the reference `+0x48` that `CNavalInterceptOrder::IsActive` fills with the first enemy fleet its search
finds (`FINDINGS-navalmissions.md`, section 6) - and writes it only where it resolves. That is not COrder's `target`, which
COrder::SaveContents writes beside it. So an intercept still waiting in port writes `target` and no `provinces`, however
long it has waited: `Ireland1937_07_05_02` (given that hour) and `_10_03_21` (given the day before) both do, and so does
`Ireland1940_05_23_17` in its first hour, where `_18` to `_20` write `provinces` - the same fleet as `target`, which the
search found.
