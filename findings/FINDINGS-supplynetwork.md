# The supply network: areas, supply groups, depots, distances, and what a province passes

*Read on 2026-10-09 for the rewrite's first piece of supply. Static, then set against three of
the maintainer's savegames (section 9), which agree with it province for province, and then
against what he watched the running game do when he released two countries (section 10), which
the depot score gives case for case. Addresses are virtual (image base `0x400000`); the record
holds them as rvas.*

`FINDINGS-supply.md` is the daily pass: what moves along the network once it exists. This is the
network itself - which province draws on which depot, and why - and the three figures the pass
asks of every province. It settles five of that file's seven open points.

## In one paragraph

The land is cut into **areas**: blocks of provinces one country controls that touch one another,
each with more than one level of infrastructure. Areas that touch and are **on one side** - a
country's with its puppets' and its master's - are collected into **supply groups**, and a group
picks one **depot**, the province that scores highest, where a capital scores far above anything
else. Every province of the group draws on that depot. A group of a single area picks one only if
the area has a working port, or is its controller's home and has industry; otherwise each province
asks `CCountry::FindSupplyDepot`, which finds the capital where the area is the capital's own and
otherwise walks to a neighbouring area of a friend. A province no depot is found for counts its
days out of supply. From each depot the **distance** is then spread outwards, a province costing
its size - 1 to 4, by its bounding box - once, twice or three times by how poor its roads are.

**Two things the maintainer said before the reading, both borne out**: a puppet is part of its
master's network unless the two do not touch, and allies keep networks of their own.

## 1. What this corrects and settles

| was | is |
| --- | --- |
| `COwnerArea +0x70`, "the area-level override that gets first refusal on a province's label", unidentified | the area's **supply group**, and the group's `+0x10` is the depot it picked |
| `COwnerArea +0x69`, unidentified | "may hold a depot": a working port, or the home area with industry |
| `CCountry::FindSupplyDepot` "recurses through `+0xF34`/`+0xF38` and the area's `+0x34` list; not settled whether that reaches allies, puppets or lend-lease partners" | read through, section 5: it is the **fallback**, and it reaches the master, fellow puppets and friends - but only for an area whose group gave it no depot |
| `CProvinceTemplate +0x24`, "a per-province traversal cost, never sampled" | a **size class of 1 to 4** from the province's bounding box, section 6 |
| `CProvinceTemplate +0x13D`, "still unidentified" in the struct | the record's own `MarkSimulatedProvinces` entry had it already: **the province takes part in this session**, on everywhere in a campaign. The field is renamed `simulated` |
| `CMapProvince +0x54`/`+0x58`, "two further unit lists whose meaning is not established" | the province's **air base** and **naval base** objects; the lists are the wings based there and the fleets in port |
| `CMapProvince +0x2B0`, `capital`, "the province is a capital" | **the controller's capital or a province that touches it**, rewritten every day, section 7 |
| `COwnerArea` "is not in `project.json` at all" | it had eight fields by today; this adds its size, six more and the two structures it points at |

## 2. Areas

A `COwnerArea` is 0x98 bytes (`operator new(0x98)` at every one of the constructor's 21 call
sites), vftable `0x15BDB50`, three slots:

| slot | function | |
| --- | --- | --- |
| 0 | `0xA92590`, the shared `ReturnTrue` | "this is a real area"; `CNullOwnerArea` answers false |
| 1 | `COwnerArea::AddProvince` (`0x47EA10`, `ret 4`) | appends the province unless it is there, then refreshes the port lists and the two flags |
| 2 | `COwnerArea::RemoveProvince` (`0x47EA90`, `ret 4`) | unlinks it, then the same two refreshes |

Every province points at one through `CMapProvince +0x2B4`. A province in no area points at the one
`CNullOwnerArea` (`g_null_owner_area`, VA `0x1A85574`, made on first use: a `COwnerArea` with the
other vftable written over it).

