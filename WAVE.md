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

## The faction wave - joining, leaving, and what a faction is worth

> **LANDED 2026-10-13.** Three briefs, merged (54 address entries, 35 of them new; 5 structs declared, 28 fields; apply 189/190 `failed: 0`, `struct fields: 0`); the write-up is `findings/FINDINGS-factionplay.md`, indexed in `CANDIDATES.md`.

Planned and launched 2026-10-13, for OpenHOI3, whose diplomacy the maintainer cut into "what two countries
hold of each other; the diplomacy screen; Lua; the agreements; war and peace; factions". The first five are
built; this is the last. Membership already exists there - a country's faction, the order members joined,
leaving when owning nothing, a declaration putting the victim into the enemy's faction - but a country cannot
join or leave one by diplomacy or script, a faction's progress is nought, and what membership gives beyond
the triangle is unbuilt. Three briefs; the write-up is the new `findings/FINDINGS-factionplay.md`, sections A
to C.

**What is known and is not to be redone:** `FINDINGS-faction.md` whole (`CFaction::AddCountry` and its war
sweep, `AddMember`, leadership being positional, no alliance from a join, `CCountry::LeaveFaction`,
`CFactionJoin`/`CFactionLeave`, `CJoinFactionEffect::Execute`, the six `AddCountry` callers, `0xE70A0` and
`0xFBC10`); `FINDINGS-diploaction.md` (`CFactionAction::Apply`'s gate and its influence charge, its message
keys, `CFactionAction::Create`); `FINDINGS-agreements.md` section B (the join and invite rows' slots 11 and
13, B.9's swapped neutrality limits); `FINDINGS-diplomacyview.md` (the faction boxes, `victory_progress` and
`CFaction_BuildProgressTooltip`, `CFaction_DescribeRulesAndModifier`); `FINDINGS-politics.md`
(`IsWithinFactionJoinDistance`); `FINDINGS-alignment.md`; `FINDINGS-triggerleaves.md`
(`CFactionProgressTrigger::Evaluate`); `FINDINGS-effectrun.md` (`leave_faction`); `FINDINGS-surrender.md`
(`FactionLeaderPromotion`, the exile and a faction).

| brief | what | fragment |
| --- | --- | --- |
| A | **joining and inviting**: `CFactionAction` whole on the listing - which of actor and recipient joins in each direction, `IsValid`, `IsSelectable` and `GetDescription` exactly, `Apply` past its gate (both arms of `AddCountry`'s call, the messages and who is told), `GetAIAcceptance` and the Lua it asks, `AskPlayer` and `CAskFaction`; and `CJoinFactionGoalAction` with `GetJoinFactionGoalScoreFromLua` - what it is, who makes one and what it does | `faction-join.json` |
| B | **leaving, and what membership gives**: the player's leave from the screen (`CDiplomacyView::OnCgmLeaveFaction`, `Cgm_IsLeavingFaction`, `Cgm_GetFactionJoining`, `CCgmLeaveFactionCommand` and its execution) and whether a leave waits; `CFaction::RemoveMember` to `confirmed`; who reads `IsWithinFactionStratBonusDistance` and what that bonus is; who reads the rules `0xFBC10` builds (`CCountry +0xDBC`) and what each rule does; anything else a member gets from its faction that OpenHOI3 would miss | `faction-leave.json` |
| C | **a faction's progress and the victory conditions**: `CFaction::GetVictoryPointShare` whole (which provinces' points - owned, held, cores, by whom - over what total, rounding, caps), `faction_progress` set against it, the victory conditions (what they are, where they are defined or chosen - `CChooseVictoryConditionsCommand` - `VictoryConditions_CountForFaction` / `CountMetForFaction`), and what, if anything, a faction meeting them or the end date does to the game | `faction-progress.json` |
