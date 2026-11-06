# The map's far view

What the original changes as the map is zoomed out: the shaders, what is drawn and the country names. Read 2026-11-06,
statically, in a wave of two readers - section A, what decides far against near and what changes with it (fragment
`farmap-switch.json`); section B, the country names (fragment `farmap-names.json`). Addresses are rvas unless marked VA
(VA = rva + 0x400000), valid only for this build. **[exe]** hardcoded in the executable; **[mod: file]** a file can change
it. `confirmed` unless marked.

## A. What decides far against near, and what changes with it

**In one line.** There is no one switch: four thresholds on the camera's height (`MapCamera +0x348`), each tested every
frame and none with hysteresis - the shaders and the per-country far layer on default.map's `terrain_sheet_heights`
(500 in TFH) [mod]; buildings, counters, clicks and the hierarchy lines at a hardcoded 500.0 [exe]; land borders at
default.map's `border_cutoff` (500.0) [mod]; far against near counters at settings.txt's `counter_distance` [mod].
`WaterSimple` is the `simpleWater` setting, not a third band. Map style 0 - written only by the Terrain and Weather modes -
keeps the land on `TerrainShader_Graphical` at every height and leaves the far per-country layer out.

**Corrections.** `FINDINGS-mapmode.md`'s style table is wrong in most rows (A.3: Theatre is 14, not 0; Weather 0, not
0xB-0xF; Diplomatic 6; Infrastructure 9). `FINDINGS-camera.md`'s missing compare, the one that hides counters and
buildings, is in `MapObjects_UpdateLayerVisibility`. `FINDINGS-counters.md` section 7's "who calls slot 92": nothing on
the path - the avatar's +0x152 is written inline by CUnit's and CNavy's slot 36. `CMap +0x2A80` is `tree`, an int.

### A.1 Four thresholds on one figure

The figure is the map camera's height, `MapCamera +0x348`, 40 to 1000 [exe], 330 at the start [exe]
(`FINDINGS-camera.md`), so a new game opens near. Everything below compares the current height with a fixed figure
every frame. The height eases toward the wanted one by 0.197 of the difference a frame, or jumps at once with
`use_legacy_camera`; so a zoom crosses each line over a few frames, and nothing holds a state once it is crossed.

| threshold | in TFH | set by | what it switches |
| --- | --- | --- | --- |
| `terrain_sheet_heights` (`CMap +0x40`) | **500** | [mod: map/default.map], `CMap::LoadKey` | the land and beach shaders, water Far/Near, terra incognita Far/Near, the surf line, the texture sheet, the far-only per-country layer (the names) |
| the double 500.0 at VA 0x160A538 | **500** | [exe] | the building pictures and the counters; clicks on counters, buildings and battles; the hierarchy lines |
| `border_cutoff` (`CMap +0x2050`) | **500.0** | [mod: map/default.map] | whether land borders are drawn at all |
| `border_heights` (`CMap +0x30`) | **150, 500** | [mod: map/default.map] | which of three border textures |
| `counter_distance` (`GameSettings +0xFC`) | **100** in a new game; slider 0-500 | [mod: settings.txt `mapRenderingOptions`] | near counters or figures against far counters (avatar +0x152) |
| the double 100.0 at VA 0x160A358 | **100** | [exe] | trees, the tile-strip rebuild, the layer under mask bit 0x8 |
| the float 150.0 at VA 0x15E3170 | **150** | [exe] | object group +0x44 (contents not read) |
| `tree` (`CMap +0x2A80`) | **350** | [mod: map/default.map]; 400 from the constructor | the trees' fade; dead in TFH, A.2 |

None of them is a define; only `counter_distance` is a settings.txt key.

**How a level is counted.** Each draw counts its level off a list of thresholds: 1 + the index of the last entry the
height is strictly above, or 0 for none. Terrain, beaches and the names test "level > 0"; water and terra incognita
"above any entry"; the surf counts entries exceeded. With TFH's one entry all agree: **far is a height above 500.0,
strictly**. The hardcoded object layers show "while 500 > height" - so at exactly 500.0 the shaders are still near and
the buildings and counters already gone. The original's edge, kept.

**On screen.** From height h the camera sees 0.828·h map units from the top of the screen to the bottom
(`FINDINGS-camera.md`); the far view starts at about 414 map units of map on screen.

**Three bands for counters** stand as `FINDINGS-camera.md` had them: under `counter_distance` the near counter or the
figures, from there to 500 the far counter, from 500 nothing. **A mod that moves `terrain_sheet_heights` does not move
the 500 [exe]**: the two "far"s can come apart, and a reimplementation keeps them as two figures.

