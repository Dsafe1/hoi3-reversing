# The ship and brigade card, and the sunk ships

The unit panel's click on a brigade row, `brigade_view` (the card), `sunk_ships_view`, the Pride of the Fleet dialog and what they post. Read out of `hoi3_tfh.exe` (TFH build, all VAs below `0x400000`-based), tagged **confirmed** (read) / **inferred** where said.

## 1. In one line

A plain click on a brigade's row in the unit panel opens a card, one per sub-unit, listing that brigade's/ship's/wing's whole statistics; a ship's card can open a list of the ships it sank and can make it the Pride of the Fleet through a confirm dialog. Nothing in them is live except two buttons; a rename goes out when the card closes.

## 2. What opens the card

**A plain click on a row's `select` button** (a `subunit_entry` in `single_unitpanel`'s brigade list) opens it. The row's button glue (`CSubUnitEntry` +0x28, 0x50 bytes, built at 0x748E50) has its slot 2 (plain click, the handler at glue +8) set to 0x67A310, `mov eax,[ecx]; jmp [eax+0x10]` - the row's slot 4, `CSubUnitEntry::OnClicked` (0x749EE0). **Confirmed** on the listing.

`OnClicked`, in order:
- nothing for a row of an upgrade in progress (+0x120, the second constructor's flag);
- resolves the sub-unit by its id pair (+0xCC/+0xD0); nothing if it is gone;
- looks the sub-unit's id up in the **in-game screen's list of open cards** (`CInGameIdler +0x20`, head; +0x24 tail; +0x28 count; 0x14-byte nodes {type, id, ...}); **if it is on it, nothing** - one card per sub-unit, a second click on the same row does nothing;
- otherwise appends the id and makes the 0xBC-byte `CBrigadeView`, handing it to `CEU3Idler::AddDialog`.

So: **any land regiment, any ship, any air wing** in the selected unit's list (the row exists for each - `FINDINGS-unitpanel.md`, section 7 - and the click asks nothing of the sub-unit or its owner). A row for an upgrade in progress opens nothing. Which button a *foreign* unit shows is the selection's business: a foreign unit cannot be selected (`FINDINGS-selection.md`, line 175), so its panel never shows; **inferred**: the only route to a card is the player's own selection. An expeditionary unit under the player is reachable and its card behaves the same (**inferred** - no separate code).

`CEU3Idler::AddDialog` (0x644670) only appends to the screen's list at +0xA0/+0xA4/+0xA8, which `CEU3Idler::Update` runs each frame (slot 1, false = delete). It has no pause. **Nothing in the three windows' classes pauses, and a selection change does not reach them**: `CBrigadeView` and `CSunkenShipsView` are `CUpdateable`s held only by that list, so they outlive the selection; several cards (one per sub-unit) can be open at once. The file's `moveable = 1` applies to both windows.

**Which file**: both `interface/brigadeview.gui` and `tfh/interface/brigadeview.gui` exist and differ in one line: the base game's `subunit_name` edit box has `format = centre` and TFH's does not; the install's `tfh` layering makes TFH's the one read (**inferred** - the layer rule, no check of which file is loaded here). The base game's and TFH's sprites for these windows (`GFX_brigade_detail_bg`, `GFX_sunk_ships_bg`, `GFX_brigade_detail_entry`, `GFX_small_button` etc. in `interface/unitpanel.gfx`, `GFX_unit_stars` 11 frames, `GFX_no_ship_selected` and `GFX_model_overlay` in `interface/country_production.gfx`) are as the files say.

## 3. The card: `brigade_view` (class `CBrigadeView`)

`CBrigadeView::CBrigadeView` (0x71F460), `new 0xBC`. Holds: closed flag +0x88; the sub-unit +0x8C and its id pair +0x90/+0x94; the window +0xB4; the screen +0xB8. Three `CButtonObserverGlue` members (0x2C bytes): `close` (+0x4 -> 0x727120, `closed = 1`), `sunk` (+0x30 -> `CBrigadeView::OnSunkClicked`), `make_pride` (+0x5C -> `CBrigadeView::OnMakePrideClicked`), each the plain click. Window at (320, 70), 1024x768.

### 3.1 What is filled, once, at construction

- **`photo`**: `CInGameIdler::SetSubUnitPhoto` (slot 77, 0x677410) with the builder's country (+0x34, the tag and id) if the sub-unit has a builder (+0x38 not 0), else its owner (+0x94), and the sub-unit. See 3.6. No model picture means it keeps `GFX_no_ship_selected` from the file.
- **`model_overlay`, `background`**: never touched; the file's. (`brigade_detail_entry` in each row likewise.)
- **`unit_experience_land`/`_air`/`_naval`**: the sub-unit's experience with pride (`CSubUnit::ExperienceWithPride` logic inline: experience, below 0 taken as 0, plus `PRIDE_BONUS_EXP` for a pride) gives the same frame as a unit-panel brigade: frame 1 under an experience of 1; otherwise `round(exp / 10) + 2`, at most 11. Which is shown: `is_land` -> `unit_experience_land` set to that frame and the other two hidden (slot 65, sticky); `is_air` -> `_air`; `is_ship` -> `_naval`. The file's `frame = 6` is always overwritten. **confirmed.**
- **`label`** (instant text box): `(§Y` + the historical model's name (`PickBestModel` on the builder's/owner's country's set for this type) + `+*` where the best model is not `FindModelOf`'s + `§W)\n`. With no model: the definition's name (its slot 6). (`CHistoricalModel_GetName`; the same model pair as the sunk row.)
- **`subunit_name`** (edit box): the sub-unit's name (slot 8); `"` refused (`0xACCFE0`, same as `unitname`); read-only (edit box +0x159 = 1) when `g_CCurrentGameState->scenario` is set. The file's edit box has no `maxChars` key at all so the limit is whatever the edit box defaults to (**not read**).
- **The list `list`** of `brigade_detail` rows (`CBrigadeStatsEntry`, 0x28 bytes: `label` and `value` text boxes; `value` is `format = right` from the file): 3.4 and 3.5. Built once; rows are never refilled, so **the card is a picture of the moment it opened** except for the two buttons of 3.2.
- **The window's slot-2/slot-3**: `0x598DB0` (returns false) and `EmptyTooltip` (0x776F20), so neither window answers the tooltip system and none of their elements has a tooltip; the file's `tooltip` fields are empty.

