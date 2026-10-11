# Leaders at sea and in the air

Read on 2026-10-11 for the third piece of OpenHOI3's leaders, its second part: everything a
leader does to a battle at sea, a battle in the air and a bombing. Almost all of it had been read
already, in `FINDINGS-seabattle.md`, `FINDINGS-navaldetection.md`, `FINDINGS-combatmods.md`,
`FINDINGS-airbattle.md` and `FINDINGS-bombing.md`; this gathers it in one place and checks the
points those left open off the instructions.

**Synopsis.** A fleet's, an air unit's or a bombed unit's own leader adds `COMBAT_LEADER_IMPACT`
a point of skill to every ship and wing, behind **the land battle's rank ladder inlined** into
all four modifier passes, with no trait and no `leader_defence`. The same leader's skill, **with
no rank test at all**, draws a fleet's ships up, goes into a ship's or a wing's targeting and
puts ships on a bomber's list; a side's highest ranked leader raises its positioning at sea and
lowers its friendly fire. Eleven trait kinds come in where they name, down the chain of command.
**Two corrections**: `CTechnologyStatus +0x70` and `+0x74`, recorded as named by their use with
"which technology key fills it was not read", are `targeting_chance` and `targeting_choice` -
`FINDINGS-fieldmap.md` and `FINDINGS-uinumbers2.md` had both keys; and an admiral of skill 5 draws
his ships up at half their reach **or one further**, not "exactly" half, because the spread's
floor of 2 survives. **No addresses are new.**

## 1. The leader's bonus, and the rank ladder inlined

`CNavalCombatant::ApplyCombatModifiers` (`0x566480`), `CAirCombatant::ApplyCombatModifiers`
(`0x56C6F0`), `CBomberCombatant::ApplyCombatModifiers` (`0x561680`) and
`CTargetCombatant::ApplyCombatModifiers` (`0x5627D0`) each end with `BM_LEADER_BONUS`. The naval
one, `0x566CAC`..`0x566E18`:

    switch unit->oob_level (+0x1F4), a jump table of 8 at 0x566E48:
        0, 1:  leader->rank (+0x6C) >= 3        2: >= 2        3: >= 1
        4, 7:  pass                             5, 6: unit slot 15 (+0x3C), else
                                                      CLeader::CommandSize(leader) >= unit->regiments (+0x40)
    failing it, or leader->skill (+0x70) <= 0:  nothing
    v = skill * 1000 * COMBAT_LEADER_IMPACT (military +0x84) / 1000
    add(BM_LEADER_BONUS, v, v)

That is `CUnit::LeaderHasRankForCommand` (`0x5CD960`) arm for arm - its own table at `0x5CD9C0`
reads `0x5CD972, 0x5CD981, 0x5CD990, 0x5CD99F, pass, 0x5CD9B2, 0x5CD9B2, pass`, the two `0x5CD9B2`
arms being `CUnit::LeaderCommandsEnough` (`0x5CD920`), which is the slot 15 test and the
`CommandSize` comparison. The other three inline the same: `CLeader::CommandSize` (`0x5800A0`) has
eight direct callers, and four are these - `0x5622B7` (bomber), `0x562F8C` (target), `0x566D3E`
(naval), `0x56D2BD` (air). **No trait and no `MODIFIER_LEADER_DEFENCE`**, as
`FINDINGS-combatmods.md` section 6 had it. `confirmed`

## 2. Drawing a fleet up

`CNavalCombatant::AddUnit` (`0x566F20`), checked at `0x566FCB`..`0x56705C`:

    s = (5 - unit->leader->skill) * 1000;  0x566FEC test esi,esi; jns: under nothing, nothing
    t = CommandEffect(unit, 13 spread_out)
    for each ship:
        half = firing_distance * 1000 / 2000
        f    = max(300 - t, 100)           0x1A881A8 floor(300.5), 0x1A881AC floor(100.5)
        x    = f * half / 1000 * s / 1000 * (1000 - positioning) / 1000,  2000 at least
        d    = half + (Random() % (x / 1000)) * 1000

**The unit's own leader** (`+0x12C`), read straight, with no rank test - and the null leader's
skill of 0 where there is none. **An admiral of skill 5 or more leaves `x` at its floor of 2000**,
so `Random() % 2`: his ships stand at half their reach or one further. `FINDINGS-seabattle.md`
section 2 says "exactly half their reach", which misses the floor. `confirmed`

## 3. A side's positioning

`CNavalCombatant::UpdatePositioning` (`0x566E70`) and the creep at the head of
`CNavalCombatant::Attack` (`0x567930`) both add `CCombatant::GetHighestRankedLeader`'s skill x
100 to the base of 400, where his slot 8 answers yes - so the side's leader, of rank above 0,
first of equals (`FINDINGS-battleleaders.md`, section 1). Already recorded; nothing changes.
`confirmed`

## 4. Who a ship or a wing shoots at

