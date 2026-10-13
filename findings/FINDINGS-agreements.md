# The agreements: an offer's way through the game, the screen's actions, and the pacts

Read out of the executable on 2026-10-13 by the agreements wave (`WAVE.md`), three briefs, for
OpenHOI3's diplomacy, whose fourth piece is the agreements. It builds on
`FINDINGS-diploaction.md` - the action object, its lifecycle, the twenty slot-7 bodies' defines and
messages - and **corrects its section 5**: the hourly loop that accepts every pending offer runs only
in the tutorial, and an AI answers by its foreign minister, every hour, on a score and a roll.
Transcribed by the collecting session; the three briefs' own words, lightly joined. Addresses are
**virtual**, based `0x400000`, with the rva beside anything named.

## In one line

**An offer** is made from the diplomacy screen's action list - a row per action
`CCountry::GetDiplomaticActionsToward` builds, greyed by slot 14 and for seven days after any
proposal to that country, whose button opens a dialog whose Accept posts it - or from Lua with
`PostAction`. **An AI country answers within the hour**: `GetAIAcceptance` 30 or less declines,
otherwise a roll of the game state's generator below the score accepts, one trade a call. **The
player** gets an icon that opens a dialog; unopened for seven days it declines itself, opened it lapses
two months after the offer (an alliance seven days). Guarantee, embargo, influence and align are
never answered: they take effect when offered. **A pact** is a `CRelation` hung on both statuses;
each charges influence on the offer, moves relation by its define on acceptance, and ends by being
broken or, in one daily pass, by itself - a NAP after `NAP_EXPIRY_MONTHS`, a guarantee after twenty
years, an alliance when both are in one faction.

## An offer's way through the game (brief A)

Read 2026-10-13. Addresses are virtual (based 0x400000), with the rva beside named ones. This section corrects `FINDINGS-diploaction.md` §5 "Reply".

### A1. The correction: the accept-everything pass is the tutorial's

The hourly pass's loop at `0x682B37` (`RunHourlyPass_TutorialAcceptAll`) accepts every pending PROPOSE whose slot 18 is true, then clears the list. RunHourlyPass reaches it only through `cmp byte [state+0xD9D],0; jne 0x682B37` at `0x682B14`, and `+0xD9D` is `tutorial_active`. On that path `ai_pass_done` is never cleared, so the parallel AI stops recurring.

In an ordinary game the clear at `0x682B1D` runs instead, and offers are answered by the foreign minister (A2). `FINDINGS-diploaction.md` §5 says an offer an AI does not act on in its first hour is discarded. That describes the tutorial. The record's comments on MakeCommand and ClearPendingDiplomaticActions repeated the error and are revised.

### A2. How an AI answers: `CAIForeignMinister::AnswerPendingOffers` (`0x89E010`, rva `0x49E010`)

`__stdcall`, the minister on the stack, `ret 4`.

**Who calls it, and how often.**
- **ProcessAI at `0x8896F7`, every hour.** It runs for every CEU3AI whose `+0x60` (the foreign minister) is non-null. The agent's enable byte `+0x3C` and the minister's hour are not tested on this path.
- **CAIForeignMinister::DoWork at `0x89D67D`, once a day** at the hour `(id + 13) % 24`, just before `ForeignMinister_Tick`.

So an offer to an AI is answered in the first AI pass after `CDiplomaticActionCommand::Execute` queues it, within the hour. ProcessAI's own gates still apply: CEU3AI `+0x128`, `theatres_dirty` (`+0x580`), and "no provinces and not a government in exile".

