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

## The trade interface wave - the trade list, an offer to the player, automate-trade, the messages

> **LANDED 2026-10-13.** Both briefs ran and merged (37 addresses new, 3 structs, 22 struct fields, and
> one revision of `CEU3Dialog_SetTitle`'s callers; apply 179 `failed: 0`, `struct fields: 0`); the
> write-up is `findings/FINDINGS-tradeui.md`, indexed in `CANDIDATES.md`. It corrects
> `FINDINGS-tradeaid.md` A.6 on the messages' variables, and finds an offer's dialog is `eu3dialog.gui`'s
> `DefaultDialog`. Kept as history until the next plan replaces it.

Planned and launched 2026-10-13, for OpenHOI3's trade screens. The maintainer looked at its trade
window beside the original and asked for the trade interface finished, and for the variables of the
trade messages filled. The previous wave (`findings/FINDINGS-tradeaid.md`, landed the same day) read
the trade itself; this one reads the screens around it. The cut in two is the collecting session's.

**What is known and is not to be redone**:
- `findings/FINDINGS-tradeaid.md` section A: `CTradeAction` arm by arm, its slots 11, 12, 13, 14 and
  18, `FormatTradeGoods`, the `TradeDiplomacyDialog`, who is told which message key, the route's day,
  `CTradeCancelConfirm`'s constructor and `OnAgree` (a value-0 action, actor the player), the
  production trade list's inactive tooltip and `PW_IMPORTING` / `PW_EXPORTING`, `CAskTrade`'s text
  (`TRADEREQDESC`, `CONV_AT_TRADE`, `IS_BOUGHT_WITH_DEBT`), and the claim, **to be checked**, that
  "no shipped text uses" `ACT_TRADE` / `REC_TRADE` - `ACTRAWITHUS_6`, `WETRADEAG_4` and
  `BRKTRADEUS_6` do, and `WEDETRA_5` asks for `$ACTORS$`;
- `findings/FINDINGS-agreements.md` A3 and A4: the pending list, `AskPlayer` and its 13 kinds,
  `AddDiplomaticOffer`, the icon bar in outline (`CDiploIcon`, blinking from 120 h, declined after
  168 h), the dialog's two buttons and when it lapses, the player's automate-trade answering, the
  flag `GetLocalPlayer()+0x34`; and the record's `DiploIconBar_*` and `CDiploIcon::*` entries;
- `findings/FINDINGS-countryviews.md` section 4 (the production screen's four lists, entries not
  read), `FINDINGS-productiontooltip.md` (the trade list's tooltip in outline),
  `FINDINGS-diplomacyview.md` (the diplomacy screen) and `FINDINGS-messages.md` (how a message's
  variables are filled);
- measured, not read: the maintainer's screenshot of 2026-10-13 has the player's own trade dialog
  standing at the screen's centre plus `diplo_request_pos` (10, -100), to within three pixels.

| brief | what | fragment |
| --- | --- | --- |
| A | **the production screen's trade list and the trade messages**: `CTradeItem` (`0x803C70`) whole - its window in `country_production.gui`, every element and what it says, in what unit and colour, active and inactive, which side the player is on; the list's tooltip (`0x803FD0`) whole; how a line opens `CTradeCancelConfirm` and that dialog's window, texts and buttons whole (slot 0, `0x8050D0`); **the variables of the trade messages**: what the accept, decline and cancel arms of `CTradeAction::Apply` fill - `ACT_TRADE`, `REC_TRADE`, `ACTORS` and any other - with what text, from which side, and whether the cancel arm fills them; **the diplomacy screen's `trade_automate_checkbox`**: what a click does (a command, or the local player record), its frame, its tooltip | `trade-list.json` |
| B | **an offer to the player on screen**: `CTradeAction::AskPlayer` and `CAskTrade` whole - which window it builds, every element and text, whether its sliders show and move; the base `CDiplomacyDialog` (its five introduced slots) and how every `CAsk*` dialog is laid out and **placed**; the bar of offer icons - `AddDiplomaticOffer`, `DiploIconBar_Add`/`Update`/`Layout`, `CDiploIcon` whole: its window (`diplomessageicon_entry_window`) and `diplomessageicons_window`, where they stand and in what order, the flag, the blinking, the sound, the tooltip, what `+0x8` (the kind) selects, what a click does; and **where the player's own request dialogs stand** - the diplomacy view's use of `diplo_request_pos` (the window's slots 42 and 11), for `TradeDiplomacyDialog` and the standard dialog | `diplo-offer-icons.json` |

Both are written up as one, `findings/FINDINGS-tradeui.md`, a section each. **Every brief asks** what
looks wrong but is what the bytes do, and which figure is shown in what unit and colour.
