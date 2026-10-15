# A building line: ordered, priced, finished and placed

Read statically on 2026-10-15, in **the building-queue wave** (`WAVE.md`), for OpenHOI3's build queue, which held
units only. Image base `0x400000`; addresses as `VA / rva`. It extends `FINDINGS-buildqueue.md`, which covers a unit
line. Two readers: A, the command, who posts it, the price and the day's work, the line on the production screen, and
the saves; B, the delivery, the building waiting to be placed, the placing test and the deploy menu and map for a
building. The fragments are `fragments/merged/building-line-ordered.json` and `building-finished-placed.json`.

**What it corrects**, so a reader of the older text knows which sentences to discount:

- `CConstructBuildingCommand::LoadKey` reads five keys, not three (`country` and `amount` besides).
- `CConstruction::CanStillBeBuilt` (`0x4831C0`) never runs on a building line: `CBuildingConstruction` has its own slot
  12 (`0x4864C0`), which cancels lost-province lines and enforces the underground's rules.
- `FINDINGS-oob.md`'s "both build commands call AddProgress when an item is queued" is wrong for this command.
- `CBuildingConstruction::Deliver` raises only `level_max`: the working level is left to the day's repair. It does not
  refresh the area's bases, the province's modifier or radar.
- `CBuildingDeployment::DeployAt` refreshes the area's bases where **a naval base makes a port**, not "where an air base
  appears".
- `CProvinceBuilding_OnLevelChanged` does nothing for any building but infrastructure, and its "message through
  `0x47F540`" is `UpdateOwnerAreaOfProvince`.
- `CBuilding`'s `prerequisites` and `not_if_x_exists` are not unread: they are resolved at load into two building lists
  (`+0x9C`, `+0xBC`) that `CCountry::IsBuildingAllowed` reads.
- `FINDINGS-buildqueue.md` section 9's "a finished building or convoy prices every line again" holds, and is not
  building-specific: any day a line is finished and removed reprices every line.
- `WAVE.md`'s list of production-screen building buttons was one short: both installs also have `industry`.
- The start save holds no building line: Their Finest Hour's history has none.

---

## A. A building line ordered and priced

Checked against seven saves of 1936 (4, 7 and 8 January, 1 February, 1 March, 1 April, 20 April).

### A.1 The command, `CConstructBuildingCommand`

Type id 0x1C3, 0x58 bytes, base `CCommand`.

| field | what it holds | saved as |
| --- | --- | --- |
| `+0x3C` | the building | `building`, the building's index |
| `+0x40` | the province id; **0 means a line to be placed later** | `province` |
| `+0x44` / `+0x48` | the id the new line will take | `id` |
| `+0x4C` | how many | `amount` |
| `+0x50` | the country | `country` |

`LoadKey` (`0x545310 / 0x145310`) reads all five. `SaveContents` (`0x545180`) writes them in the order `country building
id amount province`.

**The constructor** (`0x544E10 / 0x144E10`, `ret 0x14`) takes `this`, the building, the province and the tag on the
stack, and **the amount in EDI**. It mints the line's id from the persistent-id counter at `0x1A857F8`: the type is
`0x1268 + word[0x1A857EC]`, which is 4713 in every save. The counter then moves on by `1 + 3 x amount`.

**`Execute`** (`0x544EF0 / 0x144EF0`, slot 6):

    level = province.buildings[building.index].level_max / 1000            ; truncated
    if (cmd.province != 0)
        for each line of the country's queue, head to tail:
            if it is a building line (slot 16), same location, same building:
                level += line.size ;  found = line                            ; the LAST match
    if (found)
        add = amount ;  if (amount + level > max_allowed_level) add = max_allowed_level - level
        found.size += add                                                     ; not priced again
    else
        new CBuildingConstruction: status 1000, size = amount (uncapped), the country's tag,
            the building, the command's id ; builder stays "---"
        CCountry::EnqueueConstruction                                         ; appended at the TAIL
        slot 14                                                               ; priced
    if (cmd.province != 0)  line.location = province ;  slot 8 (a no-op on a building line)
    CDistributeProduction::UpdateNeeded

- **Nothing is charged when you order, nothing is refused and nothing is said.** There is no AddProgress, no IC and no
  message.
- **A province order joins a line already queued there**: the last line for the same building in the same province, up
  to the building's `max_level`.
- **An order without a province always makes a new line**, with any size at all.

**`IsValid`** (`0x545540`, slot 14) is the only gate. The channel's post asks it, and the session's pump asks it again
just before `Execute` (`FINDINGS-commands.md`). A command that fails is deleted silently.

    building null                -> false
    province < 0                 -> false
    province == 0                -> true                ; a production-screen order is never checked
    else CCountry::IsBuildingAllowed(country, building, province)

