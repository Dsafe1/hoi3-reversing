# The production screen's tooltips, and what each share's slider says

Read for OpenHOI3's tooltips, 2026-10-11: what each element of the production screen says when the
mouse is over it - `CProductionView::BuildTooltip` (`0x7FFD30`, slot 10) - with the line of the build
queue (`0x7F5A40`), the ten shares' own tooltips (`CDistributionSetting` slot 5, one body each), and
the `£` escape a queue line's text uses. Addresses are virtual, based `0x400000`. Nothing here was
watched in a running game. How a tooltip is shown at all is `FINDINGS-tooltips.md`; the top bar's,
whose resource ledgers this screen shares, is `FINDINGS-topbartooltip.md`.

**Synopsis.** The production screen answers through `CInGameIdler_ViewTooltip` and asks its builder
windows first. Then, by the element's name: each resource's icon, label and figure give that good's
ledger, the top bar's; a strategic resource's icon gives the resource's name, what the country has of
its modifier and one line for each province that yields it to the player, with that province's
infrastructure as a share of what it was built to; the bombs, the two theatre buttons, the escort
button, the convoy button, the underground button and each building's button give a line or two.
**A slider's parts ask the share behind the slider**, handing it the share the slider is at - not the
country's - and the knob adds "right click to lock" or "to unlock" as the delayed half. Each of the ten
shares writes its own sentence; lend-lease writes nothing. A line of the build queue answers by which
of its elements is under the mouse. **`£` and a name in a text draw the unit counter of that name**,
the middle of the sprite `GFX_counter_` + name, 30 by 16. **Corrected:** `BuildProductionPenaltyTooltip`
is the whole tooltip of a build queue line, of which the priority penalties are a part, and its two
stack arguments were the wrong way round in the record - the line first, then `out`.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| `0x3FFD30` | `CProductionView::BuildTooltip` | revised | confirmed | dispatch by element name, every arm described; `out` then the element |
| `0x3F5A40` | `BuildQueueLineTooltip` | revised | confirmed | was `BuildProductionPenaltyTooltip`; the element in ECX, the line, then `out` |
| `0x118970` | `CDistributeLendLease::GetTooltip` | new | confirmed | slot 5: an empty tooltip |
| `0x119200` | `CDistributeConsumerGoods::GetTooltip` | new | confirmed | slot 5: the need, the standing army, the demand's sources, dissent |
| `0x11A590` | `CDistributeProduction::GetTooltip` | new | confirmed | slot 5: `DCG_PRODUCTION` |
| `0x11AEE0` | `CDistributeSupply::GetTooltip` | new | confirmed | slot 5: `DCG_SUPPLIES`, the sources, the technology |
| `0x11C670` | `CDistributeReinforcement::GetTooltip` | new | confirmed | slot 5: `DCG_REINFORCE`, and the bonus |
| `0x11D5C0` | `CDistributeUpgrade::GetTooltip` | new | confirmed | slot 5: `DCG_UPGRADE`, then `_BAD` or `_OK` |
| `0x11E060` | `CDistributeNCO::GetTooltip` | new | confirmed | slot 5: `DCG_OFFICERS` and the sources |
| `0x11E570` | `CDistributeDiplomacy::GetTooltip` | new | confirmed | slot 5: `DCG_DIPLOMACY` |
| `0x11F190` | `CDistributeEspionage::GetTooltip` | new | confirmed | slot 5: `DCG_ESPIONAGE` |
| `0x120EF0` | `CDistributeResearch::GetTooltip` | new | confirmed | slot 5: `DCG_RESEARCH` |
| `0x109340` | `CCountry_CanTrainUnderground` | new | confirmed | at war, not in exile, and occupied ground somewhere |
| `0x109650` | `CCountry::GetUndergroundUnavailableText` | new | confirmed | `UNDERGROUND_NOT_AT_WAR` or nothing |
| `0x10D210` | `ResolvePersistentIdInPlace` | new | confirmed | an id pair at ESI looked up and replaced by its object |
| `0x82320` | `GetQueuedBrigadeName` | new | confirmed | copies the string at the item's `+0x18` |
| `0x65640` | `Fixed15FromFloat` | new | confirmed | `x * 32768 ± 0.5`, truncated: rounded half away from nought |
| `0x43FEE0` | `CEU3BitmapFont::DrawCounterIcon` | new | confirmed | slot 24: what `£name` draws |
| `0x43FED0` | `CEU3BitmapFont::CounterIconWidth` | new | confirmed | slot 25: 30 |

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| `CConstruction` | `+0x7C` | `items` | `void*` | new |
| `CConstruction` | `+0x84` | `item_count` | `int` | new |
| `CConstruction` | `+0xA4` | `accumulated_experience` | `int` | new |

