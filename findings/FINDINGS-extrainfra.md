# A save that crashes on load: `extra_infra` and the province with no area

Read on 2026-11-02 from a BlackICE save that crashes as it is loaded (an Ireland game at
1937.4.1.1, `save load CTD.hoi3`), from two dumps of the crash - a minidump and, once the
maintainer set WER's `DumpType` to 2, **a full-memory dump** - and off the bytes. Addresses are
**virtual** (base `0x400000`) with the rva beside them where it helps; the process was loaded at
`0xBC0000` both times, so a live address is `static = live - 0xBC0000 + 0x400000`. Only valid for
this build of `hoi3_tfh.exe`.

**In one line.** `CMapProvince +0x5C` (`MaxInfrastructure`) is written by every building whose
effect is `MODIFIER_INFRASTRUCTURE`, the last one winning, so BlackICE's `extra_infra` (added
2026-10-26, `infrastructure = 0.05`) overwrites `infra`'s figure; areas are made from that figure
afresh only when a game is entered, so a loaded game puts ~1,600 provinces in no area, and the
AI's daily sealift pass reads the first province of the empty null area for any unit whose saved
`target` lies in one.

## 1. The crash

`ACCESS_VIOLATION` reading `0x00000000` at rva `0x4C42E1`, in `CAIUnit_MayShipUnitToArea`
(`0x8C41D0`), on two threads at once - the main thread and a TBB worker, each running
`CAIUnit::AssignAreaTargetsAndSealift` for a different country:

    0x8C42DB  mov ebx, [ebp+0x10]     ; the area, third argument
    0x8C42DE  mov edx, [ebx+0x24]     ; COwnerArea +0x24, the head of its province list
    0x8C42E1  mov edi, [edx]          ; its first province - edx is 0

`ebx` was the same pointer in both threads and equal to the global `g_null_owner_area`
(VA `0x1A85574`) read out of the dump: the `CNullOwnerArea`, which holds no provinces. The
return address is `0x8C5853`, the call at `0x8C584E` - the **keep-or-release** step of
`FINDINGS-moving.md` F.3.3, which hands the function the area of the province in the unit's
saved `target` (`CArmy +0x2E8`, through `provinces_begin[target]->+0x2B4`) with no test of its
own that the area is real.

**`MayShipUnitToArea` never tests the area's province count (`+0x2C`).** It reads the first
province of the target area in two places: at `0x8C427B`-`0x8C4281`, for `CanUnitReach`, behind
a slot-0 test of the *destination's* area and not the target's; and at `0x8C42DB`-`0x8C42E1`,
unguarded, which is the one that fired. `CAIStrategy::BuildTheatres` does test `+0x2C` for zero
(`0x8A9CD3`), so the assumption is local to this function.

The full dump names both units (the unit is the caller's `ebx`, saved at `[ebp-0x1C]` in the
callee's frame):

| thread | unit | owner | `army_role` | target | target's `MaxInfrastructure` | standing in |
| --- | --- | --- | --- | --- | --- | --- |
| 29836 | `27-y Ukrepl'onnyy Rayon`, id 2181, a division | SOV | 5 | 782 Leningrad | **100** | 46, 400, a real area of 2525 provinces |
| 14724 | `Hubei Silingbu`, id 13129, a division | CHI | 5 | 5542 Shanghai | **50** | 7541, 600, a real area of 220 |

The save gives Leningrad `infra` 9 and Shanghai 8, and both are controlled by their owner, so by
the rule `FINDINGS-supplynetwork.md` section 2 sets out - a province is in an area only with
MaxInfrastructure **above** 100 - neither should have been in the null area. The figure was not
the save's `infra`.

## 2. Who writes `MaxInfrastructure`

Five writers, as `CProvince +0x5C`'s record already says (`CMapProvince +0x5C`'s said one). The
three that matter here are the same shape:

    CProvince::LoadKey                   0x496128  cmp [building->effect + 0x24], 12  ; MODIFIER_INFRASTRUCTURE
                                         0x496152  mov [province + 0x5C], level * figure / 1000
    SetProvinceBuildingLevel             0x4A3AED  cmp [definition->effect + 0x24], 12
                                         0x4A3B0A  mov [province + 0x5C], level * figure / 1000
    CProvinceBuilding_OnLevelChanged     0x4B8024

