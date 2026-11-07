# A masked shield: a country's flag cut to a shield, through `maskedflag.fx`

*Read 2026-11-07, statically, by a delegated agent (fragment `interface-maskedflag.json`), for OpenHOI3, which wants to draw
a `maskedShieldType` through the install's own `gfx/FX/maskedflag.fx` fed exactly as the original feeds it. Functions are
named by rva; instruction sites are VAs (rva + 0x400000). Only valid for this build of `hoi3_tfh.exe`. Nothing here was
checked in a running game; the flag atlas was checked against the cached atlas file the game left in the install.*

**Corrections, rather than additions**: `CMaskedSpriteType::LoadKey` now says where each key lands and that every other
key falls through to `CSpriteType::LoadKey`; `LoadFlags` was recorded `void __cdecl LoadFlags(void)` and takes the graphics
in ECX; and `FINDINGS-provincetooltip.md`'s open item, which texture the `@TAG` flag atlas is, is answered (section 5).

## In one line

A `maskedShieldType` is a `CMaskedSpriteType`; every element showing one owns a `CShieldObject`, whose render draws
**the flag** - one cell of a flag atlas built from `gfx/flags/<TAG>.tga` - through the effect, cut to the mask's alpha,
with the technique `tec0`, `down`, `over` or `disable` by the element's state, and then **the overlay** over it with
plain alpha blending, the same in every state.

## 1. The sprite type and its keys

`maskedShieldType` makes a `CMaskedSpriteType` (RTTI; `: CSpriteType` at 0; table rva `0x11E1D44`; 0x250 bytes, made by
the spriteTypes factory at VA `0x8409CB` and `CMaskedSpriteType::CMaskedSpriteType`, rva `0x44BE10`, which is handed
the graphics in ECX and the flag atlas `&CGraphics +0x6BD6C`). `CMaskedSpriteType::LoadKey` (`0x44C030`):

| key | token | lands |
| --- | --- | --- |
| `textureFile1` | 0x25 | `+0x1C0` - **the overlay**, drawn over the flag |
| `textureFile2` | 0x26 | `+0x1A4` - **the mask**, whose alpha is the shield's shape |
| `effectFile` | 0x59 | `+0x1F4` - its own string; `CSpriteType`'s `+0x5C` stays empty |
| anything else | | `CSpriteType::LoadKey` (`0x6B7A00`) - so `allwaystransparent`, `transparencecheck`, `clicksound`, `noOfFrames`, `textureFile` are accepted |

`confirmed`. Of the passed-through keys only `allwaystransparent` is written in the game's files (core.gfx's
`GFX_minishield_war`, eu3dialog.gfx's two dialog shields), and it only matters for clicks (section 6). **`noOfFrames`
does nothing on a masked shield**: neither its quad builder nor its render reads `+0x94`, where `CSpriteType`'s own
quad builder divides by it (VA `0xAB85BF`) - the positive control.

**Who shows one.** Their Finest Hour declares twelve (core.gfx six, topbar.gfx two, eu3dialog.gfx two,
country_diplomacy.gfx and unitpanel.gfx one each), used by four element kinds:

| element | how it names the sprite | uses |
| --- | --- | --- |
| `iconType` | `spriteType` | the top bar's `player_flag` (`GFX_topbarflag`), combat.gui's `shield`, the diplomacy and espionage country flags (`GFX_thinshield`, rotation -1.5708), province_interface `flag`, brigadeview, the ledger, the unit panel's attacker and defender (`GFX_minishield_war`), `exp_force`, diplomacy's `GFX_flag_tiny` |
| `guiButtonType` | `quadTextureSprite` | the diplomacy/espionage/politics/theatres country list buttons (`GFX_minishield`, `_small`), province_interface `owner_flag` (thinshield, -1.5708) and `occupier_flag`, lobby shields |
| `checkboxType` | `quadTextureSprite` | menubar.gui `shield` (`GFX_minishield_greydown`) |
| `shieldtype` (in an eu3dialog window) | `spriteType` | every dialog's `LeftShield`/`RightShield` (thinshield / standarddialogshield, -1.5708) |

