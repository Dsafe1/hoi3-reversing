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
    (the commander's own aboard test is not made: the code asks the unit's slot 9 a second time - section 7.2)
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

    d      = to - from, after moving whichever end is further east a map width west where they are more than half the map's width apart (section 7.2)
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

It then adds to the phase the seconds since the previous frame's Present where those are over 0.2, and **0.2
otherwise, so in practice 0.2 a frame**, takes 100 off it once it passes 100 (three whole pictures at the effect's 0.03,
so nothing jumps), and calls `HierarchyLines_Draw` (`0x883030`). That sets the effect's `WorldViewProjectionMatrix`
(view × projection), `CameraPosition`, `LineTexture` and `Time`, and draws the mesh **twice: once where it is and once
with `CameraPosition.x` less the map width, a map width to the east**. There is no copy to the west (section 7.4).

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

## 7. The lines through hierarchy.fx, whole

*Read 2026-11-07, by a delegated agent (fragment `interface-hierarchyfx.json`), so that another program can draw the lines
through the install's own `hierarchy.fx`, fed exactly as the original feeds it. Static reading; addresses are VAs unless
marked rva. **[exe]** hardcoded, **[mod: file]** a file can change it. `confirmed` unless a line says otherwise.*

**Corrections, rather than additions**: the phase grows by the seconds since the previous frame's Present or 0.2, so in
practice 0.2 a drawn frame, not by "the frame's time" (7.4); the second draw is a map width **east** only, not two copies
either side of the seam (7.4); AddLine's seam moves whichever end lies further east a map width west, not to.x (7.2); the
"commander aboard nothing" test does not exist (7.2); and `HierarchyLines_LoadShader`'s old `no_signature` (EBX read before
written) was wrong - it is `void __stdcall (CGraphics*)`.

### 7.1 Loading: `HierarchyLines_LoadShader` (`0x883290`)

Two callers: LoadEverything (`0x6319D9`) and `0x43BBBE` (not read). It takes the CGraphics on the stack (`ret 4`; EBX is
saved and zeroed, not an argument) and keeps it in `g_HierarchyGraphics` (`0x1A8CB5C`). Then:

- **The vertex declaration**, from the static list at `0x170ABD8` (CreateVertexDeclaration, device slot 86), into
  `0x1A8CB40` [exe]; on failure the message box "CreateVertexDeclaration failed!! (HierarchyVertexDecl)" and exit.

  | stream | offset | type | usage |
  | --- | --- | --- | --- |
  | 0 | 0 | FLOAT2 | POSITION0 |
  | 0 | 8 | FLOAT3 | TEXCOORD0 |
  | 0 | 20 | D3DCOLOR | COLOR0 |

  Stride 24, exactly hierarchy.fx's `VS_INPUT`: `float2 vPosition`, `float3 vUV_Range`, `float4 Color`.
- **The effect** `/FX/hierarchy.fx` under the key `Hierarchy`, its path built from the game's directory settings as the
  other map effects'; it goes through `FxHandler_Reload` first and then `FxHandler_Register`, so loading again (the second
  caller) recompiles it; into `g_HierarchyEffect` (`0x1A8CB44`).
- **The handles, by name**: `WorldViewProjectionMatrix`, `CameraPosition`, `LineTexture`, `Time` and the technique
  `Hierarchy` (`0x1A8CB48`..`0x1A8CB58`).
- **The texture** `/mapitems/hierarchy_line.tga`, registered with the graphics' texture handler (`0xA60F30`) into
  `0x1A8CB60`; TextureHandler_LoadFile opens it as **`gfx/mapitems/hierarchy_line.dds`** wherever that exists
  (`FINDINGS-textureload.md`), and the install has only the `.dds`: 64×64 A8R8G8B8, 7 mips [mod: gfx/mapitems]. Left half
  (u 0..0.5) a white band with black edges and a dark notch, two arrowheads a picture, tips at rows 9 and 41, pointing
  towards row 0 (v = 0); right half (u 0.5..1) a white dashed band, opaque on rows 0..26 and 45..63, clear on 27..44.

### 7.2 The mesh: `HierarchyLines_Rebuild` (`0x883890`) and `HierarchyLines_AddLine` (`0x882B30`)

The object at `CInGameIdler +0x1DE0` is a 0x40-byte `HierarchyLines`; its mesh (`+0x1C`, a MeshBuffer) is made whenever
the walk changes (section 2): four vertices a line in a vertex buffer (stride 0x18, FVF 0, not dynamic) and six 16-bit
indices a line, both in the **managed pool**; a **triangle list** (the mesh's kind, `+0x3C`, is 0 from construction and
never written); the declaration above. The lines are counted first by `HierarchyLines_CountUnit` (`0x8829F0`) and
`HierarchyLines_CountBelow` (`0x883AB0`) with exactly AddUnit's tests, so the buffers are filled exactly.

