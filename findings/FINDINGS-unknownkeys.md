# A key the original does not know: what each kind of file does with it

*Read on 2026-11-20, statically, for a question about mods written for two engines: may a file the
original also reads carry a key that only another engine understands? Addresses are **rvas** unless a
VA is said (trap 1). Nothing was tried in a running game. The mechanism was already in the record -
`FINDINGS-oob.md` ("An unrecognised key does not skip its block"), `FINDINGS-script.md` ("Nothing is
written when a mod's file has a bad key"), `FINDINGS-triggergrammar.md` section 2 and
`FINDINGS-effectgrammar.md` section 2 - and this file adds the survey that says how far it reaches,
four default arms nobody had read, and the answer per kind of file.*

**Synopsis.** A loader reads `key = value` one pair at a time and nothing steps over a value it was not
asked to read: **`ParseSkipValue` has one caller in the whole image, `CCountry::LoadKey`**. So in every
other object an unknown key written with a **scalar** is passed over cleanly - silently, or with a log
line on a channel no log file has ever shown - and an unknown key written with a **block** is not
skipped: the block's contents are read as the enclosing object's own keys and its `}` ends that object
early. `defines.lua` is the exception both ways, being read through Lua by name. Three corrections to
the record: `CTechnology::LoadKey` does not take "anything it does not know" for a unit type - a name
that is no unit type goes on to `CTechStatistics::LoadKey`; that loader's default arm has three more
name-resolved forms and a log line; and `CSubUnitDefinition::LoadKey` logs a key it does not know
where the record said it was dropped in silence.

## 1. The mechanism, in one paragraph

`CPersistent::Load` (`0x67C050`) loops: peek a token, stop on `}` or the end, `ParseReadKeyValue`
(`0x67ACB0`), then the object's `LoadKey` with the key's token. `ParseReadKeyValue` reads the key, one
token, and - only where that token is `=` - **one** value token. For `foo = { a = 1 }` the value is the
`{` itself. A `LoadKey` with no case for `foo` returns; the loop's next key is `a`, read as a key of
the enclosing object, and the `}` that closed `foo` is met in key position and ends the enclosing
object's `Load`. Whatever followed in that object is then read by *its* parent. All `confirmed` in the
files named above.

So the only thing that could make an unknown block harmless is a loader that skips it, and the next
section is the search for one.

## 2. The survey: `scripts/loaderarms.py`

For each of the **320** recorded functions whose name holds `LoadKey` or ends `::LoadEntry`, the script
takes the bytes from the entry to the first run of three `int3` or the next recorded function and reads
every `E8`, `E9` and `0F 8x` at every byte offset as a rel32 branch, keeping those that land on
`ReportUnknownKey` (`0x67A7B0`), `ReportParseError` (`0x67A960`), the log record builder (`0x2410`),
`ParseSkipValue` (`0x67AC60`) or another recorded loader. It does not decode, so trap 9 does not apply.

| | loaders |
| --- | --- |
| reach `ReportUnknownKey` (queued, never printed for a data file) | 34 |
| build a log record (a message of their own for a bad key or value) | 37 |
| reach `ParseSkipValue` | **1** - `CCountry::LoadKey`, the call at `0xCCDF2` |
| reach none of the four and no other loader - they return | 65 |

The rest call or jump into another loader - a base class's, or `CModifier::LoadKey` for a law, a
minister type, a government and a triggered modifier.

**The negative and its control.** The same byte scan over the whole of `.text`, not only the loaders,
finds one rel32 branch to `ParseSkipValue`: the call `0x52` into `CCountry::LoadKey`, which is the
caller the record already had. So the scan finds what is known to be there, and finds nothing else.
`confirmed` for direct branches. **What it cannot see**: a call through a pointer, and a skip loop
written inline in a default arm. The four arms of section 4 and the arms already read in the files
above were read instruction by instruction and have neither; the other loaders' arms were not read
one by one, so for them "does not skip" is `likely`, on the strength of the helper existing, being
used once, and no arm read so far doing the work by hand.

## 3. The answer, by kind of file

"Clean" means the pair is consumed and nothing else is disturbed. A block is unsafe in every row but
the last two.

| file | loader | an unknown `key = scalar` | source |
| --- | --- | --- | --- |
| `.mod` descriptor | `CModDescriptor::LoadKey` | clean, silent (`ReportUnknownKey`) | `FINDINGS-modlayer.md` |
| events, decisions: the container | `CEvent`, `CEventOption`, `CDecision::LoadKey` | clean, silent (the arm returns) | section 2 |
| an effect block | `CEffect::LoadKey` | clean; `Unknown effect-type` logged | `FINDINGS-effectgrammar.md`, 3 |
| a trigger block | `CTrigger::LoadKey` | clean; silent inside a script-written block, `Unknown trigger-type` logged directly inside an engine-made one | `FINDINGS-triggergrammar.md`, 2-3; section 4.4 |
| `common/traits.txt` | `CTrait::LoadKey` | clean; logged against `traits.cpp` | the record's entry |
| a law, a minister type, a government, a triggered or static modifier | `CModifier::LoadKey` | clean; `unknown modifier '<key>'` logged | `FINDINGS-occupation.md`, F |
| `common/buildings.txt` | `CBuilding::LoadKey` | clean, silent | `FINDINGS-modifierkinds.md`, 3 |
| `units/*.txt` | `CSubUnitDefinition::LoadKey` | clean; `Unknown keyword '<key>'` logged | section 4.3 |
| `technologies/*.txt` | `CTechnology::LoadKey`, then `CTechStatistics::LoadKey` | clean; `Unkown token '<key>'` logged | sections 4.1, 4.2 |
| a unit file's terrain block | `CUnitAdjuster::LoadKey` | clean; `unknown key '<key>'` logged | the record's entry |
| country and province history | `CCountryHistory::LoadEntry`, `CProvinceHistory::LoadEntry` | **not clean in general**: the key is resolved as a name, and a name not found comes back as the database's null object, which the loader then acts on | `FINDINGS-script.md`, "Where a message really lives or dies" |
| `common/defines.lua` | `CDefines::Load`, through Lua | clean, and **so is a new block**: the file is run as Lua and each of the 395 names is fetched by name | `FINDINGS-definesuse.md`, 1 |
| a new file under `common/` | none | never opened: every `common` file is opened by name, and `LoadCommonFiles` lists only `music` and `scenarios`. It is summed into the file checksum, which lists `common` for `.lua` and `.txt` | section 5; `FINDINGS-checksum.md`, 3 |

Every log line named here is on channel `0x10004`, **the one channel seen in the code and never in a
log file** (`FINDINGS-script.md`): whether it reaches `error.log` is not known, and no log of a full
load has shown one. So "logged" may mean nothing a player or a modder can see.

**Two things that are not parse safety, and matter as much to a file meant for two engines:**

- **A dropped trigger is an absent condition.** An `and` whose only other-engine condition is dropped
  holds; a `not` around it holds. A dropped effect does nothing. So a script that leans on a new
  keyword behaves differently in the original even though it parses.
- **A key that is the name of something** - a building, a technology, a unit type, a law group, an
  ideology, a region, a country tag - is taken for that thing by the trigger and effect loaders' default
  arms before it is ever unknown (`FINDINGS-triggergrammar.md`, 2; `FINDINGS-effectgrammar.md`, 3). A
  new key must not collide with a name a mod declares.

## 4. Four default arms, read for this

### 4.1 `CTechnology::LoadKey` (`0x134AC0`): a unit type, else the statistics

The default arm is VA `0x535485`, reached by `jne` from the comparison tree. It copies the key's text
(`parse +0x24`) into a string and looks it up with `StringHashFind` (`0x5C7D60`) in the table at
`CSubUnitDataBase::GetInstance() +0x10` - the unit types by name.

- **Found** (`test esi, esi` at `0x53550C`): a 0x228-byte object is built for that unit type (the
  constructor at VA `0x5A3510`, with the type's `+0x8` and `+0x24`), its slot 3 (`Load`) is called with
  the parse context - so the value has to be a block - and it is appended to the technology's list at
  `+0x294`..`+0x29C`.
- **Not found**: `CTechStatistics::LoadKey(this, parse, key)` - the call at VA `0x5355EF` - and
  return.

The lookup answers a real null here, not a null object, so a key that is no unit type does **not**
become an effect on the null unit type. `confirmed`. The record said "anything it does not know is
taken as a unit type's name"; that is the first half only.

### 4.2 `CTechStatistics::LoadKey` (`0x137DB0`): three more forms, then a log line

The switch's default is VA `0x538792`. In order:

1. **A key beginning `tactic_`** (seven bytes compared, the call at VA `0x5387A0`): the value through
   `TokenToFixedPoint` (`0x669550`), and the pair - the key's whole text and the value - pushed onto the
   vector at `this +0x1E8` (the push at VA `0x538834`, the 0x20-byte `{name, value}` element
   `AmphibiousMultPending_PushBack` handles). Resolved later by name; where was not read.
2. **A combined-arms unit group's name** (`CSubUnitDataBase_FindUnitGroup`, `0x1AE010`, with an index
   above nought, VA `0x538924`..`0x53892C`): the value through `TokenToFixedPoint` into
   `(this +0x5C)[index]`.
3. **An order type's keyword**: `OrderTypeToMissionIndex` (`0x184410`) of the key's *token* (`parse
   +0x20`) answering anything but 0x21. The value is then read **as a block** by a loop of the same
   shape as `CPersistent::Load` (VA `0x538980`..`0x538A3E`): stop on `}` or the end, `ParseReadKeyValue`,
   `efficiency` (token 0x587) into `this + index*4 + 0xE0`, `reduction_modifier` (0x586) into `this +
   index*4 + 0x164`, any other key passed over. This is `air_superiority = { efficiency = 0.05 }`.
4. **Anything else**: `Unkown token '<key>' in <file>` - the engine's spelling - `technology.cpp` line
   1237 (`push 0x4D5`), channel `0x10004`, and return. **Nothing is consumed.**

`confirmed`, each step off the listing. So an unknown scalar in a technology is clean and an unknown
block leaks into the technology.

### 4.3 `CSubUnitDefinition::LoadKey` (`0x1A3C80`): a terrain's name, else a log line

The default arm is VA `0x5A4D13`. The key's text goes to `CMap::FindTerrainByName` (`0x91E40`) with
`g_CMap`:

- **Found**: the terrain's index (its `+0x8`) picks a 0x18-byte element of the array at `this +0x54`
  and that element's slot 3 (`Load`) is called with the parse context - the terrain's adjuster block,
  `forest = { attack = -0.1 }`, which `CUnitAdjuster::LoadKey` reads.
- **Not found**: `Unknown keyword '<key>' in <file>`, `subunit.cpp` line 346 (`push 0x15A`), channel
  `0x10004`, and return. **Nothing is consumed.**

`confirmed`. The record's "anything that is neither is dropped in silence" was `definitions.py`'s
boilerplate, written before this arm was read; the key is logged. A unit type's key that is the name
of a terrain a mod adds is read as that terrain's block, so a new unit key must not be a terrain's
name either.

### 4.4 `CTrigger::LoadKey` (`0x5C8D10`): the failing default consumes nothing

`FINDINGS-triggergrammar.md` has the default arm's five steps. Its end, VA `0x9CAEE3`..`0x9CAFA1`,
read again for one question: `cmp [esp+0xC], 0 / jne` over the log block, the log record for `Unknown
trigger-type`, two string destructors and the epilogue. **No token is read on either path.** So an
unknown key given a block - one that is no ideology, no region and no scope - leaves the block's
conditions to be read as the parent's own and its `}` to close the parent. `confirmed`. For a trigger
that means the conditions inside still count, in the parent, and what followed the block in the parent
moves up a level.

## 5. Which folders are listed, and which files are opened by name

A file nothing opens cannot hurt. Every rel32 call to `ListFilesWithExtension` (`0x66BCB0`), found by
the same byte scan (39 sites), with the folder or extension string pushed nearest before it:

| caller | lists |
| --- | --- |
| `CTechnologyDataBase::LoadTechnologies` | `technologies`, `.txt` |
| `CSubUnitDataBase::LoadDefinitions`, `BuildHistoricalModels` | `units`, `units/models`, `.txt` |
| `HistoryDatabase_LoadFiles` | the history folders, `.txt` |
| `CEU3Application::LoadEverything` | `.gfx`, `.gui` |
| `LoadCommonFiles` | `music` and `scenarios`, `.txt` - **and nothing of `common` itself** |
| `LoadDecisions`, `LoadEventFolder`, `CMission::LoadKey` | `decisions`, `events`, `missions`, `.txt` |
| `WinMain` | the localisation's `.csv` |
| `DlcModSettings_Scan` | `.dlc`, `.mod` |
| `CVersion::ChecksumFolder` | the checksum's folders (`FINDINGS-checksum.md`, 3) |
| `BattlePlanManager_ScanHistorical`, `_ScanSaved`, `CInGameIdler::CInGameIdler` (`.mp3`), `ListFilesWithExtensionSorted` | battle plans, music, and a sorted wrapper whose own callers were not followed |

So a new `.txt` in `technologies`, `units`, `events`, `decisions` or a history folder **is parsed** by
that folder's loader, and one in `common/` is not parsed by anything: it is only summed.
`ListFilesWithExtensionSorted`'s callers were not followed, and `ListSubdirectories` was not scanned -
`likely` for "nothing lists `common`", `confirmed` for the sites listed.

## 6. Recorded

`fragments/merged/unknown-key-arms.json`: five revisions, no new function - `ParseSkipValue` (its one
caller), `CTechnology::LoadKey` and `CTechStatistics::LoadKey` (sections 4.1, 4.2),
`CSubUnitDefinition::LoadKey` (4.3) and `CTrigger::LoadKey` (4.4). `scripts/loaderarms.py` is the
survey.

**Not read**: the default arms of the loaders section 3 does not name (a minister's, a leader's, a
country file's, the map's); what `0x10004` reaches; where a technology's `tactic_` pairs are resolved.
