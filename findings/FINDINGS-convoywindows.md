# The convoy windows

*Addresses are virtual (rva + 0x400000) unless marked; fragment `convoywindows.json`. Everything is confirmed on the bytes unless marked inferred. Game text is Windows-1252.*

## 1. What there is

The production screen (`CProductionView`) owns two dialogs, created and hidden in its constructor:

- `CConvoySettings` at view +0x314, the gui window `convoy_settings`.
- `CConvoyDetails` at view +0x310, the gui window `convoy_details`.

Both are `CReloadableInterface`s:

| slot | what it does |
| --- | --- |
| 0 | Rebuild |
| 1 | delete |
| 2 | Show |
| 3 | Hide |
| 4 | Update |
| 5 | IsShown (the shared body 0x7E36A0, reading window +0x5B) |
| 6 | tooltip |

`CConvoySettings::Bind` also makes a third object, `CConvoyCreationWindow` (0x90 bytes, settings +0x44), the gui window `convoy_creation_window`, whose list rows are `CConvoyProvinceEntry`.

- The production screen's Update calls settings.Update and details.Update only while each is shown (0x7FEA6C-0x7FEA9B).
- CProductionView::Hide and HideDialogs hide both whenever the view hides.
- **None of these windows pauses the game.** No body of any of the three classes touches a pause; whatever the production screen does about pausing is unchanged.
- **The file that applies**: `tfh/interface/convoys.gui` over `interface/convoys.gui`. The only difference is one line, the base file's `horisontal = 0` on the creation window's `list`, which the code does not read (`horisontal` occurs nowhere in the convoy windows' code read here).

## 2. The production screen's list

- `convoy_button` (`GFX_convoy_button`, `CProductionView::OnConvoySettingsButton` 0x4024D0): shows the settings dialog (slot 2). Nothing enables or disables it, and nothing gives it a tooltip of its own. The text beside it is `create_convoy` (`PW_CREATE_CONVOY` "Create convoy"), and `convoys_label` is `PW_CONVOYS` "Convoys"; all static.
- `convoy_queue` (`RebuildConvoyList`, 0x7FCA30): the list is cleared and given one row for each of the country's convoys in `Convoys` order (CCountry +0xA0, the order they were made in). Then, for each entry of the country's `lendlease_distributions` (+0x6B8, 16 bytes each, receiver id at +4), the receiver's first convoy with `is_lend_lease` and `lend_lease_partner` the viewing country, if any, gets a row too. The scrollbar's position is kept. It is rebuilt only when the list's count differs from `Convoys.count` plus those found (0x7FE8xx-0x7FEA67, inside CProductionView::Update).
- **Every visible row is updated each frame** (row window +0x5B set, its slot 8).

**The row, `convoy_entry`** (`_A0xbb459920::CConvoyEntry`, 0xA8 bytes):

| element | content |
| --- | --- |
| `convoy_name` | colour + start port's name + `" - "` + end port's name. Colour is `§R` where path_count < 2, or transports == 0, or `CConvoy::IsRouteUsable` is false; otherwise `§G` where `CConvoy::GetEfficiency` >= 1000, else `§Y`. |
| `icon_supplies_mini`, `_fuel_`, `_oil_`, `_metal_`, `_energy_`, `_raremat_` | shown where the goods mask (+0x5C) has that good (indices 0, 1, 3, 4, 5, 6) |
| `num_convoys` | normally colour + transports + `/` + GetDesiredTransports; for a lend-lease row seen by the giver (partner == player) colour + efficiency percent with one decimal + `%§!` |
| `lend_lease` | shown only for a lend-lease convoy: `LEND_LEASE_CONVOYED_TO` "IC to $COUNTRY$" with `@`+owner tag where the player is the partner (the giver), `LEND_LEASE_CONVOYED_FROM` "IC from $COUNTRY$" with `@`+partner tag otherwise (the owner, the receiver) |
| `select` | enabled unless the convoy is lend-lease and not the player's (constructor only, 0x7F9674); a click opens `convoy_details` (slot 4 -> `CConvoyDetails::SetConvoy` then slot 2) |

A lend-lease convoy is the **receiver's** (`CCountry::CreateConvoy` is called for the receiver, partner the giver), so the row the receiver sees is manageable and the row the giver sees is display-only.

## 3. `convoy_settings`

Opened by `convoy_button`. Closed by `close` (`CLOSE` "Close"; the hide handler at 0x456960, tail to slot 3, shared with `CLendLeaseDistribution`) and by the production screen hiding.

**Static**: `detail_background`; labels `a_r_label` (`CDW_AUTO_RES` "Auto-Create/Destroy Resource Convoys"), `a_s_label` (`CDW_AUTO_SUP` "Auto-Create/Destroy Supply Convoys"), `a_m_label` (`CDW_AUTO_MAIN` "Auto-Maintain Convoy Transports/Escorts").

**Show** sets the three boxes from the country's `auto_resource_convoy` (+0x74A), `auto_supply_convoy` (+0x749), `auto_maintain_convoy` (+0x748). Only Show does this; Update does not touch them. A toggle therefore keeps the box's own tick until the window is next opened.

**Each box** posts its command on any change (CToggleAutoSupplyConvoysCommand and the other two).

**Update** (each frame; first runs the creation window's Update if one exists). For each province the country controls with owner id != 0, a port (+0x354) and a naval base of level_max > 0:

- `canResource` is set where its area is not the acting capital's area and that area has no convoy starting in it (`COwnerArea` +0x4..+0x8 empty).
- `canSupply` is set where the province's own convoy vector (+0x38..+0x3C) is empty.

Then `canResource` is cleared where `auto_resource_convoy` is set and `canSupply` where `auto_supply_convoy` is set. `create_resource` (`CDW_CREATE_RES` "Create Resource Convoy") is enabled iff `canResource`; `create_supply` (`CDW_CREATE_SUP` "Create Supply Convoy") iff `canSupply` and arcade_mode <= 0 (`CCurrentGameState` +0xC9C).

**Press** `create_supply` or `create_resource`: `CConvoyCreationWindow::Open(true)` or `Open(false)`. Neither hides the settings window.

**Tooltips**: slot 6 is the folded EmptyTooltip, so while the settings dialog is up the production screen's tooltips stop (section 8).

## 4. `convoy_creation_window`: choosing the ports

**Nothing on the map happens.** No map mode, no click on the map, no route drawn: the window is a list of ports and the route is made only when the command runs (`CCountry::CreateConvoy` -> `CConvoy::RebuildPath` -> `FindConvoyPath`).

`Open(supplies)`:

- +0x28 = supplies, +0x29 picking-origin = 1, +0x2C origin = null, +0x3C row-clicked = 0.
- `title` = `CDW_ORIGIN` "Select Port of Origin for Convoy" (the file's `CDW_AUTO_MAIN` text is always overwritten before it is seen).
- The list is filled.
- The window is shown (+0x18 slot 0x34) and brought up (slot 11, by the same pattern as Show on the other two; *inferred* "brought up").

**FillList** (0x7E02B0). Candidates are the country's controlled provinces, in list order (`ControlledProvinces`, +0xD00), with owner id != 0, a port, a naval base of level_max > 0, and not the origin (+0x2C). `capitalArea` means the province's area == the acting capital's area. `wanted = (carries_supplies == picking_origin)`, true exactly for a supply convoy's origin and a resource convoy's destination.

| | origin | destination |
| --- | --- | --- |
| **supply convoy** | `capitalArea` must hold | not `capitalArea`, unless the province's `supply_depot_hops` (+0x50) > `SUPPLY_SAME_AREA_DIST_CUTOFF`/1000 (10 in both installs) |
| **resource convoy** | not `capitalArea`, and the area has no convoy starting in it | `capitalArea` must hold; no further test |

A supply candidate, either end, is also refused where a non-lend-lease, non-trade convoy with supplies or fuel in its mask already ends at that province. Each passing province gets a `convoy_province_entry` row (`name` = the province's name, `select` = `GFX_create_convoy`), appended with `list` slot 4 (entry, 1) (the second argument was not read).

**Clicking a row** (slot 4): the row's province is written to the window's +0x30 and +0x3C = 1. `CConvoyCreationWindow::Update` (slot 8, run from `CConvoySettings::Update`, so only while the settings dialog is shown) then acts:

- First click (picking_origin): picking_origin = 0, origin = chosen, `title` = `CDW_DESTINATION` "Select Destination Port for Convoy", and the list is refilled.
- Second click: `CCreateConvoyCommand(origin id, chosen id, carries_supplies)` is posted, the window hidden, and row-clicked cleared.

**`cancel`**, the window's only other button, is at position 5770,580 (the file's `##todo:remove`): it cannot be reached with a mouse. The window closes by `close` on the settings dialog or by finishing; pressing a `create_*` button again restarts it. The `title` box's file text (`CDW_AUTO_MAIN`) is never shown.

## 5. `convoy_details`

**Opened** only by a row's `select`. Reopening with another row switches the convoy.

**Hidden** by `close` (`CLOSE`), by `cancel` (after posting), when its convoy disappears (Update sets +0x6C and hides it), and by the screen hiding.

**Update**, each frame while shown, in order:

| element | content |
| --- | --- |
| `convoys_running` | `CONVOYS_RUNNING` "Convoys Running: §Y$ACTIVE$/$TOTAL$§W"; ACTIVE = the owner's convoys with path_count > 1, transports != 0, `IsRouteUsable`; TOTAL = the owner's convoy count |
| `convoys_available` | `CONVOYS_AVAIL` "$TRA$ transports and $ESC$ escorts available." with the owner's free `Transports` (+0xB0) and `Escorts` (+0xB4) |
| `transports_value` | transports + `/` + `CConvoy::GetDesiredTransports` |
| `escorts_value` | escorts |
| `transports_minus`, `escorts_minus` | enabled iff the convoy has >= 1 |
| `escorts_plus` | enabled iff free escorts >= 1 |
| `transports_plus` | enabled iff free transports >= 1 **and** transports < desired |
| `from_name`, `to_name` | the two ports' names |
| `energy_value`, `metal_value`, `raremat_value`, `oil_value`, `supplies_value`, `fuel_value` | `FormatFixedPoint(daily[good], 0)` |
| the six `ship_*` boxes | enabled iff the convoy is neither lend-lease nor trade |
| `cancel` (`CANCEL_CONVOY` "Cancel Convoy") | enabled iff neither lend-lease nor trade |

`daily` is what the convoy carried at its last sailing. The goods table is 0x170AE68: `{good, box, value box}` for fuel 1, supplies 0, oil 3, raremat 6, metal 4, energy 5.

**The boxes** are set only in Show (from the convoy's goods mask, and disabled for lend-lease only in Show; Update refines it with trade). A change of any box sends all six: `CConvoyDetails::OnShipBoxChanged` builds a seven-byte array (supplies 0, fuel 1, oil 3, metal 4, energy 5, rare 6; money 2 always off) and posts one `CChangeResourcesInConvoyCommand`.

**Steppers** (`Ctrl` means 10; keyboard slot 12, `Keyboard_IsCtrlDown`):

| button | amount |
| --- | --- |
| `transports_plus` | min(step, desired - transports, free transports); 0 does nothing |
| `transports_minus` | max(-step, -transports) |
| `escorts_plus` | min(step, free escorts) |
| `escorts_minus` | max(-step, -escorts) |

Each posts `CChangeTransportsInConvoyCommand` or `CChangeEscortsInConvoyCommand`. Nothing here consults the `auto_maintain_convoy` flag.

**Static**: `detail_background`, the six goods icons, `transports_icon`, `escorts_icon`.

## 6. The commands

All go through the game's command channel, as every command does. Save tokens: `CConstructConvoyCommand` 0x4DF was already recorded; `create_convoy` 0x4DB, cancel 0x4DC, change escorts 0x4D9, change transports 0x4DA, change resources 0x4DD, toggle maintain 0x567, supply 0x568, resource 0x569 (the type ids in the constructors).

| command | fields, save keys | IsValid (slot 14) | Execute |
| --- | --- | --- | --- |
| `CCreateConvoyCommand` | +0x3C `from`, +0x40 `to`, +0x44 `supply` | folded ReturnTrue | `CCountry::CreateConvoy(countries[from.controller], from, to, supply, 0x2A, g_convoy_id++, "---", 0)` |
| `CCancelConvoyCommand` | +0x40/+0x44 `convoy` id pair | resolves | If the convoy still exists: removed from the owner's `Convoys`, `convoys_changed` set, escorts and transports back to the owner's free pools, deleted. `CConvoy::~CConvoy` takes it off every province of its path and off every owner area's starting and ending vectors. |
| `CChangeEscortsInConvoyCommand` | +0x40/+0x44 `convoy`, +0x64 `amount` | resolves, and amount > 0: free >= amount; amount < 0: convoy has >= -amount | convoy.escorts += amount; free -= amount |
| `CChangeTransportsInConvoyCommand` | as above | as above, with transports | convoy.transports += amount; free -= amount |
| `CChangeResourcesInConvoyCommand` | +0x40/+0x44 `convoy`, +0x64 `status` (7 ints) | resolves | copies the seven ints over the convoy's mask |
| `CToggleAuto*ConvoysCommand` (three) | +0x3C/+0x40 `country` | folded ReturnTrue (not read in the body; slot 14 is the same folded body as the others) | flips +0x749, +0x74A or +0x748 |

Posters, each with one caller or the handlers in section 5:

- `CCreateConvoyCommand`: `CConvoyCreationWindow::Update`.
- `CCancelConvoyCommand`: `CConvoyDetails::OnCancel`.
- The two changes: the four steppers.
- The resource change: the boxes.
- The toggles: the three checkboxes.
- The AI posts none of these (only those callers exist; the AI goes through `CCountry::MaintainSupplyConvoys`, `MaintainResourceConvoys` and `DistributeConvoyShips`).

## 7. A hand-made convoy and the automatic ones

**Nothing marks a convoy as hand-made.** Save keys: `convoys`, `daily`, `end`, `escorts`, `id`, `last_attack`, `lend_lease`, `path`, `ship`, `start`, `start_date`, `trade`, `type` (plus goods under `daily`); no flag. A hand-made convoy is made by the same `CCountry::CreateConvoy` with the same goods mask (supplies and fuel, or the four resources), and starts with no ships outside a new game. So from then on it is one of the country's convoys for `DistributeConvoyShips` and the two Maintain routines.

A hand-made convoy therefore cannot be protected from an automatic flag:

- While `auto_supply_convoy` is set, the create-supply button is dead, but a convoy made earlier is still subject to `MaintainSupplyConvoys`' unmaking (*FINDINGS-supplyconvoys.md*, section 2).
- `auto_maintain_convoy` means `DistributeConvoyShips` rebalances every convoy's ships daily, overriding the steppers.
- The windows do not grey the steppers under `auto_maintain_convoy`.

Oracle: `Ireland1938_08_03_14.hoi3` holds 444 `convoy` objects, 295 of them trade, no lend-lease in that save, and all three flags are `yes` for all 101 countries. Masks seen: `1 1 0 0 0 0 0` 98 times (supply), `0 0 0 1 1 1 1` 51 (resource). A convoy's goods mask can be edited by hand on any convoy that is neither trade nor lend-lease, so a resource convoy can be given supplies or a supply convoy resources. Nothing in the windows or commands forbids it, and `CConvoy::IsSupplyConvoy` then answers by the mask.

## 8. Tooltips

`CProductionView::BuildTooltip` answers in this order: the confirm-build dialog at +0x318, then the one at +0x300 if shown (not read here), then `convoy_settings`, then `convoy_details`, then the screen. So:

- While `convoy_settings` is up every production-screen tooltip is empty.
- While `convoy_details` is up (and settings not) only its four stepper buttons have a tooltip: `BUILD_ADD_REM_BUNDLE` "§YCtrl + LMB§! to add or remove §G$NUM$§!" with NUM = 10, literal.

Rows of `convoy_queue` give `BuildConvoyEfficiencyTooltip(row, out)` for the row the mouse is over:

- **Not lend-lease**: for each good with daily > 0, separated by spaces, `CONV_SHIP_IRO` "Ships §Y$VALUE$§W $NAME$ every day." (VALUE = daily to one decimal, NAME = the good); if none, `NO_CONVOY_SHIP` "Nothing was shipped through this convoy in the previous day."; then a space and `CONV_EFF_IRO` "With this number of transports, the convoy runs at §Y$EFF$%§W efficiency." (EFF = efficiency x 100 / 1000, one decimal).
- **Lend-lease**: `LEND_LEASE_CONVOY_DESC` (FROM = partner's country name, TO = owner's), newline, `LL_CONVOY_EFF_DESC` (PERC = efficiency x 100000 / 1000, two decimals), and under 1000 efficiency also `LL_CONVOY_EFF_LOW_DESC` (DAYS from `0xC7CE0`, not read); and where the player is not the owner, `LEND_LEASE_CONVOY_OWNER_DESC` "This convoy belongs to §Y$COUNTRY$§!, and it's up to them to manage it." as the tooltip's delayed half.

`convoy_button`, `create_*`, the `auto_*` boxes and the creation window's rows have no tooltip at all.

## 9. Keys

| key | text |
| --- | --- |
| `CDW_ORIGIN` | Select Port of Origin for Convoy |
| `CDW_DESTINATION` | Select Destination Port for Convoy |
| `CDW_AUTO_RES` | Auto-Create/Destroy Resource Convoys |
| `CDW_AUTO_SUP` | Auto-Create/Destroy Supply Convoys |
| `CDW_AUTO_MAIN` | Auto-Maintain Convoy Transports/Escorts |
| `CDW_CREATE_RES` | Create Resource Convoy |
| `CDW_CREATE_SUP` | Create Supply Convoy |
| `CANCEL_CONVOY` | Cancel Convoy |
| `CLOSE` | Close |
| `CONVOYS_RUNNING` | Convoys Running: §Y$ACTIVE$/$TOTAL$§W |
| `CONVOYS_AVAIL` | $TRA$ transports and $ESC$ escorts available. |
| `PW_CREATE_CONVOY` | Create convoy |
| `PW_CONVOYS` | Convoys |
| `PW_AVAILABLE_TRANSPORT_ESCORT` | Available transports/escorts |
| `CONV_SHIP_IRO`, `CONV_EFF_IRO`, `NO_CONVOY_SHIP`, `LL_CONVOY_EFF_DESC`, `LL_CONVOY_EFF_LOW_DESC`, `LEND_LEASE_CONVOY_DESC`, `LEND_LEASE_CONVOY_OWNER_DESC`, `LEND_LEASE_CONVOYED_TO`, `LEND_LEASE_CONVOYED_FROM`, `BUILD_ADD_REM_BUNDLE` | as above; all in `localisation` (`interface.csv`, `tfh_4_0.csv`, `tfh_4_01.csv`, `tfh_4_02.csv`, `tfh.csv`) |

## 10. Compiled in, and from the files

**Compiled in:**

- the step 10 for Ctrl and the number 10 on the tooltip;
- the row colours' thresholds (efficiency 1000 = green);
- `/` and ` - `, `%§!`;
- that `cancel` in the creation window is unreachable (a file position, so a mod could move it, and the handler would then work: it only hides).

**From the files:** the element names; the texts above; `SUPPLY_SAME_AREA_DIST_CUTOFF` (10) in `defines.lua`, both installs.

## 11. What looks wrong but is what the bytes do

1. The creation window's `title` in the file says `CDW_AUTO_MAIN`, and its `cancel` is at x=5770: neither is ever seen.
2. Clicking `create_supply` or `create_resource` leaves the settings dialog up underneath, and the creation window has no way out but finishing, restarting, or closing the settings dialog.
3. The `auto_*` boxes are read from the country only in Show.
4. The `ship_*` boxes' disabled state is set by Show from lend-lease alone, and then by Update from lend-lease or trade.
5. A convoy's `cancel` is disabled for lend-lease and trade, and a lend-lease convoy's select for the giver, but the steppers are live whenever they have something to move, including on the receiver's lend-lease convoy.
6. A hand-made convoy's stepped ships are given back every day where `auto_maintain_convoy` is set: the steppers are not greyed.
7. The value boxes read `daily`, what was carried at the last sailing, not the mask.
8. `CreateConvoy`'s owner is `from`'s **controller**, and `IsValid` is ReturnTrue.

## 12. Not settled

- What `+0x2C` on a window does after its show (slot 11; *inferred* "brought forward").
- The second argument to the list's slot 4 add.
- What reads or clears `CCountry +0x9C convoys_changed`.
- What +0x300's dialog is (not this scope).
- Whether a province's convoys vector being empty, for `canSupply`, is meant to test an unused port; that is what the code does.

Frontier: `0x3C9530` (the persistent-reference builder FUN_7C9530), `0xC7CE0` (`LL_CONVOY_EFF_LOW_DESC`'s DAYS), `0x14A200`, `0x14A580`, `0x14A900` (clones); each command's slot 7 and its prototype constructor. CConvoyCreationWindow slot 0 (0x3DFDA0) is folded with CSpyMissionEntry and left unnamed.


# The go-to box

*`CGotoBox`, by the collecting session of the same wave, off the listing; file `interface/goto.gui`. Addresses are virtual.*

`button_goto` beside the minimap brings up `goto_box` (the idler keeps the button's glue at +0xB18; the handler itself was not found, so that it only shows the box, and does not toggle, is *inferred*). The box is `moveable`. `goto_text` is `GOTO_LIST_BOX` "Possible Provinces", `goto` is `GOTO_GOTO` "Go to" and `cancel` is `GOTO_CANCEL` "Cancel". `CGotoBox::CGotoBox` (0x68FBE0) hides it and binds `goto`, `cancel` and `goto_edit`, whose text observer is 0x6906A0 and whose Enter is 0x68FE80. It keeps a chosen province at +0x9C, -1 for none.

**As the text changes** (0x6906A0). The `provinces` list is cleared and `goto` greyed. The text is lower-cased. Only with **more than one character**:

- `atoi` of the text, where it is above 0 and below the provinces' count: a row for that province, and `goto` is enabled.
- Then, with no chosen province, every province from 1 in order: its name, skipped where it **starts with "PROV"** (checked before lower-casing, on a name of at least 5 characters); the lower-cased name's first characters, as many as the text has, equal to the text: a row. A name **equal to the whole text** enables `goto`.

A row is `save_game_entry` (`CGotoProvinceItem`, 0x68FA30), the province's name on its button `game`.

**Go** (`goto`, or Enter: 0x68FE80, then 0x68FF60 with `exact` false). With no chosen province: the text lower-cased; `atoi` of it nought, the first province by number whose name begins with the text (or equals it, where `exact`) is centred on and the walk stops; otherwise the map centres on the province of that number, whatever it is. With one chosen: that province. Then the edit box is emptied and loses the keyboard, the box hidden and the list cleared.

**A row's button** (0x690FC0): the chosen province becomes the row's, the edit box takes its name, Go runs with `exact` true, and the chosen province goes back to -1. So a click on a row goes at once.

**`cancel`** (0x6905E0) hides the box and leaves the text as it stands.

Centring is the in-game screen's slot 47, `CInGameIdler::CentreOnProvinceId`: the map moves and nothing is selected. No tooltips of its own; nothing pauses.

A province of number 0x421 has a test beside it that does nothing (`String_Equals` of a string with itself), a developer's leftover.

Frontier: the handler stored in the idler's glue +0xB18.
