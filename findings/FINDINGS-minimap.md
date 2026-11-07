# The minimap and the map mode buttons

What the minimap at the lower right of the in-game screen is, draws and does, and how the sixteen
map mode buttons beside it switch the map - read 2026-11-07 by a delegated agent (fragment
`interface-minimap.json`) for a reimplementation that has neither; the map tooltip's anchor checked
again off the bytes by the collecting session. Addresses are **VAs** unless written "rva";
`project.json` holds rvas (VA - 0x400000). Valid for this build only.

Settled: the minimap is a fixed picture; the camera frame on it (how computed, drawn with what, when
redrawn); what a click does and what nothing else does; the day/night overlay over it; each button's
binding, setter, pressed look, tooltip and lack of a shortcut; the modes the game enters by itself;
the mode a game starts in. **One correction to `FINDINGS-tooltips.md`**: the map's tooltip is placed
at the minimap's corner, not at the mouse (section 8).

## 1. What is on screen, and who makes it

`tfh/interface/menubar.gui`:

| element | kind | sprite | position (LOWER_RIGHT) | made by |
| --- | --- | --- | --- | --- |
| `minimap_bg` | top-level iconType | GFX_minimap_bg, `minimap_bg.dds` 340x160 | -380, -151 | the screen, kept at CInGameIdler +0x1918 |
| `minimap_pic` | top-level iconType | GFX_minimap, `minimap.dds` 320x128 (the .gfx says .tga) | -363, -135 | **CEU3Gui_CreateMinimap** -> a `CEU3Minimap`, kept at +0x1920 |
| `minimap_overlay` | top-level iconType | `day_night_scroll`, a scrollingSprite of `daynight_overlay.tga` (512x128), size 320x128, step 24, progress.fx | -362, -136 | the screen, kept at +0x191C |
| `minimap_bg_shadow` | iconType in window `menubar` | GFX_minimap_bg_shadow | -380, -161 | the window only - no code names it |
| `mapmode_1`..`mapmode_16` | guiButtonType in `menubar` | GFX_mapmode_*, 52x20, noOfFrames 2, buttonstate.fx, `clicksound = click`, no shortcut | y -156, x from -378 by 21 | the window; bound by Enter |
| `map_zoom_in` / `map_zoom_out` | guiButtonType in `menubar` | | -32, -59 / -32, -32 | shortcut PAGE_DOWN / PAGE_UP |
| `minimap_closed` | commented out in the file | GFX_minimap_closed (32x100) | | **nothing** |

From left to right the buttons run `mapmode_1, 14, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 15, 16, 12, 13`.

**`CEU3Gui_CreateMinimap`** (`0x6435E0`, rva `0x2435E0`; the gui in ESI, the name in EDX, the parent
on the stack, `ret 4`) is the only maker of a CEU3Minimap. It looks the iconType up in the gui's type
tree (+0x34, slot 1), news 0x120 bytes, runs `CEU3Minimap::CEU3Minimap` (`0x67A3C0`: this, graphics,
gui, parent, type in EDX, `ret 0x10`) and appends the object to the gui's element vector (+0x5C). Its
two callers both pass `minimap_pic`: `CInGameIdler::Enter` (`0x65F99A`, the result stored at +0x1920
at `0x65F99F`) and **`CInGameIdler::ReloadMenubar`** (`0x658EC0`, rva `0x258EC0`). ReloadMenubar is
slot 0 of the CReloadDispatcher table CInGameIdler carries at +0xB4, so `this` is idler + 0xB4. It sits
right after `CInGameIdler_Render`'s `ret 4` at `0x658EBD` with no padding - **a trap-2 pair**. It
deletes and remakes `bg_main_menus` (hidden), `minimap_bg` (shown), `minimap_pic` (shown) and
`minimap_overlay` (frame = hour of day, then shown). `confirmed`.

**The class.** `CEU3Minimap < CIcon < CButton < TButton < CGuiObject`. Its own slots are **1**
HandleMouse (`0x67AC00`), **5** the deleting destructor (`0x67A5A0`), **6** Update (`0x67A650`),
**13** Show (`0x67AB70`) and **14** Hide (`0x67ABC0`). Everything else is CIcon's, the drawing of
the picture among it. Its fields, as the constructor sets them: +0xF0 the graphics global
`[0x1A85634]`; +0xF4 the gui; +0xF8 the parent (the screen passes its +0x1794); +0xFC the map
graphics owner `[0x1A855FC]`; **+0x100 the map camera**, read as the owner's +4, which the
CInGameIdler constructor points at its own +0x1938 (`0x648B49`); +0x104/+0x108/+0x10C the camera
x_settled, y_settled and height as last drawn; +0x110/+0x114 the map's width and height as floats
(CMap +0x2A74/+0x2A78, 5616 and 2160); +0x118 and +0x11C two line objects. `confirmed`.

