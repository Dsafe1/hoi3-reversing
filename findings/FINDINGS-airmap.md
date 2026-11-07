# The air map mode

Read statically out of `hoi3_tfh.exe` on 2026-10-11, for the rewrite's air map mode. Nothing here
was watched in a running game. Addresses are **rvas** against an image base of `0x400000`
unless a line says VA. Only valid for this build.

The mode is `mapmode_15`, the game's mode **18** (`FINDINGS-mapmode.md`). That file lists it as
taking "the generic path" of the colouring dispatch, which is true of the dispatch and nothing
else: the mode's setter colours the map itself (section 2). `FINDINGS-combatview.md`, section 14,
read its three battle icons first; section 4 here reads them again and corrects one test.

## 1. Turning it on, and what happens each day

**The setter** is `0x267EE0` (`MapMode_Air_Set`, the in-game idler in ECX, bare `ret`):

    unless the mode is already 18: the "click" sound
    UpdateAirMapIcons(province objects)              section 4 and 5
    UpdateAirBaseCircles(province objects)           section 6
    leaving the naval mode (19): its icons are taken down (0x46AA70, not read)
    the idler's mode (+0xD34) and CMap's (+0x2A90) = 18
    MapMode_ShowButton(15): every mapmode_N button to frame 1, mapmode_15 to frame 2
    the settings: +0xE7 = 0, the layer mask +0xF0 = 0xFF9A, the map style +0xF4 = 18
    the graphics owner's +0x60F8 = 0 (a word; not read)
    HideProvinceObjects98: each province object's picture at +0x98 is hidden (which picture
        that is was not read)
    MapMode_Air_Colour(province objects)             section 2
    Map_RefreshColourTextures(0), which also refills the sea's colours, because style 18 is one
        of the three that colour the sea (FINDINGS-mapmode.md)
    the graphics owner's +0x60DC = 1

**Each day** `CInGameIdler::DailyUpdate` calls `UpdateAirMapIcons` and then
`UpdateAirBaseCircles` while the mode is 18. **The colours are not redone each day.** They are
made by the setter, and again - each time with `Map_RefreshColourTextures(0)` after it - wherever
the mode is 18 and the unit is the player's (`CUnit +0x128` against the player's id):

- when an intercept or an air superiority order starts (`CAirInterceptOrder::Start`,
  `CAirPatrol::Start`, slot 13 of each);
- and when one is destroyed (`CAirInterceptOrder::~CAirInterceptOrder`, `0x18EA00`, and
  `CAirPatrol::~CAirPatrol`, `0x1983F0`) - **at the top of the destructor**, before the order is
  taken apart. Whether the unit still holds the dying order at that moment, and so whether its
  provinces are still coloured, was not read.

So the map follows the player's two kinds of fighter order as they are given and as they go, and
nothing else: an order's provinces falling out of range as its unit moves base, for instance, are
not looked at again until one of these happens.

**Leaving it.** `0x278A00` (`MapMode_SwitchIcons`, the new mode in EDI, the idler on the stack,
`ret 4`) is the third caller of both: given 18 it redoes the icons and the circles; given
anything else while the mode is 18 it takes down the province's five icons of sections 4 and 5
(`HideAirMapIcons`, `0x46A560`) and every circle (`ClearAirBaseCircles`, `0x46AC00`); given 19 it
puts the naval icons up (`0x46A6F0`). **Every other mode's setter calls `ClearAirBaseCircles`**
too - 27 call sites in all.

**When the selection changes.** `CInGameIdler::Update` (slot 1, every frame) tests the byte
`+0x1D3C`, and where it is set and the mode is 18 calls `UpdateAirBaseCircles` again, then clears
it. The circles depend on what is selected (section 6); the byte is what says it changed
(`inferred` from that use).

## 2. The colours

