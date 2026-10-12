# An event firing, a decision taken, and the two windows

*Read on 2026-10-12, statically, for OpenHOI3's events and decisions, by a wave of three. Addresses
are rvas against `0x400000` unless they say VA. The candidate lists, the monthly rebuild, the daily
pass and the mean time to happen are `FINDINGS-events.md`; the files and containers
`FINDINGS-eventfiles.md`; `country_event` and `province_event` `FINDINGS-effects.md` and
`FINDINGS-effectrun.md`.*

**Synopsis.** `FireEvent` had a record by name and extent only; it is read whole here, with the
command that answers an event, the already-fired registry, the on_actions, decisions, and the two
windows. **Corrections**: `FireEvent` has 16 callers, not 10, and the group the record called effect
code is the battle on_actions; `CGameState::GetLocalPlayer` has 115 callers, not two;
`CCurrentGameState +0xC38` is the registry's count, not a pointer. **Found**: an AI country's option
is drawn on a fresh MT19937 **seeded with the wall clock**; a person's event answers itself with
option 0 after four months; the `immediate` block runs inside `FireEvent`, before either answer; a
province event with a mean time to happen never fires on its own, though on_actions can fire one;
an on_action's weights are never read.

The function and field tables are in `fragments/merged/event-firing.json`, `decisions.json` and
`event-window.json`.

## 1. `FireEvent`, and choosing an option

### 1.1 `FireEvent` (`0x5C0C80`), read whole

`__stdcall(event, scope)`, `ret 8`. Nothing is passed in a register - EAX is overwritten by the SEH
prologue before anything reads it - so the `GetEventList` call before 15 of the 16 call sites is
there only to construct the list lazily. That closes `FINDINGS-eventfiles.md`'s open item: it does
not take the list in EAX. `confirmed`. In order:

1. **`fire_only_once`** (`CEvent +0x172`): the event's id pair is looked up in the registry at
   `CCurrentGameState +0xC38`; if the answer is this very `CEvent`, it returns at once - no
   `immediate`, no window, no AI.
2. **Which country answers**: the scope's `country_id` (`+0x14`), or where that is 0 the owner
   (`+0x32C`/`+0x330`) of the scope's province (`+0x28`). A province's event is answered by its owner.
