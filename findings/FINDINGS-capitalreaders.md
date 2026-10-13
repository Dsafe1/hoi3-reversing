# Which capital each reader reads

Read 2026-10-13 for OpenHOI3 (`WAVE.md`, the acting capital wave). Fragment `fragments/merged/capital-readers.json`.
Addresses are VAs, with the rva beside each named function.

A country has a **declared** capital (`capital_province_id +0xE20`, `CCountry::GetCapitalLocation`, rva `0x17AF0`)
and an **acting** capital (`acting_capital_province_id +0xE24`, `CCountry::GetActingCapitalLocation`, rva
`0x2F100`). The national stockpile is `CCountry::GetPool` (rva `0xF4DE0`): `pool_in_exile` for a government in
exile, else the acting capital province's pool. `FINDINGS-surrender.md` D.5 and C say how the two fields move;
this file says who reads which, site by site of OpenHOI3's reads of its one capital field.

## In one line

- **The acting capital is the default.** Everything that moves goods or measures distance reads it: production,
  IC, supply, depots, convoys, trade routes, lend-lease convoys, threat spread, alignment, strategic resources, the
  overseas modifier, unit placement, a shattered unit's new home, `capital_scope`, and the Lua
  `GetActingCapitalLocation`, `GetDiplomaticDistance` and `GetCapital`.
- **The declared capital is read by a short list:**
  - script: `capital =` (trigger), `is_capital`, the `capital` effect's text, `continent = this/from`, the event
    text's `$CAPITAL$`;
  - the diplomacy screen's continent buttons;
  - the neutrality ceiling's different-continent term;
  - lend-lease's same-continent "teleport";
  - breaking a NAP: both the threat's origin and the dialog's PROV;
  - a trade convoy's reference harbour;
  - the possible-vassals list;
  - the division designer's order;
  - and the bookkeeping: EnsureCapital, release, liberation, the puppet swap, annexation, surrender, and some AI.
- **History sets both** (`CCountryCapitalChange::Apply`), and so does the `capital` effect. So in a new game the two
  agree for every country, and they part only in play.

## 1. Site by site

"Declared" is `+0xE20` / `GetCapitalLocation`; "acting" is `+0xE24` / `GetActingCapitalLocation`. "Pool" means
`GetPool`: `pool_in_exile` for an exile, else the acting capital province's pool, often inlined. Paths are
OpenHOI3's, relative to its `lib/`, as they stood on 2026-10-13.