| offset | | |
| --- | --- | --- |
| `+0x24` | `provinces` | `CList<CMapProvince*>`, count at `+0x2C` (already recorded) |
| `+0x34` | `neighbour_areas` | `CList` of **links**, 8 bytes each: `+0` the other `COwnerArea*`, `+4` how many edges join the two. The record had the payload as `COwnerArea*`; it is a pointer to that pair |
| `+0x48` | `ports` | `CList<CMapProvince*>`, count at `+0x50` (already recorded) |
| `+0x58` | `air_bases` | `CList<CMapProvince*>`, count at `+0x60` |
| `+0x68` | `landlocked` | a byte: no province of it has a working port |
| `+0x69` | `may_hold_depot` | a byte, below |
| `+0x6C` | `region_group` | already recorded; section 8 |
| `+0x70` | `supply_group` | `CSupplyGroup*`, section 3 |
| `+0x74` | `fronts` | already recorded |
| `+0x94` | `serial` | a running number from `g_owner_area_serial` (VA `0x1A85570`), given by the constructor |

**Who is in an area.** `RebuildOwnerAreas` (`0x47CEF0`, no arguments, bare `ret`, one caller at
`0x648D48`) first frees every area (`ClearOwnerAreas`, `0x47D160`) and then, for every country in
the country database's order, walks the country's list of **controlled** provinces. A province
starts a new area when all three hold:

    its template is simulated                          CProvinceTemplate +0x13D
    it is in no area yet                               area->slot0() answers false
    MaxInfrastructure (+0x5C)  >  100                  the static at VA 0x1A869E0

**The 100 is one level of infrastructure.** The static is filled once, by the initialiser at
`0xCAEC50`, from the float `100.5` at `0x160A684` through `floor`; `MaxInfrastructure` holds a
province's most infrastructure with 1000 for ten levels (the record's comment on the field: 10,642
of 10,642 provinces read `infra x 100` live). So **a province whose infrastructure is one level or none is
in no area at all**, and the test is strict: exactly one level is out.

`COwnerArea::Flood` (`0x47D370`, `this` in `ecx`, the province on the stack, `ret 4`) takes the
province in - slot 1, then `province->area = this` - and goes through **its template's edges in
order**. A neighbour is taken, by the same routine and at once, when it is simulated, **its
controller's id equals this province's**, it is in no area and its `MaxInfrastructure` is above the
same 100. **The edge's kind is not looked at**: a crossing and an edge marked impassable join as a
plain border does. A sea province has no controller and never joins. The recursion is depth
first, so the area's province list is in the order of that walk.

After every area is made, `COwnerArea::BuildNeighbours` (`0x47E7B0`, the area on the stack,
`ret 4`) is run on each: for every province of the area and every edge of it, where the province
across is in a real area that is not this one, `COwnerArea::AdjustNeighbour` (`0x47EAD0`, `this`
in `ecx`, the other area in `eax`, the count to add on the stack, `ret 4`) adds one to the link,
making it at the list's end the first time. A link whose count falls to zero is unlinked and freed.

**Ports and air bases.** `COwnerArea::RefreshBases` (`0x47E6D0`, the area in `edi`, bare `ret`)
empties both lists and goes through the provinces:

    port:      owner id (+0x330) != 0  and  port (+0x354) != null  and  naval_base (+0x300)->+0x20 > 0
    air base:  air_base (+0x304)->+0x20 / 1000 > 0

`+0x354` is the province's `CPort`, which only a province whose naval base position lies on the
sea has (`FINDINGS-seaair.md`), so a naval base on a lake is no port. `+0x20` of a
`CProvinceBuilding` is what the record calls `level_max`.

**The two flags.** `COwnerArea::RefreshDepotFlags` (`0x47EC00`, the area on the stack, `ret 4`)
writes the word at `+0x68` to 1 - landlocked, may hold no depot - and goes through the provinces:

    if the province is a port (the same three tests):   landlocked = 0, may_hold_depot = 1, stop
    else if may_hold_depot is still 0
         and this area is the area of the acting capital of the province's CONTROLLER
         and the province's industry (buildings[db->+0x2C->index])->+0x20  >  the static at 0x1A86A14:
                                                         may_hold_depot = 1