### 3.2 Each frame: `CBrigadeView::Update` (0x726D70, slot 1)

- Re-resolves the sub-unit from its id pair; gone -> return **false** (the idler deletes the window). A ship stays resolved after sinking, so an open card survives it (see 3.3); a regiment or wing being deleted shuts its card (**inferred** from `CGameState::DisposeSubUnit` keeping only ships).
- Asks the sub-unit's slot 10 (`0xA92590`, true, for `CShip` only; `CRegiment` and `CWing` have 0x592360, false). **Not a ship (land brigade or air wing): `make_pride` and `sunk` both hidden (button slot 14) and nothing else.**
- A ship: `sunk` is **enabled** (button slot 46) if any entry of `g_CCurrentGameState->sunk_ships` (+0x20, whole list, first match) has `sunk_by` (+0x9C/+0xA0) resolving to this ship; else **disabled** (slot 47). `make_pride`: where the definition's `can_be_pride` (+0x39) is clear, **hidden**; where set, **disabled** (slot 47) if the ship is already a pride (+0xA5), **enabled** (slot 46) if not.
- Returns "not closed" (`+0x88 == 0`).

Pressing `make_pride` needs no ownership check here: the only sub-units reachable are the player's (section 2).

### 3.3 Shutting: `close`, and the rename

`close` (plain click, handler 0x327120) sets `closed`; the window is deleted next frame. `ESC` is not bound by this window. `~CBrigadeView` (0x726AA0, `ret 4`): if the window and sub-unit still exist, takes the `subunit_name` text, trims whitespace (`TrimWhitespace`), and **if it differs from the sub-unit's current name, is not empty, and no scenario is running, posts `CRenameSubUnitCommand(sub-unit, text)`** (0x5DDD90, 0x80 bytes, through the screen's session command queue). Then removes the window and the sub-unit's id from the screen's open-cards list. **So a rename is applied when the card is closed - by any means (close button or sub-unit lost if it still resolves) - and never while it is open.** `CRenameSubUnitCommand` carries the id pair and the name; its `Execute` not read here.