`CCountry::IsBuildingAllowed` is B.3's.

### A.2 Who posts it

**1. The production screen.** `CProductionView::AttachButtons` (`0x7FBE20`) attaches every building whose file says
`capital = yes`, in the database's order, by its key. In both installs that gives eight buttons: `air_base`,
`naval_base`, `industry`, `anti_air`, `radar_station`, `nuclear_reactor`, `rocket_test`, `underground`.

A press goes to `CProductionView::OnBuildingButton` (`0x8025C0`). It finds the building by the element's name and opens
**`CConfirmBuild`** (`0x7F1800`) on the `confirm_build` window (`interface/confirmbuild.gui`) in mode 0, closing any
dialog already open at `+0x318`. **No province is asked for.** The dialog:

- **`label`** shows the building's name. **`photo`** shows the sprite `picture_` + the building's key, which exists for
  every building.
- **`serial_value` and `paralell_value`** both start at 1.
- **`serial_plus`, `serial_minus`, `parallell_plus` and `parallel_minus`** (the file's spellings) step by 1, or by 10 with
  Ctrl. Their tooltip is `BUILD_ADD_REM_BUNDLE`, "Ctrl + LMB to add or remove $NUM$", with NUM = 10. Held down, a stepper
  repeats after 0.3 s and then every 0.1 s (inferred). Update keeps both counts at 1 or more, disables a minus at 1 and
  disables a plus at 99 or more.
- **`ic_cost_value`** is `parallel x the building's cost a day` (`CCountry::GetBuildCost`), to two decimals.
- **`build_time_value`** is `serial x days` (`CCountry_GetBuildingBuildDays`), written as `N Days` up to 365 and `N/30
  Months` (truncated) above that. The keys are `DAYS` "Days" and `MONTHS` "Months".
- **One of `selected_brigade_green`, `_orange` and `_red` is shown.** The spare IC is the IC the production slider gives
  (its share x factor x TotalIC) less the summed daily cost of every queued line: green where spare - parallel x cost >=
  0, orange where spare > 0, red otherwise.
- **`on_complete_icon`** shows `icon_` + the category key. **`on_complete_impact`** shows `+` and `completion_size` to one
  decimal.
- **`accept` ("Start Production") is never disabled.** It posts `parallel` separate commands, each
  `CConstructBuildingCommand(building, province 0, country, amount = serial)` (`CConfirmBuild::OnAccept`, `0x7F3980`).
  **`cancel`** ("Close") posts nothing.

So **parallel 3 and serial 2 makes three lines, each of two buildings, all without a province.** The button itself is
the only refusal on this road: Update enables it from `building_available`, and the underground's from
`CCountry_CanTrainUnderground` (`FINDINGS-countryviews.md` section 4, `FINDINGS-productiontooltip.md` section 6).

**2. The province view.** Each building has a `building_member` with a `building_icon` button
(`province_interface.gui`). A click runs `CBuildingMember::OnClick` (`0x6DBE40`). For **every selected province the
player controls** where `IsBuildingAllowed` holds, it posts `CConstructBuildingCommand(building, province id, the
province's controller tag, amount 1)`: **one level per click per selected province**, which Execute merges into a line
already queued there. In a custom game's setup it posts `CCgmSetBuildingLevelCommand` instead, behind
`IsBuildingAllowedIgnoringLevel` (`0x4DFE70`; read from the decompile only). The button's enabling, `0x6DC380`, was not
read whole.

**3. The AI's Lua**, `tfh/script/ai_production_minister.lua`:

| line | building |
| --- | --- |
| 1368 | underground (at `GetRandomUnderGroundTarget()`, only if that is above 0) |
| 1395 | nuclear_reactor |
| 1425 | rocket_test |
| 1454 | industry |
| 1487 | land_fort (the capital, only after `IsBuildingAllowed`) |
| 1514 | coastal_fort |
| 1539 | anti_air |
| 1564 | radar_station |
| 1589 | air_base |
| 1620, 1633 | infra |
| 1667 | naval_base |

`ai_support_functions.lua` 617 has one more. Every call is `CConstructBuildingCommand(tag, building, provinceID, 1)`,
then `IsValid()`, then `ministerAI:Post`, and `GetBuildCost(building):Get()` comes off its budget. **The AI always names
a province.** All 171 lines in the saves have a `location`; none has `builder` or `count`.

**The save grammar** is `building_construction = { id = { id type } size cost duration progress status location
country building }`. `count` appears only when it is non-zero, and `builder` never does on these lines.

**History.** Their Finest Hour's history has no building lines. BlackICE's has some (for example
`history/units/Forts_JAP.txt`, `size=3 duration=0 location=5759 building=4`). `CCountry::LoadKey` reads one through the
constructor `0x4858F0`, enqueues it, and then reads the block, as for a unit line. By `FINDINGS-buildqueue.md` section 1
a new game then prices it, so a file's `duration = 0` means its first building is already due (inferred; the Enter loop
was not re-read).

