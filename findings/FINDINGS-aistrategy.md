# The AI strategy: who a country fears, courts, antagonises and protects

Read 2026-10-16 for OpenHOI3's stage 5 (the AI strategy the foreign minister's Lua reads), in the collecting session,
off the bytes of `hoi3_tfh.exe` (TFH 4.02). Addresses are rvas unless marked VA. Builds on `FINDINGS-ai.md` (who
consumes `CAIStrategy`), `FINDINGS-triggereval.md` sections 6, 12 and 17 (the weighted walk and the ten adders),
`FINDINGS-aitheatre.md` (the embedded strategy at `CCountry +0x48C`) and `FINDINGS-foreignminister.md` (the prepared
wars at `+0x148`).

**What the Lua reads of it.** `CAIStrategy:GetFriendliness(tag)` is the `befriend` hash, `GetAntagonism` the
`antagonize` hash, `GetThreat` the `threat` hash, `GetProtectionism` the `protect` hash, each 0 where absent, and
`IsMilitarist()` is `Personality == 1`. The install's scripts call them 46, 26, 25, 3 and 3 times, in diplomacy, trade,
licences, politics and five country files. This write-up is what fills those hashes.

**Mod-able or exe-hardcoded.** The `add_ai_strategy` effect and a scenario's `ai_hard_strategy` are mod-able inputs, and
so are the victory conditions of `common/faction_aims.txt`, which the rebuild walks (section D.3); the base game uses
neither effect nor block, so every list of a new game is the engine's own arithmetic. **That arithmetic is
exe-hardcoded throughout** - every weight, cap, threshold and the personality rule below is a float in `.rdata` or a
literal, and no define reaches any of it.

**The savegame is the oracle.** Every country's merged strategy is saved under `ai = { ... }`, one rebuild's worth
(section A). The start save `Germany1936_01_01_00.hoi3` holds 101 of them.

## A. When a strategy is rebuilt

`CAIStrategy::Rebuild` (`0x4A5C90`) starts from nothing every time (`ClearCollectedLists`). It is reached:

1. **On entering a game**, from `CInGameIdler::Enter` at VA `0x65C282`, for every country in a loop after
   `CCountry::RebuildNeighbours` and `RebuildStaticModifiers` - **before** the weather's 96 hours (VA `0x65C86A`) and the
   two days a new game runs. So the strategy a new game's first screen holds was made before those days.
2. **Every day, every ten days**: `RunDailyPass` (VA `0x682E0F`, the loop that then calls `RunCountryDailyPass` at
   `0x682E1A`) calls `CCountry_AfterDiplomacyChange` (`0xE39C0`) for every country in the session (`+0x44`), and that
   rebuilds **in a running game** (`in_game`) when the whole days since `rebuild_tick` (`+0x10`) are 10 or more - days
   as `(tick - 43800000) / 24`, the year arithmetic in between cancelling out. The same function is the tail of 64 other
   call sites - every diplomatic effect, `CTradeAction::Apply` (4), `CInfluenceNation::Apply`, `CMapProvince::TakeControl`,
   coups, vassals, convoys, the decision and diplomatic-action commands - and each of those also rebuilds only past the
   ten days, so they move *when* in the day a ten-day rebuild falls, not how often.
3. **The daily pass's first-time rebuild**: `RunCountryDailyPass` at `0xDB7AF`-`0xDB7C4`,
   `if (!initialized && !static) Rebuild()` - for a country no earlier rebuild reached, as one whose rebuild bailed
   because it owned nothing.
4. **At once, unthrottled**: `CCountry::UpdateAtWarAndEnemies` in a running game (both sides of each
   `CWar::AddAttacker`/`AddDefender`/`RemoveAttacker`/`RemoveDefender`), `CFaction::AddCountry` (twice),
   `CPeaceAction::Apply`, `CAddAIStrategyEffect::Execute`, `CCountry_SetGovernment` (with its history flag) and
   `CCountry_UpdateActiveMission` when a mission starts.

