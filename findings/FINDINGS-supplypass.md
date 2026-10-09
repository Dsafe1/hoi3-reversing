# The daily supply pass, step for step, and what goes on around it

*Read on 2026-10-09 and 2026-10-10 for the rewrite's second piece of supply. Static, then set
against the maintainer's savegame of the start date (section 9), where a replay of it reproduces
124 of 234 networks province for province in every figure the save keeps. Addresses are
**virtual**, the way a disassembler prints them; the record holds the rvas. Only valid for this
build.*

`FINDINGS-supply.md` has the pass in outline and `FINDINGS-supplynetwork.md` the network it runs
on. This file is the pass read instruction for instruction, and four things beside it that
decide what a province holds: the unit's draw, what a unit carries with it, where a day's
supplies are made, and what a new game does before its first hour.

## In one paragraph

Once a day, before any country's own day, every province swaps its two pairs of buffers and the
pass goes through the provinces **furthest from its depot first**. A province that is not a
capital works out what it wants - enough to hold `SUPPLYPOOL_DAYS` of what its units ask for, at
most two days' worth at once - adds that to what the provinces behind it have asked of it, and
takes what the provinces nearer the depot will give: of what each **held when the pass last came
to it**, up to what it can pass in a day. What it could not get it leaves as a demand on them.
Then, nearest first, every province holding more than its days and what was asked of it sends
all the rest **one province inward**. A unit draws on the province it stands in, its share of
what is there. A marching unit takes its days of supplies along. A day's supplies and fuel are
made **where the factories are** and travel to the capital a province a day. And a new game
runs **a day, then the pass some hundreds of times with the stockpiles put back each time, then
another day** - which is the "two days" every save of the start date is on from.

## 1. What this corrects

- **What a load loses is an amount, not a share.** `FINDINGS-supply.md` says a take "arrives less
  `stepLoss[id]`", which is right as far as it goes, and `FINDINGS-supplynetwork.md` read
  `SupplyLoss` as "what a load loses crossing a province" without saying of what. It is
  `SUPPLY_TAX` in thousandths of a unit - 0.1, half that on a country's own ground -
  **added to what the province asks for and taken off what arrives**, whatever the size of the
  load. Section 9 has it on a savegame: fuel asked along a line of provinces out of Moscow reads
  5.250, 5.200, 5.150, 5.100, 5.050, 5.000.
- **`SUPPLYPOOL_DAYS` is 15 in Their Finest Hour**, 30 in the base game's file and 35 in
  BlackICE; the 35 in `FINDINGS-supply.md` is the mod's.
- **The naval base's list is the fleets based there**, not the fleets in port.
  `FINDINGS-supplynetwork.md`, section 7, said "in port". `CUnit::ConsumeSuppliesAndFuel` sends a
  fleet to its base's province wherever the fleet is (section 4), and the list is the same kind of
  list as the air base's.
- **`RunSupplyAndConvoyIterations` is not all a new game runs.** `CInGameIdler::Enter` calls
  `RunDailyPass` itself first (section 7).
- **The province's `current_producing` supplies and fuel are written by the makers of supplies
  and fuel** (section 6) and reset the same day, so the "made at home" term of a province's want
  is nothing in practice.

## 2. The order

`RunDailyPass` (`0x682C20`), where arcade mode is off: `CSupply::RebuildSupplyNetwork` if the
network is dirty; `CSupply::ResetSupplyOrder`, which puts every province's pointer in the order
array in the order of the provinces' numbers, number 0 and the sea with them; then

    qsort(order, count, 4, CompareProvincesByDepotDistanceDescending)

`_qsort` is `0xB96750`, **the C runtime's own** - Ghidra's library match says Visual Studio 2010,
and the body is that runtime's: runs of eight or fewer go to `shortsort` (`0xB966C0`), which
finds the element that belongs last, by a strict `> 0`, and swaps it to the end, again and
again; longer runs take the middle of the first, the middle and the last element as the pivot
(three compares, each swapping on `> 0`), partition about it, step over everything equal to the
pivot, push the longer half and go on with the shorter.

**The sort is not stable, and the order of provinces equally far from their depots is whatever
it leaves.** That order decides who takes first from a province with too little, so it is part
of the rule. It can be had exactly by sorting the same input the same way: the provinces by
number, with the comparator's three answers.

