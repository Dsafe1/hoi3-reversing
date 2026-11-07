# The simplified terrain, region and naval map modes

Read statically out of `hoi3_tfh.exe` on 2026-11-07 by a delegated agent (fragment `mapmode-rest.json`), for a program
that colours the map in these three modes as the original does; the setters' calls to their own routines and the naval
icons' flags checked again off the bytes by the collecting session. Nothing here was watched in a running game.
Addresses are **rvas** against an image base of `0x400000` unless a line says VA. Only valid for this build. **[exe]**
marks a figure of the executable, **[mod]** one an install or a mod can change.

Settles, for mode 13 (`mapmode_14`, Simplified Terrain), mode 3 (`mapmode_7`, `MAPMODE_7G`, Region) and mode 19
(`mapmode_16`, Naval): every province's colour and its inputs, when the colours are made again, what else each mode puts
on the map, and each mode's part of the province tooltip. The setters are `FINDINGS-minimap.md`, section 5; the air mode,
the naval mode's sibling, is `FINDINGS-airmap.md`.

**Correction first.** `FINDINGS-mapmode.md` listed modes 3, 13 and 19 as coloured by "the generic path", and said
Simplified Terrain has "no routine of its own". Each has its own colouring routine, called by its setter (VA `0x666C8C`,
`0x666E9B`, `0x668293`); what is true is that **CInGameIdler_RefreshMap, the per-frame refresh, has no arm for any of the
three** (its arms are modes 1, 2, 4-9 and 17, and 0, 6, 11 under the refresh flags). So in all three modes **the colours
are made when the mode is chosen and, for the naval mode, when one of the player's naval missions starts or ends - never
daily, never on a change of owner, intelligence or region**. Region and Simplified Terrain colours change only by choosing
the mode again.

Common to all three: each province graphics entry (the graphics owner's `+0x1DC4` container) carries two packed
`0xAARRGGBB` colours, the ground (`+0`) and the stripes (`+4`); the packer (`CColor::ToPackedArgb`) multiplies each float
by 255 in x87 extended precision and **truncates**. Provinces are visited from 1; province 0 is never coloured.

## 1. Simplified Terrain (mode 13)

**The setter** (`MapMode_SimplifiedTerrain_Driver`, `0x266CE0`): mode 13, `MapMode_ShowButton(14)`, layer mask `0xFFBA`,
map style **8**, `+0xE7` = 0, the supply depot pictures hidden (`HideProvinceObjects98`), the air icons and circles and
the naval icons taken down, then `MapMode_SimplifiedTerrain_ColourLoop` (`0x465B70`) and `Map_RefreshColourTextures(0)`.

**The colour** (`0x465B70`, province entries in EDI, bare `ret`), for every province:

    b = 1.0   where the map's country's (CMap +0x2A8C) intel of the province (+0x370) is 2 or more   [exe]
        0.5   below 2 (and where the country's index is past the province's intel array)            [exe]
        0     where the province's template is not simulated (+0x13D clear; every province in a campaign)
    colour = the terrain's colour (CTerrain +0xC, a CColor) x b, each of r, g, b clamped at 1.0, alpha kept
    ground = stripes = that colour, packed

The terrain is the template's `+0xC`, the same terrain the terrain mode and the tooltip name. Its colour is the
category's `color = { r g b }` in `map/terrain.txt` [mod], read by `CTerrain::LoadKey`'s `color` arm through
`CColor::Load`: each figure **above 1** is divided by 255, so a figure of exactly 1 stays 1.0 (255) [exe]; alpha is 1.0
unless a fourth figure is given, which is taken raw. A terrain with no `color` keeps the constructor's white. In Their
Finest Hour: ocean 0 0 255, mountain 117 108 119, forest 91 123 45, woods 165 205 108, marsh 76 112 105, plains 241 221
184, urban 137 104 165, hills 135 70 0, jungle 32 151 0, desert 218 195 0, arctic 235 235 235.

**Exact bytes.** With b = 1 the round trip `c / 255` in single precision, then × 255 truncated, gives back c for every c
from 0 to 255 (checked for all 256). With b = 0.5 the byte is ⌊c / 2⌋. Alpha is 0xFF. Not simulated: 0xFF000000.

**The sea is coloured and not shown.** Sea provinces are in the loop and get the ocean's colour, but style 8 is not one of
the three styles (16, 18, 19) that draw the water from province colours (`FINDINGS-mapmode.md`, *The sea*), so the water
draws as in the terrain mode. BiceLib's one-byte patch of the style to 18 is what makes it show.

**Else on the map.** Mask `0xFFBA`: no trees (bit 0x1 clear, `FINDINGS-farmap.md`), no shadow pre-pass (0x4 clear),
province names and land and water borders (0x8, 0x2, 0x200 set); the far view goes to General_Low at 500 and shows
country names, as every mode but terrain and weather. No icons. Supply depot pictures hidden.

**Tooltip**: the terrain mode's part (jump-table entry 13 = entry 0, `0x9843A`; `FINDINGS-provincetooltip.md`, section
4): on land the owner's flag, or the controller's and the owner's; the terrain's name; its four figures. The tail's
objectives lines are shown (only the air and naval modes leave them out).

