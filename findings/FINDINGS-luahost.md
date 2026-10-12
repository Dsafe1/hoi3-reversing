# How `hoi3_tfh.exe` hosts Lua

Read out of the executable on 2026-10-12, for OpenHOI3's first use of Lua: running the mod's
`AI_GenerateNonHistoricalRelation` as a new game is made (`FINDINGS-diplostate.md`, A). One brief
(F) of the Lua slice. The interpreter is `lua51.dll`, Lua 5.1.4 with doubles; the original's copy in
an install is `lua5.1.dll.preBlackICE`, the `lua51.dll` there now being BlackICE's forwarder (trap
19). Addresses are **virtual**, based `0x400000`, unless a line says rva.

## In one line

One Lua state per OS thread, made on first use with **all eight standard libraries**, luabind 0.9.x
and the whole API registered, one searcher added at `package.loaders[2]` over the game's file system
(the mod, then TFH, then the base game), and `script/autoexec.lua` run; nothing standard is removed,
`math.randomseed` is never called, and no state is ever closed. A new game calls
`AI_GenerateNonHistoricalRelation(country, tag)` and **`Laws(country)` for every country, the
player's included**. The result is `lua_tointeger` - **rounded to the nearest, ties to even** - and
**a Lua error or a missing function leaves the 25 set before the call**. `==` on two governments or
two factions is a registered `__eq` comparing save tokens, which is identity. The device is made
without `D3DCREATE_FPU_PRESERVE`, so the main thread's x87 runs at 24 bits.

## 1. The state

`GetThreadLuaState` (rva `0xEACA0`) keeps the state in the exe's own thread-local slot. On a
thread's first call, under a critical section (`g_ThreadLuaStateLock`), in order:

1. `luaL_newstate`;
2. `luaL_openlibs` - **all eight**: base, package, table, io, os, string, math, debug (the stock
   5.1.4 table, read out of the DLL at `0x10021230`);
3. `SetupAI(L)`: `luabind::open` (rva `0x77EFD0` - its registry tables and the globals `class`,
   `property`, `super`), then the whole API, each class a global - what autoexec's "`hoi` already
   imported by game" means;
4. `table.insert(package.loaders, 2, <the PhysicsFS searcher>)` (`Lua_InstallPhysfsLoader`, rva
   `0x4F1180`);
5. `script/autoexec.lua` run (`RunLuaFile`, rva `0x6A8290`);
6. the slot added to `g_ThreadLuaStateSlots` (`RegisterThreadLuaStateSlot`, rva `0x501DA0`).

**Nothing removes or replaces a standard global** - `print`, `dofile`, `require`, `os`, `io`,
`math.random` are all stock. **The engine never calls `math.randomseed`**: no "math" or
"randomseed" string is in the image (positive control: "package" and "loaders" are found by the same
scan), and neither the base game's, TFH's nor BlackICE's scripts call it. So each thread's
`math.random` is the C runtime's per-thread `rand`, seeded 1 and never reseeded (inferred from the
CRT; MSVCR80 was not opened). **`lua_close` is not imported**: a state lives for the session, across
new games (inferred), with its globals.

Twenty-one call sites ask for a state, all through `GetThreadLuaState`. `LoadDefines` is first - the
engine reads the global `defines` table out of the state, so `common/defines.lua` runs in every state
through autoexec's `require('defines')`, and the main thread's state exists, autoexec run, long before
a new game. Then the game's own code (`SetUpCountryForNewGame` twice, the hourly AI trade, the daily
leadership pass, the production screen's trade list) and the AI (the five ministers, the six DiploScore
bridges, which the record has on TBB workers). **There are no separate GUI and AI states**: the
"context" in autoexec's comment is the thread.

## 2. Files

