# Movement: the order, the route, the hourly march, and how far apart two provinces are

Read statically out of `hoi3_tfh.exe` on 2026-10-09, for the rewrite's movement. Addresses are
**VAs** unless a line says rva; `rva = VA - 0x400000`. Only valid for this build. The distance
rule of section 6 was afterwards checked against the cache the game itself wrote; nothing else
here was checked against a running game, and the last section says what was not read.

**In one line.** A unit holds a list of the provinces still ahead of it and one number, its
progress towards the first of them. Every hour it adds its **speed** to the progress, and when
the progress reaches the **distance** of the edge between the province it is in and the next,
it enters the next and keeps what is left over. The speed is the slowest brigade's
`maximum_speed` times a product of modifiers times `LAND_SPEED_MODIFIER`; the distance is **not
geometric** - it is the sum of the terrain `movement_cost` of every pixel on a walk between the
two provinces' unit points, worked out once when the map cache is built.

This corrects three things already in the record, each in its own section: `CTerrain +0x44
movement_cost` was recorded as "parsed and then never used" (section 6), `ProvinceEdge +0xC`
as "not geometric and not settled" in `FINDINGS-mapbuild.md` (section 6, which also finds the
writer of the bearing that write-up could not), and the weather term of the speed as reading
the province the unit is *heading for* (section 4: it is the one it is *in*).

---

## 1. The click: `CUnit::OrderToProvince`

