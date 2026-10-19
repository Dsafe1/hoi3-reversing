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

## The moving wave - the military AI's third piece: moving and attacking

> **LANDED 2026-10-19.** Six readers, A to F below, on the maintainer's word "Ok lets go" (2026-10-17; relaunched on
> 2026-10-19 after the first launch hit the usage limit before any reader's first step). Six fragments merged (72 address
> entries, 43 new; 1 struct declared, 40 struct fields; apply `failed: 0`, `struct fields: 0`); the write-up is
> `findings/FINDINGS-moving.md`, indexed in `CANDIDATES.md`, where what it left is queued. The attack's candidates are
> taken lowest cost first; the division need's weight sum is never divided, and the capital's naval floor gives every
> European Soviet theatre 18; the AI's sea targeting asks for no sighting; an invasion's "load at night" stage sends
> carrier aircraft; the AI's leader pass only fills leaderless units.

**The question, for OpenHOI3's stage 5 - the military AI's third piece**: what moves a unit and makes it attack. The
second piece built the theatres, the agents, the order of battle and every plan; nothing yet marches a division to a
front, sends a fleet or a wing at the enemy, lands anyone on a coast - or settles the division need the built balancing
waits on. Six readers, A to F; the write-up is **a new `findings/FINDINGS-moving.md`**, sections A to F.

**Already read, not to be redone - cite it; re-read only to settle a listed leftover or to correct**:

- `FINDINGS-agents.md` - the pass, the agent tick's 22 rows (A.2 numbers them; rows 10, 12, 15, 17, 18, 19, 21 are this
  wave's), the regrouping, the plan whole, and the movers between theatres (F.1-F.5, divisions, fleets, transports, air).
- `FINDINGS-aiconsumer.md` - `CAIUnit_ManageLandUnits` (row 21) phases 1-3 whole: the front-province scoring, the
  committing of units one at a time against the odds bars, the calling-off. Its *What is not established* is reader B's
  list.
- `FINDINGS-attackodds.md` - `CAIUnit::EstimateAttackOdds` (`0x4D93B0`) whole: a damage ratio.
- `FINDINGS-aihelpers.md` - the AI's own combat modifier model (`0x4D8C50` attack, `0x4D8590` defence).
- `FINDINGS-airnaval4.md` - air phase 4's mission assignment; the naval convoy-escort and rebase block.
- `FINDINGS-airstance.md` - who sets the air stance; who fills the four `air_target_provinces_*` lists.
- `FINDINGS-invasion.md` - `CEU3AI::PickInvasionLandingProvince` whole. `FINDINGS-theatre2.md` - `CAIInvasion`'s stage
  machine, named `likely` from one read.
- `FINDINGS-aiplans.md`, `FINDINGS-aiunit.md`, `FINDINGS-theatres.md` - the plan's slots, the class, the theatres.

**The oracle.** The five saves (one game, Germany played): **Italy is at war with Ethiopia in all of them - the one
running war**, so Italy's land block runs every third hour and *Cdo. Sup. Africa* is the one plan at stance 4 with a
`path`; 12 plans in `_01_04_12` carry an embark/debark pair, all ports; between `_01_01_00` and `_01_04_12` 429 units
change place. OpenHOI3's built check (`SaveCheck agents`) leaves concrete targets: the Soviet Home Command holds 3
divisions against the save's 18 (the division need), `our_power` agrees in 22 of 106 and `their_power` in 78 of 106.