`MapMode_Air_Colour` (`0x4673B0`, the province objects on the stack, `ret 4`; its five callers are
in section 1). Each province has
the two colours every mode writes - the ground and the stripes (`FINDINGS-mapmode.md`, *The sea*)
- packed `0xAARRGGBB`:

    every province from 1:   both colours 0x80808080        grey, alpha 0x80
    for each unit of the map's country (CMap +0x2A88, the player) whose order is
    air_intercept (0x718) or air_superiority (0x6FA):
        for each province of the order's list (CAirOrder +0x44) that the order's slot 38
        (the range alone, FINDINGS-airorders.md) passes:
            intercept:        ground = 0x8058FF58 (green); the stripes too, where still grey
            air superiority:  stripes = 0x80FF5858 (red);  the ground too, where still grey

So **a province is green under an intercept, red under air superiority, striped green and red
under both, and grey otherwise** - whichever order came first, since each takes the other's
colour only where it is still grey. **Only those two orders colour anything**: a bombing
mission's provinces are as grey as the rest. **The sea is coloured too**, because the mode's
style is 18. Every colour has an alpha of 0x80; what the map's shaders make of a province
colour's alpha differs from technique to technique and was not followed.

## 3. The list of finished battles, and how long it keeps one

`FINDINGS-combat.md` has the entry: the hour the battle ended, its kind (1 land, 2 naval, 3 air,
4 ground bombing, 5 land bombing, 6 naval bombing), the province, and two country tags. What
fills the tags, now read:

- `CCombatHistoryEntry::CCombatHistoryEntry` takes each side's **first country of its list
  `+0x54`**, or writes `---` with id 0 where that list is empty.
- `CCombatant::AddUnit` adds a unit's owner to that list and to the second list `+0x64` where
  it is not there yet. **`CCombatant::RemoveUnit` rebuilds `+0x54` from the units left on the
  side**; `+0x64` is never taken from. `CCombatant::DetachAllUnits`, which ends a battle, empties
  the unit list and leaves `+0x54` as it is.
- So a side whose units were taken off it one by one - a beaten side, its units falling back -
  is `---`; a side still standing at the end keeps its countries, and so does a ground
  bombing's defender, on whose list `CreateCombat` puts the province's controller with no unit
  (`FINDINGS-bombing.md`, section 5) - **until a unit is taken off that side, which rebuilds the
  list from the units and drops the controller**.

**A week, and then it goes.** `CCombatHistory::Prune` (`0x2F830`, the history in ESI, bare
`ret`) is the first thing `CCombatManager::Tick` does, every hour, before any battle is fought:

    while the list is not empty and its first entry ended after now: take the first off
    while the list is not empty and its first entry ended before now - 168: take the first off

An entry is kept while it ended at most **168 hours** before the hour, so for seven days and an
hour after the hour it ended; the original's own tooltip says "during the past week" (section 7).
Only the front of the list is looked at, which is in the order the battles ended. A history with
its byte `+0x14` set marks an entry (`+0x30` = 1) instead of freeing it, which would loop forever
on the same entry; nothing was found setting that byte. The first loop is for a list holding an
hour still to come, as after loading an older game (`inferred`).

`FINDINGS-combat.md` had "keeping something like the last few days or the last N entries; which
of the two is not yet known". It is a week of hours.

## 4. The three battle icons

`UpdateAirMapIcons` (`0x46A1E0`) keeps three counts for every province. For each entry of kind 3
(an air battle) or 4, 5 or 6 (a bombing), at the entry's province, with P the player:

    ours  =  P controls the province (+0x338) or owns it (+0x330)
          or the entry's defender is P
          or the defender is a country (id not 0) other than REB, and
                 CCountry::IsSameSide(P, defender)
                 or P's diplomacy status with it has co_belligerent (+0x58) set
                    and CCountry::IsEnemyTag(P, defender) says no
    ours:                                   a bombing counts as "bombed us", an air battle as an air battle
    else, the attacker is P, or CCountry::CanOperateIn(P, attacker),
          or CCountry::IsEnemyTag(P, defender):
                                            a bombing counts as "bombed them", an air battle as an air battle
    else:                                   the entry is left out

