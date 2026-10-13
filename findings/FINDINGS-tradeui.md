# The trade interface: the trade list, an offer to the player, automate-trade, the messages

Read 2026-10-13 in the trade interface wave (`WAVE.md` of that date), for OpenHOI3's trade screens,
after the maintainer set its trade window beside the original's. It builds on
`FINDINGS-tradeaid.md`, which read the trade itself, and `FINDINGS-agreements.md`, which read the
offer's way to the player in outline. Section A is the production screen's trade list, the cancel
dialog, the trade messages' variables and the Automate Trade checkbox; section B the offer to the
player on screen, the bar of offer icons and where the request dialogs stand.

**Corrections to the record:** `FINDINGS-tradeaid.md` A.6 said the accept arm's `ACT_TRADE` /
`REC_TRADE` are used by no shipped text. Four texts use them and every one is filled (A.6 below);
`ACTORS`, which `WEDETRA_5` asks for, is filled too, with the actor's name.

Measured before the reading, from the maintainer's screenshot of 2026-10-13: the player's own trade
dialog stands at the screen's centre plus `diplo_request_pos` (10, -100), within three pixels.

## A. The trade list, the cancel dialog, the messages' variables and automate trade (brief A)

*Addresses are virtual (based 0x400000), with the rva beside anything named. The interface files are
Their Finest Hour's: `tfh/interface/country_production.gui` (the trade item is identical in
`interface/`), `interface/eu3dialog.gui` and `tfh/interface/country_diplomacy.gui`. Amounts are
thousandths unless said otherwise.*

### A.1 In one line

- **The list holds every trade route of the played country.** It runs through the country database
  in id order, skipping the player's own country. Each partner's routes come in the order they were
  accepted. Active and inactive routes are both listed, whichever side the player is on.
- **A line is the partner's flag and name, then one icon per good.** The icons for what the player
  hands over go in `purchase_box`, under "Export". The icons for what he gets go in `sales_box`, under
  "Import". **No line shows a figure**: the daily amount is only in each icon's tooltip.
- **The X on a line opens a confirmation dialog.** Its OK posts the cancellation, as
  `FINDINGS-tradeaid.md` A.9 says.
- **The trade messages have all their variables filled.** ACT_TRADE is what the player's side gives
  and REC_TRADE what it gets; ACTORS is the proposer's name.
- **Automate Trade is a local flag, not a command.**

### A.2 The list (`trade_list`) and when it is rebuilt

`trade_list` is a listbox in `country_production`, placed at (675, 476) and 362x64, with spacing 2.
Above it the window has three labels:
- `trades_label`: PW_TRADE_ROUTES "Trade Routes";
- `export_label` at x 810: PW_EXPORT "Export";
- `import_label` at x 920: PW_IMPORT "Import".

**`CProductionView::RebuildTradeList` (0x802700, rva 0x402700)** builds the list. It is `ret 4`, with
the view on the stack. In order:
1. It keeps the list's scroll value (-1.0 if the list has no scrollbar).
2. It empties the list.
3. It copies the country database's vector (`g_CCountryDataBase +0x16C`) and walks it in id order,
   skipping the played country (game state +0xC34).
4. For each country, it takes every route on `played->diplomacy[that country]->trade_routes` (+0x60),
   in list order. `CTradeRoute::Activate` appends, so this is the order the routes were accepted. Each
   route gets one `CTradeItem`.
5. It restores the scroll position.

It is called from four places:
- `CProductionView::Rebuild` (0x7FBE09) and `Show` (0x7FF5A9);
- `Update` at 0x7FD443, when the country shown changed;
- `Update` at 0x7FE95D, when the list's count differs from the sum over every other country c of
  `played->diplomacy[c] +0x68`, the routes' count.

**Every frame**, before that count test, `Update` runs every line's `CTradeItem::Update`. A line's
icons and name are never refreshed except by a rebuild.

### A.3 A line (`CTradeItem`, 0xA8 bytes; constructor 0x802AB0, rva 0x402AB0)

The window is `production_trade_item`, 256x16. Its elements are set as follows:

| element (.gui) | what it is set to |
| --- | --- |
| `trade_entry_bg` | the file's GFX_trade_entry_bg; untouched |
| `name` (instantTextBox, Arial12, at (-4, 0), max width 128) | `"@" + partner tag + " " + partner's name`, so the partner's flag is drawn in the text and then his name. The partner is the route's `first`, or its `second` where `first` is the played country |
| `purchase_box` (OverlappingElementsBox, x 125, 120x32, spacing 1.0) | one icon per good the **player hands over** |
| `sales_box` (x 240) | one icon per good the **player receives** |
| `inactive_icon` (GFX_trade_inactive, at (-8, -3)) | moved and shown by Update (below); otherwise hidden |
| `cancel` (GFX_trade_cancel button at (339, -4)) | opens CTradeCancelConfirm (A.5). No tooltip |

**The icons.** The constructor walks the goods g = 0..6 in pool order:
- **If `trade_from[g]` > 0:** it makes an icon of the type `<key>_trade_icon`. The keys, from a table
  set up at start (0x170CF50), are supplies, fuel, money, oil, metal, energy and raremat. The icon is
  wrapped in its own 32x32 `production_trade_goods` window. It goes to `sales_box` if the route's `to`
  is the player, and to `purchase_box` otherwise.
- **Else, if `trade_to[g]` > 0:** the same, with the boxes swapped.

Money is a good like the others, so the price shows as a money icon in the buyer's Export column. The
icon types are the `<good>_trade_icon` entries of the same file, which use the GFX_icon_*_mini
sprites.

**Update (slot 8, 0x803D90), every frame.**
- **When it shows the marker:** the route is `inactive` (+0x54) **and** the line's window is visible
  (+0x5B).
- **Where it puts it:** at the position of `sales_box` (240, -2) if the route's `convoy_responsible`
  is the played country, else of `purchase_box` (125, -2), **plus 32 in x**.
- **Otherwise:** it hides it.

### A.4 The line's tooltip (`CTradeItem_BuildTooltip`, 0x803FD0, rva 0x403FD0)

`CProductionView::BuildTooltip` asks this for every line whose window contains the hovered element;
the last line that matches wins. There are three cases.

1. **A goods icon.**
   - **The player gives** when the icon was made for `trade_from` and the route's `from` is the played
     country, or was made for `trade_to` and its `to` is.
     - Then the text is PW_EXPORTING "Exporting §Y$NUM$ $TYPE$§W to §Y$COUNTRY$§W".
     - Otherwise it is PW_IMPORTING "Importing §Y$NUM$ $TYPE$§W from §Y$COUNTRY$§W".
   - **The variables:**
     - NUM = the daily amount of that good from the icon's own block, /1000 as a float, to two
       decimals (FormatFloat). Money is included.
     - TYPE = GoodName(g): Supplies, Fuel, Money, Crude Oil, Metal, Energy, Rare Materials.
     - COUNTRY = the partner's name.
   - The good is found by matching the icon's name against `<key>_trade_icon`.
2. **`inactive_icon`.** The text is TRADE_IS_INACTIVE "Trade is inactive, most likely due to either
   party being out of a traded resources". The **delayed half** is the route's `inactive_reason` as the
   day's pass wrote it: TRADE_INACTIVE_CONVOY "§Y$COUNTRY$§W have not assigned enough convoys." or
   TRADE_INACTIVE_NO_RES "§Y$COUNTRY$§W does not have enough §Y$RES$§Y.".
3. **Anything else on the line** (the name, the cancel button, the background): an **empty** tooltip.

### A.5 Cancelling: the `cancel` button and `CTradeCancelConfirm`

**The button.** `CTradeItem::OnCancelClicked` (0x803C70) does `new(0xF0) CTradeCancelConfirm(route)`
and `CEU3Idler::AddDialog`. Nothing is tested, so every press opens another dialog.

**The window** is `DefaultConfirm` (`interface/eu3dialog.gui`):
- 500x280, orientation CENTER, at (-250, -140);
- background `Background`, and the banner `default_popup_banner`;
- `Title`: Arial_17, centred, y 53;
- `Description`: Arial14_black, centred, (70, 90), 360x200;
- `AgreeButton` at (264, 200): OK "Ok", ENTER;
- `DeclineButton` at (104, 200): CANCEL "Cancel", ESCAPE.

The buttons keep the file's labels; the dialog's base constructor only binds them.

