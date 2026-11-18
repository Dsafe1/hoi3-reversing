# The order of a unit's sub units: `priority`

Read 2026-11-18 for OpenHOI3, after the maintainer found BlackICE's infantry divisions showing the division headquarters on
their counters; fragment `subunit-priority.json`. The insert's loop and its call in AddRegimentToUnit were checked off the
listing by the collecting session. All addresses VA unless marked rva.

## 1. The insert (`CList_InsertSubUnitByPriority`, rva 0x1D4AA0)

`void __stdcall (CList<CSubUnit*>* list, CSubUnit** regiment)`, 0x5D4AA0..0x5D4B66, three `ret 8`. Unrecorded until now; the
record's nearest entry, CList_RemoveNode (rva 0x1D49D0, 86 bytes), ends before it.

    node = list->tail (+4)
    while node and node->data->definition (+0x58)->priority (+0x194) < (*regiment)->definition->priority:
        node = node->prev (+4)
    if node is null: CList_PushFront(list in ESI, regiment)          ; 0x45F5E0, recorded
    else: a new node {*regiment, prev = node, next = node->next, 0} after it (the tail where node was), count (+8)++

So a list built only through it is in **descending priority, equals in the order they were put in**. `priority` is the plain
int CSubUnitDefinition::LoadKey stores with `atoi` (0x5A3D44..0x5A3D53), so `2.9` is 2. Two callers only (findRefs
--callers): AddRegimentToUnit (0x5BE6B0) and CWindowForSubUnitsEntry::Fill (0x755023).

## 2. Every way into a unit goes through it

AddRegimentToUnit (rva 0x1BE640) calls it at 0x5BE6B0 with `lea eax,[edi+0x38]` - the unit's `regiments` - before it writes
`unit_ptr`, redoes the counters and rebuilds the definition. Its 20 callers: CUnit::LoadKey (regiment, ship, wing - the
order-of-battle and save reader), CMilitaryConstruction::Deliver, CUnitDeployment::JoinUnit, CUnit_MergeInto,
CTransferSubUnitCommand::Execute, CUnitSplitCommand_TakeSubUnit, CCreateHigherCommand::Execute, CCreateNewHQCommand::Execute,
CAirReserveOrder_ReinforceUnit (three), ReserveOrder_ExchangeShips (two), ResolveConvoyRaid, CreateRebelsForFaction,
ReleaseProvinces, CAddSubUnitEffect::Execute and CAddDivisionEffect::Execute. A scan of every call to the 25 recorded list and
vector inserters, plus this one, for a list argument built as `[x+0x38]` in the seven instructions before found
AddRegimentToUnit's call (the positive control) and three unrelated lists, nothing else. An inlined insert would not show in
that scan; the saves (section 5) are the check on that. Nothing reorders a unit's list later.

So **a unit's first sub unit is one of its highest priority**, and CUnit_GetCounterTypeKey (rva 0x1BDB60), which takes the
head's type, shows that one. Nothing picks a picture by priority; the order does it.

## 3. The unit panel sorts again

CWindowForSubUnitsEntry::Fill (rva 0x354430) copies the unit's `regiments` node by node into a local CList through the same
insert (0x754FF5..0x75502A), makes a CSubUnitEntry (0x748D90) for each node of the copy (0x75517C..0x7551D7) and frees it
(0x50D1E0). Since the unit's list is already in that order, the rows are the unit's order. (`functionStart` inside it answers
0x754230: trap 2 - 0x75442D `ret 4` abuts 0x754430.)

## 4. Every reader of `+0x194`

`fieldchain.py --field 0x194` (a disp32 byte search): 443 sites, 167 off a non-stack base, each read in place. On a
CSubUnitDefinition:
- the insert (section 1), twice;
- CPrioComparator::Compare (rva 0x3D76D0) - the division designer, largest first (`FINDINGS-builders.md`);
- CUnit::BuildTooltip, `cmp [edi+0x194],5` at 0x5C591A - the counter tooltip's named types at intel 3-5
  (`FINDINGS-countertooltip.md`);
- CAreaEntry::BuildStep, CTheatreView::BuildStep, CAINeedEntry::BuildStep: `cmp [x+0x194],5; jl` - the theatres screen's and
  the AI needs' split at 5;
- CNavalCombatant::PickBestTarget (0x56754A) and CAirCombatant::BestTarget (0x56D53E) - a target's worth;
- copies in CSubUnitDefinition::Assign and Add (where it is summed, `FINDINGS-unitdef.md`) and in
  CTechStatistics::BuildEffectsText.

The rest are other classes' `+0x194` - a builder's selected type, CDefines blocks (CNavalCombatant::Attack's
`[0x1A86040]+0xAC`), battle plans, map and GUI objects, CUnit::FaceNextProvince's own field. The known readers
(PickBestTarget, BestTarget, the tooltip, CPrioComparator) all appear in the scan: the positive control.

## 5. The saves

A scan of every unit block (regiment, ship and wing types against `units/*.txt`'s priorities):
- **None out of order** among the 50 base-game saves the original wrote in the maintainer's folder, nor among the 19 BlackICE
  ones, apart from four types older BlackICE saves hold that today's files no longer declare - hundreds to over a thousand
  units of mixed priority a save.
- Their Finest Hour's `ENG_1936.txt` lists the 5th Indian Infantry as infantry, infantry, gurkha (7, 7, 9);
  `Germany1936_01_01_00.hoi3` has the gurkha first. The Home Fleet's carrier (10) leads its six battleships (9).
- BlackICE: `division_hq_standard` is 1 and `infantry_brigade` 83, and the files list the headquarters first; the original's
  BlackICE start save (`Ireland1936_01_01_00.hoi3`) has the infantry first in every such division. Its German infantry
  divisions lead with a `GER_x_ID` brigade of priority 200, as the original's save shows.
- The folder's other three saves are out of order exactly as the history files list them, and are OpenHOI3's.

## What this means for a mod

`priority` in `units/*.txt` decides a unit's brigade order, and so its counter, its panel's first row and everything that asks
for a unit's first brigade: the headquarters radio, garrison tests in the AI, naming. Highest first; equal priorities keep the
order they joined in. *Mod-able*: the key. *Hardcoded*: the order, the tie rule and `atoi`.
