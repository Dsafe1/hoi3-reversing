# The new-unit button: an empty unit, or a split

*Read 2026-11-04 for OpenHOI3's single unit panel, by the session building it, straight off the bytes with
`scripts/disasm.py`, `scripts/vtable.py` and `scripts/findRefs.py`. Only valid for this build of `hoi3_tfh.exe`.*

**Synopsis.** The aim was to settle what the single panel's `newunitbutton` does. The record had its greying only in
part ("among other things") and the tail of `CSingleUnitButtons::Update` unfollowed. It is now read whole, and the
button turns out to be **two**: a plain click makes **an empty unit beside the selected one and opens the reorganise
window between them** - which is why that window disbands an empty unit at its close - and **Ctrl and a click split the
unit into a unit for every brigade but its last** (`CUnitSplitCommand`), each new one taking the old unit's *first*
brigade. A land split takes the leader off the old unit and every new one. `CSingleUnitButtons::Update` is revised: its
greying of the button made exact, and its tail read.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| `0x35E820` | `CSingleUnitButtons::OnNewUnitButton` | new | confirmed | the click: Ctrl splits, else an empty unit is made and waited for |
| `0x1EB540` | `CUnit_MaySplit` | new | confirmed | Ctrl's test: more than one brigade, idle, at base, no headquarters |
| `0x1EAD70` | `CUnitSplitCommand::Execute` | new | confirmed | a unit per brigade but one; land leaders off; the player's selection |
| `0x1EB970` | `CUnitSplitCommand_MakeUnit` | new | confirmed | the new unit: kind, level, owner, province, base, parent |
| `0x1EB620` | `CUnitSplitCommand_TakeSubUnit` | new | confirmed | the transfer's move, without its message or its lone-brigade rule |
| `0x35EC40` | `CSingleUnitButtons::Update` | revised | confirmed | `newunitbutton`'s greying exact; the tail that opens the reorganise window |

The fragment touches no struct field. `CUnitSplitCommand +0x3C` (the unit), `+0x64` (new_units_id, 8-byte id pairs) and
`+0x74` (select, the constructor's third argument) are named in the prose only.

## 1. When the button is greyed

In `CSingleUnitButtons::Update`, at the first that holds:

1. a land unit with **one brigade or fewer - two or fewer where its leader is real**;
2. in a battle;
3. an AI agent on the unit or on any unit above it;
4. on loan;
5. a fleet or an air unit carrying anything;
6. a land unit aboard a fleet or a plane;
7. an attack delay;

and otherwise **enabled only where the screen's slot 51 answers 1 and the unit has more than one brigade**. Slot 51 is
taken to be the number of units selected, *inferred*: the single panel is only up for one. A custom game's lock greys it
first.

## 2. The click

`CSingleUnitButtons::OnNewUnitButton` (`0x35E820`), the handler of the glue at the strip's `+0x360`:

- **With Ctrl held**: where `CUnit_MaySplit` says yes - more than one brigade, no battle, no path, a fleet or an air unit
  at its own base, a land unit whose `army_role` is not 0 (a headquarters) - a fresh id pair is taken for each brigade but
  one and **one `CUnitSplitCommand(unit, ids, select 1)`** posted.
- **Without**: only where no new unit is waiting, a fresh id is taken and kept, and **a `CCreateUnitCommand`** posted -
  the owner, that id, the unit's province, kind 0, 1 or 2 by land, naval or air, the unit's base's province or -1, and
  `is_allowed_empty` 1. **A land unit at any level gets a division**: kind 0 is made at `oob_level` 4.

**What follows a plain click** is `Update`'s tail: once the waiting id is found, it is cleared, the new unit is **added
to the selection**, **the reorganise window opened** - `OnReorganiseButton`, so the selected unit is on the left and the
new one on the right - and, where the selected unit has a parent and `CUnit_MayTakeSubordinate(parent, the selected
unit, 0)` says yes, **a `CAttachUnitCommand` puts the new unit under that parent**. The test asks about the selected unit,
not the new one, so a commander already holding five land units still takes it.

## 3. The split

`CUnitSplitCommand::Execute` (`0x1EAD70`) tests nothing of the button's. With `n` the brigades less one:

1. too few ids: logged, nothing;
2. for each of `n`: **a new unit** (`CUnitSplitCommand_MakeUnit`) - the old one's kind and **level**, its owner, allowed
   empty, no name yet, in its province, at its base, under its parent where the parent may take it - and then **the old
   unit's first brigade** moved into it (`CUnitSplitCommand_TakeSubUnit`). Each step takes whatever is first at the time,
   so **a first brigade that may not go is tried and refused every time**, leaving every new unit empty; the new unit's
   `is_allowed_empty` is cleared either way, so an empty one goes in the hourly pass;
3. **a land unit**: the old unit and every new one get the null leader;
4. the player's unit: the interface told, and with `select` set **the selection becomes the old unit and the new ones**,
   in that order.

The move (`CUnitSplitCommand_TakeSubUnit`) is `CTransferSubUnitCommand::Execute`'s - `CUnit_CanTakeSubUnit` with one
province asked, the brigade moved, the best leader for a receiver not land or of more than one brigade, the receiver
named by its first brigade, a carrier's air groups taken along - with three differences: **no `TRANSFEREDSUBUNIT`**,
**the old unit loses its leader only when left empty** (the transfer also takes it from a land unit left with one), and
**the receiver always looks for a battle** (the transfer only when it holds one brigade).

So in the base game a split land division keeps its last brigade, its leader goes, and the new single-brigade divisions
have none - and with the units leaderless, `AssignBestLeader` was never asked of a land one.

## 4. What is not established

- The screen's slot 51, read as the selection's count.
- `0x739BC0` and `0x739C30`, the interface calls that tell of the units: not read.
- The air branch of `CUnitSplitCommand_MakeUnit`'s broadcast past `0x5EBD8D`.
