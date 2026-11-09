# The front line an automated headquarters shows on the map

Read 2026-11-09 against `hoi3_tfh.exe`, this build only. Addresses are virtual (`VA - 0x400000` = rva) unless marked rva. `[exe]` = hardcoded in the executable; `[mod: file]` = changeable by a mod; `*inferred*` is marked where it applies; everything else is read off the bytes.

The console's `reloadfx front` called it "the front manager"; the game's only name for it is the string `Front manager error`. There is no RTTI class and no vftable: it is a plain struct.

## 1. The object, and where it hangs

`FrontManager` (our name; 0x40 bytes). Made inline in `CInGameIdler`'s constructor at 0x649332 (`operator new(0x40)`, its fields zeroed) and stored at **`CInGameIdler +0x1DDC`** at 0x649369.

| offset | | |
| --- | --- | --- |
| +0, +4, +8 | `units` | `std::vector<CUnit*>`, one entry per chain |
| +0x10, +0x14, +0x18 | `meshes` | `std::vector<MeshBuffer*>`, parallel to `units` |
| +0x20 | `vertex_declaration` | |
| +0x24 | `effect` | front.fx |
| +0x28, +0x2C, +0x34 | handles | WorldViewProjectionMatrix, CameraPosition, ArrowTexture |
| +0x30 | technique | `Front` |
| +0x38 | `graphics` | |
| +0x3C | `texture_index` | |

`FrontManager_Load(manager, graphics)` (0x8456E0, `ret 8`):
- Has two callers: the constructor (0x64936F) and the console's `reloadfx front` (0x43BA4F). The console prints `Front reloaded`, or `Front manager error` where the manager is null (0x43B9C5).
- Creates the vertex declaration of `FrontVertexDecl_Elements` (VA 0x170ACF8: FLOAT2 POSITION0 at 0, FLOAT2 TEXCOORD0 at 8; a 16-byte vertex). Failure is a message box and FatalExit.
- Loads `/FX/front.fx` under the key `Front` through the same directory settings as the other map effects (`FxHandler_Reload` then `FxHandler_Register`, handler at `graphics +0x6BCFC`).
- Registers the texture `/mapitems/front_arrow.tga` through the texture handler at `graphics +0x158` (0xA60F30), the `.tga` name opening `front_arrow.dds` as `hierarchy_line.tga` does (*inferred* by parallel with `HierarchyLines_LoadShader`).

Exists only in the in-game screen; the front end has none.

## 2. When a line exists, and from which unit

**Draw:** every frame, whenever `meshes` is non-empty. See section 4 for the gates, which are none of the ones asked about.

**A unit acquires a line** only through `FrontManager_BuildForUnit`, which has one caller: `CInGameIdler::ShowSelection` (slot 32, 0x668BCE).
- ShowSelection acts only where its `unit` argument is non-null, is the **player's**, and **an AI agent commands it or a unit above it** (`CUnit +0x198` up the chain `+0x1E0`, highest found wins). Otherwise it returns without touching any mesh.
- It then walks **every unit of the player's country** and, for each one that has an agent in its own chain, builds that unit's line where `unit->is_selected` (`+4`) **and** the unit's own `plan.ops_area` count (`+0x21C`) is non-zero.

So:
- only selected units;
- only the player's units;
- **any selected unit with an agent anywhere above it** counts, not only the top agent. The list drawn is that unit's *own* plan's list. A headquarters under an automated parent has its own slice, posted to it through `CSetPlanOpsAreaCommand` (`FINDINGS-setarea.md`), so a selected corps shows its own slice.

**`ShowSelection` callers** (found by scanning `mov reg,[reg+0x80]; call reg` through the in-game screen, section *Not established*):

| site | what passes |
| --- | --- |
| `CObjectivesEntry::CObjectivesEntry` (0x74E7CD; the panel's headquarters row, `oob_level < 4`; made when a single selected unit's panel is built) | the row's unit where an agent is in its chain; null where none (0x74E854) |
| `CObjectivesEntry::OnAutomateChecked` (0x74FC1C, 0x74FB6C) | the row's unit after making the agent; null after removing it |
| `CSetPlanOpsAreaCommand::Execute`, `CTogglePlanObjectiveCommand::Execute`, `CSetPlanAxisCommand::Execute` (0x5E649F, 0x5E72AF, 0x5E83E7) | the unit, in the ops-area command only where it is the local player's and the unit reference matches |
| `CInGameIdler::RemoveUnitRow` (0x66436A) | null, when 0 or 2+ rows remain |

