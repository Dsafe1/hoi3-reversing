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

## The order of battle browser wave - the tree of a country's forces, a ship's or brigade's card, and the sunk ships

> **LANDED 2026-11-08**, two fragments merged, launched on the maintainer's word ("commit and continue"), the next of the gaps in OpenHOI3's readme, *What of the interface is missing*. The write-ups are `findings/FINDINGS-oobbrowser.md` and `findings/FINDINGS-sunkships.md`. Three things the plan assumed were wrong: `COOBChange` is a country-history entry and not a drag record, there is no leader list in the browser, and the card and the sunk ships view are not reached from anything but a brigade row.

**The question, for OpenHOI3**: what `oobbrowser` shows and does, how a unit or leader is dragged in it, and what the unit panel's `brigade_view` and `sunk_ships_view` show, with making a ship the pride of the fleet. **Known before reading**: the classes `COOBBrowser`, `COOBUnitEntry`, `COOBChange`, `CBrigadeView`, `CSunkenShipsView`, `CSunkenShipEntry` and `CConfirmMakePride` exist by RTTI and have no records; `CMakePrideCommand::Execute` (0x1DB530), `GetPrideRedesignationDissent` (0xE6500), `CCountry_FindPrideOfTheFleet` (0xE64B0), `CSubUnit::ExperienceWithPride` (0x1AC430), `CEU3AI_ChoosePride` (0x499C80) and the sunk ships' list and ledger page are read.

| reader | brief | fragment |
| --- | --- | --- |
| **A** | **The order of battle browser**: `oobbrowser`, its split window, the unit and leader rows, what opens it, every button, the drag and what it posts. | `oobbrowser.json` |
| **B** | **`brigade_view`, `sunk_ships_view`**, the pride of the fleet's confirmation, and how each is opened. | `sunkships.json` |

The write-ups will be `findings/FINDINGS-oobbrowser.md` and `findings/FINDINGS-sunkships.md`.
