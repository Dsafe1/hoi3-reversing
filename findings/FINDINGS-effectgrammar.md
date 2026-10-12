# The grammar of effects

*Read on 2026-10-12, statically, for OpenHOI3's loading of event and decision script. Every
address is a **VA** unless it says rva; the record's entries are rvas. Nothing was tried in a
running game. Builds on `FINDINGS-script.md` (the 91 keywords and their classes) and
`FINDINGS-effects.md` (the slot map and several effects); the triggers are
`FINDINGS-triggergrammar.md` and the containers `FINDINGS-eventfiles.md`.*

**Synopsis.** What `CEffect::LoadKey` does with a key that is not one of its 91 keywords, what the
fifteen unrecorded slot-7 scalar handlers accept, and what keys and value forms the block effects
take - all settled, with the text tokenizer, which decides case and what is a number. **Four
corrections:** the default branch is not "a province id, an ideology, then the technology
database" but a nine-step chain - a government position, a building, an ideology, a technology, a
rebel type, a region, a unit type, then (only for a block) a scope, else a log line;
`CRelationEffect`, `CWarEffect`, `CUndeclaredWarRegionEffect`, `CWarGoalEffect` and
`CModifySpiesEffect` had `this`/`from` recorded as keys where they are values of `who`/`target`;
eight block loaders recorded as dropping unknown keys hand them on as **child effects**, and
`CAllOrganisationPopularityEffect` has two keys, not one; and **`CFaction +0xC` is a string, not a
`CCountryTag`** - its constructor (`0x5224B0`) builds an empty `std::string` there (capacity 0xF at
`+0x20`, length at `+0x1C`), `FindFactionByName` compares it as a string, and Lua registers it as
`CString const& GetTag`; the `axis`, `alli`, `comi` once read live are the first bytes of the
string's own buffer. The DLL's `GameClasses/CFaction.hpp` gives the offset and may read it as a
tag.

The function and field tables are in `fragments/merged/effect-grammar.json`; of the functions, 15
loaders are revised (comments and value forms), 35 are new - the 15 scalar handlers, the lexer
`TextTokenizer_NextToken` (rva `0x66A2E0`) and `RegisterCompiledTokens` (`0x669B80`), the name
lookups (`CMap_FindRegion` `0x8FAA0`, `StringHashFind_At18`/`_At1C`/`_At20C`/`_AtC`/`_At44`,
`FindFactionByName` `0x128070`), `CContextEffect::CContextEffect` (`0x59E250`), the default
branch's constructors and five `Execute`s. 30 structs are declared and their value fields added.

## 1. The lexer: what a key or value token is

`TextTokenizer_NextToken` (VA `0xA6A2E0`) is slot 1 of the text tokenizer (vftable `0x15FD1FC`).
`confirmed`:

- **Comments**: `#`, `!` and `;` each start a comment to the end of the line (the byte table at
  `0xA6A608` and jump table at `0xA6A5E4` send all three to one arm).
- **Punctuation** is a token kind of its own: `=` 1, `{` 3, `}` 4, `(` 5, `)` 6, `,` 8. `<`, `>`
  and `.` are ordinary letters.
- **A quoted string** (`"..."`) is kind 0xF and **never looked up as a keyword**: a quoted `"yes"`
  is not `yes`, a quoted `"this"` not `this`.
- **A bare word**: a digit or `-` first makes it a number (0xC) outright; otherwise it is looked up
  in `g_dynamic_tokens` with `TernarySearchTreeFind`, which lower-cases the query, and a hit gives
  that token; otherwise a number if it holds only digits, `.` and `-`, and an identifier (0xF) if
  not.
- **Every keyword is case-insensitive**: `RegisterCompiledTokens` (`0xA69B80`) puts every compiled
  keyword into the tree, lower-cased as it is inserted. So `ADD_CORE`, `This`, `FROM` and `Yes`
  are the tokens they look like. No two compiled tokens differ only in case (`saveTokens.json`).