A null argument builds nothing and removes nothing.

**A unit loses its line** through `FrontManager_RemoveUnit` (0x848180, manager in ESI):
- called first by the build itself;
- by `CGameState::RemoveUnit` (0x684E82);
- by `FrontManager_Prune` (0x848280, manager in EAX), which runs in the idler's pre-update (0x64F850, itself called from `CInGameIdler::Update` at 0x655AEF), so every frame.

The prune walks `units` and removes an entry where the unit is no longer selected or has no agent left in its chain.

RemoveUnit's loop runs i from 0 to the count taken at entry, swapping the last entry into i and popping, and **does not re-examine the element it swapped in**. The mesh is `Release`d through its slot-2 calls (vertex buffer, index buffer, +8) and freed. Prune tries an index again after removing; `BuildForUnit`'s call does not.

**What follows from this, for a spec:**
- Rebuild happens on: selecting a headquarters into the single panel; ticking `automate_checkbox`; and the three plan commands above. Nothing else. There is no hourly rebuild, and no rebuild on a stance change as such.
- An ops area that becomes empty does **not** clear an existing line: ShowSelection's gate skips the build, so the old mesh stays until the unit is deselected or loses its agent.
- A multi-selection builds nothing new (ShowSelection is given null or nothing). A line already built for a unit that stays selected and automated survives, because only the prune removes it.

### 2.1 Which edges: the walk

Data: the plan's `ops_area` list at `CUnit +0x214` (first node), `+0x218`, `+0x21C` count, in list order. Node `+0` = `CMapProvince*`, node `+8` = next. For each province its template `+0x90/+0x94` edge vector (0x14 bytes each, `to_province` at +4), all edge kinds.

`isFront(N)`, a neighbour province N, as tested at 0x845CD0 and again at 0x8462xx:
- N's template is land (`+0x22`);
- `N.controller.id` differs from `unit.owner` (`CCountry` found through `unit +0x124`);
- `status = owner.Diplomacy[controller.id]`, and **not** `status.co_belligerent` (+0x58), and `status.alliance` (+0x14) is null;
- and there is no vassal link either way: a `status.dependency` (+0x18) whose slot 7 token is 0x298 with `dependency.second.id == status.Target.id`, or `CDiplomacyStatus_IsVassalWithTargetFirst` (the same, inlined at the second site, with `dependency.first`).

Faction membership is not tested: a friendly province at peace counts as foreign unless allied, co-belligerent or a vassal link applies. **Friend or foe is read off the province's controller at build time.**

The walk (0x845B60; `open[i]` = count of edges of `ops_area[i]` with `isFront`; `visited[i][k]` zeroed flat, `recorded[i]` byte zeroed):

```
do:
  passId += 1
  chain = new FrontChain; points = new vector          // chain: provinces, starts, neighbours
  prev = null; last = -1
  i = first index with open[i] > 0
  while i < N:
    P = ops_area[i]
    if prev == null or P has an edge to prev's province id (+0xD0):
      if last >= 0:
        k = P's edge to `last`; none, or no edges at all -> end this chain
        visited[P][k] already set -> end this chain
        visited[P][k] = 1; open[P] -= 1
        add midpoint(P.centre, last.centre) to points
      startC = size(chain.neighbours)
      repeat:
        took = false
        for each edge k of P, in edge order:
          N = edge.to
          if not visited[P][k] and open[P] > 0:
            if isFront(N) and (last == -1 or N has an edge to last):
              visited[P][k] = 1; open[P] -= 1; last = N
              chain.neighbours.push(N); add midpoint(P.centre, N.centre) to points
              took = true
          else if recorded[P] != passId:
            recorded[P] = passId; chain.provinces.push(P.id); chain.starts.push(startC)
      until not took
      prev = P
    i += 1
  chain.starts.push(size(chain.neighbours)); chain.starts[0] = 1
while points of this pass non-empty
// the last pass's empty chain is popped
```

