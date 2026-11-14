# FINDINGS-citypoint.md: what a province's `city` point is for

*Read 2026-11-14, statically, by the `citypoint` agent for OpenHOI3; the city point's read (VA `0x63F814`) and the call of
`CCountry::GetActingCapitalLocation` (VA `0x63F912`) in ProvinceGraphics_UpdatePictures checked off the listing by the
collecting session. Addresses are rvas unless marked VA. Everything is `confirmed` unless marked otherwise.*

## 1. The question

`positions.txt` gives a province a `city = { x y }` point beside `unit`, `text_position` and `building_position`.
CMap::LoadPositionsFile (0x8FBB0) writes it, as two floats, to CProvinceTemplate +0x4C/+0x50 (token 0x2A2), and
CMap::ComputeProvinceGeometry (0x917A0) gives every province the default ((float)label_x, (float)label_y) - the plain
bounding-box centre, with none of the 2.0 the name's point has (`FINDINGS-provincenamepoint.md`). Nothing had recorded a
reader. OpenHOI3 asked what is drawn there, what else reads it, and its default.

**The answer: the `capital` marker of `interface/mapitems.gfx` stands there, on the owner's acting capital, and nothing
else in a normal game reads the point.**

## 2. The search for readers

Three scans over `.text`, each split on int3 runs and decoded with capstone resumed past every stop:

- **a float or integer read of `[reg+0x4C]` followed within 14 instructions by a read of `[same reg+0x50]`**, any
  register but esp and ebp: 90 hits. Read one by one, the ones on a CProvinceTemplate are CProvinceTemplate::Save
  (VA 0x4AA32B, 0x4AA877) and **ProvinceGraphics_UpdatePictures (VA 0x63F814)**; the rest are other classes - commands'
  Clone and LoadKey, orders, CRT and D3DX code, a vertex buffer in MapObjects_RebuildTileStrips (VA 0x862A56), a counter's
  three floats in CProvinceTemplate::MoveUnitCounter (VA 0x4AC430, `+0x4C/+0x50/+0x54` of the counter object), the
  ProvinceMapText origin in ProvinceTexts_Update (VA 0x8562A5, `+0x4C/+0x50/+0x54` of the text entry), a CMapProvince in
  CSupply::SpreadFromDepot (VA 0x689C5F) and an integer pair compared with 0x1268 in MapMode_Naval_Colour (VA 0x8676E1).
- **a float read of `[reg+0x4C]` anywhere in an int3-delimited piece that also reads `+0x50` as a float and touches one of
  the template's other fields** (+0x5C, +0x60, +0x64, +0x68, +0x7C, +0x13D, or CMap +0x2A60): the same two template
  readers, ProvinceTexts_Update (the text entry, as above), and one more piece, VA 0x69F310 (section 4).
- **a getter**: `lea eax, [ecx+0x44]; ret` and `lea eax, [ecx+0x4C]; ret`, and 8-byte `movq`/`movsd` loads of
  `[reg+0x4C]`. The one `lea [ecx+0x44]; ret` (VA 0x791460) is CTableLedgerItem's slot 3 (vtable.py --holding), not the
  template; the one `movq` is in AirBaseCircleGroups_PushBack's piece and not the template.

The positive control is that the first scan finds CProvinceTemplate::Save's two known reads of the point (VA 0x4AA32B,
`cvttss2si` of +0x4C and +0x50, the "write city where it differs" test of `FINDINGS-provincenamepoint.md` section 3).
What would show the negative wrong: a reader that reaches +0x4C through the embedded CMapPoint at +0x44 by a call that is
not a plain `lea`/`ret` getter, or one that reads the x half alone with no +0x50 near it. Neither form was searched for
exhaustively.

## 3. The capital marker

**ProvinceGraphics_UpdatePictures** (0x23F790, `(province graphics, province, graphics owner, country)`, `ret 0x10`),
read whole on the decompilation and checked on the listing at VA 0x63F7B2..0x63F954. `g` is the province graphics, `t`
its template (`g +8`), `p` the province:

    if (!t->simulated (+0x13D) || t->pictures_stale (+0x20)) and g's capital picture (+0x34) exists:
        hide it (slot 14), destroy it out of the owner's group +0x1358, g +0x34 = 0
    if t->simulated and g +0x34 is 0:
        v = ((double)t->city_x - (float)t->label_x,  0,  (double)t->city_y - (float)t->label_y)    ; each narrowed to float
        g +0x34 = a new billboard of the type named "capital", added to the owner's group +0x1358 (slot 4)
        Translate(v) (slot 33), then ProvinceGraphics_PlacePicture(anchor, owner, picture, raise = true)
    if g +0x34 exists:
        acting = CCountry::GetActingCapitalLocation(p->owner's country)
        shown and p != acting  -> hide (slot 14)
        hidden and p == acting -> show (slot 13)

The vector is computed in double: `cvtdq2ps` of the label, widened, subtracted from the widened city, narrowed
(VA 0x63F80A..0x63F84B). The anchor is the province's tile-local label point, and PlacePicture raises the picture by 1.0
(`FINDINGS-billboardfx.md`, section 3), so **the marker stands at the city point, (city_x, 1.0, city_y)**, as a building's
picture stands at its building position. It takes the billboard type's own `scale` (2.5 in Their Finest Hour, 1.5 in
BlackICE), frame 0, rotation 0, and is drawn in the same group as the buildings' pictures, WaterObject group +0x5C.