## 2. Region (mode 3)

**The setter** (`MapMode_Region_Set`, `0x266AD0`): mode 3, `MapMode_ShowButton(7)`, mask `0xFFBA`, style **8** (written
at `0x266C5F`-`0x266C64`), the same hidings as section 1, then `MapMode_Region_Colour` (`0x465930`) and the refill. It is
the only caller of the colouring. Also reached from the tutorial's `mapmode region` and the air orders window's destructor
restoring a saved 3.

**The colour** (`0x465930`, `ret 4`), for every province, b as in section 1 (the map's country, intel 2 and above):

    base = (b x 0.5, b x 0.5, b x 0.5, 1.0)                     grey   [exe]
    continent painting off (CInGameIdler +0x8, the normal case):
        the province is in a region (+0x360 above 0):  colour = the first region of its list (+0x358) x b
    continent painting on:
        the province has a continent (+0x368):        colour = the continent's colour x b
    otherwise:                                         colour = base
    ground = stripes = colour, packed

Packed, the grey is **0xFF7F7F7F** at intel 2 and above, **0xFF3F3F3F** below, 0xFF000000 unsimulated; a region's colour is
its colors.txt bytes at intel 2 and above and each byte halved (floor) below. **There are no stripes.** **Unknown
provinces are not hidden**, only darkened. A province's "first region" is the head of its list, which `CMap::AssignRegions`
fills in the map's order of regions (`FINDINGS-airorders.md`, 4). Sea provinces are coloured by their sea regions and,
as in section 1, never shown (style 8).

**Continent painting** is the byte the console command **`cpaint`** flips (`ConsoleCmd_ContinentPaint`, `0x3CFC0`; "Now
painting continent. Shift-click to painting the map." / "Painting disabled"), one of three editor commands left in the
release with `paint` (+0x5) and `rpaint` (+0x6). Nothing in a normal game sets it.

**Where a region's colour comes from** - `CMap_AssignRegionAndContinentColours` (`0x28A6E0`), once a process, at
startup, from `CGameState_StartupResetAndLoadGameplaySettings`:

1. It reads **`interface/colors.txt`** [mod] - the interface folder of the directory settings, the mod's own copy alone
   in mode 1 and the mod's where it has one in mode 2 - and keeps, in file order, every `color = { r g b }` (CColor::Load,
   as in section 1); any other key is passed over. Their Finest Hour's and BlackICE's files are the same 200 colours,
   starting 4 144 178, 181 72 106, 63 125 214.
2. **Regions**, in CMap's vector (+0x2A40, `map/region.txt`'s order [mod]): a region with no province is passed over
   and uses no colour; otherwise it takes the next colour. **When the list runs out, the region met at that moment takes
   nothing - it keeps the constructor's white (1, 1, 1, 1) - and the list starts again from its first colour at the next
   region.** With 200 colours the 201st, 402nd, 603rd ... non-empty region is white [exe, the wrap; mod, the counts]:
   Their Finest Hour has 2221 regions and BlackICE 2308, none empty, so 11 are white in each.
3. **Continents** (+0x2A30, `map/continent.txt`), from the list's first colour again, with no test for an empty one. In
   Their Finest Hour's order (inferred: the vector is in file order): europe 4 144 178, asia 181 72 106, africa 63 125
   214, north_america 54 167 156, south_america 231 181 12, oceania 57 160 101, lake 194 140 86, greenland 199 175 12.

With no colors.txt every region and continent stays white. The colour is held at `+0x50` of both CRegion and CContinent.

**Else on the map**: as section 1 (mask 0xFFBA, no icons).

**Tooltip** (`ProvinceTooltip_Mode3`, `0x9924F`), after the name and owner:

    continent painting off:
        for each region of the province's list, in order:   "\n - " + its name, then "*" where it is used for peace
    whatever the painting, where the province has a continent:
        "\n" + the continent's localised name with its first letter upper-cased

A region's name (`CRegion::GetLocalisedName`, slot 6) is its key's localisation, made once when the region is loaded;
where the key has none (the localisation equals the key) and the region has provinces, `REGION_NAME` with `NAME` = its
first province's name - "$NAME$ Region" in Their Finest Hour [mod]. "Used for peace" is the region's `peace = yes`
(`CRegion +0x6C`). The upper-casing is the C runtime's `toupper` on the first byte (ASCII only). The objectives lines of
the tail follow.

## 3. Naval (mode 19)

