# Where a text box puts its text

Read statically off `hoi3_tfh.exe` on 2026-10-08, for the rewrite
(`OpenHOI3/docs/mechanics/interface.md`, section 6), after the maintainer twice pointed at
a figure the rewrite drew off-centre in a circle the art paints for it. Addresses are
**virtual** (image base `0x400000`) with the rva beside anything the record needs.
Listings are in the session scratchpad (`factbase/screens/font_draw*.txt`,
`txt_ctor*.txt`, `itb_ctor*.txt`).

This time there is something to check against: a screenshot of the running game the
maintainer sent, with the figure and the year beside it in the panel for one technology,
measured to the pixel against the circle in `bg_selected_tech.dds`.

## In one line

A text box does not place its own text: it hands the string, its box, its border, its
format and its orientation to **the font's slot 8**, which lays the lines out and places
them - set left at the border, **centred in the whole box from the border** with each
half cut to a whole number, set right against the box's right edge **with no border at
all** - and then draws every glyph with **half a pixel added to both coordinates** of
every corner, which beside the game's pictures is one pixel right and one up; and the
colours of the `§` escapes are not in the executable but in each font's own
`colorcodes` block.

---

## 1. The chain

`instantTextBoxType` widgets (vftable `0x15FDB70`, no RTTI) are built by `0xA7F930` (rva
`0x67F930`, `ret 0x38`). It keeps its `maxWidth` at `+0x8C`, its format at `+0xF0`, and
at `+0x94` an object of `0x1D4` bytes that does the work, built by `0xB32350` (rva
`0x732350`, `ret 0x30`), vftable `0x1606C70`, also without RTTI. Called `CGuiText` here;
the name is ours.

`CGuiText` keeps what the declaration gave:

| offset | what |
| --- | --- |
| `+0x150` | the text, a `std::string` |
| `+0x16C` | a colour block handed to the font's slot 15 before each draw |
| `+0x188`, `+0x18C` | position x and y |
| `+0x198`, `+0x19C` | `borderSize` x and y |
| `+0x1A0`, `+0x1A4` | `maxWidth` and `maxHeight`; each becomes 200 if it was 0 (`0xB325AB`) |
| `+0x1A8` | orientation, 0 to 6 as `ParseGuiOrientation` gives it |
| `+0x1AC` | format: **0 left, 1 right, 2 centre** |
| `+0x1B0`, `+0x1B4` | the size of the area positions are measured in; the font fills it |
| `+0x1B8` | `fixedsize` (inferred): when set and there is text, the constructor has the font cut it to the box (slot 12, section 2.4) - *corrected 2026-11-14*: this said "re-flow" |
| `+0x1BC` | the font |

Its draw routine is `0xB326C0` (rva `0x7326C0`, `ret 0x18`): font slot 15 with the
colour block, then **font slot 8** with, in order, the text, the format, the orientation,
a rectangle `{x, y, maxWidth, maxHeight}` by value, border x, border y, and a pointer to
the area size.

*Added 2026-11-14 by the `linebreak` agent; the collecting session checked the cut's place off the listing:*

- `findRefs --callers 0xB32350` gives two callers: the instant box's constructor (`0xA7FABF`) and `GuiButton_Construct`
  (`0xB3FDC5`, kept at the button's `+0x94`). **So a button's caption is drawn by slot 8 too.**
- `CGuiText`'s constructor tests `+0x1B8` at `0xB32528` and, with text, calls font slot 12 (`[vftable+0x30]`,
  `0xB32580`) with maxWidth and maxHeight **as given**; only then (`0xB325AB`..`0xB325C8`) are zeros made 200. All 1320
  instant boxes in the base game and Their Finest Hour have both a width and a height.
- **A `textBoxType` does not use `CGuiText`.** Its constructor (`0xA87770`) makes a display object through the graphics
  (`0xA6FFB0`): a template found by the box's name in a hash at graphics `+0xA0`, built where missing (0x144 bytes,
  constructor `0xB266E0`, vftable `0x1606708`), whose slot 23 builds a 0x310-byte object (`0xAB4AA0`, vftable
  `0x1600F58`, no RTTI) - called `CTextSprite` here - kept at the box's `+0x4C`. `SetText` calls its slot 61 (`0xAB59B0`,
  `ret 0x24`, nine arguments), which calls slot 60 (`0xAB5190`, `ret 0x28`); `SetTextToFit` calls slot 60 directly with
  height 0. Slot 60 cuts with font slot 12 where fixedsize is set and the height is not 0; where fixedsize is set, a
  dimension is 0 and there is a background, that dimension becomes the background's less the border; then **font slot 6**
  renders into the texture (section 2.2).
