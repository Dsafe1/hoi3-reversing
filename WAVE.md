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

## The agreements wave - an offer's way through the game, the screen's actions, and the pacts

> **LANDED 2026-10-13.** All three briefs ran and merged (167 addresses, 6 structs, 41 struct fields;
> apply 167/168 `failed: 0`, `struct fields: 0`); the write-up is `findings/FINDINGS-agreements.md`,
> indexed in `CANDIDATES.md`. It corrected `FINDINGS-diploaction.md` §5 (the accept-all loop is the
> tutorial's), the wave's own premise that the screen's tooltips ask the AI (they do not: only the
> dialog's chance band does), and five record entries (C's synopsis). Kept as history until the next
> plan replaces it.

Planned and launched 2026-10-13, for OpenHOI3's diplomacy, whose fourth piece in the maintainer's
order is the agreements. The cut below is the collecting session's, not his: **the offer itself and
the pacts** first - alliance, non-aggression pact, guarantee, military access asked and offered,
embargo, influence and alignment - and **trade and aid** (trade, debt, lend-lease, licences, shared
technology) after. War and peace, a call to arms and factions are later pieces of his order and are
not in this wave except where an offer's machinery is shared.

**What is known and is not to be redone**:
- `findings/FINDINGS-diploaction.md`: the action object field by field, `type` PROPOSE/DECLINE/ACCEPT,
  `value` a bool, the 24 classes and their save tokens, the lifecycle (Lua `Create`, slot 6
  `MakeCommand`, `CDiplomaticActionCommand::Execute`, the pending list `+0xF24`, the seven-day
  `+0x50`), slot 18's split, the null action; sections 11-20: **slot 7** of all twenty bodies - extents,
  the defines each reads, the influence charged on PROPOSE, `CNapAction` and `CTradeAction` arm by arm,
  `CRelation` slot 10 for every subclass, `ChangeRelation`, the global relation list `+0xB2C`, and each
  body's message keys; sections 21-31 the war-goal chain, `SpreadThreat`, `CDiplomacyStatus::LoadKey`;
- `findings/FINDINGS-diplomacy.md`, `FINDINGS-survivors.md`, `FINDINGS-luaapi.md`: `GetAIAcceptance`
  (slot 17) per class, the bridge and its clones, what Lua the score comes from;
- `findings/FINDINGS-ai.md`, `FINDINGS-aisched.md`: the five ministers, their hour of the day by the
  country's id, the parallel pass;
- `findings/FINDINGS-diplomacyview.md`: the diplomacy screen except its actions;
- **found by the collecting session while planning, and the starting point of brief A**:
  `0x89E010` (rva `0x49E010`, unnamed), which `CAIForeignMinister`'s slot 10 runs just before
  `ForeignMinister_Tick`, is **the AI answering its pending offers**: for each with slot 18 true and
  `type` PROPOSE, `score = GetAIAcceptance()`; a score of 30 or less is declined; otherwise a roll of
  `MT19937Next() % 100` accepts it where it is below the score; a trade (token `0x6DA`) is accepted only
  once a pass and the rest are kept on a list handed to `0x4E6410`; each answer is posted as a command.
  And the hourly pass's loop at `0x682B37` that accepts **everything** pending runs only while
  `tutorial_active` (`+0xD9D`) is set.

| brief | what | fragment |
| --- | --- | --- |
| A | **an offer's way through the game**: `0x89E010` read whole, `0x4E6410` and what is left pending; which countries' foreign ministers run and so answer - `CAIAgent +0x3C`, the player's country, the hour; an offer **to the player** - how it is shown and what accepting or declining it does; the replies' messages; an offer **from the player** - the button handlers that make and post one; `CEU3AI::PostAction`, the AI's offer from Lua; the reader of `next_offer_allowed` (`+0x50`), and of the influence an offer costs | `diplomacy-offer.json` |
| B | **the diplomacy screen's actions**: which actions the chosen country's panel offers, by element name, and what each button does; for each kind the screen offers, slot 13 `IsValid`, slot 14 `IsSelectable` and slot 11 (the description and why-not texts: `MILACCDESC`, `DIP_NO_INFL` ...) read whole; what `CDiplomacyView::BuildTooltip`'s thirteen slot-17 calls show of the AI's answer | `diplomacy-actions.json` |
| C | **what the pacts do**: slot 7 arm by arm, with every `CDiplomacyStatus` and `CCountry` write, for alliance, guarantee, military access asked and offered, embargo, influence nation and influence alliance leader (align), and NAP's checked; breaking each; whether a relation ends by itself (`CRelation +0x1C end_date`, `+0x20`); the daily and monthly passes that read a pact - influence and align running, the relation drift's access term, embargo and threat (`0x4F50A0`); each relation's save block | `diplomacy-pacts.json` |

A and C are written up as one, `findings/FINDINGS-agreements.md`; B into the same file, its own
section. **Every brief asks** what looks wrong but is what the bytes do, and which figure is shown or
stored in what unit.
