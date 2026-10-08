# The production and technology screens: what they write into their elements

Read statically off `hoi3_tfh.exe` on 2026-10-08, for the rewrite's second and third
screens (`OpenHOI3/docs/mechanics/productionscreen.md`,
`OpenHOI3/docs/mechanics/technologyscreen.md`). The game was not running and **nothing
here was checked against a live screen** - where the top bar's reading had sixteen strings
out of a running game to agree with (`FINDINGS-guilive.md` §6), this one has only the
bytes and the localisation files. Addresses are **virtual** (image base `0x400000`) with
the rva beside anything the record needs. Listings are in the session scratchpad
(`factbase/screens/*.txt`).

`FINDINGS-uinumbers.md` already had both screens' *tooltip* builders. What it did not have
is the routines that fill the screens, the slider both share, or the three list and tree
entries.

## In one line

Both screens are a `CCountryView` - a main window, a `topcolor_*` window behind it and a
country skin read from `gfx/interface/skins/country_bg_<TAG>.dds`; the sliders on both are
one class, `CEconomySlider`, driven by the country's own `CDistributionSetting` objects,
holding its value **in IC or in leadership, not in percent**, printing it to two decimals
behind a colour its setting chooses (red when the need is larger, to the hundredth) and
its need as `SLIDER_NEED` plus the same; the production screen prints a resource as
`stock (change)` in whole units with the change **red and unsigned when the stock is
falling**, green with a plus when it is rising; the technology tree is one `tech_entry`
window for each technology of the chosen folder, placed at the `positionType` named
`<technology key>_position`, whose name line reads `Name: next / max` and whose
background is one of four buttons chosen by whether the technology is finished, may be
researched, and has more than one level; and a line of the research queue shows the
finish date as `year month day`, the level being worked on in **roman numerals**, and one
of three backgrounds by whether the project gets a whole point of leadership, part of one
or none.

---

## 1. `CCountryView`, the base both screens share

RTTI vftable `0x15D419C`, fifteen slots. Six classes derive from it - diplomacy, espionage,
politics, production, technology, theatre - and slots 7, 8, 9, 11, 12 and 13 are the base's
own in most of them.

| slot | VA | what |
| --- | --- | --- |
| 0 | `0x6EB3D0` | **Rebuild**: hide (slot 4), destroy and remake the main window by the name it had, then remake the second window as `'topcolor_politics'` (`0x6EB469`) - the base's default; production and technology make their own in their constructors (`'topcolor_production'`, `'topcolor_technology'`) |
| 2 | `0x6EB380` | **Show**: show the window at `+0xAC`, show the window at `+0xA8`, tail-jump to slot 11 |
| 7 | `0x6EB4E0` | is it on screen: the main window's `+0x5B` |
| 8 | `0x6EB3B0` | slot 11 of both windows, the second by tail jump |
| 9 | `0x6EB4F0` | **the country skin**, below |
| 11 | `0x6EC150` | **the automation line**: sets `automation_setting` to the text `0x6EB910` returns for the local player's setting for this view (`OPT_NORMAL` / `OPT_AICONTROL`), calls slot 14, and enables `mode_arrow_left`, `mode_arrow_right` and `close_button` |
| 14 | `0x6EC3E0` | greys the main window (its slot 38 with 0 or 1) according to whether the local player's setting for this view is 1 |

Fields: `+0x78` the view's index into the local player's automation settings (`[player +
0x38][index]`, `0x6EC24C`), `+0xA8` the main window, `+0xAC` the `topcolor` window, `+0xB0`
the gui the windows are made through.