### A.3 The line and its price, `CBuildingConstruction`

The line is 0x60 bytes. The base fields are as recorded. `+0x40` (size) is **how many buildings are still to deliver**.
`+0x58` is the building. `+0x5C` (`count`) is not the number ordered: it numbers the deployments a line makes (B.2).

| slot | address | what |
| --- | --- | --- |
| 9 | `0x485BD0` | Deliver, B.2 |
| 10 | `0x486300` | GetSaveToken: 636, `building_construction` |
| 11 | `0x486450` | IsUnderground |
| 12 | `0x4864C0` | CanStillBeBuilt, A.4 |
| 13 | `0x486310` | GetName: the building's name, plus `" (" + province + ")"` where the line has a location |
| 14 | `0x485B30` | RecalculateCost, below |

`RecalculateCost` (`0x485B30 / 0x85B30`):

    d    = GetCategoryBuildDiscount(country, building.category)           ; the on_completion category
    cost = building.cost * (1000 - d) / 1000                               ; 64-bit, truncated  -> +0x30
    days = (building.time * 1000 * (1000 - d) / 1000) / 1000               ; whole days         -> +0x34 = days * 1000

with `GetCategoryBuildDiscount` as `FINDINGS-unitdaily.md` section 6 has it:

    a = max(ability in the category, 0) - 5000
    term = a < 0 ? a * 100 / 1000 : (a > 1000 ? FixedPointSqrt(a) : a) * 50 / 1000
    d = min(term + INDUSTRIAL_EFFICIENCY + ic_efficiency, 990)

- **Compiled in:** the expected 5.000 ability, the 100 and 50 per point, the rough square root, and the 990 cap.
- **From the files:** `cost`, `time` and `on_completion` in `buildings.txt`; `industrial_efficiency` in `laws.txt`
  (consumer_product_orientation -0.15, heavy_industry_emphasis +0.05) and `minister_types.txt` (die_hard_reformer
  +0.03); `ic_efficiency` on `industral_efficiency`, 0.025 a level.

| buildings | category |
| --- | --- |
| air_base, naval_base, coastal_fort, land_fort, industry, infra | construction_practical |
| anti_air | artillery_practical |
| radar_station | electornicegineering_practical |
| underground | militia_theory |
| nuclear_reactor | nuclear_bomb |
| rocket_test | rocket_practical |

**So one building costs a day, and takes, `cost` and `time` scaled by the same factor, and nothing else**: no levels
term, no by-type term and no build-speed modifier (unit lines have all three); no 0.05 floor, the cap of 990 leaving at
least 1%; no reserves; **no practical_factor**. `size` is not in it: several of one building on one line cost one
building's day each, built one after another. The practical gain is B.2's.

**When it runs** - the queue-wide callers of slot 14 (`FINDINGS-buildqueue.md` section 2): `Execute`, on a new line;
`CDistributeProduction::Distribute` (`0x51A253`), on every remaining line after a line was finished and removed;
`CInGameIdler::Enter`, for a new game; `CChangeLawCommand::Execute`. **A line merged by a province order is not priced
again.**

Worked examples (practical 0 with consumer_product_orientation gives d = -650): land fort 5 x 1.65 = **8.250 IC a day
for 297 days**; air base **6.600 for 148** (148.5, truncated). With an artillery practical of exactly 5.000, anti-air
comes out at **3.450 for 69** (d = -150).

### A.4 The day's work

`Distribute` treats a building line exactly as it treats a unit line (`FINDINGS-buildqueue.md` section 3): the need is
its `cost`; it is paid in queue order, from the share and then from resources; whatever the pool cannot cover gets
`AddProgress(0)`, and no IC carries over. **There is no gearing and no serial-run term**: the line's slot 20 is the
folded `ret 4` (`0x60CD50`). Status starts at 1000 from the constructor, which is why a line not yet paid reads
`status=1.000 progress=0.000` (TIB, 4 January).

**Slot 12 (`0x4864C0`) is the building line's own** and is asked first every day. Where it answers false the line is
unlinked and freed, with no message (`FINDINGS-production.md` step 1), in three cases:

- **a located line for anything but the underground, in a province the country no longer controls**;
- **an underground with no location**, the first day `CCountry_CanTrainUnderground` fails (not at war, in exile, or
  nowhere to put one);
- **an underground with a location**, where the province already has an underground, or fails
  `Underground_CanPlaceIn`'s test.