`max_supply_depot_distance` (`CCurrentGameState +0x58`) is then element 0's distance, held to 500.

Then, per country that exists, `CCountry::ClearDailyPools` (`0x4F28B0`, the country in `EAX`):
it zeroes seven goods each of `usage`, the pool at `+0xA1C`, `unit_demand`, the pool at `+0xA64`,
`tribute_received`, `sent_back` and `sent_to`. Then `RunDailySupplyPass` (`0x687070`), and only
then the countries' own days and after those the provinces'. So:

    the supply pass  ->  each country: its units (rotation, then the draw), its production  ->  each province

## 3. The pass

`CSupply::DailySupplyPass` (`0x6872D0`). `days` is `SUPPLYPOOL_DAYS / 1000`, never under 1.
"Nearer" below is always: a province across one of this one's edges, simulated, **with the same
`supply_depot_id` and a strictly smaller `supply_depot_distance`**. Supplies and fuel are worked
side by side and never mixed.

**Phase 1.** Every simulated province: `drawn` and `last_drawn` swap, `throughput` and
`last_throughput` swap, and today's `drawn`, `throughput` and `need` are zeroed.

**Phase 2, the order's first element first.** A province that is its controller's acting
capital copies `pool` to `last_pool` and that is all. Any other:

    need = supplyNeed[id]                      and the same for fuel
    if 0 < need < 1.000 and pool < 5.000:  need = 1.000
    province.need = need

    made   = min(need, current_producing)                       nothing in practice (section 6)
    want   = days x need - pool - made
    want   = clamp(want, 0, 2 x need)                           the 2 is floor(2000.5f)
    drawn += want

    S = drawn.supplies, F = drawn.fuel                          its own want and all passed in to it
    if S < 1 and F < 1:  next province - and `last_pool` is NOT brought up to date
    if S > 0:  S += stepLoss[id]
    if F > 0:  F += stepLoss[id]

*Sweep 1, goods.* Over the edges in order, for each nearer province `N`:

    count += 1
    if S < 1 and F < 1:  stop the sweep                         so count can fall short
    offered = min(N.last_pool, capacity[N])
    if N.last_drawn > 0 and N.last_throughput > 0 and N.last_throughput < N.last_drawn:
        offered = offered x min(S x 1000 / N.last_drawn, 1000) / 1000
    offered = min(offered, N.pool)
    take    = min(S, offered)
    if S > 0 and take > 0:
        N.drawn += take;  N.throughput += take;  N.pool -= take
        pool    += max(take - stepLoss[id], 0)
        S       -= take
        where N is its controller's acting capital:  that country's usage += take

Three things in it:

- **`last_pool` and not `pool`.** A province further out is processed before `N`, so
  `N.last_pool` is what `N` held when **yesterday's** pass came to it. What reaches a province
  today can go one province further tomorrow, and no faster. A capital's `last_pool` is its whole
  stockpile as of yesterday.
- **For fuel the first test reads today's `drawn`, not `last_drawn`**: `cmp [drawn_ptr + 0xC], 0`
  where the supplies arm has `last_drawn_ptr`. The other two tests and the division use
  `last_drawn` in both. `likely` a slip; it is what the bytes say.
- The rationing is this province's share of what was asked of `N` **yesterday**: where `N` passed
  less than it was asked for, each taker is held to `S / N.last_drawn` of what `N` offers.

*Sweep 2, shares of what is still wanted.*

    shareS = count == 0 ? -1 : S x 1000 / (count x 1000)        and shareF
    for each nearer province N, in edge order:
        shareS = min(shareS, capacity[N] - N.drawn.supplies)    and it STAYS cut for the rest
        if shareS > 0:  N.drawn.supplies += shareS
        S -= shareS                                             whatever its sign

So a share cut by one province's room stays cut for the provinces after it, and **a province
already asked for more than it can pass makes the share negative, which is then taken off `S`
with its sign - `S` grows**. Both are what the bytes do.

*Sweep 3, the rest.* Over the edges, for each province with the same depot: stop if `S < 1` and
`F < 1`; for a nearer one, `N.drawn += min(S, capacity[N])` and `S` less by that. Here the limit
is all `N` can pass, not its room.

Then `last_pool = pool`.

Sweeps 2 and 3 move **demand and no goods**.