A ship that sinks while its card is open keeps its id resolving (it stays on the sunk list and the id table, `FINDINGS-savedbattle.md`); the card stays open and a rename still posts (**inferred** from the two records; neither is exercised by a save).

### 3.4 The rows: `list`, in order, for every kind

Each row is label (left) and value (right, `format=right`). Values use `FormatFixedPoint(value, places)` (value / 1000, truncated, `places` decimals). Row 0 is **`UNIT_STATS`** "Statistics", value empty.

For all kinds:

| # | key (text) | value |
| --- | --- | --- |
| 1 | BV_STRENGTH "Strength" | slot 13: a regiment `FormatMen(strength)`; a ship or wing: strength to 0 places + `%` (0x5ADD80) |
| 2 | BV_EXPERIENCE "Experience" | experience with pride, 1 place |
| 3 | MAX_STRENGTH "Max Strength" | **regiment only**: `FormatMen(DefaultStrength)` (the definition's) |
| 4 | DEFAULT_ORG "Organisation" | definition's `max_organisation`, 1 place |
| 5 | DEFAULT_MORALE "Morale" | morale x 100, 1 place + `%` |
| 6 | RADIO_STRENGTH "Radio Strength" | 2 places |
| 7 | MAXIMUM_SPEED "Max Speed" | max_speed 2 places, then the KPH text with no space between (`KPH` "KPH") |
| 8 | SUPPLY_CONSUMPTION "Supply Consumption" | `CRegiment::SupplyConsumption` 2 places |
| 9 | FUEL_CONSUMPTION "Fuel Consumption" | `CRegiment::FuelConsumption` 2 places |

The definition (+0x58) is the sub-unit's, with its country's technology applied, so these are the working figures. Supply and fuel are the per-sub-unit figures including `extra_consumption`.

Then, by the definition's kind (these are the only rows that differ):

**`is_land`** (`+0x2D`): TRANSPORT_WEIGHT "Weight" (weight, 2), DEFENSIVENESS "Defensiveness" (2), TOUGHNESS "Toughness" (2), SOFTNESS "Softness" (softness x 100, **0 places**, `%`), AIR_DEFENCE "Air Defence" (2), SUPPRESSION "Suppression" (2), SOFT_ATTACK "Soft Attack" (2), HARD_ATTACK "Hard Attack" (2), AIR_ATTACK "Air Attack" (2), COMBAT_WIDTH "Combat Width" (2), AP_ATTACK "Piercing Attack" (piercing_attack, 2), ARMOR_VALUE "Armor" (armor, 2).

**`is_ship`** (`+0x2E`): RANGE "Range" (range, 0 places, then `KM` with no space), DISTANCE "Distance" (firing_distance, 1 place, then `KM`), SURFACE_DETECTION "Surface Detection", AIR_DETECTION "Air Detection", SUB_DETECTION "Sub Detection", VISIBILITY "Visibility", SEA_DEFENCE "Sea Defence", AIR_DEFENCE "Air Defence", AIR_ATTACK "Air Attack", CONVOY_ATTACK "Convoy Attack", SEA_ATTACK "Sea Attack", SUB_ATTACK "Sub Attack", SHORE_BOMBARDMENT "Shore Bombardment", HULL "Hull", POSITIONING "Positioning", TRANSPORT_CAPABILITY "Transport Capability", AMPH_INVASION_SPEED_BONUS "Amphibious invasion speed", AMPH_INVASION_DEFENCE_BONUS "Amphibious craft defence", CARRIER_CAPACITY "Carrier CAG size" (all 2 places). The key `KM` is in no csv of the install: the text is the key itself ("KM"), as for any missing key. **No range row for a wing** - a difference from the unit summary tooltip, which shows it for ships and wings.

**`is_air`** (`+0x2C`): SURFACE_DEFENCE "Surface Defence", AIR_DEFENCE "Air Defence", STRATEGIC_ATTACK "Strategic Attack", SOFT_ATTACK "Soft Attack", HARD_ATTACK "Hard Attack", TRANSPORT_CAPABILITY "Transport Capability", AIR_ATTACK "Air Attack", SEA_ATTACK "Sea Attack" (all 2 places).

A definition that is none of the three gets none of those rows. The three tests are independent `if`s in that order, not an else-chain (**confirmed**), so nothing but the data stops a definition carrying two.

Then, for all kinds:

| | |
| --- | --- |
| blank row | empty label, empty value |
| `NIGHT_ADJUSTER` "Night" | `CBrigadeView_AddAdjusterRows` on the definition's `night` adjuster |
| `FORT_ADJUSTER` "Fort" | `fort` |
| `RIVER_ADJUSTER` "River" | `river` |
| `AMPH_ADJUSTER` "Amphibious" | `amphibious` |
| each terrain | the terrain's localised name (`GetLocalisedName`), in the map's terrain order (`g_CMap->terrains`), `terrain_adjusters[id]` |
| blank row | |
| `UNIT_MODELS` "Current Models" | empty value |
| one row per technology on the sub-unit's list | label: the technology's name (slot 7); value: 3.5 |

### 3.5 Adjuster rows and technology rows

`CBrigadeView_AddAdjusterRows(view, screen, name, adjuster)` (0x7259D0): for each of `attack` (+8), `defence` (+0xC), `movement` (+0x10), `attrition` (+0x14) that is **not 0**, a row: label = name + `" "` + `UA_ATTACK`/`UA_DEFENCE`/`UA_MOVEMENT`/`UA_ATTRITION` (`Attack`, `Defence`, `Movement`, `Attrition`); value = `"+"` where positive (nothing where negative or zero; the row is not made at zero) + the figure + `%`. **The first three are value x 100 to 2 places (a value of 0.100 shows `+10.00%`); attrition is the value itself to 2 places (a value of 0.100 shows `+0.10%`), the same `%` beside it** - read at 0x726755..: no multiply on that arm. Kept: **do not tidy**. So each base row can produce up to four rows; an adjuster with all zeros none.

A technology row (`brigade->technologies`, list order): value is, joined in order:
- `§Y` if the technology's `canUpgrade`;
- if the technology has no models (`additional_offset == 0`): `Yes` (`YES`) where level >= 1, else `No` (`NO`);
- otherwise the level's name, `CCountry_TechnologyLevelName(country, technology, level)` of the builder/owner country (+ the owner's faction leader's list where the country is a government in exile and this level is above its own - **the country is the card's: builder's if any, else owner's**);
- where the technology's progress (the sub-unit's third figure, node +8) is above 0: `" §W(+"` + progress x 100 to 2 places + `%)`.

