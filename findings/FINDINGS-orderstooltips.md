# The deploy menu's and the orders windows' tooltips

*Read 2026-10-12 for OpenHOI3; the mechanics specs are `OpenHOI3/docs/mechanics/mapunits.md`,
section 10, and `OpenHOI3/docs/mechanics/fleetsandair.md`, section 8. Addresses are VA / rva.
Everything here is one build of `hoi3_tfh.exe`. Nothing in it was watched in a running game.*

What a unit's other windows say in a tooltip: the deploy menu a finished unit is placed from, and
the two windows a right click with a fleet or an air unit brings up. `FINDINGS-tooltips.md`
has how a tooltip is asked for; `FINDINGS-seaair.md` and `FINDINGS-airorders.md` the two
windows; the deploy menu is in the record under `CSideMenuDeploy`.

**How it was read.** Each routine decompiled headless out of a copy of the Ghidra project with
the record applied (`ghidra/DecompileAt.java`), and the joins, the string literals and where
each text is stored read in the listing (`scripts/disasm.py`).

## 1. Where the dispatcher asks them

`CInGameIdler::GetElementTooltip` (`0x6C5290`) asks, after the windows at `+0x1358` to
`+0x1D4C`:

- **the side menu that is open** - `[idler + 0xD10] + 0x14` - through three slots: **4** whether
  it is shown, **6** whether the element is its own, **8** the tooltip. Only where 4 and 6 both say
  yes is 8 asked, and its answer is final (`0x6C547A`..`0x6C54A8`). `CSideMenu`'s slot 4
  (`0x824120`) is its window's shown byte (`+0x24`'s `+0x5B`); its slot 6 (`0x598DB0`) answers
  no, so a side menu that does not override it answers for nothing.
- **the orders view** (`+0x160`), where there is one, through its slot 5 - is the element its
  own - and slot 6, the tooltip.

Then the names: among them an unconditional **`closebutton` - `CLOSE`**, so a close button that no
window before has claimed says "Close" wherever it is (the battle window's, `combat.gui`, among
them). A second `closebutton` arm further down, among the multi-unit buttons, gives the same
text; whether anything reaches it past the first was not followed. `confirmed` for the first.

## 2. The deploy menu (`CSideMenuDeploy`)

**Slot 6** (`0x828B00`): the element is the menu's where an entry of `deployment_queue` claims it
- its observer slot 22 (`+0x58` of the `+0x1C` table). Nothing else in `sidebar_deploy` is the
menu's, so the rest of the window falls through to the names. `confirmed`

**Slot 8** (`0x828680`): the entry that claims it answers - while a target is being chosen
(`choosing_target`, `+0x58`) a target's line (`0x826200`), otherwise a finished unit's line
(`0x826CA0`). `confirmed`

**A finished unit's line** (`0x826CA0`; the entry in `edx`): the deployment found by its id
(`+0x78`); where it is a unit's (slot 8 answering `0x4B4`) and that unit is a land unit (slot 15),
a line for each of its brigades, `£` (`0x15CA688`) + the brigade's type's key + ` ` + its name
(slot 8) + `\n`. A fleet, an air unit and a building say nothing. All in `text`. `confirmed` -
the joins are given their operands by the decompilation itself.

**A target's line** (`0x826200`; the entry in `edx`): the unit at the entry's `+0xA0`, the same
line for each of its brigades, **whatever the unit is**. `confirmed`

So both are the unit panel's `counter_type` (`FINDINGS-unitpaneltooltips.md`, section 3.2), over
the whole of the line.

## 3. The fleet's window (`CNavalOrdersView::GetTooltip`, slot 6, `0x73F660`)

`void* __thiscall (view, out, element)`. In order:

| element | what it says |
| --- | --- |
| `accept`, **while it is switched off** (its slot 48) | `OV_NO_VALID_ORDER` where no order is being made (`+0x220`); else `OV_OUT_OF_RANGE` where that order's slot 8, "is in range", says no; else nothing |
| `stance_label`, `stance_value`, `decrease_stance_button`, `increase_stance_button` | `OV_STANCE` |
| `priority_label`, `priority_value` | `OV_PRIO` |
| a row of `orders_list` | its order's description (`OrderMissionIndexToDescription(OrderTypeToMissionIndex(type))`, the type from the order's token the row keeps at the element's `+8`); and, after a moment, where `CreateOrder(type, the window's province)` says out of range, `OUT_OF_RANGE` |
| anything else | nothing |

`confirmed`. **The window's two priority buttons say nothing**: the routine asks for
`priority_stance_button` twice (`0x73FA24` and `0x73FA3F`, the same string `0x15D7088`), a name
no element has; the buttons are `decrease_priority_button` and `increase_priority_button`.

**`OUT_OF_RANGE`** goes in `delayed` - the description is stored at `[esp + 0xA0]` and this at
`[esp + 0xBC]` of one frame, `0x1C` apart (`0x73FBD3`, `0x73FE39`). Its two figures:

- `MYRANGE` - the range (`+0x148`) of the unit's sub unit definition (`CUnit +0xC8`), as a float
  over 1000.0 (`0x160A300`), to one place (`0xA5AEC0`);
- `RANGE` - `CMapProvince::NavalDistanceTo` from the window's province (`+0x2C`) to the province
  of the unit's base (`+0x98`, slot 0, its `+0xD0`), trimmed (`0xA5ABC0`).

**`OV_OUT_OF_RANGE` has no text** in Their Finest Hour's tables or the base game's, so where it
shows it is the key itself. And `accept` is switched on whenever a row is ticked (`+0x13C`), so a
switched-off `accept` has no order and the second case is not reached.

## 4. The air window (`CAirOrdersView::GetTooltip`, slot 6, `0x7456C0`)

The naval one's twin, all in `text`:

| element | what it says |
| --- | --- |
| `daytime_title`, `daytime_icon`, `daytime_icondesc` | `ORDER_DAY_TIME_DESC` with `PROV` the window's province's name (`+0x30`) and `TIME` the text of `ORDER_NIGHT` or `ORDER_DAY` - `IsNight` (`0x4A7390`) for that province at the start widget's hour (`+0xB0`, its `+0x160`) of the day and month |
| `accept`, while switched off | `OV_NO_VALID_ORDER` with no order being made (`+0x2EC`); `OV_NO_VALID_PROVINCES` where its list of provinces is empty; else nothing |
| the stance's four | `OV_STANCE` |
| `priority_label`, `priority_value` | `OV_PRIO` - its priority buttons say nothing, for the naval one's reason (`0x745A83`, `0x745A9E`) |
| `continous_checkbox` | `OV_CONT` |
| `point_target_button`, `region_target_button`, `circle_target_button`, `cone_target_button` | `AirOrdersBtn_Point`, `_Region`, `_Circle`, `_Conic` |
| a row of `orders_list` | its order's description; **no range line** |
| anything else | nothing |

`confirmed`. The day readout's arithmetic is the window's own (`FINDINGS-airorders.md`): the hour
less 43,800,000, the hour of the day its remainder by 24, the month by walking the month lengths
from the day of the year.

## Kept as read, though they look odd

1. Both windows' priority buttons say nothing: their routine asks twice for a name that is not in
   the file.
2. `OV_OUT_OF_RANGE` has no text, and is not reached.
3. A finished fleet's or air unit's line in the deploy menu says nothing, where a target's line
   lists any unit's ships or wings.

## Not established

- What the original's `GetText` shows for a key with no text: taken to be the key.

## In the record

Entered in `ghidra/project.json` by `fragments/merged/orders-tooltips.json`: four functions new -
`CSideMenuDeploy::OwnsElement` and `CSideMenuDeploy::GetTooltip` (slots 6 and 8),
`CDeploymentEntry_Tooltip` and `CDeploymentTargetEntry_Tooltip` - with `CSideMenu`'s slot 4
(`CSideMenu::IsShown`) and slot 6 (`CSideMenu::OwnsElement`, which says no); and
`CNavalOrdersView::GetTooltip` and `CAirOrdersView::GetTooltip` revised from `inferred` to
`confirmed`, read whole. Then `fragments/merged/tooltips-storage.json` placed every parameter of
seven register-convention signatures - the two above and five entered for the unit panel's
tooltips (`FINDINGS-unitpaneltooltips.md`).
