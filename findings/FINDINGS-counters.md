# Map counters: what one is made of, which units have one, and where it stands

Read statically out of `hoi3_tfh.exe` on 2026-10-09, for the rewrite's map. Addresses are
**VAs** unless a line says rva; `rva = VA - 0x400000`. Only valid for this build. Nothing here
was checked against a running game, and the last section says what was not read.

**In one line.** Every unit on the map owns a `CHoiAvatar`, which holds its 3D figure and
**two** counters - `unit_counter` for a far camera and `unit_counter_close` for a near one -
each a `CCounterObject` made from a `CounterType` of `interface/mapitems.gfx`. A counter is
one quad drawn by `gfx/FX/counter.fx` out of four textures and a colour, with a flag and two
short texts laid over the one on top of its stack. A province keeps **five stacks** of
counters, by what the units in them are doing, and **a fleet in port and a wing at its own
base have no counter at all**.

---

## 1. The declaration: `CCounterType`

`CCounterType::LoadKey` (`0x83B840`, already recorded) reads 18 keys. Where each lands, from
the loader for the strings and colours and from the draw routines for the rest:

| key | offset | used as |
| --- | --- | --- |
| `textureFile` | `+0xB4` (name), `+0xA4` (texture) | the shader's `BackgroundTex` |
| `textureFile2` | `+0xD0`, `+0xA8` | `MaskTex` |
| `textureFile3` | `+0xEC`, `+0xAC` | `SizeTex`, a strip of `noOfFrames` frames |
| `textureFile4` | `+0x124` (name), `+0xB0` (texture) | loaded, and read by nothing in the draw |
| `effectFile` | `+0x15C`, `+0xA0` | the shader |
| `noOfFrames` | `+0x194` | frames in `SizeTex`; `+0x198` is handed to the shader as `SizeOffset` |
| `scale` | `+0x9C` | half the counter's height, in map units |
| `level_scale` | `+0x1D0` | growth for each step of size, section 3 |
| `font` | `+0x178`, `+0x19C` | the font of the two texts |
| `size` | `+0x1D4` | the size of the first text |
| `offset` | `+0x1A0..+0x1A8` | where the flag goes |
| `offset2` | `+0x1AC..+0x1B4` | where the first text goes |
| `offset3` | `+0x1B8..+0x1C0` | where the second text goes |
| `shieldtype` | `+0x1CC` set, `+0x1C4`, `+0x1C8` | that there is a flag, and its width and height |
| `color1` | `+0x1D8` (a `CColor`; its four floats from `+0x1E0`) | selection colour 2 |
| `color2` | `+0x1F4` (floats from `+0x1FC`) | selection colour 3 |
| `delayAfterAttackColor` | `+0x210` | read, and used by nothing: the attack-delay corner is a static yellow (section 10.6) |

`confirmed` for the string, colour and `noOfFrames` rows, which are the loader's own stores;
`likely` for the float rows, which are named from the order the draw routines use them in and
from the comments beside them in the file (`# flag`, `# offensive-defensive`, `# commander`,
`# fontsize`).

`CCounterType` slot 18 (`0x83BB00`) is its `CreateInstance`: `new 0x1C0` and the
`CCounterObject` constructor.

## 2. The object: `CCounterObject`, 0x1C0 bytes

Constructor `0x838B60`. It makes the flag at once - a `CShield3dObject` of
`shieldtype.x * scale` by `shieldtype.y * scale` - and a `counter_arrow` billboard.

| offset | | |
| --- | --- | --- |
| `+0x138` | `type` | its `CCounterType` |
| `+0x148` | `size` | 0 to 5, the frame of the size strip; section 3 |
| `+0x14C` | `picture` | the texture of the unit type's picture |
| `+0x150` | `colour` | a `CColor`: the owner's |
| `+0x16C` | `shield` | the flag |
| `+0x170` | `figures` | a string, the first text |
| `+0x18C` | `name` | a string, the second text |
| `+0x1A8` | `order` | where it sorts in its stack, and how soon a click finds it |
| `+0x1AC` | `intel` | a copy of its unit's intel level, section 5 |
| `+0x1B0` | `selection` | a word: 0 none, 1 white, 2 `color1`, 3 `color2` |
| `+0x1B4` | `arrow` | the `counter_arrow` billboard |
| `+0x1B8` | `shows_arrow` | |
| `+0x1B9` | `is_top` | the one of its stack that draws its flag and texts |
| `+0x1BA` | `is_shown` | |
| `+0x1BB`, `+0x1BC`, `+0x1BD` | three marks | choose the second colour, below |

Slot 23 (`0x838B30`) sets `selection` and slot 94 (`0x838B50`) reads it.