| reader | brief | fragment |
| --- | --- | --- |
| **A** | **The land block - who marches where.** Rows 10 and 15: `0x4B1820` (`CAIUnit_UpdateThreatenedProvinces`); `0x4CC450` (the land block's first call, clears `full_pass_pending`) and `0x4CC020`, `0x4D7F80` (sets it back), `0x4CC690` (gated on the air-transports vector `+0x10C` - a paradrop planner?) - all four whole: how a division is given a province to stand in (garrisons, reserves, the walk to the front), which command each posts, and how this meets the per-division `CSetAIParamCommand(unit, target, staging)` targets. With them: which order kinds `0x4E5` and `0x56C` are (slot 86 skips a unit under one), `CUnit +0x2C9` (disqualifies a candidate, one reader at `0x4D6CE0`), `CCountry +0xF50` (tested `> 0` beside `at_war` to run the land pass at all). | `land-block.json` |
| **B** | **Attacking's open ends** - `FINDINGS-aiconsumer.md`'s *not established*, off the bytes: slot 86 (`0x4C7540`, the veto - what disqualifies a unit); slot 88 (`0x4BE560`, a float against 95.0); slot 89 (`0x4BE7E0`, the enemy's power at a province); **`0x49AAB0`, the stand-down primitive** - what command it posts, whether a cancelled attack stops or reverses; slot 17's sign on one `CCombat` subclass (the land body disengages `> 0.5`, the naval `< 0.5` complemented - which is "losing"); `CMapProvince +0x330`/`+0x354` (the unsupplied-attacker port test); `CAIUnit +0x12C`'s contents (`FINDINGS-opsarea.md` item 7's `m mod n`). | `attack-vetoes-and-standdown.json` |
| **C** | **The division need's arithmetic** - what OpenHOI3's balancing waits on. `CAIUnit::EstimateAreaNeed` (`0x4B82F0`) tail, VA `0x8B8F26`-`0x8B9098`, instruction by instruction: the integer score sum divided by 1000.0 and rounded by `fistp`, the float sum carried through the recursion into the focus areas of `+0x338`, and **which of the two is divided by the area's provinces (at most 40)**; `CAIUnit::EstimateTheatreNeed` (`0x4B9610`) whole; `their_power` exact (`0x4B5210`/`0x4B60F0`'s enemy side - the save agrees only 78 of 106); France's 0.5% in `our_power` and how a figure under 1.000 passed the whole-number gate on its first post (`0x4E1D00`?); `0x508C30`. The check: the Soviet Home Command's 18 divisions, and the saves' `our_power`/`their_power`. | `division-need.json` |
| **D** | **Fleets and aircraft to their targets.** `CEU3AI_AssignSeaTargetsToAgents` (`0x48C140`) whole - what fills `+0x25C` (sightings gained), `+0x26C` (lost) and `+0xD8` (`submarine_want`), which `DistributeFleetsToTheatres` and the naval-bomber want read; `CAIUnit_ManageNavalUnits` (`0x4D0880`) rows the regroup (section C) and the convoy/rebase block (`FINDINGS-airnaval4.md`) did not cover - who is sent to sea, to patrol, to intercept, and when; `CAIUnit_ManageAirUnits` (`0x4CD890`) likewise beyond phase 4 and the regroup; `BuildAirTargetProvinceLists` (row 12) against `FINDINGS-airstance.md` - settle what it left. Small leftovers in reach: `0xD52A0`'s war branch (the fleet-to-port route test), `0xE1010` past its combat test (is a transfer refused?), `0x4B4200`'s province score, which way `InsertUnitByRange` keeps its order. | `sea-and-air-targets.json` |
| **E** | **Invasions.** The `CEU3AI` side whole: `PlanAmphibiousInvasion` (`0x492190`) with `AddTransportNeed` (`0x4935DE`), `AddBrigadeNeed` (`0x493756`), `CreateInvasionAgent` (`0x493B18`); `RankInvasionAreas` (`0x495530`); `PruneInvasions` (`0x491BE0`); `RebuildWeakEnemyPorts` (`0x4972E0`); `AbandonInvasionArea` (`0x494C40`); `ProcessAI_UpdateInvasionAgents` (`0x489887`). Then `CAIInvasion`'s tick off the bytes, raising `FINDINGS-theatre2.md`'s `likely` names: `DoTick` (`0x49FB40`), `PickLandingSite` (`0x49FBC0`), `MarchLandForceToPort` (`0x4A01F0`), `LoadTransportsAtNight` (`0x4A0610`), `SailAndIssueInvasionOrder` (`0x4A09B0`), `UnitCanReachObjectiveOverland` (`0x4A11B0`), `IsInvasionOver` (`0x4A12F0`), `AddUnit` (`0x4A1680`), `ReleaseUnitOutsidePortArea` (`0x4A18E0`). `PickInvasionLandingProvince` is read whole - cite it. | `invasions.json` |
| **F** | **Sealift and the pass's remainders.** `CAIUnit::AssignAreaTargetsAndSealift` (`0x4C4370`, 12.7 KB) **off the bytes** - `FINDINGS-agents.md` E.6 has its shape from the decompiler alone: the head's per-division targets by area need and the `CSetAIParamCommand(unit, target, staging)` it posts (and that command's `Execute`), the land-or-sea split, the tail's embark/debark vote, and the pickers `0x4C3AF0` (the port), `0x4C3940`, `0x4C3D50`; `CEU3AI_RecallStrandedLandUnits` (`0x498870`) whole; `AI_ReassignLeaders` (`0x498EF0`) whole - raise it from `inferred`, what it moves and by what rule against `FINDINGS-leaderassign.md`. | `sealift-and-leaders.json` |

**Measurable afterwards, by OpenHOI3**: the 4 January and 20 April saves beside a run - divisions standing on the
fronts' provinces, the two powers whole, the Soviet divisions balanced, embark/debark pairs posted - and the headless
run's Spanish Civil War and Italy's war in Ethiopia no longer frozen.

---

## The agent wave - the order of battle the AI builds under its theatres, and each theatre's plan

> **LANDED 2026-10-17.** Five readers, A to E below, on the maintainer's word "Continue with the next step" after the
> theatre wave; five fragments and a follow-up merged (89 address entries, 55 new and 34 revised, 6 structs, 76 struct
> fields; apply `failed: 0`, `struct fields: 0`); the write-up is `findings/FINDINGS-agents.md`, indexed in
> `CANDIDATES.md`, where what it left is queued. **The counts below are wrong**: they keyed units by id alone, and
> serials of two id types collide (reader B). Keyed by the whole id, 382 units are new - 93 army groups, 96 armies under
> army groups and 1 under a theatre, 89 corps, 87 navies and 16 air units - 44 gone (31 navies, 13 air units) and 599
> change parent; and no ops area changes between `_01_04_12` and `_01_07_14`, an empty one not being saved (reader E).
> **A sixth reader, F**, was sent the same day for the four movers between theatres A had only named, once OpenHOI3's check
> showed what they do (section F); its fragment `movers-between-theatres.json` merged, 18 entries, apply clean. **A seventh, G**, found
> what had already spread the history's units over the theatres by the start save - the sort at each country's first AI
> pass, `0x48D560` (section G), 1555 of 1555 parents - correcting A's first frame and `FINDINGS-theatres.md` K and O.

**The question, for OpenHOI3's stage 5 - the military AI's second piece**: what the AI's unit agents (`CAIUnit`, one per
theatre and below) do to the order of battle and to each theatre's plan in a new game's first days. Moving units and
attacking (`CAIUnit_ManageLandUnits`, naval, air, `CAIInvasion`) are the third piece and **out of this wave** except
where a reader must know which of them a call is.