**Corrected.** `FINDINGS-combatview.md`, section 14, read the fourth line as "exists and is no
enemy of the player's". The byte at `+0x58` is not the country's - it is P's diplomacy status
with the defender (`CCountry +0xE28`, by the defender's id), and `+0x58` there is
`co_belligerent`. `CCountry::CanOperateIn` asks the same byte.

Then for every province from 1 - **province 0 is skipped** - `ShowBombedUsIcon`,
`ShowBombedThemIcon` and `ShowAirBattleIcon` with its counts: each makes its billboard where its
count is above 0 and it has none, and takes it down where it has one and the count is below 1.

| count | billboard of `interface/mapitems.gfx` | kept at the province object's | vector to its slot 33 |
| --- | --- | --- | --- |
| bombed us | `air_bombed_us_icon` | `+0x60` | (0, 3, 3) |
| bombed them | `air_bombed_them_icon` | `+0x64` | (0, 3, -3) |
| air battles | `air_battle_icon` | `+0x68` | (3, 3, 0) |

**Slot 33 places a picture against its province's label point** (`inferred`: the large pictures
of section 5 are given the building's position less the label point through the same slot, with
a middle figure of 0). So the vector is east, up and north: the air battle stands 3 east of the
point, "bombed us" 3 north and "bombed them" 3 south, all three raised by 3. That the third
figure counts north is `inferred` from the building positions, whose y counts north. All three
are drawn at the type's `scale`, 3.5. *Whether the vector reaches the screen is open*: the slot 33 call comes after
ProvinceGraphics_PlacePicture has computed the world transform, and no later refresh was found
(`FINDINGS-billboardfx.md`, Not established).

**The counts are bytes, and signed.** Each is one `char` of a buffer of three to a province, and
read back sign-extended: 128 entries of one kind in a province within the week reads as below 1
and takes the icon down, and 256 reads as none. `confirmed` as the code is written; whether a
province ever gets so many in a week was not looked at.

## 5. The large air base and anti-aircraft pictures

`UpdateAirMapIcons` goes on, for every province from 1 whose template has `+0x13D` set (every
province, `FINDINGS-mapmode.md`):

    the player's intel of the province above 1:  n = the air base's built level (+0x20) / 1000,
                                                 m = the anti-aircraft's likewise
    otherwise:                                   n = 1 where it has an air base at all, else 0;
                                                 m the same of anti-aircraft
    ShowLargeAirBaseIcon(n)                      0x242960
    ShowLargeAntiAirIcon(m)                      0x242B40

Each, where its figure is above 0: makes, where there is none (at the province object's `+0x7C`,
and `+0x84`), the billboard `large_air_base` - or `large_anti_air` - placed through slot 33 at
the building's position (`CProvinceTemplate +0x258` by the building's index) less the label
point, at height 0 (*whether that reaches the screen is open*, as in section 4: `FINDINGS-billboardfx.md`, Not
established); the air base's frame is then set by `ProvinceGraphics_UpdateAirBasePicture`
(`FINDINGS-seaair.md`, section 6: frame 1 with an air unit at home). And every time, **its size:
the picture's `+0xB28` = (n - 1) x 0.2 + 1** - 1 for a level 1 base and 2.8 for a level 10.
Where the figure is below 1, the picture is taken down. `CMapProvince +0x308` is the
anti-aircraft building, as `CProvince +0x308` already was in the record.

**The level is the built one** (`+0x20`), not what works of it: a bombed air base keeps its size.
**A province the player knows little of shows a level 1 picture whatever is built**, as it shows
the ordinary building pictures by whether there is one.

