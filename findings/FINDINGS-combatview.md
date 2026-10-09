# The battle on screen: the combat window, its entry in the unit panel, the marker, and tactics

*Read on 2026-10-09 for the rewrite's third piece of land combat, after the maintainer gave three
screenshots of a battle of his own - the marker on the map, the unit panel with its battle row,
and the window. Static only: nothing here was watched in a running game. Addresses are virtual
(image base `0x400000`); the record holds them as rvas.*

`FINDINGS-landbattle.md` is what a battle *does*. This is what the original *shows* of one, and
the one rule of the fight that the window makes impossible to leave out: the tactics.

## In one paragraph

A battle is a selectable thing. Selecting it - by its row in a unit's panel, among other ways -
asks the in-game screen to show a **`CCombatView`** for it, which makes the window `combat` out of
`interface/combat.gui`, hangs a side window on each half, and is then refreshed **every frame**:
a bar and a number for the attacker's share of the two sides' strength, the battle's width, an
arrow that says whose tactic counters whose, an icon for every modifier in play on either side,
and for each side its flag, its leader, its tactic and two lists of units, those on the front and
those in reserve. The same share picks the colour of the round marker on the map and is the number
written on it. A land battle's two tactics are picked when it starts and again every
`TACTIC_SWAP_FREQUENCEY` hours, by weight, out of `common/combat_tactics.txt`.

## 1. How the window comes up and goes away

`CCombat` has a second table at `+8`, a `CSelectable`. Its slots:

| slot | function | what it does |
| --- | --- | --- |
| 4 | `CCombat::OnSelected` (`0x56E420`) | `inGameScreen->ShowCombatView(this)` |
| 5 | `CCombat::OnDeselected` (`0x56E4E0`) | if the view on screen is this battle's, `ShowCombatView(null)` |
| 6 | `CCombat::OrderUnits` (`0x56E5C0`) | a right click with a battle selected: passes the two arguments on to slot 6 of every unit **of the player's** on the side the player has a country in - the defender's side is looked at first |
| 7 | `CCombat::GetName` (`0x57AB80`) | section 8 |

**`CInGameIdler::ShowCombatView`** (`0x664E90`, slot 58 of the screen) does nothing when the view
it holds (`CInGameIdler +0x1364`) is already of that battle. Otherwise it hides and frees the old
view, and for a battle that is not null allocates `0xA50` bytes, constructs a `CCombatView`
(section 2), shows its window, and **hides the window of the object at `+0x1CC0`** - which was not
identified; by what is on screen when a battle opens it is the panel of the selected unit - before
it sees to the message log and the chat window. `CInGameIdler::GetCombatView` (`0x674EE0`, slot
59) returns `+0x1364`.

The screen's own frame routine (the function at `0x650700`) calls **`CCombatView::Update`**
(`0x72F820`) on that view at `0x650952`, every frame, and when it answers false calls
`ShowCombatView(null)`. So a window closes itself; section 3 says when.

## 2. The constructor

`CCombatView::CCombatView` (`0x72E710`; the screen in ECX, then the memory and the battle). The
class has no table of its own - its two `CButtonObserverGlue<CCombatView>` members at `+0x10` and
`+0x3C` are what the RTTI export knows it by.

1. `+0x00` the window, made from the type **`combat`**; `+0x04` the battle; `+0x70` the screen.
2. By the battle's kind (`CCombat` slot 11: 1 land, 2 naval, 3 air; any other, where slot 8 says it
   is a bombing, takes the air's):

   | kind | side windows | added as |
   | --- | --- | --- |
   | land | `combat_side_l`, `combat_side_r` | children `attacker`, `defender` |
   | naval | `naval_l_combat_side`, `naval_r_combat_side` | the same two names |
   | air, bombing | `air_combat_side` twice | the same two names |

   **The names `attacker` and `defender` are given by the code**, not by the file: every later
   lookup goes through the window's child of that name.
3. **A land battle's picture** (`combat_terrain`): the file
   `gfx/interface/prov_pictures/provimg_` + the province's id + `.dds` where there is one - a
   sprite made in the shape of `GFX_terrainimg_plains` with that file for its texture - and
   otherwise the sprite `GFX_terrainimg_` + the name of the battle's terrain (`CCombat +0x24`,
   its slot 7).
