# How the localisation tables are read, and which of a key's texts stands

Read out of the executable on 2026-11-19, for an OpenHOI3 bug: BlackICE's events that give a technology progress
showed "Gain Tech." where the original names the technology and the amount. BlackICE's `zDD-tech.csv` gives
`TECH_INVEST` twice - `$TECH$ $DIRECTION$ $VALUE$`, then `Gain Tech.\n` - and the rebuild kept the last. Addresses are
**rvas** against an image base of `0x400000` (trap 1) where a name is given, and virtual addresses where they say VA.

## 1. Every table is read as one text

In `WinMain` (`0x656470`), VA `0xA590FF`-`0xA59646`:

1. `ListFilesWithExtension(<folder>, list, ".csv")` (`0x66BCB0`) twice - a directory slot's base folder and its override
   (VA `0xA59118`, `0xA59162`); the second list keeps only names the first lacks (`std::find`, `0x394A40`). Nothing in
   this build sets the override, so the second is empty (the record's `ListFilesWithExtension`).
2. A vector of full paths: the second list's names with their folder, then the first's (VA `0xA59230`-`0xA593FA`).
3. For each path, in order: the file is opened (`VirtualFile_Open`, `0x66C1B0`), read whole through its slot 2, and
   **appended to one buffer** (`0x6BA620`), with a `\n` appended after it where its last byte is not one
   (VA `0xA595AE`-`0xA59608`).
4. `0xA86A20 (VA)` - `LoadTextTablesFromBuffer` - with the buffer (VA `0xA59783`): it logs, makes a 0x54-byte table with
   `TextTable_Construct` (`0x6862B0`, VA `0xA86C3A`) and puts it in the global at VA `0x1B16684`, destroying the one
   before with `TextTable_Destroy` (`0x6868C0`).

So **the order of the files is the order they are listed in**, and a key given in two files is settled by the same
rule as one given twice in a file.

## 2. The first text stands

`TextTable_Construct`'s loop over the buffer's lines (`internationalizedtext.cpp`; VA `0xA864CA`-`0xA867E1`):

    a line whose key begins with '#'  -> the comment path (VA 0xA864EF)
    entry = find or make the key's entry                                      ; 0x686DA0, VA 0xA8654E
    if the longest of the entry's texts is above nought:                      ; VA 0xA86555-0xA8657B
        log 'Duplicate text-key "<key>".'  and take the next line             ; VA 0xA865BE, jmp 0xA867E1
    text = the line's column for the language ([ebp-0x34]) where it has that many,
           else the line's field at +0x20                                     ; VA 0xA8665C-0xA8666E
    "\n" in it turned into a line break as it is copied                       ; VA 0xA8668E-0xA866A6
    empty  -> log 'Empty key "<key>" found.'                                  ; VA 0xA8672C
    else   -> stored on the entry                                             ; 0x684A40, VA 0xA8671A

**A key keeps the first non-empty text it is given in the language read; every later line of it is logged as a
duplicate and dropped.** A line with no text in that language gives none, so a placeholder `KEY;;;...;x` - the `x`
column notwithstanding - leaves the key to a later line. *Not read*: what the line's `+0x20` field is (very likely the
English, for a line too short for the language), how `0x686DA0` hashes a key, and where the two logs go - no log of the
player's has either line.

## 3. PhysFS lists a folder's names sorted by byte

`ListFilesWithExtension`'s names come from `PHYSFS_enumerateFiles` (`0x785900`, VA `0xA6BE02`): a list allocated, then
`PHYSFS_enumerateFilesCallback` (`0x7848B0`) with `enumStringListCallback` (`0x783740`). That callback asks
`findInStringList` (`0x7836B0`) and **drops a name already listed**, else inserts it at the position found, moving the
rest along (`memmove`, VA `0xB837E5`). `findInStringList` is a binary search with an **inlined `strcmp`** - byte by byte,
unsigned (`sbb eax, eax; sbb eax, -1`), case and all - returning 1 where the name is there and the insertion position
otherwise (VA `0xB836C7`-`0xB8373A`).

So a folder is listed as **every name over the whole search path once, sorted by byte with case**, each read from its
frontmost copy - not layer by layer. With section 2, of two tables giving one key the one whose name sorts first gives
its text, whichever layer either is in.

## 4. What it changes

- BlackICE's `TECH_INVEST` is its first line, `$TECH$ $DIRECTION$ $VALUE$`: an event giving a technology progress names
  it and the amount, as seen in the running original.
- Over BlackICE's 132 tables, 130 keys are given more than once with text and 101 of them with different English: ship
  names, decision titles, flag texts. Over Their Finest Hour's 45, 4 keys more than once and none with different
  English. Neither install has a key given in two layers' tables under different names whose first text depends on the
  layer order - BlackICE replaces the whole folder, so all its tables are one layer.
