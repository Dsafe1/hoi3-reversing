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

## The espionage wave - spies placed and caught, what their missions do, what a country knows, the screen, and the AI's spying

> **LANDED 2026-10-14.** Five briefs, merged (131 address entries landed; 7 structs declared, 72 fields; three hand edits - `CDistributeEspionage`'s size, `CSpyPresence`'s comment, `CanAttemptCoup`'s comment; apply 195 `failed: 0`, `struct fields: 0`); the write-up is `findings/FINDINGS-espionage.md` sections A to E, indexed in `CANDIDATES.md`, where six things it left are queued.

Planned and launched 2026-10-14, for OpenHOI3, whose stage 4 lists "diplomacy, factions, politics, espionage, occupation,
revolt"; the first three are built. What OpenHOI3 has: spies trained from the espionage share of leadership into a
country's free pool, and nothing that spends them; a party's figures with a tally slot for spies that nothing
writes; `CAIIntel` built for the AI's offers, its espionage terms answering nought; every espionage condition and
effect reporting as unbuilt; the top bar's Intelligence button opening nothing. Five briefs; the write-up is the
existing `findings/FINDINGS-espionage.md`, **extended** with sections A to E rather than a new file, since its
first reading is the ground every brief stands on.

**What is known and is not to be redone:** `FINDINGS-espionage.md` (the `CSpyPresence` record field by field,
the nine missions and which function resolves each, the daily pass and its order, the arithmetic of each
mission's chance, detection and `spiescaught`, the espionage slider, the two intel fan-outs, the defines and the
three with no reader); `FINDINGS-government.md` B.6 (the coup command), B.1 (`CIdeologyData` and its five
tallies - the spies' is slot 3); `FINDINGS-luaapi.md` and its `CAIIntel` section (what the AI's offers read of
espionage); `FINDINGS-ai.md` (the intelligence minister is `CEU3AI`'s agent with `IntelligenceMinister_Tick` at
slot 10); `FINDINGS-definitions.md` and `FINDINGS-fieldmap.md` (`CChangeSpyMission`, `CChangeSpyPriority` and
`CPerformCoupCommand`'s save blocks and fields); `FINDINGS-onactions.md` (`on_coup_success`, `on_coup_fail`);
`FINDINGS-diplomacyview.md` (the list, sort and faction-box machinery the espionage screen shares with
diplomacy's).

**The oracle.** Every save holds, per country, `spies` (the free pool), and towards every other country
`spy_priority`, `spy_allocation` (the presence's level), `spy_date`, and `spy_mission` (the nine settings of each
presence, flattened). The maintainer's saves of one game - 1 January, the three autosaves and 20 April 1936 - give
the presence's growth and decay over time against its priority. Each brief that reads something a save keeps
should say which save fields it predicts.

| brief | what it settles | starting points |
| --- | --- | --- |
| **A. Placing spies** | How free spies become a presence: `CChangeSpyPriority` and `CChangeSpyMission` read whole (fields, `IsValid`, `Execute`, who may post them); how the priority shares the pool out and how fast a level grows to `MAX_SPY_LEVEL`, decays, and is lost when a spy is caught; `spy_date`; what the presence's `mission_share` is made from and when; the messages the slider's distribution raises (`CDistributeEspionage`, two, text not chased); what a new game's presences hold - the history's `spy_priority` key, the start save. Predicts `spies`, `spy_allocation` and `spy_priority` across the saves. | `CDistributeEspionage::Distribute`; `CSpyPresence` slots; the two command classes; `RunDailyMissions` |
| **B. What a mission does** | The parts the first reading left: the tech steal past `0x52EBE0`'s chance (which technology, how much, the message), military intel past `0x52FD40`'s (what the walk over the target's units yields and how long it lasts); the party boosts' two targets (`CCountry +0x10C4` is organisation by the politics wave; `+0x10D4`'s stride-16 is very likely the tally array - confirm); the threat pair `0x42F100`/`0x4F4E80`; covert ops points and the coup - when `attempt_coup_button` may be pressed, its chance and cost, and `CPerformCoupCommand`'s posting; `0x4EF7C0`, the ally predicate; every message a mission or a catch raises, with its keys; the script keywords `spies`, `spy_mission_count`, `has_hostile_spy_mission` (conditions), `modify_spies` (effect), `local_intel_boost` and `spy_lower_neutrality`/`spy_support_resistance` (modifiers) | `FINDINGS-espionage.md`'s *not established*; the effect and trigger tables |
| **C. What a country knows** | The figure that says how much a country knows of another - what the espionage screen and the diplomacy screen hide behind it, and what `CAIIntel::GetFactor` reads - and how a presence, a neighbour, an alliance or a faction makes it; `UpdateIntelFunctor`'s per-province body past `0x688480`, what it writes and from what (OpenHOI3's `CIntelligence` has the part air combat needed: 9 for one's own and friends' ground and a unit's, 2 for a unit's water; radar unread), so that province intel is read whole once; `prov +0xD4`; the switch at `[0x170AD30]` | `0x688D40` and its two fan-outs; `CAIIntel::GetFactor`; the screen's own gating (shared with D) |
| **D. The screen** | `country_espionage`, its view class, as section D of `FINDINGS-government.md` read the politics view: construction, Show, Update; the country list, its tabs and five sorts (`threat`, `covert`, `spy_level`, `spy_priority`); `own_country_info` (free, active and foreign spies, partisan efficiency, spies caught, foreign actions, own priority, our missions); `country_info` for the chosen country - what each figure shows at each level of knowledge, `spy_bar`, `target_priority`, covert ops, the nine `spy_mission_entry` rows and their priority buttons, `attempt_coup_button`; `country_info_sections` - the production and minister views and the research lists; every command the screen posts; every tooltip, by element | the view's vftable from RTTI; `country_espionage.gui` (TFH) |
| **E. The AI's spying** | When the intelligence minister acts (its schedule, as the politics wave read the politics minister's, and whether only a country nobody plays has one); `IntelligenceMinister_Tick` in TFH's `ai_intelligence_minister.lua` and each method it reaches - `CSpyPresence` (`GetPriority`, `GetPrimaryMission`, `GetMissionPriority`, `MAX_SPY_PRIORITY`, the rest of its registered methods), `CCountry:GetSpyPresence`, `GetSpyingOnUs`, `AccessIdeologyPopularity`, `GetCapitalLocation`, `GetNationalUnity`, `CalculateIsAllied`, `CCurrentGameState.GetPlayer`, `CDate:GetTotalDays`; the two constructors `CChangeSpyMission(actor, target, mission, priority)` and `CChangeSpyPriority(actor, target, priority)` from Lua; any C++ side of the minister | `FINDINGS-ai.md`'s agent table; the luabind registrations; the script itself |

Every brief gets `TRAPS.md` and the two report tables verbatim from `CLAUDE.md`. B and C share `0x4EF7C0` and the
ally test; D reads what C's figure gates, so D's agent is told C's starting points and to cite rather than re-derive.
