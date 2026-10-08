# What a unit draws each day: supplies and fuel, reinforcement and upgrades

Static reading of `hoi3_tfh.exe`, image base `0x400000`, on 2026-10-08. Addresses are given as
`VA / rva`. The game was not running. Written because the rewrite's next step needed four
things read through that the record only had in outline: what a unit asks for in supplies and
fuel, and the three things that change a brigade from one day to the next without a battle -
troop rotation, the reinforcement share and the upgrade share.

Where a savegame is quoted it is a vanilla Their Finest Hour game played as Germany: the save
of 1 January 1936, hour 0, and four later saves of the same game up to 20 April. Those figures
are marked **measured**. Everything else is read off the bytes.

`FINDINGS-manpower.md` has rotation and the reinforcement loop's counters;
`FINDINGS-production.md` has the shape every share's `Distribute` has; `FINDINGS-supply.md` has
the supply network. This file reads the two bodies those left as call lists, and corrects two
things on the way.

## 1. The order of a country's day, as far as its units go

`RunCountryDailyPass` (`0x4DA530 / 0xDA530`), per country, in this order:

    0x4DB291   for each unit of the country:  unit->vf32()          ; CUnit::UpdateDaily
    0x4DB2C0   for each finished unit waiting to be placed (+0x688, kind 0x4B4):
                   CUnit::ConsumeSuppliesAndFuel(unit)
    0x4DB418   the economy block (FINDINGS-distribute.md, section 1)
    0x4DB4F3       the six IC shares in index order: ... supply (3), reinforcement (4), upgrade (5)

and inside `CUnit::UpdateDaily` (`0x5BAF70 / 0x1BAF70`):

    dig in (land, at war, standing still)
    0x5BB146   troop rotation                     ; FINDINGS-manpower.md, and section 3 below
    0x5BB323   CUnit::UpdatePlanForceNeeds        ; only below oob_level 4
    0x5BB32C   CUnit::ConsumeSuppliesAndFuel(this)
    0x5BB3E8   attrition and, for a fleet, the transport overload check

So within one day: **a unit loses its rotated men by yesterday's supply figure, then draws
today's supplies; and only afterwards does its country make supplies, reinforce and upgrade.**
A unit still in the deployment queue eats too.

`CUnit::ConsumeSuppliesAndFuel` (`0x5BB950`) has exactly three callers: those two, and
`0x678FD9` in the function at `0x678AB0`, which `FINDINGS-supply.md` has as the pass
`CInGameIdler::Enter` runs once as a game starts.

## 2. What a unit asks for

`CUnit::SupplyConsumption` (`0x5BB560 / 0x1BB560`) and `CUnit::FuelConsumption`
(`0x5BB7A0 / 0x1BB7A0`), with the per-brigade pair `0x5AD0F0` and `0x5AD300` that the
interface uses. `CLASSES.md`, *Supply and fuel consumption*, describes them; read again here
instruction by instruction, with two things added and one corrected.

    potency = 1000
    if (!withoutLeaders)
        potency = 1000 + owner.modifier[MODIFIER_SUPPLY_CONSUMPTION]        ; 49
        hq = the unit, or the first unit above it, whose oob_level is 1     ; the army group
        if (hq found && unit->current_province (+0x130) != 0)
            potency -= hq->leader->skill * 1000 * 50 / 1000 * CommandReach(unit, 1) / 1000
        potency += CommandEffect(unit, 2)
        if (potency < 0) potency = 0

    for each brigade of the unit
        p    = potency + floor((float(brigade->extra_consumption (+0xCC)) + 0.0005) * 1000.0) * 10 / 1000
        used = definition->supply_consumption (+0x110) * p / 1000
        if (!unit->IsNaval())                                               ; slot 16
            used = used * (brigade->strength * 1000 / definition->max_strength) / 1000
        total += used

    if (unit->IsLand() && order->vf16() == 0x5A4)                           ; a strategic redeployment
        total = total * STRAT_REDEP_SUPPLY_MOD / 1000                       ; military +0x1E8