`CUnit` slot 6 (`0x5C1AD0`, `ret 8`): `(province, bool append)`. It is what a right click on the
map reaches for each selected unit; `append` is the shift key - it is what keeps the path the
unit already has, and the maintainer confirmed the key from play on 2026-10-09 ("Yes it is
shift"); the caller that reads the keyboard was not looked for.

- a unit in a battle is never appended to: `append` is cleared;
- nothing happens for a unit with no brigades, for one that is retreating, or for one with an
  AI agent on any HQ above it;
- a land unit of the player's, outside the battle plan branch (`0x5B59C0`, not read):
  - the province is **the one it stands in**, and either `append` is clear or it has no path:
    a `CCancelMovementCommand` for the unit;
  - `CUnit::CanMoveTo(province)` (slot 35, already recorded) says no: the
    `illegal_selection_projection` effect on the province and the `error` sound;
  - otherwise the `legal_selection_projection` effect, the sound `army_move`, and
    `CMoveCommand(unit, province id, clear = !append, safe = 0, very_safe = 0)`.
- a fleet and a wing take their own branches (`navy_move`, `air_move`), which were not read
  through; both end in the same `CMoveCommand`.

So **`CMoveCommand +0x68`, recorded as `mode_68`, is `clear`** - the key its `LoadKey` saves it
under (`avoid`, `clear`, `location`, `province`, `safe`, `unit`), and the opposite of
`append`.

## 2. The command: `CMoveCommand::Execute`

Slot 6 (`0x5D88C0`), recorded as `CMoveCommand::RouteUnit`; it is the command's `Execute`. In
order:

1. target `-1` means "retreat": `CUnit::FindRetreatProvince` picks the province, and nothing
   happens if there is none. (The retreat button of a battle posts exactly this, `0x732190`.)
2. a unit whose order has type `0x6E7` takes another path (`0x59EB10`, not read) and returns.
3. a fleet in a battle that does not yet want to disengage only notes the target (`+0xAC`) and
   sets `disengage`.
4. **where the route starts**: with `clear` unset and a path already there, from the **last**
   province of that path; otherwise from the province the unit is in.
5. the finder: `CVerySafePathFind` if `very_safe`, else `CSafePathFind` if `safe`, else
   `CPathFind` - all three built side by side on the stack.
6. `CPathFind::Find(finder, unit, from, to, &path)`.
   - found: `SetUnitPath(unit, &path, clear)`, the unit's two dates `+0xCC` and `+0xD0` are set
     to the null date, and its order is replaced by a null order (`CreateOrder(0x18D)`).
   - not found: the unit keeps what it had, and `+0x8C` / `+0x90` take the target province and
     the current hour - a record of the failed order, whose reader was not looked for.

## 3. The route: `CPathFind::Find`

`0x5A12B0`, already recorded as an A\* search. What the earlier reading did not say:

- **A province is settled the first time it is reached.** The visited byte is set when a
  neighbour passes `MayStep`, not when it is taken off the open list, and a visited province is
  never looked at again - so a cheaper way to it found later does not replace the first. The
  routes are therefore not always the cheapest.
- **The open list is one sorted chain**, threaded through an array of "next" indices: a new
  province goes in before the first one whose `f` is not smaller, so of equal ones the newest
  is taken first.
- **`f = g + h`**: `g` is the sum of `StepCost` so far and `h` is
  `IntegerSqrt(dx*dx + dy*dy) * 1000 * 1250 / 1000`, the straight line in map pixels between
  the bounding-box centres (`CProvinceTemplate +0x2C/+0x30`), `dx` wrapped at the map's width,
  times 1.25. The 1250 is a startup constant (`0x1A88618`, the floor of the float 1250.5).
- a neighbour whose `StepCost` is negative, or whose template flag `+0x13D` is clear, is
  marked visited and never queued.
- neighbours are tried in the order of the province's edge vector (section 7).
- the path handed back **leaves out the start and includes the goal**: `0x5A11F0` builds it
  from the came-from chain and `Find` then drops its first node.

`StepCost` (slot 0, `0x5A2A00`) is the edge's distance, times 1.1 into a province a country
hostile to the unit's owner controls, or times 2 when the owner also knows of units standing
there (intel 2 or more) - as recorded.

### May the unit go there at all

`CPathFind::MayUse` (slot 1) asks the unit's slot 34 about the **goal** - and for a fleet also
`0x4A7D70`, a sea connection test. `CPathFind::MayStep` (slot 2), for every step, in order:

1. the edge's kind is 3 (impassable): no.
2. the goal's template flag `+0x13D` is clear: no.
3. `IsCrossingBlocked(unit, edge)` (`0x5A2600`): on an edge of **kind 1** with a crossed
   province, for a unit that is not air - the crossed province is land and a country hostile to
   the owner controls it, or it is sea and a hostile fleet that is not retreating and has ships
   is in it: no.
4. a fleet may go land to sea and sea to land only through the one sea province a land
   province names (`CProvinceTemplate +0xA4`), never land to land.
5. the unit's slot 34 about the province stepped into: section 3.1.
6. for a land unit stepping into a province its own country does not control: the three
   recorded tests against a hostile controller (strength under the shatter threshold; no
   supplies received while it uses some; no fuel received while it uses some), and then
   **military access**: if the owner has access to the country controlling `from`, that country
   is not at war with the one controlling `to`, and the owner **is** at war with the one
   controlling `to` - no. A country cannot be attacked out of a neutral that merely lets you
   through.

### 3.1 Slot 34: may this unit stand in that province

`CUnit::MayStandIn` (`0x5C2AE0`, the base):

    the province's template flag +0x13D is clear                       -> no
    its controller is the controller of the province the unit is in    -> yes
    CCountry::MayEnterProvince(owner, province, false)                 -> yes
    the unit is on land, the province is the sea province its own names,
        and the unit's slot 34 says no to the province it is in        -> yes
    otherwise                                                          -> no

`CArmy::MayStandIn` (`0x5CE2A0`) goes first for a land unit:

    a sea province   -> only if a fleet of the same owner is there that is not in a battle, not
                        moving, not retreating, and can still carry the unit's weight
                        (0x5CEFB0: transport_capacity against what it carries plus this unit)
    a land province  -> its owner area's slot 0 has to say yes (not read; a COwnerArea or a
                        CNullOwnerArea), then yes outright where the byte at CArmy +0x1A8 is set
                        and the province's owner is the owner of the province the unit is in,
                        and the base test otherwise.

`CCountry::MayEnterProvince` (`0x4EFA50`; the country in `this`, the province in EDI, one bool
that also asks the canal test `0x4A7E30`) is the rule of **whose ground a country may walk on**:

    no, when the template flag +0x13D is clear
    no, when all of these hold:
        the country is at war with neither the province's owner nor its controller
        the province is land
        its controller is not friendly to the country
        its owner is not friendly either, or the owner is at war with the controller
        the province has an owner
        the country is not REB
    yes otherwise

with "friendly" being `CCountry::IsFriendly(country, tag, true)`, already recorded: the
country itself, its overlord or puppet, a faction or alliance partner, a co-belligerent, or
one it has military access to. So ground can be entered when it is one's own or a friend's,
when it belongs to nobody, or when one is at war with whoever owns or holds it.

