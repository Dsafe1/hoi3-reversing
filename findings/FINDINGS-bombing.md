# Bombing: the eight missions, the three bombings and what a bomb does

Read statically out of `hoi3_tfh.exe` on 2026-10-10, for the rewrite's bombing. Addresses are
**VAs** unless a line says rva; `rva = VA - 0x400000`. Only valid for this build. **Nothing here
was watched in a running game.**

It builds on `FINDINGS-airbattle.md` (the frame every air order shares, what a country knows
of a province, the hour of grace), `FINDINGS-airnaval.md` (what starts a bombing),
`FINDINGS-airdefence.md` (the bomber's shot, the static anti-aircraft fire, the six compiled-in
factors), `FINDINGS-combatmods.md` section 8 (the two sides' modifiers) and
`FINDINGS-landbattle.md` (the shared hour of a combat), and **corrects four things** in them -
the last section.

**In one page.** A bombing mission is an air order asked every hour whether it is still going,
and that asking is where it flies. Eight of them share two frames. The **strike frame** - ground
attack, interdiction, the naval strike and the raid on convoys from the air - keeps the province
it is flying to from sortie to sortie and picks another only when that one is no longer the
enemy's or it arrived and nothing started. The **bombing frame** - the strategic bombing, the
logistical strike, the runway and the installation strike and the port strike - forgets its
province as soon as a bombing has begun and picks afresh at its base. Either way a unit flies
out, bombs for four hours, and is told to return the hour after. **A bombing is a combat** of
one of three kinds, decided by what is found: the ground itself (4), which needs no unit and
takes only aircraft at their base and - for a port strike - the fleets in the port; land units
(5); or ships (6). Each hour every wing of the bombers fires at one target drawn from a list its
unit's order makes, with the attack figure the order names, and then **bombs the province**:
whole runs of `strategic_attack`, never fewer than one, each taking a die's worth off the
buildings, the stockpile and the day's production that its order names. The other side fires
back: the province's anti-aircraft level and one and a half times every `air_attack` standing
there as one lump of shots, and each ship or each land unit its own `air_attack` beside. Nothing
a target has defends it. At the fourth hour the bombing is over, and bombers worn to nothing
fall back as from an air battle. Bombed buildings come back a little every day, faster on good
roads.

---

## 1. The orders, and what tells them apart

Eight classes over `CAirOrder`, told apart by eleven slots. `xor al,al` and `mov al,1` are the
shared stubs; a blank is the base's no.

| | type | 11 may be given | 13 / 14 frame | 17 bombs here | 20 | 26 | 27 | 28 | 29 | 33 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `CGroundAttackOrder` | `0x6FB` | `0x58DD60` | strike | `0x58E4D0` | yes | | | yes | | yes |
| `CAirInterdictionOrder` | `0x6FC` | `0x58DD60` | strike | `0x58DA60` | yes | | | yes | | |
| `CNavalStrikeOrder` | `0x700` | `0x5924F0` | strike | its province | yes | yes | yes | | yes | |
| `CAirConvoyRaid` | `0x592` | `0x5924F0` | strike, own 14 | no | yes | | | | | |
| `CStrategicBombOrder` | `0x6F9` | `0x58CAD0` | bombing | its province | yes | yes | | | | |
| `CBombLogisiticsOrder` | `0x6FD` | `0x58CAD0` | bombing | its province | yes | yes | | | | |
| `CBombRunwayOrder` | `0x6FE` | `0x58CAD0` | bombing | its province | yes | yes | | | yes | |
| `CBombInstallationOrder` | `0x6FF` | `0x58CAD0` | bombing | its province | yes | yes | | | yes | |
| `CPortStrikeOrder` | `0x701` | `0x591AC0` | bombing, own 14 | its province | yes | yes | yes | | | |
| `CCarrierProtection` | `0x56C` | yes | own 14 | `0x590730` | | | yes | | | |

"Its province" is `COrder::ShouldBombProvince`, `province == this->+0x68`. What each slot is
asked for:

- **26 - bombs the ground.** `StartBombing` makes a kind-4 bombing of a land province the
  enemy holds, with no unit needed.
- **27 - goes for ships.** A fleet may be its target; a fleet in a land province may only be
  fought by a unit whose order says this; the port's fleets are offered to its bombing.
- **28 - goes for land units**, and fires the soft and hard attack split by the target's
  softness.
- **29 - goes for aircraft at their base**, and otherwise fires its hard attack.
- **33 - prefers units that are fighting** (section 5).
- **20** is set on every bombing mission and was not followed to a reader.

**May it be given** (slot 11): ground attack and interdiction, a land province whose controller
is an enemy of the unit's owner (`CCountry::IsEnemy`); the four strategic kinds, that and a
`strategic_attack` above nothing in the unit's own definition; the naval strike and the convoy
raid, a province that is not land; the port strike, one that is.

**May a province be on the mission's list** (slot 37):

    ground attack                 a land province
    interdiction, strategic,      not a land province whose controller is not at war with the
        installation                  unit's owner                                  (0x58B580)
    logistical strike             the same; and not a province with neither supplies nor fuel
                                      lying in it (pool) whose infrastructure's maximum level
                                      is nothing                                    (0x58BF50)
    runway                        the same; and an air base whose maximum level is above nothing
    naval strike                  a sea province that is not landlocked water
    port strike                   a province whose controller is at war with the unit's owner

**What it bombs** (slots 30, 31 and 32, section 6). A building is known by the id of its
modifier: 12 infrastructure, 15 industry, 45 the naval base, 46 the air base, 48 the radar
station, 75 the anti-aircraft guns.

    strategic bombing     buildings 15 and 75; the day's production of crude oil, metal,
                          energy and rare materials
    logistical strike     buildings 12 and 75; the supplies and the fuel lying in the province
    runway                buildings 46 and 75
    installation strike   buildings 48 and 75
    port strike           buildings 45 and 75

So **every mission that bombs buildings bombs the guns too**, and an installation strike is a
strike at radar and nothing else.

## 2. The strike frame: `0x58A930`

Slot 13 (`0x592510`): a unit with a base that is not in its base's province is told to return;
then the hour. Slot 14 (`0x592550`): no base, done; the hour; `CAirOrder::IsActive`.

The hour, `strike` being the order's `+0x68`:

    return_to_base is set                                              -> nothing
    in its base's province and not fit to fly (slot 25)                -> nothing
    in a battle (+0x11C), or in a bombing (+0x110)                     -> nothing
    not fit to fly: OrderReturnToBase                                  (and on)
    no fuel received (CUnit +0x100 == 0)                               -> RETURN
    a path left                                                        -> nothing
    tick > death_date: OrderReturnToBase                               (and on)
    its hours of grace after a bombing (CUnit +0x9C) above nothing     -> RETURN

    no strike - or a strike that is land and no longer an enemy's:
        in its base's province and fit: strike = PickProvince()        (slot 39)
        in its base's province and not fit: OrderReturnToBase
        no strike                                                      -> RETURN
        a sea province                                                 -> nothing more
        a land province that is not an enemy's                         -> RETURN
                                                                       -> nothing more
    not in the strike province (or with no base):
        a way there is looked for and taken where found
        arrive = the hour it will come in (CUnit::NextArrivalHour)
        the mission's time allows that hour's light over the strike province
                (0x4A7320: night or day at a tick, by its hour and month):
            where it is at its own base: order +0x7C = tick + 4        -> nothing more
        otherwise: not in its base's province: OrderReturnToBase
                   in it, with a path: CUnit::CancelMovement           -> nothing more
    in the strike province:
        tick > death_date                                              -> RETURN
        strike = PickProvince(); none                                  -> RETURN
    RETURN: OrderReturnToBase

- **A sortie is a flight out, a bombing and a flight home.** In the strike province
  `CheckForCombat` starts the bombing on arrival; while it lasts the hour does nothing; the
  hour after it ends the hours of grace send the unit home.
- **The strike province is kept.** Home again, `CAirOrder::IsActive` clears `return_to_base`
  and the next hour flies at the same province. Another is picked only where the strike is
  land and has stopped being an enemy's, or where the unit stands in it with no bombing and no
  grace - it arrived and nothing started.
- **Day and night are judged at the hour of arrival**, over the strike province, before the
  unit leaves; and then again every hour by `CAirOrder::IsActive`'s gate, over where it is.
- `+0x7C` is written and was not followed to a reader.

**`CAirConvoyRaid`'s slot 14** (`0x5998C0`) counts `+0x80` down by one each hour and, in the
strike province with the count under one, calls `ResolveConvoyRaid(the unit)` - the fleet's
raid - and sets the count to 12; then the hour and `CAirOrder::IsActive`. Its `PickProvince`
(`0x59A020`) takes, of the mission's provinces other than the one the unit is in, the one
with the highest `1000 + 1000 x the transports` summed over the enemy convoys passing through.

## 3. The bombing frame: `0x58A2E0`

Slot 13 (`0x591B80`) and slot 14 (`0x58C210`) are the strike frame's with this hour.
**`CPortStrikeOrder`'s slot 14** (`0x591BC0`) adds: with no strike province, the order is done
unless some province of the mission passes slot 37.

    return_to_base is set, or in a battle                              -> nothing
    in a bombing: strike = none                                        -> nothing
    not fit to fly: OrderReturnToBase                                  (and on)
    no fuel received: OrderReturnToBase                                -> nothing more
    a path left                                                        -> nothing
    hours of grace above nothing: OrderReturnToBase                    (and on)
    tick > death_date: OrderReturnToBase                               (and on)

    no strike:
        in its base's province and fit: strike = PickProvince()
        in its base's province and not fit: OrderReturnToBase
        no strike: OrderReturnToBase
    a strike, and the unit is in it with a base: OrderReturnToBase
    a strike elsewhere:
        a way there is looked for and taken where found
        the light at the hour of arrival is against the mission's time:
            in its base's province: CUnit::CancelMovement where it has a path
            otherwise: OrderReturnToBase
        otherwise, at its own base: order +0x7C = tick + 4

- **The strike is forgotten the moment a bombing has it**, so every sortie picks afresh.
- A unit standing in its strike province in no bombing is sent home **with the strike kept**,
  and flies at it again from its base.
- Told to return for being unfit or past its date, **the hour runs on** and may still give it
  a way out - the oddity `FINDINGS-airbattle.md` has of air superiority.

## 4. Which province: slot 39

`cur` is the strike province; `next` is the province after it in the mission's list - the
first where there is no strike, the first again after the last, and `cur` itself where `cur`
is not on the list or the list is empty. Each mission goes over the list's provinces that pass
slot 37.

**Ground attack** (`0x58E790`): the hours of grace above nothing, none. Otherwise `next` -
unless `next` is `cur` and some province scored above nothing, and then the best of those. So
with two provinces or more it goes round them in the list's order, and the score only counts
for a list of one. The score (`0x58E5B0`): -10000 for `cur`; -10,000,000 where the wings
already bound for it - every air unit of a country at war with its controller whose order's
slot 24 says yes and whose strike is this province - are above nothing and with the unit's own
more than 3; -20000 where the unit's country knows the province at under 2; otherwise the
strength, summed unit by unit, of the land units there of countries at war with the owner,
**the running sum divided by a hundred each time a unit is not holding ground**
(`CUnit::IsHoldingGround`).

**Interdiction** (`0x58DC70`): the same `next`, and a "best" that is **the last province of
the list scoring above -1000**, whatever came before it - the test is `score > -1000 or score
> best`. It answers the best unless `next` differs from `cur` and the hours of grace are above
nothing. Its score (`0x58DB60`) is ground attack's without the count of wings, the hundredth
taken where a unit **has no path**. So interdiction flies at the last province of its list that
its country knows at 2 or better and that is not the one it has, enemy or no enemy there.

**Naval strike** (`0x592E60`): the same best; it answers `next` unless `next` is `cur` or the
hours of grace are above nothing. Its score (`0x592CC0`): -10000 for `cur`; -10,000,000 by the
count of wings; -20000 unknown; else 1000 a ship for the fleets there of countries at war.

**Strategic bombing** (`0x58B5F0`): the highest of

    industry (province modifier 15) + the day's production of crude oil, metal, energy and
    rare materials, x 1000 / the anti-aircraft level (modifier 75) where that is not nothing

the first found among equals, passing over a province that the wings already bound for it,
with the unit's own, would make more than 3 on.

**Logistical strike** (`0x58C070`): the highest of `the supplies lying there + infrastructure
(modifier 12)`, over the guns the same way. **Runway** (`0x58C9E0`): `1000 x the units based
there`, over the guns. **Installation** (`0x58D280`): the radar level (modifier 48), over the
guns. **Port strike** (`0x5923C0`): `1000 a ship of the fleets there + the naval base
(modifier 45)` where its controller is at war with the owner, nothing otherwise. The first
province always stands until a higher one is found.

## 5. What starts a bombing, and who is in it

`CCombatManager::CheckForCombat` ends, for an air unit whose order's slot 17 says yes of the
province: where the province has a bombing (`+0x2FC`), `JoinBombingInProvince` (`0x430210`);
and where the unit is then in none, `StartBombing`.

**Slot 17.** For six missions the strike province alone. **Ground attack** (`0x58E4D0`) also
any province with units in it that its country knows at 2 or better and where some land unit
of a country at war with it **is holding ground**; **interdiction** (`0x58DA60`) any province
its country knows at 2 or better that has units in it, where it is the strike province or some
land unit of a country at war with it **has a path**. So those two bomb on the way.

**`CCombatManager::StartBombing`** (`0x4302A0`):

    the unit is in a bombing, or its hours of grace are above nothing  -> 0
    a land province, the order's slot 26, and the controller an enemy
        of the unit's owner                                            -> kind 4, no target
    otherwise the first unit of the province, in list order, that is
        an air unit: at its own base, the order's slot 29, and slot 17 of the bomber's province
        a fleet: the order's slot 27
        a land unit: the order's slot 28
        a fleet at sea: the bomber has a wing and ShouldStartNavalCombat(bomber, fleet)
        CUnit::CanEngage(bomber, it, bombing, province) and
        DefenderAcceptsBattle(it, bomber)                              -> kind 6 for a fleet, else 5
    none                                                               -> 0
    the province has no bombing: CCombatManager::CreateCombat(province, kind, bomber, target)
        and for a strategic bombing (0x6F9): BOMBING_THREAT_IMPACT on the owner's threat with
        every country (0x4F4E80), and STRAT_BOMBING_PENALTY dated now on the country of the
        target or of the province's controller (0x5307A0)

- **One bombing to a province.** A second unit joins it or stays out.
- A fleet at sea has to be **sighted** by the bombers as by a fleet, and a fleet's order may
  refuse: a raider or a transport is never bombed, and a patrol only by its stance.
- The last two calls were not read past their arguments.

**`CUnit::CanEngage` with the bombing flag** asks, beyond the war, the two owners and neither
falling back: of two air units, the other at its own base and the bomber's order's slot 29 and
slot 17; and of a land unit that it is not a loaded one going nowhere.

**`CCombatManager::CreateCombat`** for a bombing: a kind 4 puts the province's controller on
the defender's list of countries; the bomber joins the attacker and the target, where there is
one, the defender; then every other unit of the province is offered (`CCombat::AddUnit`) -
**but a land unit only to a kind 5 and a fleet only to a kind 6** - and, where the bomber's
order's slot 27 says yes and the province has an owner, a port and a naval base whose maximum
is above nothing, **every fleet in the port**.

**`CCombat::AddUnit`** gives a unit to the side the other side is hostile to, and for a bombing
refuses the defender's side to an air unit that is not at its own base.
**`CUnitList::AllHostileTo` with the bombing flag** asks of each unit of the list against the
candidate: a war and the rest; where both are air units, the candidate at its own base and the
list unit's order's slots 29 and 17; and where the list unit is a fleet or a land unit, the
candidate an air unit. A side with no unit is hostile to nobody.

- So the defender of a kind 4 is the fleets in port, for a port strike, and - **only where the
  bombers' order goes for aircraft at their base (slot 29)** - the aircraft at their base in the
  province; of a kind 5 the land units; of a kind 6 the fleets; each of the last two with such
  aircraft under the same condition. A port strike has no slot 29: the aircraft in its province
  are in nobody's bombing.
- **A second bomber unit joins only a bombing whose defender has units and no aircraft among
  them**: against a side with nobody on it, or with a wing on it, the defender is not "hostile"
  to it. Two units sent to bomb one city's industry bomb it one after the other.

`JoinBombingInProvince` (the province on the stack, the unit in EDI): not in its hours of
grace nor in a bombing; a land unit only a kind 5 and a fleet only a kind 6; then
`combat->AddUnit(unit)`.

## 6. The bombers' hour: `CBomberCombatant::Attack` (`0x5615C0`)

After the leaders' hours and the practical's gain (`0x565430` with `BOMBING_DOCTRINE_INCREASE`),
for every unit of the side:

    order slot 33 (ground attack): the side's targets = CollectFightingLandTargets
    the side has no target: the side's targets = CollectBombTargets
    for each wing of the unit: CBomberCombatant::FireUnit(side, wing); CSubUnit::BombProvince(wing, side)

The list is made **afresh for every unit**, and each wing draws from its unit's list.

**`CollectFightingLandTargets`** (`0x560600`, the target side in ECX): for each land unit of
the other side that is in a battle, a roll: `Random() % 100 <= t x 100 / 1000`, `t` being the
bomber's owner's `frontline_focus` (`CTechnologyStatus +0xD0`) where the unit is on the front
line of a land battle (the list at `CLandCombatant +0xB0` of either side) and its
`reserve_focus` (`+0xD4`) otherwise. A unit that passes has every brigade whose strength less
its pending damage is not under nothing added, 1024 at most. With both figures at nothing a
unit passes one time in a hundred; a level of either technology is 0.05, five in a hundred
more. **So a ground attack fires at everybody in the province unless a roll has singled out
units that are fighting**, and then at those alone.

**`CollectBombTargets`** (`0x5608A0`): for each unit of the other side -

    an air unit: only under the order's slot 29 and slot 17 of the bomber's province, and
                 only at its own base
    a land unit: only under the order's slot 28
    a fleet:     only under the order's slot 27, or a convoy raid's order (0x592)

- every brigade, wing or ship with strength left is added, 1024 at most; **but a ship, under
any order but the convoy raid's, only by a roll of its own**:

    Random() % 100 <= the bomber's leader's skill x 10 x (1000 + t) / 1000

`t` being the owner's `naval_air_target_chance` (`CTechnologyStatus +0xD8`). A unit with no leader has the game's empty
one, whose skill is nothing, so **a leaderless bomber has a ship on its list one time in a
hundred** and otherwise nothing to fire at.

**`CBomberCombatant::FireUnit`** is `FINDINGS-airdefence.md`'s, with these made out:

    no target on the list                                              -> nothing
    target = targets[Random() % count]                                 one for all the wing's shots
    attack by the wing's unit's order:
        slot 28:  soft = min(the target's softness x (1000 + CommandEffect 15) / 1000, 1000)
                  hard_attack x (1000 - soft) / 1000 + soft_attack x soft / 1000,
                  x (1000 + CommandEffect 19) / 1000
        slot 27, or a convoy raid's: sea_attack x (1000 + CommandEffect 17) / 1000
        slot 29:  hard_attack
        otherwise nothing
    n     = attack x the wing's attack product / 1000
    shots = n / 1000, and one more where Random() % 100 < (n % 1000) x 100 / 1000
    each shot:
        the target's strength less its pending damage under nothing    -> no more shots
        Random()                                                       drawn and not used
        Random() % 100 < min(CHANCE_TO_AVOID_HIT_AT_NO_DEF, 99.0)      -> missed
        org = (Random() % 7 + 3) x 1000
        str = (Random() % 3 + 1) x 1000
        Random() % 100 < 10: str x 10
        a ship with a hull: str x 1000 / hull, org x 1000 / hull
        a brigade: str x (1000 + 10 x the defender's brigades) / 1000 x 0.4 x BOMB_REGIMENT_DAMAGE_MODIFIER
                   org x 0.8 x BOMB_REGIMENT_DAMAGE_MODIFIER
        a ship:    where the wing is a carrier's (is_cag) and the ship's fleet is in a battle:
                       str x CAG_SHIP_ATTACK_STR_BONUS, org x CAG_SHIP_ATTACK_ORG_BONUS
                   str x 0.3 x BOMB_SHIP_DAMAGE_MODIFIER, org x 0.5 x BOMB_SHIP_DAMAGE_MODIFIER
        a wing:    str x 0.5 x BOMB_WING_DAMAGE_MODIFIER, org x 0.7 x BOMB_WING_DAMAGE_MODIFIER
        the target's pending organisation += org; its pending strength += str
        a ship that this leaves with nothing (0x5AB9A0): where the wing is a bomber, or a
            carrier's wing, it goes on the attacker's list of ships sunk, with who sank it
            noted (0x5ABB30) for a bomber and for a carrier's wing whose carrier is in a battle

- **Two draws to a wing** - its target, and the fraction of its shots - **and five to a shot
  that hits**, in that order: the unused one, the avoid roll, the organisation die, the
  strength die, the critical roll. A shot that misses takes two.
- "The defender's brigades" is `CUnitList::GetTotalNumOfRegiments` of the whole defending
  side: one in a hundred more strength damage for each.
- A brigade's and a wing's pending damage is settled at a hundredth, a ship's whole
  (`0x5AB9A0` tests it so).

**`CSubUnit::BombProvince`** (`0x55FF40`, the wing in ECX, the side on the stack), for every
wing of every bombing whatever its kind:

    n    = strategic_attack x (1000 + CommandEffect 16) / 1000 x the wing's attack product / 1000
    runs = max(n, 1000) / 1000                       whole runs; the fraction is dropped
    (s, f) = 7 x SupplyNeed(the province)            a week of what its units ask in supplies and fuel
    infra, most = the current level of the building of modifier 12 and 1000 x its max_level
                  (nothing and 10000 where there is none)
    base = (most - infra) x BOMB_STRATEGIC_RESOURCES_INFRA_FRACTION / 1000
                          x BOMB_STRATEGIC_RESOURCES / 1000
    each run:
        die = (Random() % 3 + 1) x 1000
        for each of the seven goods, in the pool's order:
            order slot 31: take = base x die / 1000
                supplies, where s > 0: take x min(pool x 1000 / s, 1200) / 1000
                fuel, where f > 0:     the same against f
                take = min(take, pool); pool -= take; the side's tally (+0x10C4) += take
            order slot 32: take = min(BOMB_STRATEGIC_PRODUCTION x die / 1000, current_producing)
                current_producing -= take; the side's tally (+0x10D4) += take
        for each kind of building, in the database's order:
            order slot 30: take = damage_factor x (BOMB_STRATEGIC_BUILDINGS x die / 1000) / 1000
                the building's maximum above nothing: take x (current x 1000 / maximum) / 1000
                take = min(take, current); current -= take, not below nothing
                its "changed" byte (+0x28); the side's tally (+0x10B4) += take
    the province's pool and its current_producing are each held between nothing and 99999

- **A wing with no strategic attack still makes one run an hour.** A naval bomber on a port
  strike wears the port down as fast as a strategic bomber with an attack under two.
- **The fuller the stockpile against a week's need, the more is destroyed**, to 1.2 times; a
  province nobody draws on loses the plain figure.
- **A building loses less the more of it is already gone**, by its current share of its
  maximum.
- The order of the pool is supplies, fuel, money, crude oil, metal, energy, rare materials.
- `damage_factor` is 1 unless `buildings.txt` says otherwise (`CBuilding::CBuilding`,
  `0x4B63EF`).

## 7. The other side's hour

All three target combatants first list the bombers' wings with strength left
(`0x563110`, the bombers in EAX), 1024 at most. **`CGroundTargetCombatant::Attack`** is the
static fire alone; the other two do nothing more where there is no wing to fire at, and
otherwise the leaders' hours, the static fire, and then their own.

**`StaticAntiAirTerm`** (`0x562370`), read to its end:

    no wing on the list                                                -> nothing
    guns  = the province's modifier 75 x (1000 + the controller's provincial_aa_efficiency,
                                              CTechnologyStatus +0xA0) / 1000
                                       x STATIC_AA_SCALE / 1000
    units = the air_attack (the unit's own definition) of every unit standing in the province
            whose owner is a friend of the controller (CCountry::IsFriend), and - where the
            province has an owner, a port and a naval base - of every such fleet in the port
    n     = guns + units x 1.5                                         (the 1500 at 0x1A88154)
    shots = n / 1000, and one more where Random() % 100 < (n % 1000) x 100 / 1000
    each shot:
        target = wings[Random() % count]
        Random()                                                       drawn and not used
        Random() % 100 < min(CHANCE_TO_AVOID_HIT_AT_NO_DEF, 99.0)      -> missed
        org = ((Random() & 7) + 3) x 1000
        str = ((Random() & 1) + 1) x 1000
        Random() % 100 < 10: str x 5
        the wing's pending organisation += org; its pending strength += str

So **the units' `air_attack` counts whether or not they are in the bombing** - a land unit in
a province whose industry is bombed fires through this and through nothing else - and a
province with neither guns nor units fires nothing.

**A fleet in port is counted twice.** `CMapProvince::AddUnit` (`FINDINGS-seaair.md`) puts a
fleet that enters a land province on the province's list of units *and* on its `CPort`, and
this sums both lists. That is two readings put together and not one instruction - `inferred` -
but nothing in either list's walk leaves a fleet out. A battle fleet in its base then fires
three times its ships' air attack through the province, where a fleet at sea fires it once,
ship by ship.

**`CNavalTargetCombatant::Attack`** (`0x5631E0`), then for each ship of each fleet of the side:

    n = air_attack x the ship's attack product / 1000; shots as above
    each shot: a wing at random; the unused draw; the avoid roll;
               org = (Random() % 7 + 3) x 1000; str = (Random() % 3 + 1) x 1000;
               Random() % 100 < 10: str x 10

**`CLandTargetCombatant::Attack`** (`0x5637C0`), for each **unit** of the side, not each
brigade:

    n = the unit's own definition's air_attack
          x (CUnit +0xEC x CUnit +0xF4 / 1000) / 1000; shots as above
    each shot: org = (Random() % 9 + 4) x 1000; str = ((Random() & 3) + 2) x 1000;
               Random() % 100 < 10: str x 10

`CUnit +0xEC` and `+0xF4` are the land battle's two products, which
`CCombatant::ApplyCombatModifiers` has just put back to 1000 for every unit of this side, and
the target side's own modifiers go on its brigades (section 8). So **a land unit fires its
plain `air_attack` at the aircraft bombing it**, whatever the hour holds for or against it.
And an aircraft at its base in any bombing fires nothing of its own: only ships and land units
have a loop.

## 8. What the hour makes of each side

Both are `FINDINGS-combatmods.md`'s section 8, read through.

**`CBomberCombatant::ApplyCombatModifiers`** (`0x561680`), on every wing, both halves unless
said:

    difficulty                    GetDifficultyCombatModifier of the unit's country
    naval surprise, attack only   AIR_COMBAT_NAV_SURPRISE_BONUS, where the other side is a naval
                                  target and the combat's `day` is under AIR_COMBAT_NAV_SURPRISE_ROUNDS,
                                  and either this is the first round (`day` < 1) of an attacker
                                  and Random() % 100 < AIR_COMBAT_NAV_SURPRISE_CHANCE, or the
                                  side had it the round before
    air combat                    the sum, over each battle on the unit's own list, of
                                  AIR_COMBAT_ON_BOMBING x (attackers x 1000 / defenders) / 1000,
                                  the two being the strength of every wing of each side of the
                                  list's air battles (kind 3) so far, each at least 1000
    supplies                      -COMBAT_SUPPLY_LACK_IMPACT x (1000 - received) / 1000
                                  x (1000 + CommandEffect 10) / 1000, where it got less than all
    experience                    (experience, PRIDE_BONUS_EXP more for the pride) x 10 / 1000,
                                  x (1000 + CommandEffect 23) / 1000
    mission efficiency            as everywhere, and not under a move order
    radio                         the country's CTechnologyStatus +0xA4
    dissent                       -COMBAT_DISSENT_IMPACT x (dissent x 10 / 1000) / 1000
    stacking                      max(AIR_STACKING_PENALTY x W / 1000, AIR_STACKING_PENALTY_MAX)
                                  where under nothing; W = 1000 a wing, or CAG_STACKING_PENALTY
                                  for a carrier's wing over water
    radar                         RADAR_COMBAT_IMPACT x the highest radar level (modifier 48) of
                                  the province and its neighbours held by a friend of the side's
                                  first country, x (1000 + its CTechnologyStatus +0xC0) / 1000
    weather, attack only          -CWeather::BombCombatEffect
    night, attack only            BASE_NIGHT_PENALTY + the wing's own night figure (attack for
                                  an attacker) + CommandEffect 18, where under nothing
    leader                        COMBAT_LEADER_IMPACT x skill, by the unit's level and rank

- **The stacking counts every wing**, where an air battle's counts all but one.
- There is **no base proximity and no fighter's bonus**, which an air battle has.
- **A bomber in an air battle fires less the stronger its attackers are** against the
  defenders of that battle; with the two equal it is `AIR_COMBAT_ON_BOMBING` once for each
  battle on its list.

**`CTargetCombatant::ApplyCombatModifiers`** (`0x5627D0`), on every brigade, ship and wing of
the side: difficulty; the capital ships' missing screens and the fort, both on the defence
alone; experience; mission efficiency; supplies; radio; dissent; stacking -
`10 x the side's brigades - the country's CTechnologyStatus +0x6C`, where above nothing; night
on the attack alone; the leader. `FINDINGS-airdefence.md` has which half each moves. **Only a
ship's attack product is ever read**, by its own fire; nothing reads a defence.

## 9. The end

The tick is `CAirCombat::Tick`'s: four hours. `CCombat::Tick` settles both sides each hour and
removes ships under a tenth of a point of strength. At the fourth hour it asks `HasLost` of the
attacker - the bombers, by `CCombatant::HasLost` - and then of the defender, **whose slot 16 is
the stub that says no**: a target side never loses. Bombers that have - their wings averaging
under one organisation, or no strength left - are sent back as from an air battle
(`CUnit::RetreatFromCombat`, `FINDINGS-airbattle.md` section 6).

`CCombat::End` empties the province's bombing slot, and for a fleet's bombing it is
`CNavalCombat::End`. The units' hours of grace (`CUnit +0x9C`, set to 2 at the start of each
of their hours in a bombing and taken down by one at its end) then turn the frame for home.

## 10. A carrier's aircraft

`CCarrierProtection` (`0x56C`): slot 11 yes, no slot 13. **Slot 14** (`0x5901F0`): no base,
done; average organisation as a share (slot 20) under `CAG_DUTY_MINIMUM_ORG_LIMIT`,
`OrderReturnToBase`; and where it is in no battle, no bombing and has no path - not in its
base's province, `OrderReturnToBase`; **the order's province becomes its base's province**.
Always still going. **Slot 17** (`0x590730`) is `province == the order's province`, and slot 27
is yes: it bombs ships where its carrier is. Slot 34 is `FINDINGS-airnaval.md`'s.

`CNavy::SendCarrierAircraft` (`FINDINGS-seabattle.md`) sends each such unit to
`CheckForCombat` while its fleet is in a battle, which is how the bombing of kind 6 beside a
sea battle begins: against a fleet the aircraft have to sight like any other, with
`CAG_SHIP_ATTACK_STR_BONUS` and `CAG_SHIP_ATTACK_ORG_BONUS` on every hit while that fleet is in
a battle.

## 11. What comes back each day

`RunDailyProvincePass` (`0x49EAB0`), for a province that is simulated, after the climate:

    roads = infrastructure x (1000 + local + global infrastructure) / 1000   modifiers 12, 13, 14
            held between 10 and 1000
    rate  = (100 + roads) x (1000 + the controller's repair_rate, CTechnologyStatus +0xC4) / 1000
    each of the seven goods: current_producing = min(max_producing, current_producing + rate)
    mend  = BUILDING_REPAIR_SPEED x rate / 1000
    each building whose definition says repair (it does unless the file says no):
        current = min(maximum, current + mend); its "changed" byte
        a whole level gained: the province's modifiers are made again

So a province on full roads gets back 1.1 of each good's production a day and 0.11 of a level
of every building; one with no roads a tenth of that.

**The five technology figures** are named by `fieldmap.py 0x537DB0`, the loader of a
technology's effects: `+0xA0` `provincial_aa_efficiency`, `+0xC4` `repair_rate`, `+0xD0`
`frontline_focus`, `+0xD4` `reserve_focus`, `+0xD8` `naval_air_target_chance`. The same run
names three that `FINDINGS-airbattle.md` section 7 left bare: `+0x3C` `encryption`, `+0x40`
`decryption` and the byte `+0xDC` `listening_station` - so what radar shows of a province is
the looker's decryption against the holder's encryption.

## 12. The march, a bombing and the hours of grace

Found while the rewrite was being built, in `CUnit::AdvanceMovement` (`0x5CA430`):

    an air unit in a bombing (+0x110) that is not retreating          -> it does not move
    ... the speed is added; in a battle the progress is held and nothing more happens ...
    otherwise: no_bombing_hours (+0x9C) = 0; no_battle_hours (+0xA0) = 0
    ... and where the step is completed, before the unit enters the next province:
    in a bombing: CCombat::UnitLeaves(the bombing, the unit); +0x110 = none

- **A bomber stays over its bombing** for the four hours, whatever its order gives it.
- **The hours of grace end with the first move.** They are set to 2 at the start of each of the
  unit's hours in a battle or a bombing and taken down at its end, and *every pass of the
  march of a unit that is in no battle wipes them*. So a bomber told to return the hour after
  its bombing may start another in the next province it enters, and a fighter out of a battle
  may be drawn into one a province on. `FINDINGS-airbattle.md` section 4 had "an air unit out
  of a battle has one hour in which it may move and cannot be fought": it has, **while it stays
  where it is**; and the count is asked only of the unit that starts or joins, never of the one
  found.
- **Whoever leaves a province leaves the bombing of it**: a land unit that walks out, a fleet
  that sails, a bomber that falls back.
- `SetUnitPath` takes a unit out of its bombing only where it is also in a battle
  (`FINDINGS-landbattle.md`, section 7): being given a path does nothing to a bombing alone.

And three technology figures the record had under names of our own are, by
`fieldmap.py 0x537DB0`: `CTechnologyStatus +0x6C` **`unit_cooperation`**, `+0xA4`
**`combat_efficiency`** - the one effect of the `radio` technology beside its `encryption` -
and `+0xC0` **`radar_impact`**.

## Corrections to the record

1. **`CBomberCombatant::FireUnit`'s entry** had "a 10% chance to cut the second by ten". The
   strength die is **multiplied** by ten (`__allmul(str, 10000)` then `/ 1000`), as in an air
   battle.
2. **`StaticAntiAirTerm`** was `likely`, "not read end to end", with its second term unnamed.
   Section 7 has all of it: the second term is one and a half times the `air_attack` of every
   friendly unit in the province and in its port.
3. **`CUnit::CanEngage`** and **`CUnitList::AllHostileTo`** had the bombing flag's arm
   unstated; and `CCombat::AddUnit`'s "global test at 0x5CDC30" is `CUnit_IsAtOwnBase`, asked
   only of an air unit. Section 5.
4. **`CSubUnitDefinition +0x17C`** (`strategic_attack`) was "no reader in any combat function
   ... Unread". Its reader is `CSubUnit::BombProvince`, which is at `0x55FF40` - under the
   range the census took for the combat classes.

## Not read

- `0x4F4E80` and `0x5307A0`, what a strategic bombing does to threat and to the bombed
  country; the strategic warfare tally in `CCombat::Tick`; the message `CBomberCombatant`
  slot 10 builds when a bombing ends.
- The reader of `CAirOrder +0x7C`, and of slot 20.
- `ResolveConvoyRaid` with an air unit for its raider.
- `CNukeMission`, `CParadropMission`, `CTransportSuppliesOrder`, `CRebaseToCarrierMission`.
- Whether flying costs an air unit organisation: nothing read here takes any.
