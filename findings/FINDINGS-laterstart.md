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

## 2a. One country at a time

*Read 2026-11-15 by `bm-occupation`; fragment `later-start-occupation.json`.* **Steps 4 and 5 of section 2 are one loop
over the countries.** It starts at VA 0x65B15B; its body runs both the step-4 calls (0x65B276..0x65B398) and, for a new
game, the step-5 calls (0x65B4E1..0x65B64C), and it loops back from 0x65B7EA to 0x65B152. Each country is set up in turn,
in id order, so what a country's turn reads of other countries is what the earlier turns made:

- **A later country's IC is nought** while an earlier country's laws are moved. `UpdateIC` has exactly three callers
  (0x4D633D, 0x4DB442, 0x65B2C5; `findRefs --callers`), none in the lobby, so `enemy_ic_ratio` - any enemy with max_ic 0
  answers false - fails for a country with an enemy later in the order. The 1939.9.1 save's Germany, Britain, France and
  Poland take `three_year_draft` and `war_economy` so (*measured*).
- **Effective neutrality** is written at 0x65B3E3 in each country's turn, against `highest_threat_id` - a field last
  elected by the lobby's `RefreshAllCountries` -> `RebuildNeighbours` when no threat existed, so it holds the first
  eligible country, mostly Germany - with the threat the earlier turns spread already in it. The 1941.6.22 save's Sweden
  moves to `three_year_draft` this way (*measured*).
- **The history threat spread** (0x65B64C) ends each turn. A controller whose turn is still to come has a modifier not
  yet rebuilt with its ministers, so its `threat_resistance` reads 0 - unless the history's wars mobilised it in the
  lobby, because `CCountry_AddTimedModifier` calls `RebuildStaticModifiers`. *Measured*: every pair of all three saves
  agrees; the USA resists Japan's spread and not Germany's.
- **The lobby's war replay** runs with the clock at `start_date`: `AddAttacker`/`AddDefender` ->
  `UpdateAtWarAndEnemies(0,0)` stamp the joiner's `last_war` at 1936.1.1 (the saves' `SPR->SPA`, `CSX->JAP`, `IRQ->ENG`)
  and mobilise it with a 30-day modifier from 1936.1.1. At a later start that modifier has run out, so step 4 finds every
  warring country mobilised already and gives no new one: no later save has `initial_mobilization`.
