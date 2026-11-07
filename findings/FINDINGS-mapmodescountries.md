# The diplomatic, intel and theatre map modes

*Read 2026-11-07 by a delegated agent (fragment `mapmode-countryviews.json`), statically, for a program that colours
the map in each of these modes as the original does; the political mode read beside them for its stripes. The revised
`CCountry +0xC30` checked again off the bytes by the collecting session. Addresses are **VAs** unless written "rva"
(`project.json` holds rvas, VA - 0x400000). Valid for this build only. **[exe]** a figure of the executable; **[mod]** one
a file can change. `confirmed` unless marked.*

**What it settles.** For modes 2 (Diplomatic, `mapmode_6`), 6 (Intel, `mapmode_4`) and 8 (Theatre, `mapmode_11`):
each province's two colours and every input to them, with the exact packed values; when the colours are made
again; what else each mode shows or hides; and each mode's part of the province tooltip. And for mode 1
(Political): which colour is the stripes'.

**Corrections, rather than additions.**
- **The political stripes are the owner's.** The political loop writes the controller's colour first and the
  owner's second, and terrain_2_0.fx draws the second where `stripes.dds` has alpha - the thin band (section 1).
- **A theatre's colour is a region's.** Theatre number k of the player's list takes CMap's region number k's colour,
  `interface/colors.txt`'s k-th in TFH (section 4). Nothing about the theatre itself picks it.
- `CCountry +0xC30` (`color`) is a CColor held by value, not a `CPersistent*`: `CCountry_GetColour` copies its fields
  `+0xC34`..`+0xC48` into a fresh CColor (`0x4CCCC0`).
- `CInGameIdler_RefreshMap` calls each mode's **setter**, not its colouring; and refresh flag 0x100 is set by nine
  diplomatic routines as well as by the two province setters its record named (section 5; `FINDINGS-mapmodesfigures.md`,
  section 1, found the same nine).

## How every one of these colours reaches the screen

A setter (`FINDINGS-minimap.md`, section 5) runs its mode's loop over the CProvinceManager's entry vector, which
holds two packed `0xAARRGGBB` colours per province (entry +0 and +4; province ids from 1), and then
`Map_RefreshColourTextures(0)` copies them into the two 256x256 province textures (first -> `GeneralTexture`,
second -> `GeneralTexture2`). A colour is floats packed by `CColor::ToPackedArgb` (`0xA628B0`): each channel
`trunc(float x 255.0)` [exe].

The land is drawn in map styles 2, 6, 12 and 14 by `TerrainShader_General` (near) and `General_Low` (far)
[mod: gfx/FX/terrain_2_0.fx]:

    c = lerp(first - 0.7, second - 0.7, stripes.dds.a)     # General_Low: the same as c2*a + c1*(1-a)
    near: lerp(grey terrain, c, 0.3) * COLOR_LIGHTNESS
    far:  c overlay-blended with map_overlay_tile.dds

`map/terrain/stripes.dds` [mod] is 128x128 DXT1 with one-bit alpha: per row, 17 opaque pixels in every 64
(26.6%), on diagonal bands, repeating every 8 map pixels (`FINDINGS-farmap.md`, A.2). **So the second colour is the
thin stripe and the first is the ground.** Beaches sample the first colour only. The terrain draw runs with alpha
blending off (`FINDINGS-mapdraw.md`, C.1), so a colour's alpha does not show on land. None of 6, 12 and 14 is 0, 16,
18 or 19: the sea is plain water and the far view has the country names. A selected province is lifted +0.1 per
channel when the textures are filled (`Map_UpdateProvinceColourTexture`). That is a refill, not a recolouring.

Every setter of the three writes layer mask 0xFFBA and the graphics owner's +0x60F8 word = 0. So trees, bit 0x4's
pass and MapObjects (0x40) are off; borders, province names, building pictures, rivers, sea borders and counters are
on; and the depot and weather pictures are off (`FINDINGS-mapmodesfigures.md`, section 6). Political's 0xFFBE
keeps 0x4.

**Nothing else is mode-specific in these three.** Two sweeps of `.text`, one for compares of +0xD34 or CMap +0x2A90
with an immediate and one for compares after a call to `GetCurrentMapMode` (slot +0x164), found 2, 6 and 8 only in
their setters, `MapMode_Theatre_Recolour` and RefreshMap. Positive control: the same sweeps find the many 18 and 19
tests and the weather mode's 11. So no icon, line or marker belongs to these modes.

