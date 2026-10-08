# Manpower: where it comes from

`FINDINGS-manpower.md` is what takes manpower away - reinforcement, rotation, attrition - and
was written for BiceLib's tooltip. This is the other half, read on 2026-10-08 for OpenHOI3's
`docs/mechanics/manpower.md`: what a day adds to the pool, what `max_manpower` is, and what a
new game starts a country with.

Addresses are rvas in the tables and `project.json`; the listings quoted are virtual addresses,
which are those plus `0x400000` (trap 1). Everything is in thousandths and every divide
truncates.

## 1. What was settled

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| `0xE1DA0` | `GetMonthlyManpowerGain` | new | confirmed | a twelfth of the year's manpower |
| `0xE1C00` | `UpdateMaxManpower` | new | confirmed | the year's manpower times `MAX_MANPOWER`, at least 1 |
| `0xDA932` | `RunCountryDailyPass_AddManpower` | new | confirmed | the month's figure over the days the month has |
| `0x168747C` | `g_StartingManpowerLostPerMonthAtWar` | new | confirmed | 0.12, from `floorf(120.5f)` |
| `0x8B6680` | `InitStartingManpowerLostPerMonthAtWar` | new | confirmed | its initialiser |
| `0xD6230` | `SetUpCountryForNewGame` | revised | confirmed | the tail is read: the starting manpower |
| `0xDEA50` | `RebuildStaticModifiers_AddControlledProvinceModifiers` | new | confirmed | a country's modifier takes in each controlled province's |
| `0xE1FC0` | `UpdateBlockadeLevel` | new | inferred | the share of home ports cut off; the flag it tests is the inference |

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| `CTechnologyStatus` | `+0x8C` | `manpower_gain` | `int` | new |
| `CCountry` | `+0xBD0` | `max_manpower` | `int` | revised - it is not a ceiling |
| `CCountry` | `+0xCF8` | `owned_province_count` | `int` | new |

## 2. The year's manpower

`GetMonthlyManpowerGain` and `UpdateMaxManpower` share their first half, instruction for
instruction. For every province in the country's `ControlledProvinces` (`+0xD00`):

    base   = province->manpower (+0x320) + provinceValues[3]
    factor = 1000 + provinceValues[5] + ownerValues[6]          floored at 0
    part   = base * factor / 1000                               added only when not negative

    0x4E1E53  mov ecx, [eax+0x114]        ; the province's modifier values
    0x4E1E59  mov ebx, [eax+0x320]        ; its manpower
    0x4E1E5F  mov esi, [ecx+0x28]         ; entry 5
    0x4E1E62  add ebx, [ecx+0x18]         ; entry 3
    0x4E1E68  lea ecx, [eax+0x32c]        ; the OWNER tag
    0x4E1E6E  add esi, 0x3e8
    0x4E1E74  call CCountryTag::GetCountry
    0x4E1E79  mov ecx, [eax+0xda8]        ; the owner's modifier values
    0x4E1E7F  mov eax, [ecx+0x30]         ; entry 6
    0x4E1E82  add eax, esi
    0x4E1E84  jns +2 / xor eax, eax
    0x4E1E88  imul ebx                    ; then / 1000, and floored at 0

A values array has eight bytes an entry, so `+0x18`, `+0x28` and `+0x30` are entries 3, 5 and 6
and `+0x20` below is entry 4. By what the script files put in them these are `local_manpower`,
`local_manpower_modifier`, `global_manpower_modifier` and `global_manpower`: the laws' key is a
percentage and can only be the one added to 1000, and `base_values`' `global_manpower = 4` is the
only thing that can make a country with no province gain four a year, which the savegame shows.
That agrees with the Lua names in `CLASSES.md`, *Modifiers*, and not with the definition keys,
which call 5 and 6 `LOCAL_MANPOWER` and `GLOBAL_MANPOWER`.

Three things follow that are not what one would guess:

- **The local and the global percentage are added, not multiplied.** `overseas` takes 75% off and a
  volunteer army 50%: such a province gives nothing, where multiplying would have left an eighth.
- **The law is the province owner's**, though the manpower goes to the controller. An occupier
  gets a province's manpower under the conscription law of the country it took it from.
- **`global_manpower` is added after the provinces and is not scaled by any law.**

Then, for both:

    year = (sum + countryValues[4]) * (1000 + technology_status->manpower_gain (+0x8C)) / 1000

Technology multiplies the whole. That is not leadership's shape, where the technology bonus is
added to the laws' (`FINDINGS-leadership.md`, section 2).

## 3. A month, a day, and the figure called max

**`GetMonthlyManpowerGain`** ends `year * 1000 / 12000`. The 12000 is `floorf(12000.5f)`, the
float at VA `0x160A82C`.

**`RunCountryDailyPass`** calls it at `0x4DA89A` and adds a day's part:

    day = month * 1000 / (days in this month * 1000)
    if (day > 0) country->manpower (+0xBCC) += day                       0x4DA932

The length of the month comes off `MonthLengthTable`, walked down from the day of the year. So
February's days are worth more than January's. It runs for every country, after
`RebuildStaticModifiers` and before `UpdateTotalLeadership`. **Nothing compares the pool with
`max_manpower`** - not here and not anywhere a scan for the displacement finds.

