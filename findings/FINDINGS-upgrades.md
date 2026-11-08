# Changing a brigade's type: `unit_upgrades.txt`, `CUpgradeRegimentCommand` and the line it makes

Read 2026-11-08 for OpenHOI3. All statements are `confirmed` off the listing or the decompilation unless marked. Addresses are VAs (image base 0x400000); `project.json` uses rvas. **This is not the upgrade share of IC** (`CDistributeUpgrade`, which raises technology levels) but the order that replaces a brigade with one of another type. Figures are tagged `hardcoded` (in the executable) or `mod-able` (a define or file, named).

## 1. `common/unit_upgrades.txt` and `CSubUnitDataBase +0xB0`

Read at the end of `CSubUnitDataBase::LoadDefinitions` (VA 0x5AE1C0), after every sub-unit type is known. `upgrade_targets` (+0xB0) is first resized to the number of types (0x5B0339 → 0x5B1D00): one 16-byte vector per type, in type-index order (`CSubUnitDefinition +0x24`).

The file must open with `unit_upgrades` or it is dropped whole. Inside it, each `upgrade = { base = X target = Y }` is read to `}`; any other key in the block is ignored and the last `base` and `target` win. Where both strings are non-empty and both resolve in the by-name table (+0x10), Y's index is `push_back`ed onto X's vector (0x4221F0): no check for duplicates, no check for X = Y. Anything that names no type is dropped in silence. (`hardcoded` grammar; `mod-able`: the file.)

**The transitivity the file's header claims is real**, and is done once, after the whole file: `CSubUnitDataBase_CloseUpgradeTargets` (VA 0x5B06A0).

  repeat
    changed = false
    for each type i, in index order:
      n = length(list[i])              ; taken before the walk
      for k in 0 .. n-1:
        j = list[i][k]
        m = length(list[j])            ; taken before this inner walk
        for each t in list[j][0 .. m-1]:
          if t not in list[i]: append t to list[i], changed = true
  until not changed

**The order that shows in the list** is: the file's own order for that type, then whatever the passes append. Because a type earlier in index order has already been extended when a later one is visited in the same pass, the appended order depends on type-index order. A cycle puts a type on its own list. With the shipped file, `infantry_brigade` reads marine, bergsjaeger, paratrooper, engineer, motorized (the file's five), then mechanized (motorized's). Longer chains (cavalry→light_armor→armor→heavy→super_heavy) append later and where exactly falls by index order.

## 2. `CUpgradeRegimentCommand` (save token `upgrade_regiment`, 0x762)

Fields: +0x3C/+0x40/+0x44 the brigade's reference (cached pointer, id), +0x64 the target type index. Save keys `sub_unit`, `target` (slot 2, VA 0x5DB070; load 0x5DB110). Constructor with arguments VA 0x5DA710; callers are `CSelectUpgradeEntry::OnClick`, `CInGameIdler_UpgradeSelectionTo` and the Lua binding (0x9891E7). A grep of the install's and BlackICE's `.lua` finds no script that uses it, so **the AI never upgrades by this route** (the negative is a grep of those files only; the C++ AI's callers are the two interface sites plus Lua).

**Slot 14, IsValid (VA 0x5DB250):** the brigade resolves, `CSubUnit_MayUpgradeWhereItStands`, and `CCountry::CountMaxUnitsStillBuildable(the unit's owner, target) >= 1`. It does not ask whether the target is on the brigade's upgrade list; that is only the interface's filter. Men and IC are not asked either.

**Slot 6, Execute (VA 0x5DA7C0)**, in order; nothing is tested beyond the brigade existing and having a unit:

