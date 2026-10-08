# Leadership: the total, its four shares, two province modifiers, and what a country starts a game with

Static reading of `hoi3_tfh.exe`, image base `0x400000`, on 2026-10-07. Addresses are given
as `VA / rva`. The game was not running. Written because the rewrite's leadership spec needed
three things nothing here had: how `TotalLeadership` is worked out, what the officer and
diplomacy shares do with theirs, and exactly when a province is `overseas` or `non_core`.
Looking for where diplomatic influence begins then found the function that fills a country's
stockpile at the start of a game, which is section 10 and answers what the rewrite's stockpile
spec had only measured.

Where a savegame is quoted it is a vanilla Their Finest Hour save from 1 January 1936, hour 0,
two daily passes in, and the figure is marked **measured**. Everything else is read off the
bytes.

**Three corrections to what was already written**, each detailed below:

- `CDistributeNCO::Distribute` **does** store its result. `FINDINGS-production.md` and the
  record said "it stores nothing - the officers are the return value".
- `CDistributeDiplomacy::Distribute` has **no cap**. What was read as a clamp is a floor at zero.
- `FINDINGS-revolt.md`'s table of the province rebuild has static `+0x34` as the non-core
  modifier. `+0x34` is `blockaded`; `non_core` is `+0x4C`, under a different test.

## 1. `CCountry::UpdateTotalLeadership` - `0x4D9170 / 0xD9170`

Not in the record until now; `FINDINGS-politics.md` lists it as "reads
`SHARE_TECH_LEADERSHIP_COST` - the tech-sharing leadership drain", which is its last third.
**The country arrives in `ESI`**, nothing is on the stack, and it ends in a bare `ret` at
`0x4D9499` with `int3` after. It is the only writer of `CCountry +0xBD8` (`TotalLeadership`) in
the image apart from the constructor (`fieldchain.py --field 0xBD8 --writes`: fifteen
candidates, nine in this function, one in the constructor `0x4C8A40`, the rest stack frames).

All thousandths, every division `__alldiv` and so truncating:

    total = 0
    for each node of ControlledProvinces (+0xD00; id at node +0, next at +8):     ; 0x4D9218
        province = gamestate->provinces (+0xB8C)[id]
        values   = province->modifiers (+0x114)
        local    = values[LOCAL_LEADERSHIP_MODIFIER] + 1000                       ; id 34, +0x110
        if local < 0: local = 0                                                   ; jns at 0x4D9246
        part     = (province->leadership (+0x324) + values[LOCAL_LEADERSHIP])     ; id 32, +0x100
                   * local / 1000
        if part < 0: part = 0
        total   += part
    total += countryValues[GLOBAL_LEADERSHIP]                                     ; id 33, 0x4D9280
    total  = total * (1000 + countryValues[GLOBAL_LEADERSHIP_MODIFIER]            ; id 35
                           + technology_status->leadership_gain (+0xB8)) / 1000   ; 0x4D92A7
    if total < 1000: total = 1000                                                 ; 0x4D92BC

So, for a modder: **a country's leadership is what the provinces it controls give, each scaled
by its own local modifier, plus a flat `global_leadership`, all scaled by one plus
`global_leadership_modifier` plus the technology bonus - and never less than 1.** Four things
worth stating:

- **It walks the controlled provinces**, the same list `CCountry::UpdateIC` walks.
- **The flat `global_leadership` is inside the multiplication.** `base_values` gives every
  country 3.5, and a law worth +20% makes that 4.2.
- **The technology bonus is added to the modifier, not multiplied with it** - the same shape
  as IC's.
- **The floor is on the result.** A country cannot be modded below 1 leadership.

`countryValues` is `[country + 0xDA8]`, eight bytes an entry. `technology_status +0xB8` is the
field the record carries on `CTechStatistics` as `leadership_gain`; the technology files' key is
`leadership_gain` too.

### The tech-sharing drain

    cost = defines->diplomacy (+0xBC)->SHARE_TECH_LEADERSHIP_COST (+0xC0)          ; 0x4D92CB
    n    = (country->+0x6F4 - country->+0x6F0) / 12                                ; 0x4D92DD
    while total < n * cost + 1000:                                                 ; 0x4D9361
        CCountry::StopSharingTechWith(country, GetCountry(&shares[n - 1]))         ; 0x4D9381
        n = (+0x6F4 - +0x6F0) / 12
    total -= n * cost                                                              ; 0x4D9487