---

## 1. How it is reached

`CInGameIdler_ViewTooltip` (`0x662C50`) calls the open country view's slot 10 with the out tooltip and
the element (`FINDINGS-tooltips.md`, section 5). For the production screen that is
`CProductionView::BuildTooltip`, `ret 8`, `out` at `[ebp+8]` and the element at `[ebp+0xC]`
(`confirmed`, from its call of `0x7F5A40` at `0x801746`, which loads the element from `[ebp+0xC]`).

**Its own builder windows answer first** (`0x7FFDA8`..`0x7FFE60`): the dialog at `+0x318` if there is
one, else each of `+0x300`, `+0x314`, `+0x310`, `+0x31C`, `+0x308`, `+0x30C`, `+0x304` whose slot 5
says it is up, through that dialog's slot 6. Those are the builder windows' tooltips, not read here.

## 2. By the element's name

Then, each tested in this order (`confirmed`); the first that matches fills the tooltip, all of it in
`text` unless said:

| element | what it says |
| --- | --- |
| `energy_icon`, `energy_label`, `energy_value` | the ledger of energy, `BuildGoodsLedgerTooltip` with 5 (`FINDINGS-topbartooltip.md`, section 3) |
| `metal_*`, `rm_*`, `oil_*`, `supplies_*`, `money_*`, `fuel_*` | the same, with 4, 6, 3, 0, 2, 1 |
| `strat_icon_in_prod` | section 3 |
| `nuke_icon`, `nukes_label`, `nukes_value` | `NO_NUKE_PRODUCTION` when the technology status's `nuclear_production` (`+0xBC`) is nought; else `NUKE_PRODUCTION` with `$AMOUNT$` that figure, thousandths, to two places |
| a part of a slider | section 4 |
| `theatres_calc_button` | `THEATRE_RECALC_DESC` |
| `theatres_assign_button` | `THEATRE_ASSIGN_TROOPS_DESC` |
| `escort` | `LEDGER_ESCORTS`; and **when the button is disabled** (its slot 48), `"\n"` + `NEED` + `" §Y"` + the name (slot 7) of the first technology in the database whose `allow_escorts` (`+0x80`) is set |
| `needs` | the lines of `ai_need_queue`, each name after a `£`-like `0xA3` marker resolved through the unit database - not read further |
| `convoy` | `CONVOYS` |
| `underground` | **only when the button is disabled**: section 6 |

and for any other element, two more passes, which do not stop at a match:

- **every building whose file says `capital = yes`** (`+0x60`), in the building database's order, is
  looked for as a button of the building's key (`+0x1C`); where the element is that button,
  `text += the building's name (slot 6) + "\n"`, and where the button is also disabled and a
  technology unlocks the building (`+0x10`), `text += NEED + " §Y" + that technology's name`;
- **each of `trade_list`, `build_queue` and `convoy_queue`**: every line whose window holds the element
  (the line's window's slot 37) replaces the tooltip - `0x803FD0` for a trade, section 5 for the build
  queue, `BuildConvoyEfficiencyTooltip` for a convoy.

Every other element - the IC figure, the counts of transports and escorts, the headline, a slider's
title, value and need - says nothing.

## 3. A strategic resource

`strat_icon_in_prod` is one icon per resource (`FINDINGS-countryviews.md`, section 4), and the
resource is found **by the string at the element's `+8`** in the strategic resource database
(`CNameDataBase::GetByName`): the icons are made carrying their resource's key. With none, nothing. Otherwise
`STRAT_DET_RES_TT` - in English `$NAME$\n$EFFECT$\n$FROM$` - with:

- `$NAME$`: the resource's slot 6, its name;
- `$EFFECT$`: the slot 7 (`DescribeAllValues`) of the country's own scaled copy of the resource
  (`CCountry +0x668`, found by its key at `+0x30`) - every value the country has of it, a line each;
  empty when it has none;
