# A sprite's `transparencecheck`: where a click goes through a picture

*Read 2026-11-03, statically, for OpenHOI3: the top bar's speed indicator lies over the left ten pixels of the
speed-up button, and the rewrite gave every click there to the indicator. Every address below is an rva of this
build of `hoi3_tfh.exe`.*

## In one line

`transparencecheck = yes` on a `spriteType` makes the sprite **see-through wherever the pixel of the frame asked
about has an alpha of nought**; without it the sprite is see-through nowhere, and `allwaystransparent = yes` makes it
see-through everywhere. The texture must be uncompressed or DXT3: a DXT1 or DXT5 texture is refused with an error as
it is loaded and the flag cleared.

## 1. The keys - `CSpriteType::LoadKey` (`0x6B7A00`)

`ret 8`, a switch over the save token. Its cases, the token names out of `ghidra/saveTokens.json`:

| token | key | where it goes |
| --- | --- | --- |
| 0x1B | `noOfFrames` | `+0x94`, through a `sscanf` of the parser's current text |
| 0x24 | `textureFile` | `+0x78`, a `Hoi3CString`, through the string reader 0x67AFB0 |
| 0x41 | `defaultAnimationTime` | `+0x9C`, through 0x67B640 |
| 0x59 | `effectFile` | `+0x5C`, a `Hoi3CString` |
| 0x13A | `transparencecheck` | the bool `+0x170` through 0x67B410, **and `+0x171` set to 1** |
| 0x143 | `clicksound` | `+0x17C`, a `Hoi3CString` |
| 0x166 | `allwaystransparent` | the bool `+0x178` through 0x67B410 |

Anything else goes to the base's loader, 0x6F9640 (recorded as `CProvinceType::LoadKey`, whose one key is
`norefcount`). The table this is slot 4 of is at rva 0x12012F8, which the RTTI export does not name; it is
`CSpriteType`'s by elimination - `CMaskedSpriteType`'s table (0x11E1D44) is the same in every slot but its own
overrides, and its `LoadKey` (0x44C030) forwards its default case here.

## 2. The default - `CSpriteType::SetTransparenceCheckDefault` (`0x6B8310`)

Slot 22, `ret 4`, five instructions: where `+0x171` is nought - the file did not give the key - the bool argument is
written to `+0x170`. So a caller can switch the check on or off for a sprite type whose file is silent, and the file's
word wins over it. **Who calls it was not read** - it is called only through the table, and no caller was found.

## 3. The refusal - in slot 6 (`0x6B7B00`), the one that loads the texture

Slot 6 builds the sprite's resources out of `+0x5C` and `+0x78`. Only its middle was read: having loaded the texture
it asks its level description (`IDirect3DTexture9` slot 17), and **where the format is `DXT1` or `DXT5` and `+0x170`
is set it logs `Texture <file> have forbidden compression, have you tried DXT3?` under `spritetype.cpp`, line 0x116,
and clears `+0x170`.** So a sprite whose texture is either of those is tested nowhere, as though it had no key.

## 4. The test - `CSpriteType::IsTransparentAt` (`0x6B80E0`)

Slot 18, `ret 8`: a pointer to two `short`s, x and y, and a 16-bit frame. Answers a bool, **true for see-through**:

1. `allwaystransparent` (`+0x178`) set - true.
2. no texture (`+0x168` nought) - true.
3. `transparencecheck` (`+0x170`) clear - **false**.
4. The frame: nought is taken as 1, and one above `noOfFrames` (`+0x94`) as `noOfFrames`.
5. The top level of the texture is locked (`LockRect`, slot 19, read-only) and its format asked (slot 17):
   - **DXT3**: the 4-bit explicit alpha of the pixel, read out of its 4 by 4 block - the block's row from
     `frame * width / noOfFrames` and `y / 4`, its column from `x / 4`, the nibble from `x % 4 + 4 * (y % 4)`. The
     frame here scales the row, not the column, so for a sheet of more than one frame the block reached is not the
     frame's own: kept as read.
   - **DXT1 or DXT5**: false, and the texture is left locked - the jump skips the unlock. Unreachable after section 3.
   - **anything else**, taken as four bytes a pixel: the byte at `bits + y * pitch + 4 * ((frame - 1) * W / noOfFrames
     + x) + 3`, the alpha of an `A8R8G8B8` pixel, where `W` is `+0xA4` - the texture's width, *inferred* from the
     arithmetic.
6. Unlock; **true where that alpha is nought**, false otherwise.

So the point is in the texture's own pixels, measured from the frame's corner.

## What is not established

- **Who asks it.** The test is called only through the table, and the 1,512 calls through slot 18 in the image were
  not sorted to find which are on a sprite type. So that a click on a button goes to what lies under it where the test
  answers true - the reason it exists - is *inferred*, from the key's name, the refusal's wording and the art: the top
  bar's `GFX_speed_indicator` has the key and is drawn only in columns 4 to 13 of each 32-wide frame, the part that
  overlaps the speed-up button is empty, and the speed-up button can be pressed there. Which frame the caller passes,
  and how it turns a point of the screen into one of the texture, were not read either.
- **What `allwaystransparent` on a sprite does for a button.** The test answers true for it, but with the caller
  unread it is not known whether a button drawn with such a sprite can be pressed at all - `province_interface.gui`'s
  `occupier_flag` is one.
- Slot 6 was read only across the refusal.
