# The diplomacy screen: what `CDiplomacyView` puts in each element

Read out of the executable on 2026-10-12 for OpenHOI3's diplomacy screen, in two briefs of one wave
(`WAVE.md`, the diplomatic state wave): **D**, the list half - the country list, its tabs and sorting,
choosing a country and what switches between the views; **E**, the panel half - what is shown of the
chosen country. What the figures are is `FINDINGS-diplostate.md`; the screen's decision list is
`FINDINGS-eventfire.md`, 3.7, and is not redone. The file is `tfh/interface/country_diplomacy.gui`.
Addresses are **virtual**, based `0x400000`, unless a line says rva.

Conventions below: "selected" is the country at `CDiplomacyView +0x1DC/+0x1E0`, "player" the one at
`CCurrentGameState +0xC30/+0xC34`; `T = selected->+0xE28[c]` is the selected country's status towards a
country c and `S = c->+0xE28[selected]` the other way. A window finds an element by its slots 13 (a
button), 14 (a text box), 15 (an instant text box), 17 (an icon), 27 (a child window), 31 (a list box)
and 39 (an overlapping-elements box); an icon's slot 18 sets its frame (from 1) or a progress bar's
fill (0 to 100), and its slot 53 a flag by country id (as in `FINDINGS-unitpanel.md`,
`FINDINGS-topbar.md`). `FormatFixedPoint` (FFP) truncates. Localisation texts are the same in
`localisation` and `tfh/localisation` unless a line says otherwise.

## The list half

"A custom game" below is the first byte of `g_CustomGameSettings`, Their Finest Hour's staged custom
mode the `CGM_*` texts describe (that it means that is inferred); outside one, the normal branch is
the one that matters.

### D.1 The view, and when things happen

- **Construction** (`CDiplomacyView::CDiplomacyView`, `0x77D090`, its one call at `0x659878` after
  `push 0x560; call operator new`): the view is `0x560` bytes, index 0 among the in-game screen's views
  (`CInGameIdler +0xD00`), and **starts with the played country selected**; then `BuildWidgets`
  (`0x781310`), which binds every button and runs again from Rebuild (slot 0).
- **Show (slot 2, `0x77DF40`)**: where exactly one province is selected on the map and has an owner,
  that owner becomes the selected country; **where the country list is empty, the All tab's handler
  runs** - so the first opening shows All, and after that whatever tab and sort were last made stay, as
  long as the in-game screen lives; then the triangle's markers, the faction boxes, the panel
  (`RefreshCountryInfo`), the action list and the decision list, and the windows shown; the panel back
  to Info. **The country rows are not made again.**
- **Update (slot 6, `0x77E530`)**, through `CInGameIdler_UpdateOpenView` (`0x651D30`) from
  `CInGameIdler::Update` at `0x656465` - every frame, inferred: every *visible* row's
  `UpdateResourceIcons`, so the icons' colours are live; a row whose country owns no province any more
  is taken off the list and the list box made again. Threat, name and flag are not refreshed.
- Hide (slot 4) is the base's (`0x61FC70`). Slot 5 (`0x783DE0`) clears the markers and the custom
  game's widgets; `CInGameIdler_UpdateOpenView` runs slots 5, 4 and 2 in that order when the screen's
  `+0xD30` is set.
- **Rebuild (slot 0, `0x7812D0`)** makes the main window again, so `country_listbox` comes back empty,
  and nothing on that path fills it - Show fills only an *empty country list* - so the rows stay empty
  until a tab or a sort button is pressed (inferred; who calls slot 0 was not read).
- **On a diplomatic change**, `CInGameIdler` slot 101 (`0x6782B0`) refreshes the actions, the markers,
  the panel and the faction boxes, **and not the rows**.

### D.2 The tabs (in the window `alignment`)

The texts are the file's; the code never sets them: `DIP_MAJORS` "Majors", `DIP_NEIGHBOURS`
"Neighbours", `DIP_UNALIGNED` "Unaligned", `DIP_SELF` "Selected", `DIP_ALL` "All". No handler marks a
tab as pressed. Each empties the country list (view `+0xD0`), fills it, and makes the list box again -
rows added head to tail, so they stand in the list's order - and the triangle's markers.