and for fuel the same potency and the same `p`, on `fuel_consumption` (`+0x114`), **with no
strength term at unit level**, and nothing at all for a land unit on a strategic redeployment.

- **`extra_consumption` is the sum of every technology level the brigade holds.** The record
  already says so (`CSubUnit +0xCC`, read live on 10,254 sub units); the consequence is worth
  stating in words: **every level of anything a brigade is equipped or trained with makes it
  use a hundredth more supplies and fuel.**
- **`+0x130` is `current_province_ptr`, not the leader.** The test before the army group
  commander's discount is that the *unit* stands in a province; the leader is read off the
  headquarters at `+0x12C` with no null test of its own.
- **The strategic redeployment define is `STRAT_REDEP_SUPPLY_MOD`** (`military +0x1E8`), 2.0 in
  Their Finest Hour: a redeploying army uses twice the supplies and no fuel. `CLASSES.md` had
  the supply half as "still consumed".
- **The per-brigade fuel routine does scale by strength** (`0x5AD477`..`0x5AD4D4`, the same
  shape as the supply one), where the unit-level one does not. So the fuel figure a brigade
  shows by itself and the fuel its unit is charged are not the same sum. Only the unit-level
  pair is called by anything that moves goods.

`withoutLeaders` is 0 at both callers that move goods - `ConsumeSuppliesAndFuel` and the
starting stockpile (`0x4D7066`..`0x4D708B`, `FINDINGS-leadership.md` section 10).