The viewer in the loops is **CMap's player** (+0x2A88/+0x2A8C). The tooltip's is the game state's (+0xC30). They
are the same country in play.

## 1. Political (mode 1), for the stripes

`MapMode_Political_ColourLoop` (`0x864000`, `ret 4`; called by the setter at `0x6663D3`). For each province:

    b = 1.0 where the player's intel on it (+0x370[id], 0 past +0x374) >= 2, else 0.5;  0 where not simulated (+0x13D)
    owner id 0:      both 0x99999999 [exe]
    else:            first  = controller's colour x b      (owner's where the controller is the owner)
                     second = owner's colour x b

A country's colour is the CColor at CCountry +0xC30 (`CCountry_GetColour`, `0x4CCCC0`), read from the country
file's `color = { r g b }` [mod: common/countries/*.txt]; each of r, g, b above 1.0 is divided by 255
(`CColor::Load`). "x b" is `CombineColourBrightness` (`0x643750`): each channel times b, held at 1.0.

**So an occupied province is the controller's colour with thin stripes of the owner's**, dimmed to half below intel
2. The front end's and lobby's map use `MapMode_Political_ColourLoopLobby` (`0x864180`) instead: no intel, unowned
0x99999999, unsimulated black, and **first = owner, second = controller** - the other way round.

## 2. Diplomatic (mode 2)

### 2.1 The colours [exe]

