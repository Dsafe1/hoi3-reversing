# The hierarchy lines on the map, and the key that switches them

*Read 2026-10-09 for OpenHOI3, after the maintainer's word that the original draws "hierarchy
lines and highlight" for a selected unit and that "they can be toggled with h". Static reading
of `hoi3_tfh.exe`; every address is a VA of this build. `confirmed` unless a line says
otherwise.*

**In one line.** With the setting `render_hierarchy` on, the game screen keeps one mesh for
the first selected land unit: a textured band from that unit to the unit commanding it, and
from every unit below it, at any depth, to its own commander - coloured by how far below the
selected unit each is, as wide as its rank, with arrowheads running down from the commander.
Apart from the setting, the counters of every unit under the selected one wear a ring of
their own colour (section 6).

---

## 1. The setting and the key

`render_hierarchy` is a key of `CMapRenderingOptions` (`CMapRenderingOptions::LoadKey`,
`0x45F630`), which sits in the settings object at `+0xDC`. The loader's nine cases give the
whole block:

| key | in the options | in the settings |
| --- | --- | --- |
| `renderTrees` | `+0x8` | `+0xE4` |
| `simpleWater` | `+0x9` | `+0xE5` |
| `waves` | `+0xA` | `+0xE6` |
| `render_hierarchy` | `+0xC` | **`+0xE8`** |
| `show_unit_names` | `+0xD` | `+0xE9` |
| `onmap` | `+0x1C` | `+0xF8` |
| `alwaysCounters` | `+0x1D` | `+0xF9` |
| `counter_distance` | `+0x20` | `+0xFC` |
| `counter_scale` | `+0x24` | `+0x100` |

That settles two things `FINDINGS-counters.md` left open: `+0xE9` is `show_unit_names` and
not merely likely, and `+0xF9`, recorded as `counters_when_near`, is **`alwaysCounters`**.

**The H key flips it.** In the game screen's key handler (`0x652540`), at `0x6537D2`:

    cmp cl, 0x68                      ; 'h'
    jne ...
    call GetGameSettings
    cmp byte ptr [eax+0xE8], 0
    sete cl
    mov byte ptr [eax+0xE8], cl

Nothing else: the mesh is made or dropped on the next update. A third reader, `0x6F810F`
inside `0x6F80A0`, writes the byte from the settings menu's `hierarchy_checkbox`
(`SM_HIERARCHY`, "Show hierarchy on map"); `inferred`, from the store and the menu's file.

## 2. Whose hierarchy, and when it is made

The object is 0x40 bytes with no table of its own, made as the game screen is built (the
store at `0x649334`) and kept at **`CInGameIdler +0x1DE0`**:

| | |
| --- | --- |
| `+0x00` | a vector of 8-byte records, a unit and its province: what the mesh was built from |
| `+0x10` | the commander of the unit the mesh was built for |
| `+0x14` | a byte: there is a unit to draw for |
| `+0x18` | a float: the picture's phase |
| `+0x1C` | the mesh: vertex buffer, index buffer, declaration, and its counts |

`CInGameIdler::Update` (`0x6565A8`..`0x65664B`), every frame, with the setting on:

    unit = the first of the selection whose slot 1 answers 0        ; a land unit
    lines->+0x14 = (unit != null)
    if (!HierarchyLines_IsCurrent(lines, unit))
        HierarchyLines_Rebuild(lines, unit)

`HierarchyLines_IsCurrent` (`0x883800`) walks the same units the build would and compares each
with the records kept - the unit and the province it is in - so **the mesh is made again when a
unit of it moves to another province, or the selection or the order of battle changes**, and
not otherwise.

## 3. Which lines: `HierarchyLines_Rebuild`

`0x883890` `(lines, unit)`. It counts first (`0x8829F0` for a unit, `0x883AB0` down the
tree), makes a vertex buffer of four vertices a line at 0x18 bytes each and an index buffer of
six indices a line, and fills them with `HierarchyLines_AddBelow` (`0x883AF0`), which calls
`HierarchyLines_AddUnit` on a unit and then itself on each of the units under it
(`CUnit +0x1E4`).