So every simulated province carries one capital picture, made once, and **it is shown exactly where the province is the
acting capital of its owner**. Not its controller: an occupied capital still shows its owner's marker, and a government
in exile sitting in a host's province shows nothing there, the province's owner being the host. **No test of what the
viewer knows** - the buildings' intel test (`FINDINGS-seaair.md` section 6) is below this, for the buildings alone.

**When it runs.** ProvinceGraphics_Update (0x23EF30), every frame for every province graphics entry: where the template is
simulated and the province has a controller (CMapProvince +0x338) and an owner (+0x330), every 15th frame of the entry's
own counter (+0xA0, `inc` at VA 0x63F404, `% 15 == 0` at VA 0x63F531..0x63F541) it runs UpdatePortPicture,
UpdateAirBasePicture, 0x23FD30, UpdatePictures and 0x240450, and resets the counter; **after that test, on every frame,
whether the pass ran or not, it clears the template's +0x20** (VA 0x63F590). Where the province is not simulated or has
no owner or no controller, it destroys the capital picture (VA 0x63F5A7..0x63F5C9) and several others. So the marker
follows a change of acting capital within 15 frames.

**The hit test does not offer it.** The click test of a province's pictures (0x240F40) reads the large air and naval
base pictures and the counter and building pictures, and no `+0x34` of the province graphics: a click on the marker
goes through to whatever is under it.

**Template +0x20, `pictures_stale`.** Zeroed by the constructor (the word store at VA 0x4A92F4, with +0x21), set to 1
wherever an underground is built, dissolved or lost - CBuildingConstruction::Deliver, CBuildingDeployment::DeployAt,
CCgmSetUndergroundCommand::Execute, RunDailyUndergroundPass, Province_SetController - and cleared by
ProvinceGraphics_Update as above. UpdatePictures treats it as "throw every picture away and make it again" (the capital
and every building's). *Inferred*: since it is cleared on every frame and acted on only on the 15th, a flag set on
another frame never forces the remake - the pictures are made anyway where missing and destroyed where their building
went, so what the remake would add is not visible from here.

## 4. The map editor moves it

VA 0x69F310, one of the hidden map editor's nudge handlers in rva 0x29ED40..0x2A06BF that `FINDINGS-provincenamepoint.md`
and the ProvinceTexts_Refresh record already put down to the editor (*inferred*): on the selected template
(`[this+0x5F8]` less 8) it switches on a type at `[this+0x9C0]` - **1: city x += 0.1** (the double at VA 0x160A3C0),
nothing refreshed; 2: the unit point x += 1 (VA 0x160A248) with the hemisphere byte set again; 3: text_position x +=
0.3 (VA 0x160A3E8) and ProvinceTexts_Refresh's caller 0x241DE0; 4: the building position of the building at `[this+0xA84]` x += 0.1, with
`nudge_warning` for a naval base - and then writes `nudge_x`. `interface/nudge.gui` has the matching
`nudge_selection_city` / `nudge_type_city` checkbox. So `city` is one of the editor's five kinds of point, and the
`capital` picture is the only thing in a game that shows it. This function was not named or entered in the record.

## 5. The data

Their Finest Hour's `map/positions.txt` has **one** `city` block, on province 4644, Lisbon - Portugal's capital:
`city = { x=2541.856201 y=1475.007476 }`, against a bounding-box centre of (2541, 1478). So Portugal's marker stands 0.86
east and 3.0 south of where every other capital's stands relative to its centre (engine y counts north; the box is x
2535..2546, y 1474..1482). BlackICE's file has none. The base game's own `map/positions.txt` (the install's root, which
Their Finest Hour's `tfh/map` replaces) has one too, on a different province: 1964, London, `city = { x=2757 y=1726 }`,
two pixels south of its centre (2757, 1728); Their Finest Hour's London block has no `city`.

## 6. Hardcoded or mod-able

- **Which picture**: [mod: `interface/mapitems.gfx`, the `billboardType` named `capital`, its texture and `scale`]. The
  name `capital` is [exe].
- **Where**: [mod: `map/positions.txt` `city`], else the bounding-box centre [mod: `map/provinces.bmp`, `definition.csv`;
  the arithmetic exe]. The 1.0 raise is [exe].
- **On which province**: the owner's acting capital [exe the rule; mod: the history's `capital`, and what moves the
  acting capital].
- **Every 15th frame**: [exe].

## 7. Not established

- In what order a group's billboards are drawn, so whether a building's picture on the same point lies over the marker
  or under it. The capital picture of a province is made before its buildings' in the one call.
- What 0x23FD30 and 0x240450, the two other calls of the 15-frame pass, keep up to date.
- The live game was not used. A live read of Lisbon's template at +0x4C/+0x50 should give 2541.856201 and 1475.007476,
  and its province graphics' +0x34 a billboard shown while Lisbon is Portugal's acting capital.