- `+0xC8` is fixedsize because it is the constructor's only byte argument, and the factory `0xB31BE0` pushes the type's
  `+0xD4`, where the loader puts `fixedsize`.
- `CTextBoxType`'s loader (`0xB31DC0`), key to offset: font `0x1D` -> `+0x88`, textureFile `0x24` -> `+0x6C`, position
  `0x4B` -> `+0xCC`, format `0x71` -> `+0xF8` (left 0, right 1, centre 2), borderSize `0x83` -> `+0x64`, text `0x8C` ->
  `+0xA4` (localised at once), maxHeight `0x8D` -> `+0xC4`, maxWidth `0x8E` -> `+0xC0`, fixedsize `0xAD` -> `+0xD4`,
  orientation `0xBF` -> `+0xDC`, textblock 300.

*Added 2026-11-14 by the `textrest` agent: the box a button's caption is given (the branch on the sprite checked off the
listing by the collecting session - one byte, `[ebp+0xD3]`, chooses the `CGuiText` route at `0xB3FDC5`).*

`GuiButton_Construct` (`0xB3FA50`) makes its caption one of two ways, and a third case makes none
(`0xB3FC5C`..`0xB3FF6E`). *Corrected*: the bullet above said "a button's caption is drawn by slot 8 too" - true only of a
button with no sprite.

- **The button names no sprite** - `spriteType` and `quadTextureSprite` both land at the type's `+0x104`
  (`GuiType_guiButtonType::LoadKey`, `0xB2CE40`) - and its `buttonText` and `buttonFont` are both set: a `CGuiText` at
  `+0x94`, with the button's position and orientation, the parent's size, **maxWidth and maxHeight the button type's
  `size`** (`+0x280`/`+0x284`, so 200 each where the file gives none), **a border of nought**, the type's `format`
  (`+0x288`; `left` 0, `right` 1, `centre` 2), not of fixed size. Drawn by slot 8 - an `instantTextBoxType`'s rule. In
  the base game and Their Finest Hour only two buttons are so, `bg_button` and `messagelogbutton`, both with blank text.
- **It names a sprite** and text and font are set: the graphics' `0xA6FFB0` - the call a `textBoxType` makes its
  display object with - makes a display object from **the sprite's template**, with the text, the font, textureFile
  `""`, **width 0, height 0, format 2 (centre), fixedsize 1** and the type's `borderSize` (`+0x294`). On a
  `textSpriteType` that object is a `CTextSprite`, so the caption is a `textBoxType`'s text: `CTextSprite::RenderText`
  takes the empty textureFile as the template's own picture, makes the width and height **the picture's less the border
  once**, cuts the text with slot 12 (the height is not nought), and slot 6 breaks it (section 2.2), centres each line in
  the width with no border and centres the lines up and down (a background is present), and shows the picture less the
  border. A plain `spriteType`'s template makes no text object, so its caption is never drawn.
- Text or font empty: the display object is made from the sprite alone.

Of 329 `guiButtonType`s with both a text and a font in the base game and Their Finest Hour, 299 are on a text sprite, 27
on a plain sprite, 2 have none, 1 names a sprite no `.gfx` declares. **No button gives a `borderSize`**, though the
grammar takes one, and no text sprite has more than one frame.

The button type's grammar (`0xB2CE40`, slot 4 of the no-RTTI table `0x1606AD0` that `guiButtonType` and `checkboxType`
share): `borderSize` `+0x294`; `upSprite`, `downSprite`, `dissableSprite`, `overSprite`; `spriteType` and
`quadTextureSprite` `+0x104`; `position` `+0x254`; `scale` `+0x290`; `parent`; `tooltip` `+0x120`; `tooltipText`;
`delayedTooltipText`; `buttonText` `+0x200`; `buttonFont` and `origo` `+0xB0`; `orientation`; `size` `+0x280`; `format`
`+0x288`; `oversound` `+0x158`; `clicksound` `+0x174`; `downsound` `+0x190`; `upsound` `+0x1AC`; `shortcut` `+0x1E4`;
`luaClick` `+0x1C8`; `rotation` `+0x28C`; the rest to `CGuiType::LoadKey`.

## 2. `CEU3BitmapFont` slot 8, `0xAFC070` (rva `0x6FC070`)

