# A fleet's missions: reserve, patrol, intercept, sortie, the raid on convoys and their escort

Read statically out of `hoi3_tfh.exe` on 2026-10-10, for the rewrite's fleet missions.
Addresses are **VAs** unless a line says rva; `rva = VA - 0x400000`. Only valid for this build.
**Nothing here was watched in a running game**, and two results are odd enough that somebody
who can watch the original should: an intercepting fleet that has gone out once does nothing
more (section 6), and a fleet on patrol sinks convoys (section 4).

It builds on `FINDINGS-seaair.md` (the orders window, the three orders that only send a unit
somewhere, the hourly driver), `FINDINGS-seabattle.md` (the battle), `FINDINGS-navaldetection.md`
(`ShouldStartNavalCombat`) and `FINDINGS-convoys.md` (what a convoy is, what a lost one costs),
and **corrects four things** in them - the last section.

**In one page.** A mission is an order object on the fleet. `CSetOrderCommand` starts it (slot
13) and `CUnit::CheckOrderAndCombat` asks it every hour whether it is still going (slot 14); the
asking is where everything a mission does is done. All six share a frame: nothing while the fleet
is in a battle; a fleet of a country a person plays whose ships are too worn for its stance
heads for the nearest harbour; then the mission's own hour. A **patrol** goes to its province
and then round the sea provinces next to it, one an hour it has no path, shadows a foreign fleet
it sights, and every twelve hours tries the convoys of the water it is in. A **convoy raid** is
the same round without the shadowing. An **intercept** waits in its port and goes for the first
enemy fleet it sees in its province or the ones around it that is no stronger than itself. A
**sortie** sails to its province, going for enemy fleets beside its way, and turns for home on
arrival. An **escort** sails up and down the stretch of a convoy's route within its range. A
**reserve** lies in its port, and once a day its sound ships change places with the worn ships
of the fleets beside it. The raid itself is a battle: a throwaway fleet of destroyers and
transport ships is made out of the convoy's counts and five rounds of the ordinary sea battle
are fought against it on the spot.

---

## 1. What every naval order shares

The classes, under `CNavalOrder` (a `COrder`), with the type each answers from slot 16:

    CRebaseOrder 0x6DE, CReserveOrder 0x398, CPatrolOrder 0x42E, CNavalInterceptOrder 0x6E6,
    CNavalSortieOrder 0x6E7, CConvoyEscortOrder 0x6E8, CConvoyRaid 0x6E9,
    CNavalTransportOrder 0x3A8, CNavalInvasionOrder 0x3A5

`CNavalInterceptOrder` uses `CPatrolOrder`'s loader; nothing else is shared between the
missions but the base. The slots that matter, by the vtables:

| slot | | |
| --- | --- | --- |
| 8 | in range | `CNavalOrder::IsInRange` for all (`COrder::IsTargetInRange`) |
| 11 | may it be given | `0x5A0000` for patrol, intercept, sortie and raid; own for reserve and escort |
| 13 | start | each its own |
| 14 | still going, asked every hour | each its own |
| 15 | what the panel says | own for patrol, intercept and escort; `CNavalOrder::Describe` for the rest |
| 18 | | `0x59B160`: `return this->+0x38`, the naval order's own priority |
| 19 | stance | `COrder::GetStance`, `+0x20` |
| 21 | | the shared `true` for every naval order; the base is `false` |
| 23 | once a day | nothing, but for `CReserveOrder` (section 3) |
| 24 | | the shared `true`; what gates slot 23 in `CUnit::UpdateDaily` |

**May it be given**, `0x5A0000`, shared by the four: the unit is in no battle, the order's
province is **not land**, and slot 8 says it is in range.

**`CNavalOrder::IsActive`** (`0x59B070`, already recorded as not made out), read again from the
listing:

    the unit has no base                                                -> false
    the byte +0x34 is set and the unit is in its base's province        -> the byte is cleared, false
    death_date (+0x2C) == start_date (+0x28)                            -> true
    otherwise                                                           -> death_date > the hour

