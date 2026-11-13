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
`CDeploymentMenuMouseObserver` for the drag into the order of battle browser (section 6; it was
"for the map" here until 2026-11-13), and its `close` button.

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

## 6. Dragging a line onto the order of battle browser

*Read statically 2026-11-13, for OpenHOI3; nothing watched running. Addresses VAs unless marked
rva.* **In one line:** a line of the plain list can be pressed and dragged into the order of
battle browser and dropped on a row, and the unit is then deployed under that row's unit. **The
drag never goes to the map**: placing on the map is still choosing the line and clicking a
province, or choosing a unit from the target list (sections 3 and 4).

*Corrected 2026-11-13: this section said the observer reacts to "a left click ... over the map"
and was `inferred`. It tests only the browser's main window and no mouse button; and a drop posts
two commands, not one.*

### 6.1 The rules

1. **Only from the plain list, and only a unit's line.** `confirmed`
   - Pressing the left button on a line's `select` button marks that line as pending in the menu's
     mouse observer - only where its deployment is a unit deployment holding a unit. A building's
     line marks nothing; the target list's lines have a click handler only. Neither can be dragged.
   - The press does nothing visible: it does not choose the line, select anything or set the in-game
     screen's "deployment being placed".
2. **The press becomes a drag once the pointer is inside the browser's window.** `confirmed`
   - The observer runs every frame the menu is shown; with the browser closed it forgets a pending
     press. Otherwise a pending press and a pointer inside the browser's main window (`oobbrowser`,
     both edges inside) hand the drag to the browser, and the mark is cleared.
   - No mouse button is tested here; rule 4 makes that harmless.
   - The browser is open only while exactly one unit is selected (`FINDINGS-oobbrowser.md`, section
     2): select one unit, open the browser from the unit panel, open the deploy menu, press a line and
     drag it into the browser beside the menu.
3. **What is dragged depends on the unit's size.** `confirmed` A unit of exactly one brigade (ship,
   wing): that brigade, as a brigade dragged from the unit panel. Any other: the unit, as a unit row
   dragged. Either way the drag carries a deployment callback holding the deployment and the in-game
   screen.
4. **The browser's own drag rules apply unchanged.** `confirmed` The drag goes live once the pointer
   has moved more than 2 pixels either way from where the browser first saw it; letting go before
   cancels it and posts nothing. A press whose button was already up on reaching the browser is
   cancelled within one frame, so a stale press can never drop anything.
5. **Feedback while dragging** (`confirmed`): the browser's floating `oob_unit_entry` follows the
   pointer, filled with the deployment's unit or brigade; each row shows frame 2 where it accepts and
   is under the pointer, frame 1 and disabled where it refuses; a closed row hovered 1.0 s opens; the
   list scrolls at its edges. What a row shows is the drop's test **minus rule 7's province check**,
   so a row can light up for a one-brigade unit and still refuse it. No cursor change or tooltip was
   found here (`inferred`; only these functions were searched).
