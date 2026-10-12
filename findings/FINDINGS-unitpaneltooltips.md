# The unit panel's tooltips

*Read 2026-10-12 for OpenHOI3's unit panel; the mechanics spec is
`OpenHOI3/docs/mechanics/unitpanel.md`, section 10. Addresses are VA / rva. Everything here is one
build of `hoi3_tfh.exe`. Nothing in it was watched in a running game.*

What the panel of a selected unit says in a tooltip, entry by entry, with the helpers each entry
calls: the leader's own tooltip, a brigade's summary, the name of a level of equipment, the
historical model's name, a unit's level, the breakdowns of attrition, of speed and of combined
arms, and what each kind of order calls itself. `FINDINGS-unitpanel.md` has the panel itself;
`FINDINGS-tooltips.md` how a tooltip is asked for.

**How it was read.** Every routine was decompiled headless out of a copy of the Ghidra project
with the record applied (`ghidra/DecompileAt.java`), the short literals put back from the image,
and each join of several strings read in the listing where the decompiler drops its operands
(`std::string::operator+` at `0xA5B0D0`). Four were read through in the listing (the header's
bars, its strength list, the leader's heading and skill line, a brigade's combat width); every
other join followed the same order - key, colour or separator, figure, suffix - and is written
here in it.

## 1. How the panel is asked

`CInGameIdler::GetElementTooltip` asks, among its windows, the one at `+0x135C`: the
`CSingleUnitPanel`, when its window is shown and holds the element. `0x762670 / 0x362670` walks
its list box `list` for the entry whose observer slot 22 (`+0x58` of the `+0x1C` table) says the
element is its own, and hands it to that entry's **slot 13** (`out`, element). An element no entry
owns has an empty tooltip. `confirmed` (`0x6C5392`..`0x6C53E6`, the decompilation of `0x762670`)

The windows asked before it are not the panel: `+0x1358` is the reorganise window
(`0x764F40`: `REORG_WND_SHIPS_RATIO_DESC` on its two ratio elements, else the brigade under the
mouse in `left_list` or `right_list` by its summary, section 7); `+0x1360` answers
`theatre_forces_button` with `THEATRE_ASSIGN_TROOPS_DESC` and otherwise its two lists' entries
through `0x736C00`; `+0x1D48` and `+0x1D4C` hand to their entries through `0x6D2160` and
`0x6D14D0`. Those three windows were not identified.

