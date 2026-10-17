# Fronts and theatres: what the AI's theatre layer draws, and the theatre headquarters it makes

Read 2026-10-17 for OpenHOI3's stage 5 (the military AI's first piece), in the collecting session, off the bytes of
`hoi3_tfh.exe` (TFH 4.02). Addresses are rvas unless marked VA. Builds on `FINDINGS-aitheatre.md` and
`FINDINGS-theatre2.md` (the theatre layer's map, the six `new CTheatre` sites), `FINDINGS-supplynetwork.md` section 2
(the owner areas the fronts belong to), `FINDINGS-aistrategy.md` (the strategy the theatres hang off, `CCountry
+0x48C`) and `FINDINGS-foreignminister.md` section E (the readiness test, which counts an area's fronts).

**In one paragraph.** Every owner area keeps its **fronts**: the runs of its provinces that touch another holder's land,
each flood-filled through the area. For one country an area's fronts are then split by **whose land each province
faces**, the country's front-worthy enemies winning, and a front where the country is at war is **hot**. A country's
**theatres** are made area by area from those: a front facing enough of the enemy's land gets a theatre of its own, two
named provinces get one for Germany and the United States, an area nothing claimed gets one whole, and the rest of the
area's provinces go to the nearest theatre and spread outward. The theatres are then merged - every one under thirty
provinces into its nearest, larger ones only where they share their enemies - and set beside the old ones by overlap,
so a theatre that survives keeps its id. Each theatre then has a **headquarters**: a theatre-level land unit already
standing in it, or a new one, a single `hq_brigade` placed about 150 behind the front, made at once and given the
orphans of any theatre headquarters removed before. Theatre-level units no theatre owns are disbanded.

**Mod-able or exe-hardcoded.** All of the arithmetic is **exe-hardcoded**: the size test (eight provinces, a quarter),
the thirty-province merge, the half overlap, the 150 and every multiplier of the headquarters' placing, the priority's
weights, the compiled-in table of who is a front-worthy enemy of whom (section D), and the four seats of section E.3.
Mod-able: the map (provinces, edges, regions), infrastructure, the `hq_brigade` unit type (taken by its key), the
`UNIT_START_EXPERIENCE` modifier, `NAMED_THEATHRE` and `THEATRE_NAME` in localisation, and the `REGIMENT_NAME` the brigade
is named by.

**The savegame is the oracle.** A country's theatres are saved under its strategy as `area_theatre` blocks - id, fronts
(provinces, `local_enemy`, `front`, `sea`), provinces, `unit`, `country`, `hot` and `key` - and the game state's next
theatre id as `theatre`. `Germany1936_01_01_00.hoi3` holds 108 of them for 78 countries, ids 5 to 311, `theatre=312`.

## A. When theatres are made

`theatres_dirty` is **`CAIStrategy +0xF4`**, which is **`CCountry +0x580`** - the same byte, the strategy being embedded
at `+0x48C`. The record had the two offsets as two fields.

1. **Every country starts dirty.** `CCountry::CCountry` (VA `0x4CA834`) calls `CAIStrategy::ClearCollectedLists(strategy,
   1)`, whose flag sets `+0xF4` (and empties the war targets and frees the theatres); `CCountry_Reset` does the same.
2. **The hourly fork** - `RunCountryHourlyPass` (VA `0x4D9079`), for each country in the session (`+0x44`), after its
   units' hour: **dirty: `BuildTheatres(strategy, false)`**; clean: **`MaintainTheatres(strategy, hour of day == id %
   24)`**. So a new game's first hour - the one hour of the two days a new game runs - builds every country's theatres
   from nothing, in the countries' order; that is why the start save's ids run 5 to 311 country by country.
3. **Set dirty** by: a change of a province's controller in a real area - the old and new controller and every distinct
   owner of a simulated neighbouring province (`Province_SetController`, step 9); infrastructure crossing 100 or 200
   (`CProvinceBuilding_OnLevelChanged`); `CCountry::OnDiplomacyChanged` (VA `0x4E7152`, twenty diplomacy-state changes);
   the ten-day strategy rebuild (`CCountry_AfterDiplomacyChange`, VA `0x4E3E63`, right after `Rebuild`); and the war
   targets' recheck dropping a target that is a neighbour (`CAIStrategy_RecheckWarTargets`, `FINDINGS-aistrategy.md` J).
4. **`BuildTheatres(strategy, true)` right after an unthrottled `Rebuild`**: `CCountry::UpdateAtWarAndEnemies` in a
   running game (VA `0x4E6CD3`), `CFaction::AddCountry` (twice), `CPeaceAction::Apply` (VA `0xA401B1`) - and the
   production screen's slider build for the player (VA `0x7FC925`), which with a played country only refreshes.

`BuildTheatres` (`0x4A9B10`) itself: nothing for `REB` or a zero id. **When `in_game` is set, the strategy already has
theatres, and the flag is false or the country is played**, it calls `RefreshTheatreProvinces(strategy, true)` (section
I) and returns. Otherwise it builds from nothing - so the hourly dirty fork only ever refreshes a running game's
theatres, and a full rebuild in a running game comes only from the four sites of 4, and only for a country no person
plays.

## B. An area's fronts (`COwnerArea +0x74`, and `+0x84` by the sea)

Made by **`COwnerArea::BuildFronts`** (`0x7D800`; the record had it as `CAreaBorder::CAreaBorder_2`), called for every
area `RebuildOwnerAreas` makes and every area `UpdateOwnerAreaOfProvince` touches. It frees both lists and goes through
the area's provinces in their order:

- A province **on a land border** (`CProvince_BordersForeignLand`, `0xA5E30`: any edge, **of any kind**, to a land,
  simulated province with another controller) and in no land front yet starts a new `CAreaBorder` (`sea` clear), which
  **`FloodFront`** (`0x7D4E0`) fills: push the province, then for each of its edges in order, a neighbour in the **same
  area**, on a land border and in no front of the area yet is flooded in turn - depth first, so a front's provinces are
  in that walk's order. The edge's kind is not looked at.
- A province whose template has a sea province beside it (`+0xA4`) also starts a sea front (`sea` set), flooded the
  same way through neighbours of the same area whose sea provinces share a region of `map/region.txt` with this one's
  (or both have none).

The sea fronts (`+0x84`) are read by nothing this file reaches. The land fronts are what everything below starts from,
and what the foreign minister's readiness test counts (`FINDINGS-foreignminister.md` E).

## C. A country's fronts of an area (`CollectAreaFrontsForCountry`, `0x7DA40`)

The record had it as a filter over `+0x74`. **It builds a new list**, the caller's, of fresh `CAreaBorder`s:

1. For each land front of the area and each of its provinces P in order: over P's edges **not of kind 3**, each
   neighbour that is simulated, land and **not held by P's controller** is looked at. Its controller becomes P's
   `enemy` if P has none yet; otherwise it replaces it if it is front-worthy (section D) or if the one held is not. And
   where that controller is not the country and is at war with it, or either of them is `REB`, P is **hot**, and the
   walk of P's edges stops there. A province on a land border only through an impassable edge has no enemy (`---`).
2. P then joins the borders already made for which `(P hot and the border hot) or the border's enemy is P's enemy`, and
   which P touches (an edge not of kind 3 to a simulated province of it, `CAreaBorder_Touches`, `0x7C850`). **None**: a
   new border with P, its enemy and its hotness, at the list's end. **One**: P is appended. **Several**: from the last
   found back, each is appended to the first found - the first becoming hot if either was - and taken out and deleted;
   then P is appended to the first.
3. Each hot border is given the area it **faces** (`+0x24`): counting, over every edge not of kind 3 of each of its
   provinces, the simulated neighbour's real area other than this one, the area with most edges - **the first of equals
   in the order of the areas' addresses**, a `std::map` keyed by pointer.
4. Each hot border, in order, is appended to the **first** other hot border facing the same area, and taken out.

## D. A front-worthy enemy (`CAIStrategy::IsFrontWorthyEnemy`, `0x4A9390`, read whole on the listing)

`(strategy, tag)`, in order:

1. The country itself: false. A subject: the answer for its overlord.
2. `IsWarCandidate` (`0x4A9A30`): an enemy; not a friend (`IsFriend(tag, false)`) and either a country of the tag's real
   faction is at war with us, or we are preparing war on it (`IsPreparingWarWith`) - true.
3. A friend (`CCountry::IsFriend(tag, true)`, military access counting): false. We a subject whose overlord is allied
   to it: false. We preparing war on it: true. A scenario running (`CCurrentGameState +0xD0C`): false.
4. **We are in no faction** (our faction's slot 7 false):
   - we FIN: NOR and GER false, SOV true; we JAP: CHC, CHI, CGX, CSX, KOR, MAN, MEN, SIK, CXB, CYN true;
   - any country we are at war with is in a real faction: false;
   - its faction is real and its ideology group is not democracy's (`GetIdeologies() +0x34`): true;
   - it is JAP or ITA and no subject: true;
   - otherwise true where `floor((sqrt((d*d/1000 + d*d/1000) / 1000.0f) + 0.0005) * 1000) >= 180000` with **d = our
     alignment x minus its x** (`CCountry +0xE4`) - **the x difference both times**, so the triangle's y never counts.
5. **We are in a faction**: its faction real and another: true. Then by our tag, against `CCountryDataBase`'s cached tags
   (all false within one faction): SOV - FIN, ROM, POL, EST, LAT, LIT, SWE, HUN, BUL, TUR, YUG, SLO, CZE, AUS, MAN, JAP;
   GER - HOL, BEL, LUX, POL, DEN; FRA - ITA (in another faction), and BEL or LUX by the rule below; BEL - LUX by that
   rule; ENG - ITA; JAP - CHC, CHI, CGX, CSX, KOR, MAN, MEN, SIK, CXB, CYN. **BEL and LUX for FRA, LUX for BEL**: false
   if the tag's overlord is us, Germany owns no province, or Germany is in our faction; otherwise true **where Germany is
   not at war with it**. Every other tag: false.

**Which tag each cached slot holds** is read off the cacher (`CCountryDataBase_CacheTag`, VA `0x515CC0`), arm by arm -
the string each arm compares and the slot its match stores to - and **from slot 29 on it is not the order of the
`.rdata` name array** the record took it to be (`FINDINGS-theatre2.md` section 1 checked only the first six):

| slots | tags |
| --- | --- |
| 0-5 | GER ENG SOV USA JAP FRA |
| 6-16 | ITA PHI CHI CHC CGX CSX KOR MEN SIK CXB CYN |
| 17-28 | BEL LUX HOL POL ROM HUN BUL TUR YUG SLO CZE AUS |
| 29-33 | MAN **NZL CAN SAF AST** |
| 34-38 | **DEN FIN SWE NOR EST** |
| 39-44 | **LAT LIT SCH SPA SPR ETH** |

So the first reading of this function, which went by the array, had LIT for FIN, LAT for DEN and SPA/SPR/ETH for
EST/LAT/LIT; the check against the save found it (section P).

## E. Building theatres from nothing (`CAIStrategy::BuildTheatres`, `0x4A9B10`, read on the listing)

For each area of the country (`CCountry +0xD30`, in order) with provinces: a **leftover** list of its provinces, the
country's fronts of it (C), and a **made** list.

### E.1 A theatre for a front

Each front whose enemy is not `REB` and is front-worthy: **home** is the sum, over the distinct real areas its
simulated provinces lie in, of the area's province count x 1000; **spill** the same over the distinct real areas of
simulated neighbours, by edges not of kind 3, **held by the front's enemy**. ratio = `spill * 1000 / home` (-1 when
home is 0). **Where spill is under 8000 and the ratio under 250** (`g_theatre_split_threshold`) there is no theatre.
Otherwise a new theatre (id from the game state's counter, `theatre`), the front given to it by `AddFront(theatre,
front, true)` (F) and taken off the fronts, `hot` = the front's, its provinces taken off the leftover.

### E.2 The fallback

**Where the leftover is still the whole area**, one theatre for the area, every province added (`AddProvince`, which
appends to both `+0x30` - the saved `provinces` - and `+0x60`, and stamps the province's theatre, `CMapProvince
+0x380`/`+0x384`).

### E.3 The four seats (`FINDINGS-theatre2.md` section 1)

Between E.1 and E.2. For **Germany**: Paris (province 2613) when fewer than two theatres were made for this area, then
Warszawa (1928) when exactly one was; for **the United States**: San Fransisco (3658), then Washington D.C. (4530). Each
only where the province is in this area, held by the country and not a front province (`CProvince::IsFrontProvince(P,
false)`); a new theatre, not hot, the province its key province (`+0x40`) and added, and taken off the leftover.

### E.4 The rest of the area

When something was claimed, two passes over the leftover, each repeated while it changed something and anything is
left:

- **Nearest**: for each leftover province P, the made theatre with the province nearest P - over the provinces of its
  fronts that are hot or face a front-worthy enemy, and its key provinces - by `16 x (dx*dx + dy*dy)` of the provinces'
  centres, dx wrapped at half the map's width; the first of equals. P is added to it only where P touches its `+0x60`
  provinces (an edge not of kind 3 to a simulated one).
- **Touching**: each leftover province P is added to the first made theatre it touches.

### E.5 The fronts no theatre was made for

Each, in order: its first province F0 goes with it; every other province P leaves whatever theatre it is in
(`CTheatre_RemoveProvince`, off `+0x30`, `+0x60` and `+0x40`, its stamp cleared), and where P's theatre is not F0's,
moves to a new front of the same enemy kept per theatre. The front, with what is left, is the front of F0's theatre.
Then **in the order of the theatres' ids**, each of those fronts is given to its theatre (`AddFront(theatre, front,
true)`) where a theatre has that id - a province no theatre took has the stamp 0 and is dropped.

So a theatre's `provinces` are its provinces off any front, and each front its own.

## F. `CTheatre::AddFront` (`0xAF580`) and the order of a front

With `reorder` set (every call but the merge's), the front's provinces are taken out and put back as a **chain**:
while some are left, the start is the left province with fewest neighbours among those taken out - edges not of kind
3, simulated, in the province's own area - the first below 100 seen and **the first under two taken at once**; from it
a depth-first walk (`CTheatre_ChainFront`, `0xAF3C0`) over edges not of kind 3, to provinces of the same area,
simulated, not yet put back and among those taken out. Then, with or without the flag, each province is stamped with
the theatre and appended to its `+0x60`, and the front appended to its fronts (`+0x50`).

## G. Merging (`0x4AB4CE` on)

First each made theatre's **areas** (`+0x84`: the real areas of its `+0x60` provinces, in the order of their
addresses) and **ports** (`+0x94`: its provinces with a naval base, the largest first, equal ones in turn) are made
(`CTheatre_RebuildAreas`, `0xB1550`). Then, while anything is made: **S** is the made theatre with fewest `+0x60`
provinces, the first of equals, and for every other made theatre O, O is a **candidate** where

- S has fewer than 30 provinces, or more theatres are made than the limit (100000; for a played country at war, the
  number its strategy holds);
- or both have the same largest area (`+0x84`'s with most provinces, the first of equals), S faces a front-worthy
  enemy, and **O's front-worthy enemies are S's** (as many, each found) or **their fronts meet** (`CTheatre_FrontsMeet`,
  `0xB1C00`: the first or the last province of one of O's front-worthy fronts has, by an edge not of kind 3, a
  simulated neighbour that is the first or the last province of one of S's).

The candidate with the least `1000 x distance + 1000 x (O's and S's provinces)` wins, distance being the integer
square root of the least `16 x (dx*dx + dy*dy)` between their `+0x60` provinces (Newton's method from half). **No
candidate: the merging stops**. Otherwise S's fronts go to the winner (`AddFront(winner, front, false)`, the winner hot
if one was), then its `provinces` (`CTheatre_TakeProvinces`, `0xAFBA0`), the winner's areas are made again, and S is
deleted.

## H. Set beside the old theatres

The strategy's theatres are taken off it. For each made theatre N in order, the old theatre with the greatest overlap
- `shared provinces x 1000 / old provinces`, both `+0x60`, 0 where either is empty - **the first to reach 500** ending
the search: **at least 500**, the old theatre takes N's contents (`CTheatre::TakeOver`, `0xAF1D0`: its fronts, keys,
provinces, areas, ports and priority made N's, keeping its own id and headquarters) and goes back on the strategy, and N
is deleted; **otherwise N** goes on. Either way the theatre's provinces the country holds are stamped with it and its
key provinces it no longer stamps dropped (`0xAFD30`), and it is listed for the AI's agents. Every old theatre left over
is **deleted, and its headquarters unit queued for removal** (`CGameState::QueueUnitRemoval`) - where the theatre's
`unit` still exists - after its agent is told. Then `MaintainTheatres(strategy, true)`, the allies' agents told
(`0x4AC390`), and `theatres_dirty` cleared.

## I. Refreshing (`CAIStrategy::RefreshTheatreProvinces`, `0x4ABC90`)

With the flag: each province the country holds whose stamp names no theatre of the country is placed
(`CAIStrategy_PlaceProvince`, `0x4AC000`): nothing outside a real area or not simulated; **in an area of one province**,
the theatre whose headquarters is the root of a land unit of the country's standing there; else the theatre most of
its neighbours (edges not of kind 3, simulated, the country's) are stamped with - **the first of equals in the order of
the theatres' addresses**; else the theatre whose `+0x60` has the nearest province (`CMap::DistanceBetweenProvinces`).
Then each theatre's provinces the country no longer holds are dropped (`0xAFA70`: off its fronts, `+0x30`, `+0x40`,
`+0x60`). Then every theatre: stamps (H), areas and ports (G), and **its fronts made again** (`CTheatre_RebuildFronts`,
`0xB1790`): not hot, fronts freed, and for each of its areas the country's fronts of it (C), each keeping only the
provinces stamped with this theatre (taken off `+0x60` to be put back), given to it with `AddFront(…, true)`, the theatre
hot if one is. A theatre left with no provinces has its agent told to go. Then `MaintainTheatres(strategy, true)`.

## J. Every hour (`CAIStrategy::MaintainTheatres`, `0x4AC400`)

Nothing for `REB` or a country out of the session (`+0x44`). For each theatre in order:

1. **Its headquarters**: where `unit` names no unit, the country's units in order are looked at: the first land unit of
   level 0 (`oob_level`) standing in a province stamped with this theatre, whose order of battle's root is no theatre's
   headquarters or this one's (`FindTheatreForUnit`), **becomes it**, and any agent of that unit is pointed at the
   theatre. Failing that a new one (K) is made where the theatre has a province for it.
2. **Its priority** (`+0xA4`), only in the country's hour or while it is under 1: P = the TotalIC x 1000 of each
   distinct front-worthy enemy its fronts face; + 10000 where an area of it is the acting capital's (real); + 1000 x its
   `+0x60` provinces / 30 (cut); + 1000 x the sum of its headquarters' `plan_subunit_difference` where positive; and
   where any front-worthy enemy faced is at war with the country (or `REB`), x 2.000 if the acting capital's area is in
   it, else x 1.500 (64-bit, cut). Then **every theatre's priority** is made `P x 1000 / the sum` - or `1000000 /
   (theatres x 1000)` each where the sum is not above 0, which is every hour but the country's own, those hours computing
   nothing.
3. **In the country's hour**: for a country no person plays, or before `in_game`: each unit of level 0 that is no
   theatre's headquarters (`FindTheatreForUnit` null) has its agent told and **a `CDisbandCommand` posted** for it
   (`0x489BD0`). For a played country in a running game, instead, each such unit is given a new theatre of its own.

## K. A new theatre headquarters

**Where** (`CTheatre_PickHQProvince`, `0xB0A00`): over the theatre's `+0x60` provinces in order, those with effective
infrastructure (`infrastructure x (1000 + local + global) / 1000`, held between 10 and 1000) **of at least 200**,
simulated and stamped with the theatre; not one with a neighbour (any edge) holding a land unit, or a fleet carrying
land units (`CNavy +0x2EC`, the count of its `carrying` list), of a country at war with this one (or `REB` either side),
nor one with a land battle (`combats`, kind 1). The first such is the fallback; each is scored `|150 - mean distance to the theatre's front provinces|` (each front
province counted once per front, `CMap::DistanceBetweenProvinces`, the mean cut), **x4** where it borders a front
province, **x2** where it borders another holder's land (B), **/3** where it is its controller's capital, **x100**
where it is itself a front province; the least wins, the first of equals. No province: no headquarters.