4. The window's group is `combat_view`. `closebutton` is given the first observer (its handler is
   the five bytes at `0x734710`, which were not read) and `retreat_button` the second
   (`CCombatView::OnRetreatClicked`, section 7).
5. `CCombatView::UpdateSides(true)` (section 4).
6. Of `combat_bg`, `combat_naval_bg` and `combat_air_bg` the one for the kind is shown and the
   other two hidden; `combat_terrain` is shown for a land battle and hidden for any other.
7. `label_battlename` is the battle's name (section 8), set once.
8. A generator of the view's own (`+0x88`) is seeded from the clock. Only the sounds use it.

## 3. Every frame: `CCombatView::Update`

In this order:

1. **`combat_progress`**: `share * 100000 / 1000 / 1000`, a whole number from 0 to 100, handed to
   the icon's slot 18 (`+0x48`) - which for a progress bar is how full it is. `share` is
   `CCombat::GetAttackerStrengthShare` (section 10), so **the bar is the attacker's share**, and
   its first texture (`progress_bar_combat_a`) is the attacker's part.
2. **`combat_width`**: `CCombat::GetCombatWidth` over 1000, as a whole number.
3. **`combat_attack_indicator`**, land only (hidden for any other kind) - a frame by whose tactic
   counters whose (section 11 has what countering is):

   | frame | when | tooltip |
   | --- | --- | --- |
   | 2 | the attacker's tactic counters the defender's | `DEFENDER_COUNTERED` |
   | 3 | the defender's counters the attacker's | `ATTACKER_COUNTERED` |
   | 1 | neither, or a side has no tactic | `NONE_COUNTERED` |

   The first test wins where both hold. The two tests are also functions of their own,
   `CCombat::IsDefenderCountered` (`0x57CFD0`) and `CCombat::IsAttackerCountered` (`0x57CFA0`),
   the battle in EAX, which the tooltip uses.
4. **The modifiers are worked out again, for the window**: `attacker->ApplyCombatModifiers(defender,
   1)` and then `defender->ApplyCombatModifiers(attacker, 1)` (`CCombatant` slot 19). The third
   argument is 1 here and 0 from the battle's own hour.
