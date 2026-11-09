# The console: every command the game has

*Static reading of `hoi3_tfh.exe` (TFH, the unpatched vanilla build), 2026-11-08, by a delegated agent (fragment
`console-commands.json`), for an inventory the maintainer asked for. The table's 53 rows - names, developer bytes, aliases
and handlers - were read again off the bytes by the collecting session before the merge. Addresses are VAs unless marked
rva; every one is valid only for this build.*

**What this settles.** The console has **53 commands, all in one static table**, one of them `debug`, which takes 15
sub-words and 10 more layer names under `debug render`. Two of the 53, `weather` and `crash`, are marked developer-only
and refused in this build. **Nothing runs in a multiplayer game.** No command is registered at run time, and there is no
second table or dispatcher. **Corrected** by it: `weather` cannot be reached from the console (ConsoleCmd_Weather's body
is unreachable); `SpawnRebelsTextCommand` and `GuaranteeTextCommand`, recorded as registered at run time, are rows 22
(`revolt`) and 48 (`guarantee`) of the static table, and `revolt`'s first argument is a rebel type's **name**;
`g_log_command_execution`'s setter, "not found", is `randomlog`; GameSettings +0xEC is not "only bit 0 ever changed" -
`debug` flips 13 of its bits; and VA 0x170B498, which earlier comments cite as the table, is row 17's name field.

## A. How a line is run