"Centre" is the province template's bounding-box centre: `+0x2C`/`+0x30`, map pixels, y growing northward. The midpoint is `(float)(c_x * 0.5) + (float)(n_x * 0.5)`, each half taken in single precision.

**There can be several chains**: one for each pass and each merge survivor, and each is its own mesh with its own entry in the manager. **Border pixels, the province raster and the terrain are never read.** "Along the border" means the middle of each pair of province centres.

### 2.5 Joining the chains

`FrontChains_MergePass` (0x8473F0) runs until it reports nothing erased. For each ordered pair of chains R, S (S not R, both with provinces), in this order, with `adj(a,b)` meaning a's edge list contains b:

1. `R.provinces.last == S.provinces.first` and `adj(R.neighbours.last, S.neighbours.first)`.
2. `R.provinces.first == S.provinces.first` and `adj(R.neighbours.first, S.neighbours.first)`: R reversed first.
3. `R.provinces.last == S.provinces.last` and `adj(R.neighbours.last, S.neighbours.last)`: S reversed first.
4. `R.provinces.first == S.provinces.last` and `adj(R.neighbours.first, S.neighbours.last)`: both reversed.

   In these four, R's last province and last start entry are popped, S is appended to R (`FrontChain_Append`), and S's province list is emptied.

5. `adj(R.provinces.last, S.provinces.first)` and `R.neighbours.last == S.neighbours.first`.
6. `adj(R.provinces.last, S.provinces.last)` and `R.neighbours.last == S.neighbours.last`: S reversed.
7. `adj(R.provinces.first, S.provinces.first)` and `R.neighbours.first == S.neighbours.first`: R reversed.
8. `adj(R.provinces.first, S.provinces.last)` and `R.neighbours.first == S.neighbours.last`: both reversed.

   In these four, R's last neighbour is popped, S is appended, S's province list emptied.

Reversing a chain reverses all three lists and maps each start `b` to `size(neighbours) - b + 1` (`FrontChain_Reverse`). Appending adds each of S's starts after its first, shifted by R's neighbour count before the append. Afterwards every chain with an empty province list is erased, from the highest index down, and the function answers whether any was.

## 3. Points, and the strip