`CConstruction::CanStillBeBuilt` (`0x4831C0`) is held only by military and convoy lines, whose location is always null,
so it never cancels anything.

**Measured:** at full speed a line gains exactly 1.000 a day. CZE's anti-air at 2562 goes 3.000 -> 6.000 -> 7.000 across
4 Jan 12:00, 7 Jan 14:00 and 8 Jan 07:00. POL's land fort at 1626 goes 88.097 -> 107.097 between 1 and 20 April.

### A.5 The line on the production screen

`CBuildQueueEntry`'s constructor (`0x7F4140`) picks by kind, in this order: slot 17 (a unit), slot 15 (a convoy), slot
16 (a building). For a building:

- **`counter_type`** takes the sprite **`icon_build_` + the building's key**. Every building but the underground has
  one; the underground keeps the file's `GFX_temp_unit_icon`.
- **`unit_name`** is slot 13: "Anti-Aircraft Guns (Praha)", or just "Anti-Aircraft Guns" for an unplaced line.
- **`unit_target`** is not written; **`original_country`** is hidden, the builder being `---`.

Update (`FINDINGS-buildqueue.md` section 8) is the same as for a unit: `production_queue_buildings`, `series_info`
`+size-1`, cost, ETA, progress.

**The tooltip** (`0x7F5A40`): the five buttons say what they say on any line; `counter_type`, `series_info`,
`unit_target` and `production_queue_division`, `_air` and `_naval` give **an empty tooltip** on a building line, the
brigade part needing slot 17; anything else gives the status sentence - `PEN_FULL_SPEED` "This production is going
ahead at full speed.", `PEN_PARTIAL_PROGRESS` "...only progressing at §Y$PERC$%§W...", or `PEN_NO_PROGRESS`.

**The five buttons** are the same on every kind of line:

| button | what it does |
| --- | --- |
| `cancel` (`0x7F66B0`) | a confirm with `CONFIRM_CANCEL_CONSTRUCTION_TITLE` "Cancel Construction?" / `_DESC` "Are you sure you wish to cancel this construction?", carrying `CCancelUnitConstructionCommand`, which gives a building line back nothing. **With Ctrl** (`CANCEL_MULTI_CONSTRUCTIONS_DESC`) it gathers every line of the same kind and building, in any province, with no more progress than this one; two or more open `CMultiCancelPrompt` |
| `prio` (`0x7F6F90`) | `CChangePriorityCommand` -1, one place forward |
| `max_prio` (`0x7F7040`) | -2, to the front |
| `non_prio` (`0x7F70F0`) | +1, one place back |
| `max_non_prio` (`0x7F71A0`) | +2, to the back |

### A.6 Against the savegames

The scratch `oracle.py` predicts each line's cost and days from the save's own figures: the category practical,
`industrial_policy_laws`, and the `industral_efficiency` level through FixedPointSqrt. Building indices are the file's
position + 1 (air_base 1 ... anti_air 5), which the cost and time pairs fix.

| save | agree |
| --- | --- |
| 4 Jan | 21 of 21 |
| 7 Jan | 21 of 22 |
| 8 Jan | 21 of 22 |
| 1 Feb | 22 of 23 |
| 1 Mar | 22 of 24 |
| 1 Apr | 24 of 28 |
| 20 Apr | 28 of 31 |

**159 of 171.** The 12 that miss: **9 lines of CYN and PHI** (8.100 / 291 where 8.250 / 297 is predicted) match exactly
with d - 30, both heads of state (Long Yun, Manuel Quezon) being `die_hard_reformer`, +0.03 industrial efficiency;
**2 lines of FRA's naval base** (4.970 / 178) match the d = +6 FRA's January construction practical of 7.500 gives,
priced then and not since; **1 line of ITA's air base on 1 April** (5.428, d = -357) was priced before its practical
decayed, and by 20 April it agrees (5.444). No line finished between two saves of one game. B.6 adds that line ids at
one place differ between saves (Denmark's land fort in 1482 is line 2626 on 1 March and 1948 on 1 April, its progress
continuing): match lines across saves by place and building, not by id.

### A.7 What looks wrong but is what the bytes do

1. A production-screen order has no province, and `IsValid` passes province 0 without asking anything. Only the
   button's disabled state stands between a player and an unavailable building.
2. The size of a new line is never capped, by the dialog (99, and beyond with Ctrl) or by Execute. A province order is
   capped only when it merges.
3. A province order merges into the **last** matching line, and a merged line is not priced again.
4. A line's price ignores its size, and the days are truncated (90 x 1.65 gives 148).
5. There is no floor on building time but the 990 discount cap.
6. The confirm dialog's colour compares `parallel x cost` with what the production slider leaves over the whole queue;
   serial does not enter it.
