# The nuclear bomb

The nuclear bomb in Hearts of Iron 3: Their Finest Hour, read out of `hoi3_tfh.exe` on 2026-11-09. Addresses are virtual, based at 0x400000, unless a table says rva. Every figure below is marked **hard-coded** or as a **define in `common/defines.lua`**, named. `confirmed` means read from the bytes; `inferred` says why.

## 1. Where bombs come from

`CCountry +0x90`, `nukes`, is the country's stock in thousandths. **1000 is one bomb.**

The **only** ongoing source is at `0x4DCB3D` in `CCountry::UpdateMonthly`:

    nukes += technology_status (+0xDF8) -> nuclear_production (+0xBC)

(`confirmed`.) It is **monthly and not daily**, once per country on the month's pass (`RunMonthlyPass`, over the countries from index 1), whether the country is played or at war or not. It is unconditional, unfloored and has no cap.

`nuclear_production` is the sum over technologies of each technology's file key `nuclear_production` x the level (`CTechnologyStatus::ApplyTechnologyEffects`). Their Finest Hour has exactly one technology with the key: **`da_bomb`** in `technologies/Secret Weapons.txt`, `nuclear_production = 0.1` a level, `max_level = 12`, **mod-able** (the technology files). So one level gives 100 thousandths a month, **one bomb every ten months per level**. The figure is read once a month and nothing scales it: **`nuclear_reactor` is not in the formula at all.**

The reactor matters only as the technology's prerequisite: `da_bomb`'s `allow` is `civil_nuclear_research = 4` and `any_owned_province = { has_building = nuclear_reactor }` (a **file**), so the level cannot be researched without it. The building's own `on_completion = nuclear_bomb`, `completion_size = 6` and `capital = yes` are unrelated to the stock.

`NUKE_PRODUCTION` on the production screen's tooltip shows that figure, thousandths, two places: "We are producing about 0.10 nuclear bombs every month" (`CProductionView::BuildTooltip`); `NO_NUKE_PRODUCTION` where it is nought. `nukes_value` on the top of the screen is the stock (`CCountry +0x90`) with two places.

### Everything that writes the stock (`confirmed`)

A scan of every store of the form `[reg + 0x90]` in `.text`, non-stack, gives 227 sites; each was read by its enclosing recorded name. Positive controls: `ConsoleCmd_Nukes`, the monthly add and the mission's two are all among them. The writers on a `CCountry` are:

| site | what |
| --- | --- |
| `CCountry::CCountry` `0x4C8B09` | written once in the constructor |
| `CCountry_Reset` `0x4D2ED8` | zero with the rest of the reset (its register, unread here, is the same one that function zeroes the neighbouring fields with) |
| `CCountry::LoadKey`, the `nukes` key (token 0x577) | the save's figure |
| `CNukeChange` through `CCountry::SetNukes` (`0x588BA0`, rva 0x188BA0) | a history `nukes` entry; **absolute** (slot 7 keeps the old figure for undoing). None of the install's history files uses it (searched; the same search finds `capital` in 100 of them) |
| `CCountry::UpdateMonthly` `0x4DCB3D` | the production above |
| `ConsoleCmd_Nukes` `0x43D948` | `+= N x 1000`, no floor |
| `CNukeMission::Start` (slot 13) `0x593C10` | **`nukes -= 1000`** where it is at least 1000 |
| `~CNukeMission` (slot 0) `0x593B48` | `nukes += order +0x80 x 1000` |

The two that come from a bomb order are in section 3. The scan is complete for that shape of instruction; a write through a pointer to the field would not show (see *Not established*).

## 2. Giving the order

**Who may carry one.** Nothing in the order or its row names a wing type or a technology. What is tested, both at the row and at the order's slot 11, is **`CUnit +0xC8` (the unit's synthesised definition) `strategic_attack` (+0x17C) above nought**, so any air unit whose wings between them have strategic attack: in Their Finest Hour `strategic_bomber`, `tactical_bomber`, `naval_bomber`, `flying_bomb` and `flying_rocket` have a non-zero value in their unit files. (Files: **mod-able**.) There is no technology test beyond having bombs.

**The row** (`CAirOrdersView::BuildOrders`, rva 0x346260, `0x746760` onwards; *the row's creation* is new here, the old record's ladder did not mention it):

