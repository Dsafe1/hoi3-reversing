# FINDINGS-unitrename.md: renaming a unit - CRenameUnitCommand, the `unitname` box and the register of names

*Read 2026-11-12, statically, out of `hoi3_tfh.exe` with `scripts/disasm.py`, `scripts/findRefs.py`, `scripts/vtable.py`
and `image.py`, for OpenHOI3's typeable unit name. Addresses are VAs, with rvas beside named functions. Valid only for this
build. Nothing here was set against a running game. None of the sites read is near a `Patch_*` site (trap 19). The edit
box's clearing of layout +0x9A, CUnit_SetName's two writes of 0x1A855F6 and the panel's one-line cap were checked again off
the bytes by the collecting session the same day.*

**It corrects the record** in four places: `CTextLayout::InsertText`'s fit-to-lines Backspace loop was "never in an edit
box" - it runs in every one, the box's constructor clearing layout +0x9A, and it is what holds `unitname` to one line; the
global byte `0x1A855F6` "has no writer" - `CUnit_SetName` writes it, at 0x5C49EB and 0x5C4B07; `UnregisterUnitName`'s and
`RegisterUnitName`'s signatures had `char*` / `CString*` where the code reads a `Hoi3CString*`; and `CCountry +0x84` was a
`void*` "not read" - it is the count of a 0xC-byte set held by value.

**In one paragraph.** The name in the single unit panel's header is filled once, when the header is built, and sent only
when that header is **destroyed** - when the panel is rebuilt or hidden - never on Enter, on losing the keyboard or per
keystroke. On destruction the box's text is trimmed of whitespace and sent only if it differs from the unit's current name
(exact bytes), is not empty, and the header belongs to the single panel; a row of several selected units never sends. The
destructor posts `CRenameUnitCommand` **and** renames the unit locally at once. The command checks nothing: no owner, no
uniqueness, no length. A country keeps one set of names in use, shared by its units, brigades, ships and wings; names need
not be unique, and a rename takes **every** entry of the old name off the set and adds the new one. What can be typed: no
`"`, `§`, `¤`, `£`, `@`, `{`, `}` or Tab; at most 250 bytes; and, the box allowing **one laid-out line**, nothing past what
fits its width - a character that would wrap is backspaced off as it is typed.

## 1. The command: `CRenameUnitCommand`

RTTI class under CCommand, vftable VA 0x15C8E5C (rva 0x11C8E5C), 0x80 bytes - the size every `new` for it asks (0x76DA4A,
0x887126, Clone at 0x5DDB9C).

| offset | what |
| --- | --- |
| +0x00..+0x3B | CCommand (+4 = 0x18D; type id 0x394 at +0x2C and +0x30; +0x34 = 0xFFFF; +0x36 and +0x38 zero) |
| +0x3C | `unit`, a 0x28-byte reference: cached CUnit* +0x3C, id pair +0x40 (type) / +0x44 (id), a string +0x48 |
| +0x64 | `name`, a Hoi3CString (capacity at +0x78) |

- **Prototype constructor** `CRenameUnitCommand_default` (0x5DD6F0, rva 0x1DD6F0), `ret 4`, called once by
  RegisterCommandTypes at 0x887142: an empty reference (pointer 0, the null id from 0x1A8CC94/0x1A8CC98), an empty name.
- **Constructor** (0x5DD890, rva 0x1DD890), `(storage, CUnit* unit, Hoi3CString name)`, the name by value, `ret 0x24`: the
  reference built from the unit pointer by 0x42DD70, the name copied to +0x64; it tests nothing. **Its only caller is
  0x76DA8B, in `CUnitView::~CUnitView`**; nothing else builds a `rename_unit` but the factory, through Clone.
- **Keys** (the recorded LoadKey, 0x5DDB20): `unit` (token 0x256) by ParseObjectReference into +0x3C; `name` (token 0x1A),
  the parse buffer (parse +0x22C) assigned to +0x64 - the field map's "name lands nowhere" was its own limit. SaveContents
  (slot 2, 0x5DDAB0) writes `unit` with the id pair, then `name`, then CCommand's own fields.
- **GetTypeId** (slot 7, 0x5DDAA0): 0x394, `rename_unit` in `ghidra/saveTokens.json`. **Clone** (slot 13, 0x5DDB80,
  `ret 0x1C`): `new 0x80` and `CRenameUnitCommand_copy` (0x5DDBF0).

## 2. Execute, and the gate before it