BlackICE's interface has the same twelve sprites and the same uses, plus battleplansinterface `flag` and cgm
`player_flag`. **An icon is given its country through its slot 53**, `CIcon::SetCountry` (`0x6A2730`), a tail jump to
slot 83 of its sprite object - `CShieldObject::SetCountry` - which is how `SetDialogLeftShield` (`0x23E5B0`) sets a
dialog's shield from a `CCountryTag`'s id. `confirmed`.

## 2. Loading: the textures and the effect

`CMaskedSpriteType::LoadResources` (slot 6, `0x44C0A0`), `confirmed`:

- The mask and the overlay go through the texture handler (`CGraphics +0x158`) into `+0x210` and `+0x214`. Each file's
  **own** width and height go into `+0x1DC/+0x1E0` (mask) and `+0x1E4/+0x1E8` (overlay). The handler pads a picture into
  the top-left of a power-of-two texture (`FINDINGS-mapdraw.md`, A.3), which is why every texture coordinate below is a
  size over its next power of two.
- **The effect is `FxHandler_Register(graphics +0x6BCFC, effectFile, effectFile, device)`.** The string is both the path
  and the key, so every masked sprite naming the same file shares one `ID3DXEffect`; its index goes to `+0x218`.
- Handles are taken by name: `GetParameterByName(NULL, …)` for `tex0`, `tex1`, `FlagCoords`, `WorldViewProjectionMatrix`,
  and `GetTechniqueByName` for `tec0`, `over`, `down`, `disable`. **There is no `up`; `tec0` is the normal technique.**
- It also builds a plain quad (`+0x220`) that nothing read here draws.

## 3. The draw

`CShieldObject` (RTTI, `: CSprite`, 0x1AC bytes) is made by the type's slot 23 (`CreateInstance`, `0x44CAE0`). Its
constructor (`0x47E760`) takes the type in ECX, the graphics and the atlas, and **sets the country to `SWE`'s tag** - a
shield shows Sweden's flag until a country is set. `CShieldObject::Render` (slot 10, `0x47E830`), `confirmed`:

1. Saves ZENABLE and ZWRITEENABLE and sets both to 1; FOGVERTEXMODE 0; **SRCBLEND = SRCALPHA, DESTBLEND = INVSRCALPHA**.
2. **The flag's cell.** id = the country id (`+0x190`), 0 taken as 1; k = id − 1; the atlas row is k div columns, the
   column k mod columns. **`FlagCoords` = (columns, rows, column / columns, row / rows)** as floats; the texture is the
   atlas's. **Where the shield has a picture of its own** (`+0x1A4`, set by slot 84 `SetTexture` from a texture-handler
   index and cleared by `SetCountry`), `FlagCoords` = (1, 1, 0, 0) and that picture is the texture instead.
3. If the object's rotation (`+0x14C`) differs from the type's `+0xA0`, it is copied there and the type's slot 27
   rebuilds the shared quad.