**A click.** `ProvinceGraphics_HitTest` (`FINDINGS-seaair.md`, section 6) asks the large air base
picture first, before any counter, and a hit offers the air base - each click the next of the
player's units there. The layer mask `0xFF9A` has `0x800` set and `0x20` clear, and of the two
bits the hit test reads, `0x20` is the one that lets **an ordinary building's picture** be hit:
so in this mode the small building pictures cannot be clicked, and the large air base is how an
air unit at its base is picked. Whether the same bit hides the small pictures from view was not
read (`inferred` from the bit's name in the hit test only).

## 6. The circles of range round the player's air bases

`UpdateAirBaseCircles` (`0x46AD60`, the province objects on the stack, `ret 4`):

    ClearAirBaseCircles
    selected = some selected thing's slot 1 answers 2 - an air unit (a unit's slot 1 is
               0 for an army, 1 for a fleet, 2 for an air unit)
    for each province of the player's AirBases list (CCountry +0xD70) whose air base object
    (CMapProvince +0x54) has units:
        the base's units, sorted by range (InsertUnitByRange, 0x4DD3D0): the range of the
            unit's definition (CUnit +0xC8, CSubUnitDefinition +0x148), smallest first, a
            unit of equal range after those already there
        groups: going down that list, a unit whose range is within 100 (a tenth of a
            kilometre) of the group before's joins it - the group's range becomes the unit's,
            its strength and its most strength are added to, and it is "selected" where any
            unit of it is (CUnit +0x4); else it starts a group of its own
            strength      = the sum of its regiments' strength (CSubUnit +0x5C)
            most strength = CUnit::GetTotalMaxStrength (slot 23)
        for each group:
            share = (strength / 1000) / (most strength / 1000), in single precision
            a CAreaCircleObject: its colour, a CColor at +0x148 (vftable, token 0x18D,
                then r, g, b, a) = (share, share, share, a), with
                a = 0.3 where an air unit is selected and none of the group's is, else 1;
                its byte +0x160 = share above 0.999, where a is 1 (else 0)
            its radius (slot 39) = range / 1000 x 0.25
            added to the graphics owner's layer +0x14D4 and shown; moved by the air base's
                position less the label point and hung on the province's anchor 1.0 higher
                (section 8)

**The radius is a quarter of the range in kilometres**, the same scale the range test uses: a
distance between provinces is four times the pixels (`FINDINGS-seaair.md`, section 4), so a range
of R reaches R / 4 pixels, which is the circle's radius in map units.

**How a circle is drawn** (`CAreaCircleObject`, slots 10 and 39, and `gfx/FX/circle.fx`). Slot 39
makes a square of four quarters, each from the centre out to the radius, each textured with the
whole of `map/Sector.dds` - a quarter disc whose centre is its corner, brightest at its rim and
fading inward; measured on the file, the rim is at 0.90 to 0.93 of the radius and gone by 0.95,
and it is empty inside 0.47 of it (section 8.2).
Slot 10 hands the shader `vStrength` = (share, a), from `+0x150` and `+0x15C`, and the shader
draws

    colour = red (1, 0, 0) to yellow (1, 1, 0) as the share goes 0 to 0.5,
             then yellow to green (0, 1, 0) as it goes 0.5 to 1
    alpha  = the texture x 0.3 x a

So **a ring for each range of aircraft at a base, green when its wings are full and red when they
are spent**, and the rings of other bases dimmed to a third while an air unit is selected. Nothing
reads the byte `+0x160` (section 8.5).

## 7. The tooltip

`ProvinceTooltip_Build`, branch for mode 18 (`0x9C3DE`). With P the player (`CCurrentGameState
+0xC30`):

    ours = P controls or owns the province
    for each entry of the list at this province:
        kind 3, and ours or CombatEntryConcerns(entry, P):         air battles + 1
        kind 4, 5 or 6, and ours or CombatEntryConcerns(entry, P): bombings + 1
    bombings above 0:     AIR_TOOLTIP_BOMBING with NUM = bombings, a line
    air battles above 0:  AIR_TOOLTIP_DOGFIGHT with NUM = air battles, a line

In Their Finest Hour: "There have been §Y$NUM$§W bombings in the province during the past
week." and "... air battles ...". **Bombings come first.**

