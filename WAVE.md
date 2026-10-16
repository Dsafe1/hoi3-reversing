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

## The transport wave - carrying land units by sea and by air, the landing, and the carrier

> **LANDED 2026-10-15.** Four briefs, merged (104 address entries, 15 of them revisions; 6 structs declared, 36 fields;
> apply `failed: 0`, `struct fields: 0`); the write-up is `findings/FINDINGS-transport.md` sections A to D, indexed in
> `CANDIDATES.md`, where eight things it left are queued. Two corrections to this plan: the "carried-by fields"
> `+0x1C8/+0x2E4/+0x2E8` below are a land unit's dig-in, `staging_province` and `target`, and `+0x144`'s key is
> `transport_capability`.

Planned 2026-10-15, for OpenHOI3, on the maintainer's word that day ("Ok. Please continue with the next step"):
transport and invasion is the fourth of six pieces in his order ("3 - 2 - 1 - 5 - 4 - 6": the province view, convoys
in the build queue, weather, transport and invasion, the headless run, the AI). OpenHOI3 has fleets, their missions but
these two, the land march, the land and sea battles, supply and a carrier's air groups read off the order of battle -
and **no land unit ever boards a ship**. Four briefs; the write-up is **a new `findings/FINDINGS-transport.md`**,
sections A to D. **The AI's side is not this wave**: where it lands (`FINDINGS-invasion.md`), `CAIInvasion`'s stages
(`FINDINGS-theatre2.md`, `FINDINGS-aitheatre.md`) and its planning (`FINDINGS-aiplans.md`) belong to the AI piece;
cite them where they name a call, do not read them further.

**What is known and is not to be redone** - cite it; re-read on the listing only to settle what follows, to raise an
`inferred` record or to correct one:

- `FINDINGS-manpower.md`, "What an overloaded fleet does to its cargo": `CheckTransportOverload` (rva `0x1CFBD0`), the
  last of `CUnit::UpdateDaily` for a fleet - put ashore where the province's info byte `+0x22` allows, otherwise take
  a regiment apart until the load fits; `SumTransportWeight` (`0x1D6690`); `RemoveFromTransport` (`0x1CF120`, one
  write read). Which way round `+0x22` is was not settled.