The same list and level-name rule as the unit panel's equipment (`FINDINGS-unitpaneltooltips.md`, section 7).

### 3.6 The picture: `CInGameIdler::SetSubUnitPhoto` (slot 77, 0x677410)

The gfx folder's slot in `CDirectorySettings` (base `+0xB8`, override `+0x25C`, mode `+0x4C`; `Path_PreferOverride` in mode 2, the override only in mode 1). With `<type>` the sub-unit's definition key:

- Default: `<gfx>/models/<type>_0.tga`.
- With a model N from `PickBestModel(country's set[type], sub-unit)` (N = its `index`, +0x24): `<gfx>/models/<TAG>_<type>_<N>.tga` if that file exists; else `<gfx>/models/<type>_<N>.tga` if that exists; else the default. Files like `ENG_battleship_1.tga`, `battleship_0.tga` and `CAN_battleship_0.tga` (Canada's model 0) sit in `gfx/models/` and match this.
- With no model: it tries `<TAG>_<type>_0.tga` **with no `/models/` in front** (listing at 0x677CD0: the suffix is the tag, `_`, the type key, `_0.tga`), so that path is the gfx folder's name run together with the file name and cannot be found: the default is used. **The original's slip, kept.**

If the chosen path exists (`FileExists`), a 0x1AC texture object is built from it on `GFX_no_ship_selected`'s sprite and set on the icon (slot 56) and the icon shown (slot 13); if no file exists the icon keeps the file's `GFX_no_ship_selected`. Mod files layer like any other interface picture.

## 4. The pride of the fleet

`make_pride`'s text is the file's `MAKE_PRIDE` "Make Pride". When pressable, its click (`CBrigadeView::OnMakePrideClicked`, 0x727270) makes a `CConfirmMakePride` (0x94 bytes, `DefaultConfirm` window, `interface/eu3dialog.gui`, buttons `AgreeButton` "Ok"/`DeclineButton` "Cancel" from the file). **Nothing guards a second press: each opens another dialog.** Nothing happens to the game until OK.

The dialog (`CConfirmMakePride::CConfirmMakePride`, 0x71E8A0):

- Title: `CONFIRM_MAKE_PRIDE_TITLE` "Do you wish to make this ship the Pride of the Fleet?"
- Description: `CONFIRM_MAKE_PRIDE_DESC` "A country can only have one Battleship or Battlecruiser designated the Pride of the Fleet.\n$EFFECTS$", with EFFECTS:
  - `MAKE_PRIDE_EXP_EFFECT` "- $NAME$ gets §G$EXP$%§W more experience\n": NAME the ship; EXP `PRIDE_BONUS_EXP` formatted 0 places (defines: 10; mod-able);
  - `MAKE_PRIDE_SUNK_EFFECT` "- If $NAME$ is sunk, we will incur §R2§W Dissent\n" - **a literal 2 in the table**; `PRIDE_SUNK_DISSENT_IMPACT` is read by nothing (`FINDINGS-government.md`), so the line is true only by accident of the default;
  - where the ship's owner already has a pride (`CCountry_FindPrideOfTheFleet` of the owner, CSubUnit +0x94): `MAKE_PRIDE_PREVIOUS_EFFECT` "- $OLD_NAME$ is no longer Pride of the Fleet\n"; and, where `GetPrideRedesignationDissent(new, old)` is above 0, `MAKE_PRIDE_DISSENT_EFFECT` "- We incur §R$DISSENT$§W Dissent from the redesignation\n" with DISSENT to 2 places. (`PRIDE_BASE_REDESIGNATION_DISSENT` 1, then halved or divided by hull and technology differences: the record's GetPrideRedesignationDissent comment.)

