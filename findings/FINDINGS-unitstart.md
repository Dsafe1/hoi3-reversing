# What a brigade starts a new game with

Read statically off `hoi3_tfh.exe` on 2026-10-08 for OpenHOI3's units, and set beside one
savegame written two days into an unmodded game (`Germany1936_01_01_00.hoi3`, 3792 brigades,
ships and wings) and the files that game was started from. Addresses are **virtual**, the way
a disassembler prints them; the record holds the rvas. Only valid for this build.

`FINDINGS-oob.md` says which keys an order of battle accepts. This says what the values
come out as: which technology levels a brigade holds, how strong and how organised it is,
and how experienced, on the first hour of a new game.

## 1. When the order of battle is read

Not while the country's history is. `CCountry::LoadOobFile` has three callers: the
`load_oob` effect, one at `0x41C3A6` that was not read, and **`0x65B4EC`, inside
`CInGameIdler::Enter`**, in the loop that walks every country of the game as a session
comes up. Per country, in this order:

    UpdateTriggeredModifiers, RebuildStaticModifiers, RebuildRules, UpdateTotalLeadership,
    UpdateMaxManpower, UpdateIC, UpdateBlockadeLevel
    UpdateAtWarAndEnemies              <- sets `mobilised` on a country at war
    effective neutrality
    if the session was not loaded from a save:
        0x4D59D0                       <- not read
        LoadOobFile                    <- the units are made here
        SetUpCountryForNewGame
        RecountUnitTotals
        the shares of IC
        the country's officers          (section 7)
    for each of the country's units:    (section 6)

So a unit is built by a country that already has its laws, its technology levels and its
modifiers, and already knows whether it is at war. That is what the two rules below that read
a modifier depend on.

## 2. A brigade as it is constructed

`CSubUnit::CSubUnit` (`0x5A88F0`, `ret 4`, the object on the stack), which the regiment, wing
and ship constructors all begin with:

| field | starts as | which means |
| --- | --- | --- |
| `strength` `+0x5C` | 100000 | 100.000 - more than any type has, so "all there is" |
| `organisation` `+0x60` | 100000 | the same |
| `experience` `+0x3C` | -1000 | **-1.000, "not given"** |
| `historical_model` `+0xD0` | -1 | none |
| `strength_ceiling` `+0x30` | 0 | |
| `is_reserve`, `pride` `+0xA4`, `+0xA5` | 0 | one `mov word ptr` |
| `contributes_to_unit` `+0xD4` | 1 | |

