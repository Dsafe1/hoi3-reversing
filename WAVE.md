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

## The convoy-line wave - transports and escorts in the build queue

> **LANDED 2026-10-15.** Two briefs, merged (12 address entries landed and 9 revised; 1 struct declared, 5 fields;
> apply `failed: 0`, `struct fields: 0`); the write-up is `findings/FINDINGS-convoylines.md` sections A and B, indexed
> in `CANDIDATES.md`, where five things it left are queued.

Planned 2026-10-15, for OpenHOI3, on the maintainer's word that day ("Ok go ahead with the next step"): convoys in the
build queue are the second of six pieces in his order ("3 - 2 - 1 - 5 - 4 - 6": the province view, convoys in the
build queue, weather, transport and invasion, the headless run, the AI). OpenHOI3's queue holds units and buildings;
the production screen's `convoy` and `escort` buttons order nothing. Two briefs; the write-up is **a new
`findings/FINDINGS-convoylines.md`**, sections A and B.

**What is known and is not to be redone** (cite it; re-read on the listing only to raise an `inferred` record or
correct it):

- `FINDINGS-oob.md`, "On a convoy construction": `CConvoyConstruction::LoadKey` (rva `0x866B0`), `status = yes` marks
  escorts; `CConvoyConstruction::Deliver` (rva `0x86770`, **`likely`** and named from what it does, not from a slot -
  it is slot 9, by `vtable.py`).
- `CConstruction::LoadKey` (rva `0x83200`), the shared keys `id`, `cost`, `duration`, `progress`, `status`, `size`,
  `location`, `country`, `builder`.
- `FINDINGS-buildingqueue.md` sections A and B: the confirm dialog `CConfirmBuild` - its constructor's modes 1
  (transports, `picture_convoy`, `CONVOYS`) and 2 (escorts, `picture_escort`, `ESCORTS`), `Update` read for mode 0 only
  ("modes 1 and 2 take the convoy's and escort's own figures" - not read), `OnAccept` posting `parallel`
  `CConstructConvoyCommand(0 or 1, country)` (rva `0x1496A0`, the constructor, not read); `CProductionView::OnConvoyButton`
  (rva `0x4023F0`) and `OnEscortButton` (rva `0x4024E0`), both **`inferred`**; `CBuildQueueEntry`'s constructor picking
  slot 15 for a convoy (rva `0x3F4140`, the convoy arm not read); `CConstruction::CanStillBeBuilt` (rva `0x831C0`), which a
  convoy line holds and which never cancels; `CDistributeProduction::Distribute` pricing every line again on a day a
  line finished.
- `FINDINGS-countryviews.md` section 4: `transports_value` / `escorts_value` with `' (+N)'` the convoys being built,
  `N` summed over the lines as `size` times the define at `[defines + 0x9C] + 0x34` over a thousand; the button
  `escort` disabled unless the technology status's `+0x80` (`allow_escorts`) is set.
- `FINDINGS-uinumbers2.md` section 3: the technology status's `+0x44` `convoy_build_cost`, `+0x48`
  `convoy_build_time`, `+0x4C` `escort_build_cost`, `+0x50` `escort_build_time`, `+0x80` `allow_escorts`.
- `FINDINGS-buildqueue.md`: the queue, a unit's line, the day's loop.

**Found while planning** (planning's own reading, to be confirmed by brief A): `CConvoyConstruction`'s vftable has
**slot 14 a bare `ret`** (`0xABF890`) where a building line's slot 14 (rva `0x85B30`) prices the line - so a convoy line
looks priced once, when made, and never again; slot 15 is the folded `mov al,1; ret` (the "is a convoy" answer); slot 12
is `CConstruction::CanStillBeBuilt`; slot 10 answers token `0x4DE`. **Measured in the maintainer's saves:** about 75
convoy lines in each save of January to April 1936, every one at `cost` 2.000 and `duration` 100.000 (transports,
`status = no`) or 4.000 and 240.000 (escorts, `status = yes`) - Their Finest Hour's `CONVOY_BUILD_COST` 2,
`CONVOY_BUILD_TIME` 100, `ESCORT_BUILD_COST` 4, `ESCORT_BUILD_TIME` 240 - with `size` 1, 2, 4 or 5;
`CONVOY_CONSTRUCTION_SIZE` is 10.

| brief | what it settles | starting points |
| --- | --- | --- |
| **A. The line** | **`CConstructConvoyCommand`**: its constructor (rva `0x1496A0`: which arguments - is there an amount, and where does `size` come from? the id it mints), its vftable's slots (save, load, `IsValid`, `Execute` - every check that refuses an order, e.g. escorts without `allow_escorts`), and **`Execute` whole**: the `CConvoyConstruction` it makes - `cost` and `duration` from which defines and which technology fields (`+0x44`..`+0x50`), in which order, with what rounding and floors, `size`, `status`, where in the queue it goes. **`CConvoyConstruction`** whole: its constructor, its vftable (rva of each slot, `vtable.py` gives them), slot 2 (its save), **slot 9 `Deliver` read whole and raised or corrected** - how many transports or escorts one finished line gives (the define at `[defines + 0x9C] + 0x34` - which define?), whether it gives the whole `size` at once or one a time as a building line does, `progress` and `size` after, a message to the player, practical, anything else - slot 13 (its name on the queue), slot 14 confirmed empty, and who else ever sets a convoy line's `cost` or `duration` (a change of law? a technology researched?). **The day's loop**: anything `CDistributeProduction::Distribute` does differently for a convoy line. **The history**: how a `convoy_construction` block in `history/units` or a savegame is made into a line. **The Lua constructor** (the third caller, VA `0x98A0BD`): its arguments, for the AI later | VA `0x5496A0`, `0x5499B0`, `0x549770`, `0x5499A0`, `0x549C40`, `0x486770`, `0x4866F0`, `0x486860`, `0x98A0BD`; `CConvoyConstruction` and `CConstructConvoyCommand` RTTI |
| **B. The screen** | **`CConfirmBuild` in modes 1 and 2**: `Update`'s arms for them (rva `0x3F2490`) - `ic_cost_value`, `build_time_value`, the red/orange/green icon, `on_complete_icon` / `on_complete_impact` (hidden?), the counts' meaning for a convoy (does `serial` reach the command at all? `OnAccept` rva `0x3F3980`'s two convoy arms read for what they pass); **the production screen's `convoy` and `escort` buttons**: raise `OnConvoyButton` / `OnEscortButton` by finding which element each is attached to, when each is enabled, and **their tooltips** in `CProductionView::BuildTooltip` (rva `0x3FFD30`: `CONVOYS`, `LEDGER_ESCORTS` - which element says which, with which variables, main line and delayed half); **`CBuildQueueEntry`'s convoy arm** - its constructor's slot-15 branch (rva `0x3F4140`) and `Update` (rva `0x3F5...`, recorded as `CBuildQueueEntry::Update`): `counter_type`'s sprite, `unit_name`'s text, `unit_target`, `original_country`, `series_info`, and the tooltip of a convoy line on the queue if it has one | rva `0x3F2490`, `0x3F3980`, `0x4023F0`, `0x4024E0`, `0x3FFD30`, `0x3F4140`, `CBuildQueueEntry::Update`; `tfh/interface/country_production.gui`, `confirmbuild.gui` |
