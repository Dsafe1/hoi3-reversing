# A plain sprite: `buttonstate.fx` and `interpolated_buttonstate.fx`

*Read 2026-11-07, statically, by a delegated agent (fragment `interface-buttonstatefx.json`), for OpenHOI3,
which wants to draw every plain `spriteType` through the effect file it names, fed exactly as the original
feeds it. Functions are named by rva; instruction sites are VAs (rva + 0x400000). Only valid for this build
of `hoi3_tfh.exe`. Nothing here was checked in a running game; the constructor's default and the revised
`CSprite::UpdateStateName` were checked again off the bytes by the collecting session.*

**Corrections, rather than additions:**
- `0x706050` was recorded `CShieldObject::UpdateStateName`. It is **`CSprite`'s**: it is in CSprite's table
  (VA 0x1605020, slot 8), which `vtable.py` cannot see because CSprite has no RTTI table, and CShieldObject
  inherits it. Its comment's "what reads +8 was not read" is answered (section 3).
- `CCheckBox_ShowState`'s "slot 23, the frame setter" is `CSprite::SetState`. It picks the technique as well
  as the frame, so a ticked box is drawn with `down`, a tenth darker.
- `CSpriteType +0xA0` was "the rotation in radians". On a plain sprite it is **quarter turns**.
- `FINDINGS-maskedflag.md` section 1 says `CSpriteType`'s `+0x5C` "stays empty" on a masked shield. It holds
  the constructor's default, `gfx/FX/buttonstate.fx`, which the masked type never uses.
- The question as posed: **buttonstate.fx has `Color` too.** The two files differ only in their sampler
  (Point against Linear).

## In one line

Every sprite made from a `spriteType` is drawn through an effect file, buttonstate.fx unless the file names
another. The interface's renderer sets the technique **by name** from the drawn object's state (2 `down`,
3 `over`, 4 `disable`, anything else `up`). The sprite type's draw sets `WorldViewProjectionMatrix`, `tex0`,
`Color` and `vXOffset` and draws a four-vertex strip, half a pixel shifted.

## 1. The sprite type, its effect and its keys

`spriteType` is token 0x35. ObjectType_CreateByToken (`0x670550`) makes a 0x1A0-byte `CSpriteType` for it
(`CSpriteType::CSpriteType`, `0x6B7450`; table rva `0x12012F8`, no RTTI of its own). `tileSpriteType` (0x178)
is a subclass with its own table (VA 0x1605D00) and `maskedShieldType` another. `textSpriteType`,
`corneredTileSpriteType` and `progressbartype` are different classes (VA 0xB1B360, 0xB0EB80, 0xB26CA0) and
are not read here. `confirmed`.

- **The constructor sets `effectFile` (`+0x5C`) to `gfx/FX/buttonstate.fx`** (VA 0xAB75F1) before the file
  is read. `CSpriteType::LoadKey`'s token 0x59 case then overwrites it where the file names one. So **a sprite
  naming no effect file is drawn through buttonstate.fx**. `confirmed`.
- `CSpriteType::LoadResources` (`0x6B7B00`), read whole now: where `+0x5C` is empty (a file writing
  `effectFile = ""`) it becomes `gfx\FX\buttonstate.fx`. Then
  `FxHandler_Register(graphics +0x6BCFC, +0x5C, +0x5C, device)` is called, the string being both path and
  key. Sprites naming one text share one effect. The default's key `gfx/FX/buttonstate.fx` and a file's
  `gfx\\FX\\buttonstate.fx` are different keys, so they are two instances of the same file, which is harmless
  since every parameter is set per draw. The effect goes to `+0xD0` and to the type's `+0x24`.
  `GetParameterByName` is called for `tex0` (`+0xD4`) and `WorldViewProjectionMatrix` (`+0xD8`), and
  `GetTechniqueByName` for `up`, `over`, `down`, `disable` (`+0xDC..+0xE8`). **Those four handles are used by
  nothing read**: the technique is set by name (section 3). The type's technique name `+0x28` = `up`.
  **`Color` and `vXOffset` take no handle and are set by name every draw.** `confirmed`.
- The texture is loaded here only where `norefcount` (`+0x4C`, written by `CObjectType::LoadKey`) is set.
  Otherwise slots 11 and 12 (`0x6B8330`, `0x6B84E0`) load it on first use and free it on last, counting in
  `+0x48`. Either way `+0xA4`/`+0xA8` are **the file's own width and height** (the texture handler pads to a
  power of two). 1218 of the 1345 spriteTypes in TFH's interface say `norefcount = yes`. `confirmed`.
