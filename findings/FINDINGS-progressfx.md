# A progress bar: `progressbartype` through `progress.fx`

*Read 2026-11-07, statically, by a delegated agent (fragment `interface-progressfx.json`), for OpenHOI3, which wants to draw
a `progressbartype` through the install's own `gfx/FX/progress.fx` fed exactly as the original feeds it. Functions are
named by rva; instruction sites are VAs (rva + 0x400000). Only valid for this build of `hoi3_tfh.exe`. Nothing here was
checked in a running game; the revised `CObjectType::LoadKey` was checked again off the bytes by the collecting session.*

**Corrections, rather than additions**: rva `0x6F9640` was `CProvinceType::LoadKey` with one key (`norefcount`); it is
**`CObjectType::LoadKey`**, the base every `.gfx` type falls through to, with three keys (section 1). And
`ObjectType_CreateByToken`'s comment knew one of its two jump tables; the second is where `progressbartype` is made.

## In one line

A `progressbartype` is a `CProgressBarType`. Each icon showing one owns a `CProgressBarObject`. That object draws a quad of
`size` through the effect: technique `ColorProgress` with `textureFile1`/`textureFile2` when both loaded, else `tec0`
with `color`/`colortwo`. `CurrentState` is the share (0..100, through the icon's frame) / 100 × the texture's own-width
fraction. The quad's v runs **up** the local frame where the masked shield's runs down, which is why both pictures come
out upside down.

## 1. The sprite type and its keys

`progressbartype` is token 313. `ObjectType_CreateByToken` (`0x670550`) reaches it through its second byte table (VA
`0xA70BD0`) and jump table (`0xA70B98`), which cover tokens 0x139..0x1AD; the first table covers only up to 0x118. The
arm makes **0x180 bytes** with `CProgressBarType::CProgressBarType` (`0x726CA0`). The factory is reached as the default
arm of the CEU3Graphics factory `0x4408E0`, the one that makes `maskedShieldType`.

**There is no RTTI for it.** The dword before its table `0x16068F0` (rva `0x12068F0`, 26 slots) is a code address, not
a complete object locator. The positive control: the same read before `CMaskedSpriteType`'s table gives
`.?AVCMaskedSpriteType@@`. No string in the image containing "progress" names a class. So **`CProgressBarType` is a name
made from the keyword**, and `CProgressBarObject` likewise. Its constructor does **not** call the CSpriteType
constructor: it is a direct object type, not a sprite type, and fills the CObjectType part itself. *confirmed*.

`CProgressBarType::LoadKey` (`0x727820`), *confirmed*:

| key | token | lands |
| --- | --- | --- |
| `textureFile1` | 0x25 | `+0xB0` - the picture over the **filled** part (tex0) |
| `textureFile2` | 0x26 | `+0xCC` - the picture over the **rest** (tex1); **its own size sets the texture coordinates** |
| `size` | 0x2E | `+0xF0`/`+0xF4` as ints, read strictly as `{ x = N y = N }` (`ParseIntPairXY`, `0x67B670`, `%i`) |
| `color` | 0x55 | the CColor at `+0x78` (its slot 3, `CColor::Load`) |
| `effectFile` | 0x59 | `+0x5C` |
| `horizontal` | 0x96 | bool `+0x120`, **default 1** |
| `colortwo` | 0x133 | the CColor at `+0x94` |
| `allwaystransparent` | 0x166 | bool `+0x174`, default 0 |
| anything else | | `CObjectType::LoadKey` (`0x6F9640`) |

`CObjectType::LoadKey` takes (its tests at VA 0xAF965E-0xAF9673: token − 0x1A, then − 0x132, then the next):
- `name` (0x1A) → `+8`;
- `loadType` (0x14C) → `+0x50`: 1 for `FRONTEND`, 2 for `BACKEND`, 3 for `INGAME`, 0 otherwise;
- `norefcount` (0x14D) → `+0x4C`;
- anything else is the unknown-key report (`0x67A7B0`).

Evidence that it is the base's:
- 29 direct calls to it, each the default arm of another type's LoadKey;
- CProvinceType and CProvinceWaterType hold it at slot 4 only because they do not override it.

**A colour** (`CColor::Load`, `0x662960`) is `{ r g b }` or `{ r g b a }`:
- each of the first three is scanned with `%f` and **divided by 255 when above 1.0**;
- alpha is 1.0 unless a fourth number follows, which is taken **raw**, not divided by 255;
- a byte at `+0x18` is set when all four are above 0.999.

So `org_bar`'s `{ 0.0 0.0 0.0 0.0 }` is transparent black, and the usual `{ 0.0 0.5 0.0 }` is opaque.

**What the game ships.** 25 `progressbartype` blocks in Their Finest Hour's `interface/*.gfx`, every one naming
`gfx\\FX\\progress.fx`:
- 19 give both textures;
- six give none: `moralebar`, `org_bar`, `testbar`, `traditionbar`, `siegebar`, `unitbar`;
- three are `horizontal = no`: `org_bar`, `siegebar`, `unitbar`, all colour-only;
- two are `allwaystransparent`: `tech_progress`, `tech_progress_current`.

In the `.gui` files **every one of the 52 uses is an `iconType`** naming it by `spriteType`. The unit panel's and the
combat window's `str_bar`/`org_bar` use `rotation = 1.5708`, and so does `modifier_progress`. Six sprites are used by no
`.gui` file.

## 2. Loading: the effect, the handles, the textures

`CProgressBarType::LoadResources` (slot 6, `0x726F80`), *confirmed*:

- **`FxHandler_Register(graphics +0x6BCFC, &effectFile, &effectFile, device)`**. The string is both the path and the
  key, so every bar naming the same file shares one `ID3DXEffect`. The index goes to `+0x11C` and the effect to `+0xF8`.
  An index of 0 leaves the effect null, and the next instruction dereferences it.
- Handles are taken by name:
  - `GetParameterByName(NULL, …)` for `WorldViewProjectionMatrix`, `CurrentState`, `vFirstColor`, `vSecondColor`,
    `tex0`, `tex1`;
  - `GetTechniqueByName` for **`tec0`** and **`ColorProgress`**;
  - **`ScrollTech` is never asked for by a progress bar.** Its only two users (VAs `0xB1FA31`, `0xB1FCA0`) are in the
    `scrollingSprite` type (token 389, constructor `0x71F7A0`), which is menubar.gfx's `day_night_scroll`.
- A non-empty `textureFile1` is loaded through the texture handler (`graphics +0x158`, `0x660F30`) into `+0xE8`; a
  non-empty `textureFile2` likewise into `+0xEC`. Each stays -1 when its key is absent.
- **The texture-coordinate extents come from `textureFile2` alone.** U = its own width / P(width), V = its own height
  / P(height), P the least power of two not below (the handler pads a picture into the top-left of a power-of-two
  texture). Both are 1.0 when there is no `textureFile2`. They are stored at `+0x178` and `+0x17C`. `textureFile1`'s
  size is never asked.

## 3. The draw

`CProgressBarType::CreateInstance` (slot 23, `0x727750`) makes the object: 0x198 bytes, `CProgressBarObject` constructor
`0x727970`. The object copies the type's two colours into `+0x15C` and `+0x178`. Progress (`+0x14C`) and rotation
(`+0x150`) start at 0.

`CProgressBarObject::Render` (slot 10, `0x727AD0`) takes a 4×4 matrix as its second argument. It replaces the matrix's
upper three rows by row × R, with R = `MakeRotationZ3x3(+0x150)` = (cos, sin, 0), (−sin, cos, 0), (0, 0, 1). The
translation row is left alone, so a bar **turns about its local origin**: x' = x cos − y sin, y' = x sin + y cos, then
the matrix's own transform. (`0x80BCC0` is cos and `0x80BB90` is sin: their x87 paths execute `fcos` and `fsin`.) It then
calls `CProgressBarType_Draw(type, graphics, &matrix, progress, &first colour, &second colour)` (`0x727310`), *confirmed*:

1. The effect is fetched again from `+0x11C`, and `WorldViewProjectionMatrix`, `CurrentState`, `tec0`, `vFirstColor`
   and `vSecondColor` are taken by name again, **every draw**.
2. **Technique.** If **both** texture indices are ≥ 0: take `ColorProgress`, `tex0` and `tex1` by name;
   `SetTechnique(ColorProgress)`; **`tex0` = the textureFile1 texture, `tex1` = the textureFile2 texture**. The texture
   is the handler entry `graphics +0x15C + index × 0x2C`, null for an index over 9999. **Otherwise `SetTechnique(tec0)`**
   and no texture is set. So a bar with either texture missing falls back to the colours.
3. **`WorldViewProjectionMatrix` = matrix × identity × `D3DXMatrixOrthoRH(screen width, screen height, 0, 1)`**, the
   same composition as the masked shield's.
4. **`vFirstColor`** = the first colour's (r, g, b, a); **`vSecondColor`** = the second's. These are the object's copies
   of `color`/`colortwo`; nothing read here changes them afterwards.
5. **`CurrentState` = (float)(progress / 100.0) × U**: the share, scaled by textureFile2's own-width fraction. The split
   therefore falls at exactly the share of the bar's length, and the textured fill shows the picture's real pixels, not
   the padding.
6. `Begin(&passes, 0)`, `BeginPass(0)`, `CommitChanges`, **`SetFVF(0x102 = XYZ | TEX1)`**, **`DrawPrimitiveUP(TRIANGLESTRIP,
   2, type +0x124, stride 0x14)`**, `CommitChanges`, `EndPass`, `End`.

**No render state is set by the draw.** The pass sets only `ALPHABLENDENABLE` and `ALPHATESTENABLE` (true); blend factors,
`ALPHAREF` and `ALPHAFUNC` are whatever the device holds (unlike the shield, whose render sets SRCALPHA/INVSRCALPHA
itself). Sampling is the file's: Point, Wrap.

## 4. The vertices

Built once per type by `LoadResources`, at `+0x124`, stride 0x14: x, y, z, u, v. W × H is `size`, U × V the extents of
section 2, z = 0 throughout (inside `OrthoRH(…, 0, 1)`).

| | position | uv, `horizontal` (default) | uv, `horizontal = no` |
| --- | --- | --- | --- |
| v0 | (0, 0) | (0, 0) | (0, 0) |
| v1 | (0, H) | (0, V) | (U, 0) |
| v2 | (W, 0) | (U, 0) | (0, V) |
| v3 | (W, H) | (U, V) | (U, V) |

Strip order v0 v1 v2 v3. *confirmed* off the stores. Consequences:

- **TEXCOORD0's third component is nothing.** FVF `TEX1` carries two floats, so the shader's `float3` reads z as the
  API's default 0 (*inferred*: Direct3D 9's rule for missing components, not read in the image). No pixel shader uses
  it.