**Where the tests run, each frame:** `MapGraphics_DrawScene` (0x45BE50), from the game screen's frame (0x25704B), the
front end (0x2EED3F) and 0x29EBF2; `MapGraphics_Update` (0x45C6F0), from the graphics owner's update (0x241D00); and the
draws they call - `MapGraphics_DrawTerrain` (0x45DFB0), `_DrawLandBorders` (0x45E9B0), `_DrawBeaches` (0x45EF50),
`_DrawWater` (0x45F6E0), `_DrawTerraIncognita` (0x4602E0), `MapShore_Draw` (0x432C70).

### A.2 What changes

**Land - `MapGraphics_DrawTerrain` (0x45DFB0), gfx/FX/terrain_2_0.fx.** Map style (`GameSettings +0xF4`) **0**:
`TerrainShader_Graphical` at every height [exe]. Any other style: `TerrainShader_General` near, `TerrainShader_General_Low`
far. Its tex6 is always the level's own texture sheet - texturesheet.tga near, texturesheet2.tga far - the loader making
`texturesheet` + (i+2) + `.tga` for each entry of `terrain_sheet_heights`; so the Terrain mode's far view is Graphical
with the second sheet. What each draws [mod: gfx/FX/terrain_2_0.fx]:

- *Graphical*: the sheet's tiles (four samples blended by noise) half and half with colormap.dds (tex4); greyed and
  brightened by the province texture's blue (winter), darkened by its red (fog of war), its green added; no province
  colour.
- *General* (near): the same tiles half and half with colormap_political.dds, greyed; then 70% grey terrain and 30% of
  the two province colours (each less 0.7) blended by stripes.dds (tex7), all times 1.5.
- *General_Low* (far): **no terrain tiles** - 70% colormap_political.dds and 30% of the striped province colours
  overlay-blended with map_overlay_tile.dds (tex5), times 1.5: the political colour map with a tint of province colour
  and a paper texture. The weights as the file writes them; not set against a screenshot.

**Beaches - `MapGraphics_DrawBeaches` (0x45EF50)**: the same switch; style 0 `BeachShader_Graphical`, else
`BeachShader_General` near and `BeachShader_General_Low` far, the far one 70% colour map and 30% province colour, no
tiles.

**Sea - `MapGraphics_DrawWater` (0x45F6E0), water.fx.** `simpleWater` (`GameSettings +0xE5`) on: `WaterSimple` /
`WaterSimpleColor` at every height - a flat (0.3, 0.4, 0.5) with fog of war - **the third "level" is a setting** [mod:
settings.txt `simpleWater`]. Otherwise far `WaterFar`: colormap_water.dds × 0.8, no waves, overlay-blended with
map_overlay_tile.dds, black where there is no fog-of-war value; near `WaterNear`: colormap_water.dds lit by four
animated normal-map samples with specular, `Time` set on this branch alone. The `…Color` variant for map styles 16, 18
and 19 (`FINDINGS-mapmode.md`) lerps the sea 0.8 toward the striped province colours.

**Terra incognita - `MapGraphics_DrawTerraIncognita` (0x4602E0)**: far `TerraIncognitaFar`, near `TerraIncognitaNear`,
drawn only while a scenario is loaded (`CCurrentGameState +0xD0C` not null), so never in the full game. In the install's
terraincognita.fx both compile the same `PixelShader_TIFar` with the same states: **the switch changes nothing [mod]**.

