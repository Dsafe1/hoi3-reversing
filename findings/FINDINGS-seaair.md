# Fleets and air units on the move: the orders window, range, ports, and the base

Read statically out of `hoi3_tfh.exe` on 2026-10-09, for the rewrite's movement of fleets and
air units. Addresses are **VAs** unless a line says rva; `rva = VA - 0x400000`. Only valid for
this build. Section 4 was checked against the cache the game wrote, cell for cell, and sections
5 and 7 against savegames an hour apart; the last section says what was not read.

**In one line.** A fleet and an air unit walk the same graph of provinces as a division, by the
same route finder and the same hourly march, at their own speeds. What differs is how they are
told to: a right click opens **a window of orders** for the province, the player picks one and
accepts, and the unit carries **an order object** that sets it on its way and is looked at again
every hour. A fleet goes between land and sea only through **a port** - a land province whose
`naval_base` position lies on a sea pixel - and only as far from its base as its `range`, set
against **a table of distances by sea** the map cache keeps; an air unit's range is set against
a straight line.

This **corrects one thing in `FINDINGS-movement.md`** (section 5 there): `CUnit::AdvanceMovement`
is not called by `CUnit::UpdateHourly`. It is called by `CUnit::CheckOrderAndCombat`, slot 31 -
section 3 here.

---

## 1. The right click

`CUnit::OrderToProvince` (slot 6, `0x5C1AD0`, `(province, bool append)`; `append` is shift) was
read for a land unit in `FINDINGS-movement.md`. The other two branches, for a unit of the
player's that no AI commands:

**A fleet** (`IsNaval`, slot 16):

    SeaConnected(province, the fleet's own)                          # section 5
        it has a path and the province is the one it is in     -> CCancelMovementCommand
        no shift, in no battle, and it is the selected unit    -> the naval orders window
        otherwise (shift, or in a battle)                      -> the sound navy_move, and
            COrder::IsTargetInRange(its order, fleet, province)
                yes -> CMoveCommand(fleet, province, clear = !append), legal_selection_projection
                no  -> illegal_selection_projection
    not connected by sea
        the province is land and coastal (template +0x22, +0xA0), the fleet carries units
        (CNavy +0x2EC), the first of them may stand in the province (slot 34), no shift, no
        battle, selected                                       -> the naval orders window
        otherwise                                              -> illegal projection, error

**An air unit** (`IsAir`, slot 17):

    in no battle and selected          -> the air orders window, whatever the shift key
    otherwise                          -> CMoveCommand(unit, province, clear = !append)
    then the sound air_move

So **shift with a right click sends a fleet straight there** with a plain move, within its
range, and a plain right click asks what it is to do there. An air unit is always asked. A land
unit whose `CInGameIdler +0x1C` object answers its slot 12 - a key held, not identified - gets
the third window, the land one (`mode 2`); otherwise the click of `FINDINGS-movement.md`.

**`CInGameIdler::OpenOrdersView`** (`0x677260`, `ret 0xC`; the mode in ECX, the idler in EDX,
then the idler again, the unit and the province on the stack): nothing where the view at
`CInGameIdler +0x160` is already of this mode (its slot 1); otherwise the old one is closed
(`0x678160`) and a new one made:

| mode | class | bytes | constructor | window of `orders.gui` |
| --- | --- | --- | --- | --- |
| 0 | `CNavalOrdersView` | 0x274 | `0x73DB50` | `naval_unit_order` |
| 1 | `CAirOrdersView` | 0x37C | `0x7400C0` | `air_unit_order` |
| 2 | `CLandOrdersView` | 0x198 | `0x73C270` | `land_unit_order` |

The land view was not read.

## 2. The orders window

### The naval one

**`CNavalOrdersView::CNavalOrdersView`** (`0x73DB50`, `(this, idler, unit, province)`, `ret 0x10`)
makes the window `naval_unit_order`, wires `accept`, `cancel`, `decrease_stance_button`,
`increase_stance_button`, `decrease_priority_button` and `increase_priority_button`, and writes
the **province's name** into `title`. It then makes one order object of each kind for the
province and hands each to `CNavalOrdersView::AddOrder`, in this order:

    CMoveOrder, CRebaseOrder, CReserveOrder, CPatrolOrder, CNavalInterceptOrder,
    CNavalSortieOrder, CConvoyRaid, CNavalTransportOrder, CNavalInvasionOrder,
    and a CConvoyEscortOrder for each convoy of the province (CMapProvince +0x38) that is the
    player's

**`CNavalOrdersView::AddOrder`** (`0x73ED80`, `(view, order)`, `ret 8`) makes a row for it
**whether or not it can be given**: an `order_entry` window appended to the list box
`orders_list`, its `name` text set from the order's slot 6, its `checkbox` added to the view's
radio group under the order's token name. Then, for every unit of the selection
(`CInGameIdler +0x1304`):

    the order is not a rebase (0x6DE) and COrder::IsTargetInRange(order, unit, province) fails
    or the order's slot 11 - "may this be given" - answers no
        -> the checkbox is disabled (its byte +0x136 cleared), and the function answers false

Only an order that passes is entered in the view's name-to-order map (`+0x224`). So **every
order is listed and the ones that cannot be given are greyed.**

Which is ticked when the window comes up:

    the unit may stand in the province (slot 34), the province's controller is not at war with
    the unit's country, it has a naval base (level > 0), and "rebase" is in the map
        -> "rebase"  -  or "transport" where the fleet carries units
    else, where the move could be given
        -> "move_order"

`0x73EC40` runs when the tick changes: the view's current order (`+0x220`) is destroyed and a
new one made by `CreateOrder(token of the ticked name, province)`. Slot 2 (`0x73E810`), the
view's update, enables `accept` only while a row is ticked (`+0x13C`).

**Accept** (`0x73E8E0`): for every unit of the selection that is naval, a
`CSetOrderCommand(unit, the order's token, province id, the hour the window was opened, null)`
with the view's stance copied in, posted to the session; the window then closes (`+0x30`
cleared). **Cancel** (`0x73EC30`) only closes it.