**The guard** (`Rebuild` itself): the strategy's country id non-zero and not `REB`, the country owning a province
(`+0xCF8 > 0`), and its acting capital's area (`CProvince +0x2B4`) answering its slot 0 - a real area, not
`CNullOwnerArea`. Then `ClearCollectedLists(this, 0)`, `rebuild_tick = tick`, and in order:

| step | rva | what |
| --- | --- | --- |
| 1 | `0x4A5DD0` | the personality (section B) |
| 2 | `0x4ACE20` | the production shares (section C, not built by OpenHOI3) |
| 3 | `0x4AD430` | `max_subunits` (section C) |
| 4 | `0x4A62A0` | `ApplyCountryAIStrategies`: the merges, the walk and the lists (section D) |
| 5 | `0x4AD6E0` | the war targets rechecked (section J) |
| 6 | | `initialized = 1` |

**The 1936 saves bear the schedule out.** Between `Germany1936_01_01_00` and `Germany1936_04_20_03`, 68 countries' lists
differ and 33 are the same - the threat lists move with every regiment built - and Britain's `antagonize` is the same in
both (section D.3), as a list made from the same victory conditions would be.

## B. The personality (`0x4A5DD0`, read on the listing)

`Personality` (`+0x18`) is first set to the event strategy's (`CCountry +0x34C`, `ai_event_strategy +0x18`) where
non-zero, else the hard strategy's (`+0x1F4`), else 4. **Where the strategy is not `static` (`+0x15`), it is then worked
out and that overwrites it**:

- `n` = the government's ideologies (`CCountry +0xDFC`, its list `+0x30`, count `+0x38`), at least 1; `share` =
  thousandths of `1.0 / n` through the float idiom `floor((float)(x + 0.0005) * 1000)`.
- For each of the government's ideologies, `w` = `share`, doubled (`share * 2000 / 1000`) for the ruling party
  (`CCountry +0x1140`). Its group's position (`CIdeologyGroup +0x58` x, `+0x5C` y, thousandths) gives three scores:
  - **military** = `y / 2`, and where `y > 0`, plus `(y + |x|) * 0.5` for `x >= 0` or `(y - x) * 0.33` for `x < 0`;
  - **capital** (industrialist) = `-x` for `x < 0`; for `x >= 0`, `(x + y) / 2` where `y < 0`, else 0;
  - **diplomacy** = `(200 - |x / 1000|) * 1000 / 2 - y / 2` (the first term in whole units of x, truncated).
  - each summed as `score * w / 1000`.
- `total` = the three sums, at least 1000. Then **in this order**: military's share of the total (`* 1000 / total`)
  at least 400 → 1 (`military`); diplomacy's → 3 (`diplomacy`); capital's → 2 (`capital`); else 4 (`balanced`).

The save names them `military`, `capital`, `diplomacy` and `balanced` (`CAIStrategy::SaveContents`, `0x4A4860`). With
the base game's corners - fascism (200, 200), democracy (0, -146), communism (-200, 200) - an all-fascist government
is military (Germany: 1500 of the total), an all-democratic one diplomacy, and a mixed one usually balanced: the start
save's 101 merged strategies are 51 `military`, 27 `diplomacy`, 23 `balanced` and no `capital`.

## C. The production shares and `max_subunits` (read, not built by OpenHOI3)

`0x4ACE20` sets `land_perc` (`+0xFC`), `air_perc` (`+0x100`), `naval_perc` (`+0x104`) and `armor_bias` (`+0x108`):
air 0.050, naval 0.400 x the share of the country's provinces in coastal areas other than its capital's, plus 0.100;
where `TotalIC` (`+0x604`) is under 50 (its unit not checked here), naval halved at peace and naval and air nought at
war; air nought above a desperation of 0.100; then
cases by tag - `GER`, `ITA`, `JAP`, `USA`, `ENG`, `FRA`, `SOV`, each against two or three fixed provinces' owners and
friendships - and land is the rest of 1. `armor_bias` is 0.250, 0.330 for Germany as faction leader, 0.050 for Japan.
Germany's start block is land 0.823, air 0.050, naval 0.127, armour 0.330. **What reads these was not sought**; they
are the military AI's.