`n` goes through a float: `(float)n + 0.0005` times `1000.0`, then `floorf` and `_ftol2_sse` -
which is `n` as thousandths, the two doubles at `0x160A460` and `0x160A300` being `0.0005` and
`1000.0`. **Those are the two constants `FINDINGS-research.md` lists as not read**; they are the
ordinary int-to-thousandths conversion and mean nothing by themselves.

So **each technology category a country shares costs it `SHARE_TECH_LEADERSHIP_COST`
leadership, taken off after everything else, and it is never left with less than 1: the newest
agreements are cancelled until what remains pays for the rest.**

`+0x6F0`/`+0x6F4` is a vector of twelve-byte entries. `0x507C10 / 0x107C10` (`this` in `ecx`,
one stack argument, `ret 4`) finds the entry whose second dword is the other country's id,
erases it, and - when the other country's `category_shared_from` (`+0x6A8`) entry at the index
held in the erased entry's third dword names this country - resets that to the tag `---` with
id 0; then it looks again, until no entry names that country. So an entry is
`{ CCountryTag receiver; int category }`. That the vector is "what this country shares, and
with whom" is `inferred` from that and from the define's name; its writer was not read.

### When it runs

Two callers (`findRefs.py --callers`):

- `0x4DAEA7`, in `RunCountryDailyPass`, straight after the neutrality drift and `0x507DF0` and
  unconditionally - **every country, every day, before the economy block**;
- `0x65B2B7`, in `CInGameIdler::Enter`, between `CCountry::RebuildRules` and
  `UpdateIC(country, 0)` - **once on entering a game**, after `RebuildStaticModifiers`.

## 2. The loop over the leadership shares - `0x4DB5BE / 0xDB5BE`

In `RunCountryDailyPass`, the country in `ebx`, inside the same gate as the six IC shares
(`FINDINGS-distribute.md`, section 1): a country with a tag, and not `REB`.

    0x4DB5BE   if (gamestate->scenario (+0xD0C) != 0)
                   setting = LeadershipDistribution[0]                  ; officers
                   old     = setting->base_percentage; setting->base_percentage = 0
                   if (old != 0) setting->vf4()                         ; 0xABF890, a bare `ret`
    0x4DB5EC   for (i = 0; i < count(+0x5E4); i++)
                   available = ((int64)TotalLeadership << 30) / (1000 << 15)
                   LeadershipDistribution[i]->vf0(&out, available, 0)

- **`available` is the whole of `TotalLeadership`, turned from thousandths into
  `fpml::fixed_point<__int64,48,15>` by a truncating divide.** 4.2 leadership is 137625, not
  137625.6.
- **The four run in index order**: officers, diplomacy, espionage, research. Nothing is taken
  from `available` between them; each multiplies it by its own share.
- **`out` is discarded.** The caller reads nothing back.
- **In a scenario the officer share is set to nothing every day.** `gamestate +0xD0C` is the
  pointer the record names `scenario`. It is the same test that skips the dissent change in
  `CDistributeConsumerGoods::Distribute`, so the nine stand-alone battles run with no officer
  training and no dissent from consumer goods. Slot 4, which is called when the share was not
  already nothing, is the shared empty stub for every one of the ten classes but
  `CDistributeResearch`. `likely`: the campaign's savegame has every country at a quarter on
  officers, which it could not have if the pointer were set in a campaign.

## 3. `CDistributeNCO::Distribute` - `0x51DF40 / 0x11DF40`

Slot 0, `this` in `ecx`, `ret 0x10`. Read through, 0x115 bytes:

    a      = (base_percentage * available) >> 15                 ; fixed 15
    b      = (a * factor) >> 15
    rate   = (LEADERSHIP_TO_OFFICERS << 30) / (1000 << 15)        ; economy +0x2C, to fixed 15
    bonus  = (countryValues[OFFICER_RECRUITMENT] << 30) / (1000 << 15)   ; id 82, +0x290
    c      = (rate * b) >> 15
    d      = (c * (bonus + 0x8000)) >> 15
    country->officers (+0xC4) += (d * (1000 << 15)) >> 30         ; to thousandths, rounded down
    if (country->officers < 0) country->officers = 0              ; 0x51E036
    *out = 0

