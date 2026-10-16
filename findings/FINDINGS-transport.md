# Transport: carrying land units by sea and by air, the landing, and the carrier

**The transport wave, 2026-10-15**, read for OpenHOI3 (`WAVE.md`, "the transport wave"). Four sections, one per
reader: **A** carrying by sea - boarding, capacity, getting off, a carried unit at sea, the transport mission; **B**
the landing - the invasion mission, a land unit landing from the sea, the invasion's progress and its battle; **C**
carrying on screen; **D** the carrier as an air base and carrying by air - the paradrop and the air supply. The AI's
side (`FINDINGS-invasion.md`, `FINDINGS-theatre2.md`, `FINDINGS-aitheatre.md`, `FINDINGS-aiplans.md`) is not read
here.

Addresses are VAs with rvas beside named functions; the record (`ghidra/project.json`) holds the rvas. Their Finest
Hour's values are given for each define, all mod-able in `common/defines.lua`; everything not a define is compiled in.

## A. Carrying by sea

A passenger is a land unit (`CArmy`) on a fleet's `carrying` list (`CNavy +0x2E4`; a `CList` whose last member,
`+0x2F0`, is the no-unlink lock). The passenger's own `carried_by` (`CArmy +0x300`) names the fleet. **A passenger is
tied to the fleet, never to a ship.**

### A.1 Boarding

There are two ways aboard.

**By command.** `CLoadArmyCommand` (type `load_unit`, 0x518) carries both ends: `unit` at `+0x3C` and `navy` at
`+0x64`. It is saved, loaded and constructed with both - `CLoadArmyCommand(this, unit, navy)` at VA 0x5E3A20 (rva
0x1E3A20) - so **the fleet is whatever the poster names**. The unit panel's load button (handler 0x75E0B0) gets its
fleet from 0x75E510, which takes the first fleet in the port that `CanCarry` accepts (section C). The other posters are
0x66ABB4 (the multi-unit panel, in 0x66AB50) and two AI sites, 0x8A0F46 (in 0x8A0BD3) and 0x8D420A (in 0x8D4070).

`IsValid` (slot 14, VA 0x5E4090, rva 0x1E4090) is asked at post and again before execute. It is false if either end no
longer exists, and otherwise is `CNavy::CanCarry(fleet, unit)` (VA 0x5CEFB0, rva 0x1CEFB0):

    fleet.owner == unit.owner
    fleet in no battle, not moving (path count +0x140 <= 0), not retreating
    unit.definition.transport_weight / 1000 + SumTransportWeight(fleet.carrying) <= fleet.definition.transport_capability / 1000

`Execute` (slot 6, VA 0x5E3AD0, rva 0x1E3AD0):

    if unit is land and unit.carried_by == null:
        CNavy::AddCarried(fleet, unit)        # the call at 0x5E3B96; the slot-11 call at 0x5E3B94 is fleet->AsNavy
        CUnit::EnterProvince(unit, unit's own province)
        selection: if the unit was selected -> clear the selection, select the fleet (unless already selected);
                   else if the fleet was selected -> reselect it
        unit.order = the null order (CreateOrder 0x18D)

**Nothing checks that the unit stands where the fleet is, or in a port.** Execute does not move the unit. Boarding is
instant and costs nothing: no time, no organisation, no supplies. The path is left alone; only the order is cleared.
Any land unit qualifies, a headquarters included, but **only that unit boards**: its children stay where they are, and
only its own definition's weight counts.

`CNavy::AddCarried` (VA 0x5CF040, rva 0x1CF040; fleet in EAX, unit on the stack):

    army.carried_by = fleet
    army.dig_in_level = 0
    army.staging_province = 0
    if fleet == null: army.target = 0
    if the unit is not already listed: append it at the tail of fleet.carrying
    tell the first AI agent up the fleet's hierarchy (+0x198, then the parent's at +0x1E0), slot 69

Location, path, `movement_progress` and the place in the hierarchy are left untouched - which is why the April save's
19th Indian Infantry is aboard with `movement_progress=0.050`.

**By marching.** In `CUnit::AdvanceMovement` (rva 0x1CA430), when a land unit's next province is **sea**, it walks that
sea province's units (`+0x2B8`) and boards **the first fleet for which `CanCarry` is true** - so only its own country's
fleets, never an ally's: if the sea province is the end of the path, `AnnounceArrival`; then `AddCarried`, previous =
current, `EnterProvince(sea province)`, the path freed; if the unit was selected, the fleet is selected. With no fleet
that can carry it, the move is cancelled. `CArmy::MayStandIn` (rva 0x1CE2A0) makes the same `CanCarry` test, which is
what lets the route search put a sea province on a land unit's path.

### A.2 Capacity

The load is the sum, over the passengers, of each one's own rebuilt definition weight (`CUnit +0xC8`, `+0x10C`),
**each divided by 1000 and cut separately** (`SumTransportWeight`, rva 0x1D6690). The capacity is the fleet's
definition `+0x144` / 1000 - **the key is `transport_capability`**, for ships and transport planes alike; no
`transport_capacity` key exists. Both are sums over brigades or ships (`FINDINGS-unitdef.md`); a worn-out zero-width
support brigade adds no weight. Their Finest Hour's figures: `transport_ship` 40, `invasion_transport_ship` 60, every
other ship 0; `infantry_brigade` 10, armor 20, cavalry, light armor and motorized 15, artillery 5, HQ 10. So one
transport ship carries a three-infantry division (30 of 40), and France's three-transport fleet has 120.