**Stance and priority** are two numbers of the view. Stance (`+0x20C`) is 0, 1 or 2 -
`STAN_AGRESSIVE`, `STAN_DEFENSIVE`, `STAN_PASSIVE` (`0x5871F0`) - shown in `stance_value`, the
two buttons stepping it down and up and wrapping (`0x73F4E0`, `0x73F500`). Priority (`+0x208`)
is 0 to 4, shown as the number in `priority_value`, wrapping likewise (`0x73F370`, `0x73F390`).
Both start at 0 and are copied into every order of the list that takes them (`0x73F530`,
`0x73F3C0`).

**Tooltips** (slot 6, `0x73F660`): on `accept`, `OV_NO_VALID_ORDER` with no order or
`OV_OUT_OF_RANGE` where the order's slot 8 says so; on a row, the order's description
(`OrderMissionIndexToDescription`) and, out of range, `OUT_OF_RANGE` with `MYRANGE` and
`RANGE`; on the stance and priority elements `OV_STANCE` and `OV_PRIO`.

### The air one

**`CAirOrdersView::CAirOrdersView`** (`0x7400C0`) is the same idea with more controls - the
target shape buttons, three sliders, day and night, the two date widgets - and builds its list
in **`CAirOrdersView::BuildOrders`** (`0x746260`, `(view, unit, token of the order to keep)`,
`ret 0xC`), each row through `CAirOrdersView::AddOrder` (`0x742C60`). Unlike the naval list,
**an order is offered only where the unit could ever fly it**:

| order | offered where |
| --- | --- |
| `CAirPatrol`; with `CCarrierProtection` first for a unit whose base is a carrier in this province | the unit's definition has `+0x140` (air attack) |
| `CAirInterceptOrder` | the same |
| `CParadropMission` | it carries units, and the province is land |
| `CRebaseToCarrierMission` | a ship of the province carries aircraft |
| `CNukeMission` | the country has a bomb, the unit has `+0x17C` (strategic attack), land |
| `CTransportSuppliesOrder` | the unit has `+0x144`, land |
| `CStrategicBombOrder`, `CBombLogisiticsOrder`, `CBombRunwayOrder`, `CBombInstallationOrder` | `+0x17C`, land |
| `CGroundAttackOrder`, `CAirInterdictionOrder` | land, and `+0x134` or `+0x138` (soft or hard attack) |
| `CPortStrikeOrder` | `+0x168` (sea attack), land |
| `CNavalStrikeOrder`, `CAirConvoyRaid` | `+0x168`, sea |
| `CAirReserveOrder`, `CRebaseAirOrder` | **land** |

**There is no `CMoveOrder` in it**: an air unit is sent somewhere to stay only by changing its
base. The row ticked at first is `rebase_air` where the unit may stand in the province, its
controller is not at war with the unit's country, it has an air base and the rebase could be
given; otherwise one of the missions by a ladder of tests that was read only as far as its
first rung.

### An order's name

`COrder` slot 6 (`0x587980`) is `OrderMissionIndexToKey(OrderTypeToMissionIndex(type))`, both
already recorded: `MOVE_ORDER`, `ORDER_REBASE`, `ORDER_RESERVE`, `ORDER_PATROL`,
`ORDER_INTERCEPT`, `ORDER_SORTIE`, `ORDER_CONVOY_RAID`, `ORDER_TRANSPORT`, `ORDER_INVADE`,
`ORDER_CONVOY_ESCORT`, and for the air `AIRSUP`, `INTERCEPT`, `ORDER_AIR_REBASE`,
`ORDER_AIR_RESERVE` and the rest. That the text box then looks the key up is `inferred`: the
localisation has every one of them.

## 3. The three orders that only send a unit somewhere

An order holds its unit at `+0x8` and its province at `+0xC`. The slots read:

| slot | | `CMoveOrder` (type `0x255`) | `CRebaseOrder` (`0x6DE`) | `CRebaseAirOrder` (`0x574`) |
| --- | --- | --- | --- | --- |
| 8 | in range | `0x587F00`: a fleet by `COrder::IsTargetInRange`, anything else yes | `CNavalOrder`'s `0x59B1D0`: `IsTargetInRange`, which says yes to a rebase | yes |
| 11 | may be given | `0x587A80` | `0x59B1F0` | `0x595CE0` |
| 13 | start | `0x587B00` | `0x59B270` | `0x595D80` |
| 14 | still going | `0x587C60` | `0x59B340` | `0x595D90` |
| 15 | what the panel says | `0x587D70`: `MOVE_ORDER_D` with `WHERE` the province | `CNavalOrder`'s `0x59AD90`: the mission's key, ` :`, the province | `0x595F70`: `ORDER_AIR_REBASE_SHORT_DESC` with `PROV` |

**May it be given** (slot 11):

    CMoveOrder      a land unit: in no battle, and the province it is in has an edge to this one
                    any other:   COrder::IsTargetInRange(order, unit, province)
                    and then the unit's slot 35, CanMoveTo(province)
    CRebaseOrder    the unit is in no battle; the province has a naval base (level > 0);
                    CanMoveTo(province); and the province's controller counts the unit's
                    country a friend (CCountry::IsFriend)
    CRebaseAirOrder the province's controller is not at war with the unit's country and counts
                    it a friend; the province has an air base (level > 0); its owner area's
                    slot 0 says yes

A change of base asks nothing of the range, and an air unit's not even whether the unit may fly
there.

**Start** (slot 13), run by `CSetOrderCommand` the moment the order is given, where the hour is
not before the unit's `+0xCC`:

    CMoveOrder      0x587BD0: CPathFind::Find(unit, where it is, province); found -> SetUnitPath(clear)
    CRebaseOrder    0x59B490: the same, and SetUnitPath whether or not a way was found
    CRebaseAirOrder 0x5961E0: only for a unit with no path and in no battle; found -> SetUnitPath

