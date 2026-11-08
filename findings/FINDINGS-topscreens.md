# The top bar's last three screens

*The top screens wave, 2026-11-08 (`WAVE.md`, `CANDIDATES.md`). What the top bar's Theatres, Statistics and Strategic Warfare buttons open: `country_theatres`, `ledger` and `swm_window`. Read statically. Addresses are VAs unless a line says rva.*

## A. The theatres screen

*Addresses in this section are VAs unless a line says rva. Text is the English column of the install's tables; the keys are in `localisation` (`Motherland.csv`, `interface.csv`, `SemperFi.csv`, `units.csv`). Read statically; the game was not run. Marked confirmed / likely / inferred. **No save holds what this screen shows and the game cannot be run from here**, so nothing below was compared with a live screen - the bytes alone.*

### A.1 What it is, and how it opens

`CTheatreView` (RTTI, vftable `0x15BD424`, fifteen slots; own bodies at slots 0, 1, 2, 6) is the sixth `CCountryView`, made by `CInGameIdler_BuildViews` as the last of the six (index 5 of `+0xD00`; call at `0x659D7B`). Its constructor passes **`country_theatres`, `topcolor_theatres` and view_index 4** to the base - the same view_index the espionage view passes, so the screen shares the local player's automation setting at that index. That setting does nothing here: the base's slot 11 opens with `automation_setting`, which this file does not declare, and returns before it would call slot 14, so the screen is always clickable and has no automation arrows (confirmed).

**Who opens it.** Only `CTopBar::OnTheatreButton` (rva `0x2CEF90`, `topbarbutton_theatre`; `OpenCountryView(5)` at `0x6CEF96`) passes the literal 5 among the 40 direct callers of `CInGameIdler::OpenCountryView`; several pass `+0xCFC`, the open view (the toggle). `OpenCountryView` is shared by all six views: where any view is open it hides them all; `+0xCFC` becomes 5; the side menus shut; opening the view that is already open only closes it - the toggle. It then `ClearSelection`s **after** calling `Show`. Nothing in `OpenCountryView`, `Show` or the screen's own code touches the pause (confirmed for those functions; that the game therefore keeps running behind the screen is inferred - the idler's frame loop was not read for it).