| button | who | order |
| --- | --- | --- |
| `majors_button` | every country of the game state's vector that **owns a province** and is **`major = yes` (`CCountry +0x15C`) or has max_ic (`+0x60C`, the whole IC of its provinces) above 100** | the vector's, unsorted |
| `neighbours_button` | the **played country's** neighbour list (`CCountry +0xFD8`), those owning a province - countries owning a province beside one the player owns, where its owner is its controller | that list's |
| `unaligned_button` | every country of the vector owning a province whose faction is the null faction | the vector's |
| `self_button` ("Selected") | **the selected country alone**, with no test of provinces | |
| `all_button` | every country of the database (0 to count - 1) owning a province | **by name, A to Z** |

All's names are compared byte by byte as unsigned Windows-1252 - case and all, accented letters after
`z` - and equal names keep the database's order.

**Two more lists the file declares**, both by name A to Z:
- **The faction buttons**: for each real faction of the game state's list (`+0xCE4`; slot 7, which the
  null faction answers no), a `diplomacy_faction_sort_window` at `diplomacy_sort_faction_start` (56,75)
  + n x `diplomacy_sort_faction_offset` (101,0), its `faction_symbol_big_button` given the sprite
  `GFX_sort_<faction key>` and the faction's slot 6 text; a click lists the faction's members that own a
  province (`ListFactionMembers`, `0x78CC10`). Its tooltip is the faction's slot 6 text, delayed
  `0x522AF0` (the faction's part, not read).
- **The continent buttons**: one `continent_button` a continent of the map's list but `lake` and
  `greenland` (`IsContinentListedInDiplomacy`, rva `0x86DB0`), its text the continent's slot 6 text,
  named `cont_button_<index>`; placed from `continent_offset` (57,133) in steps of `continent_start`
  (100,0), wrapping where x reaches `continent_end`.x (356) to x = 57 and y + `continent_end`.y (20) - so
  the file's two names are the wrong way round, as its own `#position!`/`#offset!` comments warn. In
  Their Finest Hour's order: Europe, Asia, Africa on the first row; North America, South America,
  Oceania on the second (that the map's list keeps the file's order is inferred). A click lists **every
  country whose capital is on the continent** and owns a province (`ListContinent`, `0x78D960`).

### D.3 The sort buttons

**One direction flag serves all nine**, view `+0x4D8`, zeroed only by the constructor; **each press
flips it and then sorts**:

| button | key | flag 1 (a first press) | flag 0 |
| --- | --- | --- | --- |
| `sortby_name_button` (`DIP_NAME_TITLE` "Name") | the name, unsigned bytes | Z to A | A to Z |
| `sortby_threat_button` (`DIP_THREAT_TITLE` "Threat") | the threat the player feels from the country - the row's figure (`CompareThreatToCountry`, rva `0x21C8F0`) | highest first | lowest first |
| `sortby_energy` / `metal` / `raremet` / `oil` / `supplies` / `fuel` / `money_button` (goods 5, 4, 6, 3, 0, 1, 2) | the country's day's balance of the good (the `GetDailyBalance` ledger; supplies and fuel without `convoyed_in`) | the largest surplus first | the largest deficit first |

So the flag being shared, presses alternate across buttons: Name and then Threat gives Threat lowest
first. **A sort only makes the list box's rows again**: the country list keeps its order, so the next
tab, faction or continent, or a country dropping out, undoes it; and it does not remake the markers.
The seven resource buttons are hidden in a custom game.

### D.4 A row: `diplomatic_country_entry` (`CCountrylistItem`, `0xC0` bytes)

| element | what | when | tooltip |
| --- | --- | --- | --- |
| `country_button` (a checkbox, `GFX_big_listbutton_1`) | nothing at first - **no row starts ticked, the selected country's neither**; a click ticks it and selects the country; slot 7 (`SetSelected`, `0x7862D0`) unticks it unless the checkbox's `+0xD8` is set and `+0x136` clear (inferred, those bytes not read) | made, clicked | none |
| `country_icon` (a button, `GFX_minishield`) | the country's flag (slot 53); **a click does what the checkbox does** | made | none |
| `name` | `CountryNameOfTag(country)`, plain | made, only | none |
| `threat` | `FormatFixedPoint(player.diplomacy[country]->threat, 1)` - **what the played country feels from this one**, one decimal, cut, no sign or colour | **made, only** | none |
| `icon_energy`, `icon_metal`, `icon_raremet`, `icon_oil`, `icon_supplies`, `icon_fuel`, `icon_money` | **no number, only the icon**, tinted by the country's day's balance b of the good: **b > 0 (1.0, 1.0, 1.0, 1.0); b <= 0 (1.0, 0.5, 0.5, 1.0), a light red**, through the drawable's slot 68 (the four floats RGBA, inferred); hidden in a custom game | made, shown, and every frame while visible | yes |

**The icons' tooltip** (`CCountrylistItem::BuildTradeSurplusTooltip`, rva `0x386690` - a method of the
row, the hovered icon its argument; the record had it as a free `__stdcall`), `text` only: b < 0,
`DIP_NO_SURPLUS` "$NAME$ is in deficit of §Y$VAL$§W $RES$ each day." with VAL = -b; b >= 0, `DIP_SURPLUS`
"$NAME$ is producing a surplus of §Y$VAL$§W $RES$ each day." with VAL = b. NAME is the country's name,
RES `ENERGY_IRO` "Energy", `METAL_IRO` "Metal", `RAREMAT_IRO` "Rare Materials", `CRUDE_OIL_IRO` "Crude
Oil", `SUPPLIES_IRO` "Supplies", `FUEL_IRO` "Fuel", `MONEY_IRO` "Money"; VAL goes int -> float -> / 1000
(double) -> float -> `sprintf("%.2f")` - two decimals, rounded, never negative.