Slot 13 of each entry: `CParentUnitEntry` `0x74DB80`, `CUnitView` `0x76A210`, `CUnitStatusEntry`
`0x75AE20`, `CCurrentOrdersEntry` `0x752950`, `CObjectivesEntry` `0x74FE80`,
`CWindowForSubUnitsEntry` `0x755200`, `CSubUnitEntry` `0x7493B0`, `CWindowForChildUnitsEntry`
`0x756A80`, `CChildUnitEntry` `0x74C2A0`, `CSingleUnitButtons` `0x760600`, `CCombatEntry`
`0x7572E0` (not read here; it is a battle's).

## 2. A unit above (`CParentUnitEntry`)

Anywhere on it: `SELECT_PARENT_UNIT`. `confirmed`

## 3. The header (`CUnitView`)

Its unit at `+0x28`. **First**, where the object at `+0x34` (the leader window's, `0x7681C0`, not
read here) is shown, it is asked, and if it gives a `text` or a `delayed` that is the tooltip.
Otherwise, by the element's name: `confirmed` throughout

| element | what it says |
| --- | --- |
| `unit_activity` | the first of the list below that holds |
| `remove_unit_from_selection_button` | `DESELECT_UNIT`, delayed `DESELECT_UNIT_DRO` |
| `only_unit_from_selection_button` | `OSELECT_UNIT`, delayed `OSELECT_UNIT_DRO` |
| `leader_button` | `UW_LEADER_BUTTON_IRO`, delayed `UW_LEADER_BUTTON_DRO` |
| `leader_types` | **the key `xxx`, text and delayed** |
| `unitname` | `UW_UNITNAMES_IRO`, delayed `UW_UNITNAMES_DRO` |
| `exp_force` | `UW_XP_FORCE_IRO` with `COUNTRY` the name of the expeditionary owner (`+0x28C`), delayed `UW_XP_FORCE_DRO` |
| `counter_type` | a line for each brigade, section 3.2 |
| `counter_size` | the unit's level, section 3.3 |
| `unitstrength` | section 3.4 |
| `unitleader`, `leader_photo` | the leader's tooltip (his slot 9, section 9) |
| `org_bar` | `CURR_COMB_ORG` + `§Y` + the average organisation (slot 20) to 1 place + `§W\n`, then the hourly regain (section 3.5) |
| `str_bar` | `CURR_COMB_STR` + `§Y` + strength over most (slot 23), times 100, 1 place + `%§W\n` |

### 3.1 `unit_activity`

In order, the first that holds, each a text with nothing delayed:

    in a battle (+0x11C):  UV_ATTACKING where CUnit::IsAttackerHere, else UV_UNDER_ATTACK
    retreating (+0x158):   UV_RETREAT
    an attack delay (+0xD4 > 0):  UW_ATTACK_DELAY, HOURS = the delay's hours (0x5BADB0),
                           DATE = now + those hours as a date (0x44C950)
    moving (+0x140 > 0):   ESTIMATE_ARIVAL, DATE = CUnit::NextArrivalHour, PROV = the next province's name
    weakest brigade's strength (+0x5C) under 0.1:   UV_NO_STRENGHT, STR = it, NEED = 0.1, one place each
    weakest brigade's organisation (+0x60) under 1: UV_NO_MORALE, ORG = it, NEED = 1, one place each
    not CUnit::IsFreeToAct:  UV_NOT_MOBILE
    otherwise nothing

The 0.1 is `0x1A8AF28`, set to `floor(100.5)` by a static initialiser (`0xCE13A0`); the 1 is the
constant `1000` at `0x170E9F4`. **The hours of an attack delay** (`0x5BADB0`): `delay / 1000`, and
where the unit's `+0xD8` is above 0 and at most `UNIT_ATTACK_DELAY_PERIOD / 1000`, that times
`+0xD8` over the period; never under 1.

**A date** (`0x44C950`): `" %d:00, %d %s, %d"` - the hour, the day, the month's name and the year -
from the game's hour count less 43,800,000. Note the leading space.

### 3.2 A unit's brigades by their counters

`counter_type`, here and in a row of a unit under it: for each brigade, `£` + its type's key +
` ` + its name + `\n`. `confirmed` (`0x76B690`..`0x76B7AB`)

### 3.3 A unit's level

`counter_size`, here and in a row under it: a unit whose counter size is 0 says
`UNIT_BRIGADE_NAME`, delayed `UNIT_BRIGADE_DESC`; any other says the name and description of its
level (`+0x1F4`): `0x5B8CD0` and `0x5B9190`, a switch from 0 to 6 on `UNIT_THEATHRE`,
`UNIT_ARMYGROUP`, `UNIT_ARMY`, `UNIT_CORP`, `UNIT_DIVISION`, `UNIT_NAVY`, `UNIT_AIR` with `_NAME` and
`_DESC` (the spellings are the game's), and `NONE` past them.

### 3.4 `unitstrength`

By slot 15, `IsLand`:

- **a land unit**: `UW_TOTAL_STR_IRO`, `VALUE` the men of its most strength (slot 23, `FormatMen`),
  then for each brigade a line: `£` + key + ` ` + name + ` - ` + colour + its men (its slot 13) +
  `§W/` + the men of its most (its slot 12) + `\n`, the colour `§R` under half its most, `§Y` under
  its most, `§W` at it;
- **a fleet or an air unit**: for each part under its most - the strength over its most, in
  thousandths, under 1000 - a line `£` + key + ` ` + name + colour + its men + `§W\n`, the colour
  ` §G` from 900, ` §Y` from 660, ` §R` below; and then `UW_FOLLOWING_HURT` followed by the lines, or
  `UW_ALL_FIT` where there are none.

`confirmed` (`0x76B9B8`..`0x76C233`). The 900 and the 660 are `floor(900.5)` and `floor(660.5)`.

### 3.5 The hourly regain (`0x5C6660`)

Nothing for a unit in a battle. Otherwise `+§Y` + the organisation a brigade of it regains an hour,
to three places: the regain rate the unit's supply, its officers, the country's `ORG_REGAIN`
modifier and its province give, as the hourly pass computes it. `confirmed` for the shape; that it
is the hourly pass's own figure is read off the terms it multiplies, not compared.

## 4. A unit under it (`CChildUnitEntry`)

`counter_type` and `counter_size` as the header's; `order` the order's description (section 10);
`objective` the unit's objectives (section 8); `org_bar` and `str_bar` as the header's. Anything
else: nothing. The window around the rows (`CWindowForChildUnitsEntry`) hands every element to the
row that owns it. `confirmed`

## 5. The status (`CUnitStatusEntry`)

Its unit at `+0x78`. `confirmed`

| element | what it says |
| --- | --- |
| `unitattrition` | the attrition breakdown (section 11), only for a unit with brigades |
| `unitlocation` | `UW_LOC_IRO`; and where `delayed_extra` is empty and `unit_location_button` has a shortcut, `SHORTCUT` and the shortcut into `delayed_extra` |
| `unitbase` | a fleet or an air unit: `UW_BASED_FROM`, and `UW_BASE_AIR_SUPPLY_INFO` or `UW_BASE_NAVAL_SUPPLY_INFO` (`0x76FF40`: `NAME` the base, `VAL` how well it supplies, `PLANES` or `SHIPS` its room, `DAILY`) into `delayed`; a land unit: `UW_SUPPLIES_FROM`, and the text of the element `unitbase` into `delayed` |
| `unit_weight` | `TRANSPORT_WEIGHT` |
| `unit_cw_strip` | `UNIT_COMBAT_WIDTH` + `: §Y` + the unit's width to 1 place + `§W\n` |
| `unitstatus_delay` | `UW_STRATDEPLOYMENT_DELAY` for a unit on strategic redeployment (order type `0x5A4`), else `UW_ATTACK_DELAY`; `HOURS` and `DATE` as section 3.1 |
| `unitstatus_nuke` | `UW_CARRYING_NUKE` |
| `unitstatus_dugin` | `UW_DUGIN`, `CURR` the unit's digging in (`+0x1C8`, 0 places), `CAP` `UNIT_DIGIN_CAP` + what its country's technology adds (`+0x14`), 0 places |
| `unitstatus_combinedarms` | the combined arms breakdown (section 12) |
| `supply_status` | `UW_SUPPLY_STATUS2`: `FROM` the depot's name, `DAYS` the supplies there over what its units use a day, whole, `VAL` the supplies the unit received (`+0xFC`) times 100, `CON` what it uses a day (`CUnit::SupplyConsumption`) to 2 places |
| `fuel_status` | `UW_SUPPLY_FUEL2`, the same for fuel (`+0x100`, `CUnit::FuelConsumption`) |
| `unitstatus_moving` | while moving and in no battle, `ESTIMATE_ARIVAL` as section 3.1 |
| `speed` | `UW_SPEED` + `\n`; where the speed multiplier is not 1, ` / ` + the speed it gives + `KPH`; then for each brigade `\n` + `£` + key + ` ` + name + ` - ` + its type's speed + ` ` + `KPH`; then `\n` and the speed breakdown (section 11) |
| `unitstatus_distance` | where a unit above is out of radio range, `UW_DIS_OUT_OF_RANGE` + `\n`; for a headquarters, `UW_EFFECTIVE_RADIO_STRENGTH` with `HQ` its level's name and `DISTANCE` its first brigade's radio times the define of its level (`RADIO_*_LEADER_DISTANCE`), over 1000, + `\n`; then for each headquarters above, `UW_DIST_TO` + `\n` with `LOCATION` the headquarters' province, `HQ` its level's name, `NAME` its name, `LOWER` the name of the unit below it in the chain - not the selected unit - and `DISTANCE` a colour and the distance between their provinces: `§R` where the reach (`CUnit::CommandReachFrom`) is under 0, `§Y` under 1000, `§G` at it. **A reach is never under 0** - beyond twice the radius it is 0 - so a link out of reach is yellow and nothing is ever red. Each text comes before its `\n`, read in the listing at `0x75C4B0`, `0x75C6B6` and `0x75C953` (`operator+` at `0xA5B0D0` with the text on the left) |

## 6. The order (`CCurrentOrdersEntry`)

`cancel_order_button`: `CANCEL_CURRENT_ORDER` where the unit has no order, or its order's slot 24
says no, or its slot 12 says yes; `non_cancellable_order_desc` otherwise. Anywhere else: the
order's description (section 10). `confirmed`

## 7. The brigades (`CWindowForSubUnitsEntry`, `CSubUnitEntry`)

The window: `positioning`, on a fleet (slot 16), says `POS_STACK_PENALTY` with `MAX`
`NAVAL_STACK_POS_HULL_LIMIT` (0 places), `EACH` `NAVAL_STACK_POS_PENALTY_HULL_MULT` times 100 (0
places), and `TOTAL` `(hull - limit) * mult / 1000`, kept between 0 and
`NAVAL_STACK_POS_PENALTY_MAX`, times 100, one place. Any other element goes to the brigade row
that owns it. `confirmed` - the decompiler shows the text built into a local and dropped; the
listing copies it out (`0x755646`).

**A brigade's row** (`CSubUnitEntry::BuildTooltip`):

| element | what it says |
| --- | --- |
| `unit_cw_strip` | `UNIT_COMBAT_WIDTH` + `: §Y` + its type's width (`+0xE8`) to 1 place + `§W\n` |
| `upgrade_button` | `UNIT_CAN_UPGRADE_TO`, then `\n` and the name of each type it may be upgraded to (the unit database's list for its type) that the **played** country may still build one of |
| `unitstatus_reserve` | `UW_RESERVE_INFO`, `VAL` minus the country's `RESERVES_PENALTY_SIZE` times 100; or `UW_MOBILIZED_RESERVE_INFO` where the country has mobilised |
| anything else | the brigade's summary (`0x5A9900`, below) |

A row that stands for an upgrade being built says `BRIGADE_UPGRADE_MIL_CON_INFO` with `FROM` and
`TO`, delayed `BRIGADE_UPGRADE_INHERITED_EXP` with `EXP` (2 places) where above 0.

**Slot 4 is not a tooltip.** It is the row's click: it makes a 0xBC-byte window,
`BuildUnitStatsTooltip`'s object, and shows it (`0x644670`). So `CSubUnitEntry::BuildStatsTooltip`
is the click that opens a brigade's statistics window, and `BuildUnitStatsTooltip` that window's
constructor - the record had both as tooltips.

**A brigade's summary** (`0x5A9900`), used by its row and by the reorganise window:

    "(§Y" + the historical model's name (section 13) + "+*" where the model is not the one
          the country builds today + "§W)\n"
    PRIDE_OF_FLEET + "\n", for a pride of the fleet (+0xA5)
    SUBTT_STRENGTH + ": §Y" + its slot 13 + "§W/" + then, where its slot 9 says yes, the men of
          its most (slot 12, FormatMen) + "\n"; where it says no, its most over 1000 as a whole
          number + "%\n"
    SUBTT_ORG + ": §Y" + organisation + "§W/" + most organisation + "§W\n", both with only
          the decimals they need
    SUBTT_EXP + ": §Y" + experience with pride, 3 places + "§W%\n"
    for a ship or a wing (slot 10): MAXIMUM_SPEED in KPH and RANGE in KM, as stat lines (0x5A51D0)
    then its equipment (0x5AACF0)

The order of the pieces in these lines is the decompilation's order of making them, which every
join read in the listing has followed; these three were not themselves read there.

**A stat line** (`0x5A51D0`): the label, then ` §Y` where asked, else ` §R` for a value not above 0
and ` §G` above, `+` where asked and above 0, the value to the places asked, `§W `, the unit, ` \n`;
nothing for a value of 0. The summary's two (`0x5AAA0D`..`0x5AAC90`, read in the listing): the
ship's or wing's type's maximum speed (`+0x108`) to 2 places with `KPH`, and its range (`+0x148`)
to 0 places with `KM`, neither with a `+`; the flag that asks for ` §Y` is the `push 1` left on the
stack before the unit's text is built, so both are yellow - `inferred` from where it lies, since
nothing else in the call fits that slot.

**Equipment's list** (`+0x84` of the brigade) holds nodes of the technology, the level and a third
figure, the one written `§W(+` ... `%)` - times 100000 over 1000, so a fraction in thousandths shown
as a percentage. That it is the brigade's progress towards the technology's next level is
`likely`: it is the third figure a sub unit's save writes beside each technology, which the
upgrade adds to.

**Equipment** (`0x5AACF0`): for each technology on the brigade's list - the technology's name +
` : §Y` + the level's name (section 13), or `YES` / `NO` where the technology has no models
(`+0x2C0` 0) - then `§W(+` + its bonus times 100, 2 places, `%)` where it has one, and `§W\n`. A
government in exile names a level by its faction leader's list where the level is above its own.

## 8. A headquarters' row (`CObjectivesEntry`)

| element | what it says |
| --- | --- |
| `objectives` | the objectives (`0x5B59F0`: the province names of `+0x234`, `, ` between, where `+0x204` is set), delayed `OBJECTIVES_DESC` |
| `aggression_checkbox` | `AGGRESSION_OFF`, or `AGGRESSION_ON` where the unit's aggression is its own (`+0x4A`) |
| `tac_aggro_slider_bg`, `tac_aggro_bg`, `aggro_TrackButton`, `aggro_SliderButton` | `AGGRESSION_LEVEL` with `STATUS` `AGGRESSION_AGGRESSIVE` above 0.3, `AGGRESSION_NEUTRAL` from -0.3, `AGGRESSION_DEFENSIVE` below |
| `automate_checkbox` | `AUTOMATED` where it or a unit above has an AI agent (`+0x198`); else by level: a division `CANT_AUTO_DIVISIONS`, a theatre with no area `CANT_AUTO_NO_AREA`, a fleet or air unit `ONLY_AUTO_ARMIES`, any other `PLAYER_CONTROLLED`; delayed `AUTOMATED_DESC` |
| `reorg_hq_checkbox` | `ALLOW_HQ_REORG` |

`confirmed`; the thresholds are the floats at `0x15C05EC` (0.3) and `0x174C568` (-0.3).

## 9. The buttons (`CSingleUnitButtons`)

| element | what it says |
| --- | --- |
| `attach_button` | `UW_NOT_POSSIBLE_TO_ATTACH` where the button is switched off, else `UW_ATTACH` |
| `detach_button` | `UW_DETACH` |
| `oob_button` | `UW_OPEN_OOB_BROWSER` |
| `disbandbutton` | `DISBAND_UNIT`, delayed `DISBAND_UNIT_DRO` |
| `newunitbutton` | `NEW_UNIT`, delayed `NEW_UNIT_DRO` + `\n\n` + `SPLIT_UNITS_DESC` with `NUM` the brigades |
| `prio_checkbox`, `reinf_checkbox`, `upgrade_checkbox` | `UW_TURN_OFF_PRIO` where it is on (`+0xA4`), else `UW_TURN_ON_PRIO`; `_REINF` (`+0xA6`); `_UPGRADE` (`+0xA5`) |
| `create_corps`, `create_army`, `create_armygroup`, `create_theatre` | `UW_CREATE_CORPS`, `UW_CREATE_ARMY`, `UW_CREATE_ARMYGROUP`, `UW_CREATE_THEATHRE`; delayed `UW_CREATE_ABOVE_DRO`, with a line of the custom game's cost in custom game mode |
| `edit_theatre` | `UW_EDIT_THEATRE`, delayed `UW_EDIT_THEATRE_DRO` |
| `unload_button` | `UW_UNLOAD_VALID` where it may land, else `UW_UNLOAD_NOT_VALID` |
| `load_button` | `UW_LOAD_IS_VALID` where a fleet to board is found, else `UW_LOAD_NO_FLEET_FOUND` |
| `unload_plane_button` | `UW_UNLOAD_PLANE_BASE_OK` at its own base, else `UW_UNLOAD_PLANE_BASE_ONLY` |
| `load_plane_button` | `UW_LOAD_PLANE` where it may, else `UW_LOAD_PLANE_FAIL_LOW_ORG` where a brigade is under `PARATROOP_MISSION_ORG_REQ`, else `UW_LOAD_PLANE_FAIL` |

`confirmed`

## 10. What an order calls itself

`COrder` slot 7, `GetDescription` (`0x586F40`), is shared by every order class but one:
`OrderMissionIndexToDescription(OrderTypeToMissionIndex(its type))`. **The idle order
(`CNullOrder`) overrides it with an empty string** (`GetEmptyName`), so an idle unit's order line
says nothing. `confirmed`. The two tables, now read whole:

| order (save token) | index | description |
| --- | --- | --- |
| `none` | 0 | `NO_ORDERS` |
| `support_attack` | 1 | `SUPPORT_ATTACK_DESC` |
| `strategic_redeployment` | 2 | `ORDER_STRATEGIC_REDEPLOYMENT_DESC` |
| `move_order` | 3 | `MOVE_ORDER_DESC` |
| `rebase` | 4 | `ORDER_REBASE_DESC` |
| `reserves` | 5 | `ORDER_RESERVE_DESC` |
| `patrol` | 6 | `ORDER_PATROL_DESC` |
| `intercept` | 7 | `ORDER_INTERCEPT_DESC` |
| `sortie` | 8 | `ORDER_SORTIE_DESC` |
| `convoy_escort` | 9 | `ORDER_CONVOY_ESCORT_DESC` |
| `convoy_raid` | 10 | `ORDER_CONVOY_RAID_DESC` |
| `air_convoy_raid` | 11 | `AIR_CONVOY_DESC` |
| `transport` | 12 | `ORDER_TRANSPORT_DESC` |
| `invasion` | 13 | `ORDER_INVADE_DESC` |
| `strategic_bomb` | 14 | `STRAT_BOMB_DESC` |
| `logistical_strike` | 15 | `LOG_BOMB_DESC` |
| `runway_cratering` | 16 | `AIRFIELD_BOMB_DESC` |
| `installation_strike` | 17 | `INSTALLATION_BOMB_DESC` |
| `ground_attack` | 18 | `GROUNDATTACK_BOMB_DESC` |
| `interdiction` | 19 | `INTERDICT_BOMB_DESC` |
| `air_intercept` | 20 | `INTERCEPT_DESC` |
| `carrier_protection` | 21 | `CAG_DUTY_DESC` |
| `paradrop_mission` | 22 | `PARADROP_MISSION_DESC` |
| `port_strike` | 23 | `PORTSTRIKE_BOMB_DESC` |
| `naval_strike` | 24 | `NAVALSTRIKE_BOMB_DESC` |
| `rebase_to_carrier` | 25 | `REBASE_TO_CAG_MISSION_DESC` |
| `nuke_mission` | 26 | `NUKE_MISSION_DESC` |
| `transport_supplies_mission` | 27 | `TRANS_SUP_MISSION_DESC` |
| `rebase_air` | 28 | `ORDER_AIR_REBASE_DESC` |
| `air_reserve` | 29 | `ORDER_AIR_RESERVE_DESC` |
| `air_superiority` | 30 | `AIRSUP_DESC` |
| `join_fleet` | 31 | `ORDER_JOIN_FLEET_DESC` |
| `join_air` | 32 | `ORDER_JOIN_AIR_DESC` |

## 11. The breakdowns of attrition and of speed

**Attrition** (`BuildAttritionTooltip`, `0x4A0BA0`; the province, the out string, the unit): nothing
for a unit whose slot 9 says no. Otherwise, in a friend's province not at the front
`IN_FRIENDLY_FOR_ATT` alone; at the front `IN_FRONT_PROV_ONLY_10` and a base of 0.1; in an enemy's
`IN_HOSTILE_FOR_ATT` and a base of 1; then the province's own line (its `+0xFC` object's slot 9);
`ATTR_INFRA` + `: §R` + `(1000 - infrastructure share) * base`, `+` above 0, 2 places, `§!\n`, the
share being the province's infrastructure over its most, between `0x1BEA400` and 1;
`ATTR_WEATHER` with `: §R+` where the weather's attrition (with the unit's leader's effect 6 in the
cold) times the base is above 0; the terrain's adjuster's attrition for the unit's type and the
province's own, times the base, by the terrain's name with `: §R+`; `ATTR_TECH` with `: ` and the
country's technology's attrition (`+0x88`), `§G` below 0 and `§R+` above, times 100, 2 places,
`%§!\n`; and last `\n§Y` + `TERRAIN_ATTRITION` + `§!` and the province's attrition, `§R+` above 0,
2 places, `%§!`. `confirmed` for the shape; the base's arithmetic was not followed into every term.

**Speed** (`BuildSpeedModifierTooltip`, `0x5C82A0`; the unit, the out string): `SPEED_MODIFIER` with
`PERC` the whole multiplier (`CUnit::MovementSpeedModifier`), as a percentage (`0xAB6FC0`); nothing
more where it is 1. Then, for each term that is not 1, `\n- ` and its line with `PERC`:
`SPEED_MODIFIER_COMBAT`, `_FUEL`, `_TERRAIN`, `_TRAIT`, `_ADJACIENCY`, `_WEATHER`, `_LOCAL_MOD`,
`_MOTORIZED_BONUS`, `_RETREATING`, each the term `MovementSpeedModifier` multiplies in, worked out
again here the same way. `confirmed`. **A multiplier as a percentage** (`0xAB6FC0`): times 100 to 2
places with `%§!`, `§G` above 1 and `§R` below; exactly 1 is `§Y100.00%§!`.

## 12. Combined arms (`CUnit::GetCombinedArmsBonus`)

Given a third argument, it writes there the breakdown where the bonus is not 0:
`CA_BONUS_DETAILS_TOTAL` with `VAL` the bonus times 100, 2 places; `\n` + `CA_BONUS_DETAILS_BASE`
the unit's own; `\n` + `CA_BONUS_DETAILS_TECH` the technology's where above 0; `\n` +
`CA_BONUS_DETAILS_TRAIT` the leader's where above 0. `confirmed`

## 13. Names: a leader, a level of equipment, a historical model

**The leader's tooltip** (`CLeader::BuildTooltip`, slot 9), all in `text`:

    the rank's name (0x5817B0: LAND_RANKn, SEA_RANKn or AIR_RANKn by his kind +0x68 and rank
          +0x6C, INACTIVE for none) + " §Y" + his name + "§W\n"
    for a leader of a fleet or an air unit: LEADER_COMMAND_SIZE + " §G" where his rank fits the
          unit (CUnit::LeaderHasRankForCommand), else " §R"; + " " + the size (0x5800A0: the
          NAVAL_RANK_n or AIR_RANK_n define for his rank, over 1000) + " " + SHIPS_LABEL or
          PLANES_LABEL + "§W\n"
    an admiral (kind 1): LEADER_POSITIONING + " §Y" + skill x 100 thousandths, times 100,
          0 places + "%§W\n"
    LEADER_SKILL + " §Y" + skill, and " (" + LEADER_SKILL_AT_MAX + ")" where at his most, + "§W\n"
    LEADER_XP + " §Y" + experience as a percentage (CLeader::GetExperiencePercent, times 100),
          2 places + "%§W\n"
    where he has traits: "\n" + ACTUAL_TRAITS_DESC + then "\n- §Y" + each trait's name + "§!"
    where he is on his way to one: "\n" + TO_GAIN_TRAITS_DESC + "\n" + the progress lines
          (CTraitGainTracker::BuildProgressTooltip)