`+0x34` is **`CNavalOrder`'s own `return_to_base`**, the one its loader reads from a save. The
whole of the naval order code (`0x599800`-`0x5A1300`) writes it twice: zero in the constructor
(`0x59A94C`) and zero here (`0x59B0B4`). Nothing in play sets it. So for an order given in a game
this function is **"has it a base, and has its last date not passed"** - and an order from the
orders window carries the constructor's two null dates, equal, so it never ends by date
(`CSetOrderCommand::Execute` copies the command's `+0x74` and `+0x78` into the order's two dates;
the command's other pair, `+0x6C` and `+0x70`, goes to the unit's `+0xCC` and `+0xD0`).

**`COrder::OrderReturnToBase`** (`0x5878C0`, already recorded) sets the *other* byte, `COrder
+0x18`, and gives the unit a plain path to its base's province. **No naval order code ever
clears `+0x18`**: the scan of `0x599800`-`0x5A1300` for a byte write at that displacement finds
the constructor's zero and nothing else, and the one clearing write nearby (`0x58A6C4`) is in
`CAirOrder`'s code. Slot 14 of intercept and reserve, the raid counter of patrol and raid and
the sortie's route plotter all test `+0x18`. So **a naval order that has once been told to
return to base stays that way for as long as the order lives.** What that does to each mission
is in its section. One way out is `inferred`, from the loader and the saver and not from a
game: `COrder::SaveContents` writes `+0x18` as `return_to_base`, `CNavalOrder::SaveContents`
writes `+0x34` under the same key after it, and `CNavalOrder::LoadKey` takes that key for
`+0x34` before `COrder` sees it - so a save and a load would leave `+0x18` clear.

**Too worn to go on** - `0x59A990` (`(order)`, `ret 4`), called first by every mission's slot 14
but the reserve's:

    the fleet's country is played by no person (CCurrentGameState +0xBCC[owner] == 0)  -> false
    limit = 0.25;  stance 0 (aggressive): 0.5;  stance 2 (passive): 0.1
    for each ship:  lost = (GetMaxStrength - strength) * 1000 / GetMaxStrength
                    lost > limit -> worn++,  else fit++
    worn < fit  -> false;   otherwise -> true          (a fleet with no ship: true)

The three limits are the floats 250.5 (`0x160A688`), 500.5 (`0x160A5E8`) and 100.5
(`0x160A684`), floored - **not** the `*_STRENGTH_LIMIT` defines. So **a fleet of the AI's never
breaks off a mission for damage here**, and a player's does when at least as many of its ships
have lost more than a tenth, a quarter or a half of their strength as have not.

**Heading for a harbour** - `0x59AB80` (`(order)`, `ret 4`), what slot 14 calls when the test
says yes, before answering true:

    only for a fleet in no battle, with no path, in a sea province
    of the naval bases (CCountry +NavalBases, a list of provinces) of its country - or, where
    the country's faction's slot 7 says so, of every member of the faction - the one with the
    least CMapProvince::NavalDistanceTo(that base, the fleet's province); the first of equals
    a path there by CSafeNavalPathFind; found -> SetUnitPath(clear)

The base is not changed and the order is kept. In port nothing happens, so **the fleet lies
there under its order until enough of its ships are mended** for the test to say no, and then
its mission's hour runs again from where it lies.

**Going somewhere** - `0x59A700` (the unit in EAX, the province in ECX): nothing where the unit
is there already or `CanMoveTo` (slot 35) says no; otherwise `0x59A640(the unit's province,
safe = 1)`. `0x59A640` (`(from, safe)`, cdecl; the unit in ESI, the goal in EDI) repeats the two
tests, finds a path **from `from`** to the goal - by `CSafeNavalPathFind` where `safe`, by the
plain `CPathFind` otherwise - and calls `SetUnitPath(unit, path, clear)` **whether or not one
was found**.

`CSafeNavalPathFind::StepCost` is already recorded: the plain cost, three times over where a
province next to the one stepped into is held by a country at war with the fleet's and has a
naval base, and three times again where one has an air base.

## 2. `0x59A740` - an enemy fleet in a province worth going for

`(province in ECX, unit, order)`; what intercept and sortie look with.

    the province is land                                                 -> none
    best = none
    for each unit standing in the province, in list order:
        its owner is at war with the order's unit's owner (CDiplomacyStatus +0x20), and
        the unit has a ship, and ShouldStartNavalCombat(unit, that one), and
        that one's GetPower <= the order's unit's GetPower:
            best is none, or that one's ships have more strength in all than best's -> best = it
    -> best

- **It is the sighting of `FINDINGS-navaldetection.md`**, asked with `ours` wherever it is: the
  intelligence level read is that of the province **the asking fleet stands in**. A fleet in its
  own port stands in land its country knows at 9, which is a sighting with no roll - so a fleet
  waiting in port sees every enemy fleet in the provinces it looks at, and one at sea rolls.
- The other gates of the sighting apply: the wait after a battle, the submarines against the
  screens, the patrol's stance.
- Nothing asks whether the unit found is a fleet. In a sea province only an air unit could be
  anything else.

## 3. `CReserveOrder`

**May it be given** (`0x59B520`): the unit is in no battle; the province has a naval base of a
level above nothing (`CMapProvince +0x300`, its `+0x20`); the province's **controller**
(`+0x338`, the id half of the tag) is the unit's owner; and slot 8.

**Start** (`0x59B560`): where the unit's base is not the province, the province's naval base
object (`+0x58`) becomes its base; and where the unit is not in the province,
`OrderReturnToBase`.

**Still going** (`0x59B5E0`): it has a base, `IsActive`, and - `+0x18` is set, or it has no path
and is in the province. So a reserve sent for from elsewhere is kept by the byte that never
clears, and one that was in port is kept while it stays there with no path.

**Once a day** - slot 23, `0x59B630`, which `CUnit::UpdateDaily` calls for every unit whose
order's slot 24 says yes; only this class has a body there:

    only where the fleet is in the order's province
    the units based at the fleet's base (the base object's list), each whose order's slot 24
    says yes and for which COrder::IsTargetInRange(this fleet, the province that unit is in):
        put in one of four lists by its order's slot 18 - the priority, 0 to 3
    for priority 3 down to 0, each unit of that list in order:
        0x59B850(this order, that unit);  this fleet has no ship left -> done

