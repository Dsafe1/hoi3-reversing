# The top bar's tooltips, and how a modifier lists where it comes from

Read for OpenHOI3's tooltips, 2026-10-11: what each element of the top bar says when the mouse is
over it - `CTopBar::BuildTooltip` (`0x6CCB80`, slot 5) and the five builders it hands off to - and,
because four of them end in it, **the routine that lists the contributors to one kind of modifier**
(`CModifier` slot 9) with the line it writes for each (slot 8). Addresses are virtual, based
`0x400000`. Nothing here was watched in a running game. How a tooltip is shown at all is
`FINDINGS-tooltips.md`.

**Synopsis.** The top bar answers by the element's name. Each picture beside a figure gives a
heading (`*_IRO`) with its description (`*_DRO`) as the delayed half. Each resource's number gives
the day's ledger of that good, line by line, ending in what its global modifier is made of. IC,
dissent, national unity, officers and manpower give a sentence with the figures behind them and
then the same list of contributors for the modifier kind that drives them; diplomacy gives the day's
influence; spies a bare heading. The top bar's buttons say only "Disabled in scenario", when they
are. **Corrected:** the record's `BuildModifierEffectsText` (`0x456E00`) is not a tooltip at all - it
is the initialiser that builds the 108 modifier definitions, and the "108 keys" are their names. Each
definition carries two flags no record had: shown as a percentage, and more is better.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| `0x2CCB80` | `CTopBar::BuildTooltip` | revised | confirmed | dispatch by element name, every arm described |
| `0xF3000` | `BuildGoodsLedgerTooltip` | revised | confirmed | the line order, colours and the closing modifier list |
| `0x2D0540` | `GetManpowerDetailsText` | revised | confirmed | fills a whole `GuiTooltipText`; the delayed half described; out type corrected |
| `0x56E00` | `InitModifierDefinitions` | revised | confirmed | was `BuildModifierEffectsText`: the definitions' initialiser, not a tooltip |
| `0xF99C0` | `BuildDissentTooltip` | new | confirmed | `DISSENTV_IRO`, its contributors and the penalties of dissent |
| `0xF8BE0` | `BuildNationalUnityTooltip` | new | confirmed | unity, the three strategic warfare impacts, contributors, effect size |
| `0x2CFFF0` | `BuildOfficerTooltip` | new | confirmed | `OFFICER_NUMBER2_IRO` and the officer recruitment contributors |
| `0x59DA0` | `CModifier::DescribeContributors` | new | confirmed | slot 9: one kind's contributors, one line each |
| `0x59880` | `CModifier::DescribeOwnValue` | new | confirmed | slot 8: name, colour, sign, value |
| `0x59AB0` | `CModifier::DescribeAllValues` | new | confirmed | slot 7: every kind it holds, by the kind's name |
| `0x56DD0` | `GetEmptyName` | new | confirmed | slot 6 of a plain modifier: empty; a body folded into 43 tables |
| `0x5A2D0` | `CStaticModifier::GetDisplayName` | new | confirmed | slot 6: its name, localised |
| `0x1241B0` | `CGovernment::GetDisplayName` | new | confirmed | slot 6: its key, localised |
| `0x126750` | `CModifier_GetKeyDisplayName` | new | confirmed | slot 6 shared by four classes: the key at +0x30, localised |
| `0x129100` | `CLaw::GetDisplayName` | new | confirmed | slot 6: the law's slot 13 |
| `0x122480` | `CFactionModifier::GetDisplayName` | new | confirmed | slot 6: its faction's slot 6 |
| `0x12AB90` | `CMinisterType::DescribeAllValues` | new | confirmed | slot 7: the base list and a `DECAY` line per category |
| `0x5D660` | `CModifierDefinition_GetLocalisedName` | new | confirmed | a kind's name, its key localised |
| `0x56D50` | `CModifierDefinition_Construct` | new | confirmed | id in EDX; the two flags at +0x28 and +0x29 |
| `0x65AD70` | `FormatFixed15` | new | confirmed | a 48.15 number through `sprintf("%.Nf")` |
| `0x65AE30` | `FormatFloat3` | new | confirmed | a float through `sprintf("%.3f")` |
| `0x17D60` | `CDistributionSetting_EffectiveShare` | new | confirmed | base share times factor, shifted 15 |
| `0x1ECA00` | `CCountry_GetOfficers` | new | confirmed | the officers at +0xC4 |

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| `CModifierDefinition` | `+0x28` | `percent` | `bool` | new |
| `CModifierDefinition` | `+0x29` | `more_is_better` | `bool` | new |