`confirmed`. **The experience as a percentage** (`0x581C50`, read in the listing): 0 from skill 12;
otherwise, with `T` the thresholds at `0x170AEE0` (0, 1000, 2000, 4000, 8000, 12000, 18000, 25000,
33000, 43000, 60000, 100000000, and then a 1 that belongs to nothing), `((experience - (T[skill] << 15))
<< 15) / ((T[skill + 1] << 15) - (T[skill] << 15))`, a signed 64-bit division, times `1000 << 15` and
shifted right 30: thousandths of the way to the next skill. At skill 11 the next threshold is that
stray 1, so the share is at most nothing. **The rank's name** (`0x5817B0`) indexes one of three five-entry tables by the rank
itself - `0x170AF28` for a general (kind 0), `0x170AF14` for an admiral (kind 1), `0x170AF3C` for
an air marshal - each `INACTIVE` at 0 and `LAND_RANK1`..`4`, `SEA_RANK1`..`4` or `AIR_RANK1`..`4`
after it; nothing bounds the rank. **The progress lines** (`0x474240`, read in the listing
`0x4742A4`..`0x474341`): for each trait in the tracker's map whose progress is above 0 and under
100000, `\n` before every line but the first, then `- ` (`0x15B57EC`) + `TRAIT_GAIN_PROGRESS` with
`PROG` the progress over 1000 to 2 places and `TRAIT` the trait's slot 6 name. The map is keyed by
the trait's pointer, so the lines come in the order the traits lie in memory; the joins above
(`0x581634`..`0x5816ED`) put `\n` + `TO_GAIN_TRAITS_DESC` + `\n` in front of them. `confirmed`