- **So `PHI` and `PAN` never arrive as identifiers**: they are spelled like the compiled tokens
  `phi` (81) and `pan` (317). `EventScopeSpec_Construct` asks for a tag only of a 0xF token
  (`cmp [ebx], 0xF` at `0x9C1B9D`), so `PHI = { ... }` and `PAN = { ... }` never resolve as
  scopes - an effect block of them is parsed and never runs (section 3, step 8), a trigger block
  is dropped as `Unknown trigger-type`. A scalar is unaffected: `create_vassal = PHI` uses the
  text. No other tag in the base game or BlackICE collides. BlackICE writes `PHI = { ... }` in
  effects (`events/JapanInvadesPhilippines.txt` 42-102, `USAPoliticalEvents.txt` 1268,
  `zBI_USA_EventOOBs.txt` 4634, `decisions/LiberationAllies.txt` 1367). Each step `confirmed`; the
  end in a running game `inferred` - the Philippines invasion event's `Invasion_shock` modifier
  would show it.

`ParseReadKeyValue` (rva `0x67ACB0`) reads a key and the next token; **where that is not `=`, it
is thrown away and the value keeps the previous pair's value** (`0xA7AD11`..`0xA7AD43`,
`confirmed`).

## 2. The two tails of `CEffect::LoadKey`

Every keyword's case ends in one of two tails: **the scalar tail** (`0x99A038`, 67 keywords)
copies the value token (`parse +0x228`) and calls **slot 7, `TakeScalarValue`**; **the block
tail** (`0x99A0C3`, 24 keywords) calls **slot 3, `Load`**. The only slot-7 dispatches are at
`0x99A057` and `0x99B32E`, the only slot-3 ones at `0x99A0E5`, `0x99A0FA`, `0x99B56B` and
`0x99B580`, and the split matches all 101 of the family's tables: every block keyword's class has
a `LoadKey` or `Load` of its own and every scalar one a slot 7, but `modify_spies`. `confirmed`.

**Neither tail looks at the value's kind.** `CPersistent::Load` (`0xA7C050`) is a loop - peek a
token, stop at `}` or the end, `ParseReadKeyValue`, the key's `LoadKey` - and nothing skips a
block nobody read. So:

- **a scalar keyword given a block** (`add_core = { ... }`) gives slot 7 the text `{`; the block's
  contents are read as the parent's own, and its `}` closes the parent early;
- **a block keyword given a scalar** (`random = 50`) has its `Load` swallow what follows, up to the
  parent's `}`;