**`0x59B850`** (`(order, other)`, `ret 8`) - the exchange. Only where `other` is a fleet (slot
16), its order's slot 24 says yes, its byte `+0x94` is clear, its owner is this fleet's and
**it is in the same province as this fleet**:

    limit = DEFENSIVE_STRENGTH_LIMIT;  the other's stance 2: PASSIVE_STRENGTH_LIMIT
            (stance 0 reads DEFENSIVE_STRENGTH_LIMIT a second time: the aggressive limit is never read)
    loop:
        worn  = the other's ship with the least strength / default strength, under the limit
                and under 1.000 (the constant at 0x170D710);  none -> done
        sound = this fleet's ship of the same type (definition index) with the most
                strength / default strength, above worn's;  none -> done
        the two ships change fleets

So **a reserve is a pool of sound ships for the fleets that lie in the same port**: each day the
most worn ship of each, under half strength for a defensive stance, is swapped for the reserve's
best of the same type, the highest priority first. A fleet at sea gets nothing: it has to be in
the province.

## 4. `CPatrolOrder`

Its own fields: `+0x48`, a reference to a unit - **the fleet it shadows** - with the object id
at `+0x4C`/`+0x50`; `+0x70`, which neighbour of its province is next on its round; `+0x74`, the
hours to its next try at a convoy. The constructor zeroes both counters, so the first try is in
the first hour.

**Start** (`0x59C4E0`): the hour's move below, and a refresh of the map mode 0x13 where the
fleet is the player's.

**Still going** (`0x59C5F0`):

    no base                                              -> false
    in a battle                                          -> true
    too worn (section 1)                                 -> heads for a harbour, true
    not IsActive                                         -> false
    the move, 0x59CA40
    in no battle, CUnit +0x110 clear, +0x18 clear, not retreating:
        +0x74 down by one;  under 1 -> ResolveConvoyRaid(the fleet), +0x74 = 12
    -> true

**The move** - `0x59CA40` (the order in EDI):

    shadowing nobody:
        near - the fleet is in the order's province or in one with an edge from it (0x59CDA0) -
        and has no path:
            i = +0x70;  n = the edges of the order's province
            i == n:  not in the order's province -> go there (0x59A700);   +0x70 = 0
            i <  n:  +0x70 = i + 1;  q = the province of edge i;
                     q is sea, is `simulated` (CProvinceTemplate), and in range
                     (COrder::IsTargetInRange) -> go there
        otherwise, with no path and not in the order's province, and CanMoveTo says yes:
            a path there by CSafeNavalPathFind, SetUnitPath(clear)
    shadowing a fleet that has a path, whose next province is not this fleet's next province:
        a path to that next province by the plain CPathFind, SetUnitPath(clear)
    then 0x59CE10