**Still going** (slot 14), asked every hour; false ends the order:

    CMoveOrder      the unit is in the province                      -> done
                    from its start hour on: at that hour, start again; later, no path left -> done
    CRebaseOrder    no base, or CNavalOrder's own slot 14 says no    -> done
                    the unit's base is not this province             -> CUnit::SetBase(the province's naval base object, +0x58)
                    the unit is in the province                      -> done
                    from its start hour on: at that hour, start; later, no path left -> done
    CRebaseAirOrder no base                                          -> done
                    the unit's base is not this province: a unit based on a carrier leaves it
                    (0x5B9A30), and CUnit::SetBase(the province's air base object, +0x54)
                    the unit is in the province: **every wing's organisation is halved**
                    (org * 1000 / 2000, not under 0)                 -> done
                    from its start hour on: start (which does nothing while it has a path);
                    no path and no battle                            -> done

So **the base changes the first hour the order is looked at**, not on arrival - a savegame shows
it: an air unit seventeen provinces short of its new airfield already has `base=` that province.
And **an air unit lands at a new base with half its organisation**.

`CUnit::SetBase` (`0x5CDBE0`, the unit in EDI, the base object on the stack, `ret 4`) takes the
unit out of its old base's list of units, stores the new base at `CUnit +0x98` and adds the
unit to the new one's list (`0x5D5520`).

**The base object** is a `CUnitBaseProvince` (RTTI; a `CUnitBase` with a `CSelectable` at
`+0x18`) or a `CUnitBaseCarrier`. Slot 0 answers the province, slot 1 whether it is a carrier.
A province has two: `CMapProvince +0x54` for air units and `+0x58` for fleets. Each keeps a
list of **the units based there**, wherever they are.

**`CSetOrderCommand::Execute`** (slot 6, `0x5E1F90`): after the command's own slot 14 agrees,
the unit's `+0xCC` and `+0xD0` take the command's two dates, `CreateOrder(token, province)`
makes the order, its target, stance, dates, `time` and `stop` are filled in - a `stop` of zero
or less becomes `AGGRESSIVE_`, `DEFENSIVE_` or `PASSIVE_ORGANISATION_LIMIT` by the stance - the
unit's old order is deleted, the new one installed at `+0xB0`, and its slot 13 is called.

### The hourly driver, and a correction

`CUnit::CheckOrderAndCombat` (slot 31, `0x5BA2F0`) is already recorded as the one caller of an
order's slot 14, and `RunCountryHourlyPass` as its one caller: **once an hour, on the tick
thread, for every unit of every country in turn, before any unit's `UpdateHourly`.** Read
through, in order:

1. the two "estimate is stale" bytes are set and `0x5CB630` is called;
2. `order->slot14()`; false: the unit's two dates `+0xCC` and `+0xD0` go to null and its order
   becomes a null order;
3. an air unit whose order's slot 24 is false and whose base is a carrier gets order `0x56C`
   for the province it is in;
4. an air unit away from its base: with less strength in all than `floor(1.5)` it is removed;
   with a base and its slot 26 figure under that, it is given a `CMoveOrder` to its base's
   province unless it has one;
5. a unit in a battle is given experience;
6. a land unit with a path looks for a battle in the next province (`CheckForCombat`) under
   the tests of `FINDINGS-movement.md`;
7. dig-in is cleared for a unit with a path, or of a country at peace; the battles it is no
   longer beside are left; the attack delay runs down;
8. **with a path: `CUnit::AdvanceMovement(unit, true)`, and then `AdvanceMovement(unit, false)`
   for as long as it answers true** (`0x5BAB26`..`0x5BAB3A`);
9. a stale avatar is rebuilt;
10. with no path, not retreating and in no battle: `CheckForCombat` in the province it is in;
11. the unit's slot 18 (below), and two counters at `+0x9C` and `+0xA0` go down by one.

**`FINDINGS-movement.md` says `CUnit::UpdateHourly` calls `AdvanceMovement` near its end. That
is wrong**: `0x5BAB26` lies in this function, which starts at `0x5BA2F0`; `UpdateHourly` is the
function before it. Two things follow. **A unit moves before its organisation is seen to, not
after**, since every unit's slot 31 runs before any `UpdateHourly`. And **movement is not on
the worker threads**: it is serial, country by country in the order of the country vector, each
country's units in the order of its own list - so it has an order, where that write-up's reader
concluded it had none.

Slot 18, the last step: `CNavy`'s (`0x5D01B0`) does nothing while the fleet's base is held by
no enemy of its country; otherwise the fleet leaves that base and takes the nearest by sea of
its country's naval bases, then of its faction's, and with none at all and no port left to its
country it is removed. `CAir`'s (`0x5D0E20`) gives a unit with no base the nearest of its
country's air bases in a straight line.

## 4. Range, and the distances by sea

**`COrder::IsTargetInRange`** (`0x5CE0A0`, already recorded; the order in EAX):

    the order is rebase_air, rebase_to_carrier or rebase          -> in range
    the unit has no base (+0x98)                                  -> in range
    a fleet:   range < NavalDistance(base province, province)     -> out of range
    an air unit: range < CMap::DistanceBetweenProvinces(base, province) * 1000 -> out of range

`range` is the unit definition's `+0x148`, which `CUnit::RebuildDefinition` keeps as the
smallest among the unit's ships or wings (`FINDINGS-unitdef.md`).
`CMap::DistanceBetweenProvinces`, already recorded, is four times the pixels between the two
bounding-box centres, the short way round the map, rounded down - so **a range is in quarters
of a pixel**, and an air unit's reach is a circle about its base.

**`CMapProvince::NavalDistanceTo`** (`0x4A5570`, `(this, out, province id)`, `ret 8`; the same
arithmetic is inline in `IsTargetInRange`):

    a = the province's sea index (CProvinceTemplate +0xAC); below zero, that of the sea
        province it names (+0xA4)
    b = the same for the other
    either still below zero                -> 0        (floor(0.0005 * 1000))
    i, j = the smaller and the larger
    table[(N - 1) * i - (i - 1) * i / 2 + j] * 1000

with `N` at `CMap +0x2A6C` and the table of 16-bit numbers at `CMap +0x2A70`: the upper
triangle of an N by N table, the diagonal included, row by row.

**Who has a sea index.** `CMap::LoadPositionsFile` zeroes `N` and reads `positions.txt`. For
every `naval_base` position it meets, `CMap::LoadBuildingPositions` (already recorded for the
store of the position) goes on:

    q = the province the pixel (int)x, (int)y of the position belongs to
    q is land: the pixels east, north-east, north and the pixel itself are looked at in turn,
               each lookup overwriting the last - and the last is the pixel itself again, so
               nothing comes of it
    q is sea, and not MapProvinceIsLandlockedWater(q):
        the land province's +0xA4 (sea_province_id) = q
        a CPort is made for it (CMapProvince +0x354; 0x1C bytes, its +0x18 the sea province)
        its sea index = N, and N goes up by one

and when the file is done every province from 1 up that is sea, has no index yet and is not
landlocked water takes the next. So **the ports come first, in the order `positions.txt`
names them, and the sea provinces after, by id** - and **a land province has a port exactly
where its `naval_base` position lies on a pixel of a sea province**. The four-pixel walk looks
like a search for water next to a position on land that was meant to stop at the first hit and
does not.

`MapProvinceIsLandlockedWater` (already recorded) is true for a sea province all of whose
neighbours are land, and at once for one whose template byte `+0x14` is set. **That byte is
"listed under the continent `lake`"**: `CMap::AssignContinents` (`0x48F260`), going through
the continents of `continent.txt`, stores the continent at `CMapProvince +0x368` for a
province that has none yet and sets `+0x14` where the continent's name is `lake`. Their Finest
Hour lists four provinces there.

**`CMap::BuildNavalDistances`** (`0x48D9F0`, the map in ECX) allocates the table, and unless
the cache is stale reads it from `map/cache/navaldist.bin` (`CMap::LoadNavalDistances`,
`0x48D7F0`). Otherwise the table is zeroed and, for every province with an index, in the order
of the province ids:

    dist[every index] = 1e7;  dist[own] = 0;  queue = [the province]
    while the queue is not empty:
        p = the first of the queue;  d = dist[p]
        for each edge of p, in order, to a province q that has an index:
            n = d + CMap::DistanceBetweenProvinces(p, q)
            n < dist[q]:
                dist[q] = n
                table[own, q] = n cut to 16 bits
                q goes on the end of the queue

and the table is written to the file. So a step is **the straight line between the centres of
two adjoining provinces**, a distance is the shortest sum of steps, and **the places of the
table are the ports as well as the seas**: a port is joined to every sea province it borders
and to every port it borders, which lets a way by "sea" cross a neck of land where two ports
touch. A pair with no way between them keeps the zero the table started with, and so reads as
**no distance at all, in range of everything**.

### Checked against the game's own cache

`tfh/map/cache/navaldist.bin` is 35,242,032 bytes: 17,621,016 cells, the upper triangle of a
table of 5,936. The rewrite builds the indices and the table from the map files by the rules
above and its `OpenHOI3.SaveCheck navaldist` compares (2026-10-09, Their Finest Hour):

| | |
| --- | --- |
| places of the table | 5,936 here and there: 2,406 ports and 3,530 sea provinces, 17 lakes left out |
| distances | **17,621,016 of 17,621,016 agree** |
| pairs with no way between them | 23,735 |

So the port rule, the numbering and its order, the two kinds of lake, the step and the search
are all `confirmed` by the game's own output. With the lakes taken by their neighbours alone
the table came to 5,941; the `lake` continent accounts for the five.

## 5. Where a fleet and an air unit may go

`CPathFind::Find` and the hourly march are those of `FINDINGS-movement.md`. What is the
fleet's own:

**`CNavy::MayStandIn`** (slot 34, `0x5CEE70`):

    a land province: it must have an owner, a CPort (+0x354) and a naval base (level > 0);
                     its controller must be no enemy of the fleet's country
                     (CCountry::IsEnemy), the fleet's country must count the controller a
                     friend (CCountry::IsFriend), and its owner area's slot 0 must agree
    WaterIsClosed(province)                                          -> no
    then the base rule, CUnit::MayStandIn

**`WaterIsClosed`** (`0x4A7E30`, the province on the stack, the country's tag in ESI,
`ret 4`): the defines' `map` section is five pairs, a sea province and a land one -

    SUEZ / SUEZ_BLOCKER, PANAMA / PANAMA_BLOCKER, BALTIC / BALTIC_BLOCKER,
    BLACKSEA / BLACKSEA_BLOCKER, GIBRALTAR / GIBRALTAR_BLOCKER

- and the province is closed where it is one of the five sea provinces and the controller of
its blocker is an enemy of the country. So **a canal or a strait is a sea province a fleet may
not be in while an enemy holds one named land province.**

**`CPathFind::MayStep`**, for a fleet, before it asks slot 34 of the province stepped into:

    land to land                                      -> no
    sea to land: the land's sea_province_id (+0xA4) must be the sea stepped from
    land to sea: the land's sea_province_id must be the sea stepped into; and then, where the
                 fleet may not stand in the land it is leaving, the step is allowed outright

A fleet enters and leaves a port **only through the one sea province the port opens onto**,
whatever else the land province borders; and it can always put to sea from a port it has lost.

**`SeaConnected`** (`0x4A7D70`; one province in ECX, the other in EAX, the country's tag on the
stack, `ret 4`), which `CPathFind::MayUse` asks of a fleet's goal, the click asks first, and
`CUnit::CanMoveTo` asks last: each province that is land with a port is replaced by its sea
province; **both must then be sea**; and `0x4A7F80` must agree both ways. That one compares
the first region of each province (`CMapProvince +0x358`) with three regions kept in globals -
the Black Sea, the Baltic and the Mediterranean - and says no where the only ways between the
two are closed waters: out of the Baltic with `BALTIC` closed, out of the Black Sea with
`BLACKSEA` closed, between the Mediterranean and the rest with both `GIBRALTAR` and `SUEZ`
closed. It is a shortcut for a search that would fail anyway.

**`CUnit::CanMoveTo`** (slot 35), for a fleet, after the tests it shares: `SeaConnected`, and
**none of the units it carries (`CNavy +0x2E4`) may be on the move itself**. `CAir::CanMoveTo`
(already recorded) first refuses a province whose cloud cover is at or over
`ALLOWEDTOFLYTHRESHOLD`.

An air unit has no slot 34 of its own: it flies over whatever the base rule lets its country
into - the sea, its own ground and a friend's, ground at war with it - and **not over a
neutral's**.

## 6. Ports and airfields on the map, and how a docked fleet is picked

**A building's picture.** The map's graphics owner - the object `CInGameIdler`'s slot 15
answers - keeps one object per province id in an array at its `+0x1DF0`: the province's
graphics. `0x63F790` (`(province graphics, province, graphics owner, country)`, `ret 0x10`)
keeps that province's map pictures up to date. Besides the `capital` marker, for every
building of the province from index 1 up (`CMapProvince +0x310`):

    shown where: the template's +0x13D is set, the building's level (+0x20) is above the fixed
    point at 0x1A870F4, the building type's byte +0x94 is set (onmap), and either the player
    knows the province at all (its intel byte is not 0) or the type's +0x95 is set (visibility)

    made, where shown and not there yet: the billboard type named "building_" + the building's
    name, placed at the building's position (CProvinceTemplate +0x258[index]) less the label
    point, raised by the building's nudge (+0x268[index]); a building type with +0xDD set
    (port) whose position is more than the constant at 0x15BED10 east of the naval base
    position has the byte +0x14A set on its picture

The pictures are kept at `province graphics +0x40`, by building index; two more at `+0x7C` and
`+0x80` are the `large_air_base` and `large_naval_base` ones.

**Its frame.** `building_naval_base` and `building_air_base` have two frames.
`UpdatePortPicture` (`0x6400E0`, `(province graphics, province)`, `ret 8`), for a province
with an owner, a `CPort` and a naval base: frame 1 where **the port's list of units is not
empty** and the player's intel of the province is above 1, else frame 0 - on the building's
picture and on the large one alike. `UpdateAirBasePicture` (`0x6402A0`): frame 1 where some
unit of the air base object's list `CUnit_IsAtOwnBase`, with the same intel test.
`CUnit::EnterProvince` calls the one or the other for the province a fleet or an air unit
leaves and for the one it enters.

**In port.** `CUnit::EnterProvince` puts a fleet that is in a land province at the province's
naval base position and an air unit at its own base at the air base position - or the naval
one where its base is not the province's air base object - (slot 30: `CNavy::GetPosition`
`0x5CEF70`, `CAir::GetPosition` `0x5D2E20`), and calls the avatar's slot 14, which is what
keeps such a unit's counter off the map. `0x4A5A30`, which enters a unit in the province's own
lists, adds a fleet in a land province to the `CPort`'s list (`CPort::AddUnit`, `0x493E10`) and
logs `Navalunit ... placed in non port` where there is no port; `0x4A5D10` takes it out again.
So **the port's list is the fleets lying there now**, and the air base's is the units based
there.