OK (`CConfirmMakePride::OnConfirm`, slot 5, 0x71F2A0): posts `CMakePrideCommand(ship)` (0x64 bytes) through the session's command queue, sets the dialog's closed flag, and sets the screen's `reshow_open_view` (+0xD30) unless the custom game's setting +0x18 is 2. Cancel is `CEU3Dialog`'s default. `CConfirmMakePride::StaysOpen` (slot 7): the ship must still resolve, else the dialog shuts doing nothing.

`CMakePrideCommand::Execute` (0x5DB530, already recorded): resolves the ship; if none, nothing. Otherwise for its owner: `CCountry_FindPrideOfTheFleet`; where there is one, `Dissent += GetPrideRedesignationDissent(new, old)` floored at 0, and the old ship's `pride` cleared; then this ship's `pride` set. **It tests nothing else** - not `can_be_pride`, not who posted it, and not whether the ship is the same as the old pride. The button is what keeps those from arising in play. The pride bonus only shows on the card in the experience figure and the stars: `PRIDE_OF_FLEET` and the star (`unit_pride_star`) are the unit panel's, not this window's; `make_pride` is merely disabled once a ship is pride.

## 5. `sunk_ships_view`

Opened only by `sunk`'s plain click on a ship's card (`CBrigadeView::OnSunkClicked`), and only pressable where the ship has sunk something (3.2). Each press opens another window (`new 0x60`, unguarded). Window at (320, 213), `moveable`; independent of the card (closing the card leaves it). Button text `SUNK_SHIPS` "Sunk ships" is the file's.

`CSunkenShipsView::CSunkenShipsView` (0x71E100): holds the ship (+0x34, id +0x38/+0x3C) and the window (+0x5C); `close` button's glue sets the closed flag (+0x30). `label` (instant text box, `format=centre`, position 40,12) = `SUNK_SHIP_LABEL` "Ships sunk by $NAME$." with NAME the ship's name. `list` (330x386, spacing 2, the file's `standardlistbox_slider`) gets a row for **every ship on `g_CCurrentGameState->sunk_ships` whose `sunk_by` (+0x9C/+0xA0) resolves to this ship, in the list's order** - the order they left the game, oldest first. The list is what was on the sunk list when the window opened; Update does not refill it. Note the sunk list holds every ship that left the game, disbanded ones too; only those with this `sunk_by` appear. (On the oracle `Ireland1938_08_03_14.hoi3`: 30 entries, 12 with a `sunk_by`, the sinkers alive; two sinkers sank two ships each - so `sunk` is enabled for ten ships in that save, one row each or two for those two.)

`CSunkenShipsView::Update` (slot 1): gone ship -> close; else not closed. No tooltips (slots 2, 3 the shared stubs).

**A row (`CSunkenShipEntry`, `sunk_ship`, 0x28 bytes):**

| element | what it gets |
| --- | --- |
| `name` | the sunk ship's name (slot 8) |
| `counter_type` | sprite `GFX_counter_` + the type's key if that sprite exists; otherwise the file's `GFX_temp_unit_icon` |
| `country` | the sunk ship's **owner's** flag (icon slot 53 with +0x98) on the file's `GFX_minishield` |
| `model` | `PickBestModel`'s model name of the ship's builder's country (the owner's where no builder) + `+*` where it is not `FindModelOf`'s model; the definition's name (slot 6) where the type has no model |