**Slot 14**, IsValid, is 0x5E2DF0, one body folded into 18 unit commands' tables: it resolves the unit from +0x40/+0x44,
stores the pointer at +0x3C and answers whether it was found. The post deletes a command whose slot 14 says no, and the
drain asks again before it executes (`FINDINGS-commands.md`, 0xB3C0D7 and 0xA89844). So **a rename of a unit that no
longer exists is dropped silently**.

**Execute** (slot 6, 0x5DD960, rva 0x1DD960, bare `ret`), *confirmed*: (1) re-resolves the unit - the id table at
0x1A857F4 for a type id up to 0x1268, else 0x1A857F0, through FindPersistentById (0xA9DA00), less 8 for the CUnit - into
+0x3C; (2) **`CUnit_SetName(unit, +0x64)`** (section 4); (3) where the in-game screen's slot 105 answers an object (the
order of battle browser, `CInGameIdler +0x1360`), appends a reference to the unit to its `row_changed_queue` (+0x148) -
`COOBBrowser::QueueRowChanged` inlined. **It tests nothing**: no owner, so it would rename any country's unit; no test for
an empty, unchanged, used or long name.

## 3. The panel side: `CUnitView`, the `unitname` box

`CUnitView` is the `unitpanel` window, made as the single panel's header (in_panel +0x30 = 1, by
`CSingleUnitPanel::Rebuild`) and as each row of the several-selected list (in_panel 0, by `CInGameIdler::AddUnitRow`).
With one unit selected **both exist**: the row is hidden.

### 3.1 Filling the box: `CUnitView::CUnitView` (0x769940), once

The `unitname` block, 0x769D40..0x769E4D, in order, *confirmed*: the box's layout (box +0x48) **SetText(the unit's name)**
by `CUnit::GetName`, slot 7 (0x5C47A0, a copy of +0x16C); EditBox_RefreshText; **max lines = 1** (`mov dword
[box+0xE4], 1`, layout +0x9C, at 0x769DD5); `CTextLayout_RefuseDoubleQuote`; CaretToTextStart (layout slot 36), the caret
to (0, 0); EditBox_RefreshText; and where in_panel is clear, **read-only** (box +0x159 = 1) - the row; the header stays
typeable.

Not there: **no scenario test** (a scan for game state `+0xd0c]` finds nothing in the constructor, the destructor or
Execute, and finds CBrigadeView's at 0x726BC2, the positive control - so the brigade card is locked in a scenario and the
unit name is not); no owner test; **no listener on the layout**, so Enter does nothing (*inferred*: no registration in the
block, as the edit-box reading found for `game_name`). **The box is never filled again**: the string `unitname`
(0x15D8568) has four references - two in the constructor, one in `CUnitView::BuildTooltip` (0x76B379) and one in the
destructor; `CUnitView::Update` never touches it.

**Who may type**: only the player's own units reach the panel, a foreign unit not being selectable (`FINDINGS-selection.md`,
A); with two or more selected the single panel is hidden every frame (`CSingleUnitPanel_Hide`) and every row's box is
read-only. So **a name can be typed only with exactly one unit, the player's own, selected**.

### 3.2 Sending it: `CUnitView::~CUnitView` (0x76D8C0, rva 0x36D8C0, `__stdcall`, `ret 4`)

