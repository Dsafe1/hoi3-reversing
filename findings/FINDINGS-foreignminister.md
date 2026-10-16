# The foreign minister's day: decisions and prepared wars

Read 2026-10-16 for OpenHOI3's stage 5 (the AI taking decisions), in the collecting session, off the bytes of
`hoi3_tfh.exe` (TFH 4.02). Addresses are rvas unless marked VA. Builds on `FINDINGS-eventfire.md` section 2.4 (the
decisions pass, first read 2026-10-12), `FINDINGS-ai.md` (the ministers' objects and hours) and `FINDINGS-ministers.md`
(the shared Enable and its countdown).

**Mod-able or exe-hardcoded.** Which decisions the AI takes, and when, is the install's Lua
(`ForeignMinister_EvaluateDecision` and a country file's override) and so mod-able; so is whether a decision is tied to a
prepared war (`PrepareWarDecision`). Everything below the Lua - when the pass runs, the scope it is asked in, the walk of
prepared wars, the readiness test with its 99%, 30%, three months and 0.66, the pruning with its 100 IC and its one and
three months, Japan's exception and the three special war goals - is **exe-hardcoded**: no define reaches any of it.

## A. The day, in order: `CAIForeignMinister::DoWork` (slot 10, `0x49D600`)

Entered every AI pass, since it sets its countdown (`+0x30`) to 1. Then:

1. A skip-once byte `+0x70`: when set, cleared and nothing more (who sets it was not traced).
2. The hour gate: `(country id (+0x38) + 13) % 24 == (tick - 43800000) % 24`. Outside it, nothing.
3. `CAIForeignMinister::AnswerPendingOffers` (`0x49E010`, `FINDINGS-agreements.md` A2).
4. **`ForeignMinister_Tick(minister)`** in the thread's Lua state (`Lua_ForeignMinister_Tick`, then the proxy's call
   `0x49E530`, the same shape as `LuaEvaluateDecision_Release`); a `luabind::error` is caught and reported
   (`ReportLuaError`) and the day goes on. Every shipped `ForeignMinister_Tick` calls `minister:ExecuteDiploDecisions()`
   first (section B).
5. **The cached proposal**: where `+0x58` holds an action and its score `+0x5C` is above 50.0 (the double at VA
   `0x160A4C8`), `CEU3AI::PostAction(OwnerAI, action)`; then the action is released, `+0x58 = 0`, `+0x5C = -1.0f`.
   (`Propose` from the Lua fills it; not read further.)
6. **The pruning of prepared wars** (section C.3), only where the country is a major (`is_major`, `+0x15C`) or its
   `max_ic` (`+0x60C`, whole IC) is above 100.
7. **The walk of prepared wars** (section D).

## B. The decisions pass: `CAIForeignMinister::ExecuteDiploDecisions` (`0x49DD50`)

As `FINDINGS-eventfire.md` 2.4 has it, which stands: one `CEventScope` - the minister's country, FROM `---`, province
0, and its random state, the state's copy and its seed all one `MT19937Next` draw on the game's own generator (gamestate
`+0x124`) - then the **diplomatic** decisions in file order: `potential`, and where it holds `allow`, both in that one
scope, the scope **not** reset between decisions; for each that passes both,
`ForeignMinister_EvaluateDecision(minister, decision, scope)`, and an answer above 0 posts the decision with
`PostExecuteDecisionCommand(&scope, decision)`. **The answer goes through the Lua DLL's `lua_tointeger`** (the import at
VA `0xD2B4D4`, called at VA `0x89E6F6` in `LuaEvaluateDecision_CallInt` after `lua_type` at VA `0x89E6BA` answers 3),
which is `fld; fistp` (`FINDINGS-luahost.md`): **to the nearest, ties to even** - a score of 0.5 is 0 and 1.5 is 2.
*Corrected*: `LuaEvaluateDecision_CallInt`'s record and `FINDINGS-eventfire.md` 2.4 said a fraction is cut. Every
shipped score is a whole number, so nothing turns on it.

The Lua is handed `CDecision`, whose methods are `GetKey` (a `CString`, its name: the folded `GetKey` at `0x131190`
answers `this + 8`), `IsPotential(scope)` and `IsAllowed(scope)` (`0x598940`, `0x598950`: the block's `Evaluate` in the
scope handed, nothing else).

## C. Prepared wars: the war targets

### C.1 The list

`CAIStrategy +0x148` `WarTargets`, a `CList<CCountryWarTargetValue*>` (first, last, count `+0x150`, deferred-delete flag
`+0x154`). `CCountry +0x5D4` is the same list's head through the country's strategy (`+0x48C`). An entry is 0x20 bytes:
target `+0x8`/`+0xC`, `value` `+0x10` (float), `limited` `+0x14`, `decision` `+0x18`, `date` `+0x1C` (the tick it was
made). Saved and loaded with the strategy (`CCountryWarTargetValue::LoadKey`; `FINDINGS-eventfire.md`).

