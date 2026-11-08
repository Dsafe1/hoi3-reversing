# Battle plans: drawing on the map

All addresses in this write-up are rvas. Everything below is `confirmed` off the decompilation unless it says `inferred`. No game was run. Tooltip texts are from `tfh/localisation/tfh.csv` (Windows-1252; §Y is the colour switch).

## 1. bp_settings.txt

`CBattlePlanManager` loads it as the window is built: `battleplans/bp_settings.txt`, from the install or the mod. Directory mode 1 uses the mod's folder. Mode 2 uses the mod's file where it exists, else the install's. The file is taken whole and never merged. A reload frees the settings object, so the current tool and options are lost (reader A's `BattlePlanManager_LoadToolSettings`, 0xE660).

Top level: the keys `tool_color`, `tool_arrow`, `tool_borders`, `tool_icons`. Any other top-level key is read and dropped, with no error.

Inside a tool block, the first key is read as `icon = <sprite name>`. If it is not `icon` it is consumed and the sprite name stays empty. Then come `option = { ... }` blocks in order; other keys there are read and dropped. Each new option records its position in the list (+8), the index used everywhere after.

An option's keys:
- Colour options: `name`, `red`, `green`, `blue`, each number through `ParseFixedPoint`, so thousandths. **`type` is not a key here.**
- Arrow, border and icon options: `name`, `type`. Border and icon options use the arrow option's loader.

A key not in an option's list is dropped silently by the CPersistent load path. Nothing validates that a `type` names an object type. Drawing with one that does not exist uses a type lookup with no null check, so presumably a crash; not read further.

The colour table: `BattlePlanToolSettings_PublishColours` copies each colour option to a global list (address 0x1B166DC, 0x1C-byte CColor records), r,g,b = thousandths / 1000, a = 1. That list is the palette the arrow, border and icon passes colour from. A colour index past its end is drawn magenta (1,0,1,1).

Shipped options, in order:
- Colours: `BP_TOOL_COLOR_RED`, `_GREEN`, `_BLUE`, `_YELLOW` = Red, Green, Blue, Yellow, values (0.84,0.15,0.15) and so on.
- Arrows: `ba_0`, `ba_1`, `ba_1b`, `ba_1c`, `ba_2`, then their `_dash` forms. Keys `BP_TOOL_ARROW_SLIM`, `_MEDIUM_1`, `_MEDIUM_2`, `_MEDIUM_3`, `_THICK`, and the `_DASHED` forms.
- Borders: `bb_0`..`bb_3` (`BP_TOOL_BORDER_1`..`_4`).
- Icons: `mi_0`..`mi_10` (`BP_TOOL_ICON_AIRPLANE`, `_TANK`, `_INFANTRY`, `_COMBAT`, `_BOMB_1`, `_BOMB_2`, `_PARADROP`, `_CARRIER`, `_BATTLESHIP`, `_SUB`, `_LANDING`).

The sprites each tool names are `GFX_bp_tool_color_option_icon` (4 frames), `GFX_bp_tool_arrow_option_icon` (10), `GFX_bp_tool_border_option_icon` (5, the fifth frame unused), `GFX_bp_tool_icons_option_icon` (11). A frame is the option's index + 1; the `.gfx` comment says the frames must match the options' order. The key `BP_TOOL_BORDER_5` exists in the table and is used by nothing.

## 2. The strip `tools`

Buttons in the window's order, tagged 0..6: `select`, `arrows`, `borders`, `icons`, `colors`, `text`, `erase`. Tooltips by tag, text as in the table:

| tag | tool | tooltip key | text |
| --- | --- | --- | --- |
| 0 | select | BP_TOOLTIP_TOOL_SELECT | "Click on object to select it." |
| 1 | arrows | BP_TOOLTIP_TOOL_ARROW | "Choose arrow type, and draw it on the map with §YLMB§!.\nHold §YShift§! + §YLMB§! to snap your arrow to another one." |
| 2 | borders | BP_TOOLTIP_TOOL_BORDER | "Choose border type, and draw it on the map with §YLMB§!." |
| 3 | icons | BP_TOOLTIP_TOOL_ICON | "Choose icon type, and draw it on the map with §YLMB§!.\nHold §YShift§! + §YMouse Wheel§! to rotate an icon." |
| 4 | colors | BP_TOOLTIP_TOOL_COLOR | "Choose current color to draw arrows and icons.\nAlso applies the color to any currently selected arrow or icon." |
| 5 | text | BP_TOOLTIP_TOOL_TEXT | "Place a text sign on the map.\nIf nothing selected - creates a new text.\nIf an arrow is selected - draws the text on the arrow.\nIf text sign selected - edits the text.\n§YShift§! + §YMouse Wheel§! to rotate the text.\n§YCtrl§! + §YMouse Wheel§! to scale the text." |
| 6 | erase | BP_TOOLTIP_TOOL_ERASE | "Delete selected object." |

