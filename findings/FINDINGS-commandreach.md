# How far a command reaches

Read on 2026-10-11 for OpenHOI3's second piece of leaders: how much of a headquarters' command
reaches the units under it, how a leader's trait comes down the chain, and the three places a
running game asks either - a brigade's organisation ceiling, its hourly return, and what a unit
uses. Every routine here was already in the record under a name, mostly BiceLib's, with the
shape right; what this adds is the arithmetic to the instruction, the edge cases, which unit each
caller passes, and the order a new game does things in.

**Synopsis.** A headquarters reaches a unit in full within a radius of its first brigade's
`radio_strength` times the `RADIO_*_LEADER_DISTANCE` define for its level, then by the radius
over the distance out to twice the radius, and not at all beyond. Up a chain the links multiply.
A trait's effect comes down the chain halved at every step and scaled by the same reach. An
army's commander adds his skill, times the army's reach, to every brigade's organisation
ceiling; an army group's commander takes a twentieth of his skill, times its reach, off what a
unit uses. **One correction**: `FINDINGS-unitstart.md` section 8 wrote the ceiling's call as
`CommandReach(hq, brigade)`; it is `CommandReach(the brigade's unit, 2)`, as
`FINDINGS-organisation.md` already had it for the hourly return. Set against the start save by
OpenHOI3, every brigade under an army with a commander comes out right - 764 of 764, where 142
did without.

All numbers are thousandths and every division truncates toward nothing, as everywhere.

## 1. The routines

| rva | name | what |
| --- | --- | --- |
| `0xA5500` | `ProvinceDistanceSquared` | the square of the distance between two provinces, quarters of a pixel |
| `0x1B67B0` | `CUnit::CommandReachFrom` | how much of one headquarters' command reaches one unit |
| `0x1B6980` | `CUnit::CommandReach` | the same compounded up the chain to a level |
| `0x1B6C00` | `CUnit::IsOutOfRadioRange` | whether any link above a unit lets less than all through |
| `0x1D1120` | `CUnit::CommandEffect` | one kind of trait effect, from the unit's leader and down the chain |

## 2. A headquarters' radius

Read in all three of `CommandReachFrom`, `CommandReach` and `IsOutOfRadioRange`, which inline it
identically (`0x5B67F5`..`0x5B6887`, `0x5B69FA`..`0x5B6A8C`, `0x5B6C5B`..`0x5B6CF0`):

    if the headquarters has no brigade (regiments.count +0x40 == 0):  radius = 0
    else
        radio  = its first brigade's definition (+0x38 -> data -> +0x58) ->radio_strength (+0x180)
        switch oob_level:  0 RADIO_THEATHRE_LEADER_DISTANCE (military +0x21C)
                           1 RADIO_ARMYGROUP_LEADER_DISTANCE (+0x218)
                           2 RADIO_ARMY_LEADER_DISTANCE (+0x214)
                           3 RADIO_CORPS_LEADER_DISTANCE (+0x210)
        radio  = define * radio / 1000                      __alldiv, 64-bit
        radius = radio / 1000                               the 0x10624DD3 multiply, sar 6

The switch's default skips the multiply, but nothing reaches it: every caller has already turned
away a headquarters at level 4 or more. Their Finest Hour's `hq_brigade` has `radio_strength = 2`
and the defines are 100, 200, 300 and 1000, so a corps reaches 200 in full, an army 400, an army
group 600 and a theatre 2000 - in the distance's units, quarters of a pixel (section 3), which
are the game's kilometres: an aircraft's `range` is set against the same measure. So 200, 400,
600 and 2000 km, or 50, 100, 150 and 500 pixels of the province bitmap. **The four defines' offsets were `inferred` from their order in
`defines.lua`; the switch on `oob_level` confirms the order.** `confirmed`

## 3. The distance: `ProvinceDistanceSquared` (`0xA5500`)

The first province in `EAX`, the second on the stack, `ret 4`:

    a, b = g_CMap->province_templates (+0x2A60) [province->id (+0xD0)]
    across = |a.centre_x (+0x2C) - b.centre_x|
    if across > map_width (+0x2A74) / 2:  across = map_width - across
    up = a.centre_y (+0x30) - b.centre_y
    answer = (across * across + up * up) << 4

So it is **the square of four times the pixels** between the two bounding-box centres, the short
way round - the same measure as the air range and the distances by sea, before a root is taken.
`CommandReach` and `IsOutOfRadioRange` inline the same body rather than call it. `confirmed`

## 4. One link: `CUnit::CommandReachFrom` (`0x1B67B0`)

`__stdcall (unit, out, headquarters)`, `ret 0xC`:

    if unit->current_province (+0x130) == 0 or headquarters == 0:     0
    if headquarters->oob_level >= 4 or headquarters->current_province == 0:   1000
    r  = section 2's radius;  d2 = ProvinceDistanceSquared(unit's province, its province)
    if d2 == 0 or d2 <= r * r:                                         1000
    if d2 > 4 * r * r:                                                 0
    d  = IntegerSqrt(d2)
    1000 - (d - r) * 1000 * 1000 / (d * 1000)                          the 64-bit path where the product would overflow

