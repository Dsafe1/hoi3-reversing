# Trade and aid: routes and their price, the AI's trading, debt, licences, lend-lease, shared technology

Read 2026-10-13 by the trade and aid wave (`WAVE.md`), for the second half of OpenHOI3's agreements;
the first half is `FINDINGS-agreements.md`. Three briefs: **A**, trade - the route, its price, the
offer window, the day's exchange, the convoy, how a route ends; **B**, the Lua the trade and aid
scripts reach and how a script posts an offer; **C**, aid - debt, licences, lend-lease and shared
technology. Addresses are virtual (based `0x400000`), with the rva beside anything named. Figures
are thousandths unless a section says otherwise.

## In one line

- **A trade route** is a relation with two seven-good blocks, `trade_from` (what the proposer hands
  over each day) and `trade_to`; one holds goods and the other their price in money,
  `goods_cost x amount x (1 - 1/2 x (relation + 200)/400)`, fixed when the amounts are set - which
  reproduces both money entries of all 582 routes in four of the maintainer's saves (A.3). It is
  exchanged in the proposer's daily pass, scaled by its convoy's efficiency; it never expires.
- **The AI trades through the install's Lua**: each hour one draw in six runs `ProposeTrades`, and
  failing that one in ten `EvalutateExistingTrades`; a script's offer takes the screen's command path
  (B.1, B.2).
- **Debt** grows only for a country at war that is allowed it, and is repaid a fifty-year share a
  peaceful day - for ever, since nothing reduces it (C.1). **A licence** is the buyer building the
  seller's model in its own queue for a fee (C.2). **Lend-lease** is IC, given by a share of the
  giver's and received as whole IC the next day, its effectiveness that of a convoy that carries
  nothing (C.3). **Shared technology** lends a theory's level (C.4).

**Corrected in the record** by this wave: `CTradeRoute +0x34`/`+0x44` were swapped (A.2);
`TradeRouteValueOneGood` is `CTradeRoute::GetCost`; `FindMatchingTradeRoute` returns the route;
`CTradeAction::SetTrading`'s negative value sets the actor's side (B.2); `RunHourlyAITrade` draws
twice (B.1); `CDiplomacyStatus +0x70 debt` is what the owner owes, not is owed (C.1); `repaid_away`
and `income_from_debt` are written (C.1); `RunCountryDailyPass` runs on past what was taken for its
unwind (C); and `CCountry +0xDEC` is the faction rule `free_resource_gifts` (A.11).

## A. Trade (brief A)

*Read 2026-10-13 by the trade and aid wave's brief A, out of the executable. Addresses are virtual (based 0x400000), with the rva beside anything named. Checked against four of the maintainer's saves (`Germany1936_04_20_03`, `autosave`, `Germany1936_01_08_07`, `olderautosave`) and Their Finest Hour's `common/defines.lua`. All quantities are thousandths unless said otherwise. Goods are in pool order: supplies, fuel, money, crude oil, metal, energy, rare materials.*

### A.1 In one line

- **A trade route is a `CRelation`** with two seven-good blocks:
  - `trade_from` (+0x44) is what the proposer (`from`) hands over each day;
  - `trade_to` (+0x34) is what the recipient (`to`) hands over;
  - one block holds goods and the other holds money, the money being the price of those goods.
- **The price is set once**, when the amounts are set, as goods_cost x amount x (1 - 1/2 x (relation + 200)/400).
- **Accepting does three things:** it hangs the route on both countries, gives +15 relation, and, where the two need a convoy, makes one owned by the buyer, running from the buyer's harbour to the seller's.
- **Each day, in the `from` country's pass,** the goods and money change stockpiles, scaled by the convoy's efficiency. A route that cannot run that day is made inactive with a reason.
- **A route never expires.** It ends by a cancellation by either side; war between the two; an embargo; or losing a convoy it needs, which destroys it silently.

### A.2 What a route holds

`CTradeRoute` (vftable 0x15FBD48, 0x88 bytes, base `CRelation`). `CTradeAction` (0xB0) embeds one at +0x28.

| offset | field | what it is |
| --- | --- | --- |
| +0x8/+0xC | first | = `from` = the action's actor (CTradeRoute::SetFirst, rva 0x64D500, writes both; CTradeAction::SetActor, rva 0x638FD0, calls it) |
| +0x10/+0x14 | second | = `to` = the action's recipient (SetSecond, rva 0x64D520; SetRecipient, rva 0x638FA0) |
| +0x18 | start_date | the action's date, stamped on accept |
| +0x24/+0x28 | from | |
| +0x2C/+0x30 | to | |
| +0x34 | **trade_to** | vector of 7, what `to` gives each day; save key `trade_to` |
| +0x44 | **trade_from** | vector of 7, what `from` gives each day; save key `trade_from` |
| +0x54 | inactive | daily state, not saved |
| +0x58/+0x5C | convoy_responsible | written when the route goes inactive |
| +0x60 | inactive_reason | rendered text, not saved |
| +0x7C/+0x80 | convoy | CPersistent id pair; null for an overland route |
| +0x84 | last_inactive | sticky stamp (FINDINGS-trade2.md section 6) |

**The direction is settled by the save keys and by the flow.**
- `CTradeRoute::SaveContents` (0xA4CD60, rva 0x64CD60) writes `trade_from` (token 0x6DC) from +0x44 and `trade_to` (0x6DD) from +0x34. LoadKey reads them back to the same places.
- RunDailyTradeRoutes takes +0x44 out of `from`'s stockpile and +0x34 out of `to`'s.
- In the save, `trade={ to="FIN" from="SWE" trade_from={ ... metal 0.400 ... } trade_to={ ... money 0.026 ... } }` means Sweden sells 0.4 metal a day to Finland for 0.026 money.
- **In all 582 saved routes, goods sit in one block and money in the other.**

