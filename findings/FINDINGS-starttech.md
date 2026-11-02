# What a new game does to a country's laws and technology before the first screen

Read 2026-11-02 by two readers in parallel, for OpenHOI3, whose China fought with level-0 infantry equipment against
the original's level 1 (`OpenHOI3/docs/mechanics/headless.md`, section 4). Reader A came from the data - every writer
of a country's technology level - and reader B from the timeline - the new-game path through `CInGameIdler::Enter`.
**They met at the same function**, rva `0xD59D0`, now `SetUpCountryLawsAndTechnologyForNewGame`, and each one's
simulation of it reproduces the start save on its own. Addresses are VAs unless marked rva.

## In one paragraph

As a new game is entered, every country - the player's too - first has each of its laws moved up to the latest law of
its group whose `allow` holds, and then **buys technology levels with a budget**: about 1.92 years of its core
provinces' leadership, capped at 5, spent at the full research cost on the cheapest level that is already due, one
level at a time. Levels not yet due cost double and theories are never bought. That is why the start save holds 476
levels above the history in 86 countries, why they come in whole families by kind of unit (a practical makes a family
cheap), why 453 of them land exactly on "the highest level due before 1936", and why poorer countries stop part of the
way. A loaded save never runs it.

## 1. Every writer of a technology level (reader A)

A census of every `mov reg, [x+0x218]` in `.text` - a byte search for the displacement of `CTechnologyStatus`'s
`level_by_technology` - each register followed forward to a store through it, callee-saved registers across calls.
Twelve functions, all direct; nothing sets a level through a wrapper but the history's `CTechnologyChange`:

- **research**: `CTechnologyStatus::AdvanceResearch` (rva `0x132F10`), its `inc`;
- **the history**: `CTechnologyStatus_SetLevel` (rva `0x133190`), whose only caller is `CTechnologyChange::Apply`
  (slot 7); `CCountryHistory::LoadEntry` builds the change (VA `0x5EE448`) for a history `technology` block, and no
  effect is applied there;
- **a savegame**: `CTechnologyStatus::LoadKey` (rva `0x132230`);
- **a reset**: `CTechnologyStatus_Clear` (rva `0x132060`), from `CCountry_Reset`;
- **a release**: `ReleaseProvinces` (rva `0xC1430`) - a released country takes its oppressor's higher levels;
- **the custom game**: six (`0x1A320`, `0x1A3C0`, `0x1334F0`, and slot 6 of `CCgmTechResearchChange`, `...ClearAll`
  and `ExecuteStackedCommand` at `0x2AB40`, `0x2B740`, `0x2BBB0`);
- **none of those**: `0xD59D0`.

No script effect and no Lua call writes a level. *The positive control*: the census finds the three writers already
recorded. *Its limit*: a store through a second register made by `lea` from the loaded pointer would be missed; no such
shape was seen.

## 2. The path (reader B)

1. **History loaded into the game state** (not read here). `CCountry::AfterLoad` (rva `0xD2500`) calls
   `ReapplyAllTechnologies` at `0x4D26B1`, so a loaded country's status is rebuilt from its levels.
2. **`CInGameIdler::Enter`, its per-country loop** (`0x65B157`..`0x65BB03`) over every country of the game state
   (`+0xBBC`). Where the scenario (`+0xD0C`) is set, a country not in its list at `+0x88` is skipped. Each country then
   has ActivateRankedLeaders (new game only), EnsureCapital, UpdateTriggeredModifiers, RebuildStaticModifiers,
   RebuildRules, UpdateTotalLeadership, UpdateMaxManpower, UpdateIC, UpdateBlockadeLevel and UpdateAtWarAndEnemies -
   readers of the technology status, none a writer.
3. **`0x65B4D4`: `cmp byte [gs+0xD9C], 0; jne 0x65B7C9`** - the new-game block (`loaded_from_save` is 0):
   - `0x65B4E6 call 0x4D59D0` - **the laws and the levels** (sections 3 and 4);
   - `0x65B4EC` `CCountry::LoadOobFile`;
   - `0x65B4F2` `SetUpCountryForNewGame`, whose `ReapplyAllTechnologies` at `0x4D7346` rebuilds the status - unit
     figures, `unit_available`, `building_available` - from the new levels, so they count from the first hour. The order
     of battle is read after the levels are raised and before that rebuild.
4. **The two days** (`RunDailyPass` at `0x65CB2E`, `RunSupplyAndConvoyIterations` at `0x65CC64`): not read for research.
   No technology has progress in the start save, which agrees with nothing being researched in them.
5. **The custom game only**: a byte copied from game state `+0xD2C` into the custom-game settings, then
   `LoadCustomGameSettings` and `ApplyCustomGameSettings(settings, 3)` (`0x66187E`), which calls
   `ReapplyAllTechnologies` (`0x41DC85`). *Likely*: the byte is identified by its use.