1. New `CMilitaryConstruction` (0xAC): line id from the counter (type 0x29 family, as the build queue's), the unit id the next number, the counter moved on 3 (`FINDINGS-buildqueue.md`, section 1); country the brigade's owner; Size 1; target (+0x90/+0x94) the unit's id; `is_reserve` the brigade's `is_reserve`.
2. `share = min(trunc(strength * 1000 / DefaultStrength(brigade's own definition, +0x58)), 1000)`, or -1 where DefaultStrength is 0 (`hardcoded`).
3. A new item (`CBrigadeConstructionDefinition`, 0x54) of the target type: id fresh from the counter (0xA9D6B0). **Model:** for each technology in the *target type's* list, the owner's current level (`level_by_technology`), at the moment of the order. **Name:** the old brigade's name (its slot 8); the old brigade's name is released and re-registered on the item, so it stays taken. **Experience:** `max(brigade.experience, 0) + (pride ? PRIDE_BONUS_EXP : 0)` (`mod-able`: `PRIDE_BONUS_EXP`, 10 in defines.lua, stored in thousandths). **upgrading_from (+0x38):** the database's plain type found by the brigade definition's name (0x482C80), never the brigade's own technology-laden copy. **upgrading_from_strength (+0x3C):** `share`.
4. Manpower: `back = trunc(GetBuildCostManpower(owner, brigade.definition, is_reserve) * share / 1000)`, added to `Manpower`, floored at 0. `cost = GetBuildCostManpower(owner, the new type's built definition, is_reserve)` is stored in the line's `manpower` and taken off `Manpower`, floored at 0. **A shortage of men never refuses it** (the pool stops at 0). `UpdateManpowerAfterMobilising`.
5. `builder` = owner; `location` = the acting capital (cleared again by `EnqueueConstruction`); `SetReservesFactor`; `RecalculateCost`; `EnqueueConstruction`; `CDistributeProduction::UpdateNeeded`.
6. `CUnit_AddUpgradeLine(unit, line)`.
7. **`RemoveRegimentFromUnit` and `CGameState::DisposeSubUnit`: the brigade is gone now.** A unit left with no brigades is left so here; what becomes of it is the ordinary rule for an empty unit, not read here. For the player's own unit the interface is told (0x739BC0).

There is no message.

## 3. The queue line's price and time

`CMilitaryConstruction::RecalculateCost` (VA 0x485300), upgrade arm: taken where the first item's `upgrading_from` (+0x38) is set. It runs at every occasion the line is priced (`FINDINGS-buildqueue.md`, section 2).

  new = MakeDefinition(item)                 ; the new type's definition with the item's levels applied, levels = their sum
  icNew = GetBuildCostIC(country, new, levels, is_reserve)
  icOld = GetBuildCostIC(country, upgrading_from, levels, is_reserve)   ; the old type at the NEW levels
  credit = trunc(trunc(UNIT_UPGRADE_COST * upgrading_from_strength / 1000) * icOld / 1000)
  cost = icNew - credit ; below 1 -> 0
  practical_factor = 1000
  if icNew != 0: practical_factor = trunc(trunc(cost * 1000 / icNew) * UNIT_UPGRADE_PRACTICAL_MOD / 1000)
  duration = trunc(GetBuildTime(country, new, levels) * 1000) - trunc(GetBuildTime(country, upgrading_from, levels) * 1000 * UNIT_UPGRADE_TIME / 1000)
  below 1 -> 0

All divisions truncate toward nought (`__alldiv`). `mod-able` (`common/defines.lua` block `military`; thousandths once stored): `UNIT_UPGRADE_COST` 0.1 in the base game, 0.4 in Their Finest Hour; `UNIT_UPGRADE_TIME` 0.7 both; `UNIT_UPGRADE_PRACTICAL_MOD` absent from `common/defines.lua` (not looked for what the engine then defaults to), 0.9 in `tfh/common/defines.lua`. `hardcoded`: the 1000-capped share, the two floors at nought.

**Refusal:** nothing in the price or the time refuses a line. The IC is paid as any line's; Size is 1 and never more.

**Its name and counter in the production queue** (`CBuildQueueEntry`, ctor VA 0x7F4140, and `CMilitaryConstruction::GetName`): `counter_type` is `GFX_counter_` + the first item's type key (the **new** type); `unit_name` is the first item's name, i.e. the old brigade's name, as `+0x60` is empty and `GetName` falls through to the first item's; `unit_target` is `=> ` + the target unit's name where the target exists. `prodqueue_progress`, `ic_cost` and the rest as for any line. Tooltip: `BRIGADE_UPGRADE_MIL_CON_INFO` etc. (`FINDINGS-productiontooltip.md`, section 5). A queue row's `cancel` button posts `CCancelUnitConstructionCommand` for the upgrade line as for any other (record of `CBuildQueueEntry::OnCancel`, not re-read here).

## 4. A finished line

`CMilitaryConstruction::Deliver` (VA 0x484A60), as for any single-brigade line (`FINDINGS-buildqueue.md`, section 4), with what the order put on the item:

- A new `CRegiment`/`CWing`/`CShip` by the item's type, with the item's own id (minted at the order, and +1 afterwards). `home` = line location, else the map's first province; `EnqueueConstruction` zeroed location, so it is the first province.
- `is_reserve` = the line's; `experience = max(item.experience, accumulated_experience)`, capped at 100000 (`hardcoded`).
- Technology levels: the item's model (the owner's at the order) by position; `ApplyTechnologies`.
- **Strength:** the type's DefaultStrength, times `reserves_factor`/1000 for a reserve, capped at `GetMaxStrength`; a brigade at 30% before an upgrade comes out full. `strength_ceiling` raised to it.
- **Organisation:** `GetMaxOrganisation(brigade, 1, 1)`, not the old brigade's.
- **Leader:** none (a brigade has none). **Pride:** the old pride is lost; only the experience bonus carried it. **History counters of the old brigade** (sunk-ship counts and so on): none copied, since Deliver writes only the fields above.
- **The practical** (`hardcoded` path, `mod-able` factor): `GainTechAbility(country, the new type's technology category, trunc(trunc(completion_size * reserves_factor / 1000 if a reserve, else completion_size) * practical_factor / 1000))`.
- The new unit is `CUnitDeployment`'d into `country.deployments`, then:

    target = FindPersistentById(line.target), if any
    if target and (CUnit_CanTakeSubUnit(target, country, new brigade, sameProvince=false)
                   or (target.oob_level == 0 and CUnit_MayTakeSubordinate(target, new unit, 0))):
        JoinUnit(country, target, true)