3. **The AI answers** when `played_countries_array[id]` is 0 and the country's `CEU3AI` (`CCountry
   +0x1D8`) is not null - or when the country is the local player's, the local player record's byte
   `+0x28` is set, **and** the `nopopup` cheat is on. It chooses (1.2) and **posts** a
   `CSelectEventOptionCommand`; it does not run the option.
4. **A person answers** where neither applies, the country is the local player's and `+0x28` is set.
   If the in-game screen's list of open events (`IsEventPending`, `CInGameIdler +0x188`) already
   holds this `CEvent*`, nothing is shown; otherwise a `CEventWindow` (VA `0x9C2010`, 0xA0 bytes) is
   built with a copy of the scope and added to the in-game screen's list at `+0xA0`.
5. **Any other country** gets nothing on this machine - another person's in multiplayer, or a country
   with neither a player nor an AI object.
6. **Always**, on every branch past step 1, the **`immediate` effects** (`CEvent +0x98`, the
   immediate option at `+0x70` plus `0x28`) run through slot 11 with `(scope, 0)` - **after** the
   window is built or the AI's command posted, and **before** either answer's option runs.
7. With `fire_only_once`, the event goes into the registry (1.5).

The trigger is **not** asked again here; every caller asks it first. `FireEvent` writes no log line
(no string reference in its listing, where the same tool shows `Execute`'s). All `confirmed`.

**Looks wrong, and is what the bytes do**: an event fired again while its window is still open shows
**no second window, yet runs its `immediate` again** - and the open-window test is keyed on the
`CEvent*` alone, so the same event for another scope is refused too. And where the local player
record's `+0x28` is clear, the player's own events get **no answer at all**, only `immediate`.

### 1.2 How the AI picks an option

`ai_chance` is a `CAIMTTHChance`. The weight of option i is

    w_i = (float)((float)GetDays(&option->ai_chance, scope) / 1000.0) * ai_chance.factor (option +0x24)

`GetDays` being `days x 1000` multiplied by each modifier whose condition holds, as `factor / 1000`,
in 64-bit integers - so with the default `days = 1` a weight is `factor` times the modifiers'
factors. The weights are summed in single precision. If the sum is not above 0.0 (no options
included), the choice is **option 0**. Otherwise `s = sum / 100.0`, **a fresh MT19937 is built on
the stack, seeded with `_time64(NULL)`** (VA `0xAA2BF0`; VA `0xB9AFDE` is the C runtime's
`_time64`, read) - not the game's synchronised generator and not the scope's state - `r =
MT19937Next() % 100`, in 0..99, and the choice is the **first** i with `r <= sum over j <= i of
trunc(w_j / s)`. All `confirmed`.

**Kept as the bytes have them**: the truncated shares can sum below 99, and a roll past them falls
to **option 0** - six equal options make 16 each, 96 in all, so a roll of 97 to 99 does; three make
33 + 33 + 33 = 99, and since the roll is at most 99 and the test `r <= c`, none passes them
(*corrected in transcription, 2026-10-12: the reading gave three equal options as the example*); since the test is `r <= c` and r can be 0,
a first option weighing nothing is still taken **one time in a hundred**; each option's `GetDays`,
conditions and all, is asked twice, once in each loop; and **the choice is reproducible from neither
a save nor a seed** - only the index chosen travels, in the command.

### 1.3 A person's event: the window, the wait, the timeout

Brief C's ground; read here only for the wait and the answer. All `confirmed`:

- the window's constructor sets a deadline at `window +0x98`: now, advanced by `AddMonths(..., 4)`
  (VA `0x9C30D7`-`0x9C30E6`);
- its slot 1 (VA `0x9C45F0`) runs each frame, and once the game's tick is past the deadline it posts
  `CSelectEventOptionCommand(event, scope, 0)` and closes - **unanswered for four months of game
  time, a person's event takes option 0**, not the AI's choice; a paused game never times out;
- a click on an option (VA `0x9C4890`) posts the button's position as the index and clears the
  window's open byte (`+0x58`), so a second click posts nothing;
- the constructor adds the event to `CInGameIdler`'s open list and the destructor takes it off;
- the buttons are switched by whether a second of real time has passed since the window opened
  (`+0x9C`); which of the two calls enables them was not read.

### 1.4 `CSelectEventOptionCommand`, and what `Execute` runs

The command (0xB0 bytes, type id `0x355`) holds a persistent reference to the event (`+0x3C`, its id
pair at `+0x40`/`+0x44`), the option at `+0x64` and a copy of the scope at `+0x68`. Three places
build it: the AI's branch of `FireEvent`, the window's timeout (option 0) and its buttons. **Its one
check** is slot 14 (a body shared with five other command classes) resolving the event's id; the
session's drain deletes it unexecuted if that fails. `confirmed`.

`Execute` (slot 6, `0x60ABF0`), in order, `confirmed`:

1. The event resolved again by id; the copied scope's `this_scope` pointed at itself.
2. The message's replacements: one per government position from the **local** player's ministers
   (`MINISTER_MESSAGE_ENTRY`, TITLE and NAME); COUNTRY (the scope country's name, or for a province's
   scope the owner's or the province's); EVENT, EVENTDESC and OPTION - title, description and the
   option chosen - each read through the scope.
3. One message (its poster, VA `0xA0C4D0`, posts nothing under `nopopup`): `EVENTHAPPENUS` where the
   scope's **raw** `country_id` is the local player's; otherwise, with at most one option,
   `MAJOREVENTHAPPENOTHER` if `major` (`CEvent +0x171`) is set and `EVENTHAPPENOTHER` if not;
   otherwise `MAJOREVENTHAPPENOTHEROPTION` or `EVENTHAPPENOTHEROPTION` on the same test. **Choosing
   among these is all `major` does on this path**; whether each pops up, is logged or is hidden is the
   message settings, not read.
4. **The scope's random state is reset to its seed**: `+0x8` and `+0xC` set to `+0x2C`. `immediate`
   began from that seed too (the daily pass and `country_event` set all three alike), so **an
   option's rolls replay the sequence `immediate`'s began with** - inferred from the two readings.
5. `RunEventOption(event, option, scope)` (`0x5BF3D0`): the option's effects through slot 11 with
   `(scope, option index)` - which no effect reads; an index out of range does nothing; a negative
   one would run `immediate`, and nothing makes one.

**Not checked**: the trigger, whether the event was open for that country, who sent the command.
**Looks wrong**: a province's event has `country_id` 0, so its owner is told `EVENTHAPPENOTHER...`,
not `EVENTHAPPENUS`.

The sequence: for the AI, `FireEvent` -> command posted -> `immediate` -> registry -> (at the
command drain) message -> the option's effects; for a person, `FireEvent` -> window -> `immediate`
-> registry -> a click or four months -> command -> message -> the option's effects.

### 1.5 `fire_only_once` and the already-fired registry

`CCurrentGameState +0xC38` is the count, `+0xC3C` the number of buckets, `+0xC40` the buckets, each
chaining 8-byte nodes `{CEvent*, next}`; an id's bucket is `((id_type << 16) + id) % buckets`.
Inserted by `FireEvent` **when the event fires**, not when it is answered, and by
`ResolveSavedFiredEvents` (`0x280FE0`), which `CInGameIdler::Enter` calls only for a game loaded
from a save (`+0xD9C`) to move the saved ids (`+0xC44`) into the registry. Read by
`RebuildCountryEventCandidates` (which leaves the event off every list), `FireEvent`'s first test,
and that resolver. **The key is the event alone, not the event and a country**: a `fire_only_once`
event fires once a game, for whichever country gets it first. `confirmed`. Within a month it may stay
on other countries' lists; `FireEvent`'s first test stops it.

### 1.6 Province events, and who else calls `FireEvent`

**No province event with a mean time to happen ever fires on its own** - inferred before, now well
supported. Province events are kept at `g_event_list +0x10`, which only the console's `event` command
reads: of 18 callers of `GetEventList`, 15 sit just before a `FireEvent` call and the rest are the
console (VA `0x43C5D7`) and `LoadEvents` (VA `0x632536`, `0x65AC03`); of 19 references to the
global, none walks `+0x10`. The positive control: the same search finds the `+0x00` walker,
`RebuildCountryEventCandidates`, through VA `0x682556` and `0x683CD3`.

**But on_actions can fire one** (`confirmed`): `OnAction_PickEvent` resolves any id with
`FindPersistentByIdPair(0x28, id)`, country and province events alike, and asks its trigger in the
on_action's scope. The 16 callers of `FireEvent` are the daily pass, `country_event`,
`province_event`, `FireOnAction` (for `on_nuke_dropped` alone) and twelve inline on_action sites:

| on_action | where (VA) |
| --- | --- |
| `on_encirclement` | the daily province pass, `0x49F122` |
| `on_surrender` | `0x4E915F` |
| `on_coup_success`, `on_coup_fail` | `0x4F7DFC`, `0x4F7EA3` |
| `on_enemy_pride_sunk`, `on_our_pride_sunk` | `0x568820`, `0x568918` (`CNavalCombatant::Attack`) |
| `on_battle_won`, `on_battle_lost` | `0x576A6C`, `0x576B7F` |
| `on_air_battle_won`, `on_air_battle_lost` | `0x57864F`, `0x578767` |
| `on_naval_battle_won`, `on_naval_battle_lost` | `0x57A975`, `0x57AA9B` |

That is all 13 keys of `tfh/common/on_actions.txt`, one `FindOnAction` call each.

`on_encirclement` fires from the daily province pass, once per province, where its
`out_of_supply_days` (`+0x20`) is exactly 1, its area (`+0x2B4`) answers slot 0 true and the area's
byte `+0x68` is set - what that byte is was not read - in a scope of country `---`, the province, and
a fresh MT draw as the seed, so the province's owner answers.

**An on_action's pick is not weighted**: `OnAction_PickEvent` returns the **first entry in file order
whose trigger holds**. `LoadOnActions` keeps each entry's weight (the `10` in `10 = 600`) on its node
and sums it into `COnAction +0x0`, and nothing reads either - the picker loads the weight into a
local never read again, and all 13 lookups hand their answer to the picker alone.

### 1.7 When an event is asked

From the record, not read again: the daily pass runs before the monthly rebuild on the 1st, so an
event with a mean time to happen fires from the 2nd; both are skipped while `tutorial_active`
(`+0xD9D`) is set. New here: **the daily pass has no "already open" test and a candidate is not
removed when it fires**, so an event without `fire_only_once` may fire again on any later day while
its trigger holds - the AI posting a new command and running its option again each time, a person
getting no second window while one is open but `immediate` again each time.

### 1.8 Traps hit

- **Traps 2 and 9, on the tooling**: `disasm.py 0xA0ABF0 0x1400` found no `ret`, `Execute` being
  0x15A8 bytes - its end is the next slot (`0xA0C1A0`) and the bare `ret` at VA `0xA0C198`;
  `functionStart` gave nonsense at VA `0x9C32AA` and `0x578767`, both placed by their call sites.
- **The record's list of callers (10) was stale**, and "effect code" for the `0x576`-`0x57A` group a
  guess; `findRefs --callers` gives 16 (checked again in transcription).
- A bash heredoc stalled on stdin; every script after went through the Write tool.

### 1.9 Not established

- What sets the local player record's byte `+0x28` (read by `FireEvent` twice and `CInGameIdler`
  slot 24, VA `0x674EF0`); "an active local player who receives popups" is a guess.
- **In multiplayer**: `FireEvent` has no host test, so every peer with a `CEU3AI` for the country would
  post a command; whether those objects exist only on the host was not read.
- Whether `CGameState::LoadKey`'s list of ids at VA `0x6808AF` is the `fired_events` key (`+0xC44`).
- The message settings for the four event messages.
- `on_encirclement`'s area byte `+0x68`, and the scopes the other eleven inline on_actions build.
- Which of `CEventWindow`'s `+0xB8`/`+0xBC` enables the buttons, and its layout (section 3).
- Not read: `CSelectEventOptionCommand`'s slot 13 (its copy) and slot 2; VA `0x644670` (an append
  to the list at `ESI+0xA0`, 49 callers); the minister replacement inside `Execute`.

**Frontier:** `0x244670`, `0x274EF0` (`CInGameIdler` slot 24), `0x5D49D0`, `0x60C4D0` (the event
message's poster), `0x60C430`.

## 2. Decisions: offered, taken, and taken by the AI

### 2.1 Where a decision is offered

**There is no list of decisions kept for a country.** Three paths ask when they need to, each with a
`CEventScope` of its own, each walking **the diplomatic vector** (`g_decision_database +0x0C`) in
file order, asking `potential` (`+0x24`, slot 6) and `allow` (`+0x64`) only where `potential` holds.
All `confirmed`.

| who | the scope's country | FROM, province | seed | when |
| --- | --- | --- | --- | --- |
| `CAIForeignMinister::ExecuteDiploDecisions` (`0x49DD50`) | the minister's country | `---`, 0 | one MT19937 draw on the game's generator (`+0x124`) a pass | once a game day for each country with a foreign minister (2.4) |
| `CAlertManager_Update`, its walk at `0x206D41` | the played country | `---`, 0 | 0 | at most every 3.0 of a float clock read through the manager's `+0xA0C` slot 5 - probably seconds, the clock not read (`inferred`) |
| `CDiplomacyView::RebuildDecisionList` (`0x38C560`) | section 3.7 | | | when the screen is shown |

**The alert**: each decision that passes both adds its title's text to alert 12
(`alert_national_decisions`), which is shown where any passed and hidden where none did - and
**never in a scenario**, `gamestate +0xD0C` set forcing it off.

**The two groups.** A sweep of the 14 pieces of code that address `g_decision_database` or call
`GetDecisionDatabase` - the control being that it finds every walker and lookup already known - finds
every walk over the diplomatic vector and none over the political (`+0x28`) but
`DestroyDecisionDatabase`. Lookups by name: `IsValid` and `Execute` the diplomatic table then the
political; `SetUpCountryForNewGame` the political then the diplomatic; `CCountryWarTargetValue::LoadKey`
the diplomatic alone. **So a `political_decisions` decision is read, can be run by name and replayed
from history, and is never offered to a person or to the AI.** `confirmed`.

### 2.2 Taking one: a command, asked again when it runs

`PostExecuteDecisionCommand` (`0x598A00`) is the only way in, with three callers: the AI's pass, its
prepared wars in `DoWork`, and the screen's button (`CDecisionEntry::OnClicked`). It makes a
`CExecuteDecisionCommand(name, a copy of the scope)` - **the name, not the pointer** - and posts it on
the session's channel, checking nothing. The loopback post (`0x73C0D9`) calls the command's
**slot 14, `IsValid`**, and deletes it on false; the session's drain (`0x689848`) calls `IsValid`
**again just before `Execute`** and skips it on false.

`IsValid` (`0x609A30`), `confirmed`: the decision found by name, diplomatic table then political,
false where neither has it; the scope's `this_scope` pointed at itself; **its random state reset to
its seed** (`+8`/`+0xC` from `+0x2C`); and **`potential && allow`**. Nothing else is asked.

`Execute` (slot 6, `0x608610`), read whole, `confirmed`:

1. The decision found by name, the diplomatic table then the political; neither, and it returns
   silently. It asks neither `potential` nor `allow` nor whether the country still exists - that is
   `IsValid`'s.
2. **The message, before the effect runs** - so its text shows the state before the decision: COUNTRY,
   EVENT (`<name>_title`), DESC (`<name>_desc`) and PROVINCENAME where the scope has a province; the
   type, in this order: `DECISIONUS` where the scope's country is the played one (`PROVDECISIONUS`
   with a province), else `PROVDECISIONOTHER` with a province, else `MAJORDECISIONOTHER` where `major`
   is set, else `DECISIONOTHER`. **That is the whole of `major`.** The shipped `messagetypes.txt`
   gives `DECISIONOTHER` no log and no popup, and `MAJORDECISIONOTHER` both.
3. The random state reset to the seed again, so every peer draws the same numbers.
4. **The effect** (`CDecision +0xA4`), `CEffect::Execute(scope, 0)`.
5. `CCountry::RebuildNeighbours` and `0xE39C0` on the country, `RebuildProvinceModifierValues` on its
   province where there is one, then `CCountry::RebuildStaticModifiers`.
6. **A `CCountryDecisionChange`** dated today filed in the country's history
   (`CHistoryContainer::AddEntry`) - **and not applied**. The name goes through `_snprintf("%s")` into
   a buffer of 255 characters.

### 2.3 Once, or again?

**A decision may be taken again whenever `potential` and `allow` hold.** No path that offers one,
and neither `IsValid` nor `Execute`, reads any record of a decision taken - all read whole or at
their decision code. `confirmed`. Taking one once is the script's business: a flag set in `effect` and
asked in `potential`, by convention.

A country does keep **a list of decisions taken** (`CCountry +0x128`/`+0x12C`/`+0x130`; 0x28-byte
nodes, a name each, no repeats), filled **by history alone** - `decision = X` and `remove_decision =
X` through the changes' `Apply` - so taking one in play files an entry but leaves the list alone. Its
one reader is `SetUpCountryForNewGame`, which **on a new game, never on a load**, looks each name up
(political table first), logs `<TAG> has unknown decision '<name>'` for a name nothing has, and **runs
its effect** in a country's scope whose random state and seed are 0, not reset between decisions -
asking neither `potential` nor `allow`, sending no message and filing no entry.

Every dated `decision =` in the base game's, Their Finest Hour's and BlackICE's histories is after
1936.1.1 - the first are France's `popular_front`, 1936.5.3, and BlackICE's Soviet
`great_officer_purge`, 1937.12.1 - so a start on 1 January 1936 runs none, **if** history is applied
only up to the start (`inferred`; the range was not read).

### 2.4 The AI

**The daily pass**: `CAIForeignMinister::DoWork` (slot 10) acts in the hour `(id + 13) % 24` of each
day and calls the Lua `ForeignMinister_Tick`, and every shipped version of that script - the base
game's, Their Finest Hour's and BlackICE's - calls `minister:ExecuteDiploDecisions()` first. That
pass, for each diplomatic decision whose `potential` and `allow` hold, calls the Lua global
`ForeignMinister_EvaluateDecision(minister, decision, scope)`, and **an integer answer above 0 posts the
decision**. The answer must be a Lua number, or luabind throws; a fraction is cut by
`lua_tointeger`.

**`ai_will_do` (`+0xC4`) is never read** (`confirmed`): no instruction in the 14 pieces of code that
reach the database, nor in the command's, addresses `+0xC4` to `+0xDC` of a decision, where the same
sweep finds the one read of `+0xE0` (`major`) in `Execute`; and none of the 13 callers of the mean
time to happen's evaluator (`0x5C4B90`), nor the one caller of `GetChance`, passes `+0xC4`. The Lua
API gives a decision only `GetKey`, `IsPotential` and `IsAllowed`. **So the AI's chance lives in the
scripts**: the base game's `GetAIRand() % 100`, nought below 25; Their Finest Hour's and BlackICE's
`math.random(100)`, nought below 25, BlackICE adding `OMG` at 100 and a rule for `buy_resource`; a
country's own file may override it. With no override that is about 75% a day for each decision open
to it. One pass may post several decisions, all judged before any runs; `IsValid` asks each again when
it does.

**Prepared wars** (`DoWork`, `0x49D830`-`0x49DCCF`): `CAIStrategy::PrepareWarDecision(tag, value,
decision, limited)` adds a `CCountryWarTargetValue` holding the decision at `+0x18`; for a war target
`0x4ADEF0` accepts (not read; a readiness test, by its look) and that carries a decision, `DoWork`
asks `potential` and `allow` in a fresh country's scope seeded from the MT19937 and posts it - **no
Lua score on this path**. A target with no decision goes to `0x49D967` (not read; the declaration of
war, by its look). The shipped German, Italian and Japanese scripts use it.

**A player's country** has a `CAIForeignMinister` only where `GetLocalPlayer()->flags[0] == 1`
(`FINDINGS-ai.md`, `CEU3AI::CreateMinisters`), a flag that record pairs with a save key by inference
(`automate_trade`). If that holds, a player who leaves that ministry to the computer has decisions
taken for him by both paths - each through the same command.

### 2.5 What looks wrong and is what the bytes do

1. `ai_will_do` is read from the file and never used.
2. The order of the lookups differs: `Execute` and `IsValid` the diplomatic table first, the new
   game's replay the political first, and a war target's saved decision is found again in the
   diplomatic table alone, so a political one is lost on a load.
3. The message goes out before the effect runs.
4. `Execute` files a history entry it never applies, so the list of decisions taken is history's alone
   and read only by the new game's replay.
5. The AI's scope is seeded by one draw on the game's own MT19937 a pass; the replay's state is 0 and
   not reset between decisions.
6. `Execute` has messages for a scope with a province and no path found posts one: the AI's is
   province 0, a prepared war's is made by a constructor, the screen's has none; and Their Finest
   Hour's `messagetypes.txt` has neither `PROVDECISIONUS` nor `PROVDECISIONOTHER` (a message of that
   kind would log "Bad messagetype", `inferred`).
7. The decisions' alert is never shown while a scenario is set.
8. A decision's name over 255 characters is cut in its history entry.

### 2.6 Traps hit

- **Trap 2**: `FINDINGS-eventfiles.md` section 6 and `g_decision_database`'s comment cited VA
  `0x4D59D0` for the lookup by name in both tables; that function ends `ret 4` at VA `0x4D622D` with
  no padding, and the lookups are in `SetUpCountryForNewGame` (VA `0x4D6230`), whose record already
  warned of the abutment.
- The same comment filed the walk at VA `0x606D41` under "the AI"; it is `CAlertManager_Update`.
- **Trap 1**: `g_decision_database`, `GetDecisionDatabase` and `DoWork`'s first paragraph cited
  callees as VAs; the two revised database comments are in rvas now, `DoWork`'s old paragraph carried
  unchanged.
- **The decompiler** shows a `return` after `DestroyDecisionDatabase` in `ExecuteDiploDecisions` and
  `SetUpCountryForNewGame`; the bytes store the database and go on.
- **Collisions**: `0x598760`, `0x598800` and `0x5986E0` left to `event-window.json`'s names
  (`CDecision::GetTitleText`, `CDecision::GetDescText`, `MakeDescKey`); `PostExecuteDecisionCommand`
  and the command's constructor kept here.

### 2.7 Not established

- `0xE39C0`, after `RebuildNeighbours` here and in many effects; `0xD7AE0`, the builder of the played
  country's message variables.
- `0x4ADEF0` and `0x49D967` (2.4).
- Whether history is applied only up to the start (2.3).
- The unit of the alert's clock, and whether `[esp+0x18]` is the played country throughout
  `CAlertManager_Update` (head and tail read).
- Which save key `flags[0]` is.
- The thread `ExecuteDiploDecisions` runs on.
- **Not swept**: all 95 pieces of code touching `+0x128`/`+0x12C`/`+0x130`, so a reader of the taken
  list outside the code that reaches the database is not ruled out; every path that offers a decision
  was read and none reads it.

**Frontier:** `0xE39C0`, `0xD7AE0`, `0x4ADEF0`, `0x49D967`, `0x609B50`, `0x10F8E0`, `0x10F880`,
`0x37E200`, `0x208730`, `0x208580`.

## 3. The event window and the decision screen

### 3.1 Which event window

The constructor (`0x5C2010`) asks one thing, **whether the scope has a province** (`scope.province >=
1`, VA `0x9C219F`); the event's kind does not enter into it. `confirmed`.

| | no province | a province |
| --- | --- | --- |
| window | `EventWindow` (`interface/eventwindow.gui`, at 300,100, 520 x 410) | `Event_Province_Window` (`interface/event_province_window.gui`, at 300,50, 520 x 600) |
| button type | `EventOptionButton` | `EventPOptionButton` |
| offset type | `event_option_offset` (6,25) | `event_province_option_offset` (100,25) |
| picture when none loads | `GFX_event_no_image` | `GFX_prov_event_no_image` |

The window is made through the scope country's interface host (`CCountry +0xF1C`): its slot 14 gives
the gui, the gui's slot 11 makes the window by name, slot 16 gives the parent. It stands where its
file puts it; no code moves it, and it is `moveable`.

| element | kind | what goes in it | tooltip | |
| --- | --- | --- | --- | --- |
| `Title` | textBoxType | `LocaliseEventText(title)` | none | confirmed |
| `Subtitle` | textBoxType | `LocaliseEventText(subtitle)`, **only where the key is not empty**; otherwise the file's text stays | none | confirmed |
| `Description` | instantTextBoxType | `LocaliseEventText(desc)`, then, **where the `immediate` block's effects text is longer than one character, `"\n\n§W"` and that text** | none | confirmed |
| `event_images` | iconType | a drawable loaded from `gfx/pictures/events/` + `picture` + `.tga`, given the fallback sprite type, and shown | none | confirmed; a missing file not read |
| `event_option<i>`, one for each option | a new `EventOptionButton` or `EventPOptionButton` attached under that name | `LocaliseEventText(option's name)`, in the button's own font | the option's effects text (3.4) | confirmed |
| `Background`, `bg_event_clip` | the file's | untouched | none | confirmed (never referenced) |

### 3.2 `LocaliseEventText` (`0x5C35E0`): a key and its `$VARIABLES$`

Arguments `(out, key, scope by value, owner tag by value)`, cdecl, 16 callers - both commands and the
missions among them. It looks the key up with `GetText` and fills **`$NAME$` variables** through
`CInternationalizedText::Replace`. **There are no `[This.GetName]` forms**: the same search over the
install's localisation finds `$COUNTRY$` 829 times and no `[This`, `[From` or `[Root`.

C is the scope's country, or **the controller of its province where it has none**.

| variable | value | only when |
| --- | --- | --- |
| `THISCOUNTRY` | the name of THIS's country | THIS has a country |
| `FROMCOUNTRY`, `FROMCOUNTRY_ADJ` | FROM's name; FROM's adjective, localised | the scope has a FROM country |
| `COUNTRY`, `COUNTRYNAME` | C's name, the two the same | C exists |
| `MONARCHTITLE` | C's government's slot 15, localised | C exists |
| `COUNTRY_ADJ` | C's adjective, **not passed through `GetText`** | C exists |
| `CAPITAL` | the name of C's capital | C exists |
| `LAND_`, `AIR_`, `NAVAL_` + `LOSER_LOSSES`, `WINNER_LOSSES` | the game state's last-battle figures | always |
| `PRIDE_SUNK`, `PRIDE_SINKER` | the names at the game state's `+0x48` and `+0x4C`, empty for none | always |
| `YEAR` | `(tick - 43800000) / 24 / 365.0`, cut | always |
| `PROVINCENAME` | the province's name | a province |
| `REGIONNAME` | its first region's name, localised; empty for none | a province |
| `CONTINENTNAME` | its continent's **raw** name, not localised; empty for none | a province |
| `OWNERNAME` | the owner argument's name where its id is not 0, else the province owner's | a province |

The text is then drawn with the game settings' colours. Every window and decision caller passes the
owner `---`. `confirmed`.

### 3.3 The option buttons

- **One for each option, in file order, with no cap.**
- **Button i** (counted from 0) stands at x = offset.x, **y = the window's height - (n + 1 - i) x
  offset.y**: the last option always sits at height - 2 x offset.y and more options grow upward - y
  = 360 in `EventWindow` and 550 in the province's window.
- **Its instance name** (`+8`, set by the button's slot 30) is `<event id>_<i>_<scope's seed>_<scope's
  province>_<FROM's tag>`.
- **The buttons are disabled until a second of real time** (the idler's clock) has passed since the
  window opened.

### 3.4 An option's tooltip

`CInGameIdler::GetElementTooltip` (VA `0x6C64C4` -> `0x6C927A`) takes the branch when the element
under the mouse has a type name **beginning with** `EventOptionButton` (17 characters) or
`EventPOptionButton` (18): it splits the instance name at `_`, makes a scope - the seed, a random
state of the seed, FROM by the tag, **the country the player's** (`CCurrentGameState +0xC30`), the
province where it is not 0 - finds the event by id, and shows `GetEventOptionEffectsText(i)`: that
option's `CEffect::GetBlockText`, trimmed. **The event's own scope country, FROM province, rebel
faction and combatant are not used.** `confirmed`.

### 3.5 Pressing, closing, the timeout

- **A click** (`OnOptionClicked`, `0x5C4890`) takes the first button whose `+0x2C` is set (the pressed
  flag, `inferred`) and posts `CSelectEventOptionCommand(event, scope, i)` on the session's channel,
  clearing `alive`; on the next frame `Update` answers false and `CEU3Idler::Update` deletes the
  window.
- **Closing**: the destructor takes the event off the idler's open list (`+0x188`) and closes the
  window. **There is no close button.**
- **The timeout**: once the game's tick passes the opening plus **four months**, `Update` itself
  posts **option 0**, whatever the `ai_chance`.

### 3.6 Shown, hidden, several, `major`

- The window is shown and the sound `message` played **unless the custom-game settings' first byte is
  set** (written at VA `0x65A78C` in `CInGameIdler::Enter`), when it is made hidden. `Update` shows it
  again, and plays the sound again, whenever it finds it shut while that byte is clear.
- **All of `Update`'s work sits behind "the window is open"**, so a hidden window answers true for
  ever and **never times out**.
- **Several events** each get a window of their own at the same place in the file; an event already
  on the open list gets no second one (section 1.1).
- **`major`, `is_triggered_only` and `fire_only_once` are not read by the constructor** (`+0x170` to
  `+0x172`); the same listing reads `+0xC`, `+0x70` and `+0xD4`/`+0xD8`, the control.

### 3.7 The decision screen

The list is `CDiplomacyView`'s window `country_diplomacy` (`tfh/interface/country_diplomacy.gui`):
**`decisions_listbox`** (at 50,565, 290 x 135, spacing 1). `confirmed`.

- **Rebuilt each time the diplomacy screen is shown**: `RebuildDecisionList` (`0x38C560`) has one
  caller, `CDiplomacyView`'s slot 2.
- **Its scope**: the player's country, everything else null, seed 0.
- **What is listed**: only the **diplomatic** decisions (the database's `+0x0C`); one whose
  `potential` fails is left out; one whose `allow` holds is pushed to the **front**, one whose `allow`
  fails to the **back** - so **those that may be taken come first in reverse file order, then those
  that may not in file order**.
- **While open**, every row's slot 8 runs from `CDiplomacyView`'s slot 6 while the list box is open:
  it asks `allow`, then `potential`, and **disables the button where either fails - and otherwise does
  nothing, so a disabled button is never enabled again** until the screen is shown again. A row whose
  `potential` fails stays listed until then.

Each row is the window **`diplomatic_decision_entry`** (300 x 20):

| element | kind | what goes in it | tooltip | |
| --- | --- | --- | --- | --- |
| `name` | instantTextBoxType | `LocaliseEventText(<decision>_title)`, trimmed | `LocaliseEventText(<decision>_desc)`, trimmed | confirmed |
| `select_button` | guiButtonType | the file's `SELECT`; **disabled where `allow` fails** when it is made, or where `allow` or `potential` fails at any update | the `effect` block's text (`CEffect::GetBlockText`, depth 0) | confirmed |
| `info_icon` | iconType | the file's `GFX_info_diplo_decision`, untouched | the `allow` block's `CAndTrigger::GetBlockText(0, 0)` - the technology requirements' rendering, green and red asterisks | confirmed |

A decision that may not be taken shows only a disabled button; there is no grey text. Before any of
the three tooltips the scope's random state is set back to its seed. Any other element of a row has
no tooltip. **A click** (slot 4, `0x20F7B0`) calls `PostExecuteDecisionCommand(decision, scope)`,
which makes and posts `CExecuteDecisionCommand(decision's key, scope)` - **`allow` is not asked again
at the click**. The AI posts the same command through the same function (VA `0x89D95D`, `0x89DFEC`).

### 3.8 What looks wrong and is what the bytes do

1. Decisions that may be taken are listed in reverse file order.
2. A decision's button is never enabled again until the screen is opened again.
3. A row whose `potential` fails stays in the list.
4. An unanswered event takes option 0 after four months, but only while its window is shown.
5. The option buttons cannot be pressed for the first second.
6. An option's tooltip is worked out in the player's country, not the event's.
7. `COUNTRY_ADJ` and `CONTINENTNAME` are not localised.
8. The `immediate` block's effects are written under the description.
9. Options stack upward from a fixed bottom, with no cap.
10. The province's window is chosen by the scope having a province, not by the event being a province
    event.

### 3.9 Traps hit

- **Trap 1**: `g_decision_database`'s comment gave the list's code as `0x78C560`, a VA (rva
  `0x38C560`).
- **Trap 2**: the known pair `0x5BF3CD`/`0x5BF3D0` bounds `GetEventOptionEffectsText`.
- **The decompiler** typed `RebuildDecisionList`'s 0x10-byte list nodes as `CDecisionDatabase`, and
  gave `CDecisionEntry`'s constructor the idler as `this`; both read off the listing.
- **A name that fits one use**: `SubWindowMap_Add` (`0x6C44F0`) is also how `LocaliseEventText`
  appends its replacements - a plain `{string, ptr}` vector append. Not renamed.
- **Collisions**: `0x598760`, `0x598800`, `0x5986E0`, `0x598A00` and `0x608540` left to
  `decisions.json`; `0x60AB40`, `0x275130`, `0x275160`, `0x2751C0` and `CInGameIdler
  +0x188`/`+0x18C`/`+0x190` to `event-firing.json`, which calls that list "pending events" - it is
  the set of events with a window open, slot 62 adding to it as the window's constructor ends and slot
  63 taking off in its destructor. The two names describe one thing.

### 3.10 Not established

- What is drawn when the picture file is missing.
- What a button's `+0x2C` is (the pressed flag, inferred).
- What the custom-game settings' first byte means.
- The order stacked event windows are drawn in.
- How often `CDiplomacyView`'s slot 6 runs; the list box's slots 20 and 21 at the end of the rebuild;
  the rest of `CEU3Idler::Update`; the key of the adjectives' table (VA `0x517AC9`).

**Frontier:** `0x67CCB0` (`CEU3Gui` slot 3, the factory of elements by name), `0x67CEA0`,
`0x6C4FE0`, `0x6BA9A0` (the picture's drawable), `0x37E530`, `0x37F490` (`CDiplomacyView` slots 6
and 10), `0x60C430`, `0x1D49D0`.
