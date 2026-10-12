# A technology's requirements and effects as text

Read on 2026-10-12 for OpenHOI3's technology screen tooltips, the two parts
`FINDINGS-techtooltip.md` left out: why a technology may not be researched, and what a level does.
Static reading of `hoi3_tfh.exe`; **every address is a VA** (image base `0x400000`) unless it says
rva. The trigger renderers were already in the record from `FINDINGS-script.md`; this reads the
leaves and the exact rules of each line.

**Synopsis.** The account of an `allow` block is its slot 9, `GetBlockText(scope, redWhen = 0,
depth = 0)`, against a scope of the country; each container draws its children's lines with
three spaces of indent a level and a red or green asterisk, and each leaf writes one line whose
**wording turns round inside a `not`** - `TECHNOLOGY_HIGHER_THAN` becomes `TECHNOLOGY_LOWER_THAN`.
The original's indentation is wrong in the ways `FINDINGS-script.md` sets out; the rules below are
the original's, and section 4 is the corrected arithmetic BiceLib patches into it, which **the
maintainer asked OpenHOI3 to follow** (2026-10-12). What a level does is
`CTechStatistics::BuildEffectsText`, read whole: the unit types and building a **first** level
allows, each usable unit type's figures (`CSubUnitDefinition::BuildStatsTooltip`) **times the
number of levels**, folded onto one line with commas, and the country-wide block
(`CTechStatistics::BuildEffectsTooltip`, read whole, 46 scalars, two flags and four lists).
**Corrected:** `CSubUnitDefinition::BuildStatsTooltip`'s two unknown arguments are a prefix and a
plus flag; `AppendStatLine`'s layout is read; `BuildEffectsText`'s last three arguments are a unit
type filter, the country's tag and its id.

## 1. The call

`DescribeWhyNotResearchable` (`0x535830`): for a technology of one level the country has,
`ALREADY_RESEARCHED`; otherwise a `CEventScope` built for the country (its id and tag), and the
`allow` trigger's slot 9 with `redWhen = 0` and `depth = 0` (the decompilation's
`allow->slot9(out, &scope, 0, 0)`). `confirmed`

## 2. The original's renderers

Three spaces is one level (`"   "`, three bytes, at each indent loop). The asterisk is `(§R*§W)`
where the child's `Evaluate` equals `redWhen`, else `(§G*§W)` (`0x15F5E1C`, `0x15F5E24`).

**The base, `CTrigger::GetBlockText` (`0x5D03F0`):** a negative depth is made positive and
remembered. For each child: its line is its slot 8 (`GetText(scope, redWhen, depth)`); where that
is not empty, `indent(depth)`, then the asterisk **only where the depth is 0 or arrived
negative**, then the line; and then, for every child, its slot 9 at the same depth (a leaf's slot 9
is this base with no children: empty). `confirmed`

**`and` (`0x5D0720`):** at depth 0 the base's call, so a technology's `allow` - an implicit `and` -
lists its conditions with no header. Otherwise `indent(depth)` + `AND_TRIGGER_STARTS` + `":\n"`,
and for each child: its slot 9 **at depth 0**; where that is empty and the child has no children
(`+0x10`), its slot 8 at depth 0; where the result is not empty, `indent(depth)` + asterisk +
it. `confirmed`

**`or` (`0x5D0D40`):** `indent(depth)`, the `or`'s own asterisk **at depth 0 only**,
`OR_TRIGGER_STARTS` + `":\n"`, then the children as the `and`'s but their slot 9 **at depth 1**.
`confirmed`

**`not` (`0x5D1300`):** the base with `redWhen` turned round and the depth unchanged.
`confirmed`. Its `Evaluate` (`0x5D12C0`) is a NOR over its children.

**`any_owned_province` (`0x5DD5B0`):** `indent(depth)`, its asterisk at depth 0 only, then
`indent(depth)` again + `ANY_PROVINCE_STARTS` + `" ("` + the name of the scope's country +
`"):\n"`, then the base for its children at `depth + 1` - so they have no asterisks.
`confirmed`. As BiceLib notes, the children are evaluated against the country, not a province,
so an asterisk there would mean nothing.

## 3. The leaves

Each `GetText` is `(out, scope, redWhen, depth)`, `ret 0x10`, and **chooses its words by
`redWhen`**: the second wording inside a `not`. `confirmed`