`CTradeAction::SetTrading` (rva 0x638DF0, brief B's revision agrees):
- `SetTrading(v > 0, g)` puts v into `trade_to`: **the actor buys**.
- `SetTrading(v < 0, g)` puts |v| into `trade_from`: **the actor sells**.
- `0` clears the good both ways.
- TradeRouteSetOneGood (rva 0x64C880) zeroes the same good in the other block whenever it writes a positive value, so one good never flows both ways.

**Money is not a good**, at least while either party lacks the rule. TradeRouteSetTradedOf (rva 0x64CA90) zeroes both money entries and recomputes them on every call:

    trade_to[money]   = sum over g of GetCost(g, trade_from[g], from, to)    ; to pays for what it receives
    trade_from[money] = sum over g of GetCost(g, trade_to[g],   from, to)

**This only happens where `chargeMoney`**, i.e. unless both countries have the free_resource_gifts rule (A.11).

### A.3 The price - `CTradeRoute::GetCost` (0xA4C9A0, rva 0x64C9A0)

Static, registered to Lua as `CTradeRoute:GetCost(GoodsCategory, CFixedPoint, CCountryTag, CCountryTag)`.

    range = |[0x1710CD0]| + |[0x1710CD4]|                  = 400000   (the +-200.000 relation scale)
    rel   = 200000 + countries[b]->diplomacy[a]->relation (+0x38)      0..400000
    f     = rel * 1000 / range                                          0..1000, 500 at relation 0
    d     = f * 500 / 1000                                              the 500 is (int)floor(500.5f), a CRT static at 0x1B15F48
    price = (goods_cost[g] * amount / 1000) * (1000 - d) / 1000         every division truncates

- **A good costs its full `goods_cost` at relation -200, three quarters at 0, and half at +200.**
- Nothing else enters: not stockpiles, distance, convoys, or who asks.
- Their Finest Hour's goods_cost: supplies 0.25, fuel 0.75, money 0, crude oil 0.75, metal 0.1, energy 0.05, rare materials 0.2.
- The 1/2 is not a define.

*Measured against the saves.* With these numbers, both money entries of every route are reproduced exactly for some whole relation: 239 of 239 routes in `Germany1936_04_20_03`; 115 of 115 in `autosave`; 42 of 42 in `Germany1936_01_08_07`; 186 of 186 in `olderautosave`. Where a pair has had nothing else happen, the fitted relation is 0 and the saved relation is 15, which is exactly `TRADE_RELATION_CHANGES` added at acceptance: SAF-FRA, IRE-ENG, HUN-GER, CHI-ENG, BUL-GER, SIA-FRA and HUN-SOV.

**The price is frozen.** Only SetTrading prices a route (its callers are the trade dialog at 0x77445F and Lua). Nothing reprices it afterwards, so the price is the one in force at the last slider move or `SetTrading` before the offer. The +15 on acceptance and every later drift leave it alone.

### A.4 The offer window - `TradeDiplomacyDialog` / `CTradeDiplomacyDialog`

`DiplomacyView_OpenActionDialog` opens it for a `trade_action` row. The constructor is 0x773220 (rva 0x373220): host in ECX, then the object, the row's action and the view on the stack, `ret 0xC`.

| element (diplomacydialog.gui) | what it does |
| --- | --- |
| `LeftShield` / `RightShield` | the actor's / the recipient's flag |
| `Title` | the action's slot 10, "Offer Trade Agreement" |
| `supplies_slider`, `fuel_slider`, `crude_slider`, `metal_slider`, `energy_slider`, `rare_met_slider` | one per good, no money slider. File: 0..1, step 0.001, start 0.5; the left button is labelled SELL, the right BUY |
| `value_<good>` (`value_rare_met` for rare) | TRADE_DAY "$VAL$/Day", VAL to 2 decimals |
| `reset_<good>` | sets that slider back to its start value: nothing traded |
| `Description` | slot 12 (A.5) |
| `chance_string` | the AI's chance word (DiplomaticAction_BuildChanceText); shown because a trade offer's slot 18 is true |
| `debt_desc` | IS_BOUGHT_WITH_DEBT "Debt is used for this deal.", **hidden unless `actor->diplomacy[recipient]->allowDebts` and the actor is at war** |
| `AgreeButton` / `DeclineButton` | relabelled ACCEPT / DECLINE (the file's PW_I_DO / PW_RUN_AWAY are overwritten) |

**Each frame** (slot 7, `StaysOpen`, 0x773E30):
- Each slider gives `s = (int)floor((pos + 0.0005) x 1000)`, 0..1000. TradeDialog_ReadSlider (0x773A90) turns it into an amount a day around a centre of 500:
  - `s < 500` -> `-MAX_DAILY_TRADE x (500 - s)/1000`, a sale;
  - otherwise `+MAX_DAILY_TRADE x (s - 500)/1000`, a purchase.
  - MAX_DAILY_TRADE is economy +0x38 = 100, so **+-50.000 a day at the ends, 0.100 a step**.
  - This is the define's reader that FINDINGS-convoys.md could not find. It caps the dialog only.
- Where any slider changed (the stored amounts start at -1000 as a sentinel, so the first frame always counts):
  - SetTrading is called for every good but money;
  - money in the dialog's own vector is set to minus what the actor pays, or what it receives (never displayed);
  - Description and chance are refreshed.
- **AgreeButton is enabled iff `CTradeRoute::IsValid` and `CTradeAction::IsConvoyPossible`.**
- Its tooltip (slot 3):
  - route valid and convoy possible: slot 11 (A.5);
  - route valid, convoy impossible: TR_CANT_CONVOY "$ACTOR$ cannot trace a convoyroute to collect his goods", ACTOR = the buyer;
  - route invalid: for a barter, NO_TRADE_RULE "Only if both parties have the $RULE$ rule could we trade resources for resources." (RULE = "Free resources gifts"); **for a trade with no price, an empty tooltip**.
- The dialog stays open while the view is shown and the action's slot 13 holds, unless another dialog occupies view +0x518. On closing it rebuilds the action list.

**Accept** is the shared `DiplomacyDialog_OnAgree` (0x773090): it stamps the date, posts MakeCommand, rebuilds and closes.

`CTradeRoute::IsValid` (0xA4CEE0, rva 0x64CEE0) answers true at once when both countries have the free_resource_gifts rule. Otherwise:
1. False where some good of `trade_from` and some good of `trade_to` each exceed one thousandth: **no barter**.
2. False where neither block's money reaches one thousandth: **a price is required**.
3. False where the route has a convoy whose start or end is controlled by neither of the two.

### A.5 CTradeAction's slots 11, 12, 13, 14, 18

- **Slot 13 (IsValid, rva 0x638770)** and **slot 14 (IsSelectable, rva 0x638920)** are already in the record (FINDINGS-trade2.md section 4, FINDINGS-agreements.md B.8). Re-read here; they agree.
  - Offering needs: no war; puppet rules; influence >= TRADE_INFLUENCE_COST; a port each where trade needs a convoy; and no embargo of theirs on us.
  - Cancelling: slot 14 is always true; slot 13 needs a matching route.
- **Slot 11 (GetDescription, rva 0x637F00)**: ACT_NO_SELF; ENROUTE; WEWAR; SUBJECT; then:
  - offering: DIP_NO_INFL with TRADE_INFLUENCE_COST (+0xA0, 0 decimals);
  - cancelling: DIP_NO_INFL with TRADE_CANCEL_INFLUENCE_COST (+0xA4), then CANCELTRADEDESC "Cancel our Trade Agreement.";
  - offering, after that: CDIP_EMBARGO "Embargoed by $LIST$"; TRADENO_PORTS "You cannot initiate overseas trading without both partners having a port to ship it through."; else TRADEDESC "This will allow us to negotiate to either sell or buy resources."
- **Slot 12 (GetDialogText, 0xA37520, rva 0x637520)**:
  - Offering: TRADENEWDESCTWO "We offer §Y$COUNTRY$§W to §Y$TYPE$§W $SELL$ per day for $BUY$ per day.", COUNTRY = the recipient. The texts come from FormatTradeGoods (0xA34CA0, rva 0x634CA0): "§Y0.40 Metal§W " items, joined by ", " and "and ", or TRADE_NOTHING "Nothing".
    - Actor pays no money: SELL = what the actor gives, BUY = what it gets, TYPE = TRADE_BUY "Buy".
    - Actor pays: BUY = what the actor gives (with its money), SELL = what it gets, TYPE = TRADE_TRADE "Trade" if the recipient pays money too, else TRADE_SELL "Sell".
    - TYPE describes the recipient's side.
  - Cancelling: CANCELTRADENEWDESC "Do you wish to cancel our agreement with $COUNTRY$?\nThis will stop the transfer of $SELL$ for $BUY$." COUNTRY is the recipient's name passed through `sprintf` as a format and then GetText. SELL and BUY are never filled. Then DIP_INFLUENCECOST with TRADE_CANCEL_INFLUENCE_COST, 2 decimals. No screen found opens this arm.
- **Slot 18** is a body shared by four classes (0xA0FE10, rva 0x60FE10): `value != 0`. The same body sits in CAllianceAction, CNapAction and CRequestLendLeaseAction. **An offer is answered; a cancellation is not**, so a cancellation takes effect when it is proposed.
- **Slot 21** is `value`, so a cancel row is never greyed by the diplomat en-route cooldown (agreements B.3).

The offer as the player receives it (CAskTrade, rva 0x215FA0): TRADEREQDESC "$COUNTRY$ is offering us a Trade Agreement. \n We would give them $TO$ each day in exchange for $FROM$ each day." FROM = their `trade_from`, TO = our `trade_to`. Plus CONV_AT_TRADE "$CONV$ would be responsible for the convoy needed for this trade." where a convoy is needed, CONV = the buyer. Plus IS_BOUGHT_WITH_DEBT where the proposer has debt allowed and is at war.

### A.6 What happens on each arm - `CTradeAction::Apply` (0xA352F0, rva 0x6352F0)

Their Finest Hour's defines (diplomacy block): TRADE_RELATION_CHANGES 15.0 (+0x9C), TRADE_INFLUENCE_COST 3.0 (+0xA0), TRADE_CANCEL_INFLUENCE_COST 1.0 (+0xA4), TRADE_CANCEL_RELATION_COST 15.0 (+0xA8). BlackICE uses 10 / 1 / 0 / 10.

- **PROPOSE with value set**: influence -3, clamped at 0. Charged whatever the answer.
- **ACCEPT**:
  1. `CTradeRoute::IsValid` must hold, or nothing happens.
  2. A copy of the route is created, start_date is set, and it is Activated on both statuses.
  3. Where a convoy is needed, one is made (A.7). **If it cannot be made, the route stands anyway.**
  4. The route is appended to the relation list.
  5. Relation +15.
  6. Messages (table below).
  7. RebuildNeighbours and 0x4E39C0 on both countries.
- **DECLINE**: messages only. No relation change, no refund.
- **value == 0, any type (a cancellation)**:
  1. FindMatchingTradeRoute (0xA4A750, rva 0x64A750) returns the route matching first, second and both blocks exactly. **It is used with no null test**; Execute's slot 13 is what guarantees a match.
  2. Deactivate, unlink, delete.
  3. Relation -15.
  4. **No influence is charged.**
  5. Messages; RebuildNeighbours on both; the in-game screen refreshes if the player is involved.

Who is told which key (actor / recipient / anyone else; the texts confirm the order):

| arm | actor played | recipient played | anyone else |
| --- | --- | --- | --- |
| accepted | ACTRAWITHUS "We now have a Trade Agreement with $RECIPIENT$." | WETRADEAG "We have accepted the Trade Agreement with $ACTOR$." | OTHERTRADEAG |
| declined | DETRAWITHUS "$RECIPIENT$ declined our Trade Agreement proposal." | WEDETRA | DETRAWITHOTHER |
| cancelled | WEBRKTRADE "We have broken the Trade Agreement we had with $RECIPIENT$." | BRKTRADEUS "$ACTOR$ has broken the Trade Agreement they had with us." | BRKTRADEOTH |

- **The two accepted messages for a played country are suppressed while the local player has delegated foreign policy or set automate_trade.**
- The two declined messages are suppressed by automate_trade only.
- The cancelled messages and every "anyone else" message are never suppressed.
- The accept arm also fills message variables ACT_TRADE / REC_TRADE (what the player's side gives / gets). ~~No shipped text uses them.~~ *Corrected 2026-10-13 (`FINDINGS-tradeui.md` A.6): `ACTRAWITHUS_6`, `WETRADEAG_4` and `BRKTRADEUS_6` use them, the cancel arm fills them for `BRKTRADEUS` too, and `ACTORS` is filled for every arm.*

### A.7 The route's convoy

**Whether one is needed** - `CCountry::NeedConvoyToTradeWith` (0x503C60, rva 0x103C60). It answers false (overland) where any of these holds: the two are land neighbours (`neighbours`, +0xF58); their acting capitals are on **the same continent** (province +0x368); the two capitals' areas are joined overland (AreaIsConnectedTo). It answers true where either capital has no area.

**Who runs it, and where.** S is the buyer: `to` where `trade_to` carries money, else `from` (CTradeRoute::GetConvoyResponsible). O is the other country.

    p    = COwnerArea::FirstPortId(GetCapitalLocation(S)->area)          ; S's largest home harbour (the real capital)
    to   = NearestPortTo(p,  GetActingCapitalLocation(O)->area, S)        ; O's harbour nearest it, straight line between port-seas
    from = NearestPortTo(to, GetActingCapitalLocation(S)->area, S)        ; then S's harbour nearest that

- Both ends must have an owner, a CPort and a naval base with `level_max` > 0. CTradeAction::IsConvoyPossible makes the same test the same way.
- Then `CCountry::CreateConvoy(S, from, to, supplies = no, ...)` makes the convoy. In play it starts with no transports (FINDINGS-supplyconvoys.md section 6).
- TradeRouteSetConvoy (rva 0x64D660) links the route to the convoy and sets `is_trade`.
- The `ship` mask is set for every good either block moves, money included.
- *Save:* SAF->FRA (13.900 energy for 0.521 money) is served by convoy 263, owned by France, Marseille -> Walvis Bay, mask money + energy, `daily` money 0.521 and energy 13.900. 73 of the save's 239 routes have a convoy.

**How many transports.** `CConvoy::GetDesiredTransports`: path length x CONVOY_PATH_LENGTH_MULT (0.33) x **CONVOY_TRADE_WEIGHT_MULT (0.2)**, scaled by the end harbour's maximum level, at least 1 (FINDINGS-convoys.md). In the save, trade convoys carry 1-6 transports and 2 of 73 carry none.

**How it is manned.** DistributeConvoyShips treats a trade convoy like a resource convoy (FINDINGS-supplyconvoys.md section 7): it is idled, giving back all its ships, where the **start area's** production of crude oil, metal, energy and rare materials is all nothing (0x4FD93D-0x4FD95F); it is ranked by GetImportance on its `daily`.

**With no convoy** where one is needed - never made, or removed later - the next RunDailyTradeRoutes destroys the route: no message, no relation change, and the +15 and the influence already spent are not returned.

The daily look at a country's convoys (RunCountryDailyPass, 0x4DABDF on) removes a trade convoy when no route of the pair refers to it any more; or either end is held by a country at war with the owner, or by rebels. A cancelled route's convoy has its `is_trade` cleared by CTradeRoute::Deactivate (rva 0x64D400). The same daily look then removes it the next day, because it carries money and is not trade.

### A.8 The day - `CCountry::RunDailyTradeRoutes` (0x4FEE70, rva 0xFEE70)

**Where it runs.** Inside RunCountryDailyPass (0x4DB43A), only for a country that owns provinces or is in exile. The country's day runs in this order: 1. the non-trade convoys deliver; 2. relations expire; 3. units draw; 4. SupplyLoss; 5. CollectDailyProduction; 6. **trade**; 7. UpdateIC; 8. ConvertCrudeOilToFuel; 9. influence upkeep; 10. the three convoy-maintenance routines.

**What it walks.** For every other country `o` and every route on `country->diplomacy[o]->trade_routes`:
1. **Convoy.**
   - None, and a convoy is needed: the route is queued for destruction at the end of the call.
   - A convoy with a path under two provinces, no transports, or an unusable route: the route is made inactive (TradeRouteSetInactive(1)). `convoy_responsible` is set to the buyer, and `inactive_reason` to TRADE_INACTIVE_CONVOY "§Y$COUNTRY$§W have not assigned enough convoys." with COUNTRY = the buyer.
   - These two steps run from both countries' passes.
2. **Only where `route.first == country`.** A and B are copies of the two stockpiles (the acting capital's pool, or the exile pool). eff = CConvoy::GetEfficiency, not clamped, or 1000 without a convoy. Then for g = 0..6:
   - give = trade_from[g] x eff/1000; get = trade_to[g] x eff/1000.
   - **Debt, money only.** If `from` is at war (with anybody) and `from->diplomacy[to]->allowDebts`, its payment goes onto that status's `debt` (+0x70) instead of out of A. The same applies to `to`. The seller still receives the money in full. A flag is set and stays set for the route's remaining goods.
   - A -= give, B -= get (unless paid on debt); A += get, B += give.
   - **A[g] < 0 with the flag clear**: TRADE_INACTIVE_NO_RES "§Y$COUNTRY$§W does not have enough §Y$RES$§Y." (COUNTRY = `from`, RES = the good); `convoy_responsible` = `from`; inactive; nothing written back. Then the same for B with `to`. **The test is on the stockpile after the day's exchange, money included**, so a buyer who cannot pay stops the route.
   - Unless the good is money paid on debt: TradedAway, TradedFor, TradedAwaySansAlliedSupply and TradedForSansAlliedSupply are credited on both countries, and the convoy's `daily[g]` = give + get.
   - After all seven goods: TradeRouteSetInactive(0), and A and B are written back to the stockpiles.

A route is therefore inactive on any day it cannot run and active again on the first day it can. `last_inactive` is sticky for 23 days (FINDINGS-trade2.md section 6). Nothing about inactivity is saved.

### A.9 How a route ends

| how | where | messages / relation |
| --- | --- | --- |
| cancelled by the player | production screen's trade list -> CTradeCancelConfirm (ctor rva 0x404A70; OnAgree rva 0x405160) posts a value-0 CTradeAction, actor = player | WEBRKTRADE / BRKTRADEUS / BRKTRADEOTH; -15 relation |
| cancelled by an AI | Lua -> CEU3AI::EvaluateCancelTrades (rva 0x49B810) -> PostTradeRouteCancel (rva 0x49BC80): **actor = the route's `from`, whoever asked** | the same |
| war between the two | SetPairWar (rva 0x648790): every route of the pair deactivated, unlinked, deleted | none |
| embargo | CEmbargoAction::Apply: every route of the pair, slot 11, unlink, delete (agreements C.6) | the embargo's own messages |
| convoy needed and missing | RunDailyTradeRoutes' end-of-call list | none |
| expiry | never: CTradeRoute's slot 6 is ReturnFalse, and ExpireRelations does not look at trade | - |
| inactivity | never ends a route | - |

`CEU3AI::EvaluateCancelTrades(amount, good)`: the engine's own cancellation logic, reached only through Lua. Over the game state's countries in order, then each pair's route list, it takes v = what we hand over of the good. Every route with 0 < v <= the remaining amount is cancelled, and v is subtracted. Then, if anything remains, the smallest route with v > the remaining amount is cancelled (first of equals), and the remainder becomes 0. It returns the remainder.

### A.10 The AI's side

- **Answering.** `CAIForeignMinister::AnswerPendingOffers` accepts at most one trade per call. Further trades that pass the roll are kept, still PROPOSE, for the next hour's roll. `CCountry::RetainPendingDiplomaticActions` (rva 0xE6410, re-read, the record stands) deletes everything else on the pending list and re-appends the kept actions, the same objects, not copies. RunCountryDailyPass drops pending actions older than 96 hours (agreements A2).
- **The player's automate_trade**: re-read in RunHourlyAITrade, the record stands. Rolls come from a private `rand()` reseeded to 1 each hour; a trade is declined where score <= roll; one acceptance per call; the rest are kept.
- **The Lua cadence** (brief B's revision): two separate draws on the game state's generator. Proposing about one hour in six, re-evaluating about one in twelve. Under automate_trade or delegation it runs for the player's own country too.

### A.11 The free_resource_gifts rule (CCountry +0xDEC)

`+0xDEC` is the fourth bool of the country's `Rules` (+0xDBC): CRule +0x18 + 3x8. CCountry::RebuildRules (rva 0xFBC10) clears it and then ORs in the rule of the country's faction where that faction is real, through CRule::Merge (0x45E340, rva 0x5E340). The base game gives the rule to the Comintern (`common/ideologies.txt`: `rule = { free_resource_gifts = yes }`).

**Between two countries that both have it:** CTradeRoute::IsValid is always true; SetTrading leaves money alone, at 0 in a new action; so they may trade goods for goods, or for nothing. FINDINGS-trade2.md's disp32 scan could not see the write: it is a disp8 through +0xDBC.

### A.12 What looks wrong but is what the bytes do

1. An AI cancellation is posted with actor = the route's `from`. If the cancelling AI is `to`, the messages and the -15 name the partner as the one who broke the deal.
2. TRADE_CANCEL_INFLUENCE_COST is shown in the tooltip and the dialog and never charged; a cancellation is never greyed for lack of it.
3. The price is fixed at the last SetTrading. Neither the +15 on acceptance nor any later relation change reprices it.
4. A route whose convoy cannot be made is still accepted, and is destroyed silently the next day. The influence and the +15 stay. The dialog's Agree checks IsConvoyPossible; an accept from CAskTrade or Lua does not.
5. The transfer happens only in `from`'s own daily pass. A `from` that owns no province and is not in exile never runs one.
6. "No resource" is tested after the exchange, on both stockpiles and on money; `from` is checked first.
7. The four Traded pools are credited good by good, so a route that fails on a later good has already recorded earlier goods that never moved.
8. Once a payment goes on debt, the "no resource" test is off for the rest of that route's goods that day. The stockpile can go below nothing and is clamped at the day's end, which creates goods. The seller still receives money the buyer owes, which creates money.
9. Debt applies only to a buyer at war with anybody, not necessarily with the partner.
10. Convoy efficiency is not clamped. An overmanned trade convoy would move more than agreed, and charge more. DistributeConvoyShips normally prevents this.
11. Two countries on one continent never need a convoy, whatever lies between them: Britain and France trade overland.
12. The convoy's reference harbour is the real capital's area, but the harbours are chosen in the acting capitals' areas.
13. A trade convoy is idled - and so the route made inactive - when its start area produces none of crude oil, metal, energy or rare materials (inferred from DistributeConvoyShips' common branch; see A.13).
14. The trade dialog keeps a money amount it never shows. The cancel-confirm dialog shows SELL = `trade_from` and BUY = `trade_to` whichever side the player is on, so it reads backwards for the route's `to`. Slot 12's cancel text never fills SELL/BUY and runs the country's name through `sprintf`.
15. TradeRouteSetOneGood computes the price of each change, and its only caller throws it away.
16. FormatTradeGoods counts positive values for its separators but lists every non-zero one.
17. The trade dialog shows the AI chance word, but its Agree button is the only thing tested each frame. Slot 13 alone decides whether the dialog stays open.

### A.13 What could not be settled

- **Whether a trade convoy really reaches DistributeConvoyShips' IDLE test.** Read from the shared resource/trade branch at 0x4FD924-0x4FD95F, not from a trace through a trade convoy. The 2 of 73 trade convoys with no transports in `Germany1936_04_20_03` are consistent with it but were not identified.
- **What happens to a route when either party ceases to exist (annexation).** No path that ends routes on annexation was found or looked for.
- **A free-trade (both-rule) route.** Its money stays 0 and its convoy mask has no money. When such a route is cancelled, the daily convoy look's money test does not remove the demoted convoy, and it was not followed further.
- **`OnResetButton` and `HasTooltip`.** The meaning of slider +0x388 (start value) and of the dialog's slot 2 are inferred from shape.
- **The production screen's trade list** (0x803C70, 0x803FD0) was read only for the inactive tooltip (TRADE_IS_INACTIVE plus the reason) and the PW_IMPORTING / PW_EXPORTING keys.
- **Brief C's ground:** `debt` (+0x70) repayment and `allowDebts` were not read.

### A.14 Frontier (rvas)

- `0x403C70`: production trade-list item, `sales_box` / `purchase_box` / `inactive_icon`; opens CTradeCancelConfirm.
- `0x403FD0`: that list's tooltip builder.
- `0x4050D0`: CTradeCancelConfirm slot 0.
- `0xE39C0`: called after every pact on both countries.
- `0x28A530`: makes a new convoy id.
- `0x10D0D0`: vector assignment used by the route copy.

## B. Lua: what the trade and aid scripts reach (brief B)

Read 2026-10-13. Addresses are virtual (based 0x400000), with the rva beside anything named. This builds on `FINDINGS-luaapi.md`, which read every method the eleven tag-only `DiploScore_*` functions reach. Three of this brief's functions are among those eleven: `DiploScore_Debt`, `DiploScore_OfferLendLease` and `DiploScore_RequestLendLease`, and all their methods were done there. What follows is what `tfh/script/ai_trade.lua` (`ProposeTrades`, `EvalutateExistingTrades`, `DiploScore_OfferTrade` and `Support_Trade.*`) and `tfh/script/ai_license.lua` (`DiploScore_LicenceTechnology`, `Support_License.ProductionCheck` and `CalculateCost`) add. It also covers the TFH country overrides those functions reach through `Utils.CallGetScoreAI` and `HasCountryAIFunction`: `AI_<TAG>.DiploScore_OfferTrade` in 19 files, and `TradeWeights` in GER, ITA and JAP.

The reach was found with the luaapi session's call-graph script (`scratchpad/luagraph.py`) over the TFH layer. Subtracting what the eleven reach leaves:
- **Methods.**
  - `CCountry`: AIGetTradeRoutes, GetCountryTag, GetGlobalModifier, GetTechnologyStatus, GetTradedAwaySansAlliedSupply, GetTradedForSansAlliedSupply, HasDiplomatEnroute.
  - `CAI`: AlreadyTradingDisabledResource, GetSpamPenalty, HasTradeGoneStale, PostAction.
  - `CDiplomaticAction`: GetAIAcceptance, IsSelectable, IsValid, SetValue.
  - `CTradeAction`: GetRoute, SetRoute, GetTrading, SetTrading.
  - `CTradeRoute`: GetFrom, GetTo, GetTradedFromOf, GetTradedToOf, IsInactive.
  - `CLicenceTechnologyAction`: Get/SetMoney, Get/SetSerial, GetParalell/SetParallel, Get/SetSubunit.
  - `CGoodsPool`: Get, GetFloat.
  - `CModifier`: GetValue.
  - `CTechnologyStatus`: GetIcModifier, IsUnitAvailable.
  - `CIdeologyGroup`: GetKey.
  - `CSubUnitDefinition`: GetBuildCostIC, GetBuildCostMP, GetBuildTime, IsCapitalShip.
  - `CCountryTag`: IsReal.
- **Statics:** `CCurrentGameState.GetCountries` and `CSubUnitDataBase.GetSubUnit`.
- **Constructors:** `CTradeAction(tag, tag)`, `CLicenceTechnologyAction(tag, tag)` and `CFixedPoint(number)`.
- **Constants:** `CGoodsPool._FUEL_` and the rest of the goods, and `CModifier._MODIFIER_GLOBAL_IC_` (17).
- **Fields:** `CGoodsValues`' seven floats.

Several of these names were already counted in `FINDINGS-luaapi.md`'s 76 because its fourteen roots included the two functions here, but their bodies were not read there.

### B1. Who calls what, and what it is handed

**`ProposeTrades(ai, tag)` and `EvalutateExistingTrades(ai, tag)`** come from `CCountry::RunHourlyAITrade` (rva `0xDC410`), once per country per hour on a TBB worker. After the player's automate-trade block (section A4), the Lua runs at `0x4DC6E5` only if all of these hold:
- `in_game` (state `+0xDA4`) is set;
- the country has a `CEU3AI` (`+0x1D8`);
- **if it is the local player's own country, his foreign policy is delegated or `automate_trade` (`GetLocalPlayer()+0x34`) is set**.

Then:

    if (MT19937Next(&state->+0x124) % 6 == 0)        ProposeTrades(ai, tag)            0x4DC7A9
    else if (MT19937Next(&state->+0x124) % 10 == 0)  EvalutateExistingTrades(ai, tag)  0x4DC7F8

These are **two separate draws** of the game state's generator, each taken as a signed int (`cdq; idiv`). So a country proposes in one hour of six and reviews its routes in one of twelve (5/6 x 1/10). The call goes through `BuildLuaCallProxy_AiAndTag` (rva `0x110280`) and `LuaCallProxy_AiAndTag_CallVoid` (rva `0x10D600`), with `pcall(L, 2, 0)`. The AI is pushed as its most derived class (nil if null) and the tag as a fresh copy (`LuaPushArgs_AiAndTag`, rva `0x111A40`). A Lua error is caught by `RunHourlyAITrade`'s one try block and reported (`ReportLuaError` at `0x4DC82F`), and that country's hour ends there.

**`DiploScore_OfferTrade(voAI, voFromTag, voToTag, voObserverTag, voTradeAction, voTradedFrom, voTradedTo)`** is called only from `CTradeAction::GetAIAcceptance` (slot 17, rva `0x638B00`). Before Lua is asked, four things can settle the answer:
- the same country on both sides -> 100;
- `IsValid` (slot 13) false -> 0;
- `IsConvoyPossible` false -> 0;
- the **recipient's** AI's `AlreadyTradingDisabledResource` true -> 0.

Otherwise `GetOfferTradeScoreFromLua` (rva `0x60DDF0`) pushes, through `LuaPushArgs_OfferTrade` (rva `0x644D50`):

| parameter | what it is |
| --- | --- |
| `voAI` | the recipient's `CEU3AI`, else the actor's (most derived class, or nil) |
| `voFromTag` | the actor, a fresh copy |
| `voToTag` | the recipient, a fresh copy |
| `voObserverTag` | **the recipient again**: `GetAIAcceptance` passes `this+0x10` twice |
| `voTradeAction` | **the `CTradeAction` itself, by pointer** (`LuaPush_TradeActionAndGoods`, rva `0x645B60`). The script holds the very action being answered, and `GetRoute()` reaches its embedded route |
| `voTradedFrom` | a **fresh `CGoodsValues`** made from the route's `+0x44` block: what the route's `from` side (the actor) hands over per day |
| `voTradedTo` | the same from `+0x34`: what the recipient hands over per day |

Each value is `(float)((double)(float)thousandths / 1000.0)`: `cvtdq2ps`, `cvtss2sd`, `divsd [0x160A300]`, `cvtsd2ss`. **They are laid out in `CGoodsValues` order, not goods order.** `GetAIAcceptance` stores goods `[2],[1],[3],[4],[5],[6],[0]` at `+0..+0x18` (`0xA38B6D`..`0xA38D03`). That matches the offsets luabind registers:

| field | offset | good (index) |
| --- | --- | --- |
| `vMoney` | +0 | money (2) |
| `vFuel` | +4 | fuel (1) |
| `vCrudeOil` | +8 | crude oil (3) |
| `vMetal` | +12 | metal (4) |
| `vEnergy` | +16 | energy (5) |
| `vRareMaterials` | +20 | rare materials (6) |
| `vSupplies` | +24 | supplies (0) |

The copies are made by `LuaPush_TwoGoodsValues` (rva `0x645EE0`) and `LuaPush_CGoodsValuesCopy` (rva `0x646230`, `new 0x1C`), so writing to them changes nothing in the engine. The call is `LuaCallProxy_OfferTrade_CallIntResult` (rva `0x644210`), `pcall(L, 7, 1)`. The result must be a number and is rounded to the nearest integer, ties to even. **A Lua error answers 0**: the catch at `0xA0DF4C` then `xor eax, eax`. Who calls `GetAIAcceptance`, and so `DiploScore_OfferTrade`:
- the recipient's foreign minister, each hour (`AnswerPendingOffers`);
- `RunHourlyAITrade`'s automate-trade block;
- the screen's chance text (`DiplomaticAction_BuildChanceText`);
- **scripts themselves**: `ProposeTrades` calls `loCommand:GetAIAcceptance()` on its own command. The engine then re-enters the same thread's Lua state with `DiploScore_OfferTrade`, the **target's** AI as `voAI`. That is a nested protected call inside `ProposeTrades`, and an error in it answers 0 there without ending `ProposeTrades`.

**`DiploScore_LicenceTechnology(voAI, voActorTag, voRecipientTag, voObserverTag, voCommand)`** comes from `CLicenceTechnologyAction::GetAIAcceptance` (rva `0x63D3F0`). It has no gate of its own and goes straight to `GetLicenceTechnologyScoreFromLua` (rva `0x644990`):
- the AI is the recipient's (the seller's), else the actor's;
- actor, recipient and observer are fresh tag copies, and **the observer is the recipient again**;
- `voCommand` is **the `CLicenceTechnologyAction` itself, by pointer** (`LuaPush_TagAndLicenceAction`, rva `0x645CA0`).

The call is `pcall(L, 5, 1)` (rva `0x6451C0`), with the same rounding and an error answering 0. `Support_License.ProductionCheck` also calls `DiploScore_LicenceTechnology` **directly from Lua**, with `nil` as the observer, before posting.

### B2. Making and posting an offer

**The constructors.** The scripts write `CTradeAction(a, b)` and `CLicenceTechnologyAction(a, b)`. These are luabind constructors, not the registered static `Create` that `FINDINGS-diploaction.md` lists for ten other classes. `CTradeAction` has both, and they build the same object.
- `LuabindConstruct_CTradeAction` (rva `0x5880B0`) does `new 0xB0` and calls `CTradeAction_Construct` (rva `0x634A60`). That sets actor, recipient, type 0 (PROPOSE), `date` and `last_command_date` to the current tick, `value` 1, and the embedded route at `+0x28` with **`from` = the actor and `to` = the recipient**, both goods vectors at nought.
- `LuabindConstruct_CLicenceTechnologyAction` (rva `0x58A3D0`) does `new 0x38` and calls `CLicenceTechnologyAction_Construct` (rva `0x63B3E0`). That writes the same header and zeroes `Subunit` (`+0x28`), `Serial` (`+0x2C`), `Paralell` (`+0x30`) and `Money` (`+0x34`).
- **Both objects belong to Lua** (auto_ptr holders) and are collected with the userdata. Posting is safe because `MakeCommand` clones the action.

**`CFixedPoint(x)`** (`LuabindConstruct_CFixedPointFromFloat`, rva `0x587CA0`). The overload entry first stores the Lua number as a **float** (`fstp dword` at `0x9674D0`). The constructor then computes `floor((float)((float)(f + 0.0005) * 1000))` thousandths: the same `fx` as the operators in `FINDINGS-luaapi.md` section 3, to the nearest thousandth with a half going up, by way of single precision. So `CFixedPoint(-2.5)` is -2500, `CFixedPoint(0.0004)` is 0 and `CFixedPoint(-0.0006)` is -1. (The report this section came from gave `-0.0004` as -1; the formula makes it `floor(0.1)`, 0, corrected 2026-10-13 when OpenHOI3's test of it said so.)

**The setters.**
- `CTradeAction:SetTrading(fp, good)` (rva `0x638DF0`) works out `chargeMoney = !(actor +0xDEC && recipient +0xDEC)`, and the **sign picks the side**:
  - `v > 0`: the recipient's side gets v of the good (route `+0x34`). **The actor buys.**
  - `v < 0`: `|v|`, computed as `(v * -1000) / 1000` in 64 bits, goes on **the actor's** side (`+0x44`). **The actor sells.** The stack copy of the recipient's tag is overwritten with the actor's at `0xA38E64` and `0xA38E72`.
  - `v == 0`: both sides are set to nought.

  Then `TradeRouteSetTradedOf` reprices money (index 2) when `chargeMoney` is set. The price is brief A's; per `FINDINGS-trade2.md` section 3 a side's money entry is what that side pays for what it receives. Between two free traders, money stays at nought. That is exactly `ProposeTrades`' convention: `SetTrading(CFixedPoint(q), g)` to buy and `CFixedPoint(q * -1)` to sell.
- `CTradeAction:GetTrading(good, tag)`: the `+0x44` block's entry when the tag is the actor, else the `+0x34` block's. That is what that side hands over, and for `_MONEY_` what that side pays per day. It answers a `CFixedPoint` (thousandths).
- `CTradeAction:SetRoute(route)` copies the whole route into `+0x28` (`0xA39020`), including the route's own `from` and `to`. In `EvalutateExistingTrades` those can be the other way round from the action's actor and recipient.
- `CDiplomaticAction:SetValue(false)` makes the action a cancellation. `IsValid` then demands that an identical route already exist on the pair (`FindMatchingTradeRoute`, `FINDINGS-trade2.md` section 4).
- Licence setters:
  - `SetSubunit(def)` writes `+0x28`, `SetSerial(n)` `+0x2C`, `SetParallel(n)` `+0x30`, and `SetMoney(fp)` `+0x34` (the fee per unit, thousandths).
  - The getters answer the same fields. `GetSubunit` answers nil when the field is null; that is luabind's null-pointer push, inferred.

**`CAI:PostAction(action)`** (rva `0x49A750`) has no gate. It calls `MakeCommand` (slot 6), which stamps `last_command_date` and clones through slot 16, and posts the clone on the session channel. That is **the same command path as an offer from the screen** (`DiplomacyDialog_OnAgree`, `FINDINGS-agreements.md` section A6). The one difference is that the dialog sets `action.date = now` before posting and `PostAction` does not, so a script's offer keeps the tick its constructor stamped. On every peer, `CDiplomaticActionCommand::Execute` (rva `0x60E120`) then:
1. checks `IsValid` (slot 13); if false, nothing happens;
2. for a PROPOSE other than `callaction`, sets `next_offer_allowed = date + 168 h`;
3. runs slot 7. For a trade offer, `TRADE_INFLUENCE_COST` comes off the actor's influence when the offer is made, clamped at 0; a cancellation costs `TRADE_CANCEL_RELATION_COST` (`CTradeAction::Apply`, rva `0x6352F0`);
4. queues a clone on the **recipient's** pending list.

From there the recipient's minister answers it within the hour: 30 or less declines, otherwise a roll below the score accepts, one trade a call (`FINDINGS-agreements.md` section A2). For the player it goes to the dialog or to automate-trade. **The engine applies no cap on the quantity.** The 50-a-trade cap and the 0.25 floor are the script's (`liMaxTradeAmount`, `liMinTradeAmount`). The scripts gate themselves with `IsValid`, `IsSelectable` and `HasDiplomatEnroute`:
- `IsSelectable` for a trade (rva `0x638920`): different countries; a cancellation passes; an offer needs no war, the actor not a subject, the recipient not a subject or the actor's own, influence of at least `TRADE_INFLUENCE_COST`, a port at both ends where convoys are needed, and no embargo.
- `IsSelectable` for a licence (rva `0x63D300`): no diplomat en route, no war, and for buying, influence of at least `LICENCE_INFLUENCE_COST`.
- `ProposeTrades` checks `IsValid() and IsSelectable()`. `EvalutateExistingTrades` checks `IsSelectable()` for stale routes only and posts its other cancellations unchecked; `Execute`'s `IsValid` is then the only test.

### B3. What each method answers

A `CFixedPoint` answer is thousandths; `:Get()` makes it a single-precision float.

| | answers |
| --- | --- |
| `CCountry:AIGetTradeRoutes()` (rva `0x1080C0`) | iterator. **Rebuilds the scratch vector at `CCountry +0x34` on every call**, then walks the statuses one per country id from 0 up (`+0xE28`) and takes each status's `trade_routes` list (`+0x60`) in order, active and inactive. The iterator walks that member vector |
| `CCountry:GetTradedAwaySansAlliedSupply()`, `GetTradedForSansAlliedSupply()` | the `CGoodsPool`s at `+0x800` and `+0x890`, per day, thousandths; save keys `traded_away_sans_allied` / `traded_for_sans_allied`. Credited by `RunDailyTradeRoutes` beside `traded_away` and `traded_for` (`FINDINGS-convoys.md`). How "sans allied" differs is brief A's |
| `CCountry:GetTechnologyStatus()` | `+0xDF8` |
| `CCountry:GetGlobalModifier()` | the `CModifier` at `+0xD90` |
| `CCountry:GetCountryTag()` | `+0xCA4` |
| `CCountry:HasDiplomatEnroute(tag)` | `tick <= own->+0xE28[tag]->next_offer_allowed`, inclusive (`FINDINGS-agreements.md` section A7) |
| `CModifier:GetValue(id)` | `values (+0x18)[id*8]`, low dword (trap 5), thousandths; `_MODIFIER_GLOBAL_IC_` is 17 |
| `CTechnologyStatus:GetIcModifier()` | `+0x90` (`ic_bonus`), thousandths: technology's share added to the IC multiplier |
| `CTechnologyStatus:IsUnitAvailable(def)` (rva `0x133020`) | `unit_available (+0x27C)[def->Index (+0x24)]` **and** `SubUnitDefinitionIsUsableBy(country tag, def)`. A nil `def` is dereferenced |
| `CGoodsPool:Get(g)` | `[this + 8 + g*4]` as a `CFixedPoint` |
| `CGoodsPool:GetFloat(g)` (rva `0x4E81A0`) | the same over 1000.0, rounded to a float: equal to `:Get(g):Get()` |
| `CIdeologyGroup:GetKey()` | the `CString` at `+0x18`, its name; `tostring` gives the text. The body `0x479740` is a fold shared with `CWarGoal.GetActor` and two `GetKey`s (trap 4) |
| `CSubUnitDefinition:GetBuildCostIC()`, `GetBuildCostMP()`, `GetBuildTime()` | `+0xF8`, `+0xFC`, `+0x100`, thousandths: the definition's own figures, **without** the country's technology discounts (`CTechnologyStatus +0x24C/+0x26C`) |
| `CSubUnitDefinition:IsCapitalShip()` | the byte `+0x2F` |
| `CSubUnitDataBase.GetSubUnit(name)` | the definition by name, or nil (recorded) |
| `CCountryTag:IsReal()` (rva `0x79720`) | **false only for `REB`**: `---` is "real" |
| `CCountryTag:IsValid()` | id (`+4`) != 0 |
| `CCurrentGameState.GetCountries()` | iterator over the game state's country vector (`+0xBBC`), in id order. Inferred: the daily pass at `0x68F04D` dereferences every element without a test, so there is no null to stop the loop, and element 0 is the null country (`---`) |
| `CTradeAction:GetRoute()` | the embedded route at `+0x28`. A reference into the action is inferred (luabind's `const&` push was not read) |
| `CTradeRoute:GetFrom()`, `GetTo()` | `+0x24`, `+0x2C`: in a script-made action, the actor and the recipient |
| `CTradeRoute:GetTradedFromOf(g)`, `GetTradedToOf(g)` | `(*(+0x44))[g]` and `(*(+0x34))[g]`: what the route's `from` side and `to` side hand over per day, thousandths, **whichever country asks** |
| `CTradeRoute:IsInactive()` | `+0x54` |
| `CAI:HasTradeGoneStale(route)` | inactive, `last_inactive` (`+0x84`) not the null date, and `last_inactive + 336 h < tick`: stale after a fortnight inactive (recorded) |
| `CAI:AlreadyTradingDisabledResource(route)` (rva `0x49B3E0`) | over the inactive routes on `countries[from]->+0xE28[to]`: true when, for some good other than money, both the candidate and that route move **more than one thousandth** (`g_TradeGoodsEpsilon`, rva `0x17148A0`, `(int)floorf(1.5f)`) in the **same block position** |
| `CAI:GetSpamPenalty(tag)` (rva `0x49B530`) | 0.0 unless somebody plays `tag`. Otherwise `10 x max(0, dNext - dNow + 24)` as a whole-number float, with `dNow = (tick - 43,800,000)/24` and `dNext` the same of this AI's status's `next_offer_allowed` toward `tag`. **310** in the hour this AI proposes to him, **240** when its seven-day cooldown ends, nought 24 days later. The year terms (365.0) cancel |
| `CDiplomaticAction:GetAIAcceptance()` | slot 17 (B1); an int |
| `CDiplomaticAction:IsValid()`, `IsSelectable()` | slots 13 and 14. The trade's slot 13 is in `FINDINGS-trade2.md` section 4 and its slot 14 is recorded at rva `0x638920`; for the licence, slot 13 (rva `0x63D2C0`) is "no war" and slot 14 is rva `0x63D300` |
| `CLicenceTechnologyAction:GetMoney()` | `+0x34`, `CFixedPoint` |
| `CLicenceTechnologyAction:GetSerial()`, `GetParalell()` | `+0x2C`, `+0x30`, ints. Both bodies are folds (trap 4) |

### B4. What `GetSpamPenalty` does to the AI's offers to a player

`ProposeTrades` keeps an offer only when `GetAIAcceptance - SpamPenalty > 50`. Against a human, a score of 100 therefore needs a penalty below 50, which means `dNext - dNow + 24 < 5`. **So an AI makes at most one trade offer to a given player about every 26 days** (7 + 19). Between AIs the penalty is nought, and only the seven-day `HasDiplomatEnroute` gate applies.

### B5. Behaviours of the scripts themselves

These come out of the Lua, not the bytes. OpenHOI3 reproduces them by running the scripts, but a port would have to keep them:
- `DiploScore_OfferTrade` tests `lbFreeTrader`, an undefined global, so that branch never fires.
- `EvalutateExistingTrades` tests `v.Bypass` where the table sets `ByPass`, so money is not bypassed there. It is harmless, because money's `TradeFor` and `TradeAway` are 0.
- `ai_trade.lua` ends `return Support_Embargo`, which is nil.
- In `DiploScore_LicenceTechnology`, `Seller.Continent` and `Buyer.Continent` are never set (both `Continent` lines write `loDiploScoreObj.Continent`), so `nil == nil` gives **+5 always**.
- `HumanSelling` is true whenever the actor is the seller, human or not.
- `GetTradedFromOf`/`GetTradedToOf` are read as if the asking country were the route's `from`, which it need not be.
- Ties between trades of equal score, and the one-resource-a-trade test, follow `pairs` order. That is Lua 5.1.4's hash order, so it holds only on the original interpreter.

### B6. What looks wrong but is what the bytes do

1. `voTradedFrom`/`voTradedTo` are not in goods order: money first, supplies last.
2. `SetTrading` with a negative value quietly switches sides: the stack tag is overwritten with the actor's.
3. The engine passes the recipient as the observer in both `DiploScore_OfferTrade` and `DiploScore_LicenceTechnology`. From `ProductionCheck` the observer is nil.
4. The hourly trade AI takes two draws, so "review" is 1 in 12, not 1 in 10.
5. The player's own country runs `ProposeTrades` whenever `automate_trade` is on, even with foreign policy not delegated.
6. `GetSpamPenalty` counts 24 days past the cooldown; the `+24` is an immediate (`lea esi, [ebx+esi+0x18]`).
7. `AlreadyTradingDisabledResource` compares blocks by position, so an inactive route made the other way round is matched from-block to from-block. Its "threshold" is one thousandth, from a `(int)floorf(1.5f)` static.
8. `AIGetTradeRoutes` is registered `const` yet rewrites a member vector; a second call on the same country invalidates the first iterator.
9. `CCountryTag:IsReal()` is true for `---`.
10. The getter is spelled `GetParalell` and the setter `SetParallel`; both are the game's names.
11. A script's own `GetAIAcceptance()` re-enters Lua. An error inside it answers 0 and does not stop the caller.
12. Script-made actions keep their construction tick as `date`; `PostAction` does not restamp it.

### B7. Not settled

- What happens when `DiploScore_OfferTrade` or `_LicenceTechnology` return a non-number (a country override falling off its end). `cast_failed` is not caught by the clones, and where it ends was not read.
- Whether luabind pushes `const CTradeRoute&` and `const CCountryTag&` returns as references or copies. Inferred to be references; not read.
- How `traded_*_sans_allied` differ from `traded_*` (brief A's daily pass).
- The trade price `TradeRouteValueOneGood` (rva `0x64C9A0`) and what `TradeRouteSetOneGood` (rva `0x64C880`) does to `+0x38` (brief A).
- Whether a posted cancellation waits for the recipient's answer (slot 18 of `CTradeAction`, brief A).
- `GetCountries`' order and that element 0 is non-null are inferred from the daily pass, not read off the vector's filler.
- In multiplayer, whether every peer runs `RunHourlyAITrade`'s Lua for every country and so posts duplicate offers. Not read.
- The `CResourceValues()` constructor is still unread. It is irrelevant here, because `GetResourceValues` writes all six fields before any read.

### B8. Frontier (rvas)

- `0x64C4F0`: the CTradeRoute constructor. It stores EDX as `from` and ECX as `to`, zeroes the goods vectors and sets the null dates; brief A's.
- `0x5767F0`, `0x5673F0`, `0x585640`: luabind's overload entries for the three constructors. `0x5767F0` and `0x585640` each hold a second function after a bare `ret` (trap 2).
- `0x644180`, `0x645130`: the destructors of the OfferTrade and Licence proxies.
- `0x587BD0`: called from the `CFixedPoint` construct.
- `0x645820`: the function after `LuaPushArgs_LicenceTechnology`, called from `0x6451C0`.
- `0x64C9A0`: the trade price (brief A).

## C. Aid: debt, licences, lend-lease, shared technology (brief C)

*Read on 2026-10-13 by brief C of the trade and aid wave. Addresses are virtual (base `0x400000`), with the rva beside anything named. `type` is the action's +0x18 (0 PROPOSE, 1 DECLINE, 2 ACCEPT) and `value` is the bool at +0x24. All money, IC and levels are in thousandths unless stated. S is `actor->diplomacy[recipient]`. "Told" means a message is raised only when that country is the one being played.*

**Corrections to the record**: `CDiplomacyStatus +0x70 debt` is what the array's owner **owes** the other country - the record had it the other way round, and so had `CLicenceTechnologyAction::Apply`'s comment (it said `seller->diplomacy[buyer]`). `repaid_away` (+0x824) and `income_from_debt` (+0x848) **are** written, money slot only, by a repayment loop in `CCountry::CollectDailyProduction` - which settles `CANDIDATES.md`'s open item on them. `RunCountryDailyPass`'s "0x4DC242 onward is SEH unwind" is wrong: 0x4DC24D..0x4DC3E3 is body (trap 3), and it holds the AI's `BalanceLendLeaseSliders` call. And the debt itself is never reduced anywhere in the image.

### C.1 Debt

**What `allowDebts` means.** `allowDebts` (`CDiplomacyStatus +0x78`) on `X->diplomacy[Y]` means **X may run a debt with Y**. "Allow Debt" is asked by the would-be debtor; the localisation agrees (ALLOWDEBTDESC "Request to be allowed to accumulate debt during wartime when trading with them").

**`CDebtAction::Apply`** (`0xA3D8A0`, rva `0x63D8A0`):
- **Ask** (PROPOSE, value 1): the actor's influence is reduced by ALLOW_DEBT_INFLUENCE_COST (diplomacy +0xC4), floored at 0.
- **Accept** (ACCEPT, value 1): `actor->diplomacy[recipient].allowDebts = 1` (`0xA3E012`). The actor is told DEBTALLOWACCEPT.
- **Decline**: the actor is told DEBTALLOWDECLINE.
- **Revoke** (PROPOSE, value 0; the actor is the creditor):
  - `recipient->diplomacy[actor].allowDebts = 0` (`0xA3DD48`).
  - **The recipient's influence** is reduced by REVOKE_DEBT_INFLUENCE_COST (+0xC8, negated at `0xA3DD75`), floored at 0 (`0xA3DD77`). So the debtor pays for being cut off. IsSelectable, meanwhile, demands that the revoker have both costs.
  - The recipient is told DEBTREVOKE. A revoke is not answered: slot 18 is `value`.
- No third country is told anything.
- **Nothing here touches the debt.** A revoke leaves an existing debt in place, and it goes on being repaid.

**War.** Declaring war clears `allowDebts` both ways (`0xA12E69` and `0xA12E96`, already in the record). It does not clear the debt.

**How a debt grows.** Only while the debtor is at war (`+0xACC`) and holds `allowDebts` towards the creditor:
- **Licence.** `buyer->diplomacy[seller].debt += fee` (`0xA3C5A1`). The seller is paid nothing at that moment.
- **Trade.** In `CCountry::RunDailyTradeRoutes`, for goods index 2 (money) only, the day's money owed goes onto the debtor's status instead of leaving its pool (`0x4FF442` this side, `0x4FF485` the partner's side). A flag (`[ebp-0x11]`) then lets the route run even where the debtor's money is below nought. The creditor's local pool is still credited with the money (`0x4FF4A1`, inferred from the two local pool copies; section A.8 says the same): the creditor is paid at once and again when the debt is repaid.

**Repayment** happens at the end of `CCountry::CollectDailyProduction` (rva `0xF1F50`; `0x4F23E2`..`0x4F25B9`). That function runs inside the daily pass's economy gate, so a debtor that owns no province never repays. For each country O:
- `r = CDiplomacyStatus::GetDailyRepay(this->diplomacy[O])` (rva `0x64A7F0`): computed only where debt > 0 and `daily_repay <= 0`; then `daily_repay = debt * 1000 / (YEARS_TO_REPAY_DEBT * 365000 / 1000)`, or -1 where that day count is 0. Otherwise the stored figure is kept.
- Where r > 0:
  - If the debtor is at war with anybody, or its money is not **strictly greater** than r, then `daily_repay = 0` and nothing is paid that day.
  - Otherwise the debtor's pool money goes down by r and O's up by r; `this->repaid_away.money (+0x834) += r`; `O->income_from_debt.money (+0x858) += r`.
- **The debt (+0x70) is never reduced.** A full `.text` sweep found no `sub` of `[reg+0x70]` at all. Its only writes through a diplomacy-array element are the three `add`s above; the positive control is that the same scan finds the licence's known `add`.
- So with Their Finest Hour's 50 years the debtor pays 1/18,250 of the debt each peaceful day, **indefinitely**; a debt under 18.250 gives a daily figure of 0 and is never repaid; and the daily figure is reworked from the current debt after any day the debtor was at war or could not pay.
- `repaid_away` and `income_from_debt` are not saved. Whether they are zeroed each day was **not settled**.

**Debt texts:**
- **Slot 11** (`0xA3E510`): ACT_NO_SELF; WEWAR (S.war); ENROUTE; DIP_NO_INFL with INF = the cost to 0 places (ALLOW cost when asking, REVOKE cost when revoking); otherwise ALLOWDEBTDESC (base game `v1.csv`; TFH ships only `_BAD`) or REVOKEDEBTDESC.
- **Slot 12** (`0xA3ECE0`, rva `0x63ECE0`): allowing, ALLOWDEBTNEWDESC "...when trading with the $NAME$? ... repaid over $YEAR$ years ... cost us $COST$ influence points." - NAME is **the recipient's faction's localised name**, YEAR is YEARS_TO_REPAY_DEBT and COST is ALLOW_DEBT_INFLUENCE_COST, both to 0 places; revoking, REVOKEDEBTNEWDESC with NAME = the recipient's name and COST = REVOKE_DEBT_INFLUENCE_COST.
- **Slots 13 and 14**: as already recorded (13 = neither country in exile).
- **Slot 18**: `value`. A player recipient gets CAskDebt (ASKDEBTREQDESC).

### C.2 Licences

**The action.** Fields: Subunit +0x28, Serial +0x2C (units per run), Paralell +0x30 (runs), Money +0x34 (price per unit). The actor is the buyer, the recipient the seller.

**`CLicenceTechnologyAction::Apply`** (`0xA3B5A0`, rva `0x63B5A0`):
- **Debt or cash.** The buyer is "on debt" when `buyer->diplomacy[seller].allowDebts` is set and the buyer is at war.
- **Fee.** `fee = Money x Serial x Paralell`, in thousandths of money. The counts become thousandths through `floor((n + 0.0005) * 1000)`, and each multiplication is a truncating 64-bit `/1000`.
- **An accept the buyer cannot pay.** If the buyer is not on debt and its money is below the fee, `type` is set to DECLINE (`0xA3C348`); the buyer then hears a decline.
- **Propose** (value 1): the buyer's influence is reduced by LICENCE_INFLUENCE_COST, floored at 0.
- **Accept** (value 1):
  - On the machine allowed to issue commands (session +0x34), **Paralell times** a `CConstructUnitCommand` is posted, carrying the type; the buyer's acting capital; amount = Serial; **is_reserve = the type's land byte (+0x2D)**; country = the buyer, **builder = the seller**.
  - The command's constructor (`0x545760`) takes **each brigade's technology levels from the builder**. So the buyer builds, in its own queue and with its own IC and manpower, a model at the **seller's** current levels; the queue charges a hundredth more cost and time per level, as the build queue does.
  - Then either the buyer's debt grows by the fee, or the fee moves as cash (buyer down, seller up).
- **Messages.** Only the buyer is told, at the seller's capital: LICBUYACCEPT with ACCEPTED = the key ACCEPTED, which has no text and so shows as the key; or LICBUYDECLINE with DECLINED likewise. NAME = the seller's best current model name (with "+*" where it differs from the model matched); NUM = Serial x Paralell.

**The dialog** (`CLicenceTechnologyDialog`, `LicenceDialog` in `interface/diplomacydialog.gui`; ctor rva `0x379A00`):
- **The list** (`BuildUnitList`, `0x77B690`): a unit type is listed when it is buildable and usable by the buyer; the seller can still build it (`CountMaxUnitsStillBuildable` >= 1); it is not a capital ship; and, where the buyer can build it too, the buyer's version scores no higher than the seller's (`GetSubUnitDefinitionCombatValue`).
- **Serial and parallel** each run 1..99 by their plus and minus buttons.
- **`money_slider`**: price per unit = slider x **the buyer's current money stockpile** (`GetOfferedMoney`, `0x77BB80`).
- **Description:** BUYLICENCENONE with no type selected; otherwise BUYLICENCENEWDESC with RUNS = parallel, NUM = serial, TYPE, and PAY = money/1000 x parallel x serial to one place, which is exactly the fee. Refresh copies parallel, serial and money into the action.
- **chance_string** is the AI chance word, refreshed when the slider or the score changes.
- **`debt_desc`** (IS_BOUGHT_WITH_DEBT) shows only under Apply's own debt test.
- **Agree** is disabled with no type selected, or where the buyer's manpower is below `build_cost_manpower x max(1000 + build_cost_mp_by_unit_type, 1/20) / 1000 x serial x parallel`; the row's tooltip is then BUYLICENCE_MPCOST.
- **Row tooltips**: the delayed half is the seller's version of the type through `BuildStatsTooltip`.

**Licence slots:** 11: ACT_NO_SELF; ENROUTE; buying: DIP_NO_INFL (0 places), else BUYLICENCEDESC; value 0: SELLLICENCEDESC - there is no WEWAR arm, although 13 and 14 test war. 12: the folded empty string; the dialog writes its own Description. 13: S.war null. 14: as already recorded. 18: always true; any proposal to a player becomes CAskBuyLicence.

### C.3 Lend-lease

**What a country holds:**
- **Its givings, +0x6B8**: 16-byte entries {receiver, weight +8, effectiveness +0xC}; save keys `lendlease_targets`, `lendlease_distributions`, `lendlease_effectiveness`.
- **Its receipts, +0x6C8**: 12-byte entries {giver, amount}; save keys `lend_lease_from` and `_values`.
- **+0x6D8**: yesterday's copy of the receipts.
- **lend_lease_income (+0x6E8)**: lend-lease received and not yet turned into IC.
- **lend_lease_income_yesterday (+0x6EC)**: the IC turned into IC on the last day.

**`CRequestLendLeaseAction::Apply`** (`0xA0ECC0`). The actor asks; the recipient would give.
- **Ask**: the actor's influence is reduced by **ALLOW_DEBT_INFLUENCE_COST**.
- **Cancel** (PROPOSE, value 0): `RemoveLendLease(recipient -> actor)`. The recipient is told **LENDOFFERREFUSED**, with ACTOR and RECIPIENT swapped so that it reads from the giver's side.
- **Accept**: `AddLendLease(recipient -> actor)`. The actor is told LENDACCEPT.
- **Decline**: the actor is told LENDDECLINE.

**`COfferLendLeaseAction::Apply`** (`0xA10870`) charges no influence.
- **Stop** (value 0, PROPOSE only): `RemoveLendLease(actor -> recipient)`. The recipient is told **LENDREVOKE**, swapped likewise.
- **Accept**: `AddLendLease(actor -> recipient)`. The actor is told LENDOFFERACCEPT.
- **Decline**: the actor is told LENDOFFERREFUSED.
- No third country is told for either action.

**Starting and stopping.** `AddLendLease` (rva `0x1084B0`) appends {receiver, weight 500, effectiveness 0} and adds the giver to the receiver's receipts. `RemoveLendLease` (rva `0x108550`) undoes both and scraps the receiver's lend-lease convoy from that giver, returning its transports and escorts to the receiver's pool.

**Eligibility** (`LendLease_GetRoute`, `0xA10180`). The first that holds:
- either side is a government in exile: refused, ACT_LENDLEASE_ANY_GOI;
- the **giver's** EffectiveNeutrality is above LEND_LEASE_NEUTRALITY_LIMIT (TFH 60): refused, ACT_LENDLEASE_OUR_NEUTRALITY or ACT_LENDLEASE_NEUTRALITY;
- the **receiver** is at war with nobody: refused, ACT_LENDLEASE_THEM_ONLY_AT_WAR or ACT_LENDLEASE_ONLY_AT_WAR;
- the two are at war with each other: refused, WEWAR.

Then the route: **2**, LEND_LEASE_ALLOWED_NEIGHBOUR - the two are neighbours, or the giver is among the receiver's controller-neighbours; **3**, LEND_LEASE_ALLOWED_TELEPORT - the two capitals are on the same continent; **1**, LEND_LEASE_ALLOWED_CONVOY - both have a naval base; otherwise refused, LEND_LEASE_NOT_ALLOWED. The giver need not be at war.

**Every hour** (`CCountry::UpdateLendLeaseRoutes`, `0x508C30`, from `RunCountryHourlyPass`), the check is rerun for each giver of each receiver:
- **Refused**: a `CRemoveLendLeaseCommand` is posted. The receiver is then told **LENDREVOKE** "have revoked our lend-lease aid", even though the rules ended it, not the giver.
- **Land route**: the giver's entry gets effectiveness 1000.
- **Sea route**: the **receiver** makes (if it has none) and owns a lend-lease convoy, from the giver's harbour (`NearestPortTo` the receiver's first port, in the giver's capital area) to its own capital area's first port. Effectiveness = `CConvoy::GetEfficiency` of that convoy: the share of transports it has against those it wants, times the lend-lease convoy efficiency that sinkings lower. With no harbour, no convoy is made and the effectiveness stays at 0.
- **The convoy carries nothing.** It only sets the effectiveness figure; `RunDelivery` already refuses lend-lease convoys.

**The share** (`CDistributeLendLease::Distribute`, `0x518800`; daily, slider 0):
- `total = available x base_percentage x factor`, as 48.15 numbers.
- For each receiver: `amount = total` (in thousandths of IC) `x weight/sum of weights / 1000 x effectiveness / 1000`, truncated.
- If `amount <= GetResourceLimitedIC`: `ConsumeIcResources` charges the giver's metal, energy and rare materials, and `ReceiveLendLease` (rva `0x108900`) credits the receiver.
- **Otherwise that receiver gets nothing that day.** There is no partial delivery.
- The function writes 0 to its out-value. It never reads `+0x608`, so lend-lease IC received cannot be passed on for free.

**What the receiver gets** is IC, in its own daily `UpdateIC`, applied after the resource cap: `lend_lease_ic (+0x608) = floor(lend_lease_income / 1000)` whole IC, added to TotalIC, needing no resources. The receipts are copied to "yesterday", then that whole IC is taken out of the entries in order; the fractional remainder carries over to the next day. How a day's IC reaches the receiver therefore depends on where giver and receiver fall in the country loop.

**Weights:** `CChangeLendLeaseDistributionCommand::Execute` (rva `0x155580`) sets each weight as given, not normalised. The AI's `BalanceLendLeaseSliders` (Lua) sets each receiver's weight to its TotalIC; it is called from the daily pass's cold block. A sum of 0 gives every receiver a share of 0; the `-1` arm after it is dead code, the global it compares against being 0.

**The cap.** `GetMaxLendLeaseFraction` (rva `0x108A90`) = `LOW + (HIGH - LOW) x (1 - min(1, EffectiveNeutrality / LIMIT))`; in TFH from 0.90 at neutrality 0 to 0.05 at neutrality 60 and above. `GetMaxLendLease` = TotalIC x that. **Nothing in the engine enforces it.** It drives only the slider's `limit` marker (GetLimit), the top-bar tooltip (LEND_LEASE_MAX_VALUE) and the AI script's target; a player can set the slider past it. TotalIC already includes lend-lease received.

**Lend-lease texts:**
- **Request:** slot 11 - cancel shows LEND_LEASE_CANCEL_DESC if the recipient gives, else nothing; asking shows LEND_LEASE_DESC "\n" + the route line only on success, otherwise ENROUTE or the refusal reason alone. Slot 12: LEND_LEASE_DESCRIPTION / LEND_LEASE_BREAK_DESCRIPTION, no cost line although asking costs influence. Slot 13 (shared body): the countries differ and the recipient owns a province. Slot 14: the gate (asking) or "the recipient gives" (cancelling). Slot 18: `value`.
- **Offer:** slot 11 - stop shows STOPLL_DESCRIPTION; offering shows ENROUTE, or empty if already giving, or OFFERLL_DESCRIPTION "\n" + the route line **or the refusal reason**, prefixed either way. Slot 12: OFFERLL_DESCRIPTION / STOPLL_DESCRIPTION. Slots 13, 14, 18: as for the request.
- A player recipient gets CAskLendLease (ASK_ / OFFER_LEND_LEASE_DESC).

### C.4 Shared technology

- **The action.** `CShareTechnologyAction::Apply` (already read) takes effect on the offer; slot 18 is false.
  - **Share**: influence is reduced by SHARE_TECH_INFLUENCE_COST, then `StartSharingTechWith` (`0x507B40`, rva `0x107B40`): {receiver, category} is appended to the sharer's +0x6F0 list; where the receiver already has a sharer for that category, `StopSharingTechWith(old sharer, receiver)` runs, which ends **every** category the old sharer gave that receiver; `receiver->category_shared_from[cat]` (+0x6A8) = the sharer.
  - **Stop**: `StopSharingTechWith(actor, recipient)`, free of charge.
  - No messages.
- **Only theories can be shared** (`CTechnologyCategory +0x60`).
- **What it does to the receiver:** every reader of the category level uses `max(own, sharer's own)` - research speed (`GetCategoryResearchAbility`), the build-cost discount, `GetAbility`, the screen's skill entry, and the `practical` effect - following the sharer's level as it changes. The `practical` effect adds its value to `max(own, shared)` and stores the result as the receiver's own (already recorded), so an event on a shared theory makes the shared level permanent.
- **What it costs the sharer:** SHARE_TECH_LEADERSHIP_COST leadership per entry per day (already recorded in FINDINGS-leadership).
- **The daily check** (`CCountry::CheckTechSharing`, `0x507DF0`; from RunCountryDailyPass at `0x4DAEA2`): an entry is dropped where the receiver owns no province or the sharer's **own** level is not above the receiver's **own** level. Dropping goes through StopSharingTechWith, so every category shared with that receiver ends.
- **The dialog** (`ShareTechnologyDialog`, ctor rva `0x3904D0`): it lists the theories where the recipient's effective level is below the actor's own, showing the actor's level ("Our") and the recipient's effective level ("Their"). Description: TS_NO_SELECTED with Agree disabled; or TS_SELECTED with TECH, COUNTRY, COST = SHARE_TECH_INFLUENCE_COST and LEADERSHIP = SHARE_TECH_LEADERSHIP_COST, each to 1 place. Agree writes the category into the action's +0x28 and posts.
- **Slots:** 11 (already recorded): DIP_NO_INFL prints cost/1000 as a whole number. 12: stopping only, CANCEL_SHARE_TECH_INFO (TECH = the first shared category) or `_NO`. 13: stopping is always true; sharing needs a theory, a recipient that owns a province, and the actor's own level above the recipient's effective level. 14 (already recorded). 18: false.

### C.5 Who is told which key (actor / recipient / anybody else)

| arm | actor | recipient | other |
| --- | --- | --- | --- |
| debt accepted | DEBTALLOWACCEPT | - | - |
| debt declined | DEBTALLOWDECLINE | - | - |
| debt revoked | - | DEBTREVOKE | - |
| licence accepted | LICBUYACCEPT | - | - |
| licence declined, or refused for want of money | LICBUYDECLINE | - | - |
| lend-lease request accepted | LENDACCEPT | - | - |
| lend-lease request declined | LENDDECLINE | - | - |
| lend-lease request cancelled | - | LENDOFFERREFUSED | - |
| lend-lease offer accepted | LENDOFFERACCEPT | - | - |
| lend-lease offer declined | LENDOFFERREFUSED | - | - |
| lend-lease offer stopped | - | LENDREVOKE | - |
| CRemoveLendLeaseCommand (the rules ended it) | - | LENDREVOKE | - |
| share technology | - | - | - |

### C.6 What looks wrong but is what the bytes do

1. A debt is never reduced, so repayment runs for ever. A debt under 18.250 is never repaid at all.
2. Revoking someone's debt permission charges the influence to the debtor, not the revoker.
3. The Allow Debt dialog names the recipient's faction, not the country.
4. Lend-lease requests are charged ALLOW_DEBT_INFLUENCE_COST; offers cost nothing.
5. An accepted licence the buyer cannot afford turns into a decline. The licence fee is per unit x serial x parallel, with the per-unit price set as a share of the buyer's current cash.
6. Licensed land brigades are ordered as reserves: the type's land byte is passed where a builder window passes its as_reserves box.
7. A licensed unit is built at the seller's technology levels, in the buyer's queue.
8. The lend-lease IC caps (LOW/HIGH) are display and AI only; the engine does not enforce them.
9. A receiver whose share exceeds the giver's resource-limited IC gets nothing that day. Lend-lease that is not delivered is lost.
10. A lend-lease convoy belongs to the receiver and only scales an efficiency figure; it carries nothing.
11. When the rules end lend-lease, the receiver is told the giver "revoked" it.
12. A new sharer of one theory ends every theory the old sharer gave that country, and the daily check drops all of a receiver's categories when one fails.
13. The offer's tooltip prefixes OFFERLL_DESCRIPTION to a refusal reason; the request's does not.
14. The licence tooltip has no WEWAR arm, and ACCEPTED/DECLINED have no text.

### C.7 Not settled

- **Whether `repaid_away`, `income_from_debt` and `traded_away` are zeroed daily.** `traded_away` visibly goes up and down between saves, yet a displacement scan finds no clearing write for it. That positive control fails, so no claim is made either way for the debt pools.
- `0x507500` (a country's version of a unit type) was not read. The money slider's range was not read either (assumed 0..1).
- Whether `UpdateLendLeaseRoutes`'s CRemoveLendLeaseCommand is posted once or by every peer in multiplayer (it is hourly code with no originate test seen).
- How a receiver's lend-lease convoy is given transports after creation (it starts with none in a running game).

### C.8 Frontier (rvas)

`0x107500`, `0x155CA0` (CRemoveLendLeaseCommand constructor), `0x1565C0` (its Clone), `0xF25E0` (a subject's daily call), `0x37B400` (licence dialog slot 3), `0x118BA0` (lend-lease window opener, slot 8), `0x110160` and `0x110210` (the BalanceProduction/LendLeaseSliders proxies), `0x1085E0` and `0x108A20` (Lua accessors), `0x10F9F0`, `0x111C10`, `0x111D90` and `0x111E50` (vector helpers).
