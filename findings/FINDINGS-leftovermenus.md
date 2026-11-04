# The leftover menus: the right-click menu and the five side menus

*The leftovers wave, 2026-11-04: three readers, read statically out of `hoi3_tfh.exe` with `scripts/disasm.py`,
`scripts/findRefs.py`, `scripts/vtable.py`, `scripts/fieldchain.py` and Ghidra copies. Only valid for this build. No
running game was asked: these menus cannot be opened in the shipped game. For OpenHOI3, which may build them and then
switch them off again - the maintainer's word.*

**The wave in one paragraph.** Two interface files nothing in the shipped screens reaches, as the maintainer guessed -
leftovers of another game on the engine. **The right-click menu** (`rightclickmenu.gui`, section A) is made by the
in-game screen and the front end; in game a right click with nothing selected fills it, but its build-units rows walk
two lists made empty and never filled and its reload row needs a field only ever set to nought, so it never shows; in
the front end, **Shift and the right button over an interface element** should show `Reload: <file>` and `Close` - a
developer's hot-reload of one `.gui` file - which is the one live piece, and a ten-second test in the original. **The
five side menus** (`sidebar.gui`, sections B and C) are made at every game's start and numbered 0 provinces, 1 army, 2
naval, 3 air, 4 combat (5 is the deploy menu, built already); one is open at a time, a second press closing it; the six
top-bar buttons that would open them are commented out in every shipped `topbar.gui`, **and their handlers are never
attached to any button either**, so restoring the buttons would give six that do nothing - only the deploy menu ever
opens. Were they opened: the army menu is the player's land order of battle as a tree, the air and naval menus each base
with the units based there and its level as `4.50/5`, the provinces and combat menus an icon and a title and nothing
else; a row's select selects the unit alone, its expand is the outliner's own flag; no tooltips anywhere.

**Corrected in the record**: `CInGameIdler_OpenSideMenu` and `CInGameIdler_CloseSideMenus` read whole and `confirmed`
(were *inferred*); `CInGameIdler_LayoutUnitPanels` takes its width from side menu 1's window, not the open one's, and has
six callers, not two; `CBrowserItem` is the expeditionary-force dialog's row, not a side menu's, and none of the side
menus' rows derives from it.

| section | reader | fragment |
| --- | --- | --- |
| A, the right-click menu | A | `fragments/merged/rightclick-menu.json` |
| B, the frame, what opens the menus, provinces, army and combat | B | `fragments/merged/sidemenu-land.json` |
| C, the air and naval menus | C | `fragments/merged/sidemenu-sea-air.json` |

## A. The right-click menu (`interface/rightclickmenu.gui`)

*Reader A. Addresses are VAs unless marked rva.*

**Synopsis.** The aim was who makes `rightClickMenu`, what shows it, what its rows are and do, and whether a player of
the shipped game can see it. **In game it never shows**: the right release with nothing selected calls the filler, but
the filler can only make the `empty_right_click_entry` spacer - its build rows walk two lists made empty and never
filled, its Reload row needs `CInGameIdler +0x1D98`, to which only nought is ever written (the caller zeroes it just
before the fill) - and with fewer than two rows the filler hides the window. **In the front end it is live by the bytes,
and a developer's tool**: Shift and the right mouse button over any interface element should give three rows - the
spacer, **`Reload: <the element's .gui file>`** and **`Close`** - and Reload hot-reloads that file, as the `reload`
console command does. **Nothing ever builds units**: that row only sets its own clicked flag, and the menu closes.
**Corrected in the brief**: `0x6F2860` is not inside or after `CFrontEnd::LaunchGame` but a function of its own, called
by the front end's per-frame update; and `0x6754B0` is not map-mode code but the in-game twin of the same filler.
Nothing in the record is revised.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| 0x2754B0 | CInGameIdler_FillRightClickMenu | new | confirmed | the in-game filler; always ends with the menu hidden |
| 0x2F2860 | CFrontEnd_FillRightClickMenu | new | confirmed | the front end's instruction-for-instruction copy; its Reload branch is live |
| 0x297EA0 | CRightClickBuildUnitsItem::CRightClickBuildUnitsItem | new | confirmed | build row (screen, unit type, province); never reached |
| 0x298170 | CRightClickBuildUnitsItem::IsAvailable | new | confirmed | player controls the province; manpower >= 1 or not a land type; no land combat there |
| 0x327120 | CRightClickBuildUnitsItem::OnClick | new | confirmed | `+0x88 = 1` and nothing else |
| 0x297E80 | CRightClickBuildUnitsItem::WasClicked | new | confirmed | slot 10 of the +4 table: the clicked flag |
| 0x298A00 | RightClickItem_RefreshButton | new | confirmed | shared slot 1 of BuildUnits and Reload: greys or enables `button` by slot 0; class-free on purpose |
| 0x298290 | CRightClickCloseItem::CRightClickCloseItem | new | confirmed | screen in ECX, row on the stack; text the localisation key `CLOSE` |
| 0x2985F0 | CRightClickCloseItem::OnClick | new | confirmed | `+0x80 = 1` |
| 0x298600 | CRightClickCloseItem::RefreshButton | new | confirmed | always enables `button` |
| 0x298690 | CRightClickReloadItem::CRightClickReloadItem | new | confirmed | text the literal `"Reload: " + file`, not localised |
| 0x2989A0 | CRightClickReloadItem::IsAvailable | new | confirmed | file name not empty |
| 0x2989B0 | CRightClickReloadItem::OnClick | new | confirmed | flag set, then ReloadInterfaceFile(file) |
| 0x67E400 | ReloadInterfaceFile | new | inferred | re-parses a .gui file and calls slot 0 of every CReloadableInterface registered for it |
| 0x3B1D0 | ConsoleCmd_Reload | new | confirmed | the `reload <file>` console command ("Reloads the gui or lua file") |