- `$FROM$`: for each province on the game state's `player_strategic_resource_provinces` (`+0x104`)
  whose resource (`+0x18`) is this one:

      standing = values[INFRASTRUCTURE] * (1000 + values[LOCAL_INFRASTRUCTURE] + values[GLOBAL_INFRASTRUCTURE]) / 1000
      standing = min(max(standing, 10), 1000)
      share    = MaxInfrastructure (+0x5C) == 0 ? -1 : standing * 1000 / MaxInfrastructure
      colour   = share < 330 ? §R : share < 990 ? §Y : §G

      "\n@" + controller's tag (+0x334) + "  " + the province's name + " - " + colour
            + FormatFixedPoint(share * 100, 2) + "%§W"

  The thresholds are `floor(330.5f)` and `floor(990.5f)`, the floor of 10 is `floor(10.5f)`. So **a
  province's line is its infrastructure as a share of what it was built to**, without the flat term
  `UpdateStrategicResources` adds and with no floor at nought, red under a third, yellow under
  ninety-nine hundredths.

The list is filled by `UpdateStrategicResources` (`0x68C190`): resource by resource, the provinces of
each in the order the state keeps them, **one appended each time the player's country is given that
province's resource** - so only provinces whose resource reaches the player are on it.

## 4. A slider

Six names are a slider's parts: `domesticpanel_slider_progress`, `actual_slider`, `ds_TrackButton`,
`ds_SliderButton`, `ds_downButton`, `ds_upButton`. For one of them (from `0x800A1B`):

1. **the share's index is the number at the element's `+8`** (`atoi`, `0xA5B220`) - the slider's
   parts are made carrying it. Below nought, nothing;
2. the slider's position is read from the view's slider list (`+0xBC`), and **divided by the country's
   TotalIC when that is above nought** (a float, `0x800AC4`); with no IC the position is used as it is;
3. that is turned into a 48.15 number by `Fixed15FromFloat` (`0x465640`): `x * 32768`, plus a half
   with its sign, truncated - **rounded to the nearest 32768th, half away from nought**;
4. the share at that index of the country's `ProductionDistribution` (`+0x5F4`) is asked its slot 5
   with that number, and its tooltip is the slider's;
5. for `ds_SliderButton` alone, the knob, **the delayed half** gets `SLIDER_LOCKED_TOOLTIP` when the
   slider is disabled and `SLIDER_UNLOCKED_TOOLTIP` when not.

**So what a slider's tooltip says is what the share would do at the slider's position**, before the
position is sent to the game. The technology screen does the same with the leadership shares and
TotalLeadership (`FINDINGS-techtooltip.md`).

### What each share says

`s` is the 48.15 share handed in, `IC` the country's TotalIC (`+0x604`) and `L` its TotalLeadership
(`+0xBD8`), each a thousandths figure turned into 48.15 (`(v << 30) / 0x1F40000`, cut). Every figure is
`FormatFixed15`, so **rounded** by `sprintf`, unless said. `§` strings are `0x15B5C50` `§G`, `0x15B5C58`
`§R`, `0x15BE9D4` `§R+`, `0x15B6B84` `§G+`, `0x15B6700` `§W`. All in `text`; none has a delayed half.

**Lend-lease** (`0x518970`): nothing.

**Consumer goods** (`0x519200`):

1. `need = GetConsumerGoodsNeeded + values[DISSENT]`, never below nought; `"\n" + DCG_TOTAL_NEED + "\n"`
   with `$PERC$` = `need * 100`, two places;
2. `DCG_TROOPS_GOODS + "\n"`, `$IC$` = `GetStandingArmyConsumerDemand * 100`, two places, `$TROOPS$` =
   `land_brigades_in_service` (`+0x108C`) as an integer;
3. the country modifier's slot 9 for `war_consumer_goods_demand` (40) at war and
   `peace_consumer_goods_demand` (41) at peace (`0x51985A`: `40 + (at_war == 0)`), scale 1000 -
   appended straight on;
4. where `GetDissentChange(s)` - the need less `s`, plus `values[DISSENT]`, **at the slider's share** -
   is not nought: `"\n" + DCG_DISSENT + " "`, `$VAL$` = `§G` when it is below nought and `§R+` when
   above, the change to two places, `§W`.

