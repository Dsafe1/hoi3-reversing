# How a list box lays out what is in it

*Read 2026-10-09 for the rewrite. The maintainer saw the ship builder's list run over the
line under it there, with every ship type unlocked, and said the game's never does. The
rewrite stacked a list's entries with the box's `spacing` between them and cut them off at
the box's edge, by "the plain reading of the declaration"; nothing of the original's had
been read. It does neither.*

Addresses are virtual, with the rva after a slash where a function is named. The widget has
no RTTI name; the record calls its two tables `GuiObject_listboxType` (`0x15FE6D0`) and
`GuiObject_listboxType_CGuiObject` (`0x15FE758`, at `+4`), and the names here - `GuiListBox`
and its members - are ours.

## 1. The object

`0x160` bytes, made by the `listboxType` declaration's factory (`0xB2BDC0 / 0x72BDC0`),
which hands the declaration's position, size, `borderSize`, background and scrollbar name to
a base constructor (`0xA8C0E0 / 0x68C0E0`, tables `0x15FE898` and `0x15FE920`) and then
writes the two tables above over the base's.

| | |
| --- | --- |
| `+0x54` | the entries: a `CList`, head `+0x54`, tail `+0x58`, count `+0x5C` |
| `+0xDE` | the box's height, a `short` |
| `+0xE0` | a gap put before each entry in the second mode; `likely` the declaration's `spacing` |
| `+0xE4` | where the first entry goes, both ways; `likely` the first number of `borderSize` |
| `+0xF8` | the scrollbar, or null |
| `+0x128` | a `CList` of the entries the second mode has hidden |
| `+0x13E` | **the mode**: 0 rows, 1 heights |
| `+0x144` | how many entries have been put in |
| `+0x148` | **how many rows the box has** |

## 2. Rows, which is what nearly every list is

`+0x13E` is cleared by the base constructor (`0xA8C1C1`) and written in one other place in
the image, `GuiListBox::UseEntryHeights` (`0x679320 / 0x279320`), which has two callers:
`CInGameIdler::Enter` (`0x660E10`) and `0x7628A3`, on a list named `list`. **Every other
list in the game is in the first mode** - the build queue, the research queue, the four
builders' lists among them. `confirmed` for the writes; that those two callers are the only
ones rests on a search for direct calls.

**How many rows**, worked out again each time an entry is put in
(`GuiListBox::InsertEntry`, `0xA8EF70 / 0x68EF70`):

    rows = (int)((float)box height / (float)height of the entry just put in)    ; cut
    scrollbar's greatest value = max(entries - rows, 0), a row a step

`confirmed` (`0xA8EFA0`..`0xA8EFCF`: `movsx` of the entry's height and of `[edi+0xde]`,
`divsd`, `cvttsd2si`, `mov [edi+0x148], ecx`)

**Where they go** (`GuiListBox::Layout`, `0xA8E390 / 0x68E390`, slot 27, from `0xA8E81B`):

    at    = (+0xE4, +0xE4)                            ; one word, used for x and for y
    first = the scrollbar's value as a whole number, or 0 with no scrollbar or a hidden one
    h     = the height of the FIRST entry
    for each entry, counted from 0:
        if (index < first || index >= first + rows)   hide it
        else  put it at `at`;  at.y += h;  show it

`confirmed` (`0xA8E81B`..`0xA8E8CA`)

What that means, each of which the rewrite had otherwise:

- **A box shows a whole number of entries.** One that has no row is hidden, whole. Nothing
  is cut off at the box's edge, and there is no half entry at the bottom.
- **`spacing` plays no part.** Entries are one first-entry's height apart and touch.
- **The box's height is its row count, and nothing else limits it.** A box higher than its
  frame shows entries past the frame.
- **Scrolling is by the row.**
- The scrollbar is shown when its greatest value is 1 or more - more entries than rows -
  and hidden otherwise (`0xA8E7E0`: `cmp [eax+4], 0x3e8`).

### The files are written to it

*Measured, 2026-10-09, Their Finest Hour's own files.* The production screen's lists are
whole numbers of their entries, with no room for a gap:

| list | box | entry | rows |
| --- | --- | --- | --- |
| `build_queue` | 280 | `queue_entry`, 40 | 7 |
| `ai_need_queue` | 176 | `ai_need_entry`, 44 | 4 |
| `convoy_queue` | 132 | `convoy_entry`, 22 | 6 |

Each of the three gives `spacing = 2`. With a gap of two between entries the build queue's
seventh line would be twelve units out of its box.

### The ship builder's list, which is what was asked