**Phase 3, the order's last element first.** Skipped: a province at distance 0 that is its
controller's acting capital; one with `pool < 1` in both; and one **short of both** - `drawn > 0`
and `pool < drawn` for supplies and for fuel alike. Otherwise

    spare = pool - (drawn + days x supplyNeed[id])              the need as counted, NOT as raised

and where either is above nothing:

- **at distance 0**: up to `min(sum over the province's convoys that end here and start in the
  capital's area of NavalBaseCapacity x efficiency / 1000, NavalBaseCapacity)` of each goes to
  the controller's acting capital, counted in `sent_back`;
- **elsewhere**: all of it goes to **the first nearer province in edge order**, with no limit,
  counted in `sent_back` where that province is its controller's acting capital.

Because the nearest goes first, what a province sends inward lands in a province already
visited: **a surplus moves one province a day.**

**A capital that is not a depot is drained by this.** A country whose capital draws on another's
depot - Manchukuo's, on Japan's Hamhung - is an ordinary province to phase 3 once its distance is
not 0: everything its stockpile holds over its own garrison's days goes inward towards the
depot, a province a day, and from the depot home to the depot holder's capital. Section 9 has it:
Manchukuo's capital holds 7.8 supplies on the second day, where a country's stockpile starts
with ninety days of what all its units use.

## 4. A unit's draw

`CUnit::ConsumeSuppliesAndFuel` (`0x5BB950`), the network arm (arcade mode off). It asks
`CUnit::SupplyConsumption` and `CUnit::FuelConsumption` what the unit uses; `payer` is the
expeditionary owner where there is one, else the owner.

**Which province.** The unit's current province; the owner's acting capital where it has none.
Where it has a home base (`+0x98`) - a wing, a fleet, **wherever it is** - the base's province;
for an air unit whose base is a carrier, the province of the carrier's own base. A land unit
aboard a fleet or an air transport takes the carrier's base.

    need  = that province's `need` (section 3: nothing at a capital)
    depot = provinces[province.supply_depot_id]

**Paying a friend.** Where the depot's controller is not the payer, is a friend of it
(`CCountry::IsFriendly`, requests counted) and the payer is no government in exile:

    full  = need < 1 ? 1000 : province.pool x 1000 / (days x need)
    price = (1000 - full) x 250 / 1000 + 1000                   the 250 is floor(250.5f)

for supplies and for fuel apart. So a friend's unit pays between a little under and **a quarter
over** what it asks for, the more the emptier the province it draws in.

**A fleet under a rebase order** (`GetTypeId() == 0x6DE`) has both province and depot replaced
by its owner's acting capital - after the price was worked out from the old ones.

**Whoever holds the depot must be a friend of the unit's owner**, where there is a depot at all
(`ProvinceID != 0`); otherwise both received figures are 0 and nothing else happens.