So the reach is **all of it within the radius, the radius over the distance out to twice the
radius - from 1000 down to 500 - and then nothing**: it falls off a cliff from a half to none at
exactly twice the radius. A fall that reached nothing smoothly at twice the radius would
divide `(d - r)` by `r`; the code divides by `d`. Whether that was intended is not knowable
from the bytes. The code keeps a guard for `d * 1000 == 0` that answers 1001; with
`d2` at least 16 by then, it cannot be reached. `confirmed`

## 5. The chain: `CUnit::CommandReach` (`0x1B6980`)

The unit in `EAX`, `out` and a level on the stack, `ret 8`:

    if level == unit->oob_level:  1000
    reach = 1000;  lower = unit
    for hq = unit->higher_oob_unit (+0x1E0); hq and hq->oob_level >= level; hq = hq->higher_oob_unit:
        link  = section 4 for (lower, hq), inline
        reach = link * reach / 1000                                    __alldiv
        lower = hq

So each link is measured **from the unit below it**, not from the unit asked about: a division's
reach from its army is the corps' reach of the division times the army's reach of the corps.
Ghidra's C for this function shows `out` written from an uninitialised local and the product
thrown away; the listing (`0x5B6BAB`..`0x5B6BC4`) stores it at `[ebp-8]`, which starts at 1000.
`confirmed`

## 6. `CUnit::IsOutOfRadioRange` (`0x1B6C00`)

`EAX` in, `AL` out, bare `ret`. The same walk as section 5 with **no level to stop at** - up to
the top - answering true at the first link under 1000 (`0x5B6E0A`). A unit with no headquarters
is never out; a unit off the map is out at its first link, since that link is 0. The
`unitstatus_distance` icon and the hierarchy line's broken red picture are both this
(`FINDINGS-unitpanel.md` section 5, `FINDINGS-hierarchy.md` section 4). `confirmed`

## 7. A trait down the chain: `CUnit::CommandEffect` (`0x1D1120`)

`__thiscall (unit, out, kind)`:

    out = 0
    if unit->higher_oob_unit:
        above = CommandEffect(higher_oob_unit, kind)                   recursive
        if above != 0:
            reach = max(CommandReachFrom(unit, higher_oob_unit), 0)
            share = reach * above / 1000
            out  += share * 1000 / 2000                                halved, toward nothing
    if unit->leader (+0x12C)->vslot 8():                               not the null leader
        for each trait of his, each of its effect_count effects:
            if its kind == kind:  out += its value

So **a commander's trait is worth half to the units under him, a quarter to theirs**, each step
also scaled by how much of that link's command reaches. A negative effect halves toward nothing:
-133 becomes -66. The kind numbers are the order the comment at the head of `common/traits.txt`
lists them, `xp_gain` 0 to `terrain_defence` 30 (`FINDINGS-leaderassign.md`). `confirmed`

## 8. The three places this section reads it from

**The organisation ceiling** - `CSubUnit::GetMaxOrganisation` (`0x1AB700`), `0x5AB70A`..`0x5AB783`:

    unit = brigade->unit (+0xB0)
    army = the unit if oob_level 2; its parent if that is 2; its parent's parent if the parent
           is a corps (3) and that is 2; otherwise none
    bonus = army ? CommandReach(unit, army->oob_level) * (army->leader->skill (+0x70) * 1000) / 1000 : 0

`CommandReach` is called with the brigade's **unit** in `EAX` (loaded at `0x5AB70A`, unchanged to
the call at `0x5AB76C`) and the army's level, 2, pushed. `FINDINGS-unitstart.md` section 8 has
`CommandReach(hq, brigade)` and is corrected here. The army's leader is read with no test; a
headquarters with no leader holds the null leader, whose skill is 0 (section 9), so it adds
nothing. `CSubUnit::GetMaxOrganisationWithBonus` adds the bonus only once a game is running and
only for a brigade in a unit (`FINDINGS-unitstart.md` section 8). `confirmed`

**The hourly return** - `CUnit::RegainOrganisation` (`0x1C6A60`), `0x5C6E61`..`0x5C6ED6`: the
same search from the unit and the same `CommandReach(unit, 2) * skill * 1000 / 1000`, worked
out once a unit and handed to each brigade's `CSubUnit::RegainOrganisation` as its bonus.
`confirmed`

**What a unit uses** - `CUnit::SupplyConsumption` (`0x1BB560`) and `CUnit::FuelConsumption`
(`0x1BB7A0`), as `FINDINGS-unitdaily.md` section 2 has them:

    potency = 1000 + the owner's supply_consumption modifier
    group   = the unit, or the first above it, whose oob_level is 1
    if group and unit->current_province:
        potency -= group->leader->skill * 1000 * Define50 / 1000 * CommandReach(unit, 1) / 1000
    potency += CommandEffect(unit, 2)                                  supply_consumption
    if potency < 0:  potency = 0

`Define50` (`0x168879C`) is 50, from the float 50.5: **a twentieth off for each point of the
army group commander's skill**, by its reach. The fuel routine skips the reach where the discount
is nothing, which comes to the same. The floor is tested once, after the trait. `confirmed`

