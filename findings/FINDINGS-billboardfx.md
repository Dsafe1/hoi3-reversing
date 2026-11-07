# Plain billboards through billboard.fx, whole

*Read off the listing on 2026-11-07 by a delegated agent (fragment `interface-billboardfx.json`), for a program that draws
every plain `billboardType` of `interface/mapitems.gfx` through the install's own `gfx/FX/billboard.fx`, fed as the
original feeds it; the flip's overwrite, `vMultiplier`'s 1.5 and the rotation's π/2 checked again off the bytes by the
collecting session. VAs unless written "rva"; `confirmed` except where a line says otherwise. **[exe]** a figure of the
executable, **[mod]** one a file can change. `FINDINGS-counters.md` section 10 (counter.fx) and `FINDINGS-weathersim.md`
C.3.1 (weather_billboard.fx) are the same reading for the other two kinds the map draws as quads.*

**What it settles.** The type's keys and their defaults; the texture, the effect, the quad and the technique; every
parameter of the draw; the render states and where the batch falls among the map's objects; and, for each map thing that is
a plain billboard, who makes it, where it is placed and with what rotation, frame and scale.

**Corrections, rather than additions.**
- `CBillboardType::DrawQuad`'s world matrix uses the inverse of the **whole** view, not of its rotation.
- **`flip` has no visible effect on a plain billboard.** RotationY(π) is computed and then overwritten by RotationZ, and
  billboard.fx never reads `vFlip`.
- **A counter's pointer is always drawn at scale 1.** `CCounterObject::Render` "sets its scale" through C3dVisibleObject's
  SetScale (slot 39), which writes +0xF4 and the local matrix. The draw reads neither: it reads `+0xB28`, which nothing
  writes for the pointer.
- **`offset` is not scaled by `vScale`.** `vScale` multiplies only the quad's vertices.
- The battle marker stores the rotation **−(h + π)**: the two quarter turns add, they do not cancel.
- What the marker hands `SetPosition` is **M − D**, half the vector from the defender to the attacker, not "the negated
  midpoint".
- `vftable_CBillboardObject` differs from C3dVisibleObject's at **nine** slots, not one.
- `ProvinceGraphics_PlacePicture` stores the world transform itself. Its slot 32 is an unlink.

## 1. The type: `CBillboardType`

**Constructor** `0xB06AA0` (rva 0x706AA0; `this` and the graphics on the stack, `ret 8`). It writes vftable `0x1605258`,
which is what identifies that table. Its defaults:

| field | key (token) | default | read by |
| --- | --- | --- | --- |
| +0x98 | `scale` (0x5C), float | 1.0 | ParseFloat |
| +0x9C | `textureFile` (0x24) | "" | ParseString |
| +0xB8 | `effect` (0x58) | **"Billboard"** | ParseString |
| +0xD4 | `effectFile` (0x59) | **"gfx/FX/billboard.fx"** | ParseString |
| +0xF0 | `noOfFrames` (0x1B) | 1 | ParseInt |
| +0xF8 | `offset` (0x161), **one float** | 0.0 | ParseFloat |
| +0x104 | `font_size` (0x182), float | 1.0 | sscanf "%f" |
| +0x108..+0x110 | `offset2` (0x17F), three floats | 0 | ParseVector3 |
| +0x114 | `font` (0x1D) | "" | ParseString |

- That table is `CBillboardType::LoadKey` (`0xB071C0`, slot 4). Anything else goes to `CObjectType::LoadKey` (`name` and
  the rest). The tokens' names come from `saveTokens.py`. The weather type's record already had `scale` at +0x98 by the same
  token.
- The two readers whose destinations the decompilation lost are ParseFloat (`0xA7B640`: `sscanf("%f")` with the parse
  context in ECX and the destination in EAX) and ParseVector3 (`0xA7B070`: `{` then three numbers then `}`).

**LoadResources** (slot 6, `0xB06DB0`, `ret 4`). In order:
1. +0x44 = graphics +0x158, the texture table.
2. **The texture**: +0x100 = the loader `0xA60F30` on `textureFile`.
3. **The effect**: FxHandler_Register(graphics +0x6BCFC, path `effectFile`, **key `effect`**, device) into +0x94. With the
   defaults, **every plain billboardType shares one ID3DXEffect, keyed "Billboard"**. No plain entry in TFH names either
   key **[mod]**. A type naming only its own `effectFile` would still get the shared effect, because the key is looked up
   first.