`shipbuilder.gui` gives `queue`, at 103, a size of 533 by **620**, which is 25 rows of a
`build_ship_entry`'s 24 - in a window whose frame for the list ends near 404, with the
selected ship's line at 414. The air builder's list and the brigade picker's are 620 high
too; the brigade builder's is 300, twelve rows. **So by this reading the base game's ship
list never scrolls: twelve rows end at 391, inside the frame, and a thirteenth is drawn
from 391 to 415, across the frame's edge and the gap under it.** The base game has
thirteen ship types, several of them late; whether a game reaches thirteen at once was
not looked at. BlackICE's own `shipbuilder.gui` gives the list 941 by 345, fourteen rows
and then the scrollbar. **The maintainer's recollection is the other way** - "a visual
gap which the original never overflows" - and nobody has watched the unmodded game with
thirteen ship types to build, so this stands as `inferred` from the routine and the file,
against a memory of the game.

## 3. Heights, for two lists

With `+0x13E` set, `Layout` (from `0xA8E3A6`) goes by the entries' own heights:

    total = sum of the entries' heights; if (gap > 0) total += (gap - 1) * entries
    if (box height - border < total)                        ; they do not all fit
        show the scrollbar
        from = (total + 2 * border - box height) * the scrollbar's value
        entries wholly above `from` are hidden; the first at or below it goes at the top,
        each after `gap` and the one before it; one that would end past
        box height - 2 * border is hidden
    else
        hide the scrollbar; each goes `gap` under the one before, the first `gap` down

`likely`: read in the decompiled C only, and the function is one where the decompiler
shares stack slots.

**The gap is not what a screenshot shows, 2026-10-09.** The maintainer's screenshot of the
running game's unit panel - the list `list` of `single_unitpanel`, which declares
`spacing = 2` - has every entry beginning on the pixel row after the one before ends: two
`sup_parent_unit_entry` rows 18 apart, then the header 40, the status 44, the order 28, the
buttons 32 and the brigades' window, eleven border lines over 290 rows with nothing between.
So either `gap` is not the box's `spacing` or the reading of where each entry goes is wrong;
the `(gap - 1) * entries` in the total is at least a sign that the gap is not simply added.
Not followed up in the bytes. OpenHOI3 lays that list out touching, from the screenshot.

## 4. What is cut at the box's edge, across: nothing (read 2026-11-15, the `rowclip` agent; the base constructor's `mov word [esi+0xF0], 0x100` at `0xA6018D` checked off the listing by the collecting session)

*Read for the rewrite's technology panel: its `effects` list is 310 wide, each `detail_entry` row is resized to
180, and the row's `instantTextBoxType` lays its text out to 330 less one `O` (`FINDINGS-countryviews.md`,
section 5.5) - so a line can be wider than the row and than the list. The question was what of it the original
shows.*

**Nothing clips a list box's rows, or any interface object, to the box or to its window.** Section 2 already had
it that a row with no place is hidden whole; this is the other direction. Three readings, each with its scan:

1. **The draw list's scissor is never in force.** `CGraphics_DrawObjectList` (`0xA73390`) turns on
   SCISSORTESTENABLE (render state `0xAE`) and calls the device's `SetScissorRect` (slot 75) with the graphics'
   `+0x6BCE0` around an object whose byte `+0xF0` is set. Neither half is ever live:
   - **The rectangle is all nought.** `findRefs --address` over every dword from `+0x6BCD8` to `+0x6BCF4`: the
     four dwords `+0x6BCE0..+0x6BCEC` are reached only by the CGraphics constructor, which zeroes them
     (`0xA6F1BB`..`0xA6F1CD`), and by the draw's push (`0xA7357E`). (`0xA70FAC` adds `0x6BCEC` to `CGraphics+4`,
     which is the `objectTypes` hash table at `+0x6BCF0`, as the record already says; three further "hits" on
     `+0x6BCE8` are call targets whose bytes happen to match.) Its neighbours are the present parameters handed
     to `Reset` (`+0x6BCA4`, device slot 16), a byte at `+0x6BCDC` and that hash table - nothing that would write
     it through a structure pointer. A rectangle `{0, 0, 0, 0}` passes no pixel, so **a flagged object would draw
     nothing at all** - not a clip to a list.
   - **No store sets the flag.** Every instruction in `.text` whose destination is memory at a register plus
     `0xF0`, of any width: 165 sites; 8 are byte stores through a base other than `esp`/`ebp`. Four are in
     `ClientCommandChannel`, one in `CAIStrategy`'s constructor, one (`0xB0E065`) in a `.gfx` sub-block loader
     whose object carries CColors at `+0x90` and `+0xAC` and is no draw object, and **two copy the byte from a
     display object onto its replacement** - `CIcon::SetSpriteType` (`0xAA29B0`) and `GuiButton_SetSpriteType`
     (`0xB40710`), each when the sprite is changed by name. **Positive control**: the same scan finds the draw
     objects' base constructor (`0xA600E0`, called by the 2D object's constructor `0xAB2770`, hence by `CSprite`
     and `CGuiText`), whose `mov word [esi+0xF0], 0x100` at `0xA6018D` makes the flag 0 (and `+0xF1` 1). So
     every draw object starts at 0 and only ever inherits another's 0. `inferred` as a whole only because a store
     through a computed pointer (no displacement `0xF0`) cannot be ruled out by a scan; every direct one is
     accounted for.