1. **The console object** hangs off the in-game screen at `CInGameIdler +0x1CC4` (*inferred* from the shared offsets):
   +0x28 the edit box, +0x30 whether it is open, +0x44 the history cursor, +0x48 a `std::vector<ConsoleCommandDef*>`.
   Its constructor fills that vector at 0x60C3A4 through **ConsoleCommands_Fill** (0x444110), which reserves 0x35 = 53 and
   pushes a pointer to every 0x4C-byte row from 0x170AF88 while the row is below 0x170BF44. `CInGameIdler_HandleInput`
   sends the up and down arrows to the history (0x60C540 / 0x60C580) while the console is open; `§` (0xA7) and `` ` ``
   open it (`FINDINGS-editbox.md`, `FINDINGS-selection.md`).
2. **Console_SubmitLine** (0x60C640) runs on Enter, reached only through a callback pointer written at 0x60BF2C. It takes
   the edit box's text, trims it, and keeps it in the history and in `console_history.txt`. Then:
   - **where `CInGameIdler +0x68` (multiplayer) is set it prints `No cheats in MP` and stops**, before any lookup, so even
     `help` is shut in a multiplayer game (0x60C8BB); *confirmed*
   - otherwise it splits the line on spaces (0xA5B520) into `std::string` tokens and calls ConsoleCommands_Execute;
   - it splits the reply on line breaks and prints each line after `§W` (white) where the reply's success byte is set and
     `§R` (red) where it is not.
3. **ConsoleCommands_Execute** (0x4442D0) looks `tokens[0]` up with **ConsoleCommands_Find** (0x4441D0), an **exact,
   case-sensitive** compare against the row's name and then each alias (*confirmed*: no case folding there or in
   SubmitLine). Then: no row, `Unknown command`; a row whose first byte is 0, **`Command available only for developers.`**
   with no global consulted, so nothing in this build enables those rows; a row with no handler, `Console Error - command
   has missing action.`; otherwise `handler(&reply, &args)`, `__cdecl`, `args` being `tokens[1..]`. A **reply**
   (ConsoleReply, 0x20 bytes) is `{bool ok; std::string text}`.
4. **`help`** lists every row through ConsoleCommands_ListAll (0x444640), which **leaves the developer-only rows out**,
   each written by ConsoleCommand_Format (0x43A380) as `name(alias,alias) [arg] [arg]`. `help <cmd>`
   (ConsoleCommands_DescribeOne, 0x4444D0) adds `\n - <description>` and does not test the developer byte, so it
   describes `weather` and `crash` too.

**Arguments are counted, not typed**: most handlers `atoi` a number, so anything else reads 0. A number of goods,
manpower, officers or nukes is multiplied by 1000 (the game's thousandths).

## B. The table

`g_ConsoleCommandTable`, VA 0x170AF88..0x170BF44 (rva 0x130AF88), 53 rows of **ConsoleCommandDef**:

| offset | field | |
| --- | --- | --- |
| +0x00 | `available_in_release` (bool) | 0 on `weather` and `crash` alone |
| +0x04 | `name` (char*) | |
| +0x08 | `alias_count` (int) | 0..2 used |
| +0x0C | `aliases` (char*[3]) | |
| +0x18 | `description` (char*) | the help text |
| +0x1C | `handler` | `ConsoleReply* __cdecl (ConsoleReply*, std::vector<std::string>*)` |
| +0x20 | `argument_count` (int) | 0..5 used |
| +0x24 | `arguments` (char*[10]) | the bracketed argument texts |

**The extent, with its positive control**: the walker's constants (0x444150 `mov ebx,0x170AF88`, 0x4441B8 `add
ebx,0x4C`, 0x4441BB `cmp ebx,0x170BF44`) and its reserve of 0x35 agree - (0x170BF44 − 0x170AF88) / 0x4C = 53 with nothing
over. Every row parses as a name pointer into .rdata and a handler into .text 0x43A6B0..0x443E90; neither the dword before
row 0 (0x3F800000, 1.0f) nor the bytes after the end (0x102, then a null name) does.

## C. Every command

Help texts are quoted as written, misspellings and all. "The player" is the country played (`CGameState +0xC30`). Every
handler is `void* __cdecl ConsoleCmd_X(void* result, void* arguments)`. Each runs once it is past the multiplayer gate
unless its row says otherwise. *Confirmed* except where marked.

### Cheats on the player's country

| command | aliases | args | help text | handler VA (rva) | what it does |
| --- | --- | --- | --- | --- | --- |
| `money` | | amount | Adds specified amount of money | 0x43E1A0 (0x3E1A0) | +N×1000 money to the stockpile - the acting capital's province pool (+0x15C), or `CCountry +0x9F8` for a government in exile; no floor. "Added N money." |
| `supplies` | | amount | Adds specified amount of supplies | 0x43E420 (0x3E420) | the same, supplies (+0x8) |
| `crudeoil` | crude | amount | Adds specified amount of crude oil | 0x43E6A0 (0x3E6A0) | the same, crude oil (+0x14) |
| `fuel` | | amount | Adds specified amount of fuel | 0x43E920 (0x3E920) | the same, fuel (+0xC) |
| `metal` | | amount | Adds specified amount of metal | 0x43EBA0 (0x3EBA0) | the same, metal (+0x18) |
| `energy` | | amount | Adds specified amount of energy | 0x43EE20 (0x3EE20) | the same, energy (+0x1C) |
| `rarematerials` | rare | amount | Adds specified amount of rare materials | 0x43F0A0 (0x3F0A0) | the same, rare materials (+0x20) |
| `givemeall` | | amount | Adds specified amount of all resources | 0x43F320 (0x3F320) | all seven goods at once. "Added N of everything." |
| `addmanpower` | manpower | num | Adds a specified amount of manpower | 0x43D5B0 (0x3D5B0) | +N×1000 to `CCountry +0xBCC`, floor 0 |
| `addofficers` | officers | num | Adds a specified amount of officers | 0x43D340 (0x3D340) | +N×1000 to `CCountry +0xC4`, floor 0 |
| `nukes` | | num | Adds a specified amount of nukes | 0x43D820 (0x3D820) | +N×1000 to `CCountry +0x90`, no floor |
| `noneutrality` | | - | Lower down your country neutrality | 0x43D200 (0x3D200) | `ChangeNeutrality(player, −1000000)`. "No longer neutral" |
| `setnationalunity` | | country tag, new national unity | Sets the national unity of the provided country to the given value | 0x43F650 (0x3F650) | `CCountry::SetNationalUnity`, held 1..100 |
| `election` | | - | Starts an election | 0x43C8D0 (0x3C8D0) | `CCountry_HoldElection(player, 1)` |
| `instantresearch` | inr | - | Toggles instant research | 0x440030 (0x40030) | flips `g_InstantResearch` (rva 0x168559B) |
| `instantconstruction` | instantproduction, inc | - | Toggles instant construction | 0x43FF80 (0x3FF80) | flips `g_InstantConstruction` (rva 0x168559A), read only by `CDistributeProduction::Distribute` (0x51A1C5): a line the day reaches is finished whatever its progress |
| `reorg` | | province id | Reorganize all friendly units at location | 0x43FCD0 (0x3FCD0) | every brigade of the **player's own** units in the province to `GetMaxOrganisation` |
| `teleportselectionto` | teleport | province id | Teleports currently selected unit to location | 0x43FA70 (0x3FA70) | the selected unit: `CancelMovement`, `EnterProvince(provinces[id])`, no test of adjacency, owner or terrain; refuses "Select transportable unit first!" by the unit's slot 15 (not read) |

### Cheats on the world: diplomacy, land, events

| command | aliases | args | help text | handler VA (rva) | what it does |
| --- | --- | --- | --- | --- | --- |
| `tag` | | country_TAG | Switch control to another country | 0x43C9F0 (0x3C9F0) | **posts a `CSetCountryControllerCommand`** - the one cheat through the command queue. Refused while the first byte of the custom game settings is set (meaning not read); a tag owning no province: "Such country does not exist." |
| `surrender` | | loser country tag, winner country tag | Annex the other country | 0x4401E0 (0x401E0) | `AnnexCountry(winner, true, loser)` |
| `guarantee` | | country tag, recipient country tag | Toggle guarantee of one country by another | 0x442CD0 (0x42CD0) | makes or removes a CGuarantee |
| `conquerall` | | country tag | Set all enemy provinces under our control. | 0x442910 (0x42910) | every province TAG owns and still controls under the player's control (`Province_SetController`). **No war needed** |
| `changeowner` | | country tag, province id | Change the owner of specified location | 0x440A70 (0x40A70) | `CMapProvince::SetOwner`, no history entry, the controller left |
| `changecontroller` | | country tag, province id | Change the controller of specified location | 0x440E10 (0x40E10) | `Province_SetController` |
| `event` | | event id, <country_TAG/province_ID> | Executes an event | 0x43C2E0 (0x3C2E0) | finds the event by id and **opens its window** for the player, or for the tag or province given (a province event in a province's scope); no trigger, mean time or fire-once test. *inferred*: the options then act as usual |
| `revolt` | | <revolt type>, province id | Creates revolt at specified location | 0x43DDE0 (0x3DDE0) | two arguments: a rebel type's **name** (g_rebel_types) and a province, `CreateRebelBrigadesInProvince`; one: the province alone, which chooses the type (`SpawnRebelsOfChosenTypeInProvince`) |
| `alwayspartisants` | ap | - | Toggles ability to always spawn partisants from undergrounds. | 0x43A980 (0x3A980) | flips `g_ignore_partisan_spawn_limit` |
| `date` | | date in format yyyy.mm.dd.hh | Changes current date | 0x43E070 (0x3E070) | **writes `CGameState +0xBDC` directly**; nothing runs for the time skipped |
| `aipause` | | <country tag>, <all> | Pause AI for specified country or for all. | 0x443720 (0x43720) | none: lists the paused AIs; `all`: unpauses all where any is paused, else pauses all; a tag: toggles that country's AI `+0x128 ai_paused` |
| `morehumans` | humans | num | Adds more humans | 0x43ABB0 (0x3ABB0) | appends N fake CHuman records to `CGameState +0x60` and sets `controllers_changed`: a lobby or multiplayer test |

### Debug toggles: the `debug` command

`debug` (row 43; help "Various debugging actions"; argument text "Arguments:
info/profile/tooltips/assert/log_profile/textures/fow/spy/yesmen/wireframe/minzoom/render/color/save/nopopup"); handler
**0x441520 (rva 0x41520)**, one function 0x441520..0x442578 - the "start at 0x441A0E" findRefs gives is its heuristic, not
an entry. The word is matched exactly, in this order:

| word | does | answers |
| --- | --- | --- |
| `info` | flips bit 0x2000000 of GameSettings +0xEC | Displaying debug info |
| `profile` | flips bit 0x800000 of +0xEC | Displaying profiler info |
| `tooltips` | flips `g_TooltipsEnabled` - every tooltip off or on | Tooltips are now turned OFF./ON. |
| `assert` | flips `g_AssertsEnabled` (rva 0x13098E2, starts 1) | Asserts are now turned OFF./ON. |
| `log_profile` | flips bit 0x400000 of +0xEC | Profiling info has been written to the debug log. |
| `textures` | writes the graphics' texture list to the log | Texture info has been written to the debug log. |
| `fow` | flips `g_FogOfWarEnabled` and asks for the whole map's refresh (in-game screen +0x84 = −1, −1 pushed on +0x88) | Fog of war turned OFF/ON |
| `nopopup` | flips `g_NoPopups` | Blocking all popups / Stopped blocking all popups |
| `spy` | flips `g_SpyCheat` | Superior espionage turned ON./OFF. |
| `yesmen` | flips `g_AiYesmen` | AI now always responds favorably / AI now uses normal responses. |
| `wireframe` | flips `g_ConsoleWireframe`, mirrored to graphics +0x6BC44, `SetRenderState(D3DRS_FILLMODE, WIREFRAME/SOLID)` | Wireframe ON/OFF |
| `minzoom N` | MapCamera +0x35C `lowest_height_setting` = N where N > 0 | Zoom limit set to N |
| `render` | lists the ten layers of (+0xF0 AND +0xEC) as yes or no | Render options: ... |
| `render <LAYER>` | upper-cases the layer (CharUpperBuffA) and flips one bit of +0xEC: TREES 0x1, BORDERS 0x2, TEXT 0x8, OVERLAY 0x10, OBJECTS 0x20, MAPOBJECTS 0x40, RIVERS 0x80, WATER 0x100, WATERBORDERS 0x200, EFFECTS 0x400 | nothing |
| `color TAG r g b` | each 0..255 over 255.0; sets the country's map colour (0x4CCD00) and makes the map's colour textures again | Color applied to X |
| `save TAG` | 0x4F5730 (not read) | Country color saved |

`info`, `profile` and `log_profile` also copy bit 0 into `render_trees` (+0xE4). With no word the answer is "Please
specify some arguments."; an unknown word answers nothing.

### Other debug toggles and logs

| command | aliases | args | help text | handler VA (rva) | what it does |
| --- | --- | --- | --- | --- | --- |
| `tooltipdebug` | tdbg | - | Toggle debug shown in game tooltip. | 0x443670 (0x43670) | flips `g_TooltipDebug`: the province tooltip adds the tag, the country's id and the province's id |
| `randomlog` | | - | Toggles random logging | 0x43B130 (0x3B130) | **sets** `g_log_command_execution` and never clears it, whatever the help says; PumpCommands then logs every command |
| `detailedlog` | dl | FilePathAndName | Prints detailed log of entire game data (use for debugging). | 0x43A6B0 (0x3A6B0) | the game state to `logs/<name>.log` through 0x68C650 (*inferred* save-shaped, from SaveWriteKey/Value) |
| `printtech` | pt | <nozero> | Prints actual technology levels to the log file. | 0x443270 (0x43270) | the player's levels to game.log; **any one argument leaves zeros out** - the word `nozero` is never compared, the string being absent from the image |
| `copyprov` | | - | Copy selected provinces ids to clipboard | 0x4411B0 (0x411B0) | the ids, space-separated, to the Windows clipboard |

### Reloads and developer tools

| command | aliases | args | help text | handler VA (rva) | what it does |
| --- | --- | --- | --- | --- | --- |
| `reload` | | file name | Reloads the gui or lua file | 0x43B1D0 (0x3B1D0) | `.lua`: looked for as given, then under `script/`, then `script/country/`, and run in every thread's Lua state; otherwise `ReloadInterfaceFile` |
| `reloadinterface` | | - | Reloads the entire interface | 0x43B610 (0x3B610) | `CInGameIdler_BuildViews` |
| `reloadfx` | | map/front/hierarchy/masked3dFlag or *.fx filename | Reloads the shader | 0x43B730 (0x3B730) | `map`: the province manager's resources; `front`, `hierarchy`, `masked3dFlag`: their own shaders; a file: `FxHandler_Reload` as given, then under `gfx/FX/` |
| `reloadtexture` | | texture file name | Reloads the specified texture | 0x43C0F0 (0x3C0F0) | 0xA61730 (not read) |
| `window` | wnd | open/close, window gui name | Opens or closes the specified window | 0x43AEB0 (0x3AEB0) | makes or destroys one interface window by name, one at a time (`g_ConsoleOpenWindow`) |
| `tutorial` | | chapter id, <reload> | Sets or reload tutorial | 0x440720 (0x40720) | `reload`: parses `interface/tutorial.gui` again; N: in-game screen slot 90 (1, N); none: chapter 0 |
| `fullscreen` | | - | Toggles full screen mode | 0x4400E0 (0x400E0) | flips the window mode and resets the device |
| `nextsong` | | - | Changes the currently playing soundtrack. | 0x43AA30 (0x3AA30) | in-game screen slot 33 (0x678730). "Now playing X" |
| `spawnactor` | | actor name, province id, <animation>, <gun>, <hat> | Spawns 3d object at location | 0x442580 (0x42580) | places a model with GunNode and HelmetNode attachments (*inferred* in detail) |
| `help` | | command name | Print out all console commands or a specific command description. | 0x443E90 (0x43E90) | section A.4 |
| `helplog` | | - | Print out all console commands to game.log file. | 0x443C50 (0x43C50) | the same list to game.log |

### Editor and map painting, left in the release

| command | help text | handler VA (rva) | what it does |
| --- | --- | --- | --- |
| `paint` | Switch to map painting mode. | 0x43CD80 (0x3CD80) | flips CInGameIdler +0x5. "Now painting the map, use tag XXX to change what to paint." |
| `rpaint` | Switch to region painting mode. | 0x43CEA0 (0x3CEA0) | flips +0x6 |
| `cpaint` | Switch to continent painting mode. | 0x43CFC0 (0x3CFC0) | flips +0x8; the region map mode colours by continent (`FINDINGS-mapmodesrest.md`, section 2) |
| `ipaint` | Switch to infra painting mode. | 0x43D0E0 (0x3D0E0) | flips +0x7. "Now painting infra. Shift-click to pick up, click to paint." |

### Developer-only, refused in this build

| command | args | help text | handler VA (rva) | what it would do |
| --- | --- | --- | --- | --- |
| `weather` | num | Runs weather test | 0x43DA80 (0x3DA80) | N hours of the weather by hand (`FINDINGS-weathersim.md`, A) |
| `crash` | - | Simulate crashing the game | 0x443640 (0x43640) | writes 1 to address 0 |

**Multiplayer**: no command is for it - all 53 are shut by `No cheats in MP`; `tag` and `morehumans` are the two whose
subject is players.

## The table's order, and the replies, read 2026-11-09 for OpenHOI3

Row order (what `help` lists): detailedlog, alwayspartisants, nextsong, morehumans, window, randomlog, reload, reloadinterface, reloadfx, reloadtexture, event, election,
tag, paint, rpaint, cpaint, ipaint, noneutrality, addofficers, addmanpower, nukes, weather, revolt, date, money, supplies, crudeoil, fuel, metal, energy, rarematerials,
givemeall, setnationalunity, teleportselectionto, reorg, instantconstruction, instantresearch, fullscreen, surrender, tutorial, changeowner, changecontroller, copyprov,
debug, spawnactor, conquerall, tooltipdebug, aipause, guarantee, printtech, crash, helplog, help.

**The words of the answers**, the literals in each handler (*confirmed* as literals; how they are joined is *inferred* from their order where more than one stands in a
reply): an amount, `Please specify the amount.`, then `Added ` N ` money.` (or ` supplies.`, ` crude oil.`, ` fuel.`, ` metal.`, ` energy.`, ` rare materials.`, ` of everything.`,
` manpower.`, ` officers.`); `noneutrality` and `election` `Invalid arguments count.`, `No longer neutral`, `Election started`; `setnationalunity` `Please specify the country tag
and new national unity.`, `Please specify the new national unity.`, `Invalid country tag.`, `National Unity of ` X ` changed to ` N; `reorg` `Please specify the province id.`, N
` friendly subunits reorganized.`, `No friendly subunits found in province`; `surrender` `Please specify 2 country tags.`, `Unknown country `, `Country ` X ` annexed ` Y;
`guarantee` the same and `Unknown country tag`, X ` is now guaranteeing ` Y, ` is no longer guaranteeing `; `conquerall` `Please specify enemy country tag.`, `Unknown country tag`,
N ` more provinces are under our control`; `changeowner` and `changecontroller` `Please specify country tag and province id`, `Unknown country.`, `Invalid province specified`, X
` now belongs to ` Y, ` is now controlled by `; `event` `Please specify event id`, `There is no event with ID #`, `Target tag is invalid.`, `Executed #`; `revolt` `Please specify province id
and rebel type.`, `Unknown rebel type`, `Revolt created.`; `copyprov` `Invalid arguments`, `Select some provinces first.`, N ` provinces copied to clipboard.`; `printtech` `===== ` tag
` Technology Levels =====`, name ` = ` level, `See game.log for result.`; `helplog` `== HELP LOG ==\n`, `See game.log for full help details.`; `cpaint` `Invalid arguments count`, `Now painting continent. Shift-click to painting the map.`, `Painting disabled`.

## What the medium commands needed, read 2026-11-09 for OpenHOI3

- **`teleport`**: slot 15 is `IsLand`, slot 9 `AsArmy`; the refusal is *no unit selected, or a land unit whose `carried_by` is set*. A fleet or an air unit goes. A province id of 0 or less leaves the reply empty.
- **`debug render`** alone: a rule of 34 dashes and `\n`, `Render options:\n`, then `\t\tTrees:\t` and `yes\n` or `no\n` for each of the ten layers by bit order, then the rule again. `(mask +0xF0 of the map mode) AND (+0xEC of the console)` is what it reports. `debug render <LAYER>` answers nothing.
- **`debug minzoom`**: `Please specify zoomlevel value.`; the reply is `Zoom limit set to ` and the figure as `%.3f`, whether or not it was above nought.
- **`debug color`**: exactly five words or `4 more arguments needed: country tag, red, green, blue`; `Invalid country Tag`; `Color applied to ` and the country's name. 0x4CCD00 copies the colour to the country.
- **`aipause`**: the list is `AI is paused for:\n`, each tag and `, `, a line break after every sixth, `None` where there are none.
- **`reloadinterface`**: any argument, `Invalid arguments count`.
- **`detailedlog`**: 0x68C650 writes the counters `rebel`, `convoy`, `theatre`, `unit`, the rebel factions, a walk of records, `sunk_ships`, `weather`, `combat`, and the three lists of wars: a savegame's shape without its head (*inferred* from the keys; the walks were not read one by one).

## D. Looking for more, and the controls

- **One table**: findValue finds 0x170AF88 and 0x170BF44 once each in .text, both in ConsoleCommands_Fill.
- **No second table**: a scan of every section but code for a pointer into the handler block 0x43A000..0x444700 found,
  outside the table, only text that happens to fall in the range, none of it a handler's entry. Positive control: the same
  scan finds all 53 of the table's own handler pointers.
- **One dispatcher**: ConsoleCommands_Execute has one caller (0x60C956); the lookup two, Execute and DescribeOne; the
  string `Unknown command` occurs once.
- **No handler outside the table**: the shared answers ("Invalid arguments count." in two spellings, "Invalid arguments.",
  "Please specify the amount.", "ConsoleCmdImpl.cpp", the developer refusal) are read only inside the handler block.
- **The `debug` words**: the 15 literals in the handler are exactly the 15 the row's argument text lists, with `render`'s
  10 upper-case layer names.
- **Not covered**: the overlay's Lua console (`FINDINGS-messages.md`) is BiceLib's, not the game's; the chat box was not
  read for slash commands - nothing in the console's path asks it, but the chat code itself was not read.

## E. For a reimplementation

- Every command's effect is a direct write or a direct call but `tag`'s, which posts a command; a reimplementation that
  wants replayable cheats has to make each of them a command, where the original's are not.
- The help texts are compiled-in English, not localisation keys; nothing of the console is read from a data file but
  `console_history.txt`.

## Not established

- **0x68C650**, the walks between `detailedlog`'s keys, read as far as the keys alone.
- **The first byte of GetCustomGameSettings**, which makes `tag` refuse.
- **The in-game screen's slot 33** (`nextsong`) and **slot 90** (`tutorial`).
- **0xA61730** (`reloadtexture`), **0xA755C0** (`fullscreen`), **0x4F5730** (`debug save`),
  **0xA618F0 and 0xA769E0** (`debug textures`).
- **The reader of `g_AssertsEnabled`** at 0xA5A104, whose function entry was not found.
- **The readers of GameSettings +0xEC bits 0x2000000, 0x800000 and 0x400000** (`debug info`, `profile`, `log_profile`).
- **The readers of CInGameIdler +0x7** (`ipaint`).
- **Whether `event`'s window, once answered, does exactly what a fired event's does**: the option path was not read.
- **Whether repeated spaces are collapsed**: the splitter 0xA5B520 was not read, so `debug  fow` with two spaces may give an
  empty word.
- **The console's constructor's entry**: `functionStart` gives 0x60C2B9, which is not to be trusted, so +0x1CC4 being the
  object whose +0x48 is filled rests on the shared offsets (*inferred*).
- **`spawnactor`'s arguments against its calls**, read off the call sequence only (*inferred*).