So **a patrol visits the sea provinces around its province one after the other, in the order of
the province's edges, coming back to the middle after the last**, taking one step each hour it
finds itself with no path.

**Shadowing** - `0x59CE10` (`(order)`, `ret 4`), every hour after the move:

    the fleet it shadowed, if any: that fleet's byte +0x95 is cleared, the reference emptied
    for each unit in the province the patrol is in, in list order:
        another unit, a fleet, of another country, and slot 8 of the order says in range,
        and its country is not of this one's faction and has no "friendly agreement" with it
        (CDiplomacyStatus::HasFriendlyAgreement), and
        the patrol has a ship and ShouldStartNavalCombat(patrol, it):
            the reference is that fleet;  its byte +0x95 = 1
            a new one, and the patrol is the player's -> the message PATROLTRACK
            -> done

- **No war is asked for.** A patrol shadows any foreign fleet that is not a friend's.
- **`CUnit +0x95` is "shadowed by a patrol"**, and this is its writer. `ShouldStartNavalCombat`
  doubles the figure of every roll made against a fleet that has it.
- The reference is what `UpdateIntelFunctor_SerialBody` looks at: a patrol that shadows somebody
  gives its country level 9 of the sea province (`FINDINGS-seabattle.md`, section 1) - **from the
  next refresh on, and the refresh is daily** (`FINDINGS-schedule.md`: `RunIntelRefresh` at the
  end of `RunDailyPass`, hourly only once a change of who plays a country has asked for it).
- The panel says `ORDER_PATROL_S` with `ACTION` either `PATROL_SHADOW` or `PATROL_SEARCH`
  (`0x59C680`).

**A patrol tries the convoys too.** `ResolveConvoyRaid`'s call at `0x59C66B` is in this
function - `CPatrolOrder`'s slot 14 by the vtable - and not in `CConvoyRaid`'s, where the record
had it. Every twelve hours a patrolling fleet in no battle does exactly what a raider does.

## 5. `CConvoyRaid`

Fields: `+0x48` the neighbour next on its round, `+0x4C` the hours to its next try; both zero
from `CNavalOrder`'s constructor.

**Start** (`0x5A0140`) and **still going** (`0x5A0250`) are the patrol's, line for line, with
the move `0x5A0390` in place of `0x59CA40`:

    near - not at its own base (CUnit_IsAtOwnBase), and in the order's province or one with an
    edge from it (0x5A05C0) - and with no path:
        the patrol's round, with no test of the range
    otherwise, with no path and not in the order's province, and CanMoveTo says yes:
        a path there by CSafeNavalPathFind, SetUnitPath(clear)

No shadowing. And `ShouldStartNavalCombat` answers no for a fleet whose order is a raid, and
`DefenderAcceptsBattle` no for one found under it: **a raider starts no battle between fleets
and is never made the defender of one.** It can still be offered to a battle already being
fought in its province.

## 6. `CNavalInterceptOrder`

One field of its own: `+0x48`, a reference to the fleet it is after.

**Start** (`0x59D9B0`): the unit is not in its base's province -> `OrderReturnToBase`.