**What it does.** It walks the country's `+0xF24` list in arrival order. For each action:
1. If slot 18 is false, or `type != 0`, skip it. It gets no answer and is deleted at the end.
2. `score = GetAIAcceptance()` (slot 17, the mod's Lua).
3. If `score <= 30`, decline (`jle 0x1E` at `0x89E0A5`). No roll is drawn.
4. Otherwise `roll = MT19937Next(&gamestate->+0x124) % 100`. This is the game state's generator, not the AI's.
5. If `roll >= score`, decline. So it accepts exactly when `roll < score`, strictly.
6. If accepted and the action is not `trade_action` (`0x6DA`), mark it ACCEPT.
7. If it is a trade: the first trade accepted in this call is marked ACCEPT. Any later accepted trade is put on a local keep list, still PROPOSE.

**How an answer is posted.**
- The answer is written into the pending action itself: `type = 2` or `type = 1`.
- MakeCommand (slot 6) clones the action into a command.
- The command is posted through `country+0xF1C` slot 18 → `+0x38` slot 6.

**What is left afterwards.** `CCountry::RetainPendingDiplomaticActions` (`0x4E6410`, rva `0xE6410`, country in EAX) deletes every action on the list except the kept trades. With nothing kept, it is `ClearPendingDiplomaticActions`. Kept trades are rolled again on the next call.

A kept trade does not wait for ever. `RunCountryDailyPass` (`0x4DB042`) deletes, unanswered, any pending action whose `last_command_date + 96 h` is before today. That runs for every AI country, and for the player's own country only when his foreign policy is delegated.

### A3. Which countries answer

- **Every country gets a CEU3AI** when the AI starts (`0x683140`). The only exception is a scenario game (`+0xD0C` set), which an ordinary game is not: a live check on 1936-01-01 read 0, per `FINDINGS-aiconsumer.md`.
- **Every AI country gets all five ministers.** `CEU3AI::CreateMinisters` enables each one through slot 52, `CAIAgent::Enable` (five calls, `0x8889EF` to `0x888E8F`). That answers the old open item on what sets `+0x3C`.
- **The player's country gets a foreign minister only when foreign policy is delegated** (`GetLocalPlayer()->+0x38[0] == 1`, "Ai Control" on the diplomacy screen). Only then does `AnswerPendingOffers` answer offers made to him.

### A4. An offer to the player

`CEU3Idler::Update` (`0x644750`) handles this, every frame, on the main thread.

**When it does nothing.** If the local player has delegated foreign policy (`flags[0] == 1`), it shows nothing and the minister answers instead.

**What it does otherwise.** It walks the player's `+0xF24` list:
- A `trade_action`, while `automate_trade` is set, is kept on the list. That flag is `GetLocalPlayer()+0x34`, written by `CGameState::LoadKey` token `0x737` at `0x680698`.
- Every other action gets slot 19 (`AskPlayer`, with the idler as the host).
- Then `RetainPendingDiplomaticActions` empties the list except the kept trades.

So every offer is offered to the player exactly once.

**`AskPlayer` (slot 19).** Only a PROPOSE produces anything. It creates a 0x70-byte `CAsk*` dialog, which holds a clone of the action at `+0x6C`, and calls `CInGameIdler::AddDiplomaticOffer` (slot 24) with a kind and the sender's tag.

| kind | offer | condition |
| --- | --- | --- |
| 1 | peace | value set |
| 2 | alliance | value set |
| 3 | trade | value set |
| 4 | military access asked | value set |
| 5 | military access offered | value set |
| 6 | call to arms | value set, and only while the caller fights the enemy and the player is on neither side |
| 7 | non-aggression pact | value set |
| 8 | faction | any PROPOSE |
| 9 | expedition | value set |
| 10 | licence | any PROPOSE |
| 11 | debt | value set |
| 12 | lend-lease asked | value set |
| 13 | lend-lease offered | value set |

- A call to arms with `value` clear is accepted for the player without being shown.
- Guarantee, embargo, influence, align, declare war, share technology and the war-goal actions have the empty stub. They take effect when proposed.
- Replies (types 1 and 2) on the player's list show nothing here. They are deleted.

**`AddDiplomaticOffer` (slot 24, `0x674EF0`).** If the local player record's byte `+0x28` (the popup gate FireEvent also reads) is clear, the dialog is deleted. The offer then vanishes and no reply is ever sent.

Otherwise an icon goes into the bar at `CInGameIdler+0x1D38`:
- The icon is a `CDiploIcon`, window `diplomessageicon_entry_window`, showing the sender's flag.
- The `diplomaticoffer` sound plays.
- The icon blinks from 120 h.
- **After 168 h unopened, `CDiploIcon::Update` calls the dialog's Decline.**
- Clicking the icon opens the dialog.

**The open dialog.**
- Buttons: `AgreeButton` and `DeclineButton`, labelled `ACCEPT` and `DECLINE`.
- Accept (slot 5) sets `type = 2`; Decline (slot 6) sets `type = 1`. Either posts MakeCommand through the host and closes the dialog. Nothing is tested at the press.
- Every frame, slot 7 decides whether the dialog stays open, and calls **Decline** when it lapses:
  - **Base rule:** `AddMonths(action.date, 2) < now`, or `IsValid` false. Used by offer-access, faction, peace, debt, lend-lease and licence.
  - **Alliance:** `date + 168 h`, and no alliance or war already between them.
  - **NAP:** 2 months, and no alliance and no war.
  - **Military access asked:** 2 months only.
  - **Trade:** 2 months, and no war.
  - **Call to arms:** 2 months plus tests on who is in the war.
  - **Expedition:** the unit must still resolve.
- Each dialog's text key, with its $VARS$, is in the entries: ALLIANCEREQDESC "$ACTOR$ offers us an Alliance…", NAPREQDESC, MILACCREQDESC, MILACCOFFDESC, TRADEREQDESC, CALLREQDESC, PEACEREQDESC, INVITE/ASKFACTIONREQDESC, ASKDEBTREQDESC, ASK_/OFFER_LEND_LEASE_DESC, ASKBUYLICENCEREQDESC, ASKEXPEDITIONREQDESC.

**Trades under `automate_trade` (and foreign policy not delegated).** `CCountry::RunHourlyAITrade` answers them each hour on a worker thread, `0x4DC4A6`–`0x4DC66B`:
- `score = slot 17` for every pending PROPOSE whose slot 18 is true.
- Non-trades are kept for the dialog.
- Each trade's roll is `(r1*r2) % 100` from a **C-runtime `rand()` re-seeded to 1 on every call**. Accepted if `roll < score`; one acceptance per call; otherwise declined.
- **Since the seed resets, the rolls are the same every hour: 47, 0, 56, 24, 68, 25, 87, 51…** There is no ≤ 30 cut-off on this path.
- Actions failing slot 18, and replies, are dropped.

### A5. The reply reaches the proposer only as a message

Execute runs slot 7 for the reply on every peer. That raises the WE/THEY/OTHER message in `FINDINGS-diploaction.md` §17, keyed on `played_country_id`. Its popup and log settings come from `interface/messagetypes.txt`: MILALLACCEPT and MILALLREJECT `popup=yes log=yes`; WENAP `popup=no log=yes`; THEYNAP `popup=yes`. Execute then queues the reply on the proposer's list, where (for the player) slot 19 shows nothing and the entry is deleted. Nothing else tells the player.

### A6. An offer from the player

The row button `CDiplomaticActionItem` slot 4 → `0x78B9D0` opens a request dialogue; this is brief B's. Its agree handler, `0x773090` (B: `DiplomacyDialog_OnAgree`):
1. sets `action.date = now`;
2. MakeCommand, posted through the host;
3. rebuilds the action list and closes.

There is **no check at the press**. The dialogue's slot 7 keeps it open only while the view is open, the action's `IsValid` holds, and no other request dialogue is open (`view+0x518`).

`CEU3AI::PostAction` (from Lua) has no gate either. The shipped scripts check `IsSelectable` and `HasDiplomatEnroute` themselves. The only check every peer applies is Execute's `IsValid`.

Influence is charged in slot 7 on PROPOSE, whatever the answer. Brief B has slots 13 and 14.

### A7. `next_offer_allowed` (`CDiplomacyStatus +0x50`)

The reader is `CCountry::HasDiplomatEnroute` (rva `0xE3ED0`, B's): `tick <= proposer->E28[recipient]->+0x50`, inclusive, registered to Lua. It greys a row with ENROUTE, "We have a diplomat enroute, and he will arrive on $DATE$". The shipped AI scripts call it before posting.

So this is a seven-day cooldown on one country's offers to another, stamped on every PROPOSE except `callaction`, enforced where an offer is chosen and **not** in Execute.

My scan of every `[reg+0x50]` in the diplomacy ranges found 57 sites. Its positive controls: the setter's three accesses and LoadKey's `lea [ebx+0x50]` at `0xA482CB`. The one read through a status pointer is `0x4E3F6E`, which is that reader.

### A8. Every other place `type` changes or a pending list is cleared

`type` changes in:
- AnswerPendingOffers;
- RunHourlyAITrade's player block;
- CDiplomacyDialog Accept and Decline (direct, or from expiry);
- CCallAllyAction::AskPlayer;
- the tutorial loop.

A pending list is cleared by:
- RetainPendingDiplomaticActions, from AnswerPendingOffers, CEU3Idler::Update and RunHourlyAITrade;
- the daily 96-hour expiry;
- the tutorial loop.

### A9. What looks wrong but is what the bytes do

1. Only one trade can be accepted per call. Other accepted trades wait, are re-rolled each hour, and are silently dropped after 96 h.
2. The AI's answer rolls on the shared game-state generator, on parallel TBB workers. The order of draws across countries is not fixed.
3. The player's automated trades use a private `rand()` re-seeded to 1 every hour, so the "rolls" are a fixed sequence (47, 0, 56…). The first trade is accepted only if its score is above 47.
4. With the popup byte (`+0x28`) clear, an offer to the player is deleted with no reply.
5. Offers lapse on two different clocks. An unopened icon lapses 7 days after it **appeared**; an opened dialog lapses 2 months after the offer's **date**, but 7 days for an alliance. Some dialogs check `IsValid` each frame; alliance, NAP, access and trade do not.
6. A call to arms with `value` clear is accepted for the player without asking.
7. `next_offer_allowed` is stamped on every proposal, accepted or not, but Execute never tests it.
8. The answer is written into the pending action itself before it is cloned and posted.

### A10. What I could not settle

- What `CDiploIcon +0x8` (the kind) selects. I did not trace its reader.
- `CAskJoinWar::IsStillOpen` is read from the decompilation only.
- `DiploIconBar_Layout` was read for what it stores, not line by line.
- `ProcessAI`'s gate `CEU3AI +0x128` remains unread.
- In multiplayer: whether every peer runs AnswerPendingOffers for every AI, and so posts duplicate answers. Not read.

### A11. Frontier (rvas)

- `0x648B20`: a function called from the daily pass that raises `DIPLOEXPIRE` / `DIPLOEXPIRE_ALIGN`, apparently relations ending by themselves. This is brief C's.
- `0x23D830`: CEU3Dialog slot 1, the dialog update; 46 tables.
- `0x219E60`: the icon's second button callback.
- `0x2147B0`: the CDiplomacyDialog destructor; deletes the clone only while it is valid.
- `0x73FA30`: CEU3Idler slot 24.

## The diplomacy screen's actions

*Read on 2026-10-13 by the agreements wave's brief B, for OpenHOI3's diplomacy screen. Addresses are virtual, based `0x400000`, with the rva beside anything named. `FINDINGS-diplomacyview.md` covers the rest of the screen. Conventions used below:*
- *S is the actor's status towards the recipient, `actor->+0xE28[recipient]`.*
- *A "real faction" is one whose `CFaction` slot 7 answers true.*
- *Influence is `CCountry::GetDiploInfluence`: `diplo_influence` (`+0xA88`), or 100.000 while `g_UnlimitedDiploInfluence` is set.*
- *All figures are in thousandths.*
- *`FFP(x, n)` is `FormatFixedPoint` with n decimals, cut rather than rounded. "trimmed" is `FormatFixedPointTrimmed`.*

### B.1 In one line

The chosen country's panel shows `diploaction_list`. It has one row per action that `CCountry::GetDiplomaticActionsToward` (`0x4E3FE0`, rva `0xE3FE0`) builds for the player towards that country.

- **Each row is one button.** Its text is the action's slot 10 title. Its tooltip is the action's slot 11 text.
- **Greying.** The button is greyed every frame where slot 14 (`IsSelectable`) is false, or where slot 21 is true and a diplomat is en route.
- **Pressing never posts.** It opens a window. Fourteen kinds get the standard Accept/Decline dialog. Its Description is slot 12 and its chance line is the AI's score (slot 17) as a word, shown only where slot 18 is true. **Accept** stamps the action's date and posts `MakeCommand`.
- **Slot 13 (`IsValid`)** never greys a row. It closes the dialog and, per section 5, makes the command do nothing.

### B.2 Which rows, in which order (`GetDiplomaticActionsToward`)

`__thiscall` on the player's country, `(out list, recipient tag by value)`, ending `ret 0xC` at `0x4E57F5`. Its one caller is `CDiplomacyView::RebuildActionList` at `0x78C27C`. Every row is a fresh action, with its actor set through slot 9 and its recipient through slot 8. The rows, in order:

1. **At peace with them (S.war null):**
   - **Declare War** (`declarewar`, value 1), where S.alliance is null and the two are not in one real faction.
   - **Declare Limited War** (token 1213 `limited_war`, also a `CDeclareWarAction`, value 0), where also the player's `+0xDDC` is set. That byte is inferred to be the faction rule LIMITED_WAR (B.9).
2. **A Call to Arms!** (`callaction`, value 0, with the enemy at `+0x28`/`+0x2C`), where the player is at war. The enemy is the first one on its enemies list (`+0x1008`) that the recipient is not at war with and whose war has its byte `+0x70` set. The recipient must be allied or in the same real faction.
3. **Expeditions and technology,** where allied or in one real faction:
   - `send_expedition` value 1.
   - At most one value-0 type-3 `send_expedition` each way: retrieve ours, return theirs.
   - Then `share_technology`: value 0 (stop) where `0x507CE0(player, recipient)` is non-zero, which I infer means "already sharing". Otherwise value 1, where some flagged category puts the recipient below the player.
4. **Peace** (`peace_action`) and **Add war goal** (`add_war_goal`), value 1, where at war with them.
5. **Alliance:**
   - "Dissolve this Alliance" (value 0) where S.alliance is set.
   - Otherwise "Offer Alliance" (value 1), unless **both** are in real factions. The player must also not be a subject (`+0xF34`) and not a government in exile (`+0x95`), and the recipient must not be a subject unless it is the player's own.
6. **Non-Aggression Pact.** Always present: value 1 while S.nap is null, else "Revoke" (value 0).
7. **Proclaim Guarantee** (value 1), only where S.guarantee is null or the recipient is its guarantor. **No row ever revokes a guarantee**: where the player guarantees them, the row is simply absent.
8. **Military access,** unless the two are in one real faction:
   - **Ask for / Cancel Transit Rights** (`milaccess`, value = !S+0x4C).
   - **Give / Revoke Transit Rights** (`offermilaccess`, value = !`recipient->+0xE28[player]+0x4C`).
9. **Faction:**
   - **Invite to Faction** (value 0), where the player leads a real faction and the recipient is in none.
   - **Join Faction** (value 1), where the player is in none and the recipient leads a real one.
10. **Align:**
    - **Align to Faction** (value 1), where the player is in no real faction, S.war is null, S.align (`+0x30`) is null and the player is not a subject.
    - **Stop aligning** (value 0), where S.align is set.
11. **Embargo:**
    - **Embargo** (value 1), where S.embargo is null.
    - **Revoke Embargo** (value 0), where the embargo is the player's own (its `first` is the player).
12. **At peace only:**
    - **Buy Production Licence**, always.
    - **Allow / Revoke Debt** (value = !`recipient->+0xE28[player]->allowDebts`), where neither is a government in exile and the player is not a subject.
    - **Influence Nation / Stop influencing** (by `recipient->+0xE28[player]->influence_running`), where the recipient is in no real faction and is not a subject. Starting also needs the player major or with max_ic above 100.
    - **Offer Trade Agreement**.
    - **Request / Cancel Lend-lease**.
    - **Offer Lend-lease / Stop Lend-leasing**.

    **Influence, trade and the two lend-lease rows are kept only where their slot 13 (`IsValid`) already holds.** The rest are always listed and only greyed.

Rebuilding the list:
- **When it is rebuilt.** `RebuildActionList` runs when a country is selected, on Show, and after any dialog's Agree or Decline where that country is still selected.
- **What is kept.** Where the new list matches the rows already there (each row's token, recipient id, actor id and value), it only refreshes them. Otherwise it empties the list and makes a `CDiplomaticActionItem` per action, keeping the scroll position.
- **Hidden.** The list is hidden in a custom game.
- **Disabled.** It is disabled whole when the screen is set to AI control.

### B.3 A row (`CDiplomaticActionItem`, 0x88 bytes)

- **Constructor** (`0x78B3D0`): ECX is the in-game screen, from view `+0xB0`. The constructor keeps a clone of the action at `+0x7C` and the view at `+0x80`.
- **Button text** (`button_diploaction`): `GetText(slot 20 + "TITLE")`. The `.gui` default `PW_DIPLOMACY_ACTION` has no text and is always overwritten.
- **Enabled state** (row slot 11, `0x78B8A0`, also run every frame by `CDiplomacyView::Update`):
  - **Disabled** (button slot 47) where the action's slot 14 is false, or where its slot 21 is true and `CCountry::HasDiplomatEnroute(actor, recipient)` holds.
  - Otherwise enabled (slot 46).
  - Slot 21 answers true for every class except three: `CTradeAction` and `CSendExpeditionaryForceAction` answer `value`, so cancelling a trade or withdrawing an expedition is never greyed by a diplomat; `COfferLendLeaseAction` answers false for "stop" where the actor already gives lend-lease.
- **Tooltip** (`0x78B800`): `text` = slot 11 only. There is no delayed half and nothing about the AI's answer.
- **Diplomat en route.** `HasDiplomatEnroute` is `tick <= actor->+0xE28[recipient]->next_offer_allowed`, inclusive. `CDiplomaticActionCommand::Execute` sets `next_offer_allowed` to `date + 168` on every PROPOSE except `callaction`. **So for seven days after any proposal to a country, every row for it that slot 21 does not exempt is greyed, and its tooltip reads ENROUTE with the date.**

### B.4 Pressing a row (`DiplomacyView_OpenActionDialog`, `0x78B9D0`)

The window is chosen by the action's slot 15 token. It is placed at the `.gui` position `diplo_request_pos`, added to the in-game screen, and kept at view `+0x518`. The only branch that tests anything is share technology's `value`; nothing else is checked before opening.

| token | kind | opens |
| --- | --- | --- |
| `0x2F5` (and limited war) | declare war | **CWarGoalDialog** |
| `0x7A4` | add war goal | **CWarGoalDialog** |
| `0x6DA` | trade | **CTradeDiplomacyDialog** |
| `0x71A` | expeditionary force | **CExpeditionaryForceDialog** |
| `0x71C` | licence | **CLicenceTechnologyDialog** |
| `0x75D` | share technology | **CShareTechnologyDialog** when `value` is set; the standard dialog when stopping |
| alliance, guarantee, milaccess, offermilaccess, callaction, influence, nap, influence_leaders, embargo, faction_action, debt, peace, request_lendlease, offer_lendlease | | **CStandadDiplomacyDialogue** (`DefaultDiplomacyDialog`) |

**The standard dialog** (constructor `0x772B80`; it keeps its own clone of the action):

| element | what it shows |
| --- | --- |
| `LeftShield` / `RightShield` | the actor's and the recipient's flags |
| `Title` | slot 10 |
| `Description` | slot 12 |
| `chance_string` | B.5; where it is empty, it and `diplo_popup_chance_bg` are hidden |
| `AgreeButton` / `DeclineButton` | ACCEPT "Accept" / DECLINE "Decline" |

What the dialog's slots do:
- **Agree** (slot 5, `0x773090`, shared with the trade dialog). Sets the action's `date` = tick, then `MakeCommand` (slot 6), then posts through the in-game screen's slot 18 channel. Then it rebuilds the list and closes. The influence is charged later, when the command executes as PROPOSE (section 15).
- **Decline** (slot 6, `0x77B650`). Rebuilds the list and closes; nothing is posted.
- **While open** (slot 7). The dialog closes when the view is hidden or the action's `IsValid` turns false (inferred).

That slot 5 and slot 6 are the two buttons is inferred from what they do.

### B.5 What the AI's answer shows

**Only the standard dialog shows it** (`DiplomaticAction_BuildChanceText`, `0x7726F0`):
- Nothing where slot 18 is false. That is: guarantee, embargo, influence, align, share technology, declare war, and war goals always; military access and offered access when cancelling.
- Otherwise the score s = slot 17 (`GetAIAcceptance`) gives a word, with no figure:

| s | key | text |
| --- | --- | --- |
| < 1 | DIPCHANCE_IMPOSSIBLE | Impossible |
| < 10 | DIPCHANCE_VUNLIKELY | Very Unlikely |
| < 40 | DIPCHANCE_UNLIKELY | Unlikely |
| < 60 | DIPCHANCE_MAYBE | Maybe |
| < 80 | DIPCHANCE_LIKELY | Likely |
| otherwise | DIPCHANCE_VLIKELY | Very Likely |

**Nothing else on the screen asks slot 17.** `CDiplomacyView::BuildTooltip`'s thirteen slot-17 calls (`[reg+0x44]`, for example at `0x77FC0E`, `0x7800DF`, `0x780123`) are on the hovered element. They fetch its name for the string-compare dispatch.

### B.6 The arms every slot 11 shares

Each slot 11 renders the first arm that holds. The common arms, in the usual order:

| key | text | condition |
| --- | --- | --- |
| ACT_NO_SELF | "You cannot negotiate with yourself." | actor = recipient; absent from guarantee, military access, influence and align |
| ENROUTE | "We have a diplomat enroute, and he will arrive on $DATE$" | `HasDiplomatEnroute`; DATE = `next_offer_allowed` by `FormatHourDate` (then used as a `sprintf` format and through `GetText`) |
| WEWAR | "We are at War" | S.war |
| SUBJECT | "We are a subject country. It is not up to us." | the actor is a subject |
| DIP_NO_INFL | "You do not have the §Y$INF$§W diplomatic influence required" | influence below the cost |

DIP_NO_INFL's INF is printed with 0 decimals by alliance, NAP, embargo, trade, faction, licence, debt and expedition. It is printed with 2 decimals by guarantee, both military access kinds, influence, align, declare war and call to arms. Share technology prints cost / 1000 as a whole number.

### B.7 The eight agreements

For each kind: the title, slot 13 (decides), slot 14 (greys), slot 11 (tooltip, first arm that holds) and slot 12 (dialog body). DIP_INFLUENCECOST is "This will cost us §Y$COST$§W diplomatic influence points.", COST with 2 decimals.

**Alliance** - "Offer Alliance" (prefix `ALLIANCE`) / "Dissolve this Alliance" (prefix `CANCELALIANCE`, so spelled).
- **Slot 13, offer:** S.alliance null, S.war null, the actor not a subject and not a government in exile, the recipient not a subject unless it is the actor's own, and not both in one real faction.
- **Slot 13, dissolve:** S.alliance set, S.war null, neither at war with anybody (`+0xACC`), the actor not a subject, the recipient not a subject unless it is the actor's own.
- **Slot 14:** actor ≠ recipient, no diplomat en route, then:
  - Offer: slot 13's tests except the faction test; the **recipient** (not the actor) not in exile; **both** effective neutralities (`+0xA90`) ≤ ALLIANCE_NEUTRALITY_LIMIT (`+0x3C`); influence ≥ JOIN_ALLIANCE_INFLUENCE_COST (`+0xC`).
  - Dissolve: **neither** a subject, with no overlord exception; influence ≥ LEAVE_ALLIANCE_INFLUENCE_COST (`+0x10`).
- **Slot 11:** ACT_NO_SELF, ENROUTE, WEWAR, SUBJECT, then:
  - Offer: DIP_TO_NEUTR_THREAT for the actor, then DIP_THEY_TO_NEUTR_THREAT for the recipient ("The difference between our/their neutrality and the highest threat against us/them is too high. This value is §Y$VAL$§W while it needs to be lower than §Y$LIM$§W"; VAL = FFP(effective neutrality, 2), LIM = trimmed limit). Then DIP_NO_INFL (`+0xC`). Then OFFERALLIANCEDESC "If a country accepts our Alliance offer, it may come to our assistance during wars."
  - Dissolve: DIP_NO_INFL (`+0x10`), then CANCELALLIANCEDESC "Dissolving the current Alliance will, of course, end the current Alliance you have with this country, and will adversely affect relations."
- **Slot 12:**
  - Offer: ALLIANCENEWDESC "Do you wish to offer an Alliance to $COUNTRY$? Doing so will oblige us to assist each other in times of war." + DIP_INFLUENCECOST (`+0xC`).
  - Dissolve: BREAKALLIANCENEWDESC "Do you wish to cancel the Alliance with $COUNTRY$? This will upset them." + DIP_INFLUENCECOST (`+0x10`).

**Non-Aggression Pact** - "Non-Aggression Pact" / "Revoke Non-Aggression Pact".
- **Slot 13, offer:** S.alliance null, S.war null, the actor not a subject, the recipient not a subject unless the actor's own, influence ≥ NAP_JOIN_INFLUENCE_COST (`+0x54`). An existing NAP is not tested.
- **Slot 13, revoke:** S.nap set, S.war null, influence ≥ LEAVE_NAP_INFLUENCE_COST (`+0x5C`).
- **Slot 14:** actor ≠ recipient, no diplomat en route, slot 13's tests, and for a revoke also `CCountry::CanBreakNap`.
- **Slot 11:** ACT_NO_SELF, ENROUTE, WEWAR, SUBJECT, then:
  - Offer: DIP_NO_INFL (`+0x54`), else NAPEDESC "Promise not to declare war on them."
  - Revoke: DIP_NO_INFL (`+0x5C`). Then CANCELNAP_TOO_SOON_DESC "Non-Aggression Pacts cannot be broken for the first §Y$MONTHS$§W months." while tick < start + NAP_UNBREAKABLE_MONTHS. Then, inside each of the three NAP_FORCE_BALANCE_RULE_MONTHS windows, CANCELNAP_TOO_LOW_BALANCE "We need §Y$LIMIT_PERC$%§W of their brigades along our common borders. We currently have §Y$CURR_PERC$%§W." where the balance is below NAP_BREAK_FORCE_BALANCE_1/2/3 (`+0xEC`/`+0xF0`/`+0xF4`). The balance is `nap+0x24`, inverted to 1000000 / balance (or -1 at 0) when the recipient is the nap's `second`. LIMIT_PERC = floor(100.5) × limit / 1000 and CURR_PERC = 100 × balance / 1000, both trimmed. Otherwise CANCELNAPDESC "Revoke our promise of non-aggression".
- **Slot 12:**
  - Offer: NAPNEWDESC "Do you wish to sign a Non-Aggression Pact with $COUNTRY$?" + DIP_INFLUENCECOST (`+0x54`).
  - Revoke: BREAKNAPNEWDESC + DIP_THREAT "This will generate §Y$AMOUNT$§W threat in §Y$PROV$§W" (AMOUNT = LEAVE_NAP_THREAT_COST `+0x60`, PROV = the recipient's capital) + DIP_INFLUENCECOST (`+0x5C`).

**Guarantee** - "Proclaim Guarantee" (prefix `GUARANT`, one prefix whatever `value` says).
- **Slot 13:** S.war null and S.guarantee null. Either direction blocks, since the guarantee pointer is written on both statuses.
- **Slot 14:** actor ≠ recipient, influence ≥ GUARANTEE_INFLUENCE_COST (`+0x14`), the actor's effective neutrality ≤ GUARANTEE_NEUTRALITY_LIMIT (`+0x48`), S.war and S.guarantee null. There is no diplomat test of its own; the row is still greyed through slot 21.
- **Slot 11:** no `value` test at all, and no ACT_NO_SELF. In order: ENROUTE; DIP_NO_INFL (`+0x14`, 2 decimals); HASGUARANT "We are already guaranteeing them." where a guarantee exists and its guarantor is not the recipient; THEYGUARANT "They guarantee our independence, so we can not guarantee theirs." where it is the recipient; WEWAR; DIP_TO_NEUTR "Our neutrality is too high. It is currently §Y$NOW$§W and needs to be below §Y$LIM$§W." (`+0x48`); else GUARANTDESC "Proclaiming a guarantee will give us a chance to defend them against those who declare war on them."
- **Slot 12:** GUARANTNEWDESC "Do you wish to proclaim a guarantee for $COUNTRY$? If they are attacked, we will be called upon to join the fight." Then, where the **actor's** `+0xDE4` (rule ALLIANCE_GUARANTEE, inferred) is set, ALLIES_GUARANT "Should we need to come to their aid, all members of our faction will follow us." Then DIP_INFLUENCECOST (`+0x14`).

**Ask for / Cancel Transit Rights** (`CMilitaryAccessAction`; prefixes `MILACC` / `CANCELMILACC`).
- **Slot 13:** false where both are in one real faction. Otherwise true where S+0x4C ("we have access through them") is clear when asking, or set when cancelling.
- **Slot 14:** actor ≠ recipient, S.war null, influence ≥ MILACCESS_INFLUENCE_COST (`+0x2C`) **when cancelling too**, not one real faction, the S+0x4C test, and for a cancel **no unit of the actor in a province the recipient owns** (unit `+0x130` -> `+0x330`).
- **Slot 11** (it starts on the byte after slot 7's `ret`, trap 2): ENROUTE; DIP_NO_INFL (`+0x2C`, 2 decimals). Cancelling with access: CANCELMILACCDESC_NOPES_TROOPS "We cannot cancel transit rights while we still have forces inside their borders." or CANCELMILACCDESC "Cancel our Transit Rights in their country." Otherwise ISATWAR "You can not ask for Military Access when you are at war." where S.war (war with them, not war in general), else MILACCDESC "Request access to their territory."
- **Slot 12:** MILACCNEWDESC / CANCELMILACCNEWDESC with COUNTRY. No cost line.

**Give / Revoke Transit Rights** (`COfferMilitaryAccessAction`; prefixes `OFFERMILACC` / `REVOKEMILACC`).
- **Slot 13:** on `recipient->+0xE28[actor]+0x4C`: clear to give, set to revoke.
- **Slot 14:** actor ≠ recipient, S.war null, influence ≥ MILACCESS_INFLUENCE_COST (`+0x2C`), then slot 13's test.
- **Slot 11:** ENROUTE; DIP_NO_INFL (`+0x2C`, 2 decimals); revoking shows **REVOKEMILACCTITLE** "Revoke Transit Rights." as its description; giving shows OFFERMILACCDESC "Enable them to station troops and ships in our country."
- **Slot 12:** OFFERMILACCNEWDESC / REVOKEMILACCNEWDESC with COUNTRY.

**Embargo** - "Embargo" / "Revoke Embargo".
- **Slot 13, impose:** S.alliance null, S.war null, the actor not a subject, the recipient not a subject **or the actor's own puppet**.
- **Slot 13, lift:** S.embargo set.
- **Slot 14:** actor ≠ recipient, no diplomat en route, then:
  - Impose: not one real faction; S.alliance and S.war null; the actor not a subject; **the recipient not the actor's own puppet** (the reverse of slot 13); the actor's effective neutrality ≤ EMBARGO_NETRALITY (`+0x84`); influence ≥ EMBARGO_INFLUENCE_COST (`+0x28`).
  - Lift: S.embargo null **or** the actor's own, and S.war null.
- **Slot 11:** ACT_NO_SELF, ENROUTE, WEWAR, SUBJECT, then:
  - Impose: DIP_NO_INFL (`+0x28`, 0 decimals), then DIP_TO_NEUTR_THREAT (`+0x84`), then EMBARGODESC "Prevent them from trading with you."
  - Lift: CANCELEMBARGODESC "Enable trading.", with no influence test.
- **Slot 12:**
  - Impose: EMBARGONEWDESC (RECIPIENT; the text carries a literal `\n`) + DIP_INFLUENCECOST (`+0x28`). A DIP_THREAT with EMBARGO_THREAT_COST (`+0x88`) and the recipient's acting capital is filled in and **never shown**.
  - Lift: CANCELEMBARGONEWDESC.

**Influence Nation** - "Influence Nation" / "Stop influencing nation" (`CInfluenceNation`, 0x2C bytes). Its `+0x28` is the static modifier the **actor's** faction's `influence` key names, looked up when the action is made.
- **Slot 13:** S.war null, the actor in a real faction, the recipient with no overlord or the actor as overlord, the actor major or with max_ic above 100, both owning a province. Starting is then valid; stopping is valid where the recipient has the faction's influence modifier.
- **Slot 14:** actor ≠ recipient, the recipient owns a province, the actor not a subject and major or above 100 IC, S.war null, then:
  - Starting: the recipient **without** that modifier, and influence ≥ INFLUENCE_INFLUENCE_COST (`+0x30`).
  - Stopping: the recipient **with** it.
  - Either way: where the recipient is at war, not with any member of the actor's faction.
  - There is no diplomat test.
- **Slot 11:** ENROUTE, then:
  - Stopping: STOPNFLDESC (so spelled) "Stop Improving relations with nation."
  - Starting:
    - DIP_NO_INFL (`+0x30`, 2 decimals), then WEWAR.
    - THEY_AT_WAR_WITH_FACTION "They are at war with our faction."
    - Where the recipient already has the modifier: DIP_ALLREADY_INF. Base text: "$RECIPIENT$ is already being influenced by $NATION$ of our faction. Their influence will cease on $DATE$."; Their Finest Hour's text drops the date. NATION is the last faction member found influencing or aligning them. With none found, the key ERROR is shown, which has no text.
    - Otherwise INFLDESC "Influence nation towards your faction."
- **Slot 12:**
  - Starting: INFLNEWDESC "Do you wish to exert influence on $RECIPIENT$?\nThis will move them $VAL$ towards $FACTION$ each day for $TIME$ days." TIME is UNLIMITED "Unlimited" where DAYS_OF_INFLUENCE_RELATION_CHANGE (`+0x74`, -1 in Their Finest Hour) is below 0. VAL = FFP(the modifier's ALIGN_TOWARDS, 2). **There is no cost line.**
  - Stopping: STOPINFLNEWDESC.

**Align to Faction** - "Align to Faction" / "Stop aligning towards faction" (`CInfluenceAllianceLeader`).
- **Slot 13:** not (at war with them and starting); the actor in **no** real faction; neither a subject; both owning a province. S.align and the recipient's faction are not tested here.
- **Slot 14:** actor ≠ recipient; not (at war with them and starting); influence ≥ ALIGN_INFLUENCE_COST (`+0x7C`) either way. Let M be the recipient's faction's influence modifier. Then:
  - Starting: the actor without M; the recipient's faction real and the recipient its leader (first member); S.align null; and, if the actor is at war, not with any member of that faction.
  - Stopping: the actor with M, and S.align set.
- **Slot 11:** ENROUTE; DIP_NO_INFL (`+0x7C`, 2 decimals; stopping too); WEWAR; ALIGN_NO_FACTION "They are not in a faction you can align with."; ALIGN_NOT_LEADER "They are not the leader of $FACTION$, try $LEADER$"; ALIGN_ALLREADY_ALL "We are already aligning ourselves to $FACTION$. This action will be done on $DATE$."; AT_WAR_WITH_FACTION "We are at war with their faction."; else ALIGNDESC "Align yourself to a faction." **Stopping shows ALIGNDESC too.**
- **Slot 12:**
  - Starting: ALIGNNEWDESC (FACTION, VAL = ALIGN_TOWARDS of M, TIME from **DAYS_OF_INFLUENCE_RELATION_CHANGE** `+0x74`, not DAYS_OF_ALIGN `+0x78`).
  - Stopping: STOPALIGNNEWDESC "Do you wish to stop aligning towards $RECIPIENT$?". No cost line.

### B.8 The other kinds (read for keys and the shape of their gates)

**Declare War / Declare Limited War** (prefixes `WAR` / `LIMWAR`; titles "Declare War" / "Declare Limited War").
- **Slot 13:** no war, no alliance, not one real faction, and `0x47BF70` (not read).
- **Slot 14:**
  - The recipient owns a province, not REB, no truce.
  - Influence ≥ WARDEC_INFLUENCE_COST, and no diplomat en route.
  - Puppet rules.
  - Every NAP it would break must be breakable: with the recipient, its faction leader, its overlord and its allies (`+0xF88`).
  - Effective neutrality ≤ `GetMaxNeutralityForWarWith`.
  - None of the actor's land units in a province the recipient controls.
- **Slot 11:**
  - Base arms: HAS_TRUCE_WITH "Have truce with " + name, and ENROUTE.
  - With no NAP: NO_WAR_ALLIED, DIP_NO_INFL, DIP_WAR_NEUTR (NEUT/THEM/THREAT), NO_WAR_MILITARY_ACCESS, else ACT_WARDESC.
  - With a NAP: DECLARE_WAR_NAP_LIMIT_DATE, DECLARE_WAR_NAP_LIMIT_TROOPS_BALANCE, else DECLARE_WAR_NAP_BREAKABLE.
  - Limited war appends "\n" + LIMITED_WARDESC.

**A Call to Arms!** (prefix `CALL`).
- **Gate:** the actor at war with the enemy, the war's `+0x70` set, influence ≥ CALLALLY_INFLUENCE_COST, and no NAP of the recipient with a country on the side it would fight.
- **Slot 11:** CAN_NOT_JOIN_WAR_NAP, else CALLDESC.

**Expeditionary force.**
- **Titles:** slot 20 returns the localised SENDEXPED, RETRIEVEEXPED or RESENDEXPED. Those keys have no text, so the key comes back unchanged and `+TITLE` resolves to "Expeditionary Force", "Retrieve…" or "Return Expeditionary Force".
- **Slot 14:** needs the unit ref (`+0x2C`) to resolve (inferred).
- **Slot 11:** SENDEXPEDDESC, RETRIEVEEXPEDDESC or RESENDEXPEDDESC.

**Share Technology / Stop Sharing Technology.**
- **Slot 13, stopping:** always true.
- **Slot 13, sharing:** the dialog's chosen category must put the actor above the recipient.
- **Slot 14:** no war, no diplomat; when sharing, influence ≥ SHARE_TECH_INFLUENCE_COST.

**Peace.**
- **Slot 13:** at war with them.
- **Slot 14 and 11:** PEACE_FACTION "You are both in factions, and factions fight until they surrender". PEACE_NOT_LEADER "You can only negotiate with the leader of your enemy" unless each is the first country of its side. Otherwise PEACEDESC.

**Add war goal** (prefix `WARGOAL`).
- **Slot 11:** DIPL_NOT_AT_WAR, which has no text and so shows the key, when not at war. Otherwise `""` or the reasons from `0x4E68C0` (not read).

**Join / Invite to Faction.**
- **Slot 13:** neither in exile; the inviter leads a real faction and the invitee is in none, or the reverse for joining.
- **Slot 11:**
  - DIP_THEY_PUPPET "They are a puppet state of §Y$OVERLORD$§W", then DIP_NO_INFL (JOIN `+0x8C` / INVITE `+0x90`).
  - The neutrality texts, with **swapped limits** (B.9).
  - FACTION_DISTANCE / FACTION_DISTANCE_2 (VAL = FACTION_JOIN_DIST, VALC = the current distance).
  - JOINFACTIONDESC / INVITEFACTIONDESC.

**Buy / Sell Production Licence.**
- **Slot 13:** not at war with them.
- **Slot 14:** no diplomat, no war; buying needs influence ≥ LICENCE_INFLUENCE_COST.
- **Slot 11:** BUYLICENCEDESC; SELLLICENCEDESC has the same text.

**Allow / Revoke Debt.**
- **Slot 13:** neither in exile.
- **Slot 14:**
  - Allowing: `actor->+0xE28[recipient]->allowDebts` clear. Revoking: `recipient->+0xE28[actor]->allowDebts` set.
  - Influence ≥ **both** ALLOW_DEBT_INFLUENCE_COST and REVOKE_DEBT_INFLUENCE_COST.
  - No war.
- **Slot 11:** WEWAR, ENROUTE, DIP_NO_INFL, then ALLOWDEBTDESC / REVOKEDEBTDESC.

**Offer / Cancel Trade Agreement.**
- **Slot 13:** recorded already.
- **Slot 14:**
  - Cancelling: always true.
  - Offering: no war, puppet rules, influence ≥ TRADE_INFLUENCE_COST, ports on both sides where trade needs convoys, and no embargo of theirs on us.
- **Slot 11:** ENROUTE, WEWAR, SUBJECT, DIP_NO_INFL (TRADE `+0xA0` / TRADE_CANCEL `+0xA4`), then CANCELTRADEDESC, or CDIP_EMBARGO "Embargoed by $LIST$", TRADENO_PORTS, TRADEDESC.

**Lend-lease.**
- **Slot 13:** the recipient owns a province.
- **Slots 14 and 11:** go through `0xA0FEC0` / `0xA11790` (ENROUTE) and then `0xA10180`, which was not read.
- **Texts:** LEND_LEASE_DESC "Request industrial aid", LEND_LEASE_CANCEL_DESC, OFFERLL_DESCRIPTION, STOPLL_DESCRIPTION.

### B.9 What looks wrong and is what the bytes do

1. **A guarantee cannot be revoked from the screen.** No row is built when the player is the guarantor. When they guarantee us, the row shows greyed with THEYGUARANT.
2. **Slot 13 and slot 14 disagree.**
   - Alliance: 13 tests the actor's exile and the shared faction; 14 tests the recipient's exile and not the faction.
   - Embargo: 13 allows embargoing your own puppet and 14 forbids it. Lifting passes 14 with no embargo at all, while 13 needs one.
   - Debt: the row's value is read from the recipient's side, but 14 tests the actor's side when allowing.
   - The row greys on 14 only. 13 closes the dialog and makes the posted command a no-op.
3. **The AI-chance bands do not match the AI's cut-off.** The planning finding is that a score of 30 or less is always declined, yet scores 10 to 30 read "Unlikely" and 1 to 9 "Very Unlikely".
4. **The faction texts swap their limits.** The join test checks JOIN_FACTION_NEUTRALITY but prints LIM = INVITE_FACTION_NEUTRALITY, and the invite test the other way round. Both are 25 in Their Finest Hour.
5. **Some dialogs omit what they promise or charge.**
   - The embargo dialog builds a DIP_THREAT line and never shows it.
   - The influence and align dialogs show no influence cost.
   - The align dialog's duration comes from DAYS_OF_INFLUENCE, not DAYS_OF_ALIGN.
6. **Military access charges oddly.** Offering access costs nothing when accepted, yet the row needs MILACCESS_INFLUENCE_COST. Cancelling our own access also needs it.
7. **Some descriptions are odd.**
   - Revoking offered access uses REVOKEMILACCTITLE as its description.
   - Stopping alignment shows ALIGNDESC.
   - STOPNFLDESC is misspelt, and ERROR and DIPL_NOT_AT_WAR have no text.
8. **DIP_ALLREADY_INF's date is nonsense with the shipped define:** start + (-1) days. Their Finest Hour's text drops `$DATE$`.
9. **ENROUTE is inclusive.** `tick <= next_offer_allowed` counts the last hour as en route. The date string is passed to `sprintf` as a format.
10. **DIP_NO_INFL decimals vary by class** (0, 2, or cost/1000 as a whole number).
11. **The expedition titles work only because their keys have no text.** If SENDEXPED were ever translated, the title lookup would break.
12. **The rule bytes are inferred.** `+0xDD4`/`+0xDDC`/`+0xDE4`/`+0xDEC` stand in the order of the four faction rules NONE, LIMITED_WAR, ALLIANCE_GUARANTEE, FREE_RESOURCE_GIFTS. Only `+0xDDC`, `+0xDE4` and `+0xDEC` have a reader that fits that meaning. **`+0xDDC` is set in play** (2026-10-13): the maintainer's screenshot of the original's action list shows "Declare Limited War" under "Declare War", for a player who leads a faction (the list has "Invite to Faction") - so, unlike `+0xDE4` (C.3), something writes it. Its writer is still unread, and which faction the screenshot was of was not said; that it is the faction's rule remains the inference, now with a positive observation beside it. *Settled 2026-10-13: the writer is `CCountry::RebuildRules` through `CRule::Merge`, and the bytes are the faction's rules (`FINDINGS-factionplay.md` B.3).*

### B.10 Not settled

- **Dialog buttons and closing.** Which `CEU3Dialog` slots `AgreeButton` and `DeclineButton` call (slots 5 and 6 are inferred from what they do), and that `StaysOpen` false closes the dialog.
- **Units on the war rows.** `CSendExpeditionaryForceAction`'s unit `+0x290`/`+0x294` and the defines date the builder compares against.
- **Unread callees.** `0x507CE0` (sharing already?), `0x47BF70`, `0x4E67D0`, `0x4E68C0`, `0xA526D0` (war goal and call-to-arms gates), `0xA10180` (lend-lease eligibility and its reasons). The war byte `CWar +0x70`.
- **The other dialogs' insides.** The trade, licence, expedition, share-technology and war-goal dialogs were not read past "this window opens".
- **Rule bytes.** No writer of 1 to `+0xDDC`/`+0xDE4` was looked for, so the rule meaning is inferred. *Settled 2026-10-13: `CCountry::RebuildRules` writes all four through `CRule::Merge` from the faction's `rule` block (`FINDINGS-factionplay.md` B.3).*

### B.11 Frontier (rvas)

`0x107CE0`, `0x7BF70`, `0xE67D0`, `0xE68C0`, `0x6526D0`, `0x610180`, `0x60FEC0`, `0x611790`, `0x103C60` (`CCountry::NeedConvoyToTradeWith`, named in decompiles but no entry), `0x63F510` / `0x646980` (the folded set-recipient and set-actor setters, slots 8/9 of 34 tables across both diplomacy families), `0x23E6F0` (`CEU3Dialog` set-Description).

## C. What the pacts do

Read on 2026-10-13 by brief C of the agreements wave, out of the executable. Checked against the 12 savegames now on the machine and Their Finest Hour's `tfh/common/defines.lua`. Addresses are **virtual**, based at `0x400000`, with the rva given beside anything that is named. `type` is the action's `+0x18`: 0 PROPOSE, 1 DECLINE, 2 ACCEPT. `value` is the bool at `+0x24`. Every relation change goes through `CCountry::ChangeRelation(actor, recipient, delta)`, which writes one clamped value to both directions. Relation is in thousandths on a ±200.000 scale. Influence is `CCountry +0xA88`, also in thousandths.

### C.1 In one line

Every pact's slot 7 has the same skeleton: charge the actor's influence on PROPOSE; on ACCEPT build the `CRelation`, hang it on the statuses (slot 10) and append it to the list at `+0xB2C`; on `value == 0` take it off (slot 11, unlink, delete). Guarantee, embargo, influence and align **test no `type` at all** and take effect on the offer.

Agreements also end by themselves, in one daily function, `CDiplomacyStatus_ExpireRelations` (rva `0x648B20`), which asks each relation's slot 6:
- an alliance when both partners sit in one real faction;
- a NAP after `NAP_EXPIRY_MONTHS`;
- a guarantee after a fixed twenty years;
- a casus belli on its end date;
- an influence or an align when its faction conditions fail (`DAYS_OF_*` is −1 in Their Finest Hour, so never by time).

`end_date` matters to nothing live except a casus belli. A war ends:
- the alliance and the NAP between the two belligerents (CDeclareWarAction);
- their influence and trade (SetPairWar);
- their access and debts (CDeclareWarAction);
- the guarantee, which it only nulls.

### C.2 Alliance — `CAllianceAction::Apply`, `0xA18D70` (rva `0x618D70`)

- **PROPOSE, value set**: `diplo_influence -= JOIN_ALLIANCE_INFLUENCE_COST` (diplomacy `+0xC`, 5 in Their Finest Hour), clamped at 0.
- **ACCEPT, value set**:
  - `new(0x24)` CAlliance; first = actor, second = recipient, `start_date` = the action's `date`;
  - slot 10 (`+0x14` and `changed` on both directions), **then** appended to the relation list;
  - `ChangeRelation(+ALLIANCE_RELATION_CHANGE)` (+15);
  - messages MILALLACCEPT / MILALLWEACCEPT / MILLALLINVACCEPTOTHER;
  - RebuildNeighbours and `0x4E39C0` on both countries.
- **DECLINE**: messages only. No relation change, no refund.
- **value == 0, any `type`** (leaving):
  - `actor->diplomacy[recipient]->alliance` is taken **with no null test**;
  - slot 11, unlink, delete;
  - `ChangeRelation(ALLIANCE_REJECT_RELATION_CHANGE)` (−50);
  - `diplo_influence -= LEAVE_ALLIANCE_INFLUENCE_COST` (1);
  - messages MILALLWEBAN / MILALLBAN / MILALLBANOTHER;
  - then a **second `ChangeRelation(−30000)`**;
  - RebuildNeighbours on both.
- **Every arm** ends, in a running game, with a refresh push (`0x45F5E0`) and `in_game_screen +0x84 |= 0x100`.

**An alliance does nothing to factions, wars or other pacts in this body.**
- Allies join a war only through the call-to-arms offers `CDeclareWarAction::Apply` manufactures. Its `+0x14` readers are at `0xA121FC` and in its helper at `0xA148FC`; that is the later piece.
- A declaration of war between two allies ends their alliance there: `0xA121FC`–`0xA122C2` runs Deactivate, unlink and delete.

### C.3 Guarantee — `CGuaranteeAction::Apply`, `0xA1BCC0` (rva `0x61BCC0`)

- **value set**:
  - `new(0x28)` `CGuarantee(0)`; first = guarantor, second = recipient, `start_date` = date;
  - appended (`0xA1BDCA`), **then** slot 10 (`+0x1C` on both directions);
  - **if the guarantor's `CCountry +0xDE4` byte is set**, every other member of its faction also guarantees the recipient, through `CGuarantee(1)`. Nothing in `.text` ever writes 1 to `+0xDE4` (disp32 scan; the positive control finds CCountry_Reset's clear), so this branch is dead; *Corrected 2026-10-13 (`FINDINGS-factionplay.md` B.3): `CCountry::RebuildRules` writes it through `CRule::Merge`, a disp8 store off `&country->Rules (+0xDBC)` that the disp32 scan could not see - a member holds its faction's rules, so this branch is live for the Allies.*
  - `diplo_influence -= GUARANTEE_INFLUENCE_COST` (5);
  - messages WEGUARAT / GUARATOUS / GUARATOOTHER;
  - **no relation change**.
- **value == 0** (revoking):
  - `actor->diplomacy[recipient]->guarantee` is taken with no null test and no check that the actor is its `first`;
  - slot 11, unlink, delete;
  - `ChangeRelation(REVOKE_GUARANTEE_RELATION_CHANGE)` (−20);
  - `diplo_influence **+=** REVOKE_GUARANTEE_INFLUENCE_COST` (1);
  - messages GUARACANCELTOTHEM / GUARACANCELTOUS.
- Both arms end with RebuildNeighbours and `0x4E39C0` on both countries.

**Readers of `+0x1C`.** From a register-taint sweep of every `.text` chunk that mentions `0xE28`; the positive control finds CGuarantee::Activate's and Deactivate's stores.
- MonthlyRelationDrift: +80 thousandths.
- RebuildNeighbours: the list at `+0xFC8`.
- **CDeclareWarAction::Apply**, which:
  - manufactures a call to arms from the attacked country to each of its guarantors (`0xA12B40`–`0xA12BE4`); this is the war-declaring side and the later piece, so I stop there;
  - **nulls the guarantee between the belligerents without unlinking it** (`0xA12E14`, `0xA12E42`).
- MakeVassal (nulls it, does not delete), AnnexCountry, and the capitulation.
- The script: CGuaranteeEffect, CEndGuaranteeEffect, CGuaranteeTrigger.
- The status lines, the drift breakdown, `GuaranteeTextCommand`, `CDiplomacyStatus_ExpireRelations`, and Lua's `IsGuaranting` / `IsGuaranteed`.

### C.4 Military access

**`CMilitaryAccessAction::Apply`**, `0xA231F0` to `0xA247BF`. This is trap 2: slot 11 begins at `0xA247C0`.
- **PROPOSE, value set**: `−MILACCESS_INFLUENCE_COST` (1).
- **ACCEPT, value == 1**:
  - `SetMilitaryAccess(1, actor->diplomacy[recipient])`. **One direction: the asker may enter the granter's land;**
  - `ChangeRelation(+MILACC_ACCEPT, +10)`.
- **DECLINE, value == 1**:
  - −10 (`MILACC_DECLINE`), **only where either country is played**;
  - the asker's cost is refunded.
- **value == 0, any `type`** (the asker gives up its own access):
  - −10, again `MILACC_DECLINE` (`MILACC_CANCEL`, −20, has no reader);
  - `SetMilitaryAccess(0)` on the same one direction.

**`COfferMilitaryAccessAction::Apply`**, `0xA25830`. No influence is charged and no define is read.
- **ACCEPT**: `SetMilitaryAccess(1, recipient->diplomacy[offerer])` and +10000.
- **DECLINE**: messages only.
- **value == 0** (withdrawing the offer):
  - −20000, only where someone is played;
  - then `SetMilitaryAccess(0)` in **both** directions.

**Units.** Neither body moves any unit. A unit standing in the other's land is slot 11's business, `CANCELMILACCDESC_NOPES_TROOPS`: "We cannot cancel transit rights while we still have forces inside their borders." That is brief B's.

### C.5 NAP — `CNapAction::Apply`, `0xA2B090`

Section 15 of `FINDINGS-diploaction.md` is confirmed except for one missing write.

- **Break arm**: the order is `nap` (no null test) → **slot 11 `CNap::Deactivate` at `0xA2BEEA`** (nulls `+0x28` both ways) → unlink → delete → SpreadThreat(recipient, `&LEAVE_NAP_THREAT_COST`) → −30 → `−LEAVE_NAP_INFLUENCE_COST`.
- **DECLINE** (−20 at `0xA2C433`): the key is THEYREJECTNAP when the actor is the player.
- **Expiry**: `CNap::IsOver` (rva `0x6470F0`) is `tick > AddMonths(start_date, NAP_EXPIRY_MONTHS / 1000)`, strictly after; 45 months in Their Finest Hour. The NAP is ended **silently** — no message, no relation, no threat. `+0x1C end_date` is not read, and `+0x20` is `cancel`.

**The force balance.** `CNap_UpdateForceBalance`, `0xA47370` (rva `0x647370`). It walks the **first** party's areas → fronts (`COwnerArea +0x74`) → front provinces.
- For each edge of a front province that is not impassable (kind ≠ 3) and whose neighbour is controlled by the second party, it adds `1000 ×` the regiment count of the second's land units in that neighbour (theirs).
- If a front province has any such edge, it adds the first's land regiments in that province (ours).
- Then `our_power (+0x2C) = ours/1000` and `their_power (+0x28) = theirs/1000`. `balance (+0x24) = ours×1000/theirs`, or **1,000,000 when theirs is 0**.
- It runs from `CNap::Activate` in a running game. It also runs from `0x4E39C0` — which RunDailyPass calls for every country before its daily pass, `0x682E0F` — for NAPs whose `first` is that country, but only when `Date_DayOfYear % 7 == 0`, or the balance is negative (a new pact's −1000), or the game is not yet in play.

**The alert.** `NAP_EXPIRY_ALERT_MONTHS_AHEAD` (`+0xF8`) is read by the alert manager (`0x60207E`), paired with **`NAP_UNBREAKABLE_MONTHS`** (`+0xE4`), not with expiry. The NAP is listed once `start + (6−3)` months has passed.

### C.6 Embargo — `CEmbargoAction::Apply`, `0xA2E5F0`

No arm tests `type`.
- **Imposing** (value set):
  - `new(0x24)` CEmbargo; Activate (`+0x34` both ways; `changed` set on neither); append;
  - `ChangeRelation(EMBARGO_RELATION_CHANGE)`: −30 in Their Finest Hour, −200 (the floor) in BlackICE;
  - `−EMBARGO_INFLUENCE_COST` (1);
  - `SpreadThreat(recipient, &EMBARGO_THREAT_COST, +1000, recipient's acting capital)`;
  - messages;
  - **every trade route of the pair is cancelled**: each route's slot 11, unlink, delete.
- **Lifting**:
  - SpreadThreat with scale −1000, so the threat is taken back;
  - then, only if the embargo exists: slot 11, `CDiplomacy_RemoveRelation`, delete;
  - no relation change, no refund.

What an embargo stops while it stands:
- CTradeAction slot 14 answers false on `+0x34` (`0xA38A77`), so a trade offer between the two cannot be selected;
- CTradeAction slot 12 shows `CDIP_EMBARGO`, "Embargoed by $LIST$".

The `+0x34` sweep finds no other reader beyond the status lines. It never expires (its slot 6 is ReturnFalse).

### C.7 Influence and align

**`CInfluenceNation::Apply`**, `0xA1E420`. No `type` test.
- **value == 0**: `CCountry_StopInfluence`.
- **value set**:
  - if any member of the actor's faction already influences the recipient, it does nothing at all;
  - otherwise `new(0x40)` CInfluence, then Activate. Activate:
    - sets `recipient->diplomacy[actor]->+0x2C = this` and `recipient +0x1144 = 1`;
    - copies the influencer's faction name into `+0x24`;
    - puts `align_towards_<faction>` on the **recipient** for `DAYS_OF_INFLUENCE_RELATION_CHANGE / 1000` days;
  - then append;
  - then **`−INFLUENCE_INFLUENCE_COST` (`+0x30`, 3)** at `0xA1E68D`, through the inlined `GetDefines` (singleton `[0x1A86040]`) — the record said it was not read.

**`CInfluenceAllianceLeader::Apply`** (align), `0xA20F70`.
- It looks up `align_towards_<recipient's faction>`.
- **value == 0**: only if the actor has that modifier active, `CCountry_StopAlign`.
- **value set**: if the modifier is already active, nothing. Otherwise:
  - `new(0x40)` CAlign; Activate puts it on `actor->diplomacy[leader]->+0x30` and adds the modifier to the **aligner itself**, using the INFLUENCE duration define;
  - append;
  - `−ALIGN_INFLUENCE_COST` (1).

**Neither changes relation.** Their only effect is the static modifier, which the alignment step's Influence term reads (`FINDINGS-alignment.md` 1.6).

**The save confirms it, 4 of 4** (`Germany1936_04_20_03`):
- the `align` blocks SWE→GER and SCH→GER put `align_towards_axis` on SWE and SCH;
- TUR→SOV puts `align_towards_comintern` on TUR;
- the `influence` block ENG→CAN puts `align_towards_allies` on CAN.

**The passes, in RunCountryDailyPass order:**
1. `CDiplomacyStatus_ExpireRelations` (`0x4DAF35`):
   - an influence ends when `CInfluence::IsOver` says so — the influencer's faction is the influenced country's, or the influenced country is in any real faction or is a subject, or either owns no province, or the duration has run;
   - an align ends on `CAlign::IsOver`;
   - each is unlinked, deactivated (the modifier removed) and deleted;
   - an align sends DIPLOEXPIRE / DIPLOEXPIRE_ALIGN to a playing aligner; an influence sends nothing.
2. `CCountry::PayDailyInfluenceUpkeep` (`0x4DB671`): `INFLUENCE_UPKEEP` (1) a day per running influence. When it cannot be paid, influence is clamped to 0 and StopInfluence runs. **An align has no upkeep.**

**War.** `SetPairWar` ends an influence between belligerents.

### C.8 The relation list's own life

**`CDiplomacyStatus_ExpireRelations`.**
- **Its one caller** is RunCountryDailyPass, on `country->diplomacy[o]` for every o that owns a province. RunDailyPass runs that pass only for countries with `+0x44` set.
- **Order**:
  1. casus belli list — removed from the status list and `+0xB2C`, deleted, **no slot 11, so no WELOSECB**;
  2. influence;
  3. align;
  4. guarantee — only from the side where `guarantee.first == status target`, i.e. the guaranteed country's pass;
  5. NAP;
  6. alliance — `CDiplomacy_RemoveRelation`, slot 11, delete, then the **leave-alliance keys** MILALLWEBAN / MILALLBAN / MILALLBANOTHER, naming the status owner as ACTOR.
- **Not checked**: dependency, embargo, trade.

**The slot 6 bodies:**

| relation | when it is over |
|---|---|
| CAlliance | no dependency between the two, and both in one real faction |
| CNap | `tick > start + NAP_EXPIRY_MONTHS` |
| CGuarantee, CWarning (one body) | `tick > start + 175200 h` — twenty years |
| CCasusBelli | the end date is real and `tick > end_date` |
| CInfluence, CAlign | as recorded |
| CEmbargo, CDependency, CVassal, CTradeRoute | never (ReturnFalse) |

`end_date` is read live only by CCasusBelli. The history files' end dates act only during the replay before play (`FINDINGS-history.md` §3).

**`SetPairWar`** (rva `0x648790`). Called from `CWar::AddDefender` with the war, and from `CWar::RemoveDefender` with 0. It writes `+0x20` and always ends the pair's influence (`+0x2C`) and every trade route (`+0x60`).

**The save, key by key.** `CDiplomacy::SaveContents` writes `GetToken` and the block for every relation in the list **except those with `cancel` set**.
- **CRelation::SaveContents** (inherited by alliance, guarantee, embargo, align, influence, vassal, warning): `first`, `second`, `end_date` only when real, then `start_date` — or `cancel=yes` *instead of* `start_date`.
- **CNap**: `balance` (fixed point), `our_power` and `their_power` (`%d`), then the CRelation keys.
- **Not saved**: CInfluence and CAlign's faction name, and CGuarantee's `+0x24`.

**The load.** `CDiplomacy::LoadKey` reads 11 keys. `align` and `embargo` sit outside the switch. Each relation is built, loaded, appended and then **Activated**, which re-hangs it on the statuses and re-derives the faction name; CNap's measurement does not run, because `in_game` is still clear. An unknown key is logged ("Unknown tag in diplomacy field in savegame").

**The saves agree.** The diplomacy blocks hold:
- `guarantee`, `alliance` and `vassal` with `end_date` — from history;
- `align`, `influence` and `trade` without it.

### C.9 Military access in the month's drift

`MonthlyRelationDrift` (`0x4E79B1`) adds **25 thousandths when `country->diplomacy[other]->hasMilitaryAccess` is set** — that country holds access into the other's land. A pair is visited from both sides and each visit adds `trunc(d×1000/2000)`. So one-way access moves the pair **0.012 a month** and two-way access 0.024. `FINDINGS-diplostate.md` C.2's "12 + 12 = 24" holds only for two-way access.

### C.10 What looks wrong but is what the bytes do

- Guarantee, embargo, influence and align test no `type`: they take effect when offered and are never answered.
- Leaving an alliance costs −50 and then a hard-coded −30. Declining costs nothing.
- Revoking a guarantee *adds* `REVOKE_GUARANTEE_INFLUENCE_COST`. Declining access refunds the asker.
- `MILACC_CANCEL_RELATION_CHANGE` is dead. COffer uses constants (+10, −20), and its withdrawal clears access **in both directions**.
- The leave, revoke and break arms take the pointer with no null test (the gate is slot 13's).
- `CGuaranteeAction` has a faction-wide branch behind `CCountry +0xDE4`, which nothing ever sets. *Corrected 2026-10-13: it is the ALLIANCE_GUARANTEE rule, set for every Allies member by `CCountry::RebuildRules` (`FINDINGS-factionplay.md` B.3); the branch is live.*
- A guarantee lasts exactly twenty years from its start, whatever `end_date` says.
- An alliance that both partners outgrow by joining one faction is dissolved with the "left the alliance" messages.
- CDeclareWarAction nulls the guarantee between belligerents **without unlinking it**. It stays in the list, is saved, and `CDiplomacy::LoadKey` re-activates it on load. Inferred from reading the bytes; no save has such a pair.
- The NAP alert counts from `NAP_UNBREAKABLE_MONTHS`, not from expiry, and stays on for good once due.
- The NAP balance counts brigades, a neighbour once per edge into it and a province once per front it is on, and is refreshed only on day-of-year multiples of 7.
- An expiring casus belli raises no WELOSECB on this path.
- `CRelation::SaveContents` would drop `start_date` for a cancelled relation, but nothing ever saves one.

### C.11 What I could not settle

- Whether `CWar::AddAttacker` writes `+0x20` by some other route.
- Who writes `CRelation +0x20 cancel` during play.
- What reads `CCountry +0x1144`. A disp32 scan finds none.
- Whether `CInfluence::Activate` re-adding its timed modifier at load duplicates the one in the country's own save block. `CAlign` tests for that; `CInfluence` does not; AddTimedModifier was not read.
- What `0x4E39C0` does beyond the NAP measurement.
- The CDeclareWarAction call-to-arms gates: the later piece.

### C.12 Frontier (rvas)

`0xE39C0`, `0xE9220` (the capitulation), `0xF5F30` (faction mutation), `0x647A00` and `0x647D20` (CCasusBelli slots 2 and 11).

## D. The ruler's title in a message (`MONARCHTITLE`)

Read 2026-10-13 by the collecting session, for the pacts' messages: every one of them carries the
player's standard variables, and one of those is `MONARCHTITLE`. All `confirmed`, off the
disassembly.

**Where it is set.** `CCountry::BuildMessageVariables` pushes the name `MONARCHTITLE` (`0x4D7786`)
and fills it from `CCountry_GetRulerTitle` (`0x4FFCE0`, rva `0xFFCE0`, called at `0x4D77AC`). That
helper is nine instructions: the country in EAX, the out string in ESI, its `Government`
(`CCountry +0xDFC`, never null as made) asked through **vftable slot 15** with both flags off. It has
16 direct callers, among them the NAP's and the embargo's message arms.

**What slot 15 answers.** `CGovernment::GetRulerTitle` (`0x5243F0`, rva `0x1243F0`, slot 15 of
`CGovernment` and inherited by `CNullGovernment`) takes `out`, `female` and `vassal`:

1. the key is the government's name + `_ruler`, and + `_female` when `female` is set;
2. `CGovernment::GetVassalText` (`0x523F70`, rva `0x123F70`) is asked with that key and `vassal`.
   Without `vassal` it answers the key unchanged; with it, the localised `<key>_vassal` where the
   localisation has that key, and the key unchanged where it does not;
3. if that answer is not the key, it is the title. Otherwise the title is the key's localisation,
   `GetText(key)` rendered.

So the title is the localised `<government>_ruler[_female][_vassal]`, where the vassal form is taken
only if it exists. **A message asks with both flags off**, so `MONARCHTITLE` is always the plain
`<government>_ruler` text: the base game's `national_socialism_ruler` is "Führer", and a puppet's
message uses the same title as anyone else's.

**What is not settled.** Who passes `female` or `vassal` as set: `GetVassalText`'s other caller is
`CGovernment` slot 13, which was not read.

**The rest of a pact message's variables.** After the standard list, `MONARCHTITLE` again (the
NAP's arm at `0xA2B168`), then `ACTOR`, `RECIPIENT` and `MESSENGER` - whose value is the key
`MESSAGE_HEAD_CHAN`, "The Foreign Office reports", pushed just before it (`0xA2B791`, `0xA2B7BD`).
`CCountry::BuildMessageVariables` itself sets `COUNTRY`, `MONARCHTITLE` (`0x4D7786`), `TITLE`
(`0x4D78EB`, the same title from a second call to `CCountry_GetRulerTitle`) and then each post
through `0x4D7AE0` (`MINISTER_MESSAGE_ENTRY`, `TITLE`, `NAME`).

## E. Who is told which key

Read 2026-10-13 by the collecting session, `confirmed`. Every pact arm tests the player twice -
`cmp [this+0xC], played_country_id` (the actor) and then `cmp [this+0x14], ...` (the recipient) -
and the key loaded after each test is the one that country is told; the key after both is
everybody else's. **The keys' names do not say which is which**, and `FINDINGS-diploaction.md`
section 17 lists them in an order that is not always actor-first. In actor / recipient / other
order:

| arm | actor played | recipient played | anybody else | tests at |
| --- | --- | --- | --- | --- |
| alliance accepted | `MILALLACCEPT` | `MILALLWEACCEPT` | `MILLALLINVACCEPTOTHER` | `0xA196AE`, `0xA19844` |
| alliance declined | `MILALLREJECT` | `MILALLWEREJECT` | `MILLALLJOINREJECTOTHER` | `0xA19FED`, `0xA1A17E` |
| alliance dissolved | `MILALLWEBAN` | `MILALLBAN` | `MILALLBANOTHER` | `0xA19C41`, `0xA19D1C` |
| NAP accepted | `WENAP` | `THEYNAP` | `OTHERNAP` | `0xA2BB83`, `0xA2BD19` |
| **NAP declined** | **`THEYREJECTNAP`** | **`WEREJECTNAP`** | `OTHERREJECTNAP` | `0xA2C4B6`, `0xA2C64D` |
| NAP cancelled | `WECANCELNAP` | `THEYCANCELNAP` | `OTHERCANCELNAP` | `0xA2C0F7`, `0xA2C1D6` |
| guarantee given | `WEGUARAT` | `GUARATOUS` | `GUARATOOTHER` | `0xA1C6FC`, `0xA1C847` |
| **guarantee revoked** | `GUARACANCELTOTHEM` | `GUARACANCELTOUS` | **`GUARACANCELTOTHEM`** | `0xA1D051`, `0xA1D13A` |
| access granted | `ACCMILUS` | `WEACCMIL` | `ACCMILOTHER` | `0xA23A6F`, `0xA23BFD` |
| access declined | `DECMILUS` | `WEDECMIL` | `DECMILOTHER` | `0xA23F47`, `0xA240E1` |
| **access cancelled** | **`WECANMIL`** | **`CANCMILUS`** | `CANMILOTHE` | `0xA2433F`, `0xA244CD` |
| offered access accepted | `OFFACCMILUS` | `WEOFFACCMIL` | `OFFACCMILOTHER` | `0xA2623C` (the recipient's) |
| offered access declined | `OFFDECMILUS` | `WEDECOFFMIL` | `DECOFFMILOTHER` | `0xA264A0`, `0xA2663A` |
| **offered access withdrawn** | **`WECANMIL`** | **`CANCMILUS`** | `CANMILOTHE` | `0xA2695E`, `0xA26A30` |
| embargo imposed | `WEEMBARGO` | `THEYEMBARGO` | `OTHEREMBARGO` | `0xA2F11E`, `0xA2F1F4` |
| embargo lifted | `WECANCELEMBARGO` | `THEYCANCELEMBARGO` | `OTHERCANCELEMBARGO` | `0xA2F6CF`, `0xA2F7A3` |
| influence started | `WEINFLUENCE` | `THEYINFLUENCE` | `OTHERINFLUENCE` | `0xA1F361`, `0xA1F5D9` |
| align started | `WEALIGN` | `THEYALIGN` | `OTHERALIGN` | `0xA21BBA`, `0xA21CA3` |
| influence stopped | `WEINFLUENCESTOP` | `THEYINFLUENCESTOP` | `OTHERINFLUENCESTOP` | `0x504A55`, `0x504B07`, on the countries' ids `+0xCA8` |
| align stopped | `WEALIGNSTOP` | `THEYALIGNSTOP` | `OTHERALIGNSTOP` | `0x505A30`, `0x505B07` |

The bold rows are the ones where the obvious reading of the names is wrong. The texts agree with the
bytes: `THEYREJECTNAP_LOG` is "$RECIPIENT$ rejected our offer of a non-aggression pact", so it is the
proposer's; `WECANMIL` is the canceller's. **A revoked guarantee is told to everybody**, the third
case reusing the first key; the record listed two keys until this reading. The offered-access
accept's actor test falls before the stretch read; the order of its other two places it.
