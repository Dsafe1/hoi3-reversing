# What a battle gives: experience and gainable traits

Read on 2026-10-11 for the third piece of OpenHOI3's leaders, its last part. `FINDINGS-leaders.md`
sections 1 and 2 had the shape of both mechanics; this reads what it left open - the enemy term of
the experience, the ships that are skipped, how the gainable-trait database is keyed, and the
bodies of the combat triggers `common/gainable_traits.txt` uses - and follows the convoy raid's
battle to its end.

**Synopsis.** `GrantCombatExperience`'s enemy term is **the other side's average organisation
times its count of sub units**, summed over the unit's combats and, for a unit that is not land,
its current combat (a bombing); the side is found by the unit's owner in the side's country list
at `+0x54`. A ship gains only while it has a target. `LoadGainableTraits` files a trait once for
each leader type its `allowed_leader` flags permit, in file order. Of the triggers:
`is_winner = yes` holds once the combat has ended and the side **has not** lost, so a broken-off
battle is won by both; `has_combined_arms` **never reads its own value**; `terrain` compares the
province's terrain name; `has_combat_modifier` reads the side's per-hour flag. **The convoy raid
never ends its battle through `CCombat::End`**, so `CTraitGainTracker::Update` never runs for it -
`seawolf`, which wants `is_convoy`, is not earnable by raiding (`inferred`; see section 4). **Two
addresses are new** (the two trigger bodies); four records are revised.

## 1. The experience of an hour

`GrantCombatExperience` (`0x5C4200`) is called from `CUnit::CheckOrderAndCombat` (`0x5BA555`) for
a unit with `combats.count (+0x11C) > 0` or `current_combat (+0x110)` - every hour, in the unit's
own pass, after its order and the air unit's look home, before the land path's
`CheckForCombat` - and from `ResolveConvoyRaid` (below).

