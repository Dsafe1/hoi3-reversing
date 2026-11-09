# The sixteen alerts

*Read 2026-11-09, on a throwaway copy of `Hoi3_v12.1.2` with `DecompileAt.java` and the listing of `scripts/disasm.py`. Everything marked **listing** was read off instructions; the rest off the decompiled C. Addresses are VAs; subtract 0x400000 for an rva. Texts are Windows-1252. "Hard-coded" means a constant in the executable; "defines" means a key of `common/defines.lua`, mod-able.*

**In one line.** Every three real seconds a single function tests the sixteen alerts one after another for the played country. It puts up or takes down each alert's icon in a row under the top bar in the order the alerts came up, playing the `message` sound each time an icon appears.

## 1. The pass: gates, clock, order

`CAlertManager_Update` (`0x601DE0`) is called every frame from `CInGameIdler_UpdateOpenView` (`0x651D30`), but **not when the custom-game flag is set** (`GetCustomGameSettings`' first byte, `0x41C4E0`). So in a custom game there are no alerts at all. It runs while paused, and it runs whatever country view is open. Hard-coded: 3.0, the 0x88 record size, the list caps below.

**Every frame**, before any gate, every alert that has a window and whose window byte `+0x5B` is set gets slot 11 (raise), so icons stay on top.

**The gate on the rest:** nothing further happens while `clock seconds < manager +0x8A0`, or while manager byte `+0` is set. Otherwise `+0x8A0 = clock + 3.0`, so the tests run at most every **3.0 real seconds** of the platform clock (`g_PlatformClock` at `0x1A857E4`, a `CHighPerfWinClock`, slot 5 seconds, cached in manager `+0xA0C`). `+0x8A0` starts at 0, so the first pass is the first frame.

Manager byte `+0` never does anything: the only writes in the image are the constructor's 0 and `CInGameIdler::OpenCountryView` setting it to 0 (`0x665967`, after the custom-game test). All nine `.text` hits of displacement `0x1D28` were searched, which is every path to the manager. The same search finds the known readers (`+0x2C` windows, `+0x24` positions), so it is a positive control.

**The scenario gate:** `noScenario = gamestate->scenario (+0xD0C) == 0`. When a scenario is set, the flag is forced false for alerts 0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 12 and 13 (alert 10's whole test sits inside `if (scenario == null)`). **Alerts 11, 14 and 15 are not gated** (the twelve reads of `[esp+0xF]` in the listing cover only the others). A scenario does not bring up alert 3 either, which nothing shows.

The played country is `gamestate->player` read at the top of the pass; the numbers the tests use are its own.

**Order of tests (hard-coded by the code's order):** 0 NAP, 1 deployable units, 2 troops in foreign territory, 3 revolt risk (built, hidden, never shown, section 3), 4 invite to faction, 5 resource panic, 6 possible law, 7 free tech slots, 8 wasted IC, 9 tech far ahead, 10 lack of troops, 11 bad supply, 13 mobilised in peace, 15 allied objectives, 14 victory conditions, 12 national decisions. Within one pass, alerts newly true come up in this order.

**Showing** (`CAlertManager_Show`, `0x607FE0`; called with the manager in EDI and the number pushed): if the flag is true and the alert has no window, an `alerticon_window` is made. `alerticon` gets frame `number + 1`, `alerticon_banner` frame 0, and the window is placed at manager `+8`/`+0xC` (`next_x`, `row_y`). Then `next_x += step_x`, the `message` sound plays, and the record's first dword gets clock + 30.0 (read by nothing). Alert 4 then fills its tooltip through `CAlertManager_SetInviteTooltip`, and 2, 3 and 12 through `CAlertManager_SetTooltipList` from the scratch text. The window's `alert_scope` is what routes its tooltip (`CInGameIdler::GetElementTooltip` at `0x6C6035`, comparing an element's `+8` to `alert_scope`).

**Hiding** (`CAlertManager_Hide`, `0x608730`, number in EAX): the window is destroyed, the record's window zeroed, every other alert whose x is greater than this one's moves left by `step_x` and is placed again, and `next_x -= step_x`. So **the row closes up**, in arrival order; an alert that returns goes on the end with a new window and the sound.

**The row:** `first_x = next_x = alerticon_startposition.x`, plus `alerticon_mp_offset.x` in a multiplayer game (`CInGameIdler +0x68`). `row_y = alerticon_startposition.y`. `step_x = alerticon_offset.x`, read as x only. In `interface/alerts.gui`: start (-60, 63), offset 35, mp offset 35. Mod-able, by the `.gui`. The `_mp_offset` key shifts the row once, not per icon.

**Banner and blink:** none live. `alerticon_banner` is declared at x=5000 in the file with the comment `#remove!`, set once to frame 0, and never updated. Show writes `banner_until = clock + 30.0` and nothing reads it (same nine-site search, with the same control). No code toggles the frame or the visibility of an icon after it is up.

**Tooltip text generally:** at registration (`CAlertManager_Register`, `0x601B70`) each alert's `<name>_instant` and `<name>_delayed` are rendered once into the record (`text` and `delayed` of a `GuiTooltipText`). The delayed half of alerts with a list is rewritten each time its list changes (section 3). Alerts 14 and 15 are special-cased in `CAlertManager_IconTooltip` (`0x606EE0`); every other copies its record.

## 2. Automation

Each tested from `CGameState::GetLocalPlayer` (the local human's `CHuman`):

- Alert 5, goods 0 (supplies) and 2 (money) only: skipped while `automate_sliders != 0` or `automation[1] == 1`. Other goods are still tested.
- Alert 6: skipped while `automation[3] == 1`.
- Alert 7: skipped while `automation[2] == 1`.
- Alert 8: skipped while `automation[1] == 1` or `automate_sliders != 0`.
- Alert 9: skipped while `automation[2] == 1`.

The automation of `automation[2]` is the flag, not the four-way `automate_tech_sliders`, as `FINDINGS-frontend.md` says. No other alert asks automation.

## 3. The sixteen

Below, `C` is the played country, `now` is `gamestate->tick`. Where a flag is **up** it is shown when it has no window; when false and it has a window it is hidden.

**Alert 0 `alert_nap_expiry`.** *Up* when no scenario, `NAP_EXPIRY_ALERT_MONTHS_AHEAD` (defines, `diplomacy +0xF8`) is above 0, and a pass over `C`'s diplomacy vector by country id finds a NAP (`status->nap`, `+0x28`) with `AddMonths(start_date, NAP_UNBREAKABLE_MONTHS - NAP_EXPIRY_ALERT_MONTHS_AHEAD) < now` (strict). `NAP_UNBREAKABLE_MONTHS` is `+0xE4`, defines, /1000. The list is rebuilt each pass (`+0x9D0`); the alert goes when no such NAP exists, so when the NAP ends.

*Tooltip:* `_instant` `§YNon-Aggression Pact status.§W`. The delayed text is rebuilt into the record each pass: `alert_nap_expiry_delayed` ("Non-Aggression Pact with:"), then per NAP in vector order, `\n - ` + one of:

- `_delayed_list_A` when `now < start + NAP_UNBREAKABLE_MONTHS`: `§G$COUNTRY$§W may be broken on §Y$DATE$§W`, DATE = that date.
- `_delayed_list_B` when a window's date is still ahead and the balance is short: `§G$COUNTRY$§W could be broken now, but we don't have enough troops on their border. We need §Y$LIMIT_PERC$%§W of their brigades along our common borders, but we currently have §Y$CURR_PERC$%§W.`, and if it is not the last window, `\n` + `_delayed_list_E` `The required troops ratio will change after §Y$DATE$§W to §Y$LIMIT_PERC$%§W.`.
- `_delayed_list_C` otherwise: `§G$COUNTRY$§W may be broken now`.

Then always `\n` + `_delayed_list_D` `Completely expires §Y$DATE$§W.`, DATE = start + `NAP_EXPIRY_MONTHS` (`+0xE0`, defines).

COUNTRY is `@TAG` + ` ` + the country name, TAG being the other party's. The windows are `AddMonths(start + unbreakable, k * NAP_FORCE_BALANCE_RULE_MONTHS)` for k = 1, 2, 3 (`+0xE8`, defines). In window k the limit is `NAP_BREAK_FORCE_BALANCE_k` (`+0xEC..+0xF4`, defines, as `diplomacy[0x3B..0x3D]`). The balance is the NAP's `+0x24`, or 1,000,000/it when `C` is the second party (or -1 if zero). LIMIT_PERC and CURR_PERC are `(100000.5f floored = 100000)` times it, /1000, by `FormatFixedPointTrimmed`: "200". In the loop a window whose date is at or before now passes on, and a window whose balance is enough also passes on, reaching C. Date text: `Date_FormatYearMonthDay` (`%d %s %d`, year first).

*Click:* no arm (section 4).

**Alert 1 `alert_deployable_units`.** *Up* when no scenario and `C`'s `deployments_count > 0`.

*Tooltip:* `§YWe have units available to be deployed.§W`; delayed `$LIST$`. For the first **21** deployments of the country's list, the list is built in the scratch text:

- kind `unit_deployment` (slot 8 answers `0x4B4`): `£` + the first brigade's type key + ` ` + the deployment's name (slot 11) + `\n`.
- kind `building_deployment` (`0x4B7`): the name + `\n`.
- then `...\n` if more remain.

The re-render is when the sum of each listed deployment's `+0xC` differs from the last pass's (`+0xA14`). Hard-coded 21.

*Click:* side menu 5 (section 4).

**Alert 2 `alert_troops_in_foreign_territory`.** *Up* when no scenario and a walk of `C`'s units (`Units` list, not naval: slot 16 `IsNaval` false, so armies and air both) finds a unit in province `p` (`current_province_ptr`) whose controller `c` satisfies all of:

- `c.id != player`, `c.id != 0`
- not `CCountry::IsEnemy(C, c)`
- `Diplomacy[c.id]` has no alliance and no `hasMilitaryAccess`
- `c`'s faction is not a real faction, or is not `C`'s faction
- not vassal to or of `c` (`CDiplomacyStatus_IsVassalWithTargetSecond`/`First`)

Provinces are deduplicated by pointer in order of first finding (`+0x9E0`).

*Tooltip:* `§YYou have troops in foreign territory.§W`; delayed `In $LIST$.`; LIST is `FormatProvinceList`, "A, B and C". Re-rendered when the set of provinces changed (count or any element at its position differs), and on Show.

*Click:* no arm.

**Alert 3 `alert_revoltrisk_in_provinces`.** Built (`AlertPass_RevoltRiskList`) and **never shown**: no call of `CAlertManager_Show` pushes 3 (fifteen pushes, 0, 1, 2, 4..15). If up it is hidden; it never is. Text `§YPossible Partisans§W` / `The following provinces run a risk of having a partisan uprising.\n$LIST$`. Dead.

**Alert 4 `alert_can_invite_to_faction`.** *Up* when no scenario, `C` belongs to a real faction (`Faction` slot 7 true; `CNullFaction`'s answers false), `C` is the first member (leader) of it, and a walk of all countries finds any where:

- not `REB`, owns at least one province, and is not `C`
- not in a real faction
- `CAlignment::IsWithinFactionJoinDistance(country->Alignment, C's faction)` (FACTION_JOIN_DIST, defines)
- not at war with a member of `C`'s faction
- `EffectiveNeutrality <= INVITE_FACTION_NEUTRALITY` (`diplomacy +0x98`, defines; compared as thousandths)

The list of candidates (`+0x910`, country-database order) is rebuilt each pass.

*Tooltip:* `§YPossibility to invite to Faction§W`; delayed `You can invite $LIST$ to your faction.`; LIST `FormatCountryTagList`: `Name (@TAG)`, `, ` between while two or more remain, ` ` + AND before the last. Re-rendered at Show and when the count changed.

*Click:* OpenCountryView(0), diplomacy.

**Alert 5 `alert_resource_panic`.** *Up* when no scenario and any of the seven goods in order supplies, fuel, money, crude oil, metal, energy, rare materials is short. For goods index g (0-6): `stock` is the capital province's pool (`CCountry::GetActingCapitalLocation(C)->pool`, `pool +8 + g*4`), or `pool_in_exile` when `isGovernmentInExile`. `balance = CCountry::GetDailyBalance(C, g)`. If `balance < 0`, automation permitting (section 2): `days = stock * 1000 / (-balance)` (thousandths of days, integer division); short when `days < 30001` and `days > -1001` (hard-coded 30.000 and -1.000).

*Tooltip:* `§YResource stockpile almost empty§W`; delayed `$LIST$`; each short good appends `RES_OUT_IN_X_DAYS` `Stockpiles of §Y$NAME$§W will be empty within §R$DAYS$§W days.` with NAME = `GoodName(g)` and DAYS = `days/1000 + 1`, then `\n`. Re-rendered every pass while up (the "last count" static at `0x1BEA448` has no writer in the image; one reference, the compare).

*Click:* no arm.

**Alert 6 `alert_possible_law`.** *Up* when no scenario, `automation[3] != 1`, and for some law group (groups 1 to end of the law database's vector; group 0 is the null group) a law is enactable. The group's laws (`CLawGroup +0xC`, list order the reverse of `laws.txt`) are walked from the head: nothing is considered until the current law of the group (`C->laws[i]`) is reached; the first law after that in the walk whose `allow` evaluates true (scope country `C`) is offered, one per group. Since the walk runs reverse of the file, "after the current" means **earlier in the file**.

*Tooltip:* `§YMore efficient laws can be enacted!§W`; delayed `$LIST$`; each offered law: `POSSIBLE_LAW` `§Y$LAW$§W (§Y$MONEY$§W) can be enacted as $GROUP$.` LAW = `CLaw` slot 14 (name for country), GROUP = group's localised name, MONEY = `CCountry_GetLawChangeCost(law, C)` at 1 decimal, then `\n`. Re-rendered every pass (same dead static, `0x1BEA44C`).

*Click:* OpenCountryView(3), politics.

**Alert 7 `alert_free_tech_slots`.** *Up* when no scenario, `automation[2] != 1`, and `researchLeadership > activeResearch * 1000`, where `researchLeadership = (basePercentage * factor >> 15) * 1000 >> 15` (the research leadership distribution's effective share, truncated to thousandths) `* TotalLeadership / 1000`, and `activeResearch` is `CurrentResearch.count`. *Listing.* That is, research is receiving more than one point of leadership per research line.

*Tooltip:* `§YMore research possible.§W` / `We are not using our leadership optimally, and there is a possibility for more research to be done.` (static).

*Click:* OpenCountryView(2).

**Alert 8 `alert_wasted_ic`.** *Up* when no scenario, `automation[1] != 1`, `automate_sliders == 0`, and `GetAvailableIC(C) > 0` (that is, the summed spare IC from `GetSpareICIn` over the five production categories consumer..upgrade reaches 1.000 IC).

*Tooltip:* `§YIC wasted!§W`; delayed `$LIST$`; for categories in the table 1, 2, 3, 4, 5 where `GetSpareICIn > 0`: `POSSIBLE_WASTED` `We are wasting §R$IC$§W IC on §Y$NAME$§W.` with IC at 2 decimals and NAME the production distribution setting's name (slot 6), then `\n`. Re-rendered every pass (static `0x1BEA450` dead).

*Click:* OpenCountryView(1).

**Alert 9 `alert_tech_far_ahead`.** *Up* when no scenario, `automation[2] != 1`, and some technology in `CurrentResearch` has `GetYear(tech, level + 1) - currentYear > 1`, where `currentYear = (int)((now - 43800000) / 24 / 365.0)` (`GetYear` is `start_year`/`first_offset`/`additional_offset`).

*Tooltip:* `§YInefficient research§W`; delayed `$LIST$`; `TECH_AHEAD` `§Y$NAME$§W is §R$YEAR$§W years ahead in research.`, YEAR = the difference, NAME = tech name + ` §W(` + the tech's folder's name + `)`, then `\n`. Re-rendered every pass (static `0x1BEA454` dead).

*Click:* OpenCountryView(2).

**Alert 10 `alert_lack_of_troops`** (only when no scenario, by an outer `if`). For each unit of `C`'s `Units`: let `a` be the unit's own `ai_agent`, overridden walking up `higher_oob_unit_ptr` by any higher unit's non-null agent. Required: `a` non-null, the unit has a non-empty plan objective count (`+0x23C`), and **no unit above it has an agent at all** (so the unit is the top of the agent chain), has at least one brigade whose definition (`+0x58`) is set. Then with `need = their_power (+0x280) * mult / 1000`, where mult is 2000 at plan_stance 3 and 3000 at plan_stance 4, else 1000: up if `our_power (+0x27C) < need`. Hard-coded multipliers. Rows capped at 20 then `& ...`.

*Tooltip:* `§YLack of Troops§W`; delayed `$LIST$`; each row: `£` + first brigade's type key + ` ` + unit name (slot 7) + `=> ` + `CUnit_ObjectivesSummaryText` + `\n`; after 20, `& ...` once. Re-rendered every pass (static `0x1BEA458` dead).

*Click:* section 4.

**Alert 11 `alert_bad_supply`.** Not scenario-gated. *Up* if any unit of `Units` has `supply_received_percentage (+0xFC) < 1000` and at least one brigade (`regiments_count != 0`). Rows capped at 20 then `& ...`.

*Tooltip:* `§YUnits in poor supply§W`; delayed `$LIST$`; row: `£` type key + ` ` + unit name (slot 7) + ` (` + province name + `)` + `\n`. Hard-coded 1000, 20. Re-rendered every pass (static `0x1BEA45C` dead).

*Click:* section 4.

**Alert 13 `alert_mobilized_in_peace`.** *Up* when no scenario, not `isAtWar`, and `isMobilized`.

*Tooltip:* `§RCountry is mobilized in peacetime!§W` / `Mobilization is very costly.`.

*Click:* no arm.

**Alert 15 `alert_allied_objectives`.** Not scenario-gated. *Up* while `gamestate +0xB9C[player]` (0x14-byte records, the per-country allied objective list) is non-empty.

*Tooltip:* always built (`CAlertManager_AlliedObjectivesTooltip`, `0x6070D0`), `AO_ALERT` `§GAllied Objectives§W`, delayed per record in list order, records joined with `\n`:

- each requester `§Y<name>§W`, joined `, ` and before the last ` ` + AND + ` `;
- then `OL_AO_THEY_REQUEST` ` have requested that we`;
- then `OL_AO_DEFEND` ` §Gdefend§W near ` if the province's controller's faction is `C`'s, else `OL_AO_ATTACK` ` §Rattack§W near `;
- then `§Y<province>§W.`.

*Click:* no arm. The `alert_allied_objectives_*` keys are not in the tables and are never used (`AO_ALERT` is).

**Alert 14 `alert_victory_conditions`.** Not scenario-gated. *Up* while any faction of the game's list (`gamestate +0xCE4`) other than `C`'s has `VictoryConditions_CountMetForFaction * 100 / VICTORY_CONDITIONS_TO_WIN >= 75` (the `0x4A < ...` test; 75 is hard-coded, `VICTORY_CONDITIONS_TO_WIN` is defines, or the scenario's value; as `FINDINGS-factionplay.md`).

*Tooltip:* `CAlertManager_VictoryConditionsTooltip`: `VC_ALERT` `§GVictory Conditions§W`, delayed `VC_DANGER` for the *last* such faction in the list.

*Click:* OnAlertClicked's goals arm (section 4).

**Alert 12 `alert_national_decisions`** (tested last; as `FINDINGS-eventfire.md`). *Up* when no scenario and any **diplomatic** decision (the database's `diplomatic` vector, in file order) passes `potential` then `allow`, with scope country `C` and a copied scope as `this`.

*Tooltip:* `§YNational Decisions Available§W`; delayed `The following decisions are available:\n$LIST$`; each decision's localised title + `\n`. Filled at Show and when the list text's length changes (static `0x1BEA460`, this one *is* written, each pass).

*Click:* OpenCountryView(0).

## 4. Clicks (`CAlertManager::OnIconClicked`, `0x607ED0`, then `CInGameIdler::OnAlertClicked`, `0x64ACB0`, slot 80)

The handler does nothing unless the screen's slot 69 answers true (`0x678890`: no session object at `+0x1CD0`, or its `+0xF5`; true in any single-player game). Alerts are identified by the icon's frame less one.

Slot 80, every arm:

1. Always first: `CInGameIdler_CloseSideMenus`, `CloseOrdersView`; the browser's open flag (`+0x1360` window `+0xF4`) is noted. For `alert_deployable_units` only, the first selected object that is a unit (slot 1: 0, 1 or 2) is remembered.
2. The selection is cleared with `Selection_Clear` **except for `alert_bad_supply` and `alert_lack_of_troops`**.
3. By name:
   - `alert_deployable_units`: if a country view is open, `OpenCountryView(open_view)` closes it; `CInGameIdler_OpenSideMenu(5)` (deploy); the remembered unit is reselected if `Selection_CanAdd` allows; if the browser was open and is now closed, `vf_104` (slot 104) reopens it.
   - `alert_national_decisions`, `alert_can_invite_to_faction`: `OpenCountryView(0)`.
   - `alert_wasted_ic`: `OpenCountryView(1)`.
   - `alert_free_tech_slots`, `alert_tech_far_ahead`: `OpenCountryView(2)`.
   - `alert_possible_law`: `OpenCountryView(3)`.
   - `alert_lack_of_troops`: walks `C`'s `Units` starting from the unit after the first unit row's (`unit_rows[0]+0x28`) if the rows are not empty, wrapping once around (the count limits it). For each unit it applies alert 10's test from `+0x198` down to `their_power` (the agent, objectives, top-of-chain and power test, not the first-brigade test). The first that passes: `ClearSelection`, `Select`, `CentreOnProvince` (its `+0x130`).
   - `alert_bad_supply`: the same cycling walk, testing only `supply_received_percentage < 1000`. Same selection and centring.
   - `alert_victory_conditions`: `ToggleGoals` only if the goals window is hidden (`+0x5B` nought); so it opens and never closes.
   - No arm: `alert_nap_expiry`, `alert_troops_in_foreign_territory`, `alert_revoltrisk_in_provinces`, `alert_resource_panic`, `alert_mobilized_in_peace`, `alert_allied_objectives`. Step 1 and 2 only.

`OpenCountryView` is a toggle: a click on an alert whose view is already open closes it.

## 5. Slips and things that look wrong

- Alert 3 is complete, including its sorted list, and is never shown.
- Five of the "last count" statics (`0x1BEA448..0x1BEA45C`) have one reference each, the compare, and no writer: the tooltip of 5, 6, 8, 9, 10 and 11 is simply re-rendered every pass.
- `alerticon_banner` is positioned off-screen in the file and never touched. Its 30-second timer field is written and never read. Dead.
- Manager byte `+0`, a whole-pass stop, is never set non-zero.
- Alert 8 can come up with only fractional spare in each category but total spare of at least 1.000 IC; the list shows every category with any spare.
- Alert 6 offers a law **earlier in the file** than the current one (the walk is reverse-file order) whose `allow` holds; the first such in the group, one per group. The check is `allow`, nothing else (no check it is "better").
- The NAP alert's two windows: a NAP past `start + UNBREAKABLE - AHEAD` is listed until its end, listing "may be broken" lines before it can actually be broken.
- `FINDINGS-government.md` (line ~1031) and `FINDINGS-espionage.md` (line ~1296) say an alert named `politics` or `intel` opens a view inside `OnAlertClicked` at `0x64B563`/`0x64B5A8`. Those addresses lie past slot 80's `ret 4` at `0x64B2CD`, in slot 81 (`0x64B2D0`). Slot 80 has no such arms; its list is exactly section 4. The record's `OpenCountryView` comment, which lists 'diplomacy' 0 .. 'intel' 4 as "the alerts (OnAlertClicked)", is about something else.

## Not established

- What calls slot 81 (`0x64B2D0`) and what names its `politics`/`intel`/`diplomacy` arms compare; it has no direct callers (`findRefs --callers`) and was not read.
- `+0x1CD0`/`+0xF5` (slot 69): what the object is exactly, in a multiplayer session; the single-player answer is plain.
- The exact semantics of the sound manager's slots 26 and 25 (consulted before slot 9 plays `message`).
- Whether alert order on the very first pass matters beyond the row's arrival order (nothing else reads it).
- Which country has database id 0, tested in alert 2 (`c.id != 0`); `countries.txt` starts with `REB`, so REB by order is *inferred*.
- The deployment `+0xC` summed for alert 1's hash; only its use for "changed" was read.
- The frame numbers of `GFX_alerticons` are the art's and were not checked.