---

## 1. How it is reached

`CInGameIdler_NamedElementTooltip` (`0x6C43B0`) tests the string at the element's `+8` against
`topbar` first (`0x6C443F`); on a match, and with no custom game settings in force, it calls the top
bar's slot 5 with the out tooltip and the element, and returns. That every element of the top bar
carries `topbar` there is `inferred`: the builder tests the element's own name (its slot 17) against
twenty-nine of the bar's names, which could not be reached otherwise, and `interface/topbar.gui`
declares all of them flat inside the one window.

`CTopBar::BuildTooltip` itself, `ret 8`, `confirmed`:

1. **The strategic warfare window first.** When the window at top bar `+0x380` is shown (its slot 4)
   and its `+0x24`'s element test passes, `BuildStratWarfareTooltip` answers and nothing else runs.
2. The country is the player's (idler slot 23, the database).
3. Then the element's name, each tested in this order; the first that matches fills the tooltip:

| element | text | delayed |
| --- | --- | --- |
| `energy_number`, `metal_number`, `raremat_number`, `oil_number` | the ledger of energy, metal, rare materials, crude oil (section 3) | |
| `fuel_number`, `supplies_number` | the ledger of fuel, supplies; **nothing for a government in exile** (`+0x95`) | |
| `money_number` | the ledger of money | |
| `ic_number` | section 4 | |
| `icon_ic_small` | `IC_IRO` | `IC_DRO` |
| `icon_energy_small`, `icon_metal_small`, `icon_raremat_small`, `icon_oil_small`, `icon_fuel_small`, `icon_supplies_small`, `icon_money_small` | `ENERGY_IRO`, `METAL_IRO`, `RAREMAT_IRO`, `CRUDE_OIL_IRO`, `FUEL_IRO`, `SUPPLIES_IRO`, `MONEY_IRO` | the same with `_DRO` |
| `icon_dissent` | `DISSENT_IRO` | `DISSENT_DRO` |
| `dissent_number` | section 5 | |
| `icon_diplomacy` | `DIPLOINF_IRO` | `DIPLOINF_DRO` |
| `diplomacy_number` | section 6 | |
| `icon_national_unity` | `NATIONAL_UNITY_IRO` | `NATIONAL_UNITY_DRO` |
| `national_unity_number` | section 7 | |
| `icon_espionage` | `ESPIONAGE_IRO` | `ESPIONAGE_DRO` |
| `espionage_number` | `FREE_SPIES`, alone | |
| `icon_leadership` | `OFFICERS_IRO` | `OFFICERS_DRO` |
| `icon_manpower` | `MANPOWER_IRO` | `MANPOWER_DRO` |
| `manpower_number` | section 9 | section 9 |
| `leadership_number` | section 8 | |
| `topbarbutton_diplo`, `_prod`, `_tech`, `_politics`, `_intelligence`, `_statistics`, `_theatre` | `DISABLED_IN_SCENARIO` when the button is disabled (its slot 48) and the game has a scenario; else nothing | |

Every other element of the bar - the date, the name, the flag, the speed buttons, `pause_bg`, the
menu, outliner and strategic warfare buttons - gets an empty tooltip here, and so only its
shortcut line (`FINDINGS-tooltips.md`, section 6) where it has one. Each text is rendered with the
game settings' colours as every tooltip is.

**`pause_bg`.** The top bar's update gives the button its own tooltip through its slot 51
(`0x6CC92E`): `PAUSE_RESUME` while paused, `FE_PAUSED_TEXT` while not. Nothing read here reads that
back: neither `CInGameIdler::GetTooltip` nor the shortcut step asks a button for it. Whether it is
ever shown is **not established**.

**The speed buttons** have a case of their own further down `0x6C43B0` (`0x6C4AA1`): when idler
`+0x68` is set and idler slot 18's `+0x34` is clear - "this player may not set the speed", by its
shape a multiplayer client - the text is the key at `0x15D20C4`. In a game of one player, nothing.
It is reached only for an element whose `+8` is not `topbar`, so if the inference above holds it is
not the top bar's own speed buttons it serves.

