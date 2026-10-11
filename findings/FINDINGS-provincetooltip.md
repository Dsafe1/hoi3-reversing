# The tooltip of a province

Read for OpenHOI3's map tooltip, 2026-10-11: `ProvinceTooltip_Build` (`0x4973E0`) whole - its head
on a selected unit's move, its frame, the parts for the terrain, political and supply map modes,
and its tail - with the inline flag icon its political part writes. The air part is
`FINDINGS-airmap.md`, section 7; the diplomatic, intel, VP, theatre, weather, resources and
naval parts were left. How the tooltip is shown at all is `FINDINGS-tooltips.md`.

Every address is a VA of this build.

## 1. The call

Slot 3 of `CProvince`'s second table (`0x15BEBA4`, at object offset 8) and `CMapProvince`'s
(`0x15BEC1C`). `CInGameIdler::GetTooltip` calls it on the province under the mouse with two
stack arguments, the out `GuiTooltipText` and **the province itself**; `this` is the province's
second base, 8 bytes in, so every offset inside the function is 8 short of `CMapProvince`'s
(`FINDINGS-mapmode.md`). A null province gives an empty tooltip. `ret 8`. `confirmed`.

Every line below is added to the tooltip's `text`; nothing goes in its delayed halves.

## 2. The head: a selected army's move

Only when the first thing selected is an army - a selection's slot 1 answers 0 for `CArmy`, 1 for
`CNavy`, 2 for `CAir` and 3 for a province (`0xA80690`, `0xBF9B90`, `0xC037D0`, `0x57BC80`).
With `enemy` meaning the country controlling the province is the army's owner's enemy
(`CCountry::IsEnemyTag`), at most one line, each `"\n" + text + "\n"`:

    if the province is land and the army may not stand in it (CArmy::MayStandIn):
        UTM_NO_INFRA where its country may enter the province (MayEnterProvince, false),
        else UTM_NO_ACCESS
    else, the first that holds of:
        it is in a battle and may not retreat into the province (slot 19)   UTM_NOT_LEGAL_RETREAT
        it is land, enemy, and its strength * 1000 / its strength ceiling
          (-1 where the ceiling is 0) is under its ShatterThreshold         UTM_MAY_SHATTER
        it is land, carried by nothing (CArmy +0x300), enemy, it received
          no supplies (+0xFC) and its SupplyConsumption is above 0         UTM_LACK_OF_SUPPLIES
        it cannot fight (slot 33) and enemy:
            a land army whose role (+0x2FC) is 0 - one with a headquarters
              brigade: nothing, and nothing more of the head
            otherwise                                                       UTM_TOO_WEAK_TO_FIGHT
        its FuelConsumption is above 0, enemy, and it received no fuel     UTM_LACK_OF_FUEL

`confirmed` off the listing. `CArmy +0x300` is new to the record: the fleet carrying the army,
cleared by `CNavy::UnloadCarried` (`0x5CFEA1`) and `RemoveFromTransport` (`0x5CF193`).

## 3. The frame

After the head, for every province:

1. **its name** - slot 7 of the second table (`0x4973B0`), which is the template's
   (`CProvinceTemplate +0xB0`, new to the record);
