# The merge button: what a merge does

*Read 2026-11-04 for OpenHOI3's merge button, by the session building it, straight off the bytes with
`scripts/disasm.py`, `scripts/vtable.py` and `scripts/findRefs.py`. Only valid for this build of `hoi3_tfh.exe`.*

**Synopsis.** The aim was to settle what `CMergeCommand::Execute` does, which the record had as `inferred`
(`FINDINGS-selection.md`, section B.4), and how `CUnit_MergeInto` settles two units' leaders. Execute is now
`confirmed`: **it tests nothing** - the button's greying by `UnitList_MayMerge` is the only gate - and it picks
the unit merged into by brigades x 10, plus the strength share **in tenths, cut toward nought**, plus the
leader's skill x 2, the highest strictly and so the first of equals. The share's divisor is the brigades' summed
`max_strength` (`CUnit::GetTotalMaxStrength`, slot 23), not slot 25's mean share as the record's comment
suggested. `CUnit_MergeInto` keeps the giver's leader where the taker has none or where his skill is strictly
higher. One new function, `CLeader_SetCommandedUnit`.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| `0x1DB9E0` | `CMergeCommand::Execute` | revised | confirmed | was `inferred`; the score's terms exact, no test, removal flags, the leader tail |
| `0x1CDC90` | `CUnit_MergeInto` | revised | confirmed | "the better leader kept" made exact; the passengers' fields named |
| `0x1801E0` | `CLeader_SetCommandedUnit` | new | confirmed | frees a leader's old unit and gives him a new one |

The fragment touches no struct field.

## 1. The command

`CMergeCommand` has no validity slot: of its overridden slots, 7 is `mov eax, 0x382; ret` (its type), 13 a clone and 14
the save (`vtable.py CMergeCommand`). So what the button posts runs.

**Execute** (slot 6, `0x1DB9E0`):

1. Walks the command's list of units, each an id pair resolved through the persistent tables; a unit gone is skipped.
2. Scores each:
   - `regiments_count x 10`;
   - plus `(share x 10000 / 1000) / 1000`, where `share = sum of the brigades' strength x 1000 / GetTotalMaxStrength`,
     or -1 where the total is 0 - **the share in tenths, cut toward nought**, so a unit at 95% gets 9;
   - plus, where it has a real leader, `skill x 2000 / 1000` - twice the skill.
3. Keeps the highest **strictly above** the best so far, which starts at 0: the first of equals wins, and where nobody
   scores above 0 the list's first unit is taken.
4. Merges every other unit into it (`CUnit_MergeInto`, section 2) and removes it, `CGameState::RemoveUnit(it, false,
   true)` - passengers with it, though a merge of two fleets has already moved them.
5. Where the unit merged into has no real leader and its country's `auto_assign_leaders` is set,
   `CUnit::AssignBestLeader`.

There is no message.

`CUnit::GetTotalMaxStrength` (`0x1C6520`, slot 23) sums each brigade's definition `max_strength`; the strength term
is the whole unit's share, not a mean of the brigades' shares.

## 2. One unit into another

`CUnit_MergeInto(into, from)` (`0x1CDC90`), read whole:

- the two the same: nothing;
- **every brigade** of `from`, in its order, to `into`;
- **both fleets**: every land unit `from` carries goes to `into`, its carrier set and its dig-in and staging province
  cleared. **Both air units**: what `from` carries likewise, its plane set and its target cleared. Otherwise passengers
  stay on `from`;
- **the leaders**:
  - `into` with none and `from` with one: `into` takes his, his banked trait hours thrown away and no organisation
    lost (`SetLeader(his, 1, 0)`);
  - both with one and `from`'s skill **strictly** higher: `into`'s is freed (`CLeader_SetCommandedUnit(his, null)`), then
    `into` takes `from`'s the same way;
  - otherwise each keeps his own, and `from`'s goes free when `from` is removed;
- `into` rebuilt - its combined definition, its counter - and put back into its province.

The join-fleet and join-air orders call the same routine, so an AI fleet joining another keeps the better admiral too.

## 3. What is not established

- Whether the busy flag both units carry for the length (`+0x48`) is read by anything during it.
- The merge button's shortcut `g` (`unitpanel.gui`) was not traced: whether a key press on a greyed button is refused
  is the interface's general rule, not this button's.