`ret 0x28`: ten dwords of arguments. It is 0x1674 bytes: a cache of forty laid-out texts
keyed by a hash of the string and all the arguments, a loop that measures and breaks
lines, a switch that places the first line, and a loop that emits glyph quads.

**A line's width is the sum of its glyphs' `xadvance`**, plus kerning: `add [esp+0x10],
edx` with `edx = [glyph+0x18]` at `0xAFC61C`. The escape `§` and the letter after it add
nothing.

**The placement switch** is at `0xAFCAA5`, a jump table on the orientation. Coordinates
are in a space centred on the middle of the area, x to the right and **y upwards**:
`x - areaWidth/2`, `areaHeight/2 - y`. For orientation 0, `UPPER_LEFT`, at `0xAFCAAC`:

    lineY = areaHeight/2 - y - borderY
    x0    = x - areaWidth/2
    left   (format 0):  x0 + borderX
    centre (format 2):  x0 + borderX + maxWidth/2 - lineWidth/2
    right  (format 1):  x0 + maxWidth - lineWidth

Every `/2` is its own integer division, cut towards nought (`cdq; sub eax,edx; sar
eax,1`), so a line 31 wide in a box of 60 starts 15 in, not 14.5. **Set right, the border
is not used.**

For orientation 1, `UPPER_RIGHT`, at `0xAFCB1C`, `x0 = areaWidth/2 + x + borderX` - the
border is in the origin - and then the same three, so left and centre have the border
twice and right has it once. Orientations 2 and 3 (`0xAFCBA5`, `0xAFCBED`) place left
and centre and treat right as left. **CENTER, 4 (`0xAFCC16`, read 2026-11-08)**: x is from the middle of the area and `lineY = -(y + borderY)`; left and right both start at `x + borderX`, and
centre at `x + borderX - widest/2 + maxWidth/2 - lineWidth/2`, `widest` being the block's widest line (the register the switch inherits, `cmovg` at `0xAFCA3B`). So **a single line ends at the middle of
the box and is not centred in it**: "0 of 15 Victory Conditions" in `backend.gui` falls inside its column by this and off it otherwise. 5, CENTER_UP (`0xAFCC77`), has terms of its own not worked through. Of the 1118 text boxes in the base game and Their
Finest Hour, 1077 are `UPPER_LEFT`.

**Every corner of every glyph has half a pixel added to x and to y.** In the quad loop
`xmm7` holds `-0.5` (`movsd xmm7,[0x160a350]` at `0xAFCD95`) and each coordinate is
`subsd`-ed by it: left `pen + xoffset + 0.5` (`0xAFD200`), right, top `lineY - yoffset +
0.5` (`0xAFD215`), bottom. In a space with y upwards that is half a pixel right and half
a pixel **up**.

### 2.1 The line breaking (read 2026-11-14, from a full decompile of `0xAFC070`)

The limit is `maxWidth`, or `0x140` (320) where it is 0. **`maxHeight` takes part only in the cache's hash**: a text is
never cut to its box's height.

- **At a space** - a glyph of no height - the line and the word with its space, plus `2 * borderX`, are set against the
  limit (`0xAFC693`..`0xAFC6AB`). Wider: a `\n` goes before the word, the broken line keeps its trailing space in its
  width (`L - w`), and the new line starts at `L = w`. Otherwise the word is appended.
- **A long word**: at a visible glyph, with output already made, the limit `<= 2 * borderX + L` and the word over 50
  wide, the word is broken there (`0xAFC78C`..`0xAFC7AC`).
- **`\n` or `\r`** ends a line with no test.
- **After 55 lines** (`cmp 0x37` at `0xAFC714`) the rest of the text is dropped.
- **At the end of the text**: where the limit `<` w, the word is appended with no break and the line's width becomes w;
  else where the limit `<` `L + 2 * borderX`, a break; otherwise appended.
- **Drawing**: the loop at `0xAFD0ED`..`0xAFD144` steps each line down by `+0x494`, and each centred line is placed at
  `border + maxWidth/2 - its own width/2` (`x0 + borderX` stored at `0xAFCB0E`).

Two consequences: a first word wider than the box, followed by a space, leaves the first line empty; and a word broken by
the long-word rule is tested again at the end from where it was broken.

The rule is the instant box's and a button caption's (section 1). It stops at **55 lines** like slot 6 below.

### 2.2 Slot 6, `0xAFA610` (rva `0x6FA610`): a `textBoxType`'s breaking (read 2026-11-14)