2. where the owner's id is not 0 (id 0 is the empty tag, not `REB`), **`" (" + the owner's name
   + ")"`** - the name out of a table of country names by id (`0x518730`, `0x518620`);
3. with the tooltip debug on - the byte `0x1A85598`, which a console command flips with "Tooltip
   debug ENABLED" (`0x4436EF`) - a block of the country's tag, its id and the province's id;
4. **where the template's `simulated` byte (`+0x13D`) is clear, the whole tooltip is emptied**
   (`0x40C400`, which clears a `GuiTooltipText` in EAX) and returned - unless the debug is on. In a
   campaign every province is simulated;
5. **the map mode's part** (sections 4 to 6), then the tail (section 7).

## 4. The terrain mode (0 and 13)

    on land:
        owner and controller the same and not id 0:  " - ( @" + owner + ")"
        not the same:                                " - ( @" + controller + "/@" + owner + ")"
    "\n" + the terrain's name (CTerrain slot 6, 0x4AE700: its key, localised)
    "\n" + the terrain's figures (0x4ADD20)

`@` and a tag is the text's flag icon (section 8). **The controller comes first** - the
decompiler shows the owner first; the listing (`0x498824..0x498891`) does not. The figures are
four lines, each `key + "§Y" + figure + "§W\n"`, the figure to two places:

    TERRAIN_MOVEMENT_COST  movement_cost (+0x44)   always
    TERRAIN_ATTACK         attack (+0x50)          where not 0
    TERRAIN_DEFENCE        defence (+0x4C)         where not 0
    TERRAIN_ATTRITION      attrition (+0x5C)       where not 0

## 5. The political mode (1)

On land only: the same flags as section 4, then `"\n"` + the terrain's name. Nothing at sea.

## 6. The supply mode (4)

`FINDINGS-supplyconvoys.md`, section 9, read it for its keys and figures; this is how it is put
together, `confirmed` off the listing where the order matters. Colours: `§G` (`0x15B5C50`), `§Y`,
`§R`, and `§!`, which goes back to the text's own.

**At sea**, for each convoy on the province's list whose owner is the player:

    "\n" + LOGTT_8 + its start's name + LOGTT_9 + its end's name + LOGTT_10

(`0x4C7B90` answers the start, `CConvoy +0xC0`, and `0x4C7BB0` the end, `+0xC4`; the end is
fetched first and joined second.) Then, for each good 0 to 6 it carries more than none of,
`"\n   "` + `CONV_SHIP_IRO` with `NAME` the good's name and `VALUE` the amount to one place.

**On land with `MaxInfrastructure` under 0.200**: `"\n" + TOOLOWINFRA`, and nothing else.

**Otherwise**, with `capacity` = `SupplyCapacity`, and where the player's intelligence on the
province (`+0x368`, by country id) is **above 5**:

    infra   = INFRASTRUCTURE * (1000 + LOCAL_INFRASTRUCTURE + GLOBAL_INFRASTRUCTURE) / 1000,
              held between 10 and 1000, then * 10000 / 1000          (a level, 0.10 to 10)
    most    = 10000 * MaxInfrastructure / 1000
    INFRA   = (infra < most ? "§R" : "§G") + infra to two places + "§!"
    not a capital:  "\n" + SUPPLY_INFRA_EFFECT_INFO (INFRA, MAX = most to two places,
                    THRU = capacity trimmed) + "\n"
    a capital:      "\n" + SUPPLY_INFRA_CAPITAL_EFFECT_INFO (THRU = VALUE_MAX) + "\n"
    "\n" + LOGTT_1 + "§Y" + the depot's name + "§W"
    " (" + the depot distance (+0x4C, the weighted one) + " " + LOGTT_2 + ")"

The two `"\n"` leave a blank line between the line on infrastructure and the one on the depot.
The constants are `floorf(10.5)` and `floorf(10000.5)`; "trimmed" is `FormatFixedPointTrimmed`.
No test is made that the province has a depot.

And where that intelligence is **above 8**:

    "\n" + LOGTT_3 + (pool supplies < need ? "§R" : "§G") + pool supplies + "§W"
         + LOGTT_4 + (pool fuel < need ? "§R" : "§G") + pool fuel + "§W"
    "\n" + LOGTT_5 + (drawn < throughput ? "§R" : "§Y") + supplies drawn + "§W"
         + LOGTT_6 + (the same for fuel) + fuel drawn + "§W"
    "\n" + LOGTT_7 + (throughput < capacity ? "§Y" : "§R") + supplies through + "§W"
         + LOGTT_6 + (the same for fuel) + fuel through + "§W"
    with a naval base above level 0:  "\n" + PORT_SHIPS (SIZE = NavalBaseCapacity, two places)

Today's drawn and throughput (`+0x1A8`, `+0x1F8`), every figure to two places.

## 7. The tail

1. **An air unit selected, with a base**: `"\n" + the distance + "km (" + its range + "km)"` - the
   distance `CMap::DistanceBetweenProvinces` between the province and the base's (`0x4A54D0`), a
   whole number; the range its definition's `+0x148`, to no places.
2. **A fleet selected, with a base**: the same, with the distance by sea
   (`CMapProvince::NavalDistanceTo` to the base, to no places).
3. Outside the air and naval map modes, the player's and its allies' objectives on the province,
   `OL_AO_THEY_REQUEST` / `OL_AO_WE_REQUEST` with `OL_AO_DEFEND` / `OL_AO_ATTACK`; read for its
   keys only.
4. **A province selected, other than this one**: `"\n" + PROV_DISTANCE_FROM` with `DIST` the
   distance between the two (`DistanceBetweenProvinces`) and `FROM` the selected province's name.

## 8. The flag icon in text

`@` and the three letters after it draw a country's flag (`FINDINGS-text.md` has its width).
`CEU3BitmapFont` slot 21 (`0x83FB60`): the tag's country id - **0 is taken as 1** - picks a cell of
a flag atlas, and a quad is drawn **23 wide and 11 high, from 3 to 14 below the top of the line**:
the renderer counts y upwards, a glyph runs down from `y - yoffset` and a new line takes the line
height off `y` (`0xAFD127`), so the `y` handed in is the line's top. Slot 26 (`0x83F7F0`) answers
**24**, what the pen moves on by. The constants are the doubles 23.0 and 11.0 at `0x160AA28` and
`0x160AA30`. Which texture the atlas is was not read.

## Not established

- The flag atlas's texture, and so how a flag is shrunk into its cell.
- The debug block's text beyond its literals.
- The objectives' lines (section 7, 3) beyond their keys.
- The diplomatic, intel, VP, theatre, weather, resources and naval parts.
