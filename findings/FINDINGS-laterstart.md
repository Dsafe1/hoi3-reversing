# A new game at a later date: what the new-game pass does after the history is applied

*Read 2026-11-15 by the `bookmarks-newgame` agent for OpenHOI3's planned bookmarked starts (its readme's Loose ends, "Bookmarked starts are planned, not
built"). Its sister reading, by another agent the same day, covers the bookmark file, the lobby and how the history is
applied up to the date (`FINDINGS-bookmarks.md`); this one starts where the history has been applied. The new game's
war walk at VA 0x648EFD - the `loaded_from_save` test, then the list at `+0xC00` - checked off the listing by the
collecting session. Addresses are VAs unless marked rva.*

**Synopsis.** Everything a new game does once the history stands - `CInGameIdler::CInGameIdler`'s two new-game
branches and `CInGameIdler::Enter`'s new-game blocks - was walked for reads of a date. **Nothing in it takes the
bookmark itself**: no reader of the bookmark survives into the game, and the game's own start tick (`CGameState
+0xBE0`) has **no reader in the image at all**. What changes with a later start comes in by three doors only: **the
game's clock** (the tick the history was run to), **the defines' `start_date`** (fixed at 1936.1.1 in Their Finest
Hour and BlackICE, and read here by exactly one rule, the technology head start), and **whatever the history left
standing at the date** - wars, war histories, pacts, laws, ministers, leaders' ranks, threat, revolts, rebel-held
provinces. A 1939 start does buy more technology, by a budget that grows a thousandth-year a year, and its countries
at war start mobilised, war-weary, short of manpower and with smaller stockpiles - counted from **the war's** first
day, not the country's. Two things looked at were corrected or settled rather than added: the record's "not read"
head of `SetUpCountryForNewGame` (the election date brought forward - already in `FINDINGS-government.md`, now in the
record), and **the war-exhaustion rule for a country at peace is dead for every war of the history** (a finished
history war has no sides left to find the country on).

## 1. Where a date can come from

**The defines' `start_date` (`CDefines +0x8`)** - every reader, by two scans run here (the scripts are
`agent_bmnewgame/defreaders.py` and `definline.py` in the collecting session's scratchpad):

- the 598 calls of `GetDefines` followed by a read of `[eax+8]` before the next call or jump: 23 hits - three in
  `ExecuteHistoryToDate` (`0x5F52A0`), sixteen in eight date widgets at `0x60E650`-`0x60E8C0` (each holds a date
  between start_date and end_date), one at `0x632783` (`CEU3Application::LoadEverything`'s history stage), one in
  `ResetGameStateToStartDate` (`0x63A696`), one in `CGameSetup::CGameSetup` (`0x706043`, the lobby's copy at +0x464,
  which `CGameSetup::SelectBookmark` holds the bookmark's date to), and one in `CAIStrategy::CAIStrategy`
  (`0x8A33E5` - a strategy's `rebuild_tick` starts at start_date);
- the 83 inlined copies of the accessor (279 references to the singleton `0x1A86040`), each followed to its first
  small field read: **one** reads `+8`, at `0x4D5DCE` in `SetUpCountryLawsAndTechnologyForNewGame` - the positive
  control, the known reader.

So in a game being made, start_date matters to **the technology budget** (section 3) and to nothing else but a
landless country's first AI-strategy throttle (`rebuild_tick`, which every country with land gets replaced by the tick
when `CInGameIdler::Enter` rebuilds its strategy before the two days). `confirmed` for the census of call-and-read
sites; the inlined scan is a candidate list read by hand.

**The game's start tick (`CGameState +0xBE0`, `start_tick`)**: `CInGameIdler::Enter` sets it to the tick at
`0x65A8AA` for a new game. Every `[reg + 0xBE0]` in `.text` (16 sites; a disp32, so the byte search is complete -
`fieldchain.py --field 0xBE0`) is a stack slot, a store (`CGameState::CGameState` at `0x67D341`/`0x67D353`,
`CGameState::LoadKey` at `0x67FEE8`, Enter), or **`CCountry +0xBE0`** (`core_victory_points_owned`, read by
`CCountry::GetOccupiedVictoryPointShare` and `CAIUnit_ProvinceHoldValue`, written at `0x4C9533` and `0x4E230B`/
`0x4E3059`). **Nothing reads the game state's**, so the date a game began drives nothing. `confirmed`.

**The game's tick (`+0xBDC`)**: read in the new-game pass by the technology budget (section 3), the election date
(section 4), war exhaustion, the stockpile and the manpower penalty (section 5), the pool of ministers (section 4),
the dates put back (section 4), the rebel-held provinces (section 7), every active war's `action` (section 6), and the
history replays of `HistoryDatabase_PlaceWars` (section 6) - and, as on any day, by the weather's season during its
96 hours (`INITIAL_SIMULATION_HOURS_AHEAD`) and by the two days. **The weather pre-roll does not move the clock**: it
calls `CWeatherManager::Tick` and every province's `CWeather::Update` that many times at the start hour
(`0x65C815`-`0x65C8A0`), so all 96 are worked out at the start date's hour and season. `confirmed` off the listing.

## 2. The order, for a new game, once the history stands

From the launch (`CInGameIdler::CInGameIdler`, then `CInGameIdler::Enter`; `FINDINGS-savegame.md` A.5 has the whole
table, loaded against new):

1. `CInGameIdler::CInGameIdler`, new game only (`0x648CD2`): **`HistoryDatabase_PlaceWars(registry, &tick)`** - the
   diplomatic history's entries dated on or before the tick applied into the state's diplomacy (pacts begun and ended
   by then: `history/diplomacy`'s `start_date`/`end_date`), each historical war begun by then appended to
   `previous_war`, and the wars with somebody on both sides given `CWar_DropFutureHistory` and appended to
   `active_war`. Then `RebuildOwnerAreas`.
2. `CInGameIdler::CInGameIdler`, new game only (`0x648EFD`-`0x648FA7`): **every war of `active_war` gets `action`
   (`CWar +0xC`) = the tick** - the start save's one war, the Second Italo-Abyssinian War, has `action="1936.1.1.0"`.
   This is a third writer of the field, which the record had as unfound (it is not the writer that keeps `action` at
   the save's hour in a running game - that one is still not found).
3. `CInGameIdler::Enter`: `start_tick` = tick (no reader, section 1); the events read again; each province's modifier,
   latitude and climate.
4. Per country (both kinds of game): `CCountry::ActivateRankedLeaders` (new game: **every leader whose rank the history
   has made non-zero by the date**), EnsureCapital, triggered modifiers, static modifiers, rules, leadership, max
   manpower, IC, blockade, **`CCountry::UpdateAtWarAndEnemies(1, 0)`** - at_war set, each enemy pair's `last_war` =
   tick, and **a country at war that is not mobilised is mobilised**: the timed static modifier `initial_mobilization`
   for MOBILIZATION_BONUS_DAYS (30) days and `mobilised` = 1; one mobilised at peace is demobilised - effective
   neutrality.
5. Per country, new game only (`0x65B4D4`): `SetUpCountryLawsAndTechnologyForNewGame` (section 3); `CCountry::LoadOobFile`
   (the order of battle the history names at the date - so units are made by a country that already knows it is at
   war and is mobilised, and with the laws and levels just bought); `SetUpCountryForNewGame` (sections 4 and 5);
   RecountUnitTotals; the six shares of IC (`Enter_SetNewGameShares`, which takes consumer goods under at_war); the
   history threat spread (`SpreadThreat` from the acting capital, where `history_threat` is not zero - **no country of
   Their Finest Hour has one before 1938**: Germany's first `threat = 10` is in its 1938.9.1 block, Japan's, Italy's
   and the Soviet Union's later); the officers; `CUnit::AssignBestLeader` for an unled unit; the build queue's lines.
6. Each unit: named, starting experience. Each battle's modifiers (there is none). Each province, new game only: the
   temperature seeded, its modifier, **`SpawnFullRevoltInProvince`** (a province history's `revolt`; none in Their Finest
   Hour or BlackICE), and the rebel-held provinces' date (section 7).
7. Each country: neighbours, after-diplomacy, static modifiers, the distributions, research; **`CAIStrategy::Rebuild`**
   for every strategy not yet initialised - which is where the wars at the date first become theatres and fronts.
8. Supply, then new game only: strategic resources, **the weather's 96 hours**, the intelligence arrays, the first
   `RunDailyPass`, `RunSupplyAndConvoyIterations` (the filling, the second day, the month, the hour).
9. Both: convoy indexes, **`RemoveLandlessCountriesFromWars`** - every country owning no province and not a government
   in exile taken off every active war (no history kept) and out of its faction; neighbours and after-diplomacy
   again. New game only: **`GameStrategicWarfare_SetUpForNewGame`** - the played country's tag and, if it is at war, a
   record for each enemy it is at war with.
10. The intelligence refresh, the units entered again, `in_game` = 1. The Lua `Laws(country)` posts made in step 5 run
    after this, outside Enter (`SetUpCountryForNewGame_CallLaws`).

## 3. The technology head start at a later date

`SetUpCountryLawsAndTechnologyForNewGame` (rva `0xD59D0`, `FINDINGS-starttech.md` sections 3-4). Two of its terms read
the date and one reads start_date:

    y  = the year of the game's tick              the candidates' test and the doubling
    m0 = its month counted from 0
    s  = the year of the defines' start_date      1936 in Their Finest Hour and BlackICE, whatever the bookmark
    x  = y*1000 + trunc((m0*1000 - 1000)*1000/12000) + 2000 - s*1000
    budget = trunc(trunc(3650*x/1000) * min(core leadership, 5000) / 1000)

**So a later start buys more, and from a larger set.** x for each of Their Finest Hour's eight bookmarks
(`common/bookmarks.txt`), and the budget of a country at the leadership cap (Germany):

| bookmark | x | budget at the cap | against 1936 |
| --- | --- | --- | --- |
| 1936.1.1 | 1917 | 34,985 | 1 |
| 1938.9.1 | 4583 | 83,635 | 2.39 |
| 1939.9.1 | 5583 | 101,885 | 2.91 |
| 1940.5.10 | 6250 | 114,060 | 3.26 |
| 1941.6.22 | 7333 | 133,825 | 3.83 |
| 1941.12.11 | 7833 | 142,950 | 4.09 |
| 1943.2.1 | 9000 | 164,250 | 4.69 |
| 1944.6.20 | 10333 | 188,575 | 5.39 |

(The arithmetic is the record's, `confirmed` against the start save; the table is that arithmetic applied, *not
measured* - no save starts later.) Each level costs its undiscounted price over a hundred - 1,250 for a level at the
base 125.000 - so a 1939 Germany buys roughly three times the 1936 head start, on top of the levels its history's
1938.9.1 and 1939.9.1 blocks already set. **The month's off-by-one stays**: January counts as -1/12, so every start counts one
month fewer than the whole months gone in its year (1 September counts seven, not eight); the day is not read. The candidates are the technologies whose **current** level's year is
before y and the doubling falls on those whose next level's year is not before y - both against the game's year,
so a 1939 start reaches levels of 1938 and earlier at the plain price.

**The date never enters as the bookmark's**: s is the defines', and nothing else in the function reads a date.
`confirmed` (the only inlined start_date read in the image, section 1). The laws half has no date in it, but the laws'
`allow` blocks do read `war = yes` (`CAtWarTrigger`, the country's at_war), which `UpdateAtWarAndEnemies` set a step
earlier in the same country's iteration - **so a country at war at the date has its laws moved as far as war allows**
(e.g. conscription and economy laws gated on `war = yes` in `tfh/common/laws.txt`), before its Lua `Laws()`.

## 4. The political date rules in `SetUpCountryForNewGame`

**The election date** (`0x4D6230`-`0x4D633B`, the head the record had as "not read"; already in
`FINDINGS-government.md` section A, line 414): where `last_election` (+0xAB0) is not the null date and is before the
tick, with the term = the country's own `duration` (+0x98), else its government's (`CGovernment +0x2C`): n is the count
of whole terms added to `last_election` until it is past now (`AddMonths`, one term at a time); then `last_election`
+= (n - 1) terms in one `AddMonths`. So it lands on **the latest election date of its schedule on or before the
start**. *Looks wrong*: with a term of 0 the counting loop never ends - a country whose history gives `last_election`
under a government with no `duration` and no `duration` of its own would hang the start (`inferred`; whether any
history does was not searched). Later, `last_election` = now where it holds a date before year 3.

**The pool of ministers** (`0x4D6741`-`0x4D683C`): each historical minister with `start_date <= now < death_date` - at a
later start, those already dead are out and those risen since 1936 are in.

**The dates put back** (`0x4D6841`): any pair's `last_war` later than now goes back to the null date.

## 5. War at the date: exhaustion, stockpile, manpower

(`0x4D69DF`-`0x4D6DE4` and `0x4D7397`-`0x4D7470`, read again here on the listing.)

**At war** (at_war): the start is **the earliest `CWar::GetStartDate` over the active wars the country is an attacker
(+0x2C..+0x30) or a defender (+0x3C..+0x40) in** - and GetStartDate is the war's first dated history entry, **not the
date the country joined it**. months = calendar months from that start to now; war_exhaustion = min(months * 0.05, 10);
days = 30 + 5 * max(12 - months, 2); and once the manpower pool is set to its maximum, it loses
`max_manpower / MAX_MANPOWER * (1 + months * 0.12)`, floored at 0.

So at the 1941.6.22 bookmark the Soviet Union, which joins the World War II war that day, is counted 21 months at war
from that war's 1939.9.1 entry: war exhaustion 1.050, a stockpile of 40 days' IC instead of 90, and **3.52 tenths of
its manpower cap gone** (MAX_MANPOWER 10). Hungary and Finland, joining the same day, likewise. *Looks wrong* - the
rule reads as meant for the time the country has spent at war; it is what the bytes do (`confirmed`: the only date
taken is `GetStartDate(war)`, `0x4D6AD4`; the membership test is on the war's present sides). A war of **no** dated
history has the null date as its start, which would give such a country 10 war exhaustion and lose it nearly its whole
pool; none of Their Finest Hour's active wars is of that kind (`inferred` - the two nameless empty wars of the start
save are on `previous_war`, not `active_war`).

**At peace**: war_exhaustion = max(3 - months since the latest `CWar_GetLastHistoryDate` over the `previous_war`
entries **the country is on** * 0.05, 0), the latest starting at the null date. **This finds nothing for any war of
the history**: a war reaches `previous_war` when it has ended, a history war ends by `rem_attacker`/`rem_defender`,
and `CRemoveAttackerChange::Apply` is `CWar::RemoveAttacker`, which **erases the tag** from the side - so a finished
history war has no attacker or defender to find the country among, and every country at peace starts at 0. The start
save bears the shape out: its two `previous_war` blocks carry no `attacker` or `defender` line. (`confirmed` for the
filter and the erasure; that the rule therefore never fires is the consequence, `inferred` only in that a history war
could in principle end with one side left - none of Their Finest Hour's does by 1944.) A dead rule of the original:
at a 1940.5.10 start Finland, two calendar months out of the Winter War (ended 1940.3.13), starts with nothing, not 2.900.

Days, the stockpile (crude oil and metal MaxIC * days, energy twice, rare materials half, money only where the pool has
none, supplies and fuel `days` of the units' use, held to 1000 for a subject) and influence are as the record has
them; only `days` depends on the war.

## 6. Wars standing at the date

All in the record already; collected here because a 1936 start exercises them for one war (Italy and Ethiopia) and a
later start for many:

- **Which wars**: `HistoryDatabase_PlaceWars` (step 1) - active if somebody is on both sides at the date, with the
  war's future history deleted; begun by then and over, on `previous_war` with empty sides. A war's **war goals** come
  with its history (`war_goal` in `history/wars`; World War II's 1939.9.1 entries give Germany `conquer` on Poland and
  `vichy_war_goal` on France) - their application is the history's (the sister reading).
- **`action`** = the tick, every active war (step 2).
- **Mobilisation**: every country at war (step 4), before its order of battle is read.
- **Laws** moved under `war = yes` (section 3); the Lua `Laws()` and `AI_GenerateNonHistoricalRelation` both read
  `IsAtWar`/`HasWar` (`script/ai_politics_minister.lua`, `script/ai_country.lua`: -200 for a pair at war, -100 for a
  truce, where the history gave the pair no relation).
- **Spies**: the first allocation gives +2 towards a country at war with this one.
- **Landless countries**: `RemoveLandlessCountriesFromWars` (step 9) - at a 1940 or 1941 start, every country the
  history has left with no province is taken off its wars and out of its faction **unless the history made it a
  government in exile** (`government_in_exile = yes`, in Their Finest Hour only France's and Poland's histories).
- **Strategic warfare**: the played country, if at war, gets a record per enemy (step 9).
- **The AI's strategy and theatres** are rebuilt with the wars standing (step 7).
- **No battle exists** when a game begins, whatever the date: the battles' walk in Enter finds none, and units of two
  countries at war sharing a province meet only in the running game's hours.

## 7. Rebel-held provinces

`0x65BF86`-`0x65C007`, new game only, in the per-province pass straight after `SpawnFullRevoltInProvince`: where the
province's controller tag (+0x334) is `REB`, the province history's entries are walked from the last backwards (the
history is held by value at +0xD8, its last node at +0xE8, a node's data at +0 and its previous at +4), and **the first
`controller` entry (slot 6 answers 0x1ED) whose tag (`0x5FEF60`) has the province's controller id (+0x338) is
re-dated to the tick** (`+8`; the tick read once at `0x65B12F`). `ProvinceHistory_LatestControllerDate` answers that
date to `RunMonthlyRebelFactionPass`, which adds `defect_delay` months to it before a rebel faction's independence can
roll - **so the rebels' clock on a province they hold at the start starts with the game**, not at the history's date.
`confirmed` for the walk and the store; the value stored being the tick is `inferred` (likely - the slot `[esp+0x58]`
is written from the tick at `0x65B148` and nowhere between there and `0x65C003` by any `[esp + 0x58]` operand, and the
frame depth matches; not traced instruction by instruction).

## 8. What a live probe would need

None of the maintainer's saves (`Documents\Paradox Interactive\Hearts of Iron III\save games`, 45 files, and the
BlackICE folders' ten) is the first hour of a later bookmark: the earliest of each later year is an autosave or a save
of the Ireland game played from 1936. The Cheat Engine bridge did not answer on 2026-11-15 (`ping`: the pipe is not
reachable), so no probe was run. What it would do, with `probes/hoi.lua`:

1. Copy the three autosaves aside first - a save from the probe rotates `autosave.hoi3` into `oldautosave` and
   `olderautosave`, and `olderautosave.hoi3` is the maintainer's 1939.9.8 Ireland game.
2. From the main menu, Single Player (`hoiNewGame`'s first call), then **`CGameSetup::SelectBookmark` (rva `0x30ED60`,
   slot 7) on the lobby view with the wanted `CBookmark`** - the holder at `[0x1A8A874]` keeps two lists, the historical
   bookmarks in file order in one and the `is_cgm` ones in the other (`CBookmarkList_Load`; which is which was not read) - or a click on the row through `CBookmarkEntry::OnBookmarkClicked`
   (rva `0x3034F0`); wait for the posted `CSetHistoryDate` to move the world; then `CGameSetup::OnProvinceClicked`
   with a province of the country (`hoiNewGame`'s second call) and Play.
3. The game loads paused at the bookmark's hour, its two days run: `hoiSave()` writes `autosave.hoi3`; copy it out as
   e.g. `Germany1939_09_01_00.hoi3` (the start save of that bookmark), then put the maintainer's autosaves back.
4. Optionally, a breakpoint at the end of `SetUpCountryLawsAndTechnologyForNewGame` logging the country and its budget
   (or a read of level_by_technology before and after) to set the head start beside section 3's table.

Two bookmarks would cover nearly everything: **1939.9.1** (a fresh war with many joiners, Germany played and at war -
strategic warfare - mobilisation, laws under war, the larger budget) and **1941.6.22** (joiners of a long war - the
months-from-the-war's-start rule - landless countries and the two exiles, the Winter War on `previous_war`).

## 9. Not established

- The bookmark lobby's own path to the date (the sister reading).
- `0x5FEF60` (a history change's tag) is unnamed; it is in the frontier.
- What keeps a running war's `action` at the hour (the record's open question) - not this reading.
- Whether any history gives `last_election` under a government with no term (the hang in section 4).
- Every number in section 3's table and section 5's examples is the read arithmetic applied, not measured.