## 4. Setting off: `SetUnitPath`

`0x5C9AC0`, `(unit, path, clear)`:

1. a unit in a battle first asks every battle whether it may leave (`0x5C0000`) and does
   nothing if none says so; otherwise it leaves them all (`0x5BFF70`), and where it was still
   holding ground (`0x5C0160`) it is marked **retreating** (`+0x158`).
2. with `clear`: **the progress (`+0x14C`) and the arrow's counter (`+0x154`) go back to zero
   unless the new path begins with the province the old one began with**, and the old path is
   emptied. So re-ordering a unit towards the province it was already walking to keeps what it
   has walked. Without `clear` the old path stays and the new provinces are added to its end.
3. a land unit at sea given a one-province path onto hostile land: the AI of the theatre there
   is told (`0x8D56A0`).
4. the provinces are appended, 16-byte nodes of a province id.
5. `0x44DCC0` on the game state, and with a path now set `CUnit::ShowMoving` (`0x5C9E10`): the
   avatar goes to the province's **moving** point, plays `move`, the arrow is made
   (`0x5CC230`), and the unit's counter changes stack (`CProvinceTemplate::MoveUnitCounter`).

The fields, on `CUnit`:

| offset | | |
| --- | --- | --- |
| `+0x134` | `previous` | the province it was in before this one; written just before every entry |
| `+0x138`, `+0x13C`, `+0x140` | the path | a `CList` of province ids: first node, last node, count |
| `+0x144` | | the list's "do not unlink" byte |
| `+0x14C` | `movement_progress` | thousandths, towards the first province of the path |
| `+0x150`, `+0x154` | | whole per cent of the way, for the arrow: `progress * 100 / distance` capped at 100, and a running sum of the hour's share |
| `+0x158` | `retreat` | |
| `+0xCC` | | an hour before which the unit does not move at all |
| `+0xD0` | `end_date` | an hour before which it does not **arrive**: it waits with full progress |
| `+0xD4` | `attack_delay` | thousandths of an hour |
| `+0x188` | | the arrow object, and `+0x18C` `arrow_state` |

**`+0x134` is recorded as `supplied_from_province_ptr`** with a comment already doubting it;
`CUnit::AdvanceMovement` stores the current province there immediately before
`CUnit::EnterProvince`, which with the save key `previous` settles it. `+0x138` and `+0x13C`
are recorded as province pointers and are list nodes: a province is reached as
`map->provinces[*node]`.

## 5. The hour: `CUnit::AdvanceMovement`

`0x5CA430`, `bool (unit, bool addSpeed)`, `ret 8`. `CUnit::CheckOrderAndCombat` (slot 31)
calls it for a unit with a path, **once with `addSpeed` set and then again with it clear for as
long as it answers true** (`0x5BAB26`..`0x5BAB3A`) - which is how one hour can carry a unit
through more than one short province.

**Corrected 2026-10-09.** This said `CUnit::UpdateHourly` calls it near its end. The two calls
lie in the function that starts at `0x5BA2F0`, which is `CheckOrderAndCombat`; `UpdateHourly` is
the function before it. So a unit moves **before** its organisation is seen to, on the tick
thread, one country after another - not on the worker threads. `FINDINGS-seaair.md`, section 3,
has the whole of that routine in order.

In order:

1. no brigades: stop.
2. progress zero, an attack delay still running, and the order not a strategic redeployment
   (type `0x5A4`): stop. A unit does not set off while it is delayed, but one already under
   way keeps walking.
3. a land unit at sea about to land on enemy ground, when its slot 33 says it cannot fight:
   the move is cancelled unless another of its country's units is landing on the same
   province.
4. the current hour is before `+0xCC`: stop.
5. the first province of the path is the one the unit is in: that node is dropped and the
   progress set to zero. Stop.
6. a wing in a battle that is not retreating: stop.
7. a land unit whose next province is controlled by an enemy, that has no battle for that
   province, and **has received no supplies** (`+0xFC` zero): the move is cancelled - and a
   unit that was retreating is removed from the game instead.
8. `speed = CUnit::MovementSpeed(unit)` and `distance = CUnit::MovementDistance(unit)`. With
   `addSpeed`, `progress += speed` - and nothing is added under a `support_attack` order (type
   `0x4E5`). A negative progress becomes zero.
