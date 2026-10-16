# Selection: the click, the box, the keys and several units selected

How the player selects on the map and what the screen does with several units selected, read for OpenHOI3 in the
selection wave of 2026-10-16 (`WAVE.md`), on the maintainer's word that day: before the headless run, "some useability
improvements - implement the drag-box-selection; implement the shift-multiselect for units (combines with the drag
box)". Two readers: **A** the input - the click, the box, the keys and the right click with several selected; **B** the
multi-unit panel. Addresses are VAs, with rvas beside named functions; texts are Their Finest Hour's English.

Earlier readings this extends: `FINDINGS-provinceview.md` A.1 (the selection itself, the click and Shift-click on a
province), `FINDINGS-transport.md` C.3 (the multi-unit panel's three carrying buttons), `FINDINGS-unitpanel.md` section
4 (the header row), `FINDINGS-unitpaneltooltips.md` section 3, `FINDINGS-movement.md` section 1 (`CUnit::OrderToProvince`),
`FINDINGS-counters.md`, `FINDINGS-scrollbar.md` (the input object's slots 10 and 12), `FINDINGS-gui.md` (`unitlist_start`,
`unitlist_offset`).

## A. Selecting: the click, the box and the keys

*Read 2026-10-16 on the listing, checked against the decompilation of a copy carrying the record. Addresses are VAs,
with rvas beside named functions. This continues `FINDINGS-provinceview.md` A.1, `FINDINGS-counters.md`,
`FINDINGS-seaair.md` section 6 and `FINDINGS-hierarchy.md` section 6, and corrects A.1's line on the drag box.*

**In short.** Everything happens in `CInGameIdler_HandleInput` (`0x652540`, rva `0x252540`), once a frame, over a queue
of the frame's input events.
- **The left button.** A left press stores the ground point under the pointer. At release the gesture is a drag if the
  pointer's ground point has moved at least **2.0 map units**; otherwise it is a click.
- **A click** selects what is under the pointer:
  - battles are tested first, then counters and building pictures, then the province itself;
  - Shift adds it or takes it out;
  - Ctrl on an army also takes everything under it;
  - a click on the one selected unit's own counter picks the next of its owner's units in that province.
- **A drag** draws a white outline two pixels wide on the ground. At release it takes the player's own units whose map
  position is in the box: **land units if there are any, else fleets, else air units**. It clears first unless Shift is
  held while units are selected. Alt held cancels it, but Alt is probably never seen.
- **A right click** sends each selected thing, in selection order, its "right click on a province" slot.
- **Digits** recall selection groups. Ctrl+digit stores one through a command, and pressing the same digit again
  centres the camera on the group's first unit.
- Nothing here shows any text.

### A.1 The keys: slots 10, 11 and 12

`CInGameIdler +0x1C` is **the keyboard**. It has no RTTI. Its table is at `0x1608494`, written only by its constructor
`0xB4DFF0`, which is made by the platform factory's keyboard slot (`0xB08800`, slot 2 of the factory table at
`0x1605328`). It is the object `UpdateMapCamera` asks the arrow keys of (the caller loads `[ebx+0x1C]` at `0x656693`;
`FINDINGS-camera.md`), and that slot 9 body exists only in this table.

The keyboard holds a 256-byte "held" array at `+0x40` and a 256-byte "pressed" array at `+0x140`, both indexed by
Windows virtual-key code.

| slot | body | what |
| --- | --- | --- |
| 4 | `Keyboard_OnKeyMessage` `0xB4E0D0` | from the window procedure: WM_KEYDOWN or WM_SYSKEYDOWN sets `[vk+0x40]`, `[vk+0x140]` and `+0x240`; a system key with lParam's Alt bit also sets VK_MENU's bytes (`+0x52`, `+0x152`) |
| 5 | `Keyboard_ForgetReleasedKeys` `0xB4E090` | each code: held cleared where GetAsyncKeyState says it is up; pressed cleared |
| 9 | `Keyboard_IsKeyDown` `0xB4E160` | `[vk+0x40]` |
| **10** | `Keyboard_IsShiftDown` `0xB4E120` | **`[+0x50]`, VK_SHIFT** |
| **11** | `Keyboard_IsAltDown` `0xB4E140` | **`[+0xE4]` or `[+0xE5]`, VK_LMENU or VK_RMENU** |
| **12** | `Keyboard_IsCtrlDown` `0xB4E130` | **`[+0x51]`, VK_CONTROL** |

- **Shift and Ctrl** are confirmed off the bytes. This settles `FINDINGS-scrollbar.md`'s `likely` for slot 12. The
  scrollbar asks the gui's input object rather than the screen's; that it is the same class is *inferred*, since this
  is the only keyboard table in the image. It also names the key that `FINDINGS-seaair.md` section 1 left open for the
  land orders window: **Ctrl and a right click**.
- **Alt probably never answers.** The keyboard's only setter stores at the message's own key code, and Windows reports
  either Alt key as VK_MENU (0x12), which lands at `+0x52`. Nothing found writes `+0xE4` or `+0xE5`. The image imports
  neither MapVirtualKey nor GetKeyboardState. *Inferred*: slot 11 is always false.

**How key events arrive.** The window procedure (`0xA91610`) queues one record per event in `CInGameIdler +0x1CB0`:

| offset | holds |
| --- | --- |
| `+0` | the key code |
| `+4` | the message: 0x100 key down, 0x102 character |
| `+8` | 0 mouse, 1 key |
| `+0x10` | 3 press, 4 release |
| `+0x14` | button: 1 left, 2 right |
| `+0x18` | handled byte |
| `+0x20` | next |

A **character** (WM_CHAR) is always queued unless `0xA800D0` claims the key. A **key down** is queued only where
`0xA800D0` claims it (the navigation keys) **or Ctrl is held**. So a plain digit arrives once, as a character, and
Ctrl+digit arrives once, as a key down with the same code.

### A.2 The left button: press, drag and release

- **Press** (event `+0x10` = 3, `+0x14` = 1, not handled by the interface):
  - `drag_armed` (`+0x1300`) = 1;
  - `drag_start` (`+0x12F4`, three floats: x, height, z) = the ground point under the pointer, from CMap `0x492850`
    (*inferred* to be the screen-to-ground pick, from its use);
  - `left_down` (`+0x12E0`) = 1.
- **Release** (`+0x10` = 4, `+0x14` = 1, `left_down` set; **the handled byte is not tested**, so a release over a window
  still completes the gesture):
  - the right-click menu is hidden (`+0x1D90`);
  - `left_down` = 0;
  - then `CInGameIdler_IsDragging` (`0x64D850`, rva `0x24D850`) decides.
- **The drag test.** It needs `drag_armed`, and the length of (the ground point now under the pointer - `drag_start`),
  in three dimensions, of **2.0 or more**. 2.0 is the float literal at `0x1718064`; exactly 2.0 counts as a drag. These
  are map units, not pixels. With `FINDINGS-camera.md`'s view of 0.828 x height map units top to bottom, 2.0 map units
  on a 1080-high screen is about:

  | camera height | pixels |
  | --- | --- |
  | 40 (lowest) | 65 |
  | 100 | 26 |
  | 330 (start) | 8 |
  | 1000 | 2.6 |

  *Inferred* arithmetic, for the straight-down camera of `always_counters`.
