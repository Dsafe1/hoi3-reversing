# Four small pieces of the interface

Read 2026-11-08 for OpenHOI3's interface, the small batch wave (`WAVE.md`). Static reading of `hoi3_tfh.exe`; the game was not run. **Addresses are VAs unless a line says rva.** Marked confirmed, likely or inferred. Text is the English column of the install's tables, the key beside it; the winning `.gui` is `tfh/interface/` unless said otherwise.

## 1. `disbandbutton` on the single unit panel

**When it can be pressed** (`CSingleUnitButtons::Update`, 0x75EC40; `confirmed`). Under the custom-game lock (0x4208B0) it is disabled. Otherwise it is disabled at the first of these that holds, and enabled if none does:

1. a land unit (slot 15) aboard a fleet (+0x300) or a plane (+0x304);
2. a unit of `oob_level` 0 (+0x1F4) whose theatre (`CUnit_FindTheatre`, rva 0x1D2A00: the owner's strategy's theatre for the unit's id) exists and has `added_provinces_count` (`CTheatre +0x68`) above nought, meaning a theatre headquarters whose theatre still holds provinces;
3. a unit with an AI agent (`CUnit +0x198`), the agent on the unit itself, with no walk upward;
4. a unit on loan (`CUnit +0x290`, `expeditionary_owner_id`, the id half of the `expeditionary_owner` tag);
5. in a battle (`CUnit +0x11C`, `combats_count`, above 0).

Its tooltip is the strip's own: `DISBAND_UNIT` "Disband Unit", delayed `DISBAND_UNIT_DRO` "Disbanding an army will reduce the amount of supplies and fuel your nation is spending on maintenance. If the unit is under-strength, it will free manpower to reinforce units in more important areas." (no test on enabled; 0x760AC2).

**The click** (`CSingleUnitButtons::OnDisbandButton`, 0x75E790; glue +0x310, handler pushed at 0x75D1D1, registered on the button at 0x75D34E). It does nothing under the lock (`GetCustomGameSettings` byte set and 0x4208B0 true). Otherwise a new `CConfirmDisband` goes on the screen's dialog list (`CEU3Idler::AddDialog`). It tests nothing else. `confirmed`.

**The dialog** (`CConfirmDisband`, RTTI, 0x94 bytes, base `CEU3Dialog`, table 0x15D879C; `confirmed`). The constructor (0x748170, screen in ECX, stack `storage`, `unit`) uses window **`DefaultConfirm`** (`interface/eu3dialog.gui`, no TFH copy): 500 x 280, `position (-250,-140)`, orientation CENTER, `moveable = 0`, nothing in code moves it. `AgreeButton` (x 264, `OK` "Ok", ENTER), `DeclineButton` (x 104, `CANCEL` "Cancel", ESCAPE). `Title` is `CONFIRM_DISBAND_TITLE` "Do you wish to disband this unit?"; `Description` is `CONFIRM_DISBAND_DESC` "This will remove the unit completely from the game, and you will no longer have to pay any maintenance costs for it. Any manpower remaining in the unit will be returned to the pool.", with a `NAME` replacement of the unit's name (slot 7) that the English text does not use.

- **Slot 5, OnConfirm** (0x748450, `confirmed`): re-finds the unit by its id pair (+0x70/+0x74); makes `CDisbandCommand(unit)` (constructor 0x5D99A0) and posts it on the session's channel (game state +0xBE8 slot 18, then +0x38 slot 6, as the multi-unit's). Marks the dialog done (+0x64 = 1). Sets the screen's `reshow_open_view` (+0xD30) unless the custom game's settings are present and its +0x18 is 2.
- **Slot 6** is `CEU3Dialog`'s, close only.
- **Slot 7, StaysOpen** (0x7485B0, `confirmed`): looks the unit up by id, stores it at +0x6C, answers whether it exists. As other dialogs' slot 7, false closes it, so **the dialog closes itself when the unit no longer exists; a changed selection does not close it**, unlike `CConfirmDisbandAll`.
- **The selection and panels**: `OnConfirm` does not clear the selection. When the command runs, `CDisbandCommand::Execute` calls `CGameState::RemoveUnit`, which deselects the unit; the panel goes through its own teardown as for any selection change (`FINDINGS-attachbuttons.md`). The `DISBAND` message is `Execute`'s (`FINDINGS-selection.md` B.4; `DISBAND_LOG` "$UNIT$ was disbanded.").