`g_CBuildingDataBase +0x2C` is the cached `industry` building (the record's own account of that
object). The static at `0x1A86A14` has one reference in the image, this read, and nothing writes
it: it is zero. So **an area may hold a depot of its own when it has a working port, or when it is
its controller's home and has any industry.**

Two small readers, both with the area in `eax`: `COwnerArea::FirstPortId` (`0x47E6B0`) answers the
province id of the first port, or 0; `COwnerArea::FindOpenPort` (`0x47E540`, `ret 8` over two stack
words it never reads) answers the id of the first province that passes the port tests **and**
whose byte at `+0x36C` is clear, or 0. It is the `0x47E540` `FINDINGS-leadership.md` left unread
behind `blockaded`; what sets `+0x36C` was not read. `COwnerArea::GetController` (`0x47E9D0`, the
area in `ecx`, the tag written through `eax`) is the controller of the area's first province, or
`---` with id 0 for an empty one.

**Kept up to date.** A province that changes hands goes through `UpdateOwnerAreaOfProvince`
(`0x47F540`, `__cdecl`, five words: the province, its new controller's tag and its old one's -
called from `CMapProvince::TakeControl` at `0x4A32C2`, from `0x4A3B33` and from `0x4B808E`). It
takes the province out of its area, where the area is left empty unlinks and frees it, where it is
left with more than one province **floods it again from scratch** (so a block cut in two becomes
two areas), then puts the province into a neighbouring area of its new controller - merging two
such areas into the larger with `COwnerArea::Absorb` (`0x47F460`, `ret 8`) where it now joins
them - or into a new one, and mends the links. `TakeControl` then, behind a flag of its own,
calls four routines in a row: `0x47FFF0`, `RebuildAreaGroups` (`0x47FEB0`), `0x4807F0` and
`RebuildSupplyGroups` (`0x480690`). The first and third were not read; by their place they empty
the two lists the second and fourth fill.

## 3. Supply groups

`RebuildSupplyGroups` (`0x480690`, no arguments, bare `ret`, fifteen callers) calls `0x481980`
(not read) and then, for every country in order and every area of its list (`CCountry +0xD30`)
that is real and has **no group yet** (`+0x70 == 0`):

    group = new CSupplyGroup        0x14 bytes: a CList<COwnerArea*> at +0, the depot's id at +0x10
    CSupplyGroup::Collect(group, area)
    CSupplyGroup::PickDepot(group)
    append the group to the list at VA 0x1A869B4 (last at 0x1A869B8, count at 0x1A869BC)

`CSupplyGroup::Collect` (`0x4809D0`, `this` in `ecx`, the area on the stack, `ret 4`) sets the
area's `+0x70`, calls slot 8 of the area's controller with the group (not read), appends the area
to the group's list, and then goes through the area's neighbour links in order. A neighbour with
no group yet is collected, by the same routine and at once, when - with `theirs` the neighbour's
controller and `first` **the controller of the group's first area** -

    theirs->IsSameSide(first)
    or  ( the neighbour is landlocked (+0x68)
          and it is not the area of theirs' acting capital
          and theirs->CanOperateIn(first) )

`CCountry::IsSameSide` (`0x4EF940`, already recorded) is true for the same country, for a puppet
and its master either way round, and for two puppets of one master; never for the rebels.
`CCountry::CanOperateIn` (`0x4EFA00`) adds a country fighting a war beside the other that is not
at war with it. So:

- **A puppet's land that touches its master's is one group with it.** Land of a puppet that the
  master's does not touch starts a group of its own.
- **Allies do not join.** Two members of a faction are not on one side by this test, and the
  second arm is only for a landlocked block away from its holder's capital - a pocket of an
  ally's that has no port of its own is taken into the group whose land it sits beside.
- The test is always against the **first** area's controller, so which area a group is started
  from decides who else is in it. With a master and its puppets it comes to the same thing either
  way.

## 4. The group's depot