For each merged chain the final polyline (rebuilt from its lists, the walk's `points` having only said whether anything happened):

```
for j over chain.provinces:
  own = province j
  for k from chain.starts[j]-1 up to chain.starts[j+1]-1 inclusive:
    point = half(own.centre) + half(province[chain.neighbours[k]].centre)
```

Then, where the chain has at least two points:

- `FrontLine_Relax` (0x8484C0): two passes, factor 1.0 then 0.5, in place. Each pass recomputes the unit direction `d[i]` of segment i, then for i = 2 to n-3 does `P[i] += (d[i] - d[i-1]) x factor`. Nothing where n <= 4. [exe]
- `FrontLine_CutCorners` (0x846DE0), **one** round: `out[0] = P[0]`; for i in 1..n-2 the two points `0.25 P[i-1] + 0.75 P[i]` and `0.75 P[i] + 0.25 P[i+1]`; `out[last] = P[n-1]`; 2n-2 points. [exe]
- A new `MeshBuffer` (0x24 bytes, zeroed; managed pool, stride 0x10, no FVF, no declaration on the mesh, triangle list) is pushed with the unit, and `FrontManager_MakeMesh` (0x847C50) fills it.

The strip, for n points:
- 2n vertices of 16 bytes: `{float x, float y, float u, float v}`.
- `(n-1) x 6` 16-bit indices: `{i, i+1, i+2, i+1, i+3, i+2}` for i = 0, 2, 4...
- Normal of a segment: `(-dy, dx) / length`, in single precision.
- Each point i < n-1: `miter = normalise(normal(i-1) + normal(i))`, with `normal(-1) = normal(0)`.
- Vertex 2i = `P[i] + miter x 3.0`, uv `(s, 0)`; vertex 2i+1 = `P[i] + miter x -3.0`, uv `(s, 1.0)`. The 1.0 is the float global at VA 0x171DBAC.
- `s` is the sum of segment lengths so far, starting at 0.
- The miter is **not** lengthened by the angle, and there is no join treatment for sharp turns: the half-width stays 3.0 along the unit miter.
- The last point uses the last segment's normal alone.

The strip is flat: only these points, no height read. **Constants [exe]:** 0.5, 3.0, -3.0, the Relax passes, the Chaikin weights, the number of rounds.

There is **no seam treatment** in any of these: an edge between provinces at the map's two sides gives a midpoint in the middle of the map (no such test exists in these functions; a chain crossing the seam would be a long stray segment, not seen live).

## 4. The draw, the shader, the texture

`FrontManager_Draw(manager, camera)` (0x8482F0), called by `CInGameIdler_Render` at 0x65705C, immediately after `MapGraphics_DrawScene`, in the same device-ready block, gated only by the manager's existence (0x657056). Nothing in the function or at the call tests a map mode, the layer mask (settings +0xEC), the camera height, or any setting.

Inside: nothing where the graphics have no current view (`+0x6BC88`). `ZWRITEENABLE 0`, `ZENABLE 0`, not put back. `SetTechnique(Front)`; `Begin`; `WorldViewProjectionMatrix` = view x projection of the current view's camera (slots 91, 93), as the hierarchy lines; `CameraPosition` = the map camera's `+0x33C` pair (2 floats); `SetVertexDeclaration(+0x20)`; `ArrowTexture` from the texture handler's entry. Each pass: `BeginPass`, `CommitChanges`, `VertexBuffer_Draw` once per mesh; `EndPass`, `End`.

**Unlike `HierarchyLines_Draw`, it draws each mesh once: there is no second draw a map width over**, so a line is not repeated across the seam.

Each mesh is drawn once per pass, in `meshes` order. After it come the hierarchy lines, then the unit layers (0x641950), so counters are drawn over it.

**`gfx/FX/front.fx`** [mod], technique `Front` (BlackICE ships its own; identical but for whitespace):
- Vertex shader: `Position = float4(x - CameraPosition.x, 1.0, y - CameraPosition.y, 1.0)`. A flat plane at height 1.0 (the hierarchy lines use 2.0). No terrain.
- Pixel shader: everything but the last lines is overwritten. `UV = v.vUV.yx; UV.y *= 0.15; return tex2D(ArrowSampler, UV)`.
- So texture U = across the line (vertex v, 0..1), texture V = along it (`s * 0.15`, **no scrolling**: the effect has no Time and the draw sets none).
- Pass: `ALPHABLENDENABLE = True`, `ALPHATESTENABLE = False`, samplers WRAP/LINEAR/LINEAR/LINEAR. Colour comes from the texture only: **no colour parameter, no tint.**

**`gfx/mapitems/front_arrow.dds`** [mod], DXT5, 64x64, one level in the file.
- Across (U, 64 texels): opaque in columns about 25..38, centred, colour about (24..50, grey) with a lighter left edge and a darker right edge; alpha 0 outside. In the 6-unit strip that is an opaque band about 14/64 x 6 = 1.3 units wide.
- Along (V, 64 rows): **two identical dashes per texture period**, rows 0..27 and 32..59, near-black (RGB about 50 down to 32, darker at the end), with a brief lighter row (RGB 139) at each dash's start, and 4 fully transparent rows (28..31, 60..63) between.
- `V = s * 0.15` makes the texture period `1 / 0.15 = 6.667` map units, so a dash-and-gap is **3.33 units** long and the gap about **0.42 units**.

That is the whole of "black and dashed".

## 5. Other front-related displays

None in this code: no colour by stance, no offensive/defensive variant, no arrow in `FrontManager_*`. The build reads only the plan's `ops_area` (+0x214..+0x21C); stance (+0x208), `fallback_line` (+0x224), objectives and path are not read there (the walk and draw were read whole).

What `ShowSelection` draws next to it, for each player unit with an agent in its chain, whether selected or not (`FINDINGS-movement.md`):
- objective markers `MapObjective` / `MapObjectiveOther` from `plan.objectives`, `Other` for units that are not the one passed;
- `AutomationArrow` / `OtherAutomationArrow` along `plan.path` where the unit is land and its `CArmy +0x2FC` is 0.

## 6. Hardcoded and mod-able

- **Mod-able:** `front.fx` (the height 1.0, the along factor 0.15, the blend state) and `front_arrow` (the dash pattern, the width of the opaque band, the colour).
- **Exe-hardcoded:** the walk, `isFront`, the merge's eight tests, the midpoint 0.5, Relax's two passes and factors, one round of Chaikin at 0.25/0.75, the strip half-width 3.0 and its uv layout, the draw's Z state and its single draw, and the absence of a map-mode, height or setting gate.

## 7. The markers, the arrows and the click that sets them, read 2026-11-09

`ShowSelection` first takes down what it showed last. For each of the player's units with an agent in its chain (selected or not), once the front line is dealt with:

- **each objective in `plan.objectives`:** the province's billboard `icon_objective_strip` (`mapitems.gfx`, four frames; made once by `0x641E20` and kept on the province graphics' +0x90), shown and given slot 0x60 with 0 for the unit passed and 1 for the others (*inferred* to be the frame), then an `animatedmaptext` of type `MapObjective` or, for the others, `MapObjectiveOther` (`core.gfx`), whose text is the province's name, on the same anchor.
- **an arrow along `plan.path`**, where the unit is land, its `army_role` 0 and the path not empty: `0x6682E0` with `AutomationArrow` or `OtherAutomationArrow`, called twice, both kept. Its points are each path province's centre (z 0 over the sea), and then a last one past the end, `x + (int)((x - prevx) * 0.25)` and the same for y; `progress` (+0x15C) 1.0.