- The constructor also makes **`+0x120` = `D3DXMatrixOrthoRH(screen width, screen height, 0, 1)`**, once,
  at the screen size of that moment.

**Which sprites name which file** (`tfh/interface` over `interface`, by file name): `spriteType` 212
buttonstate.fx, 1 interpolated_buttonstate.fx (`GFX_empty_position`) and 1132 none, all drawn through
buttonstate.fx. `textSpriteType` 48 buttonstate.fx and 37 none (another class, not read).

## 2. The drawn object and its state

`CSpriteType::CreateInstance` (slot 23, `0x6B73E0`) makes a **`CSprite`**: 0x184 bytes, table VA 0x1605020,
no RTTI table (CShieldObject's RTTI names it as base). `CSprite::CSprite` (`0x705EB0`), `confirmed`:
- **`+4` = the type's effect and `+8` = `up`**; the type at `+0x150` and `+0x24`;
- state `+0x158` = 0, alpha `+0x180` = 1.0, rotation `+0x14C` = 0;
- from its bases (VA 0xAB2770, 0xA600E0): scale `+0xF8` = 1.0, **frame `+0x4E` = -1 (unset)**, and the
  CColor at `+0x30` white with its flag (`+0x48`, the colour's `+0x18`) set.

Its slots: 1 `SetAlpha` (`+0x180`); 23 `SetState` / 26 `GetState` (`+0x158`); 24/25 `SetFrame`/`GetFrame`
(`+0x4E`); 34 `SetRotation`; 39 `C2dObject::SetScale` (`+0xF8`); 68 SetColor (VA 0xA603D0: the CColor into
`+0x30`).

**Who sets which state** (all `confirmed` at the call):

| element | its state | sprite state, so technique |
| --- | --- | --- |
| `guiButtonType` widget (table VA 0x1607698), sprite at `+0x94` | `+0x64` 0 normal, 1 pressed, 2 hovered, 3 disabled (GuiButton_ShowState `0x741020` calls slots 70-73) | **1 `up`, 2 `down`, 3 `over`, 4 `disable`** (GuiButton_ShowUp/Down/Over/Disabled, `0x740CB0`, `0x740D30`, `0x740DB0`, `0x740F80`) |
| `iconType` (CIcon), sprite at `+0x88` | CIcon::SetState (`0x6A2410`, slot 45) s | s + 1 |
| `checkboxType`, sprite at `+0x64` | CCheckBox_ShowState (`0x681AA0`) | 1, 2, 3 by state; 4 when switched off |
| a Strategic Effects row (`0x2D1130`) | | 1 or 4, set on the icon's sprite directly |

Which mouse event gives a button state 2 (hovered) rests on `GuiButton_HandleMouse`'s record, read to its
gates: `inferred`.

## 3. The draw, frame by frame

**Collecting** (`CGraphics_DrawInterface`, `0x673240`, called by CInGameIdler_Render, CFrontEnd_Render and
two more):
1. `CGraphics_Begin2D` (`0x673040`).
2. `CGraphics_CollectObjects` (`0x673890`) walks the object tree from `graphics +0x6B9E0`, siblings by
   `+0xD8` and children by `+0xDC`. Each object's **world matrix (`+0x94`) = the parent's with its
   translation raised by the object's position (`+0x84`, `+0x88`), `_43 = -1.0`, `_44 = 1.0`**, the root
   being the identity.
3. For each visible object it **calls slot 8, `CSprite::UpdateStateName`**, which writes `+8` from the state
   (2 `down`, 3 `over`, 4 `disable`, else `up`), and appends the object to the draw list.

A parent precedes its children. `confirmed`.

**Batching** (`CGraphics_DrawObjectList`, `0x673390`), `confirmed`:
- effect = the object's `+4`, else its type's `+0x24`; technique = its `+8` string, or the type's `+0x28`
  where `+8` is empty.
- Unless both equal the open batch's: `EndPass`/`End` the old one, then **`SetTechnique(the name as a
  string)`, `Begin(&passes, 0)`, `BeginPass(0)`**. Only pass 0. Flags 0, so D3DX saves and restores the
  states the pass sets.
- An object with no effect is drawn with the WORLD transform at its `+0x94` instead.
- Where the object's byte `+0xF0` is set, SCISSORTESTENABLE with the graphics' rectangle `+0x6BCE0` is on
  around it.
- Then **slot 10** with (graphics, device, `&world`, slot 22's float). Slots 26 and 22 end in bare `ret`s,
  so the state and a nought they were pushed stay on the stack as Render's fifth and sixth arguments.

**`CSprite::Render`** (`0x7060D0`): rebuilds the type's quad where the rotation changed; copies the object's
alpha into type `+0x174` and its CColor into type `+0xB4`; calls **`CSpriteType::Draw`** (slot 26,
`0x6B77E0`) with world[15] = the object's scale, the state, texture 0 and the frame `+0x4E`; then puts 1.0
back in `+0x174`.

**`CSpriteType::Draw`**, inside the batch's pass, `confirmed`:
- **Column** = (state - 1) mod noOfFrames, unsigned (state 0 gives 0xFFFFFFFF mod frames). Then the frame
  overrides: **0 means column 0, n > 0 means column n - 1, negative (unset) leaves the state's column**. Never
  clamped.
- Where world[15] differs from `+0x110`, the quad is rebuilt at that scale. Then world[15] = 1.0.
- **`WorldViewProjectionMatrix` = world × `+0x120`** (OrthoRH).
- texture = the argument, else the type's `+0x168`. **With neither, nothing is drawn.** **`tex0`** = that.
- **`Color`** = (1, 1, 1, alpha) where the colour's flag is set, else the colour's r, g, b, a. A tint
  therefore replaces the object's alpha.
- **`vXOffset`** = column × `+0x164`.
- `CommitChanges`, then the quad: SetFVF 0x102 (XYZ|TEX1), a triangle strip of four.

**A positive control for `Color`:** `CCountrylistItem::UpdateResourceIcons` tints a resource icon
(1, 0.5, 0.5, 1) with the flag clear through the sprite's slot 68, and (1, 1, 1, 1) with it set.

## 4. The vertices

`CSpriteType::BuildQuad` (slot 27, `0x6B8540`); the buffer from slot 29 (`0x6B7750`: 4 vertices, stride
0x14, XYZ|TEX1, a strip). `confirmed`. W, H = the file's size; P(n) = the least power of two not below n;
F = noOfFrames; s = the scale. The four crop shorts L `+0xAC`, T `+0xAE`, B `+0xB0`, R `+0xB2` are 0 unless
CSprite slots 56/57 set them, which nothing read does:

- u0 = R / P(W); v0 = B / P(H); **u-step (`+0x164`) = ((W - L) / P(W) - u0) / F**; u1 = u0 + u-step;
  v1 = (H - T) / P(H).
- w = (W div F - L) · s; h = (H - B) · s; built only where h > 0, w >= 0 and W div F != R.

| | position (z = 1.0) | uv, rotation 0 or anything else | 1.0 | 2.0 | 3.0 |
| --- | --- | --- | --- | --- | --- |
| v0 | (-0.5, T - 0.5) | (u0, v1) | (u0, v0) | (u1, v0) | (u1, v1) |
| v1 | (-0.5, h - 0.5) | (u0, v0) | (u1, v0) | (u1, v1) | (u0, v1) |
| v2 | (w - 0.5, T - 0.5) | (u1, v1) | (u0, v1) | (u0, v0) | (u1, v0) |
| v3 | (w - 0.5, h - 0.5) | (u1, v0) | (u1, v1) | (u0, v1) | (u0, v0) |

Y is up, so v0 is the bottom left. The rotation is compared exactly with 0, 1, 2 and 3. 1 turns the picture a
quarter anticlockwise and 3 a quarter clockwise, both in an unchanged box. **No plain spriteType in TFH's
interface is given a `rotation`**: they are all on progress bars and shields.

**The −0.5 is Direct3D 9's half-pixel**: it puts texel centres on pixel centres. Placement: world z = 1.0 −
1.0 = 0, and clip x = 2X/width, y = 2Y/height. So positions are pixels from the screen's centre, y up, and the
quad's corner sits at the object's summed position. **This answers FINDINGS-maskedflag.md's question of how
z = 1.0 escapes clipping**: the world matrix's `_43` is −1.

## 5. The render states

- **The pass:** `ALPHABLENDENABLE = True`, the shaders, and `tex0`'s sampler_state: **buttonstate.fx Point,
  interpolated_buttonstate.fx Linear**, MipFilter None, Wrap both ways.
- **`CGraphics_Begin2D`:** ALPHABLENDENABLE 0 (until the pass), LIGHTING 0, ZENABLE 0, ZWRITEENABLE 0,
  sampler 0 POINT, VIEW identity, PROJECTION OrthoRH.
- **Baseline (`CGraphics_SetDefaultRenderStates`):** CULLMODE NONE, ALPHATESTENABLE 1 with ALPHAREF 8 and
  GREATEREQUAL, which **drops pixels under 8/255 alpha** (`inferred` for the moment of drawing: no census of
  ALPHATESTENABLE was made).
- **No sprite code sets SRCBLEND or DESTBLEND.** A census of the 27 immediate SetRenderState(SRCBLEND) sites
  finds none in the sprite types. The baseline is ONE/ZERO, but the map's passes, the shields and
  `CEU3BitmapFont::DrawText` set SRCALPHA/INVSRCALPHA. So a sprite blends **SRCALPHA/INVSRCALPHA**: `inferred`.

## 6. `interpolated_buttonstate.fx` and `GFX_empty_position`

**Nothing about `Color` is particular to this file.** Both files multiply `Color` into every technique and the
same draw feeds both. The one difference is **Linear filtering**: the "interpolation" is the texture's
(`inferred` from the files). `GFX_empty_position` (country_politics.gfx, `norefcount`,
`empty_position.tga` 36×50) is:
- the `iconType` of combat.gui's five `leader_photo`s, country_politics.gui's two `photo`s and
  country_espionage.gui's one;
- **the type a portrait is drawn through.** The leader window and others build a picture object over it,
  `PictureSprite_Construct` (`0x6BA9A0`, table VA 0x16015B0, no RTTI), with `gfx/pictures/portraits/` + a
  picture + `.tga` loaded as its own texture (+0x1A8). They hand it to the icon's slot 56.

`PictureSprite_Render` (`0x6BAC90`) calls the same Draw with that texture. **The quad and its UVs remain the
type's** (36×50 within 64×64), so a portrait is drawn into empty_position's box. Every portrait sampled is
36×50 (399 of 400). Its `Color` is (1, 1, 1, its alpha `+0x184`) or its tint, as for any sprite. Nothing that
changes either over time was found, and callers of SetAlpha were not looked for. `confirmed` except where
marked.

## Not established

- **How a widget fills an object's `+0x84`/`+0x88`** from the element's position and orientation, i.e. the
  conversion from the .gui's top-left-down pixels to the centred y-up space.
- **Who calls `CSprite::SetAlpha`** and SetColor (VA 0xA603D0) other than the resource icons, so whether
  anything fades a sprite.
- **A fresh icon's state** (`+0x64` at creation; slot 56 passes it to the sprite unshifted). Only a
  multi-frame sprite with neither state nor frame would show it: column 0xFFFFFFFF mod frames.
- **Whether a multi-frame button sprite's frame is ever set by code**, for most of them. TFH has 88
  guiButtonTypes with a multi-frame sprite and no `frame` (the map-mode buttons among them). Where nothing sets
  one, by the rule their column follows the state: up 0, down 1, over 2, disable 3, each mod frames. The
  landorders reading of the checkbox (frames 1-4) agrees. **The technology screen's folder tabs are settled**
  (the collecting session, 2026-11-07, on the maintainer's pointer to BlackICE's avionics tab):
  `GuiButton_SetFrame` (`0x741400`, the widget's slot 18) stores the frame at `+0x138` and calls the sprite's
  slot 24, SetFrame, and the technology view's update calls it on every `techtree_` button, 2 for the chosen
  folder and 1 for the rest (VA 0x81B2A0-0x81B2B1, `FINDINGS-countryviews.md` section 5). A set frame
  overrides the state's column, so a tab keeps its picture under the mouse and when pressed. `confirmed`.
- `textSpriteType` (48 name buttonstate.fx), `corneredTileSpriteType`, and `tileSpriteType`'s own LoadKey,
  LoadResources and BuildQuad (VA 0xB16D40, 0xB16D30, 0xB16D70). It inherits Draw and the constructor's
  default.
- The pass after the interface (VA 0xA73630); the setters of the crop shorts and of `+0xF0`; the float
  `+0x154` passed to Draw and never read.
- The other object class with the same state names (table VA 0x1600F58, slot 8 VA 0xAB5B20).
- The blend and alpha-test states at the moment the interface draws, which were not measured.

Frontier: 0x660F30, 0x6610E0, 0x6603D0, 0x6600E0, 0x6B2770, 0x673630, 0x6B5A60, 0x6B5B20, 0x716D30, 0x716D40,
0x716D70, 0x71B360, 0x70EB80, 0x6A2870, 0x740980, 0x6A2250, 0x7062F0, 0x706390, 0x7063D0, 0x706270, 0x7061E0.