Every file is read through PhysicsFS, linked into the exe (its export table names its functions; the
record's `FileExists`, rva `0x784A20`, is the export `PHYSFS_exists`). `PHYSFS_mount` is called with
append 0, so each later mount goes in front: base and `tfh` at `0xA570C1`/`0xA570CD`, the mod at
`0xA572FD` - **the search order is the mod, then TFH, then the base game** (confirmed for the mod,
`esi` cleared just before; for base and TFH inferred, `edi` being that function's zero register
along the paths followed). So `script/autoexec.lua` is the mod's, else TFH's, else the base game's.

**`require`**: the engine's searcher (`Lua_PhysfsLoader`, rva `0x4F0FE0`) at position 2, ahead of
Lua's own path searcher, tries `script/<name>.lua`, then `script/country/<name>.lua`, then
`common/<name>.lua`, each over the whole search path, loading through `PHYSFS_openRead` and
`lua_load` (`Lua_LoadPhysfsChunk`, rva `0x4F0F70`; `Lua_PhysfsChunkReader`, rva `0x4F0F10`, a
`0x200`-byte buffer). So `require('defines')` finds `common/defines.lua` and `require('ai_country')`
the base game's `script/ai_country.lua`, TFH having none. The `package.path` autoexec builds is
reached only where the file system has no such file. **A chunk is named by its bare path**, no `@`.

**Errors**: files run under `lua_pcall` with no message handler, and luabind's pcall callback
(`g_luabind_pcall_callback`) is never set, so there is no traceback. Every failure goes to
`ReportLuaError` (rva `0x6A8050`, 21 callers), which writes `LUA Error: <message>` to the log, and
nothing else happens.

## 3. The new game's two calls

**`AI_GenerateNonHistoricalRelation(country, B)`**, on the main thread, in `SetUpCountryForNewGame`,
long after autoexec. `PrepareLuaCall_AI_GenerateNonHistoricalRelation` (rva `0x1100D0`) builds the
call object - **`+8` is `luabind::detail::pcall`** (`0xB7E9D0`), not an argument pusher as the record
had it, and `+0x14` the "called" flag - and `LuaCallProxy_CountryTag_CallInt` (rva `0x10D2F0`) makes
it:

1. the global fetched with `lua_gettable(GLOBALS)`;
2. `country` pushed as a `CCountry*` pointer instance - nil if null, no copy, no cache
   (`LuaPushArgs_CountryAndTag`, rva `0x111830`);
3. `B` pushed as **a fresh heap copy of its `CCountryTag`**, owned by Lua
   (`LuaPush_CCountryTagByValue`, rva `0x1137C0`, 25 callers);
4. `lua_pcall(L, 2, 1)`; a failure throws `luabind::error`;
5. the result must be `lua_type == LUA_TNUMBER` - a numeric string included, anything else throws
   `luabind::cast_failed`;
6. the value is `lua_tointeger`, in this DLL `fld qword; fistp dword`: **rounded to the nearest,
   ties to even** (85.5 is 86, 84.5 is 84).

**On a failure**: the try block catches only `luabind::error&` and its handler logs and resumes; the
local was set to **25** before the call (`mov [ebp-0x20], 0x19` at `0x4D7173`), so **a missing
function or a Lua error gives 25**. `cast_failed` is not a `luabind::error` (its ThrowInfo lists
`cast_failed` and `std::exception` only); it escapes `SetUpCountryForNewGame` and
`CInGameIdler::Enter`, which has no try block, and where it ends was not read.

**`Laws(country)`**, at `0x4D734B`-`0x4D7375` (`"Laws"` at `0x15C0F34`; `PrepareLuaCall_Laws`, rva
`0x110120`; the void call `LuaCallProxy_Country_CallVoid`, rva `0x10D3F0`), after
`ReapplyAllTechnologies`, on the same state: one argument, no result, the same catch. **It is not
guarded** by REB, by owning a province or by who plays the country. `ai_politics_minister.lua`'s
`Laws(minister)` receives the `CCountry` where it expects a minister, and still works, `CCountry`
having `GetCountryTag` too; for each law group it wants moved it posts a `CChangeLawCommand` through
`CCurrentGameState.Post`. **This is how every country's laws, the player's among them, have moved
by the first screen** - OpenHOI3's compatibility entry 6 (Germany on `two_year_draft`) and
`FINDINGS-unitstart.md`'s open question. The call is confirmed; that the posted commands are what
change the laws is inferred from the script, their execution not traced.

## 4. The eight methods the relation's Lua calls

Each confirmed off its body: `CCountry::GetRelation(tag)` (rva `0x17BB0`) is `this->+0xE28[tag->+4]`,
`ret 4`, no checks; `CCountryTag::GetCountry` the database's `countries[id]` (recorded);
`CDiplomacyStatus::HasAlliance` `+0x14 != 0` (recorded); `HasWar` (rva `0x179A0`) `+0x20 != 0`;
`HasTruce` no war and `+0x54` within 2400 hours (recorded); `CCountry::IsAtWar` (rva `0x17BD0`) the
byte `+0xACC`; `CCountry::GetGovernment` (rva `0xE0450`) `+0xDFC`; `CCountry::GetFaction` `+0xD8` -
the body `0x417BF0` is folded with `CNudgeIdler` slot 14 (trap 4), so it has no record entry of its
own.

## 5. `==` on what the methods return

This is **luabind 0.9.x** - "No such operator defined", `__luabind_cast_graph`,
`__luabind_class_id_map` and `instance_holder`, and the dispatcher matches 0.9.1's source line for
line; 0.9.0 and 0.9.1 were not told apart. **All luabind instances share one metatable**
(`push_instance_metatable`, `0xB7E8D0`) holding a `dispatch_operator` closure (`0xB7E6C0`) for each of
13 operators, so Lua 5.1's `==` between two distinct userdata always finds `__eq`; the dispatcher looks
the operator up in the operand's class and `lua_call`s it, or raises "No such operator defined". The API
registers `self == self` for `CGovernment` and `CFaction`, and their wrappers compare **save tokens**:
`CGovernment::luabind_opeq` (rva `0x502AE0`) `+0x40`, the government key's token;
`CFaction::luabind_opeq` (rva `0x502C40`) `+0xB8`, `RegisterDynamicToken(name)` from
`CFaction::LoadKey` (`0x52292A`) or -1 from the constructor (`0x52254B`), which the null faction keeps.

So **two governments or factions are equal exactly when they are the same object**, and two countries
in no faction are equal, both holding `g_CNullFaction`. `GetGovernment` never returns null as made:
`CCountry::CCountry` stores `g_CNullGovernment` (`CNullGovernment`, rva `0x1252E0`: `CGovernment
("nogovernment", 0)`). Were nil to arise, nil against an object is false (different types, no
metamethod) and nil against nil true. Because the operator answers for any two instances, caching
userdata would not matter.

## 6. The x87's precision

All four `IDirect3D9::CreateDevice` calls in `CGraphics::CGraphics` (`0xA6E960`, `0xA6EA1F`,
`0xA6EAE9`, `0xA6ECE8`) pass `0x40` or the settings' flags, which the detector
(`GraphicsSettings_DetectDevice`, rva `0x6A3DD0`; its own test devices `0xAA47B8`, `0xAA49D0`; the flag
stores `0xAA48BD`, `0xAA4AD5`) writes as only `0x40` or `0x20`. **`D3DCREATE_FPU_PRESERVE` (0x2) is
never passed**, so by Direct3D 9's documented behaviour the creating thread's x87 is set to **24-bit
precision, round to nearest**. The image's only other precision write is the C runtime's start-up
`_setdefaultprecision` (53 bits); of the 216 `fldcw`, checked by the instructions before each, the
rest are the truncating-conversion idiom (`or 0xC00`) or the runtime's maths. `lua5.1.dll` does its
arithmetic on the x87 (no SSE2), so **Lua's arithmetic on the device's thread ran in 24-bit
mantissas** - that this is the thread running `CInGameIdler` and the main state is inferred (BiceLib
sees `Present` and the game's Lua share a thread). For `AI_GenerateNonHistoricalRelation` it changes
nothing: every value is a small integer, exact either way. Whether TBB's workers inherit the control
word was not read.

## 7. What looks wrong and is what the bytes do

- `Laws(minister)` runs with a `CCountry` for every country of a new game, the player's included,
  and posts law changes.
- A Lua error, or no such function, silently gives a relation of 25, a log line its only record.
- A result that is not a number is an uncaught C++ exception, not a Lua error.
- The result is rounded, not truncated.
- autoexec's `package.path` is dead for anything in the game's file system.
- No error carries a traceback.
- A console command (`0x43B1D0`, "reloaded!" / "Failed to reload the file") runs a file again in
  every registered state.

## 8. Not read

What `cast_failed` escaping `CInGameIdler::Enter` does; whether TBB carries the control word to its
workers; `make_pointer_instance` (`0x514550`), `get_instance_value` (`0xB7E5C0`) and `SetupAI` beyond
what `luabindExtract` already emulates; the whole of `0xAA3DD0`; the other writers of `CCountry
+0xDFC`; the loop that calls `SetUpCountryForNewGame` beyond its `+0xD9C` guard; whether every posted
`CChangeLawCommand` takes effect, which bears on `FINDINGS-unitstart.md`'s training law; MSVCR80's
`rand`.