Hardcoded: all of the tests. Mod-able: the window (`eu3dialog.gui`), the texts.

## 2. `ElectionResultPopup`

**What posts it.** `CCountry_HoldElection` (rva 0xFBFF0-ish, recorded) with `notifyPlayer` set: the type `ELECTIONRESULTS` (`messagetypes.txt`: log=no, onmap=no, popup=yes, pausepopup=yes, option=no, cat_other) is found and its `popup_kind` set to 3 each time. `CMessage` has three variables and a data pointer: `PREVIOUS_PARTY` (the ruling ideology before `CCountry_SetRulingIdeology`, the name for the country, slot `GetNameForCountry`), `WINNING_PARTY` (the winner's name for the country), `ELECTION_YEAR` (`last_election` - 43800000) / 24 / `g_DaysPerYear`, as text), and **argument 6, the scratch `CIdeologyData` of scores** normalised to sum 100.000 (`CIdeologyData_NormaliseToHundred`), which lands at `CMessage +0x70` (the dialog's message is at +0x6C, so read as dialog +0xDC). First country: the player. The scores are computed before the ideology is applied; ministers and cabinet seats are refilled before the post, so the lists show the new cabinet. `confirmed` from the decompilation of 0x4FBFF0..; the receiver is `CInGameIdler` so the **8-byte** builder rva 0x534A0 runs; the 4-byte rva 0x654640 is its identical twin (the observer +0x144 becomes +0x14C and the callback +0x13C becomes +0x140; everything below is the same; read both).

**The window** (`interface/election.gui` and `tfh/interface/election.gui`, the TFH copy winning): `eu3dialogtype` `ElectionResultPopup`, `position (-465,-333)`, size 888 x 520, CENTER, `moveable = 1`, `backGround` "Background".

| element | what it is | what fills it |
| --- | --- | --- |
| `Background` | button of `GFX_bg_ministers_election` (904 x 556 on disk) | gets the right-click observer |
| `Title` | textBox (202,22), `Arial_17`, 500 x 32, centre | `ELECTIONRESULTS_HEADER` "Election $ELECTION_YEAR$", rendered |
| `Description` | textBox (202,67), `Arial14_black`, 500 x 230, centre | `ELECTIONRESULTS_1` "$WINNING_PARTY$", rendered |
| `result_chart` | icon of `GFX_election_result_chart` (a `PieChartType`, size 100), (127,190) | the pie, below |
| `minister_list1`, `minister_list2` | list boxes (270,103) and (600,103), 300 x 400, spacing 2 | the posts, below |
| `AgreeButton`, `DeclineButton`, `CenterOK` | 128-wide buttons, file x 536, 236, 386, file y 700 | below |

`ELECTIONRESULTS_2` "Won the election" and the rest are never read by the popup: only `_HEADER`, `_1` and the `_BTN` keys are. `ELECTIONRESULTS_LOG` is not used because `log=no`.

**The variables**: `_HEADER` and `_1` each get one `$KEY$` -> `GetText(value)` replacement per variable on the message's list, as `BuildMessagePopupText` does for a default popup, **but no `§W` -> `§b` swap**; `Title` and `Description` are `CInternationalizedText::Render` directly. `confirmed`.

**The pie** (`confirmed`): where the message's +0xDC is set (always for this type), for each ideology from index 1 in database order a slice of the ideology's colour (+0x54) and size `round(max(values[ideology +0x4C], 1000) / 1000.0)`, the value through single precision and `fistp` (round half to even), into the pie through 0xAA37D0. **Every party that exists is drawn at no less than 1**, so a party with nothing shows one percent and the slices can sum past 100. Values are the election's scores, not the popularity.