**Shown and hidden.** Show and Hide take both line objects with them. `CInGameIdler::OpenCountryView`
hides the minimap, `minimap_bg` and `minimap_overlay` when a country view opens, and
`CInGameIdler_CloseCountryView` (`0x665220`) shows the three again. **Nothing else opens or closes
the minimap.** The image holds no `minimap_closed`, `GFX_minimap`, `day_night_scroll` or
`minimap_bg_shadow` string. Positive controls: `minimap_bg`, `minimap_pic`, `minimap_overlay` and
`button_goto` are all found, with their references. `confirmed`.

## 2. The picture, and the frame on it

**The picture never changes.** None of CEU3Minimap's six own functions touches a texture or a
colour; the picture is CIcon's sprite, `minimap.dds`. The map mode, the date and the owners do not
reach it. `confirmed`: the same functions do reach the camera and the line objects, so the method
can see what they touch.

**The frame** is redrawn by `CEU3Minimap::Update` (slot 6), which CGui::ProcessInput runs on every
shown element each frame. It does nothing unless the camera's x_settled (+0x33C), y_settled
(+0x340) or height (+0x348) differ from the copies the minimap kept, or the minimap's position
(slot 70) differs from a function-local static pair (`0x1BEB590`). It follows the **eased** camera,
not the target it is moving to. Then:

    fx = x_settled / map_width          fy = y_settled / map_height
    (w, h) = the minimap's size (slot 61)      pos = its corner (slot 70, floats)
    cx = pos.x + fx*w - g          (g = the float at 0x1BEA498: one reference, in .bss, so 0)
    cy = pos.y + (h - fy*h - 4)    (y is flipped: the map's y runs north)
    t  = height / (highest - lowest)                 = height / 960
    hw = int(t*1410 + 70) * 0.1 * 0.25               (0.1 a float widened)
    hh = int(t*820  + 80) * 0.1 * 0.25
    points, each coordinate truncated to int:
        (cx-hw, cy-hh) (cx-hw, cy+hh) (cx+hw, cy+hh) (cx+hw, cy-hh) (cx-hw, cy-hh)

So **the frame's size is a straight line in the camera's height, not the view's projection**. It
does not depend on the screen's aspect. At the starting height of 330 it is about 28x18 pixels on
the 320x128 picture, about 486x304 map pixels; the screen at 16:9 actually sees about 486x273. At
40 it is about 6x6, and at 1000 about 77x47. **Nothing clips or wraps it**: near the map's edge it
runs off the picture. The second line object (+0x11C) is emptied every time and never given a point.
`confirmed`.

**Drawn with what.** `Graphics_CreateLineObject` (`0xA70160`) makes a 0x1138-byte screen-space line
object (`LineObject_Construct`, `0xACF7F0`) and hangs it on the interface tree. Its colour is
**(1, 1, 1, 1), white and opaque**, and the minimap leaves it at that. Its width is **1.0**, set by
the minimap on the object and on its `ID3DXLine` (SetWidth). It holds up to 500 points.
`LineObject_Draw` (`0xACF9F0`, slot 10) does `ID3DXLine::Begin`, `Draw(points, count, colour)` and
`End` - a polyline in screen pixels. `confirmed`, except that it is drawn by the interface tree's
walk, which is `inferred`.

## 3. The click

`CEU3Minimap::HandleMouse` (slot 1) **replaces GuiButton_HandleMouse and never calls it**:

- It acts only on a mouse event that is a **left press** on a shown minimap. Moves, releases and the
  right and middle buttons are left unhandled, so **there is no drag**: one press, one jump.
- rx = mouse.x - int(pos.x) and ry = mouse.y - int(pos.y). It acts only where **0 < rx < w and
  0 < ry < h**, strictly, so the picture's border row and column do nothing.
- x = (rx - 1) * (map width / w); y = (h - (ry - 1)) * (map height / h). The width and height are
  the map graphics owner's +0x60D4/+0x60D8, copies of CMap's.
- `MapCamera_JumpTo` (`0x63D3C0`): unless the camera is frozen (+0x356), x/y **and** x_settled/
  y_settled become the point, so there is no easing. **The height is left alone.**
- The event is marked handled, which takes it off the frame's list, so the map below never sees the
  press and the selection is untouched. No sound.

**Frozen** (MapCamera +0x356) is set each frame while a country view or a builder window is up
(`0x64FC27`/`0x64FC38`); UpdateMapCamera tests it too. `confirmed`.

**Tooltip**: none of its own. `GetElementTooltip` names some sixty elements, `mapmode_1`..`16` among
them (positive control), and no minimap element. With an element under the mouse,
`CInGameIdler::GetTooltip` takes the element path, so no province tooltip comes from the minimap
either. `inferred`: CInGameIdler_NamedElementTooltip, the last fallback, was not read, and which
element is "under the mouse" over the overlay was not read.

## 4. The day/night overlay

`minimap_overlay` is a scrollingSprite whose frame is the **hour of the day**: (CCurrentGameState
+0xBDC - 43,800,000) mod 24. **`CInGameIdler::HourlyUpdate`** (slot 52, `0x661BC0`) sets it. It is
called every hour, unconditionally, at the end of RunHourlyTick (`0x68240D`). Enter and
ReloadMenubar set it as well. `confirmed`.

The sprite draws with progress.fx's `ScrollTech`: `tex2D(tex0, u + CurrentState, v)` with wrapping
addressing, where CurrentState = (frame - 1) / step x an extent at +0x118 (`0xB1FE36`..`0xB1FE8B`).
So the night band slides a twenty-fourth of the texture across the minimap each hour. The formula
is `confirmed`. That the step is the .gfx `step = 24` and the extent the texture's u extent is
`inferred`.

## 5. The buttons

**Binding.** The CInGameIdler constructor makes sixteen 0x50-byte member-function glues
(`0x679650`), one per setter, at +0xD38 .. +0x11E8. `CInGameIdler::Enter` finds each button in the
`menubar` window (+0x134C, slot 13) and subscribes the glue to it (the button's +0x48 observer,
slot 1, `0x65DD11`..`0x65E53C`). A click runs that setter with the screen in ECX:

| button | glue | setter | mode | ShowButton | layer mask | style | other |
| --- | --- | --- | --- | --- | --- | --- | --- |
| mapmode_1 | +0xD38 | MapMode_Terrain_Set `0x666020` | 0 | 1 | 0xFFFF | 0 | +0x60F9 = 0, MapMode_Terrain_Colour |
| mapmode_2 | +0xD88 | MapMode_Political_Colour `0x666220` | 1 | 2 | 0xFFBE | 2 | |
| mapmode_3 | +0xFB8 | MapMode_Weather_Set `0x667300` | 11 | 3 | 0xFFBB | 0 | weather pictures on |
| mapmode_4 | +0x1008 | MapMode_Intel_Colour `0x667510` | 6 | 4 | 0xFFBA | 12 | |
| mapmode_5 | +0xDD8 | MapMode_Revolt_Set `0x666430` | 12 | 5 | 0xFFBE | 2 | |
| mapmode_6 | +0xE28 | MapMode_Diplomatic_Colour `0x6668C0` | 2 | 6 | 0xFFBA | 6 | |
| mapmode_7 | +0xE78 | MapMode_Region_Set `0x666AD0` | 3 | 7 | 0xFFBA | 8 | |
| mapmode_8 | +0xF18 | MapMode_Supply_Colour `0x666EE0` | 4 | 8 | 0xFFBA | 9 | +0x60F8 = 1, depot pictures |
| mapmode_9 | +0xF68 | MapMode_Infrastructure_Colour `0x6670F0` | 5 | 9 | 0xFFBA | 9 | |
| mapmode_10 | +0x1058 | MapMode_VictoryPoints_Recolour `0x667710` | 7 | 10 | 0xFFBA | 13 | |
| mapmode_11 | +0x10A8 | MapMode_Theatre_Colour `0x667920` | 8 | 11 | 0xFFBA | 14 | 0x667AE0 in place of the colouring |
| mapmode_12 | +0x10F8 | MapMode_Strength_Colour `0x667B50` | 9 | 12 | 0xFFBA | 15 | |
| mapmode_13 | +0x1148 | MapMode_Resources_Set `0x678400` | 10 | 13 | 0xFFAA | 20 | settings +0xE7 = **1** |
| mapmode_14 | +0xEC8 | MapMode_SimplifiedTerrain_Driver `0x666CE0` | 13 | 14 | 0xFFBA | 8 | |
| mapmode_15 | +0x1198 | MapMode_Air_Set `0x667EE0` | 18 | 15 | 0xFF9A | 18 | air icons and circles up |
| mapmode_16 | +0x11E8 | MapMode_Naval_Set `0x6680E0` | 19 | 16 | 0xFF9A | 19 | naval icons up |

Every setter has the same shape:

1. Unless the mode is already its own, the `click` sound where the sound system says `click` is not
   already playing (slot 25, then slot 9).
2. Leaving 18 takes down the air icons and circles; leaving 19 takes down the naval icons.
3. The screen's +0xD34 and CMap +0x2A90 take the mode.
4. MapMode_ShowButton(its button).
5. The settings' layer mask (+0xF0), map style (+0xF4) and +0xE7 are written.
6. The graphics owner's +0x60F8 is written; HideProvinceObjects98.
7. The mode's colouring runs, then Map_RefreshColourTextures(0); the graphics owner's +0x60DC = 1.

**The province tooltip needs nothing redone**, because it asks the mode each time it is built
(FINDINGS-mapmode.md). Which counters and pictures the layer mask hides was not read. `confirmed`
for the table, read off all sixteen setters.

**The pressed look.** `MapMode_ShowButton` sets every `mapmode_1`..`16` to frame 1, then
`mapmode_<n>` to frame 2 (the button's slot 18). The two frames are the two halves of the 52x20
sprite. Its number is the **button's**, not the mode's. Hover and press shading are buttonstate.fx's.
**No button is hidden, and only `mapmode_8` is ever greyed, in the Arcade game mode**: the names `mapmode_1`..`mapmode_16` are referenced only in
Enter's binding, in ShowButton and in GetElementTooltip, three references each. `mapmode_8` has a
fourth, in CInGameIdler::Update at `0x6568C8`: it greys `mapmode_8` every frame in the Arcade game mode, which has no supply network (`FINDINGS-frontend.md`, D.2). Otherwise `confirmed`.

**Tooltips.** GetElementTooltip answers `mapmode_N` with the localised **`MAPMODE_N`** as a
one-line tooltip, with **`MAPMODE_7G`** for `mapmode_7`: "Terrain Mapmode", "Political Mapmode",
"Weather Mapmode", "Intel Mapmode", "Revoltrisk Mapmode", "Diplomatic Mapmode", "Region Mapmode",
"Supply Mapmode", "Infrastructure Mapmode", "VP Mapmode", "Theatre Mapmode", "Strength Mapmode",
"Resources Mapmode", "Simplified Terrain Mapmode", "Air Mapmode", "Naval Mapmode". The buttons
declare no `shortcut`, so no "Shortcut:" line is added. `confirmed`.

**Keyboard.** No key selects a map mode. The .gui gives the buttons no shortcut, and
CInGameIdler_HandleInput's keys (FINDINGS-selection.md) include none. The zoom buttons have PAGE_DOWN
and PAGE_UP: `CInGameIdler::ZoomIn` takes a fifth off the camera's height wanted, down to 40, and
`ZoomOut` adds a fifth, up to 1000, each with the same `click`. `confirmed`.

## 6. Modes switched to by itself

`PushMapMode` (slot 98) puts the current mode on the front of a list; `PopMapMode` (slot 99) takes
the front one off and runs **that mode's full button setter**. Its table: 0, 14, 15, 16 and anything
above 19 go to terrain; **17 goes to the theatre setter (mode 8)**; the rest go to their own. So the
button is pressed again and the `click` plays when the mode changes. Three users, each with a push
and a pop:

- **14, placing a deployment**: SetDeploymentBeingPlaced (FINDINGS-buildingqueue.md B). The pop
  restores what was pushed.
- **15, the air orders window**: `CAirOrdersView::CAirOrdersView` pushes and calls
  **`CInGameIdler::SetAirOrdersMapMode`** (slot 100, `0x677380`): mode 15, style 16, mask 0xFFBA, no
  sound, **no ShowButton, no colouring** - the window paints the map itself (`0x867DB0`). Its
  destructor pops (`0x741688`).
- **17, the theatre editor**: **`CInGameIdler::SetTheatreEditing`** (slot 110, `0x666680`). Given a
  theatre headquarters it pushes and enters 17 (style 2, mask 0xFFBE, its own colouring
  `0x865290`), with no ShowButton. Given null it pops and posts the edited provinces for the
  headquarters' theatre. CInGameIdler_HandleInput calls it on Alt or Ctrl+R with one theatre
  headquarters selected.

None of 14, 15 and 17 calls ShowButton, so **the last button pressed stays down under them**.
`confirmed`.

**The tutorial** reaches the setters by name through **`CInGameIdler::DoTutorialAction`** (slot 81,
`0x64B2D0`, `ret 0x10`). For the key `mapmode` the value picks a setter: `terrain`, `political`,
`diplomacy`, `region`, **`culture` - the supply setter**, `theatre`, `strength`; any other value
does nothing. Its known caller, the unrecorded `0x8E4490`, passes `mapmode` and a page string, and
`tutorial/chapter1.txt` pages carry `mapmode = "terrain"` and `zoom = 200`. Slot 81 opens on the byte
after slot 80's (OnAlertClicked's) `ret 4` at `0x64B2CD`, with no padding - **a trap-2 pair**:
`retsBefore` from `0x64ACB0` shows `ret 4` up to `0x64B2CD` and `ret 0x10` from `0x64B3FD`. The
behaviour is `confirmed`; the tutorial reading is `inferred`.

## 7. The mode a game starts in

**Terrain (0), with `mapmode_1` down.** The CInGameIdler constructor calls MapMode_SwitchIcons(0) -
its only caller - and writes the terrain settings (mask 0xFFFF, style 0, +0xE7 = 0). Enter sets
+0xD34 and CMap +0x2A90 to 0 again (`0x65A605`) and calls MapMode_ShowButton(1) right after binding
the buttons (`0x65E588`). The in-game enter's refresh flags 0xB make the first frame's
CInGameIdler_RefreshMap run MapMode_Terrain_Set (mode 0, flags & 0xF, not exactly 2). A loaded game
is the same: nothing restores a mode. `confirmed`, every link read.

## 8. The map's tooltip stands on the minimap

`CInGameIdler::GetTooltip` (`0x6627D0`), with no element under the mouse and the mouse over the map,
places the province's tooltip at **the minimap's corner** - CInGameIdler +0x1920, the CEU3Minimap,
its slot 24 (CButton::GetPosition; `0x662B6A`-`0x662B81`) - **less (50, 20)** (`0x662B83`,
`0x662B89`), with `below` false. So the box stands above that point **wherever on the map the mouse
is**, pulled in only at the right edge. With nothing under the mouse it gives an empty tooltip at the
corner less (60, 20). +0x1920 is written only by Enter and ReloadMenubar, as the return of
CEU3Gui_CreateMinimap for `minimap_pic` (a resumed sweep of `.text` for the displacement).
`confirmed`. This is why the maintainer's screenshot shows the province tooltip standing over the
minimap.

## Not established

- What `CInGameIdler_NamedElementTooltip` answers for the minimap, and which element is hovered over
  it, the minimap or the overlay. The "no tooltip over the minimap" rule rests on these.
- Whether the overlay, created after the minimap, lets clicks through by its CIcon handler. The
  game's own behaviour says it must.
- The order the frame lines and the icons are drawn in, and the scrolling sprite's u extent.
- What the settings' +0xE7 governs. No reader was found next to a GetGameSettings call, and a reader
  through a held pointer would not show in that scan.
- Which counters and pictures each layer mask value hides.
- The menubar window's own show and hide, which takes the buttons and `minimap_bg_shadow` with it.
- The `+4` the air orders window's destructor switches on after popping: no writer was found in its
  constructor.
- ~~The fourth `mapmode_8` reference, in CInGameIdler::Update at `0x6568C8`.~~ Already read: the Arcade game mode greys it (`FINDINGS-frontend.md`, D.2).
- DoTutorialAction's arms other than `mapmode`, and its caller `0x8E4490`.
- The region, resources, naval and theatre-editor colouring routines. They were left to the map
  mode readers, as asked.

Frontier: 0x4E4490, 0x23D350, 0x465930, 0x4660E0, 0x4674E0, 0x465290, 0x267AE0, 0x66FCA0, 0x6B2770,
0x46AA70