- **While the button is held and it is a drag**, the frame draws the box (A.5). The pointer is set to cursor number 3
  (`CInGameIdler_UpdateCursor`, `0x653990`). What number 3 looks like was not read.

### A.3 What is under the pointer

Every frame, `+0x1DD4` (**`hovered`**) is set from `MapGraphics_PickUnderPointer` (`0x6416D0`, rva `0x2416D0`), and
`+0x1DD0` (`province_under_pointer`) from the province id it reports. In order, the first hit wins:

1. the province under the pointer (`0x8558F0`); none means nothing;
2. **a battle's marker** in that province, then in each neighbour in the template's edge order
   (`ProvinceGraphics_HitTestBattles`, `0x640DA0`). The first 3-D object that is hit and shown is matched to the
   province's battles (`+0x2EC`) and the battle's selectable is returned. Selecting it opens its window
   (CCombat::OnSelected);
3. **counters and building pictures** of the province, then of each neighbour (`ProvinceGraphics_HitTest`, `0x640F40`;
   A.4). A neighbour's hit makes the neighbour `province_under_pointer`;
4. the province itself.

Battles, counters and buildings answer only with the camera at height **500 or under** (the double at `0x160A538`).
The large base pictures are the exception and answer at any height (`FINDINGS-camera.md`).

**The kinds** (selectable slot 1, read off each table) govern the one-kind rule of `Selection_CanAdd`:

| kind | what | slot 2, "may be selected" |
| --- | --- | --- |
| 0 | army (`CArmy`) | the unit's owner is the player (`0x5C0540`) |
| 1 | fleet (`CNavy`) | the same |
| 2 | air unit (`CAir`) | the same |
| 3 | province (`CMapProvince +8`) | always |
| 4 | port (`CPort`) | its list is not empty and its first fleet may be selected |
| 6 | building (`CProvinceBuilding`) | always |
| 7 | battle or bombing (`CCombat +8`, seven classes) | always |
| 8 | air base (`CUnitBaseProvince +0x18`) | always |
| 9 | the `CSelectable` default | - |

Kind 9 is answered by no class with RTTI. HandleInput clears the whole selection each frame if anything selected is of
kind 9, which in practice never fires.

### A.4 A click

On release without a drag:

- **A deployment being placed** goes first (`FINDINGS-buildingqueue.md` B.4, unchanged).
- Otherwise `clicked` (`+0x1314`) = `hovered`.

**With Shift and something under the pointer:**
- already selected -> `Selection_Remove`; `selection_changed` is set only where it is an air unit;
- not selected and `Selection_CanAdd` allows it -> **added, nothing cleared**;
- otherwise, with anything selected, **nothing at all**.

**Plain (or Shift with nothing under the pointer), in order:**
1. note whether the deploy menu (side menu 5) is up;
2. close the side menus (`CInGameIdler_CloseSideMenus`) and the orders view;
3. `Selection_Clear` under `clearing_selection`;
4. free the unit rows (`+0xD20`);
5. set `selection_changed`;
6. hide the multi-unit slider and the upgrades window (`0x66B7B0`);
7. toggle an open country view shut;
8. **select `hovered` where `Selection_CanAdd` allows**;
9. **with Ctrl, if it is an army: `CUnit::SelectSubordinates`** (`0x5D36A0`, rva `0x1D36A0`) - every unit directly
   below it whose IsLand matches its own, in the order of battle's list order, selected through `CInGameIdler::Select`
   where not yet selected, and **then the same for that child before the next one** - each unit followed by its own
   command (A.12 settles the order on the listing). So a whole army group's land units come with its HQ;
10. **without Ctrl**, the deploy menu is reopened where exactly one thing is now selected and step 2 had closed it.

`last_group` (`+0x12E4`) = -1 after an add. There is no **double click**: the handler reads no clock.

**What that means where the click lands:**
- **A unit's counter.** The plain click selects that unit alone, whatever was selected. Shift adds it if it is the same
  kind as what is selected, removes it if already selected, and otherwise does nothing.
- **A foreign unit's counter.** Slot 2 refuses it, so a plain click empties the selection and selects nothing; with
  Shift nothing happens.
- **The one selected unit's own counter: the cycle** (`ProvinceGraphics_HitTest`). Where exactly one unit is selected
  and its own figure or counter is hit:
  - every unit of the province's `map_units` vector (`CMapProvince +0x2C8`) that is in the same province, has the same
    owner and is not at its own base is gathered;
  - the walk starts at `map_unit_cursor` (`+0x2E8`), which CUnit::OnSelected sets to the selected unit's index
    (`0x4A5880`) and OnDeselected sets to 0;
  - the answer is **the unit after the selected one, wrapping**; alone, it answers itself.

  A plain click therefore steps through a stack, as the maintainer described (`FINDINGS-counters.md` section 7).
  **Shift on it adds the next unit instead.**
- **Other counters, with the camera above `counter_distance`**: the unit at the province's cursor is taken, if it is
  not selected, not at its own base and at intel 2 or more. Under `counter_distance`, the unit whose own figure was hit.
  Building pictures need the settings word's bit 0x20, counters bit 0x800. Building pictures are skipped in a province
  hidden by fog.
- **A port or air base** (picture or large picture) offers a CPort (kind 4) or an air base (kind 8). Its OnSelected
  removes itself and selects the next fleet or air unit in its list (`FINDINGS-seaair.md` section 6), without
  `Selection_CanAdd`. A plain click therefore clears and then picks a fleet. **A Shift-click on a port or air base with
  units selected does nothing** (kind 4 or 8 against 0, 1 or 2). With nothing selected it behaves like a plain click.
- **A battle** (kind 7) opens its window. It can never join units.
- **A province** while units are selected: a plain click replaces them; a Shift-click does nothing. Provinces join only
  provinces (`FINDINGS-provinceview.md` A.1).

### A.5 The drag box

**What is drawn** - `CInGameIdler_DrawSelectionBox` (`0x64D950`, rva `0x24D950`), each frame while dragging:
- **five points at height 0**: (x1,z1) (x2,z1) (x2,z2) (x1,z2) (x1,z1), from `drag_start` and the ground point now
  under the pointer. It is **an outline on the ground, square to the map's axes**, not a screen rectangle: under a
  leaning camera it is a trapezoid on screen;
- drawn with the ID3DXLine at `+0x1CCC` (made by D3DXCreateLine in `CInGameIdler::Enter`): SetWidth(2.0), so **2
  pixels**; Begin; DrawTransform with the map's offset and the camera's view and projection; End;
- depth test and depth writes off;
- **white**: CColor(1, 1, 1, 1) x 1.1, clamped;
- no fill; it is neither the `Selection` mesh nor `selection_projection`. The latter is made per selected unit by
  CUnit::OnSelected, and only when `alwaysCounters` is off.