`0x4AD430` (receiver in `ESI`): `max_subunits` (`+0xF8`) = 5 x the whole IC of the home area (`CCountry`
`core_home_area_ic / 1000`), at least 1 - a plain count, which the save writes with `%d` (Germany 665).

## D. `ApplyCountryAIStrategies` (`0x4A62A0`): the merges, the walk, then the lists

In order:

1. `MergeAIStrategy(this, ai_hard_strategy)` and `MergeAIStrategy(this, ai_event_strategy)`: every entry of their ten
   lists re-added through its own adder, so weights add.
2. **The walk** (D.3), skipped where the country is played and the local player's automation flag `[1]` is not 1.
3. **Military access** (section I, read in part).
4. Where the strategy is not `static`, the lists, each followed by its scaling (section H):

| order | rva | builds | then scaled |
| --- | --- | --- | --- |
| a | `0x4A67B0` | `conquer_prov` (E.1) | |
| b | `0x4A6980` | `defend_prov` (E.2) | |
| c | `0x4A6AC0` | `threat` (F) | `threat` |
| d | `0x4A73C0` | `antagonize` and `rival` (G.1, G.2) | `antagonize`, `rival` |
| e | `0x4A8250` | `befriend` and `vassal` (G.3) | `befriend`, `vassal` |
| f | `0x4A8AF0` | `protect` (G.4) | `protect` |

**The order matters**: `antagonize` reads `conquer_prov` and its own entries as it goes, `befriend` reads the scaled
`threat` and `antagonize`, and every adder trims to its cap as it goes, so an entry the walk added can be pushed out by
a stronger one later.

### D.1 The lists and their adders (`FINDINGS-triggereval.md` 17, which stands)

Each list is kept sorted high to low; adding a key that is there adds to its weight and re-inserts it, below any equal;
a total under 1 removes it; a new key with a weight of 0 or less is not added; a country never records itself. After
each add, the list loses its **lowest** entries until it is within its cap: `threat` none, `antagonize` 7, `befriend` 7
(14 for `diplomacy`), **`protect` 6 (12 for `diplomacy`)** - not befriend's 7 and 14, which the record had (section M) -
`rival` 4, `vassal` 10, `military_access` 10, `conquer_prov` 40 (60 for `military`), `defend_prov` 1000. Every cap was
checked on the listing.

### D.2 The mission (root 1)

Where the country has a mission (`CCountry +0xE40`) whose slot 6 holds, its embedded trigger at `+0xC4` is walked with
weight 600 in the mission's own scope (`+0xE44`). Missions are a scenario's; the base game's canonical start has none.

### D.3 The victory conditions (root 2), and what the walk reports

Where the country's faction is real (its slot 7), the faction's index in `CVictoryConditionManager +0x8` is found, and
**each condition chosen for this game** (`+0x18`, `FINDINGS-factionplay.md`) has its `trigger` (`CVictoryCondition
+0x24`) walked with weight 200, in a scope of the country alone (`CEventScope(0, 0)`, country set).

The walk is slot 10 (`FINDINGS-triggereval.md` 6 and 12): a block passes its weight to each child (`CTrigger`,
`0x5D0680`); `OR` passes `weight / children`, at least 1 (`0x5D1270`); `NOT` flips the `negated` flag
(`0x5D1340`); a scope (`CContextTrigger`, `0x5D2470`) makes its scope and walks its children only where it resolves.
**The leaves the base game's faction aims use** - read 2026-10-16:

- **`faction`** (`CFactionTrigger`, `0x5FCB30`): not negated, and the collector's country's faction **is** the
  trigger's faction, and the condition does **not** hold in the scope → where the scope has a province (or its `THIS`
  has one), `AddConquerProv(province, weight)`; otherwise **`AddAntagonize(the scope's country, weight)`**.
- **`controls` and `owns`** (one body, `0x5D5F10`): not negated, the scope's country is the collector's, and the
  condition does not hold → `AddConquerProv(the trigger's province, weight)`.
