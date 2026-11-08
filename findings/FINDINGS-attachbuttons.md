# Attaching, detaching and making a headquarters

Read for OpenHOI3's unit panel, 2026-11-08. Static reading of `hoi3_tfh.exe`; **addresses are VAs** unless they say rva. `confirmed` where the bytes were read, and `inferred` is said where it applies. The `.gui` that wins is `tfh/interface/`; `unitpanel.gui`'s attachment section is the same in the base install. All texts below are from the install's tables (Windows-1252).

## 1. The strip's three handlers

`CSingleUnitButtons`'s constructor (`0x75CED0`) registers one glue for each. `attach_button` uses the glue at `+0x130`, `detach_button` the one at `+0xE0`, and `create_corps`, `create_army`, `create_armygroup`, `create_theatre` all share the glue at `+0x180`, so there is **one handler for four buttons**. Keyboard shortcuts in `single_unitpanel.gui`: attach `a`, detach `d`, each create button `c`.

Every handler first tests the custom-game lock (`GetCustomGameSettings` byte set and `0x4208B0` true) and does nothing if it holds; a game with no custom settings does not have it. `confirmed`.

## 2. `attach_button`, and the window it opens

**The click** (`0x75E650`): if a panel is held at `+0x2C`, its window's slot 20 runs and the object is freed; then **a new `CUnitAttachmentPanel` is always made** and stored at `+0x2C`. So **a second press does not close it; it rebuilds it**. Ghidra shows the destroy as a whole `else` with an early return; the listing falls through into the construction. `confirmed`. Slot 20 (`0xAC1F60`) marks the window with `+0x46` and walks its children.

**The window** is `attachment_selection_panel`, position `x=320 y=150`, size 400x100, `moveable = 0`, no `Orientation` so the default upper left. It is made by the in-game screen's `CEU3Gui` (slot 14), slot 11, the same call as the panel's own windows, and nothing moves it, so **it stands at (320,150) as a top-level window**.

**It does not pause the game**: no such call in `0x76EF70`, whose only calls are the window factory, the two string assigns, `FindButton`, the country accessor, `CUnit_MayTakeSubordinate`, the insertion, `FindListBox`, the entry constructor and `Show`. `confirmed`. Not modal; `moveable = 0`.

**What shuts it**, all `confirmed`:

- **`back_button`** (`0x76F250`) hides the window (`+0x18`, slot 14); the object stays at `+0x2C` for the next press.
- **A row's press** (section 3) hides it the same way.
- **The strip being destroyed** discards it: `~CSingleUnitButtons` (`0x75D8A0`) does the slot-20-and-free. The strip is an entry of the panel's list, and emptying that list (`GuiListBox::Clear` -> `0xA8CAD0` -> `0xA8BB80`, which deletes each entry through its slot 0 with flag 1) destroys it. So it goes whenever **`CSingleUnitPanel::Rebuild`** or **`CSingleUnitPanel_Hide`** runs: selecting any other single unit (the screen writes the panel's `+8` and calls `0x762F40`, which calls `Rebuild` at once), any selection of other than one unit (`CInGameIdler::Update` calls `CSingleUnitPanel_Hide` where the row count is not 1), and `CSingleUnitPanel_RefreshIfChanged` seeing the count of units above or of battles change, or an AI agent appear or go.
- Selecting something else does not hide it directly, only through those.

**Its elements** (`unitpanel.gui`):

| element | what it is | touched by code |
| --- | --- | --- |
| `attach_bg` | `GFX_attach_bg`, at (0,-14) | no |
| `label` | `attach_label` = "Select HQ", centred, at (27,-7) | no |
| `back_button` | `GFX_button_128wide`, at (65,308), text `CLOSE` = "Close" | click only |
| `list` | list box at (5,14), 230x298, spacing 2, `standardlistbox_slider` | filled by the constructor |

No element has a tooltip of its own in the file, and nothing in code sets one for this window. `inferred` for the absence: the search was of the constructor and the two glue targets, and the panel is not among the sources `CSingleUnitPanel_ElementTooltip` walks.

## 3. The rows (`CUnitAttachmentEntry`, 0xD0 bytes, window `unit_assignment_entry`, 360x32)

**Who is listed.** Every unit of the owner's `CCountry +0xBAC` (all levels, the country's own list) for which `CUnit_MayTakeSubordinate(candidate, unit, 0)` is true. **No limit of distance or province, and no other test.** `confirmed`.

`CUnit_MayTakeSubordinate` (record, read again):

1. False unless the candidate's `oob_level` is lower than the unit's.
2. For an air or naval unit (slots 17, 16): false where the candidate's level is above 3.
3. For a land unit under anything but a theatre (level 0): false where the candidate already has more than four land units under it, the unit itself counted if already there (flag 0).

Levels are 0 theatre, 1 army group, 2 army, 3 corps, 4 division, 5 navy, 6 air, so **a candidate is always level 0 to 3**.

