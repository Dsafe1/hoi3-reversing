# How the map cache is built

*The map cache wave, 2026-11-08 (`WAVE.md`, `CANDIDATES.md`). How the original makes the drawing half of `map/cache` out of the
map files, read so that the files can be made again exactly. The formats as the loaders read them are in
`FINDINGS-mapdraw.md` (A.1, A.3, B.7, C.6, C.7); this file is the builders. Each section's rules were run against two maps
byte for byte: Their Finest Hour's shipped cache (`tfh/map/cache`, stamp 93E125C4) and the cache the original built for
BlackICE in the player's folder (stamp 383756A4). Tags: [exe] hardcoded in the executable, [mod] set by a map file.*

## A. The land mesh and the files

*Read 2026-11-08 (fragment `mapcache-land.json`). Addresses are rvas unless marked VA. Confirmed means read and reproduced by
the byte comparison.*

**The check.** The staircase raster is read from each cache's own map.bin (section D's product). Everything else comes from
`provinces.bmp`, `definition.csv` and `default.map`.

| | TFH | BlackICE |
| --- | --- | --- |
| tiles built vs shipped | 1,774 / 1,774, none extra or missing | 1,787 / 1,787, none extra or missing |
| piece 1 (tile dword, vertices) | 1,774 of 1,774 | 1,787 of 1,787 |
| piece 2 (total bytes, N, groups) | 1,774 of 1,774 | 1,787 of 1,787 |
| whole record, pieces 3-7 from the shipped file | 1,774 of 1,774 | 1,787 of 1,787 |
| quad_index.bin | identical, 14,204 bytes | identical, 14,308 bytes |
| all_quads.bin, framed as above | identical, 66,167,662 bytes | identical, 66,141,318 bytes |

**Controls**, because a match on a passive input proves little:

| raster change | TFH tiles still agreeing | BlackICE tiles still agreeing |
| --- | --- | --- |
| all flags zeroed | 100 of 1,774 | 117 of 1,787 |
| bit 0x01 cleared | 378 | 391 |
| bit 0x02 cleared | 119 | 134 |
| bit 0x04 cleared | 372 | 386 |
| bit 0x08 cleared | 115 | 132 |
| bit 0x20 cleared | 111 | 127 |
| bit 0x10 cleared | 1,774 (all) | 1,787 (all) |

So the land mesh reads every bit except 0x10.

### A.1 CProvinceManager_BuildQuads (0x45A580)

**Confirmed.** It mallocs 0x1000000 bytes as a scratch for the terrain-index textures, and opens `/cache/all_quads.bin` for
writing for the whole run. It VirtualAllocs five buffers and frees them at the end:

| buffer | bytes | user |
| --- | --- | --- |
| g_pProvinceVertexMemCache | 480,000 | passed to QuadBuild_EdgeVertices |
| g_pTempVertices | 480,000 | TempBorderVertices_Weld |
| g_pIndexLookup | 40,000 | TempBorderVertices_Weld |
| g_pTempBorderIndices | 20,000 | Weld, EdgeVertices, QuadBuild_Tile |
| g_pTempBorderVertices | 480,000 | Weld, EdgeVertices, QuadBuild_Tile |

None of the five is touched by the land mesh, which uses plain `std::vector`s.

- **Tile order:** index 0 to columns × rows − 1.
- A tile is built if any province in its list (`MapTile +0`) is land; the walk stops at the first land province. The call is
  `QuadBuild_Tile(mgr, tile, &list, texturesFolder, scratch)`.
- If the tile then has land vertices (`+0x27C > 0`), 'writing quad mesh' is logged and `QuadCache_WriteTile` appends the record.
  Tile index and record size go on two vectors.
- After each built tile, `VectorU16_Resize(0)` on `mgr +0x42C4`.
- **`quad_index.bin`:** int count, int total (sum of sizes), int largest, then (tile, size) pairs in written order.
- **It does not write `quad_format.bin`.**

### A.2 The record (QuadCache_WriteTile, 0x474F00, stream in ESI, `ret 8`)

**Confirmed for pieces 1 and 2; the others are the format as written, for sections B and C.** In order:

1. dword **tile index**; dword V = vertices × 8; vertices as SHORT2 (float − 0.5, truncated), then the two id words as held.
2. dword **total land index bytes** (primitive count × 6); dword N = province count of the list **including sea**; N × (dword B, B
   bytes). Sea provinces have empty groups, which is why groups trail with 0.
3. dword M = border primitives × 6; M bytes.
4. dword = border vertices × 12; each 0x18-byte temporary record is cut to 12. x and y are −0.5, then −1000 where the corner field
   is 0.0 and +1000 where it is 1.0. **For any other value the short is left unwritten in a malloc'd buffer.**
5. dword W = beach vertices × 12; W bytes.
6. Only if W ≠ 0: dword X = beach primitives × 6; X bytes.
7. dword K; K × 0x1C wave pixels, from shore `+0x18`, 16 bytes per tile.

The return value is the record size.

### A.3 QuadBuild_Tile (0x4727B0), the whole per-tile order (`ret 0x14`)

Tile middle = (50 × col + 25, 50 × row + 25). Then:

