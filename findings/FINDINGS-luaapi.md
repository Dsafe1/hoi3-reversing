# The Lua API the AI's answers to offers are made with

Read out of the executable on 2026-10-13, for OpenHOI3's Lua piece: the AI's answer to a
diplomatic offer is a `DiploScore_*` function of the install's Lua (`FINDINGS-diplomacy.md`,
`FINDINGS-survivors.md`), and this is what those functions are handed, what they reach of the
engine's API, and what each part of it answers. Addresses are **virtual**, based `0x400000`,
unless a line says rva. The host itself - the state, `require`, the x87 - is
`FINDINGS-luahost.md`.

## In one line

The bridge calls the function with the recipient's AI and three **fresh copies** of the tags,
turns a number into an integer to the nearest, and **answers 0 when the call fails** (a Lua error,
or no such function); a result that is not a number escapes as `cast_failed`. Across the 58 files
`autoexec.lua` loads, `SpyMission` is the only engine global any file reads as it is loaded; the
fourteen functions the engine calls reach 92 Lua functions, 76 engine methods, 6 static functions
and 2 constructors. **`CFixedPoint:Get()` is a single-precision float**; the arithmetic with a plain
number on the left comes out **reversed** for `-` and `/`; a `return_clausewitz_iterator` walks
its container in storage order and **stops at the first null element** of an array.

## 1. The bridge's call and its failure

`GetDiploScoreFromLua` (rva `0x60DC70`) and its five name-baked clones (`FINDINGS-survivors.md`,
section 1) end the same way:

1. the AI handed to the script is the **recipient's** `CEU3AI` (`CCountry +0x1D8`), else the
   actor's, else the third argument's - read at `0xA0DD39`..`0xA0DD70`;
2. `LuaPushArgs_AiAndThreeTags` (rva `0x644CE0`) pushes it as an instance of its most derived class
   (`__RTDynamicCast` at `0xA44D09`, then the instance push), or **nil** where the pointer is null,
   and then **each tag as a fresh heap copy** through `LuaPush_CCountryTagByValue` (rva `0x1137C0`)
   at `0xA44D2F`, `0xA44D39`, `0xA44D43` - so a script holding a tag holds its own;
3. `LuaCallProxy_CallIntResult` (rva `0x644080`, `ret 4`) sets the proxy's called flag, pushes the
   arguments and calls the proxy's `+8` - `luabind::detail::pcall` - with **four arguments and one
   result**; a non-zero status throws `luabind::error`; the result must be `lua_type == 3`
   (`LUA_TNUMBER`) or `luabind::cast_failed` is thrown; otherwise it is `lua_tointeger` - **to the
   nearest, ties to even**, the same conversion as the new game's relation (`FINDINGS-luahost.md`,
   section 3) - and the stack is put back.

**The bridge catches `luabind::error` and answers 0.** `ehcatches.py 0xA0DC70` lists one try,
catching `.?AVerror@luabind@@`; the handler at `0xA0DDBE` hands the error's state to
`ReportLuaError` (rva `0x6A8050`) - `LUA Error: <message>` in the log - and resumes at `0xA0DDCF`,
`xor eax, eax`. So a script that raises an error, or a function that does not exist (calling nil is
a Lua error), gives **0**: the offer is refused. `cast_failed` is not a `luabind::error` and is not
caught here, as in `FINDINGS-luahost.md`; where it ends was not read.

**The four-argument bridge passes four.** Three of the functions it calls declare a fifth parameter
- `DiploScore_PeaceAction`, `DiploScore_SendExpeditionaryForce` and
`DiploScore_OfferMilitaryAccess`, each `(voAI, voActorTag, voRecipientTag, voObserverTag,
action)` - which is therefore always **nil**. None of the three reads it, so nothing breaks.

## 2. What the scripts reach

Found from the install's Lua, not the bytes: `luac -p -l` over each file `autoexec.lua` loads,
following `require` into the files that require others (`ai_foreign_minister.lua` requires
`ai_diplomacy.lua`), for the globals each main chunk reads as it is loaded; then a text call graph
from the fourteen functions the engine calls, following `Utils.CallGetScoreAI`,
`CallScoredCountryAI` and their kin into every `AI_<TAG>` module that defines the named function.
The scripts are TFH's, over the base game's `ai_country.lua`.

