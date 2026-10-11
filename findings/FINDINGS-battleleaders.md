# Leaders in a land battle

Read on 2026-10-11 for the third piece of OpenHOI3's leaders: everything a leader does to a land
battle and to a unit's march. Most of it was already in `FINDINGS-combatmods.md` and
`FINDINGS-landbattle.md`; this gathers it in one place, checks four things off the
instructions that had rested on the decompiler or on a reading of a use, and reads one class
nobody had, `CTraitTrigger`.

**Synopsis.** A unit's leader adds his skill times `COMBAT_LEADER_IMPACT` and his offensive or
defensive traits to its attack and defence, but **only where he has the rank for the unit and
some skill** - so a unit with no leader also gets none of its commanders' offence or defence
traits. Every other trait comes into the modifier it names, down the chain of command
(`FINDINGS-commandreach.md`). The theatre commander's skill takes a hundredth a point off the
stacking penalty, at any distance. A defender's leader's skill goes into the order of its front,
a corps commander's into its divisions' chance of coming up from reserve, a unit's own leader's
into where it shatters, and a side's highest ranked leader picks its tactic. **Two corrections**:
the defender's front order is read off the instructions now and its lost term was `hard_attack`;
and a corps fighting alone counts its own commander in its reserve chance, not only a division
under one. **Two dead traits**: `fort_defence` and `surprise_chance` do nothing in a land battle.

## 1. A side's leader: `CCombatant::GetHighestRankedLeader` (`0x165F20`)

Over the side's units (`+0x40`), each unit's leader whose slot 8 answers yes is kept where his
rank (`+0x6C`) is **strictly** above the best so far, which starts at 0 (`0x565FA0` `cmp ecx,
ebx; jle`). So the first of equal ranks wins, a leader of rank 0 never does, and a side with
none answers the null leader, skill 0. `confirmed`

## 2. The tactic triggers that ask about leaders

`CSkillTrigger` (slot 6, `0xA07250`): the side's leader's skill (`+0x70`) is at least the value,
a whole number (`cmp ecx,[esi+0x40]; setge`). `CSkillAdvantageTrigger` (`0xA06CB0`) the same with
the other side's taken off. Both were recorded; this confirms them. `confirmed`

**`CTraitTrigger::Evaluate`** (slot 6, `0xA07880`, `ret 4`): with a side in the scope (`+0x40`),
the side's highest ranked leader's own trait list (`CLeader +0x30`) is walked for the trait the
trigger holds at its own `+0x40`; true where it is there. **Only the leader's own traits** -
nothing that comes down the chain. Slot 7 (`0xA077C0`) reads the value as a string and resolves
it through a lazily built registry at `0x1A855EC` with `0x5B4E00`, which is taken to be the
lookup of a trait by name - `inferred`, from its use. `confirmed` for the evaluation.

## 3. The leader's bonus, `BM_LEADER_BONUS`

`CLandCombatant::ApplyCombatModifiers`, `0x56AA20`..`0x56AB59`, as `FINDINGS-combatmods.md` has
it, checked off the listing:

    if not CUnit::LeaderHasRankForCommand(unit) or unit->leader->skill <= 0:  nothing
    base = skill * 1000 * COMBAT_LEADER_IMPACT (military +0x84) / 1000
    t    = the battle province's terrain's name (template +0xD4 -> +0xC -> vslot 7)
    attacker: v = CommandEffect(unit, 4 offence_modifier) + TerrainCommandEffect(unit, 29, t) + base
    defender: v = (CommandEffect(unit, 3 defence_modifier) + TerrainCommandEffect(unit, 30, t) + base)
                  * (1000 + owner->modifier[100 leader_defence]) / 1000
    add(BM_LEADER_BONUS, v, v)

- **The gate is on the whole of it.** A unit whose own leader has not the rank, or has a skill of
  nothing, gets no offence, defence or terrain trait at all - neither its leader's nor the ones
  its commanders' chain would bring.
- The owner is `+0x128`'s country, not the expeditionary one the other modifiers take.
- `leader_defence` is the country modifier id 100's key (`MODIFIER_LEADER_DEFENCE`).
- The same figure goes on attack and defence alike.

`confirmed`

## 4. The traits in the other modifiers

Every call of `CUnit::CommandEffect` (`0x1D1120`), with the kind pushed before it - 63, found
with `findRefs.py --callers` and the push before each. Of a land battle's:

| modifier | trait | how |
| --- | --- | --- |
| `BM_RIVER_PENALTY` | 7 `river_attack` | added to the penalty |
| `BM_PARATROOP_PENALTY` | 27 `paradrop_mission` | added |
| `BM_AMPH_PENALTY` | 25 `amph_attack` | added |
| `BM_FORT_MODIFIER` | 8 `fort_attack` | added; 24 `fort_defence` - section 6 |
| `BM_EXPERIENCE` | 23 `experience_bonus` | the figure times one and it |
| `BM_COMBINED_ARMS` | 9 `combined_arms_bonus` | added, in `CUnit::GetCombinedArmsBonus` |
| `BM_DISSENT` | 20 `dissent_impact` | times one and it |
| `BM_LACK_OF_SUPPLIES` | 10 `out_of_supply_modifier` | times one and it |
| `BM_DUGIN_MODIFIER` | 26 `digin_bonus` | times one and it |
| `BM_NIGHT_MODIFIER` | 18 `night_attack` | added |
| `BM_LEADER_BONUS` | 3, 4, 29, 30 | section 3 |
| `BM_ENVELOPMENT_PENALTY` | 22 `envelopment_bonus` | times one and it |
| `BM_ENCIRCLEMENT_PENALTY` | 21 `encirclement_bonus` | times one and it |
| none | 1 `surprise_chance`, at `0x56A330` | read and thrown away (`FINDINGS-combat3.md`) |

