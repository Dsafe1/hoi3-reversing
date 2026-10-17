# The unit agents: the order of battle the AI builds under its theatres, and each theatre's plan

Read 2026-10-17 for OpenHOI3's stage 5 (the military AI's second piece) by five readers, A to E, collected by the
session that planned the wave (`WAVE.md`, "The agent wave"). Addresses are rvas unless marked VA. Read statically; the
oracle is one game of the maintainer's, `Germany1936_01_01_00.hoi3` (a new game after its two days and first hour) to
`_01_04_12`, `_01_07_14` and `_01_08_07`, Germany played and every other country the AI's. Builds on
`FINDINGS-aiunit.md`, `FINDINGS-aiplans.md`, `FINDINGS-aitheatre.md`, `FINDINGS-theatre2.md`, `FINDINGS-theatres.md`,
`FINDINGS-power.md` and `FINDINGS-reorganise.md`.

**In one paragraph.** A country the AI runs has **one unit agent per theatre and none below** (A). The agent is made with
the theatre, unbound. **The country's first AI pass** - which a single-player new game runs after its first hour - **sorts
its whole order of battle into the theatres its units stand in** (G), taking units out of commands that stand elsewhere;
the next binds each agent to its theatre's headquarters, which switches the headquarters' battle plan on, and once every
agent has posted its plan attaches what the sort left - units on another country's land - under a theatre. Once a day the
divisions are balanced between the country's theatres by need (F). Once a day each agent then **builds the order of battle
under its headquarters** (B): it wants `floor(n/4) + 1` commands over n units of the level below, makes them one a day
(corps, then armies, then army groups), and puts every division, corps and army under the nearest command one level up
with room for five. **Fleets and air units are regrouped** (C): a fleet over its caps sheds ships one at a time into new
one-ship fleets named `Nth Navy`, and small fleets and air groups are merged by `join_fleet` and `join_air` orders. **The
plan** carries a stance from a ratio of power (D) - 1 at peace with an ops area, 2 with none, 2 to 4 at war - the AI's
own power and the enemy's facing it, and objectives at 20 a victory point on a hot theatre; and **an ops area** (E) - the
provinces of its taken fronts that face hostile land in a real owner area - with a minimum of aircraft by type, and an
embark and a debark port for divisions going by sea. Checked against one game's saves: the ladder in all 99 AI theatres
with land units, Italy's fleets ship for ship, the stances of all 106 plans, 46 of 63 small powers exactly, and every ops
area of 106, province for province, on three dates.

**Corrections to the record this wave made** - each section has its own: the four `RADIO_*` reads are in
`AssignToNearestCommand`, not slot 85, and the AI never makes a theatre by `CCreateHigherCommand` (B; against
`FINDINGS-aiunit.md` and `FINDINGS-aitheatre.md`); `CCountry +0x570` is the strategy's own theatre list, saved, not a
second one (A.7); the readiness gate returns from `ProcessAI`; the tick's slot 78 condition was backwards;
`CEU3AI +0xA5`'s reader was a ship's `pride`; `CSendExpeditionCommand::Execute` is `0x1E9950`, not `0x1E9660` (C);
slot 78 walks the whole country and with `+0x364` clear commits (against `FINDINGS-power.md`); an objective's priority
**is** read, by slot 80 (against `FINDINGS-aiplans.md`); `UpdateUnitStances` ends at `0x491BD7` and `+0xA9`'s sense was
the other way round; the powers' gate is a whole number; `CCountry +0x4A8` is the strategy's `conquer_prov` (D);
`+0xA0` is the second ring, `+0xB0` a vector, `RebuildFocusOwnerAreas`' callee an rva (E); and `CAIUnit +0x364` is
`frontier_at_war`, not `manage_reserve` (`FINDINGS-opsarea.md` had read its writer).


## A. The AI's hourly pass and the agents' life

*Reader A.*

**In one paragraph.** Every game hour `ProcessAI` runs once a country on a TBB worker: the ministers tick, then the
country's unit agents (`CAIUnit`, **one per theatre and none below**) and its invasion agents, then helpers each at a
fixed hour of the day staggered by the country's id - `id % 24`, `(id+8) % 24`, `(id+16) % 24`. An agent is made on the
tick thread when the theatre layer makes its theatre, with no unit; the AI's own pass binds it to the theatre's
headquarters through `SetUnit`, which switches the headquarters' battle plan on, and once every agent of the country has
posted its plan, the same helper attaches any top-level unit with no theatre under one. An agent is removed when its
theatre goes, when its unit stops being a theatre's headquarters, or when its unit changes place in the order of battle.
**A single-player new game runs none of this during its two days and first hour.**

**Exe-hardcoded**: every stagger (0, 8, 16 and 0, 3, 6, 9), hour 1, the weekly test (day of the year % 7), the ninth-day
test, the day-of-month % 7 and hour % 3 tests, the 365-day year, the pride score, the scores of weak enemy ports (x 100 a
naval base, x 10 an air base, + 1000 a supply depot), the 2000 and 3000 cut-offs of distance at sea, and the ladder of
leader promotions. **Mod-able**: the unit types the helpers read - `can_be_pride`, `hull`, `transport_capability`, and the
cached keys `tactical_bomber`, `strategic_bomber`, `naval_bomber`, `transport_plane`, `paratrooper_brigade`. **None of
it reads `defines.lua` or Lua.**

### A.1 When `ProcessAI` runs

Four ways (`FINDINGS-ai.md`): `CGameState::RunAIPass`'s parallel loop once a game hour, from the frame after the hour
turns - the recurring one; `CInGameIdler::Enter`'s loop, gated on `gamestate +0xD9C` (`loaded_from_save`, VA
`0x661935`), so a loaded game only; a once-a-process kick in `CInGameIdler::Update`, gated on idler `+0x68` (multiplayer,
VA `0x65603A`); and idler slot 67. **So in a single-player new game nothing runs `ProcessAI` while `Enter` runs the two
days and the first hour**, though the `CEU3AI` objects exist then (`CGameState::StartAI` from the `CInGameIdler`
constructor, VA `0x64921B`). The first call comes from the first in-game frame, the clock still at hour 0 of 1 January -
inferred from `RunAIPass`'s only gate (`gamestate +0xC68`, which the first hour's `RunHourlyPass` leaves clear); the start
save, dated `1936.1.1.0`, is consistent with it.

### A.2 `ProcessAI` (`0x4894E0`), in order

