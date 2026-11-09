# The tooltip over a unit's counter

*Read 2026-11-07 from the unpatched vanilla `hoi3_tfh.exe`, by a delegated agent (fragment `unit-counter-tooltip.json`),
for the counter tooltip in OpenHOI3. Addresses are virtual (base 0x400000) unless marked rva. Every offset and address is
valid only for this build.*

When the mouse is over a unit's counter on the map, `CInGameIdler::GetTooltip` (slot 20, VA 0x6627D0) asks the hovered
selectable's slot 3 (`FINDINGS-selection.md` A.6), not ProvinceTooltip_Build. For a unit, slot 3 is
**`CUnit::BuildTooltip`**, VA 0x5C4B20, rva 0x1C4B20. It is the same body in all four tables (`vtable.py --holding
0x5C4B20`: CUnit 0x15C85CC, CArmy 0x15BDE0C, CNavy 0x15C869C and CAir 0x15C8774, each at slot 3, and no other class). So
land, naval and air units build the same text, and differ only in which list of units is read (section 2).

## 1. Shape

- **Extent**: 0x5C4B20 to the single `ret 8` at 0x5C5AB5, then eight `int3`. A script over every `jcc`/`jmp` in the body
  found none leaving 0x5C4B20–0x5C5AB8, so nothing lies past the `ret` (trap 3). An SEH frame (handler 0xC7D416) and a
  0x138-byte frame.
- **No padding before it**: `CUnit_SetName` (0x5C48E0) ends `ret 4` at 0x5C4B1D and slot 3's `push ebp` is the next
  byte, so `functionStart` inside the body answers 0x5C47E0 (trap 2).
- **Convention**: `GuiTooltipText* __thiscall CUnit::BuildTooltip(CUnit* this, GuiTooltipText* out, CMapProvince*
  province)`, result in EAX. The callee cleans 8 bytes and returns `out`.
- **`province` is never read** - [ebp+0xC] has no use in the body. Both callers pass one: CInGameIdler::GetTooltip at
  0x662B41, and CPort::GetTooltip at 0x4942A4, where the port asks the first fleet in its list and puts that fleet's
  text after `PORT` (`FINDINGS-seaair.md` section 6). The shape matches ProvinceTooltip_Build's `(out, province)`.
  *confirmed*
- **The output record**: the GuiTooltipText is constructed in place - `text`, `delayed` and `delayed_extra` emptied
  (length +0x10/+0x2C/+0x48 to 0, capacity +0x14/+0x30/+0x4C to 0xF, first byte 0), `position` (+0x54) 0 and `below`
  (+0x58) 1 - and only `text` is written after that. **On the map the caller overwrites `position` and `below`**:
  CInGameIdler::GetTooltip copies the record and sets the position to the minimap's corner less (50, 20) with `below`
  false, exactly as for a province (`FINDINGS-tooltips.md` section 4). So the counter's tooltip box stands above the
  minimap's corner, wherever the counter is. *confirmed*

## 2. Which units it lists