`ret 0x30`: twelve stack arguments, ten seen read. maxWidth 0 becomes 320; otherwise a maxHeight not 0 sets `fit`. The
text is read a character at a time; L is the line's width and w the word's, and each character is appended to the word
first.

- Where the font's slot 19 (byte `+8`, the escape switch) is true, these are pictures, added to L only, not to w: `§` and
  1 character, 0 wide; `@` and 3, the flag's width; `{` and 2, 8 wide; `£` and a name, the counter's width; `¤`, 16 wide.
- Then, for every character, before a plain glyph is counted: where `limit <= L + 2 * borderX` (`0xAFAC06`), `\n` and the
  word gathered so far go out; the broken line is stored as `L - n - w`, n being the picture's width or -1 for a plain
  character; L becomes `n + w` and w is kept (`0xAFAC4C`..`0xAFAC63`). So a plain word goes down at the character where
  the line reaches the box - no floor of 50 and no "something already laid out" test. After such a break L is one short,
  and w is never reset there, so **a word wider than the box goes on one character a line**.
- `\n` or `\r`: where `L + 2b < limit`, the word goes out and w = 0; otherwise `\n` and the word go out and w is kept (the
  `jmp` at `0xAFAE5C` skips `0xAFAEA2`). Either way L = 0. Other characters with no glyph are skipped.
- A glyph adds its `xadvance` and the kerning with the next byte to L and to w.
- At a space (a glyph of no height): the word goes out where the result is still empty (`[esp+0x60]`) or `L + 2b <
  limit`; otherwise `\n` and the word, with L = w. Then w = 0 (`0xAFADAC`).
- At the end: where `L + 2b < limit` the word goes out, otherwise `\n` and the word. The word alone is never tested.
- The newline and space breaks count lines, and the loop stops at 55 (`cmp 0x37; cmovge`, four places).
- **Placement**: section 2.2.1.

#### 2.2.1 Where slot 6 places the lines, and how much of its picture is shown (read 2026-11-14, the `textplace` agent)

Read off the listing of `0xAFA610` from the end of the breaking loop (`0xAFAEC3`) to the glyph loop (`0xAFB584`), the
newline arm of that loop (`0xAFB99C`..`0xAFBA2C`), `CTextSprite::RenderText` (`0xAB5190`) around its call of slot 6
(`0xAB57CB`..`0xAB5934`), and the routine it ends in, `0xAB61F0`, which makes the quad the picture is drawn with.

**`fit` is an argument, and it is the box's `fixedsize`** - *corrected*: this said only that a maxHeight not 0 sets it.
RenderText pushes, last to first: `!fixedsize`, `1`, fixedsize (`[ebp+0x2c]`), the format, the border, the height, the
width, the background, the text, the size, the texture size and the texture (`0xAB58BB`..`0xAB58FC`). Slot 6 then sets
the byte to 1 where the width and the height are both given (`0xAFA6B4`), and makes a width of 0 into 320 leaving it as
it came (`0xAFA6BA`). So:

    fit = fixedsize || (maxWidth != 0 && maxHeight != 0)

and a box of fixed size with no width is laid out at 320 *and* fits. (The arm RenderText takes where its `+0x20C` - the
template's `+0x94`, a count of frames - is above 1 passes `fit = 1` and a quarter of the width; no box of the base game
was seen to take it.) The last two arguments, `1` and `!fixedsize`, are still not seen read.

**The size of the picture** (`0xAFAF55`..`0xAFAFFA`), with n lines and h the font's line height (`+0x494`):

    W = fit ? maxWidth (320 where it was 0) : widest + 2 * borderX
    H = fit && maxHeight != 0 ? maxHeight : n * h + 2 * borderY
    texture = the next power of two at least W, and at least H

**What is shown of it**, written through slot 6's third argument and kept by RenderText at `+0x1FC`/`+0x200` (the
texture's own size at `+0x204`/`+0x208`, `0xAB5914`..`0xAB592E`):

    shown = fit ? (W - borderX,  maxHeight != 0 ? maxHeight - borderY : H)
                : (W, H)

`0xAB61F0` (this in EDI) makes the four corners from the shown size: across from c to (shown width / frames) - a - 1,
up from b to shown height - d - 1, with texture coordinates from c / texture width to (shown width - a) / texture width
and from d / texture height to (shown height - b) / texture height - a, b, c and d being four words at
`+0x17A`..`+0x180` that only the object's slots 56 and 57 write (`0xAB5A90`, `0xAB5AC0`) and that are nought for a box
nobody crops (inferred; who calls the two was not followed). **So only the shown part of the picture reaches the screen:
a `textBoxType`'s lines past its `maxHeight` less its `borderSize` y are cut off, and so is anything right of its
`maxWidth` less its `borderSize` x.** The quad spans one unit less than the texels it shows, each way; whether pictures
do the same was not read.

