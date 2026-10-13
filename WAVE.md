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

## The aid screens wave - the lend-lease window, the licence and share-technology dialogs

> **LANDED 2026-10-13.** Both briefs ran and merged (D: 31 addresses, 7 structs, 30 fields; E: 4 new
> addresses, 6 revised, 3 field comments; apply 180 `failed: 0`, `struct fields: 0`); the write-up is
> sections D and E of `findings/FINDINGS-tradeui.md`, indexed in `CANDIDATES.md`. Kept as history until
> the next plan replaces it.

Planned and launched 2026-10-13, for OpenHOI3's aid (debt, licences, lend-lease, shared technology),
whose rules `findings/FINDINGS-tradeaid.md` section C read; the screens around them were left. One
brief; the write-up is a section D of `findings/FINDINGS-tradeui.md`.

**What is known and is not to be redone**: `FINDINGS-tradeaid.md` C (every aid action arm by arm, the
debt and its repayment, `LendLease_GetRoute`, `UpdateLendLeaseRoutes`, `CDistributeLendLease`, the
receiver's IC, `GetMaxLendLeaseFraction`, `CChangeLendLeaseDistributionCommand`, the licence dialog's
list rule, serial and parallel, money slider, description and Agree, the share-technology dialog's
list rule and description, each kind's slots 11 to 18); `FINDINGS-agreements.md` B.2 (the rows) and A4
(the offer to the player); `FINDINGS-tradeui.md` (the offer dialogs and the icon bar);
`FINDINGS-countryviews.md` and `FINDINGS-productiontooltip.md` (the production screen and its
tooltips); `FINDINGS-sliders.md` if it exists (the production sliders).

| brief | what | fragment |
| --- | --- | --- |
| E | **lend-lease's IC, exactly**: `CDistributeLendLease::Distribute` (VA `0x518800`) line by line - what "available", "base percentage" and "factor" are and in what kind of number, the per-receiver amount, `GetResourceLimitedIC` and `ConsumeIcResources` as it calls them, `ReceiveLendLease` (rva `0x108900`); **the receiver's side** - the step of the IC calculation (`0x4F14D0` region) that adds `lend_lease_income / 1000` and rolls and drains the receipts vectors, exactly; **how each of the five other distributors uses `+0x608`**, the free pool: consumer goods `0x518D67`, **production** `0x519D5E` - its path where `+0x608` is not nought, which `FINDINGS-buildqueue.md` section 3 did not read - supply (already read), reinforcement `0x51BB96`, upgrades `0x51CEE9`; and **how a receiver's lend-lease convoy is manned** (`DistributeConvoyShips` and `GetDesiredTransports` for a lend-lease convoy, `FINDINGS-tradeaid.md` C.7) | `lendlease-ic.json` |
| D | **the lend-lease distribution window** (`tfh/interface/lendlease.gui`, `lendlease_distribution_window`): what opens it (the production screen's "Distribute", the opener rva `0x118BA0`, slot 8), every element - a receiver's row (`lendlease_country_entry`/`lendlease_entry`: flag, name, `actual_slider`, `actual_IC`, `cancel`) - what each shows, in what unit, what a slider and `cancel` post (`CChangeLendLeaseDistributionCommand`, `CRemoveLendLeaseCommand` - its constructor `0x155CA0`), the rows' order, its tooltips; the production screen's lend-lease slider: its `limit` marker (`GetLimit`) and what the "Distribute" button and the slider's need text say; **the licence dialog's rows** (`prod_share_entry`: `select_frame`, `counter_type`, `name`), their order, what selecting one does, the row tooltip; `0x107500` (a country's version of a unit type); **the share-technology dialog** (`interface/share_technology.gui`, ctor rva `0x3904D0`) whole - its rows, what a row shows ("Our", "Their"), selection, its title and buttons; and `0x507CE0` (whether a country already shares with another) | `aid-screens.json` |
