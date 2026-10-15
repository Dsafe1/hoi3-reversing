# The next wave

**This file holds one thing: the wave that is planned but has not run.** It exists because the plan
used to live in `CANDIDATES.md`, which is five hundred lines of queue and archive, and finding the
plan in it was a search rather than a glance.

The contract, so the two files do not drift:

| | |
| --- | --- |
| **`WAVE.md`** (this file) | the plan for the wave that has **not launched**. Overwritten by the next plan |
| `CANDIDATES.md` | the standing queue and the archive. **A wave's result goes there**, not here, along with the area-level backlog a plan is chosen from |

So: plan here -> launch -> write the result into `CANDIDATES.md` -> replace this file with the next
plan. If this file describes a wave that has already landed, it is stale and `CANDIDATES.md` is the
truth.

---

## The building-queue wave - a building line ordered, priced, finished and placed

> **LANDED 2026-10-15.** Two briefs, merged (52 address entries landed and 9 revised; 3 structs declared, 26 fields;
> apply 206 `failed: 0`, `struct fields: 0`); the write-up is `findings/FINDINGS-buildingqueue.md` sections A and B,
> indexed in `CANDIDATES.md`, where six things it left are queued.

Planned 2026-10-15, for OpenHOI3, on the maintainer's word that day: "Undergrounds now, queue later" - the undergrounds
are built there without the way one is ordered, and **buildings in the build queue are its next piece**. OpenHOI3's
queue holds units only (`FINDINGS-buildqueue.md`, which this extends): an order, pricing (`RecalculateCost`), the day's
work, finishing and placing a unit are built; **no building line exists**, the production screen's building buttons do
nothing, and an underground can only be finished by hand. Two briefs; the write-up is **a new
`findings/FINDINGS-buildingqueue.md`**, sections A and B.

**Scope.** In both installs only the buildings whose file says `capital = yes` have a production-screen button (air
base, naval base, anti-air, radar station, underground, nuclear reactor, rocket test - `FINDINGS-productiontooltip.md`
section 2); forts, infrastructure and industry are built from the province view, which OpenHOI3 does not have. Both
briefs read **the building line whatever posts it**, and say which path each of the two roads takes. Convoys - the
queue's third kind of line - are out of this wave.

**What is known and is not to be redone** (cite it; re-read on the listing only to raise an `inferred` record or
correct it): `FINDINGS-buildqueue.md` (a unit line: `CMilitaryConstruction::RecalculateCost`, the day's work, finishing,
placing, the queue's commands and the line's text; "a finished building or convoy prices every line again" is section
9's inference); `FINDINGS-production.md` (the production share's day); `FINDINGS-productiontooltip.md` sections 2 and 6
(the building buttons' tooltips and `CCountry_CanTrainUnderground`); `FINDINGS-occupation.md` section E.2 (the
underground's own branch of `CBuildingConstruction::Deliver` and `CBuildingDeployment::DeployAt`, and the placing map's
colours `0x867A00`, inferred); `FINDINGS-deploymenu.md` (the deploy menu, for units); `FINDINGS-mapbuild.md` (buildings
drawn on the map); `FINDINGS-buildertooltips.md`; `CConstruction::CanStillBeBuilt` (`0x4831C0`, slot 12) is recorded.

**The oracle.** The start save's `production_queue` blocks hold the history's building lines where a country starts
building one, with their cost, days and progress; the later saves (1 February, 1 March, 1 April, 20 April 1936) show
lines advanced and finished, and the map's buildings changed. Each brief that reads something a save keeps should
say what it predicts there and check it.

| brief | what it settles | starting points |
| --- | --- | --- |
| **A. A building line ordered and priced** | `CConstructBuildingCommand` whole (`LoadKey` `0x545310` is recorded: `building`, `id`, `province`) - its `IsValid`, its `Execute`, which line it makes and with what (a province or none), and **who posts it**: each production-screen building button's press (and anything it opens or asks - a province to be chosen?), the province view's building buttons if they are the same command, the AI's Lua (`CConstructBuildingCommand` in `ai_production_minister.lua`), and what is refused where. **`CBuildingConstruction`** - its constructor, layout and `LoadKey` (`0x485980`: `building`, `count`), and **its slot 14, the price**: how a building's `cost` and `time` become a line's IC a day and days, every modifier and technology on them (the country's `GetBuildTime`/`GetBuildCostIC` or its own terms), `count` (several of one building on one line?), the `practical_factor` and the line's `on_completion` / `completion_size` practical gain; slot 12 as recorded; **the day's work for a building line** beside a unit's - whether the production share's loop treats it the same way, gearing and the serial-run term; **the line's text and tooltip** on the production screen (`FINDINGS-buildqueue.md` section 8 has a unit's: what a building's line writes, its picture), and the five buttons on it. Set the start save's building lines against what the reading predicts | `0x545310`, `0x485980`, `CMilitaryConstruction::RecalculateCost` (`0x485300`), the production screen's building buttons (`FINDINGS-productiontooltip.md` section 2) |
| **B. A building finished and placed** | **`CBuildingConstruction::Deliver`** (`0x485BD0`, recorded `inferred`) whole on the listing: a line with a province against one without; `level_max` and `level_current` (is what is finished working at once?); what `CProvinceBuilding_OnLevelChanged` does; the area's bases refreshed; radar; a building's own effects (a naval base making a port?); the province's modifier made again; the messages (`BUILDING_DONE` and any other, with their variables and who is told); **every line priced again**, if so. **`CBuildingDeployment`** - constructor, `DeployAt` (`0x57E640`, recorded `inferred`) whole, **its `CanDeployIn` (slot 10)**: for each key of `CBuilding::LoadKey` that bears on it (`port`, `capital`, `onmap`, `not_if_x_exists`, `prerequisites`, `max_level`, `orientation`, `show_for_province`) and for ownership and holding, which provinces may take it; **the deploy menu for a building**: its entry and tooltip (`CDeploymentEntry` for a building's deployment, slot 8 not answering `unit_deployment`), what clicking it and then the map does (`CDeployUnitCommand` with a building's deployment, or another command), the map's colouring while one is placed (`0x867A00`, recorded `inferred` for the underground) for every building, and what is refused where; and what is told when it is placed | `0x485BD0`, `0x57E640`, `0x57EDB0` (`CBuildingDeployment::LoadKey`), `0x5490D0` (`CDeployUnitCommand::Execute`), `0x867A00`, `FINDINGS-deploymenu.md` |
