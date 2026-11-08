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

## The attach wave - attaching, detaching and making a headquarters from the unit panel

> **LANDED 2026-11-08**, one fragment merged, launched on the maintainer's word: "One thing still missing from the unit card that I would do before: Detach, attach, create HQ". The write-up is `findings/FINDINGS-attachbuttons.md`.

**The question, for OpenHOI3**: what the single unit panel's `attach_button`, `detach_button` and four `create_*` buttons do when pressed, the window `attachment_selection_panel` with its rows (`CUnitAttachmentEntry`), and the multi-unit panel's `detach_multiunit` and `highercomm_multiunit`. **Known before reading**: `CAttachUnitCommand`, `CDetachUnitCommand::Execute`, `CCreateHigherCommand::Execute` and its one-unit constructor, `CInGameIdler::OnDetachMultiUnit` and `CInGameIdler::OnHigherCommandMultiUnit`, and when each button is shown and enabled (`CSingleUnitButtons::Update`).

| reader | brief | fragment |
| --- | --- | --- |
| **A** | The click handlers of the buttons, the attachment window and its rows, the multi-unit command's constructor. | `attachbuttons.json` |

The write-up will be `findings/FINDINGS-attachbuttons.md`.
