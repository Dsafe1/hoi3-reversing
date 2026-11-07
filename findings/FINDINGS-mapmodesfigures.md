# Four map modes, figure for figure: infrastructure, victory points, strength, resources

*Read 2026-11-07 by a delegated agent (fragment `mapmode-figures.json`), statically, for a program that colours the
map in each of these modes as the original does; the VP hues, the 0.3 constant and the region and infrastructure setters'
styles checked again off the bytes by the collecting session. Addresses are **VAs** unless written "rva" (`project.json`
holds rvas, VA - 0x400000). Valid for this build only. **[exe]** a figure of the executable; **[mod]** one a file can
change. `confirmed` unless marked.*

**What it settles.** For modes 5 (Infrastructure, `mapmode_9`), 7 (VP, `mapmode_10`), 9 (Strength, `mapmode_12`) and
10 (Resources, `mapmode_13`): each province's two colours and every input to them; when the colours are worked out
again; what else each mode shows or hides; and each mode's part of the province tooltip.

**Corrections, rather than additions.**
- The VP loop does not draw a province "in its controller's colour". It draws it in one of three fixed hues -
  green, red or yellow - by how the controller stands towards the player (section 3). `FINDINGS-mapmode.md`'s "It
  is not a green ramp" paragraph is corrected.
- `MapMode_Infrastructure_SetMapStyle` (rva `0x266C5F`) is in the **region** mode's setter (`MapMode_Region_Set`,
  VA `0x666AD0`), before its `mov [eax+0xF4], 8` at `0x666C64`. The infrastructure setter writes **9**, at `0x667284`.
  The entry is renamed `MapMode_Region_SetMapStyle`.
- `GameSettings +0xE7` is **whether the resource icons are shown** (section 5). `FINDINGS-minimap.md` and
  `FINDINGS-farmap.md` A.4 had it open.
- The infrastructure ramp's "below 1 the loop leaves the colour alone" means **black**: the loop packs (0, 0, 0, 1)
  first and keeps it. A province the player has no intelligence of at all is black too.

## 1. When these four modes are coloured again

The four colouring loops each have one caller, their mode's setter. A setter runs:

1. when the button is pressed (`FINDINGS-minimap.md`, section 5), and when `PopMapMode` returns to the mode (the end
   of placing a deployment, the air orders window; `FINDINGS-minimap.md`, section 6);
2. for modes 5, 7 and 9 only, from **`CInGameIdler_RefreshMap`** (`0x6516A0`, every frame), in two cases:
   - **the refresh flags (idler +0x84) hold 0x100**. A resumed sweep of `.text` for `or [X+0x84], imm` finds
     0x100 set by `CMapProvince::SetOwner` (`0x4A2344`), `Province_SetController` (`0x4A35CE`), the `Apply` of the
     war declaration (`0xA146E7`), alliance (`0xA1A416`), military access (`0xA247A1`), offered military access
     (`0xA26CE7`), NAP (`0xA2C8CC`) and faction (`0xA32FA8`) actions, `CAlliance::Activate` (`0xA46BC9`) and
     `Deactivate` (`0xA46D79`), and `SetMilitaryAccess` (`0xA4A531`). For each of the diplomatic sites,
     `retsBefore` from the nearest recorded entry is empty. Also the console's fog-of-war toggle (`0x44190E`), which
     sets every flag. The positive control is that the two writers already recorded, SetOwner and SetController,
     were found;
   - **the current mode's entry of the map mode table (idler +0x30) is 1.** Only two writers were found, each storing
     1 for the current mode: `ApplyCustomGameSettings` (`0x41E21C`) and `CCgmSetBuildingLevelCommand::Execute`
     (`0x42CC63`). A sweep for a store through `[X+0x30]` found these, a store of 0 at `0x407019`, and RefreshMap's
     own read (the positive control). Its two mode lists are 1, 2, 6, 5, 8, 17, 4, 7, 9 and 1, 2, 6, 5, 8, 4, 7, 9.
     *Likely*: a writer by another idiom would escape the sweep;
3. Strength also from `DoTutorialAction`'s `strength` (`0x64BA50`). A routine of the air orders window at `0x7415E0`
   (not read) calls the setters for 5, 7 and 9 (`0x7419F3`, `0x741B0B`, `0x741CAB`), *by all appearance* its inlined
   pop.