- **`owned_by`** (`COwnedByTrigger`, `0x5DF8A0`): in a province scope; not negated - the tag is the collector's and the
  condition does not hold; negated - the tag is not the collector's and the condition holds; either way
  `AddConquerProv(the scope's province, weight)`.
- `year` and every leaf that keeps `CTrigger`'s body report nothing.

**The rest, read the same day** once OpenHOI3's check against the start save showed the region scope was needed:

- **A region** (`CRegionScopeTrigger`, `0x5DCC20`): its children walked **once for each province of the region**, the
  copied scope's province set to it and the country kept. `comintern_east_germany` is a region block, and it is what
  puts Germany at the top of the Soviet Union's, Mongolia's and Tannu Tuva's `antagonize`.
- **`any_neighbor_province`** (`0x5DD240`): once for each edge of the scope's province whose province has an owner;
  **`any_owned_province`** (`0x5DDA20`): once for each province of the scope country's list; **`any_neighbor_country`**
  (`0x5E6300`): once for each of its neighbours, the country set and the province kept; **`any_core`** (`0x5E6820`): once
  for each core of the scope's province, likewise.
- **`exists`** (`0x5DABA0`): only negated, and where the condition holds: antagonise the tag.
- **`war_with` and `undeclared_war_with`** (one body, `0x5EB000`, newly recorded): not negated, where the scope's country
  or the tag is the walker, antagonise the other of the two - **without evaluating the condition**.
- **`alliance_with`** (`0x5EFB60`): where the scope's country or the tag is the walker, befriend the other by the weight
  and antagonise it by minus it, both signs flipped when negated - **without evaluating**.
- **`relation`** (`0x5DEFA0`): its `who` resolved; where it or the scope's country is the walker, the other is
  antagonised when negated and befriended when not - **without evaluating**.
- **`vassal_of`** (`0x5EF4B0`): not negated, the tag the walker and the condition not holding: `vassal` of the scope's
  country, and antagonise it and befriend it by minus the weight - the other way round for a `diplomacy` walker.
- **`has_building`** (`0x5E4A50`): `building_prov` of the scope's province and the building, not negated and not
  holding; **a unit type** (`CSubUnitTrigger`, `0x5DB2F0`): the count added to the strategy's per-type array at `+0x138`,
  likewise. Both feed the military AI.

Their Finest Hour's aims are all `<province> = { controller = { faction = <own> } }` (with `NOT`, `OR`, `year` and
two country scopes): the `controller` scope has no province, so **each block whose controller is outside the faction
antagonises that controller by 200** - or by the `OR`'s share. That is Britain's `antagonize` in both 1936 saves:
`ROM` 400 (scaled), `GRE`, `USA`, `BUL`, `NOR`, `BEL` - the six `allied_*` aims' countries - and `TAN`. **Germany has
none of it because it is played** (step 2): its list is the formula's alone.

So every slot-10 body of the image's twenty is now read.

## E. The province lists

### E.1 `conquer_prov` (`0x4A67B0`)

