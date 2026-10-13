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

## The acting capital wave - which capital each reader reads

> **LANDED 2026-10-13.** One brief, merged (12 address entries, 4 of them new; apply 185/186 `failed: 0`, `struct fields: 0`); the write-up is `findings/FINDINGS-capitalreaders.md`, indexed in `CANDIDATES.md`.

Planned and launched 2026-10-13, for OpenHOI3, which is about to give its countries an acting capital
(`FINDINGS-surrender.md` D.5: where a government sits when its capital falls, and so where its stockpile
is). OpenHOI3 reads a country's capital in about a hundred places, written before the difference was
known; each must read the field the original reads there. One brief.

**What is known and is not to be redone:** `FINDINGS-surrender.md` D.5 (the two fields, `EnsureCapital`,
`UpdateActingCapital`, `GetPool`, the writers of `+0xE24`), C (the exile's acting capital); the 43 findings
files that already name `GetActingCapitalLocation`, `GetCapitalLocation` or the acting capital.

| brief | what | fragment |
| --- | --- | --- |
| A | **for each of OpenHOI3's reads of a country's capital** (a list of sites, each with what it does and the findings file its spec cites): which field the original reads at the matching place - the declared capital (`+0xE20`, `GetCapitalLocation`), the acting capital (`+0xE24`, `GetActingCapitalLocation`), the pool (`GetPool`), the original capital (`GetOriginalCapital`), or something else - settled from the findings or the record where they already say, and **read on the listing where they do not**; anything read goes in the fragment | `capital-readers.json` |