- **The province history's `controller` and `owner` lines** are `CControllerChange::Apply` -> `Province_SetController(...,
  0,0,0)` and `COwnerChange::Apply` -> `CMapProvince::ChangeOwner(..., 0,0,0)`. So every change of hands the replay makes
  takes the occupation policy - that step lies outside `applyConsequences` - and an owner change sets nationalism.
- **The Lua `Laws()` call** is made once per country during the entry: the 1939 save's Soviet Union is one step on.

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

**Measured on the maintainer's 1939.9.1, 1941.6.22 and 1941.12.11 start saves** (2026-11-15, by `bm-economy`; nothing
read anew):

1. **A goods line sets**, as `CGoodsChange::Apply` reads: Germany's 1939 stockpile has its 1939.9.1 block's
   `rare_materials = 5000` plus 180 IC's half of 90 days (13,297.932 in the save), not the three lines' sum.
2. **The set-up's stores go to the acting capital's province pool, not `GetPool`**: at 1941.6.22 London holds 1,520
   IC-days (metal 1,520, rare materials 760) over England's 161 x 40 - Denmark's, Norway's, Poland's, Greece's and
   Yugoslavia's 5 IC, Belgium's 6 and France's 7, each x 40, all exiles seated there by `SetGovernmentInExile` replayed
   from the history key; each exile's own `pool` holds only two days of income. The Netherlands' 13 x 40 lies in
   Amsterdam, its seat moved to Batavia afterwards.
3. **The decisions' effects precede the stockpile** in `SetUpCountryForNewGame`, so France at 1939, given 35 money by
   `popular_front`, gets no money for its IC (43.134 two days in).
4. **The months at war count from the war's first dated entry**: the Soviet Union, Romania and Finland at 1941.6.22 keep
   0.648 of their most, exact under the save's laws.
5. **The per-country set-up is one loop, and a country's most manpower reads each owner's law as it stands at that
   moment**: land owned by a country later in `countries.txt` is weighed by its history law - Japan's 130 Chinese
   provinces give nothing under China's history `volunteer_army` at 1941.6.22, so 558.603. With the save's laws and
   occupation policies every country's manpower is exact at both 1941 starts, 72 of 72. `likely` for the loop's shape
   (`FINDINGS-savegame.md` A.5's single "per-country set-up" row), measured for the effect.

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
  government in exile** (`government_in_exile = yes`). *Corrected 2026-11-15 (`bm-occupation`)*: the key is in ten base-game histories - ALB, BEL, DEN, FRA, GRE, HOL, NOR, PHI, POL, YUG - not France's and Poland's only; Their Finest Hour overrides those two. The 1941.12.11 start save has seven exiles.
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

*Since 2026-11-15 the maintainer's folder has start saves of three later bookmarks* - `Ireland1939_09_01_00.hoi3`, `Ireland1941_06_22_00.hoi3`, `Ireland1941_12_11_00.hoi3`, each written at the bookmark's first hour - and OpenHOI3's start checks set a new game beside them (sections 2a, 5, 10 to 12 measure on them). What follows was the plan before they existed.

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

## 10. Entering runs the shares with nothing to spend

*Read 2026-11-15 by `bm-units`; fragment `later-start-units.json`.* In `CInGameIdler::Enter`'s per-country pass after
the information caches (VA 0x65C170 on; the "6+4 distributions" of `FINDINGS-savegame.md` A.5), **for new and loaded
games alike** - no `loaded_from_save` test guards it - each country gets, after 0x4E21E0, 0x4E39C0 and 0x4DDD80:

- slot 0 of each of its six IC shares (+0x5F4, VA 0x65C1B0..0x65C1E5) with an allocation of **0** and flag **1**;
- the same for its four leadership shares (+0x5E4, VA 0x65C1E9..0x65C21E);
- where +0x640 > 0, `CDistributeResearch::ShareAmongProjects`;
- then `CAIStrategy::Rebuild` for a strategy neither initialized nor static.

A census of every `[ebp+0x14]` operand in the ten Distribute bodies finds two: `CDistributeConsumerGoods` at 0x518DE8 and
`CDistributeProduction` at 0x51A213 (the positive control, already recorded). `CDistributeUpgrade` never reads the flag:
with its budget at 0 no equipment moves, but **every doctrine a brigade is behind in moves a whole level**, before a new
game's two days and again at every load. Reinforcement acts only with a budget above 0. A 1936 start, its models a level
or two behind, cannot tell. Measured at the later starts:

- three start saves have model-1 brigades three doctrine levels behind level with their country, and those four behind
  a level short; two days alone leave 48, 775 and 856 levels a level further back;
- Germany's 1939 reserves (organisation 35, own figure 45 at infantry_warfare 3, 50 at 4) gain a full hour's
  organisation, 35.077, where the share 35/45 > 0.75 would have slowed them to 35.053.

What consumer goods does with the flag, and what espionage and research do with nothing, was not followed.

## 11. A country's list of the provinces it controls is in the order the history's passes reached them

`CControllerChange::Apply` (slot 7, table 0x15CA124; VA 0x5FEB70..0x5FEED0) turns `XXX` into the null tag. Going forward,
where the province has no owner and the tag is real, it logs "<province> has no owner set when <tag> is set as
controller."; it keeps the province's controller at +0x18 and calls `Province_SetController(province, &tag, &date, 0, 0,
0)`. Going backward it calls the same with the kept tag.

So every controller entry the replay applies takes the province off the old controller's `ControlledProvinces` (+0xD00)
and appends it to the new one's (`CCountry_AddControlledProvince`). The replay goes in passes - undated to 2.1.1, then to
the defines' `start_date`, then `CSetHistoryDate` to the bookmark - each province by province. `RebuildOwnerAreas` (one
caller, reached for new and loaded games, VA 0x648CD2 -> 0x648D48) floods areas from those lists in list order. **So at a
later start, land the history gave a country after 1936 begins its areas after the rest**: Germany's Norway is its last
area and its theatre the last of three (numbers 1, 2, 4) in both 1941 start saves; by province number it came first.
Built that way, OpenHOI3 gives all 96 and 97 theatres of those saves. Two consequences:

- `RunCountryHourlyPass` builds a country's theatres right after its own units, before the next country's units. Japan
  takes Wake Island (10664) in the Day of Infamy's first hour after the United States' theatres were made with it: the
  save's USA theatre 76 holds Alaska, Hawaii, the Pacific islands and Wake, 31 provinces.
- A save writes only each province's controller, so after a load the lists are in province order (*inferred*).

## 12. `CAIStrategy::AddDefendProv` takes only a province the country controls

At VA 0x8A5139..0x8A5142, `mov edx, [ecx+0x338]; cmp edx, [esi+0xC]; jne` to the epilogue (checked off the listing by the
collecting session). `AddConquerProv`'s test (0x8A4FF9) is the owner (+0x330) being the country's, returning; the
record's "same shape, two differences" missed this third. So the declared capital the defend builder adds at 200 is left
off when another country holds it: France, Denmark, Norway, Belgium and the Netherlands have no capital entry in the
1941.12.11 start save. OpenHOI3 then gives `defend_prov` 73 of 73 at both 1941 bookmarks (60 and 65 before).

(Measured too, no new reading: `ParseReadKeyValue` drops the token after a key that is not `=`, so `army {` in
`SWE_DayOfInfamy.txt` and two `theatre {` in `JAP_DayOfInfamy.txt` are whole units, 232 unit numbers; and
`FINDINGS-bookmarks.md` 2.4's rule that only an owning country or REB has its file read accounts for the 315 numbers of
AUS, CZE and SPR at 1939.)

## 13. A history war goal goes through `CWarGoal::AddToWar`

*Read 2026-11-15 by `bm2-exile`; fragment `later-start-exiles.json`.* `CAddWarGoalChange::Apply` (rva 0x200170, slot 7)
is a history file's `war_goal` entry. Forward it calls `CWarGoal::AddToWar` (rva 0x651FB0) with the goal embedded at
`this+0x10` in EDI and the war at `[this+0xC]`; backward it erases the goal from the war's per-country bucket at
`war+0x9C`. AddToWar's only gate is `CWarGoal::IsValidWithTrigger` - the type's `is_valid` in the recipient's scope, THIS
the actor - and a goal that fails it is not added and stamps no cooldown.

`ExecuteHistory` replays every country's history before the wars' (`FINDINGS-bookmarks.md` 2.2), so at a later start a
goal on a country already in exile fails `conquer`'s `government_in_exile = no`, and France's `vichy_war_goal` fails once
the history has set `fr_signs_peace`. *Measured*: World War II at 1941.6.22 keeps only Germany's goals on the Netherlands
and the Soviet Union of the nine its file gives by then, and every `next_wargoal_date` of the four start saves is one goal
added so, stamped 1936.2.1.0 at every bookmark - the defines' start date plus `WARGOAL_ADD_COOLDOWN`, the lobby's tick.
Germany's goal on Belgium, had it stood, would have made `has_cb = { type = conquer }` hold for Belgium and kept France's
and Britain's `puppet`, and so their `protect` of 50.

## 14. `conquer_prov`'s own-land half is dead

`CAIStrategy_CollectConquerProvinces` (rva 0x4A67B0) skips the area test for a province the country owns (VA 0x8A68D8:
`cmp [province+0x330], [strategy+0xC]; je`). But `CAIStrategy::AddConquerProv` jumps to its epilogue at VA 0x8A5002 for
any province whose owner is the strategy's country, before adding anything (both checked off the listing by the collecting
session). So a country's own land held by an enemy is never on the list. *Measured*: no such entry for Norway's 810 or
Poland's 2096 at either 1941 start, nor China's 5420 at 1939.9.1, nor the Soviet Union's own provinces held by Germany at
1941.12.11.

## 15. An exile's day at a later start

Collected from `FINDINGS-surrender.md` C.5 and C.7, nothing read anew, and measured on the 1941 start saves:

- `CollectDailyProduction` runs for a country that owns land **or is in exile**, and adds `BaseResourceIncome` (5 metal,
  10 energy, 2.5 rare materials) whatever it holds: every exile's `home` in the 1941 saves is exactly that.
- The hand-over of supplies and fuel comes after `ConvertCrudeOilToFuel`, so the day's fuel goes too, and the supplies its
  shares make wait for the next day: the saves' exile pools hold no fuel, and their supplies are one day's `home`.
- Belgium's first-day usage (2.023 of IC) needs `CDistributeUpgrade`'s exile rule, the faction leader's level where it is
  higher.
- `ConsumeSuppliesAndFuel` charges an exile nothing at a friend's depot (`FINDINGS-supplypass.md` 4); without that the new
  game's filling of the provinces, which puts every stockpile back after each pass, piled about 2,000 of the exiles'
  payments into London.

## 16. What the two days post, the revert's walk, a pair block in an order of battle, and the enemies stamped

*Read 2026-11-15 by `bm2-rest`; fragment `later-start-laws-and-pairs.json`. The list link, the landless removal's want
of a diplomacy call (positive control: `CCountry_Capitulate`'s four) and the date loop checked off the listing by the
collecting session.*

- **The peace-time revert walks the law group backwards.** `CCountry_RevertDisallowedLaws` (VA 0x4D57D0) walks
  `law->group (+0x50)`'s list at `+0xC` from its head, a node's +0 the law and +4 the next. `CLawGroup::LoadKey` links
  each new law in front of the old head (VA 0x5297E5..0x529810), so the list runs opposite to `laws.txt`'s order and the
  law posted is **the last allowed law in the file's order** - the record said the first. *Measured*: at 1939.9.1 China
  (unity 69.998, effective neutrality 81.291), made Japan's puppet on the first day, holds `legalistic_restrictions`,
  `volunteer_army` and `basic_mobilisation`, where the file's first allowed would be `limited_restrictions` and
  `full_civilian_economy`. `confirmed`.
- **The command is free and silent before in_game**: its constructor keeps neither flag before `in_game` is set, so a
  revert posted in a new game's two days costs nothing and tells nobody. It waits in the session queue behind the
  `Laws()` posts made in the set-up; the queue's draining was not traced, in-order draining *inferred* - and the save
  fits it, China's laws being the revert's and not the look's.
- **Not every leaving of a war is a change of diplomacy.** `CCountry::OnDiplomacyChanged` has twenty direct callers -
  CustomGame_LeaveFaction 1; MakeVassal 2 (the overlord, then the vassal); CCountry_Capitulate 4; CFaction::AddCountry 1;
  CLeaveFactionEffect 1; CEndWarEffect 3; CUndeclaredWarRegionEffect 2; CDeclareWarAction 2; CCallAllyAction 3;
  CPeaceAction 1 - and none is in `CWar::RemoveAttacker`/`RemoveDefender`, `RemoveLandlessCountriesFromWars` or
  `AnnexCountry`. So the entry's end reverts no law. *Measured*: Estonia, Latvia and Lithuania keep `repression`,
  `service_by_requirement` and `total_economic_mobilisation` at both 1941 bookmarks.
- **An order of battle can carry a pair block.** `CCountry::LoadKey`'s fallback for an unknown key (VA 0x4CF237) looks
  the key up as a country tag (`CCountryDataBase::GetTag`); found, `diplomacy[id]` loads the block through its slot 3, so
  `CDiplomacyStatus::LoadKey` takes it key by key. Not a tag, a technology (its level held to a define, into +0x698),
  then a law. An order of battle goes through this loader (`CCountry::LoadOobFile`), so `SWE = { military_access = yes }`,
  the first line of Their Finest Hour's `GER_1941`, `GER_DayOfInfamy`, `GER_TheTideHasTurned` and `GER_1944`, gives
  Germany's record towards Sweden military access: both 1941 start saves hold it, the 1939 one does not, and no
  diplomacy history gives it. `confirmed`.
- **The history's wars stamp both sides.** In the lobby's replay `AddAttacker`/`AddDefender` update the joiner and each
  country on the other side, so `last_war` is 1936.1.1 both ways. A save shows only the joiner's side where the other
  owns no province by the date (SPR->SPA, CSX->JAP, IRQ->ENG, EST/LAT/LIT->SOV), because `CCountry::SaveContents` writes
  no record towards a country owning none. `SetUpCountryForNewGame` also stamps `last_war` = now towards each active war's
  enemies (VA 0x4D6912..0x4D69D5). *Measured*: all 52, 336, 503 and 2 pairs of the four start saves.
- **New Zealand's 1941 posts** are `OfficeManagement`'s picks at war, made in the AI pass at hour 0, the frame after
  Enter and before the first hour (`FINDINGS-government.md` E.1): NZL's gate (id + 17) mod 24 = 0 at id 79, the branch a
  chance draw. *Measured*: all eight managed posts. *Inferred*: the id. Not built in OpenHOI3.
- **The 1939 fronts**: China's cores given back as it becomes Japan's puppet go through `UpdateOwnerAreaOfProvince`,
  whose re-flood of Japan's area is the *likely* cause of the save's order; where the re-flood starts (after VA 0x47F93F)
  was not read.

## 17. What leaves the stockpile in a new game's first hour

*Read 2026-11-15 by `bm3-supplies`; fragment `later-start-supplies.json`. CarrySupplies' branches and ClearDailyPools'
stores checked off the listing by the collecting session.*

**A new headquarters brings its days.** `CCreateNewHQCommand::Execute` (rva 0x1E0BB0) places the new army with
`CUnit::EnterProvince` twice - at VA 0x5E0F97, then `CUnit::RebuildAvatar`, then again at 0x5E0FAC. EnterProvince runs a
gate before it writes `current_province_ptr`: the unit is not there already (`cmp [unit+0x130], province; je`), the
province is land (template +0x22), the unit is land (slot 15), and its army's +0x300 and +0x304 are both null - it is
aboard nothing. When all four hold it calls `CUnit::CarrySupplies(unit, province, 0, 0)` at VA 0x5BF313. A new unit's
current province is null, so the first call carries and the second does not.

With no previous province, CarrySupplies takes the owner's stockpile (`GetPool`) before the game is under way (`in_game`
+0xDA4, set at VA 0x65D126 after the first days). Under way (VA 0x5BEE6B..0x5BEEAA): where the province's `owner_id`
(+0x330) is the unit's owner (+0x128), **the stockpile**, whoever holds the province; otherwise, where its
`controller_id` (+0x338) is not the unit's owner either, **nothing**; otherwise - the unit's owner holding ground another
owns - **the pool of the province's depot** (+0x48), nothing where it has none. The record had the last two arms the
other way round. The unit's use is asked while it is still nowhere, so no commander's reach comes into it: for a fifth of
an `hq_brigade` that is 15 x 0.67 / 5 = **2.010 supplies**.

*Measured*: every country the AI gives a headquarters in the first hour has exactly that much less in its stockpile on
the first screen than a new game that carried nothing - 27 countries of `Germany1936_01_01_00` (Ireland 69.506: Dublin
2.010 less, Limerick 3.624 where it was 1.614); 1.800, 1.335 or 1.140 where `supply_consumption` laws apply; twice for
Romania, which got two; Ireland at every later start. `CCreateHigherCommand::Execute` (rva 0x1DF600) does the same
(EnterProvince at VA 0x5DFBE8, after the order-of-battle placing), and so do `CreateRebelsForFaction` (VA 0x4BAE8A,
0x4BAE9F) and `CUnitDeployment::DeployAt`.

**Its brigade holds no technology.** Both commands call `CSubUnit::SetType` (VA 0x5E0E11; 0x5DF91E), which builds the
technology list at level nought, and `CSubUnit::ApplyTechnologies` follows (0x5E0F1E; 0x5DFA5A) with nothing between that
sets a level: the figures are the type's template, and the upgrades raise them later. *Measured*: Ireland's Dublin
headquarters in `Ireland1941_06_22_00` holds every doctrine at 0 where Ireland holds `mass_assault` 3. The record's
"technologies applied" meant applied at nought.

**The energy conversion balances on the day's own pools.** `CCountry::ClearDailyPools` (VA 0x4F28B0) runs for every
country before the supply pass and zeroes `usage` (+0x994..+0x9AC), `sent_to`, `sent_back`, `tribute_received`,
`received_from_exiles`, `unit_demand` and +0xA1C; `UpdateIC` zeroes `conversion_used` and `conversion_made` as it begins
(VA 0x4F0CE4, 0x4F0D36), and `CollectDailyProduction` writes `home_produced` just before UpdateIC in
`RunCountryDailyPass`. So when the conversion block reads its fifteen pools, usage holds nothing of energy or crude oil -
industry is charged by the shares afterwards. *Measured*: with today's pools in place of yesterday's usage,
`Germany1936_01_01_00`'s crude oil and energy agree for 77 of 77 countries where 69 did; the United States converts 38.25
energy on both days. When the convoyed, traded, repaid and tribute-sent pools are cleared was not read.

**An order of battle's `expeditionary_owner` makes its unit lent**, through `CUnit::LoadKey`, as from a save: Their Finest
Hour's files lend 20 units by 1941.6.22 and 69 by 1941.12.11, each start save's count of the line, and the lender is then
the payer at a friend's depot (`FINDINGS-supplypass.md` section 4). *Measured* at 1941.12.11, what each paid for its units
drawing on friends' depots: Canada 11.872 against the save's 11.886, Hungary 12.103 against 11.588, Romania 39.799 against
38.748 - all nothing or less before.

## 18. What the first screen shows of the units' demand and the reinforcement and upgrade needs

*Read 2026-11-15 by `unitdemand`; fragment `later-start-unit-demand.json`. The carriage loop checked off the listing by the
collecting session.* A sweep of `.text` for every operand with displacement 0xA40..0xA5C, 0xA98 or 0xAA4 finds all the
writers.

**`unit_demand` (+0xA40):** `CCountry::CCountry` and `CCountry_Reset` set it to nought from the zero global 0x1A87818;
`CCountry::ClearDailyPools` zeroes it at the head of the day; `CUnit::ConsumeSuppliesAndFuel` adds each unit's ask at six
sites, the waiting units' included; and **the carriage**, at VA 0x4DB311..0x4DB3FA in RunCountryDailyPass straight after the
waiting units draw, walks the country's `ControlledProvinces` (+0xD00) and, for each province whose `units_count` (+0x2C0)
is above nought - or else whose naval base's `level_max` (+0x300 then +0x20) is above nought and today's throughput of
supplies (+0x1F8 then +0x8) is nought - adds `supply_depot_hops` (+0x50) x 1000 x SupplyLoss(province) / 1000 to
`unit_demand.supplies` (+0xA48): hops times loss. Fuel is left alone. **Nothing in Enter writes it, and no save keeps it**,
so a new game's first screen shows the second day's and a loaded game's nought until the first midnight;
`CDistributeSupply::GetNeeded` reads +0xA48.

**`reinforcement_cost` (+0xA98) and `upgrade_cost` (+0xAA4)** are written in play only by their shares' Distribute, each
zeroing the figure and adding every brigade's day of cost whether or not anything is spent (VA 0x51BBF6 and 0x51C5FC;
0x51CF4C and 0x51D4E1); the constructor and Reset set them to nought. Enter's run with nothing to spend (section 10) counts
them - the record's "reinforcement does nothing" there means it moves nothing - but for a new game the block at VA 0x65C7F0
comes after it, and its days count them again. So a new game's first screen shows the second day's needs, and a loaded
game's that run's; neither is saved.

*Measured* with OpenHOI3's second day, against no save, none keeping them: at 1936 the supply need is Germany 12.288,
Britain 20.871 and Ireland 0.148, and at 1941.12.11 Germany's 129.496, its divisions deep in the Soviet Union adding many
hops each. With the carriage built, the 1936 new game's written `distribution` is the start save's for seven more countries
(67 misses where there were 74), the AI's shares reading the supply need.

**The production need is counted the same way** (`prodneed`; `FINDINGS-production.md`, *The production need: who counts
it*). Enter's run with nothing to spend counts it at the end of `Distribute` for both kinds of game, a new game's days
count it again, and the Lua `Laws()` changes run after Enter reprice every line without counting it. So a new game's first
screen shows the second day's need at the second day's prices - Germany 13.984 at 1936, its queue then costing 16.159 -
and a loaded game's shows Enter's count of the queue as saved. `resources_needed` (+0x968) is filled on the entry IC
calculation too: the applyDailyEffects test at VA 0x4F106F jumps to `UpdateIC_IndustryNeed`, which reads TotalIC before
the cap (0x4F14A6) and the lend-lease (0x4F14C1).

## 19. The original capital is the declared one in a new game, and the supply loss's suppression

*Read 2026-11-15 by `chinaloss`; fragment `later-start-original-capital.json`. GetOriginalCapital's walk of +0xCD8 and
CCountry_Reset's call of CHistoryContainer::Reset checked off the listing by the collecting session.*

**China's stockpile at 1939.9.1.** China's history puts `capital = 5494` (Nanjing) at the top of its file and `capital =
9478` (Chongqing) at 1937.11.21. On the bookmark's first day China capitulates and becomes Japan's puppet, and MakeVassal
gives Nanjing back to its control (the save's 5494 carries `1939.9.1.0 = { controller = "CHI" }`). The first hour's
RunCountryHourlyPass runs CCountry::UpdateActingCapital for every country owning land, whose step 1 moves the government to
GetOriginalCapital where that differs from the seat and the country holds it - yet the save keeps `acting_capital=9478`,
with 771.250 crude oil, 837.034 metal and 3.200 money in Chongqing's pool. So GetOriginalCapital answers 9478.

**Why.** GetOriginalCapital walks the list at CCountry +0xCD8, which belongs to the CCountryHistory embedded at +0xCCC:
CCountry::CCountry builds it in place (`lea ecx, [ebx+0xccc]; call` the constructor at VA 0x5ECA30, owner at +0x20; the
object is 0x24 bytes and ends at +0xCF0, OwnedProvinces), CCountry_Reset empties it (CHistoryContainer::Reset at VA
0x4D46EA), and CGameState::ResetSession runs CCountry_Reset over every country before ResetGameStateToStartDate replays the
history. **The history files are not in it**: HistoryDatabase_LoadFiles allocates a separate CCountryHistory for each country
(`operator new(0x24)` and the constructor at VA 0x5F6FCE and 0x5F7FDB, then slot 3 with the parse) and keeps it in the
registry, and CCountryCapitalChange::Apply sets the capital with logHistory 0. So the record holds only what play logged -
CCountry_SetCapital with logHistory 1, from CCountry::EnsureCapital and CCapitalEffect::Execute (ReleaseProvinces passes 0),
CCountry::ChangeNeutrality and the other AddEntry sites. **In a new game, and after a load, the original capital is
therefore the declared capital** until the country first declares another, and that first declaration then stays the
original capital, the list being walked from its head. The province containers behave alike: no province of the 1936 start
save writes a history block, and every province history in the 1939 save is dated 1939.9.1.0, so the files' entries (5494's
own `1937.12.13 = { controller = JAP }`) are not in them. No save of the maintainer's writes a country `history` block;
whether the writer would write a non-empty one was not read. (`confirmed` for the walk, the embedded constructor, the reset
and the registry's separate objects; *measured* for China.)

*Measured*, OpenHOI3 with the history's first capital dropped: China's 1939 stockpile holds its supplies, fuel, money, metal
and rare materials to the thousandth, where it read nought of every good. Its crude oil (+1.800) and energy (+270.000) still
miss, beside a supply convoy Fuzhou - Tianmu Shan and 144 energy convoyed out in the save that OpenHOI3, grouping a new
puppet with its master at once (its compatibility entry 9), does not make.

**The suppression term of SupplyLoss** (VA 0x49DF1D..0x49DFD6). The figure is the province's own `suppression` (+0x28), the
daily province pass's SuppressionNearProvince, held between two bounds built at run time from floats - floor((float)0.0005
x 1000) = 0 and floor(1000.5f) = 1000. Where the controller is at war with the owner, the multiplier gains trunc(trunc(trunc(
LOCAL_PARTISAN_SUPPORT x 1000 / 1000) x PARTISAN_EFFECT_ON_SUPPLY_TAX / 1000) x (1000 - suppression) / 1000). Being the
province's day's figure, it is nought on a new game's first day and on a loaded game's. *Measured* in OpenHOI3, against no
save (none keeps the loss): Germany's first-screen supply need (section 18) 12.288 at 1936 as before, 59.371 at 1941.6.22
(64.716 before) and 77.882 at 1941.12.11 (129.496); the 1941.12.11 start save's brigades' strength 5513 of 5513 (5505), and
Germany's fuel used the save's; `supplypass` 185 to 187 of 222 networks at 1941.6.22 and 180 to 188 of 224 at 1941.12.11.

## 20. Land in no area goes to the enemy around it, every hour

*Read 2026-11-16 by `leftcontrol`; fragment `later-start-stranded-land.json`. The head's two tests and the call with its three
flags checked off the listing by the collecting session.* The middle of `RunHourlyProvincePass` (rva 0x9E600, VA
0x49E664..0x49EA42) - the `(1, 1, 1)` caller of `Province_SetController` that `FINDINGS-surrender.md` D.4 listed as not
read. It runs for an owned province (`+0x330` not nought) whose area (`+0x2B4`) is the `CNullOwnerArea` - one level of
infrastructure or none (`FINDINGS-supplynetwork.md` section 2). C is the controller's country.

1. The province's template edges are walked in order: an impassable edge (kind 3) is skipped, and so is a neighbour whose
   template is not `is_land` (+0x22); every other neighbour counts as land.
2. **A neighbour in a real area**: where `CCountry::CanOperateIn(C, neighbour's controller)`, nothing happens and the walk
   stops; otherwise, where `IsEnemyTag(C, it)` and C is not REB, it becomes the candidate - the last such neighbour wins.
3. **A neighbour in no area** is collected into a list.
4. **Where no land neighbour was in a real area**, the list is walked: `first` is the first neighbour's controller (`---`
   with none); the province stays where a neighbour's controller (not `---`, not REB) is `IsSameSide` with C, or is
   co-belligerent with C (`diplomacy[+0xE28]->+0x58`) and no enemy; an enemy neighbour becomes the candidate, and where it is
   not `first` the candidate is cleared and the walk stops.
5. Where the candidate is set: `Province_SetController(province, candidate, tick, 1, 1, 1)` (VA 0x49EA3D) - with
   consequences, an area rebuild, and peaceful: nothing damaged, production not zeroed, no capital looted. The
   CControllerChange it logs is the province `history` block a save writes at the hour.

It runs in a new game's hour before the first screen, so at a later start **it gives the start saves' controllers where the
history does not** (*measured*, OpenHOI3 built to this reading, 2026-11-16): Cyp (32) Finland's at 1941.12.11, 1943.2.1 and
1944.6.20, its land neighbours Finland's Pecenga and Finland-held Titovka, two levels each; Wadi al Hamim (5554) Britain's at
1941.12.11, beside British-held Bahi (two levels), its four Italian neighbours of one level; at 1943.2.1 four Algerian
desert provinces Germany's, Daraj (9307) back to Italy and Apamama (10637), whose one land neighbour is across a strait,
Japan's; at 1944.6.20 Munda and Buala Japan's and three provinces of New Guinea the United States' - fifteen in all. With
them every province's owner and controller is the save's at all eight start dates, 1936 to 1944; the save's other
start-hour entries are first-hour captures or the day's return.

*Looks wrong, is the bytes*: land changes hands with no unit near; beside an area the last enemy takes it and a neutral is
passed over; with no area beside it, a neutral holding the first neighbour keeps it in place.

And the base game's dated entries are not applied under a `tfh` province file of the same path: province 4979's base
`1938.9.1 owner = JAP` is absent from the 1938 save, and Cyp's base file gives no Finnish core at 1936 - so Cyp's Finnish
controller is not the base file's `1941.3.12` entry.
