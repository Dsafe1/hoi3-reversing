# The air orders window: the area of a mission, its sliders, its hours and its dates

Read statically out of `hoi3_tfh.exe` on 2026-10-11, for the rewrite's window of orders an air
unit is given. Addresses are **VAs** unless a line says rva; `rva = VA - 0x400000`. Only valid
for this build. Nothing here was watched in a running game.

It goes on from `FINDINGS-seaair.md`, section 2, which read the window as far as its list of
orders, and from `FINDINGS-airbattle.md`, section 1, which read the fill that makes a circle's
provinces. **It finishes both**: the four shapes, the cone's test, the right click that sets a
second target, what the window starts with, the whole ladder that picks the order ticked first,
the day and night boxes, the two dates, accept, and what the map shows while the window is up.

**In one line.** The window holds an order it is making; every control changes that order, and
the order's own list of provinces is what accept sends. A shape button says how the list is
made, the three sliders and a right click on the map say how far and which way, shift with a
right click adds or takes away one province, and the map is coloured to show the unit's reach
and the list for as long as the window is up.

---

## 1. What the window holds

`CAirOrdersView` (0x37C bytes, vftable `0x15D751C`), made by `CInGameIdler::OpenOrdersView`
with mode 1. The fields this reading leans on:

| | |
| --- | --- |
| `+0x08` | the unit, a reference by id |
| `+0x30` | the province the window is for, whose name is the title |
| `+0x34` | a second target province. **Only the constructor writes it, with nought** (`0x740102`) |
| `+0x38` | open; cleared by accept, which closes the window |
| `+0x4C` | the hour the window was opened |
| `+0xA8`, `+0xAC` | the two windows made from `datewidget` |
| `+0xB0`, `+0xB4` | the two date widgets, start and end; each keeps its date at `+0x160` and whether its buttons are switched on at `+0x168` |
| `+0xB8` | the window `air_unit_order` |
| `+0x164` | the name of the order ticked, or null |
| `+0x2E0` | priority, 0 to 4 |
| `+0x2E4` | stance, 0 to 2 |
| `+0x2E8` | the shape: 0 point, 2 circle, 3 cone, 4 region |
| `+0x2EC` | the order being made, or null |
| `+0x2F0` | the range the sliders last gave, in the distance units of a unit's range |
| `+0x2F4`, `+0x2F8` | the angle and the width the sliders last gave, in radians |
| `+0x304` | the sliders have moved; the figures and the map are to be redone |
| `+0x30C` | the time: 0 by day, 1 by night, 2 both |
| `+0x310` | a map from an order's name to the order, for the orders that may be given |

The shape is also written into the order (`CAirOrder +0x6C`) whenever the order is made or a
shape button pressed, and the order keeps its own range, angle and width (`+0x74`, `+0x70`,
`+0x78`) and its own **second target** (`+0x54`).

## 2. Opening, and what it starts with

**`CAirOrdersView::CAirOrdersView`** (`0x7400C0`) makes the window, wires `accept`, `cancel`,
the four shape buttons and the stance and priority arrows, and writes the province's name into
`title`. Then, in this order:

1. `both_checkbox` ticked, `night_checkbox` and `day_checkbox` cleared, `continous_checkbox`
   ticked; the time `+0x30C` is 2 from the start.
2. `CAirOrdersView::BuildOrders(unit, 0x18D)` - the list of orders, section 3.
3. `0x742AA0`, which makes the order of the ticked row (section 4).
4. The stance and priority figures.
5. Two `datewidget` windows, placed at the `positionType`s `mission_timewidget_start` and
   `mission_timewidget_stop` and named `start_widget` and `end_widget`. **The start is the
   hour now, the end the hour now and one month** (`AddMonths(&date, 1)`, `0x740F0F`).
6. The map coloured for the order (section 8).
7. The three sliders set, each `SetValue(n, 1, 1)` in thousandths of the bar: **`range_slider`
   0, `angle_slider` 16, `width_slider` 250** - `floor((x + 0.0005) * 1000)` of 0, 0.016 and
   0.25, folded to 16.5 and 250.5 by the compiler. The `.gui` file's `startValue`s, 0.25 for
   the angle and 0.016 for the width, are the other way round and do not count.
