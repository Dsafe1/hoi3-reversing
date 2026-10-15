# The province view

The window a selected province opens (`province_view`, `tfh/interface/province_interface.gui`; the class
`CProvinceView`), read for OpenHOI3 in the province-view wave of 2026-10-15 (`WAVE.md`). Three readers: **A** the
window, its opening and its refresh; **B** the building columns and the `underground` sub-window; **C** covert
operations and allied cooperation. Addresses are VAs, with rvas beside named functions; texts are Their Finest Hour's
English.

Earlier readings this extends: `FINDINGS-occupation.md` B.6 (the revolt-risk figure) and E.7 (the `underground`
window), `FINDINGS-buildingqueue.md` A.2 (`CBuildingMember::OnClick`), `FINDINGS-uinumbers.md`
(`BuildProvinceViewTooltip`'s number block), `FINDINGS-espionage.md` B.7 (covert operations).

## A. The window, opening and refresh

*Read 2026-10-15 on the listing and checked against the decompilation of a copy with the record applied.*

**In short.** Nothing opens or closes the view directly: it **follows the selection**. Selecting a province tells the
in-game screen through a listener every province carries; deselecting asks the screen to show the first province still
selected, or to hide the view; `close_button` clears the selection. The refresh runs only when the view is shown on a
province (and on a GUI reload); the weather strip, the building rows, the underground window and `cov_ops_points` are
redone every frame. So the name, flags, terrain, figures, the `adj` list and the `claims` box go stale when the province
changes hands, until it is selected again.

### A.1 When the view opens and closes

**There is no "open" call.** The view shows exactly while one or more provinces are selected: the most recently added
province, or after a removal the first one still selected.

- **The listener.** `CMap_SetSelectionListener` (`0x4920B0`, rva `0x920B0`) writes a listener into `CMap +0x2A68` and
  every province's `+0xCC`. `CInGameIdler`'s constructor calls it with the in-game screen; so do
  `CEU3Application::MakeBackEndIdler`, `CFrontEnd::CFrontEnd` and an unidentified screen at `0x69D703`, each with itself.
- **Selecting.** `CSelectable_Select` calls the province's `OnSelected`, slot 4 of its second table (`0x49E240`, rva
  `0x9E240`): a land province with a listener gets the listener's slot 11, `CInGameIdler::ShowProvinceView`
  (`0x6632E0`); **a sea zone, or a province with no listener, runs `CInGameIdler::ClearSelection` instead**, which takes
  the sea zone out of the selection too; either way it then plays `click` and queues the province for repaint.
- **ShowProvinceView** does nothing for a null province, id 0, or where the template's `simulated` byte (`+0x13D`) is
  clear; otherwise `CInGameIdler_OpenProvinceView` (`0x673630`), in order: shows the window (`CFixedWindow`'s Show
  re-shows every child button and text box); hides again the occupier flag if one is held hidden (`+0x28`); runs
  `CProvinceView::Refresh`; hides the icon `bg_main_menus` (`menubar.gui`); sets in-game-screen byte `+0x1D3D` = 1.
- **Deselecting.** `OnDeselected`, slot 5 (`0x49E4F0`), calls the listener's slot 13,
  `RefreshProvinceViewFromSelection` (`0x663280`): with an empty selection `HideProvinceView` (`0x663310`), which hides the
  window and `cgm_underground_build` (called twice, harmlessly); otherwise the first selected thing, in selection order,
  whose kind is 3 (a province) gets `ShowProvinceView`.
- **`Selection_Clear`** (`0x4AD6F0`) detaches the whole list before telling each item, so every `OnDeselected` already
  sees an empty selection.

**The click** - the left button released over the map with no drag, in `CInGameIdler_HandleInput` (`0x652540`):

- **While a deployment is being placed**, the click goes to that first: where `CanDeployIn` holds, the deploy command is
  posted and nothing is selected; otherwise it goes on as an ordinary click (recorded).
- **A plain click** (input slot 10 not held): closes the side menus and the orders view; clears the selection; closes an
  open country view by toggling it; selects what is under the pointer (`hovered`, from `0x6416D0`, not read) where
  `Selection_CanAdd` (`0x4AD6B0`) allows. So clicking a land province opens or moves the view; clicking a unit clears the
  province selection, which closes the view, and selects the unit; clicking a sea zone closes the view. There is no test
  of what was selected before and no map-mode test on this path. The deploy menu, if it was open, is reopened when the
  click leaves exactly one thing selected (*inferred* from the reopen calls).
- **Shift-click** (input slot 10; Shift by the scrollbar reading, same slot, a different object): on something already
  selected, `Selection_Remove` (`0x4AD680`) - the view moves to the first province left, or closes; otherwise it is added
  without clearing, where `Selection_CanAdd` allows. **`Selection_CanAdd` admits only the kind of the first selected
  thing** (0 army, 1 fleet, 2 air, 3 province): provinces join only provinces, and shift-clicking a province while units
  are selected does nothing. **Shift-clicking a sea zone while provinces are selected clears everything**, through
  `OnSelected`.
- **A drag box** selects only the player's own units inside it - land units over land, fleets, air units - clearing first
  unless a modifier (input slot 11) is held. **No province is ever box-selected.**
- **Escape** with anything selected runs `ClearSelection`, so it closes the view.
- **`close_button`**, in the view and in `underground`, is `CProvinceView::OnClose` (`0x6DE340`) =
  `CInGameIdler::ClearSelection` (slot 46).
- **A country view opening does not touch the province view**: `CInGameIdler::OpenCountryView` does not read `+0x1CC0`;
  it only hides `bg_main_menus` too.

### A.2 `CProvinceView`

RTTI `CProvinceView`, base `CReloadableInterface` at 0, vftable `0x15D3E00`, two slots: 0 `Rebuild` (`0x6E35C0`), 1 the
deleting destructor (`0x6DDBD0`). 0x1A4 bytes, made once in `CInGameIdler::Enter` (`new 0x1A4`, constructor
`0x6DD8D0`), kept at in-game-screen `+0x1CC0`, then hidden; in-game-screen slot 82 answers it.

The observer glue is `VCProvinceView::__CButtonObserverGlue` (vftable `0x15D3E0C`, 0x2C bytes): +8 slot 2 the plain
click; +0x20 slot 1 a press, handed the button (a left press, *inferred* - the tutorial menu's six buttons use it the
same way); +0x24 slot 9 the right click.

| offset | field | holds |
| --- | --- | --- |
| +0x20 | window | the `province_view` window |
| +0x24 | province | the province shown |
| +0x28 | hidden_occupier_flag | `occupier_flag` while hidden, else 0 |
| +0x2C | close_observer | glue on both `close_button`s, slot 1, OnClose |
| +0x58 | cooperation_observer | glue on `set_cooperation`, slot 2 `0x6E3030` |
| +0x84 | cov_ops_observer | glue on `open_cov_ops`, slot 2 `0x6E1B40` |
| +0xB0 | | the cooperation count (C.4) |
| +0xB4 / +0xB8 | owner | owner tag and id at the last refresh |
| +0xBC / +0xC0 | controller | controller tag and id at the last refresh |
| +0xC4 | flag_observer | glue on both flags, slot 1, OnFlagClicked |
| +0xF0 | spawn_partisan_observer | glue on `spawn_partisan`, slot 2 `0x6E1450` |
| +0x11C | spawn_underground_observer | glue on `spawn_underground`, slot 2 `0x6E1460` |
| +0x148 | underground_mission_observer | glue on `underground_mission`: slot 2 `0x6EA380`, slot 9 `0x6EA490` |
| +0x174 | cgm_underground_build | the custom-game window |
| +0x178 | cgm_underground_build_observer | its glue, slot 2 `0x6DDCD0` |