**Friendly fire**, `CSubUnit::PickTarget` (`0x5675D0`), `0x5677D2`..`0x567800`:

    esi = 0x50 - 0x49 = 7
    leader = GetHighestRankedLeader(own side, [ebp+8]);  slot 8 (+0x20) yes: esi -= leader->skill
    Random() % 100 < esi:  a friend

So the side's leader, not the ship's admiral - the record's comment said "the admiral's skill".

**`targeting_chance`**, at the head of the same function (`0x56762A`..`0x56765F`): `p = (the
ship's positioning + the side's) * 100000 / 1000 * (1000 + CTechnologyStatus +0x70) / 1000 / 1000`,
whole - as recorded.

**`CSubUnit::TargetingSkill`** (`0x5AC3C0`): `[edi+0xB0]` (the sub unit's unit) `+0x12C`
(its leader) `+0x70` (skill) x 1000 x `[0x1A8868C]` / 1000, then for a ship (slot 10, `+0x28`)
`+0x74`, for a wing (slot 11, `+0x2C`) `+0xC8` and `+0xCC`, of `CSubUnit::GetOwner`'s technology.
`[0x1A8868C]` is 10, written once at `0xCC370B` from the float 10.5 (`staticconst`). The unit's
own leader, **no rank test**. The leader's part is ten a point raw, the technology's thousandths,
and the pickers take a tenth of the sum as a chance in a hundred. `confirmed`

**The two technology keys.** `FINDINGS-fieldmap.md`'s `CTechStatistics` table, from
`LoadKey` at `0x537DB0`, places `targeting_chance` (token `0x511`) at `+0x70` and
`targeting_choice` (token `0x510`) at `+0x74`; `FINDINGS-uinumbers2.md` section 4 has the
tooltip reading them back as `TARGET_CHANCE_TECH` and `TARGET_CHOICE_TECH`. The record's fields
are `naval_positioning_bonus` and `naval_targeting_bonus`, the second saying "which technology
key fills it was not read". The names are kept, as `FINDINGS-uinumbers2.md` kept its others;
the comments now give the keys. In Their Finest Hour they are 0.05 a level of the naval
doctrines `fire_control_system_training` and `commander_decision_making`.

## 5. A bomber's list of ships

`CCombatant::CollectBombTargets` (`0x5608A0`), `0x5609CD`: `[edi+0x12C]` `+0x70`, with `edi` the
bomber unit - its owner tag `+0x124`/`+0x128` resolves the country whose `+0xD8`
(`naval_air_target_chance`) follows. Its own leader, no rank test, as recorded. `confirmed`

## 6. The traits

Each through `CUnit::CommandEffect` (`0x5D1120`), so down the unit's chain of command
(`FINDINGS-commandreach.md`). The four `kind None` rows the push-scanner left were read by hand:
each is `push 0xA` a few instructions before the call.

| kind | trait | site | use |
| --- | --- | --- | --- |
| 10 | `out_of_supply_modifier` | `0x566AF7` naval, `0x56CE48` air, `0x561CDD` bomber, `0x562C89` target | the supply lack x (1000 + t) / 1000 |
| 23 | `experience_bonus` | `0x566890`, `0x56CA21`, `0x561DFE`, `0x562B23` | the experience x (1000 + t) / 1000 |
| 18 | `night_attack` | `0x566C7C`, `0x56D1FF`, `0x56221A`, `0x562ED2` | added to the night's figure |
| 14 | `spotting_chance` | `0x431D28` ShouldStartNavalCombat | each pair's figure x (1000 + t) / 1000 |
| 13 | `spread_out` | `0x566FE7` | section 2 |
| 11 | `submarine_attack` | `0x567B1C` | `sub_attack` x (1000 + t) / 1000 at a submarine |
| 12 | `disengage_timer` | `0x5C9A6C` WantsToDisengage | below |
| 15 | `defender_softness` | `0x560C0C` | the target's softness x (1000 + t) / 1000, then held to 1000 |
| 19 | `tactical_attack` | `0x560C8E` | the soft and hard blend x (1000 + t) / 1000 |
| 17 | `naval_attack` | `0x560D23` | `sea_attack` x (1000 + t) / 1000 |
| 16 | `strategic_attack` | `0x55FFC3` | `strategic_attack` x (1000 + t) / 1000, before the wing's product |

**`WantsToDisengage`** (`0x5C9A60`): `(1000 + t) * 5000 / 1000`, then the magic-number divide
by 1000 at `0x5C9A97`..`0x5C9AA6` - so **5 x (1 + t) cut to a whole number toward nothing**,
compared with `+0xA8`. A trait of -0.1 still leaves 4.

**Dissent has no trait at sea or in the air**: none of the four passes calls `CommandEffect` near
its `BM_DISSENT`, as `FINDINGS-combatmods.md` section 6 had it for the naval one.

## Not established

- Nothing here was watched in a running game, and no save holds a battle.
- Which of a raid's two sides is the bomber in `CollectBombTargets`' convoy-raid arm (`0x592`)
  was not looked into again; `FINDINGS-bombing.md` section 6 has it as it was read.