**The click.** `0x640F40` (`(graphics owner, province graphics, mouse, selection)`, `ret 0x10`) is the
hit test of one province's pictures. A hit on the large air base picture offers the air base
object's selectable (`+0x18` of the object at `CMapProvince +0x54`), one on the large naval
base picture the `CPort`; among the counters and building pictures (two bits of the settings
word at `+0xEC`/`+0xF0`, `0x800` and `0x20`, switch the two kinds) a building picture offers
the `CPort` for a naval base, the air base's selectable for an air base, and the building
itself for any other.

**`CPort::OnSelected`** (slot 4, `0x493E80`, `(this, selection)`, `ret 4`): the port takes
itself out of the selection again, and then

    no unit in its list         -> nothing
    one                         -> that unit is selected (CSelectable_Select, 0x4AD620)
    more: the first unit goes to the end of the list; every unit that is not the player's goes
          to the end after it, in order; and the unit now first is selected

**Each click on a port picks the next of the player's fleets in it.** The air base's
(`0x5D56D0`, slot 4 of the `CSelectable` at `+0x18`) is the same turn of the list, and selects
only where the unit that comes up is the player's. `CPort`'s slot 3 (`0x4940C0`) is its
tooltip - `PORT`, the first unit's own, and the ships there against the base's capacity - and
its slot 7 answers the name `port`.

