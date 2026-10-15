# The next wave

**This file holds one thing: the wave that is planned but has not run.** It exists because the plan
used to live in `CANDIDATES.md`, which is five hundred lines of queue and archive, and finding the
plan in it was a search rather than a glance.

The contract, so the two files do not drift:

| | |
| --- | --- |
| **`WAVE.md`** (this file) | the plan for the wave that has **not launched**. Overwritten by the next plan |
| `CANDIDATES.md` | the standing queue and the archive. **A wave's result goes there**, not here, along with the area-level backlog a plan is chosen from |

So: plan here -> launch -> write the result into `CANDIDATES.md` -> replace this file with the next
plan. If this file describes a wave that has already landed, it is stale and `CANDIDATES.md` is the
truth.

---

## The province-view wave - the window a selected province opens

> **LANDED 2026-10-15.** Three briefs, merged (56 address entries landed and 3 revised; 4 structs declared, 37 fields;
> apply 208 `failed: 0`, `struct fields: 0`); the write-up is `findings/FINDINGS-provinceview.md` sections A, B and C,
> indexed in `CANDIDATES.md`, where seven things it left are queued.

Planned 2026-10-15, for OpenHOI3, on the maintainer's word that day: the province view is the first of six pieces in
his order ("3 - 2 - 1 - 5 - 4 - 6": the province view, convoys in the build queue, weather, transport and invasion,
the headless run, the AI). OpenHOI3 has no province view: a selected province shows a scaffolding readout under the
top bar, forts and infrastructure cannot be ordered, and an underground's mission cannot be set. Three briefs; the
write-up is **a new `findings/FINDINGS-provinceview.md`**, sections A, B and C.