`JoinUnit` (`FINDINGS-deploymenu.md`) places it at the target's province (or the nearest legal one in the capital's area), moves a one-brigade unit's brigade into the target and removes the emptied unit, raising TRANSFEREDSUBUNIT for the player. **A target that is gone, has left, is in a battle, is full, on loan or otherwise unable to take a brigade** leaves the new one-brigade unit among the deployments, waiting to be placed as any finished unit. There is no other check: the line is paid for and delivered whatever has happened. The brigade is new; "the brigade no longer exists" does not apply since Execute removed it.
- The end of Deliver as for any line: a name for the type's next brigade is made and registered (`MakeSubUnitName`), `Size` drops to 0, and the line is removed.

**Cancelling** (`CCancelUnitConstructionCommand::Execute`, VA 0x548550): `size * manpower` back to `Manpower`, floored at 0; the line is taken out and freed. **The brigade is not restored: it was disposed at the order.** Nothing of the IC spent is returned. The line's destructor (VA 0x483F20, read whole) calls `CUnit_RemoveUpgradeLine` where any item has `upgrading_from` set.

**The unit's upgrade-line list and the orange mark.** `CUnit_AddUpgradeLine` at the order, `CUnit_RemoveUpgradeLine` from the destructor (finished or cancelled), and `CMilitaryConstruction_RegisterUpgradeTarget` from `CCountry::AfterLoad` to rebuild it. The orange mark (`+0x1BD`, both counters) is whether any line is left, for the played country's own units only (the existing records, `FINDINGS-counters.md`, section 10).

## 5. The single-unit panel