Its only caller is slot 0 (0x76A180). *Confirmed*, read whole: (1) the row taken off the screen's kept-rows list
(+0x17C); (2) where the window exists: `text` = the box's raw text (layout slot 19), then `TrimWhitespace` - `\n`, `\t`,
`\r` and space off both ends; `old` = `CUnit::GetName(+0x28)`; **sent if and only if** `!String_Equals(old, text)` (exact
bytes, case-sensitive - a change of case is a rename) **and** `text` is not empty **and** in_panel is set; if sent, a
`CRenameUnitCommand(unit, text)` posted through the session (game state +0xBE8, GetSession slot 18, its +0x38's slot 6),
**then `CUnit_SetName(unit, text)` at once, locally** (0x76DB32), before the command has run on any machine; (3) the
window released, the leader panel at +0x34 destroyed, the bases run. The unit is the raw pointer +0x28, not re-resolved;
what happens if it was destroyed first was not read.

**When that happens** (`FINDINGS-selection.md` B.1, `FINDINGS-unitpanel.md`): **rebuild** - `CSingleUnitPanel::Rebuild`
empties the list when one unit is selected (AddUnitRow at count 1), when a deselection leaves one, and from
`CSingleUnitPanel_RefreshIfChanged` when its request byte is set or the number of units above, of battles shown or the
AI-agent state changes; **hide** - `CSingleUnitPanel_Hide` on RemoveUnitRow and every frame while the row count is not 1:
selecting another unit, Shift-adding a second, emptying the selection. *Inferred*: the list box's clear deletes its entries
through slot 0. So the name goes out when the player selects or deselects, or when the panel rebuilds on its own - a battle
beginning or ending for the unit, for one - in that last case mid-typing, the rebuilt box holding the new name and no longer
the keyboard (*inferred*: the gui drops a focus whose object is released). Clicking a button or the map does not take the
keyboard from a box (`FINDINGS-editbox.md`, section 2); Enter, focus loss and keystrokes send nothing. **A rename does not
rebuild the panel**: `CUnit_SetName` sets 0x1A855F6 around its Deselect/Select of a selected unit, and `CUnit::OnDeselected`
and `OnSelected` then skip RemoveUnitRow and AddUnitRow (section 4).

### 3.3 Two consequences of filling once (*inferred*, by composition)

- **The box is compared with the unit's name at the moment of destruction**: something else renaming the shown unit while
  its header is up (`CSetCommandLevel::Execute` renames by level, `CTransferSubUnitCommand::Execute` names a receiver whose
  name is under two characters) leaves the old text in the box, and **its destruction posts the old name back**, unless a
  rebuild came between.
- **A name the box cannot hold whole is renamed when the panel closes**: SetText goes through InsertText's fit loop
  (section 5) while max lines is still -1, so only the box's height applies, and a name wider than about two lines is cut
  and then posted as a rename, with no typing; a name with leading or trailing spaces is renamed to its trimmed form.
  Neither was provoked.

## 4. The register of names in use

`CCountry +0x84` holds, **by value**, a 0xC-byte string hash set (+0x90 is `nukes`): +0x84 the count, +0x88 the bucket
count (never changed by an insert), +0x8C the bucket array, each bucket a chain of 8-byte nodes {Hoi3CString*, next}.

- **`StringHashSet_Find`** (0xA86F70, rva 0x686F70), *confirmed*: h = 0, then for each byte (signed) h = (h + c) × 61;
  bucket = h mod the bucket count; answers the first stored string of the same length and bytes - **exact and
  case-sensitive**.
- **`StringHashSet_Insert`** (0xB4A2E0): a node at the bucket's head and the count up - **no test for an equal string**.
- **`StringHashSet_RemoveEntry`** (0x50F960): removes the node holding that exact string pointer.
- **`RegisterUnitName(country, name)`** (0xCB450): copies the name and inserts it, untested.
- **`UnregisterUnitName(country@EAX, name)`** (0xCB510): **while** Find finds an equal string, that entry is removed and its
  copy freed - **every** entry of the name leaves the set.

**`CUnit_SetName(unit@EDI, name)`** (0x5C48E0, rva 0x1C48E0), read whole: `UnregisterUnitName(owner by +0x128, the old
name)`; +0x16C = name; `RegisterUnitName(owner, name)`; it tests nothing; where the unit has a counter and
`show_unit_names` (settings +0xE9) is on, the counter gets the name (cut to 8 characters by CHoiAvatar_SetCounterName), or
`???` below intel 5; where the unit is selected (+4): `0x1A855F6` = 1, the screen's Deselect (slot 45) and Select (slot 38)
on it, then `0x1A855F6` = 0. `findRefs --address 0x1A855F6` gives four references: these two writes, and the reads at
0x5C0896 (OnSelected) and 0x5C0BAC (OnDeselected) - the positive control, the only ones the record knew.

**What follows** (*confirmed* as mechanism, the consequences *inferred*): names need not be unique, within a country or
across countries; units, brigades, ships and wings share one set per country (`CSubUnit_SetName` and
`CRenameSubUnitCommand::Execute` use the same Register/Unregister); renaming away from a shared name clears it for
everyone - with two "1st Army" and one renamed, the set no longer holds "1st Army" while the other bears it, and
`CCountry::MakeUnitName`, whose only uniqueness test is Find on this set, may make it again; the old name is freed for
reuse; the local SetName before Execute leaves the set's membership the same on every machine; but it is a change outside
the command, so a command dropped by the gate leaves the local machine with the new name and the others without it.

**Other renamers**, as they bear on the register - each through CUnit_SetName: CMilitaryConstruction::Deliver,
CreateRebelsForFaction, ReleaseProvinces, CCreateUnitCommand::Execute, CAirReserveOrder_ReinforceUnit, CUnit::LoadKey,
CTransferSubUnitCommand::Execute, CCreateHigherCommand::Execute (twice), CCreateNewHQCommand::Execute (twice),
CSetCommandLevel::Execute, CUnitSplitCommand_TakeSubUnit, CUnitSplitCommand_MakeUnit, CAddSubUnitEffect::Execute,
CAddDivisionEffect::Execute, and one site at 0x65B970 not attributed - 19 call sites, each read only as far as the call.

## 5. What can be typed into `unitname`

| rule | value | source |
| --- | --- | --- |
| Tab | refused | [exe] |
| `"` | refused by the layout's list (`CTextLayout_RefuseDoubleQuote`) | [exe] |
| `"` `§` `¤` `£` `@` `{` `}` | refused, the box's font `Arial12_bold` having `effect` at its default, yes | the bytes [exe]; whether they apply [mod: the font's `effect` in `interface/core.gfx`] |
| other bytes, Escape's 0x1B among them | go in | [exe] |
| length | 250 bytes | [exe], every edit box |
| **one laid-out line** | below | the cap [exe]; the width [mod: `unitpanel.gui`, the font] |