**Production** (`0x51A590`): `DCG_PRODUCTION`, with `$VAL$` = `IC * s / needed * 100` to two places -
**not divided at all when `needed` (`+0x20`) is nought or less** - `$USE$` = `spent_beyond_free`
(`+0x28`) and `$NEED$` = `needed`, both to two places.

**Supplies** (`0x51AEE0`): `made = GetSuppliesMade(s, IC)`. `DCG_SUPPLIES` with `$VAL$` = `§R` when
`made` is nought or less, `§G+` when above, then `made` to two places and `§W`; `$IC$` = `s * 100` to
two places. Then **straight after it**, with no line between, slot 9 for `global_supplies` (27), scale
1000. Then, where the technology status's `supply_production_bonus` (`+0x9C`) is not nought,
`"\n" + FROM_TECHNOLOGY + ": §G+" + bonus * 100 + "%§W\n"`, the bonus turned into 48.15 first.

**Reinforcement** (`0x51C670`): `DCG_REINFORCE`, `$VAL$` = `IC * s / reinforcement_cost * 100` to two
places - **undivided when `reinforcement_cost` (`+0xA98`) is nought or less**. Then where
`1000 + values[REINFORCEMENT_BONUS]` is above 1000: `" " + DCG_REINFORCE_BONUS`, `$VAL$` = that sum
through `FormatFixedPoint` to **one place, cut** - `1.2`, a multiplier, not a percentage.

**Upgrades** (`0x51D5C0`): `DCG_UPGRADE`, `$UNITS$` = the share's own `+0x20` - the brigades upgrading,
counted in 48.15 by `Distribute` - to no places, `$IC$` = `upgrade_cost` (`+0xAA4`) through
`FormatFixedPoint` to two. Then, **with nothing between**: where `s * 1000` in thousandths, cut, times
`IC` is below `upgrade_cost`, `DCG_UPGRADE_BAD` with `$VAL$` = `IC * s / upgrade_cost * 100` to two
places; else `DCG_UPGRADE_OK`.

**Officers** (`0x51E060`): `DCG_OFFICERS`, `$VAL$` = `L * s * LEADERSHIP_TO_OFFICERS * (1 +
values[OFFICER_RECRUITMENT])` to **one** place, each product shifted back by 15. Then slot 9 for
`officer_recruitment` (82), scale 1000, appended after a `"\n"` **only when it is more than two
characters long**.

**Diplomacy** (`0x51E570`): `DCG_DIPLOMACY`, `$VAL$` = `L * s * LEADERSHIP_TO_DIPLOMACY` and `$UPKEEP$`
= `GetInfluenceUpkeep`, both to two places.

**Espionage** (`0x51F190`): `DCG_ESPIONAGE`, `$VAL$` = `L * s * LEADERSHIP_TO_SPIES` to two places.

**Research** (`0x520EF0`): `DCG_RESEARCH`, `$SPEED$` = `L * s` to two places, `$COUNT$` = the projects
on the queue (`+0x640`) as an integer, `$PERCENT$` = `ratio = COUNT == 0 ? 1 : SPEED / COUNT`, then
`§R` when `ratio < 1` and `§G` when not, `ratio * 100` to two places, and `%§W` (`0x15C2148`).

## 5. A line of the build queue: `BuildQueueLineTooltip` (`0x7F5A40`)

`ret 8`; **the element in ECX, the line on the stack, then `out`** (`0x7F5A5F`: `mov ebx, [ebp+0xC]`
is what is filled). The construction is the line's `+0x78` id pair resolved by `0x50D210`; with none,
an empty tooltip. Then, by the element's name, `confirmed`:

| element | text | delayed |
| --- | --- | --- |
| `original_country` | `PW_ORIGINAL`, `$COUNTRY$` the licence's country | |
| `cancel` | `PEN_CANCEL_PRODU` | `PEN_CANCEL_PRODU_DRO` + `"\n\n"` + `CANCEL_MULTI_CONSTRUCTIONS_DESC` |
| `max_prio` | `PEN_MAX_PRIO` | |
| `prio` | `PEN_PRIO` | |
| `non_prio` | `PEN_NON_PRIO` | |
| `max_non_prio` | `PEN_MAX_NON_PRIO` | |
| `counter_type`, `production_queue_division`, `production_queue_air`, `production_queue_naval`, `series_info`, `unit_target` | the brigades, below | the inherited experience, below |
| anything else | by the line's `status` (`+0x3C`): 1000 or more `PEN_FULL_SPEED`; above nought `PEN_PARTIAL_PROGRESS` with `$PERC$` = `status * 100` through `FormatFixedPoint` to no places, cut; nought `PEN_NO_PROGRESS` | |