- **Loading**: only `ai_intelligence_minister.lua` reads an engine global at its top -
  `SpyMission`, an enum (`luabind.json`, `enum_types`). Everything else an engine name appears in is
  inside a function. So the whole of `autoexec.lua` loads given that one enum.
- **The fourteen**: 92 Lua functions in all, 49 of them countries' own overrides; 76 engine method
  names; the static functions `CCurrentGameState.GetFaction`, `.GetFactions`, `.GetProvince`,
  `.GetCurrentDate`, `.IsPlayer` and `CCountryDataBase.GetTag`; the constructors `CAIIntel(tag,
  tag)` and `CResourceValues()`; the constants `CGoodsPool._SUPPLIES_` .. `_RARE_MATERIALS_` and
  `CModifier._MODIFIER_GLOBAL_IC_`.
- **By what they are handed**: eleven take nothing but tags, or an action they never read -
  `Alliance`, `Debt`, `InviteToFaction`, `DemandMilitaryAccess`, `NonAgression`, `OfferLendLease`,
  `OfferMilitaryAccess`, `PeaceAction`, `SendExpeditionaryForce`, `CallAlly`, `RequestLendLease`.
  Three read the object they are handed: `JoinFactionGoal` the war goal, `LicenceTechnology` the
  licence action (`GetMoney`, `GetSerial`, `GetSubunit`, `GetParalell`), `OfferTrade` the trade
  action and its two blocks.

`Utils.LUA_DEBUGOUT` writes `lua_output.txt` beside the game whenever it is called; every call of
it in the fourteen's reach is commented out.

## 3. `CFixedPoint` in Lua

A `CFixedPoint` is handed over as an object, never as a number.

- **`Get()`** (rva `0x2040`): `fild dword [ecx]; fdiv qword [1000.0]; fstp dword` - the
  thousandths divided by 1000 and **rounded to a single-precision float**, which luabind pushes as a
  Lua number. So `0.1` reads as `0.100000001490116...`.
- **`GetTruncated()`** (rva `0x17970`): thousandths / 1000, toward nought.
- **Two `CFixedPoint`s**: `+` and `-` on the thousandths; `*` is `a * b / 1000` in 64 bits toward
  nought; `/` is `a * 1000 / b` (in 32 bits where `a * 1000` fits, else 64 - the same answer), and
  **dividing by nought gives -1 thousandth**, no error (`0x9039A0`). `==`, `<`, `<=` compare the
  thousandths. Each arithmetic result is a new `CFixedPoint`.
- **A number with it**: luabind turns the number into a `float`, and the float into thousandths as
  `fx(f) = floor((float)((float)(f + 0.0005) * 1000))` - in SSE, each step rounded back to single
  precision (`0x9021E8`..`0x902213`; `0.0005` is the double at `0x160A460`, the float `0.0005`
  widened). With the object on the left, `fp + n`, `fp - n`, `fp * n` (`fx * fp / 1000`), `fp / n`
  (`fp * 1000 / fx`, by nought -1) are `CFixedPoint`s.
