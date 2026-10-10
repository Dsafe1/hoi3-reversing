# Convoys as supply uses them: made, routed, manned, run - and the supply map mode

Read out of the executable on 2026-10-10 for OpenHOI3's third piece of supply, with the
maintainer's start-date savegame (`Germany1936_01_01_00.hoi3`, 261 convoys) as the oracle for
what the reading predicts. Addresses are virtual, based `0x400000`. Nothing here needed a
running game.

`FINDINGS-convoys.md` has the delivery, the efficiency and the raid; `FINDINGS-supplypass.md` has
the daily pass the deliveries feed. This is what neither had: **who makes a convoy and when, the
route it is given, how a country's transports and escorts are shared out among its convoys, what
a new game gives for nothing, where the production of land cut off from the capital goes**, and
the colours and the tooltip of the supply map mode.

## 1. Corrections to what was written before

- **`AreaSupplyAndFuelHeadroom` sums over ports, not over the area's provinces.** It walks the
  destination's **supply group** (`COwnerArea +0x70`), each area of it, and each area's **port
  list** (`+0x48`): the ports' `drawn` supplies and fuel and the ports' `pool` supplies and fuel.
  `FINDINGS-convoys.md` said "its provinces". So the room a network has for a shipload is counted
  at its harbours only.
- **And it has a second case nobody wrote down.** After the sums: where the destination is not
  its own depot (`id != supply_depot_id`), its area is a real one, and that area is the area of
  the **loading country's** acting capital, both answers are replaced by
  `NavalBaseCapacity(destination)`. A convoy to a harbour of the home area that is no depot is
  limited by the harbour and not by what the network holds.
- **`CConvoy::ClearPath` (`0x4C6930`) rebuilds.** It takes the convoy off every province and area
  of the old path, frees the list, and then calls the path search (section 3) and writes the new
  path, registering the convoy at each province of it. The name is now `CConvoy::RebuildPath`.
- **`CConvoy::IsRouteUsable` is read whole** (section 5); it was `likely` on its entry
  conditions.
- **The supply map mode writes map style 9**, not 6: `mov dword ptr [eax+0xF4], 9` at `0x667074`,
  with the layer mask `0xFFBA`. `FINDINGS-mapmode.md`'s table of styles had 6 for it. And
  `0x666EE0` is the mode's **setter**; the colouring loop it calls is `0x8669B0` (section 9).

## 2. Who makes a supply convoy: `CCountry::MaintainSupplyConvoys` (`0x4FDF40`)

One stack argument, the country; `ret 4`. Nothing is done for a country with **one area and no
convoy**, nor for one whose acting capital is in no area.