**Still going** (`0x59D9E0`):

    no base                                              -> false
    in a battle, or +0x18 set                            -> true, and nothing else
    too worn                                             -> heads for a harbour, true
    not IsActive                                         -> false
    after nobody, and not in its base's province         -> OrderReturnToBase
    the fleet is retreating (CUnit +0x158)               -> the reference emptied, OrderReturnToBase
    after nobody, and in its base's province:
        found = 0x59A740(the order's province);  none: the province of each edge of the order's
                province in turn, the first that gives one
        found -> the reference is that fleet;  go to the province it is in
    in no battle, and after somebody:
        COrder::IsTargetInRange fails                    -> OrderReturnToBase
        the target has a path and this fleet has none    -> go to the target's next province
        otherwise, this fleet has no path and the target is somewhere:
            the target is in a land province             -> OrderReturnToBase, true
            go to the province the target is in
    -> true

So **an interceptor waits in its port, sights by section 2, and chases** - to where the target
is, or where it is going if it is under way. With section 1's byte: **once it has been told to
return to base - because it was ordered while at sea, because its target went into port or out
of range, because it was beaten - slot 14 answers true and does nothing, for good.** The fleet
goes home and lies there under an order whose panel text is `INTERCEPT_RETURN`; it does not go
out again until it is given an order anew (or, `inferred`, the game is saved and loaded). The
panel's other two states are `INTERCEPT_WAITING` and `INTERCEPT_ATTACK` (`0x59DD10`).

A lost target does not by itself send it home: the reference stays while the object lives, and
the branch that orders the return for "after nobody" needs the fleet away from its base.

## 7. `CNavalSortieOrder`

Fields: `+0x48` `start`, the province of the fleet's base when the order was made (or the one
it was in, with no base); `+0x4C` `current`, the waypoint it is making for; `+0x50`/`+0x54`/
`+0x58` a list of provinces, the waypoints, saved as `provinces`; a reference at `+0x60`. The
constructor (`0x59E1C0`) puts **the order's province** in the list, alone. Nothing read adds to
it; the loader does.