**`UpdateMaxManpower`** ends `year * MAX_MANPOWER / 1000`, floored at 1000. `MAX_MANPOWER` is the
first entry of the `military` block of `defines.lua`, 10 in Their Finest Hour. So `max_manpower`
is ten years of manpower, and its readers are the new-game setup below, two triggers and the
tooltip. The record's comment called it "the manpower ceiling"; it is corrected.

It is called once a month from `CCountry::UpdateMonthly`, on entering a game from
`CInGameIdler::Enter` straight after `UpdateTotalLeadership`, from the new-game setup, from
`ApplyCustomGameSettings`, and from `0x4DFD69` and `0x559B77`, which were not read.

## 4. The block for a government in exile

Between the province sum and the flat addition, `GetMonthlyManpowerGain` alone has this:

    if (country->government_in_exile (+0x95))
        for each province in ControlledProvinces
            if (province->controller_id (+0x338) != country->id)
                *out = province->manpower * 100 / 1000                    0x4E1F32, a mov

It **assigns**, so each such province replaces everything summed so far, and the list it walks is
the one that should hold only provinces whose controller *is* the country. Whether that list
keeps a government in exile's lost provinces, and whether the assignment is a slip for an
addition, were not established. `UpdateMaxManpower` has no such block.

## 5. What a new game starts with

The tail of `SetUpCountryForNewGame`, from `0x4D7380`:

    RebuildStaticModifiers(country)
    UpdateMaxManpower(country)
    country->manpower = country->max_manpower                             0x4D7391, a mov
    if (country->owned_province_count (+0xCF8) > 0 && country->at_war (+0xACC))
        year   = max_manpower * 1000 / MAX_MANPOWER
        months = the months the country has been at war, in thousandths
        country->manpower -= year * (1000 + months * 120 / 1000) / 1000   floored at 0

- **The `mov` discards whatever `manpower` the country's history file gave.** No history file in
  Their Finest Hour gives one.
- The months are the ones the war exhaustion and the stockpile were worked out from earlier in
  the function: calendar months since the oldest war the country is still in.
- The 120 is `g_StartingManpowerLostPerMonthAtWar`, `floorf(120.5f)`, read nowhere else.

So a country at war starts a year of manpower short, and 0.12 of a year more for each month.

## 6. A country's modifier takes in its provinces'

Found while asking why two countries start as they do (section 7). In
`CCountry::RebuildStaticModifiers`, `0x4DEA50..0x4DEB98`:

    for each province in ControlledProvinces
        for each modifier id
            countryValues[id] += provinceValues[id]                       0x4DEB20..0x4DEB3A
        record the province's modifier as a contributor

`[esp+0x10]` is the country's own modifier object, `country + 0xD90`, set at `0x4DDDFA`; its
values pointer is the `+0xDA8` everything reads. So whatever a province's modifier holds reaches
the controller's, once a province. **Likely** that is the road a strategic resource takes - it is
a modifier, on a province, with country-wide kinds in it - but the step that would put one into a
province's modifier was looked for in `RebuildProvinceModifierValues` and not found. The rest of
`RebuildStaticModifiers` is still unread.

## 7. Against a savegame

A vanilla Their Finest Hour save from 1 January 1936, two daily passes in, with four later saves
of the same game. The countries were given the laws, ministers and technology levels the save
shows, because the original's AI has already chosen its own by then.

- **East Germany**, which holds nothing, has 40.020: ten years of four, and two days of
  4 / 12 / 31 = 0.010. Across the later saves it gains 0.010 a day in January and March and 0.011
  in February and April. It passes 40 and keeps going.
- **Germany** has 882.474: (59 + 4) x 1.4 = 88.2 a year, 882 to start, 7.35 a month, 0.237 a day.
- **All 23 countries that do not exist yet, and 74 of the 78 that do, agree to the thousandth** -
  Italy and Ethiopia among them, three months into their war and each 1.36 years short.
- So **units cost no manpower in the first two days**: every one of the 74 has units.

The four that do not agree:

- **The United States** holds 254.936 against 1050.564. Its save carries the event modifier
  `us_new_deal`, which a decision gives and which takes 40% off; with it the figure is exact. The
  AI took the decision before the country was set up.
- **France** holds 580.160. It fits exactly with the triggered modifier `population_crisis`
  (-30%) from the start and its black soil (+10%) only in the two days.
- **Brazil** fits with one minister's +5% left out of both, so he was appointed after the last
  day ran.
- **The United Kingdom** started as worked out and then made 0.130 a day against 0.111, which is
  what 10% more would give. Nothing in its files or its save was found that gives it.

**The Soviet Union shows the same thing as France, alone**: its 1525.226 is a start worked out
without black soil's 10% and two days with it. So when `SetUpCountryForNewGame` runs, a strategic
resource is not yet in the country's modifier, and by the first daily pass it is.

## 8. Not established

- how a strategic resource gets into a province's or a country's modifier, and why it is missing
  when a new game is set up;
- what the government-in-exile block is for (section 4);
- `0x4DCD70`, which rewrites `CCountry +0x158` from the pool, `max_manpower` and the country's
  units - so that field is not only what the history file gave;
- the two unread callers of `UpdateMaxManpower`, and the third caller of `UpdateBlockadeLevel`;
- the byte at `CProvince +0x36C` that `UpdateBlockadeLevel` and `RebuildStaticModifiers` test;
- where the United Kingdom's extra tenth comes from.