An option entry's tooltip is its localised `name`.

A press (`CBattlePlanManager::OnToolPressed`):
- **erase (6)**: nothing unless a plan is chosen, is live (`CBattlePlan +0x1F0`) and is the player's. Then every selected arrow, border and sign is deleted. **The tool does not change.** The `.gui` gives `erase` the shortcut `DEL`.
- **Any other button**: `text` first prepares the edit box (section 7). Then the current tool becomes the tag and `UpdateToolStrip` runs. Pressing `colors` picks the colours tool and changes nothing else.

The tool starts as 0 (select) with every option at 0. The state lasts as long as the settings object, so it survives closing and reopening the window. The chosen tool is marked by the icon named `marker` over its button; marker is hidden if the button is missing.

**There is no greying.** `UpdateToolStrip`:
- `tools` is shown only when the tab is Current (`+0x34C`=0), a plan is chosen (`+0x390`) and live, the plan's country is the player's (`+0x3A4`), and no rename or save prompt is up (`+0x39D`). Otherwise the strip is hidden whole.
- `text_prompt_window` is shown only for tool 5.
- `options_window` is shown when the current tool has options (tools 1-4 have them; select, text and erase have none).

## 3. options_window and battleplan_tool_option_entry

The window creates as many entries as the longest option list (11) from the button type `battleplan_tool_option_entry`. Each is placed at:

    x = window_width + (column + 1) * (-33)
    y = row * 33

The pattern (-33, 33) comes from the entry's `.gui` position; 330 is the width. `row` runs 0..6, then `column` steps left: a right-aligned grid of 7 rows. The `.gui` comment says "Position here is used as an offset pattern".

For the current tool, its first N entries are shown with the tool's sprite and frame i+1, the rest hidden. The window's own `marker` sits on the entry of the option remembered for that tool (one index per tool, `settings[tool+1]`), hidden if out of range. A press (`OnToolOptionPressed`) stores the entry's tag as that tool's index. With the colours tool it also writes the colour's index onto every selected arrow and border (+0x154) and icon (+0x140), and marks the plan dirty. **A text sign is not recoloured.** Choices are remembered between tools, and until the settings object is rebuilt.

## 4. The mouse on the map