2. **An `instantTextBoxType` draws its text whole, then and there.** `CGuiText` (`0x1D4` bytes, vftable
   `0x1606C70`) is itself a draw object - its constructor calls `0xAB2770` - and its slot 10 is `CGuiText::Draw`
   (`0xB326C0`), so `CGraphics_DrawObjectList` reaches it as it reaches a sprite. It calls the font's slot 8,
   `CEU3BitmapFont::DrawText`, whose glyph loop (`0xAFD0ED`..) writes every glyph with a height into the shared
   batch at `0x1B1A118` with **no test of its corners against the box, maxWidth, maxHeight or the area**, and
   draws the batch with the device's `DrawPrimitiveUP` (slot 83, a triangle list) - 194 glyphs at a time and the
   rest before it returns. So a line laid out wider than its box is drawn to its last glyph, past the box, the row,
   the list and the window alike. The only branches on a glyph are its height (none: advance only), the escape
   characters and the batch count.
3. **The list box neither crops nor redirects.** `GuiListBox::Layout` hides or shows whole rows (section 2);
   `CGraphics_CollectObjects` puts every visible object and its children on the draw list with only a
   translation, no bounds; and no call of a display object's crop slots (56, 57 - `CSprite +0x178`,
   `CTextSprite +0x17A..`) was found in the list box's or the window's code (`slotcalls.py 56` and `57`, filtered
   to `0xA7E000`..`0xA92000`: one hit, `0xA90F4E`, which is a field read of `+0xE0` and no call). No render target is made for a list.

**The one cut there is** is the picture a `textBoxType` is drawn into (`FINDINGS-textdraw.md`, section 2.2.1),
which shows only its `maxWidth` less its border across; and a `fixedsize` box is cut to `" ..."` before it is
laid out (section 2.4). Both are the box's own, not its list's. An `instantTextBoxType` has neither.

**What that gives the technology panel**: the `detail_entry` rows are instant text boxes, so a line up to 330
less an `O` wide - about 321 in Arial12 - stands whole in a list 310 wide, up to about 11 units past the list's
right edge, over whatever is drawn there; on the 1120-wide `tech_details` window the list ends at 990, so the
line stays inside the window. Where the list's scrollbar is shown, a long line runs under or over it by the
draw order, which was not read (the scrollbar's place is section 5).

## 5. Where the scrollbar stands, and `offset` (read 2026-11-19)

Read after BlackICE was found setting `offset` on seven list boxes, with comments that it was needed to line things
up, and OpenHOI3 accepting the key and doing nothing with it.

**The declaration's grammar** is `GuiType_listboxType_LoadKey` (`0xB2B660`, slot 4 of the declaration's table
`0x1606A64`): sixteen keys, the rest to `CGuiType::LoadKey`. `offset` (token 353) is an `{x y}` pair at the
declaration's `+0xFC`, read by the same routine as `position` (`+0xF4`), `size` (`+0x104`) and `borderSize`
(`+0x10C`). The whole map is the record's entry. Two things in it look odd and are left as read: `step` and `spacing`
both write `+0x158`, by two readers; and `parent` goes to `+0x84` and `background` to `+0xA0`, where the record's
`GuiType_listboxType_Create` entry calls `+0x84` the background - what the create hands on was not checked against it.