`HierarchyLines_AddUnit` (`0x882A70`, the unit in EAX) adds a line for a unit when:

    it is a land unit (slot 15)
    it is aboard neither a fleet nor an air unit (its slot 9 object's +0x300 and +0x304)
    it has a commander (CUnit +0x1E0)
    the commander, where a land unit, is aboard nothing either
    the commander is in another province

and the line runs **from the unit's province's unit point to the commander's**
(`CProvinceTemplate +0x64/+0x68`, the two integers) with `CUnit::IsOutOfRadioRange` of the
unit as its last argument. The walk starts at the selected unit itself, so its own line up to
its commander is among them.

## 4. One line: `HierarchyLines_AddLine`

`0x882B30`, the build's context in ESI, the unit in EDX, the two points and the flag on the
stack.

**The colour**, ARGB, by where the unit stands under the selected one (`0x882B36`..`0x882B8A`):

| | colour | |
| --- | --- | --- |
| out of radio range | `0xFF800000` | dark red, whatever its place |
| the selected unit itself | `0xFF007800` | green: its line up |
| its commander is the selected unit | `0xFF1432C8` | blue |
| its commander's commander is | `0xFF6464D2` | a paler blue |
| further down | `0xFFC8C8C8` | grey |

**The width**: half of it is `(GetCounterSize + 1) * 0.2` map pixels - the same seven-way
switch on `oob_level` as the counter's size mark (`FINDINGS-counters.md`, section 3), so a
division of several brigades has a line 0.8 wide, a corps 1.2, an army 1.6, an army group 2.0
and a theatre 2.4. (The 0.2 is the double at `0x160A260`.)

**The four vertices**, each `x, y, u, v, range, colour`:

    d      = to - from, with to.x moved by the map's width where |d.x| is over half of it
    across = (d.y, -d.x) * halfWidth / |d|
    from - across   u 0   v 0
    from + across   u 1   v 0
    to   - across   u 0   v |d| / (2 * halfWidth) * 0.2
    to   + across   u 1   v the same

`range` is 1.0 for a line in reach and 0.0 for one out of it.

## 5. The picture and the drawing

`HierarchyLines_LoadShader` (`0x883290`) loads the effect `gfx/FX/hierarchy.fx` with the
technique `Hierarchy` and the texture `gfx/mapitems/hierarchy_line.tga`. The effect ships as
text, so what it does is not a reading:

    u = u * 0.5 + 0.5 - 0.5 * range          ; range 1: the left half of the picture, 0: the right
    v = v + Time * 0.03 * range              ; the left half slides, the right stands
    colour = picture * the vertex's colour

and the picture is 64 by 64: **arrowheads in a band in its left half, a broken line in its
right**. So a line in reach is a band of arrowheads in its colour, running from the commander's
end to the unit's, and one out of reach a still, broken, dark red line.

The game screen's frame routine (`0x656E10`, at `0x657061`..`0x657150`) draws it when all of
these hold:

    the object exists and render_hierarchy is on
    alwaysCounters is on, or the camera is higher than counter_distance
    the camera is lower than 500
    lines->+0x14

It then adds to the phase - the frame's time where that is over 0.2 seconds, and **0.2
otherwise, so 0.2 a frame** - takes 100 off it once it passes 100 (three whole pictures at the
effect's 0.03, so nothing jumps), and calls `HierarchyLines_Draw` (`0x883030`), which sets the
effect's `WorldViewProjectionMatrix`, `LineTexture` and `Time` and draws the mesh **twice with
two values of `CameraPosition`** - `inferred` to be the two copies of the map either side of
its seam.

## 6. The highlight: the rings of the units under the selected one

**Every unit under a selected unit wears a ring in the counter type's `color2`**, at any
depth. It was missed at first and found on the maintainer's word, with a screenshot, that "in
the original the subordinate units also get the white counter ring (regardless of if the
higher unit is ai or not)".

A counter's ring is the word `CCounterObject::SetSelection` stores: 0 none, 1 white, 2 the
type's `color1`, 3 its `color2`. Three routines set it, all through an avatar's two counters
(`CHoiAvatar +0x140` and `+0x13C`):

| | | ring |
| --- | --- | --- |
| `CUnit::OnSelected`, slot 4 (`0x5C05F0`) | the unit | 1 |
| | `CUnit_SetRingBelow(3, its units)` | **3 for every unit under it** |
| `CUnit::OnDeselected`, slot 5 (`0x5C0B30`) | the unit, and `CUnit_SetRingBelow(0, ...)` | 0 |
| `CInGameIdler::ShowSelection`, slot 32 (`0x668780`) | the selected unit, where it is the player's | 1, or **2 where an AI agent commands it or a unit above it** |

`CUnit_SetRingBelow` (`0x5C0580`, `(state, list)`) walks a list of units and, for each that
is **not itself selected** (the byte at `CUnit +4`), sets both its counters and goes on into
its own list (`+0x1E4`) where that has any.

So: the selected unit white, or green where an AI commands it; everything under it the pale
blue-green of `color2`, which `mapitems.gfx` gives as `0.28 0.8 0.82` against `color1`'s
`0 1 0`; and a unit under it that is selected too keeps its own. The rings are given when a
unit is selected and taken back when it is not - a unit attached under it in between has none
until then. They do not depend on `render_hierarchy`.

**The screenshot fits to the colour**: the headquarters selected in it wears green - an AI
commands it in that game - and the three counters under it, two in its own stack, the pale
blue-green. The maintainer calls that one white; it is `color2`, pulsing as every ring does.

**Why it was missed**: the first search was for a literal 3 pushed beside a fetch of slot 23,
within sixteen bytes. Here the 3 is pushed for `CUnit_SetRingBelow`, which hands it on as a
variable, so there is no literal beside the fetch. Looking instead for every fetch of the
slot off an avatar's two counters found the three routines at once.

## What was not read

- the rest of `0x652540`, the key handler, and of `0x668780`, which goes on to an AI-commanded
  unit's objectives and its `AutomationArrow`s;
- `0x6F80A0`, the settings menu's side;
- why `HierarchyLines_Draw` draws twice, beyond the two camera positions;
- the rest of `CUnit::OnSelected`, which was read for the rings only.