Elsewhere: 2 `supply_consumption` in the four consumption routines; 5 `combat_move_speed` in
`CUnit::MovementSpeedModifier` and `CUnit::CheckOrderAndCombat` (section 8); 6 `winter_attrition`
in `GetProvinceAttrition`; 0 `xp_gain` in `GrantCombatExperience`; 12 `disengage_timer` in
`WantsToDisengage`; 13 `spread_out` in `CNavalCombatant::UpdatePositioning`; 11
`submarine_attack` in `CNavalCombatant::Attack`; 14 `spotting_chance` in
`ShouldStartNavalCombat`; 15, 16, 17, 19 in `CBomberCombatant::FireUnit` and `0x55FE90`; 18 and
23 in the naval and air modifiers; and fourteen in the AI's estimate of a battle
(`AICombatEstimateAttackValue`, `AICombatEstimateDefenceValue`). `TerrainCommandEffect` takes 28
`terrain_speed` in the speed and 29 and 30 in section 3. `confirmed` for the sites, each
kind read off its push.

## 5. The theatre commander and crowding

`0x56A8A5`..`0x56A95B`, per unit, after the side's stacking figure is made:

    v = side's figure - owner's technology (+0xDF8 -> +0x6C)
    from the unit itself up higher_oob_unit, the first unit of oob_level 0:
        v -= int(skill + 0.0005) thousandths * Define10 (0x1A881A0) / 1000          skill * 10
    if v > 0:  add(BM_DIVISION_PENALTY, -v, -v)

The walk starts at the unit itself. **No reach and no rank**: the theatre commander takes a
hundredth a point off, wherever he is. `confirmed`

## 6. `fort_defence` does nothing

`CLandCombatant::AddAssaultModifiers` (`0x169750`), where `BM_FORT_MODIFIER` is decided, is called
only from `0x56A347`, behind `cmp byte [ebx+0x38], 0; je` at `0x56A335` - the side's attacker
flag. So its defender's arm, `v = CommandEffect(unit, 24 fort_defence)`, is never reached, and
**a defending leader's `fort_defence` trait has no effect**. `confirmed` for this caller. The
function is slot 27 of `CLandCombatant`, reached through the table, and this is the one call of
it the record has; other calls of slot 27 were not searched for, so "never" is `inferred`.

## 7. The defender's front order: `CompareDefenderFrontOrder` (`0x16C340`)

Off the instructions, `0x56C34D`..`0x56C3D3` for the first unit and the same for the second:

    figure = defensiveness (+0x11C) + hard_attack (+0x138) + skill * 1000 + soft_attack (+0x134) + 1000
    figure = figure * average organisation (slot 20) / 1000
    figure = figure * the sum of the brigades' strength (+0x5C) / 1000

**`FINDINGS-landbattle.md` section 2 had this from the decompiler with two terms lost: they are
`hard_attack` and the order of the additions.** So a defender is ordered as an attacker is, with
defensiveness for toughness and its leader's skill, whole, added - whatever his rank, and 0 with
none. `confirmed`, was `likely`.

## 8. A corps commander and the reserves; a leader and the attack delay and the march

**`CUnit::ReinforceChance`** (`0x1CDA40`), `0x5CDAB4`..`0x5CDB59`:

    corps = the unit itself where its oob_level is 3; its parent where it is a division (4) under a corps
    if corps and (corps's province == unit's, or corps's province template HasEdgeTo the unit's):
        c += corps->leader->skill * 1000 * Define10 / 1000 * CommandReach(unit, corps's level) / 1000

So a **corps in reserve counts its own commander**, which the record's comment left out, and the
edge is asked from the corps' province to the unit's. `confirmed`

**The attack delay** (`CUnit::CheckOrderAndCombat`, `0x5BAA01`) and **a unit's pace in a
battle** (`CUnit::MovementSpeedModifier`, `0x5C8DE1`) both add `CommandEffect(unit, 5
combat_move_speed)` to one and the country's `combat_movement_speed` (`FINDINGS-landbattle.md`
section 6, `FINDINGS-movement.md` section 5). **The march** multiplies by one and
`TerrainCommandEffect(unit, 28 terrain_speed, the next province's terrain)` after the unit's own
terrain adjuster (`0x5C8F07`). `confirmed`

## 9. A unit's own leader and shattering

`CUnit::ShatterThreshold` (`0x1C3140`), as recorded: less 10 thousandths for each point of the
unit's own leader's skill, whatever his rank. Nothing new; listed for completeness.

## Not established

- **The aggressiveness a side's leader picks a tactic with** comes from the stance of an
  active plan on a headquarters above his unit, or an aggression the unit is given
  (`CUnit::GetAggressiveness`, `FINDINGS-combatview.md` section 11); what sets either in play was
  not read.
- Whether `0x5B4E00` is a lookup of a trait by name, and what `CTraitTrigger` holds for a name
  no trait has.
- Nothing here was watched in a running game. `FINDINGS-combat.md` saw a leader's +35.7% on a
  division's tooltip, which the formula of section 3 is consistent with and was not set against.