- **A number on the left answers a number, and two of them backwards**: `n + fp` is
  `(float)((fx + fp) / 1000)`, but **`n - fp` is `(fp - fx) / 1000`** (`0x90251F`: `[fp] - eax`)
  and **`n / fp` is `fp * 1000 / fx`, over 1000** (`0x8EAB12`..`0x8EAB2C`: the object's thousandths
  over the number's) - the object's value minus or over the number's, each rounded to a float
  (`0x4C8A10` pushes it). `n * fp` is `fx * fp / 1000`. A number of nought on the right of a
  division gives -1 thousandth.
- **A comparison with a plain number never runs.** luabind registers `==`, `<`, `<=` against a
  float both ways round, but Lua 5.1 calls `__eq` only between two values of one type and raises
  "attempt to compare" for `<` and `<=` between a number and a userdata - so `fp == 0.5` is plain
  `false` and `fp < 0.5` is an error.
- `tostring` goes through a `std::stringstream` (`0x908C00`); the formatting of a `CFixedPoint` in it
  was not read.

## 4. The iterators

`return_clausewitz_iterator`, the API's own policy on 40 registrations, gives the script a closure
- `lua_pushcclosure(L, next, 1)` - over a userdata of two words: the current element and the
container. One `next` per container kind (21 of them, the pushes at `0x95D8EB`..`0x974C18`):

- **a list** (`CList`): the current node; `next` pushes the node's element and steps to the node's
  `next`, `nil` at the end. Read: `ClausewitzIterator_Next_CFactionList` (`0x98A980`, node step
  `+8`) and `ClausewitzIterator_Next_CCountryTagList` (`0x98FDA0`, node step `+0xC`, each tag pushed
  **as a fresh copy** through `LuaPush_CCountryTagByValue`).
- **an array** (`CArray`, `std::vector`): a pointer into it and the container; `next` pushes
  `*p` while `begin <= p < end` and steps 4. An element that is a **null pointer is pushed as nil**
  and the pointer still steps - but Lua's generic `for` stops at the first nil, so **a loop over an
  array ends at its first null entry**. Read: `ClausewitzIterator_Next_CDiplomacyStatusArray`
  (`0x98FE90`) and `ClausewitzIterator_Next_CCountryArray` (`0x98A8E0`).

The order is the container's: `GetDiplomacy()` is `CCountry +0xE28`, **one status per country id,
from 0 up** - the null country `---` and the country itself included, which is why the scripts test
`GetTarget():IsValid()`; `GetCurrentAtWarWith()` and `GetNeighbours()` are tag lists
(`CCountryList`) in the order they were built; `CCurrentGameState.GetFactions()` is the game state's
faction list (`+0xCE4`).

## 5. Equality, text and the null faction

- `CCountryTag`: `==` compares the ids (`0x902A60`); `tostring` writes its letters through a
  `std::stringstream` (`0x902A90`, `0x908DB0`) - what `_G['AI_' .. tostring(tag)]` relies on.
- `CIdeologyGroup`: `==` compares `+0x50`, its index (`0x902C10`).
- `CContinent`: `==` compares the two continents' slot 7 strings, their names (`0x902BE0`,
  `CContinent_TagsEqual` `0x8EAB70`).
- `CString` (what `CFaction:GetTag()` answers): `tostring` its text, `==` its text.
- `CFaction`: `==` by save token (`FINDINGS-luahost.md`, section 5). **`IsValid()` is slot 7**,
  `mov al, 1; ret` in `CFaction`'s table and `xor al, al; ret` in `CNullFaction`'s - so a real
  faction answers true and the null faction, which every country outside a faction holds, false.
  `CCountry:HasFaction()` is a faction pointer that answers `IsValid`.
  `CCurrentGameState.GetFaction(name)` walks the faction list comparing names, case and all, and
  answers **the null faction** where none matches (`0x686F50`).

## 6. What each method answers

Every body read; the record names them from the registration (`luabind.json`), and these are the
readings. A `CFixedPoint` answer is thousandths.

