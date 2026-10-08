# The build queue: ordering, the day's work, delivery, and a new game's lines

Static reading of `hoi3_tfh.exe`, image base `0x400000`, addresses as `VA / rva`. Read on
2026-10-08 for the rewrite's build queue, and checked against five savegames of one unmodded
game played as Germany (1 January to 20 April 1936). Where a figure is from a save it says so.

`FINDINGS-production.md` has the centre of this - `CDistributeProduction::Distribute`, the
loop that pays each line of a country's queue - and `FINDINGS-oob.md` has the two meanings of
`status`. This file reads what those left: what a line costs when it is a unit of several
brigades, the term their cost has that an upgrade's does not, what finishing a unit does, the
four commands that touch the queue, and how a `military_construction` in an order of battle
becomes a line with work already done on it. It corrects four things on the way.

## 1. A line out of an order of battle

`CCountry::LoadKey` makes a `CMilitaryConstruction` for the key (`0x4CCFB2`: `new 0xAC`, the
constructor `0x483E10`), **enqueues it first** (`CCountry::EnqueueConstruction`, `0x4CCFD2`)
and only then loads its block. The loaders store what the file gives and nothing else:
`CConstruction::LoadKey` puts `cost` in `+0x30`, `duration` in `+0x34`, `progress` in `+0x38`.