### C.2 The Lua's methods (`CAIStrategy`)

- **`PrepareWarDecision(tag, value, decision, limited)`** (`0x4AD4D0`). Does nothing where the target is the null tag,
  owns no province, or is this country's puppet (its overlord is this country), or where this country's faction is a
  real one (slot 7) and the target's faction is the same. Otherwise: the first entry for that target; **where there is
  none, a new one at the end of the list holding the target, the decision, `limited` and today's tick**, and the
  strategy's byte `+0xF4` set where the target is a neighbour (`CCountry +0xF58`; its reader was not traced). **Then the
  entry's `value` is set** - so for an entry that was already there only the value changes; its decision, `limited` and
  date stay the first call's.
- **`PrepareWar(tag, value)`** and **`PrepareLimitedWar(tag, value)`** (`0x4AD470`, `0x4AD4A0`): `PrepareWarDecision`
  with no decision and `limited` false or true.
- **`CancelPrepareWar(tag)`** (`0x4AD650`): the first entry for that target taken off and deleted, and `+0xF4` set where
  it is a neighbour.
- **`GetWarTarget(tag)`** (`0x4ADEC0`): the first entry for that target, or nil.
- **`IsPreparingWar()`** (`0x4ADD50`): whether any entry's target owns a province or is in exile, is not this country's
  puppet, and is not in this country's real faction.
- **`IsPreparingWarWith(tag)`** (`0x4ADE10`): false where this country is at war with it (`CCountry::IsEnemy`), or it
  owns no province, or it is in exile; otherwise whether an entry has that target.

In Their Finest Hour `PrepareWarDecision` is called only from four countries' `ForeignMinister_EvaluateDecision`
overrides, each answering 0 for the decision itself: Germany's `danzig_or_war` (Poland, from August 1939), Italy's
`annexation_of_albania` (Albania) and `the_future_of_greece` (Greece, once Vichy exists, or one time in ten once France
has lost Paris), and Japan's `marco_polo_bridge_incident` (Shanxi and China). `PrepareWar` is called from the
`ForeignMinister_ProposeWar` of Britain, Italy and the United States; `IsPreparingWar(With)` from the politics
minister (`ai_politics_minister.lua`) and the foreign minister's own scripts.

### C.3 The pruning (`CAIStrategy_PruneWarTargets`, `0x4AD9B0`)

Step 6 of the day, `ret 4`, the strategy on the stack. A target's **month** is `years x 12 + month`, worked from a tick
as `DoWork`'s day of the month is (`FINDINGS-ministers.md` A.1). Then:

1. Walk the list; for every target that is a major or has `max_ic` above 100, remember it and its date's month - so it
   is **the last such target in the list** that counts. None: stop.
2. Walk the list again; for every other target that is neither a major nor above 100 IC, where
   `majorMonth - itsMonth > 1` **or** `thisMonth - itsMonth > 3`: the entry is taken off (deferred while the list is
   being walked, `+0x154`; else unlinked, freed and the count lowered), deleted, and `+0xF4` set where it is a
   neighbour. The walk goes on.

So a country preparing war on a great power drops the small targets it prepared more than a month before that one, and
any small target older than three months - but **only while it has a great target**: with only small ones nothing is
dropped. *Corrected*: the decompiler shows a `return` after the unlink, which is not in the listing - the count is
lowered (`dec [edi+0x150]` at VA `0x8ADCEF`) and the walk continues.

## D. The walk after the Lua (`DoWork`, VA `0x89D742`-`0x89DCCF`)

**The first walk**, over the list in order, a flag "a neighbour is unready" clear:

1. Where this country's diplomacy status towards the target has military access (`+0x4C`, this country may enter the
   target's land): a **`CMilitaryAccessAction` from this country to the target with value 0** (the constructor at
   `0x6230D0` sets value 1; `DoWork` clears it at VA `0x89D7E7`) is made into a command and posted - giving the access
   up, which the asker's arm of that action does (`FINDINGS-agreements.md` C.4) - and **the day ends there**.
2. Where the target is a neighbour (`CCountry +0xF58`): the readiness test (section E). Ready: on to the second walk at
   once. Not ready: the flag is set and the walk goes on.

At the end of the first walk, with the flag set, the day ends.

**The second walk**, over the whole list from the start, each target put to the readiness test; for one that is ready:

- **with a decision**: a fresh `CEventScope` (`CEventScope::CEventScope`, seeded with one `MT19937Next` draw on the
  game's generator, the country the minister's), its `potential` then its `allow`; where both hold,
  `PostExecuteDecisionCommand` - **no Lua score**.