**The setter** (`MapMode_Naval_Set`, `0x2680E0`): the naval icons put up first (`UpdateNavalMapIcons`, VA `0x66822F`),
then mode 19, `MapMode_ShowButton(16)`, mask `0xFF9A`, style **19** - one of the three that draw the water from province
colours - the supply depot pictures hidden, `MapMode_Naval_Colour` (`0x4674E0`, VA `0x668293`) and the refill. Leaving 19,
every other setter, `MapMode_SwitchIcons` and the screen's entry take the icons down (`HideNavalMapIcons`, `0x46AA70`:
the four icons and the large naval base picture).

### 3.1 The colours

`MapMode_Naval_Colour`, with P the player:

    every province:           ground = stripes = 0x80808080                       grey, alpha 0x80   [exe]
    for P's diplomatic status with each country in turn, where it holds an undeclared war that is not the
    same war as the last one met:
        every province of every region the war covers (CUndeclaredWar +0x38):
                              ground = stripes = 0x80FFD240                       orange             [exe]
    for each unit of P's (every level) by its order:
        patrol (6):           ground = 0x8040FF40 (green); the stripes too where still grey
        convoy_raid (10):     stripes = 0x80FF4040 (red); the ground too where still grey
                              - on the order's province and on each neighbour that is water and not a canal or
                                strait closed to P (WaterIsClosed: the defines' SUEZ, PANAMA, BALTIC, BLACKSEA and
                                GIBRALTAR pairs, closed where an enemy holds the blocker)
        convoy_escort (9):    the convoy looked up again by its id; along its path from the start, every province
                              from the beat's first end through its last: green as patrol
                              (the walk stops at the last end even where the first was never met)
        anything else:        nothing

So: **grey everywhere; orange over the regions of P's undeclared wars, land and sea; green where P's fleets patrol, with
the sea around the patrol province; red where they raid convoys, with the sea around; green along each escort's beat;
green and red stripes where a patrol and a raid overlap; on orange, a patrol keeps orange stripes and a raid keeps the
orange ground.** Intercept, sortie, reserve, transport and invasion colour nothing; nor do other countries' fleets,
P's naval bases, or a fleet's range. The beat is the escort order's own (`+0x74`, `+0x78`; `FINDINGS-navalmissions.md`,
section 8: the first stretch of the convoy's route within the fleet's range of its base). The undeclared war's provinces
are its regions' province lists appended region after region, duplicates and all (`UndeclaredWar_AddRegion`). Every
colour has an alpha of 0x80, as the air mode's; what the shaders make of it was not followed. The player is read twice:
the undeclared wars from `CCurrentGameState +0xC30/+0xC34`, the units from the map's country `CMap +0x2A88/+0x2A8C` -
the same country in play.

**When**: the setter; and, only while the mode is 19 and the order's unit is the player's, **when a patrol, convoy raid or
convoy escort order starts** (`CPatrolOrder::Start`, `CConvoyRaid::Start`, `CConvoyEscortOrder::Start`, slot 13 of
each) **and when one is destroyed** (`CPatrolOrder::~CPatrolOrder` `0x19C3B0`, `CConvoyRaid::~CConvoyRaid` `0x1A0030`,
`CConvoyEscortOrder::~CConvoyEscortOrder` `0x19F640`, at the top, before the order is taken apart), each followed by
the refill. Not daily: a convoy's route changing, an escort's beat worked out again in its hour, an undeclared war made,
widened or ended - none recolours until one of those happens.

### 3.2 The four icons

