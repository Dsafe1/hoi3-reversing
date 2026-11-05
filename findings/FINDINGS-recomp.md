# A census of the image, for static recompilation

Taken 2026-11-05, for a question of the maintainer's: could `hoi3_tfh.exe` be lifted to C and
recompiled, as `NFSU2Recomp` does for another 32-bit Direct3D 9 game, with **Windows as the only
target**? This is not a reading of any mechanic. It is a count, over the whole image, of the things
that make a static recompiler hard: how much code there is, how much of it Ghidra has found, how
control reaches it indirectly, exceptions, floating point, threads, and what the image calls
outside itself. One small class was read whole along the way, `WinThread` (section 9), and is in
`project.json`.

Addresses are **rvas** unless a line says otherwise. Ghidra's `FUN_` names are virtual
(`FUN_00bffc50` is rva `0x7FFC50`), which is trap 1.

**How it was taken.** `ghidra/DumpRecompStats.java`, headless and `-readOnly`, against a copy of
`Hoi3_v12.1.2` with `-noanalysis`, so the figures are **what Ghidra's project holds**, and an
undiscovered function is invisible to them. That script writes every function's body, every
reference to an entry, every computed call and jump and every instruction outside a function. The
relocation, import and exception-table counts were made in Python over the install's executable,
which differs from the shipped `hoi3_tfh_imperium.exe` in the 17 bytes of trap 19 and nowhere
else (`cmp -l`, 2026-11-05). None of those bytes bears on a count here.

## Synopsis

**23,686 functions of real code**, 2.44 million instructions. Ghidra's 73,884 is inflated by
49,384 `Unwind@` and 814 `Catch` funclets. **Exceptions are part of ordinary running.** There are
4,374 `FuncInfo` records and 805 try blocks, 728 of them `catch(...)`, and handlers for
`CDatabaseException`, `luabind::error` and `CFileException`. **Code discovery is close to complete**:
every scaled-index jump table is resolved, and what lies outside the bodies is exception
machinery and catch continuations. **The image makes no code at run time**: one `VirtualAlloc`,
read-write. **SSE2 does most of the floating point, and x87 is in 847 functions**, 250 of them
named, simulation functions among them. **Lock-free code is small**: 27 `lock` instructions in 19
functions. The threads are TBB's workers, `WinThread` and one more `CreateThread`. Lua is called
from 6,691 sites in 2,982 functions.

## 1. How much code

| | functions | instructions |
| --- | --- | --- |
| code | 23,686 | 2,435,868 |
| `Unwind@` funclets | 49,384 | 123,163 |
| `Catch` / `Catch_All` funclets | 814 | 9,127 |
| **all Ghidra functions** | **73,884** | **2,568,158** |

A code function's median is 41 instructions, the 99th percentile 1,145, and the largest 19,251
(`0x8F5390`, unnamed). 7,221 bodies are not contiguous. 96 are thunks. Ghidra holds 9,189 real
names, 1,118 `vf_NN` slot names and 13,364 `FUN_`. Namespaces worth knowing: `luabind` 1,019, the C
runtime's `_` and `__` names 518, `std` 110, `tbb` 10. **The C runtime is linked in statically**:
no `MSVCR` is imported.

## 2. What Ghidra has not made a function

`.text` is 9,609,216 bytes. Function bodies cover 8,678,545 of them. The rest:

- **356,030 bytes of instructions** - 89,282 instructions in 4,291 runs. 3,562 runs begin
  `mov eax, <FuncInfo>` and end in a `jmp`: **the per-function exception state handlers** a
  frame's `push offset` registers. Another 204 begin `mov edx, [esp+N]`, the cookie-checking form.
  The rest are short.
- 52,292 bytes of defined data;
- 522,351 undefined bytes, 346,858 of them `CC`, `90` or `00` padding. The other 175,493 were not
  classified. MSVC puts switch index tables in `.text`, which would account for some of them -
  *inferred*, not counted.

**Relocations, as the oracle for what is reachable.** 279,900 `HIGHLOW` relocations. 81,825
distinct targets lie in `.text`:

| target | from `.text` | from data |
| --- | --- | --- |
| a function's entry | 3,483 | 95,259 |
| inside a function | 8,202 | - |
| outside every body, on a stray instruction | 8,884 | 9,480 |
| outside every body, on bytes nobody disassembled | 1,149 | 155 |

Of the last row, 561 targets begin `8B` (a `mov`). The samples are **catch continuations**: the
address a catch funclet hands back, such as `0x1ECC`, referenced from `Catch_All@00401ea9`.
Ghidra never reached them, because only the exception path leads there. Other samples are
addresses inside tables in `.text`. Not all 1,304 were looked at.

## 3. Indirect control flow

- **Calls through the import table**: 11,434.
- **Other computed calls**: 36,047, in 6,818 functions - `call edx` 17,671, `call eax` 16,535
  (virtual calls), `call [abs]` 1,354 (pointers in globals), the rest a few hundred.
