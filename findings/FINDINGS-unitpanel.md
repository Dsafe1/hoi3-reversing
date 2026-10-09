# The unit panel: what a selected unit's window is made of

*Read 2026-10-09 for OpenHOI3's unit panel. Static reading of `hoi3_tfh.exe`; every address is
a VA of this build. `confirmed` unless a line says otherwise. Nothing here was watched in a
running game.*

**In one line.** One selected unit gets the window `single_unitpanel`, which is nothing but a
list box; `CSingleUnitPanel::Rebuild` fills it with a fixed run of entries, each a class of its
own under `CUnitViewBaseEntry` that makes one window of `single_unitpanel.gui` or
`unitpanel.gui`, finds its elements by name once, and fills them from the unit every frame.

The families of the two files it does **not** cover are at the end.

---

## 1. The shape of an entry

`CUnitViewBaseEntry` derives from `CStandardlistboxItem` and has **two tables**: the list box
item's at `+0` (14 slots) and a window observer's at `+0x1C` (23 slots). All eighteen classes
under it follow one pattern:

    +0x00  the list box item's table
    +0x1C  the observer's table
    +0x20  the entry's window, made by the gui factory from the window's name
    +0x24  a byte the constructor of the header sets to 1 when it is done

- **the constructor** makes the window by name, registers the object as the observer of its
  buttons (`__CButtonObserverGlue`, one call per button with the handler in the slot of the
  event), and ends by calling its own update;
- **the update is slot 9 of the `+0x1C` table** (`this` is the `+0x1C` sub-object there, so the
  unit an entry holds at `+0x28` reads as `+0xC` inside it). `CUnitView` alone forwards it to
  slot 8 of its `+0` table;
- **slot 13 of the `+0` table builds the tooltip** of whichever element is under the mouse - it
  is handed the element and compares its name. These were not read through, and they are most
  of the bulk: `CUnitView`'s is 0x25E0 bytes against 0x1090 for its update;
- **slot 4 of the `+0` table is "the entry was clicked"**. Every row's button is registered
  with the one handler `0x67A310`, which only calls it.

A window finds its elements through its own table: `+0x34` a button, `+0x38` a text box,
`+0x3C` an instant text box, `+0x40` an edit box, `+0x44` an icon, `+0x48` a checkbox, `+0x6C` a
child window, `+0x7C` a list box. On an element `+0x34` shows and `+0x38` hides, `+0xB8` enables
and `+0xBC` disables a button, and an icon's `+0x48` sets its frame, **counted from 1**. An icon
or a bar is also hidden through `+0x104` and shown through `+0x108`; why there are two pairs
was not read.

## 2. The list: `CSingleUnitPanel::Rebuild`

`0x762780`, the panel in ECX, its unit at `+8`. `CSingleUnitPanel`'s constructor (`0x761C80`,
called once by `CInGameIdler::Enter`) makes the window `single_unitpanel`, registers
`oob_button`, and hides the two child windows `select_upgrade_window` and
`sup_stance_change_window`.

Rebuild empties the list `list`, switches it to entries of their own heights, and adds, in this
order:

| | entry | window | when |
| --- | --- | --- | --- |
| 1 | `CParentUnitEntry`, one for **each unit above**, the highest first | `sup_parent_unit_entry` | the chain of `higher_oob_unit_ptr` |
| 2 | `CUnitView` | `unitpanel` | always |
| 3 | `CUnitStatusEntry` | `sup_unit_status` | always |
| 4 | `CCurrentOrdersEntry` | `sup_current_orders` | always |
| 5 | `CObjectivesEntry` (`0x74E450`) | `sup_objectives` | `oob_level < 4`: a headquarters |
| 6 | `CUnitStanceEntry`, `CUnitAirStanceEntry`, `CUnitNavalStanceEntry`, `CPowerRatioEntry`, `CDesiredAssetsEntry` | `sup_unit_stance`, ..., `sup_power_ratios`, `sup_desired_assets` | a headquarters **with an AI agent on it or on a unit above** (`CUnit::HasAgentAbove`, `0x5B59C0`) |
| 7 | `CSingleUnitButtons` | `sup_buttons_window` | always |
| 8 | `CWindowForSubUnitsEntry` | `sup_subunits` | always |
| 9 | `CWindowForChildUnitsEntry` | `sup_children` | `CUnit::CountChildrenShown` (`0x5B9B80`) is not 0 |
| 10 | `CWindowForLoadedUnitsEntry`, up to twice | `sup_loaded` | a fleet (slot 16), and again for an air unit (slot 17) |
| 11 | `CCombatEntry`, one for each battle | `combat_entry` | each of `combats` whose slot 9 says yes, then `current_combat` likewise |

