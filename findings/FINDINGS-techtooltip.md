# The technology screen's tooltips

Read for OpenHOI3's tooltips, 2026-10-11: what each element of the technology screen says when the
mouse is over it - `CTechnologyView`'s slot 10 (`0x81F2A0`, new here) - with the four kinds of entry
it hands off to: a tree entry (`CTechTreeEntry::BuildTooltip`, `0x8193C0`), a theory or practical
(`0x814D00`), a line of the queue (`CCurrentResearchEntry::BuildTooltip`, `0x816A10`) and a category
icon of the panel for one technology (`CEntryForTechCategory` slot 12, `0x814310`). Addresses are
virtual, based `0x400000`. Nothing here was watched in a running game. The sliders' own tooltips are
`FINDINGS-productiontooltip.md`, section 4; how a tooltip is shown at all is `FINDINGS-tooltips.md`.

**Synopsis.** With custom game settings in force, three buttons of that mode answer first; otherwise
a slider's parts ask their leadership share as the production screen's ask theirs. The label of the
leadership figure gives where the country's leadership comes from: a base summed over the provinces
it controls, the sources of the two global leadership kinds, what technology adds, and a line for
each technology it is sharing. A tree entry gives the technology's name and the level it would be,
why it may not be researched where it may not, **its whole effects text** (`BuildEffectsText`, not
read here) and, delayed, "double click to start" or "to cancel". A theory or practical gives its
name, and where another country shares it, both levels. A line of the queue gives what its priority
buttons and `cancel` do, the level being researched, and the sources of research efficiency. In the
panel for one technology: each category icon says how much that skill speeds the research; `start`
says it is already queued, or **how many days it would take at full funding from scratch**, carried
over the year's end with the next year's penalty, or why it may not be researched; the picture of
what it adds to says so; `difficulty` names itself. **Corrected:** `CTechTreeEntry::BuildTooltip`
had no signature and was named by analogy; it is read whole here.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| `0x41F2A0` | `CTechnologyView::BuildTooltip` | new | confirmed | slot 10: the dispatch, every arm described |
| `0x4193C0` | `CTechTreeEntry::BuildTooltip` | revised | confirmed | read whole: heading, why not, effects, the double click |
| `0x416A10` | `CCurrentResearchEntry::BuildTooltip` | revised | confirmed | the arms and the efficiency block every arm ends in |
| `0x414D00` | `CTechSkillEntry::BuildTooltip` | new | confirmed | the category's name; the sharer's and our level delayed |
| `0x414310` | `CEntryForTechCategory::BuildTooltip` | new | confirmed | slot 12: `TECH_ICON_SPEED_MOD` for its `tech_icon` |
| `0x419030` | `CTechTreeEntry::OwnsElement` | new | confirmed | whether an element is one of the entry's |
| `0x414280` | `CEntryForTechCategory::OwnsElement` | new | confirmed | whether an element is its `tech_icon` |
| `0x135830` | `DescribeWhyNotResearchable` | new | confirmed | `ALREADY_RESEARCHED`, or the `allow` trigger's slot 9 |
| `0x142560` | `CTechnology_YearPenalty` | new | confirmed | 1000 plus the impact of each year early, level in EAX |
| `0x1333C0` | `CCountry_ResearchEfficiency` | new | confirmed | `max(least, 1000 + modifier + technology)` |

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| `CEntryForTechCategory` | `+0x28` | `category` | `CTechnologyCategory*` | new |
| `CEntryForTechCategory` | `+0x2C` | `speed` | `int` | new |
| `CEntryForTechCategory` | `+0x30` | `skill` | `int` | new |
| `CEntryForTechCategory` | `+0x34` | `weight` | `int` | new |

---

## 1. How it is reached, and the order

As the production screen's (`FINDINGS-productiontooltip.md`, section 1): `CInGameIdler_ViewTooltip`
calls slot 10, here `0x81F2A0`, `ret 8`, `out` at `[ebp+8]` and the element at `[ebp+0xC]`. Each tested
in this order (`confirmed`):