**Nothing else in the list has a tooltip**: `CDiplomacyView::BuildTooltip` (slot 10, `0x77F490`) asks a
row only `IsResourceIcon`, so the seven icons answer (the control); nothing in it answers a row's
checkbox, flag, name or threat, or a tab, sort or toggle button, and the file gives all of them empty
tooltips.

### D.5 Choosing a country

`SelectCountry` (`0x784A30`) runs from a row's checkbox or flag, a triangle marker, a faction member's
button (not REB, not id 0), a drift row (`0x77CD9A`) and, on Show, the selected province's owner. It
sets `+0x1DC/+0x1E0`, brings the country's marker to the front, empties and fills the drift list, runs
`FillCountryInfoHeader` and `RefreshCountryInfo`, makes the action list again and **puts the panel back
to Info** - the relation and goal windows hidden, `diplostatus_list` shown. **It does not touch the
country list.**

### D.6 The three toggles

`toggle_diploview_button_country` hides `relation_list_window` and `goal_list_window` and hides and
shows `diplostatus_list` again; `toggle_diploview_button_relation` hides all three, empties
`domestictext_relationlist`, fills it with `FillRelationListByRelation(view, 0)` and shows
`relation_list_window`; `toggle_diploview_button_goals` hides all three and runs
`FillGoalLists(view, goal_list_window)`. None changes a button's state. `info_label`, `relation_label`,
`wargoals_label` and `headline_diplo` are never looked up (no such string is in the image, where
`alignment` is, with references), so the file's texts stand: `DIPLO_INFO` "Info", `DIPLO_RELATIONS`
"Relations", `DIPLO_WARGOALS` "Wargoals", `headline_diplo` "DIPLOMACY".

### D.7 The mode arrows and `automation_setting`