**The lists** (`confirmed`): both emptied, then for each government post from index 1 (`n` the count; `mid = (n-1)/2`): a `CMinisterItem("minister_entry2", the screen, view null, post, minister null, false)` into `minister_list1` where the post's index is `mid` or less, else `minister_list2`. `Refresh` runs at once. `Refresh` with a null minister reads the played country's holder of the post (+0x618), so the rows show the **new cabinet**. The row is `minister_entry2`: photo `GFX_empty_position` with a portrait over it, `legend_color`, `title` (the post's name), `name`, `personality`, `ability`, as a politics row (`CMinisterItem`, recorded). There are no buttons in it; the constructor's `replace_minister` lookup is guarded.

**Layout**: `Background` is sized to (its width, `popup_bottom_button_pos.y` 70 + `popup_textline_dist.x` 50) through the sprite's slot 64, the same arithmetic slip as the default popup's. For a plain picture slot 64 is the empty `ret 4` of `C2dObject` (confirmed on `C2dObject`, which `CShieldObject`/`CSprite` inherit), so the background keeps its texture size. Then the three buttons' y is set to `Background's height - 70 + 17`; x stays the file's. With the texture's 556 that is **y 503** (`inferred`: that slot 64 is a `ret 4` on a button's sprite is inferred from the hierarchy, not traced to the object). The cascade is the default popup's (the handler's +0x2C count moved on, to 0 after 10; `10 x count` right and down of its base position, clamped to the screen less 10, plus 40 down, shown). `confirmed`.

**Buttons**: the type's `option` is off, so `AgreeButton` and `DeclineButton` are hidden (slot 65) and `CenterOK` is shown with `ELECTIONRESULTS_BTN1` "OK", closing it (observer +0x38). ENTER is `CenterOK`'s `.gui` shortcut (also `AgreeButton`'s), ESCAPE is `DeclineButton`'s. With `option = yes` the arm is `_BTN2` "OK" and `_BTN3` "Details" on the two buttons, `_BTN3` running the callback where there is one, as the default popup. `Background`, `AgreeButton`, `DeclineButton` and `CenterOK` all carry the right-click settings observer (+0x144/+0x14C). A plain popup's other rules (`FINDINGS-messageshow.md`) hold.

**Pause**: `pausepopup=yes` means the post's own pause arm applies in single player.

**Tooltips** (`CInGameIdler` slot 37, 0x675CA0, `BuildMessageDialogTooltip`, only for a type of `popup_kind` 3; `confirmed`):

- `result_chart`: the slice under the mouse (0xAA3270 with the screen's mouse point), the ideology at `index + 1`, its name for the played country (slot 14), then ` - §Y`, the whole percent the slice was given, `%§W`. No delayed half.
- Anything else: the row of `minister_list1` or `minister_list2` that owns the element (row's second table, slot 22) gets `CMinisterItem::BuildTooltip`: the minister's ideology on `legend_color`, `replace_minister` n/a.

Hardcoded: which variables, the 1 floor, the mid-split. Mod-able: the window, the texts, `messagetypes.txt` (`popup`, `pausepopup`, `option`), the sprites (a `PieChartType`'s size), `ELECTION_RANDOMNESS` (the scores).

## 3. `ai_need_queue` on the production screen

**It is the theatre needs list, one row per theatre, shown for any country, human included.** No test on human or AI anywhere in it.

**Filling** (`CProductionView::RebuildAiNeedQueue`, 0x7FCCE0, rva 0x3FCCE0; `confirmed`): the scrollbar's position saved; the list emptied; for each `CTheatre` on the played country's `Strategy.Theatres` list in list order: where its HQ id pair (`CTheatre +0x74`/`+0x78`) resolves to a live object, a new `_A0xbb459920::CAINeedEntry(screen, theatre)` appended (`Add(row, 0)`); the scrollbar put back if it had been past a small constant. No sort.

**When**: from `Show` (slot 2, 0x7FF59D), and each frame in `Update` (0x7FE6E5) when the row count differs from the theatre count; when the counts agree, each row's `Refresh` (slot 8) runs instead. While one of the dialogs the view owns is open (`+0x318`, and +0x300 to +0x314's four builders, tested in order), both `build_queue` and `ai_need_queue` are hidden (slot 21) and the dialog's update runs; nothing refreshes. The list is shown again (slot 20) when none is open. `confirmed` (0x7FE539-0x7FE68C). "Which dialog" is `FINDINGS-countryviews.md`.

**A row** (`CAINeedEntry`, RTTI, `_A0xbb459920`, table 0x15DEFC8, base `CStandardlistboxItem`, 0xC0 bytes; window `ai_need_entry` in `tfh/interface/country_production.gui`, 500 x 44):

| element | what it is | what fills it |
| --- | --- | --- |
| `theatre_need_entry` | icon `GFX_theatre_need_entry` (5,-2) | untouched |
| `name` | text (12,4), `Arial14_black`, 400 x 32, `fixedsize` | the HQ's name (slot 7) |
| `needs` | text (12,23), `Arial12_black`, 400 x 16, `fixedsize` | below |
| `build` | button `GFX_build_theatre_need` (430,19) | glue; enabled or disabled, below |
| `build_text` | text (452,24), `Arial12_bold`, `text = "Build"` | untouched: the `Build` key "Build" |

The HQ is held by id (+0x84/+0x88), found again each `Refresh`; a row whose HQ is gone writes nothing. `Refresh` (0x7F74E0, rva 0x3F74E0, `confirmed`):

    needs = HQ's plan_subunit_needed (+0x7C..+0x80), if its length is the sub-unit database's count; else go to NO
    for every military line in the played country's Constructions (+0xF40) that is military (slot 17)
      and is aimed at this HQ (line +0x90/+0x94 = HQ +0x10/+0x14):
        for each item of the line (the items list, +0x7C): needs[item's type +0x34 -> +0x24] -= the line's Size (+0x40)
    if any needs > 0:
        text = "" ; for each type index in database order with needs > 0:
          text += <n in decimal> + " £" + <the type's key> + ", "
        `needs` = text        (the trailing ", " is NOT cut; the theatres screen's immediate_needs cuts it)
        `build` enabled (no owner test)
    else: `needs` = NO_NEEDS_FOR_BUILDS "This theatre has no immediate needs for new units.", `build` disabled

**Where the data comes from** is the HQ's `plan_subunit_needed` (`CUnit +0x7C`), not a field of the row: the part of the plan's shortage the group as a whole still needs (recorded; `CUnit::UpdatePlanForceNeeds`, called by `CUnit::UpdateDaily` for level-0 units and by `RefreshPlanForceNeeds` when the plan's forces, stance or area change; for the theatre HQ of a human player's unit it is filled the same way, an active plan at the top reading `plan->min` and an inactive one a fresh wanted vector). The theatres screen's `immediate_needs` (`FINDINGS-topscreens.md` A.4) shows the same numbers. The only differences of this row: the trailing `, `, and no owner test on `build`.

**`build`'s click** (`CAINeedEntry::OnBuild`, 0x7F7FD0, `confirmed`): row +0xB8 = the played country's `Manpower`, then `BuildStep` (0x7F80C0) until it answers false; the row is not refreshed there (next frame it is, showing the lines just posted). `BuildStep` is `CTheatreView::BuildStep`'s order and arithmetic over this row's needs (+0xA8) and manpower (+0xB8), the command's target this row's HQ (`inferred`: compared call by call and compare by compare with `FINDINGS-topscreens.md`'s BuildStep; 212 against 211 such instructions, differing only in inlined accessors and the generator's inlining). So, as there: air before land by `air > land/4`, single series by the integer square root, a division by priority, then ships; the stack MT19937 is never seeded, so its picks are effectively arbitrary; a press may place several lines.

**The `needs` tooltip** (in `CProductionView::BuildTooltip`, `confirmed`): only where the element's name is `needs`; the rows of `ai_need_queue` are walked and those whose window holds the element take the walk over their `needs` text (no stop at the first):

    for each character:
      the marker 0xA3 (£): read the [A-Za-z_]* that follows; find it in the sub-unit database;
         append the type's display name (slot 6) where found, nothing where not; continue after it
      ',': append "\n"
      anything else: append the character

So `5 £infantry_brigade, 3 £armor_brigade, ` becomes `5 Infantry\n 3 Armor\n ` (each line after the first starts with the space that followed the comma; the last ends with a newline and a space). `name` and `build` have no tooltip; the row class has no tooltip slot of its own beyond the standard list item's.

**Hardcoded**: all of the above. **Mod-able**: `country_production.gui`, `GFX_theatre_need_entry`, `GFX_build_theatre_need`, the texts, and through it what the AI's plans want (`CUnit::UpdatePlanForceNeeds`'s inputs).

## 4. `selected_plane_desc_list` and `air_desc_entry`

**The routine** is at VA **0x5AB2C0**, rva 0x1AB2C0 (`FINDINGS-builders.md`'s "0x5AB2C0" and "0x5AACF0" are VAs; trap 1). It is **not** a split of a description text: it is a vector of strings, **one per technology of the sub-unit**, from the sub-unit's `technologies` list (+0x84). `CSubUnit::EquipmentLines` (`confirmed`):

    country = builder (+0x34/+0x38) if its id is set, else owner (+0x94/+0x98) (CCountryTag::GetCountry)
    for each node (technology, level, third figure):
      line = technology's name (slot 7) + " : §Y"
      line += CCountry_TechnologyLevelName(country, technology, level) -
              an exile naming a level above its own by its faction's first member
      if third figure > 0:  line += "§W(+" + FormatFixedPoint(third * 100000 / 1000, 2) + "%)"
      line += "§W"
      push line

The name function's rules are `FINDINGS-unitpaneltooltips.md` section 13. There is **no YES/NO arm** here, where `CSubUnit::EquipmentText` (rva 0x1AACF0, which the brigade builder's `selected_brigade_description` uses, a single text box; two callers 0x5AACA2 and 0x7DA666) has one.

**The air builder** (`CAirBuilder::Update`, 0x7D1350; rebuilt only when the selected type changes (`+0x16C != +0x168`), `confirmed`): a temporary `CWing` (0xD8 bytes) has `SetType(the type)`, each node's level set to the country's level of that technology (`level_by_technology`, the country's `TechnologyStatus`), then `ApplyTechnologies(false)`. `selected_plane_desc_list` is emptied, then the lines are made and each gets a row: a 0x28-byte object through the generic list-item factory `0xA8BBD0`, window **`air_desc_entry`** (in `tfh/interface/airbuilder.gui`; 1024 x 16), the single element **`selected_plane_description`** (`instantTextBoxType`, `Arial12`, `format = left`, 330 x 16) set to the line, appended in order. The temporary wing is not the unit being built.

The third figure on a fresh wing is 0 (its nodes come from `SetType` at level zero and only `level` is written), so the "(+x%)" arm never shows in the air builder. `confirmed` for the writing; `inferred` that `SetType`'s third figure starts at 0, from `SetType`'s record ("each at level zero").

**The temporary wing's builder and owner are not set** (`inferred` from a scan of 0x960 bytes of `Update` for stores to [reg+0x34/+0x38/+0x94/+0x98], which found none, and `CSubUnit`'s constructor does not visibly set them either). So the country is database entry 0, and the `TAG_technology_level` form of a level's name is asked with the null country's tag. Whether that ever differs from the generic `technology_level` text was not read.

**Siblings**: the brigade builder's `selected_brigade_description` is a single text box (`tfh/interface/brigaderbuilder.gui`, `Arial12`, 330 x 200, `format = left`) given `CSubUnit::EquipmentText` of its temporary brigade (one string with its `\n`s), and the ship builder has **no** description element at all (`shipbuilder.gui`, no `desc` in the file; neither routine has a caller from `CShipBuilder::Update`). Hardcoded: the line's form. Mod-able: `airbuilder.gui`, the unit types' technology lists, the level-name keys.

## 5. The message of a battle begun (`CCombat::Begin`, rva 0x172580)

Read by the collecting session. `CCombat` slot 13, which `CCombatManager::Tick` calls before the round where `begun` (+0x29) is clear; it sets `begun`, and a convoy battle stops there. **Everything else in it is the message.** `confirmed` unless said.

The variables, on top of the played country's own (`CCountry::BuildMessageVariables`): `MESSENGER` `MESSAGE_HEAD_MARS`, `ATTACKER` the names of the attacker's units' countries (rva 0x170C60, below), `PROV` the province, `DEFENDER` the same of the defender's and empty where it has no unit, `ATTUNIT` `CombatSide_Summary(attacker, no names)`.

**A bombing** (slot 8 true): `DEFUNIT` the defender's summary with `CCombat_BombingSummary` after it; `ORDER` the name of the first attacker's order (empty with none). The player among the attacker's countries: `BOMBTHEM`. Otherwise among the defender's: `BOMBUS`, its first country the province's controller.

**Anything else**: nothing where either side's `countries` list is empty. `DEFUNIT` the defender's summary. The player among the attacker's countries (+0x10, the list tested first, 0x5731F8): `ATTACKTHEM`, `NAVALATTACKTHEM` or `AIRATTACKTHEM` by `GetKind` (1 land, then naval, else air), first country the player and second the defender's first. Otherwise among the defender's (+0x14, 0x5733E3): the `...US` types, first country the attacker's first and second the player. Both also carry `DEFTOTAL` and `ATTTOTAL` (the two summaries) and `DEFDETAIL` and `ATTDETAIL` (`CombatSide_UnitNames(side, 6)`). The province's callback is `CProvince::SelectBattleForMessage`.

`CombatSide_UnitNames` with a limit under 21: each unit a line, its name cut to 20 letters; past the limit `AND_MORE` in place of the rest.

**The names of a side's countries** (rva 0x170C60, `CombatSide_CountryNames`): for each unit its owner's name - for `REB` the rebel faction's where one is found (`FindRebelFactionByObjectId`) - kept once each, then joined by `, ` with ` AND ` before the last. Order: as they come (`inferred`, the node insertion was read only in outline).

**The popup's columns** (`BuildMessagePopupText`, VA 0x4373D5 on): with y where the six lines ended, `combatstart_divider`, `Line_left_1` and `Line_right_1` all at y keeping their own x; y grows by `Line_right_1`'s height (+0xAA); `Line_left_2` and `Line_right_2` at y; y grows by `Line_right_2`'s height. The background and buttons then use that y. So the left column's height is never asked.

By default only `ATTACKUS` pops up (`messagetypes.txt`); the land and naval types go on the map; the air and bombing types go nowhere until a player's file says so.

## What is not established

- The button y of the election popup (503 from a 556-high picture) rests on the sprite's slot 64 being the do-nothing `ret 4`; that the button's +0x88 object is a `CSprite` was inferred from the class hierarchy.
- `CAINeedEntry::BuildStep` is `inferred` the theatre's by a shape diff, not re-read line by line.
- Whether `TAG_technology_level` ever answers differently from the generic text for the air builder's null-country lines was not read.
- The election's `CIdeologyData` is not freed by `CCountry_HoldElection` and is shallow-copied into the dialog's message; who frees it (if anyone) was not looked for.
- Nothing here was compared with a running game or a savegame; the message and the windows are interface, and no save keeps them.

Frontier: `0x6A3270` (rva of 0xAA3270, the pie's slice under the mouse), `0x41C4E0`/`0x4208B0` (custom-game settings and lock), `0x4385B0`/`0x438460` (a pie slice's colour-and-size entry and the vector's append), `0x6A37D0` (rva of 0xAA37D0, recorded elsewhere, the pie's slice setter), `0xB41300` (the button's GetSize slot's forwarder).