So the header row of the panel - the name, the leader, the strength and the two bars - is the
same `unitpanel` window, of the same class, as a row of the list of several selected units. Its
constructor's fourth argument says which: 1 here, 0 from `CInGameIdler`'s slot 34 (`0x6639E0`),
which adds a row to the selection list.

`CSingleUnitPanel +0xC` is set where the unit or one above it has an AI agent, `+0x10` is how
many parents there were, `+0x14` how many battles. When `0x1A85620` is set the unit's definition
is rebuilt first (`CUnit::RebuildDefinition`), which is the debug switch that write-up names.

`CUnit::CountChildrenShown` counts the units directly under this one, leaving out an air unit
that is aboard a carrier (its `home_base_ptr`'s slot 1).

## 3. The parents: `CParentUnitEntry`

`0x74D4F0`. One button, `unit`, whose text is the unit's name (slot 7) -

- wrapped as `§G` name `§W` where the unit has an AI agent (`ai_agent` not null);
- else, where the byte at `CUnit +0x4A` is set, followed by one of `§R*§!`, `§B*§!`, `§g*§!`
  (`0x5D3FE0`, by a figure of the unit against `floor(100.5)` and `floor(-99.5)`; neither the
  byte nor the figure was identified).

It has no update: the name is set once. Its click (slot 4, `CUnitViewBaseEntry::SelectUnit`,
`0x74D8A0`, shared with `CChildUnitEntry`) clears the selection, selects the unit, centres the
map on its province and, for a land unit where a setting of the screen allows, calls
`0x5D36A0`. Tooltip: `SELECT_PARENT_UNIT`.

## 4. The header: `CUnitView`

Constructor `0x769940` `(object, unit, screen, bool inPanel, list)`, update `0x76C7F0` (slot 8).

**Once, in the constructor:**

- `unitname`, an **edit box**, takes the unit's name; with `inPanel` clear its byte `+0x159` is
  set (not followed: by its place, "may not be typed in");
- `exp_force`, the flag of an expeditionary force: the owner's flag where
  `expeditionary_owner_id` is not 0, hidden otherwise;
- `counter_type` takes the sprite `GFX_counter_` + the type name of the unit's **first** brigade,
  when the player's intel on the unit is 3 or more, it has a brigade, and that sprite exists;
  `unit_activity` is then moved in front of it;
- `counter_size`, frame `n + 1` with `n` by `oob_level`: theatre 5, army group 4, army 3,
  corps 2, division **1 where it has more than one brigade and 0 otherwise**, fleet 1, anything
  else 0;
- `leader_types`, frame the leader's `+0x68` plus 1;
- three buttons are registered: `remove_unit_from_selection_button`,
  `only_unit_from_selection_button`, `leader_button` - and `leader_photo` with the last's
  handler.

**Every frame:**

1. `only_unit_from_selection_button` is shifted 15 pixels right where this row is in the list
   at `+0x17C`, and **disabled and hidden when exactly one unit is selected** (the screen's
   slot 51), enabled and shown otherwise.
2. **`unit_activity`**, a strip of six frames - nothing, a white arrow, a red star, a red arrow,
   a green arrow, a red cross:

       in a battle (combats_count > 0)      4 where CUnit::IsAttackerHere, else 3
       retreating                           2
       attack delay running                 6
       has a path                           5
       CUnit::IsFreeToAct                   1
       otherwise                            6

   `CUnit::IsFreeToAct` (`0x5C5AC0`, the unit in ESI) is false only for a unit with no
   brigades, and for a land unit that is aboard an air unit (`CArmy +0x304`); in a battle it
   asks the battles instead (`0x5C0000`). So **an idle unit shows nothing, and one on the
   march the green arrow**. `CUnit::IsAttackerHere` (`0x5C5BA0`) is the test that also picks a
   counter's stack in a battle (`FINDINGS-counters.md`); `inferred` to be "on the attacking
   side" from the red arrow it earns.
3. **`unitstrength`** is the unit's slot 37. For an army (`CArmy::StrengthText`, `0x5CE550`):

       men = the sum over its brigades of  strength * 100          (each cut to a whole man)

   written whole under 1000 and as thousands, a comma and three digits above - `8,997` - with
   `§R` in front where its strength over its strength ceilings is under
   `CUnit::ShatterThreshold`. `CRegiment`'s slot 14 (`0x5AC870`) is where the 100 comes from: it
   answers 100.000 and nothing else.
4. **`unitleader`**: the leader's name; `§R` and the name where `CUnit::LeaderHasRankForCommand`
   says no; the text `NO_LEADER` where the leader object's slot 8 answers false - a unit
   without a leader holds the null leader and not a null pointer.
5. `leader_photo` is made again when the leader changes:
   `gfx/pictures/portraits/` + the leader's `+0xA8` + `.tga`.
6. **`org_bar`** and **`str_bar`**, whole percentages handed to the bar's `+0x48`:

       org = trunc( 100 * GetAverageOrganisation / CUnit::MaxOrganisation )
       str = trunc( 100 * sum of the brigades' strength / sum of their definitions' max_strength )

   each with the divisor raised to the dividend where it is smaller, so neither passes 100.
   `CUnit::MaxOrganisation` (slot 38, `0x5BB430`) is the brigades' definitions'
   `max_organisation` averaged, times `1000 + ` the country's `land_organisation` (or
   `naval_organisation`, `air_organisation`) over 1000. It does not look at officers.
