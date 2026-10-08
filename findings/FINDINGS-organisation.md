# The officer ratio, and what holds and returns a brigade's organisation

Static reading of `hoi3_tfh.exe`, image base `0x400000`, on 2026-10-08. Addresses are given as
`VA / rva`. The game was not running. Written because the rewrite's next step needed three
things the record had only as open items: who writes the officer ratio and where it is capped
(`FINDINGS-unitstart.md`, "Not established"), what raises a brigade's organisation, and what
brings one down to its ceiling.

Where a savegame is quoted it is a vanilla Their Finest Hour game played as Germany: the save
of 1 January 1936, hour 0, and one of 1 February of the same game. Those figures are marked
**measured**. Everything else is read off the bytes.

`FINDINGS-unitstart.md`, section 8, has the ceiling itself (`CSubUnit::GetMaxOrganisation` and
`CSubUnit::GetMaxOrganisationWithBonus`); `FINDINGS-opsarea.md`, section 5, has the hourly
count the ratio divides by; `FINDINGS-unitdaily.md`, section 4, has the reinforcement loop,
whose crowding term turns up again here and is now followed to its two figures.

## 1. The officer ratio

`CCountry::UpdateOfficerRatio` (`0x417C80 / 0x17C80`), the country on the stack, `ret 4`:

    most = defines->military->MAX_OFFICERS                 ; +0xAC, +0x240; kept in 0x1BEA3EC
    need = country->officers_required (+0xD0)
    if (need <= 0)  country->OfficerRatio (+0xD4) = 1000
    else            country->OfficerRatio = min(country->officers (+0xC4) * 1000 / need, most)

`__allmul` and `__alldiv`, so the division drops its remainder; `cmp eax, edi; cmovg eax, edi`
is the cap. `MAX_OFFICERS` is 1.4 in both `defines.lua` files, with the comment "officer ratio
max for bonus".

**Two callers.** `CCountry::RecountUnitTotals` (`0x5004F0 / 0x1004F0`) ends in it
(`push edi; call` at `0x50079F`), so the ratio is worked out wherever the count is: once an
hour for every country on `ProcessCountryFunctor`, and from that function's five other
callers, `CInGameIdler::Enter` at `0x65B4F7` among them - which is why a country has a ratio
before the first hour. The other is `ApplyCustomGameSettings` at `0x41E1CE`, straight after it
has set the country's officers from the count and the custom game's own figures.

**Two things about `RecountUnitTotals` the record had wrong or lacked.** It takes no stack
argument: the country arrives in `EDI` and no caller pushes anything (`0x68EDC1`, `0x4E3989`,
`0x65B4F7`, `0x41E0E5`); the `[ebp+8]` reads a scan finds past `0x5007AB` belong to the next
function. And the hourly call is behind `cmp byte ptr [edi+0x44], 0; je` in the functor - a
country whose `+0x44` byte is clear is not counted. What that byte is was not followed.

**What it divides by** is `FINDINGS-opsarea.md`'s `+0xD0`: the sum of `definition->officers`
(`+0x118`) over every brigade, ship and wing of the country's own units that are not lent
out, of the units lent to it, and of its finished units waiting to be placed. It is each
brigade's own definition, and nothing is left out for being weak - unlike the sum a new game
gives the country its officers from (`FINDINGS-unitstart.md`, section 7), which is the units'
definitions and so misses a support brigade that has stopped counting.

**In the hour, the units go first.** `RunHourlyPass` spawns `ProcessUnitFunctor` at `0x682887`
and `ProcessCountryFunctor` at `0x6828D4` (`FINDINGS-tick.md`). So an hour's organisation is
worked out with the ratio the hour before left.

This closes `FINDINGS-unitstart.md`'s "where `OfficerRatio` is capped": Germany's history gives
it 1.5 times what its units call for, and the cap makes that 1.4.

## 2. What is held to the ceiling, and by whom

`CSubUnit::GetMaxOrganisation` (`0x5AB700`) has 24 callers. Most only read it - tooltips, the
AI's averages, `GetUnitAverageStrengthAndOrganisation`. Four write a brigade's organisation
from it:

| caller | flags | what it does |
| --- | --- | --- |
| `CSubUnit::AfterLoad` (`0x5A926B`) | 1, 0 | `organisation = min(organisation, ceiling)`, for a brigade with a historical model |
| `CSubUnit::ApplyTechnologies` (`0x5AC170`) | 0, 0 | the same, and strength to its own ceiling first - only when its second argument is clear, which is how the upgrade share calls it (`FINDINGS-unitdaily.md`, section 5) |
| `CChangeLawCommand::Execute` (`0x54F9A6`, `0x54F9B6`) | 0, 0 | section 5 |
| `CSubUnit::RegainOrganisation` (`0x5ABBC5`, through `GetMaxOrganisationWithBonus`) | 0, 0 | section 3: every hour |

The two flags are `GetMaxOrganisationWithBonus`'s reserve gate, as `FINDINGS-unitstart.md` has
it: with both clear a reserve is kept short while its country is neither mobilised nor at war.

**And the ceiling is the type's own figure and nothing else while `in_game` is clear**
(`0x5AB85E`). That matters more than it looks: section 6.

## 3. The hourly return

`CUnit::UpdateHourly` (`0x5B9C50 / 0x1B9C50`) opens with it:

    if (unit->combats_count (+0x11C) <= 0 && !CUnit::IsMovingOntoEnemyGround(unit))
        CUnit::RegainOrganisation(unit)                                  ; 0x5C6A60
    if (unit->combats_count <= 0 && unit->+0x97)                         ; a flag, cleared here
        every brigade's organisation = max(organisation * PARATROOP_DROP_ORG_MULT / 1000, 0)