**Resources (10) is in neither of RefreshMap's lists**, and its setter has no direct caller. So its colours are
worked out only when the mode is chosen. **None of the four is coloured again on a day or an hour, on a unit's
move, on a building finished, bombed or repaired, or on a change of intelligence** (flag 2 is the intel mode's
alone). Strength in particular keeps the picture it had when it was chosen, or when an owner, controller or
diplomatic status last changed.

Every setter ends with `Map_RefreshColourTextures(0)`, which copies the entries into the two province colour
textures. Map styles 9, 13, 15 and 20 are not 16, 18 or 19, so **the sea is never drawn in these modes' province
colours** (`FINDINGS-mapmode.md`, "The sea"). The land draws `TerrainShader_General` near and `General_Low` far
(`FINDINGS-farmap.md`, A.2), where a province's two colours are blended by `stripes.dds` and mixed 30% into grey
terrain. A sweep for reads of +0xF4 next to `GetGameSettings` finds only the known tests (0, and 16/18/19). So the
four styles draw alike (*likely*: a read through a held pointer, which is how the terrain draw reads it, escapes
that sweep).

The setters also write the graphics owner's +0x60F8 **and** +0x60F9 as one zero word. So the supply depot pictures
and the weather pictures are off.

## 2. Infrastructure (mode 5)

`MapMode_Infrastructure_ColourLoop` (`0x866F80`, `ret 4`), argument the `CProvinceManager` (WaterObject): P is the
player's id (CMap +0x2A8C).

    colour = (0, 0, 0, 1)                                        black
    if the player's intelligence of the province (+0x370[P], if P < +0x374) >= 1:
        L = (float)((double)(float)infra / 1000) * 10            infra = _MODIFIER_INFRASTRUCTURE_ (+0x114 -> +0x60)
        the first of   L >= 10 (0, 1)    >= 9 (0.25, 0.73)  >= 8 (0.2, 0.5)  >= 7 (0.1, 0.4)  >= 6 (0.65, 0.75)
                       >= 5 (1, 1)       >= 4 (1, 0.3)      >= 3 (0.8, 0.1)  >= 2 (0.6, 0)    >= 1 (0.1, 0)
        as (r, g), b = 0, a = 1; below 1, black
    both entries (+0 and +4) take it: no stripes

- **The level is floor(infra / 100)** for every value 0 to 1000 (checked in float32 arithmetic) [exe]. The input is
  the province's raw modifier: infrastructure buildings and anything else that adds to it. It is **not** the supply
  tooltip's figure with `LOCAL_INFRASTRUCTURE`/`GLOBAL_INFRASTRUCTURE` folded in. Damage counts.
- There is no brightness by intelligence and no land test. A sea province with a zero modifier is black, and is not
  drawn anyway.
- The packed bytes are `FINDINGS-mapmode.md`'s table, the packer truncating.

**Tooltip part** (`0x49B8F2`). Where the player's intelligence (by CCurrentGameState +0xC34) is 1 or more:

    "\n" + FormatFixedPoint(infra * 100000 / 1000, 2) + "%"

So 0.700 is `70.00%`, truncated, **with no label**: the line follows the province's name and owner and says only a
percentage. Nothing below intelligence 1.

## 3. Victory points (mode 7)