| | answers |
| --- | --- |
| `CCountry:Exists()` | it owns a province |
| `GetActingCapitalLocation()` | the province of `+0xE24` |
| `GetPool()` | the capital province's goods pool; a government in exile's own pool (`+0x9F8`) |
| `GetDailyBalance(g)` | home production (and convoyed in, but not for supplies or fuel) + sent back + `+0xA64` + income from debt + conversion made + traded for + tribute received - (sent to - repaid away - tribute sent + usage + conversion used + convoyed out + traded away) |
| `GetDailyExpense(g)` | traded away - tribute sent - repaid away + convoyed out + conversion used + sent to + usage |
| `GetDiplomaticDistance(tag)` | `CMap::DistanceBetweenProvinces` (four times the pixels between the centres, rounded down) from this country's acting capital to the other's `+0xE24`, as whole thousandths |
| `GetEffectiveNeutrality()`, `GetNeutrality()` | the two fields |
| `GetFaction()`, `HasFaction()` | section 5 |
| `GetMaxIC()`, `GetTotalIC()` | `+0x60C` - **the provinces' summed IC before any bonus**, whatever the name says (`CCountry::UpdateIC` writes it and `+0x604` from one register and then only scales `+0x604`) - and `+0x604`, the IC after bonuses and the resources' cut |
| `GetNumberOfOwnedProvinces()`, `...ControlledProvinces()` | the two list counts |
| `GetOverlord()` | the overlord's tag, by value; the null tag for none |
| `GetRelation(tag)` | the status toward that country, `+0xE28[id]` |
| `GetRulingIdeology()` | `+0xDFC`'s ideology (`RulingIdeology`) |
| `GetStrategy()` | the merged `CAIStrategy` at `+0x48C` |
| `GetSurrenderLevel()` | recorded (`FINDINGS-negatives.md`) |
| `GetTransports()` | `+0xB0` |
| `IsAtWar()` | the byte `+0xACC` (`FINDINGS-luahost.md`) |
| `IsEnemy(tag)` | not itself; at war with it; or either is `REB` |
| `IsFriend(tag, b)` | itself; either is the other's overlord; both have one overlord; one real faction; an alliance; fighting a war together and not enemies; with `b`, military access toward it |
| `IsGovernmentInExile()` | `+0x95` |
| `IsLandSafeToJoin(faction)` | false for the null faction; true where the faction's leader is not at war; otherwise false - the loop that looks for a reason finds one and breaks to the same `false`, so **it can answer true only when the leader is at peace** |
| `IsMajor()` | `major = yes`, or `+0x60C` (as `GetMaxIC`) over 100 |
| `IsNonExileNeighbour(tag)` | it is among the countries whose provinces touch the ones this one controls (`+0xF68`) and not in exile |
| `IsPuppet()` | `+0xF34` |
| `NeedConvoyToTradeWith(tag)` | not a neighbour (`+0xF58`), and either capital has no area, or the capitals are on different continents and the areas are not connected |
| `CDiplomacyStatus:GetValue()`, `GetThreat()` | relation, threat |
| `HasAlliance()`, `HasWar()`, `IsGuaranteed()`, `AllowDebts()`, `IsFightingWarTogether()` | the fields; `IsGuaranteed` - the guarantee's first party is the status's target |
| `HasFriendlyAgreement()` | an alliance, military access, a **vassal** bond (`+0x18` whose slot 7 is the save token `0x298`, `vassal`) with the target at either end, or a guarantee either way |
| `GetTarget()` | the other country's tag, by value |
| `CCountry:AICalculateExpense(g)` (rva `0x107F20`) | for metal, energy and rare materials, in SSE with each figure rounded to a float: `x = (float)((tech + gic) * m + m)` - `tech` the technology status's IC modifier (`+0x90`) and `gic` the `GLOBAL_IC` modifier, each thousandths over 1000 as a float, `m` the IC at `+0x60C` (the provinces' summed IC, before bonuses); then `x * 2` for energy and `x * 0.5` for rare materials, as floats. Nought for any other good. **Never below the day's spending** - sent to - repaid away - tribute sent + usage + conversion used + convoyed out + traded away, made a float, over 1000.0, rounded to a float (`0x50802C`..`0x508037`) |
| `CResourceValues:GetResourceValues(c, g)` (rva `0x4EA9A0`) | fills its six floats: `vDailyExpense` = `AICalculateExpense`; `vDailyHome`, `vConvoyedIn` the two ledgers; `vPool` the pool's figure; `vDailyIncome` the income side of `GetDailyBalance`; `vDailyBalance` that balance - each thousandths made a float (`cvtdq2ps`/`cvtsi2ss`), over 1000.0, rounded to a float. `CResourceValues()` starts them at nought (inferred: the constructor was not read) |
| `CAI:GetRelation(a, b)` | `a`'s status toward `b` |
| `CAI:GetNumberOfOwnedProvinces(tag)` | that country's owned count |
| `CAI:GetCountryAlignmentDistance(a, b)` | section 7 |
| `CAI:CanTradeFreeResources(a, b)` | both have `+0xDEC` set |
| `CAIStrategy:GetFriendliness(tag)`, `GetAntagonism`, `GetThreat` | the value in three hash maps keyed by the country's id, 0 where absent |
| `CProvince:GetContinent()`, `GetController()` | the fields |
| `CEU3Date:GetYear()`, `GetMonthOfYear()` | from the tick: the year; the month counted from 0 |
| `CCurrentGameState.GetCurrentDate()` | the clock |
| `CCurrentGameState.GetProvince(id)` | the province, unchecked |
| `CCurrentGameState.IsPlayer(tag)` | a person plays it |
| `CCountryDataBase.GetTag(name)` | the tag of that name |

## 7. The distance on the alignment triangle