- `FINDINGS-supplypass.md` section 5: `CNavy::UnloadCarried` (`0x1CFE10`) and `CAir::ReleaseCarried` (`0x1D0990`), and
  what a carried unit draws (the fleet's supplies; `PARASUPPLYPOOL_DAYS` for a dropped one). `CArmy +0x300`
  `carried_by`, `CUnit +0x2E4` the fleet's list of passengers, `+0x304` carried by air.
- `FINDINGS-movement.md` sections 5.1 and 5.2: a land unit at sea landing on the next province moves at
  `AMPHIBIOUS_INVADE_SPEED_BASE` + the fleet's `amphibious_invasion_speed` over `AMPHIBIOUS_INVADE_MOVEMENT_COST`.
- `FINDINGS-combatmods.md`: `BM_AMPH_PENALTY` (VA `0x569A63`) with `AMPHIBIOUS_LANDING_PENALTY` and
  `AMPHIBIOUS_INVADE_LANDING_PENALTY_DECREASE` (its `+0x218`/`+0x21C`/`+0x18C` unidentified); `FINDINGS-combat.md`:
  `CLandCombatant` slot 19 (rva `0x169B50`) interpolating `AMPHIBIOUS_INVADE_ATTACK_LOW`/`_HIGH` and
  `AMPHIBIOUS_INVADE_DEFEND_HIGH` "for a unit landing over water" - not read to the formula.
- `FINDINGS-seabattle.md` section 5: `CNavy::SendCarrierAircraft` (`0x1C7C70`). `FINDINGS-bombing.md` section 10:
  `CCarrierProtection` (slots 14, 17, 34) and a carrier's aircraft bombing. `FINDINGS-seaair.md`: the naval orders'
  frame and `CRebaseToCarrierMission`'s row. `FINDINGS-navalmissions.md`: the frame every naval order shares
  (`CNavalOrder::IsActive`, `IsTooWorn`, `HeadForNearestBase`, the return-to-base byte). `FINDINGS-airorders.md` and
  OpenHOI3's fleets-and-air spec: the orders window, where `Transport`, `Invasion`, `Paradrop`, `Rebase to
  carrier` and `Air Supply` are listed.
- `CSubUnitDefinition`: `is_transport` `+0x30`, `amphibious` adjuster `+0xAC`, `weight` (`transport_weight`) `+0x10C`,
  `transport_capacity` `+0x144`, `amphibious_invasion_speed` `+0x188` (the mean over brigades declaring one),
  `amphibious_invasion_defence` `+0x18C` (a plain sum), `carrier_size` `+0x190` (`IsCarrier` is it above nought).

**The savegames hold carried units**: a fleet's block holds each land unit it carries as a `division` block of its own,
with the passenger's `location` the fleet's. In the maintainer's game (`C:\Users\David\Documents\Paradox
Interactive\Hearts of Iron III\save games\`, plain text, Latin-1, read only) France's *Flotte expeditionnaire de
transport* - three `transport_ship` flotillas - carries the *Division de Tonkin* under a `transport` mission to province
6610 in `Germany1936_01_07_22`, `_01_08_02`, `_03`, `_06` and `_07` (at sea, `movement_progress` 7.5 to 45 over five
hours); in `Germany1936_04_20_03` a British and an Italian fleet carry divisions under `transport`. **No save holds an
invasion or a paradrop.**

**What OpenHOI3 needs that is not settled**, by brief:

| brief | what it settles | starting points |
| --- | --- | --- |
| **A. Carrying by sea** | **Boarding**: `CLoadArmyCommand` - its `Execute` (slot 6) and validity test (slot 14) whole, the call at VA `0x5E3B94` into rva `0x1CF040`; what may board what (a land unit, its children? a headquarters?), where (in port only? the same province, a naval base of what level, at war?), which fleet when several could (`MUL_LOAD_ONTO`), what it costs (time, organisation), and the carried unit's state after (its location, path, orders, `CArmy +0x300` and the other three carried-by fields, its counter). **Capacity**: the sum of `transport_weight` against `transport_capacity` - summed over which ships (transports only?), at boarding and daily (`CheckTransportOverload` re-read: which way round `+0x22` is). **Leaving the ship**: `CUnloadArmyCommand` (slots 6 and 14), `RemoveFromTransport` and `CNavy::UnloadCarried` whole - where a unit may get off (`UW_UNLOAD_NOT_VALID`: in a port), what it costs, which province it stands in after. **At sea**: what a carried unit is - does it lose organisation, draw supplies, suffer attrition, reinforce, upgrade, count for intelligence, move with the fleet's hour (who moves its `location`); the fleet's speed and its other orders while carrying; **a sea battle with passengers** (are they hit? a transport sunk - what of the units it carried, and how is a passenger tied to one ship or to the fleet?) and a fleet destroyed, merged, split or disbanded with passengers. **The transport mission**: `CNavalTransportOrder` (`MayBeGiven` slot 11, `IsActive` slot 14, its save and load) - "Transport land units on board the fleet to the friendly land province, then return to base" (`ORDER_TRANSPORT_DESC`): the path, what happens at the province (unload: all? when?), the return. **Save and load**: the `division` block inside a fleet's, and what a load makes again | rvas `0x1E3AD0`, `0x1E4090`, `0x1CF040`, `0x1E3600`, `0x1E3740`, `0x1CF120`, `0x1CFE10`, `0x1CFBD0`, `0x1D6690`, `0x1A0640`, `0x1A0690`, `0x1A0780`; `CArmy +0x300`, `CUnit +0x2E4`/`+0x2E8`/`+0x1C8`; the `CNavy` save slots; `FINDINGS-manpower.md`, `FINDINGS-supplypass.md` section 5 |
| **B. The landing** | **The invasion**: `CNavalInvasionOrder` whole - `MayBeGiven` (slot 11, `0x1A0790`), `Start` (slot 13, `0x1A0810`), `IsActive` (slot 14, `0x1A0990`), its keys `transport` and `message` (`0x1A1030`, save `0x1A1160`): "Land troops, carried on the fleet, in the selected province" (`ORDER_INVADE_DESC`). **A land unit landing from the sea**, given by the player directly as well as by the mission: which provinces may be landed on (beside the fleet's sea province only? any coast? one held by the enemy, by nobody, by a friend? a port or not?), how the order is made, what the march is (`CUnit::MovementSpeed` and `MovementDistance`'s landing branches re-read - which fleet's `amphibious_invasion_speed`, the passenger still aboard during the march?), **the invasion's progress** (`AMPH_INVASION_PROGRESS` "Amphibious invasion progress: $PERC$%" - what it is a share of), when the unit leaves the ship, and what if the fleet moves, is attacked or sinks during it. **The battle at a landing**: `CLandCombatant` slot 19's amphibious arm read to the formula - `AMPHIBIOUS_INVADE_ATTACK_LOW`/`_HIGH`, `_DEFEND_LOW`/`_HIGH`, by what figure interpolated (the progress?), `amphibious_invasion_defence` ("its defence improved by the transports' armour", `AMPH_INVASION_COMBAT_PROGRESS_DESC`), `AMPH_INVASION_ATTACK_SCALE`/`_DEFEND_SCALE`; `BM_AMPH_PENALTY` confirmed with its unidentified `+0x218`/`+0x21C`/`+0x18C` named (they look like the landing-craft technologies `amphibious_invasion_technology`, `amphibious_assault_units`); what a beaten landing does (back aboard? destroyed?) and a won one (the province taken - by the capture already read). **The message** `INVADEDUS` ("$ENEMY$ is storming our beach in $PROV$.") - who raises it, when, with what variables | rvas `0x1A0790`, `0x1A0810`, `0x1A0990`, `0x1A1030`, `0x1A1160`, `0x1C9140`, `0x1C9340`, `0x169B50`, VA `0x569A63`; the defines `AMPHIBIOUS_*`; `FINDINGS-movement.md` 5.1-5.2, `FINDINGS-combatmods.md`, `FINDINGS-combat.md` |
| **C. Carrying on screen** | **The unit panel**: the load and unload buttons and their tooltips (`UW_LOAD_IS_VALID`, `UW_LOAD_NO_FLEET_FOUND`, `UW_UNLOAD_VALID`, `UW_UNLOAD_NOT_VALID`, and the plane ones as far as their buttons go), which element each is and what it posts; a fleet's list of what it carries (`CWindowForLoadedUnitsEntry`, `CLoadedUnitEntry`: their elements, what each row shows, what a click does), `LOAD_CAPACITY_LABEL` "Can carry $NUM$ weight.", `TOTAL_LOAD_WILL_BE`, `TRANSPORT_WEIGHT`, `TRANSPORT_CAPABILITY`. **Several units at once**: `MUL_LOAD_ONTO` "Load these units onto", `NO_MULTILOAD`, `UNMOUNT_MULTILOAD` "Unmount $NUM$ units from air and naval transports." - where these are (the multiple-selection panel?) and what they post. **The map**: the right click with a land unit selected on a fleet, on a sea province, on a coast from aboard a fleet - what order each makes and what the province tooltip's warning lines say (`UTM_*`); what a carried unit's counter is (hidden? drawn on the fleet's?), an invasion's marker if any. **The orders window**: the `Transport` and `Invasion` rows - when each can be ticked, what the window sends. Anything else on screen about carrying | `CWindowForLoadedUnitsEntry` (slot 13 VA `0x758DE0`), `CLoadedUnitEntry` (slots 0, 4, 13: VA `0x74CE60`, `0x74D8A0`, `0x74C2A0`), `FINDINGS-unitpanel.md`, `FINDINGS-guilive.md`, `FINDINGS-provincetooltip.md`, OpenHOI3's fleets-and-air spec, `interface/` and `tfh/interface/` `.gui` files |
| **D. The carrier and carrying by air** | **A carrier as an air base**: `CRebaseToCarrierMission` (slots 11, 13, 14, 15 - VA `0x593050`, `0x5930B0`, `0x593290`, `0x593330`; its key `carrier_target`) - which air units may go aboard (`carrier_air_group`s only?), how many (`carrier_size` against what of the air unit), where the carrier must be; what an air unit aboard is (its base, its `CarriedBy`, does it move with the ship's hour, repair, refuel, reinforce, upgrade); what happens to it when its carrier sinks, is in a battle, is in port; which air missions it may fly from the carrier and from where (range from the ship). `CNavy::SendCarrierAircraft` and `CCarrierProtection` are read - cite, do not redo. **Carrying by air**: `CLoadOnPlaneCommand` (Execute slot 6 VA `0x5E4750`, slot 14 `0x5E4BF0`; keys `air`, `unit`) and `CUnloadFromPlaneCommand` (`0x5E4300`, `0x5E4450`) - who may board (`UW_LOAD_PLANE_FAIL_LOW_ORG`: paratroops at 95% of their organisation), onto which air units (`transport_capability`), where (`UW_UNLOAD_PLANE_BASE_ONLY`: an air base); **the paradrop**: `CParadropMission` (slots 11, 13, 14, 15 - VA `0x590900`, `0x590920`, `0x590C60`, `0x5913D0`) - where it may drop, the drop itself (`CAir::ReleaseCarried`, the `+0x97` byte `BM_PARATROOP_PENALTY` reads), what the dropped unit is after; **the air supply** `CTransportSuppliesOrder` as far as it carries anything (slots 11, 13, 14 and its own 37 and 39) | VA `0x593050`, `0x5930B0`, `0x593290`, `0x593330`, `0x5E4750`, `0x5E4BF0`, `0x5E4300`, `0x5E4450`, `0x590900`, `0x590920`, `0x590C60`, `0x5913D0`, `0x595300`, `0x595480`, `0x595490`, `0x595BF0`, `0x595C40`; rva `0x1D0990`, `0x1C7C70`; `FINDINGS-bombing.md` section 10, `FINDINGS-seabattle.md` section 5, `FINDINGS-supplypass.md` section 5 |

**Measurable afterwards, by OpenHOI3**: the French fleet's five saves - an hour of a carrying fleet's march, and the
passenger's location following it - and the April save's three carrying fleets, loaded from the save. Nothing measures
a landing, a paradrop or a carrier's air group taking off; a trial will have to stand for them, as for the battles.
