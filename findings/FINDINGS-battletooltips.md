# The battle window's tooltips, and a battle's row in a unit's panel

*Read 2026-10-12 for OpenHOI3; the mechanics spec is `OpenHOI3/docs/mechanics/combatview.md`,
section 12. Addresses are VA / rva. Everything here is one build of `hoi3_tfh.exe`. Nothing in it
was watched in a running game.*

What the window of a battle says in a tooltip - on land, at sea, in the air and under bombs - and
what the row a unit's panel has for each of its battles says. `FINDINGS-combatview.md` has the
window and the row themselves; `FINDINGS-tooltips.md` how a tooltip is asked for;
`FINDINGS-combatmods.md` the combat modifiers and their `BM_` keys.

**How it was read.** Each routine decompiled headless out of a copy of the Ghidra project with
the record applied (`ghidra/DecompileAt.java`), the string literals read out of the image, and
the joins the decompiler leaves without operands read in the listing (`scripts/disasm.py`) where
their order was not otherwise plain: the attack line, a modifier's line, the firing range, a
modifier icon's two halves and the dispatcher's tests. Every other join follows the same order -
key, separator, colour, figure, suffix - and is written here in it.

## 1. How the window is asked

`CInGameIdler::GetElementTooltip` (`0x6C5290`) tests, after the windows of `FINDINGS-tooltips.md`
section 5, **the element's name** against `closebutton` (`CLOSE`, unconditionally), and then
**the element's group** - the string at the element's `+8` (`0x6C5C5E`..`0x6C5CAC`, `lea eax,
[edi+8]`) - against `army_option`, `wing_option`, `navy_option` and `combat_view`. Any of the four,
with a battle's window up (the idler's slot 59), goes to **`CCombatView::BuildTooltip`**
(`0x731120`), whose answer is final. The window's own group is `combat_view` and its entries'
are `army_option` and the others (`FINDINGS-combatview.md`, sections 1 and 5), so every element of
the window but its close button is the router's. **The close button says `CLOSE`.**

An element's name is its slot 17 (`0x67A330`: its type at `+0x24`, that type's slot 6), the name
the `.gui` file gives it. `confirmed`

**The modifier icons** are the exception: each `combat_modifier` entry is given the modifier's id
as its name (`FINDINGS-combatview.md`, section 4), so its icon carries no battle group and reaches
the dispatcher's own `combat_mod_icon` arm (`0x6C8E27`..`0x6C8EAB`): the id read back with
`atoi` (`0xA5B220`), then **the modifier's name** (`0x564340`: `CombatModifierKey`, the key's text)
into `text` and **its description** (`0x564410`: the key + `_desc`, its text) into `delayed`, `0x1C`
apart. `confirmed`

## 2. The router (`CCombatView::BuildTooltip`, `0x731120`)

`(view, out, element)`. In order, the first that holds:

1. **`combat_battle_events_icon`**, or the window answering its slot 17 for `combat_event_name` -
   nothing. Their Finest Hour's `combat.gui` has neither; what the window's slot 17 does with an
   argument (`0xAC3C90`) was not followed. `inferred`
2. **`combat_terrain`** - the battle's terrain's own name (`CCombat +0x24`, its localised name).
3. **`combat_width`** - `COMBAT_WIDTH`. (`combat_battle_events_icon` is tested here too and is
   never reached.)
4. **`positioning`** - `FLEET_POSITIONING`.
5. **`retreat_button`** - `COMBAT_RETREAT`.
6. By the battle's kind - each list's entries asked whether the element is theirs (observer slot
   22):
   - **at sea** (kind 2): the attacker's `ships`, then the defender's - a ship's tooltip (section 5);
   - **in the air** (kind 3), and **a bombing** (slot 8 says yes): the attacker's `planes`, then
     the defender's - a wing's (section 6);
   - **on land**: the attacker's `committed` - a unit's (section 3); the attacker's `reserves` -
     **its chance of coming up** (section 4); the defender's `committed` and then **the defender's
     `reserves` - a unit's, not a chance**; and then, land alone, **`tactic_name` or
     `tactic_picture`** of either side - that side's tactic's own text where it has one
     (`CCombatTactic::BuildTooltip`, section 7) - and **`combat_attack_indicator`** -
     `DEFENDER_COUNTERED` where `CCombat::IsDefenderCountered`, else `ATTACKER_COUNTERED` where
     `IsAttackerCountered`, else `NONE_COUNTERED`.