The base `CCountryView`'s: `mode_arrow_left` calls slot 12 (the setting + 1, wrapping past 1 to 0) and
`mode_arrow_right` slot 13 (- 1, wrapping below 0 to 1) - with two values both just toggle. Each then
refreshes `automation_setting` (`OPT_NORMAL` "Normal" / `OPT_AICONTROL` "Ai Control"), calls
`CEU3AI::ApplyPlayerDelegation` and opens the view again. In the diplomacy view **Ai Control greys only
`decisions_listbox` and `diploaction_list`** (slot 14, `0x78E060`, in place of the base's whole window);
the country list stays usable.

### D.8 Later work, named only

`diploaction_list` is filled by `RebuildActionList` (`0x78C130`) from `0x4E3FE0` (not read), hidden in a
custom game. The triangle: the window `alignment` holds the tabs and the markers `<TAG>_aligner`
(`AddAlignmentMarker`), one a listed country and one for the selected country, made again every
`ALIGNMENT_INTERVAL` x 24 hours. The faction boxes: `faction_box_window` and `faction_member_entry`
(`UpdateFactionBoxes`).

### D.9 What looks wrong and is what the bytes do

1. A row's threat, name and flag are set once and never refreshed - not by Update, by
   `RefreshDiplomacyView` or by Show; only a tab, a sort or a country dropping out makes rows.
2. One direction flag serves all nine sort buttons.
3. A sort leaves the stored list as it was, and the next remaking undoes it.
4. Neighbours are the player's, not the selected country's.
5. "Selected" lists the selected country alone, and does not follow a later choice until pressed again.
6. At a balance of exactly 0 the icon is red and its tooltip says "producing a surplus of 0.00".
7. The resource figures are only in tooltips; a row's one number is its threat.
8. No row starts ticked.
9. Majors takes any country whose provinces come to more than 100 IC.
10. A Rebuild leaves the list box empty until a button is pressed (inferred).
11. The left arrow is "next" and the right "previous".
12. The continent buttons' two position names are swapped in the file.

### D.10 Not established

Who calls slot 0; what `+0xB4` (slot 15) is; a checkbox's `+0xD8` and `+0x136`; `RefreshDiplomacyView`'s
flag and what lies behind its callers (`0x4E39C0`); what a faction's and a continent's slot 6 text is
exactly (the localised name, inferred); whether Update runs every frame (read down to
`CInGameIdler::Update`); the selected unit copied at `+0x4DC`, for the actions; the custom game's
`0x78E3D0`, `0x78EC90`, `0x78F120` and `0x77C180`.

## The panel half

### E.1 Who fills it, and when

- **`CDiplomacyView::FillCountryInfoHeader`** (`0x784E30`; the record had it as BiceLib's guess
  `PopulateCountryInfoPanel`, likely) - the flag, the name, the relation and the surrender bar - runs
  in Rebuild (slot 0), in the function that selects a country (`0x784A30`) and at `0x78DDAB`.
- **`CDiplomacyView::RefreshCountryInfo`** (`0x788F70`) - the rest - runs in Show (slot 2), in the
  select, from `0x6783CA`, `0x78DDB1` and `0x78F677`, **and in Update (slot 6) on every frame on which
  the view's `+0x504` differs from the player's own most-threatened value**.
- **Update (slot 6), every frame**, also sets the surrender bar again and calls `RefreshDriftList`.
- **The relation and goal lists** are filled only by their buttons: `toggle_diploview_button_relation`
  -> `0x788610` -> `FillRelationListByRelation(view, 0)`; `toggle_diploview_button_goals` -> `0x788870`
  -> `FillGoalLists`; `sortby_nation_button` -> `OnSortByNation`; `sortby_relation_button` ->
  `OnSortByRelation`. The constructor (`0x77D090`) keeps their handlers at view `+0x1F0`, `+0x21C`,
  `+0x248`, `+0x274`, `+0x2A0` and slot 0 hangs them on the buttons. `RefreshCountryInfo` ends by
  keeping whichever view is up and does not refill those lists; choosing another country goes back to
  the info view.

### E.2 `country_info`, label by label

| element | what | from |
| --- | --- | --- |
| `country_flag` | the selected country's flag | icon slot 53 |
| `faction_symbol_icon` | hidden where the selected country's faction (`+0xD8`) is null or the no-faction singleton (slot 7 false), or where it is leaving one (a custom game's, always false otherwise); else frame = `CFaction +0x3C`: 1 comintern, 2 axis, 3 allies (`GFX_icon_factions_small`) | |
| `label_nation` | `CountryNameOfTag(selected)` | |
| `ruler_label` | **nothing**: no code names it (the string is not in the image, where `ruler_value` and `label_relation_value` are), so it keeps the file's `""`; `DIP_PARTY` "Ruling party:" is not referenced either | |
| `ruler_value` | the ruling ideology (`+0x1140`) by `GetNameForCountry` - `<ideology>_<TAG>` where that exists, else the ideology's name; no null test | |
| `label_relation_value` | `itoa(selected->+0xE28[player]->relation / 1000)`: whole, truncated, no sign, no colour; for the player's own country its self-pair, 85 at the start | |
| `label_threat_us_value` ("Our threat to them") | `FFP(selected->+0xE28[player]->threat, 2)`: **what the selected country feels from the player** | |
| `label_threat_them_value` ("Their threat to us") | `FFP(player->+0xE28[selected]->threat, 2)`: what the player feels from the selected country | |
| `label_neutrality_value` | `FFP(selected +0xA90, 0) + "%"` - **effective** neutrality; the base (`+0xA8C`) is shown nowhere on the panel (its only reads in `0x77A000`-`0x790000` are `0x78E4FA` and `0x78F297`) | |
| `label_our_neutrality_value` | the player's own country: `FFP(player +0xA90, 0) + "%"`; else colour + `FFP(player +0xA90, 0)` + `"%§W/"` + `FFP(max, 0)` + `"%"`, max = `player->GetMaxNeutralityForWarWith(selected)` (`0x505D00`), §R where the effective neutrality is above it (war cannot be declared), else §G - "§R80%§W/45%" | |
| `label_highest_threat_value` | `FFP(selected->+0xE28[selected +0x11DC]->threat, 1)` - how threatened the selected country is by its most-threatening country; kept at view `+0x504` | |
| `highest_threat_flag` | the flag of `selected +0x11DC` | |
| `surrender_progress` | a progress bar, green then red: fill = `(100000 - progress x 100) / 1000` = 100 - ceil(progress / 10), progress = `CCountry::GetSurrenderProgress`, 0 to 1000 - **green is what is left, red the progress** | |
| `automation_setting` | `CCountryView::UpdateAutomationLine`, recorded: `OPT_NORMAL` / `OPT_AICONTROL` | |

