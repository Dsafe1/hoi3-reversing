# How hoi3_tfh.exe is told to play a mod, and how it lays it over the install

*Read out of the executable on 2026-11-16, statically, for OpenHOI3's mod layer; fragment
`fragments/merged/mod-layer-startup.json`. Addresses are VAs (image base `0x400000`) unless marked rva. The split at `-`,
the user folder's mount and write directory, and the replace test's table read, search-path walk and `strstr` were
checked off the listing by the collecting session.*

**Synopsis.** `WinMain` (rva `0x656470`) cuts the command line at every `-`, takes `mod=` values naming a descriptor as
`mod/<file>.mod`, and sets up PhysFS twice: a first search path to find the descriptors, torn down by `PHYSFS_deinit`, and
a second with the selected mods. **With a mod the search order is the mod's user folder (`<Documents game folder>/<user_dir>`),
the mod's `path`, `tfh`, the install root - the plain Documents folder is not mounted at all.** `replace_path` lives in a
table of its own that **only `ListFilesWithExtension` reads**: an exact, case-sensitive folder match that covers no
subfolder, and a file opened by name still falls through to `tfh/` and the install. The old-style descriptor reader,
`CDirectorySettings::LoadKey`, is never run in this build.

## Rules, for a reimplementation

Everything here is fixed in the executable; only the contents of `.mod` files are moddable.

**The command line** (confirmed)
- The command line arrives with the program name removed, is cut at **every `-`**, and the piece before the first `-` is
  dropped. Each piece is trimmed of space, tab, CR and LF - **quotes are not removed** - and compared case-sensitively.