Then, with `holder` the controller of the province drawn on, for supplies:

    asked < 1:   received = 1000
    else:
        not paying:  holder.unit_demand += asked
        paying:      amount = price x asked / 1000
                     payer.TradedAway += amount
                     amount = min(amount, the payer's stockpile)
                     the payer's stockpile -= amount;  the depot holder's stockpile += amount
                     the depot holder's TradedFor += amount;  its unit_demand += amount
        have = province.pool
        if have < need:  have = have x (asked x 1000 / need) / 1000        its share of what there is
        if have < asked: received = have < 1 ? 0 : have x 1000 / asked;  taken = have
        else:            received = 1000;  taken = asked
        where the unit stands in holder's acting capital:  holder.usage += taken
        province.pool -= taken

Fuel is the same, with one difference: **the pool is only lessened, and `usage` only counted,
for a unit that is moving** (`movement_order_remaining_provinces_count > 0`) **or a fleet not at
its own base**. A unit standing still is told how much it would have got and burns none. Its
`unit_demand` is counted either way, and so is a friend's payment.

So `unit_demand` - the supply share's need - belongs to **whoever holds the ground**, and a unit
drawing on a friend's depot is its own country's `TradedAway` and the friend's `TradedFor` and
`unit_demand`.

## 5. What a unit carries

`CUnit::CarrySupplies` (`0x5BED80`, the name ours): four stack arguments - the unit, a province,
a byte that picks `PARASUPPLYPOOL_DAYS` over `SUPPLYPOOL_DAYS`, and a byte that says "from the
stockpile whatever else".

    source = the owner's stockpile
    if the unit has a previous province (+0x134):
        if that province is land:  source = its pool
    else if the last byte is clear and the game is under way and the province's controller is not the owner:
        if the province's owner is not the unit's owner, or it has no depot:  nothing at all
        source = the depot's pool
    moved = min(days x SupplyConsumption, source.supplies)       and the same for fuel
    province.pool += moved;  source -= moved

Five callers:

| from | when |
| --- | --- |
| `CUnit::EnterProvince` `0x5BF313` | a **land** unit that is aboard nothing enters a **land** province other than the one it is in: called with the province entered, before `current_province_ptr` is changed |
| `RemoveFromTransport` `0x5CF1B8` | a unit put ashore, with the last byte set |
| `0x5CFE10` | every unit a fleet carries, unloaded together, the same way |
| `0x5D0990` | a unit let go by the air unit carrying it, with the parachute byte passed on |
| `RunSupplyAndConvoyIterations` `0x6790D7` | section 7 |

So **a marching army takes fifteen days of what it uses out of the province it leaves and into
the one it enters**, as far as the province it leaves has it. That, and not the network, is what
feeds an army that has walked beyond its supply lines.

## 6. Where supplies and fuel are made

Already read, in `FINDINGS-distribute.md` (section 3) and `FINDINGS-ic.md`; set down here
because it is half of what a province holds. `CDistributeSupply::Distribute` (`0x51AA80`) and
`CCountry::ConvertCrudeOilToFuel` (`0x4F19F0`) both, where arcade mode is off,
`core_home_area_ic` is above nothing and the acting capital has an area:

    for each province of the capital's area the country owns and has a core on, with IC > 0:
        share = min(1000, IC x (1000 + LOCAL_IC) / 1000 x 1000 / core_home_area_ic)
        part  = share x made / 1000
        province.pool += part;  province.current_producing = part
        outside the capital:  sent_to += part
    what is left of `made` goes to the stockpile

The share is cut to a thousandth before it is taken of what was made, so a province with 3 of
26 gets 0.115 and not 0.11538 (section 9 has exactly that on a savegame). **What is made away
from the capital reaches the stockpile only through phase 3, a province a day.**

**Only the capital's own area shares.** The list walked is the acting capital's area's, and
`core_home_area_ic` is that area's alone, so a province cut off from the capital gets no part
and is not in the divisor - though its IC is in the country's total. (This file said until
2026-10-10 that what is made in a cut-off area never reaches the stockpile; nothing is made
there.) Section 9 has it: Germany's parts are so many 133rds, and it holds 139 levels of
industry, six of them in Königsberg.

`current_producing`'s supplies and fuel are then brought back under `max_producing` - which holds
none - by `RunDailyProvincePass` the same day, so by the next morning's pass they are nothing.

## 7. A new game

`CInGameIdler::Enter` (`0x65A2B0`), for a session not loaded from a save - the byte tested at
`0x65C7FA` jumps past all of this otherwise - after the depots are given and
`CSupply::RebuildSupplyNetwork` (`0x65C611`):

    RebuildStrategicResourceProvinces, the weather run in
    RunDailyPass                                  0x65CB2E     the first day
    RunSupplyAndConvoyIterations(0, 0)            0x65CC64

and `RunSupplyAndConvoyIterations` (`0x678AB0`):

    passes = max_supply_depot_distance + 2        1 in the tutorial and in arcade mode
    the four per-province arrays, once
    repeat `passes` times:
        keep every country's stockpile                                   all seven goods
        CSupply::DailySupplyPass
        per country:
            its convoys' deliveries (those carrying supplies or fuel every time, the rest the first time)
            CUnit::ConsumeSuppliesAndFuel for every unit
            **where its capital's depot is the capital itself: the stockpile is put back as kept**
            the second time round only: three calls that set up its convoys (not read)
    every unit whose supplies received is 0:  CUnit::CarrySupplies(unit, its province, 0, 0)
    RunDailyPass                                  0x679157     the second day
    RunMonthlyPass, RunHourlyPass

Four things follow.

- **The first day comes before the filling**, on provinces that hold nothing: every unit outside
  a capital is given nothing that day, and the first day's supplies and fuel are made at the
  factories (section 6).
