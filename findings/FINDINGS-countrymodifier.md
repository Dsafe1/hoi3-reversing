# What a country's modifier is made of

`CCountry::RebuildStaticModifiers` read from its first instruction to its `ret`, on 2026-10-08, for
OpenHOI3's `docs/mechanics/modifiers.md`. Until now only its espionage arm had been read, and three
write-ups - `FINDINGS-leadership.md`, `FINDINGS-researchshare.md`, `FINDINGS-manpowergain.md` - each
ended with a country or two that would not fit a savegame for something this routine decides.

Addresses are rvas in the tables and `project.json`; the listings quoted are virtual addresses,
which are those plus `0x400000` (trap 1). Values are thousandths and divides truncate.

## 1. What was settled

A country's modifier is rebuilt from nothing out of twenty-one sources in a fixed order. Laws,
ministers and the government are added whole; a strategic resource is added **scaled**, by a level
the country keeps for each resource; triggered modifiers come from a list a separate daily routine
maintains; event modifiers carry an expiry date. **Corrected:** `FINDINGS-manpowergain.md` guessed
that a strategic resource reaches a country through its province's modifier. It does not.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| `0xDDD80` | `CCountry::RebuildStaticModifiers` | revised | confirmed | read through; was `likely` with one arm read |
| `0xD8070` | `UpdateTriggeredModifiers` | new | confirmed | keeps the list of triggered modifiers that apply |
| `0x5BC00` | `CTriggeredModifier::AppliesTo` | new | confirmed | `potential` and then `trigger`, both true |
| `0x28C190` | `UpdateStrategicResources` | new | confirmed | each country's level of each resource; only ever raised |
| `0x28BEF0` | `CCountry::GetsStrategicResourcesFrom` | new | confirmed | who is given whose resources |
| `0x28BB90` | `RebuildStrategicResourceProvinces` | new | confirmed | the provinces of each resource |
| `0x28BD60` | `CollectSeaNeighboursOfNavalBases` | new | inferred | the name's "sea" rests on `is_land` |
| `0x2EBD0` | `MarkRegionsTouched` | new | inferred | what the entries are is not established |
| `0x282C58` | `RunDailyPass_UpdateStrategicResources` | new | confirmed | the first thing a day does |
| `0x25B06B` | `CInGameIdler_Enter_StrategicResourcesOnlyOnLoad` | new | confirmed | a new game skips it |
| `0xDEA50` | `RebuildStaticModifiers_AddControlledProvinceModifiers` | revised | confirmed | no longer says it carries strategic resources |
| `0x168640C` | `g_strategic_resources` | new | confirmed | the database |
| `0x16861E0` | `g_triggered_modifiers` | new | confirmed | the database |

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| `CStrategicResource` | - | the struct itself, 0x50 bytes over `CModifier` | | new |
| `CStrategicResource` | `+0x2C` | `name_token` | `int` | new |
| `CStrategicResource` | `+0x30` | `key` | `Hoi3CString` | new |
| `CStrategicResource` | `+0x4C` | `index` | `int` | new |
| `CCountry` | `+0x648` | `active_modifiers` | `CList` | revised - the comment says what it holds and how an entry expires |
| `CCountry` | `+0x658` | `triggered_modifiers` | `void*` | new |
| `CCountry` | `+0x668` | `strategic_resource_modifiers` | `void*` | new |
| `CCountry` | `+0x678` | `strategic_resource_levels` | `int*` | new |
| `CCountry` | `+0x67C` | `strategic_resource_levels_end` | `int*` | new |
| `CCountry` | `+0x700` | `unfilled_modifier` | `CModifier` | new |
| `CCountry` | `+0xAD4` | `war_exhaustion_modifier` | `CStaticModifier` | new |
| `CCountry` | `+0xB1C` | `dissent_modifier` | `CStaticModifier` | new |
| `CCountry` | `+0xB64` | `neutrality_modifier` | `CStaticModifier` | new |
| `CMinisterType` | `+0x50` | `decay` | `int*` | new |
| `CGameState`, `CCurrentGameState` | `+0xF4` | `strategic_resource_provinces` | `void*` | new |
| `CGameState`, `CCurrentGameState` | `+0x104` | `player_strategic_resource_provinces` | `void*` | new |

## 2. The rebuild, in order

`0x4DDD80` to the `ret 4` at `0x4DF97D`. The destination of every addition is `country + 0xD90`,
kept at `[esp+0x10]` from `0x4DDDFA`; its values pointer is the `+0xDA8` everything reads. Each step
adds one modifier's values id by id and appends that modifier to the country modifier's contributor
vector, which is what a tooltip lists.