**It adds to `CCountry +0xC4`**, the field the save writes as `officers`: `add [esi+0xc4], eax`
at `0x51E030`. The earlier reading stopped before that instruction. So officers per day are

    share x leadership x LEADERSHIP_TO_OFFICERS x (1 + officer_recruitment)

`officer_recruitment` is on the conscription laws in Their Finest Hour, from -0.5 for a
volunteer army to +0.5 for service by requirement.

## 4. `CDistributeDiplomacy::Distribute` - `0x51E4B0 / 0x11E4B0`

Slot 0, `ret 0x10`, 0xB4 bytes:

    b    = ((base_percentage * available) >> 15 * factor) >> 15
    rate = (LEADERSHIP_TO_DIPLOMACY << 30) / (1000 << 15)         ; economy +0x4
    c    = (rate * b) >> 15
    country->diplo_influence (+0xA88) += (c * (1000 << 15)) >> 30
    if (country->diplo_influence < 0) country->diplo_influence = 0    ; 0x51E545
    *out = 0

**There is no upper limit here.** `cmp [esi+0xa88], edi` with `edi = 0` and `jge` is a floor.
No modifier is read: diplomatic influence per day is `share x leadership x
LEADERSHIP_TO_DIPLOMACY` and nothing else.

## 5. The espionage share's first step, to the bit

`FINDINGS-espionage.md` has the whole of `CDistributeEspionage::Distribute`. Its first phase,
with the order of the conversions made explicit (`0x51ED4B`..`0x51EDC6`):

    b      = ((base_percentage * available) >> 15 * factor) >> 15
    whole  = (b * (1000 << 15)) >> 30                             ; leadership in thousandths
    country->spy_pool (+0x1170) += whole * LEADERSHIP_TO_SPIES / 1000

**The leadership is turned into thousandths before the define is applied**, where the officer
and diplomacy shares apply theirs in fixed 15 first. A quarter of 4.2 leadership is 1.049 here,
and 1.049 x 0.15 truncates to 0.157.

## 6. `CCountry::GetAllowedResearchSlots`, to the bit - `0x4E0170 / 0xE0170`

The record has it as `round(base_percentage x factor x TotalLeadership)`. The arithmetic:

    p     = (factor * base_percentage) >> 15                      ; of LeadershipDistribution[3]
    share = (p * (1000 << 15)) >> 30                              ; the share in thousandths
    x     = share * TotalLeadership / 1000                        ; thousandths
    slots = fistp((float)(x / 1000.0))

Two things follow. **The share is turned into thousandths before it is multiplied by the
leadership.** And **`fistp` rounds to nearest with ties to even**, under the default control
word: 2.5 is 2 projects and 3.5 is 4.

## 7. The static modifier database, slot by slot

`g_static_modifiers` (`0x1A86208`) is recorded as a 0xBC-byte object whose `+0x18` upward are
named `CStaticModifier*`, with two of them identified. `LoadModifierDefinitions`
(`0x45A490 / 0x5A490`) fills them: from `0x45AB17` it pushes one name string after another,
looks each up (`0x5B4E00`, the database in `eax`) and stores the answer at a compiled-in
offset. Paired off by a scan of that function - each `push imm32` that is a C string with the
next `mov [esi+disp], eax`:

| offset | name | | offset | name |
| --- | --- | --- | --- | --- |
| `+0x1C` | `overseas` | | `+0x70` | `very_easy_player` |
| `+0x20` | `coastal` | | `+0x74` | `easy_player` |
| `+0x24` | `non_coastal` | | `+0x78` | `hard_player` |
| `+0x28` | `coastal_sea` | | `+0x7C` | `very_hard_player` |
| `+0x2C` | `no_adjacent_controlled` | | `+0x80` | `very_easy_ai` |
| `+0x30` | `out_of_supply` | | `+0x84` | `easy_ai` |
| `+0x34` | `blockaded` | | `+0x88` | `hard_ai` |
| `+0x38` | `land_province` | | `+0x8C` | `very_hard_ai` |
| `+0x3C` | `sea_zone` | | `+0x90` | `disrupt_production` |
| `+0x40` | `manpower` | | `+0x94` | `disrupt_research` |
| `+0x44` | `nationalism` | | `+0x98` | `spy_lower_national_unity` |
| `+0x48` | `revolt_risk` | | `+0x9C` | `spy_raise_national_unity` |
| `+0x4C` | `non_core` | | `+0xA0` | `spy_lower_neutrality` |
| `+0x50` | `war` | | `+0xA4` | `spy_support_resistance` |
| `+0x54` | `peace` | | `+0xA8` | `dissent` |
| `+0x58` | `war_exhaustion` | | `+0xAC` | `neutrality` |
| `+0x5C` | `land_maintenance` | | `+0xB0` | `initial_mobilization` |
| `+0x60` | `naval_maintenance` | | `+0xB4` | `government_in_exile` |
| `+0x64` | `base_values` | | `+0xB8` | `fractured_government` |
| `+0x6C` | `total_blockaded` | | | |

It agrees with the three the record already had by other routes: `+0x40` `manpower` and `+0x48`
`revolt_risk` (`FINDINGS-revolt.md`), `+0x98`/`+0x9C` the two spy modifiers
(`FINDINGS-espionage.md`).

- **`+0x64` is `base_values`.** `FINDINGS-ic.md` left "which modifier `[0x1A86208]+0x64` is"
  open, and the rewrite had measured it from a savegame. It is read here.
- **`+0x18` and `+0x68` are not written by this function.** No `[esi+0x18]` or `[esi+0x68]`
  store is in it. What they hold was not found.
- **`initial_mobilization` is looked up twice and stored twice at `+0xB0`**, at `0x45B6F9` and
  `0x45B73F`, the same string address both times. One of the two was presumably meant to be
  something else.

## 8. When a province is `overseas`, and when it is `non_core`

`RebuildProvinceModifierValues` (`0x49F3E0 / 0x9F3E0`), the province in `ebx`, the database in
`[esp+0x14]`. With the slots named, the block after the buildings reads:

    0x49F527   capital = GetActingCapitalLocation(countries[province->controller_id])
               if (province->area (+0x2B4) == capital->area) goto 0x49F733
    0x49F55F   if (province->Continent (+0x368) == capital->Continent) goto 0x49F733
    0x49F595   add static +0x1C                                   ; overseas

    0x49F643   if (!(province->owner_id != 0 && province->port (+0x354) != 0
                     && province->naval_base (+0x300)->level > 0))
    0x49F665       if (0x47E540(area, controller tag, controller id) == 0)
    0x49F686           add static +0x34                           ; blockaded

    0x49F733   for each node of province->cores (+0x344; id at +4, next at +0xC):
                   if (node id == province->owner_id) goto 0x49F813
    0x49F753   if (province->owner_id != province->controller_id) goto 0x49F813
    0x49F765   add static +0x4C                                   ; non_core

- **`overseas`: the province is in a different area from its controller's acting capital, and
  on a different continent.** Both, not either. The area is the `COwnerArea` - a block of
  land in one country's hands - so a province joined to the capital overland is never overseas
  however far away it is, and an island off the capital's own continent is not overseas either.
- **`blockaded` is only ever tested for a province that is overseas.** It sits inside that
  branch. A province with an owner, a port and a naval base above level 0 is exempt; otherwise
  it is blockaded when `0x47E540` answers no for its area and controller. `0x47E540` was not
  read.
- **`non_core`: the province's owner has no core on it, and the owner is also its
  controller.** The test is against the *owner*, and an occupied province gets nothing here -
  it gets the occupier's policy further down instead (`FINDINGS-occupation.md`).

In Their Finest Hour `overseas` is `local_manpower_modifier = -0.75` and
`local_leadership_modifier = -0.9`; `non_core` is -0.75 manpower, -0.8 leadership, -0.5
`local_ic` and -0.5 `local_resources`; `blockaded` is empty.

## 9. `CCountry::RebuildStaticModifiers` starts from `base_values`