## 2. Every line's colour

Four short strings are everywhere below: `§R` (`0x15B5C58`), `§Y` (`0x15B5C54`), `§G` (`0x15B5C50`),
`§G+` (`0x15B6B84`), and `§W` (`0x15B6700`) to close.

## 3. A resource's ledger: `BuildGoodsLedgerTooltip` (`0x4F3000`)

`Hoi3CString* __stdcall (CCountry*, Hoi3CString* out, int goods)`, `ret 0xC` - the record's
reading of its fifteen pools stands (`FINDINGS-uinumbers.md`, section 5). What it writes, in order,
`confirmed`:

1. **`RES_CHANGE`** ("Changes by $VAL$ every day.\n") with

       change = produced + convoyed in (not for supplies or fuel) + tribute received + traded for
                + made by converting + sent back + the pool at +0xA64 + income from debt
              - (sent to units - repaid away - tribute sent + used + used in converting
                 + convoyed out + traded away)
       VAL = (change < 0 ? §R : §G+) + change to two places + §W

   so nothing changing reads `§G+0.00`.
2. Then one line per pool, each only where its condition holds, each `VAL` a colour, a number to
   two places and `§W`:

| key | when | VAL |
| --- | --- | --- |
| `RES_PROD` | produced > 0 | `§G+` produced |
| `RES_CONVOYED_IN` | not supplies or fuel, and > 0 | `§G+` it |
| `RES_TRADED_FOR` | > 0 | `§G+` it |
| `RES_INC_DEBT` | > 0 | `§G+` it |
| `RES_FROM_PUPPETS` | tribute received > 0 | `§G+` it |
| `RES_CONVERTED` | used in converting ≠ 0 | its negation: `§R` and the minus where it was used, `§G+` where it was negative |
| `RES_CONVERTED` | made by converting ≠ 0 | `§G+` where above 0, else `§R` |
| `RES_TRADED_AWAY` | > 0 | `§R` and its negation |
| `RES_REPAID_AWAY` | > 0 | `§R` and its negation |
| `RES_CONVOYED_OUT` | > 0 | `§R` and its negation |
| `RES_SENT_TO_MASTER` | tribute sent < 0 | **`§G+` and its negation** - green, though it is a loss (`0x4F4556`..`0x4F4594`) |
| `RES_INTO_NET` | sent to units > 0 | `§R` and its negation |
| `RES_USED` | > 0 | `§R` and its negation |
| `RES_SHIPPED_BACK` | sent back > 0 | `§G+` it |

   Each key ends in its own `\n`.
3. **`"\n"` and the contributors to the good's global modifier** (section 10), kind by goods
   from the table built at `0x4F4AB0`: supplies `MODIFIER_GLOBAL_SUPPLIES` (27), fuel
   `MODIFIER_GLOBAL_FUEL` (29), money `MODIFIER_GLOBAL_MONEY` (31), crude oil `_CRUDE_OIL` (19),
   metal `_METAL` (23), energy `_ENERGY` (21), rare materials `_RARE_MATERIALS` (25).

## 4. IC: `ic_number`

`confirmed`, `0x6CCF18`..`0x6CD6B0`:

1. `IC_NUMBER_IRO` - "Wasted IC: §Y$WASTED$§W. Base IC: §Y$BASE$§W. Available IC:
   §Y$AVAILABLE$§W.\n" - with `WASTED` `CCountry::GetAvailableIC`, `AVAILABLE` the total IC (+0x604)
   and `BASE` the province IC (+0x60C), each as a whole number (`IntToString`). The same three
   figures the bar shows.
2. Where the technology IC bonus (`technology_status +0x90`) is not 0:
   `FROM_TECHNOLOGY` + `": §G+"` + the bonus x 100 to two places + `"%§W\n"`.
3. The contributors to `MODIFIER_GLOBAL_IC` (17).
4. Where lend-lease reaches the country (`0x508970`): `"\n"` + `LEND_LEASE_RECEIVED_VALUE` with `VAL`
   the IC received (+0x6EC); then for each entry of `lend_lease_from_yesterday_values`, `"\n- @"` +
   the giver's tag + its name + the amount and `LEND_LEASE_MAX_VALUE`, each to three places, the
   amount held to the giver's maximum.