## 7. Checked against savegames

Three saves of one unmodded game, 8 January 1936 at 03:00, 06:00 and 07:00, which the
maintainer made with a submarine flotilla sailing from Kiel for Königsberg and an air fleet
changing its base to Königsberg; the AI has some fifteen more fleets under way. The rewrite's
`OpenHOI3.SaveCheck march` gives every fleet and air unit that has a `path` in the earlier
save its ships or wings, its `fuel`, its `location`, its `path` and its `movement_progress`,
moves it hour by hour by `FINDINGS-movement.md`'s march, and sets it against the later save:

| saves | the province it is in and the path left | `movement_progress` to the thousandth |
| --- | --- | --- |
| 06:00 to 07:00 | 17 of 17 fleets, 1 of 1 air units | 17 of 17, 1 of 1 |
| 03:00 to 06:00 | 17 of 17 fleets | 17 of 17 |
| 7 January 22:00 to 8 January 02:00 | 12 of 12 fleets | 12 of 12 |

- **The speed** is `maximum_speed * modifier / 1000` and then times `NAVAL_SPEED_MODIFIER`
  (0.5) or `AIR_SPEED_MODIFIER` (0.3), as that write-up has it, with the fuel term for a fleet
  and none of the land terms. The maintainer's submarines gain 5.75 an hour.