**The lines** (`0xAFB4D2`..`0xAFB55F` for the first, `0xAFB99C`..`0xAFBA2C` at each newline): in the texture's space,
y upwards from its bottom,

    top = texture height - borderY                      ; borderY down from the picture's top
    where fit and there is a background:
        top = texture height - (H - n * h) / 2          ; cut towards nought: cdq; sub; sar 1
    x   = fit && format 2 (centre) : W / 2 - width / 2  ; each half cut towards nought, no border
          fit && format 1 (right)  : W - borderX - 1 - width
          otherwise                : borderX            ; without fit, every format
    each later line: top -= h, x by the same rule with that line's stored width

So the centring up and down is **(H - text height) / 2 from the picture's top, with no border in it**, and only where
the box fits. "A background" is the box's `textureFile` - RenderText resolves it against the graphics' texture table into
`+0x1A0` (an empty name taking the template's own, `+0x150 +0x74`), and slot 6 tests that pointer (`[ebp+0x18]`). A
glyph's corners are then placed as slot 8 places them: `x + xoffset + 0.5`, `top - yoffset + 0.5` (`movsd
xmm0,[0x160A350]` = -0.5, subtracted). There is no orientation in any of it: the box's orientation places the picture,
not the text in it.

**`h` is the descriptor's `lineHeight`** (read 2026-11-14, the `editline` agent). `+0x494` is written by
`CEU3BitmapFont::LoadGlyphs` (`0xAF9FD0`), which reads the `.fnt` positionally: one token (`info`), nine key-value
pairs (`face` to `padding`'s first number), six tokens (`padding`'s other three numbers and their commas), one pair
(`spacing`'s first), three tokens (`,`, its second number, `common`) - and then `atoi` of the next pair's value into
`+0x494` and of the one after into `+0x498`. That lands on `lineHeight` and `base` only if a comma is a token of its own,
which is what the counts of six and three need; for `Arial12_bold` the two are 14 and 11. So the centring's text height
is lines times `lineHeight` - 14 for `game_name`'s one line, and (32 - 14) / 2 = 9 as written above. *Not checked*: a
descriptor whose `info` line carries another number of pairs, which would shift both.

**The background is drawn into the same picture, under the text** - section 2.2.2.

Base game and Their Finest Hour, layered: of 341 `textBoxType`s, 18 do not fit (16 in `metaserver.gui`, two in
`settings.gui`, among them `MustRestartTextBox`, centred, which therefore starts at its border); four have a picture and
fit - `console_text`, `ChatMemberText`, `ToolTip` and `FPS_Counter` - and the tooltip is filled through `SetTextToFit`
with no height, so it does not fit and its picture does not centre it.

#### 2.2.2 The picture behind the text, `0xAFDAC0` (rva `0x6FDAC0`) (read 2026-11-14, the `textrest` agent)

Decompiled whole; *corrects* the "likely nine parts" of before. `__cdecl`, five arguments, pushed by slot 6 at
`0xAFB37C`..`0xAFB388`: the device; **the box's border** `{x, y}` (slot 6's `[ebp+0x24]`); **the render texture's size**
(only its height is read); **the shown size** slot 6 has just written through its third argument (section 2.2.1); and
**what that argument held when slot 6 was called**, which `CTextSprite::RenderText` fills with the background's own size
(`+0x1A4`/`+0x1A8`, the texture table entry's `+0x17C`/`+0x180`; `0xAB56F3`..`0xAB56FD`).

It is drawn after `SetSamplerState` sets MINFILTER and MAGFILTER to **point** (`0xAFB14A`..`0xAFB16E`), into a target
cleared to `0x00FFFF99`, alpha blending off (`SetRenderState(0x1B, 0)` at `0xAFB36E`), in an orthographic space `0..texture
width` by `0..texture height` with y up (`D3DXMatrixOrthoOffCenter` at `0xAFB319`). With bx, by the border, Sw, Sh the
shown size, T the texture's height and Pw, Ph the picture's size:

    W = Sw - (bx != 0 ? 2 : 0)                 ; the 2.0 at 0x160A360
    H = Sh - (by != 0 ? 2 : 0)
    across:  0,  bx,  W - bx,  W
    down:    T,  T - by,  T - H + by,  T - H   ; y up: the picture's top is the texture's
    u:       0,  bx,  Pw - bx,  Pw             ; each over the next power of two at least Pw
    v:       0,  by,  Ph - by,  Ph             ; the same with Ph

and every position less 0.5 (`0x160A308`; `subsd 0.5` at `0xAFE51E`/`0xAFE539`), which under Direct3D 9 puts each texel
on a pixel. Sixteen points, nine quads, 18 triangles (`DrawPrimitive(D3DPT_TRIANGLELIST, 0, 0x12)` at `0xAFB3C3`; the
first `p10, p00, p11` and `p11, p00, p01`, and so on over the grid). So **the picture covers the upper left W by H of
what the box shows**: its four corners are the border's size in the picture and on the screen, its edges are stretched
along their length and its middle both ways - **stretched, not repeated** - and it ends **two pixels short of the shown
part's right edge where the border across is not nought, and two short of its bottom where the border down is not**.

That is exactly the edit box OpenHOI3 measured on the maintainer's screenshot of the save dialog (OpenHOI3's
`interface.md`, section 8): `game_name`, 260 by 32 with a border of 8 by 6, is handed to its display object whole
(`EditBox_RefreshText`, `0xA90140`: the size, the border, format 0, fixedsize 0, so it fits), which
`GuiObject_editBoxType::PlaceAt` puts the border in; it shows 252 by 26, and the picture is 250 by 24 at 8, 6 - its rim,
the picture having two clear all round, 246 by 20 at 10, 8, as measured. **So an edit box draws its line and its picture
through the same `CTextSprite` and slot 6 as a `textBoxType`.**

**An edit box with no `textureFile` has no picture behind its line** (read 2026-11-14). The display object is made from
a template found by the element's name in the graphics' `+0xA0` hash, built where none is (`0xA6FFB0`); the one built
(`TextSpriteTemplate_Construct`, `0xB266E0`, `__stdcall`, `ret 0x2C`) leaves its own texture name, `+0x74`, empty.
`RenderText`, given an empty `textureFile`, takes the template's `+0x74` instead (`0xAB538A`), finds it empty too and
makes no lookup in the texture table (the `sete` at `0xAB5486` gates the call of `0xA60F30`), so the background
(`+0x1A0`) stays null - and slot 6 places the line at the border, not centred. The unit panel's `unitname` (235 by 24,
border 8 by 4, `Arial12_bold`, no `textureFile`) is such a box; the save dialog's `game_name` names
`small_tiles_dialog.dds` and is centred. No `.gfx` of the base game declares a sprite of either name.

With the shown size of a box that does not fit (section 2.2.1) the tooltip's picture is its lines and the border round
them, less two each way. Of the base game's four `textBoxType`s with a picture, two name `transparency.dds`, which is
clear; the tooltip and `FPS_Counter` name `tiles_dialog.dds`.

**A text sprite of more than one frame** (`RenderText`'s other arm, `0xAB5701`..`0xAB57C6`) is laid out at `(int)(picture
width * 0.25)` - a quarter whatever the count - by the picture's height, fit, with no cut, and slot 6 is handed the frame
count and 0 as its last two arguments; the shown width kept is that times the frames. So slot 6's eleventh argument is
likely the frame count (`inferred`, from this arm alone; the general arm passes 1). No text sprite of the base game or of
BlackICE has more than one frame.

### 2.3 `CTextLayout::BuildLines`, `0xACCB10` (rva `0x6CCB10`) (read 2026-11-14)

O = slot 18 = `GetStringWidth("O", 1)` (the string at `0x16049D4`). Where the width up to the first newline, plus O, is
over the area: if the text has a space and the width up to the first space plus O is within the area, it is cut at the
**last space before n** (`0xACE240`) and the space dropped (`0xACE150`); otherwise after n characters (`0xACE090`) - n
being **the fewest characters at least `area - O` wide** (`0xACC960`, a binary search). Otherwise the line is taken with
its newline. *Corrected*: the record had "at the last space that fits", `inferred`.

Its users and their area: a **tooltip**, `maxWidth - 3 * border` = 352, then `SetTextToFit`, whose limit of 368 never
breaks again; the **message log**, the button's width less 10 and a height of 2000, the result split at `\n`; the
**diplomacy status list**, the row text box's maxWidth (`[edi+0x8c]` beside `mov ecx,0x7d0` at `0x78A484`); the
**technology effects**; the **edit box**; the **lobby's chat**.

**The lobby's chat** (`CGameSetup::AddChatLine`, `0x30D3E0`, read 2026-11-14 by the `textrest` agent): a probe row
`lobby_chat_text` finds its `messagelogtext` and that box's font; the layout's area is the box's width less 10 by 2000
(`0x70D6CF`..`0x70D6DF`) - the width through `GuiObject_instantTextBoxType::GetSize` (slot 47), which is
`CGuiText::GetSize`, the text as laid out by font slot 13 and **raised to maxWidth**, so with the probe's empty text 750
in `temp_frontend.gui` and an area of 740 - the line's text set, the laid-out text split at `\n`, and a row made for each
piece; past the lobby's limit (a short at `+0x3BC +0x4C`) the first row is taken off. So the chat is laid out as the
message log is.

**The edit box**, followed the same day: `EditBox_RefreshText` hands its display object the caret's laid-out line with
the box's whole size, its border, format 0 and fixedsize 0 (section 2.2.2). A line the layout gives is narrower than the
size less twice the border less an `O`, so slot 6 never breaks it again. A text set by code (`CTextLayout::SetText`)
leaves the caret at its end, so the box shows the last laid-out line.

Not followed: the calls in the lobby's constructor and `OnBack`, the province view, the statistics ledger and
`CreateIcon`.

### 2.4 Slot 12, `0xB003E0` (rva `0x7003E0`): the fixedsize cut (read 2026-11-14)

`ret 0x14`. maxWidth 0 becomes 320. The room across is `maxWidth - 2 * border[0]`, the room down `maxHeight - 2 *
border[0]` - **the border's y is never read**. Lines are counted a character at a time, from one: `§` skips the next
character; `{` adds 8 and skips **three** more, one past the two digits; `@` adds the flag's width and skips three; `£`
adds the counter's width over its name. Where the line's width reaches the room across, a line is added and the line
count is set to the second count, which is then zeroed - the two being equal then, **the next character adds a line
too**. `\n` and `\r` add a line and zero both counts. Where the lines counted are more than the room down: out =
`text[0..i]` with its last four characters set to `' ', '.', '.', '.'` - at a newline only where out is at least 5 long,
at a full line only where i > 3, else `"..."` (from `0x15B5C6C`, the construction not read). **The cut runs before the
breaking.**

## 3. What that comes to on screen

`measured`, on the maintainer's screenshot of the running game. In the panel for one
technology the difficulty is a box at 811, 104 with `maxWidth = 24`, `borderSize = { 4 2
}`, centred, in `Arial12_bold`, whose `1` is `xoffset=0 yoffset=3 width=4 height=8
xadvance=6`. The circle painted for it in `bg_selected_tech.dds` is columns 803 to 819
and rows 104 to 120 of the texture, so 819 to 835 and 104 to 120 of the panel.

| | section 2 gives | the screenshot has |
| --- | --- | --- |
| ink of the `1`, x | 811 + 4 + 12 - 3 = 824 to 827 | **825 to 828** |
| ink of the `1`, y | 104 + 2 + 3 = 109 to 116 | **108 to 115** |
| ink of `1938` beside it (`arial_18`, box at 823, 103, 60 wide), x | 823 + 4 + 30 - 16 + 1 = 842 to 871 | **843 to 872** |
| the same, y | 103 + 2 + 3 = 108 to 118 | **107 to 117** |

Both are one pixel right and one pixel up of the arithmetic, which is what half a pixel
each way becomes if the game's pictures are drawn half a pixel the other way - a whole
pixel between text and art on both axes. **The picture side of that was not read**; the
half pixel on the text side is in the bytes and the whole pixel is on the screen.

## 4. The colours of `§`

In the quad loop, `0xAFCDA3`: the byte `0xA7` takes the next character as an index, times
32, into a table **inside the font** at `+0x4A8`; if the entry there is not set (its first
byte is `0xA7`) the same index is tried in a table at the global `0x1B211A8`; `§!` goes
back to the font's own colour (`+0x38`). The font's table is what its `colorcodes` block
in the `.gfx` file fills - `FINDINGS-definitions.md` already lists `colorcodes` among
`CEU3BitmapFont`'s keys. Seven `bitmapfont` entries of `core.gfx` have one, all the same:

    W = { 255 255 255 }   B = { 0 0 255 }    G = { 0 255 0 }    R = { 255 50 50 }
    r = { 160 50 50 }     b = { 0 0 0 }      g = { 176 176 176 }  Y = { 255 189 0 }

**So the colours are data, and a mod's to change**, font by font. What fills the global
table the other fonts fall back to was not read.

---

## What is not established

- **Why the pictures sit half a pixel the other way.** Section 3 measures it; the sprite
  side's vertex arithmetic was not read.
- **Orientation 5** of the switch, and what 2 and 3 do with text set right.
- ~~**The line breaking loop**~~ - read 2026-11-14, section 2.1. Left of it: what `$` (`0xAFC256`) is used for in a
  text, `0xA4` adding 16 to the width at `0xAFC5E1`, and `@` in the quad loop at `0xAFCE0F`.
- ~~**`textBoxType`**, the other kind of text box: assumed to reach the same slot 8~~ - it does not: it renders through
  slot 6 into a texture of its own (section 1, section 2.2), read 2026-11-14.
- **The global colour table** at `0x1B211A8`: who fills it and with what.
- ~~**Button captions.**~~ The box `GuiButton_Construct` passes is read since 2026-11-14 (section 1): the button's `size`
  with no border on a button with no sprite, and on a sprite a `textBoxType`'s display object laid out in the sprite's
  picture.
- ~~**Where an edit box's line stands up and down.**~~ *Measured* 2026-11-14 on two screenshots of the original, both
  1:1 crops of the maintainer's screen, each placed by its own art (`frontend_button4.dds`'s opaque edge and
  `unitpanel_bg.dds`): **the save dialog's `game_name`** with "Ireland1939_09_07_17sdadad" typed - the capitals and
  figures stand on rows 17 to 24 below the box's top, the `_` on row 26, `small_tiles_dialog`'s rim on rows 8 and 27 and
  columns 10 on; the first letter's ink 17 in and every later one where its `xadvance` sum puts it, rim + 7 + pen; the
  caret's bar (`textcursor.dds` rows 5 to 20) on rows 10 to 25, its stem 173 in, the border plus the line's 156 plus 3,
  plus the sprite's six; and **the unit panel's `unitname`** with "5th Air wing" - the figures on rows 11 to 18 below
  the box's top, the `5`'s ink 17 in. Against sections 2.2.1 and 2.2.2, where the arithmetic puts the line's top at the
  border plus 9 (`game_name`) and at the border plus the border (`unitname`), and a glyph's ink `yoffset` below that and
  one right of its pen (the `+ 0.5` on a glyph's x): **across, both are exactly the arithmetic, a unit right; up and
  down, `unitname` is exactly the arithmetic, 4 + 4 + 3 = 11, and `game_name` is a unit higher than it, 6 + 9 + 3 = 18
  against 17 - and its caret a unit higher than its border, 11 against 10.** The rim stands where the arithmetic puts it.
  So it was neither of the two guesses: the centring's line height is the descriptor's (section 2.2.1, above), and the
  old placing was off by two, not the reading by three. **What lifts the line and the caret by a unit only where a
  picture is behind them was not found**: the projection is set before the background test (`0xAFB319`) and the glyph
  arithmetic does not depend on it; the quad (`0xAB61F0`) shows the shown height 1:1 in both boxes - the rim keeps its
  20 rows and the capitals their 8 - so no row is dropped above the text. Candidates not read: where the sprite renderer
  stands a CTextSprite's quad (its corners run from b up to the shown height less d less 1, y up), and whether the
  caret is placed off the display object rather than the box. Note also that the background's corners are set less 0.5
  in a space whose y points up (section 2.2.2), which by Direct3D 9's integer pixel centres moves it a pixel *down* in
  its texture while the glyphs' `+ 0.5` leaves them where they are - which would explain the unit if the whole quad
  stood a unit up where there is a background, and nothing explains that yet. A `textBoxType` with no picture, drawn
  through the same object, would on this evidence also stand at the arithmetic and not a unit up as an
  `instantTextBoxType`'s text does (section 3); no screenshot of one has been measured.
- Whether a text sprite's button frames or `buttonstate.fx` state still apply over the picture `0xAFDAC0` draws behind
  its caption.
- ~~Whether a `textBoxType` clips its lines at maxHeight (section 2.2).~~ It shows only its `maxWidth - borderX` by
  `maxHeight - borderY` of its picture (section 2.2.1), read 2026-11-14. Left: who calls the display object's slots 56
  and 57, which crop it; whether a picture's quad is also one unit short of its texels each way; and the arm of
  RenderText taken where the template counts more than one frame.
- Whether an instant box cuts again when its text is set after it was made: no `CGuiText` virtual reads `+0x1B8`.
- Who writes slot 19's byte (the escape switch), slot 6's last two arguments, and what `¤` draws.