**Making**, not in arcade mode. For every area `A` of the country (`CCountry +0xD30`) that is not
the capital's area and has provinces:

    D = provinces[ DepotOrAreaPort(A's first province) ]              0x4A6FC0, below
    skip A where D is province 0 or is sea
    need  = max(D.drawn.supplies, D.drawn.fuel)                        today's `drawn`
    found = false
    if need > 0:
        for each convoy c ending in A (COwnerArea +0x14..+0x18) that is the country's and
        carries supplies or fuel and is neither trade nor lend-lease:
            need -= NavalBaseCapacity(provinces[c.end])
            if provinces[c.end] == D: found = true
    while need > 0  or  (not found and the country is not at war):
        best = 0, port = none
        for each port p of A (COwnerArea +0x48), in list order:
            skip p where a supply convoy of the country's already ends at p
            score = p.supply_depot_hops x 1000,  or 100000.000 where p is D
            if score > best: best = score, port = p
        if no port: stop
        from = provinces[ NearestPortTo(port, the capital's area, the country) ]   0x47E5E0, section 4
        if from has no owner, no CPort, or a naval base with no maximum level: stop
        CreateConvoy(country, from, port, supplies)                    0x4FD2E0, section 6
        need -= NavalBaseCapacity(port)
    remember need for A                                                a map local to the call

Three things follow from the loop's test, and the save shows each:

- **`found` is never set inside the loop.** A country at peace with no convoy to the depot itself
  therefore goes on until every port of the area has a convoy - the depot first, then the ports
  **furthest** from it. That is why a save's convoys end at ports, several to a network, and why
  Holland has sixteen to the East Indies.
- **A port at the depot's own distance of nothing that is not the depot is never chosen**: its
  score is 0, and 0 is not above 0.
- **A country at war makes only what the day's `drawn` asks for.**

`DepotOrAreaPort` (`0x4A6FC0`, province in EDI): the province's `supply_depot_id` where that
depot's controller is the province's own; otherwise the id of the first port of the province's
area, or 0 where the area has none.

**Unmaking**, only with a game on screen (`in_game`). For every supply convoy of the country's
whose `start_date` is **four or more days** back:

    E = its end, S = its start, d = DepotOrAreaPort(E)
    it is kept where all of these hold:
        not arcade mode;  E.controller is the country;
        provinces[d].drawn has supplies or fuel above nothing;
        E.area is the capital's area  or  E.area != S.area;
        S.area is the capital's area;
        and one of:  E is d;  the need remembered for E.area is not negative;
                     -need < 2 x NavalBaseCapacity(E)               the 2 is floor(2000.5f)
    otherwise it is taken off the country's list, its transports and escorts go back to the
    country's free ones (`+0xB0`, `+0xB4`), and it is destroyed.

So a convoy goes when its end has changed hands, when nothing was asked of the depot it serves,
or when the area has room to spare of twice its harbour.

## 3. The route: `FindConvoyPath` (`0x5A1F50`) and its heap

`FindConvoyPath(from, to, out list, owner's tag)` - four stack arguments. It is a best-first
search over provinces with a `CDynamicHeap<CProvincePathNode>`, each node
`{ province, f, g, parent }`:

    visited[from] = true;  push { from, 0, 0, none }
    loop: pop the node with the least f
        if it is `to`: walk the parents back, done
        for each edge of its province's template (+0x90..+0x94, 0x14 bytes each), in order:
            skip an edge of kind 3
            q = the province across
            q must be `to`, or sea that is not landlocked water and is simulated
            skip q where WaterIsClosed(q, the controller of `from`)      the five straits and canals
            skip q where visited[q]
            cost = the edge's distance (+0xC)
            if today - day(the popped province's last_convoy_attack) < 5: cost = cost x 5
            if HasEnemyNeighbour(the popped province, owner):            0x4A6920
                m = 8.000, or 13.000 + 2 x its naval base's maximum level where it has one
                m += 5.000 + 2 x its air base's level where it has an air base
                cost = cost x m
            if cost >= 0:
                h = IntegerSqrt(dx^2 + dy^2) x 1.25                      centres, the short way round; floor(1250.5f)
                push { q, g + cost + h, g + cost, the popped node }
            visited[q] = true

**A province is settled the first time a step reaches it**, as in a unit's search
(`FINDINGS-movement.md`), so the route is not always the cheapest. The cost multipliers read the
**popped** province, not the one stepped into. `HasEnemyNeighbour`: any edge not of kind 3 to a
simulated province whose controller is another country and an enemy of the owner. The result is
`from`, the sea provinces, `to` - the search hands back the list without its first element and
`RebuildPath` puts the start in front.

**The heap is an ordinary binary heap kept as a tree of nodes** `{ item, left, right }` with a
count and the size of its last full row:

- **push** (`0x5A30E0`, heap in EAX, item in EDI; `0x5A3140` does the descent): the new item goes
  to position `count` of the complete tree - the bits of the count below its top one say left or
  right at each level - and on the way back up each child is exchanged with its parent where
  `child.f < parent.f`. That is a sift-up with a strict test.
- **pop** (inline in the search): the last position's item is taken out (`0x482050`), the root's
  item is the answer, and the taken one is sifted down from the root (`0x5A31C0`): the left child
  is the candidate where `left.f <= right.f`, the right one otherwise, and it moves up only where
  its `f` is **strictly less** than that of the item coming down.

So of two nodes with one `f` the order they come out in is the heap's and not the order they went
in, and an implementation has to be a binary heap with these two tests to give the same routes.

## 4. The home harbour: `COwnerArea::NearestPortTo` (`0x47E5E0`)

Province id in ECX, area in EDX, the country's tag (two dwords) on the stack; `ret 8`. With `T`
the sea province the target's port opens onto (`path_node +0xA4`): of the area's ports, in list
order, the one whose own port-sea is `SeaConnected` with `T` for the country and for which
`CMap::DistanceBetweenProvinces(that port-sea, T) x 1000` is **smallest**, the first of equals -
a straight line between the two **sea** provinces, four times the pixels, not a distance by sea.
0 where the area has no port, the id is 0, or none is connected.

**"The first port" of an area is its largest.** The area's port list is not in the order of its
provinces. `COwnerArea::RefreshBases` hands each port to `PortList_InsertByLevel` (`0x481AA0`),
which walks the list **from its tail** and puts the new port behind the first one it meets whose
level is **not smaller**; where every one is smaller it goes to the front. So the list is kept
by level, largest first, and of two alike the one met first in the area's province order stays
ahead. The level is `CMapProvince::UsableNavalBaseLevel` (`0x4A7EE0`, province in EAX, out in
EDI): the naval base's **current** level - or 0 for a port on one particular sea region
(the global at `0x1A8558C`) while `WaterIsClosed` says the strait into it (the third pair of
the defines' `map` block) is shut to the province's owner. The air base list is kept the same
way by `AirBaseList_InsertByLevel` (`0x481B90`), by whole levels.

This decides three things read above and below: which harbour `NearestPortTo` takes of two at
one distance, which harbour a block's resources wait in (section 8), and where
`DepotOrAreaPort` counts a need. **The save shows it**: with the ports in province order 212 of
its 261 convoys came out of the rewrite's replay, and with them in this order all 261 - San
Diego and not Los Angeles for the Pacific, Alexandria and not Tel Aviv for Egypt's resources,
Bombay and not Karachi for India's.

## 5. `CConvoy::IsRouteUsable` (`0x4C7A10`) and `CConvoy::IsPathBroken` (`0x4C7670`)

`IsRouteUsable` (convoy in ESI) is false where either end has no controller; false for a convoy
that carries neither supplies nor fuel (or is trade or lend-lease) whose ends are in one area;
then

- a trade or lend-lease convoy: false where the controller of either end is an enemy of the owner;
- any other: each end's controller must be the owner or a country whose overlord is the owner;

and last `not IsPathBroken(convoy)`. `IsPathBroken` walks the path: for every sea province on it,
true where the owner may not enter it (`CCountry::MayEnterProvince`) or it is not `SeaConnected`
with the sea the start's port opens onto.

## 6. `CCountry::CreateConvoy` (`0x4FD2E0`), and what a new game gives away

`__thiscall`, seven stack arguments: from, to, a byte "carries supplies", the id pair
(`type 42`, the next of `g_convoy_id`), and a tag and id that are `---`/0 unless the convoy is
lend-lease. It makes the `CConvoy`, sets the goods mask - **supplies and fuel**
(`CConvoy::SetSupplyMask`, `0x4C7BD0`) or **crude oil, metal, energy and rare materials** - sets
the ends, calls `RebuildPath`, and puts the convoy on both end provinces' lists, the country's
list (at the tail), and the two areas' lists (`COwnerArea +0x4` for the one it starts in, `+0x14`
for the one it ends in).

Then one test decides its ships:

    if the in-game screen's byte +4 is set:   transports = GetDesiredTransports(convoy), escorts = 1
    else:                                      transports = 0, escorts = 0

**That byte is "a new game is being made".** `CInGameIdler::Enter` sets it at `0x65C9C7`, before
the first `RunDailyPass` (`0x65CB2E`) and `RunSupplyAndConvoyIterations` (`0x65CC64`), and clears
it at `0x65CD19`. So **every convoy made while a game starts is manned for nothing**, out of no
pool, and one made in play starts empty and waits for section 7 to man it.

`RunSupplyAndConvoyIterations` (`0x678AB0`) calls the three routines on its **second** pass, for
every country, whatever its three automation flags say:

    MaintainSupplyConvoys(country)
    MaintainResourceConvoys(country)
    if its second argument is 0 and country.Transports == 0:  country.Transports = country.max_ic / 2
    DistributeConvoyShips(country)

**So a country starts with one free transport for every two of its base IC**, whole numbers, and
its convoys' transports on top. `max_ic` (`CCountry +0x60C`) is the provinces' IC summed **with
no country scaling on it**: the record's comment on `TotalIC` said so ("+0x60C is the base") and
its comment on `max_ic` itself said the opposite, and the save settles it - of the 20 countries
with convoys, 19 have exactly half the rewrite's base IC free (Germany 72 of 144, the USA 128 of
256, Britain 80 of 161, Japan 47 of 94) where the scaled figure would have given Germany 100.
The twentieth is Denmark, with 1: its resource convoy from Iceland was made on the first day with
a transport, had nothing to load and gave it back, so the country did not have none when the
grant was looked at - which is the `Transports == 0` test doing what it says.

And free **escorts equal to its number of convoys**, because each convoy was made with one and
section 7 takes it back from a country at peace: true of 19 of the 20; Italy, at war, has one on
each of its six and none free.

**The first convoys are made on the first day, not in the filling.** `CInGameIdler::Enter` runs
`RunDailyPass` before `RunSupplyAndConvoyIterations`, and the country's day ends with the three
routines; the flag is already set, so those convoys are manned for nothing too. Denmark's 1 is
only explained that way.

In play `RunCountryDailyPass` calls the same three late in the country's day, each behind a
byte: `MaintainSupplyConvoys` behind `CCountry +0x749`, `MaintainResourceConvoys` behind `+0x74A`,
`DistributeConvoyShips` behind `+0x748` - the save's `auto_supply_convoy`, `auto_resource_convoy`
and `auto_maintain_convoy`, in the order the save writes them (`inferred` from that order and
from what each guards; the loader was not read). All three are `yes` for all 101 countries of the
start-date save, the player's included.

## 7. Sharing the ships out: `CCountry::DistributeConvoyShips` (`0x4FD750`)

One stack argument. `TotalNeededTransports (+0xB8) = 0`, `TotalConvoyTransports (+0xBC) =` the
free transports, `TotalNeededConvoyTransports (+0xC0) = 0`; `escortsOwned =` the free escorts;
`short = 0`; `escortsWanted = 0`. Then every convoy, in the country's list order:

    TotalConvoyTransports += c.transports;  TotalNeededConvoyTransports += c.transports
    escortsOwned += c.escorts
    if c.path has under two provinces or not IsRouteUsable(c):            -> list IDLE (at the tail)
    else if c is a supply convoy:
        UpdateLoadingProduction(c)                                        0x4C7740
        c.transports_wanted = GetDesiredTransports(c);  ComputeDesiredEscorts(c)
        -> list FIRST, at the **head**
        short += max(c.transports_wanted - c.transports, 0)
        escortsWanted += c.escorts_wanted
    else:
        UpdateLoadingProduction(c);  wanted and escorts as above
        if c.loading_production has no crude oil, metal, energy or rare materials: -> list IDLE
        else, with w = GetImportance(c):                                  0x4C78D0
            w >= 100.000  -> FIRST at the head
            w >  20.000   -> FIRST at the tail
            w >   1.000   -> LAST at the head
            otherwise     -> LAST at the tail
            escortsWanted += c.escorts_wanted

(The supply branch first asks two helpers, `0x4C7810` and `0x4C7870`, that work the headroom out
and throw it away; they answer whether the mask has fuel and has supplies, and a supply convoy
always has one.)

`UpdateLoadingProduction` sums `current_producing`, all seven goods, over the provinces of the
**start's area**. `GetImportance`: nothing for lend-lease; otherwise over the five goods that are
not supplies or fuel,

    amount = loading_production[g]                          (a trade convoy tests its `daily` instead)
    weight = 1.0;  2.0 where amount > 0.100 x the owner's daily income of g;
                   0.5 where amount < 0.020 x that income       floor(100.5f), floor(20.5f), floor(500.5f)
    w += loading_production[g] x weight

Then, in this order:

1. every IDLE convoy gives all its transports and all its escorts back;
2. `short -= ` the free transports;
3. LAST, **tail to head**: a convoy gives back `transports - wanted`, or **all it has** where
   `short > 0` or it has fewer than `GetDesiredTransports`; what it gives comes off `short`;
4. FIRST, head to tail: a convoy gives back what it has over `wanted`; and then, where it still
   has some but fewer than `GetDesiredTransports`, **all of them**;
5. FIRST, head to tail: `TotalNeededTransports += wanted`; it takes `min(wanted - transports, free)`;
6. LAST, head to tail: the same.

So a convoy is either at strength or - after step 4 - emptied and refilled in its turn; the supply
convoys made latest are served first, then the richest resource runs, and the poorest give their
ships up whenever a supply convoy is short.

7. Escorts, where the country has any convoy: `ratio = escortsOwned x 1000 / escortsWanted`, at
   most 1000, 0 where nothing is wanted. For every convoy in list order

       d = (c.escorts_wanted x ratio / 1000 - c.escorts)                  whole escorts, towards zero
       d < 0:   -d escorts go back
       d >= 1 and the convoy was attacked within the last 99 days:        it takes min(d, free)
       and a convoy with no transports gives all its escorts back.

   **A convoy that was never attacked is never given an escort in play.** `ComputeDesiredEscorts`
   wants none for a country at peace, so there `d` is minus what the convoy has.

8. `TotalNeededConvoyTransports += TotalNeededTransports`.

## 8. Resource convoys, and where cut-off production goes

**`CCountry::CollectDailyProduction` (`0x4F1F50`)** - one stack argument, called from
`RunCountryDailyPass` before the trade routes and `UpdateIC`. It zeroes `home_produced`
(`+0x770`) and `total_produced` (`+0x74C`); adds the base income of metal, energy and rare
materials (`CCountry::BaseResourceIncome`, `0x4F1E00`: a value of a static modifier, twice it and
half it) to `home_produced` and the stockpile; and then, for every province the country controls
(`+0xD00`), with `yield(g)` = `CMapProvince::ResourceYield` (`0x4A6EB0`: `current_producing[g]`
times the controller's technology for metal, energy and rare materials, times
`1 + the province's and the country's modifiers`, not below nothing) over the five goods that are
not supplies or fuel:

- **home** - the province's area is the capital's, **or its depot is a province of the capital's
  area**: the yield goes to the stockpile, to `home_produced` and to `total_produced`;
- **cut off** - neither: the yield goes into **the province's own `pool`** and to
  `total_produced` only. Then a loading port is looked for: the **start** of the first convoy on
  the area's starting list that is the country's and is trade, lend-lease or carries neither
  supplies nor fuel; failing that the area's **first port**. Where there is one and it is another
  province, **everything the province's pool holds of those five goods is moved to the port's
  pool** (`CGoodsPool::TakeResources`, `0x523A20`: each of the five times a share in thousandths,
  taken out of the source; supplies and fuel are left).

So a cut-off area's resources are in its loading port's pool by the end of each day, which is
what `CLASSES.md` saw from outside ("in 53 of the 58 resource ports the stock is exactly one
day's load"). An area with no port keeps them province by province.

**`CCountry::MaintainResourceConvoys` (`0x4FE7E0`)** - one stack argument; the same two early
outs as section 2. For every area of the country that is not the capital's and has a port: with
`P` the area's **first port**, where `P.pool` holds any crude oil, metal, energy or rare
materials (`CGoodsPool::HasResources`, `0x5239F0`) and no convoy starting in the area is the
country's and trade, lend-lease or without supplies and fuel: a convoy from `P` to
`NearestPortTo(P, the capital's area)`, where both are owned ports with a naval base.

**The test is on the harbour's whole pool, so a country that does not exist can call a ship.**
The save has a Danish resource convoy from Reykjavik with no transports, and Iceland yields
none of the four resources. The rewrite's replay makes that convoy only when it counts what its
own model keeps in Reykjavik's pool - the stockpile of Iceland, whose capital it is and which
does not exist in 1936 - and leaves it out when it counts the day's yield alone. The convoy then
has nothing to load by `UpdateLoadingProduction`, is idle, and gives its transport back - which
is the 1 free transport of section 6.

**And the sweep carries such a stockpile off.** A country that does not exist keeps its goods
in the pool of its capital province like any other (its own `pool` block in the save is empty),
and where that province is cut-off land of whoever holds it, `CollectDailyProduction` moves
everything in it but supplies and fuel to the loading harbour, and the convoy takes it home.
The start-date save, two days in:

| capital | of | held by | what its pool has left |
| --- | --- | --- | --- |
| Reykjavik | Iceland | Denmark | crude oil 450.000, metal 448.886, energy 897.772, rare materials 224.444 - **all of it**: Reykjavik is its block's loading harbour, so nothing is swept out of it, and its convoy has no transport |
| Jerusalem | Israel | Britain | supplies and money only |
| Cairo | Egypt | Britain | supplies and money only |
| Amman | Jordan | Britain | supplies and money only |
| Beirut, Damascus | Lebanon, Syria | France | supplies and money only |
| Baghdad | Iraq, which exists | Iraq | crude oil 470.280, metal 456.374, energy 939.936, rare materials 228.188 |

Each of these countries starts with about 450 of crude oil and metal, 900 of energy and 225 of
rare materials. And Britain's crude oil is **exactly 450.000** above what its own two days make
and use. So within two days the stock of a country that does not exist has been swept to the
harbour and shipped to whoever holds its capital.

**Such a country goes on being charged all the same**, which is why Israel's `usage` in the save
reads metal 2.395 with no metal in Jerusalem. Three things already read meet here:

- `UpdateIC`, and with it the cut a shortage makes to IC, runs only for a country that holds
  something or is in exile (`FINDINGS-distribute.md`, section 1); a country that does not exist
  keeps the IC it had;
- the consumer goods share and the supply share call `CCountry::ConsumeIcResources` without
  asking what the stockpile will bear (the same, sections 2 and 3), and that is a plain
  subtraction - so the capital's pool goes below nothing;
- **`RunDailyProvincePass` ends by holding each of a land province's seven goods between nothing
  and 99999.000** (`0x5F5DD18`), after every country's day. So the debt is gone by the day's
  end, and it is also why no stockpile passes 99999.

That answers what `FINDINGS-distribute.md` left open - whether `ConsumeIcResources` can take a
stockpile below zero. It can, for a day.

**And the IC such a country is charged for leaves its ministers out** (`measured`, the reason
`inferred`). Since `UpdateIC` is not run daily for a country that holds nothing, its `TotalIC`
is whatever the calculation on entering the game gave it. Twenty of the 22 such countries in
the save use resources as the rewrite's formula says; the two that did not are the two with a
minister who moves `global_ic`: Guyana - the law that halves IC and an armament minister worth
a tenth more - uses as for an IC of 2 where 5 x 0.6 is 3, and the Italian Social Republic - a
minister worth a twentieth less - as for 5 where 5 x 0.95 cuts to 4. Leaving the ministers'
`global_ic` out of such a country's IC makes it 22 of 22. So the entry calculation ran before
the ministers' effects were in the country's modifier - or something to the same end; what
was not read. It is the IC alone: the same countries' money, officers, influence and spies
agree with the save only with their ministers counted.

Then for every vassal (`CCountry +0xF78`) whose capital's area has no convoy starting in it:
unless one of the areas touching the vassal's capital's area is the country's own, a convoy from
the first port of the vassal's capital's area to the country's nearest home port.

Then every resource convoy of the country's is removed where its two ends are in one area, or
the controller of either end is not a friend (`CCountry::IsFriend`).

**The daily look at each convoy**, early in `RunCountryDailyPass` and before the units draw: a
convoy with a path that is not trade, has two provinces or more, has transports and is usable
**delivers** (`CConvoy::RunDelivery`); one with a path that is too short or broken has it
rebuilt. Then a convoy is **removed**, its ships going back, where it carries money and is not
trade, or where: a resource convoy's start is controlled by neither the country nor a puppet of
it; a supply convoy's end is not controlled by the country; or either end is controlled by a
country at war with the owner or by rebels.

## 9. The supply map mode: `MapMode_Supply_ColourLoop` (`0x8669B0`)

One stack argument, the map's colour table. Per province, with `b` = 1.0 where the viewing
country's intelligence on it is 2 or more and 0.5 below (0 for a province that is not
simulated), `grey = 0.4 x b`, and `P` pool, `LP` last_pool, `T` throughput, `D` drawn and `N` need
- the **supplies** of each, never the fuel:

    both colours = (grey, grey, grey)
    MaxInfrastructure < 0.200 (two levels; floor(200.5f)):  both colours black, done
    intelligence under 6:                                    done
    intelligence 6 or 7:                                     both = (grey, 0.8b, grey), done
    otherwise, the first that holds:
      P >= D and D > 0                                       (grey, 0.8b, grey)        green
      P <  D and D > 0 and LP <= 0 and T == 0 and N > 0 and N > P
                                                             (0.6b, grey, grey)        red
      P > 0 and D == 0                                       (grey, 0.6b, 0.6b)        blue-green
      D > 0 and ( P > 0  or  T > 0  or  LP > 0 )             (y, y, grey)              yellow
          y = 0.8b where MaxInfrastructure is above the infrastructure it has the use of
              (modifier 12 x (1 + modifiers 13 and 14), held between 0.010 and 1), else 0.5b
      nothing of these                                       grey
    second colour = the first, but (0.7b, grey, grey) where D > SupplyCapacity(province)

The second colour is the stripes: **a province asked for more than it can pass is striped red.**
`CColor::Set` (`0xA627A0`, colour in EAX, the four floats in XMM0-3) is new to the record.

**The tooltip** (`ProvinceTooltip_Mode4`, the branch at `0x4993DB`; read for what it says, not
for every string operation). On **sea**: for each convoy of the player's on the province's list,
`LOGTT_8` + the start's name + `LOGTT_9` + the end's name + `LOGTT_10`, and a `CONV_SHIP_IRO`
line per good it carried. On **land**: `TOOLOWINFRA` where `MaxInfrastructure` is under 0.200;
otherwise a throughput line (`THRU`, `VALUE_MAX`, `SUPPLY_INFRA_CAPITAL_EFFECT_INFO` for a
province beside a capital); `LOGTT_1` + the depot's name, ` (` + `supply_depot_distance` + ` ` +
`LOGTT_2` + `)`; and with intelligence above 8: `LOGTT_3` pool supplies and `LOGTT_4` pool fuel,
each red where it is under `need`; `LOGTT_5` drawn supplies and `LOGTT_6` drawn fuel; `LOGTT_7`
throughput supplies and `LOGTT_6` throughput fuel; and `PORT_SHIPS` with `NavalBaseCapacity`
where the province has a naval base. Every figure to two places.

## 10. Against the savegame

OpenHOI3's replay of this reading (`OpenHOI3.SaveCheck supplypass`, 2026-10-10) makes a game with
the units, laws and technology of `Germany1936_01_01_00.hoi3`, runs a day, the filling and a
day, and sets its convoys beside the save's:

| | |
| --- | --- |
| convoys | 261 in the save, 261 in the replay, **261 the same run with the same goods** |
| route | **261 of 261 province for province** |
| transports on each | 261 of 261 |
| escorts with each | 261 of 261 |
| free transports | 20 of 20 countries |
| free escorts | 20 of 20 countries |
| money and resources lying in a province that is nobody's capital | **88 of 88 to the thousandth** - what waits in each harbour |
| the same in a capital somebody else holds | 28 of 49 to the thousandth, 49 within a fiftieth |
| London's crude oil | to the thousandth, the 450.000 of section 8 with it |

The last three came right only with one pool for a province, swept whole, and with consumer
goods and supplies charged to a country that does not exist though its capital holds nothing
(section 8). Kept apart - the yield in a pool of its own, the charge held to what the stockpile
has - the harbours were 82 of 88, the money in every one of them wrong.

So sections 2 to 8 are borne out as far as a start can show them: which harbours get a convoy
and from where, the search and its heap down to the order of equals, the transports each run
wants, and the sharing out. What a start cannot show - the unmaking, the under-strength rule in
play, escorts under attack - rests on the reading. And with the convoys in, the supply pass's own
comparison went from 124 of 234 networks the same in every figure to **171**.

## 11. Not read

- The body of `CConvoy::CConvoy` and the destructor - that removal takes the convoy off the
  province and area lists is assumed from the three helpers (`0x4816E0`, `0x481760`, `0x4A7550`)
  that do it for `RebuildPath`.
- The save loader for the three automation bytes (section 6).
- `0x4F25E0`, called at the end of `CollectDailyProduction` for a subject, and the loop after it
  that moves money between countries.
- The trade branch of the daily look at a convoy, and lend-lease throughout.
- The tooltip's string building beyond which keys and which figures.
- Whether the first port and first province of an area are stable from day to day; the lists are
  rebuilt with the areas.