7. `leader_button` is disabled for an expeditionary force, a retreating unit, a unit in a
   battle, a fleet outside a port, an enemy's unit, and an air or sea unit without the base it
   needs; enabled otherwise. (Read as branches; which branch is which was matched by the tests
   and not by provoking them.)
8. `leader_types` again.

Its three handlers are registered in the order `0x76DC00`, `0x76DD70`, `0x76DE30`, and the
three buttons in the order remove, only, leader - but **which handler is whose was not
established**, and the plain reading of that order does not fit the names: `0x76DD70` hands
this unit to the screen's slot 43, which with a null is "clear the selection" and so with a
unit is by all appearance "take this one out of it"; `0x76DC00` clears the selection and then
selects every unit of a list (`+0x2E4` of what the unit's slot 11 answers). `0x76DE30` was not
read.

## 5. The status: `CUnitStatusEntry`

Constructor `0x7591A0`, update `0x759330`. One button, `unit_location_button`, whose handler
(`0x759310`) centres the map on the unit's province.

| element | what it is given |
| --- | --- |
| `unitlocation` | the name of the province the unit is in |
| `unitattrition` | `?%` for a unit with no brigades; else `GetProvinceAttrition` of its province as whole percent and `%` |
| `unitbase` | the text `SUPPLIED_FROM`, a space, and a province's name - or ` ???`. A land unit: the capital the province it stands in is supplied from (`supply_depot_id`; in arcade mode the country's acting capital), or the base of the fleet or the air unit carrying it; ` ???` where that province's controller is not a friend. A fleet or an air unit: its base, then `(` range `km)`; ` ???` with no base |
| `speed` | the unit's top speed times `CUnit::MovementSpeedModifier` over 1000, through `FormatSpeedExact`, then the text `KPH` |
| `unit_cw_strip` | hidden unless a land unit; else frame 1 to 5 by its definition's `width`: under 2, 4, 6, 8, or more |
| `supply_status`, `fuel_status` | whole percent, see below |
| `unit_weight` | a land unit's definition's `weight`, whole; nothing for the others |
| `unitstatus_distance` | hidden unless a land unit; frame 2 where `CUnit::IsOutOfRadioRange`, else 1 |
| `unitstatus_moving` | shown with a path |
| `unitstatus_combinedarms` | shown where `base_ca_bonus > 0` |
| `unitstatus_nuke` | shown where the order's slot 9 says so |
| `unitstatus_dugin` | shown where `dig_in_level > 0` |
| `unitstatus_delay` | shown where the attack delay is running |