5. **`retreat_button`** is enabled (the button's slot 46) where `CCombat` slot 12 says yes and
   disabled (slot 47) where it does not. Slot 12 is the shared "true" for a land battle.
6. **`combat_modifiers`**, a box of overlapping elements. The 30 bytes of `modifier_used`
   (`CCombatant +0x08`) are counted, one for each id set **on either side**; where that is not the
   number of entries the box holds, the box is emptied and filled again: for each id from 0 to 29
   set on either side, a window `combat_modifier` whose icon `combat_mod_icon` takes the sprite
   **`CMOD_` + the modifier's key** (`CombatModifierKey`, the `BM_...` names) where a sprite of
   that name exists, and whose entry is given the id as its name. So the icons stand in the order
   of the ids, and one icon serves both sides.
7. **Whether the window stays.** It hides itself and answers false -
   - a land battle: where either side has no units (`CCombatant +0x48`), or both lists of the
     attacker's side window are empty, or both of the defender's;
   - a naval battle: where either side has no units;
   - an air battle or a bombing: where a `planes` list is empty.
8. Otherwise: `UpdateSides(false)`; the child `attacker` is put at the place of the icon
   `left_pos` and `defender` at `right_pos`; and unless the byte at `+0x68` is set, when the
   sound it last started (`+0x84`) is over it starts another: `land_combat_` 1 to 6,
   `air_combat_` 1 or 2, `naval_combat_` 1 to 3, or `bomb_` 1 to 3, by a draw of the view's own
   generator.

## 4. A side

`CCombatView::UpdateSides` (`0x732340`, the view in ESI, one bool) calls
**`CCombatView::UpdateSide`** (`0x7325E0`: the view, the `CCombatant`, whether it is the attacker,
its side window) for the attacker and then the defender. For a land battle:

- **`committed_label`**: the text `COMMITED_LABEL` with `$COUNT$` the number of units on the front
  (`CCombatant +0xB8`) and `$WIDTH$` `SumUnitListCombatWidth` (`0x5D6460`) of the front over
  1000 - each unit's `CUnit::GetCombatWidth`, summed.
- **`reserves_label`**: `RESERVES_LABEL` with `$COUNT$` the number in reserve (`+0xC8`).
- **The lists `committed` and `reserves`**, each by `CCombatView::FillUnitList` (`0x732440`): where
  the list has as many entries as the side's list has units and every entry's unit is still in it,
  each entry is only refreshed (its slot 8); otherwise the list is emptied and a `CUnitOption`
  (section 5) made for each unit **in the order of the side's own list**.

Then, for every kind of battle:

- **The leader** is `CCombatant::GetHighestRankedLeader`. Where that is a real leader (its slot 8)
  with a unit: `leader_name` is his name and `leader_photo` a sprite in the shape of
  `GFX_empty_position` with the file `gfx/pictures/portraits/` + his picture + `.tga` - both set
  only when the leader is another than the one the view remembers for that side (`+0x74` the
  attacker's, `+0x78` the defender's). Where there is none and the side has a country,
  `leader_name` is the text **`NO_COMMANDER`**.
- **`shield`** is given a country (the icon's slot 53, `+0xD4`): the leader's unit's owner; with no
  leader the first of the side's countries (`+0x54`); with no country either, the controller of
  the battle's province (`CMapProvince +0x334`).
- A side with no tactic (`+0xAC` null) is done here.
- **`initiative_indicator`** is shown on the attacker's side where the attacker's leader has more
  skill than the defender's, and on the defender's where the defender's has more; hidden where they
  are equal. No leader counts as 0.
- **The tactic**, when it is another than the one remembered (`+0x7C`, `+0x80`): `tactic_name` is
  its name as the localisation gives it (slot 6), and `tactic_picture` a sprite in the shape of
  `GFX_empty_tactics` with the file `gfx/pictures/tactics/` + the tactic's `picture` + `.dds`,
  **where that file exists**; without it the picture is left as it was.

For a naval battle the side has one list, `ships`, a label `SHIPS_LABEL` and a `positioning`
figure; for an air battle one list, `planes`, and `PLANES_LABEL`. Neither was read further.

## 5. A unit in a list: `CUnitOption`

`CUnitOption::CUnitOption` (`0x729570`), `0x58` bytes, a list entry made from the window
**`division_option`**; it keeps a reference to the unit (`+0x28`), the view (`+0x50`) and whether
its side is the attacker (`+0x54`).

| element | what it is given |
| --- | --- |
| `counter_type` | the sprite `GFX_counter_` + the type of the unit's first brigade, for a unit at division level or below (`oob_level >= 3`) that has one; any other takes the default the image keeps at `0x170D858`. Set only where a sprite of that name exists |
| `unit_cw_strip` | a frame by the unit's width (its summed definition's `+0xE8`): 1 under 2, 2 under 4, 3 under 6, 4 under 8, 5 from 8 |
| `combat_unit_bg` | a progress bar: 100, full |
| `name` | the unit's name |

and then its **`CUnitOption::Update`** (`0x7299B0`, slot 8), which is also what a refresh calls:

| element | what it is given |
| --- | --- |
| `str_bar` | the brigades' strengths added up, over the unit's full strength (slot 24), as a whole number of hundredths |
| `org_bar` | the unit's average organisation (slot 20) over its summed definition's `max_organisation`, the same |
| `location` | the name of the province the unit is in |
| `combat_unit_bg` | for a unit landing from the sea only: how far the landing has got. For every other it stays full |

The entry's group is `army_option`. Its own button handler (the eight bytes at `0x734720`) was not
read.

## 6. Tooltips

`CCombatView::BuildTooltip` (`0x731120`: the view, the tooltip to fill, the element under the
mouse) is a router and was read only as far as the routes:

| under the mouse | what is written |
| --- | --- |
| `combat_terrain` | the terrain's own description |
| `combat_width` | the text `COMBAT_WIDTH` |
| `retreat_button` | `COMBAT_RETREAT` |
| `positioning` | `FLEET_POSITIONING` |
| an entry of `committed` or of the defender's `reserves` | `CCombatView::BuildUnitTooltip`, which the record already has |
| an entry of the attacker's `reserves` | the function at `0x72BD70`, not read |
| `tactic_name` or `tactic_picture` of a side | the tactic's own text (`CCombatTactic::BuildTooltip`, section 11) |
| `combat_attack_indicator` | one of the three texts of section 3 |
| `leader_name` or `leader_photo` of a side | the leader's own tooltip, with `LEADER_INITIATIVE` added where he has more skill than the other side's |

## 7. The retreat button

`CCombatView::OnRetreatClicked` (`0x732190`, the view in ECX): for every unit of the attacker's
side and then of the defender's whose owner is the player, a `CMoveCommand` made with
`(-1, 1, 0, 0)` is handed to the session. So **the button orders every unit of the player's in the
battle to stop**, whichever side it is on; what a move command of those arguments does to a unit
in a battle is `FINDINGS-landbattle.md`, section 7.

## 8. The battle's name, and its row in a unit's panel

**`CCombat::GetName`**: the text `BATTLE_OF`, a space, and the name of the battle's province; for
a bombing `BOMBING_OF` in its place. Nothing else goes into it.

**`CCombatEntry`** is the row a unit's panel adds for each battle the unit is in
(`FINDINGS-unitpanel.md`, row 11 of its table), made from the window **`combat_entry`** of
`interface/single_unitpanel.gui` by the constructor at `0x756B90`, which keeps the battle
(`+0x28`) and the unit (`+0x2C`).

`CCombatEntry::Update` (`0x756D60`, slot 9 of its second table) does nothing unless the battle is
still one of the unit's (`CUnit +0x114`, or `+0x110`) and `CCombat::IsLive` (`0x56E700`, slot 9)
says so - both sides with a country and a unit, and every country of each an enemy of the other
side. Then:

| element | what it is given |
| --- | --- |
| `desc` | the battle's name |
| `progress` | the attacker's share as a whole number from 0 to 100, exactly as the window's bar |
| `attacker_flag` | the first of the attacker's countries; left alone where it has none |
| `defender_flag` | the first of the defender's countries; with none, the controller of the battle's province |

`CCombatEntry::OnClick` (`0x757020`, slot 4), under the same two conditions: clears the selection
(the screen's slot 43 with 0), **selects the battle** (slot 38, with the battle's `CSelectable`) -
which is what brings the window up, by section 1 - and centres the map on the battle's province.
`CCombatEntry::BuildTooltip` (`0x7572E0`, slot 13) lists the attacker's units, the text
`COMB_TT_VS`, and the defender's.

## 9. The marker on the map

`FINDINGS-gui.md`, sections 6 and 7, has what the marker is - two billboards, `combat_status` and
`combat_status_close` of `interface/mapitems.gfx`, three frames each, made the first time
`CCombat::UpdateCombatStatusWindow` runs for a battle **the player has a country in**, and freed
with the battle - and how it is placed and turned. Read again here for what that write-up left
open:

- **The frame**, from the listing of `0x57C1E7..0x57C296`. The player's id is looked for among the
  **defender's** countries:

  | the attacker's share | the player is not defending | the player is defending |
  | --- | --- | --- |
  | above 660 | 0 | 2 |
  | above 330 | 1 | 1 |
  | otherwise | 2 | 0 |

  The picture `gfx/mapitems/combat_status.dds` is green, yellow, red from the left, so **frame 0
  says it goes well for the player** and 2 that it goes badly. Both billboards take the same
  frame.
- **The number**: `FormatFixedPoint(share * 100000 / 1000, 0)` - the share as a percentage with
  **no decimals**. That write-up's "66.000" was the figure before it is formatted.
- **Where**: half way between the place of the attacker's first unit and the defender's first
  unit (each unit's slot 30). The marker is hung on the battle's province, which is why the
  routine hands it half the difference and not the middle itself. `inferred` for the second
  sentence; the arithmetic is read.
- **Which way it points**: the heading (`CUnit +0x104`) of the attacker's first unit.

**The arrow of a unit that attacks** is the `attackArrow` of `interface/arrows.gfx`, drawn as
every selected unit's arrow is (`FINDINGS-movement.md`, section 10). What picks it is
`CUnit::IsNextProvinceEnemyHeld` (`0x5C5B20`, the unit in EAX): the unit has a path, the first
province of it has a controller, and that controller is an enemy of the unit's owner
(`CCountry::IsEnemy`). **Whether anybody stands there does not come into it**: a walk into
undefended enemy ground has the attack's arrow too.

**What a click on the marker does was not read.** Each billboard is entered in a table of the
map's objects by the battle's province (`0x640CA0`), which is presumably how a click finds the
battle; by section 1 selecting the battle is all it would take to open the window.

## 10. The share

`CCombat::GetAttackerStrengthShare` is `a * 1000 / (a + d)`, each sum at least 1
(`FINDINGS-combat3.md`). The sums are `CCombatant::SumSubUnitStrength`, whose land arm, read off
the listing of `0x566334..0x566434`, is for every brigade of **every unit of the side, on the
front or not**:

    b = organisation * strength / 1000
    p = (unit.attack_b * unit.attack_product / 1000) * (unit.defend_b * unit.defend_product / 1000) / 1000
    s = (soft_attack + hard_attack + (the side attacks ? toughness : defensiveness)) * 1000 / 10000
    if s > 1000:  p = p * s / 1000
    sum += b * p / 1000

`attack_product` and `defend_product` are the unit's two products of the hour's modifiers
(`CUnit +0xEC`, `+0xF0`); `attack_b` and `defend_b` (`+0xF4`, `+0xF8`) are set to 1000 with them
and nothing read for a land battle changes them. The three figures of `s` are the brigade's own
definition's. **Both products go in for both sides**, so a unit's defence modifiers count for it
when it attacks.

This is a figure for the player and nothing else: it is worked out only for a battle the player
has a country in (`FINDINGS-slot11.md`), and by section 3 the window works the modifiers out again
before it asks for it.

## 11. Tactics

`FINDINGS-landbattle.md`, section 5, has when they are picked and what four figures of a battle
they fill. This is the rest.

**A `CCombatTactic`** is `0xDC` bytes, loaded by `LoadCombatTactics` from
`common/combat_tactics.txt`, one for each block, into a list whose **entry 0 is a
`CNullCombatTactic`** made by the loader - so the first tactic of the file is number 1.

| offset | key | |
| --- | --- | --- |
| `+0x08` | the block's name | |
| `+0x40` | `countered_by` | the name, as read |
| `+0x5C` | `picture` | |
| `+0x78` | | the number of the tactic `countered_by` names, looked up when the whole file is in; 0 for none. A name that is no tactic is logged |
| `+0x80` | | the tactic's own number |
| `+0x84` | `aggressiveness` | |
| `+0x88` | `base` | |
| `+0x8C` | `trigger` | |
| `+0xCC` | `combat_width` | |
| `+0xD0` | `attacker` | |
| `+0xD4` | `defender` | |
| `+0xD8` | `movement_speed` | |

The six numbers are fixed point, so `base = 15` is 15000. Any other key is logged as
`Unknown combat tactic effect`.

**This corrects `FINDINGS-landbattle.md` and the record on which of `+0x78` and `+0x80` is
which.** They had `+0x80` for `countered_by`. `+0x80` is the tactic's own number: it is what the
loader copies *into* another tactic's `+0x78`, what the tooltip looks other tactics up by, and
what indexes the country's table of bonuses below. So tactic A **counters** tactic B where
`A +0x80 == B +0x78`, and `CCombat::SumTacticEffects` leaves out a side's tactic where **the other
side's `+0x80` equals its `+0x78`** - the same rule that write-up states in words, with the two
offsets the other way round.

**`CCombatant::PickTactic`** (`0x5649A0`: the side, an aggressiveness, the number of a tactic to
favour, and a difference in skill), for each tactic from number 1:

    weight = 0
    if the tactic is a real one (slot 7) and its trigger holds for this side:
        weight = country.tactic_bonus[number] + base
        if number == favoured:
            weight = weight * (1000 + INITIATIVE_PICK_COUNTER_ADVANTAGE_FACTOR * skill difference) / 1000
        d = |aggressiveness - the tactic's aggressiveness|, held between 0 and 1000
        weight = weight * (1000 - d * AGGRESSIVNESS_SELECTION_IMPACT / 1000) / 1000

`country` is the first of the side's countries and `tactic_bonus` the table at `+0x24` of its
technology status, indexed by the tactic's number. The skill difference is a whole number and is
taken as that many units (`floor((d + 0.0005) * 1000)`).

Then **one draw of the game's generator** `r`, as a signed number: with `total` the sum of the
weights above 0, the tactic picked is the first whose running sum of those weights is above
`r % total`. A draw below 0 has a remainder that is not above 0, so it picks the first tactic with
any weight. Where nothing has weight the side has no tactic.

**The routine makes two draws**, not one: before the weights it builds the scope the triggers are
judged in, and that takes a draw for the scope's own seed. So a pick of both sides is four.

**Who picks first** (`CCombat::PickTactics`, re-read): each side's leader gives a skill and, where
he has a unit, an aggressiveness (`CUnit::GetAggressiveness`, `0x5D3F10`: the first unit from his
own upward with an active plan gives -1000, -500, 0, 500 or 1000 by its stance 0 to 4; with none,
the first unit upward with an aggression of its own gives that; else 0). The side with **less**
skill picks first, favouring nothing; the other then picks **favouring the tactic that counters
the first's** - the first's `+0x78` - with the difference in skill. Equal skill: the attacker
first, the defender second, favouring nothing.

**The conditions a tactic's `trigger` is made of** that belong to a battle - each judged on the
side that is picking (`+0x40` of the scope):

| key | class | true when |
| --- | --- | --- |
| `is_attacker` | `CIsAttackerTrigger` | the side's `is_attacker` is the value |
| `frontage_full` | `CFrontageFullTrigger` | for `yes`: the battle's width less the widths of the side's front is **below 0** (`CLandCombatant::HasRoomOnFront`, `0x56BDF0`, says no) |
| `reserves` | `CReservesTrigger` | for `yes`: the side has a unit in reserve (`+0xC8` above 0) |
| `skill_advantage` | `CSkillAdvantageTrigger` | the side's leader's skill less the other side's is at least the value |
| `skill` | `CSkillTrigger` | the side's leader's skill is at least the value |
| `has_armour_unit` | `CCombatHasArmourUnitTrigger` | for `yes`: a unit **on the side's front** has a brigade whose type is `is_armor` (`CSubUnitDefinition +0x34`) |

`frontage_full`, `reserves` and `has_armour_unit` are false outright for a side that is not a land
side (`CCombatant` slot 6). `trait`, `CTraitTrigger`, was not read.

**A technology names a tactic at its own top level**: `CTechStatistics::LoadKey` keeps any key it
does not know that begins `tactic_`, with its number, in a list at `+0x1E8`. **How that reaches
the country's table was not read**; that each level of the technology adds it once is what every
other figure of a technology does, and is `inferred` here.

**A tactic's own text** (`CCombatTactic::BuildTooltip`, `0x439830`): its four figures where they
are not 0 (`CCombatTactic::BuildEffectsText`, `0x438C10`: `COMEV_COMBATWIDTH`,
`COMEV_DAMAGE_ATTACKER`, `COMEV_DAMAGE_DEFENDER`, `COMEV_MOVEMENTSPEED`), then
`TACTIC_COUNTERED_BY` with the name of the tactic at `+0x78`, then `TACTIC_COUNTERS` and every
tactic whose `+0x78` is this one's number.

## What was not read, and what is not established

- **What a click on the marker does**, and the two small button handlers (`0x734710`,
  `0x734720`).
- **The object at `CInGameIdler +0x1CC0`** that opening a battle hides.
- **How a technology's `tactic_` figures reach the country's table**, and `CTraitTrigger`.
- **The naval and the air side** of the window beyond their element names, the tooltip at
  `0x72BD70`, and everything a tooltip writes.
- **The second pair of multipliers** (`CUnit +0xF4`, `+0xF8`): reset to 1000 with the products
  and read by the share and by `FireUnit`; no writer of any other value was found in what was
  read for land battles, and none was looked for elsewhere.
- Nothing here was watched in a running game. The maintainer's screenshot of 2026-10-09 agrees
  with it as far as it goes: a title of "Battle of" and the province, a bar with a small first
  part beside a marker reading 6, a width of 10, "1 units, 3 width." over each front and
  "0 units in reserve." under it, and a tactic's name over each side.