6. **A unit of several brigades dropped on a row** (`confirmed`): accepted where the row's unit may
   take it as a subordinate (section 2's rule) - its level strictly higher in command; a land unit
   under anything but a theatre needs the row to hold at most 4 land units already; a fleet or air
   unit needs the row at level 3 or above. Nothing else: not the province, loan, combat or theatre.
   The browser lists only the player's own units. So a division goes under a corps, army, army group
   or theatre, never a division; a fleet or air group under a land headquarters of level 3 or above;
   a fleet never under a fleet, an air group never under a fleet.
7. **A unit of one brigade dropped on a row** (`confirmed`): the row's unit must accept the brigade
   under the eleven tests of `CUnit_CanTakeSubUnit` **with the same-province test off** (same service,
   not fighting, not on loan, a land row not full of brigades, the carrier air group rules), and **the
   deployment must be placeable in the row unit's province** (`CanDeployIn`): a ship the province's
   naval base, a wing its air base, and in an ordinary game the province in the same area as the
   acting capital. So a fleet at sea refuses a single ship, a division outside the capital's area
   refuses a single brigade though its row is lit, and a headquarters row accepts a land brigade into
   the headquarters unit itself (`likely`, from JoinUnit's merge rule).
8. **What a drop posts, in this order** (`confirmed`, both through the in-game screen's command
   channel): (1) `CDeployUnitCommand` - province the row unit's, country the player, deployment the one
   dragged, target the row's unit; (2) for a unit of several brigades **`CAttachUnitCommand(the
   deployment's unit, the row's unit)`**, for a single brigade **`CTransferSubUnitCommand(the row's
   unit, the brigade)`**. They run in the order posted (`likely`: one channel drained in order,
   `FINDINGS-commands.md`).
9. **What the deploy command does** is section 5's `JoinUnit` with no swap flag (`confirmed` by the
   record): the place is the row unit's province or, where the unit may not be deployed there, the
   nearest province of the capital's area where it may; then a single brigade of the same service is
   moved into the row's unit (`TRANSFEREDSUBUNIT`) and the emptied unit removed; any other unit is put
   under the row's unit. So for several brigades the province is never refused at the drop.
10. **What the second command does** after the deploy command has run was not traced: the attach
    repeats what is done, a no-op that re-appends the unit last (`inferred`); the transfer is refused
    or moves the brigade from the row's unit to itself, perhaps raising `TRANSFEREDSUBUNIT` twice
    (`inferred`). Where `JoinUnit` finds no province and does nothing, the attach would still hang the
    undeployed unit under the row's unit, `CAttachUnitCommand::IsValid` asking only that both exist and
    the levels fit (`inferred`, not traced).
11. **Afterwards** (`confirmed`): the browser clears its drag; for a unit drop it remembers the row's
    and the dropped unit's references (+0xF8, +0x120, unread elsewhere); the commands' notifications
    redraw the tree; the deploy menu sees the country's count of deployments changed and builds its
    list again, closing when empty (section 2).
12. **A drop off every row does nothing**: nothing posted, the line stays, the callback freed at the
    next drag or with the observer. `confirmed`
13. **Neither reverse exists.** Nothing hands a deployment drag to the map - the observer's only target
    is the browser, and the callback class is made in one place (`confirmed`). A browser row dropped on
    the deploy menu does nothing: the browser's release looks only at its own two lists and the menu
    has no drop handling (`likely`).

**The plain case - choose a line, click a province - was not found in this class.** The
in-game screen is told which deployment is being placed (slot 30) and the click must be
handled there with the rest of the map's clicks; it posts the same command with no target,
by `FINDINGS-buildqueue.md`'s account of `Execute`. `inferred`.

### 6.2 Evidence

- **The press.** `CDeploymentEntry::CDeploymentEntry` (0x826F40) builds the `select` button's glue
  (0x828E10) with the slot-4 thunk 0x67A310 (OnSelect) first and **0x827600 third**, as
  `COOBUnitEntry`'s constructor puts the click first and its `OnDragStart` third (0x735EB4, 0x735EBD).
  The glue's table (0x15E0408) sends observer slot 2 to the first handler (+8) and slot 4 to the third
  (+0x10). `GuiButton_HandleMouse` (rva 0x6CFBE0) calls `GuiButton_NotifyPress` (rva 0x6CFEE0,
  observer slot 4) at 0xACFC4D on left-button-down, setting the button's state to 1, and
  `GuiButton_NotifyClick` (rva 0x6CFEA0, slot 2) at 0xACFC73 when the button comes up pressed.
  0x827600 (`CDeploymentEntry::OnDragStart`) resolves the deployment; where `GetType` is 0x4B4 and +0x38
  is non-null it writes observer (menu +0x28) +0x10 = the line and +0x18 = 1 (0x827643, 0x827646), else
  0 to both. `OnSelect` (0x8276C0), the line's destructor (0x827415) and the observer clear both.
- **The hand-over.** `CSideMenuDeploy::Update` calls the observer's slot 1 first (0x827AA3).
  `CDeploymentMenuMouseObserver::OnMouse` (0x828C20-0x828D80, read whole): the menu's slot 4 (IsShown)
  and `[in-game screen slot 105]+0xF4` (the browser open), failing either clear and return (0x828C4F,
  0x828C5C); press_pending == 1 (0x828C62); the pointer from input slot 19 inside the rectangle of
  `COOBBrowser +0xD0` (corner from its +0x18 slot 15, size from slot 24; 0x828C6C-0x828CE5);
  `CDeploymentEntry_GetUnit` (0x8274A0); the old callback freed (0x828D05); the new
  `CDropAndAssignUnitDeploymentCallback` (vftable 0x15E02DC, +4 from
  `CDeploymentEntry_ResolveDeployment` 0x8274D0, +8 the in-game screen); `cmp [unit+0x40],1` -
  `BeginDragSubUnit` with the first regiment (0x828D58), else `BeginDragUnit` (0x828D6D). No mouse-button
  test in the body.
- **The browser.** `COOBBrowser::Update` (0x739CA0): state 1 records the pointer (0x739DE8); state 2
  becomes 3 on a move of more than 2 (0x739E05-0x739E2D); references resolved only at state 3
  (0x739E44); on release (input slot 12 false) `UnitRows_HandleDrop` on the main list (0x739F67), then
  the split list (0x739F89), then `ClearDrag` (0x739FA3); a release before state 3 reaches `ClearDrag`
  with nothing resolved (0x739F4C); the rows' update is passed the callback (+0x98) as `anyProvince`
  (0x73A2EA), which switches the same-province test off in the hover. The hovers call only
  `CUnit_MayTakeSubordinate` (0x7363BF) or `CUnit_CanTakeSubUnit` (0x736596), never `CanDeployIn`.
- **The drop.** `UnitRows_HandleDrop` (0x73A7C0-0x73AE70, read whole). Unit path:
  `CUnit_MayTakeSubordinate(row, unit, 0)` (0x73A8BA); the callback's slot 0 with the row's unit
  (0x73A8D9), +0x98 cleared; then, unconditionally, `CAttachUnitCommand` (0x73A906), posted at
  0x73A9BE; +0xF8 and +0x120 written. Sub-unit path: sameProvince = `sete([+0x98]==0)` (0x73AAB8) into
  `CUnit_CanTakeSubUnit` (0x73AAC4); the deployment's slot 10, `CanDeployIn`, with the row unit's
  +0x130 (0x73AAF6); only if true, the callback (0x73AB1D); the callback cleared either way, nothing
  posted on false; then `CTransferSubUnitCommand` (0x73AB6C).
- **The command.** `CDropAndAssignUnitDeploymentCallback::Call` (0x826130, read whole) builds
  `CDeployUnitCommand` (0x548FF0): province the unit's +0x130, then +0xD0; country the in-game screen's
  slot 23 (GetPlayer); deployment the callback's +4 id pair; target the unit's id pair; posted through
  the in-game screen's slot 18, the object `HandleDrop` posts through (`g_CCurrentGameState +0xBE8`).
- **Exclusivity.** The callback's vftable has one reference in .text (0x828D39). `BeginDragUnit` has
  five callers and `BeginDragSubUnit` two; only the observer's pass a callback. The callback's `Call` is
  reached only through `HandleDrop`.

*Checked by the collecting session the same day off the bytes: `0x828C55 cmp [ebx+0xF4],0`, `0x828C62
cmp [edi+0x18],1` and `0x828C6C mov esi,[ebx+0xD0]` with no button test between; and `0x73A8D9` the
callback followed at `0x73A906` by the attach command's constructor with no branch around it.*

### 6.3 What is not established

- What the second command does after the deploy command has run, and whether the player sees
  `TRANSFEREDSUBUNIT` twice for a one-brigade drop.
- What becomes of a unit attached while its deployment could not be placed (rule 10).
- Whether a unit on loan is offered as a row target on the several-brigade path:
  `MayTakeSubordinate` does not test loan, while the menu's own target list excludes such units.
- Cursor and tooltip behaviour beyond the floating row and the rows' frames.
- The plain placing click; the record's `CDeployUnitCommand` constructor names the in-game input
  handler's placing click (0x65393B) as a poster with no target, not read here.
- Button slot 67 (`GuiButton_PollMouse`): who calls it.
- 0x827520, a `CDeploymentEntry` routine that greys `select` by the custom-game flag, with no direct
  reference; the press handler has no custom-game gate, unlike `COOBUnitEntry::OnDragStart`.

## What was not read

- **When `alert_deployable_units` is up.**
- **How the map shows where a unit may go** while one is being placed, and the click that
  places it: the in-game screen's slot 30 (`0x667DB0`) and whatever reads what it stores.
- **The carrier air group rule** among the targets.
- **`0x5B9760`**, which puts one unit under another, and the message that follows.
- **The two AI helpers** that swap the target when `JoinUnit`'s flag is set.
- **The tooltips** of both kinds of line (`0x826CA0`, `0x826200`).
