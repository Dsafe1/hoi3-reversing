# The script and AI-Lua gaps

Read 2026-11-09 for OpenHOI3's remaining script and AI-Lua pieces. Addresses are rvas unless marked VA. Only valid for this build of `hoi3_tfh.exe`. Every figure is marked **hard-coded** or as a define in `common/defines.lua`.

## 1. `num_of_ports` and `total_num_of_ports`

Already recorded (`CNumOfPortsTrigger::Evaluate` 0x5D84D0, `CTotalNumOfPortsTrigger::Evaluate` 0x5D8A50, `FINDINGS-ministers.md` A.6). Checked on the listing. Both are integer triggers, `country counter >= N`, scoped to the scope's country (`scope->country_id`).

- **Where the counters are made:** `CCountry::RebuildNeighbours` (0xE21E0), zeroed at 0xE247F/0xE248B, for each province of **`OwnedProvinces` (+0xCF0)**.
- **What counts** (VA 0x4E2A6D-0x4E2AC0): province `owner (+0x330)` is real, `port (+0x354)` is non-null (a `CPort` from `positions.txt`'s naval base position, on a sea pixel that is not landlocked water), and `naval_base (+0x300)->level_max (+0x20) > 0`.
- **`total_num_of_ports` (+0x1060):** every such owned province, whatever its controller and however damaged (`level_max`, what was built, not what works).
- **`num_of_ports` (+0x105C):** the same, restricted to provinces whose area (+0x2B4) equals the acting capital's area. So a colony's port does not count towards the `num_of_ports = 1` the naval technologies demand.
- **Staleness:** the figures are as of the last rebuild (daily and on diplomatic changes).
- Hard-coded: the two tests. No define.

## 2. `surrender_inherit` (`CSurrenderInheritEffect::Execute`, 0x5AA4B0)

`AnnexCountry(countries[scope], surrender 1, TAG)`: **the scope annexes TAG**, with no test of the tag. `FINDINGS-surrender.md` A.3 reads `AnnexCountry` whole; the difference from `inherit` is only in the surrender branches. In order:

1. The world is told `ANNEX`, at TAG's capital.
2. **Candidates:** TAG's `non_hostile_countries` that are at war with the annexer. Without a war this list is empty.
3. TAG leaves its faction.
4. **Provinces:** one TAG owns and another country (not REB) holds stays with its occupier; otherwise the annexer owns it, and in surrender mode a neighbouring area held by a candidate takes **control** of it.
5. **Constructions** are deleted. Nothing is refunded.
6. **Active mission** cleared.
7. **Expeditionaries:** units lent to TAG go home shattered; units it lent out are recalled and destroyed in the next step.
8. **Every other unit is destroyed**, except that in surrender mode a unit with a candidate takes one draw (hard-coded even/odd): even, it goes over and its children stay behind; odd, destroyed. Leaders are taken off (not killed).
9. Land TAG occupied goes back to its owners.
10. **Rebuilds** of area and supply groups.
11. **Wars, pacts, spies, debts:** TAG is taken out of each war; alliances, dependencies, guarantees and trade routes are deleted; `CDiplomacyStatus::Reset` runs on **the other country's side only**; threat falls by 9999.000 (hard-coded) both ways, floored at 0.
12. `PickDepot` on the annexer's supply groups.

**Left behind:** TAG's stockpile, manpower, technology, leaders, ministers, laws, capital, its own diplomatic side (NAPs, casus belli, debts). Nothing marks it dead.

**The shipped use:** `tfh/events/France.txt` event 2911, option A: `surrender_inherit = VIC`, trigger `tag = FRA`, France holds 2613 and 3351, `VIC = { war = no }`. Scope France, TAG Vichy. With Vichy at peace the candidate list is empty, so the surrender branches never run and it behaves as `inherit = VIC` (every Vichy unit destroyed, inferred from the trigger).

## 3. `create_alliance`: the ACCEPT arm

`CCreateAllianceEffect::Execute` builds a `CAllianceAction { actor scope, recipient TAG, type 2 ACCEPT, value 1 }`, calls `CAllianceAction::Apply` (0x618D70), deletes the action. Read on the listing (VA 0xA194DE on); the record's comment on that arm is accurate and this confirms it:

- `new CAlliance` (`first` actor, `second` recipient, `start_date` the action's date); slot 10 `Activate` writes it into both `CDiplomacyStatus +0x14` and sets `changed`; appended to the relation list (`CCurrentGameState +0xB2C`).
- `ChangeRelation(actor, recipient, ALLIANCE_RELATION_CHANGE)` (define, 15.0 in TFH's `common/defines.lua`, read one-sided as `diplomacy[0x10]`). Applied once, actor towards recipient.
- `diplomaticsuccess` with `MILALLACCEPT` (actor played), `MILALLWEACCEPT` (recipient played), `MILLALLINVACCEPTOTHER` otherwise.
- `CCountry::RebuildNeighbours` and `CCountry_AfterDiplomacyChange` on both countries.
- **No check of any kind.** No influence cost (the cost is in the PROPOSE arm). Nothing tests for an existing alliance: a second `create_alliance` overwrites both status pointers and leaves the old `CAlliance` on the relation list. Nothing tests `at war`, faction, or `TAG == scope`. It touches no war and no faction; allies reach each other's wars only through `CDeclareWarAction`'s call-to-arms offers.

## 4. The undeclared war

### 4.1 What it is

`CDiplomacyStatus +0x24` holds a `CUndeclaredWar` (attackers, defenders, regions, provinces) shared by both directions. It is held on `CCurrentGameState +0xC10` (head, +0xC14 tail, +0xC18 count), saved as `undeclared_war` with `attacker`, `defender`, `region` entries in that order (0x75E70), read back by `LoadKey` through `AddAttacker`/`AddDefender`/`UndeclaredWar_AddRegion`.

**Only `CUndeclaredWarRegionEffect::Execute` (0x5BCF00) starts one.** It reuses the pair's war or makes one with the scope as attacker and `target` as defender, appends `region` **every time** (duplicates kept), links the war to +0xC10 once, calls `OnDiplomacyChanged` on both. The effect has exactly two keys, `target` (a tag, `this` or `from`; no target: the controller of the scope's province) and `region`. Any other key parses as a child effect that `Execute` never runs. No enemy test, no message.

**`CCountry +0xACD in_undeclared_war` and the opponents list +0x1018** are set by `UpdateUndeclaredWars` (0xE6EE0), called only from `AddAttacker`, `AddDefender` and the two `Remove*`.

### 4.2 How it ends

- **Declaring formally ends the pointer on one side only.** `CDeclareWarAction::Apply` (0xA1239F, VA) zeroes `S+0x24` on **the actor's** status, unlinks the war from +0xC10, deletes it through slot 0 (`FINDINGS-war.md` A.2 step 3). `CCallAllyAction::Apply` (0xA2871B) does the same, confirmed in the decompile (`local_108->undeclared_war = 0`, `CList_RemoveValue`, delete). The other direction keeps a dangling pointer, and `+0xACD`/`+0x1018` are not recomputed (`UpdateUndeclaredWars` has no caller on this path). Once the pair is at war `IsEnemy` answers earlier on `War`, so the dangling pointer is read only after a later peace (reading freed memory: inferred from the code shape, not provoked).
- **`RemoveAttacker`/`RemoveDefender`** run only from `CGameState::ResetSession`.
- **`CDiplomacyStatus::Reset`** (annexation, the other country's side) zeroes +0x24 one-sidedly; nothing unlinks the war from +0xC10.
- **No peace, event or decay ends it.** The only trigger is `undeclared_war_with` (0x5EA480), `status +0x24 != 0`. `war = yes/no` reads `+0xACC` only, so `undeclared_war_two`/`three`'s `war = no` still passes.

### 4.3 Consumers

**The test:** `at war, or REB on either side, or (status +0x24 set and UndeclaredWarCoversProvince(war, province))`. The province test is a region match: is the province in any of the war's regions. Every consumer below is a site of that shape.

**Direct calls to 0x763A0 (29) and inlined copies:**

| VA | function | what it decides |
| --- | --- | --- |
| 0x42F266 | `CCountry::IsEnemy` (province form) | The universal hostility test; see the IsEnemy list below |
| 0x430CD7 | `CCombatManager::CheckForCombat` | Whether a land unit's stack starts a battle against another unit there |
| 0x5C024F | `CUnit::CanEngage` | Whether a unit may fight another in that province, the battle filter |
| 0x5D5EAD | `CUnitList::AllHostileTo` | Bombing/combat: every unit of a list counts as hostile to the candidate |
| 0x4A1DB9 | `CMapProvince::TakeControl` | Who a province passes to on walking in (a vassal's chain walks up its overlords on the same test) |
| 0x59A12A | `CAirConvoyRaid::PickProvince` | Which province's convoys an air raid weighs |
| 0x5D1485 | `ResolveConvoyRaid` | Whether a convoy in reach counts as an enemy (raider's own province must be covered) |
| 0x5D3AE9 | `CUnit::PathCrossesEnemyProvince` | Whether a path crosses enemy ground |
| 0x5D6A6D | `EnemyAirStrengthIn` | The enemy air count over a province |
| 0x88CC05 | `CEU3AI_AssignSeaTargetsToAgents` | Enemy fleets/convoys handed to agents |
| 0x894184, 0x894B4F, 0x895E4B, 0x896DE5 | invasion layer (`PickInvasionLandingProvince`, `PickNearestInvadableNeighbourProvince`, `RankInvasionAreas`) | Which areas are invasion targets |
| 0x8B10D1 | `CAIUnit::OnProvinceControllerChanged` | Agent told an enemy took a province |
| 0x8B1626, 0x8B1A81 | `CollectUnitsMovingIntoProvince`, `UpdateThreatenedProvinces` | Landing threats |
| 0x8B3D79 | `CAIUnit::RebuildHoldProvinces` | Which provinces to hold |
| 0x8B6AB0 | `ComputePlanForces_LandWants` | Land force wanted |
| 0x8BA9E2, 0x8BB1DB, 0x8BE111 | `CAIUnit::SetArea`, `ClassifyOpsAreaFrontier` | Ops area and frontier |
| 0x8C9BC5, 0x8CB426, 0x8CC2A5, 0x8D753D | `FillLinePositions`, `FillGarrisons`, `CheckLandMarches`, `ManageLandUnits` | Land block's positions and marches |
| 0x8DB462, 0x8DB4CB, 0x8DBBE0 | `CAIUnit` slot 76 plan builder (the human's delegated AI) | Delegated theatre planning |
| 0x8B5B84, 0x8B72E1, 0x8B768E, 0x8BC6E4, 0x8CD4B0, 0x8D72B3, 0x8DB8B6 | inlined copies: `ComputePlanForces`, `RebuildFrontAndApproaches`, `PlanParadrops`, `ManageLandUnits`, slot 76 | The same test inlined |

**The province-taking `CCountry::IsEnemy` (0x2F210)** has 101 call sites and every one but VA 0x8CC149 (`CheckLandMarches`, `xor edi,edi`, so no undeclared-war answer there) passes a province. So an undeclared war is hostile at those sites only in covered regions:

- Province/owner: `TakeControl`, `Province_SetController`, `IsFrontProvince`, `UpdateProvinceBlockaded`, `HasEnemyNeighbour`.
- Orders: `CSupportAttackOrder`, `CStrategicRedeploymentOrder`, `CAirOrder::UpdateStrike`, the runway/strategic/ground/port/naval strike checks, `CAirInterceptOrder`, `CAirPatrol`, `CParadropMission`, `CNukeMission`, `CNavalInvasionOrder`.
- Unit: `IsMovingOntoEnemyGround`, `HasEnemyLandUnitIn`, `CanMoveTo`, `IsNextProvinceEnemyHeld`, `CanRetreatToProvince`, `FindRetreatProvince`, `CMapProvince::CanUnitReach`, `UnitBlockadesProvince`, `CancelMovement`, `SetUnitPath`, `AdvanceMovement`, `CheckBase`, `DropCarried`, `UpdateDaily`.
- Strength counts: `EnemyLandStrengthIn`, `CountEnemyLandUnitsInList`.
- AI: the rest of `CEU3AI` and `CAIUnit` (invasion, recall, sealift, garrison, line, air phase 4, convoy raid scoring).

**The Lua-registered `IsEnemy` (0x2F1B0)**, about 113 callers, takes no province and **never** sees an undeclared war.

**`CCountry +0xACD`** (11 readers, all AI, each a gate `at_war || in_undeclared_war`): `CAIUnit::Tick` (0x8B0B95, 0x8B0CD5: land pass one hour in three), `ManageAirUnits`, `AirPhase4_SortWingsIntoMissionPools` (0x8CF0C4), `AirPhase4_IssueAirIntercept` (0x8CF64F), `ManageNavalUnits` (0x8D08C6 and four more), `NavalConvoyRaid_ScoreConvoyRoutes` (0x8D26EA), and the rebase chooser (0x8D328B). Everything else is the human's.

**Opponents list +0x1018:** `CEU3AI_AssignSeaTargetsToAgents` (VA 0x88C1EA, enemies then undeclared opponents) and `NavalConvoyRaid_ScoreConvoyRoutes` (0x8D25F9).

**On screen:**

- `MapMode_Naval_Colour` (0x8675FB, orange over the regions of the player's undeclared wars).
- `CUndeclaredWarWithTrigger::GetText` (`IS_AT_UNDECLARED_WAR_WITH`, one code reference, VA 0x9EA7F8).
- `CUndeclaredWarRegionEffect::GetText` (`ADD_UNDECLARED_REGION_EFFECT`, one reference, VA 0x9BD273).
- No diplomacy-screen row and no war row (the `+0xE28` chain sweep found no interface reader).
- Scripts: the two literals in event and decision text; no Lua method exists.

**Not counted:** `+0x20` (`War`) gating in the many war-only sites (e.g. `CountEnemyUnitsInArea`, war exhaustion, the war rows) ignores undeclared wars.

**False positives excluded (each read in place):** 0x477F32, 0x4E424C/0x4E4E11/0x4E536B/0x4E54A9, 0x89B966, 0x8A91ED, 0x9E850A/0x9E85AE, 0x9EDB41, 0xA43665, and the byte accesses at 0xA12C4B-0xA4BE9C.

### 4.4 What a player would notice, ranked

1. In a covered region (TFH: the three Atlantic regions, USA as attacker against GER), the two sides' fleets and air fight as if at war (`CheckForCombat`, `CanEngage`, `AllHostileTo`), with no diplomatic state, row or casus belli.
2. Convoys are raided by the other side in covered water only (`ResolveConvoyRaid` tests the raider's province).
3. The naval map mode paints those regions orange.
4. Blockades and land movement treat covered provinces as enemy (`UpdateProvinceBlockaded`, `CanMoveTo`), which matters only if a mod lists land.
5. The AI treats the opponent as a target there and runs its war-time air and naval blocks.

Formally declaring ends it silently; nothing else does. `undeclared_war` (mod-able) has no cost, message or relation effect of its own.

## 5. Lua answers

### 5.1 `CEU3AI::CanDeclareWar` (0x49B110)

False when `target` owns no province. Otherwise builds a `CDeclareWarAction` (actor, target, type 0, value 1, today, empty goal) and returns **`CDeclareWarAction::IsSelectable`** (0x615E50), the same conditions as the player's row (`FINDINGS-war.md` A.10): actor != recipient, recipient owns a province, influence >= `WARDEC_INFLUENCE_COST` (define, 0.0 in TFH), no diplomat en route, no war/alliance, not REB, no truce, not one faction, puppet rules, breakable NAPs, effective neutrality <= `GetMaxNeutralityForWarWith`, no land unit of the actor in a province the recipient controls. `IsValid` (slot 13, war goal) is not asked.

### 5.2 `MayLiberateCountries`, `CanCreatePuppet`, `IsCapitalSafeToLiberate`

Already confirmed; not re-derived.

- `MayLiberateCountries` (0xEE100): `GetPossibleLiberations()->count != 0`.
- `CanCreatePuppet` (0xEE550, the record's `MayReleaseVassals`): `GetPossibleVassals()->count != 0`.
- **Both rebuild one shared list, `+0x11E0`**, so asking one throws away the other's answer.
- `IsCapitalSafeToLiberate` (0x4A1B20): `FINDINGS-government.md` E.5.

### 5.3 Tribute

**Paid daily by `CCountry_PayTributeToOverlord` (0xF25E0)**, called at the end of `CollectDailyProduction` for a subject (`FINDINGS-capitalreaders.md` section 4). Excess above **2000.000** (hard-coded) of money, crude, metal, energy and rare materials; supplies and fuel never; nothing where the puppet's acting capital differs from its capital, in exile, or the overlord owns nothing. Destination: the overlord's stockpile where an area of the overlord's touching the puppet's home area is its acting capital's or has no harbour; otherwise a harbour province's pool, unrecorded by any ledger.

**The Lua reads it only through `GetDailyIncome/Expense/Need/Balance`** (+0x8FC `tribute_received` added to income; +0x920 `tribute_sent`, held negative: subtracted from expense, added to need). There is no separate Lua method: a search of the registrations for "Tribute" finds none, `.rdata` holds no such string, and the base-game and TFH Lua do not mention it. Positive control: the same searches find `GetDailyBalance`.

### 5.4 `GetTechModifers`, `GetFolderModifers`

The getters return `CAITechMinister +0x60` and `+0x70` (float arrays, rebuilt monthly by `RebuildTechModifiers` 0x4AECA0 and `RebuildFolderModifiers` 0x4AEF40; `FINDINGS-ministers.md` A.2 has the formulas). **Nothing in the executable or any shipped script reads them**: `tfh/script/ai_tech_minister.lua`, the base game's and BlackICE's scripts have no call; only BlackICE's `LUA API.txt` lists them.

### 5.5 Commands the Lua posts

`CCreateVassalCommand(vassal, overlord)` and `CLiberateCountryCommand(liberated, liberator)` are the same classes as the player's, with the same constructor and `Execute` (`LuaConstruct_*` thunks at 0x589DB0 and VA 0x989EFF). No difference.

## 6. `load_oob` in a running game

**Order, from `CLoadOOBEffect::Execute` (0x5BBD00):** `SetOobFile`, `LoadOobFile`, and then, only where `+0xD0C scenario` is set (null in a game loaded from a save) and the country is the player's, `CEU3AI_SortUnitsIntoTheatres(its AI, 1)`.

**`LoadOobFile`:** does nothing where the name is empty, or where the country owns no province and is not `REB` (hard-coded gate). The file is found through three path forms or skipped silently.

**Per brigade** (`CUnit::LoadKey` regiment/wing/ship cases; `CSubUnit::CSubUnit`):

- Constructor (hard-coded): strength **100.000**, organisation **100.000**, experience **-1.000** ("not given"), `historical_model` -1, `strength_ceiling` 0. A file's `strength`/`organisation`/`experience` keys overwrite them.
- `CSubUnit::AfterLoad` with a `historical_model` (every shipped line has one): levels applied, then `strength = min(strength, GetMaxStrength(1,0))`, `organisation = min(organisation, GetMaxOrganisation(1,0))`, `strength_ceiling` raised to strength.
- Without a `historical_model`: every level 0 and the 100.000s stand.
- **The difference from a new game:** with `in_game` set, `GetMaxOrganisation` runs its factors; in a new game `in_game` is clear and organisation is the type's plain `default_organisation`. A running game's brigade therefore starts at its ceiling including factors. (The army commander's bonus is 0 during the load: the parent link is not made until after the child's Load returns. Inferred.)
- **Experience is not filled in.** The new game's replacement (`UNIT_START_EXPERIENCE`, a modifier, in `CInGameIdler::Enter`) does not run. The six readers of that modifier are `Enter` (twice), the build-queue's two, and `CCreateNewHQCommand`. Experience stays -1.000 stored; `ExperienceWithPride` and `GetAverageExperience` floor it at 0.
- A reserve brigade's strength clamp comes from the same `GetMaxStrength`.

**Ids:** unit and brigade alike, at each block's close: no id in the file mints `{0x29, counter++}` from `0x170AF78`; a file id is kept and the counter pushed past it (`FINDINGS-oob.md`). Brigades mint first, then their unit, children before parents. An `id` colliding with a live object is not checked.

**Placement: at once, on the map.** `location` (`CUnit::LoadKey`) calls `EnterProvince` while the file is read; `CUnit::AfterLoad` enters it again after the brigades are added. There is no deployment unless the file uses `unit_deployment`.

- A location missing from the map becomes province **1** and logs (`loaded_from_save` clear only); enemy-held or low-infra starts log only.
- **A top-level unit with no `location` is deleted silently** (`CCountry::LoadKey`, `current_province_ptr == 0`), and so is a child unit without one (`CUnit::LoadKey`, same test). Air/navy too; `base` alone does not place the unit.

**Leaders:** the `leader` key is honoured: `SetLeader(unit, leader, 0, 0)`, the id looked up across the whole game, no check of country or rank (`FINDINGS-leaderassign.md`). **No other assignment happens:** `AssignBestLeader`'s nine callers are `CInGameIdler::Enter`, custom game, `CUnitDeployment::JoinUnit`/`DeployAt`, `CMergeCommand`, `CTransferSubUnitCommand`, `CCreateHigherCommand`, `CCreateNewHQCommand` and `CUnitSplitCommand_TakeSubUnit`. So a `load_oob` unit with no `leader` line has the null leader.

**`military_construction` and other country-level keys.** The file is read as a piece of the country's save block. `military_construction` makes a `CMilitaryConstruction`, `EnqueueConstruction` appends it to the queue's tail (and clears its location), then loads it; `CMilitaryConstruction::AfterLoad` mints its id. `unit_deployment` appends with no de-duplication (`FINDINGS-oob.md`). Every other of the 119 country keys acts directly on the live country with none of a new game's follow-up. **Neither shipped file uses one:** `AnschlussOOB.txt` has only `corps`, `division`, `air`; `destroyers_for_bases.txt` only `navy`.

**What runs afterwards:**

- **`CCountry::AfterLoad` (0xD2500)** runs at the close of the file (when the parse context holds no message): `CTechnologyStatus::ReapplyAllTechnologies` (reapplies every technology's effects), the ruling-party fallback, `CIdeologyData_NormaliseToHundred` twice, `CCountry_AllotCabinetSeats`, and each military queue line's `RegisterUpgradeTarget`.
- Per unit `CUnit::AfterLoad`: `RebuildDefinition`, `RebuildAvatar`, slot 18 (`CheckBase` for fleets and air units).
- `RecountUnitTotals` runs hourly anyway.
- **Not run:** officers added, supply rebuild, leaders, the new game's experience pass, or `SetUpCountryForNewGame` work. No theatres except the player's sort above.

## Not established

- `EnterProvince`'s full path was read only to the point of placement; **whether a `load_oob` unit starts a battle at the moment of placement** is not read (combat otherwise starts from the hourly checks).
- Reads of `+0x24` reaching the status through a helper rather than `+0xE28` directly would be missed by the sweep. Method: all 29 direct callers; `+0xE28` chain within 25 instructions; province `+0x358` within 14 instructions of `+0x2C`. Positive controls: the war field `+0x20` found at 215 sites and the known 0x476096.. writers. The writer sweep (`gaps_w24.py`) missed the two formal-war clears (0xA1239F, 0xA2871B) at its 60-instruction window, which is why it does not stand alone as a negative.
- The dangling-pointer consequence after a peace is inferred, not provoked.
- The 73 `IsEnemy` call sites past those named by group were taken by the function they sit in (`gaps_ise.py`) and not each read for what they decide.
- `undeclared_war` with a land region: nothing in TFH uses one. The code path exists (region matching is generic) but only sea regions are shipped.
- `CUnit` slot 18 on `CArmy` is the empty stub, read off the table. The `RemoveAttacker` caller in `ResetSession` is on the one direct-call route only.
