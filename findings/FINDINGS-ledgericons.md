# The building ledger's icons, and the crash a missing one causes

*2026-11-04. Read in the collecting session from a crash the maintainer had clicking through
the statistics ledger with BlackICE's new `extra_infra` building in `common/buildings.txt`.*

## Synopsis

The ledger's building page makes **one column for every building**, and heads each with an
icon instantiated from a gui type named `<building>_icon`. The function that instantiates it
never checks the lookup: a building whose `<name>_icon` is not declared as an `iconType`
anywhere in the interface files crashes the game with a read of `0x9C`, the moment the page
is opened. `visibility = no` does not keep a building off the page. `confirmed`, off the
bytes and off the crash's own memory.

## 1. The crash

`BiceLibCrash_011` (2026-11-04 14:03): access violation **reading `0x0000009C`** at rva
`0x6C857E`, with the overlay closed, so the exception was the game's own. Windows' full
dump of the same crash was beside it. The stack from `esp`, return addresses only:

    0x6C8560  IconType_CreateIcon      <- faults on its first real instruction
    0x67CDAA  CEU3Gui::CreateIcon       (CEU3Gui slot 31)
    0x3920CA  CGraphicalTableLedger::CGraphicalTableLedger
    0x3A0426  LedgerPage_Buildings      (ledger page 7)
    0x3C21E5  LedgerPage_Update

`CEU3Gui::CreateIcon`'s first argument read out of the full dump is an `Hoi3CString`
holding **`extra_infra_icon`** - length 16, capacity 31, on the heap. That settles which
name failed without relying on the reading below.

## 2. Why it crashes

- **`LedgerPage_Buildings`** (`0x39F500`, page 7, `LEDGER_BUILDING_TITLE`) walks the
  building database. For each building it asks slot 8 (`+0x20`), and if that answers true
  it builds the string `name + "_icon"` from `CBuilding +0x1C` and adds a column with it
  (`0x7BEB80`, the column adder of `FINDINGS-uinumbers2.md` section 2). **`CBuilding`'s
  slot 8 is the shared `mov al, 1; ret`** (`0xA92590`, in 440 tables), so every building
  gets a column. `visibility`, `onmap` and `show_for_province` do not enter into it.
- It then constructs the page's **`CGraphicalTableLedger`** (`0x391970`, vftable
  `0x15DB474`, the string `GraphicalTableLedger` at `+0x54`). For each of the columns
  with the byte at `+0x38` set it calls the gui's slot 31 with the column's string at
  `+0x1C`.
- **`CEU3Gui::CreateIcon`** (`0x67CD60`, slot 31, `ret 8`) looks the name up through slot
  1 of the gui-type registry at `+0x34`, the same lookup as `CEU3Gui::GetGuiType` (slot
  18), which returns null on a miss. It passes the result straight to
  **`IconType_CreateIcon`** (`0x6C8560`) in `ESI` with **no test**.
- `IconType_CreateIcon` opens with `cmp byte [esi+0x9C], 0`, which picks one of two
  0xF0-byte objects, and reads the type's `+0x64`, `+0x68`, `+0x6C`, `+0x88`..`+0xAC`.
  With `ESI` null the first read is address `0x9C`, which is the reported fault address.

The type is an `iconType` by inference. The function sits just after the `iconType`
loader at `0x6C81F0` (`FINDINGS-guicontainers.md`), the failing name is the
`<building>_icon` form, and BlackICE declares all 59 of the others as `iconType` in
`interface/hoi3ledgericons.gui`. Where the type is declared does not matter as long as it
is a gui type the registry holds. What would show this wrong is an `iconType` named
`extra_infra_icon` that still crashes.

## 3. What it means for content

**Every entry in `common/buildings.txt` needs an `iconType` named `<name>_icon`**, or the
building ledger page crashes as it opens. Whether the building is visible makes no
difference. It is hardcoded in the executable; only the icon declarations can be modded.
BlackICE's fix was one `iconType` for `extra_infra`, using `GFX_provinceview_infra`.

For OpenHOI3 the rule is the same, and the original's failure is a crash. Report a
missing icon instead.

## Not established

- What the byte at `CGraphicalTableLedger`'s column `+0x38` means. Every building
  column reached the call, so it was set for these.
- The second argument of slot 31 (`CGraphicalTableLedger +0x114`), and what the two
  objects `IconType_CreateIcon` chooses between on `+0x9C` are.
- The other pages that call slot 31 (`0x7C` on the gui) were not surveyed; any page that
  names an icon after a database entry has the same weakness.