`CUnit::LoadKey`'s `regiment` case then sets the brigade's owner and its unit, and **copies
the unit's own reserve flag down**: `cmp byte ptr [ebx+0x8e], 0` at `0x5B73E4` and again at
`0x5B7405`, either side of the brigade's own `Load`, each followed by `mov byte ptr
[esi+0xa4], 1`. `ebx` is the unit's `CPersistent` half, so the flag is **`CUnit +0x96`**, and
the unit's `is_reserve` key (token `0x57F`) is a plain `ParseBool` into it at `0x5B7C80`.

Two consequences:

- **`is_reserve = yes` on a division makes reserves only of the brigades that come after it
  in the block.** Nothing goes back over the ones already read. All 644 such lines in the
  78 files the base game starts from come before their brigades, so this never shows.
- **Only `regiment` does it.** The `wing` case (`0x5B797E`) builds the same object and never
  tests the flag, and the ship case was not seen to either.

A brigade left without a name is named there too: the count of the unit's brigades once it is
added, then `". "`, then the unit's name - `3. 1st Division`. 790 of the base game's 2912
starting regiments are named that way.

## 3. The keys, by where they land

`CSubUnit::LoadKey` (`0x5A8BF0`), from the jump chain on the token:

| token | key | does |
| --- | --- | --- |
| `0x1A` | `name` | sets the name |
| `0xD9` | `type` | looks the value up in the sub unit database and calls `CSubUnit::SetType`; a miss logs `Unknown subunit 'x' in ...` from `subunit.cpp` and leaves the brigade with no type |
| `0x254` | `home` | a province, into `+0x64` |
| `0x259` | `strength` | fixed point into `+0x5C` |
| `0x48B` | `experience` | fixed point into `+0x3C` |
| `0x4C8` | `organisation` | fixed point into `+0x60` |
| `0x504` | `current_distance` | `+0xC8` |
| `0x513` | `historical_model` | `atoi` into `+0xD0` |
| `0x57E` | `builder` | a country tag into `+0x34` |
| `0x57F` | `is_reserve` | `ParseBool` into `+0xA4` |
| `0x5A0` | `sunk_by` | an object id into `+0x9C` |
| `0x5C0` | `highest` | fixed point into `+0x30` |
| `0x750` | `pride` | `ParseBool` into `+0xA5` |
| anything else | | **looked up as a technology's name**; on a hit the value is read as `{ level progress }` and written into the brigade's node for that technology, if it has one |

The last row is how a savegame's `infantry_guns = { 1 0.024 }` gets back in, and it means an
order of battle may carry the same thing.

## 4. `CSubUnit::AfterLoad`: levels, then strength and organisation

`0x5A9130`, the brigade's `CPersistent` slot 5. After the id (`FINDINGS-oob.md`):

    model = historical_model
    if model != -1:
        owner = the brigade's country                         (0x5ABCF0)
        set   = owner->historical_models[definition->type_index]
        if 0 <= model < the set's count and set[model] is not null:
            CHistoricalModel::ApplyTo(set[model], brigade)     (0x582CA0)
            for each technology the brigade lists:
                if the technology's `change` is no and the brigade's level of it is 0:
                    level = the country's level of it
    ApplyTechnologies(brigade, keepStrength = true)
    if model != -1:
        strength_ceiling = 0
        strength     = min(strength,     GetMaxStrength(1, 0))
        organisation = min(organisation, GetMaxOrganisation(1, 0))
        strength_ceiling = max(strength_ceiling, strength)

`CHistoricalModel::ApplyTo` walks the model's twelve-byte entries and, for each whose
technology the brigade lists, **overwrites the brigade's level with the model's**. Nothing
there looks at what the country has researched: a model can hand a brigade a level its
country does not have, and it does - 31 brigades in the save hold level 2 of something their
country holds none of.

**A brigade with no `historical_model` line skips all of it.** The model, the doctrine levels
and both clamps are inside the two tests of `-1`, so it keeps every level at nought and
100.000 of strength and organisation until something else clamps them. Every brigade in the
base game's files has the line.

### What that comes to at a new game

- **strength** is the type's `max_strength` after its technologies, and for a reserve that
  times `(1 + reserves_penalty_size)` unless the country is mobilised. With the flags `(1, 0)`
  the gate in `CSubUnit::GetMaxStrength` reads: mobilised, no penalty; not at war, penalty; at
  war and not mobilised, penalty.
- **organisation** is the type's `default_organisation` after its technologies and nothing
  else. `0x5AB7C0`, below, returns before any of its factors when `in_game` is clear, and
  `in_game` is not set until the end of `CInGameIdler::Enter`.

Measured, all 2892 brigades that could be matched by name: `highest` is the type's
`max_strength` on every regular, and 0.25, 0.34, 0.5 or 0.75 of it on the reserves of
countries whose conscription law says -0.75, -0.66, -0.5 or -0.25. Sixty reserves of
countries on `three_year_draft` are at the whole of it, and those are countries at war on
the first day: section 9 has every `highest` in the save reproduced with "mobilised" read as
"at war as the game starts".

## 5. Historical models

A model is a list of `{technology, level}` for one unit type. A country has a set of them
for every type, indexed by number, and `historical_model = N` in an order of battle picks one.

**Every set starts with defaults.** `CHistoricalModelSet::CHistoricalModelSet` (`0x582CF0`,
`ret 0x10`, called once, from `CCountry`'s constructor at `0x4CA5A5`) makes
`HISTORICAL_MODEL_MAX` models - the define is 10 in the base game - and gives model `n` one
entry for every technology of the type:

    level = 0   if the technology's `allow` block holds any condition and its additional_offset is 0
    level = n   otherwise

`cmp dword ptr [eax+0x258], ecx; jle` then `cmp dword ptr [eax+0x2c0], ecx; jne` at
`0x582E26`. `+0x2C0` is `additional_offset`, whose nought is what declares a technology to
have one level. `+0x258` is not a field of the technology's own: the `allow` trigger sits at
`+0x248` by value and a trigger keeps its children's count at `+0x10`. So the test is "a
one-level technology that has a precondition", and those are left out of a default model.
Measured, on the brigades whose model is a default numbered above nought: all 1,650 levels
of a technology with more than one level are `n`, and all 1,322 of a one-level technology are
0. Every one-level technology those brigades list has an `allow` block, so the save cannot
tell this rule from "a one-level technology is left out"; the bytes can, and say the block is
what decides.

**A file replaces them.** `CSubUnitDataBase::BuildHistoricalModels` (`0x5B0870`) lists
`units/models/*.txt`, and for each file:

1. upper-cases the name (`CharUpperBuffA`) and asks `CCountryDataBase::GetTag` for it; a name
   that does not begin with a known tag skips the whole file;
2. reads statements whose key is `<unit type>.<number>`: split on the dot, anything but two
   parts logs `broken statement in model file`, a type nobody declares logs `unknown unit
   type in model file`;
3. takes the country's model of that number for that type. Where there is none the number
   has to be exactly the next one, and a new model is added; otherwise it logs `error in model
   order in model file` and drops the statement;
4. **empties the model's list**, and loads the block into it with `CHistoricalModel::LoadKey`,
   each key a technology and each value a level.

So a model from a file holds only what the file lists. A technology it leaves out is not at
level `n`; it is not in the model, and the brigade keeps nought of it. The last thing the
function does is walk every country's every set through `0x5832E0`, which logs `Not all
technologies for TAG #n - type are defined.` for a model shorter than its type's list, and
changes nothing.

Measured: where a country's file has the model, all 3,215 levels on its brigades are the
file's.

## 6. Experience, and names, once the units exist

Still inside `CInGameIdler::Enter`, the loop over a country's units at `0x65B7F0`. For a
session loaded from a save it only puts each unit back in its province. For a new game:

- a unit with no name is given one (`0x4CB580`, not read);
- for each brigade whose **experience is below nought** - the constructor's "not given":

      experience = unit_start_experience                              a regular
      experience = unit_start_experience * (1 + reserves_penalty_size)   a reserve
      capped at 100

  `mov eax,[edx+0xda8]; mov eax,[eax+0x1a0]` for modifier 52 at `0x65B9F7`, and the same
  with `[ecx+0x268]`, modifier 77, plus 1000, an `imul` and a divide by 1000 at `0x65BA33`.
  **This one has no mobilisation gate**: a reserve's starting experience is cut whether or
  not its strength was.

A brigade whose line gave an `experience` keeps it, reserve or not.

Measured: the lines with a figure come out as that figure (181 regiments and 3 wings, among
them 108 reserves at 45). The lines without come out as 0, 10 or 15 - `minimal_training`
gives no modifier, `basic_training` 10, `advanced_training` 15 - and the reserves among them
as 2.5, 3.75, 5, 7.5 and 11.25.

## 7. The officers a country starts with

The same per-country block, at `0x65B651`, straight after the order of battle is read:

    for each of the country's units:
        n = unit->definition->officers                 the unit's own brigades' sum
        if country->officers_ratio != 0:
            n = n * officers_ratio / 1000
        officers += n                                  floored at 0

`unit->definition` is the definition the unit owns (`FINDINGS-unitdef.md`), so `officers`
there is the sum over the unit's own brigades. The loop goes on to call `0x5CD5B0` on a unit
whose leader answers no to slot 8, which was not read and is the obvious place for a unit to
be given a commander.

**`country +0x1C` is taken to be the history key `officers_ratio`** - `1.5` for Germany,
`0.60` for five countries - **on the strength of the arithmetic, not of the loader.** The case
that reads the key was not found: token `0x543` is compared directly only in the custom game
settings' loader, which keeps a figure of its own under the same key, and `CCountry::LoadKey`
reaches its cases through a table. What supports it is the save: take two days of officer
training off each country's `officers`, and what is left is this sum with the history's ratio
in 95 countries of 100, Germany among them at 1.5. The other five - Britain, the United
States, France, the Netherlands, Poland - are out by a fraction and right in the whole
number; they are the five whose leadership a triggered modifier changes
(`FINDINGS-leadership.md`), so it is their two days of training that is wrong, not this.

This closes `FINDINGS-leadership.md`'s "what sets `officers` at the start".

## 8. The ceiling on organisation, for when the game is running

`CSubUnit::GetMaxOrganisation` (`0x5AB700`) works out one number and hands it on:

    hq = the brigade's unit if that is an army (oob_level 2), else the army above it,
         reached through a corps (3) from a division (4) - or none
    bonus = hq ? CommandReach(hq, brigade) * hq->leader->skill * 1000 / 1000 : 0

and `0x5AB7C0` (`ret 0x10`, the answer through `ESI`) does the rest:

    out = definition->default_organisation
    if not in_game: return
    if the brigade is in a unit:
        out += bonus
        if is_reserve and the same gate as GetMaxStrength's passes:
            out = out * (1000 + reserves_penalty_size) / 1000
        if there is no scenario, or the scenario lists the owner:
            out = out * owner->OfficerRatio / 1000
    out = out * (1000 + m) / 1000      m = land_organisation, naval_organisation or
                                           air_organisation, by the brigade's kind

The three modifiers are 70, 72 and 71 (`+0x230`, `+0x240`, `+0x238` of the values array),
chosen by the brigade's slots 9 and 10. The gate's two flags are the caller's second and
third arguments; `AfterLoad` passes `(1, 0)`.

**What the save shows of it**, two days in: no brigade is above what section 4 gave it, and
the ones below are below by this ceiling. Germany, with `officers_ratio = 1.5` and
`two_year_draft`, has its regulars at exactly their starting 40 and its reserves at exactly
28, which is 40 x 0.5 x 1.4 - so the ratio in use is 1.4, not 1.5, and nothing raised the
regulars toward a ceiling of 56 in two days. Britain's regulars are at 0.985 of theirs.

## 9. The whole of it against the save

OpenHOI3 builds the units of the 78 orders of battle by sections 2 to 7 and numbers them as
`FINDINGS-oob.md` describes - one count over the countries in `countries.txt`'s order, each
block taking the next number as it closes. Set beside the save by number:

| | agree |
| --- | --- |
| a brigade, ship or wing of that number, in the unit of that number, of that type | 3706 of 3706 |
| its name, where the file or section 2 gives one | 3682 of 3682 |
| whether it is a reserve | 3706 of 3706 |
| `highest` against section 4's strength | 3706 of 3706 |
| `experience` against section 6 | 3706 of 3706 |
| the level of every technology that takes new equipment | 26648 of 26648 |
| the level of every doctrine, or the country's where that is higher | 10235 of 10235 |
| a unit of that number, name and kind | 1555 of 1579 |
| where it is | 1578 of 1579 |
| where a fleet or an air group is based | 244 of 244 |
| which unit commands it, where the file nests it | 994 of 1028 |

What that settles beyond the sections above:

- **A unit under construction takes five numbers.** The count only comes out right if each
  `military_construction` block is given five: in the save the construction holds the first,
  the brigade it is building the fifth, and nothing a savegame writes holds the three
  between. All thirty in the base game build one brigade, so what a second brigade costs is
  not known.
- **A doctrine reaches a brigade within two days.** Section 4 leaves a doctrine at the
  model's level where the model gives one, and the save has such brigades at their
  country's higher level instead: German infantry raised as model 1, which lists
  `infantry_warfare` at 1, hold the 2 their country has. Nothing in the loader does that, so
  it is the game's own upgrading, and it takes no time for a technology whose `change` is no.
- **The conscription law the units were made under is the save's, and the training law the
  history's.** Reserves fit the conscription law the save shows in every country - Germany's
  are at half strength with 7.5 experience, which is `two_year_draft` on a history that says
  `volunteer_army`. But 43 countries fit their history's training law and not the save's. So
  by the time `CInGameIdler::Enter` reads the orders of battle something has already changed
  conscription, for the player's country as well, and the training laws were changed
  afterwards. The earlier write-ups put both down to the AI; neither was traced.

  **Confirmed in the running game by the maintainer, 2026-10-08**: a fresh 1936 game as
  Germany shows `two_year_draft` on the first screen, before anything is touched or a
  minute has passed. So it is not the player's hand, and it is before the first hour. His
  reading is that it is a bug: the AI should not have touched the country the player is
  playing.

  What the files add, and where it stops:

  - **It is not the history file.** Germany's history does hold a `two_year_draft` line, in
    its last dated block (1944.6.20), which would explain it if dated lines leaked. They do
    not: Britain, France, Finland, Australia and three more have dated conscription lines
    too, and the save has each on its undated one.
  - **It is the shape of the AI script's rule.** `script/ai_politics_minister.lua` is plain
    text in the install; its `Laws()` takes each law group in turn and for conscription
    and the economy proposes "the next law up, if it is allowed". Germany is two laws up in
    both: `volunteer_army` to `two_year_draft`, `basic_mobilisation` to `war_economy`. The
    script has no test for a human player; `FINDINGS-aisched.md` has the executable giving
    the player's country a minister only for a ministry the player has delegated, which is
    where such a test would live.
  - **And it does not fit that routine as written.** `Laws()` proposes every group in one
    pass, training among them - Germany's own script asks for `specialist_training`, which
    is always allowed. Had that pass run before the units were made, Germany's reserves
    would have 12.5 experience; they have 7.5, which is `advanced_training`. So either the
    proposals of one pass do not all take effect together, or something else moved
    conscription. That was not traced, and neither was how the script comes to run at all
    before the first hour: in play `PoliticsMinister_Tick` is reached once a day and calls
    `Laws()` on about one tick in twelve, which cannot be how 95 countries changed their
    education law within two days.
- **The 24 units that do not match by name** are the air groups aboard carriers, which the
  files leave unnamed: the save has them as `1st Air wing`, `2nd Air wing`, counted through
  the country, and their wings as `1st CAG`, `2nd CAG`.
- **The 34 that do not match by commander** are units the files nest and the save has under
  one of the theatres below.
- **Organisation two days in**: 958 brigades are where section 4 put them, 2745 below and 3
  above - three German brigades at 55.107 from 55.

## Not established

- **The loader's case for `officers_ratio`**, as section 7 says.
- **Where `OfficerRatio` is capped.** Germany's reserves say 1.4 where its history says 1.5;
  the writer of `CCountry +0xD4` was not read.
- **What raises organisation**, and when a brigade above its ceiling is brought down to it.
  The save shows the second happened within two days and the first did not.
- **The 86 theatres the files do not have.** The 78 orders of battle hold 22 theatres; the
  save holds 108, every one of the extra 86 with a single `hq_brigade` at a fifth of its
  strength, ids above every id a file's unit got, and every top-level unit of the files
  moved under one. `FINDINGS-aitheatre.md` has the AI issuing `CCreateHigherCommand`; that
  this is what made them was not checked.
- **A wing's or a ship's default name.** The `wing` case names an unnamed wing through a
  call that takes the country and the type (`0x5B7A20` on), not read. 24 of the base game's
  136 starting wings have no name in the files.
- **`0x4D59D0`**, run just before the order of battle is read, and **`0x5CD5B0`**, run on
  each unit just after. `0x4D59D0` was looked at only as far as what it calls -
  `CTechnology::CheckResearchAllowed`, `CTechnologyStatus::GetResearchCost`,
  `CCountry::RebuildStaticModifiers` and the string `theory_folder` - which makes it the
  country's starting technology and not its laws.
- **What changes conscription before the units are made, and how the AI script comes to
  run before the first hour**: section 9.
- **Whether a ship passes the unit's reserve flag down.** The case was not read to its end.
- The measurements are one save of one game.