**The click** (`CUnit::OrderToProvince`). A unit with an agent on a unit above it has returned already. For a land unit of the player's with `HasAgentAbove`, selected, above a division: not appending, `CTogglePlanObjectiveCommand(unit, province)`; appending, slot 29 (`0x5C28E0`), `CUnit::SetPlanAxisTo(province, 0)`: `CPlannedPathFind` from the unit's province, posting `CSetPlanAxisCommand`. With the slot's second argument, not passed here, a new leg goes onto `path2`. Both play `army_move`.

`CTogglePlanObjectiveCommand::Execute` removes the objective where the province is one, and otherwise appends it with priority 400, hold; its tail asks `CAIUnit::GetArea` and `SetArea`.

## Frontier

Unnamed, used here: 0x848A60 (vector<chain> push_back), 0x848B10, 0x848D70, 0x8489B0, 0x848CA0, 0x848D00, 0x84AFB0, 0x844BF0, 0x7C6440, 0xA60F30 (texture register), 0xA610E0, 0xA5B0D0, 0x44C2F0.

## Not established

- **The list of `ShowSelection` callers is what the scan found**: `mov reg,[reg+0x80]` followed by a `call reg` within six instructions, across the interface code at VA 0x640000-0x7A0000, plus a whole-image scan of those with `+0xBE8` in the lead-in. The positive controls `RemoveUnitRow` and `OnAutomateChecked` were found. A call that loads the vftable in another shape would be missed.
- **The source and destination blend factors.** `front.fx` sets only `ALPHABLENDENABLE`; `SRCBLEND`/`DESTBLEND`, `CULLMODE` and the texture-stage states are inherited from what `MapGraphics_DrawScene` left. *Inferred*: `SRCALPHA`/`INVSRCALPHA` from the land-borders pass. Which cull mode is in force was not traced; the strip's winding is given above, so a spec can pick no culling.
- **Mip levels and `.tga` versus `.dds`.** The file has one level and the sampler asks for `MIPFILTER = LINEAR`; whether the texture handler generates more was not read. The `.tga` name opening the install's `.dds` is inferred from `hierarchy_line.tga`.
- **Seam behaviour** was reasoned from the absence of code, not observed; no live check of a chain crossing the seam.
- **Not compared to the running game**: no screenshot was measured, and the ordering of chains and the exact dash phase at a chain's start were not set beside the original.
- **The exact behaviour of the multi-selection case** was reasoned from the listed callers and the prune, not observed.
- **What fills `ops_area`** for a human's delegated agent, and that list's order, is cited from `FINDINGS-setarea.md`/`FINDINGS-agents.md` and was not re-read here.
- **The `+0x30` pair of `FrontChain`** is copied in `0x848CA0` and read nowhere the walk reaches; it is unnamed.