7. Every kind: **`leader_name` or `leader_photo`** of a side - by the element itself
   (`0x731D1C`..): the tooltip of the side's highest ranked leader (`CLeader` slot 9,
   `FINDINGS-unitpaneltooltips.md`, section 13), and where his skill is above the other side's
   highest ranked leader's, `LEADER_INITIATIVE` appended to `delayed`.

`confirmed`. The tactic, the indicator and the leaders do not return: a tactic's text that was
written stands unless a later test writes over it, and none does.

## 3. A land unit (`CCombatView::BuildUnitTooltip`, `0x729D40`)

`(entry, out, element)`, `ret 0xC`. The entry finds its unit again by its id (`+0x2C`); none,
nothing. Then by the element:

| element | what it says |
| --- | --- |
| `str_bar` | `CURR_COMB_STR` + `§Y` + its brigades' strength over its most (slot 23), times 100, 1 place + `%§W\n` (-1 where the most is 0) |
| `org_bar` | `CURR_COMB_ORG` + `§Y` + its organisation (slot 20) to 1 place + `§W\n` |
| `unit_cw_strip` | `UNIT_COMBAT_WIDTH` + `: §Y` + its definition's width (`+0xC8`, the summed definition) to 1 place + `§W\n` |
| anything else | the whole, below |

**The whole**, in `text`:

    the leader: LEADER_COMMAND_INFO with NAME and SKILL, where the unit's leader is one (slot 8);
          else NO_LEADER_FOR_THIS_2 for a unit of one brigade, NO_LEADER_FOR_THIS_1 for more,
          each + "\n"
    for a unit landing from the sea, the landing's progress and its two scales - not set out
          here, there being no landing in what this is read for
    BATTLE_ATTACKMOD + ": " + colour + attack + "§!%", then " / " + the other colour + base
          + "§!%" where the two differ; "\n"
    BATTLE_DEFENDMOD the same, with the defence
    for each combat modifier on the unit (CUnit +0xDC): its name (0x564340) + ": ", then
          where its attack and defence are one figure: colour + figure + "§W%\n"
          else: attack's colour + attack + "§W%/" + defence's colour + defence + "§W%\n"
    the side's tactic's figures as the unit's side feels them (0x57C380, section 7), where the
          entry has a tactic (+0x50) - the attacker's two where the entry is the attacker's (+0x54)
    AP_ATTACK + ": §Y" + its definition's piercing attack, trimmed + "§!\n"
    ARMOR_VALUE + ": §Y" + its definition's armour, trimmed + "§!\n"

**The attack** is the unit's attack product (`+0xEC`) times its second multiplier (`+0xF4`) over
1000, times 100 - a percentage; **the base** the product alone, times 100. The colour is `§Y`, and
`§G` where the attack is above the base, `§R` below; the base's colour the other way. The second
multiplier is 1000 but for a landing (`FINDINGS-combatview.md`), so the two are one figure and the
line one colour. The defence is `+0xF0` and `+0xF8` the same way. Both to 2 places. Read in the
listing (`0x72AF13`..`0x72B071`). `confirmed`

**A modifier's figure**: `§R` where it is 0 or less, `§G+` above, then the figure times 100 to 2
places. The attack is the record's `+4` and the defence `+8` (`FINDINGS-combatmods.md`); read in the
listing (`0x72B7F9`..`0x72B9A9`). `confirmed`

## 4. A reserve of the attacker's (`0x72BD70`)

`(entry, out)`, `ret 8`: `BATTLE_REINFORCE_CHANCE` + `: §Y` + `CUnit::ReinforceChance(unit, the
entry's +0x54)` times 100 to 2 places + `§W%\n`, whatever the element. **Only the attacker's
reserves say it**; the defender's say a unit's whole. `confirmed`

## 5. A ship (`0x727CD0`)

`(entry, out, element)`, `ret 0xC`; the ship by its id (`+0x2C`).

