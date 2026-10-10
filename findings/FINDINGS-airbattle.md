# The battle in the air: air superiority, the intercept, and the shot

Read statically out of `hoi3_tfh.exe` on 2026-10-10, for the rewrite's battle in the air.
Addresses are **VAs** unless a line says rva; `rva = VA - 0x400000`. Only valid for this build.
**Nothing here was watched in a running game.**

It builds on `FINDINGS-airnaval.md` (what starts an air combat, `CAirOrder::IsFitToFly`, the
four hours), `FINDINGS-seaair.md` (the hourly driver, the range, the rebase),
`FINDINGS-combatmods.md` (the modifiers on a wing), `FINDINGS-airdefence.md` (what the shot
reads) and `FINDINGS-landbattle.md` (the shared hour of a combat), and **corrects four things**
in them - the last section.

**In one page.** An air mission is an order on the air unit, asked every hour whether it is
still going, and the asking is where it flies. Every air order shares one frame: a unit away
from its base when the order is given is sent home first; a mission flown by day turns for home
at night and one flown by night at day; a unit further from its base than its range turns for
home and loses its order; and a unit that has come home under "return to base" either flies
again or, past the order's end date, is done. **Air superiority** goes round the provinces of
its mission one after another and, whenever it stands at its base or has caught what it was
after, picks the strongest enemy air unit it knows of in those provinces and flies to where that
one is going. **The intercept** waits at its base, watches the provinces of its mission and
everything within two steps of them, and flies to meet the strongest enemy air unit that is in
its provinces or will enter one within three steps of its own path; having caught it, it turns
for home. **A battle** starts as any does - the first enemy air unit found in the province -
and a unit in the air can be fought whatever its order: the order only counts for a unit sitting
at its own base. Each hour every wing with an air attack keeps the target it had while that
still exists, or picks a new one - a random enemy wing, or by its targeting skill the one with
the highest priority and the most strength missing - and fires `air_attack x its attack
modifier` shots; a shot that is not avoided does a die of organisation and a die of strength,
and one strength hit in ten is ten times as hard. After four hours a side whose wings average
under one organisation has lost and falls back; otherwise the battle just ends. **An air unit
that has been in a battle cannot be drawn into another for one hour**, which is what lets it
fly away.

---

## 1. The frame every air order shares

`CAirOrder` (vftable `0x15C5EB4`, 40 slots) overrides slots 13, 14, 25, 36, 37 and 38 of
`COrder`. Its nineteen subclasses reach these unless they have their own.