Structs declared: `CRightClickItemInterface` (0x4), `CRightClickBuildUnitsItem` (0x90), `CRightClickCloseItem` (0x88),
`CRightClickReloadItem` (0xA0), and `CFrontEnd` (vftable only, no size).

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| CInGameIdler | 0x1D90 | right_click_menu | void* | new |
| CInGameIdler | 0x1D94 | right_click_province | void* | new |
| CInGameIdler | 0x1D98 | right_click_element | CGuiObject* | new |
| CFrontEnd | 0xB4 | right_click_menu | void* | new |
| CFrontEnd | 0xB8 | right_click_province | void* | new |
| CFrontEnd | 0xBC | right_click_element | CGuiObject* | new |
| CRightClickBuildUnitsItem | 0x24 / 0x2C / 0x30 / 0x34 / 0x38 / 0x88 | window / screen / unit_type / province / click_observer / clicked | void* / void* / CSubUnitDefinition* (inferred) / CMapProvince* / void* / bool | new |
| CRightClickCloseItem | 0x24 / 0x2C / 0x30 / 0x80 | window / screen / click_observer / clicked | void* / void* / void* / bool | new |
| CRightClickReloadItem | 0x24 / 0x2C / 0x30 / 0x80 / 0x84 | window / screen / click_observer / clicked / file | void* / void* / void* / bool / Hoi3CString | new |

The three items' slots are recorded on their primary tables (0 IsAvailable, 1 RefreshButton, 2 OnClick) and their `@0x4`
tables (0 ScalarDeletingDestructorAt4, 4 OnSelect, 10 WasClicked, 11 RefreshButton), and the same names on the base
`CRightClickItemInterface`, whose slots are all `_purecall`. Two bodies are left unnamed (`slots_noted`): `0x697E90`, the
clicked-flag getter of Close and Reload, which is also CTableLedgerItem's slot 5 (trap 4), and `0xA92590`, ReturnTrue,
Close's slot 0.

### A.1 What makes it

- **The in-game screen**: in `CInGameIdler::CInGameIdler` (rva `0x2474A0`), VA `0x6494D1`-`0x64952A`, the screen asks
  the gui (`+0x60`, slot 10) for the window `rightClickMenu`, keeps it at **`+0x1D90`** and hides it at once. The lines
  after register the screen as a CReloadableInterface for `interface/menubar.gui` (`0xA7E210`) - unrelated.