The labels no code touches keep their keys: `label_relation` `DIP_CURRENT_RELATION` "Current
relations:", `label_threat_us` `DIP_THREAT_US` "Our threat to them:", `label_threat_them`
`DIP_THREAT_THEM` "Their threat to us:", `label_neutrality` `DIP_NEUTRALITY` "Their Neutrality:",
`label_our_neutrality` `DIP_OUR_NEUTRALITY` "Our Neutrality:", `label_highest_threat`
`DIP_HIGHEST_THREAT` "Highest Threat :", `headline_diplo` "DIPLOMACY".

### E.3 `diplostatus_list` (rows `diplo_status_entry`, text `text`)

The text is `CCountry::BuildDiplomaticStatusText(selected)` (rva `0xEACD0`) over
`CCountry::GetDiplomaticStatusLines` (rva `0xEADD0`) - in a custom game only, `LEAVE_FACTION_INTENTION`
or `JOIN_FACTION_INTENTION` and a newline first - wrapped with the `text` box's font at its width and
cut at the newlines, **one row a line**, each a plain `0x28`-byte item sized 180 by the line's height.
**The lines alternate §W, §Y, §W ..., from §W**; a wrapped piece with no § takes the colour of the last
line that had one - §Y if it held §Y, else §W. The scroll position is kept before the list is emptied
and put back only where the selected id is the one of the last fill (a static, `0x1BEBDD0`). **Only
countries owning a province count**, but for the lend-lease and mission lines.

Lists are "A, B and C" (`AND` "and "), by `FormatCountryNameList` (rva `0xEA2E0`). The lines, in order:

1. `ATWARWITH` "At war with $LIST$." - **one line a war** (`T+0x20`, each distinct): the side of the war
   the selected country is not on (`CWar +0x2C` or `+0x3C`); a country is marked '*' after its name
   where it stands **first** on the enemy side of any of the selected country's wars.
2. `TRUCEWITH` "Truce with $LIST$." - `CDiplomacyStatus::HasTruce(T)`.
3. `FACTION_MEMBER_OF` "$NAME$ is a $FACTION$ member." - where the faction is real.
4. `INFLUENCEFROM` "Influenced by $LIST$" - `T+0x2C`.
5. `ALIGNINGTOWARDS` "Aligning towards $LIST$" - `T+0x30`, **written as each country's faction's name**
   ("Aligning towards Axis").