**`Rebuild`, slot 0**: destroys any old window; makes `province_view` and gives it the group `province_view`; binds the
glues by element name, the `underground` ones inside that child window; makes `cgm_underground_build` positioned off the
view's own position, groups it and hides it; refreshes if a province is held.

### A.3 The refresh, `CProvinceView::Refresh` (`0x6DE5F0`, rva `0x2DE5F0`, `ret 8`)

**Callers**: only `CInGameIdler_OpenProvinceView` and `Rebuild`. Not per frame, per tick or on a change of hands:
`Province_SetController` (to its `ret 0x18`) does not read the in-game screen, where the positive control `OnSelected`
does.

**Common head**: `+0x24` = the province; the building columns made on first use and pointed at it (B.1); the window's
group set to `province_view`; the window re-shown if shown (which re-shows every child).

**Several selected** (in-game-screen `+0x130C` above 1): hidden `day_night`, `owner_flag`, `occupier_flag`,
`text_espionage`, `text_partisans`, `text_manpower`, `text_leadership`, the four resource texts, `strategic_resource`,
`temperature_txt`, `wind_status`, the list `adj`, the box `claims`, `coop_label`, `cooperation_list`, `cooperation_bg`,
the window `cov_ops`; `text_title` = `PROV_VIEW_MULTI` "Multiple Selected($NUM$)", NUM the selection count, whole; then
the per-frame update once. **Left as they were**: `terrain` (the previous single province's picture), `overlay`,
`overlay2`, the figure icons, `covert_ops_icon`, `open_cov_ops`, `cov_ops_points`, `set_cooperation`; **`weather_icon`,
`wind_icon` and `ground_status_icon` stay visible**, showing the province just added (`+0x24`).

**One selected**, in order:

1. **`day_night`** frame 1 at night, else 2 - the wrong way round and dead: the update at the end sets it back.
2. **`text_title`**, here and in `underground`: the province's name.
3. Owner and controller tags cached at `+0xB4` and `+0xBC`.
4. **`owner_flag`**: the owner's flag.
5. **`occupier_flag`**: controller id equal to owner id - hidden, and kept at `+0x28`; otherwise `+0x28` = 0 and the
   flag the controller's.
6. **`terrain`**: where `gfx/interface/prov_pictures/provimg_<province id>.dds` exists, that texture in the frame of
   `GFX_terrainimg_plains`; otherwise the sprite `GFX_terrainimg_` + the terrain's key (ocean, mountain, forest, woods,
   marsh, plains, urban, hills, jungle, desert, arctic - all eleven have sprites); re-shown where the window is shown.
7. **`text_espionage`**: the played country's intelligence of the province (0-9) as a bare number, no colour; 0 if the
   country is past the array.