- **Computed jumps**: 716. 430 are jump tables Ghidra resolved, with 7,544 targets, and 51 go to
  imports. **235 are unresolved, and none has a scaled index**: `jmp edx` 124, `jmp eax` 85,
  `jmp [eax+N]` 21 and a handful of others. They are tail calls through pointers, not switches.
- **Entries whose address is taken**: 57,949 are referenced from data - virtual tables, luabind's
  registrations, unwind maps - and 2,443 by an address operand in code. 615 entries have no
  reference at all.

## 4. Exceptions

**`FuncInfo` records in `.rdata`**: 4,374 - 4,373 of magic `0x19930522` and 1 of `0x19930520`. 772
have try blocks, 805 try blocks in all. The deepest unwind map has 9,476 states. What they catch,
handler by handler:

| type | handlers |
| --- | --- |
| `...` | 728 |
| `CDatabaseException` | 33 |
| `luabind::error` | 20 |
| `CFileException` | 20 |
| `CTcpException` | 5 |
| `std::logic_error`, `std::runtime_error`, `std::exception`, `CSoundException`, a pointer type | 1 each |

**What is thrown.** `_CxxThrowException` (`0x79894B`) has 499 references from 438 functions in
Ghidra. A byte scan for `E8` calls finds 613 sites; the difference was not reconciled, and the scan
can match inside other instructions. The scan read the `ThrowInfo` pushed before 396 of them:
`std::bad_alloc` 198, `std::runtime_error` 107, `luabind::error` 27, `CFileException` 18,
`CTcpException` 15, `luabind::cast_failed` 10, `std::bad_cast` 6, `ios_base::failure` 3,
`CClockException` 2, and one each of `CChoiceException`, `CComInitException`, `CThreadException`,
`length_error`, `out_of_range`, `bad_typeid`, `__non_rtti_object` and `bad_exception`. Another 217
push their `ThrowInfo` some other way, `CDatabaseException`'s throws presumably among them -
*inferred*.

`RaiseException` is called from `_CxxThrowException` and one site at `0x80AAFB`.
`SetUnhandledExceptionFilter` is called from the C runtime. 27,845 instructions in 8,958
functions use `FS`, nearly all of them the `fs:[0]` frame link.

## 5. Floating point

| | instructions | functions |
| --- | --- | --- |
| SSE (an `XMM` operand) | 68,191 | 2,433 |
| x87 (`D8`-`DF`) | 22,301 | 847 |
| MMX | 0 | 0 |

The 25 functions with the most x87 are unnamed, and all lie between `0x7BAD30` and `0x800650`.
That is library code by its place in the image - *inferred*, not read. Of the 847, 250 carry real
names, and the simulation is among them: `CAlignment::ComputeDrift`, `RunDailyRevoltRoll`,
`RunDailyUndergroundPass`, `RunCountryDailyPass`, `CLeader::AddExperience`, `CFixedPoint::Get`,
`Fixed15FromFloat`, `ReadDefineThousandths`, `CCountry::GetSpareICIn` and others. There are 211
`FLDCW` in function bodies (`FINDINGS-luahost.md` counted 216 over the image), 162 `FISTP`, and
no `CPUID`.

**That bears on the precision a recompiled x87 must keep.** `FINDINGS-luahost.md`, section 6:
the device is made without `D3DCREATE_FPU_PRESERVE`, so the creating thread runs its x87 at
**24 bits**; the C runtime's default elsewhere is 53. Whether TBB's workers inherit the control
word is still not read.

## 6. Threads and atomics

- **TBB**: 13 imports, 88 sites in 52 functions - the `parallel_for` launchers of
  `FINDINGS-aisched.md` and `concurrent_queue`. The AI, units, provinces, trade and intel fan out
  on its workers, each with its own Lua state (`FINDINGS-luahost.md`, section 1).
- **`CreateThread`**: 2 sites - `WinThread::Start` (section 9), and `0x8069F0`, whose start
  routine is `0x806940`. Neither of the latter two was read. `TerminateThread` is called once, at
  `0x806B90`.
- **`lock` prefix**: 27 instructions in 19 functions - `ConcurrentQueue_TryPop`, `0x28EA80`,
  `CMessage::CopyTo` and `::~CMessage` (a reference count), the three command channels' `Post` and
  `ServerCommandChannel::Pump`, `CGameState::QueueUnitRemoval`, `CCountry::ShatterUnit`,
  `CheckTransportOverload`, `CRemoveBrigadeEffect::Execute`, `0x27AEE0`, `0x29AD50`, `0x73E660`,
  `0x73EDF0`, `0x73EE60`, and two catch funclets.
- `Interlocked*` imports: 23 sites, most in the C runtime. Critical sections: 10 enter sites.
  `PAUSE`: 4. `SwitchToThread`: 4 sites, in `0x27AEE0`, `0x28F720`, `0x28F760` and `0x73EDF0`.

## 7. What the image calls outside itself