7. `accept` is never disabled.
8. An unplaced underground line is silently cancelled the first day its country cannot train one.
9. A located line is silently cancelled when the province's controller changes.
10. `original_country` is hidden on building lines, and hovering a building line's icon shows nothing.
11. The underground has no `icon_build_` sprite.
12. Ctrl-cancel matches lines in every province.
13. The command reserves `1 + 3 x amount` ids.

### A.8 Not settled

- That the in-game screen's `+0x1C` slot 12 is the Ctrl key (taken from the `BUILD_ADD_REM_BUNDLE` and
  `CANCEL_MULTI_CONSTRUCTIONS_DESC` texts).
- The repeat timer's slot meanings, and the floor the -10 steppers clamp to.
- That `[esp+0x50]` in Update's colour test is `parallel x cost` (from the stack bookkeeping and the decompile).
- That the minister's `industrial_efficiency` reaches the discount - inferred from the CYN and PHI lines matching
  exactly.
- How a close byte becomes a destroyed dialog.
- `CBuildingMember`'s enabling (`0x6DC380`) and which buildings get a member.
- The custom-game arm of the province view.

Frontier: `0x2DC380` (CBuildingMember's update), `0x2DB560` (its constructor), `0x109920`
(CCountry::GetRandomUnderGroundTarget), `0xB8B60` (building database find-by-name), `0x1496A0`
(CConstructConvoyCommand's constructor), `0x3F3CA0` (stepper press start), `0xE02F0` (GainTechAbility, still without a
signature), `0x1B370` and `0x1B700` (custom-game building level).

---

## B. A building finished and placed

It continues `FINDINGS-buildqueue.md` sections 4 and 7, which cover a unit finished and placed.

### B.1 In one line

- `CDistributeProduction::Distribute` calls a building line's slot 9 when `progress >= duration`.
- With a province, one level is added to the province's building, **as built (`level_max`) and not as working**. With
  no province, a `capital = yes` building is put in the country's deploy menu.
- The built level is filled by the day's repair, about 0.11 a day on full roads.
- `BUILDING_DONE` goes only to the player who controls the province.
- A building in the deploy menu is placed by a left click on a province the map shows green; the click is the only
  check.
- Every line is priced again on any day a line is finished, unit or building.

### B.2 `CBuildingConstruction::Deliver` (`0x485BD0`, rva `0x85BD0`, slot 9)

Bare `ret`, answers a `bool`. In order:

    if (country is not REB and owns no province (+0xCF8 <= 0))   return 1

    if (building->category (+0x88) answers its slot 2)            ; always: both tables hold `mov al,1`
        CCountry::GainTechAbility(country, category, building.completion_size)

    if (building.capital (+0x60) and line.location (+0x44) is null)
        d = new CBuildingDeployment(country)                      ; 0x3C bytes
        d.id = (line.id_type, line.id + count + 1) ;  d.building = line.building
        CCountry_AddDeployment(country, d)                        ; the back of +0x688
        count += 1                                                ; no message
    else if (line.location)
        b = province.buildings[building.index]
        b.level_max += 1000 ; capped at max_level * 1000 ; floored at 0
        CProvinceBuilding_OnLevelChanged(b)
        if (building is the underground)                          ; FINDINGS-occupation.md E.2
            level_current += Underground_GetInitialStrength(province, country), capped
            underground_owner = country ; CCountry_AddUnderground ; template +0x20 = 1
        if (local player == province.controller)
            BUILDING_DONE  NAME = the building's name, PROV = the province's name
                           both shield countries the province's owner

    progress -= min(duration, progress)
    size -= 1
    (custom game, stage 2, the country on the game state's +0x60 list: settings +0x6C = 1)
    if (size > 0)  slot 14                                        ; price the next of a series
    return size <= 0

**1. The practical is gained in full, once, when the building is done** - `completion_size` into the building's
`on_completion` category, through the diminishing gain research uses. Unlike a unit's (`FINDINGS-buildqueue.md`
section 4) it is **not** multiplied by the line's `practical_factor`: the body never reads `+0xA0`. It is gained before
the line decides where the building goes, so a line that ends up building nothing still pays out its practical.

| building | category | gain |
| --- | --- | --- |
| air base, infrastructure | `construction_practical` | 0.13 |
| industry | `construction_practical` | 0.67 |
| naval base, both forts | `construction_practical` | 0.33 |
| anti-air | `artillery_practical` | 0.25 |
| radar | `electornicegineering_practical` | 0.5 |
| underground | `militia_theory` | 0.1 |
| nuclear reactor | `nuclear_bomb` | 6 |
| rocket test site | `rocket_practical` | 6 |

**2. A line with a province adds one built level, and nothing works yet.** `level_current`, the level every reader of
the building's effect uses, is left alone, and so is the province's modifier, which adds `effect_size x
level_current` (`FINDINGS-occupation.md` A.7, step 2). The new level is filled by `RunDailyProvincePass`
(`FINDINGS-bombing.md` section 11):

    roads = infrastructure x (1000 + infrastructure modifiers) / 1000, held to 10..1000
    rate  = (100 + roads) x (1000 + repair_rate) / 1000
    mend  = BUILDING_REPAIR_SPEED x rate / 1000              ; 0.1 in Their Finest Hour

`level_current = min(level_max, level_current + mend)` each day, for every building whose file does not say `repair =
no`. The `changed` byte is set every day it moves, so the hourly pass rebuilds the province's modifier within the hour.
So **a level phases in over about ten days on full roads** (0.11 a day); with infrastructure 3 it is 0.04 a day, 25 days;
with none 0.011 a day. The underground has `repair = no` and its own strength (E.2), which is why it alone is raised
here. *Inferred*: the rate is the daily pass's, read in other waves; no save holds a building part built (B.6).

**3. Nothing else is touched.** `CProvinceBuilding_OnLevelChanged` (`0x4B7FA0`, rva `0xB7FA0`) returns at once unless the
building's modifier is `MODIFIER_INFRASTRUCTURE` (`0x4B7FC4`). For infrastructure it is `FINDINGS-aifields.md`'s live
writer of `MaxInfrastructure`: crossing 100 or 200 thousandths, it moves the province in or out of its owner area
(`UpdateOwnerAreaOfProvince`, which the record had as "a message"), rebuilds the area and supply groups, sets
`theatres_dirty` on the neighbours' owners and the controller, and calls `UpdateSupplyDepot`. No refresh of the area's
ports and air bases (`COwnerArea::RefreshBases` has eleven callers, none of them `Deliver`); no rebuild of the
province's modifier and no radar bookkeeping - radar is picked up by the modifier's rebuild (`FINDINGS-occupation.md`
A.7 step 13) once the repair moves `level_current`. The country's `AirBases`/`NavalBases` lists (+0xD70/+0xD80) are
filled from controlled provinces with `level_max > 0` by `CCountry::RebuildNeighbours` (`0x4E2F6A`-`0x4E3014`), the
daily rebuild, so a new base joins them at the next one. The CPort a naval base needs is map geometry, made at load and
never by a building.

**4. A capital building with no province goes to the deploy menu**, as a `CBuildingDeployment` holding the building,
numbered off the line's own id plus `count` plus one; `count` then goes up, which is all it is for. The country is told
nothing. No save has such a line: all 259 building lines across the twelve saves have a `location` (B.6).

**5. The message.** Gate: `CCurrentGameState +0xC34 == province +0x338` - only the local player, and only where he
**controls** the province. `BUILDING_DONE` (`messagetypes.txt`, both installs: `log=yes onmap=yes popup=no option=yes`,
`cat_province`): log and map "$NAME$ has been built in $PROV$."; header "Building is complete."; popup lines "$NAME$" /
"in the province" / "$PROV$" / "is completed."; Goto callback the thunk `0x522400`, the in-game screen's slot 78
(`0x64AB10`, not read). `NAME` is the building's slot 6, the string at `CBuilding +0x38`, looked up as a key, so it reads
"Naval Base" either way; `PROV` the province's `GetName`. **Both shield countries are the province's owner**; `DeployAt`
gives controller and owner.

**6. Every line priced again.** `Distribute`, after its loop, where any `Deliver` answered 1 (`0x51A236`-`0x51A261`):
`CCountry::RebuildStaticModifiers(country)`, then slot 14 for each line left. That is any line removed as done - a unit,
a building, or one dropped because the country owns nothing. A series going on to its next item (answers 0) does not
trigger it.

### B.3 `CBuildingDeployment`, and where a building may go

`CDeployment`'s child, 13 slots. Constructor `0x482A80` (rva `0x82A80`; this in EAX, the country by value, `ret 8`): its
id (type, serial) at +8/+0xC, the base's byte and empty string at +0x10/+0x14, `country` at +0x30/+0x34, `building` at
+0x38; 0x3C bytes. Made by `Deliver` and by `CCountry::LoadKey`'s `building_deployment` arm (`0x4CD950`). Saved as
`building_deployment` (token `0x4B7`, which slot 8 answers) with `id` and `building` (the index; `LoadKey` `0x57EDB0`).
Slot 11 (`0x57ED80`, rva `0x17ED80`) is its name: the building's slot 6.

**`CanDeployIn`** (`0x57E480`, rva `0x17E480`, slot 10, `ret 4`); the country is the deployment's:

    if (province has no CPort (+0x354) and building.port)          no
    if (!CCountry::IsBuildingAllowed(country, building, province)) no      ; BiceLib hooks 0x57E4E5
    if (building is the underground)
        no if the province's underground has a level
        yes if: its controller is at war with the country (REB counts),
                the country is a friend of its owner (military access counts),
                and the country is a major, or MaxIC > 100, or owns it
    else
        no unless the province's controller is the country
        naval base: no unless the province's naval base has level_max 0
        air base:   no unless the province's air base has under one whole level
        yes

**`CCountry::IsBuildingAllowed`** (`0x4DFFC0`, rva `0xDFFC0`, `ret 8`; the Lua API's `CCountry:IsBuildingAllowed`):

    no unless technology_status.building_available[index]      ; a researched activate_building
    no unless country is the province's controller             ; skipped for the underground
    no unless whole built levels + the size of every queued building line of this building
              in this province < max_level
    no if the province has no CPort and the building is port = yes
    no if any building of the resolved not_if_x_exists has a level here
    no if any building of the resolved prerequisites has none
    yes

Callers: `CanDeployIn`, `CConstructBuildingCommand::IsValid`, `CBuildingMember::OnClick` (the province view's building
button) and that button's update (`0x6DC380`) twice.

| key | where it bears |
| --- | --- |
| `max_level` | caps built plus queued in that province; also caps `level_max` in `Deliver` and `DeployAt` |
| `port` | needs the province's CPort: a naval base's map position on non-landlocked sea |
| `prerequisites`, `not_if_x_exists` | resolved into buildings at load by `CBuilding_ResolveBuildingLists` (`0x4B6EF0`, rva `0xB6EF0`), which logs "Unknown building '...' referred to in prerequisited list." and "Building '...' defined as its own prerequisit." and frees the names. Neither install uses them |
| `capital` | not asked here: it decides only that a line with no province makes a deployment, and which production-screen button exists |
| `onmap`, `visibility` | only the map picture (`FINDINGS-seaair.md` section 6) |
| `orientation`, `show_for_province` | read by neither function |

The terrain is never asked, and the owner not but for the underground: a country may put a deployed base in an
occupied province it controls. **A deployed naval base or air base can only be a new one**; the other five capital
buildings may be stacked to `max_level`.

**`DeployAt`** (`0x57E640`, rva `0x17E640`, slot 9, `ret 4`):

    hadPort = province owned and has a CPort and its naval base has level_max > 0
    hadUnderground = its underground has level_max > 0
    b.level_max += 1000, capped, floored ; CProvinceBuilding_OnLevelChanged(b)
    if (!hadPort and province owned, CPort, naval base level_max > 0)
        COwnerArea::RefreshBases(province.area)
    if (!hadUnderground and the underground now has a level)
        the underground as in Deliver, owner = the deployment's country
    if (local player == province.controller)
        BUILDING_DONE  NAME, PROV ; shields: the controller, then the owner

`level_current` is untouched here too. **A deployed naval base puts its province among its area's ports at once; a
deployed air base, and any base a line builds in place, does not.**

### B.4 The deploy menu and the map, for a building

**The line** (`CDeploymentEntry`, `0x826F40`): `name` the deployment's slot 11, the building's name; `counter_type` and
`counter_size` hidden, only a unit's deployment (slot 8 = `0x4B4`) showing them; the tooltip (`0x826CA0`) empty, it
answering only for a unit's deployment. Lines are in the order things were finished.

**Choosing it** (`CDeploymentEntry::OnSelect`, `0x827650`): `CInGameIdler::SetDeploymentBeingPlaced(deployment)` (slot
30); for a building's deployment, slot 46 (`0x656CD0`) instead of the target list - the selection emptied, the orders
view closed. The menu stays on its plain list.

**`SetDeploymentBeingPlaced`** (`0x667DB0`, rva `0x267DB0`): pushes the current map mode (slot 98); stores the
deployment's id at `+0x158/+0x15C`; takes the air or naval mode's icons down if one was on; sets the mode (`+0xD34`, and
the map's `+0x2A90`) to **14**; sets the settings' `+0xE7 = 0`, layer mask `+0xF0 = 0xFFBA`, map style `+0xF4 = 11`;
hides the province objects' `+0x98` picture, paints, refreshes the colour textures. With null: clears the id and pops
the mode (slot 99). **Mode 14 has no lines of its own in the province tooltip** (`FINDINGS-mapmode.md`).

**The colours** (`MapMode_Deployment_Colour`, `0x867A00`, rva `0x467A00`), every province from index 1, alpha 1:

| | red, green, blue |
| --- | --- |
| everywhere | 0.5, 0.5, 0.5 |
| `CanDeployIn` says yes | 0.5, 0.9, 0.5 |
| the underground, where yes | 0.5, 0.6 + 0.3 x initial / `UNDERGOUND_INITIAL_STRENGTH` (0.4), 0.5 |

The underground's `initial` is `Underground_GetInitialStrength` for the **player's** country, in single precision.
Painted once, when the line is chosen. The same routine paints for a unit's deployment through
`CUnitDeployment::CanDeployIn`; this raises `FINDINGS-occupation.md` E.3 from inferred.

**The click** (`CInGameIdler_HandleInput`, `0x652540`, rva `0x252540`): the left button's release over the map, with
nothing dragged, where a deployment is being placed and there is a province under the pointer -

    if (deployment.CanDeployIn(province))
        post CDeployUnitCommand(province, the player, the deployment, no target)
        SetDeploymentBeingPlaced(0)
    else
        the click goes on as an ordinary click; nothing is said, the line stays chosen

**The command** (`CDeployUnitCommand::Execute`, `0x5490D0`, rva `0x1490D0`): with no target, `DeployAt(province)`, the
deployment taken off the country's list and freed; with a target found and a building's deployment, nothing, the
deployment staying. **Nothing in the command asks where**: slot 14 asks only that the deployment exists. Once the
country's count of deployments changes, the menu rebuilds its list, and closes when it is empty
(`FINDINGS-deploymenu.md` section 2).

**What is told:** `BUILDING_DONE`, from `DeployAt`, to whoever controls the province - the placer, but for the
underground, the occupier.

### B.5 What looks wrong but is what the bytes do

- **A finished building does not work on the day it is finished**: zero working level, repaired up - about ten days on
  full roads, ninety with none.
- **The practical for a building is never scaled by the line's `practical_factor`**, where a unit's is.
- **A base a line builds in a province is not added to its area's port or air base list** until the area is touched: a
  change of controller in it, an infrastructure crossing, a load. A deployed naval base is added at once; a deployed air
  base never is, until the area is touched.
- **A deployed naval base or air base can only be a new one.**
- **The deployment path tells the player nothing.**
- **The two messages differ in their shields**: owner and owner from `Deliver`, controller and owner from `DeployAt`.
- **`BUILDING_DONE` goes to the controller, not the builder.**
- **The map's colours are made once per chosen line.**
- **Choosing a second line while placing the first pushes mode 14 onto the mode stack**; placing then pops 14, which goes
  to the terrain setter, and the original mode stays on the stack (*inferred*, from the push and the pop).
- **The placing click is checked only on the clicking machine**; the command checks nothing.
- **`prerequisites` and `not_if_x_exists` work**, though neither install uses them.

### B.6 Against the saves

Twelve saves, 1 January to 20 April 1936. **No deployments**: no save holds a `building_deployment` (positive control:
`unit_deployment` once each in the 1 February, 1 March, 1 April and 20 April saves - the Graf Spee). All 259 building
lines have a `location` (163 land forts, 29 each of air base, naval base and coastal fort, 7 anti-air, 2 rocket test
sites); none saves a `count`. **Province buildings**: the one non-infrastructure building that changed is
Czechoslovakia's anti-air in province 2631, absent at the start and `{ 1.000 1.000 }` on 1 April and 20 April - a line
finished and repaired full. No save holds a non-infrastructure building part built. The pair a save keeps is current
then maximum: province 9980's infrastructure is `2.224 3.000` on 1 February after fighting, mended to `3.000` by 1 March.

### B.7 Not settled

- That a new level comes in at zero working level, and how long it takes to fill, against a running game.
- `CBuilding +0x38`: whether it holds the key or its text. Either way the message shows the text.
- When `alert_deployable_units` is up.
- What the in-game screen's slot 78 (`0x64AB10`, the Goto of `BUILDING_DONE`) does for a province message.
- The rest of `CInGameIdler_HandleInput`, and what the ordinary click does while a line is chosen.
- What the custom game's `+0x6C` byte and the game state's `+0x60` list are.

Frontier: `0x2DBE40` (now `CBuildingMember::OnClick`, A.2), `0x23F56E` and `0x4558BC` (the callers of
`ProvinceGraphics_UpdatePictures` - when a new building's picture appears), `0x24AB10` (slot 78), `0x266020` and
`0x2680E0` (the terrain and naval mode setters), `0xAD6F0` (the selection's clear), `0x24D850` (the input handler's test
before the plain left click), `0x9E600` (the `(1, 1, 1)` caller of `Province_SetController` that `FINDINGS-surrender.md`
leaves unread).
