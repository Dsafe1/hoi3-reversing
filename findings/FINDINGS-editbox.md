# The edit box: focus, keys and the caret

*Read 2026-11-05 statically out of `hoi3_tfh.exe` with `scripts/disasm.py`, `scripts/findRefs.py`,
`scripts/vtable.py`, byte-pattern scans and a Ghidra copy. For OpenHOI3's save dialog (`menubar.gui`'s
`menu_save`, edit box `game_name`). Addresses are VAs, with rvas beside named functions. Only valid for this
build. Nothing here was set against a running game. Spot-checked off the bytes by the collecting session: the
250 at VA `0xA8F2E3` (`mov dword ptr [esi+0xE8], 0xFA`, the layout at `+0x48` and its `+0xA0`), the blink's
`fld qword ptr [0x160A308]` and `fld1` in `Update`, and the insert helper's `cmp edx, [ebx+0xA0]`.*

**In one paragraph.**
- **Focus.** An edit box takes the keyboard in one of two ways: a press of the left button over it, or code
  setting its byte `+0x40` to 1. That byte is a request; the gui's input pass grants it at the end of the frame.
  The box keeps the keyboard until another edit box is clicked or given it. Hiding the box, Enter, Escape and
  clicking a button do not take it away.
- **What goes in.** Every character message goes in as its single byte, with these exceptions:
  - Tab;
  - with a font whose `effect` is yes (the default): `"` `§` `¤` `£` `@` `{` `}`;
  - the box's own refused list (only the console fills one);
  - nothing at all once the text holds **250** bytes.
- **Editing keys.** Backspace, Delete, Left, Right, Home and End are the only keys that edit or move the caret.
  Enter is swallowed. There is no selection, no clipboard and no Ctrl key reachable through a box.
- **The caret** is the `cursor` sprite. It shows for half a second and hides for half a second. It sits at the
  width of the text before it plus 3 pixels, past the border and the `cursor` offset. It hides for a moment after
  each key.
- **What is shown.** The text is word-wrapped to the box's inner width, and the box shows only the line the caret
  is on.

## 1. The pieces

| | what | where |
| --- | --- | --- |
| the box | `GuiObject_editBoxType`, 0x1D0 bytes, table `0x15FED90` (47 slots), abstract base table `0x15FECD8` | built by `0xA8F160` (rva `0x68F160`) from the type's builder `0xB29F80` |
| its text | `CTextLayout`, 0xB8 bytes, table `0x1602550`, held by value at `+0x48` (table there `0x15FEE50`) | `0xACBB90` (rva `0x6CBB90`); 13 other callers, the tooltip text among them |
| the gui | `CGui::ProcessInput`, CEU3Gui slot 1 | `0xA7D0F0` (rva `0x67D0F0`) |

None of these classes has an RTTI name, so all the names are ours.

The box's declaration keys come from the `editBoxType` LoadKey switch (`0xB2A120`, eight cases plus CGuiType's
default):

- `font`
- `textureFile`
- `size`
- `position`
- `borderSize`
- `text` (localised where not empty)
- `orientation`
- `cursor = { x = y = }`, which is new to the record: an offset added to the caret's position. No base-game file
  sets it.

**There is no `maxCharacters` key.** No such string exists anywhere in the image, nor `maxChars` or
`max_characters`. As a positive control, the same search finds `maxWidth`, `borderSize` and `cursor`.

## 2. Focus

**The gui's pass** (`CGui::ProcessInput`, once a frame, before the screen's own handler; CInGameIdler calls it at
`0x651C2C` with its mouse, its keyboard and its event list), *confirmed*:

1. It drops the keyboard focus (`CGui +0xA0`) if that object is `released` (`CGuiObject +0x2E`).
2. **A key event** goes first to the focus, if the focus is shown. If the focus does not handle it, it goes to each
   shown object of the gui's `+0x6C` vector in turn, until one marks it handled.
3. **A mouse event** goes to the objects under the pointer, topmost first.
4. **A handled event is taken off the list and freed.** CInGameIdler's list keeps no entries (`+0x1CBC` is written
   0 once, at `0x648459`), so the map's handler (`CInGameIdler_HandleInput`) never sees a key a box took.