`CheckTransportOverload` (VA 0x5CFBD0, rva 0x1CFBD0):

    while load > capacity:
        walk the passengers in list order:
            standing in a land province (the fleet is in port):
                RemoveFromTransport(fleet, no supplies, its province); EnterProvince(it, there)
                go on with the next passenger
            at sea and still has a brigade:
                remove its FIRST brigade and delete it (the unit's definition is rebuilt)
                if that was its last brigade: queue the unit for removal
                measure again

Nothing is shown to the player; what it posts goes to the unit-removal queue. It runs every hour for every fleet
(`CUnit::UpdateHourly`, 0x5BA003); every day behind `in_game` (`UpdateDaily`, 0x5BB413); after every round of a battle
(`CUnitList::RemoveSpentSubUnits`, 0x5D6653); and on the source fleet of a sub-unit transfer (0x5DCDC1) and of a split
(0x5EB737). So **sinking or splitting transports at sea destroys passengers brigade by brigade; in port it puts them
ashore.** This corrects `FINDINGS-manpower.md`, which had it daily only, and left `+0x22`'s direction open: `+0x22` set
is land.

### A.3 Getting off

There are four ways a passenger leaves a fleet.

1. **By command.** `CUnloadArmyCommand` (`unload_unit`, 0x519; the only key is `unit`). `IsValid` (VA 0x5E3740, rva
   0x1E3740): the unit exists, **the province it stands in is land**, and it is carried - since a carried unit stands
   where its fleet is, "the fleet is in port"; the refusal's tooltip is `UW_UNLOAD_NOT_VALID` "You can only unload if
   your fleet is located in a port." `Execute` (VA 0x5E3600, rva 0x1E3600): `RemoveFromTransport(fleet, no supplies,
   province)`, then `EnterProvince` in place. No cost, no supplies brought; the unit stays in the port. Posters:
   0x66A9E0, the unit panel's 0x75E458, the AI's 0x8D4F50, and one built inline by the AI at 0x891FE3.
2. **The fleet ends its path in a land province.** `CUnit::EnterProvince` (rva 0x1BEFD0, 0x5BF905-0x5BFA1E) runs for
   each passenger: first `LeaveAllCombats`; if the province is sea, or the fleet still has a path, the passenger simply
   enters the province with it; otherwise `RemoveFromTransport(fleet, carry supplies, province)`, `EnterProvince`,
   `CheckForCombat`. So **everyone gets off the moment a fleet arrives at the end of its path in port**; a port passed
   through mid-path keeps them aboard.
3. **Stepping ashore** (the landing, section B). In `AdvanceMovement` a carried land unit whose next province it may
   stand in has `previous_province` cleared, then `RemoveFromTransport(fleet, carry supplies, next)`. If it then may not
   stand there after all, it goes back aboard (`AddCarried`, 0x5CAF5F).
4. **`CNavy::UnloadCarried`** (VA 0x5CFE10, rva 0x1CFE10; `void __stdcall (CNavy*)`) does the same for every passenger
   without moving anyone. Its one caller is the transport mission.

`RemoveFromTransport` (VA 0x5CF120, rva 0x1CF120; `(fleet, carrySupplies, province)` on the stack, the unit in EDI,
`ret 0xC`):

    tell the fleet's AI agent, slot 70, with (army, province)    # the only use of `province`
    army.carried_by = army.dig_in_level = army.staging_province = army.target = 0
    if carrySupplies: CUnit::CarrySupplies(unit, the province the unit is in NOW, false, fromStockpile = true)
    unlink from fleet.carrying
    CheckForCombat(unit, the province it is in)

The supplies come from the pool of the unit's previous province where that is land, otherwise the owner's stockpile -
always the stockpile for a landing, whose previous province has just been cleared. They are `SUPPLYPOOL_DAYS` (15)
days' worth. **Because the unit has not moved yet, they land in the province it is leaving, which for ways 2 and 3 is a
sea zone.**

### A.4 At sea

**Location.** The passenger's location follows the fleet's hour: each time the fleet enters a province, `EnterProvince`
enters every passenger into it, with `LeaveAllCombats` first. Its `previous` is not changed - the Division de Tonkin
keeps `previous=5944` (Bac Ninh) through every save. The fleet sails at its own speed with no carrying term: 7.5 an
hour in the saves (7.5, 15, 37.5, 45 over hours 2, 3, 6, 7), which is `transport_ship`'s 15 x `NAVAL_SPEED_MODIFIER`
0.5. Passengers have `movement_progress` 0.

**Hourly.** No organisation regain while the fleet is at sea; in port it regains (`CUnit::RegainOrganisation`) - the
saves show 29.995 unchanged for 17 hours. `CheckForCombat` does nothing at all for a passenger while its fleet is
moving. A passenger that is going nowhere fights no one and is fought by no one (`CUnit::CanEngage`,
`CUnitList::AllHostileTo`). A passenger takes no province and blocks no taking.

**Daily.** No digging in (`UpdateDaily`). Troop rotation still drains strength (29.984 to 29.982 across a midnight in
the saves). It draws supplies through the carrier's base province (`FINDINGS-supplypass.md` section 4) and burns no
fuel, because it is not moving. Attrition applies by the province's own `attrition` modifier: `ApplyAttrition` has no
`+0x300` test (the negative from the same slot-9 `+0x300` scan that does find `UpdateDaily`'s test). Not reinforced
(`CSubUnit::CanReinforce`).

**Intelligence.** The passenger counts like any unit in the province: 2 at sea, 9 in port.

**Moving a passenger.** `CanMoveTo` skips the "no supplies onto enemy ground" test for a carried unit; a carried unit's
orders are section B's.

**The fleet while carrying.** **It may not move while any passenger has a path** (`CUnit::CanMoveTo`, 0x5C2E41). It
may take any naval order: no `MayBeGiven` but the invasion's reads the cargo. Under a `transport` order it is never made
the defender of a battle (`DefenderAcceptsBattle`, `FINDINGS-seabattle.md`), and an AI fleet under `transport` starts
no battle. A fleet whose passenger is moving or fighting is found without a sighting roll (`FINDINGS-navaldetection.md`).

### A.5 A sea battle with passengers, and the fleet's end

Passengers are hit only through the transports. `CUnit::SettleCombatDamage` (rva 0x1C3820) takes the notes the fleet's
`is_transport` ships took this round and lays them on every passenger brigade - organisation `notes x 1000 / (N x
2000)`, strength `notes x 1000 / (N x 1000)`, N the total number of brigades aboard - settled at once, with no shatter
test for the passengers. Ships under 0.1 strength are then removed, the fleet's capability falls, and
`CheckTransportOverload` destroys brigades at sea until the load fits again. **A fleet sunk whole loses every
passenger's brigades this way**, and each emptied passenger is queued for removal. No message is raised.

`CGameState::RemoveUnit(fleet, ., destroyPassengers)` (rva 0x284E40): with the third flag set it removes every passenger
with the fleet; otherwise it lets them go where they stand, all four carried fields cleared. Every caller read passes 1
except `CCountry_Reset` and `SetGovernmentInExile`, so **a disbanded fleet** (`CDisbandCommand::Execute` ->
`RemoveUnit(..., true, true)`), **a fleet drained from the removal queue, or one removed in a battle, takes its
passengers with it.**

**Merge** (`CUnit_MergeInto`, VA 0x5CDC90, rva 0x1CDC90; used by `CMergeCommand` and the join-fleet order): the
passengers move to the new fleet only if it is a fleet (or both are air units, section D). Capacity is not checked
until the next overload test. **Split or transfer**: the new fleet gets no passengers, and the old fleet's overload test
runs.

### A.6 The transport mission

`CNavalTransportOrder` (type 0x3A8): "Transport land units on board the fleet to the friendly land province, then
return to base." (`ORDER_TRANSPORT_DESC`).

**`MayBeGiven`** (VA 0x5A0640, rva 0x1A0640): the fleet in no battle; a target with a naval base above level 0;
`IsInRange`; the fleet allowed to stand in the target (`CNavy::MayStandIn`: owned, a port, the controller a friend and
no enemy). It does not ask about cargo. `Start` is an empty stub.

**`IsActive`** (VA 0x5A0690, rva 0x1A0690), every hour:

    no base, or CNavalOrder::IsActive false        -> the order ends
    in a battle, or return_to_base set             -> keep, do nothing
    may not stand in the target                    -> return to base (unless at base)
    moving                                         -> keep
    at base, carrying                              -> NavalOrder_GoTo(target), a safe path
    in the target, carrying                        -> CNavy::UnloadCarried
    in the target, empty                           -> COrder::OrderReturnToBase
    elsewhere                                      -> NavalOrder_SetPathFrom(here, safe) to the target

So it waits at base for cargo, sails, unloads into the port, and goes home. Arriving at the end of its path in the
target port already puts everyone ashore (A.3, way 2), so the usual next hour is the return.

**The French fleet.** From `_01_07_22` to `_01_08_07`: base Saigon (6236), target Luganville (6610), path running to
6610, moving. Every one of those hours the order is in its "moving -> keep" branch and does nothing. The division's
`location` tracks the fleet (11943, then 11233), and its `target=6610` is the AI's `CArmy +0x2E8`: **boarding keeps
`target`**; getting off clears it.

### A.7 Save and load

**Save.** `CNavy::SaveContents` (VA 0x5CFAA0, rva 0x1CFAA0) writes `CUnit`'s contents, then each passenger as a block
under its oob_level key (`theatre`, `armygroup`, `army`, `corps`, `division`, `navy`, `air`), then `at_sea` = `+0x2F8`,
the post-battle wait (0 on all 220 and 206 fleets of two saves). `CUnit::SaveContents` leaves a carried child out of its
land parent's block (0x5B8681). `CArmy::SaveContents` (VA 0x5CECD0, rva 0x1CECD0) writes `parent` only for a carried
unit - the April save has exactly 5 `parent=` keys for its 5 passengers, `_01_07_22` has 1.

**Load.** `CNavy::LoadKey` (VA 0x5CF6A0, rva 0x1CF6A0), for each of those land keys, builds a `CArmy`, gives it the
fleet's owner and reads the block; if it has a location, `CNavy::AddCarried(fleet, it)`, then `CCountry::AddUnit` -
**`AddCarried` zeroes the loaded `dig_in` and `staging_province`** and keeps `target`; with no location, it is deleted.
The `parent` id pair (`CUnit +0x54/+0x58`) is resolved and the unit reattached by `CUnit_RelinkLoadedParent` (VA
0x5CEDC0) for every unit as `CInGameIdler::Enter` runs.

### A.8 Corrections to the record

1. **`CLoadArmyCommand` has two keys, `navy` and `unit`**: the command names the fleet.
2. **The `at_sea` save key is `CNavy +0x2F8`, the post-battle wait.** `CNavy::LoadKey`'s and `SaveContents`' `this` is
   fleet + 8, so the "`at_sea` locks the carrying list" collision `CANDIDATES.md` queued does not exist; `+0x2F0` is the
   list's no-unlink lock.
3. **`CArmy +0x2E4` is `staging_province` and `+0x2E8` is `target`** (they were `ai_param_b`/`ai_param_a`). The
   `+0x1C8/+0x2E4/+0x2E8` "carried-by fields" in `WAVE.md`'s plan and `FINDINGS-supplypass.md` are dig-in,
   staging_province and target. The carrying list at `+0x2E4` is `CNavy`'s and `CAir`'s.
4. **`CSubUnitDefinition +0x144` is the `transport_capability` key.**
5. **`CheckTransportOverload` runs every hour and after every battle round, split and transfer**, not only daily; in
   port it puts passengers ashore, at sea it destroys brigades; what it posts goes to the unit-removal queue.

### A.9 What looks wrong but is what the bytes do

- Neither the load command's `IsValid` nor its `Execute` checks where the unit or the fleet is. A command naming a
  distant fleet boards the unit where it stands; it catches up only when the fleet next enters a province.
- Ways 2 and 3 of getting off carry 15 days of supplies into **the sea zone being left**. On arrival the source is the
  pool of the last land province the unit walked from; on a landing it is the capital's stockpile. Consistent with it,
  the saves hold `pool` supplies on unowned sea zones: 7 in April, and 12037/13467 holding the same 2.160/6.285 from 7
  to 8 January (`inferred` that these are the source, not traced).
- The unload command and the in-port overload unload bring no supplies at all.
- Boarding keeps `target` but clears `staging_province` and dig-in, including those just read from a save.
- A merge into a non-naval unit leaves the passengers listed on the fleet being removed.
- `CLoadArmyCommand::Execute` reads `is_selected`, which is local to each machine, and changes the interface's
  selection on every peer - harmless to the simulation.

### A.10 Not settled

- Whether anything ever draws on a sea zone's pool: the daily pass's handling of sea provinces was not read. A save just
  before and just after a fleet unloads in port, comparing the last sea zone's `pool`, would show it.
- Whether a retreating fleet with a passenger mid-landing can move: retreat sets a path through `SetUnitPath`, which
  was not seen to ask `CanMoveTo`.
- The flags `RunHourlyTick`'s removal drain passes as its second argument, and what `CCountry_Reset` and
  `SetGovernmentInExile` pass - those two may let passengers go in place.
- `CUnit::SaveContents`' branch at 0x5B8771, which writes a fleet under `navy` for a carried child: only partly read.
- What the AI agent's slots 69 and 70 do with the notifications (the AI's wave).

Frontier (rvas): 0x1E3810 and 0x1E3460 (factory prototypes); 0x1E3FE0 (copy constructor); 0x19A900 (`CNavalOrder`'s
constructor); 0x1CB830; 0x1CB980; 0x1B8C70 (key to oob_level); 0x4D54A0 (`CAIUnit` slot 70); 0x1EB620 (split helper);
0x4A0BD3, 0x4D4070, 0x4D4D40, 0x491BE0 (AI posters).

## B. The landing

No save holds an invasion, so nothing here was checked against a running game. The defines are Their Finest Hour's
`tfh/common/defines.lua`; the base game's `common/defines.lua` has none of the `AMPHIBIOUS_INVADE_*` keys.

| define | TFH | read at |
| --- | --- | --- |
| `AMPHIBIOUS_LANDING_PENALTY` | -0.7 | `BM_AMPH_PENALTY`, 0x5698D4 |
| `AMPHIBIOUS_INVADE_SPEED_BASE` | 0.5 | `CUnit::MovementSpeed`, 0x5C91D5 |
| `AMPHIBIOUS_INVADE_MOVEMENT_COST` | 24.0 | `CUnit::MovementDistance` 0x5C93BA, `CUnit::PathDistance` 0x5CCF4C (the arrow), the AI at 0x8B7C3A |
| `AMPHIBIOUS_INVADE_ATTACK_LOW` / `_HIGH` | 0.2 / 1.0 | slot 19, 0x569B90 / 0x569BA5 |
| `AMPHIBIOUS_INVADE_DEFEND_LOW` / `_HIGH` | 1.5 / 1.0 | slot 19, 0x569BBC / 0x569BD4 |
| `AMPHIBIOUS_INVADE_LANDING_PENALTY_DECREASE` | 3.5 | `BM_AMPH_PENALTY`, 0x569999 |

**How the define readers were found**: `fieldchain.py --holder 0xAC --field` for each offset. The four `_LOW`/`_HIGH`
defines have exactly one reader each, all in slot 19. Positive control: the same scan finds the known `MovementSpeed`
read of `+0x278` (which `functionStart` files under 0x5C8D10 - trap 2).

### B.1 The mission: `CNavalInvasionOrder`

`ORDER_INVADE_DESC` "Land troops, carried on the fleet, in the selected province". Type 0x3A5, 0x4C bytes (`CreateOrder`
does `push 0x4C` at 0x583B9E). `COrder +0xC` is the province to land on; its one field of its own, `+0x48`, is the sea
province the landing is made from, saved as **`transport`**. **`message` is accepted on load and thrown away**:
`LoadKey` (0x5A1030, rva 0x1A1030) parses it with `ParseBool` into a byte of its own argument slot (`lea
ecx,[ebp+0xB]`); `SaveContents` (0x5A1160, rva 0x1A1160) never writes it, and the object has no field for it.

**May it be given** - slot 11, 0x5A0790 (rva 0x1A0790), all of these in order: the unit is a fleet (slot 16); it is in
no battle; the province is **land**; slot 8 (`CNavalOrder::IsInRange`) says it is in range of the fleet's base; the
fleet carries at least one unit (`CNavy +0x2EC`); and **the first passenger's slot 34, `CArmy::MayStandIn`, allows the
province** - the "whose ground a country may walk on" rule of `FINDINGS-movement.md` 3.1: own ground, a friend's,
nobody's, or ground whose owner or controller the passenger's country is at war with. Nothing asks for a port, for a
war, or that the province is a coast; the coast is what Start has to find.

**Start** - slot 13, 0x5A0810 (rva 0x1A0810). It walks the target's edges in their order, impassable ones included. A
candidate is a neighbour that is sea, simulated (`+0x13D`) and that the fleet's slot 35 (`CanMoveTo`) allows. A
candidate is taken when nothing is chosen yet, or when `CMapProvince::NavalDistanceTo(target, candidate)` is **strictly
less** than the distance of the one chosen. That distance runs from the sea province the target names
(`CProvinceTemplate +0xA4`), and is 0 where the target names none. **"Nothing chosen yet" is tested as `best == 0`**, so
a candidate at distance 0 - the target's own named sea province, or every candidate where the target names none - is
displaced by the next candidate in edge order. With no candidate at all, `+0x48` stays null, and the order then does
nothing for as long as it lives.

**Each hour** - slot 14, `IsActive`, 0x5A0990 (rva 0x1A0990):

    fleet has no base (+0x98)                         -> false
    fleet in a battle                                  -> true, nothing done
    CNavalOrder::IsActive false                        -> false
    COrder +0x18 return_to_base set                    -> true (sailing home)
    fleet has a path                                   -> true
    fleet not at the landing sea:
        carrying something -> NavalOrder_GoTo(landing sea) where one was chosen; true
        carrying nothing   -> COrder::OrderReturnToBase; false
    at the landing sea, carrying:
        flanks  = each province on the target's edges, edge kind not 3, that is land,
                  whose owner area's slot 0 says yes, whose controller is an enemy of the
                  fleet's owner, that has an edge to the landing sea, and that holds no
                  enemy land unit
        heading = how many passengers' first path province is the target
        for each passenger, in list order, not in a battle:
            cannot fight (slot 33): kept aside if it has no path, else skipped
            can fight, but its slot 35 refuses the target -> OrderReturnToBase; false
            has a path: skipped
            e = enemy land units in the target (CountEnemyLandUnitsInList)
            if there are flanks and heading < e + 6 and heading < 2e:
                NavalOrder_GoTo(passenger, the next flank in turn)
            else:
                NavalOrder_GoTo(passenger, target); heading += its brigade count (CUnit +0x40)
        each passenger kept aside: to the target, or else the first flank, for which
            CUnit::OtherFighterBoundFor says a fighting unit of its country is bound there
        any kept aside still unplaced -> OrderReturnToBase; false
        true
    at the landing sea, empty:
        not at war with the target's controller           -> OrderReturnToBase; false
        a land battle in the target (HasCombatOfKind 1)   -> true (wait)
        a retreating unit in the target whose path ends
            at the fleet's own sea province               -> true (wait)
        otherwise -> OrderReturnToBase; true - the order lives on, lying in port

`NavalOrder_GoTo` gives a land passenger its path through `NavalOrder_SetPathFrom` (`CSafeNavalPathFind`, safe = 1);
from the sea to an adjacent coast that is a one-step path. Unlike every other mission's slot 14, this one **never asks
the "too worn" test** 0x59A990 (`FINDINGS-navalmissions.md` section 1). After a lost landing the passenger is back
aboard with no path, so the next hour sends it again.

### B.2 A land unit landing from the sea

**Making the order.** By hand, a carried unit's right click goes `CUnit::OrderToProvince` -> `CMoveCommand` ->
`CPathFind::Find` from the sea province the unit stands in (section C). The mission makes the same kind of path. The
route rules are `FINDINGS-movement.md` sections 3 and 3.1: an edge must exist from the sea province, not of kind 3; a
kind-1 crossing that a hostile fleet blocks is refused (`IsCrossingBlocked`); `CArmy::MayStandIn` must allow the
province - own, a friend's, nobody's, or at war with its owner or controller, never a neutral's; and against an enemy
controller the march-in tests also apply (strength above the shatter threshold, supplies and fuel received, the
military-access rule). **Nothing tests for a port or a naval base**, and nothing refuses a province where a battle
already goes on. A sea province on the route is allowed only where another idle friendly fleet with room stands there
(section A.1). The path may run on inland after the coast. `SetUnitPath` (0x5C9AC0) also registers the unit for the
`INVADEDUS` warning (B.6) and tells the theatre AI (0x8D56A0, not this wave).

**The march.** For a land unit with a path, standing in a sea province, whose next province is land:

- **The distance is `AMPHIBIOUS_INVADE_MOVEMENT_COST`** (24.0). `MovementDistance` does not ask whose coast it is or
  whether the unit is carried.
- **The speed is `AMPHIBIOUS_INVADE_SPEED_BASE` (0.5) plus the carrying fleet's `amphibious_invasion_speed`, and nothing
  else.** The fleet is the one at `CArmy +0x300`; its figure is its summed definition's `+0x188`, which
  `CUnit::RebuildDefinition` sets to the **mean over the ships that declare a non-zero one**, so escorts do not dilute
  it. `MovementSpeed` returns at 0x5C91E0, **before `MovementSpeedModifier` and before `LAND_SPEED_MODIFIER`**: weather,
  fuel, terrain, rivers and the retreat bonus do not touch a landing.
- Unit figures: `invasion_transport_ship` 0.50, `assault_ship` 0.75, plain `transport_ship` none;
  `amphibious_invasion_technology` adds 0.10 a level to each of the three, a technology's effect scaled by the level
  the ship holds. So, with progress added each hour as `FINDINGS-movement.md` section 5 has it, plain transports take
  24/0.5 = **48 hours**; assault ships at technology level 2 take ceil(24/1.45) = 17.
- **This applies to any coast, own or friendly too**: putting a unit ashore outside a port is this same march.

**Aboard during the march.** The unit stays on the fleet's list (`CNavy +0x2E4`) with `carried_by` set and its
`location` the sea province, moving with the fleet. In a save it is a `division` inside the fleet's block, with `path`
the coast and `movement_progress` rising. What stops it, all in `CUnit::AdvanceMovement` (0x5CA430):

- **A unit that cannot fight landing on enemy ground** (`CArmy::CanFight`: frontage brigades averaging strength 0.1 and
  organisation 1.0): if `CUnit::OtherFighterBoundFor` (0x5C2F20, rva 0x1C2F20) finds another fighting land unit of its
  country whose path *ends* there, it waits the hour with no progress; otherwise the move is cancelled. This corrects
  `FINDINGS-movement.md` section 5 step 3's "another of its units landing": the other unit need not be landing at all.
- No supplies received (`CUnit +0xFC` = 0) with the coast enemy-held and no battle there: cancelled (section 5 step 7).
  A carried unit draws its supplies from the fleet (`FINDINGS-supplypass.md` section 5).
- **The fleet moves.** The passenger's province changes with it. If the new sea province has no edge to the coast, the
  move is cancelled at the next step check; if it still has one, the march goes on with its progress kept. While the
  fleet has a path, `CCombatManager::CheckForCombat` refuses the passenger any new battle (0x4309A3..0x4309C0), so a
  fleet under way cannot start a landing battle.
- **The fleet in a sea battle**: the passengers are not part of it - a land unit is never added to a naval battle (A.5).

**Off the ship**, on arrival only - progress has reached the distance, the unit is in no battle, and the hour is not
before `end_date`: the node is dropped and `progress -= distance` (zeroed under an attack delay); where the unit is
carried and `MayStandIn` still allows the coast, `RemoveFromTransport(fleet, true, coast)` (0x5CF120); then `previous`
= the sea province, `CUnit::EnterProvince(coast)`, and `CheckForCombat`, which takes an unheld coast
(`FINDINGS-landbattle.md` section 1, `TakeControl`). If the coast may no longer be stood in (say, peace was made), the
move is cancelled and the unit stays aboard; the 0x5CF040 re-board branch after it cannot be reached on that path.
**During a battle the progress keeps growing but is held at the distance**, so the unit never comes ashore while it
fights; a won landing still has to finish its 24 points.

### B.3 The invasion's progress and its two scales

**`AMPH_INVASION_PROGRESS`** "Amphibious invasion progress: $PERC$%" is `CUnit::MovementProgressShare` (0x5CA340, rva
0x1CA340): `movement_progress * 1000 / MovementDistance`, i.e. progress over 24.0, truncated; 0 with no path and -1 at
distance 0.

**`AMPH_INVASION_ATTACK_SCALE`** "Invasion total attack ability: $PERC$%" and **`AMPH_INVASION_DEFEND_SCALE`** "Invasion
total defence ability: $PERC$%" are `CUnit +0xF4` and `+0xF8`. `CLandCombatant::ApplyCombatModifiers` (slot 19,
0x569B50, rva 0x169B50) computes them every battle hour, after the base slot 19 has reset all four multipliers to 1000
(`CUnit::ResetCombatModifiers`), for every unit of the side that has a path, is land, stands in a sea province, and
whose next province is land controlled by an enemy of its owner:

    p       = MovementProgressShare(unit)                                  thousandths
    attack  = ATTACK_LOW + (ATTACK_HIGH - ATTACK_LOW) * p / 1000          -> +0xF4
    low     = DEFEND_LOW + (carried ? fleet.+0xC8.amphibious_invasion_defence : 0)
    defence = low + (DEFEND_HIGH - low) * p / 1000                        -> +0xF8

The products are 64-bit and truncated toward zero. **Whether the unit is the attacker is not asked.** The fleet's
`amphibious_invasion_defence` (`+0x18C`) is a **plain sum over its ships**: `invasion_transport_ship` 0.10,
`assault_ship` 0.25, plus 0.10 a level of `amphibious_assault_units` on each of the three transport types. With plain
transports and no technology, attack runs 20% to 100% and defence 150% to 100% over the 48 hours; ten assault ships at
level 2 give 1.5 + 4.5, a defence of **600%** at the first hour.

**Where they act**, in `CLandCombatant::FireUnit`: the shot count is `(+0xEC * +0xF4 / 1000) * (soft + hard) / 1000 /
1000` (0x56AED2), so the attack scale cuts the shots; the unit's defence as a target is multiplied by `+0xF0 * +0xF8 /
1000` (0x56B0CB).

**On screen**: the battle's unit tooltip (section C.6). The entry's `combat_unit_bg` bar is the same share in whole
percent (0x729CC3). The fleet side has its own landing figure, `CNavy::MeanLandingProgress` (0x5D00A0, rva 0x1D00A0;
the mean progress share of the passengers landing on enemy ground, with `CNavy::HasLandingPassenger` 0x5CFFF0), which
feeds a float at `+0x15C` of an object at the fleet's `+0x190` (0x5CB630, not read). The arrow of a unit landing on any
ground uses the texture `unitInvasionArrow` (`CUnit::MakeArrow`, 0x5CCB43).

### B.4 The battle at a landing

**How it starts.** `CUnit::CheckOrderAndCombat` step 6 (`FINDINGS-landbattle.md` section 1) calls
`CheckForCombat(unit, next)` for a land unit with a path when an enemy land unit stands in the next province, the unit
has no battle there, and it has received supplies. `StartCombat` makes the landing unit the **attacker** and the first
engageable unit of the coastal province the defender, fighting in the coastal province. `CanEngage` lets a carried unit
fight because it has a path. So **a landing into an empty enemy province fights no battle**: the unit marches its 24
points, lands, and takes the province on arrival; a battle starts only if enemy land units arrive there meanwhile. A
landing into a province where a land battle already goes on joins it (`JoinCombatInProvince`), on the side whose
enemies are all its enemies.

**`BM_AMPH_PENALTY`** (0x0B, the call at 0x569A63), in `CLandCombatant::AddAssaultModifiers` (slot 27, 0x569750, rva
0x169750), for attackers only. The unit counts as amphibious when it stands in a sea province (unless its owner is
`REB`), or when it attacks along an edge of kind 1 - so **a strait assault from land gets the penalty too**, without the
landing scales or the cut below. A paratrooper (`+0x97`) clears the flag. With the flag set:

    v = AMPHIBIOUS_LANDING_PENALTY + the division's amphibious.attack (+0xB4) + trait 25 amph_attack
    if v < 0 and IsLandingFromSea(unit, false) and the unit is carried (CArmy +0x300):
        s   = 1000 + sum over the division's regiments of fleet.+0xC8.extra_amphibious_defence[regiment type_index]
        r   = min(s * fleet.+0xC8.amphibious_invasion_defence / 1000, LANDING_PENALTY_DECREASE)   (-1 where the define is 0)
        v   = v * (floor(1010.5) - r * 1000 / LANDING_PENALTY_DECREASE) / 1000
    v = max(v, floor(-989.5))
    if v < 0: add BM_AMPH_PENALTY(v, v)

- **`extra_amphibious_defence` never counts.** The map lives inside an embedded `CSubUnitAmphibiousMult` at
  `CSubUnitDefinition +0x200` (map at `+0x218`). A fleet's summed definition is made by the named constructor (empty
  map), then rebuilt by `Assign` of the null definition and `Add` of each ship; neither touches `+0x200..+0x223`. Only
  the copy constructor 0x536570 copies it (0x536A24..0x536A6E), the positive control for what a copy looks like. So `s`
  is always 1000, and `assault_ship`'s per-brigade extras do nothing.
- The amphibious adjuster read here is the **mean** of the brigades' figures: `RebuildDefinition` divides adjusters by
  the brigade count (`CSubUnitDefinition::Divide`); `FINDINGS-combatmods.md` section 4's "three times one brigade's"
  predates that reading. Infantry has none, engineers 0.4, marines 0.5.
- Worked out: with no landing craft `r = 0` and the penalty is **multiplied by 1.010**, so -0.7 becomes -0.707; at `r`
  = 3.5 it is multiplied by 0.010.

**Other terms.** The amphibious flag makes `BM_FORT_MODIFIER` read the coast's `COASTAL_FORT_LEVEL` instead of
`FORT_LEVEL`. `BM_SHORE_BOMBARD` counts, on each sea neighbour of the battle province, the enemy units **with no path**:
the slot 19 loop does `cmp [esi+0x140],0; jg skip` at 0x569DE5, which corrects `FINDINGS-combatmods.md` section 5's
"`u->+0x140 > 0`". So escorts standing still beside a beach bombard its defenders, at `SHORE_BOMBARDMENT_MOD` -0.01
each, floored at `SHORE_BOMBARDMENT_CAP` -0.25.

### B.5 The outcome

- **Won**: the defenders fall back and the battle ends. The landing unit is still at sea with its progress held,
  finishes its march the following hours, comes off the ship on arrival (B.2), and its `CheckForCombat` takes the
  province by `TakeControl`.
- **Lost**: `CUnit::RetreatFromCombat` (0x565760) sends a unit not standing in the battle's province to "the province
  it is in" - the sea. Since that is where it stands, it gets a null order and `CUnit::CancelMovement(unit, true)`:
  progress 0, path emptied, **still aboard**, `retreat` not set. A carried unit is never removed for having nowhere to
  go. Under the mission it is sent again next hour if it can fight; if it cannot, it is "kept aside", and the order ends
  with it still aboard unless a fighting unit is bound for a landing province.
- **A friend's or nobody's coast**: the same 24-point march, no `INVADEDUS`, no landing scales, no wait or cancel for a
  unit that cannot fight. On arrival `TakeControl` leaves a friend's coast with its controller; `CheckForCombat`'s
  change-of-hands step needs an owner, so an unowned province does not change hands.

### B.6 The message `INVADEDUS`

It is raised by `InvasionWarnings_Hourly` (0x44DE20, rva 0x4DE20), **the first thing `RunHourlyPass` does** (0x682654),
on a list kept at `CCurrentGameState +0x8`.

**How the list is filled.** `SetUnitPath` calls `InvasionWarnings_Add` (0x44DCC0) for every unit given a path. A unit is
listed under its owner's country when `InvasionWarnings_IsInvadingPlayer` (0x44DBB0) holds: the player's country is an
enemy of the unit's owner; `IsLandingFromSea(unit, false)`; and the first province of its path is **controlled** by the
player. A country new to the list, or a unit new to its entry, sets the entry's `new` byte; **an already-listed unit
given a path again clears it.**

**Each hour, for each country**: units that no longer resolve or no longer qualify (landed, cancelled, destroyed, coast
lost) are dropped; where some remain and `new` is set, `new` is cleared and **one message goes to the player**, with
`ENEMY` = the invader's name (`CountryNameOfCountry`) and `PROV` = `FormatProvinceList` of the distinct first-path
provinces of **all** units still listed for that country, in list order ("A, B and C"); the player's own variables come
first (`BuildMessageVariables`, which presumably supplies the header's `$chief_of_staff$` - `inferred`, not traced); the
message's province is the first of the list; it is posted with `PostMessage_CInGameIdler`. Texts: header
"$chief_of_staff$ reports that"; popup "$ENEMY$ is storming our beach" / "in $PROV$."; log "$ENEMY$ is storming our
beach in $PROV$."; map "Invasion"; setup "When enemy is storming our beaches."; buttons OK, OK, GOTO.

So the message comes **the hour after the landing path is set**, before any battle and up to 48 hours before anyone
comes ashore. When the player changes, the list is emptied.

### B.7 Corrections to the record

- `AddAssaultModifiers`' `+0x300` is the carrying fleet (`CArmy::carried_by`), not "the province's naval base"; its
  `+0x18C` is the fleet's summed `amphibious_invasion_defence`; the `+0x218` map is the empty
  `extra_amphibious_defence`.
- `CSubUnitDefinition +0x188`/`+0x18C` are read off the fleet's definition, and `+0x188`'s reader is `MovementSpeed`;
  the landing speed escapes `LAND_SPEED_MODIFIER`.
- `CUnit +0xF4/+0xF8` are the landing's own attack and defence scales (they were `combat_attack_modifier_b`/
  `combat_defend_modifier_b`).
- `FINDINGS-movement.md` section 5 step 3's "another unit landing" should read: any fighting unit whose path ends there.
- Shore bombardment counts units with no path.
- `CCurrentGameState +0x18` is the invasion-warning list's copy of the player tag, which explains both of its earlier
  readings (`---` and `IRE`).

### B.8 What looks wrong but is what the bytes do

1. The mission lands on the **flanks** while `heading < min(e+6, 2e)`, and `heading` only grows when a unit is sent to
   the target. So with a defended target and any qualifying flank, every fighting passenger that hour goes to the
   flanks. `heading` also starts as a count of units and grows by brigades.
2. Start treats a naval distance of 0 as "nothing chosen yet", and does not skip impassable edges, which IsActive does.
3. `message` is read and dropped; it is never saved.
4. One fighting passenger refused by `CanMoveTo`, or any non-fighting passenger left unplaced, ends the whole invasion
   order (return to base).
5. The empty fleet waits for retreating units whose path ends in its sea province. Retreats only go to land, so this is
   probably never true (`inferred`).
6. Landing speed ignores `LAND_SPEED_MODIFIER` and every speed modifier. A landing on one's own coast is the same
   24-point march.
7. `BM_AMPH_PENALTY`'s "cut" multiplies by 1.010 when there is no landing defence, and `extra_amphibious_defence` is
   inert.
8. The landing scales are set for any landing unit in a battle; the attacker is not asked.
9. Re-pathing an already-listed invader clears its country's pending `INVADEDUS`, and `PROV` lists all units'
   provinces, not only the new ones.
10. A non-fighting landing unit waits, with no progress, as long as any fighting land unit of its country has a path
    ending at that coast, landing or not.

### B.9 Measured on the maintainer's screenshots, 2026-10-15

Three screenshots of the original's battle window, Germany landing three infantry divisions from Danzig Bay against
one Polish division in Danzig on plain transports, the unit tooltip of 1. Infanterie-Division at three moments. Every
figure B.3 predicts is there, to the hundredth:

| shown | B.3's arithmetic |
| --- | --- |
| progress 4.10% | progress 1.0 of 24 (two hours at 0.5): 1000 x 1.0 / 24 = 41.67, cut to 41 |
| attack 23.20% | 200 + 800 x 41 / 1000 = 232.8, cut to 232 |
| defence 148.00% | 1500 + (-500 x 41) / 1000 = 1500 - 20.5, **cut toward zero** to 1480 (a floor would give 147.90) |
| Attack Modifier 7.60% / 33.10% | 331 x 232 / 1000 = 76.8, cut to 76 - the first figure is `+0xEC x +0xF4 / 1000` |
| Defend Modifier 48.90% / 33.10% | 331 x 1480 / 1000 = 489.9, cut to 489 |
| progress 39.50%, attack 51.60%, defence 130.30% | progress 9.5: 395.8 -> 395; 200 + 316 = 516; 1500 - 197.5 -> 1303 |
| Attack Modifier 8.50% / 16.50% (by night) | 165 x 516 / 1000 = 85.1 -> 85 |
| Amphibious Penalty -70.70% | `AMPHIBIOUS_LANDING_PENALTY` -0.7 x 1.010, the "cut" with no landing defence (B.8 item 7) |
| progress 100.00% in green; no transports line and no scale lines | `p >= 1000` drops the description; both scales back at 1000 are not written |

The third screenshot has the three divisions still in Danzig Bay at 100%, fighting: the progress held at the distance
while the battle lasts (B.2). The tooltip's order is the leader's line first, then the landing block, a blank line, and
the modifier lines.

### B.10 Not settled

- Whether a unit-type template's `CSubUnitAmphibiousMult` map is ever filled from its name list (0x542FC0 stores the
  names at `+0x208`). It does not matter for the penalty, which reads only the fleet's summed definition.
- Which sea province Start chooses in practice: that depends on whether coastal provinces name a sea province
  (`+0xA4`). A save taken while a fleet is under an Invasion order would show it as `transport=<id>` in the fleet's
  mission block, and the passenger's `movement_progress` would rise 0.5 an hour on plain transports.
- A screenshot of a landing unit's battle tooltip would confirm B.3's lines - e.g. "Amphibious invasion progress:
  25.00%" in red, attack 40.00%, defence 137.50% at 12 hours on plain transports.
- What happens to a passenger fighting a land battle while its fleet sails away (`inferred`: it keeps fighting, then is
  cancelled for want of an edge).
- What 0x5CB630 shows on the map.

Frontier (rvas): 0x1CB630 (the fleet's landing marker, sets `+0x190`'s `+0x15C`), 0x1CB980 (the second caller of
`MeanLandingProgress`), 0x1CB830 (the first landing passenger's coast), 0x4BEC70 (the AI's use of
`MovementProgressShare`), 0x4D56A0 (the theatre told by `SetUnitPath`), 0x142FC0 (`CSubUnitAmphibiousMult` name store),
0x82860 (`CSubUnitAmphibiousMult` slot 0), 0x4E780 / 0x4E6A0 / 0x4EBE0 (the warning map's find, operator[] and step).
The orders window builds the invasion order at VA 0x73E3C9 with `+0x48` = 0.

## C. Carrying on screen

Every line is `confirmed` unless it says otherwise. Nothing here was watched in a running game.

**In one line.** A land unit is loaded through its panel's `load_button`, or several at once through the multi-unit
panel, and unloaded through `unload_button` or `unmount_multiunit`; each button posts the load or unload command, and
the rules behind it are sections A and D's. Every fleet's and every air unit's panel has a `sup_loaded` row: a capacity
line and one row per passenger. A passenger in port has no counter on the map, while one at sea has its own counter
beside its fleet's. Nothing on the map marks a landing.

### C.1 The unit panel's four buttons

`sup_buttons_window` (`single_unitpanel.gui`) puts each pair at one spot, so only one of each pair shows:
`load_button` and `unload_button` at (222, 1), sprites `GFX_button_load_boat` and `GFX_button_unload_boat`, shortcut
`l`; `load_plane_button` and `unload_plane_button` at (248, 1), sprites `GFX_button_load_air` and
`GFX_button_unload_air`, shortcut `p`. `CSingleUnitButtons::Update` (`0x75EC40`, rva `0x35EC40`) sets them every
frame.

**The ship buttons.**

- **A land unit aboard a fleet** (CArmy `+0x300`): `unload_button` is shown and `load_button` hidden. The unload button
  is **enabled where the province the unit stands in is land** (its template's `is_land`). A carried unit stands where
  its fleet is, so this means "the fleet is in port".
- **A land unit aboard nothing**: `load_button` is shown, `unload_button` hidden. The load button is enabled where
  `CSingleUnitButtons_FindFleetToBoard` finds a fleet.
- **Anything else** (a fleet, an air unit, or a land unit aboard a plane): both are hidden.

**The plane buttons**, the same way: aboard an air unit (`+0x304`), `unload_plane_button` is shown, enabled where that
air unit is `CUnit_IsAtOwnBase`; aboard nothing, `load_plane_button` is shown, enabled where
`CSingleUnitButtons_FindPlanesToBoard` finds an air unit; otherwise - a land unit aboard a ship included - both hidden.

**`CSingleUnitButtons_FindFleetToBoard`** (`0x75E510`, rva `0x35E510`) answers null unless the unit is a land unit,
its province is land, it is in no battle (`combats_count` 0), and the province's naval base has a **built** level
above 0 (`level_max`, so a bombed base still counts). It then walks the fleets lying in the province's port
(CMapProvince `+0x354`, the port's list) in list order and returns **the first** that `CNavy::CanCarry` accepts
(section A: same owner, not in battle, not moving, not retreating, and the passengers' weight plus this unit's fits).
The player is never offered a choice of fleet.

**`CSingleUnitButtons_FindPlanesToBoard`** (`0x75E5B0`, rva `0x35E5B0`) is the same with an air base (`+0x304`) for the
naval base, the units stationed at the province's base (CMapProvince `+0x54`) for the port's fleets, only air units
that are `CUnit_IsAtOwnBase`, and `CAir::MayLoad` (section D) as the test.

**Tooltips** (already in `FINDINGS-unitpaneltooltips.md` section 9; they ask the same calls):

- `unload_button`: `UW_UNLOAD_VALID` "Unload this unit from the fleet"; where the province is not land,
  `UW_UNLOAD_NOT_VALID` "You can only unload if your fleet is located in a port."
- `load_button`: `UW_LOAD_IS_VALID` "Click to load this unit onto a transport fleet.", or `UW_LOAD_NO_FLEET_FOUND`
  "There is no fleet here that this unit can be loaded onto."
- `unload_plane_button`: `UW_UNLOAD_PLANE_BASE_OK` "Unload from transport planes.", or `UW_UNLOAD_PLANE_BASE_ONLY` "You
  can only unload at an airbase."
- `load_plane_button`: `UW_LOAD_PLANE` "Load this unit onto transport planes." Where no air unit is found,
  `UW_LOAD_PLANE_FAIL_LOW_ORG` "Our paratroops have too low organization. They need to be at 95% of their maximum." where
  any brigade's `organisation * 1000 / its maximum` is under `PARATROOP_MISSION_ORG_REQ` (0.95), otherwise
  `UW_LOAD_PLANE_FAIL` "There are no transport planes here that this unit can be loaded onto."

**Clicks.** Each handler first does nothing at all in a custom game where `0x4208B0` marks the local player (not
identified; the same lock greys the rest of the strip). Then `load_button` (`0x75E0B0`) runs the finder again and posts
**`CLoadArmyCommand(unit, that fleet)`**; `unload_button` (`0x75E400`) posts **`CUnloadArmyCommand(unit)`**;
`load_plane_button` (`0x75E1D0`) posts **`CLoadOnPlaneCommand(unit, air unit)`**; `unload_plane_button` (`0x75E2F0`)
posts **`CUnloadFromPlaneCommand(unit)`** - each to the session's command channel.

**Other buttons on the same strip**: `disbandbutton` is disabled for a land unit aboard a ship or a plane;
`newunitbutton` (split) is disabled for a land unit aboard either, and for a fleet or an air unit carrying anything.
Already known and only cited here: the header's `leader_button` is disabled for a land unit aboard anything
(`FINDINGS-unitpanel.md` section 4); `unitbase` shows the carrier's base (section 5); `unit_weight` is the land unit's
weight, tooltip `TRANSPORT_WEIGHT` "Weight".

### C.2 A fleet's list of what it carries

`CSingleUnitPanel::Rebuild` adds a **`CWindowForLoadedUnitsEntry` to every fleet's panel and every air unit's panel**,
unconditionally (constructor `0x7575C0`, rva `0x3575C0`). Its window is `sup_loaded` (254 x 222): `bg_loadedunits`;
`header` (Arial12_bold_black, at 8,8); `select_land` (170,3, shortcut `.`); `select_air` (237,3, shortcut `,`); `list`
(0,32, 307 x 192). The base game's and Their Finest Hour's files are identical here.

**`header`** is filled by `CWindowForLoadedUnitsEntry_Fill` (`0x757CB0`): `LOAD_CAPACITY_LABEL` "Can carry $NUM$
weight.", with nothing aboard `NUM = trunc(transport_capability / 1000)` of the unit's summed definition, otherwise
`NUM = (that - SumTransportWeight(passengers)) + " (" + that + ")"` - what is left, then the whole. Weights are whole
units, each passenger truncated. Worked example (`inferred`: it assumes no technology changes either figure, and
nothing shows the header): the French *Flotte expeditionnaire de transport*, three `transport_ship` flotillas
(`transport_capability = 40` each), carries the *Division de Tonkin*, three `infantry_brigade`s at `transport_weight =
10`, so its header reads **"Can carry 90 (120) weight."**

**The list** is one `CLoadedUnitEntry` per unit on the carrying list (`+0x2E4`), in list order. **For a fleet it then
has a row for every air unit aboard each of its carriers**: each ship whose definition's `carrier_size` is above 0, the
units in its `CShip +0xDC` list. An air unit's list has its passengers only.

**A row** is the window `loadedunit_entry` (360 x 38); constructor `0x74CB30`, update `0x74CF30`, which finds the unit
again by its id each frame. `counter_type`: `GFX_counter_` + the type of the unit's first brigade, where the player's
intel on it is 3 or more and the sprite exists. `counter_size`: by `oob_level`, as in the header. `name`: the unit's
name, without a leader. `order`: `CUnit::DescribeOrder`. `objective`: `0x5B5B50`. `org_bar` and `str_bar`: the
header's whole percentages, worked here in single-precision floats. **No strength figure**: this window has no `str`
text. Clicking `select` selects the passenger: the selection is cleared, the unit selected, and the map centred on its
province. The row's tooltip is `CChildUnitEntry::BuildTooltip`, a shared body.

**The window's tooltip**: `select_land`, `UW_SELECT_LAND` "Select all attached land units."; `select_air`,
`UW_SELECT_AIR` "Select all CAG's attached to this fleet."; anything else is answered by the row under the mouse.

**The two buttons** (update `0x7577B0`): `select_land` is enabled where anything is aboard; `select_air` is enabled, for
a fleet, where any carrier has aircraft aboard, and hidden for an air unit. Clicking either clears the selection and
selects every passenger (`0x758B00`), or every aircraft aboard the fleet's carriers (`0x758940`).

**Refresh.** Every frame each row updates itself. **Only an air unit's list is filled again** when its passenger count
changes. `CSingleUnitPanel_RefreshIfChanged` (`0x7624F0`) rebuilds the panel only when the number of units above, the
battles, the AI agent or a request byte change. So a fleet's list is built when the fleet is selected, and is **not
rebuilt while it stays selected** (see C.8).

### C.3 Several units at once

Their Finest Hour's `multi_unitpanel` (`CInGameIdler +0x1368`) has three buttons - the base game's file has only
`load_multiunit`: `unmount_multiunit` at (127, 26), `load_on_air_multiunit` at (160, 26), `load_multiunit` at
(193, 26). `CInGameIdler_UpdatePanels` (`0x650700`) handles them whenever the selection list has two rows or more: it
**shows all three where the first row's unit is a land unit**, and hides them otherwise. Then `load_multiunit` is
enabled where `CInGameIdler_FindFleetForSelection` (`0x669BF0`) finds a fleet, `load_on_air_multiunit` where
`CInGameIdler_FindPlanesForSelection` (`0x669AA0`) finds an air unit, `unmount_multiunit` where any selected land unit
is aboard a ship or a plane; all three are disabled under the custom-game lock.

**The fleet finder** needs two or more units selected. It goes through the selection in order and adds up each unit's
whole weight (`CUnit_TransportWeight`), failing at the first unit that is not a land unit, or that stands in another
province than the one before it, or in a province that is not land, or in a battle, or where no naval base is built.
In the last unit's port it answers the first fleet whose passengers plus the whole selection fit within
`trunc(transport_capability / 1000)` and which **`CNavy::CanCarry` accepts for the last selected unit only**. The air
finder is the same over the air units at their own base, with `CAir::MayLoad`.

**Clicks.** `load_multiunit` (`0x66AB50`) posts **one `CLoadArmyCommand(unit, fleet)` per selected unit**, all naming
the same fleet; `load_on_air_multiunit` (`0x66AA30`) does the same with `CLoadOnPlaneCommand`; `unmount_multiunit`
(`0x66A750`) posts first a `CUnloadFromPlaneCommand` for each unit aboard a plane, then a `CUnloadArmyCommand` for each
unit aboard a ship. **It makes no test of where the carrier is**; section A's `CUnloadArmyCommand::IsValid` refuses
one that is not in a land province.

**Tooltips** (`CInGameIdler::GetElementTooltip`, read in the listing):

- `load_multiunit`: `NO_MULTILOAD` "There is no possible fleet to load these units onto.", or `MUL_LOAD_ONTO` + `" §Y"`
  + the fleet's name + `"§W"` - "Load these units onto *name*"; its delayed half, always, `TOTAL_LOAD_WILL_BE` +
  `" §Y"` + the sum of every selected unit's whole weight + `"§W"` - "The units weigh a total of 30".
- `load_on_air_multiunit`: the same, with `NO_MULTILOAD_AIR` "There is no air transport available to load these units
  onto." and the air unit's name.
- `unmount_multiunit`: `UNMOUNT_MULTILOAD` "Unmount §G$NUM$§! units from air and naval transports.", with NUM =
  `CInGameIdler_CountSelectedAboard(null, plane, ship)` (`0x669A10`); where NUM is 0, `UNMOUNT_MULTILOAD_NONE` "There
  are no units to unload from air or naval transports."

### C.4 The map

**The right click** takes the province under the pointer; no counter is consulted. If the orders view is up, it gets
the click; otherwise every selected unit gets `CUnit::OrderToProvince(province, shift)`. A land unit, carried or not,
goes through `CUnit::CanMoveTo`: the province it stands in gives `CCancelMovementCommand`; a province it may not enter
gives the `illegal_selection_projection` effect and the `error` sound; otherwise `CMoveCommand` and the `army_move`
sound. For carrying, that means:

- **A sea province** is enterable only where a fleet of the same owner lies that `CNavy::CanCarry` accepts
  (`CArmy::MayStandIn`, `FINDINGS-movement.md` 3.1). What happens on arrival is section A's.
- **A right click on a fleet's counter in port is a right click on the port province.** For a unit already standing
  there it cancels a move; for one elsewhere it marches there. It never loads.
- **A unit at sea** (aboard a fleet) may be sent only to a land province that **has an edge from the sea province it
  is in** - the direct landing, section B's.
- The "no supplies" refusal is skipped for a carried unit; the shatter and fuel refusals still apply.

**The province tooltip** (`FINDINGS-provincetooltip.md` section 2) has **no key for carrying or landing**: a scan of the
image for `UTM_*` strings finds only the seven already known, so a sea province the unit cannot enter shows no warning
at all. `UTM_LACK_OF_SUPPLIES` is left out for a carried army.

**A fleet carrying units**: a plain right click on a coast that is not sea-connected opens the naval orders window -
only where the province is land and coastal, the fleet carries something, the first passenger may stand there, shift
is not held and the fleet is in no battle; otherwise the illegal projection and `error`. Elsewhere the usual rules
apply: the orders window, or a move with shift (`FINDINGS-seaair.md` section 1).

**Counters** (`CProvinceTemplate_AddUnitCounter`, rva `0xAB880`, read in the listing):

- **A land unit carried by a fleet in a land province gets no counter.** A passenger in port is shown by nothing on the
  map except the port.
- **At sea it has its own counter**: in stack 1, the moving one, while its fleet has a path (`[[unit+0x300]+0x140] >
  0`, 0x4AB976), otherwise in stack 0.
- A unit carried by a plane goes in stack 4, the air stack.
- No reader of a fleet's passenger count was found in the counter code. Search: `fieldchain.py --field 0x2EC` over the
  image found no reads in `0x839000`-`0x84B000`. Positive control: the same scan finds the unit panel's reads at
  `0x76025D`, `0x760298` and `0x757E88`.

**No landing marker.** No sprite in `interface/` or `tfh/interface` `.gfx` names an invasion or landing, and the
march's arrow is the ordinary path arrow.

### C.5 The orders window's Transport and Invasion rows

`CNavalOrdersView` (`FINDINGS-seaair.md` section 2) lists `CNavalTransportOrder`'s and `CNavalInvasionOrder`'s rows,
`ORDER_TRANSPORT` "Transport" and `ORDER_INVADE` "Invasion", **always**. Each is greyed where
`COrder::IsTargetInRange` fails or its slot 11 says no: `CNavalTransportOrder::MayBeGiven` (`0x5A0640`, section A: the
fleet in no battle, the target with a built naval base, in range, and the fleet may stand there);
`CNavalInvasionOrder::MayBeGiven` (`0x5A0790`, section B: a fleet in no battle, a land target, in range, carrying
something, and **the first passenger** may stand there).

**Which row is ticked when the window opens.** Where the fleet may stand in the province, its controller is not at war
with the fleet's owner, a naval base is built and "rebase" can be given: **"transport" if the fleet carries anything,
else "rebase"**; otherwise "move_order" (`0x73E5B1`..`0x73E5E3`). It does not ask whether the transport row itself
passed.

**Accept** posts `CSetOrderCommand(unit, token, the province's id, the hour, null)` for each naval unit selected.
**Row tooltips**: `ORDER_TRANSPORT_DESC` "Transport land units on board the fleet to the friendly land province, then
return to base."; `ORDER_INVADE_DESC` "Land troops, carried on the fleet, in the selected province"; `OUT_OF_RANGE`
when out of range.

### C.6 Anything else on screen

**A land unit's tooltip in a battle** (`CCombatView::BuildUnitTooltip`, read in the listing `0x72A984`..`0x72AE04`).
Where `CUnit::IsLandingFromSea`, with p = `CUnit::MovementProgressShare` (section B):

- while p < 1000: `AMPH_INVASION_COMBAT_PROGRESS_DESC` "This unit is currently in amphibious transports. Its offensive
  capabilities are reduced and its defence improved by the transports' armour.", followed by a blank line;
- `AMPH_INVASION_PROGRESS` "Amphibious invasion progress: $PERC$%", with PERC = `§R` (or `§G` from 1000) +
  `FormatFixedPoint(p * 100000 / 1000, 2)` + `§!`, so 500 shows "50.00";
- `AMPH_INVASION_ATTACK_SCALE` "Invasion total attack ability: $PERC$%", from `+0xF4`, and `AMPH_INVASION_DEFEND_SCALE`
  "Invasion total defence ability: $PERC$%", from `+0xF8` - each only where its figure is not 1000, `§R` below and `§G`
  above, each on its own line.

**Production and ledger figures.** The production screen's `transports_value`, labelled `PW_AVAILABLE_TRANSPORT_ESCORT`
"Available transports/escorts", is the **convoy pool** (`CCountry +0xB0`, `FINDINGS-convoylines.md`); nothing there
counts troop transports or passengers. `LEDGER_TRANSPORTS` "Transports" is a column of the **convoys** ledger page
(`0x7A1570`). `TRANSPORT_WEIGHT` and `TRANSPORT_CAPABILITY` appear only as stat lines in
`CSubUnitDefinition::BuildStatsTooltip`, the unit stats window and the panel's `unit_weight`.

**Messages and the province view.** **No message** for a load or an unload: a string scan of the image found no
carrying-related message key except `INVADEDUS` (section B's), which is the scan's positive control. No carrying key is
referenced from the province view. `AnnounceLoadedUnitsToScreen` (rva `0x48D560`) is about units *created* by an
order-of-battle effect, not units aboard anything.

### C.7 What looks wrong but is what the bytes do

- **A fleet's passenger list is not refilled while the fleet stays selected**; an air unit's is (`0x7577B0`). This
  rests on the reading, since nothing outside the panel was seen to rebuild it.
- **Every fleet and every air unit shows the capacity row**, so a battleship squadron reads "Can carry 0 weight."
  (`inferred`: the add is unconditional).
- `unmount_multiunit` posts unload commands with no port or air-base test. The single panel's `unload_button` is greyed
  outside a port; the multi-unit button is not, and its commands are refused when they are checked.
- The multi-unit load sums the **whole selection's** weight but asks `CNavy::CanCarry` about **the last unit only**. It
  posts one command per unit naming one fleet, so later commands may be refused if the fleet fills up.
- The single load button takes **the first** fleet in the port's list that can carry the unit; no choice is offered.
- The finders do not test the port pointer for null where a naval base is built.
- The orders window can tick "transport" without asking whether the transport row passed.

### C.8 Settled by the maintainer, 2026-10-15

- **A selected fleet's list goes stale**, as C.7 read it: "The unit moves onto the land province, but stays in the
  list on the ship until the unit is re-selected."
- **A warship fleet's panel reads "Can carry 0 weight."**: "Yes."

### C.9 Not settled

- What `0x4208B0` marks in a custom game (the lock).
- `0x5D36A0`, called by the passenger row's click: not read.

Frontier (rvas): `0x2208B0` (the custom-game player flag), `0x269D50`, `0x269DE0`, `0x269EB0` (the multi-unit panel's
checkbox, detach and higher-command helpers), `0x3646D0` (the `+0x1358` window test in UpdatePanels), `0x1D2A00`,
`0x1B5B50` (the objective text), `0x1D36A0`, `0x6982B0` and `0x34CE60` (the two deleting destructors).

## D. The carrier and carrying by air

Their Finest Hour's values: `PARATROOP_MISSION_ORG_REQ` 0.95 (military `+0xAC`), `PARATROOP_DROP_ORG_MULT` 0.66
(`+0xA4`), `PARATROOP_DROP_ORG_MULT_PLANE` 0.01 (`+0xA8`), `PARATROOP_MISSION_DELAY` 168 (`+0xA0`; `UNIT_ATTACK_DELAY`
is also 168), `PARADROP_PENALTY` -0.5 (`+0x18`), `PARASUPPLYPOOL_DAYS` 7 (`+0x44`; `SUPPLYPOOL_DAYS` is 15),
`PARADROP_MIN_TIME` 24 (`+0x26C`), `AIR_SUPPLY_FACTOR` 0.5 (`+0x230`), `CAG_DUTY_MINIMUM_ORG_LIMIT` 0.20 (`+0xEC`).

The units files: `carrier_size` is 2 on `carrier` and 1 on `escort_carrier`; `is_cag` is on `cag` alone.
`transport_capability` is 15 on `transport_plane` - the air file's key, loaded into definition `+0x144`, the same field
a ship's `transport_capacity` uses. `can_paradrop = yes` is on `paratrooper_brigade`, `ranger_brigade` and
`Gurkha_brigade`, all with `transport_weight` 5. A unit's weight and capability are each sums over its brigades or
wings (`FINDINGS-unitdef.md`).

### D.1 A carrier as an air base

**The order.** `rebase_to_carrier` (type 0x573) is offered by the air orders window where a ship of the province
carries aircraft (`FINDINGS-seaair.md`). `CRebaseToCarrierMission::MayBeGiven` (VA 0x593050, rva 0x193050) needs two
things:

- **`FindCarrierWithRoom` (0x4A8470, rva 0xA8470)** finds a fleet in the order's province. It looks first among the
  province's units (`CMapProvince +0x2B8`); only if that finds none, and the province has a port (`+0x354`), among the
  fleets in the port.
- **The unit** is an air unit whose every wing is a carrier air group (`CUnit_AllSubUnitsAreCag`, `is_cag`).

A fleet qualifies when it is a fleet, belongs to **the same country** as the air unit (owner id; allies' carriers are
never considered), and has a ship with `carrier_size` above nought whose room passes:

    wings already aboard (sum of regiments_count of the air units on the ship's list, CShip +0xDC)
      + the unit's own wings                                  <= carrier_size / 1000

So **a carrier holds `carrier_size` wings** (2 for a carrier, 1 for an escort carrier in Their Finest Hour), counted
per ship and not per fleet. The first fleet of the list in list order wins, and within it the first ship in the
fleet's order. Nothing asks whether the carrier is at sea or in port, about range, or about war.

**Start** (0x5930B0, rva 0x1930B0), run when the order is given:

1. The fleet is found again and its object id kept (`+0x84` type, `+0x88` id, saved as `carrier_target`).
2. The ships are walked for the first one with room.
3. The air unit leaves its old base's list, and its base (`CUnit +0x98`) becomes **the `CUnitBaseCarrier` embedded in
   that ship at `+0xD8`** - `CShip`'s constructor (0x5ADB60) builds it there with the ship at the base's `+0x18`. The
   unit goes on the ship's list (`+0xDC`).
4. `CUnit_AttachToParent` (0x5B9760) hangs the unit under the fleet in the order of battle; a fleet is level 5 and an
   air unit 6.
5. It is sent flying (`FlyToCarrier`, 0x593910).

So, as with a rebase to an airfield, **the base changes the moment the order is given**, not on arrival.

**The flight and its end.**

- **`FlyToCarrier`** paths to the province the fleet is in *now*. It judges the light at the hour of arrival the way
  the strike missions do: order `time` (`+0x30`) 0 refuses a night arrival and 1 a day arrival. With the wrong light,
  a unit in its base's province has its movement cancelled; any other unit is told to return to base, which is now the
  carrier.
- **`IsActive`** (0x593290) re-finds the fleet by id each hour. If the fleet is gone, or the unit has no base, the order
  is done. In a battle, a bombing or with a path, it goes on. When the unit **is at its own base** the order is done.
  Otherwise it re-paths after the moving fleet.
- **No range is measured at any point.** `COrder::IsTargetInRange` answers "in range" for rebase_to_carrier
  (`FINDINGS-seaair.md` section 4), and this slot 14 never calls `CAirOrder::IsActive`.
- No organisation is halved on landing, unlike `CRebaseAirOrder`.
- With the order done, `CUnit::CheckOrderAndCombat` gives a carrier-based air unit with a null order
  `CCarrierProtection` for the province it is in (`FINDINGS-seaair.md` section 3, step 3).

**What an air group aboard is.**

- **Its base province is where the fleet is.** `CUnitBaseCarrier`'s slot 0 (0x5D5570) answers the province of the
  ship's fleet (`ship+0xB0 -> +0x130`), or province 0 with no ship or fleet.
- **Its range moves with the ship.** `IsTargetInRange` measures range from that province, so an air group's reach is a
  circle about its carrier wherever the carrier is.
- **It is at its base only while the fleet is not fighting.** `CUnit_IsAtOwnBase` (0x5CDC30) is true in the fleet's
  province only while that fleet is in no battle and no bombing. Every "at base" test (the order texts, `MayLoad`, the
  missions) therefore fails while the carrier fights.
- **It moves with the carrier.** `CUnit::EnterProvince` for a fleet entering a *different* province walks every ship
  with `carrier_size` and enters into the new province each air group that has no path, is in no battle and no
  bombing, and stands in the fleet's old province or nowhere. Air groups out on a mission stay where they are and
  return to wherever the carrier has gone.
- **It is never crowded:** organisation regain and reinforcement both give it full room (`FINDINGS-organisation.md`
  section 4, `FINDINGS-unitdaily.md` section 4).
- **Its supplies** are drawn at the province of the carrier's own base (`FINDINGS-supplypass.md` section 4).
- Upgrade was not read.

**Missions from a carrier.** The window offers `CCarrierProtection` first for a unit whose base is a carrier in this
province, and the others by the unit's attack figures as for any air unit (`FINDINGS-seaair.md`). `CCarrierProtection`
returns below `CAG_DUTY_MINIMUM_ORG_LIMIT` and keeps its province at the carrier's (`FINDINGS-bombing.md` section 10).
In a sea battle, `CNavy::SendCarrierAircraft` sends idle groups under that order into combat (`FINDINGS-seabattle.md`
section 5).

**Carrier protection, read through on 2026-10-16** (decompiled from a scratch copy with the record applied):

- **Its hour** (`IsActive`, 0x5901F0): no base, done. The unit's **plain average organisation** - slot 20,
  `CUnit::GetAverageOrganisation`, the wings' organisation over their count, not a share of a maximum - under
  `CAG_DUTY_MINIMUM_ORG_LIMIT` (0.2): told to return to base. In no battle, no bombing and with no path: away from its
  base's province, told to return to base; and the order's province becomes the base's province - the carrier's.
  Always still going.
- **Whether it fights in the air** (slot 34, `WillEngage`, 0x5901A0): the same plain average at least
  `CAG_DUTY_MINIMUM_ORG_LIMIT`, and **an ordinary battle going on in the order's province** - `CMapProvince +0x2F4` is
  the count of its combat list. So a carrier's aircraft are taken into an air battle only where their carrier's
  province has a battle in it - a sea battle the carrier is in, or any other.
- **Where it bombs** (slot 17, 0x590730): the order's province alone; **it goes for ships** (slot 27). A carrier's
  aircraft bomb the enemy's fleets where their carrier is.
- **Given unasked**: `CUnit::CheckOrderAndCombat`, step 3, gives it to an air unit based on a carrier whose order is
  the null order (slot 24 false), for the province it is in.
- **Into the sea battle** (`CNavy::SendCarrierAircraft`, 0x5C7C70, decompiled): in the fleet's own hour while it is in
  a battle or a bombing, for each ship with `carrier_size` above nought, each air unit on its list under this order, in
  the fleet's province, in no bombing and no battle, with no path, and able to fight (slot 33) goes to `CheckForCombat`
  there.

**When the carrier sinks.** `CUnit::RemoveSpentSubUnits` hands the ship to `CGameState::DisposeSubUnit` (0x684CE0, rva
0x284CE0). For a ship, each air group based on it is taken off the list and has its base cleared, gets a fresh null
order, runs `CAir::CheckBase` - which gives it **the nearest of its country's air bases in a straight line** - and is
re-entered where it stands. The ship goes on a list at game state `+0x20` instead of being freed. When **the whole
fleet** is removed, `CGameState::RemoveUnit` does the same for each carrier's groups (0x685080..0x68516C) and also takes
each out of the fleet in the order of battle (`CUnit_LeaveParent`).

**Rebased to an airfield** (`CRebaseAirOrder`): the group leaves the fleet in the order of battle, takes the airfield
as its base the first hour, and lands with half its organisation (`FINDINGS-seaair.md` section 3).

**In port** nothing is special: the fleet's province is the land province, and the group is "at base" there.

### D.2 Carrying by air

**Who may board what: `CAir::MayLoad`** (0x5D07F0, rva 0x1D07F0), asked by `CLoadOnPlaneCommand::IsValid`. All of
these, in order:

1. Plane and land unit have one owner.
2. The plane is in no battle, has no path, is not retreating, and is at its own base.
3. The land unit's attack delay (`CUnit +0xD4`, save key `attack_delay`) is not running.
4. The plane's base province has an air base at a working level of at least 1.
5. **Every brigade** has `can_paradrop` and organisation x 1000 / its maximum at or above `PARATROOP_MISSION_ORG_REQ`
   (0.95) - `UW_LOAD_PLANE_FAIL_LOW_ORG`, "Our paratroops have too low organization. They need to be at 95% of their
   maximum."
6. The weight fits:

       SumTransportWeight(units already aboard)  +  trunc(land unit's transport_weight / 1000)
           <=  trunc(plane's transport_capability / 1000)

   So one transport wing (15) carries three paratroop brigades (5 each), and a larger plane unit carries in
   proportion.

**Where the land unit stands is not asked** by the command; offering only planes "here" is the screen's job (section
C; `UW_LOAD_PLANE_FAIL` "There are no transport planes here that this unit can be loaded onto.").

**Boarding: `CLoadOnPlaneCommand::Execute`** (0x5E4750). Type 0x56E, keys `unit` and `air`. For a land unit not
already aboard a plane:

1. **`CAir::Board`** (0x5D0920) sets the unit's `+0x304` (`carried_by_air`) to the plane, zeroes its `+0x2E8`, and
   appends it to the plane's list at `+0x2E4`.
2. `EnterProvince(unit, the province it is in)` leaves it where it is.
3. If it was selected, the selection moves to the plane.
4. The land unit's order becomes a null order.

**While aboard**, it moves with the plane - an air unit's `EnterProvince` enters each passenger into the same province;
it is never engaged (`CUnit::CanEngage`), not reinforced (`CanReinforce`), and shown as not free to act
(`CUnit::IsFreeToAct`); and it draws its supplies at the plane's base (`FINDINGS-supplypass.md` section 4).

**Getting off: `CUnloadFromPlaneCommand`** (type 0x56F). `IsValid` (0x5E4450) needs the unit in a land province,
aboard a plane, and the plane at its own base - `UW_UNLOAD_PLANE_BASE_ONLY`, "You can only unload at an airbase."
`Execute` (0x5E4300) is `CAir::ReleaseCarried(plane, false)`: the unit's `+0x304` and `+0x2E8` are cleared and it
leaves the plane's list, no supplies are moved, **`CheckForCombat` is called in every case**, and a selected unit's
counter is redrawn.

**Save.** A unit aboard a plane is a `division` block inside the `air` block; `CAir::LoadKey` builds it and calls
`CAir::Board`.

### D.3 The paradrop

**Giving it.** `CParadropMission::MayBeGiven` (0x590900): the province is land, nothing more. The window offers it only
to a unit that carries something, over land (`FINDINGS-seaair.md`), and moves its start to at least now +
`PARADROP_MIN_TIME` (24) hours (`FINDINGS-airorders.md` section 9). **Nothing in the order's own slots measures
range.**

**Taking off: `TakeOff`** (0x590930), from slot 13 and again every hour the unit is not over its target:

1. With no fuel, or unfit to fly (`CAirOrder::IsFitToFly`), it is told to return to base and nothing more happens that
   hour (decompiled 2026-10-16). Before its start hour a unit is never fit to fly, so it is told so every hour it waits.
2. Before the start hour, nothing happens.
3. Then, with `hostile` = the target's controller at war with the plane's owner, the plane **waits** while either
   holds: `hostile` is true and any passenger's attack delay is running; any passenger brigade is under 95%
   organisation.
4. Otherwise it is given the way to the target, with the day/night arrival test as above - **only where a way was
   found** (decompiled 2026-10-16).

**Over the target: `IsActive`** (0x590C60). The hour the plane stands in the target with no path and no battle, from
its start hour on:

1. **`CAir::DropCarried`** (0x5D0AA0), with `hostile` = the plane's owner at war with **the controller of the province
   it is in**. For each passenger in order: `was_paradropped` (`+0x97`) is set to `hostile`; where hostile,
   `CUnit::StartAttackDelay`, which uses `PARATROOP_MISSION_DELAY` for such a unit (`FINDINGS-landbattle.md` section 6);
   then `CAir::ReleaseCarried(plane, true)` - off the plane, then `CUnit::CarrySupplies(unit, province, parachuted,
   from-stockpile)`, which moves `PARASUPPLYPOOL_DAYS` (7) days of what the unit uses into the province
   (`FINDINGS-supplypass.md` section 5), then `CCombatManager::CheckForCombat` there. That starts or joins a battle
   against defenders, or **takes an undefended province at once**.
2. Every transport wing's organisation is multiplied by `PARATROOP_DROP_ORG_MULT_PLANE`: **1% is left**, floored at
   nought.
3. The plane is told to return to base.
4. The first time only (`+0x80`, saved as `message`, **set before anything is asked**, decompiled 2026-10-16), where
   **the target's controller after the drop is the player** and the plane's owner is at war with the player - so an
   undefended province the drop has just taken tells nobody - the message `PARATROOPEDUS` is raised with `ENEMY` (the owner's name) and `PROV`
   (the province's name): "$ENEMY$ is dropping paratroopers / in $PROV$." The log reads "$ENEMY$ dropped paratroopers
   in $PROV$." and the setup line is "When enemy drops paratroops on our territory."

The order ends when the plane is back at its base with nothing aboard.

**Where the supplies come from.** `CarrySupplies` takes them from the pool of the unit's previous province (`CUnit
+0x134`) where that is land, and from the stockpile only otherwise. Boarding and the plane's moves never write
`+0x134`, so a paratrooper's previous province is the land province it last walked out of. The stockpile is the
government in exile's pool for a country in exile.

**The dropped unit afterwards** (`was_paradropped`): it gets `BM_PARATROOP_PENALTY` = `PARADROP_PENALTY` (-0.5) plus
its leader's `paradrop_mission` trait, negative only (`FINDINGS-combatmods.md`); it is exempt from
`BM_LACK_OF_SUPPLIES` (`FINDINGS-combatmods.md`); `CCombat::GetCombatWidth` counts no paratrooper after the first
(`FINDINGS-landbattle.md` section 2); and **the first hour it is in no battle**, `CUnit::UpdateHourly` clears the byte
and multiplies every brigade's organisation by `PARATROOP_DROP_ORG_MULT` (0.66) - dropped into an empty province, that
is the same hour. A drop onto ground nobody is at war with sets none of this, but still moves the supplies and checks
for combat.

**Texts.** `Describe`: `PARADROP_MISSION_SHORT_DESC` "Airborne Assault ($TYPE$}" (the brace is the localisation's);
TYPE is "Resting" (`STRAT_BOMB_WAITING`) while unfit or in its base province, "Returning", "Flying" (`PARA_FLYING`) or
"Fighting" (`CAG_FIGHTING`). `GetDescription`: `PARA_MISSION_DESC` "Perform an airborne assault on a province, dropping
paratroopers on the target."

### D.4 The air supply

`CTransportSuppliesOrder` (Air Supply). **MayBeGiven** (0x595300): land, and the unit has `transport_capability`.
**Start** is a jump to `CAirOrder::UpdateBombing`, so the hour's targeting, path and light test are the strike
missions' (`FINDINGS-bombing.md` section 3). Its pick, `PickProvince` (slot 39, 0x595C40), walks the mission's area
list over provinces whose controller counts the unit's country a friend (military access counting, slot 37): the first
such province is taken, and each later one replaces it where (drawn - throughput) of fuel plus that of supplies, today,
is above nought. **So the last short province of the list wins**, and the first allowed one where no later one is
short.

**IsActive** (0x595490), each hour:

- **At the target**, the target's pool gains the supplies and fuel aboard, and cargo and target are cleared.
- **At its own base with a target**, the empty cargo is loaded, with `cap = AIR_SUPPLY_FACTOR x transport_capability /
  1000` (7.5 per transport wing):

      supplies = min(max(target.drawn.supplies - target.throughput.supplies, 0), cap)
      base_province.drawn.supplies += supplies
      supplies = min(supplies, base_province.pool.supplies);  base_province.pool.supplies -= supplies

  Fuel is loaded the same way, after the supplies.
- **At its base with a target and nothing aboard**, it waits without moving.
- **Otherwise** `UpdateBombing`, and `CAirOrder::IsActive` (with its range check) answers.

**Texts.** `TRANS_SUP_MISSION_SHORT_DESC` "Air Supply ($TYPE$)" with `TS_RETURNING` "Returning", `TS_WAITING` "Waiting"
(at base with no path) or `TS_SUPPLYING` "Flying". `TRANS_SUP_MISSION_DESC` "Deliver supplies through the air to any
troops needing them."

### D.5 Corrections to the record

1. **`CAir::ReleaseCarried`** (rva 0x1D0990): `CheckForCombat` runs on an unload too, not only on a drop (checked on
   the listing: the `CarrySupplies` call at 0x5D09F8 is behind the byte at `[ebp+0xC]`, the combat manager's call
   after it is not); and a drop's supplies are not "out of its country's stockpile" (D.3).
2. **`CUnit +0x97`** is `was_paradropped` (save token 1442). Its writer is `CAir::DropCarried` (0x5D0AF6), and it is
   read by combat width, the attack delay and two battle modifiers, not only by the organisation step.
3. **`CUnit_IsAtOwnBase`**: its third clause means the carrier's fleet is in no battle or bombing, and the carrier
   base's slot 0 is the fleet's current province.
4. **`CCarrierProtection::IsActive`** and **`WillEngage`** (2026-10-16) compare the plain average organisation with
   `CAG_DUTY_MINIMUM_ORG_LIMIT`; the record said "as a share". `WillEngage`'s `+0x2F4` is the count of the province's
   ordinary battles, which the record had left unnamed.
5. **`CGameState::RemoveUnit`** (2026-10-16): its third flag removes **an air unit's** passengers with it as well as a
   fleet's, and lets them go otherwise; its first, clear, takes the unit's officers off its owner's pool. The record
   had the flags unestablished.

### D.6 What looks wrong but is what the bytes do

- The load command never asks where the land unit stands; only the screen keeps it to the plane's province.
- `Execute` sets the land unit's null order twice.
- Boarding a plane zeroes `CArmy +0x2E8` (recorded as `ai_param_a`) alone; boarding a ship (0x5CF06C) zeroes `+0x2E4`
  and `+0x2E8`.
- A paratrooper's 7 days of supplies come from the province it last walked out of where that is land, not from the
  stockpile.
- Transport planes are left at 1% organisation after **every** drop, hostile or not.
- `PARATROOPEDUS` goes only to the player who **controls** the target once the drop is over, and once per order - so a
  player whose undefended province the paratroopers took is never told.
- Neither a paradrop nor a rebase to carrier measures range after the order is given.
- Air supply raises the base province's `drawn` by the load before capping it by the pool. It picks the *last* short
  province of the area, not the neediest, and delivers whether or not the target is still friendly.
- Only one's own country's carriers are offered or taken.
- A **sunk** carrier's air groups stay children of its fleet in the order of battle. Only removing the whole fleet
  detaches them.

### D.7 Not settled

- ~~**A transport plane destroyed with passengers aboard.**~~ **Settled 2026-10-16**: `CGameState::RemoveUnit` has an
  air branch after the fleet's, read whole on a decompile - with its third flag set each passenger is removed with the
  plane, and otherwise let go where it stands. The hourly removal drain, capitulation and annexation pass the flag set
  and the exile's clean-up passes it clear (the record's callers; `CCountry_Reset`'s not read), so
  **the paratroopers are lost with the plane**. The maintainer did not know (2026-10-15).
- **A land unit loaded while it has a path.** `MayLoad` does not test the land unit's path, and
  `CUnit::AdvanceMovement`'s carried test reads only `+0x300`. Whether a passenger keeps walking depends on whether the
  screen allows such a load (section C).
- **The technology efficiencies.** No read of `paradrop_mission` or `transport_supplies_mission` was found in the bodies
  read.
- **`CShip +0xF4`** (the carrier base's `+0x1C` byte, set to 1 by `CShip`'s constructor) gates `DisposeSubUnit`'s
  air-group arm. Its other writers were not looked for.
- **A carrier wing away from its carrier**: for the crowding term, `base->slot0()->+0x304` is then a sea province's air
  base; not checked.
- **`CUnit +0x2E4`** is recorded as `carrying` (a CList) while `CArmy +0x2E4` is `ai_param_b`. The list is really
  `CNavy`'s and `CAir`'s: `CAir::Board` and the fleet code both use `+0x2E4/+0x2E8/+0x2EC` as head, tail and count.
- **0x5CDC90** moves passengers, naval (`+0x300`) and air (`+0x304`), from one unit to another (a merge or split?). Its
  callers 0x597BB0, 0x59BC40 and 0x5DB9E0 were not identified.

Frontier: rva 0x1CDC90 (the carried-units transfer); 0x1B8170 (a `CUnit` save body that switches on oob_level and
writes `was_paradropped`); 0x2DD70 (the object-id record maker); 0x197BB0, 0x19BC40, 0x1DB9E0 (callers of 0x1CDC90);
0x1E4B40 (`CLoadOnPlaneCommand`'s copy constructor).