- **`upgrade_button`** (`single_unitpanel.gui`, in `subunit_entry`, sprite `GFX_upgrade_unit`). Visible where `CSubUnitEntry_MayShowUpgradeButton` (VA 0x74A220) answers true: not an upgrade row; the game state's `scenario` is null; not a mode-2 custom game; brigade resolves; `MayUpgradeWhereItStands`; the type's list has any target with `CountMaxUnitsStillBuildable >= 1` **for the player's country** (not the owner). Asked at the row's constructor and every frame by `CSubUnitEntry::Update`.
- **Click** (`CSubUnitEntry::OnUpgradeButton`, VA 0x74A0C0, the glue at +0x78): frame 2, then `CSingleUnitPanel_ShowUpgradeList` (VA 0x7620A0) with the panel at +0x11C. It closes any previous row's list, stores the row at panel +0x48, empties the window's `list`, and adds one `CSelectUpgradeEntry` per target in the order of `CSubUnitDataBase +0xB0` that has `CountMaxUnitsStillBuildable >= 1` for the player, then a last row with -1, then shows `list` and the window and places it.
- **Placing** (`CSingleUnitPanel_PlaceUpgradeList`, VA 0x761EF0; called at opening and from four CInGameIdler sites, so it follows a scrolled panel): the `list` inside the fixed window `select_upgrade_window` ({254, 0}, 254×240) is moved to `x = upgrade_button.x + panel.home_x (+0x50) + (row.x - panel.x)`, `y = upgrade_button.y + (row.y - panel.y)`, **and that is a place on the screen, not inside the window** (`measured` on the maintainer's screenshot, section *What was not settled*).
- **Rows** (`CSelectUpgradeEntry`, ctor VA 0x747C10): the window `select_upgrade_entry`, its button `target` shows the type's name (definition slot 6) or, for -1, `UPGRADE_CANCEL` ("Cancel").
- **Row click** (`CSelectUpgradeEntry::OnClick`, slot 4, VA 0x747F00): for a real target with the brigade still there, where the target is on the brigade type's list and buildable by the player, one `CUpgradeRegimentCommand(brigade, target)` posted through the session channel; `reshow_open_view` set unless a mode-2 custom game. Cancel posts nothing. Either way, `CSubUnitEntry_CloseUpgradeList` (VA 0x74A170): button frame 1 and, if this row holds the panel, hide (`CSingleUnitPanel_HideUpgradeList`, 0x762440). Also closed by opening another row's list, by the row's destruction (0x7491B1) and by `CSingleUnitPanel::Rebuild` (0x762780) hiding the window without clearing +0x48.

**The row of an upgrade in progress** (`CSubUnitEntry` second constructor, VA 0x7489F0): one for each record of the unit's `upgrade_lines` whose line still resolves (`CWindowForSubUnitsEntry::Fill`; **they are added before the brigades' rows**). `is_upgrade_row` set; `counter_type` the new type's counter; `upgrade_button` hidden. `CSubUnitEntry::Update` each frame: `subunit_name` = `UNIT_UPG_PROGRESS` ("Upgrading progress $PROG$%") with PROG the percentage to one decimal place (progress/duration, ratio in thousandths, times 100, 0 where duration not positive); `subunit_level`, `subunit_amount`, `unit_cw_strip`, `unit_experience`, `org_bar`, `str_bar`, `unitstatus_reserve` hidden; `subunit_type` emptied. `select` and everything else do nothing for such a row. Tooltip: section 7.

## 6. The multi-unit path

The three previously `inferred` records are confirmed as they were written.