- **Upside down** (*likely*). u = 0 at local x = 0, so the fill runs from local x = 0. v = 0 at local **y = 0**, and
  v grows with y. The masked shield, drawn through the same ortho composition and upright in the game, puts v = 0 at the
  **top** of its quad (`FINDINGS-maskedflag.md`, section 4: its low-y vertices carry the texture's bottom). So under the
  same y-up frame the bar shows its pictures' top row along the bottom edge: **both textures are flipped vertically**.
  This agrees with OpenHOI3's measurement of the maintainer's screenshots. It is *likely* and not *confirmed* only
  because the bar's matrix arrives from a caller that was not read (the shield uses its own `+0x94`), so that the two
  share a y sense is inferred.
- **`horizontal = no` transposes**: u runs along local y, so the split runs from local y = 0 upwards (by the share of H)
  and a texture would be laid with its x axis up the bar. No shipped vertical bar has textures.
- **A turned bar** (rotation θ, about local (0, 0)) at θ = +1.5708 maps local (x, y) to (−y, x). The fill then runs up
  the screen and the bar lies to the left of its anchor point, given the y-up frame.

## 5. How full a bar is, and who says so

`CProgressBarObject::SetProgress` (slot 23, `0x727E70`): progress = the argument zero-extended from 16 bits, then
**capped at 100**. It is a whole number of hundredths. `GetProgress` is slot 26.

**It arrives through the frame channel.** The object's slot 24 (`0x720540`) is `jmp [vftable+0x5C]`, i.e. slot 24 → slot
23, and slot 24 is SetFrame on C3dVisibleObject. **CIcon slot 18** (`0x6A23E0`) tail-calls its sprite object's (`+0x88`)
slot 24. So "set an icon's frame" is "set a bar's share". That fits the record's CDiplomacyView surrender bar, which
passes `100 − ceil(progress/10)` through icon slot 18. *confirmed*.

The rotation is the object's slot 34 (`0x720550`, writes `+0x150`). CIcon's slot 49 (`0x6A22D0`) passes it the icon's
`+0xEC`. That `+0xEC` is the `.gui` `rotation` is *inferred*.

## 6. Clicks

- `CProgressBarType::ContainsPoint` (slot 16): inside W × H from the origin, **strict at both ends**.
- `IsTransparentAt` (slot 18): `allwaystransparent` and nothing else, so a bar is see-through to clicks everywhere or
  nowhere.
- Slot 24 sets that flag.
- The object's slot 20 (`0x727EE0`) is a hit test that un-turns the point by `+0x150`; not read whole.

*confirmed* except slot 20.

## Not established

- **Who calls `CProgressBarObject::Render`, and how its matrix is made** from the icon's position and orientation; whether
  it carries a half-pixel offset. Two sweeps over VA `0xA50000..0xB60000` for a slot-10 call (direct and through a
  register) with six arguments or a `+0x94` matrix found nothing. That is a negative with no positive control, so it says
  only that the caller is not of that shape. This is why the upside-down reading is *likely* rather than *confirmed*.
- **The blend and alpha-test states** in force when a bar draws (the draw and the pass leave them to the interface).
- **What `0x660F30` returns for a file that fails to load**: -1, which would give `tec0`, or a valid index of a default
  picture.
- Whether an icon's `.gui` `frame` becomes a bar's starting share. CIcon slot 56 (`0x6A2870`) hands a new sprite object
  the icon's frame through slot 24 (the slot that reaches SetProgress); not followed.
- What the `+0x48` count and `norefcount` actually govern.
- `progressbar3dType` (token 337, constructor `0x70DF70`; it takes `tec0`, `CurrentState`, `vFirstColor` and
  `vSecondColor` at `0x70E200`) and `scrollingSprite`'s `ScrollTech` feed: neither was read.
- BlackICE's progress bars were not counted.

Frontier: 0x726E50, 0x727EE0, 0x6B2770, 0x660F30, 0x6610E0, 0x6611E0, 0x70DF70, 0x70E200, 0x71F7A0, 0x71F9A0, 0x71FC00,
0x4408E0, 0x6A2870, 0x6A29B0.