`MapMode_Diplomatic_ColourLoop` (`0x864330`, `ret 4`; one caller, the setter at `0x666A73`). P is the player,
S = countries[owner]->diplomacy[P] (the **owner's** status towards P). There is **no intel test and no simulated
test**, and the controller is not asked:

| province | first colour | packed |
| --- | --- | --- |
| owned by P | (0, 0.9, 0) | 0xFF00E500 |
| S co_belligerent (+0x58) | (0, 0.8, 0.9) | 0xFF00CCE5 |
| else S dependency (+0x18) - a puppet bond either way | (0, 0.7, 0) | 0xFF00B200 |
| else the owner's faction is real (slot 7) and is P's | (0, 0.9, 0.7) | 0xFF00E5B2 |
| else S alliance (+0x14) | (0, 0.7, 0.7) | 0xFF00B2B2 |
| else S war (+0x20) | (0.7, 0, 0) | 0xFFB20000 |
| else, unowned provinces among them | (0.5, 0.5, 0.5) | 0xFF7F7F7F |

The tests run in that order, first match wins. The second colour is the same as the first, except:

- a province of P's own that is **not** one of P's cores: 0x66666666 (drawn as 0.4 grey);
- **any** province where P holds a core (the core list, CMapProvince +0x344): (0, 0.9, 0), 0xFF00E500.

So P's land is solid green, its land without its core green with dark grey stripes, and a core of P's held by
anyone else is that holder's relation colour with thin green stripes. Guarantees, NAPs and military access do not
colour. An unowned province takes the last row *inferred*: country 0's statuses hold nothing.

### 2.2 When it is coloured again

- When the mode is chosen, **including a click on the button already down**: the setter re-runs and only the sound
  is skipped. Also on `PopMapMode` back to it, `DoTutorialAction`'s `diplomacy` (`0x64B9A4`), and the air orders
  window's return to a saved mode (`0x74184F`).
- From `CInGameIdler_RefreshMap` (every frame), where the mode table's entry is 1 (`ApplyCustomGameSettings`, the
  console's set-building command) or **refresh flag 0x100** is set. A sweep for `or dword [R+0x84], imm` finds 0x100
  set by `CMapProvince::SetOwner`, `Province_SetController`, the `Apply` of the war declaration, alliance, military
  access, offered access, NAP and faction actions, `CAlliance::Activate` and `Deactivate`, and `SetMilitaryAccess`.
  Positive control: every writer the record already had is among its 20 hits.

So a change of owner or controller, a declaration, an alliance and a faction action recolour it. **A puppet made or
released, a guarantee, a peace or a call to arms answered do not, by themselves** - unless an owner or controller
changes alongside. That rests on the sweep: a writer by another idiom would escape it (*likely*). Nothing recolours
it on a day or an hour.

### 2.3 The tooltip

Branch `0x498A67`, after the frame (`FINDINGS-provincetooltip.md`, section 3). Only where the owner's id is not 0
and the province is land:

    "\n " + the owner's name + ": " + the first of, S' = the player's status towards the owner:
        S' war                                      ATWARWITHUS     "They are at war with us."
        S' co_belligerent                           OURWARALLY      "Allied in a War"
        a vassal bond whose overlord is the owner   OURVASSAL       (no table defines it)
        a vassal bond whose puppet is the owner     DIP_THEY_PUPPET "They are a puppet state of §Y$OVERLORD$§W",
                                                    OVERLORD = the owner's overlord's name
        S' alliance                                 ALLIEDWITHTHEM  "We are allied with them."
        S' IsGuaranting (we guarantee them)         WEGUARANTEED    "We are guaranteeing their independence."
        S' IsGuaranteed (they guarantee us)         THEYGUARANTING  "They are guaranteeing our independence."
        the owner is not the player                 NEUTRAL         "We are neutral towards them."
        (the player's own province: nothing after the colon)

Each key is rendered with the settings' text colours and appended with no line break of its own [mod: localisation].
A save's `vassal` block's `first` is the overlord (the start save: `first="JAP" second="MAN"`). So OURVASSAL shows
when **the player is the owner's puppet**, despite its name. No csv of TFH or BlackICE defines the key, so it shows
as the key itself (*inferred*: the localiser's missing-key behaviour was not read here). The tooltip does not ask
factions, so a faction member with no alliance reads NEUTRAL while it is coloured faction teal.

## 3. Intel (mode 6)

### 3.1 The colours [exe]

`MapMode_Intel_ColourLoop` (`0x8671F0`, the province objects in EDI, bare `ret`; called by the setter at
`0x6676CB`). L is the player's intel on the province, 0 where the player's id is not under +0x374. One colour for
both, so there are no stripes:

| L | colour | packed |
| --- | --- | --- |
| 0 | (0.3, 0, 0) | 0xFF4C0000 |
| 1 | (0.2, 0.3, 0) | 0xFF334C00 |
| 2 | (0.2, 0.4222, 0.2) | 0xFF336B33 |
| 3 | | 0xFF338833 |
| 4 | | 0xFF33A433 |
| 5 | | 0xFF33C033 |
| 6 | | 0xFF33DD33 |
| 7 | | 0xFF33F933 |
| 8, 9 | (0.2, 1.0, 0.2) | 0xFF33FF33 |

For L >= 2, g = min(float(L)/9.0 + 0.2, 1.0), each step in double and rounded to float (the 0.2 is the float 0.2
widened). **The province is black where its template is not simulated, and only in this arm**: L 0 and 1 are
coloured whatever. Sea and land alike.

### 3.2 When it is coloured again

Everything in 2.2 (the setter's callers, the table, flag 0x100), and also, at most once a frame:

- **refresh flag 2**, set by `CLocalIntelBoost::Execute` (`0x9BE658`) and by **CInGameIdler slot 56**
  (`0x672BE0`, at `0x6731EC`). Slot 56 is a pass over every province that recomputes the province's byte +0x36D
  from where the player's and its allies' units stand (each unit's province and its neighbours) and
  `Province_IsHiddenByFog` (the player's intel below 2), and sets 2 for each province whose byte changed;
- **any of flags 0xF**: Province_SetController's bit 0, the capitulation, `ApplyCustomGameSettings`, the in-game
  and front-end enters.

**The daily intel rebuild does not ask for it**: neither `RunIntelRefresh` nor `RunIntelRefreshIfRequested`
touches the screen (no `+0xBE8` / `+0x84` access in either). So intel levels that change away from the edge of what
the player's units see wait for one of the triggers above. Who calls slot 56, and how often, was not found.

### 3.3 The tooltip

Branch `0x49AF68`. Where the player's id is not 0: `"\n" + IntelLevelText(L)` - INTEL_NONE "No intel (0)",
INTEL_STRUCTURES "Basic Intel (1)", INTEL_UNITS "Basic Intel, divisions of unknown strength (2)", INTEL_2..INTEL_7
"Intel lvl 3".."Intel lvl 8", MAX_INTEL_LEVEL "Full Intel (9)" [mod: localisation]. On sea too.

## 4. Theatre (mode 8)

### 4.1 The colours

The setter writes mode 8 and then calls `MapMode_Theatre_Recolour` (`0x667AE0`), which does nothing unless the
mode is 8. It then clears the depot and weather pictures, runs `MapMode_Theatre_ColourLoop` (`0x864C40`) and
refills. With b = 1.0 at the player's intel 2 or more, 0.5 below, 0 unsimulated:

    every province, both colours:  grey 0.5 x b  ->  0xFF7F7F7F, 0xFF3F3F3F or black
    for each theatre T of the player's country (CCountry +0x570, in list order), k = 0, 1, 2, ...:
        colour(P) = region[k].colour x b(P)         where k < the number of regions; else P's grey
        (1) every province of T (its +0x60 list) gets colour
        (2) for each area A of T (+0x84) whose area group holds more than one province:
                for each area F of CollectTheatreFocusAreas(T, A's group), not controlled by T's country
                and not already done for T:  every province of F gets colour

Later theatres overwrite earlier ones. Both colours are always alike, so there are no stripes. Only the **player's**
theatres are coloured; every other province stays grey, and allied land takes a theatre colour only as one of its
focus areas. `CollectTheatreFocusAreas` (`FINDINGS-agents.md`) gives other same-side countries' areas of the group
that touch this theatre more than any other theatre of ours.

**The colour is a region's, by index** [mod]: `region[k]` is CMap's k-th region in `map/region.txt`'s order. Each
region's colour is assigned at startup from `interface/colors.txt` (`CMap_AssignRegionAndContinentColours`,
`FINDINGS-mapmodesrest.md`, section 2). TFH has 2677 regions, none empty, and 200 colours, so for k < 200 theatre k
takes colors.txt's k-th colour - (4, 144, 178), (181, 72, 106), (63, 125, 214), (54, 167, 156), (231, 181, 12) ... -
exactly, at full intel. Below intel 2 every channel is halved, floored. Region 200 has none and stays white. BlackICE
ships the same 200 values. Theatre count in TFH is at most a dozen a country, so the wrap never matters in practice.

### 4.2 When it is coloured again

The setter's callers: the button (again when already down), `PopMapMode` for a popped 8 **or 17** (the theatre
editor's), `DoTutorialAction`'s `theatre` (`0x64BA25`), and the air orders window (`0x741B97`). RefreshMap's table
entry and flag 0x100, as in 2.2. **Not when the AI rebuilds the theatres** - every ten days, or at a change of war.
The one code path that rebuilds and repaints, `CProductionView::RecalculateTheatres` (`0x7FC860`), hangs on a glue
nothing subscribes, beside the `theatres_calc_button` the view hides (*likely* dead).

### 4.3 The tooltip

Branch `0x49B160` (modes 8 and 17). Where `CCountry::IsFriend(the controller, the player, false)` holds - the same
country, an overlord or puppet either way, the same overlord, the same real faction, an alliance, or a
co-belligerent who is not an enemy - the province's theatre is looked up. That is the one its id pair is stamped with
(+0x380/+0x384), the stamp `CTheatre::AddProvince` and `CTheatre_StampProvinces` write. Then its headquarters
(`CTheatre_GetUnit`), and where both exist:

    "\n(" + the headquarters unit's name + ")"

So an allied province names the ally's theatre headquarters. Nothing in the colouring corresponds.

## 5. The refresh, in one place

`CInGameIdler_RefreshMap` runs a mode's **setter** - not its loop - in two cases: where the mode table's entry is 1,
for modes 1, 2, 4-9 and 17; and on refresh flag 0x100, for 1, 2, 4-9. Mode 6 also runs on flag 2 and on any of
0xF, never twice in a frame. The setters re-run `MapMode_ShowButton` and the settings writes too.

## Not established

- Who calls CInGameIdler slot 56, and so how often the intel mode follows the player's units.
- A writer of the refresh flags or the mode table by an idiom the sweeps could not see - hence whether a puppet,
  a guarantee, a peace or a call to arms recolours the diplomatic mode by itself.
- What OURVASSAL renders as (*inferred*: the key).
- Whether `CProductionView::RecalculateTheatres` is reachable (a subscriber of the view's +0xF0 glue elsewhere).
- Which theatre stamps a province two countries' theatres hold (the tooltip's theatre).
- The theatre editor (mode 17): its colouring `0x865290` and RefreshMap's mode-17 block.
- What mask bit 0x4's pass and bit 0x40 draw (`FINDINGS-mapmodesfigures.md`, section 6).

Frontier: 0x465290, 0x241DC0, 0x24D850, 0x272BE0