**Drawing is deferred.** Slot 10 (`0x838E60`) draws nothing: where `is_shown` is set it
copies the matrix it is given, appends itself to a global vector (`0x1A8C224`..`0x1A8C22C`),
sets `is_top`, and draws its arrow if `shows_arrow`. `0x8396C0` then draws the whole vector in
three passes and empties it:

1. **every counter's quad**, `0x83BC80`, each with a D3DRS_DEPTHBIAS 0.0001 lower than the one before, so later is nearer (section 10.3);
2. **the flag** of each counter whose `is_top` is set and whose type has a `shieldtype`
   (`0x838F50`), at `offset * scale * 0.1 * s`;
3. **the texts** of each counter whose `is_top` is set (`0x839110`): `figures` at
   `offset2 * scale * 0.1 * s` in the size `size_key * scale * 0.1 * s`, and `name` at
   `offset3 * scale * 0.1 * s` in the size `3.5 * scale * 0.1 * s`.

`s` is the counter's own scale, section 3. So `offset`, `offset2` and `offset3` are in
tenths of `scale`, and a text's size too. `likely`: read in the decompiled C, the constants
`0.1` (`0x160A3C0`) and `3.5` (`0x160A528`) read from the image.

**The quad** (`0x83BC80`) is `gfx/FX/counter.fx`, which is plain text in the install, fed:

| shader value | from |
| --- | --- |
| `BackgroundTex`, `MaskTex`, `SizeTex` | the type's three textures |
| `CounterTex` | the object's `picture` |
| `SizeOffset` | the type's `+0x198` |
| `SizeFrame` | the object's `size`, as a float |
| `CountryColor` | the object's `colour` |
| `vOtherColor` | one of four fixed colours by the three marks: none; `+0x1BC` red `(1,0,0)`; else `+0x1BD` orange `(1,0.5,0)`; else `+0x1BB` yellow `(1,1,0)`; alpha 1 for each mark, (0,0,0,0) for none |
| `SelectionColor` | by `selection`: 1 white, 2 the type's `color1`, 3 its `color2` |
| `SelectionIntensity` | `0.5 + 0.5 * |sin(2t)|`, t the platform clock in seconds (section 10.4) |
| `Selected` | 1 or 0 |
| `CounterScale` | `s` |
| `WorldMatrix` | the camera's inverse view rotation with the counter's position, lifted by the camera's tilt, as its translation: the quad lies in the camera's right/up plane (section 10.4) |

What the shader does with them is in the file: the background's colour times the country's
where the mask's red is set; the unit picture over that by its alpha; the size strip's frame
over that by its alpha, sampled at `((u + SizeFrame) * SizeOffset, v)`; then the selection
colour through the mask's blue and green. The second colour replaces the country's in the
corner where `u + v > 1.6`, with a black line where `u + v` is between 1.57 and 1.6. **The three
marks are an attack delay (yellow), supplies or fuel under 5% (red) and an upgrade under way (orange), on the played
country's own units only** - section 10.6.

**The hit test** (`0x83C2B0`, reached from slot 20 at `0x839620`) takes the quad as
`scale * s` up and down and that times the background texture's width over its height left
and right, projected to the screen. So **a counter is `2 * scale * s` map units high**. A hit
answers `(order + 1) * 0.1 + 1`, a miss `-1`: the caller keeps the highest.

## 3. Size

`CUnit::GetCounterSize` (`0x5BD1C0`, a seven-way jump on `oob_level`, `CUnit +0x1F4`):

| `oob_level` | size | strip frame |
| --- | --- | --- |
| 0, a theatre | 5 | `XXXXXX` |
| 1, an army group | 4 | `XXXXX` |
| 2, an army | 3 | `XXXX` |
| 3, a corps | 2 | `XXX` |
| 4, a division | 1 with more than one brigade, else 0 | `XX` or `X` |
| 5 | 1 | `XX` |
| anything else | 0 | `X` |

`confirmed`, from the listing: `mov eax,5`, `4`, `3`, `2`, `xor eax,eax; cmp [ecx+0x40],1;
setg al`, `mov eax,1`, `xor eax,eax`. The record has level 5 as a fleet.

**A counter's scale is `s = (size - 1) * level_scale * g + 1`**, where `g` is a global
(`0x170AF84`) the settings' constructor sets to 1 beside `counter_scale`. `confirmed` off `CCounterObject_DrawBatch`'s
listing (section 10.3): `g` multiplies only the growth with rank, so `counter_scale` leaves a counter of size 1 - and
every near counter - as it is. With the
file's `level_scale = 0.20` on `unit_counter` a lone brigade is drawn at 0.8, a division at 1
and a theatre at 1.8; `unit_counter_close` gives no `level_scale` and every counter is 1.

## 4. The avatar, and what feeds the counters

`CHoiAvatar` (0x154 bytes, constructor `0x849B00`) is at `CUnit +0x164`. Its constructor
looks its three parts up by name and makes each: the figure (`+0x124`), `unit_counter_close`
(`+0x140`), `unit_counter` (`+0x13C`), and for a size above 1 a `Rank<size + 1>` object
(`+0x128`).