**Who shuts it.** `close_button` (`shortcut = ESCAPE` in the file, observer from `CCountryView`'s constructor): if the view's byte `+0xB4` is 0 and a view is open, `OpenCountryView(+0xCFC)` - the toggle. Both goto handlers end the same way. `+0xB4` is only zeroed in the base constructor and read here; nothing found sets it (not established whether anything does outside the views' own code).

### A.2 The two lists, and the selection

`CTheatreView_RefillLists` (rva `0x6FE00`, this in ESI), called by `Show` and by `Rebuild`, empties `my_theatres` and `allied_theatres`, then, in order:

1. **Which theatre is preselected** (nothing on a first open): the first entry of the idler's selection (`+0x1304`) with slot 1 = 0 (a land unit) and `oob_level` (`+0x1F4`) = 0 - a selected theatre headquarters, if any.
2. **`my_theatres`**: the played country's own `area_theatre` list (country `+0x570`, list order, **no sort**). A theatre whose headquarters (its `unit` id, `+0x74`/`+0x78`) cannot be found gets no row. Each gets a `CTheatreEntry`. The theatre becomes selected if its HQ is the selected unit or nothing is selected yet.
3. **`allied_theatres`**: every country on the player's Allies list (`+0xF88`, bilateral alliances and faction members, list order), each country's own theatres in its order; a row each; selected only if nothing is yet.

The selection is the theatre's id pair at view `+0xB8`/`+0xBC`, with a dirty byte at `+0xC0`. It survives closing the screen. `Show` always sets the dirty byte.

**A row, `theatre_entry`** (0x90 bytes; constructor rva `0x6C380`, `CTheatreEntry`): keeps the theatre's id pair and the view; `title` = the headquarters unit's name (the unit's slot 7, its `name`); `country_icon` shield = its owner (button slot 53 with the owner's id); `theatre_plupp` = `CUnitPlan::GetPowerRatio` of that HQ's plan as a float: **above 0.75 frame 1, above 0.5 frame 2, otherwise frame 3** (the frames are `GFX_theatres_plupp`, `noOfFrames = 3`; a plan whose `their_power` is exactly 0 gives -1, so frame 3; `their_power` < 0 gives 1000, so frame 1). This runs once, when the row is built (rva `0x6C500`, only caller), and the row is not updated again while the screen is up: `CTheatreView::Update` calls the `areas` rows and no others (confirmed; that the listbox itself never calls slot 8 was not searched for). **`background_button`** alone has an observer: `OnSelect` sets the view's selection to the row's theatre and dirty. `country_icon` is a button with no observer. Clicking the file's `title` does nothing.

### A.3 `selected_theatre`, and when it is filled

`CTheatreView::Update` (slot 6, rva `0x71AD0`; the idler calls the open country view's slot 6 as for the others, inferred from the production and technology screens' readings). While the screen is open (slot 7): if the selected id finds no theatre, the first row of `my_theatres` is used instead (not stored back into the selection). **Only when a theatre is found and the dirty byte is set** the byte is cleared and the window is filled - so the text is a snapshot of the moment the selection changed or the screen opened, not a live readout.

| element | content | source |
| --- | --- | --- |
| `title` | the HQ unit's name | unit slot 7 |
| `country_icon` | the HQ owner's shield | owner_id `+0x128` |
| `land_stance` | PlanStanceName of the plan's stance: `STANCE_WITHDRAW` / `_PREPARE` / `_DEFEND` / `_ATTACK` / `_BLITZ` (Withdraw / Prepare / Defensive / Attacking / Blitzing Stance) | unit `+0x208` |
| `air_stance` | `STANCE_AIR_PREPARE` / `_DEFEND` / `_ATTACK` (Air Prepare / Air Defensive / Air Offensive) | unit `+0x20C` |
| `naval_stance` | `STANCE_NAVAL_PREPARE` / `_DEFEND` / `_ATTACK` (Naval Prepare / Naval Defensive / Naval Offensive) | unit `+0x210` |
| `immediate_needs`, `build` | A.4 | |
| `forces` | A.5 | |
| `objective` | A.6 | |
| `current_operation` | A.6 | |
| `areas` | A.7 | |

The file's defaults stand where nothing is written (`land_stance` "Defensive Stance", `forces` "needs", `objective` "None", `current_operation` "None"): with no theatres the window keeps them. Static text the file declares is keyed: `headline_theatres` THEATRES, `THEATRE_THEATRES` Theatres, `THEATRE_ALLIED_THEATRES` Allied Theatres, `THEATRE_FORCES` Theatre Forces, `IMMEDIATE_NEEDS` Immediate needs, `THEATRE_CURRENT_OBJECTIVES` Current Objectives, `THEATRE_CURRENT_OPERATION` Current Operation, `THEATRE_FRONT_PLANNING` Front Planning, `NEEDS` Needs, `BUILD` Build. `goto_button`'s `buttonText = "GOTO"` has no key in any table (shown as is).

Elements the file declares that the code does not touch: the `topcolor_icon`, `bg_mainshadow`, `bg_countryskin` (the base's skin routine may touch it, not read for this view), `bg_theatres`, the seven labels above, `land/air/naval_stance_icon`, every `build_text`, `theatres_front_bg`, `needs_label`, **`odds_with_reinforcements`** (not in the image's strings at all, marked `##remove` in the file and parked at x = 9585), and the row's `country_icon` observer that does not exist.

### A.4 `immediate_needs` and `build` (rva `0x70220`)

The HQ's `plan_subunit_needed` (`+0x7C`, a per-type vector) is used only when its length equals the sub-unit database's count; then it is copied to the view's `+0xC4`. **Every military line in the played country's own queue that is aimed at this HQ** (the line's target `+0x90`/`+0x94` equals HQ `+0x10`/`+0x14`) takes its `Size` off the entry of each brigade type it holds, once per brigade of the line. If any entry is then above 0, the text is, in database order over the types above 0:

    <n> £<type key>, <n> £<type key>...

with the trailing `, ` removed (` £` is the counter-in-text escape, so the key draws that unit's counter). `build` is enabled when the HQ's owner is the played country and disabled otherwise (button slots 46 and 47). Otherwise the text is `NO_NEEDS_FOR_BUILDS` ("This theatre has no immediate needs for new units."), `build` disabled. The length mismatch takes the same branch.

### A.5 `forces` (rva `0x70D50`)

Per unit type, a count of every brigade (`+0x38` of each unit, type by `+0x58` -> `+0x24`) of every unit on the HQ owner's unit list (`+0xBAC`) whose theatre by `CUnit_FindTheatre` is the HQ's. The text is the same `<n> £<key>, ` in database order, trailing comma off; empty string if none.

### A.6 `objective` and `current_operation` (rva `0x71410`)

**`objective`** = `CUnit_ObjectivesSummaryText` (rva `0x1B5B50`) of the HQ, or `NO_OBJECTIVES` ("No Objectives") when empty. That text is empty unless the plan is active (`+0x204`) with objectives (`+0x234`..). Up to three: names joined `, `, ` & ` before the last. Four or more: the one of highest score - victory points × 20000 + province modifier 15 + 1000 if it has an air base + 1000 if a naval base + 10000 if it is its holder's capital - as `OBJ_AND_MORE` ("$NAME$ & more...").

**`current_operation`**: for each AI agent of the HQ owner's `CEU3AI` (agents list `+0x50`) whose slot 60 (`GetLandForce`, `CAIInvasion`'s; other agents' not read) returns a non-empty land force: the first land unit of it whose top HQ's theatre equals the selected HQ's theatre; where the agent's target `+0x84` and stage `+0x88` are both set, `THEATRE_INVASION` ("Part of invasion of $TARGET$ staging from $STAGE$. ") is appended (trailing space included), for each such agent, with no separator between. If nothing was appended: `NO_INVASION_PLAN` ("Not part of invasion plans."). Only when the HQ's owner has an AI object at all.

### A.7 `areas` (rva `0x711C0`)

For the theatre's fronts (`+0x50`, list order) with **at least two provinces** and whose enemy (`local_enemy`, `+0x1C`/`+0x20`) is **not** a friend of the played country (`CCountry::IsFriend(player, enemy, true)` - so the player's and allies' fronts are left out, and a front with one province is left out): a `CAreaEntry`. A theatre whose fronts are all with friends shows an empty list.

**A row, `area_entry`** (0x1A0 bytes; constructor rva `0x6C840`). Its setup (rva `0x6CF20`):

- **Which province names it** (rva `0x6CBD0`): of the front's provinces in order, `n` of them, `half = n / 2`, the score of index `i` is `4 * (1 - |i - half| / half) + province[+0x5C] / 1000` as a float (`+0x5C` is `MaxInfrastructure`, the Lua API's name) - the middle of the front counts for 4, the ends for 0. Highest strictly above 0.0, first of equals. **If nothing scores above 0, the row stays entirely blank** - no title, no observers.
- `theatres_continent` picture: the first of these sprites that exists: `GFX_theatres_<province id>`; `GFX_theatres_<region name>` for each of the province's regions in the map's order (the base game's file has `GFX_theatres_north_africa_region`); and **only where the province's continent is the continent of the front enemy's acting capital** `GFX_theatres_<enemy tag>` (GER, POL, SOV...); then `GFX_theatres_continent_<continent name>` (`europe`, `asia`, `africa`, `north_america`, `south_america`, `oceania`). None found: the file's `GFX_theatres_continent_europe` stays.
- `title` = `FRONT_TITLE`, "$FROM$ front toward $TO$": `$FROM$` the province's name, `$TO$` the enemy country's name.
- `stance` button's text starts from the HQ plan's stance.

**Row update** (slot 8, rva `0x6EA80`) runs only while its dirty byte `+0x198` is set: the constructor and `OnStance` set it. It sets the button text, builds a list of the front's provinces, calls `CUnit::UpdatePlanForceNeeds(hq, ?, ?, row needs, provinces)` and, if that answers true, subtracts the player's military lines aimed at the HQ as in A.4, then `ShowNeeds` (rva `0x6F090`). `ShowNeeds` writes `forces_needs` the same way as `immediate_needs` and enables `build` when the HQ's owner is the played country and there are needs. Otherwise `forces_needs` = `NO_NEEDS_FOR_BUILDS`, `build` disabled.

**`odds_description`** (rva `0x6F7E0`) and **`current_odds`**: `GetPowerRatio` of the **theatre HQ's plan** in thousandths:

    ODDS_  + DEFEND_ (plan stance 0-2) | ATTACK_ (3-4)  +  GOOD (ratio > 750) | AVERAGE (> 500) | BAD

- `ODDS_DEFEND_GOOD` "We will have no problems defending this position"
- `ODDS_DEFEND_AVERAGE` "We can defend this position for a while"
- `ODDS_DEFEND_BAD` "We will not be able to hold this position"
- `ODDS_ATTACK_GOOD` "We are confident in pushing the enemy back when attacking"
- `ODDS_ATTACK_AVERAGE` "We can attack, but might need reinforcements to hold the new line"
- `ODDS_ATTACK_BAD` "We are not strong enough to perform well in an attack"

`current_odds`: frame by the same ratio as the theatre row (above 0.75 / above 0.5 / else). **Every row of a theatre shows the same odds**: one figure, the plan's, the front does not enter it; the row's own stance button does not enter it either - only the plan's stance does (confirmed off the call site at `0x46EF27`..`0x46EF42`). Note the ratio-is-exactly-0 case (-1) reads BAD.

### A.8 The actions, and what each does

| element | handler | what it does | posts |
| --- | --- | --- | --- |
| `background_button` (theatre row) | `CTheatreEntry::OnSelect`, rva `0x6C6A0` | sets the view's selected theatre and its dirty byte | nothing |
| `selected_theatre` `goto_button` | `CTheatreView::OnGoto`, rva `0x73320` | if the HQ is the player's: Deselect if already selected, ClearSelection, idler slot 93 (not read), Select(hq), centres the map on the HQ's province; then closes the view | nothing |
| `selected_theatre` `build` | `CTheatreView::OnBuild`, rva `0x72030` | `+0xD4` = the country's manpower; BuildStep until false. **No refresh**: the text stays until reselected or reopened | the commands below |
| area row `goto_button` | `CAreaEntry::OnGoto`, rva `0x6D5A0` | centres the map on the row's chosen province; closes the view. Selects nothing | nothing |
| area row `build` | `CAreaEntry::OnBuild`, rva `0x6D6A0` | a local = the country's manpower; BuildStep until false; then ShowNeeds | the commands below |
| area row `stance` | `CAreaEntry::OnStance`, rva `0x6E9A0` | adds one to the row's own number, wrapping at 5, sets dirty. **A label only**: the row's number is read by nothing else, so the plan does not change, the needs do not change, the odds do not change. Inferred: unfinished in the original (no `CSetPlanAttributesCommand` or any other command is near it). | nothing |

**BuildStep** (rva `0x72120` for the theatre, rva `0x6D790` for a row - the same order and arithmetic; the first reads the view's `+0xC4` and `+0xD4`, the second the row's `+0x184` and a local):

Sum the needs into `air`, `land`, `ship` (by `is_air`, `is_land`, `is_ship`). The score of a candidate is `need * 5000 + (r % (need * 10 + 1)) * 1000`, where `r` is drawn from an MT19937 that lives on the stack and is **never seeded** (its 624 state words are whatever the stack held; only the index and flag are set) - so a pick is effectively arbitrary but breaks ties by need. A candidate must have `need > 0`, `is_buildable`, and `CCountry::CountMaxUnitsStillBuildable >= 1`; strict `>`, first of equals wins.

1. **If `air > land / 4`**: the best air type. If none, fall to step 4. A series of `root` units, `root` = integer square root of `need` (Newton from `need/2`, at least 1), `lines = need / root`. For each line: the size starts at `root` (and stays where it ended, across lines) and is lowered, stopping at 2, while `CCountry_GetBrigadesManpowerCost(type, size)` exceeds the manpower left; the cost is taken off; if the manpower has gone below 0 the whole step answers **false** (a `CConstructUnitCommand` is not made for that line). Otherwise a `CConstructUnitCommand` is posted (the brigade list `[type]`, province = the played country's acting capital `+0xE24`, amount = the size, reserve 0, build-now 0, country = the played country, builder `---`, **target = the HQ's id pair**) and `needs[type] -= size`. After all lines: true.
2. **Else if `land > 2`**: one division. First pass over the database in order: types with `need > 0`, `is_land`, `is_buildable`, `CountMax >= 1`, `priority > 4`, adding brigades of each (each brigade: `needs[type]--`) until a count of `(BRIGADES_IN_DIVISION + division_size)/1000 - 1` or `CCountry_GetMaxBrigadesInDivision - 1`. Second pass the same but `priority < 5` and up to the full `(BRIGADES_IN_DIVISION + division_size)/1000`. **The needs are decremented even if what follows refuses the list.** `CanBuildDivision(list, country, 1)` true: cost, charge, a `CConstructUnitCommand` (the list, capital, amount 1, as above), return true. False: step 3 with the reduced needs.
3. **Else if `land > 0`**: the best single land type, built exactly as air is in step 1.
4. **Otherwise ships**: the same as air, over `is_ship`. No land need and no ship need: false.

Each loop in OnBuild runs until a step answers false - so one press places several lines. The manpower is the country's whole `Manpower` at the press, spent locally; only the command charges it for real (`CConstructUnitCommand::Execute`). The order is posted to the local channel as every other country view's command is.

`CCountry_GetBrigadesManpowerCost` (rva `0xE1600`): the sum, over the list, of the brigade's definition's `BuildCostMP` after the country's technology is applied, scaled by `(the country's technology status +0x25C for the type + 1000) / 1000` (floored at `g_OneTwentieth`), times the amount. Whether this equals `CCountry::GetBuildCostManpower`'s per-brigade arithmetic was not compared (inferred the same).

### A.9 Tooltips, and greying

**None of this screen's elements has a tooltip of its own.** The view's slot 10 is `EmptyTooltip` (rva `0x376F20`); the two rows' table slots are the standard listbox item's; the file's `tooltip` and `tooltipText` are empty. `close_button` carries only the shortcut line of a button with `shortcut = ESCAPE`. (That `CInGameIdler::GetElementTooltip`'s sixty literals name none of these elements is inferred: `closebutton` is the literal, this file's is `close_button`.)

**Greying is `build` alone**: the two `build` buttons as above. `goto_button`s are never greyed: `CTheatreView::OnGoto` on an allied theatre's HQ does nothing but close the view (the HQ is not the player's, so no select and no centring).

### A.10 What is not established

- Whether `+0xB4` on a country view is ever set (only zeroed; read by every close path here). Only this family's code was searched.
- Whether the listbox itself calls a row's slot 8 (the view does not, for the theatre lists).
- What idler slot 93 does in `CTheatreView::OnGoto`.
- That an AI agent's slot 60 is empty for anything but `CAIInvasion` (the operation lines). Only the invasion's was read.
- Whether `CCountryView::UpdateCountrySkin` runs for this view as for others (base code; not traced here).
- Whether `CCountry_GetBrigadesManpowerCost` is the same arithmetic per brigade as `CCountry::GetBuildCostManpower`.
- Nothing above was run; `UpdatePlanForceNeeds`' first two out-vectors in the area case were not read.

Frontier: `0xA5B600` (string routine used to cut the trailing comma), `0x46FDA0` (`CTheatreView` destructor), `0x678610` (called in `CInGameIdler::OpenCountryView`).

## B. The statistics ledger

*Fragment `screens-ledger.json`. Source: decompilation of each page, partly through a scripted filter that dropped string and vector plumbing. Each page's keys and field reads are direct; where a figure's arithmetic was not read to the instruction it is marked. Texts are the install's English (Windows-1252).*

**B.1 Opening and closing - confirmed.** `topbarbutton_statistics` (CTopBar +0x270) reaches `0x6733F0` (callers `0x64B5FF`, `0x6CBB64`), then `0x673470`, the toggle on idler +0x1CE0.

- On open: `0x673470` hides the idler's +0x1CC0 object, and if a country view is open it closes it (it calls `OpenCountryView` on the current one).
- If the ledger already exists, it records the page in +0x1D40, sets the close request +0x1D3D and hides `bg_main_menus` (+0x1914).
- Otherwise it stores IsPaused in `paused_before_window` (+0x1D3E), and **pauses only in single player**: it calls slot 27 if not paused and the idler's multiplayer byte +0x68 is 0.
- It then creates a `CStatisticsLedger` (0x2F8 bytes) starting at page +0x1D40 and calls `Open` (`0x3C2620`).
- `close_button` and shortcut ESCAPE: `OnClose` records the page, sets +0x1D3D and hides `bg_main_menus`. `CInGameIdler::Update` at `0x65676F` destroys the ledger next frame and, where +0x1D3E is clear and +0x12D8 (not read) is set, calls slot 27 to unpause. The other +0x1D3D writers are other close paths.
- Reopening returns to the last page. `bg_countryskin` is `gfx/interface/skins/country_bg_<TAG>.dds` for the player's tag, if it exists (`0x3C5C10`).

**B.2 Pages and navigation - confirmed.** 26 pages, 0-based, with `page + 1` written to `page_number`. `next_button` (RIGHT) and `previous_button` (LEFT) wrap over 0..25. `ledger_overview` = 0, `ledger_economy` = 6, `ledger_misc` = 12, `ledger_military` = 13. The heading text is set in the `header` box of each page. `ledger_overlay` is shown by `LedgerPage_Update` and hidden by the pie pages 22-25. `textbox_autosend` and `checkbox_autosend` are hidden on every page (and placed off-screen at x 2170/2200 in the file). The gui's `headline_statistics` key reads "STATISTICS"; `headline_statistics` is a plain text box.

**B.3 Pages (bold key = page title).** "Player" is the country played; rows are built on every open.

| page | title key -> text | rows | columns (key -> text), cell, sort type |
| --- | --- | --- | --- |
| 0 | `ELEDGER_NATIONAL_STATISTICS` "National Statistics" | every country with OwnedProvinces > 0 (and only while the byte +0x68 of the player's country record's interface host is 0; meaning not read) | Country (name), Faction (localised), VP = controlled_victory_points/1000 (float), Offmap VP = country +0x11D0/1000, Total VP = sum |
| 1 | literal `Nation Statistics` (not a table key) | every province with VP > 0 | `LEDGER_PROVINCE` "Province", `LEDGER_VALUE` "Victory Points", `LEDGER_CONTROLLER` "Controller", `LEDGER_NEUTRAL` "Neutral" (VP where the controller has no faction, else 0), one column per ideology group (VP where the controller's faction is that group's, else 0) |
| 2/3/4 | `LEDGER_ALLARMIES_TITLE` "Allied Army Comparison", `LEDGER_ALLNAVIES_TITLE` "Allied Navy Comparison", `LEDGER_ALLAIR_TITLE` "Allied Air Comparison" | countries with land: the player, faction co-members (when the player has a real faction), allies (`Diplomacy.alliance`), and puppets of the player (dependency type 0x298 with the player as first) | `LEDGER_COUNTRY`, one column per buildable subunit of the kind (SubUnitDefinition short name), `LEDGER_TOTAL`; int cells count brigades, total is the sum |
| 5 | `LEDGER_SUNK_SHIP` "Ships Sunk" | `CCurrentGameState.sunk_ships` | `LEDGER_OWNER`, `LEDGER_SHIP`, `LEDGER_TYPE`, `LEDGER_SINKER_NAME`, `LEDGER_SINKER_TYPE`, `LEDGER_SINKER_COUNTRY` (the sinker unit via FindPersistentByIdPair) |
| 6 | `LEDGER_TERRITORIAL_TITLE` "Controlled Provinces" | the player's controlled province list | `LEDGER_PROVINCE`, `LEDGER_ENERGY`, `LEDGER_METAL`, `LEDGER_RARE`, `LEDGER_OIL`, `LEDGER_MP`, `LEDGER_LEADER`; province current_producing / manpower / leadership over 1000 |
| 7 | `LEDGER_BUILDING_TITLE` "Buildings" | the same provinces | `LEDGER_PROVINCE`, one column per building (icon `<name>_icon`), cell = the province's building level; see `FINDINGS-ledgericons.md` |
| 8 | `LEDGER_FLOW_TITLE` "Resources Flows" | one row per pool | `LEDGER_CATEGORY` + one column per good (GoodName 0..6), each row's pool dword over 1000. Rows: `LEDGER_HOME_PRODUCED`, `LEDGER_CONVOYED_IN`, `LEDGER_CONVOYED_OUT` (+0x7B8), `LEDGER_REPAID_DEBT` (+0x824), `LEDGER_INCOMING_DEBT` "Debt payed to us" (+0x848), `LEDGER_CONVERTED_TO` (+0x8B4), `LEDGER_CONVERTED_FROM` (+0x8D8), `LEDGER_PUPPET_FROM` (+0x8FC), `LEDGER_PUPPET_TO` (+0x920), `LEDGER_USED_INDUSTRY` (+0x968), `LEDGER_USED_TROOPS` "Usage" (+0x98C), literal `Into Network` (+0x9B0), `LEDGER_STOCKPILE` "Returned to Stockpile" (+0x9D4), `LEDGER_FROM_EXILES` (+0xA64), `LEDGER_TRADED_FOR`, `LEDGER_TRADED_AWAY` |
| 9/10 | `PW_STRAT_RESOURCES` "Strategic Resources" | `strategic_resource_provinces` | resources 0..8 on page 9, 9 onward on page 10 (icon `<name>_icon`); each cell a flag of the controller, with tooltip "resource controlled by <country> <faction> located at province <name>" (`LEDGER_STRAT_RES_CONTROL_TOOLTIP_1`, `_2`). Layout (a row per province per resource) is inferred |
| 11 | `LEDGER_CONVOYS_TITLE` "Convoys" | every convoy | `LEDGER_FROM`, `LEDGER_TO` (province names), `LEDGER_TRANSPORTS`, `LEDGER_ESCORTS`, then each convoy's daily metal, energy, crude oil, rare, supplies over 1000 |
| 12 | `LEDGER_POLITICIANS_TITLE` "Politicians" | each minister x each position open to them | `LEDGER_NAME`, `LEDGER_IDEOLOGY`, `LEDGER_POSSIBLE` (Yes/No: his ideology among the government's), `LEDGER_PERSONALITY` (GetPersonality for that position), `LEDGER_JOB` (position name where he holds it, else `LEDGER_NONE` "None") |
| 13 | `LEDGER_BRIGADE_TITLE` "Brigades" | each brigade of the player's land units | `LEDGER_NAME`, `LEDGER_TYPE`, `LEDGER_STRENGTH`, `LEDGER_ORG` (strength and org /1000), `LEDGER_LOCATION` (the unit's province), `LEDGER_DIVISION`, `LEDGER_CORP`, `LEDGER_ARMY`, `LEDGER_ARMYGROUP`, `LEDGER_THEATRE` (the chain of higher commands by level), `LEDGER_ORDER` |
| 14 | `LEDGER_SHIP_TITLE` "Ships" | the player's naval | `LEDGER_NAME`, `LEDGER_TYPE`, `LEDGER_STRENGTH`, `LEDGER_ORG`, `LEDGER_LOCATION`, `LEDGER_FLEET`, `LEDGER_BASE`, `LEDGER_ORDER` |
| 15 | `LEDGER_PLANE_TITLE` "Planes" | the player's air | as 14 with `LEDGER_WING` |
| 16 | `LEDGER_BRIGADE_STATS` | land brigades | `LEDGER_NAME`, `LEDGER_TYPE`, `LEDGER_MODELNAME` (PickBestModel), then icon columns: `ledger_sort_str` (max strength), `_cw`, `_sa`, `_ha`, `_def`, `_tou`, `_ap`, `_arm`, `_sof`, `_aa`, `_ad`, `_sup`, `_sc`, `_fc`, `_speed`, `LEDGER_EXPERIENCE2` "Exp" (experience as percent) |
| 17 | `LEDGER_SHIP_STATS` | ships | as 16: range, distance, surface, air, sub detection, visibility, sea defence, air defence, air attack, convoy attack, sea attack, sub attack, shore bombardment, hull, positioning, transport capacity |
| 18 | `LEDGER_PLANE_STATS` | wings | str, org, speed, sc, fc, surface defence, air attack, air defence, strategic attack, sa, ha, transport, sea attack, range |
| 19/20/21 | `LEDGER_LAND_COMMMANDER`, `LEDGER_SEA_COMMMANDER`, `LEDGER_AIR_COMMMANDER` | player's active leaders of type 0/1/2 | `LEDGER_NAME`, `LEDGER_RANK`, `LEDGER_SKILL`, `LEDGER_EXPERIENCE`, `LEDGER_COMMISION` "Commission" (unit, or `LEDGER_NONE`), `LEDGER_TRAIT1`..`4`. Clicking a row selects the leader's unit and closes the ledger |
| 22 | `LEDGER_PIE_ALL` "All Units" | pies | 4 pies. (1) `LEDGER_UNIT_SPLIT` "Number of units": brigade counts by kind, slices `LEDGER_BRIGADE_TITLE`/`AIRWINGS`/`LEDGER_SHIP_TITLE` with `LEDGER_LAND`/`AIR`/`NAVAL`. (2) `LEDGER_SUPPLY_CONSUMPTION` "Supply Cons.". (3) `LEDGER_FUEL_CONSUMPTION` "Fuel Cons.". (4) `LEDGER_UNIT_REINFORCE_NEED` "Reinforcement Need:". Slices of 2-4 land/air/naval, red/green/blue, only where the total is above 0.1 (`0x160A3C0`; a pie with no slices shows `no_pie_data_window`, `LEDGER_NO_DATA` "No data for this pie") |
| 23/24/25 | `LEDGER_PIE_LAND`/`_AIR`/`_NAVAL` | pies | the same four, one slice per unit type (colour from the page's list, `CRegiment::SupplyConsumption`/`FuelConsumption`, count, reinforcement need) |

Header texts come from `TableHeaderText` (`Arial12_headline`) or icons. Cell text is `TableItemText` (`Arial12_black`, 12 high, fixedsize). Column widths come from `ledger_default_title_col` (130) and `ledger_default_normal_col` (75), overridable per page with `ledger_<name><i>` position types; pie pages' sizes are in the page code (the `0x96`/`300` immediates, not read).

**B.4 Tables - confirmed.** Rows live in a std::map keyed by the row name, so a table's default order is the sort of that key. A page applies the stored per-page sort (`CCurrentGameState` +0xCC4 column string, +0xCD4 ascending 0/1) through `0x395300`, else sorts by the first column; the strategic pages sort nothing (`0x6EF800`). A left click on a header (`OnMouseEvent`) stores and applies the sort on that column; cells compare by int, float or text depending on the cell, ascending or descending. A row click calls `CStatisticsLedger` slot 0 (only the leader pages act). The mouse wheel moves the slider `standardlistbox_slider` placed by `ledger_scrollbar_offset`; the visible rows start at `(int)(value + 0.5)`.

**B.5 Pies - inferred.** Each pie is a `0xAA3090` object (the slice geometry is in there, not read) at the `pie_UL`..`pie_LR` rect with the pie offsets `pie_one_offset` to `pie_four_offset`. It has a `pie_heading` (`Arial14_black`), and each slice has a `pie_text` (`Arial12_bold_black`, stepped by line height) and a two-vertex leader line (`pie_line_offset`, `pie_line_offset_two`) in the slice colour. Slice label text is built by concatenating a label and the value (not read to the format).

**B.6 Graphs: dead - confirmed.** `graph_background` and `no_graph_data` are found and hidden and nothing shows them. `prev_graph_button` and `next_graph_button` are bound in the constructor and only move `graph_index`. The strings `graph_label`, `legend_label`, `vertical_1`, `horizontal_1`, `graph_vertical_bar`, `graph_horizontal_bar` and `graph_entry_center` do not occur in the executable at all. So **nothing in the file's graph section is drawn.** `graph_entry` has one reference, at `0xAC3C15`, which was not read; it may be a generic lookup.

**B.7 Save history.** `income_statistics` and `inflation_statistics` are empty in every save (written, never filled). `nation_size_statistics`: one point per country per year, appended in `RunYearlyPass` (`AppendStatisticsSample`, `0x1F3B90`, one caller): `value` = country +0xCF8 (owned provinces), `year` = the year. Checked: `Germany1936_04_20_03` has an empty block; `Ireland1938_08_03_14` has 102 series with `ledger_data_x` = 1937, 1938; `Ireland1940_05_23_19` has 1937..1940, with GER 263, 263, 326, 375 and `ledger_data_y` the owned-province count. No cap: points are kept for the game. Series names include `---` (null country) and `REB`. No code reads it for display: the only readers of +0xC70 are at load, save and teardown, and `RunYearlyPass` (`0x67C693`, `0x67D605`, `0x67DD39`, `0x67F92F`, `0x67FD95`, `0x683E53`) - a displacement scan, candidates each read in place.

**B.8 Tooltips.** Column icons `ledger_sort_*` and `sort_strat_a` answer through `BuildLedgerColumnTooltip` with `BUILD_*_IRO` and `BUILD_*_DRO`: str, org, cw, sa, ha, aa, def, tou, PIERCING(ap), ARMOR(arm), ad, sof, SPEED_DD(speed), sup, sc, fc, con_a, sea_a, sub_a, air_a, shore, sea_d, strat_a(`sort_strat_a`), air_d, sur_det, air_det, sub_det, VISI(visibi), trans, range, distance, hull, pos, and cw last. Text cells show their cell's `+0x84` tooltip where set. The `TableItemText` branch shows the element's own text.

**B.9 Not used by the code.** `ledger.gui`'s `ledger_building_overlay` and `ledger_build_building_button` have no string reference; the building-page handlers (`0x3BFFC0`, `0x3C0000`, `0x3C0040`, `building_mode`) and the helper `0x3BFE00` are reachable only through glue objects that no button binds in this build. `checkbox_autosend` and `textbox_autosend` are hidden, off-screen and do nothing.

**B.10 Where a table stands, and each page's columns - confirmed (2026-11-08, from the maintainer's report that the columns were wrong).** The write-up above took the column widths from `ledger_default_title_col` and `ledger_default_normal_col`; **only page 0 uses them**. There is no `ledger_row_height` (the string is not in the image; the record's comment was wrong).

- **Origin.** `ledger_UL` is measured from the middle of the screen: the table's left is centre x - (UL.x + 18) + 9, its top centre y - UL.y. With the file's (480, 205) and the window at (-555, -344) from the centre, that is (66, 139) in the window.
- **Rows.** Every page gives two rectangle lists, headers at y 0..30 and cells at y 35..65 over the same columns. The first row stands at 35, and rows step by the first cell rectangle's height, 30, until the step passes `ledger_LR`.y (500): sixteen rows. The slider is at `ledger_scrollbar_offset` from the screen's centre in x and the table's top in y.
- **A header** is the optional icon at the rectangle's corner, then `TableHeaderText` after the icon's width with its width set to the rectangle's; an empty text is parked off screen. Page 7's and 16-18's headers have empty text, so they are icons alone. **A cell's** width is its rectangle's.
- **Columns**, left..right from the table's left, literal in each page's code, some overlapping or with gaps:

| page | columns |
| --- | --- |
| 0 | helper `0x7954F0`, name `nat_stat`: `ledger_nat_stat0` or the title default 130, then `ledger_nat_stat<i>` or the normal default 75, each from the last's right |
| 1 | 0-150, 150-250, 250-350, 350-425, 425-500, 500-575, 575-625 |
| 2 | -12..72, then the i-th at 45 + 28i, 29 wide |
| 3 | 0-100, then 100 + 58i, 60 wide |
| 4 | 0-128, then 128 + 65i, 60 wide |
| 5 | 0-150, 150-375, 385-450, 500-700, 700-800, 800-900 |
| 6 | 0-180, 180-255, 255-320, 320-405, 405-480, 480-555, 555-720 |
| 7 | 0-150, then 50 each |
| 8 | 0-130, then 70 each |
| 9, 10 | width (UL.x + 18) x 2 / columns = 996 / n; column i from i x width to (i + 1) x width - 12 |
| 11 | rights 85, 170, 230, 290, 350, 410, 470, 540, 600, each from the last |
| 12 | rights 150, 325, 400, 600, 825 |
| 13 | 0-150, 150-200, 200-250, 250-300, 300-375, 375-500, 525-650, 675-750, 750-825, 825-900, 900-975 |
| 14 | rights 150, 200, 250, 300, 380, 555, 655, 850 |
| 15 | rights 150, 200, 250, 300, 400, 520, 680, 900 |
| 16 | widths 150, 50, 75, then sixteen of 43, touching |
| 17 | rights 130, 180, 285; thirteen at 287 + 41k, 40 wide; three more from the last right + 1, 42 wide and 43 apart |
| 18 | rights 150, 200, 285; fourteen at 287 + 41k, 40 wide |
| 19-21 | 0-125, 130-200, 200-250, 250-325, 325-500, 505-605, 610-700, 705-895, 800-995 |

**The strategic resource pages (9, 10)** correct B.3's "layout inferred". A column is a resource, in the order of `common/strategic_resources.txt`, headed by its icon and its name. **Row r holds the r-th province of each column's resource**, so a row is not a province: the cell's text is `@<holder's tag> <province's name>`, drawn with the flag in text, and the rows' keys are the row's number, so nothing reorders them. Its tooltip: `LEDGER_STRAT_RES_CONTROL_TOOLTIP_1`, the holder's name, the holder's faction in brackets where it has one - green if it is the player's faction, red otherwise, white when the player has none - then `_TOOLTIP_2` and the province's name. Set against the maintainer's screenshot: Aluminium Altenberg, Pixian, Little Rock; Rubber Kuantan, Semarang, Manaus - and that is what comes out of the province order.

**Corrections.** `LedgerPage_Update`'s claim that no page reads simulation fields is wrong: every page builds its rows from `CCountry`/`CMapProvince`/`CUnit` directly; its signature is `ledger@EDI, page@stack`. `BuildLedgerColumnTooltip`'s "+0x1CE0 is the ledger" is confirmed from the opener.

**Not established.** The page 0 gate byte (+0x68 of the country record's interface host). The exact row and flag arithmetic of `FillRows`. The slice angles (`0xAA3090`). The strategic-resource page's precise cell layout. `graph_entry`'s lone reference at `0xAC3C15`. The idler's +0x1CC0 object (hidden at open) and +0x12D8. `CStatisticsLedger` +0x28 (shown after updates; never written in the code read).

Frontier: `0x3BEB80`, `0x3C0CC0`, `0xA70220`, `0xAA3090`, `0xAF1590`, `0x395300`, `0x3BFE00`.

## C. The strategic warfare manager

*Addresses are VAs unless marked rva. "Confirmed" means read off the listing or decompile; the rest is marked.*

**C.1 Opening and closing (confirmed).** `swm_open` (shortcut F8, in `topbar.gui`) toggles the window through `CTopBar::OnStrategicWarfareButton`, stored at glue `+0x2A4` (0x6CBB70).
- Visible: slot 3 (Hide). Hidden: slot 2 (Show), then slot 6, which forwards to the gui window's slot 0x2C; what that slot does was not read.
- `close_button` (shortcut ESCAPE) also calls Hide. It is disabled in a scenario, as `FINDINGS-topbar.md` already says.
- **No call in this class pauses the game or touches the map, and the handler's whole body is the two virtual slots.** The window is `moveable = 1`. CTopBar's per-frame Update calls window slot 5 with 0 while the window is shown.
- Show: the first time ever (`+0x178`) it runs `select_present`, then `Update(force)`.
- Build sets tab 0 (naval) and duration 0 (last month). Tab frames are 2 for the selected tab, 1 otherwise; duration frames are 1 selected, 2 otherwise.
- The file's `size = 550x487` is not the art's: `swm_bg.dds` is 668x568, sub windows 388x492. The file places `close_button` at x=631.

**C.2 What is measured (confirmed, with the save as oracle).** The window reads `CCurrentGameState +0xD68`: the played country plus a `std::map` of one record per enemy. A record is made on the day the played country is found at war with a country that has none, by `GameStrategicWarfare_DailyUpdate`, the first call of `RunDailyPass`, and at session start for a new game.
- A record carries the enemy tag, `start_tick`, `end_tick`, `ended` and `years` = (end_date year - start year + 1); 13 for a 1936 start and 1948 end.
- Each of its **three categories** (0 naval, 1 air, 2 land) has **three rings**: 30 daily, 12 monthly, `years` yearly. Each element is **eight Fixed15 columns**.
- Daily: `AdvanceDay` moves the day ring and zeroes the new slot; the month element is recomputed as the sum of the day ring (so it is a rolling 30 days until the ring closes the month), and the year element as the sum of the month ring. When the day ring wraps to 0 the month ring advances; when the month ring wraps, the year ring advances. Months are 30 days, not calendar months.
- A tally adds to the slot **before** `offset`. The slot at `offset` is the empty new one.
- A record with no war any more is marked ended with `end_tick`, stops advancing, and stays listed forever. If the war comes back its rings are zeroed and `start_tick` reset.
- Saved at top level as `strategic_warfare = { player count <TAG> = { end start_date end_date years container{...}x9 } }`. Two saves carry rings: `Germany1936_03_31_19` (8 enemies) and `Germany1936_09_02_21` (7). The rest of the 76 saves in the folder show `count=0` where listed; I printed the first 60 of the block counts. Those two saves' columns and ring offsets match the layout read from code.

**C.3 Who writes which column (confirmed unless noted).** Columns:

| category | columns |
| --- | --- |
| naval | 0 our convoy IC lost, 1 cargo tons lost, 2 raiders' navy damage IC; 3, 4, 5 the same with the player raiding |
| air | 0 bomber IC lost, 1 province IC damage (buildings, goods at RESOURCE_TO_IC_COST), 2 bomber strength lost, 3 province raw damage; 4-7 the same with the player bombing |
| land | 0 our IC, 1 their IC, 2 our manpower, 3 their manpower |

| event | writer | where the value comes from |
| --- | --- | --- |
| Convoy raid | `ResolveConvoyRaid` to `TallyConvoyRaid` | columns 0/3 and 1/4 and 2/5 via the IC, cargo and damage helpers |
| Bombing end | `CBomberCombatant::ReportBombingEnd` to `RecordBombingEnd` to `TallyBombing` | 4 columns |
| Air combat end | `RecordBomberLosses` from 0x57BCB0 | air column 0/4 |
| Land | `CUnit::SettleCombatDamage` | |
| Land, unit lost whole | `TallyUnitDestroyed`, from RetreatFromCombat, AdvanceMovement, CheckOrderAndCombat | full build cost |
| Land hourly | `OnCombatTick` from `CCombat::Tick` | columns 0..3 |
| Attrition | `ApplyAttrition` to `TallyAttrition` | **only on land controlled by an enemy** (the check in `TallyAttrition`) |
| Naval | `OnNavalCombatEnd` | columns 2 and 5 of a convoy battle, inferred |

**C.4 The list (confirmed).** `listbox_countries` lists every enemy the played country has a record for. The row window `swm_list_entry`:
- `background_button_present` for a running war, `background_button_past` for an ended one; never both.
- `country` is the enemy's name, `country_flag` the enemy's flag, `color_icon` the country's colour.
- `date_begin` is `SWM_RECORDS_BEGIN_DATE` ("From: §Y$DATE$§!"); `date_end` is `SWM_RECORDS_END_DATE` ("To: §Y$DATE$§!") with `$DATE$` = the end date or `SWM_RECORDS_TODAY` ("Today").
- Order: running wars first, ties in map (country id) order. It is `std::sort` with that comparator, so only stable up to 32 rows.
- Rows are rebuilt when the record map changes or the played country does; selected countries are kept by id.
- `select_all`, `select_present` (running on, ended off), `select_none`.

**C.5 What is drawn (confirmed).** Each tab has pairs of line charts: the selected rows' values, one line per selected enemy in the **country's own colour**.

| tab | left chart | right chart |
| --- | --- | --- |
| naval upper | linechart_our_convoy_ic (col 0) | linechart_our_enemy_ic (col 2) |
| naval | linechart_our_convoy_cargo (col 1) | |
| naval lower | linechart_their_enemy_ic (col 5) | linechart_their_convoy_ic (col 3) |
| naval | | linechart_their_convoy_cargo (col 4) |
| air upper | linechart_our_province (col 1) | linechart_our_bombers (col 0) |
| air lower | linechart_their_bombers (col 4) | linechart_their_province (col 5) |
| land upper | linechart_ic_loss_to_us (col 0) | linechart_ic_loss_to_them (col 1) |
| land lower | linechart_man_loss_to_us (col 2) | linechart_man_loss_to_them (col 3) |

- Series order per chart: the selected rows, top to bottom of the list, as the list stands.
- Ring values come newest first, padded with zeros to the ring's size, reversed before drawing so the **newest is at the right**. Unwrapped, the leftmost plotted point is padding and the rightmost is the empty new slot (value 0). Wrapped, that empty slot is the leftmost point.
- Chart scale: common to the two charts of a pair and to both tabs' pairs. **Max = the largest value of all the pair's series, seeded 0.01** (328 in Fixed15 on naval, 0.01 on the others). A point's height = value x 32768 / max x 100 as a whole percent (truncated). The chart's drawn height is percent / 100 (`+0x178` taken as 100, inferred from the shader).
- `GFX_swm_linechart` (154x88, linewidth 3, outline yes) is drawn with `gfx/FX/linechart.fx`: at most 40 points; x = index x width / pointCount, so the last point stops short of the right edge; y = top + height x (1 - h); half width = linewidth / 2; a black outline where `bIsOutline`. With no series selected: a single line of height 0 and three points (default colour).

**Text (the code overrides the file's `text`):**

| element | key | value |
| --- | --- | --- |
| max | `SWM_GRAPH_MAX_IC_VAL` / `_MAN_VAL` / `_TONS_VAL` | $MAX$ with 2 decimals, Fixed15 |
| `*_avg_ic`, `*_loss_avg_*` | `SWM_GRAPH_TOTAL_VAL` "Total: $TOT$" | 2 decimals, the column's sum over the duration ring; the file's `SWM_GRAPH_AVG_VAL` is never used, and the "Avg" text is a total |
| air `*_total_dam` | `SWM_GRAPH_TOTAL_DAMAGE_VAL` "Total Damage: $TOT$" | sum of columns 3 and 2, or 7 and 6 |
| cargo_desc_* | `SWM_CARGO_LOST_DESC_<duration+1>` / `SWM_CARGO_SUNK_DESC_<...>` | $NUM$ 2 decimals |
| air descs | `SWM_OUR_PROV_IC_LOSS_DESC_n` / `_THEIR_PROV_...` | $IC$ 1 decimal, the province IC total of the shown duration |
| air descs | `our_bombers_desc` uses `SWM_THEIR_BOMBERS_IC_LOSS_DESC_n`; `their_bombers_desc` uses `SWM_OUR_BOMBERS_IC_LOSS_DESC_n` | names cross over, as in the original |

**Comparators (frames of `GFX_swm_comparators`, 3 frames):**

| comparator | a | b | threshold | frame |
| --- | --- | --- | --- | --- |
| comparator_our (naval) | total col 0 | total col 2 | 8.0 | |a-b| <= threshold: 3; else a < b: 2; else 1 |
| comparator_their (naval) | col 3 | col 5 | 8.0 | same |
| comparator_ic (land) | col 0 | col 1 | 8.0 | |a-b| <= threshold: 3; else b < a: 2; else 1 |
| comparator_man (land) | col 2 | col 3 | 2.0 | as comparator_ic |

**C.6 Tooltips (confirmed; `BuildStratWarfareTooltip`).** Tabs: `SWM_TOOLTIP_TAB_NAVAL/_AIR/_LAND`. Each chart's own key (all in `tfh/localisation/tfh.csv`):

| key | text |
| --- | --- |
| NAVAL_OUR_CONVOYS | "The estimated IC cost of convoys that §Ywe§! have lost." |
| NAVAL_OUR_ATTACKERS | "The estimated IC cost of §Yenemy§! naval units (repairing cost + rebuilding lost ships) that suffered damage in their raids on our convoys." |
| NAVAL_OUR_CARGO | "The estimated cargo sunk together with §Your§! convoys." |
| NAVAL_THEIR_CONVOYS | "The estimated IC cost of §Yenemy§! convoys that we sank in convoy raids." |
| NAVAL_THEIR_ATTACKERS | "The estimated IC cost of §Your§! naval units (repairing cost + rebuilding lost ships) that suffered damage in our raids on enemy convoys." |
| NAVAL_THEIR_CARGO | "The estimated cargo sunk together with §Yenemy§! convoys." |
| AIR_OUR_PROVINCE | "The estimated damage done in §Your§! provinces by enemy bombers.\nThis includes damaged buildings, destroyed goods and supplies, and damaged land units." |
| AIR_OUR_BOMBERS | "The estimated damage done to §Yenemy§! bombers." |
| AIR_THEIR_PROVINCE | "The estimated damage done to §Yenemy§! provinces by our bombers.\nThis includes damaged buildings, destroyed goods and supplies, and damaged land units." |
| AIR_THEIR_BOMBERS | "The estimated damage done to §Your§! bombers." |
| LAND_IC_US | "The estimated IC cost of reinforcement/rebuilding of §Your§! land units that have suffered damage in combat." |
| LAND_IC_THEM | same with §Yenemy§! |
| LAND_MAN_US | "The estimated Manpower cost of reinforcement/rebuilding of §Your§! land units that have suffered damage in combat." |
| LAND_MAN_THEM | same with §Yenemy§! |

Every other element inside a shown window gives an empty tooltip: `CTopBar::BuildTooltip` returns straight after the call, gated on the window being visible and containing the element. Only the shown tab's charts answer. `swm_open` itself has no tooltip key in `CTopBar::BuildTooltip`, as far as the reading of that function goes. `SWM_BUTTON_SHOW` appears in no `.gui` file under the two `interface` folders and not in the rdata strings.

**Greying:** `swm_open` is disabled in a scenario (FINDINGS-topbar); nothing in the window is greyed by code. **Declared but untouched:** `SWM_MAX_DAMAGE`, the `*_DAMAGE_DESC_*` keys, `SWM_GRAPH_MAX_IC_VAL2`, `SWM_GRAPH_TOTAL_DAMAGE_VAL`'s German text. `SWM_DURATION_n`, `SWM_SELECT_*`, `SWM_GRAPH_HEADER_*`, `SWM_LOSSES_*` and `SWM_STRATEGIC_WARFARE_OVERVIEW` come from the `.gui` file, as do the tab titles (`Naval`, `Air`, `Land`, plain strings in the file).

**Not established.** The gui window's slot 0x2C and slot 0x78 (with "topbar") in Build. The comparator art, so which frame looks like what. Whether LineChart's `+0x178` is 100 (inferred from the shader). What created a record at hour 9 in one save (`POL`, `1936.1.27.9`; every other is hour 0). The third naval writer's exact arms (the naval end tally, inferred). Confidence in the writer semantics: confirmed from the decompile, but none of this was tested in a running game.

Frontier: `0x46B760` (a localised text with one replacement), `0x46BB70` (the std::sort instance), `0x461CB0`, `0xA7F7B0` (generic list item select), `0x4CCCC0` (country colour), `0x424050`, and what the two line-chart tokens `0x166`/`0x1BA` are by name.

## D. What a plan wants and is short of

Everything below is `confirmed` on the listing unless marked. Numbers in thousandths are written as such; figures are **exe-hardcoded** unless a define is named. Nothing here is mod-able except through unit keys (`common/units`), the availability of types by technology, and `usable_by`.

### D.1 `CUnit::UpdatePlanForceNeeds` (rva `0x1BD240`)

Five arguments, `ret 0x14`: the unit, three out-vectors `difference`, `groupDifference`, `needed`, and `provinces` (a list of provinces, or null). All three vectors are indexed by the sub-unit type index.

- **Growth.** N = the database's type count. If `difference` is empty, all three are grown by N zeros; `needed` is grown whatever it already holds. Otherwise `groupDifference` and `needed` are zeroed and `difference` is left for the write below. A row of the screen always passes fresh local `difference` and `groupDifference`, so each update appends N zeros to the row's `needed` (`+0x184`) and rewrites only positive entries. A row updated a second time (the stance button sets its dirty flag) therefore keeps old positive entries where the new answer is not positive. Only the first N entries are read.
- **The gate.** Walk `higher_oob_unit_ptr` to the top of the order of battle. If the top unit's plan is active and its `oob_level` is 0, nothing is computed. Otherwise:
  - `provinces` null (the **null arm**): zero the plan's `our_power` and `their_power`, then `ComputePlanWantedSubUnits(plan, unit, &plan.ops_area, &plan.min, &our, &their, false)`. This writes the plan's own `min`, `our_power` and `their_power`.
  - `provinces` given (the **area arm**): the same call with the list, a local vector, two locals and `true`. The plan is not touched.
- **wanted** is the local vector if it is non-empty, else `plan.min`. So with an active top plan even the area arm uses `plan.min`, and every row of that theatre shows the same.
- **The vectors.** If `wanted` is non-empty, `have = CUnit::CountSubUnitsByType(unit)`, which counts the brigades in the unit and all descendants. It has no area filter and does **not** count queue lines or units waiting to be placed.
  - `difference[i] = wanted[i] - have[i]`, signed.
  - `groupDifference[SubUnitTypeGroup(i)] += difference[i]` where that is non-zero.
  - Over a **copy** of `groupDifference`, for ascending `i` with `difference[i] > 0`: `x = min(difference[i], copy[group(i)])`; if `x > 0` then `needed[i] = x` and `copy[group(i)] -= x`, and the function answers true.
  - An empty `wanted` leaves `difference` as it was, the other two zeroed, and answers false.
- **In words.** `+0x5C` is wanted minus have per type, negative for a surplus. `+0x6C` is the same summed onto each group's representative type (by `SubUnitTypeGroup`, so a surplus of infantry cancels a shortage of garrison or motorized). `+0x7C` is the positive part per type, lower type indices first, capped by what the group is still short of. A surplus inside a group therefore cancels another type's deficit.

The screen's `immediate_needs` reads `+0x7C` (confirmed at `0x470297`-`0x47029D`, which compares its length with the database's count).

### D.2 `ComputePlanWantedSubUnits` (rva `0x4E1D00`)

Called only from the two arms above. Arguments are as listed in D.1. `wanted` is grown to N entries and zeroed first.

**Types resolved**, each kept only where `unit_available` and `usable_by` admit it:

| role | chain |
| --- | --- |
| armour | `armor_brigade` -> `light_armor_brigade` -> `mechanized_brigade` -> `motorized_brigade` -> `infantry_brigade` |
| fast | `mechanized_brigade` -> `motorized_brigade` -> `cavalry_brigade` -> `infantry_brigade` |
| mountain | `bergsjaeger_brigade` -> `infantry_brigade` |
| garrison | `garrison_brigade` -> `infantry_brigade` |
| aircraft | `tactical_bomber` and `interceptor`, tested for nothing |

An `anti_tank_brigade` availability test is made and its answer dropped.

**Own brigades** come from `CUnit::CollectRegiments(unit, useArea ? provinces : null)`. An army in the area arm is taken only if its destination (the last province of its path, else its current province) is on the list; navies and air units are always taken. Land brigades are counted by `SubUnitDefinition_GetRole`: role 3 armour, 4 fast, 5 garrison, 6 mountain, 0 not counted, anything else infantry. Non-land brigades count only as the two aircraft types, exactly. Each brigade also adds to `our` `(value x (strength/max x organisation/max))`, each ratio in thousandths and truncated. A zero maximum gives -1 for that ratio.

**Garrison target.** Area arm: the count of `provinces` whose controller is the unit's owner and whose `CUnitPlan_ProvinceHoldScore` is 25 or more. Null arm: the same over the theatre provinces of the nearest CAIUnit up the chain (`GetArea()+0x60`); 0 if none.

**Enemy census**, over each province of `provinces` (the ops area in the null arm; for an active-top row this never runs):

- For each edge not of kind 3 to a simulated land province whose controller is not `IsFriend(owner, c, true)`, take that province once.
- `mountainEnemy++` if its terrain is mountain (not plains).
- For each unit on it that is not friendly, for each brigade not a ship: land -> `E++`, role 3 `Ea++`, role 4 `Ef++`; air -> `Air++`. Every such brigade adds its raw combat value to `their`.
- The own side's `mountainOwn` counts mountain provinces among `provinces` themselves. The mountain target is `3 x max(mountainOwn, mountainEnemy)`.

**Scale s** (thousandths):

- Area arm: **s = 200**, because the test on the "enemy" (`0`, own tag, or a war or REB check) always passes. That variable holds the unit's own tag (store at `0x8E260D`; a slip for the foreign unit's owner), so the lookup can only find an entry keyed by the country itself or by id 0. The 1 January 1936 save holds none for the country itself nor for REB. Whether any list can hold country id 0 is **not settled**, so the "always 200" conclusion has that one caveat.
- Null arm: at war 1000. At peace 200, replaced by `top threat weight x 5` if that weight is above 0, then raised to `top antagonize weight x 5` if higher.
- Then cap 1000, floor 100.

**Stance factor k** by `plan+0xC`: 2 -> 1500, 3 -> 2000, 4 -> 2500, else 1000. Define:

- `B = trunc(E x k)`, `Ba = trunc(Ea x k)`, `Bf = trunc(Ef x k)`.
- `A = trunc(B x 1.5k)`, and `Aa`, `Af` likewise.
- `1.5k` is the fixed-point `(1500 x k)/1000`.

**Base S.** Area arm: `trunc(count(provinces) x s x 9 / 1000)`. Null arm: `trunc(CUnit_PlanBaseBrigades(unit) x s / 1000)`, where the base is 3 at level 4, 9 at level 3, 27 at level 2, 81 at level 1; at level 0 the sum over direct children, at least 9; and any other level 0. At peace only: `S = min(S, TotalIC x m)`, with m = 10 for a faction leader, 4 for a faction member, else 1, and x4 more when the ruling ideology group is not democracy. Then `S = max(S, 3)`. **The cap compares brigades with IC in thousandths, so it binds only for a country with almost no IC; it is effectively not there.**

**Targets:**

- `H = max(S, A)`, `L = max(S/2, B)`.
- Armour: `Ha = max(avail ? H/5 : 0, Aa)`, `La = max(avail ? L/5 : 0, Ba)`.
- Fast: `Hf = max(H/4, Af)`, `Lf = max(L/4, Bf)`.
- Infantry: `Hi = H - Hf - Ha`, `Li = L - Lf - La`.

Division truncates toward zero.

**`wanted` is what is to be ADDED, net of the unit's brigades by role.** Each type adds `max(0, min(low, high) - have)`, written as a loop of `high - have` steps each adding one while `low-- > have`. The infantry steps pick in order: `bergsjaeger` while `mountainTarget-- >= mountainHave`, then `garrison` while `garrisonTarget-- >= garrisonHave`, then `infantry`, each adding only while `infantryLow-- > infantryHave`. **Because the test is `>=`, one mountain step is taken even with no mountains and none in the unit** (the same off-by-one applies to garrison).

**Aircraft.** `n = 9`, or 3 at `oob_level` 2, 0 at level 3. `AA = trunc(n x s / 1000)`, `BB = AA/2`. Level 0 or 1: `AA >= 3`, `BB >= 1`. Level 2: `AA >= 1`. Then both are at least `Air`. Tactical bomber high = `AA - AA/3`, low = `BB - BB/3`; interceptor high = `AA/3`, low = `BB/3`; each adds `max(0, min(low, high) - have)` of that exact type.

**So a shortage is subtracted twice.** `wanted` already subtracts the role count, and `difference` subtracts the exact-type count: a deficit of `L - h` becomes `L - h - h`, in practice `L - 2h` where the type and role counts agree. In the area arm `h` is only what stands in the area, but the second subtraction is the whole theatre's, so a row almost always answers "no needs". This is the original's; do not tidy it.

### D.3 `CUnitPlan_ProvinceHoldScore` (rva `0x4E1160`)

`int (plan, unit, province)`, truncated. C is the unit's owner. Returns 0 if `MaxInfrastructure` (`+0x5C`) is below 0.2.

Over edges not of kind 3 to a simulated land province N:

- If the province has no VP, is not its own supply depot, and `IsWarCandidate(C, N.controller)`: return 0.
- FRA facing BEL or LUX (or BEL facing LUX), that controller not C's subject, GER holding land, not in C's faction, and not `IsEnemy(GER, N.controller, N)`: `sum += 4000; count++`.
- Otherwise, N's controller unfriendly: `t = GetThreat(C, N.controller)`, plus antagonism at peace when the nearest agent's `+0x3C` is set; `t >= 100`: `sum += t; count++`.
- `count > 0`: `v = sum / count / 20 + count`.

Then (the sibling of `CAIUnit_ProvinceHoldValue`):

- The first unfriendly neighbour with threat >= 100 or front-worthy: `v += 3 x fort level`.
- Coastal fort: `5 x (cf + 1)`.
- `w` = air base level, plus naval (for GER and ITA `x = (5n + 15) x 2`, above 100 `(x - 100)/5 + 90`; others `x = n`). `w x2` outside the controller's capital area when the area has under 15 provinces. `v += w`.
- VP: owned by C, `max(VP x 100 / (victory_points_owned/1000), 2VP + 10)`; controlled by C and the owner not in exile, `2VP + 10`.
- Acting capital +100; strategic resource +60; `+ (IC modifier id 15 / 1000) x max(effective revolt, minimum revolt, 0)/1000`; own supply depot +100.
- Naval level > 0 with a naval station: `+ 30 + 2 x ships of naval units there`.
- `+ 0.25 x` the plan's objective priority on this province.
- If the nearest agent's `+0x3C` is set: `+` the controller's `defend_prov` entry for the province.

### D.4 Who runs it and when

- **`CUnit::UpdateDaily`** (rva `0x1BAF70`, inlined gate at `0x1BB273`): `oob_level >= 4` skip; level 0 runs the null arm; level 1-3 with `ai_agent` set runs the null arm; otherwise all three vectors are emptied. **`CUnit::RefreshPlanForceNeeds`** (`0x1BD6F0`) is the same gate out of line, called from `CSetPlanForcesCommand::Execute` (after `CUnitPlan::SetMinForces`), `CSetPlanAttributesCommand::Execute` (stance change only) and `CSetPlanOpsAreaCommand::Execute`.
- **`CSetPlanForcesCommand`** replaces `plan.min`, and a refresh follows. With the plan active the compute is skipped, so `+0x7C` is `min` minus what the unit has.
- **A played country's theatre.** The plan is never switched on, so the null arm rebuilds `plan.min` daily and `+0x7C` comes from it. The evidence is that `plan` is saved only where active and `oob_level` is under 4 (`CUnit::SaveContents`), and Germany (player) has no plan block on its two theatres in `Germany1936_01_04_12.hoi3`. (`ops_area` empty is inferred: nothing sets one on an inactive plan as far as read.) The start save shows no plan block anywhere.
- **An AI country's theatre.** Before the agent binds (start date) the plan is inactive, so the null arm holds, unsaved. Once bound the plan is active and the six aircraft wants (`CAIUnit_ComputePlanForces`, `0x4B5210`) sit in `min`, so `+0x7C` is positive only for aircraft types.
- **`CUnit_FindTheatre`** (rva `0x1D2A00`): `FindTheatreForUnit`, which walks to the topmost unit of the chain and finds the `CTheatre` whose `unit` is it. Already clear in the record; not changed.

### D.5 Against the saves

- **Agrees, confirmed:** all 106 plans in `Germany1936_01_04_12` are `active=yes`, and `min` is non-zero only at indices 29 (interceptor), 39 and 53 there and in `Germany1936_04_20_03`. The same holds with later aircraft indices 38 and 56 added in `Ireland1940_05_23_20` and `Soviet_Union1941_07_16_21`. Germany's `Ob.kdo. des Heeres` and `OB West` have no plan block. This is what the gate and the save condition predict.
- **Not testable from any save:** the null arm's land composition and any `needed` vector, because neither is saved.
- **Prediction, not checked against anything** (`Germany1936_01_01_00`): Germany is at peace with FRA as top threat and antagonize (weight 400, x5 = 2000, capped), so s = 1000. `Ob.kdo. des Heeres`: base 117 (one army group 81 plus four corps 9 each; navy and air count 0), S = 117, H = 117, L = 58. `OB West`: seven corps, base 63, S = 63, H = 63, L = 31. Which armour or fast type the chains resolve to depends on Germany's technologies, not read here.

**Not established:**

- Whether a threat or antagonize list can hold country id 0.
- Whether a played country's inactive plan ever carries an `ops_area`. If it does, the enemy terms come alive and the stance factor matters; default stance for an inactive plan was not re-verified beyond the record.
- The caller at VA `0x7376B0` (rva `0x3376B0`) of `CUnit::CollectRegiments`, unread.

Frontier: the unread caller of `CUnit::CollectRegiments` at rva `0x3376B0`.