- It exists only where **`selection count x 1000 <= country nukes`** (hard-coded 1000, `confirmed`, at `0x74674x`), the unit's definition has `strategic_attack` above nought, and the province is land. So the row disappears where the selection has more units than bombs.
- It is built with `AddOrder` like every other row. `AddOrder` then greys it (+0x136 cleared) where, for any unit of the selection, `COrder::IsTargetInRange` fails or the order's slot 11 answers no. Range uses the unit's definition's `air_range`-ish field +0x148 from its base province; slot 11 is `CNukeMission::MayBeGiven`: the province's controller is an enemy of the unit's owner, and `strategic_attack` above nought. The stock is **not** asked at this stage (it was asked for the row to exist).
- **The row is ticked at once, by name, through the radio group** (`0xAD53E0` with EDI = view +0xD0, the string `nuke_mission`, at `0x7467B3`-`0x7467CB`) in every case except the order being kept being a usable nuke order, and **whether or not `AddOrder` let it be given**. So a row that is greyed can still be the one ticked. Because the later ladder of defaults runs only where nothing is ticked, the nuke row suppresses the ladder of default orders (`air_superiority`, `port_strike`, the strikes, ground attack): it stays ticked unless the `rebase_air` arm, which is tested first, ticks over it. (`confirmed` for the code; what the window then does with an accept on a greyed row was not followed.)
- The row's texts: **`NUKE_MISSION`** (the generic name through `OrderMissionIndexToKey`, index 26, `COrder` slot 6), tooltip **`NUKE_MISSION_DESC`** (slot 7), and in the unit panel **`NUKE_MISSION_SHORT_DESC`** with `$TYPE$` = `STRAT_BOMB_RETURNING` where `return_to_base` (+0x18) is set, `STRAT_BOMB_WAITING` where the unit stands in its base's province, `PARA_FLYING` where in no battle or bombing, `CAG_FIGHTING` otherwise (slot 15). The icon `unitstatus_nuke` (`UW_CARRYING_NUKE`) shows where the order's slot 9, **`CNukeMission::IsCarryingNuke`** (`0 < +0x80`), says so.

Accept (`CAirOrdersView::OnAccept`) posts a `CSetOrderCommand` for each air unit of the selection, as for every air order. The AI gives the same order through `CreateUnitOrder` (`AirPhase4_IssueStrategicBombOrNuke`, not re-read).

## 3. The order, hour by hour

**Taking the bomb** (`CNukeMission::Start`, slot 13, called by `CUnit::SetOrder` as the order is installed, after the old order has been destroyed - `CUnit::SetOrder`, rva 0x1CD9E0):

    if the owner's nukes >= 1000:
        +0x80 = 1;  nukes -= 1000
        CNukeMission_FlyToTarget(this)

Where the stock is under 1000 nothing happens: `+0x80` stays 0, and the next hour's `IsActive` ends the order at its first gate with nothing lost. Hard-coded: 1000, one bomb per order.

**Giving it back.** `~CNukeMission` (slot 0) does `owner nukes += +0x80 x 1000` for any deletion of the order: the unit given another order (`SetOrder` deletes the old one first, so replacing a nuke order with another nuke order gives the bomb back and takes one again), the order ended by `CUnit::CheckOrderAndCombat` when `IsActive` answers false, or **the bomber destroyed** (`CUnit::~CUnit` releases its orders - record; `CGameState::RemoveUnit` is the path). So a bomb in the air returns to the stock if the carrier is lost - nothing is destroyed. After a drop the destructor gives nothing because the drop has zeroed `+0x80`. A carried bomb survives a save (`CNukeMission::SaveContents`, `nukes`, int, `+0x80`).