Only the head of `0x4DDD80 / 0xDDD80` was read here, to settle one thing. The country is the
stack argument (`mov ebx, [ebp+8]`), and its modifier is the `CModifier` at `+0xD90`, whose
values array at `+0x18` is the `+0xDA8` everything reads.

    0x4DDDFE   clear country->global_modifier (+0xD90)            ; 0x4595C0
    0x4DDE4A   for every modifier id: values[id] += statics->base_values (+0x64)->values[id]
               and base_values is appended to the modifier's contributor list
    0x4DDEDE   if (country->faction (+0xD8) != 0 && faction->vf7())
                   the same for the CModifier at faction +0x7C

**So `base_values` is added whole to every country's modifier, first.** That is what puts
`global_leadership = 3.5` and the two consumer goods demands into it, and the rewrite had only
inferred it. The faction's own modifier follows when the faction is a real one. The rest of
the function - 0x1300 bytes and more, reaching `war` (`+0x50`), `peace` (`+0x54`),
`war_exhaustion` (`+0x58`), `land_maintenance` (`+0x5C`) and `dissent` (`+0xA8`) by the slots
it loads - **was not read**, and is the answer to what else a country's modifier is made of.

## 10. `SetUpCountryForNewGame` - what a country starts a game with

Found by looking for what writes `diplo_influence` (`fieldchain.py --field 0xA88 --writes`),
and it turned out to hold the whole starting stockpile as well. `0x4D6230 / 0xD6230` takes the
country as its one stack argument and ends `ret 4` at `0x4D757A`. It has **one caller**,
`0x65B4F2` in `CInGameIdler::Enter`, inside the block that
`gamestate->loaded_from_save (+0xD9C) == 0` guards - so it runs once for every country when a
game is started from history, and never on a load. **The function before it ends `ret 4` at
`0x4D622D` with no padding, so a walk back from `0x4D70EE` runs through that `ret` and answers
`0x4D59D0`** - trap 2, and `fieldchain.py` printed exactly that owner.

Read from `0x4D69DF` to `0x4D7108`; the listing was decoded from the function's own entry so
that it is aligned. The country is `[ebp+8]`, `now` is `[ebp-0x1C]`. "Months" below is a
calendar count: `(tick - 43800000) / 24` is a day number, the year is that over `365.0`, the
month is found by taking the lengths in the table at `0x1713294` off the day of the year, and
the figure is `year * 12 + month` - the same arithmetic four times over, inline.

### How long it has been at war

    0x4D69EC   if (country->at_war (+0xACC))
    0x4D6A72       began = now
                   for each war in gamestate->active_war (+0xC00):
                       if the country is among its attackers (+0x2C..+0x30) or defenders (+0x3C..+0x40):
                           began = min(began, 0xA51D20(war))             ; the war's date
    0x4D6BC3       months = Months(now) - Months(began)
                   country->war_exhaustion (+0xAD0) = min(months * 0.05, 10.000)
               else
    0x4D6BF8       ended = g_NullDate
                   for each war in gamestate->previous_war (+0xC20) the country was in:
                       ended = max(ended, 0xA51F40(war))
    0x4D6DB8       country->war_exhaustion = max(3.000 - (Months(now) - Months(ended)) * 0.05, 0)
                   began = now

`0.05` is `[0x1A874C0]`, a file-scope constant built at startup from the float `50.5` at
`0x160A7B4` by the usual `floorf` and `_ftol2_sse` pair (initialiser `0xCB6620`), so it is 50
in thousandths and no define moves it. It has 22 references; three are in this function.

### The days of stockpile

    0x4D6EAF   months = Months(now) - Months(began)                      ; 0 for a country at peace
               days   = 30 + 5 * max(12 - months, 2)                     ; 0x2EE0, 0x7D0, 0x1388, 0x7530
    0x4D6EEF   amount = MaxIC (+0x60C) * days                            ; thousandths
    0x4D6F1B   if (country->isSubject (+0xF34) && amount > 1000.000) amount = 1000.000

