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
shares stack slots. No list the rewrite draws is in this mode.

## Not established

- **Which lists the two callers of `UseEntryHeights` are.** One is made as the game is
  entered; the message log would fit and was not confirmed.
- **Where `+0xE0` and `+0xE4` are filled.** The base constructor's own base (`0xA8D660`) was
  not read, so that they are `spacing` and `borderSize` is from their use.
- **The wheel.** Slot 1 of the second table (`0xA8EA70`) takes it and moves the scrollbar;
  by how much was not worked out.
- **Where the scrollbar stands** beside the box.

## In the record

| rva | name | new or revised | confidence | |
| --- | --- | --- | --- | --- |
| `0x68E390` | `GuiListBox::Layout` | new | confirmed | rows, section 2; heights `likely` |
| `0x68EF70` | `GuiListBox::InsertEntry` | new | confirmed | the row count |
| `0x279320` | `GuiListBox::UseEntryHeights` | new | inferred | sets the mode; two callers |
| `0x68C0E0` | `GuiListBoxBase_Construct` | new | inferred | clears the mode |
| `0x72BDC0` | `GuiType_listboxType_Create` | new | inferred | the declaration's factory |

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
