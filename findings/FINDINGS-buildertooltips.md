# The builder windows' tooltips

*Read 2026-10-11 for OpenHOI3's builder windows; the mechanics spec is
`OpenHOI3/docs/mechanics/builders.md`, section 11. Addresses are VA / rva. Everything here is one
build of `hoi3_tfh.exe`. Nothing in it was watched in a running game.*

What the division designer, the ship builder, the air builder and the brigade builder say in a
tooltip, read out of each one's slot 6 and out of the arm of the in-game screen's named-element
routine their practical icon reaches. `FINDINGS-builders.md` has what the windows show and do;
`FINDINGS-tooltips.md` how a tooltip is asked for and shown.

**One correction on the way** (section 4): the routine the record had as the builders' sort column
label is the ledger's, and none of the builders calls it.

## 1. How a builder window is asked

`CProductionView::BuildTooltip` (`0x7FFD30 / 0x3FFD30`) asks first whichever of its dialogs is
shown - each dialog's slot 5 says whether it is - and hands it the whole question: the dialog's slot
6 with `out` and the element, and nothing of the production screen's own is asked after
(`0x7FFE01`..`0x7FFED1`). So **while a builder window is up, every element the production view is
asked about is answered by the builder** - its own and the eight of the production screen's frame
it leaves showing (`FINDINGS-builders.md`, section 7), which none of the four answers. `confirmed`

Before the view is asked, the in-game screen's named-element routine (`0x6C43B0`) has answered two
names wherever they are: `on_complete_icon` and `on_complete_impact` (section 3).

## 2. The four routines

`GuiTooltipText* __thiscall BuildTooltip(this, GuiTooltipText* out, CGuiObject* element)`, `ret 8`,
`out` at `[ebp+8]` and the element at `[ebp+0xC]`, returning `out`. Each is a chain of compares of
the element's slot 17 - its name - against literals, and an arm for each:

| | designer `0x7EA930` | ship `0x80D420` | air `0x7D3AB0` | brigade `0x7DC090` |
| --- | --- | --- | --- | --- |
| ends | `0x7EC530` | `0x80F226` | `0x7D534E` | `0x7DDA70` |

**A column's button** gives `text` = the localised `_IRO` key and `delayed` = its `_DRO`: the
column's short name, and after a moment what it means (`BUILD_STR_IRO` "Strength" ... `BUILD_STR_DRO`
"How many men each brigade is made up of."). `confirmed`, every arm's target mapped by script and
three read through (`0x7EAA2D`, `0x80EF63`..`0x80F055`, `0x7EB5A8`).

| element | key | designer | ship | air | brigade |
| --- | --- | --- | --- | --- | --- |
| `sort_prio` | `BUILD_PRIO` | yes | yes | yes | yes |
| `sort_str` | `BUILD_STR` | and `total_str` | | | yes |
| `sort_sa`, `sort_ha` | `BUILD_SA`, `BUILD_HA` | and `total_` | | | yes |
| `sort_soft_a`, `sort_hard_a` | `BUILD_SA`, `BUILD_HA` | | | yes | |
| `sort_piercing`, `sort_armored` | `BUILD_PIERCING`, `BUILD_ARMOR` | and `total_` | | | and `total_` |
| `sort_ad`, `sort_cw`, `sort_aa`, `sort_def`, `sort_tou`, `sort_sup` | `BUILD_AD` ... | and `total_` | | | yes |
| `sort_org`, `sort_sc` | `BUILD_ORG`, `BUILD_SC` | and `total_` | yes | yes | yes |
| `sort_sof` | `BUILD_SOF` | and `total_sof` | | | yes |
| `sort_fc` | `BUILD_FC` | and **`total_oc`** | yes | yes | yes |
| `sort_speed` | `BUILD_SPEED_DD` / **`BUILD_SSPEED`** | `_DD`, and `total_speed` | `SSPEED` | `SSPEED` | `_DD` |
| `sort_ic`, `sort_mp` | `BUILD_IC`, `BUILD_MP` | yes | yes | yes | yes |
| `sort_time`, `sort_off` | `BUILD_TIME_DD`, `BUILD_OFF_DD` | yes | yes | yes | yes |
| `sort_con_a`, `sort_sub_a`, `sort_shore`, `sort_sea_d`, `sort_sub_det`, `sort_visibi` (`BUILD_VISI`), `sort_distance`, `sort_hull`, `sort_pos` | | | yes | | |
| `sort_sea_a`, `sort_air_a`, `sort_air_d`, `sort_sur_det`, `sort_air_det`, `sort_trans`, `sort_range` | | | yes | yes | |
| `sort_surf_d` | **`SURFACE_DEFENCE`** as `text`, `BUILD_SURF_D_DRO` | | | yes | |
| `sort_strat_a` | `BUILD_STRAT_A` | | | yes | |