`CSupplyGroup::PickDepot` (`0x480C00`, the group on the stack, `ret 4`) zeroes `+0x10` and stops
unless

    the group has more than one area,  or  its one area's may_hold_depot (+0x69) is 1

Otherwise it scores **every province of every area** of the group and keeps the best, strictly:
of two provinces with one score the earlier stays. For an area with `home` the area of the acting
capital of the **owner** (`+0x32C`) of the area's first province, and a province `p` of it:

    score = p->MaxInfrastructure
    if p's area != home:            score += p's naval base level (+0x300 -> +0x20)
    for each q in p's near provinces (+0x14C .. +0x150):
        if q is in a real area and that area's supply group is this group:
            score += q->MaxInfrastructure
            if q's area != the area of the acting capital of q's OWNER:
                score += p's naval base level                    p's, again - not q's
    score = score / (the number of near provinces + 1)           whole-number division

    if p is the acting capital of its CONTROLLER:
        score += 2000
        if the controller is not a subject (+0xF34 == 0):                score += 1000000
        if the controller's faction (+0xD8) has members and the first is the controller:
                                                                         score += 10000000

`MaxInfrastructure` is 1000 for ten levels and a building's level is 1000 a level, so away from a
capital **the naval base decides**: a level of port is worth as much as the most infrastructure a
province can have. The capital of a country that is nobody's puppet beats any port, and a faction
leader's capital beats that.

The depot's id goes to `+0x10` and, where it is not 0, **into `supply_depot_id` (`+0x48`) of every
province of every area of the group**.

**The near provinces.** `CMapProvince +0x14C`..`+0x150` is a `vector<CMapProvince*>` (`+0x154` its
end of storage), filled by the province's reset at `0x496480` - the routine that also points
`+0x2B4` at the null area: for every edge of the template the province across is added unless it
is there, and then, for every edge of **that** province, the province across that. So it is
**every province within two edges**, each once, in the order met - and since a neighbour's edges
lead back, the province itself is in its own list whenever it has a neighbour. Sea provinces are
in it. The score counts the province twice over for that reason, and divides by one more than the
list's length. `SuppressionNearProvince` (`0x49F360`) walks the same vector, so the suppression
"in and around" a province is of the same two rings.

## 5. A province's depot