- **without one**: a `CDeclareWarAction` (constructor VA `0xA11DF0`, vftable `0x15FB3F4`) from this country to the
  target, a limited war (its `+0x24` cleared) where the entry is `limited` or the country's faction rule `limited_war`
  (`+0xDDC`) holds, with the war goal `conquer` (`CWarGoal_Make`). For three pairs the goal is first another: Germany on
  France **`vichy_war_goal`**, Germany on the Soviet Union **`barbarossa_war_goal`**, Japan on the United States
  **`japan_USA_goal`**; where `CDeclareWarAction::IsSelectable` and that goal's `CWarGoal::IsValidWithTrigger` both hold
  it is posted, and otherwise the action is made again with `conquer` and posted where `IsSelectable` holds. A plain
  target goes the same way with `conquer` first. Everything is posted as a command
  (`CDiplomaticAction::MakeCommand`).

A target stays on the list after its decision or its war is posted; nothing in `DoWork` takes it off.

## E. The readiness test (`CAIStrategy_IsReadyForWar`, `0x4ADEF0`)

`bool __stdcall (strategy, target tag, entry)`, `ret 0x10`. **It counts the fronts the theatre layer draws**: an area's
`fronts` (`COwnerArea +0x74`, `CAreaBorder` lists, made by `CAIStrategy::BuildTheatres` - `FINDINGS-aiplans.md`,
`FINDINGS-supplynetwork.md`). For each area of this country (`CCountry +0xD30`) that has a neighbouring area whose first
province the target controls - once per area, however many such neighbours - for every front of that area and every
province on it that is in a real area:

- every edge but an impassable one (kind 3) to a province that is simulated, controlled by the target and in a real
  area: that province is **an enemy province**, and the first time it is met (a list kept for the call) the strength of
  its land units (`0x1D64F0`: for each unit whose slot 15, `IsLand`, holds, its brigades' `+0x5C` summed) is added to
  **the enemy's strength**;
- where the province has any such edge it is **a front province**: count it, and add the strength of each of this
  country's land units standing in it that is not in a battle's cool-down (`+0xD4 <= 0`) and whose average strength
  and organisation, as shares of their most in thousandths (`0x1C70E0`), are **both at least 990** - the static at VA
  `0x1B15020`, `floor(990.5f)`. A front province with none is **an empty front province**. Their sum is **our
  strength**. A province on two fronts is counted twice.

Then, by the entry's date (`+0x1C`):

- **three months or more since it was prepared**: the enemy's strength `x 660 / 1000` (`floor(660.5f)` at VA
  `0x160A654`; 64-bit, cut towards nought). And **where the country is Japan** (the country database's fifth cached tag,
  `+0x20`/`+0x24`) **and it has fewer than four front provinces: ready**, whatever else.
- under three months: the code adds three months more and scales by 330 (`floor(330.5f)`, VA `0x160A6E0`) where that
  date has passed - **which it never has**, the first test having found three months not passed: dead code.

Then: where there are front provinces and empty ones `x 1000 / all of them` (thousandths) is **above 300** (the static
at VA `0x1B1502C`, `floor(300.5f)`): not ready. Otherwise **ready where the enemy's strength is no more than ours**.

With no front facing the target at all - a target not across a land border from any area of this country, as Albania
is from Italy - every count is nought and the test answers ready, three months or not; but the first walk asks it only
of neighbours, and the second walk asks it of every target once no neighbour is unready.

## F. What looks wrong and is what the bytes do

1. An AI that holds transit rights into a country it prepares war on gives them up and does nothing else that day - in
   the order of its list, before any target is looked at further.
2. `PrepareWarDecision` on a target already listed changes only the value: a decision tied to it later is not kept.
3. The 330 branch of the readiness test cannot be reached.
4. Japan alone is ready on a short front after three months, by a cached tag.
5. A province on two fronts counts twice towards both the front and our strength; an enemy province once.
6. The pruning keeps every small target while no great one is listed, however old.
7. Nothing takes a target off once its war has begun or its decision has been taken.

## G. Corrections to the record

- `LuaEvaluateDecision_CallInt` (`0x49E630`) and `FINDINGS-eventfire.md` 2.4: the score is rounded to the nearest, not
  cut (section B).
- `CAIForeignMinister::DoWork` (`0x49D600`): "filters the list at `country+0x5D4` by neighbours" was the first walk of
  section D, and "a target without a decision goes to 0x49D967, not read" is the declaration of section D, now read; the
  pruning (step 6) was not in its account.

## H. Not established

- ~~Who sets the skip-once byte `+0x70`~~ - the constructor (section I); who reads the strategy's `+0xF4`.
- ~~What `Propose` puts at `+0x58`; `ForeignMinister_Tick`'s other calls~~ - section I.