`total_oc` is the name the designer's file gives its fuel total, so the pair matches. The air
builder's `sort_surf_d` alone takes a plain text key, the technology screen's `SURFACE_DEFENCE`,
for its short name.

**The four step buttons** - `parallel_minus`, `parallell_plus`, `serial_minus`, `serial_plus` - give
`text` = `BUILD_ADD_REM_BUNDLE` with `$NUM$` = `10`, through AppendLocalisedLine (`0x7EB557`..
`0x7EB5A3`). In English it is "§YCtrl + LMB§! to add or remove §G$NUM$§!" - **the original's own
word that a step of ten is Ctrl and a click**, which `FINDINGS-builders.md` left open. The key the
step's code asks (the in-game screen's input object, slot 12) was not traced to a key code, so this
is the text's word and not the code's: `likely`.

**The designer's own four** (`0x7EA930`):

- **`terrainbonus`**: `text` = the terrain summary the design keeps at `+0x1D4` (section 5), with no
  `delayed`. `confirmed` (`0x7EA99F`..`0x7EA9E0`)
- **`combined_arms_bonus_value`**: `text` = `BUILD_CA_BONUS_VALUE`, "Combined arms bonus for combat".
- **A name beginning `combined_arms_indicator_`** (a compare of its first 24 characters): the number
  after it, by `atoi`; for one above 0, the combined arms group of that index in the unit database's
  vector at its `+0` - the vector the window's own update counts from 1, so `combined_arms_indicator_1`
  is the first group of `common/combined_arms.txt` - and `text` = its name (`0x5B1BA0`: its key at
  `+8`, localised), `delayed` = its key + `_desc`, localised. In the base game, `infantry_unit_type`
  "Infantry", and "Infantry is the basis for combined arms. ..." `confirmed` (`0x7EB431`..
  `0x7EB552`). The index is not checked against the vector's length.

**Anything else is empty** in all four: an unmatched last compare jumps to the epilogue
(`0x80F1C6`, `0x7D52EF`, `0x7DD82D`; the designer's prefix compare at `0x7EB44D`). So **a list's
lines, the panel's figures, `accept`, `cancel`, the template buttons and the checkbox say nothing** -
the window's tooltips are its headers', its step buttons' and the designer's four. `confirmed`

## 3. The practical icon and its figure

`0x6C43B0` compares slot 17 with `on_complete_impact` and with `on_complete_icon`, and both go to
one arm (`0x6C4AD7`..`0x6C4AFE`, then `0x6C4EB3`):

    category = the technology database's +0x2C table, looked up by the element's own string at +8
    if none:  the tooltip is empty
    text = category's name (slot 0, its localised name at +0x24) + " "
         + TC_BUILD_COST_AND_TIME + " §Y"
         + FormatFixedPoint(CCountry::GetCategoryBuildDiscount(the played country, category) * 100, 1)
         + "%§W"

"Infantry Practical reduces building cost and time by §Y12.3%§W". The discount is in thousandths, so
times 100 and one place is a percentage, cut. The country is the played one: the idler's slot 23
gives its tag. `confirmed` (`0x6C4EB3`..`0x6C511A`)

**What puts a category there.** Each of the four windows, as it fills the icon and its figure, calls
their slot 30 with the key of the unit's practical (the type's `+0x3C`, its key at `+8`) - designer
`0x7E6908` and `0x7E6A33` for each `on_complete_entry`, ship `0x80BE1A` and `0x80BF3F`, air
`0x7D2492`, brigade `0x7DA7B8` and `0x7DA8F1`. That slot 30 writes the string at `+8` is `inferred`
from this pairing: nothing else connects the two. An icon no window has filled - the ship builder's
before a type is picked - has its own name there, which names no category, and says nothing.

This is the arm `FINDINGS-tooltips.md` called "technology icons": only these two names reach it.

## 4. Correction: `0x7C3510` is the ledger's

`CInGameIdler_ViewTooltip` (`0x662C50`) answers, when the idler's `+0x1CE0` is set, with
`0x7C3510`, the element in ECX and `out` pushed (`0x662C5D`..`0x662C75`). The record had that
routine as `BuildBuilderSortColumnLabel`, "called by" the four builders' slot 6, and `+0x1CE0` as "a
builder window open". Neither holds:

- **it has one caller**, `0x662C69` (`findRefs --callers 0x7C3510`); the four slot 6 routines have
  the same shape and the same keys, which is where the claim came from, and call nothing of the kind;
- **the names it answers are `ledger_sort_*`**, the elements of `interface/hoi3ledgericons.gui`, after
  first asking whether the element's slot 17 is `TableItemText`.

So it is renamed `BuildLedgerColumnTooltip`, and `+0x1CE0` is most likely the ledger - `inferred`
from the names. It was not read further.

## 5. The designer's terrain summary