**Each hour, `CNukeMission::IsActive`** (slot 14, rva 0x193C30, called by `CUnit::CheckOrderAndCombat` from the country's hourly pass; `confirmed`). It does **not** call `CAirOrder::IsActive`, so the order has no end date, no range check again and no return for fuel of its own:

    if unit has no base (+0x98)                     -> order done
    if +0x80 is 0                                    -> order done
    if the target's controller is not an enemy of the unit's owner  -> order done
    if unit in a battle or bombing (+0x11C >= 1 or +0x110 set) or has a path left (+0x140 >= 1)
                                                     -> still going, nothing else this hour
    if the unit stands in the target (+0x130 == order +0xC):  drop (section 4); order done
    otherwise:                                        CNukeMission_FlyToTarget;  still going

So the target changing hands to anyone not at war with the owner ends the order and gives the bomb back. **The order's date widgets do nothing on this order**: neither its `death_date` nor its dates are read by `IsActive`. Only `Start` and the hour are its life.

**`CNukeMission_FlyToTarget`** (rva 0x1950D0; new). With `fuel_received_percentage` (+0x100) nought: `OrderReturnToBase` and stop. Otherwise a `CPathFind::Find` from the unit's province to the target and, where found, `SetUnitPath(unit, path, clear=true)`. Then the day and night: where the order's `time` (+0x30) is 0 (day) and `IsNightAtTick(target, NextArrivalHour)` says night, or 1 (night) and it says day, the unit does not go: at its base with a path set, `CUnit::CancelMovement`; away from its base, `OrderReturnToBase`. Time 2 (both, the window's default) never stops it. Called from `Start` and from each hour's last line. An order set to return to base is therefore flown again the next time it finds itself still and away from the target; the `return_to_base` byte stays set (it only changes the status text) because nothing here clears it - that is `CAirOrder::IsActive`'s work, which this order does not call.

After a drop the unit has a fresh `CNullOrder` and stands in the target; what brings it home is the general air unit's handling in `CUnit::CheckOrderAndCombat` and `CAir::CheckBase`, not this order.

## 4. The drop (`confirmed`, `CNukeMission::IsActive`, `0x593D02` onwards)

Reached only when the unit stands in the target province with no battle, no bombing and no path, and the controller is its owner's enemy.

**1. National unity, the controller's.** Let `C` be the province's controller.

    factor = 1000
    if the province is a core of C (CProvince_IsCoreOf, province +0x344 cores list):
        factor = 1000 + province modifier IC (province +0x114, id 15, +0x78, thousandths)
        if the province is C's acting capital:
            factor = factor x 2000 / 1000     (doubled, inside the core arm only)
    amount = NUKE_UNITY_IMPACT x factor / 1000 (truncated)
    CCountry::ChangeNationalUnity(C, -amount)

`NUKE_UNITY_IMPACT` is a **define in `common/defines.lua`** (country block, `1.0`, stored as 1000 at `CDefinesCountry +0x4C`); the 1000 and 2000 are **hard-coded**. The change is through `ChangeNationalUnity`, so scaled by the controller's `national_unity_effect` and held to 1 to 100. `amount` is the message's `$IMPACT$` (one decimal), the figure before that scaling. A province not a core of its controller loses the plain impact; a province that is a core adds 1 for each unit of its IC modifier, and the acting capital doubles the whole. *This corrects "the province holds something" in the record's comment and sharpens `FINDINGS-onactions.md` 2.4's "doubled at the acting capital": the capital test is reached only for a core.* `FINDINGS-government.md`'s statement ("one of the controller's cores") is right.

**2. Buildings.** Every building type (each of `GetBuildingDataBase`'s, by its index, through `CMapProvince +0x310[index]`) gets `CProvinceBuilding_Damage(10000000)`. That subtracts 10000 levels' worth (thousandths) from the *current* level (`+0x24`), floored at nought, with the `changed` flag set. **So every building goes to current level 0, and its maximum level (`+0x20`) is left**, which is what the daily repair then rebuilds toward. Hard-coded: 10,000,000. All buildings, every kind, with no test: the reactor, the rocket test site and the underground too. **The province's modifiers are not rebuilt here**, so the province's IC, infrastructure and so on are stale until something else rebuilds them (a building repaired across a level, a capture, the hour's look at a moved building - see the mechanics specs on when a province is made again).

**3. The province's goods.** `CGoodsPool_Clear` on the province's **`pool` (`+0x15C`) and `current_producing` (`+0x268`)**: the seven goods of each set to the zero fixed point. Hard-coded. The first is what lies in the province - **in a capital, the national stockpile**. (The second is the province's own yield figures, which the daily rebuild refills.)

**4. Every unit in the province** (`CMapProvince +0x2B8`, every owner: the bomber's country and its friends too; fleets in port are on this list and on the port's). The list is walked once:

    skip the bomber itself
    skip an air unit that is not at its own base (CUnit_IsAtOwnBase)
    land unit:
        R = RandomThousandths()                  ; 0..999, the game's own generator, one draw for the unit
        D = (670 + R x 1000 / 3000) x GetTotalMaxStrength / 1000
        CUnit::TakeDamage(unit, D, 10000000)     ; strength shared by each brigade's max strength,
                                                 ; organisation in equal parts over the brigades
    fleet or air unit:
        for each ship or wing, its own R:
            D = (670 + R x 1000 / 3000) x GetMaxStrength(0, 0) / 1000
            pending_strength_damage (+0xA8) += D
            pending_organisation_damage (+0xAC) += 10000000
    CUnit::SettleCombatDamage(unit, ..., 0)      ; the same routine a battle uses; arg 0, no war ledger

`670` is `(int)floor(670.5f)` from the float at `0x160AAF0`; 1000, 3000 and 10,000,000 are all **hard-coded**. `R x 1000 / 3000` is R / 3, so the strength factor runs 670 to 1003 thousandths of the maximum; the one above 1000 is a rounding effect and is capped when the damage is spent. `TakeDamage` shares the land unit's organisation in equal parts of `1000/n` (truncated per brigade, n brigades).

**What this means after settlement** (`CSubUnit::SettleDamage`, rva 0x1ABA60, `confirmed`). For a brigade (slot 9) or a wing (slot 11) both pending figures are first multiplied by `g_CombatModifierFloor` (10) / 1000, that is **divided by 100**; ships are taken whole; and each figure is capped at what the sub unit has. So:

| | strength lost | organisation lost |
| --- | --- | --- |
| a brigade | ~0.67% to 1.00% of its maximum (e.g. 0.20 to 0.30 of a 30-strength brigade) | 100/n organisation points (n brigades in the unit, capped at what it has): all of a lone brigade, a third of 100 for a three-brigade division |
| a wing | ~0.67% to 1.00% of its maximum | 100 points, so all of it |
| a ship | 67% to 100% of its maximum (floored at what it has), so usually crippled or sunk | all of it |

Which is why a nuke's text speaks of industry and unity: land units and air units on the ground lose almost nothing in strength. **This is what the bytes do**, confirmed as far as the reading goes; no save holds a nuke and the number has not been seen in play (see *Not established*). The losses run through the usual `SettleCombatDamage`, so the same casualty trickleback and officer charge as a battle apply (`CUnit::SettleCombatDamage` record).

**5. Spent sub-units.** `CUnitList::RemoveSpentSubUnits(province units, false)`, the same removal a battle uses.

**6. Messages, for the local player only**, in this order of test. Variables: `PROV` (the province's name), `IMPACT` (`amount`, one decimal), `EVIL` (the bomber's owner's name), `TARGET` (the controller's name), `TITLE` (the ruler title). Types, by `interface/messagetypes.txt`:

| the player is | type | tags given |
| --- | --- | --- |
| the controller | `NUKE_ON_US` | province owner, bomber's owner |
| the bomber's owner | `WE_NUKE` | province owner, controller |
| anyone else | `NUKE_ON_OTHER` | province owner, controller |

All three: `log = yes`, `onmap = yes`, `popup = yes`, `pausepopup = no`, category `cat_combat` (`interface/messagetypes.txt`, **mod-able** in that file). Goto-screen button per `FINDINGS-messagegoto.md`.

**7. `on_nuke_dropped`.** Through `FireOnAction` (VA `0x594A91`), the scope built with `CEventScope(0, 0)` and **seed 0**: `country` = the bomber's owner (`CUnit +0x124/+0x128`), `FROM` = the province's controller (`+0x334/+0x338`), `province` = the target (`+0xD0`), no combatant. The file's own comment (`common/on_actions.txt`) has this right.

**8.** `+0x80 = 0` (so the destructor gives nothing back) and `IsActive` answers false, ending the order.

**Nothing else.** No population, manpower, leadership, IC (beyond the buildings), resources beyond the two pools, revolt risk, dissent, relations, or threat. Search: the whole function body read, decompiled and in the listing; a mention of any such store would be a named field or a call. The "radiation" of the original game's lore is not a mechanic here.

**Oddities to keep as read**: a nuke hits every owner's units including the bomber's friends and its own; only the bomber and air units away from their base are spared; `amount` in the messages is before scaling; the row ticks when greyed; brigades and wings take a hundredth of the strength damage ships do.

## 5. `province_event` and `country_event`

Both build the same `CEvent` (0x174 bytes). **The only difference in the file is the list**: country events go to the event list's `+0x00`, province events to `+0x10` (`LoadEventFile`, `FINDINGS-eventfiles.md`). Everything else depends on the *scope* an event is fired in.

**On the on_action path** (`FireOnAction`, `OnAction_PickEvent`): `OnAction_PickEvent` walks the on_action's entries in file order, resolves each id with `FindPersistentByIdPair(0x28, id)` - country and province events alike - and returns the **first whose `trigger` holds in the scope** (the weight in `10 = 18050` is never read). `FireEvent` then runs it. The kind is not consulted anywhere on this path. In `on_nuke_dropped`:

- **who answers**: the scope's `country_id` is the bomber's owner (non-zero), so the bomber's owner answers and not the province's owner - `FireEvent`'s province fall-back only applies where the scope's country is nought. `FROM` is the controller, `province` the target.
- **which window**: `CEventWindow` chooses the province window (`Event_Province_Window`, `EventPOptionButton`) because the *scope* has a province (`scope.province >= 1`, `FINDINGS-eventfire.md` section 3); the event's kind does not enter into it. So the player gets a province-shaped window for a `province_event` *or* a `country_event` fired in this scope.
- **`major`** (`CEvent +0x171`): chooses the message family (`MAJOREVENTHAPPENOTHER` and the like) when the answer is reported (`CSelectEventOptionCommand::Execute`), and that is all. 18050's `major = yes` does nothing on the firing itself.
- **`is_triggered_only`** (`+0x170`): not read by `FireEvent`, `OnAction_PickEvent` or the window. It is for the mean-time pass. On this path it has no effect.
- **The file's choice**: on `on_nuke_dropped` the first entry whose trigger holds. 18050 first (`NOT = { has_global_flag = first_nuke }`, its option sets the flag - so **the first nuke of the world**); after that the bomber's tag picks 18051 to 18055 in file order. Their options give `national_unity = 5` to the **bomber's** country: dropping a nuke is a unity gain for the dropper in the base game.

**In general**: `country_event = id` (effect, `CCountryEventEffect::Execute`) fires in a scope of the current country, FROM the parent's `this_scope`; `province_event = id` (`CProvinceEventEffect::Execute`) fires in a scope of country `---`, the scope's province, FROM the parent's `this_scope`, and **its answerer is the province's owner**, because the scope's country is 0 (`FINDINGS-eventfire.md`). Either effect resolves the id regardless of the event's kind: a `country_event = <province event's id>` fires it in a country scope. `province_event` also runs the same two steps of the parent's scope generator before the lookup even when nothing fires.

**Whether a `province_event` can fire by mean time**: no path to it is known, `inferred` with a positive control (`FINDINGS-eventfire.md` section 1.6): `RebuildCountryEventCandidates` walks only the list at `+0x00`; of 19 references to the global event list (`0x1B15670`, re-counted for this file: 19) and 18 callers of `GetEventList`, none walks `+0x10` but the console's `event` command. The 19 references, and the known `+0x00` walker found through them, are the positive control. A province event with no MTTH trigger path is reachable only by an effect or an on_action, as here.

`tfh/events/nuke_events.txt` and `tfh/common/on_actions.txt` are **files, mod-able**, and all the choice of events and what they do lives there.

## Not established

1. **A bomb's effect in play was not measured.** No save holds a nuke, and no game was run. The numbers are the listing's. The maintainer confirmed the scale from having seen a bomb land in the original, 2026-11-09: a brigade loses about a hundredth of its strength and most of its organisation, and ships are usually sunk. The exact figures rest on `CSubUnit::SettleDamage`'s record and bytes (`0x5ABA86`).
2. **The ticked-but-greyed row**: read for the code that ticks; what a press of `accept` on a greyed ticked row does was not followed (`OnAccept` itself checks only the selection's slot 24 and 12, not read further).
3. **`CCountry::SetNukes` and `GetNukes` as the country's** are `inferred`: each is a tiny body with two callers, all on a country. A fold with another class's `+0x90` accessor would not be visible from the callers; nothing in the tables holds them.
4. **A write to `+0x90` through a pointer to the field** would not show in the store scan (`[reg+0x90]` only). Two reads of the field's use (`CProductionView::Update`, `CProductionView::BuildTooltip`) go through the stock; no third writer is known. Search: 227 non-stack stores of displacement `0x90` in `.text` read by hand against the recorded function names; controls `ConsoleCmd_Nukes`, `UpdateMonthly` and the mission's two all among them.
5. **`0xAD53E0`** is named here only as "the radio group's tick by name" (its +0x94 write, the ticked name at `CAirOrdersView +0x164`, is read); its full body was not.
6. **`0xF0270`** (the call in `UpdateMonthly` just before the production) was not read; the production has no dependency on it that was seen.
7. **Why `CProvinceBuilding_Damage`'s province modifiers are not rebuilt at once** is not known; the absence was read in the body of this function only (its direct calls are the ones listed; the rebuild is elsewhere, and whether anything triggers one on a `changed` building sooner was not followed beyond what the specs on province rebuild schedules say).
8. **What the AI does with `IsActive` answering false** beyond the general `CUnit::CheckOrderAndCombat` was not traced; the AI's issuing and its one-token-per-pass quirk are `FINDINGS-airnaval4.md`'s.