- **The front end**: `CFrontEnd::Enter` the same at VA `0x6EFFDC`-`0x6F0051`, keeping it at **`CFrontEnd +0xB4`**.
- **The window**: declared 0 x 0 and `moveable = 1`; its one child the listbox `options` (background `rightclick_bg`,
  120 x 300). The row templates: `right_click_entry`, 250 x 32 with one `button` whose file text reads "Send Merchant"
  (Europa Universalis III's; every row overwrites it), and `empty_right_click_entry`, the same with no button. BlackICE's
  copy differs from the base game's in whitespace only.

### A.2 In game: what would show it, and why it never shows

**The click**: `CInGameIdler_HandleInput`, on a **right release with nothing selected, no unit rows and the left button
up** (VA `0x65288F`-`0x6528EE`): where a province is under the pointer, `+0x1D94` = the graphical map's entry for it;
**`+0x1D98 = 0`**; the filler `0x6754B0`; and the window moved to the pointer, pulled back by its size + 10 where it would
leave the screen (the screen size graphics `+0x6B9BC`/`+0x6B9C0`, the constant the double 10.0 at `0x160A340`), through
window slot 42.

**The fill, `CInGameIdler_FillRightClickMenu`**: clears `options`; **with `+0x1D98` set**, the spacer and then
`Reload: <file>` for that element; **otherwise with `+0x1D94` set**, the spacer and then build rows - only where the
player's country both **owns (`+0x330`) and controls (`+0x338`)** the province, one CRightClickBuildUnitsItem per node of
a local list, plus one per node of a second where the province's cores (`+0x344`) hold the player. **With two rows or
more**, Close last, `options` sized to (first row's width + 20, (rows + 1) x row height + 7) - + 14 instead of + 7 with
exactly three rows - and the window shown; **with fewer, hidden**.

**Why nothing ever shows**, all off the bytes:
- Both build lists are made by `0x432630`, four stores of nought; nothing writes the first before its walk, and the
  second is a freshly zeroed list moved in by `0x679AE0`. So **no build row is ever made** - all that is left of whatever
  filled them in the other game is the empty list's constructor, the owner, controller and core tests standing round
  nothing.
- **Negative with its control**: a displacement scan of .text for `+0x1D98` finds three writers, all of nought - the
  constructor (esi = 0), `0x64FC94` (beside `chat_window`, ebx = 0) and `0x6528E8` (edi = 0) - and no `lea` of the field;
  the same scan finds the filler's two known reads, the positive control.
- So in game the fill gives the spacer at most: one row, the window hidden. **A player of the shipped game cannot see it
  in game.**

### A.3 In the front end: Shift and the right button

**The trigger**: the front end's per-frame update (slot 1, VA `0x6EDD60`) walks the frame's input events; for any mouse
event (kind 0) **while Shift is held and the right button is down** (VA `0x6EE370`-`0x6EE3B6`): `+0xB8 = 0`; **`+0xBC` =
the element under the pointer** (gui `0x1A857D8` +0x98); `CFrontEnd_FillRightClickMenu` (`0x6F2860`), the in-game
filler's copy instruction for instruction; the window put at the pointer as in game. Shift is the keyboard's (`+0x1C`)
slot 10, which reads byte `+0x50`; the right button the input object's (`+0x64`) slot 11, byte `+0x95`, the second of
the per-button array the DirectInput poll (`0xB4E900`-`0xB4EA69`) fills for buttons 0-2. **No gate**: no jump from the
update's start reaches past this loop, and no define or switch is tested; the front end has no province, so the build
branch is never taken either.

**So**: with an element under the pointer, three rows - **spacer, `Reload: <file>`, `Close`** - in a 270 x 142 box; with
nothing under it, none and the window hidden. The gate is off the bytes; **that it appears on screen is inferred** - it
rests on DirectInput's button 1 being the right button, on the front end's event list carrying mouse presses, and on the
window drawing there. **A ten-second test in the original: in the main menu, hold Shift and right-click a button.**

### A.4 The rows and the three items

**Order**: the spacer first (`empty_right_click_entry`, a plain listbox row through the generic row constructor
`0xA8BBD0`), the item rows, Close last. The spacer is only a padding row at the top; the two places asking for it, near
`PopMapMode` and near `LaunchGame`, are the two fillers. **All three items**: CRightClickItemInterface at +0,
CStandardlistboxItem at +4, the row window at +0x24, the screen at +0x2C, a `CButtonObserverGlue` on `button` whose plain
click goes to slot 2.
- **Build units** (0x90): the unit type at +0x30 (CSubUnitDefinition, inferred), the province at +0x34; its text the
  type's name (type slot 6); pressable where the player controls the province, has 1.000 manpower or more or the type is
  not a land type (`+0x2D`), and the province has no combat of kind 1. **A click sets `+0x88` and does nothing else.**
  Never made (A.2).
- **Close** (0x88): the localisation key **`CLOSE`** ("Close"), never greyed; a click sets `+0x80`.
- **Reload** (0xA0): the literal **`"Reload: " + file`**, the file the element's CGuiType `+0x24` string - inferred to be
  the .gui file the type was declared in; greyed while it is empty; a click sets `+0x80` and calls
  `ReloadInterfaceFile(file)`.

### A.5 Greying, tooltips and closing

**Every frame**, `CInGameIdler::Update` (VA `0x6567C0`-`0x656888`) and the front end's (VA `0x6EE954`-`0x6EEA10`) walk
every row of `options`, unconditionally: each row's slot 11 refreshes its button (enabled or not by slot 0), its slot 10
reports the clicked flag, and **where any row reports clicked, the menu is hidden**. The flag is never cleared; the rows
are destroyed at the next fill. **It closes** on a click on a row's button, on choosing the row itself (the +4 table's
slot 4 thunks to the same OnClick), on a fill of fewer than two rows, and in game only on a left release over the map
with the down byte set (HandleInput `0x652B8F`-`0x652BB6`, which also clears `+0x1D94`). **Tooltips: none found** - the
file's tooltip keys are empty and the items override no tooltip slot; the screens' GetElementTooltip for this window was
not read, so *inferred*.

### A.6 The reload behind it

**`ReloadInterfaceFile`** (`0x67E400`, *inferred*): a name holding `.gui` not found as given gets `interface/` in front,
and if it then exists is parsed again into the gui; a name holding `.lua` is only looked for, as given and under
`script\`. Then every CReloadableInterface registered for that name has its slot 0 called, and the answer is true unless
one answers false. **`ConsoleCmd_Reload`** (`0x3B1D0`), the console's `reload <file>` from the static table at
`0x170B150`: a name not .lua goes to the same function and answers "<name> reloaded!" or "Failed to reload the file"; a
.lua name is looked for as given, under `script/` and `script/country/`, and run in the Lua states - that half not read.
Section B's `ConsoleCmd_ReloadInterface` (`0x3B610`, `reloadinterface`) is the next handler in the image.

### Not established

- What CGuiType `+0x24` is: used as a file name; that it is the type's source file is inferred.
- The class of the graphical map's per-province entry at `+0x1D94` (the map's `+0x1DF0` array; its `+0xC` the
  CMapProvince).
- Which combat kind is 1 in `HasCombatOfKind(..., 1)`.
- Whether the front end's menu really appears on screen (A.3).

## B. The side menus' frame, what opens them, and the provinces, army and combat menus

*Reader B. Addresses are VAs unless marked rva. Read statically out of `hoi3_tfh.exe` on 2026-11-04; valid for this
build only.*

**Synopsis.** The aim was the side menus' frame, how they are opened, and the provinces, army and combat menus.
`CInGameIdler_BuildViews` (rva `0x259760`) numbers the menus 0 provinces, 1 army, 2 naval, 3 air, 4 combat, 5 deploy;
`CInGameIdler_OpenSideMenu` keeps one open at a time and closes the open one when it is asked for again - a toggle. **The
six top-bar handlers cannot be reached**: their button glues (`CTopBar +0x168` ... `+0x244`) are built by the
constructor but never attached to any button by `CTopBar::Build`, which attaches all thirteen other glues - so even
uncommenting `button_view*` in `topbar.gui` would give buttons that do nothing, and only the deploy menu (5) is ever
opened in the shipped game. The provinces and combat menus are the bare frame, an icon and a title; the army menu is the
player's land order of battle as an expandable tree. **Corrected rather than added**: `CBrowserItem` is not a side-menu
row but the expeditionary-force dialog's (`expedition_entry`); `CInGameIdler_LayoutUnitPanels` takes its x from side
menu 1's window, not the open one's, and has six callers, not two; `OpenSideMenu` and `CloseSideMenus` were *inferred*
and are read whole and *confirmed*.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| 0x423E90 | CSideMenu::CSideMenu | new | confirmed | the frame: registers for reload under its .gui file, keeps screen +0x20, window +0x24, mouse observer +0x28; `this` on the stack, `ret 0x10` |
| 0x424070 | CSideMenu::Rebuild | new | confirmed | slot 0: hides, destroys and remakes the window, shows it again if it was shown |
| 0x423F60 | CSideMenu::~CSideMenu | new | confirmed | slot 1, scalar deleting destructor |
| 0x424100 | CSideMenu::Show | new | confirmed | slot 2: window +0x18 slot 13 (tail jump) |
| 0x424110 | CSideMenu::Hide | new | confirmed | slot 3: window +0x18 slot 14 (tail jump); in 6 tables |
| 0x424030 | CSideMenu::Update | new | confirmed | slot 7: polls the mouse observer's slot 1 each frame where there is one |
| 0x243B70 | CSideMenuProvinces::~CSideMenuProvinces | new | confirmed | slot 1, the class's only slot of its own; the class has no behaviour |
| 0x243BA0 | CSideMenuCombat::CSideMenuCombat | new | confirmed | the frame on `sidebar_combat`, no observer; this@ESI, `ret 4` |
| 0x243C20 | CSideMenuCombat::~CSideMenuCombat | new | confirmed | slot 1 |
| 0x425BF0 | CSideMenuArmy::~CSideMenuArmy | new | confirmed | slot 1; the army menu adds no fields (0x2C) |
| 0x425C20 | CSideMenuArmy::Rebuild | new | confirmed | slot 0: the base's Rebuild, then BuildList |
| 0x425C40 | CSideMenuArmy::Show | new | confirmed | slot 2: show, then BuildList |
| 0x425C60 | CSideMenuArmy::Update | new | confirmed | slot 7: rebuilds the list when the row count differs, else each row's slot 8 |
| 0x425FC0 | CSideMenuArmy_BuildList | new | confirmed | empties `unit_queue` and fills it from the player's CCountry +0xBAC; menu@EDI |
| 0x425E60 | CSideMenuArmy::AddUnitRows | new | confirmed | top level: units with no superior that are land; children of expanded units follow depth-first |
| 0x425DF0 | CSideMenuArmy::CountUnitRows | new | confirmed | the same walk, counting |
| 0x4252D0 | _A0xf32dc95c::CUnitBrowserEntry::CUnitBrowserEntry | new | confirmed | `unitbrowse_entry`: name, location, counter, size frame, two glues; 0x100 bytes |
| 0x425A60 | _A0xf32dc95c::CUnitBrowserEntry::OnExpandClicked | new | confirmed | flips CUnit +0xB4 outliner_expanded |
| 0x425B20 | _A0xf32dc95c::CUnitBrowserEntry::OnSelect | new | confirmed | slot 4 (select_frame): ClearSelection, then Select(unit) |
| 0x4258A0 | _A0xf32dc95c::CUnitBrowserEntry::Update | new | confirmed | slot 8: `expand` disabled with no children; x = depth x browser_offset.x |
| 0x374D80 | CBrowserItem::CBrowserItem | new | inferred | the expedition dialog's row (`expedition_entry`), not a side menu's; outline only |
| 0x259760 | CInGameIdler_BuildViews | new | confirmed | deletes and remakes the 6 country views (+0xD00) and the 6 side menus (+0xD10, in number order) |
| 0x3B610 | ConsoleCmd_ReloadInterface | new | confirmed | the console's `reloadinterface`: BuildViews; opens nothing |
| 0x2655C0 | CInGameIdler_OpenSideMenu | revised | confirmed | was "only its call read": now the toggle, one at a time, ClearSelection, Show + slot 5, a register signature |
| 0x265320 | CInGameIdler_CloseSideMenus | revised | confirmed | was inferred: hides every shown menu, 0x664160, moves the single unit panel back; signature added |
| 0x2652D0 | CInGameIdler_AnySideMenuOpen | new | confirmed | until now named only inside AnyCountryViewOpen's comment |
| 0x265410 | CInGameIdler_RefreshOpenSideMenus | new | confirmed | hide, show and raise each open menu; called after CCreateHigherCommand / CCreateNewHQCommand |
| 0x265490 | CInGameIdler_SetDeployMenuShown | new | confirmed | shows or hides menu 5 only; one caller (0x41EC66, passes 0) |
| 0x263400 | CInGameIdler_LayoutUnitPanels | revised | inferred | the width is side menu 1's window, not "the open side menu's"; six callers, not two |
| 0x2CF0B0 | CTopBar::OnViewProvincesButton | new | confirmed | OpenSideMenu(0) and the button frames; dead |
| 0x2CF300 | CTopBar::OnViewArmyButton | new | confirmed | OpenSideMenu(1); dead; abuts the next handler (trap 2) |
| 0x2CF550 | CTopBar::OnViewAirButton | new | confirmed | OpenSideMenu(3); dead; abuts on both sides |
| 0x2CF7A0 | CTopBar::OnViewNavalButton | new | confirmed | OpenSideMenu(2); dead |
| 0x2CFA00 | CTopBar::OnViewCombatButton | new | confirmed | OpenSideMenu(4); dead |
| 0x2CFC50 | CTopBar::OnViewDeployButton | new | confirmed | OpenSideMenu(5); dead |

Structs declared: `CSideMenu` (0x2C, vftable `0x11DFE3C`); `CSideMenuArmy`, `CSideMenuProvinces` and `CSideMenuCombat`
(0x2C each, inheriting `CSideMenu`); `_A0xf32dc95c::CUnitBrowserEntry` (0x100, vftable `0x11E0100`).

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| CSideMenu | 0x4 | gui_file | std::string | new |
| CSideMenu | 0x20 | in_game_screen | CInGameIdler* | new |
| CSideMenu | 0x24 | window | CFixedWindow* | new |
| CSideMenu | 0x28 | mouse_observer | void* | new |
| _A0xf32dc95c::CUnitBrowserEntry | 0x20 | window | CFixedWindow* | new |
| _A0xf32dc95c::CUnitBrowserEntry | 0x28 | observer_expand | void* | new |
| _A0xf32dc95c::CUnitBrowserEntry | 0x78 | observer_select_frame | void* | new |
| _A0xf32dc95c::CUnitBrowserEntry | 0xC8 | unit | CUnit* | new |
| _A0xf32dc95c::CUnitBrowserEntry | 0xCC | unit_id_type | int | new |
| _A0xf32dc95c::CUnitBrowserEntry | 0xD0 | unit_id | int | new |
| _A0xf32dc95c::CUnitBrowserEntry | 0xF0 | in_game_screen | CInGameIdler* | new |
| _A0xf32dc95c::CUnitBrowserEntry | 0xF4 | depth | int | new |
| _A0xf32dc95c::CUnitBrowserEntry | 0xF8 | menu | CSideMenu* | new |
| CTopBar | 0x168 | observer_viewprovinces | void* | new |
| CTopBar | 0x194 | observer_viewarmy | void* | new |
| CTopBar | 0x1C0 | observer_viewair | void* | new |
| CTopBar | 0x1EC | observer_viewnaval | void* | new |
| CTopBar | 0x218 | observer_viewcombat | void* | new |
| CTopBar | 0x244 | observer_viewdeploy | void* | new |
| CInGameIdler | 0xD10 | side_menus | void** | revised: comment only - the menus' order and which indices are read where |

### B.1 The frame: `CSideMenu`

`CSideMenu` is a `CReloadableInterface` of 9 slots. Its constructor (`0x823E90`; `this` on the stack, then the screen,
the window name and a mouse observer; `ret 0x10`) registers it for reload under the .gui file its window type came from
(`+4`; `0xA7E210`), and keeps the in-game screen at `+0x20`, the window at `+0x24` (made by name through the gui's slot
11) and the observer at `+0x28`. 0x2C bytes; the provinces, army and naval menus add no field and are `new(0x2C)`.

| slot | body | what it does |
| --- | --- | --- |
| 0 | `0x824070` Rebuild | notes whether shown, hides, destroys and remakes the window, shows it again if it was; answers true |
| 1 | `0x823F60` | scalar deleting destructor (body `0x823F90`: destroys the window, deletes the observer, unregisters the reload) |
| 2 | `0x824100` Show | window `+0x18` slot 13 |
| 3 | `0x824110` Hide | window `+0x18` slot 14 |
| 4 | `0x824120` IsShown | already recorded: the window's byte `+0x5B` |
| 5 | `0x824050` | where there is a window, its slot 11, read as "raise" (*inferred*). **Not recorded**: the same body is CStratWarfareWindow's slot 6, a fold across two families (trap 4) |
| 6 | `0x598DB0` | folded `xor al,al; ret 4` (192 tables): "owns no element" |
| 7 | `0x824030` Update | every frame for a shown menu (`CInGameIdler_UpdateOpenView`): the mouse observer's slot 1, where there is one |
| 8 | `0x776F20` | folded empty tooltip (76 tables) |

**`CSideMenuMouseObserver`** has two slots, a destructor (`0x823E60`) and slot 1 the folded empty stub `0xABF890`;
polled by the menu's slot 7, not registered with the map. Only the deploy menu has one (`CDeploymentMenuMouseObserver`);
the other five are made with none.

**On screen**: every `sidebar_*` window is at (0,0), 256 x 512, UPPER_LEFT (the deploy menu at y 35); the icon at y 65,
the title at (20,97), the army, air and naval `unit_queue` at y 120. **One is open at a time** (B.2). **The single unit
panel moves right of it**: `CInGameIdler_LayoutUnitPanels` (and `LayoutUnitRows`) take their x from **side menu 1**'s
window width whenever *any* side menu is open; all six are 256 wide, so in effect it is the open one's - the record had
"the open side menu's width". **`browser_offset` (x 10, y 0)** is read in one place (VA `0x8259B3`), the army row's
update: a row's x is depth x 10.

### B.2 How they are made, opened and closed

**Made**: `CInGameIdler_BuildViews` (rva `0x259760`), from `CInGameIdler::Enter` (VA `0x65D6A7`) and from the console's
`reloadinterface` (rva `0x3B610`, "Reloads the entire interface", answering `Interface reloaded.`). It deletes every
country view (`+0xD00`) and side menu (`+0xD10`), makes the six views and pushes the six menus; **a menu's number is its
push order**: 0 provinces (inline), 1 army (inline), 2 naval (inline), 3 air (`0x824C20`), 4 combat (`0x643BA0`), 5 deploy
(`0x8277A0`). None is shown; nothing else writes the vector.

**Opened**: `CInGameIdler_OpenSideMenu(screen@ESI, index)` (rva `0x2655C0`, `ret 4`), read whole. It finds the last menu
that answers IsShown; if one is shown, every shown menu is hidden (slot 3) and `bg_main_menus` (`+0x1914`) hidden - **and
if that was menu `index`, it lays out the unit panels and returns: the toggle**. Otherwise `ClearSelection` (screen slot
46), then menu `index` shown (slot 2) and raised (slot 5). So one at a time, a second click on the same one closes it, and
opening one lets the selection go.

**Closed**: `CInGameIdler_CloseSideMenus(screen@EAX)` hides every shown menu, then 0x664160 (which places the `+0x1360`
window beside the deploy menu where that is shown), and where the single unit panel exists moves it back to the left
(`0x761EB0`). Thirteen callers, among them OnAlertClicked, OpenCountryView and HandleInput. Three neighbours:
`CInGameIdler_AnySideMenuOpen` (rva `0x2652D0`); `CInGameIdler_RefreshOpenSideMenus` (rva `0x265410`: hide, show and
raise each open menu, after `CCreateHigherCommand` / `CCreateNewHQCommand` - it only reopens what is open);
`CInGameIdler_SetDeployMenuShown(screen@EAX, bool)` (rva `0x265490`, menu 5 only).

**The six top-bar handlers**, just after `CTopBar::OnTheatreButton`:

| handler (rva) | button | OpenSideMenu number | glue in CTopBar |
| --- | --- | --- | --- |
| 0x2CF0B0 | button_viewprovinces | 0 | +0x168 |
| 0x2CF300 | button_viewarmy | 1 | +0x194 |
| 0x2CF550 | button_viewair | 3 | +0x1C0 |
| 0x2CF7A0 | button_viewnaval | 2 | +0x1EC |
| 0x2CFA00 | button_viewcombat | 4 | +0x218 |
| 0x2CFC50 | button_viewdeploy | 5 | +0x244 |

Each opens its menu, then looks up all six buttons in the top bar's window and sets its own button's frame to 2 if it
was 1, else 1, and the other five to frame 1 - with no test that a lookup found the button.

**Nothing reaches them, and nothing reaches menus 0-4** - *confirmed*, by these searches:
1. **The handlers**: each handler's address searched for as a 4-byte value over every section of the image (scratch
   `findptr.py`) appears exactly once, the CTopBar constructor's store into its glue (`0x6C97C5` ... `0x6C9923`); the
   glue offsets `+0x168` ... `+0x244` appear in the whole CTopBar code range (VA `0x6C9530`-`0x6D0130`) only in the
   constructor's and destructor's stores. **Positive control**: in the same disassembly `CTopBar::Build` takes `lea` of
   all thirteen other glues (`+0x34`, `+0x60`, `+0x8C`, `+0xB8`, `+0xE4`, `+0x110`, `+0x13C`, `+0x270`, `+0x29C`,
   `+0x2C8`, `+0x2F4`, `+0x320`, `+0x34C`), and `OnDiplomacyButton`'s address is likewise found once, in the constructor.
   The six button names are referenced only inside the six handlers, never in Build. So the glues are never attached,
   and **restoring the buttons in a `topbar.gui` would draw six buttons that do nothing.**
2. **OpenSideMenu**: `findRefs --callers` gives 7 direct calls and no pointer to it anywhere in the image; the alert
   pushes 5, the handlers 0-5.
3. **The vector**: `fieldchain.py --field 0xD10` lists every site. Outside BuildViews and the loops (Open, Close,
   AnyOpen, Refresh, UpdateOpenView, the destructor), only `[+0xD10]+0x14` (menu 5: GetElementTooltip, HandleInput,
   0x41E510, 0x664160) and `+4` (menu 1's width) are read.
4. **The console**: the only command that touches the menus is `reloadinterface`, which remakes them and opens none. No
   define was looked for: nothing on these paths reads one.

### B.3 The army menu: `CSideMenuArmy` (`sidebar_army`)

**What it lists**: the played country's units (`CCountry +0xBAC`, in that list's order) as a depth-first tree - at the
top every unit with no superior (`+0x1E0` null) that is a land unit (slot 15); under a unit whose `outliner_expanded`
(`+0xB4`) is set, its children (`+0x1E4`) at depth + 1, each straight after its parent. Any kind of unit with a superior
is listed, so fleets and air groups under a land headquarters show there. The flag is **the outliner's own**: opening a
unit in either opens it in both.

**When the list is made**: on Show (fresh each time it opens) and on Rebuild; each frame Update counts the rows that
should be (`CountUnitRows`) and remakes the list where the count differs, else calls each row's slot 8. So a row is made
again only when the count changes - an expand or collapse, a unit gained or lost - and **a unit that moves keeps the
location its row was made with**. The title is never set: the file's `Army Units`, which is no localisation key in the
base game's or Their Finest Hour's tables.

**A row**, `CUnitBrowserEntry` on `unitbrowse_entry` (0x100 bytes; constructor rva `0x4252D0`), holds the unit by id and
finds it again before each use:
- `name` the unit's name (slot 7); `location` the name of the province it is in;
- `counter_type` `GFX_counter_` + the key of the first brigade's type where intel_level >= 3 and the unit has a brigade,
  changed only where that sprite exists, else the file's `GFX_temp_unit_icon`;
- `counter_size` the frame by oob_level: theatre 6, army group 5, army 4, corps 3, division 2 (more than one brigade) or
  1, fleet 2, air and anything else 1 - `GetCounterSize` + 1, as the deploy menu's line;
- name and location never refreshed after the row is made.

**Each frame (slot 8)**: `expand` disabled (button slot 47) where the unit has no children (`+0x1EC == 0`), else enabled;
its label stays the file's `>` open or closed (the outliner's row changes its frame; this one does not). The row's
window x is set to depth x `browser_offset`.x - 10 px a level - its y kept.

**Clicks**: `expand` (`0x825A60`) flips `+0xB4`, so the next frame's count differs and the list is remade with the
children shown or gone. `select_frame`, through the shared thunk `0x67A310` (`jmp [vftable+0x10]`) to slot 4:
`ClearSelection`, then `Select(unit)` - a plain single selection, so the unit panel opens beside the menu. A clicked row
whose unit is gone does nothing.

**Tooltips: none.** `GetElementTooltip` asks only side menu 5; the base slots 6 and 8 are the folded false and empty
stubs; the file's tooltip fields are empty; the row sets no group.

### B.4 The provinces and combat menus

`CSideMenuProvinces` has no slot of its own but the destructor; its constructor is inlined into BuildViews - the base
constructor on `sidebar_provinces`, no observer. `CSideMenuCombat`'s constructor (`0x643BA0`) is the same on
`sidebar_combat`. Neither has a list, an update, a click or a tooltip. Shown, each is its file icon
(`GFX_sidebar_view_provinces` / `_combat`) and its title, `Provinces` / `Active Combats`, neither a localisation key and
so shown as written (*inferred* from the absence of a key). They look like menus that were never filled in.

### B.5 `CBrowserItem` is not a side-menu row

Its constructor (`0x774D80`, `ret 0x14`, one caller: the recursive builder `0x777630`) uses the window
**`expedition_entry`** of `interface/diplomacydialog.gui` - the expeditionary-force request dialog's `unitlist_list`,
with the same six elements as `unitbrowse_entry`. RTTI gives both `CBrowserItem` and `CUnitBrowserEntry`
`CStandardlistboxItem` as their base; the second is not derived from the first. Only its outline was read (*inferred*).

### Not settled

- Window slot 11 as "raise" and slot 20 as "destroy", taken from neighbouring records, not read.
- `0x41E510`, which opens or closes the deploy menu (5 only) on some condition: not read.
- The rest of BuildViews past the menus (`unitlist_start` / `unitlist_offset`).

## C. The air and naval side menus

*Reader C. Addresses are VAs unless marked rva. Read statically on 2026-11-04 and checked against no running game; the
menus cannot be opened in the shipped game (section B).*

**Synopsis.** The aim was to read `CSideMenuAir`, `CSideMenuNaval` and their rows: which bases and units each lists and
in what order, what every element of `basebrowse_entry` and `unitbrowse_entry` shows, what each click does, the tooltips,
and when the lists are made again. All of it is settled, almost all `confirmed` off the bytes. The air menu lists the
player's air bases and the naval menu the player's ports, each base row followed by the units based there. A base row's
`size` is the base's working level over its built level - `4.50/5` - not a count and not a capacity. `select_frame`
clears the selection and selects the unit; `expand` flips the outliner's own `CUnit +0xB4` flag. Neither menu has a
tooltip. **Corrected in the brief**: the rows do not derive from `CBrowserItem`. `CAirBrowserEntry`,
`CNavalBrowserEntry`, `CBrowserItem` and `CUnitBrowserEntry` are four siblings under `CStandardlistboxItem`, so C's rows
lean on none of B's row classes, only on the `CSideMenu` frame. Nothing already in the record is revised.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| 0x424C20 | CSideMenuAir::CSideMenuAir | new | confirmed | `sidebar_air`, no mouse observer; this@ESI; one caller, in CInGameIdler's constructor. The naval one is inlined at VA 0x65A0ED |
| 0x424CA0 | CSideMenuAir::ScalarDeletingDestructor | new | confirmed | slot 1 |
| 0x424CD0 | CSideMenuAir::Rebuild | new | confirmed | slot 0: CSideMenu's slot 0, then BuildList |
| 0x424CF0 | CSideMenuAir::Show | new | confirmed | slot 2: show the window, then BuildList |
| 0x424D10 | CSideMenuAir::Update | new | confirmed | slot 7: rebuild the list when the row count differs, else each row's slot 8 |
| 0x424E50 | SideMenu_CountUnitRows | new | confirmed | recursive row count; one body shared by air and naval, so the name is class-free |
| 0x424EB0 | CSideMenuAir::AddUnitRows | new | confirmed | one unit row per unit, expanded children after it; no owner test, no indent |
| 0x424FF0 | CSideMenuAir_CountRows | new | confirmed | AirBases (+0xD70) x the base object +0x54 -> +4 |
| 0x425080 | CSideMenuAir_BuildList | new | confirmed | base row, then the units based there, for each province of AirBases |
| 0x424140 | _A0xaec99346::CAirBrowserEntry::CAirBrowserEntry | new | confirmed | row parent: window +0x20, screen +0x28, menu +0x30 (no_signature: string passed by value, screen in EDI) |
| 0x424200 | _A0xaec99346::CAirBaseBrowserEntry::CAirBaseBrowserEntry | new | confirmed | `name` = province; `size` = air_base level_current (2 decimals) "/" level_max |
| 0x424500 | _A0xaec99346::CAirUnitBrowserEntry::CAirUnitBrowserEntry | new | confirmed | name, location, counter (intel >= 3), size frame, two glues, CRef |
| 0x4249B0 | _A0xaec99346::CAirUnitBrowserEntry::Update | new | confirmed | slot 8 of both unit rows (one body): `expand` disabled when the unit has no children |
| 0x424A90 | _A0xaec99346::CAirUnitBrowserEntry::OnExpandClicked | new | confirmed | flips CUnit +0xB4 outliner_expanded; used by both unit rows |
| 0x424B50 | _A0xaec99346::CAirUnitBrowserEntry::OnSelect | new | confirmed | slot 4 of both unit rows: ClearSelection, then Select(unit) |
| 0x428EB0 | _A0xfce85ce3::CNavalBrowserEntry::CNavalBrowserEntry | new | confirmed | twin of 0x424140 (not folded) |
| 0x428FE0 | _A0xfce85ce3::CNavalBaseBrowserEntry::CNavalBaseBrowserEntry | new | confirmed | the same with naval_base (+0x300) |
| 0x4292E0 | _A0xfce85ce3::CNavalUnitBrowserEntry::CNavalUnitBrowserEntry | new | confirmed | twin of the air unit row; uses the air row's handlers |
| 0x429790 | _A0xfce85ce3::CNavalUnitBrowserEntry::ScalarDeletingDestructor | new | confirmed | slot 0 of both unit rows (one body) |
| 0x4297C0 | _A0xfce85ce3::CNavalUnitBrowserEntry::~CNavalUnitBrowserEntry | new | confirmed | destructor body, both unit rows |
| 0x429E40 | _A0xfce85ce3::CNavalUnitBrowserEntry::ScalarDeletingDestructorAt1C | new | confirmed | adjustor thunk, slot 0 of both +0x1C tables |
| 0x429870 | CSideMenuNaval::ScalarDeletingDestructor | new | confirmed | slot 1 |
| 0x4298A0 | CSideMenuNaval::Rebuild | new | confirmed | slot 0 |
| 0x4298C0 | CSideMenuNaval::Show | new | confirmed | slot 2 |
| 0x4298E0 | CSideMenuNaval::Update | new | confirmed | slot 7 |
| 0x429A20 | CSideMenuNaval::AddUnitRows | new | confirmed | naval twin |
| 0x429B60 | CSideMenuNaval_CountRows | new | confirmed | NavalBases (+0xD80) x +0x58 -> +4 |
| 0x429BF0 | CSideMenuNaval_BuildList | new | confirmed | ports, each followed by the fleets based there |

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| _A0xaec99346::CAirBrowserEntry | 0x20 | window | void* | new |
| _A0xaec99346::CAirBrowserEntry | 0x28 | in_game_screen | CInGameIdler* | new |
| _A0xaec99346::CAirBrowserEntry | 0x30 | menu | void* | new |
| _A0xaec99346::CAirBaseBrowserEntry | 0x34 | province | CMapProvince* | new |
| _A0xaec99346::CAirUnitBrowserEntry | 0x38 | expand_observer | void* | new |
| _A0xaec99346::CAirUnitBrowserEntry | 0x88 | select_observer | void* | new |
| _A0xaec99346::CAirUnitBrowserEntry | 0xD8 | unit | CRef | new |
| _A0xfce85ce3::CNavalBrowserEntry | 0x20 | window | void* | new |
| _A0xfce85ce3::CNavalBrowserEntry | 0x28 | in_game_screen | CInGameIdler* | new |
| _A0xfce85ce3::CNavalBrowserEntry | 0x30 | menu | void* | new |
| _A0xfce85ce3::CNavalBaseBrowserEntry | 0x34 | province | CMapProvince* | new |
| _A0xfce85ce3::CNavalUnitBrowserEntry | 0x38 | expand_observer | void* | new |
| _A0xfce85ce3::CNavalUnitBrowserEntry | 0x88 | select_observer | void* | new |
| _A0xfce85ce3::CNavalUnitBrowserEntry | 0xD8 | unit | CRef | new |

### C.1 The two menus

**The air menu is made by `CSideMenuAir::CSideMenuAir` (`0x824C20`)**: `CSideMenu`'s constructor (`0x823E90`) with the
window name `sidebar_air` and a null mouse observer (`+0x28`), then its own vftable. Its one caller is
`CInGameIdler::CInGameIdler` (`0x65A20E`), after a 0x2C-byte `operator new`. **The naval menu has no constructor of its
own**: the same three steps are inlined at `0x65A0ED`-`0x65A154` with `sidebar_naval`. The idler's constructor makes the
menus as provinces, army, naval, air, deploy; which number opens which is B's reading.

Both menus override slots 0, 1, 2 and 7. Slots 3 (hide), 4 (`IsShown`), 5, 6 and 8 are `CSideMenu`'s: **slot 6** is the
192-table `xor al,al; ret 4`, so "does this element belong to the menu" always answers no; **slot 8** is `EmptyTooltip`.

| slot | air | naval | what it does |
| --- | --- | --- | --- |
| 0 `Rebuild` | `0x824CD0` | `0x8298A0` | `CSideMenu` slot 0 (`0x824070`: the window destroyed and made again, shown again if it was), then build the list; returns 1 |
| 1 | `0x824CA0` | `0x829870` | scalar deleting destructor, through `CSideMenu`'s destructor body `0x823F90` |
| 2 `Show` | `0x824CF0` | `0x8298C0` | show the window, then build the list |
| 7 `Update` | `0x824D10` | `0x8298E0` | section C.3 |

**The title and the icon are never touched.** `title_view_air`, `title_view_naval`, `sidebar_view_air` and
`sidebar_view_naval` do not occur in the image; the positive control, the same search, finds `title_view_deploy` with its
two references at `0x827E7E` and `0x828801`. So each title is the file's own `text`, "Air Units" or "Naval Units",
neither a localisation key in either install folder's `*.csv`.

### C.2 What is listed, and in what order

**`CSideMenuAir_BuildList` (`0x825080`)**, and `CSideMenuNaval_BuildList` (`0x829BF0`) the same way: empties
`unit_queue`; takes the player (the in-game screen's slot 23, `GetPlayer`) and the country database; walks the player's
base list in its own order - **air: `AirBases`, `CCountry +0xD70`, the Lua API's `GetAirBases`; naval: `NavalBases`,
`CCountry +0xD80`**. For each province in it: **a base row** (`CAirBaseBrowserEntry` / `CNavalBaseBrowserEntry`, 0x38
bytes), then **a unit row for each unit on that province's base object**, in the base's own order (air
`CMapProvince +0x54`, the `CUnitBaseProvince`, its unit list at `+4`; naval `+0x58`, `+4`), added by `AddUnitRows`
(`0x824EB0` air, `0x829A20` naval). **A unit whose `outliner_expanded` (`CUnit +0xB4`) is set is followed by the rows of
its children** (`+0x1E4`), recursively.

Consequences, all read off the code:
- **A unit appears under its home base wherever it is now**; `location` says where it is.
- **No owner is tested** (no read of `+0x124`/`+0x128` in either `AddUnitRows`): every unit on the base's list gets a
  row, so an ally's units based at the player's base would be listed. That allies can base there is from other readings
  (the capture code tests each listed unit's owner for enmity), not from this one.
- **An air group on a carrier is in no row** - it is based on a `CUnitBaseCarrier`, in no province's list - nor is a
  unit with no home base.
- **Depth is never shown.** `AddUnitRows` carries a depth (from 1) and does not hand it to the row, and nothing in either
  menu reads `browser_offset` - its only readers are `CBrowserItem` slot 8 (`0x7753C0`) and `CUnitBrowserEntry` slot 8
  (`0x8258A0`), B's, which is the positive control. **So expanded children are not indented.**
- At depth 0, `AddUnitRows` and `SideMenu_CountUnitRows` skip a unit with a parent (`+0x1E0`), but neither menu calls
  them at depth 0, so that filter never applies here.

What keeps `AirBases` and `NavalBases` up to date was not read here.

### C.3 When the list is made again

Every call to **slot 7, `Update`**: tells the mouse observer if there is one (null for both); compares `unit_queue`'s row
count with what `CSideMenuAir_CountRows` (`0x824FF0`) / `CSideMenuNaval_CountRows` (`0x829B60`) says it should be - one
per base, one per unit on the base, plus `SideMenu_CountUnitRows` (`0x824E50`, one body for both) for each expanded unit;
**where they differ, the whole list is rebuilt; where they agree, each row's slot 8** - a unit row's only enables or
disables `expand`, a base row's is the empty stub.

**So a row's text is written once, in its constructor, and never refreshed**: a unit that moves keeps its old
`location`, a base whose level changes its old `size`, until something changes the count - a unit based or unbased, a
unit expanded. How often the in-game screen calls slot 7 is B's reading.

### C.4 A base's row (`basebrowse_entry`)

Constructors `0x824200` (air) and `0x828FE0` (naval); the province at `+0x34`.

| element | what it shows |
| --- | --- |
| `name` | the province's name |
| `size` | `FormatFixedPoint(level_current, 2) + "/" + level_max / 1000`, of the province's air base (`+0x304`) or naval base (`+0x300`) |

So **`size` is the base's working level, to two decimals and cut, over its built level as a whole**: `5.00/5`, or
`3.40/5` after bombing. The row has no click and no update of its own: its slot 4 is the 85-table default (`0xA7F7B0`),
which marks the option chosen and tells the option's observers, of which this menu registers none; its slot 8 is the
empty stub.

### C.5 A unit's row (`unitbrowse_entry`)

Constructors `0x824500` (air) and `0x8292E0` (naval); 0x100 bytes, the unit a `CRef` at `+0xD8`.

| element | what it shows or does |
| --- | --- |
| `name` | the unit's name (its slot 7) |
| `location` | the name of the province the unit is in now (`+0x130`) |
| `counter_type` | `GFX_counter_` + the key of the first brigade's definition, **only where the screen's country knows the unit at `intel_level` (`+0x1F8`) 3 or more** and it has a brigade; otherwise `GFX_counter_` alone - and the sprite is set only where it exists, so otherwise the file's `GFX_temp_unit_icon` stays. The deploy menu's rows have no intel test; these do |
| `counter_size` | frame `GetCounterSize + 1`, the same inline seven-way jump: an air unit frame 1, a fleet frame 2 |
| `expand` | **disabled where the unit has no children** (`children_count +0x1EC == 0`), else enabled, checked every `Update` (`0x8249B0`); its `>` never changes. A click (`0x824A90`) **flips `CUnit +0xB4 outliner_expanded`, the outliner's own flag** - expanding here expands it in the outliner and back - and the next `Update` sees another count and rebuilds |
| `select_frame` | through the slot-4 thunk `0x67A310` to `OnSelect` (`0x824B50`): the unit found again by its id, the in-game screen's `ClearSelection` (slot 46), then `Select(unit)` (slot 38). **The map is not centred and no window opens** |

Whether a click on the row's background reaches slot 4 too is the list's behaviour and was not read. Air units and
fleets of 1936 seldom have children, so **`expand` will nearly always be disabled** - inference.

**One code path serves both unit rows** (identical code folded across the two anonymous namespaces): slots 8 and 4
(`0x8249B0`, `0x824B50`) and the expand handler (`0x824A90`) sit in the air translation unit and the naval row uses
them; slot 0 (`0x829790`), the destructor body (`0x8297C0`) and the slot-0 thunk at `+0x1C` (`0x829E40`) sit in the
naval one and the air row uses them. Each is named for where it sits and recorded in both slot tables.

### C.6 Tooltips

**None.** The `.gui` gives every button an empty `tooltip`, `tooltipText` and `delayedTooltipText`; neither menu
overrides `CSideMenu`'s slot 6 (always "not mine") or slot 8 (`EmptyTooltip`); no row class overrides a slot beyond 0, 4
and 8.

### C.7 What these menus lean on of B's

Only the frame: `CSideMenu`'s constructor `0x823E90`, its slot 0 `0x824070`, its destructor body `0x823F90`, its slots
3-6 and 8, and its fields `+0x20` (in-game screen), `+0x24` (window), `+0x28` (mouse observer). Nothing of `CBrowserItem`
or `CUnitBrowserEntry`. The rows are `CStandardlistboxItem`s; every slot of the parents `CAirBrowserEntry` and
`CNavalBrowserEntry` is inherited, and their constructors (`0x824140`, `0x828EB0`) inline `CStandardlistboxItem`'s and
make the row's window through the in-game screen's gui factory.

### C.8 Not established

- What adds and removes provinces in `CCountry +0xD70` / `+0xD80`, so exactly which bases appear - probably the
  provinces with a base the country holds; not read.
- Whether a click on a unit row outside `select_frame` reaches its slot 4.
- How often slot 7 runs, and what opens either menu: section B.
