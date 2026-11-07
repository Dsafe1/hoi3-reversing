# BiceLib's oldest patch sites, read off the bytes

Read out of `hoi3_tfh.exe` on 2026-11-07, statically, for the review of BiceLib's 2024-2025 code.
**Every address here is an rva** (image base `0x400000`, `VA = RVA + 0x400000`). Only valid for
this build.

**Why this exists.** Twenty-six records in `ghidra/project.json` - every site of the DLL's oldest
hooks and byte patches, and `CLeader::AddTrait` - were marked `confirmed` with nothing behind them
but `BiceLib/bice.cpp` or `BiceLib/Patches.cpp`: the code that uses the address was the only
evidence for the address. This file is the reading that replaces that, site by site, and what
the reading turned up.

**In one line.** All the sites hold what the DLL expects; three of the hooks read their inputs from
somewhere other than where they thought - one from a stack slot that is the caller's register, one
from a register a virtual call is free to clobber, one from a register that does not hold what it
was said to - and the installed executable is **not vanilla**: it carries one of the byte patches
on disk, and so does every reading taken from it.

---

## 1. The installed executable has been patched on disk

The fact base's `scripts/image.py` reads the executable `scripts/roots.py` finds as `GAME`, which
is the install. An untouched copy (the Paradox build, file date 2013-01-03, 21,011,968 bytes) was
set against it byte for byte. **They differ in 17 bytes, in two runs, and nowhere else:**

| rva | vanilla | installed |
| --- | --- | --- |
| `0xDCBD3` | `01 86 D0 0A 00 00 79 06 89 9E D0 0A 00 00` | `C7 86 D0 0A 00 00 00 00 00 00 90 90 90 90` |
| `0xDCC12` | `01` | `19` |
| `0xDCC18` | `89 9E D0 0A 00 00` | `90 90 90 90 90 90` |
| `0xDE3ED` | `89` | `01` |

These are BiceLib's war exhaustion and minister tech decay patches (sections 4 and 5) - except
`0xDCC12`, where the install holds a byte the DLL never wrote. Something wrote them to the file
itself; the install also holds `zDsafe_ExePatcher.exe`.

**So every disassembly of those four sites taken from the install showed the patch, not the game.**
Elsewhere the two files agree, and every other site below was read from both.

**Later the same day the maintainer put the vanilla executable back in the install**, and it is
now byte-identical to the untouched copy - so `image.py` reads vanilla again, and the table above
is a record of what the install held, not of what it holds.

## 2. The hook sites

Each row: the bytes vanilla holds, which the DLL now checks before writing; the function; what is
in hand. "Replayed" means the stub runs the replaced instructions itself before resuming.