1. Nothing while `ai +0x128` (`ai_paused`, the console's AI pause) or the country's `theatres_dirty` (`CCountry +0x580`)
   is set.
2. For the played country (`ai->id == gamestate->player`) `runs_units` (`+0x2C`) is cleared - its only writers in the AI
   code are this and the constructor.
3. `CEU3AI_RefreshUnitDestinations` (`0x49A800`): each unit's `+0x2CC` becomes the province at the end of its path, or 0.
   Then `AI_ManageUndergrounds`.
4. A country owning no province and not in exile: `CEU3AI_SendLandlessUnitsOnExpedition` (`0x499A10`), and the pass
   ends. Only in a real faction: every unit below theatre level is sent to a faction member other than itself and not in
   exile - a fleet or an air unit to the faction leader (the first member) alone, a land unit to the member controlling
   its province, or to the leader where that controller is outside the faction. Posted again every hour.
5. firstPass = `unit_pass_done` (`+0xA5`) clear; in a game loaded from a save, firstPass is false instead and
   `theatres_changed` (`+0xA6`) is cleared.
6. Every enabled minister ticks; the foreign minister answers its offers.
7. The played country with `automation[6] == 1`: `DeployFinishedUnits`, every hour.
8. The played country of a loaded game, with `runs_units` clear and no agents yet: `CreateAgentsForPlannedUnits`
   (`0x48BEF0`) - **never a country the AI runs**.
9. `CEU3AI_DisbandTheatrelessHQs` (`0x489BD0`): each level-0 unit that is no theatre's headquarters has its agent
   removed, and gets a `CDisbandCommand` where nobody plays the country or before `in_game`. A **true** answer (such a unit
   had an agent and children) **ends the pass**.
10. **The readiness gate** (`0x4897E8`): while `theatres_changed` is set, the strategy's theatres are walked; the first
    whose `unit` does not resolve sends the pass on to step 11, the flag staying set; when every one resolves (or there
    are none), `AnnounceLoadedUnitsToScreen(ai, isPlayer)` - **in fact `CEU3AI_SortUnitsIntoTheatres`, the sort of the whole order of battle into the theatres (section G)** -, the flag is cleared and **`ProcessAI` returns** - that hour no
    agent ticks and nothing below runs. The constructor seeds the flag to 1 (`+0xA4 = 0x10000`, VA `0x888130`), so
    every country's first pass ends here once its headquarters exist.
11. Every unit agent (`+0x40`) and every invasion agent (`+0x50`) ticks through slot 9 (`+0x30` decremented; at 0 slot 10,
    which is slot 73; `+0x30 = 1` again).
12. hour = `(tick - 43800000) % 24`. At hour 1 of a month's 1st, the failed-invasion areas (`+0x94`) are freed. At
    `id % 24`, `CEU3AI_AssignSeaTargetsToAgents` (`0x48C140`). Every hour, `CEU3AI_PruneInvasions` (`0x491BE0`) into a
    local list of areas already being invaded.
13. **The played country** (`runs_units` clear): on even hours, for each unit agent, `CEU3AI_RankInvasionAreas(ai,
    agent)` and `PlanAmphibiousInvasion(ai, list, agent)`. Nothing more; `unit_pass_done` is never set.
14. **Every other country**: `CEU3AI_RecallStrandedLandUnits` (`0x498870`) on the first pass or at `(id+16) % 24`;
    `CreateAgentsForTheatres` (`0x48AA80`) and `CEU3AI_BindAgentsAndAttachOrphans` (`0x48DCF0`) every hour; then at one
    of the three hours:

    | hour | in order |
    | --- | --- |
    | `id % 24` | `CEU3AI_ChoosePride` (`0x499C80`); `CEU3AI_BalanceDivisionsBetweenTheatres` (`0x48E490`, only once `unit_pass_done`); `RebuildPriorityProvinces` (`0x4976E0`); `RankInvasionAreas(ai, null)`; `CEU3AI_RebuildWeakEnemyPorts` (`0x4972E0`); `GenerateUnitObjectives` (`0x4980E0`); `PlanAmphibiousInvasion(ai, list, null)` |
    | `(id+8) % 24` | `CEU3AI_GatherTransportsForTheatres` (`0x490DB0`); `DeployFinishedUnits` (`0x48B300`); `AI_ReassignLeaders` (`0x498EF0`) |
    | `(id+16) % 24` | every agent's per-type tally (`CAIUnit +0x23C`) zeroed; `CEU3AI_DistributeFleetsToTheatres` (`0x48FBB0`); `CEU3AI_DistributeAirToTheatres` (`0x48F2B0`); `CEU3AI_PromoteLeadersForCommands` (`0x499280`) |

    then `UpdateUnitStances(ai, hour == (id+16) % 24)` (section D.2), and `unit_pass_done` = 1. `0x48DCF0`'s answer gates
    the first three hour calls, and it is **always false** (`xor al, al` at its one exit, VA `0x88E480`), so those gates
    always pass.

Read whole here: `0x49A800`, `0x499A10`, `0x48DCF0`, `0x499C80`, `0x499280`. Named by shape only, for the regrouping
(section C) and the third piece: `0x48E490`, `0x490DB0`, `0x48FBB0`, `0x48F2B0`, `0x48C140`, `0x491BE0`, `0x495530`,
`0x498870`, `0x4972E0` (Ghidra mislabels it a `CProvinceFloat` constructor), `PlanAmphibiousInvasion`,
`DeployFinishedUnits`, `AI_ReassignLeaders`.

### A.3 The agents' life

**Creation.** The `CAIUnit` constructor has four callers:

| path | where | thread | a country the AI runs? |
| --- | --- | --- | --- |
| `EnsureAgentForArea` (`0x48A880`) | `BuildTheatres`, `RefreshTheatreProvinces` | tick | **yes** - one agent a theatre, no unit, `area_dirty` = 1 |
| `CreateAgentsForTheatres` (`0x48AA80`) | `ProcessAI`, every hour | worker | yes - only for a theatre with no agent, bound at once |
| `CreateAgentsForPlannedUnits` (`0x48BEF0`) | `ProcessAI` | worker | no - the played country of a loaded save |
| `CreateUnitAgent` (`0x49A1B0`) | the objectives panel (`CObjectivesEntry` slot 22) | interface | no - the player's |

**`EnsureAgentForArea(ai, theatre, flag)`** - flag means "the theatre is going" - goes through the agents in order: with
flag clear, an agent whose unit has this theatre as its own but whose area id points elsewhere is pointed at it; the
agent covering the theatre (its area is this theatre, it has no unit or a level-0 one, and its area id is set) gets
`area_dirty` = 1 with flag clear, and slot 54 (plan off) and removal with flag set; every other agent gets slot 76
(`BuildPlan`) **where `runs_units` is clear**; and if no agent covers the theatre and `runs_units` is set, a new agent is
made - area id = the theatre, `area_dirty` = 1, enabled, **no unit**. Its callers: `BuildTheatres` for each old theatre
deleted (flag 1, VA `0x8ABAEF`) and each made or kept (flag 0, VA `0x8ABC38`); `RefreshTheatreProvinces` for a theatre
left with no provinces (flag 1, VA `0x8ABE8F`) and the others (flag 0, VA `0x8ABFAE`).

**`CreateAgentsForTheatres`** looks for an agent whose root (climbing `+0x40`) is a `CAIUnit` whose area resolves to the
theatre; finding none it makes one, enables it, and **binds it to the theatre's headquarters at once (slot 63)** where
the headquarters resolves.

**Binding**, slot 63, `SetUnit` (`0x4B9EB0`): false if already bound; otherwise any other agent in `unit +0x198` gets slot
64, `unit +0x198` = this, `+0x64` = unit, `SetArea`; **`CActivateUnitPlanCommand(unit, 1, plan +0x205)` is posted** - the
headquarters' plan switched on; then slot 78 and `UpdatePlanPower`; true. For the agents made in the first hour, the
binding is `CEU3AI_BindAgentsAndAttachOrphans`'s first step: each unit-less agent whose root's area resolves gets that
theatre's headquarters through slot 63.

**`CEU3AI_BindAgentsAndAttachOrphans` (`0x48DCF0`), after binding** - only once **every** agent of the country has
`stance_set` - walks the country's units in list order: a unit another country owns is unlinked from the list; a level-0
unit that is no theatre's headquarters loses its agent and, where nobody plays the country, gets a `CDisbandCommand`; a
unit of any other level with no agent and no parent - **a top-level orphan** - is attached by `CAttachUnitCommand` under
the headquarters of the theatre stamped on its province (`CMapProvince +0x380`) where that theatre and its headquarters
are ours and the headquarters is of a lower level (otherwise it is disbanded where nobody plays the country), and failing
such a theatre, under the unit of the agent nearest it (`CMap::DistanceBetweenProvinces`, from 1e7, the first of equals).

**Which agents exist after a new game's first hour**: **one per theatre, of every country with a `CEU3AI`, the played
country's included** - its `runs_units` is still 1 then, `ProcessAI` first running after the first hour - all enabled,
all with `area_dirty`, **none with a unit**. No agent exists for a unit below a theatre: slot 48 (`SetParent`) has no
caller in the AI code (`slotcalls 48`, 87 sites, the one in that range a false positive, a vector read at VA
`0x8B870F`), so every agent is a root. The played country's agents are never bound, only the AI branch binding; they
tick, but slots 82, 85 and the rest of the tick return at once without a unit.

**`CUnit +0x198`** holds the agent commanding *that* unit - a `CAIUnit`, or a `CAIInvasion` (whose `AddUnit` takes it).
For a country the AI runs that is only the theatre headquarters and units given to an invasion; a unit below a
headquarters holds null, and code finds its agent by climbing `+0x1E0` to the first unit that has one (the tick does
exactly this). Its writers: `SetUnit` and `CAIInvasion::AddUnit` set it; `CAIAgent`'s destructor (VA `0x89C81D`) zeroes
it on every unit of the country pointing at the dying agent; `CUnit_AttachToParent` and `CUnit_LeaveParent` remove the
unit's own agent and zero it; `CUnit_SetOwner` zeroes it **without telling the agent**; `CAIInvasion` slot 64. `ClearUnit`
does **not** clear it.

**What removes an agent** - `CEU3AI_RemoveAgent` (`0x499F70`): an agent with a parent is handed to the parent's slot 59;
otherwise it is unlinked from the unit-agent or invasion list and deleted - `~CAIUnit` (`ClearUnit` on its unit: AI
scratch cleared, AI parameter reset, **plan switched off**; then unsubscribed from the eight channels) and `CAIAgent`'s
destructor (`+0x198` zeroed). The cases: **its theatre goes** (`EnsureAgentForArea` with flag 1: an old theatre deleted
by `BuildTheatres`, or one left with no provinces by the refresh); **its unit is no longer a theatre's headquarters**
(`CEU3AI_DisbandTheatrelessHQs`, every hour and in `MaintainTheatres`, and `0x48DCF0`'s level-0 arm); **its unit changes
place in the order of battle** (`CUnit_AttachToParent`, `CUnit_LeaveParent` - so also when the unit is removed,
`CGameState::RemoveUnit` calling `LeaveParent`); **a planning agent retires the agents under its unit**
(`CEU3AI_RemoveAgentsUnderUnit`, `0x49A080`, slot 76's first act); a finished or unwanted invasion
(`CEU3AI_PruneInvasions`).

**`0x4AC390`** (`CAIStrategy_TellFriendsOfTheatres`, at the end of `BuildTheatres` and the refresh) calls
`CEU3AI_MarkAgentsNearTheatres` (`0x48C090`) once for each friendly country with an AI: each of that friend's agents
whose unit is level 0 gets `area_dirty` where any of our theatres connects to its theatre (`CTheatre_IsConnectedTo`, `0xB0710` - the record had the VA `0x4B0710`, section F.7: they share an
area, or our headquarters can reach theirs).

### A.4 `CEU3AI`'s fields

| offset | name | meaning |
| --- | --- | --- |
| `+0x2C` | `runs_units` | seeded 1; cleared by `ProcessAI` for the played country, so still 1 in a new game's first hour. Read by `ProcessAI` (which branch), `EnsureAgentForArea`, the tick's slot 80 gate, `UpdatePlanAxis`, slots 82 and 85, `SetArea` and the manage bodies |
| `+0x94` | `failed_invasion_areas` | areas where an invasion found nowhere to land (appended by `0x494C40` from `CAIInvasion` stage 3); `RankInvasionAreas` skips them; freed at hour 1 of each month's 1st |
| `+0xA5` | `unit_pass_done` | set at the end of every AI-branch pass; read only at VA `0x88961B` (first pass) and `0x889A82` (the balancer of divisions). The record's reader at `0x899CF2` is `CSubUnit +0xA5`, `pride` |
| `+0xA6` | `theatres_changed` | seeded 1; set by the theatre layer for a country nobody plays when a theatre is made or deleted; cleared by the readiness gate (that hour then ends) or by a loaded game's first pass |
| `+0x128` | `ai_paused` | the console command at VA `0x843720` ("AI Paused for all" / "AI is now Paused") |

`+0xC8` (the ranked invasion areas) and `+0xD8` (the weak enemy ports) are in the helpers' comments, not entered as
fields.

### A.5 `CAIUnit::Tick` (slot 73), settled on the listing

hour = `(tick - 43800000) % 24`; dayOfYear = `days - (int)((int)(days / 365.0) x 365.0)`; the staggers off the country
id at `CAIAgent +0x38` are A0 = `id % 24`, A3 = `(id+3) % 24`, A6 = `(id+6) % 24`, A9 = `(id+9) % 24`; **F (the full
pass)** = hour A6, or `full_pass_pending` (`+0x84`).

| # | when | call | section |
| --- | --- | --- | --- |
| 1 | `area_dirty` (`+0x87`), or hour 1 on a dayOfYear % 7 == 0 | `SetArea(this, GetArea())` | E |
| 2 | hour A0, or `stance_set` (`+0x80`) clear | `UpdatePlanAxis` `0x4C3330` | E |
| 3 | a land unit | objectives copied to `CArmy +0x2EC` | `FINDINGS-aiplans.md` |
| 4 | **every hour**, its flag hour A0 and dayOfYear % 9 == 0 | slot 82 | B |
| 5 | hour A3 | slot 85 | B |
| 6 | **no unit: return** | | |
| 7 | hour A9 | `RebuildFocusOwnerAreas` `0x4B0D20` | E |
| 8 | always | `+0x368 = 0x4DCAE0(this)` | E |
| 9 | `replan_subordinates` (`+0x86`), or hour A9, or F | slot 78 | C |
| 10 | always | `CAIUnit_UpdateThreatenedProvinces` `0x4B1820` | the third piece |
| 11 | F | slot 79 `ManageExpeditions` | C |
| 12 | F, or `air_target_lists_built` (`+0x83`) clear | `BuildAirTargetProvinceLists` | the third piece |
| 13 | `hold_provinces_built` (`+0x82`) clear, or `+0x1E4` > 0, or F and (day of month % 7 == 0 or `runs_units` clear) | slot 80 `RebuildHoldProvinces` | C |
| 14 | F, the unit at level 0, an area id set | the played country `ComputePlanForcesAndPower` `0x4B60F0`, any other `ComputePlanForces` `0x4B5210` | D, E |
| 15 | F, or (at war, in an undeclared war or with provinces in revolt, and hour % 3 == 0) | `0x4CC450`, `0x4D7F80`, `0x4CC690` (with the vector at `+0x10C` non-empty), `0x4CC020` | the third piece |
| 16 | F | `CAIUnit_PullHeadquartersIn` | B |
| 17 | this the nearest agent at or above its unit | `0x4C4370(this, hour == A6)`, posting `CSetPlanTransportStateCommand` | E |
| 18 | the same | `CAIUnit_ManageAirUnits(this, F)` | C, the third piece |
| 19 | the same | `CAIUnit_ManageNavalUnits(this, F or replan_naval)` | C, the third piece |
| 20 | every hour | `CAIUnit_MoveAgentUnitToCommandProvince` | B |
| 21 | as row 15 | `CAIUnit_ManageLandUnits` | the third piece |

The decompiled `goto`s around slot 80 resolve exactly as row 13; after it, the F path always goes on to row 15's land
block, and the war-and-hour test applies only when F is clear. **The record had row 9 backwards** ("slot 78 runs unless
`+0x86` is clear and the hour matches A9").

**The flag bytes**, seeded `+0x80` to `+0x88` as 0, 1, 0, 0, 1, 1, 1, 0, 1:

| byte | name | meaning |
| --- | --- | --- |
| `+0x80` | `stance_set` | set by `UpdatePlanAxis` (a bound agent of an AI-run country) and by `SetPlanStance` - "the plan posted once", not "a stance chosen"; also gates `0x48DCF0`'s orphan pass |
| `+0x81` | - | seeded 1; **no access anywhere in VA `0x880000`-`0x8EA000` at any size** (the control: `+0x82` is found in the same scan) |
| `+0x82` | `hold_provinces_built` | set by slot 80, cleared by `SetArea` |
| `+0x83` | `air_target_lists_built` | set by `BuildAirTargetProvinceLists`; never cleared |
| `+0x84` | `full_pass_pending` | set by `SetArea` and `0x4D7F80`; cleared by `0x4CC450`, the land block's first call, which every full pass reaches |
| `+0x85` | `replan_naval` | set by `0x4D3EB0`, reached from observer slot 72 when a foreign unit carrying troops is announced; cleared by the forced naval pass |
| `+0x86` | `replan_subordinates` | set by `SetPlanStance`, the fleet and transport regroupers (on both agents of a unit they move), `CreateUnitOrder`'s invasion order, and `CUnit_AttachToParent`/`CUnit_LeaveParent`; cleared by slot 78 |
| `+0x87` | `area_dirty` | set by `EnsureAgentForArea`, `MarkAgentsNearTheatres` and `MaintainTheatres` (VA `0x8AC624`, making a unit a theatre's headquarters); cleared by `SetArea` before its guards |
| `+0x88` | `regroup_air_pending` | `ManageAirUnits` only |

### A.6 A new game, hour by hour, against the saves

- **The first hour, inside `Enter`, on the tick thread**: every theatre is built and every theatre of every country gets
  an agent with no unit; headquarters are adopted or made at once (`CCreateNewHQCommand`); `DisbandTheatrelessHQs` posts
  disbands, the game not yet `in_game`; `theatres_changed` is set for every country nobody plays.
- **The first frame, hour 0** (inferred, A.1): the first `ProcessAI`. The played country's `runs_units` is cleared; every
  country reaches the readiness gate, finds its headquarters, **sorts its units into its theatres (section G)** and returns. **The start save `_01_01_00` has no `plan`
  block at all** - no agent bound - and has 108 theatres (Germany's 2) and only four top-level units that are not
  theatres: the USA's Asiatic Fleet and 2nd USN Submarine Fleet, and two Japanese air units.
- **Hour 1**: agents tick without units (`SetArea` clears `area_dirty`; the rest returns). The AI branch's first pass:
  `RecallStrandedLandUnits`, then `0x48DCF0` binds every AI agent to its headquarters, **posting
  `CActivateUnitPlanCommand`**. `UpdateUnitStances` normally does nothing yet (`+0xA9` clear and the call unforced).
- **Hour 2**: each bound agent's tick posts its axis (`stance_set` = 1) and runs a full pass (`full_pass_pending` seeded
  1); the AI branch the same hour finds every agent posted and **attaches the orphans**. In `_01_04_12` the two American
  fleets are under *Pacific Theater*, one Japanese air unit under *Kwantung Army Theater*, the other gone; **106 theatre
  headquarters carry a `plan` block - all but Germany's two**, the played country's agents never being bound.

From then on each daily stagger runs once a day.

### A.7 Corrections to the record

| record | read |
| --- | --- |
| `CCountry +0x570` `oob_theatres_*`, "a different set from `CAIStrategy +0xE4`, neither saved nor loaded" (`FINDINGS-aitheatre.md` section 2) | it **is** that list, `+0x48C + 0xE4`; `CCreateHigherCommand` appends to the strategy's saved list |
| the readiness gate "clears `+0xA6`" | and **returns**: that hour ticks no agent |
| the tick: "slot 78 runs unless `+0x86` is clear and the hour matches A9" | it runs when `+0x86` is set, at A9, or on the full pass |
| `CEU3AI +0xA5` read at VA `0x899CF2` | that is `CSubUnit +0xA5` (`pride`) |
| `DisbandTheatrelessHQs` "called by `MaintainTheatres`" | also by `ProcessAI` every hour, a true answer ending the pass |
| `stance_set`, "a stance was chosen" | `UpdatePlanAxis` sets it too |
| `CreateAgentsForTheatres`: no binding | binds the new agent through slot 63 |
| `ClearUnit` likely | read whole; it leaves `CUnit +0x198` |
| `FINDINGS-theatres.md` section O: what puts the history's top-level units under a theatre | `CEU3AI_BindAgentsAndAttachOrphans`, and the headquarters command's orphan rule (section K) |

### A.8 What looks wrong and is what the bytes do

1. `CEU3AI_BindAgentsAndAttachOrphans` always answers false, so `ProcessAI`'s three gates on its answer are dead.
2. The hour the readiness gate clears `theatres_changed` runs no agent and no AI branch for that country.
3. In a new game the played country's theatres get agents (its `runs_units` still 1 in the first hour) that are never
   bound.
4. With `runs_units` clear, `EnsureAgentForArea` calls slot 76 on every agent that does not cover the theatre.
5. The orphan attach waits for **every** agent to have posted its plan, so a theatre left without a headquarters would
   block it for that country (inferred from the gate).
6. `CUnit_SetOwner` zeroes `+0x198` while the agent keeps `+0x64`; `ClearUnit` clears the agent's side and not the
   unit's.
7. `SendLandlessUnitsOnExpedition` posts its commands again every hour.
8. The played country uses `ComputePlanForcesAndPower`, everyone else `ComputePlanForces`.
9. `+0x81` is seeded 1 and read by nothing.
10. Pride is chosen by hull through a float round trip (`/1000 x 1000`), plus `extra_consumption`.

### A.9 Not settled

- That the first `ProcessAI` runs on the first frame, paused, at hour 0 - inferred from `RunAIPass`'s single gate; the
  start save is consistent with it and does not show it.
- `FINDINGS-aiconsumer.md`'s live census found 112 unbound agents (one per theatre fits), **no agent for the played
  Ireland**, and `runs_units` clear on 3 of 110 countries; this reading predicts Ireland's agents in a new game and one
  clear `runs_units`. What kind of session that census was is not recorded. The cheapest check: at a new game's first
  screen, count the `CAIUnit`s whose `+0x38` is the player's id.
- What `CAIUnit +0x23C` tallies, and `0x490DB0`'s `+0x58` gate; whether `CAIUnit +0x3D`/`+0x3E` (`SetUnit`'s guard) are
  ever set; the insides of `0x48E490`, `0x490DB0`, `0x48FBB0`, `0x48F2B0`, `0x48C140` and `0x495530`; when the disbands
  posted in the first hour execute.


## B. Higher commands made: corps, armies and army groups

*Reader B.*

**In one paragraph.** Once a day, at hour `(country id + 3) % 24`, each unit agent of an AI country reorganises the land
units under its theatre headquarters. **First it makes commands**: for divisions, then corps, then armies, it wants
`floor(n/4) + 1` commands of the next level up, and makes them one at a time, each over the shallowest unit of the level
below, by `CCreateHigherCommand`. Because a command is posted and not run at once, **the ladder grows one level a day** -
corps on the first pass, armies on the second, army groups on the third. **Then it fills them**: garrisons and fleets go
straight under the theatre headquarters, and every division, corps and army is kept under, or moved to, the nearest
command of the level above with room - room being five subordinates, counting those posted in this pass, and "nearest"
counting any distance beyond the command's radio reach. **Each new headquarters** is a `CArmy` one level above the unit
it was made over, standing where that unit stands, with one `hq_brigade` at a twentieth of its strength, the country's
next `<n>th Army Group`, `Army` or `Corps` name and a leader. **A headquarters is then walked about**: a theatre
headquarters towards the province `CTheatre_PickHQProvince` prefers, any lower one towards the middle of its subordinates
when one drifts out of full reach.

**Exe-hardcoded**: the `/4` and `+1` of the need, the cap of five, 0.85 for the current parent, the twentieth of strength
and of the manpower charge, `GetWantedCommandLevel`'s thresholds (5, 10, 30), every weight of the province choices
(100000, 0.5, 0.01, 15, 6, 1000, 100000, the floor of 200), and the stop at army groups. **Mod-able**:
`RADIO_THEATHRE_`, `RADIO_ARMYGROUP_`, `RADIO_ARMY_` and `RADIO_CORPS_LEADER_DISTANCE` in `defines.lua`; each type's
`radio_strength`; the `hq_brigade` type (`max_strength`, `build_cost_manpower`) and the `garrison_brigade` type, both
matched by key; the technologies' `build_cost_mp` modifiers; localisation `ARMYGROUP_NAME`, `ARMY_NAME`, `CORPS_NAME`,
`REGIMENT_NAME`, `ST`/`ND`/`RD`/`TH`, `hq_brigade_short`; the country's `auto_assign_leaders`.

### B.1 When (`CAIUnit::Tick`)

Slot 85 (`OrganiseCommands`) runs once a game day at hour `(id + 3) % 24`. Slot 82 (`MaybeSetCommandLevel`) runs every
hour, its `force` set at hour `id % 24` on days of the year divisible by 9. `CAIUnit_PullHeadquartersIn` runs at hour
`(id + 6) % 24`, or while `+0x84` is set; `CAIUnit_MoveAgentUnitToCommandProvince` every hour.

### B.2 Slot 85, `CAIUnit::OrganiseCommands` (`0x4C20C0`)

Nothing unless the agent has a unit (`+0x64`) and an area (a `CTheatre`). **reorg** = the owner's AI runs units
(`CEU3AI +0x2C`, set for every AI country) or the unit's plan allows headquarters reorganisation (`CUnit +0x205`,
`CUnitPlan +0x9`); for the played country only the second can hold.

1. With reorg, `CAIUnit_CreateHigherCommands` (B.3).
2. Over the subtree's land units (`+0x11C`, filled by slot 78, section C.6): each one's `CUnit +0x2C4` (pending
   subordinates) is zeroed; the agent's own unit, any unit carried by a fleet (`CArmy +0x300`) and any unit slot 86
   answers true for are skipped; the rest are sorted by oob level - 1 army groups, 2 armies, 3 corps, any other level
   **garrisons** if the first brigade is the `garrison_brigade` type and **divisions** otherwise.
3. With reorg: every garrison whose parent is not the agent's unit gets `CAttachUnitCommand(garrison, theatre HQ)` - the
   old parent's `+0x2C4` down one, the headquarters' up one; and every fleet of the subtree (`+0xDC`) whose parent is not
   the headquarters is attached under it.
4. `AssignToNearestCommand` three times: divisions to corps, corps to armies, armies to army groups (B.4).

**The four `RADIO_*` reads are not in slot 85's body** (`FINDINGS-aiunit.md` put them there): they are in
`AssignToNearestCommand`.

### B.3 Making commands (`CAIUnit_CreateHigherCommands`, `0x4C2CD0`)

1. Nothing unless the country's manpower is at least the `hq_brigade` type's `build_cost_manpower`.
2. `counts[level]` = the subtree's land units by oob level, **leaving out units whose first brigade is a garrison
   brigade**; a unit with no brigade counts.
3. For L = 4, 3, 2: need = `counts[L] / 4 + 1` (integer division). While `counts[L-1]` < need:
   - **Borrow** (an AI country only, `CEU3AI +0x2C`): over the country's other agents (`CEU3AI +0x40`) and each one's
     non-division units (`+0x14C`), a unit qualifies that is at level L-1, has no children, has `+0x2C4` <= 0, stands in a
     real owner area, was not taken already this round, and can reach the agent's unit's province through owner areas
     no enemy holds (`CCountry_ProvincesConnectedByArea(country, its province, HQ province, true)`, `0xEFB40`). Each
     adds one to `counts[L-1]` and gets `CAttachUnitCommand(it, theatre HQ)`. The need is tested between agents, not
     between units; met, the next L.
   - **Make** otherwise: of the `+0x11C` units of level L that are not garrison-led, not chosen already for this L, and
     stand on a land province, the one with **the fewest ancestors**, the first in the vector of equals; post
     `CCreateHigherCommand(that unit)` and add one to `counts[L-1]`. With no such unit, the next L.
4. L stops at 2, so **the AI never makes a theatre here**. Corps posted at L = 4 count towards the armies needed at L = 3
   but cannot be chosen until they exist - hence a level a day.

### B.4 Filling commands (`CAIUnit::AssignToNearestCommand`, `0x4C2770`)

`reach(H)` = 0 if H has no brigade, else its first brigade's `radio_strength` x `RADIO_<level>_LEADER_DISTANCE` / 1000,
for levels 0 to 3, then / 1000. `dist` is `CMap::DistanceBetweenProvinces`. For each unit U, with parent P:

1. Skipped if U's `CArmy +0x2E8` (`target`) > 0, or P's is.
2. over = -1000; with a parent, over = `(dist(U's destination-or-province, P's destination-or-province) - reach(P)) x 1000`.
3. If P is exactly one level above U: skipped unless reorg; skipped if U has a blocking order; otherwise, if P has a
   blocking order or over <= 0, **U is kept** while `P.+0x2C4` + P's children of U's level <= 4, and else goes on to step
   4; U beyond P's reach goes on to step 4. P at another level: skipped unless reorg, then step 4. No P: step 4 whatever.
4. For each candidate command K in turn: n = `K.+0x2C4 + 1 +` K's children of the level below. K is eligible at n <= 4;
   at n = 5 only if (over > 0 and `U.+0x2C9` is clear) or K is P. Score = `(float)dist(U's province, K's province)`, plus
   K's own over / 1000 if positive, **x 0.85 if K is P**. The lowest below 1,000,000 wins, strictly - the first of equals.
5. A winner other than P: P's `+0x2C4` down one, the winner's up one, and `CAttachUnitCommand(U, winner)` posted.

### B.5 The commands

**`CCreateHigherCommand`'s constructor (`0x1DF320`)** takes one unit and reserves the new headquarters' id under a spin
lock: type `0x1268 + word[VA 0x1A857EC]` (4713), serial = the persistent-id counter (VA `0x1A857F8`) + 1, and the
counter then moves on **by three** - the headquarters, its brigade at serial + 1, and one left unused.

**`IsValid` (`0x1E07D0`)**: every unit named exists at level >= 1, and the first unit's owner has manpower >=
`floor((n + 0.0005) x 1000) x hq build_cost_manpower / 1000`.

**`Execute` (`0x1DF600`)**:

1. top = the named unit of the lowest level, the first of equals; none, or level < 1, logs `Failed to create higher
   command` and stops.
2. place = top's province; at sea with top a carried land unit, the carrying fleet's home base province; still not land,
   it logs `...on the naval base` and stops.
3. A **`CArmy` at level top - 1** with the reserved id and top's owner.
4. **One `hq_brigade`** (id serial + 1): home = place; **strength = max x 1000 / 20000** (a twentieth, at least 0), the
   highest strength raised to match; no experience; the owner charged `(1000 + the technologies' build_cost_mp modifier,
   at least 50) x build_cost_manpower / 1000 x 1000 / 20000` manpower, floored at 0; named by `REGIMENT_NAME`, its
   technologies applied.
5. The parent: X = top's parent, or its grandparent where the parent is already at the new level; if X ranks above the
   new headquarters, the headquarters goes under X. Then top leaves its parent and goes under the new headquarters, and
   every other named unit `CUnit_MayTakeSubordinate` accepts follows.
6. It enters place. At level 0, `CUnit_MakeName` with the province, and a new `CTheatre` (the theatre counter, then + 1)
   whose unit it is, appended to `CCountry +0x570`; otherwise `CUnit_MakeName` with no province - `<n><st|nd|rd|th> Army
   Group`, `Army` or `Corps`, numbered per country.
7. `AssignBestLeader` if the country assigns leaders itself, `CheckForCombat`, and the "unit created" broadcast (land on
   channel 6, and channel 0).

**`CAttachUnitCommand`**: `IsValid` (`0x1DF130`) - both exist and the parent's level < the unit's. `Execute`
(`0x1DE940`) - `CUnit_AttachToParent`, which needs the same owner and the parent ranking above, leaves the old parent
and appends the unit last; **no cap on subordinates**; for the player's own unit, the `ATTACHEDUNIT` message.

**`CSetCommandLevel`**: `IsValid` (`0x1E1BF0`) - land needs level < 5, a navy exactly 5, an air unit exactly 6.
`Execute` (`0x1E1920`) - oob level = level, renamed by `CUnit_MakeName(owner, province)`; nothing else.

### B.6 Slot 82, and the level wanted

`GetWantedCommandLevel` (`0x4BA550`) takes n = the active plan's ops-area count, else the theatre's province count, and
answers 3 for n <= 5, 2 for 6 to 10, 1 for 11 to 29, 0 for 30 and more, and 3 with no area. Slot 82 works only on a land
unit with children: (1) with no parent agent, wanted < the unit's level and `CEU3AI +0x2C` set, it posts
`CSetCommandLevel(unit, wanted)` - it only promotes, and an AI theatre agent's unit is already level 0, so **for the AI it
never fires**; (2) if `+0x54` is null, or `force`, or the unit stands on a front province, `+0x54 =
CAIUnit_PickCommandProvince(agent, level)`.

### B.7 Where a headquarters stands

**`CAIUnit_PickCommandProvince` (`0x4DA340`)**: at level 0 with an area, `CTheatre_PickHQProvince`; at other levels with
an area the candidates are the theatre's provinces; with none, the owner area of the plan's first ops-area province, or
with no ops area, the second chooser below. Each candidate P is scored, the highest winning, strictly, from -1 - and only
when the agent's own ops area (`+0x90`) is non-empty: P is skipped if its mean distance to the ops area is 0; the score
starts at `100000 / mean`; halved if P is beside the ops area (for an army or a corps the test is reversed: halved if
**not** beside it); halved again if P borders another holder's land; x 0.01 if P is in the ops area; x `(1 - a/15)`
where a = friendly land units in or heading into P (`CAIUnit_CountFriendlyLandUnitsAt`, `0x4DA180`); x 0.01 if its
`ai_front_value` < 200. `CAIUnit_MoveAgentUnitToCommandProvince` marches the theatre headquarters there every hour.

**`CAIUnit_PickProvinceAmongSubordinates` (`0x4DA660`)**: the candidates are each land child's destination-or-province
(where reachable from where the headquarters is going or stands, through owner areas no enemy holds) and every land
neighbour of it in the same area; the score is the mean distance to the children, skipped at 0, -6 for the
headquarters' own start province, +1000 bordering foreign land, +100000 with `ai_front_value` < 200; the lowest below
100000 wins. **`CAIUnit_PullHeadquartersIn`** applies it every day to each non-division headquarters of the subtree -
always to one that is moving (the record said only one with no destination), and to one standing still only if a child
is under full command reach (< 1000), or the headquarters is trespassing, or it stands on a front province while `+0x364`
is set.

### B.8 Against the saves, `_01_01_00` to `_01_04_12`

**The counts**, keyed by the whole id (id and type): **382 new units** - 93 army groups under theatres, 96 armies under
army groups and 1 under a theatre, 89 corps under armies, 87 navies and 16 air units - and **44 gone**, 31 navies and 13
air units, and 599 changes of parent. (`WAVE.md`'s 285, 40 and 661 and its "4 corps under navies" came from keying units
by id alone, where serials of type 41 and type 4713 collide.)

**The ladder.** All 99 AI theatres with land units end with at least `floor(divisions/4)+1` corps, `floor(corps/4)+1`
armies and `floor(armies/4)+1` army groups; only Germany's two, played, fall short. 88 of the 99 equal `max(what they had,
the need)` exactly; the other 11 had divisions move between theatres in those days and still meet it. Japan's Kwantung
starts with 27 divisions, no corps, 9 armies and an army group and ends with 7 corps, 9 armies and 3 army groups; the
Imperial GHQ (9 divisions, 6 armies) gains 3 corps and 2 army groups. Every Soviet theatre meets the rule: STAVKA, with
12 divisions, 5 corps, 2 armies and 2 army groups, needs 4, 2 and 1.

**The new headquarters**, all 279: each has an `hq_brigade` at serial = the headquarters' + 1, type 4713; the newest are
at strength 0.500 of 10 with no experience; 273 have a leader; 226 of 275 stand where their first child stands; the first
child is always one level below. **The ids show a level a day**: Ecuador's corps is 371, its army 2170, its army group
2447. Prussia's army 527 came in the same pass as its corps 524 (525 the brigade, 526 unused), made over a corps of the
history. **No AI command has more than five children of the next level**; 4 of 605 have exactly five.

### B.9 What looks wrong and is what the bytes do

1. A command with five children of the next level fails the "keep" test (more than 4), so a unit posted to it moves on if
   another has room; at five the current parent itself scores n = 6 and is ineligible.
2. Borrowing scans again on every turn of the while loop, so units borrowed already are counted, and their attach
   posted, again while the need is unmet.
3. `IsValid` asks for n `hq_brigade`s' worth of manpower; `Execute` charges a twentieth of one.
4. Three ids are reserved a command and two used, reserved as it is posted, so a refused command wastes them.
5. A new AI headquarters starts at a twentieth of its strength with no experience; a new theatre headquarters
   (`CCreateNewHQCommand`, `FINDINGS-theatres.md` K) at a fifth with the starting experience.
6. A candidate where all of a headquarters' children stand (mean distance 0) is skipped by both choosers, so a
   headquarters never walks onto its subordinates' shared province.
7. `AssignToNearestCommand` scores by current provinces but measures reach from destinations.
8. Garrisons are known by their first brigade only.
9. Slot 82's promotion is dead for AI theatre agents.
10. A level-0 `CCreateHigherCommand` (the player's only) makes a `CTheatre` with no provinces.

### B.10 Not settled

- The order of slot 78's `+0x11C` vector, which decides the first of equals among the shallowest units.
- Which orders kinds `0x4E5` and `0x56C` are; the order of `CAIUnit_CountFriendlyLandUnitsAt`'s second loop's tests.
- Where the brigades' experience of 0.16 and 0.317 by day three comes from - not these bodies.
- The one army under a theatre, not traced. No save keeps `+0x54`, so the choosers of a province are read, not checked.
- `CAIUnit +0xB0`'s "order" record rests on the `UnitHasBlockingOrder` misattribution and wants another look.

## C. Subordinates moved between commands, and fleets and air units regrouped

*Reader C. The install's `hoi3_tfh.exe` and the unpatched `hoi3_tfh_imperium.exe` agree byte for byte over every
function read here (trap 19); BiceLib's `InterAiExpeditionaries` patch on slot 79 is in memory only.*

### C.1 Who regroups, in one paragraph

Neither slot 78 nor slot 79 regroups anything. Fleets and air units are regrouped by two callees of `CAIUnit::Tick`,
`CAIUnit_ManageNavalUnits` (`0x4D0880`) and `CAIUnit_ManageAirUnits` (`0x4CD890`), which the tick calls only for the
topmost agent of a unit chain (`0x4B0C3D`) - the theatre's. They act two ways:

- **Split.** For one ship or wing they post `CCreateUnitCommand` for a new empty unit (`PostCreateUnitCommand`,
  `0x4BEAD0`), then `CTransferSubUnitCommand` moving that ship or wing into it - **one new unit per ship**. The three
  transfer sites are VA `0x8CE90E` (air, inside `0x4CD890`) and VA `0x8D1341` and `0x8D1BEB` (naval, inside `0x4D0880`).
- **Merge.** They give a small unit a `join_fleet` or `join_air` order. The merge happens on arrival, inside the order's
  `IsActive` - `CJoinFleetOrder::IsActive` (`0x19BC40`), `CJoinAirOrder::IsActive` (`0x197BB0`) - which call
  `CUnit_MergeInto(target, mover)`: **the mover disappears and the target keeps its name and id.**

`PostCreateUnitCommand` writes the new id onto the agent's requested-units list (`CAIUnit +0x1EC`). When the unit is
made, the observer slot 17/18/19 (`0x4D5320`) finds it there and posts `CAttachUnitCommand(new unit, agent->unit)` -
which is why the 63 new navies and 14 new air units hang under theatre headquarters. Nothing here uses `CMergeCommand`.

### C.2 When they run

- **Air.** `ManageAirUnits` runs every hour for an agent holding air units (`+0x104 >= 1`); its regroup phase runs when
  `+0x88` is set (a split or merge happened last time) or when the tick's daily flag is passed as `force`.
- **Naval.** `ManageNavalUnits` runs when `force` is set (the daily flag, or `+0x85`, seeded 1), or when the country is
  at war or `+0xACD` is set.
- **The daily flag** is `hour == (id+6) % 24`, or `CAIUnit +0x84`, which the constructor seeds to 1; `+0x84` is cleared by
  `0x4CC450` (reader A's) and set again from `0x4BBA17` and `0x4D8505`.
- Splits happen only to units **at their own base with no busy or blocking order**, and merges send units sailing, so the
  regrouping converges over a few days - 661 changes of parent in the first three and a half days, 13 in the next three.

### C.3 Fleets: `CAIUnit_ManageNavalUnits` (`0x4D0880`)

`mayReorganise` = the owner AI runs this country's units (`CEU3AI +0x2C`), or the theatre unit's plan has
`allow_hq_reorg` (`CUnit +0x205`).

**1. Port phase (VA `0x8D0C2D`-`0x8D1496`), per fleet in `+0xDC`.** A fleet with no ship, no base, or retreating is
skipped.

- *needsPort* (`CUnit_FleetNeedsPort`, `0x4B16F0`): any transport below 0.5 strength, or any other ship below 0.75
  strength or below 0.5 organisation.
- *Damaged*: a transport below 0.5 strength, or any other ship below 0.9 strength (the double `0x3FECCCCCC0000000`).
- *Resting*: any non-transport below 0.9 organisation.
- **If needsPort, the fleet has a base, is not at its own base and carries nothing (`CNavy +0x2EC <= 0`), it is sent to
  the nearest port.** The candidates are every port (`COwnerArea +0x48`, largest first) of every area on the country's
  list (`CCountry +0xD30`); the distance is `NavalDistanceTo(fleet province, port) / 1000`, truncated, the current
  base's multiplied by 0.75 and truncated; the best starts at 1,000,000 and is the minimum by strict `<` (first of
  equals). The port must also pass `0xD52A0(country, fleet province, port, 0)`, true at peace (its war branch not read).
  If the best port is the current base: a busy order is cancelled (`IssueUnitOrder none`), and a fleet not fighting is
  moved home (`MoveUnit`). Otherwise it is ordered to `rebase` (`0x6DE`) to the best port.
- **Else, if a ship is damaged or resting and the fleet has no busy order, is not blocked and is at its own base**:
  nothing more unless mayReorganise; then if `0 < damaged < ships` and the fleet is not fighting, one new fleet (kind 1)
  in the fleet's province, based at its base, and a `CTransferSubUnitCommand` for each damaged ship (VA `0x8D12EA`,
  `0x8D1341`). Either way the fleet sits out this pass.
- **Every other fleet is "ready"**, kept in a vector in `+0xDC` order - damaged ones that are busy or away from base
  among them.

**2. Split and merge (VA `0x8D19F6`-`0x8D2025`)**, only if mayReorganise, per ready fleet that is not retreating, not
fighting, has ships, has not been handled this pass, has no busy order (order slot 24), is not blocked and is at its own
base. Ships are counted by `CountShipsByRole`:

| role | what counts | unit-file key |
| --- | --- | --- |
| capital | battleship, battlecruiser, heavy cruiser, carrier, escort carrier, super-heavy battleship | `capital = yes` |
| transport | transport ships | `transport = yes` |
| sub | submarines | `is_sub = yes` |
| carrier | `carrier_size > 0` and not capital - none in TFH | `carrier_size` |
| screen | everything else (light cruiser, destroyer) | - |

**Split**: the ships are walked **in list order** and one is detached when:

| ship | detached when |
| --- | --- |
| capital | capitals > 4 |
| transport, the theatre unit's `+0x284` zero | transports > 4, or the fleet holds any capital or carrier |
| transport, `+0x284` set | screens > 4 (it falls to the screen test) |
| sub | subs > 3, or the fleet holds any non-sub (that count taken once and never decremented) |
| screen or carrier | screens > 4 |

Each detached ship gets a fresh id (type `word[0x1A857EC] + 0x1268`, serial `++[0x1A857F8]`), then
`CCreateUnitCommand(kind 1, the fleet's province, the fleet's base)` and `CTransferSubUnitCommand(id, ship)` (VA
`0x8D1BA4`, `0x8D1BEB`), and its role's count is decremented. **So each surplus ship becomes a one-ship fleet of its
own, the earliest in the list first, and the fleet keeps its last four of a kind.**

**Merge**: a fleet with **no transports and fewer than 6 ships** takes the **first** partner in ready-vector order that
is not itself and not already handled. Over the two fleets' summed counts the partner is rejected when:

- **subs**: there are subs and either fleet holds a non-sub, or the two first ships' definitions differ in `range`
  (`+0x148`), or subs > 3;
- **capitals**: capitals + carriers > 3 while this fleet itself has any;
- **screens alone**: there are screens but no transport, capital or carrier;
- **transports**: there are transports together with any capital or carrier;
- **too many screens**: screens > 3;
- **unreachable**: this fleet cannot reach the partner's province (`CMapProvince::CanUnitReach`).

On acceptance, `CreateUnitOrder(ai, join_fleet, this fleet, partner's province, ..., partner's id)` (VA `0x8D1FCB`), and
both fleets are marked handled: **the small fleet sails to the partner and vanishes into it.**

**3. Merging for battle.** At war, or with `+0x28C > 0`, and a naval stance other than 0, the intercept phase (VA
`0x8D3800`-`0x8D3DC4`) gives the first chosen fleet `intercept` and the others `join_fleet` onto it until the gathered
power covers the enemy - mapped from the decompilation, not read; the third piece's.

### C.4 Air units: `CAIUnit_ManageAirUnits` phase 3 (VA `0x8CE64F`-`0x8CED97`)

The gate and the split rules are as `FINDINGS-reorganise.md` gives them. Added here: **skipped** are a group holding a
CAG, a group of one wing, a group on loan (`CUnit +0x290 != 0`) and a group with no base; **split**: each wing breaking
the rule gets a new air unit (kind 2) in the group's province, based at its base (VA `0x8CE8D3`, `0x8CE90E`).

**Merge**: a group of **fewer than 3 wings** takes the first partner from the agent's air list (`+0xFC`, kept by range
by `InsertUnitByRange`) that is not itself and not handled; neither definition may have `strategic_attack > 50000`. Over
the summed wings the partner is rejected for:

- any CAG;
- strategic > 3, or strategic with any tactical, naval or transport;
- tactical + naval + transport > 2, or more than one of those three kinds mixed;
- transports > 1;
- multi-role > 1, or multi-role with strategic or interceptor;
- interceptors > 3, or interceptors with strategic, tactical, naval or transport;
- CAS with anything else, or CAS > 2.

On acceptance, `join_air` to the partner's province (VA `0x8CECEA`), and `+0x88` is set so the phase runs again next
hour.

### C.5 The commands

- **`CCreateUnitCommand::Execute` (`0x147930`)** builds an empty unit - kind 0 a `CArmy` at oob level 4, 1 a `CNavy` at
  5, 2 a `CAir` at 6 - with the id given, its owner, and `CUnit +0x159` from `+0x59`. It enters `province_id`, and its base
  is that province's naval base or air base when `base_province_id >= 0`. The AI is told on observer channel 6, 7 or 8
  (slot 17, 18 or 19). Its name, `CUnit_MakeName` with no brigade, comes out **empty**.
- **`CTransferSubUnitCommand::Execute` (`0x1DCB40`)** is **refused** when the receiving unit is fighting, or when
  `0xE1010`'s kind test fails (not read further). Otherwise the sub-unit moves; the best leader is assigned where the
  country auto-assigns and the unit has no real leader (skipped for a land unit of one brigade); an emptied source loses
  its leader, and a source fleet has `CheckTransportOverload` run. **A receiving unit whose name is under two characters
  is named here**: `CCountry::MakeUnitName(country, first brigade's definition, oob_level, 0)` - `NAVY_NAME`
  "$NUM$$ORDER$ Navy" or `AIR_NAME` "$NUM$$ORDER$ Air wing", with the first free number. A carrier brings the air units
  based on it, attached again under the new fleet. Both units enter their provinces again, and the player is told with
  `TRANSFEREDSUBUNIT`.
- **`CSendExpeditionCommand::Execute` (`0x1E9950`)**: the unit leaves its parent. If its expeditionary owner is the
  target it is going home - the field cleared and the unit off that country's lent list; otherwise it is lent - `+0x294`
  set to `defines.end_date`, and with no expeditionary owner yet, its owner becomes that owner and it joins the lent list
  (`0xE0860`). Either way it moves from its owner's `Units` list to the target's, its subtree with it
  (`CSendExpeditionCommand_TransferSubtree`, `0x1E9660`).
- **`CDetachUnitCommand::Execute` (`0x1DE270`)**: `CUnit_LeaveParent(unit, true)`. The unit keeps its children; no id or
  name changes.
- **`CJoinFleetOrder` / `CJoinAirOrder` `::IsActive`**: true while the mover sails; once it shares the target's province
  they merge it in and remove it. With no target, or a target itself joining (air), the mover goes back to base.

### C.6 Slot 78, `CAIUnit::ManageSubordinates` (`0x4B1D10`), read whole

Called at VA `0x8B0A1D` when `+0x86` is set, at hour `(id+9) % 24`, or under the daily flag. The commitment ladder, the
reserve's size, the recall and the detach to reserve are as `FINDINGS-power.md` has them. Added and corrected:

1. **It walks the whole country's unit list** (`CCountry +0xBAC`): a unit belongs to this agent when the nearest
   `ai_agent` up its chain is this one; a CAG air unit also belongs when it is based on a carrier whose fleet's agent is
   this one.
2. **Every naval unit of the country** under an `invasion` order adds its province to `+0x1AC`, whoever owns it.
3. **Air** units go into `+0xFC` (sorted by range), and onto `+0x10C` too if they carry troops.
4. **Naval** units go onto `+0xDC`, and onto `+0xEC` too if they carry troops and either carry something now or do not
   need port.
5. **Land** units: one on `support_attack` that is not holding ground or retreating is stopped (`0x49AAB0`: order
   `none`, destination cleared, `CCancelMovementCommand`); all go onto `+0x11C`; role-8 armies (`CArmy +0x2FC == 8`,
   likely paratroopers) also onto `+0x16C`, with the `+0x2E4` air-base check and the one `CSetAIParamCommand`; one that
   slot 86 claims is skipped with `+0x2C8` cleared; otherwise a division is committed or held back, and anything else goes
   onto `+0x14C`.
6. **With `+0x364` clear - `frontier_at_war`, the record's `manage_reserve` renamed by this wave, `FINDINGS-opsarea.md`
   having read its writer - or for a theatre agent's division outside the theatre's largest area**, there is no
   strength test: a held-back division stays held back and any other is committed. (`FINDINGS-power.md` had a clear byte
   holding back; it commits.)
7. **Role-8 divisions** are skipped when air transports existed at entry, and held back whenever the test runs.
8. Committed divisions on friendly foreign soil within the capital's region group are counted into `+0x348`, which
   `0x4CC450` reads.

### C.7 Slot 79, `ManageExpeditions` (`0x4B32E0`), and slot 80

Slot 79 is as the record had it, with three corrections (VA `0x8B3390`, `0x8B379B`): a unit on loan from a **government
in exile** is lent onward like the AI's own; the "same faction" test is a `CFaction*` compare, so **two factionless
countries pass**, sharing the null-faction singleton; and lending also needs the area's controller unplayed (or
`0x497A40`) and the area outside the theatre.

**The tick's `vf_80` is slot 80**, `CAIUnit::RebuildHoldProvinces` (`0x4B3A50`, called at VA `0x8B0A99`); slot 79 is the
call at VA `0x8B0A36`. Slot 80 rebuilds `+0x17C`, which slot 86 reads, and **adds `CObjective +0xC` (priority) to each
objective province's score** (VA `0x8B3C64`) - which ends `FINDINGS-aiplans.md`'s negative: the priority is read.

### C.8 Against the saves, `_01_01_00` to `_01_04_12`

- **Italy.** *Regia Marina* had 5 capitals and 13 screens. In list order it shed Andrea Doria (capitals 5 to 4); Taranto,
  Bari and Libia; and destroyers 2774 and 2783-2787 (screens 13 to 4) - exactly the ships the later save leaves it. Ten
  new fleets were made in that order, as ids 193 to 202 and the names 1st to 10th Navy bear out. The survivors: *3rd
  Navy* (195), Bari with *10a Squadra*'s three heavy cruisers joined into it; *8th Navy* (200), destroyer 2785 with
  Taranto, *2a Squadra* (three heavy cruisers) and *6a Squadra*'s destroyer joined - 3 capitals and 3 screens, both at
  the merge caps; *9th Navy* (201), destroyer 2786 with Andrea Doria and Libia. The other four destroyers joined transport
  squadrons, a transport fleet accepting screens. In the air, *4th Squadra Aerea* (a tactical bomber and a transport
  plane) lost the tactical bomber, which became *1st Air wing*; *Aeronautica Sardegna*'s interceptor split off and its
  naval bomber joined *'Centauro'*.
- **Japan.** Each fleet with 5 cruisers of one role shed its first; *15. Kaigun* (6 transports) shed 2 (6th and 7th
  Navy); *24. Kaigun* (7 destroyers) shed 3, which joined transport squadrons; three-capital squadrons joined lone-screen
  or carrier fleets, and single carriers joined a carrier.
- **The caps**: AI fleets over them fall from 56 to 2 between the two saves, and the rules explain both: Italy's
  submarine flotilla is resting a newly built cruiser (organisation 3.5), and New Zealand's 5 transports are at sea.

**Exe-hardcoded**: the split caps (4 capitals, 4 transports, 3 subs, 4 screens; the air caps of
`FINDINGS-reorganise.md`, interceptors only with interceptors or multi-roles), the merge caps (under 6 ships, at most 3
capitals, 3 screens, 3 subs; air groups under 3 wings, at most 3 interceptors), the port and fitness thresholds (0.5,
0.75, 0.9, and 0.75 on the current base's distance), one new unit a ship, and the 50000 strategic-attack cut.
**Mod-able**: which ships count as capital, transport, sub or carrier (the unit files' `capital`, `transport`, `is_sub`,
`carrier_size`, and `range` for matching subs), the new units' names (`NAVY_NAME`, `AIR_NAME`, `ST`/`ND`/`RD`/`TH`), and
strength, organisation and leader rules through the usual defines.

### C.9 What looks wrong and is what the bytes do

- A transport is judged by the **screen** cap whenever the theatre unit's `+0x284` is set.
- A sub in a mixed fleet is detached even after the last non-sub has gone, the non-sub count never being decremented:
  every sub of a mixed fleet ends in a fleet of its own.
- A carrier that is not `capital` would be detached on the screen count while its own count is decremented; TFH has none.
- `+0x84` is seeded 1, so a new agent's "daily" passes run **every hour** until `0x4CC450` clears it.
- Slot 78 pushes every naval invasion target of the whole country onto every agent's `+0x1AC`.
- Slot 79 lends units between two factionless countries.

### C.10 Not settled

- `0xD52A0`'s war branch, the route test for a fleet going to port; `0xE1010` past the combat test (whether a transfer is
  refused); `0x4B4200`'s province score.
- Which way `InsertUnitByRange` keeps its order, which decides which air partner comes first.
- Whether `+0x84` is ever set again in peace; the intercept phase's join rule's power arithmetic.
- The 4 "corps under navies" of the census - an artefact of keying units by id alone (section B.8).

## D. The plan's figures: stance, powers, objectives

*Reader D.*

**In one paragraph.** A theatre plan in the save carries **`active` = yes** because every `CSetPlanAttributesCommand`
switches its plan on and the AI posts one for every agent on its first pass; **`air_stance` and `naval_stance` = 2**
because `UpdateUnitStances` drives both to 2 on every pass; **`stance` = 1** where the agent has an ops area and no war on
its frontier, **2** where it has no ops area (the constructor's default), and 2, 3 or 4 at war by a ratio of power;
**`our_power` and `their_power`**, the AI's division strength and the foreign strength facing its ops area, posted again
only when a whole number is crossed, so small figures freeze at their first hour's; and **`objective`s** only on a
theatre at war - every province with points in the areas its fronts touch, at a priority of points x 20.

### D.1 When (`ProcessAI`, `0x4894E0`, hourly, AI countries only)

At the country's hour `id % 24`, in order: `0x48E490` when `0x48DCF0` answers false and `CEU3AI +0xA5` is set - where
`UpdatePlanPower` runs, for every agent whose root theatre resolves; `RebuildPriorityProvinces`;
`GenerateUnitObjectives`. Then **every hour** `UpdateUnitStances(ai, hour == (id+16) % 24)`, and `+0xA5` is set to 1.

### D.2 The stances - `CEU3AI::UpdateUnitStances` (`0x4912D0`-`0x491BD7`)

Its extent ends at `0x491BD7`: the "second exit" the record gave it is a function of its own, `0x491BE0`.

1. **Gate.** Without `force` it returns at once while `CEU3AI +0xA9` is set. `+0xA9` is set at the function's end only
   when the whole pass ran and no agent was at war on its frontier without an ops area; the constructor zeroes it and
   nothing clears it. So **the pass runs every hour until it first completes cleanly, then once a day** at hour
   `(id+16) % 24`. (The record had the sense of `+0xA9` the other way round.)
2. **Loop 1, over the unit agents** (`CEU3AI +0x40`): an agent with no unit **ends the whole function** (VA `0x89136F`),
   `+0xA9` left clear. A frontier not at war (`CAIUnit +0x364` clear): `+0xD0` = 0. Otherwise it climbs to the root agent
   and walks the root theatre's fronts (`CTheatre +0x50`); for each **hot** front (`+0x28`) whose enemy (`+0x1C`/`+0x20`)
   is new to this agent, the enemy goes on the agent's list and on a list over all agents, and when that enemy is at war
   with us (`diplomacy[enemy]->war`) or either side is `REB`, `plan.their_power / 1000` is added to the agent's sum - so
   their_power once per distinct enemy at war. `+0xD0` = the sum; a grand total is kept, and the agent with the smallest
   sum remembered (seeded 1e7).
3. **Loop 2**, for each agent with a unit:
   - if its plan's air or naval stance is not 2, post `CSetPlanAttributesCommand(unit, 5, 2, 2, -1000, -1000)` (VA
     `0x8916AD`);
   - `+0xD0` is rewritten as 1.0 when it equals the total, `1 - x/total` when the total > 0, else 0 - and nothing reads it;
   - **no ops area** (`CUnit +0x21C` = 0): the stance is not touched, and a frontier at war makes the pass unsettled;
   - **a frontier not at war**: stance **1**;
   - **a frontier at war**: r = our_power / their_power as floats in whole units, or 10.0 when their_power <= 0, then x
     0.5 when more than one distinct hot enemy exists over all agents and this agent is not the least threatened one. g =
     friendSum / enemySum, or 10.0 when enemySum <= 0, where enemySum = the sum of `army_combat_value` (`CCountry +0xCC`)
     / 1000 over the distinct enemies and friendSum the same over the distinct countries in any enemy's
     `ControllerNeighbours` (`+0xFE8`) that `IsFriend(that, us, true)` accepts. v = `CAIUnit +0x368` x r, where `+0x368` is
     the front coverage the tick takes from `0x4DCAE0` (section E). **v < 0.99 gives 2; v < 1.98, 3; otherwise 4**; then a 3
     or 4 with g < 0.9 loses one (clamped 0 to 4).
4. The stance is applied through slot 77 **only when it differs** from `plan.stance`.

**`SetPlanStance`, slot 77 (`0x4C36F0`)**: `+0x80` = 1; posts `(unit, stance, 3, 3, -1000, -1000)`; recurses into every
child agent with the same stance, so the commands queue parent first; then `UpdatePlanAxis`,
`RebuildOpsAreaProvinceRecords` when the stance is 0, and `ScoreOpsAreaProvinces`; finally it empties the held-back
vector `+0x15C`, clearing each division's `+0x2C8`, and sets `+0x86` (`replan_subordinates`).

**What the values mean** (`PlanStanceName` `0x4DFF00`, `PlanAirStanceName` `0x4E05A0`, `PlanNavalStanceName` `0x4E0B40`,
and the base game's localisation):

| | 0 | 1 | 2 | 3 | 4 |
| --- | --- | --- | --- | --- | --- |
| ground (`STANCE_*`) | Withdraw | Prepare | Defensive | Attacking | Blitzing |
| air and naval | Prepare | Defensive | Offensive | | |

The constructor and a reset give ground 2 and air and naval 1; slot 76's adoption of a theatre gives (1, 0, 0), the
0s overwritten with 2 on the next pass.

**Checked on `_01_04_12`**: 88 theatres at stance 1 (an ops area and a frontier at peace); 16 at 2 with no ops area
(NOR, IRE, OMN, YEM, BHU, NEP, MON, TAN, PHI, SIA, LIB, AST, NZL, CAN, CUB, URU); Ethiopia at 2 (r = 1.428/10.037 =
0.14); Italy's *Cdo. Sup. Africa* at 4 (r = 16.581/0.270 = 61); air and naval 2 on all 106. The same on `_01_07_14` and
`_01_08_07`; by `_04_20_03` Italy's Africa plan is back to 1.

### D.3 `active` - `CActivateUnitPlanCommand` (`0x1E5350`, `Execute` `0x1E5400`) and `CSetPlanAttributesCommand` (`0x1E7710`, `0x1E77D0`)

`active` is `CUnitPlan +0x8`, written by `CUnitPlan::SetActive`. **Set to 1** by every `CSetPlanAttributesCommand`,
whose constructor fixes `+0x64` = 1; by `CActivateUnitPlanCommand(unit, 1, plan.allow_hq_reorg)` from `CAIUnit::SetUnit`
(slot 63); and by the objectives panel. **Set to 0 with a full reset** (stance 2, air and naval 1, lists and powers
emptied) by `(unit, 0, 0)` from slot 54 (when the plan is active) and from `ClearUnit` (slot 64).
`CActivateUnitPlanCommand::Execute` then writes its `+0x65` to plan `+0x9` (`allow_hq_reorg`). **106 and not 108**: the
played country's two theatres have no agents.

### D.4 The powers

**The writer**, for an AI country, is `CAIUnit::UpdatePlanPower` (`0x4B5060`): our = `CAIUnit_SumOurPower`, their =
`CAIUnit::EstimateTheatreNeed`'s out-figure, and it posts `(unit, 5, 3, 3, our, their)` **only if `plan.our / 1000 !=
our / 1000` or `plan.their / 1000 != their / 1000`**, in C integer division - a change of whole number, not of a
thousandth as the record had it. It runs from `SetUnit` (after slot 78 fills `+0x11C`) and daily at hour `id % 24`
through `0x48E490`. `0x4B60F0` (`ComputePlanForcesAndPower`) posts its own figures unconditionally, but only for a
country a human plays (`played_countries_array[id] != 0`, VA `0x8B0B6F`); for an AI country the tick runs `0x4B5210`
instead, which posts no powers.

**our_power** (`CAIUnit_SumOurPower`, `0x4B9490`) sums over every unit on `CAIUnit +0x11C` with oob level 4 (`+0x11C`
holds every land unit whose nearest agent up the order of battle is this one). Per brigade: `(strength/100) x typeValue /
1000 x (organisation/100) / 1000`, all integer, in thousandths (`CUnit::GetPower`). **typeValue** (land) = `(soft_attack +
hard_attack + ap_attack + (defensiveness + toughness)/10 + armor_value) x (2000 - softness) / 1000`, from the regiment's
own definition - the unit file and the regiment's own technology levels (the save's `tech={level progress}` lines) times
each technology's effect. **The fort bonus**: a division gets `x (1000 + 80 x fort level) / 1000` unless it is moving
(`+0x2CC > 0`), its order is of a kind other than `0x4E5`/`0x56C` and answers true to slot 24, or the plan's stance is 3
or more.

**their_power** (`EstimateTheatreNeed` to `EstimateAreaNeed`, `FINDINGS-power.md`): the weighted `GetPower` of foreign
land units on the front provinces the agent's ops area faces (`CAIUnit +0xC0`). Hence **0 for a plan with no ops area** -
all 16 such show `their_power=0.000` (inferred: it rests on `+0xC0` being rebuilt only from the ops area); other zeros are
no foreign units on the faced front, or a figure frozen by the gate.

**Checked**: **46 of the 63 our_power figures under 1.000** in `_01_04_12` equal this sum over `_01_01_00`'s order of
battle *exactly* - all nine 0.063s, Copenhagen 0.188, Oslo 0.144, Stockholm 0.520, Amsterdam 0.648, Bucuresti and Cluj
0.810 - posted in the first hour and frozen by the gate. Kwantung Army Theater's 40.084, posted between `_01_08_03` and
`_01_08_06` (Japan id 5, hour 5), is the sum over `_01_08_06`, 40084. Ethiopia's 1.383, posted in the same window, lies
between the sums over `_01_08_03` and `_01_08_06`, 1380 and 1386. Every change of power between saves crosses a whole
number (7 of 7 from `_01_04_12` to `_01_07_14`), each in the hour its country's `id % 24` gives. France's Paris and
Bordeaux headquarters come out 0.5% low (14.946 and 17.106 against 15.017 and 17.167), not explained. Slot 78 sets its
commitment floor by the ratio of the two (`FINDINGS-power.md`).

### D.5 Objectives

**`RebuildPriorityProvinces` (`0x4976E0`)** fills `CEU3AI +0x118`, only while the country is at war: the candidates are
the faction's other members that are themselves at war, then `non_hostile_countries`; for each candidate Y, it walks
`CGameState +0xBAC[Y]` (`allied_objectives_by_requester`), and every record whose countries hold our id gives its
province.

**`GenerateUnitObjectives` (`0x4980E0`)** runs for every unit agent, subordinates too, since `GetArea` climbs to the
theatre:

1. **Only a hot theatre** (`CTheatre +0x70`) builds a list. A front counts when it is hot or its enemy is front-worthy;
   for each of its provinces and each edge not of kind 3, the neighbour must be simulated (`+0x13D`) with a real owner
   area, and if the controller of that area's *first* province is front-worthy the area joins the list, once, in the
   order met.
2. For each listed area's provinces in order: **priority = victory points x 20 + the province's `conquer_prov` value**
   (the strategy's, `CCountry +0x4A8` = `CAIStrategy +0x1C` of the strategy at `+0x48C`) **+ 100 if it is in `+0x118`**;
   kept at 1 or more, as `{province, priority, invasion 0, hold 0}` - `invasion` is always 0.
3. The test meant to drop provinces nearer another theatre compares each of that theatre's areas with its *own*
   neighbour links (VA `0x8985E5`); an area is never linked to itself (`AdjustNeighbour` refuses), so **it never fires**.
4. It posts `CSetPlanObjectivesCommand(unit, list)` unless the count and every (province, priority) pair already match;
   a theatre that is not hot posts an empty list, which clears old objectives. **`CSetPlanObjectivesCommand::Execute`
   (`0x1E6980`)**: `CUnitPlan::CopyObjectives` replaces the plan's list whole.

**Checked**: Italy's Africa plan holds 7445 (20), 5567 (20), 5589, 5563 and 5586 (100), 5611 (40), 9943 (40), 5160 (80),
5412 (60), 5134 (100) - each exactly 20 x the province's `points` in the history files, with no `conquer_prov` and no
+100: British, Ethiopian and French provinces in areas touching the theatre's fronts. Ethiopia's hot theatre faces Italian
East Africa, whose provinces have no points, so gets nothing; no other AI theatre is hot, so 105 plans carry no
objective; by `_04_20_03` the Italian list is cleared.

**Exe-hardcoded**: the stance thresholds 0.99, 1.98 and 0.9; the halving and the 10.0 defaults; the schedule (`id % 24`,
`(id+16) % 24`) and the settled byte; the whole-number gate on the powers; 80 a fort level; the typeValue formula; x 20 a
victory point and + 100 an allied objective; only hot theatres making objectives. **Mod-able**: brigade figures
(`units/*.txt`) and technology effects, which feed the powers; fort levels; victory points (`history/provinces`);
`conquer_prov` (the AI strategy); allied objectives (set in play); the stance names (`STANCE_*`, text only).

### D.6 What looks wrong and is what the bytes do

1. One agent with no unit ends the whole stance pass for the hour, the air and naval posts with it.
2. their_power is added once per distinct enemy at war, so two enemies double it.
3. Every agent but the least threatened has r halved whenever there is more than one hot enemy.
4. `CAIUnit +0xD0` is computed twice and never read; it is 1.0, not 0, when an agent holds all the enemy's power.
5. The AI never chooses stance 0 (withdraw); a war stance never drops below 2.
6. A peaceful agent with no ops area keeps the constructor's stance 2, not 1.
7. Fractional powers freeze for months under the whole-number gate.
8. The drop of objectives nearer another theatre never fires.
9. Objectives include provinces of front-worthy neighbours not at war (British and French ones for Italy).
10. Every subordinate agent posts the theatre's whole objective list for its own unit, beside slot 84's distribution.
11. `CEU3AI +0xA9` is never cleared, so a war breaking out later is answered with a new stance only once a day.

### D.7 Not settled

- How a figure under 1.000 got past the whole-number gate on its first post, the plan starting at 0 and 0: one of the
  figures must first have held another whole number. A candidate is `ComputePlanWantedSubUnits` (`0x4E1D00`) writing an
  inactive plan's powers; not read.
- France's 0.5%, probably a figure or technology effect the calculation misses; their_power not reproduced
  (`EstimateAreaNeed` not read again).
- Whether subordinate agents exist in these first days - only theatre plans are in the saves (section A.3: they do
  not; every agent is a theatre's).
- ~~`CAIUnit +0x364` is still named `manage_reserve` in the record, where `FINDINGS-opsarea.md` says
  `frontier_at_war`~~ - renamed `frontier_at_war` in this wave's merge.

## E. The plan's area: ops area, axis, embark and debark, `min`

*Reader E. Builds on `FINDINGS-setarea.md` and `FINDINGS-forceneeds.md` too.*

**Exe-hardcoded**: the infrastructure floor 200 (a static from 200.5, two levels); an owner area holding only provinces
of more than one level of infrastructure (100); wideOpen's threat 40000 and neutrality 20000; the second chance's 100;
the prune's distance 100 and its three nearest; the five-province area test and the 100.0 and 50.0 weights of a
position; the force planner's `/40`, `x3`, `/300`, its halves and 0.07, 0.15, 0.02; the vote's weights 1, 4, +3, +10.
**Mod-able**: the map (edges, infrastructure, regions, ports); the theatres and fronts (`FINDINGS-theatres.md`); threat
and antagonism, through the strategy; the unit files - which types exist, their order (the folder's listing),
`usable_by`, `transport_weight`, `transport_capability` - and the technologies that make a type available
(`single_engine_aircraft_design` the interceptor, `twin_engine_aircraft_design` the tactical bomber, `nav_development`
the naval bomber, `basic_four_engine_airframe` the transport plane, `basic_strategic_bomber`,
`multi_role_fighter_development`, `cas_development`).

### E.1 Who writes an AI theatre's plan

For a country the AI runs, **the ops area comes only from `CAIUnit::SetArea`**. Slot 76, the plan builder of
`FINDINGS-aiplans.md`, is dispatched only for the human's delegated AI: `EnsureAgentForArea` calls it only while
`runs_units` is clear, `CreateAgentsForPlannedUnits` is gated on the player, and `CObjectivesEntry` slot 22 is the
interface (the other `slotcalls 76` hits in the AI module, VA `0x891F1D` and `0x8988DC`, are reads of `CUnit +0x130`, not
calls). So slot 76's double post (`FINDINGS-aiplans.md` step 7) cannot be settled from these saves.

`SetArea` runs (`CAIUnit::Tick`) when `area_dirty` (`+0x87`) is set, and at 01:00 on a day whose day of the year (from 0
= 1 January) is a multiple of 7 - 1, 8, 15 January and so on. `area_dirty` is set by `EnsureAgentForArea(..., false)`,
which the theatre layer calls for every theatre whenever it runs - after `BuildTheatres` sets the made theatres beside
the old (VA `0x8ABC38`) and in `RefreshTheatreProvinces` (VA `0x8ABFAE`) - so every refresh of the theatres draws its
agent's area again in the next AI hour. `SetUnit` (slot 63), slot 76's adoption and `CTogglePlanObjectiveCommand::Execute`
call it too.

### E.2 `SetArea` (`0x4BA5A0`), in order

0. `+0x87` = 0. Nothing more unless the agent has a unit at oob level 0 and a theatre.
1. `RebuildFocusOwnerAreas` (E.3); `+0x90` emptied.
2. **Objective areas, the human's delegated AI only**: the distinct owner areas of the plan's objectives that are not
   ours. Every AI country skips this.
3. **The candidate fronts**: the theatre's own fronts (`+0x50`) in order; then, for each focus area (`+0x338`) that
   `AreaMayWidenFrontSearch(us, area, &out, false)` allows, every front of every theatre of the area's controller whose
   first province is in that area and whose enemy is not us, without repeats - a subject agent taking such fronts only
   against an enemy at war, `REB`, or under an undeclared war. Areas returned with `out` set are recorded for step 6.
   For an AI country `AreaMayWidenFrontSearch` answers yes when the area's controller is our subject (its `+0xF3C` is
   us), when we lead their faction, and in a few war cases.
4. **Which fronts are taken.** wideOpen is true when the theatre is not hot, or we are `IsPreparingWarWith` the enemy,
   or our `CDiplomacyStatus` towards it has `+0x5C` >= 40000 **and** the enemy's `+0xA90` <= 20000; forced false if step 2
   found anything. A front is taken when it is hot (`CAreaBorder +0x28`, the save's `front`), or `IsWarCandidate(enemy)`,
   or wideOpen and `IsFrontWorthyEnemy(enemy)` (`FINDINGS-theatres.md` D), or it is one of step 2's.
5. **Which provinces of a taken front**, in the front's order: p is taken when `MaxInfrastructure(p)` >= 200, p is in a
   real owner area, p is ours or `IsFrontProvince(p, false)` or held by our subject, and some edge of p **not of kind 3**
   reaches a land, simulated province with a hostile controller (id 0, `REB`, or not `IsSameSide` and either not a
   co-belligerent or an enemy) **that is itself in a real owner area**. An owner area holds only provinces of more than
   one level of infrastructure, so a front province whose only hostile neighbours have one level is left out - what makes
   nine fronts partial in the saves, e.g. province 252 of Finland's front against the Soviet Union, whose only Soviet
   neighbour 267 has one level. Each taken p goes onto `+0x90` and its id onto the command's list.
6. **The prune**, only if step 3 recorded areas, which needs `CEU3AI +0x118`, filled only at war
   (`RebuildPriorityProvinces`): for each listed province in or beside a recorded area, if we are at war with its owner
   the three ops provinces nearest it are kept, otherwise every ops province within `CMap` distance 100 of it; then every
   unkept ops province in a recorded area is erased from both lists.
7. **The second chance**, when the area has an id and `+0x90` is empty: for each of the theatre's own fronts, value = the
   enemy's threat towards us (its strategy's threat keyed by our id) + our antagonism of it (AI only); above 100, every
   province with infrastructure >= 200 in a real area is taken - **with no neighbour test**.
8. **Always** one `CSetPlanOpsAreaCommand` with the ids, even an empty one: its `Execute`, `CUnitPlan::SetOpsArea`, first
   pads `min` with zeros to the database's size, then `RefreshPlanForceNeeds`; then the five replan calls, the third only
   at stance 0; then `CArmy +0x2EC` refilled, slot 82 (false), and `+0x84` = 1, `+0x82` = 0.

**Against the saves** (scratch `opssim3.py`, the edges from the install's `map/cache/adjacencies.bin`): **106 of 106 in
each of `_01_04_12`, `_01_08_07` and `_04_20_03`, province for province and in order.** In `_01_04_12`: 82 by the main
path; 2 with a subject's fronts after the theatre's own - Japan's Kwantung Army takes Manchukuo's fronts against the
Soviet Union and Mongolia but not those against Japan, the Soviet Far East takes Mongolia's against Japan and Manchukuo
but not Sinkiang; 6 by the second chance - Sweden, two British, Portugal's Nova Lisboa, Bolivia, the US Pacific - each
taking exactly the fronts whose value is above 100 (Sweden: Norway 345 and Denmark 117 taken, Finland 14 not); and 16
empty. The front-worthy test was taken as whole fronts, not computed again, and fits `FINDINGS-theatres.md` D wherever
looked: the Soviet Union takes Finland, Estonia, Latvia, Poland, Romania, Turkey, Manchukuo and Japan and not
Afghanistan, Persia, Sinkiang or Mongolia; Finland takes the Soviet Union and not Sweden or Norway; Mongolia, a Comintern
member with no row of its own, nothing.

**The 16 with no ops area**: Cuba, New Zealand and the Philippines have no front; the rest face only countries that are
not front-worthy with threat and antagonism at most 100 - Ireland and Canada facing Britain or the United States, Norway
(Sweden 44), Siam, Liberia, Uruguay, Britain's subjects Bhutan, Nepal, Oman and Yemen, Mongolia and Tannu Tuva,
Australia (Holland 19). **Between `_01_04_12` and `_01_07_14` no ops area changes**: an empty list is not written to the
save, which `WAVE.md`'s count of 16 changes misread. To `_01_08_07`, after the re-anchor of 8 January, 4 change: two
British theatres in order only, and Italy's Africa theatre and Ethiopia's with the war.

### E.3 The focus areas (`0x4B0D20`, `0xB0F20`, `0xB1240`, `0x803F0`)

`RebuildFocusOwnerAreas` runs daily at hour `(id + 9) % 24` and at the start of `SetArea`: it empties `+0x338`, and for
each distinct region group (`COwnerArea +0x6C`, one side's connected land, `CollectAreaGroup`) of the theatre's areas
whose real areas hold more than one province (`AreaGroup_CountProvinces`), calls `CollectTheatreFocusAreas` (`0xB0F20`;
the record's callee "0x4B0F20" was a VA). That repeats while it adds something, stopping when the group's province total
is not above the list's count; for each area of the group it skips one whose controller is the theatre's country, one
where both are in real factions that differ, one listed already, and otherwise adds it where `TheatreBordersAreaMost`
(`0xB1240`) is true - or where that found no edge at all and the list is not empty. `TheatreBordersAreaMost` counts edges
(not of kind 3) from the area's land fronts to provinces the theatre's country controls, per theatre serial
(`CMapProvince +0x384`); the first strict maximum in ascending serial order must be this theatre.

### E.4 The replan calls and the coverage

In `ReplanSubtree`, `SetArea` and `SetOpsAreaAndReplan`. **`0x4BC860`**: ring one is friendly land (same side, or a
co-belligerent that is not an enemy) beside the ops area, kept in a local vector and thrown away; ring two, the same test
a step further leaving out the ops area and ring one, is appended to **`+0xA0`**; `+0xB0` is only emptied (a vector, not
the `COrder*` the record had). **`0x4BCD60`**, only at stance 0, the **hold positions**: a supply depot's province gets a
record weighted 100.0; otherwise the position is the province itself, or its one friendly neighbour outside the area
when `10 x fort(neighbour)` (+10 behind an edge of kind 1 or 2) `> 10 x (fort(p) + enemy crossings of kind 1 or 2)`,
weighted 50.0 - fort being modifier 10 / 1000; records go to `+0x2FC`, mapped by province at `+0x30C`. **`+0x368`**
(`CAIUnit_GetFrontCoverage`, `0x4DCAE0`, each hour) is the share of exposed positions covered: the positions are `+0x2FC`
at stance 0 and otherwise `+0x2C0`; one is **exposed** if an enemy-held land neighbour lies in an area of more than 5
provinces, and **covered** if one of our land units with no children stands there; the figure is covered / min(exposed,
the count of `+0x12C`) - 1.0 with nothing exposed, 0.0 with no list, no unit or an empty `+0x12C`. Its one reader is
`UpdateUnitStances` (VA `0x891AE3`, section D.2).

### E.5 The axis (`UpdatePlanAxis`, `0x4C3330`)

Only one plan has a `path`: Italy's *Cdo. Sup. Africa* in `_01_04_12`, at stance 4 with ten objectives - 9807, 9846, 9887,
9907, 9943, starting at the neighbour of ops province 9767 and ending at its one Ethiopian objective, the British and
French objectives not reachable by land; `path2` empty. Every other plan is at stance 1 or 2 with no path, as the gate on
stance 3 and 4 says. Embark and debark do **not** come from the axis.

### E.6 Embark and debark (`0x4C4370`, `0x1E8C00`, `0x1E8CB0`)

`CSetPlanTransportStateCommand(unit, embark, debark)` sets the plan's `+0x88`/`+0x8C` (`CUnit +0x284`/`+0x288`) and
nothing else. Its only poster is **`CAIUnit::AssignAreaTargetsAndSealift`** (`0x4C4370`, 12.7 KB; Ghidra mislabels it
`CSetAIParamCommand_4`), which the tick calls for the agent that plans its order of battle at hour `(id + 6) % 24`, or at
once while `+0x5C` is set (it clears it). **Its head** (decompiler only) gives each land division of `+0x11C` a target
province by area need - `EstimateAreaNeed` per theatre area, halved for the capital's area at war - posting
`CSetAIParamCommand(unit, target, staging)`, the target being the save's division `target`; it marches divisions by land
where it can and lists the rest for the sea. **Its tail**: `+0xD4` = the listed divisions' `transport_weight` / 1000; if
only one of embark and debark is set, or both are set but no listed division bound for debark stands in embark's area,
it posts (0, 0). While debark is unset, anything is listed and the agent has transports (`+0xEC`), the listed divisions
vote for their target province - 1 a vote, or 4 where one per-area tally of the area the division stands in is below 1;
+3 where the other is above 0; +10 where the target is not ours. The best target not tried yet becomes debark, embark is
`0x4C3AF0`'s port in the area most of those divisions stand in, and the pair is posted; then the divisions are marched to
embark and transports sent there by weighted distance at sea until their room covers the divisions' weight. **In the
saves** 12 plans in `_01_04_12` have an embark and a debark, all ports; debark is a division's saved `target` in 10 of
the 12, Australia's and New Zealand's the exceptions.

### E.7 `min` (`0x4B5210` for an AI country, `0x4B60F0` for the played one)

**The 58 entries**: `CSubUnitDataBase` makes the null definition first, index 0 (`push 0` at VA `0x5AEFED`); the unit
files then get 1, 2 and on in the order the folder lists them (`FindFirstFile`, inferred) - `tfh/units` has 57, so 58.
**The AI's arm** zeroes the vector and adds up to six aircraft wants, each gated on `unit_available` and `usable_by`.
brigadeDemand = `+0x354 x 3 + +0x370`; totalBrigades = the sum of `+0x40` over `+0x11C`.

- **interceptor** = **tactical bomber** = `(totalBrigades + brigadeDemand) / 40`, truncated; CAS stands in for the
  tactical bomber where that is not available;
- **transport plane** = `round(airborne tonnage / capacity)`;
- **strategic bomber** = `round(sum(LOCAL_IC + crude oil) / 300)`, halved with an ops area, only if > 0;
- **naval bomber** = `round(score)`, stored plainly, rounded by `fistp` (half to even), where the score is, over the
  **sightings gained** (`+0x25C`), enemies only, +0.07 a heavy cruiser brigade, +0.15 a capital ship, +0.02 anything but
  a **submarine**, and over the **sightings lost** (`+0x26C`), every unit with no enemy test, -0.07, -0.15, -0.02 for
  anything but a **transport_ship**;
- **multi-role** = `round(tactical / 2 + score / 2 + transport planes / 2)`.

The vector is posted only on a change, and the theatre's plan being active at level 0, `UpdatePlanForceNeeds` never
overwrites it. **Against the saves**: only indices 29, 39 and 53 (interceptor, naval bomber, tactical bomber) are ever
non-zero, in all 106 plans of `_01_04_12` and `_04_20_03`. Interceptor equals tactical bomber but where the technology
is missing - Finland and Greece have no single-engine design and want neither; Portugal has it but not the twin-engine
one, so wants an interceptor and no tactical bomber. `floor(brigades under the headquarters / 40)` is never above the
interceptor want where the type is available - 67 equal it, the rest exceed it by the need term. The naval bomber is -1
to -4 in exactly 9 theatres, all of countries with `nav_development`. The exact interceptor figure needs
`EstimateTheatreNeed` (`+0x354`), not computed again. Downstream, `CEU3AI::GetTheatreSubUnitNeedCounts` (`+0x108`) sums
each agent's `plan_subunit_group_difference` floored at 0, so for an AI country it only ever carries aircraft.

### E.8 What looks wrong and is what the bytes do

1. A front province whose only hostile neighbours have one level of infrastructure never enters an ops area, the
   neighbour being in no owner area.
2. The second chance has no neighbour test and takes whole fronts, provinces facing nothing hostile among them.
3. `0x4BC860` throws away the adjacent ring and keeps only friendly land two steps out at `+0xA0`; `+0xB0` is emptied and
   never filled.
4. The lost-sightings loop has no enemy test and leaves out transports where the gained loop leaves out submarines, so
   an AI's naval bomber want is at most 0 at peace.
5. `SetArea` posts its command even with an empty list, which clears the plan's area.
6. At stance 0, with no friendly neighbour outside the area, the hold position becomes the first friendly neighbour
   *inside* it (decompiler, not stepped).
7. `CollectTheatreFocusAreas` stops when a group's province total is not above its list's count of areas.

### E.9 Not settled

- Slot 76's fallback double post: no AI plan goes through slot 76, and the played country has no plan.
- `IsFrontWorthyEnemy` not computed again pair by pair - OpenHOI3 has it, and its check will close this.
- `0x4C4370`'s head (the area need and the targets) is read on the decompiler only, as are its two per-area tallies and
  `+0x58`.
- The exact interceptor and tactical figure, which needs `EstimateTheatreNeed` and slot 78's `+0x11C`.
- That the unit files' order is `FindFirstFile`'s and not a sorted one: the saves' three indices agree with either, only
  `armor`/`armored_car` and `motorized`/`mot_AA` differing.
- Which day the weekly re-anchor falls on across a year's end (day 364, then day 0).

## F. The movers between theatres

*Reader F, read after A to E landed.*

**In one paragraph.** Four `CEU3AI` helpers run once a game day for each AI country and move whole units from one theatre
agent to another, each move posted as `CDetachUnitCommand` then `CAttachUnitCommand(unit, the receiving theatre's
headquarters)` - **nothing marches**: the receiving theatre's own logic moves them later. **Divisions** (`id % 24`):
theatres short of divisions take from theatres with a surplus, by the ratio of division count to division need, and a war
candidate also pulls in mobile divisions and the whole surplus. **Fleets** (`(id+16) % 24`): submarine fleets by
submarine want, surface fleets by each theatre's share of sighted enemy ships. **Bombers, transport planes and
paratroopers** (`(id+16) % 24`): by the plan's group difference, the capital's theatre pulling every unit holding a
transport plane or a paratrooper. **Transport fleets** (`(id+8) % 24`): to theatres whose sealift tonnage is more than the
room they hold. A division moves alone unless every division of its corps (or every corps of its army) was picked; then
the whole command moves.

**Exe-hardcoded**: the three hours; the -1000 sort penalty; the ratio thresholds 0.4/0.15, 0.3/0.1 and 0.35/0.125; 3 x
need, two thirds of the ops area, stance <= 2; max_speed >= 2000; the pick's weights 10, 15, 0.25, /3 and k/100 and the
0.1 default distance; round half to even on the area keep; the 1000 "no war-candidate border" figure; the -10000 floors,
gain > 1; the sea distance /1000 /400 capped at 10, plus room; r >= 1.0. **Mod-able**: the unit files'
`transport_capability`, `maximum_speed`, transport `weight`, and which types exist under the keys `motorized_brigade`,
`mechanized_brigade`, `armor_brigade`, `light_armor_brigade`, `heavy_armor_brigade`, `bergsjaeger_brigade`,
`tactical_bomber`, `strategic_bomber`, `naval_bomber`, `transport_plane`, `paratrooper_brigade`; the terrain named
`mountain`; naval bases, victory points, supply depots and the map; the theatres, and the plan's `min` the group
difference is measured against (E.7). None of it reads `defines.lua` or Lua.

### F.1 `CEU3AI_BalanceDivisionsBetweenTheatres` (`0x48E490`)

At `id % 24` once `unit_pass_done` is set - from the country's second AI pass.

1. **The refresh and the sort.** For every unit agent with a unit whose root theatre resolves, `CAIUnit::UpdatePlanPower`
   runs - the day's refresh of `divisions_needed` (`+0x354`), `divisions_counted` (`+0x358`) and the powers (D.4). The
   agent then goes into a local list sorted by key = need - count, less 1000 unless `frontier_at_war` (`+0x364`),
   descending, ties in agent order (`CEU3AI_InsertAgentByShortage`, `0x49C140`): agents at war first, then the most short.
2. **Takers**, from the head of the list; an agent is skipped when need < count and `frontier_war_candidate` (`+0x365`) is
   clear.
3. **Donors**: every other listed agent, walked from the tail; a donor whose theatre is connected to the taker's
   (`CTheatre_IsConnectedTo`, `0xB0710`: they share an owner area, or the donor's headquarters can reach the taker's
   headquarters' province by `CanUnitReach(..., true, true)`) is pushed to the front of the donor list, any other
   appended. So connected donors come first, most short to most surplus; unconnected ones follow, most surplus first.
4. **A donor B is passed over for taker A**: where A is not a war candidate, B's frontier is at war and B's plan stance
   (`CUnit +0x208`) <= 2; where 3 x needA - countA < 1; where A is not a war candidate, B is at war, and countA >=
   floor(2 x |A's ops area| / 3). Counts and needs are read again for every donor.
5. **The whole-unit grab.** Connected, A a war candidate, B not, and needA > needB: every division of B holding a
   motorized, mechanized, armor, light_armor or heavy_armor brigade (`CAIUnit_CollectMobileDivisions`, `0x4BF660`),
   rolled up (F.2), moves to A.
6. **How many.** ratioA = countA / needA and ratioB = countB / needB, as floats, each 1.0 where its need is <= 0.
   (t1, t2) is (0.4, 0.15), or (0.3, 0.1) where A is a war candidate, or (0.35, 0.125) where both are. If ratioB - t1 >
   ratioA, n counts up while n < needA - countA and (countA + n) / needA < (countB - n) / needB - t2 - B gives until A's
   fill would reach B's less t2. minGive is countB - needB where A is a war candidate, the theatres are connected and B is
   not - and only then is `fastOnly` set; floor((countB - needB) / 2) where both are war candidates, connected, and countB
   > 2 x needB; else 0. n = min(max(n, minGive), 3 x needA - countA); below 1 nothing moves. The need scale f = 1 -
   min(n / (countB - n - minGive), 1) where that divisor is positive, else 1.
7. **The pick**: `CAIUnit_PickDivisionsToGive(B, n, n, fastOnly, A's theatre, f)` (`0x4BF8E0`, F.2).
8. **The post**, for each picked unit in list order: its `GetPower` moved from B's `+0x35C` to A's;
   `CDetachUnitCommand(unit)` and `CAttachUnitCommand(unit, A's headquarters)` posted; A's `+0x358` up and B's down by its
   divisions (1 a division, `CountDivisions` over a command's children). The plan's `our_power` is not posted again until
   the next `UpdatePlanPower`.

### F.2 Which divisions a donor gives (`0x4BF8E0`, `0x4C0160`, `0x4BEC70`)

1. **The area keep.** For each owner area of the donor's theatre: keep = round half to even(`EstimateAreaNeed(B, area,
   relaxed)` x f), at least 1 where the need is above 0; have = `CAIUnit::CountDivisionsInArea` (`0x4B7F80`).
2. **Candidates**, in `+0x11C` order: a division (level 4, a brigade at least), not the agent's own unit, with `army_role`
   (`CArmy +0x2FC`) not 8; a role-5 division stays where it stands on or is bound for a province of more than 9 victory
   points or its own supply depot; `CAIUnit_UnitMayLeave(..., false, true)` (`0x4BEC70`) - not retreating, not held in a
   combat, and at peace no border condition; not bound for an enemy-held province; with `fastOnly`, its definition's
   max_speed >= 2000 (garrisons, at speed 1, are out); not on the agent's target-area provinces (`+0x1CC`); and not in an
   area whose have <= keep with keep > 0.
3. **Picking.** maxD = the greatest distance from a candidate's province to the receiving theatre's fronts
   (`DistanceToTheatreFronts`), 0.1 where that is 0. While fewer than n are picked, each unpicked candidate is tested and
   scored: it needs k >= 1, k being 1000, or beside a war-candidate border the other idle divisions in its province
   (`0x4BF0E0`); a donor that is a war candidate (without `fastOnly`) never gives a division holding a mobile brigade;
   score = (1 - d / maxD) x (15 where its parent has given one already, else 10); x 0.25 unless its area is one of the
   receiving theatre's areas or touches one; / 3 for a `bergsjaeger` division standing idle on a mountain province of the
   donor's ops area; x min(k / 100, 1). The strictly highest score above 0 is picked, the first of equals, and its parent
   noted.
4. **Roll-up** (`CAIUnit_RollUpWholeCommands`, `0x4C0160`): a noted parent - not fighting, not retreating, not a theatre -
   all of whose children were picked takes their place; its own parent gets the same test once. So whole corps move, and
   whole armies when all their corps did.

### F.3 `CEU3AI_DistributeFleetsToTheatres` (`0x48FBB0`-`0x490DA3`)

The surface half lies past the `ret 4` at VA `0x8906EF` (trap 3). The fleets considered are every naval unit with no
`ai_agent` of its own, in unit-list order, a fleet's current agent the topmost agent up its chain. **Submarine fleets** -
any holding a submarine - each go to the agent maximising (`submarine_want` `+0xD8` - subs held) - (the current agent's
want - held + the fleet's ships), counting only agents with a want; the current agent's term is -10000 with none or a
want <= 0; the winner must score above 0. **Surface fleets**: wants = `CAIUnit_CountSightedEnemyShips` (`0x4B96A0`, the
ships of the units on `+0x25C`), for agents whose theatre has ports; each agent's holding = the carriers, capitals and
screens of its agent-less fleets; with the wants summing to <= 0 nothing moves; otherwise each surface fleet (n = its
ships but submarines, transports among them) goes to the agent maximising want / the sum of wants - (holding +- n) / the
country's total, from -10000. **The move**: detached where it has a parent, attached under the winner's headquarters,
`replan_subordinates` on both agents.

### F.4 `CEU3AI_DistributeAirToTheatres` (`0x48F2B0`)

Every agent in order is offered every unit of the country, in list order, that has not moved this pass and is not under
it already - land divisions among them. (1) **The capital pull**: where the agent's theatre is the capital province's and
the unit holds a transport plane or a paratrooper brigade, it moves, with no tally. (2) **The gain** otherwise: over the
five listed types the unit holds, the sum of (A.diff - A.tally - T) - (cur.diff + T - cur.tally), diff being
`plan_subunit_group_difference` (`CUnit +0x6C`), aircraft their own group, every cur.diff -1000 with no current agent; it
moves where the gain > 1, or where it holds a tactical bomber and the receiver is a war candidate while its current agent
is not. Interceptors, multi-role fighters and CAS never move. (3) The tally (`CAIUnit +0x23C`) is kept for every type on
each move.

### F.5 `CEU3AI_GatherTransportsForTheatres` (`0x490DB0`)

Only agents with a `sealift_port` (`+0x58`) and an `amphibious_transport_tonnage` (`+0xD4`) above 0, both written by
`AssignAreaTargetsAndSealift`'s tail (E.6); the port is `COwnerArea_LargestNavalBase(CTheatre_LargestArea(theatre))`
(`0x4C38C0`). While the tonnage is above what the agent has (the room of `+0xEC`, `CAIUnit_SumTransportCapacity`,
`0x4B4F90`), it takes the best fleet that is agent-less and on no busy order with room >= 1, not under this agent and not
taken this pass, and - where its current agent has its own tonnage - only where r >= 1.0 and have < r, r and have being
the *taker's* (`CAIUnit_SealiftWeightToEnemyDebark`, `0x4BDCC0`). Score = 10 - min(sea distance to the port / 1000 / 400,
10) + room / 1000; the strictly best is attached, the have grows, and both agents are marked.

### F.6 Against the saves

Consistent with every rule above and checkable figure for figure by none, `divisions_needed` not being saved (F.9).
**The Soviet Union**, `_01_01_00` to `_01_04_12`: 24 divisions changed theatre - Arkhangelsk HQ 7 to 14, Leningrad HQ 8
to 17, Brjansk HQ 11 to 15, Kyiv HQ 18 to 13, Odessa HQ 34 to 19, STAVKA 13 to 13. Arkhangelsk took 11 and gave 4 to
Leningrad in the same days; 11 corps moved whole, every corps whose divisions all moved; the mechanised corps went to
Arkhangelsk and Leningrad, which fits the whole-unit grab if those two are war candidates - which no save records. No
Soviet division changed theatre from `_01_04_12` to `_04_20_03`: the balance settles in about three passes. **Poland**:
the new Lwów HQ 0 to 20 divisions, Warszawa 43 to 23, every one keeping its place, as an attach without a march would.
**Manchukuo**: Mukden 4 to 1, Harbin 2 to 5 - Mukden keeping one, as the area keep would with one area. **The United
States**: 6 divisions and I Army Corps East to West, and the Philippine force to Manila HQ. **Britain**: India gave 6th
Indian Infantry to the Far East and 7th to East Africa, each standing on its new theatre's embark port (6070, 5762), and
six more by April. **Fleets**: the only fleets that changed theatre between the first two saves, orphans aside, are
Britain's 3rd Transport Squadron (4 transports) to East Africa and 5th (3) to the Far East - the two theatres with an
embark and a debark and no transports; India, with its own squadron, got none; both then sailed. By April two French
transport fleets and Italy's 1a Squadra di Marina moved the same way. **No warship fleet changed theatre**, which fits a
surface want made of sighted *enemy* ships, empty at peace (inferred). **Air**: Italy's 4th Squadra Aerea (a tactical
bomber and a transport plane) went from Africa to Metropolitana without moving - the capital pull; 'Drago' (tactical
bombers) to Africa at war - the tactical-bomber rule; 'Eolo' (naval bombers) to Africa, not reproduced.

### F.7 Corrections to the record

| record | read |
| --- | --- |
| `0x4B0710` as the theatre-connection test (the comments of `0x48C090` and `0x48E490`, section A.3) | a VA; the rva is `0xB0710`, `CTheatre_IsConnectedTo`; rva `0x4B0710` is `CAIUnit::DoUpdate` |
| `CEU3AI_DistributeFleetsToTheatres`, "the largest unmet naval want" | two rules: submarines by `submarine_want`, surface fleets by a share; nothing moves with no enemy ship sighted |
| `+0x23C`, "what it counts was not read" | the air distributor's tally alone |
| `0x490DB0`'s `+0x58` gate | `CAIUnit +0x58` is the sealift port |
| `WAVE.md`: "STAVKA holds them all at the start" | the start save spreads the Soviet divisions over nine theatres already; STAVKA keeps 13 throughout |

A root agent's "slot 65" test is `mov al,1` (the folded body `0xA92590`) on `CAIUnit`, always true in these bodies.

### F.8 What looks wrong and is what the bytes do

1. Connected donors are asked most short first; unconnected donors most surplus first.
2. A theatre whose need is 0 reads as exactly full (ratio 1.0).
3. A donor at war with an attacking stance (3 or 4) can be stripped by a taker at peace; a defending one cannot.
4. A war-candidate taker may be filled to three times its need (minGive).
5. The power moved with a rolled-up command is its own headquarters brigade's alone, `GetPower` walking one unit
   (inferred).
6. A fleet's size counts its transports where an agent's holding does not; one submarine makes a mixed fleet a
   submarine fleet.
7. The air distributor gives a unit to the first agent that qualifies, not the best; an orphan bomber goes to the first.
8. The capital pull moves a whole air group, or a land division, for one transport plane or paratrooper brigade, with no
   tally.
9. The transport guard uses the taker's own r and have to decide whether it may take from an agent with its own sealift.
10. `0x4BEF30` is worked out in the pick and never used on the path taken.

### F.9 Not settled

- The thresholds against needs: `divisions_needed` comes from `EstimateTheatreNeed` and is not saved.
- Whether Arkhangelsk and Leningrad carry `+0x365` - no save records it.
- What fills `+0x25C` at peace (`AssignSeaTargetsToAgents`, the third piece).
- What combat slots 8 and 12 ask in `CAIUnit_UnitMayLeave`; `CountDivisionsInArea`'s region-group arm (decompiler only).
- 'Eolo''s move; why the Far East got the smaller 5th Transport Squadron (likely when each theatre's tonnage appeared);
  which day each move happened, the saves being three and a half days apart.

## G. What puts the history's units under the theatres: the sort at the first AI pass

*Reader G, read after A to F landed. It corrects A.2 step 10, A.6 and A.7's last row, and `FINDINGS-theatres.md` K and
O.*

**In one paragraph.** At each country's first AI pass - in a new game the first frame after the first hour - `ProcessAI`'s
readiness gate finds every theatre with a headquarters and, before it returns, calls **`CEU3AI_SortUnitsIntoTheatres`**
(`0x48D560`, which the record held as `AnnounceLoadedUnitsToScreen`). That walks every unit of the country: works out
where it counts as standing - a fleet or air unit by its base, a land unit by its place where the country controls it,
otherwise by the nearest headquarters - takes the theatre stamped on that province, and climbs the order of battle while
each parent stands in the same theatre; where the climb meets a parent standing elsewhere, the unit below it is
**detached and attached under its own theatre's headquarters**, and a top-level unit is attached outright. So whole
fronts, armies, corps and single divisions are taken out of commands standing in other theatres, and the history's
top-level fleets, air groups and armies go under the theatre where they stand. Units on another country's land, or on land
no theatre of theirs covers, stay; nothing marches, nothing is disbanded, and a command the sort empties stays.

**Exe-hardcoded**: the whole rule - the climb and its stop, the carrier-wing skip, the search's first best of 1,000,000.0,
its strict `<`, its first of equals and its moving reference, the order of the theatres it searches, the flag that spares
the player's units held by lower agents, and when it runs. **Mod-able**: where the units stand and what they are based on
(`history/units/*.txt`: `location`, `base`, nesting), `is_cag` in the unit files, and the map and all the theatres are made
from (`FINDINGS-theatres.md`). It reads no define and no Lua.

### G.1 When

1. **`ProcessAI`'s readiness gate** (`0x4897E8`, the call at VA `0x88984D`): while `theatres_changed` (`CEU3AI +0xA6`) is
   set and every theatre's `unit` resolves, the sort with `flag = (country id == CCurrentGameState +0xC34)`, then the byte
   cleared and the pass returned (A.2 step 10). The constructor seeds the byte to 1, so **every country's first AI pass
   sorts**, the played one's too; the theatre layer sets it again only for a country nobody plays
   (`played_countries_array[id] == 0`), at VA `0x8ABAA4` and `0x8ABB77` in `BuildTheatres` and `0x8ABF22` in
   `RefreshTheatreProvinces` (a byte scan of `.text` for writes to `+0xA6`, the control the gate's own clear, which it
   found); its only clearers are the gate (VA `0x889852`) and a loaded game's first pass (VA `0x8896BC`). So **an AI country
   is sorted again at its next pass after a theatre is made or deleted** - "made or deleted" for the three sites being A's
   reading.
2. **Its other callers**: `CInGameIdler::Update`'s one-off multiplayer kick, for each country not played (`0x2561C5`, flag
   0); `ApplyCustomGameSettingFaction` (`0x1C460`, flag 1); `CProductionView::BuildSliders` (`0x3FCA12`, flag 1);
   `CAddDivisionEffect::Execute` (`0x5B5DD5`) and `CLoadOOBEffect::Execute` (`0x5BBE22`), each only with `CCurrentGameState
   +0xD0C` set and the country the player's (flag 1).

The start save holds the sort's result and no `plan` block at all - what one AI pass ended at the gate leaves, the binding
that posts the plans coming at the next (A.6) - which bears out A.1's inference that one pass, the first frame's, ran before
the save.

### G.2 The sort (`CEU3AI_SortUnitsIntoTheatres`, `0x48D560`, `ret 8`, read whole)

**Pass 1**, over the country's units (`CCountry +0xBAC`) in list order - after a load, post-order, children before their
parents (`CCountry::LoadKey` loads a top-level unit and then `AddUnit`s it, VA `0x4CD9D3`, `0x4CD2B3`; `CUnit::LoadKey`
loads a child, attaches it and then adds it, VA `0x5B76AB`), the headquarters the first hour made last. For each unit U:

1. Passed over at level 0.
2. P = `CEU3AI_GetUnitTheatreProvince(U)` (G.3), T = the theatre stamped on P (`CMapProvince +0x380/+0x384`); passed over
   unless T exists and is the country's (`CTheatre +0x80 == CEU3AI +0x24`).
3. **With the flag set** (the player's call) and T's headquarters bound to an agent (`CUnit +0x198`), passed over where the
   nearest agent up U's chain (`CUnit_FindNearestAgent`, `0x1B6E60`) answers slot 65 true and its unit (slot 74) is not of
   level 0 - a unit held by an agent below theatre level is left alone.
4. **The climb**: cur = U; while cur has a parent and is not of level 0 - where the parent's province (by the same function)
   is stamped T, cur = the parent; otherwise stop, and **cur is listed**. A climb reaching the top, or a level-0 unit, without
   leaving T lists nothing - the test is on U's own parent (`[esp+0x14]`, set once at VA `0x88D6D0`), so the one exception
   is that **a U with no parent at all is listed itself**.
5. A listed unit goes on a local list once (by pointer), in the order first found.

**Pass 2**, for each listed unit A in order: passed over if it is an air unit (slot 17) holding a carrier wing
(`CSubUnitDefinition +0x32`); P, T and T's headquarters found again, passed over if the headquarters does not resolve; if A
has a parent, `CDetachUnitCommand(A)`; then `CAttachUnitCommand(A, headquarters)` - both through `in_game_screen` slot 18,
`+0x38`, slot 6, the session's post, so they run at the next drain. The attach puts A **last** under the headquarters.

So **which units move**: every unit whose parent stands in another theatre, or in none of its country's, and every top-level
unit - where its own province is in one of its country's theatres. **Under which headquarters**: that of the theatre stamped
on its own province. **In what order**: that in which its first descendant, or itself, comes in the unit list.

### G.3 Where a unit counts as standing (`CEU3AI_GetUnitTheatreProvince`, `0x48DA40`)

Unit in EAX, the AI on the stack (`ret 4`); the first rule that answers wins:

1. **A land unit aboard a fleet** (`CArmy +0x300`): the last province of the fleet's path (the node at `CUnit +0x13C`), where
   the path is not empty (`+0x140`) and that province is land the country controls; otherwise the fleet's base (`+0x98`,
   slot 0), where it has one.
2. **A fleet carrying anything** (`CNavy +0x2EC`) with a path: the path's last province, on the same test.
3. **The unit's own base** (`+0x98`), whoever controls it - what places fleets and air groups.
4. **Its destination** where the country controls it; otherwise **its place** (`+0x130`) where the country controls it.
5. **Otherwise a search** from R (the destination where there is one, else the place): best = 1,000,000.0, cur = R; over the
   country's theatres (`CCountry +0x570`) in order whose headquarters resolves - that headquarters' place is answered at
   once where R's area is real, `CCountry::CanOperateIn(R's controller)` holds and **`CTheatre_CoversArea`** (`0xB1170`)
   holds (the area is the theatre's own country's, or one of its focus areas); otherwise, where `(float)
   DistanceBetweenProvinces(cur, its place) < best`, best is that and **cur becomes that headquarters' place** - each later
   distance measured from the last best headquarters, not from R. The answer is cur.

### G.4 Against the start save

Scratch `wave/G/sim.py` runs G.2 and G.3 on each country's history order of battle (the oob file `history/countries`
names, the `tfh` layer first) with the save's theatres, stamps, headquarters and controllers and distances from
`map/positions.txt` (an approximation of `CMap`'s centres), the posted commands applied in order, and sets the result
beside `Germany1936_01_01_00`: **all 78 countries with theatres, 1555 of 1555 units' parents, and the children of all 108
theatre headquarters in order.** The 24 units not matched are all carrier air units made at load from carriers' wings,
which stay with their fleets - which the carrier-wing skip guarantees. With the sort switched off, 535 parents and 100 of
the 108 lists of children differ. No country's history leaves a theatre-level unit unadopted, so the theatre layer's
disbands (`FINDINGS-theatres.md` J.3) and K's orphan rule play no part.

- **Poland**, 60 of 60: its eleven top-level units each listed for having no parent, every one standing in Warszawa's
  theatre (stamp 199), so all eleven go under Warszawa HQ in list order and Lwów HQ gets nothing - not the first new
  headquarters' orphan rule.
- **The Soviet Union**, 243 of 243, 46 posts: `14ya Armiya` (at 46, Arkhangelsk's theatre) taken out of the Leningrad
  Front (782, Leningrad's) and put under Arkhangelsk HQ; `54.` and `71. Strelkovaya Diviziya` (582, 508) taken out of `7ya
  Armiya` (742), which is left empty; the Leningrad Front itself from STAVKA (1409) to Leningrad HQ; the South West Front
  before `5th Cavalry Corps` under Odessa HQ, the first unit of the list leading to it being a division of the 31st Army
  Corps.
- **The United States**, 72 of 72: the top-level **Philippine Force** at Manila (held by PHI) takes the search; the theatres
  in order are CONUS West (San Francisco), CONUS East (Washington), Pacific (Honolulu) - San Francisco 6948, then Washington
  from San Francisco 3029, then Honolulu from Washington 4716 - so **CONUS East Theater**, as the save has it, where a fixed
  reference would give Pacific (5091 against 6948 and 9786; the distances approximate). The Asiatic Fleet and the 2nd USN
  Submarine Fleet are based at Manila, stamped with PHI's theatre, so are passed over - the two top-level fleets of A.6.
- **Japan**, 122 of 122: its units in Manchukuo come under Kwantung; the two air units based at 7139 (held by MAN) are passed
  over, and the agents' orphan attach of the second hour (A.3, A.6) takes these four left over.
- **Germany**, played, 65 of 65: the flag spares nothing, no agent being bound yet.

### G.5 Corrections to the record

| record | read |
| --- | --- |
| `0x48D560` `AnnounceLoadedUnitsToScreen`, "tells the interface about a country's units", "a 0x64 byte object handed to a virtual on `in_game_screen`" (`FINDINGS-effecttext.md`, `FINDINGS-oob.md`; `FINDINGS-ai.md`, "almost certainly the `CAIUnit` agent refresh") | `CEU3AI_SortUnitsIntoTheatres`; the objects are `CDetachUnitCommand` (0x64) and `CAttachUnitCommand` (0x8C), and the call is their post (G.2) |
| A.2 step 10 and A.6, the first frame: the gate "finds its headquarters and returns" | it sorts every unit under the theatre it stands in first; the start save's order of battle is that sort |
| A.7's last row, and `FINDINGS-theatres.md` O: the history's top-level units are put under a theatre by `CEU3AI_BindAgentsAndAttachOrphans` and K's orphan rule | by the sort, at the first AI pass; the agents' second-hour pass takes only what the sort leaves - units placed on another country's land |
| `FINDINGS-theatres.md` K: history headquarters with no theatre "are disbanded in the country's first hour, and their children hang under the next headquarters the country is given" | true as a rule, but no TFH 1936 country leaves one, so nothing is orphaned and K's attach moves nothing. `CUnit +0x50` has no writer but `RemoveUnit` (a byte scan of `.text` for `mov byte [reg+0x50]` with a non-zero immediate or a register, disp8 only: 53 sites, the only `CUnit` ones the constructor's zeroing, VA `0x5B508E`, the positive control, and `RemoveUnit`, VA `0x68500E`) |
| `CAddDivisionEffect::Execute`: "AnnounceLoadedUnitsToScreen tells the player" | the sort, only with `+0xD0C` set and the player's country |

### G.6 What looks wrong and is what the bytes do

1. The nearest-headquarters search measures each distance from **the last best headquarters**, not from the unit: the
   Philippine Force goes to CONUS East, not to Pacific.
2. A fleet or air unit is placed by its base **whoever controls the base**, so one based on a puppet's or an ally's land is
   passed over, where a land unit there takes the search.
3. A unit is taken out of its command whenever its parent stands in another theatre: commands are left empty (`7ya
   Armiya`) or split across theatres, and nothing forms them again.
4. The test is against the parent only, so a unit two levels below a command standing elsewhere stays where its own parent
   is in its theatre.
5. Only the player's call spares units held by lower agents; an AI country's re-sort after any theatre change has no such
   test - that it would pull a `CAIInvasion`'s units back is inferred, its slots 65 and 74 not read.
6. A re-sort would also undo F's moves for divisions standing in the donor's theatre; Poland's 20 divisions under Lwów HQ
   in `_01_04_12`, still standing in Warszawa's theatre, show none happened for Poland in those days.
7. A parent whose province came back null would make the climb loop for ever (VA `0x88D6EC`-`0x88D725`); nothing reaches it.
8. `CTheatre_CoversArea` answers true for any area of the theatre's own country, not only its own theatre's.

### G.7 Not settled

- `CMap`'s own province coordinates (`+0x2C/+0x30`) were approximated by `positions.txt`; only the Philippine Force rests on
  distances. The `CanOperateIn`/`CoversArea` short cut was approximated in the simulation; nothing in the start save hangs
  on it.
- How often VA `0x8ABB77` fires (each theatre kept, or only made), and with it how often an AI country is sorted again in a
  running game - A's reading.
- Which frame drains the commands posted at the first pass; the save shows only that they had run.
