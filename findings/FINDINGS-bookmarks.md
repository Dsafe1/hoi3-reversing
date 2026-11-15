# Bookmarks: a later start, from the lobby to the history applied

Read 2026-11-15, statically, in a copy of the Ghidra project, by `bookmarks-lobby`, for OpenHOI3's planned bookmarked
starts (its readme's *Loose ends*; `docs/compatibility.md`, entries 1 and 17). Fragment `bookmarks-lobby.json`. Its
companion is the new-game pass at a later date, read in parallel by `bookmarks-newgame` (fragment
`later-start-newgame.json`): this write-up stops where the history has been applied. Addresses are rvas unless marked VA
(VA = rva + 0x400000); only valid for this build. **[exe]** hardcoded in the executable, **[mod: file]** what a file may
change. `confirmed` unless marked. `ExecuteHistoryToDate`'s argument roles (the registry `[ebp+8]`, the start
`[ebp+0xC]`, the target in EDX, at VA 0x5F52BE..0x5F52C6) checked off the listing by the collecting session.

Builds on `FINDINGS-frontend.md` (the lobby, B.1-B.6, and the Quick Start panel, A.4), `FINDINGS-history.md` (the
history containers and their replay), `FINDINGS-war.md` C.13 (the wars' two lists), `FINDINGS-oob.md` and
`FINDINGS-starttech.md`.

**Corrections to the record**:

- `ExecuteHistory`'s record said its fourth argument was the history registry. **The registry is EDX**; the fourth
  argument is a scenario's history or null (section 2.2).
- `ExecuteHistoryToDate`'s argument list was `inferred` with the two stack slots unsettled; it is `(registry, from)` on
  the stack and `to` in EDX, and the record's names had `from` and `to` the wrong way round (section 2.1).
- `FINDINGS-frontend.md` A.7's open "the quickstarts' five automation entries" is settled (section 1.5), and so is
  B.8's "CResetGame's Execute" (section 1.6). A.4's "the middle of the bodies *inferred*" is now read.
- `FINDINGS-startup.md` section 7 has `bookmarks.txt` loaded "at the very top of LoadEverything". Its path is gathered
  there; the file is read near the end, after the history is executed and the country database exists (section 1.1).

## 1. The bookmark and the lobby

### 1.1 Which files

`CBookmarkList_Load` (`0x2ECFB0`) is called once, from `CEU3Application::LoadEverything` at `0x232AC6`, after its
`history execute` stage. It is handed a vector of **two paths**, built at the top of LoadEverything (`0x22FBDA` to
`0x230124`): each is `/bookmarks.txt` under a directory of its own, **the mod's copy where the file exists there, the
game's otherwise**. That the two directories are `common/` and `cgm/` is *inferred* from the install, whose
`tfh/cgm/bookmarks.txt` is the one whose bookmarks say `is_cgm = yes`; the settings fields the two roots come from were
not identified. **So a mod's bookmarks file replaces the game's; the two are not merged** [exe]. Their Finest Hour has
no `tfh/common/bookmarks.txt`, so the base game's `common/bookmarks.txt` is read; BlackICE ships one with a single 1936
bookmark (its `cgm/bookmarks.txt` has the 1936 custom game, the rest commented out).

Both lists are emptied, then each file read in turn. A missing file logs `Failed to open file <path>` and is passed
over. Each top-level block is parsed into a CBookmark and, where the parse left no message, appended to the historical
list or, with `is_cgm`, to the custom games' list - **file order** in both.

**An unknown key ends the file** [exe]: the first bookmark whose parse leaves a message (any key not among the seven
goes to `ReportUnknownKey`, which adds one) logs `Failed to read bookmark in <path>`, and that bookmark **and every one
after it in the file** are lost. The next file is still read.

### 1.2 The grammar (`CBookmark::LoadKey`, `0x2EC6F0`)

| key | holds | notes |
| --- | --- | --- |
| `name` | a localisation key | kept as written, and **localised once, at load**, where not empty |
| `desc` | a localisation key | the same |
| `icon` | a sprite name | the lobby row's button (`GFX_bg_startdate_1936`) |
| `date` | `year.month.day.hour` | **the hour 0 when left out**; held to the defines' range when chosen (1.3) |
| `country` | a tag, repeatable | appended in order; a tag that is no country logs `Bad tag <X> in bookmark <name>` and is left out - the bookmark is kept |
| `is_cgm` | yes/no | the custom games' list |
| `cgm_folder` | a folder name | the custom game's folder; out of OpenHOI3's scope |

The base game's eight [mod: common/bookmarks.txt], in file order:

| name key | date | countries |
| --- | --- | --- |
| ROAD_TO_WAR | 1936.1.1 | ENG GER FRA USA JAP SOV ITA |
| GATHERING_STORM | 1938.9.1 | ENG GER FRA USA JAP SOV ITA |
| BLITZKRIEG | 1939.9.1 | ENG GER FRA USA JAP SOV ITA POL |
| ATTACK_ON_THE_WEST | 1940.5.10 | GER FRA ENG ITA BEL HOL USA SOV |
| AWAKENING_THE_GIANT | 1941.6.22 | GER ENG USA JAP SOV ITA AST |
| DAY_OF_INFAMY | 1941.12.11 | JAP USA ENG GER SOV ITA AST CAN |
| THE_TIDE_HAS_TURNED | 1943.2.1 | JAP USA SOV ENG GER ITA AST CAN |
| GOTTERDAMMERUNG | 1944.6.20 | GER SOV ENG USA AST CAN JAP FRA |

### 1.3 Choosing one, and where the date is kept

(The lobby's rows, shields and tabs are `FINDINGS-frontend.md` B.1, B.2; what follows is the date.)

Opening the lobby runs `CGameSetup::SelectDefaultBookmark` (`0x307BF0`): **the history replayed from the state's tick
to the defines' `start_date`** [mod: common/defines.lua], every country refreshed, the map redrawn, then a
CSelectBookmark posted for **the first bookmark of the historical list**. A click on a row posts the same command for
that row. Executed, it reaches `CGameSetup::SelectBookmark` (`0x30ED60`), which **holds the bookmark's date between the
defines' `start_date` and `end_date`** and posts a **CSetHistoryDate** with it.

`CSetHistoryDate::Execute` (`0x2D60C0`), read whole:

1. **the history replayed from the game state's tick to the date** (`ExecuteHistoryToDate`, section 2.1);
2. **the game state's tick set to the date** - this is where a bookmark's date lives: the game's clock, saved as the
   save's `date`. **The defines' `start_date` is not replaced** and keeps its other uses: the hold above, the rewind
   point of every backwards move (2.1), a reset's date, and the start-technology budget (`FINDINGS-starttech.md`);
3. every country refreshed; the map's overlays hidden and its colours redrawn, its layer mask and style set as the
   front end's Enter sets them;
4. the victory conditions' two game_finished bytes cleared and **the victory conditions chosen**: at random without a
   scenario (`VictoryConditions_ChooseRandomly`, whose only caller this is), the primaries in one.

**So the lobby's map shows the chosen date's world at once** - owners, controllers, every history entry up to it - and
each later click moves it again. The bookmark's name stays in the lobby (`CGameSetup +0x6DC`, for the year label and the
row's highlight); nothing of the bookmark but its date reaches the game.

### 1.4 `simple`

Not a bookmark key: `simple = yes|no` is the player's `settings.txt`, and picks whether the front end opens on the main
menu or on the Quick Start panel (`FINDINGS-frontend.md` A.1).

### 1.5 The Quick Start panel's four buttons

`quickstart_ger`, `_usa`, `_jap` and `_sov` [mod: interface/temp_frontend.gui, the buttons and their titles] each run a
body of their own, the same in all four but for the date and the tag [exe]:

| button | date | tag |
| --- | --- | --- |
| `quickstart_ger` (`0x2F4250`) | 1939.9.1.1 | GER |
| `quickstart_usa` (`0x2F48A0`) | 1936.1.1.1 | USA |
| `quickstart_jap` (`0x2F4EA0`) | 1941.12.7.1 | JAP |
| `quickstart_sov` (`0x2F5500`) | 1941.6.22.1 | SOV |

**They name no bookmark**: the date and tag are string constants, and nothing reads `bookmarks.txt`. Japan's 7 December
1941 is no bookmark's date (Day of Infamy is the 11th). In order:

1. the date parsed - **hour 1**, where a bookmark of the same day begins at hour 0;
2. the history replayed from the state's tick to it and the tick set to it - **with no hold to the defines' range and no
   CSetHistoryDate**, so the victory conditions are not chosen here and game_finished is not cleared;
3. every country refreshed;
4. a player record (`CHuman_ConstructNamed`: name `Human`, the session's local id);
5. a seed from the platform clock with the draw count nought, posted as a CSetRandomSeed;
6. the tag made the played country - played_countries, the state's and the map's player - its CAI's +0x2C cleared,
   controllers_changed set;
7. **the player record's automation: Diplomacy, Production, Technology, Politics and Intelligence all to the AI (flags 0
   to 4 set to 1), the tech minister on sliders and research (`automate_tech_sliders` 1), and `primary_local` set**;
   `automate_sliders` and the Armies level left at their defaults. So a Quick Start game leaves the player the army
   alone;
8. the record appended to the state's humans (`CGameState_AddHuman`, which copies it);
9. `launch_requested` set: the game starts on the next frame, through the same `LaunchGame` as Play.

### 1.6 Back from a save to Historical Start

`CGameSetup::OnNewGameTab` posts a **CResetGame** where the state came from a save. Its Execute (`0x2D59B0`) finds the
lobby by a fixed persistent id (*inferred*: from the slot it calls) and calls its CLobbyInterface slot 12,
`CGameSetup::RevertToStartDate` (`0x314750`): the loading indicator up, **ResetGameStateToStartDate** - every history
file read again and replayed from `-1.1.1` to `start_date` - the indicator down, the chosen save dropped, every country
refreshed, the map redrawn, and the chat line REVERT_SAVE_CAL. **No bookmark is chosen**: Play waits on
CANT_START_REASON_SELECT_BOOKMARK until a row is clicked.

## 2. History at a date

### 2.1 `ExecuteHistoryToDate` (`0x1F52A0`): two passes from nothing, and a rewind for every move back

`(registry, from)` on the stack, `to` in EDX. Ignoring scenarios: where the target is before `from`, the world is first
**rewound to the defines' `start_date`** and replayed forwards from there; otherwise it is replayed forwards from `from`.
**A move backwards is never an undo to the target** [exe].

Its callers:

| when | from | to |
| --- | --- | --- |
| startup (`LoadEverything`), and a reset (`ResetGameStateToStartDate`, which first reads every history file again) | `-1.1.1` | `2.1.1` |
| the same, next | `2.1.1` | the tick, which is `start_date` |
| the lobby opening (`SelectDefaultBookmark`) | the tick | `start_date` |
| a bookmark chosen (`CSetHistoryDate`) | the tick | the bookmark's date, held to the defines' range |
| a Quick Start | the tick | its hardcoded date |

The two static dates are globals set by static initialisers from the strings `-1.1.1` and `2.1.1`. **An undated history
entry - a key at the top of a file, outside any date block - keeps the null date, year 0**, so the first pass applies
every undated entry, and the second every entry dated after year 2 up to `start_date`.

### 2.2 `ExecuteHistory` (`0x1F4C20`): what is replayed, in what order

Every history container applies an entry **dated in (from, to]** going forwards, head to tail, and undoes one dated in
**(to, from]** going backwards, tail to head (`CHistoryContainer::ApplyRange`). The containers are kept in date order as
they are read: an entry no earlier than the last is appended, so **entries of one date apply in file order**; an earlier
one goes through a sorted insert that was not read (`0x1FAEE0`), so where it falls among equals is not established.
Within a date block, keys are entries in their file order.

The order of one call [exe]:

1. **every province's history** (`history/provinces`);
2. **every country's history** (`history/countries`), in country id order, and right after each country **the history
   of every leader in that country's list** (`history/leaders`) - a leader's rank changes ride with his country;
3. **the diplomatic history** (`history/diplomacy`): each relation, NAP, casus belli, alliance, guarantee and vassal is
   an entry at its `start_date`, and its inverse a second entry at its `end_date` where it has one
   (`ReadDiplomaticHistoryFile`);
4. **the wars' histories** (`history/wars`): `add_attacker`, `rem_attacker`, `add_defender`, `rem_defender`,
   `limited_war`, `war_goal` and `name`, dated;
5. **the wars sorted**: each war of the registry's "other" list with at least one attacker and one defender is moved to
   its "standing" list, and each standing war left with an empty side moved back;
6. **always, whatever the dates**: the area groups and the supply groups deleted and made again.

(A scenario's own history, which OpenHOI3 does not read, is interleaved: after the registry's going forwards, before it
going backwards.)

`HistoryDatabase_PlaceWars` (`0x1F5450`) is what puts the standing wars on the game state's `active_war` list - each
cut of every history entry after the date (`CWar_DropFutureHistory`) - and the others whose first dated entry is not
after the date on `previous_war`. It runs from `CGameState::StartAI`'s new-game branch, so **in the lobby the wars exist
only in the registry; the game gets them as it starts** (`FINDINGS-war.md` C.13).

### 2.3 The grammars, and which entries a later date brings

What each file may say is the existing record's (`CCountryHistory::LoadEntry`, `CProvinceHistory::LoadEntry`,
`CWarHistory::LoadEntry`, `CLeaderHistory::LoadEntry`, `ReadDiplomaticHistoryFile`). **A date block is only a way of
postponing a key**: anything valid at a file's top is valid inside one (`CHistoryContainer::LoadKey`).

A country's history, 33 keys by name [exe] (`switchmap.py` on its LoadEntry): `alignment`, `capital`,
`clr_country_flag`, `clr_global_flag`, `crude_oil`, `decision`, `dissent`, `energy`, `fuel`, `government`,
`government_in_exile`, `historical_friend`, `ideology`, `join_faction`, `leader`, `leave_faction`, `manpower`, `metal`,
`money`, `national_unity`, `neutrality`, `nukes`, `officers`, `officers_ratio`, `oob`, `organization`, `popularity`,
`rare_materials`, `remove_decision`, `set_country_flag`, `set_global_flag`, `supplies`, `threat` - and any other key
looked up as a technology, a technology category, a minister's post, a law group or an occupation policy. A province's,
18 keys and every building.

Each is an entry with an Apply that saves what it overwrites, so it can be undone. Read for this write-up, besides those
already recorded: **`set_global_flag`** sets a global flag (`CAddGlobalFlagChange::Apply`) - neither the base game nor
BlackICE uses it; `historical_friend` adds to the country's historical friends (*inferred*: the add was not read);
`manpower` sets manpower (`CCountryManpowerChange::Apply`, and see 4.2). `join_faction`, `leave_faction` and
`alignment` were read before (`FINDINGS-faction.md`, `FINDINGS-alignment.md`): replayed, they join and leave factions
and place a country on the triangle without writing more history.

**So at a later date, for every country and province, everything dated up to the date applies, in date order, on top
of everything undated**: owners, controllers, cores, buildings and resources; capitals, governments, ruling parties,
popularity and organisation; ministers in their posts, laws, technology levels, neutrality, national unity, dissent,
threat, goods; flags; factions; exile; occupation policies; the order of battle's file name; leaders' ranks, loyalty and
traits (a dated `skill` does nothing, `FINDINGS-history.md` section 2); the diplomatic pacts standing at the date; and
the wars.

### 2.4 Which order of battle a country gets

**Each `oob = "<file>"` line is a history entry** (`COOBChange`, whose Apply only sets the country's `oob_file`), so the
file a country ends with is **the last `oob` entry dated at or before the date** - the undated one where none is dated.
**Nothing is read in the lobby.** The file is read once, as the new game is entered, by `CCountry::LoadOobFile` for each
country - `history/units/<file>` through the layers - and only where the name is not empty and **the country owns a
province or is REB**; a file that is not found loads nothing, silently (`FINDINGS-oob.md`; the newgame pass is
`bookmarks-newgame`'s).

So the per-year files are not chosen by their names: `GER_1939.txt` is read at 1939 only because Germany's history says
`oob = "GER_1939.txt"` in its `1939.9.1` block. Their Finest Hour's country histories carry 581 `oob` lines; the files
they name end in `_1936` (99), `_1938` (97), `_1939` (94), `_1940` (84), `_1941` (89), `_DayOfInfamy` (84),
`_TheTideHasTurned` (81), `_1944` (80) and `empty.txt` (24). At each bookmark's date the last entry gives, for the 78 to
80 countries that have one:

| bookmark | files |
| --- | --- |
| 1936.1.1 | `_1936` 78 |
| 1938.9.1 | `_1938` 77, `_1936` 2, `empty` 1 |
| 1939.9.1 | `_1939` 75, `empty` 3, `_1938` 2, `_1936` 1 |
| 1940.5.10 | `_1940` 67, `empty` 8, `_1939` 3, `_1938` 2, `_1936` 1 |
| 1941.6.22 | `_1941` 68, `empty` 12, `_1938` 2, `_1936` 1 |
| 1941.12.11 | `_DayOfInfamy` 66, `empty` 12, `_1941` 2, `_1938` 2, `_1936` 1 |
| 1943.2.1 | `_TheTideHasTurned` 64, `empty` 15, `_1938` 2, `_1936` 1, `_1941` 1 |
| 1944.6.20 | `_1944` 64, `empty` 16, `_1938` 2, `_TheTideHasTurned` 2, `_1936` 1, `_1941` 1 |

Two named files do not exist: `NOR_1940.txt` (Norway's 1940.5.10 entry, so Norway at that bookmark has no units, if it
still owns a province) and `scenarios/desert_fox/ITA_Army.txt` (Italy's 1941.3.30 entry, superseded on 1941.6.22 before
any bookmark). BlackICE's histories name `_1936` files in 83 lines and later files in 5; with its one bookmark it never
reaches them - except through the Quick Start panel (section 4.3).

### 2.5 A country that is gone, and one that is new

There is no annexation in the history. **A country exists where it owns a province**, so Austria is gone in 1938 and
Czechoslovakia in 1939 because their provinces' histories give them away: `history/provinces/.../3026 - Wien.txt` has
`1938.3.12 = { owner = GER controller = GER add_core = GER }`. Austria keeps its undated `oob = "AUS_1936.txt"`, which
LoadOobFile then passes over, since Austria owns nothing. A country born later - Slovakia, Croatia, Vichy France - is
made the same way: its provinces' dated `owner`, its own dated `join_faction`, `oob` and the rest. Puppets are the
diplomatic history's dated `vassal` entries; factions the countries' dated `join_faction` and `leave_faction`; an exile
`government_in_exile = yes`.

## 3. What happened before the date

**Nothing marks an event or a decision as fired.** No history file has a key for it - none of the grammars above names
one - so at a later start the fired-event list is as empty as at 1936, and any event whose trigger holds may fire again
(*confirmed* for the grammars; that nothing else fills the list at a later start is *inferred* - the new-game pass is
`bookmarks-newgame`'s).

The content does the marking itself, in history:

- **country flags**: 39 `set_country_flag` lines in the base game's and Their Finest Hour's country histories, each the
  flag the event or decision of that history would have set - `the_molotov_ribbentrop_pact` on Germany at 1939.8.23,
  which the Molotov-Ribbentrop decision's `potential` tests (`not = { has_country_flag = the_molotov_ribbentrop_pact
  }`); `fall_of_stalingrad`, `destruction_of_the_french_fleet`, `spanish_civil_war_over`, the Spanish Civil War's
  intervention flags and the rest;
- **events' own triggers on the world**: the Anschluss's needs Austria, which no longer owns a province;
- **`decision = <name>`** lines: 22 in Their Finest Hour's country histories (the base game's with `tfh/` laid over),
  every one dated (two in 1936, one in 1937, two in 1939, four in 1940, seven in 1941, one in 1942, four in 1943, one
  in 1944). Replayed, each only adds the
  name to the country's taken list (`CCountryDecisionChange::Apply`); **the decision's effect then runs as the new game
  is set up** (`SetUpCountryForNewGame`), with no `potential` or `allow` asked - so a later start runs more of them
  (the new-game side is `bookmarks-newgame`'s);
- **global flags**: the key `set_global_flag` exists in a country's history; neither the base game nor BlackICE uses it.

The game's own variables, the counters and the event list of a save are not touched by the history.

## 4. What looks wrong and is the original's

1. **An unknown key in a bookmark ends its file**: that bookmark and every later one are lost, logged once (1.1).
2. **Quick Start ignores `bookmarks.txt` and the defines' date range**: it starts its four hardcoded dates whatever the
   mod - BlackICE, with one 1936 bookmark, still starts 1939 and 1941 from its own history, its later order-of-battle
   files mostly not written (2.4). Japan's date is no bookmark's (1.5).
3. **A Quick Start begins at hour 1, a bookmark at hour 0**, of the same day (1.5).
4. **A Quick Start chooses no victory conditions** - only CSetHistoryDate calls the random choice (1.3, 1.5). What the
   victory conditions then hold was not traced.
5. **A move backwards in the lobby is a rewind to `start_date` and a replay forwards**, and a rewind is only as exact as
   each entry's undo: undoing a dated `manpower` writes the country's officers into its manpower
   (`CCountryManpowerChange::Apply` keeps the officers, not the manpower, as what to put back - harmless, the new game
   overwrites manpower); undoing a `revolt_risk` puts back a figure cut to whole points (`CRevoltRiskChange::Apply`);
   undoing a `rank` takes a land leader off his unit (no units exist in the lobby). So **choosing a later bookmark and
   then an earlier one may leave a world that differs from choosing the earlier one at once**.
6. **The bookmark's countries are only shortcuts**, and its name and description are localised once, at load - a
   language change does not reach them until the next start.
7. **The undated pass applies everything dated before year 2 as well** - an entry dated `1.1.1` is applied with the
   undated ones; none is so dated in the install.
8. Two named order-of-battle files do not exist (2.4) - the install's, not the engine's; the engine says nothing.

## 5. Not established

- Which settings fields hold the two bookmark directories (1.1); `common/` and `cgm/` is inferred.
- Where an out-of-order history entry lands among entries of its date (the sorted insert, `0x1FAEE0`).
- Which object owns the persistent id CResetGame looks up (*inferred* the lobby from the slot it calls).
- What a Quick Start game's victory conditions hold, with no CSetHistoryDate run.
- `historical_friend`'s add (`0x1EC940`), and `0x286F40`, read here as the game state's global flags.
- Nothing here was watched in a running game; no save at a later bookmark's first hour exists in the maintainer's
  folder (all are of games begun in 1936).