`CProvince::UpdateSupplyDepot` (`0xA70C0` rva, already recorded; `this` in `ecx`, bare `ret`) is
called for **every simulated province once a day** by `RunDailyProvincePass` (at `0x49EF5B`), and
from `CInGameIdler::Enter` for every province whose depot is still 0. It does nothing to a
province with no owner (`+0x330 == 0`) or in no real area. Otherwise, with `group` the area's
`+0x70`:

    if group != null  and  (group has 2 areas or more, or the area's may_hold_depot == 1)
                      and  group->depot != 0:
        supply_depot_id = group->depot
    else:
        supply_depot_id = FindSupplyDepot(controller's country, province, an empty list, null)

and then `out_of_supply_days` (`+0x20`) is counted up where the depot came out 0 and zeroed where
it did not, and the network is marked to be measured again. So **a province with no depot counts
its days**, a sea province among them, and the savegame's `out_of_supply_days` - written only
above zero - is the list of provinces that draw on nothing.

`CCountry::FindSupplyDepot` (`0x4F2B00`, `this` in `ecx`, three stack arguments - the province, a
`CList` of areas already looked at, and the country it is being asked for, `origin`, null on the
first call and then taken to be `this` - `ret 0xC`). **It is the fallback**: by the test above it
is only reached for an area that is alone in its group and has neither a port nor a home with
industry, or - through its own recursion - for an area beside one. In order:

1. 0 where the province's area is in the list already; 0 where the province has no owner or no
   real area. Otherwise the area is added to the list.
2. Everything from here to step 8 only where **the province's controller is `this`**.
3. Where the area's `may_hold_depot` is 0: for each neighbouring area, in the links' order, that
   has a controller, is not in the list and whose controller **`origin->IsFriendly(.., false)`**
   (`0x4EF7C0`): ask *that* country about *that* area's first province, with that country as the
   new `origin`. The first answer above 0 is returned.
4. Where `origin` is a subject: the same over the neighbouring areas whose controller is
   `origin`'s overlord.
5. Where the area is the area of `origin`'s acting capital: **`origin`'s acting capital**.
6. Where `origin` is `this` and the area has a port: the province of the area with the largest
   `MaxInfrastructure` **plus that of each province across one of its edges that is in the same
   area**, where that is above 0. A different sum from section 4's: one ring, no port, no
   division.
7. The same recursion over the neighbouring areas held by `origin` itself, by a puppet of
   `origin`, or by a puppet of `origin`'s own overlord.
8. And over those held by a friend, as in step 3.
9. Where `origin` is `this`: the area's first port's id (`COwnerArea::FirstPortId`), or 0. Else 0.

`CCountry::IsFriendly` is wider than `IsSameSide`: the same faction, an alliance, and a country
fighting a war beside this one count. So **a block of land with no port and no capital, beside a
friend's land, draws on the friend's depot** - step 3 or step 8 - and beside nobody's it draws on
nothing. Step 6 is close to dead: an area with a port may hold a depot, so its group picked one,
and the step is only reached for an area asked about through somebody else's recursion. There it
names a province that need not be that area's own depot, and a province given such an answer draws
on a "depot" nothing is spread from (section 6). Not seen in any save.

## 6. How far

`FINDINGS-supply.md` has the walk: `CSupply::RebuildSupplyNetwork` sets every labelled, simulated
province to 100000 and the rest to 0, and `CSupply::SpreadFromDepot` relaxes outwards from every
province whose label is its own id, a province that improves going back on the queue. A step
into a province costs

    factor(province) x size(province)

with the factor 1, 2 or 3 by the province's infrastructure, as that file has it. **The size is
`CProvinceTemplate +0x24`, and it is not a distance.** `CMap::ComputeProvinceGeometry` (`0x4917A0`)
sets it at `0x491839`..`0x491860` from the province's bounding box, right after the centre:

| `bbox_width + bbox_height`, pixels | size |
| --- | --- |
| under 30 | 1 |
| under 60 | 2 |
| under 90 | 3 |
| 90 and over | 4 |

So a step costs between 1 and 12, and the "largest distance clamped to 500" that the daily pass
keeps is in those units. `CWeatherManager::PropagateHighPressure` uses the same number as its
step (`FINDINGS-weather.md`), so weather pressure too falls off faster across a large province.

## 7. What a province passes, what it takes, what it asks for

**`SupplyCapacity`** (`0x49DD00`, already recorded): how much a province can pass on in a day.

    if the province's `capital` byte (+0x2B0) is set:        99999.000
    infra = clamp( modifier[INFRASTRUCTURE] x (1000 + modifier[LOCAL_INFRASTRUCTURE]
                                                    + modifier[GLOBAL_INFRASTRUCTURE]) / 1000,  10, 1000 )
    level = 10000 x infra / 1000                             the level, 10.000 at full
    worth = 1000                    where level < 1000
            level x level / 1000    otherwise                the level squared
    worth = INFRA_THROUGHPUT_IMPACT x worth / 1000
    if owner id == controller id:   worth = OWNED_AND_CONTROLLED_THROUGHPUT_CAP_BONUS x worth / 1000
    capacity = (1000 + controller's modifier[SUPPLY_THROUGHPUT]
                     + controller's technology supply_throughput) x worth / 1000

The 10000 is the float `10000.5` at `0x160A648` through `floor`, the 10 the float `10.5`. With
Their Finest Hour's 4 and 2, ten levels on a country's own ground pass 800 a day and five pass 200.

**The `capital` byte is not "this is a capital".** `RunDailyProvincePass` rewrites it for every
province at `0x49ED9D`/`0x49EDEC`, before it asks for the depot: 1 where the province **is** the
acting capital of its controller, or where **one of its template's edges leads to it**; 0
otherwise. So a capital and everything that touches it pass supplies without limit. The savegame
writes the byte as `capital=yes`, on 402 provinces on the first day.

**`SupplyLoss`** (`0x49DE80`, already recorded): what a load loses crossing a province.

    tax = SUPPLY_TAX
    if owner id == controller id:   tax = tax x 1000 / 2000              half on its own ground
    times = 1000
    if the province is not frozen (+0x88 == 0):
        times += muddyness (+0x84) x MUDDYNESSSUPPLYTAXMODIFIER / 1000
    if the controller IsEnemy of the owner:
        s = clamp(suppression (+0x28), 0, 1000)
        times += PARTISAN_EFFECT_ON_SUPPLY_TAX x modifier[LOCAL_PARTISAN_SUPPORT] / 1000 x (1000 - s) / 1000
    tax = tax x times / 1000
    tax += controller's technology supply_transfer_cost                  negative in the files
    never below 0

The record's comment had the partisan term "built from ... the province's +0x84 when +0x88 is
zero"; those two are the mud, and the partisan term is the modifier with id `0x4C`,
`LOCAL_PARTISAN_SUPPORT`, read at `[province + 0x114] + 0x260`.

**`SupplyNeed`** (`0x49E020`, already recorded): the supplies and the fuel the units in a province
ask for in a day, each the sum of `CUnit::SupplyConsumption` and `CUnit::FuelConsumption` over

- the units in the province (`+0x2B8`) for which the virtual at `+0x3C` answers true - **land
  units** - and whose owner either is the province's controller or is not at war with it, neither
  being the rebels. Before a game is under way (`in_game` 0 and not loaded from a save) the
  owner is not looked at;
- every unit of the list at `+4` of the object at `CMapProvince +0x54` - the province's air base,
  the object a wing's home base pointer holds: **the wings based here**;
- and every unit of the list at `+4` of the object at `+0x58`, the naval base: **the fleets
  based here**. (This said "in port here" until 2026-10-10. `CUnit::ConsumeSuppliesAndFuel` sends
  a fleet to its base's province wherever the fleet is - `FINDINGS-supplypass.md`, section 4 - and
  the list is the same kind as the air base's.)

So a wing draws where it is based and so does a fleet, and neither is asked whose side it is on.

## 8. The other grouping

`COwnerArea +0x6C`, the record's `region_group`, is made the same way by `RebuildAreaGroups`
(`0x47FEB0`) and `0x4801D0` (`this` the group in `ecx`, the area on the stack, `ret 4`): a
neighbouring area with no group joins when its controller is not the rebels and either
`IsSameSide` with the controller of the group's first area or fighting a war beside it
(`CDiplomacyStatus +0x58`) and not its enemy. So it is the supply group without the "landlocked
and away from the capital" limit on the second arm: **the land a country and those fighting
beside it hold in one piece**. It is 0x10 bytes, a `CList<COwnerArea*>`, kept in the list at VA
`0x1A86980`. Supply does not read it; the unit AI does.

## 9. Against the savegames

A save does not write a province's depot. It writes three things the network decides, and the
maintainer's saves of 1 January, 8 January and 20 April 1936 were set against all three, with
sections 2 to 5 worked out afresh from each save's own owners, controllers and capitals:

| | the save | by this reading |
| --- | --- | --- |
| provinces with `out_of_supply_days` | 4400 | **the same 4400**, in all three |
| provinces with `capital=yes` | 402, 402, 400 | **the same**, in all three |
| `throughput` above the province's capacity | - | none, of about 2,500 provinces a save |

Of the 4400, 4383 are the sea, land nobody owns and land with one level of infrastructure or
none - which is what fixed the 100 as a strict "more than one level". **The other 17 are owned
land with more**, and the reading gives every one: the three provinces of the Canal Zone and the
two of Panama it cuts off from Panama City, six islands with no naval base, and six blocks on the
mainland with no port and no friend beside them. They are section 5 coming out 0.

Two more things agree without proving as much. All 232 convoys of the 8 January save that carry
supplies run between a port of land that draws on the sender's capital and a port of land that
draws on another depot, by this reading; none runs inside one network. And of the networks of
more than one province with supplies in them, the largest pool of supplies lies at the depot this
reading picks in 104 of 113, 107 of 115 and 110 of 121; in the rest it lies at another port of the
same network or where the garrison stands, with the depot's own pool close behind.

**What that does not show**: which province of a group is the depot is checked, in a save, only
by where the supplies lie. The next section is the maintainer watching it.

## 10. Watched in a running game

The maintainer, on 2026-10-09, in the unmodded game as Japan's neighbourhood stands on the first
day, releasing countries out of Japan's Korea and reading each province's depot:

> At the start Manchuko exists and is supplied from Hamhung. If I release only North Korea the
> depot changes to Pusan for Manchuko and North Korea. If I also release South Korea it switches
> them all to their own captial, even though Japan still has a port in Dailan. HOWEVER after
> letting the game run a few days the puppets and Dailan all switch to Pyongyang.

Sections 2 to 4, worked out afresh on the first day's map with the same releases - each country
given every province it has a core on that Japan owns and controls, and made Japan's puppet -
give **each of the three settled states**:

| | watched | by this reading |
| --- | --- | --- |
| as the game starts | Manchukuo on Hamhung | Manchukuo and Japan's Korea, one group, on Hamhung |
| North Korea released | Manchukuo and North Korea on Pusan | the group - Manchukuo, North Korea, Japan's south - on Pusan |
| both Koreas released, some days on | the puppets and Dalian on P'yongyang | the group - Manchukuo, both Koreas, Dalian - on P'yongyang |

So three terms of `CSupplyGroup::PickDepot`'s score are seen at work, which no save could show:

- **"plus the naval base level where the province's area is not its owner's home"**: Hamhung is
  the depot while it is Japan's and stops being it the day it lies in North Korea's own home
  area, though nothing about the port changed.
- **2000 for a subject's capital against a port**: Pusan, on land that is not Japan's home, beats
  the capitals of two puppets.
- **A capital where no such port is left**: with Japan holding only Dalian - one province, its
  score divided over a near list that is mostly sea and Manchukuo's home - the best built of the
  three puppets' capitals wins.

**And the days in between say when the groups are made.** With both Koreas given their land and
*not* yet marked as anybody's subject, this reading puts each Korea on its own capital - a group
of one area, its capital worth the full million - and Manchukuo and Dalian on Hsinking: "all to
their own capital, even though Japan still has a port in Dalian". So the groups are made again
when the land changes hands (`CMapProvince::TakeControl`'s call of `RebuildSupplyGroups`), **at
which moment the released country is not yet a subject**, and they are not made again when it
becomes one - only "a few days" later, by one of the fourteen other callers. `inferred`: it fits
what was watched in both states, and neither the order of a release's effects nor those callers
were read. **It made one prediction that was then checked**: that with North Korea alone
released, the move to Pusan would be delayed in the same way. Asked whether it came at once, the
maintainer answered "Only after a few days."

## Not read

- `0x47FFF0`, `0x4807F0`, `0x481930` and `0x481980`, which by their place empty the two lists of
  groups before they are filled.
- Slots 6 and 8 of `CCountry`, called with each new group.
- What sets `CMapProvince +0x36C`, the byte `COwnerArea::FindOpenPort` skips a port for.
- `COwnerArea`'s two vectors at `+0x4` and `+0x14`, which the constructor zeroes.
- The fifteen callers of `RebuildSupplyGroups` beyond `TakeControl`: what else makes the groups
  be made again. Section 10 says it is not a country becoming a subject, and that one of them
  runs within a few days of that.
- The scores `CSupplyGroup::PickDepot` gives that nothing has shown at work: the million for a
  free country's capital against a very large port, and the faction leader's ten million.
- `0x648D48`, the one caller of `RebuildOwnerAreas`.
- The virtual `RebuildSupplyNetwork` calls first, slot 5 of the object at `CCurrentGameState +0xF0`.
- The convoys: where a convoy lands its load and how a depot across the sea is filled. A save's
  convoys end at ports, several to one network, and not at the depot.