| element | what it says |
| --- | --- |
| `str_bar` | `CURR_COMB_STR` + `§Y` + its strength over its most (slot `GetMaxStrength`), times 100, 1 place + `%§W\n` |
| `org_bar` | `CURR_COMB_ORG` + `§Y` + its organisation to 1 place + `§W\n` |
| anything else | the whole, below |

    "==>" + where it has a target (CSubUnit::ResolveTarget): "§G" where the target's country is
          an enemy of the ship's, else "§R", + the target's name + "§W"; with none, "<> "
    " (" + its distance (+current_distance) to 0 places + "km)\n"
    where its unit is in a battle: EFF_POS + " : §Y" + its positioning + "%§W\n" - its
          definition's positioning and its side's (the attacker's where its country is on the
          attacker's list, else the defender's), times 100, times (1000 + its country's
          naval_positioning_bonus) over 1000, 1 place
    where it is in a unit: BATTLE_FIRINGRANGE + its firing range (CSubUnit::FiringRange: the
          definition's distance, shortened by the weather) to 1 place + "km"; and where the
          province's precipitation times FIRINGRANGEMODIFIER is not 0, "(" + "§R" below 0 or "§G"
          above + that times 100, 0 places + "%§W)"; then "\n"
    BATTLE_ATTACKMOD + ": §Y" + its attack product times 100, 2 places + "§W%\n"
    BATTLE_DEFENDMOD the same with its defence product
    its combat modifiers, as a unit's (section 3)
    the side's tactic's figures, where the entry has one (+0x50)

**With no target the line runs `==><>  (`**: the `<> ` and the ` (` follow one another. The firing
range's join is the text, the figure and `km` (`0x7288CA`..`0x7288F7`). `confirmed`; that the
technology's `naval_positioning_bonus` is the figure the rewrite has as `targeting_chance` is not
established.

## 6. A wing (`0x72D100`)

`(entry, out, element)`, `ret 0xC`; the wing by its id (`+0x28`).

| element | what it says |
| --- | --- |
| `str_bar` | `CURR_COMB_STR` + `§Y` + its strength (`+0x5C`) over its most (slot 12), times 100, 1 place + `%§W\n` |
| `org_bar` | `CURR_COMB_ORG` + `§Y` + its organisation (`+0x60`) to 1 place + `§W\n` |
| anything else | `BATTLE_ATTACKMOD` + `: §Y` + its attack product (`+0x50`) times 100, 2 places + `§W%\n`; `BATTLE_DEFENDMOD` the same (`+0x54`); its combat modifiers (`+0x40`); and the entry's tactic's figures (`+0x40` of the entry) with both halves |

**A row with no wing** - the bombed side's buildings and goods in a bombing - says a figure: a
building (`+0x30`) its level now to 2 places (`+0x24`), `/`, its most to 0 places (`+0x20`); a good
(`+0x38` not 7) its production (`+0x164` of the province by the good) to 2 places; the good held
(`+0x38` 7, `+0x34` not 7) the province's pool (`+0x270`) and `/` and its other figure (`+0x294`)
- the order of the last two joins was not read. `inferred` for the rows with no wing.

## 7. A tactic

**Its own text** (`CCombatTactic::BuildTooltip`, `0x439830`): its figures (`BuildEffectsText`,
`0x438C10`) + `\n`; where another tactic counters it, `TACTIC_COUNTERED_BY` with `NAME` that
tactic's name; and where it counters any, `TACTIC_COUNTERS`, then `\n` where it counters more than
one, then a line for each - `§Y  ` + its name + `§!\n` - in the order of the tactics' list. Only a
tactic its slot 7 calls valid is counted.

**Its figures** - each a line where it is not 0, the key + `: ` + `§G+` above 0 or `§R` below + the
figure + the suffix:

| figure | key | figure written | suffix |
| --- | --- | --- | --- |
| width (`+0xCC`) | `COMEV_COMBATWIDTH` | to 0 places | `§W\n` |
| attacker's damage (`+0xD0`) | `COMEV_DAMAGE_ATTACKER` | times 100, 0 places | `%§W\n` |
| defender's damage (`+0xD4`) | `COMEV_DAMAGE_DEFENDER` | the same | `%§W\n` |
| speed (`+0xD8`) | `COMEV_MOVEMENTSPEED` | the same | `%§W\n` |

**As a side feels them** (`0x57C380`; `(tactic, out, attacker's, defender's)`, `ret 0x10`): the
width always, the attacker's damage and the speed only where the first flag is set, the
defender's damage only where the second is. A unit passes its side - set and clear, or clear and
set - and a wing passes both set. `confirmed`

## 8. A battle's row in a unit's panel (`CCombatEntry::BuildTooltip`, `0x7572E0`)

    the attacker's side (0x5703E0, with its units named) + "\n" + COMB_TT_VS + "\n"
          + the defender's side, the same
    a bombing (slot 8): + what of the province is bombed (0x5713E0)

**A side** (`0x5703E0`; `(out, units, named)`, `ret 0xC`): nothing for a side with no units.
Named, first **its units' names** (`0x56F690` with a limit of 999999):

    for each unit: "@" + its country's tag + " £" + its first brigade's type's key - none for a
          unit whose +0x1F8 is under 3, has no brigades, or whose first has no type - + " "
          + its name;
          after each, ", " where more than one remains, " " + AND + " " before the last,
          nothing after it
    a fleet or an air unit: the same for each of its ships or wings - the ship's country and
          type - but each with the FLEET's name, and the count of what remains is the units'
          count less one, taken down once a ship

So **a side of one fleet runs its ships together with nothing between them**, each named after
the fleet. Kept as read. Below 21 the routine instead writes each name to at most 20 letters, one
to a line, and `AND_MORE` past the limit; this row never asks for that.

Then **what the side has**, one line after `\n`, by the side's first unit:

| first unit | text | figures |
| --- | --- | --- |
| a fleet (slot 16) | `UNIT_ATTACK_INFO_NAVY` | `CAP` capital ships, `SCR` screens, `TRA` transports, `SUB` submarines - by the ship's type: capital, else submarine, else transport, else screen |
| a land unit (slot 15) | `UNIT_ATTACK_INFO_ARMY` | `MEN` the men of the land units' brigades' strength added up (`FormatMen`), `UNIT` how many land units, `BRIG` how many brigades |
| an air unit (slot 17) | `UNIT_ATTACK_INFO_AIR` | `FIG` fighters, `BOM` bombers, `ROC` rockets - by the wing's type: rocket, else bomber, else fighter |

The counts are of every unit on the side, land and the rest alike. `confirmed`

**What of the province is bombed** (`0x5713E0`; `(combat, out)`, `ret 8`): where the first bomber's
mission (its unit's `+0xB0`) has something to bomb - the buildings its slot 30 takes that the
province has (level above 0), named and joined with `, ` and ` and `, ending `.`; the goods its slot
31 takes, after ` ` + `BOMB_PROD_OFF` + ` `; the goods its slot 32 takes that the province holds
some of, after ` ` + `BOMB_POOL_OFF` + ` `. `inferred` for which slot is which list.

## Kept as read, though they look odd

1. A side of one fleet in a battle's row runs its ships' names together, each named after the
   fleet.
2. The defender's reserves say a unit's whole, the attacker's their chance of coming up.
3. A ship with no target writes `==><>  (` with two spaces.
4. A tactic's countered and countering lines need its slot 7 to call the other valid.
5. `combat_battle_events_icon` is tested twice, the second time unreachably.

## Not established

- What a window's slot 17 does with an argument (`0xAC3C90`), which the router's first test asks.
- Whether `naval_positioning_bonus` is the technology's `targeting_chance`.
- The bombed side's rows' joins (section 6).
- A landing's progress lines (section 3).

## In the record

Entered in `ghidra/project.json` by `fragments/merged/battle-tooltips.json`: nine functions new -
the ship's, the wing's and the attacker's reserve's tooltips, a combat modifier's name, key and
description, a tactic's figures as a side feels them, a side's unit names and its summary, the
bombing's summary and `atoi` of a string - and `CCombatView::BuildTooltip`,
`CCombatView::BuildUnitTooltip` and `CCombatEntry::BuildTooltip` revised, read whole.