`CombatEntryConcerns` (`0x32190`, `__cdecl` (entry, tag, id), returns a bool) is a test of its
own, not the icons':

    the attacker is P                                               yes
    the attacker is a country other than REB:
        IsSameSide(P, attacker)                                     yes
        co_belligerent with it, and IsEnemyTag(P, attacker) says no  yes
    the defender is P                                               yes
    IsEnemyTag(P, defender)                                         yes
    CanOperateIn(P, defender)                                       yes
    otherwise                                                       no

**It counts the same entries as the icons**, though it is written differently. Its attacker
clause is `CanOperateIn(P, attacker)` spelled out, which is the icons' second test; its
`CanOperateIn(P, defender)` is the icons' "ours" clause about the defender, condition for
condition; and the rest are the same tests in another order. With "ours" added for a province P
holds or owns, a battle the tooltip counts is one the icons count, as "ours" or as "theirs" - the
icons only sort them. Set side by side, not watched.

## 8. The rings through circle.fx, whole

*Read on 2026-11-07 by a delegated agent (fragment `interface-circlefx.json`), for a program that draws the rings through
the install's own `circle.fx`, fed as the original feeds it. Section 6 has who gets a ring and with what share; this is
everything from the `CAreaCircleObject` to the pixels. **[exe]** a figure of the executable, **[mod]** one an install or a
mod can change.*

**Corrections, rather than additions**: `CAreaCircleObject::Draw` takes six stack values, not "two read, four
unidentified", and is typed; section 6's `0x18D` among the colour's figures is the CColor's persistence token, not a
component; and the byte `+0x160` has no reader (8.5, with a positive control).

### 8.1 The object

`UpdateAirBaseCircles` (`0x46AD60`), for each group of section 6:

    new 0x218; CAreaCircleObject::CAreaCircleObject(graphics)            0x1350
        C3dVisibleObject's constructor with no object type
        texture (+0x140) = the graphics' texture table entry for "map/Sector.dds"
        effect  (+0x144) = FxHandler_Register(<folder> + "/FX/circle.fx", key "circle")
                           - one ID3DXEffect for every ring; the file through PhysFS, the mod's first [mod]
    colour (+0x148, a CColor by value: vftable, token 0x18D, r, g, b, a) = (share, share, share, a)
    full (+0x160) = 0 where dimmed, else share > 0.999
    SetRadius(float(float(range / 1000.0) x 0.25))                      slot 39
    ObjectLayer_Add(graphics owner +0x14D4, circle)                      0x665720
    Show                                                                 slot 13
    C3dObject::Translate(air base position - label point, height 0)      slot 33, 0x65CD80
    ProvinceGraphics_PlacePicture(owner +0x1DF0[province], circle, raise 1)

`share` is computed in single precision with each division through double: `float(float(strength) / 1000.0) /
float(float(most) / 1000.0)`, then cast to float.

### 8.2 The vertices

`SetRadius` (`0x1720`) writes nine vertices of `{x, y, z, u, v}` at `+0x164`, stride 0x14 (**D3DFVF_XYZ | D3DFVF_TEX1** =
0x102 at the draw); y up, z north, r the radius:

| # | position | uv | | # | position | uv |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | (0, 0, 0) | (1, 1) | | 5 | (0, 0, -r) | (1, 0) |
| 1 | (0, 0, r) | (1, 0) | | 6 | (r, 0, -r) | (0, 0) |
| 2 | (-r, 0, r) | (0, 0) | | 7 | (r, 0, 0) | (0, 1) |
| 3 | (-r, 0, 0) | (0, 1) | | 8 | (r, 0, r) | (0, 0) |
| 4 | (-r, 0, -r) | (0, 0) | | | | |

