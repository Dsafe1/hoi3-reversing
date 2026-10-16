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
