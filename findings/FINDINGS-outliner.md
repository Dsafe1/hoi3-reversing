# The outliner: the list down the side of the in-game screen

Read on 2026-11-03 by a wave of three readers (`WAVE.md`, "The outliner wave"), for OpenHOI3's interface, which builds
its screens from the original's `.gui` files and needs what each window does. The window is `outliner` in
`interface/outliner.gui`; the code is VA `0x6A3000`-`0x6B6A00` and the top bar's `CTopBar::SyncOutliner`. The oracle was
three screenshots of the maintainer's: a land battle row "7%" and "Gurbo" with its tooltip, the land units' tree of
"100.0%" rows with an army's tooltip, and the naval units' whole numbers. Every figure in them is accounted for below.

## In one paragraph

`COutLiner` (0x80 bytes, made by every `CTopBar::Build`, kept at `CTopBar +0x378`) is a window of nine sections in a
fixed order - land, naval and air battles, land, naval and air units, allied objectives, our bombings, hostile bombing -
each shown only when its switch at the top is on and it has an entry, under a title row naming it. The switches live in
`settings.txt`'s `outliner = { }` key, with 10 meaning "open". Every frame it gathers what each section would hold, and
rebuilds the rows only where that has changed; otherwise each row updates its own figures. The units are the player's
own, each root followed by the tree below it where a unit has been expanded - a byte on the unit, never saved. A land
unit shows its strength as a percentage, a fleet its ships and an air unit its wings; a land battle shows the
attacker's share, green where the player attacks and negated in red where he defends; sea and air battles the two
sides' ships or planes. A click on a row selects it and centres the map; nothing in the outliner answers a right click
or a double click.

## What this corrects

1. `BuildOutlinerHeaderTooltip` (`0x2AE0D0`) is not a tooltip: it is the title of a section by its kind, now
   `GetOutlinerKindTitle`, `confirmed` - and its old confidence word, `likely`, was not one the record takes.
2. `CCombatMember::BuildTooltip` (`0x2A9E90`) builds a `GuiTooltipText` for an element, not a string; its `PROGRESS` is
   the attacker's strength share, not odds. Now `confirmed`.
3. `CTopBar::SyncOutliner` (`0x2CB920`) is the outliner's per-frame driver and hides it behind the full-screen views, as
   well as setting the top bar's button. `CTopBar +0x378`/`+0x37C` are the outliner and "hidden by a view".
4. **The 30-widget leak** of `FINDINGS-guilive.md`, point 5, is explained: every `COutLiner::Show` makes ten new title
   rows, and nothing frees them (A, *What looks wrong*, 1).
5. **`outliner_province_entry` (with `occupied` and `siege`), `outliner_standard_entry` and `outliner_unit_entry` are
   dead**: the file declares them and no code names them. There is no province row.

**Two names for one pair of slots.** Slots 15 and 16 of the row classes are named `IsWanted`/`NoteShown` on the unit
rows (B) and `IsStillCurrent`/`MarkShown` on the others (C), each recorded on its own classes; they are the same pair -
whether the row still belongs to what the frame gathered, and noting that it was shown - and the base class's slots are
left unnamed. One of the two should be chosen when the base is read.

## A. The window and its list

Addresses are virtual (image base 0x400000). "Hardcoded" means it is in the executable. "Mod-able" names the file that changes it.

### A.1 The object, and where it is shown

- **What it is.** The outliner is `COutLiner`, 0x80 bytes. It has no RTTI of its own; the name comes from `CButtonObserverGlue<COutLiner>`. It hangs off the top bar at `CTopBar +0x378`.
- **When it is made.** Every `CTopBar::Build` frees the old one and makes a new one (0x6CC59F..0x6CC5F9). The constructor (0x6A3210):
  - makes the `outliner` window;
  - makes the `outliner_configuration` window;
  - attaches the stand-alone `outliner_bottom` icon as `bottom`;
  - finds the nine view switches by name and gives each the element group `outliner`;
  - makes twelve sections, kinds 0..11.
  - *Confirmed.*