1. **The list.** By default the hovered unit's province's units, `this->current_province_ptr (+0x130)->units (+0x2B8)`:
   the CUnitList every unit is appended to as it enters (0x4A5A30, at the tail +0x2BC, counted in +0x2C0), so **in the
   order the units entered the province**. *confirmed*
   - **A fleet in a land province** (slot 16 IsNaval, and the template's `is_land`, +0xD4 → +0x22) reads its port's list,
     `province->port (+0x354)`, the CUnitList at CPort +8: the fleets lying there. CPort::OnSelected turns that list on
     every click on the port, so its order changes as the player clicks. *confirmed*
   - **An air unit at its base** (slot 17 IsAir, `home_base_ptr` +0x98 not null, and the base object's slot 0 answering
     the unit's own province) reads the base object's list at +4: the units based there - by the record's comment on
     CMapProvince +0x54, summed as the airfield's occupancy, so plausibly including units based there and flying
     elsewhere. *inferred*
   - Anything else - an army, a fleet at sea, an air unit away from its base - the province list.
2. **The filter.** A unit `u` of that list is skipped where *confirmed off the listing 0x5C4DC0–0x5C4E1C*:
   - `u` is a land unit (slot 15) and the province is a sea zone - the land units aboard a fleet hovered at sea;
   - the hovered unit is a land unit, `u` is a fleet, and the province is land - the fleets in port under a hovered army.

   **There is no test of owner, alliance or visibility, and no cap**: every country's units at the place are listed, and
   the hovered unit's own `intel_level` gates the whole tooltip - so hovering an enemy the player knows little of shows
   the player's own units in the same province with `?` too. Air units in a land province are not filtered under a
   hovered army, so they are listed with it where they are in the province's list; that an air unit at its base sits in
   +0x2B8 rests on 0x4A5A30 appending whatever unit it is given, and was not traced. *inferred*
3. For each unit that passes, three things are collected:
   - **its owner** (`owner` +0x124 / `owner_id` +0x128), added to a list unless that id is in it already - so in order of
     first appearance;
   - **the leader**: the best so far starts as `g_NullLeader`, whose name the CNullLeader constructor (0x57F380) sets to
     the localised `NO_LEADER`. The unit's leader (+0x12C) replaces him where **(its `rank` +0x6C ≥ his and its `skill`
     +0x70 > his) or he is not valid** (CLeader slot 8: 0xA92590 `mov al,1` on CLeader, 0x592360 `xor al,al` on
     CNullLeader). The first unit with a leader always replaces the null one; after that a lower rank never replaces, an
     equal rank needs strictly more skill, and a higher rank with less skill does not replace either. So the choice
     hangs on the list's order and is not "the highest rank". *confirmed*
   - **its brigades**: each regiment of `regiments` (+0x38), in list order, appended to a bucket by `sub_unit_definition_ptr
     (+0x58) → type_index (+0x24)` - one bucket per CSubUnitDataBase definition. *confirmed*

## 3. The text, line by line

Every literal was read with `image.read`; none is a localisation key. The one localised word is the null leader's name.

| address | bytes |
| --- | --- |
| 0x15C49F4 | `@` |
| 0x15B4E94 | ` ` |
| 0x15C82BC | `?\n` |
| 0x15B57D0 | `\n` |
| 0x15BD2DC | ` £` (0x20 0xA3) |
| 0x15C82D8 | `? £unknown` (10 bytes, no line break) |
| 0x15C82CC | `? £unknown\n` |
| 0x15C82C8 | `? £` |
| 0x15C82C0 | `{0` |
| 0x15C82C4 | `{10` |
| 0x15B4945 | the empty string |

**The head line**, only where at least one unit passed the filter:

    for each owner, in order of first appearance:  "@" + TAG + " "
    then  intel_level < 5 :  "?\n"
          otherwise       :  the chosen leader's name (CLeader +0x4C) + "\n"

`@TAG` draws the country's flag, 23 by 11, the pen moving 24 (CEU3BitmapFont::DrawFlagIcon/FlagIconWidth). Where no
listed unit has a leader the name is `NO_LEADER`: `(no leader)` in the base game's `localisation/misc.csv`, `§W(no
leader)§W` in BlackICE's, taken as the null leader is made. [exe: the layout; mod: NO_LEADER]

**The body**, always, after the head:

    intel_level < 3:   "? £unknown"                         - once, and the text ends there
    otherwise, a line for each sub unit type with a brigade among the units, by type_index:
      intel_level >= 8:  N + " £" + key + " " + a strength icon per brigade
                         (" " after every fifth, the last included) + "\n"
      intel_level 6-7:   ("" where N < 10, else " ") + N + " £" + key + "\n"
      intel_level 3-5:   the type's priority (+0x194) >= 6 :  "? £" + key + "\n"
                         otherwise                         :  "? £unknown\n"

`N` is the number of that type's brigades among all the listed units, `_itoa` in base 10; `key` the definition's key
(+0x8). **`£` and a name draw the unit counter `GFX_counter_` + name**, a 30 by 16 quad, the pen moving 30
(CEU3BitmapFont::DrawCounterIcon/CounterIconWidth, `FINDINGS-productiontooltip.md` section 7) - so the key is never seen
as text, and a line is a count, a counter picture and, at 8 or more, bars. `£unknown` draws `GFX_counter_unknown`, which
the base game and Their Finest Hour both define.

Kept as read, though they look odd: at 6–7 a space goes **before a two-digit count** and not before a one-digit one (the
literal is `""` under 10 and `" "` from 10, `cmp eax,0xA; jl` at 0x5C575D); at 3–5 every low-priority type gets **its
own** `? £unknown` line, not one for all; and under 3 the single `? £unknown` has no line break.

[exe: layout and thresholds; mod: `priority` in `units/*.txt`. In Their Finest Hour: hq_brigade 11; the armour types 10;
most infantry 7–9; artillery, anti-tank, anti-air 3; police and engineers 2; transports 1; destroyer 4; light cruiser 5;
heavy cruiser 6; interceptor and multi_role 5; tactical and naval bombers 3; cas 2]

**The strength icon**, per brigade, in bucket order (the unit list's, then the regiments'):

    max = CSubUnit::GetMaxStrength(brigade, false, false)      ; slot 12, *out
    max <= 0                                   -> "{10"
    ratio = strength (+0x5C) * 1000 / max      ; truncated; __allmul/__alldiv when
                                               ;   strength + 0x189373 > 0x39580D (unsigned)
    t = ratio * 10000 / 1000                   ; __allmul/__alldiv, i.e. 10 * ratio
    t >= g_UnitTooltipFullStrength (9900)      -> "{10"
    otherwise                                  -> "{0" + _itoa(t / 1000)   ; "{00" .. "{09"

So the frame is `floor(10 × strength / max)`, 10 from 99.0%. Strength and max are thousandths of the definition's
`max_strength`; GetMaxStrength applies RESERVES_PENALTY_SIZE to a reserve brigade. [exe: the 9900, `(int)floorf(9900.499f)`
from the float at rva 0x120AACC, made on first use behind the guard bit at VA 0x1BEBFE4; no define moves it]

**What `{NN` draws.** CEU3BitmapFont::DrawText (slot 8, 0xAFC070) at 0xAFD00E reads the two bytes after `{` as decimal
(`(d1−'0')×10 + (d2−'0')`), calls slot 23 (0xAF9820, forwarding to slot 22, 0x8403A0) with kind 3 and that frame, and
moves the pen **8**; GetStringWidth counts 8 too. Kind 3 is the sprite **`GFX_tooltip_strength`** - kind 0 is
`GFX_tooltip_money`, which `¤` draws; the table is built by 0x83FA70 through 0x83F8D0. In the install that is
`interface/tooltipicons.gfx` (and `tfh/interface`), `gfx/interface/tooltip_strength.dds`, 176 by 20, `noOfFrames = 11`: a
frame 16 by 20, whose opaque pixels are columns 5–10 and rows 2–18 in every frame (measured) - a row of 6-pixel bars, 8
apart. Slot 22 draws the frame as a quad of frame width × texture height, x to x+16 and y−20 to y, each less 0.5. [mod: the
sprite and its art]

**Example**, read and not seen in a running game: two of the player's German infantry divisions (intel 9) under one
leader, three infantry brigades at full strength and one at 95%, and two artillery brigades:

    @GER <leader's name>
    2 [artillery counter] ▮▮
    4 [infantry counter] ▮▮▮▮

each ▮ a frame - `{10{10`, then `{10{10{10{09`; the type lines in type_index order.

## 4. What does not change it

No test of a unit in battle, moving, retreating or carrying, or of the player's own, beyond the intel level - and the
player's own units are at 9 (`FINDINGS-counters.md` section 5), so their counters always get the full form. Land, naval
and air differ only in the list chosen and the two filters of section 2. Ships and wings are brigades like any other, so a
fleet's lines count `destroyer`, `light_cruiser` and the rest, a bar a ship.

## 5. Functions it calls

| VA | name | what for |
| --- | --- | --- |
| 0x40A160 | std::string::assign | the literals |
| 0x433B40 | std::string::appendChars | `?\n`, `{10`, ` `, `\n`, `? £unknown\n` |
| 0x433E30 | std::string::appendString | each line built |
| 0xA5B0D0 | std::string::operatorPlus | concatenation |
| 0xA5B150 | std::string::operatorPlusChars | `"{0"+n`, `" "/""+n`, `"? £"+key` |
| 0xB9A0C4 | **_itoa** (new) | counts and frames |
| 0xB9602F / 0xB95F9B | operator_new / free | buckets, nodes |
| 0x57F380 | CNullLeader::CNullLeader | g_NullLeader made lazily (an inlined CLeader::null) |
| 0x5AE0C0 | CSubUnitDataBase::~CSubUnitDataBase | the inlined lazy creation of g_CSubUnitDataBase |
| 0xB99AF0 / 0xB99980 | __allmul / __alldiv | the share |
| 0x401FD0 / 0xC08870 | floorf / _ftol2_sse | the 9900 |
| virtual | CUnit slots 15/16/17 (IsLand/IsNaval/IsAir), CSubUnit slot 12 (GetMaxStrength), CLeader slot 8 (valid), the base object's slot 0 (its province) | |

**Frontier** (unnamed): 0x45F300 (clears a list of 0x14-byte nodes, next at +0xC, in ECX - the owners here); 0x649D80
(frees a heap CList's nodes, next at +8, and the list, list in EDI; seven callers); 0xAB9B90 (`vector<T*>` grow, vector
in EAX); 0xB94BEC (a thunk to operator_new, operator new[] in shape); 0xB99220 (memset in shape).

## Not established

- Whether an air unit at its base is in its province's +0x2B8 list, and so listed under a hovered army.
- Whether the base object's list (+4) includes units based there and away on a mission.
- The order of type_index - the order of CSubUnitDataBase's definition array; the loader's fill order was not read.
- What y DrawText passes to slot 22, so where a `{NN` bar sits against the line's text: the quad spans y−20..y.
- Whether the space before a two-digit count at 6–7 was meant; kept as read.
- Other callers of CUnit slot 3 than CInGameIdler::GetTooltip and CPort::GetTooltip: a `[reg+0xC]` call is CPersistent's
  slot 3 everywhere, so a slot-call scan cannot tell them apart cheaply.
- None of it was set against a running game.