**The day and night gate**, `0x588BC0`, `__cdecl (unit, time, province)`:

    night = IsNight(province, the hour of the day, the month)
    time 0 and it is night, or time 1 and it is day:
        the unit is in its base's province:  CUnit::CancelMovement where it has a path; answer no
        otherwise:                           COrder::OrderReturnToBase(the unit's order); answer no
    otherwise: answer yes

So `time` (`COrder +0x30`) is **0 by day only, 1 by night only, anything else both** - every
order of a 1942 save has 2 (`CLASSES.md`). The province is the one the unit is in.

**Slot 13, `CAirOrder::Start`** (`0x58A790`): a unit with a base that is not in its base's
province is told to return to base. Nothing else.

**Slot 14, `CAirOrder::IsActive`** (`0x58A5E0`):

    the unit has no base                                           -> done
    return_to_base is clear:
        the day and night gate (which may set it)
        still clear, and the unit in no battle (+0x11C) and no bombing (+0x110):
            range (the unit definition's +0x148) < 1000 x CMap::DistanceBetweenProvinces(
                    its base's province, the province it is in):
                OrderReturnToBase                                  -> done
    return_to_base is set:
        the unit is in its base's province:
            return_to_base = 0                                     -> done unless tick <= death_date
        it has no path left (+0x140 < 1) and is in no battle:  OrderReturnToBase again
    -> still going

- **The order outlives its sorties.** Home under "return to base", the byte is cleared and the
  order goes on while the hour is not past `death_date` (`COrder +0x2C`); the mission's own hour
  then sends the unit out again. Past the date the order is done.
- **Out of range ends the order**, with the way home already given. The range is measured from
  the base to where the unit is, and only while it is in no battle.
- A unit told to return that has lost its path is given one again each hour.

**Slot 25, `CAirOrder::IsFitToFly`** (`0x58A090`), is `FINDINGS-airnaval.md`'s, with the two
figures now made out: the strength figure is the sum of the wings' strength x 1000 over
`CUnit` slot 23 (`0x5C6520`, the sum of the wings' definitions' `max_strength`), and the
organisation figure is `CUnit` slot 20's average organisation x 1000 over the unit's own
definition's `max_organisation`. Each has to **reach** the stance's limit.

**The mission's provinces.** `CAirOrder +0x44` is a list of provinces, `provinces` in a save.
`CSetOrderCommand::Execute` (`0x5E1F90`) fills it from the command's own list at `+0x84`
(`objectives` in its loader): for each, where the order's slot 22 says yes (it does for an air
mission), slot 36. **Slot 36, `CAirOrder::AddProvince`** (`0x5899B0`), adds a province not
already listed where slot 37 agrees; slot 37 (`0x589A30`) is a jump to slot 38; **slot 38**
(`0x58A910`) is `COrder::IsTargetInRange(the unit, the province's id)` - in range of the base.

**The area the window draws** is the other maker of that list, and is read here only as far as
the fill. `CAirOrder` keeps a shape at `+0x6C` and three floats, angle `+0x70`, range `+0x74`,
width `+0x78`; the window's three sliders (`range_slider`, `angle_slider`, `width_slider`, in
`CAirOrdersView` slot 2, `0x741DE0`) call `0x589810`, `0x589750` and `0x5898F0` on the order it
is making, the range slider's value times `the unit's range / 1000` and the others times a
constant. Each setter stores its float and, for shape 2 or 3 (range) or shape 3 only (angle,
width), empties the list and calls the fill, `0x589400(order, &range in thousandths, the
order's province)`:

    mark the province seen (CMapProvince +0x37C); where slot 38 agrees, add it to the list
    for each neighbour not seen:
        mark it seen, and remember it on a second list (+0x58) so that the marks can be cleared
        where the unit's slot 35 (CanMoveTo) and the order's slot 38 agree, and
              1000 x DistanceBetweenProvinces(the order's province, the neighbour) <= range:
            shape 3: an angle test (0x588E60, 0x589320), which may stop here
            the same again from the neighbour

So **a mission's area is the provinces joined to its target through provinces the unit can fly
to, within the area's range of it, each within the unit's own range of its base**. What shapes
0 and 1 are, the cone's test, and what the window starts with were not read.

## 2. Air superiority: `CAirPatrol` (`0x6FA`)

Slot 13 (`0x598540`) is the frame's slot 13, then the mission's hour, then a redraw of the
mission's map mode where the unit is the player's. Slot 14 (`0x598680`): no base, done;
otherwise the mission's hour and then the frame's slot 14. Slot 17 is false: it never bombs.
Slot 24 and slot 34 are true.

Its own fields: `+0x68` the province it is flying to (`CAirOrder`'s `strike_province_ptr`),
`+0x80` a reference to its target unit with the target's id at `+0x84`/`+0x88`, `+0xA8` the
province of its round.

**The mission's hour**, `0x599230`, the order in EDI:

    return_to_base is set                                          -> nothing
    not fit to fly (slot 25): OrderReturnToBase                    (and on)
    in a battle, or with a path left                               -> nothing
    no fuel received (CUnit +0x100 == 0): OrderReturnToBase        -> nothing more
    tick > death_date: OrderReturnToBase                           (and on)
    the day and night gate says no                                 -> nothing

    no target:
        at its base and fit to fly: target = PickTarget()          (may be none)
    a target that is in no province of the mission: the target is dropped

    (no destination and no target) or (the unit is at its destination):
        round = destination = the province after the destination in the mission's list
                (0x58DB20, the destination in EAX and the list in ESI: the first when there
                 is none, and the first again after the last)

    a target, in the unit's own province, and the unit has a base:
        tick <= death_date: the gate; target = PickTarget() (or none); destination = none
        otherwise: OrderReturnToBase
        -> nothing more

    no target:
        a destination: the gate; a way there is looked for, and taken where found
    a target:
        the target has a path and its next province is the destination already: as "no target"
        the gate
        the target has a path, and its next province is not where it stands:
            a way to that next province; found: destination = round = it
        otherwise: a way to the province the target is in; found: destination = it

- **It flies to where its target is going, not to where it is**, one province ahead.
- **It picks a new target only at its base or in its target's province.** In between it keeps
  what it has, and drops it only when the target leaves the mission's provinces.
- **With nothing to go for it goes round the mission's provinces in the list's order**, one
  each time it arrives.
- Past its end date, or unfit, it is told to return and **the hour runs on**: it may still be
  given a way to a target in the same hour, which the way home then replaces or not by the
  order of the calls. Read as written.
- **So a unit too worn to fly, sitting at its base, still takes off.** There "return to base"
  only sets the byte; the hour goes on to give it the way to the next province of its round;
  and `CAirOrder::IsActive`, called straight after, finds the byte set and the unit still in
  its base's province and clears it. The hour after, in the air and unfit, it is told to
  return and now has a way home, which stops the hour at "with a path". The rewrite's trial
  shows the round trip repeating every third hour. Nobody has watched the original do it.

**`PickTarget`**, `0x598F70`: over the mission's provinces the unit may stand in (slot 34), over
the units in each: the unit's country knows the province at 2 or better (`CMapProvince +0x370`,
the byte for its country), the unit is an air unit (slot 17), has an order, is another
country's, and that country is at war with the unit's. Each is scored and the highest wins,
the first found among equals; none scores above -10000 by default, so any that is scored at
all is taken.

**The score**, `0x598DC0`: **-10,000,000** - never picked, being under the -10000 the search
starts from - unless the candidate has an order, is **not at its own base**
(`CUnit_IsAtOwnBase`) and is an enemy there (`CCountry::IsEnemy`). Then the wings already
after it are counted: over every country at war with the candidate's, every air unit whose
order's slot 24 is true and is an intercept (`0x718`) or an air superiority (`0x6FA`) with
this candidate for its target. Where that count is above nothing and **the count plus the
unit's own wings is more than 3**, -10,000,000. Otherwise the score is the candidate's total
strength (`UnitSumStrength`).

So **no more than three wings go for one enemy unit, unless one unit brings more by itself**,
and of the rest the strongest is taken.

## 3. The intercept: `CAirInterceptOrder` (`0x718`)

Its own fields: `+0x68` the province it is flying to, `+0x80` a set of provinces it watches (a
list with a hash beside it), `+0x9C` its target as a pointer with the id at `+0xA0`/`+0xA4`,
`+0xC4` the province where it means to meet a target that is on its way in.

**Slot 13** (`0x58EB80`): the frame's slot 13; **the watch set is made** (`0x58F9F0`: every
province of the mission, and by `0x58F860` every neighbour of each and every neighbour of
those - two steps out); `UpdateMission`; the redraw. **Slot 14** is as
`FINDINGS-airnaval.md` has it: no base, done; `UpdateMission`; out of range of its base where
it stands, return to base, the destination forgotten, still going; otherwise the frame's slot 14.

**`UpdateMission`**, `0x58FEB0`:

    a path left, or in a battle                                    -> nothing
    the day and night gate; return_to_base set                     -> nothing
    fuel received, and tick <= death_date, and fit to fly:
        a meeting province, and the unit is in it:
            target = PickTarget() where there is one; GoForTarget
        no target:
            at its base: target = PickTarget() where there is one; GoForTarget   -> nothing more
        a target:
            its province is not in the watch set: the target is dropped,
                    OrderReturnToBase                               -> nothing more
            it is not in the unit's province, or the unit has no base:
                    GoForTarget                                     -> nothing more
    OrderReturnToBase

- **It waits at its base.** Away from it with no target, or with no fuel, unfit or past its
  date, it is told to return.
- **Having caught its target - the two in one province - it is told to return.** The battle
  starts on its arrival (`CheckForCombat`, on entering the province) and a wing in a battle
  does not move, so it flies home when the battle lets it go.

**`PickTarget`**, `0x58F600`: over **the watch set's** provinces the unit may stand in and its
country knows at 2 or better, over the units there that are air units of another country:

    the unit is in a province of the mission:   scored; the best so far: target, no meeting province
    it has a path: the first three provinces of the path, in order, the first that is
        a province of the mission:              scored; the best so far: target, meeting province = it

The score, `0x58F440`, is air superiority's with one test more: a candidate with no wings is
never picked. **Nothing here asks whether the candidate's country is at war with the unit's**
before scoring - the score's own `IsEnemy` test does.

**`GoForTarget`**, `0x58FBE0`, the order in EDI:

    a meeting province the unit is not in: a way there; found: destination = it
    otherwise: the target is looked up by its id; none: nothing
        the target has a path and its next province is the destination already: nothing
        the target has a path, and its next province is not where it stands:
            a way to that next province; found: destination = it
        otherwise: a way to the province the target is in; found: destination = it
    a way found is taken (SetUnitPath)

## 4. What may fight what

`CUnit::CanEngage` (`0x5C01F0`, the unit in EDI, `(other, bombing, province)`), for a battle
that is not a bombing, between two air units - after the tests every arm shares (a war
between the owners, different owners, neither retreating, the same arm):

    this unit is at its own base:
        its order's slot 34 says no           -> no
        its order's slot 25 says no           -> no
    the other is at its own base:
        THIS unit's order's slot 34 says no   -> no
        the OTHER's order's slot 25 says no   -> no

So **the order and the fitness count only at a base**. Two units in the air fight whatever
their orders, bombers and transports among them. A unit at its base is fought only by one
whose order is a fighting one, and - as written - **only while it is itself fit to fly**: a
worn unit sitting at its base cannot be attacked in the air. That last is the reading and not
a guess at intent.

`CCombatManager::StartCombat` asks one thing more of the unit that starts: its order's slot 34
(`FINDINGS-airnaval.md`). So a bomber starts no air battle and can be the defender of one.

**The hour's grace.** `CUnit::CheckOrderAndCombat` begins by writing 2 into `CUnit +0xA0`
where the unit is an air unit in a battle (`0x5BA350`) - and 2 into `+0x9C` where it is in a
bombing (`0x5BA335`) - and ends by taking one off both. `StartCombat` and
`JoinCombatInProvince` refuse a unit whose `+0xA0` is above nothing. A battle is finished at the
end of the hourly pass, after every unit's hour, so its units stand at 1; the look for a new
battle that `CCombat::Finish` makes finds them refused, and so does the look of their own next
hour, which comes after that hour's movement. **An air unit out of a battle has one hour in
which it may move and cannot be fought.** `CUnit::AdvanceMovement` zeroes both counts on one
of its paths (`0x5CA8DE`), which was not followed.

> *Corrected 2026-10-10, the same day, by `FINDINGS-bombing.md` section 12, which followed
> it.* That path is **every pass of the march of a unit that is in no battle**. So the hour
> holds only while the unit stays where it is: its first move wipes both counts, and it may
> start or join a battle in the very next province it enters. And the count is the unit's own
> - it keeps *it* from starting or joining; a unit that finds it is not asked for its.

## 5. The shot: `CAirCombatant::Attack` (`0x56D750`)

After the leaders' hours and the practical's gain (`0x565430` with `AIR_DOCTRINE_INCREASE`),
for every unit of the side and every wing of it in list order:

    air_attack (the wing's definition +0x140) is nothing        -> next wing
    target = PickTarget(the wing); none                          -> next wing
    n      = air_attack x the wing's attack product (+0x50) / 1000
    shots  = n / 1000, and one more where Random() % 100 < (n % 1000) x 100 / 1000
    each shot:
        the target's strength less its pending damage is under nothing   -> no more shots
        Random()                                    drawn and not used
        Random() % 100 < min(CHANCE_TO_AVOID_HIT_AT_NO_DEF, 99.0)        -> missed
        org = (Random() % AIR_COMBAT_ORG_DICE_SIZE + 1) x AIR_COMBAT_ORG_DAMAGE_MODIFIER
        str = (Random() % AIR_COMBAT_STR_DICE_SIZE + 1)
        Random() % 100 < AIR_COMBAT_CRITICAL_HIT_DAMAGE_CHANCE: str x AIR_COMBAT_CRITICAL_HIT_DAMAGE_MUL
        str = str x AIR_COMBAT_STR_DAMAGE_MODIFIER
        the target is a carrier's air group (definition +0x32): str x AIR_COMBAT_CAG_STR_DAMAGE_MOD,
                                                              org x AIR_COMBAT_CAG_ORG_DAMAGE_MOD
        the target's pending organisation (+0xAC) += org; its pending strength (+0xA8) += str

- **Five draws to a shot that hits, two to one that misses**, in that order: one unused, the
  avoid roll, the organisation die, the strength die, the critical roll.
- The "less its pending damage" of the first test is the pending strength over a hundred for
  a wing, as it will be settled (`CSubUnit::SettleDamage`).
- **A critical hit multiplies the strength only.**
- Nothing of the target but its definition's `is_cag` comes into it: no air defence, no
  experience, no modifier of its own. `FINDINGS-airdefence.md` said so of the defence, and
  asked for somebody who knows the game: **the maintainer, told on 2026-10-10 that a wing's
  defence and `air_defence` do nothing in an air battle: "Yes thats a bug in the original."**
  That is his knowledge of the game and not a watched run.
- With the base game's defines a wing of interceptors, air attack 4, fires four shots an
  hour; 52 in a hundred hit (48 avoided); a hit takes 0.125 to 1.125 organisation and 0.1 to
  0.4 strength once settled, a critical one 1 to 4 strength.

**The target**, `0x56D620`, the wing in EAX: a wing keeps the target it remembers (`CSubUnit
+0xB8`/`+0xBC`) while that object still exists. Otherwise:

    the other side's wings are collected (CAirCombatant::CollectTargets, 0x56D430): every wing
        whose strength less its pending damage is not under nothing, 1024 at most, in the
        order of the other side's units and of each unit's wings
    skill = CSubUnit::TargetingSkill(the wing)       thousandths
    roll  = Random() % 100
    skill / 10 < roll:   none collected -> no target;  else targets[Random() % count]
    otherwise:           none collected -> no target;  else the best

`TargetingSkill` (`0x5AC3C0`) for a wing is ten times its unit's leader's skill plus the
owner's `bomber_targeting` and `fighter_targeting` (`CTechnologyStatus +0xC8`, `+0xCC`) **added
together**, whichever the wing or its target is.

**The best**, `0x56D500`, over the collected wings, the highest of

    priority x (250 + (max strength - strength) x 10 / 1000) x (1000 + targeting) / 1000

where `priority` is the target's definition's (`+0x194`), strength in thousandths, and
`targeting` is the firing wing's country's `bomber_targeting` where the target's definition
has `+0x37` set and its `fighter_targeting` otherwise. The first found among equals; one that
scores nothing is never the best, so a list whose wings all have priority 0 gives no target.
`CSubUnitDefinition +0x37` is `isBomber` in the record, the `is_bomber` key: it picks the
bomber's technology here, and is what keeps a wing from the intercept's bonus in
`CAirCombatant::ApplyCombatModifiers`, which `FINDINGS-combatmods.md` left unnamed.

`CAirCombatant` slot 12 (`0x56D3E0`) is the base's `AddUnit` and a count of the wings by type.

## 6. The end, and the loser

The four hours and the tests are `FINDINGS-airnaval.md`'s and `FINDINGS-landbattle.md`'s:
`CCombat::Tick` asks `HasLost` of the attacker and then of the defender from the fourth hour,
and `CAirCombat::Tick` ends the battle at the fourth hour whatever they answer. So an air
battle is four rounds; in the fourth a side may be found to have lost - its wings averaging
under 1 of organisation, or under 0.010 of strength in all - and is then sent back.

**Where a beaten air unit goes**, `CUnit::FindRetreatProvince` (`0x5C5D50`), the arm for a
unit that is neither land nor fleet: over the neighbours of its province that it may stand
in, a crossing an enemy closes notwithstanding -

    a sea province:   1000, and 2000 more for each land province beside it with a naval base
                      that the unit may stand in
    a land province:  where CAir::CanRetreatToProvince (slot 19, 0x5D0B30: no enemy air
                      strength there, EnemyAirStrengthIn) - nothing, which is never enough

and the highest above the floor is taken. **So a beaten air unit beside the sea flies out to
sea**, to the water with the most ports, and only one with no sea beside it goes where the
last lines send it: **its base's province**. `CUnit::RetreatFromCombat` (`0x565760`) then: a
unit not in the battle's own province stays where it is; one with nowhere to go, or no way
there, **is removed from the game**; otherwise it is given the way, its two dates are cleared
and `retreat` is set - without the land unit's order, progress or `disengage`.

`CUnit::ShowCombatOver` does nothing to an air unit beyond its picture: there is no wait like
a fleet's.

**Sent home empty.** `CUnit::CheckOrderAndCombat`'s fourth step (`FINDINGS-seaair.md`) reads
`CUnit` slot 26 (`0x5C7010`): the average over the wings of `organisation x 1000 / its most`.
An air unit away from its base whose figure is under the floor - no organisation at all - is
given a plain move to its base in place of its order.

## 7. How well a country knows a province

Both missions pick their targets only in provinces their country knows at 2 or better, so
`UpdateIntelFunctor_SerialBody` (`0x6883B0`) was read to its end; `FINDINGS-seabattle.md`,
section 1, had the part about a unit at sea. `ClearIntelFunctor_SerialBody` first sets every
country's byte in every province to 0 - or to 9 where the global at `0x170AD30` is clear, which
is the game with no fog of war. Then, for each province with `+0x13D` of its template set:

    the controller (+0x334)                                         9
    every country on the controller's list of allies and
        faction members (CCountry `allied_or_faction_countries`)   9
    the underground's owner (+0x38C), where there is one, and
        every country on its list                                   9
    for each unit standing there:
        each entry of the unit's own list at CUnit +0x2A8 (twelve
            bytes: a country, a count, a level) whose count is
            above nothing: that country                             at least its level, 9 at most
        the unit's owner, where it is not the controller:
            a land province                                         9
            a sea province with a battle of kind 1 on it            9
            a sea province, the unit a patrol (0x42E) shadowing     9
            a sea province otherwise                                at least 2
    radar: for each country that exists and has the radar flag
        (CTechnologyStatus +0xDC), where it knows the province
        at less than `near`:
            d    = its CTechnologyStatus +0x40 - the controller's +0x3C
            step = -1 where d < 0; 0 where d = 0; else max(1, d x [0x1A89770] / 1000 / 1000)
            m    = its modifier's +0x340 over a land province, +0x338 over sea, in whole units
            near = step + 2 + m,  far = step + 1 + m,   each held to 0 .. 8
            for each of its radar stations (CCountry +0x1148) whose province has a
                radar level (modifier 48) above nothing:
                reach = level x (the functor's +8 x 0x4A76A0()) / 1000
                within [0x170DF64] x reach of the station:  near, for it and its list
                within [0x170DF60] x reach:                 far,  for it and its list
                (distances as sixteen times the squared pixels, the short way round the map)

The second number written, `CProvinceTemplate +0x278` with the byte at `+0x13C`, is the same
figure for **the country looking at the screen** and its friends - what the map draws by.

- **A country knows the ground it or a friend holds, the ground its units stand on, the water
  its units are in, and what its radar reaches. Nothing else.** In particular not ground it
  owns that an enemy holds, and not a neighbour's.
- So an air superiority mission over an enemy's ground finds a target to chase only where its
  country already has a unit or a radar's reach; and an intercept over its own ground always
  does. A battle needs none of this: it starts on entering the province.
- The two technology figures at `+0x3C` and `+0x40`, the two globals of the rings and the
  define behind `0x4A76A0` were not named; nor what fills a unit's list at `+0x2A8`.

`RunIntelRefresh` runs this once a day, and hourly once asked (`FINDINGS-navalmissions.md`,
section 9).

## Corrections to the record

1. **`CUnit::CanEngage`'s air arm.** The record had "an air-to-air combat needs both orders to
   be `air_intercept`/`air_superiority` (or carrier protection) and both wings to pass
   `CAirOrder::IsFitToFly`". The four calls are there, but each pair is behind
   `CUnit_IsAtOwnBase`, and the second pair asks slot 34 of **this** unit's order and slot 25
   of the **other's**. Section 4. This also answers `FINDINGS-combatmods.md`'s question of how
   a bomber comes to be in a kind-3 combat: it is in the air.
2. **`CAirCombat::Tick`'s entry** still said it "calls slots 15, 17 and 18 through the vftable
   and never 0x4C ... so no air unit gets a combat modifier list". `FINDINGS-airnaval.md`
   corrected the prose on 2026-10-04 and the entry was left; it is brought in line here.
3. **`CAirCombatant::CollectTargets`** was `inferred` with its filter unstated: the filter is
   strength less pending damage, and it is `confirmed`.
4. **`CSubUnit::TargetingSkill`**'s "`+0xC8` and `+0xCC` together for a wing" is right and is
   now said plainly: the two are added. And `CAirInterceptOrder::UpdateMission`'s entry said it
   "sends the wing home once it is past" its `death_date`; it does, and so do no fuel, being
   unfit, having no target away from base and having caught its target.
5. **`UpdateIntelFunctor_SerialBody`** was "read only to 0x688480; what it writes back into a
   province's intel array at +0x370 is not established". Section 7 has all of it. And the
   record's note on `CMapProvince +0x370`, "0 unseen, 3 partial, 9 own", is short: every level
   from 0 to 9 can be written.

## Not read

- The window's part in a mission's area: shapes 0 and 1, the cone's angle test (`0x588E60`,
  `0x589320`), the three sliders' ranges and what the window starts with; the day, night,
  both and continuous boxes and the two dates, and which fields they fill.
- `CAir` slots 25, 36 and 37; `CAirCombat` slots 13 and 14.
- The path in `CUnit::AdvanceMovement` that zeroes `+0x9C` and `+0xA0`.
- `CCarrierProtection`, and a carrier's aircraft in a sea battle.
- The three bombings, anti-aircraft fire, and every other air order.
- Whether an air unit loses organisation by flying: nothing read here takes any.