1. **Custom game settings in force** (`GetCustomGameSettings`): the view's buttons at `+0x1A4`, `+0x198`,
   `+0x19C` and `+0x1A0` give `CGM_TOOLTIP_CLEAR_ALL`, `CGM_TOOLTIP_TECH_PLUS` (with the chosen
   technology's custom line, `0x81F070`, delayed), `CGM_TOOLTIP_TECH_MINUS` and `CGM_TOOLTIP_TECH_RESET`.
2. **A slider's part** - the same six names as the production screen's: the index at the element's `+8`,
   below the number of leadership shares; the slider's position made a 48.15 number by
   `Fixed15FromFloat` - rounded - and **then** divided by `TotalLeadership` in 48.15 (`0x81FB23`..
   `0x81FB5C`: `(position << 15) / leadership`, cut), or taken as it is with no leadership; the
   leadership share at that index of `LeadershipDistribution` asked its slot 5; and for
   `ds_SliderButton` the lock line delayed. **The production screen divides first, as floats, and
   rounds after**; the two screens turn a position into a share in different orders.
3. **`leader_ship_label`**: section 2.
4. **An entry of the tree** (the list at `+0x160`): the first whose `OwnsElement` (`0x819030`) says the
   element is its `start`, `name`, `level`, `icon_finish_type`, `progress`, one of its four backgrounds,
   `difficulty`, or the `tech_icon` of a category icon in its `input_box` - its slot 0, section 3.
5. **A theory or practical** (`skill_entries`): the one whose `+0xC`, `+0x10` or `+0x14` - its icon, its
   bar or its figure - is the element: `0x814D00`, section 4.
6. **A line of `current_research`** whose window holds the element: its slot 12, section 5.
7. **With the panel for one technology up** (`+0xD0`): section 6.

## 2. `leader_ship_label`

All of it in `text` (the tooltip at `[esp+0xD8]`, appended through `[esp+0xE4]` after three pushes):

    base = 0                                   floor((0 + 0.0005f) * 1000)
    for each province the country controls (+0xD00):
        l = (province +0x324 + values[LOCAL_LEADERSHIP]) * max(0, 1000 + values[LOCAL_LEADERSHIP_MODIFIER]) / 1000
        base += max(l, 0)

the values the province's own (`+0x114`). Then:

1. `BASE + " §Y" + FormatFixedPoint(base, 2) + "§W\n"`;
2. the country modifier's slot 9 for `global_leadership` (33), scale 1000, appended straight on;
3. the same for `global_leadership_modifier` (35);
4. where the technology status's `+0xB8` is not nought: `"\n" + FROM_TECHNOLOGY + ": §G+" +
   FormatFixedPoint(it * 100, 2) + "%§W\n"`;
5. for each technology the country is sharing (`+0x6F0`, twelve bytes an entry): `SHARE_TECH_TOOLTIP`
   with `$TECH$` the technology's name, `$COUNTRY$` the country's, and `$COST$` the define at
   diplomacy `+0xC0` to one place, then `"\n"`.

## 3. A tree entry: `CTechTreeEntry::BuildTooltip` (`0x8193C0`)

`ret 4`, `out` on the stack. `level` is the country's level of the technology plus one, or **1 for a
technology of one level** (`additional_offset` nought), whatever the country has.

1. `text = name (slot 7) + " (" + level + ")\n\n"`.
2. Where `CTechnology::CanResearch` says no: `TTE_ALREADY + "\n"` when it is on the queue; otherwise
   `DescribeWhyNotResearchable` (`0x535830`) `+ "\n"` - `ALREADY_RESEARCHED` for a technology of one
   level the country has (level above one, or below nought), else the `allow` trigger's slot 9 with a
   scope of the country.
3. `text += CTechStatistics::BuildEffectsText(technology, level, 0, the country)` - what a level does:
   the units and the building it allows (`ENABLE_UNIT_TECH`, `ENABLE_BUILDING_TECH`), each unit type's
   statistics scaled by `level` through `CSubUnitDefinition::BuildStatsTooltip`, and the country-wide
   figures of `BuildEffectsTooltip`. **Not read here.**
4. `delayed_extra`: `TECH_DC_TO_STOP` when the technology is on the queue, `TECH_DC_TO_START` when not.
   With custom game settings, in its place: `LOWEST_TECH_LEVEL` where that mode sets one, and the three
   `CGM_TOOLTIP_TECH_*_SHORTCUT` lines.

## 4. A theory or practical: `0x814D00`

`text` is the category's name (its slot 0); with custom game settings, `"\n"` and
`CGM_TOOLTIP_THEORY_PRACTICE` after it. **Where another country shares the category with this one**
(`category_shared_from`, `+0x6A8`), the delayed half is `TW_SKILL_SHARE` with `$COUNTRY$` the sharer's
name, `$THEIR$` the higher of the two levels to one place, `$OUR$` the country's own to one place.

## 5. A line of the queue: `CCurrentResearchEntry::BuildTooltip` (`0x816A10`)

`ret 8`, the out tooltip then the element. By the element's name:

| element | text |
| --- | --- |
| `tech_prio_maxup` | `PEN_MAX_PRIO` |
| `tech_prio_up` | `PEN_PRIO` |
| `tech_prio_down` | `PEN_NON_PRIO` |
| `tech_prio_maxdown` | `PEN_MAX_NON_PRIO` |
| `cancel` | `TECH_SUSPEND` |
| anything else | for a technology of many levels, `TECH_TREE_INFO` with `$NAME$` its name and `$LEVEL$` the country's level plus one; for one of one level, nothing |

**Then, whichever it was** - every arm joins at `0x816BAF` - the country modifier's slot 9 for
`research_efficiency` (73), scale 1000, is made, and the technology status's `research_efficiency`
(`+0xA8`) read. Where the first is **more than one character** or the second **above nought**:
`"\n" + MODIFIER_RESEARCH_EFFICIENCY + ":\n"`; then where the second is above nought
`FROM_TECHNOLOGY + ": §G+" + FormatFixedPoint(it * 100, 2) + "%§W\n"`; then where the first is more than
one character, it. With custom game settings the chosen technology's custom line goes in `delayed`.

## 6. The panel for one technology

With the panel up (`+0xD0`), the technology at `+0xD4`:

- **a category icon of its `input_box`** - one whose `OwnsElement` (`0x814280`) says the element is its
  `tech_icon` - gives its slot 12 (`0x814310`), whose `text` and `delayed` are appended. That is
  `TECH_ICON_SPEED_MOD` with `$NAME$` the category's name, `$SKILL$` the skill (`+0x30`) to one place,
  `$PERCENT$` the weight (`+0x34`) times a hundred to no places, cut, and `$SPEED$` = `§R` below nought
  or `§G+` above, then `FormatFixedPointTrimmed(speed * 100)` (`+0x2C`). The three come from the tree
  entry's constructor of the icon (`0x817F1A`..`0x817FCC`): for each `research_bonus_from` node, the
  speed is `GetCategoryResearchAbility`, the skill the country's level of the category or its sharer's
  where higher, the weight the node's own;
- **`start`**, section 7;
- **`icon_finish_type`**: `ICON_FINISH`, `$NAME$` the name of the category the technology adds to on
  completion;
- **`difficulty`**: `DIFFICULTY_TECH`, alone.

Each is rendered with the game settings' tooltip colours (`0x40C630`), not the plain ones.

## 7. `start`

- On the queue (`CurrentResearch`, `+0x638`): `TTE_ALREADY`.
- May not be researched: `DescribeWhyNotResearchable`, as on a tree entry.
- Otherwise `START_RESEARCH`, `$DAYS$` from this (`0x820C55`..`0x820E56`), all thousandths:

      level = the country's level of it + 1
      eff   = CCountry_ResearchEfficiency(country)      max(g_MinimumResearchEfficiency, 1000 + values[RESEARCH_EFFICIENCY] + status research_efficiency)
      cost  = CTechnologyStatus::GetResearchCost(technology)
      work  = eff == 0 ? -1 : cost * 1000 / eff
      year  = this year;  f = YearPenalty(level, year)
      left  = (365 - day of the year, from nought) * 1000
      if work * f / 1000 <= left:
          days = work * f / 1000
      else:
          days = left
          work -= f == 0 ? -1 : left * 1000 / f
          while work > 0:
              year += 1;  f = YearPenalty(level, year)
              x = f * work / 1000
              if x <= 365000:  days += x;  work = 0
              else:            work -= 365000000 / f;  days += 365000
      $DAYS$ = FormatFixedPoint(days, 0)

  `YearPenalty` (`0x542560`, the level in EAX, out in ESI): the year the level is due - `start_year`
  for level 1, `first_offset` for 2, and `additional_offset` more for each level past it - and
  `1000 + (due - year) * 1000 * TECHNOLOGY_YEAR_IMPACT / 1000` when that is ahead of `year`, else 1000.
  **So it is the days at one leadership a day, from nothing done**, ignoring what the country gives
  research and how far the level has got; a year has 365 days.

## Kept as read, though they look odd

1. **A tree entry of one level says `(1)` and is described at level 1** even when the country has it.
2. **The start button's days are at one leadership a day**, whatever the research share is.
3. **A tree entry says `TTE_ALREADY` only where `CanResearch` also says no**; whether a technology on
   the queue may be researched was not read here, so whether that line is ever seen is not known.

## Not established

- `CTechStatistics::BuildEffectsText` and `BuildEffectsTooltip` - a technology's effects as text, which a
  tree entry carries and the panel's `effects` list is made of.
- What a trigger's slot 9 writes: the `allow` block's account of why a technology may not be researched.
- What sets the strings at the elements' `+8` that the sliders are found by.
