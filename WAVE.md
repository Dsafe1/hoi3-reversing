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

## The event wave - an event firing, a decision taken, and the two windows

> **LANDED 2026-10-12.** All three briefs ran and merged; the write-up is
> `findings/FINDINGS-eventfire.md` and its index row is in `CANDIDATES.md`. Kept as history until the
> next plan replaces it.

Planned and launched 2026-10-12, for OpenHOI3's stage 4 step 4 ("an event firing and a decision
taken, with the event's window and the decision screen"). The effects wave before it landed the
same day (`findings/FINDINGS-effectrun.md`).

**What is known and is not to be redone**: `findings/FINDINGS-events.md` - the candidate lists,
the monthly rebuild (rva `0x5C0050`), the daily pass (`0x5C0A40`), `CMeanTimeToHappen::GetChance`
(`0x5C4AB0`) and the scope the two build; `FINDINGS-eventfiles.md` - the files and the containers;
`FINDINGS-effects.md` and `FINDINGS-effectrun.md` - `country_event` and `province_event`, which call
`FireEvent` after asking the event's trigger. The record holds `FireEvent` (`0x5C0C80`) by name
and extent only - **its body was never read** - and the two commands
(`CSelectEventOptionCommand`, `CExecuteDecisionCommand`) by their loaders only.

### A. `FireEvent`, and choosing an option

