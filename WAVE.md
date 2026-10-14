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

## The politics wave - laws, ministers, parties, dissent and unity, the screen, and the AI's politics

> **LANDED 2026-10-14.** Five briefs, merged (171 address entries; 16 structs declared, 81 fields; apply 193/194 `failed: 0`, `struct fields: 0`); the write-up is `findings/FINDINGS-government.md`, indexed in `CANDIDATES.md`. Two questions left open are queued there: the minister pool at a new game, and what runs the AI's `Laws()` more than once before the start save.

Planned and launched 2026-10-14, for OpenHOI3, whose stage 4 lists "diplomacy, factions, politics, espionage,
occupation, revolt"; diplomacy and factions are built. What OpenHOI3 has: a country's laws and ministers as
the history gives them, its ruling party and government, dissent moved by consumer goods, national unity held
at one; nothing changes a law or a minister, parties have no figures, and every condition and effect on the
government, the parties and the ministers reports as unbuilt. Five briefs; the write-up is the new
`findings/FINDINGS-government.md`, sections A to E.

**What is known and is not to be redone:** `FINDINGS-politics.md` (the country's daily pass and its order,
phase 4's schedule of elections, `CCountry +0x618` ministers and `+0x628` laws, the three law accessors);
`FINDINGS-effectrun.md` sections 1.4 and 1.5 (`organisation` and `popularity`, `coup_by`, `do_election` and
`CCountry_HoldElection`'s scoring, a government position `= id`, `remove_minister`); `FINDINGS-triggerleaves.md`
(`minister_alive`, the government position, `government`, `has_removable_minister`, `ideology`,
`ideology_group`); `FINDINGS-numtriggers.md` (`dissent`, `national_unity`, `popularity` and `organisation` as
conditions); `FINDINGS-distribute.md` (consumer goods' dissent, `CDistributeConsumerGoods::GetDissentChange`);
`FINDINGS-topbar.md` and `FINDINGS-topbartooltip.md` (what the top bar shows of dissent and national unity);
`FINDINGS-espionage.md` (`CSpyPresence::ApplyUnityModifiers`, the coup mission); `FINDINGS-ai.md` (when the AI's
ministers tick); `FINDINGS-luaapi.md` and `FINDINGS-luahost.md` (the Lua API read so far and the state);
`FINDINGS-fieldmap.md` (the history keys); `FINDINGS-alignment.md`; `FINDINGS-revolt.md`.

| brief | what | fragment |
| --- | --- | --- |
| A | **a law or a minister changed**: `CChangeLawCommand` and `CChangeMinisterCommand` whole - who may post one, what is checked before and in `Execute`, and everything a change sets off at once or later (a law's `allow`, the cost or delay if any, dissent, the modifier, the brigades, history, messages); which ministers a post may take - `CMinister::CanTakePosition`, `IsValid` (slot 8), ideology against the ruling party, dates, the pool `+0x160` and how it is made; `CCountry_FillMinisterPosts` (inferred) whole and **who calls it when**, the start of a game included; ministers dying or retiring as the days pass | `politics-change.json` |
| B | **the parties over time**: `CIdeologyData` and the country's two of them (popularity, organisation): where they come from (the history), **every writer** - what moves popularity and organisation day by day or month by month, by laws, ministers, events or drift - with the defines; `CCountry_AllotCabinetSeats` (inferred) whole and who reads the seats; `CIdeologyData::GetLeading` (inferred) to confirmed; the tally at `+0x18`; the forced election and the "never" sentinel left open in `FINDINGS-politics.md` phase 4; `CPerformCoupCommand` (`from`, `to`) - who posts one and what it does | `politics-parties.json` |
| C | **dissent and national unity**: every writer of dissent (`CCountry +0x10B4`) besides consumer goods and the rebels' zeroing - its daily decay or drift, ministers and laws - and of national unity through `CCountry::ChangeNationalUnity` (every caller and why: war, occupation, events, espionage); what dissent and national unity **do** elsewhere (a surrender level, IC, revolts - say where and stop: revolts are a later wave); and the unread helpers of the country's daily pass (`FINDINGS-politics.md`, "The rest of the pass") - name each one and say which touch politics | `politics-unity.json` |
| D | **the politics screen**: `CPoliticsView` whole - every element it finds by name in `interface/` and what it writes there, the parties' figures, the cabinet with `CMinisterItem`, the laws with `CLawEntry`, `CPossibleLawEntry` and `CLawChangeConfirmDialog`, what each button posts, every tooltip with its keys and variables; the `C*Change` history classes (`CLawChange`, `CMinisterChange`, `CIdeologyChange`, `CGovernmentChange`, `CPopularityChange`, `CDissentChange`, `CNationalUnityChange`) - who writes and who **reads** them; and the top bar's politics button | `politics-view.json` |
| E | **the AI's politics**: `CAIPoliticsMinister::DoWork` and `Lua_PoliticsMinister_Tick` - for which countries and when (the player's excluded or not; whether it runs in a new game's first days, which is how the original's first screen has other laws than the history); every method the install's `tfh/script/ai_politics_minister.lua` reaches that `FINDINGS-luaapi.md` has not read - `CLawDataBase`, `CLaw:ValidFor`/`GetGroup`/`GetIndex`, `CCountry:GetLaw`/`GetMinister`/`GetPossibleMinisters`/`GetRulingIdeology`, `CGovernmentPositionDataBase`, `CMinister:CanTakePosition`, `CChangeLawCommand(...)`, `CChangeMinisterCommand(...)`, `ai:Post`/`CCurrentGameState.Post`, `CCurrentGameState.GetAIRand` (which generator) and the rest - on the listing, as `FINDINGS-luaapi.md` did; and what `CToggleMobilizationCommand` and `CLiberateCountryCommand` do when the AI posts them | `politics-ai.json` |