- `CSubUnit_MayUpgradeWhereItStands` (VA 0x5DB2F0): the unit exists, in no battle, not on loan, not retreating; a fleet needs a port, an air unit an air base, by `level_max` (+0x20 of the province's building) ≥ 1; a land unit nothing more; and the province's area is the area of the owner's acting capital (`hardcoded`).
- `CInGameIdler_CountUpgradeableBrigades` (VA 0x66AFE0) and `CInGameIdler::OnUpgradeAll` (VA 0x66B510): as recorded; rows in the order first found across selection and list, then a Cancel row; `upgrade_all` frame 2 while open.
- `CInGameIdler_UpgradeSelectionTo` (VA 0x66B2A0): target buildable once at the top (player); each selected unit (kinds 0-2), each passing brigade whose list has the target, one command. A command for each brigade, not a choice per unit.
- **`MULTI_SEL_UPGRADE_DESC`**, the tooltip of `upgrade_all` (site VA 0x6C7616, in the screen's tooltip routine 0x6C5290): where the window at +0x1368 is shown, "§G$NUM$§! brigades in current selection can be upgraded.", `NUM` = `CountUpgradeableBrigades(no out list, screen)`.

## 7. Tooltips

All from `CSubUnitEntry::BuildTooltip` (slot 13, VA 0x7493B0):

- **`upgrade_button` on a brigade's row:** `UNIT_CAN_UPGRADE_TO` ("Click to upgrade this unit to:§Y"), then for each target with `CountMaxUnitsStillBuildable >= 1` for the player a `\n` and the type's name (definition slot 6). Nothing if the type's list is empty. No delayed half.
- **An upgrade row, on anything:** `BRIGADE_UPGRADE_MIL_CON_INFO` ("This unit upgrades from §Y$FROM$§! to §Y$TO$§!.") with FROM the old type's name (the item's +0x38, slot 6) and TO the new type's (+0x34). Where the item's `experience` (+0x40) is above nought, the delayed half `BRIGADE_UPGRADE_INHERITED_EXP` ("Upgraded unit will have at least §G$EXP$§!% experience inherited from previous unit, or more.") with `$EXP$` that to two places, the figure including the pride bonus.
- Any other element on a brigade's row keeps its existing tooltip (`unit_cw_strip`, `unitstatus_reserve`, otherwise the brigade summary): `FINDINGS-unitpaneltooltips.md`.

**Messages.** The command raises none: no message call appears in `Execute`'s or in `Deliver`'s body as decompiled whole. (Control: `CTransferSubUnitCommand::Execute` raises TRANSFEREDSUBUNIT by its record.) The only message on this path is the TRANSFEREDSUBUNIT `JoinUnit` raises for the player when the delivered brigade is moved into its target (section 4).

## 8. The save

An upgrade line is written like any `military_construction` (`CMilitaryConstruction::SaveContents`, VA 0x4843F0): `id size cost duration progress status [location] [country] [builder]`, `name` where longer than one character, `unit{id type}`, `manpower`, `target{id type}` where not 0/0, `is_reserve`/`factor` together where reserve, then each item as `<new type> = { id name model experience [upgrading_from_subunit = <old type> upgrading_from_subunit_str = <share, fixed>] }` (written only where not nought), `accumulated_experiance`, `accumulated_progress`. `FINDINGS-savegame.md` lines 579 and 742 have all of these.

**A unit's upgrade-line list is not written.** A scan of `CUnit::SaveContents` (VA 0x5B8170, where `this` is the unit + 8, so the list would be +0x290/+0x294 of the code) found no such offset; the same scan's positive controls found +0x9C and +0xA4. `CCountry::AfterLoad` rebuilds the list and the orange mark through `CMilitaryConstruction_RegisterUpgradeTarget`. The command's token is `upgrade_regiment` (0x762) with keys `sub_unit` and `target`.

## What was not settled

- `FUN_00749270` (VA 0x749270, the third function pointer of the row's first glue): the row's other mouse handler; by its call to VA 0x73B280 probably a drag of the brigade, but not read further.
- `0x76F2E0`, the test in `Fill` before each upgrade record's row: read as "the line resolves" only by its use.
- ~~`CSingleUnitPanel_PlaceUpgradeList`'s coordinate space and the slot-18 position of a list box (inferred).~~ **Measured
  2026-11-08 on a screenshot of the maintainer's**: the sum is a place on the screen, not inside `select_upgrade_window` (254, 0) or
  the panel (0, 108), the first `target` button's left and top standing at the row's left + 325 and the row's top - 5, where the sum
  and the button's file position (95, 98) give 325 and -6. `home_x` (+0x50) is the panel window's x, 0 as shipped. The pixel
  lower is what was measured and not explained.
- **Where the original refuses a foreign unit's upgrade** was not found: no routine read tests the owner, and the maintainer's
  word (2026-11-08) is that foreign units are not manually upgradeable.
- What the engine does for `UNIT_UPGRADE_PRACTICAL_MOD` where a mod's `defines.lua` lacks it (the default; the base game's file has no such key).
- The exact appended order for chains longer than two depends on type-index order; not computed for every type, since it follows from the loader's order. (The closure itself is confirmed, section 1.)
- Nothing here has been checked against a running game or a savegame; every statement is static.