| | what is added | when |
| --- | --- | --- |
| 1 | nothing - the modifier is cleared | always |
| 2 | static `base_values` | always |
| 3 | the faction's own modifier (`CFaction +0x7C`) | the faction is a real one |
| 4 | *`tech_decay_modifier` is zeroed* | |
| 5 | **each minister's type for the post he holds** | the minister is a real one |
| 6 | *technology's per-category decay into `tech_decay_modifier`* | |
| 7 | **each law** | the law is a real one |
| 8 | **the government** | always |
| 9 | **each strategic resource, times the country's level of it** | the level is above 0 |
| 10 | the modifier of every province the country controls | always |
| 11 | static `war`, or static `peace` | at war, or not |
| 12 | the two espionage unity modifiers | another country's spies are here |
| 13 | static `war_exhaustion`, times the country's war exhaustion | the block exists |
| 14 | static `dissent`, times the country's dissent | the block exists |
| 15 | static `neutrality`, times effective neutrality / 100 | the block exists |
| 16 | the modifier embedded at `+0x700` | always; nothing found that fills it |
| 17 | **each event modifier** | not expired |
| 18 | **each triggered modifier on the country's list** | |
| 19 | the overlord's faction's `align_towards_*` | a subject in no faction, its overlord in one |
| 20 | a difficulty block | not on normal |
| 21 | static `government_in_exile` | in exile |
| 22 | static `fractured_government` | `0x4F7160` says so; unread |

**Not in it:** an ideology, and technology, which the consumers read beside the modifier.

### Ministers, and what `decay` does

For cabinet post `i`, the minister's `postings` list is searched for the `i`-th government position
and the type found is added; a minister with no entry for the post he holds counts as the shared
`noMinisterType`, which is empty. So the same man is a different modifier in a different seat, which
`modifiers.md` had as inference.

Straight after, the same type's array at `CMinisterType +0x50` is added into the country's
`tech_decay_modifier`, one int per technology category:

    0x4DE36F  mov eax, [eax+0x50]         ; the type's decay array
    0x4DE372  mov edx, [eax+edi*4]
    0x4DE375  mov eax, [ebx+0x1174]       ; country->tech_decay_modifier
    0x4DE37B  add [eax+edi*4], edx

That array is `decay = { naval_engineering = -0.25 }` in `minister_types.txt`, on 24 of the types. It
is what `FINDINGS-research.md` could not place. The monthly decay step multiplies by
`1000 + tech_decay_modifier[category]`, so -0.25 takes a quarter off that category's decay.

### The scaled statics

Three static modifiers are copied into a `CStaticModifier` of the country's own and every value
multiplied by a factor over 1000 before being added:

| static | the country's copy | factor |
| --- | --- | --- |
| `war_exhaustion` | `+0xAD4` | `war_exhaustion` (`+0xAD0`) |
| `dissent` | `+0xB1C` | `dissent` (`+0x10B4`) |
| `neutrality` | `+0xB64` | `max(neutrality - threat from the highest threat, 0) * 1000 / 100000` |

So `dissent = { global_ic = -0.01 }` is 1% of IC for each point of dissent, and
`neutrality = { drift_speed = 0.05 }` is 0.05 at a neutrality of 100. The 100000 is the float
`100000.5` floored (`0x160A718`).

### Event modifiers

`active_modifiers` (`+0x648`) is what `add_country_modifier` fills and what a save writes as
`modifier = { modifier = us_new_deal date = 1.1.1.0 }`. Each entry has the modifier at `+8` and a
date at `+0xC`:

    if (today > entry->date && year(entry->date) > 1)   remove and delete the entry
    else                                                add entry->modifier

A date in year 1 or earlier is how one with no end is stored.

### Difficulty

`gamestate->difficulty` (`+0xC98`, 0 to 4) through two jump tables, one for a country in
`played_countries_array` and one for the rest:

| | 0 | 1 | 2 | 3 | 4 |
| --- | --- | --- | --- | --- | --- |
| played | `very_easy_player` | `easy_player` | nothing | `hard_player` | `very_hard_player` |
| not played | `very_easy_ai` | `easy_ai` | nothing | `hard_ai` | `very_hard_ai` |

## 3. Triggered modifiers