| trigger | `redWhen` 0 | `redWhen` 1 |
| --- | --- | --- |
| a technology, `0x5DB480` | `§Y` + its name + `" ("` + its folder's name + `")§W"` + `TECHNOLOGY_HIGHER_THAN` + `§Y` + the level + `§W\n` | the same with `TECHNOLOGY_LOWER_THAN` |
| `num_of_ports`, `0x5D8510` | `HAVE_MORE_PORTS_THAN` + `§Y` + n + `§W\n` | `HAVE_LESS_PORTS_THAN` ... |
| `has_building`, `0x5E4150` | `HAVE_A_X_INY`, `X` = `§Y` + the building's name + `§W`, `Y` = `§Y` + the name of the scope's province (`+0x28`) + `§W`, then `\n` | `DONT_HAVE_A_X_INY` ... |
| `has_country_flag`, `0x5E2110` | `HAVE_COUNTRY_FLAG` + `'§Y` + the flag's text + `§W'\n` | `HAVE_NOT_COUNTRY_FLAG` ... |

The numbers are written with `itoa`, whole. Under `any_owned_province` the scope is still the
country's, whose province is 0, so **`has_building` names province 0**.

## 4. BiceLib's corrections

`Hooks::TriggerText::TriggerIndent` changes the arithmetic and nothing else - the text of every
line, and the order, stay the game's. In prose:

1. **A header does not indent itself**: the `and`'s and the `or`'s header loops, and those of the
   six scope triggers (a country scope, `any_owned_province`, a region, `any_neighbor_province`,
   `any_neighbor_country`, `any_core`), are jumped over; the parent has already placed the line.
2. **Each child of an `and` or an `or` is indented `depth + 1`**, not `depth`.
3. **A child block of an `and` or an `or` is given `depth + 1`**, not 0 or 1.
4. **In the base, a child that is a block gets its indent and its asterisk** where the depth is
   above 0, before its block is appended; at depth 0 nothing, since a block draws its own there.
5. **A country scope passes its depth negated**, `-(depth + 1)`, so the conditions under it - which
   are evaluated against a real scope - get asterisks.
6. **A `not`'s text has its leading spaces taken off**, since it sits on a line its parent placed.

So, corrected: at the top an `allow` is a plain list; a block below the top is its header
(no indent of its own) and then its children each one level deeper than the block; a `not` reads
as one line in its parent's place. `FINDINGS-script.md` has why each of the three sums was wrong.

## 5. What a level does: `CTechStatistics::BuildEffectsText` (`0x5359A0`)

`(technology, out, levels, unitFilter, tag, countryId)`, `ret 0x18`. A tree entry passes the level
it is about, 0 and the country (`FINDINGS-techtooltip.md` section 3). In order:

1. `levels` outside -1..1 counts as "more than one"; a negative one is taken as 1.
2. **Only for one level**: for each unit type the technology activates (`activate_unit`) that the
   country may use (`SubUnitDefinitionIsUsableBy`), `ENABLE_UNIT_TECH` + `" §Y"` + its name +
   `"§W\n"`; then, where the technology activates a building (its slot 8 says it is real),
   `ENABLE_BUILDING_TECH` + `" §Y"` + its name + `"§W\n"`.
3. For each unit type the technology changes, in its list's order, that the country may use (and,
   with a filter, only that one): its effect copied and **scaled by the levels**
   (`CSubUnitDefinition::Scale`, every figure and adjuster times the levels); its figures
   (section 6) with the prefix `""` and the plus asked for; trimmed of space, tab and line breaks
   at both ends; every `" \n"` replaced by `", "`; and written as its **short name** (`0x5A3980`:
   the text of its key + `_short`) + `": "` + that + `"\n"`.
4. The country-wide block, section 7.

`confirmed`. A filter (`unitFilter` not 0) writes each figure on its own line instead; nothing here
passes one.

## 6. A unit type's figures: `CSubUnitDefinition::BuildStatsTooltip` (`0x5A55C0`)

`(definition, out, prefix, plus)`, `ret 0xC`. A line for each of 42 figures through
`AppendStatLine` (`0x5A51D0`, `ret 0x54`), whose arguments are, in order: out, the prefix, the plus
flag, **the label key and the unit word as strings by value**, the value, a "more is better" flag,
the places, and a yellow flag (`push` order read at every one of the 42 calls). Its line:

    nothing where the value is 0; otherwise
    prefix + the label's text
         + " §Y" where yellow, else " §G" where (better ? value : -value) is above 0, else " §R"
         + "+" where the value is above 0 and the plus is asked
         + FormatFixedPoint(value, places) + "§W " + unit + " \n"

The figures, label, field, places, better and unit; yellow is never asked here:

| label | field | places | better | unit |
| --- | --- | --- | --- | --- |
| `MAX_STRENGTH` | `+0xEC` | 0 | yes | |
| `NEEDED_OFFICERS` | `+0x118` | 0 | yes | |
| `DEFAULT_ORG` | `+0xF0` | 1 | yes | |
| `DEFAULT_MORALE` | `+0xF4` times 100 | 1 | yes | `%` |
| `BUILD_COST_IC` | `+0xF8` | 2 | no | `IC`'s text |
| `BUILD_COST_MP` | `+0xFC` | 2 | no | |
| `BUILD_TIME` | `+0x100` | 0 | no | `DAYS`'s text |
| `MAXIMUM_SPEED` | `+0x108` | 2 | yes | `KPH`'s text |
| `TRANSPORT_WEIGHT`, `SUPPLY_CONSUMPTION`, `FUEL_CONSUMPTION` | `+0x10C`, `+0x110`, `+0x114` | 2 | no | |
| `DEFENSIVENESS`, `TOUGHNESS` | `+0x11C`, `+0x120` | 2 | yes | |
| `SOFTNESS` | `+0x124` | 2 | no | |
| `ARMOR_VALUE`, `AIR_DEFENCE`, `SUPPRESSION`, `SOFT_ATTACK`, `HARD_ATTACK`, `AP_ATTACK`, `AIR_ATTACK` | `+0x12C`, `+0x128`, `+0x130`, `+0x134`, `+0x138`, `+0x13C`, `+0x140` | 2 | yes | |
| `COMBAT_WIDTH` | `+0xE8` | 2 | no | |
| `TRANSPORT_CAPABILITY`, `AMPH_INVASION_SPEED_BONUS`, `AMPH_INVASION_DEFENCE_BONUS` | `+0x144`, `+0x188`, `+0x18C` | 2 | yes | |
| `RANGE` | `+0x148` | 0 | yes | `KM`'s text |
| `DISTANCE` | `+0x14C` | 1 | yes | `KM`'s text |
| `SURFACE_DETECTION`, `AIR_DETECTION`, `SUB_DETECTION` | `+0x150`, `+0x154`, `+0x158` | 2 | yes | |
| `VISIBILITY` | `+0x15C` | 2 | no | |
| `SEA_DEFENCE`, `CONVOY_ATTACK`, `SEA_ATTACK`, `SUB_ATTACK`, `SHORE_BOMBARDMENT`, `SURFACE_DEFENCE`, `STRATEGIC_ATTACK` | `+0x160` .. `+0x174`, `+0x17C` | 2 | yes | |
| `RADIO_STRENGTH` | `+0x180` | 2 | no | |
| `HULL`, `POSITIONING`, `CARRIER_CAPACITY` | `+0x178`, `+0x184`, `+0x190` | 2 | yes | |

Then the adjusters, each written where `CUnitAdjuster_Describe` says anything, as the label's
text + `": "` + it + `"\n"`: night (`NIGHT_ADJUSTER`), fort (`FORT_ADJUSTER`), river
(`RIVER_ADJUSTER`), amphibious (`AMPH_ADJUSTER`), and every terrain in the map's order under its
own name. `confirmed`

## 7. The country-wide block: `CTechStatistics::BuildEffectsTooltip` (`0x538D60`)

`(technology, out, levels, tag, countryId)`, `ret 0x14`; every figure is the technology's
per-level figure **times the levels** (`levels x 1000`, multiplied and divided by 1000 in 64
bits), and a line is written only where it is not 0. Read in the listing, arm by arm, in this
order. A line is the label's text + the colour + the figure + its end; "x100" is times 100000
over 1000:

| | label | colour | figure | end |
| --- | --- | --- | --- | --- |
| `+0x08` | `GDE_FROM_TECH` | `": §G"` | x100, 2 places | `%§W\n` |
| `+0x14` | `DIGIN_FROM_TECH` | `": §G"` | 0 places | `§W\n` |
| `+0x18` | `ATTACK_DELAY_FROM_TECH` | `": §G"` | 0 places | `" "` + `AD_HOURS` + `§W\n` |
| `+0x1C` | `DIVISION_SIZE_FROM_TECH` | more | 0 places | `§W\n` |
| `+0x0C` | `SUPPLY_TRANSFER_COST_TECH` | less | 2 places | `§W\n` |
| `+0x10`, `+0x20` | `SUPPLY_THROUGHPUT_TECH`, `REFINERY_EFFICIENCY_TECH` | more | x100, 2 | `%§W\n` |
| `+0x34` | `RADAR_EFFICIENCY_TECH` | more | x100, 2 | `§W\n` |
| `+0x38` | `RADIO_STRENGTH_TECH` | more | 0 places | `%§W\n` |
| `+0x40`, `+0x3C` | `DECRYPTION_TECH`, `ENCRYPTION_TECH` | more | 1 place | `§W\n` |
| `+0x44`..`+0x50` | `CONVOY_COST_TECH`, `CONVOY_TIME_TECH`, `ESCORT_COST_TECH`, `ESCORT_TIME_TECH` | more | 0 places | `§W\n` |
| `+0x54`, `+0x58`, `+0x6C`, `+0x7C`, `+0x70`, `+0x74`, `+0x78` | `ATTACK_MOVEMENT_SPEED_TECH`, `REINFORCE_CHANCE_TECH`, `UNIT_COOP_TECH`, `NAVAL_BASE_EFF_TECH`, `TARGET_CHANCE_TECH`, `TARGET_CHOICE_TECH`, `ESCORT_EFFICIENCY_TECH` | more | x100, 2 | `%§W\n` |
| `+0x80`, `+0xDC` | `ALLOW_ESCORTS_TECH`, `LISTENING_STATION_TECH` - where the byte is 1, unscaled | | | `§W\n` |
| `+0x84` | `CASUALTY_TRICKLEBACK_TECH` | more | x100, 2 | `%§W\n` |
| `+0x88` | `MAX_ATTRITION_TECH` | less | x100, 2 | `%§W\n` |
| `+0x8C`..`+0xD8` | `MANPOWER_GAIN_TECH`, `IC_MOD_TECH`, `IC_EFFICIENCY_TECH`, `ENERGY_TO_OIL_TECH`, `IC_TO_SUPPLIES_TECH`, `PROV_AA_TECH`, `COMBAT_EFF_TECH`, `RESEARC_EFF_TECH`, `METAL_PROD_TECH`, `RARES_PROD_TECH`, `ENERGY_PROD_TECH`, `LEADERSHIP_GAIN_TECH`, `NUKE_PROD_GAIN_TECH`, `RADAR_IMPACT_TECH`, `REPAIR_RATE_TECH`, `BOMBER_TARGET_TECH`, `FIGHTER_TARGET_TECH`, `FRONTLINE_FOCUS_TECH`, `RESERVE_FOCUS_TECH`, `NAVAL_AIR_TARGET_CHANCE_TECH` | more | x100, 2 | `%§W\n` |

"more" is `": §G+"` above 0 and `": §R"` below; "less" is `": §G"` below 0 and `": §R+"` above.
Then four lists:

- **the tactics** (`+0x24`), each in the tactics' order with a figure: its name + `": §G+"` +
  the figure to 0 places + `"%§!\n"` - **green with a plus whatever its sign**;
- **the combined-arms groups** (`+0x5C`), in the groups' order: the group's key's text +
  `": §G+"` + x100 to 0 places + `"%§!\n"`;
- **the missions**, 33 in the mission index's order (`OrderMissionIndexToKey`): the efficiency
  (`+0xE0`) as the mission's text + `ORD_EFF` + `" §G+"` above 0 or `" §R"` + x100 to 1 place +
  `"%§!\n"`; then the organisation penalty (`+0x164`) the same with `ORD_RED` and `" §R+"` above
  0 or `" §G"`;
- **decay** (`+0x1F8`), in the categories' order: before the first, `"\n"` where anything has been
  written; then the category's name + `" "` + `DECAY` + `": "` + `"§G"` below 0 or `"§R+"` + x100 to
  1 place + `"%§W\n"`.

`confirmed`, every line, from the listing (`0x538D60`..`0x540598`; Ghidra cannot decompile it).

## Kept as read, though they look odd

1. A tactic's line is green with a plus even for a penalty: `+-100%`.
2. Radar efficiency has no `%`; radio strength has one and no x100.
3. `has_building` under `any_owned_province` names province 0.
4. A unit type's figures end `§W ` + unit + ` \n`, so folded with commas a figure with no unit
   leaves a space before its comma.
5. What a level allows is said only for one level, so a tree entry beyond the first never says it.

## Not established

- The technology panel's `effects` list (`0x81E846`) is made from this text, with its own level
  argument, and cut into rows; neither was read.
- The text of every other trigger a mod's `allow` may use; and which trigger a category's name
  makes as a condition.
- The name of province 0.