**A plain store, with no comparison against what is there.** So the figure is that of the
*last* infrastructure building loaded or set, not of `infra`. The record's gate entry said
modifier 12 meant "the building `infra`"; it means **any building whose effect is
`infrastructure`**, and with one such building in the base game the two readings could not be
told apart. `figure` is the building's `infrastructure` value in thousandths: `infra` is 0.1,
so 100 a level; BlackICE's `extra_infra` is **0.05, so 50 a level** (its comment in
`common/buildings.txt`, "the same as infra, level for level", is not what the number says).

**A save writes a province's buildings in `common/buildings.txt` order** - every one of the
14,189 province blocks of this save does - and `extra_infra` is building no. 60 against
`infra`'s no. 21. So on load `extra_infra` always comes second and always wins. Read live in the
full dump:

| province | `infra` | `extra_infra` | MaxInfrastructure read live |
| --- | --- | --- | --- |
| 46 | 4 | - | 400 |
| 5542 Shanghai | 8 | 1 | 50 |
| 782 Leningrad | 9 | 2 | 100 |

In this save **1,666 provinces carry `extra_infra` and 1,603 of them are left at 100 or under**,
which is no area at all. 45 unit targets point at them - Shanghai alone has 33.

*Mod-able*: which buildings carry `infrastructure`, their figure, and their order in
`buildings.txt`. *Exe-hardcoded*: last one wins, and the threshold of 100 (`g_min_area_infrastructure`).

## 3. Why only a loaded game crashes

**Areas are made from scratch only when a game is entered.** `RebuildOwnerAreas` (`0x47CEF0`)
has one caller, at `0x648D48` inside `CInGameIdler::CInGameIdler` (`0x6474A0`). In play an
area changes only through `UpdateOwnerAreaOfProvince` (`0x47F540`).

`SetProvinceBuildingLevel` - the building effect BlackICE's weekly `omg_extra_infra_recalc`
decision uses (`extra_infra = -1` / `+1`, `FINDINGS-effectrun.md` 1.9) - does call it, at
`0x4A3B33`, but only with `notify` set, **only when the old figure was under 200 and the new one
is over 100**, and with the old and the new controller both the province's own. With the two ids
equal it does nothing to a province already in a real area. So **a figure that falls never takes
a province out of its area**: in play the decision overwrites Shanghai's 800 with 50 and Shanghai
stays in its area, the AI can still give a unit a target there, and nothing reads the empty list.
The record had this call as "raises a message"; it is the area update.

Load the game and `RebuildOwnerAreas` makes the areas again out of the overwritten figures, every
such province is in the null area, and the first daily sealift pass of an agent with a unit bound
for one crashes. A new game is safe until its first load, because `extra_infra` is handed out only
from 1936.1.10 and the areas were made before it existed.

**One way it can happen without a load (inferred, not seen):** a province at 100 or under that
changes controller in play leaves its area through `UpdateOwnerAreaOfProvince` and does not join
a new one, so a unit already bound for it would crash the same way.

## 4. What it costs besides the crash

Areas are what the supply network groups (`FINDINGS-supplynetwork.md`), what the AI's theatres
and fronts are made of, and what `MaxInfrastructure` itself is read for - the 200 and 300
thresholds of `EstimateAreaNeed`. After a load ~1,600 provinces, Leningrad and Shanghai among
them, are in none of them. In play, without a load, the figure is wrong in all 1,666 but the areas
are not. Neither was measured beyond the crash.

## 5. The fix in BiceLib

`BiceLib/Hooks/MaxInfrastructure.cpp`, switched on by `BiceLib.ComplexPatches.fixMaxInfrastructure()`
(2026-11-02): a jump at each of the three stores to a stub that lets the store happen and then
writes `infra`'s `level_max x effect_size / 1000` over it, `infra` found by name in the province's
building array. `SetProvinceBuildingLevel`'s join test is handed the corrected figure. Nothing
branches into the bytes the jumps cover after their first: a byte scan of every rel8 and rel32
branch in `.text` finds none, and finds `0x4B8003 jmp 0x4B8024` as its positive control.

## 6. Not settled

- *Settled since*: `CProvinceBuilding_OnLevelChanged`'s write (`0x4B8024`) is the same plain store,
  of the built building's `level_max x 1000 / 10000` - a fixed tenth, not the building's figure,
  so for `extra_infra` it would write 100 a level where the other two write 50. It is the
  construction path, and `extra_infra` is never built by hand.
- Which of a province's two `extra_infra` figures LoadKey takes (`level` is the building's
  `+0x20`, the built level); the two agree in all but 8 provinces here.
- The dump does not say what puts `army_role` 5 units on the keep-or-release path and not
  others; 45 targets point at no-area provinces and two crashed.
