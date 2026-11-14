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
- **Placement**: with `fit` the texture is the box's size, rounded up to powers of two - left at the border, centre at
  `maxWidth/2 - w/2` with no border, right at `maxWidth - borderX - 1 - w`; without `fit`, at the border whatever the
  format. Lines step down by `+0x494` from the texture's top less borderY; with a background the text is centred
  vertically.

How the display object draws the texture was not read, so a clip at maxHeight is likely, not established.

### 2.3 `CTextLayout::BuildLines`, `0xACCB10` (rva `0x6CCB10`) (read 2026-11-14)

O = slot 18 = `GetStringWidth("O", 1)` (the string at `0x16049D4`). Where the width up to the first newline, plus O, is
over the area: if the text has a space and the width up to the first space plus O is within the area, it is cut at the
**last space before n** (`0xACE240`) and the space dropped (`0xACE150`); otherwise after n characters (`0xACE090`) - n
being **the fewest characters at least `area - O` wide** (`0xACC960`, a binary search). Otherwise the line is taken with
its newline. *Corrected*: the record had "at the last space that fits", `inferred`.

Its users and their area: a **tooltip**, `maxWidth - 3 * border` = 352, then `SetTextToFit`, whose limit of 368 never
breaks again; the **message log**, the button's width less 10 and a height of 2000, the result split at `\n`; the
**diplomacy status list**, the row text box's maxWidth (`[edi+0x8c]` beside `mov ecx,0x7d0` at `0x78A484`); the
**technology effects**; the **edit box**. Not followed: the calls in the lobby's constructor and `OnBack`, the province
view, the statistics ledger and `CreateIcon`.

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
- ~~**Button captions.**~~ Slot 8, through a `CGuiText` of their own (section 1); the box `GuiButton_Construct` passes
  was not read.
- Whether a `textBoxType` clips its lines at maxHeight (section 2.2).
- Whether an instant box cuts again when its text is set after it was made: no `CGuiText` virtual reads `+0x1B8`.
- Who writes slot 19's byte (the escape switch), slot 6's last two arguments, and what `¤` draws.