**What the constructor (0x804A70, rva 0x404A70) sets.**
- It copies the route to +0x68.
- **Title** = CANCELTRADETITLE "Cancel Trade Agreement", through `CEU3Dialog_SetTitle`.
- **Description** = CANCELTRADENEWDESC "Do you wish to cancel our agreement with $COUNTRY$?\nThis will
  stop the transfer of $SELL$ for $BUY$.", where:
  - COUNTRY = the partner;
  - **SELL = FormatTradeGoods(trade_from) and BUY = FormatTradeGoods(trade_to) in both branches.**
    `FINDINGS-tradeaid.md` A.12 point 14 is confirmed: the dialog reads correctly for the route's
    `from` and backwards for its `to`;
  - the text is set through `CEU3Dialog_SetDescription`, which turns every §W into §b. So a good reads
    "§Y0.40 Metal" in yellow and then returns to black text.

**The slots:**
- Slot 5, `OnAgree` (0x805160, rva 0x405160): posts a CTradeAction with value 0, actor the player,
  recipient the partner and the copied route. Read in `FINDINGS-tradeaid.md`; it stands.
- Slot 6, `CEU3Dialog::Close`: Cancel just closes.
- Slot 7: ReturnTrue.
- Slot 0 (0x8050D0): the destructor.

### A.6 The messages' variables (`CTradeAction::Apply`, 0xA352F0, rva 0x6352F0)

**For every arm**, the variable list is `CCountry::BuildMessageVariables` of the **played** country:
its fourteen, starting with $COUNTRY$, so $MONARCHTITLE$ and $foreign_minister$ are the player's own.
Four more are appended:
- ACTOR = the actor's name;
- **ACTORS = the actor's name again**: the same call on the same tag, at 0xA355CE;
- RECIPIENT = the recipient's name;
- MESSENGER = MESSAGE_HEAD_CHAN "The Foreign Office reports".