`CUnit::RebuildAvatar` (`0x5BDC70`) throws the avatar away and makes it again, then for each
of the two counters:

    colour   = the owner's colour (CCountry +0xC34)
    size     = CUnit::GetCounterSize
    picture  = the texture of the sprite "GFX_small_counter_<key>"   for unit_counter
                                         "GFX_map_counter_<key>"     for unit_counter_close

`<key>` (`0x5BDB60`) is **the type key of the unit's first brigade**, where the unit's intel
level (section 5) is 3 or more and it has a brigade; otherwise a static string whose bytes in
the file are empty and whose run-time value was not read - `interface/counters.gfx` declares
`GFX_map_counter_unknown` and `GFX_small_counter_unknown`, which is what it would be for.
`AddRegimentToUnit` does the same again when a brigade joins, which is what the record had
taken for a renaming of the unit.

Two texts follow:

- **`figures`** (`0x84AD10`): `"<a> - <b>"`, where `a` is the unit's slot 39 and `b` its
  slot 40, each written as `?` when negative. Both counters get it. The two slots are
  already in the record as `GetAttackValue` and `GetDefenceValue`:

  | | `a` | `b` |
  | --- | --- | --- |
  | land | `(soft_attack + hard_attack) / 6` | `(defensiveness + toughness) / 16` |
  | naval | `sea_attack / 25` | `sea_defence / 25` |
  | air | `air_attack / 10` | `air_defence / 10` |

  each off the unit's own definition (`CUnit +0xC8`, the sum of its brigades - and
  `FINDINGS-unitdef.md` has `toughness` counted twice in that sum), divided as whole
  thousandths, then rounded to a whole number and held to 9; and **-1 where the intel level
  is under 7**.
- **`name`** (`0x5BE500`, `0x84AEB0`), on `unit_counter_close` only: `???` where the intel
  level is under 5; else, with the `show_unit_names` setting (`CSettings +0xE9`) off, the
  name of the unit's leader if it has a real one and nothing if not; with it on, the unit's
  own name. Cut to its first 8 characters either way.

## 5. `CUnit +0x1F8` is the player's intel level on the unit

`CUnit::EnterProvince` writes it (`0x5BF2..`): 9 where the player is the observer the test at
`0x5D37D0` answers for, else `province->intel_by_country[player]`, and sets the unit's
"rebuild the avatar" byte (`+0x10C`) when it changes or the unit crosses between land and sea.
The record has that byte array as 0 unseen, 3 partial, 9 own. It gates four things, which is
what fixes its meaning:

| under | |
| --- | --- |
| 2 | the stack is not drawn at all |
| 3 | the stack draws one counter, and the picture is the unknown one |
| 5 | the name is `???` |
| 7 | the two figures are `?` |

`confirmed` for the write and the four comparisons; this replaces "what `[this+0x1F8]` holds
is not established" in the four `Get...Value` entries.

**The test for 9** is `CUnit_IsSeenAsOwnBy` (`0x5D37D0`, rva `0x1D37D0`; read on the listing 2026-11-07, for the map's
fog of war in OpenHOI3): the unit in EAX, the observer's `CCountryTag*` on the stack, `ret 4`, a bool in AL. True where
the unit's owner id (`CUnit +0x128`) is the observer's; else, where the owner's faction (`CCountry +0xD8`, never null)
answers its slot 7 true - a real faction, not the shared null one - and the observer's faction is the same object; else
where the owner's diplomatic status towards the observer (`CCountry +0xE28`[observer id]) has an alliance (`+0x14`). So:
its own units, its faction's and its allies'. No puppet, guarantee or war test. Eleven direct callers
(`findRefs.py --callers`), `CUnit_RefreshIntelLevel` (`0x5BAC63`) and `CUnit::EnterProvince` (`0x5BF23F`) among them; the
other nine were not read.

## 6. Which units have a counter, and the five stacks

`CProvinceTemplate` holds, for the province's map picture:

| offset | |
| --- | --- |
| `+0xCC` | five points of three floats, one per stack |
| `+0x108` | five `CCounterStack*`, made the first time one is needed |
| `+0x13C` | "the stacks want looking at" |
| `+0x140` | 5 x 7 pairs of (unit, flag): up to seven small flags per stack |
| `+0x278` | the intel level last given to a stack |

When a unit enters a province `CUnit::EnterProvince` calls `0x4AB880`, which **returns
without giving the unit a counter** where:

- the province is land and the unit is naval - **a fleet in port**;
- the province is land and the unit is a land unit whose slot 9 answers an object with
  `+0x300` set - `inferred`: aboard a fleet;
- the unit is an air unit and `CUnit_IsAtOwnBase` - **a wing at its own base**.

