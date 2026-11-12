# FINDINGS-provincenamepoint.md: where a province name stands without a text_position

*Read 2026-11-12, statically. Addresses are rvas unless marked VA. Everything is `confirmed` unless marked otherwise. The
stores and the 2.0 were checked again off the bytes by the collecting session the same day.*

**It corrects `FINDINGS-farmap.md`** B.7.1 and B.5, which had such a name standing on the bounding box's centre, and the
record's `CProvinceTemplate +0x5C` comment, which said the geometry pass "goes on to refine" the label pair; it does not.

## 1. The question

`FINDINGS-farmap.md` B.7.1 had the near-map name of a province with no `text_position` at its bounding-box centre, and
said the step writing that point into `CProvinceTemplate +0x3C/+0x40` had not been read. The maintainer then set a
screenshot of the original beside OpenHOI3, which uses the bounding-box centre `min + (max − min + 1) / 2`: every
province without a `text_position` stood about 1.9 map pixels further south in the original, and every province with one
stood in the same place in both (2026-11-12; Bautzen, Lauban, Sagar, Neusalz, Glogau, Varnsdorf and Altenberg against
Görlitz, Pirna, Dessau, Torgau, Crossen, Hoyerswerda, Meißen, Grünberg, Finsterwalde, Chemnitz and Bunzlau).

## 2. Who writes the point, and how

**ProvinceTexts_Create** (0x456710) takes the name's origin from the template's +0x3C/+0x40 (VA 0x856871, 0x856876) and
subtracts the tile middle. It tests nothing about the province. ProvinceTexts_Refresh takes the point again from the same
template fields.

**CMap::ComputeProvinceGeometry** (0x917A0) fills +0x3C/+0x40. CMap::LoadMapFiles calls it once at 0x8A739. The call is
unconditional: it comes after the map-cache branch rejoins at 0x8A6C6, and **directly before CMap::LoadPositionsFile at
0x8A73F**. For each template `t`:

    centre_x = bbox_x (+0x80) + bbox_width  (+0x88) / 2       ; integer; cdq/sub/sar, truncating
    centre_y = bbox_y (+0x84) + bbox_height (+0x8C) / 2       ; width and height count pixels
    label (+0x5C/+0x60) = centre
    if (centre_x == 0 || centre_y == 0) centre = label = (1, 1)            ; 0x918A9
    position (+0x64/+0x68) = label
    city     (+0x4C/+0x50) = ((float)label_x, (float)label_y)
    text_position_x (+0x3C) = (float)label_x                                ; VA 0x491905
    text_position_y (+0x40) = (float)((double)(float)label_y - 2.0)         ; VA 0x491912 stores the plain value,
                                                                            ; 0x491917..0x491926 subtracts the
                                                                            ; double 2.0 at VA 0x160A360 (rva 0x120A360)
    every building position = ((float)label_x, (float)label_y); every building nudge = 0.0f

The centre is `min + (max − min + 1) / 2`, the width and height counting pixels; `FINDINGS-movement.md` section 6
established that, and nothing here changes it. The result is a whole pixel. The −2.0 is applied in double precision and
is exact for any integer coordinate. **x is not moved. y has 2.0 taken off, and engine y grows northward, so the point
moves two map pixels south.** The city point, the unit point and every building position get the plain centre, with no
2.0.

LoadPositionsFile then overwrites +0x3C/+0x40 verbatim where a block has `text_position`: `movss [ebx+0x3C]` and
`[ebx+0x40]` at VA 0x48FE70/75, straight from the parsed CMapPoint, with no arithmetic. So the 2.0 survives only where
the file says nothing. **The `unit` key does not affect the name**: it writes +0x64/+0x68, and the fallback was taken
from the label before positions.txt was read.

**Search for other writers.** VA 0x480000–0x4B0000 was scanned for float and dword stores to `[reg+0x3C]` and
`[reg+0x40]`; the scan split the range on int3 runs, decoded each piece from its start, and resumed capstone past every
stop. It found:

- the known writers, which serve as the positive control: the constructor at VA 0x4A92F8/FD, the geometry pass at
  0x491905/12/26, and the text_position handler at 0x48FE70/75;
- CProvinceTemplate::Save at 0x4AA76F/93 (section 3);
- two other classes, not this template: CTerrainGraphical at 0x4880EB and CTree at 0x48C441;
- one store at 0x491C3C inside the geometry pass, which is into the building-position array, not the template.

The hidden map editor's handlers lie outside that range and were not scanned. They are not part of a normal game.

## 3. The writing side agrees: CProvinceTemplate::Save

CProvinceTemplate::Save (0xAA300, slot 1) writes a positions.txt block. At VA 0x4AA326..0x4AA3FE it computes each point's
default and writes a key only where the point differs from it:

- **unit:** written where the label (+0x5C/+0x60) differs from the position (+0x64/+0x68).
- **city:** written where the label differs from the truncated city (+0x4C/+0x50).
- **text_position:** written where (+0x3C, +0x40) differs from `((float)label_x, (float)((double)(float)label_y − 2.0))`.
  The 2.0 is the same double at VA 0x160A360.
- **text_rotation:** written where it is not 0.0. **text_scale:** written where it is not 1.0.

Before writing text_position, Save rounds both halves through RoundToOneDecimal (0xA91F0), `floor(10x + 0.5) / 10`, stores
the rounded values back into the template (VA 0x4AA76F, 0x4AA793), then writes token 0x3D2. *Inferred*: Save is reached
from the hidden map editor; its callers were not read.

## 4. The layout does not differ

ProvinceTexts_Update's per-entry tests are the slot (+0x48) and the shown byte (+0x44), and nothing else. The template
carries no flag recording whether the file gave a `text_position`; the fallback is baked into +0x40 as a number. So
`FINDINGS-farmap.md` B.7.3 holds for every province: the lines are centred on the point, and the text block's bottom
stands on it.

**On 1.9 against 2.0.** One kart_font line at text_scale 1 is 76 × 0.025 = **1.9** map pixels - the measured figure, so the
coincidence is worth stating. **The code does not use a line height**: the shift is a fixed 2.0 map pixels applied to the
point, at every text_scale. *Inferred*: the 0.1 difference is the precision of measuring a screenshot. TFH has a cheap test
that tells the two apart: 243 provinces have no `text_position` but a `text_scale` other than 1, and under this reading
every one still sits 2.0 south, where under a line-height explanation the shift would scale with text_scale - Indiga 358
(scale 1.4): 2.0 here, 2.66 by line height; Bilovodsk 2525 (0.65): 2.0 and 1.24; Fort Albany 3540, Fort Hope 3601, Wager
Bay 4800 and Churchill 5027 (1.5 each): 2.0 and 2.85.

## 5. The check against the measurement

Bounding boxes from TFH's `tfh/map/provinces.bmp` (5616×2160, 24-bit) and `tfh/map/definition.csv`; engine y is
`2159 − file row`, per `FINDINGS-mapbuild.md` section 7.

| province | bbox x | bbox y | centre | original's point | south of centre |
| --- | --- | --- | --- | --- | --- |
| Bautzen 2265 (text_rotation 5.783185 only) | 2983..2999 | 1687..1702 | (2991, 1695) | (2991.0, 1693.0) | 2.0 |
| Lauban 2323 | 2997..3007 | 1689..1698 | (3002, 1694) | (3002.0, 1692.0) | 2.0 |
| Sagar 2266 | 2996..3005 | 1698..1708 | (3001, 1703) | (3001.0, 1701.0) | 2.0 |
| Neusalz 2211 | 3005..3014 | 1696..1705 | (3010, 1701) | (3010.0, 1699.0) | 2.0 |
| Glogau 2268 | 3013..3023 | 1695..1704 | (3018, 1700) | (3018.0, 1698.0) | 2.0 |
| Varnsdorf 2380 | 2984..2994 | 1679..1690 | (2989, 1685) | (2989.0, 1683.0) | 2.0 |
| Altenberg 2379 | 2969..2978 | 1681..1691 | (2974, 1686) | (2974.0, 1684.0) | 2.0 |

The centre column is the rewrite's centre and the original's centre_x/centre_y alike. So the difference is exactly 2.0 map
pixels south for every one, against the measured ~1.9, with no x difference predicted and none measured. The provinces with
a `text_position` use the file's point verbatim in both programs, which is why they match. TFH: 6,167 of 14,168 position
blocks have `text_position`.

The live game was not used. A live read of Bautzen's template at +0x3C/+0x40 should give 2991.0 and 1693.0.

## 6. Hardcoded or mod-able

- **The 2.0 map-pixel shift south:** [exe], the double at VA 0x160A360, shared with unrelated code. No define or file
  moves it.
- **The bounding box and its centre:** [mod: map/provinces.bmp and map/definition.csv]. The arithmetic is [exe]: integer,
  truncating, with the width counting pixels.
- **Whether the fallback applies at all:** [mod: positions.txt], by the absence of `text_position` in the province's block.
- **text_rotation and text_scale** keep their own defaults, 0 and 1.0, [exe], and are applied around this point as before
  [mod: positions.txt].
- **The (0,0)→(1,1) guard:** [exe]. *Inferred*: it never fires on a real map.

## 7. Not established

- Who calls CProvinceTemplate::Save. *Inferred*: the map editor.
- The two constants at VA 0x160A450/0x160A458 in RoundToOneDecimal. *Inferred*: a sign mask and 2^52.
- What Save's other four RoundToOneDecimal calls round. *Likely* two more point pairs.
- Whether anything outside VA 0x480000–0x4B0000 writes the template's +0x3C/+0x40 during a normal game. Only the map
  editor is suspected.

In the record through `fragments/merged/province-name-fallback-2026-11-12.json`.