**A loaded save never runs `0xD59D0`**: its one caller is behind the `+0xD9C` test, `findRefs --callers` gives exactly
`0x65B4E6` and a value search over `.text` and `.rdata` gives nothing. `confirmed`; checked again by the collecting
session. `ReapplyAllTechnologies` has three callers - `0x41DC85`, `0x4D26B1`, `0x4D7346` - where the record had one.

## 3. `0xD59D0`, the laws (`0x4D59F4`..`0x4D5BD7`)

One `CEventScope`: the country, FROM `---`. For each law group by index from 1 (`GetLawDataBase +0x28`), its list
(`CLawGroup +0xC`) is walked:

- a law whose modifier values hold a non-zero entry 52 (`[law+0x18]+0x1A0`, `UNIT_START_EXPERIENCE`) **abandons the
  whole group**;
- the country's current law (`+0x628[i]`) is noted, and **no law after it in the list is asked**;
- a law met before it whose `allow` (`CLaw +0x54`, slot 6) holds becomes the country's law by a plain store
  (`laws[group->index (+0x50)] = law`) - no command, cost or message - and any change calls `RebuildStaticModifiers`.

`CLawGroup::LoadKey` links each new law in front of the old head (`0x5297E5`..`0x529810`), so the list runs in the
**reverse of `laws.txt`'s order** (both readers; *likely* that nothing reorders it later - not searched). The effect: **a
law moves to the latest law of its group, in file order, whose `allow` holds, where that is later than its own**, and
`training_laws`, whose last law carries `unit_start_experience`, is never touched. The player's country too. `confirmed`
off the listing; **not set against a save** - the AI's Lua `Laws()` in `SetUpCountryForNewGame` changes laws after it.

## 4. `0xD59D0`, the technology (`0x4D5BD7`..`0x4D622D`)

`confirmed`, read whole by both readers:

    y   = the year of the game's tick (+0xBDC): (tick - 43800000) / 24, then / 365.0, truncated
    m0  = its month counted from 0, from the day of the year through the month table 0x1713294
    s   = the year of start_date (CDefines +0x8)
    x   = y*1000 + trunc((m0*1000 - 1000)*1000 / 12000) + 2000 - s*1000          1917 on 1 January of the start year
    L   = the sum of leadership (+0x324) over the country's CoreProvinces (+0xD10), owned or not, held to 5000
    B   = trunc(trunc(x*3650 / 1000) * L / 1000)                                   Germany: L 20.35 -> 5000, B 34985
    while B > 0:
        best = 99999000, pick = none
        for t in the technology database in its order, notech first:
            Lv = level_by_technology[t->Index]
            skip if additional_offset (+0x2C0) == 0 and Lv >= 1
            skip if t's folder (+0x290) is the one named "theory_folder"
            skip unless CTechnology::CheckResearchAllowed(t, tag, id, -1)        max_level, allow, the custom game's minimums
            skip if Year(t, Lv) >= y                                              the CURRENT level's year
            c = GetResearchCost(t)
            if Year(t, Lv + 1) >= y:  c = trunc(c*2000/1000)                       a level not yet due costs double
            if c < best:  best = c, pick = t                                       strict: the first of equals wins
        no pick: stop
        B -= trunc(GetResearchCost(pick)*1000/100000)                              the undoubled cost over 100
        level_by_technology[pick] = min(Lv + 1, max_level)                         0x4D620F

`Year` is `CTechnologyStatus::GetYear`'s arithmetic: `start_year` for a level of 1 or less, `first_offset` for 2, and
`additional_offset` more a level above. The loop writes its last pick even when that takes the budget below nought. It
writes the level and **nothing else** - no progress, ability, queue, `on_completion`, message or history entry; the
effects come from `ReapplyAllTechnologies` afterwards. The month term is an off-by-one: January counts as -1/12.

