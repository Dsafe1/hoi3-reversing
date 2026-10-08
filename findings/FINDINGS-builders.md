# The four windows a unit is ordered from

*Read 2026-10-08 for OpenHOI3's builder windows; the mechanics spec is
`OpenHOI3/docs/mechanics/builders.md`. Addresses are VA / rva. Everything here is one build
of `hoi3_tfh.exe`.*

The production screen owns seven dialogs (`FINDINGS-countryviews.md`, section 4). Four of
them order units: `division_designer`, `ship_builder_window`, `air_builder_window` and
`brigade_builder_window`. This is what each shows, what its buttons do, and what it posts.
`FINDINGS-buildqueue.md` has what happens to the order afterwards.

**How it was read.** The four `Update` routines are between 2,300 and 4,000 instructions each.
They were decompiled headless out of a copy of the Ghidra project with the record applied
(`ghidra/DecompileAt.java`) to find the shape, and every figure below that says `confirmed`
was then read in the listing, because the decompiler loses track of which stack slot is which
in functions this size - it had the designer's sums and its maxima confused. Where only the
decompiled C was read the claim says `likely`.

## 1. The family

All four are `CReloadableInterface` classes with the same seven slots:

| slot | what | designer | ship | air | brigade |
| --- | --- | --- | --- | --- | --- |
| 0 | rebuild the window and re-attach `accept` and `cancel` | `0x7E4430` | `0x808D30` | `0x7D0360` | `0x7D8770` |
| 2 | show | `0x7E43E0` | `0x808C30` | `0x7D0330` | `0x7D8730` |
| 3 | hide | `0x7E4410` | `0x7D8760` | `0x7D8760` | `0x7D8760` |
| 4 | **update, every frame it is open** | `0x7E4EE0` | `0x80AA10` | `0x7D1350` | `0x7D9A10` |
| 6 | the tooltip builder (`BUILD_*_IRO` / `_DRO` keys) | `0x7EA930` | `0x80D420` | `0x7D3AB0` | `0x7DC090` |

and the same order panel, by the same element names in each window's own file:

- **`serial_plus`, `serial_minus`, `parallell_plus`, `parallel_minus`** (the spellings are
  the files'). Each has a handler for the press and one for the hold. The press sets a
  "first repeat" byte and restarts a timer; the hold fires when the timer has run **0.3 s the
  first time and 0.1 s after** (`0x160A418`, `0x160A410`, doubles), adding or taking 1, or
  **10 while the key the game screen's input object answers at slot 12 is down** - `likely`
  shift; which key was not read. The ten-step subtraction floors at 1; the one-step relies on
  the button being disabled. Designer: `0x7E4740` serial +, `0x7E4830` parallel +, `0x7E4920`
  serial -, `0x7E4A20` parallel -, timer test `0x7E46B0`. `confirmed`
- **`serial_value`, `paralell_value`** are the two counts as plain integers. A minus button
  is disabled under 2 and a plus button at 99. `confirmed`
- **`ic_cost_value`** = the unit's IC a day times `parallel`, two decimals.
  **`mp_cost_value`** = its manpower times `serial * parallel`, two decimals.
  **`build_time_value`** = its days times `serial`: up to 365 as `N` + `' '` + the text of
  `DAYS`, above as `N / 30` + `' '` + the text of `MONTHS`. `ic_cost_label` is the text of
  `PW_IC_COST`. `confirmed` (designer `0x7E7807`..`0x7E862E`)
- **The traffic light.** `selected_brigade_green`, `_orange` and `_red` are hidden, then
  one is shown:

      spare = CCountry::GetICPart(production) - CCountry::GetUsedIC()
      green   if spare - cost >= 0          ; cost is ic_cost_value's figure
      orange  else if spare > 0
      red     otherwise

  `GetICPart` (`0x503D10`) is the IC the production share has; `GetUsedIC` (`0x4F4B60`) is
  the `Cost` of every line of the queue added up. `confirmed` (`0x7EA69B`..`0x7EA7F0`)
- **`accept`** has the text of `START_PRODUCTION` and is disabled when the country's manpower
  is under `mp_cost_value`'s figure, and for each window's own reasons below.
- **`cancel`** and a finished `accept` both go through `0x7D9890`, which hides the window
  (slot 3) and tells the game screen (its slot 37 with 1).
- **`on_complete_icon`** and **`on_complete_impact`**: the practical the unit gives. The icon
  takes the sprite `'icon_'` + the key of the type's technology category when a sprite of
  that name exists, and the text is `'+'` + the type's `completion_size` through
  `0xA5ABC0 / 0x65ABC0` - the number with only the decimals it needs, `+0.2`, `+2`.
  `confirmed` for the formatter; `likely` for the rest.

**Custom game mode.** Each routine reads the first byte of the custom game settings
(`0x41C4E0`) and, when it is set, prices by points instead: `accept` says `BUILD`, the label
is `CGM_IC_COST`, the build time and `serial` are hidden, and `paralell_label` becomes
`DIVISIONS_TO_BUILD` / `NAVIES_TO_BUILD` / `AIRS_TO_BUILD` / `BRIGADES_TO_BUILD`. Not read
past that.

## 2. The division designer

`CDivisionDesigner`, vftable `0x15DE138`, constructor `0x7E39A0 / 0x3E39A0`. Window
`division_designer`, with a second window of its own, `brigade_picker` (`CBrigadePicker`,
held at `+0x1C4`), which is shown and hidden with it.

| | |
| --- | --- |
| `+0x20` | the window |
| `+0x150` | `parallel`, starting at 1 |
| `+0x154` | `serial`, starting at 1 |
| `+0x184` | the template on show, `-1` for none |
| `+0x1B4` | **the design**: a `CList` of unit types (`+0x1BC` its count) |
| `+0x1C4` | the brigade picker |
| `+0x1C8`, `+0x1CC` | the manpower and the IC a day last worked out |
| `+0x1D0` | the softness last worked out |
| `+0x1D4` | the text of the terrain tooltip |
| `+0x1F0`, `+0x1F4` | the repeat timer and its "first repeat" byte |

### What may go in it

`CBrigadePicker::Populate` (`0x7ED1F0 / 0x3ED1F0`) empties the list `queue` and, for every
unit type in the database's order:

    if (type.is_land && type.is_buildable
        && CCountry::CountMaxUnitsStillBuildable(country, type) >= 1)
            make the type's definition at the country's levels, and insert it in order

`CCountry::CountMaxUnitsStillBuildable` (`0x4E13A0 / 0xE13A0`, the game's own name out of the
Lua API):

    if (!technology_status.unit_available[type])            return 0     ; +0x27C
    if (!SubUnitDefinitionIsUsableBy(country tag, type))    return 0     ; usable_by
    if (type has an available_trigger && it is false)       return 0
    if (minimum_of_type < 1 && max_percentage_of_type < 1)  return 1000000
    all  = the country's brigades of the type's branch
    have = its brigades of this type
           + size of every queue line building one, per brigade of the type
           + one for each in a unit waiting to be placed
    return max(0, max(minimum_of_type - have,
                      all * max_percentage_of_type / 1000 - have))

`likely` past the three early returns: the counting was read in the decompiled C only.

**So an elite brigade is rationed**: `alpini_brigade` has `minimum_of_type = 6` and
`max_percentage_of_type = 0.04`, which is six of them, or four in a hundred of the army,
whichever is more.

Each entry is a `brigade_entry_2` window (`CPossibleBrigadeEntry`, `0x7EE4A0 / 0x3EE4A0`),
filled from the definition **with every technology at the country's level**:

| element | figure | decimals |
| --- | --- | --- |
| `name` | the type's name | |
| `counter_type` | sprite `'GFX_counter_'` + key, if there is one | |
| `counter_size` | frame 1 | |
| `str` | `max_strength * 100` through the suffix formatter below | |
| `org` | `max_organisation` | 0 |
| `cw` | `width` | 0 |
| `sa`, `ha`, `aa` | soft, hard and air attack | 0 |
| `piercing`, `armored` | `piercing_attack`, `armor` | 0 |
| `def`, `tou`, `ad` | defensiveness, toughness, air defence | 0 |
| `sof` | `softness * 100` + `'%'` | 0 |
| `speed` | `max_speed`, the speed formatter | |
| `sup` | suppression | 0 |
| `sc`, `fc` | supply and fuel consumption | 2 |
| `ic` | `CCountry::GetBuildCostIC(country, definition, levels, false)` | 2 |
| `mp` | `CCountry::GetBuildCostManpower(country, definition, false)` | 2 |
| `time` | `CCountry::GetBuildTime(country, definition, levels)` | whole |
| `off` | `officers` | 0 |

`levels` is the sum of the levels the definition was made with, which is what makes a
brigade a hundredth dearer and slower for each (`FINDINGS-buildqueue.md`, section 2).
`confirmed` (`0x7EEB7A`..`0x7EF948`)

**The line's button is coloured by combined arms group**: `select` takes the sprite
`'GFX_divdesigner_listbutton'` + the type's `unit_group` as a number, when a sprite of that
name exists (`0x7EE5B6`..`0x7EE6EB`). The base game has `GFX_divdesigner_listbutton1` to
`5`, one a group. `confirmed`

**The suffix formatter**, `0xAB7380`: a figure whose whole part is under 1000 is written
whole; above that `0xAB7260` divides by a thousand as often as it can and appends `k`, `M`
or `G` (`0x1601250`, `0x15C7714`, `0x15B5A68`) - so 3000 men is `3k`, cut and not rounded.

**The speed formatter**, `0x5A5460`: no decimals, except that a speed under 2 whose
fraction is more than 0.09 takes two.

**Sorting.** The twenty-one `sort_*` buttons share one handler (`0x7EDD80 / 0x3EDD80`). It
makes a comparator for the button - `CPrioComparator` for `sort_prio`,
`CStrengthComparator` for `sort_str`, and so on - gives it the button's own byte from
`+0x2C` on, flips that byte, and populates again. A comparator is a vftable and one byte:
`compare(a, b)` answers `a.field < b.field`, or `a.field > b.field` with the byte set. The
insert (`0x7EFB70`) walks back from the end of the list while the comparator says yes and
puts the new one after the first it says no to. **So the first click on a column sorts it
largest first, the second smallest first, and ties keep the database's order.** The picker
starts on `CPrioComparator` with the byte clear: `priority` (`+0x194`), largest first.
`confirmed` (`0x7D76D0`, `0x7D7710`, `0x7EDDF6`..`0x7EDE09`, `0x7ED0D0`)

The comparators read the **definition's own** fields - `CICCostComparator` reads
`BuildCostIC` (`+0xF8`), not the figure the `ic` column shows, which has the country's laws
in it. For one country the order is the same.

### Adding and taking out

`select` on an entry calls `CDivisionDesigner::AddBrigade` (`0x7EA880 / 0x3EA880`):

    if (count < (BRIGADES_IN_DIVISION + technology_status.division_size) / 1000)
        insert the type by a CPrioComparator with its byte clear      ; 0x7EA8FF..0x7EA90C
        rebuild `brigade_queue` ; work the design out again

**So the design is kept in the order of its types' `priority`, largest first**, equals in
the order they were clicked - not in the order clicked. Its first brigade, which is what a
division is named for (section 3), is the one of the highest priority: armour's 10 comes
before infantry's 7, so a division with a tank brigade in it takes a panzer division's
name. A template is copied in as its file has it, unsorted. `confirmed`

`technology_status +0x1C` is what the technology key `division_size` adds up to
(`0x5374F0` adds `technology +0x1C * scale`); one technology of the base game has it,
`superior_firepower`, so four brigades become five. `confirmed`

`brigade_queue` holds one `brigade_entry` (`CSelectedBrigadeEntry`, `0x7EC540 / 0x3EC540`)
for each: `name`, `counter_type` as above, `counter_size` frame 1, and `cancel`, whose
handler (`0x7EC900`) takes that one out of the list.

### The design, worked out (`0x7E6160 / 0x3E6160`)

Called after every change. For each brigade it makes a regiment of the type with every
technology at the country's level, and adds up:

| element | what | decimals |
| --- | --- | --- |
| `size_value` | the number of brigades | |
| `allowed_value` | `(BRIGADES_IN_DIVISION + division_size) / 1000` | |
| `str_value` | the sum of `max_strength`, as men (below) | |
| `org_value` | **the average** of `max_organisation` | 0 |
| `cw_value` | the sum of `width` | 0 |
| `sa_value`, `ha_value`, `aa_value` | sums | 0 |
| `def_value`, `tou_value`, `ad_value` | sums | 0 |
| `sof_value` | **the average** softness `* 100` + `'%'` | 0 |
| `sup_value` | the sum of suppression | 0 |
| `sc_value`, `fc_value` | sums | 2 |
| `speed_value` | **the slowest** `max_speed`, nothing under 0, the second speed formatter | |
| `piercing_value` | **the greatest** `piercing_attack` | 0 |
| `armored_value` | **the greatest** `armor` | 0 |

`confirmed`: `0x7E6BFC`..`0x7E6D4E` are the accumulators and `0x7E86AC`..`0x7E959B` the
elements. The averages are `sum * 1000 / (count * 1000)`.

**Men**, `0x5AC500`: `strength / 1000 * 100` as a whole number (`0x1717BFC` is 100.0), then
under 1000 as it is; under 100,000 with a comma before the last three digits; under two
million in thousands with a `K`; and above in millions to two decimals with an `M`.

**The second speed formatter**, `0x5A5520`: no decimals for a whole speed, two otherwise.

**What it costs.** With `as_reserves` read off its checkbox:

    manpower = sum of CCountry::GetBuildCostManpower(country, definition, reserves)
    days     = the greatest of CCountry::GetBuildTime(country, definition, levels) * 1000
    ic a day = sum of (GetBuildCostIC(country, definition, levels, reserves) * days_i / 1000)
               * 1000 / days

which is `CMilitaryConstruction::RecalculateCost`'s arithmetic for a unit of several
brigades (`FINDINGS-buildqueue.md`, section 2). `confirmed` (`0x7E6FF6`..`0x7E71C8`,
`0x7E749B`..`0x7E74D6`)

**Combined arms.** `common/combined_arms.txt` makes the groups; a unit type's `unit_group`
is its one-based index among them, and the database holds them in a vector at its `+0x00`,
each with the byte for `base = yes` at `+0x24` and its `value` at `+0x28`. For every group
`i` the icon `combined_arms_indicator_` + `i`:

    if (some brigade of the design is in group i  AND  some brigade's group is a base one)
        frame i ;  bonus += group.value + technology_status.combined_arms_group_bonus[i]
    else
        frame i + (number of groups)                 ; the greyed half of the strip

and `combined_arms_bonus_value` = `bonus * 100`, no decimals, + `'%'`. `confirmed`
(`0x7EA11C`..`0x7EA630`) **So without a brigade of a base group - infantry, in the base
game - the design shows no bonus at all.** Whether combat applies the same rule is
`CUnit::GetCombinedArmsBonus` and was not read here.

**The terrain tooltip** (`+0x1D4`): one line for each terrain the averaged adjusters say
anything about - the terrain's name, `': '`, and what `0x5D5100` writes for the four
figures under `UA_ATTACK`, `UA_DEFENCE`, `UA_MOVEMENT` and `UA_ATTRITION` - then the same
for `RIVER_ADJUSTER`, `NIGHT_ADJUSTER`, `FORT_ADJUSTER` and `AMPH_ADJUSTER`, each with the
define's own penalty added per brigade first (`RIVER_CROSSING_PENALTY`,
`BASE_NIGHT_PENALTY`, `BASE_FORT_PENALTY`, `AMPHIBIOUS_LANDING_PENALTY`). A terrain's own
attack and defence are added in too. Read as far as that.

### The window's own update (`0x7E4EE0 / 0x3E4EE0`, slot 4)

- `save_template` is shown only while a template is on show.
- Each `divdesign_button` + `n` takes frame 2 when it is the one on show and 1 otherwise.
- `brigade_queue` is rebuilt when its length is not the design's.
- **`accept` is disabled** unless `0x4E1190` says the design may be built, and when the
  country's manpower is under the cost.
- `total_sof` is set to frame 1.

**`0x4E1190 / 0xE1190`**, the design in ECX, the country and the number of divisions on the
stack:

    allowed = (BRIGADES_IN_DIVISION + division_size) / 1000
    if (count > allowed || count < 2)                      return false
    for each brigade: if (!type.is_buildable)              return false
    for each type n times in the design:
        if (CountMaxUnitsStillBuildable(country, type) - n * divisions < 0)  return false
    return true

**A division of one brigade cannot be ordered here.** `confirmed` (`0x4E11BE`..`0x4E11D6`)

### Templates

`CCountry +0x148` is a vector of the country's templates, from `default_templates` in its
file under `common/countries`; Germany has ten. A template has its name at `+0x08` and a
`CList` of unit types at `+0x24`. The constructor attaches one handler to
`divdesign_button1`..`divdesign_button` + `n`, gives each the text of its template's name
(a localisation key, through `0x57F2D0`) and stores the index in it as text. The handler
(`0x7E4570`) empties the design and copies the template in (`0x7E45B0`), remembering which
(`+0x184`). `save_template` (`0x7E5FB0`) posts a `CChangeTemplateCommand` for that index
with the design as it stands.

**The files give twelve buttons and nothing hides the spare ones**: with ten templates the
last two keep the `.gui` file's own text and have no handler.

### Ordering (`0x7E4B20 / 0x3E4B20`)

    repeat parallel times:
        post CConstructUnitCommand(the design, the country's capital, amount = serial,
                                   is_reserve = the checkbox)
    close

## 3. The command, and the name of a new unit

`CConstructUnitCommand::Execute` is `FINDINGS-buildqueue.md`, section 5. What that left
out is the naming, which is three functions:

**`0x4CB5F0 / 0xCB5F0`**, a name for a unit of a given level, 4 being a division. The
country holds, for each unit type, a list of names (`+0xCAC`, from `unit_names` in its
file) and where it has got to in each (`+0xCBC`):

    if (level == division)
        list = country.names[first brigade's type]
        from where the country left off, once round:
            name = list[at] ; remember at ; at = (at + 1) wrapped
            if (the name is not in use) return it
    for n = 1, 2, 3 ...
        name = the text of DIVISION_NAME (THEATRE_NAME, ARMYGROUP_NAME, ARMY_NAME,
               CORPS_NAME, NAVY_NAME, AIR_NAME by level)
               with NUM = n, ORDER = the text of ST, ND, RD or TH, TYPE = the text of
               the first brigade's key + '_short'
        if (the name is not in use) return it

The ordinal is `n % 10` looked up in `TH ST ND RD TH TH TH TH TH TH`, with 11, 12 and 13
sent to `TH`. In English `DIVISION_NAME` is `$NUM$$ORDER$ $TYPE$ Division` - `1st Inf
Division`.

**`0x4CBFD0 / 0xCBFD0`**, a name for a brigade, ship or wing. **For a ship or a wing the
country's list for the type is tried first**, exactly as above; a land brigade never looks
at one - the lists under brigade types name divisions. Then `n = 1, 2, 3 ...` with
`REGIMENT_NAME` for a land brigade and `SUBUNIT_NAME` for the rest, the same three
replacements, until one is free. A name that comes out as the key itself, or empty, is
returned as it is.

**`0x4CB450 / 0xCB450`** puts a name in the set of names in use. "In use" is one set for
the whole game (`0xA86F70` asks it), not one a country.

`Execute` names the unit only when the command lists **more than one brigade**, and names
every brigade. A unit of one - any ship, any wing, a brigade ordered alone - has no name of
its own and takes its brigade's when it is delivered (`FINDINGS-buildqueue.md`, section 4).

## 4. The ship builder

`CShipBuilder`, vftable `0x15DF2E4`, constructor `0x807B40 / 0x407B40`. Window
`ship_builder_window`, holding `selected_ship_window`, which holds
`shipbuild_model_selection`.

| | |
| --- | --- |
| `+0x15C`, `+0x160` | `parallel`, `serial` |
| `+0x194` | the type selected, null for none |
| `+0x198` | a ship of that type kept to work figures out on |
| `+0x19C` | the type the panel was last built for |
| `+0x1A0` | **the levels it will be built with**: a `CList` of ints, one for each of the type's technologies (`+0x1A8` its count) |
| `+0x1C0` | the model selection is open |
| `+0x1E4`, `+0x1E8` | manpower and IC a day |

**The list** (`0x80F230 / 0x40F230`) is the picker's, with `is_ship` for `is_land`. An entry
is a `build_ship_entry` (`CPossibleShipEntry`, `0x80FFE0 / 0x40FFE0`):

| element | figure | decimals |
| --- | --- | --- |
| `org` | `max_organisation` | 0 |
| `con_a`, `sea_a`, `sub_a`, `air_a`, `shore` | convoy, sea, sub and air attack, shore bombardment | 0 |
| `sea_d`, `air_d` | sea and air defence | 0 |
| `sur_det`, `air_det`, `sub_det`, `visibi` | the three detections, visibility | 0 |
| `trans`, `range` | transport capacity, range | 0 |
| `distance` | `firing_distance * 100` | 0 |
| `speed` | the speed formatter | |
| `hull`, `sc`, `fc`, `ic`, `mp` | hull, supply and fuel consumption, the two costs | 2 |
| `time` | days | whole |
| `pos` | `positioning * 100` + `'%'` | 1 |
| `off` | officers | 0 |

The one row of `stats_pos` for the ship selected is the same window type filled by another
class's constructor (`CSelectedShipEntry`, `0x811610 / 0x411610`) - the same columns,
fields and decimals, but **a figure that differs from the type's at the country's own levels
is written in yellow** (`§Y`). `confirmed` (`0x811B2B`..`0x813C0B` for the row, the list's
constructor digested the same way). The two were first taken for one function here;
`checkSignatures.py` caught it, because `0x811610` writes `CSelectedShipEntry`'s table.

**Selecting a type** fills `+0x1A0` with the country's level of each of its technologies -
a government in exile takes its faction leader's where that is higher - and the panel:
`selected_ship_label` (the name of the historical model that fits, with `+*` when that is
not the country's default - `likely`), `selected_ship_photo`, the `stats_pos` row, and
`models`, one `shipbuild_model_entry` (`CCurrentModelEntry`, `0x806EF0`) for each
technology with its `title`, the `name` of the level chosen and a `select` button.

**Choosing a level.** `select` opens `shipbuild_model_selection` (`0x80A260`): its `name` is
the technology's, and its `list` has one `shipbuild_possible_model_entry`
(`CPossibleModelEntry`, `0x807320`) for **every level from 0 to the country's** - `name`
from `0x5010E0`, `effect` from `CTechStatistics::BuildEffectsText`, `current_model` shown on
the one chosen, and a `change` button that writes that level into the list and closes
(`0x80A8F0`). `back_button` closes without (`0x80A820`).

**So a ship may be ordered at any level its country has reached or below**, technology by
technology, and each level left out makes it a hundredth cheaper and quicker.

**Cost.** Manpower is `build_cost_manpower * max(50, 1000 + by-type) / 1000` - no reserves -
and IC and days are `GetBuildCostIC` and `GetBuildTime` with the levels chosen.

**`add_cag`** can be ticked only for a type with a `carrier_size` of 1 or more - `likely`:
the update routine treats the checkbox one way for those and another for the rest, and what
each arm does to it was read in the decompiled C only.

**Ordering** (`0x809D00 / 0x409D00`):

    repeat parallel times:
        post CConstructSingleUnitCommand(the type, the acting capital, amount = serial,
                                         the levels chosen)
        if (add_cag is ticked && type.carrier_size >= 1)
            cag = the first unit type in the database with is_cag
            repeat carrier_size / 1000 times:
                post CConstructUnitCommand([cag], the acting capital, amount = serial,
                                           not reserves)

**Each air group of a carrier is its own line of the queue**, and a series of carriers
gets a series of each.

**`CConstructSingleUnitCommand`**, vftable slot 6 `0x546E40 / 0x146E40`, constructor
`0x546BB0 / 0x146BB0`. One brigade definition, made in the constructor - on the machine of
the player who clicked - with its ids minted and **its name already chosen** (`0x4CBFD0`,
then `0x4CB450`), and the levels copied into its model. `Execute` makes the line, adds the
definition, takes `manpower * amount` off the country (floored at nothing, the reserves
penalty not in it), prices it and queues it. Nothing in it names anything.

## 5. The air builder

`CAirBuilder`, vftable `0x15DD4F0`, update `0x7D1350 / 0x3D1350`. Window
`air_builder_window` holding `selected_air_window`. `+0x130` `parallel`, `+0x134` `serial`,
`+0x168` the type selected, `+0x170` manpower, `+0x174` IC a day.

The list is the picker's with `is_air`. An entry is a `build_air_entry`
(`CPossibleAirEntry`, `0x7D5F50 / 0x3D5F50`): `org`, `hard_a`, `soft_a`, `sea_a`, `air_a`,
`strat_a` (strategic attack), `surf_d` (surface defence), `air_d`, `sur_det`, `air_det`,
`trans`, `range` and `off` with no decimals; `speed` through the speed formatter; `sc`,
`fc`, `ic` and `mp` with two; `time` whole. `confirmed`

Selecting one fills `selected_plane_label` and `selected_plane_photo` as the ship
builder's, one row of `stats_pos`, and `selected_plane_desc_list` with one `air_desc_entry`
for each line of the type's description (`0x5AB2C0`).

**There is no choice of level**: a wing is built at the country's.

**Ordering** (`0x7D1120 / 0x3D1120`): `parallel` times `CConstructUnitCommand([the type],
the capital, amount = serial, not reserves)`.

## 6. The brigade builder

`CBrigadeBuilder`, vftable `0x15DD828`, update `0x7D9A10 / 0x3D9A10`. Window `brigade_builder_window` holding
`selected_brigade_window`. `+0x130` `parallel`, `+0x134` `serial`, `+0x188` the type
selected, `+0x190` manpower, `+0x194` IC a day. This is what `brig_attach` opens: a land
brigade ordered on its own.

The list is the picker's own - land, buildable, still allowed - and an entry is a
`brigade_entry_3` (`CPossibleSingleBrigadeEntry`, `0x7DE3B0 / 0x3DE3B0`), which is
`CPossibleBrigadeEntry`'s constructor again to the byte count: the same twenty columns.

**Its lines are coloured by combined arms group too, from a sprite family of their own**:
`select` takes `'GFX_brigade_listbutton'` + the type's `unit_group` as a number, when a
sprite of that name exists. `0x7DE4C6`..`0x7DE5FB` is `0x7EE5B6`..`0x7EE6EB` of the
picker's constructor instruction for instruction, 87 of them, but for the string and its
length. The base game has `GFX_brigade_listbutton1` to `5`. `confirmed`, read 2026-10-09.

**`brigade_entry_3` gives its `select` button two positions**, `{ 0 4 }` and then
`{ 3 0 }`. An element is read a key at a time into its own field
(`FINDINGS-guicontainers.md`, the `LoadKey` tables), so the second is what stands - and
`{ 3 0 }` is where the line sits under its header in the game, by the maintainer's eye:
drawn at `{ 0 4 }` it is "a little too low and left". `inferred` from the reader's shape,
and seen.

Selecting one fills `selected_brigade_label`, `selected_brigade_photo`, one row of
`stats_pos`, and `selected_brigade_description` (`0x5AACF0`).

`accept` is also disabled when `CountMaxUnitsStillBuildable` is under `serial * parallel`.

**Ordering** (`0x7D95F0 / 0x3D95F0`): `parallel` times `CConstructUnitCommand([the type],
the capital, amount = serial, is_reserve = the checkbox)`.

## 7. How the production screen brings one up

Each of the four buttons has a handler of its own, all one shape (`0x8022F0 / 0x4022F0`
for `build_division_button`):

    CProductionView::HideDialogs()          ; 0x802260: slot 3 of all seven dialogs
    hide the screen's own window            ; +0xA8, slot 14 of its CGuiObject
    CProductionView::ShowFrame()            ; 0x801F80
    show the dialog                         ; its slot 2
    jump to the view's own slot 5

| button | handler | dialog |
| --- | --- | --- |
| `build_division_button` | `0x8022F0` | `+0x300`, the division designer |
| `build_ship_button` | `0x8023B0` | `+0x304`, the ship builder |
| `build_air_button` | `0x802330` | `+0x308`, the air builder |
| `brig_attach` | `0x802370` | `+0x30C`, the brigade builder |

`confirmed` for the shape and the dialog each shows; which button each is attached to is
`inferred` from the order of the names in `CProductionView::AttachButtons`.

**`ShowFrame`** shows eight elements of the screen's own window again, by name: the icons
`bg_countryskin`, `bg_mainshadow` and `production_topitem`, the button `close_button`, the
texts `headline_prod` and `automation_setting`, and the buttons `mode_arrow_right` and
`mode_arrow_left`. **So a builder window stands on the production screen's frame and the
country's picture, with everything else of that screen put away** - which is what its own
art is drawn for: 5.6% of `production_divdesign_bg.dds` is opaque. `bg_prod`, the screen's
background, is not brought back.

`cancel` and a finished `accept` hide the dialog and call the game screen's slot 37 with 1
(`0x7D9890`); that this is what brings the whole production screen back was not read.

## What is not established

- **Which key makes a step ten.**
- **`CProductionView` slot 5** (`0x7FFA80`), which each of the four handlers ends on, and
  the game screen's slot 37.
- **The four tooltip builders** (slot 6), beyond their keys.
- **`CCountry::CountMaxUnitsStillBuildable` past its early returns** in the listing, and
  what `0x5ADF70` groups brigades by when it counts "of the type's branch".
- **The photo and the label**: `0x582FA0`, `CHistoricalModel::PickBestModel` and `0x581F70`
  choose a historical model and write its name; how the picture is chosen was not read.
- **`0x5010E0`**, the name of one level of one technology for one country (`MODEL_TAG`,
  `Default`, `NO`), and `CTechStatistics::BuildEffectsText`.
- **The two description builders**, `0x5AACF0` and `0x5AB2C0`.
- **`CChangeTemplateCommand::Execute`**, and how a country that has no `default_templates`
  comes by any.
- **Custom game mode** throughout.
- **Why `accept` in the ship builder leaves `CountMaxUnitsStillBuildable` alone** when the
  brigade builder asks it: seen, not explained.

## In the record

Entered in `ghidra/project.json` by `fragments/merged/builders.json`: forty-eight
functions, all new, two structs declared (`CDivisionDesigner`, `CShipBuilder`) and
twenty-six fields, four of them on classes that already had a record - `CTechnologyStatus
+0x1C division_size`, and `CCountry +0x148 templates`, `+0xCAC unit_names` and `+0xCBC
unit_name_cursors`. Nothing was revised.

And by `fragments/merged/builders-production.json`, for what was read while the windows
were being built: seven more functions - the four handlers of section 7,
`CProductionView::ShowFrame` and `HideDialogs`, and `FormatFixedPointTrimmed` - and two of
the first fragment's own entries revised, `CDivisionDesigner::AddBrigade` for the
comparator it inserts by and `CPossibleBrigadeEntry`'s constructor for the sprite of its
button.

Three addresses carried constructor labels from Ghidra's RTTI pass that their bodies do not
bear out, and are named here for what they do: `0x7EA880` (`CDivisionDesigner::AddBrigade`,
not a `CPrioComparator` constructor), `0x7E5FB0` (`OnSaveTemplate`, not
`CDivisionTemplate`'s) and `0x7EC940` (`CBrigadePicker`'s constructor).

Two things in it answer what `FINDINGS-buildqueue.md` left open: what refuses an order the
country cannot man or may not build - the windows do, by disabling `accept`, and the
commands do not - and where the windows that post `CConstructUnitCommand` are.