`UpdateNavalMapIcons` (`0x46A6F0`) keeps **four flags** a province - bytes zeroed and only ever set to 1 (VA
`0x86A86A`), so **they say whether, not how many**. Over the list of finished battles (`CCurrentGameState +0xB7C`, the
CCombatHistory of the combat manager at `+0xB5C`, which keeps a week: `FINDINGS-airmap.md`, 3), each entry of **kind 2
(naval)** at its province, with P the player:

    ours-attacking = the attacker is P
                  or the attacker is a country (id not 0, not REB) with which P IsSameSide, or is co_belligerent
                     (+0x58 of P's status with it) and not IsEnemyTag
                  or P IsEnemyTag the defender
    ours-defending = the defender is P, or CanOperateIn(P, defender)

    a convoy raid's battle (+0x20):  flag 0 where still clear and ours-attacking;
                                     otherwise - or where flag 0 was already set - flag 1 where still clear and ours-defending
    any other naval battle:          flag 3 likewise, else flag 2

| flag | means | billboard of `interface/mapitems.gfx` | kept at the entry's | vector |
| --- | --- | --- | --- | --- |
| 1 | our convoys raided | `naval_convoy_raided_icon` | `+0x6C` | (3, 3, 0) |
| 0 | convoys we sank | `naval_convoy_sunk_icon` | `+0x70` | (-3, 3, 0) |
| 2 | we were attacked | `naval_raider_defended_icon` | `+0x74` | (0, 3, 3) |
| 3 | we attacked | `naval_raider_attacked_icon` | `+0x78` | (0, 3, -3) |

For every province from 1 each icon is made where its flag is set and it has none, and taken down where it has one and the
flag is clear (`FINDINGS-billboardfx.md`, 3). On `FINDINGS-airmap.md` 4's reading of the vector - east, up, north,
inferred - raided stands 3 east, sunk 3 west, defended 3 north and attacked 3 south of the province's point, raised 3, at
the type's scale; whether the vector reaches the screen is the open point of `FINDINGS-billboardfx.md`. **The
"raider" icons are about every naval battle that is not a convoy raid**, whatever the fleets were doing. Kind 6 (naval
bombing) is not counted. Unlike the air icons there is **no term for P owning or controlling the province**. The flags set
together with the tooltip's counts: an icon stands where its tooltip line has a count above 0 (inferred from setting the
two tests side by side; the flag-already-set branch differs only for a battle that is both "ours attacking" and "ours
defending").

**The large naval base picture**, in the same function, for every province from 1 (no simulated or land test):
`ShowLargeNavalBaseIcon` with the naval base's **built** level (`CMapProvince +0x300` → `+0x20`, / 1000, truncated)
where P's intelligence of the province is 2 or more, else 1 where it has a naval base at all, else 0: made where above 0,
sized `(level − 1) × 0.2 + 1` (1 at level 1, 2.8 at level 10), at the naval base's position, its frame from
`ProvinceGraphics_UpdatePortPicture`; taken down below 1. A bombed base keeps its size; a base P knows little of shows
as a level 1.

**When**: the setter; **every day** (`CInGameIdler::DailyUpdate`, while the mode is 19); `MapMode_SwitchIcons` given 19.
So the icons follow the week's battles a day at a time while the colours do not.

**Else on the map**: mask `0xFF9A`, the air mode's - no trees, the small building pictures not hit-testable (bit 0x20,
`FINDINGS-airmap.md` 5); no rings, no lines.

### 3.3 The tooltip

`ProvinceTooltip_Mode19` (`0x9C6AC`), after the name and owner, with P the player, over the same list's kind-2 entries at
this province:

    the attacker is not id 0 and is P or CanOperateIn(P, it):     ours attacking
    else the defender is not id 0 and is P or CanOperateIn(P, it): ours defending
    else IsEnemyTag(P, defender):                                  ours attacking
    else:                                                          not counted
    a convoy raid's battle:  attacking -> raids,            defending -> convoys sunk
    any other:               attacking -> raider attacked,  defending -> raider defended

Then, each where above 0, in this order, `"\n"` + the line with `NUM` = the count:

| key | Their Finest Hour |
| --- | --- |
| `NAVAL_TOOLTIP_RAIDS` | We have sunk §Y$NUM$§W enemy convoys in the province during the past week. |
| `NAVAL_TOOLTIP_CONVOYS_SUNK` | The enemy has sunk §Y$NUM$§W of our convoys in the province during the past week. |
| `NAVAL_TOOLTIP_RAIDER_ATTACKED` | We have attacked enemy raiders §Y$NUM$§W times in the province during the past week. |
| `NAVAL_TOOLTIP_RAIDER_DEFENDED` | The enemy have attacked our raiders §Y$NUM$§W times in the province during the past week. |

Here they are counts, one per finished battle. The tail's objectives lines are left out in this mode (and the air mode).

## Not established

- **Whether a dying naval order still colours its provinces**: the destructors recolour before the order is taken apart;
  whether the unit's `+0xB0` still points at it then was not read (the air orders' same question).
- **`MapGraphics_RefreshByFlags`** (refresh flags `& 0xF`, on a change of owner or controller): whether it recomputes any
  province's colour in these modes or only re-uploads what the entries hold. Not read; the reading above assumes the
  latter.
- What the shaders make of a province colour's alpha (0x80 here, 0xFF in modes 3 and 13).
- Whether CMap's continent vector is in `continent.txt`'s order (the loader appends; not traced to the file walk), and
  so which continent takes which colour.
- Readers of `CInGameIdler +0x5` and `+0x6`, and what painting does on a click.
- The two other callers of `RegionOrContinent_GetColour` at rva `0x464C40` and `0x465290` (other agents' modes) and at
  VA `0x64DC2B` / `0x64E0D1` (a function not identified that indexes CMap's regions).
- The layer-mask bits 0x40 and 0x80 (clear and set in `0xFF9A`).

**Frontier** (rvas): `0x464C40`, `0x465290`, `0xA7ACB0`, `0xB84A20`, `0x4AD300`, `0x486CD0`, `0x48F750`, `0x48E520`.