**The order.** The candidates are taken in list order and each inserted:

    node = tail of the list being built
    while node and SortsAfter(node's unit, the new unit): node = node's previous
    no node left: the new unit goes at the head; otherwise straight after node

`SortsAfter(a, b)` (`0x76EEE0`, the subject unit in the static `0x1A85628`):

    subject land (slot 15):   a.oob_level < b.oob_level -> true
    otherwise:                a.oob_level > b.oob_level -> true
    then, in both cases, where the level did not answer true:
      Distance(subject's province, a's) > Distance(subject's province, b's)

Distance is `CMap::DistanceBetweenProvinces`, four times the straight-line map distance. **The second test also runs where a's level is the other way round from b's**, so this is not a clean sort; do the insertion as written. Roughly: land subject, lowest ranks first, nearest first; air or naval subject, highest ranks first, nearest first. `confirmed`. Rows are added to `list` in that order after it is emptied; that the top row is the first added is `inferred` from the other lists.

**A row's elements**, set once by the constructor (`0x76E4E0`, no per-frame update):

| element | what it is given |
| --- | --- |
| `assign` | `GFX_attach_banner`, at (10,1): the row's button |
| `name` | the candidate's name (slot 7) |
| `location` | the name of the candidate's province, then the literal ` (`, then the distance as a decimal integer, then the literal `km)`, neither localised |
| `counter_type` | the sprite `GFX_counter_` + the first brigade's definition key (`+0x58`, `+8`) where the candidate's `+0x1F8` (`intel_level`) is at least 3, it has a brigade and the brigade has a definition; otherwise the empty suffix. **Set only where such a sprite exists**, else the file's `GFX_temp_unit_icon` stays. The icon's render node also gets a call (`+0x88`, slot 76), unread |
| `counter_size` | `GFX_counter_size` (6 frames) at frame `level 0: 6, 1: 5, 2: 4, 3: 3`. The code also has `4: 1 or 2 by brigades`, `5: 2`, any other `1`, which do not arise here |
| `unit_pride_star` | `GFX_unit_stars`, frame 3 where the first brigade's `+0xA5` (`pride`) is set, otherwise as the file. An HQ brigade has none in practice |

The class has no tooltip slot (its first table holds 12 slots, against 14 for `CChildUnitEntry`) and no update. The row's window has nothing else.

**A row's press** (`0x76ED40`, `assign`):

- `CAttachUnitCommand(the unit, the candidate)` posted (the candidate is the parent; pushes at `0x76EDE3`/`0x76EDE4`); then the panel's window hidden.
- **It tests nothing itself.** `CAttachUnitCommand::IsValid` and `CUnit_AttachToParent` do what the record says, and **`Execute` does not test the limit**.
- The list and the selection are left alone; the selection does not change. The command's result brings a Rebuild, which disposes of the window.
- For the player, `Execute` raises `ATTACHEDUNIT`: `ATTACHEDUNIT_1` "$UNIT$", `ATTACHEDUNIT_2` "has now been attached to", `ATTACHEDUNIT_3` "$PARENT$", `ATTACHEDUNIT_LOG` "$UNIT$ is now attached to $PARENT$." (`messages.csv`).

## 4. When the buttons may be pressed (`CSingleUnitButtons::Update`, `0x75EC40`)

**No unit above** (`CUnit +0x1E0` null): `attach_button` shown, `detach_button` hidden. Then, with the lock off:

    any_commander = any unit u of the owner's country (+0x128) with MayTakeSubordinate(u, unit, 0)
                    (the walk does not stop at the first)
    enabled = !CUnit_AllSubUnitsAreCag(unit) && any_commander

`CUnit_AllSubUnitsAreCag` (`0x5D1220`) is true where every wing is a carrier air group and the unit has at least one, so **a carrier air group cannot be attached through this button**. Under the lock, attach is disabled.

**A unit above**: `attach_button` hidden; `detach_button` hidden where `CUnit_AllSubUnitsAreCag`, else shown; under the lock detach is disabled (custom game only).

Tooltips (`BuildTooltip`, `FINDINGS-unitpaneltooltips.md`): `UW_ATTACH` "Attach this unit into the unit hierarchy", or `UW_NOT_POSSIBLE_TO_ATTACH` "There is no unit higher up in the hierarchy that this unit can be attached to." where the button is not enabled (the element's enabled slot, 48); `UW_DETACH` "Detach this unit from its current position in the unit hierarchy".

**The four create buttons.** One is shown by `oob_level` (4 corps, 3 army, 2 army group, 1 theatre, 0 `edit_theatre`); levels 5 and 6 show none. All four are enabled together exactly when:

    !lock
    and not (parent != null and parent.oob_level + 1 >= unit.oob_level)
    and (no custom game or 0x420EB0(settings))
    and owner.Manpower >= hq_brigade.build_cost_manpower

A parent is always at least one level above, so the middle test means **a parent exactly one level up**: a division under a corps may not make a corps, a division under an army may, and an army group with a theatre over it may not make a theatre. `0x420EB0` is the custom-game test that does not apply. **The manpower compared is the brigade's whole `build_cost_manpower`** (signed int, thousandths; `hq_brigade +0xFC`; 1.67 in `tfh/units/hq_brigade.txt`), though `Execute` then charges only a twentieth. `confirmed`, `0x75F2C9`..`0x75F38C`.

Tooltips: `UW_CREATE_CORPS` "Create a new corps, and attach this division to it.", `UW_CREATE_ARMY` "Create a new army, and attach this corps to it.", `UW_CREATE_ARMYGROUP` "Create a new army group, and attach this army to it.", `UW_CREATE_THEATHRE` "Create a new theatre, and attach this army group to it." (the key's spelling is the game's), delayed `UW_CREATE_ABOVE_DRO` "Creating a unit one tier above the current will create a new headquarters brigade in the current province. This HQ unit will be created at 0 strength, so it will need to be reinforced before it is fully combat ready."

## 5. `detach_button`'s click

`0x75D9D0`: `CDetachUnitCommand(the unit)` posted to the session. Nothing else; the panel and the selection are left as they are. `Execute` then calls `CUnit_LeaveParent(unit, true)` (record), the unit keeps its children, and for the player `DETACHEDUNIT` is raised: `DETACHEDUNIT_1` "$UNIT$", `_2` "has now been", `_3` "DETACHED", `_4` "from the hierarchy.", `_LOG` "$UNIT$ detached from unit hierarchy.". `confirmed`.

## 6. The `create_*` click

`0x75DAE0`: after the two custom-game tests, **`CCreateHigherCommand(this, the unit)`**, the one-unit constructor `0x5DF320`, so **`+0x54` (select) is 0: the new headquarters is not selected and the selection stays on the unit it was made from**. It tests nothing else: the level, the parent and the manpower are the enabling and the command's `IsValid` (for one unit, `floor((1 + 0.0005) x 1000) x cost / 1000` = the cost, so the same figure as the button's). `confirmed`.

The headquarters' id pair is reserved in the constructor, and the persistent counter moves by 3 (record).

## 7. Several units at once

`highercomm_multiunit` (`CInGameIdler::OnHigherCommandMultiUnit`, record, `FINDINGS-selection.md` B.4): the vector from `CInGameIdler_CollectForHigherCommand`, the manpower of **n headquarters' worth** against the first unit's owner, the selection cleared, then the **new constructor at `0x5DF430`**: `(this, a pointer to a vector of CUnit*)`, `ret 8`, the same in every way as the one-unit form except that **`+0x54` is 1** and every unit is appended to `+0x3C` as a CRef. So `Execute`, for the local player, **selects the new headquarters** (the screen's `Select`, slot 38). `confirmed`. Neither this nor `detach_multiunit` is missing a record: tooltips `HIGHER_COMMAND_MULTI_UNITS` and `DETACH_ALL`, and the greying, are in B.4. The delayed half from `0x4210E0` is custom-game only and not read.

## 8. A player's level-0 headquarters

`create_theatre` is reachable only for an army group (level 1) with no parent. `Execute` makes the level-0 `CArmy` and its `hq_brigade` as the record has them, in the unit's own province (or a carrier's home base). Then:

- **The name**: `CCountry::MakeUnitName` at level 0 with the headquarters' province. Where that province carries a theatre id (`CMapProvince +0x380`/`+0x384`) that resolves, the text is `NAMED_THEATHRE` "$PROV$ HQ" with PROV the name of **that theatre's** province with the most `victory points x 10000 + 5000 for a built naval base + its ic modifier` (the first of equals); otherwise, or where that name is taken within the country, `THEATRE_NAME` "$NUM$$ORDER$ Theatre", numbered. A freshly created headquarters often stands where no theatre is stamped. `confirmed`.
- **The theatre**: `new(0xA8)` `CTheatre(tag, country)`, id type 45 (`+8`), id the game's `g_theatre_id` which then moves on by one (`+0xC`), `unit` the headquarters (`+0x74`/`+0x78`), appended to the owner's `CCountry +0x570` list. **It holds nothing else**: no provinces, no fronts. `confirmed`.

For the player, `Execute`'s step 7 also tells the interface; with `+0x54` clear, as here, the selection does not move.

What the theatre layer does with an empty `CTheatre` afterwards belongs to `FINDINGS-theatres.md` and was not re-read.

## What is not established

- That the top row of `list` is the first one added: `inferred` from other lists.
- That no tooltip is set for the window's elements: `inferred` from the search above.
- The `+0x88`, slot 76 call on the counter icons' render node.
- `0x4208B0`, `0x420EB0`, `0x4210E0`: custom-game only and not read here.
- No savegame bears on any of this; it is interface and commands.

Frontier: `0x208B0`, `0x20EB0`, `0x210E0` (custom-game tests), `0x36EC80` (the entry's destructor body), `0x362F40` (the panel's show-and-rebuild on a selection).