`CUnit::IsMovingOntoEnemyGround` (`0x5B9BD0 / 0x1B9BD0`, the unit in `EAX`, a bool in `AL`):
the unit has provinces left to move through (`+0x140 > 0`), its `combat_cooldown` (`+0xD4`) is
not running, the next province (`+0x138`, through the map's province array) has a controller,
and `CCountry::IsEnemy` (`0x42F210`) answers yes for that controller and the unit's owner. The
name is ours and `inferred`: the four tests are read, the reading of them together is not.

### The unit's part: `CUnit::RegainOrganisation` (`0x5C6A60 / 0x1C6A60`)

`this` in `ECX`, bare `ret`. One caller. Read through:

    if (combats_count > 0) return
    if (IsLand() && the object slot 9 answers has +0x300 set                  ; an army aboard a fleet
              && that fleet's province is not land (template +0x22 clear)) return

    owner  = countries[unit->owner_id (+0x128)]
    factor = unit->supply_received_percentage (+0xFC)

    province = unit->current_province_ptr (+0x130)
    if (province->path_node_ptr->is_land (+0x22))
        m     = province->modifiers (+0x114)
        roads = m[INFRASTRUCTURE] * (m[LOCAL_INFRASTRUCTURE] + m[GLOBAL_INFRASTRUCTURE] + 1000) / 1000
        roads = clamp(roads, 10, 1000)                                        ; floor(10.5f), kept in 0x1BEA400
        factor = roads * factor / 1000

    ratio = owner->OfficerRatio (+0xD4)
    if (unit->expeditionary_owner_id (+0x290))
        lender = countries[that id]
        if (no scenario, or the scenario lists the lender) ratio = lender->OfficerRatio
    factor = ratio * factor / 1000

    if (!IsLand() && unit->home_base_ptr (+0x98))
        factor = crowding * factor / 1000                                     ; section 4

    factor = (owner->modifier[ORG_REGAIN] + 1000) * factor / 1000             ; id 67; 0x170D8E4 holds the 1000
    if (unit->supply_received_percentage == 0) factor = -1000

    hq    = the unit of oob_level 2 above, exactly as GetMaxOrganisation finds it, or none
    bonus = hq ? CommandReach(unit, hq->oob_level) * hq->leader->skill * 1000 / 1000 : 0
    for each brigade: CSubUnit::RegainOrganisation(brigade, factor, bonus)

The three infrastructure modifiers are entries 12, 13 and 14 of the province's own modifier
values (`+0x60`, `+0x68`, `+0x70`), and a building's `infrastructure = 0.1` a level is what
fills the first. Every step is an `imul` and an `__alldiv` by 1000, in the order written.

**A unit that was given no supplies at all does not merely stop: its factor is minus one**, and
the brigade's part below then takes organisation off. A unit given a thousandth of what it
asked for gains a thousandth as fast.

### The brigade's part: `CSubUnit::RegainOrganisation` (`0x5ABB60 / 0x1ABB60`)

The brigade in `EDI`, the factor and the bonus on the stack, `ret 8`. One caller.

    low     = defines->military->LOW_ORG_REGAIN_BONUS            ; +0x244; kept in 0x1BEBBD8
    ceiling = GetMaxOrganisationWithBonus(brigade, 0, 0, bonus)
    share   = ceiling ? brigade->organisation * 1000 / ceiling : -1
    if      (share < 250) factor = (low + 1000) * factor / 1000   ; 0x1A886EC
    else if (share > 750) factor = (1000 - low) * factor / 1000   ; 0x1A886D8
    gain = definition->morale (+0xF4) * factor / 1000
    gain = gain * 200 / 1000                                      ; 0x1A88688
    if (a land brigade whose unit's order is of type 0x5A4)       ; strategic redeployment
        gain = max(gain - STRAT_REDEP_ORG_LOSS, 0)                ; military +0x1EC
    organisation += gain
    if (organisation > ceiling) organisation = ceiling
    if (organisation < 0)       organisation = 0

So in an hour a brigade gains a fifth of its `default_morale` times the unit's factor: 0.06 for
infantry with 0.30, in supply on full infrastructure with all its officers. Under a quarter of
its ceiling it gains `LOW_ORG_REGAIN_BONUS` faster, over three quarters that much slower; the
define is 0.3 in Their Finest Hour and 0.25 in the base game's file.

**The same routine is what brings a brigade down.** The clamp to the ceiling is unconditional,
so a brigade above its ceiling - because a law changed, officers were lost, a commander left -
is at it an hour later, whatever it would have gained.

The three thresholds are statics copied at startup from the truncated floats the image keeps:
`0x1A88688` from `0x1A88678`, which is `floor(200.5)`; `0x1A886EC` from `0x1A88690`,
`floor(250.5)`; `0x1A886D8` from `0x1A886A4`, `floor(750.5)`. None is a define.

## 4. A crowded base

The term in section 3, and the one `CDistributeReinforcement::Distribute` computes for itself
(`FINDINGS-unitdaily.md`, section 4), are the same arithmetic:

    base  = unit->home_base_ptr (+0x98)                  ; a CUnitBaseProvince or a CUnitBaseCarrier
    based = 1000 * the brigades of every unit on base's list (+4)
    room  = a fleet:      NavalBaseCapacity(base->slot0())
            an air unit:  based, if base->slot1() and base->slot0() is where the unit is
                          else base->slot0()->+0x304->level_current (+0x24)
    crowding = based > 0 ? room * 1000 / based : 1000
    crowding = clamp(crowding, 250, 1000)                ; floor(250.5f)

`slot1` is `IsCarrier` (`FINDINGS-aiconsumer.md`): **an air group aboard its carrier, where the
carrier is, is never crowded.** `FINDINGS-unitdaily.md` had that line as "an air unit standing
on its own base", which is wrong for an airfield and is corrected there.

**`CMapProvince +0x304` is the province's air base**, a `CProvinceBuilding` like the naval base
at `+0x300` beside it; the record had it as `ai_param_building`, "which building it points at
was not established". So an airfield has room for one wing a level.

**`NavalBaseCapacity` (`0x4A75D0 / 0xA75D0`), read here rather than taken from the DLL:**

    room = defines->military->NAVAL_BASE_EFFICIENCY (+0x274) * naval_base->level_current / 1000
    c    = the province's controller (+0x334)
    room = room * (c->technology_status (+0xDF8)->+0x7C + 1000 + c->modifier[NAVAL_BASE_EFFICIENCY]) / 1000

The record's comment called the define a supply one; `+0xAC` is the military block and
`+0x274` in it is `NAVAL_BASE_EFFICIENCY`, 6 in Their Finest Hour: six ships a level.
**`CTechnologyStatus +0x7C` is taken to be what the technology key `naval_base_efficiency`
adds up to**, by the same reasoning as `+0x94` and `ic_efficiency`
(`FINDINGS-unitdaily.md`, section 6) and with less behind it: no figure here measures it.

A province's two base objects are separate (`CMapProvince +0x54` for wings, `+0x58` for
fleets), so ships do not crowd an airfield. Each is the province's, not a country's, so every
unit based there is on its list whoever owns it - `inferred` from that, not watched.

## 5. A change of law

`CChangeLawCommand::Execute` (`0x54EF60 / 0x14EF60`), after it has put the law in its group and
shown the player his message, from `0x54F7FD`:

    CCountry::RebuildStaticModifiers(country)
    for each of country->Constructions (+0xF40):  construction->vf14()
    for each unit of country->units (+0xBAC), each brigade:
        over = brigade->strength - brigade->GetMaxStrength(0, 0)
        if (over > 0)
            country->Manpower += over * 1000 / definition->max_strength
                                 * definition->build_cost_manpower / 1000        ; floored at 0
            brigade->strength_ceiling (+0x30) = 0
            brigade->strength = max(GetMaxStrength(0, 0), 0)
            strength_ceiling raised to it
        if (GetMaxOrganisation(brigade, 0, 0) < brigade->organisation)
            brigade->organisation = max(that, 0)

**Any law, not only conscription**: the loop is not conditional on the group. So a change of
law holds every brigade of the country to both ceilings at once and gives back the men of the
strength taken off - which is what demobilising costs and returns - and it is the one place
besides the hourly return where a brigade's organisation is brought down.

## 6. Against the save

The checking is OpenHOI3's `tools/OpenHOI3.SaveCheck`, which builds every brigade as
`FINDINGS-unitstart.md` describes, runs the two days the original has behind it on the first
screen (`FINDINGS-unitdaily.md`, sections 4 and 5, have what they do to a brigade) and sets
each brigade's `organisation` beside the save's. All **measured**, on the save of 1 January
1936.

- **The ratio.** Taking each country's `officers` from the save over the `officers` of every
  brigade the save gives it - the 86 headquarters its AI added among them - and capping at 1.4
  gives the ratio every figure below is computed with: 0.985 for Britain (11939.444 of 12110),
  0.977 for Hungary (3617.698 of 3700), 0.986 for the Soviet Union, and the cap for Germany.
- **Of the 75 countries whose brigades could tell, 74 have some below what the two days left
  them**, and for those every
  brigade not under an army that has a commander is at
  `min(what it had, the section 2 ceiling with both flags clear and no bonus)`: **2676 of
  2676, to the thousandth.** Germany's reserve infantry at 28.000 (40 x 0.5 x 1.4), a Hungarian
  headquarters at 29.310 (30 x 0.977), Soviet reserves at 8.627. Turkey's are where the two
  days left them, and so are the 266 brigades of countries where the two readings agree.
- **So what held them was a change of law after the two days**, section 5, and not an hour of
  section 3: an hour would also have raised every German regular from 40 towards 56, and they
  are at exactly 40.000. This fits what `FINDINGS-unitstart.md` and `FINDINGS-unitdaily.md`
  found from other figures - the AI changes training laws and industrial policy after the last
  daily pass is run. It is `inferred`: nothing in a save says which countries had a law
  changed, and the test here is only "is any brigade below what it had".
- **Under an army with a commander, 142 of 764 fit without the bonus.** Of the 622 that do
  not, 136 are above the bonus-less ceiling and where the two days left them, and 486 are
  below that and at the figure a bonus of a whole number gives: 1.00 for 339, 2.00 for 105,
  3.00 for 30, and 0.82 to 1.30 for 12. That is a commander's skill times a reach that is
  usually the whole of it. The chain of command that fits is the files' own, not the save's:
  a Soviet division the save has straight under one of the AI's theatres, which has no army,
  is held as its file's army holds it. So the theatres were made after the laws were changed.
- **Three brigades are above what they started with**: Germany's Waffen-SS, at 55.107 from 55.
  They are the only brigades in the game that had room: a doctrine raised their own figure
  from 55 to 60 on the first of the two days (`mechanized_offensive`, free and whole in a day),
  and nobody else's country had the officers. One hour of section 3 gives exactly that -
  morale 0.55, Berlin's infrastructure 1.0, ratio 1.4, and 0.7 for being over three quarters
  of 60: `550 * 980 / 1000 = 539`, `539 * 200 / 1000 = 107`. **But only if the ceiling is 60
  and not 84**, which is what it is while `in_game` is clear. With the ratio in the ceiling
  the brigade is under three quarters of it and the hour gives 0.154.
- **So the two days are run before `in_game` is set, an hour before each day.** `inferred`
  from the last point and from nothing else: an hour before the first day finds every brigade
  at its type's figure and changes nothing, the first day's upgrades raise the Waffen-SS, the
  hour before the second day gives them 0.107, and nothing after the second day's upgrades
  runs an hour. The routine that runs those two days has never been found; this is what it
  has to do.
- **A month on, every German brigade is at its ceiling**: all 172 in the save of 1 February
  1936 are at their own figure times 1.4 - 56.000 for the 40s, 49.000 for the 35s, 70.000 for
  mountain troops, 42.000 for ships of 30, 84.000 for the Waffen-SS - and the reserves at half
  of that. Ships and wings take the country's ratio like the rest.

## What is not established

- **The loop that runs the two days**, and with it whether "an hour before each day" is how
  it is written or only what it comes to.
- **A commander's reach** in the bonus: `CUnit::CommandReach` is recorded (`CLASSES.md`) and
  falls with distance; the twelve fractional bonuses above were not reproduced.
- **`CUnit +0x97`**, the flag that multiplies organisation by `PARATROOP_DROP_ORG_MULT` once
  the unit is out of combat: its writer was not looked for.
- **`CCountry +0x44`**, which gates the hourly recount.
- **`CTechnologyStatus +0x7C`**, section 4.
- **The `REB` test further down `CUnit::UpdateHourly`** (`0x5B9F1D`): a rebel unit whose
  brigades' strength adds up to less than `0x1A88740`, which is 100, is handed to `0x684C80`.
  Not followed.
- **Order type `0x5A4`** is called strategic redeployment on the strength of the define
  subtracted for it and nothing else.
- **Everything live.** Nothing here was watched happening; the measurements are of savegames.

## In the record

Entered the same day through `fragments/merged/organisation.json`:
`CCountry::UpdateOfficerRatio` (`0x17C80`), `CUnit::RegainOrganisation` (`0x1C6A60`),
`CSubUnit::RegainOrganisation` (`0x1ABB60`) and `CUnit::IsMovingOntoEnemyGround` (`0x1B9BD0`,
`inferred`) new; `CCountry::RecountUnitTotals` (no stack argument, the tail call, and from
`likely` to `confirmed`), `CUnit::UpdateHourly`, `CChangeLawCommand::Execute` and
`NavalBaseCapacity` (from `inferred` off the DLL to `confirmed` off the bytes, and the define
named) revised; four globals - `g_OrganisationRegainHourlyShare` (`0x1688688`),
`g_OrganisationLowShare` (`0x16886EC`), `g_OrganisationHighShare` (`0x16886D8`) and
`g_MAX_OFFICERS` (`0x17EA3EC`); `CMapProvince +0x304` renamed `air_base` and typed, and
`CUnit +0x97` and `CTechnologyStatus +0x7C` given a name each. The names are ours.