**The oracle.** `Germany1936_01_01_00.hoi3` is a new game after its two days and first hour; `_01_04_12` three and a
half days later; `_01_07_14` and `_01_08_07` later still, all with Germany played and every other country the AI's.
Between the first two, **285 units are new and 40 gone**: 66 army groups under theatres, 70 armies under army groups,
67 corps under armies, 63 navies and 14 air units under theatres, one army under a theatre and 4 corps under navies; the
40 gone are all fleets (30) and air units (10), so fleets and air units are regrouped. 661 units change parent, 429
change place. From `_01_04_12` to `_01_07_14` only 13 change parent, so **the reorganisation is a first-days thing**.
Every theatre headquarters but the played country's (106 of 108) carries a `plan` block by `_01_04_12` - `active`,
`stance`, `air_stance`, `naval_stance`, `our_power`, `their_power`, `embark`, `debark`, `ops_area`, `min` (58 counts, one a
sub-unit type) - and from `_01_04_12` to `_01_07_14` stance, the two other stances and `min` agree for all 106, the ops
area for 90, the powers for 99. Scratch scripts that print these are in the collecting session's
`scratchpad/agents/` (`unitdiff.py`, `plandiff.py`, `planowners.py`).

**Already read, not to be redone**: `FINDINGS-aiunit.md` (the class, its tick's staggers, its slots), `FINDINGS-aiplans.md`
(slot 76 whole, slot 78's head, slot 84, the objective generator's formula, the stance decider's shape),
`FINDINGS-aitheatre.md` and `FINDINGS-theatre2.md` (the theatre layer's map, `CAIInvasion`), `FINDINGS-aiconsumer.md`
(`ManageLandUnits` - the third piece's), `FINDINGS-aifields.md`, `FINDINGS-theatres.md` (the theatres themselves, read
whole the day before). `ProcessAI` (rva `0x4894E0`) and `CAIUnit::Tick` (slot 73, rva `0x4B0730`) are named in the record
with their callees partly named; each reader starts from them.

| reader | brief |
| --- | --- |
| **A** | **The pass and the agents' life.** `ProcessAI` whole in order, every `CEU3AI` helper it calls named at least by purpose (`0x49A800`, `0x48C140`, `0x491BE0`, `0x495530`, `0x498870`, `0x48DCF0`, `0x499C80`, `0x48E490`, `0x490DB0`, `0x48FBB0`, `0x48F2B0`, `0x499280`, `0x499A10`, `CEU3AI_DisbandTheatrelessHQs`, `RebuildPriorityProvinces`, the `CProvinceFloat_2` call); `CreateAgentsForTheatres`, `EnsureAgentForArea` and their callers, `0x4AC390`, an agent's enabling, `SetUnit`/`ClearUnit` (slots 63, 64), what removes an agent; `CEU3AI +0x2C` (`runs_units`), `+0xA5`, `+0xA6`; and slot 73's gates and the flag bytes `+0x80`-`+0x88` - which callee of the tick is which, so B to E can be pointed at theirs. |
| **B** | **Higher commands made.** Slot 85 (rva `0x4C20C0`) whole - when the agent makes an army group, army or corps (`CCreateHigherCommand`) and what it attaches under it (`CAttachUnitCommand`); slot 82 (`CSetCommandLevel`, every hour); `CAIUnit_PullHeadquartersIn`, `CAIUnit_MoveAgentUnitToCommandProvince`; the observer slots 17-19 (`0x4D5320`); and the `Execute` of `CCreateHigherCommand`, `CAttachUnitCommand` and `CSetCommandLevel` - what each changes, the new unit's id, name (`#st Army Group`), place and leader. The check is the 66/70/67 ladder above. |
| **C** | **Subordinates and fleets regrouped.** Slot 78 (rva `0x4B1D10`-`0x4B32DF`) whole, which `FINDINGS-aiplans.md` read only to its head; slot 79 (`0x4B32E0`, detach and expedition, `vf_80` and `ManageExpeditions` as the tick calls them); the three `CTransferSubUnitCommand` sites (`0x4CE90E`, `0x4D1341`, `0x4D1BEB`) and what they are in; and whatever merges or splits fleets and air units into new ones under a theatre (the 63 navies, 14 air units and 40 gone) - with `CDetachUnitCommand`, `CTransferSubUnitCommand` and any merge command's `Execute`. |
| **D** | **The plan's figures: stance, powers, objectives.** `CEU3AI::UpdateUnitStances` (rva `0x4912D0`) whole - the 0-4 value and the air and naval stances; `CAIUnit_ComputePlanForces` and `CAIUnit_ComputePlanForcesAndPower` and the power estimator `0x4B60F0` - `our_power` and `their_power`; `GenerateUnitObjectives` (`0x4980E0`) and `RebuildPriorityProvinces` with `CCountry +0x4A8` and `CEU3AI +0x118`; `CSetPlanAttributesCommand`'s and `CSetPlanObjectivesCommand`'s `Execute`; what `active` is. |
| **E** | **The plan's area: ops area, axis, embark and debark, `min`.** `CAIUnit::SetArea` (rva `0x4BA5A0`, 5.4 KB) and `GetArea`; `UpdatePlanAxis` (`0x4C3330`); `ReplanSubtree`'s callees `0x4BBB50`, `0x4BC860`, `0x4BCD60`, `0x4BDF30`, `0x4BD270`; `RebuildFocusOwnerAreas`; `CSetPlanOpsAreaCommand`, `CSetPlanAxisCommand` (embark and debark?), `CSetPlanForcesCommand` and `CUnit::RefreshPlanForceNeeds` - what the save's `min` is and how it is counted; the `0x4DCAE0` float at `+0x368`; and slot 76's fallback's double post (`FINDINGS-aiplans.md` step 7), against the saves. |

---

## The theatre wave - fronts, theatres and their headquarters

> **LANDED 2026-10-17.** Read by the collecting session alone, on the maintainer's word that day ("Ok lets do the
> military AI"), cut by that session into pieces with fronts and theatres first; one fragment merged (36 addresses new,
> 9 revised, one vftable slot, 48 struct fields; apply `failed: 0`, `struct fields: 0`); the write-up is
> `findings/FINDINGS-theatres.md`, indexed in `CANDIDATES.md`, where three things it left are queued. The cached tags
> past slot 28 were not in the array's order, and a unit name is kept per country; with both corrected OpenHOI3's check
> agreed in all 108 of the start save's theatres.

The question, for OpenHOI3's stage 5: what the AI's theatres are, where they come from and when, and the headquarters
each is given - the start save holds every country's, so it is the check. **The next piece is the unit agents**
(`CAIUnit`): what moves the units and puts the history's top-level commands under a theatre.

---

## The AI strategy wave - who each country fears, courts, antagonises and protects

> **LANDED 2026-10-16.** Read by the collecting session alone, on the maintainer's word that day ("go ahead with it",
> the AI strategy before the military AI); two fragments merged (25 addresses new, 5 revised, 4 struct fields, and a
> correction moving one entry off its virtual address; apply `failed: 0`, `struct fields: 0`); the write-up is
> `findings/FINDINGS-aistrategy.md`, indexed in `CANDIDATES.md`, where three things it left are queued. Every country's
> strategy is rebuilt every ten days, not a handful of times a year; the base game's victory conditions antagonise the
> controllers of the provinces they name. A third fragment the same day read the walk's other twelve bodies and
> corrected `protect`'s cap to 6 and 12, both found by OpenHOI3's check against the start save, which then agreed in
> every list for all 78 countries.

The question, for OpenHOI3's stage 5: what fills `CAIStrategy`'s lists. OpenHOI3's foreign minister answered
`GetFriendliness`, `GetAntagonism`, `GetThreat` and `GetProtectionism` with 0, so no AI offered a NAP, a guarantee or an
alliance in 180 days. The start save holds every country's strategy, so it is the check.

---

## The foreign minister wave - the AI's decisions and its prepared wars, then the whole minister

> **LANDED 2026-10-16.** Read by the collecting session alone, on the maintainer's word that day ("continue with
> decisions"); two fragments merged (6 addresses new, 2 revised, 2 signatures placed whole; apply `failed: 0`,
> `struct fields: 0`); the write-up is `findings/FINDINGS-foreignminister.md`, indexed in `CANDIDATES.md`, where four
> things it left are queued. The decision score is rounded to the nearest, not cut; the readiness test a prepared war
> waits on counts the theatre layer's fronts.