Two things follow from the order. `EnqueueConstruction` calls slot 8, which is where a line
of reserves is given its `reserves_factor` - and `is_reserve` has not been read yet. So **a
file's line of reserves keeps a factor of 1**, unless the file gives `factor` itself.
(*Measured*: Belgium's one line is `is_reserve = yes`, and two days in it has gathered
experience at the full 15 of its training law, not a reserve's share.)

### The numbers it takes

`CMilitaryConstruction::AfterLoad` (`0x4848A0 / 0x848A0`, slot 5), where the file gave no
`unit`:

    construction.id = counter++            ; type 0x29, through slot 6
    if (size > 1) size = 1
    construction.unit = counter            ; type 0x29
    counter += 3
    for each brigade definition:  definition.id = counter++

The counter is the one units and brigades are numbered from (`0x170AF78`, `FINDINGS-oob.md`).
So a line takes **one number for itself, one for its unit, two that are passed over, and one
for each brigade** - five for the thirty lines the base game starts with, which all build one
brigade. Where the two go is section 4: the unit's deployment takes the one after the unit's.

(*Measured*: all thirty lines, their units and their brigades have the save's numbers.)

### What a new game does with it

Not the loader. **`CInGameIdler::Enter`**, in the per-country block of a session that was not
loaded from a save, straight after the country's officers are counted (`0x65B749`):

    for each line of the country's queue (+0xF40):
        left = line.duration                       ; +0x34, what the file gave
        line->RecalculateCost()                    ; slot 14
        progress = line.duration - left
        if (progress < 0) progress = 0
        line.progress = progress                   ; +0x38

So **a file's `duration` is the days the line still has to go**, its `progress` is thrown
away, and so is its `cost`: all three are worked out by the country as it is when the game
starts. A line with further to go than it takes starts from nothing.

(*Measured*, on Germany, whose shares nothing moved: the Graf Spee's file says `duration = 6`;
the line takes 313 days by Germany's history laws; the save two days on has `progress = 309`.
Its destroyers and submarines, 61 to go of 206 and 244: 147 and 185. For the countries an AI
runs the same holds for four of them and not for six - section 8.)

## 2. What a line costs and how long it takes

`CMilitaryConstruction::RecalculateCost` (`0x485300 / 0x85300`, slot 14) has two arms.
`FINDINGS-production.md` read the upgrade arm's defines; this is the other, which every new
unit takes (`0x48563C`..`0x48588F`):

    cost = 0 ;  duration = 0
    for each brigade definition:
        build a brigade of the definition's type on the stack
        CBrigadeConstructionDefinition::MakeDefinition(definition, brigade, &levels, &own)
        days  = CCountry::GetBuildTime(country, own, levels) * 1000
        daily = CCountry::GetBuildCostIC(country, own, levels, is_reserve)
        if (brigades_count > 1) daily = daily * days / 1000        ; IC-days
        cost += daily
        if (days > duration) duration = days
    if (brigades_count > 1 && duration > 0)
        cost = cost * 1000 / duration
    this->duration = duration ;  this->cost = cost ;  this->practical_factor = 1000

- **A unit of one brigade costs what the brigade costs a day and takes what it takes.**
- **A unit of several takes as long as its slowest brigade, and costs a day what would pay
  for every brigade's own days over that time.** An infantry brigade of 2 IC for 100 days with
  artillery of 3 IC for 60 costs `(200 + 180) / 100 = 3.8` a day for 100 days.

`CBrigadeConstructionDefinition::MakeDefinition` (`0x483120 / 0x83120`; the definition in
`ecx`, the brigade in `eax`, two stack arguments, `ret 8`):

    CSubUnit::SetType(brigade, definition->Type)
    *levels = 0
    for each node of definition->model, beside each node of brigade->technologies in turn:
        node.level = model level ;  *levels += model level
    CSubUnit::ApplyTechnologies(brigade, false)
    copy the brigade's own definition into *own

**The pairing is by position**, and stops when either list ends.

### The term an upgrade does not have

`levels` is the third argument of both `GetBuildTime` and `GetBuildCostIC`, and each adds
`levels * 10` to its multiplier (`FINDINGS-unitdaily.md`, section 6). The upgrade share
passes nothing there. The queue passes the sum of the model's levels. So:

**Every level a brigade is built with, of any of its technologies, makes it a hundredth
dearer and a hundredth slower to build.**

    cost = build_cost_ic * (1 + 0.01 * levels + by-unit-type - discount)      [* (1 + reserves_penalty_size)]
    days = build_time * max(0.05, (1 + 0.01 * levels + by-unit-type + unit_recruitment_time - discount)
                                  * (1 + the build speed modifier of its kind))

(*Measured*, exactly, on all thirty lines of the start save, under the laws the save shows:
the Graf Spee's model is `{ 0 0 3 2 3 3 1 }`, twelve levels; `6 * (1 + 0.12 + 0.05)` is its
7.020 and `280 * (1 + 0.12 + 0.05 + 0.20)` its 383 days, Germany then being on a policy that
takes 15% off industrial efficiency, four levels of the technology that gives 2.5% back, and
specialist training. Thirty of thirty for the cost and thirty of thirty for the days.)

### When it runs

`FINDINGS-production.md` has it at "exactly two moments". There are **six**:

| where | |
| --- | --- |
| `CConstructUnitCommand::Execute`, `0x546166`, and the single-unit one | when a line is queued |
| `CDistributeProduction::Distribute`, `0x51A253` | every remaining line, on a day anything was finished |
| `CMilitaryConstruction::Deliver`, `0x4851FD` | the line itself, going on to the next of a series |
| `CInGameIdler::Enter`, `0x65B76D` | every line of a new game - section 1 |
| `ApplyCustomGameSettings`, `0x41E1E4` | every line, after the country's officers are set |
| **`CChangeLawCommand::Execute`, `0x54F844`** | **every line of the country, on any change of law** |

The last is the one that shows. `CChangeLawCommand::Execute` rebuilds the country's modifier
(`0x54F817`) and then walks its queue calling slot 14, before it holds the brigades
(`FINDINGS-organisation.md`, section 5). **The work done on a line is left alone**: only cost
and duration move. That is how a line comes to have more progress than it has days - Italy's
`RM Eugenio di Savoia` has 296 of 282 in the start save, which finishes it the next time
its queue is paid.

It is still true that nothing prices a line daily: **what a practical's decay does to a cost
reaches the queue only at one of those six**. (*Measured*: Germany's destroyers are 4.860 a
day until the Graf Spee is finished in March, and 4.941 after - the practical having fallen
from 5.000 to 4.811 in two months, `-189 * 100 / 1000 = -18`, a thousandth-and-eight dearer.)

## 3. The day's work: one correction

`CDistributeProduction::Distribute` is as `FINDINGS-production.md` has it, with one step
read more closely. Where the country has no IC from lend-lease (`+0x608` nothing), per line:

    need   = cost << 30 / (1000 << 15)                   ; the cost, in fixed 15
    if (pool <= 0)  { AddProgress(0) unless flag ; next }
    if (need <= 0)    AddProgress(1000)
    else
        share  = min(1.0, (pool << 15) / need)
        wanted = share * need >> 15
        this->+0x28 += wanted
        if (GetResourceLimitedIC(country) >= wanted * 1000 >> 15)
            ConsumeICResources(country, wanted * 1000 >> 15)
            pool  -= need                                ; 0x51A172: [esp+0x38], which is need
            amount = share * 1000 >> 15
        else
            amount = 0                                   ; and pool is left as it was
        AddProgress(amount)

**What comes off the pool is the whole of a day's cost, not what was paid.** The earlier
reading had `pool -= frac * need`. For a line paid in full the two are the same; for the line
the share runs out on, this leaves the pool below nothing and every line after it gets
`AddProgress(0)`, where the other would have left a sliver to be shared out. And a line the
stockpile refuses takes nothing off the pool, so a cheaper line after it can still be paid.

(*Measured*: two days of this on Germany's three lines give the save's `progress`,
`accumulated_progress`, `accumulated_experiance` and `status` on all three; and with the
queue's 13.982 IC in, Germany's industry used 121.187 on the save's last day, which is the
save's own figure to the thousandth - 44.823 on consumer goods, 31.191 on supplies, 31.191
on upgrades.)

## 4. Finishing a unit

`CMilitaryConstruction::Deliver` (`0x484A60 / 0x84A60`, slot 9, `this` in `ecx`, bare `ret`,
answers a `bool`). `Distribute` calls it when `progress >= duration` and removes the line when
it answers 1.

    if (the country is not REB and owns no province (+0xCF8 <= 0))  return 1
    if (brigades_count == 0)                                        return 1

    if (accumulated_progress < 1000)
        accumulated_experience += (1000 - accumulated_progress) * rate / 1000
            ; rate = GetStartExperienceRate: the country's UNIT_START_EXPERIENCE,
            ;        times reserves_factor / 1000 for reserves

    make the unit by the first brigade's type: CNavy for a ship, CAir for a wing, else CArmy
    unit.id = this->unit ;  unit.owner = this->country

    for each brigade definition:
        make a CShip, a CWing or a CRegiment ;  id = definition.id ;  name = definition.name
        CSubUnit::SetType(brigade, definition->Type)
        is_reserve = this->is_reserve
        experience = max(definition.experience, accumulated_experience), no more than 100
        if (builder != country)  brigade.builder = builder
        gain = definition->Type->completion_size          [* reserves_factor / 1000 for reserves]
        CCountry::GainTechAbility(country, Type->technology_category, gain * practical_factor / 1000)
        definition.id += 1
        the model's levels onto the brigade's technologies, by position
        CSubUnit::ApplyTechnologies(brigade, false)
        strength_ceiling = 0 ;  owner = country
        strength = max_strength * reserves_factor / 1000, no more than slot 12 allows, not below 0
        strength_ceiling = max(strength_ceiling, strength)
        organisation = CSubUnit::GetMaxOrganisation(brigade, 1, 1), not below 0
        AddRegimentToUnit(unit, brigade)

    name the unit: the line's name for a land unit, else its first brigade's
    accumulated_experience = 0 ;  accumulated_progress = 0

    make a CUnitDeployment, id = (unit type, unit id + 1), holding the unit
    append it to the country's deployments (+0x688)
    this->unit id += 2

    if the line has a target that is a unit, and the unit may join it: deploy it there at once
    post the message

    progress -= min(duration, progress)
    size -= 1
    if (size > 0)
        RecalculateCost()
        if (is_reserve) reserves_factor = 1000 + RESERVES_PENALTY_SIZE
    return size <= 0

Six things about it:

- **The experience a unit is built with is its country's `unit_start_experience` at the rate
  of each day it was paid for.** Each day adds `rate * (amount * 1000 / duration) / 1000`, and
  whatever of the building was never counted - the days a file's line starts with, mostly -
  is counted at delivery at the rate of that day. A change of training law half way through
  shows in what comes out.
- **The practical is gained in full, once, when the unit is done**: `completion_size`,
  through the same diminishing gain research uses.
- **Organisation is set before the brigade is put in its unit.**
  `CSubUnit::GetMaxOrganisationWithBonus` skips the commander, the reserve's share and the
  officer ratio alike for a brigade whose unit pointer is null (`0x5AB878`,
  `FINDINGS-unitstart.md`, section 8). So a new brigade has `default_organisation` times its
  branch's modifier and nothing else, whatever its country's officers.
- **A unit finished is not on the map.** It is a deployment, and its deployment takes the
  number after its own - which is one of the two numbers a file's line passes over. The other
  is where the next unit of a series would start, at the unit's number plus two; that puts
  its deployment on the number of the first brigade, so the numbers of a series collide. The
  thirty lines of the base game are all of one.
- **A series subtracts a whole unit's days and goes on**, with what was left over, at a price
  worked out afresh.
- **A country that owns no province is delivered nothing**, and the line is dropped as done.

(*Measured*, exactly: the Graf Spee is in the 1 April save as a `unit_deployment` numbered
240 holding fleet 239 and ship 242, with `experience = 24.940`, `strength = 100.000` and
**`organisation = 30.000`** - its own figure, where Germany's officers would allow 42. The
experience is the 3.040 the 1 March save shows, fifteen more days at `25 * 0.002`, and
`(1 - 0.154) * 25` for what was never counted. Germany's `cruiser_practical` goes from 4.811
to 6.276 over the month: 1.6 gained, then April's decay.)

## 5. Ordering

`CConstructUnitCommand::Execute` (`0x545BA0 / 0x145BA0`, slot 6). `FINDINGS-production.md`
has what it copies and the "build it now" flag. The rest:

    make the line ;  size = cmd.amount (+0x70) ;  is_reserve = cmd.is_reserve (+0x74)
    slot 8                                  ; reserves_factor = 1000 + RESERVES_PENALTY_SIZE
    if (!build now) CCountry::EnqueueConstruction(line, country)
    if (cmd has more than one brigade) name the unit
    men = 0
    for each brigade the command lists:
        name it ;  CMilitaryConstruction::AddBrigade(line, definition)
        build the brigade on the stack as section 2 does
        one  = CCountry::GetBuildCostManpower(country, own definition, is_reserve)
        men += one
        country.manpower -= one * amount                  ; not below 0
    line.manpower = men
    line->RecalculateCost()
    CCountry::UpdateManpowerAfterMobilising(country) ;  CDistributeProduction::UpdateNeeded

`CCountry::GetBuildCostManpower` (`0x4E1880 / 0xE1880`, `ret 0xC`):

    factor = 1000 + technology_status->build_cost_mp_by_unit_type[type]
    if (reserves) factor += RESERVES_PENALTY_SIZE
    if (factor < 50) factor = 50                          ; g_OneTwentieth
    return definition->build_cost_manpower * factor / 1000

- **The men are taken when the unit is ordered, for the whole series at once**, and the line
  remembers what one unit took.
- **Reserves take the share of their men the conscription law leaves**, never less than a
  twentieth.
- **Nothing in `Execute` asks whether the country has the men**: the pool is floored at
  nothing. Whatever refuses an order the country cannot man is before this.

## 6. Cancelling and moving

`CCancelUnitConstructionCommand::Execute` (`0x548550 / 0x148550`, slot 6): finds the line by
its id; **for a unit, gives back `size * manpower`** - the men of every unit still to come -
unlinks it, refreshes the share's need, and frees it. Nothing of the IC spent comes back.

`CChangePriorityCommand::Execute` (`0x5489F0 / 0x1489F0`, slot 6), by the number at `+0x4C`:

| | |
| --- | --- |
| below -1 | unlinked, and pushed on the front |
| -1 | put before the line before it |
| 1 | put after the line after it |
| above 1 | unlinked, and appended |
| 0 | nothing |

There is no priority but the order: `Distribute` pays the first line first.

## 7. Placing

`CDeployUnitCommand::Execute` (`0x5490D0 / 0x1490D0`, slot 6): finds the deployment; with a
target unit, and the deployment being a unit's, joins it to the target (`0x5067D0`); otherwise
calls the deployment's slot 9 with the province and takes it off the country's list. Its slot
14, `0x5495A0`, the "may I run" test, asks only that the deployment exists.

`CUnitDeployment::CanDeployIn` (`0x57D390 / 0x17D390`, slot 10, `ret 4`):

    if the unit is a fleet:       the province's naval base (+0x300) must have a level above 0
    else if it is an air unit:    the province's air base (+0x304) must
    in an ordinary game:          capital(country)->area (+0x2B4) == province->area

**A unit is placed in the area its country's capital is in** - `area` being the `COwnerArea`
of `FINDINGS-aiplans.md`, a block of land under one owner. A second rule stands in for the
last line in one kind of session (`0x57D3F9`..`0x57D452`: the province's controller must be
the country); which kind was not read.

`CUnitDeployment::DeployAt` (`0x57D480`, slot 9) adds the unit to the country's list
(`0x4E06F0`) and calls `CUnit::EnterProvince`. The rest of it is messages and was not read.

## 8. What the production screen writes in a line

`CBuildQueueEntry::Update` (`0x7F4C90 / 0x3F4C90`, slot 8 of the `CBuildQueueEntry` in the
production screen's own namespace, bare `ret` at `0x7F5A36`) on a `queue_entry` window:

| element | |
| --- | --- |
| `production_queue_green`, `_orange`, `_red` | green where `status > 990`, orange where `status > 0`, red otherwise |
| `production_speed` | `status * 100`, no decimals, and `%` |
| `ic_cost` | `cost` to two decimals, and the text of the key `IC` straight after |
| `eta_date` | `CConstruction::GetEtaText` |
| `series_info` | `+` and `size - 1` where `size > 1`, else nothing |
| `prodqueue_progress` | `progress * 1000 / duration`, as a whole percentage |
| `production_queue_naval`, `_division`, `_air`, `_buildings` | one of them, by what the line is |

and the constructor (`0x7F4140`) finds `cancel`, `max_prio`, `prio`, `non_prio` and
`max_non_prio`, `original_country`, gives `counter_type` the sprite `GFX_counter_` and the
first brigade's type key, writes `unit_name`, and `unit_target` as `=> ` and the target's
name. The handlers behind the five buttons were not read.

`CConstruction::GetEtaText` (`0x483870 / 0x83870`):

    pace = status ;  if (progress == 0) pace = 1000
    if (pace == 0) return "---"
    left = (duration - progress) * 1000 / pace            ; thousandths of a day
    if (left has a fraction of a day) left += 1000
    the date that many whole days on

**So `status` has readers**, which `FINDINGS-oob.md` says it has not: these two. A line no
day has touched is dated as if it were paid in full.

## 9. Against the savegames

Run by the rewrite's `tools/OpenHOI3.SaveCheck`, 2026-10-08.

The start save, two days in:

| | agree |
| --- | --- |
| a line's number, its unit's and each brigade's | 30 of 30 |
| the model each brigade will be built with | 30 of 30 |
| cost a day, under the laws the save shows | 30 of 30 |
| days, under the laws the save shows | 30 of 30 |
| progress, counted share, experience and status two days on: Germany | 3 of 3 each |
| the same: the countries an AI runs | 4, 12, 12 and 14 of 27 |
| where a line stood as the game started, by the save's less at most two days' work | 16 of 30 |
| what Germany's industry used on the last day | 121.187 of 121.187 |

Four later saves of the same game, each pair run forward from the earlier with every line
paid in full, for the countries whose lines were:

| | agree |
| --- | --- |
| progress, counted share and experience over 31, 28, 31 and 19 days: Germany | 10 of 10 each |
| the same: the others | 26 of 26 each |
| cost and days at the later save: Germany | 10 of 10 |
| the same: the others | 24 and 25 of 26 |
| a finished unit's experience | 5 of 5 |
| Germany's finished ship: strength and organisation while it waits | 1 of 1 each |

**What does not agree is the AI's.** Six countries' lines - Britain's, the United States',
Japan's, France's, Belgium's and the Netherlands' - stood somewhere else as the game started
than their history's laws or the save's put them: `CInGameIdler::Enter` priced them under
laws or ministers their AI has since changed again. The United States' destroyers and
carriers are 0.03 of a multiplier out, which is one minister's `industrial_efficiency`; the
others were not worked through. And the two
lines whose price differs at a later save are in countries where something else was finished
in between - a building or a convoy, which prices every line again too.

## What is not established

- **The upgrade arm of `RecalculateCost`** beyond its three defines: what makes a line an
  upgrade is its first brigade definition having `+0x38` set, which the key
  `upgrading_from_subunit_str` fills by a look-up in the sub unit database. Who queues one
  is the command at `0x5DA7C0`, which enqueues a line for a brigade in the field and takes
  the difference in men (`0x5DAE04`..`0x5DAE67`); it was read for that and no further, and
  its class was not found from its address.
- ~~**What refuses an order** the country cannot man or may not build: not `Execute`.~~
  *Read since: the windows a unit is ordered from disable `accept`, and nothing after that
  asks. `FINDINGS-builders.md`, sections 1, 2 and 6.*
- **The handlers behind a queue line's five buttons.** ~~and the three builder windows that
  post `CConstructUnitCommand`~~ *The windows are four, and are `FINDINGS-builders.md`.*
- **`CUnitDeployment::DeployAt` past its first two calls**, and the second placing rule of
  section 7.
- **`CBuildingConstruction` and `CConvoyConstruction`**: their slot 9 and slot 14 were not
  read. They share the queue and the day's loop.
- **`CCountry +0x158`**, which `0x4DCD70` fills after an order: the manpower pool, plus a
  term from the technology status, less what bringing every reserve - in the field and in
  the queue - to full strength would take. Read as far as that and named for it.
- **The date `GetEtaText` formats**, past the arithmetic.
- **Why six countries' lines start where they do** - section 9.

## In the record

Entered in `ghidra/project.json` by `fragments/merged/buildqueue.json`: fifteen new
functions, six revised, and five struct fields, one of them a revision that matters to the
DLL - `CBrigadeConstructionDefinition +0x44` is a `CList<int>`, not a vector of ints.