9. **in a battle**: the progress is held at `distance` and the hour ends. The unit does not
   enter while it is fighting.
10. otherwise the two per cent figures of the arrow are brought up to date, and:
    - the unit has a battle in that province: stop;
    - the province the unit is in has no edge to the next (`CProvinceTemplate::HasEdgeTo`), or
      `IsCrossingBlocked` says no for a unit that is not air: **the move is cancelled**;
    - `progress < distance`: stop;
    - the hour is before `end_date`: `progress = distance`, stop;
11. **it arrives.** The first node is dropped, `progress -= distance`, the arrow counter is
    zeroed, and **`progress = 0` where an attack delay is running**. Its `current_combat` is
    left, `retreat` is cleared. If slot 34 no longer allows the province the move is
    cancelled; otherwise `previous = current`, `CUnit::EnterProvince(next)` and
    `CCombatManager::CheckForCombat`, and the AI of the theatre and of every country at war
    with the owner are told.
12. no battle came of it and the path is empty: `CUnit::AnnounceArrival` (`0x5C0D50`) - the
    message `UNITARRIVED_LAND`, `_NAVAL` or `_AIR` to the player, only for the player's own
    units and not under orders `0x42E`, `0x6E8`, `0x6E9` - the avatar plays `idle`, goes back
    to the standing point and the counter changes stack.
13. the answer: true when a path is left, the unit is in no battle, and the progress it kept
    already covers the next distance.

`CUnit::CancelMovement` (`0x5C9430`, `(unit, bool resetOrder)`) is the other way out: both
dates to null, a null order if asked, out of any battle it was attacking in, progress and
arrow counter zeroed, the path emptied, the avatar back to `idle` at the standing point, and -
standing on enemy ground, not retreating, in no battle - `CheckForCombat`.

`CUnit::NextArrivalHour` (`0x5CA1A0`) is what an arrival date is shown from:

    hours = ceil( (distance - progress) / speed )
    hour  = max( now + attack_delay / 1000 + hours, end_date )

### 5.1 Speed