## I. The rest of the tick: what it reaches (read 2026-10-16, second pass)

For the whole foreign minister in OpenHOI3. `ForeignMinister_Tick` (Their Finest Hour's `ai_foreign_minister.lua`, with
`ai_diplomacy.lua`, `ai_support_functions.lua` and the countries' `ForeignMinister_*` overrides) reaches 84 script
functions; every engine method at the end of them is in the record, these read for it. **All mod-able in their use, and
exe-hardcoded in what they answer.**

**The minister** (`CAIForeignMinister`, 0x74 bytes):

- **The constructor** (`0x49D2E0`) leaves the cached proposal null at `+0x58` with score `+0x5C` 0.0, `+0x60` -1, the
  proposed war `---` (`+0x64`/`+0x68`) with score `+0x6C` 0.0, and **the skip-once byte `+0x70` at 1** - so the first
  time `DoWork` is entered it only clears it. *Corrected*: the record stopped at `+0x64`.
- **`Propose(action, score)`** (`0x49DCF0`): where the score is **strictly above** the cached one and the action's slot 14
  holds, the cached action is deleted and a clone of this one cached with its score. `DoWork` step 5 posts it where its
  score is above 50.0 and sets the score to -1.0. So the day's best selectable proposal goes out - one a day at most -
  and **one at 50 or under stays cached**, posted on no day, until a higher one replaces it; the first after a post need
  only beat -1.
- **`ProposeWar(tag, score)`** (`0x49E420`): kept where the score beats the kept one by more than 40.0;
  **`ClearWarProposal()`** (`0x49E460`) puts back `---` and 0; `GetProposedWarTarget()` answers the tag. Nothing in the
  engine was found to read them, and no shipped script calls any.
- **`PercOccupied(tag)`** (`0x49E280`): 0 where it owns no province; else of the provinces it owns, the share it does
  not control, `x 100.0` over the count in double precision, made a float and rounded to the nearest (`fistp`).
- **`ForeignMinister_OnWar(minister, tag, tag, war)`**: for every new pair at war - a joiner and each country on the
  other side, as `CWar::AddAttacker`/`AddDefender` set them - every foreign minister is told
  (`BroadcastToListeners2` channel 0x15, slot 41; `FINDINGS-war.md`, *the AI's broadcast*). Empty in every shipped
  script.

**`CDiplomaticAction`**: the eleven `Create` constructors (`FINDINGS-diploaction.md`) and the lend-lease pair's folded
one (`0x4E8270`, `COfferLendLeaseAction` and `CRequestLendLeaseAction`) make an action proposed, value 1, dated now; the
call to arms takes a third tag. **`IsSelectable` from Lua is each kind's own slot 14**: luabind registered a vcall thunk
(`0xA788D0`), and the base's body (`0x60EAE0`, actor != recipient) is only what a kind that does not override it gets.
`CEU3AI::PostAction` posts any of them as a command, no gate of its own.

**What the scripts ask**:

| method | rva | answers |
| --- | --- | --- |
| `CWar:IsLimited()` | `0x651FA0` | the war's limited byte |
| `CDiplomacyStatus:HasEmbargo()` | `0x64A740` | an embargo between the two, either way |
| `CDiplomacyStatus:IsBeingInfluenced()` | `0x64A720` | `influence_running` - on the influenced country's status towards the influencer |
| `CAIStrategy:GetProtectionism(tag)` | `0x4A4E90` | the `protect` hash's value, 0 where absent |
| `CCountry:IsNeighbour(tag)` | `0xC86C0` | the neighbours byte (`+0xF58`) |
| `CCountry:GetControllerNeighbours()` | `0x487F30` | the `ControllerNeighbours` list (`+0xFE8`) |
| `CCountry:HasNeighborInFaction(f)` | `0x107990` | a real faction with members, and some country of `Neighbours` in it |
| `CCountry:HasActiveLendLeaseFrom(tag)` | `0x1089C0` | the giver's distributions name this country |
| `CCountry:IsGivingLendLeaseToTarget(tag)` | `0x1085E0` | this country's distributions name that one |

`GetAllies` and `GetVassals` were recorded (`+0xF88`, `+0xF78`, filled by `RebuildNeighbours`).
- `CDeclareWarAction`'s constructor (VA `0xA11DF0`) and the goal copy (VA `0x477210`) were read only as far as section D
  needs.

## Trap check

- Trap 1: every address above was taken from a listing printed by `disasm.py` with both forms shown; `0x4ADEF0` is the
  rva of VA `0x8ADEF0`.
- Trap 2: the readiness test ends `ret 0x10` at VA `0x8AE495`/`0x8AE4D5` with more after; the pruning `ret 4` at VA
  `0x8ADD3F`, int3 to `0x8ADD4F`, `IsPreparingWar` at `0x8ADD50`.
