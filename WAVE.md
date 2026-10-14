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

## The occupation and revolt wave - policies, revolt risk, rebels made and at work, undergrounds, and `counter_espionage`

> **LANDED 2026-10-14.** Six briefs, merged (131 address entries landed; 13 structs declared, 71 fields; one hand edit -
> `CRebelFaction`'s size 0xA4; apply 199 `failed: 0`, `struct fields: 0`); the write-up is `findings/FINDINGS-occupation.md`
> sections A to F, indexed in `CANDIDATES.md`, where six things it left are queued and item 7 is settled.

Planned and launched 2026-10-14, for OpenHOI3, whose stage 4 lists "diplomacy, factions, politics, espionage,
occupation, revolt"; all but the last two are built, and triggered modifiers since (`FINDINGS-countrymodifier.md`,
section 3). **What OpenHOI3 has of this domain is nothing**: no occupation policy, no revolt risk, no suppression, no
underground, no rebel faction or rebel unit. It has `REB` as a country that is everybody's enemy (`IsEnemy`), a
province's owner and controller with their changes of hands, a province's modifier from its buildings, `overseas`
and `non_core` only (steps 1 to 3 of the nine in `FINDINGS-countrymodifier.md`/`FINDINGS-revolt.md` section 3), units
with their brigades' `suppression` read, the land battle, governments in exile, and the conditions `revolt_risk`,
`pure_revolt_risk`, `num_of_revolts`, `revolt_percentage` and `nationalism` reporting as unbuilt. Six briefs; the
write-up **extends `findings/FINDINGS-occupation.md`** with sections A to F rather than making a new file, since it
and `FINDINGS-revolt.md` are the ground every brief stands on.

**What is known and is not to be redone** (cite it; re-read on the listing only to raise an `inferred` record to
`confirmed` or to correct it): `FINDINGS-occupation.md` (the daily revolt-risk step `0x49EAB0`, the effective figure
`0x4A4050` and the two triggers, suppression `0x49F360`/`0x49F250`, the occupation policy in the province rebuild,
the underground spawn `0x50B630` and its tooltips, `CRebelType` and `CRebelFaction`'s layouts, the `REB` special
cases); `FINDINGS-revolt.md` (the roll `0x4C07C0`, `ChooseRebelTypeForProvince` and `spawn_chance`,
`CMeanTimeToHappen::GetDays`, the province rebuild's order, the underground pass `0x50A110` in outline, the two
script effects); `FINDINGS-countrymodifier.md` (the country rebuild); `FINDINGS-exile.md` and `FINDINGS-capitulation.md`
if present (a government in exile); `FINDINGS-handchanges.md` if present (a change of hands).

**The oracle.** `Germany1936_04_20_03.hoi3` holds `revolt_risk` on six provinces (9958, 9959, 9971, 9972, 9979, 9987 -
Italian-occupied Ethiopia: 0.081, 1.375, 0.974, 0.147, 1.500, 1.500) and three `occupation_policy` entries
(`collaboration_government` twice, `civil_war` once); the 1 January save has none of either. `nationalism` entries
are on 5 provinces on 1 January and 57 on 20 April. The three autosaves (1 February, 1 March, 1 April) lie between.
Each brief that reads something a save keeps should say what it predicts there.