So **a country starts with 90 days of what its industry needs, less five for every month it
has been at war, and never fewer than 40.** That is the 75 the rewrite measured for Italy and
Ethiopia: their war in the history files begins on 3 October 1935, three calendar months
before 1 January 1936. It is **war, not mobilisation**, and it is the *oldest* war the country
is still in that counts. And **a subject country's IC-days are held to 1000**, whatever its
IC - Manchukuo's 1000 metal against the 1890 its 21 IC would give.

`MaxIC` is the province sum in whole IC before any law (`FINDINGS-ic.md`); `UpdateIC(country,
0)` is called at `0x4D633D`, near the top, to have it.

### What is put in the capital's pool

The pool is `GetActingCapitalLocation(country)->pool`, the goods from `+0x164`. Every one is
an `add`, so whatever the province already holds stays:

    0x4D6F3D   crude_oil (+0x170)      += amount
    0x4D6F52   metal (+0x174)          += amount
    0x4D6F9C   energy (+0x178)         += amount * 2                     ; floorf(2000.5f) / 1000
    0x4D6FF6   rare_materials (+0x17C) += amount / 2                     ; * 1000 / 2000
    0x4D7001   if (pool.money (+0x16C) == 0)
    0x4D704E       money += amount * IC_TO_MONEY / 1000 * 0.05           ; economy +0x8, [0x1A874C0]
    0x4D7054   for each unit of country->units (+0xBAC):
                   fuel     += CUnit::FuelConsumption(unit)              ; 0x5BB7A0
                   supplies += CUnit::SupplyConsumption(unit)            ; 0x5BB560
    0x4D70DB   pool.supplies (+0x164) += supplies * days
    0x4D70E8   pool.fuel (+0x168)     += fuel * days
    0x4D70EE   country->diplo_influence (+0xA88) = (MaxIC / 5) * 1000

- **Money is given only where the pool has none**, the test the rewrite had measured from
  Berlin, Madrid and the United States. It is a twentieth of what the stockpile's IC-days would
  earn at `IC_TO_MONEY`, so a mod that changes the define changes the starting money with it.
- **Starting supplies and fuel are the same number of days of what the country's units
  use.** That is why two countries with the same IC start with different amounts.
- **Starting diplomatic influence is base IC divided by five, in whole points.** `imul` by
  `0x66666667` and `sar edx, 1` is a divide by five. The five is compiled in.
- **A country's history file is applied before this**, since it is the load that fills the
  pool this adds to - which is how the United States' `money = 1` stops them being given any.

**Not read:** the function's first 0x7AF bytes, before the at-war test - they hold a second
loop over the diplomatic statuses that stamps `CDiplomacyStatus +0x54` with `now`; the block
after the influence line (`0x4D713A`..`0x4D733F`), run for a country that holds something and
is not `REB`; and the tail, which calls `ReapplyAllTechnologies` (`0x4D7346`),
`RebuildStaticModifiers` (`0x4D7380`) and `0x4E1C00`. `0xA51D20` and `0xA51F40`, the two
dates read off a war, were not opened: that they are its start and its end is `inferred` from
which list each is used on.

## 11. What the savegame says

**measured**, all of it, from the one save. The total is not saved; what three of the four
shares made in two days is.

- **Every country has its four shares at exactly 0.25** - 100 of 100.
- **A country that holds no province** has `base_values`' 3.5, times its education law. East
  Germany, with the law worth +20% and a volunteer army (officer recruitment -0.5): 4.2
  leadership, and the save has `officers = 4.198`, `diplo_influence = 2.048` and
  `spies = 0.314` - two days of 2.099, two of 0.524 on top of 1, two of 0.157. Nationalist
  Spain and Slovakia, on a one-year draft (-0.25), have 6.298 officers: two days of 3.149.
- **For 95 of the 100 countries, `officers` and `diplo_influence` less two days of this
  formula are whole numbers, and `spies` is two days of it less whole spies.** The whole
  number of officers is what the units were given at the start.
- **`diplo_influence` starts at a fifth of base IC, in whole points**, as section 10 reads.
  Less its two days, the save's figure is `MaxIC / 5` truncated for every one of those 95:
  Germany 144 base IC and 28, the Soviet Union 32, Japan 18, Luxembourg 2, and 1 for each of
  the 22 that hold nothing and have only `base_values`' five. The other five have the right
  whole part too - the United States 256 and 51. The rebels, who are skipped by the daily
  loop, sit at exactly 1.