- **`max_supply_depot_distance` is known by then** because the first day's `RunDailyPass` sorted
  the order and read it; and the order the passes run in is that sorted one.
- **What the first day made away from the capitals is lost.** During the passes it moves inward
  a province at a time (phase 3), reaches the stockpile, and the stockpile is put back as it was
  kept. Section 9: a country's fuel two days in is short of what it started with, was given and
  refined by exactly one day's refining outside its capital.
- **A stockpile that draws on another's depot is not put back**, so it is drained in these passes
  as in any other (section 3).

The same routine is called from `ApplyCustomGameSettings` (`0x41E0A2`) for the countries a
custom game changes.

## 8. Not read

- `CConvoy::RunDelivery` beyond what `FINDINGS-convoys.md` has, and the three calls of the second
  pass that set a country's convoys up (`0x4FDF40`, `0x4FE7E0`, `0x4FD750`): how a depot across
  the sea is filled.
- What `0x5CFE10` and `0x5D0990` do beyond the calls named in section 5.
- The pool at `CCountry +0xA1C`, which the pass and the unit's draw both add to and nothing here
  explained.
- `0x688000`, called in `CInGameIdler::Enter` just before the first `RunDailyPass`.

## 9. Against the savegame

`Germany1936_01_01_00.hoi3`, the first hour of an unmodded game. The rewrite's
`OpenHOI3.SaveCheck supplypass` makes the units as the save has them, gives each country the
save's laws, ministers and technology, and then does what section 7 says: a day, the filling, a
day. Every province's `pool`, `drawn`, `last_drawn`, `throughput` and `last_throughput`, for
supplies and for fuel, is set beside the save's.

- **124 of 234 networks agree in every province and every figure**: Sweden's (210 provinces),
  Turkey's (195), Norway's (108), the Philippines' (85), Persia's (84), Saudi Arabia's (79),
  Siam's (61), South Africa's (42), New Zealand's (32) and 115 smaller ones.
- **Canada's** agrees in all but what a wrongly guessed share of IC makes: twenty provinces in a
  line from Ottawa to Halifax, each asked 0.050 more than the one behind it - 1.845 at Halifax,
  2.445 at Ottawa - and each holding exactly one day's load in passing.
- Of the provinces where a figure is something on either side, 17% of the supply figures and 76%
  of the fuel lying about are the same to the thousandth. **What differs is what goes in, not
  the pass**: the original has given most units a leader, which changes what a unit uses and is
  not in the rewrite; its AI has units on the move - fuel is asked for in 145 provinces where the
  replay burns none; and its AI moves the shares of IC after the day is run, so for 25 of 101
  countries no share makes exactly the supplies the save says were made.
- Germany's stockpile, followed on: 8496 on the fifth day and 8743 on the eighth, against the
  later saves' 8493 and 8758.

What the save shows by itself, with no replay:

- **The loss is an amount** (section 1): 5.250, 5.200, 5.150, 5.100, 5.050, 5.000.
- **The factories' parcels** (section 6): Canada made 29.923 supplies and 9.000 fuel that day,
  and each province with industry holds 1.137 and 0.342 a level - 2.274 and 0.684 with two
  levels, **3.441 and 1.035 with three**, which is 0.115 of each and not three twenty-sixths.
  `to` in the country's block is their sum outside the capital, 23.937 and 7.200.
- **Land cut off from the capital has no part** (section 6): Germany made 283.840 supplies and
  110.000 fuel, and Rostock - two levels of industry, no unit - holds 4.257 and 1.650, which is
  0.015 of each: two of 133, cut to the thousandth. Two of the 139 levels Germany holds would
  be 0.014 and 3.973. The six left out are Königsberg's, across the Polish corridor - whose pool
  holds 12.100 energy, as no province joined to Berlin does.
- **No parcel from the first day is anywhere**, in any country: neither at a factory, where a
  second would lie on the first, nor one province inward. Canada's provinces hold 689.310 fuel:
  the 581.580 it started with, 96.930 the filling put in Halifax for nothing, two days' refining
  at 9.000, **less 7.200**.
- **The drained capital** (section 3): Manchukuo's holds 7.837 supplies.
- A week on, 582 provinces with no industry hold supplies nothing was asked of: parcels on their
  way in.
