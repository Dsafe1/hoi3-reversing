# Expeditionary forces, from the diplomacy row to the unit changing hands and back

*Read 2026-11-09 from the decompilation of a private copy of `Hoi3_v12.1.2` and from the listing, for OpenHOI3. Every figure here is the original's executable or its localisation; where a figure can be changed by a mod the file is named in brackets. Addresses are rvas unless marked VA.*

## In one line

The diplomacy screen offers a send row (and, while a unit is on loan with no recall pending, a Retrieve row and a Return row); the row's window lets the player tick one unit; Accept posts the action; an accepted offer moves the unit to the host at once and charges the influence on the offer; a withdrawal only sets the unit's `expeditionary_date` to now + `EXPEDITION_RETURN_TIME` days and the host's daily pass sends it home after that. The unit stays usable by the host until then and answers to the lender for officers, supply, reinforcement, upgrades and technology.

## 1. The window (`CExpeditionaryForceDialog`, `ExpeditionDialog`)

**Made by** `DiplomacyView_OpenActionDialog` for the action's token `0x71A` (`send_expedition`), whatever its `value`. The window sits at the screen's `diplo_request_pos`. Constructor `0x375BE0`; table `0x11DA284` (VA `0x15DA284`); slots: 0 scalar deleting destructor, **1 Update, 3 the folded `EmptyTooltip`, 4 the folded `ReturnTrue`, 5 Accept, 6 Decline, 7 IsStillOpen**, the rest `CEU3Dialog`'s.

**No element of this window has a tooltip**: slot 3 is the shared empty tooltip. That covers the kind buttons, the list and both buttons.

### 1.1 The elements