**The speed is not what an hour adds.** It leaves out `LAND_SPEED_MODIFIER`: the panel shows
`maximum_speed x modifier`, the figure the unit files are written in, and the march adds a
twentieth of it an hour (`FINDINGS-movement.md`, section 5.1).

**The two bars are the province's, not the unit's.** `0x75A65A`..`0x75A7D0`:

    days   = max( whole(SUPPLYPOOL_DAYS), 1 )
    supply = pool.supplies * 1000 / ( days * need.supplies / 1000 )     1000 where need.supplies < 1
    fuel   = the same with fuel
    bar    = value * 100 / 1000

with `pool` and `need` the two `CGoodsPool`s of the province the unit stands in
(`CMapProvince +0x15C` and `+0x244`; supplies and fuel are their first two amounts, `+8` and
`+0xC`). So the bar says how many of `SUPPLYPOOL_DAYS` days of what the units there need is
lying in the province.

`CUnit::IsOutOfRadioRange` (`0x5B6C00`) walks up the headquarters above the unit; for each, the
reach is its first brigade's `CSubUnitDefinition +0x180` times the define for its level
(`RADIO_CORPS_LEADER_DISTANCE` and its three siblings), and the distance is between the two
provinces' bounding-box centres. It answers true as soon as one link is out of reach.

## 6. The order: `CCurrentOrdersEntry`

Constructor `0x752710`, update `0x752880`: the instant text box `orders` takes
`CUnit::DescribeOrder`. One button, `cancel_order_button` (`0x752C10`): **a land unit with a
path that is not retreating gets a `CCancelMovementCommand`**; otherwise, where the order's
slot 12 says it may be cancelled, a `CSetOrderCommand` for a null order.

`CUnit::DescribeOrder` (`0x5D2E90`, the unit in ECX, the string out on the stack):

    the order's slot 24 says it describes itself          -> the order's own text (slot 15)
    not a land unit                                       -> the order's own text
    retreating, with a path                               -> RETREAT_TO_OI, WHERE = the next province
    a path, and in a battle                               -> ATTACKING_TO_OI, WHERE = the next province
    no path, in a battle, among a battle's attackers      -> ATTACKING_TO_OI, WHERE = the province it is in
    no path, in a battle                                  -> DEFENDING_OI
    a path                                                -> MOVE_ORDER_D, WHERE = the next province
    strength under the shatter threshold                  -> RECOVERING_OI
    received no fuel and burns some                       -> NEED_FUEL_OI
    received no supplies and uses some                    -> NEED_SUPPLIES_OI
    otherwise                                             -> the order's own text

The order of the tests is as the routine has them; the three battle lines were put together
from a decompilation that had lost some of its branches and are `inferred`, the rest
`confirmed`.

**`WHERE` is the next province of the path, not its end**: `Move to $WHERE$.` names the
province the unit will be in next. The text of the null order was not read; the game's files
have `NO_ORDERS`, "No Order".

The header's tooltip over `unit_activity` gives the arrival: `ESTIMATE_ARIVAL`, "Will arrive in
$PROV$ on $DATE$", with the next province and `CUnit::NextArrivalHour` - again the next
province - and `UW_ATTACK_DELAY` with the hours left where a delay runs.

## 7. The brigades: `CWindowForSubUnitsEntry` and `CSubUnitEntry`

`CWindowForSubUnitsEntry` (constructor `0x753EF0`, update `0x753FF0`, fill `0x754430`):

- `header`: a land unit `LAND_COUNT` with `NUM` its brigades; a fleet `NAVAL_COUNT` with
  `CAPITAL`, `ESCORTS`, `OTHER`; an air unit `AIR_COUNT` with `FIGHTER`, `BOMBER`;
- `positioning`: empty but for a fleet, where it is `NavalStackingPositionPenalty` as a
  percentage - `§G0%§W` at nothing, `§r` in front otherwise;
- `list`: a `CSubUnitEntry` for each brigade, in the unit's own order, then one for each
  upgrade in progress (`CUnit +0x298`, 0x28 bytes each). The update fills it again when the
  count no longer matches or a row's brigade is gone.