`MapMode_VictoryPoints_ColourLoop` (`0x8665A0`, `ret 4`). P is the player (CMap +0x2A88 tag, +0x2A8C id).

    b = (P's intelligence >= 2) ? 1.0 : 0.5           0.5 also where the intel array is too short
    b = 0 where the template's simulated byte (+0x13D) is clear
    colour = (0.9b, 0.9b, 0.9b, 1)                    grey: 229 or 114
    if victory points (+0x34) > 0:
        k = min((points / 15) * 0.3 + 0.7, 1.0)       integer divide: 0.7 for 1-14, 1.0 from 15
        C = the controller's country (+0x338)
        C is P                                   -> green  (0.3b, kb, 0.3b)
        C at war with P (status +0x20), or P's
          or C's tag is REB                      -> red    (kb, 0.3b, 0.3b)
        C's faction is real (slot 7) and is P's  -> green
        otherwise                                -> yellow (kb, kb, 0.3b)
    both entries take it; a = 1

- The 0.3 is the double at `0x160A3E8` (0.30000001); the yellow and green stores are at `0x8668A8`-`0x8668BA` and
  `0x86693F`-`0x866951`.
- Bytes at b = 1: green (76, 178, 76) or (76, 255, 76); red (178, 76, 76) or (255, 76, 76); yellow (178, 178, 76)
  or (255, 255, 76). At b = 0.5: 38 for 0.3b, 89 or 127 for kb.
- "Real faction" is CFaction's slot 7: `ReturnTrue` in CFaction's table (VA `0x15C2430`) and `ReturnFalse` in the
  null faction's (`0x15C248C`). So **a plain alliance does not count**: an ally outside the player's faction is
  yellow, and so is any country when the player is in no faction.
- The red test is `CCountry::IsEnemyTag` inlined.
- Victory points show at any intelligence: a province never seen is drawn dim (b = 0.5), not hidden.
- The 0.999 compare in the loop only sets the colour's `opaque` byte, which never holds here.

**Tooltip part** (`0x49AFDA`): `"\n" + PROV_POINTS + ": " + victory points` ("Points: 5"). It is always added: no
intelligence test, and shown for 0 points and at sea.

## 4. Strength (mode 9)

`MapMode_Strength_ColourLoop` (`0x8646B0`, `ret 4`).

    a sea province (template +0x22 clear): skipped - its entries keep the last mode's colours
    b as for VP (intelligence 2; simulated)
    colour = (0.5b, 0.5b, 0.5b, 1)                       grey: 127 or 63
    if P's intelligence >= 2:
        T = 0
        for every unit on the province's list (+0x2B8) whose slot 15 (IsLand) is true:
            s = sum of its regiments' strength (CSubUnit +0x5C) / 1000
            intelligence 2:      w = 1.0                                      a count
            intelligence 3-5:    w = s * 0.01 * ((unit id +0x14) mod 37 + 15)  15 to 51, fixed by the id
            intelligence 6-7:    w = s * 0.01 * GetAverageOrganisation / 1000
            intelligence 8-9:    w = s * 0.01 * org * (GetAverageExperience / 1000 + 1.0)
            T += w
        if T > 0:
            k = min(T, 500) / 500 * 0.5 + 0.5                0.5 to 1.0
            C = the controller's country
            CCountry::IsFriend(C, P, false)  -> green (0.3b, kb, 0.3b)
            CCountry::IsEnemyTag(C, P)       -> red   (kb, 0.3b, 0.3b)
            otherwise                        -> blue  (0.3b, 0.3b, kb)
    both entries take it; a = 1

- **Everybody's land units count, whoever owns them; the hue is the controller's.** An enemy stack standing in the
  player's own province makes it a brighter green. Fleets and air units in the province do not count.
- The scale is the original's [exe]. 500 and the 0.01 are constants. TFH's infantry brigade is `max_strength = 30`
  and `default_organisation = 30` [mod], and experience runs 0 to 100. So at intelligence 6 a full three-brigade
  division weighs about 27, and the bright end (500) needs about eighteen. At 8 and above, experience multiplies by
  up to 101, so any veteran stack saturates. The player's own provinces are intelligence 9.
- The stand-in at intelligence 3 to 5 is deterministic: the same unit always shows the same weight.
- IsFriend is true for: the country itself; an overlord or puppet; the same overlord; the same real faction; an
  alliance; or co-belligerence without enmity (its record).
- The colours for the sea entries are stale but never drawn: style 15 leaves the sea plain. *Inferred* from the
  water's colour test.

**Tooltip part**: none. Mode 9 is `0x49CBAE` in the jump table at VA `0x49DCA4`, the "no mode lines" exit, as are 12
and 14-16.

## 5. Resources (mode 10)

**The colouring** - `MapMode_Resources_ColourLoop` (`0x8660E0`, `ret 4`):

    b as for VP; i = P's intelligence (0 where the array is too short)
    first = (0.9b, 0.9b, 0.9b)                                     grey
    if _MODIFIER_IC_ (+0x114 -> +0x78, entry 15) > 0:
        v = min(IC / 1000 / 10 * 0.5 + 0.5, 1.0);  v = 0.5 if i < 1
        first = (0.3b, vb, 0.3b)                                   green by the province's IC
    second = first
    if the strategic resource (+0x18) is set and its slot 14 is true (a real one):
        C = the controller's country
        CCountry::GetsStrategicResourcesFrom(player, state, C) -> second = (63, 108, 255)  blue
        else CCountry::IsEnemyTag(C, P)                        -> second = (255, 39, 39)   red
        else                                                   -> second = (255, 216, 0)   yellow
        if there was no IC: first = second
    entry +0 = first, +4 = second; a = 1

- The three resource colours are the floats 0.247059/0.423529/1, 1/0.152941/0.152941 and 1/0.847059/0, exact
  byte fractions, and **are not dimmed by intelligence**.
- **So a province with industry and a strategic resource is striped** green and the resource colour. One with only
  the resource is solid in it. Everything else is grey or IC green. A green province is lighter the more IC it has,
  up to 10.
- Blue means "the player is given this province's strategic resources". That is the daily rule
  (`FINDINGS-strategicresources` reading in the record): the same country; no war; a major, or a country with IC
  above 100, in the same real faction - or a faction leader at war whose faction the holder is near; and the two
  connected by continent or by sea.
- Slot 14 is `ReturnTrue` in CStrategicResource's table (VA `0x15BC87C`) and `ReturnFalse` in
  CNullStrategicResource's (`0x15BC8BC`), read directly.

**The icons.** `UpdateProvinceResourcePictures` (`0x869FD0`) is run once, by `CInGameIdler::Enter`, and makes:
- `resource_oil`, `_metal`, `_energy`, `_raremat` for each good whose `max_producing` is above 0, at the position of
  the 3rd to 6th building of buildings.txt;
- `STRATEGIC_<key>` on the province's label point.

`FINDINGS-resourceicons.md` has where they stand; `FINDINGS-billboardfx.md` how a billboard is drawn. New here:
- **Both kinds go into the graphics owner's layer +0x17CC**: added at `0x6422BD` and `0x6424D5`, removed through
  `0xA6FBC0` at `0x64240D`.
- That layer is the **object group at WaterObject +0x70**: the CProvinceManager constructor's 12th stack argument,
  stored at `0x84F606`.
- `MapObjects_UpdateLayerVisibility` sets that group's visible byte to **GameSettings +0xE7** each frame
  (`0x85BC41`) while the camera is under 500.0, and to 0 from 500 up [exe].
- Only the resources setter writes +0xE7 = 1. So **the icons exist all game and are drawn only in this mode, and
  only near**. They are not hidden by the layer mask.
- Because they are made once, a resource gained or lost in play changes no icon until the next session (one direct
  caller each of `0x869FD0`, `0x642010` and `0x6423C0`; positive control: findRefs found each one).
- Each is drawn at frame 0 and draw scale 1, a square 2 × `scale` across: TFH's `resource_*` scale 2.5 and
  `STRATEGIC_*` scale 3 [mod: interface/mapitems.gfx].
- The four goods' icons are translated (slot 33) **before** `ProvinceGraphics_PlacePicture` hangs them, so they
  stand at (building x, 1.0, building y). Their `building_nudge` height is added by a SetLocal **after** the world
  transform was computed, so on `FINDINGS-billboardfx.md`'s reading it never reaches the screen (*inferred*).
- The `STRATEGIC_*` entries write `texturefile` in lower case. Keyword tokens are case-insensitive
  (`FINDINGS-effectgrammar.md`), so they have their textures (*likely*).
- **Building pictures stay on in this mode** (mask bit 0x20 is kept), so a built fort is drawn on the icon that
  shares its point (`FINDINGS-resourceicons.md`).

**Tooltip part** (`0x49BA59`):

    if P's intelligence >= 1:
        for g in metal, energy, rare materials, crude oil (goods 4, 5, 6, 3), where max_producing[g] > 0:
            "\n" + GoodName(g) + ": " + FormatFloat(current_producing[g] / 1000, 1) + "/" + FormatFloat(max / 1000, 1)
    at any intelligence, where the strategic resource is a real one:
        "\n§G" + its localised key + "§W"

GoodName is `METAL_IRO`, `ENERGY_IRO`, `RAREMAT_IRO`, `CRUDE_OIL_IRO` ("Metal", "Energy", "Rare Materials", "Crude
Oil"). FormatFloat is `%.1f`, rounded. Crude oil comes **last**.

## 6. What the layer mask hides in these modes

The console's `render` command (`0x441A0E`) prints the mask bits by name: 0x1 Trees, 0x2 Borders, 0x8 Text, 0x10
Overlay, 0x20 Objects, 0x40 MapObjects, 0x80 Rivers, 0x100 Water, 0x200 WaterBorders, 0x400 Effects. 0x4 and 0x800
are not printed; 0x800 is the counters.

- **Infrastructure, VP and Strength (0xFFBA)**: off are Trees (0x1), 0x4 and MapObjects (0x40). Everything else is
  on: borders, province names, the 0x10 groups, building pictures, rivers, water, sea borders, effects, counters.
- **Resources (0xFFAA)**: also off is **Overlay (0x10)**, which shows the object groups at WaterObject +0x48 (the
  owner's layer +0x5FC) and +0x4C (+0x778, also only under counter_distance). `CUnit::OnSelected` makes its +0x168
  object in +0x778, and `CUnit::OnDeselected` adds to +0x5FC: by all appearance a selected unit's markers. Their
  contents were not read.
- Bit 0x4 gates, at `0x6418ED` and `0x641B31`, a pass also gated on GameSettings +0x58 and the graphics' +0x6BC4C,
  which calls `0x85BB60` (not read).
- A sweep for every `and R, [X+0xEC|0xF0]` (9 sites) found a test of **0x40** only in the console. That sweep did
  find the 0x10, 0x20, 0x800, 0x1, 0x2, 0x8, 0x80, 0x100 and 0x200 tests, so it can see such a test. A reader that
  takes +0xF0 without the AND would escape it.

None of the four modes draws a figure or an icon of its own on the map besides the resource icons. The province
names (Text) and, in the far view, the country names (style ≠ 0) are drawn in all four.

The CProvinceManager constructor's object groups, from its arguments (`0x84F5C7`..`0x84F609`), as offsets into the
graphics owner:

| WaterObject | owner | what |
| --- | --- | --- |
| +0x44 | +0xC | under height 150 |
| +0x48 | +0x5FC | mask 0x10 |
| +0x4C | +0x778 | mask 0x10, under counter_distance |
| +0x50 | +0xEE4 | |
| +0x54 | +0xD68 | |
| +0x58 | +0x1C40 | |
| +0x5C | +0x1358 | building pictures; mask 0x20, under 500 |
| +0x60 | +0x14D4 | large and event icons; any mask |
| +0x64 | +0x1650 | weather pictures; mask 0x20, weather mode |
| +0x68 | +0xA70 | the far battle marker's layer |
| +0x6C | +0xBEC | the near battle marker's layer |
| +0x70 | +0x17CC | **resource icons**; GameSettings +0xE7, under 500 |
| +0x74 | +0x1948 | |

## Not established

- What the bit 0x4 pass draws (`0x6418B0`, `0x85BB60`, GameSettings +0x58), and what the Overlay groups +0x48 and
  +0x4C hold.
- Whether anything reads mask bit 0x40 other than the console.
- Whether `0x7415E0` is the air orders view's destructor with `PopMapMode` inlined.
- A writer of the map mode table by an idiom the sweep could not see (section 1, *likely*).
- Whether the province graphics, and so the resource icons, are ever remade after `CInGameIdler::Enter`.
- That the `building_nudge` height never reaches a resource icon (rests on `FINDINGS-billboardfx.md`'s open point).
- **A lead, out of this reading's scope**: `CStrategicResourceEffect::GetText` (rva `0x5BDA70`) writes
  `EFF_NO_MORE_RES` where the resource's slot 14 is **true**. Its record calls that the null resource, but the tables
  say slot 14 is true for a real one. Either the effect's +0x20 is not what it seems, or the original's text is
  backwards. Worth one read.

Frontier: 0x6418B0, 0x45BB60, 0x7415E0, 0x441A0E