`CDivisionDesigner::UpdateDesign` (`0x7E6160`), after every change to the design, keeps at `+0x1D4`
a text of what ground, rivers, the night, forts and landings do to the design. `confirmed`
throughout, `0x7E6D52`..`0x7E6FE9` for the sums, `0x7E73F7`..`0x7E749B` for the division and
`0x7E95AD`..`0x7EA000` for the text.

**The sums**, over the design's brigades, each made with every technology at the country's level
(`FINDINGS-builders.md`, section 2) - a `CUnitAdjuster` each, `+8` attack, `+0xC` defence, `+0x10`
movement, `+0x14` attrition:

    for each terrain t of the map's list (map/terrain.txt's categories, in order):
        sum[t] += the brigade's adjuster for t                 ; CSubUnitDefinition +0x54
        sum[t].attack  += t's own attack                       ; CTerrain +0x50
        sum[t].defence += t's own defence                      ; CTerrain +0x4C
    river      += the brigade's river adjuster,      attack += RIVER_CROSSING_PENALTY
    night      += the brigade's night adjuster,      attack += BASE_NIGHT_PENALTY
    fort       += the brigade's fort adjuster,       attack += BASE_FORT_PENALTY
    amphibious += the brigade's amphibious adjuster, attack += AMPHIBIOUS_LANDING_PENALTY

and then each of them, all four figures, divided by the number of brigades
(`CUnitAdjuster::Divide`, `x * 1000 / (n * 1000)` in 64 bits, cut toward nothing). **So the
terrain's own figures and the defines come in once each, as an average does, and a terrain's
attrition does not come in at all.**

**The text**, empty to start:

    for each terrain t, in the same order:
        line = CUnitAdjuster_Describe(sum[t])
        if line is not empty:   text += t's name + ": " + line + "\n"
    then the same for river, night, fort and amphibious, named by the localised
    RIVER_ADJUSTER, NIGHT_ADJUSTER, FORT_ADJUSTER and AMPH_ADJUSTER

**`CUnitAdjuster_Describe`** (`0x5D5100 / 0x1D5100`) empties its `out` and calls
`AppendAdjusterFigure` (`0x5D4F40`) four times:

| figure | label | value passed | sign turned for the colour |
| --- | --- | --- | --- |
| attack | `UA_ATTACK` | `attack * 100` | no |
| defence | `UA_DEFENCE` | `defence * 100` | no |
| movement | `UA_MOVEMENT` | `movement * 100` | no |
| attrition | `UA_ATTRITION` | **`attrition` as it is** | yes |

The hundred is `100000.5` floored, times the figure, over 1000 in 64 bits. **`AppendAdjusterFigure`**:

    if value == 0:  nothing
    if out is not empty:  out += ", "
    out += label + " "
    out += (turned ? -value : value) < 0 ? "§R" : "§G"
    if value > 0:  out += "+"
    out += FormatFixedPoint(value, 1) + "%§W"

So "Mountain: Attack §R-47.5%§W, Defence §R-17.5%§W, Movement §R-10.0%§W" for three infantry
brigades and one armoured, by the base game's files and no technology: the mountain's `attack =
-0.4` four times and the armour's `-0.30`, over four; the armour's `defence = -0.70` and `movement
= -0.40` over four. The same design's river line is the armour's `-0.05` and four times `-0.6`, over
four: "River: Attack §R-61.2%§W".

## Kept as read, though they look odd

1. **Attrition is written without its hundred**: an adjuster's attrition of `0.5` reads `+0.5%`
   where its other figures of `0.5` read `+50.0%`. Its colour is turned, so more attrition is red.
2. **A terrain's own attack and defence count in its line but its attrition does not.**
3. **The `+` goes by the figure and the colour by the turned figure**, so attrition above nothing is
   red and has a `+`.
4. **`combined_arms_indicator_` and a number past the groups** reads past the list.
5. **Everything but the headers, the step buttons and the designer's four is silent** - the lists'
   lines, the costs, the light, `accept`.

## Not established

- **Which key the step of ten asks**: the text says Ctrl.
- **That slot 30 writes the string at `+8`**, which only the pairing in section 3 shows.
- **`BuildLedgerColumnTooltip` past its names**, and what `+0x1CE0` is.

## In the record

Entered in `ghidra/project.json` by `fragments/merged/builder-tooltips.json`: three slot 6 routines
new (`CShipBuilder`, `CAirBuilder`, `CBrigadeBuilder::BuildTooltip`), `CUnitAdjuster_Describe`,
`AppendAdjusterFigure`, `CCombinedArmsGroup_GetName` and `LocaliseKeyInto` new; and five revised -
`CDivisionDesigner::BuildTooltip` read whole and `confirmed`, `CInGameIdler_NamedElementTooltip` for
the practical icon, `CInGameIdler_ViewTooltip` for what `+0x1CE0` is not,
`BuildBuilderSortColumnLabel` renamed `BuildLedgerColumnTooltip`, and
`CDivisionDesigner::UpdateDesign` for the terrain summary.