5. After the events, every shown object gets slot 6 (Update).
6. **The focus step.** The last shown object in the gui's vector whose `clicked` byte (`+0x40`) is set becomes the
   focus. The byte is cleared as it is read. Exceptions:
   - an object marked `released` does not take the focus;
   - if the current focus has `keeps_focus` (`+0x41`), nothing changes.

   Otherwise the old focus gets slot 21 (**LoseFocus**: `editing` = 0, caret hidden) and the new one slot 20
   (**GainFocus**: unless `read_only` (`+0x159`), `editing` = 1 and the caret shown).

**A click.** The box's slot 1 (`OnInput`, `0xA8FD50`) sets `clicked` only for a mouse event (kind 0) while the box
is under the pointer (`+0x2C`, set by `CGuiObject::OnPointerOver`) and the left button is down (the mouse's slot 12,
its `+0x94`). It also marks the event handled. **It does not move the caret**; neither does GainFocus. That a press
event rather than a release does it is *inferred*: any mouse event with the button held qualifies.

**Code.** `CInGameIdler::OpenSaveDialog` writes `game_name`'s word `+0x40` = 1 at `0x66CB73`. The console's toggle
does the same to its box at `0x65380E`. Because it is a word store, `keeps_focus` is cleared at the same time. The
box gets the focus in the next pass, once it is shown. **So the "give focus" the save dialog does is that store.**
`0x690140`, which it calls just before, only refreshes the shown text (section 6).

**Losing it.** A pattern scan for stores of 1 at `+0x40` over the gui code (`0xA70000`-`0xB70000`) finds only the
box's own two (`0xA8FD78`, `0xA8F9D2`). Over the whole image there are thirteen more word stores; two were read, the
two above. **Buttons, icons and windows never set `clicked`**, so pressing `save` or `cancel` does not take the
keyboard away. This is *likely*: a store of a register value would escape the scan.

Hide (slot 14) leaves `editing` and the gui's focus alone. A hidden focused box ignores keys, because `OnInput` needs
`is_open`, and they pass on to other receivers. When it is shown again its caret comes back. Nothing in the key path
clears the focus: not Enter, not Escape, not Tab.

## 3. What reaches the box

**The window procedure** (`0xA91610`) queues events. Its choice is made by `KeyEvent_IsNavigationKey` (`0xA800D0`,
rva `0x6800D0`), *confirmed*.

A **key down** is queued only if one of two things holds:
- it is one of: Up, Down, plain Left/Right, Home, End, Delete without Shift, Ctrl/Shift+Left/Right, Ctrl/Shift+Insert,
  Shift, Ctrl, Pause, Escape, F1-F24, Page Up/Down, Tab;
- or Ctrl is held.

A **character** (WM_CHAR) is queued unless it is Tab or Ctrl is held. **With Ctrl held no character is queued at all.**
If the chat or console input (`app +0x80`) is open, it takes both kinds of event first.

**The box's gate** (`OnInput`). A key event is taken only while the box is shown and `editing`, and only if it is
one of:
- a character;
- Left or Right with neither Ctrl nor Shift held;
- Home or End (key down);
- Delete without Shift.

Everything else falls through unhandled, including Escape (key down), Up, Down, Page Up/Down, Insert and every Ctrl
or Shift combination.

## 4. Characters

**What goes in** (*confirmed*): the event's code as one byte (`KeyEvent_ToText`). That means any byte the window
procedure delivers, which on an ANSI window is the system code page (Windows-1252 on a Western system; *inferred*
from the ANSI window functions the image uses).

Typed characters that look like key codes still go in: `$` (0x24), `#` (0x23), `%`, `'`, `.`, `(`. **Control
characters the window procedure lets through go in too**: Escape's character, 0x1B, is not refused.

**Refused**, all three tests in `OnInput`:

| what | when | **[exe]** / **[mod]** |
| --- | --- | --- |
| Tab (9) | always | [exe] |
| `"` 0x22, `§` 0xA7, `¤` 0xA4, `£` 0xA3, `@`, `{`, `}` | where the box's font (its `font` key, looked up in `fonts` then `bitmapfonts`) has `effect` set (CEU3BitmapFont slot 19, its byte `+8`) | the seven bytes [exe]; `effect` [mod: `interface/core.gfx`, the font's `effect = no`]. **The default is yes** (`0xAF9889`); `Arial12_bold`, `game_name`'s font, sets nothing, so the seven are refused in the save box |
| the box's refused list (`+0x188`) | `EditBox_RefuseCharacter` (`0xA90570`) | [exe]; **only the console calls it**, with `0xA7` and `` ` `` (`0x60C055`, `0x60C05F`) |
| the layout's refused list (`+0x88`) | `CTextLayout_RefuseDoubleQuote` | [exe]; only `unitname` and the unit stats window, so a unit's name cannot hold `"`. `game_name` is not affected |