## 5. Dissent: `BuildDissentTooltip` (`0x4F99C0`)

`Hoi3CString* __stdcall (CCountry*, Hoi3CString* out)`, `ret 8`. `confirmed`:

1. `DISSENTV_IRO` - "With the current investment in consumer goods, dissent will change by
   $CHANGE$ every day." - with `CHANGE` a colour, the day's change to two places and `§W`. The change
   is `CDistributeConsumerGoods::GetDissentChange` for the consumer goods slider (`+0x5F4`'s second),
   a 48.15 number, formatted by `FormatFixed15` - **rounded**, by `sprintf`, where every thousandths
   figure is cut. The colour: `§R` above 0, `§Y` at 0, `§G` below.
2. The contributors to `MODIFIER_DISSENT` (43); where that comes to more than one character,
   `"\n"` + `DISSENTV_IRO2` ("The following circumstances will increase the dissent as well.\n") +
   it.
3. Where the country's dissent (+0x10B4) is not 0: `"\n"` + `DISSENTV_IRO3` ("Our current level of
   dissent gives these penalties.\n") + every value of the country's own scaled copy of the static
   `dissent` (+0xB1C), through its slot 7 (section 10).

## 6. Diplomacy: `diplomacy_number`

`confirmed`, `0x6CE3C1`..: `DIPDETAILS_IRO` - "Every day our pool of influence change by
$DAILY$§W.\n§G+$PRODUCED$§W from leadership and §R-$UPKEEP$§W lost from influencing other nations."

    PRODUCED = the diplomacy slider's effective share (CDistributionSetting_EffectiveShare,
               base x factor >> 15, then to thousandths) x total leadership / 1000
               x LEADERSHIP_TO_DIPLOMACY / 1000                         to two places
    UPKEEP   = CCountry::GetInfluenceUpkeep                              to two places
    DAILY    = (PRODUCED - UPKEEP < 0 ? §R : = 0 ? §Y : §G+) + it         to two places

## 7. National unity: `BuildNationalUnityTooltip` (`0x4F8BE0`)

`Hoi3CString* __stdcall (CCountry*, Hoi3CString* out)`, `ret 8`. `confirmed`:

1. `§Y` + national unity (`+0x10B8`) to three places + `"%§W\n"`.
2. A list: for each of the strategic warfare impacts that is not 0 - convoys (`+0x118C`, `STW_CONV`),
   allies (`+0x1190`, `STW_ALLIES`), bombing (`+0x1194`, `STW_BOMB`) - the key + (`§G+` above 0,
   else `§R`) + the impact to three places + `"§W\n"`; then the contributors to
   `MODIFIER_NATIONAL_UNITY` (44).
3. Where the list is under three characters, `NO_CURR_EFFECTS_ON_NU`; else `STRMONTHLY_CHANGE`
   ("Monthly Change:") + `"\n"` + the list.
4. The contributors to `MODIFIER_NATIONAL_UNITY_EFFECT` (68); where more than two characters,
   `"\n"` + `EFFECT_SIZE_MOD_NU` + `"\n"` + them.

## 8. Officers: `BuildOfficerTooltip` (`0x6CFFF0`), for `leadership_number`

The country's tag in ECX, the out `GuiTooltipText` on the stack, bare `ret`. Only `text` is
filled. `confirmed`:

1. `OFFICER_NUMBER2_IRO` - "We have §Y$OFFICERS$§W officers covering §Y$DIVISIONS$§W brigades, ships
   and wings. ... we need at least §Y$NEED$§W officers. Every day we are educating §Y$DAILY$§W new
   officers." - `OFFICERS` the officers (+0xC4), `DIVISIONS` the brigades, ships and wings
   (+0xC8, in thousandths), `NEED` the officers they require (+0xD0), each with no decimals; and

       DAILY = the officer slider's effective share x total leadership / 1000
               x LEADERSHIP_TO_OFFICERS / 1000 x (1000 + MODIFIER_OFFICER_RECRUITMENT) / 1000
                                                                          to one place
