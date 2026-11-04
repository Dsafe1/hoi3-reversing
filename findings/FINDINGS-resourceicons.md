# Where the map's resource icons stand

*Read 2026-11-04 for BlackICE's `tools/placeResourceIcons.py`, after a redo of the mod's province
resources left many icons on top of one another. Static reading only; nothing was provoked in a
running game.*

**Synopsis.** positions.txt has no key for a resource icon, and the engine has no point of its
own for one. The four icons of crude oil, metal, energy and rare materials are drawn at **a
building's position**: the building whose slot in the building database is the good's slot in
the goods pool. With slot 0 the engine's own `nobuilding`, that is the 3rd to 6th building of
`common/buildings.txt`. Vanilla's order put them on `coastal_fort`, `land_fort`, `anti_air` and
`radar_station`, all of which its positions.txt declares. BlackICE's inserts `beach_defence` and
`fortress` before them, which moves the goods onto `coastal_fort`, `beach_defence`, `land_fort` and
`fortress`. BlackICE's file declares the second and third of these for 0 and 165 provinces, and
an undeclared building position is (0, 0). The strategic resource icon (`STRATEGIC_` + name) is
given no position, so it stands on the province's label point.

## 1. Who makes them

| rva | | |
| --- | --- | --- |
| `0x469FD0` | `UpdateProvinceResourcePictures` | every province from 1: the two below. `ret 4` |
| `0x242010` | `ProvinceGraphics_UpdateResourcePictures` | the four goods' icons. `ret 0xC` |
| `0x2423C0` | `ProvinceGraphics_UpdateStrategicResourcePicture` | the strategic resource's. `ret 0xC` |

`0x469FD0` has one direct caller, `CInGameIdler::Enter` at `0x65C02E`, so the icons are made as a
session comes up, from what the provinces produce at that moment. For each index i from 1 below
the count of the vector at its argument's `+0x2C`/`+0x30`, it passes the vector's entry i (the
province graphics), `g_CCurrentGameState +0xB8C`[i] (the province) and `[0x1A855FC]` to
`0x242010`, then the same three to `0x2423C0`.

## 2. The four goods - `0x242010`

Stack arguments: the province graphics at `[ebp+8]`, the province at `[ebp+0xC]` and the owner at
`[ebp+0x10]`. ECX is not read, so the convention is `__stdcall`.

1. The province graphics' vector at `+0x50`/`+0x54` is sized to 7 nulls on first use
   (`0x642044..0x6420AD`): one picture per good.
2. Nothing more where the template (`+0xD4`) has `+0x13D` clear (`0x6420B8`).
3. For g = 0..6, the goods table at VA `0x170CF50` with stride `0x1C` (`0x6420CA`, the bound
   `0x170D014` at `0x642396`): any old picture is taken down. **Only g = 3, 4, 5, 6 go on**
   (`cmp ebx,3/4/5/6` at `0x64210C..0x64211E`), and only where `province +0x294 + 4g > 0`
   (`0x642127`). That is `max_producing` (`+0x28C`, a `CGoodsPool` whose goods start at `+8`). The
   table is in pool order: supplies, fuel, money, oil, metal, energy, raremat
   (`FINDINGS-tradeui.md`), and the four are crude oil, metal, energy and rare materials.
4. The name is `resource_` (VA `0x15CD648`) + the table's key, so `resource_oil`,
   `resource_metal`, `resource_energy` and `resource_raremat`: the four billboards of
   `interface/mapitems.gfx`.
5. **The building is `g_CBuildingDataBase +0xC`[g]** (`mov edx,[eax+0xc]; mov ebx,[edx+ebx*4]`
   at `0x6421E4`/`0x6421EA`). That is the database's vector, not the province's buildings, and its
   entry 0 is `nobuilding` (`FINDINGS-mapmode.md`, `FINDINGS-provinceview.md`).