4. CreateVertexDeclaration from **BillboardVertexElements** (VA `0x17092EC`): stream 0, offset 0 FLOAT3 POSITION; offset 12
   FLOAT2 TEXCOORD0; 20 bytes a vertex. Identical to the counter's and the weather's.
5. **+0xF4 = (float)(w / P(w)) / noOfFrames**, where w and h are the texture's picture size (table row +0x24/+0x28) and
   P(n) is the least power of two ≥ n.
6. **The quad**: a managed MeshBuffer at +0xFC. VertexBuffer_Create(4, stride 0x14, fvf 0, not dynamic) and
   IndexBuffer_Create(6). With s = `scale` and U = +0xF4:

       v0 (-s, -s, 0)  uv (0, 1)     lower left
       v1 (-s,  s, 0)  uv (0, 0)     upper left
       v2 ( s, -s, 0)  uv (U, 1)     lower right
       v3 ( s,  s, 0)  uv (U, 0)     upper right
       indices 0 1 2, 2 1 3 - clockwise seen from the camera, D3D's front face

   **Always a square 2s across** **[exe]**: there is no aspect term. **u is corrected for the texture's power-of-two
   padding and v is not.**
7. The font: where `font` is not empty, +0x130 = the font of that name (graphics +0x88, else +0x94); otherwise 0.

What the padding means for TFH's files **[mod]**:
- `combat_status.dds` 192×64, 3 frames: U = 0.75/3 = 0.25.
- `counter_arrows.dds` 64×32, 2 frames: U = 0.5.
- `building_airbase`/`navalbase` 128×64, 2 frames: U = 0.5.
- TFH's `building_underground.dds` 448×64, 7 frames: U = 0.125.
- Each of these frames is square, so the square quad fits.
- **The four `resource_*.dds` are 40×40**, padded to 64 *(inferred, from D3DX's documentation as in `FINDINGS-counters.md`
  10.2)*. Their u runs to 0.625 and their v to 1.0, so the picture fills the top 62.5% of the square and is stretched
  across its full width.

**ReleaseResources** (slot 7, `0xB07180`) frees the texture and the declaration. The quad is freed by the next
LoadResources.

**The other slots** of the 38: 0 the destructor (`0xB06BF0`), 18 CreateInstance, 31 DrawQuad, 32 `0xB07A50` (the hit test
of the quad, not read), 33 `0xB080E0` (not read), 34 ReturnZero (no animation frames), and 35 to 37 below.

## 2. The draw

**Who queues.** A billboard object's slot 12 answers no mesh, so `MapObjectGroup_Draw` takes its no-mesh path for it and
calls its slot 10. `CBillboardObject::Render` (`0xAB6A60`) **ignores its arguments and only queues itself** with its type's
slot 37: `QueueForDraw` (`0xB07640`) pushes it onto **g_BillboardDrawList** (VA `0x1B26A48`). It does not copy the matrix
it is handed, so a billboard is drawn from the world transform (`+0x94`) it already holds.

**The flush, at the end of each object group.** In `MapObjectGroup_Draw`:
1. 0xA71D28: `BillboardList_DrawBatch(g_BillboardDrawList, graphics)`, the plain billboards.
2. 0xA71D37: `CEU3Graphics::FlushDeferredObjects`, i.e. the counters and then the weather pictures.
3. ALPHABLENDENABLE 0.

So within a group the plain billboards are drawn **before** the counters.

In `BillboardList_DrawBatch` (`0xB073B0`), in order:
1. The first queued object's type's slot 35: **BeginBatch** (`0xB074E0`).
   - SetVertexDeclaration(+0x90).
   - **SetTechnique(GetTechniqueByName("standard"))** **[exe]**: the technique by name. `effect` is the registration key,
     not the technique.
   - **ViewProjectionMatrix = D3DXMatrixMultiply(view, projection)** of the current view's camera (graphics +0x6BC88 →
     +0x1C, slots 91 and 93).
   - **Begin(&passes, 0)** and **BeginPass(0)**.
2. For each object in queue order, `CBillboardObject::Draw` with (graphics, device, &object +0x94, its time). It calls the
   type's slot 31, DrawQuad.