- **The air unit crosses six provinces in its hour** - 5.1 along one edge at 06:00, 6.7 along
  the seventh at 07:00 - which is `AdvanceMovement` answering true and being called again
  with what was left over, province after province. That loop had only ever been read.
- **The route**: for all 17 fleets and the air unit, `CPathFind::Find` as read, with section
  5's rules, finds from `location` to the path's end exactly the `path` the save has. The air
  unit's seventeen provinces run over land and sea alike.
- **The base**: the air unit's `base=` is already the province it is flying to, and its order
  is saved as `rebase_air` with `province=` that province.
- **Range**, for what it is worth: 14 of the 17 fleets are bound for a province within their
  `range` of their base by the table of section 4. The three that are not are transport
  flotillas of the AI's, under orders that were not read.

## What was not read

- **`CLandOrdersView`**, and which key opens it.
- **`COrder::IsTargetInRange`'s order at the shift click**: the decompilation loses EAX at
  `OrderToProvince`'s call; taken here to be the unit's own order.
- **The air view** past its list: the sliders, the target shapes, the date widgets, and the
  ladder that picks the first tick among the missions.
- **`CNavalOrder`'s slot 14** (`0x59B070`), which `CRebaseOrder`'s asks first: it reads the
  order's `+0x28`, `+0x2C` and `+0x34` and was not made out. And the two dates a
  `CSetOrderCommand` carries, of which the window sends the hour it was opened and null.
- **`CSetOrderCommand`'s own test** (its slot 14), and its other constructor.
- **`0x5CB630`**, called at the top of every unit's hour and after a fleet's click: it frees
  or remakes an arrow at `CUnit +0x190` towards a province `0x5CB830` picks, for the player's
  units and his allies'. Probably the arrow to a mission's target.
- **The owner area's slot 0**, still.
- **Of the building pictures**: what `+0x14A` does to one (a mirrored picture is a guess), the
  `orientation` key of a coastal fort, at what distance the large pictures replace the small,
  and the order two overlapping pictures are tested in - `buildings.txt` says in a comment
  that it is the order of that file.
- **What an air unit's slot 26 figure is**, which sends it home in step 4 of section 3.
- **`0x4A7F80`** beyond what section 5 says, and where the three regions' globals are set.