**The brigades**, only where the construction's slot 17 says it builds a unit and its `item_count`
(`+0x84`) is one or more. The items are the list at `+0x7C`:

- **an upgrade** - the first item's `+0x38` set: `BRIGADE_UPGRADE_MIL_CON_INFO` with `$FROM$` the name
  (slot 6) of the type at `+0x38` and `$TO$` of the type at `+0x34`; and where its `+0x40` is above
  nought, the delayed half `BRIGADE_UPGRADE_INHERITED_EXP` with `$EXP$` that, two places;
- **otherwise one line per item**: `"£" + the key of its type (+0x34, the string at +8) + " " + its name
  (+0x18)`, a `"\n"` after every one but the last;

then, either way, `"\n" + BRIGADE_MIL_CON_CUMULATED_EXP`, `$EXP$` = `accumulated_experience`
(`+0xA4`) to two places. `production_queue_buildings` is not among the names, so a building's line
gives its `status` sentence.

## 6. The underground button

`underground` is disabled when `CCountry_CanTrainUnderground` (`0x509340`) says no
(`FINDINGS-countryviews.md`, section 4). That needs the country **at war** (`+0xACC`) and **not a
government in exile** (`+0x95`), and one province with no unit in it (`+0x30C` then `+0x20` below one)
held by somebody the country is at war with - not itself, not `REB`, and `CCountry::IsFriend` of the
owner - among: the provinces of its allies, when it is a major (`+0x15C`) or has more than 100 MaxIC
(`+0x60C`); then its own, where for a small country the province must also be its own.

Disabled, its tooltip is `CCountry::GetUndergroundUnavailableText` (`0x509650`): `UNDERGROUND_NOT_AT_WAR`
when not at war, nothing for a government in exile, and otherwise the same walk - **nothing** where a
province would qualify, `UNDERGROUND_NOT_AT_WAR` where none does.

## 7. `£` in a text

`CEU3BitmapFont` slot 24 (`0x83FEE0`) is what `£` (`0xA3`) and the name after it draw - the name
`[A-Za-z_]` as `GetStringWidth` takes it (`FINDINGS-text.md`). It looks up the sprite
**`GFX_counter_` + the name**; with none it draws nothing. With one, a quad **30 wide and 16 high**
(`0x170AED0`, `0x160AA20`) from the line's top down, offset by -0.5 both ways, its texture coordinates
**0.26 to 0.75 across and 0.23 to 0.55 down** (`0x171DC10`, `0x171DC18`, `0x171DC14`, and the 0.75 at
`fAiPowerRatio_0_75`): the middle of a unit counter, its symbol, without the frame. Slot 25
(`0x83FED0`) answers **30**, what the pen moves on by.

## Kept as read, though they look odd

1. **Production and reinforcement are not divided when nothing is needed**: the percentage is then a
   hundred times the IC the slider holds.
2. **The supply share's sentence runs straight into its first source**, with no line between.
3. **The upgrade share's two sentences touch**, the first ending in a space in English.
4. **The reinforcement bonus is a multiplier to one place**, `1.2`, cut, where every other figure in
   these sentences is rounded.
5. **A strategic resource's provinces are shown without the flat term** their yield has, and one with
   nothing built shows `-0.10%` in red.

## Not established

- The trade list's line (`0x803FD0`), the convoy queue's (`BuildConvoyEfficiencyTooltip`) and the AI's
  needs list beyond the shape above.
- The builder windows' tooltips, which answer first.
- Who sets the string at a slider part's or a strategic resource icon's `+8`; that they carry the
  index and the key is `inferred` from what is read out of them.
- `CEU3BitmapFont` slot 22 (`0x8403A0`), another icon drawn out of the font's own atlas, by its shape
  the `¤` (`0xA4`) escape.