| DLL | imports used | sites | functions |
| --- | --- | --- | --- |
| `lua51.dll` | 56 | 6,691 | 2,982 |
| `kernel32.dll` | 142 | 566 | 269 |
| `d3dx9_42.dll` | 48 | 194 | 110 |
| `ws2_32.dll` | 26 | 129 | 45 |
| `user32.dll` | 34 | 127 | 63 |
| `tbb.dll` | 13 | 88 | 52 |
| `psapi.dll` | 1 (`GetProcessMemoryInfo`) | 86 | 10 |
| `winmm.dll` | 3 | 31 | 21 |
| `ole32`, `shell32`, `advapi32`, `shlwapi` | 14 | 19 | 11 |
| `d3d9`, `dinput8`, `dsound`, `steam_api` | 1 each | 5 | 5 |

`steam_api` is `SteamApps` alone. **Nothing makes code at run time**: `VirtualProtect` is not
imported, and the one `VirtualAlloc` (`0x45A8F9`, in `0x45A580`) asks for `0x75300` bytes
`MEM_COMMIT | MEM_RESERVE`, `PAGE_READWRITE`. `LoadLibraryA` is called from
`CMicrotransactionInterface::vf_00` (`0x42A330`) and `0x78B690`. `LoadLibraryW` is called from the C
runtime's `__crtMessageBoxW`. `GetProcAddress` has 6 sites.

**Beside the executable in the install** (2026-11-05): `lua51.dll` is BlackICE's forwarder to
`lua5.1.dll` (Lua 5.1.4 on `MSVCR80`, trap 19). `tbb.dll` is on `MSVCR100`. `d3d9.dll` and
`dxgi.dll` are DXVK's. `dinput8.dll` is the mod's borderless-window component.

## 8. Rare instructions

216 distinct mnemonics. Among the rare: `RDTSC` 2, `PUSHFD` 2, `LAHF` 112, `SAHF` 10, `ADC` 265,
`SBB` 1,035, `SHLD` 202, `SHRD` 199, `FSAVE` and `FRSTOR` 1 each, `FSIN` 5, `FCOS` 4, `FPATAN` 3,
`F2XM1` 1, `FYL2X` 2, `FPREM1` 2, `FSCALE` 5, `CMPXCHG` 4 (all `lock`), `CMOVcc` 67, the string
instructions with `REP` at least 520, and a scattering of SSE2 integer forms (`PADDQ`, `PMOVMSKB` and
others, single digits).

## 9. `WinThread`, read whole

A thread class with **no RTTI**: its table at `0x1208638` has no complete-object locator before
it, and follows the strings `"Thread Creation failed!"` and `"winthread.cpp"`, which `Start` uses.
The name comes from that file. Seven slots:

| slot | rva | what it does |
| --- | --- | --- |
| 0 | `0x74F500` | **Start**: only if `+8` is 0. Boxes `this` in 8 bytes, then `CreateThread(0, 0, WinThread_ThreadProc, box, 0, this+4)`; the handle goes to `+8`. Priority from `+0x1C`: 1 -> `THREAD_PRIORITY_NORMAL`, 2 -> `ABOVE_NORMAL`, else `BELOW_NORMAL`. A handle still 0 throws `CThreadException` with the two strings. Bare `ret` |
| 1 | `0x74F660` | **SetRunnable**: `+0x18` = its argument; `ret 4` |
| 2 | `0x74F670` | **Join**: `WaitForSingleObject(+8, INFINITE)`. Ghidra has no function here |
| 3 | `0x74F680` | **SetPriority**: `SetThreadPriority(+8, p)`, then `+0x1C` = p - **the raw Win32 value**, where Start reads `+0x1C` as 1 or 2; `ret 4` |
| 4 | `0x74F6A0` | **IsRunning**: `GetExitCodeThread` answers `STILL_ACTIVE` (0x103) |
| 5 | `0x74F6D0` | **Run**: 0 if the calling thread's id equals `+0xC`; otherwise calls slot 1 of the object at `+0x18`, then answers 1 |
| 6 | `0x74F4B0` | **scalar deleting destructor**: restores its table, waits `+0x14` milliseconds on the handle - and **on a timeout calls `ExitThread(0)`, ending the calling thread, not the waited one** - then closes the handle and frees on bit 0 |

`WinThread_ThreadProc` (`0x74F700`) frees the box with `free` (`0x795F9B`) and **tail-jumps to slot
5 with its own parameter still on the stack**. Run ends in a bare `ret`, so the thread procedure
returns to the kernel without popping the 4 bytes a `WINAPI` routine owes. That is harmless under
`BaseThreadInitThunk`'s frame, and a recompiler's callback stub has to accept it.

Not read: who writes `+0xC`, who derives from `WinThread`, and which objects are its runnables.
Neither of `Start`'s callers was found; its only reference is the table.

## What would show this wrong

The counts are the Ghidra project's. A function it never found is missing from every row, and a
body it merged with its neighbour counts once. The section 2 relocation table is the check on
that: a relocation landing in bytes nobody disassembled is either a gap or data, and 1,304 are.
The thrown-type count rests on a `push imm32` within 40 bytes before the call. The x87 and SSE
counts are by opcode byte and operand text, so an x87 instruction behind an unusual prefix would
be missed.