2. The contributors to `MODIFIER_OFFICER_RECRUITMENT` (82); where more than two characters,
   `"\n"` + them.

## 9. Manpower: `GetManpowerDetailsText` (`0x6D0540`), for `manpower_number`

`__cdecl (GuiTooltipText* out, CCountryTag* tag)`, bare `ret`. It fills **two** of the three
strings - the record had its out as a plain string. `confirmed`:

- **text:** `MANPOWER_DETAILS_IRO` - "Our army needs §Y$NEED$§W manpower to reinforce, and we use
  §Y$USED$§W every day." - `NEED` what reinforcing every unit would take (+0xA9C) and `USED` what
  reinforcing took today (+0xAA0), to two places where the need is under 10, to one at or above.
- **delayed:** `MANPOWER_DETAILS_DRO` - "Monthly gain: §Y$MONTHLY$§W\nBase: §Y$BASE$§W\n" - with
  `MONTHLY` `GetMonthlyManpowerGain` to one place and

      BASE = (max_manpower / 1000 x 0.5) / (MODIFIER_GLOBAL_MANPOWER_MODIFIER / 1000 + 1
                                           + technology manpower gain / 1000)

  worked in single-precision floats and written `%.3f`; then the contributors to modifier 4
  (`MANPOWER`, the country-wide flat one); then, where the technology manpower gain
  (`technology_status +0x8C`) is not 0, a `"\n"` where the list so far has more than one character
  and `FROM_TECHNOLOGY` + `": §G+"` + the gain x 100 to two places + `"%§W\n"`; then the
  contributors to modifier 6 (`GLOBAL_MANPOWER`, the percentage), with no newline before them.

## 10. Where a modifier comes from

A country's modifier (`+0xD90`) is rebuilt each day from its sources, and every source is appended
to the modifier's **contributor vector** (`+8`..`+0xC`) as it is added (`FINDINGS-countrymodifier.md`,
section 2). Four virtual slots of `CModifier` turn that into text.

### Slot 9, the contributors to one kind (`0x459DA0`)

`Hoi3CString* __thiscall (CModifier*, Hoi3CString* out, int kind, int scale)`, `ret 0xC`; every
caller passes a scale of 1000. `confirmed`:

    out = ""
    if the modifier has no contributors and its value of `kind` is not 0:
        out = slot 8 (kind, scale)                                        its own line
    last = 0
    for each contributor c, in the order they were added:
        if out has grown since `last`:  out += "\n"
        last = out.length
        line = c.slot 9 (kind, scale)                                      recursion
        if c.slot 10 and line is not empty:  out += <c's +0x2C's name> + ": "
        out += line trimmed

So a source with nothing of the kind writes nothing and no newline. Slot 10 answers false for
every class under `CModifier` but `CProvinceModifier` (`0xA92590`, true), so only a province's
contribution is headed by a name.

### Slot 8, a contributor's own line (`0x459880`)

`Hoi3CString* __thiscall (CModifier*, Hoi3CString* out, int kind, int scale)`, `ret 0xC`.
`confirmed`:

    v = value of kind x scale / 1000
    out = slot 6 (its display name) + ": "
        + colour + (v > 0 ? "+" : "") + figure + "§W"
    colour: more_is_better ? (v > 0 §G, v < 0 §R, else §Y) : (v > 0 §R, v < 0 §G, else §Y)
    figure: percent ? v x 100 to one place + "%" : v to two places

### Slot 6, the display name, by class

| class | slot 6 | name |
| --- | --- | --- |
| `CModifier`, `CProvinceModifier`, `CIdeology` | `0x456DD0` | empty |
| `CStaticModifier`, `CTriggeredModifier` | `0x45A2D0` | its name, localised |
| `CGovernment` | `0x5241B0` | its key, localised |
| `CGovernmentPosition`, `CMinisterType`, `COccupationPolicy`, `CStrategicResource` | `0x526750` | the key at `+0x30`, localised |
| `CLaw` | `0x529100` | its slot 13 |
| `CFactionModifier` | `0x522480` | its faction's slot 6 |
| `CTrait` | `0x5B29D0` | not read |

So a law's line is "Its name: §G+10.0%§W", the static `dissent`'s "Dissent: §R-5.0%§W", and the
province modifiers a country controls, being plain `CProvinceModifier`s whose own name is empty,
head their contributors' lines with the province's.