| OpenHOI3 site(s) | what it does | the original's function (rva) | reads | evidence | confidence |
| --- | --- | --- | --- | --- | --- |
| Content/History/CCountryHistory.cs:135 | history `capital =` | CCountryCapitalChange::Apply (0x1EEAD0) | **both** declared and acting | read whole, section 2 | confirmed |
| Interface/Events/CEventText.cs:47 | `$CAPITAL$` | LocaliseEventText (0x5C35E0) | declared | `call 0x417AF0` at 0x9C3DA6 after the literal 'CAPITAL' | confirmed |
| Interface/Screens/CAirCombatText.cs:89, Sim/Combat/CProvinceBombing.cs:114, Sim/Missions/CBombingOrders.cs:189 | which goods a logistical strike hits | CSubUnit::BombProvince (FINDINGS-bombing.md) | no capital: the bombed province's own pool | a grep hit on "Stockpile" only | confirmed |
| Interface/Screens/CDiplomacyActions.cs:402 | NAP break dialog, PROV | CNapAction::GetDialogText (0x62D8D0) | declared | 0xA2E0BA | confirmed |
| Interface/Screens/CDiplomacyLists.cs:60-61 | continent button | CDiplomacyView::ListContinent (0x38D960) | declared | 0x78DAD5, record | confirmed |
| Interface/Screens/CLicenceText.cs:90 | licence money | CLicenceTechnologyDialog::GetOfferedMoney (0x37BB80) | pool | `+0x95` test (FINDINGS-surrender.md C.7) and an acting call in the same body | confirmed |
| Interface/Screens/CProductionScreenText.cs:43 | goods held | CProductionView::SetGoodsText (0x3FD170) | pool | C.7, acting call | confirmed |
| Interface/Screens/CTopBarText.cs:62 | goods held | CTopBar::FormatGoodsNumber (0x2C9CB0) | pool | C.7, three acting calls | confirmed |
| Interface/Screens/CUnitPanelText.cs:335-337 | `unitbase` for a land unit | CUnitStatusEntry::Update (0x359330) | **no capital**: the unit's province's `supply_depot_id`; the acting capital only in arcade mode | FINDINGS-unitpanel.md 5; no declared read in it | confirmed |
| Interface/Script/CConditionLines.cs:427, Sim/Script/CProvinceConditions.cs:97 | `continent = this/from` | CContinentTrigger::GetText (0x5E4CA0) / ::Evaluate (0x5E4B80) | declared | 0x9E4CEB, 0x9E4BEA; record | confirmed |
| Interface/Script/CEffectLines.cs:366 | `capital` effect text | CCapitalEffect::GetText (0x59F080) | declared | `mov ecx,[eax+0xE20]` at 0x99F0B6 | confirmed |
| Lua/Api/CCountryClass.cs:44 (via :163) | `GetActingCapitalLocation` | 0x2F100 | acting | FINDINGS-luaapi.md 6 | confirmed |
| Lua/Api/CCountryClass.cs:45 | `GetPool` | 0xF4DE0 | pool | luaapi | confirmed |
| Lua/Api/CCountryClass.cs:56-57 | `GetDiplomaticDistance` | CCountry::GetDiplomaticDistance (Lua, VA 0x4CCD50) | acting, both ends | 0x4CCD5F `+0xE24`, 0x4CCD67 call; luaapi | confirmed |
| Lua/Api/CResourceValuesClass.cs:26 | `.Pool` | CResourceValues::GetResourceValues (Lua, VA 0x8EA9A0) | pool | C.7 0x8EA9FE, acting call 0x8EAA11 | confirmed |
| Sim/Agreements/CPacts.cs:104, :133 | licence fee | CLicenceTechnologyAction::Apply (0x63B5A0) | pool, both sides | FINDINGS-diploaction.md (fee row); `+0xE24` at 0xA3C514 | confirmed |
| Sim/Agreements/CPacts.cs:321 | NAP broken, threat origin | CNapAction::Apply (0x62B090) | **declared** | 0xA2BFEA | confirmed |
| Sim/Agreements/CPacts.cs:427, :431 | embargo on/off, threat origin | CEmbargoAction::Apply (0x62E5F0) | acting (recipient) | 0xA2F08C, 0xA2F56A | confirmed |
| Sim/Aid/CDebts.cs:23, :46 | debt repayment | CCountry::CollectDailyProduction's last loop (0xF1F50) | pool, both | record | confirmed |
| Sim/Aid/CLendLease.cs:61-63 | lend-lease "teleport", same continent | LendLease_GetRoute (0x610180) | **declared**, both | 0xA10380, 0xA1038D | confirmed |
| Sim/Aid/CLendLease.cs:147-148 | lend-lease convoy ends | CCountry::UpdateLendLeaseRoutes (0x108C30) | acting, both areas | record; 0x508DE5/DF9 | confirmed |
| Sim/CGameState.cs:464-466 | `Stockpile()` | CCountry::GetPool (0xF4DE0) | pool (exile pool or acting capital's; never null - capital 0 gives province 0's pool) | record | confirmed |
| Sim/Combat/CCombatRetreat.cs:173-183 | a shattered unit's new home | CCountry::ShatterUnit (0x1007B0) | acting, **or** the depot province of the unit's current province where that depot's controller is no enemy | 0x5007E0; record | confirmed |
| Sim/Construction/CDeployment.cs:25, :29 | where a unit may be placed | CUnitDeployment::CanDeployIn (0x17D390) | acting capital's area; no controller test in an ordinary game | 0x57D461 | confirmed |
| Sim/Convoys/CConvoyDelivery.cs:55, :60, :116 | source and landing pool, home area | CConvoy::RunDelivery (0xC6C30) | acting area; pool | FINDINGS-convoys.md; 3 acting calls and GetPool, no declared | confirmed |
| Sim/Convoys/CConvoyDelivery.cs:172 | room in a home harbour that is no depot | AreaSupplyAndFuelHeadroom (0xDD4D0) | acting (loading country's) | FINDINGS-supplyconvoys.md 1; 0x4DD62E | confirmed |
| Sim/Convoys/CConvoyRules.cs:59 | homeward capacity of a depot | CSupply::DailySupplyPass phase 3 (0x2872D0) | acting | no declared read in it (call list and sweep); `+0xE24` at 0x687CFE | confirmed |
| Sim/Convoys/CResourceConvoys.cs:28, :57 | home area, a puppet's area | CCountry::MaintainResourceConvoys (0xFE7E0) | acting (country's and puppet's) | 8 acting calls, no declared read | confirmed |
| Sim/Convoys/CSupplyConvoys.cs:41 | home area | CCountry::MaintainSupplyConvoys (0xFDF40) | acting | record; 5 acting calls | confirmed |
| Sim/Countries/CCountryLists.cs:222-228 | possible vassals | CCountry::GetPossibleVassals (0xEE320) | declared, both (the skipped province and the vassal's capital) | 0x4EE42E call, `+0xE20` at 0x4EE4A7 | confirmed |
| Sim/Diplomacy/CAlignment.cs:284, :287 | proximity term distance | CAlignment::GetProximityTerm (0xC3C00) | acting, both | 0x4C3CC7, 0x4C3CCF; FINDINGS-alignment.md | confirmed |
| Sim/Diplomacy/CDiplomacy.cs:25 | history threat at a new game | CInGameIdler::Enter (0x25A2B0) | acting (own) | 0x65B63F before SpreadThreat 0x65B64C | confirmed |
| Sim/Diplomacy/CNeutrality.cs:72 | different-continent term | CCountry::GetMaxNeutralityForWarWith (0x105D00) | **declared**, both | 0x505E99, 0x505EB6 | confirmed |
| Sim/Diplomacy/CThreat.cs:50, :58 | SpreadThreatToAll distance | ThreatFactorTowards (0xFBCB0), from SpreadThreatToAll (0xF4E80) | acting, both | `+0xE24` at 0x4FBCFE, call 0x4FBD04 | confirmed |
| Sim/Economy/CIndustrialCapacity.cs:62 | core home IC area | CCountry::UpdateIC (0xF0CC0) | acting | FINDINGS-ic.md; 0x4F0F3B | confirmed |
| Sim/Economy/CProduction.cs:46, :248 | stockpile exists | GetPool | pool (never null in the original) | - | confirmed |
| Sim/Economy/CResources.cs:78, :107 | home yield: own area, or a depot in it | CCountry::CollectDailyProduction (0xF1F50) | acting area | record; 12 acting calls, no declared read in its extent | confirmed |
| Sim/Economy/CResources.cs:203, :215 (and CProduction.cs:256, CProvinceModifiers.cs:31) | "joined to the capital" walk | the acting capital's `COwnerArea` (UpdateIC, CollectDailyProduction, the overseas test) | acting | as above | confirmed |
| the same `HoldsCapital` used as "the country exists" (CProduction.cs:256) | the gate on the daily economy | RunCountryDailyPass | **no capital**: owns a province, or is in exile | FINDINGS-surrender.md C.5 | confirmed |
| Sim/Economy/CStockpile.cs:81 | history goods | CGoodsChange::Apply (0x1F1370) | pool; **sets** the good | read whole, section 3 | confirmed |
| Sim/Economy/CStockpile.cs:93, :130 | start stockpile, unit goods | SetUpCountryForNewGame (0xD6230) | the acting capital's province pool directly (no exile branch) | FINDINGS-leadership.md 10 | confirmed |
| Sim/Economy/CStockpile.cs:145 | home production into the stockpile | CollectDailyProduction | pool | record, C.7 | confirmed |
| Sim/Modifiers/CProvinceModifiers.cs:81 | `overseas` continent | RebuildProvinceModifierValues_Overseas (0x9F527) | acting (controller's), for both the area and the continent | record | confirmed |
| Sim/Modifiers/CStrategicResources.cs:75-76 | same continent | CCountry::GetsStrategicResourcesFrom (0x28BEF0) | acting, both | 0x68BFCB, 0x68BFD4; record | confirmed |
| Sim/Provinces/CProvinceHands.cs:47-49 | a fallen capital's loot | Province_SetController (0xA2400) | acting (old controller's) test; pool both sides | FINDINGS-surrender.md D.2 | confirmed |
| Sim/Script/CCountryConditions.cs:34 | `capital =` trigger | CCapitalTrigger::Evaluate (0x5F1C50) | declared | 0x9F1C74 | confirmed |
| Sim/Script/CCountryConditions.cs:76 | goods triggers | CMoneyTrigger::Evaluate (0x5F5E70) and siblings | pool (exile branch included) | FINDINGS-numtriggers.md | confirmed |
| Sim/Script/CCountryEffects.cs:58 | `capital =` effect | CCapitalEffect::Execute (0x59F000) | sets **both** | record | confirmed |
| Sim/Script/CCountryEffects.cs:164 | goods effects, country scope | CMoneyPoolEffect::Execute (0x5B4690) and siblings | pool | C.7; acting calls | confirmed |
| Sim/Script/CProvinceConditions.cs:32 | `is_capital` | CIsCapitalTrigger::Evaluate (0x5F2540) | declared (owner's) | 0x9F260B | confirmed |
| Sim/Script/CScopeSwitch.cs:56 | `capital_scope` | CEventScope::MakeScope (0x5C1C10) | acting | 0x9C1E7C; record | confirmed |
| Sim/Supply/CSupplyCarry.cs:33 | stockpile carried by a unit | CUnit::CarrySupplies (0x1BED80) | pool | C.7 | confirmed |
| Sim/Supply/CSupplyDraw.cs:46 | a unit in no province | CUnit::ConsumeSuppliesAndFuel (0x1BB950) | acting (owner's) | 0x5BBCB8 | confirmed |
| Sim/Supply/CSupplyDraw.cs:76-78 | a rebasing fleet | same | acting | `cmp eax,0x6DE` then 0x5BBF00 | confirmed |
| Sim/Supply/CSupplyDraw.cs:92 | unit stands in the capital (usage) | same | acting | 0x5BC19C `cmp eax,[unit+0x130]` | confirmed |
| Sim/Supply/CSupplyDraw.cs:156 | the payment | same | pool, both | 0x5BC206-0x5BC288 | confirmed |
| Sim/Supply/CSupplyFigures.cs:99, :105 | the `capital` byte, capital or beside it | RunDailyProvincePass (0x9EAB0) | acting (controller's) | `+0xE24` at 0x49ED8F | confirmed |
| Sim/Supply/CSupplyMaking.cs:24, :43 | supplies made at the factories | CDistributeSupply::Distribute (0x11AA80), CCountry::ConvertCrudeOilToFuel (0xF19F0) | acting area, "not the acting capital" | record | confirmed |
| Sim/Supply/CSupplyNetworks.cs:159, :426, :507 | home area, capital bonus, FindSupplyDepot step 5 | CSupplyGroup::PickDepot (0x80C00), ::Collect (0x809D0), COwnerArea::RefreshDepotFlags (0x7EC00), CCountry::FindSupplyDepot (0xF2B00) | acting (whose: the owner's or the controller's as FINDINGS-supplynetwork.md 2-5 says) | record; no declared read in any | confirmed |
| Sim/Supply/CSupplyPass.cs:90, :148, :292, :319-322, :337 | the stockpile province, the depot shipping home | CSupply::DailySupplyPass (0x2872D0) | acting (controller's) | 0x687CFE; 8 acting calls, none declared | confirmed |
| Sim/Supply/CSupplyStart.cs:79 | stockpile kept | RunSupplyAndConvoyIterations (0x278AB0) | pool | C.7 | confirmed |
| Sim/Supply/CSupplyStart.cs:104-105 | acting capital is its own depot | same | acting | `cmp edx,[ebx+0xE24]` at 0x678FEC | confirmed |
| Sim/Trade/CTradeRoutes.cs:144 | daily exchange | CCountry::RunDailyTradeRoutes (0xFEE70) | pool, both | FINDINGS-tradeaid.md; C.7 | confirmed |
| Sim/Trade/CTradeRules.cs:164-169 | needs a convoy | CCountry::NeedConvoyToTradeWith (0x103C60) | acting, both (area and continent) | record | confirmed |
| Sim/Trade/CTradeRules.cs:183-184 | convoy ends | CTradeAction::Apply (0x6352F0), IsConvoyPossible (0x6390D0) | **split**: reference port = first port of the buyer's **declared** capital's area; the other's end in its **acting** area; the buyer's end in its **acting** area | 0xA35C4B / 0xA35C6F / 0xA35CBC; 0xA39168 / 0xA391A4 | confirmed |
| Sim/Wars/CDeclarations.cs:171 | declaration threat origin | CDeclareWarAction::Apply (0x612030) | acting (recipient) | 0xA128E7 | confirmed |

No site maps to `GetOriginalCapital`, and every row has a counterpart in the original, except the bombing rows, which
are not capital reads at all.

## 2. History's `capital =`: `CCountryCapitalChange::Apply` (`0x5EEAD0`, rva `0x1EEAD0`)

Slot 7 of the history entry `CCountryCapitalChange` (one holder; `CExileStatusChange::Apply` is its sibling's).
`void __thiscall (bool forward)`, `ret 4`; `this+0xC` is the country, `+0x10` the new id, `+0x14` the kept one.

- **Forward**: the current declared capital is kept at `+0x14`, read by `CCountry_GetCapitalProvinceId`
  (`0x43A670`, rva `0x3A670`, `mov eax,[eax+0xE20]; ret`, its only caller). Then `CCountry_SetCapital(country, new,
  logHistory 0)` and `CCountry_SetActingCapital(country@EDI, new)`.
- **Backward**: both are set back to the kept value.

**So a history `capital =` line moves both capitals**, as the `capital` effect does (`FINDINGS-effectrun.md`). A
game started from the history files therefore has `acting_capital == capital` everywhere. The save's `capital=` and
`acting_capital=` are loaded separately (`CCountry::LoadKey`, writes at `0x4CD163` and `0x4CDEC1`).

## 3. History goods lines: `CGoodsChange::Apply` (`0x5F1370`, rva `0x1F1370`)

Slot 7 of `CGoodsChange`, one holder, `ret 4`. The good's index comes from `0x5F14A0` (the entry's save token
through slot 6; not read); 7 means none, and nothing happens.

- **Forward**: `GetPool(country)[g]` is kept at `+0x14`, then `0x523C80` stores `pool[g] = this+0x10` (`mov
  [ecx+edx*4+8], eax` - **a store, not an add**).
- **Backward**: the kept value is put back.

The target is `GetPool`, so the acting capital's province pool, or the exile pool. Where two countries' histories
both carry a goods line and their capitals are the same province, the later line wins rather than the two summing.

## 4. The puppet's tribute: `CCountry_PayTributeToOverlord` (`0x4F25E0`, rva `0xF25E0`, name ours)

`void __stdcall (CCountry* puppet)`, `ret 4`. Called once a day from the end of `CollectDailyProduction`
(`0x4F23D0`) for a country with `isSubject (+0xF34)`. Read whole.

1. `tribute_sent` (`+0x920`, its goods at `+0x928`) is zeroed.
2. **Nothing is paid** where the overlord owns no province (`+0xCF8 <= 0`); where **the puppet's acting capital is
   not its declared capital** (`mov eax,[ebx+0xE24]; cmp eax,[ebx+0xE20]; jne` at `0x4F267D`) - a puppet whose
   government has fled pays nothing; or where the puppet is in exile.
3. **Where it goes.** The neighbour links of the puppet's acting capital's area are walked in order while `dest` is
   not 0. `dest` starts at -1. For a linked area whose first province's controller is the overlord: `dest = 0` (the
   overlord's stockpile) where that area is the overlord's acting capital's area, **or where it has no harbour**;
   otherwise `dest` = the id of its first (largest) harbour, and the walk goes on. With `dest` still -1 (no area of
   the overlord's touches the puppet's home area), nothing is paid.
4. **What is paid.** For money, crude oil, metal, energy and rare materials, never supplies or fuel: `amount =
   GetPool(puppet)[g] - 2000.000` - the puppet keeps 2000 of each. Where `amount` is above 0, `tribute_sent[g] -=
   amount` (held negative) and the puppet's pool loses it. With `dest == 0`: the overlord's `tribute_received`
   (`+0x8FC`) and `GetPool(overlord)` gain it. Otherwise it lands in harbour `dest`'s pool, and **no ledger of the
   overlord's counts it**.

## 5. Every reader of the declared capital

`findRefs --callers 0x417AF0` finds 55 calls. A sweep of `.text` for dword operands at `+0xE20`/`+0xE24` decoded
5,510,780 instructions in int3-split chunks, resumed past every stop, two chunkings unioned: 33 `+0xE20` and 52
`+0xE24` candidates. The positive controls are `GetCapitalLocation`'s own read (`0x417B84`) and
`GetActingCapitalLocation`'s (`0x42F194`), and both were found.

Named readers of the declared capital:

- **Script**: `CCapitalTrigger::Evaluate`, `CIsCapitalTrigger::Evaluate`, `CCapitalEffect::GetText`,
  `CContinentTrigger::Evaluate`/`GetText`, `LocaliseEventText`, `CReleaseVassalEffect::Execute`,
  `CFormGovernmentInExileAction::Execute`.
- **Diplomacy**: `CNapAction::Apply`, `CNapAction::GetDialogText`, `CCountry::GetMaxNeutralityForWarWith` and its
  tooltip, `LendLease_GetRoute`, `CTradeAction::Apply`, `CTradeAction::IsConvoyPossible`,
  `CDiplomacyStatus_ExpireRelations`, `CCasusBelli::RemoveFromStatus`, `CDiplomacyView::ListContinent`.
- **Country state**: the capital's own machinery (`CCountry::EnsureCapital`, `CCountry::GetOriginalCapital`, the
  setters, save, load and reset); surrender and annexation (`AnnexCountry`, `CCountry_Surrender`,
  `CWarGoal::Enforce`); the puppet's other paths (`ExileDaily_PuppetSwapGate`, `CCountry_ReplaceExileWithPuppet`,
  `CCreateVassalCommand::Execute`, `CLiberateCountryCommand::Execute`, `ReleaseProvinces`,
  `CCountry::GetPossibleVassals`); the tribute (section 4), and `SetGovernmentInExile`'s return (acting =
  declared).
- **Other**: `CDivisionDesigner::OnAccept`.
- **AI**: `CEU3AI::PlanAmphibiousInvasion`, `CEU3AI::PickInvasionLandingProvince`, `AreaMayWidenFrontSearch`,
  `CAIPoliticsMinister::DoWork` (`IsCapitalSafeToLiberate`), `ApplyCountryAIStrategies`.

Unnamed functions holding a call or a read, by `functionStart` only (trap 2 applies): interface and front end -
`0x418BC0` (custom game), `0x5B5B50`, `0x62A4C0`, `0x69BE90`, `0x6BE790` (the politics view's liberation list,
`FINDINGS-surrender.md` C.7), `0x6EA010`, `0x704560`, `0x709B40`, `0x70E360`, `0x7106F0`, `0x83D9E0`; country and AI
code - `0x4EDED0` (the possible liberations, C.7 `0x4EE034`), `0x4EE560` (the production minister's value),
`0x88F2B0`, `0x8972E0`, `0x8A6AC0`, `0x8A73C0`, `0x43C2E0`, `0x4B0A00`, `0x4BA0EA`, `0x4BE0E0`, `0x4BE3D0`,
`0x4BF8E0` (the inlined `GetOriginalCapital` loop, `FINDINGS-history.md`). The two `esp`-based hits (`0x603B9F`,
`0x65BFCA`) are stack slots, not `CCountry`.

**Lua**: `GetCapitalLocation` is the declared province; `GetActingCapitalLocation` the acting one; `GetCapital` is
`CCountry::GetActingCapital` (`0x46C370`), the acting **id**. `GetAreActingCapitalsOnSameContinent` (`0x508080`) is
acting by name and was not read.

## 6. The pool

`GetPool` is inlined almost everywhere as `+0x95 ? +0x9F8 : GetActingCapitalLocation()->+0x15C`, which is why
"pool" readers show up among the acting capital's 420 call sites. **Three places take the acting capital's province
pool with no exile branch**: `SetUpCountryForNewGame` (the start stockpile, `FINDINGS-leadership.md` 10); the
fallen-capital test in `Province_SetController`, whose loot then goes through `GetPool` on both sides; and the
history goods line, which goes through `GetPool` and sets rather than adds.

## 7. What looks wrong and is what the bytes do

1. Breaking a NAP spreads threat from the recipient's **declared** capital. Every other `SpreadThreat` source passes
   an acting capital: the declaration, the embargo, mobilisation, the capitulation and the new game.
2. Lend-lease's "same continent, no convoy" asks the **declared** capitals; trade's `NeedConvoyToTradeWith` asks the
   **acting** ones. So a fled government can trade overland and still need lend-lease to cross, or the other way
   round.
3. A trade convoy's reference harbour is the first port of the buyer's **declared** capital's area; both of its ends
   are chosen in the acting capitals' areas.
4. The division designer orders at the **declared** capital; the brigade, air and ship builders order at the acting
   one.
5. `$CAPITAL$`, `capital =`, `is_capital` and `continent = this/from` all speak of the declared capital, while
   `capital_scope` scopes to the acting one. A `capital_scope = { is_capital = yes }` is false while the capital is
   occupied.
6. A puppet whose acting capital has moved pays no tribute at all.
7. A puppet whose home area touches an area of its overlord's that has no harbour pays straight into the overlord's
   stockpile; a harboured area of the overlord's gets the tribute in its port, and the overlord's ledger never
   counts it.
8. A history goods line sets the stockpile rather than adding to it.
9. The unit panel's "Supplied from" for a land unit is the depot of the unit's province, not a capital.

## 8. Not settled

- What a build order's province is used for (`CConstructUnitCommand`'s constructor `0x545760`, rva `0x145760`, not
  read), so whether the designer's declared capital changes anything.
- `0x5F14A0`, the history goods token-to-index map; that 7 means "none" is inferred from the exit test.
- The unnamed declared readers in section 5 were attributed by `functionStart` and not read.
- `GetAreActingCapitalsOnSameContinent` was not read.

## 9. Frontier (rvas)

`0x1F14A0`, `0x145760`, `0xEE560`, `0xEDED0`, `0x3C2E0`, `0xB0A00`, `0x108080`.

**Traps met.** Trap 14, in nearest-name attribution: three `GetPool` calls looked like `CNeutralityChange::Apply`'s
and are `CGoodsChange::Apply`'s; the capital getter `0x43A670` looked like `GetOwnedProvinces`', and the tribute's
two field reads looked like `CollectDailyProduction`'s. Each was settled by the vftable or by `functionStart` with
`retsBefore`. Trap 12: the `+0xE20`/`+0xE24` sweep's hits are candidates; only those named here were read in place.

Function table: 0x1EEAD0 CCountryCapitalChange::Apply new confirmed; 0x1F1370 CGoodsChange::Apply new confirmed;
0x3A670 CCountry_GetCapitalProvinceId new confirmed; 0xF25E0 CCountry_PayTributeToOverlord new confirmed; revised
(which capital, nothing else): 0x17D390 CUnitDeployment::CanDeployIn (acting), 0x610180 LendLease_GetRoute
(declared), 0x62D8D0 CNapAction::GetDialogText (declared), 0x62B090 CNapAction::Apply (declared), 0x105D00
CCountry::GetMaxNeutralityForWarWith (declared), 0x5C35E0 LocaliseEventText (declared), 0x6390D0
CTradeAction::IsConvoyPossible (declared reference area), 0x3E4B20 CDivisionDesigner::OnAccept (declared). No struct
field touched.