**The skin, slot 9.** Builds `'gfx/interface/skins/country_bg_'` + the played country's tag
as text (game state `+0xC30`, the `CCountryTag` whose first bytes are its three letters) +
`'.dds'` (`0x6EB5E5`..`0x6EB609`), and **only if that file exists** (`FileExists`,
`0x6EB737`) makes a sprite from the `GFX_country_bg` definition with that texture and sets
it on the icon `bg_countryskin` (the icon's slot 56). So the picture behind a country view
changes with the country and falls back to whatever `GFX_country_bg` names. *That the top
bar does the same was not read.*

## 2. `CEconomySlider`, the slider of both screens

No RTTI of its own; the name is from its observer glue,
`VCEconomySlider::__CButtonObserverGlue` (vftable `0x15DE378`), which the constructor
writes at `+0x00`. `0x40` bytes (`push 0x40; call operator new` at `0x7FC4DE` and
`0x81A5B0`).

| offset | what |
| --- | --- |
| `+0x00` | the observer glue: vftable, `+0x04` self, `+0x08` the handler `0x7F0080` |
| `+0x30` | its window - `domesticpanel_slider` on the production screen, `tech_slider` on the technology screen |
| `+0x34` | the `CDistributionSetting*` it shows |
| `+0x38` | the value last set, a float |
| `+0x3C` | latched from the scrollbar's `+0x252` and cleared by `0x7F1320`: the player moved it |
| `+0x3D` | 1 for an IC slider, 0 for a leadership one (`cl` at construction) |
| `+0x3E` | set when the need button has just pinned it |

**Constructor, `0x7EFC40` (rva `0x3EFC40`), `ret 0x28`.** Makes the window whose name it is
given, sets `title` to the setting's slot 6 (its name - a `DISTRIBUTE_*` key, §3), attaches
itself to the scrollbar `actual_slider`, renames the window to its index in decimal
(`0x7EFDE5`), attaches itself to `ic_need_button` if the window has one, and calls slot 65
on `limit` if it has one.

**The value is an amount, not a share.** `0x7F0C30` returns the scrollbar's value as a
float; `0x7F0CC0` sets it as `floor((v + 0.0005) * 1000)`; `0x7F0D90` returns the
scrollbar's `+0x230` over a thousand, rounded to the hundredth - its maximum; `0x7F0EB0`
sets that maximum, and both views call it with **the country's total** - `TotalIC`
(`+0x604`) on the production screen (`0x7FE009`), `TotalLeadership / 1000` (`+0xBD8`) on
the technology screen (`0x81B6D0`). So a slider runs from nought to all the country's IC
or leadership, and the `minValue = 0`, `maxValue = 100` of the `.gui` file are replaced.

**Update, `0x7F0290` (rva `0x3F0290`).** `void __thiscall`, bare `ret`.

- The value `v` becomes a share for the setting: `v * 32768` rounded half away from zero,
  shifted fifteen and divided by the total shifted fifteen - `TotalIC` for an IC slider,
  `TotalLeadership / 1000` for the other; left as it is when the total is not positive.
- **`value`** = the setting's slot 2 for that share - a colour escape, §3 - followed by
  `v` to two decimals (`0xA5AEC0` with `push 2`). `0x7F05DA`..`0x7F06D1`.
- **`need`** = the setting's slot 1 for that share - §3. `0x7F074C`..`0x7F0828`.
- **`limit`**: when the window has one and the setting's slot 11 answers nought or more,
  the icon is shown and moved along the slider to that value; hidden otherwise.
  `0x7F0880`..`0x7F0BB3`. Slot 11 is `-1.0` (`0x170AC0C`) for nine of the ten settings.

**The need button, `0x7F0080`.** If the setting's slot 7 says yes - only lend-lease's
does - its slot 8 is called and nothing else happens; that is the lend-lease window.
Otherwise the slider is set to `need + step / 2`, the need being slot 3 (a 48.15 fixed
point, read with `fild qword` and multiplied by 2^-15) and the step the scrollbar's `+0x234`
over a thousand; then the slider's own button is **disabled** and `+0x3E` set - pinned to
its need - unless it was already disabled (its slot 44 answering 3), in which case it is
enabled again if the scrollbar's `+0x253` says the need button was what disabled it.

**How a view keeps six sliders adding up** (`0x7FE114`..`0x7FE395` in production's update,
`0x81BD30`..`0x81BF3B` in technology's, the same code twice). Up to ten rounds: `left` =
the maximum minus the sum of the six values; every slider is updated; the count of
sliders free to move is those that are neither disabled (`0x7F10D0`) nor held by the mouse
or just moved (`0x7F1170`); `left / free`, clamped away from nought to `±0.01`, is added to
each free one (`0x7FEBD0`, which will not take a slider below nought or above its
maximum and returns what it actually took) until `|left|` is under `0.005`. The round
stops early when nothing is left. A slider just moved keeps its value; the others absorb
the difference. **A command is sent at most once a second**: `0x7FFA90` (production) and
`0x81D150` (technology) run only when a slider changed and a wall-clock second has passed
since the last one (`+0x328` and `+0x190`, doubles).

## 3. What a `CDistributionSetting` tells its slider

Ten classes, twelve slots each. Slot 0 is `Distribute`, already recorded for all ten.

| slot | what | read off |
| --- | --- | --- |
| 1 | **the `need` line**: the text of `SLIDER_NEED` followed by slot 3's need to two decimals (`0xA5AD70`, `push 2`). An empty string for espionage and officers (`0x5187A0`); lend-lease gives the text of `DISTRIBUTE` instead (`0x5189B0`). **Research has one**: its need is the number of projects on the queue | `0x521480`, the body consumer goods, supply and research's tables point at; `0x51A300`, `0x51CB00`, `0x51DBE0` and `0x51E8E0` (production, reinforcement, upgrade, diplomacy) carry the same key and were not read past it |
| 2 | **the colour of the `value` line**: `§R` when the need is greater than what the share gives, both cut to the hundredth, `§W` otherwise. Production compares the need at `+0x20`; consumer goods calls its own slot 3; diplomacy compares against `CCountry::GetInfluenceUpkeep`. Lend-lease is always `§W` (`0x518A90`); research, espionage and officers give an empty string (`0x5187A0`). Supply, reinforcement and upgrade's bodies are the size and shape of production's and were not read | `0x51A440`: `cmp eax,edi; jle` chooses `0x15B5C58` (`a7 52`) or `0x15B6700` (`a7 57`); `0x5190F0`; `0x51EB20` |
| 3 | the need, a 48.15 fixed point written through the out pointer, `ret 4` | `0x51A2E0` production: its own `+0x20`. `0x51CAD0` reinforcement: the country's `reinforcement_cost` (`+0xA98`), thousandths made 48.15. `0x51DBB0` upgrade: `upgrade_cost` (`+0xAA4`). `0x521450` research: the length of `CurrentResearch`, shifted fifteen |
| 6 | the name: the text of `DISTRIBUTE_CONSUMER_GOODS`, `_PRODUCTION`, `_SUPPLY`, `_REINFORCE`, `_UPGRADE`, `_LENDLEASE`, `_RESEARCH`, `_ESPIONAGE`, `_DIPLOMACY`, `_NCO` | ten bodies of `0xDE` bytes, one key each |
| 7, 8 | "has a window of its own" and "open it": yes only for lend-lease | `0xA92590` against `0x592360` |
| 11 | where the `limit` marker goes; `-1.0` unless lend-lease, which gives a figure from `TotalIC` when the country has lend-lease distributions | `0x518790`, `0x518BD0` |

**`CDistributeProduction::GetICForShare` was misnamed.** The record had `0x51A440` (rva
`0x11A440`) returning a `CFixedPoint`. It returns a `std::string` of two characters, the
colour escape above: its last instructions are `push 2; push 0x15b5c58; call
std::string::assign; mov eax,esi; ret 0xc`. Renamed `GetValueColour`.

**Two `GetNeedTooltip` records were the function before the one meant.** `0x51CAD0` (rva
`0x11CAD0`) and `0x51DBB0` (rva `0x11DBB0`) were recorded as slot 3 bodies that build from
`SLIDER_NEED` and `ret 0xC`. Each is `0x2E` bytes, reads one country field, writes two
dwords through `[ebp+8]` and ends `ret 4`: they are reinforcement's and upgrade's
**`GetNeeded`**, slot 3 like every other class's. The `SLIDER_NEED` bodies are the
functions two bytes of padding later, `0x51CB00` and `0x51DBE0`, at slot 1 - so **the
slot is stable across the family after all**, and `FINDINGS-uinumbers.md` §6's "slot 1 or
slot 3" was this misattribution. `FINDINGS-sigaudit.md` had already noticed the two took
one argument and returned with `ret 4`.

**`CDistributeResearch` slot 4, `0x51F4D0`,** shares the research leadership among the
queue: for each technology on `CurrentResearch` that passes `CheckResearchAllowed`, it
takes a whole point (`0x8000`) or what is left if less, and writes it in thousandths to
the technology status's `leadership_by_technology` (`+0x238`); a technology that fails
the check, or comes after the leadership has run out, gets nought. Section 6 is what
reads that back.

## 4. The production screen, `CProductionView`

RTTI vftable `0x15DED24`. Constructor `0x7FB1A0`, which names its windows
`'topcolor_production'` and `'country_production'` and the seven dialogs it owns
(`division_designer`, `ship_builder_window`, `air_builder_window`,
`brigade_builder_window`, `convoy_details`, `convoy_settings`,
`lendlease_distribution_window`), held at `+0x300`..`+0x31C`.

| slot | VA | what |
| --- | --- | --- |
| 0 | `0x7FBE00` | the base's rebuild, then `0x802700` (the trade list) and `0x7FBE20` (attaches the observers of ten buttons) |
| 2 | `0x7FEE40` | **Show**, below |
| 4 | `0x7FF9D0` | hide both windows and close the dialogs |
| 6 | `0x7FD350` | **Update**, below |
| 7 | `0x7FEDD0` | on screen: any of four dialogs open, or the main window |
| 10 | `0x7FFD30` | `CProductionView::BuildTooltip`, already recorded |

**The sliders, `0x7FC350` and `0x7FF730`.** One `CEconomySlider` for each of the country's
`ProductionDistribution` (`+0x5F4`..`+0x5F8`), made in index order with the window
`'domesticpanel_slider'` and **put at the front of the list** at `+0xB8`, so the list runs
upgrade, reinforcement, supply, production, consumer goods, lend-lease - the order of the
six icons down the `.gui` file. `0x7FF730` places them: the first at the `positionType`
`domestic_eco_slider_start` plus the main window's own position, each next one further by
`domestic_eco_slider_offset`; each is shown, given `TotalIC` as its maximum and, unless
the view is mid-edit (`+0xCC`), reset from its setting (`0x7EFFA0`: maximum times
share). A slider whose entry in the country's array at `+0x1090` is positive starts
disabled (`0x7FC557`) - the lock survives the screen being rebuilt.

**Show, slot 2.** Shows both windows, calls slot 11, then rebuilds the strategic resource
strip: clears the box `strat_resources` and, for every strategic resource the country has
a level above nought of (`strategic_resource_levels`, `+0x678`), adds a
`production_strat_resource` window whose icon `strat_icon_in_prod` is given the sprite
`'GFX_'` + key + `'_small'` **if a sprite of that name exists** (`0x7FF24F`..`0x7FF41B`).
Then places the sliders and rebuilds the four lists.

**Update, slot 6.** When the played country is not the one shown (`+0x334`), everything is
rebuilt first. Then:

- **The seven resources** through `0x7FD170`, goods in ECX: energy 5, metal 4, rare
  materials 6, crude oil 3, fuel 1, supplies 0, money 2, into `energy_value`,
  `metal_value`, `rm_value`, `oil_value`, `fuel_value`, `supplies_value`, `money_value`.
  The text is `sprintf("%i (%s%i§W)", stock / 1000, colour, change / 1000)`
  (`0x15DE910`), where `change` = out - in over the same fifteen ledgers the top bar reads
  (`FINDINGS-topbar.md` §3, with `traded_for` counted as coming in) and the colour string
  is `§R` when `change > 0`, `§G+` with the change negated when `change < 0`, and `§Y`
  when it is nought. **So a falling stock is a red number with no minus sign and a rising
  one a green number with a plus.** Both divisions are by the magic for a thousand and
  truncate. The stock is the exile pool or the acting capital's, as on the top bar.
- **`nukes_value`** = `nukes` (`+0x90`) through `FormatFixedPoint` with two decimals.
- **`ic_value`** = `TotalIC` (`+0x604`) as a plain integer.
- `theatres_calc_button` is hidden.
- **`transports_value`** = `Transports` (`+0xB0`) as an integer, followed by `' (+N)'`
  when `N`, the convoys being built, is not nought; **`escorts_value`** the same from
  `Escorts` (`+0xB4`). `N` is summed over the country's `Constructions` (`+0xF40`): for
  each whose slot 15 says yes, its `+0x40` times the define at `[defines + 0x9C] + 0x34`
  over a thousand, to escorts when its `+0x58` is set and to transports otherwise.
- The button `escort` is disabled unless the technology status's `+0x80` is set.
- **Building buttons are found by the building's key.** For every building with `capital
  = yes` (`+0x60`), the window is asked for a button named as the building is
  (`+0x1C`); if there is one it is enabled when the technology status's
  `building_available` has the building and disabled when not. `0x7FDE82`..`0x7FDF73`.
- `underground` is disabled when `0x509340` says no.
- The sliders, section 2.
- The four lists - `build_queue`, `ai_need_queue`, `trade_list`, `convoy_queue` - are
  rebuilt when their length differs from the model's and otherwise have each entry
  updated. The entries were not read.

## 5. The technology screen, `CTechnologyView`

RTTI vftable `0x15DFC44`. Constructor `0x81A110`: `'topcolor_technology'`,
`'country_technology'`, and a third window, `'country_leadership_sliders'`, at `+0x184`,
which the four sliders are children of.

| slot | VA | what |
| --- | --- | --- |
| 2 | `0x81C9B0` | Show: places the sliders from `leadership_slider_start` and `leadership_slider_offset`, builds the tree, the queue and, if a technology is selected, the detail panel |
| 4 | `0x81CFA0` | Hide: also empties `tech_tree` and `tech_categories` |
| 6 | `0x81B0C0` | **Update**, below |
| 10 | `0x81F2A0` | the tooltip builder |
| 11 | `0x822970` | the automation line, with four texts where the base has two: `OPT_NORMAL`, `OPT_AICONTROL`, `TECH_AUTOMATED`, `LEADERSHIP_AUTOMATED` |

**Build, `0x81A510`.** One `CEconomySlider` per `LeadershipDistribution` (`+0x5E4`), window
`'tech_slider'`, each put at the front of the list at `+0xBC` - so the list runs research,
espionage, diplomacy, officers, the order of the four icons. Then, for every technology
folder from index 1, the button `'techtree_'` + folder key is given the view's observer,
and the first folder that has a button becomes the selected one (`+0x15C`).

**Update, slot 6.**

- For every folder from index 1: the icon `'bg_tech_'` + key is shown for the selected
  folder and hidden for the rest; the button `'techtree_'` + key is set to frame 2 when
  selected and 1 when not. `0x81B0F2`..`0x81B2DB`.
- Every skill entry is updated (§5.2).
- **`leader_ship_label`** = the text of `DISPOSAL_OF_LEADERSHIP` + `':§Y '` (`0x15DFA58`) +
  `TotalLeadership` to two decimals.
- **`current_research_label`** = the text of `CURR_RES_LABEL` with `$CURR$` and `$MAX$`.
  `MAX` is the research slider's value as leadership, two decimals. `CURR` is the length
  of `CurrentResearch` (`+0x640`) between a colour and `§W`: `§G` unless the count is a
  whole project or more above `MAX`, then `§Y`. (A third branch pushes `§R` and cannot be
  reached: it is taken only when the count is below `MAX`, inside the branch entered
  when it is at least one above.) `0x81B753`..`0x81BC4F`.
- The sliders, section 2.
- **The `start` button of the detail panel**: with a technology selected, it reads the
  text of `ITEM_RESEARCH_START` and is disabled if `CheckResearchAllowed` fails; if the
  technology is already on `CurrentResearch` it reads the text of `cancel`.
- The queue list `current_research` is rebuilt (`0x8211A0`) when its length or order
  differs from `CurrentResearch`; then every tree entry is updated.

### 5.1 A tree entry, `CTechTreeEntry`

RTTI vftable `0x15DFC38` (one slot, the tooltip, `0x8193C0`); `0x40` bytes; `+0x30` the
`CTechnology`, `+0x38` its `tech_entry` window.

**The tree, `0x821570`.** Empties `tech_tree`; for every technology whose `Folder`
(`+0x290`) is the selected one, makes an entry and looks up the `positionType` named
**technology key + `'_position'`** (`0x821C51`); if there is one the entry's window is
moved there. A technology with no position stays where the window type puts it. The entry
is added to `tech_tree`.

**Constructor, `0x817920`.** Attaches itself to the four background buttons; sets
`icon_finish_type` to the sprite `'icon_'` + the key of the technology's `on_completion`
category + `'_small'` if that sprite exists, keeping the icon's scale; and fills
`input_box` with one `tech_category_entry` for each `research_bonus_from`, whose
`tech_icon` is `'icon_'` + category key + `'_small'`.

**Update, `0x818350` (rva `0x418350`).** With `level` the country's level of the
technology and `multi` meaning `additional_offset != 0`:

- All four backgrounds are hidden, then one is shown: for a technology that is not
  `multi` - `bg_finnished` when `level >= 1`, else `bg_cant` when `CheckResearchAllowed`
  fails, else `bg_oneshot`; for a `multi` one - `bg_cant` when it fails, else
  `bg_endless`. (A custom game setting can force `bg_cant`.)
- `tech_status_researching` is shown when the technology is on `CurrentResearch`.
- **`progress`** is set to `level * 100 / max_level`, an integer, for a `multi`
  technology and to nought otherwise.
- **`name`** is the technology's name for one that is not `multi`; for a `multi` one, name
  + `': '` + **`level + 1`** + `' / '` + `max_level` while `level < max_level`, and name +
  `': '` + the text of `TECH_AT_MAX` after.
- **`difficulty`** is the number behind `§G` under 3, `§Y` from 3 to 5, `§R` above 5.
- **`year`** is the historical year of the next level: `start_year` for level 1,
  `first_offset` for level 2, `first_offset + (n - 2) * additional_offset` for level `n`;
  for one that is not `multi`, `start_year`.
- A technology that is not `multi` and is finished has `difficulty` and `year` emptied.

### 5.2 A skill entry

Unnamed, `0x24` bytes, one for each technology category, made by the tree builder at the
`positionType` **category key + `'_position'`** inside the window `tech_categories`
(`0x821716`), from the window type `tech_category_skill_entry`. Constructor `0x814800`:
`tech_cat_icon` gets the sprite `'icon_'` + category key if there is one. Update
`0x814A30`, with `level` the country's `category_levels` entry, or the entry of the
country in `category_shared_from` when that is set and higher:

- **`skill`** = `level` to one decimal (`FormatFixedPoint`, `push 1`) when `level > 99`
  thousandths, prefixed `§G` when the level is a shared one; `'-'` otherwise.
- **`tech_skill_indicator`** is set to frame `level / 1000`, at least 1 when the level is
  above nought and at most 20.

### 5.3 A line of the research queue, `CCurrentResearchEntry`

Window type `current_research_entry`. Update is slot 8, `0x8158A0` (rva `0x4158A0`).

- **`data`** = the day the level will be finished, from `GetDaysToResearch`: `'?'` when
  that answers -1, else **year + `' '` + month name + `' '` + day** (`0x816128`..
  `0x816190`: the four `operator+` take the year string first).
- **`level`** = `level + 1` in **roman numerals** (`0x45D300`: `L`, `XL`, `X`, ...).
- **`progress`** = `progress_by_technology` times a hundred, a percentage.
- **`name`** = name + `': '` + `level + 1` for a `multi` technology, the name alone
  otherwise.
- **The background**: with `share` the technology's `leadership_by_technology` -
  `bg_current_green` when `share >= 990` (the float `990.5` floored, `0x160A754`),
  `bg_current_orange` when it is above nought, `bg_current_red` when it is nought.
- The five buttons (`cancel` and the four `tech_prio_*`) are disabled under one custom
  game setting and enabled otherwise.

### 5.4 The detail panel, `0x81D400`

Hides `tech_categories`, shows `tech_details`, and for the technology chosen:

- **`photo`**: the file `<base>/pictures/tech/<key>.tga`; if it exists, a sprite from the
  `GFX_no_tech_image` definition with that texture. `0x81D575`..`0x81D808`.
- **`name`** = name + `' ('` + `level + 1` + `')'`; a technology that is not `multi`
  always reads `' (1)'`.
- **`name_expl`** = `0x5019E0`: the text of the key `<TAG>_<technology key>_<level>` if
  there is one, else of `<technology key>_<level>`, else the name (with `': '` and the
  level for a `multi` one). That is where a model's name comes from.
- `input_box`, `difficulty` and `year` as on a tree entry. **`icon_finish_type` is not**:
  here the sprite is `'icon_'` + the category's key with **no `'_small'`** - one
  `operator+` after the `'icon_'` pushed at `0x81DEBD`, and `'_small'` is not among the
  routine's strings, where the tree entry's constructor pushes both. Corrected
  2026-10-08, after the maintainer saw the rewrite draw it the wrong size.
- `tech_status_finnished` for a finished technology that is not `multi`;
  `tech_status_researching` when it is on the queue.
- **`desc`** = `0x5342E0`, which reads the key technology key + `'_desc'`.
- **`effects`**: `CTechStatistics::BuildEffectsText` split into lines, each a
  `detail_entry` window with its `text` set.

---

## What is not established

- **Little was seen running.** Every format is from the bytes. The maintainer, who knows
  the running game, confirmed two things on 2026-10-08 on seeing the rewrite's screens:
  **a falling resource is printed red with no minus sign**, and **a locked slider is
  drawn in grey** - which is the `disable` technique of `gfx/FX/buttonstate.fx`, and so
  agrees with section 2's reading that the need button disables the slider's own button
  and that state 3 is "disabled". On a second look the same day the maintainer also
  found **the queue's dates reading year first** right in the rewrite, with the folder
  buttons, the priority and cancel buttons and `start` - whose handlers were not read
  here, so that is the rewrite's behaviour passing by eye and no more.
- **A scrollbar that runs up and down is read from the bottom.** Not from the bytes: the
  list boxes' `standardlistbox_slider` gives its `leftbutton` the sprite of an arrow
  pointing down and its `rightbutton` one pointing up, and the maintainer reports the
  running game draws the up arrow at the top. So `leftbutton` is the bottom end. The
  scrollbar's own code was still not read.
- **What the buttons do.** The observers' handlers were not read on either screen: the
  build buttons, the folder buttons, the four priority buttons, `cancel`, `start`, the
  mode arrows.
- **The commands the sliders send** (`0x7FFA90`, `0x81D150`) were not read past their
  once-a-second gate.
- **The scrollbar itself.** Its fields at `+0x22C`, `+0x230` and `+0x234` are read as
  minimum, maximum and step in thousandths from how the slider uses them, not from the
  scrollbar's own code; what locks one - `SLIDER_LOCKED_TOOLTIP` exists - was not found.
- **List boxes**: how entries are stacked, clipped and scrolled was not read.
- **The production screen's four list entries**, the trade list and the convoy list.
- **`0xA5AEC0` and `0xA5AD70`** are taken to print a float and a 48.15 fixed point to the
  number of decimals pushed, from their arguments and where the result goes. Whether
  they round or cut was not read.
- **The term the value colour adds.** `0x51A440` and `0x5190F0` add the 64-bit number at
  `0x1A87718` to the share's IC before cutting it to the hundredth (`add eax,[0x1a87718];
  adc edx,[0x1a8771c]`). It is in the part of the image that is not initialised, so its
  value cannot be read statically. If it is a rounding half, a share set exactly at its
  need is not red; if it is nought, it is, by the hair the share lost being stored.
- **Which top bar button opens which view**, and whether opening one closes another.