**A refused key is not marked handled**, so it falls through to the next receiver and then to the map's handler. The
map's handler opens the console on `0xA7` (FINDINGS-selection.md A.8), **so `§` typed into the save box opens the
console** (*inferred*: the map handler runs every frame, menu or not).

**Maximum length** (*confirmed*): the box's constructor sets the layout's `max_length` (`+0xA0`) to **250**
(`0xA8F2E3`, **[exe]**, the same for every edit box) over the layout's own default of 1,000,000. Each of the three
insert helpers refuses once the text **already** holds 250 bytes or more. So:
- typing stops at 250;
- a longer string inserted below that is kept whole;
- `SetText` empties first, so text set by code is never cut.

No `.gui` key moves it.

**The fit to the box's lines** (*confirmed*, 2026-11-12, `FINDINGS-unitrename.md` section 5): `CTextLayout::InsertText`
ends by backspacing while the wrapped text has more lines than the box's height holds, or than its max lines where those are
set - a loop the record had "not in an edit box", but every edit box's constructor clears the layout's +0x9A that would skip
it (`0xA8F528`). So a box holds what fits its own height, and the unit panel's `unitname`, max lines 1, a single line.

## 5. Editing keys

`CTextLayout::HandleKey` (`0xACC2E0`, rva `0x6CC2E0`), *confirmed*. The first column is what reaches it through a box.

| key | message | does |
| --- | --- | --- |
| a character | WM_CHAR | inserted at the caret, caret after it (`InsertText`) |
| Backspace | WM_CHAR 8 | erases the byte before the caret, caret left. **At caret (0, 0) it erases the byte after the caret** |
| Delete | key down, no Shift | erases the byte after the caret; nothing at the end; caret stays |
| Left / Right | key down, no Ctrl or Shift | caret one byte; across a wrapped line onto the next or previous. Right at the very end and Left at the very start do nothing |
| Home | key down | column 0 of the caret's wrapped line |
| End | key down | column = `line_length` (`+0x44`), the caret's line length **as last stored** |
| Enter | WM_CHAR 13 | inserts `\n` only where `newline_on_enter` (`+0x98`) is set (never, in a box); then tells every listener (slot 3). **`game_name` has no listener, so Enter does nothing**, but the box marks it handled |
| Escape | WM_CHAR 0x1B | inserted like any byte (the key down falls through) |
| Tab | - | refused, falls through |

So **there is a caret position, and typing inserts at it**, not only at the end. There is no overwrite mode in reach
(`insert_mode` `+0x4C` is 1).

The layout can also do Up/Down, word left/right (Ctrl, stopping at space, `!`, newline, tab), extend a selection
(Shift), copy (Ctrl+Insert), paste (Shift+Insert) and cut. Its clipboard is the gui's own string (gui `+0x7C`),
**never Windows'**. **None of it is reachable through an edit box**, whose gate refuses those keys. There is no Ctrl+V,
Ctrl+C or select-all: Ctrl characters are never queued.

## 6. The caret and where the text goes

**The caret** (*confirmed*) is a sprite of the spriteType `cursor` **[mod: `interface/core.gfx`;
`gfx/interface/textcursor.tga`, loaded as `.dds`, 32x32]**, made in the constructor and hidden at once.

**The blink.** `Update` (slot 6, every frame while shown and editing) reads a seconds clock:
- below 0.5 the phase is 0;
- strictly between 0.5 and 1 it is 1;
- at exactly 0.5, or at 1 or more, the clock restarts.

A change from 0 to 1 hides the caret and 1 to 0 shows it. **That is half a second on, half a second off, a period of
1 second [exe]** (the double 0.5 at `0x160A308`, `fld1`). **A key taken this frame (`typed`, `+0x184`) also hides
it**, until the next 1-to-0 change: up to a second.