- **Open and close.** `topbar_outlinerbutton` is a toggle (`CTopBar::OnOutlinerButton`, 0x6CFEA0). Open → Hide, button frame 1. Closed → button frame 2, Show. The top bar's Build sets the button's frame from IsVisible. *Confirmed.*
- **Behind full-screen screens** (`CTopBar::SyncOutliner`). While any country view is open (diplomacy, production, technology, politics, intelligence, theatre: the idler's `views[open_view]` IsOpen), or while the ledger is (`idler +0x1CE0`):
  - an open outliner is closed and `CTopBar +0x37C` is set;
  - the top-bar button is hidden.
  - When both are gone, the button comes back. If the outliner was closed this way, it reopens.
  - *Confirmed.*
- **Across sessions.** Show adds 10 to the settings' `outliner` list and Hide removes it. The constructor opens the outliner when 10 is in that list. So the outliner reopens on entering a game if it was open when the settings were last written. *Confirmed.*
- **Custom game mode.** The custom-game bar (`0x426D40`) opens it if it is closed. *Inferred* (the class is inferred).
- **Placement.** Window `outliner` is UPPER_RIGHT at (-220, 47). The list is at (0, 33) with spacing 2. *Mod-able:* `interface/outliner.gui`.

### A.2 The sections, their titles and their switches (kinds hardcoded)

Kinds 1-9, in **list order**. Titles are `GetOutlinerKindTitle(kind)`.

| kind | title key | English | switch element |
| --- | --- | --- | --- |
| 1 | OL_COMBATS | Land Combat | outliner_view_landcombat |
| 2 | OL_NAVAL_COMBAT | Naval Combat | outliner_view_navalcombat |
| 3 | OL_AIR_COMBAT | Air Combat | outliner_view_aircombat |
| 4 | ARMIES | Land Units | outliner_view_landunits |
| 5 | NAVIES | Naval Units | outliner_view_navalunits |
| 6 | OL_AIR_UNITS | Air Units | outliner_view_airunits |
| 7 | OL_ALLIED_OBJECTIVE | Allied Objectives | outliner_view_ao |
| 8 | OL_WE_BOMB | Our Bombings | **outliner_view_bombonus** |
| 9 | OL_BOMB_ON_US | Hostile Bombing | **outliner_view_bombonthem** |

- Kind 11 holds the header rows (`CTitleMember`). Kinds 0 and 10 are never filled. *Confirmed* (0x6AE0D0's switch; the stores 0x6A3A06..0x6A3C66).
- **A switch's tooltip is its section's title** (`COutLiner::BuildTooltip`). *Confirmed.*
- **A section appears only when its switch is on and it has at least one entry.** An empty section shows no title either (AddSectionRows' count test). *Confirmed.*

### A.3 Where the switches are kept, and their defaults

- **The settings key.** The player's `settings.txt` key `outliner = { ... }` (`GameSettings +0x164`) is a set of numbers:
  - 1-9: that section's switch is on;
  - 10: the outliner is open.
  - Order means nothing. Reading the key replaces the list whole.
- **Defaults.**
  - No key at all: {10, 4, 5, 6} (open; land, naval and air units). Hardcoded, in the settings constructor.
  - The install's shipped `settings.txt`: {1 2 3 4 5 6 7 8 9} (closed, all on).
  - *Confirmed.*
- **When it changes.** The in-memory list changes the moment a switch changes (`COutlinerSection::SetWanted`). The file is written by `0xAB1CE0`. The outliner calls that only from the configuration window's close button; the other four callers are elsewhere and were not read. *Inferred:* that `0xAB1CE0` writes the file.
- **How a switch takes effect.** The switches are polled every frame: checked → wanted; unchecked and shown → not wanted. A section's `shown` copies `wanted` at the end of each pass, and the next pass's comparison rebuilds. So a switch takes effect within a frame or two. *Confirmed.*
- **Oracle mismatch.** The maintainer's current `Documents\...\settings.txt` reads {2 3 7 8 9 1 10}: open, but land, naval and air units switched off. His screenshot shows Land Units and Naval Units, so the screenshot must predate the file. Worth asking him.

### A.4 What each section holds, and in what order

**The units (kinds 4-6).** The player's country's units are walked in `CCountry::GetUnits` order. A unit is a **root** when it has no parent, or when it is a fleet or air unit whose parent is a land unit (0x5D39F0).
- **Air Units:**
  - root air units;
  - except where any unit above it has an AI agent (`CUnit +0x198`), which means a theatre left to the AI (*inferred*);
  - except an all-carrier-air-group unit whose base is a carrier (base slot 1 answers true only for `CUnitBaseCarrier`).
- **Naval Units:** root fleets, with the same AI-agent exclusion.
- **Land Units:** land units with no parent. There is **no AI-agent test** for these.
- **The tree under each root.** Each root is followed, depth first, by its children (`CUnit +0x1E4`, in that list's order), recursively. A unit's children are listed only where its `CUnit +0xB4` byte is set (expanded); a collapsed unit hides everything below it. Depth is unlimited.
  - Children are whatever the hierarchy holds. **A fleet or air group attached to a land HQ therefore appears twice**: under its HQ in Land Units (as a `CArmyMember`) and as a root in Naval or Air Units. That matches the screenshot ("19a Squadra di Marina", "Aeronautica AOI" inside the land tree).
- **Row classes.** Every Land Units row is a `CArmyMember`, whatever its type. Naval Units rows are `CNavyMember` and Air Units rows are `CAirMember`; each is given its base's province, or else the unit's own province.
- *Confirmed*, except the AI-agent meaning.

**The battles (kinds 1-3).** For each of the player's units in a battle, each live battle on its list (combat slot 9) is listed once, in first-met order: land → 1, naval → 2, air → 3.

**The bombings (kinds 8 and 9).** For each of the player's units in a bombing (`CUnit +0x110`):
- the unit is an air unit owned by the player → **Our Bombings (8)**;
- otherwise → **Hostile Bombing (9)**.

The bombing's kind and which side the unit is on are not tested. A bombing with no unit of ours in it is not listed. *Confirmed*, given the record's "bombings live only at +0x110".

**Allied Objectives (7).** One row per province record:
- first, `gamestate +0xB9C[player]`: what allies asked of us (`CAlliedObjectiveMember` flag 1);
- then, `+0xBAC[player]`: what we asked of them (flag 0).
- A province asked by several allies is one row.
- *Confirmed.*

**Layout of the list.** The list is: for each kind 1..9 in order that is wanted and non-empty, its title row, then its rows. *Confirmed.*

### A.5 Size

- **Height.** The list's height is min(the summed row heights, max_list_height). Hardcoded: max_list_height = ((screen height − 358) / 16) · 16 − 48, which is 672 at 1080.
- **Width.** The width becomes the first row's width.
- **Bottom cap.** `outliner_bottom` is moved to just under the list, at x 0 and y = the list's y + its height.
- **Empty outliner.** With no rows the list is 0 high, so only the top strip and the cap show.
- *Confirmed.*

### A.6 When it is rebuilt

- **Refresh runs every frame while the outliner is open:** `CInGameIdler::Update` (0x655AEF) → 0x64F850 → `CTopBar::Update` → `SyncOutliner` → `COutLiner::Refresh`. In custom game mode, the custom-game bar calls SyncOutliner instead.
- **What triggers a rebuild.** Refresh rebuilds the rows only when one of these differs from the freshly gathered contents:
  - for any of kinds 1-9, the row count or the object behind any row, compared in order (allied objectives by count only);
  - or `COutLiner +0x7C` is set — set by `CSetCountryControllerCommand`'s Execute when control of a country changes.
- **A change in expansion** changes the flattened unit list, so it rebuilds.
- **Otherwise** every row's slot 8 (Update) runs, which keeps each row's figures current every frame.
- **Scroll.** A rebuild keeps the scroll position (saved first, `ListBox_RestoreScroll` after).
- *Confirmed.*

### A.7 Clicks, keys, tooltips

- **No clicks or keys here.** COutLiner itself handles no click, double click, right click or key. Rows handle their own (readers B and C: CCombatMember::OnClick, CArmyMember::OnExpandClicked, and so on). *Confirmed:* no observer in COutLiner but the configuration close button.
- **Tooltips.** Elements with group `outliner` are routed by `CInGameIdler::GetElementTooltip` → `CTopBar_OutlinerTooltip` → `COutLiner::BuildTooltip`.

### A.8 The configuration window (`outliner_configuration`)

- **What it holds.** Nine `outliner_configuration_entry` rows (`CConfigMember`, kinds 1..9). Each has an `outliner_checkbox` (checked from the settings) and `outliner_list_text` = the section title.
- **What it does.** Ticking a row sets wanted and edits the settings list. The close button hides the window and calls the settings writer.
- **It is never shown.** Nothing found shows it: the constructor hides it, the close button hides it, and a sweep finds no reader of `COutLiner +0x18` outside these. The positive control, the same sweep for `+0x7C`, finds its one writer. *Inferred:* unreachable in the shipped game.
- **It would not hold anyway.** Its ticks would be undone each frame by the polled top switches, which are never updated to match.

### What looks wrong but is what the bytes do

1. **The leak.** Show makes ten `CTitleMember` into section 11 every time, and nothing ever deletes them. Every close and open, which every full-screen screen causes, leaves ten `outliner_header_entry` windows behind: exactly the 30 widgets per cycle measured live.
2. **Show mislabels battles for a frame.** Show gathers kinds 1, 2 and 3 into one list it never empties between calls. Section 2 therefore also gets the land battles, and section 3 the land and naval ones, each as a row of that section's class. The next frame's Refresh replaces them.
3. **The bombing switches look swapped.** `outliner_view_bombonus` toggles "Our Bombings" and `_bombonthem` toggles "Hostile Bombing". Their tooltips say the section names, so a player sees consistent text.
4. **Air units are classed by type, not side.** An air unit of ours on the defending side of a bombing (at its own base) is listed under Our Bombings.
5. **Bombings 8 and 9 are compared by count only, unless there is a land battle.** For those two sections the walk of the rows is gated on the *land battle* count ([ebp−0x190] at 0x6A55B7 and 0x6A5779), so it runs only when there is a land battle. With none, a bombing swapped for another without the count changing is not noticed.
6. **A dead branch.** A bombing branch in `OutlinerScan_CollectCombats` tests kinds `4 || 5 || 5` (kind 6 never). It is dead, because bombings are never on a unit's battle list.
7. **Ticking a configuration row adds its kind twice.** `CConfigMember::OnChecked` appends the kind to the settings list after `SetWanted` has already added it; unticking removes it twice.
8. **One-frame height glitches.** A rebuild sizes the list by row heights without the spacing; the next frame measures with it, so the list grows 2 px per row a frame later. FillList also starts from the list's pre-emptying height.
9. **Bad settings values.** A settings value above 11 would index past the twelve sections in the constructor.

### What could not be settled

- **What `0xAB1CE0` does.** It is called with the settings object in ESI; that it writes `settings.txt` is inferred.
- **What the AI agent means.** That `CUnit +0x198` on a unit's superior means "theatre left to the AI" is inferred.
- **The first of the five battle-list fields.** What `OutlinerScan +0` (the controlled provinces) is for: it is stored and not used.
- **Top-bar window slot 11.** OnOutlinerButton calls it after Show; it was not read.
- **The screenshot's round button.** Most likely `topbar_outlinerbutton`; not checked against `topbar.gui`.

### Frontier

- `0xAB1CE0` (settings apply/write).
- `0x6D3390`: `CSetCountryControllerCommand` slot 6, unrecorded; only its tail was read.
- EH-unwind wrappers: `0x6A31F0`, `0x6A40F0`, `0x6A4110`.
- CList / vector<COutlinerSection> template helpers: `0x6A8920`, `0x6A9040`, `0x6A9270`, `0x6A88C0`..`0x6A99B0`.
- `0x62D8B0`: the list's scroll position, the counterpart of `ListBox_RestoreScroll`.
- `0xA8BBD0`: the list-item base constructor.
- `0x679400`: sets a list's size.
- `0xAA2290`: sets an element's position.
- `0x414860`: builds a short pair.
- `0x6797E0`: a list node's value.
- The two observer-glue tables are listed in the fragment's `slots_noted`, deliberately unrecorded.

## B. The unit rows

All addresses below are virtual addresses (VA). Read headless against a copy of the Ghidra project and checked against the disassembly. Confidence is `confirmed` unless marked otherwise.

### B.1 What a unit row is built from

Every unit row is two windows.
- **The row window** is `outliner_unit_entry_bg`. It holds only the background button `outliner_standard`, and the base class keeps it at `+0x20`.
- **The unit window** is `outliner_top_unit_entry`, holding `expand_button`, `entry_text`, `info_text` and `movment`. The row keeps it at `+0x118` (land) or `+0xCC` (fleet and air), and returns it through slot 17.
- The unit window is tagged `outliner` (its `+0x18` object's slot 30), so the outliner's tooltips answer for its elements. It is added to the row window under the key `items`.
- **The `outliner_unit_entry` window in `outliner.gui` is never used.** No code names it; the only similar string is `outliner_unit_entry_bg`.

All three rows are 0x120 bytes. They are made in the outliner's rebuild: the land row at 0x6A6492, the fleet row at 0x6A66EF, the air row at 0x6A694C. Their constructors are `__stdcall`, with the memory and the unit on the stack. The fleet and air constructors take a third argument, a province.

**A fleet or air row can stand for a base.** When the constructor is given no unit, the row stands for the province's naval base (province `+0x58`) or air base (province `+0x54`).
- Its name is the province's name.
- Its children are the fleets or wings based there.
- Its count is the base's `units_count` (`+0xC`).

Land rows have no such case.

Slot 12 answers the row's kind, as one shared "return a constant" body per value: land 4, fleet 5, air 6. For comparison, the other rows answer: combat 1, naval combat 2, allied objective 7, title 11.

### B.2 The name, `entry_text`

**Land row** (`CArmyMember_RefreshEntryText`, 0x6B0320). The parts, in order:
1. `§G` if the unit or any unit above it has an AI agent (`CUnit +0x198`). This is the green name of a command handed to the AI. The colour is never closed.
2. `CUnit::GetShortName(21)`: a name longer than 21 characters becomes its first **18 characters plus `...`**.
3. If no AI agent is in the chain and the unit has its own aggression setting (`+0x4A`), a star (`CUnit_AggressionStarText`):
   - `§R*§!` when aggression (`+0x4C`) is above 100, i.e. above 0.1;
   - `§B*§!` when it is below −100;
   - `§g*§!` otherwise.
4. If the unit is in one of the player's selection groups, `(§Y` + the group number + `§W) `. This is the first group 0–9 that holds it (`CCurrentGameState::GetUnitSelectionGroup`).

There is **no space before the bracket and one after it**, e.g. `I. Armeekorps(§Y1§W) `. That is what the concatenation order at 0x6B07AC–0x6B07D0 builds.

**Fleet and air rows** (0x6B43C0) get only the short name (21) and the group suffix: no green, no star. A base row's name is the province's full name, uncut.

The text box itself is `fixedsize = yes`, `maxWidth = 164`, `format = right` in `outliner.gui`. The cut at 21 characters is the code's own, applied before the box sees the text.

### B.3 The figure, `info_text`

**Land row: strength as a percentage.**
- The figure is (sum of the brigades' strength) × 1000 ÷ `GetTotalMaxStrength`, taken as 1000 when the maximum is 0.
- It is written with `FormatFixedPoint` to one decimal, truncated, then `%`. This gives the maintainer's `100.0%` and `99.9%`.
- **When the row is made**, the text is `§R` + figure + `%§W` (red) when strength ÷ strength ceiling (`GetTotalStrengthCeiling`, not the maximum) is below `CUnit::ShatterThreshold`.
- **`CArmyMember::Update` rewrites it whenever the summed strength changes** (it is cached at `+0x70`), and writes only figure + `%`, with no colour codes. So a shattering unit's red lasts until its first change of strength.

**Fleet row: the number of ships.** It is the unit's sub-unit count (`CUnit +0x40`, the count of its `regiments` list), written as a whole number: `18`, `3`. It is cached at `+0xC8` and rewritten by `Update` when the count changes.

**Air row:** the number of wings, the same way.

**A base row shows `0`.** The constructor writes the zero register there (0x6B15AC–0x6B1602), and `Update` returns before reaching `info_text` on a base row.

### B.4 The `movment` arrow

It has no frames: it is shown or hidden. The sprite `GFX_outliner_move_arrow` is a single frame.
- **It is shown exactly when the unit has a path** (`CUnit +0x140 > 0`).
- Nothing marks a battle, a retreat, a strategic redeployment or being carried.
- Land row: set in `Update` (every update) and in `Show` (slot 10 of the `+0x1C` table).
- Fleet and air rows: set **only in `Show`** (0x6B4DB0). Their `Update` never touches it, so a fleet's arrow changes only when its row is shown again. A base row's arrow is always hidden.

### B.5 The tree: `expand_button`

**The expanded state is a byte on the unit itself, `CUnit +0xB4` (`outliner_expanded`).**
- Clicking `expand_button` flips it (`CArmyMember::OnExpandClicked` and the fleet and air versions); that is all the click does.
- `CUnit::CUnit` zeroes it (0x5B53D8), and **it is not saved**. A sweep of the unit code finds no other write. The same sweep finds the saved `retreat` byte (`+0x158`) 26 times, including in `CUnit::LoadKey`, so it can see a saved byte. Every unit therefore starts collapsed in every session.
- A base row keeps its state in the base object instead: `CUnitBaseProvince +0x14`.

**The frame** (the sprite has 2 frames): frame 1 when collapsed, frame 2 when expanded. A base row shows frame 2 only if it is expanded *and* has at least one unit. **The frame is set only when the row is constructed**, never by `Update` or by the click.

**Enabled or disabled:** the button is disabled when the unit has no children (`CUnit +0x1EC == 0`) or the base has no units (`+0xC < 1`), and enabled again when it has. This is done in the constructor and in every `Update`. The button's state 3 means disabled; slot 46 enables it, slot 47 disables it.

**Collapsing:**
- A land row's `IsWanted` (slot 15) **answers false when the unit's parent is collapsed**. That is how a collapsed command hides its children, presumably at the next rebuild.
- Otherwise it answers whether the unit is in the list at its argument's `+0xA4`.
- The fleet and air `IsWanted` have no parent test. **They answer true outright when the row's province has the base built** (naval base or air base `level_max > 0`); otherwise they look for the unit in the argument's `+0xC4` list. Both fleet and air rows use that same `+0xC4` list.
- `NoteShown` (slot 16) appends the row's unit to the argument's lists: `+0xB4` for land, `+0xD4` for fleets and air units, `+0x104` for ports, `+0x124` for airfields.
- What the argument is, and the builder that uses it, belong to reader A.

**Indentation:** a land row is moved right by the x of the positionType `outliner_browser_offset` (10 in `outliner.gui`) times the number of units above it. A division under corps → army → army group → theatre is 40 pixels in. **Fleet and air rows look the offset up and throw the answer away, so they are never indented** (0x6B10C8–0x6B111E).

### B.6 The tooltip (slot 13)

**Land row:** it asks which element is under the mouse (the element's slot 17 gives its name).
- `movment` while moving: `OL_UNIT_MOVING`, "Moving towards §Y$TARGET$§W.", with $TARGET$ the **next** province on the path (the first node, `+0x138`).
- `info_text`: `SHATTER_TOOLTIP`, from `CUnit_BuildShatterTooltip`. Its fields are:
  - $STRENGTH$: strength as a share of the ceiling;
  - $THRESHOLD$: `ShatterThreshold`;
  - $OFFICER$: min(1000 − 500 × officer ratio ÷ 1000, 500);
  - $EXP$: average experience × 3 ÷ 1000;
  - $LEADER$: skill × 10;
  - $NAME$: the leader's name.

  Each figure is written as a percentage to one decimal.
- **Anything else** (the name, the background, `expand_button`, or `movment` while standing still) gives `OL_ARMY`: "This army currently $COMMANDER$ and is standing in §Y$PROV$§W."
  - $COMMANDER$ is `OL_COMMANDER` ("is under the command of $COMMANDER$", with the leader's name `+0x4C`, uncoloured) when the leader's slot 8 answers true. It answers true for `CLeader` and false for `CNullLeader`; with the null leader it is `OL_NOCOMMANDER` ("has no commander").
  - $PROV$ is the current province, and is filled only when there is one.
  - While moving, a newline and `OL_ARMY_MOVE` follow, "It is on the move towards §Y$DEST$§W.", with $DEST$ the **final** province (the last node, `+0x13C`).
  - This produces the maintainer's "This army currently is under the command of de Bono and is standing in Roma." exactly.

**Fleet and air rows:** one tooltip for the whole row; the element is not looked at.
- Base: `OL_NAVAL_BASE` or `OL_AIR_BASE`, "The $PROV$ naval base currently has $NUM$ units assigned", with $NUM$ the base's `units_count`.
- Unit: `OL_NAVY` or `OL_AIR` with the same $COMMANDER$ and $PROV$ variants.
- While moving: a newline and `OL_NAVY_MOVE` ("It has set sail towards…") or `OL_AIR_MOVE` ("It has set flying towards…"), with $DEST$ the last province.

The keys are in `localisation/outliner.csv`, `misc.csv` (`OL_UNIT_MOVING`) and `interface.csv` (`SHATTER_TOOLTIP`). `tfh/localisation` overrides none of them.

### B.7 Clicks

**Left click on the background (`outliner_standard`)** (`CArmyMember::OnClick`, `OutlinerFleetOrAirRow_OnClick`). The unit must resolve and be the player's (`CUnit::IsPlayers`). Then:
1. Deselect the unit if it is selected (in-game screen slot 45).
2. Clear the selection (slot 46).
3. Slot 93: shut any open country view, then 0x66BE80(0) (frontier).
4. Select the unit (slot 38).
5. **Put the camera on its province** (slot 47 by province id, then `CentreOnProvince`).

There is no Shift, Ctrl or double-click handling: nothing reads the keyboard or a clock. A click always replaces the selection with that one unit.

**A fleet or air row whose unit is not the player's, and every base row,** instead clear the selection, run slot 93, **select the province** (its selectable at `+8`) and centre the camera on it. A land row with a foreign unit does nothing.

**`expand_button`:** flips the expanded byte (B.5).

**Pressing and dragging a row** (the background glue's slot 4, `OutlinerUnitRow_OnDragStart`; *inferred*): hands the unit to the in-game screen's slot-105 object through 0x73AE80. That object keeps the unit and sets `+0x9C = 1`: the unit is picked up to be dropped onto another. The unit panel's child rows and the deploy menu start their drags through the same call. A base row passes null, which clears it.

**Right click:** none. The glue's right-click slot (slot 9, `+0x40`) is null for every unit row.

### B.8 What a mod can change and what is hardcoded

**Moddable:**
- The window and element names and layout (`interface/outliner.gui`). The names are the contract: the code finds `outliner_unit_entry_bg`, `outliner_standard`, `outliner_top_unit_entry`, `items`, `expand_button`, `entry_text`, `info_text`, `movment` and `outliner_browser_offset` by name.
- The indent step (`outliner_browser_offset`'s x).
- The two expand frames and the arrow (`interface/outliner.gfx`).
- All the localisation keys.

**Hardcoded in the executable:**
- The 21-character cut and `...`.
- The colour codes `§G`, `§R`, `§W`, `§Y`, and the star's ±100 thresholds and colours.
- `(`…`) ` around the group number.
- One decimal place and `%`; ships and wings as a whole number.
- The shatter weights 500 / 3 / 10, filled by static initialisers.
- The fact that the expanded state is never saved.

### What looks wrong but is what the bytes do

- The red shatter colour is written only when the row is made; the first strength change in `Update` drops it. The red test uses the strength **ceiling**, while the figure shown uses the **maximum**.
- When the maximum strength is 0, the constructor shows `100.0%` but `Update` shows `0.0%`.
- The land row caches its name with the `§G` prefix, so an AI-commanded unit's name never matches `GetName` and its text is rebuilt on every `Update`.
- `§G` is never closed; it runs into the group number.
- There is no space between the name and `(`.
- A base row's `info_text` is `0`, though its tooltip gives the real unit count.
- Fleet and air rows are never indented (the offset is looked up and discarded) and never get the green name or the star.
- The fleet and air arrow is refreshed only in `Show`, not in `Update`.
- The expand frame is never refreshed after construction.
- A fleet or air row whose unit is not the player's selects its province on a click.
- The fleet and air `IsWanted` answers true for any row whose province (fixed when the row was made) has the base built, whatever happened to the unit since. If a fleet row's unit stops resolving, the row behaves as a base row (`OL_NAVAL_BASE` tooltip, province click). Whether the builder ever lets that happen is reader A's question.
- Fleet and air rows both look in the argument's `+0xC4` and append to `+0xD4`.
- Both `Show` overrides skip the base class's store of 1 at the item's `+8`.
- `GetUnitSelectionGroup` copies the country's ten group lists to the stack on every call, which happens on every `Update` of every row.

### What could not be settled

- **What the argument of slots 15 and 16 is.** It is a set of lists at `+0xA4`, `+0xB4`, `+0xC4`, `+0xD4`, `+0x104` and `+0x124`, and no caller of these row slots was found in VA 0x6A3000–0x6A9A00. Whether fleet and air units share the `+0xC4` and `+0xD4` lists in one pass is part of this. It belongs to reader A's rebuild.
- **That glue slot 4 is a press-and-drag.** This rests on what 0x73AE80 does and on its other callers, not on the button code that fires the glue.
- **`OwnsElement` and `Show`.** Named from their shape and from the base body; neither caller was traced.
- **`CUnit::IsPlayers`.** In-game screen slot 23 (0x60BC80), which supplies the tag compared against the owner, was not read.
- **The expand frame numbering.** Frames 1 and 2 against a two-frame sprite suggests counting from 1; the setter (button slot 18, `+0x138`) was not followed into drawing.

### Frontier

- `0x66BE80`: called by in-game screen slot 93 after the country view is shut; it reads `menu_save` and `menu_message_settings`.
- `0x73AE80` / `0x73B030`: the slot-105 drag object's "pick up" and "clear"; its class was not identified.
- `0x6B6F80`, `0x6B6F90`, `0x6B6FB0`: slot 0 thunks of the `+0x1C` table (destructor adjustors), not recorded.
- `0x6C60C5`: the second caller of `CUnit_BuildShatterTooltip`.
- In-game screen slot 23 (`0x60BC80`) and slot 93 (`0x6750B0`), unnamed.
- Button slot 47 (`0xACFFA0`, disable through slot 69) was not read whole.

## C. The other rows

### C.1 The kinds: one number per section

Every row's slot 12 answers a kind, and `GetOutlinerKindTitle(out, kind)` (VA `0x6AE0D0`, `__cdecl`, answers `out`) turns a kind into the section's name. Confirmed from the compare chain at `0x6AE0FD` onwards and from each slot 12 body.

| kind | rows | section title key (English) |
|---|---|---|
| 1 | CCombatMember (`Return_1`) | `OL_COMBATS` "Land Combat" |
| 2 | CNavalCombatMember (`Return_2`) | `OL_NAVAL_COMBAT` "Naval Combat" |
| 3 | CAirCombatMember (`Return_3`) | `OL_AIR_COMBAT` "Air Combat" |
| 4 | CArmyMember (`Return_4`) | `ARMIES` "Land Units" |
| 5 | CNavyMember (`0x563F30`, `mov eax,5`) | `NAVIES` "Naval Units" |
| 6 | CAirMember (`0x564000`, `mov eax,6`) | `OL_AIR_UNITS` "Air Units" |
| 7 | CAlliedObjectiveMember | `OL_ALLIED_OBJECTIVE` "Allied Objectives" |
| 8 | CBombCombatMember, player bombing | `OL_WE_BOMB` "Our Bombings" |
| 9 | CBombCombatMember, player bombed | `OL_BOMB_ON_US` "Hostile Bombing" |
| 11 | CTitleMember itself | - |

Any other kind gives an empty string. The function has three callers: the title's constructor, the configuration list (`0x6A301F`) and the window (`0x6A86CC`). So the configuration window's entries carry the same names.

### C.2 The title row (`CTitleMember`, window `outliner_header_entry`)

- **What it shows:** only the section name. The constructor (`0x6ADF10`) puts it into `entry_text` (bold, right-aligned) once.
- **No count.** No figure is written anywhere, and there is no update (slot 8 is the empty stub `0xABF890`).
- **No tooltip** (slot 13 is `EmptyTooltip`).
- **No collapse.** The window has no expand button, and the constructor builds no observer glue, so a click on a title does nothing of its own.
- Slot 15 is the folded `mov al,1; ret 4`: a title is always kept. Slot 16 is the folded `ret 4`.

Confirmed.

### C.3 The battle rows (window `outliner_combat_entry`)

The whole row is the `outliner_standard` button. The figure goes in `info_text` (x 8, left-aligned) and the place in `entry_text` (x 44, right-aligned). Every row keeps its battle (+0x28) and the battle's province (+0x2C).

**What every row checks first.** Each slot asks whether the battle is still in its province's combats list (`CMapProvince +0x2EC`). A bombing row asks instead whether it is still the province's one bombing (`+0x2FC`). If not, the slot does nothing.

**`entry_text`, all four kinds:** `CProvince::GetName` of the province. That is the "Gurbo" in the maintainer's screenshot. Each constructor calls the province's +8 table, slot 7 (`0x4973B0`).

**Whose side the row takes (+0x80).** The constructor sets +0x80 to 1 when the player's country id is among the attacker's countries still in the fight (`CCombatant +0x54`). For a bombing, the attacker is the bombing side. **It is set once, when the row is built, and never recomputed.**
- Land: the walk is at `0x6A9D42` to `0x6A9D60`. It writes 0 at `0x6A9D62`, and 1 in a cold block past the `ret 4` at `0x6A9E7C` (trap 3).

**Land, the figure (Update, `0x6AA840`).**
- `share = CCombat::GetAttackerStrengthShare`, in thousandths. This is the same share the battle window's bar and the map marker use (`FINDINGS-combatview.md`, section 10).
- When the player attacks: `§G` + `FormatFixedPoint(share × 100000 / 1000, 0)` + `%§W`.
- When the player defends: `§R` + the same of **−share** + `%§W`.
- `FormatFixedPoint` truncates. So a share of 78 shows **"7%" in green** to the attacker and "-7%" in red to the defender.
- **The colour says which side the player is on, not how the battle is going.**
- The row has no cache: it is rewritten every time Update is called.

Confirmed: `neg ecx` at `0x6AA8DA`; `push 0` for the decimals at `0x6AA953`.

**Land, the tooltip (slot 13, `0x6A9E90`).**
- It is empty unless the battle still exists and neither side's combatant answers slot 8 (air) or slot 7 (naval).
- The key is `OL_LAND_COMBAT_ATTACK` when +0x80 is set, otherwise `OL_LAND_COMBAT_DEFEND`. "Ours" is the player's side.
- `$PROGRESS$` is `FormatFixedPoint(share × 100000 / 1000, 1)`: one decimal, truncated. That is the 7.8% in the screenshot against the row's 7%. **It is the attacker's share in both variants and is not negated when defending.** DEFEND's text is "an attack which has progressed §R7.8%§W towards success".
- `$OUR_LEAD$` and `$THEIR_LEAD$` are the name of `CCombatant::GetHighestRankedLeader` (the highest rank wins, the first of equals). For the null leader they are the rendered `NO_COMMANDER` "(No Commander)".
- `$ENEMY$` is `CountryAdjectiveOfTag` of the first of their countries still in the fight. With none, it is the bare string `NONE` (see C.7).
- `$OUR_NUM$` and `$THEIR_NUM$` are `CUnitList::GetTotalNumOfRegiments` of the side's front (`+0xB0`). `$OUR_RES$` and `$THEIR_RES$` are the same of its reserves (`+0xC0`). Both count land regiments only.
- Confirmed: `0x6A9F48` to `0x6AA400`; `push 1` for the decimals at `0x6A9FFE`.

**Sea and air, the figure.**
- Sea: `a` and `d` are `CUnitList::GetTotalNumOfShips` of each side's units.
- Air: `CUnitList::GetTotalNumOfPlanes`, and the update runs only while `CCombat::IsLive`.
- When the player attacks: `§G a §W - §R d §W`. When the player defends: `§R a §W - §G d §W`. **The attacker is always first; the player's number is green.**
- The text is rewritten only when a count changes against the cached +0x84/+0x88. An air row starts at `0 - 0`.
- Confirmed.

**Sea and air, the tooltip.**
- There is no localisation sentence; it is built by concatenation:
  - `CCombat::GetName` ("Battle of X");
  - `\n` and the attacker's leader name, only if the leader is real;
  - `\n §G` or ` §R`, the count, `§W `, and `OL_SHIPS` "Ships" (air: `OL_WING` "Wings");
  - `\n-`;
  - the defender's leader and count the same way.
- The player's side is green. The counts are the row's cached ones.
- Confirmed.

**Bombing.**
- `entry_text` is the province. **`info_text` is never written**, so the row shows no figure.
- No update and no tooltip (slot 8 is the stub, slot 13 is `EmptyTooltip`).
- Its kind is 8 when the player bombs, 9 when the player is bombed. **That is how `outliner_view_bombonus` and `outliner_view_bombonthem` can be told apart** (which switch takes which kind is section A's).
- Confirmed.

**Clicks.** Every row's observer glue has only its plain-click handler set; the 16 other handlers, right click (glue slot 9, `+0x40`) included, are null. "Glue slot 2 = plain click" comes from the earlier `CBuildingMember` and `CProvinceView` readings.
- **Land, sea, bombing:** if the battle still exists: `CInGameIdler::ClearSelection` (slot 46), then `Select(battle's CSelectable)` (slot 38), which opens the battle window through `CCombat::OnSelected`, then `CentreOnProvince` (slot 48). Each click recentres.
- **Air:** additionally requires `CCombat::IsLive`, and **does nothing if the open battle window is already this battle's** (screen slot 59). It uses `DeselectLater(0)` (slot 43) instead of ClearSelection.
- **Double click:** none of these rows has a handler. The list item's own "selected" slot 4 (`0xA7F7B0`, shared by 85 tables) is section A's.

**Tooltip routing (slot 14):** a battle row answers for `entry_text`, `outliner_standard` and `info_text`. The four classes share one folded body (`0x6AA4C0`).

### C.4 The allied objective row (window `outliner_allied_objective_entry`)

- **What it holds:** a province id (+0x28) and +0x80, the constructor's third argument.
  - +0x80 = 1: the objective was **asked of the player** (`CGameState +0xB9C[player]`).
  - +0x80 = 0: the **player asked it** of others (`+0xBAC[player]`).
- **Row text:** `§R` + province name when asked of the player, `§G` + province name when the player asked. Set once in the constructor; there is no update.
- **Tooltip** (shown only over `entry_text`; slot 14 checks nothing else):
  - Asked of us: the requesters, each `§Y` + name + `§W`, joined by `, `, with ` ` + `AND` + ` ` before the last. Then `OL_AO_THEY_REQUEST` " have requested that we".
  - We asked: `OL_AO_WE_REQUEST` "We have requested that " followed by the countries asked, listed the same way.
  - Then `OL_AO_DEFEND` " §Gdefend§W near " **when the faction of the province's controller (`+0x334`) is the player's faction**, otherwise `OL_AO_ATTACK` " §Rattack§W near ".
  - Then `§Y` + province name + `§W.`.
  - Confirmed (`0x6B5A40` to `0x6B6892`).
- **Click:** `CInGameIdler::CentreOnProvinceId` (slot 47). It centres the map and selects nothing.
- **Kept or dropped:** slot 15 keeps the row while the player's list still has a record for the province. Slot 16 does nothing.

### C.5 The province entry

`outliner_province_entry`, `occupied`, `siege`, `outliner_standard_entry` and `GFX_outliner` occur nowhere in the image. The search was a byte search over every section, plain and UTF-16. **Positive control:** the same search finds `outliner_combat_entry` (4 references), `outliner_header_entry`, `outliner_allied_objective_entry`, `outliner_top_unit_entry`, and `convoy_province_entry` (a different window). So no province row exists, and the `occupied` and `siege` icons are never shown. This is confirmed for the plain strings; that no name is put together at run time is inferred. BlackICE's `outliner.gui` declares both windows too.

### C.6 What a mod can change and what is hardcoded

**A mod can change:**
- Every localisation text: `OL_*`, `ARMIES`, `NAVIES`, `AND`, `NO_COMMANDER`, `BATTLE_OF`, `BOMBING_OF`.
- The layout, fonts and sprites in `outliner.gui`.

**Hardcoded in the executable:**
- The colour codes `§G`/`§R`/`§Y`/`§W`, the `%`, ` - `, `-`, `0 - 0`, `NONE`, and the line layout of the sea and air tooltips.
- ×100 with truncation, 0 decimals on the row and 1 in the tooltip.
- The defender's minus sign.
- Green for the player's side.
- The defend-or-attack faction rule.
- The kind numbering.
- The element names looked up: `entry_text`, `info_text`, `outliner_standard`.
- That the province entry is unused.

### C.7 What looks wrong but is what the bytes do

1. A defender's land row shows **minus the attacker's share** ("-7%"), not its own progress. The DEFEND tooltip shows the attacker's share without the minus.
2. +0x80 (which side the player is on) is fixed when the row is built.
3. The sea row's constructor seeds the defender's cached count (+0x88) with **total strength / 1000, not a ship count**. If that happens to equal the defender's ship count, the first Update writes nothing, and the figure stays blank until a count changes.
4. The land row computes both sides' strength into +0x84/+0x88, and nothing reads them. Positive control: the same decode of the window code finds the `+0x3C`/`+0x40` slot calls.
5. `CBombCombatMember::IsStillCurrent` asks **sets+0x04, the list the land row asks**. Its own `MarkShown` writes +0x74/+0x94, and the other rows ask +0x24 and +0x44.
6. `CAlliedObjectiveMember::MarkShown` is a no-op.
7. The objective tooltip's "and" comes out with two spaces: ` ` + `and ` + ` `.
8. The defend-or-attack rule compares faction pointers. A country in no faction shares one singleton (`CCountry +0xD8`), so two faction-less countries count as the same faction and get "defend".
9. The air click needs IsLive and refuses to reopen the battle that is already open. The land, sea and bombing clicks do neither, and use a different deselect slot.
10. `CTitleMember::OwnsElement` asks for an `outliner_standard` that its window does not have.
11. `$ENEMY$` with no enemy is the raw string `NONE`. The value goes through `Replace`, like a leader's name, and is not looked up as a key, though the key `NONE` "None" exists. This is inferred.
12. The sea and air tooltips leave out the leader line for the null leader; the land tooltip says "(No Commander)".

### C.8 What could not be settled

- When slot 8 (Update) runs, and what builds `sets` and reads slots 15 and 16. That is section A's. It decides what point 5 above does: if sets+0x04 holds only land battles, a bombing row is dropped and rebuilt on every refresh.
- Whether `Render` localises a replacement value (`NONE`).
- Any double-click handling, which would sit in the list and not in these rows.

### C.9 Frontier

- `0x6A9A30` `COutLinerMember::COutLinerMember` (section A or B)
- the glue constructors `0x6B6B40`, `0x6B6BE0`, `0x6B6F00`
- `0x6ACB50`, the deleting destructor folded across 13 tables
- `0x6AE720`, a depth count over `+0x1E0` called from unit-row code (section B)
- `0xB129A0`, `mov al,1; ret 4`, in 37 tables
- `CCombatant` slots 7 and 8: the naval and air predicates (`ReturnTrue` in `CNavalCombatant` slot 7 and `CAirCombatant` slot 8), whose slot names are unrecorded
- `0x4022A0`, a string-assign helper
