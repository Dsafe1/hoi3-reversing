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
| `+0x1B8` | a flag: when set the constructor has the font re-flow the text (slot 12) |
| `+0x1BC` | the font |

Its draw routine is `0xB326C0` (rva `0x7326C0`, `ret 0x18`): font slot 15 with the
colour block, then **font slot 8** with, in order, the text, the format, the orientation,
a rectangle `{x, y, maxWidth, maxHeight}` by value, border x, border y, and a pointer to
the area size.

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
and centre and treat right as left. 4 and 5 (`0xAFCC16`, `0xAFCC77`) have terms of their
own that were not worked through. Of the 1118 text boxes in the base game and Their
Finest Hour, 1077 are `UPPER_LEFT`.

**Every corner of every glyph has half a pixel added to x and to y.** In the quad loop
`xmm7` holds `-0.5` (`movsd xmm7,[0x160a350]` at `0xAFCD95`) and each coordinate is
`subsd`-ed by it: left `pen + xoffset + 0.5` (`0xAFD200`), right, top `lineY - yoffset +
0.5` (`0xAFD215`), bottom. In a space with y upwards that is half a pixel right and half
a pixel **up**.

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
- **Orientations 4 and 5** of the switch, and what 2 and 3 do with text set right.
- **The line breaking loop**: when a line breaks, the `0x140` it uses for a box with no
  width, the two characters it treats specially (`$` at `0xAFC256`, `0xA4` adding 16 to
  the width at `0xAFC5E1`, `@` in the quad loop at `0xAFCE0F`).
- **`textBoxType`**, the other kind of text box: assumed to reach the same slot 8 through
  the layout `GuiObject_textBoxType::SetText` asks for, not traced.
- **The global colour table** at `0x1B211A8`: who fills it and with what.
- **Button captions.** Whether a button's text goes through slot 8 with a box of its own.