**Order**: the walk's - the selected unit first, then depth first down the `+0x1E4` lists in list order. With depth off and
blending on, a later line draws over an earlier one.

**Which lines**: a unit gets one when it is a land unit, its own slot 9 object is aboard neither a fleet nor an air unit,
it has a commander, and the commander's province (`+0x130`) is not its own. **Correction to section 3**: there is no
"commander aboard nothing" test - where the commander is a land unit, the code at `0x882AC8`..`0x882AEA` asks slot 9 of the
*unit* again (`mov ecx, esi`), which has already answered; the counter tests no commander either, so the two agree.

**The two ends**, integers turned to floats: `f` (from) the unit's province's unit point (`CProvinceTemplate
+0x64/+0x68`), `t` (to) the commander's.

**Colour (ARGB) and range** [exe]:

| | colour | range |
| --- | --- | --- |
| out of radio range | `0xFF800000` | 0.0 |
| the selected unit itself | `0xFF007800` | 1.0 |
| its commander is the selected unit | `0xFF1432C8` | 1.0 |
| its commander's commander is | `0xFF6464D2` | 1.0 |
| further down | `0xFFC8C8C8` | 1.0 |

**Half width** `w = (float)((double)(size + 1) × 0.2)` [exe], the size from the **unit's own** `oob_level` through the jump
table at `0x883010`: theatre 5 (w 1.2), army group 4 (1.0), army 3 (0.8), corps 2 (0.6), division with more than one
brigade (`+0x40 > 1`) 1 (0.4), a division otherwise 0 (0.2), navy 1, air 0 - only land units get lines.

**The seam** (correction to section 4), W the map width (`CMap +0x2A74`), W/2 computed once per process (`0x1BEB714`):
where `t.x − f.x > W/2`, `t.x −= W`; else where `f.x − t.x > W/2`, `f.x −= W`. Whichever end lies further east is moved a
whole map width **west**, so a line across the seam hangs off the map's west edge.

**The vertices**, each `(x, y, u, v, range, colour)`, `d = t − f`, `L = sqrtf(d.x² + d.y²)` (CRT sqrt, rounded to float),
`a = d × (w / L)`, **`V = L / (2w) × 0.2`** [exe]:

    0: (f.x − a.y, f.y + a.x, 0, 0)
    1: (f.x + a.y, f.y − a.x, 1, 0)
    2: (t.x − a.y, t.y + a.x, 0, V)
    3: (t.x + a.y, t.y − a.x, 1, V)
    indices: n, n+1, n+2, n+1, n+3, n+2

So v is 0 at the **unit's** end and grows **by length** towards the commander, one picture every `10w` map units and an
arrowhead every 5w; u 0 on the side left of the unit-to-commander direction, seen from above with north up (map y grows
north). Seen so, both triangles wind counter-clockwise, which CULLMODE CCW would remove - the visible lines show the cull
mode is not CCW there, agreeing with `FINDINGS-mapdraw.md` C.1's NONE (*inferred*). The arithmetic is double, rounded to
float at each store, as the other map code.

### 7.3 The shader's view of it [mod: gfx/FX/hierarchy.fx]

The vertex shader places a vertex at `(x − CameraPosition.x, 2.0, y − CameraPosition.y, 1)` and multiplies by
`WorldViewProjectionMatrix`: **a flat ribbon in the horizontal plane, 2.0 world units up** (the land at 0.35, the sea at
−0.32), its width in **map units**, not facing the camera. u becomes `u × 0.5 + 0.5 − 0.5 × range` - the left half of the
picture in reach, the right half out of it; v becomes `v + Time × 0.03 × range`; the pixel `tex2D(LineSampler, uv) ×
Color`, Color the D3DCOLOR as `(R, G, B, A) / 255`; the sampler WRAP/WRAP, MIN/MAG LINEAR, MIP NONE. As sampled v grows
with Time the picture moves towards smaller v, towards the unit, as the arrowheads point: in reach a band of arrowheads in
its colour running from commander to subordinate; out of reach a still, dashed, dark red line.

### 7.4 The draw: `CInGameIdler_Render` (`0x656E10`) and `HierarchyLines_Draw` (`0x883030`)

`CInGameIdler_Render`, once a frame at the end of `CInGameIdler::Update` (`0x656756`): BeginScene and Clear (grey, depth
1.0); MapGraphics_DrawScene (`FINDINGS-mapdraw.md` C.1); `0x8482F0` on `+0x1DDC` (another effect's list of meshes, not
read; it sets only ZWRITEENABLE 0 and ZENABLE 0); **the hierarchy lines** (`0x657061`..`0x657152`); the unit layers
(`0x641950`) - so **the counters are drawn over the lines**; later draws not read; EndScene and Present.