8. The view's own range, angle and width read back from the sliders (section 5), and the three
   figures written.

**The window remembers the last one.** `CInGameIdler::OpenOrdersView` calls `0x747300` after
making an air window, with `CInGameIdler +0x1D9C`: four dwords - priority, stance, shape and
the type of the order that was being made. The idler's constructor sets them to 0, 0, 0 and
`0x18D` (`0x648587`..`0x648599`); `CInGameIdler::CloseOrdersView` (`0x678160`) stores them
from an air window as it closes, through `0x7472B0`, with `0x18D` where no order was being
made. `0x747300`:

    the kept type is not 0x18D:  the list made again, keeping that type (section 3)
    priority and stance taken, their figures written
    the kept shape's button pressed (section 4), and the order made again (0x742AA0)

So **the first air window of a session opens with priority 0, the aggressive stance and the
point shape, and ticks the unit's own order where it can; each later one opens with the last
one's priority, stance and shape, and ticks the last one's order where it can.** The idler is
the session's, so this is per session and not per unit.

## 3. The list, and which row is ticked

`CAirOrdersView::BuildOrders` (`0x746260`, `(view, unit, type to keep)`) is section 2 of
`FINDINGS-seaair.md` as far as which orders are offered. **The type to keep** is the type of
the order being made where there is one; otherwise the unit's own order's type where it was
given `0x18D`; otherwise the type it was given. Each row is made by `AddOrder`, which answers
whether the order may be given, and **a row of the type to keep that may be given is noted**.
Then the row ticked, by name:

    the unit may stand in the province (its slot 34), the province's controller is not at
    war with the unit's country, it has an air base built, and "rebase_air" may be given
                                                                 -> rebase_air
    otherwise:
        a noted row                                              -> the noted row
        otherwise the ladder

(A last test, after both arms, ticks the noted row where nothing is ticked; neither arm can
leave it so.)

**The ladder** (`0x746CFE` onwards). It counts the unit's wings three ways (`0x746160`): a
wing whose definition is no bomber (`isBomber`, `CSubUnitDefinition +0x37`) is a fighter; a
bomber whose half of soft and hard attack together is under its strategic attack is a
strategic bomber; any other bomber is a tactical one. **Its second rung asks nothing about
what is ticked**, so ticking there replaces what the first ticked; the last two run only where
nothing is ticked:

    fighters outnumber each of the other two:
        the province's controller is an enemy of the unit's country and "air_superiority"
        may be given                                             -> air_superiority
        otherwise, where "air_intercept" may be given           -> air_intercept
    the unit's sea attack (its definition, CUnit +0xC8, +0x168) is above nought, whatever
    is ticked:
        the province has an owner, a port, a naval base built, and
        "port_strike" may be given                               -> port_strike
        otherwise, it is sea and "naval_strike" may be given    -> naval_strike
    nothing ticked, and strategic bombers outnumber tactical ones, and the province's
    controller is at war with the unit's country:
        it has an air base built and "runway_cratering" may be given
                                                                 -> runway_cratering
        otherwise, it has a radar station, a nuclear reactor or a rocket test site above
        nothing, and "installation_strike" may be given          -> installation_strike
        otherwise, its IC modifier (CMapProvince +0x114, +0x78) is above nought and
        "strategic_bomb" may be given                            -> strategic_bomb
    nothing ticked, and the unit's soft or hard attack is above nought:
        "ground_attack" where it may be given, otherwise "interdiction" where it may
                                                                 -> that one

"May be given" is the name map at `+0x310`: an order is entered there only where `AddOrder`
let it be ticked. The building tests read each building's level by its key out of
`CMapProvince +0x310`, against a value kept in `.bss` that is nothing at the start of a
session (`0x1A870F4`, `inferred` - it is not in the image). "Built" is a building's built level
(`CProvinceBuilding +0x20`, in thousandths) above nought, whatever bombing has left of it. Where
no rung answers, nothing is ticked and accept is greyed.

## 4. The four shapes