**Scope.** `province_interface.gui` (Their Finest Hour's copy in `tfh/interface`): the window `province_view` with its
sub-windows `underground` and `cov_ops`, its list boxes `adj`, `buildings_left` and `buildings_right`, the box
`claims`, the box `allied_cooperation`, and the entry windows `building_member`, `adj_member`, `prov_claims_entry`,
`allied_coop_item` and `cov_ops_mission_entry`. The class is `CProvinceView` (RTTI; its code lies around rva
`0x2DB000`-`0x2EB000`). **What the window shows of the weather is read even though OpenHOI3 has no weather yet** - weather
is the third piece, and the view is where the player sees it.

**What is known and is not to be redone** (cite it; re-read on the listing only to raise an `inferred` record or
correct it): `FINDINGS-occupation.md` B.6 (`text_partisans` and its tooltip `BuildProvinceRevoltRiskTooltip`, the
refresh at `0x6DE5F0` read for that figure only) and E.7 (the `underground` window: its elements, the two spawn
buttons, `underground_mission` and its command, their tooltips; the gate `0x6EA920` not read to its end, which mouse
button steps the mission which way not read); `FINDINGS-buildingqueue.md` section A.2 (`CBuildingMember::OnClick`,
one level a click for every selected province) and `CCountry::IsBuildingAllowed`; `FINDINGS-uinumbers.md`
(`BuildProvinceViewTooltip`, rva `0x2E4250`, its 52-key number block); `FINDINGS-espionage.md` B.7 (covert operations:
`common/covert_ops.txt`, `CCovertOpsMission`, `CCovertOpsMission_CanSelect`, `CSendCovertOpsMission`) and B.14 (the
frontier `0x2E1DB0`, `0x2E2C10`); `FINDINGS-provincetooltip.md` (the map's province tooltip, which shares much with
this view); `FINDINGS-espionage.md` C.2 (what a country knows of a province, which gates
what the view shows); `FINDINGS-gui.md`, `FINDINGS-guicontainers.md`, `FINDINGS-guilive.md` (element kinds, list
boxes, overlapping-element boxes).

| brief | what it settles | starting points |
| --- | --- | --- |
| **A. The window, opening and refresh** | **When the view opens and closes**: which click on the map selects a province and opens it (and with what selected or not - a unit, the deploy menu, a map mode), several provinces selected (shift, a drag box?) and what the view then shows, `close_button`, what closes it (another screen, Escape, a unit selected), and whether it follows the selection. **`CProvinceView`**: its constructor, vftable and slots, its fields; **the refresh (`0x6DE5F0`) whole and in order** - `text_title` (the name, and anything added), the `terrain` picture (which sprite frame for which terrain), `overlay`/`overlay2`, `owner_flag` and `occupier_flag` (and what a click on either does), the four resources' texts (`text_oil`, `text_metal`, `text_energy`, `text_raremat` - the province's yield, by what formula, rounding and format, shown only at which intelligence?), `strategic_resource` (which frame), `text_espionage` (which figure: the player's intelligence of the province?), `text_manpower`, `text_leadership`, `covert_ops_icon`/`cov_ops_points`/`open_cov_ops` (shown when; brief C reads the window it opens), **the `adj` list** (`adj_member`: which neighbours in which order, `adj_icon`'s frame - passable, a river, a strait, impassable? - and `adj_text`), **the `claims` box** (`prov_claims_entry`: whose flags - cores? claims? - in what order), and **the weather strip** (`day_night`, `weather_icon`'s frame, `temperature_txt`'s figure and format, `wind_icon`/`wind_status`'s bar, `ground_status_icon`'s frame - what province fields each reads). **Every element's tooltip** out of `BuildProvinceViewTooltip` (rva `0x2E4250`) - its number block is recorded; read which element answers with which keys and variables, main line and delayed half. Whether the view refreshes every frame or on an event | `0x6DE5F0` (VA), rva `0x2E4250`, rva `0x2E0370`, the CProvinceView RTTI, `FINDINGS-provincetooltip.md` |
| **B. Buildings and the underground** | **The building columns**: which buildings get a `building_member` and in which of `buildings_left` / `buildings_right` (by `onmap`? `show_for_province`? the file's order?), `CBuildingMember`'s constructor (`0x6DB560`) and **its update and enabling (`0x6DC380`) whole** - `building_icon`'s frame or sprite, the ten `plupp_N` pips (built level, working level, queued, max level - which colour or frame for each state), when the button is disabled and why, its tooltip (cost, time, what the building does, why it is disabled - every key with its variables), and what a right click does if anything (cancel a queued level?). **The `underground` window** to its end: the gate `0x6EA920` whole (when the sub-window shows, its `text_title`, `owner_flag`/`occupier_flag` there if they are its own, `supression_icon` and `text_supression`'s figure and format), **which mouse button steps `underground_mission` which way** (`0x6EA380`, `0x6EA490`), and anything E.7 left | VA `0x6DB560`, `0x6DC380`, `0x6EA920`, `0x6EA380`, `0x6EA490`; rva `0x2DBE40`, `0x2E1590`, `0x2EA5A0` |
| **C. Covert operations and allied cooperation** | **The `cov_ops` window**: what opens it (`open_cov_ops`) and closes it, `cov_ops_label`, `cov_ops_list`'s entries (`cov_ops_mission_entry`) - **which missions in which order** (`common/covert_ops.txt`'s order? filtered by `is_valid`?), `selectbutton`'s text (the mission's name? with its cost?), its enabling (`CCovertOpsMission_CanSelect`, recorded) and its tooltip (cost, effect, why not) - from the entry builder `0x2E1DB0` and the select callback `0x2E2C10`; `cov_ops_points`' figure and format. **The `allied_cooperation` box**: `set_cooperation`, `coop_label`, `cooperation_list` with `allied_coop_item` (`objective` checkbox, `flag`, `country_name`) - **what it is**: which allies are listed, what ticking `objective` posts (a command? an AI objective for an ally?), when the box shows, and what it does in the simulation if anything; its tooltips | rva `0x2E1DB0`, `0x2E2C10`, `0x444C60` (recorded), `CSendCovertOpsMission` (recorded), `FINDINGS-espionage.md` B.7 |