**The enemy term**, `0x5C422E`..`0x5C440A`:

    A = 0
    for each combat c in unit->combats (+0x114):
        c->attacker (+0x10)->countries (+0x54) holds unit->owner (+0x128):  side = c->defender
        else c->defender's does:                                             side = c->attacker
        else: nothing
        A += (SumOf(+0x40) over side's units << 15) * (CUnitList::AverageOrganisation(side) << 30 / 0x1F40000) >> 15
    current = unit->+0x110;  current and not IsLand (slot 15):  the same against it

`+0x54` is the list `CCombatant::RemoveUnit` rebuilds from the units left - the countries still in
the fight. `CUnitList::AverageOrganisation` (`0x5D6710`) is `sum(count * 1000 * avg / 1000) * 1000
/ (total count * 1000)`, each unit's own average (slot 20, `+0x50`) weighted by its sub unit count
(`+0x40`). `confirmed`

**Then**, as `FINDINGS-leaders.md` has it, with the constant pinned: `b = 328` (the double 328.18 at
`0x120A7B8`, truncated by `0xC088A6`), so the "0.01" is 328/32768. `(A * b) >> 15`, zero returns
before the die; `/ 4`; held to `0..0x60000`; `/ 3` plus `Random() % 6 + 1`; times the kind's
`EXP_GAIN_*`, `1 + xp_gain`, and the convoy modifier; then `* b` **with no shift**, and both shares
take `>> 15` of that. The sub units' share is `((v >> 15) * 0x1F40000 >> 30) * EXP_GAIN_DIV / 1000`,
thousandths. `confirmed`

**The sub units**, `0x5C4657`..`0x5C4671`: `if (slot 10 () == 0 || regiment->+0xC0)` - slot 10 is
the ship test (`CSubUnit::TargetingSkill` takes the naval branch on it), `+0xC0` the byte
`PickTarget` sets with a remembered target - so **a ship gains nothing in an hour it has no
target**; every brigade and wing gains, to `100000` at most. `confirmed`

**The chain**: from `unit->+0x1E0` up while `IsLand` of the headquarters equals the unit's, the
share divided at each step by the headquarters' `Children` count (`+0x1EC`) held to `2..5` - the
division made whether or not that headquarters has a leader. `confirmed`

## 2. The database

`LoadGainableTraits` (`0x473C70`): after `CGainableTrait::LoadKey` reads a block, the loop that
ends `cmp eax, 3` at `0x473EFC` runs `t = 0..2` and, where the trait's byte `+0x2B0 + t` is set
(`0x473E0B`)
- `allowed_land`, `allowed_sea`, `allowed_air` - appends the gainable trait to the per-type vector
(the tracker's prefill) and to `db[combat token][t]` (`0x474820`, `0x474970`). In file order, so
`CTraitGainTracker::Update` walks a trait's candidates in the order the file declares them.
`confirmed`

## 3. The triggers

All read `scope->+0x40`, the combatant; `CTraitGainTracker::Update` makes its scope with
`CEventScope(0, side)` and puts the leader at `+0x44`.

| key | class, slot 6 | body |
| --- | --- | --- |
| `is_winner` | `CCombatIsWinnerTrigger` `0xA07F90` | `combat (+0x3C)->+0x2A` set, then `slot 16 (HasLost)`; `test al,al; sete cl; cmp ecx, value` - **true where the side has not lost**, so both sides of a battle nobody lost |
| `is_convoy` | `CCombatIsConvoyTrigger` `0xA07F70` | `combat->+0x2B == value` |
| `has_combat_modifier` | `CCombatModifierTrigger` `0xA07E80` | id 0..0x1D whose `CombatModifierKey` matches the string exactly, then `combatant->+0x08 + id`; the flags are zeroed at the top of every `ApplyCombatModifiers` |
| `province_temperature` | `CCombatTemperatureTrigger` `0xA07E50` | `province->+0x7C < value * 1000` |
| `has_combined_arms` | `CHasCombinedArmsBonus` `0xA07D60` | **new.** `combatant` slot 6 (`IsLand`: `0xA92590` on `CLandCombatant` alone) true; then each unit of `+0x40` whose leader (`+0x12C`) is the scope's `+0x44` - any unit where that is null - with `base_ca_bonus (+0x1CC) > 0`. **The trigger's own value is never read** |
| `terrain` | `CCombatTerrainTrigger` `0xA07DC0` | **new.** `combat->province (+0x18)->+0xD4->+0xC` slot 7, the terrain's name, into a string, compared with the trigger's at `+0x40` (`0x4173C0`) |

`is_attacker` (`CIsAttackerTrigger`, `0xA063E0`) was recorded.

## 4. The convoy raid's battle

`ResolveConvoyRaid` (`0x5D1250`) appends the throwaway battle to the raider's `combats`
(`0x5D23DF`..`0x5D242F`), then `for i in 0..4: i < 3 -> GrantCombatExperience(raider, 1); combat
slot 15` (`0x5D2431`..`0x5D2458`), then takes the node off the raider's list itself with
`CList_RemoveNode` (`0x5D2476`), and at the end `CCombatHistory::RecordCombat` (`0x5D2904`), the
combat's slot 0 with a zero flag (`0x5D2910`, its destructor), and `CGameState::RemoveUnit` of the
throwaway fleet (`0x5D29D7`). **No call of `CCombat::End`** (`0x57AB00`, whose only callers are
`0x57B8F3` in `CNavalCombat::End` and `0x57BD53`, the air combat's slot 14) and none of
`CCombatant::DetachAllUnits`. `CTraitGainTracker::Update` has two callers, `0x565348` in
`CCombatant::RemoveUnit` (slot 13) and `0x565CFC` in `DetachAllUnits`; slot 13 is reached only
virtually, and the throwaway fleet's removal would run it for the **defender's** side, not the
raider's. So the hours the raider's leader banks in the five rounds are counted at his next
`Update`, against whatever battle that is. `inferred`: the destructor at `0x56DEF0`'s two virtual
calls were not followed to rule out a slot 13 call on the attacker.

## Not established

- Whether the raid battle's destructor reaches `CCombatant::RemoveUnit` for the raider.
- Nothing here was watched in a running game, and no save holds a battle.