- slot 5 of its observer table (`0x754230`) answers its height, which grows with the rows.

`CSubUnitEntry` (constructor `0x748D90`, update `0x74A410`), the window `subunit_entry`:

| element | what it is given |
| --- | --- |
| `counter_type` | `GFX_counter_` + the type's name, where that sprite exists |
| `counter_size` | frame 1 |
| `unit_pride_star` | frame 3 where the brigade is a pride (`CSubUnit +0xA5`) |
| `subunit_name` | the brigade's name (slot 8) |
| `subunit_level` | a Roman numeral: the index of `CHistoricalModel::PickBestModel` plus 1, or I |
| `subunit_amount` | its slot 13: for a brigade `FormatMen(strength)` |
| `subunit_type` | its definition's name (the definition's slot 6) |
| `unit_cw_strip` | hidden unless a brigade (slot 9); else frame 1 to 5 by `width` as in section 5 |
| `unit_experience` | frame 1 where its experience is under 1; else `round(experience / 10) + 2`, at most 11 - the experience with `PRIDE_BONUS_EXP` added for a pride (`0x5AC430`), rounded to even |
| `org_bar` | `trunc(100 * organisation / CSubUnit::GetMaxOrganisation)`, capped as in section 4 |
| `str_bar` | `trunc(100 * strength / its definition's max_strength)`, capped |
| `unitstatus_reserve` | shown where it is a reserve (`CSubUnit +0xA4`) |
| `upgrade_button` | shown where `0x74A220` says the country may still build a type this one upgrades to |

A row for an upgrade in progress instead shows `UNIT_UPG_PROGRESS` with its percentage in
`subunit_name`, the target type in `subunit_type`, and hides the rest.

Its click (`0x749270`, the third event of `select`) selects the brigade through the screen;
slot 4 is `CSubUnitEntry::BuildStatsTooltip`, already recorded.

## 8. The units under it: `CWindowForChildUnitsEntry` and `CChildUnitEntry`

`CWindowForChildUnitsEntry` (constructor `0x755760`, update `0x7558E0`, fill `0x755DD0`): `str`
is `FormatMen` of the strength of every land unit under this one, at any depth
(`CUnitList::TotalLandStrength`, `0x5D63C0`), and `select_all_childunits` is enabled - or, for
a unit that is not a land unit, `str` is empty and the button disabled. The list is filled
again when `CUnit::CountChildrenShown` no longer matches its rows, and each row is updated.

The fill makes a `CChildUnitEntry` for each unit `CountChildrenShown` counts and writes
`header` from how many of them are at each level: the number, a space and the text, for
`NUM_GROUPS` (level 1), `NUM_ARMIES` (2), `NUM_CORPS` (3) and `NUM_DIVISONS` (4, the key is
spelt so), those that are not 0, in that order, with `, ` between - "2 Corps, 1 Division(s)".

**Both windows are as high as their rows** (slot 5 of the observer table, `0x754230` and
`0x755C70`, which is what the list of entries of their own heights asks):

    height = the label icon's height + min( rows * a row's height, the window's height - the label's )

with the label `bg_label_brigade` or `children_label_bg`. A fleet with fewer than three
ships gets twice the room in the brigades' window; why was not read.

`CChildUnitEntry` (constructor `0x74B490`, update `0x74BA10`), the window `childunit_entry`:

| element | what it is given |
| --- | --- |
| `counter_type`, `counter_size`, `unit_pride_star` | as the header's; the star is frame 3 where its first brigade is a pride |
| `name` | the unit's name, and ` (` leader's name `)` where it has a leader |
| `order` | `CUnit::DescribeOrder` |
| `objective` | `0x5B5B50`, not read |
| `str` | a land unit: `FormatMen` of the sum of its own brigades' strength; else empty |
| `org_bar`, `str_bar` | as the header's |

Its click is `CUnitViewBaseEntry::SelectUnit`; `0x74B900`, the third event of `select`, hands
the unit to the screen's slot 105 object (`0x73AE80`, not read).

## 9. The buttons: `CSingleUnitButtons`

Constructor `0x75CED0`, update `0x75EC40` (0x1B00 bytes, read as far as this):

