# The deploy menu: how a finished unit gets from the list to the map

Read statically out of `hoi3_tfh.exe` on 2026-10-09, for the rewrite. Addresses are **VAs**
unless a line says rva; `rva = VA - 0x400000`. Only valid for this build. Nothing here was
checked against a running game. It continues `FINDINGS-buildqueue.md`, section 7, which has
the command and the rule for a province.

**In one line.** An alert icon opens a side menu, `sidebar_deploy`, listing the country's
finished units. Choosing one turns the same list into the units already in the field that the
new one may **join**; the player then picks one of those, or a province on the map. Either
way one `CDeployUnitCommand` is posted, with or without a target.

---

## 1. The alert

`CAlertManager`'s constructor (`0x6012F0`) registers sixteen alerts by name and number:

| | | | |
| --- | --- | --- | --- |
| 0 | `alert_nap_expiry` | 8 | `alert_wasted_ic` |
| 1 | `alert_deployable_units` | 9 | `alert_tech_far_ahead` |
| 2 | `alert_troops_in_foreign_territory` | 10 | `alert_lack_of_troops` |
| 3 | `alert_revoltrisk_in_provinces` | 11 | `alert_bad_supply` |
| 4 | `alert_can_invite_to_faction` | 12 | `alert_national_decisions` |
| 5 | `alert_resource_panic` | 13 | `alert_mobilized_in_peace` |
| 6 | `alert_possible_law` | 14 | `alert_victory_conditions` |
| 7 | `alert_free_tech_slots` | 15 | `alert_allied_objectives` |

Each takes its two tooltips from the localisation keys `<name>_instant` and `<name>_delayed`
(`0x601B70`). `confirmed`: sixteen string literals, each followed by the call with its number.

**Showing one** (`0x607FE0`): an `alerticon_window` is made from `interface/alerts.gui`, its
`alerticon` is set to **frame `number + 1`** and its `alerticon_banner` to frame 0, and the
window is put at the manager's next place - which starts at the `positionType`
`alerticon_startposition` and moves on by `alerticon_offset`'s x for each alert shown. So
alerts stand in a row in the order they came up, not in the order of their numbers.
`likely`: read in the decompiled C.

**Clicking one** (`0x607ED0`) finds the alert by the icon's frame less one and hands its name
to the in-game screen's slot 80 (`0x64ACB0`). For `alert_deployable_units` that closes
whatever side menu is open and opens side menu **5** (`0x6655C0`), the deploy menu.

**When the alert is up was not read.** Its tooltip is "We have units available to be
deployed."

## 2. The menu: `CSideMenuDeploy`

Constructor `0x8277A0`: the window `sidebar_deploy` of `interface/sidebar.gui`, a
`CDeploymentMenuMouseObserver` for the map, and its `close` button.

| offset | | |
| --- | --- | --- |
| `+0x20` | the in-game screen | |
| `+0x24` | the window | |
| `+0x58` | `choosing_target` | 0: the list is the finished units. 1: it is the units one may join |
| `+0x5C`, `+0x60` | `deployment_id` | the one chosen |
| `+0x64` | `targets_stale` | the target list is to be made again |
| `+0x68` | the list's scroll position when a unit was chosen | |
| `+0x6C` | `list_stale` | |

**Slot 7 (`0x827A70`) is its update**, and the whole of its behaviour.

*Not choosing a target:* when the number of lines in `deployment_queue` differs from the
country's count of deployments, or `list_stale` is set, the list is made again (`0x8287B0`):
the title `title_view_deploy` is set to the text of `DEPLOY_UNITS`, the list is emptied, and
one `CDeploymentEntry` is added per deployment, in the country's own order. **When the list
is empty the menu closes itself** (`0x665320`).

*Choosing a target:* once (`targets_stale`), the list is emptied and the title becomes the
text of `DEPLOY_SEL_TARGET`. Then the country's units are walked **by `oob_level`, 0 to 7,
and within a level in the country's own order**, and a `CDeploymentTargetEntry` is added for
each that passes:

    the deployment may be placed in the province the unit is in     (CanDeployIn)
    and the unit is not lent to another country                     (expeditionary_owner == 0)
    and one of:
      the new unit is LAND with exactly one brigade:
          the unit is land, and has fewer brigades than the country may put in a division
      the new unit is LAND otherwise:
          the unit may take it as a subordinate                      (below)
      both are AIR:
          an air unit with no wings, or - one rule about carrier air groups, not read through
      both are NAVAL:
          always

"May put in a division" is `0x4E1360`: `(BRIGADES_IN_DIVISION + the country's modifier at
CModifier +0x1C) / 1000`. "May take as a subordinate" is `0x5B96B0`:

    the unit's oob_level must be lower than the new unit's            ; it is higher in command
    if the new unit is land and the unit is not a theatre (level 0):
        the unit must have at most 4 land units under it already
    if the new unit is naval or air:  the unit's oob_level must be 3 or less