> **Second pass LANDED the same day**, on the maintainer's word "Complete the foreign minister": every engine method
> `ForeignMinister_Tick` reaches that was unread - 14 addresses new and the constructor revised (`foreign-minister-api.json`;
> apply `failed: 0`, `struct fields: 0`); `FINDINGS-foreignminister.md` section I. The minister's skip-once byte is set by
> its constructor, so its first work does nothing.

The question, for OpenHOI3's stage 5: what the foreign minister's day does around `ExecuteDiploDecisions` - read
2026-10-12 (`FINDINGS-eventfire.md` 2.4) - and in particular the prepared wars four countries' scripts tie a decision to
(`PrepareWarDecision`): Germany's Danzig, Italy's Albania and Greece, Japan's Marco Polo Bridge.

---

## The ministers wave - research and production for the countries nobody plays

> **LANDED 2026-10-16.** Four briefs, merged (105 address entries, 91 landed; 8 structs declared, 59 fields; apply
> `failed: 0`, `struct fields: 0`); the write-up is `findings/FINDINGS-ministers.md` sections A to D, indexed in
> `CANDIDATES.md`, where seven things it left are queued. `ProductionMinister_Tick` runs every day, not on the 1st and
> the 15th; the `automate_*` keys are not delegation flags.

Planned 2026-10-16, for OpenHOI3's stage 5, the AI, on the maintainer's word that day ("go ahead with the next
step"): the tech and production ministers first, because OpenHOI3's headless run of 1936 to 1948 showed a world with no
research, no production and sliders frozen where a new game left them (`OpenHOI3/docs/mechanics/headless.md`). Both
ministers are the install's Lua - `TechMinister_Tick` in `script/ai_tech_minister.lua`, `ProductionMinister_Tick` and
`BalanceProductionSliders` in `script/ai_production_minister.lua`, with `ai_support_functions.lua` (`Support.CreateUnit`,
`Support.CalculateExpenseResourceFactor`), `utils.lua` and the countries' files under `script/country/` - so what is
needed from the executable is **what calls them, when, with what, and what each engine method they reach answers**, and
what the commands they post do. Four briefs; the write-up is **a new `findings/FINDINGS-ministers.md`**, sections A to D.

**What is known and is not to be redone** - cite it; re-read on the listing only to settle what follows, to raise an
`inferred` record or to correct one:

- `FINDINGS-ai.md`: the five ministers, `CEU3AI::CreateMinisters`, the hourly `ProcessAI` on TBB workers, the schedule -
  **tech at the hour `(id + 3) mod 24`, production at `(id + 5) mod 24`**; the tech minister's monthly re-plan
  (`0x8AECA0`, `0x8AEF40`, not read) and its two bytes `+0x5C`/`+0x5D` handed to `TechMinister_Tick`; the production
  minister's `0x899770(OwnerAI)` (not read), its gate (`+0x5C < 0` or day of month `% 14 == 0`) and the float
  `*0x4EE560(country) / 1000` (not read); `CAITechMinister::OnCountryEvent` (slot 47, `likely`, what it is not
  established). Records: `CAITechMinister::DoWork` (rva `0x4AEAD0`), `CAIProductionMinister::DoWork` (`0x4A22E0`),
  `Lua_TechMinister_Tick` (`0x4AF280`), `Lua_ProductionMinister_Tick` (`0x4A2B00`), `CAITechMinister::CAITechMinister`
  (`0x4AE7D0`), `LuaProxy_BalanceProductionSliders` (`0x110160`, `inferred`) and its `_Call` (`0x10D570`, `inferred`).
- `FINDINGS-luaapi.md` and `FINDINGS-luahost.md`: the bridge, a failed call, `CFixedPoint:Get()` in single precision,
  the iterators (storage order, stopping at the first null), equality, the per-thread state.
- `FINDINGS-government.md` section E and `FINDINGS-espionage.md` section E: how the politics and intelligence ministers
  were read - the pattern to follow.
- `FINDINGS-tradeaid.md`: `BalanceLendLeaseSliders` is called from the daily pass's cold block;
  `CChangeLendLeaseDistributionCommand::Execute`; `GetMaxLendLeaseFraction`.
- `FINDINGS-leadership.md` and the record: `CCountry::GetAllowedResearchSlots` (rva `0xE0170`, `confirmed`).
- `FINDINGS-buildqueue.md`, `FINDINGS-builders.md`, `FINDINGS-buildingqueue.md`, `FINDINGS-convoylines.md`,
  `FINDINGS-production.md`, `FINDINGS-ic.md`: the queue, a unit's and a building's price, `IsBuildingAllowed`,
  `CConstructBuildingCommand`, `CConstructConvoyCommand`, `CConstructUnitCommand` as the player's windows post them;
  `CountMaxUnitsStillBuildable` (`inferred`). `FINDINGS-techtooltip.md`: `CTechnology::CheckResearchAllowed`.
- `ghidra/luabind.json`: every Lua method's function and every constructor's signature, below by brief.

**What OpenHOI3 needs that is not settled**, by brief (rvas; the export's addresses are VAs, `+0x400000`):

| brief | what it settles | starting points (rva) |
| --- | --- | --- |
| **A. The tech minister** | **The exe's side**: `CAITechMinister::DoWork` re-read whole - the monthly re-plan `0x8AECA0` and `0x8AEF40` (what its two vectors hold, what reads them - do they decide anything, or only feed the Lua?), what `vbSliders` and `vbResearch` (`+0x5C`/`+0x5D`) are for a country nobody plays, slot 47 `OnCountryEvent` and the object `0x557E00` builds (a command? posted when?). **What the script reaches**: `CAITechMinister:CanResearch(tech)` (`0x4AF190`) against `CTechnology:CanResearch` (`0x135760`) and `CTechnologyStatus:CanResearch` (`0x133950`); `CCountry` `GetNumberOfCurrentResearch` (`0x4E81F0`), `GetCurrentResearch` (`0xE01F0`, which list, in which order), `GetTotalLeadership` (`0xF4E00`), `GetOfficerRatio` (`0x17C60`), `GetDiplomaticInfluence` (`0xF4E20`), `CalculateNumberOfActiveInfluences` (`0xFBEA0`, `likely`), `GetNumOfPorts` (`0xE2170`), `GetNumOfAirfields` (`0xE2180`), `GetTechnologyStatus` (`0x17BA0`); `CTechnologyDataBase` `GetTechnologies` (order), `GetTechnology(name)` (`0x4EA1D0`, an unknown name?), `GetLatestTechYear` (`0x4EA290`); `CTechnology:GetFolder` (`0xC8530`) and the folder's `GetKey`; `CTechnologyStatus` `GetLevel` (`0x133130`), `GetYear(tech, level)` (`0x133380`), `IsBuildingAvailable` (`0x133110`), `IsUnitAvailable` (`0x133020`); `CBuildingDataBase.GetBuilding(name)` (`0x4E9F80`). **The two commands**: `CStartResearchCommand(tag, tech)` - its constructor and `Execute`: where the technology goes in the queue, what it refuses (already queued, not allowed, a full queue?), whether it moves anything already there; `CChangeLeadershipCommand(tag, nco, diplomacy, espionage, research)` - the four floats' order against the four leadership shares, how a float becomes the share (rounding, the 15-bit kind), any normalising or clamping, and what of the player's own sliders it touches. **`math.random`** in the AI's Lua states: which `rand` it is (the CRT's, the game's?), its seeding, and whether each worker thread's state has its own | `0x4AEAD0`, `0x4AECA0`, `0x4AEF40`, `0x4AE9B0`, `0x157E00`, `0x4AF190`, `0x135760`, `0x133950`, the export's functions above, `luabind.json`'s `CStartResearchCommand` and `CChangeLeadershipCommand`; `FINDINGS-ai.md`, `FINDINGS-luahost.md`, `FINDINGS-leadership.md`, `FINDINGS-techtooltip.md`, `FINDINGS-research*`/`FINDINGS-techdecay.md` |
| **B. The production minister** | **The exe's side**: `CAIProductionMinister::DoWork` re-read whole - `0x899770(OwnerAI)` and what `0x4EE560` answers (VA; rva `0xEE560` is the export's `CCountry::CalcDesperation`, so the cached `+0x5C` is likely the country's desperation - settle it); **the daily `BalanceProductionSliders` call** from `RunCountryDailyPass` (`0xDC203`, `0xDC2EC`) and the two at VA `0x805BAA`/`0x805FBB`: for whom (nobody's country? the player's with automated sliders?), how often, and every argument - `prioSelection` (the `SLIDER_AUTOMATION_LEVEL`), the six values (the current shares, needs, as fractions?) and `bHasReinforceBonus`; **`CAI.FastNormalizeByPriority`** (`0x4E9250`) whole - the priority orders it walks, what it caps each share at, what `factor_left` is; **`CChangeInvestmentCommand(tag, lendlease, consumer, production, supply, reinforce, upgrade)`** - constructor and `Execute`: the floats into the shares, rounding, normalising; **`PrioritizeBuildQueue`** (`0x4A2720`) whole; `CountTransportsUnderConstruction` (`0x4A24D0`) and `CountEscortsUnderConstruction` (`0x4A25E0`). **What happens to an AI country's finished unit**: who places it, where, when (the deploy that the player does by hand) - and its finished building and convoys if anything differs from the player's | `0x4A22E0`, `0x499770`, `0xEE560`?, `0x110160`, `0x10D570`, `0xDC203`, `0xDC2EC`, `0x405BAA`, `0x405FBB`, `0x4E9250`, `0x4A2720`, `0x4A24D0`, `0x4A25E0`; `FINDINGS-ai.md`, `FINDINGS-tradeaid.md`, `FINDINGS-production.md`, `FINDINGS-buildqueue.md`, `FINDINGS-unitstart.md` |
| **C. The production script's units and constructions** | `CAI:GetProductionSubUnitCounts` (`0x4E8190`) and `GetDeployedSubUnitCounts` (`0x4E8180`): which arrays, filled where and when, what counts (brigades by type index? units waiting to be placed, aboard, in a theatre?); the `CArray*` classes' `GetAt`/`SetAt`/`GetSize` (index base, out of range); `CSubUnitDataBase.GetSubUnitList` (order), `CSubUnitDefinition` `GetIndex` (`0x6832A0`), `IsRegiment` (`0x62D10`), `IsCag` (`0xC8350`), `GetBuildCostMP`; `CCountry` `GetConstructions` (`0xF56B0`, order) with `CConstruction` `IsMilitary`, `GetMilitary`, `GetCost` (`0x837C0`: the line's whole cost, a day's?), `GetSize`, `CMilitaryConstruction` `IsLand`/`IsAir`/`IsNaval`/`GetBrigades`, `CBrigadeConstructionDefinition:GetType`; `GetICPart(ProductionCategory)` (`0x103D10`) and `CDistributionSetting`'s constants; `GetUsedIC` (`0xF4B60`); `HasExtraManpowerLeft` (`0x4E81E0`); `CountMaxUnitsStillBuildable` (`0xE13A0`, raise from `inferred`); `GetDissent` (`0xF8AE0`); `HasActiveLendLeaseToAnyone` (`0x1089A0`); `GetEscorts` (`0x17C30`), `GetTotalConvoyTransports` (`0x4E8200`), `GetTotalNeededConvoyTransports` (`0x4E8210`); `CalcDesperation` (`0xEE560`); **`CConstructUnitCommand(tag, list, province, count, reserve, CNullTag(), CID())`** - the Lua constructor and what the command then does with each argument (count as parallel lines or a serial run? reserve; the province not the country's; the two last), against the player's order (`FINDINGS-builders.md`); `SubUnitList()`/`Append`, `CID()`, `CNullTag()` | the export's functions above; `FINDINGS-builders.md`, `FINDINGS-buildqueue.md`, `FINDINGS-ic.md`, `FINDINGS-production.md`, `FINDINGS-tradeaid.md`, `FINDINGS-convoylines.md`, `FINDINGS-trade2.md` (which names the two `CAI` counts) |
| **D. The production script's provinces and buildings** | `CBuildingDataBase.GetBuilding(name)` (`0x4E9F80`; an unknown name - BlackICE's `infrastructure` against TFH's `infra`?), `CBuilding:GetIndex`; `CProvince` `GetBuilding(building)` (`0xA3B60`) with `CProvinceBuilding:GetMax` (`0x17A70`: built level or working level?), `HasBuilding` (`0xA3900`), `GetCurrentConstructionLevel` (`0xA3930`: levels under construction, whose?), `IsFrontProvince(bool)` (`0xA56B0`, recorded `CProvince::HasHostileLandNeighbour` `likely` - what the flag is), `GetController`, `GetOwner`; `CCountry` `GetControlledProvinces` (order), `GetTotalCoreBuildingLevels(index)` (`0xE21A0`), `GetRandomUnderGroundTarget` (`0x109920` - which generator, which provinces), `IsBuildingAllowed`, `GetBuildCost(building)`, `GetConvoyBuildCost`, `GetEscortBuildCost`; **`CConstructBuildingCommand(tag, building, province, count)`** - the Lua constructor and **`IsValid`**, what it tests, against the province view's order (`FINDINGS-buildingqueue.md`); **`CConstructConvoyCommand(tag, escort, count)`**'s Lua constructor (`FINDINGS-convoylines.md` has the command) | the export's functions above; `FINDINGS-buildingqueue.md`, `FINDINGS-provinceview.md`, `FINDINGS-convoylines.md`, `FINDINGS-undergrounds*`, `FINDINGS-occupation.md` |

**Measurable afterwards, by OpenHOI3**: the save of 20 April 1936 (`Germany1936_04_20_03.hoi3`) beside a new game run to
that hour - every AI country's research queue and technology levels, its six production shares and four leadership
shares, its build queue's lines by kind, its convoys - and the headless run's world no longer frozen.