Each shape button (`point_target_button` `0x743CE0`, `region_target_button` `0x743FB0`,
`circle_target_button` `0x744280`, `cone_target_button` `0x744550`) gives its own button frame
2 and the other three frame 1, switches the sliders, sets the view's shape and the order's, and
makes the order's list again with `CAirOrder::SetSecondTarget(order, view +0x34, false)`, then
redraws the map:

| button | shape | sliders switched on |
| --- | --- | --- |
| point | 0 | none |
| region | 4 | none |
| circle | 2 | range |
| cone | 3 | range, angle and width |

Since `+0x34` is always nought, the list made there is the shape's own:

**`CAirOrder::SetSecondTarget`** (`0x588EB0`, `(order, province, bool toggle)`):

    the province is the order's own                                    -> nothing
    toggle:
        the province is out of range (slot 38)  -> taken off the list where it is on it
        on the list                              -> taken off
        otherwise                                -> added at the end
    no toggle:
        the list emptied; the order's second target (+0x54) is the province
        a province given:
            range = the distance from the order's province to it, no more than the unit's
                    range / 1000
            angle = Bearing(the order's province, it)
        shape 2 or 3:  the list filled from the order's province (CAirOrder::FillArea) with
                       the range in thousandths, floor((range + 0.0005) * 1000)
        shape 0:       the order's province, where it is in range (slot 38)
        shape 4:       every province of the order's province's first region, in the
                       region's own order, that is in range (slot 38); with no region, the
                       order's province where it is in range

**The fill** is `FINDINGS-airbattle.md`'s, section 1: from the order's province, through
neighbours the unit may fly to that are within the unit's range of its base and **within the
range of the order's province**, each added as it is reached. For the cone a neighbour must
also pass the arc test before the walk goes on from it, and that is what decides whether it is
added:

**`Bearing`** (`0x588E60`, `(x1, y1, x2, y2)`, the province's label point, `CProvinceTemplate
+0x5C` and `+0x60`, y counting north) is `atan2(y2 - y1, x1 - x2) + 3pi/2`, in single
precision: north of the first point 0 (2pi), east pi/2, south pi, west 3pi/2 - **a compass
bearing, clockwise from north**, between pi/2 and 5pi/2.

**`IsWithinArc`** (`0x589320`, `(bearing, angle, half width)`, the half width being the order's
width x 0.5):

    hi = fmod(angle + half, 2pi)
    lo = fmod(angle - half, 2pi)
    b  = fmod(bearing, 2pi)
    hi > lo:   lo <= b <= hi
    otherwise: b >= lo or b <= hi
    -> 1.0 or 0.0

`fmod` keeps the sign of what it divides, so **where the angle is less than half the width, `lo`
is negative and the arc's part west of north is lost**: a cone pointed north-east and wider
than twice its angle reaches round to north and no further.

**The region** of a province is the first of its regions (`0x4A6E90`: the first node of
`CMapProvince +0x358`, where the count at `+0x360` is not nought). **`CMap::AssignRegions`**
(`0x48FAC0`) gives each province its list: for each region of the map's vector at `+0x2A40`,
for each province id of the region's own vector (`CRegion +0x8`..`+0xC`) under the map's
province count, the region is appended to the province's list. That the vector holds the
regions in the order `map/region.txt` gives them is `inferred`: its first two entries are what
`g_black_sea_region` and `g_baltic_sea_region` name. 6,136 of the 11,632 provinces Their Finest
Hour's file lists are in more than one region. A word that is not a number inside a region's
block, `peace` in eleven of them, is the region's `useForPeace` (`CRegion +0x6C`).

## 5. The sliders and their figures

Slot 2, **`CAirOrdersView::Update`** (`0x741DE0`), each frame where an order is being made: each
slider's value (0 to 1) is multiplied by its factor - **the unit's range / 1000** for the range
(its definition's `+0x148`), **2pi** for the angle and the width - and

    | what the view holds - the new value | / the new value  >  0.05
        -> the view holds the new value, the order's setter is called with it
           (CAirOrder::SetAreaRange, SetAreaAngle, SetAreaWidth), and the figures and the map
           are to be redone

So **a slider has to move by more than a twentieth of where it now is before the order takes
it**, and a run of small moves is measured from the last value taken, not from the last frame.
Each setter stores its value and, for a shape that uses it, empties the list and fills it from
the order's province: the range for the circle and the cone, the angle and the width for the
cone alone. A setter does not set a second target, so the range and the angle a right click gave
(section 6) stand until a slider is moved by enough.

**The figures** (`0x744820`): `range_value` is `ORDER_RANGE_VAL` with `VAL` the view's range
`%.0f` ("600 kms"); `angle_value` and `width_value` are `ORDER_ANGLE_VAL` and
`ORDER_WIDTH_VAL` with the view's angle and width x 180 / pi, `%.2f` ("5.76 Deg"). They show
the sliders' values, never what a right click gave the order.

## 6. A right click on the map while the window is up

The input handler at `0x652540` has, for a right click on a province (`0x6534E4`, the button
2), with nothing dragged and a province under the pointer: **where the orders view is up and
its slot 3 says it is shown, the view's slot 4 is called with the province and whether shift
is held** (`CInGameIdler +0x1C`, slot 10 - the key that is `append` for
`CUnit::OrderToProvince`), and nothing else is done. Otherwise every selected unit is sent
there as before. `CNavalOrdersView` has no slot 4 of its own and `COrdersView`'s is `ret 8`
(`0xA806D0`), so **with the naval window up a right click on the map does nothing**.

**Slot 4, `CAirOrdersView::OnMapRightClick`** (`0x743950`), where an order is being made:

    circle or cone:          CAirOrder::SetSecondTarget(order, the province, shift)
    point, with shift:       the order's slot 36 (AddProvince) with the province
    region, with shift:      slot 36 for every province of the province's first region, or for
                             the province where it has none
    otherwise:               the window is for the province now - its +0x30 - and the list
                             is made again keeping the order's type, the order made again,
                             and the shape's button pressed again
    then the map redrawn

So a plain right click **aims a circle or a cone** - its range becomes the distance to the
province, capped at the unit's range, and a cone's angle the bearing to it - and **moves a point
or a region** to the province clicked; shift with it **adds or takes away a province** of a
circle or a cone, and **adds** to a point or a region. Slot 36 adds a province not already
listed where slot 37 agrees, and slot 37 is the order's own: for most orders the range of slot
38, but for the strategic bombing, the installation strike and interdiction
`CStrategicBombOrder::IsProvinceAllowed`, which asks no range (`FINDINGS-bombing.md`, section
1). The region shape's own fill asks slot 38, the range alone.

**The second target is never shown.** `Update` writes `second_target` as `ORDER_SECOND_TARGET`
with the view's `+0x34` - which is always nought - so that line never appears; where the order
cannot be accepted it writes `ORDER_NO_SECOND_TARGET` ("Right-click on the map to select a
second target province."), and where it can it leaves the box as it was. The box is empty in
the `.gui` file, so **it reads empty until the first time accept is greyed, and the hint from
then on.**

## 7. Day, night and both

`0x744E50`, from `Update` every frame, makes the three boxes act as one choice, by what was
chosen last (`+0x30C`):

    time is 0 or 1, and "both" is ticked:  day and night cleared, time 2
    else time is 0 or 2, "night" ticked:   both and day cleared, time 1
    else time is 1 or 2, "day" ticked:     both and night cleared, time 0

**Clearing the box that is ticked leaves none ticked and the time as it was.** A box is cleared
unless it is shown and switched off.

Then the readout: `daytime_title` is `ORDER_DAY_TIME` with `PROV` the window's province
("Locally in Warszawa:"); `daytime_icon` takes frame 2 where it is night and 1 by day, and
`daytime_icondesc` reads `ORDER_NIGHT` or `ORDER_DAY` - **`IsNight` of the window's province
at the hour of the day and the month of the start date**. Its tooltip is
`ORDER_DAY_TIME_DESC`, with `PROV` and `TIME`.

## 8. The map while the window is up

**`0x867DB0`** (the order, and the map's colours in EDI, `+0x1DC4` of the screen's map object)
gives every province two colours, a fill and a stripe, the same:

    not in the unit's range (the order's slot 38)    nothing: (0, 0, 0, 0)
    sea, or land the unit's country controls         (0.4, 0.7, 0.4) + 0.2 each - green
    land of a country at war with the unit's         (0.7, 0.4, 0.4) + 0.2 each - red
    other land                                       (0.4, 0.4, 0.4) + 0.2 each - grey
    and then every province on the order's list     (0.5, 0.8, 0.8)            - pale cyan

All with alpha 1 but the first. It is called by the constructor, with the map's refresh
(`0x880D90`, false), and by `0x743B10`, which `Update` calls where the sliders moved and every
shape button and right click call, with the refresh true. It has no other caller: **the colours
are the window's own, not a map mode's**. The destructor (`0x7415E0`) recolours the map by the
mode at `+0x4` - political, diplomatic, supply, infrastructure, intelligence, victory points,
theatre, strength and two more - so the map comes back as it was.

## 9. The dates

The two `datewidget`s each have `year_up`, `year_down`, `month_up`, `month_down`, `day_up`,
`day_down`, `hour_up` and `hour_down` (`0x60E650`..`0x60E8C0`): 8,760 hours, a month by
`AddMonths`, 24 hours and one hour, up and down, and after each **the date is held between the
defines' `start_date` and `end_date`** (`CDefines +0x8` and `+0xC`). `date` shows it with its
hour (`0x60E910`).

`Update` switches both widgets' eight buttons off while `continous_checkbox` is ticked and on
while it is not (`0x60EE00`, `0x60E9F0`). **"Continuous" is ticked when the window opens**, so
a mission is given with the dates it opened with unless the box is cleared first.

`0x745520`, from `Update` and from accept: for a paradrop (type `0x570`), the start is moved
on to the hour now and `PARADROP_MIN_TIME` / 1000 hours where it is earlier.

## 10. Accept

**`0x742720`**, for every unit of the selection that is an air unit (its slot 17), skipping one
whose own order says yes to slot 24 and no to slot 12 - **a change of base under way**:

    CSetOrderCommand(the unit, the type of the order being made, the window's province,
                     the hour the window was opened, the null date)
    stance      (+0x94)  the view's
    time        (+0x98)  the view's
    objectives  (+0x84)  the ids of the order's list, in its order
    start_date  (+0x74)  the start widget's date
    end_date    (+0x78)  "continuous" ticked: the defines' end_date; otherwise the end widget's

then posted, and the window closes. `CSetOrderCommand::Execute` puts `+0x74` into the new
order's `start_date` and `+0x78` into its `death_date` (`0x5E1F90`): before its start an air
order is not fit to fly, and past its death date it is over once home
(`FINDINGS-airbattle.md`, section 1). The two dates of the constructor go to the unit's `+0xCC`
and `+0xD0`, the first being the hour before which it does not move.

**The priority is never sent.** The command carries the stance and the time and nothing
carries `+0x2E0`, which agrees with the record's live reading of `COrder +0x1C`, zero on every
order of a running game. The arrows step it and it is remembered (section 2), and that is all.

`accept` is switched on by `Update` only while an order is being made, its list is not empty,
and its slot 10 - which is slot 11, "may this be given" - says yes. Its tooltip is
`OV_NO_VALID_ORDER` with no order and `OV_NO_VALID_PROVINCES` with an empty list.

## 11. Tooltips

Slot 6 (`0x7456C0`): a row of `orders_list` gives the order's description
(`OrderMissionIndexToDescription`); the stance elements `OV_STANCE`, the priority elements
`OV_PRIO`, `continous_checkbox` `OV_CONT`, the four shape buttons `AirOrdersBtn_Point`,
`AirOrdersBtn_Region`, `AirOrdersBtn_Circle` and `AirOrdersBtn_Conic`, and the day readout
`ORDER_DAY_TIME_DESC`.

## 12. What was not read

- `cancel` (`0x742A90`), which is taken to close the window, as the naval one's does.
- The glue at `+0x350` (`0x747410`), which posts a `CSetOrderCommand` of type `0x18D` with
  the hour now twice for the view's unit where its order says yes to slot 24: what calls it.
- Slot 5 (`0x745630`), which asks the two date windows, the start widget and the window itself
  their slot 37 - taken to be "is the pointer over it".
- How the original's map shader draws a colour with no alpha.
- Which unit the window's range factor reads when several are selected: the view's unit's.