**A level of equipment** (`0x5010E0`, the country, the technology, the level): `NO` for level 0
of a technology with models (`+0x258`). Otherwise the text of `TAG_technology_level` (the country's
tag at `+0xCA4`, the technology's key at `+0x20C`) where there is one; else of `technology_level`;
else level 0 `NO` or `Default` (by `+0x2C0`), and any other `MODEL_TAG` + ` ` + its model number:
`+0x2B4` for level 1, `(level - 2) * +0x2C0 + +0x2B8` from 2. `confirmed`. Those three are the
technology's `start_year`, `first_offset` and `additional_offset`, so the number is a **year**:
Their Finest Hour's infantry technologies give 1918, 1934, 1936 and on by two - the files' own
comment, "2nd model is from 1934", says as much. A technology with `additional_offset = 0` has no
models and says `YES` or `NO`.

**A historical model's name** (`0x581F70`): the text of `TAG_type_n` - the model's tag, its type's
key and its number (`+0x24`) - where there is one; for a faction member, the faction leader's
`LEADER_type_n` where that is; else the type's `type_n`; and where none has a text, the type's
name + ` (` + the number plus 1 in Roman numerals + `)`. `inferred` past the first two - the tail of
the routine was read in the decompilation only. `0x582FA0` finds, among a set's models, the one
whose technology levels equal the brigade's; the summary marks a model with `+*` where
`PickBestModel` answers another.

## Kept as read, though they look odd

1. `leader_types` says the key `xxx`, text and second half alike.
2. A date is written with a space in front of it.
3. A fleet's and an air unit's strength list says nothing of a ship at full strength, and a land
   unit's says something of every brigade.
4. The idle order's line has no tooltip at all.
5. `UV_NO_STRENGHT` is the game's spelling, `UW_CREATE_THEATHRE` and `UNIT_THEATHRE_NAME` too.
6. The distance to a headquarters out of reach is yellow, as one within part of its reach is: the
   red asks for a reach under nothing.
7. An air unit's `counter_size` says `UNIT_BRIGADE_NAME`, its counter's size being 0.

## Not established

- The three windows at `+0x1360`, `+0x1D48` and `+0x1D4C`.
- The leader window's part of the header (`0x7681C0`).
- The battle row (`CCombatEntry::BuildTooltip`), left to a battle's tooltips.
- The base's arithmetic in the attrition breakdown, term by term.
- Which class `BuildUnitStatsTooltip` constructs: its vftables `0x15D626C` and `0x15D6280` belong to
  no class with RTTI.

## In the record

Entered in `ghidra/project.json` by `fragments/merged/unitpanel-tooltips.json`: thirty functions
new - the nine entries' slot 13s, the panel's and the reorganise window's dispatchers, three
unidentified windows' and the helpers of sections 3 to 13 - and nine revised:
`CSubUnitEntry::BuildTooltip` read whole, `CSubUnitEntry::BuildStatsTooltip` renamed
`CSubUnitEntry::OnClicked`, `BuildUnitStatsTooltip` renamed `UnitStatsWindow_Construct`,
`BuildAttritionTooltip` and `BuildSpeedModifierTooltip` with their arguments,
`OrderTypeToMissionIndex` and `OrderMissionIndexToDescription` tabulated, and
`CUnit::GetCombinedArmsBonus` and `CLeader::BuildTooltip` read through; slot 13 recorded for ten
classes, slot 4 for `CSubUnitEntry`, slot 9 for `CLeader` and `CNullLeader`. `CLeader::CommandSize`
was already in the record and agreed. Then `fragments/merged/unitpanel-tooltips-receiver.json`
typed one receiver.