### Slot 7, every value it holds (`0x459AB0`)

`Hoi3CString* __thiscall (CModifier*, Hoi3CString* out)`, `ret 4`. For each kind, in definition
order, whose value is not 0: `"\n"` between lines, the kind's name
(`CModifierDefinition_GetLocalisedName`, its key at `+4` localised), `": "`, the colour and sign as
slot 8's, the figure (a percentage x 100 to one place and `%`), `§W`. `CMinisterType` (`0x52AB90`)
adds, after it, a `DECAY` line per technology category the type changes the decay of.

### The definitions, and their two flags

`0x456E00`, recorded as `BuildModifierEffectsText`, is **the global initialiser of the modifier
definitions**: 108 times over, `operator new(0x2C)`, the name built on the stack, a save token, the id
in EDX, and `CModifierDefinition_Construct` (`0x456D50`, `ret 0x2C`), then
`ModifierDefinitionDatabase::Add`. Its "108 localisation keys" are the definitions' names. The
constructor writes the vftable `0x15BC4E4`, the name at `+4`, the token at `+0x20`, the id at
`+0x24`, and **two flags**: the push nearest the name to `+0x28`, **shown as a percentage**, and the
one before it to `+0x29`, **more is better**. `confirmed`.

Every kind is both, except these. `confirmed`, read off each push:

| neither: a plain number, more is worse | `MINIMUM_REVOLT_RISK`, `LOCAL_REVOLT_RISK`, `GLOBAL_REVOLT_RISK`, `ATTRITION`, `WAR_EXHAUSTION`, `MAX_WAR_EXHAUSTION`, `LOCAL_PARTISAN_SUPPORT`, `NEUTRALITY_CHANGE`, `PARTISAN_EFFICENCY` |
| --- | --- |
| **a plain number**, more is better | `MANPOWER` (3 and 4), `FORT_LEVEL`, `COASTAL_FORT_LEVEL`, `MODIFIER_INFRASTRUCTURE`, `MODIFIER_IC`, `LOCAL_LEADERSHIP`, `GLOBAL_LEADERSHIP`, `NATIONAL_UNITY`, `NAVAL_CAPACITY`, `AIR_CAPACITY`, `ALIGN_TOWARDS`, `RADAR_LEVEL`, `UNIT_START_EXPERIENCE`, `LOCAL_AA`, `LAND_INTEL_BOOST`, `NAVAL_INTEL_BOOST`, `LOCAL_UNDERGROUND` |
| a percentage, **more is worse** | `INCORPORATE_COST`, `WAR_CONSUMER_GOODS_DEMAND`, `PEACE_CONSUMER_GOODS_DEMAND`, `DISSENT`, `SUPPLY_CONSUMPTION`, `PEACETIME_MANPOWER_ROTATION`, `UNIT_RECRUITMENT_TIME`, `THREAT_IMPACT`, `NATIONAL_UNITY_EFFECT`, `RESERVES_PENALTY_SIZE`, `NEUTRALITY`, `AIR_BUILD_SPEED`, `LAND_BUILD_SPEED`, `ROCKET_BUILD_SPEED`, `TANK_BUILD_SPEED`, `NAVAL_BUILD_SPEED`, `JUNGLE_EFFECTS`, `SW_NATIONAL_UNITY_EFFECT` |

The 32 mission efficiency definitions made at startup have both set (`0x0101`,
`InitMissionEfficiencyModifiers`).

## Kept as read, though they look odd

1. **Tribute sent to a master shows green, with a plus** (section 3).
2. **Dissent's change is rounded** where every other figure is cut (section 5).
3. **Manpower's two lists run together**: no newline between the flat kind's contributors and the
   percentage's when there is no technology line between them (section 9).

## Not established

- **What the element's `+8` is.** Read as the window the element belongs to (section 1).
- **Whether `pause_bg`'s tooltip is ever shown** (section 1).
- **The name a `CProvinceModifier` contribution is headed by**: `+0x2C`'s `+8` object's slot 7 was not
  followed; the province's name is the reading's expectation, not a reading.
- **`CTrait`'s slot 6**, and the key at `0x15D20C4`.