6. `NAPWITH` "Non-Aggression Pact with $LIST$" - `T+0x28`.
7. `ALLIEDWITH` "Allied with $LIST$." - `T+0x14`.
8. `LEADVASSAL` "Has the following puppets: $LIST$." - `T+0x18` a `CVassal` (slot 7 = `0x298`;
   `CDependency`'s own is `_purecall`) whose second is c.
9. `AMVASSAL` "Is a puppet of $LIST$." - the same with first = c.
10. `GUARANTEED` "Independence guaranteed by $LIST$." - `T+0x1C`, first = c.
11. `GUARANTING` "Guaranteeing the Independence of $LIST$." - `T+0x1C`, first not c.
12. `CD_ISEMBARGOED` "Embargoed by $LIST$." - `T+0x34`, first not the selected country.
13. `CD_ISEMBARGOING` "Embargoing $LIST$." - the same, first the selected country.
14. `CD_GIVESACCESS` "Grants military access to $LIST$." - `S+0x4C`.
15. `CD_HASACCESS` "Has military access through $LIST$." - `T+0x4C`.
16. `CD_DEBT` "Allows debts from $LIST$" - `S+0x78`.
17. `LEND_LEASE_TO_LIST` "Giving Lend-lease to $COUNTRIES$" (`tfh_4_0.csv`) - the tags of `+0x6B8`'s
    16-byte entries (the layout inferred).
18. `LEND_LEASE_FROM_LIST` "Receiving Lend-lease from $COUNTRIES$" - `+0x6C8`'s 12-byte entries.
19. Where `+0xE40` is set and its slot 6 true: the text of `ON_MISSION` + "'" + the mission's title +
    "'" - **`ON_MISSION` is in no localisation file**, so it shows as the key.

### E.4 `relation_list_window` (`domestictext_relationlist`, rows `domesticpanel_relation_entry`, `CRelationEntry`)

- **Who**: every country owning a province but the selected one, with the selected country's relation
  to it, `v = (int)(relation / 1000.0)`, truncated.
- **`name`**: `"@" + tag + CountryNameOfCountry(c)` - the flag, and no space before the name.
- **`value`**: `itoa(v)`, coloured by f = (v + 200) / 400 as (r, g, b) = (1 - f, f, |0.5 - f|), alpha 1:
  (1, 0, 0.5) at -200, (0.5, 0.5, 0) at 0, (0, 1, 0.5) at +200.
- **Sorting** (`CountrySortList_Insert`, rva `0x22E7F0`, a sorted insert walking back from the tail,
  and `CountrySortList_Before`, rva `0x21C990`; equals keep their order of insertion; names compared
  as unsigned bytes, case and all): by relation on `+0x318`, which the constructor sets to 1, best
  first - the tab button sorts without flipping it, `sortby_relation_button` flips it and then sorts,
  so its first press gives worst first; by name on `+0x319`, set to 0 - `sortby_nation_button` **flips
  first and then sorts**, so its first press gives Z to A.
- **Tooltip**: `RELATION_CHANGE_VALUE` "Estimated yearly change:" + " " + §G, or §R where negative, +
  `sprintf("%.2f", MonthlyRelationDrift(selected, c) / 1000 x 12)` + §W - the month's drift of
  `FINDINGS-diplostate.md` A.5 and C. The delayed half is `0x4E74D0`, not read.

### E.5 `goal_list_window` (`goals_by_us`, `goals_at_us`; rows `goal_overview_entry`)

Empty unless the selected country is at war (`+0xACC`). The wars are every distinct `CWar` among its
statuses towards the countries on its `enemies` list (`+0x1008`). **`goals_by_us`**: the goals filed
under the selected country in each war's `war_goals_by_actor` (`+0x9C`), each with the goal's
recipient's flag; **`goals_at_us`**: every goal in those wars whose recipient is the selected country,
with its actor's flag. A goal is shown only where its casus belli is not null and the casus belli's
slot 7 is true. `wargoal_icon`'s frame is the casus belli type's `+0xC`, probably `sprite_index`
against `GFX_diplo_wargoal_icons`' 7 frames (inferred). The row is `_A0x55a8222a::CGoalOverviewEntry`,
not `CGoalEntry`, which is the war-goal dialog's. `our_label` `OUR_GOALS` "War Goals:", `their_label`
`GOALS_VS_US` "Targeted by:". **Tooltip**: the casus belli's name ("Retake our cores"), delayed
`<cb>_setup` with `$ACTOR$` and `$RECIPIENT$` as "§Y" + name + "§W".

### E.6 `drift_label` and `drift_list` (rows `drift_entry`)

`drift_label` is static, the key "Influences" ("Influences", `gold.csv`). **The list is of influence
and alignment**: a country c has a row marked outgoing where its status towards the selected country
holds an influence (`+0x2C`) or align (`+0x30`) pointer - `+0x2C` sitting on the influenced side, so
the selected country influences c - and otherwise a row marked incoming where the selected country's
status towards c holds one. A country may have two rows, one for each, and the rows do not say which.
**`name`**: `"@TAG " + name`. **`influence`**: with M the static modifier the faction's `influence` key
names (`align_towards_axis`) - the selected country's faction where outgoing, c's otherwise - "--"
where the other country does not have M; outgoing, "§G+" + `FFP(M's ALIGN_TOWARDS, 2)`; incoming, the
faction's name. A click on a row's `bg_button` selects its country (`CDriftItem::OnClicked`).

### E.7 Tooltips (`CDiplomacyView` slot 10, the panel's branches)

- **`highest_threat_flag`, `label_highest_threat_value`, `label_highest_threat`**:
  `DIP_HIGHEST_THREAT_TOOLTIP` "The highest perceived threat in their region is §Y$COUNTRY$§W. Their
  threat value to us is §Y$VAL$§W", `$COUNTRY$` the name of `selected +0x11D8`, `$VAL$` = `FFP(+0x504,
  1)`; delayed `DIP_HIGHEST_THREAT_TOOLTIP_DELAYED`.
- **`surrender_progress`**: `SURRENDER_TITLE` "Surrender Progress: §Y$VAL$%§W", `$VAL$` =
  `sprintf("%.2f", progress / 1000 x 100)`; delayed `SURRENDER_DETAILS` for the player or
  `SURRENDER_DETAILS_THEY`, `$OCCUPATION$` = `FFP(occupied victory-point share x 100, 1)` and `$UNITY$` =
  `FFP(national unity, 1)` - or, for a government in exile, `WE_ARE_GOV_EXILE` for the player, else
  the name + " " + `IS_IN_EXILE`.
- **`label_neutrality_value`**: the sources of `MODIFIER_NEUTRALITY_CHANGE` (78) in the selected
  country's modifier, `DescribeContributors(78, 1000)`.
- **`label_our_neutrality_value`**: for the player's own country, the same of the player; otherwise
  `BuildWarNeutralityTooltip` (rva `0x105F20`, `FINDINGS-diplostate.md` C) - `WARNE_THREAT` "Mutual
  Threat is §Y$VAL$§W." with the larger of the two directions' threat, `WARNE_CLAIMS` "Territorial
  Claims: §G+$VAL$§W.", `WARNE_CONTINENT` "Different Continent: §R-$VAL$§W.", `WARNE_FACTION` "Member of
  $NAME$ : $VAL$§W." - with the player's neutrality sources delayed.
- **None** for `country_flag`, `faction_symbol_icon`, `label_nation`, `ruler_value`,
  `label_relation_value`, the two threats, the status rows and the drift rows.

### E.8 What looks wrong and is what the bytes do

1. Update refills the whole info view, status list and all, on every frame on which the selected
   country's most-threatened value differs from **the player's own** - for most countries every frame;
   that is why the scroll position is put back.
2. `drift_list` is rebuilt only when a count changes - but a pair influencing both ways counts 2 and
   gets 1 row, so the count never matches and it is rebuilt every frame.
3. The first press of `sortby_nation_button` sorts Z to A.
4. `ruler_label` is never filled; `DIP_PARTY` is unused.
5. `DIP_HIGHEST_THREAT_TOOLTIP` says "Their threat value to us", and `$VAL$` is how threatened the
   selected country is by its worst threat, not a threat towards the player.
6. `ruler_value` reads the ruling ideology with no null test.
7. Every `$LIST$` is itself put through `GetText` before it is put in, so a list that matched a key
   would be replaced.
8. `ON_MISSION` has no text anywhere, so the line shows "ON_MISSION'...'".
9. `ALIGNINGTOWARDS` lists factions, not countries.
10. `ActiveMission_GetTitle` (rva `0x5C7550`) treats `CCountry +0xE38` as an object held in place, where
    the record types it a pointer.

### E.9 Not read

`0x4E74D0`, the relation change's breakdown; the custom-game helpers `0x41D470`, `0x41F300`,
`0x421660`, `0x420780`; window `+0x5B` read as "visible", a list's slots 20, 21 and 23 as show, hide
and empty, and the overlapping box's slot 48 as empty - from use, not from the bodies;
`CCasusBelliType +0xC` as `sprite_index` (the loader's case not traced); `+0x6B8`'s entry layout.
`0x78C130` fills `diploaction_list` with `CDiplomaticActionItem`s from `0x4E3FE0(player, ...)` - the
actions, later work.
