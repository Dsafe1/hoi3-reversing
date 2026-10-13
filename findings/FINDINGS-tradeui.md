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