The indices are a static list of 24 words at rva `0x1312310` (VA `0x1712310`), referenced once, by the draw: `3,2,1
3,1,0` (north-west), `0,1,8  0,8,7` (north-east), `4,3,0  4,0,5` (south-west), `5,0,7  5,7,6` (south-east) - **two
triangles a quarter, eight in all, clockwise seen from above** [exe]. So within every quarter **u = 1 − |x|/r and v = 1 −
|z|/r**: the texture is mirrored into each quarter, its corner (1, 1) - the bottom right of the image - at the centre.
SetRadius writes only where the new radius differs from `+0x138` (compared in double), so the constructor's SetRadius(0)
writes nothing and the real radius writes the vertices first.

**The texture, measured on the file**: `map/Sector.dds` is 1024 × 1024 luminance (L8) with 11 mips; measured from its
bottom-right corner as a share of the side it is 0 out to 0.47, rises to 254 at 0.92, and is 0 again by 0.96 - the
visible band runs from about half the radius to the rim, brightest at 0.92 r [mod: the file].

### 8.3 Where it stands

A land province's pictures hang on its **anchor**, the `CProvinceObject` at its province graphics entry's `+0x10`
(`ProvinceGraphics_Construct`, `0x23EBC0`); the map-graphics builder makes one per land province whose bounding box has a
width, with `CProvinceObject::CProvinceObject` (`0x477920`), which places it through `C3dObject::Translate` at
**(centre_x, 0, centre_y)** - the template's `+0x2C`/`+0x30`, height 0. A sea zone gets a `CProvinceWaterObject` at its
label point instead. `C3dObject::Translate` multiplies the local transform (`+0x54`, the identity at first) by a
translation, so the ring's local transform becomes translation (air base x − label x, 0, air base y − label y), the air
base's position being `CProvinceTemplate +0x258`[the air base building's `+0x54`] [mod: `map/positions.txt`
`building_position`]. `ProvinceGraphics_PlacePicture` with raise 1 adds 1.0 to the local transform's float 13 (`+0x88`),
sets the world transform (`+0x94`) = local × the anchor's world (`Matrix4x4_Multiply`, `0x44E450`), and relinks the ring
under the anchor. So the world transform is a pure translation:

    world row 3 = (centre_x + base_x - label_x,  1.0,  centre_y + base_y - label_y,  1)

`FINDINGS-weathersim.md`, B.9, reads the label point as a copy of the centre that nothing later changes; on that reading
**the ring is centred on the air base's building position, 1.0 above the ground plane** (`likely`: it rests on B.9 and on
the anchor's world being its own translation - its parent was not read). Where the province has no graphics entry,
PlacePicture is skipped and the ring stays under the layer's root, unraised, at the offset alone. Nothing makes a second
ring across the map's seam (`inferred` from its absence in UpdateAirBaseCircles).

### 8.4 The draw