- **The other five have triggered modifiers.** Poland, the Netherlands and France each fit a
  `global_leadership_modifier` a tenth higher than their laws give, the United States a flat
  0.15 more, and the United Kingdom both. `triggered_modifiers.txt` has `polish_corridor_pol`
  at +0.1 for a Poland that controls province 1626, and `great_naval_army` at
  `global_leadership = 0.15` for a hundred ships. So **triggered modifiers reach the country's
  modifier**, which is what section 9's unread remainder should show.
- **The starting stockpile of section 10 is the one the rewrite had measured**: metal and rare
  materials to the thousandth for 76 of 78 capitals and money for 77, with Manchukuo - a
  subject, at exactly 1000 metal, 500 rare materials and 2.5 money - one of the exceptions in
  each and the United Kingdom the other. Italy has 69 x 75 = 5175 metal.
- **Before `overseas` was applied, three more did not fit** - Belgium, Portugal and Republican
  Spain, whose only leadership outside Europe is in Africa. With section 8's two tests they do.
- **Strategic resources reach the country's modifier too.** `gold` is `global_money = 0.33` in
  `strategic_resources.txt`; the save has gold in three provinces, held by the Netherlands, the
  Philippines and South Africa, and those are exactly the three countries whose daily money is
  a third of base more than their laws give. Where that is added was not read; the Dutch
  province is in the East Indies, so the province does not have to be joined to the capital
  overland.

## What is not established

- **The rest of `CCountry::RebuildStaticModifiers`** (`0xDDD80`), from `0x4DDF9E` on. It is the
  list of what a country's modifier is made of. Triggered modifiers and strategic resources
  are in it or behind it, by section 11.
- **Whether a strategic resource counts once or once a province**, and whether the province
  must be controlled, owned, or reachable. No country in the save has two of one.
- **The unread parts of `SetUpCountryForNewGame`** (`0xD6230`), listed at the end of section
  10, and the two war dates it reads through `0xA51D20` and `0xA51F40`.
- **What takes the starting war exhaustion off again.** Section 10 gives Italy 0.150 for its
  three months at war; the save, two days on, has every country at 0.000.
- **What sets `officers` at the start.** A whole number in every country that has units;
  country history files carry `officers_ratio`. It is not in the part of section 10 that was
  read.
- **`0x47E540`**, the test behind `blockaded`, and what marks a `COwnerArea`'s edges - whether
  an area is land one country *owns* or *controls*, and whether a strait joins two.
- **`0x507DF0`**, called just before the total is worked out, with the country in `edi`. It
  reads the same vector at `+0x6F0`.
- **Who writes the vector at `CCountry +0x6F0`.**
- **Static slots `+0x18` and `+0x68`.**
- **`CDistributeResearch::Distribute`** (`0x11F620`) is still unread as a body. It is what the
  fourth share does, and the rewrite's research will need it.

## In the record

Entered the same day through `fragments/merged/leadership.json`: `CCountry::UpdateTotalLeadership`
(`0xD9170`), `CCountry::StopSharingTechWith` (`0x107C10`) and `SetUpCountryForNewGame`
(`0xD6230`) as new functions; the labels
`RunCountryDailyPass_DistributeLeadershipShares` (`0xDB5BE`),
`RebuildProvinceModifierValues_Overseas` (`0x9F527`), `RebuildProvinceModifierValues_NonCore`
(`0x9F733`) and `RebuildStaticModifiers_AddBaseValues` (`0xDDE4A`);
`CDistributeNCO::Distribute`, `CDistributeDiplomacy::Distribute` and
`CCountry::GetAllowedResearchSlots` revised as the corrections above say; `g_static_modifiers`
revised to point at its slots; the struct `CStaticModifierDataBase` declared with its 39 named
slots; `CTechnologyStatus +0xB8` `leadership_gain`; `CCountry +0x6F0`/`+0x6F4`, the
tech-sharing vector; and the global `g_OneTwentieth` (`0x16874C0`) with its initialiser. The
names are ours except where the game's own strings give them.

Applied headless to a copy of the Ghidra project: `failed: 0`, and `struct fields: 0` on the
second run.