`EnterProvince` hides the avatar in the first and third cases and refreshes the province's
own map icon instead (`0x6400E0` for the port, `0x6402A0` for the air base), which is where
such units are shown. Otherwise the stack is:

| stack | |
| --- | --- |
| 4 | an air unit; or a land unit whose slot 9 object has `+0x304` set |
| 2, 3 | a unit in a combat (`combats_count > 0`): 2 where `0x5C5BA0` answers true, else 3 |
| 1 | a unit with provinces left to move through; or a land unit aboard something that has |
| 0 | every other |

`confirmed` for the order of the tests; which of 2 and 3 is the attacker was not read.
`0x4ABF00` does the same when a unit's state changes and moves its counter between stacks,
and `0x4ABD80` takes it out.

The counter that goes into a stack is **`unit_counter_close`**, the avatar's `+0x140`
(`0x839FA0`), and the avatar itself is put at the stack's point - `+0xCC`, `+0xD8` when
moving, `+0xFC` for an air unit.

**A `CCounterStack`** (0x158 bytes, constructor `0x839B60`) is a list of counters (`+0x138`,
count `+0x13C`) and a byte, `is_fanned` (`+0x154`). Its slot 10 (`0x839D20`) sorts the list
by `order` ascending (`0x83A6F0`, a merge sort whose comparison is `[a+0x1A8] < [b+0x1A8]`)
and draws **the last one, or the last six where `is_fanned`**: the first of them at the
stack's point raised by 2, each next one 0.3 further west and 0.3 further north. It clears
`is_top` on every one it draws and sets it on the last, so only the top counter of a stack
carries a flag and texts.

`0x4AC4C0` decides `is_fanned` and whether a stack shows, from the intel level of its
**first** counter: under 2 hidden, under 3 shown and not fanned, else shown and fanned.

## 7. Far and near

`CHoiAvatar` slot 92 (`0x849AF0`) sets its byte `+0x152`. Its hit test (slot 20,
`0x84A2F0`) reads the rest:

    if (+0x152):                       unit_counter, where it is shown
    else if (CSettings +0xF9):         unit_counter_close, where it is the top of a stack
    else:                              the figure

So `+0x152` is "seen from far away", and the near view is counters or figures by a setting.

**Only the top counter of a stack can be clicked**, by the middle line: a near counter
that is not the last of one of its province's five stacks is never asked. The maintainer's
account of the running game, 2026-10-09, agrees and adds what this routine does not show:
a click on a counter under the top one "goes through to the province", and clicking the
top one again and again "cycles through the units in the province". Where the cycling is
done was not read.
The settings' constructor (`0x45FA80`) gives `counter_distance` (`CSettings +0xFC`) **100**
and `counter_scale` (`+0x100`) 1. **Who calls slot 92, and what it compares with
`counter_distance`, was not found.**

## 8. Against a screenshot

The maintainer gave a screenshot of one near counter out of the running game on
2026-10-09: an armoured division showing `2 - 2` and the name `1. Panze`. The unit
picture's box, 34 by 24 texels of a 64 by 64 texture, is 83.5 by 58 pixels in it, so the
quad is 156 pixels and **one map unit is 31 pixels** there. Measured against that, from
the quad's middle, with the file's `unit_counter_close` numbers beside them:

| | read (sections 1 and 2) | measured |
| --- | --- | --- |
| the flag's middle | `offset * scale * 0.1` = 0.625 east, 1.25 south | 0.66 east, 1.29 south |
| the flag, inside its frame | `shieldtype * scale` = 1.125 by 0.75 | 1.15 by 0.76 |
| the left end of `figures` | 1.75 west | 1.75 west |
| the foot of its digits | 1.6 south | 1.59 south |
| the first letter of `name` | 1.45 east, 1.375 north | 1.56 east, 1.35 north |

So the three offsets are what section 1 took them for, **the third number of each is
north**, and four things follow that the reading did not give:

- **A text's place is the start of its baseline**, not its middle or its corner.
- **`name` is drawn turned a quarter turn**, running south from its place with the tops of
  its letters to the east. In the decompiled C of `0x839110` the second text's draw call
  is handed the same two direction vectors as the first's the other way round, one of
  them negated, which is a quarter turn; `likely`, the decompiler being loose there.
- **A text comes out about nine tenths of the size it is given.** `Arial_17_2` has a line
  of 18 and digits of 11. The digits are 0.615 map units high, where a line of
  `4.5 * 2.5 * 0.1` = 1.125 would make them 0.69; the name's capitals are 0.48, where a
  line of `3.5 * 2.5 * 0.1` = 0.875 would make them 0.53. Both fit a size that is 20 of
  the font's units. What the font's draw routine divides by was not read.
- **The flag has a dark frame** about two pixels wide outside the size `shieldtype` gives;
  presumably the `CShield3dObject`'s own, which was not read.