| rva | bytes | in | what is in hand |
| --- | --- | --- | --- |
| `0x1D7CDC` | `89 47 6C 39 5F 68` - `mov [edi+0x6C], eax; cmp [edi+0x68], ebx` | `CPromoteLeaderCommand::Execute` | EDI the leader, EAX the new rank. Replayed |
| `0x17FF08` | `83 C1 2C 8D 7C 24 0C` - `add ecx, 0x2C; lea edi, [esp+0xC]` | `CLeader::SaveContents` | ECX the trait (`mov ecx, [ebx]` at `0x17FF03`, a node's data); `+0x2C` is its name |
| `0x365688` | `8B F0 8B CE 83 C4 0C` | `CLeaderAssignmentEntry::CLeaderAssignmentEntry` | EAX the buffer the runtime's integer-to-text call (`0x79A0C4`, given the skill, the buffer and 10, `cdecl`) filled. **The leader is `[ebp+0x14]`** - section 3 |
| `0x3679D4` | the same seven | `CLeaderAssignmentPanel::CLeaderAssignmentPanel` | EAX the buffer. **The leader is `[ebp+0xC]`** - section 3 |
| `0x1B9733` | `83 7D 08 05 5F` - `cmp dword ptr [ebp+8], 5; pop edi` | `CUnit_MayTakeSubordinate` | EBX the unit to attach, **EDI the last subordinate counted**, `[ebp+8]` the count - section 6 |
| `0x166560` | `3B F2 0F 8D 8E 00 00 00` - `cmp esi, edx; jge 0x1665F6` | `CNavalCombatant::ApplyCombatModifiers` | ESI screens, EDX capital ships (already > 0, `0x166558`), `[esp+0x1C]` the penalty, set to EBX (zeroed at `0x1664E9`) at `0x166554` |
| `0xF0F22` | `8B 8E 30 03 00 00` - `mov ecx, [esi+0x330]` | `CCountry::UpdateIC` | ESI the province, EBX the country, EAX the province's term `base * (1000 + local) / 1000` from `0xF0EFD` |
| `0xF0F9D` | `89 83 04 06 00 00` - `mov [ebx+0x604], eax` | `CCountry::UpdateIC` | EAX the sum in whole IC (`/1000` by `0x10624DD3` at `0xF0F8B`), ECX `[ebx+0xDA8]` |
| `0x17E4E5` | `84 C0 0F 84 CA 00 00 00` - `test al, al; je 0x17E5B7` | `CBuildingDeployment::CanDeployIn` | AL `CCountry::IsBuildingAllowed`'s answer, EDI the deployment, EBX the province - section 7 |
| `0x83020` | `3B 46 18 73 CC` then `8B F0 83 C0 0C 39 16` | `CBrigadeConstructionDefinition::LoadKey` | as FINDINGS-buildqueue.md section 10 has it; the append at `0x8302E` is `8B 5F 04 6A 10` |

Two more, of the same functions:

- **`0x1665F6`**, `cmp byte ptr [ebp+0xC], 0`, is where both exits of the screen penalty's scale
  meet - the `jle` at `0x16655A` and the `jge` above. Nothing from there reads EDX or EAX before
  setting them (`mov edx, [esp+0x18]` at `0x166600`), as the scale's own end leaves both changed.
- **`0x1B9705`**, `test esi, esi; je 0x1B974B`, follows `mov esi, [esi+0x1E4]` - the commander's
  first subordinate node. With none the function answers true before the loop and before it
  pushes EDI, so the hook at `0x1B9733` is only ever reached with a subordinate counted.

`[ebx+0xDA8]` in `UpdateIC` is `CCountry::global_modifier` (`+0xD90`) plus `CModifier::values`
(`+0x18`): the global modifier's value array, read directly by the compiler. `[ecx+0x78]` is
then its `IC` entry (type 15, eight bytes each) and `[ecx+0x88]` at `0xF0FAF` entry 17,
`GLOBAL_IC`. The province's `[esi+0x114]` is the same thing for `CMapProvince::modifier`
(`+0xFC`), and `[+0x78]`, `[+0x80]` its `IC` and `LOCAL_IC`.

## 3. The leader list read a stack slot that is not the leader

**`0x365688`.** The old hook took the leader from the game's `esp+0xC`. Counting the constructor's
stack: `push ebp; mov ebp, esp`, three dwords of SEH frame, `sub esp, 0xB8`, then `push ebx; push
esi; push edi` - so `ebp-0xD0` is where `edi` was saved - and the three arguments `_itoa` was given
are still on the stack at the hook (`add esp, 0xC` is one of the replaced instructions). So
`esp+0xC` at the hook is `ebp-0xD0`: **the caller's EDI**, not anything of this function's. It
held the leader only when the caller happened to keep one there, which is where the old code's
"for some reason the trait filtering causes a 0 leaderAddress" came from.

The game reads the leader from `[ebp+0x14]` (`mov edx, [ebp+0x14]; mov eax, [edx+0x70]` at
`0x365666`) - the constructor's fourth argument, as the record's signature has it - and that is
what the rewrite reads. *Inferred* for the slot (stack arithmetic, with every call between assumed
balanced); *confirmed* for `[ebp+0x14]`, which is the game's own read.

**`0x3679D4`.** `[ebp+0xC]` is the panel constructor's `unit` argument - but at `0x367922` the game
loads it, reads `[unit+0x12C]` (`CUnit::leader_ptr`) and **stores that back into `[ebp+0xC]` at
`0x367935`**, and reads the leader from there at `0x3679B2` (`mov edx, [ebp+0xC]; mov eax,
[edx+0x70]`). So `[ebp+0xC]` is the leader at the hook, as the old code had it. The function runs
unbroken from `0x3671A0` - no other prologue or padding before the site.

Neither place tests the leader for null before reading `+0x70`.

## 4. The minister tech decay patch is in the modifier rebuild, not an effect handler

`0xDE3ED`, vanilla `89 04 31` - `mov [ecx+esi], eax` - is inside `CCountry::RebuildStaticModifiers`
(`0xDDD80`), not "the `decay` effect's handler" as FINDINGS-techdecay.md section 4 and its open
questions put it. The rebuild:

1. zeroes `CCountry +0x1174[category]` for every category (`mov dword ptr [edx], 0` at `0xDDFBA`);
2. walks the cabinet (`+0x618` to `+0x61C`) and **adds** each minister's figure per category
   (`add [eax+edi*4], edx` at `0xDE37B`);
3. walks the categories again and **stores** `technology_status (+0xDF8) -> +0x1F8 [category]`
   over each one (`0xDE3D0` to `0xDE3F2`).

So step 3 threw step 2 away. The patch turns the `mov` into `add` (`01 04 31`), so the total is the
ministers' plus the technology's, and step 1 keeps it from accumulating across rebuilds.

## 5. War exhaustion: one byte of the patch never did anything

In `CCountry::UpdateMonthly`, vanilla adds the month's war exhaustion to `+0xAD0` (`add [esi+0xAD0],
eax; jns +6; mov [esi+0xAD0], ebx` at `0xDCBD3`, a floor at 0), caps it at `0xDCBE1`, and when it is
above 0 and `+0xACC` is clear, passes it by value to `0x4FBF80` and zeroes it (`0xDCC18`).

BiceLib's patch stores 0 at `0xDCBD3` and nops `0xDCC18`. It also wrote `0x01` to `0xDCC12` - the
ModRM byte of `mov [ecx], eax` at `0xDCC11`, the argument being built - which is **the byte
vanilla already holds**. The write changed nothing, and the record's name for it was an
instruction that does not start there. The install's `0x19` (`mov [ecx], ebx`, passing 0) is not
the DLL's. Neither matters while the first site stores 0: `cmp eax, ebx; jle` at `0xDCC09` skips
the call. The DLL no longer writes that byte.

## 6. The attachment limit read ECX where EDI holds the unit

The loop counting a commander's subordinates (`0x1B9710` to `0x1B9731`) loads each one with `mov edi,
[esi]`, sets `ecx` to it for a virtual call (`call [edx+0x3C]`), and moves on. The old hook took the
"last subordinate counted" from **ECX** - which after that call is whatever the callee left there.
It held the unit because that slot happens to be a getter that does not touch ECX. **EDI** is the
same unit and callee-saved; the rewrite reads it.

The count lives in `[ebp+8]`, the subordinate argument's own slot, cleared at `0x1B96FE` once EBX
holds the argument.

## 7. `IsBuildingAllowed` asks more than the hook answers

`0x17E4E5` replaces the test of `CCountry::IsBuildingAllowed` (`0xDFFC0`), called at `0x17E4E0`
with the building `[edi+0x38]` (`CBuildingDeployment +0x38`, pushed at `0x17E4D9`) and the
province. The record already has that function whole; what matters here is that it refuses six
things, of which research is only the first:

1. a building the country has not been given - `technology_status -> +0x28C [index]`, the index
   read at `CBuilding +0x54` (`0xDFFDD`);
2. for any building but the underground, a province the country does not control - its id
   (`+0xCA8`) against `[province+0x338]` at `0xE0057`;
3. a province whose whole levels (`buildings[index] -> +0x20`, `/1000` at `0xE0077`) plus the
   levels queued for it reach `CBuilding +0x68`, `max_allowed_level` (read at `0xE007E`);
4. a port building where the province has no port;
5. a building of its `not_if_x_exists` list already standing there;
6. a missing prerequisite.

The hook skips the call's answer and asks a cut-down third question in its place - the level
already there against `+0x68`, with nothing queued counted - so it skips all of the others too. The refusal
target `0x17E5B7` and the resume `0x17E4ED` (after the eight bytes) are the `je`'s two outcomes;
the old hook resumed at `+6`, inside its own nop padding.

### 7.1 What the hook stands on since, so that only research is waived

Rewritten the same day to leave the game's other five questions in place. **Only
`CanDeployIn`'s call is affected**: `IsBuildingAllowed` has four other direct callers -
`CConstructBuildingCommand::IsValid` (`0x14562D`), `CBuildingMember::OnClick` (`0x2DC0F0`) and
`CBuildingMember::Update` (`0x2DC558`, `0x2DC66C`), the production screen's building buttons -
and research must keep counting for queuing a construction. `CanDeployIn` itself has no direct
caller; it is `CBuildingDeployment`'s slot 10, so every way a waiting building is placed reaches
it through the table. Slot 9, `DeployAt` (`0x17E640`), does the placing and does not ask again.

- **`0x17E4E0`**, `call 0xDFFC0` (`E8 DB 1A F6 FF`), becomes a jump to a stub that raises a flag,
  makes the same call - ECX and the two arguments are as the game left them, and the callee's
  `ret 8` takes the arguments - lowers the flag and resumes at `0x17E4E5`, the vanilla `test al,
  al`.
- **`0xDFFF0`**, `cmp byte ptr [eax+edx], 0; jne 0xE000B` (`80 3C 10 00 75 15`) - the research
  test, EAX the building's index (`+0x54`, from `0xDFFDD`) and EDX `technology_status ->
  +0x28C` - becomes a stub that goes straight to `0xE000B` while the flag is up and otherwise
  makes the test itself; its false way is `0xDFFF6`, `xor al, al`. Neither target reads the flags.

## 8. `CLeader::AddTrait`

`0x181A60`: `push ebp; mov ebp, esp`, the leader from `[ebp+8]` and the trait from `[ebp+0xC]`,
both exits `ret 8` (`0x181C2A`, `0x181C44`), nothing taken from ECX:
`void __stdcall AddTrait(CLeader* leader, CTrait* trait)`. Before anything is added it tests a
byte at `trait + leader_type + 0x2B0` (`cmp byte ptr [eax+esi+0x2B0], 0`, EAX the leader's `+0x68`)
- three bytes on the trait, one per leader type.

## 9. The other byte patches

- **`0x4B348A`** `0F 85 91 05 00 00` and **`0x4B37E5`** `0F 84 32 02 00 00`, both in
  `CAIUnit::ManageExpeditions`: a `jne` and a `je` the DLL makes `90 E9` - a nop and a jmp with the
  same displacement, which ends at the same byte and so lands on the same target.
- **`0x1832A8`** `F7 D9` and the `CC` padding at **`0x1832D4`** - CHistoricalModel.hpp's account,
  confirmed against vanilla. The `jmp +0x2A` lands on `0x1832D4` and the `jmp -0x32` after the
  six-byte `mov` lands on `0x1832AA`, the `add eax, ecx`.
- **`0x266E74`** `C7 80 F4 00 00 00 08 00 00 00`, as FINDINGS-mapmode.md has it.

**`0xF0F90` and `0xF0FA9`** were the sites of an earlier offmap IC fix, a byte patch the DLL had
long stopped calling and that is now deleted. Read for what they are: `imul dword ptr [ebp+8]`
with `0x10624DD3` in EAX, the first step of dividing the summed provincial IC by 1000, and
`imul eax, eax, 0x3E8`, the stored total back in thousandths for the next term.

## Not settled

- Whether anything but the deploy menu reaches `CBuildingDeployment::CanDeployIn`, and whether
  the menu offers only the player's own provinces - which says how far section 7's skipped checks
  reach in practice.
- What wrote the install's `0x19` at `0xDCC12`.