6. The position is `template +0x258`[building `+0x54`] **less the label point** (`+0x5C`/`+0x60`,
   converted from int): `0x642220..0x64228C`, as (x - label_x, 0, y - label_y). It goes to the
   picture through slot 33 (`+0x84`, `0x6422CA`), which `FINDINGS-airmap.md` reads as placing
   against the label point. The building's nudge (`template +0x268`[index]) is added to the
   transform's float 13, the height (`0x642319..0x642337`). Then `ProvinceGraphics_PlacePicture`
   with `raise` 1 where the province has an anchor (`owner +0x1DF0`[id], `0x6422E3`).

**So a resource icon and its building's picture stand on one point.**
`ProvinceGraphics_UpdatePictures` (`0x23F790`) places the building at the same
`+0x258[index]` less the label point, raised by the same nudge. A built coastal fort in a province
producing oil is drawn on the oil icon, in vanilla and here alike.

## 3. The strategic resource - `0x2423C0`

Same three arguments, the same convention. Any picture at the province graphics' `+0x9C` is taken
down. Where the template has `+0x13D` set, the province has a strategic resource (`+0x18`, not
null) and the resource's slot 14 answers true (`0x642447`), a billboard is made: `STRATEGIC_`
(VA `0x15CD654`) + the resource's key (`+0x30`), shown through slot 13 (`+0x34`), hung with
`ProvinceGraphics_PlacePicture` (raise 1) and kept at `+0x9C`. **No position is given**: there is
no slot 33 call, unlike the four goods. So the icon stands on the anchor, which is the label point
(`inferred` from that absence). The label point is the bounding box's middle,
`min + (max - min + 1) / 2` (`FINDINGS-weathersim.md`, B.9), and nothing in positions.txt moves
it.

## 4. What an undeclared position is

`CProvinceTemplate::CProvinceTemplate` pushes one `CMapPoint` `{vftable, 0x18D, 0.0, 0.0}` per
building type (`FINDINGS-mappoint.md`, section 4). `CMap::ComputeProvinceGeometry`'s resize finds
the length already right and writes nothing (`0x4919E5..0x491AAB`, read again for this). Only
`CMap::LoadBuildingPositions` writes a point, and only for a key the file declares. A scan of every
`.text` instruction addressing `+0x258` found one other store of a point, at `0x29C38B`, inside the
in-game nudge editor (`nudge_warning`, `nudge_x`, `nudge_z` beside it). **So an undeclared point is
(0, 0)**, and an icon placed there is put at (-label_x, -label_y) from its province's anchor: the
map's south-west corner, nowhere near the province (`inferred`: not seen on screen).

## 5. The four keys, by buildings.txt

| good | slot | vanilla (TFH) | declared there | BlackICE | declared there |
| --- | --- | --- | --- | --- | --- |
| crude oil | 3 | `coastal_fort` | 2441 | `coastal_fort` | 2443 |
| metal | 4 | `land_fort` | 10602 | `beach_defence` | **0** |
| energy | 5 | `anti_air` | 10607 | `land_fort` | **165** |
| rare materials | 6 | `radar_station` | 10591 | `fortress` | 10602 |

Counts are blocks in each positions.txt, 2026-11-04. BlackICE's 10602 `fortress` points match TFH's
10602 `land_fort` points in number, which suggests the key was renamed in the file at some point.
`onmap` in BlackICE: `coastal_fort`, `land_fort` and `fortress` yes, `beach_defence` no. So metal is
the only good whose point no building picture shares.

Which building carries which good is the engine's (**hardcoded** by slot). The building order is
the mod's (`common/buildings.txt`; its own comments warn that event OOBs depend on it), and the
points are the mod's (`map/positions.txt`).

## 6. Not established

- **The icon's size in map pixels.** A billboard's `scale` (2 for the resource icons, 1.5 for
  buildings) was not followed into the renderer. The script spaces icons by measuring vanilla's
  hand-placed building points instead (median nearest neighbour 3.5 px, a quarter under 2.8).
- **Whether `0x469FD0` runs again after a session starts**, which decides whether a good gained in
  play gets an icon. Only direct calls were searched: one.
- **Whether the strategic icon's local transform is the identity** before `PlacePicture`, rather
  than set inside the billboard factory (`0x9C7D60`'s slot 18). Not read.