**Measured.** A save keeps one figure of this: a country's `usage.supplies` is what its units
*standing in its capital* were given, plus what the supply network took out of the capital
(the province's `throughput`). Taking the throughput off and adding up the formula above over
the units the order of battle puts in the capital, with no leaders: France 7.590 against the
save's 7.590, Denmark 2.159 against 2.159, and the same to the thousandth for 38 of the 65
capitals whose garrison the save shows fully supplied. The other 27 are short of a leader the
save has given a unit there, or of a unit the files do not give - Germany is 17.670 against
16.474, with a theatre commander in Berlin - and in the six capitals where the save shows a
unit that asked and was given nothing, the save's figure is nothing.

## 3. The draw

`CUnit::ConsumeSuppliesAndFuel` is already recorded with both of its paths. What the reading
adds:

**The arcade path, in full** (`gamestate +0xC9C > 0`, `0x5BBA4A`..`0x5BBC2E`):

    payer = the expeditionary owner where the unit has one, else the owner
    if (wantSupplies > 0)
        taken = min(wantSupplies, GetPool(payer).supplies)
        GetPool(payer).supplies      -= taken
        payer->unit_demand.supplies  += wantSupplies            ; +0xA48, what was asked
        unit->supply_received         = taken * 1000 / wantSupplies
    if (unit is moving (+0x140 > 0)  ||  (unit->IsNaval() && !CUnit_IsAtOwnBase(unit)))
        if (wantFuel > 0)
            the same for fuel, into +0xA4C and unit->fuel_received

Nothing is booked to `usage` on this path, and a unit that wants nothing keeps the figure it
had. **Fuel is drawn only by a unit that is moving and by a fleet out of its own port**, on
both paths.

**On the network path, `usage.supplies` is the capital's own garrison.** At `0x5BC197` the
amount actually taken is added to the supplying country's `usage.supplies` (`+0x994`) only
when the unit's province is that country's acting capital; `+0xA24` gets what was asked on the
same test. That is what makes the measurement in section 2 possible.

## 4. `CDistributeReinforcement::Distribute`, read through

`0x51BA60 / 0x11BA60` to the `ret 0x10` at `0x51C669`. `FINDINGS-manpower.md` has the three
counters and the manpower pricing; this is the rest.

    budget = thousandths(percentage * available * factor)
    free   = thousandths(percentage * factor * lend_lease_ic (+0x608))
    country: reinforcement_cost (+0xA98) = manpower_needed (+0xA9C) = manpower_used (+0xAA0) = 0

    list = empty
    for each unit of country->units (+0xBAC):
        skip one with an expeditionary owner (+0x290), and one whose reinforcements_active (+0xA6) is clear
        if (unit->+0xA4)  put it at the FRONT of the list   else  at the back
    for each unit of the country's second list (+0xBBC):    the same, without the expeditionary test

    reserveCost = max(1000, -modifier[RESERVES_PENALTY_SIZE] * 5000 / 1000)
    repair      = 1000 + modifier[MODIFIER_UNIT_REPAIR]                     ; 53
    startExp    = modifier[MODIFIER_UNIT_START_EXPERIENCE]                  ; 52

    for each unit in the list:
        crowding = 1000
        if (!unit->IsLand() && unit->home_base (+0x98) != 0)
            based = 1000 * the brigades of every unit at that base
            room  = a fleet: NavalBaseCapacity(the base's province)
                    an air unit standing on its own base: based        ; so the ratio is 1
                    an air unit elsewhere: the base province's +0x304 -> +0x24
            if (based > 0) crowding = room * 1000 / based
            crowding = clamp(crowding, 250, 1000)                      ; 0x1A87710, floor(250.5f)

        for each brigade of the unit:
            if (!CanReinforce(brigade)) continue                       ; 0x5AC1C0, below
            max     = brigade->GetMaxStrength(0, 0)
            full    = definition->max_strength
            scale   = max * 1000 / full
            missing = max - strength
            share   = missing * 1000 / max
            if (share <= 0) continue                                   ; see below
            whole   = definition->build_cost_manpower * scale / 1000   ; the men a full brigade takes
            needed  = share * whole / 1000

            speed   = (1000 + modifier[MODIFIER_REINFORCEMENT_BONUS])  ; 86
                      * repair / 1000 * crowding / 1000 * unit->supply_received (+0xFC) / 1000
            aDay    = full * 1000 / 30000 * 500 / 1000                 ; 0x1A87730, floor(500.5f)
            gain    = speed * aDay / 1000
            men     = gain * whole / 1000 * 1000 / max
            if (men <= 0) continue

            afford  = manpower <= 0 ? 0 : min(manpower * 1000 / men, 1000)
            gain    = gain * afford / 1000
            used    = men  * afford / 1000
            ic      = max(definition->BuildCostIC, 1000) * afford / 1000
            if (brigade->is_reserve) ic = ic * reserveCost / 1000
            ic      = ic * definition->repair_cost_multiplier (+0x104) / 1000

            if (strength + gain >= max)                                ; a day would overfill it
                exact = missing * 1000 / speed
                part  = exact * 1000 / gain
                used  = used * part / 1000 ;  ic = ic * part / 1000 ;  gain = exact

            if (budget > 0)
                paid = ic * afford / 1000
                if (free > 0) { charge = paid - free ; free -= paid } else charge = paid
                if (charge > 0) ConsumeIcResources(country, charge)
                strength = clamp(strength + gain, 0, GetMaxStrength(0, 0)), and strength_ceiling raised to it
                g   = gain * 1000 / max
                exp = max(experience, 0) + (brigade->pride ? PRIDE_BONUS_EXP : 0)      ; military +0x68
                experience = min((1000 - g) * exp / 1000 + g * startExp / 1000, 100000)
                manpower = max(manpower - used, 0)
                budget  -= ic
                manpower_used += used
            reinforcement_cost += ic
            manpower_needed    += needed

    *out = 0

`CanReinforce` is `0x5AC1C0 / 0x1AC1C0`, the brigade in `esi`, a bool in `al`, bare `ret`:
false unless `strength < GetMaxStrength(0,0)`, that maximum is positive and the brigade is in a
unit; false for a land unit that is in a combat (`+0x11C > 0`), for any unit that is
retreating (`+0x158`), for a land unit that is being carried (the unit's slot 9 answers an
object whose `+0x300` or `+0x304` is set); and for a ship (the brigade's slot 10) false unless
the unit's province is one whose info byte `+0x22` is set - **a ship is reinforced only in a
province that is land, which is to say in port.** The name is ours.

In words, and the first two are the ones a player sees:

- **A brigade is not touched until it is short by a thousandth of what it may have.** `share`
  is an integer number of thousandths, and at zero the brigade is skipped: under 0.030 short
  for a brigade of 30, under 0.015 for a reserve held to 15.
- **Topping up divides what is missing by the speed.** Where a day's `gain` would overfill the
  brigade, what is added is `missing * 1000 / speed`: all of what is missing at a speed of 1,
  and 87% of it for a country with ball bearings (`unit_repair = 0.15`). A unit on half its
  supplies would be given twice what is missing, which the clamp then cuts back to its maximum
  - and it would be charged for the twice.
- **A day at full speed brings back a sixtieth of a brigade's full strength**: half of a
  thirtieth. Both numbers are compiled in.
- **It costs a twentieth of the brigade's build cost a day**, whatever the day brings back:
  `repair_cost_multiplier` is 0.05 on all 57 of Their Finest Hour's unit types, and `ic` has no
  term in `gain` until the overfill branch scales it. A brigade cheaper than 1 IC a day is
  priced as 1.
- **A reserve costs five times the share of it that its conscription law keeps back**: 3.75
  times a regular on a volunteer army, 2.5 on a two-year draft, and never less than 1.
- **The share overspends by one brigade.** The test is `budget > 0` before the brigade, and the
  whole `ic` comes off after it.
- **The men who arrive bring a new unit's experience** and dilute what the brigade had, by the
  share of its full strength that they are.
- **`PRIDE_BONUS_EXP` is added to the pride of the fleet's stored experience every time it is
  reinforced**, before the dilution. Read twice (`0x51C573`..`0x51C58C`); it looks like a
  getter's bonus written back, and is recorded as read, not as understood.
- **The slider's need is `reinforcement_cost`**: the sum of `ic` over every brigade past the
  thousandth, whether or not anything was spent on it.

**Measured, and it is the first rule that the saves show.** Two days in, every regular German
brigade of 30 is at 29.996 and every reserve of 15 at 14.998 - two days of rotation at the
two-year draft's 0.03 and no reinforcement at all, although the share had 31 IC. A month later
they stand at 29.986 and 14.993, and across the five saves the missing strength of a reserve is
always half a regular's: 4 and 2, 13 and 7, 15-18 and 8-9, 25-28 and 13-14, 11-14 and 6-7.
That is a sawtooth, not a balance: a brigade loses 0.002 (or 0.001) a day until it is 0.030 (or
0.015) short, is topped up in one day to within a few thousandths, and starts again.

## 5. `CDistributeUpgrade::Distribute`, read through

`0x51CE60 / 0x11CE60` to the `ret 0x10` at `0x51D5B5`. Recorded until now as "not read line by
line".

    budget = thousandths(percentage * available * factor)
    free   = thousandths(percentage * factor * lend_lease_ic)
    this->+0x20 (an __int64, fixed 15) = 0 ;  country->upgrade_cost (+0xAA4) = 0 ;  spent = 0

    list: first the country's second list (+0xBBC), then its own units (+0xBAC) less those with
          an expeditionary owner; each needs upgrade_active (+0xA5); +0xA4 puts one at the front

    status = country->technology_status
    host   = a government in exile: the technology_status of the first member of its faction
    for each unit in the list, each brigade, each node of brigade->technologies (+0x84):
        technology = node->technology
        if (!technology->canUpgrade (+0x314)) continue
        level = status->level_by_technology[technology->Index]        ; the higher of it and the host's
        if (level <= node->level) continue

        days = CCountry::GetBuildTime(country, brigade->definition, 0)
        rate = max((1000000 / (days * 1000)) * 2000 / 1000, 1)        ; 0x1A8776C, floor(1.5f)
        rate = rate * (a ship: SHIP_UPGRADE_SPEED_MOD,  a wing: AIR_...,  else LAND_...) / 1000

        cost = definition->BuildCostIC
               * (1000 + status->build_cost_by_unit_type[type] - GetCategoryBuildDiscount(country, definition->category)) / 1000
        if (brigade->is_reserve) cost = cost * (1000 + modifier[RESERVES_PENALTY_SIZE]) / 1000
        daily = (cost * 1000 / (brigade->technologies.count * 1000))
                * (500 * 1000 / ((level - node->level) * 1000)) / 1000

        if (!technology->change (+0x288)) { daily = 0 ; progress = 1000 }
        else                                progress = rate
        pays = daily
        if (daily > budget) { progress = budget * 2000 / 1000 * progress / 1000 ; pays = budget }

        if (progress > 0)
            node->progress += progress
            if (node->progress >= 1000)
                node->progress = 0 ;  node->level += 1 ;  a level was gained
                if (technology->change && the unit is not on loan to this country) brigade->builder = brigade->owner
            spent += pays ;  budget -= pays
        country->upgrade_cost += daily
        the brigade is upgrading

    after a brigade's technologies:
        if it is upgrading:      this->+0x20 += 0x8000                  ; one more, in fixed 15
        if a level was gained:   CUnit::RebuildDefinition(unit, 0), or CSubUnit::ApplyTechnologies(brigade, 0) for one in no unit

    if (free > 0) spent -= free
    if (spent > 0) ConsumeIcResources(country, spent)
    *out = 0

In words:

- **A brigade is brought up one level of one technology at a time, every technology it is
  behind in at once.** The country's level is compared with the brigade's own, node by node.
- **A day moves a level on by `2 / days to build`, in whole thousandths, the fraction dropped
  before the doubling.** Light armour that takes 160 days gets `1000 / 160 = 6`, doubled, 0.012
  a day: 84 days a level. Ships take the define's four times that, so a destroyer of 200 days
  gets `5 * 2 * 4 = 0.040` a day.
- **A day of one technology costs half the brigade's price, spread over every technology the
  brigade lists, and divided again by how many levels behind it is.** So being further behind
  costs no more a day, and a brigade behind in everything by one level pays half its build
  cost a day until it has caught up.
- **A technology with `change = no` - a doctrine - costs nothing and takes a day a level**,
  whatever the share is given, including nothing. **One with `can_upgrade = no` is never
  brought up at all**: 19 of Their Finest Hour's technologies say so.
- **When the share runs out, the technology it runs out on gets `budget * 2 * rate`** - the
  last of the money doubled and multiplied by the day's rate, with no division by the cost -
  and everything after it gets nothing. The order is the list's, which is the order of the
  units' numbers.
- **The slider's need is `upgrade_cost`**: every `daily`, spent or not. `this->+0x20` is the
  count of brigades upgrading, which the slider's tooltip prints as `$UNITS$`.
- **The resources are charged once, at the end**, for the day's total.

`CSubUnitTechnology` is `{technology, level, progress, ?, next}`: the node's `+0x10` is the
link the loop follows.

**Measured, and exact for the country nothing had touched.** Running two days of this on what
the orders of battle make, with the save's shares and technology and the laws its last day ran
under, reproduces the save's `{level progress}` pair on **all 1,469** of Germany's
technology lines - 0.024 on light armour, 0.032 on motorised, 0.036 on cavalry and
interceptors, 0.020 on bombers, 0.080 on destroyers - **including where the share ran out**:
Germany's 31.191 IC covers its units in number order up to the third wing of its fifth air
unit, whose first technology has 0.008 where its neighbours have 0.020 and whose others have
nothing, and the three wings after it have nothing. Two days of `0.206 * 2 * 0.010`. Every
doctrine a country knew better than a brigade is on the brigade two days in: 10,235 of 10,235.
For the other countries 22,993 of 25,179 lines agree; their shares are moved by the AI, and
what is left is mostly a share that was nothing on the day and is something in the save, or the
other way round.

## 6. What a unit costs and how long it takes, as the upgrade share asks

`CCountry::GetBuildTime` (`0x4E19A0 / 0xE19A0`) and `GetCategoryBuildDiscount`
(`0x4E1AC0 / 0xE1AC0`) are both recorded. Read again for this, with one correction and one
name.

    GetCategoryBuildDiscount(country, category):
        a = max(ability in the category, 0) - 5000        ; the country's own, or a sharer's if higher
        if (a < 0)   d = a * 100 / 1000
        else       { if (a > 1000) a = FixedPointSqrt(a) ;  d = a * 50 / 1000 }
        d += modifier[MODIFIER_INDUSTRIAL_EFFICIENCY] + technology_status->+0x94
        return min(d, 990)

    GetBuildTime(country, definition, bonus):
        f = bonus * 10 - GetCategoryBuildDiscount(country, definition->category)
            + modifier[MODIFIER_UNIT_RECRUITMENT_TIME] + 1000 + status->build_time_by_unit_type[type]
        s = 1000 + modifier[one of ROCKET_, TANK_, AIR_, NAVAL_, LAND_BUILD_SPEED]
            ; chosen by is_rocket (+0x33), is_armor (+0x34), is_air (+0x2C), is_ship (+0x2E), in that order
        return max(s * f / 1000, 50) * definition->BuildTime / 1000 / 1000        ; whole days

- **Past one point over the expected 5, the surplus goes through `FixedPointSqrt`** - the
  routine research uses for the same purpose - before it is worth a twentieth a point. The
  record's comment said "everything past 1.000 halved first", which is the square root's first
  guess read as the whole of it. `cmp eax, 0x3e8; jle; ... call 0xa9cec0` at `0x4E1B78`.
- **`CTechnologyStatus +0x94` is what the technology key `ic_efficiency` adds up to** - the
  effect of `industral_efficiency` (the files' spelling), 0.025 a level. Named from its one
  reader and from a measurement: without it Germany's upgrade share runs out four wings early
  and every build time comes out a tenth long; with Germany's four levels, 0.10, both are
  exact. So **industrial efficiency takes its 2.5% a level off the cost of every unit and off
  its build time alike**, and its neighbour at `+0x90` (`ic_modifier`) is a different thing.
- The definition's category is the unit type's `on_completion`: the practical it feeds is the
  practical that discounts it.

## 7. `CDistributeSupply::GetNeeded`

`0x51B660 / 0x11B660`, slot 3 of `CDistributeSupply` (`0x15C2208`), `this` in `ecx`, `ret 4`.
Unread until now.

    supplies = unit_demand.supplies (+0xA48) + traded_away.supplies (+0x7E4)
               - tribute_sent.supplies (+0x928) - traded_for.supplies (+0x874) - tribute_received.supplies (+0x904)
    if (supplies <= 0) return 0
    return supplies / (IC_TO_SUPPLIES * (1 + technology_status->supply_production_bonus + modifier[GLOBAL_SUPPLIES]))

So **the supply slider's need is the IC that would make the supplies the country's units asked
for today**, with what it trades and pays in tribute on either side. The divisor is exactly
what `CDistributeSupply::GetSuppliesMade` multiplies by.

## 8. A unit's three switches

`CUnit`'s constructor (`0x5B5010 / 0x1B5010`) writes `mov word ptr [edi+0xa4], 0x100` and
`mov byte ptr [edi+0xa6], 1` at `0x5B5410`: **a unit starts with upgrades on, reinforcement on
and no priority**, and `supply_received` and `fuel_received` at 1000 (`0x5B52A1`). The save
writes the three as `is_prioritized`, `can_upgrade` and `can_reinforce`.

`+0xA4` is recorded as `upgrade_prio`. Both shares read it, and for the same thing - which end
of the list the unit joins - so it is the unit's priority for reinforcement as much as for
upgrades. The name is left as it is and the comment says so.

## What is not established

- **The country's second unit list, `CCountry +0xBBC`.** Both shares walk it beside the
  country's own units and without the expeditionary test, so units lent *to* the country are
  the obvious reading. Nothing here read what fills it, and it is not named.
- **`CUnit::CommandEffect` and the army group commander's discount were not re-read**, and the
  leaders they need are what the measurement in section 2 is short of.
- **Why some countries start with up to a fifth more fuel than the formula gives.** All
  the fuel in the provinces a country holds, less two days' refining, is the starting
  stockpile's `days * fuel a day` exactly for 18 of the 76 countries that have a capital to
  themselves, and within a few units for about twenty more, where the estimate of two days'
  refining is the likelier fault. But twenty-five hold 2% to 19% more than the rule gives,
  and they come in bands: France 19%, Italy 17%, Siam, Lithuania, Turkey, Australia, Canada
  and China 15% to 16%, Mexico, the United Kingdom and Czechoslovakia 14%, the United States
  and Republican Spain 13%; then Argentina, Germany, the Netherlands, Finland, Belgium and
  Japan 7% to 9%, Norway 6%; then Brazil, Yugoslavia, Portugal, Greece and Sweden 2% to 4%.
  The excess does not follow the size of the country, and the top band has landlocked
  countries in it, so it is not the fleets. **What those countries have in common was not
  found.** The Soviet Union holds a quarter *less*, which is about what the Comintern's
  faction modifier (`supply_consumption = -0.33` in `ideologies.txt`) would take off if a
  faction's modifier reaches the country's; not read. So the starting fuel stands as a
  reading and only partly as a measurement.
- **What the AI's training law was on the two days.** Germany fits its history's training law
  for the two days, the law its units were made under, and not the one the save shows; 34 other
  countries fit a law out of their history better than the save's for training or for
  industrial policy. That the AI changes laws after the last daily pass is already in
  `FINDINGS-distribute.md`; these are two more groups of them.
- **`NavalBaseCapacity` and the air base's `+0x24`** as the room a base has for reinforcing:
  the crowding term was read and neither figure was followed.
- **Which technology keys fill `build_cost_by_unit_type` and `build_time_by_unit_type`.** No
  technology file of Their Finest Hour has a key that looks like one, and both read as zero in
  every measurement here.
- **The pride of the fleet's bonus** in the reinforcement loop, section 4.
- **Everything live.** Nothing here was watched happening; the measurements are of savegames.

## In the record

Entered the same day through `fragments/merged/unit-daily.json`: `CSubUnit::CanReinforce`
(`0x1AC1C0`), `CDistributeSupply::GetNeeded` (`0x11B660`) and `CUnit::CUnit` (`0x1B5010`) new;
`CDistributeReinforcement::Distribute`, `CDistributeUpgrade::Distribute` (from `inferred` to
`confirmed`), `CCountry::GetCategoryBuildDiscount`, `CUnit::SupplyConsumption`,
`CRegiment::FuelConsumption` and `CUnit::ConsumeSuppliesAndFuel` revised; three globals -
`g_ReinforcementCrowdingFloor` (`0x1687710`), `g_ReinforcementDailyShare` (`0x1687730`) and
`g_UpgradeLeastRate` (`0x168776C`); and the comments of `CUnit +0xA4`, `+0xA5`, `+0xA6` and
`CTechnologyStatus +0x94`. The names are ours.