**Plotting** - `0x59EB80` (`(order)`, `ret 4`), which is the whole of slot 13:

    +0x18 set -> nothing
    current is none -> the first waypoint
    from = the province the fleet is in
    for each waypoint from `current` on:
        0x59A640(from, safe = it is `current`)  with the waypoint for goal;   from = the waypoint
    the last waypoint has no naval base (level under 1), and the fleet is not in its base's
    province, and CanMoveTo(the base's province):
        a path from `from` to the base's province by the plain CPathFind, SetUnitPath(clear)

**Every call of `SetUnitPath` here clears.** With one waypoint, and the fleet in its base's
province when the order is given, the result is the path out. A fleet that is not in its base's
province is left with the leg **from the waypoint home**, which does not begin where it is.

**Still going** (`0x59E370`):

    no base                                              -> false
    in a battle                                          -> true
    in the last waypoint:
        the FIRST waypoint has no naval base             -> OrderReturnToBase
        -> true
    too worn                                             -> heads for a harbour, true
    not IsActive                                         -> false
    in `current` and in no battle:
        there is a waypoint after it -> that is `current`;  it is the last and has a naval base
        -> CUnit::SetBase(the fleet, that province's naval base object)
    in no battle:
        over the edges of the province the fleet is in, each province that is sea and simulated:
            found = 0x59A740(it)
            best is none, or found's ships have more strength in all (0x5C3120) -> best = found
        best -> a reference to it is made and dropped;  go to the province it is in
    no path, and in a battle -> plot again       (cannot be reached: a battle returned above)
    -> true

So **a sortie sails to its province and turns for home the hour it arrives**, and on the way -
and afterwards, lying in port under the order - **goes for the strongest enemy fleet it sights
in a sea province next to the one it is in** that is no stronger than itself. Having gone for
one it does not take up its way again: the test that would plot it afresh asks for a fleet with
no path that is in a battle, after the function has already answered for every fleet in one.

## 8. `CConvoyEscortOrder`

Fields: `+0x48` the convoy, with its object id at `+0x4C`/`+0x50`; `+0x70` the id of the
province it is making for, -1 at first; `+0x74` and `+0x78` the two ends of its beat; `+0x7C`
which end it is bound for.

**The beat** - `0x59ED80` (`(base province, the convoy's path, range, out first, out last)`,
cdecl), over the provinces of the convoy's path (`CConvoy +0xB0`) from its start:

    in reach - CMapProvince::NavalDistanceTo(base, it) < range - and a sea province:
        last = it;  first is none -> first = it
    otherwise, once there is a first: stop

**the first unbroken stretch of the route that lies within the fleet's range of its base.** The
orders window makes one such order for each convoy of the province that is the player's, or a
lend-lease convoy bound for him (`0x73E452`-`0x73E506`), by a constructor (`0x59EE90`) that
works the beat out at once.

**May it be given** (`0x59F0A0`): there is a first end, the unit is in no battle, and the order's
province is not land.

**Start** (`0x59F0D0`): the convoy is looked up by its id; where its path has more than one
province the beat is worked out and, with a first end, the fleet is given a path there by
`CSafeNavalPathFind` (`SetUnitPath(clear)`, whether or not one was found) and `+0x70` is that
province.

**Still going** (`0x59F440`):

    no base                                              -> false
    in a battle                                          -> true
    the convoy is gone                                   -> the reference emptied, false
    too worn                                             -> heads for a harbour, true
    not IsActive                                         -> false
    an end missing: the beat worked out again;  still missing -> false
    in no battle and in the province +0x70:
        0x59FE50: +0x7C is turned over; a path to the first end where it is now set, to the
        last end where it is now clear (by CSafeNavalPathFind, SetUnitPath(clear)); +0x70 is
        that end
    -> true

The byte starts clear and the start sends the fleet to the first end, so its first arrival there
turns the byte on and "sends" it to the end it is already in; the hour after it turns again and
sets off for the last. From then on it goes up and down.

Nothing in it touches the convoy. `FINDINGS-convoys.md` already has what an escorting fleet is
worth: its mission's efficiency against a raider's in the sighting, and the battle it then
fights like any other fleet.

## 9. The raid itself: `ResolveConvoyRaid`, the part that was not read

`0x5D1250` (`(raider)`, `ret 4`). `FINDINGS-convoys.md` has its head - the raider's attack, the
finding of a convoy at `Random() % 50 < the best surface_detection`, the test against
`CConvoy::GetDefence` - and its tail. Between them, read now from the listing
`0x5D2024`-`0x5D28F0`:

**The fleet the convoy becomes.** A `CNavy` is made, its byte `+0x48` set, given the convoy's
owner, and filled:

    scale      = path_count * 1000 / 5, and 1000 at least            a fifth of the route's length
    escorts    = convoy.escorts * 1000 * 1000 / scale;     above 0 and under 1000 -> 1000
    transports = convoy.transports * 1000 * 1000 / scale;  above 0 and under 1000 -> 1000
    ships      = (escorts + transports) / 1000.0, rounded to the nearest
    the first escorts / 1000 of them (cut) are `destroyer`s      (CSubUnitDataBase +0xA8)
    the rest are `transport_ship`s                               (CSubUnitDataBase +0x88)

Each ship is a new sub unit, `CSubUnit::SetType`, then its technology levels are filled from
the convoy's owner's - **by a loop whose bounds are the destroyer's list of technologies
whichever the ship is**, so a destroyer gets its country's levels and a transport ship, whose
own list lies elsewhere, gets none - then `CSubUnit::ApplyTechnologies`. That settles which of
the two cached definitions is which: `+0xA8` and `+0x88` are the ones the record already names
`destroyer` and `transport_ship`.

**The battle.** With a ship in it the throwaway fleet enters the raider's province
(`CUnit::EnterProvince`); a `CNavalCombat` is made for a fleet, a `CNavalBombing` for an air
unit; **its byte `+0x2B` is set** - this is the writer `FINDINGS-seabattle.md`, section 6, was
missing, and its five reads are those of a convoy battle: `confirmed` now - the raider is added
to the attacking side and the throwaway fleet to the defending (slot 12 of each), and the
battle's slot 13 is called, which is its first hour's setting up. Then

    every ship of both fleets is put at a distance of 1.000 (CSubUnit +0xC8)
    the battle is put on the raider's own list of battles
    five times:  the first three, GrantCombatExperience(raider, true);  the battle's slot 15, Tick
    the battle is taken off the raider's list again

**five rounds of the sea battle, at once, at point-blank.** What the answers of `Tick` are is
not looked at. Inside them (`FINDINGS-seabattle.md`, section 3) the raider shoots with
`convoy_attack`, a ship of the convoy's does an eightieth of its strength damage and twice its
organisation damage, nobody is asked whether they have lost, and the hourly roll to break off
is made from the third round like any other - which can leave the raider's `disengage` count
above nothing.

**The count.**

    for each ship of the throwaway fleet:  lost = GetMaxStrength - strength, summed apart for
        the transports (definition +0x30) and the others
    escortsLost    = lostOthers     * 2000 / 1000 * 1000 / 100000
    transportsLost = lostTransports * 2000 / 1000 * 1000 / 100000;  above 300 and under 1000 -> 1000
    either is 1000 or more:
        the strategic warfare statistic (0x463EC0)
        CConvoy::LoseShips(convoy, round(transportsLost / 1000.0), round(escortsLost / 1000.0),
                           the province, the raider's country)
        s = (transportsLost + escortsLost) * (STRAT_CONVOY_DAMAGE / the victim's convoys) / 1000;
            halved where the convoy had an escort;  added to the victim's series (CCountry +0x1184)
    the province's last_convoy_attack = the hour;   CCombatHistory::RecordCombat;   the battle is
    deleted, the raider's +0x110 put back, and the throwaway fleet removed from the game

A ship of a hundred strength that is sunk counts as **two** of the convoy's; damage to the
transports worth more than 0.3 of a ship counts as one. The 300 is the fixed point at
`0x1A88748`, which a startup initialiser (the store at `0xCC407B`) fills with the float 300.5
(`0x160AAB4`) floored. The rounding is the processor's, to the nearest.

**Who calls it.** Three places: `0x5998EF`, `CAirConvoyRaid`; **`0x59C66B`, `CPatrolOrder`'s
slot 14**; and `0x5A02CD`, `CConvoyRaid`'s.

## 10. Mission efficiency, and the penalty nothing reads

A technology file gives a mission its figures in a block named after it:

    convoy_escort = { efficiency = 0.05 }          convoy_raid = { efficiency = 0.06 }
    sortie = { reduction_modifier = -0.05 }        convoy_raid = { reduction_modifier = -0.50 }

`COrder::GetMissionEfficiency` (already recorded) is the first kind for the order's mission plus
the country modifier made for that mission. Its name is `<mission>_eff`, but a file sets it by
the mission's own name - `convoy_raid = 0.25` (corrected 2026-10-12, `FINDINGS-convoys.md`). It
is not "set by no file of the base game": the base game's `event_modifiers.txt` sets
`air_intercept`, `convoy_raid` and `naval_strike`, and BlackICE sets eight missions' 78 times.
It is read by the
sighting (`FINDINGS-navaldetection.md`: an escort's or a patrol's less a raider's, against a
raider) and by `BM_MISSION_EFFICIENCY`, which puts it on the attack and the defence of every
ship of a fleet whose order is not a plain move (`FINDINGS-combatmods.md`).

`COrder::GetMissionOrgPenalty` reads the second kind and has one caller, `0x5C80C2` in
`CUnit::ShowCombatOver`: the listing shows the figure written to a local at `[esp+0x14]` and
**nothing reading it** before the function ends - the next instruction is the draw for the
fleet's wait. So **`reduction_modifier` does nothing in this build.**

## Corrections to the record

- **`ResolveConvoyRaid`'s callers.** The record and `FINDINGS-convoys.md` give `0x19C66B` and
  `0x1A02CD` (rvas) to `CConvoyRaid`. The first is in `CPatrolOrder`'s slot 14.
- **`CNavalOrder::IsActive`** was recorded as not made out, with "the byte +0x34" unnamed in
  the text. It is the naval order's own `return_to_base`, which nothing sets in play.
- **`CCombat +0x2B`** was `inferred` to be the convoy battle's flag. Its writer is
  `ResolveConvoyRaid` (`0x5D2368`).
- **`CUnit +0x95`** was unnamed. It is set and cleared by a patrol's shadowing alone.
- **`FINDINGS-convoys.md`**: "which of `+0x88` and `+0xA8` is the convoy definition" - neither
  is a definition of its own: they are `transport_ship` and `destroyer`.

## What was not read

- **`CNavalTransportOrder` and `CNavalInvasionOrder`**, and everything about carrying.
- **Slot 20** of an order, `true` for patrol, intercept, raid, escort, transport and invasion
  and `false` for rebase, reserve and sortie: no caller was found.
- **`CUnit +0x94`**, the byte that keeps a fleet out of the reserve's exchange.
- **`CProvinceTemplate`'s `simulated`** beyond its name.
- **`CCountry`'s list of naval bases**: what puts a province on it and in what order.
- **The messages**: `PATROLTRACK`, `CONVOY_TOO_STRONG`, and those of `CConvoy::LoseShips`.
- **`0x463EC0`** and **`0x530600`**, the two statistics calls of the raid.
- **Whether an interceptor really lies idle after its first return.** Read three ways - the
  listing of slot 14, the scan for a write that clears the byte, the air order's code that does
  clear its own - and still worth a look in a running game.