4. `CMaskedSpriteType_DrawFlag` (`0x44C7A0`) is called with the type, the graphics, the object's matrix (`+0x94`), the
   texture, `&FlagCoords` and the state:
   - **technique**: state 2 → `down`, 3 → `over`, 4 → `disable`, anything else → `tec0`;
   - **`WorldViewProjectionMatrix`** = matrix × identity × `D3DXMatrixOrthoRH(screen width, screen height, 0, 1)` (the
     import resolves by name), so positions are screen pixels about the screen's centre, y up;
   - **`tex0`** = the texture from step 2; **`tex1`** = the mask; **`FlagCoords`** as in step 2;
   - where the matrix's float at `+0x3C` differs from the type's `+0x110` (−1.0 after the buffer is made), slot 27
     rebuilds the quad - in effect, on the first draw;
   - `Begin(&passes, 0)` (which saves and restores the device state), `BeginPass(0)`, `CommitChanges`, then
     `VertexBuffer_Draw` of the quad at `+0xEC`: **SetFVF(0x202 = XYZ|TEX2)**, after the pass, so the file's `fvf = XYZ |
     Normal | Diffuse | Tex1` pass state is overridden; a triangle fan of 4. Then `EndPass`, `End`.
5. **The overlay**, fixed-function: four vertices covering the overlay box (section 4), z 1.0, FVF 0x102 (XYZ|TEX1),
   `SetTexture(0, overlay)`, ALPHABLENDENABLE 1, `DrawPrimitiveUP(TRIANGLEFAN, 2, stride 0x14)`, ALPHABLENDENABLE 0. Then
   the two depth states are put back.

**The state changes only the flag**; the overlay is drawn the same whatever it is. That 2/3/4 mean pressed, hovered,
disabled is `likely`: `CShieldObject`'s slot 8 (`0x706050`) maps exactly those values to the strings `down`, `over`,
`disable` (and the rest to `up`), as `CSpriteType`'s object does at VA `0xAB5B20`. Which value each element kind passes
was not read.

**`maskedflag_greydown.fx`** has the same parameters and techniques; it differs in two ways: both samplers are Point (the
flag's is Linear in `maskedflag.fx`), and its `down` greys the flag like `disable`. Only `GFX_minishield_greydown` names
it. **`masked3dflag.fx` is never a `maskedShieldType`'s**: it is loaded from a fixed path (`/FX/masked3dflag.fx`, key
`Masked3dFlag`, at VA `0x84B1DD` in the unread `0x44B020`) for the `objectTypes` kind `Masked3dFlag` (the allied-objective
marker in mapitems.gfx), which takes no `effectFile`.

## 4. The vertices

All in one local box: x from 0 to FW, y from 0 to FH, **y up**, FW × FH the overlay's size; z = 1.0.

**The flag** (`CMaskedSpriteType::BuildQuad`, slot 27, `0x44CC10`; buffer from slot 29, `0x44CB80`: 4 vertices, stride
0x1C, position + two texture coordinates). W × H is the mask's size; ox = (FW − W) × 0.5 and oy = (FH − H) × 0.5 (**the
mask is centred in the overlay**); P(n) the least power of two ≥ n; w2 = W/2 and h2 = H/2 as whole numbers; R turns by the
rotation θ (`+0xA0`): x' = cos θ·x − sin θ·y, y' = sin θ·x + cos θ·y (`_CIcos`, `_CIsin`).

| | position | TEXCOORD0 (flag) | TEXCOORD1 (mask) |
| --- | --- | --- | --- |
| v0 | R(ox − w2, oy − h2) + (w2, h2) | (0, 1) | (0, H/P(H)) |
| v1 | R(ox − W/2, oy + H/2) + (W/2, H/2) | (0, 0) | (0, 0) |
| v2 | R(ox + W/2, oy + H/2) + (W/2, H/2) | (1, 0) | (W/P(W), 0) |
| v3 | R(ox + w2, oy − h2) + (W/2, H/2) | (1, 1) | (W/P(W), H/P(H)) |

Drawn as a fan v0, v1, v2, v3. `confirmed` off the listing. Three things that look wrong are kept as read:

- **The whole-number halves and the 0.5 halves are mixed.** For an odd W or H, at θ = 0 v3 comes out at (ox + W − ½,
  oy + ½) rather than (ox + W, oy). It shows on `shield_mask` (66 × 51, half a pixel up) and `topbarflag_mask` (93 × 64,
  half a pixel in).
- **The flag turns about (W/2, H/2) and the overlay about (FW/2, FH/2).** These are the same point only where the mask and
  the overlay are the same size. The only rotated sprite in the files, `GFX_thinshield`, has both 66 × 51, so nothing in
  the game shows the difference.
- **The mask is not cut to a frame.** TEXCOORD0 covers 0 to 1, which is the atlas cell exactly once `FlagCoords` divides
  and offsets it.

**The overlay** (in `CShieldObject::Render`, halves × 0.5, R by the object's `+0x14C`):

| | position | uv |
| --- | --- | --- |
| v0 | R(−FW/2, −FH/2) + (FW/2, FH/2) | (0, FH/P(FH)) |
| v1 | R(−FW/2, FH/2) + (FW/2, FH/2) | (0, 0) |
| v2 | R(FW/2, FH/2) + (FW/2, FH/2) | (FW/P(FW), 0) |
| v3 | R(FW/2, −FH/2) + (FW/2, FH/2) | (FW/P(FW), FH/P(FH)) |

## 5. The flag atlas

`LoadFlags` (`0x440BC0`, the graphics in ECX) calls `FlagTextureMap_Build(&graphics +0x6BD6C, "gfx/flags", countries,
graphics)` (`0x4427C0`; its log lines name `flagtexturemap.cpp`). Read in part, so `inferred` as a whole; `confirmed`
where it agrees with the file:

- One file a country, **`<TAG>.tga`**, for every country of the database whose tag starts with a letter, in database (id)
  order. **Cell k holds country id k + 1**, row-major from the top.
- N flags; s = (int)√N. If s is a power of two: rows = s, columns = s, and columns = 2s where s² < N. Otherwise: rows =
  P(s), columns = P(⌈N / rows⌉). Stored at map `+0x24` (rows) and `+0x28` (columns).
- The texture is P(93 × columns) wide and P(64 × rows) high; 93 and 64 are set by `CEU3Graphics::CEU3Graphics` (`CGraphics
  +0x6BD98/+0x6BD9C`). A cell is texture width / columns by texture height / rows. **Each flag is drawn whole into its
  cell, whatever its own size**, onto a render target cleared to white, copied into an A8R8G8B8 texture. Each row's cells
  hold {u = column / columns, v = row / rows}.
- The atlas is cached as `gfx/flags/flagfiles.tga`, with `flagfiles.txt` reading `PowerOf2` and then every flag file in
  order. `Missing flag for <TAG>` and `Failed to load flag texture` are its log lines.

**Against the install** (`gfx/flags/flagfiles.tga`, `flagfiles.txt`): 101 flags give s = 10, rows 16, columns 8, and a
1024 × 1024 texture of 128 × 64 cells. The file is exactly that (1024 × 1024, 32 bits, checked again by the collecting
session): its column boundary at x = 128, unused cells 101–127 white, and **97 of 101 cells match their flag file**
sampled at six points of each, read in that order; the four misses are flags with fine detail (NZL, AST, GUY, OMN). So
each 93 × 64 flag is stretched to 128 × 64 in the atlas.

`CEU3BitmapFont::DrawFlagIcon` (`@TAG` in text) reads the same atlas - rows at `+0x6BD90`, columns at `+0x6BD94` - and
samples the cell from (u, v) to (u + 1/columns, v + 1/rows). That answers `FINDINGS-provincetooltip.md`'s open item:
**the atlas's texture is `CGraphics +0x6BD6C`, and a flag fills its cell.**

## 6. Clicks

`CMaskedSpriteType::ContainsPoint` (slot 16, `0x44C4E0`): inside the overlay's rectangle, **strict at both ends** (the
plain sprite's is inclusive at the near end). `CMaskedSpriteType::IsTransparentAt` (slot 18, `0x44C530`):

- see-through where `allwaystransparent` is set; **`transparencecheck` is never asked**;
- otherwise the point is moved by the mask's offset in the overlay (`+0x1EC/+0x1F0`, written by each draw) and is
  see-through past the mask's **width** in x *or* in y (the height is not used);
- else solid where the mask's alpha is not nought, else solid where the overlay's alpha at the unmoved point is not
  nought, else see-through.

So a shield is solid wherever the mask or the overlay is opaque. `confirmed`.

## Not established

- **How the object's matrix (`CShieldObject +0x94`) is made** from the element's position and orientation; whether it
  carries a rotation as well as `+0x14C`; and what its float at `+0x3C` is. So the rotation's sense on screen (−1.5708 a
  clockwise quarter turn, if the matrix does not mirror y) is `inferred`, as is how z = 1.0 under `OrthoRH(…, 0, 1)` (clip
  z = −1) escapes clipping.
- **Who sets `+0x14C`.** That it is the `.gui` `rotation` is `inferred` from the files.
- **Which state each element kind passes** to the render, and so when `over`, `down` and `disable` appear; who calls
  `Render`.
- **The overlay's texture-stage states**, which the render does not set and leaves to the interface's own.
- **When the atlas cache is used rather than rebuilt** (`0x4417E0`), how each flag file is loaded, and what a flag of
  another size or a missing one actually gives: a white cell by the build's logic, but BlackICE's `CLAUDE.md` records
  startup dying at "Processing Flags" for a missing `.tga`.
- `masked3dflag.fx`'s feed (`0x44B020`, `CMasked3dFlagType` slot 6 `0x44B790`, `CMasked3dFlag` slots 9 and 10).
- Whether `CSpriteType +0xA0` and `+0x110` mean the same (rotation, scale) on a plain sprite type; read on the masked type
  only.

Frontier: 0x660F30, 0x6610E0, 0x661300, 0x674470, 0x705EB0, 0x4417E0, 0x44B020, 0x44B790, 0x44BDA0, 0x44BDD0, 0x6B8540.
