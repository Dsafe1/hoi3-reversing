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

## The diplomatic state wave - relation, threat and neutrality, and the screen that shows them

> **LANDED 2026-10-12.** All five briefs ran and merged (132 addresses, 7 structs, 76 struct fields;
> apply 159/160 `failed: 0`, `struct fields: 0`); the write-ups are `findings/FINDINGS-diplostate.md`
> and `findings/FINDINGS-diplomacyview.md`, indexed in `CANDIDATES.md`, and trap 19 came out of it.
> Left over: `CDiplomacyStatus`'s size, `0x80` (one `new(0x80)` before its only constructor call), is
> not in its struct record, because a declaration cannot add a size to a struct already recorded.
> **Two more briefs followed the same day**, when the reading showed a new game's relations come from
> the mod's Lua and threat is weighed on the alignment triangle: **F**, how the exe hosts Lua
> (`findings/FINDINGS-luahost.md`, `lua-host.json`), and **G**, the triangle's start and drift
> (`findings/FINDINGS-alignment.md`, `alignment.json`). Both merged; apply 161/162. Kept as history
> until the next plan replaces it.

Planned and launched 2026-10-12, for OpenHOI3's diplomacy, which the maintainer has cut in order:
what two countries hold of each other (relation, threat, neutrality, how each moves); the diplomacy
screen showing it; then the Lua the AI answers offers with; then the agreements, war and peace, and
factions. This wave is the reading for the first two. The agreements' `Apply` bodies are **not** in
it except where they move relation, threat or neutrality, and no Lua is.

**What is known and is not to be redone**:
- `findings/FINDINGS-diploaction.md`: the offer as an object, its lifecycle, the seven-day
  `next_offer_allowed`, the pending list;
- `findings/FINDINGS-diplomacy.md`, `FINDINGS-survivors.md`: `GetDiploScoreFromLua` and `yesmen`;
- `findings/FINDINGS-politics.md`, section 4: the country's daily pass `0x4DA530` call by call, the
  neutrality clamp and `EffectiveNeutrality`, the drift by `NEUTRALITY_CHANGE`, the influence upkeep;
  section 3's alignment terms (relation, threat) and `FACTION_THREAT_DIST`;
- `findings/FINDINGS-effectrun.md` 2.11 and the table: the `relation`, `threat` and `neutrality`
  effects, `SpreadThreatToAll`'s formula; `FINDINGS-triggerleaves.md`, `FINDINGS-numtriggers.md`: the
  conditions;
- the record: `CDiplomacyStatus` field by field (`+0x38` relation, `+0x5C` threat, `+0x2C` influence,
  `+0x30` align, the relation pointers), `CCountry::ChangeRelation` (rva `0xE65C0`),
  `CCountry::ChangeNeutrality` (`0xFBF80`), `SpreadThreat` (`0xF50A0`), `SpreadThreatToAll`
  (`0xF4E80`), `ThreatFactorTowards` (`0xFBCB0`), `CDiplomacyView::RebuildDecisionList` (`0x38C560`).

**What the start-date save says, which is the oracle for brief A**: each of the 101 country blocks
holds 78 pair blocks `TAG = { value threat }` - one for each country that exists - and the matrix is
symmetric. On 1 January 1936 threat is 0 everywhere and relation is 75 for 3,988 pairs, 0 for 3,226,
85 for 540 (every self-pair among them), 10 for 100, 200 for 20, 100 for 2 and -125 for 2.
`history/diplomacy/relation.txt` gives GER-ITA 200 and SOV-CHI 100; ITA-ETH -125 are at war; the
eight countries in a faction look to hold 0 with everybody. By 20 April threat has grown to 632
non-zero pairs, most of them 0.001 to 0.3, and relation has moved in steps of 15 beside
`last_send_diplomat` dates.

| brief | what | fragment |
| --- | --- | --- |
| A | **the start**: everything a new game does to the pair statuses, neutrality and threat - the five `history/diplomacy` files and `history/wars`, and whatever sets 75, 85 and 10, checked pair for pair against the start save; and a pair block's save keys | `diplomacy-start.json` |
| B | **threat**: every writer of `CDiplomacyStatus +0x5C`, the 14 callers of `SpreadThreat` and `SpreadThreatToAll` with what each spreads, whether threat decays, the most-threatening-country cache (`0x4E21E0`), and the three unread calls at the head of the daily pass | `threat.json` |
| C | **relation and neutrality over time**: the 24 callers of `ChangeRelation` with the amount and the condition at each, whether relation drifts on its own or by `DAYS_OF_INFLUENCE_RELATION_CHANGE` / `DAYS_OF_ALIGN_RELATION_CHANGE`; every writer of neutrality, what feeds `NEUTRALITY_CHANGE`, `NEUT_INCREASE_DIFF_CONTINENT`, `NEUT_REDUCTION_AT_CLAIMS`, war exhaustion's reset | `relation-neutrality.json` |
| D | **the diplomacy screen, its list half**: `CDiplomacyView` - showing, refreshing, the five tabs, the nine sort buttons, a row (`CCountrylistItem`) with every figure on it, choosing a country, the three toggled views and the mode arrows | `diplomacy-view.json` |
| E | **the diplomacy screen, its panel half**: `country_info` label by label, the status list, the relation list (`CRelationEntry`), the war-goal lists, the drift label, surrender progress, the most-threatening flag, and every tooltip on them | `diplomacy-panel.json` |

A, B and C are written up as one, `findings/FINDINGS-diplostate.md`; D and E as one,
`findings/FINDINGS-diplomacyview.md`. **Every brief asks** what looks wrong but is what the bytes do,
and which figure is shown or stored in what unit.

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
