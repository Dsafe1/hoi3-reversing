# A province's stacks: a battle's two sides, and which counter is on top, 2026-11-14

Read statically, for OpenHOI3's units on the map. It settles two things `FINDINGS-counters.md`, section 6, left open -
which battle stack is the attacker's, and what a counter's `order` is - and closes `FINDINGS-selection.md`'s note that what
fills a province's `map_units` was read only from its writers. Addresses are rvas unless marked VA, and valid only for this
build. Where the five stacks stand is `FINDINGS-movement.md`, section 9; nothing here changes it.

## 1. Which battle stack is the attacker's (confirmed)

A fighting unit's counter goes in stack 2 where `CUnit::IsAttackerHere` (`0x1C5BA0`) answers true, else 3. It asks one
battle:

1. the first on the list of the province the unit **stands in** (`+0x130`, the province's `+0x2EC`) whose kind fits the
   province - 1 on land, 2 at sea;
2. where there is none, **the unit's own first battle** (`+0x114`).

and answers whether the unit's owner is on that battle's **attacker** (`CCombat +0x10`) list of the countries still in the
fight (`+0x54`). So **stack 2 is the attackers', 3 the defenders'** - and at sea the attackers stand 2.4 west and south of
the zone's point, the defenders 2.4 east and north. On land both stand on the province's point.

Two consequences, both of the reading: an attacker on land stands in its own province, where there is usually no battle, so
it is placed by the battle it is in; and **an attacker standing in a province that is itself attacked stands with the
defenders**, the battle there being asked first. The panel's red arrow and red star follow the same answer.

## 2. A province's list of units on the map (confirmed)

`CMapProvince::AddUnit` (`0xA5A30`) puts each unit entering a province on one of two vectors by `MapUnit_IsShown`
(`0xA57D0`): **`map_units` (`+0x2C8`)**, the units with a counter, or `hidden_units` (`+0x2D8`) - an air unit at its base, a
fleet in a land province, a passenger in port or at an air base. It **re-sorts `map_units` each time**, with `std::sort`
(`MapUnits_Sort`, `0xA88E0`; for 32 units or fewer only its insertion pass, `0xA8E50`) and the comparison
`MapUnitOrder_Before` (`0xA58C0`), given the played country and whether the province is land:

1. the played country's own units first;
2. (an air unit at its own base last - none is on this vector);
3. an air unit before a land unit carried by an air unit;
4. in a land province anything but a fleet before a fleet, at sea a fleet first;
5. **the higher rank first**: the unit's `oob_level`, 0 a theatre, 1 an army group, 2 an army, 3 a corps, 4 a division, 5
   a fleet, 6 an air unit.

It is strict, and the insertion pass keeps equals in their order, so **of two units it does not part the one that came into
the province first stands first** (for more than 32 the introsort's partition may not). Nothing else orders the vector:
`RemoveUnit` erases from it.

This **confirms the maintainer's word** of 2026-10-09 that the higher rank is on top of a stack, which `mapunits.md` had
taken from him with the sort unread - and adds the played country's units first and the order of equals.

## 3. Which counter is on top (confirmed)

A stack draws its counters in ascending `order` (`CCounterObject +0x1A8`), the last on top (`FINDINGS-counters.md`,
section 6). `order` is written each frame of the near view by `CUnit::UpdateAvatar` from the `stackIndex`
`ProvinceGraphics_Update` (`0x23EF30`) hands it: walking `map_units` **from `map_unit_cursor` (`+0x2E8`) round to it again**,
the first unit gets the vector's size less one and each next one less. So:

- **with nothing selected** the cursor is 0 and **the first of `map_units` is on top** of its stack, the rest under it in
  the list's order;
- **with a unit selected** the cursor is its place (`CUnit::OnSelected`), so **it is on top**, the units after it in the
  list under it, and those before it under them;
- the click that steps through a stack (`FINDINGS-selection.md`) takes the unit after the selected one in the same list,
  which is then on top in its turn.

The units of `hidden_units` are told their view with `order` 0. How `ProvinceGraphics_Update` shows or hides a province's
avatars by the player's part in their battles - the rest of that loop - was not read.

## 4. Recorded

`project.json`, from `fragments/merged/map-stack-order.json`: `CUnit::IsAttackerHere`, `CMapProvince::AddUnit` and
`ProvinceGraphics_Update` revised; `MapUnit_IsShown`, `MapUnitOrder_Before`, `MapUnits_Sort` and `MapUnits_InsertionSort`
new; `CMapProvince +0x2C8 map_units` and `CCounterObject +0x1A8 order` revised, `CMapProvince +0x2D8 hidden_units` new.