8. **Partisans, manpower, leadership**, gated on that figure being **9** (hardcoded): under 9 `text_partisans`,
   `text_manpower` and `text_leadership` all read `?`; at 9 `text_partisans` is the revolt risk
   (`FINDINGS-occupation.md` B.6); `text_manpower` `-` where the base manpower is 0, else `§Y` + the effective manpower
   (`Province_GetEffectiveManpower`, rva `0xA5140`: (base + the province's `MANPOWER`) x max(0, 1 + the province's
   `LOCAL_MANPOWER` + the owner's `GLOBAL_MANPOWER`), truncated, not below 0) to two places, truncated;
   `text_leadership` `-` where the base is 0, else `§Y` + (base + `MODIFIER_LOCAL_LEADERSHIP`) x max(0, 1 +
   `MODIFIER_LOCAL_LEADERSHIP_MODIFIER`) (`Province_GetEffectiveLeadership`, rva `0xA5310`) the same way - no country term.
9. **`text_oil` / `text_metal` / `text_energy` / `text_raremat`** (goods 3, 4, 5, 6; `ProvinceView_ResourceText`, rva
   `0x2DE400`): `§W0` where the province's max_producing of the good is 0 or less; else `§Y?§W` where intelligence is
   under 9; else `§R` if current_producing is below max_producing, `§G` otherwise, then the daily yield
   (`CMapProvince::ResourceYield`, `FINDINGS-supplyconvoys.md` section 8) to **one place, rounded** (`%.1f`), no closing
   colour.
10. **`strategic_resource`**: shown with the sprite `GFX_<key>_small` for a real resource (set only where the graphics
    hold it; all 17 of Their Finest Hour's do); hidden for none.
11. **`adj`**: one `adj_member` row (`CAdjMember`, `0x6DCBF0`, its update `0x6DCD40`) per edge of the province template's
    edge vector, **in the template's order**, sea neighbours included; the list grown or cut to the count. `adj_text`
    the neighbour's name; `adj_icon` by the edge's kind: 1 (a `sea` crossing in `adjacencies.csv`)
    `GFX_provinceview_strait`, 2 (river) `GFX_provinceview_river`, 3 `GFX_provinceview_impassable`, 0
    `GFX_provinceview_ocean` where the neighbour is sea, else `GFX_provinceview_passable`.
12. The window re-shown and the held occupier flag hidden again.
13. **`claims`**: emptied, then one `prov_claims_entry` per **core**, in the province's core list's order, the owner's
    own included, its `flag` the core holder's; laid out and shown.
14. `coop_label`, `cooperation_list`, `cooperation_bg` and `cov_ops` hidden; the group set again;
    `cgm_underground_build` hidden.
15. The per-frame update (A.5).

**Never touched by the refresh**: `overlay`, `overlay2`, `background`, `background_topbar`, the figure icons,
`covert_ops_icon`, `open_cov_ops`.

**The flags' click** - `CProvinceView::OnFlagClicked` (`0x6EA010`, rva `0x2EA010`): nothing in a custom game's setup;
`owner_flag`, where no scenario is loaded (state `+0xD0C` clear), opens the diplomacy screen (`OpenCountryView(0)`);
`occupier_flag` clears the selection and selects the flagged country's capital, which moves the view there, then the
same diplomacy opening.

### A.4 Tooltips, `BuildProvinceViewTooltip` (`0x6E4250`, rva `0x2E4250`)

`CInGameIdler::GetElementTooltip` sends every element whose group is `province_view` here, with the view; it dispatches
on the element's name. The arguments are (view, out, element), returning out - **the record had them as (out, a, b)**.

| element | main | delayed |
| --- | --- | --- |
| `terrain` | the terrain's localised name | movement cost always; attack, defence, attrition where not 0 (`CTerrain_BuildFigures`) |
| `oil` / `metal` / `energy` / `rare` | `CRUDE_OIL_IRO` "Crude Oil", `METAL_IRO` "Metal", `ENERGY_IRO` "Energy", `RAREMAT_IRO` "Rare Materials" | |
| `text_oil` ... `text_raremat` | the resource block below | |
| `strategic_resource` | the resource's key, localised | each of its modifier values on a line |
| `weather_icon` | by the weather picture: `WEATHER_SNOW_STORM` "Blizzard", `_SNOW` "Snow", `_STORM` "Storm", `_RAIN` "Rain", `_CLOUD` "Cloudy", `_PARTIAL_CLOUD` "Partial Clouds", else `WEATHER_CLEAR_SKY` "Clear Sky" | |
| `ground_status_icon` | frozen > 0 `WEATHER_FROZEN` "Frozen Ground"; else muddyness > 0 `WEATHER_MUDDY` "Muddy Ground"; else `WEATHER_DRY` "Dry Ground" | |
| `wind_status`, `wind_icon` | `WEATHER_WIND` "There are winds at $SPEED$km speed here.", SPEED the windspeed to one place, not clamped | |
| `temperature_txt` | `WEATHER_TEMPERATURE` "Temperature" | |
| `owner_flag` | `PV_OWNER` "Province owned by $NAME$" | |
| `occupier_flag` | `PV_OCC` "Province occupied by $NAME$" | |
| `flag` (a claims entry) | `PV_HAS_CLAIM` "$NAME$ has a claim on this province." | |
| `espionage`, `text_espionage` | by level (`IntelLevelText`, rva `0xA77F0`): `INTEL_NONE` "No intel (0)", `INTEL_STRUCTURES` "Basic Intel (1)", `INTEL_UNITS` "Basic Intel, divisions of unknown strength (2)", `INTEL_2` "Intel lvl 3" ... `INTEL_7` "Intel lvl 8", `MAX_INTEL_LEVEL` "Full Intel (9)" | |
| `icon_manpower`, `text_manpower` | `PV_MANPOWER` "Manpower" | |
| `icon_leadership`, `text_leadership` | `PV_LEADERSHIP` "Leadership" | |
| `partisans_icon` | `PV_RR` "Revolt Risk" | |
| `text_partisans` | the revolt-risk breakdown (`FINDINGS-occupation.md` B.6) | |
| `adj_icon`, `adj_text`, kind 0, land neighbour | `PV_PASSABLE` "Normal" | `PV_PASSABLE_DESC` "This is just a normal connection without any penalties to attack across it." |
| the same, sea neighbour | `PV_OCEAN` "Ocean" | `PV_OCEAN_DESC` "Only ships can enter this province" |
| the same, kind 2 | `PV_RIVER` "River Crossing" | `PV_RIVER_DESC` "Attacking across a river has severe drawbacks, but engineers lessen them." |
| the same, kind 1 | `PV_STRAIT` "Strait" | `PV_STRAIT_DESC` "Attacking across a strait means that they will be subject to the penalties of an amphibious attack if they are opposed." |
| the same, kind 3 | nothing | nothing |

NAME in the three flag tooltips is the country of the element's own flag. The `adj` lookup finds the row owning the
element and reads its edge. The intelligence level is the player's figure, 0 past the array, empty text above 9.

**The resource tooltips** (`text_oil` ... `text_raremat`), line by line: `BASE` "Base:" + " §Y" + current_producing to
two places + "§W\n"; for metal, energy and rare materials only, where the controller's technology factor for that good is
not 0, `FROM_TECHNOLOGY` "From Improved Technology" + ": §G+" + factor x 100 to two places + "%§W\n"; the contributors to
`LOCAL_<good>` then `LOCAL_RESOURCES` in the province's modifier; "\n"; the contributors to `GLOBAL_<good>` then
`GLOBAL_RESOURCES` in the controller's modifier. **No intelligence gate** on any of it.

**Before and after**: checked first, in a custom game's setup, the `cgm_underground_build` window (B.4); checked last,
whatever matched, where `cov_ops` is open a `cov_ops_list` entry owning the element answers instead (C.2). **No
tooltip**: `text_title`, `close_button`, `day_night`, `overlay`, `overlay2`, `background`, `covert_ops_icon`,
`open_cov_ops`, `cov_ops_points`. `PV_INTEL` "Intel Level: $VAL$" is in the localisation and not in the executable
(`findBytes` finds no string; positive control `PV_RR` found).

### A.5 The weather strip and the per-frame update

`ProvinceView_Update` (`0x6E7C00`, rva `0x2E7C00`, section C) runs every frame from `0x650700`, which
`CInGameIdler::Update` calls at `0x655E2E`, while `+0x1CC0`'s window is shown, and at the end of each refresh; all its
paths reach the view test. The strip reads the province's `CWeather` (save keys in brackets):

| element | what it shows |
| --- | --- |
| `weather_icon` | the frame by `CWeather::GraphicName`, compared as strings: `weather_snow_storm` 7, `weather_snow` 6, `weather_thunderstorm` 5, `weather_rain` 4, `weather_cloud` 3, `weather_partialcloud` 2, anything else 1 (the clear sky's name is the empty string) |
| `ground_status_icon` | frame 2 where `frozen` > 0, else 3 where `muddyness` > 0, else 1 |
| `day_night` | frame 2 at night (the hourly `is_night` byte), else 1; frame 1 the bright half of `daynight.tga`, 2 the dark |
| `wind_status` | a bar (the underground bar's setter) at trunc(trunc(min(`windspeed`, 30000) x 10 / 3) / 1000)% - min(wind, 30) / 30, the 30 hardcoded |
| `temperature_txt` | `§G+` above 0, `§Y` at 0, `§R` below (the minus from the number), + `temperature` to one place (`FormatFixedPoint`) + `C`; no closing colour, no degree sign |

`GraphicName` is snow, or the snowstorm, where `precipitation` > `GFX_SNOW_LIMIT` (0.1) and the temperature is under -5;
rain, or the storm, where `precipitation` > `GFX_RAIN_LIMIT` (0.1) - `GFX_SNOW_STORM_LIMIT` and `GFX_STORM_LIMIT` (15.0
each) on the windspeed deciding the storms; otherwise overcast above `GFX_CLOUD_LIMIT` (0.8), partial above
`GFX_PARTIAL_CLOUD_LIMIT` (0.3), else clear. The six limits are defines; the -5 and the 30 are hardcoded.

Also every frame, from the same function: the building rows (B.2); `cov_ops_points` against the controller cached at
`+0xC0` - stale after a change of hands, like the flags (C.1); the cooperation flags (C.4); the `underground` window
(B.4).

### A.6 What looks wrong but is what the bytes do

- `day_night` is set inverted by the refresh, then corrected in the same call by the update.
- Selecting a sea zone clears the whole selection, provinces already shift-selected included.
- **The view does not refresh when the province changes hands**: title, flags, terrain, intelligence and the figures,
  `adj` and `claims` stay until the province is selected again; the weather strip and `cov_ops_points` are live, the
  latter against the old controller.
- With several selected, `terrain` keeps the previously shown province's picture; `weather_icon`, `wind_icon` and
  `ground_status_icon` stay visible for the province added last; `day_night`, the temperature and the wind bar are
  hidden but still updated.
- The figures need intelligence 9; their tooltips (Base, technology, every modifier source) need none; a province
  producing nothing reads `§W0` at any intelligence.
- Resource figures are rounded (`%.1f`), every other figure here truncated; the colour compares current_producing with
  max_producing while the number is the daily yield with technology and modifiers.
- The `claims` box lists **cores**, the owner's included, under a "has a claim" tooltip.
- An impassable edge (kind 3) has no tooltip; a kind-1 crossing is always called a strait.
- The intelligence keys are offset by one: `INTEL_2` is "Intel lvl 3".
- `PV_INTEL` exists in the localisation and is never used.
- The occupier flag's click also moves the selection, and the view, to the occupier's capital; neither flag opens
  diplomacy in a loaded scenario (state `+0xD0C` set).

### A.7 What was not settled

- **Which mouse event the glue's slot 1 is**: a left press, *inferred* from the tutorial menu's six buttons; a click on
  `close_button` closing the view would confirm it.
- **What a click picks where a counter and a province overlap**, and in the air map mode: `0x6416D0`, not read
  (`FINDINGS-airmap.md` has the large air base asked first there).
- **Input slots 10, 11 and 12 as Shift, Alt(?) and Ctrl**: slot 10 = Shift is borrowed from the scrollbar's input
  object; the object here is in-game-screen `+0x1C`. Shift-clicking a second province (title "Multiple Selected(2)")
  would settle it.
- **Which country the diplomacy screen opens on** from a flag click: `OpenCountryView(0)` takes only the index.
- Whether `CFixedWindow::Show` re-shows child windows: the walk over buttons and text boxes is confirmed, child windows
  not checked.
- `ground_icon`'s art: frame 2 frozen and frame 3 mud are from the code; the art was not looked at.
- Screenshots the maintainer could take: several provinces selected (title "Multiple Selected(N)" with the terrain
  picture kept and the weather icons still shown); an occupied province, both flags, then a click on the occupier flag;
  a province at intelligence below 9 (`?` figures, yet tooltips showing Base).

**Frontier (rvas):** `0x250700` (the per-frame panel update in `CInGameIdler::Update`), `0x2416D0` (what is under the
pointer), `0x24D850` (the click-or-drag test), `0x264160` and `0x26B7B0` (after the click's clear), `0x68BBD0` (the
overlapping box's entry wrapper), `0x1D36A0` (Ctrl-click on an army), `0x2DDC00` (`CProvinceView`'s destructor body).

## B. Buildings and the underground

*Read 2026-10-15 off the bytes. Continues `FINDINGS-buildingqueue.md` A.2 (`CBuildingMember::OnClick`) and
`FINDINGS-occupation.md` E.7.*

### B.1 Which buildings get a row, and in which column

The view's refresh (`0x6DE5F0`, section A) fills `buildings_left` and `buildings_right` **only when `buildings_left`
holds no row** - once, the first time the refresh runs on a view; every later refresh only writes the view's province
(+0x24) into each row's +0x2C (`0x6DE942`-`0x6DE980`). The rows come from the building database's vector
(`g_CBuildingDataBase +0xC`), whose position 0 is the built-in `nobuilding` (`CNullBuilding`) and the rest
`buildings.txt`'s entries in file order. With `n` the vector's size:

    half = (n - 1) / 2                       ; truncated
    left column:  positions 0 .. half
    right column: positions half+1 .. n-1
    a position gets a row where the building's slot 8 answers true
        (CBuilding: always; CNullBuilding: never)
        and show_for_province (+0x96) is set

Rows are added with the list box's slot 4 in that order, top to bottom in database order (appending *inferred* from the
call). **Hidden buildings still count towards the split.** In Their Finest Hour `n` is 12 and `half` 5: left Air Base,
Naval Base, Coastal Fort, Land Fort, Anti-Aircraft Guns; right Radar Station, Nuclear Reactor, Rocket Test Site,
Industrial Capacity, Infrastructure. The underground (`show_for_province = no`) has no row. **The list does not depend
on the province or the player**: a landlocked province still shows Naval Base and Coastal Fort, disabled.

### B.2 A row: `CBuildingMember`

0xA0 bytes, RTTI base `CStandardlistboxItem`, vftable `0x15D3E38` (a second at +0x1C, `0x15D3E6C`), made from the window
`building_member`. +0x20 its window, +0x28 the building, +0x2C the province, +0x30 its label, +0x50 the click glue.

**The constructor** (`0x6DB560`, rva `0x2DB560`, `ret 0xC`):

1. **Sprite**: `building_icon`'s sprite is `GFX_provinceview_` + the building's key (button slot 57). Every Their Finest
   Hour building has one but the underground; each is a single frame.
2. **Clicks**: the glue `VCBuildingMember::__CButtonObserverGlue` (vftable `0x15D3ECC`) on `building_icon` - slot 2, the
   plain left click, calls `CBuildingMember::OnClick` (`0x6DBE40`); slot 9, the right click, `CBuildingMember::OnRightClick`
   (`0x6DBB00`). That slot 9 is the right click rests on the maintainer's confirmation for another glue of the same
   interface (`FINDINGS-leaderwindow.md` section 6), and the custom game's `CGM_TOOLTIP_BUILDING_SHORTCUT` ("§GLMB§! to
   increase the level.\n§GRMB§! to decrease the level.\n§GCtrl+LMB§! to reset to default.") agrees.
3. **The shortcut and the label**: the building's name - `CBuilding` slot 6, the localised text the `CBuilding`
   constructor renders into +0x38 at load (`0x4B64F8`-`0x4B6537`) - is walked character by character against a list of
   characters every row of this refresh shares, left column first; the first character not on it is added to it and
   becomes the button's **keyboard shortcut** (button slot 55, a one-character string), and the label (+0x30) is the
   name with that character wrapped in `§Y`...`§W`. The compare is byte for byte, so **case counts**: Their Finest
   Hour's keys come out A, N, C, L, **n** (Anti-Aircraft Guns), R, **u** (Nuclear Reactor), **o** (Rocket Test Site), I,
   **f** (Infrastructure). Where every character is taken, the label is the plain name and the shortcut empty.

**The update** (`CBuildingMember::Update`, `0x6DC380`, rva `0x2DC380`, slot 8), run for every row by the view's update
(`0x6E7C00`, at `0x6E7CB0`/`0x6E7D40`):

*Enabling* (button slot 46 enables, 47 disables): in a custom game's setup where `0x4208B0` answers true, disabled; with
**two or more objects selected**, enabled where **any** selected province the player controls passes
`CCountry::IsBuildingAllowed(player, building, province)` (`IsBuildingAllowedIgnoringLevel` in the setup); with one or
none, enabled where the row's province is controlled by the player (+0x338) and passes the same test. So the button is
greyed exactly where `OnClick` would post nothing (`IsBuildingAllowed`: `FINDINGS-buildingqueue.md` B.3).

*Pips*: `plupp_0` ... `plupp_{N-1}`, N the building's `max_level` (+0x68); sprite `GFX_prov_building_plupp`, 3 frames,
measured on `gfx/interface/prov_building_plupp.dds`: **frame 1 green, frame 2 orange, frame 3 grey**. `intel` is the
player's intelligence of the province (+0x370[player], 0 past +0x374):

    if intel >= 6  or  (the building's modifier is MODIFIER_INFRASTRUCTURE (12) and intel >= 1):
        built   = trunc(level_max / 1000.0)               ; single precision
        working = level_current / 1000.0
        queued  = sum of size (+0x40) over the PLAYER's building lines here of this building
        for pip i = 1 .. N:
            i > built + queued   -> hidden
            else shown, frame:  i > built -> 3 (queued)
                                i > working -> 2 (built, not working: damaged or still being repaired)
                                else -> 1 (working)
    else if infrastructure (so intel == 0) and MaxInfrastructure (+0x5C) < 200   ; floor(200.5f), a static
        every pip hidden
    else
        pip 1: frame 1 where level_max / 1000.0 > 0, else hidden    ; frame set (slot 18) but not shown (slot 13)
        pips 2..N hidden

A pip is green only where that whole level works: built 3 and working 2.5 give pips 1-2 green and pip 3 orange. A new
level, which `Deliver` adds at working level 0 (`FINDINGS-buildingqueue.md` B.2), shows orange until the day's repair
fills it. Grey pips are lines **with this province as their location** in the player's own queue; a production-screen
line with no province is not counted.

**The click** is `FINDINGS-buildingqueue.md` A.2, unchanged: one level a click for each selected province the player
controls, and **no modifier key does anything in a game** - Ctrl matters only in a custom game's setup, where it resets
the level to the default (which corroborates A.8's reading of the in-game screen's +0x1C slot 12 as Ctrl). **The right
click** (`0x6DBB00`, rva `0x2DBB00`) returns at once outside a custom game's setup; in the setup it lowers the level of
each selected controlled province by one (`CCgmSetBuildingLevelCommand`), with floors (*inferred* in detail). **There is
no way to cancel a queued level from the view.**

### B.3 A row's tooltip

`BuildProvinceViewTooltip` sends `building_icon` and `plupp_0`...`plupp_9` to `ProvinceView_BuildBuildingTooltip`
(`0x6E9160`, rva `0x2E9160`, `ret 0x10`), once with `buildings_left` and once with `buildings_right`; it finds the row
whose window holds the element and reads the **view's** province (+0x24).

**The player's intelligence of the province below 6**: `text` is the building's name, plainly, and nothing else - no
infrastructure exception here.

**Otherwise, `building_icon`**: `text` the row's label (the name with its shortcut letter in yellow), then **into
`delayed`** the first that applies:

1. the building is not available to the player's technology (`building_available[index]`): `PV_NB_TECH` "You do not have
   the technology to construct this building.", followed, where the building has an unlocking technology (+0x10), by
   `"\n (§R*) "` and that technology's name;
2. in a custom game's setup with the player controlling the province: `0x6E3D90`'s text, and
   `CGM_TOOLTIP_BUILDING_SHORTCUT` into `delayed_extra`;
3. the province is not controlled by the player: `PV_NB_HOSTILE_TERR` "This province is not controlled by you.";
4. whole built levels plus the **player's** queued lines here are at or above `max_level`: `PV_NB_MAX_SIZE` "This
   building has already reached its maximum size.";
5. **the province has a CPort (+0x354) and the building is `port = yes`**: `PV_BUILD_ONLY_IN_PORT` "This is only possible
   to be built in a coastal province.";
6. otherwise nothing.

The in-game screen then puts "Shortcut:" and the key into `delayed_extra` where it is empty (`FINDINGS-tooltips.md`
section 4).

**A pip**: appended to `text` - `level_max` 0: `PV_BUILD_NO_YET` "Not yet built in this province."; `level_current`
equal to `level_max` (as floats): `PV_BUILD_W_DESC` "This building is built up to level §Y$MAX$§W.", MAX `level_max` to
no places; otherwise `PV_BUILD_DESC` "This building has been damaged and is currently at §Y$CURR$§W level. It is built up
to level §Y$MAX$§W, but will take time to repair. Further combat may reduce it even further.", CURR `level_current` to
three places and MAX `level_max` to none. Then, where the **province controller's** queued lines of this building here
have any size, `"\n"` + `PV_CURR_CONS_MORE` "Currently constructing more.". The figures go through `FormatFloat`
(`sprintf` `%.Nf`), so they are rounded. **Neither tooltip ever states a cost, a time or what the building does.**

### B.4 The `underground` window

*Elements*: `background_topbar_resistance`, `underground_status` (progress bar `supply_progress`), `spawn_partisan`,
`spawn_underground`, `supression_icon`, `text_supression`, `underground_mission` (`GFX_underground_mission_automatic`,
3 frames), `close_button`, `text_title`. **No owner or occupier flag of its own**; those are the main window's.

*Bindings* (`0x6E35C0`): `spawn_partisan` glue at view +0xF0, left click `0x6E1450` -> `ProvinceView_OnSpawnButton(0x786)`;
`spawn_underground` +0x11C, `0x6E1460` -> `ProvinceView_OnSpawnButton(0x787)`; `underground_mission` +0x148 (vftable
`0x15D3E0C`); `close_button` **the view's own close glue at +0x2C**, so it closes the whole view.

**The gate** (`ProvinceView_GetUndergroundProvince`, `0x6EA920`, rva `0x2EA920`), called by the view's update at
`0x6E8860`, returns the province P the window is about: with fewer than two objects selected, the view's province where
its underground has `level_max > 0` **and** either the player owns it (`underground_owner`) or
`Underground_CanPlaceIn(province, player, false)` holds (in a custom game's setup, `CanPlaceIn` alone); with two or more,
the **first selected province** in selection order passing the same test; otherwise null, and the update hides the
window (its +0x18 slot 14). So the window shows for the player's own underground, or for anyone's in a province where
the player could have one.

**What the update shows for P, in order** (`0x6E8871`-`0x6E90ED`):

1. `spawn_partisan` enabled, outside the setup, where `ProvinceView_CanMobilizeSelection(P)` (rva `0x2EAC50`) holds: with
   two or more selected, any selected province with the player's underground passing `CanMobilizePartisans`; otherwise
   `CanMobilizePartisans(player, P)`;
2. `spawn_underground` alike with `CanSpawnUnderground` (rva `0x2EADB0`);
3. `underground_status` = `round(P.level_current x 100000 / 1000 / 1000.0)`, a whole percent of 1.0 by `fistp` (half to
   even); 0 in the setup;
4. `text_supression` = `"§Y"` + `FormatFloat(UNDERGROUND_DETECT_CHANCE / 1000.0 x P.suppression(+0x28) / 1000.0, 0 places)`
   + `"%§W"` - with `UNDERGROUND_DETECT_CHANCE` 2, twice the province's suppression: 0.6 shows "1%";
5. `underground_mission`'s frame = `(P's underground level_max > 0 ? underground_action : 2) + 1`, **enabled only where
   P's underground is the player's**;
6. outside the setup both spawn buttons shown; in it the code-made button `cgm_underground_build` (view +0x174) is shown
   labelled `BUILD` "Build" or `DESTROY` "Destroy" and the spawn buttons hidden.

**`text_title`** is set by the refresh (`0x6DF741`-`0x6DF7FC`) to the **view's** province's name, the same call the main
title uses at `0x6DF683`. `supression_icon` and the background are static.

**`underground_mission`'s mouse buttons**: **left click** (`0x6EA380`, rva `0x2EA380`, the glue's slot 2 -> +8) frame
1->2->3->1, partisans -> spread -> none -> partisans; **right click** (`0x6EA490`, rva `0x2EA490`, slot 9 -> +0x24)
3->2->1->3. Each sets the frame, then `ProvinceView_PostUndergroundMission(view, frame)` posts
`CChangeUndergroundMission(province, frame - 1)`; with several selected, for every selected province with the player's
underground, all to the same action, stepped from P's displayed frame.

**Tooltips** (`BuildProvinceViewTooltip`), all of them reading the **view's** province, not P:

- `underground_status`: `text` `UNDERGROUND_STATUS` "Underground strength: §Y$CURRENT$§W/§Y$MAX$§W", CURRENT
  `level_current` and MAX `level_max`, `FormatFixedPoint` to one place;
- `spawn_partisan`: where the owner is not the player, `text` `UNDERGROUND_OWNER_DESC` "Underground owned by
  §Y$COUNTRY$§!"; otherwise `text` `SPAWN_PARTISAN` "Spawn partisan unit" with **`delayed`** `MOBILIZE_PARTISANS` or
  `UNDERGROUND_NOT_STRONG_ENOUGH`;
- `spawn_underground`: the same with `SPREAD_UNDERGROUND` "Expand underground resistance network" and
  `MOBILIZE_UNDERGROUND` / not strong enough in `delayed`;
- `underground_mission`: owner neither the player nor `---`, `UNDERGROUND_OWNER_DESC`; otherwise by action 0
  `UNDERGROUND_ACTION_PARTISAN` "Spawn partisan unit as soon as we can", 1 `_SPREAD` "Spread underground network as soon
  as we can", 2 `_NONE` "Do nothing and build up strength", any other nothing;
- `supression_icon`: `SUPRESSION` "Suppression";
- `text_supression`: **nothing** - the builder compares the name `supression_text` (`0x6E6927`, string `0x15D3C58`),
  which neither install's interface files contain; `supression_icon` is found the same way, as the control;
- in the setup, `cgm_underground_build`: `CGM_TOOLTIP_UNDERGROUND_BUILD_DESTROY` "Build or Destroy the underground base."

This settles `FINDINGS-occupation.md` E.7's "main line and delayed half told apart by layout, inferred" from the offsets
written.

### B.5 What looks wrong but is what the bytes do

1. A right click on a building does nothing in a game, and a queued level cannot be cancelled from the view.
2. "This is only possible to be built in a coastal province." appears where the province **has** a port and the building
   can be built, never where it lacks one.
3. The view never states a building's cost, build time or effect.
4. The button's tooltip and the pips count the player's queued lines; the pips' tooltip counts the province controller's.
5. Below intelligence 6 only "something is built" shows, as one green pip - given its frame but not shown, so a pip
   hidden for an earlier province stays hidden (*inferred*). Infrastructure shows full pips from intelligence 1; at
   intelligence 0, infrastructure under two levels hides every pip.
6. Shortcut letters are case-sensitive, so some rows get lowercase letters.
7. `text_supression` has no tooltip (the misspelt lookup name).
8. The suppression figure, labelled with %, is twice the province's suppression - about ten times the daily detection
   chance, `round(2S)` per thousand (E.4; the comparison *inferred*).
9. The window's figures and enabling are about P, the first qualifying selected province, while its title and tooltips
   are about the view's province.
10. Rows are built once per view, whatever the province.

### B.6 Corrections

- `FINDINGS-buildingqueue.md` B.7's open question on `CBuilding +0x38` is settled: the localised text, rendered once at
  load.
- `BuildProvinceViewTooltip`'s recorded signature `(void* out, void* a, void* b)` is wrong: `[ebp+8]` is the view (its
  +0x174 and +0x24 are read), `[ebp+0xC]` `out` (copied into at `0x6E7BA1`), `[ebp+0x10]` the element. Section A revises
  the record.

### B.7 Not settled

- Whether a lowercase shortcut letter ('n', 'u', 'o', 'f') resolves to a key: pressing N with a province selected would
  show whether the Anti-Aircraft Guns row answers.
- How a disabled `building_icon` is drawn; its sprites are single-frame. A screenshot of a hostile province's view.
- That slot 13 shows an icon and slot 14 hides it, so the low-intelligence pip stays hidden: view a no-intelligence
  province, then a low-intelligence one with a fort.
- Whether the list's slot 4 appends.
- What `FormatFloat` makes of an exact .5 under `%.0f`.
- The custom-game helpers `0x4208B0`, `0x41B700`, `0x41B370` and `0x6E3D90`.

**Frontier (rvas):** `0x2E3D90` (the custom game's building price text), `0x208B0`, `0x1B700`, `0x1B370`, `0x2DE340` (the
close glue's handler), `0x2E35C0` (the view's element binding).

## C. Covert operations and allied cooperation

*Read 2026-10-15 on the listing, with the decompilation of a copy carrying the record.*

**In one line.** `open_cov_ops` toggles a panel listing `common/covert_ops.txt`'s operations in file order, those whose
`is_valid` holds; each row's button carries the operation's localised name and is enabled while `is_valid` and
`CCovertOpsMission_CanSelect` both hold, and pressing it posts `CSendCovertOpsMission` and nothing more.
`set_cooperation` toggles a second panel in the same place listing the player's Allies with a checkbox each; ticking one
posts `CSetAlliedObjectiveCommand`, asking that ally to take this province, and unticking withdraws it. The
`allied_cooperation` box shows the flags of everyone the player has asked about this province. In the simulation the
request is an AI objective bonus that, per `FINDINGS-aifields.md`, steers nothing.

### C.1 The covert-operations elements and their panel

**`covert_ops_icon`, `open_cov_ops` and `cov_ops_points` are always shown.** No code looks up `covert_ops_icon` (its
name is not in the image); `open_cov_ops` is referenced only where its glue is bound (the view's slot 0, 0x6E38AB);
`cov_ops_points` only in `ProvinceView_Update`. None of the three is ever hidden, not even with several provinces
selected.

**`cov_ops_points`** is set on every call of `ProvinceView_Update` (`0x6E7C00`, rva `0x2E7C00`):
`itoa(trunc(P.espionage[controller].covert_ops_points / 1000))`, P the played country and controller the id the view's
refresh copies from `CMapProvince +0x338` into view +0xC0. So it is **the player's covert-ops points about the
province's controller**, whole points, no decimals, no colour - the same figure as the intelligence screen's
`covert_ops_value` (`FINDINGS-espionage.md` D.1); in the player's own province, the home record's points.
`ProvinceView_Update` is called from the in-game screen's frame work (0x65097D, inside 0x650700, called from
`CInGameIdler::Update`) when the view's window has its +0x5B set (*inferred*: every frame while open; the gate was not
read), and twice from the view's refresh.

**`cov_ops_label`** is never looked up (its name is not in the image), so it keeps the file's `COVERT_MISSIONS_LABEL`
"Covert Missions". `cov_ops_bg` is `GFX_coop_bg`.

**`open_cov_ops`** is `CProvinceView::OnOpenCovertOps` (`0x6E1B40`, rva `0x2E1B40`), a toggle: where `cov_ops_bg` is
visible (its +0x43), the `cov_ops` window is hidden and that is all; otherwise `coop_label`, `cooperation_list` and
`cooperation_bg` are hidden (the two panels share the place at 254,11), the `cov_ops` window hidden, `cov_ops_list`
refilled, and the window shown.

**What closes it**: `open_cov_ops` again; opening the allied-objectives panel (`set_cooperation` hides the `cov_ops`
window); and **every refresh of the view** - selecting a province, one or several: both the single and the
multi-selection branch of the refresh (0x6DE5F0) hide `coop_label`, `cooperation_list`, `cooperation_bg` and the
`cov_ops` window. There is no close button inside it, and pressing an operation does not close it.

**The list** - `ProvinceView_FillCovertOpsList` (`0x6E2DA0`, rva `0x2E2DA0`) - empties `cov_ops_list`; with no province
or id 0 it stays empty; otherwise it walks the covert-operations database's vector, which `LoadCovertOperations`
push_backs in file order, and adds a `cov_ops_mission_entry` row for every operation whose **`is_valid` is empty or
holds on a scope with FROM = P and the province as scope**, then updates every row (C.2). The list is made only when the
panel opens: an operation whose `is_valid` stops holding stays listed, greyed by the rows' updates; one that starts
holding appears only when the panel is reopened. Their Finest Hour's four, in order:

| key | cost | `is_valid` | shown as |
| --- | --- | --- | --- |
| `sabotage_strategic_resource` | 10 | `has_strategic_resource = yes` | "Sabotage strategic resource" |
| `steal_battle_plans` | 10 | | "Steal local battle plans" |
| `scout_area` | 15 | | "Scout area" |
| `sabotage_area` | 15 | | "Sabotage area" |

### C.2 A row: `cov_ops_mission_entry` (`CCovOpsMissionEntry`, `0x6E1DB0`, rva `0x2E1DB0`)

**`selectbutton`'s text** is `LocaliseObjectKey(mission)`: the operation's key looked up in localisation (`sabotage_area`
-> "Sabotage area"). No cost. Set once, when the row is made, replacing the file's "???".

**Enabling** - `Update`, slot 8 (`0x6E1FF0`, rva `0x2E1FF0`): valid = the row's province id is not 0 and (`is_valid`
empty or holding with FROM = P and the province); can = `CCovertOpsMission_CanSelect` (recorded: P's whole points about
the province's controller >= cost, and `is_selectable` empty or holding). Enabled when both hold, disabled otherwise,
**never hidden**. It runs for every row when the list is filled, and every frame from `ProvinceView_Update` while the
`cov_ops` window is open (its `cov_ops_bg` visible).

**Pressing it** - `OnSelect` (`0x6E2C10`, rva `0x2E2C10`) - posts `CSendCovertOpsMission(actor = P, province = the row's
province id, mission)` with no test. The window stays open and the list is not refilled; once the command executes the
points have gone, and the next frame's `Update` greys whatever is no longer affordable. `Execute` (recorded) takes cost
x 1000 off P's points about the province's controller, no floor, then runs the effect with FROM = P and the province as
scope. No message.

**The tooltip.** The row's window is tagged `province_view`, so `BuildProvinceViewTooltip` answers its elements: it
looks through `cov_ops_list`'s rows, only while `cov_ops_bg` is visible, for the row owning the hovered element and
calls `BuildTooltip` (`0x6E2230`, rva `0x2E2230`). Over the whole row, button included:

- **Main line**: `CCovertOpsMission_GetDescription`, `<key>_desc` - `sabotage_strategic_resource_desc` "Sabotage the
  strategic resource in this province to reduce its effect.", `steal_battle_plans_desc` "Infiltrate to steal local
  battle plans and give us an intelligence advantage in the area.", `scout_area_desc` "Send in spies to do detailed
  scouting of the area before an advance.", `sabotage_area_desc` "Sabotage bridges, destroy road signs and generally
  make it a difficult place for the enemy to move through."
- **Delayed half**, in order:
  1. the cost, with points = trunc(P.espionage[province's controller].covert_ops_points / 1000): where cost > points,
     `COV_OPS_COST_LACKING` "Costs §R$COST$§! covert ops points. We only have §Y$CURRENT$§! " (COST the cost, CURRENT
     the points, both whole; **it ends in a space, not a line break**); otherwise `COV_OPS_COST` "Covert ops cost: " +
     "§Y" + the cost + "§!" + a line break;
  2. **only while the button is disabled** (its slot 48, as `FINDINGS-orderstooltips.md` reads that slot) and
     `is_selectable` has conditions: the block's own text (`CTrigger` slot 9, `GetBlockText(out, scope, false, 0)`,
     scope FROM = P and the province) + a line break;
  3. where the effect has entries: `COV_OPS_EXECUTE` "\n\nEffect:\n", then the effect block's text (`CEffect` slot 8,
     `GetBlockText(out, scope, 0, "", 0)`) + a line break.

  `is_valid` is never shown.

### C.3 The allied-objectives panel: `set_cooperation`, `cooperation_bg`, `coop_label`, `cooperation_list`

**`set_cooperation`** (`GFX_coop_open`) is always shown and never looked up but to bind its glue. It is
`CProvinceView::OnSetCooperation` (`0x6E3030`, rva `0x2E3030`), a toggle: where `cooperation_list` is shown (its +0x47,
*inferred* to be the shown byte from its use here), the list, `cooperation_bg` and `coop_label` are hidden; otherwise the
`cov_ops` window is hidden, the list made, and the list, `cooperation_bg` (`GFX_coop_bg`) and `coop_label` shown.
`coop_label` keeps the file's `COOP_LABEL` "Allied Objectives" (the key is not in the image). The panel is also hidden
by every refresh of the view (C.1) and by `open_cov_ops`.

**Who is listed**: P's **Allies** (`CCountry +0xF88`), in that list's order - per `FINDINGS-faction.md` and
`FINDINGS-espionage.md` E.3, P's bilateral alliances (the database loop) and then the other members of P's faction -
each kept where it takes part in the scenario (`CCountry +0x44`) and **it is not the case that P's and the ally's
factions are both real and different**. Nothing else is asked: not war, not whether the ally is human, not the province.
The list is resized to that count, adding `CAlliedItem` rows or trimming from the end (rows are reused between
openings), and each row set by `CAlliedItem::Set` (`0x6DD380`, rva `0x2DD380`): `flag` (`GFX_minishield_small`) the
ally, `country_name` its name, and `objective` (`GFX_coop_checkbox`, two frames) **ticked where P has already asked that
ally to take this province** - where the record for this province in `CGameState +0xBAC`[P], the objectives indexed by
the asker, holds the ally's id - and cleared otherwise (C.6). The rows are set only when the panel opens; while it is
open only the player's own clicks change them.

**Ticking `objective`** runs `CAlliedItem::OnChecked` (`0x6DD500`, rva `0x2DD500`) - the checkbox observer's checked
notification (`CCheckBox` slot 1, 0xA81D10, notifies observer slot 2 on becoming checked and slot 3 on becoming
unchecked; the row's glue maps them to +0x48 and +0x50) - which posts **`CSetAlliedObjectiveCommand`** (country = the
row's ally, requester = P, province = the view's province id, active = 1). **Unticking** runs `OnUnchecked`
(`0x6DD6A0`, rva `0x2DD6A0`): the same with active = 0.

The command (`0x553B50`, rva `0x153B50`; save token `set_allied_objective`): country +0x3C/+0x40, requester
+0x44/+0x48, province +0x4C, active +0x50. `IsValid` (slot 14): province >= 0 and both ids non-zero. `Execute`
(recorded) adds the objective to `CGameState +0xB9C`[country] and the mirror `+0xBAC`[requester], or removes both. **The
province view is the only place that makes one from game state**: no Lua binds it and the AI does not post it.

**What it does** (`FINDINGS-aifields.md` section 1, cited, not re-read): the asked country's AI, only while it is itself
at war, gives +100 objective priority to each province a faction member at war or a non-hostile country has asked it to
take; nothing weighs `CObjective::priority`, so the effect is to make that AI post its objective list again that hour,
and no more. Leaving a faction clears every objective in either direction (`CFaction::RemoveMember`). Objectives are
saved as `allied_objectives`. What the asked player sees was not read: the outliner's `CAlliedObjectiveMember`, alert
15 `alert_allied_objectives`, the map object type `allied_objective`.

### C.4 The `allied_cooperation` box

`ProvinceView_FillAlliedObjectiveFlags` (`0x6E1790`, rva `0x2E1790`) empties the overlapping-elements box, finds the
record for the view's province in `CGameState +0xBAC`[P], and only where one exists stores its count in view +0xB0 and
adds a `prov_claims_entry` per country P has asked, in the order asked (each flag set to the country), and shows the
box. `ProvinceView_Update` calls it when that count (0 with no record) differs from view +0xB0. The box is never
hidden. So it shows **the flags of the allies P has asked to take this province.**

### C.5 Tooltips

- Every operation row: C.2.
- `set_cooperation`, `open_cov_ops`, `cov_ops_points`, `coop_label`, `cov_ops_label`, `covert_ops_icon`: **none** -
  each name is absent from the image or referenced only where it is bound or set. The positive control: `cov_ops`,
  `cov_ops_bg` and `cov_ops_list` are each found inside `BuildProvinceViewTooltip`.
- `objective` has `tooltip = ""` in the file.
- `BuildProvinceViewTooltip` answers **any element named `flag`** with `PV_HAS_CLAIM` "$NAME$ has a claim on this
  province.", NAME the flag's country. Both the `allied_cooperation` box's flags and the `allied_coop_item` rows' are
  named `flag`. Whether they reach that routine depends on the `province_view` tag: it is set by a recursive call
  (window slot 30, 0xAC3620, walking the children existing at the time); the view re-tags itself only at the end of a
  refresh, just before `ProvinceView_Update` adds the asked flags; the `CAlliedItem` rows are never tagged when made.
  The *inference* is that they usually have no tooltip and may say "... has a claim on this province." after a later
  refresh has tagged them - not settled (C.8).

### C.6 What looks wrong but is what the bytes do

1. The covert-ops list is made only when the panel opens; later changes only grey buttons.
2. Pressing an operation neither closes the panel nor checks anything; the command spends with no floor.
3. A row's tooltip shows the `is_selectable` conditions whenever the button is disabled, even when the only reason is
   the cost or `is_valid`; with too few points they run straight on after "...We only have §Y5§! ", because
   `COV_OPS_COST_LACKING` has no closing line break.
4. `is_valid` is never shown.
5. Points are always about the province's **controller**: in land the player holds, operations cost its home points.
6. `cov_ops_points`, `open_cov_ops` and `set_cooperation` stay up with several provinces selected; `cov_ops_points`
   then shows the last single province's controller.
7. View +0xB0 is never initialised and is written only where a record exists: moving from a province with N asked
   allies to another with N, or from one with none to one with as many as an earlier province had, leaves the
   `allied_cooperation` box showing the old flags or nothing; a province with none, after one with some, refills an
   empty box every frame.
8. Allies in a different real faction from the player's are left out, though a bilateral alliance can cross factions.
9. The ticked state is set only when the panel opens; nothing re-reads the objectives while it is open.
10. An unticked row's box is cleared unless the checkbox's +0xD8 is set and +0x136 clear (C.8).

### C.7 Corrections

- The record's `CSendCovertOpsMission::CSendCovertOpsMission` comment had the row's province at +0x78 and mission at
  +0x7C; it is mission +0x78, province +0x7C (call site 0x6E2CCB-0x6E2CE2).
- `FINDINGS-aifields.md` section 1 calls `CSetAlliedObjectiveCommand`'s `mov eax,0x757` "slot 5"; the table has it at
  slot 7, slot 5 being the shared stub 0xABF890.
- `FINDINGS-espionage.md` B.7's "and more": Their Finest Hour has exactly four operations.
- B.14's "who evaluates `is_valid`" is settled: the list's filler and the row's `Update`; and "what the province view's
  window shows" by C.1 and C.2.

### C.8 What was not settled

- **The `flag` tooltips** (C.5). A screenshot would settle it: hover a flag in the Allied Objectives box under the
  province view, and one in the opened `set_cooperation` list, before and after re-selecting the province - does it say
  "X has a claim on this province."?
- The checkbox's +0xD8 and +0x136, which `CAlliedItem::Set` and `CCheckBox` slot 1 test: slot 1 refuses to untick with
  +0xD8 set and does nothing with +0x136 clear; for a plain checkbox they presumably do not bite.
- `cooperation_list +0x47` as the list's shown byte, *inferred* from its use as the toggle's state.
- That `ProvinceView_Update` runs every frame (the +0x5B gate at 0x650976 was not read) - brief A's question.
- What the asked side sees: `CAlliedObjectiveMember`, `alert_allied_objectives`, the `allied_objective` map object.
- The colour meaning of the `false` passed to `is_selectable`'s `GetBlockText`.
- What +0x24 holds with several provinces selected, which decides what `open_cov_ops` fills the list from then (brief A).

**Frontier (rvas):** `0x154120` (`CSetAlliedObjectiveCommand` Clone), `0x153D90` (its slot 2), `0x250700` (the in-game
screen's frame work that calls the view's update), `0x2B5A40`, `0x2B68A0`, `0x2B69E0` (`CAlliedObjectiveMember` slots
13-15), `0x2DE340` (the `close_button` handler), `0x2E35C0` (`CProvinceView` slot 0), `0x6C3620` (window slot 30, the
tag's recursion).