**The gates**, all of: the lines object exists (`+0x1DE0`); `render_hierarchy` (settings `+0xE8`); `alwaysCounters`
(`+0xF9`), or the camera's height (MapCamera `+0x348`) **strictly above** `counter_distance` (`+0xFC`); the height
**strictly under 500.0** [exe, the double at `0x160A538`]; the object's `has_lines` (`+0x14`).

**The phase** (`HierarchyLines +0x18`, 0.0 when made, never reset), each frame that passes the gates, before the draw:

    step  = g_RenderIdleSeconds > 0.2 ? g_RenderIdleSeconds : 0.2f
    phase = (float)((double)phase + step)
    if (phase > 100.0) phase = (float)(phase − 100.0)

`g_RenderIdleSeconds` (`0x1BEA47C`) is written at the head of the render: the render's own clock (`CInGameIdler +0x1934`, a
CHighPerfWinClock in seconds) less `g_RenderEndTime` (`0x1BEA484`), the same clock read **after the previous frame's
Present** - the update in between, not the whole frame. **Correction to section 5**: that is normally a few milliseconds,
so the step is **0.2 a drawn frame**, frame-rate dependent; only a stall over 0.2 s adds its own length. Time has no unit of
its own: 0.006 of a picture a frame at the effect's 0.03, about 0.36 pictures (3.6w map units) a second at 60 frames. The
wrap at 100 is three whole pictures, so nothing jumps, and the phase stops while the lines are not drawn.

**`HierarchyLines_Draw(camera, mesh, phase)`**, `ret 0xC`: returns without drawing where the mesh has no primitives or the
graphics have no current view (`CGraphics +0x6BC88`); `ZWRITEENABLE 0`, `ZENABLE 0` [exe], not put back; the effect with
`Begin(&passes, 0)` (D3DX restores the pass's states at End): `SetTechnique(Hierarchy)`; **`WorldViewProjectionMatrix`** =
`D3DXMatrixMultiply(view, projection)` of the current view camera (slots 91 and 93, `+0x16C`, `+0x174`; the scene's
left-handed LookAt and PerspectiveFov, `FINDINGS-mapdraw.md` A.4), no world matrix - camera-relative, hence the
shader's subtraction; **`CameraPosition`** = (MapCamera x_settled `+0x33C`, y_settled `+0x340`) (SetFloatArray, 2);
**`LineTexture`** the handler's texture; **`Time`** the phase. For the file's one pass `p0`: BeginPass, CommitChanges,
**the mesh** (VertexBuffer_Draw: the declaration, stream 0 stride 24, the indices, `DrawIndexedPrimitive(TRIANGLELIST, 0,
0, vertices, 0, 2 × lines)`); then `CameraPosition.x = (float)((double)x − (double)(float)W)`, CommitChanges, **and the
mesh again**; EndPass; End. **Correction to section 5**: the second draw is the mesh a map width **east**; with AddLine's
seam rule it covers a line crossing the seam from both sides, but no copy is drawn a width **west**, so from a camera just
across the seam on the west, a line near the east edge is not drawn (the consequence *inferred*; the two draws read).

**States at the draw**: the pass `p0` [mod: hierarchy.fx] `ALPHABLENDENABLE TRUE`, `ALPHATESTENABLE FALSE`, `ZWRITEENABLE
FALSE`, `vs_1_1` / `ps_2_0`; the engine [exe] `ZENABLE FALSE`, `ZWRITEENABLE FALSE` - **not depth tested**, over the whole
map scene and under the counters; the blend factors the engine's last, as neither the file nor the draw sets them: every
setter after the land in DrawScene sets `SRCALPHA / INVSRCALPHA` and `0x8482F0` sets none, so that pair (*likely*: the
object groups `+0x4C` and `+0x48` were not read); BLENDOP Direct3D's default ADD (*inferred*); CULLMODE NONE (*likely*,
and the winding needs it).

### 7.5 Not established

What `0x8482F0` (`CInGameIdler +0x1DDC`) draws, just before the lines with the same pattern (its own effect,
CameraPosition from `+0x33C`, one copy); the loader's second caller `0x43BBBE`; whether the two unread object groups of
DrawScene change SRCBLEND, DESTBLEND or CULLMODE; where a counter is drawn relative to its province's unit point when its
stack is fanned - the line ends at the unit point either way. Frontier: `0x483B30` (the records' push_back),
`0x482980`/`0x483A70` (IsCurrent's walk), `0x241950`, `0x4482F0`, `0x673B10`, `0x660F30`, `0x6610E0`, `0x676E80` (rvas).

## What was not read

- the rest of `0x652540`, the key handler, and of `0x668780`, which goes on to an AI-commanded
  unit's objectives and its `AutomationArrow`s;
- `0x6F80A0`, the settings menu's side;
- the rest of `CUnit::OnSelected`, which was read for the rings only.