**Land borders - `MapGraphics_DrawLandBorders` (0x45E9B0), `TerrainShader_Border`**: drawn only while `border_cutoff` >
height and layer-mask bit 0x2 is set, **so the far view has no land borders** [mod: default.map `border_cutoff`]; below
it the texture steps by `border_heights` (150, 500) - borders.tga under 150, then borders2.tga, then borders3.tga (the
"+2" of the second and third names *inferred* from the texture-sheet loop's identical shape). The pixel shader takes the
province, country and diagonal lines from that one texture. The water borders (0x45DD50, `WaterBorderShader`, mask 0x200)
have no height gate in the scene.

**Surf - `MapShore_Draw` (0x432C70), beach.fx** (*inferred*, only the technique choice read): near `BeachShader`, the
shore texture added; far `BeachShaderColor`, a black coastline at 70% alpha. Drawn where graphics +0x42E9 is set (not
identified).

**Counters and figures.** `MapGraphics_Update` sets far = height > `counter_distance` (strict); `ProvinceGraphics_Update`
hands it to every unit's slot 36, `CUnit::UpdateAvatar` (0x1CD040) or `CNavy::UpdateAvatar` (0x1CF290), which writes
`CHoiAvatar +0x152` (seen from far) **inline**, with the near counter's `order` (+0x1A8) - the unit's place in its
province - and the marks. Slot 92 (`SetSeenFromFar`) is not on this path. `MapObjects_UpdateLayerVisibility` (0x45BBB0)
then shows the 18 unit layers at graphics +0x4158 (*inferred* from the mask bits; 0x800 is counters): under
`counter_distance` with counters on, the near-counter layer if `always_counters`, the figure layers if not; from
`counter_distance` to under 500 [exe] the far-counter layer; **from 500 none**.

**Buildings.** The building-picture group (graphics +0x5C, mask 0x20) and the group at +0x70 (`GameSettings +0xE7`) show
only under 500 [exe] - the compare `FINDINGS-camera.md` could not find.

**Trees** are drawn only under 100 [exe] and with mask bit 0x1; inside, default.map's `tree` (350) cuts them off above
it and fades them from 0.3·tree - with TFH's 350 the fade starts at 105, so **trees are at full strength when drawn and
vanish at 100**. Only the Terrain and Weather modes have them: every other mode's mask clears bit 0x1.

**Rivers** (0x47C8A0, mask 0x80): no height gate in the scene call; a grep of the river draw's first 0x1000 bytes finds
no read of the height where the same grep finds it in the tree draw - a negative with that limit.

**Country names.** The scene calls 0x43ED10, a per-country layer, only where the level is above 0 (far by
`terrain_sheet_heights` [mod]), the map style is not 0, and no scenario is loaded; it is handed the camera's settled x
and y and uses the per-country dirty bytes at VA 0x1A8C388 - set by a change of controller (old and new), faction changes,
vassalage, annexation and the rest (B.4). It is the country-name layer: section B.

### A.3 The map mode

The far view is the same in every mode but for what style 0 does. Each mode's setter writes the style [exe]:

| mode | style | mode | style |
| --- | --- | --- | --- |
| 0 Terrain | **0** | 10 Resources | 20 |
| 1 Political | 2 | 11 Weather | **0** |
| 2 Diplomatic | 6 | 12 Revolt | 2 |
| 3 (unnamed) | 8 | 13 Simplified Terrain | 8 |
| 4 Supply | 9 | 14 deployment | 11 |
| 5 Infrastructure | 9 | 15 (set at 0x2773C1) | 16 |
| 6 Intel | 12 | 17 | 2 |
| 7 VP | 13 | 18 Air | 18 |
| 8 Theatre | 14 | 19 Naval | 19 |
| 9 Strength | 15 | | |

The front end sets style 2. **Terrain and Weather (style 0)**: land and beaches Graphical at every height - only the
sheet changes far - and no country names. **Every other mode**: the land goes from General to General_Low at 500 and the
names appear. The water switches Far/Near in every mode, styles 16, 18 and 19 with the coloured variants. Borders,
counters, buildings and terra incognita take no map mode into account; trees do, through the layer mask alone.

This corrects `FINDINGS-mapmode.md`'s style table, which had Theatre at 0, Weather at 0xB-0xF, Diplomatic and mode 3 at
2, Infrastructure at 8 and Intel and VP at 9. Its water conclusion stands: only 16, 18 and 19 pass the colour test.

### A.4 Not established

What 0x43ED10 draws (section B); which unit layer at graphics +0x4158 is which beyond the mask bits; the groups at +0x44,
+0x60 and +0x70 and what `GameSettings +0xE7` is; the graphics +0x42E9 byte that gates the surf; what 0x4608D0 (mask
0x8, under 100) and 0x6BB7E0 do; five of the eight `+0x170` call sites `slotcalls.py` lists for slot 92; the "+2" of the
two border loops. **A hand decision**: `WaterObject` is the whole map-graphics object (the graphics owner's +0x1DC4), not
the water alone - a rename the merge cannot make; by its RTTI it is **`CProvinceManager`** (its constructor, 0x44F570,
writes the vftable VA 0x15E3384 the export gives that class; B.1).

Frontier: 0x4608D0 (B.5), 0x47C8A0, 0x45DD50, 0x463930, 0x45F450, 0x241D00, 0x6BB7E0.

## B. The country names

**In one line.** In the far view every country owning land, but `REB`, gets one name, laid over the piece of land it
controls that is joined to its capital: along a least-squares line through that land [exe], its letters sized against
the line's length and the land's area and spaced with blanks [exe], then bent along a Catmull-Rom spline through the
middle of the land [exe], in the bitmap font of the country's faction [mod: interface/core.gfx `neutral_country`,
`comintern_country`, `axis_country`, `allies_country`] chosen by the faction's `icon` [mod: common/ideologies.txt], in
the colour of the font's atlas - TFH's are black with alpha, so the names are black [mod: gfx/fonts/*.tga]. A name is
rebuilt only when its country is marked dirty, and drawn without a fade.

**Corrections.** The strings "maptext", "mapfonts" and "mapfont" are not strings of their own: they sit inside
"animatedmaptext" (VA 0x15EA960, the `objectTypes` keyword, token 0x135), "bitmapfonts" (VA 0x15EA81C) and
"bitmapfont" (VA 0x15EA828). **`gfx/FX/maptext.fx` is named nowhere in the image** - every `.fx` literal listed;
`mapobject.fx` is found, `maptext.fx` not (checked again by the collecting session): a leftover file, **and the names use
no shader and no signed-distance texture** - the fixed pipeline from the font's ordinary atlas. `WaterObject` is
`CProvinceManager` (A.4). A.2's guess that 0x43ED10 is the name layer is right; A.4's 0x4608D0 is the near map's
**province** names (B.5).

### B.1 The text system, and which font

There is no map-text registry. `mapTextType` (token 0x5D) makes a 0x90-byte object type (`MapTextType_Construct`
0x717060, its table at 0x1205D78, no RTTI) whose CreateInstance is C3dObjectType's - a plain 3D object; core.gfx declares
one, `MapText`, and **nothing looks it up**: "MapText" exists only as the tail of "MessageMapText" (VA 0x15CFFEB),
unreferenced, where "MessageMapText" itself (VA 0x15CFFE4) is found pushed by ShowMessageMapText (the positive control).
The `animatedmaptext` blocks name the font "MaptextFont", which no `.gfx` of the install defines; what the lookup then
does was not read.

**The names' fonts.** The `CProvinceManager` constructor loads five fonts by name [exe the names, mod the fonts], each
tried in the graphics' `fonts` (+0x88), then `bitmapfonts` (+0x94):

| offset | name looked up | TFH core.gfx | BlackICE core.gfx |
| --- | --- | --- | --- |
| +0x4178 | `tahoma_60` | kart_font, 0xff333333 | tungsten |
| +0x417C | `neutral_country` | kart_font, effect yes | eldon |
| +0x4180 | `comintern_country` | Kyril, effect yes | Typingrad |
| +0x4184 | `axis_country` | old_english, **effect no** | godofwar |
| +0x4188 | `allies_country` | trebuchet_45, effect yes | acie |

`tahoma_60` is the province names' font (B.5). The other four are read in one place, **and not at these offsets**:
through the map object (state +0xBE8, slot 15) at `+0x5F40 + 4 × index` (0x43E420) - 0x5F40 being 0x1DC4, where that
object builds its `CProvinceManager`, plus 0x417C. **The index is the country's faction's `icon`** (CFaction +0x3C), 0
for a country in no faction (the faction's slot 7 false for the shared no-faction object); TFH's icons are comintern 1,
axis 2, allies 3 [mod: common/ideologies.txt]. An `icon` above 3 reads past the table into +0x418C (*inferred* risk; no
bound check). *Trap note*: a sweep of all .text (3,084,578 instructions) finds no read of +0x417C..+0x4188, while it
finds both reads of +0x4178 and every store - a negative that would have called the four faction fonts dead; the read is
through the containing object at +0x5F40.

What a font gives [mod: gfx/fonts/&lt;name&gt;.fnt and .tga]: its glyph metrics (xadvance, kerning, offsets,
`lineHeight`), its atlas, and its `effect` key - where yes, the default, the name is upper-cased by `CharUpperBuffA`
(the ANSI code page), so TFH's Axis names keep their mixed case. The font's `color` and `colorcodes` are **not read** on
this path: neither the layout (0x6FF5E0) nor the draw touches its +0x38 (*inferred* from reading both).

### B.2 Which names

- **Countries only**: one record per country id (`g_CountryMapNames`, 0x14 bytes each); no regions, no seas.
- **None** for tag id 0, a country owning no province (CCountry +0xCF8 ≤ 0), or `REB` [exe].
- **Land controlled, not owned**: a flood fill from `CCountry::GetCapitalLocation`, taken without a test, over neighbours
  (CProvinceTemplate +0x90 edges) that are land whose **controller** (CMapProvince +0x338) is the country. So occupied
  land counts for the occupier, only the piece joined to the capital is ever named - a country in parts gets one name -
  and a country fully occupied gets a fill of its capital alone.
- **The text**: `CountryNameOfTag`, the country-name table the province tooltip uses, upper-cased as in B.1. What fills
  that table was not read here.

### B.3 Where and how a name is laid out

All [exe]. Map units are provinces.bmp pixels; y is the map's y, which is the world's z.

**1. Sampling.** For each province of the piece, every second pixel of its bounding box (+0x80, +0x84, +0x88, +0x8C):
x = x0, x0+2, ..., ((w−1)>>1)+1 steps, and so for y. A pixel counts where the province raster gives **this province or
any sea** (is_land 0, lakes too) - so sea inside a coastal province's box counts, once for every box over it. Sums Sx, Sy,
Sxy, Sxx, Syy and N in 64-bit integers, and the extent in x and y. N = 0: stop, the old mesh kept.

**2. Two lines, the longer kept.** Least squares both ways, means and slopes as floats:

- A, y on x: b₁ = (N·Sxy − Sx·Sy) / (N·Sxx − Sx²), a₁ = ȳ − b₁·x̄, from (minX, b₁·minX + a₁) to (maxX, b₁·maxX + a₁);
- B, x on y: b₂ = (N·Sxy − Sx·Sy) / (N·Syy − Sy²), a₂ = x̄ − b₂·ȳ, from (b₂·minY + a₂, minY) to (b₂·maxY + a₂, maxY).

Each line's ends truncated to int, rasterised by Bresenham (`MapLine_Rasterise`, at most 256,000 points), and trimmed by
`MapLine_TrimToCountry` with sea allowed: cut to its first and last pixels of the country's own (the visited piece and
controlled); emptied if any point is off the map; then the longest run of pixels that are own land, land with controller
0, or sea - another country's land breaks a run, the first of equal runs wins. Each line's ends ordered left to right;
**A kept where its squared length is strictly greater, else B**; L its length. **A name can cross the sea along it, never
foreign land.**

**3. Size.** With w and h the name's size in font pixels (`GetTextSize`; h the `lineHeight`):

    s = min( (L / w) × 10,  (N / L × 40) / h,  25 )

**No name** where 6 × the name's length in characters (spaces included) > L, or s < 2.5 - the old mesh released. Read:
the unspaced text spans at most half the line (w·0.05·s ≤ L/2), and its height is at most about half the land's mean
thickness (area ≈ 4N, so 0.05·s·h ≤ 2N/L) - the reading *inferred*, the formula [exe].

**4. Letter spacing.** k = 0; while w_k × s / L < 11, k += 1 and the text is made again with k blanks after every
character but the last (a space in the name gets them too), w_k the new width. Where s was not capped the ratio starts at
exactly 10, so **there is always at least one blank between letters**.

**5. Anchor.** With d = end − start and p = (−d.y, d.x)/|d|, the normal on the left of the reading direction:

    anchor = (start + end)/2 − p × (h × 0.5 × s × 0.04)

kept as the record's x and z.

**6. Letters.** `BitmapFont_LayOutTextQuads(font, -, spaced text, origin 0, up p, along d̂, s, 100000)`: the line centred,
the pen starting at −w_k/2; each glyph a quad from pen + xoffset to pen + xoffset + width along the line and from
(h − yoffset − height) to (h − yoffset) across it, all × 0.05·s; a glyph under 1 high only advances the pen, so blanks make
no quads. The vertex buffer holds 6 vertices per non-space letter of the name (XYZ|TEX1, 20 bytes, write-only), lying in
the ground plane.

**7. The bend** (`CountryMapName_BendAlongLand`). None where |end.y − start.y| ≤ 0.1: a level line stays straight.
Otherwise:

- for each letter, through its centre (vertices 0 and 3, plus the anchor) the line of slope −d.x/d.y from minX to maxX,
  rasterised and trimmed **without sea** (own piece, or land with controller 0), and the midpoint of the run left;
- F the first letter's midpoint, Lst the last's, A the mean of all;
- two outer control points: P₀ = F + |F−A|·dir(2·angle(F−A) − angle(A−Lst)), P₃ its mirror at Lst; where P₀.x > P₃.x both
  pairs are swapped, so the text still reads from the left. This closed form restates the vector arithmetic at
  0x43D1A7..0x43D39B and is the part to check first (*inferred* as geometry);
- character i of the unspaced name, n its length with spaces and t = i/(n−1), spaces skipped (a space leaves a step's
  gap): t ≤ 0.5 `D3DXVec2CatmullRom(P₀, F, A, Lst, 2t)`, t > 0.5 `(F, A, Lst, P₃, 2t − 1)`; the tangent from a second
  sample 0.01 back where that parameter is above 0.5, else 0.01 ahead, normalised;
- the quad made again centred on the sample, its own half-width (|v1 − v0|/2) along the tangent and half-height
  (|v3 − v1|/2) across it.

So **a bent name's letters sit evenly by character index from F through A to Lst**; the blanks of step 4 then matter only
for where F and Lst were found, and for a level name. Edge cases as read: n = 1 gives t = 0/0, and a line the trim emptied
has the builder read before the start of its point vector.

### B.4 When

**Built** inside the draw pass, for every record whose dirty byte is set. Records are made dirty the first time the pass,
or the builder, finds the vector empty. The byte is set by eight functions, each only where the vector exists:
`Province_SetController` (old and new controller), `CFaction::AddCountry`, `CCountry::LeaveFaction`,
`CustomGame_LeaveFaction`, `MakeVassal`, `AnnexCountry`, `CProvince_ResetState` and `RemoveLandlessCountriesFromWars` -
with the module and the exit teardown, all of the 68 operands on the vector. **Not daily**: none of them is a change of
capital alone or a country renamed, so those do not mark it (*inferred*). A change made zoomed in is laid out on the next
frame drawn zoomed out. `g_CountryMapNamesRebuildAll` (VA 0x1BEA4C1) would rebuild everything; nothing sets it
(*inferred*, with a positive control).

**Drawn**: `MapGraphics_DrawScene` calls the pass at 0x45C39D only where the zoom level is above 0 (A: the height above
an entry of `terrain_sheet_heights`, 500 [mod: map/default.map]), the map style (GameSettings +0xF4) is not 0 - not
Terrain or Weather (A.3) [exe] - and no scenario is loaded (CCurrentGameState +0xD0C null). Nothing in the names' own code
asks whether the view is far.

**How**: depth test and depth write off; alpha blend SRCALPHA / INVSRCALPHA; no lighting; linear filtering; each name
given a world translation of (x − camera x, **0.1**, z − camera z). **Colour**: the atlas texel × TEXTUREFACTOR, colour
and alpha; this pass does not set TEXTUREFACTOR - the province names save and restore it around their own use - and
TFH's atlases (kart_font, old_english, trebuchet_45, Kyril) are black ink with alpha, so the names are **black** whatever
it is [mod: the atlas]; whether its alpha is 255 there was not read. **No fade with zoom**: they appear as the height
crosses 500 and go as it falls back. **No setting turns them off** - no settings.txt key, no layer-mask bit; only the
map style, the zoom and a scenario.

### B.5 Province names, near, for contrast

`ProvinceTexts_Create` (0x456710) runs once as the map is built ("CreateProvinceTexts()"): an entry for each province of
each map tile, **sea zones included** and marked so, the template's name, with `text_position`, `text_rotation` and
`text_scale` (CProvinceTemplate +0x3C/+0x40, **+0x54, +0x58**) [mod: map/positions.txt]. Drawn only below camera
height 100 [exe] and with layer-mask bit 8, and below 100 updated each frame (0x455EA0): at most 1000 at once, font
`tahoma_60` [mod: core.gfx], wrapped at 320, a name over 50 characters cut to 49 (each buffer 300 vertices, 50 letters),
the scale text_scale × 0.5; each fades in at alpha = (now − start) × 170, capped at 255 [exe; the clock's unit not
read], set as `TEXTUREFACTOR = alpha<<24 | 0xFFFFFF`. **Between heights 100 and 500 neither kind of name is drawn.**

### B.6 Not established

TEXTUREFACTOR when the country names are drawn, so whether they are fully opaque; who sets a province entry's shown byte
(+0x44); what 0x4564A0 does; the `MaptextFont` lookup failure; what fills the country-name table, so whether dynamic names
reach the map; the thirteen other object-type cases of 0x670550; the two callees of CountryMapNames_Reserve (0x43F650,
0x43F530).

Frontier: 0x43F3E0, 0x43F530, 0x43F650, 0x43F6E0, 0x4564A0, 0x298D10, 0x240600, 0x46B620, 0x4E7F90.
