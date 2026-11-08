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

## The battle plans wave - the window of plans and drawing them on the map

> **LANDED 2026-11-08**, three fragments merged, launched on the maintainer's word: "Commit and continue with the battle plans". The write-ups are `findings/FINDINGS-battleplans.md` and `findings/FINDINGS-battleplandraw.md`. The next of the gaps in OpenHOI3's readme, *What of the interface is missing*.

**The question, for OpenHOI3**: everything `battleplans_window` does, what a plan is and where it is kept, and how a player draws one on the map. **Known before reading**: `BattlePlan_Serialize` (0x47C0), the `LoadKey`s of `CBattlePlanSendCommand`, `CBattlePlanDeleteCommand` and the tool options; RTTI names `CBattlePlanManager`, `CBattlePlanEntry`, `CBattlePlanToolOption` and its three children, `CConfirmDeletePlan`, `CConfirmSavePlan`. Files: `tfh/interface/battleplansinterface.gui`, `.gfx`, `tfh/interface/menubar.gui`, `battleplans/bp_settings.txt`.

| reader | brief | fragment |
| --- | --- | --- |
| **A** | **The window and the plans**: the manager, the data, the three tabs, every action, saved files, sharing with allies, the saved game. | `battleplans.json` |
| **B** | **Drawing**: each tool, the mouse on the map, what a drawing holds, and how arrows, borders, icons and texts are drawn. | `battleplandraw.json` |

The write-ups will be `findings/FINDINGS-battleplans.md` and `findings/FINDINGS-battleplandraw.md`.