- `create_corps`, `create_army`, `create_armygroup`, `create_theatre`, `edit_theatre` are all
  hidden and then **one is shown by `oob_level`**: 4 a division `create_corps`, 3
  `create_army`, 2 `create_armygroup`, 1 `create_theatre`, 0 `edit_theatre`. The four that
  create are disabled together where the unit already has a parent no more than one level up,
  a custom game setting forbids it, or the country's manpower is under what a headquarters
  brigade needs.
- **no unit above**: `attach_button` shown, `detach_button` hidden; `attach_button` enabled
  where some unit of the country may take this one (`CUnit_MayTakeSubordinate`) and its
  brigades are not all carrier air groups. **A unit above**: `attach_button` hidden,
  `detach_button` shown unless all its brigades are carrier air groups.
- the three checkboxes are set from the unit every frame: `prio_checkbox` from `CUnit +0xA4`,
  `reinf_checkbox` from `+0xA6`, `upgrade_checkbox` from `+0xA5`.
- a land unit that is not aboard anything: `unload_button` hidden, `load_button` shown and
  enabled where `0x75E510` finds a fleet to board; aboard: `unload_button` shown,
  `load_button` hidden.
- `load_plane_button`, `unload_plane_button`, `disbandbutton`, `newunitbutton`: in the part
  not read.

## 10. A headquarters' row: `CObjectivesEntry`

Read after the maintainer set a corps' panel beside OpenHOI3's and this row was missing from
it. Constructor `0x74E450`, update `0x74E9F0`; the window `sup_objectives`, entry 5 of
section 2, for every unit with `oob_level < 4`. It has two faces, by whether the unit or a
unit above it has an AI agent:

| element | under the player's hand | an AI in command |
| --- | --- | --- |
| `automate_checkbox` | clear | ticked |
| `reorg_hq_checkbox` | hidden | shown, set from `CUnit +0x205` |
| `objectives` | hidden | shown: `OBJECTIVES`, `: ` and `0x5B5B50`'s text, or `NO_OBJECTIVES` |
| `tac_aggro_bg`, `tac_aggro_slider_bg` | shown | hidden |
| `aggression_checkbox` | shown, set from `CUnit +0x4A` | hidden |
| `aggression_slider` | shown | hidden |

**The aggression** is two fields of the unit: the byte **`+0x4A`, "it has a setting of its
own"**, and the fixed-point **`+0x4C`, the setting**, from -1 to 1 as the slider's
`minValue` and `maxValue` have it.

- box clear: the slider shows `0x5D3F10(unit)` - by its use the setting the unit is under,
  not read - and is locked (its byte `+0x253`, and its thumb disabled);
- box ticked: the slider is free, and where its value is further from `+0x4C` than a small
  constant the entry posts a `CSetUnitAggressionCommand(unit, value)`.

That also names the mark section 3 could not: a parent's row shows `§R*§!`, `§B*§!` or
`§g*§!` after the name of a unit **with a setting of its own** - red above 0.1, blue below
-0.1, grey between (`floor(100.5)` and `floor(-99.5)` against `+0x4C`).

Last, `automate_checkbox` is disabled for a headquarters whose own commander is under an AI
already, and for a theatre under conditions of `0x5D2A00` that were not read.

## What was not read

- **every tooltip** (slot 13 of each class), beyond the three texts named above;
- the three stance entries, `CPowerRatioEntry`, `CDesiredAssetsEntry`,
  `CWindowForLoadedUnitsEntry` with `CLoadedUnitEntry`, `CCombatEntry`; of `CObjectivesEntry`
  its handlers and slot 22 (`0x74F910`);
- the second half of `CSingleUnitButtons::Update` and every handler of its buttons;
- of `unitpanel.gui`: `multi_unitpanel`, `leader_selection_panel` and its entries,
  `reorg_window`, `attachment_selection_panel`; and how `CInGameIdler` lays the list of
  several selected units out, beyond what `FINDINGS-guilive.md` has of `unitlist_start` and
  `unitlist_offset`;
- `0x5D36A0`, `0x5D3FE0`'s figure, `0x5B5B50`, `0x73AE80`, `0x73B280`, `0x76DE30`;
- why an icon has two pairs of show and hide.