`UpdateTriggeredModifiers` (`0x4D8070`), called immediately before `RebuildStaticModifiers` in
`RunCountryDailyPass` and in `CInGameIdler::Enter`, and nowhere else:

    for each entry of triggered_modifiers.txt, in file order
        if (entry.AppliesTo(country) && the country's list does not hold it)
            append it                       ; a message, for the player's country
    for each entry on the country's list
        if (!entry.AppliesTo(country))
            remove it                       ; a message, for the player's country

`AppliesTo` (`0x45BC00`) builds a country scope and evaluates the entry's `potential` and then its
`trigger`; both must hold. So a triggered modifier is tested **once a day for every country** and is
on or off from that day's rebuild. Country id 0 is skipped.

## 4. Strategic resources

### The level

`UpdateStrategicResources` (`0x68C190`), the game state in `EDI`. For each resource and each province
that has it:

    infra      = values[INFRASTRUCTURE] * (1000 + values[LOCAL_INFRASTRUCTURE] + values[GLOBAL_INFRASTRUCTURE]) / 1000
    infra      = min(max(infra, 10), 1000)
    efficiency = max(infra * 1000 / province->MaxInfrastructure + values[105], 0)

- The values are the province's own modifier. `MaxInfrastructure` (`+0x5C`) is what the province's
  infrastructure was built to, so **the efficiency is the share of its infrastructure still
  standing**: 1 for an undamaged province, less for a bombed one.
- A province with **no** infrastructure has a quotient of -1 and gives nothing.
- Entry 105 is added flat. Its definition key duplicates `NAVAL_INTEL_BOOST`; which script key
  writes it was not established.

Then, for every country that owns at least one province and is given the controller's resources
(below):

    country->strategic_resource_levels[resource] = max(what it holds, efficiency)       0x68C388

**It is a maximum, so a resource counts once however many provinces of it a country has the use
of, at the best of them.** That much is the instruction itself.

**That nothing lowers it is a scan's negative, not something watched.** Every instruction that
reaches the array through its displacement is accounted for - the constructor's zero fill, the
zeroing in the country reset (`0x4D2B60`), the destructor, three reads, and the raise above - and
the reset is called from the constructor and, for every country, from `CGameState::ResetSession`
(`0x67BDFC`). So by the scan a country that loses the province keeps the resource, at the best
level it ever had, until the session is reset. What was not done:

- a writer handed the array some other way would not show in such a scan;
- three more stores of the displacement (`0x6478D1`, `0x705081`, `0x71283E`), which replace the
  dword at `+0x678` itself, sit in `CInGameIdler::CInGameIdler` and two unnamed functions in the
  interface's range and were taken to be other classes without proving it;
- whether loading a save goes through the reset was not traced. A save does not store the levels;
- **it has not been seen in a running game**, and no save examined has a resource province
  changing hands. BiceLib could settle it by reading the array for a country before and after it
  loses such a province.

`RebuildStaticModifiers` step 9 then copies the resource's modifier, multiplies every value by
`level / 1000`, and adds it.

### Who is given whose

`CCountry::GetsStrategicResourcesFrom` (`0x68BEF0`), `this` the receiver:

    the same country                                            -> yes
    at war with each other                                      -> no
    one of:
      (receiver is_major  OR  receiver max_ic > 100)
          AND receiver's faction is real AND holder is in it
      receiver's faction is real AND receiver is its leader
          AND holder is NOT in it AND receiver is at war
          AND holder's alignment is within FACTION_STRAT_BONUS_DIST of the faction
    and then one of:
      the two acting capitals are on continents of the same name
      both have a naval base beside a sea province of the same entry of CMap +0x2A5C

So a faction's **majors and its countries with more than 100 IC** share what any member holds, and a
faction's **leader at war** also gets the resources of outsiders aligned closely enough to it. The
leader is the first of the faction's `Members`. `max_ic` is the province sum before the country's
own bonuses (`FINDINGS-ic.md`).

The second link was read as arithmetic only: `CollectSeaNeighboursOfNavalBases` gathers the
non-land neighbours of each country's naval bases, `MarkRegionsTouched` marks which entries of the
object at `CMap +0x2A5C` those provinces fall in, and the answer is yes when one entry is marked for
both. What the entries are - named sea regions is the natural reading - was not established.

### When

- **The top of every daily pass** (`0x682C58`), before any country's own, unless a scenario says
  otherwise. `image.functionStart` attributes that call to `RunHourlyPass`: `RunDailyPass` begins at
  `0x682C20` with no padding after it (trap 2).
- After a load, and in `RebuildEventCandidatesAndDailyCaches`.
- **Not on entering a new game.** `CInGameIdler::Enter` calls it only under
  `loaded_from_save != 0` (`0x65B06B`). So when `SetUpCountryForNewGame` runs every level is 0, and
  the starting manpower it reads off `max_manpower` is worked out without any resource. That is the
  thing `FINDINGS-manpowergain.md` section 7 measured and could not explain.

## 5. Against a savegame

The vanilla Their Finest Hour saves of `FINDINGS-manpowergain.md`: 1 January 1936 two daily passes
in, and four later ones of the same game.

- **The United Kingdom's manpower fits exactly** once it is given France's black soil: both are
  majors in the Allies with capitals in Europe. It started without the 10% and gained with it, which
  is the new-game skip. That was the one country of the four misfits nothing had explained.
- **The Soviet Union and France** fit as before, now for a reason.
- **No money figure moved**: the Netherlands, the Philippines and South Africa hold gold and none of
  them is in a faction with a major on its own continent, so all 100 still agree.
- **The Soviet Union's research** on atomic theory agrees again only with its heavy water counted,
  which is the level reaching `nuke_research`.
- **Minister decay**: of the monthly ability figures in two pairs of saves, 140 more now agree than
  could be compared before - 1067 of 1123 over February and 1042 of 1240 over March.

Still not fitting, and each now has a named cause: the United States (an event modifier from a
decision), France's manpower and ninety countries' research (triggered modifiers), Brazil (a
minister appointed after the last day ran).

## 6. Not established

- what the entries of `CMap +0x2A5C` are, and so exactly when two countries on different
  continents share;
- which script key writes province modifier entry 105;
- whether anything fills the modifier at `CCountry +0x700`;
- `0x4F7160`, the test for `fractured_government`;
- what a faction's own modifier (`CFaction +0x7C`) is loaded from;
- `0x4DD8D0`, the first helper of the country's daily pass.