The row inherits every slot of the list item: **a click selects nothing visible and does nothing, and no element has a tooltip.** Scrolling is the list box's. The window shuts with `close` (the file's `CLOSE` "Close", next-frame) or when the ship can no longer be resolved.

## 6. Declared in the files and not touched by the code

`model_overlay` and the `background` buttons of both windows; `brigade_detail_entry` in each row; the file's `tooltip`/`tooltipText`/`delayedTooltipText` on the buttons (all empty, and no tooltip code applies); the `frame = 6` on the three experience icons (overwritten); the default texts `name`, `Value` in the entries (overwritten). `CSunkenShipEntry`'s and `CBrigadeStatsEntry`'s classes introduce no virtual of their own. Nothing here reads the file's `moveable` beyond the common window behaviour.

## 7. Kept as read, though they look odd

- **Attrition's row is not times 100**, the other three are (3.5). The `%` follows it all the same.
- **`SetSubUnitPhoto`'s no-model arm cannot find `<TAG>_<type>_0.tga`** (3.6): no `/models/` in the path.
- `MAKE_PRIDE_SUNK_EFFECT`'s 2 dissent is a literal; the define is unread.
- `KM` has no text in the tables, so RANGE and DISTANCE say "KM" as the bare key; KPH and KM follow the number with no space.
- A card's `make_pride`/`sunk`: one press opens a new dialog or window each time; nothing is modal. Multiple `CConfirmMakePride` can be open at once and each can post (`Execute` is unguarded).
- The card is built once: the rows do not update while it is open.
- `Execute` of `CMakePrideCommand` does not test the type. The `make_pride` button's `can_be_pride` test is the only gate.
- The `+*` test compares `PickBestModel` and `FindModelOf`; which of those means "older than today's model" is the historical-model reading's business (`FINDINGS-unitpaneltooltips.md`, section 13).

## 8. What is not established

- Which mouse events slots other than the plain click are on the row's `select` glue (`0x749270`, slot 4, its "third event", per `FINDINGS-unitpanel.md`, selects the brigade through the screen); only the plain click opening the card is read.
- `CRenameSubUnitCommand::Execute` (0x1DDE60) was read afterwards: it resolves the sub-unit, takes its old name off its country's names in use (`UnregisterUnitName`, 0xCB510), sets the name and registers it. It tests nothing.
- A wing's or regiment's card when the sub-unit is removed: the card's Update returns false once the id no longer resolves; a disposed `CShip` stays on the id table, a regiment's or wing's deletion is the normal removal - no save was exercised.
- Whether `FileExists` on the malformed no-model path could ever succeed (a file literally named by the gfx folder name run into the tag) - no such file was looked for beyond the arithmetic.
- Multiplayer: `CMakePrideCommand` and the rename are posted commands, but no MP run was made; nothing specific was read.
- The edit box's character limit (no `maxChars` in the file; the default of `editBoxType` not read here).
- The other callers of slot 77 (`CInGameIdler::SetSubUnitPhoto`): the unit panel's `selected_photo` and the builder windows' pictures (`selected_ship_photo` etc.; `FINDINGS-builders.md` says "how the picture is chosen was not read") were not traced; 0x751578 is one caller, not identified.

Frontier: 0x3C9530 (the persistent-reference holder ctor at +0x8C/+0x34/+0x6C), 0x31E820 (folded row deleting destructor), 0x406210 (id resolve via EAX used on subunit_name), 0x690140 and 0x6903E0 (edit box display and focus helpers used for `subunit_name`), the other callers of `CInGameIdler` slot 77 (0x751560 at least).