`BattlePlanManager_Update` (0x12AA0; A's name) runs once a frame from `CInGameIdler::Update`, before `CInGameIdler_HandleInput` and `UpdateMapCamera`. It needs the window visible, the Current tab, and a live plan of the player's chosen. Its coordinates come from `GraphicsView::PickGroundPoint`: the mouse ray intersected with the plane y = 0, camera-relative. In map pixels, a world point is pick + camera (x_settled, y_settled). No snapping to provinces (*inferred* only in that map pixels comes from the saved values). World x is the map's x and world z the map's y.

**Which inputs stay live.** For tools 1, 2, 3, 4 and 5, and for tool 0 with Ctrl or Shift held, every left-button event is marked handled, so the idler does not see it. Plain select leaves left clicks for the map as well as for the plan. Right-button events are never touched, so right clicks and orders keep working. Wheel events (event kind 4, inferred to be the wheel, per FINDINGS-selection) are marked handled in tools 0, 3 and 5 with Ctrl or Shift. Other wheel use and all scrolling stay live.

Note the select tool: its click logic runs whether or not the event is consumed. Colors (tool 4) eats left clicks and does nothing with them.

Starting a drawing needs a left press not already handled by the interface. Holding the button is read from the input object.

**Modifiers.** Ctrl is keyboard slot 12, Shift slot 10.

**Wheel values.** The wheel is the input object's counter (slot 20); a change of the counter gives +1 or -1.

**Shift + wheel** in tools 0, 3, 5: `settings+0x104 += 0.15 * sign` (a rotation in radians). Selected: in the select tool, the first selected icon and the first selected text are set to it.

**Ctrl + wheel** in tool 5, or tool 0 with a text selected: `settings+0x108 = clamp(+0.75 * sign, 0.25, 20)` (the size). In tool 5 with `placing_text` it only affects the preview; otherwise selected texts are relaid at the new size and the plan is dirty. It starts at 2.0.

**Arrows (1).** Left press: `BattlePlan_BeginArrow`: deselect all, make the object from the current option's `type`, colour from the colour tool's choice (index `settings[5]`), object position = camera position. Shift at the press: `SnapToNearest` (section 6). While held, each frame `AddPoint` with `Q = (camera - object origin) + pick`. On release: `SmoothPoints`, kept in the plan's list, selected, the in-progress slot cleared, plan dirty.

**Borders (2).** The same, no snapping.

**Icons (3).** Press makes the object; while held its object transform is the camera at the moment and its position in it is the pick, rotation = `settings+0x104`. Release keeps it and selects it.

**Text (5)**, with placing on: a preview object (plan `+0xC`) is made and each frame follows the mouse with the settings' text, size and rotation. A left press drops it on the plan (selected) and the next frame makes another; manager `+0x3A8` is the wait for release. If the tool stops being text the preview is destroyed and placing turned off.

**Select (0).** A press records the pick (`settings+0x20` and `+0x24/+0x28`). On release, if the distance from the press is at most 5.0 map units, the selection is cleared and `BattlePlan_HitTest` runs.

**Hit test** (`BattlePlan_HitTest`, tolerance 1.25, camera-relative coordinates):
1. Icons and text signs in list order: a sign with text is hit within 1.25 * length(text) * size * 0.25 of its point (`+0x168/+0x16C` plus object origin); an icon within 1.25 * type scale * 0.5. The first hit is selected and the test ends.
2. Arrows: only the control points are tested, squared distance under 31.25, the nearest wins; its label is selected with it.
3. Borders likewise, starting the threshold again.

There is no drag-move anywhere. Only one thing is selected at a time from the click path.

**A click on empty map** in select clears the selection. Selected things pulse; nothing deletes them but `erase`, and `apply` for an emptied text.

## 5. What each drawing holds

Units: world map pixels, stored as float. A shipped `.pln` writes the control points in integer thousandths (one thousandth of a map pixel), e.g. `-3785 1262`. In the plan `matrix_transforms` holds each object's origin (its transform's translation) in thousandths; the object's local points are relative to that.

