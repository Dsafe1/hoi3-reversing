# The file checksum, 2026-11-13

What `CEU3Application::CreateChecksum` (`0x232DA0`) sums, how, and how the four letters on the main menu come from it.
Read statically - decompiled on a copy of the project, each helper's receiver taken off the listing - and **checked
against the original's own figure**: every run writes `Checksum is HoI3 v4.02 (GSKH)    1499173604` to the user folder's
`logs/setup.log`, and `scripts/checksum.py`, a model of what follows, gives that figure to the unit. Addresses are rvas
unless marked VA, and valid only for this build.

This corrects `FINDINGS-startup.md`, section 8, whose list was the strings near the function and not its calls: it left
out `events`, `missions`, `technologies`, `decisions`, `common/*.txt` and every `.lua` folder, and said `common/*.txt` is
not covered. It is.

## 1. The result (confirmed)

| | figure | letters | files | set against |
| --- | --- | --- | --- | --- |
| Their Finest Hour, no mod | 1,499,173,604 | GSKH | 11,824 | `Hearts of Iron III/logs/setup.log`, written 2026-11-13 |
| BlackICE 15.1 | -410,340,735 | ZAUD | 14,177 | `Hearts of Iron III/BlackICE 15.1/logs/setup.log`, written 2026-11-09, no file of the mod newer |

Both agree exactly. The other three BlackICE folders' logs (16.0, 16.1, GitHub) are older than their files and were not
used; their letters still agree with their figures through section 4's formula.

## 2. Where the sum goes

The application holds a **`CVersion`** at `+0x20` (RTTI; a `CPersistent`, token `0x18D`), made by `CApplication`'s
constructor (VA `0xA909FB`) with the version name `HoI3 v4.02` (VA `0x15CC4A0`). It is a persistent block of four keys
(`CVersion::LoadKey` `0x6B45E0`, `CVersion::SaveContents` `0x6B4510`):

| offset | key | |
| --- | --- | --- |
| +0x8 | `minValue` | a fixed-point, written only above nought; what it bounds was not read |
| +0xC | `executable` | nought in every run logged; nothing in the startup path sets it |
| +0x10 | `data` | **the file checksum** |
| +0x14 | `name` | `HoI3 v4.02` |

Every term below is a 32-bit add into `data`, so **the order files are met in does not matter**. A savegame holds no
`CVersion`. That the block is what peers compare in multiplayer is *inferred* from its being persistent; the six callers
of `MakeVersion` (`0x6B3C90`) and the other places its vftable is written were not read.

## 3. What is summed, in order (confirmed)

`CVersion::ChecksumFolder(directory, extension, recurse)` (`0x6B3E00`, `__thiscall`, `ret 0xC`) adds every file of a
folder: `ListFilesWithExtension` - the whole search path, each name once, the extension a byte compare of the name's tail,
case and all; directories and names with a byte of 0x80 or more left out; in a folder a `.mod`'s `replace_path` names,
only what the mod's mounts hold (`FINDINGS-ingamemenu.md`, C.2) - and each name but `.`, `..` and `.svn` is read whole
through `ChecksumFile` as `directory/name`. With `recurse`, `ListSubdirectories` (`0x66BA00`) and the same on each
subfolder but those three names.

For each folder the path registry (`g_CDirectorySettings`) gives a mode: the base folder is summed where the mode is not 1,
its override folder (the registry's second block) where it is not 0. The overrides were empty in every run read; a mod
enters through the search path instead.

1. `common` `.lua`, `common` `.txt`, `common/countries` `.txt`
2. `events`, `missions` (`.txt`)
3. `units` `.txt`, `units/models` `.txt`, then `units` `.lua`, `units/country` `.lua`
4. `technologies`, `decisions`
5. `history/countries`, `diplomacy`, **`provinces` with its subfolders**, `wars`, `leaders`, `units`
6. `map/default.map`, `map/cache/time`, `map/cache/adjacencies.bin`, each through `ChecksumFile` alone (the map override's
   where its mode says)
7. `cgm` `.txt` with subfolders; `battleplans` `.txt` and `.pln` with subfolders
8. **the version name**: `ChecksumString` (`0x6B3DB0`) over `HoI3 v4.02`

A file's checksum is `CBinaryStream::Checksum` (`0x66D300`): two sums from nought over the bytes **unsigned**, each brought
back by subtracting 65,535 once when it passes 65,535, answered as `(a << 16) | b` - the map cache's stamp's sum
(`FINDINGS-mapbuild.md`). `ChecksumString` is the same over a string's bytes **signed** (`movsx`); the version name is
plain ASCII, so it makes no difference there. A file that does not exist adds nought.

**The search path** decides which copy of a name is read: with a mod, its user folder and the mod, then `tfh/`, then the
install, then the Documents folder (`FINDINGS-luahost.md`, section 2; the user folder's place *inferred*). The map cache
lives in the Documents folder - the base game's in `Hearts of Iron III/map/cache`, a mod's in its own user folder - so
**the checksum takes in the cache the original built**, through `time` and `adjacencies.bin`.

**Not covered**: `interface`, `gfx`, `localisation`, `script` (the AI's Lua), `sound`, `music`, `scenarios`, every map file
but the three, and `common`'s subfolders but `countries`. Two players may differ in all of those and match.

## 4. The label (confirmed)

`CVersion_GetLabel` (`0x6B42F0`, `__stdcall`, `ret 8`) writes the name, ` (`, four letters and `)`. With
`v = executable + data` as a signed 32-bit figure, the letters are `v`, `v >> 4`, `v >> 8` and `v >> 12` (arithmetic
shifts), each C's remainder by 26 made positive (`abs(x % 26)`), added to `A`. All five logged figures give their logged
letters. `FINDINGS-frontend.md`, A.1, has the main menu's `version_label` and the lobby's `checksum` label carrying this
text; its "mod 26" is this.

## 5. What is weak about it

For a multiplayer guard these are holes, kept here so a reimplementation can decide on them knowingly:

- **A sum of sums.** Exchanging two files' contents, moving a file between two summed folders, or renaming it within one,
  changes nothing; nor does adding an empty file (its checksum is nought) or anything outside the list in section 3.
- **A Fletcher sum per file**, 32 bits with a modulus of 65,535, and then the whole held in 32 bits: two different
  installs agreeing by chance is far likelier than with a cryptographic hash.
- **It is made once, at startup, over the files as they are then**, taking about 7 s for the base game and 10 to 27 s for
  BlackICE in the logs.

## 6. Recorded

`project.json`, from `fragments/merged/file-checksum.json`: `CEU3Application::CreateChecksum` revised (the whole list,
where the sum goes), `CVersion::ChecksumFolder`, `ChecksumString`, `CVersion_GetLabel`, `ListSubdirectories` and
`MakeVersion` (inferred) new; the struct `CVersion` with its four fields, and `CEU3Application +0x20 version`.