`FireEvent` read whole: what it does for a country a person plays and for one the AI runs; the
`immediate` block, when it runs and in which scope; how the AI picks an option (`ai_chance`, a
`CAIMTTHChance` - its `GetChance` and how the options' chances are weighed against each other);
what a player is shown and how the event waits for an answer (a pending list? a timeout? what
happens if nobody answers); `major` (who else hears of it); `fire_only_once` and the already-fired
registry (`CCurrentGameState +0xC38`); messages. Then `CSelectEventOptionCommand::Execute` - what
it checks and runs. And **province events**: the daily pass walks countries only - where is a
province event (14 in the base game, not triggered only) ever asked, with what scope, and how often?
Fragment `event-firing.json`.

### B. Decisions

Which decisions a country is shown (`potential`) and may take (`allow`), when that is asked, and
where the list lives; `CExecuteDecisionCommand::Execute` - what it checks again, the effects, the
scope, `CCountryDecisionChange`/`CCountryRemoveDecisionChange` (is a decision taken once? can it be
taken again?); the AI - when and how it takes a decision (`ai_will_do`, a mean time to happen whose
factor is whole days per `FINDINGS-effectgrammar.md`; `Lua_ForeignMinister_EvaluateDecision` hints
the Lua AI decides - settle where); `major`; and the two groups (diplomatic and political), of which
`FINDINGS-eventfiles.md` says only one is ever listed. Fragment `decisions.json`.

### C. The event window and the decision screen

`CEventWindow` (its constructor at rva `0x5C2010`): which `.gui` window it builds, every element it
finds by name and what it puts there - the picture, the title, the subtitle and the description with
their localisation and scope substitution, the option buttons and what each says, its tooltip,
where the window stands, what closing it does, and several events at once. Then the decision
screen: which window lists decisions, `CDecisionEntry` and every element it fills, what an entry
shows for a decision that may not be taken, the entry's tooltip (the `allow` block's text, the
effects' text?), and the button that takes it. Fragment `event-window.json`.

**Every brief asks**: the order things happen in, what is checked and what is not, what the player
sees against what the AI does, and anything that looks wrong but is what the bytes do.

## The standing rules for every brief

All learned the hard way; all go in every brief.

- **Demand the report's shape, in these words.** Wave 13 came back in four different shapes; wave 14
  came back in four consistent ones, so this works:

  > **Open your report with a synopsis of 2-5 sentences** - what you set out to settle, what you
  > settled, and anything you *corrected* rather than added. No preamble before it.
  >
  > **Then a table of every function your fragment touches**, one row each, before the write-up:
  >
  > | rva | name | new or revised | confidence | one line |
  >
  > Use `revised` for anything that already had a record, and say in the last column what changed
  > about it. If the fragment touches no function, say so in one line rather than omitting the table.
  >
  > **Then the same table for every struct field your fragment touches:**
  >
  > | struct | offset | name | type | new or revised |
  >
  > Same rule: `revised` for anything that already had a record, and say what changed - a name, a
  > type, or both. If the fragment touches no field, say so in one line.

  **And now a third table, for the `structs` key**, since a declaration is as consequential as a field
  and wave 14 landed eighteen of them:

  > **Then every struct your fragment declares:**
  >
  > | struct | size | inherits | vftable rva | own fields |

  The synopsis is what the maintainer reads and the tables are the index to the record. **The
  `revised` rows are the ones to verify off the bytes before merging** - a wrong new name costs
  little, a wrong overwrite costs a published claim. Wave 14's five `revised` rows were all verified
  this way and all held, including one that corrected a published generalisation.
- Give every agent **`TRAPS.md`**, and say the scripts are in `scripts/`, the write-ups in
  `findings/`, and that commands run from `reversing/`.
- **Addresses in `project.json` and the `GameClasses` headers are rvas against an image base of
  `0x400000`; disassemblers print VAs.** Trap 1. It has caught agents in waves 10, 11 and 12 in their
  own prose, and in wave 14 it was the *plan* that was wrong - the faction mutation was handed over as
  `0x4F5F30`, a VA, from a document that declared VAs. **`image.read`, `image.decode` and
  `image.findValue` all take VAs; `image.both` takes a VA and prints the rva.** And
  `image.decode(addr, n)` takes **`n` bytes, not `n` instructions** - asking for 1 returns nothing at
  all, which once produced a silent "no writers anywhere".
- **The fact base has three halves** - `project.json`, the `GameClasses` headers, and
  `ghidra/luabind.json` / `ghidra/bicelib_findings.json`, **which stores offsets in decimal**, so
  `grep 0xF88` over it is a silent false negative. Wave 14 paid for this twice: `CVariables::SaveContents`
  and `CVariables::LoadKey` were "unrecorded" in `project.json` and **`CERTAIN` with signatures in the
  generated file all along**, and 18 classes with 44 fields looked blocked while already being in
  Ghidra through `luabind.json`. **Grep all three before concluding anything is missing.**
- The fragment field list is **`struct_fields`**, never `fields`; a new class goes in **`structs`**,
  and a `fields` key inside a declaration is refused. `confidence` takes only
  `confirmed`/`inferred`. Every `ADDRESS_KEYS` key must be *present*, so a signed entry still needs
  `"no_signature": null`. **`revises`** replaces a record whole and rebuilds from `ADDRESS_KEYS`
  alone, so a missing `comment` or `source` is **silently blanked**; a rename needs `replaces` too. A
  `__thiscall` name needs `::` **and** an explicit `this` in the parameter list.
- **Name your fragment after the topic, not the wave** - `faction.json`, `countrylist.json`,
  `setflag-expedition.json`. Lower case, hyphens, no wave number and no agent letter.
  `fragments/merged/` is one flat archive of every fragment ever landed and you look in it for
  *the faction one*; a `wave15-` prefix sorts it by something git already tells you and buries
  the topic. Six of sixty had drifted before this was written down on 2026-10-07.
- **Check your own signatures**: `python scripts/checkSignatures.py --candidates
  fragments/incoming/<yours>.json`. The whole-image baseline is **1,605 entries, none disagree**
  (2026-10-07; it was 1,582 before wave 14 landed). "None disagree" is the pass mark, not the count.
- Say which facts are **already recorded**, and **check a new conclusion against the record before
  publishing it.** Across waves 10-14 this caught more than a dozen cases where the record already
  held the answer or contradicted itself - and in wave 14 it was three of the four *briefs* that were
  stale, not the agents.
- **Verify both ends of a function's extent, and prefer the vftable to any padding rule**: an address
  a table holds is an entry by definition and the next slot is the upper bound. The "run of at least
  three `int3`" rule is **sufficient, not necessary** - wave 14 found `CTagTrigger::Evaluate` with two.
  And **trap 3 is live**: `CFaction::AddCountry` has two interior `ret 0xC` with `0x2CC` bytes of real
  code past the first, including the two strings that name it.
- An agent's `Write` is refused for `findings/FINDINGS-*.md`; the write-up comes back as prose and
  someone transcribes it **the same session**.
- **Pick what matters, read it properly, and say what you skipped.** A partial reading that names its
  own gap is worth more than a sweep that rounds up - and **a negative needs a positive control in the
  same paragraph.**

## Launching this

Three briefs, built from the sections above. Then the pipeline, which is idempotent:

    python ghidra/mergeFindings.py --check      # refuses until each write-up exists
    python ghidra/mergeFindings.py
    python ghidra/buildFindings.py              # the oracle - validates against the exe
    ...headless ApplyBiceLibFindings            # failed: 0 AND struct fields: 0 on a second run

The full headless command, with the install path and which project, is in `ghidra/README.md`. Run it
against a **copy**; the maintainer's project is usually open and holds the lock, and **applying to
their own project is their step.**

**One thing to expect on the next apply against the maintainer's project**, from wave 14 rather than
this one: 93 vftable slots are in it under names that were wrong, and an `overwrite` run renames them
to `vf_N`. `TRAPS.md`'s section under trap 4 lists the affected tables. **That is a fix landing, not a
failure.**
