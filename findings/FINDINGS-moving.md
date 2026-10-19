# The military AI moving and attacking: the land block, the division need, sea and air targets, invasions and sealift

Read statically off `hoi3_tfh.exe` on 2026-10-19 by six readers, A to F, for OpenHOI3's stage 5 - the military AI's
third piece, moving and attacking (`WAVE.md`, "The moving wave"). Addresses are **rvas** against an image base of
`0x400000` unless marked VA. Nothing here was watched in a running game; the five saves of the maintainer's one game
(`Germany1936_01_01_00`, `_01_04_12`, `_01_07_14`, `_01_08_07`, `_04_20_03`, Germany played, Italy at war with Ethiopia
throughout) are the check wherever a rule leaves a trace in them, and each section says where it does and where it does
not. It builds on `FINDINGS-agents.md` (the pass, the agent tick's rows, the plans, the movers between theatres) and
cites, without redoing, `FINDINGS-aiconsumer.md` (`CAIUnit_ManageLandUnits`, the attack), `FINDINGS-attackodds.md`,
`FINDINGS-aihelpers.md`, `FINDINGS-airnaval4.md`, `FINDINGS-airstance.md` and `FINDINGS-invasion.md`.

## In one paragraph

An agent's land units are placed by **the land block** (A), its tick's row 15, on a full pass or at war every third hour:
the committed divisions are split into **garrisons** of the hold provinces and a **line**, shared among the area of
operations' positions in proportion to their scores, at most five a position (from `BASE_STACKING_PENALTY`); held-back
divisions go to a **rear ring**; only one of the three moves anything in a pass, line first; then defenders leave a land
battle they are losing, airborne armies are planned onto drops, and long marches become strategic redeployments. The
**attack** (`ManageLandUnits`, row 21) takes its candidates **lowest cost first** - a cost made of enemies beside the unit,
its own terrain modifier at the target and a +100 for a garrison - and a called-off attack **halts in place** (B). How
many divisions a theatre wants is **the division need** (C): per area, the larger of a front estimate rounded half to
even and a float value of the theatre's own provinces over at most 40 of them, the focus areas added, and a floor in the
capital's area from its naval bases - 18 for every European Soviet theatre. The fleets and aircraft are given their
targets once a day **with no sighting at all** (D): every enemy and war-target fleet goes to the nearest agent, its own
fleets cancel them in the wants, submarines raid or move to better hunting ports, screens patrol, and an enemy fleet at
sea draws an intercept group twice its power. **Invasions** (E) are planned once a day by countries whose fleets can lift
four infantry brigades, against the ten best enemy coastal areas, at most two at a time (Japan eight, the USA four), and
carried out by a `CAIInvasion` agent that marches, loads, sails and gives the invasion order. **Sealift** (F) moves
divisions across water to theatre areas short of them - never within one piece of friendly land - by a vote for a debark
port and an embark port in the area most of them stand in; and the AI gives leaders only to leaderless units.

## What this corrects

- `FINDINGS-aiconsumer.md`: the attack candidates are sorted **ascending** and taken lowest first; `CUnit +0x2B8` is a
  cost, not a fitness (B.4). Its "`0x5C0160`, in an attacking combat" is `CUnit::IsHoldingGround`, any battle on either
  side (A). Slot 89 is the unit's own terrain modifier, not the enemy's power (B.3).
- `FINDINGS-power.md` / the record: `EstimateAreaNeed`'s province-count division belongs to the province-value estimate,
  not the weight sum; the weight sum is rounded half to even and never divided; a province scores `n x weight`; nine
  steps were missing (C.2, C.8).
- `FINDINGS-agents.md`: E.6's "debark is a division's target in 10 of 12" holds in 12 of 12 (29 of 29 over three saves);
  its "+3" vote term never applies to an AI country; the sealift is gated on a whole unit of transport capacity (F);
  `CAIUnit +0x25C` holds every assigned enemy fleet and `+0x26C` the country's own and co-belligerents' fleets, not
  sightings gained and lost (D.1); France's 0.5% is technology toughness counted twice, and the first sub-1 post comes
  from an inactive plan's direct write (C.5, C.6).
- `FINDINGS-theatre2.md`: `CAIInvasion`'s stage 2 sends carrier air groups on `ground_attack`, it loads nothing; loading
  is stage 3's `CLoadArmyCommand` (E.5). The planner's overland test is dead code (E.9).
- The record: `AI_ReassignLeaders` reassigns nothing and is `CEU3AI_AssignLeadersToLeaderlessUnits` (F.9);
  `0x1D66D0` sums `transport_capability`, not weight (E.9, F); `CountSightedEnemyShips` is `CountAssignedEnemyShips` (D);
  `BuildAirTargetProvinceLists` rebuilds every daily full pass, over the Overlord and the Vassals (D.3); the threatened
  provinces' carried list is `CUnit +0x2E4` (A.1); `CUnit +0x2C9` is `ai_garrison` (A.8); `COwnerArea +0x3C` is the
  neighbour-area count (E.9); `CAIInvasion`'s `+0x84`/`+0x88`/`+0x90`/`+0x74` are the objective, embarkation port,
  rendezvous and air list (E.9).
- `CANDIDATES.md`: `0x508C30` is a VA, rva `0x108C30`, `CCountry::UpdateLendLeaseRoutes` (C.8).

## A. The land block: who marches where

*Read 2026-10-19 off the bytes. Builds on `FINDINGS-agents.md` A.5 (the tick's rows) and `FINDINGS-aiconsumer.md`, which has the attack, `CAIUnit_ManageLandUnits` (row 21), whole and is cited here, not redone.*

**In short.** Row 10 of the agent tick (`0x4B1820`) and all four row-15 calls, with their nine callees, are the AI's whole answer to "where does a division stand". `0x4CC450` sets aside garrisons, divides a line count among the ops-area positions (at most 5 divisions a position in Their Finest Hour, from `BASE_STACKING_PENALTY`), and sends spare held-back divisions to the rear ring; `0x4D7F80` pulls defenders out of a battle they are losing; `0x4CC690` is the paradrop planner; `0x4CC020` switches long marches to strategic redeployment and stops marches that would cross hostile ground. Every move goes through `CEU3AI::MoveUnit`, which posts a `CMoveCommand`, or a strategic-redeployment order when the move is long, or a halt when the target is the unit's own province. **Corrections**: the carried-units list in `UpdateThreatenedProvinces` is `CUnit +0x2E4`, not `+0x2DC`, and the decompiler's early return there is not in the bytes; `CUnit +0x2C9` is `ai_garrison`, with four writers and ten readers rather than one reader; and `FINDINGS-aiconsumer.md`'s "`0x5C0160`, in an attacking combat" is `CUnit::IsHoldingGround`, which means in any battle, on either side.

**In one paragraph.** Every hour an agent updates its list of provinces threatened by a landing (row 10). On its full pass, or at war every third hour, the land block runs four steps in order: (1) **position** the divisions - part of the committed divisions become **garrisons** of the hold provinces slot 80 chose, the rest form the **line**, a count divided among the ops-area positions in proportion to their scores, at most 5 a position, and divisions held back by slot 78 go to a **rear ring** two provinces out; only one of those three kinds of move is made per pass, line first; (2) **fall back** - defenders are pulled out of a land battle they are losing; (3) **paradrop**, only where the agent has air transports; (4) **check marches** - long marches become strategic redeployments, a march that would cross hostile ground is cut to its next step. None of this reads the per-division `target`/`staging_province` that `AssignAreaTargetsAndSealift` posts; only the paradrop planner reads or writes them.

**Exe-hardcoded**: the 10 divisions of line per position; the 20.0 and 50.0 hold-score bars and the 10-victory-point bar; the allied-soil budget n/2, n/5, n/3; the front x2, 7, /3 and enemies x2 at war; 3.5 x cap and the five-times supply bar; the carry bar 0.1 and the +100 over-cap penalty; the line-choice weights x100, +0.1, x0.66 three times, -50 and -100 x terrain modifier; the squared distance x16 and dig-in/100; the rear ring's 20 per unit there and 30 per depot hop; 0.3 strength/organisation, and 0.75 strength / 0.9 organisation / 80 distance for reserves sent to a position; the fallback's 0.7 attacker share, 12/25 hours, fort < 3, +100 depot, +10 river, /100 inside the ops area; the redeployment factors 0.25, 200 at war, 600 at peace; the paradrop planner's +100000 for an unconnected army; every "area of more than 3 provinces" test, and the default stack cap of 20. **Mod-able**: `BASE_STACKING_PENALTY` (`defines.lua`, military) - the stack cap is round(0.5 / -value), 5 at TFH's -0.1; the unit files - which types are `garrison_brigade`, `militia_brigade`, `police_brigade`, `armor_brigade`, `light_armor_brigade`, `heavy_armor_brigade`, `mechanized_brigade`, `paratrooper_brigade`; `max_speed`, `range`, `transport_capability`; the map - forts, infrastructure, victory points, air bases, ports, continents, supply depots.

### A.1 Row 10, `CAIUnit_UpdateThreatenedProvinces` (`0x4B1820`), every hour

The list is `+0x1DC`/`+0x1E0`/`+0x1E4`.

1. **Pruning.** A listed province p stays only while both hold: p is in the agent's own theatre (`p +0x380/+0x384` against the agent's area id); and some edge of p leads to a sea province (not land, simulated) holding a land unit whose **next step** (first path node, `CUnit +0x138`) is p, and whose owner is hostile to us - at war, REB on either side, or an undeclared war covering the unit's province. Otherwise p is unlinked, or marked at node `+0xC` while the list's no-unlink byte `+0x1E8` is set. The walk always continues; there is no return.
2. **Adding.** For every unit on the sighted list `+0x25C`, every land unit it carries (`CUnit +0x2E4`) whose path's **last** node (`+0x13C`) is a province we **own** (`+0x330`) adds that province. This step has no hostility test.

It is also added to from outside the hour: `SetUnitPath` (`0x1C9AC0`) calls `CAIUnit_AddThreatenedProvince` when a land unit standing at sea gets a one-province path into a land province held by an enemy of its owner - the defending theatre's agent is told at once.

**Readers**: the tick runs slot 80 every hour while the list is non-empty; `RebuildHoldProvinces` adds 200.0 to a threatened province's hold score (VA `0x8B467B`-`0x8B46A5`); `CAIUnit_FillGarrisons` (A.5) raises that province's garrison want and never takes a garrison out of it.

### A.2 Row 15, the dispatcher `CAIUnit::PositionLandUnits` (`0x4CC450`)

1. Nothing for a non-root agent with an area - ManageLandUnits' gate; every agent is a root (`FINDINGS-agents.md` A.3).
2. **Positions** are the scored ops-area records (`+0x2C0`, map `+0x2D0`), or at plan stance 0 the hold positions (`+0x2FC`, map `+0x30C`). n = the committed-division copy `+0x13C`.
3. **The allied-soil budget**, truncated, less `divisions_on_allied_soil` (`+0x348`): n/2 if we lead a real faction (`CCountry +0xD8` slot 7: `CFaction` true, `CNullFaction` false; first member is us); else n/5 if the acting capital's area touches an area at war with it (`COwnerArea_TouchesHostileArea`, `0x7FD90`, section F); else n/3.
4. `CAIUnit_SplitGarrisonAndLine` -> (garrison count, line count).
5. Line count > 0 and positions exist: `CAIUnit_FillLinePositions`.
6. **Only if it moved nothing**, garrison count > 0: `CAIUnit_FillGarrisons`.
7. **Only if neither moved anything**, held-back divisions (`+0x15C`) and a second ring (`+0xA0`) both exist: `CAIUnit_PlaceReserves`.
8. `full_pass_pending` (`+0x84`) = 0.

Then the tick calls `0x4D7F80`, `0x4CC690` (only while `+0x10C` is non-empty) and `0x4CC020`, in that order (VA `0x8B0BC0`-`0x8B0BE8`).

### A.3 Garrisons and the split (`CAIUnit_SplitGarrisonAndLine`, `0x4C7AB0`)

1. **Garrison divisions.** Over `+0x13C`: a division with a `garrison_brigade` gets `ai_garrison` (`CUnit +0x2C9`) = 1 and is a garrison; an already-flagged division stays one only while it stands in land we control and is not a role-8 army while air transports exist; otherwise the flag is cleared.
2. **Garrison targets.** From slot 80's hold list (`+0x17C`, best first), records go onto the target list by descending score when the score is >= 20.0 and we control the province, and it is not an ops-area province under 10 victory points that is not its own depot. `strong` = the number of records with score >= 50.0.
3. **The counts.** n = |`+0x13C`|, posCap = 10 x |positions|. No positions: garrison = n. No hold provinces: line = n - |garrison-brigade divisions|. Otherwise: front = |`+0xC0`|; enemies = non-friendly land units on front provinces whose controller `IsFrontWorthyEnemy`; areaSum = the sum of those provinces' area sizes; **at war on the frontier**: front x2, front = max(front, areaSum < 7 ? 2 x enemies : enemies), strong = 1 if front <= enemies/3 and strong > 1, enemies x2; lineWant = min(max(enemies, front), posCap); garrison = min(holdCount, n, n - lineWant); if below g = min(max(targets, garrison-brigade divisions), n), raise it to min(g, n - front); then at least `strong`; line = n - garrison, any excess over posCap returned to the garrison. In a **scenario game only** (`CCurrentGameState +0xD0C` set; 0 in an ordinary game, `FINDINGS-agreements.md`) nine tenths of the garrison go to the line.
4. **Top-up.** Targets are filled from the rest of the hold list, best first and with no conditions, until there are `garrison` of them.
5. **Per region group** (`COwnerArea +0x6C`) of those targets, the shortfall added to the theatre's largest area's group, garrisons standing or heading in the group are matched to the group's count. **Too many**: drop the non-garrison-brigade division with the lowest hold score at its province (+1000 for a militia brigade, +500 for police); flag cleared. **Too few**: pick from unflagged committed divisions standing or heading in the group that face no neighbour we are preparing war on, at war carry no armour, light armour, heavy armour or mechanized brigade, and carry no paratroopers while transports exist. The best maximises (10 x garrison rating (slot 88, `RateUnitAsGarrison`, section B) + (mean distance to the ops area + 10)/5), x0.75 on a front province, x (1.5 - organisation share) - favouring real garrisons far from the fighting and worn down. The pick gets the flag.

### A.4 The line (`CAIUnit_FillLinePositions`, `0x4C8EE0`): divide and march

**Records** are `CAIProvinceRecord`: {province, aux, score, want, have, standing, cap}.

1. **Small fronts**: front provinces whose area has <= 3 provinces and fewer than 5 enemy land units, which a committed division stands or heads in.
2. **Apportion.** For each position in friend-held land (others keep their old `want`): have = standing = 0; a position whose **only** front neighbour is a small front gets want = -1000 and is left out; otherwise cap = `CAIUnit_GetPositionCap`, and want = trunc(line x score / `+0x34C`) capped at cap, remainders carried (0 for score < 1.0 when the total is >= 1.0). **The cap** (`0x4BF350`) is 0 unless the province borders enemy land or lies in the ops area; it is the stack cap (round(0.5/(-`BASE_STACKING_PENALTY`)), so 5) - min(6, fort x 2/3), at least 1; where every enemy neighbour's area has fewer than 6 provinces it is at most the enemy land units beside it (>= 1, doubled if one of those areas is coastal).
3. `CountUnitsAtPositions` (`0x4D9E30`): committed divisions, plus allies' units where they hold a focus area while at war.
4. **The remainder.** If nothing was given out: every position wants 1, or 2 where the province's units have a `CUnit +0xC0` above 0. Otherwise, while the carry > 0.1: +1 to the position with the least want (+100 to its key if want + 1 > cap; first of equals).
5. **Supply cut.** Where want > trunc(3.5 x cap) and the province's supplies are nought, or its supply need (`+0x24C`) is at least 5x its supplies (`+0x164`), want is cut to that; the excess goes to the other positions under their own 3.5 x cap - score >= 1 first in list order, then the rest in equal chunks.
6. **Each committed division** (not a garrison, not airborne-with-transports), with d = where it is heading or standing: heading for a friendly non-depot province while in a battle, it is re-ordered to its next step. It **stays** if d is a position that wants it (in a target area only while d is beside a hostile-route province). Otherwise it goes to the reachable position (have < cap) with the lowest key: key = have/want x 100, plus the excess over 1 again; at war, key = distance x (have/want + 0.1); x0.66 for a land battle there, x0.66 for a depot, x0.66 beside a hostile-route province; -50 x its defensive terrain modifier there (slot 89, `GetUnitTerrainModifier`, section B); with the allied-soil budget spent, moves from the capital's area onto a friend's soil are skipped. With no position and d not a position: a second-ring province (`+0xA0`) chosen by an MT19937 seeded with the unit's id. **Incomplete - see A.4b**: a division bound for enemy land is passed over first, and the re-ordered one goes on.
7. **Each position still short** pulls the best division by squared map distance x 16 + dig-in/100 + attack delay/1000 - 100 x terrain modifier here - x0.25 if its own position wants none, else +100 x its terrain modifier where it is bound. At war at plan stance < 2, a division not over-filling its own position only moves within two steps. It moves only from a position fuller than the target ((standing - k)/n > (have + not-depot)/want). Finding none: `CAIUnit_SendReservesToPosition` (`0x4CA9C0`) sends fit held-back divisions (strength >= 0.75, organisation >= 0.9, off the front, within distance 80), and only at war, to a position beside a hostile route or under a land attack whose attacker share is > 0.5; it clears `ai_held_back`. **Incomplete - see A.4b** for the candidates the pull may not take.

### A.4b The line's attackers and the pull's candidates (2026-10-19, a second reading)

Read off the listing on 2026-10-19, after OpenHOI3's build of steps 6 and 7 as written above sent Italy's divisions out of
their attacks on Ethiopia every three hours - each pass the line moved them to a position or the second ring and the
attack sent them back, so no attack ever arrived, and a division ordered out of a battle was left marked retreating. The
maintainer saw the symptom as units "moving to weird places": Bender Beila (9928), a second-ring province, among them.

**Step 6's head (VA `0x8C9AE2`-`0x8C9C66`)**, per committed division not a garrison and not airborne with transports:

```
d = CUnit_GetPendingDestinationProvince(unit)               ; 0x89B010
if (!d) { d = unit->current_province (+0x130); goto position logic }
if (d held by an enemy: +0xE28[controller]->+0x20 war, REB either side, or an undeclared war covering d)
    if (unit->+0x140 (path length) < 2)               skip the unit   ; 0x8C9BD5 jl 0x8CA2B7
    if (!d->area (+0x2B4)->slot0())                     skip the unit
    if (d->area->+0x2C (provinces) <= 3)                skip the unit
    goto position logic
else   ; ours or a friend's
    if (!retreat (+0x158) && IsHoldingGround(unit, 0) && d is not its own depot (+0x48 != +0xD0))
        MoveUnit(next step - or d itself with a path of one -, 0, 1, 1, 0); moved = 1
    goto position logic                                 ; 0x8C9C62 falls into 0x8C9C66
```

`0x8CA2B7` increments the unit index and loops: it is the per-unit `continue`. So **a division attacking a neighbour is
never re-positioned by the line**, and one marching deep into enemy land is re-positioned only where the land it is bound
for is an area of more than three provinces. And the friendly arm's re-order to the next step does not end the unit's turn.

**The pull's candidates (VA `0x8CA387`-`0x8CA4F3`)**, before any key is worked out - each refusal jumps to `0x8CA8CF`, the
candidate loop's `continue`:

1. retreating (`+0x158`), a garrison (`+0x2C9`), or standing nowhere (`+0x130`);
2. d = `0x89AF00(unit)` (a destination; not read), or where it stands; where d is its own depot, refused when
   `0x8AF4E0` answers true (not read);
3. with the allied-soil budget spent, refused when `CAIUnit_IsMoveFromHomeAreaToAlliedSoil` (`0x4C77C0`) says so;
4. airborne (`CArmy +0x2FC == 8`) while air transports exist;
5. holding ground (`CUnit::IsHoldingGround`) where its province is a position that wants divisions: the map looked up
   through `0x8DCF30` is the function's third argument, the position map (`mov edi,[ebp+0x10]`), keyed by the unit's
   province, and the test is the record's want (`+0xC`) above nought - *read on 2026-10-19 after an Ethiopian division,
   defending Tandaho, was sent on by step 6 and pulled straight back, a halt that left it marked retreating for good*;
6. **d held by a country it is at war with (`CCountry::IsEnemy`, `0x42F210`) and beside the province the unit stands in**
   - the walk is over the unit's province's edges (`+0xD4` -> `+0x90`/`+0x94`, stride `0x14`), any kind, comparing each
   target with d's id (`+0xD0`). An attack under way is not pulled.

**What would show this wrong**: `0x8CA2B7` not being the per-unit continue; the pull's edge walk being over d's edges.
**Positive control**: OpenHOI3 built with these two blocks and two other corrections of the same day - the reach test of
step 6, which the reading above already had, and the split's per-block count over the first `garrison` targets, which
the record already had - moves 763 of 908 divisions as the 4 January save does, where it moved 710 before; Germany's
divisions left standing where the original's moved fall from 16 to 1 against the Ireland game's save of 2 February.

**Left open**: what `0x89AF00` and `0x8AF4E0` are. And whether a division ordered out of a battle
and then halted in the same pass is left marked retreating in the original too: `SetUnitPath` marks it and only arriving
clears the mark (`FINDINGS-landbattle.md`, section 7), `CUnit::CancelMovement` does not touch it, and
`CAIUnit_CheckLandMarches` can post that halt after the line's move - unless the original's command queue runs a posted
move before the march check reads the path. OpenHOI3 has the march check pass over a unit the pass has just sent
elsewhere.

### A.4c `MoveUnit`'s gates and the very safe finder (2026-10-19, a third reading)

Read off the listing on 2026-10-19 after the maintainer saw, in a game of OpenHOI3's, Italian divisions in Ethiopia
"joining an attack, then stopping, then attacking again, over and over". Two causes, both OpenHOI3's departures from
readings already here, and both now in the record in full.

**`CEU3AI::MoveUnit` (VA `0x89A840`), its gates in order**: a retreating unit is not moved; the unit's slot 35 may refuse
the province; `recordOnly` writes `+0x2CC` alone; the unit's own province gives the stand-down where it is going
somewhere or `0x49AEC0` says so; **a unit whose destination (`0x49AF00`) is already the province is left alone - unless
it holds ground** (`CUnit::IsHoldingGround`), when the move is posted again and `SetUnitPath` takes it out of every
battle (`FINDINGS-movement.md`, section 4); then the redeployment order where `safe` and the distance say so, else the
`CMoveCommand` with its two flags. So re-ordering a fighting attacker into the province it attacks takes it out of the
attack. **`CAIUnit_ManageLandUnits`'s commit loop never does it**: it passes over every attacker whose pending destination
is an enemy's province, the target included (`FINDINGS-aiconsumer.md`, *The decision*). OpenHOI3 had exempted the target,
and so re-ordered its attackers every three hours.

**`CVerySafePathFind::MayStep` (VA `0x5A2C40`)**, the finder every line, garrison, rear and reserve move asks for: past
the base's tests and short of the goal, a land unit (slots 16 and 17 both false) may not step into a province whose
controller is at war with it (`CCountry::IsEnemyTag`, REB counted) nor one with a **land** battle in it
(`CMapProvince::HasCombatOfKind` with kind 1, which `CreateCombat`'s jump table makes `CLandCombat`). And
`CMapProvince::CanUnitReach` with its second argument set - as the line's three reach tests pass it - builds a
`CSafePathFind` (VA `0x5C7914`), so the line chooses among positions it can reach the safe way. OpenHOI3 had taken the
plain way for both, and a line position reached only through enemy land was chosen, marched for, cut by
`CAIUnit_CheckLandMarches` at the first hostile province and chosen again the next pass.

**Positive control**: with both, the 26a Divisione 'Assietta' is ordered into 9846 once, takes it, and goes on to 9887,
where it had been re-ordered every three hours; Italy holds 9 Ethiopian provinces on 2 February to the original's 8.

### A.4d The pull's fuller test (2026-10-19, a fourth reading)

Read off the listing (VA `0x8CA2C7`-`0x8CA969`) on 2026-10-19 after the maintainer saw, in a game of OpenHOI3's played
as Ireland, Italy's army "always moving" in its home territories. OpenHOI3 had the pull's candidates (A.4b) but compared
the two positions' fullness on a guess, and divisions were pulled from one position to fill another and pulled back the
next pass. The test, whole, for a position T that is short and a candidate whose destination - or, with none, the
province it stands in - is `d`:

1. **T's fill** = (T.have + notDepot) / T.want, in single precision, where notDepot is 0 when T's province is its own
   supply depot (`+0x48 == +0xD0`) and 1 otherwise.
2. D is the position record of `d`, or none. **count** = D.standing where the unit stands at `d`, else D.have.
3. The candidate is **taken without the test** where D is none, D.want <= 0, or - when it does not stand at `d` - T has
   nobody standing in it and the unit stands in T.
4. Otherwise **k** = 0 where notDepot is 0; else 1 where T.have is not nought or count <= 1; else 0. **It is passed over
   unless (count - k) / D.want > T's fill** - it is taken only from a position that, less itself, would still be fuller.
5. **A low stance holds it close**: where the agent's byte `+0x364` is set, the plan's stance is below 2 and count <=
   D.want, it is passed over unless T is a neighbour of the province it stands in, or a neighbour's neighbour - the edges
   walked with impassable ones (kind 3) skipped and each neighbour needing its `+0x22` and `+0x13D` bytes.
6. The score (A.4) is **x 0.25 where D.want < 1, D none included**, else + 100 x the unit's terrain modifier at `d`. The
   lowest by strict `<` that `CanUnitReach(T, unit, 1, 1)` and `0x8BEC70` both pass is chosen.
7. Once chosen: D.have - 1, and D.standing - 1 where the unit stands in D's province; `0x8C78E0` (the allied-soil
   budget's, not read); `MoveUnit(unit, T, 0, 1, 1, 0)` - very safe; T.have + 1, and T.standing + 1 where it stands in T.
   The pull repeats while T.have < T.want, and with no candidate left `CAIUnit_SendReservesToPosition` is asked.

**Positive control**: built so, with the supply gate of `CPathFind` (A.4c's base) and the AI's pass run once an hour,
OpenHOI3's Italian divisions stopped changing places, and the agents check moves 774 of 908 divisions or leaves them as
the 4 January save does, against 767 before. *Hardcoded*: every figure here; nothing is a define.

### A.5 Garrisons placed (`CAIUnit_FillGarrisons`, `0x4CACB0`) and the rear (`CAIUnit_PlaceReserves`, `0x4CB840`)

**Garrisons.** Each target wants |garrisons| / |targets|, the first remainder ones one more. A threatened target adds the brigades of hostile land units heading in. The want is capped at the stack cap. Candidates are the garrison divisions, plus every agentless division of the played country. A candidate must be out of battle, free to leave, in the target's area (any area if that is a focus area), and not in a threatened province; unless the target is threatened, it is not pulled from a fuller hold position. The nearest by squared distance wins (x2 for a role-5 army leaving a higher-scored position).

**Rear.** One record per second-ring province, cap = round(10 x effective infrastructure). Each held-back division with no blocking order, not a garrison, and not already within such a province's cap: **stays** if it is beside a war candidate's province across a river or in a fort, with strength and organisation > 0.3; **stays** if it is beside war-candidate units, fit, and our other idle divisions there are fewer than half those units; otherwise goes to the ring province with the lowest distance + 20 x have - 30 x (its depot hops - that province's).

### A.6 `0x4D7F80`, `0x4CC690`, `0x4CC020`

**Fall back (`CAIUnit_FallBackFromLosingDefences`, `0x4D7F80`).** For each ops-area province p that is not its own depot and has fort < 3, and each land battle there at least 12 hours old (25 at stance >= 3), where we are a defender and the attacker share (slot 17) > 0.7: score p's neighbours - a hostile one across a river ends the look; one we may operate in scores infrastructure/1000 + 2 x fort, +10 across a river, +100 if p's depot, /100 if inside the ops area. If no friendly unit is already heading into p, send every defender with no blocking order, one per candidate in score order, round again while defenders remain; with any outside candidate, the walk stops at the first inside one. Each send is a plain `MoveUnit(0,0,0,0)` and sets `full_pass_pending`. Always answers false.

**Paradrops (`CAIUnit_PlanParadrops`, `0x4CC690`).** k = min(role-8 armies, air transports). **Targets**: up to k of `CEU3AI +0xD8`'s weak enemy ports, each with the nearest friendly air base within the first transport's `range`; at war, only our own bases count when the port is on another continent from the agent's HQ. **Assignment**, round-robin over the targets: the nearest airborne army gets staging = target (written directly, then `CSetAIParamCommand(unit, target, staging)` posted); it marches there if connected by area, else to its area's nearest air base, else asks for sealift (target = the nearest port of the target's area). **At a friendly air base**, an army takes the nearest empty transport: if the plane is there, `CLoadOnPlaneCommand` and `paradrop_mission (0x570)` at the army's staging; if not, `rebase_air (0x574)` to the army's base. **Hostile targets**: idle transports at the target's base load an army there and fly `paradrop_mission` at the target.

**March check (`CAIUnit_CheckLandMarches`, `0x4CC020`).** Over `+0x11C`: a march not already a strategic redeployment becomes one (`IssueUnitOrder 0x5A4`) if `CEU3AI_ShouldRedeployStrategically` (`0x499E50`) agrees; a unit in a battle whose next step is enemy-held is stood down (`0x49AAB0`: null order + `CCancelMovementCommand`); for each hostile province on the path before its last, an HQ is stood down and a division is cut to `MoveUnit(next step, 0,0,0,0)` when that province's area has more than 3 provinces - which can be posted repeatedly.

### A.7 What each path posts

| path | command |
| --- | --- |
| line, garrisons, rear, reserves to position | `CEU3AI::MoveUnit(u, p, 0, safe=1, verySafe=1)` -> `CMoveCommand(p, 1, 1, 1)` and `CUnit +0x2CC = p`; or `IssueUnitOrder(0x5A4)` strategic redeployment if not adjacent and distance >= max_speed/1000 x 0.25 x (200 at war / 600 at peace); a halt (`0x49AAB0`) if p is the unit's own province while it moves; nothing if it is already going there and not fighting |
| fall back, march cut | `MoveUnit(..., 0,0,0,0)`: plain `CMoveCommand`, no redeployment |
| march check | `IssueUnitOrder(0x5A4)`, `0x49AAB0` stand-down |
| paradrop | `CSetAIParamCommand(u, target, staging)` (`Execute`: `CArmy +0x2E8 = target`, `+0x2E4 = staging`), `CLoadOnPlaneCommand(u, air)` (boards, null order), `IssueUnitOrder(air, 0x570 / 0x574, province)` |

**How this meets `AssignAreaTargetsAndSealift`'s targets (section F).** The line, garrison and rear steps never read `target`/`staging`. A division marching under the sealift to an embark port whose destination is not a position wanting it can be re-routed by the line step (inferred; slot 86, `IsUnitReservedForTransport`, is not consulted here). The paradrop planner writes `staging` and, failing an air base, `target` = a port: an explicit request for the sealift.

### A.8 The leftovers

- **`0x4E5` and `0x56C`**: `support_attack` (`CSupportAttackOrder::GetTypeId`, `0x183780`, `mov eax,0x4E5`) and `carrier_protection` (`CCarrierProtection::GetTypeId`, `0x188AC0`); each body in exactly one vftable, slot 16. The record already had both; confirmed off the bytes. A unit under either counts as idle, not blocked.
- **`CUnit +0x2C9`** = `ai_garrison`. Whole-image displacement scan: 14 sites, the four byte writes all in `0x4C7AB0`, plus ClearUnit's dword clear at `0x4BA0A2`; positive control, the same scan for `+0x2C8` finds slot 78's known writes.
- **`CCountry +0xF50`** = `provinces_in_revolt`, already in the record. The whole-image scan gives exactly three writers: zeroed at `0xD42A4` (`CCountry_Reset`) and `0xE2317`, incremented at `0xE2A05` (`RebuildNeighbours`, per rebel-held province). Readers: the tick's two war gates and the two revolt triggers.

### A.9 Against the saves

`staging_province` appears in none of `_01_01_00`, `_01_04_12`, `_04_20_03` - the paradrop planner never runs in 1936, there being no role-8 armies with transports. Divisions per province: Italy's history stack of 7 in 9749 has spread out by 20 April, and no province then holds more than 3 Italian divisions; Ethiopia and France have no stack above 5 on 20 April; the Soviet Union has one province (1814) with 8, which can fit the rear ring (its cap reaches 10 by infrastructure), not checked; Italy had 6 in 9767 on 8 January - the Africa ops province where the stance-4 path starts, and ManageLandUnits' attack orders are not capped. Consistent with a 5-per-position line, not a proof.

### What looks wrong but is what the bytes do

1. Only one of line / garrison / rear moves anything in a pass: garrisons wait until the line is content, the rear until both are.
2. A position in land not held by a friend keeps its previous `want`; a `-1000` position still passes the "want != 0, have < cap" test if it kept a cap from an earlier pass.
3. The second-ring fallback seeds an MT19937 with the unit's id; the draw is used through a signed `idiv`, so a negative draw gives a **negative index** into `+0xA0` (VA `0x8CA270`). What is read there is not established.
4. `CountUnitsAtPositions` counts a unit leaving one position for a friendly one nowhere if its current record comes first in the list.
5. `CheckLandMarches` can post `MoveUnit` to the same next step once per hostile province on the path, and switching to redeployment does not set its answer.
6. The paradrop planner writes `CArmy +0x2E4`/`+0x2E8` directly on the worker thread before posting the command that writes them again.
7. `FallBackFromLosingDefences` always answers false; a hostile neighbour across a river cancels the whole fallback from that battle.
8. Garrison picking prefers divisions **far** from the ops area and worn down (x (1.5 - organisation)).
9. `GetPositionCap` doubles a small enemy area's unit count when that area is coastal.
10. In a scenario game nine tenths of the garrison go to the line; in an ordinary game never.

### What could not be settled

- `CountUnitsAtPositions`' record-walk order and `CountAlliedSoilMove`'s restore arm come off the decompiler only (both entered `inferred`).
- The comparator of the two `std::sort` calls in the supply cut (`0x4DDFF0`, with the byte at VA `0x1B15244`), so the order spare `want` is handed out in.
- `CUnit +0xC0`, summed over a province's units in the zero-assignment fallback; not named.
- `CUnit +0xC8 -> +0x108`: whose max_speed this is for a division.
- Whether the negative MT index ever happens in play.
- The Soviet stack of 8 in province 1814.

### Frontier

`0x4972E0` `RebuildWeakEnemyPorts` (section E; fills `CEU3AI +0xD8`, the paradrop targets). Unassigned: `0x4DDFF0`/`0x4DE0E0`/`0x4DE890`/`0x4DE770`/`0x4DE840` (the record sort and its key); `0x49AEC0` (MoveUnit's "has an order" test); `0x49AD00` (`IssueUnitOrder`'s tail, the command an order posts); `0x4B3A50` `RebuildHoldProvinces` (slot 80, `inferred` - its scores drive the garrison targets, the +200 for a threatened province among them); who sets `CArmy +0x2FC` = 8 (airborne) and = 5.

### The function table (A)

`0x4B1820` `CAIUnit_UpdateThreatenedProvinces` revised confirmed; `0x4CC450` `CAIUnit::PositionLandUnits` new; `0x4C7AB0` `CAIUnit_SplitGarrisonAndLine` new; `0x4C8EE0` `CAIUnit_FillLinePositions` new; `0x4CA9C0` `CAIUnit_SendReservesToPosition` new; `0x4CACB0` `CAIUnit_FillGarrisons` new; `0x4CB840` `CAIUnit_PlaceReserves` new; `0x4CC020` `CAIUnit_CheckLandMarches` new; `0x4CC690` `CAIUnit_PlanParadrops` new; `0x4D7F80` `CAIUnit_FallBackFromLosingDefences` new; `0x4BF350` `CAIUnit_GetPositionCap` new; `0x4D9E30` `CAIUnit::CountUnitsAtPositions` new inferred; `0x4C77C0` `CAIUnit_IsMoveFromHomeAreaToAlliedSoil` new; `0x4C78E0` `CAIUnit_CountAlliedSoilMove` new inferred; `0x499E50` `CEU3AI_ShouldRedeployStrategically` new. Fields: `CAIProvinceRecord` declared (0x1C: province, aux, score, want, have, standing, cap) new; `CUnit +0x2C9` `ai_garrison` revised (name, was `unknown_2c9`); `CAIUnit +0x16C` `role8_armies_first` revised (comment: role 8 is airborne).

## B. Attacking's open ends

*Read 2026-10-19 off `hoi3_tfh.exe`, every function disassembled whole and cross-checked against the Ghidra decompilation of the applied record. Addresses are rvas.*

This section reads what `FINDINGS-aiconsumer.md` left open in `CAIUnit_ManageLandUnits` (`0x4D57F0`). Phases 1-3 of that function are as that file has them, with the one correction in B.4.

**In short.** Slot 86 reserves a division for a paradrop or a sealift; slot 88 rates a unit 1-100 as a garrison; slot 89 is the unit's own terrain modifier at a province, **not** the enemy's power as had been assumed. **A called-off attack stops in place and does not reverse** - a null order and a `CCancelMovementCommand`. Slot 17 gives the same "losing" test in the land and naval bodies. **Correction to `FINDINGS-aiconsumer.md`**: the candidate list in `ManageLandUnits` is sorted **ascending** and units are taken **lowest score first**, so `CUnit +0x2B8` is a cost, not a fitness.

### B.1 Slot 86, `CAIUnit::IsUnitReservedForTransport` (`0x4C7540`): the veto on a unit

`bool (agent, unit)`, `ret 4`. **The agent is never read** - ECX is overwritten by the sub-unit database singleton at the first instruction. The unit must be a land unit: every field read goes through `unit->slot9()`, which returns the unit itself on `CArmy` and is the null stub elsewhere.

It answers **true** - the unit is spoken for - in two cases.

1. **A paradrop** (`0x4C75BF`-`0x4C7615`): the army's `staging_province` (`CArmy +0x2E4`) is above 0, and it holds at least one brigade of the database's `paratrooper_brigade` type (counted by type into an `_alloca`'d array, `CUnit_CountSubUnitsByTypeIndex`).
2. **A sealift** (`0x4C761E`-`0x4C77A1`): the army's `target` (`CArmy +0x2E8`) is above 0; climbing from the unit through its parents (`+0x1E0`), the **topmost** non-null `ai_agent` (`+0x198`) on the chain must exist and be a `CAIUnit` (slot 65 true; a `CAIInvasion` answers false); that agent's unit (slot 74) has a plan **debark** (`CUnit +0x288`) equal to the army's `target`. With `dest` = `CUnit::GetMovementDestinationProvince(unit)`, or the province it stands in when that is null, and *area* = `CMapProvince +0x2B4`, the veto holds if **either** the unit is **not** standing in the debark port's area **and** `dest` is in it, **or** the plan has an **embark** port (`CUnit +0x284 > 0`) **and** `dest` is in the embark port's area.

In words: a division voted onto a sealift is untouchable while it walks to or waits at the embarkation area, and while it is bound into the debark area; it is free again once it stands in the debark area, unless the two areas are one.

**The save shows that state.** In `Germany1936_01_04_12` a plan has `embark=5762`, `debark=10636`; exactly one division carries `target=10636`, under a `strategic_redeployment` to province 5762 - its `dest` is in the embark area, so slot 86 vetoes it. No save holds a `staging_province`, so the paradrop arm has no witness.

Callers through `[vftable+0x158]`: `CAIUnit_ManageLandUnits` three times - the candidate filter (`0x4D6DAD`), **the commit loop (`0x4D7579`), which `FINDINGS-aiconsumer.md` did not list**, and the stand-in test (`0x4D7768`); `CAIUnit_MoveAgentUnitToCommandProvince` (`0x4D5773`); `ManageSubordinates` (`0x4B2705`: it clears `ai_held_back`, and the unit is neither committed nor held back); `OrganiseCommands` (`0x4C21C3`) and slot 32 (`0x4B1235`).

**Slot 86 tests no order kind.** The `0x4E5`/`0x56C` test is elsewhere: `0x49AEC0` and the recorded `UnitHasBlockingOrder` (`0x4AF4E0`); `saveTokens.json` names `0x4E5` `support_attack` and `0x56C` `carrier_protection`.

### B.2 Slot 88, `CAIUnit::RateUnitAsGarrison` (`0x4BE560`): the float compared against 95

`float (agent, unit)`, `ret 4`, answer in ST0; the agent is never read. **A garrison rating from 1 to 100**, and 0.0 when the unit has no brigades (`regiments_count`, `+0x40`, < 1).

For each brigade `b` of the unit (`CUnit +0x38`):

```
fill  += float(strength(b)/1000) / float(GetMaxStrength(b, 0, 0)/1000)   ; CSubUnit +0x5C, slot 12, no reserve penalty
score += 100   police_brigade or garrison_brigade
          90   militia_brigade
          75   paratrooper_brigade or marine_brigade
          20   infantry_brigade
          10   bergsjaeger_brigade
           1   anything else
```

The brigade's type is matched by comparing the database's own definition at the brigade's `type_index` with the cached role definitions. Then, with `n` = regiments_count:

```
r = (score/n + (2 - n) * 20) * (2.0 - fill/n)
r > 100  ->  100
r < 1    ->  1
```

Each term is rounded to float before it is added; `score/n`, `fill/n` and the product are each computed in double and stored as float; the clamp compares in double against 100.0 and in float against 1.0f. So a one-brigade garrison or police unit is 100 at any strength (100 + 20, clamped); a two-brigade one is 100 at full strength; a unit under strength rates **higher** than a full one, up to x2 when empty; a three-brigade infantry division is 20 - 20 = 0, clamped to 1.

`ManageLandUnits` adds 100 to a candidate's cost when the rating exceeds 95.0f (`0x4D70DA`), which puts garrisons **last** in the attack list (B.4). Slot 88 is also called by `CAIUnit::AssignAreaTargetsAndSealift` (`0x4C61D6`, section F) and by `0x4C7AB0` (`0x4C8D49`), a callee of the land block `0x4CC450` (section A).

### B.3 Slot 89, `CAIUnit::GetUnitTerrainModifier` (`0x4BE7E0`): not the enemy's power

`float (agent, province, unit, bool attacking)`, `ret 0xC`, answer in ST0. Let `adj` be the unit's own definition's (`CUnit +0xC8`) terrain adjuster for the province's terrain id - `CSubUnitDefinition +0x54`, indexed by terrain id, 0x18 bytes each; the id is `CMapProvince +0xD4 -> +0xC -> +8`. The adjuster holds `attack` at +8, `defence` at +0xC and `movement` at +0x10, all x1000.

- **attacking = true:** `float(adj.attack/1000) + float(adj.movement/1000)`.
- **attacking = false:** `float(adj.defence/1000)`, **plus** an "average" over the province's land, simulated neighbours (edge kind != 3) whose controller the agent's country's strategy counts a war candidate (`CAIStrategy::IsWarCandidate`). The averaged quantity is `adj.attack + adj.movement` **of the province's own terrain again**: `0x4BE93B` reloads the province argument, not the neighbour. So the term is that same figure whenever at least one such neighbour exists, and 0 when none does.

Callers: `ManageLandUnits` with `attacking = 1` (`0x4D70B6`); `0x4C8EE0` twice with `attacking = 0` (`0x4CA0B2`, `0x4CA858`), a callee of the land block (section A). So the attack term the AI weighs a candidate by is **how well this unit attacks and moves on the target's ground** - not a power estimate of either side.

### B.4 The candidate order in `ManageLandUnits` - a correction

`FINDINGS-aiconsumer.md` says the candidates are "inserted descending by `+0x2B8`" and "committed best first". The bytes say the opposite. The insertion (`0x4D7162`-`0x4D71F2`) walks from the head (`[ebp-0x9C]`, next at +8); at `0x4D7182`, `comisd xmm0(node's +0x2B8), xmm1(new); ja` inserts **before the first node scoring more**, and otherwise appends at the tail - so the list is **ascending, ties in arrival order**. The commit loop (`0x4D73F3`) walks from the same head. So **the unit with the lowest `CUnit +0x2B8` is tried first**, and the score is a cost:

```
cost = 10 * (enemy land neighbours of the unit's own province)
     - 10 * GetUnitTerrainModifier(target, unit, attacking = 1)
     + (RateUnitAsGarrison(unit) > 95 ? 100 : 0)
then / 10 when [ebp-0xA0] != agent, else / 5 when UnitHasBlockingOrder(unit)
```

In words, the AI first sends units not needed against enemies of their own, units good at attacking and moving on the target's terrain, and field units ahead of garrisons. The rest of the commit loop stands as `FINDINGS-aiconsumer.md` read it, plus slot 86 asked again of each candidate (`0x4D7579`).

### B.5 `0x49AAB0`, `CUnit::AIStandDown`: a cancelled attack **stops, it does not reverse**

`void (unit@ECX, CEU3AI* ai)`, `ret 4`, 287 bytes. In order:

1. If the unit's order (`+0xB0`) slot 16 is not `0x18D` (`none`): `CEU3AI::IssueUnitOrder(ai, none, unit, provinceId@EDI = the province the unit stands in)` - a `CSetOrderCommand` for a null order, posted.
2. `movement_destination_province_id` (`CUnit +0x2CC`) = 0 - **a direct write, not a command**, so the rest of the AI pass sees the unit as going nowhere.
3. `new CCancelMovementCommand(unit)` (0x64 bytes, constructor `0x1D96D0`), posted on the session's queue.

The command's Execute is the recorded `CUnit::CancelMovement(unit, true)` (`FINDINGS-movement.md` section 4): the path emptied and the progress lost, the order nulled, the unit leaving every battle it was **attacking** in, staying in the province it stood in. **So a unit called off an attack halts in place**; nothing orders it back, and it keeps defending in any battle where it is the defender.

| site | when |
| --- | --- |
| `CEU3AI::MoveUnit` `0x49A93E` | told to move a unit to the province it already stands in (not `recordOnly`), when the unit is moving (`+0x2CC > 0`) or `0x49AEC0` answers true - its order is neither `support_attack` nor `carrier_protection` and its slot 24 is true |
| `ManageSubordinates` `0x4B2288` | a land unit on `support_attack` that is neither holding ground nor retreating (`FINDINGS-agents.md` C.6) |
| `0x4CC020` `0x4CC15B`, `0x4CC2C4` | section A |
| `ManageLandUnits` `0x4D7BCF` | the call-off: odds below 0.8 (0.01 relaxed) before and after committing |
| `ManageLandUnits` `0x4D7F14` | phase 3 (B.6) |

### B.6 Slot 17's sign: both bodies mean "our side is losing"

Every combat kind holds `0x17B050` at slot 17, the recorded `CCombat::GetAttackerStrengthShare` - the **attacker's** share of the two sides' strength in thousandths, each side floored at 1. **Land phase 3** (`0x4D7DA1`-`0x4D7EBB`) tests it **only after finding the unit in `combat->+0x14` (defender) `->+0x40`**: a share above 0.5 means the attacker is ahead, i.e. **we are losing**, and the unit stands down if `CUnit::MayLeaveCombats` agrees. **The naval body** (`0x4D09F3`-`0x4D0A46`) takes the share directly when the fleet attacks and complements it when it defends, then disengages below 0.5 - again "our share < 0.5". No contradiction: the land body tests only the defender case.

### B.7 `CMapProvince +0x330` and `+0x354` in the port test - already named

Both sites (`0x4D73D0`, `0x4D77CA`) read them off the **target** province: `+0x330` is the record's `owner_id` (owned), `+0x354` is `port` (a `CPort` exists), `+0x300 -> +0x20` is `naval_base->level_max > 0`. So `portSupply` reads: **some attacker stands in a province drawing on no depot (`+0x48 == 0`), and the target is owned, has a port position and has a naval base built** - which relaxes the bars to 0.2 / 0.01.

### B.8 `CAIUnit +0x12C` - the committed divisions

The record's `committed_divisions_first`, now confirmed: erased by `ManageSubordinates` at the top of its pass (`0x4B1D87`); pushed at `0x4B2885` for a land unit of `oob_level` 4 (`0x4B2720`) that slot 86 did not claim and that was not held back (`+0x13C` gets a copy); pushed again at `0x4B2CD4` for a recalled division. For `FINDINGS-opsarea.md` item 7: `m` is the number of divisions committed to the line; spreading `m` over `n` ops-area provinces, `m mod n` get one more than `m div n`, and those are given the flat +20 - *inferred*, the reading of the arithmetic.

### Which figures a mod can move

**Exe-hardcoded**: slot 88's 100/90/75/20/10/1, the `(2 - n) x 20` term, the `2.0 -` strength factor, the 1..100 clamp; the 95.0 threshold and the +100; the x10 weights on slot 89 and on enemy neighbours; the 0.5 disengage bar; the order the stand-down posts its two commands in. **Mod-able**: the brigade type names in the units files (slot 88 matches `police_brigade`, `garrison_brigade`, `militia_brigade`, `paratrooper_brigade`, `marine_brigade`, `infantry_brigade`, `bergsjaeger_brigade` through the database's cached keys; a mod's brigade under another key scores 1; slot 86's paradrop arm needs `paratrooper_brigade`); each unit type's terrain blocks (`attack`, `defence`, `movement`) in `units/*.txt`, slot 89's figures; the province terrain in the map files.

### What looks wrong but is what the bytes do

- Slot 89 with `attacking = 0` averages the target province's *own* terrain term over its war-candidate neighbours; the neighbour's terrain is never read.
- Slot 88 rates an under-strength unit as more of a garrison, by up to x2.
- `CUnit +0x2B8` is named a fitness but is a cost, taken lowest first; a garrison's "+100" is a penalty.
- Slot 86 never reads its receiver; the agent it asks is the topmost one above the unit.
- The stand-down zeroes `CUnit +0x2CC` directly in the AI pass, outside any command.

### What could not be settled

- **The `/10` arm of the cost**: it tests `[ebp-0xA0] != agent`, and which local `[ebp-0xA0]` holds at `0x4D7101` was not traced; it stands as `FINDINGS-aiconsumer.md` wrote it, unverified. The collecting session saw the same slot reused as scratch for a stack pointer at VA `0x8D71B8`, inside the insertion, so the slot is not one variable through the body and the arm's real condition needs tracing from its last write before `0x4D7101`.
- Whether the direct write to `CUnit +0x2CC` matters across peers.
- The paradrop arm of slot 86 has no witness in any save.

### Frontier

`0x49AEC0` (section A: the `0x4E5`/`0x56C` order test, `UnitHasBlockingOrder` without the moving test); `0x4C7AB0`, `0x4C8EE0`, `0x4C78E0` (section A: land-block callees calling slots 88 and 89); `0x1E1E70` (the `CSetOrderCommand` constructor `CEU3AI::CreateUnitOrder` uses, `ret 0x18`, unrecorded); `0x2DD70` (the unit-reference builder every command constructor calls at +0x3C, unrecorded).

## C. The division need, `their_power` and `our_power`'s last terms

*Read 2026-10-19 off the listing and checked against the saves. Addresses are rvas unless marked VA.*

**In short.** The division need's exact arithmetic (`CAIUnit::EstimateAreaNeed` / `EstimateTheatreNeed`), `their_power`, France's 0.5% in `our_power`, and how a power under 1.000 got past the whole-number gate are all settled. **Every European Soviet theatre needs 18 divisions**: the 18 is a floor for the capital's area (73 naval-base levels / 4), because the whole 2694-province Soviet area is Moscow's area, and it reproduces three of the five Soviet transfers exactly. `their_power` reproduces exactly wherever a post falls inside a save window (Kwantung 13812, Paris 92, Bordeaux 2988). France's 0.5% is technology toughness counted twice. **Correction**: `FINDINGS-power.md`'s pseudocode for `EstimateAreaNeed` was wrong in its core - the province-count division (`/ min(provinces, 40)`) applies to a second, float estimate built from province values, not to the weight sum; the weight sum is rounded half to even by `fistp` and never divided; the per-province score is `n x weight`, not `n x weight / 1000`; nine further steps were missing, among them a hardcoded Italy/Ethiopia/Addis Abeba case and a USA/Britain case. `0x508C30`, queued from the agent wave, is a VA: rva `0x108C30`, `CCountry::UpdateLendLeaseRoutes`, already recorded - not this topic.

**In one paragraph.** A theatre agent's division need is the sum over its theatre's owner areas of `EstimateAreaNeed(area, relaxed = 1)`. Each area is weighed two ways: **N1**, from the foreign front provinces facing it - each scores `max(floor, n x weight)` in thousandths, n being the hostile land units standing there, and the sum over 1000 is rounded half to even; and **N2**, only for an area that is ours - the theatre's own provinces in it valued as floats, summed, and divided by `min(provinces, 40)`, at most a quarter of its provinces. The larger of the two is taken only where the area has a live front. Then come the focus areas of the same side, recursively, and seven adjustments. **The one with teeth is a floor for the capital's area**: a major (or a country over 100 IC) needs at least `max(naval-base levels / 4, ports / 2)` there. For the Soviet Union, whose European and Asian land is one 2694-province area containing Moscow, that floor is 18, and it is every European theatre's need. `their_power` is gathered on the same walk: `GetPower` of the hostile units in the counted front provinces, times the province's weight / 1000, multiplied by 1.5 where the province lies in the capital area of a faction leader (at weight 500, x0.75 overall).

**Exe-hardcoded**: the weights 500/1000/2000 and floors 500/1000; the infrastructure statics 200 and 300 (`(int)floorf(N.5f)`, rvas `0x17151E4`, `0x1715204`, `0x1715218`); the rounding (`fistp`, half to even); 40 provinces, the `/4` cap, the 3- and 15-province clamps, F > 2.0; the 10% surrender threshold; +4 when Pf > 3; the 2 x enemy-brigades halving; the capital floor (`levels/4`, `ports/2`, `3 x ports`), `is_major` or `max_ic > 100`; the foreign halving; **ITA/ETH and province 9943 (Addis Abeba) by number**; in the province value every weight (3 x fort, 5 x (cf + 1), the GER/ITA naval curve, x2 under 15 provinces, 2vp + 5, the VP share x100, +100 capital, +60 resource, 0.5 x IC, +100 depot, 30 + 2 x ships, 0.25 x priority, threat >= 100) and **the USA-while-Britain-stands switch (2000 thousandths of core VP)**. **Mod-able**: `diplomacy.NAP_UNBREAKABLE_MONTHS` (`defines.lua`); the map and buildings (infrastructure, **naval-base levels and ports, which set the capital floor**, forts, coastal forts, air bases, industry); victory points, strategic resources and capitals (`history/provinces`, country history); unit stats and technology effects (`GetPower`); faction membership and order (the faction's first member taken as its leader); threat and antagonism (the AI strategy); which countries are front-worthy (`FINDINGS-theatres.md` D).

### C.1 `CAIUnit::EstimateTheatreNeed` (`0x4B9610`), whole

`theatre = GetArea(this)`. With no theatre the answer is 0 and `*theirPowerOut` is not touched. Otherwise one `visited` list is made, and for each `COwnerArea` of `CTheatre +0x84`, in order, `need += EstimateAreaNeed(area, theirPowerOut, &visited, 1)`; the list is freed and the sum returned, with no cap of its own. `visited` is shared, so a focus area is counted once, under the theatre's first area in its region group; the theatre's own areas never go on `visited`. Every area that takes no early exit gives at least 1.

### C.2 `CAIUnit::EstimateAreaNeed` (`0x4B82F0`, `ret 0x10`), in order

C is the agent's country and R the area. All divisions are C integer divisions, toward zero.

0. **Enemy area.** If `CCountry::IsEnemy(C, R's first province's controller, that province)` (`0x2F210`): answer `CountEnemyUnitsInArea(&C.strategy, R, 0)` (`0x4A8EF0`). No power, no recursion, no floor.
1. **Italy.** If C is ITA and R's first province is held by ETH (the `CCountryDataBase` tag cache): answer 0.
2. **objCount.** The plan's objectives (`CUnit +0x234`) lying in R that carry this theatre's stamp (`+0x380/+0x384`); with no theatre, those lying in the plan's ops area. For the human's delegated AI only (`CEU3AI +0x2C` clear), the areas of the other objectives that border R make **list A**.
3. **Front provinces.** For each p of `CAIUnit +0xC0`, the front-worthy land beside the ops area (`FINDINGS-opsarea.md`), with a real area:
   - **Is p a front of R?** Yes when an edge not of kind 3 reaches a simulated province of R with MaxInfrastructure >= 200. A NAP with p's controller younger than `NAP_UNBREAKABLE_MONTHS x 2 / 3` whole calendar months undoes it.
   - **Is p counted?** fw = `IsFrontWorthyEnemy(ctrl)` (`0x4A9390`), wc = `IsWarCandidate(ctrl)` (`0x4A9A30`). p counts when fw. If also !wc and ctrl's `GetSurrenderProgress / 1000.0 > 0.1`, it is **halved**, and a halved province does not set anyFront. When !fw, p counts only if its area is on list A.
   - **Weight.** relaxed and no NAP: wc ? 1000 : 500. Otherwise: wc ? 2000 : 1000. Halved: / 2.
   - **Floor.** MaxInfrastructure(p) <= 300, or halved: 500. Otherwise 1000.
   - **Hostile units.** Land units whose owner is id 0 or REB, or is not `IsSameSide` and either is not a co-belligerent (`CDiplomacyStatus +0x58`) or `IsEnemyTag`. **At peace that is every foreign unit not on our side, headquarters included.** n of them; P = sum of `CUnit::GetPower`.
   - **Score and power.** score = `max(floor, floorf((n + 0.0005f) x 1000) x weight / 1000)` = `max(floor, n x weight)`; power = `P x weight / 1000`.
   - **Faction-leader bonus.** If p lies in its controller's acting-capital area and the controller is the first member of its faction (member count > 0): score += weight; power += power x weight / 1000.
   - **Cap near our capital.** If score > 1000, and C's capital area is real, is not R, and borders p's area: power = power x 1000 / score; score = 1000.
   - **Accumulate.** `*theirPowerOut += power`; weightSum += score; p's area joins **list B**.
4. **Bf and Pf.** Bf = the land brigades (`+0x40`) of each B area's controller standing in that area. Pf = the provinces of the B areas.
5. **N1** = `fistp(float(weightSum) / 1000.0)`: round half to even (VA `0x8B8F26`-`0x8B8F49`).
6. **N2**, only when R's first province is C's (otherwise 0). F = sum of `CAIUnit_ProvinceHoldValue(p, agent, false)` over `CTheatre +0x60` provinces in R (with no theatre, over the plan's ops area). N2 = `trunc(F / min(R.provinces, 40))`, at most `R.provinces / 4` (raised to 1 only when !relaxed); if R has no neighbouring area (`+0x3C = 0`) and is not C's capital area, N2 > 1 with under 3 provinces -> 1, N2 > 2 with under 15 -> 2; otherwise N2 = 0 and F > 2.0 -> 1.
7. **need = objCount + (anyFront && N2 > N1 ? N2 : N1).**
8. **Focus recursion.** If R's region group (`+0x6C`) holds more than one province, each focus area (`+0x338`) of the same group not yet on `visited` goes on it, and need += `EstimateAreaNeed(it, ...)`. This comes **before** steps 9-14, so the parent's adjustments apply to the children's sum too.
9. R is C's, is not C's capital area, `COwnerArea_TouchesHostileArea(R)` (`0x7FD90`), and Pf > 3: **need += 4**.
10. C has more than one theatre (`+0x578`) and need > 2 x Bf: need = `max(need / 2, 2 x Bf)`, at least 1.
11. **Capital floor.** R is C's capital area and C `is_major` or `max_ic > 100`: need = `max(need, relaxed ? max(sum of port naval level_max / 1000 / 4, ports / 2) : 3 x ports)`.
12. need >= 1.
13. R is not C's and not C's subject's: if need > 1, need = `max(need / 2, 1)`.
14. C is ITA and province 9943 (Addis Abeba) is in R, or 9943's area borders R while its controller is an Italian subject: **need /= 3**, with no floor after it.

**To compute it from a save**: areas are flood-filled per controller over infrastructure > 1 level (`FINDINGS-supplynetwork.md` section 2); `+0xC0` comes from the plan's `ops_area` and the country's front-worthy set; units, locations, brigades, buildings, VP, factions (first member) and capitals are all in the save; `GetPower` as in C.5.

### C.3 `CAIUnit_ProvinceHoldValue` (`0x4B9710`, `ret 8`, float in XMM0)

The province arrives in ECX; the agent and the flag on the stack. C is the agent's country.

- **0** when MaxInfrastructure < 200.
- **near**: the first edge (not kind 3) to a simulated land province whose controller K is not `C.IsFriend(K, true)` and either has K's threat towards C (+ C's antagonism of K when C is at peace, runs_units is set and the flag is clear) >= 100.0, or is front-worthy to C.
- **full**: 1, except for USA at war while ENG owns provinces and is not in exile, and USA's lost core VP (`+0xBE0 - +0xBE4`) is under 2000.
- **Forts and bases**: v = near ? 3 x fort level : 0; full and a coastal fort cf > 0: v += 5(cf + 1); w = full ? air base level_max : 0; full and naval base level n > 0: w += n, or for GER/ITA x = 10n + 30, and above 100 `(x - 100) / 5 + 90`; w x2 when the province is outside its controller's capital area and its area has under 15 provinces; v += w.
- **Victory points**: owned by C -> v += `max(2vp + 5, vp x 100 / (C.victory_points_owned / 1000))` (`CCountry +0xBDC`); only controlled by C, its owner not in exile -> v += 2vp + 5.
- **Capital and resource**: C's acting capital +100; full and a real strategic resource +60.
- **IC and revolt**: x = IC modifier / 1000 x 0.5; r = max(effective revolt risk, max(minimum revolt risk, 0)) / 1000. Flag clear: v += x. Flag set: +100 for the province's own supply depot; v += r x x; full with a naval base and a naval station: v += 30 + 2 x ships.
- **Objective**: + 0.25 x the priority of the plan's objective on this province.

This is also the second term of `CAIUnit_ScoreHoldProvince` (`0x4B4200`, section D), called there with flag 1.

### C.4 `their_power`

Only ever `EstimateTheatreNeed`'s side-product, for AI and played countries alike (`0x4B5210` posts no powers). **Checked inside save windows**: **Kwantung Army Theater, 13812** at both `01_08_03` and `01_08_06` - it needs the Manchukuo focus areas' recursion and the x1.5 on Soviet units (their area is Moscow's, and SOV leads the Comintern); **Paris HQ, 92** - Belgian and Luxembourg units at weight 500, the Luxembourg theatre HQ unit counting; **Bordeaux HQ, 2988**. Ethiopia's 11359 lies between the two ends of its window (moving war units). Over `01_01_00` -> `01_04_12`, with the front-worthy set approximated as the enemies of the fronts the ops area touches, 72 of 106 plans equal one end and 10 more lie between the ends; most of the rest are theatres given an area by the second chance, whose enemies are not front-worthy (true answer 0), or theatres needing focus areas the scan does not model.

### C.5 `our_power`: France's 0.5%

`CSubUnitDefinition::Add` counts toughness twice (`FINDINGS-unitdef.md`): every technology level's toughness effect enters the regiment's own definition twice, the unit file's base toughness once. With that, `SumOurPower` gives **Paris 15017 and Bordeaux 17167, the figures posted between `01_08_06` and `01_08_07`, exactly**; the plain sum gave 14946 and 17106. No other post in the hour-apart windows changes.

### C.6 The first post under 1.000

Before an agent's first pass its theatre plan is inactive. `CUnit::UpdateDaily` (`0x1BB326`) calls `UpdatePlanForceNeeds` with a null fifth argument for every `oob_level`-0 unit; on an inactive plan that arm writes the plan's own `min`, `our_power` and `their_power` directly, with no command (`0x1BD498`-`0x1BD4C4`), from `ComputePlanWantedSubUnits`: our = the sum over the whole order of battle, headquarters brigades included, of (strength / max) x (organisation / max) x combat value; their = the raw combat value of the unfriendly regiments beside the plan's area. The theatre's HQ brigade alone (1.33) makes that our_power >= 1, so the first `UpdatePlanPower` (`0x4B5060`) sees a different whole number and posts the small `SumOurPower`. The writer is confirmed on the listing; that this is what let 46 sub-1 figures through is **inferred**.

### C.7 Against the saves: the Soviet Union

Needs on `01_01_00` (ops areas from `01_04_12`): Arkhangelsk, Leningrad, Smolensk, STAVKA, Brjansk, Kyiv, Odessa, Stalingrad 18 each; Far East >= 20 (two one-province island areas at 1 each, plus Mongolia and Tannu Tuva if they are focus areas). Every European 18 is the capital floor; N1 runs 0-10 and N2 1-9, almost no foreign units standing on the border. The balancing (`FINDINGS-agents.md` F.1) with these needs: **exact** - Kyiv -> Arkhangelsk 5, Odessa -> Arkhangelsk 6, Arkhangelsk -> Leningrad 4; **one too many** - Odessa -> Leningrad (save 5, model 6) and Odessa -> Brjansk (save 4, model 5). The end state is the save's to within one or two divisions, and stable from the second pass, as observed (no Soviet moves `01_04_12` -> `04_20_03`).

### C.8 Corrections to the record

| record | read |
| --- | --- |
| `EstimateAreaNeed`: score = enemyCount x weight / 1000 | `max(floor, n x weight)` (built as `floorf((n + 0.0005) x 1000) x weight / 1000`) |
| need = weightSum / min(provinces, 40), capped at provinces / 4 | N1 = `fistp(weightSum / 1000)`, undivided; the /40 and /4 belong to N2, the float sum of province values |
| "a country-database comparison" -> 0 | C is ITA and R is held by ETH |
| "halved when a relation test passes" | front-worthy, not a war candidate, surrender progress > 10%; such a province sets no anyFront |
| `if need == 0 && weightSum > 2.0` | F (province values) > 2.0, on N2 |
| "the faction test at the capital", "three capital-adjacency gates" | the controller's capital area and faction leader (x1.5 at weight 500); the cap at our capital's border |
| `FINDINGS-agents.md` D.4: France 0.5% not explained | toughness of technology effects counted twice |
| D.7: sub-1 first post | `UpdateDaily` writes an inactive plan's powers directly |
| `CANDIDATES.md`: `0x508C30` | a VA: rva `0x108C30`, `CCountry::UpdateLendLeaseRoutes`, already recorded |

### What looks wrong but is what the bytes do

1. The weight sum is never divided by the area's size, so a long front adds a division per province.
2. The capital floor depends on **naval bases**: the Soviet Union's landlocked theatres each need 18 because its one area holds 17 ports with 73 levels.
3. Only the larger of N1 and N2 counts, and N2 only where a live front exists; a quiet area of ours ignores its own provinces' worth and needs 1.
4. A province facing two of our areas, or an area and a focus area, adds its power twice.
5. The halving against 2 x enemy brigades can **raise** the need to 2 x Bf.
6. Italy's need for Ethiopian-held land is 0 before the war, and the Addis Abeba area's need is divided by 3 with no floor, so it can reach 0.
7. The US AI stops valuing coastal forts, air and naval bases and resources while Britain stands and US core VP is (almost) intact.
8. With flag 1 the province value multiplies IC by revolt risk.
9. Headquarters units count among the hostile units and their power.
10. An inactive plan's powers come from a different formula than an active one's, and that is what lets the first post through the gate.

### What could not be settled

- The two off-by-one Soviet transfers: a need cannot fix them (the floor makes every European need equal, and the two would need Odessa ~22 and Brjansk 19-20 at once); more likely `0x4BF8E0`'s pick returns fewer than asked - the balancing's (`FINDINGS-agents.md` F.2).
- The exact front-worthy sets per country (approximated in the scan; `IsFrontWorthyEnemy` not run pair by pair).
- The focus areas exactly (approximated as same-side areas in the group, not via `TheatreBordersAreaMost`).
- That the faction's "leader" is its first member: the Comintern case (SOV) confirmed by Kwantung, the general case inferred.
- `ComputePlanWantedSubUnits`' ownStrength formula is from the decompiler.
- No save isolates the province value N2.

### Frontier

Nothing unnamed is left. `0x4A4DC0`/`0x4A4E00` are luabind's `CAIStrategy::GetThreat`/`GetAntagonism`; `0x1D5CC0` is `CUnitList::GetTotalNumOfShips`. For the balancing: `0x4BF8E0`'s count of picks against n (the Soviet off-by-ones).

### The tables (C)

Functions: `0x4B82F0` `CAIUnit::EstimateAreaNeed` revised confirmed (rewritten whole); `0x4B9610` `CAIUnit::EstimateTheatreNeed` revised (comment); `0x4B9710` `CAIUnit_ProvinceHoldValue` new confirmed; `0x4B5060` `CAIUnit::UpdatePlanPower` revised (comment). Fields: `COwnerArea +0x38` `neighbour_areas_last` new; `CCountry +0xBDC` `victory_points_owned` new.

## D. Fleets and aircraft to their targets

*Read 2026-10-19 on the listing. Addresses are rvas unless marked VA.*

**In short.** **The AI's sea targeting uses no sighting, intelligence or detection at all.** `CAIUnit +0x25C` holds every naval unit of every enemy, undeclared-war opponent and strategy war target, assigned to the nearest agent; `+0x26C` is **not** "sightings lost" - it holds the country's own fleets and its co-belligerents'. That explains why naval-bomber wants are negative at peace (all nine non-zero ones in `_01_04_12` are -1 to -4). **Corrections**: those two fields; `BuildAirTargetProvinceLists` rebuilds the four lists at **every daily full pass**, not "once per agent", and its candidate countries are the Overlord and the Vassals, not the faction leader; `CountSightedEnemyShips` is renamed `CountAssignedEnemyShips`; and the convoy-raid block has a second, unreported rebase - when fewer than half the route provinces seen are raid candidates, the submarine fleet relocates to the port with the most raidable tonnage instead of raiding. The hold-province score's second helper (`0x4B9710`) is not read.

**In one paragraph.** Once a day, at hour `id % 24`, every country's AI hands its unit agents their sea targets (D.1): each enemy convoy to the agent whose ports best cover its route (the submarine want); each enemy fleet to the nearest agent, weighted by load; each enemy war-industry province in the enemy's capital area to the agent whose air bases are nearest; each sea province where one of our convoys was raided in the last month to every agent whose ports can reach it; and each fleet of our own and our co-belligerents to the nearest agent. "Enemy" means at war, in an undeclared war, **or a war target of the strategy**; no sighting or intelligence is asked. The theatre agent's naval body (D.2) then sends idle fleets home, repairs and splits fleets, cancels orders that no longer make sense, measures enemy and own naval power near its ports, has submarines raid convoys or move to better hunting ports and spreads surface fleets over its ports, sends screen fleets to patrol around raided waters or its own ports, and answers enemy fleets at sea with an intercept plus join_fleet group of at least twice the enemy's power. The air body (D.3) is as already read, with one link added: its anti-shipping wings are rationed by how many of our provinces an enemy force at sea is heading for.

**Exe-hardcoded**: sea distances 3000 (convoys), 2000 (fleets, raided sites, friendly fleets) and 1000 (the survey); map distance 800 (air bases); divide by 20, x0.2 for the theatre holding our capital's area, weight 2.0 for a province with a strategic resource, the "one working level of industry or 1 crude oil" bar, the one-month raid memory; intercept power factor 1.5 (2.0 at naval stance 1), 0.66 for a troop carrier, gather to 2x need; patrol's 168-hour window, five-province area, CRT `rand()`; the hold score's 4000, 100, 0.1, 200, /20 and the tags FRA, BEL, LUX, GER; the Allies found as ENG's faction; the anti-shipping budget 4x. **Mod-able**: the four strait blockers (`defines.lua` map: `GIBRALTAR_BLOCKER`, `SUEZ_BLOCKER`, `BLACKSEA_BLOCKER`, `BALTIC_BLOCKER`); `map/region.txt`'s `mediterranean_region`, `black_sea_region`, `baltic_sea_region`; naval base, air base and industry levels; strategic resources; a convoy's desired transports (`CONVOY_PATH_LENGTH_MULT`, `CONVOY_TRADE_WEIGHT_MULT`); the unit files' `is_buildable`, `is_cag`, `carrier_size`, `is_sub`, `capital`, `transport`, `transport_capability`; the AI strategy's figures (threat, antagonism, `defend_prov`), computed rather than authored.

### D.1 `CEU3AI_AssignSeaTargetsToAgents` (`0x48C140`, read whole)

**When.** Called by `ProcessAI` (`0x4899B9`) at hour `id % 24`, for every country with a `CEU3AI` - before the played/AI split, so the played country runs it too.

1. **The enemy list.** `enemies` (`+0x1008`), then `undeclared_war_opponents` (`+0x1018`), then every strategy war target (`CCountry +0x5D4`) not already listed.
2. **Clearing.** Every agent: `+0xD8 = 0`; the lists `+0x24C`, `+0x25C`, `+0x26C` and `+0x284` freed; the vector `+0x18C` emptied. An agent's theatre is its root's area id (`+0x68/+0x6C`) resolved.
3. **For each listed country in the scenario (`+0x44`):**
   - **Convoys** (`+0xA0`). c = `GetDesiredTransports`. For each agent whose theatre has ports, sum over every (route province, theatre port) pair with sea distance under 3000: sumBase += the port's naval base `level_max`/1000; sumDist += that distance. Every agent with sumBase >= 1 gets the convoy on `+0x24C`. Score = `max((want + c)/20/sumBase, 1) x sumDist/portCount`, want being the agent's `+0xD8` so far. The strictly lowest score (from 1e7, first of equals in agent order) gets `+0xD8 += c`.
   - **Naval units** (slot 16, IsNaval), with no test of visibility. For each agent, over its ports within sea distance 2000 of the fleet: sumDist, sumBase and n, requiring sumBase >= 1. Score = `max((CountAssignedEnemyShips + the fleet's ships)/sumBase, 1) x sumDist/n`, x0.2 when our acting capital's area is a real area on the theatre's area list (`+0x84`). The lowest score gets the fleet on `+0x25C`.
   - **War industry.** A province qualifies when it lies in the enemy's acting capital's area, its owner controls it, it is hostile to us (IsEnemy inlined, undeclared war included), and it works at least one level of industry (`+0x24` >= 1000) or produces at least 1 crude oil. Weight = 2 with a real strategic resource, else 1. Per agent, over every air base of the theatre's areas within map distance 800: sumBase += working level/1000, sumDist += d, requiring sumBase >= 1. Score = sumDist/sumBase/weight; the lowest pushes the province onto `+0x18C`.
4. **Raided convoys.** The finished-battle list (game state `+0xB80`, walked through `+0x28`). An entry qualifies when it is naval, a convoy battle (`+0x20`), its defender is real, not REB and on our side (IsSameSide, or co-belligerent and not an enemy), and its end tick plus one month is not before now. Every agent with a port within sea distance 2000 and `CCountry_IsSeaRouteOpen(us, port, province, false)` gets the province on `+0x284` (`CAIUnit_AddConvoyRaidProvince`, `0x487FC0`), once per agent.
5. **Friendly fleets.** Every naval unit of `non_hostile_countries` (`+0xF98`: us and co-belligerents) goes to the agent with the lowest mean port distance (x0.2 for the capital's theatre, no load term), onto `+0x26C`.
6. **Finish.** Every agent's `+0xD8 /= 20`, truncated.

**Downstream.** The force planners subtract `+0x26C`'s ships from the naval-bomber and surface wants (`FINDINGS-agents.md` E.7), so **a theatre's own fleets cancel the enemy's**, and at peace the want is <= 0. The saves bear this out: the nine non-zero naval-bomber wants in `_01_04_12` (ENG Home and Middle East, USA East and West, JAP, FRA x2, ITA Metropolitana, ARG) are all negative - a sign check, not a figure check. F.9's question "what fills `+0x25C` at peace" is answered: the fleets of the strategy's war targets; with an empty war-target list it is empty.

### D.2 `CAIUnit_ManageNavalUnits` (`0x4D0880`), the phases not read before

**Order of phases**: (1) withdraw from a losing sea battle (section B's slot 17); (2) idle fleets home (`0x4D0B30`); (3) port and repair (`FINDINGS-agents.md` C.3); (4) existing orders (`0x4D14F0`); (5) split and merge (C.3); (6) survey (`0x4D2025`); (7) convoy, rebase and tail (`0x4D2418`); (8) patrol (`0x4D323D`); (9) intercept (`0x4D37EA`).

**Idle fleets home (phase 2).** A fleet that is not moving, has no busy order (slot 24) and is not at its own base is `MoveUnit`-ed to its base when `CanUnitReach` - except that a fleet whose definition carries troops (`transport_capability` >= 1000) stays in port while the plan has an embark (`CUnit +0x284`), and a fleet with no base, or an unreachable one, goes on a "homeless" vector instead.

**Existing orders (phase 4)**, per ready fleet: *idle, no destination (`+0x2CC`), in a port that is not its base* - moved home, unless it holds a transport and lies in the embark port; *join_fleet* - the mover and its target go on a "handled" list, and the per-port arrival tally moves; *a busy transport fleet carrying nothing* - cancelled unless `CUnit +0x2CA` is set (its only setter is `0x4D4070`); *convoy_raid or convoy_escort at peace* - cancelled, and an escort whose target is gone is also cancelled; *patrol* - kept only at war; *anything else* - kept while the fleet has a destination, cancelled at its own base, and an intercept with no destination away from base is cancelled. "Cancel" means `IssueUnitOrder(none)` then `MoveUnit` to the base, or to where the fleet is.

**Survey (phase 6).** The handled fleets are swap-removed from the ready vector (`Vector_SwapRemoveValue`, `0x4DCDA0`), which reorders it. `+0x27C = +0x280 = 0`. Every naval unit of a country at war or in undeclared war with us (war targets do not count here) that lies within sea distance 1000 of a theatre port and is hostile where it stands adds `GetPower/1000` to `+0x27C` (`enemy_naval_power_near`), and goes on a list, troop carriers first. The ship census taken here is overwritten and never read; the +100 bonus for carriers aimed at our coast is dead code.

**Convoy block (phase 7), additions to `FINDINGS-airnaval4.md`.** A route province is "seen" when it is not an endpoint, not `0x2927..0x292A`, not Baltic-barred, and not already a candidate; it becomes a candidate when `COrder::IsTargetInRange` holds (range measured from the fleet's **base**) and, where the convoy's owner is an undeclared-war opponent, the undeclared war covers the province. **When there are no candidates, or fewer than half the seen count, the submarine fleet does not raid; it relocates** (VA `0x8D28B3`-`0x8D2AE7`): over the per-port raidable-tonnage map, score = tonnage x 10, -20 per berth over capacity, x1.5 for its own base; the strictly highest score above 0 that is reachable wins, and if it is not the current base the fleet gets `rebase`. The surface rebase is forced, skipping the submarine and crowding tests, for a homeless fleet or one whose base lies outside the agent's theatre. The tail skips any fleet holding a transport.

**Patrol (phase 8).** *Gate*: naval stance != 0, and at war, in an undeclared war, or `+0x28C > 0`. *The region V*: the `+0x284` provinces, or, when there are none, the sea zone (`+0xA4`) of each theatre port; anything `CAIUnit_IsBalticBarredToAllies` (`0x4D0520`) refuses is left out of both. *Loop, while V is not empty*: centre = `V[rand() % |V|]`, the C runtime's per-thread `rand`; the area = the centre plus the nearest remaining V entries to the centre, up to five provinces, each swap-removed from V; the fleet = the nearest free fleet (strict, first of equals) with no busy order, no submarine and at least one screen; order `patrol` from now to now + 168 h over the area, and the fleet leaves the free vector. No qualifying fleet ends the phase.

**Intercept (phase 9)**, per surveyed enemy fleet that is at sea and not Baltic-barred: skip it when `+0x27C > +0x280 x 1.5` (2.0 at naval stance 1), unless it carries troops. need = its `GetPower/1000`; target = need, or need x 0.66 for a troop carrier. While 2 x need > gathered, add the nearest free fleet that is reachable, has non-zero power, is not on patrol (unless the enemy carries troops), and has a screen when the enemy is all submarines. If gathered >= target, the first fleet gets `intercept` on the enemy and the rest `join_fleet` onto the first, all with window now -> now; `+0x280` and need are reduced by each fleet, stopping once need < 0.

**Against the saves.** Saves keep no orders. In `_01_04_12` to `_01_08_07` Italy's surface fleets (screens, no submarines) are at sea on paths of one or two provinces next to their bases, while every submarine flotilla sits in port - consistent with the patrol rule, not a check. In `_04_20_03` they are all in port, which this does not explain.

### D.3 `CAIUnit_ManageAirUnits` (`0x4CD890`) and the air target lists

- **Phases** 1-4 are as `FINDINGS-reorganise.md` and `FINDINGS-airnaval4.md` give them.
- **Anti-shipping budget.** Phase 4's naval-strike budget `+0x1E4 x 4` is `threatened_provinces_count` - so a tactical or CAS wing with sea attack flies naval strikes only while an enemy force at sea is heading for our coast.
- **Phase 2 (rebase), as read.** The running best starts as the current base with score 1e6, so the lowest-scoring listed base wins outright and the current base is never scored. A province with enemy land units marching in is skipped. Score = (list score + distance to the agent's HQ) x 0.5 when the group's parent is not a theatre; without a transport plane, x load when load > 1, using the air base's **working** level. Ties go to list order, which is ascending score.
- **`InsertUnitByRange`.** The air list `+0xFC` is kept **ascending by range**; a new unit goes after existing equals. So a merging group takes the shortest-range compatible partner, and among equals the earliest in the country's unit-list walk.
- **`CAIUnit::BuildAirTargetProvinceLists` (`0x4B4740`).** Its caller passes the tick's full-pass flag, so the four lists are rebuilt every day at `(id+6) % 24`, and hourly while `+0x84` is set. Candidates are our AirBases (`CCountry +0xD70`), our Overlord's (when we are a subject) and our Vassals'. The province base's slot 1 (IsCarrier) is always false, so it never refuses. The naval list scores bases against the provinces of the enemy fleets assigned to us (`+0x19C`, from `+0x25C`).

### D.4 The leftovers

- **`CCountry_IsSeaRouteOpen` (`0xD52A0`), its war branch.** True at peace. At war, a land `from`/`to` is replaced by its sea zone, and the route is open unless `SeaRouteCrossesClosedStrait` (`0xD5190`): crossing into or out of the Mediterranean + Black Sea is closed only when **both** the Gibraltar and Suez blockers are held by enemies; crossing into or out of the Black Sea is closed when its blocker is enemy-held; Panama and the Baltic are never asked. With `alsoNeighbours`, any adjacent sea zone of a land `to` that is reachable opens the route. Fleet-to-port passes false.
- **`CUnit_CanTakeSubUnit` (`0xE1010`) - is a transfer refused?** Yes; besides the receiver fighting, it refuses when the sub-unit is not buildable (`is_buildable = no`: HQ and partisan brigades); the kinds differ (land, air, naval); CAG rules fail (an all-CAG unit takes only CAGs, a carrier must have room, CAG and non-CAG units do not mix); the sub-unit is a command's HQ brigade; either unit is on loan; the source unit is fighting; the two stand in different provinces (`CTransferSubUnitCommand` passes 1); a land division is already at its maximum brigades. The AI's own splits pass all of these.
- **`CAIUnit_ScoreHoldProvince` (`0x4B4200`).** (1) 0 when the province's infrastructure is below 200. (2) 0 outright when a non-VP, non-depot province borders a war candidate. (3) France gets 4000 per neighbour province held by Belgium or Luxembourg, and Belgium per one held by Luxembourg, when Germany has provinces, is in another faction and is at peace with the holder there. (4) Otherwise, for each non-friend holder: t = the **holder's** threat towards us, plus our antagonism towards it when at peace and the AI runs the units; if t >= 100 and the holder's surrender progress is below 0.1, t is added and the neighbour counted. (5) Score = mean/20 + count, + `0x4B9710(province)`, + 200 on the threatened list, + the province holder's `defend_prov` weight.

### What looks wrong but is what the bytes do

1. "Sighted" enemy fleets are every enemy fleet, war targets at peace included; friendly fleets reduce the wants, so peace gives negative naval-bomber figures.
2. A convoy goes on `+0x24C` of every agent that covers it, but adds to only one agent's submarine want; the convoy score divides summed pair-distances by the theatre's whole port count.
3. Patrol picks its centre with the C runtime's per-thread `rand()`, not the game's MT19937; the result depends on which worker thread ran the country.
4. Swap-removal reorders the ready, free and patrol vectors, so "first of equals" later depends on earlier removals.
5. The submarine relocation iterates a pointer-keyed hash map; ties go to address order.
6. In the enemy survey the troop carrier's +100 is computed and never used, and the role census is overwritten per fleet and never read.
7. The Baltic ban applies only to AI-run members of ENG's faction, and lifts when any Allied major holds the Baltic blocker.
8. Closing the Mediterranean needs both Gibraltar and Suez closed.
9. `0x4B4200` reads the neighbour's threat **towards us**, not ours towards it.
10. Air phase 2 never scores the current base, so a group always moves to the lowest listed base below 1e6.
11. Phase 2 divides by the air base's working level, so a bombed base looks crowded.

### What could not be settled

- `0x4B9710`, the second term of the hold score (reads victory points, air base, naval base and the capital's area).
- What sets `CUnit +0x2CA` (`0x4D4070` writes 1; unread), the flag that saves an empty busy transport fleet's order.
- Why every Italian surface fleet is in port in `_04_20_03` (perhaps resting below 0.9 organisation; not computed).
- The four hard-coded province ids `0x2927`-`0x292A`.
- Which transport-list gate in `BuildAirTargetProvinceLists` is the sense error.
- `0x4F8AB0` taken as IsMajor (the decompiler's name, not read).
- Whether `CUnit +0xC8`'s `transport_capability` in phase 2 is the fleet's summed or first definition.

### Frontier

`0x4B9710` (hold-score term; slot 80's owner); `0x4D4070` (sets `CUnit +0x2CA`; called from `0x4C7104` and slot 69 `0x4D5652`); `0xA69E0` (neighbour-controlled-by-tag test, feeds only the dead +100); `0x4F8AB0` (IsMajor?); `0xD5760` `AreaPair_SeaRouteOpen` (section F; consistent with `0xD52A0` as read here); `0x5147D0` and `0x4DD980` (stdext hash_map node insert and rehash behind `AIOrderedMap_Subscript`, deciding the relocation's tie order).

### The tables (D)

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| `0x48C140` | `CEU3AI_AssignSeaTargetsToAgents` | revised | confirmed | read whole; `+0x26C` friendly fleets, `+0x284` raided-convoy sites, no detection |
| `0x487FC0` | `CAIUnit_AddConvoyRaidProvince` | new | confirmed | push-back onto `+0x284` |
| `0x4B96A0` | `CAIUnit_CountAssignedEnemyShips` | revised | confirmed | renamed from `CountSightedEnemyShips` |
| `0x4D0880` | `CAIUnit_ManageNavalUnits` | revised | inferred | was `likely`; the six mapped phases read |
| `0x4CD890` | `CAIUnit_ManageAirUnits` | revised | inferred | was `likely`; anti-shipping budget, phase 2, the hinge |
| `0x4B4740` | `CAIUnit::BuildAirTargetProvinceLists` | revised | confirmed | rebuilt every daily full pass; Overlord and Vassals |
| `0xD52A0` | `CCountry_IsSeaRouteOpen` | new | confirmed | the fleet route test |
| `0xD5190` | `SeaRouteCrossesClosedStrait` | new | confirmed | Gibraltar+Suez, Black Sea |
| `0xE1010` | `CUnit_CanTakeSubUnit` | new | confirmed | transfer refusal test |
| `0x4B4200` | `CAIUnit_ScoreHoldProvince` | new | inferred | slot 80's province score; `0x4B9710` unread |
| `0x4D0520` | `CAIUnit_IsBalticBarredToAllies` | new | confirmed | Allied AI out of the Baltic unless an Allied major holds `BALTIC_BLOCKER` |
| `0x4DCDA0` | `Vector_SwapRemoveValue` | new | confirmed | swap-with-last removal |

Fields: `CAIUnit +0xD8` `submarine_want` revised (comment); `+0x24C` `known_enemy_convoys` revised (comment); `+0x25C` `enemy_fleets_assigned_first` revised (renamed from `enemy_units_sighted_first`); `+0x26C` `friendly_fleets_assigned_first` revised (renamed from `enemy_units_lost_first`); `+0x18C` `strategic_target_provinces_first` revised (comment); `+0x27C` `enemy_naval_power_near` new; `+0x280` `own_naval_power` new; `+0x284`/`+0x288`/`+0x28C` `convoy_raid_provinces_first/last/count` new; `+0x83` `air_target_lists_built` revised (comment); `+0x1E4` `threatened_provinces_count` revised (comment).

## E. Invasions

*Read 2026-10-19, every function on the annotated listing, the decompiler used only as a map. Addresses are rvas unless marked VA. `CEU3AI::PickInvasionLandingProvince` (`0x493E70`, `FINDINGS-invasion.md`) is cited, not redone.*

**In short.** The whole invasion path, the `CEU3AI` planners and `CAIInvasion`'s hourly tick, is read on the listing, and every function is raised to `confirmed`. **Three corrections change what an invasion does**: stage 2 (`0x4A0610`) loads no troops - it sends up to three of the fleet's **carrier air groups** on `ground_attack` over the beach until sunset, so the `LoadTransportsAtNight` name and `FINDINGS-theatre2.md`'s "load in daylight" were both wrong, loading being a `CLoadArmyCommand` posted in stage 3; the planner's "amphibious test" (`AreaIsConnectedTo` at `0x492B9E`) is dead, asked of `g_null_owner_area`, whose slot 0 always answers false - what keeps the AI off land it can walk to is `RankInvasionAreas` failing any area touching our own coastal land, and `IsInvasionOver`/stage 1 dropping units that can march to the objective; and `0x1D66D0` sums `transport_capability`, not weight, so every lift test in this chain had been read as weight. Five smaller corrections: `CEU3AI +0xD8` (the weak enemy ports) is read by `0x4CC690`, the paradrop planner (section A), not by the invasion planner; `PickEmbarkationPort`'s score is multiplied by the distance; `AddUnit` answers **false** for a duplicate; `CAIUnit +0x370` counts land units, not brigades; `COwnerArea +0x3C` is the neighbour-area count, confirmed off its writer.

**In one paragraph.** An AI country thinks about invading once a day, at hour `id % 24`, and only if its whole fleet can lift four infantry brigades. **Ranking**: it ranks the coastal areas of the countries it is at war with, and any friendly or own area that needs reinforcing by sea; areas touching its own coast, areas it cannot reach by sea and Axis heartlands the Allies may not yet touch go on a failed list for the rest of the month; the ten best are kept. **Planning**: for each ranked area in turn, until it has two invasions (Japan eight, the USA four), it sizes a force from the enemy land units there, picks a landing port with `PickInvasionLandingProvince`, chooses spare, fit divisions nearest by sea up to what the landing port can supply, then transport and escort fleets, and creates a `CAIInvasion` agent holding them. **The agent's hour**: it picks a friendly embarkation port near the objective, marches the divisions there and moves the empty fleets there to merge, loads the troops (`CLoadArmyCommand`), sails to the port, re-picks the landing province, and gives the fleet an `invasion` order on it, flying the fleet's carrier air groups over the beach while there is daylight. **The end**: when its fleet or troops are gone, when every division can walk to the objective (once ashore), when it cannot lift its smallest division, when the troops in position are too weak, when no landing remains in the area, or when the area drops out of the ranking.

**Exe-hardcoded**: the caps 2 / USA 4 / JAP 8; the lift gate of 4 x infantry weight; the readiness floors 0.8 organisation and 0.75 strength (fleets and divisions), 0.5 / 0.33 (carrier air) and 0.33 (in position); force caps of 5 and 20, x3 against a major's capital, the supply margin of 2000, the port-sharing radius 160000 (distance squared), the escort ratio 0.5, the +500 distance offset and the fleet weights x100 / /3 / /2; the ranking's 10-area cut and 1/10 cut; every ranking score - 100001, -99, 10/50/1, 900, 200, 600, 100, 120, 8, 40, 30, 5, the 60 and 20 province counts, the ranges 5000/2000, Soviet weakness at 300 surrender progress or 90 manpower, 500/10500, 40/25 and x2; PickEmbarkationPort's 1000/2000, 1.5, 10, 0.3, 0.75, 1/2/4, x3 and <= 5 units; stage 3's 4 provinces and 10 units per province, stage 2's 3 hours and 3 air groups; the tags GER, ENG, NZL/CAN/SAF/AST, USA, JAP, SOV, HOL, PHI, POL, DEN, NOR/SWE/FIN, ROM/BUL/YUG; the provinces 2613 Paris, 2137 Brugge, 1910 Amsterdam, 1964 London and 812 Oslo; the years 1942, 1943 and 1944; the faction key `"allies"`. **Mod-able**: unit types - `infantry_brigade`'s weight (the lift reference), `transport_ship`'s `transport_capability` and every unit's `transport_weight`; the `carrier`, `battleship` and `submarine` keys; `assault_ship` and its technology; naval and air base levels, `NAVAL_BASE_EFFICIENCY` (through `NavalBaseCapacity`), victory points, strategic resources and supply consumption; the map defines `GIBRALTAR_BLOCKER` (5191) and `SUEZ_BLOCKER` (5612), and `map/region.txt` (the Baltic and Black Sea ban inside `PickInvasionLandingProvince`); which faction is keyed `allies`. Nothing in the chain reads `defines.lua` but `NavalBaseCapacity` and the two map defines; no Lua is involved.

### E.1 When it runs

- **Every hour, for every country**: `ProcessAI` ticks every invasion agent (`+0x50`) through slot 9 -> slot 10 (`CAIInvasion::Tick`, `0x49FB10`): return if finished (`+0x3E`); finished = `IsInvasionOver`; if not, `DoTick` (slot 73).
- **Every hour, before the branch**: `CEU3AI_PruneInvasions` builds the list of areas already being invaded (E.6). At hour 1 of each month's 1st the failed list (`+0x94`) is freed.
- **An AI-run country, at hour `id % 24`**: `RankInvasionAreas(ai, null)`, then `RebuildWeakEnemyPorts`, then `GenerateUnitObjectives`, then `PlanAmphibiousInvasion(ai, areasBeingInvaded, null)`.
- **The played country, on even hours**: for each unit agent, `RankInvasionAreas(ai, agent)` then `PlanAmphibiousInvasion(ai, list, agent)` - which return at once unless the agent has a unit. In a new game the played country's agents are never bound (`FINDINGS-agents.md` A.6), so this branch does nothing there; with bound agents it has no cap and can create invasions over the player's own units - *inferred from the gates, not seen.*

### E.2 `CEU3AI_RankInvasionAreas` (`0x495530`) - which areas

The list `CEU3AI +0xC8` is freed, then refilled; nodes `{area, score, distance}`, kept by descending score through `CList_InsertByDescendingIntAt4` (`0x49C240`), an equal score after its equals.

1. **The lift gate.** Nothing more unless `UnitList_SumTransportCapacity(country units +0xBAC) >= 4 x infantry_brigade.weight / 1000`.
2. **Candidate areas.** *An AI country*: every area (`CCountry +0xD30`) of every country in its war list (`+0x1008`) that is in the scenario (`+0x44`), and not landlocked (`+0x68`, i.e. it has a working port) - except that **GER**, when its acting capital's area borders an enemy (`COwnerArea_TouchesHostileArea`), considers only NOR, SWE, FIN and DEN, and when we and the enemy are both in real factions (faction slot 7), FIN is never a target, nor the acting capital area of ROM, BUL or YUG. *With an agent*: the areas of the agent unit's plan objectives (`CUnit +0x234`), each a real area, held by someone else who is a friend or an enemy, not landlocked, and holding none of the agent's front provinces (`+0xC0`).
3. **Reach.** The reach areas are our areas, plus every `non_hostile_countries` country's areas unless our capital's area borders an enemy; the range is 2000 if it does, else 5000 (naval distance / 1000).
4. **Neighbours of each candidate A, held by C.** For each neighbour B that is not landlocked: **B is ours** - A "touches us", and B, unless our capital's area, goes on a list of **staging areas**; **B is held by X != C**, and A is C's acting capital area, X is our friend and at war with C (or REB, or an undeclared war covering B), X is not a played country, X is in our faction where both are in real ones, B is not in our capital's region group, and X is our subject or else we are not JAP and X is not JAP, POL or DEN and nobody else's subject - then A "touches us" and B is a staging area.
5. **Filters on A.** Failed-listed: skip. An AI country's A that touches us: **failed list**. `CEU3AI_MayInvadeArea` false: failed. No port of A able to reach (`0xD52A0`, flag 0) a port q of a reach area within range: failed. A port q in a friend's area counts only where one of our own ports reaches q within range, or q is in ENG's capital area.
6. **Base score f.** 100001 if A holds a priority province (`CEU3AI +0x118`); else, for a small island (port levels summing >= 1, under 5 provinces, no land neighbour), **-99 for GER before 1944**, otherwise 10 x port levels + 51; else, for C's acting capital area, min(provinces, 100) + 1, halved when C is a subject; else 1.
7. **Additions to f.** **+900** when C is GER, the Soviet Union owns provinces and is weak (surrender progress > 300, or manpower < 90), we are major or have max IC > 100, and A is Germany's capital area. **USA against JAP**: +200, and +600 more for a small island - only while the Soviet Union is *not* weak. **JAP**: +600 against a USA small island, +200 against HOL, +100 against PHI.
8. **Province value g.** ENG and USA start g at 120 for each of the `GIBRALTAR_BLOCKER` and `SUEZ_BLOCKER` provinces lying in A; everyone else at 0. Over A's first 60 provinces: +8 x naval base level_max; +40 with victory points; +30 if it currently yields crude oil, metal, energy or rare materials; +40 with a strategic resource; +5 if we own it. g is divided by `n/20` when that is above 1.
9. **The final score.** total = g + f; k = max(round(total / 5), 5); score = total + (AI generator draw % k); then divide by (`COwnerArea_MinPortDistance(A, our capital area)` / 200) when that is positive, and round - `fistp`, to nearest even.
10. **Cut to the 10 best**, dropping the tail.
11. **Staging areas.** Our priority areas held by a same-side or non-hostile non-enemy country are added to the staging list. For each one not failed: `AreaPair_SeaRouteOpen` must hold (at peace it always does), else failed; one of our own needs at least 40 provinces in enemy-held neighbour areas, or 25 when one of those is its holder's capital area; score 500, or 10500 for a priority area, + draw % max(round(s/5), 5), - 5 x provinces, x2 for a capital area; inserted with distance 0. These are the targets of the planner's "friendly" branch: reinforcement by sea.
12. **Final cut.** Entries scoring under (head's score / 10) are dropped from the tail.

### E.3 `CEU3AI_MayInvadeArea` (`0x494CC0`)

1. **True** when the area's first province is ours.
2. **A real-faction member that is not its leader**: false with total IC under 50 while the AI runs its units; false with no transport capability at all.
3. **True** when gamestate `+0xD0C` is set; when the holder is not major (is_major clear and max IC <= 100) or in no real faction; when it is JAP; or when our faction is not the one named `"allies"`.
4. **Otherwise** (an Allied country against a non-Japanese Axis-style major) false for the holder's acting capital area; for ENG also false for Oslo's area (province 812) while GER holds it. It turns true there when `assault_ship` exists, its slot 9 answers true and we may build it, or when some real neighbour of the holder (owning provinces, not in exile, not us) is at war with it.

### E.4 `CEU3AI::PlanAmphibiousInvasion` (`0x492190`)

1. **Gates.** An AI country with more invasions than its cap (2; JAP 8; USA 4) plans nothing, and the area loop stops at the cap; no cap with an agent. While the strategy `IsPreparingWar`: for each neighbour it `IsPreparingWarWith`, return unless we are major and the target is not (non-major with max IC <= 100); also return while now < that WarTargets entry's date + one month. An AI country returns when every ranked area is already being invaded. With an agent, its `+0x36C` and `+0x370` are zeroed.
2. **Candidates**, walking `CCountry +0xBAC` in list order: a unit with `oob_level` != 0, no agent of its own, and a topmost agent up the hierarchy that is a `CAIUnit` (slot 65) - the given agent when there is one. **A division** (level 4) needs at least 2 brigades; not aboard; a real area that is not landlocked, and either our acting capital's area or a region group with no hostile land border (`RegionGroup_BordersEnemy`, `0x80430`); `army_role` not 5 or 8; average organisation share >= 0.8 and average strength share >= 0.75. It is taken when spare > 0 or `army_role` == 7, spare = `CountDivisionsInArea(agent, area, , false)` - (candidates already taken from that area) - need, need = `EstimateAreaNeed(agent, area, , , true)`, halved (toward zero) in the acting capital's area unless that area borders an enemy or `COwnerArea_IsWellPorted` (`0x817E0`); both figures recomputed whenever the area changes from the previous unit's. **A fleet** carrying nothing is a transport candidate. With no division, return. lift = the fleets' capability, computed once and never reduced; ref = 4 x infantry weight.
3. **Over the ranked areas, head first**, stopping at the cap or when lift < ref. **Hardcoded skips**: ENG or a dominion in a year <= 1941 marks the areas of Paris, Brugge and Amsterdam **special**; dominions skip every area before 1942; GER without an agent skips London's area in a year <= 1942. Areas already being invaded are skipped (the AreaIsConnectedTo check here is dead - E.9). **Enemy-held area** (not special): N = max(enemy land units there, 1); skip if N x ref > 2 x lift, or if fewer than N candidates. **Otherwise** (special, or friendly): N = 1 + enemy land units in the neighbouring enemy areas, less 1 for each of our land units with `army_role` != 0 already in the area's region group, for each land unit we lent the area's holder there, and for each role != 0 land unit of our invasions bound for that group; S is the sum of all their supply use; N capped at 5 (special) or 20; skip if N < 1.
4. **Landing.** An enemy area, or one with no port: `PickInvasionLandingProvince(ai, area, 0)`, null skipping the area; capacity = `NavalBaseCapacity(landing)` + over the area's ports q (the landing itself included) with distance^2 < 160000, `floor(((1 - d^2/160000) x cap(q)/1000 + 0.0005) x 1000)`. A friendly area with ports: the port minimising distance(true capital, port) x 3000 / naval level_current (the raw distance at level 0); capacity = the summed capacity of the friendly ports, or the chosen port's own where it is not friendly. N' = N, tripled where the area holds an enemy major's acting capital (not special).
5. **Picking divisions**, one at a time while picked < N' and S <= capacity + 2000: each pick minimises naval distance (first port of its own area -> landing) / 1000, halved for `army_role` 7, doubled for 4, doubled again if it would push the weight past lift (an AI country skips such a unit instead); excluded if already headed into the target's region group, and roles 3 and 5 excluded against an enemy area. S grows by its supply use; the total and the smallest weight are kept.
6. **Needs, enemy area only.** total > lift: the agent's `+0x36C` += (total - lift) / (transport_ship capability / 1000) + 1; if total > 2 x lift, the area is abandoned. Nothing picked, or fewer than N for an enemy area: `+0x370` += N - picked, and nothing is created.
7. **Fleets.** Escort target = 0.5 x total weight; loop while the chosen lift is under the total or the escort power under the target. Every ship of a fleet must have strength share >= 0.75 and organisation share >= 0.8. d = naval distance / 1000 + 500. A fleet with transport ships is a transport candidate (while lift is short); one without is an escort candidate (while power is short): d x100 with a submarine, else /3 with a carrier, else /2 with a battleship. Each round takes the nearest of each kind (first of equals); escort power += `GetPower`/1000 of **both** picks.
8. **Creation.** With >= 1 transport fleet and chosen lift >= the **smallest** picked division's weight, the agent is created and every division, transport and escort added (taken off the candidate lists), then Enable. Each area yields at most one invasion per call.

### E.5 The invasion agent's hour

**`CAIInvasion::IsInvasionOver` (`0x4A12F0`)** answers true - finished for good - when: no fleet, or no land unit; "in position" (one fleet on an `invasion` order, carrying troops, with enemy land units at the order's province) and some land unit fails `CanFight` (slot 33) or is under 0.33 strength or organisation share; every land unit can walk to the objective; the fleets' capability is below the smallest land unit's weight; `MayEnterProvince(us, objective)`, or the same for the rendezvous province `+0x90`, is false; or the lone fleet is on the invasion order, in port or at sea not next to the objective, and has a transport ship under 0.33 strength.

**`DoTick` (`0x49FB40`)** re-picks the embarkation port (`+0x88`) while it is unset or held by a non-friend; none found finishes the invasion; otherwise the three stages run in order.

**`CAIInvasion::PickEmbarkationPort` (`0x49FBC0`)** minimises over our own and non-hostile countries' areas (not the objective's): area weight 1, or 2/4 when the area borders an enemy (2 if it is its holder's capital area); each port P must pass `0xD52A0(us, P, objective, 1)`; d = naval distance to the objective, raised to 1000, refused above the limit (1000 if our capital's area borders an enemy, else 2000); s = (1.5 - level_max/10) x (10 if P is a front province else 1), x 0.3 in our own area, then x 0.75 in our capital's area; score = round(s x areaW x d), x3 when the force (<= 5 units, fully liftable) stands nowhere in that area; a foreign port also needs one of our ports to reach it within the limit. The winner goes to `+0x88`, its id to `+0x90`.

**Stage 1, `MarchLandForceToPort` (`0x4A01F0`).** For each land unit not aboard and on land: **dropped** if it can walk to the objective or is no longer ours; at the port, CArmy `staging_province` = the port; already heading to its staging province, left alone; otherwise, with a land route, `MoveUnit(unit, port, 0, safe, very safe, invasion)`; without one, it marches to the port of its own area - failing that, of a friend's neighbouring area - nearest by sea to the embarkation port, and `+0x90` switches to that rendezvous.

**Stage 2, `SendCarrierAirSupport` (`0x4A0610`).** Only with one fleet on an `invasion` order, an enemy-held objective with enemy land units in it, and at least 3 hours of daylight left. Up to 3 times, it takes the carrier air unit with the largest strength + organisation, in the fleet's province, idle, with organisation >= 0.5 and strength >= 0.33, and gives it `ground_attack` (`0x6FB`) on the objective, now until sunset.

**Stage 3, `SailAndIssueInvasionOrder` (`0x4A09B0`).**
1. Empty fleets under a busy order (COrder slot 24) are stopped at `+0x90`. A stationary loaded fleet away from `+0x90` that carries a free land unit is sent there with `transport`.
2. Empty fleets go to `+0x90`; two or more arrived and mergeable -> `CMergeCommand` (constructor `0x1DB800`), and the stage ends.
3. More than one fleet -> wait.
4. The fleet at `+0x90`, not moving and not busy, loads every land unit standing there (`CLoadArmyCommand` where `CNavy::CanCarry`). It waits while units are still walking there and the smallest of them still fits.
5. If `+0x90` is not the port: `transport` to the port, and `+0x90` = port.
6. At the port, with an enemy-held objective: objective = `PickInvasionLandingProvince(its area, this)`; none - `AbandonInvasionArea` and finish; otherwise `IssueUnitOrder(invasion, fleet, objective)`, posting a `CSetOrderCommand` with the target list {objective}, from = to = now, and setting every unit agent's `replan_subordinates`.
7. If the objective is no longer enemy-held: with an area under 4 provinces, more than 10 x provinces non-enemy land units in it, and `PickNearestInvadableNeighbourProvince(objective)` answering -> `invasion` on **that** province; otherwise `transport` to the objective.

**`UnitCanReachObjectiveOverland` (`0x4A11B0`)** answers true on the objective or in its area; false off the front, in the port's area or in our capital's area; true with a passable edge into the objective's area (`CMapProvince_HasEdgeIntoArea`, `0xA6B00`), or with an enemy neighbour area that touches it.

**`AddUnit` (`0x4A1680`) / `RemoveUnit` (`0x4A1860`) / `OnUnitUnloaded` (`0x4A18E0`).** AddUnit puts a unit in the air, land or naval list by domain; the land branch zeroes `staging_province`; a duplicate answers false. RemoveUnit (slot 64) clears the unit from all three lists and zeroes `+0x198`. OnUnitUnloaded (slot 70, called by `RemoveFromTransport`): an unload in the port's area is ignored; elsewhere the unit goes to `0x497B40`, which attaches it under a theatre headquarters.

### E.6 What kills an invasion

`IsInvasionOver` (E.5) - including the normal end, the troops ashore on the objective; no friendly embarkation port; no landing province left in the objective's area - the area joins the failed list until the 1st of next month (`AbandonInvasionArea`, `0x494C40`: append to `+0x94` unless already there); and `CEU3AI_PruneInvasions` (`0x491BE0`), hourly - finished agents dropped; for an AI country, an invasion dropped once its objective's area is neither ranked nor a neighbour of a ranked area, so an empty ranked list (e.g. after losing lift) drops them all; for the player, once no agent's plan objective lies in that area. A dropped invasion's fleets get `none` at their home base, troops aboard a fleet **in port** are unloaded (`CUnloadArmyCommand`), and the agent is removed.

### E.7 `CEU3AI_RebuildWeakEnemyPorts` (`0x4972E0`)

Daily, `CEU3AI +0xD8` is refilled, by descending score, from our enemies and our WarTargets (not deduplicated): each target's **true** capital, when no land brigade of anyone stands in it; the ports of its areas of <= 5 provinces where none stands. Score = 100 x naval level_max + 10 x air base level_current, +1000 for a depot, kept only above 0. **It is read by `0x4CC690`** (the paradrop planner, section A), not by the invasion planner.

### E.8 Against the saves

The five saves hold no invasion - "invasion" appears only as technology names. Consistent with the rules: the one war is Italy against Ethiopia, which has no coast in 1936, so its areas are landlocked and never candidates, and any coastal Ethiopian-held area would also touch Italian land and be failed. *Inferred*; the landlocked flags were not dumped. There is no positive oracle for any figure here.

### E.9 Corrections to the record

| record | read |
| --- | --- |
| PlanAmphibiousInvasion "skips any candidate area AreaIsConnectedTo says is joined overland" | dead code: asked of `g_null_owner_area` (slot 0 = ReturnFalse) |
| "SumTransportWeight" at `0x1D66D0` (planner, ranking) | sums `transport_capability` (`+0x144`); `UnitList_SumTransportCapacity` (section F) |
| creation needs lift >= "required" | >= the smallest picked division's weight |
| `0x4A0610` LoadTransportsAtNight; theatre2 "loads up to three land units in daylight" | carrier air groups on `ground_attack` until sunset |
| `0x49FBC0` score `(1.5 - nb/10) x w` | x area weight x distance, x3 rule; 4.0 only where the area borders an enemy |
| theatre2 section 5 stage 3 "invasion order" in the else arm | on `PickNearestInvadableNeighbourProvince`'s province |
| AddUnit "a duplicate returns true" | answers false |
| `+0x370` "brigade shortfall" | land units - divisions picked |
| RebuildWeakEnemyPorts "read by the invasion planner (0x494CC0)" | read by `0x4CC690` |
| CAIInvasion `+0x84/+0x88/+0x90/+0x74` names, ctor param "staging" | objective / embarkation port / rendezvous / air list |
| `COwnerArea +0x3C` unknown_3c | neighbour-area count (written by AdjustNeighbour) |

### What looks wrong but is what the bytes do

1. The planner's overland test is asked of the null area and never fires.
2. The planner's lift is computed once and not reduced as invasions take fleets, so several invasions in one pass all count on the whole fleet.
3. The landing port is counted twice in its own capacity: it is also one of "the area's ports within the radius".
4. In the capital's area the division need is **halved** (more spare), unless the area borders an enemy or is well-ported.
5. `+0x370` adds a unit count to brigade demand.
6. USA's +200/+600 against Japan holds only while the Soviet Union is *not* weak.
7. Dominions never invade before 1942; GER never takes London's area before 1943; GER's small islands score -99 before 1944.
8. The Allies' brake keys on a faction named `"allies"`.
9. An AI country's areas touching its own coast are failed for the month, even when worth invading.
10. Stage 2's "past sunset and before sunrise" refusal can never fire.
11. An air-list duplicate in AddUnit falls into the land test.
12. PruneInvasions copies kept fleets into a list nobody reads.

### What could not be settled

- `CountEnemyUnitsInArea`'s flag; COrder slot 24 ("busy"); `CSubUnitDefinition` slot 9 asked of `assault_ship`.
- `CUnit +0x18` strategic resource (an object with slot 14, though the record types it int).
- The polarity of gamestate `+0xD0C` in MayInvadeArea (`FINDINGS-invasion.md` section 17.4).
- Whether the player's bound plan agents really create invasions over the player's units.
- `CAIInvasion +0x3D`. Nothing here was watched live.

### Frontier

`0x497B40` (attaches a landed unit under a theatre HQ: own province's theatre, else the agent covering a province we may operate in, else the nearest port's, else the capital's, via `CAttachUnitCommand`; shape only; also CAIUnit slot 70 `0x4D54A0`); `0x1DB800` (`CMergeCommand`'s constructor, vftable `0x15C8D9C`); `0x1C6F40` (CUnit slot 25, the average strength share; read in passing, unrecorded).

### The tables (E)

Functions: `0x492190` `CEU3AI::PlanAmphibiousInvasion` revised confirmed; `0x493756` `PlanAmphibiousInvasion_AddBrigadeNeed` revised (comment); `0x495530` `CEU3AI_RankInvasionAreas` revised confirmed; `0x491BE0` `CEU3AI_PruneInvasions` revised confirmed; `0x4972E0` `CEU3AI_RebuildWeakEnemyPorts` revised confirmed; `0x494C40` `CEU3AI::AbandonInvasionArea` revised confirmed; `0x494CC0` `CEU3AI_MayInvadeArea` new; `0x49F920` `CAIInvasion::CAIInvasion` revised (second argument the objective); `0x49FB40` `CAIInvasion::DoTick` revised; `0x49FBC0` `CAIInvasion::PickEmbarkationPort` revised (renamed from PickLandingSite); `0x4A01F0` `MarchLandForceToPort` revised; `0x4A0610` `CAIInvasion::SendCarrierAirSupport` revised (renamed from LoadTransportsAtNight); `0x4A09B0` `SailAndIssueInvasionOrder` revised; `0x4A11B0` `UnitCanReachObjectiveOverland` revised; `0x4A12F0` `IsInvasionOver` revised; `0x4A1680` `AddUnit` revised; `0x4A1860` `CAIInvasion::RemoveUnit` new; `0x4A18E0` `CAIInvasion::OnUnitUnloaded` revised (renamed from ReleaseUnitOutsidePortArea); `0x817E0` `COwnerArea_IsWellPorted` new; `0x81880` `COwnerArea_MinPortDistance` new; `0x80430` `RegionGroup_BordersEnemy` new; `0x49C240` `CList_InsertByDescendingIntAt4` new; `0xA6B00` `CMapProvince_HasEdgeIntoArea` new. `vftable_slots`: `CAIInvasion` 63 AddUnit, 64 RemoveUnit, 70 OnUnitUnloaded, 73 DoTick.

Fields: `CAIInvasion +0x84` `objective_province` (was staging_province), `+0x88` `embarkation_port` (was landing_province), `+0x90` `rendezvous_province_id` (was landing_province_id), `+0x74` `air_units_first` (was units_first), `+0x54` `land_force_first` (comment) - all revised; `CEU3AI +0x94` `failed_invasion_areas_first` revised (comment); `CEU3AI +0xC8`/`+0xCC`/`+0xD0`/`+0xD4` `ranked_invasion_areas_*` new; `CEU3AI +0xD8` `weak_enemy_ports_first` new; `COwnerArea +0x3C` `neighbour_areas_count` revised (was unknown_3c); `CAIUnit +0x370` `invasion_brigade_need` revised (comment).

## F. Sealift and the pass's remainders

*Read 2026-10-19 on the listing, the decompiler as a map only. Addresses are rvas unless marked VA.*

**In short.** A division's saved `target` only ever means "bound for a theatre area across a break in our side's land": units inside one piece of friendly land are never given one, and a target is dropped once the unit arrives. **Corrections**: `FINDINGS-agents.md` E.6's "debark is a division's target in 10 of 12, Australia and New Zealand the exceptions" was wrong - it holds in 12 of 12 in `_01_04_12`, and in 29 of 29 across three saves; E.6's "+3" vote term is never applied to an AI country (it is a tally of the played country's objectives); the whole function is gated on the country owning at least one whole unit of transport capacity; and `AI_ReassignLeaders` reassigns nothing - it only gives leaders to units that have none, its "compare against the leader in place" path being dead code - so it is renamed `CEU3AI_AssignLeadersToLeaderlessUnits`.

**In one paragraph.** Once a day at hour `(id+6)%24` each bound agent sorts its land units against its theatre's areas - skipped entirely when the country has no transport capacity. Every area gets a need (`EstimateAreaNeed`) and a count of the divisions standing in or bound for it; targets outside the theatre, and surpluses, are released; areas short of divisions get units from other pieces of land, each given a target province (a port, or a landing province for enemy-held land) through `CSetAIParamCommand`, marched there when it can walk and otherwise listed for the sea. The listed units vote for a debark port, the area where most of them stand supplies the embark port, they are marched to embark and boarded, and transports are sent until their capacity covers the troops' weight. Separately, at `(id+16)%24` units left in other countries' land are walked home, and at `(id+8)%24` units without a leader are given one.

**Exe-hardcoded**: the transport-capacity gate (>= 1); halving the capital-area need; every weight - 10000 and -10 (release); 10000, 101, 2, 100, 50, 0.25 (candidate score); 1, 4, +3, +10 (vote); the 0.01 organisation floor, the `((1-s)+(1-o))*2+1` transport formula, the 1e6 caps; 0.5, 10, 1000, 34 and "> 5 enemies" (landing province); 0.25 and 10000 (recall); 1.25, 1.2, 1.5, 1.1, 0.5, -5.000 C, x100 (leaders). **Mod-able** (no `defines.lua` read anywhere here): the map - areas exist only for provinces above one level of infrastructure, sea links, naval bases in history and buildings; the unit files - `transport_capability`, transport weight (definition `+0x10C`), supply and fuel consumption; `common/traits.txt` (which effect kinds a trait has) and `history/leaders` (`max_skill`, traits); weather and climate (the winter_attrition test).

### F.1 When

- **`CAIUnit::AssignAreaTargetsAndSealift` (`0x4C4370`)** is the tick's row 17 (VA `0x8B0C38`), for the agent nearest above its unit, with `daily = (hour == (id+6)%24)`. It runs when the agent has a unit and (`+0x5C` is set, which it clears; or `daily`; or the country's `runs_units` is clear) - so the human's delegated agent runs every hour. **First gate**: `UnitList_SumTransportCapacity(country->Units)` must be >= 1, else it returns at once and nothing below happens - no targets, no embark or debark (VA `0x8C43EA`). The answer is ignored by the tick.
- **`CEU3AI_RecallStrandedLandUnits` (`0x498870`)** runs on an AI country's first pass and at `(id+16)%24` (VA `0x889A47`-`0x889A57`).
- **`CEU3AI_AssignLeadersToLeaderlessUnits` (`0x498EF0`)** runs at `(id+8)%24`, after `DeployFinishedUnits` (VA `0x889AC5`-`0x889AD6`), AI countries only.

### F.2 The areas, their need and what they have

1. **Areas**: `L` is the theatre's area list (`CTheatre +0x84`), keeping only real areas (slot 0), in order.
2. **Need**: for each area, `need = EstimateAreaNeed(agent, area, &theirPower, &visited, relaxed)`, `relaxed = country at war && !COwnerArea_TouchesHostileArea(area)`. When relaxed is set and the area is the acting capital's, `need /= 2` (C division, toward zero) (VA `0x8C4504`-`0x8C4569`).
3. **Have**: `have[area] = CAIUnit::CountDivisionsInArea(agent, area, .., false)` - divisions counted by `Unit_GetAnchorProvince(unit, 1)`, i.e. by their target if they have one, else by destination or position.
4. **Played-country extras**, only when `gamestate +0xC34 == agent country`: objectives per area, and a loop lowering the theatre's largest area's need while the objectives elsewhere outnumber its surplus. An AI country never has them.
5. **With no theatre** (`GetArea` null - the human's delegated AI only), `L` is built from the plan's objectives: their own area if ours, else our areas beside them, each with `need +=` the agent's land-unit count.

### F.3 Releasing targets (`CSetAIParamCommand(unit, 0, staging)`)

Every release writes `CArmy +0x2E8 = 0` at once and posts the command; its `Execute` writes `target = 0` and `staging_province = staging`, and staging is always passed through unchanged.

1. **A target outside the theatre** (VA `0x8C4D01`): a unit of `+0x11C` whose target lies in a real area not in `L` keeps it only if `army_role == 0` and the target is held by a country we `CanOperateIn`; otherwise it is released, and if a division, `have[where it stands]++`.
2. **Surplus** (VA `0x8C4F80`): for each area `a` of `L` in order, while `have[a] > need[a]`, release one candidate - divisions (`oob_level >= 4`) not aboard (`+0x300`), bound for `a`, standing (destination or position) in an area with `need > 0` (in practice an area of `L`). The one taken has the greatest "distance" (from -10): CMap distance to its target; or, with an embark set, 10000 if it stands outside embark's area, else its distance to embark. After each release `have[a]--`, and `have[its area]++` if that area is real.
3. **No longer shippable** (VA `0x8C5613`), each unit: **with a target**, if `CAIUnit_MayShipUnitToArea(agent, unit, targetArea)` now refuses, release it (`have` moves from the target's area to where it stands); otherwise it goes on the **sealift list**, weight `+=` definition weight / 1000 (truncated per unit), and if bound for debark and standing in embark's area it counts toward the **embark tally**. **Without a target**, it is **stranded** if it stands (destination or position) in a real area outside `L` that is ours, or anywhere outside `L` while trespassing (`+0x1A8`); a trespasser whose path's last province is held by an `IsFriend(.., 1)` country instead has its target zeroed directly (no command) and is not counted as stranded.

### F.4 `CAIUnit_MayShipUnitToArea` (`0x4C41D0`)

Whether a unit may be given a target in an area (or keep one). False when: the area's region group (`COwnerArea +0x6C`, "the land a country and those fighting beside it hold in one piece", `FINDINGS-supplynetwork.md` section 8) is the same as the group of the **current** province's area; or the destination's area is real and landlocked (`+0x68`) or portless (`+0x50 < 1`), and `CanUnitReach(area's first province, unit, 1, 1)` fails; or the destination is enemy-held and the unit `IsHoldingGround`, is retreating, or `CAIUnit_UnitMayLeave(agent, unit, 0, 1, 1)` refuses; or the area is enemy-held and `army_role` is 0 or 5; or the area is not enemy-held, `army_role` is 3 or 4, and either (`area +0x3C < 1` and it is not the acting capital's area) or the unit's own area `TouchesHostileArea`. Otherwise it answers `AreaPair_SeaRouteOpen(own area, country, area)` (`0xD5760`): at peace, the same area, or some port pair passing `0xD52A0`.

**So a target never lies inside the unit's own connected piece of friendly land, and arriving in the target's group drops the target at the next run.** The saves bear this out: every division target in `_01_04_12` lies across water - Diego Garcia, the Maldives, Kuching, Sapporo, Nice from Algiers, Olbia, Ibiza, Dunedin from Wellington, Samoa - or across land of one level of infrastructure (Broome, Port Hedland and Exmouth from Brisbane, Perth and Launceston: the outback belongs to no area). Only countries with transports hold targets: ENG, JAP, FRA, ITA, HOL, SPR, AST, NZL.

### F.5 The deficit list and the assignment (VA `0x8C59D6`-`0x8C6663`)

1. **The records.** Each area of `L` gets `{area, d = need - have}`. Our own areas go into a list kept **descending by d** (`0x4DD740`: walks from the tail and inserts after the last entry with d >= new, so stable); a new record whose d equals the head's, with more provinces (`+0x2C`) than the head's area, is put in front. Other countries' areas are sorted the same way in a second list, then pushed one by one onto the front of the first, so they come first and in reverse (ascending d).
2. **Per record**: `enemy = IsEnemy(us, area controller)`. `extra` = the stranded count, only when the area is not enemy-held, the stranded count is > d, and (the area `TouchesHostileArea`, or it is `CTheatre_LargestArea`, or with no theatre it is the first record); else 0. `want = max(d, extra)`; if `want < 1`, skip. Target province P = `CAIUnit_PickLandingProvince(agent, area)` if enemy-held, else `CAIUnit_PickPortNearestObjectives(area, agent)`; none, skip.
3. **The fill.** While `want >=` the next record's d (0 for the last), or (enemy-held and `want > 0`): pick the best candidate (none: next area); write `CArmy +0x2E8 = P` and post `CSetAIParamCommand(unit, P, staging)`; if `CanUnitReach(P, unit, 1, 1)`, `CEU3AI::MoveUnit(unit, P, 0, safe 1, verySafe 1, 0)` - the march, which the saves show as a `strategic_redeployment` to the embark port - else put it on the sealift list; `have[area]++`, `have[unit's area]--`, and count toward the embark tally when P is debark and the unit stands in embark's area; then decrement `extra` if the unit was stranded, else d, and recompute `want`.
4. **Candidates**, in `+0x11C` order: no target; anchor (destination or position) area real; `CAIUnit_MayShipUnitToArea`; not `army_role 8` while the agent has air transports; if its area borders an enemy area, none of those enemy areas may also touch the target area, and it must not stand in the land of a non-REB country that `IsSameSide` or a co-belligerent we are not at war with; its own area's need <= 0, or have > need; the agent's own unit only for the theatre's largest area; `oob_level >= 4`.
5. **The score**: start at `have - need` of the unit's own area. **Stranded**: +10000, and taken even when `d < 1`; otherwise not considered while `d < 1`. With `x` = slot 88 (`RateUnitAsGarrison`): **enemy-held area**, + slot 87 (`0x4BE2C0`); **otherwise**, + x if the area does not touch hostile land but the unit's area borders an enemy, + (101 - x) if the area touches hostile land and the unit's area borders no enemy, nothing in the other two cases. + 2x when the target area's `+0x3C < 1`. +100 when the parent's anchor (target first) is in the target area; +50 for each other land sibling anchored there. When the unit's area borders an enemy: x2 if `CUnit +0x2C9` is set, else x0.25 if it stands on an ops-area province. The strictly highest score wins, starting from 0.
6. **Headquarters** (VA `0x8C5D8D`): each unit of `+0x14C` (non-divisions) with no target and not a theatre - find the area where most of its direct land children stand (ties go to its own area); if not its own area, `CArmy +0x2E8 = PickPortNearestObjectives(that area)`, posted with **staging 0**, no move. In the save, 4eme Armee (child at Tunis) gets Alger and 5eme Armee (child at Alger) gets Annaba.

### F.6 The pickers

- **`CAIUnit_PickPortNearestObjectives` (`0x4C3940`, area in EAX)**: the area's provinces with a sea link (template `+0xA4 >= 1`) and a naval base `level_max >= 1000`; the mean `NavalDistanceTo / 1000` to the plan's objectives, or with none to its ops area, or with none to the unit's province; the smallest mean below 1e6 wins, first of equals. Every saved target in all three saves has a naval base in the install's history.
- **`CAIUnit_PickLandingProvince` (`0x4C3D50`)**: for each p in the area - over p's edges not of kind 3, to simulated provinces of p's own controller: n = their number, S = n x p's own naval base level, and a flag that every one of those edges is kind 1 (a strait). p is considered only with a sea link and a naval base >= 1, or S >= 1.0, and only with <= 5 enemy land units in it. `avg` = mean CMap distance to the plan objectives lying in the area, /10 if p is one of them. `score = avg - level - 0.5*S - 10*n (+1000 when the strait flag holds and n > 0) + 34*enemies`; the lowest below 1e6 wins.
- **`CAIUnit_PickEmbarkPort` (`0x4C3AF0`)**: over the area's ports, the mean sea distance to the listed units bound for debark whose **current** province is in the area (no such unit: return at once); a port beating the best mean so far is taken only if the route search `0x1A1630` finds a way from it to debark's sea province.

### F.7 Embark and debark (VA `0x8C67C8`-`0x8C7484`)

1. **Bookkeeping**: `+0xD4` = sealift weight. `+0x58` = `COwnerArea_LargestNavalBase(CTheatre_LargestArea)`, or 0 with no weight.
2. **Clearing**: `CSetPlanTransportStateCommand(unit, 0, 0)` is posted when exactly one of embark and debark is set, or when both are set and the embark tally is 0.
3. **The vote**: while debark is unset, weight > 0 and the agent has naval transports (`+0xEC`), each listed unit votes for its target: **1**, or **4** where its area's need < 1; **+3** where its area holds a played-country objective (never for the AI); **+10** where the target is not ours.
4. **Choosing the pair**: debark is the strictly best target not yet tried; embark is taken from the area (other than debark's) with the most units bound for debark, the strictly largest count that yields a `PickEmbarkPort`. If found, post `CSetPlanTransportStateCommand(unit, embark, debark)`; else set the target aside and vote again.
5. **Ties**: the vote map and the area-count map are `stdext::hash_map`s, so ties go by their iteration order; for the area map that is pointer order, which is not reproducible.
6. **With both set**: *troops* - each listed unit bound for debark that stands in embark's area and is not aboard, fighting or retreating adds its weight; if it stands at embark it is boarded there (`0x4D4070`, `CLoadArmyCommand`), otherwise marched there (`MoveUnit 0,1,1,0`). *Capacity* - the transports at embark whose order slot 24 is false add `transport_capability / 1000` each. *Sending transports* - while weight > capacity, send (`MoveUnit 0,0,0,0`) the transport that is not at embark, has no blocking order (an order answering slot 24 passes only if of kind `0x4E5`/`0x56C` and the unit not moving), passes `CUnit::CanMoveTo(embark)`, and has mean organisation >= 0.01, with the smallest `(((1-strength)+(1-org))*2+1) x sea distance / 1000`. *Then* the first idle transport in embark's port runs `0x4D4D40` (unload/merge), or failing that `0x4D42D0`.

**Against the saves**: 12 pairs in `_01_04_12`, 10 in `_01_08_07` and 7 in `_04_20_03`; in every one some unit under that theatre has `target = debark`. Several already stand at embark: the 7th Indian at Karachi; the 85eme/182eme at Alger with the XIX Region; the 6th Indian at Rangoon. The 4th Indian (Delhi -> Diego Garcia) carries a `strategic_redeployment` to Karachi, the embark port - the march of step 6. Ponape, Truk, Saipan and Eniwetok garrisons and the Taiwan division are all bound for Sapporo, embark Gaoxiong; the island garrisons' own provinces lie in no real area, so only Taiwan's area counts toward embark.

### F.8 `CEU3AI_RecallStrandedLandUnits` (`0x498870`), whole

**Who is stranded**, each unit of the country in list order: a land unit with a province, in a province another country controls; in an area that `AreaMayWidenFrontSearch(us, area, &out, 0)` refuses; not fighting, not aboard, not retreating; not on enemy-held ground; with its destination (if a different province with a real area) not enemy-held, not ours, and not allowed by `AreaMayWidenFrontSearch`.

**Where to**: (1) the province of our own areas (`CCountry +0xD30`) nearest by CMap distance, x0.25 inside the acting capital's area, that `CanUnitReach(p, unit, 0, 0)`; (2) else a province of a neighbouring area we `CanOperateIn` that does not `TouchHostileArea`, nearest, with 10000 subtracted where we control it - **no reach test** here; (3) else, for a division, the nearest province of its own area with a naval base >= 1; (4) else the acting capital.

**Then**: a trespassing unit with a target goes only where that place is held by an `IsFriend(.., 1)` country, its target then zeroed directly; otherwise it is left alone. `MoveUnit(unit, id, 0, safe 1, verySafe 0, 0)`. With no destination and no capital: `CDisbandCommand(unit)` (constructor `0x1D99A0`).

### F.9 `CEU3AI_AssignLeadersToLeaderlessUnits` (`0x498EF0`) and `AI_LeaderFitForUnit` (`0x499500`)

**Fit** (leader in EAX, unit in EDI, float): 0 unless the leader is real and `MayTakeLeader(unit, leader, onlyFree 0)` holds (`FINDINGS-leaderassign.md` section 6: the exact rank by land level). Otherwise start at **`max_skill` (`CLeader +0x74`) x 100** - `max_skill`, where the start's choice uses `(skill+1)x1000`. Then for each effect of each trait, by kind (`FINDINGS-combatmods.md`'s 0-based enum): **x1.2** for 1 surprise_chance, 3 defence_modifier, 4 offence_modifier, 21 encirclement_bonus, 22 envelopment_bonus; **x1.5** for 9 combined_arms_bonus where `base_ca_bonus > 0`, 10 out_of_supply_modifier where the unit's `supplies != 1000`, 6 winter_attrition where its province shows a weather graphic and its temperature is < -5.000; **x0.5 x (supply + fuel consumption per brigade, without leaders, /1000)** for 2 supply_consumption; **x1.1** for every other kind. A land unit with `army_role 5`: x0.5.

**The pass**: clear `ai +0xA4`, then write every unit's `CUnit +0x2C0 = fit`. For each unit of `CCountry +0xBAC` in order **with no real leader**: go through `active_leaders` in order, over those of rank > 0, commanding nothing, and not already given this pass; take a leader when `fit >= 1.25 x` the current pick's fit (fit >= 1.25 for the first). Post `CAssignLeaderCommand(unit, leader, 1)`, whose `Execute` calls `SetLeader` with both flags - so **the AI's choice costs the unit its new-leader organisation hit**, which the start's automatic choice does not. **Not settled against a save**: the saves' leader references change between `_01_01_00` and `_01_04_12` for reasons this pass does not explain (the played Germany's too).

### F.10 What looks wrong but is what the bytes do

1. With no transport capacity at all, a country never gives a division a target or a plan an embark/debark - the land part included.
2. A target is never given within one connected piece of friendly land, and is dropped (with a posted command) as soon as the unit reaches the target's land group, before it reaches the province.
3. Other countries' deficit areas come first and in **ascending** order of deficit; a friendly foreign area is filled only while its want >= the next record's deficit, an enemy area to its whole want.
4. For the last record the fill runs while `want >= 0`, so it takes one unit more than the deficit when candidates allow.
5. Release writes `CArmy +0x2E8` locally before the command executes; a stranded trespasser's target is zeroed with no command at all (here and in the recall).
6. `CAIUnit_PickLandingProvince`'s S multiplies **p's own** naval base by its friendly-neighbour count.
7. A landlocked objective adds 0 sea distance to the port pickers, `NavalDistanceTo` answering 0 without a sea index.
8. The recall's second search has no reach test, and a disband happens only when the country has no acting capital.
9. The leader pass's comparison against the leader in place and its "freed leader" list are dead code; `CUnit +0x2C0` is written and never usefully read.
10. The leader fit's supply_consumption factor is (supply+fuel per brigade)/2, which *lowers* the fit for most infantry.

### F.11 Not settled

- `0x1A1630` (the embark route search) and `0xD52A0` (the port-pair route test) are not read; nor what slot 87 (`0x4BE2C0`) answers exactly.
- `0x4D4070`, `0x4D4D40` and `0x4D42D0` - boarding, unloading and the sailing - named by their calls only; `0x4D42D0` is recorded `AIUnit_EstimateMoveTime` but is called here with (agent, transport) as the sailing step, so that name is doubtful.
- The `stdext::hash_map` iteration order that breaks ties in the vote, the embark area and the headquarters' children count.
- `COwnerArea +0x3C` (still `unknown_3c`): roles 3/4 need it >= 1 or the capital's area, and +2x in the score when < 1.
- `army_role`'s meanings (0, 3, 4, 5, 8); `COrder` slot 24.
- The leader pass against a save.

### Frontier

`0x4BE2C0` (slot 87: a 0-100 division figure - mean strength fraction times a per-type weighting, capped at 100; unassigned); `0x4D4070`, `0x4D4D40`, `0x4D42D0` (transports); `0x1A1630` (route search); `0xD52A0` (section D); `0x4DD740` (a generic sorted list insert). **For section E - a correction**: the records of `CEU3AI_RankInvasionAreas` and `CAIInvasion::PickLandingSite` call `0x1D66D0` "SumTransportWeight"; it sums `transport_capability`, so PickLandingSite's `SumTransportWeight(&+0x64) >= SumTransportWeight(&+0x54)` compares capacities, and is always true if `+0x54` holds land units.

### The function table (F)

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| `0x4C4370` | `CAIUnit::AssignAreaTargetsAndSealift` | revised | confirmed | read whole off the bytes |
| `0x4C3940` | `CAIUnit_PickPortNearestObjectives` | new | confirmed | |
| `0x4C3AF0` | `CAIUnit_PickEmbarkPort` | new | confirmed | |
| `0x4C3D50` | `CAIUnit_PickLandingProvince` | new | confirmed | |
| `0x4C41D0` | `CAIUnit_MayShipUnitToArea` | new | confirmed | |
| `0x498870` | `CEU3AI_RecallStrandedLandUnits` | revised | confirmed | whole |
| `0x498EF0` | `CEU3AI_AssignLeadersToLeaderlessUnits` | revised | confirmed | renamed from `AI_ReassignLeaders` |
| `0x499500` | `AI_LeaderFitForUnit` | new | confirmed | |
| `0x7FD90` | `COwnerArea_TouchesHostileArea` | new | confirmed | possible collision with E |
| `0xD5760` | `AreaPair_SeaRouteOpen` | new | confirmed | possible collision with E |
| `0x1D66D0` | `UnitList_SumTransportCapacity` | new | confirmed | possible collision with E |
| `0x1D99A0` | `CDisbandCommand::CDisbandCommand` | new | confirmed | |

Fields: `CUnit +0x2C0` `ai_leader_fit` revised (comment only); `CEU3AI +0xA4` `unknown_a4` new.