`CEU3AI::GetCountryAlignmentDistance` (rva `0x49A480`), off the bytes:

    s = dx*dx / 1000 + dy*dy / 1000           each in 64 bits, toward nought; summed in 32
    f = (float)((float)s / 1000.0)            SSE
    r = (float)sqrt(f)                        FloatSqrt, rva 0x2000: x87 sqrt, stored as a float
    t = (float)(r + 0.0005)                   x87, stored as a float
    answer = floor((float)(t * 1000.0))       thousandths

`dx`, `dy` are the two countries' places on the triangle (`+0xE4`, `+0xE8`), thousandths. So the
answer is the straight distance in the triangle's units, rounded to a thousandth, by way of single
precision. `CalculateAlignmentFactor` in `ai_diplomacy.lua` divides it by 400.

## 8. `CAIIntel`, which waits for espionage

The Lua constructor `CAIIntel(us, them)` is `0x89F240` (`ret 4`; `this` in `ESI`, `us` on the stack,
`them` in `ECX`): `+0` and `+4` point at the two tags, `+8` at the game state's `+0x124`, the
generator the AI rolls; `Factor` (`+0xC`) is a value out of `us`'s espionage table for `them`
(`+0x1160`, `0xF8` bytes a country, through `0x52D630`) over 1000 as a float; `UncertaintyFactor`
(`+0x10`) is `1 - Factor` plus the double at `0x160A260`, clamped. `CalculateTheirPercievedMilitaryStrengh`
rolls that generator once for every unit `them` has. **Only `DiploScore_PeaceAction` among the
fourteen makes one.** `0x52D630` and the constants of the clamp were not read.

## 9. What looks wrong and is what the bytes do

- A failed call is a refusal: the bridge answers 0.
- Three functions declare an `action` the bridge never passes.
- `n - fp` and `n / fp` are computed the other way round, and a division by nought is -1 thousandth.
- `fp == 0.5` is always false; `fp < 0.5` raises an error.
- A loop over an array of pointers stops at the first null entry.
- `IsLandSafeToJoin` answers true only when the faction's leader is at peace.

## 10. Not read

`0x52D630` and the rest of `CAIIntel`; the clone bridges' own catch blocks (taken to be the bridge's,
being "instruction for instruction" it, `FINDINGS-survivors.md`); a `CFixedPoint`'s `tostring`; the
`CFixedPoint(float)` constructor; the policy `apply` functions beyond the closure each pushes; the
`CResourceValues` constructor; which registration uses which of the 21 `next` closures beyond the
four named.

## 11. What BlackICE's scripts reach besides

*Read 2026-11-16 for OpenHOI3, from BlackICE's AI scripts against `luabind.json`; fragment `lua-api-blackice.json`. Every
pointer from the registration, every body read. `GetUnits`, `IsSubject`/`IsPuppet` and the unit list's counts were checked
off the listing by the collecting session. Addresses are virtual unless marked rva.*

**The country's variables.** `CCountry::GetVariables` (rva `0xCCD40`) is `lea eax,[ecx+0x1AC]`. Lua's
`CVariables:GetVariable(name)` is `CVariables::GetValue` (rva `0x76F60`), which has no direct caller in the image and
**creates a variable it does not find, at 0** - so every script read creates the variable, not `check_variable` alone. A 0
is never saved (`CVariables::SaveContents`), so nothing can tell a created variable from an absent one.
`CSetVariableCommand(tag, CString const&, CFixedPoint)` is the command `FINDINGS-commands.md` reads: it finds the variable,
setting `+0x1C` on a hit and calling `AddVariable` on a miss.

**The unit list.** `CCountry::GetUnits` (rva `0xE06E0`) is `lea eax,[ecx+0xBAC]`: the country's list at every level. Its
counts ask each unit only its own slot and its own `regiments_count` (+0x40):

| method | rva | counts |
| --- | --- | --- |
| GetTotalAmountOfDivisions | 0x1D5C20 | land units with +0x40 **> 1** (one-brigade divisions left out, headquarters of several in) |
| GetTotalAmountOfArmies | 0x1D5C60 | every land unit |
| GetTotalNumOfRegiments | 0x1D5C90 | the +0x40 of the land units, summed |
| GetTotalNumOfShips | 0x1D5CC0 | the +0x40 of the naval units, summed |
| GetTotalNumOfPlanes | 0x1D5CF0 | the +0x40 of the air units, summed |
| GetTotalNumOfWarShips / ...Transports | 0x1D5D20 / 0x1D5DA0 | the naval units' regiments that are naval (CSubUnit slot 10) and whose definition's is_transport (+0x30) is clear / set |
| GetCount(def) | 0x1D6380 | every unit's regiments whose definition (+0x58) is that pointer |
| GetTotalStrength | 0x1D6420 | recorded already |