- **a key a loader drops without a fallback** (in `relation`, `threat`, the variable and modifier
  effects, an ideology's block, `random_list`, `add_division`), given a block, leaks it the same
  way.

The mechanism `confirmed`; what the leaked structure then does `inferred`.

## 3. The default branch (`0x99B26B`..`0x99B647`), in order

The key's text is taken from `parse +0x24`; every lookup is an exact, **case-sensitive** byte
compare:

| step | lookup | builds | value |
| --- | --- | --- | --- |
| 1 | a government position | `CReplaceMinisterEffect` | scalar, int x1000 (a minister's id), or this/from |
| 2 | a building | `CBuildingEffect` | scalar, int x1000 |
| 3 | an ideology | `CAllOrganisationPopularityEffect` | **block** `{ organisation = fixed popularity = fixed }` |
| 4 | a technology | `CTechnologyInvestmentEffect` | scalar, int x1000 |
| 5 | a rebel type | `CCreateRebelsEffect` | scalar, int x1000 |
| 6 | a region (`CMap_FindRegion`) | `CRegionScopeEffect` | **block** `{ limit = { triggers } effects... }` |
| 7 | a unit type | `CAddSubUnitEffect` | scalar: a province id x1000, `current`, `this` or `from` |
| 8 | **only where the value is `{`** | `CContextEffect` over the key | **a block of effects**, with no trial resolution (unlike the trigger side). At run time the key resolves as a tag the country database knows (a 0xF token, its first three characters, any case), a number (a province), or one of `owner controller from ally this capital_scope sea_zone local_enemy overlord`; **anything else silently never runs its children** |
| 9 | anything else | nothing | `Unknown effect-type '<key>' in <file>`, `effect.cpp:246`, channel 0x10004 |

`ReportUnknownKey` and `ReportParseError` have no call in `CEffect::LoadKey`; the same scan finds
its 108 calls of `operator new`. **Laws are not in the chain**: `training_laws = x` as an effect
falls to step 9; the base game writes laws only as triggers. `confirmed`.

**`limit` inside a scope does nothing as a condition.** A context effect's loader is
`CEffect::LoadKey`; `limit` is no keyword and in none of the seven databases, and is written with
a block, so it becomes a `CContextEffect` keyed on the `limit` token, which never resolves - its
contents never run, **and the effects beside it run unconditionally**. BlackICE has 43
`<province> = { limit ... }` and 20 `<TAG> = { limit ... }`, e.g.
`events/OperationBritanniaRising.txt` 682, `1389 = { limit = { has_global_flag = ... } ...
naval_base = 10 }`, which builds the base whatever the flag. The steps `confirmed`, the outcome
`inferred`. The base game has none: its `limit`s outside the iterating keys are all under region
names, which take `limit`.

## 4. Every effect keyword

**int x1000** is `atoi(text) * 1000`, so decimals are cut; **fixed** is read to three places in
thousandths; **tag** is `GetTag` on the first three characters, any case, nothing if unknown;
**this/from** are matched by token, any case, never when quoted, and on the handlers that take
them set `+0x1C`/`+0x1D`. All `confirmed` unless said.

| keyword | value | notes |
| --- | --- | --- |
| `add_ai_strategy` | a block, `CAIStrategy`'s 21 keys | not effects |
| `add_casus_belli`, `casus_belli` | tag / this / from | |
| `add_core` | tag / a province number / this / from / `REB` | both fields are set from the one value: a number is a province, given the scope country's core; a tag is a country, whose core goes on the scope's province; `from` is the scope's FROM **province** |
| `add_country_modifier`, `add_province_modifier` | block `{ name = <static modifier> duration = <whole days> }` | an unknown name is logged and does nothing; other keys dropped |
| `add_division` | block `{ name = string where = %i <unit type> = name }` | `FINDINGS-oob.md` |
| `add_wargoal` | block `{ target = tag/this/from war_goal = { ... } }` + child effects | |
| `any_controlled`, `any_country`, `any_neighbor_country`, `any_neighbor_province`, `any_owned`, `random_country`, `random_owned`, `random_neighbor_province`, `random_empty_neighbor_province` | block `{ limit = { triggers } child effects... }` | several `limit`s join into one AND |
| `any_nearby_province` | the same, and `distance = %i` | not a number: a parse error |
| `capital` | int x1000, this/from | a province's id, `inferred` from use |
| `change_controller`, `create_alliance`, `create_vassal`, `do_election`, `end_guarantee`, `end_military_access`, `end_non_aggression_pact`, `end_war`, `guarantee`, `inherit`, `leave_alliance`, `military_access`, `non_aggression_pact`, `release`, `secede_province`, `surrender_inherit` | tag / this / from | |
| `change_manpower`, `dissent`, `leadership`, `manpower`, `neutrality`, `officer_pool`, `organisation`, `popularity`, `revolt_risk`, `split_troops`, `war_exhaustion` | fixed, this/from | |
| `change_province_name`, `set_`/`clr_country_flag`, `set_`/`clr_province_flag`, `set_`/`clr_global_flag` | a string, verbatim | `this` is just a name here |
| `change_variable`, `set_variable` | block `{ which = string value = fixed }` | other keys dropped |
| `country_event`, `province_event`, `create_revolt`, `kill_leader`, `local_intel_boost`, `national_unity`, `remove_fow`, `crude_oil`, `energy`, `fuel`, `metal`, `money`, `rare_materials`, `supplies` | int x1000, this/from | `crude_oil = 2.5` is 2 |
| `coup_by` | this / from / an ideology's name | nothing, silently, on a miss |
| `fixed_ai_strategy`, `form_government_in_exile` | only a bare `yes` is true | |
| `government` | `REB` (exact case) / this / from / a government's name | an unknown name does nothing |
| `join_faction`, `leave_faction` | a faction's name, exact (`axis`, `allies`, `comintern`) | no this/from; a miss gives the null faction |
| `load_oob`, `remove_brigade` | a string, verbatim (this/from also set the flags) | |
| `modify_spies` | ignored | slot 7 is the empty stub |
| `practical` | block `{ technology_group = <category> value = fixed }` + child effects | |
| `random` | block `{ chance = int x1000 child effects... }` | |
| `random_list` | block `{ <number> = { effects } ... }` | the weight plain `atoi`; the first entry has one more chance and the last one fewer |
| `relation` | block `{ who = tag/this/from value = fixed }` | other keys dropped |
| `release_vassal` | tag / this / from / `random` | **an unknown tag behaves as `random`** (what `Execute` then does was not read) |
| `remove_core` | as `add_core` | |
| `remove_country_modifier`, `remove_province_modifier` | a static modifier's name | logged on a miss |
| `remove_minister` | `yes` / a position's name / a minister's id x1000 | |
| `strategic_resource` | `none` / a resource's name | a miss stores nothing |
| `threat` | block `{ who` or `which = tag/all value = int x1000 }` | no this/from |
| `undeclared_war` | block `{ target = tag/this/from region = name }` + child effects | an unknown region is logged |
| `war` | block `{ target call_ally = yes/no (any case) limited = bool attacker_goal = { ... } defender_goal = { ... } }` + child effects | |
| *a government position* | int x1000 (a minister's id) / this / from | `head_of_state = 23050` |
| *a building* | int x1000 | `industry = 5` |
| *an ideology* | block `{ organisation = fixed popularity = fixed }` | other keys dropped |
| *a technology* | int x1000 | |
| *a rebel type* | int x1000 | |
| *a region* | block `{ limit ... effects }` | |
| *a unit type* | a province x1000 / `current` (the scope's province, given to its controller) / `this` / `from` | |
| *anything with `{`* | a scope; its children run only if the key resolves | `PHI`/`PAN` never do |
| *anything else* | dropped, with a log line on channel 0x10004 | |

**Child effects** are taken by the eleven iterating scopes, regions, scopes, `any_nearby_province`,
`random`, each `random_list` weight, and - surprisingly - `practical`, `war`, `undeclared_war` and
`add_wargoal`, for which whether `Execute` runs them was not read. No keyword accepts both a
scalar and a block.

## 5. Traps hit

- **Trap 2, a new pair**: rva `0x5A26DF`/`0x5A26E0` - the previous function ends `push ecx; jmp`
  with no padding before `CTechnologyInvestmentEffect`'s constructor.
- **The decompiler mis-structured `CRemoveMinisterEffect`'s slot 7**, folding a string destructor
  into a branch; the disassembly settled it (`0x9B17BC`..`0x9B181C`).
- **`definitions.py` has two blind spots**: it counts tokens compared against the *value* as keys
  - all five `this`/`from` corrections - and it misses the first arm of a `sub/je` chain
  (`organisation`).
- **Trap 4**: two class-free folds, `0x5A4940` (`CFlagEffect` with `CRenameProvinceEffect`) and
  `0x5A7B70` (`CCountryTargetEffect` with `CDiplomaticEffect`).

## Not established

- Whether `Execute` runs child effects for `practical`, `war`, `undeclared_war` and `add_wargoal`.
- What `CReleaseVassalEffect`'s resolver (`0x5AF510`) does with its "random".
- What `remove_minister = yes` removes.
- Where channel 0x10004 is written - never seen in a log - so whether `Unknown effect-type`,
  `Unknown modifier-type` and `non-existent region` reach anywhere.
- Which names `RegisterDynamicToken` adds at run time: a tag spelled like one would fail as a
  scope as `PHI` does.
- `CAddSubUnitEffect::Execute`'s cached unit type (`CSubUnitDataBase +0x78 -> +0x24`), and what
  its `+0x5C`/`+0x60` are.

**Frontier:** `0x5AF510`, `0x479760`, `0x5BE8F0`, `0x5B0F40` (`CRemoveMinisterEffect::Execute`),
`0x5B7D80`, `0x5B8820`, `0x5A2710`, `0x5B8ED0`, `0x5AB280` (the default branch's classes'
`Execute`s), `0x44D8E0`, `0x747A00`.