**The cost it compares** is `GetResearchCost` and `GetCategoryResearchAbility`, already in the record: (1 + 0.1 x
difficulty) x 125 x (1 - bonus), the bonus the sum over `research_bonus_from` of weight x 0.1 x f(clamp(max(own
ability, a sharer's), 0, 20) - 5), held to 0.9 with no floor, f the identity at 1 and below and **`FixedPointSqrt`'s one
step above it, not a true root** (2.5 gives 1.625).

**How to read the budget** (*inferred*; the arithmetic is `confirmed`): the deduction and the budget cancel to "the
picked levels' costs, in leadership-days, at most 365 x 1.917 x min(core leadership, 5)" - about 1.92 years of the core
provinces' leadership at full cost with the practical's bonus, cheapest level first. Research efficiency and the other
research modifiers play no part.

**`notech` is a candidate.** `LoadTechnologies` builds it through the ordinary `CTechnology` constructor (rva
`0x1339A0`, at VA `0x541407`): start_year 0, additional_offset 0, max_level 1, difficulty 0, no folder, no
`research_bonus_from`, an empty `allow` - so it costs 125.000 and takes 1250 of the budget, and this function never asks
slot 9, the test that tells the null technology from a real one. The start save has `notech=1` in 88 countries of 101;
the 13 at 0 are the 12 with no core leadership and New Zealand, whose budget ran out on cheaper levels first (reader A).

## 5. Against the start save

Both readers simulated the loop over the install's `tfh/technologies` in the order the save writes technologies, from
the save's levels with the raised ones put back to the history's, the save's abilities, core-province leadership and
(for `num_of_ports`) ports. Reader A: **627 of 627 level steps (476 of 476 lines), none extra and none missed**, notech
101 of 101. Reader B: 476 of 476, **86 of 86 countries exact**, notech 101 of 101; the collecting session ran it again
and got the same. Germany: a budget of 34,985, 26 picks - its 22 lines, 25 steps and notech - the last, `militia_at` 2,
leaving -38; its 36 levels as far behind are left because the budget is spent. China: 17 lines, 23 steps. The doubled
price never wins in this save.

Every part bears weight (reader B, countries exact of 86):

| change | exact |
| --- | --- |
| x = 1900 or 1930 | 82 or 75 (only 1917 and 1918 give 86) |
| a cap of 4900 or 5100 | 84 or 80 |
| y = 1935 | 84 |
| no doubling | 25 |
| theories included | 6 |
| notech left out | 20 of 89 (reader A: one level too many in 69 countries) |
| `<=` for the first of equals, or the database reversed | 54 |
| a true square root for FixedPointSqrt | 85 (Japan's `mountain_infantry`) |

The simulations are in the collecting session's scratchpad, `hlA/sim.py` (`NOTECH=1`) and `hlB/sim.py`.

## 6. What a mod can move, and what is built in

**A mod moves**: the provinces' `leadership` and the cores (`history/provinces`, `add_core`); `defines.lua`'s
`start_date`, and the game's start date; in the technology files `difficulty`, `research_bonus_from`, `start_year`,
`first_offset`, `additional_offset`, `max_level`, `folder`, `allow`, `is_nuclear` (with `MODIFIER_NUKE_RESEARCH`); the
files' order, which breaks ties; the history's levels, theories and practicals; `laws.txt`'s order, its `allow` blocks and
`unit_start_experience`.

**Built in**: the 2000 (two years), the month's 12000 and the -1000, 3650, the cap of 5000, the doubling, 99,999,000 and
the /100000 deduction; `GetResearchCost`'s 0.1 a difficulty, its 125 and its 0.9 cap, and the ability term's 0.1, 20, 5
and approximate root; the folder name `theory_folder`; notech being a candidate; the law half's test of modifier 52.

## 7. What it corrects

- The record's `CCountry +0x1160` comment put the spy allocation in `0xD59D0` and had it recomputed whenever a game is
  entered, so that a value written mid-game would not survive a reload. `0xD59D0` touches only `+0x628` and `+0x218`; the
  first allocation is `SetUpCountryForNewGame`'s (rva `0xD6230`), on a new game only. Both readers; the collecting session
  found no `+0x1160` in the body. The same error is in `FINDINGS-script.md` ("the assigner at rva 0xD59D0").
- `FINDINGS-unitstart.md` has the function handle "starting technology and not its laws": it does both.
- `FINDINGS-ic.md` (lines 171 and 293) puts `UpdateIC(country, 0)` at `0x4D633D` in "0x4D59D0": the call is in
  `SetUpCountryForNewGame`, the same walk back over the unpadded `ret 4` at `0x4D622D` (trap 2).
- `FINDINGS-research.md`'s open item on `0x4D59D0` is settled.
- `ReapplyAllTechnologies` had one of its three callers.

## 8. What is not established

- **A later start date.** No save starts later. As read, a game whose date is later than `start_date` gets a larger
  budget - about 3000 more for 1939. Whether `start_date` is ever anything but `defines.lua`'s was not searched.
- **The law half against a save**, and against `Laws(country)` and `CCountry_RevertDisallowedLaws` after it. Whether
  anything reorders a group's list after `LoadKey` was not searched.
- **The database's order** is taken from the order the save writes technologies in; it is borne out by the tie-break
  (54 of 86 otherwise), not by reading the writer.
- **Whether the order of battle's units take the raised levels**: `LoadOobFile` runs between the write and
  `ReapplyAllTechnologies`, and how its regiments copy levels was not read.
- **Research in the two days** - not read; the save's lack of progress is the only evidence.
- **Modifier 52 being `UNIT_START_EXPERIENCE`** rests on the DLL's header and other entries (`AddStartExperience`), not on
  this function.
- **The rest of `CTechnologyStatus_Clear`** after its first loop, `CTechnologyStatus_RevertDisallowedLevels`' logging and
  restart, the custom-game commands' `Execute` bodies and `CTechnologyChange` slots 2 and 6 - in the fragments' frontier.
- The scenario's list at `+0xD0C` and the custom game's byte at `+0xD2C`, beyond their use here.