| element | what it does |
| --- | --- |
| `LeftShield` / `RightShield` | flags of the action's actor (`+8`) and recipient (`+0x10`) |
| `Title` | the action's slot 10 GetTitle: `SENDEXPEDTITLE` "Expeditionary Force" (value set), `RETRIEVEEXPEDTITLE` "Retrieve Expeditionary Force" (value clear, ClaimType 0), `RESENDEXPEDTITLE` "Return Expeditionary Force" (value clear, ClaimType 1) - keys are slot 20's `SENDEXPED`/`RETRIEVEEXPED`/`RESENDEXPED` + `TITLE`. The prefixes themselves have no text in the tables, so an unset prefix comes back as itself and the title resolves (FINDINGS-agreements, oddity 11). |
| `Description` | see 1.5 |
| `diplo_popup_chance_bg`, `chance_string` | hidden in the constructor; nothing writes a chance. The AI's answer is not shown here |
| `ArmyButton` (`UNIT_ARMY_NAME`), `AirButton` (`UNIT_AIR_NAME`), `NavyButton` (`UNIT_NAVY_NAME`) | **change which kind the list shows**: kind 2 land (the default), 0 air, 1 navy, then rebuild. The list shows one kind at a time; a tick survives a change of kind only in the sense that a rebuild re-ticks what the three lists hold (1.3) - so there is one selected unit across all three kinds |
| `unitlist_list` | the tree of units, section 1.2. `expedition_entry` rows |
| `AgreeButton`, `DeclineButton` | text overridden to `ACCEPT` "Accept" and `DECLINE` "Decline" (the file's `PW_I_DO`/`PW_RUN_AWAY` are never seen); **Agree is disabled while none of the three selection lists has an entry** |

`bg_diplo_new`, `bg_exp_force` and `diplo_popup_banner` are pictures from the file and nothing touches them.

### 1.2 Which units, in what order

`CExpeditionaryForceDialog::FillUnitRows` (`0x377630`), walking a country's unit list **in list order - no sort** - and adding a row per unit. Which list and filter depend on the action:

| action | list walked | filter (`returning` / owner) |
| --- | --- | --- |
| value set (Send) | the player's units (`+0xBAC`) | `returning` false: the unit has **no expeditionary owner** (`+0x290 == 0`) |
| value clear, ClaimType 1 (Return, the host giving back) | the player's units | `returning` true, owner = the action's recipient (`+0x10`/`+0x14`) |
| value clear, ClaimType 0 (Retrieve, the lender recalling) | the **recipient's** units | `returning` true, owner = the action's actor (`+8`/`+0xC`) |

With `returning` true a unit must have `expeditionary_owner_id == owner` **and** `expeditionary_date >= defines.end_date` (no recall pending - a recalled unit is not offered again), and at depth 0 not have a parent that is also lent by that owner (so a lent corps appears once, at its top).

Then by kind: 2 land (slot 15), 0 air (slot 17), 1 navy (slot 16). Land only: at depth 0 a unit with a parent is skipped (in send mode; see the returning rule above for the other); and **only a land unit recurses into its children, and only while its `outliner_expanded` (`+0xB4`) is set**, each child's row at depth + 1. So the list is a tree the outliner's expansion state controls; air and fleets are flat.

A theatre (`oob_level` 0) **is listed but its box is disabled**: it cannot be picked (`CBrowserItem`).

Every frame `Update` (slot 1) counts the rows the list should have (`CountUnitRows`, the same filter) and compares with what it holds: equal -> each row's slot 8 Update; different -> `RebuildUnitList`, which refills the list and re-selects ticked rows, keeping the scroll position in proportion. So a unit that leaves the list while the window is up drops out at the next frame.

### 1.3 A row (`CBrowserItem`, window `expedition_entry`)

- `expand` (a `>` button): flips the unit's `outliner_expanded` - the same flag the outliner uses, so the expansion is shared with the outliner; the row list follows at the next frame. Disabled for a land unit with no children (slot 8 Update); enabled otherwise.
- `select_frame` (a checkbox): ticked -> `CBrowserItem::OnSelect` -> `ExpeditionDialog_SelectRow`; unticked -> `CBrowserItem_OnUnticked` -> `ExpeditionDialog_DeselectRow`. Disabled for a theatre (`oob_level == 0`).
- `name`: the unit's name (its slot 7).
- `location`: its province's name.
- `counter_type`: the picture `GFX_counter_` + the first brigade's type, only when the unit's `intel_level` is 3 or more and it has a brigade.
- `counter_size`: frame `n + 1` with n by oob_level: 0 -> 5, 1 -> 4, 2 -> 3, 3 -> 2, 4 -> 1 where the unit has more than one brigade else 0, 5 -> 1, otherwise 0.
- Indent: the row's x = depth x `browser_offset`.x (sidebar.gui, 10), y kept.

### 1.4 What selecting does

**Exactly one unit is ever chosen.** Ticking a row clears all three selection lists and unticks every other row, adds the row's unit to the current kind's list, stores the row's `CRef` as the action's unit (`+0x2C`), ticks (cosmetically) the visible rows of its children (those rows' units are not added to any list), and refreshes the description. Unticking removes the unit from the list and empties the action's unit (the null ref).

**Oddity (kept as read):** `ExpeditionDialog_DeselectRow` removes the unit from its selection list for land and air only. For a fleet the list keeps its entry, so its description and Agree stay as if still selected while the action's unit has been emptied; the Accept then posts an action whose unit does not resolve, and `CDiplomaticActionCommand::Execute`'s IsValid drops it. A tick of another row clears all lists anyway.

Nothing tests the chosen unit further: not in a battle, not at sea, not aboard a ship, not in a province. The lists only test what 1.2 says.

### 1.5 Description text (`ExpeditionDialog_UpdateDescription`, `0x376330`)

Written whenever a selection changes and once at construction. Head + unit's half:

- **Head, value set:** `SENDEXPEDNEWDESC`, `$RECIPIENT$` = recipient's name. "Do you wish to send an expeditionary force to $RECIPIENT$ to use as they see fit?"
- **Head, value clear:** `RETRIEVEEXPEDNEWDESC`, `$RECIPIENT$` = the recipient (ClaimType 1) or the actor (ClaimType 0), `$DATE$` = today's tick + `EXPEDITION_RETURN_TIME` (ClaimType 1) or `EXPEDITION_RECLAIM_TIME` (ClaimType 0) days x 24, written `year month day hour:00` (the date formatter's hour form). "Do you wish a unit to be returned home to $RECIPIENT$? If you do so, the unit will revert to the original owner on $DATE$."
- **Unit's half**, for the first selection list with an entry (land, then navy, then air): `EXPEDNEWDESC_ARMY`/`_NAVY`/`_AIR`, each `$UNIT$` the unit's name, `$NUM$` the units in the tree counted from itself (`ExpeditionDialog_CountDescendants`: a lone division says 1, a corps of 2 divisions says 3 - it is units, not divisions or ships), `$PROV$` the province's name.

**Oddity:** the head reads `RECLAIM_TIME` for a Retrieve but `Apply` always uses `RETURN_TIME` (section 3). Vanilla sets both to 30 days (`common/defines.lua`, `EXPEDITION_RETURN_TIME`, `EXPEDITION_RECLAIM_TIME`, mod-able) so it does not show; BlackICE sets both to 1.

### 1.6 Accept, Decline

Accept (slot 5): stamps the action's date with the tick, makes the command (slot 6), posts it through the host's channel, re-enables the action list unless automated, closes. Agree is only pressable with a unit ticked (1.1); if the chosen unit's ref no longer resolves when the command is run, `IsValid` drops it (the command does nothing). Decline (slot 6): posts nothing; rebuilds the view's action list when the recipient is still the view's country; closes. `IsStillOpen` (slot 7): open while the diplomacy view is shown and its current dialog is this one or empty.

## 2. The diplomacy screen's rows

`CCountry::GetDiplomaticActionsToward`, under the heading "where allied or in one real faction" (S.alliance set, or the same real faction - FINDINGS-agreements, B.2):

1. **`send_expedition` value 1**, `type` PROPOSE, one row, title `SENDEXPEDTITLE` "Expeditionary Force".
2. **The player holds a unit lent by the recipient** (`expeditionary_owner_id == recipient` and date `>= defines.end_date`, first in the player's unit list) -> one row, value 0, type 3 (ACCEPT|DECLINE), `ClaimType` 1: title "Return Expeditionary Force".
3. **The recipient holds a unit the player lent** (its `expeditionary_owner_id == the player` and date `>= defines.end_date`, first in the recipient's unit list) -> one row, value 0, type 3, `ClaimType` 0: title "Retrieve Expeditionary Force".

At most one row of 2 and one of 3, each stopping at the first unit.

**Enabled state** (row slot 11): greyed where the action's slot 14 is false or slot 21 true and a diplomat is en route. For this class slot 21 answers `value`, so **only the Send row is greyed by the diplomat's seven days**; the withdrawal rows never are.

- **Send row greyed (slot 14):** actor == recipient; the diplomat; influence below `EXPEDITION_INFLUENCE_COST` [defines.lua, diplomacy block, +0xAC]; a chosen unit that is a theatre (a row has no chosen unit, so this last never greys a fresh row - corrected from the record).
- **Withdrawal rows:** actor == recipient, and a chosen unit being a theatre (no chosen unit on a fresh row, so effectively always enabled).

**Tooltip** (slot 11, row tooltip): `ACT_NO_SELF` same country; value set: `ENROUTE` `$DATE$`, `DIP_NO_INFL` `$INF$` (cost, 0 decimals), else `SENDEXPEDDESC` "Send a formation as an expeditionary force."; value clear: `RETRIEVEEXPEDDESC` "Demand that an expeditionary force return home to you." (ClaimType 0), else `RESENDEXPEDDESC` "Send an expeditionary force back to its owner." (ClaimType 1).

Pressing any of these rows opens `CExpeditionaryForceDialog` (FINDINGS-agreements B.4); there is no other dialog and nothing opens nothing. Which unit is the row's unit is decided in the dialog, not by the row.

## 3. The flow, end to end

1. **Press the row** -> the dialog. Pick a unit -> the action's `unit` = its `CRef`.
2. **Accept posts `CDiplomaticActionCommand`** with the action cloned by slot 16 and the date stamped.
3. **`CDiplomaticActionCommand::Execute`** on every machine: slot 13 IsValid - with value set, the two countries must be in one faction (null faction included - the row checks "real faction", this does not) or allied; and the unit ref must resolve and not be a theatre - else nothing happens. A PROPOSE (type 0) stamps the status's `next_offer_allowed` +168 hours (7 days) so every row for that country that slot 21 does not exempt greys. The per-class slot 7 **Apply** runs. A clone is queued on the recipient (PROPOSE) or actor's pending list.
4. **Apply** (`0x6395B0`), keyed on `type` and `value`, never on ClaimType:
   - `type == 0` PROPOSE and value set: `-EXPEDITION_INFLUENCE_COST` to the actor's influence (`CCountry_AddInfluence`, floor 0) **at the offer**, before any answer.
   - `type == 2` ACCEPT and value set: the hand-over (below) and the news.
   - **value clear, any type** (the rows are type 3): `unit.expeditionary_date = tick + EXPEDITION_RETURN_TIME x 24` hours. That is all: no message, no answer, no hand-over. (`EXPEDITION_RECLAIM_TIME` is never read here.)
   - type 1 DECLINE and value set: only the news below.
5. **Who answers a PROPOSE with value set.** Slot 18 (`NeedsAnswer`) answers `value`, so a send is answered and a withdrawal is not. An AI recipient: the hourly pass flips the pending clone to ACCEPT by `GetAIAcceptance` (slot 17, Lua `DiploScore_SendExpeditionaryForce` in `script/ai_diplomacy.lua`: score 0 at peace, 40 or 70 with supplies stockpiled at 10 or 20 weeks' use plus 20 at war) - 30 or less declines, otherwise a roll of the game's generator below the score (FINDINGS-agreements). A player recipient: `AskPlayer` -> icon kind 9 (`GFX_diplo_message_icons`), `CAskExpedition` -> `ASKEXPEDITIONREQDESC` with `$ACTOR$`, `$UNIT$`, `$NUM$` (**wrong**: `CAskExpedition_CountDescendants(unit, 0)` is 0 for a lone unit and otherwise too large - a real bug of the original, confirmed on the listing, `0x6114C0` adds its recursion's accumulated total), `$TYPE$` (`EXP_SHIP`/`EXP_SQUADRON`/`EXP_DIVISION`), `$PROV$`. The dialog declines itself if the unit no longer resolves (`CAskExpedition::IsStillOpen`) and by the base rule after two months (an icon unopened seven days declines, FINDINGS-agreements). Accept/Decline set `type` 2/1 and post.

**The hand-over** (`type == 2`, value set, `0x639F2F..`):
`CUnit_LeaveParent(unit, 1)`; `expeditionary_date = defines.end_date` (no recall pending - the constructor's default is the same); where `expeditionary_owner_id == 0` it takes the unit's owner and the unit goes on that country's `expeditionary_units_lent` (`+0xBBC`, `CCountry_AddToLentList`); the unit leaves its owner's units list and `CCountry::AddUnit(recipient)` takes it (owner `+0x124/+0x128` and each regiment's owner, `CUnit_SetOwner`, which also clears the unit's AI agent); **where it has children**, `CUnit_TransferChildren(unit, unit, recipient, 0)`: each child gets the same treatment (own expeditionary owner if none, on the lent list, unlinked, added, re-attached under its parent, recursively, its date left at the default). So **a unit that is already lent is not lent again by this code path's bookkeeping** (`expeditionary_owner` set stays the first lender). No test that the unit is in a battle, moving, at sea or aboard a transport, and Apply touches neither the unit's orders nor its leader.

**News** (a CMessage, `diplomaticsuccess`/`diplomaticfailure` sound where the actor is the player):
- Accepted: `OUREXPACC` to the actor's player ($ACTOR$, $RECIPIENT$, $UNIT$, title "Expeditionary Force Accepted!", log "$RECPIENT$ accepted $UNIT$ as an expeditionary force."); **`EXPOTHER` to every other player, recipient included** ("$ACTOR$ sent an expeditionary force to $RECIPIENT$").
- Declined: `OUREXPDEC` to the actor's player only ("$RECIPIENT$ rejected $UNIT$ as an expeditionary force."); the influence is not refunded.
- A withdrawal posts no message.

**Coming home, the date route** (the player's own route, and a government-in-exile's): `RunCountryDailyPass` (the host's day), `0xDB1AD..0xDB418`: every unit of the host's `units` with an expeditionary owner and `expeditionary_date < tick` goes on a local list; **only the first of them** is `CUnit::ReturnFromExpedition`'d that day (`if head && head.owner == country`) - so several recalled units come home one a day, list order, and a unit whose owner stopped being the host is skipped. So the unit stays the host's for at least the given number of days and is usable by the host meanwhile; the tooltip on `exp_force` (section 4) gives the date.

**`CUnit::ReturnFromExpedition`** (recorded): leaves its parent, off the lender's lent list, `expeditionary_owner` cleared, off the host's units, `CCountry::AddUnit(lender)`, `CUnit_TransferChildren(unit, &lender, 1)` **with detachOnly set - its children are detached and left on the host's list as the host's own**, avatar rebuilt, province re-entered, intel reckoned, and `EXPRETURNED`/`EXPRETURNEDWE` where the local player is the lender or the host. (`ReturnFromExpedition` handles one unit; `CSendExpeditionCommand` is the route that recurses.)

**Coming home, the command route** (AI and only AI): `CSendExpeditionCommand` is posted only by `CAIUnit::ManageExpeditions` (give back, or lend) and `CEU3AI_SendLandlessUnitsOnExpedition`. Its Execute moves the unit immediately and recurses through `CSendExpeditionCommand_TransferSubtree`; no date wait, no message.

**The end of a loan is never automatic on a change of diplomacy.** Reasons a unit returns: (1) the daily pass on an expired date; (2) `AnnexCountry` (host annexed - units lent to it and units it lent out are returned first; FINDINGS-surrender A); (3) `SetGovernmentInExile` (host in exile, for units lent to it standing where the controller is not its friend - returned and shattered; FINDINGS-surrender); (4) the AI's commands; (5) a save's load. **Nothing returns it when the lender leaves the alliance, the two go to peace or a war ends.** Search: `findRefs.py --callers 0x5020E0` gives exactly four callers (the daily pass, `AnnexCountry` twice, `SetGovernmentInExile`), and `findRefs.py --callers 0x5E95B0` three callers (all AI); the writers of `+0x290` over the image (fieldchain census, 153 sites in 111 functions) are `CUnit::CUnit`, `CUnit::LoadKey`, `CUnit::ReturnFromExpedition`, `CUnit_TransferChildren`, `CSendExpeditionCommand::Execute`/`_TransferSubtree`, and `Apply`. Positive control: the same census finds Apply's known writes at `0xA39F86` and `0x5E982C`.

## 4. What a lent unit is afterwards

Fields: `expeditionary_owner` (+0x28C `CCountryTag`, +0x290 id half: the lender, `---`/0 otherwise), `expeditionary_date` (+0x294: `defines.end_date` when not being sent home - the constructor's default and the value at every hand-over; an hour tick otherwise), `owner` (+0x124: the host). The lender's list `expeditionary_units_lent` (+0xBBC) holds it; on load it is rebuilt from `expeditionary_owner` (`CUnit::LoadKey`, `CCountry_AddToLentList`).

- **Who orders it:** the host. `CCountry::AddUnit`/`CUnit_SetOwner` make `owner` the host, every order, selection and panel test that reads the owner reads the host (inferred from the fact the ownership field changes and from the panel tests below; the host's orders are not read separately).
- **Whose country it counts as, from its brigades' point of view:** `CSubUnit::GetOwner` answers the unit's expeditionary owner where it has one. Callers (from `findRefs --callers`): max organisation (`GetMaxOrganisationWithBonus`), targeting skill, a brigade's supply and fuel consumption, equipment lines, name setting, the upgrade and build commands. So organisation, consumption rates and those stats are the **lender's** technology and modifiers.
- **Modifiers/combat:** the combat modifier passes read the expeditionary owner's modifiers where one exists: `CBomberCombatant`/`CTargetCombatant`/`CNavalCombatant`/`CLandCombatant::ApplyCombatModifiers`, `CSubUnit::PickTarget`, the AI's `AICombatEstimate*`; `CUnit::GetCombinedArmsBonus` the lender's technology (its own `+0xDF8` status) for the group levels; `GetCombatWidth` and `SumUnitListCombatWidth` the lender's `combat_width`, `ReinforceChance` the lender's reinforce modifiers.
- **Officers:** `RegainOrganisation`, `OrgRegainText`, `StartAttackDelay`, `ShatterThreshold`, `CGameState::RemoveUnit` and `SettleCombatDamage` use the lender's officer ratio or pool (the lender pays officer losses and gets the casualty trickleback, `AddCasualtyTrickleback`).
- **Supply:** `CUnit::ConsumeSuppliesAndFuel`: the payer is the expeditionary owner. Where the depot is the payer's friend but not the payer it pays the price (FINDINGS-supply), recorded on the existing entry.
- **Reinforcement and upgrades:** the lender's. `CDistributeReinforcement` and `CDistributeUpgrade` walk the country's own units **excluding** those with an expeditionary owner and then the lent list; so a host does not reinforce or upgrade lent units and a lender reinforces and upgrades what it lent. `CSubUnit_MayUpgradeWhereItStands` refuses a unit on loan: a brigade on a lent unit cannot be upgraded by the normal upgrade paths for standing in place.
- **Research:** a lent brigade's technologies are not the host's as far as `CSubUnit::GetOwner` goes (the lender's level); the host's research does not improve it (section 'Not established' on `CSubUnit::ApplyTechnologies`).
- **Leaders:** the leader stays on the unit; neither Apply nor `CSendExpeditionCommand` touches him. `CRemoveAllLeadersCommand` skips units on loan. The `CUnitView` `leader_button` is disabled while on loan and enabled by the same routine's later branches (FINDINGS-leaderwindow section 9 - the first test's disabling is undone by the last line), so the host's panel can open the window for it. Which country's list of leaders is offered there is not read here.
- **Merging, reorganising, attaching:** a unit on loan may not be merged or reorganised (`UnitList_MayMerge`, `UnitList_MayReorganise`) and takes or gives no brigades (`CUnit_CanTakeSubUnit` either side), cannot be attached to (the deploy menu's `CSideMenuDeploy::Update` list of attach targets drops units with an expeditionary owner) and is not disbanded (`CInGameIdler_DisbandSelection`, and `disbandbutton` greyed by `CSingleUnitButtons::Update` for +0x290 set).
- **`split_troops`** (`CSplitTroopsEffect`) skips units on loan.
- **AI:** `CEU3AI::DeployFinishedUnits` will not attach a new unit to one (no expeditionary owner required); `AI_ManageUndergrounds` and `CEU3AI::PlanAmphibiousInvasion` count them by the lender's side.

**How it shows:**
- Unit panel: `exp_force` (unitpanel.gui, `GFX_exp_minishield`) carries the lender's flag where `expeditionary_owner_id` is set, hidden otherwise (CUnitView constructor). Tooltip (`CUnitView::BuildTooltip`): `UW_XP_FORCE_IRO` "This is an expeditionary force from $COUNTRY$." delayed `UW_XP_FORCE_DRO` "These forces have been lent to us by an ally. We can return them at any time."
- A second, different `exp_force` tooltip exists in `CInGameIdler::GetElementTooltip`: `EXPED_OWNER` "Expeditionary force from $COUNTRY$" and, where the date is before `end_date`, `EXPED_EXPIRE` "Expeditionary force returned to owner on $DATE$". The panel answers first, so it is not established this one is ever reached (see Not established).
- The map counter: `RebuildAvatar` (and `AddRegimentToUnit`, `RemoveRegimentFromUnit`) set the counter's flag quad from the expeditionary owner's tag where set, else the owner's - **a lent unit shows the lender's flag on its counter**. Its graphical culture (the counter's artwork lookup, `CUnit_PictureCultureName`, inferred) likewise prefers the expeditionary owner.
- Row in `CSideMenuDeploy`/outliner: only the attach/disband restrictions above were found; no special display.
- `CCountry::RecountUnitTotals`: lent units are not counted on the host's totals but are counted for the lender's. `CAIUnit::ManageExpeditions`, hourly, for AI hosts.

## 5. Save keys

- On a unit: `expeditionary_owner` (save token 0x720, the lender's tag as a string) and `expeditionary_date` (0x721, a date), both written by `CUnit::SaveContents` only where `expeditionary_owner_id` is set; `CUnit::LoadKey` reads them, the former adding the unit to the lender's lent list.
- On the action (`send_expedition`, token 0x71A): the base's `actor`, `recipient`, `type`, `date`, `value` etc., plus `unit` (0x256, a CRef) and `action` (0x2ED, ClaimType as an int) - `CSendExpeditionaryForceAction::LoadKey`.
- The command `CSendExpeditionCommand` saves `unit` and `target`.

## Oddities to keep as read (none put to the maintainer)

1. `$NUM$` in the receiver's popup (`CAskExpedition_CountDescendants`) is wrong: 0 for a lone unit.
2. `$NUM$` in the sender's own description counts the top unit as well as the units under it, whatever their kind.
3. Deselecting a fleet leaves it in the selection list while emptying the action's unit (1.4).
4. The dialog's Retrieve date text uses `EXPEDITION_RECLAIM_TIME`; the real delay is `EXPEDITION_RETURN_TIME`.
5. `ReturnFromExpedition` calls `CUnit_TransferChildren` with detachOnly 1: a returning unit with children goes home alone and its children stay, detached, as the host's own units (the daily route; the AI's command route instead recurses and moves them).
6. Several recalled units come home one per day per host.
7. The influence cost is charged at the offer and is never refunded on a decline.

## Not established

- ~~Who the leader window lists for a lent unit.~~ **The host's own leaders: the maintainer opened it on a received unit on 2026-11-09.** Whether a leader change on a lent unit behaves differently otherwise was not read.
- **Which `CMessage` location the OUREXPACC/OUREXPDEC/EXPOTHER messages use.** The code takes an acting capital of a tag held in a local (`[esp+0x18]` at `0xA39875`); which country it is was not resolved from the listing. The Goto is therefore not established.
- **Whether `CInGameIdler::GetElementTooltip`'s `exp_force` branch (EXPED_OWNER, EXPED_EXPIRE) is reached.** `CUnitView::BuildTooltip` answers `exp_force` first on the single-unit panel (FINDINGS-unitpaneltooltips section 1). If the multi-unit panel or another view holds the element, the date tooltip appears there; not read.
- **`diplo_popup_chance_bg`/`chance_string` hidden:** read as hidden from the constructor's slot calls `0x104` and `0x38` by analogy with the standard dialog; not re-derived from the GUI element's vtable.
- **`CSubUnit::ApplyTechnologies`** reads `+0x294` at `0x5AC073` on some object; not traced, so "the host's research does not apply to a lent brigade" rests on `CSubUnit::GetOwner`'s callers alone.
- Census sites not opened (other classes' same offsets almost certainly, but not checked one by one): `0x520251` and `0x51F9F5..` in `CDistributeResearch::Distribute`, `0x7FDF3F`, `0x4DFE99/0x4DFFEA` (`IsBuildingAllowed`), `0x821B23`, `0x8AF080`, `0x9DB597/0x9DBB0B`, `0x4C8530`, `0x8178E9`, `0x41A73F`, `0x41FEFC`. A CUnit reader among them would change a line of section 4.
- **The negative "nothing returns a unit when the war ends or the alliance breaks"** rests on the callers of `0x5020E0` and the +0x290 writers census. The peace and alliance code were not read for anything else that might walk the lent list (`+0xBBC`), though nothing else writes `+0x290`, so nothing could move the unit that way.
