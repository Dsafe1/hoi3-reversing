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

## The text wave - every effect and every condition as words

> **LANDED 2026-10-12.** All seven briefs ran and merged; the write-ups are
> `findings/FINDINGS-scripttext.md`, `FINDINGS-onactions.md` and `FINDINGS-messageshow.md`, indexed
> in `CANDIDATES.md`. Kept as history until the next plan replaces it.

Planned and launched 2026-10-12, for OpenHOI3's last pieces of events and decisions: an option's
tooltip, the description of an event's `immediate` block, and a decision's two tooltips (its effects
and its `allow` block). The event wave before it landed the same day (`findings/FINDINGS-eventfire.md`).

**What is known and is not to be redone**:
- `findings/FINDINGS-effects.md`, section on slots 8, 9 and 10: an effect's `GetBlockText` (slot 8,
  the base `0x59C710` read), `GetText` (slot 9, the base says nothing) and `GetTargetText` (slot 10,
  three overrides) and how a run of one keyword is folded onto one line;
- `findings/FINDINGS-techtext.md`: the trigger renderers - the base `GetBlockText` (`0x5D03F0`), `and`,
  `or`, `not`, `any_owned_province` - the asterisks, the indent and BiceLib's corrections, and four
  trigger leaves (a technology, `num_of_ports`, `has_building`, `has_country_flag`);
- `findings/FINDINGS-effecttext.md`: `kill_leader`'s line and the localisation machinery
  (`GetText`/`Replace`/`Render`);
- `findings/FINDINGS-eventfire.md`, 3.4 and 3.7: where the option tooltip and the decision tooltips
  come from and in which scope;
- `findings/FINDINGS-script.md`, `FINDINGS-triggergrammar.md`, `FINDINGS-effectgrammar.md`: which
  keyword makes which class.

**What is not read**: the leaves - 78 distinct effect `GetText` bodies and 146 distinct trigger
`GetText` bodies (slot 8 on the trigger side) - and the scope effects' and scope triggers' own block
texts but for `any_owned_province`. Listed by class with each body's rva, from the vftables, and cut
in five alphabetically:

| brief | what | fragment |
| --- | --- | --- |
| A | effect leaves, `CAddCoreEffect` .. `CMetalPoolEffect` (39) | `effect-text-add-to-metal.json` |
| B | effect leaves, `CModifySpiesEffect` .. `CWarexhaustionEffect` (39), and the 13 effects with a block text of their own, `random_list` among them | `effect-text-modify-to-war.json` |
| C | trigger leaves, `CActiveMissionTrigger` .. `CHasWarGoalTrigger` (49) | `trigger-text-active-to-war-goal.json` |
| D | trigger leaves, `CIdeologyGroupTrigger` .. `COutOfSupplyDaysTrigger` (49) | `trigger-text-ideology-to-supply.json` |
| E | trigger leaves, `COwnedByTrigger` .. `CYearTrigger` (47), and the 11 triggers with a block text of their own | `trigger-text-owned-to-year.json` |

Two more briefs run beside them, for the other two pieces:

| brief | what | fragment |
| --- | --- | --- |
| F | the on_actions: at each of the 13 sites, exactly when it fires, the scope it builds and who answers; `on_encirclement`'s area byte | `on-actions.json`, write-up `findings/FINDINGS-onactions.md` |
| G | messages: a type's settings, what decides between a popup, the log, the map and nothing, the popup and the log windows - the messages events and decisions raise are read already | `message-display.json`, write-up `findings/FINDINGS-messageshow.md` |

For each body: the keyword(s) that make the class; the line, word for word - the localisation key,
what is put in each `$VARIABLE$`, the colour codes, how a number is written (whole, thousandths, a
percent, a sign), what is named and from which scope; on the trigger side **both wordings**, for
`redWhen` 0 and 1; what is said where the target is missing; and whether the key exists in the base
game's localisation, with its English text. **Every brief asks** what looks wrong but is what the
bytes do. One write-up, `findings/FINDINGS-scripttext.md`, transcribed from the five reports.

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

Five briefs, built from the section above. Then the pipeline, which is idempotent:

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