`confirmed` for the walk and the four cases, `likely` for the carrier rule's outline, which
reads the first wing's `CSubUnitDefinition +0x32` and the home base's capacity.

When no unit passes, `choosing_target` goes back to 0. So **a unit nothing can take in shows
the plain list again**, and is placed by a click on the map only.

Slot 2 (`0x827950`) is "open": it shows the window, clears both flags and builds the list.
Slot 3 (`0x827980`) is "close": it hides it and tells the in-game screen (its slot 30, `0x667DB0`)
that no deployment is being placed.

## 3. A line of the list: `CDeploymentEntry`

Constructor `0x826F40`, on a `deployment_entry` window:

| element | |
| --- | --- |
| `name` | the deployment's own name (its slot 11) |
| `counter_type` | for a unit: the sprite `GFX_counter_<type key of the unit's first brigade>`, set only where that sprite exists. For anything else: hidden |
| `counter_size` | for a unit: frame `size + 1`, `size` being `CUnit::GetCounterSize` (`FINDINGS-counters.md`, section 3). For anything else: hidden |
| `select` | the button |

The size is worked out inline with the same seven-way jump, and there is no intel test here:
a unit with no brigade gets the same static string the map counter falls back on.

**A click on `select`** (slot 4, `0x827650`) finds the deployment by its id, tells the in-game
screen which deployment is being placed (slot 30), and for a unit's deployment calls
`0x8279B0`, which stores the id in the menu, sets `choosing_target` and `targets_stale`, and
remembers the list's scroll position. For any other kind of deployment it calls the in-game
screen's slot 46 instead.

## 4. A line of the target list: `CDeploymentTargetEntry`

Constructor `0x826480`, on a `deployment_target_entry` window: `name` is the unit's name
(its slot 7), `location` the name of the province it is in, and `counter_type` and
`counter_size` as above, from the target unit.

**A click on `select`** (slot 4, `0x826AD0`) posts

    CDeployUnitCommand(province = the target's province, country = the player,
                       deployment = the one chosen, target = the unit)

and puts the menu back to its plain list. Its own update (`0x826A00`) drops the menu back
the moment the deployment could no longer be placed in the target's province.

## 5. Joining: `CUnitDeployment::JoinUnit` (`0x5067D0`)

What `CDeployUnitCommand::Execute` calls when it has a target, with the country, the target
and a flag:

    province = the target's province
    if the deployment may not be placed there:
        province = of the provinces of the capital's area - its ports for a fleet (area +0x48),
                   its air bases for an air unit (area +0x58), all of them otherwise -
                   the nearest that it may be placed in          (CMap::DistanceBetweenProvinces)
        none: nothing happens
    the unit is placed there                                      (DeployAt, the deployment's slot 9)
    the deployment is taken off the country's list and freed
    if the unit has exactly ONE brigade and is of the same service as the target:
        the brigade is taken out of it and added to the target    (RemoveRegimentFromUnit, AddRegimentToUnit)
        the message TRANSFEREDSUBUNIT, with SUB, OLD and NEW
        the emptied unit is removed from the game
    else:
        the unit is put under the target                          (0x5B9760)
        the message for a new unit under a commander, not read

`confirmed` for the order - place, unlink, then merge or attach - and for the merge being a
plain move of one brigade. `likely` for "of the same service", which the decompiler renders
as six calls of the two units' `IsLand`, `IsAir` and `IsNaval` whose comparison it loses.
With the flag set the target is first swapped for another unit by `0x88AFC0` or `0x88ACB0`;
those are in the AI's address range and were not read.

**So a ship ordered alone joins a fleet, a wing an air unit and a brigade a division by the
same three lines**, and a division or anything larger is put under a headquarters.

## 6. The map

`CDeploymentMenuMouseObserver` (constructor inline in the menu's; its slot 1 at `0x828C20`)
watches the mouse while the menu is up. On a left click over a **unit's deployment line being
dragged** onto the map it finds the unit there (`0x8274A0`) and opens the routine that lets a
unit be dropped on another (`0x73AE80`, or `0x73B280` for a single brigade), whose answer
comes back through `CDropAndAssignUnitDeploymentCallback` (`0x826130`): a
`CDeployUnitCommand` with the answering unit as target and its province as the place.
`inferred`: only the callback was read end to end.

**The plain case - choose a line, click a province - was not found in this class.** The
in-game screen is told which deployment is being placed (slot 30) and the click must be
handled there with the rest of the map's clicks; it posts the same command with no target,
by `FINDINGS-buildqueue.md`'s account of `Execute`. `inferred`.

## What was not read

- **When `alert_deployable_units` is up.**
- **How the map shows where a unit may go** while one is being placed, and the click that
  places it: the in-game screen's slot 30 (`0x667DB0`) and whatever reads what it stores.
- **The carrier air group rule** among the targets.
- **`0x5B9760`**, which puts one unit under another, and the message that follows.
- **The two AI helpers** that swap the target when `JoinUnit`'s flag is set.
- **The tooltips** of both kinds of line (`0x826CA0`, `0x826200`).