## 9. The null leader's skill is 0

`CLeader::null` (`0x17F510`) builds its leader with `0x57F380`, whose first call, `0x57F580`,
zeroes `ebx` (`0x57F5BF`) and writes it to `+0x70` and `+0x74` (`0x57F695`, `0x57F698`). So a
headquarters with nobody in command has skill 0 and gives no bonus and no discount. `confirmed`

## 10. A new game's stockpile is reckoned before leaders are chosen

`CInGameIdler::Enter` calls `SetUpCountryForNewGame` at `0x65B4F2` and `CUnit::AssignBestLeader`
at `0x65B736`, later in the same guarded stretch (`FINDINGS-leadership.md` section 10,
`FINDINGS-leaderassign.md` section 4). The stockpile's days of supplies and fuel are what the
units use with `withoutLeaders` clear - so with the leaders they have **then**: the order of
battle's `leader = N`, set as the file was read, and nobody the choice gives. Whether the two
sit in one loop over the countries or two does not matter: a country's choice gives only its own
leaders to only its own units. `confirmed`

## 11. Against the start save

Measured by OpenHOI3's `SaveCheck` on `Germany1936_01_01_00.hoi3`, with the rules above built:

| | before | after |
| --- | --- | --- |
| organisation of a brigade under an army with a commander | 142 of 764 | 764 of 764 |
| what a capital's units use, where the save gives one a leader | 17 of 28 | 27 of 28 |
| the same, where the save also has a unit the files do not give | 19 of 35 | 33 of 35 |
| supply networks the same in every province and figure (`supplypass`) | 171 of 234 | 184 of 234 |
| Germany's stockpile of supplies two days in | 3.264 off | 0.030 off |

The dozen brigades whose bonus `FINDINGS-organisation.md` section 7 found fractional, 0.82 to
1.30, are the ones a corps or an army stands far enough from to cut the reach.

## 12. Everything that asks the reach

Every direct call, by `findRefs.py --callers` (added 2026-10-11, after the sections above):

| routine | called from | what for |
| --- | --- | --- |
| `CUnit::CommandReach` | `CSubUnit::GetMaxOrganisation`, `CUnit::RegainOrganisation` | the army commander's skill, level 2 (section 8) |
| | `CUnit::SupplyConsumption`, `CUnit::FuelConsumption`, `CRegiment::SupplyConsumption`, `CRegiment::FuelConsumption` | the army group commander's discount, level 1 |
| | `CUnit::ReinforceChance` | the corps commander's skill in a reserve's chance, level 3 (`FINDINGS-landbattle.md` section 2) |
| `CUnit::CommandReachFrom` | `CUnit::CommandEffect`, `CUnit::TerrainCommandEffect` | each step of a trait coming down the chain |
| | `0x75AE20` | the unit panel; not read |
| | `CAIUnit_PullHeadquartersIn` (`0x8CC320`) | the AI, below |
| `CUnit::IsOutOfRadioRange` | `CUnitStatusEntry::Update`, `0x75AE20`, `HierarchyLines_AddUnit` | display only |

**So no caller asks the reach at level 0**: whatever the theatre commander's skill does, it is
not scaled by how far his command reaches. Nor does a division's own leader's skill go through
any of these. Both are battle and not read here.

**`CUnit::TerrainCommandEffect` (`0x1D0F80`)** is `CUnit::CommandEffect` with a terrain: the
same recursion, the same `max(reach, 0) * above / 1000 * 1000 / 2000` at each step, and of the
unit's own leader's effects only those of the kind whose terrain string (the trait's `type`,
kept beside each value from `+0xF8`) equals the name it is given. `__thiscall (unit, out, kind,
terrain)`, `ret 0xC`. Callers: `CUnit::MovementSpeedModifier` at `0x5C8F07` with kind 28,
`terrain_speed`; `BuildSpeedModifierTooltip` the same; `CLandCombatant::ApplyCombatModifiers`
twice, `terrain_attack` and `terrain_defence`. `confirmed`

**`0x8CC320`**, called once from `CAIUnit::Tick`, `ret 4`: over the agent's units (`+0x14C`),
skipping its own (`+0x64`), one retreating, and one in a battle it may not leave, a unit with
no destination of its own is moved by `CEU3AI::MoveUnit` to the province `0x8DA660` picks for
it where **any unit directly under it is reached by less than all of its command**
(`CommandReachFrom` 999 or under), or where it is flagged at `+0x1A8`, or stands on a front
with the agent's `+0x364` set. So the AI walks a headquarters towards subordinates it has lost
touch with. Read for its shape only; the name is ours. `inferred`

## Not established

- **The Soviet capital's units use 4.101 here against the save's 2.626.** The Comintern's faction
  modifier, `supply_consumption = -0.33`, would bring it close; whether a faction's modifier
  reaches a country's is the open question `FINDINGS-unitdaily.md` already lists.
- **Germany's last 0.030 of supplies** in the stockpile two days in.
- Nothing here was watched in a running game.