Arrow or border (BattleArrowObject):
- type (`battlearrow` name)
- points: first point is the origin of the stroke
- colour (index, saved `color`)
- `ignore_smoothing` (the +0x158 snap count, -1 usually)
- selected (not saved)
- world origin (saved `matrix_transforms`)
- arrow label text (`text`, parallel vector, saved in the arrow's own record)

Border and arrow records are identical; borders have `text` too but none is ever set.

Icon (MapInfoObject): type (`mapinfo` name), `positions` = the point, `matrix_transforms` = origin, `color`, `rotation` in radians (written as integer radians * 1000, e.g. `-2850`).

Text sign: `positions`, `matrix_transforms`, `text`, `scale` (the text size * 1000), `rotation`; no colour in the file (saved list has no color for texts), and the object's colour stays 0, so **every text is drawn in the palette's first colour (red with the stock file)**.

Counts: the `arrows_count`, `icons_count`, `texts_count`, `borders_count` keys. **No maximum was found in any of the code read.**

Snapping: `SnapToNearest` copies the leading points of the nearest other arrow up to the nearest point, sets `+0x158` = that index - 1 and `+0x15C` = its point count, and takes its transform. `+0x15C` is not saved.

## 6. Arrow mesh and the arrow strokes

**Adding points** (`AddPoint`): the first point is pushed twice. Thereafter: if |Q - P[n-2]|^2 > 25 (5 units), push a new point. Then always P[n-1] = Q. So the last point follows the mouse and points are left about 5 units apart.

**Smoothing on release**, if more than 2 points: for i from 1 (or `+0x158` if not -1) to n-2, using the old values, P[i] := 0.25 P[i] + 0.75 (P[i-1] + P[i+1]) / 2. First and last stay put. A loaded plan never gets the smoothing.

**Spline**, `BuildMesh` → `CatmullRomSamples`: skip the last point if the last segment is shorter than sqrt(0.05) (tail 2 instead of 1). Segments `s = n - tail`, samples `s*4+1`. For segment i with `P0=P[i]`, `P1=P[i+1]`, `P-1=P[i-1]` (or the mirror 2P0-P1 at the start), `P2=P[i+2]` (or 2P1-P0 at the end), at t = 0, .25, .5, .75 (t = 0 only on the first segment, t = 1 only on the last):

    p = 0.5 * ( P-1 (2t^2 - t^3 - t) + P0 (3t^3 - 5t^2 + 2) + P1 (4t^2 - 3t^3 + t) + P2 (t^3 - t^2) )

No arrow is built unless the sample count exceeds 4 (with n = 2 that needs a tail of 1). So a two-point stroke draws, a degenerate press with coincident points does not.

**Mesh.** Per sample k = 1..N (0-based sample index k-1 in the array S below):
- Tangent T from S[k-1 clamped to 0-based index max(k-2,0)] to S[min(k, N-1)], normalised; normal `N = (T.y, -T.x)`.
- **progress** = (k-1)/(N-1) normally; if `+0x158` is set, for the first `+0x158 * 4` subdivisions progress = (k-1)/(parent_points*4 - 1) and thereafter progress = base + (k-1-prefix)/(N-prefix-1) * (1-base), base = prefix/(parent_points*4 - 1).
- Width `w = start + progress * (stop - start)` (`start`, `stop` from the type; these are half-widths).
- Two vertices: `S + N w` with uv (u, 0, 0) and `S - N w` with uv (u, 1, 0).
- `u` is arc length so far / `textureloop` when `textureloop` != 0 (accumulated from sample to sample), otherwise it is progress.

Head: four vertices at the last sample S with the last normal N and tangent T: `S + N*y`, uv (0,0,1); `S - N*y`, uv (0,1,1); `S + N*y + T*x`, uv (1,0,1); `S - N*y + T*x`, uv (1,1,1). `y` is the type's `y`, `x` its `x`.

The body is drawn as a triangle strip of 2N vertices (count-2 triangles), then the head as a strip of 4 at offset 2N. Vertex format: float2 position, float3 (u, v, isHead), 20 bytes.

Borders are the same object and mesh with `x`=`y`=0 and `nofade`.

## 7. Text and icon rendering; the prompt

**Text prompt.** On pressing `text`: if an arrow is selected, the box gets its label (empty if none) and placing is off. Otherwise if a text is selected, the box gets its text and placing is off. Otherwise the box and `settings+0xE8` become "New Text" and placing is on. The edit box then refreshes and its `clicked` byte (+0x40) is set to 1 (*inferred* intent: focus). The box is a normal edit box: maximum **250 bytes**, no refused characters (only the console's box has any; see FINDINGS-editbox).

**`apply`** (`OnApplyText`, reader A's 0x100E0):
- A selected arrow gets the text as its label (empty removes it).
- Otherwise a selected text gets it (empty deletes the sign and the tool returns to select).
- Otherwise, with nothing selected: an empty box returns the tool to select; else the text is stored for the next placed sign.

**A sign's text** is laid out by `MapInfoObject::SetText`: 6 vertices a glyph, through `BitmapFont_LayOutTextQuads` with origin (x, 0, z), up (0,0,1), along (1,0,0), `scale` = the size, width limit 100000 (never wraps), the glyph's font pixels * 0.05 * size in map units. Layout is centred on x and stands on z. Font: `allies_country` (the type has no font key).

**An arrow's label** (`BattlePlan_SetArrowLabel`) is a `mi_text` object with the arrow's transform and selected state. Font: the arrow type's `font` (`allies_country` in the file). Size: the type's `scale`. The text is bent along a copy of the arrow's path: reversed first if the path runs more westward than eastward (`BattlePlan_ReversePathIfWestward`), starting at control point `skip` = 5, or `+0x158 + 5` when a snap prefix is set and the path was not reversed. Each glyph is placed by the middle of its width along the path's samples, oriented on the local tangent.

**Icon quad**: 16 bytes a vertex, four corners at (x +/- s, y +/- s), uv 0..1 with the v flip, s = `scale` * 0.5.

## 8. The render pass

Visibility per frame (`CInGameIdler_Render`): a plan's layer draws only when (manager `+0x3B8`, the menu toggle, or the window is shown) and the plan's visibility flag (+0x1CC) is set. No map-mode check and no zoom range exist in this code; IsVisible is only the object's Show flag. The world position is local + object origin.

Order: map scene, hierarchy lines, unit layers (counters), selection box, each visible plan's layer draw (queuing objects into per-colour lists; the generic object-layer draw walks them), `BattleArrows_DrawAll`, `MapInfo_DrawAll`, then the interface. Depth test on, depth write off (per the effects), height 0.5, no terrain conforming.

`BattleArrows_DrawAll`: per colour list, technique **BattleArrow** of `gfx/FX/battlearrow.fx`, 2 passes per arrow: body, then head. Parameters: `WorldViewProjectionMatrix`, `CameraPosition` (settled), `ArrowColorAlpha` (the list's colour), `ArrowTransparency` (1, or for a selected object `0.25*(sin t + 1) + 0.5`, t in seconds), `NoFade` (from the type), `BodyTexture`, `HeadTexture`. The stencil is cleared between colour lists. In the effect: stencil func Equal with ref 0, pass Incr, separately per pass, so within one colour list each pixel is painted once by pass 0 (fill: requires tex g>0) then pass 1 (outline: tex r>0) only where the fill did not. Body textures wrap on U; head clamps. Non-`nofade` fade: alpha * (isHead + (1-isHead) * max(saturate((u-0.05)*5), 0.1)), and the head's alpha lifted x1.3. Point filtering on the body, linear on the head.

`MapInfo_DrawAll`: per colour list, technique **MapInfo** (icons) then **MapInfoText** (texts) of `gfx/FX/mapinfo.fx`. `ArrowColorAlpha` the colour; `IconTransparency` 1, or for a selected icon `0.25*(sin t + 1) + 0.5`, a selected text `0.5*(sin t + 1)`; `IconRotation` from +0x1C4, rotating about (x,y) in the vertex shader; `IconPosition` (x,y). Text is always textured from the font `allies_country`'s page. Icons: texture of the type, `SrcAlpha/InvSrcAlpha`, no stencil.

Textures and types: `tfh/gfx/battlearrow/battlearrow.dds`, `battlearrow2.dds`, `battleborder.dds`, and the icons `plane`, `tank`, `infantry`, `combat`, `bomb`, `paradrop`, `carrier`, `battleship`, `sub`, `landing`. The fill/outline separation lives in the textures' red and green channels (per the effect).

Files read and what each key is used for:
- `tfh/interface/battlearrow.gfx` battlearrow: name, textureFile (body), textureFile1 (head), start, stop, x, y, font (label only), scale (label only), textureloop (the `*_dash` and border types), nofade (borders).
- mapinfo: name, textureFile, scale (the icon's side; 8-26 in the file). `mi_text` is a bare mapinfo whose scale goes unused.
- `tfh/interface/battleplansinterface.gfx`: the `bp_tool_*` strip and option sprites, the marker, the panel backgrounds.

Unused or left over: `GFX_bp_tool_border_option_icon`'s frame 5 and the key `BP_TOOL_BORDER_5`; `bp_settings.txt`'s header comment says "For type definitions see: interface/battlearow.gfx" (a typo for battlearrow).

## 9. Not established

- What a `type` name not in any `.gfx` does beyond a null type (no crash path was followed).
- Slot 6 of the four tool option classes' tables differs among them and was not read; they are folded shared bodies and nothing in the code read calls them for battle plans.
- The depth comparison of the arrow plane against the rendered map objects was not measured; it is ZENABLE true with the map's depth buffer.
- The saves held no plan drawings to set anything against; the shipped `.pln` files were the oracle, and they agree in every key and its unit.
- The generic layer draw `MapObjectGroup_Draw` (rva 0x6716D0) is called for each plan layer; whether it culls by the view frustum was not read for these objects.
- Reader A owns the plan list: the visibility buttons, the `menubar_plans_toggle` (+0x3B8), and the plan file and command paths.

Frontier: 0x66B9C0, 0x66B7B0, and the sort at 0x6685B0 used to order each colour list (its comparison was not read).