| brief | what it settles | starting points |
| --- | --- | --- |
| **A. Occupation policies and a province's modifier** | Where `CDiplomacyStatus +0x10` (`occupation_policy`) is written: the policy a war or a capture starts with, the command that changes it (its fields, `IsValid`, `Execute`, who posts it), who evaluates a policy's `allow` and when; where the player sets it (which screen, which elements, tooltips) and whether an AI chooses one (Lua or C++); every message. And the rest of the province rebuild `0x49F3E0` the rewrite lacks, read to the end: the terrain/coast/blockade statics with their conditions named, the eight timed and conditional province modifiers, `manpower` scaled, **`nationalism`** - what adds an entry to `province +0x13C`, its value and its year - and when the rebuild runs (the daily pass's flag, the month) | `CDiplomacyStatus::LoadKey` (`0xA48190`); `COccupationPolicy::LoadKey` (`0x52CEE0`); `0x49F3E0`'s table in `FINDINGS-revolt.md` section 3; `common/occupation_policies.txt` |
| **B. Revolt risk and what it does** | The daily step and the effective figure on the listing (raise or correct); **the units of `CProvince +0x28`** set against the six provinces of the 20 April save; the setter `0x4A40F0` and its callers `0x5FE3EB`, `0x5FE410`, `0x9A55E3` (what script or command sets revolt risk); `CProvince +0x60`/`+0x64` and the full revolt `0x4A6C30` with `CSpawnFullRevoltCommand`'s `Execute`; the conditions `revolt_risk`, `pure_revolt_risk`, `num_of_revolts`, `revolt_percentage` and `nationalism` as the triggers' slot 6 reads them; what the player is shown of revolt risk - the province view and its tooltip (`0x4A4250`, `0x601B70`), any map mode | `0x49EAB0`, `0x4A4050`, `0x4A40F0`, `0x4A6C30`; the trigger classes |
| **C. Rebels made** | `CreateRebelsForFaction` (`0x4BAA20`) whole: the 1..4 clamp, the units made (the rebel type's `unit`, how many brigades to a unit, their strength and organisation, `MODIFIER_PARTISAN_EFFICENCY`, the inlined draw at `0x4BADED`), their owner and leader, where they are put, the message and its keys, the pre-revolt owner and controller it records; `CreateRebelBrigadesInProvince` (`0x4C1160`) whole with `0x4B9150` and `0x4A40F0`; `0x686D80` (a faction made) and `0x4BF6F0` (an independence type's area); `CCreateRebelsEffect` and `CCreateRevoltEffect` on the listing | `FINDINGS-revolt.md` sections 1.4 and 5; `FINDINGS-occupation.md` section 3.3 |
| **D. The rebel faction's day** | `RunDailyRebelFactionPass` (`0x4B9D60`) whole: `0x4BD4E0`, `0x4B98D0`, the rebels' movement (`0x4B99D0` and `movement_evaluation`), a siege won (`siege_won_trigger`, `siege_won_effect`), demands (`can_enforce_trigger`, `demands_enforced_effect`), `defection` with `defect_delay`, `independence`, `auto_convert`, `resilient`, `reinforcing`, `smart`, `area`; what changes when rebels hold a province; the `REB` country's own handling (`0x4B8F40`); rebel acceptance - `CExecuteRebelAcceptanceCommand`, `REBEL_ACCEPTANCE_MONTHS`, `CCountry`'s `last_rebel_acceptance`; every message | `FINDINGS-occupation.md` sections 3.1, 3.2 and 4; `FINDINGS-revolt.md` section 2 |
| **E. Undergrounds and partisans** | The underground pass `0x50A110` on the listing (growth, detection, the three `underground_action` values, the removal and its messages); a new underground `0x50BD00`; the initial undergrounds `0x509050`/`0x509230` with `MAX_UNDERGROUND_DISTANCE` and `UNDERGOUND_INITIAL_STRENGTH` (who calls them - a government made in exile?); what sets `underground_action` - the commands (`CSpawnPartisanCommand` and any other), the screen and its buttons (`MOBILIZE_PARTISANS`, `MOBILIZE_UNDERGROUND`, the tooltips `0x50AFD0`, `0x50B1E0`, `0x50B4A0`, `0x50BB60`), the AI's use; the `underground` building itself (who builds it, its levels) | `FINDINGS-revolt.md` section 4; `FINDINGS-occupation.md` section 2; `FINDINGS-productiontooltip.md` (the underground button) |
| **F. `counter_espionage`** | `CANDIDATES.md` item 7: every reader of modifier 55 (`+0x1B8`, `counter_espionage`) and 42 (`+0x150`, `espionage_bonus`) in the image, each with its sign; the modifier definitions' order against the keys; the tooltip a modifier gets (more-is-better) for both; and whether the maintainer's observation - it works as a "domestic counterespionage difficulty", no effect abroad, an inverted tooltip - is what the bytes do. With triggered modifiers built, OpenHOI3's start-save check catches 22 spies in the two days to the save's 33 | `FINDINGS-espionage.md` (CatchSpies), `CModifierKinds`' source in `FINDINGS-topbartooltip.md` section 10 |

Every brief gets `TRAPS.md` and the two report tables verbatim from `CLAUDE.md`. B and C share `0x4A40F0`; C and D share
`0x686D80` and the faction's lists; A and B share the province rebuild, A reading its statics and B its revolt-risk
block - each cites rather than re-derives what the other owns.