**At release:**
1. **Map mode 17** (*inferred* the theatre mode): the box assigns the player's controlled provinces whose label point is
   inside it (+-2) to the selected theatre. They are coloured as the drag goes and posted as a `CUpdateTheatreCommand`
   at release. No unit is selected.
2. **Alt (slot 11) held: nothing** - no clear, no selection. *Inferred* unreachable, A.1.
3. **The clear.** The old selection is cleared unless **Shift is held and unit rows exist** (`+0xD28 > 0`). The clear
   is the click's (A.4, steps 2 to 7), but it does not set `selection_changed` and never reopens the deploy menu. So
   Shift+drag adds to selected units, while Shift+drag over selected provinces clears them first.
4. **Three walks of the player's country's units** (`CCountry +0xBAC`, "the country's units at every level", in that
   list's order):
   1. **land units standing in a land province** (IsLand, and the province's path node `+0x22`);
   2. **fleets** (not land, not air), at sea or in port;
   3. **air units** (not land, not naval), in the air or at base.

   Each unit is taken where `Selection_CanAdd` allows it and its map position (slot 30, two ints, x and y) lies inside
   the box between the two ground points' x and z, **grown by 2 on every side**: `x + 2 >= min x`, `x - 2 <= max x`, the
   same for y against z, compared in double precision. A fleet in port stands at the naval base position and an air
   unit at its base at the air base position (`FINDINGS-seaair.md` section 6).
5. `last_group` = -1 per unit taken; `selection_changed` set per air unit.
6. Then `drag_armed` = 0, and outside mode 17 `CInGameIdler_LayoutUnitPanels` (`0x663400`, section B).

**The one-kind rule on the box.** `Selection_CanAdd` admits only the first selected thing's kind, and land is walked
first. So **a box over land and sea takes only the land units**, fleets only if no land unit qualifies, and air units
only if neither does. With Shift and an existing selection, its kind wins.

**What the box takes, and what it leaves:**
- **Takes:** HQs of every level together with their divisions (each is its own entry in the country list); units in a
  battle; units commanded by the AI (slot 2 asks ownership only); fleets in port; air units at base.
- **Leaves:** land units aboard ships (they stand in a sea province); foreign units; provinces, ports, buildings and
  battles. No province is ever box-selected.

**The province view** closes with the clear (Selection_Clear deselects every province). **The deploy menu** is closed
by the clear and stays closed.

### A.6 The right click with several selected

On a right release (`+0x14` = 2):
- **with nothing selected, no rows and the left button up**: the province right-click menu (`0x6754B0`, items
  `CRightClickBuildUnitsItem`, `CRightClickReloadItem`, `CRightClickCloseItem`; not read further);
- otherwise, **where `+0x1CE0` is clear and a province is under the pointer**:
  - an orders view that is up and shown gets its slot 4 (province, Shift), and nothing else happens
    (`FINDINGS-airorders.md` section 6);
  - **unless a visible interface element is under the mouse** (gui `+0x98`, `+0x43`), **every selected thing in
    selection order gets its slot 6 (province, Shift)**: `CUnit::OrderToProvince` for units, a `ret 8` stub for
    provinces, ports and buildings.

So each unit is ordered separately and plays its own move sound inside OrderToProvince (`FINDINGS-movement.md` section
1). Whether an already-playing sound restarts was not read.

**Several fleets, or several air units, without Shift.** The first unit's OrderToProvince opens the orders window for
itself (`CInGameIdler::OpenOrdersView`). For each later unit the window is already of that mode, so `OpenOrdersView`
returns at once (`0x677296` -> `0x677364`). **So a plain right click opens the window for the first selected unit only,
and moves no one.** With Shift every fleet is sent straight there, and every air unit is moved (`FINDINGS-seaair.md`
section 1).

A mixed selection cannot exist (A.3). A land selection with Ctrl opens the land orders window for the first unit in the
same way.

**The province tooltip with several selected** reads only the first selected thing: the head's `UTM_*` warning
(`0x497511`), the air or fleet distance line (`0x49CBC1`, `0x49CD83`) and `PROV_DISTANCE_FROM` (`0x49DB52`).
`FINDINGS-provincetooltip.md` sections 2 and 7 apply to it alone. Because `hovered` is the thing under the pointer,
**over a counter the map tooltip is the unit's own slot 3**, not ProvinceTooltip_Build.

`CInGameIdler::GetSelectedUnit` (slot 40, `0x676210`) answers the first selected thing if it is a fleet or an air unit,
whatever the count, and an army only when it is alone.

### A.7 The counters' rings with several selected

Each unit's `CUnit::OnSelected`, in the order the units join:
- gives its own two counters **ring 1, white**;
- runs `CUnit_SetRingBelow(3, ...)` over its subordinates (**ring 3, `color2`**), skipping any that is selected and not
  descending into it (`FINDINGS-hierarchy.md` section 6);
- adds its row (slot 34, section B);
- plays `army_selected`, `navy_selected` or `air_selected` (`interface/sound.sfx`) **unless that sound is already
  playing**, so a box of twenty plays it once (*inferred* from the "is playing" slot asked first).

So every selected unit is white and every unselected unit under any of them is `color2`, in either order of selection.
`CUnit::OnDeselected` sets its own rings to 0 and its subordinates' to 0 (those not selected). Taking one unit out with
Shift therefore **leaves it and everything under it ringless even when a selected unit above still covers them**. Ring
2 (`color1`, AI-commanded) comes from `CInGameIdler::ShowSelection` (slot 32), whose caller with several selected was
not found.

### A.8 Selection groups and the other keys

**'0' to '9'** go to `CInGameIdler_SelectionGroupKey` (`0x664A60`, rva `0x264A60`):

| keys | what happens |
| --- | --- |
| **Ctrl + digit** | where unit rows exist, the persistent id (`+0x10`, `+0x14`) of each row's unit, in row order, is posted as a **`CSelectionGroupCommand`** (player, ids, digit). Its Execute (slot 6) replaces the list at `CCurrentGameState +0xD40 + (country id x 10 + digit) x 0x10` - ten groups per country, kept in the game state, saved as `selectionGroups`, and the same on every peer. **With nothing selected, Ctrl+digit does nothing** and the group stays as it was |
| **digit, again** | where `last_group` is this digit, rows exist and the first selected thing is a unit: **CentreOnProvince on the first selected unit's province**, nothing else |
| **digit** | the click's clear, then each id of the group, in order: found, not selected, the player's own (slot 2), and the same kind as the first unit recalled -> `CSelectable_Select`. Dead or lost units are skipped. `last_group` = digit. An empty group leaves an empty selection |

`last_group` returns to -1 once anything else adds to the selection.

**The other keys in the handler:**
- **Escape** (key down): clears the selection, or else `0x66BD10(0)`;
- **Pause** (key down) or **Space** (character), outside multiplayer: slot 27 (*inferred* the pause);
- **'+' and '-'**: slots 25 and 26 (*inferred* the speed);
- **Home**: slot 47 with the player's capital;
- **0xA7 or '`'**: the console;
- **'h'**: the hierarchy (`FINDINGS-hierarchy.md`);
- **code 0x12** (Alt pressed, or Ctrl+R typed), with a theatre HQ selected alone: slot 110 (not read).

**There is no "select all"** and no other selection key in this handler.

### A.9 What looks wrong but is what the bytes do

- The drag threshold is 2.0 **map units**, so near the ground a drag needs a long move (about 65 px at the lowest
  camera) and from high up a tremor makes one.
- The box is a ground rectangle square to the map, between the two ground points, grown by 2 - not the screen
  rectangle.
- **Land beats sea beats air** in a mixed box; with Shift the old selection's kind wins.
- **Alt cancels the box, and Alt is (probably) never seen.**
- Shift keeps the old selection under a box only when units are selected; selected provinces are cleared first.
- The box takes HQs at every level, units in battle and AI-commanded units, but never land units aboard ships.
- A release over an interface window still completes a press made on the map.
- Clicking the lone selected unit's counter picks the next unit in the province; Shift on it adds the next one.
- **A plain right click with several fleets or air units opens the window for the first and orders nobody.**
- A right click with a visible interface element under the mouse does nothing.
- A Shift-click on a port, air base, battle, building or province while units are selected does nothing.
- Taking one unit out of a selection that holds its superior leaves it and its subordinates without a ring.
- The box's clear does not set `selection_changed` and never reopens the deploy menu; the click's does both.
- Ctrl+digit stores from the unit rows, not from the selection list, and with nothing selected leaves the group alone.
- Each frame clears the selection if it holds a thing of kind 9, which nothing has.

### A.10 Corrections

- **`FINDINGS-provinceview.md` A.1**, "clearing first unless a modifier (input slot 11) is held": slot 11 is Alt and
  **cancels** the box; Shift, with unit rows, is what keeps the selection.
- **`CInGameIdler +0x1DD4`** was `hovered_province`, "the province under the mouse". It is any selectable under the
  pointer; the map tooltip over a counter is the unit's.
- **`ProvinceGraphics_HitTest`**: all three exits are `ret 0x10`. Its signature is `(owner, provinceGraphics, mouse,
  selection)`, and its counter walk (the stack cycle) is now read. The "12" came from walking past `_CxxThrowException`
  into the next function.
- **`CCurrentGameState +0xD40`**: one 0x10-byte list per group, index = country id x 10 + group, so 0xA0 bytes a
  country.
- `FINDINGS-seaair.md` section 1's "a key held, not identified" for the land orders window is **Ctrl**.
  `FINDINGS-counters.md` section 7's "where the cycling is done was not read" is `ProvinceGraphics_HitTest`.

### A.11 Not settled

- **Whether Alt is ever seen.** A screenshot or a try: hold Alt through a drag. The bytes say the box should then still
  select.
- **CMap `0x492850`** is taken to be the screen-to-ground pick from its use; it was not read.
- **`map_units` / `map_unit_cursor`** (`+0x2C8`, `+0x2E8`): what fills the vector and in what order was read only from
  three writers. A try: select one division of a stack of three and click its counter twice; it should step through
  the others.
- **Land units aboard a transport plane**: they stand in a land province, so the box probably takes them (*inferred*).
- **Who calls `ShowSelection` (ring 2) with several selected.**
- **The cursor numbers' pictures**; slots 25, 26, 27, 47 and 110; the right-click menu `0x6754B0`; `+0x1CE0`.
- **`0x5CB630`**, called after the naval window opens (a landing arrow), was not read through.

Screenshots that would settle most of this: a drag box at the lowest camera; a box over a coast with an army and a
fleet in it (only the army should be selected); Shift+drag after selecting a province; Ctrl-click on an army HQ; Ctrl+1,
then 1, then 1 again.

**Frontier** (rvas): `0x92850` (CMap screen-to-ground), `0x2754B0` (the right-click menu), `0x266680` (slot 110),
`0x24C020` (slot 47, Home), `0x1CB630`, `0x6800D0` (which key downs are queued), `0x4558F0` (the province under the
pointer), `0x1D2A00` (the theatre of the selected unit, mode 17), ~~`0x34DB5B` and `0x3572C8` (the other callers of
`CUnit::SelectSubordinates`)~~ (read, A.12), `0xB88C0` (`CProvinceBuilding::OnSelected`, read only as far as the
picture highlight).

**Record**: `fragments/merged/selection-input.json` - 21 addresses, 14 fields, 3 vftable slots, with
`CInGameIdler_HandleInput` revised to `confirmed` and read whole, `ProvinceGraphics_HitTest` given its signature,
`CInGameIdler +0x1DD4` renamed `hovered` and `CCurrentGameState +0xD40`'s comment corrected.

### A.12 The children ribbon and Ctrl on the panel's rows

*Read 2026-10-16 on the listing, after the maintainer's screenshot of the single panel's children ribbon ("1 Army
group(s), 4 Corps") with his word: "In the original clicking the ribbon will select all subordinate units."*

**`CUnit::SelectSubordinates`** (`0x5D36A0`, rva `0x1D36A0`, bare `ret`), read whole: for each unit in the list at
`+0x1E4` (node `+0`, next `+8`), in that list's order, whose IsLand (slot 15) equals this unit's - the unit is selected
through `CInGameIdler::Select` (slot 38, `call [eax+0x98]` at `0x5D37A0`) where its selected byte `+4` is clear, and
**then `SelectSubordinates` runs on it** (`0x5D37A4`) before the walk takes the next node (`0x5D37A9`). So it is a
depth-first walk, each unit followed by its whole command and then its next sibling; an already selected unit is not
selected again but its command still is. Nothing is cleared, and slot 38 asks no kind. A child of the other IsLand is
skipped with all under it.

Its callers - four direct calls by `findRefs --callers` (`0x5D37A4` itself, `0x65344A`, `0x74DB5B`, `0x7572C8`) and a
tail jump:

| where | when | what is selected |
| --- | --- | --- |
| `CInGameIdler_HandleInput`, `0x65344A` | a Ctrl-click on an army, once it is selected (A.4, step 9) | the army and its whole command |
| **`CWindowForChildUnitsEntry::OnSelectAllChildUnits`** (`0x7558D0`, rva `0x3558D0`: `mov ecx,[ecx+0x28]; jmp 0x5D36A0`) | **a click on the children ribbon, `select_all_childunits`** - the glue at `+0x30` the constructor (`0x755760`) registers on it, enabled for a land unit only (`FINDINGS-unitpanel.md` section 8) | **the panel's unit stays selected and every land unit under it joins**: nothing is cleared, so the multi-unit panel comes up |
| `CParentUnitEntry::SelectUnit` (`0x74D8A0`), `0x74DB5B` | a click on a parent's, a subordinate's or a passenger's row **with Ctrl** - "a setting of the screen" in `FINDINGS-unitpanel.md` section 3 is the screen's keyboard `+0x1C`, slot 12 (`0x74DB38`..`0x74DB46`) - and the row's unit a land unit | the row's unit alone (the selection queued for deselection, slot 43 with null; the unit selected, slot 44), then its whole command |
| `CCombatEntry::OnClick` (`0x757020`), `0x7572C8` | a click on the panel's battle row **with Ctrl** (`0x7572A3`..`0x7572B5`) and the panel's unit (`+0x2C`) a land unit | the battle, which opens its window, **and** the unit's land units under it - but not the unit itself; no kind test stops the mix |

`CParentUnitEntry::SelectUnit` is slot 4 of three tables - `CParentUnitEntry`, `CChildUnitEntry` and
`CLoadedUnitEntry` - so a passenger's row in a fleet's list takes the same click.

**What looks wrong but is what the bytes do**: the ribbon adds and never replaces - clicked with several selected, it
adds the panel unit's command to them, though the single panel is up only with one; a Ctrl-click on a battle row
leaves a battle and land units selected together, the battle first, and the unit whose panel it was out of it.

**Record**: `fragments/merged/select-all-childunits.json` - 4 addresses: `CWindowForChildUnitsEntry::OnSelectAllChildUnits`
new; `CParentUnitEntry::SelectUnit`, `CCombatEntry::OnClick` and `CUnit::SelectSubordinates` revised (Ctrl named, the
battle row's Ctrl arm, the callers and the walk's order); slot 4 of four tables.

## B. Several selected: the multi-unit panel

*Read 2026-10-16 for OpenHOI3, on the listing, with a decompilation of a copy with the record applied as a guide.
Addresses are VAs, with rvas beside named functions. Texts are Their Finest Hour's English. Every line is `confirmed`
unless it says otherwise. Nothing here was watched in a running game.*

**In short.** Each selected unit gets a row, which is the single panel's header window `unitpanel` (a `CUnitView`),
kept in selection order.

- **One row:** the single unit panel is shown and the rows are not.
- **Two or more:** `multi_unitpanel` is shown at (0, 96). The rows are stacked from (0, 144), 40 pixels apart, as many
  as the screen holds. A scrollbar appears to their left when there are more than that.
- **What a row offers:** "deselect" and "select this". The latter keeps only that unit; with Ctrl it keeps the unit
  and everything under it; with Shift it marks rows to keep when Shift is released.
- **What the panel offers:**
  - three checkboxes, ticked if any selected unit has the flag; clicking one brings every unit to the box's new state;
  - upgrade-all;
  - detach, create higher command, reorganise, merge and disband, each gated as below;
  - close, which clears the selection.

### B.1 When the panel shows, where, and its rows

**A row per selected unit.**
- `CUnit::OnSelected` (slot 4) calls the screen's slot 34, `CInGameIdler::AddUnitRow` (`0x6639E0`, rva `0x2639E0`), at
  `0x5C08A5`.
- `CUnit::OnDeselected` (slot 5) calls slot 35, `CInGameIdler::RemoveUnitRow` (`0x664210`, rva `0x264210`), at
  `0x5C0BC1`.
- Both calls are skipped where the global byte `0x1A855F6` is set. It has four readers, all in these CUnit slots, and
  **no writer in `.text`**, so it is zero in a normal game (`inferred`).
- No province, port or battle gets a row: only CUnit's slots call 34 and 35.

**AddUnitRow**, in order:
1. The orders view is closed.
2. **The chat list (`chat_list`, menubar.gui, home (5, 120)) is moved to x 350**, keeping its y. It goes back to its
   home only when the last row goes.
3. A `CUnitView(unit, screen, inPanel 0, the kept-rows list)` is made and **appended** to the row list (`+0xD20`, count
   `+0xD28`). So **rows are in the order the units were selected**.
4. The panels are laid out (below), except while a box drag is in progress (`0x64D850`, section A).
5. **When the count becomes 2:** `multi_unitpanel` is shown, `upgrades_window` closed, `multiunit_slider` hidden, and
   the window at `+0x1360` put away (`0x7395E0`). That window was not identified; it answers `theatre_forces_button`.
6. **When the count is 1:** the single unit panel (`+0x135C`) is given the unit and rebuilt.
7. The reorganise window is closed if it is up.
8. **`desc`** is set to the row count, a space, and one of `ARMIES` "Land Units", `NAVIES` "Naval Units" or `AIRWINGS`
   "Air Units". The choice is by **the first row's** unit (land, else naval, else air). Example: "3 Land Units". With
   one row the text is set but the panel is hidden.
9. With one row, every row's window is hidden.

Nothing tests whether the unit already has a row.

**RemoveUnitRow**, in order:
1. The orders view is closed.
2. The unit's row is unlinked and destroyed. While `+0xD2C` is set, its node is only marked.
3. The panels are laid out, except while the whole selection is being cleared (`+0x1CC8`).
4. **Fewer than 2 rows:** `multi_unitpanel` hidden and `upgrades_window` closed.
5. **Exactly 1:** the single panel takes the remaining row's unit and is rebuilt, and the row windows are hidden.
6. **0, or 2 and more:** the single panel is hidden and `ShowSelection(null)` (slot 32) clears what the last selection
   drew.
7. The reorganise window is closed if it is up.
8. With rows left, `desc` is rebuilt; with none, the chat list goes home.

**The single panel is never up with two selected.** `CInGameIdler::Update` calls `CSingleUnitPanel_Hide` (`0x763050`,
rva `0x363050`) **every frame where the row count is not 1** (`0x65644F`). Its battle rows, children, brigades and
buttons are therefore absent with several selected.

**Where things go.** `multi_unitpanel` keeps its file position, **(0, 96), 410 x 48**. Nothing in the image moves it: a
scan for `+0x1368` finds lookups and show/hide only. `CInGameIdler_LayoutUnitRows` (`0x6636A0`, rva `0x2636A0`) places
the rows:

    fit   = (screen height - unitlist_start.y) / unitlist_offset.y - 1      (+0x1DF8, once at Enter)
          = (1080 - 144) / 40 - 1 = 22 at 1080 lines
    x0    = width of the open side menu, if any
          + the +0x1360 window's two parts' widths, where it is up        (inferred: "width", see below)
    if rows > fit:
        x0 += unitlist_offset.x (16)
        multiunit_slider: height unitlist_offset.y * fit, at (unitlist_start.x, unitlist_start.y - 96)
                          inside the panel (so (0, 144) on screen), shown
        first = trunc( (rows - fit) * value / (maxValue) )   single precision; maxValue 100
    else:
        slider hidden, first = 0
    for row i in list order (with 2 rows or more):
        i < first or i >= first + fit   -> its window hidden
        otherwise                        -> at (unitlist_start.x + x0, unitlist_start.y + k * 40), shown,
                                            updated (CUnitView::Update), k the count shown so far

`unitlist_start` is (0, 144) and `unitlist_offset` is (16, 40) in Their Finest Hour (the base game's start is (0,
120)). A row's window is `unitpanel`, 400 x 40, so the rows touch.

**Refresh.** `CInGameIdler_UpdateOpenView` (`0x651D30`, rva `0x251D30`) runs from Update every frame. **While no
country view is open** it calls LayoutUnitRows, so the rows are placed, shown and updated every frame. A row's update
runs only while its window is shown, and draws everything from the unit each frame. **While a country view is open**
the rows are not re-laid; they keep their last place and last update.

**Scrolling.**
- **The wheel:** `CInGameIdler_ScrollUnitRows` (`0x6634F0`, rva `0x2634F0`) handles it over the area from the panel's
  top to `panel bottom + 40 * fit`, within the panel's width, while the slider is shown. It sets `value -= wheel * (max
  / 1000) / (rows - fit)`, held to the slider's range, so **one wheel unit is one row**. The wheel figure is the input
  object's slot 21; that event kind 4 is the wheel is `inferred`.
- **The arrows:** the slider's own buttons step its value by `stepSize = 1` out of `maxValue = 100`. With first =
  trunc((rows - fit) * value / 100), **an arrow press moves less than a row when rows - fit < 100**, and nothing
  visibly until the product crosses a whole number. This rests on the file's figures and the reading, not on a run.

### B.2 A row

**What it shows** is `FINDINGS-unitpanel.md` section 4: the header row with `inPanel` clear. The only difference is
that **`unitname` cannot be typed in** (its byte `+0x159`). A row's tooltips are the header's
(`FINDINGS-unitpaneltooltips.md` section 3). `GetElementTooltip` asks the row list first (`0x6C5336`), and the last row
that owns the element answers through its slot 13.

**There is no click on the row itself.** The rows are free windows the screen positions, not list-box items, so
`CUnitView`'s "entry was clicked" slot is never reached. The constructor (`0x769940`) builds four button glues and
registers three of them:
- `remove_unit_from_selection_button` (glue `+0x88`) -> `CUnitView::OnRemoveFromSelection` (`0x76DD70`, rva
  `0x36DD70`).
- `only_unit_from_selection_button` (glue `+0xD8`) -> `CUnitView::OnSelectOnlyThis` (`0x76DE30`, rva `0x36DE30`).
- `leader_button` and `leader_photo` (glue `+0x128`) -> `CUnitView::OnLeaderButton`. This opens the leader window for
  **that row's** unit (`FINDINGS-leaderwindow.md` section 1), with the header's disabling rules.
- The fourth glue (`+0x38`, `CUnitView::SelectCarried`, `0x76DC00`: "select this fleet's passengers") is registered on
  nothing (`inferred`, by the constructor).

Each button's glue has only an ordinary-click handler; the other event slots are null. So a right click on either
button does nothing.

**Remove** (`DESELECT_UNIT` "Deselect Current Unit", delayed `DESELECT_UNIT_DRO` "This button will close the current
unit window"). The row's unit is queued with `DeselectLater` (slot 43). No key is asked. **The deselection happens at
the end of the same frame's panel pass** (B.6).

**Select this** (`OSELECT_UNIT` "Select this", delayed `OSELECT_UNIT_DRO` "If you have multiple units selected, this
option makes it possible to select just that unit."):
- **Plain click:** every selected thing but this unit is queued for deselection. The result is this unit alone.
- **With Ctrl** (input slot 12; Ctrl is `likely`, per `FINDINGS-scrollbar.md`): the unit and **every unit under it at
  any depth** (`CUnit::CollectSubtree`) are kept, every other selected thing is queued for deselection, and each of the
  kept units not yet selected is selected at once (slot 38). So Ctrl-click selects a headquarters' whole command.
- **With Shift** (input slot 10): the row is **toggled on the kept-rows list** (`+0x1DE4`), and nothing else happens
  yet. Every frame, a kept row shows its "Select this" button **shifted 15 pixels right** (CUnitView::Update,
  `+0x180`).
- **When Shift is released:** `CInGameIdler_UpdatePanels` sees the list holding rows with Shift no longer held. It
  collects their units, clears the selection, and selects each unit that may be selected (its slot 2), **keeping only
  those of the first kept unit's kind**. It then empties the list.

So Shift picks several rows and the release keeps exactly those. The order of the new selection is the order the rows
were Shift-clicked.

### B.3 The checkboxes, upgrade-all, close

The positions and sprites are from the file. The shortcut keys are the file's `shortcut` entries.

| element | where | shortcut |
| --- | --- | --- |
| `desc` | (10, 4), Arial14_black, max 300 x 32 | |
| `upgrade_all` | (175, 1), `GFX_upgrade_unit` | |
| `prio_checkbox` | (205, -4), `GFX_checkbox_prio` | n |
| `reinf_checkbox` | (230, -4), `GFX_checkbox_reinforce` | i |
| `upgrade_checkbox` | (255, -4), `GFX_checkbox_upgrade` | u |
| `close_multiunit` | (290, 2), `GFX_close_multiunit` | |
| `detach_multiunit` | (1, 24) | |
| `highercomm_multiunit` | (53, 24) | |
| `unmount_multiunit`, `load_on_air_multiunit`, `load_multiunit` | (127/160/193, 26) | (C.3) |
| `reorganizebutton` | (235, 26), `GFX_unit_reorg_button2` | r |
| `mergebutton` | (260, 26), `GFX_unit_merge_button` | g |
| `disband_multiunit` | (299, 26) | |
| `multiunit_slider` | (0, 48), 16 wide | |
| `upgrades_window` | (0, 0), 254 x 240, a list box `list` | |

The base game's file has only load, reorganise, merge and close, at y 2, in a 400 x 100 window.

**The three checkboxes.** These rules run every frame in `CInGameIdler_UpdatePanels` while there are two rows or more.

- **Enabled** unless the custom-game lock (`0x4208B0`) is on. Under the lock they, `upgrade_all` and
  `disband_multiunit` are disabled, and `upgrades_window` is closed.
- **State:** each box is **ticked where at least one selected unit has its flag**, and cleared otherwise. The flags are
  `upgrade_prio` +0xA4, `reinforcements_active` +0xA6 and `upgrade_active` +0xA5
  (`CInGameIdler::CountSelectedUnitFlags`, `0x669D50`). **There is no partial state**: three units with one
  prioritised show a ticked box. The one exception is a cleared box left alone where its byte `+0xD8` is set while it
  is disabled (not identified).
- **Click:** ticking a box calls `CInGameIdler_SetSelectionPriority(on = true)` (or its reinforce and upgrade twins).
  Clearing it calls the same with false. For every selected unit **whose flag differs from the new state**, one
  `CTogglePrioritizeCommand(unit)` (or `CToggleReinforceCommand`, `CToggleUpgradeCommand`) is posted. Each command's
  Execute **flips** the flag, so every unit ends in the box's state. Ticking a box that showed ticked because one unit
  had the flag first clears it (the click), which sends every unit with the flag to off.
- **Tooltips** (only while the panel is shown); NUM = the units with the flag, MAX = the selected units:
  - `prio_checkbox`: `MULTI_SEL_PRIO_DESC` "§G$NUM$§! out of §G$MAX$§! selected units have priority for upgrades and
    reinforcements §YENABLED§!."
  - `reinf_checkbox`: `MULTI_SEL_PRIO_REINF_DESC` "§G$NUM$§! out of §G$MAX$§! selected units will receive
    reinforcements §YENABLED§!."
  - `upgrade_checkbox`: `MULTI_SEL_PRIO_UPG_DESC` "§G$NUM$§! out of §G$MAX$§! selected units will receive upgrades
    §YENABLED§!."
  - No delayed half on any of them.

**`upgrade_all`.**
- **Enabled** as the checkboxes are.
- **Tooltip** (while shown): `MULTI_SEL_UPGRADE_DESC` "§G$NUM$§! brigades in current selection can be upgraded.", with
  NUM from `CInGameIdler_CountUpgradeableBrigades` (`0x66AFE0`). That routine walks every selected unit's every brigade
  that `CSubUnit_MayUpgradeWhereItStands` passes (`inferred`), which requires:
  - the unit in no battle, not retreating and not on loan;
  - a fleet only where a naval base is built, an air unit only where an air base is built;
  - the province in the same area as the owner's acting capital.

  It looks at the brigade type's upgrade targets (`CSubUnitDataBase +0xB0`, by inference `common/unit_upgrades.txt`,
  closed transitively as that file's comment says). A brigade counts once if **any** target has
  `CCountry::CountMaxUnitsStillBuildable >= 1` for the player.
- **Click** (`CInGameIdler::OnUpgradeAll`, `inferred` in part):
  - with `upgrades_window` up, it closes (frame 1); the button toggles;
  - with nothing upgradeable, it closes;
  - otherwise the list gets one row (`select_upgrade_entry`, button `target`) per target type in the order found, its
    text the type's name, then a last row `UPGRADE_CANCEL` "Cancel". The window is shown and `upgrade_all` goes to
    frame 2.
- **A row's click:** for a type, `CInGameIdler_UpgradeSelectionTo` posts **one `CUpgradeRegimentCommand(brigade,
  type)` per brigade of the selection** that passes the same test and lists that type, provided the player may still
  build it. The window closes either way.

**`close_multiunit`** is `CInGameIdler::ClearSelection` (slot 46), through the thunk `0x67A2F0`. **It has no tooltip.**
Search: the string `close_multiunit` (`0x15CE470`) has one code reference, the registration at `0x65F18E`. Positive
control: the same search finds `disband_multiunit`'s four, among them the tooltip at `0x6C70F5`.

### B.4 The command buttons

**`detach_multiunit`.**
- **Enabled** where any selected unit has `oob_level > 0` (anything but a theatre) and the lock is off
  (`CInGameIdler_CollectDetachable`, `0x669DE0`). **There is no test that a unit has a commander.**
- **Tooltip:** `DETACH_ALL` "Detach all selected units from the unit hierarchy.\nTheatres are ignored."
- **Click:** one **`CDetachUnitCommand(unit)`** per such unit, in selection order. The selection is kept. Execute calls
  `CUnit_LeaveParent(unit, true)` and, for the player's unit, raises the `DETACHEDUNIT` message (`inferred`).

**`highercomm_multiunit`.**
- **Enabled** where the lock is off, a custom game's second test (`0x420EB0`) allows it, and
  `CInGameIdler_CollectForHigherCommand` (`0x669EB0`) answers non-zero. That routine needs selected units with
  `oob_level > 0`. Of these, the highest-ranked (lowest level, first of equals in selection order) is taken. Where it
  has a commander and a grand-commander, and `CUnit_MayTakeSubordinate(grand-commander, it, 1)` says no, the answer is
  0. By inference this means "the new headquarters would have no room above".
- **Tooltip:** `HIGHER_COMMAND_MULTI_UNITS` "Create a §Ghigher command§!, and attach all selected units to it (except
  theatres)." In a custom game it also has a delayed half from `0x4210E0` (not read).
- **Click:**

        n      = the number of units collected
        needed = (int)floorf(((float)n + 0.0005) * 1000) * hq_brigade.build_cost_manpower / 1000
        owner of the first collected unit has Manpower < needed      -> nothing
        else ClearSelection, one CCreateHigherCommand(the collected units)

  **The manpower needed is n headquarters' worth, though one is made.** There is no message or sound here.

**`reorganizebutton`.**
- **Enabled.** UpdatePanels enables it every frame where exactly two things are selected. UpdateOpenView, later in the
  same frame and while no country view is open, sets it again: enabled where there are **exactly two rows and
  `UnitList_MayReorganise`** (`0x4E0A30`) passes. That rule requires:
  - each unit in no battle, not retreating, not moving, not on loan, with no attack delay;
  - each in the first's province;
  - **no AI agent on it or on any unit above it**;
  - the same "all carrier air groups" as the first;
  - for air units, the same base;
  - and **not exactly two brigades between them** (two one-brigade units cannot be reorganised).

  There is no level test, so a corps and a division qualify.
- **Tooltip:** `REORGANISE_UNITS` "Reorganise these two units" where fewer than 3 are selected, `NO_REORGANISE_UNITS`
  "You can only reorganise when 2 units are selected." where 3 or more are. Always delayed `REORGANISE_UNITS_DRO`
  "Reorganising these two units will allow you move subunits between the two units".
- **Click** (`CInGameIdler::OnReorganiseButton`, slot 49's body): with exactly two selected, the reorganise window gets
  the first and second units **in selection order** and opens. The window itself is not read here.

**`mergebutton`.**
- **Enabled** while no country view is open, by `UnitList_MayMerge(the rows' units, the player's country)`
  (`0x4E08E0`). That rule requires at least two units, and each of them:
  - in no battle, not retreating, no path, in the first's province, not on loan, no attack delay;
  - **the first's `oob_level`, and that level 4 or more** (divisions; fleets are 5, so by the record's level list
    fleets and presumably air units qualify);
  - "all carrier air groups" as the first, and for air units the first's base;
  - for land units, **the brigades of all of them together at most `CCountry_GetMaxBrigadesInDivision`**.

  False -> disabled. True -> enabled where **no unit, nor any unit above one, has an AI agent**, and **left as it was**
  where one has.
- **Tooltip:** `MERGE_UNITS` "Merge the selected units", delayed `MERGE_UNITS_DRO` "Choosing the merge option will take
  the current selected units and convert them into a single unit."
- **Click:** an AI agent anywhere in the chain of any selected unit -> **nothing**. Otherwise **one `CMergeCommand(all
  selected units)`** and the `click` sound. In Execute (`inferred`), the unit merged into is the one with the highest
  `brigades x 10 + strength share (0..10) + leader skill x 2` (first of equals); the others are merged into it and
  removed. If it has no leader and the country auto-assigns leaders, the best one is assigned.

**`disband_multiunit`.**
- **Enabled** as the checkboxes are.
- **Tooltip:** `DISBAND_ALL_TITLE` "Disband all units", with no delayed half.
- **Click:** opens `CConfirmDisbandAll` (window `DefaultConfirm`, centred). Its title is `DISBAND_ALL_TITLE`; its
  description is `DISBAND_ALL_DESC` "Are you sure that you want to §RDISBAND§! §Y$NUM$§! units?", with NUM the
  selection count when opened. **The dialog closes itself if the selection count changes** (its slot 7).
- **Confirm** (`CInGameIdler_DisbandSelection`):
  - every selected unit is disbanded except:
    - a land unit aboard a fleet or plane;
    - a theatre whose theatre holds provinces;
    - a unit with an AI agent **of its own** (not one above);
    - a unit on loan;
  - then the selection is cleared and **one `CDisbandCommand(unit)` per unit** is posted.

  Execute (`inferred`) raises the `DISBAND` message for the player's units and refunds `strength share x
  build_cost_manpower` in manpower. A unit disbanded at sea has its leader taken off the active list. Execute then
  removes the unit.

### B.5 Other windows with several selected

- **Orders window:** cited, not re-read. A naval Accept posts a `CSetOrderCommand` **for every naval unit selected**,
  and a row is greyed where **any** selected unit cannot take it (`FINDINGS-seaair.md` section 2). An air Accept does
  the same for every air unit **except one changing base** (`FINDINGS-airorders.md` section 10). The window's range
  factor reads the view's unit's (`FINDINGS-airorders.md`, not settled there). Which right click opens it with several
  is section A's.
- **Hierarchy lines:** drawn for **the first selected land unit only** (`FINDINGS-hierarchy.md`).
- **Leader button:** on every row, opening the leader window for that row's unit.
- **Battle rows:** none. They belong to the single panel, which is hidden whenever the row count is not 1.

### B.6 What changes the list

- **Deselection of any kind** (a click, Escape, a box, a row's buttons, ClearSelection) removes the row through
  `OnDeselected` -> slot 35.
- **Deselections queued by a row's buttons** (slot 43, `+0xA90`) are carried out at **the end of
  `CInGameIdler_UpdatePanels` in the same frame**, for each queued thing still selected (slot 45).
- **A unit that ceases to exist** (destroyed, disbanded, merged away, no retreat): `CGameState::RemoveUnit` deselects it
  at once (slot 45), after first deselecting each selected unit a dying fleet carries (`0x684FB8`, `0x684FD6`).
- **A land unit that goes aboard** stays selected with its row. Search: `CNavy::AddCarried` (`0x5CF040`..`0x5CF283`)
  and `CUnit_MergeInto` contain no call through the screen's slots 43 or 45 and no call to RemoveUnit. Positive
  control: the same search finds RemoveUnit's two slot-45 calls.
- **A unit changing owner:** not looked for.

### B.7 Corrections to the record

- `FINDINGS-unitpanel.md` section 4: `0x76DD70` is `remove_unit_from_selection_button`'s handler and `0x76DE30` is
  `only_unit_from_selection_button`'s. `0x76DC00` (glue `+0x38`) is bound to nothing. Slot 43 with a null is **not**
  "clear the selection" but "queue every selected thing for deselection at the end of the panel pass".
- `CInGameIdler_UpdatePanels`: the "selection waiting at +0x1DE4" is the Shift-kept rows, applied only once Shift is
  up. "The first one's kind" is the first kept unit's.
- `CSubUnitDataBase +0xB0`: not an unused list. It is the per-type array of upgrade targets.

### B.8 What looks wrong but is what the bytes do

- Create-higher-command needs **n x the HQ brigade's manpower** for n units, though one headquarters is made.
- The checkboxes have no "mixed" state. One unit with the flag shows the box ticked, so clicking it turns the flag
  **off** for everyone.
- Detach is enabled with any non-theatre unit selected, **whether or not anything is above it**, and posts a command for
  each.
- Merge refuses at the click, silently, where any unit or any commander above one has an AI agent. The enable rule only
  skips enabling in that case, so the button can stay enabled from an earlier frame.
- Disband skips a unit with an AI agent of its own, but not one under an AI commander. Merge and reorganise check the
  whole chain.
- Reorganise refuses two units of one brigade each but has no level test. Merge demands the same level, 4 or more.
- `multi_unitpanel` never moves, but the rows move right by the side menu's (and the `+0x1360` window's) width.
- The slider's arrows step 1 out of 100, so with fewer than 100 rows beyond what fits a press often moves nothing; the
  wheel moves one row exactly.
- A row's "select this" with Shift does nothing visible but a 15-pixel shift of the button, until Shift is released.
- Disband's dialog closes if the selection count changes, but not if the selection changes at the same count.
- `CUnitView::SelectCarried` (select a fleet's passengers) exists, with a glue built for it, and no element is given
  that glue.

### B.9 Not settled

- **The side-menu offset.** By its use in the wheel routine, the side menu's slot 24 is a size. A screenshot with a side
  menu open and several units selected would show whether the rows shift right and the panel does not.
- **The slider's size call** `0xA9EDB0(-1, 40 * fit)`: whether -1 means "keep the width" was not read.
- **What `+0x1360` is** (answers `theatre_forces_button`) and what `0x7395E0` does beyond hiding three of its children.
- **Unidentified fields and globals:** checkbox `+0xD8` (it also stops a ticked box being cleared by a click) and
  `+0x100`; `CInGameIdler +0xD2C` writers; `0x1A855F6`, which has no writer in `.text`.
- **Other unread pieces:** what each row's `+0x1C` slot 12 does in DisbandSelection before the selection is cleared;
  the reorganise window (`0x764960` fill, `0x7646D0` its keep-open test); the custom-game tests `0x4208B0` and
  `0x420EB0`, and highercomm's custom-game delayed text (`0x4210E0`).
- **Air units' `oob_level`:** whether it is 5 as for fleets, and so whether air units can merge, rests on the record's
  "5 navy" only. A save with two selected air groups would settle it.
- **Where `upgrades_window` is placed** when opened was not read; the file gives (0, 0) within the panel.
- **The Execute bodies of merge, disband and detach** were read from the decompilation only. The merge score's terms
  want a listing check.

**Frontier** (rvas): `0x3646D0` (reorganise window keep-open), `0x364960` (its fill), `0x364B90` (its close),
`0x2652D0` (side menu open?), `0x29EDB0` (scrollbar size), `0x2A0000` (scrollbar set value), `0x339C30`, `0x3395E0` (the
`+0x1360` window), `0x1DE1D0`, `0x1DF430`, `0x1DA710` (the three command constructors), `0x2208B0`, `0x220EB0`
(custom-game locks).

**Record**: `fragments/merged/selection-panel.json` - 53 addresses, 3 structs declared, 26 struct fields, with
`CInGameIdler_UpdatePanels` and `CInGameIdler_UpdateOpenView` revised to `confirmed` and `CSubUnitDataBase +0xB0`
revised from `unused_list` to `upgrade_targets`.