**The scrollbar is placed by `GuiListBoxBase_Construct`**, which keeps the declaration at the box's `+0x140`
(`0xA8C1E6`, its argument at `[ebp+0x30]`, which the create pushes as `esi`). Where the box has a scrollbar
(`+0xF8`):

    x = the box's width (+0xDC, a short) + offset.x      (the declaration's +0xFC)
    y = offset.y                                           (the declaration's +0x100)

stored as floats at the scrollbar's `+0x74` and `+0x78` (`0xA8C28F`..`0xA8C2F1`). **With no `offset` the bar stands at
the box's right edge, at its top** - which is where OpenHOI3 put it before this reading. `confirmed`. What the
constructor goes on to do with the screen's size straight after (`+0x6B9BC`, `+0x6B9C0`, halved) was not read; it
does not touch the two figures before they are stored.

**`offset` is therefore the scrollbar's offset from the box's top right**, not the rows'. In the base game five list
boxes set it, all `{ x = 0 y = 0 }`; BlackICE sets it on thirteen, seven of them otherwise -
`country_diplomacy.gui` (y 1, -14 and -6), `country_politics.gui` (y -4), `outliner.gui` (x -16),
`single_unitpanel.gui` (y 1) and `unitpanel.gui` (y 5).

## Not established

- **Which list `CInGameIdler::Enter`'s call of `UseEntryHeights` is for.** It is made as the
  game is entered; the message log would fit and was not confirmed. **The other is known
  since 2026-10-09**: `0x7628A3` is inside `CSingleUnitPanel::Rebuild`, and the list is the
  one a selected unit's panel is made of, whose entries are windows of very different
  heights and two of which grow with their own rows (`FINDINGS-unitpanel.md`, sections 2
  and 8).
- **Where `+0xE0` and `+0xE4` are filled.** The base constructor's own base (`0xA8D660`) was
  not read, so that they are `spacing` and `borderSize` is from their use.
- **The wheel.** Slot 1 of the second table (`0xA8EA70`) takes it and moves the scrollbar;
  by how much was not worked out.
- ~~**Where the scrollbar stands** beside the box.~~ Section 5.
- **What the base constructor does with the screen's size** after placing the scrollbar (section 5).

## In the record

| rva | name | new or revised | confidence | |
| --- | --- | --- | --- | --- |
| `0x68E390` | `GuiListBox::Layout` | new | confirmed | rows, section 2; heights `likely` |
| `0x68EF70` | `GuiListBox::InsertEntry` | new | confirmed | the row count |
| `0x279320` | `GuiListBox::UseEntryHeights` | new | inferred | sets the mode; two callers |
| `0x68C0E0` | `GuiListBoxBase_Construct` | new | inferred | clears the mode |
| `0x72BDC0` | `GuiType_listboxType_Create` | new | inferred | the declaration's factory |
| `0x673390` | `CGraphics_DrawObjectList` | revised | confirmed | comment: the scissor is never live, with the scans (section 4, 2026-11-15) |
| `0x7326C0` | `CGuiText::Draw` | revised | confirmed | a signature (slot 10 of CGuiText) where it had none; draws whole |
| `0x6FC070` | `CEU3BitmapFont::DrawText` | revised | confirmed | comment: no glyph is tested against any rectangle |
| `0x6600E0` | `DrawObjectBase_Construct` | new | inferred | the draw objects' base constructor; +0xF0 = 0 |
| `0x6A29B0` | `CIcon::SetSpriteType` | new | inferred | copies the scissored byte onto the new sprite; CEU3Minimap slot 57 |
| `0x740710` | `GuiButton_SetSpriteType` | new | inferred | the same for a button's display object |
| `0x72B660` | `GuiType_listboxType_LoadKey` | new | confirmed | the declaration's sixteen keys, `offset` at +0xFC (section 5, 2026-11-19) |
| `0x68C0E0` | `GuiListBoxBase_Construct` | revised | inferred | comment: the declaration at +0x140 and the scrollbar placed by `offset` (section 5) |

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| `GuiListBox` | `0x54` | `entries` | `CList` | new |
| `GuiListBox` | `0xDE` | `height` | `short` | new |
| `GuiListBox` | `0xE0` | `gap` | `int` | new |
| `GuiListBox` | `0xE4` | `border` | `int` | new |
| `GuiListBox` | `0xF8` | `scrollbar` | `void*` | new |
| `GuiListBox` | `0x128` | `hidden_entries` | `CList` | new |
| `GuiListBox` | `0x13E` | `uses_entry_heights` | `bool` | new |
| `GuiListBox` | `0x144` | `entry_count` | `int` | new |
| `GuiListBox` | `0x148` | `rows` | `int` | new |
| `GuiListBox` | `0x140` | `declaration` | `void*` | new (2026-11-19, section 5) |
| `GuiListBox` | `0xDC` | `width` | `short` | new (2026-11-19, section 5) |
| `CSprite` | `0xF0` | `scissored` | `uint8_t` | revised (comment: nobody sets it; the rectangle is empty) |
| `CGraphics` | `0x6BCE0` | `scissor_rect` | `int[4]` | new |