**The shares.** `GetProductionDistributionAt` (rva `0xE06A0`) reads `[+0x5F4][i]` unchecked, the twin of
`GetLeadershipDistributionAt` on +0x5E4. `GetPercentage` is `GetBasePercentage` (+8). `GetNeeded` is `VirtualThunkSlot3`
(rva `0x14F70`), which luabind pairs with the string 'GetNeeded' - each distributor's slot 3, all recorded already; lend-lease,
NCO and espionage hold the folded `WriteZeroInt64Out` (rva `0x6BF870`, 17 tables). Every need in thousandths is converted by
`x << 30 / 0x1F40000` - `x * 32768 / 1000`, truncated by `__alldiv` - and research's is `count << 15`.

**CFixedPoint64**, the 48.15 kind: `Get` (rva `0x6B450`) is `fild qword; fmul 2^-15` (the double at `0x160A2E0`), stored as a
float; `GetTruncated` and **`GetRounded` are one body** (rva `0x6B470`), `shrd/sar 15`, toward minus infinity - `GetRounded`
does not round.

**Others.**
- `GetNumberOfFreeSpies` (rva `0x1187E0`): spy_pool (+0x1170) / 1000 by the magic `0x10624DD3`, toward zero.
- **`IsSubject` and `IsPuppet` are one body** (rva `0xEDEA0`): `+0xF34`.
- `GetMinisters` (rva `0x105CF0`): `lea +0x618`; element 0 not read.
- `CSubUnitDefinition::IsTransport` (rva `0xC8360`): `+0x30`.
- `CProvinceBuilding::GetCurrent` (rva `0x17A60`): `+0x24`, the working level; `0x17A70` is GetMax at +0x20.
- `CModifier::GetValue` (rva `0x179E0`): `[+0x18][type*8]`, unchecked. The `ModifierType` enum is the place in the start-up
  list of modifier kinds, 0..82; **57 (`threat_resistance`) is not registered**, and 79 is spelled
  `_MODIFIER_PARTISAN_EFFICENCY_`.
- `CMinisterTypeDataBase`: GetMinisterTypeList, GetMinisterType and GetNumberOfMinisterTypes (rva `0x4EA500`, `0x4EA570`,
  `0x4EA620`) each make `g_minister_types` on first use, as `GetMinisterTypes` does, and answer its +0xC array, null type
  first, and its count. `GetMinisterType` is `CNameDataBase::GetByName`: a byte hash (x61) and an exact compare, case and all.
- `CAIAgent::GetCountry` (rva `0x49C700`) is `CCountryTag::GetCountry` on +0x34, and every minister has it.
- `CDiplomacyStatus::HasAnyAgreement` (rva `0x64A620`) is `HasFriendlyAgreement`'s five tests **or `+0x20`, the war**;
  `IsAligning` (rva `0x64A730`) is `+0x30 != 0`.

**A null definition is not refused.** `IsUnitAvailable` (rva `0x133020`), `CountMaxUnitsStillBuildable` (rva `0xE13A0`) and
`CCountry::GetBuildCostIC` (rva `0xE18F0`) read `def->+0x24` (and `+0xF8`) at once, so a script that passes nil - which
luabind turns into a null pointer - faults the process. BlackICE's production scripts name four unit types it does not
declare (`armored_engineers_brigade` and its `ss_` kind, `improved_police_brigade`, `mot_aa_brigade`).

**Corrections to the record:** `0x76F60`'s comment had create-on-read reach the game only through `CVariableTrigger` - Lua
reaches it too; `0x1D5C60` and `0x1D5CF0` take the game's Lua names (`CUnitList::GetTotalAmountOfArmies`,
`CUnitList::GetTotalNumOfPlanes`, from `CountLandUnitsInList` and `UnitList_CountAirSubUnits`); `0x1D5CF0`'s naval twin is
`0x1D5CC0`, not `0x1D5D20`.

**Not read:** what `GetMinisters`' element 0 holds; luabind's own nil-to-pointer conversion (taken from luabind 0.8's pointer
converter, not from the bytes).
