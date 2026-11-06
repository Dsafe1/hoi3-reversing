# How the map is drawn

What the original feeds each effect file of the map, so that a reimplementation drawing the install's own `gfx/FX` files
- OpenHOI3 translates them to Godot shaders, unchanged, for mods' shaders to count - can feed them the same. Read
2026-11-06, statically, in a wave of three readers: section A, the land and the beaches and the camera (fragment
`mapdraw-terrain.json`); section B, the sea, the borders and the province colour and state textures (`mapdraw-water.json`);
section C, the scene as a whole, its device states, the smaller layers and the effect system (`mapdraw-scene.json`).
Addresses are rvas unless marked VA (VA = rva + 0x400000), valid only for this build. **[exe]** hardcoded; **[mod: file]**
a file can change it. `confirmed` unless marked. It builds on `FINDINGS-farmap.md`, A (the scene's draws and their
height gates).

Device slots below are d3d9.h's IDirect3DDevice9 order - SetTransform 44, SetViewport 47, SetMaterial 49, SetRenderState
57, SetTexture 65, SetTextureStageState 67, SetSamplerState 69, DrawPrimitive 81, DrawIndexedPrimitive 82,
SetVertexDeclaration 87, SetFVF 89, SetStreamSource 100, SetIndices 104 - and the effect's d3dx9_42 ID3DXEffect order:
GetParameterByName 9, GetTechniqueByName 13, SetFloat 30, SetMatrix 38, SetTexture 52, SetTechnique 58, Begin 63,
BeginPass 64, CommitChanges 65, EndPass 66, End 67, OnLostDevice 69, OnResetDevice 70 (the map loader calls slot 9 with
(NULL, "name") and slot 13 with ("name"), those two's shapes).

## A. The land, the beaches and the camera

Measurements were made on the install's own cache (`tfh/map/cache`) and `tfh/map/provinces.bmp`, `terrain.bmp` and
`definition.csv`; *measured* is read off the shipped files, not off the code.

**In one line.** The land is drawn tile by tile - a tile 50×50 map pixels [exe], 113×44 of them for TFH's 5616×2160 map
[mod: the map's size] - each holding the whole meshes of the provinces whose middle lies in it: one indexed triangle list of
8-byte vertices (SHORT2 tile-local corner, SHORT2 province id as low byte / high byte) loaded from `map/cache/all_quads.bin`,
drawn with two world matrices - AbsoluteWorldMatrix the tile's middle, WorldMatrix the tile's middle less the camera, so
everything is camera-relative, shifted ±5616 across the east-west seam - and its own terrain-index texture. The beaches are
a second mesh for each tile, float positions and a D3DCOLOR carrying the province id. ViewMatrix and ProjectionMatrix are a
left-handed LookAt and PerspectiveFov off the scene view's camera.

**Corrections.** `FINDINGS-camera.md` left open which of the camera's two position pairs the renderer takes: MapGraphics_Update
makes every tile's WorldMatrix from **x_settled/y_settled (`MapCamera +0x33C/+0x340`)** (0x45C7B2). `VertexBuffer_Create`
(0x6D4510) stores its fvf argument at +0x1C, which C's correction (1) agrees with.

### A.1 The mesh

**Tiles.** CProvinceManager_CreateWorld (0x450520) sets the tile width and height to **50** [exe] (0x450823), columns =
map_width / 50 + 1 and rows = map_height / 50 + 1 (`CMap +0x2A74/+0x2A78`, integer division): **113 × 44 = 4,972 tiles** for
TFH. CProvinceManager_CreateTiles (0x4571F0) makes them, 0x3C0 bytes each, at `+0x19C`; tile i is col = i mod 113, row = i
div 113, and its **AbsoluteWorldMatrix = D3DXMatrixTranslation(col·50 + 25, 0, row·50 + 25)**, its middle [exe].

**Coordinates.** World x is the map's pixel column; world z is the engine's y, 0 in the south and growing northward (a
provinces.bmp file row is 2159 − y); world y is up, the land at y = `LAND_ALT` = 0.35 [mod: gfx/FX/terrain_2_0.fx]. A pixel's
middle sits on whole world coordinates: pixel k spans [k − 0.5, k + 0.5].

**Which tile holds a province.** CProvinceManager_AssignProvincesToTiles (0x45B490) puts every province in one tile, (cx / 50)
+ 113·(cy / 50), from a middle pair at the province entry's `+0x10 → +0x13C/+0x140`, and for a land province (template
`+0x22`) grows the tile's land rectangle (`+0x3A0..+0x3AC`, x y w h) to cover its bounding box (template `+0x80..+0x8C`).
*Measured*: all **10,621** provinces with a land mesh sit in the tile given by cx = x0 + (x1 − x0 + 1) div 2 over their pixel
bounding box, and so for y (floor((x0+x1)/2) gives 10,399). So **a province's whole mesh is in one tile** and reaches past its
edges: local coordinates run −106..108.

**The cache.** CProvinceManager_LoadQuads (0x459BD0) takes `cache/quad_index.bin` and `cache/all_quads.bin` where both exist
and `CMap +0x28` (stale) is 0, otherwise CProvinceManager_BuildQuads (0x45A580, not read). quad_index.bin: count, total bytes,
largest record, then count pairs of (tile index, record bytes) - TFH 1,774 tiles with land, the total 66,167,662, all_quads.bin's
size. Each record is read by `QuadCache_LoadTile` (0x474970), and every record of TFH's file parses exactly to its stated size:

| # | in the record | becomes | format |
| --- | --- | --- | --- |
| 1 | dword, dword V, V bytes | **land vertex buffer**, tile `+0x270`, V/8 vertices, stride 8 | SHORT2 position (tile-local, from the tile's middle), SHORT2 province id = (id & 0xFF, id >> 8) |
| 2 | dword, dword N, N×(dword B, B bytes) | **land index buffer**, tile `+0x24C` (IB at `+0x250`): all groups one after another, 16-bit, triangle list; the groups' starts in the int vector at tile `+0x20` | one group per province of the tile |
| 3 | dword M, M bytes | the border index buffer, tile `+0x294` | B.3 |
| 4 | dword B, B bytes | the border vertex buffer, tile `+0x294`, stride 12 | SHORT4 + D3DCOLOR, B.3 |
| 5 | dword W, W bytes | **beach vertex buffer**, tile `+0x2B8`, W/12 vertices, stride 12 | FLOAT2 position (tile-local), D3DCOLOR R = id & 0xFF, G = id >> 8, B = A = 0 |
| 6 | (only where W ≠ 0) dword X, X bytes | **beach index buffer**, tile `+0x2DC` (IB `+0x2E0`), 16-bit, triangle list | |
| 7 | dword K, K × 0x1C bytes | **K wave pixels** (C.7), each pushed onto the tile's list by CBeachManager_AddWavePixel (0x432B40), where the surf object (`+0x4164`) exists | x, y int; type int 0..51; four float offsets fixed by the type (C.7) |

All buffers WRITEONLY in the managed pool, filled by Lock, memcpy, Unlock; the index buffers by IndexBuffer_Create (0x6D48B0),
D3DFMT_INDEX16, primitive count indices/3.

**The vertex declarations**, static D3DVERTEXELEMENT9 arrays in .data made in CProvinceManager_CreateMeshes (0x4578B0) - TFH's
`cache/quad_format.bin` holds the same two lists:

| declaration | where | stream 0 |
| --- | --- | --- |
| land ("ProvinceVertexDecl") | VA 0x170AC40 → `+0x429C` | SHORT2 POSITION0 at 0; SHORT2 TEXCOORD0 at 4; stride 8 |
| beaches (logged as ProvinceVertexDecl too) | VA 0x170AC58 → `+0x42A0` | FLOAT2 POSITION0 at 0; D3DCOLOR COLOR0 at 8; stride 12 |

**What the land vertices mean.** With SHORT2 the shader's `int2 vPosition` receives the plain integers; `VertexShader_Map*`
adds 0.5 [mod: fx], so vertex v lands at world = the tile's middle + v + 0.5: **whole vertices are pixel corners**. *Measured*:
for every one of the 10,621 provinces the mesh's extent (middle + local) is exactly [x0 − 1, x1] × [y0 − 1, y1] over its pixel
bounding box - [x0 − 0.5, x1 + 0.5] after the shader's 0.5; the triangles' area summed is 4,041,885 against 4,041,291 pixels
of those provinces - 1,294 match exactly and the rest differ by at most 45 px², so the build bends some edges off the pixel
grid (how was not read); 565,507 vertices and 443,825 triangles, no triangle mixing province ids; the triangles wound
clockwise seen from above (+y), front-facing under the draw's CULLMODE CCW.

**What the beach vertices mean.** Floats already on the half pixel (14.5, −5.928); `VertexShader_Beach*` adds no 0.5 [mod:
fx]. The colour carries the land province's id: COLOR0 = (id & 0xFF, id >> 8, 0, 0)/255. *Measured* over 572,496 beach
triangles in 941 tiles: 54% of their middles on sea zones (default.map `sea_starts`), 40% on the province named, 1.3% on
another land province and 4% on pixels with no definition.csv colour - a strip laid along the coast, mostly over the sea.

### A.2 What the terrain effect is given

The handles fetched by name in CProvinceManager_ReloadResources (0x468530) on the effect registered as `TerrainShader`
(`+0x1A0`):

| parameter | value | source |
| --- | --- | --- |
| WorldMatrix | for each tile Translation(middle x − camera x_settled, 0, middle z − camera y_settled), ± the map's width across the seam (A.5) | tile `+0x17C`, MapGraphics_Update [exe] |
| AbsoluteWorldMatrix | for each tile Translation(middle x, 0, middle z) | tile `+0x13C`, set by name [exe] |
| ViewMatrix | the scene view camera's slot 91 (LookAtLH) | A.4 |
| ProjectionMatrix | the scene view camera's slot 93 (PerspectiveFovLH) | A.4 |
| WorldViewProjectionMatrix | the handle fetched and null: terrain_2_0.fx does not declare it | skipped |
| LightDirection | 12 bytes of the MapSetLight light (`+0x416C`, its `+0x138`) - *inferred* `direction = { 0.0 -1.0 0.5 }` | [mod: interface/core.gfx]; no land or beach shader reads it |
| ColorMapHeight / ColorMapWidth | **720 / 1872**, colormap.dds's own size (texture table entry `+0x28/+0x24`), even where tex4 is the political map | [mod: map/terrain/colormap.dds] |
| ColorMapTextureHeight / ColorMapTextureWidth | **1024 / 2048**, their next powers of two | [exe rule] |
| MapWidth / MapHeight | **5616 / 2160** (`CMap +0x2A74/+0x2A78`) | [mod: provinces.bmp] |
| BorderWidth / BorderHeight | **50 / 50**, the tile's size | [exe] |
| TerrainIndexOffsetX/Y, TerrainIndexSizeX/Y | for each tile, fetched by name every tile (A.3) | tile `+0x3B0..+0x3BC` |

**Every matrix goes through ID3DXEffect::SetMatrix (slot 0x98), not SetMatrixTranspose**: D3DX row-major matrices, used in
HLSL as `mul(rowVector, M)`.

**Textures** (every file in the map folder's terrain/ [mod]):

| slot | land: Graphical | land: General | land: General_Low | beaches |
| --- | --- | --- | --- | --- |
| tex0 | base.dds (`+0xB4`), unused | same | same | base.dds when not Graphical |
| tex1 | the tile's terrain-index texture (`+0x39C`) | same | same | same |
| tex2 | province colour lookup 1 (`graphics +0x4168 → +0xC`, B.2) | same | same | same |
| tex3 | province colour lookup 2 (`→ +0x10`) | same | same | **not set: the land's kept** |
| tex4 | colormap.dds (`+0xB8`) | colormap_political.dds (`+0xBC`) | colormap_political.dds | as the land |
| tex5 | noise_test2.dds (`+0x184`) | noise_test2.dds | map_overlay_tile.dds (`+0x2C0`) | **not set: the land's kept** |
| tex6 | the level's texture sheet (`+0x288[level]`): texturesheet.tga near, texturesheet2.tga far | same | same | same |
| tex7 | not set | stripes.dds (`+0xC0`) | stripes.dds | **not set: the land's kept** |

tex5's choice is the .bss global at VA 0x1A8565C - 0 noise_test2.dds, 1 test_noise.dds, anything else noise-2d.dds - whose
only reference in .text is the read (the same scan finding that read is the positive control): *inferred* always 0. The
beaches keep tex3, tex5 and tex7 because an effect's parameters persist and the land is drawn first through the same effect.

**Device states.** The land, before Begin: ALPHABLENDENABLE 0, SRCBLEND ONE, DESTBLEND ZERO, CULLMODE CCW; samplers 0 and 1
D3DSAMP_MIPMAPLODBIAS **−1.5** under Graphical and **−2.5** otherwise [exe]; Begin(flags 0). After: LOD bias 0 on samplers 0
and 1; SRCBLEND SRCALPHA, DESTBLEND INVSRCALPHA, CULLMODE NONE. The beaches, before: ALPHABLENDENABLE 1, SRCBLEND SRCALPHA,
DESTBLEND ZERO - the Graphical and General passes override that with the alpha test and SRCALPHA/INVSRCALPHA [mod: fx];
General_Low keeps it, and its shader writes alpha 1; cull not set, so NONE from the land's reset; sampler 0 alone LOD bias
**−1.7** under Graphical and −2.5 otherwise [exe]. After: the land's reset. Which of the effect's samplers land on stages 0
and 1 is the shader compiler's choice, not the executable's; *not settled*.

### A.3 The terrain-index texture and the colour map's size

**Size.** One texture a tile, `cache/quad_textures/quad_texture_<tile>.dds`, loaded by Quad_LoadTerrainIndexTexture
(0x469B60) with D3DX_DEFAULT_NONPOW2, one mip level and filter NONE, so at its file's size - TFH's 1,774 files A8R8G8B8 with no
mips. MapTile_SetTerrainIndexRect (0x457180) sets **TerrainIndexOffset = the land rectangle's (x, y) − 2** and
**TerrainIndexSize = (w + 4, h + 4)**; it works out the next power of two of both, in ESI, and overwrites ESI before the
stores, so the size is the texture's own - tile 145's rectangle 36×27 and texture 40×31, tile 1200's 53×64 and 57×68 [exe;
*measured*]. Texel (i, j) is map pixel (x0 − 2 + i, y0 − 2 + j), the texture's rows running northward.

**Contents** (*measured* on tiles 145 and 1200; made by CreateTerrainOffsetTexture 0x469080, not read): in memory B =
terrain(x, y), R = terrain(x − 1, y), G = terrain(x − 1, y + 1), A = terrain(x, y + 1), terrain terrain.bmp's index - agreeing
with terrain.bmp's raw index on 70-91% of texels a channel, the rest presumably a mapping not read; 0xFFFFFFFF outside the
land. The shader reads float4 (R, G, B, A) as (left, up-left, this, up), the names in `GenerateTiles`; index v selects tile
(v mod 16, v div 16) of the 16×16 texture sheet (2048 px, 128-px tiles) [mod: fx, texturesheet*.tga].

**The colour map's size.** The texture handler (0xA60F30 → LoadFile 0xA607D0) loads colormap.dds with width and height
D3DX_DEFAULT, mips from the file and filter NONE; D3DX_DEFAULT rounds a texture up to a power of two and filter NONE puts the
image in the top-left corner unscaled (D3DX's documented behaviour, *inferred* from the documentation and not the
executable), so the device holds a 2048×1024 texture with the 1872×720 picture in its corner - which is why the shader divides
by ColorMapTexture* while scaling by ColorMap*/Map*: u = (1872·x/5616 + 0.5)/2048. **A reimplementation loading the file at
its own size pads it to 2048×1024, or passes 1872 and 720 as the "texture" sizes.** The other textures (stripes 128, noise
256, overlay 512, sheets 2048) are powers of two already [mod].

### A.4 The camera

**The map camera** (`CInGameIdler +0x1938`) is a Camera at offset 0 (vftable VA 0x1601BE0, no RTTI) made by Camera_Construct:
fovY **0.785** rad, aspect the screen's width over its height, near **8**, far **1200** [exe]; projection `+0x148`
**D3DXMatrixPerspectiveFovLH** (left-handed); view `+0x1C8` **D3DXMatrixLookAtLH**(eye `+0xF8`, at `+0x104`, up `+0x110`)
by Camera_RebuildView (0x6BEC80), up (0, 1, 0) from the start. Each frame UpdateMapCamera ends with Camera_SetAt(aim `+0x2F4`)
and Camera_SetEye(`+0x2E8`): **eye (0, height, 0); at (0, −8, 0) with always_counters, (0, 12, 30) without**
(`FINDINGS-camera.md`). So the camera hangs over the origin and the map is moved to it by each tile's WorldMatrix, the tile's
middle less (x_settled, y_settled). Camera_UpdateViewProjection (0x6BE530) makes view × projection at `+0x188` each frame;
MapGraphics_Update culls tiles against this camera's frustum (0x6BECF0, then 0x6BF670).

**What the effect receives.** MapGraphics_DrawScene, DrawTerrain and DrawBeaches take ViewMatrix and ProjectionMatrix from
slots 91 and 93 of **the scene view's camera** - DrawScene's third argument, `[CInGameIdler +0x1788]`, at its `+0x1C` - and
MapGraphics_Update makes every tile's world-view-projection from the same camera. The scene view is a SceneView_Construct
(0x6873F0) object, a D3DVIEWPORT9 at `+0` (DrawScene's SetViewport) and a Camera at `+0x1C`; CInGameIdler makes it at
0x25D3CB with fovY 0.785, near 8, **far 250** and an aspect worked out there (not traced). **How that camera follows the map
camera was not found** (A.6); since culling uses the map camera and drawing the scene view's, and the map draws correctly at
height 1000, they agree in play. A reimplementation takes, *inferred*: View = LookAtLH((0, h, 0), aim, (0, 1, 0)) and
Projection = PerspectiveFovLH(0.785, w/h, 8, F), F at least 1000, the map camera's 1200 the likely value.

### A.5 How the draws are split, and in what order

In MapGraphics_DrawScene the land is drawn first, then the beaches, both unconditionally (C.1). Each is **one technique, one
Begin, its one pass, and inside it one draw call for each visible tile** - the visible tiles the deque at `+0x78` (count
`+0x88`) MapGraphics_Update fills in tile order, row by row from the south-west (*inferred* from the loop). For each tile: tex1,
the four TerrainIndex floats (handles fetched again by name each tile), WorldMatrix, AbsoluteWorldMatrix, CommitChanges,
SetStreamSource(0, VB, 0, stride), SetIndices, then **DrawIndexedPrimitive(D3DPT_TRIANGLELIST, 0, 0, vertex count, 0, triangle
count)**. The land skips a tile with no triangles; the beaches one with no beach vertices (`+0x2C4`) or triangles (`+0x2EC`).

**Visibility and the seam** (MapGraphics_Update 0x45C6F0, made again whenever the camera moves) [exe]: A = trunc(h / (1000 −
40) × 1410 + 70) div 2, h the camera's height; where neither of a tile's x edges, relative to the camera, lies within ±A: where
(the tile's middle − camera x) + 80 > 5616 − A the tile is shifted −5616 and marked visible, where −(5616 − A) > (middle −
camera x) − 80 shifted +5616 and marked visible; otherwise tested against the map camera's frustum as a box from y −10 to 50
[exe]. So the map wraps east-west by drawing tiles a map's width away.

### A.6 Not established

**Where the scene view's camera (`[CInGameIdler +0x1788] + 0x1C`) gets the map camera's eye, aim and far plane** - searched
without result: direct calls to Camera_SetEye, SetAt, SetUp and RebuildView (none outside the class, but RebuildView's 8
callers); every call through slot 95 or 96 in a function touching `+0x1788` (only the map camera's own); every `mov reg,
[reg+0x1788]` in .text and what follows (only reads of view and projection); reads of `+0x1C8` and `+0x1E4` near the idler; the
frame routine 0x256E10 between 0x256E8E and the DrawScene call; the writers of graphics `+0x6BC88` (the current view) were not
followed. CProvinceManager_BuildQuads (0x45A580) - how a province's pixels become triangles, the beaches' smoothing, where edges
leave the pixel grid; mods that change the map make the cache again through it. The 0x13C/0x140 middle pair the tile
assignment divides (the measured rule is in A.1); the scene view's aspect at 0x25D395; the terrain.bmp-to-index mapping of
the terrain-index texture; which sampler stages the compiled shaders use.

Frontier: 0x45A580, 0x456FD0, 0x469080, 0x4DD860, 0x474F00, 0x4727B0, 0x6702E0, 0x6BECF0, 0x6BF670, 0x46B620, 0x44AFB0,
0x432B40, 0x44EB20.

## B. The sea, the borders, and the province colour and state textures

**In one line.** The map renderer (`WaterObject`, really CProvinceManager) owns a texture manager, `CViewsTextureManager`
(+0x4168), that makes six textures [exe]: two 256x256 A8R8G8B8 **province colour lookups** indexed by province id, a
512x512 A8R8G8B8 **land border lookup**, a 1024x1024 **L8 fog texture** and two 1024x1024 A8R8G8B8 **sea colour rasters**.
The sea is three map-sized quads; every border is a mesh read from the shipped cache `map/cache/all_quads.bin`; a province
border and a country border are told apart **for each pair of neighbouring provinces**, by one alpha bit of the lookup.

**Corrections.** `FINDINGS-mapmode.md` has water.fx's ColorTexture0/1 "the same colour pair the colouring loop writes":
they are filled from that pair, but they are separate 1024x1024 rasters of the map, not the 256x256 lookups the land
samples. The record's `Map_UpdateProvinceColourTexture` fills **two** textures, not one (+0xC and +0x10, each locked -
checked by the collecting session at VA 0x880E09..0x881186). The "province-state texture" the Graphical shaders read is
not a texture of its own: it is Texture1, which in map style 0 holds fog in r, 0.1/0 in g and the frozen share in b.
`Map_RefreshColourTextures`'s "0x4813C0, not read" is the fog's rebuild. In `FINDINGS-farmap.md` A.2, WaterSimple's "with
fog of war" holds only where an earlier frame bound FOWTex (B.1).

### B.1 The sea: `MapGraphics_DrawWater` (0x45F6E0), water.fx

**The mesh** [exe]: the declaration WaterFarDecl (+0x42AC), one FLOAT4 POSITION - water.fx's `position_uv`, (x, z, u, v)
- drawn as three DrawPrimitiveUP triangle fans of two triangles, 16-byte stride. With W, H = CMap +0x2A74/+0x2A78 (5616,
2160 in TFH, from provinces.bmp [mod: map]): the map (0,0,0,0), (W,0,1,0), (W,H,1,1), (0,H,0,1); the same at x −W..0; and
at W..2W - uv 0..1 over each, the two copies the horizontal wrap. The vertex shader puts the plane at y = −0.32 and takes
CameraPosition.xz off [mod: water.fx].

**Device states before the effect** [exe]: ALPHABLENDENABLE 1, SRCALPHA / INVSRCALPHA, samplers 0 and 1 LINEAR/LINEAR with
no mip, CULLMODE NONE.

**The effect** is fetched again every frame from the graphics' effect list at index +0x2B8 − 1, with every handle the
constructor fetched - the six techniques, tex0, tex1, Time, WorldViewProjectionMatrix, WorldMatrix, CameraPosition,
LightPosition, LightDirection, MapWidth, MapHeight, BorderWidth, BorderHeight and the four ColorMap sizes; **of these only
Time is ever set**, the rest set by name or not at all.

**The technique** [exe]: simpleWater (settings +0xE5) on - WaterSimpleColor in map style 16/18/19, else WaterSimple; off,
the camera strictly above any terrain_sheet_heights entry (500 [mod: map/default.map]) - WaterFarColor / WaterFar; off and
near - WaterNearColor / WaterNear.

**What it is fed:**

| water.fx input | value | origin |
|---|---|---|
| `CameraPosition` | (MapCamera x_settled +0x33C, 0, y_settled +0x340, 0) | [exe] |
| `ViewProjectionMatrix` | view × projection (D3DXMatrixMultiply of the view object's +0x16C and +0x174) | [exe] |
| `MinMaxUV` | (0.5/Pw, 0.5/Ph, (w−0.5)/Pw, (h−0.5)/Ph), w, h colormap_water.dds's size (texture table entry +0x24/+0x28), Pw, Ph the powers of two at or above; TFH's 936x360 gives (0.5/1024, 0.5/512, 935.5/1024, 359.5/512) | [exe] arithmetic, [mod] size; that +0x24/+0x28 are the image's own size in a power-of-two texture is *inferred* - a renderer keeping the texture at its own size uses u′ = (0.5 + u(w−1))/w |
| `Time` | −(seconds on the renderer's clock, +0x28), raised by 100 while below −100: a sawtooth in [−100, 0], a 100 s period; near and not simple only | [exe]; the clock a CHighPerfWinClock the constructor starts; that every wave offset of water.fx × 100 is whole (3, 5, 2, 7, 6, 2, 1), so the jump is seamless, *inferred* |
| `ColorTex` | colormap_water.dds (+0xC4) | [mod: tfh/map/terrain/colormap_water.dds] |
| `OverlayTex` | map_overlay_tile.dds (+0x2C0), 512x512 | [mod: map/terrain] |
| `NormalTex` | sea_normal.dds (+0x2CC), 512x512 | [mod: map/terrain] |
| `FOWTex` | the generated fog, 1024x1024 L8 (+0x4168→+0x18), B.2 | [exe] |
| `color0`, `color1` | the generated sea colour rasters, 1024x1024 (+0x1C, +0x20), B.2; the coloured techniques only | [exe] |
| `stripes` | stripes.dds (+0xC0), 128x128; the coloured techniques only | [mod: map/terrain] |
| never set | WorldViewProjectionMatrix, WorldMatrix, LightPosition, LightDirection, vAlpha, MapWidth, MapHeight, BorderWidth, BorderHeight, ColorMap* | none read by the install's water techniques |

**The simple path binds no texture** [exe]: WaterSimpleColor gets color0, color1 and stripes, WaterSimple nothing. So
WaterSimple's FOWTex is whatever an earlier non-simple frame left on the effect, and with simpleWater on from the start it
was never bound - by Direct3D 9's rule that an empty sampler reads (0,0,0,1), its fog term would be saturate(0 + 0.6) =
0.6 (*inferred*); and bound, saturate(L + 0.6) is 1 for L = 0.6 or 1.0, so in a full game simple water shows no fog at
all. **A mismatch of the install's, kept**: water.fx's `FOW_SIZE_Y 512`, used only for half-texel offsets, against a fog
texture 1024 tall [exe] - its ±0.5/512 in y is a whole texel.

### B.2 The generated textures: `CViewsTextureManager`

0x4C bytes, vftable VA 0x15E3E9C, RTTI base CLostDeviceInterface (viewstexturemanager.cpp), made by the CProvinceManager
constructor (0x480D00). Slot 1 (0x4825B0) makes the textures and slot 0 (0x482530) releases them - all six one level,
D3DUSAGE_DYNAMIC, D3DPOOL_DEFAULT, so a lost device takes them and a reset makes them again. Slot 1 also sets +0x44 = 1 and
+0x48 = 5; `MapGraphics_Update` counts +0x48 down a frame at a time and at 0 calls `Map_RefreshColourTextures(textures,
entries, 1)`: **every texture is filled five frames after it is made or made again** [exe].

| field | size, format | shader input | filled by |
|---|---|---|---|
| +0xC | 256x256 A8R8G8B8 | terrain_2_0.fx tex2 = GeneralTexture (the beaches too) | Map_UpdateProvinceColourTexture, from each entry's colour +0 |
| +0x10 | 256x256 A8R8G8B8 | tex3 = GeneralTexture2 | the same, from colour +4 |
| +0x14 | 512x512 A8R8G8B8 | TerrainShader_Border tex4 = BorderDirectionTexture | ViewsTextureManager_UpdateBorderLookup (B.3) |
| +0x18 | 1024x1024 **L8** | water.fx FOWTex (read .b), terraincognita.fx FOWTex (read .r) | FowTexture_Update |
| +0x1C | 1024x1024 A8R8G8B8 | water.fx color0 | WaterTexture_Update |
| +0x20 | 1024x1024 A8R8G8B8 | water.fx color1 | WaterTexture_Update |

**The colour source**: CProvinceManager +0x2C, the province graphics entries, one per province id - +0 and +4 the two
packed 0xAARRGGBB colours a map mode's colouring loop writes, +8 the CProvinceTemplate, +0xC the CMapProvince;
`Map_RefreshColourTextures` copies it into the manager's +0x24.

**The province colour lookups (+0xC, +0x10)**: one texel per province from id 1, texel 0 never written [exe]; **x = id mod
256, y = id / 256**, bytes B G R A, each channel ×255 truncated. **Map style 0** (Terrain, Weather): g = 0.1 where the
province's byte +0xC is set, else 0, r and b kept, a = 1. **Other styles**: +0.1 on r, g and b, capped at 1, a = 1, where
byte +0xC is set, else the colour as written. Byte +0xC is the province's selection flag - *read since*: B.9, which gives
the lift exactly. On the land side the mesh's SHORT2 TEXCOORD0 is (id & 0xFF, id >> 8) - the shipped cache's first land chunk carries
(80, 40) for province 10320 - so the shader's (vProvinceId + 0.5)/256 lands on exactly that texel. **In style 0 texture +0xC
is the province-state texture**: r 1.0 where the player's intel is 2 or more, 0.5 below it, 0 where the province is not
simulated; b the frozen share, in the Weather mode only; what `PixelShader_Map2_0` makes of them is
`FINDINGS-weathersim.md`, C.1.

**The sea colour rasters (+0x1C, +0x20)**: `WaterTexture_Update` (0x4821D0) does nothing unless the entry count equals CMap
+0x21FC; for each texel (x, y) of 1024² the province raster is read **nearest** at (trunc(x·W/1024), trunc(y·H/1024)), and
where that is a province with an id above 0 the texel is entry[id] +0 (color0) or +4 (color1), word for word, no 0.1 lift;
else 0x80808080. Row y is world z = y·H/1024, which matches the quad's v [exe].

**The fog (+0x18)**: `FowTexture_Update` (0x4813C0) first calls WaterTexture_Update, in every style; then for each texel of
1024², xf = x·W/1024 and yf = y·H/1024, four raster samples at (⌊xf+0.5⌋|⌊xf+1.5⌋, ⌊yf+0.5⌋|⌊yf+1.5⌋), each clamped into the
raster, each worth [exe]: **1.0** where the province is simulated (template +0x13D) and the player's intel of it (CMapProvince
+0x370 indexed by the player id, CCurrentGameState +0xC34) is 2 or more; **0.6** simulated, intel under 2; **0** not
simulated; for an **id-0 pixel**, 1.0 where a simulated real province lies 1 to 3 pixels left, right, above or below
(0x480BA0 / 0x480C50), else 0; with **no template**, 1.0 where the byte at VA 0x170AD30 is 0 (it starts at 1, so normally
0). The four blended bilinearly by frac(xf) and frac(yf); the byte stored trunc(255·value). Where the screen's slot 83
answers true the intel test is skipped - CInGameIdler's is `xor al,al; ret`, so never in a game.

**When they are rewritten** [exe]: the land lookups by every mode setter and the other callers of
Map_RefreshColourTextures (45 in all); the sea rasters there too, but only for styles 16, 18 and 19, and on every fog
rebuild; the fog only by the five-frame refill, Map_RefreshColourTextures with its flag set (front-end enter, game setup,
history date, MapGraphics_Update and others; the mode setters pass 0), `CInGameIdler_RefreshMap` (0x2516A0) while its flags
(idler +0x84 & 0xF) are set - Province_SetController sets bit 0 and 0x100, *corrected* in B.9 from "bit 1" - and MarkSimulatedProvinces. No daily or hourly path to the
fog was found, so a change of intel alone does not reach the sea's fog until one of these runs (*inferred*; the limit the
direct-call scan and `FINDINGS-weathersim.md` C.1's scan for writers of +0x84).

### B.3 Land borders: `MapGraphics_DrawLandBorders` (0x45E9B0), TerrainShader_Border

Drawn below `border_cutoff` with layer-mask bit 0x2 (`FINDINGS-farmap.md`, A); device ALPHABLENDENABLE 1, SRCALPHA /
INVSRCALPHA. **Parameters** through the handles the setup fetched by name [exe]: ViewMatrix and ProjectionMatrix from the
view object; LightDirection the map light's +0x138..+0x140; ColorMapWidth/Height colormap.dds's size (1872x720 [mod:
tfh/map/terrain]) and ColorMapTextureWidth/Height the powers of two above; MapWidth/MapHeight W, H; BorderWidth/BorderHeight
graphics +0x194/+0x198 as floats (*inferred* the tile's width and height, from 0x469E60's use of them). The terrain handles:
tex0..tex3 +0x1A4..+0x1B0, WorldMatrix +0x1B4, ViewMatrix +0x1B8, ProjectionMatrix +0x1BC, WorldViewProjectionMatrix +0x1C0,
LightDirection +0x1C4, ColorMapHeight +0x1C8, ColorMapWidth +0x1CC, ColorMapTextureHeight +0x1D0, ColorMapTextureWidth +0x1D4,
BorderWidth +0x1D8, BorderHeight +0x1DC, MapWidth +0x1E0, MapHeight +0x1E4 (section A's to record). **tex4** the border
lookup (+0x4168→+0x14); **tex2** borders.tga / borders2.tga / borders3.tga by `border_heights` (2048x256 each [mod:
map/terrain]); the declaration BorderVertexDecl (+0x42A4) SHORT4 POSITION + D3DCOLOR COLOR0, 12 bytes. **For each tile**
(tile = +0x19C + 0x3C0·index, the visible set +0x78/+0x88) whose border mesh at tile +0x294 is not empty:
WorldViewProjectionMatrix = tile +0x1FC, WorldMatrix = tile +0x17C, AbsoluteWorldMatrix = tile +0x13C.

**The vertex** is the cache's, not the rebuild path's: `QuadCache_LoadTile` makes the +0x294 mesh, 12 bytes a vertex. A
decode of `tfh/map/cache/all_quads.bin` finds 15,625 runs of them, each a one-pixel quad: **x, z** tile-local pixels
carrying a corner flag of ±1000 - the vertex shader takes sign() as the uv corner and puts the position at value −
1000·sign + 0.5, so x = −1002 is position −1.5 with u = 0 and x = 999 is −0.5 with u = 1; **u, v** (SHORT4 .zw) a texel of
the lookup, **u + 512v = 14·id + slot** (471 + 512·286 = 14·10493 + 1); **D3DCOLOR** R = id & 0xFF, G = id >> 8 (10493 =
40·256 + 253 in the sample), B and A multiples of 8 - the province and diagonal pattern columns the rebuild path takes from
the border bitmap's bytes 0 and 3, ×8, the shader's vBorderOffsetColor .b and .a. The id the colour carries matches the id
the lookup texel implies on every vertex sampled.

**The lookup** (0x4826C0) gives each province 14 texels from 14·id [exe]: **one for each adjacency entry** (template +0x90),
**0x000000FF where the neighbour has the same controller (CMapProvince +0x338), 0x400000FF where another** - in the shader
B = 1 makes TexCoord.x += vertex .b and **A = 0.25 moves the province-border sample one band down borders.tga, into the
country row**: that is how a province border and a country border are told apart [exe; the band from the install's
shader]; **then one for each (x, y) junction pixel** of the manager's +0x42B4[id] - *corrected in B.7, which was "(key,
index) pair" here* - looked up in the border manager's corner cache: A = byte0·8, R = byte2·8, G = byte3·8, B = 0, selecting
country (x += r) and diagonal (x += g) columns (B.7); unused texels nought; written as one linear run, the pitch ignored
(512·4 bytes a row anyway), **with no cap at fourteen** (B.7). **Rebuilt** by `BorderManager_Tick` (each frame from
MapGraphics_Update) once the border manager's dirty byte +0x59 is set and its +0x5C countdown runs out - set only on a
device reset (B.7) - and by 0x460D30 with flag bit 0. **The rebuild path is left open**:
`QuadBuild_EdgeVertices` (0x4754D0) writes 24-byte records with float x, z, which do not fit the 12-byte declaration; it runs
only when the cache is made again ("REcreating quads"), and the install ships the cache.

### B.4 Water borders: `MapGraphics_DrawWaterBorders` (0x45DD50), borders_2_0.fx

Device [exe]: ZWRITEENABLE 1, **ZENABLE 0**, ALPHABLENDENABLE 1; after, ZENABLE 1 and ALPHABLENDENABLE 0. Technique
WaterBorderShader; tex1 water_borders (+0x2C4) and tex3 water_diag_borders (+0x2C8), `.tga` in the executable and `.dds` in
the install, 1024x64 [mod: map/terrain]; the declaration WaterBorderDecl (+0x42B0), SHORT2 POSITION + UBYTE4 TEXCOORD0
(vUV_Offset); one 0x24-byte mesh for each tile at +0x42D4, WorldViewProjectionMatrix = tile +0x1FC. **ProvinceBorderShader,
CountryBorderShader and RiverShader of borders_2_0.fx are named nowhere in the image** - a .rdata string scan finds
`WaterBorderShader`, the positive control, and none of the three - so their BaseTexture (/cache/border_bitmap.bin) is fed to
no shader.

### B.5 Terra incognita, briefly

Scenarios only. FOWTex the same L8 fog (read .r); OverlayTex map_overlay_tile.dds; Time, CameraPosition and
ViewProjectionMatrix as the sea sets them; TerraIncognitaDecl (+0x42A8) FLOAT4 POSITION; three map-sized quads; device alpha
blend SRCALPHA / INVSRCALPHA and a CULLMODE.

### B.6 Not established

CMapProvince byte +0xC (the 0.1 lift); how the water border meshes are built (0x4374D0) and their UBYTE4 values; the 24-byte
record of the rebuild path; 0x460D30's flag bits 1 and 2; BorderWidth/BorderHeight's values; whether anything daily
reaches the fog beyond the scans above. (The border lookup's extra entries and the setter of +0x59: B.7.)

Frontier: 0x4727B0, 0x4374D0, 0x4DD860, 0x474F00, 0x4571F0.

### B.7 The land border manager

*Read 2026-11-06 by a delegated agent and checked by the collecting session off the bytes: BorderManager_Tick's push of
(1, 1, w − 2, h − 2) at 0x83654B onto a local deque that is freed unread, 0x837980's block-map push of 16-byte elements,
the lookup writer's unconditional `mov edi, [ebp-0x14]` (14·id) at 0x882820 with no bound after it, and `push 0xA0` at
0x853B8B before the call to 0x834280 whose result is stored at +0x415C.*

**In one line.** The texels after a province's adjacency texels describe the **junction pixels** of its border mesh - the
pixels where three or four provinces meet - each a 4-byte entry of a sparse "corner cache" built once from the shipped
`border_bitmap.bin` around the pixels `border_adj.bin` lists, whose country byte is recomputed from the controllers
whenever a controller changes.

**Coordinates.** A pixel (x, y) is the engine's: x a column of provinces.bmp, y counted from the south; the file's stored
row is r = H − 1 − y (A.1). The bitmap and map.bin rasters are (W+1) × (H+1), row y at offset y·(W+1).

**The cache files** [exe the format; the contents derived from map/provinces.bmp and definition.csv, made again when CMap
+0x28 says the cache is stale]:

- **`border_adj.bin`**: int32 L (TFH 14,169, one per province id including 0), then L × (int32 n, n × (int32 x, int32 y)).
  BorderAdjCache_Read (0x474600) reads it into WaterObject +0x42B4 (a vector of 16-byte std::vectors); BorderAdjCache_Write
  (0x474310) writes it back where the cache is stale or the read failed; QuadBuild_EdgeVertices fills the lists on the
  rebuild path. *Measured*: 345,888 bytes parse exactly; 36,151 pairs, 0..9 a province, 10,107 provinces with any; x
  612..5518, y 79..2159. **Every pair is a pixel of its own province** with 3 or 4 distinct ids among it and its four
  neighbours, and no pixel is listed twice. Every one of the cache's 151,408 border vertices whose slot is past the
  province's adjacency count (as `adjacencies.bin`, the same as template +0x90) sits on a corner of pair (slot − count)'s
  pixel, at (x ± 0.5, y ± 0.5) - but one quad, ~45 px off.
- **`border_bitmap.bin`**: no header, (W+1)·(H+1)·4 bytes - TFH 5617 × 2161 × 4 = 48,553,348, the file's exact size.
  CBorderManager_Construct (0x434280) reads it whole into +0x3C; where the cache is stale or the file missing,
  CBorderManager_FillBitmap (0x434910) makes it and it is written back. Bytes: **0**, the province pattern column 0..31 -
  the province-border mask (1 = x+1, 2 = x−1, 4 = y+1, 8 = y−1, and corner codes 3, 7, 11..15, 19) ORed with **0x10**
  where the two sides' first CMapProvince +0x358 entries differ, which the record calls the regions, so a region border
  (*inferred*); **1**, a shade 0x40 or 0xFF the lookup never reads; **2**, the country column, **0 in every pixel of the
  file**; **3**, a diagonal-cut code 1..6, + 0x10 for a region cut. *Measured*: byte 0 takes 0..31 and byte 3 0..6 and
  17..22; on all 151,404 junction vertices on their pixel, the vertex colour's B and A are byte 0 × 8 and byte 3 × 8 there.
- **`map.bin`** (its owner at VA 0x486F10, global [0x1A85578]): a 20-byte header (`MAP_CACH`, dword 'E', int32 2, int32
  3), int32 N (TFH 722), N × 8 bytes, then the (W+1)·(H+1) byte raster (12,144,137 = 24 + 5,776 + 12,138,337). Its values
  are 0, 1, 2, 4, 8, 16, 32, 48; the border code reads only the low nibble, as diagonal-cut flags. Its builder (0x4873C0)
  marks staircase pixels of the province raster; not read further.

**The corner cache.** CBorderManager::BuildCornerCache (0x436D60) runs once, from CProvinceManager_CreateMeshes ("Used RAM
(corner cache)"): for each pair pixel an entry with the bitmap's four bytes, marked; then each of (x±1, y) and (x, y±1),
where absent and inside the bitmap, with that pixel's own bytes, unmarked. Each row sorted by x and flattened: +0x8C row
starts (H+2 ints), +0x90 x as int16, +0x94 **active** (marked and 1 ≤ y ≤ H−1), +0x9C the four bytes, +0x98 for each
active entry the index of the same x in rows y−1 and y+1, each less its own index. It then **frees the bitmap** and sets
+0x88: in a running game nothing of `border_bitmap.bin` remains but these entries.

**The lookup.** ViewsTextureManager_UpdateBorderLookup (0x4826C0), province i from texel 14i: a texel for each adjacency
(B.3); then for pair k the entry for (x, y), found by a linear search of row y - **A = byte0·8, R = byte2·8, G = byte3·8, B =
0**; before each province, the texels from where the last stopped up to 14i zeroed. In the shader B = 0 ignores the vertex
colour: the province sample stays in the province row at column byte 0, the country row at column byte 2 and the diagonal
row at column byte 3 [mod: gfx/FX/terrain_2_0.fx, map/terrain/borders*.tga]. **There is no cap at 14** [exe]: province
i's run is unbounded and province i+1 starts again at 14(i+1), overwriting it. In TFH 162 provinces have more than 14
adjacencies and pairs together, and about 550 cache vertices read texels past their own fourteen - the next province's.

**What recomputes it** [exe]: MapGraphics_RefreshByFlags (0x460D30), from CInGameIdler_RefreshMap with the idler's +0x84
flags. **Bit 0** runs, over every corner entry, BorderManager_UpdateControllerBits (0x4365B0), BorderManager_ApplyDiagonalCuts
(0x4369E0), BorderManager_SpreadCornerBits (0x436BC0), then the lookup. Province_SetController ORs bit 0 in (VA 0x4A3585)
only where the controller id really changed; 0xB is ORed at VA 0x661624 (*likely* CInGameIdler::Enter, by the nearest
recorded entry); 0xF by ApplyCustomGameSettings and at VA 0x4E9FC2 and 0x6EFE5E. So a change of controller rebuilds both
halves of the lookup.

**The dirty byte** [exe]: CBorderManager +0x59 is set only by CBorderManager::OnResetDevice (slot 1, 0x437950), with the
countdown at 2, so BorderManager_Tick rebuilds the lookup from the entries as they stand after a device reset, which the
D3DPOOL_DEFAULT texture needs; **the tick changes no entry**. The "bitmap refill" B.3 relayed from the record is a deque
push_back (DequeRect_PushBack, 0x437980) of the rectangle (1, 1, W−1, H−1) onto a deque destroyed unread - vestigial.

**The three passes** visit, in row order and then x order, the active entries with x ≤ W−2 and y ≤ H−2. L, R, S, N are the
entries at (x−1, y), (x+1, y), (x, y−1), (x, y+1), their bytes read as they stand; m(·) the map.bin byte; valid(p) a pixel
whose id has a template, is not 0 and is land; b0..b3 an entry's bytes.

1. **Controllers** (0x4365B0). Pixels c = (x, y), r = (x+1, y), l = (x−1, y) only where x ≥ 2, n = (x, y+1), s = (x, y−1)
   only where y ≥ 2. Where three or more of the five have no template (or are left out by x ≥ 2 / y ≥ 2), b2 is left.
   Otherwise b2 = 0 and, where valid(c), with C = ctrl(c): b2 |= 1 if valid(r), ctrl(r) ≠ C and (m(x+1, y) & 0x0E) == 0;
   |= 2 for l with (m(x−1, y) & 0x0B) == 0; |= 4 for n with (m(x, y+1) & 0x0A) == 0; |= 8 for s with (m(x, y−1) & 0x0F)
   == 0.
2. **Diagonal cuts** (0x4369E0). Where b2 == 0: b3 &= ~8, next. Where b3 == 0 or (mm = m(x, y)) & 0xF == 0: next.
   Otherwise four tests in order, each on b2 as it stands: (b2 & 5) and (mm & 1): b3 |= 8, and b2 &= ~4 unless N.b2 & 8,
   b2 &= ~1 unless R.b2 & 2; (b2 & 0xA) and (mm & 2): b3 |= 8, b2 &= ~8 unless S.b2 & 4, b2 &= ~2 unless L.b2 & 1; (b2 & 9)
   and (mm & 8): b3 |= 8, b2 &= ~8 unless S.b2 & 4, b2 &= ~1 unless R.b2 & 2; (b2 & 6) and (mm & 4): b3 |= 8, b2 &= ~4
   unless N.b2 & 8, b2 &= ~2 unless L.b2 & 1.
3. **Spread** (0x436BC0), t = b3 & 7. t ∈ {1, 2}: L.b2 |= 1 if b2 & 2; R.b2 |= 2 if b2 & 1; N.b2 |= 8 if b2 & 4; S.b2 |= 4
   if b2 & 8. t = 3: b3 bit 3 set if L.b3 == 9 or N.b3 == 9, else cleared; t = 4 the same with L.b3 == 10 or S.b3 == 10;
   t = 5 with R.b3 == 9 or S.b3 == 9; t = 6 with R.b3 == 10 or N.b3 == 10 - whole-byte compares, so a code carrying 0x10
   never matches.

**Kept as read** (*inferred* consequences of what is not reset; not observed live): an active entry with three or more
template-less pixels among its five keeps its byte 2; unmarked neighbour entries take bits from pass 3 and are never
reset; byte 3 bit 3 of a type-1/2 entry survives where byte 2 is not nought and no test of pass 2 fires. So later
refreshes may carry state from earlier ones; a program working from the file reproduces the first refresh exactly.

**Corrections.** B.3's "(key, index) pair" is an (x, y) pixel, and its "who sets +0x59 was not read" is answered above;
the record's BorderManager_Tick "refill", as above. Tooling, trap 2: OnResetDevice opens `mov eax, [abs]` (0xA1), outside
`functionStart`'s set of prologues, so `fieldchain.py` gave its +0x59 store to 0x4374D0.

**Not established.** FillBitmap's ladder of corner codes (from the decompilation, not checked branch by branch), so what a
`border_bitmap.bin` made again would hold for a mod's own map; map.bin's raster half (its list of N pixels is the rivers'
sources, C.6); template +0x21
(byte 1's shade); CBorderManager +0x14, +0x18, +0x34, +0x48, +0x4C, +0x50, +0x58, +0x68, +0x78; RefreshByFlags' bits 1 and
2; what CFrontEnd's call passes; the one quad off its pixel. What is kept as read wants a live check - BiceLib dumping the
lookup texture after a change of controller, set beside this rule.

Frontier: 0x437AD0, 0x437B60, 0x437F70, 0x4374D0, 0x87DB0, 0x873C0, 0x87C90.

### B.8 The water borders

*Read 2026-11-06 by a delegated agent (fragment `mapdraw-waterborders.json`), measured on TFH's `tfh/map/terrain.bmp`,
`provinces.bmp`, `definition.csv`, `cache/border_bitmap.bin` and the install's `map/terrain/water_borders.dds` and
`water_diag_borders.dds`.*

**In one line.** Every water pixel with a province-border or diagonal code in `border_bitmap.bin` gets a one-pixel quad
whose four bytes are its uv corners and the bitmap's bytes 0 and 3, each picking one 64-texel column of its texture; built
once at load, one mesh for each 50×50 tile, from the map files alone, and drawn at every height over everything drawn
before them, as faint black lines.

**Who builds them** [exe]. `CProvinceManager_CreateMeshes` resizes `+0x42D4` to rows × columns MeshBuffers (0x46B510; new
elements zeroed, so a triangle list) and calls `MapGraphics_BuildTileWaterBorders` (0x469E60) for every tile at 0x457F8F -
after the border manager has read `border_bitmap.bin` (B.7) and **before** BuildCornerCache frees it (0x458768). 0x469E60
takes col = i mod +0x18C and row = i div +0x18C and passes (50·col, 50·row, 50, 50) and `&meshes[i]` to
`BorderManager_BuildWaterBorderMesh` (0x4374D0), the border manager (+0x415C) in ESI; each has no other caller.
`fieldchain` finds +0x42D4 touched only by the constructor, the release (0x44FCF0), this resize, the draw and 0x469E60, so
**nothing rebuilds them in play** - no controller, mode or setting - and their buffers are D3DPOOL_MANAGED (MeshBuffer +0x14
= 1), so a reset does not lose them.

**Which pixels** [exe]. x from x0 to x0+49 outer, y from y0 to y0+49 inner; kept where x < W and y < H; terrain.bmp's byte
there (CMap +0x20E4, loaded as the province raster is, so its rows run the same way; 0 outside) indexes through
`terrain_by_palette_index` (+0x2220) an entry whose CTerrain (+0xC) has `is_water` (+0x48); 2 ≤ x ≤ (W+1) − 2 and 2 ≤ y ≤
(H+1) − 2 against the bitmap's +0x40/+0x44; the scratch has room (60,000 vertices; a tile needs at most 10,000); and
**bitmap byte 0 or byte 3 at (x, y) is not 0**. So x in 2..W−1, y in 2..H−1, y from the south. *Measured*, TFH: index 254
(`ocean1`, `is_water = yes`) is the only water index; **668,662 quads** in 3,638 of the 4,972 tiles, at most 367 in one;
every quad's province a water province.

**What the codes mean on water** (*measured*, as B.7's bit table predicts). On the quads a set bit of byte 0's 1, 2, 4, 8
has a different province on that side 394,659 times and the same 88 (all on the y bits), and **never** land: the shipped
bitmap carries no coast bit from a water pixel. Of the 282,519 diagonal-only quads (byte 0 = 0), the 2,155 that touch land
and no other sea province all have byte 3 = 20 or 21, which draws nothing. So **this system draws the borders between sea
provinces; the coast is the surf's** (C.1 #6). Byte 0: 0 on 282,519, 1/2/4/8 on 86,030/86,066/103,426/101,613, 16 or more on
8; byte 3: 0 on 252,085, 1..6 on 375,479, 19..22 on 41,098.

**The vertex** [exe], 8 bytes (SHORT2 POSITION + UBYTE4 TEXCOORD0). mid = (x0 + 25, y0 + 25), dx = x − mid.x, dy = y −
mid.y (computed in doubles as trunc(d ± 0.5 − 0.5), exact for a 50-pixel tile):

| vertex | X | Y | u_corner | v_corner | byte 6 | byte 7 |
|---|---|---|---|---|---|---|
| v0 | dx − 1 | dy − 1 | 0 | 1 | bitmap byte 0 | bitmap byte 3 |
| v1 | dx − 1 | dy | 0 | 0 | 〃 | 〃 |
| v2 | dx | dy | 1 | 0 | 〃 | 〃 |
| v3 | dx | dy − 1 | 1 | 1 | 〃 | 〃 |

Indices n, n+1, n+2, n+2, n+3, n (16-bit), in visiting order; stride 8; the draw sets WaterBorderDecl itself.

**What the shader makes of it** [mod: gfx/FX/borders_2_0.fx]. Position (X + 0.5, 0.0, Y + 0.5 − 0.7) by the tile's
world-view-projection (tile +0x1FC, A.4), then clip y += 2.0 (*inferred*: about 0.83 map units north at any height, which
roughly cancels the 0.7). Texture coordinates: base ((1 + 50·u_corner)/1024, v_corner), so u runs over texels 1..51 of a
64-texel column and v the whole height (v 0 north); ProvCoord.x = base + byte0/16, DiagCoord.x = base + byte3/16; both
clamp, so **a code of 16 or more lands on texel column 1023, transparent in both: those quads draw nothing**. The pixel
shader premultiplies each sample and takes the maximum of rgb and of alpha.

**The art** (*measured*, [mod: map/terrain]). water_borders.dds 1024×64 DXT3, water_diag_borders.dds 1024×64 A8R8G8B8,
one mip each; column c is code c. Column 1 (x+1) has its line at window texels 42..51, column 2 at 1..7, column 4 (y+1) at
rows 0..9, column 8 at rows 55..63 - agreeing with the corner bytes. All province columns are black at **alpha 0.2 at
most** (2.3% to 7.6% darkening over a quad); diagonal columns 1 and 2 full diagonals at 0.216, 3..6 small corner marks;
diagonal columns 9..14 red (215, 0, 0) at alpha 1, unreachable here - the mesh carries the file's byte 3, never the corner
cache's bit 3.

**The draw** (0x45DD50, read whole) [exe]. ZWRITEENABLE 1, ZENABLE 0, ALPHABLENDENABLE 1; WaterBorderShader, Begin(0),
pass 0; **the only parameters set** are tex1 = water_borders (+0x2C4), tex3 = water_diag_borders (+0x2C8), by name, and
WorldViewProjectionMatrix (+0x27C) = tile +0x1FC for each visible tile whose mesh has any. The blend factors are SRCALPHA
/ INVSRCALPHA as DrawWater left them. Whether ALPHATESTENABLE is on here is C.2's open item.

**No gate** [exe]. The scene calls it where mask & 0x200 and the border manager exists (0x45C218..0x45C22C) - the land
borders' call in the same function, testing `border_cutoff` and mask 0x2, the positive control. Neither the draw nor the
builder reads the height. Every immediate written to `[reg+0xF0]` in .text (0xFF9A, 0xFFAA, 0xFFBA, 0xFFBB, 0xFFBE, 0xFFFF;
`fieldchain --field 0xF0 --writes`) has 0x200 set, so no map mode hides them; immediates only. **So the far view does not
hide them in code**; *inferred*, the art does: above 500 a map pixel is at most about two screen pixels, and a line is 20%
black over a fifth of it, with no mips.

**Corrections.** None to what was published; B.6's open item is answered. The record's `CBorderManager_Construct` comment
("what either is for was not read", +0x68/+0x78) - they are this builder's scratch.

**Not established.** What a `border_bitmap.bin` made again would hold (B.7's ladder); whether 0x10 in byte 0 is a region
border; ALPHATESTENABLE at the draw; the +2.0 clip shift's exact size off the screen's middle; a 24-bit terrain.bmp's byte
(the first channel, *inferred*); 0x44FCF0.

Frontier: 0x798D80 (likely memcpy), 0x3C62C0, 0x438090, 0x437DC0, 0x46B510, 0x44FCF0.

### B.9 The highlight

*Read 2026-11-06 by a delegated agent (fragment `mapdraw-highlight.json`); the collecting session checked the three flag
stores off the bytes - `or [eax+0x84], 1` at 0x4A3585, `or [eax+0x84], 0x100` at 0x4A35CE, `or [eax+0x84], 0x200` at
0x49E47D and 0x49E592. Addresses are VAs unless marked rva.*

**In one line.** A selected province is lit by one thing alone - Map_UpdateProvinceColourTexture adding 25/255 to its
texels in both colour lookups - the byte it tests is the province's own selection flag, the lookups are refilled whole by
the in-game screen's per-frame refresh after any province is selected or deselected, and hovering marks nothing on the
map surface.

**The byte** [exe]. The province graphics entry's +0xC is the CMapProvince itself - MapMode_VictoryPoints_ColourLoop reads
`[entry+0xC]` +0x370/+0x374, +0xD4 and +0x34 (0x8665FF..0x8666B6) - and the highlight byte is **CMapProvince +0xC**.
CProvince carries CSelectable at +8 (RTTI); its constructor writes CSelectable's vftable 0x15C0694 at +8 and `mov byte
[esi+0xC], 0` (0x49472E, 0x494735), so +0xC is CSelectable +4 - the selected byte the record names on CUnit +4.
MapGraphics_PickUnderPointer hands a province over as province + 8 (0x641877).

**Who writes it.** CSelectable_Select (`mov byte [edi+4], 1`, 0x4AD621) sets it; Selection_Remove (0x4AD6A7),
Selection_Clear (0x4AD79B) and CInGameIdler::Deselect (0x656C7B) clear it; the constructor zeroes it. Census (a resumed
sweep, 3,084,674 instructions, 1,005 resumes, last at 0xD2AFFE against the section's end 0xD2B000): every byte store to
[reg+4] within 40 instructions of a call through the OnSelected/OnDeselected slots gives those four and no other; every
byte store to [reg+0xC] (1,358) filtered to those with a CMapProvince displacement within 30 gives 73 - 68 after `operator
new`, 4 list-node marks (0x5B565F, 0x5CA5B3, 0x5CFEEB, 0x8A5172), 1 the constructor (the positive control). Readers through
an entry: Map_UpdateProvinceColourTexture's two (0x880F94, 0x881299) and a CRT read. Limit: a writer reaching the province
through a register with no province displacement nearby would not be seen.

**So which provinces are lit is which are selected** (`FINDINGS-selection.md` A.4, `FINDINGS-provinceview.md` A.1): a plain
click on land selects it alone; Shift-click adds or removes provinces, so several may be lit; the drag box never takes a
province; selecting a unit, Escape, the view's close button or a click elsewhere clears it. The occupier flag in the
province view selects that country's capital; a base row in the outliner whose unit is not the player's selects the base's
province. **A sea zone never stays lit**: CSelectable_Select sets the byte and appends it, then CProvince::OnSelected
(0x49E240) sees `template +0x22 == 0` and runs CInGameIdler::ClearSelection; and the sea is drawn from the sea rasters,
which carry no lift (B.2). The byte does not test `simulated` (*inferred*; only in a scenario).

**What is not lit.** The hovered thing (CInGameIdler +0x1DD4) is read only by HandleInput, CInGameIdler_UpdateCursor and
CInGameIdler::GetTooltip. The graphics owner's +0x60D0, the province graphics under the pointer, is written by
PickUnderPointer, CFrontEnd::Update and CNudgeIdler and read by nothing (a disp32 search finds 4 writes and no read; the
known PickUnderPointer write is the positive control). The selected units' provinces, the placing mode (14), the air orders
window's area and mode 17's box colour through the entries' own colours and never touch the byte. The land border lookup
reads only controllers (B.3, B.7); highlight.fx is named nowhere (C.4).

**When it is refilled** [exe]. CProvince::OnSelected and OnDeselected (0x49E4F0) OR **0x200** into the in-game screen's
refresh flags, CInGameIdler +0x84, and push the province id onto +0x88 (or -1 once 110 are queued); no other writer of
0x200 (every immediate OR/MOV into [reg+0x84] / byte [reg+0x85]; Province_SetController's bit-0 store the positive
control). CInGameIdler_RefreshMap runs every frame from CInGameIdler::Update (0x655EF4; one `ret`, no branch over the call);
where 0x200 is set it calls Map_RefreshColourTextures(textures, entries, 0) - **both 256² lookups rewritten whole**, the fog
untouched, +0x88 not used - then sets +0x84 = 0 and empties +0x88. The click is handled after it in the same Update
(HandleInput, 0x656471), so a click shows in the next frame's refill (*likely*; the frame's order of update and draw not
read). Every other refill re-applies the lift, the byte being tested at fill time: the mode setters and colouring
routines (45 call sites), RefreshMap's 0x100 arm, the five-frame refill after a reset (B.2) - so a change of mode keeps the
selection lit.

**The lift, per style** [exe the texel; mod: gfx/FX/terrain_2_0.fx the shading - the base game's file, tfh/gfx/FX having
none]. The colour is unpacked to floats (rva 0x662D30, byte / 255) and written back as trunc(× 255.0); the style (settings
+0xF4) read once per call.

- **Style 0** (Terrain, Weather): both textures r and b kept, **g = 25** where selected and **0** where not, a = 255. Land,
  TerrainShader_Graphical: `((tiles, winter-greyed by b, + 0.3b) × r) + g` - a selected province gains **+25/255 ≈ 0.098
  on r, g and b after the fog multiply**, so it shows under full fog. Beaches, BeachShader_Graphical: `+ 1.1g` (≈ 0.108)
  after the fog, before the winter lerp, which keeps it whole (GREYIFY sums to 1).
- **Every other style**: selected, each of r, g and b + 0.1 capped at 1.0 - **+25, or 255 from 230 up** - and **alpha
  forced to 255**; not selected, the colour as the mode wrote it; both lookups, so both stripe colours. Near land (General):
  `lerp(grey terrain, stripe-lerp(C1 − 0.7, C2 − 0.7), 0.3) × 1.5` adds **0.3 × 1.5 × 25/255 ≈ 0.044** below the cap. Far
  land (General_Low): through the overlay blend, 0.45 × 2·O·0.098 where O < 0.5, else 0.45 × 2(1 − O)·0.098 (the file's
  test uses O.r for r and g, O.b for b). Beaches General and General_Low ≈ +0.044.
- **The sea**: none, in every style.

**Other selection marks, none of them a province's.** For a selected unit, the counter rings (`FINDINGS-hierarchy.md`
section 6) and a `selection_projection` CUnit::OnSelected makes on the anchor (+0x10) of its province's graphics entry
(interface/mapitems.gfx: gfx/test/selection.tga, size 5, spin 0.4, expanding 0.7 [mod]; read as far as the creation); a
right-click order's `legal_` / `illegal_selection_projection`; a building's picture's own highlight
(CProvinceBuilding::OnSelected); the drag box, a white 2-pixel ID3DXLine.

**Corrections.** B.2 and the record's CInGameIdler_RefreshMap said "Province_SetController sets bit 1" of +0x84: it ORs
**1** (bit 0, 0x4A3585, as B.7 has it) and **0x100** (0x4A35CE, through the province's +0xCC listener). The record listed
RefreshMap's recolouring as "supply, VP, strength, intel, terrain, weather": its table dispatches modes 1, 2, 4, 5, 6, 7,
8, 9 and 17, terrain (rva 0x266020) and weather only in the & 0xF arm. B.6's "CMapProvince byte +0xC" is answered.

**Not established.** The frame's order of update and draw (so the one-frame lag is *likely*); whether the lobby ever
selects a province (no direct CSelectable_Select call in CFrontEnd or CGameSetup; the slot-38 census too noisy to finish);
CInGameIdler::OnAlertClicked's second arm (0x64AEE2); whether forcing alpha to 1 shows (only with the alpha test on, C.2);
the scans' limits. A live check would settle the rest - BiceLib dumping texel (id mod 256, id / 256) of both lookups
before and after a click.

Frontier (rvas): 0x263340, 0x24ACB0, 0x266020, 0x272BE0, 0x4E7DD0, 0x2434C0, 0x1C05F0.

## C. The scene as a whole, and the smaller layers

**In one line.** The scene's draws, gates and state calls are listed in order (C.1); baseline device states are set after
every device creation and Reset, the only writer of ALPHAREF 8 / ALPHAFUNC GREATEREQUAL (C.2); effects go through
PhysFS and `D3DXCreateEffect` with no macros, flags 0 and no pool, and only the `*_2_0` files are named - there is no
1_1/2_0 test (C.4); every Begin in the scene passes flags 0, so D3DX puts a pass's states back at End.

**Corrections.** (1) `VertexBuffer_Draw` (0x6D4C30): +0x1C is the **FVF** (`SetFVF`, slot 89) and +8 the **vertex
declaration** (`SetVertexDeclaration`, slot 87) - the record had them swapped; checked by the collecting session at VA
0xAD4C3D..0xAD4C61. (2) `MapObjects_RebuildTileStrips` (0x462260) builds the **trees**: MapTrees_Draw draws exactly its
+0x130/+0x134 slots, +0x144 buffers and +0xD4 types, both only under height 100; map/trees.txt's sheets are 512 × 256 (two
halves by four rows), so the Weather mode's +0.5 u (provinces below −5) is the snowed half. (3) `FINDINGS-farmap.md`'s
frontier 0x45F450 is not a function: rva 0x45F450 is the last byte of `mov edx,[edx+0xD0]` inside MapGraphics_DrawBeaches;
VA 0x45F450 (rva 0x5F450) is the vector helper of `FINDINGS-aifields.md`. (4) The surf's gate, graphics +0x42E9, is
settings.txt **`waves`** - set to 1 at the map build's `CREATE_WAVES` step (VA 0x85886F, checked). (5) 0x6BB7E0 is not a
draw (C.3).

### C.1 The frame and the scene, in order

**The in-game frame**, about rva 0x25704B: the device check 0x6759D0; FILLMODE WIREFRAME where CGraphics +0x6BC44 is set
(a debug flag); a pre-pass 0x2418B0 only under height 100 [exe], with GameSettings +0x58, layer-mask bit 0x4 and CGraphics
+0x6BC4C, into 0x675D10 - *inferred* the shadow map (+0x6BC4C also gates shadowmap.fx's resources in the reset path), not
read; **BeginScene**; **Clear(0, NULL, TARGET | ZBUFFER | STENCIL, 0xFF808080, 1.0, 0)** [exe] - mid-grey, depth 1.0;
**MapGraphics_DrawScene**. After it: 0x4482F0 (map object +0x1DDC, not read); HierarchyLines_Draw under its own gates;
**0x241950, the unit layers** - ALPHATESTENABLE 0 and ALPHABLENDENABLE 0, then the map object's layers at +0xC + 0x17C·k
through 0x673B10, each where its +0x179 is set, in the order +0xEE4 (always), +0xC, +0x8F4 (after 0x6659C0), +0x480 with Z
test and write off, +0x1060, +0x188, +0xBEC, +0x11DC, +0x304 with Z test off, +0xA70, ending with a second gate on
GameSettings +0x58 and mask 0x4 under counter_distance; then FILLMODE SOLID. The front end makes the same pair of calls,
DrawScene at 0x2EED3F and 0x241950 at 0x2EED57.

**MapGraphics_DrawScene (0x45BE50)**, each frame:

| # | what | effect / technique | gate | device states the engine sets |
| --- | --- | --- | --- | --- |
| 0 | setup | — | — | CGraphics +0x6BC88 = view; **SetViewport** (the view's first 24 bytes); **WORLD identity, VIEW the view +0x1C slot 91, PROJECTION slot 93**; samplers 0 and 1 MIN/MAG LINEAR, MIP NONE; **CULLMODE NONE** |
| 1 | land, MapGraphics_DrawTerrain | terrain_2_0.fx (key TerrainShader), Graphical / General / General_Low | always | at entry ALPHABLENDENABLE 0, SRCBLEND ONE, DESTBLEND ZERO, **CULLMODE CCW**; samplers 0/1 MIPMAPLODBIAS from a register and back; at exit SRCALPHA / INVSRCALPHA, CULLMODE NONE |
| 2 | beaches, MapGraphics_DrawBeaches | terrain_2_0.fx Beach* | always | ALPHABLENDENABLE 1, SRCBLEND SRCALPHA, **DESTBLEND ZERO**; sampler 0 LOD bias; at exit SRCALPHA / INVSRCALPHA, CULL NONE |
| — | | | | WORLD identity, ZWRITEENABLE 1 |
| 3 | rivers, MapRivers_Draw | river.fx RiverShader | mask 0x80 and graphics +0x4160; any height | ZWRITEENABLE 0; at exit ZENABLE 1, ZWRITEENABLE 1 |
| 4 | land borders | terrain_2_0.fx TerrainShader_Border | graphics +0x415C, border_cutoff > h, mask 0x2 | ALPHABLENDENABLE 1, SRCALPHA / INVSRCALPHA (and again at exit) |
| — | | | | WORLD identity, ZWRITEENABLE 1 |
| 5 | sea, MapGraphics_DrawWater | water.fx | mask 0x100 | ALPHABLENDENABLE 1, SRCALPHA / INVSRCALPHA; samplers 0/1 MIN/MAG LINEAR, MIP from a register; CULL NONE |
| — | | | | **ZENABLE 1** |
| 6 | surf, MapShore_Draw | beach.fx BeachShader / BeachShaderColor | graphics +0x42E9 (`waves`) | none of its own; SetVertexDeclaration |
| 7 | water borders, 0x45DD50 | borders_2_0.fx (key Borders) WaterBorderShader | mask 0x200 and +0x415C | ZWRITEENABLE 1, **ZENABLE 0**, ALPHABLENDENABLE 1; at exit ZWRITE 1, ZENABLE 1, ALPHABLEND 0 |
| 8 | trees, MapTrees_Draw | terrain_2_0.fx TreeShader | h < 100 [exe], mask 0x1 | none |
| 9 | terra incognita | terraincognita.fx | a scenario loaded | ALPHABLEND 1, SRCALPHA / INVSRCALPHA, CULL NONE |
| 10 | country names, CountryMapNames_Draw | fixed pipeline | level > 0, map style ≠ 0, no scenario | LIGHTING 0, ALPHABLEND 1, SRCALPHA / INVSRCALPHA, **ZWRITE 0, ZENABLE 0 (not put back)**; stage 0 MODULATE(TEXTURE, TFACTOR) for colour and alpha, stage 1 off; WORLD per name |
| 11 | groups +0x4C, then +0x48 | 0x6659C0, then 0x672930(group, CGraphics, &view, &proj, 0, 0) | their +0x179 (mask 0x10; +0x4C also h < counter_distance) | not read |
| 12 | province names, ProvinceTexts_Draw | fixed pipeline | h < 100 and mask 0x8 | as the country names, TEXTUREFACTOR per name; then, **inside `h < 100` only**, ZWRITE 1, ZENABLE 1 |
| 13 | groups +0x5C (building pictures), +0x70 | MapObjectGroup_Draw | their +0x179 | sampler 0 MIN ANISOTROPIC / MAG LINEAR, SRCALPHA / INVSRCALPHA, LIGHTING / AMBIENT / ZENABLE per object kind |
| 14 | Animation_AdvanceClock | — | !always_counters and h < counter_distance | — |
| 15 | groups +0x64 (weather), +0x60 | MapObjectGroup_Draw | their +0x179 | as 13 |
| — | end | | | ZWRITEENABLE 1, ZENABLE 1, ALPHABLENDENABLE 0, ZFUNC LESSEQUAL |

Each MapObjectGroup_Draw call is followed by an inlined counter - calls counted, every 1000 ms (timeGetTime) calls × 1000 /
elapsed stored at CGraphics +0x84, *inferred* a draw-rate statistic. Group **+0x44**, whose visibility
MapObjects_UpdateLayerVisibility sets under 150, **is not drawn by the scene** (no read of +0x44 in 0x45BE50..0x45C6E8).

Two consequences of the order, both the original's: **in the far view with country names drawn, depth test and depth
write stay off for the groups after them** - the names turn Z off and only the `h < 100` block turns it back on - so +0x60
(no mask) and +0x64 (weather) draw without depth above 500, +0x5C and +0x70 being hidden there anyway; and **the far
beaches (BeachShader_General_Low, which sets no blend state) blend SRCALPHA / ZERO**, DrawBeaches setting DESTBLEND ZERO and
the technique leaving it.

### C.2 Device states: what an effect leaves to the engine

- **Baseline [exe]**, CGraphics_SetDefaultRenderStates (0x676FF0), after the device is made and after every Reset:
  ALPHABLENDENABLE 1, ALPHATESTENABLE 1, CULLMODE NONE, LIGHTING 0, DITHERENABLE 0, **ALPHAREF 8, ALPHAFUNC
  GREATEREQUAL**, SRCBLEND ONE, DESTBLEND ZERO, a white material, FILLMODE SOLID (WIREFRAME with the debug flag); texture
  stages 0-3 ARG1 TEXTURE, ARG2 CURRENT, stage 0 MODULATE, stages 1-3 DISABLE.
- **ALPHAREF and ALPHAFUNC are written nowhere else**: a resumed sweep of .text (3,084,578 instructions) listing every
  call through a register loaded from `[x+0xE4]` with its immediate pushes; positive control, it reproduces every state
  call of MapGraphics_DrawScene as decoded by hand and finds FOGVERTEXMODE, ZFUNC and SCISSOR writers elsewhere. So
  **every alpha-tested map pass discards alpha below 8/255** [exe]. Its limit: a call passing the state in a register.
- **FOGENABLE is set by nobody** (the same sweep, and no scene .fx sets it): fog stays at Direct3D's default, off.
- **Every effect Begin in the scene passes flags 0** (all nine: terrain, borders, beaches, water, terra incognita, water
  borders, surf, trees, rivers): without D3DXFX_DONOTSAVESTATE, D3DX saves the states a pass changes and puts them back at
  End, so **a pass's states never leak to the next draw; only the engine's SetRenderState calls carry over**.
- **Parameters do persist** between Begin/End: the trees set only vAlpha, ViewMatrix, ProjectionMatrix, WorldMatrix,
  AbsoluteWorldMatrix and tex0 on the shared terrain_2_0.fx; BorderWidth, BorderHeight, LightDirection and the rest are
  whatever the land and beach draws last set.
- **What each technique leaves to the device** (the install's pass states) [mod: gfx/FX]:
  TerrainShader_Graphical/General/General_Low and BeachShader_General_Low set no state; TerrainShader_Border and
  BeachShader_Graphical/General blend SRCALPHA / INVSRCALPHA, the two beach ones also alpha test; TreeShader and
  RiverShader only the blend and test enables, as BeachShaderColor, BeachShader those and SRCALPHA / ONE; WaterFar(Color)
  turns blend and test off, WaterSimple(Color) blend on, WaterNear(Color) blend and test on; the four borders_2_0
  techniques blend only; TerraIncognita Far/Near blend and test on and the Z test and write off. So the blend factors of
  the trees, the rivers and the far surf are the engine's: SRCALPHA / INVSRCALPHA, as the land and beach draws leave them.
- **Not established**: ZENABLE, ZWRITEENABLE and ALPHATESTENABLE at the start of the scene - none is set before the land;
  within the frame the last immediate writer before the next scene is 0x241950's ALPHATESTENABLE 0, unless the interface
  draws set them.

### C.3 Rivers, trees, surf, and the unread pieces

**Rivers (MapRivers_Draw, 0x47C8A0; the renderer at graphics +0x4160).** Drawn with mask 0x80 at every height. The meshes
are built once, at the map build, by MapRivers_Construct (C.6): a vector of strips (+0x40), one per river piece, each with
an int bounding rectangle (+0x60: x, y, w, h), and a parallel vector (+0x50) of exit (mouth) quads or null - all null in
TFH. The vertex is FVF 0x202, a position and two texture coordinates, stride 0x1C; river.fx scrolls the second by
vTime·0.3. The rebuild 0x478EF0 runs only where the byte at VA 0x1BEA4C2 is set, which nothing but its own clear writes
(*inferred* dead), and it would leave no rivers, the traced paths and the raster being freed after the build. The draw:
ZWRITEENABLE 0; world the translation (−camera x_settled, 0, −camera y_settled), view and projection the view's;
`RiverShader` by name, Begin(…, 0), pass 0; **ColorMapHeight/Width** colormap_water.dds's height and width,
**ColorMapTextureHeight/Width** the next power of two of each; **MapWidth/MapHeight** CMap map_width/map_height (5616, 2160
in TFH) [mod: the map]; **tex0** map/terrain/river_body.tga, **tex1** river_movement.tga, **tex2** the generated fog
texture (CViewsTextureManager +0x18), which river.fx never samples, **tex3** colormap_water.dds; **AbsoluteWorldMatrix**
identity; **vTime** the clock (clock slot 5). Each mesh whose box (rectangle less the camera, y −10 to 50)
MapCamera_ClassifyBox (0x6BF670) does not put wholly outside the frustum is drawn and its index kept (+0xB4, +0xB0); then
tex0 becomes **river_exit.dds** and the kept indices' exit meshes are drawn; at the end ZENABLE 1, ZWRITEENABLE 1.

**Trees (MapTrees_Draw, 0x463930).** Drawn only under height 100 [exe] and with mask 0x1 - settings `renderTrees`, in the
Terrain and Weather modes' masks alone. Nothing above CMap `tree` (350) [mod: map/default.map]; from 0.3·tree alpha =
trunc(255 · (1 − (h − 0.3·tree) / (0.8·tree))) [exe] - with TFH's 350 the fade would start at 105, so it is dead: trees are
at 255 and vanish at 100. TreeShader; vAlpha = alpha/255; view and projection; **one pass per map/trees.txt entry**, tex0
its `texture` [mod: map/trees.txt]; within it, for each visible tile slot holding quads of that type, WorldMatrix = tile
+0x17C, AbsoluteWorldMatrix = tile +0x13C, CommitChanges, and an indexed draw of the slot's range against one shared quad
index buffer (+0x154, 6 indices per 4 vertices). The mesh (MapObjects_RebuildTileStrips): for each tree point a quad of four
(x, y, z, u, v) vertices, v offset by the point's kind k (0..3) to 0.25·k; in the Weather mode, provinces below −5.000 get
u + 0.5, the snowed half.

**Surf (MapShore_Draw, 0x432C70; the CBeachManager at graphics +0x4164).** Gated by +0x42E9, set once at the map build
(`CREATE_WAVES`) from settings.txt **`waves`** (GameSettings +0xE6, default yes) [mod: settings.txt] where the surf object
exists - that step is also the only time its meshes are built (CBeachManager_BuildMeshes, C.7). Per tile one quad per
wave pixel, four SHORT4 vertices, against one shared 5000-quad index buffer: DrawIndexedPrimitive(TRIANGLELIST, 0, 0, 4K,
0, 2K). **The declaration one element, SHORT4 POSITION** (x, z in half-pixels from the tile's middle; u, v in hundredths),
which beach.fx reads as `int4 vPositionUV`. **BeachShader** near, **BeachShaderColor** far, by the count of terrain_sheet_heights
entries exceeded. **tex0** map/terrain/shore.tga; **tex1** shore_alpha.tga near or shore_alpha_outline.tga far; **tex2**
shore_alpha.tga (shore_alpha_gradient.tga only under an old-style `extend` of the map folder); **vTime** the clock;
**vWaterHeight 0.31** [exe, the float at VA 0x171DAEC]; per tile WorldMatrix and AbsoluteWorldMatrix. It sets **no render
state**, so the far black line at 70% alpha blends SRCALPHA / INVSRCALPHA, as the water left it. The records, their quads
and the shader's textures are C.7.

**The unread pieces.** 0x45F450: correction (3). 0x6BB7E0 (`Animation_AdvanceClock`) advances the animation manager at VA
0x174D960 by the time since its last call - the library *inferred* EMotion FX from the strings 'Actor.cpp',
'SingleProcessorScheduler' and 'Mesh LOD Level' in its callees - and runs only where the figures can be shown
(!always_counters, h < counter_distance), so figures' animations stand still above that (*inferred*). The layers around
ProvinceTexts_Draw are the object groups of rows 11 to 15.

### C.4 The effect system

- **Loading.** A map effect's path is the gfx folder's name (or an old-style mod's override, `Path_PreferOverride` under
  `extend`) + `/FX/<name>.fx`; river and other object types hardcode `gfx/FX/river.fx` and the like.
- **Registration.** `FxHandler_Register` (0x661DD0) takes CGraphics +0x6BCFC, the path, a key and the device; a key already
  registered returns its index and loads nothing - the land and the beaches share TerrainShader's one effect.
- **Compiling.** `Fx_CreateEffectFromPath` (0x6621D0) turns `\` into `/` and reads the file **through PhysFS**
  (VirtualFile_Open), so a mod's copy wins by the search path (mod, tfh, base; *inferred* from Lua_PhysfsLoader's record);
  it calls **D3DXCreateEffect with pDefines NULL - no D3DXMACRO list - Flags 0 and pPool NULL**, with an ID3DXInclude
  (`FxInclude_Open`, 0x662010) that finds an `#include` (water_include.h) beside the effect through PhysFS. Errors are logged
  `D3DXCreateEffectFromFile failed for file: <path> with error: <compiler output>`; **a failed effect is still registered,
  as null**, and the loaders then call GetParameterByName on it (*inferred* crash).
- **No 1_1/2_0 choice.** The image names `/FX/terrain_2_0.fx` and `/FX/borders_2_0.fx` only; terrain.fx, terrain_1_1.fx,
  borders.fx, borders_1_1.fx, waterdot4.fx, maptext.fx, test.fx, highlight.fx, mapwidget.fx and Rippleflag.fx are named
  neither in the image nor in the install's interface .gfx files (positive control: the same search finds the 2_0 files,
  river.fx, beach.fx, hierarchy.fx and the rest). The handler can try a `legacy` subfolder first (byte +0x48), but only its
  constructor writes that byte (0): no access at CGraphics +0x6BD44 in the same sweep, where 60-odd hits on +0x6BD00 are
  found; on success that route would also load twice and leak one.
- **The map's registrations.** The map graphics loader (0x450520) registers Borders (borders_2_0.fx), TerrainShader
  (terrain_2_0.fx), WaterShader (water.fx) and TerraIncognitaShader (terraincognita.fx), and builds a mapobject.fx path it
  never registers (*inferred*: no register call before the path is overwritten); the surf registers BeachShader (beach.fx)
  and the rivers RiverShader.
- **Parameters and techniques** are fetched **once, as handles** (GetParameterByName(NULL, name)) at load for the terrain
  effect - the handles on `WaterObject` (CProvinceManager) +0x1A4 tex0, +0x1A8 tex1, +0x1AC tex2, +0x1B0 tex3, +0x1B4
  WorldMatrix, +0x1B8 ViewMatrix, +0x1BC ProjectionMatrix, +0x1C0 WorldViewProjectionMatrix, +0x1C4 LightDirection, +0x1C8
  ColorMapHeight, +0x1CC ColorMapWidth, +0x1D0 ColorMapTextureHeight, +0x1D4 ColorMapTextureWidth, +0x1D8 BorderWidth,
  +0x1DC BorderHeight, +0x1E0 MapWidth, +0x1E4 MapHeight (left for section A's fragment to record). Technique handles are
  fetched once (terrain), every frame (water), or **by name each call** (rivers, surf, and most of their parameters - D3DX
  takes a name as a handle).
- **Drawing.** Every draw: SetTechnique, Begin(&passes, 0), BeginPass(0), CommitChanges per object, EndPass, End. **Only
  pass 0 is ever drawn.**
- **Device loss.** `FxHandler_OnLostDevice` and `FxHandler_OnResetDevice` run around a Reset; `FxHandler_Reload`
  recompiles one key (the developer console's `gfx/FX/... reloaded`).
- **Outside the handler.** shadowmap.fx and one water.fx (`gfx//fx//water.fx`, 0x7503BB) are made with
  D3DXCreateEffectFromFileA, which reads from the working directory and not through PhysFS; only shadowmap.fx uses the
  effect pool (CGraphics +0x6B9C8).

### C.5 Not established

ZENABLE, ZWRITEENABLE and ALPHATESTENABLE at the scene's start; the values of the land's and the water's
MIPMAPLODBIAS/MIPFILTER registers; groups +0x48/+0x4C (0x672930, 0x6659C0) and what MapObjectGroup_Draw draws by kind;
the pre-pass 0x2418B0/0x675D10 and GameSettings +0x58; 0x4482F0; the unit-layer draw 0x673B10. The rivers' tex2 is the
fog, unsampled (C.6); the water borders are B.8.

Frontier: 0x450520, 0x672930, 0x6659C0, 0x2418B0, 0x675D10, 0x241950, 0x673B10, 0x4482F0, 0x6759D0, 0x5F3E40, 0x7BC8F0.

### C.6 The river meshes

*Read 2026-11-06 by a delegated agent (fragment `mapdraw-rivers.json`); measured on TFH's `tfh/map/rivers.bmp`,
`terrain.bmp`, `terrain.txt` and `cache/map.bin`, and the install's `map/terrain/river_*` and `gfx/FX/river.fx`.*

**In one line.** At the map build every index-0 pixel of rivers.bmp starts a river, walked over the blue pixels to the sea,
a junction or nothing; each walk becomes one triangle strip - a cardinal spline (tension 0.7) through the pixel centres, as
wide as the pixel index says plus a seeded jitter - made once and never again [exe].

**Where the meshes come from [exe].** MapRivers_Construct (0x478260), called once from CProvinceManager_CreateWorld's
CREATING_RIVERS step (VA 0x8549F6) on an operator new(0xB8), the result stored at WaterObject +0x4160. In order: it seeds a
0x9C8-byte MT19937 at +0x78 with **42**; loads river_body.tga (+0x80), river_movement.tga (+0x84), colormap_water.dds
(+0x7C) and river_exit.dds (+0x88); sets **+0x3C = 128 / width(river_exit.dds)** (0.25 for the install's 512 × 128); calls
MapRivers_TraceAll (0x47B9F0) and MapRivers_BuildAllMeshes (0x47B9A0); **then frees the traced paths**
(RiverPathDeque_Clear, 0x47D3E0) and erases the exit-frame vector; then registers river.fx. No river cache file exists: the
sources come from **map.bin**, the pixels from CMap +0x20E8 - rivers.bmp, loaded at every start by CMap_LoadRiversBitmap
(0x8BC00, from CMap::LoadMapFiles) through the same image loader and converter as the province raster, and kept as 8-bit
palette indices, then deleted by CMap_ReleaseMapBuildRasters (0x924E0) under "Cleaning up after Graphical Map". **So the
rebuild 0x478EF0 has nothing to rebuild from**: it releases the meshes and loops to +0x14, then 0, and leaves +0x50 holding
released pointers. Its trigger byte has no writer but its own clear (absolute references only), so it is *inferred* dead -
and if it ever ran the rivers would vanish.

**map.bin [exe; measured].** CreateMapBinCacheOwner (0x86F10) makes the object, published at g_MapBinCache (VA 0x1A85578),
and runs its **own** staleness test, by file date: CMap_CollectMapBinStampFiles (0x92430) gives positions, provinces.bmp,
terrain.bmp, definition.csv, adjacencies, terrain.txt, continent, region, coastlines; if any is missing or newer than
map.bin, MapBinCache_Build runs and the file is saved (0x487C90); otherwise MapBinCache_Load, which on failure sets +0x44 = 1
and builds. MapBinCache_Build (0x873C0) first pushes **every pixel of rivers.bmp whose index is 0, for y = 0.. and x = 0..
in turn**, onto +0x10, then makes the (W+1) × (H+1) raster (B.7). *Measured*: TFH's map.bin's 722 pairs are exactly the 722
index-0 pixels of `tfh/map/rivers.bmp`, in that order, with y = H − 1 − the BMP's stored row (as A.1). **rivers.bmp is not
in the stamp list**: editing it alone leaves map.bin's old sources traced over the new pixels (*inferred* consequence). This
corrects the record's CMap::CollectCacheStampFiles comment, which had every map cache gated on the one flag: the quads and
the adjacency cache are, map.bin is not.

**rivers.bmp [mod: map/rivers.bmp].** 5616 × 2160, 8-bit, 256-colour palette.

| index | colour | TFH pixels | meaning |
| --- | --- | --- | --- |
| 0 | (0,255,0) | 722 | source: a river starts here |
| 1 | (255,0,0) | 282 | junction: a tributary's end goes through it |
| 2–11 | cyan to dark blue | 82,848 in all | river; width = index − 2 |
| 12–22 | none in TFH (the base game's map has 3 pixels of 13 and 15) | 0 | river, width index − 2, **and** the river's exit frame = index − 12 |
| 254 | (255,0,128) | 8,088,967 | not read by the river code (it coincides with terrain.bmp's sea, 254, but for 48 + 2 pixels) |
| 255 | white | 3,957,741 | not read (land) |

**The trace (RiverTrace_Follow, 0x47BD20) [exe].** One visited list serves the whole run. For each source in order: mark
it visited and start a path with the node {x, y, width 1, source 1}, exit frame f = −1, last direction d none. Repeat: test
R(x+1, y), R(x−1, y), R(x, y+1), R(x, y−1) in that order, skipping the reverse of d, and **step onto the first whose index
is 2..22**. A step sets f = index − 12 where index ≥ 12; **if vertical after a horizontal one, first pops the path's last
node** (the corner), unless the new pixel stops the river; pushes {x', y', index − 2, 0}; marks the pixel visited; and **stops
the river if the new pixel's terrain is water** (terrain.bmp index → terrain.txt type → `is_water`; only `ocean` in TFH),
keeping that pixel. With no step possible: test for a not-yet-visited junction pixel (index 1) at (x+1, y), (x−1, y),
(x, y+1), (x, y−1) in turn; each found adds two nodes, the junction and the pixel beyond it, with the last node's width and
flag, marks it visited and sets d none (a −x hit moves x, and a +y hit moves y, for the tests after it). At the end: if f ≠
−1 and the path has more than 2 nodes, pop two; if d is not none, push a copy of the last node one pixel further in d. A path
of 2 or more nodes becomes a piece, its f kept (MapRivers_TraceAll); a lone source makes nothing. **No visited test guards
a blue step** (a blue cycle would never end), and the raster reads have no bounds test. *Positive control, a simulation of
this rule*: TFH gives 721 pieces from 722 sources, **282 ending at a junction - exactly the 282 index-1 pixels** - and the
base game's map 347 and 347; 212 end in water, 228 on nothing, 27 blue pixels are never stepped on, every f is −1; 61,532
nodes, 364,866 vertices.

**The strip (MapRivers_BuildPieceMesh, 0x479010) [exe].** Nodes P_j = (x_j, 0, y_j) (world x, world z = engine y, pixel
centres on whole numbers as A.1), widths w_j. Ends: P_−1 = 2P_0 − P_1, w_−1 = 1.0; past the end P_s+2 = P_s+1 + (P_s −
P_s−1), w_s+2 = 2w_s+1 − w_s. Per segment s and k = 0, 1, 2, t = k/2:
- C(t) and W(t) are the **cardinal spline, tension 0.7** - weights −0.7t³ + 1.4t² − 0.7t, 1.3t³ − 2.3t² + 1, −1.3t³ +
  1.6t² + 0.7t, 0.7t³ − 0.7t²; d = normalize(C((k+1)/2) − C(t)), n = normalize(−d.z, 0, d.x);
- **hw = 0.1·W + 0.15 + 0.1·r**, r a draw of the +0x78 generator (the record's MT19937, its non-standard constants), &
  0x7FFFFFFF, / 2³¹ - one draw per k per segment, in piece order, made even when nothing is emitted;
- **vertices**: the plus side C + n·hw/2 first, then the minus side C − n·hw/2 - a full spacing of hw, 0.15 to 1.15 map
  pixels for indices 2..11;
- **height = 0.40 + max(h(side), h(centre))**, h = 0 where the province at pixel (trunc(x − 1), trunc(z − 1)) has a
  template that is not land, else 0.02 (the land at 0.35);
- **TEXCOORD0** (river_body, clamp): u = 1 plus side, 0 minus side; v = k/8 in the first segment (0 to 0.25, the texture's
  tapered tip) and k/8 + 0.25 after it (0.25 to 0.5, the body);
- **TEXCOORD1** (river_movement, wrap): (1, n/3) and (0, (n+1)/3), n counting this piece's emitted vertices;
- for s ≥ 1, k = 0 makes no new vertices: it pushes the previous pair again with TEXCOORD0 v = 0.25 - a UV seam and two
  degenerate triangles.

So a piece of N nodes has **6(N − 1) vertices**, drawn as a strip of 6(N − 1) − 2 triangles: a managed MeshBuffer,
primitive kind 1, FVF **0x202**, stride **0x1C** (float3 position, float2 TEXCOORD0, float2 TEXCOORD1). The rectangle
(+0x60) is int (x, y, w, h) over the nodes, w = max(1, max x − min x), h likewise. **The exit quad** (+0x50; only where f ≠
−1, so never in TFH): A, B the last two vertices, M their middle, D = A − B; corners M + D, M − D, then each +
3·normalize(D.z, 0, −D.x), 3 pixels downstream; TEXCOORD0 u = (f + 1)·q and f·q with q = +0x3C, v 0 at the near pair and 1
at the far; TEXCOORD1 (1, n), (0, n+1), (1, n+2), (0, n+3). Kept as read: the floors 0.15 and the reuse of the previous
same-side vertex below 0.151 are dead, every height being at least 0.4; a node carrying the source flag at s ≥ 1 (a source
straight against a junction) adds 0.25 to v and logs a line - none in TFH.

**The draw's test [exe].** The box (x − cam x, **−10**, y − cam y) to (x + w − cam x, **50**, y + h − cam y), cam the
camera's settled position, goes to MapCamera_ClassifyBox (0x6BF670) against six (a, b, c, d) planes at MapCamera +0x288: 1
wholly outside one plane, 2 crossing, 0 inside; the river is drawn unless 1. The y bounds only make the box tall enough for
the rivers' 0.40–0.42. Drawn indices go to +0xB4[+0xB0], whose exit meshes follow with tex0 river_exit.dds.

**What each texture does [mod: gfx/FX/river.fx].** **tex0** (river_body): the base colour, and **its alpha is the river's
alpha**, blended SRCALPHA/INVSRCALPHA and alpha-tested at 8/255. **tex1** (river_movement): sampled at TEXCOORD1 − (0,
0.3·vTime), so its pattern runs down the river; it lerps the colour towards (water − 0.3) by its alpha (0 at the edges,
about 0.8 in the middle), then adds its own rgb. **tex3** (colormap_water): at ((ColorMapWidth·x/MapWidth +
0.5)/ColorMapTextureWidth, (ColorMapHeight·z/MapHeight + 0.5)/ColorMapTextureHeight), the vertex's own world position
(AbsoluteWorldMatrix identity). **tex2**: the generated fog texture (CViewsTextureManager +0x18, reached as the in-game
screen's slot 15 +0x5F2C = the embedded CProvinceManager's +0x4168); river.fx declares it (`TerraIncog.dds`,
`FOWTexture`) and **never samples it**; vTerrainTexCoord is computed and unused too.

**Corrections.** C.3's "the engine's declaration was not read": FVF 0x202. C.3's rebuild: it would empty the rivers. C.3 and
C.5's tex2: the fog, unsampled. B.7's map.bin list of N pixels: the river sources. CMap +0x20E8: rivers.bmp. The record's
CMap::CollectCacheStampFiles comment, for map.bin, which has its own nine-file test.

**Not established.** The live mesh count (721 by simulation; BiceLib could read +0x40/+0x44). What the engine reads past
the raster's edge - TFH's sources make 21 such reads, which the simulation takes as "not river" and still gives 282 = 282.
Whether D3DX honours the TGA's bottom origin (*inferred* yes: v = 0 is the texture's tip). MapBinCache_Build's raster half
and the save 0x487C90; CMap_ReleaseMapBuildRasters' province loop; the game-side reader CProvinceTemplate::MeasureEdges's
river read and 0x4889E0; the destructor 0x478CE0 and 0x47CF90. Frontier: 0x478CE0, 0x47CF90, 0x487C90, 0x4889E0.

### C.7 The surf's meshes

*Read 2026-11-06 by a delegated agent (fragment `mapdraw-surf.json`); the generator reimplemented over `terrain.bmp`
reproduces all 941 tiles of TFH's cache record for record and in order, 141,831 records.*

**In one line.** The surf is a list of **wave pixels** per tile, each a 0x1C-byte record: a coastal *water* pixel (x, y),
a type 0..51 and four float offsets fixed by the type. QuadCache_LoadTile's seventh piece fills the lists from
`cache/all_quads.bin`; without a cache MapShore_GenerateWavePixels (0x46F140) fills them from `terrain.bmp`. At CREATE_WAVES
CBeachManager_BuildMeshes (0x433100) turns each record into one quad of four SHORT4 vertices - x and z in half-pixels from the
tile's middle, u and v in hundredths - and MapShore_Draw draws every tile's quads against one shared index buffer.

**The object.** CBeachManager (RTTI, base CLostDeviceInterface; both vftable slots the shared stub 0xABF890, so it does
nothing on a device loss - its buffers are managed), 0x40 bytes, allocated at VA 0x85325C in CProvinceManager_CreateWorld and
stored at WaterObject +0x4164 - unconditionally as far as the code before it shows (*inferred*). CBeachManager_Construct
(0x432080):
- tile width and height (ECX, EDX = WaterObject +0x194/+0x198, 50 each [exe]) at +8/+0xC; columns and rows (+0x18C/+0x190)
  at +0x10/+0x14;
- +0x18: an array of columns × rows `std::vector<WavePixel>`, 16 bytes each, begin/end/capacity first;
- +0x24: an array of columns × rows MeshBuffers, managed;
- +0x20: a MeshBuffer holding **one 16-bit index buffer of 30000 indices, 5000 quads [exe], quad q = 4q, 4q+1, 4q+2, 4q+2,
  4q+3, 4q** (triangles 0-1-2 and 2-3-0);
- textures: +0x30 `terrain/shore.tga`, +0x34 `shore_alpha.tga`, +0x38 `shore_alpha.tga` (or `shore_alpha_gradient.tga`
  under directory mode 2, an old-style `extend`), +0x3C `shore_alpha_outline.tga` [mod: map/terrain]; TFH's `map/terrain` has
  none of them, so the base game's are drawn (*inferred*: the loader's search not traced);
- +0x2C: beach.fx under the key BeachShader;
- +0x28: CreateVertexDeclaration from VA 0x170AD34, **one element: stream 0, offset 0, SHORT4, POSITION 0** - on failure
  MessageBoxA "CreateVertexDeclaration failed!! (WavesVertexDecl)" and FatalExit(1).

**The record** (WavePixel, 0x1C bytes; `all_quads.bin` stores it as in memory):

| offset | type | meaning |
| --- | --- | --- |
| +0x0 | int | x, the map pixel column of a terrain-water pixel |
| +0x4 | int | y, its row, northward (the land's y) |
| +0x8 | int | type 0..51: 0-6 water south of a land pixel, 7-13 north, 14-20 east, 21-27 west, 28-33 south-east, 34-39 south-west, 40-45 north-east, 46-51 north-west |
| +0xC, +0x10 | float ×2 | added to corner P0's (x, z) |
| +0x14, +0x18 | float ×2 | added to P3 (or P1, by subkind; ignored by subkind 2) |

The four floats are each 0, +0.5 or −0.5 and are **constants of the type**: every branch of the generator stores fixed
values, and the cache has exactly one float tuple per type over all 141,831 records.

**Where the records come from.** Two producers, both through CBeachManager_AddWavePixel (0x432B40), which push_backs onto
the list at +0x18 + 16·tile, keeps the largest list size in VA 0x1A85630 and, while that exceeds 5000, logs "Too many wave
pixels" - a log only (TFH's largest tile holds 2,355): QuadCache_LoadTile's piece 7, one call per cached record where +0x4164
is set; and MapShore_GenerateWavePixels, which CProvinceManager_BuildQuads reaches through the per-tile builder 0x4727B0
(call at VA 0x85AE11), which calls the per-pixel beach builder 0x46EB60 for every pixel of every land province of the tile,
which calls the surf generator first. So a province's records go to **its own tile** (A.1's rule), not to the tile under the
record: 47,381 of TFH's lie outside their tile's square, up to about 110 pixels from its middle. Order (*measured*, all 941
tiles exact): provinces by id, each province's pixels from the south row by row, west to east, each pixel's records in the
generator's order.

**The generator** (0x46F140, read whole) [exe, on mod data]. W(x, y) is TerrainRaster_IsWater (0x87360): terrain.bmp's
palette byte at (x, y), index 0 off the right or top edge, through CMap terrain_by_palette_index → CTerrain is_water [mod:
map/terrain.bmp, map/terrain.txt]; in TFH only index 254 (`ocean1`) is water. Nothing is made unless 0 < x < map width − 1
and 0 < y < map height − 1; the pixel itself is not tested. Eight blocks run in this order, each adding 0, 1 or 2 records
at the water neighbour:
- **N**, the record at (x, y+1); L = W(x−1, y+1), R = W(x+1, y+1), l = W(x−1, y), r = W(x+1, y). L and R both water: **9**
  if l and r, **11** if r only, **10** if l only, else **7**. Neither: **8**. R only: **12** unless r. L only: **13** unless l.
- **S**, at (x, y−1): the same on row y−1, giving 2, 4, 3, 0 / 1 / 5 / 6.
- **E**, at (x+1, y); U = W(x+1, y+1), D = W(x+1, y−1), u = W(x, y+1), d = W(x, y−1). U and D: **16** if u and d, **17** if
  u only, **18** if d only, else **14**. Neither: **15**. U only: **20** unless u. D only: **19** unless d.
- **W**, at (x−1, y): the same on column x−1, giving 23, 24, 25, 21 / 22 / 27 / 26.
- **SW** (at (x−1, y−1), base 34), **SE** ((x+1, y−1), base 28), **NW** ((x−1, y+1), base 46), **NE** ((x+1, y+1), base
  40), where the diagonal is water. If both orthogonals between the pixel and the diagonal are water, with the pairs
  SW: a = W(x, y+1)∧W(x−1, y+1), b = W(x+1, y−1)∧W(x+1, y); SE: a = W(x, y+1)∧W(x+1, y+1), b = W(x−1, y)∧W(x−1, y−1);
  NW: a = W(x+1, y+1)∧W(x+1, y), b = W(x−1, y−1)∧W(x, y−1); NE: a = W(x−1, y+1)∧W(x−1, y), b = W(x, y−1)∧W(x+1, y−1) -
  neither a nor b → **base**; a and b → **base+1, then base+3**; a only → **base+1, then base+4**; b only → **base+2, then
  base+3**. Both orthogonals land: **base+5**. One water, one land: nothing.

**The quads** (CBeachManager_BuildMeshes, 0x433100, read whole) [exe]. Called once at CREATE_WAVES (VA 0x8589B9), only
where +0x4164 exists and settings `waves` is on [mod: settings.txt]. For each tile with K records: VertexBuffer_Create(4K
vertices, stride 8, FVF 0, not dynamic), managed, Lock; for record n of the tile, of type t, at (x, y):
- corners P0..P3: the (x, z) of four float triples at VA 0x170F410 + 0x30·t;
- sub = the int at VA 0x170AD48 + 4t (the table holds only 0, 1, 2, 5 and 10..13, so the branch for subkind 6 is dead);
- offsets: sub 0, 5, 10..13: P0 += (f0C, f10), P3 += (f14, f18); sub 1: P0 += (f0C, f10), P1 += (f14, f18); sub 2: P0
  and P1 both += (f0C, f10);
- UV: four (u, v) from VA 0x170F210 by subkind - 0: +0x00, 1 and 2: +0x20, 5: +0x40, 10..13: +0x80 + 0x20·(sub−10) - **plus
  0x100 when n mod 4 == 0**, the same set scaled by 1.1 (*inferred*: to break the repetition);
- vertex k = **((int)(2·(x − mx + Pk.x)), (int)(2·(y − my + Pk.z)), (int)(100·uk), (int)(100·vk))**, C truncation, mx =
  50·col + 25, my = 50·row + 25;
- Unlock. A debug log gated on the byte at VA 0x1BEA4C0 is dead: the byte is in .bss and its one reference is that read
  (*inferred*, as the rivers' 0x1BEA4C2).

The table [exe]: corners (x, z) in pixels from the record's pixel centre, after the offsets. UV sets A = (0,0)(0,100)
(100,100)(100,0); B = (100,0)(0,0)(0,100)(100,100); C = (0,0)(50,50)(50,50)(100,0); the alternative sets ×1.1, A′ = (0,0)
(0,110)(110,110)(110,0) and so on.

| type | corners P0 P1 P2 P3 | uv |
| --- | --- | --- |
| 0 | (−.5,−.5) (−.5,1) (.5,1) (.5,−.5) | A |
| 1 | (0,−.5) (−.5,1) (.5,1) (0,−.5) | A |
| 2 | (−1,−.5) (0,.5) (0,.5) (1,−.5) | C |
| 3 | (−1,−.5) (.5,−.5) (.5,1) (.5,1) | B |
| 4 | (−.5,−.5) (1,−.5) (−.5,1) (−.5,1) | B |
| 5 | (.5,−.5) (.5,−.5) (−.5,1) (.5,1) | B |
| 6 | (−.5,−.5) (−.5,−.5) (−.5,1) (.5,1) | B |
| 7..13 | as 0..6 with z negated | as 0..6 |
| 14 | (.5,.5) (−1,.5) (−1,−.5) (.5,−.5) | A |
| 15 | (.5,0) (−.5,−.5) (−.5,.5) (.5,0) | A |
| 16 | (.5,1) (−.5,0) (−.5,0) (.5,−1) | C |
| 17 | (.5,1) (.5,−.5) (−1,−.5) (−1,−.5) | B |
| 18 | (.5,.5) (.5,−1) (−1,.5) (−1,.5) | B |
| 19 | (.5,−.5) (.5,−.5) (−1,−.5) (−1,.5) | B |
| 20 | (.5,.5) (.5,.5) (−1,−.5) (−1,.5) | B |
| 21..27 | as 14..20 with x negated | as 14..20 |
| 28 | (0,−.5) (−1.5,1) (−1,1.5) (.5,0) | A |
| 29 | (.5,0) (−.5,1) (−1,1) (.25,−.25) | D10 = (0,0)(0,50)(50,75)(50,0); alt (0,0)(0,55)(60,82)(60,0) |
| 30 | (.5,0) (−1,1.5) (−1,1) (.25,−.25) | D11 = (0,0)(0,100)(50,75)(50,0); alt (0,0)(0,110)(55,82)(55,0) |
| 31 | (0,−.5) (−1,.5) (−1,1) (.25,−.25) | D12 = (100,0)(100,50)(50,75)(50,0); alt (110,0)(110,55)(55,82)(55,0) |
| 32 | (0,−.5) (−1.5,1) (−1,1) (.25,−.25) | D13 = (100,0)(100,100)(50,75)(50,0); alt (110,0)(110,110)(55,82)(55,0) |
| 33 | (.5,−1) (−1,.5) (−.5,1) (1,−.5) | A |
| 34..39 | as 28..33 with x negated | as 28..33 |
| 40..45 | as 28..33 with z negated | as 28..33 |
| 46..51 | as 28..33 with x and z negated | as 28..33 |

Two quirks of the original's tables [exe]: D10's alternative set has u = 60 where ×1.1 gives 55; and 0.825f × 100 truncates
to **82**. Truncation towards nought moves the ±0.25 corners of 16 types (29-32, 35-38, 41-44, 47-50) a quarter pixel
towards the tile's middle - 9,468 vertices in TFH; every other vertex is exact. Both windings occur (49,450
counter-clockwise, 181,225 clockwise and 52,987 degenerate triangles in the x-east/z-north plane); culling is NONE at the
surf draw (C.1), so all are drawn.

**What the quads cover.** beach.fx's VertexShader_Beach places a vertex at (x·0.5, vWaterHeight, z·0.5) through WorldMatrix
(the tile's middle less the camera), so world = record pixel + corner, with no +0.5 as the land's shader has; the ±0.5
corners lie on the land's pixel edges. For the straight types the quad runs from the **far edge of the water pixel (v = 0)**
to the **centre of the land pixel (v = 1)**, the coastline at v = 2/3. vWaterHeight 0.31 [exe] puts it between the sea
(y = −0.32 in water.fx) and the land (LAND_ALT 0.35) [mod: fx]; with ZENABLE on, the land should hide the inland third
(*inferred*; whether the land writes depth is C.2's open item). *Measured* over all 141,831 records: every record pixel is
terrain 254; 130,889 lie on sea zones, 10,934 on pixels with no definition.csv colour and 8 on land-province pixels; every
record has a land-province pixel among its eight neighbours.

**The draw** (MapShore_Draw, 0x432C70). For each visible tile whose MeshBuffer has a vertex count: WorldMatrix,
AbsoluteWorldMatrix (which beach.fx does not use), CommitChanges, SetStreamSource(0, VB, 0, 8), SetIndices(the shared
buffer), **DrawIndexedPrimitive(TRIANGLELIST, 0, 0, 4K, 0, 2K)** - a tile over 5000 records would ask for more indices than
the buffer holds (*inferred* failure; TFH's most is 2,355). The technique as C.3 says.
- **BeachShader (near)** [mod: gfx/FX/beach.fx]: colour = shore.tga at uv/100 − (0, 0.2·vTime) - the foam scrolling
  towards +v, the shore (*inferred* from the shader's sign) - × shore_alpha.a(uv/100) × tex2.a(uv/100); tex2 is shore_alpha
  again, so the mask enters squared. The pass blends SRCALPHA/ONE, additive, with the alpha test (≥ 8/255, C.2). In the base
  game's files shore.tga is 32×32 white with noise in alpha; shore_alpha.tga's alpha rises from 0 at v = 0 to a peak at v ≈
  0.7, the coastline, and falls to 0 at v = 1; **shore_alpha_gradient.tga's alpha is 0 throughout, so under directory mode 2
  the near surf is invisible** (*inferred* from the file).
- **BeachShaderColor (far)**: black, alpha = 0.7 × shore_alpha_outline.a(uv/100), no scroll. The outline's alpha is 255 from
  v ≈ 0.2 to 0.9 and about 0 at the ends: a static black line about 0.7 px wide on the water side, ending at the coastline.
  The engine's SRCALPHA/INVSRCALPHA, left by the water (C.2), with the alpha test.
- vTime is the clock at [VA 0x1A857E4], slot 5, as for the rivers; its unit is not established. Every quad's u spans 0..1
  (or 0..1.1): one repeat of shore.tga per pixel along the coast. All three samplers wrap. v = 0 is taken to be the displayed
  top of each TGA (descriptor 8, bottom-left origin, which D3DX honours - *inferred* from documentation, not the executable).

**Lifecycle.** CBeachManager::ReloadResources (0x433040, from CProvinceManager_ReloadResources) reloads +0x30/+0x34/+0x38 -
not the outline - and recompiles BeachShader. CBeachManager_Destruct (0x432A50, from the WaterObject teardown at VA
0x84FF0F) releases +0x30/+0x34 only, plus the vectors, meshes and index buffer. The records are loaded whatever `waves` says;
the meshes exist only if it was on when the map was built.

**`map/coastlines.txt` does not touch the surf.** CMap::LoadKey stores its path (default.map key `coastlines`, token 0x7B5,
CMap +0x217C); its one key, `strategic_resource_coastlines` (token 0x7B6, compared at VA 0x48F653 in a reader at rva 0x8F4D0,
not read further), lists three region names - the indian, atlantic and pacific coast regions (*inferred*: for strategic
resources by sea). The negative: the surf functions, read whole, use no CMap field but the map's width and height
(+0x2A74/+0x2A78), terrain_raster (+0x20E4), terrain_by_palette_index (+0x2220) and, in the draw, terrain_sheet_heights; the
positive control is that the same reading found each of those.

**Not established.** The unit of vTime; that D3DX's v = 0 is the TGA's displayed top (from D3DX's documentation, which the
alpha profile's placement agrees with); whether the land writes depth, hiding the inland third; 0x46EB60 and 0x4727B0 read
only as far as the surf call - the pixel walk order measured from the cache, not read, and in 0x4727B0 the pixels appear to
be stored relative to the template's +0x2C/+0x30 pair and added back at VA 0x872B09..0x872B0F, not settled; CBeachManager
+0x1C (always 0x20, no reader in the functions read); whether TFH's missing `terrain/shore*.tga` resolves to the base game's
(loader search not traced); the reader at rva 0x8F4D0. For A.6: CProvinceManager_BuildQuads's surf part is read here.
Frontier: 0x46EB60, 0x4727B0, 0x434050, 0x4340D0, 0x6D44C0, 0x44FCF0, 0x8F4D0, 0x660F30, 0x6610E0, 0x718110.