Every province of the map in index order that is land (`path_node +is_land`), owned (`owner != 0`) and not controlled
by the country, where (**the country is `military`** or it is at war with the owner, `IsEnemy`) and (the owner is the
country, or the province's area touches land the country controls, `OwnerArea_TouchesController`) and the province has
a real strategic resource (`CMapProvince +0x18`, slot 14: `ReturnTrue` on `CStrategicResource`, `ReturnFalse` on the
null one): **`AddConquerProv(province, 50)`** (the float 50000.5, floored and taken to whole units). Every
`conquer_prov` of the three 1936 saves is 50 - 142 and 144 entries in 32 countries.

### E.2 `defend_prov` (`0x4A6980`)

`AddDefendProv(capital province (+0xE20, the real one, not the acting), 200)`; then for each province the country
controls (`+0xD00`, list order): 50 for a real strategic resource plus 20 for an air base built (`air_base->Max > 0`),
added where above nought. Germany: Berlin 220, the rest 70, 50 and 20.

## F. `threat` (`0x4A6AC0`)

For the country C, with `ownC` its owned provinces (nothing at all where 0) and `strC = (C's land regiments + 1) x
1000 / 2` - `CUnitList::GetTotalNumOfRegiments` (`0x1D5C90`), the regiments of its land units only - for every country
T of the database in index order with an id, not `REB`, not C, owning a province, not in C's real faction, and not
C's vassal (`CDiplomacyStatus_IsVassalWithTargetSecond(C->diplomacy[T])`):

- `strT` likewise; `sr = strT x 1000 / strC`; `pr = ownC x 1000 / provT` (C over T).
- **Where `pr > 3000` and `sr < 500`, T is skipped.**
- `score` = 0, plus:
  - **100** where T has a usable casus belli on C (`DiplomacyStatus_HasUsableCasusBelli(T->diplomacy[C], T, C)`);
  - where T's faction is real and not C's, by T's faction's group (the ideology database's group slots: `+0x34`
    democracy, `+0x38` fascism, `+0x3C` communism, stored by name in VA `0x527470`): **fascism 400** for its leader (the
    first member), 200 for another member; **communism 200** for its leader, 100 for another; **democracy** only where
    C is in a real faction - **300** where C's is fascist, 200 otherwise;
  - where C owns one province and T more, `min(provT, 4) x 50`;
- where T is not played and is `military`, `score x 1.5`;
- **where T borders C** (T's `neighbours[C]`): `n = 25 x C's border share with T + 100` - the border share is
  `CCountry +0x1048[T]`, made each day by `RebuildNeighbours` as the edges from C's owned provinces into provinces T
  both owns and controls, over all such edges (VA `0x4E2CF6`, `0x4E2EA0`) - then `x 1.5` where C's acting capital's
  area touches land T controls, and `x 1.5` again where C's **real** capital province has an edge that is not
  impassable (kind 3) to a simulated province T owns (`0xA6A70`); `score += n`;
- `t = score x min(sr, 4000) / 1000`;
- where T does **not** border C: `reach = min(ownC x 28, 1200)` km; `dist` = `GetDiplomaticDistance` (`0xCCD50`: four
  times the straight map distance between the two acting capitals, `CMap::DistanceBetweenProvinces`); the factor is
  `(reach - dist) / reach` where `dist <= reach` and C has fewer provinces than T and less strength, **else nought**;
  `t = t x factor`;
- **`t > 1`** → `AddThreat(T, round(t))`.

## G. The country lists

### G.1 `antagonize` (`0x4A73C0`, first half)

`strC = (C's land regiments + 1) x 1000` (not halved, unlike F). For every T as in F (id, not `REB`, not C, owning,
not in C's real faction, not C's vassal):

1. `conq` = the sum of C's `conquer_prov` weights over provinces T owns.
2. **Where T is somebody's subject**: its top overlord O (followed up the chain). Where `conq > 0` and (O is not one of
   C's `historical_friends` (`0x4A3370`), or C has a usable casus belli on O, or O is already antagonised), **O** is
   antagonised by `conq` and T is done with - no `antagonize` and no `rival` for T itself.
3. `acc` = `min(6 / min(provT, 6) x conq, 800)`.
4. `sr = strT / strC`, `pr = provT / ownC` (T over C), `power = (sr + pr) / 2`; **balanced** = `0.340 <= power <=
   3.000`.
5. Where T borders C and C is `military`: `(100 x border share + 25)`, `x 1.25` where C's acting capital's area touches
   T, `x 1.25` where C's real capital borders T's land (as in F).
6. **+50** where C has a usable casus belli on T.
7. Where C is T's subject and `power < 2`: `+ 300 x (2.1 - power)`.
8. **Where T is one of C's historical friends**, not already antagonised, and C has no usable casus belli on it: `acc`
   is set to nought.
9. Not allied (`CDiplomacyStatus +0x14` null) and the same ruling ideology: **-200** for `military`, -400 for
   `diplomacy`, -300 otherwise; allied: -400.
10. A different ideology group: **+50**, and another **+150** where C's acting capital's area touches T, or T borders C
    and C is `military`.
11. T in a real faction: **+400** where C is in one too (another, by the gate), **-400** where C is in none.
12. Where `acc > 0` and `pr < 1`: `+ 100 x (1 - pr)`, times 0.75 for `balanced`, 0.5 for `diplomacy` and `capital`, whole
    for `military`.
13. **`acc >= 1`** → `AddAntagonize(T, round(acc))`.

Germany's start list is the faction term at work: `FRA` (Allies, a neighbour), then `TAN` and `MON` (Comintern) and
`BHU`, `YEM`, `NEP`, `OMN` (Allies), the tiny ones raised by step 12; Britain is in the Allies too and falls below the
cap. Denmark, Sweden and Ireland each antagonise the same seven Central American countries at 150 to 200 - a usable
casus belli, a different group and step 12 at the personality's factor.

### G.2 `rival` (`0x4A73C0`, second half)

For the same T, after step 13 (and not where step 2 ended it): `r` = 0, and **only where T is balanced** (step 4):
`r` = 100 where T borders C; otherwise, where `dist < reach x 1000` (as in F), **`r = (reach x 1000 - dist) / 2`** -
divided by the constant 2.000 left in the register by step 4, **not** by `reach` as F divides. Where `r > 0`: +50 at
war with T, +50 with a usable casus belli on T, +100 where both are `capital`; `base = r + 25`;
`pw` = `power` as a float, at most 3.0 (the float at VA `0x171DC88`), then at least 0.34, back to thousandths; `v` =
`base x pw` where `power < 1`, else `base / pw` - **rivalry peaks between equals**; **`v >= 1`** → `AddRival(T,
round(v))`.

### G.3 `befriend` and `vassal` (`0x4A8250`)

For every T with an id, not `REB`, not C, owning, and either nobody's subject or C's:

- `small`: T borders C and `provT < round(ownC x 1.5)` (the float rounded half to even).
- Where T borders C and (T is not a historical friend, or is antagonised, or C has a usable casus belli on it): where
  any of C's `conquer_prov` is T's, T is passed over **unless** it is C's subject or C is `diplomacy` and T is small.
- `thr` = C's `threat` of T (scaled, section H). `acc` = 0, plus:
  - for every entry X of C's `threat` that owns a province, is not T, borders T, and has a threat of at least `thr`:
    `X's threat x min((provT / provX + strT / strX) / 2, 4)` - strength here `regiments + 1` whole;
  - **+100** for the same ruling ideology, +50 for the same group, **-100** otherwise;
  - where small: `d = ownC - provT`; `AddVassal(T, 10 x d)` where C is `diplomacy` and `d > 0`; `+ 10 x d` where T is
    C's subject;
  - `diplomacy`: `+ thr / 2` (whole, truncated);
  - C in a real faction: **+600** where T is in it, -200 where T is in another;
  - T a historical friend, not antagonised, and no usable casus belli on it: **+400**.
- **`acc >= 1`** → `AddBefriend(T, round(acc))`.

### G.4 `protect` (`0x4A8AF0`)

Only where C owns **ten provinces or more**. For every T with an id, not `REB`, not C, owning: `sr` = T's regiments over
C's (no `+ 1` here; C's at least 1), `pr = provT / ownC`, `power = (sr + pr) / 2`. Where `power < 0.66` and C borders T
(**C's** `neighbours[T]`, the other way round from F and G): +25 for a usable casus belli on T, +25 where `pr <= 0.2`.
Where anything: +10 where T owns one province; **`acc >= 1`** → `AddProtect(T, round(acc))`, **capped at 6, or 12 for a
diplomat**. So 60 is the most, and the start save's protect lists are 60, 50 and 25.

## H. The scaling (`0x4A5B50`)

After its builder, each of `threat`, `antagonize`, `rival`, `befriend`, `vassal` and `protect`: where the first (largest)
weight `v0` is above 400, it becomes 400 and every other `v` becomes `round(trunc(v x 1000 x 1000 / ratio) / 1000)`
with `ratio = v0 x 1000 / 400` (thousandths, truncated) - the last rounding a float's, half to even. So **every scaled
list tops at 400**, which is what the saves show: `threat`, `antagonize`, `befriend` and `vassal` at 400 wherever they
exceed it.

## I. Military access (`0x4A6580`, read in part; not built by OpenHOI3)

Where C has two areas or more and its acting capital's area is real: for every other area, a path to the capital's
area over the area graph (`OwnerAreaPathFind` with a `CMilAccessAreaCostCallback`, neither read), and for each area on
it whose first province is held by its owner, not `REB`, not C, and not yet in the list: `AddMilitaryAccess(owner,
area's provinces + 100, or + 150 where C borders it, + 200 where either end area is landlocked)`. Germany's start list
is `POL` 324. What `GetAccessScore` and the cost callback add was not read.

## J. The war targets rechecked (`0x4AD6E0`)

For each prepared war (`+0x148`, `FINDINGS-foreignminister.md` C.1): it stands where the target owns a province or is
a government in exile, is not C's subject, and is not in C's real faction, **and** - without a decision - a bare
`CDeclareWarAction(C, T)` (`0xA11DF0`, no goal) answers `IsSelectable`, or - with one - the decision's **`potential`**
(`CDecision +0x24`) holds in a scope of C. Otherwise the entry is removed (or marked, while the list is being walked,
`+0x154`) and, where C borders the target, `theatres_dirty` (`+0xF4`) is set.

## K. The constants

All floats in `.rdata` of the form `value x 1000 + 0.5`, floored to thousandths at the use, except where marked.

| VA | value | where |
| --- | --- | --- |
| `0x160A610` | 1.000 | the add threshold of every list; F's `t > 1`; `pr < 1` in G.1 and G.2 |
| `0x160A5F4` | 2.000 | the halving in F's strength and G's `power` |
| `0x160A948` / `0x160A944` | 3.000 / 0.340 | F's province skip; G's balanced band |
| `0x160A5E8` | 0.500 | F's strength skip; G.3's average; B's x >= 0 factor; G.1's `diplomacy` factor |
| `0x160A6E0` | 0.330 | B's x < 0 factor |
| `0x160A6DC` | 0.400 | B's 40% |
| `0x160A614` | 0.750 | G.1's `balanced` factor |
| `0x160A818` / `0x160A7C0` | 1.500 / 1.250 | F's and G.1's capital multipliers; F's `military` |
| `0x160A800` | 4.000 | the strength cap in F and G.3 |
| `0x160A650` | 25 | F's and G.2's border base; G.4's terms |
| `0x160A64C` / `0x160A654` / `0x160A648` | 0.200 / 0.660 / 10 | G.4 |
| `0x160A7FC` | 50 | E.1's weight; casus belli and ideology terms |
| `0x160A718` | 100 | F's casus belli; G's ideology and border terms |
| `0x160A938` / `0x160A940` | 150 / 2.100 | G.1 steps 10 and 7 |
| `0x160A7F4` / `0x160A93C` / `0x160A7F0` / `0x160A7F8` | 200 / 300 / 400 / 600 | faction and ideology terms |
| `0x160A950` / `0x160A94C` | 800.0 (double / float) | G.1's cap on `conq` |
| `0x160A934` | 0.34 (float, used as is) | G.2's floor on `pw` |
| `0x171DC88` | 3.0 (float in `.data`, used as is) | G.2's cap on `pw` |
| `0x160A4C8` | 50.0 (double) | F's one-province term |
| `0x160A6B8` | 1.5 (double) | G.3's `small` |

**`g_theatre_split_threshold` is 0.250**, not unknown: VA `0x1B15028` is written by a static initialiser at VA
`0xD10280`ff. from the float 250.5 at VA `0x160A688`, as are its neighbours `0x1B14FF4` (0.400), `0x1B15030` (0.100),
`0x1B15040` (0.500), `0x1B15068` (0.330), `0x1B1502C` (0.300) and `0x1B15078` (0.050), all of which section C reads.

## L. What looks wrong and is what the bytes do

1. **A played country's strategy leaves out the victory conditions** (D, step 2), so a human's faction aims never move
   its own lists - which are still made, and read by the Lua whenever an AI's offer is put to it.
2. **The rival's reach divides by two, not by the reach** (G.2): a rival 1,000 km inside a 1,200 km reach scores 525,
   where the threat with the same figures would score 0.83 of its total.
3. **Threat keeps no strength floor for a neighbour** - a one-province neighbour with a casus belli threatens - while a
   non-neighbour threatens only when it is bigger in provinces **and** in strength.
4. **`protect` asks C's neighbours, `threat` and `antagonize` T's**: with an occupied border they disagree.
5. **The first-time rebuild in the daily pass** (A.3) never fires for a country that entered the game owning land,
   since entering already rebuilt it.
6. The rebuild on entering a game runs **before** the two days it runs, so the first screen's lists are not those days'.

## M. Corrections to the record

1. **"The rest are event-driven"** (the `CAIStrategy::Rebuild` entry, and `FINDINGS-triggereval.md` 17's "a handful per
   country per game year"): `RunDailyPass` calls `CCountry_AfterDiplomacyChange` for every country every day, which
   rebuilds every ten days in a running game - about 36 rebuilds a country a year (A.2).
2. **`g_theatre_split_threshold`'s value "could not be read statically"**: it is 0.250, from a static initialiser (K).
3. **`max_subunits` "x1000"**: a plain count, written with `%d` (C).
4. **`0x527470` ("LoadCommonFileContents")** compares each group's key with `fascism`, `democracy` and `communism` and
   stores the group at `+0x38`, `+0x34` and `+0x3C` of the object it fills - the ideology groups' loader, at least for
   that part.
5. **`0x4A6580` carried Ghidra's own label `CMilAccessAreaCostCallback::CMilAccessAreaCostCallback`**: it is the
   military-access builder, which only makes such a callback on its stack.
6. **`protect`'s cap is 6, or 12 for a diplomat** - `CAIStrategy::AddProtect`'s entry and `FINDINGS-triggereval.md` 17's
   table had befriend's 7 and 14. Found by OpenHOI3's check against the start save, which kept a seventh (Germany's
   Holland, the Soviet Union's Afghanistan) and a thirteenth and fourteenth (Britain's Yunnan and Sinkiang) the save does
   not have; then read at VA `0x8A554A`.

## O. Checked against the start save

OpenHOI3 built all of this (`OpenHOI3/docs/mechanics/aistrategy.md`) and set a new game's strategies beside
`Germany1936_01_01_00.hoi3`'s: **the personality and every list - `conquer_prov`, `defend_prov`, `threat`, `antagonize`,
`befriend`, `protect`, `rival`, `vassal` - agree entry for entry, in order and weight, for all 78 countries** that have
one; the save's other 23 blocks are empty (REB and countries that do not exist on the start date). Two of this file's
readings were reached that way rather than first: the region scope (D.3) and `protect`'s cap (section M, 6). Germany's
lists leave the walk out because the save's player is Germany.

## N. Not established

- `exists`, `war_with`, `vassal_of`, `alliance_with`, `relation`, `has_building` and the copying scope rebinders in the
  walk (D.3) - none in the base game's aims.
- `OwnerAreaPathFind`'s search and the cost callback, and `GetAccessScore`'s use (I).
- What reads the production shares (C).
- Whether `MergeAIStrategy` carries `static`, `consolidate` or the shares across - only its ten lists were read.
- Which country of a pair `CMap::DistanceBetweenProvinces` is asked about first does not matter (it is symmetric); the
  capital provinces' coordinates are `CMap +0x2A60`'s, which OpenHOI3 has as the province's position.

## Trap check

Trap 1: every address here is an rva unless marked VA, and the table's are VAs because they are data read with
`image.read`. Trap 2: `0x4A6580`, `0x4A67B0`, `0x4A6980` and `0x4A6AC0` abut with one or two `int3`s, and each end was
taken from its own `ret 4`, not from a padding run; `RunHourlyPass` and `RunDailyPass` abut with none, which is why
`functionStart` answered the call at VA `0x682E0F` as `RunHourlyPass`'s (it is `RunDailyPass`'s, by the loop it sits
in). Trap 12: `+0x34`, `+0x38` and `+0x3C` on the ideology database were taken from the stores beside the three
string compares, not from a displacement count.