The trade variables, arm by arm (blocks are the action's own route):

| arm, who is told | key | ACT_TRADE | REC_TRADE |
| --- | --- | --- | --- |
| accept, actor played | ACTRAWITHUS (at the recipient's capital) | trade_from | trade_to |
| accept, recipient played | WETRADEAG (at the actor's) | trade_to | trade_from |
| accept, anybody else | OTHERTRADEAG (at the actor's) | trade_from | trade_to (its texts use neither) |
| decline, any | DETRAWITHUS / WEDETRA / DETRAWITHOTHER | not set | not set |
| cancel, actor played | WEBRKTRADE | not set | not set |
| cancel, recipient played | BRKTRADEUS (at the actor's) | the played country's give: trade_from if it is the route's `from`, else trade_to | its get |
| cancel, anybody else | BRKTRADEOTH | not set | not set |

So the four texts that use them read correctly:
- ACTRAWITHUS_6 "…We will supply them with $ACT_TRADE$ per day in exchange for $REC_TRADE$ per day."
- WETRADEAG_4 "We will supply them with $ACT_TRADE$ per day in exchange for $REC_TRADE$ per day."
- BRKTRADEUS_6 "We will no longer receive $REC_TRADE$ for $ACT_TRADE$"
- WEDETRA_5 "$ACTORS$", which shows the proposer's name.

The accept arm builds its two variables only inside the gate that requires foreign policy not
delegated and automate_trade clear. Each value is FormatTradeGoods text, such as "§Y0.40 Metal§W ". A
popup looks the value up as a localisation key and shows it as itself (`FINDINGS-messageshow.md`).
Popup lines turn every §W into §b.

### A.7 `trade_automate_checkbox` (diplomacy screen)

**The elements** (`country_diplomacy.gui`):
- a checkbox at (120, 528), GFX_checkbox_square;
- its label `trade_automate_checkbox_label`: AUTOMATE_TRADE "Automate Trade", Arial12_alpha, at
  (155, 532).

**A click** goes to `CDiplomacyView::OnTradeAutomateToggled` (0x78E290), which does
`GetLocalPlayer()+0x34 = !+0x34`. **No command is posted**: the byte is the local player record's
own, and is saved as `automate_trade`. The box toggles itself on the click. *Checked by the
collecting session: the handler reads `[GetLocalPlayer() + 0x34]` at 0x78E328 and writes it back at
0x78E3B4.*

**The box's frame each frame** comes from `CDiplomacyView::Update` (0x77EB90-0x77EEDD):
- In a custom game, the box and its label are hidden; otherwise they are shown.
- It is ticked (checkbox +0x60 and +0x100 set to 1) while the view's automation setting is 1, that is
  foreign policy left to the AI, **whatever the flag says**.
- Otherwise it is ticked where +0x34 is set, and unticked where it is clear. The one exception: Update
  does not untick a box whose +0xD8 and +0x136 are both set.

**No tooltip.** The element's name string is referenced only by BuildWidgets (twice) and Update.
`CDiplomacyView::BuildTooltip` never names it; as a positive control, `surrender_progress` is found by
the same search, inside BuildTooltip. The .gui gives it none either.

**What reads the byte:**
- `CCountry::RunHourlyAITrade`: answering trades, and letting the Lua trade for the player;
- the tail of `CEU3Idler::Update`: keeping trade offers back from the player;
- `CTradeAction::Apply`: the accept and decline message gates;
- `CDiplomacyView::Update`: the tick.

`CGameState::LoadKey` writes it.

### A.8 What looks wrong but is what the bytes do

1. A trade line has no numbers; amounts appear only on hovering an icon.
2. The boxes are named the other way round from their columns: `purchase_box` is the Export column and
   `sales_box` the Import column.
3. The destructor empties `purchase_box` but not `sales_box`.
4. The inactive marker goes 32 px to the right of the *start* of a box, so it sits on that box's second
   icon slot. It goes on the Import side when the player is the party responsible.
5. The list is rebuilt only when the count of routes changes. One route ending and another starting in
   the same frame leave a stale line (inferred from the test alone).
6. Each press of the X opens another confirmation dialog.
7. The cancel dialog reads backwards for the route's `to`.
8. Under foreign policy delegated to the AI, the Automate Trade box is forced ticked. A click still
   flips the hidden flag, which then takes effect once delegation ends.
9. Automate Trade is per machine, with no command. Under the same delegation it never shows its real
   value.
10. ACTORS is just the actor's name, a duplicate of ACTOR.
11. FormatTradeGoods ends each item with "§W " (`FINDINGS-tradeaid.md`). The message lines therefore
    probably read "Metal  per day", with two spaces. This is inferred from the record and was not
    re-read.

### A.9 What could not be settled

- **How an unfilled `$VAR$` renders.** `CInternationalizedText::Render` was followed into 0xA84E20 ->
  0xA83A20, which joins the text's pieces through each piece's slot 2. The variable piece's class was
  not found, so whether a missing variable shows its own name or nothing is not established. It does
  not matter for these messages: every variable the trade texts use is filled when that text is raised.
- **Some details of the checkbox and icon classes:**
  - what checkbox +0x100, +0xD8 and +0x136 mean. The checkbox's own input handler (0xA81D10) toggles
    +0x60 between 0 and 1. It ignores input while +0x136 is clear, and refuses to untick while +0xD8 is
    set;
  - icon slot 73 (0xAA27E0), which the constructor calls on `inactive_icon`;
  - the list's slot 30, which is given the name `production_view`.
- **Whether AddDialog repositions `DefaultConfirm`.** That is brief B's ground.

### A.10 Frontier (rvas)

- 0x405100: the route copy's destructor, receiver in ESI.
- 0x406170: the CButtonObserverGlue<CTradeItem> constructor.
- 0x6A27E0: icon slot 73.
- 0x684E20 and 0x683A20: text rendering; the variable piece's render decides unfilled variables.
- 0x23D4B0: the CEU3Dialog constructor.
- 0x681D10: the checkbox's input slot 1.

## B. An offer to the player on screen, the bar of offer icons, and where a request dialog stands (brief B)

*Addresses are virtual (based 0x400000), with the rva beside anything named. Interface files: the
install's `interface/` and `tfh/interface/`, the `tfh` copy winning where both exist. Localisation in
English, from `localisation/` and `tfh/localisation/`.*

**Corrections.** An offer to the player opens in **`DefaultDialog` of `interface/eu3dialog.gui`**, not
in either window of `diplomacydialog.gui`, for all twelve `CAsk*` dialogs (*checked by the collecting
session: `CAskTrade::CAskTrade` pushes `'DefaultDialog'` at 0x615FCA before the CEU3Dialog constructor
at 0x615FFD*). And `diplo_message` in CDiploIcon's constructor is not an animation: it is the group
string given to the icon's elements, which the in-game screen answers with the icon's tooltip.

### B.1 The dialog an offer opens - `CAskTrade` and its eleven siblings

**The window.** Every `CAsk*` constructor builds the same window, `DefaultDialog`, through
CEU3Dialog's constructor (0x63D4B0): CAskAlliance, CAskNap, CAskMilitaryAccess,
CAskOfferMilitaryAccess, CAskTrade, CAskJoinWar, CAskFaction, CAskPeace, CAskDebt, CAskLendLease,
CAskBuyLicence and CAskExpedition. `eu3dialog.gui` has no `tfh` copy.

`DefaultDialog` is 500 x 320, `orientation = CENTER`, `position = (-250, -160)`, `moveable = 1`. Its
elements:
- `Background`: `SandboxFloaterBackground`.
- `default_popup_banner` at (-7, 42).
- `Title` at (0, 53): `Arial_17`, centred, 500 x 32.
- `Description` at (100, 110): `Arial14_black`, centred, 300 x 230.
- `LeftShield` at (22, 52) and `RightShield` at (410, 52).
- `AgreeButton` at (264, 240): file text "OK", `shortcut = "ENTER"`.
- `DeclineButton` at (104, 240): file text "CANCEL", `shortcut = "ESCAPE"`.

**So an offer to the player has no slider, value, reset button, chance line or debt element.** The six
sliders exist only in the player's own trade window (`TradeDiplomacyDialog`, `FINDINGS-tradeaid.md`
A.4). The debt note is part of the description text here.

**`CTradeAction::AskPlayer`** (0xA38D20, rva 0x638D20) acts only on a PROPOSE (`type == 0`) with
`value` set. It makes a 0x70-byte CAskTrade and calls
`CInGameIdler::AddDiplomaticOffer(dialog, 3, &action->actor)`.

**`CAskTrade::CAskTrade`** (0x615FA0, rva 0x215FA0), in order:
1. CEU3Dialog's constructor. It makes the window, **shows it**, and binds AgreeButton to slot 5 and
   DeclineButton to slot 6.
2. Host at +0x68, a clone of the action at +0x6C.
3. **AgreeButton's shortcut is cleared** (`TButton::ClearShortcut`, button slot 54). This zeroes the key
   the button constructor resolved from `shortcut = "ENTER"`. All twelve constructors make this call.
   *Inferred:* Enter does not accept an offer, while Escape still presses Decline. The input dispatch
   itself was not read.
4. If the clone is not a PROPOSE, it logs "Atempted to nap proposal screen when not actually a
   proposal" (diplomacydialogs.cpp, line 711) and leaves the file's texts. AskPlayer never lets this
   happen.
5. **LeftShield** shows the proposer (the action's actor) and **RightShield** the player (the
   recipient).
6. **Description** is three pieces joined with nothing between the first two:
   - TRADEREQDESC "$COUNTRY$ is offering us a Trade Agreement. \n We would give them $TO$ each day in
     exchange for $FROM$ each day.":
     - COUNTRY = the proposer's name;
     - FROM = FormatTradeGoods(`trade_from`), what the proposer hands over;
     - TO = FormatTradeGoods(`trade_to`), what the player hands over.
   - then, only where `CCountry::NeedConvoyToTradeWith(proposer, player)`, CONV_AT_TRADE " $CONV$ would
     be responsible for the convoy needed for this trade.". The English text carries its own leading
     space. **CONV is the buyer**: `to` where `trade_to`'s money entry is non-zero, else `from`. This is
     GetConvoyResponsible inlined.
   - then `" "` + IS_BOUGHT_WITH_DEBT "Debt is used for this deal.", where
     `proposer->diplomacy[player]->allowDebts` (+0x78) **and the proposer is at war** (+0xACC).
   - Each piece is rendered on its own before joining.
7. **Title** = the action's slot 10: GetKeyPrefix "TRADE" + "TITLE" = TRADETITLE "Offer Trade
   Agreement".
8. Description is set through CEU3Dialog_SetDescription, which turns **every §W into §b**: white text
   runs become dark on this light dialog.
9. **AgreeButton** is labelled ACCEPT "Accept" and **DeclineButton** DECLINE "Decline".
10. **Growth rule:** take Title's and Description's drawn heights, from the same call the message
    popups lay out by. Where they sum to more than 400 pixels, the window gets taller by (sum - 170)
    and both buttons move down by the same amount. With the file's maxHeights of 32 and 230 this cannot
    happen, if the drawn height is capped at maxHeight. That cap was not read.

**The other eleven constructors** differ only in their texts and shields (`FINDINGS-agreements.md`
A4's keys).

**The base, `CDiplomacyDialog`** (18 slots). Against CEU3Dialog it changes or adds exactly five:

| slot | body | what it does |
| --- | --- | --- |
| 0 | 0x6147B0 `~CDiplomacyDialog` | deletes the action copy (+0x6C) **only while its IsValid holds**, then CEU3Dialog's destructor; shared by all twelve CAsk* |
| 5 | 0x60FAE0 `Accept` | bound to AgreeButton: `type = 2`, MakeCommand, posted through the host's slot 18 channel, closed (+0x64) |
| 6 | 0x60FB20 `Decline` | bound to DeclineButton: the same with `type = 1`; also what every time limit calls |
| 7 | 0x60FB60 `IsStillOpen` | two months from the action's date and IsValid, else Decline; CAskTrade overrides it (0x616D10): two months and no war, re-read and the record stands |
| 17 | 0x60FA20 `PlayOfferSound` | `diplomaticoffer`, unless it is already playing |

Nothing is checked when either button is pressed.

**`CEU3Dialog::Update`** (slot 1, 0x63D830) runs for every dialog on the idler's list, every frame:
1. If slot 7 answers false, it returns false.
2. Otherwise it keeps the window shown or hidden as slot 4 says (true for every CAsk*).
3. It answers `!closed`.

A false answer makes the idler delete the dialog.

**Where it stands, and how many can be open.**
- Nothing ever moves a CAsk* window. The window constructor works out its corner as the file's
  position plus the orientation's share of the parent's size, and the parent here is the screen.
- So the 500 x 320 window has its corner at the screen's centre less (250, 160): **it is centred on the
  screen**.
- Opening an icon (CDiploIcon::OnClick) shows the dialog, raises it (window slot 11, *inferred*), and
  adds it to the idler's dialog list (CEU3Idler::AddDialog).
- No offer dialog limits the others: **any number can be open at once, all at the same centred spot**,
  each running its own clock.
- The player's own request dialogs are different: the view keeps one at +0x518, and a second closes the
  first (agreements B.4).

### B.2 The bar of offer icons

**`CInGameIdler::AddDiplomaticOffer`** (0x674EF0) is re-read and the record stands. If the local
player's popup byte (+0x28) is clear, the dialog is deleted and the offer is lost with no reply.
Otherwise it calls DiploIconBar_Add.

**The bar** is a 0x20-byte struct at CInGameIdler +0x1D38, made as the in-game screen is built:
- +0: its window `diplomessageicons_window` (also kept at +0x1D34). `interface/menubar.gui`: position
  (340, 80), size 380 x 48, no background.
- +4..+0x10: a list of icons, **appended at the tail**.
- +0x18: the screen clock when the bar was made.

**`DiploIconBar_Add`** (0x61A1D0):
1. Builds the CDiploIcon.
2. Appends it.
3. Lays the bar out.
4. Plays the dialog's `diplomaticoffer` sound. Every new offer sounds, unless the sound is already
   playing.

**Each icon** (`CDiploIcon::CDiploIcon`, 0x619720) is the window `diplomessageicon_entry_window`
(20 x 48), with these elements:
- `diplomessageicon_button` at (14, -21), sprite `GFX_diplo_message_icons`. **Its frame is the kind**
  (button slot 18), one-based. Their Finest Hour's sprite has 13 frames; the base game's has 11,
  without the two lend-lease kinds.
- `flag`, an instant text box at (18, -2), set to `@` + the proposer's tag, which **draws the
  proposer's flag**.
- `messageicon_bg_overlay` at (23, -1). The constructor calls an unread slot 76 on its picture.

The constructor also does these things:
- binds the button's plain click to `OnClick` and its **right click to `OnRightClick`**;
- **hides the icon's window and the dialog**;
- stamps `shown_at` = now, `blink_from` = now + 120 h, `expires_at` = now + 168 h, in game hours;
- tags the window and every element with the group string **`diplo_message`**.

**Placement** (`DiploIconBar_Layout`, 0x61C5A0, and the same rule every frame in
`DiploIconBar_Update`, 0x619E80):
- The bar's window stands at the positionType `diplomessageicon_start`, (340, 80), from the screen's
  upper-left.
- Its attached children are cleared, then the icons are walked oldest first with x = 0.
- An icon with x <= the bar's width (380) goes at ((its width + `diplomessageicon_offset`.x) x n, 0),
  with n counting from 0. With the files' 20 and 20 that is **40 pixels apart**.
- Each placed icon is attached as `diploicon_<n>`, shown, and marked laid out.
- Every icon, placed or not, adds width + offset to x.
- So **at most ten icons show**. The oldest is leftmost and newer ones follow to the right.
- An eleventh stays hidden until an older one goes, and the rest close up leftwards when one is
  removed.
- The offset's y is read and never used. *Inferred:* the icon's position is relative to the bar
  (9 x 40 + 20 = 380, the bar's width).

**Blinking** (`CDiploIcon::Update`, 0x619BF0):
- It applies to a placed icon while blink_from < now < expires_at, i.e. from 120 h to 168 h after it
  appeared.
- Its button's alpha is **0.1 when (int)(t x 10) % 5 == 0, else 1.0**. t is the screen clock less the
  bar's start, seconds *inferred*. So the icon dims for one tenth of every half-period.
- The time limit counts game hours, so a paused game never declines anything.

**The tooltip** (`DiploIconBar_GetTooltip`, 0x61A340). The in-game screen's element-tooltip slot
answers any element tagged `diplo_message` with this function. It finds the icon whose button or flag is
under the mouse; the overlay gets nothing. Then it switches on the kind.

The text is DIPLOICON_TIP "$TYPE$ from §Y$NATION$§W. \n If we do not respond before §Y$DATE$§W we will
autodecline.":
- NATION = the proposer's name.
- DATE = FormatHourDate(`expires_at`), `" %d:00, %d %s, %d"`, with a leading space.
- TYPE by kind:

| kind | TYPE |
| --- | --- |
| 1 peace | ICON_PEACE - **in no localisation file, shows as the key** |
| 2 alliance | ICON_ALLIANCE "An §Yalliance§W offer" |
| 3 trade | ICON_TRADE "A §YTrade Offer§W" |
| 4 access asked | ICON_ASKMIL "A request for §YMilitary Access§W" |
| 5 access offered | ICON_OFFACC "An offer of §YMilitary Access§W" |
| 6 call to arms | ICON_CALLALLY "A §YCall to arms from one of our allies§W" |
| 7 NAP | ICON_NAP - **in no localisation file, shows as the key** |
| 8 faction | INVITEFACTIONTITLE "Invite to Faction" (also when asked to join) |
| 9 expedition | ICON_EXPEDITION "Expeditionary Force" |
| 10 licence | ICON_LICENCE "Production Licence Inquiry" |
| 11 debt | ALLOWDEBTTITLE "Allow Debt" |
| 12 / 13 lend-lease | ICON_LEND_LEASE "§YLend Lease Request§!" / ICON_LEND_LEASE_OFFER "§YLend Lease Offer§!" |

**A trade alone has a delayed half**, TRADE_TOOL_REQDESC "$COUNTRY$ would like $TO$ each day in
exchange for $FROM$ each day.":
- COUNTRY = the proposer;
- TO = FormatTradeGoods(`trade_to`), what the player gives;
- FROM = FormatTradeGoods(`trade_from`).

**Clicks:**
- **Left click** (`OnClick`, 0x619D80): the dialog is shown, raised and handed to the idler. The icon
  gives up its dialog and is dropped on the next frame. From then on the dialog's own slot 7 is the
  only clock: two months from the action's date, or 7 days for an alliance.
- **Right click** (`OnRightClick`, 0x619E60): **the offer is declined at once**, as if Decline had been
  pressed. The icon and its dialog are deleted on the next frame.

**What removes an icon:** a left click, a right click, or 168 h after it appeared, when Update calls
the dialog's Decline. A lapse posts a DECLINE that the proposer is told about. Nothing removes an icon
because the offer became impossible; only an opened dialog tests war (CAskTrade::IsStillOpen).

### B.3 Where the player's own request dialogs stand

`DiplomacyView_OpenActionDialog` (0x78B9D0):
1. Looks up the positionType `diplo_request_pos` through the gui. Both copies of
   `country_diplomacy.gui` give (10, -100).
2. Adds half the screen's width and height to it. The halves are integer, truncated.
3. Calls the dialog's slot 8, `CEU3Dialog::SetPosition(x, y)`, then slot 9 (BringToFront),
   CEU3Idler::AddDialog, and keeps the dialog at view +0x518.

The trade window (0x78BC90) and the standard window (0x78BE83) both reach this common tail at
0x78BEA4.

Slot 8 calls the window's slot 42, `CFixedWindow::SetPositionXY`, which packs the two shorts and calls
slot 6, `CFixedWindow::SetPosition`. **SetPosition puts the window's upper-left corner at (x, y) pixels
from the screen's upper-left, with no orientation applied.** It stores the pair at +0x240 and hands the
render node (screen width / 2 + x, screen height / 2 + y). That is byte for byte the transform the
window constructor applies to the corner it works out from the file, and the constructor's UPPER_LEFT
case adds nothing to the file's position.

**So the maintainer's measurement is confirmed.** The player's own request dialog's corner stands at
**the screen's centre plus (10, -100)**, on 1920 x 1080 at (970, 440). Both `TradeDiplomacyDialog` and
`DefaultDiplomacyDialog` say `position = (300, 0)` in the file, and that is overwritten before the
dialog shows.

### B.4 What looks wrong but is what the bytes do

1. An offer opens in eu3dialog.gui's generic `DefaultDialog`, centred on the screen, while the player's
   own requests open in diplomacydialog.gui's windows to the right of the centre.
2. The offer dialog's title is the proposer's button text: TRADETITLE "Offer Trade Agreement", over a
   text saying they are offering it to us.
3. The debt note is tested on the proposer alone (allowDebts toward us and at war with anybody),
   whoever actually pays.
4. ICON_PEACE and ICON_NAP have no localisation, so those two icon tooltips read the raw key.
5. Kind 8 says "Invite to Faction" both when we are invited and when we are asked to accept a member.
6. The tooltip's date has a leading space after its §Y. It is the icon's 7-day expiry, which stops
   applying once the dialog is opened.
7. **A right click declines immediately, with no confirmation.**
8. Accept's Enter shortcut is unbound, but Decline keeps Escape (inferred).
9. **Icons beyond the tenth are never shown but still expire**: after seven days they are declined for
   the player unseen.
10. Any number of offer dialogs can be open, stacked exactly on one another.
11. The dialog's destructor deletes its action copy only while it is valid. An invalid copy is leaked.

### B.5 What could not be settled

- Whether a text box's drawn height is capped at its `maxHeight`. That decides whether CAskTrade's growth
  rule can ever fire.
- That window slot 11 raises the window above the others: the render node's slot 32/29 pair was not
  read.
- The input layer's use of a button's +0x74/+0x78. That the Enter key is disabled rests on the
  constructor's fill and slot 54's clear.
- The overlay's slot 76 call in CDiploIcon's constructor.
- That an icon's position is relative to the bar: inferred, not read in the render node.
- The unit of the blink clock: CInGameIdler +0xA88, seconds inferred.

### B.6 Frontier (rvas)

- `0x23DA80`: CEU3Dialog slot 16, which hands the window's slot 30 a group string.
- `0x6C11D0`: CFixedWindow slot 11.
- `0x65EC50`: the render node's slot 51, the position.
- `0x6C3550`: CFixedWindow slot 25, SetSize.
- `0x23D980` / `0x23DA00`: the AgreeButton / DeclineButton getters.

## D. The aid screens: the lend-lease window, the licence and share-technology dialogs (brief D)

*Read 2026-10-13 in the aid screens wave. Addresses are virtual (based 0x400000), with the rva beside
anything named. Interface files: `tfh/interface/lendlease.gui`, `tfh/interface/country_production.gui`,
`interface/diplomacydialog.gui`, `interface/share_technology.gui` and `interface/eu3dialog.gui`. Amounts
are thousandths unless said otherwise. The rules behind these windows are `FINDINGS-tradeaid.md` C.*

**Corrections to the record.**
- `LicenceDialogRow_BuildTooltip` was recorded as answering "for the element `counter_type`". The
  dialog's slot 3 does the opposite: `counter_type` gets an **empty** tooltip and every other element of a
  row gets the row tooltip (D.6). *Checked by the collecting session: the string compare ends in
  `je 0x77B511` at 0x77B497, taken on equality, before the `'tech_list'` lookup.*
- `CEconomySlider::Update` shows a slider's `limit` marker only when the setting's slot 11 answers **more
  than** nought (`fcompi` then `ja`, 0x7F08C5-0x7F08D6), not "nought or more" as
  `FINDINGS-countryviews.md` section 2 and two record comments said. On the lend-lease slider GetLimit
  answers exactly 0 when the country gives no lend-lease, and the marker is then **hidden**. *Checked by
  the collecting session.*
- `0x507500` is a VA (rva `0x107500`). `0x507CE0` is also a VA (rva `0x107CE0`) and is the
  already-recorded `CCountry::GetCategorySharedWith`: the category of the sharer's first sharing entry
  that names the receiver, or null. Its two callers are the diplomacy row builder (0x4E45BD) and
  `CShareTechnologyAction::GetDialogText` (0xA4BF50). **The share dialog does not use it.**

### D.1 In one line

- **The lend-lease window lists everyone the player gives lend-lease to**, in the order the lend-lease
  began: the receiver's flag and name, a slider and the IC that slider is worth. The sliders are
  **percentages kept summing to 100**; moving one posts the whole set, at most once a second; a row's X
  asks for confirmation, then ends that receiver's lend-lease. The window has no tooltips, and while it
  is open **nothing on the production screen has one**.
- **The licence dialog's rows** are each listed type's counter and **the seller's current model name in
  brackets**. A row is greyed out where the buyer lacks the manpower for the order. Its tooltip is the
  type's name, or the manpower shortfall, with **the seller's version's stat block** in the delayed half.
- **The share-technology dialog** lists the theories the recipient is behind in, with "Our" level in green
  and "Their" level in red. Clicking a row chooses it; clicking it again un-chooses it. It has **no
  tooltips at all**, and its rows are never refreshed while it is open.

### D.2 What opens the lend-lease window: the slider's "Distribute" button

The production screen's lend-lease slider is a `domesticpanel_slider` like the other five
(`FINDINGS-countryviews.md` section 2). Four things are its own:
- **`title`** = DISTRIBUTE_LENDLEASE "Lend-Lease" (slot 6).
- **`need`**, the text over `ic_need_button`, = DISTRIBUTE "Distribute". This is slot 1,
  `CDistributeLendLease::GetNeedText` (0x5189B0, rva 0x1189B0), which never reads the share, so no figure
  appears.
- **`value`** is the slider's IC to two places and is always white (slot 2).
- **The `limit` marker** sits at GetLimit's figure: TotalIC x GetMaxLendLeaseFraction, in whole IC, on a
  slider that runs from 0 to TotalIC. It is **hidden when the country gives no lend-lease**.

Pressing **`ic_need_button`** runs `CEconomySlider::OnNeedButton`. Lend-lease's slot 7 is `ReturnTrue`,
so the button calls slot 8, **`CDistributeLendLease::OpenWindow`** (0x518BA0, rva 0x118BA0): from the
setting's country to the interface host to views[1] (the production view); if that view is on screen it
**tail-jumps to the window's Show** (slot 2). So the button never pins the slider to a need the way the
other five do; every press opens the window, or rebuilds it if it is already open.

**Tooltips on the slider** (`FINDINGS-productiontooltip.md` section 4): the lend-lease share's slot 5 is
empty, so the slider's tooltip text is empty; the knob still gets SLIDER_LOCKED_TOOLTIP or
SLIDER_UNLOCKED_TOOLTIP as its delayed half. `ic_need_button` has no tooltip of its own.

### D.3 The window (`lendlease_distribution_window`, `CLendLeaseDistribution`)

**The object.** One 0xA4-byte `CLendLeaseDistribution` is made by CProductionView's constructor and kept
at **CProductionView +0x31C**. Its window is built hidden (`BuildWindow`, 0x455550). `close`
(GFX_button_128wide, CLOSE "Close") is bound to `OnClose` (0x456960), which only hides the window. The
production screen's hide also hides it.

**The file.** 500 x 500, `Orientation = CENTER`, `position = (104, -232)`, `moveable = 0`, no background
of its own: `detail_background` (GFX_bg_lendlease) at (3, -38); `country_list`, a list box at (28, -32),
348 x 413, spacing 0, `standardlistbox_slider`; `close` at (138, 385). Nothing in code moves the window.
*Inferred:* its parent is the screen, which puts its corner at the screen's centre plus (104, -232).

**Show (slot 2, `CLendLeaseDistribution::Show`, 0x455610)**, on every press of "Distribute":
1. It clears +0x48, shows the window and raises it (window slot 11, *inferred*).
2. **It keeps the locks.** Before emptying `country_list`, it collects the receiver of every row whose
   slider knob is **locked** (knob slot 44 answering 3; the file says `lockable = yes`). After rebuilding
   it locks those receivers' sliders again (knob slot 47).
3. It empties the list, then walks **the played country's lend-lease list (CCountry +0x6B8) in order** -
   the order the lend-lease to each receiver began. Each entry becomes one `CLendLeaseItem` row.

**A row**, window `lendlease_country_entry` (32 x 59):

| element | what it is set to |
| --- | --- |
| `lendlease_entry` (GFX_lendlease_entry) | the file's picture; never named in code |
| `flag` (GFX_minishield, at (8, 15)) | the receiver's flag |
| `country_name` (Arial14, (50, 9), fixedsize, max 175) | the receiver's name |
| `actual_slider` (at (51, 33), 180 x 16, range 0-100, step 0.01, lockable) | **the entry's weight / 1000**, as floor((w/1000 + 0.0005) x 1000) thousandths - a new receiver's weight of 500 shows as 0.5. Locked again if it was locked before the rebuild |
| `actual_IC` (Arial_17, centred, (233, 22)) | empty at Show; Update fills it every frame |
| `cancel` (GFX_production_cancel_button, (310, 14)) | opens the cancel prompt (D.5) |

**Update (slot 4, 0x455CE0)**, every frame the window is shown, from CProductionView::Update at 0x7FEAC4:
1. **If the list's row count differs from the number of lend-lease entries**, it hides the window and
   Shows it again, which rebuilds the rows, and does nothing else that frame.
2. Otherwise it **keeps the sliders summing to 100**: `sum` = the sum of all slider values; `free` = the
   rows whose knob is not held by the mouse (knob state 1, 4 or 5), not locked (3) and not moved this
   frame (the scrollbar's +0x252 latch, read and cleared here); `left = 100 - sum`. Where `free > 0` and
   |left| > 0.005, every slider that is neither held nor locked gets **left / free added**; when |left| is
   under 0.01, a step of +-0.01 is spread instead. The spread is by **equal amounts, not in proportion**:
   weights of 1% and 3% open as 49% and 51%.
3. It fills **`actual_IC`**: L = the lend-lease slider's IC, base_percentage x factor (48.15 fixed point)
   as thousandths, times TotalIC, floored at 0; each row shows **floor((slider / 100 + 0.0005) x 1000) x
   L / 1000, to three places, truncated**. It ignores the route's effectiveness and the giver's resource
   cap.
4. If +0x48 is set, it hides the window. No writer of +0x48 was found.

**What moving a slider posts.** While the window is shown, CProductionView::Update calls
**`AnySliderMoved`** (0x456480) once a frame (0x7FE3B5). It reads and clears each row's moved latch until
it finds one that was set; only `CScrollbar_MoveBy` sets that latch, and only for a player's move. If one
was set, **CProductionView +0x325** is set. Once a wall-clock second has passed since +0x328 (the same
gate as the production sliders), +0x325 is cleared and **`SendDistribution`** (0x4565A0) runs: two
vectors in row order, the receivers and **floor((slider + 0.0005) x 1000)** - percentages in thousandths,
100% being 100000 - in a **CChangeLendLeaseDistributionCommand(the played country)**, posted. Its Execute
writes each weight as given; the giver's share is weight / sum of weights, so only the ratios matter.

**Tooltips.** CProductionView::BuildTooltip asks its open dialogs in a fixed order (+0x318, +0x300,
+0x314, +0x310, **+0x31C**, +0x308 and so on) and hands the hovered element to the first one shown, via
its slot 6, **whatever the element is**. The lend-lease window's slot 6 is the folded **EmptyTooltip**
(0x776F20). So **while the lend-lease window is open, every element of the production screen has an empty
tooltip**, unless one of the four dialogs checked before it is also open.

### D.4 A row (`CLendLeaseItem`, 0x456AB0)

0x30 bytes: a CStandardlistboxItem with its window at +0x20 and the receiver at +0x28. **RTTI gives it no
virtual of its own**, so clicking a row does nothing and a row has no tooltip.

### D.5 `cancel`: the prompt, and what it posts

`OnCancelClicked` (0x456970) finds the row whose window holds the pressed button and makes a
**`CCancelLLPrompt`** (0x454F80) for that row's receiver. Nothing is tested, so every press opens another
prompt. The prompt is the `DefaultConfirm` window (A.5): **Description** = CANCEL_LL_PROMPT "Are you sure
that you want to cancel lend-lease to §Y$TARGET$§!?", TARGET the receiver's name, set with the plain
SetText; **no title**; the file's OK "Ok" (Enter) and CANCEL "Cancel" (Escape); **centred on the screen**,
corner = (screen width/2 - its width/2, screen height/2 - its height/2), halves truncated.

**OK** (`OnAgree`, slot 5, 0x4551F0) posts **CRemoveLendLeaseCommand(country = the played country, target
= the receiver)** and closes. Cancel just closes. Execute ends the lend-lease (which also scraps the
receiver's lend-lease convoy); the receiver, if played, is told LENDREVOKE; the giver is told nothing.

### D.6 The licence dialog's rows (`LicenceDialog`, `tech_list`, `CTechMember`)

**Which types, in what order.** BuildUnitList's rule is recorded (`FINDINGS-tradeaid.md` C.2). The rows
follow **the unit-type database's order**, one `CTechMember` per type that passes. The comparison it
makes for a type both countries can build uses **`MakeCountrySubUnitDefinition`** (0x507500, rva
0x107500) on each country: a throwaway sub unit of the type with every technology the type lists at
**that country's current level**, applied, and the resulting definition copied out. So "the buyer's
version scores no higher than the seller's" compares the type's figures **at each country's levels
today**. The four builder windows use the same function.

**A row** (`CTechMember::CTechMember`, 0x778B30), window `prod_share_entry` (500 x 21); the buyer is the
action's actor and the seller its recipient:

| element | what it shows |
| --- | --- |
| `select_frame` (checkbox, GFX_select_prod_licence) | the row's selector. **Disabled** where the buyer's manpower is below what the order needs |
| `counter_type` (icon, at (10, -22)) | the sprite `GFX_counter_<type key>` where the gfx database has one; otherwise the file's GFX_temp_unit_icon |
| `name` (Arial12, (60, -4), fixedsize, max 250) | where the **seller** has a current model of the type: **"(§Y" + the model's name + "+*" + "§W)"**, the "+*" dropped where that model is also the one the seller's levels match exactly (`CHistoricalModelSet::FindCurrentModel`, 0x5831B0, the same rule as LICBUYACCEPT's NAME). **Only the bracketed model is shown, not the type's name.** With no model, the type's name |

**Manpower.** One unit's manpower is build_cost_manpower x max(1000 + the buyer's
build_cost_mp_by_unit_type, 1/20) / 1000. The constructor disables the box where the buyer has less than
one unit's worth; every frame `CTechMember::Update` (slot 8) compares against **one unit's manpower x
serial x parallel**, disabling the box where manpower is below it and enabling it where it is above;
equal changes nothing. A disabled checkbox ignores clicks. AgreeButton is held to the same total.

**Selecting a row.** `select_frame`'s click calls `CLicenceTechnologyDialog::SelectRow` (0x77B9D0):
every **other** row is deselected (box unticked unless its +0xD8 is set and +0x136 clear, and the
action's type reset to the null definition); then **the dialog's chosen type (+0x134) and the action's
Subunit (+0x28)** are set to this row's type. Clicking the chosen row again lets its checkbox untick
itself while the type **stays chosen** (*inferred*).

Refresh is meant to run only when the offered money (+0x12C) or the AI's score (compared with +0x130)
changes. **Nothing ever writes +0x130**, so in practice Refresh - and the AI's Lua score with it - runs
**every frame**, and BUYLICENCENEWDESC's TYPE follows a click at once.

**The row's tooltip.** The dialog's slot 3 (`CLicenceTechnologyDialog::BuildTooltip`, 0x77B400): an
element named **`counter_type` gets an empty tooltip**; any other element is looked for in the rows and
the first row holding it answers; elements outside the rows get an empty tooltip. The row's answer
(`LicenceDialogRow_BuildTooltip`, 0x779620): **text** - where the box is disabled, BUYLICENCE_MPCOST "We
lack the $COST$ necessary manpower" with COST = **one unit's** manpower / 1000 to one place, otherwise the
type's name; **delayed half** - always **the seller's version of the type** through
`CSubUnitDefinition::BuildStatsTooltip` (`FINDINGS-techtext.md` section 6), no prefix and no plus signs.

**The rest of the window**, none with a tooltip: **Title** BUYLICENCETITLE "Buy Production Licence";
AgreeButton ACCEPT "Accept" and DeclineButton DECLINE "Decline"; LeftShield the buyer, RightShield the
seller; `serial_label` and `paralell_label` keep the file's PW_SERIAL "Serial" and PW_PARALELL
"Parallel"; `serial_value` / `paralell_value` the counts in decimal; `money_icon` a plain picture.
**Position**: the screen's centre plus (10, -100), as B.3 - the licence dialog reaches the SetPosition
call via 0x78BC74 to 0x78BEBB.

### D.7 The share-technology dialog (`ShareTechnologyDialog`, `CShareTechnologyDialog`)

**The window** (`interface/share_technology.gui`, 520 x 500, file position overwritten as in B.3):
**Title** SHARE_TECHTITLE "Share Technology"; LeftShield the sharer, RightShield the recipient;
AgreeButton ACCEPT "Accept", DeclineButton DECLINE "Decline". **Description** (at (21, 370), Arial12_bold,
centred): with nothing chosen TS_NO_SELECTED "Select a technology category to share. The receiver will use
your ability in the field to boost their own research.\nWill automatically cancel if they no longer are at
a lower level.", Agree disabled; with a row chosen TS_SELECTED "Accept to share your level in §Y$TECH$§W
with §Y$COUNTRY$§W. This costs §Y$COST$§W diplomatic point and uses §Y$LEADERSHIP$§W leadership.", Agree
enabled. The column headings keep the file's texts: `tech_name_label` TS_TECH "Research", `our` TS_OUR
"Our" (x 335), `their` TS_THEIR "Their" (x 360).

**The rows**, in **the technology database's category order**, one per theory the recipient is behind in.
Each row (`CCategoryItem::CCategoryItem`, 0x78FE70) is window `share_tech_category_entry` (500 x 30):

| element | what it shows |
| --- | --- |
| `select_frame` (checkbox, GFX_unit_banner2) | the selector; never disabled |
| `tech_icon` (at (37, -1)) | sprite `icon_<category key>` where one exists, else the file's GFX_temp_unit_icon |
| `info` (at (77, -1)) | the category's name |
| `our_ability` (at (270, -1)) | **§G** + the actor's own level / 1000, whole number |
| `their_ability` (at (300, -1)) | **§R** + the recipient's level (its own, or its sharer's where higher) / 1000, whole number |

**Selecting** (`CCategoryItem::OnClicked`, slot 4, 0x790330): **an unchosen row** - the previous choice is
deselected, this row becomes the dialog's choice (+0x68), the description refreshes; **the chosen row** -
the choice is cleared, the box unticked, the description back to TS_NO_SELECTED and Agree disabled. Agree
writes the chosen category into the action and posts it. Decline posts nothing, rebuilds the view's
action list and closes.

**Never refreshed**: the dialog's slot 1 is a bare `jmp CEU3Dialog::Update` (0x7912A0), and CCategoryItem
has no per-frame slot. **No tooltips**: the dialog's slot 3 is CEU3Dialog's own **EmptyTooltip**.

### D.8 What looks wrong but is what the bytes do

1. The lend-lease window shows weights / 1000 as percentages, then pushes them to sum 100 by **equal**
   amounts, so unequal weights open looking different from the real shares; nothing is posted until the
   player moves a slider, and then the whole displayed set is posted.
2. A slider moved with its arrows takes part in the same frame's spreading, so part of the move is spread
   back onto it; with one receiver the slider cannot move from 100.
3. `actual_IC` ignores the route's effectiveness and the resource cap.
4. While the lend-lease window is open, the whole production screen loses its tooltips.
5. Each press of a row's X opens another prompt; the prompt has no title.
6. The "Distribute" button never pins the slider; the limit marker is hidden for a country with no
   receivers.
7. A licence row's `name` shows only "(Model)" or "(Model+*)", never the type's name.
8. The licence row's tooltip is on every row element except the counter picture.
9. BUYLICENCE_MPCOST quotes one unit's manpower, while the greying-out tests serial x parallel units.
10. Clicking the chosen licence row unticks it while the type stays chosen; clicking the chosen share row
    un-chooses it.
11. The licence dialog's Refresh runs every frame.
12. The share dialog shows "Their" in red and "Our" in green as whole levels and never refreshes them.

### D.9 What could not be settled

- What sets CLendLeaseDistribution +0x48.
- The scrollbar's clamp on a programmatic set above its maxValue of 100.
- Which knob states 1, 4 and 5 are, taken from `CEconomySlider::IsHeld`'s record.
- The window's parent (inferred the screen).
- The tail of `SetDistribution`'s append loop (recorded `inferred`).
- Whether a checkbox click on a chosen licence row unticks it (rests on A.9).

### D.10 Frontier (rvas)

- `0x55460` / `0x55490`: CLendLeaseDistribution's deleting destructor and destructor.
- `0x3E0E80` / `0x3E36A0`: slot 3 (hide) and slot 5 (is shown), shared with CConvoyDetails / CConvoySettings.
- `0x349390`: CEU3Dialog slot 2.
- `0x1A38A0`: CSubUnitDefinition slot 6, the type's name.
- `0x1ADB60`: the ship sub unit MakeCountrySubUnitDefinition builds.
- `0x681AA0`: the checkbox refresh after an enable or disable.
- `0x56C20`: the lend-lease vector copy.

New trap-2 pairs: `0x456970`/`0x456AB0` (`ret 4` at 0x456AAD, then `push ebp` with no padding) and
`0x518BA0`/`0x518BD0` (bare `ret` at 0x518BCF, then GetLimit's `push ebp`). And a decompiler trap: Ghidra
decompiles `0x7912A0`, a 5-byte `jmp CEU3Dialog::Update`, as that update's whole body.

## E. Lend-lease's IC, exactly (brief E)

*Read 2026-10-13 in the aid screens wave. It builds on `FINDINGS-tradeaid.md` C.3, which read the actions,
the eligibility and the route. Addresses are virtual, with the rva beside anything named. Amounts are
thousandths of IC unless said otherwise. "Fixed 15" is `fpml::fixed_point<__int64,48,15>` (the "48.15" of
C.3): 32768 is 1. Every `>> 15` is an arithmetic shift, so it rounds **down**; every `/ 1000` is the
signed 64-bit divide (`0xB99980`), so it truncates toward zero. No savegame was an oracle: none of the
maintainer's saves holds a `lend_lease_from` or `lendlease_targets` key.*

**Corrections to the record:**
- `CCountry +0x608`'s comment said the value comes from "the goods pool at +0x6D8". It comes from
  `lend_lease_income (+0x6E8) / 1000`; the `lea edi, [ebx+0x6d8]` after the write sets up the clearing of
  yesterday's receipts. *Checked by the collecting session: 0x4F14AC-0x4F14C1 divides `[ebx+0x6E8]` by a
  thousand by the magic multiply and adds it to `+0x604`; 0x4F14D0 stores it at `+0x608`.*
- `FINDINGS-buildqueue.md` section 3 read production only "where the country has no IC from lend-lease".
  The other path is E.3.
- Production's `+0x28` is zeroed at the top of every pass (`0x519D23`), so it is that day's figure.
- `FINDINGS-distribute.md` section 5 measured, without reading it, that consumer goods converts before it
  multiplies. It does: E.3.
- A new convoy's lend-lease efficiency starts at **1000**, not 0 (*checked: `mov [esi+0xAC], 0x3E8` at
  0x4C518D*). `GetResourceLimitedIC` is now read whole.

### E.0 In one line

- **The giver** sends `floor(share x TotalIC x 1000 / 32768)` thousandths a day, split by weight and scaled
  by each route's effectiveness. Its receivers are paid one at a time in its list order, each only if the
  giver's stockpile can still pay for that receiver's whole amount.
- **The receiver** turns the whole IC of what it holds into IC that needs no resources, in its daily
  `UpdateIC`, after its own resource cap. The fraction below 1.000 carries to the next day.
- **The five other shares** each take their own share of that free IC. Production spends it first, line
  by line, with no resource check. Consumer goods, supply and upgrade subtract it from their one resource
  bill. Reinforcement uses it up brigade by brigade. **The receiver's own lend-lease share of it is used by
  nobody.**
- **A sea route's convoy belongs to the receiver.** It is manned only by the receiver's
  `DistributeConvoyShips`, at the tail of the "last" list: first to be emptied, last to be filled. Its
  efficiency is the route's effectiveness.

### E.1 The giver - `CDistributeLendLease::Distribute` (0x518800, rva 0x118800)

**What it is given.** The daily share loop (`RunCountryDailyPass` at `0x4DB4F3`) calls each of the six
shares with `available = (__int64)TotalIC << 15` and `flag = 0`. TotalIC is whole IC, after this country's
own resource cap and with any lend-lease it received already added. Lend-lease is index 0, so it runs first
of the six, after the giver's own `UpdateIC`. `base_percentage` (`+8`) is the slider's share, fixed 15;
`factor` (`+0x10`) is fixed 15, set to 1.0 by the constructor.

    total = ((base_percentage * available) >> 15) * factor >> 15         fixed 15, IC
    th    = (total * 0x1F40000 >> 15) >> 15                              = floor(total * 1000 / 32768)
    for each entry {receiver, weight +8, effectiveness +0xC} of the giver's +0x6B8, in list order:
        share  = GetLendLeaseShare(giver, receiver)                       weight * 1000 / sum of weights
        amount = th * share / 1000                                        truncated
        amount = amount * effectiveness / 1000                            truncated
        if amount <= GetResourceLimitedIC(giver):
            ConsumeIcResources(giver, amount)                             1 metal, 2 energy, 0.5 rare per IC
            ReceiveLendLease(countries[receiver id], amount, giver)
    *out = 0;  return out

- **`GetLendLeaseShare`** (rva `0x108620`): the receiver is matched by id; 0 where the list is empty or the
  weights sum to 0.
- **The resource check is redone for each receiver**, against what the earlier receivers' charges left. A
  receiver that does not fit gets nothing; a later, smaller one may still be paid.
- An amount of 0 still calls both functions, harmlessly. `flag` is never read; no define is read; `+0x608`
  is not read, so lend-lease IC that was itself received is passed on at full resource cost.

**`GetResourceLimitedIC`** (0x4F15C0, rva 0xF15C0; country in ESI, out on the stack, `ret 4`): the
stockpile is the exile pool where `+0x95` is set, else the acting capital's pool; `ic_resources_reserved`
(`+0x944`), never filled in this build, is subtracted from each good first;
`out = max(0, min(metal, energy * 1000 / 2000, rare * 2000 / 1000))`. Four callers: `UpdateIC`,
lend-lease, and production twice. **No other share asks it.**

**`ReceiveLendLease`** (rva `0x108900`; receiver in ESI, `ret 0xC`): finds the giver in the receiver's
`lend_lease_from_values` (`+0x6C8`, 12-byte entries {tag, id, amount}) by id, adds `amount` to that entry
and to `lend_lease_income` (`+0x6E8`). No entry means nothing is credited, though the giver has paid.

**When it arrives.** `RunDailyPass` runs the countries in database order (`0x682E03`): a giver earlier in
the database than its receiver credits it before the receiver's `UpdateIC` that day; a later giver's
delivery waits a day.

### E.2 The receiver - `UpdateIC_ResourceCapAndLendLease` (0x4F146E..0x4F15A5, rva 0xF146E)

Only when `UpdateIC` is called with `applyDailyEffects` (the daily pass); the two calls made while a game is
entered skip it, and `+0x608` keeps the 0 written at the head of the function (`0x4F0DE4`).

    limit = GetResourceLimitedIC(country) / 1000                        whole IC, truncated
    if TotalIC > limit:  ic_lost_to_shortage (+0x614) = (limit - TotalIC) * 1000;  TotalIC = limit
    ll = lend_lease_income (+0x6E8) / 1000                              whole IC, truncated toward 0
    TotalIC += ll;  lend_lease_ic (+0x608) = ll
    clear lend_lease_from_yesterday_values (+0x6D8)                     LendLeaseReceipts_Clear, 0x511E10
    if lend_lease_from_values (+0x6C8) has entries:
        +0x6D8 = a copy of +0x6C8                                       LendLeaseReceipts_AppendAll, 0x50FA80
        lend_lease_income_yesterday (+0x6EC) = ll * 1000
    else:
        lend_lease_income = 0;  lend_lease_income_yesterday = 0
    left = ll * 1000
    for each receipt of +0x6C8 in list order, while left > 0:
        left -= receipt.amount
        if left < 0:  receipt.amount = -left;  stop                    this giver keeps the remainder
        receipt.amount = 0
    lend_lease_income -= ll * 1000

- **Lend-lease IC lands after the cap**: a receiver with an empty stockpile still gets all of it.
- **The cap has no floor**: TotalIC can be cut to 0 here, although the province sum floors it at 1.
- **The fraction carries**: `lend_lease_income` keeps `income mod 1000`, credited in the receipts to the
  givers **latest in the list**.
- **"Yesterday" is a copy taken before the drain.**
- `RemoveLendLeaseSource` (rva `0x1087C0`) takes a giver's amount off the income, floored at 0.
- **`UpdateIC` does not run for a country that holds no province and is not in exile.** Such a receiver's
  income piles up unconverted.

### E.3 How the other shares use `+0x608`

Each share computes its own free part from its own share of `ll`, so the five free parts sum to (1 - the
lend-lease share) x `ll`; the lend-lease share's part of `ll` is never used.

| share | the budget | the free part | what is charged against resources |
| --- | --- | --- | --- |
| consumer goods (`0x518C50`) | each of available, pct and factor first turned into thousandths (`x * 0x1F40000 >> 30`), then `alloc = (pct_th * avail_th / 1000) * factor_th / 1000` | `thousandths((pct * (+0x608 << 15) >> 15) * factor >> 15)`, only where `+0x608 > 0` | one `ConsumeIcResources(alloc - free)` where positive. No stockpile check. A free part bigger than the bill is lost |
| production (`0x519D10`) | `pool = (pct * available >> 15) * factor >> 15`, fixed 15 | `freePool` the same with `+0x608 << 15`, fixed 15 | below |
| supply (`0x51AA80`, already read) | `thousandths(pct * available * factor)` | the same form | one `ConsumeIcResources(alloc - free)` where positive. No stockpile check |
| reinforcement (`0x51BA60`, `FINDINGS-unitdaily.md` section 4) | `thousandths(pct * available * factor)` | the same form | **per brigade**: `charge = paid - free; free -= paid` while free > 0, else `charge = paid`. No stockpile check |
| upgrade (`0x51CE60`, `FINDINGS-unitdaily.md` section 5) | as reinforcement | the same form | once at the end: `ConsumeIcResources(spent - free)` where positive. No stockpile check |

**Production with `freePool > 0`** (`0x519EE3`..`0x51A0DF`), per line after the `pool <= 0` and
`need <= 0` tests:

    base   = min(1.0, (freePool << 15) / need);  spent = base * need >> 15
    pool  -= spent;  freePool -= spent;  amount = base * 1000 >> 15            no resource check
    if base < 1.0 and pool > 0:                                                  the top-up
        r     = min(1.0, (pool << 15) / (need - spent))
        extra = r * (1.0 - base) >> 15;  want = extra * need >> 15;  this->+0x28 += want
        if GetResourceLimitedIC >= want * 1000 >> 15:
            ConsumeIcResources(want * 1000 >> 15);  pool -= need - spent
            amount += extra * 1000 >> 15;  if amount >= 999: amount = 1000     (int)floor(999.5f)
    AddProgress(amount)

- **A paid line takes its whole day's cost off the pool either way**, as on the path without free IC.
- **The free part is not resource-checked**; where the top-up is refused, the line still advances by its
  free fraction, and the pool loses only `spent`.
- **`freePool` rarely reaches exactly 0**; every later line then takes this path with `base = 0`, which is
  the other path except for the 999 to 1000 snap.

### E.4 The lend-lease convoy: who mans it, and its efficiency

**Made.** `UpdateLendLeaseRoutes` (rva `0x108C30`, hourly) makes the receiver's convoy with `CreateConvoy`.
In play it has 0 transports; only while a new game is being made is it given `GetDesiredTransports` out of
nothing. The constructor `CConvoy::CConvoy` (0x4C4F50, rva 0xC4F50) sets `lend_lease_efficiency (+0xAC) =
1000`. Straight after creating it, and every hour after, the giver's entry gets `effectiveness =
GetEfficiency(convoy)`; a new convoy answers 0.

**Manned** only by the **receiver's** `CCountry::DistributeConvoyShips` (rva `0xFD750`), in its daily pass
behind `CCountry +0x748` (`auto_maintain_convoy`, inferred in `FINDINGS-supplyconvoys.md` section 6), and
once when a game starts. A lend-lease convoy is sorted as a resource run (`0x4FD821`):
`UpdateLoadingProduction` sums `current_producing` over the area it **starts** in - the giver's capital
area; where that produces none of crude oil, metal, energy or rare materials it is **idle**. Otherwise
`GetImportance` answers 0 for it (`0x4C78D9`), so it goes to the **tail of "last"**. In the routine's order:
idle convoys give everything back; `short` = what the supply convoys lack less the free transports; "last",
tail to head, each gives back all if `short > 0` or it is under strength, else its surplus - **so the
lend-lease convoy is the first emptied**; "first" convoys give back their surplus, or everything where
under strength; "first", head to tail, fill up; "last", head to tail, fill up - **the lend-lease convoy
takes `min(wanted - transports, free)` last of all.** Escorts: `escorts_wanted x min(1, owned/wanted)`,
taken from the free ones only if attacked within 99 days.

**What it wants.** `GetDesiredTransports`: lend-lease is not trade, so `(level_max(end port's naval base) /
10 x path_count x CONVOY_PATH_LENGTH_MULT + 1)`, truncated. The end port is the receiver's capital area's
first port.

**Its efficiency** (`CConvoy::GetEfficiency`, 0x4C6B80, rva 0xC6B80):

    eff = 1000;  if desired != 0:  eff = transports * 1000 / desired     truncated
    eff = eff * lend_lease_efficiency / 1000

Not clamped at 1000. `lend_lease_efficiency` **falls** in `LoseShips` by `LL_CONVOY_EFF_IMPACT x (lost x
1000 / transports) / 1000`, floored at 0; **recovers** by `LL_CONVOY_EFF_REGAIN` a day, clamped to 1000, in
the receiver's `RunCountryDailyPass` (`0x4DABA8`), whose loop skips every removal test for lend-lease
convoys, as does `MaintainResourceConvoys`'s removal (`0x4FED18`). In Their Finest Hour (0.4 and 0.01),
losing half the transports leaves 80% and takes 20 days to recover. A convoy loaded from a save is rebuilt
at 1000.

**Timing.** A new sea route delivers nothing on its first day: the convoy is made empty and the
effectiveness is 0 in its first hour; the receiver's daily pass mans it that night; the next hour the
giver's entry gets the convoy's efficiency; the giver's following daily share is the first to send anything.

### E.5 A worked day

A giver has TotalIC 200 and a lend-lease slider of 3276/32768, two receivers at weight 500. `total` =
3276 x 200 = 655200 (fixed 15), so `th = floor(655200 x 1000 / 32768) = 19995`. Each share is 500, so
`amount = 19995 x 500 / 1000 = 9997` - on a land route 9.997 IC, charged 9.997 metal, 19.994 energy and
4.998 rare materials; on a sea route at 600, 5.998 IC. At the receiver, day 1: income 9997, `ll = 9`,
TotalIC +9, `+0x608 = 9`, `+0x6EC = 9000`, 0.997 carried; day 2: income 10994, `ll = 10`, 0.994 carried.
With the receiver's consumer goods share at 8192/32768, that share's free part on day 1 is
`floor(9 x 8192 x 1000 / 32768) = 2250`.

### E.6 What looks wrong but is what the bytes do

1. A giver's receivers are paid in list order against a shrinking stockpile; one that does not fit gets
   nothing that day, a later, smaller one may still be paid.
2. Lend-lease IC a country received costs full resources when it passes it on; its own lend-lease slider's
   share of the free IC is used by nobody.
3. Lend-lease IC is added after the resource cap; the cap itself can take TotalIC to 0.
4. Only whole IC is turned into IC; the fraction waits, so 0.6 a day turns into IC on alternate days.
5. Production snaps a line's progress from 999 to 1000 only on the path with free IC.
6. Consumer goods rounds its bill to thousandths before multiplying; a free part larger than the bill is
   lost.
7. A sea lend-lease convoy is treated as the poorest resource run: first emptied, last filled; idle where
   the giver's capital area produces none of the four resources.
8. A new sea route delivers nothing until the receiver's daily pass has manned its convoy.

### E.7 What could not be settled

- No savegame check: no save holds lend-lease.
- `factor` (`+0x10`): only the constructor's 1.0 is known.
- The two helpers behind `LendLeaseReceipts_AppendAll` (`0x511C70`, `0x5133B0`) were decompiled, not read
  off the bytes; either way the result is a copy.
- That `+0x748` is `auto_maintain_convoy`, from `FINDINGS-supplyconvoys.md` section 6.
- The reinforcement share's override of `pct x available` with `gamestate +0xD0C -> +0x110` where set
  (`0x51BB27`..`0x51BB47`), not followed.
- The no-giver branch could oscillate on an inconsistent save; not tested.

### E.8 Frontier (rvas)

`0x111C70` and `0x1133B0` (the receipts vector's assignment and range insert); `0x118F00` (the consumer
goods money helper).