3. Slot 36: **EndBatch** (`0xB07600`), EndPass and End.
4. For each object, `CBillboardObject_DrawCaption`.
5. The list is emptied.

So one Begin/End covers the batch, with the first object's type's technique and declaration. They are identical for every
plain type.

**One billboard: `CBillboardType::DrawQuad`** (`0xB076D0`, twelve stack values, `ret 0x30`). Every handle is fetched by
name:

| parameter | value |
| --- | --- |
| `vMultiplier` | **1.5 where the object's `+0x148` is 1**, else 1.0 (the float at `0x17179AC`). The shader multiplies the whole RGBA by it. |
| `tex0` | the type's texture (+0x100 through the table; null where −1 or above 9999) |
| `WorldMatrix` | **T × R × W**. T = translation (`offset`, 0, 0). R = D3DXMatrixRotationZ(the object's `+0xB24`), multiplied T then R at 0xB078B5. W = **D3DXMatrixInverse(view)** (0xB078F4) with `_14`, `_24`, `_34` = 0, its translation row = the object's world translation (`+0x94` +0x30/+0x34/+0x38), `_44` = 1. |
| `vXOffset` | (float)((double)`+0xF4` × max(frame, 0)), frame the object's `+0x4E` (slot 25) |
| `vScale` | the object's `+0xB28` |
| `vFlip` | −1.0 with the object's `+0x14A`, else 1.0 |

Then CommitChanges and VertexBuffer_Draw: SetStreamSource(0, VB, 0, 20), SetIndices,
DrawIndexedPrimitive(TRIANGLELIST, 0, 0, 4, 0, 2).

- **W's rows are the camera's right, up and forward**, so the quad lies in the camera's plane. R turns it about the
  camera's forward axis.
- T comes before R, so **the picture stands `offset` from its object's point in the direction it is turned to**.
- `vScale` multiplies only the vertices (`In.Position * vScale` before the matrices), **so it sizes the picture and never
  `offset`**.
- **`flip`**: D3DXMatrixRotationY(π) is written to the same local matrix (0xB0779A), the matrix is then set to the identity
  (0xB077A2-0xB07804) and D3DXMatrixRotationZ overwrites it (0xB0781A; both outputs resolve to the frame's `[esp+0x10]`).
  The flip therefore never reaches the matrix, and billboard.fx declares `vFlip` and never reads it.
- Not read by DrawQuad: `animationFrame`, `time`, the seventh argument (0) and the eleventh (slot 69's answer). The type's
  slot 34 answers 0, so Draw's animation path never runs for a plain billboard.

**The object's fields as the draw sees them.** The constructor sets:
- `+0x148` = 0 (selection);
- `+0x14A` = 0 (flip);
- `+0x150` = 0;
- `+0xB24` = 0.0 (rotation);
- `+0xB28` = 1.0 (draw scale).

What changes them:
- `+0x148` is written only by slot 23 (`0xAB6F30`, `SetSelection`, the slot `CCounterObject::SetSelection` has). No call
  reaching a picture was found, so as far as is known `vMultiplier` is 1.0 (*inferred*).
- `+0xB28` is written only by the constructor and the three large map-mode icons (section 3). A sweep of `.text` for the
  displacement found those and the constructor, which is its positive control.
- `+0xB24` is written only by SetRotation (slot 37, `0xAB6F50`): `+0xB24 = −(argument + π/2)` (the double at 0x160A2A0).

**Render states.** The pass sets ZENABLE false, ZWRITEENABLE false, ALPHABLENDENABLE true and ALPHATESTENABLE false
(vs_2_0 / ps_2_0); End restores them. The rest is the device's:
- SRCBLEND SRCALPHA / DESTBLEND INVSRCALPHA, set at the start of `MapObjectGroup_Draw` (*inferred*, as for the counters,
  `FINDINGS-counters.md` 10.5).
- CULLMODE NONE.
- The sampler is the file's: CLAMP, linear min, mag and mip.

With Z off, **a billboard is drawn over everything drawn before it** and is hidden by nothing behind it.

**The caption** (`CBillboardObject_DrawCaption`, `0xAB6BE0`, `ret 0x10`). It runs only for an object whose caption
(`+0xB2C`) is not empty, which means only the battle markers. In order:
1. up = normalize(the view's second column `_12 _22 _32`) and right = normalize(its first column `_11 _21 _31`). A look
   direction is also normalized and not used.
2. **SetTransform(WORLD, the object's `+0x94`)**: its whole world matrix.
3. If the type has no font, nothing more.
4. k = (float)(`scale` × 0.1) **[exe]**; position = `offset2` × k.
5. ZENABLE and ZWRITEENABLE are saved and set to **g_BillboardCaptionZEnable** and 0. That global is 1 in the file and set
   to 0 by the graphics owner's constructor at 0x640939, its only writer, so **Z is off**.
6. **Font slot 7(text, 2, 0x140, &position, &up, &right, k × `font_size`, 1.0, 0, 0xF)**.
7. The two states are restored.

| | k | position | text height |
| --- | --- | --- | --- |
| `combat_status` | 0.26 | (0, 0, −0.65) | 1.82 |
| `combat_status_close` | 0.17 | (0, 0, −0.51) | 1.19 |

The position is in world axes, z north **[mod: the figures from `mapitems.gfx`]**. What the font's slot 7 does with its
arguments was not read; it is the same routine the counters' texts use.

## 3. Which things on the map are plain billboards

Every `billboardType` of `mapitems.gfx` is drawn by section 2. Where each one is made and placed:

| billboard | made by | layer (graphics owner) | where it stands | rotation, frame, scale |
| --- | --- | --- | --- | --- |
| `counter_arrow` | `CCounterObject::CCounterObject`, one per counter (`+0x1B4`) | the counter's own, queued by `CCounterObject::Render` where `shows_arrow` is set and the counter is shown | **the counter's world translation, copied each frame and not lifted** (the counter batch lifts only the counter); then `offset` 4.5 along its turned x | rotation −(h + π/2) = −a (`FINDINGS-counters.md` 9); frame 0 green from `ShowMoving`; **scale always 1** |
| `combat_status` / `_close` | `CCombat::UpdateCombatStatusWindow` | +0xA70 (layer 6) / +0xBEC (layer 7) | hung on the battle province's anchor, then **every call** SetPosition(M − D, height −0.0) and UpdateTransform: **the anchor plus half the vector from the defender's first unit to the attacker's, at height 0** (the 1.0 raise is overwritten) | rotation −(h + π), h the attacker's first unit's `+0x104`; frame and number below |
| `building_<name>` | `ProvinceGraphics_UpdatePictures` | +0x1358 (WaterObject group +0x5C) | Translate(position − label point, 0) **then** hung with raise 1: **(building x, 1.0, building y)** | rotation 0; frame 1 of the naval/air base with a unit there (`FINDINGS-seaair.md` 6); scale 1 |
| `capital` | the same function | the same | translated then hung, as the buildings (its vector not read here) | 0, 0, 1 |
| `large_air_base`, `large_anti_air`, `large_naval_base` | `ShowLargeAirBaseIcon`, `ShowLargeAntiAirIcon`, `ShowLargeNavalBaseIcon` | +0x14D4 (WaterObject group +0x60) | hung with raise 1 **then** Translate(building position − label point, 0); see the open point below | frame from Update{AirBase,Port}Picture; **`+0xB28` = (level − 1) × 0.2 + 1** |
| `air_battle_icon`, `air_bombed_us_icon`, `air_bombed_them_icon` | `ShowAirBattleIcon` etc. (`FINDINGS-airmap.md` 4) | +0x14D4 | hung, **then** Translate (3,3,0) / (0,3,3) / (0,3,−3) | 0, 0, 1 |
| `naval_convoy_raided_icon`, `naval_convoy_sunk_icon`, `naval_raider_defended_icon`, `naval_raider_attacked_icon` | `ShowConvoyRaidedIcon` `0x642D30`, `ShowConvoySunkIcon` `0x642E90`, `ShowRaiderDefendedIcon` `0x643000`, `ShowRaiderAttackedIcon` `0x643160`, from `UpdateNavalMapIcons` (mode 19) | +0x14D4 | hung, **then** Translate (3,3,0) / (−3,3,0) / (0,3,3) / (0,3,−3) | 0, 0, 1 |
| `supply_depot`, `resource_*`, `STRATEGIC_*`, `icon_objective_strip` | `ProvinceGraphics_UpdateSupplyDepotPicture`, `…UpdateResourcePictures`, `…UpdateStrategicResourcePicture`, `GraphicsOwner_RefreshColourTextures` | `resource_*`, `STRATEGIC_*`: the owner's +0x17CC (WaterObject group +0x70), shown with GameSettings +0xE7 under 500 (`FINDINGS-mapmodesfigures.md`, section 5); the others not read here | not read here | not read here |
| `airnaval_combat_icon` | **nothing**: no reference to its name in `.text` (*inferred* unused; the same scan found every other name) | | | |

**The battle marker's number and colour.**
- The colour is the frame of `combat_status.dds` (green, yellow, red from the left), chosen by the attacker's share against
  660 and 330, mirrored when the player defends (`FINDINGS-combatview.md` 9). Both billboards take the same frame. It
  reaches the shader as `vXOffset` = 0.25 × frame.
- The number is the caption: FormatFixedPoint(share × 100000 / 1000, 0), the share as a whole percentage, drawn by
  section 2's caption pass in `Arial_17_black`.

**Order on screen.** `MapGraphics_DrawScene` draws its groups in the order +0x5C (building pictures), +0x70, +0x64 (the
weather group) and +0x60 (the rings, then the large icons and event icons of +0x14D4). Each group flushes its billboards at
its end. `GraphicsOwner_DrawLayers` then draws the owner's layers: +0xEE4, +0xC, +0x8F4, +0x480, +0x1060, +0x188, **+0xBEC
(the near marker)**, +0x11DC, +0x304, **+0xA70 (the far marker)**, and so on. A layer holding counters flushes their
pointers before the counters.

Within one flush the order is the queue's, i.e. the group's draw list. `0xA659C0` copies that list out of the layer's map,
which `ObjectLayer_Add` keys by the object's address, so the order is *likely* ascending heap address.

`MapObjects_UpdateLayerVisibility` decides what is drawn at all:
- building pictures only below height 500;
- the near marker below `counter_distance`, the far marker from there to 500;
- +0x14D4 at every height while the mask is not 0.

## Not established

- ~~**Whether the pictures moved after they are hung ever stand where they were moved to.**~~ **Settled 2026-11-07: they
  do.** The maintainer's two screenshots of the original's air map mode have the air battle icon east of the province and
  the bombing icon south-west of it in one and north-west in the other: the battle's (3, 3, 0) and the bombings'
  (0, 3, -3) and (0, 3, 3) read as east, up and north, with the camera's tilt. So a refresh of +0x94 exists that the search
  below did not find - another negative without a positive control on the right path (`TRAPS.md`, closing section). The
  reasoning as it stood: These are the three large icons
  and the seven battle/naval event icons. Each is given its Translate after `ProvinceGraphics_PlacePicture` has computed its
  world transform (+0x94) from its local one, and that Translate writes only the local. Nothing found re-derives +0x94
  afterwards:
  - `UpdateTransform`'s no-argument calls in the image are 79. The battle markers' two are among them, as the positive
    control, and none is on a province anchor or a picture.
  - Its child walk `0xA5FA10` has no other caller.
  - The scene walk at `0xA73890` that does recompute every frame is the interface's 2D one (x/y added, z = −1).

  On this reading they are drawn at the province's anchor + (0, 1, 0), all ten on one point, and **the building nudge**
  (`positions.txt` `building_nudge`, written by SetLocal after hanging) does not reach the screen either (*inferred*). *A
  screenshot of the air map mode with an air battle and a bombing in one province settles it: offset icons mean a refresh
  exists that was not found.*
  It did, and they are offset.
- Who sets a billboard's `+0x148` to 1 (`vMultiplier` 1.5), if anything does.
- What hides a counter's pointer again, and when its red frame is used.
- The type's slots 32 (hit test) and 33. The object's destructor.
- ~~What the four naval counts count.~~ Answered 2026-11-07 (`FINDINGS-mapmodesrest.md`, 3.2): they are four yes/no
  flags, not counts, from the week's naval battles - convoys we sank, our convoys raided, we were attacked, we attacked.
- The capital's vector, and the frames of `building_underground` and `icon_objective_strip`.
- The font's slot 7: how 2, 0x140, the size and 1.0 turn into glyphs.
- Whether the lower-case `texturefile` of the `STRATEGIC_*` entries matches the `textureFile` token.
- Whether D3DX really pads the 40×40 resource icons (*inferred* from its documentation).

**Frontier** (rvas): `0x707A50`, `0x7080E0`, `0x6B6A00`.