The ring's layer is the graphics owner's `+0x14D4`, which is **WaterObject `+0x60`** (stored by the WaterObject
constructor, `0x84F570`); `MapObjects_UpdateLayerVisibility` makes it visible **whenever the layer mask is not 0, at every
camera height** (the air mode's mask is 0xFF9A) [exe]. `MapGraphics_DrawScene` draws its object groups in the order
`+0x5C`, `+0x70`, `+0x64`, `+0x60`, so **the rings come after the land, water, borders, trees, building pictures and
weather pictures**; the frame then calls `GraphicsOwner_DrawLayers` (`0x241950`), which draws the owner's own layers -
counters among them - over the rings; `+0x14D4` is not among those (`confirmed` from the call order, 0x25704B before
0x25716B).

`MapObjectGroup_Draw` (`0x6716D0`) first sets ALPHABLENDENABLE 1, SRCBLEND SRCALPHA and DESTBLEND INVSRCALPHA, the
device's VIEW and PROJECTION from the view, and stores the view at graphics `+0x6BC88`. For a ring - an object with no
type, so its slot 12 answers no mesh - it sets WORLD = `+0x94`, ZENABLE the opposite of the ring's byte `+0x135` (0, so on),
ALPHABLENDENABLE 1, and calls slot 10 with (graphics, device, &`+0x94`, slot 22's 0.0, and the stub's two zero arguments
left on the stack). `CAreaCircleObject::Draw` (`0x1950`) reads only the first two:

    effect = graphics +0x6BD00 [effect - 1]                    no null test
    SetMatrix("WorldMatrix",      this +0x94)
    SetMatrix("ViewMatrix",       view +0x1C object, slot 91)     the map camera's, as the device's VIEW
    SetMatrix("ProjectionMatrix", view +0x1C object, slot 93)     and PROJECTION
    SetFloatArray("vStrength", { colour.r (+0x150), colour.a (+0x15C) }, 2)
    SetTexture("SectorTex", the table's texture for +0x140)       null where -1 or above 9999
    Begin(&passes, 0)       flags 0: the effect saves and restores what it sets
    BeginPass(0)            the first pass only
    SetFVF(0x102)
    DrawIndexedPrimitiveUP(TRIANGLELIST, 0, 9, 8, indices, INDEX16, +0x164, 0x14)
    EndPass; End

**No technique is chosen**: neither the effect loader (`Fx_CreateEffectFromPath`) nor the draw calls SetTechnique, so the
current technique is D3DX's default for a new effect, which in `circle.fx` can only be its one technique, `Standard`
(`inferred` as to D3DX's default; settled for this file by its having one). Its pass sets **ZENABLE false, ZWRITEENABLE
false, ALPHABLENDENABLE true, ALPHATESTENABLE false** [mod], not the blend factors, so SRCALPHA / INVSRCALPHA from the
group draw apply (`likely`: other objects of the layer - the air map icons - draw before or after a ring in an order not
read). The sampler is CLAMP with LINEAR min/mag/mip [mod]. With the shader:

    t      = Sector.dds (luminance) at uv
    C      = red -> yellow as share goes 0 -> 0.5, yellow -> green as it goes 0.5 -> 1
    src    = (t x C, 0.3 x a x t)
    result = src.rgb x src.a + dest x (1 - src.a)
           = 0.3 a t^2 C + (1 - 0.3 a t) dest

### 8.5 The byte +0x160

**Nothing reads it.** The ring's own routines do not - constructor, slots 9, 10, 39, 40, `UpdateAirBaseCircles`,
`ClearAirBaseCircles` - and no inherited slot can, as C3dVisibleObject ends at 0x138, where the ring's own fields begin. A
scan of every `[reg+0x160]` byte access in the image finds the three writes (`0x4013F1`, `0x86B269`, `0x86B2D0`) - the
positive control - and byte reads only in unrelated functions walking vectors of other objects. The flag is written and
never used (`inferred`: a ring reached through a register the scan's window cannot follow would be missed).

## What was not read

- **The naval mode's icons** (`0x46A6F0`, `0x46AA70`).
- **What the province object's picture at `+0x98` is**, which the setter hides.
- **What the shaders make of a province colour's alpha** in style 18.
- **The order the rings are drawn in** among themselves and among the air map icons of the same
  layer: the layer's draw list (+0x14) is filled by code not read.
- **The anchor's parent**, and so whether a province's anchor's world transform is anything but its
  own translation; and whether the label point equals the bounding box's centre for every land province (B.9 of
  `FINDINGS-weathersim.md` against the record's `label_x`, which calls the pair "refined").
- **The fog and cull states** at the ring's draw, and how the texture table loads Sector.dds
  (0xA60F30); D3DX's default technique for an effect with several, which a mod's `circle.fx` could have.
- The words `+0x60F8` and `+0x60DC` of the graphics owner, `0x480DE0` and `0x4813C0` inside
  `Map_RefreshColourTextures`, and the settings byte `+0xE7`.
- `MapMode_ShowButton`'s first part, which resets an array of 0x24-byte entries at the graphics
  owner's `+0x1EF8` to -1 where the layer mask has `0x1` - which this mode's has not.
- Whether a beaten side's `---`, which carries the id 0, is ever taken for the country of id 0
  by `IsEnemyTag` or `CanOperateIn`.