1. `+0x10` vector resized to the list's province count; 0x6C-byte per-province entries created.
2. For each province in list order, ascending id:
   - push the current land index count (the group start);
   - sea: only sets `+0xA1` if a neighbour is land;
   - land: `QuadBuild_ProvinceLand`, then per pixel **0x456DF0** (feeds the entry's vectors from the same raster, section B) and
     **0x46EB60** (beach and surf, section C), with `+0xA0`/`+0xA1` set when a beach was added, then the entry's
     `+0x30/+0x34/+0x38`.
3. One final start pushed.
4. 'Province quad is too large' is **only a log**, when 4 × the entries' first-vector sum exceeds 40,000. A sum of 0 would skip to
   the beaches, but it is at least the tile's land pixels.
5. Land vertex buffer created (count, stride 12), **0x45D990** resets `mgr`'s 60-slot table, land index buffer created.
6. Per-province slot vectors (`mgr +0x90` pairs of (−1, 0)); **QuadBuild_EdgeVertices** per province (section B).
7. Land vertices stored as float int + 0.5 with the id words; indices copied.
8. `+0x10` meshes from the 60-slot table; **TempBorderVertices_Weld** and the border buffers (section B).
9. **0x470700** beaches where there is data (section C).
10. **Quad_CreateTerrainIndexTexture** (section E).

### A.4 How a province's pixels become mesh (0x4492C0, 0x448EE0, 0x449080)

**Confirmed: byte-for-byte on both maps.**

**Inputs.** The pixel list runs south to north, west to east, each pair relative to the centre (`bbox_x + w/2`, `bbox_y + h/2`,
where `w = x1 − x0 + 1`). `ComputeProvinceGeometry` subtracts the centre from each pair at VA 0x49187F. Below, xs, xe and y are
absolute map pixels; the original keeps them relative and adds the centre back, with the same result.

**Runs.** Maximal horizontal runs in list order: the next pixel has x + 1 and the same y.

**Each run gives one quad.** Start: L0 = L1 = xs − 1, R0 = R1 = xe. Index 0 of each pair is the south corner, index 1 the north.
Let m(c) be the raster byte at column c of row y, i.e. at y × (W + 1) + c. Left end tests m(xs − 1); right end tests m(xe). The
first bit found wins, in this order:

| bit | left end | right end |
| --- | --- | --- |
| 2 | none | none |
| 8 | L0 = xs − 2 | R0 = xe − 1 |
| 4 | L1 = xs | R1 = xe + 1 |
| 1 | L1 = xs − 2 | R1 = xe − 1 |
| 0x20 | test m(xs): 2 gives L0 = xs; 8 nothing; 4 gives L1 = xs; 1 gives L1 = xs − 2 | test m(xe + 1): 2 gives R0 = xe + 1; 8 nothing; 4 gives R1 = xe + 1; 1 gives R1 = xe − 1 |

Bit 0x10 is never tested here.

**Vertices.** In this order, each minus the tile middle: (L0, y−1), (R0, y−1), (L1, y), (R1, y). Tile-local vertex = absolute
corner − middle.

**Indices.** With n the count before the push: n+1, n, n+2, n+1, n+2, n+3 (clockwise from above, as `FINDINGS-mapdraw.md` A.1
measured).

**Weld, per province, after all its runs.** Unique positions in first-occurrence order, over this province's vertices only.
Vertices across provinces are never merged. Triangles are remapped and **dropped if two corners are equal**; collinear triangles
are kept. Id is pushed once per surviving vertex. Each id splits to words (id & 0xFF, id >> 8).

**Why the edges bend.** A corner shift makes a run's end diagonal, which adds or removes half-pixels: triangle area 4,041,885
against 4,041,291 pixels. A province with no such flag at either end of any run is exact.

### A.5 quad_format.bin

**Confirmed for TFH.** Written by `QuadFormat_Write` (0x473EC0), called from `CProvinceManager_CreateMeshes` only where
`QuadFormat_Matches` (0x473610) was false. Layout: int 3, 3 elements of VA 0x170AC40, int 4, 4 elements of VA 0x170AC58, int 1. Each
element is byte method, word offset, word stream, byte type, byte usage, byte index. 68 bytes, a constant of the executable.
Rebuilt from the executable's bytes it equals TFH's 68 bytes.

`beach_format.bin` is named beside it and written nothing on this path.

*Not established:* why BlackICE's cache folder has no `quad_format.bin`. *Inferred:* the check found the install's file through the
override and base-folder logic, compared equal, and never wrote one. Which directory mode that run used was not traced.

### A.6 Not established, and not exercised by either map

- **Tile assignment** rests on the *measured* centre rule. It is confirmed by the 3,561 tiles' lists agreeing, but
  `AssignProvincesToTiles`' `+0x13C/+0x140` middle pair was not traced.
- **Flag precedence** (2, 8, 4, 1, 0x20) is read from the code; the data cannot test it, since the raster's values are only 0, 1, 2,
  4, 8, 16, 32, 48.
- **A centre with x or y equal to 0** is set to (1,1) by `ComputeProvinceGeometry` after the pixels are rebased. No province has this
  on either map.
- **Edge columns:** a run at column 0 reads the byte before its row, and x = W uses the raster's extra column. Neither map has land
  in column 0 or column W − 1.
- **A province id with no pixels** does not occur on either map.
- **16-bit indices** are nowhere near their limit (largest tile 1,230 vertices, 2,544 indices).

**Corrections.** `CProvinceTemplate +0x6C` is relative to the province centre, which the record did not say; the two dwords
`QuadCache_LoadTile` skips are the tile index and the total index bytes.

Frontier: 0x456DF0 (decompiled only), 0x45D990 (decompiled only), 0x46EB60, 0x470700, 0x477660, 0x477860, 0x46C7C0, 0x444BB0,
0x46D470, 0x46D630, 0x46BBC0, 0x46D160, 0x422760, 0x3C60F0, 0x3C62C0, 0x591CA0, 0x66C7D0, 0x66C880, 0x66D080, 0x7853E0, 0x4221F0,
0x10E870.

## B. The land borders: pieces 3 and 4 of a record, and `border_adj.bin`

*Read 2026-11-08 (fragment `mapcache-borders.json`). Everything below is confirmed by the byte-for-byte agreement that follows
unless marked otherwise.*

**The check** (inputs: `provinces.bmp`, `definition.csv`, `default.map`, plus the shipped `border_bitmap.bin`, `map.bin`,
`adjacencies.bin`).

| map | tiles with pieces 3 and 4 agreeing | `border_adj.bin` |
| --- | --- | --- |
| TFH (93E125C4) | 1,774 of 1,774 | 345,888 bytes, byte for byte |
| BlackICE (383756A4) | 1,787 of 1,787 | 346,360 bytes, byte for byte |

No tile gets border quads that the index lacks, on either map.

**Where it runs.** The per-tile builder `0x4727B0` first loops over the tile's provinces, in ascending id, as the oracle's
order bears out. For a land province it calls `QuadBuild_AddPixelEntries` (`0x456DF0`) for each pixel of the template's `+0x6C`
list. That list is local to the centre `+0x2C/+0x30`, ordered y ascending (south first) then x ascending. The builder then
calls `QuadBuild_EdgeVertices` once per province (`0x873069`), then `TempBorderVertices_Weld` (`0x873480`, only if the tile has
any border index). It makes the tile's `+0x294` mesh from the welded buffers, at stride 0x18. The record writer `0x474F00`
turns it into piece 3 and piece 4.

**The scratch buffers** (`CProvinceManager_BuildQuads` VirtualAllocs): `g_pProvinceVertexMemCache` 480,000 bytes,
`g_pTempVertices` 480,000, `g_pIndexLookup` 40,000, `g_pTempBorderIndices` 20,000, `g_pTempBorderVertices` 480,000.

**The per-province record** (0x6C bytes, zeroed by `0x44F250`):

| offset | holds |
| --- | --- |
| +0 | absolute pixels (int x, y) |
| +0x10 | pixels local to the centre (float) |
| +0x20 | zeros |
| +0x30/+0x34 | centre less tile middle (float; the middle is 50·col + 25, 50·row + 25) |
| +0x38 | the id |
| +0x3C | each entry's type |
| +0x4C | zeros |
| +0x5C | offsets (dx, dy) |

**`QuadBuild_AddPixelEntries`.** Read map.bin's byte `m` at the absolute pixel (row y at y·(W+1)). Take type t1 in this test
order: bit 2 → 4, bit 8 → 3, bit 4 → 2, bit 1 → 1, else 0. Every pixel gets one entry of type t1 with offset (0,0). If t1 ≠ 0
the pixel gets a **second** entry, the other half of a diagonal cut: bit 2 → type 1, dx −1; bit 4 → type 3, dx −1; bit 8 → type
2, dx +1; bit 1 → type 4, dx +1. `m` of 16, 32, 48 alone gives type 0 and one entry.

**`QuadBuild_EdgeVertices`, per entry.** All raster reads answer 0 outside `[0,W)×[0,H)`. Let `own` = raster(x, y) (the entry's
pixel) and `id` = raster(x+dx, y+dy).

1. *Neighbours*, slots 0..7: NW, N, NE, W, E, SW, S, SE (y grows north).
2. *Flag and chosen neighbour.* A neighbour n sets `flag` when n ≠ own, n ≠ 0 and n is not sea. `sel` takes n if unset or if
   the slot is N, W, E or S. So the last orthogonal one in that order wins, else the first diagonal. (`own` being sea has
   another arm, wanting a sea neighbour; it cannot run for a land province.) Sea is `CMap +0x21F8`, a byte array set from the
   list at `+0x21E8`; **inferred** to be default.map's `sea_starts`, since the parser was not read and only the oracle bears
   it out.
3. *Junction.* When `flag` is set, a junction is any of the four corner pairs (N,W), (S,W), (N,E), (S,E) where the two ids both
   differ from own, differ from each other, and are both not sea.
4. *`border_adj.bin`.* A junction searches `mgr +0x42B4[own]` for (x, y) and pushes it if absent. There is no cap; `To many
   corners in province` is logged when a push leaves the list holding 8 or more. List order is the walk order, each province's
   list ascending by y then x. This is the whole of what fills the file. (B.7's "3 or 4 distinct ids" holds for every listed
   pixel but is not the rule: 5,271 of TFH's 41,422 land pixels with 3 or 4 distinct ids are unlisted, 4,625 with sea or id 0
   among the differing ones, 646 with the two others on opposite sides.)
5. *Slot.* Junction: `count + min(list index, 7)`, where count is the template's `+0x90` adjacency count. Otherwise: index of
   `sel` in the adjacency list (20-byte records, id at +4), or −1 if absent (diagonal-only contact). Then n = own·14 + slot; u =
   n & 0x1FF, v = n >> 9.
6. *A border entry (`flag` set) emits*, at border vertex base b: indices b, b+1, b+2, b+2, b+3, b, and four 0x18-byte records,
   all with the same word u, v and colour:
   - colour = (bb3·8)<<24 | (id&0xFF)<<16 | (id>>8)<<8 | (bb0·8), with bb0, bb3 the border bitmap's bytes 0 and 3 at the entry's
     pixel (x, y), row y at y·(W+1);
   - so **a diagonal's second half carries the neighbour's id in its colour and own's slot in its texel**: 335,734 of TFH's
     2,941,972 file vertices, 335,671 of BlackICE's 2,942,654, the colour id differing from the texel's province.
7. *Corners.* With rel = pixel − tile middle: A = (rel.x−½, rel.y−½, uv 0,1), B = (rel.x−½, rel.y+½, 0,0), C = (rel.x+½, rel.y+½,
   1,0), D = (rel.x+½, rel.y−½, 1,1).

| type | vertices |
| --- | --- |
| 0 | A B C D (the whole pixel) |
| 1 | A B D D |
| 2 | A C D D |
| 3 | A B C C |
| 4 | B C D D |

Types above 4 do not occur. A non-border entry emits no border record.

**The 12-byte stream is dead.** The same walk writes a 12-byte vertex per corner for **every** pixel entry (float x, z, words
id&0xFF, id>>8) to `g_pProvinceVertexMemCache`, and six indices to the builder's local vector. Nothing reads either: the global
has three code references (alloc, free, the builder's argument), and the builder frees the vector unread. It is not the land
mesh; the land mesh is `0x4492C0`'s (section A). `+0x42C4` (a u16 vector of vertex numbers, pushed on border entries) has no
reader found (`fieldchain`; cleared by `CProvinceManager_LoadQuads`). `+0x4198[60]`, `+0x4190`, `+0x4194` are per-province index
lists copied to the tile's `+0x10` meshes; not read further.

**`TempBorderVertices_Weld`.**

1. remap[] = −1; remap = −2 for each record with colour B (+0xC) = 0 and colour A (+0xF) = 0. The second arm of the test (A =
   0x16 and R = 0, at `0x8725A7`) cannot fire, A being a multiple of 8.
2. For i ascending with remap −1: copy to the next slot of `g_pTempVertices`, and every later record equal in all fields gets
   that slot. In practice only the doubled corner of a type 1..4 entry merges; a dict by the whole record reproduces it.
3. Copy back.
4. Triangles keep their order, remapped, dropped if any two indices are equal. A dropped quad has all −2, so all its triangles
   go; a doubled corner loses one triangle.

Dropped quads never mix −2 with kept vertices, since a quad's four records share one colour.

**The record.** Piece 3 is the welded 16-bit indices (M bytes). Piece 4 is 12 bytes per vertex: `X = trunc(x − 0.5 − 1000)` where
f4 = 0 and `trunc(x − 0.5 + 1000)` where f4 = 1, the same for Z from f5, then words u, v and the dword colour (writer `0x474F00`).
A tile with no border index writes M = B = 0.

**The quad ~45 px off.** It is the 9th junction pixel of province 10100, (3208, 874) in tile 1872 on both maps. Its list index 8
clamps to 7, so it reads pair 7's texel while drawn at its own pixel: 45 px west and 10 north of pair 7 at (3253, 864). B.7's
"off" quad is exactly that one; its 9-entry list is the maximum.

**Other figures, measured.**

- TFH: 3,596,996 border vertices before the weld and 2,941,972 after; 1,359,250 triangles; 1,678 tiles have a border mesh.
  BlackICE: 3,597,468, 2,942,654, 1,359,612, 1,674.
- Largest tile (3442, both maps) before the weld: 6,720 vertices, 10,080 indices = 20,160 bytes. That is over
  `g_pTempBorderIndices`' 20,000-byte request, surviving only inside the 20,480-byte committed page (*inferred*: a map past 10,240
  pre-weld indices in a tile would fault).
- The builder's "Province quad is too large" check fires at entries × 4 > 40,000 and only logs; it does not stop. Largest on
  both maps: 9,779 × 4 = 39,116.
- `border_adj`: 11 TFH / 12 BlackICE provinces have more than 7 pairs, the log's threshold.
- Slot −1: two entries in TFH (provinces 6294 and 6313, at (4389,923) and (4388,922)), none in BlackICE.

**Corrections to the published text.** B.3: a border element is a quad or, on a diagonal, one triangle, and the "matches on every
vertex sampled" is untrue of second halves. The record's `QuadBuild_EdgeVertices` summary: the 12-byte stream is written and never
read. B.7's "one quad off" is explained above; its slot statement otherwise stands.

**Not established.** Whether `+0x21E8` is truly `sea_starts` (the parser's token dispatch was not traced; the oracle agrees on both
maps). The `+0x10` tile meshes' use. Whether either slot −1 entry survived the weld.

Frontier: 0x449480 (u16 vector push), 0x3C6440 (8-byte vector reserve), 0x437F00 (u16 vector reserve), 0x3C60F0, 0x22690, 0x221F0
(vector push-backs), 0x45D990, 0x4775D0, 0x4776E0, 0x4777B0 (the builder's per-province group helpers).

## C. The beaches and the surf's order: pieces 5, 6 and 7 of a record

*Read 2026-11-08 (fragment `mapcache-beaches.json`). Everything below is confirmed by whole-file byte equality on two maps unless marked.*

**The check** (built from `provinces.bmp`, `definition.csv`, `default.map`, `terrain.bmp`, `terrain.txt` and the noise count n; `map.bin`'s raster
is made too, not read).

| map | tiles compared | piece 5 | piece 6 | piece 7 | n |
| --- | --- | --- | --- | --- | --- |
| TFH | 1,774 | 1,774 | 1,774 | 1,774 | 292 |
| BlackICE GitHub | 1,787 | 1,787 | 1,787 | 1,787 | 1140 |

No difference is left once n is given. With n = 292 on BlackICE, piece 7 is still 1,787 of 1,787, piece 5 is 833 and piece 6 is 1,699; the noise is
all that differs.

**The walk (settles `FINDINGS-mapdraw.md` C.7's "measured, not read").** QuadBuild_Tile (0x4727B0) takes the tile's province list in order, ascending id
(section A). For each land province (template +0x22) it walks the template's +0x6C pixel list in index order, south to north, row by row, west to
east. Each entry is (dx, dy) relative to the template's +0x2C/+0x30; the absolute pixel is the sum (VA 0x872B06..0x872B0F). Each pixel goes through
QuadBuild_AddPixelEntries (0x456DF0, section B), then QuadBuild_PixelBeachesAndSurf (0x46EB60). So piece 7 is, per tile: provinces by id, pixels in list
order, and for each pixel the generator's records (MapShore_GenerateWavePixels, C.7) in its own order. Piece 5/6 segments come in the same walk, after
the surf call of each pixel, in the order below.

**Beach segments of one land pixel (x, y)** [exe rule, on mod data]. Nothing unless 0 < x < W−1 and 0 < y < H−1. W(a, b) is TerrainRaster_IsWater on
terrain.bmp, palette byte through terrain.txt's categories. Added in this order:

1. **3** if (x−1,y+1), (x,y+1), (x+1,y+1) are all water; **4** the same on row y−1; **1** the same on column x+1 (y−1,y,y+1); **2** the same on column x−1.
2. Lone cases: **15** (x,y−1) water and (x−1,y−1), (x+1,y−1) land; **14** the same on row y+1; **13** (x−1,y) water and (x−1,y+1), (x−1,y−1) land; **12** the
   same on column x+1, then return at once. If 13, 14 or 15 was added, return.
3. Corners, at most one: **8** if (x−1,y−1), (x,y−1), (x−1,y), not (x−1,y+1), (x−2,y); else **7** if (x+1,y−1), (x,y−1), (x+1,y), not (x−1,y−1), (x,y−2); else
   **6** if (x−1,y+1), (x−1,y), not (x−1,y−1); else **5** if (x+1,y+1), (x+1,y), not (x+1,y−1).
4. Independently: **9** if (x−1,y−1), (x,y−1), not (x+1,y−1), (x,y−2); **10** if (x+1,y−1), (x,y−1), not (x−1,y−1), (x,y−2); **11** if (x+1,y+1), (x,y+1), not
   (x−1,y+1), (x,y+2).

A negative x−2 reads the row before, and a negative y−2 reads off the front of the buffer, as the bytes do; the check script treats y−2 < 0 as land and
no tile is affected. Segment (+0, +4) = the land pixel; +8 type; +0xC province id (unread); +0x10/+0x14 the colour offset (below); +0x18/+0x1C = −1 until
filled; +0x44 = 0. Counts: TFH 95,015 segments, types 1..15 = 11358, 11563, 12180, 13385, 6785, 6573, 4609, 4862, 7409, 7297, 6588, 584, 657, 552, 613. BlackICE
94,653.

**The colour offset, a quirk.** The 0x6C-byte per-province entry's offsets vector (+0x5C) holds 1 entry for a pixel with no map.bin cut and 2 for one with
a cut (raster byte & 0xF ≠ 0). The second entry is (dx, 0), with dx −1 for bit 2 or 4 and +1 for bit 8 or 1, in that test order (section B's 0x456DF0). The
beach reads offsets[i] with **i the pixel's index in the pixel list, not the entry index**, so an earlier flagged pixel's second entry shifts what later
pixels read. Colour = the province raster at (x + dx, y + dy) of the segment's land pixel, 0 outside the map, written as bytes 00, id>>8, id&0xFF, 00. TFH:
1,747 segments have a non-zero offset, 223 of them land on another province; BlackICE 1,750 and 224. Without map.bin's raster, 108 TFH tiles differ in piece 5
alone. This refines `FINDINGS-mapdraw.md` A.1's 1.3% "another land province" (the rest of that figure is ordinary overlap of the strip).

**Geometry of a segment** (all in tile-local floats; mx = 50·col+25, my = 50·row+25; every step float→double, operate, round to float at each store). Points
are (integer − mid) + 0.5.

Straight, types 1..11, 7 vertices, 15 indices. A, B, M from (x,y):

| t | A | B | M |
| --- | --- | --- | --- |
| 1 | (0,−1) | (0,0) | A + ½d |
| 2 | (−1,0) | (−1,−1) | A + ½d |
| 3 | (0,0) | (−1,0) | A + ½d |
| 4 | (−1,−1) | (0,−1) | A + ½d |
| 5 | (1,−1) | (0,0) | (0,−1) |
| 6 | (−1,0) | (−2,−1) | (−1,−1) |
| 7 | (−1,−2) | (0,−1) | (−1,−1) |
| 8 | (−2,0) | (−1,−1) | (−1,0) |
| 9 | (−1,−1) | (0,−2) | (0,−1) |
| 10 | (−1,−2) | (0,−1) | (−1,−1) |
| 11 | (0,0) | (−1,1) | (−1,0) |

d = (B−A) normalised: s = FloatSqrt((float)(dy²+dx²)), inv = (float)(1/s), components (float)(c·inv). P = d×(0,0,−1), normalised the same way, negated with
(float)(·−1): effectively (d.y, −d.x). Qk, k = 0..3: q = A + (float)((float)(d·k)·0.3333333432674408), per axis with the rounding as written; D =
displacement(q); Qk = q + (float)(D·P). Vertices A, B, M, Q0, Q1, Q2, Q3; indices (M,A,Q0), (Qk,Qk+1,M) for k = 0..2, (Q3,B,M).

Corners, types 12..15, 8 vertices, 18 indices:

| t | P0 | P1 | P2 | P3 |
| --- | --- | --- | --- | --- |
| 12 | (1,0) | (1,−1) | (0,0) | (0,−1) |
| 13 | (−2,−1) | (−2,0) | (−1,−1) | (−1,0) |
| 14 | (−1,1) | (0,1) | (−1,0) | (0,0) |
| 15 | (0,−2) | (−1,−2) | (0,−1) | (−1,−1) |

e1, e2 = normalised P1−P0, P2−P0. Q0 = P0 + D(P0)·e1, Q1 = P1 − D(P1)·e1, Q2 = Q0 + D(Q0)·e2, Q3 = Q1 + D(Q1)·e2. Vertices P0..P3, Q0..Q3; indices (0,4,2), (4,2,6),
(6,2,7), (7,2,3), (5,7,3), (1,5,3), each plus the segment's base.

Link fields: straight near = Q0 (index base+3), far = Q3 (base+6), start = A (base), match = M; corner near = Q1 (base+5), far = Q0 (base+4), start = P1 (base+1),
match = P0.

**Second pass.** After every first-pass index, one triangle per segment in list order: (start, near, third). BeachSegments_FindNearest over the list in order
skips any segment with the same x, y and type; distance = FloatSqrt((float)(dy²+dx²)) with dx, dy = (float)(start − other.match); the first strictly smaller value
wins, from 1e17f; accepted only if under 2.0f. If accepted and FloatSqrt of the squared distance between this segment's near point and the other's far point is
under 1.0f, third = the other's far index; otherwise third = this segment's near index, a degenerate triangle. So 18 or 21 indices per segment. A tile with no
segments has vertex count 0: QuadBuild_Beaches is not called and piece 5 is W = 0 with no piece 6.

**Displacement.** D(x, y): fBm with point (x, y, 0), H = 0.3f, lacunarity 0.4f, octaves 5.0 (the three doubles at VA 0x160A3E8/0x160A618/0x160A508). Exponent table,
six doubles, frequency = 0.4^i: exponent[i] = pow(frequency, −H). It lives in WaterObject +0x428C and is made on first use. Value: Σ i<5 of (double)noise3(point)·
exponent[i], the point multiplied by (float)0.4 each octave (in double, stored float); value < −5.0 gives 0. Result f = (float)value; if f < 0, f = −f; while f >
0.5f, f = (float)(f·0.5). noise3 is Perlin's reference routine, float results of double arithmetic: t = (float)(v + 4096.0), b0 = (int)t & 255, r0 = (float)(t −
(float)(int)t), r1 = (float)(r0 − 1.0); s_curve = (float)((3−2t)·t²) with (3−2t) in double and t² exact; at3 = (float)((q1·ry + q0·rx) + q2·rz); lerp =
(float)((b−a)·t + a); the z-plane is 0, so sz = 0 and only the b.. + 0 gradients count, q2 only by a signed zero. **Perlin_Init**: for i in 0..255: p[i] = i, then
g1[i], g2[i][2], g3[i][3], each (float)(rand() % 512 − 256) · 0.00390625, **not normalised** (6 `rand()` per i, 1,536 calls), then for i = 255..1: k = p[i], j =
rand() % 256, p[i] = p[j], p[j] = k (255 calls); tables copied to [256..513].

**n, the only input the map files do not give.** `CRT_rand` is MSVC's `holdrand = holdrand·214013 + 2531011; return (holdrand >> 16) & 0x7FFF`, per thread, starting at
1. The image has no `srand`: of 59 calls to `_getptd`, none stores to +0x14 and one reads it, which is `rand` itself, the positive control. Perlin_Init runs once, on the
first beach of the process, so its tables are those after n earlier `rand()` calls on that thread. Measured by brute force (unique among the first 3,000,000 values
each time):

| cache | n |
| --- | --- |
| TFH shipped | 292 |
| BlackICE GitHub | 1140 |
| BlackICE 15.1 | 1140 |
| BlackICE 16.0 | 364 |
| BlackICE 16.1 | 364 |

*Not established*: which callers make those earlier calls. There are 29 sites, among them GUI and particle-looking code at VAs 0xAAC8E0.., 0xB161B0, 0xB1ADB5 (a 10,000-entry
table, so it cannot be on this thread before the first beach), 0xB1B0B0, 0xB4C160.. and the CRT itself. So n is a property of a particular run, not derivable from the
files. **For a map the original never built there is no right n; a reimplementation needs a chosen n, and must be given the original's to match its cache.** The exponent
table and the noise tables persist across tiles in a process.

**Pieces in the record.** Piece 5 = 12·V bytes, position floats then colour; piece 6 = 16-bit indices, first-pass then links. TFH totals: 941 tiles with beaches of 1,774,
667,511 vertices, 572,496 triangles, 141,831 wave records, largest tile 9,892 vertices and 25,503 indices. BlackICE: 954 of 1,787, 664,975 vertices, 570,322 triangles,
142,110 wave records.

**Surf floats.** The 52 float tuples (type → 4 floats) are identical across both caches and are in the check script, keyed by type. They are *measured* from the caches and
consistent with C.7's "fixed per branch"; the generator's stores were sampled for a few types and not walked for all 52 in the executable. C.7's generator itself is reproduced
exactly on both maps: 141,831 and 142,110 records, in order.

**Facts about the input maps.** The BMPs' stored row 0 is the map's north, so engine y = H−1−stored row. `provincecache.bin` holds the province raster in the same stored
order. CMap +0x21F8 = is_sea by province id, from `default.map`'s `sea_starts`; an unknown id is not sea.

**Not established.** The callers behind n (above). The per-province ordering is confirmed by these bytes, not by reading the list's sort beyond section A's account.

**Corrections.** `FINDINGS-mapdraw.md` C.7: "the pixels appear to be stored relative to the template's +0x2C/+0x30" is confirmed, and the walk order is now read, not measured.
A.1: the colour's province is the land pixel's offset by the quirk above, not always the pixel's own.

Frontier: 0xACD40 (push_back of a float onto a vector, used by the displacement), 0x472220 (vector resize), 0x472290 (segment vector grow), 0x46D760 (segment copy), 0x7A0FFE
(`_getptd`), 0x808620 (`_CIpow`), 0x80BDD0 (`_CIsqrt`).

## D. The two rasters: `map.bin` and `border_bitmap.bin`

*Read 2026-11-08 (fragment `mapcache-rasters.json`). The rule is hardcoded in the executable; its inputs are mod files
(`provinces.bmp`, `definition.csv`, `default.map`'s `sea_starts` and `max_provinces`, `region.txt`, `rivers.bmp` for the list).*

**The check.**

| map | file | agree | differ |
| --- | --- | --- | --- |
| TFH | map.bin | 12,144,137 of 12,144,137 (head and list 5,800, raster 12,138,337) | 0 |
| TFH | border_bitmap.bin | 48,553,348 of 48,553,348 (byte 0, 1, 2, 3 each 12,138,337 of 12,138,337) | 0 |
| BlackICE | map.bin | 12,144,209 of 12,144,209 (head and list 5,872, raster 12,138,337) | 0 |
| BlackICE | border_bitmap.bin | 48,553,348 of 48,553,348 (byte 0, 1, 2, 3 each 12,138,337 of 12,138,337) | 0 |

The same script also matches `provincecache.bin` with 0 pixels different on both maps (its rows are in the file's stored order).

### D.1 Inputs and notation [confirmed unless marked]

W × H is the province raster's size (5616 × 2160). **The engine's row y is H−1−s, where s is the rows-in-file index of
`provinces.bmp`** (the file's first stored row is y = H−1). So y counts from the south; `positions.txt` agrees (province 1 at y ≈
2100, s ≈ 60).

`P(x,y)` is a province id. It comes from the 24-bit colour through `definition.csv`, whose id field is parsed `atoi`-style, so an
empty id is 0. A colour in no row gets id 0 (TFH 14,188 pixels, BlackICE 14,217). Where TFH lists a colour twice, once with a real id
and once with an empty id, the real id wins. Taking the first row seen reproduces the raster whole; whether that is "first wins" or
"an empty id does not register" the data cannot separate.

Each id below `max_provinces` has a template (`CMap::LoadMapFiles`' loop, VA 0x48A153), **id 0 included**. A raster id at or above
`max_provinces` would read out of bounds; neither map has one.

Inputs per id:

- `land(id) = not sea(id)` (template +0x22, set in the constructor from the sea flag at VA 0x4A94AC).
- `sea(id) =` CMap +0x21F8[id], 1 for ids in `default.map`'s `sea_starts`. `CMap::LoadKey`'s `sea_starts` case parses the list into
  +0x21E8, and `LoadMapFiles` makes the byte array. (This settles section B's "inferred".)
- `reg(id)` = the first region in `region.txt`'s file order that lists the id (only ids below `max_provinces` count), 0 if none.
  Compared by identity. **+0x358's first node is this.**

Controls: last-listed region gives 82,285 (byte 0) and 109,209 (byte 3) differences on TFH; regions blank 173,827 and 250,767; all
provinces land 184,013 and 11,771; no template for id 0 gives 14,045 differences in byte 1.

### D.2 map.bin [confirmed by whole-file agreement]

Written by `MapBinCache_Save` (VA 0x487C90). Layout:

- 12 bytes `MAP_CACHE\0\0\0`, read as 8 bytes then a dword `E`.
- int32 2, int32 3.
- int32 N, then N × (int32 x, int32 y) (river sources).
- (W+1) × (H+1) raster bytes, row y first from the south.

Size is 24 + 8N + (W+1)(H+1): TFH 12,144,137 (N = 722), BlackICE 12,144,209 (N = 731). 2 and 3 are constants compared whole by
`MapBinCache_Load` (*inferred* a format version pair); a difference makes the file be built again.

River sources: every `rivers.bmp` pixel of index 0, in y = 0.., x = 0.. order, y in engine terms.

Raster: start at 0. Two passes over x 1..W−2, y 1..H−2, pixels read in row order (y ascending, then x). c = P(x,y), l = P(x−1,y), r =
P(x+1,y), d = P(x,y−1), u = P(x,y+1), ld = P(x−1,y−1), rd = P(x+1,y−1), ul = P(x−1,y+1), ur = P(x+1,y+1). m is the raster.

Pass 1 (only where d ≠ 0):

1. Where c ≠ l, l = ld = d and sea(d) = sea(c): **m[x,y] = 2 as a whole-byte store** (VA 0x4877F2; the `and 0xF0` before it is dead),
   and m[x−1,y] |= 0x20.
2. Where c ≠ d, d = rd = r and sea(d) = sea(c): m[x,y] = (m[x,y] & 0xF0) | 8, and m[x+1,y] |= 0x10.

Pass 2 (only where c is land, not sea and not 0):

1. Where m[x,y] & 0xF = 0, c ≠ l, l = ul = u, l land and not 0, c = d = r, m[x,y+1] & 10 = 0 and m[x−1,y] & 10 = 0: m[x,y] = (m & 0xF0) |
   4, m[x−1,y] |= 0x20.
2. Then where m[x,y] & 0xF = 0, c ≠ r, r = ur = u, r land and not 0, c = d = l, m[x,y+1] & 10 = 0 and m[x+1,y] & 10 = 0: m[x,y] = (m &
   0xF0) | 1, m[x+1,y] |= 0x10.

Meaning, *inferred* from the rule: the low nibble says which corner of the pixel is cut (2 SW, 8 SE, 4 NW, 1 NE), the shapes being the
staircase steps at corners; 2 and 8 between any two provinces of equal sea-ness, 4 and 1 between land ones only. 0x20 means "the pixel
to my east is cut on its west"; 0x10 means "the pixel to my west is cut on its east".

| value | TFH | BlackICE |
| --- | --- | --- |
| 0 | 11,723,253 | 11,723,073 |
| 1 | 4,549 | 4,547 |
| 2 | 95,484 | 95,570 |
| 4 | 3,647 | 3,643 |
| 8 | 104,306 | 104,322 |
| 16 | 107,326 | 107,353 |
| 32 | 98,243 | 98,313 |
| 48 | 1,529 | 1,516 |

Pixels with 16 or 32 set (TFH): 207,098.

**Readers** [exe]. The cache object is reached only through `g_MapBinCache` (11 sites) and WaterObject +0x418C (6 sites: the
constructor, the destructor at VA 0x84FCF0, `FUN_00863c60` which clears the river list, and these). Readers of the raster:
`CBorderManager_FillBitmap`, `BorderManager_UpdateControllerBits` and `BorderManager_ApplyDiagonalCuts` take only the low nibble.
`QuadBuild_AddPixelEntries` (rva 0x456DF0) tests 1, 2, 4, 8 only. **`QuadBuild_RunQuad` (rva 0x448EE0) tests 1, 2, 4, 8 and 0x20**,
twice (VA 0x848F39, 0x848F7F), then looks at the byte at x+1 and moves the run's end by the cut there. That is the land mesh's bend.

No reader of 0x10 was found. The method: these are the only functions that reach the raster, and they test it by bit, and the same scan
found 0x20. So the absence is a reading of those functions, not of the whole image.

### D.3 border_bitmap.bin [confirmed by whole-file agreement]

(W+1) × (H+1) entries of four bytes, row y first from the south, no header; TFH and BlackICE 48,553,348 bytes. `border_bitmap.bin` holds
the bitmap as `CBorderManager_Construct` wrote it. Bytes b0..b3; scratch masks A (province, +0x60) and B (region, +0x64). P, reg, land, m
as above; "template exists" is true for every id, so the 0xFF and null-template branches do not fire on these maps.

**Stage A** (y = 1..H−1):

- b0(0,y) |= 1 and b0(1,y) |= 2.
- For the pair (x, y−1) and (x, y) with x = 0: if the two are of equal land-ness and different ids, A(0,y) |= 0xC where reg equal, B(0,y)
  |= 0x1C where not. These scratch entries never reach the file directly.
- For x = W−1: b0(W−1, y−1) |= 8 (or 0x18 where the regions differ) and b0(W−1, y) |= 4 (or 0x14).

**Stage B** (x = 1..W−2, y = 1..H−2; the pixel's own values only, all independent):

- b1 = 0x40. b1 is 0xFF only with three or more null templates among the pixel and its four neighbours, which never occurs. In a running
  game with a player the byte would instead be shaded by template +0x21 (below).
- b0 = 0, A = 0, B = 0.
- For each neighbour n in (x+1,y) bit 1, (x−1,y) bit 2, (x,y+1) bit 4, (x,y−1) bit 8, with m the raster at that neighbour and mask 0xE,
  0xB, 0xA, 0xF respectively:
  - if c and n are both land, not 0 and n ≠ c, and (m & mask) = 0: A |= bit where reg(c) = reg(n), else B |= 0x10 | bit;
  - if both sea, not 0 and n ≠ c, and (m & mask) = 0: A |= bit (never a region bit).

**Stage C** (corner merges, in this order on the pixel's A and B; rc = reg(c), rR, rU, rL, rD = reg of the right, up, left, down neighbour):

1. If (A = 1 or B = 0x11) and (A = 4 or B = 0x14): rc = rR and rc ≠ rU gives A = 7, B = 0; rc ≠ rR and rc = rU gives A = 3, B = 0.
2. If (A = 2 or B = 0x12) and (A = 4 or B = 0x14): rc = rL and rc ≠ rU gives A = 11, B = 0; rc ≠ rL and rc = rU gives A = 12, B = 0.
3. If (A = 8 or B = 0x18) and (A = 1 or B = 0x11): rc = rD and rc ≠ rR gives A = 14, B = 0; rc ≠ rD and rc = rR gives A = 13, B = 0.
4. If (A = 8 or B = 0x18) and (A = 2 or B = 0x12): rc = rL and rc ≠ rD gives A = 0, B = 0x13; rc ≠ rL and rc = rD gives A = 15, B = 0.

**Stage D** (in raster order, for pixels where b0, A or B is not 0 and mm = m[x,y] & 0xF is not 0). The sequence runs in order; each test
uses A, B as they stand and may read neighbours' masks as already changed this pass:

| test | sets b3 | then clears |
| --- | --- | --- |
| A & 5 and mm & 1 | 2 | A bit 4 unless A(x,y+1) has 8; A bit 1 unless A(x+1,y) has 2 |
| B & 5 and mm & 1 | 0x12 | B bit 4 unless B(x,y+1) has 8; B bit 1 unless B(x+1,y) has 2 |
| A & 10 and mm & 2 | 2 | A bit 8 unless A(x,y−1) has 4 and is not 13; A bit 2 unless A(x−1,y) has 1 |
| B & 10 and mm & 2 | 0x12 | B bit 8 unless B(x,y−1) has 4 and **A**(x,y−1) is not 13; B bit 2 unless B(x−1,y) has 1 |
| A & 9 and mm & 8 | 1 | A bit 8 unless A(x,y−1) has 4; A bit 1 unless A(x+1,y) has 2 |
| B & 9 and mm & 8 | 0x11 | B bit 8 unless B(x,y−1) has 4; B bit 1 unless B(x+1,y) has 2 |
| A & 6 and mm & 4 | 1 | A bit 4 unless A(x,y+1) has 8; A bit 2 unless A(x−1,y) has 1 |
| B & 6 and mm & 4 | 0x11 | B bit 4 unless B(x,y+1) has 8; B bit 2 unless B(x−1,y) has 1 |

Then B = 0x10 becomes B = 0. The 13 in the two A(x,y−1) tests is written as a whole-value compare in the code and is kept.

**Stage E** (in raster order), for each pixel by its current b3:

- **b3 & 3 = 0** (no cut from stage D). b3 is set from the map.bin neighbours, by the first that matches: S = m(x,y−1), E = m(x+1,y), W =
  m(x−1,y), N = m(x,y+1).
  - S & 3: code 4, against the SW neighbour's region.
  - S & 0xC: code 5, against SE.
  - E & 3: code 6, against NE.
  - E & 0xC: code 5, against SE.
  - W & 3: code 4, against SW.
  - W & 0xC: code 3, against NW.
  - N & 3: code 6, against NE.
  - N & 0xC: code 3, against NW.
  - Otherwise b3 is left at 0.
  - Add 0x10 where the pixel's region differs from that diagonal neighbour's. (SW = P(x−1,y−1), SE = P(x+1,y−1), NE = P(x+1,y+1), NW =
    P(x−1,y+1).)
- **b3 not 0 and B = 0**: A's bits spread to the neighbour across, unless that neighbour's A is a corner value (3, 7, 11, 12, 13, 14, 15,
  19):
  - bit 2 sets A(x−1,y) |= 1 unless **A(x,y)** is a corner value. **This first test reads the pixel's own entry** (the original's slip, VA
    0x835C4E);
  - bit 1 sets A(x+1,y) |= 2 unless A(x+1,y) is one;
  - bit 4 sets A(x,y+1) |= 8 unless A(x,y+1) is one;
  - bit 8 sets A(x,y−1) |= 4 unless A(x,y−1) is one.
- **b3 not 0 and B ≠ 0**: B's bits spread, the guard always reading A of the neighbour:
  - bit 2 sets B(x−1,y) |= 0x11 unless A(x−1,y) is a corner value;
  - bit 1 sets B(x+1,y) |= 0x12 unless A(x+1,y) is one;
  - bit 4 sets B(x,y+1) |= 0x18 unless A(x,y+1) is one;
  - bit 8 sets B(x,y−1) |= 0x14 unless A(x,y−1) is one.

These spreads are live across the pass: an earlier pixel's spread changes what a later one reads and which of the two branches it takes.

**Stage F** (each pixel in x 1..W−2, y 1..H−2): eight (B, A) pairs become one code, with B cleared. The list is (0x11, 4) → 3, (0x14, 1) → 7,
(0x14, 2) → 11, (0x12, 4) → 12, (0x18, 1) → 13, (0x11, 8) → 14, (0x12, 8) → 15, (0x18, 2) → **3** (as read, kept). Then b0 |= A | B.

**Stage G** (y = 1..H−1): b1(0,y) = b1(1,y) = b1(3,y), b1(W−1,y) = b1(W−2,y) = b1(W−3,y).

Byte 2 is never written. Row y = H and column x = W stay 0; row 0 has no bits set.

| lane | TFH | BlackICE |
| --- | --- | --- |
| byte 1 | 64 in 12,119,328 pixels, 0 in 19,009 (rows 0, H−1, H and column W) | the same |
| byte 2 | 0 everywhere | 0 everywhere |
| byte 3 | 0 in 11,257,639 pixels; 1..6 and 17..22 otherwise | 0 in 11,257,215 pixels; 1..6 and 17..22 otherwise |
| byte 0 | 0..31 (0 in 11,387,152 pixels; TFH has one 31) | no 31 |

Column 0 of byte 0 is 1 in rows 1..H−1, on both maps. Column W−1 has 88 nonzero values in byte 0.

**The in-game arm** [exe]. Where `g_CCurrentGameState->in_game` is set with a player (player id ≠ 0), b1 would be 0x28 if the pixel's template
+0x21 is set, 10 less for each of the four neighbours' +0x21 set, clamped at 0xFF. FillBitmap runs from `CBorderManager_Construct` under
`CreateWorld`, where no player exists (*inferred*, from `in_game` having no writer but a game's enter), so this arm does not reach the file.

**What +0x21 is.** A per-province byte set by the constructor to 0, by `CProvince_ResetState` to 0, and written from a flag by `CInGameIdler` slot
56 (VA 0x6731AD), beside `CProvince +0x36D`. Its fog-of-war meaning is *inferred*; not established.

### D.4 Corrections to `FINDINGS-mapdraw.md` and the record

- **B.7, `map.bin` bytes**: the builder's two passes are as above. The low nibble is the cut; values 16 and 32 are the marks on the pixel across the
  cut. B.7's "the border code reads only the low nibble" is right as far as it goes. **The quad builder also reads 0x20**.
- **B.7 and the record**: byte 1 is 0x40 in the interior and 0 in rows 0, H−1, H and column W. 0xFF never occurs; the +0x21 arm is the in-game one.
- **FillBitmap's old comment** had "three or more have no template" as a live case: every id has a template, id 0 included, so it is not.
- **C.6 and A.1**: the row convention `y = H − 1 − s` is confirmed for `provinces.bmp` and `rivers.bmp`, and `provincecache.bin` is the raster in the
  file's stored order (not engine row order).

**Not established.** What template +0x21 means exactly. Whether the (0x18, 2) → 3 pair in stage F is a slip in the original (it is kept). What the 2
and 3 in the head are beyond being compared. The behaviour for a raster id at or above `max_provinces`, which neither map has. Whether duplicates in
`definition.csv` are "first wins" or "an empty id does not register" (TFH has two such pairs, which the raster cannot separate).

Frontier: 0x66C1B0, 0x66D080, 0x66C880, 0x66C7D0, 0x3C62C0, 0x3C6440, 0x22760, 0xA3C0 (`FUN_0040a3c0`, the parser of the int list).

## F. The rest of the folder

*Read 2026-11-08 by the collecting session (fragment `mapcache-provinceraster.json`), when the five other files were added to OpenHOI3's builder. Every file is byte for byte on the shipped cache, on BlackICE's, and on the original's own rebuild in the Documents folder of 2026-11-08, whose noise count (section C) was 1,140. `quad_format.bin` is not in BlackICE's folder.*

- **`provincecache.bin`** [exe] (`CMap_LoadProvinceRaster`, `ImageObject_SaveBmp`): a 16-bit Windows bitmap. Head: `BM`; file size **`width + 3 x height + 0x6E`**, in every branch of the writer, where a size in bytes belongs (5616 + 6480 + 110 = 0x2FAE on both maps, and nothing reads it); two zero reserved words; offset 0x36; the 40-byte header with the width, the height **positive**, 1 plane, 16 bits, no compression, sizeImage 0, both resolutions 0xB12, no colours. Then the rows **from the north**, height − 1 down to 0, the positive height notwithstanding: the image object's +0x24 byte says so. A pixel is its id: black and white are 0 without a look, a colour no row names is 0.
- **`adjacencies.bin`**: for each province from id 0, a count and that many 20-byte records, the five fields of `ProvinceEdge` in order (kind, to, through, distance in thousandths, bearing).
- **`navaldist.bin`**: as `FINDINGS-seaair.md`, section 4.
- **`climate.bin`**: `LoadProvinceClimate`, an int32 for each province **from id 0**. Province 0's template has no point, so it reads the climate image at (0, 0): 158 on both maps.
- **`quad_format.bin`**: A.5's layout. Its second list is counted 4 where the declaration ends at 3 (its end marker third), so it carries one element past the end - method 0, offset 0, stream 0, type 3 - read from the static memory after the array.

**The original checks nothing else against `time`**: `CMap +0x28` alone decides (FINDINGS-mapbuild.md, 2), and `CMap::LoadNavalDistances` reads its file with no fallback, so a folder whose `time` is current must hold every file.

## E. The terrain-index textures (`quad_textures/quad_texture_<tile>.dds`)

*Read 2026-11-08 (fragment `mapcache-terrainindex.json`). Every rule below reproduces all 3,561 files of the two maps unless
marked otherwise.*

**In one line.** For every land pixel of a tile's land provinces, in province-id order and south row first, four bytes are
written (the priority of the pixel's palette entry, and of its left, up-left and up neighbours) and each byte is offered to
the eight surrounding texels where still unset. The buffer is saved by D3DX as an uncompressed A8R8G8B8 DDS.

**The check.**

| map | files agree whole | texels agree | file set |
| --- | --- | --- | --- |
| TFH (`tfh/map`, cache stamp 93E125C4) | 1,774 of 1,774 | 8,098,950 of 8,098,950 | made and cached sets identical |
| BlackICE (`GitHub/BlackICE/map`, its cache in Documents, stamp 383756A4) | 1,787 of 1,787 | 8,158,457 of 8,158,457 | made and cached sets identical |

Wrong rules fail, so the comparison discriminates:

| rule | TFH files | BlackICE files |
| --- | --- | --- |
| the rule | 1,774 | 1,787 |
| raw palette index instead of priority | 884 | 1,554 |
| no spread | 0 | 0 |
| last writer wins instead of first | 30 | 0 |

**Which files, and when** (confirmed).

- `CProvinceManager_BuildQuads` walks a tile's province list and calls the per-tile builder 0x4727B0 only where at least one
  province has `is_land` (0x85ADE0..0x85AE11). So **a tile has a file if and only if it has at least one land province**:
  1,774 and 1,787, both sets exact.
- `Quad_CreateTerrainIndexTexture`: the path is `'%squad_texture_%d.dds'` over the folder. The file is made unless it exists
  and `CMap +0x28` (stale) is 0, so a stale cache is overwritten. It is then always loaded from disk.

**The rectangle** (confirmed; A.1's rule). Provinces go to tile `cx/50 + cols*(cy/50)`, with cols = width/50 + 1 and cx = x0 +
bboxw/2 [exe: 50]. The tile's land rectangle is the union of its **land** provinces' bounding boxes (x, y, w, h). Texture
size is (w+4, h+4) and offset (x-2, y-2); texel (i, j) is map pixel (offset.x + i, offset.y + j).

**The pixels** (confirmed).

- *Build path:* the entries are 0x6C-byte records per province of the tile, in list order. List order is id ascending,
  because `AssignProvincesToTiles` walks ids upward. Only land provinces' records hold pixels; a sea province's record stays
  empty.
- Each record's first vector is the province's pixels as absolute (x, y): from template `+0x6C`, south row first, west to east
  (`FINDINGS-movement.md`).
- A province's pixels are those of its colour in `definition.csv` [mod]; a colour with no row is no province. "Land" is not
  in `default.map`'s `sea_starts` [mod]. *Inferred:* `is_land`'s setter was not read; every rectangle and file agreeing with
  this test is the support.
- Engine y = height - 1 - BMP storage row. The bitmap's bit offset must come from its file header: BlackICE's `terrain.bmp`
  has a 124-byte info header and offset 1162.

**A pixel's four bytes** (confirmed unless noted). With `T[i]` the palette entry for terrain.bmp's byte `i` (terrain.txt; a
later entry claiming an index wins [mod]), and "value" meaning `T[i] +0x64`:

1. If the pixel's own entry's terrain is water (`type` -> `categories` `is_water`) [mod], **skip the pixel altogether**: no
   writes, no spread. Measured: 2 land-province pixels on TFH, 7 on BlackICE.
2. `this` = the entry's value. If negative, **2** [exe]. *(Read; not exercised: no land pixel of either map has an entry
   without a priority.)*
3. `left` = entry at (x-1, y), only if x-1 > 0 [exe]. `up-left` = entry at (x-1, y+1), only if x-1 > 0 and y+1 < map height.
   `up` = entry at (x, y+1), only if y+1 < map height. Each takes its entry's value when the entry exists and the value is
   not negative, else `this`.
   - So water and `priority`-less neighbours (`ocean1`, `pti`) and the map's top row take the pixel's own value. Measured on
     TFH: 26,809 / 36,560 / 26,560 neighbours over water, and 3,221 pixels on row 2159.
   - The x-1 > 0 test is read and not exercised: no processed pixel has x <= 1 on either map. A map with land in column 0 or
     1 would need it.
4. Scale `s = 0x100 / terrain` [mod: terrain.txt's `terrain`, 256 on both maps, integer division]. Bytes stored are
   `(s * value) & 0xFF`. *(`s` other than 1 and a non-power-of-two or zero `terrain` are not exercised; zero would divide by
   zero.)*
5. Texel `(px, py) = (clamp(x - off.x, 0, W-1), clamp(y - off.y, 0, H-1))`. The clamp never binds on the build path, since
   the rectangle covers every land pixel.
6. Bytes written directly, in order, each followed by its spread: **byte 0 = this, byte 1 = up-left, byte 2 = left, byte 3 =
   up**. In memory as A8R8G8B8 that is **B = this, G = up-left, R = left, A = up**, matching A.3.

**The spread, `TerrainOffset_SpreadByte`** [exe] (confirmed). The offered byte goes to (x, y+1), (x, y-1), (x+1, y), (x-1, y),
(x+1, y+1), (x+1, y-1), (x-1, y+1), (x-1, y-1), each only where the target is in range and that channel of the target is
still 0xFF. In range means x+1 < W, y+1 < H, **x-1 > 0 and y-1 > 0**, so column 0 and row 0 are never written.

- A land texel's own direct write overwrites whatever was spread there.
- A non-land texel keeps **the first value offered in processing order** (order is exercised on 331,248 TFH and 345,420
  BlackICE texels with rival writers).
- A value of 0xFF is indistinguishable from unset, so `s * priority == 255` behaves as a hole. Neither map has one: max
  priorities 231 and 253.
- Because land is at least 2 texels inside the rectangle, the texture's outer ring (columns 0 and W-1, rows 0 and H-1) is
  always 0xFF. A.3's "0xFFFFFFFF outside the land" is true only beyond the fringe: 532,083 texels on TFH and 531,873 on
  BlackICE hold spread values.

**The file** (confirmed).

- `D3DXCreateTexture(W, H, 1 level, usage 0, A8R8G8B8, SYSTEMMEM)`, buffer copied in,
  `D3DXSaveTextureToFileInMemory(D3DXIFF_DDS)`, bytes written through `VirtualFile_Open` and 0x66D080.
- 128-byte header, exactly: `'DDS '`, 124, flags 0x1007, height, width, pitch 0, depth 0, mipcount 0, 44 reserved zero bytes;
  pixel format 32, 0x41, fourcc 0, 32 bits, masks R 0x00FF0000, G 0x0000FF00, B 0x000000FF, A 0xFF000000; caps 0x1002, then
  zeros.
- Then W x H x 4 bytes, row y = off.y (south) first, each row west to east, BGRA.

**Behaviour to know.** A file missing on the *load* path (`CProvinceManager_LoadQuads` -> `Quad_FillEntriesFromTileProvinces`)
is built from **all** provinces of the tile, sea zones too, so a sea zone's non-water pixels (40 on TFH, 80 on BlackICE) would
be clamped onto the rectangle. The shipped caches were not built that way and this path was not tested (inferred from the
code). `priority` on a palette entry is a [mod] number the shipped files happen to set equal to the index, except `ocean1`
(254) and `pti` (255), which have none.

**Corrections to A.3.** Its "mapping not read" is `priority` as above, with the neighbour and water fallbacks and the fringe
explaining the disagreement. Channels confirmed. Its "0xFFFFFFFF outside the land" holds only beyond the one-texel fringe.

**Not established.**

- The constructor default of `CMap +0x2A7C` and behaviour at any `terrain` other than 256.
- The load-path fallback's real output.
- What sets `is_land`, which was not read; the record's other readers cover it.
- Everything of `0x440E90` past its purpose.

Frontier: 0x456DF0 (per-pixel entry adder: pushes the absolute pixel and other vectors, called from both builders), 0x46B510
(vector set-up before 0x456FD0's loop), 0x66D080 (VirtualFile write), 0x32290 and 0x32460 (log stream helpers), 0x6759D0 (the
graphics-ready test at the head of the loading text).