- Prefixed switches, the value being the rest of the piece (an empty value is ignored; a single-valued switch keeps its last
  occurrence): `threads=N`, `logpostfix=X` (`logs/<name>_X.log`), `settings=NAME` (the settings file's name),
  `exclude_dlc=V` (repeatable), `mod=V` (repeatable, trimmed), `userdir=PATH` (as given: no full path made, no folder
  created). Whole-piece switches: `noasserts`, `randomlog`, `dlcmod`. Anything else is ignored.
- **A `-` inside a value cuts it**, so a mod's file name or a user folder holding `-` cannot be passed.
- `tfh` is not a switch: it is the relative folder mounted unconditionally.
- `-dlcmod` mounts stage one, writes `DLC:\n<lines>Mod:\n<name>|mod/<file>.mod\n` to the parent console, and returns 0
  without starting the game.
- A `mod=` value is compared byte for byte, case and all, with a descriptor's file path `mod/<file>.mod` - the virtual
  folder `mod` and the bare file name, never `tfh/...` nor an absolute path. The descriptors are `mod/*.mod` over stage
  one's search path: the Documents game folder, `tfh/`, the install root - so `tfh/mod` and the install's own `mod`.
- *Likely* (the executable's side confirmed, the launcher's IL not decompiled): the launcher passes
  `hoi3_tfh.exe -mod=mod/BlackICE GitHub.mod`, and ` -exclude_dlc=<dlc file>` for each DLC left unticked - it holds the
  strings `-dlcmod`, `DLC:`, `Mod:` and ` -mod=` and re-uses the text after `|`. The running process's command line would
  settle it.
- No descriptor matching (missing, misspelled, another case, a `-` in the name): nothing is mounted and no user folder set -
  **the game runs as plain Their Finest Hour with the plain Documents folder**, with no error. A descriptor that cannot be
  read or is invalid (no `name`, or neither `path` nor `archive`) is logged `Incorrect MOD descriptor: "<file>"` and
  skipped, to the same end. *Likely*: a `path` that does not exist mounts nothing (the mount's answer is ignored), but its
  `user_dir` still applies.
- The old `-mod <file>` form, with a space, is worked out (`ReadOldStyleModSwitch`, rva `0x656320`) and never used.

**The `.mod` file** (confirmed)
- Read by `CModDescriptor::LoadKey` (rva `0x6AD5F0`, `dlc.cpp`; `.dlc` files share it), not the old-style reader.
- Keys: `name` (required; the key of the map, and what `dependencies` and the tie-break use), `path` (the folder, mounted
  as written, relative to the process's current directory - *inferred* from PhysFS 2.0.2; the image imports no
  SetCurrentDirectory and the launcher starts the game in the install), `archive` (preferred over `path`), `user_dir`,
  `replace_path` (each line appended), `dependencies = { "name" ... }`, `checksum` and `affects_checksum` (no reader
  looked for), `steam_id`, `pdx_id`, `gamersgate_id` (a DLC's store ids).
- Any other key, `replace` and `extend` among them, is dropped without a log. A repeated string key keeps its last value.
  Two descriptors of one `name`: the first listed is kept.

**The mounts** (confirmed). Every mount is PhysFS 2.0.2 `PHYSFS_mount(dir, NULL, 0)`, which prepends: the last mounted is
searched first.
- Stage one: the base directory, `"tfh"`, then the user folder in front, made the write directory. The user folder is
  `userdir.txt`'s, else `Documents\Paradox Interactive\Hearts of Iron III`, with `-userdir=` over either. The descriptors
  are listed now.
- `PHYSFS_deinit` throws stage one away.
- Stage two: the base directory, `tfh`, then the selected DLCs and mods - a DLC at order 0, a mod at -1000, each
  dependency's order raised above its dependent's until nothing changes (a cycle never ends), sorted by order descending
  and ties by name byte-greater first, mounted in that order, so the lowest order and the smallest name end frontmost.
  Last the user folder, in front and the write directory: the stage-one folder where no selected descriptor has a
  `user_dir`, else `<stage-one folder>/<the user_dirs joined with "_">`, made with CreateDirectoryW (the leaf alone).
- With BlackICE: `...\Hearts of Iron III/BlackICE GitHub`, `tfh/mod/BlackICE GitHub`, `tfh`, `<install>\`. Without a mod:
  the Documents game folder, `tfh`, `<install>\`. `-dlcmod` changes no mount; it ends the program after stage one.

**`replace_path`** (confirmed)
- Honoured **only by `ListFilesWithExtension`**, the one reader of its table. `ListSubdirectories` has no test, and
  opening a file by name (`VirtualFile_Open`, `PHYSFS_exists`, `PHYSFS_openRead`) never asks it - so a file opened by name
  in a replaced folder, `map/default.map` or a named `common/*.txt`, **falls through to `tfh/` and then the install** where
  the mod lacks it.
- An entry applies where its `replace_path` equals the folder listed exactly: `strcmp`, case-sensitive, a trailing `/`
  significant; `\` is turned to `/` in the `replace_path` and in the mount directory, and nothing else is normalised.
  **No subfolder is covered**: `history/provinces` does not cover `history/provinces/africa` - the history loader lists the
  subfolders without the test and then lists each as `history/provinces/<name>`, which is why BlackICE names every base
  subfolder; its own files are in `bice_*` subfolders.
- Where entries apply, the limit is the smallest search-path index of their mount directories, and a listed file is kept
  only if `strstr(PHYSFS_getRealDir(dir/name), searchPath[i])` holds for some i up to the limit - its first copy is in the
  replacing mod or in front of it. **The user folder, at index 0, always counts.**
- *Likely*: a mod `path` written with backslashes never matches its search-path entry, which PhysFS keeps as mounted, so
  its `replace_path` lines silently do nothing.

**What else a mod changes**
- Confirmed: writes go to the write directory and make their parent folders: saves (`save games/`), the logs
  (`setup.log`, the checksum's, among them), `settings.txt`, the map cache. With a mod that is the mod's user folder.
- Confirmed: reads go over the search path. With a mod `settings.txt` is read from the mod's user folder, then the mod's
  folder, `tfh/` and the install root (which has one); the plain Documents folder's is never read. *Likely* the same for
  `map/cache/*`, so a mod could ship a cache in its folder.
- Confirmed: the save list is `ListFilesWithExtension("save games/")` over the whole search path, so the install's own
  `save games` folder is listed too.

## 1. WinMain and the command line (confirmed)

`WinMain` (rva `0x656470`, `__stdcall`, `ret 0x10` at `0xA5709D` and `0xA5A2E5`) is called by the CRT at `0xB9882F` with
`_wincmdln`'s answer. `String_Split` (rva `0x65B520`) cuts lpCmdLine at every `-` (`push 0x2d` at `0xA564D6`); the loop
starts at index 1. Each piece goes through TrimWhitespace (`\n\t\r ` only) and the compares:

| piece | effect | where |
| --- | --- | --- |
| `threads=N` | atoi into `g_ThreadCount` (rva `0x130ABB0`, default -1) | `0xA566E3` |
| `logpostfix=X` | `g_LogPostfix` (rva `0x1310D60`); logs become `logs/<name>_X.log` | `0xA56802` |
| `settings=NAME` | the settings file's name (GameSettings `+0xC0`) | `0xA56927`, used `0xA58E3A` |
| `exclude_dlc=V` | trimmed, collected | `0xA56A5E` |
| `mod=V` | trimmed, collected | `0xA56B86` |
| `noasserts` (whole) | `g_AssertsEnabled` = 0 later | `0xA56C2C`, `0xA5A102` |
| `randomlog` (whole) | `g_log_command_execution` = 1 | `0xA56C7A` |
| `userdir=PATH` | the user folder, as given | `0xA56D3F` |
| `dlcmod` (whole) | list the descriptors to the console and exit | `0xA56DA9` |

A prefixed switch needs `piece.length > prefix.length`; the value is `substr(prefix length, end)`. Each switch string has one
reference in `.text`. GetCommandLineA has two users, the CRT and `ReadOldStyleModSwitch` (rva `0x656320`), which does
`strstr(cmdline, "-mod ")`; its answer, the local at `ebp-0x154`, is only passed in and freed (`0xA58E86`, `0xA59DC3`, the
unwind at `0xA5A26D`).

## 2. Stage one (`0xA56DE0`-`0xA56EF8`, confirmed)

1. `PHYSFS_init(NULL)`; `PHYSFS_mount(PHYSFS_getBaseDir(), NULL, 0)`; the same again (a no-op: PhysFS 2.0.2 answers 1 for a
   directory already mounted); `PHYSFS_mount("tfh", NULL, 0)`. `g_PhysfsSearchPath` is refreshed after each.
2. The user folder: `ReadUserDirTxt` (rva `0x66ADB0`) - where `PHYSFS_exists("userdir.txt")`, at most 511 bytes read and
   trimmed; not empty, CreateDirectoryW, ERROR_PATH_NOT_FOUND showing `Could not create or read directory: <path>` and
   exit(0); the answer GetFullPathNameW of it. Empty, `GetDefaultUserDir` gives `<My Documents>\Paradox Interactive\Hearts
   of Iron III`. A `-userdir=` value replaces either.
3. `PHYSFS_mount(userdir, NULL, 0)` (`0xA56EDA`) and `PHYSFS_setWriteDir(userdir)` (`0xA56EE0`).
4. `GetDlcModSettings` (rva `0x6AD8C0`, a singleton of 0xB0 bytes) and `DlcModSettings_Scan` (rva `0x6ADE70`); section 4.
5. With `-dlcmod`: `DlcModSettings_ListForLauncher` (rva `0x6AF7F0`) builds `DLC:\n`, a line per DLC, `Mod:\n` and
   `<name>|mod/<file>.mod\n` a mod, written through AttachConsole(-1), GetStdHandle(-11) and WriteFile; WinMain returns 0.

## 3. Stage two (`0xA570A0`-`0xA57303`, confirmed)

1. `DlcModSettings_VerifySignatures` (rva `0x6AF210`, `dlc_signature`; only its first part read), then `SetTestDlcFlags`
   (rva `0x5D0F0`; its two bytes have no reader).
2. **`Physfs_Shutdown`** (rva `0x66B310`): PHYSFS_freeList of the cached list, `g_ReplacePathTable` emptied,
   **PHYSFS_deinit**. Stage one's mounts and write directory are gone.
3. `PHYSFS_init`; mount(getBaseDir); mount("tfh").
4. The `exclude_dlc` values copied to settings `+0x38` and the `mod` values to `+0x48`.
5. `DlcModSettings_MountSelected` (rva `0x6AD930`); section 5.
6. Settings `+0x74` (the joined user_dirs) empty: the user folder is stage one's string. Otherwise `userdir + "/" +
   user_dir`, or the user_dir alone where userdir is empty, made by `CreateDirectoryOrExit` (rva `0x66B0D0`: the leaf only;
   ERROR_PATH_NOT_FOUND the same box and exit), mounted in front (`0xA572FD`) and made the write directory (`0xA57303`).
   Neither mount's answer is tested.

Then the TBB scheduler, the two intro movies (unconditional), the logs (VirtualFile_Open under the write directory),
`settings.txt` (`0xAB1E80` at `0xA58E7C`, `PHYSFS_exists` and VirtualFile_Open over the search path) and the
CDirectorySettings singleton (`0x44B9C0`). `tfh` and the mod's path are relative and resolve against the process's current
directory (*inferred*, PhysFS 2.0.2's DIR archiver).

## 4. The descriptor (confirmed)

`DlcModSettings_Scan` sets settings `+0` to `dlc` and `+0x1C` to `mod`, empties the two maps, and calls
`ListFilesWithExtension("dlc", ".dlc")` and `("mod", ".mod")` over stage one's path - the Documents game folder, `tfh/mod`
and `<install>\mod`, where the base game's old descriptors are. Each file is loaded into a 0x100-byte `CModDescriptor`
(constructor rva `0x6AD1D0`, table VA `0x1600BBC`, no RTTI locator; slot 3 `CPersistent::Load`, slot 4 `LoadKey`) through a
Tokenizer on `<folder>/<file>`, the path kept at `+0x24`.

**`CModDescriptor::LoadKey`** (rva `0x6AD5F0`), token ids from `ghidra/saveTokens.json`:

| key | token | field |
| --- | --- | --- |
| `name` | 0x1A | +0x08 |
| `path` | 0x19C | +0x40 |
| `archive` | 0x1A0 | +0x5C |
| `dependencies` | 0x19D | +0x78, a `{ }` block |
| `replace_path` | 0x1A8 | +0x88, appended |
| `user_dir` | 0x1A9 | +0x98 |
| `checksum` | 0x1A1 | +0xB4 |
| `affects_checksum` | 0x1A2 | +0xD0, default yes |
| `steam_id` | 0x19E | +0xD8, kind 1 |
| `pdx_id` | 0x19F | +0xE0, kind 2 |
| `gamersgate_id` | 0x1A7 | +0xDC, kind 3 |

Anything else goes to ReportUnknownKey, which logs nothing. A `.mod` is then given kind (`+0xD4`) 4 and kept where `name`
is not empty and `archive` or `path` is not; a DLC needs as well kind 1 to 4 with that kind's id (jump table `0xAAE840`).
A kept descriptor goes into a `std::map` keyed by `name`, a second of one name dropped; a refused one is logged
`Incorrect MOD descriptor: "<file>"` (`dlc.cpp`:350) or `Incorrect DLC descriptor: "<file>"` (`dlc.cpp`:328). **The base
game's `Dies_irae_*.mod`** (`name`, `extend`, `replace`) are refused under `hoi3_tfh.exe`.

## 5. Selection, order, mounts and `replace_path` (confirmed)

`DlcModSettings_MountSelected`:
1. A list of {order, descriptor}: each DLC with `+0xFC` set whose file path is not an `exclude_dlc` value, at 0; each mod
   whose file path equals a `mod=` value byte for byte, at -1000 (`0xFFFFFC18`).
2. Passes until nothing changes: for each entry and each of its `dependencies` names, every entry of that `name` with an
   order no higher than the dependent's is raised by 1. A dependency not selected is not added; a cycle never ends.
3. `MountList_Sort` (rva `0x6B0790`, comparator in `0xAB12B0`): order descending, ties by `name` byte-greater first; not
   stable.
4. In that order, `PHYSFS_mount(archive or path, NULL, 0)`, the answer ignored, the list refreshed.
5. `+0x74` = the user_dirs in that order joined with `_`.
6. For each entry and each `replace_path`, `RegisterReplacePath(archive or path, line)` (rva `0x66B910`): `\` to `/` in
   both, a 0x38-byte record appended to `g_ReplacePathTable` (VA `0x1B165D4`).

## 6. Where `replace_path` reaches (confirmed)

**`ListFilesWithExtension`** (rva `0x66BCB0`) is the table's only reader: every reference to its three words is in the
vector's own code (`0xA6AD60`, `0xA6D410`, `0xA6D4E0`, `0xA6D5C0`, `0xA6D6F0`) or in this function (the table read at
`0xA6BCFE`), and the same scan finds this function (positive control). `PHYSFS_enumerateFiles` has two callers outside
PhysFS, this function and `ListSubdirectories`, which has no table test.

The test: the limit is the least, over records whose `replace_path` equals `directory` (strcmp), of the index of the
record's `mount_dir` in `g_PhysfsSearchPath` (strcmp; none found, no limit). For each name enumerated, after the extension,
high-byte and directory tests, with a limit the name is kept only if `strstr(PHYSFS_getRealDir(dir/name),
searchPath[i])` holds for some i up to the limit (the search path read at `0xA6C020`, the `strstr` at `0xA6C02A`).
`HistoryDatabase_LoadFiles` lists subfolders through `ListSubdirectories` and then `history/provinces/<sub>` (`0x5F5F70`,
`0x5F60E2`), so each subfolder has to be named.

## 7. CDirectorySettings is never loaded (confirmed by scan)

No function referencing `g_CDirectorySettings` calls `CPersistent::Load` (`0xA7C050`); the same scan with
`ListFilesWithExtension` added finds nine readers of the global, `LoadEventFolder` `0x9C0520` and technology's phase 2
`0x540E90` among them (positive control); no call through `[reg+4/0xC/0x10]` falls in the 14 instructions after any
reference; and its table (VA `0x15BB3D8`) is referenced by the constructor alone. So the folder modes stay 0 and the
overrides empty, `Path_PreferOverride`'s mode 2 never happens, and the event, decision and technology loaders' second
listing is always of an empty folder. Not excluded: a load of the object through a pointer had elsewhere.

## 8. Writes make their folders (confirmed)

VirtualFile_Open's write branch calls `VirtualFile_MakeParentDirs` (rva `0x66B3D0`) at `0xA6C248`, PHYSFS_mkdir of each
prefix up to a `/` or `\` before the open.

## What this corrects

- `FINDINGS-luahost.md` section 2: the order is not "the mod, then TFH, then the base game" - the mod's user folder is first.
- `FINDINGS-checksum.md` section 3: not "... the install, then the Documents folder": with a mod the plain Documents folder
  is not mounted, and without one it is in front. "The overrides were empty" is explained: nothing loads CDirectorySettings.
- `FINDINGS-ingamemenu.md` C.2: the mod's user folder is read (`<userdir>/<user_dir>`) and `userdir.txt`'s reader with it;
  "writing would fail, PhysFS's openWrite making no folders" is wrong - VirtualFile_Open makes the parents.
- `FINDINGS-eventfiles.md` section 1's open question: `tfh/` and `replace_path` do not map onto CDirectorySettings at all;
  `replace_path` is a table of its own, matched in a jump-table case of `CModDescriptor::LoadKey`, which is why the compare
  scan missed it.
- `FINDINGS-loadingscreen.md`: "`0xA56470`, perhaps main's entry; not recorded" is `WinMain`, recorded now.
- The record's `ListFilesWithExtension`: `0x794A40` is `std::find`, not a merge. GameSettings `+0xC0`: the "string main
  holds" is `-settings=`. `g_log_command_execution`: `-randomlog` on the command line sets it too.

## Not established

- The `-dlcmod` DLC line's exact fields; who sets a DLC's `+0xFC` (*inferred*: VerifySignatures).
- The launcher's exact argument (the executable's side settled; its IL not decompiled).
- The readers of `checksum`, `affects_checksum` and settings `+0x58` (`hoi3`).
- The partition step `0xAB0A10`; how `ReplacePathTable_Destroy` is registered.

Index: `disasm.py 0xA564D0`, `0xA572C0`, `0xA6BCB0`; `findRefs` on `0x1B165D4` and `0x1A85558`. Fragment:
`fragments/merged/mod-layer-startup.json`.