`CUnit::MovementSpeed` (`0x5C9140`), thousandths an hour:

    landing from the sea (a land unit at sea, next province land, carried by a fleet):
        AMPHIBIOUS_INVADE_SPEED_BASE + the fleet's amphibious_invasion_speed
    a land unit under a strategic redeployment order:
        STRAT_REDEP_BASE_SPEED * clamp(infra * (1000 + two modifiers) / 1000, 10, 1000) / 1000
        (the province's +0x60, +0x68 and +0x70 of its modifier block: read, not named)
    otherwise:
        maximum_speed * CUnit::MovementSpeedModifier / 1000

and then times `LAND_SPEED_MODIFIER`, `NAVAL_SPEED_MODIFIER` or `AIR_SPEED_MODIFIER` by the
unit's kind. `maximum_speed` is the unit's own definition's (`CUnit +0xC8`, `+0x108`), which
`CUnit::RebuildDefinition` keeps as the **minimum** over its brigades.

`CUnit::MovementSpeedModifier` (`0x5C8D10`) was recorded as a list of terms "read once each".
Read through now; it starts at 1000 and multiplies, each `x * term / 1000` cut:

1. **in a battle with a path**: where the unit is on the attacking side of one,
   `min(1000, max(10, (1000 + the country's combat_movement_speed + its technology figure +
   the leader effect of type 5) * (COMBAT_MOVEMENT_SPEED + the battle's own figure) / 1000))`;
   where it is in a battle on the other side the factor is the floor, 10.
2. **fuel**, for a land or sea unit that is not retreating, does not have the byte `+0x1A8`
   set, and whose definition uses fuel: `fuel_received * 900 / 1000 + 100`. A tenth of the
   speed with no fuel, all of it with a full ration. (`0x1A887B0` is 900 and `0x1A8874C` is
   100, both startup constants.)
3. **with a path**, for the *next* province:
   - `1000 + the unit definition's terrain adjuster for that province's terrain, its
     movement figure` - the average of the brigades';
   - `1000 + 0x5D0F80(unit, 0x1C, the terrain's name)`, a leader's trait for the terrain;
   - where the edge from the province it is in to the next is of **kind 1 or 2**,
     `1000 + the definition's river adjuster's movement` (`+0xA4`). A strait and a river
     crossing cost the same.
4. **a land unit**, for the province it is **in**:
   `1000 + CWeather::MovementEffect(its weather, owner) + its local_unit_speed`
   (`0x5C8FDF`: `mov eax,[ebx+0x130]`, the current province, then its modifier block and its
   weather at `+0x68`). `FINDINGS-weather.md` section 3 calls this province "where it is
   heading"; it is where it stands.
5. **a land unit**: `1000 + (the country's amm_movement_speed) * (the share of its brigades
   that are is_mobile) / 1000`, where that share is positive. `rubber` is what gives
   `amm_movement_speed` in the base game. (`CSubUnitDefinition +0x35` is `is_mobile`.)
6. **retreating**: `1000 + 100`. A retreat is a tenth faster.

Infrastructure is not a term. It decides the speed of a strategic redeployment and nothing of
an ordinary march.

**Checked against savegames, 2026-10-09.** Four saves of one unmodded game, 4 January 12:00 to
8 January 02:00 of 1936, in which the AI has some 480 of 950 divisions on the move. For every
division with the same `location` and the same `path` in two saves, no
`strategic_redeployment`, no `attack_delay` and no `combat`, the speed above was worked out
from the earlier save - its regiments, its `fuel`, the `weather` block of the province it is
in - and multiplied by the hours between, and set against the difference of the two
`movement_progress` figures (OpenHOI3's `tools/OpenHOI3.SaveCheck`, `march`):

| saves | weather effect and fuel the same in both | one of them changed in between |
| --- | --- | --- |
| 7 Jan 22:00 -> 8 Jan 02:00, 4 hours | **301 of 301 equal to the thousandth** | 73 of 73 between the two speeds |
| 7 Jan 14:00 -> 22:00, 8 hours | 289 of 290 | 65 of 68 |
| 4 Jan 12:00 -> 7 Jan 14:00, 74 hours | 151 of 167 | 32 of 40 |

That is terms 2 (fuel), 3 (terrain), the river part of 3, 4 (weather plus local speed) and 5
(`is_mobile`), both truncations and `LAND_SPEED_MODIFIER`, over infantry, cavalry, motorised,
armoured, garrison and mountain divisions. The misses of the longer spans are weather that was
something else in between than at either end. Three things the saves add:

- **`-637`** is what a frozen Soviet province costs: `COLDMOVEMENTMODIFIER` -750 times
  `(1000 - 150)/1000`, the 150 being `winter_effects` from the strategic resource `fur`. The
  country scaling of section 3 of `FINDINGS-weather.md` is therefore live in the base game.
- **the day's fuel arrives between 22:00 and 02:00**: a division with `fuel=0.000` in one save
  and `0.344` in the next gained two hours at each speed.
- **`movement_progress` is below the edge's distance in all 1,482 moving divisions** of the
  three earlier saves, and the first province of every `path` is a neighbour of `location` -
  the arrival of section 5, seen from outside.

Not covered by it: the hour of an arrival, a strategic redeployment, and the route. Of the
AI's paths 436 of 475 are what `CPathFind` as read in section 3 finds from `location` to the
path's end; the others may be `CSafePathFind`'s or `CVerySafePathFind`'s, or orders given in
stages, and were not followed up.

### 5.2 Distance

`CUnit::MovementDistance` (`0x5C9340`):

    no path                                   -> 0
    landing from the sea                      -> AMPHIBIOUS_INVADE_MOVEMENT_COST
    the province it is in has an edge to the next one of the path
                                              -> that edge's distance (ProvinceEdge +0xC)
    no such edge                              -> 1000

## 6. What an edge's distance is: `CProvinceTemplate::MeasureEdges`

`0x4A9E70`, the template in EDI, called by `CMap::LoadMapFiles` for every province from 1 up
(`0x48AE90`..`0x48AEB5`) **only when the map cache is being rebuilt** - otherwise the numbers
come straight out of `map/cache/adjacencies.bin`. For each edge of the province:

    distance = 0
    (x, y)   = this province's unit point          (CProvinceTemplate +0x64, +0x68)
    (tx, ty) = the neighbour's unit point
    this is land and the neighbour sea   -> (x, y)   = this province's naval base position
    the neighbour is land and this sea   -> (tx, ty) = the neighbour's naval base position
                                            (building_positions[naval_base], cut to ints)
    bearing = floor((atan2(...) / 2pi + 0.5 + 0.0005) * 1000)       # +0x10; see below

    until (x, y) is (tx, ty):
        t = the terrain painted at (x, y) in the terrain bitmap     # palette index 0 if off the map
        the river bitmap's byte at (x, y) is under 0xFE, and the edge's kind is 0
                                                                     -> its kind becomes 2
        distance += t.movement_cost                                  # CTerrain +0x44, thousandths
        x steps one pixel towards tx - the short way round the map - and
        y steps one pixel towards ty, both in the same turn

So the walk is diagonal until one coordinate is right and straight after, it is
`max(|dx|, |dy|)` pixels long, the pixel started from is counted and the one arrived at is
not, and each pixel costs what the terrain painted on it costs. **A pixel is a kilometre of
plains.** Three consequences:

- **`CTerrain +0x44 movement_cost` is used, here and only here** as far as was found: the
  record's "parsed and then never used" is wrong. It is spent once, when the cache is built,
  which is why a search of the simulation for a reader finds none - and why **changing
  `movement_cost` in `terrain.txt` does nothing until the cache is rebuilt**. `terrain.txt` is
  one of the seven files of the cache stamp, so the game does that by itself.
- the distance from A to B and from B to A differ: the two walks count different ends, and the
  diagonal part runs through different pixels.
- **a river is a line of pixels in `rivers.bmp` that a walk happens to cross.** Kind 2 is set
  on an edge whose walk touches any pixel of the river bitmap under `0xFE`, and only from kind
  0. Kind is per direction for the same reason distance is.

The terrain of a pixel is `CMap +0x2220[palette index] -> +0xC`: **`CMap +0x2220`, recorded as
an unidentified 0x400-byte table, is 256 pointers**, one per palette index of the terrain
bitmap, each to the entry `terrain.txt` declares for that index, whose `+0xC` is its
`CTerrain`.

**The bearing's writer is this routine too** - the pass `FINDINGS-mapbuild.md` section 5 says
it could not find. The angle is taken from the same two points before the walk; the call at
`0xC0BDBA` was not read, and the formula above is that write-up's, which fits its constants
here (`2pi` at `0x160A4F0`, `0.5`, `0.0005`, `1000`).

### Checked against the game's own cache

Their Finest Hour ships `tfh/map/cache/adjacencies.bin`, 1,728,596 bytes, in the format
`FINDINGS-mapbuild.md` section 5 gives: 14,169 counts and 83,596 edges. The rewrite builds the
edges from the map files by sections 6 and 7 and nothing else, and its
`OpenHOI3.SaveCheck adjacency` compares the two (run 2026-10-09 against the base game):

| | agree |
| --- | --- |
| provinces with the same neighbours | 14,168 of 14,168 |
| provinces with them in the same order | 14,168 of 14,168 |
| kind | 83,596 of 83,596 |
| province crossed | 83,596 of 83,596 |
| distance, land to land | 56,858 of 56,858 |
| distance, sea to sea | 19,116 of 19,116 |
| distance, land to sea and sea to land | 7,622 of 7,622 |

So the walk, the terrain cost, the river rule, the port as the land end, the order of the
edges and the adjacency file's overwriting are all `confirmed` by the game's own output, to the
thousandth, for every edge of the map. The bearing was not compared.

**It also settled what "the centre of the bounding box" is.** With the centre taken as
`(min + max) / 2` only 36% of the land distances agreed and the rest were a pixel out; with
`min + (max - min + 1) / 2` all of them do. So `CProvinceTemplate +0x88` and `+0x8C`, the
bounding box's width and height, count pixels - `max - min + 1` - and the centre at
`+0x2C/+0x30`, which is the default unit point of a province `positions.txt` does not place,
is rounded **up** where the span is even. The pixel list a province's neighbours are met in
(section 7) runs from the south row by row, west to east: the order agreeing everywhere is
what shows it.

One thing the agreement cannot show: the base game gives every land province that touches
the sea a `naval_base` position, so what the default of that point is where the file gives
none was not exercised. The rewrite uses the centre.

## 7. Which edges there are, and in what order

**`CMap::BuildAdjacencyFromRaster`** (`0x4911B0`, already recorded) decides the order, which
matters because the route finder tries neighbours in it. For each province from 1 up, for each
of its pixels in the order of its own pixel list (`CProvinceTemplate +0x6C..+0x70`, pairs of
x and y), for the four neighbours **east, west, north, south** in that order (x wraps, y does
not): a different province not yet seen on this pass, which does not already have an edge
back, gets an edge to this one appended, and this one an edge to it. So a province's edges are
first those to lower-numbered neighbours, in ascending order of the neighbour, and then those
to higher-numbered ones in the order its own pixels meet them.

**`CMap::LoadAdjacenciesFile`** (`0x48E520`) then reads `adjacencies.csv`, one line each,
`From;To;Type;Through`:

| `Type` | kind |
| --- | --- |
| `river` | 2 |
| `sea` | 1 |
| `impassable` | 3 |
| anything else, `canal` included | 0 |

Where `From` already has an edge to `To`, the kind and the crossed province are **written over
both directions**; where it has none, an edge is added each way. The crossed province's
template byte `+0x15` is set. So `adjacencies.csv` can make a land border impassable or a
river, not only add straits.

The kinds, then: **0** plain, **1** a crossing through a named province that can be blocked,
**2** a river, **3** impassable.

## 8. The terrain of a province

Not movement, but in the same block of `CMap::LoadMapFiles` (`0x48A94D`..`0x48AE11`, run on
every start whether or not the cache is used) and never written down. For each province:

    t = the terrain painted at its unit point                        # palette index 0 if off the map
    province 1737 (0x6C9): t = the terrain painted at its text position. Nothing else.
    any other land province:
        count, over the 20 x 20 pixels from (text_x - 10, text_y - 10), each pixel that belongs
        to this province, by the terrain painted on it
        the terrain with the highest count replaces t; of equals, the one declared first;
        with no pixel counted t stays
    a land province whose t is water: the first terrain declared that is not water
    template +0xC = t

The text position is `positions.txt`'s `text_position`, cut to whole pixels, or the centre of
the bounding box where the file gives none. **Province 1737 is in the executable by number.**
A sea province's terrain is whatever is painted at its unit point.

This is not "the terrain covering most of the province". It is the terrain around where the
province's name is written.

## 9. Where a moving unit stands

`CProvinceTemplate +0xCC` was recorded as five points of three floats with no reader named.
`CUnit::EnterProvince`, `CUnit::ShowMoving`, `CUnit::AdvanceMovement` and
`CUnit::CancelMovement` all pick the same way:

| point | offset | who |
| --- | --- | --- |
| 0 | `+0xCC` | a land or sea unit with no path |
| 1 | `+0xD8` | a land or sea unit with a path |
| 4 | `+0xFC` | an air unit |

A fleet in a land province is put at the naval base position instead, and a wing at its own
base at the province's unit point, each less the label point `+0x5C/+0x60`. Points 2 and 3
are the two sides of a battle (`FINDINGS-counters.md`). What writes the five was still not
found.

**The five are offsets from the province's label point, not places on the map.**
`CUnit::MakeArrow` (section 10) starts its arrow at
`stack point - (unit point - label point) + unit point`, which is the label point
(`+0x5C/+0x60`) plus the stack point; and an avatar that is put somewhere other than a stack
point is handed that place *less* the label point. So whatever fills them writes each as a
difference from the label.

## 10. The arrow of a selected unit

Read on 2026-10-09 after the maintainer gave a screenshot of it: a hollow green band curving
from the unit to where it is going, with an outlined head.

**`CUnit::MakeArrow`** (`0x5CC230`, the unit in ECX) makes it, for a unit with a path and a
graphics owner; `CUnit::ShowMoving` calls it only for a selected unit, and so does
`CUnit::EnterProvince` for a selected unit with a path left. `CUnit::RemakeArrow`
(`0x5CC200`) frees the old one and makes another; `CUnit::FreeArrow` (`0x5CB920`) frees it.

1. **Its points**, each of three floats - x, a height, y: the unit's own place, which is its
   stack's point (the moving one, or one of the two battle points) plus the label point; and
   then the unit point (`+0x64/+0x68`) of every province of the path, x moved by the map's
   width where that is the short way round. The height is 0.02 over land and 0 over sea. For
   a fleet the first point is the naval base where it is in a land province and the last is
   the naval base where it ends in one; for a wing the same with air bases.
2. **A point is added beyond each end**, 5 from it in line with the end's own leg, so that
   the curve has something to bend from.
3. **Which arrow**: `unitInvasionArrow` for a landing from the sea, `retreatArrow` for a
   retreat, `attackArrow` where `0x5C5B20` says so, `stratArrow` under a strategic
   redeployment order (type `0x5A4`), and `moveArrow` otherwise - the names of `arrowType`
   blocks in `interface/arrows.gfx`.
4. The object is a **`CUnitArrow`**, 0x160 bytes, a `C3dVisibleObject`
   (vftable VA 0x15E3C14); its constructor (`0x87F250`, the type in ECX) copies the points
   into a vector at `+0x14C`, dropping one that is within 0.1 of the next, and calls
   `CUnitArrow::BuildMesh`.
5. `+0x15C` is set at once to `movement_progress` over `CUnit::PathDistance`, and
   `CUnit::AdvanceMovement` keeps it so each hour.

**`CUnitArrow::BuildMesh`** (`0x87FA30`) makes the band:

    for each leg between two of the real points, twenty times, t = k / 20:
        p = D3DXVec3CatmullRom(the point before, this, the next, the one after, t)
        q = the same at t + 0.05
        across = the direction of q - p turned a quarter in the ground plane, one long
        from the second leg on: across = the mean of this and the cut before's, one long
        two vertices: p + across * 2 and p - across * 2
        u = 0.5
        within 4 of the end: u = 0.5 + 0.5 * clamp(1 - distance * 0.25, 0, 1)
    each vertex's progress = its cut's number over the number of cuts

So the band is **4 map units wide**, a Catmull-Rom curve through every point of the path,
twenty cuts to a leg; the shaft is the middle column of the texture and **the head is its
right half, laid over the last 4 units**. The 20, 0.05, 2.0, 0.5, 4.0 and 0.25 are constants
of the image (`0x160A318`, `0x160A850`, `0x160A360`, `0x15AB304`, `0x171DF34`, `0x160A258`);
the declaration's `size = 5.0` is not what the width comes from.

**The shader**, `gfx/FX/arrow.fx`, is plain text: a vertex whose progress is not more than
`CurrentProgress` takes its texel from the lower half of the texture, any other from the
upper. `gfx/mapitems/movearrow.tga` is 64 by 128: above, the arrow in outline; below, the
same filled. So **the arrow is hollow ahead of the unit and filled behind it**, by the share
of the whole path walked - and since the arrow is made again in each province the unit
enters, the fill starts again from nothing there.

Against the screenshot: the shaft's two lines are about 1 map unit apart and the head about
3.3 wide and 3.4 long, at 14.5 pixels to a unit; the texture's shaft is 18 of its 64 rows and
its head 52, which of a band 4 wide are 1.1 and 3.25. `confirmed` by that for the width and
the head's length. The tip in the screenshot is whole, where a last cut a twentieth of a leg
short of the end would blunt it; what the distance in the head's rule is measured to was not
made out, the decompilation losing the operands.

---

## What was not read

- **`0x5D0F80`**, the leader's term in the speed, and `CommandEffect` type 5.
- **the branch of the click behind `0x5B59C0`.** The test itself is read since:
  `CUnit::HasAgentAbove`, true where the unit or one above it has an AI agent
  (`FINDINGS-unitpanel.md`, section 2) - so the branch is what a click does to a unit an AI
  commands. The fleet's and the wing's branches are read since too: `FINDINGS-seaair.md`,
  section 1.
- **of the arrow** (section 10): the loader of an `arrowType` and what its `size`, `height`,
  `endAt`, `heading`, `type` and two colours do; the test `0x5C5B20` for the attack arrow;
  and what the head's distance is measured to.
- **`CSafePathFind` and `CVerySafePathFind`** beyond what is recorded; the player's click asks
  for neither.
- **order type `0x6E7`** in `CMoveCommand::Execute`, and the reader of the failed-order record
  at `CUnit +0x8C/+0x90`.
- **the owner area's slot 0**, which `CArmy::MayStandIn` asks of every land province.
- **`0x5C2F20` and slot 33** in step 3 of the hour were read only as far as said there.
- ~~the naval distances~~: read since, and checked against `navaldist.bin` cell for cell -
  `FINDINGS-seaair.md`, section 4.
- **what `CProvinceTemplate +0x13D` is.** Every test here treats a province with it clear as
  one nothing may enter; it is 1 on every province seen.
- **the default of a naval base position** where `positions.txt` gives none.