**Position**, placed through the sprite's slot 51 every frame:

    the box's position anchored by its orientation over the parent
    + borderSize (x, y)
    + the `cursor` offset (x, y)               [mod: the .gui]
    + the layout's caret pixel:
        x = GetStringWidth(caret's line, up to the caret) + 3        [exe]
        y = line height * caret row

**The text** (*confirmed* as far as the hand-over). `EditBox_RefreshText` (`0xA90140`, rva `0x690140`) hands the
display object (`+0x104`) **the laid-out line the caret is on, and only that line**, through its slot 61. With it go:
the font name, the `textureFile`, the size, borderSize x and y, and 0, 0.

The lines come from `CTextLayout::BuildLines` (slot 51), *likely*. It breaks at `\n` and wraps any line whose width
plus the width of one `O` exceeds the inner width (`size` less twice `borderSize`), breaking at the last space that
fits, else at the most characters that fit. So **when typing passes the box's width, the shown text jumps to the new
wrapped line**; there is no horizontal scrolling and no fixed offset of the box's own. For `game_name` the inner width
is 260 - 16 = 244. **How the display object draws the line inside the box was not read**, so OpenHOI3's measured
offset (`interface.md`, section 7) stands as measured.

## 7. Enter, Escape and the save dialog's buttons

- **Enter**, with `game_name` focused: its key down is never queued (section 3). Its character reaches the box first,
  because the focus is offered keys before anything else. The box consumes it, and with no listener nothing happens.
  So **a button whose shortcut is Enter in the same window would not see it while a box has focus** (*inferred*: how
  a button matches its shortcut was not read). `save` has no shortcut, so pressing Enter does not save.
- **Escape**: the key down falls through the box to the other receivers, where `cancel`'s ESCAPE shortcut can take it
  (*inferred*). Its character 0x1B is offered to the box. If `cancel` has hidden `menu_save` earlier in the same pass,
  the box ignores it; otherwise the byte is inserted. Not settled (shortcut matching unread).
- **Typed keys never reach the map**: a digit, a space or `h` typed into the box is consumed, so it does not recall a
  selection group, pause or open the hierarchy. Refused bytes and Tab do reach the map.

## 8. What looks wrong and is the original's

- Backspace at the very start erases forward.
- End uses the line length stored at the last edit, not the current line's, after the caret moves between wrapped
  lines (*inferred* effect; the stale store is confirmed).
- Typing hides the caret for up to a second.
- A typed `'` (code 0x27) is inserted **and then also moves the caret right**, because `HandleKey`'s Right test has no
  message test; with no Ctrl or Shift held this happens, on a US layout always. Likewise a `%` typed without Shift
  (0x25) moves it left. The insert is confirmed; the effect on non-US layouts is *inferred*.
- The Escape character can be typed into a name.
- A refused key falls through: `§` in the save box opens the console.
- **AltGr characters cannot be typed anywhere**: AltGr reports Ctrl down, and with Ctrl down the window procedure drops
  every character (*inferred* from Windows' AltGr behaviour; the drop is confirmed). `@`, `\`, `{`, `€` on a German
  keyboard among them.
- Only the caret's wrapped line is shown.
- Delete tells no listener; Backspace does.
- A box marked read-only still takes the focus, and shows nothing for it.

## 9. Additions and corrections to the record

- **Corrected**: `FINDINGS-ingamemenu.md` C.3 and the `OpenSaveDialog` entry call `0x690140` "an edit-box routine"
  and the word `+0x40` "inferred the keyboard focus". `0x690140` is `EditBox_RefreshText`; `+0x40` is `clicked`, the
  request the gui grants.
- **Settled** `FINDINGS-tooltips.md`'s open items: gui `+0x98`'s writer is `CGuiObject::OnPointerOver` (slot 0),
  cleared each pass. The layout at `0xACBB90` is `CTextLayout`, which wraps at spaces against its width less one `O`.
- **Settled** `FINDINGS-selection.md`'s frontier `0x6800D0` (`KeyEvent_IsNavigationKey`).
- **New fields** on `CGuiObject` (`+0x2C` hovered, `+0x2D`, `+0x2E` released, `+0x40` clicked, `+0x41` keeps_focus)
  and `CGui` (`+0x98`, `+0xA0` keyboard focus, `+0xA4` keyboard, which is FINDINGS-scrollbar.md's "gui's input
  object").
- **Not in the fragment**: the three tables without RTTI (`0x11FECD8`, `0x11FEE50`, `0x1202550`), because the merge
  takes no `vftable_nortti` kind. Folded bodies left unnamed:
  - the box's slot 15 (`0xA8F8F0`) and slot 46 (`0xB500B0`), each in three tables;
  - the layout's slot 10 (`0xA48130`, `CDiplomacyStatus::GetValue`) and slot 19 (`0xACC920`, `CContinent::GetTag`).
    Slot 19 returns the raw text, and it is what `OnSaveDialogSave` reads.

## Functions

| rva | name | conf. |
| --- | --- | --- |
| `0x68F160` | GuiObject_editBoxType::GuiObject_editBoxType | confirmed |
| `0x68FD50` | GuiObject_editBoxType::OnInput (slot 1) | confirmed |
| `0x68FEA0` | GuiObject_editBoxType::Update (slot 6) | confirmed |
| `0x690510` / `0x690530` / `0x690550` | GainFocus / LoseFocus / CanTakeFocus (20/21/22) | confirmed, confirmed, inferred |
| `0x68F950` / `0x68F980` | Show / Hide (13/14) | confirmed |
| `0x690140` | EditBox_RefreshText | confirmed |
| `0x690570` | EditBox_RefuseCharacter | confirmed |
| `0x68F5C0` `0x68F5F0` `0x68F7A0` `0x68F8E0` `0x68F910` `0x68F9B0` `0x68FCF0` `0x6905D0` | DeletingDestructor, ~, PlaceAt, SetEditing, Release, UpdateWithKey, SetLayer, GetSize | see fragment |
| `0x6CC2E0` | CTextLayout::HandleKey (slot 20) | confirmed |
| `0x6CC600` | CTextLayout::InsertText (slot 21) | confirmed |
| `0x6CD990` / `0x6CDAA0` | Backspace / DeleteForward (39/40) | confirmed |
| `0x6CBF70` | CTextLayout::GetCaretPixel (slot 11) | confirmed |
| `0x6CCB10` | CTextLayout::BuildLines (slot 51) | inferred |
| `0x6CE800` `0x6CE9E0` `0x6CEB50` | the three insert helpers, max-length test | confirmed |
| and 25 more CTextLayout bodies | see the fragment | |
| `0x6B8B10`-`0x6B8C90`, `0x6800D0` | the KeyEvent tests | confirmed |
| `0x67D0F0` | CGui::ProcessInput | confirmed |
| `0x680000`, `0x680090` | CGuiObject::OnPointerOver, ::Release | confirmed, inferred |

## Not established

- **How the display object (`+0x104`) draws the line**: where in the box, and whether a line wider than the box is
  clipped. It is made from the element's name by graphics `0x66FFB0`; its slot 61 takes the text. Not read.
- **How a button matches its shortcut**: whether a focused box pre-empts Enter, and whether ESCAPE fires before or
  after the Escape character reaches the box.
- **Box slot 45** (`UpdateWithKey`): no caller found, nor who fills `CGuiObject +0x34`/`+0x38`. Slot 44
  (`SetEditing`): no caller found.
- **The gui's `+0x6C` receivers vector** (filled by `0xA73CF0`), its `+0x12`, `+0x9C` and `+0x238` bytes, and
  `+0x7C`, the clipboard (only inferred from the constructor's argument).
- **The mask** (`+0x198`): no setter found. The eleven other focus-giving stores were not read.
- **The wrap's exact break**: `0x6CC960` (the most characters that fit) and `0x6CEF80` not read; the line-breaker's
  decompilation is noisy, hence *likely*.
- **Screenshots that would settle the most**:
  - type past `game_name`'s width (the text should jump to a new line);
  - type `'` in the middle of a name;
  - Backspace with the caret at the start;
  - `§` in the box (the console should open);
  - Escape while typing.

**Frontier** (rvas): `0x66FFB0`, `0x66FE30`, `0x6CEF80`, `0x6CC960`, `0x6CE2F0`, `0x6CE3C0`, `0x6CE5A0`, `0x67C400`,
`0x673CF0`.

**Record**: `fragments/merged/editbox-input.json` - 69 addresses, 2 structs (`GuiObject_editBoxType` 0x1D0,
`CTextLayout` 0xB8), 55 fields, 4 slot records.