**What** (`CCreateNewHQCommand`, built by `MaintainTheatres` with the next unit id, the counter then **raised by two**,
and its `Execute` run at once, not posted): a `CArmy` of level 0 with that id, the country's, and one `hq_brigade` (the
next id) whose home is the province, experience `UNIT_START_EXPERIENCE x 1000 / 5000` (at most 100%), **strength a
fifth of its most** (not under 0), its highest that, technologies applied; the brigade named by `REGIMENT_NAME`; the
unit placed in the province, its avatar rebuilt; **named** by `CCountry::MakeUnitName` at level 0 with the province:
`NAMED_THEATHRE` with PROV the name of the theatre's province with most `victory points x 10000 + 5000 for a naval base
+ its ic modifier` (the first of equals), or `THEATRE_NAME` numbered where that is taken; the best leader where it has
none and the country assigns them; a battle looked for. **A name is taken only within its country**: `MakeUnitName`'s
in-use test and `RegisterUnitName` (`0xCB450`) both go to a set at `CCountry +0x84` - the record had that function's
country argument as unused - so the Dominican Republic and Chile both have a `Santiago HQ` on the start save. **Then, for
a level-0 headquarters, the theatre stamped on the
province - where it is the country's - takes it as its `unit`, and every unit of the country of another level flagged
an orphan (`CUnit +0x50`) is attached under it**, the flag cleared. `CGameState::RemoveUnit` flags the children of a
removed level-0 unit so - the only writer of the flag.

So theatre headquarters the history leaves with no theatre are disbanded in the country's first hour, and their
children hang under the next headquarters the country is given. **Which theatre the history's other top-level units -
fleets, air units, armies - are put under is not here**: it is the AI's unit agents' (`CAIUnit`), the next piece.

## L. Constants

| | value | where |
| --- | --- | --- |
| spill alone that makes a front a theatre | 8000 (8 provinces) | `0x4A9B10` |
| ratio that does | 250 | `g_theatre_split_threshold`, VA `0x1B15028` |
| a theatre small enough to merge anywhere | 30 provinces | `0x4AB642` |
| merge limit | 100000, or a played country at war's theatre count | `0x4AB4F5` |
| overlap that keeps an old theatre | 500 | floor of 500.5 at VA `0x160A5E8` |
| headquarters' least infrastructure | 200 | VA `0x1A86EAC`, floor of 200.5 at VA `0x160A64C` |
| effective infrastructure's floor | 10 | floor of 10.5 at VA `0x160A680`, local static VA `0x1BEA400` |
| headquarters' distance behind the front | 150 | `0x4B0E84` |
| priority's multipliers at war | 1.500, 2.000 with the capital | VA `0x160A818`, `0x160A5F4` |
| priority for the acting capital | 10000 | `0x4AC851` |
| a new brigade's strength and experience | a fifth (x 1000 / 5000) | `CCreateNewHQCommand::Execute` |
| ids, a new game | `theatre` and `unit` start at 1 | VA `0x170AEBC`, `0x170AF78` |

## M. What looks wrong and is what the bytes do

1. **The alignment distance counts the x difference twice** and the y never (D.4).
2. **A front province on a land border only by an impassable edge** is in a front, enemy `---` (B and C.1).
3. **Hotness ends a province's walk**, so its enemy is the last one seen before a hot neighbour (C.1).
4. **The faced area and the order of a theatre's areas go by memory address** (C.3, G, I).
5. **Every hour but the country's own, every theatre's priority is the same** (J.2).
6. **A merge winner is chosen by nearness plus size**, so a large theatre near a small one is preferred less (G).
7. **An old theatre that loses the overlap test is deleted and its headquarters removed** - a history headquarters
   adopted by it with it (H).
8. **Orphans go under the first new headquarters**, whichever theatre it is (K).
9. **The merge's `AddFront` does not reorder**, so a merged theatre's fronts keep the order they had (G).

## N. Corrections to the record

| record | read |
| --- | --- |
| `CollectAreaFrontsForCountry` "clears the caller's list and fills it from `+0x74`, filtering" | builds new borders by enemy and hotness, merges and faces them (C) |
| `0x7D800` `CAreaBorder::CAreaBorder_2` | `COwnerArea::BuildFronts`, the land and sea fronts (B) |
| `CTheatre::AddFront`: "only the first ~60 instructions were read", flag meaning unknown | read whole (F) |
| `MaintainTheatres`: "what it does beyond that was not read" | read whole (J) |
| `RefreshTheatreProvinces`: "re-sorts those provinces" | read whole (I) |
| `CCountry +0x580` and `CAIStrategy +0xF4` as two fields | one byte |
| `0x4B0A00` (inside the range named `CAIUnit::DistanceToTheatreFronts`) | `CTheatre_PickHQProvince`, a function of its own |
| `0x5E0BB0` inside `CCreateHigherCommand::LoadKey`'s range | `CCreateNewHQCommand::Execute`, slot 6 |
| `IsFrontWorthyEnemy`: "the tail past `0x8A98D0` ... not read" | read whole (D) |
| `IsFrontWorthyEnemy`'s tables: SOV against LIT/.../SPA/SPR/ETH, GER against .../LAT | SOV against FIN, EST, LAT, LIT ...; GER against ... DEN; the no-faction case FIN, not LIT (D) |
| the 45 cached tags of `CCountryDataBase` in the `.rdata` array's order (`FINDINGS-theatre2.md` section 1) | so only to slot 28; slots 29 to 44 are MAN NZL CAN SAF AST DEN FIN SWE NOR EST LAT LIT SCH SPA SPR ETH (D) |
| `RegisterUnitName`: "the first argument, a country, is not used" - one set for the game | the country's set at `CCountry +0x84` (K) |

## O. Not established

- Who reads the sea fronts (`COwnerArea +0x84`).
- ~~What puts the history's top-level fleets, air units and armies under a theatre in a new game's first hour - the unit
  agents', for the next piece.~~ - the sort at the first AI pass, `FINDINGS-agents.md` section G, which also finds that K's orphan rule moves nothing in the 1936 start.
- `0x4AC390`'s and `CEU3AI::EnsureAgentForArea`'s effect on the agents, and `CEU3AI +0x2C` (whether a country's AI runs
  units) - the next piece.
- `0x508C30`, called by `RunCountryHourlyPass` just before the fork.

## P. Checked against the start save

OpenHOI3 built all of this (`OpenHOI3/docs/mechanics/theatres.md`) and set a new game's theatres beside
`Germany1936_01_01_00.hoi3`'s `area_theatre` blocks (`OpenHOI3.SaveCheck theatres`): **all 108 theatres of all 78
countries agree** - their numbers, headquarters, heat and key provinces, every front's provinces in order with its enemy
and heat, and each theatre's own provinces in order - and the next theatre number is the save's 312. Every one of the
86 headquarters made has the save's number, name and place, and its brigade the save's name, strength and highest. Two
readings were corrected on the way, both found by the check: the cached tags past slot 28, without which the Soviet Union
had four theatres for nine and Germany one number short (its Danish front is front-worthy); and the names registry,
without which Chile's headquarters was `2nd Theatre`. The brigades' experience (42 of 86) and organisation (1 of 86) are
the save's only where the two days ran under the same laws: the original's AI changes laws around those days, and a
change of law after them holds every brigade to its running ceiling (`OpenHOI3/docs/mechanics/tick.md`, section 6).

## Trap check

Trap 1: every address in the prose is an rva unless marked VA; the fragment's are rvas. Trap 2: `0x4B07D0` ends `ret`
at `0x4B08BC` and `0x4B08C0` is a separate function, so the record's `CAIUnit::DistanceToTheatreFronts` (`0xB08C0`) is
not this; `0x4B0A00` begins after it. Trap 3: `BuildTheatres` has an interior `ret` at VA `0x8A9C2A` (the refresh arm)
and the decompiler's `free(...); return;` arms inside the list walks are not exits - every list removal was read on
the listing. Ghidra's local names in `CCreateNewHQCommand::Execute` swap the country and the province; the listing's
`[esp+0x10]` is the province.
