# A message's Goto, and the picture and label of a builder's selection

Read 2026-11-08, for OpenHOI3. The callback every raise hands `PostMessage<T>`, and what the
builder windows put in their `selected_*_photo` and `selected_*_label`.

**Synopsis.** Every message type's Goto is one of six callbacks, chosen by the raise and not by the
type's file; 119 types only centre the map, a battle's and a bombing's select it, the technology and
`BUILDING_DONE` messages go through one virtual of the in-game screen. Nothing was corrected. The
builders' label and picture were `likely` and `how the picture is chosen was not read`; the label is
now `confirmed` in the brigade, air and ship builders, and the designer's picture is its first
brigade's.

**How the table was made.** For every string in `.rdata` of a message type's shape that
`interface/messagetypes.txt` or TFH's declares, each code reference to it, walked forward to the
next direct call of any of the twelve `PostMessage<T>` instances within 0x1800 bytes, and the
callback loaded in the 0x400 bytes before that call. **`inferred` for any one type** - the walk can
reach the wrong post where one function raises several - and `confirmed` for the six callbacks' code.

## 1. The callbacks

`message` is the `CMessage`: +0x38 first country's index, +0x40 second's, +0x44 the province, +0x4C a
string the raise gives, +0x68/+0x6C a unit's persistent id, +0x20 the type. All `ret 4`. The popup
closes only where the callback answers false; a log row's left click runs the same callback and
ignores the answer (`FINDINGS-messageshow.md`, sections 3 and 4).

| rva | name | what it does | answers |
| --- | --- | --- | --- |
| 0x2995D0 | `CMessageHandler::GotoProvinceForMessage` | centres on +0x44, else the acting capital of the first country, else of the second where the first is null | true |
| 0x2996F0 | `CMessageHandler::GotoUnitForMessage` | finds the unit by +0x68/+0x6C; clears the selection, selects it, centres on its province | **false**, so the popup closes |
| 0xD7FE0 | `CCountry::GotoCapitalForMessage` | where the first country is not null, centres on its acting capital | true |
| 0xA6040 | `CProvince::SelectBattleForMessage` | already recorded | |
| 0xA62F0 | `CProvince::SelectBombingForMessage` | the province's bombing (+0x2FC): none, false; else clears the selection, selects it, centres on its province, true | |
| 0x24AB10 | `CInGameIdler::MessageGotoScreen` | slot 78, below | true |
| 0x24AA80 | `CInGameIdler::MessageGotoProvince` | slot 79: centres on +0x44, else the capitals as 0x2995D0 | false where there is no province |

Two more are the compiler's thunks for a pointer to a virtual member: **0x122400** `jmp [eax+0x138]`
and **0x54F70** `jmp [eax+0x13C]`.

**Slot 78** closes the side menus and the orders view, and clears the selection. Then, by +0x4C and
the type's name:

- +0x4C is `open_diplomacy` (`DIPLOEXPIRE`'s raise, the only place that string is assigned, in rva
  0x648B20; its province is `GetCapitalLocation` of the agreement's second country): clear, select
  the province (null where there is none), `OpenCountryView(0)` - diplomacy, and it opens on that
  province's owner;
- `TECH_ONCE` or `TECH_REPEAT`: `OpenCountryView(2)`, technology. **`OpenCountryView` is a toggle**,
  so a Goto with the technology screen already up shuts it;
- `BUILDING_DONE`: centres on +0x44, else the capitals;
- anything else: nothing beyond the clearing.

## 2. Which type has which

| callback | types |
| --- | --- |
| none: the popup closes, a log row does nothing | `ALLYTAKEOVER`, `ALLYTAKEOVERWE`, `CHATMESSAGE`, `DECISIONOTHER`, `DECISIONUS`, `EVENTHAPPENOTHER`, `EVENTHAPPENOTHEROPTION`, `EVENTHAPPENUS`, `GIESWAP`, `GIESWAPFORUS`, `LAW_APPOINTED`, `MAJORDECISIONOTHER`, `MAJOREVENTHAPPENOTHER`, `MAJOREVENTHAPPENOTHEROPTION`, `MINISTER_APPOINTED`, `NEWFOGOTHER`, `NEWFOGWE`, `RETURN_EXILE`, `TRIGMOD`, `TRIGMODLOST`, `WE_RETURN_EXILE` |
| `SelectBattleForMessage` | `ATTACKTHEM`, `ATTACKUS`, `NAVALATTACKTHEM`, `NAVALATTACKUS`, `AIRATTACKTHEM`, `AIRATTACKUS`, `SHATTERED` |
| `SelectBombingForMessage` | `BOMBTHEM`, `BOMBUS` |
| `GotoCapitalForMessage` | `GIESWAPOTHER`, `INDEPENDANCE` |
| `MessageGotoProvince` | `INVADEDUS`, `PARATROOPEDUS` |
| `MessageGotoScreen` | `BUILDING_DONE`, `DIPLOEXPIRE`, `ELECTIONRESULTS`, `NUKE_ON_OTHER`, `NUKE_ON_US`, `OTHER_DEMOBILIZE`, `OTHER_MOBILIZE`, `SPIESFOUNDTHEM`, `SPIESFOUNDUS`, `TECH_ONCE`, `TECH_REPEAT`, `TECH_STOLEN`, `TECH_STOLEN_BY_UNKNOWN`, `THEYSURRENDER`, `THEYSURRENDERUS`, `WESURRENDER`, `WE_DEMOBILIZE`, `WE_MOBILIZE`, `WE_NUKE`, `WE_STEAL_TECH_ONCE`, `WE_STEAL_TECH_REPEAT` |
| `GotoUnitForMessage` | `EXPRETURNED`, `EXPRETURNEDWE`, `UNITARRIVED_AIR`, `UNITARRIVED_LAND`, `UNITARRIVED_NAVAL` |
| `GotoProvinceForMessage` | the other 119 the walk reached: every diplomatic, trade, aid and faction message, the battles over, `ANNEX`, `DISBAND`, `PROVINCELOST`, `REVOLT`, `PARTISANS`, the undergrounds' |

**Declared and reached by nothing**: `LEADERDIED`, `MINISTER_DEATH`, `REINFORCE`, `RETURN_EXILE_US`,
`SHIPSUNK` - the file gives them buttons and no code raises them. `inferred`: a negative from the
same walk, whose positive control is the 171 types it did reach.

Hardcoded: which callback a raise hands. Mod-able: whether the button is there at all (`option`),
its words (`_BTN3`), and whether the type pops up.

## 3. A builder's label and picture

`confirmed` in `CBrigadeBuilder::Update`, `CAirBuilder::Update` and `CShipBuilder::Update`, each when
the selection changes:

    model = PickBestModel(the country's set for the type, a brigade at the country's own levels)
    none:  label = the type's name
    else:  label = "(§Y" + the model's name + ("" where model == FindModelOf(the same), else "+*") + "§W)\n"

**`FindModelOf`** (rva 0x182FA0), read whole: for each model of the set, in order, a count starts at the brigade's number of
technologies and drops by one for each of the model's entries that names a technology of the brigade's where that technology's
`change` is false or the two levels are equal; the first model that brings it to nought is answered. So a technology the
model does not list keeps it from matching, and one with `change = no` matches at any level. The record's word had been
"every technology level the brigade has".

The picture is `SetSubUnitPhoto(icon, the country, that brigade)` (rva 0x277410, recorded). **With
nothing selected the label and `selected_brigade_description` are emptied and the picture is not
touched**, so it stays what it was, the file's `GFX_no_ship_selected` until something is picked.

`selected_brigade_description` is `CSubUnit::EquipmentText` of that brigade.

**The division designer's `selected_photo`** is set inside `CDivisionDesigner::UpdateDesign`'s loop
over the design, under a flag set after the first pass: **the first brigade's** picture, the
country's. With an empty design the loop does not run, so it too keeps what it had. The designer has
no label of its own. `confirmed` for the flag, `likely` that the list's first node is the first
brigade added.