**The one-line cap**, *confirmed* in the bytes, its consequence *inferred*, correcting the record. `CTextLayout::InsertText`
(0xACC600) ends with a loop: where layout +0x9A is clear and the area height is not 0, **Backspace runs while (lines − 1) >
area height ÷ the font's line height** (doubles), **or** max lines is not −1 and lines > max lines, lines counting the
wrap's breaks. The layout's own constructor sets +0x9A, but **every edit box's constructor clears it** (`mov byte
[esi+0xE2], bl` at 0xA8F528, EBX zeroed at 0xA8F1AD). `unitname` has max lines 1, and a line wraps where its width plus one
`O` exceeds the inner width (BuildLines, as recorded): so a character that would make the name wrap is erased again as soon
as it is typed, Backspace taking the byte before the caret, the one just inserted. TFH: the box (`tfh/interface/unitpanel.gui`)
is 235 × 24 with `borderSize` 8, 4, so the inner area 219 × 16 (*inferred*: size less twice the border); `Arial12_bold` has
`lineHeight` 14 and `O`'s advance 8; so a name stops at about 211 px of text, around 30-35 characters (*inferred*, not
measured).

**Typing into a name already too wide** (*inferred*): the constructor's SetText runs before max lines is set, so a two-line
name survives it (16 ÷ 14 ≥ 1), the caret at (0, 0); the first character typed goes in at the start and is backspaced off,
and Backspace at (0, 0) erases the byte **after** the caret, so the loop eats the name **from its front** until it fits one
line. The brigade card's `subunit_name` box has no such cap: the same scan finds the store in CUnitView at 0x769DD5 and
nowhere in CBrigadeView's block.

## 6. Corrections to other write-ups

- `FINDINGS-editbox.md` section 4 gains the line cap beside the 250 (done there); its section 6 picture of a box showing
  "the line the caret is on" after a wrap holds only where the box's height lets a second line in.
- `FINDINGS-selection.md`: `0x1A855F6` has two readers and two writers, both writers in `CUnit_SetName` (done there).
- A trap-2 variant: `image.functionStart(0x76DB32)` answers 0x76D9D3 - the byte 0x76D9D2 is the 0xCC disp8 of
  `mov ecx, [ebp-0x34]`, read as padding; `retsBefore(0x76D8C0, 0x76DB32)` is empty and the true start is 0x76D8C0.

## 7. Not read

What happens if the unit is gone when its header is destroyed (the raw +0x28 is used); who sets `CSingleUnitPanel`'s
request byte; whether the list box's clear is what deletes the entries; the third caller of `StringHashSet_Insert`, the
second of `RemoveEntry` (0xB49510), and the call site at 0x65B970. Nothing was run against the game.

## 8. Hardcoded or mod-able

| rule | |
| --- | --- |
| sent only when the header is destroyed; trim set `\n\t\r` and space; exact-byte compare; not empty; single panel only | exe |
| local rename at once plus the command | exe |
| command, CUnit_SetName and register test nothing; no uniqueness | exe |
| register per country, shared with brigades; unregister removes all; case-sensitive | exe |
| no scenario lock for unit names (the brigade card has one) | exe |
| `"` refused; Tab refused; 250 bytes; max lines 1 | exe |
| `§ ¤ £ @ { }` refused | the bytes exe; mod-able by the font's `effect = no` in `core.gfx` |
| how much fits on the one line | mod: `unitpanel.gui` box `size` and `borderSize`, the font (`.fnt` advances and lineHeight) |
| the counter's name cut to 8 characters, `???` below intel 5 | exe; shown only with the player's `show_unit_names` |

In the record through `fragments/merged/unit-rename-2026-11-12.json`.