It also bears out section 4: the unit's own name, cut to eight characters, with
`show_unit_names` on - his settings file has `show_unit_names=yes`, and beside it
`counter_distance`, `counter_scale` and `render_hierarchy`, three of the keys
`FINDINGS-fieldmap.md` lists for `CMapRenderingOptions`.

`positions.txt` gives a province one `unit` point and nothing else for units (2754 `unit`
blocks in Their Finest Hour's), so the five points of section 6 are made from that one -
by `CProvinceTemplate::SetStackPoints`, read on 2026-10-10 (`FINDINGS-movement.md`,
section 9): the aircraft's point is the standing one.

## 9. The pointer beside a moving unit's counter

Read on 2026-10-09, after the maintainer's word that "in the original a moving unit also has
a small green pointer at all times", with a screenshot of one.

**It is the `counter_arrow` billboard each counter makes for itself** (section 2,
`CCounterObject +0x1B4`), declared in `interface/mapitems.gfx`:

    billboardType = {
        name = "counter_arrow"
        textureFile = "gfx\\mapitems\\counter_arrows.dds"
        scale = 1.0
        offset = 4.5
        noOfFrames = 2
    }

The texture is 64 by 32: two frames of 32, a green triangle and a red one, each pointing
**east** with its base to the west.

**When it shows.** `CUnit::ShowMoving` (`0x5C9E10`, `FINDINGS-movement.md`) sets
`shows_arrow` (`+0x1B8`) on both of the avatar's counters and the avatar's own byte `+0x150`,
and sets the arrow's frame to **0**, the green one, through `C3dVisibleObject::SetFrame`. It
is not asked whether the unit is selected: every unit with a path has one. What clears it,
and when the red frame is used, were not read.

**Which way it points.** `CUnit::FaceNextProvince` (`0x5CB520`, the unit in ESI) takes the
unit point of the province the unit is in and of the next of its path - slot 30, which is
`CProvinceTemplate +0x64/+0x68` - asks `0xC0BDBA` for the angle between them with the map's
width to wrap by, takes a quarter turn off, stores the result twice (`CUnit +0x104` and
`+0x108`) and hands it to the avatar's slot 37. `CHoiAvatar::SetRotation` (`0x84AC70`) gives
the same angle to the arrow of the far counter, to the arrow of the near one, and to the
figure. `CBillboardObject::SetRotation`, already recorded, stores `-(angle + pi/2)` at
`+0xB24`: the two quarter turns cancel and the billboard holds **the direction of travel,
negated**. `CUnit::SetHeading` (`0x5CB4F0`, the unit in EAX and the angle in XMM0) is the
same store and call with an angle given.

**Where it is drawn.** `CCounterObject::Render` copies the counter's own matrix to the arrow, calls the arrow's slot 39 with the counter's own
scale, and has it drawn. Slot 39 is C3dVisibleObject's SetScale, which writes +0xF4 and the local matrix. The draw
reads neither, so **the pointer is always drawn at scale 1** (`FINDINGS-billboardfx.md` 2).
`CBillboardType`'s slot 31 (`0xB076D0`) builds the quad's matrix:

    T = a translation of [type + 0xF8] along x
    R = D3DXMatrixRotationZ(the billboard's rotation)
    world = T * R * W, W = inverse(view) with _14 _24 _34 zeroed and its translation row the object's position

`D3DXMatrixMultiply(out, T, R)` at `0xB078B5` - translation first, rotation second - so the
picture is moved out along its own x and **then turned about the object's position**: it
stands `offset` away from the counter **in the direction it points**, and points away from
the counter. The shader is given `vXOffset` as the frame times one over `noOfFrames`,
`vScale`, and `vFlip`.

`CBillboardType::LoadKey` (`0xB071C0`, slot 4 of the table at VA 0x1605258) reads
`noOfFrames` to `+0xF0`, `font` to `+0x114`, `textureFile` to `+0x9C`, `effect` to `+0xB8`,
`effectFile` to `+0xD4` and `font_size` to `+0x104`, and hands `scale`, `offset` and
`offset2` to two list readers whose destinations the decompilation loses. `+0xF8` is `offset`, a single float, read by ParseFloat (`FINDINGS-billboardfx.md` 1); `scale` is +0x98 and
`offset2` +0x108.

### Against the screenshot

A division with its counter 73 pixels high, so about 14.6 pixels to a map unit. Measured by
the green pixels:

| | read | measured |
| --- | --- | --- |
| the pointer's own axis | the direction of travel | 29.7 degrees north of east |
| where it is from the counter's middle | in that same direction | 30 degrees north of east |
| how far | `offset` = 4.5 | about 5.1 |
| its length, base to tip | 28 of 32 texels of a square 2 across = 1.75 | about 1.7 |

The direction agrees to the degree, which is the orbit and not a fixed corner: a pointer
drawn at a fixed place and merely turned would not lie on the line it points along. The
distance is a seventh more than `offset` and that is **not explained** (one candidate, not checked: the batch lifts the
counter by the camera's tilt, section 10.3, and the arrow, drawn by `Render`, is not lifted); the counter's middle
was taken from its plate's edges, and where the counter's quad is drawn from the object's
position was not read.

**The same screenshot places the moving stack**: the division, setting off from a province
with a stack of five standing in it, lies 3.7 map units east and 0.5 north of that stack's
top counter. The top counter of a fanned stack is itself 0.3 west and north for each one
under it, which puts the moving point about **2.5 east and 1.5 north of the standing one** -
half a counter and a third of one. `inferred`: the count of the stack is read off its edges.

## 10. The quad through counter.fx, whole

*Read off the listing on 2026-11-07, every store and call, by a delegated agent (fragment `interface-counterfx.json`), for
a program that draws the counter through the install's own `counter.fx`. VAs as in the rest of this file; `confirmed`
except where a line says otherwise.*

**Corrections, rather than additions**: the "step nearer the camera" between counters is `D3DRS_DEPTHBIAS`, 0.0001 less a
counter; `SizeOffset` is `(w/P(w))/frames`, 0.125 for the 384-wide strip, not 1/6; `delayAfterAttackColor` is used by
nothing, the yellow being a static colour; `counter_scale` multiplies only the growth with rank; and CNavy's marks are the
land unit's three tests unchanged.

### 10.1 Who draws it, and when

`CCounterObject::Render` (slot 10) only queues the counter, in `g_CounterDrawQueue` (VA 0x1A8C224, a
`std::vector<CCounterObject*>`), copying the matrix it is handed to `+0x94`. The queue is drawn by
`CCounterObject_DrawBatch` (0x8396C0), whose one caller is slot 4 of `CEU3Graphics` (0x840E70, `FlushDeferredObjects`),
which draws the counters and then the weather billboards (`BillboardList_DrawBatch` on VA 0x1A8CBEC). `MapObjectGroup_Draw`
calls that slot through the table (0xA71D37) after drawing its group's objects, and turns ALPHABLENDENABLE off after it.
**So counters are drawn at the end of each map object group**, after every figure, building and billboard of the group, in
the order their `Render` was called.

### 10.2 The quad: `CCounterType::LoadResources` (slot 6, 0x83B260)

The four textures are loaded by name into `+0xA4`, `+0xA8`, `+0xAC`, `+0xB0` (`textureFile4` loaded and read by nothing in
the draw). The effect is registered by `FxHandler_Register` under the key `effect`, defaulting to `effectFile`; both counter
types name the same path, so **they share one ID3DXEffect**. Then the quad, from the background texture's own picture size
`w`, `h` (the texture table row's `+0x24`/`+0x28`, its D3DXIMAGE_INFO) and `scale` (`+0x9C`):

    hw = scale · w / h        hh = scale
    um = w / P(w)             vm = h / P(h)       P(n) = the least power of two >= n

    vertex  position        uv
      0     (-hw, -hh, 0)   (0,  vm)    lower left
      1     (-hw,  hh, 0)   (0,  0 )    upper left
      2     ( hw, -hh, 0)   (um, vm)    lower right
      3     ( hw,  hh, 0)   (um, 0 )    upper right
    indices 0 1 2, 2 1 3 - a triangle list of two

In a MeshBuffer at `+0x90`: 4 vertices of stride 0x14, no FVF, not dynamic, 6 16-bit indices; the vertex declaration at
`+0x98` from `CounterVertexElements` (VA 0x170AD18): stream 0, offset 0 FLOAT3 POSITION, offset 12 FLOAT2 TEXCOORD0. Seen
from −z, x right and y up, both triangles run clockwise, D3D's front face. **`SizeOffset` (`+0x198`) = `(w3 / P(w3)) /
noOfFrames`**, w3 the size strip's own width.

The `P(...)` is there because the texture loader calls `D3DXCreateTextureFromFileInMemoryEx` with Width and Height
`D3DX_DEFAULT`, MipLevels `D3DX_FROM_FILE`, pool MANAGED and **Filter `D3DX_FILTER_NONE`** (0xA60B26): D3DX makes a
power-of-two texture with the picture unscaled in its corner (*inferred* from D3DX's documentation, *confirmed* that the
code compensates for it). With TFH's files both backgrounds (`counterbackground*.tga`, loaded as their `.dds`) are 64×64, so
the quad is square and um = vm = 1; both size strips are 384×64 in a 512 texture, so **SizeOffset = 0.75/6 = 0.125**,
sampled as `(u + SizeFrame) · 0.125` on that texture - exactly frame `SizeFrame`; on the strip loaded as a 384-wide picture
of its own it would be `(u + SizeFrame) / 6`.

### 10.3 The batch: `CCounterObject_DrawBatch`

1. **`CCounterType_BeginDraw`** (0x83BB80, the first counter's type), once: SetVertexDeclaration(type `+0x98`);
   **`ViewProjectionMatrix` = view (slot 91) × projection (slot 93)** of the current view's camera (graphics `+0x6BC88` →
   `+0x1C`, the scene view MapObjectGroup_Draw installed); `Begin(&passes, 0)` and `BeginPass(0)`. **No SetTechnique**: the
   effect keeps its technique from when it was made, and counter.fx has one, `Standard` (control: the same search finds the
   weather billboard draw's SetTechnique at 0x883FBD).
2. **The lift.** `up` = the normalised second column (_12, _22, _32) of that camera's view matrix, the camera's up in the
   world; **lift = acos(up.z) / (π/2) × 3.5** - 0 for a camera looking straight down with north up, 3.5 at the horizon. The
   helper at 0xC083A0 is the CRT's acos (its SSE2 path emulated gives acos(0.5) = 1.0472). With the figures' camera aim
   (0, 12, 30) of FINDINGS-camera.md, *inferred*: up.z = (h − 12)/√((h − 12)² + 900), the lift 0.74 at height 100, 0.21 at
   330, 0.14 at 500.
3. **Pass 1, the quads**, for each counter i of the queue from 0: `SetRenderState(D3DRS_DEPTHBIAS, −0.0001 · i)`; the
   counter's matrix (`+0x94`) copied and moved by (0, lift, 0) (`Matrix_PostTranslate`, 0x83A080); slot 22 called and its
   answer (`fldz`, always 0) thrown away; **s = (size − 1) · level_scale (`+0x1D0`) · g_CounterScale + 1.0**, in doubles;
   the picture (`+0x14C`) resolved in the graphics' texture table (null where −1 or above 9999); `CCounterType_DrawQuad`.
   Then EndPass and End.
4. **Pass 2, the flags**: depth bias `−0.000005 − 0.0001 · i`, the same lifted matrix, `CCounterObject_DrawShield` where
   `is_top`.
5. **Pass 3, the texts**: the same biases, `CCounterObject_DrawTexts` where `is_top`.
6. DEPTHBIAS back to 0 and the queue emptied.

So **later in the queue is nearer the camera**: in a stack `CCounterStack::Render` queues the drawn counters in ascending
`order` and the top one last, and each flag and text is 0.000005 nearer than its own quad.

### 10.4 One counter: `CCounterType_DrawQuad` (0x83BC80)

Every handle fetched by name, every call:

| parameter | value |
| --- | --- |
| `BackgroundTex`, `MaskTex`, `SizeTex` | the type's `+0xA4`, `+0xA8`, `+0xAC` |
| `CounterTex` | the unit type's picture: `GFX_small_counter_<key>` far, `GFX_map_counter_<key>` near (section 4) |
| `SizeOffset` | the type's `+0x198`, as in 10.2 |
| `SizeFrame` | (float) the counter's `size`, 0 to 5 (section 3) |
| `CountryColor` | the four floats of the counter's `colour` (`+0x150` → `+0x158`): its owner's colour |
| `vOtherColor` | from the static `g_CounterMarkColours` (VA 0x1BEB670, made on first use): **red (1,0,0,1) where `+0x1BC`, else orange (1,0.5,0,1) where `+0x1BD`, else yellow (1,1,0,1) where `+0x1BB`, else (0,0,0,0)** - alpha 0 turns the corner off |
| `SelectionColor` | selection 1 white (1,1,1,1); 2 the type's `color1`; 3 its `color2`; otherwise **not set**, the previous counter's staying, harmless as `Selected` is then 0 |
| `WorldMatrix` | the camera's **inverse view** (slot 92, `+0x208`) with `_14`, `_24`, `_34` zeroed and the translation row the lifted position, `_44` = 1 |
| `SelectionIntensity` | **0.5 + 0.5 · \|sin(2t)\|**, t the platform clock's seconds as a float (`g_PlatformClock`, VA 0x1A857E4, slot 5, CHighPerfWinClock::GetSeconds): a pulse between 0.5 and 1 every π/2 seconds |
| `Selected` | 1.0 for selection 1, 2 or 3, else 0.0 |
| `CounterScale` | s |

Then `CommitChanges` and `VertexBuffer_Draw` on the type's own quad: SetStreamSource(0, VB, 0, 20), SetIndices,
`DrawIndexedPrimitive(TRIANGLELIST, 0, 0, 4, 0, 2)`. The declaration and effect are the first counter's type's; the two
types' are identical and shared, so it makes no difference.

### 10.5 Render states

From the pass: ZENABLE, ZWRITEENABLE, ALPHATESTENABLE and ALPHABLENDENABLE true; nothing else is set by the pass or the
code around it but DEPTHBIAS. The rest is the device's: **ALPHAREF 8, ALPHAFUNC GREATEREQUAL** (written nowhere but
`CGraphics_SetDefaultRenderStates`); **SRCBLEND SRCALPHA / DESTBLEND INVSRCALPHA**, set at the start of
`MapObjectGroup_Draw`, whose only blend writes those are (*inferred* that nothing between changes them: a census of
immediate SetRenderState calls in that function, and effects under Begin(0) restore their state); CULLMODE NONE by
default, the quad facing the camera anyway; ZFUNC not looked at. The samplers are the file's: clamp, linear, CounterTex
anisotropic 4.

### 10.6 The three marks

Written for both of a unit's counters each frame by `CUnit::UpdateAvatar` / `CNavy::UpdateAvatar` (slot 36), and false on
any unit not the played country's own (`owner_id` against `CCurrentGameState +0xC34`):

| mark | corner | set where |
| --- | --- | --- |
| `+0x1BB` | yellow | `combat_cooldown` (`+0xD4`, the save's `attack_delay`) above 0, no combat (`+0x11C` ≤ 0), not retreating (`+0x158`) |
| `+0x1BC` | red | `supply_received_percentage` (`+0xFC`) or `fuel_received_percentage` (`+0x100`) under Define50 = 50, i.e. 5% |
| `+0x1BD` | orange | the unit's upgrade lines (`CUnit +0x298`, 0x28-byte records) are not empty |

`CUnit::ConsumeSuppliesAndFuel` also sets the red mark after a unit's day, outright where its depot's holder is no friend.
`CUnit_AddUpgradeLine` / `CUnit_RemoveUpgradeLine` set the orange one as a line comes or goes; a line is added by
`CUpgradeRegimentCommand`'s slot 6 and, after a load, by `CMilitaryConstruction_RegisterUpgradeTarget` from
`CCountry::AfterLoad`, for a construction with a target whose brigade items upgrade from another type, and removed by
`CMilitaryConstruction`'s destructor. **`delayAfterAttackColor` is read by nothing**: the attack-delay corner is the static
yellow.

### 10.7 Near and far

Both `CounterType`s name `counter.fx` and share the effect, the batch and these rules; they differ in their data alone:

| | `unit_counter` (far) | `unit_counter_close` (near) |
| --- | --- | --- |
| background | `counterbackground_small` 64×64 | `counterbackground` 64×64 |
| mask | `countercolormask_small.tga` 64×64 | `countercolormask.tga` 64×64 |
| size strip | `counterarmysize_counter_small` 384×64 | `counterarmysize_counter` 384×64 |
| picture | `smallcounters/<key>` 32×32 | `mapcounters/<key>` 64×64 |
| scale | 3, so 6 units square × s | 2.5, so 5 units square |
| level_scale | 0.2, s = 0.8 to 1.8 × counter_scale's share | none, s = 1 |

A smaller picture is sampled over the same UV range. That the far counter reaches the queue through the avatar's own
`Render`, not a stack, is *inferred*: the avatar's render was not read.

**Not established here**: who queues the far counter; ZFUNC at the batch; whether nothing between the start of
`MapObjectGroup_Draw` and its counter batch changes the blend factors; the camera's up with `always_counters`, on which
the lift depends; what sets `selection` 1, 2 or 3 (slot 23's callers); the rest of `CMilitaryConstruction`'s destructor
past 0x483FC4; the x87 path of the acos helper, taken as the SSE2 path emulated. Frontier (rvas): 0x3C9530, 0x4F910,
0x504B0, 0x660F30, 0x1DA7C0, 0x83EF0.

## What was not read

- **How a province's five points are made.** No store to `CProvinceTemplate +0xCC` was found:
  a search of `.text` for a store, a `lea` or an `add` at that displacement, with and
  without an index, finds only readers. They are probably written through a pointer taken
  somewhere else in the object.
- **What a text's size is divided by**, in the font's draw routine (slot 7 of the object at
  `CCounterType +0x19C`).
- **Who tells an avatar it is far away**, and the test against `counter_distance`.
- **What `order` is set from** (`CCounterObject +0x1A8`).
- **Of the arrow** (section 9): what hides it again, when its red frame is used, and why it is a seventh further from the
  counter on the screenshot than `offset`. `textureFile4` is loaded (`+0xB0`) and not read by the
  draw; and the `Rank` object.
- **The province's port and air base icons**, which are how a fleet in port and a wing at
  its base are shown: `0x6400E0` and `0x6402A0`.
- **The unit of the map.** Nothing read here says how long a map unit is. The stack's
  offsets (0.3) and a counter's height (5 or 6) only make sense with one map unit to a
  pixel of `provinces.bmp`, and `EnterProvince` subtracts pixel positions to make a vector
  for the avatar; `inferred`.
