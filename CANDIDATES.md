# What to read next, and why

The work queue. `PROGRESS.md` is the scoreboard and is generated; `CLASSES.md` is the prose account
of each class that has been read; this file is hand-written and says what is *worth* reading next,
with enough of an anchor that nobody has to find it twice. Read `TRAPS.md` before starting any of
it.

Addresses are virtual, based `0x400000`, with the rva beside them where both are given. That is
trap 1 and it is still the most frequent error.

**Cleaned out 2026-10-02.** Everything answered was removed - the `Done` archive that used to run
to 485 lines, and the four items in the open list that had since been settled. What each findings
file established is in that file; the index at the end of this page says which one to open. Where an
answered item left a residue that is still open, the residue is carried below under its own
heading rather than left buried in a struck entry.

**If a findings file cites a section of this one that is not here**, it was removed in that
cleanout and the whole of the old text is in commit `e73600a1d`. Three files were written from
briefs built out of *What those left behind*, and `findings/FINDINGS-survivors.md`, `findings/FINDINGS-production.md`,
`findings/FINDINGS-politics.md` and `findings/FINDINGS-revolt.md` all quote this file as it stood. Those citations are
true about the brief that was given and have been left alone on purpose.

**Two frontiers are closed and are never the prize any more.** All 266 `LoadKey` switches have been
read (`findings/FINDINGS-definitions.md`, `findings/FINDINGS-script.md`), and `fieldmap.py` has the offset most keys
store to, so a loader is never the thing worth reading. What is missing nearly everywhere is
**runtime behaviour** and **what a field means** - which is why the queue is now mostly live tests
and AI bodies.

## The queue

### Who each open item is for

**The record has two consumers and they want different things from it.** BiceLib needs a layout
it can read in a live process; OpenHOI3 needs a rule it can implement, and is forbidden the
offsets entirely. So the open items carry a tag:

| | |
| --- | --- |
| `[dll]` | a layout, an offset, a vftable slot, a signature - what lets code find a field in a running game |
| `[game]` | a rule, a formula, an ordering, a cap - what a reimplementation has to get right |
| `[both]` | a behavioural reading that also pins a layout. **Every live test is this**, because it needs the DLL to run and answers a question about behaviour |

An untagged open item is **tooling or record hygiene** - promoting a script, a hand edit the
merge cannot do, a name that needs the maintainer's call. Those serve the record rather than
either consumer.

**The tags are not a priority order, and `[dll]` is not the lesser one.** The DLL is the only
consumer that *executes* against these facts, so a wrong offset there reaches a running process
while the same error in a design reference costs a paragraph. The tags exist so that neither
queue becomes invisible when the other is the interesting one - which happened within an hour of
the two-consumer split being described, when the whole queue was proposed for re-aiming at the
rewrite.

Only the **open** sections are tagged. The wave archives below are history and are left alone.

**Wave 9 is planned below, four agents.** the maintainer's priority order still holds: the interface layer,
then the last unread AI blocks, then core engine flow, then the rest. What is not scheduled is
further down.

### Wave 9, 2026-10-02 - four agents, and what the plan got wrong

**The plan below was checked against `ghidra/project.json` before launch and four things in it were
wrong.** Recorded here rather than quietly fixed, because three of the four are the same failure and
it is the one that keeps happening: *this file described as unnamed or unsettled what the record had
already settled.* That is trap 14 from the direction the trap file warns about least - a queue entry
goes stale while the record moves on under it. The briefs went out corrected.

| in the plan | what the record actually says |
| --- | --- |
| `0x8D93B0` is "**unread**" | the *body* is unread; the function is **already named** `CAIUnit_EstimateAttackOdds` with a full signature, `inferred`, and its two `CUnit +0xF0` readers are already recorded as instruction entries at rva `0x4D9825` and `0x4D9C3A` |
| the naval block "at `0x4D2418`" | that is an **rva**; the VA is `0x8D2418`. The air range in the same sentence was given as VAs - **trap 1 inside one sentence**, which is exactly the wave 7 mistake |
| `0x23A460`'s "extent is unsettled (two `ret`s, so trap 2 or trap 3)" | **settled**, and recorded as settled: trap 2, rva `0x23A460`-`0x23A83C`, `0x3DD` bytes, 283 instructions, with `cfg.py` showing no edge into the neighbour. Also already named `ResetGameStateToStartDate` |
| "the ledger window's class: `0x3C1ED0` is in no vftable" | `0x3C1ED0` is an rva, already named `LedgerPage_Update`, `confirmed`. What is in no vftable is the **class of its `void* ledgerWindow` parameter** - a different question, and the brief was rewritten to ask it |

`0x27B240` was also already named (`CGameState_ResetAtHistoryExecute`), which the plan did not say.

**No game was running when this wave launched**, so all four agents were briefed for static work.
That matters most for agent C, whose four items were written as live questions - but each has a
static route named in `FINDINGS-guilive.md` itself, and that is the route it was sent down.


**What came back.**

**All four came back and all four corrected something already published.** That is the pattern worth
noting: the wave's value was less in the new ground than in what reading the bytes did to claims the
record was already making.

| agent | what it settled | what it overturned |
| --- | --- | --- |
| A `FINDINGS-attackodds.md` | `CAIUnit::EstimateAttackOdds` read end to end - it returns `ourDamage / theirDamage`, and `esi` is a `CUnit` by a five-link chain, so the land half of `FINDINGS-combatmods.md` is **promoted to a reading** | the recorded **signature** (`__fastcall` is wrong, `ret 16` against the function's `ret 20`); the published "monotone in committed strength" claim, which the *caller* enforces; and `CCombat` slot 17's "only one call site" |
| B `FINDINGS-airnaval4.md` | air phase 4's seven missions, the convoy raid's roulette draw, and three unnamed compiled-in thresholds | **phase 4 has two arms, not three** - `plan_air_stance` must be **2** for five of the seven missions, and the live stance is 1 on 1,125 of 1,126 formations. Also `0x4A7450`/`0x4A74D0` are **sunset/sunrise**, which inverted `FINDINGS-theatre2.md`'s "loads only in the dark" |
| C `FINDINGS-guistatic.md` | `CFixedWindow`'s **two** `CGuiObject*` child lists; registries 1 and 5 are the `3dButtonType` and `threeDguiType` indexes, empty because those keywords appear **zero** times in mod or vanilla; the ledger is a `CStatisticsLedger`; `CCheckBox` named from the widget's own string | `FINDINGS-guilive.md`'s RTTI negative - **wrong for two of six names despite carrying a positive control**, because the sweep spelled it `Checkbox` and the image spells it `CheckBox`. Also its `0x18`-byte node size (it is `0x10`) and `LedgerPage_Update`'s recorded parameter |
| D `FINDINGS-session2.md` | `0x27B240` end to end - its last 0x560 bytes **parse `gameplaysettings.txt`** into the game state, a live but unused mod hook; `0x23A330` named | `CInGameIdler +0x1790` is the **`CEU3Application`**, not a `session_manager` - `SessionManager` occurs **zero** times in the image, and the shipping DLL was already right where `project.json` was wrong |

**Landed:** 21 addresses and 27 struct fields merged; the record went 2,270 -> **2,275 functions** and
2,707 -> **2,739 fields**, labels 543 -> 559. Recorded signatures that disagree with their `ret` went
88 -> **87**.

**The Ghidra apply ran and reported `failed: 2`** - the pass mark, and both failures are the two
documented over-long bodies (`TernarySearchTreeFind` inside Ghidra's `GuiTypeTree_Find`, `MT19937Next`
inside its `CSimpleRandom::GetInteger`). It named 2,273 functions, 559 labels, 2,033 signatures, 88
struct fields and 206 virtual tables, and the two `CInGameIdler` renames landed visibly
(`+0x1790 application: named session_manager`).

**It ran against a scratch copy, not the maintainer's project.** Ghidra was open on `Hoi3_v12.1.2` at the
time - a live lock and a 1.2 GB `javaw.exe` - and the contract in `fragments/README.md` says
concurrent headless runs fight over the lock. So the names are in `project.json`,
`bicelib_findings.json` and the scratch database; **applying them to `Hoi3_v12.1.2` is the maintainer's step**,
the same division as `Deploy.ps1` and the game folder.

*An earlier version of this entry said the Ghidra installation was not on this machine. That was
wrong - the search behind it was `find /c -maxdepth 4` and the installs sit at depth 6, under
`Documents\Ghidra\ghidra_*_PUBLIC\support\`. The exact command is in `ghidra/README.md`.*

**Three schema faults in the agent contract, found independently by three of the four agents** and
now written into `fragments/README.md`: the field list is `struct_fields` and a fragment saying
`fields` lands nothing silently; `confidence` takes only `confirmed`/`inferred` although four
documents and `project.json` itself use `likely`; and **every** key in `ADDRESS_KEYS` must be
present, so a signed entry still needs `"no_signature": null`. The first of those was **my** error in
all four briefs.

### Wave 10, landed 2026-10-02 - four agents, and the record arguing with itself

**All four came back; three of them overturned a published conclusion, and two of those three found
the contradicting fact already sitting in `project.json`.** That is the wave's lesson and it is a
process one: nothing in the pipeline compares a new conclusion against what the record already says.

| agent | what it settled | what it overturned |
| --- | --- | --- |
| A `FINDINGS-aihelpers.md` | both AI combat helpers read end to end. **The AI keeps its own copy of the land combat modifier model** - 11 of 20 modifiers identical, 4 partial, 6 absent - and it **adds** fractions where the battle **multiplies** clamped factors. The helper is the **dominant** term, not a garnish: single terms reach ±4.0 against an engagement factor whose maximum is 1.0 | an **amphibious sign bug** (`subsd` where the river arm has `addsd`, both guarded by the same `jns`), making an opposed landing the most attractive move in the AI's model; `FINDINGS-combatmods.md`'s stacking rule, which is right for the defender and wrong for the attacker; and §10's callee list, which attributes four functions to both helpers when two are defence-only |
| B `FINDINGS-sigaudit.md` | the 87 disagreements were **30 tool and 57 record**, and the run now reports **1** - the one left is a recorded address that is not a function start | **`Hoi3CString` by value is `0x1C`, not `0x18`** - and the proof was already in `BiceLib/GameClasses/CTrait.hpp`, which strides a `Hoi3CString[16]` by `0x1C` and checks it. Three *invented* parameters removed as a result. Also `CMap::MapPath` is not a `CMap` member, and five records write the register as a C comment, which reaches nothing |
| C `FINDINGS-guicontainers.md` | `+0x414` is the **subwindow map**, the engine's own word, from its warning at `fixedwindow.cpp:1042`; all 28 `CWindowType::LoadKey` tokens tied to their containers, turning three `likely`s into `confirmed`s | `child_windows_begin` on `+0x2FC`, which is the vector half of `AttachChild`'s pair and not a child-window container; and "fourteen containers from `+0x174`", which is wrong twice - there are thirteen, from `+0x184` |
| D `FINDINGS-airstance.md` | `0x4B4740` fills all four `air_target_provinces_*` lists, reached by a plain `lea reg,[agent+0x1FC]`; the scorer is a **mean map distance** and the lists are **lowest-first**, so low is good | **`FINDINGS-airnaval4.md`'s headline.** The AI *does* set `plan_air_stance` to 2, on every agent, every `ProcessAI` pass - so the five strategic and naval air missions are **live**. The live distribution that said otherwise was read off air formations; the gate reads `agent->unit`, the army. Also `CUnitPlan::SetActive` resets to **1**, not 0 |

**Landed:** 85 addresses and 40 struct fields offered, 20 new addresses and 40 fields merged, the
rest revisions. Record **2,275 -> 2,291 functions**, **2,739 -> 2,771 fields**, labels 559 -> 563,
signatures 2,033 -> **2,050**. Headless apply **`failed: 2`** - the pass mark, both the documented
over-long bodies. **Signature disagreements 87 -> 1.**

**Two agents' work collided productively.** B's patched checker immediately flagged three of C's
brand-new signatures: C wrote `__thiscall` with `this` implicit *and* the real parameter left bare,
which under Ghidra's positional rule puts `name` in ECX. Fixed by spelling `this`. A tool patch that
catches a defect in another agent's output the same hour it lands is the best evidence it is right.

**What the plan got wrong this time** - the fourth wave running, so it is worth keeping the tally:

| the plan said | the bytes said |
| --- | --- |
| `attached_children_head` sits on `+0x2FC` and `+0x414` may unseat it | it is on **`+0x74`**; `+0x2FC` is `child_windows_begin`. Different claim, and the name **survives** - `AttachChild` writes `+0x2FC` and `+0x74` in one body |
| the `__fastcall` signature bug "accounts for 3, not 49" | 21, not 3. It swallows a **bare** parameter too, not only an `@stack:` one |
| a wrong signature needs a hand edit, because the merge never overwrites one | `mergeFindings.py` has a **`revises`** key for exactly this; 63 revisions landed from a fragment |
| fourteen `CWindowType` containers at a `0x10` stride from `+0x174` | thirteen, from `+0x184`; `+0x174` is an unrelated 4-stride pointer vector `LoadKey` never touches |
| `gameplaysettings.txt`'s grammar makes the hook "nearly useless" | the premise held, the conclusion did not - the save grammar *contains* a `gameplaysettings` key. What limits the hook is **when** it runs |

### Also ready, and cheaper than they look

- ~~**`gameplaysettings.txt`'s key set.**~~ **Done 2026-10-02**, written up as
  `findings/FINDINGS-session2.md` section 7, and the prediction recorded here was half wrong. It
  *is* the game state's save grammar - 21 of the switch's keys appear at the top level of a real
  save - but that grammar contains a **`gameplaysettings`** key of its own (token 1551, arm at VA
  `0x68048A`, recursing through slot 3 into the `CGamePlaySettings` the record already names at
  `CCurrentGameState +0xC90`), so the file is named after a block that genuinely exists and the
  "nearly useless" conclusion drawn here did not follow. `CGamePlaySettings::LoadKey` (rva
  `0x28A550`) takes exactly one key, `setgameplayoptions`, so the nested payload is two ints:
  `difficulty` and `arcade_mode`. What really limits the hook is **when** it runs - `0x27B240`'s one
  caller is `CEU3Application::LoadEverything`, so the parse is at startup, and the lobby writes both
  of those values afterwards and wins.
  **Two things came out of it that are worth more than the item was:** the recorded key list for
  `CGameState::LoadKey` is **short by at least five** (`ai`, `convoy`, `theatre`,
  `strategic_warfare`, `sunk_ships` - all five read by hand off the chained-`sub` arms, with `ai`
  cross-checked because its arm reads the `skip_automation_keys` byte that the record's own field
  comment says gates `ai`); and **45 savegames are on this machine after all**, under
  `Documents\Paradox Interactive\Hearts of Iron III\BlackICE GitHub\save games\` - per mod, not
  in the install - so the plain-text oracle is available and a pass today that reported none had
  simply looked in the wrong two places.
- [both] **`0x27E550`** (VA `0x67E550`, **unrecorded** - checked; the nearest below is
  `CGameState_SetProvincesAndSizePerCountryVectors` at rva `0x27E320`). It installs the game state's
  country list from the database and resizes the per-country vectors; read far enough in wave 9 to
  describe, not to name. On the frontier.
- [game] **`0x4EFA50`** (VA `0x8EFA50`, **unrecorded** - checked) - the province predicate air phase 4 and
  the ops-area scorer both call, and `FINDINGS-opsarea.md`'s own open question 2. Wave 9 read four
  arms into it and reports the record's one-line summary is incomplete.
- [game] **`0x4D0520`** (VA `0x8D0520`, **unrecorded** - checked) - the per-province predicate that excludes
  a convoy province from raiding. Until it is read, "the AI will not raid its own side's shipping
  lanes" is an inference from where it sits.
- **`CGameState::LoadKey`'s key list and `CGamePlaySettings::LoadKey`'s comment** need a **hand
  edit** for the same reason - the merge never overwrites a comment. Add the five missing keys to rva
  `0x27FCB0`, and note on rva `0x28A550` that it is the grammar of a mod's `gameplaysettings.txt`
  inner block and not only of a save's. `findings/FINDINGS-session2.md` section 7 has both, with the
  path-by-path evidence.
- [dll] **`CStatisticsLedger`'s two fields and `LedgerPage_Update`'s signature** still need a **hand
  edit**, but for one reason rather than two: `struct_fields` cannot create a struct that
  `project.json` lacks. **The "merge never overwrites a signature" half of this was wrong** -
  `mergeFindings.py` has a `revises` key and wave 10 landed 63 signature revisions through it.
  `FINDINGS-guistatic.md` §4 has the corrected form (`ShowPage(ledger@EDI, int page)`) and the two
  fields with their evidence.

### Wave 10's three decisions - two done 2026-10-03, one still open

1. **STILL OPEN: `0x450AB0 CreateMapBinCacheOwner` is not a function start.** It is the
   `call 0x486F10` *instruction* at VA `0x850AB0`, sitting inside the function that begins at rva
   `0x450520`; `functionStart` answers `0x450520` and `retsBefore` between them is empty, so there
   is no boundary in between. The author wanted to record *the caller* of the constructor and wrote
   down the address of the call rather than the caller's entry. **Two things follow:** the name never
   reaches Ghidra at all (`buildFindings.py` prints `not a function start, left out:
   00850AB0 ::CreateMapBinCacheOwner`), and it is the **last** of the original 87 signature
   disagreements, since a `void (void)` signature predicts `ret 0` against the `ret 4` found by
   disassembling on from mid-function.
   **Recommended: re-point it to rva `0x86F10`**, which is what the name actually describes. That
   address is a clean function start (`push ebp; mov ebp, esp`), ends `ret 4` at VA `0x4872DC`
   followed by `int3`, publishes itself at the global `0x1A85578` (`mov [0x1a85578], edi` at
   `0x486F8F`), references `'/cache/map.bin'` twice, and has exactly one caller - the very call that
   was mis-recorded. It wants the signature `void __stdcall CreateMapBinCacheOwner(void* owner)`,
   `this` arriving on the stack from the caller's `operator new(0x48)`. The alternative, re-pointing
   to `0x450520`, gives the name to a large loader that does much more than this; dropping the entry
   loses a live name for no gain. **The fact the entry exists to carry - that `map.bin` is the
   graphics side's and not the province graph's - is already applied to `0x8DFA0` and `0x8E2E0` and
   survives any of the three choices.**
2. ~~**`CNavalCombatant::PickTarget`**~~ **Done: renamed `CSubUnit::PickTarget`.** The receiver is in
   ECX and is a `CSubUnit` - the entry does `mov edi, ecx; mov eax, [edi+0xb0]` and `+0xB0` is
   `CSubUnit::unit_ptr`. Checked first that it is **not a virtual** (`vtable.py --holding`: no table)
   and has one caller, `CNavalCombatant::Attack`, so nothing inherits the old qualifier. The reason
   is recorded on the entry so the next reader does not put `CNavalCombatant::` back.
3. ~~**`CDefines +0xAC`**~~ **Done: `CDefinesSupply` -> `CDefinesMilitary`, `supply_defines_ptr` ->
   `military_defines_ptr`.** A live game was offered and **would not have helped** - the question was
   never factual. `definesMap.py --check` lists the blocks `defines.lua` actually has: country,
   economy, military, diplomacy, alignment, map, weather, goods_cost. **There is no `supply` block**,
   so the old name had no referent to be right about, and the pointer and all 178 field names were
   correct the whole time. Only the two labels were wrong. `FINDINGS-supply.md` had recorded it as "a
   naming wart left alone" since that wave, which is why it took a prompt to fix rather than a
   discovery. Nothing in code depended on either name - one doc comment in
   `BiceLib/GameClasses/CDefines.hpp`, one line of `CLASSES.md`, one in `FINDINGS-supply.md`.
   *One thing to know when you apply this:* a struct **rename** leaves the old `CDefinesSupply`
   behind in a Ghidra database that already has it, since the apply creates by name and does not
   delete. `ResetBiceLibOrphans` is the tool for that if it bothers you.

Plus **`likely`, which agent B answered with evidence and a recommendation rather than a change**:
`project.json` holds **219** of them, `buildFindings.py` maps `confirmed`->CERTAIN and
`inferred`->TENTATIVE with a `.get(..., "TENTATIVE")` default, so all 219 already land as TENTATIVE -
*indistinguishable from `inferred`*. B recommends **not** adding the word, because that default means
a **typo** also degrades silently and the validator's short list is the only thing that catches one.
Preferred fix: drop the third word from the three documents and convert the 219. A wrinkle worth
knowing: the Ghidra output *does* have a LIKELY tier with 81 members, but those come from
`buildFindings`'s own hardcoded cases (folded bodies, luabind wrappers) - so a real tier exists that
the record's own `likely` cannot reach, which strengthens B's case rather than weakening it.

## Wave 14 landed, 2026-10-06

Four briefs: the fragment tooling plus the blocked structs, `CContextTrigger`'s scope rebinding, what
a trigger forest costs, and the faction layer. **27 addresses, 18 new structs and 20 struct fields
landed**, which generated **121 new fields** off the eight `inherits`-only subclasses. `buildFindings`
printed no `!` lines; the headless apply gave `struct fields: 450, replaced: 0, failed: 0` and then
`0 / 0 / 0` on a second pass - **the first wave to settle to the pass mark on its own**.

Where the prose went: `findings/FINDINGS-faction.md` (new), `findings/FINDINGS-triggereval.md`
§10-16, `findings/FINDINGS-scopetriggers.md` §11-16, `findings/FINDINGS-diploaction.md` §30.

**The four results worth knowing without opening a file:**

- **`ally = { ... }` is enormously wider than `alliance_with`**, and this had been an open question
  since wave 12. A faction join writes no `CDiplomacyStatus` field at all, and in the 1945 save the
  whole world holds **7** bilateral alliances against **674** intra-faction country pairs. Two of
  those 7 are between countries in no faction, so the implication fails both ways. `is_in_faction`
  is the test for "same side"; `alliance_with` is the test for "we have a treaty".
- **Nothing in the trigger forest is cached, and `and` short-circuits while the tooltip tally does
  not.** The cost is one full tree walk per candidate event per country per game day, from
  `RunDailyEventPass`. Slot 11 - the `"%d / %d"` figure - has exactly **one** root in the image, a
  triggered-modifier panel gated on a day-of-year change, so tooltips do not double anything.
- **A scope switch writes five offsets and nothing else**, so `FROM`, `THIS`, the seed, the rebel
  faction and the combatant provably survive any depth of nesting - while `ally` and `local_enemy`
  keep the *outer* province and `capital_scope`/`sea_zone` throw the country away.
- **Faction leadership is positional and cannot be set.** It is the first member; a join always
  appends. The only promotion path in the image runs when the leader goes into exile, and picks the
  surviving member with the highest max IC.

### Queued hand edits - the first three are done, 2026-10-06

These came out of wave 14 and are listed here because `mergeFindings`' `structs` key is create-only
and the duplicates predate the check that would have refused them.

1. ~~**`CTradeRoute` needs `"inherits": "CRelation"`.**~~ **Done 2026-10-06.** RTTI puts `CRelation`
   at **offset 0** on it and no CRelation field shared an offset with its twelve, so it was safe. Its
   `+0xC first_id` and `+0x14 second_id` - whose own comments already said "Id half of the CRelation
   base's `first`/`second`" - are now folded into the inherited 8-byte tags, which the apply reported
   as `CTradeRoute+0x8 replaced 'first_id' with first`. Generated fields 3036 -> 3040: six inherited
   minus the two folded.
2. ~~**`CBuildingConstruction` and `CConvoyConstruction` have wrong `vftable_rva`s.**~~ **Done
   2026-10-06**, `0x11BDCD4` -> `0x11BDCAC` and `0x11BDD34` -> `0x11BDD04`. Verified off the bytes
   before the edit: `[0x15BDCA8]` and `[0x15BDD00]` hold `0x1611C8C` and `0x1611C38`, which are
   `.rdata` complete-object-locator pointers, so each table begins at the next dword - and
   `[0x15BDCAC]` and `[0x15BDD04]` both hold `0x5501D0`, a real code address and their shared first
   slot. The recorded values were 10 and 12 slots in.
3. ~~**Four duplicate field records.**~~ **Done 2026-10-06**, merged to one each, the survivor keeping
   position zero so the fold order is unchanged. `CDiplomacyStatus +0x14` is now **`CAlliance*`** and
   `+0x1C` **`CGuarantee*`** - both previously reached the decompilation as `void*`, because
   `merge_fields` keeps whichever record comes first - each carrying both halves of the account, since
   the `void*` records held the predicate derivations and the typed ones the `Activate` writers and
   save blocks. `CCountry +0xA8C` and `+0x10B8` were the harmless shape (same name, same type) and
   just have their two comments merged; note the **Lua half still wins their name and type**, so they
   reach Ghidra as `Neutrality`/`NationalUnity` typed `CFixedPoint`, which is item 6's rule and is
   right here.
4. **`buildFindings.py` should print a `!!` line for a duplicate `(struct, offset)`**, the way it
   already does for two address entries on one rva. A one-line `Counter`. **It would print nothing
   today** - item 3 cleared the last four - which is exactly why it is worth adding now: it is a guard
   against the duplicates coming back silently, not a backlog report. The reason to add it at all is
   that a duplicate costs more than a duplicate address entry does, because `merge_fields` quietly
   keeps whichever comes first and the file then holds two answers with neither run complaining.
   Refusing rather than reporting is still the wrong call: a wave should not be blocked on a record
   nobody has had time to merge.
5. **`buildFindings.py` should report its folds.** A field lying inside a larger typed one is dropped
   from the generated output and its text moved into the host's comment, and **nothing says so** - the
   existing overlap warning runs on the post-fold list. Two of wave 14's four agents independently
   concluded that the twelve `CCountryTag` id-half records would start an apply cycle; both were wrong,
   and both would have been saved by one printed line. The shape of that output is a judgement call,
   which is why it is queued rather than done.
6. ~~**`CEventScope +0x10` reaches Ghidra as a 4-byte `CCountryTag *`** over four bytes of tag
   letters.~~ **Done 2026-10-06**, by two rules rather than one, because there turned out to be two
   independent causes. See *The Lua API census* below; the field is now `country_tag char[4]` and
   `CResearchBonus +0x4` is `CFixedPoint` by value. `CList<CSubUnitConstructionEntry> +0x4` is left
   alone and that is now a result rather than a gap: it is accessor-derived, where a `T&` can
   legitimately be a pointer member.
7. **`reconcileFacts.py`'s wording** for the Lua-only row should say "already in the record, through
   the Lua half" rather than "need a struct record first", which reads as 44 missing facts and cost an
   agent a detour.

### The residue - what wave 14 left, in rough order of value

- [game] **The five collector entry points**: `0x4A4F50`, `0x4A51C0`, `0x4A5270`, `0x4A5420`, `0x4A5620`, all
  unnamed, all in `CAIStrategy`'s region. This is **what the whole slot-10 machinery exists for**, and
  reading it from the trigger side got as close as the standing steer allows. `0x4A51C0` is the one
  that takes **text**, which is the shape to know before starting.
- [dll] **`CValueTrigger` and `CIntTrigger`'s slot 7** (`0x5D13E0`, `0x5D1400`, abutting, two different unit
  conventions - `TokenToFixedPoint` into `+0x40` versus an argument-token test against `0x377`).
  Neither class has a vftable of its own, so which body belongs to which has to be argued from the
  derived classes that hold each. Settling it matters out of proportion: **111 of the 156 trigger
  classes are `new(0x44)`**, one dword at `+0x40`, so one declaration each would place that field on
  all of them. **The single biggest remaining win in this family.**
- [game] **`CDeclareWarAction::Apply`'s call at `0xA121CE`** passes `(country, 0, 0)` on a path gated by a
  slot-7 `IsValid` answering false - so it is a faction *leave*. **It looks like declaring war can
  eject a country from a faction**, which would be a real rule nobody has written down.
- [game] **`0x102BC0`**, the capitulation/exile function holding the faction leader promotion. 7 callers,
  four `ret`s between `0x50315F` and `0x5033AD`; worth a brief of its own.
- [dll] **`CCountryList` has no layout at all** - not a struct record, and not special-cased beside
  `CUnitList` in the `CList` pass - so `Allies (+0xF88)`, `Vassals (+0xF78)` and the rest decompile as
  untyped blobs. Giving it the `CList` layout would retire the three hand-added
  `non_hostile_countries_*` workaround records at `+0xF98`-`+0xFA0` at the same time.
- [dll] **`CCasusBelliType`'s 22 loader offsets**, now landable: token table `0x416924`, jump table
  `0x4168E0`, base token `0x78D`. Best given to one agent whole.
- [dll] **`CContextEffect`'s struct** - spec at `+0x20`, object `0x130`, same `CEventScopeSpec`. One
  declaration.
- [dll] **`CTrigger +0x1C[2]`** - a `std::vector`-shaped container of two `0x10`-byte elements; its element
  ctor/dtor (`0x9DB0`, `0xC480`) are referenced from **200** sites, so naming it needs the container
  identified rather than the trigger. A displacement scan **cannot** settle it; that was tried and is
  written up as a trap 12 case.
- [dll] **`CTrigger +0x3C`** - cleared by every container constructor and set to 1 by `CTrigger::LoadKey` at
  `0x5C915B`. No reader identified.
- **`scratchpad/triggersizes.py`** pairs 156 trigger class names with their allocation sizes in one
  command and generalises to any loader that builds its classes with `new`/constructor pairs. Worth
  promoting to `scripts/` by someone who can name it.
- [both] **Two holes in wave 14's own negatives, both stated by the agents rather than found later:** slot
  11's root search cannot see three arguments written with `mov [esp+N]` instead of pushed; and the
  faction layer's "no alliance is created" rests on `0x4E70A0` and `0x4FBC10` having been skimmed only.

## A live check: does `at_sea` lock a fleet's `carrying` list? - 2026-10-07 `[both]`

**This would be a real bug if it holds, and it is cheap to test in a session.** It came out of
settling what `CList +0xC` means (`findings/FINDINGS-factbase.md`).

What is established, both ends off instructions:

- **`CList`'s fourth member at `+0xC` is a deferred-deletion lock.** While set, code that would
  remove a node **marks it and leaves it linked** instead. `CWeatherManager::Tick` reads it at VA
  `0x4B5CD7` and branches: set -> `mov byte ptr [eax+0xc], 1` on the spent node and skip the
  unlink; clear -> relink `prev`/`next` and fix `first`/`last`.
- **`CUnit +0x2E4 carrying` is a `CList<CUnit*>`**, so `0x10` bytes, `+0x2E4`..`+0x2F4`.
  `CheckTransportOverload` (rva `0x1CFBD0`) reads it twice, `add eax, 0x2e4` and
  `mov esi, [edi+0x2e4]`.
- **`CNavy::LoadKey`'s save-token-`0x3FC` (`at_sea`) handler writes a dword there**:
  `mov dword ptr [ebx + 0x2f0], eax` at `0x1CF6FE`. `+0x2F0` is offset `0xC` inside `carrying`.

So on the face of it, **a fleet restored from a save with `at_sea` set has a non-zero lock on its
own carried-units list, and would never unlink a node from it again** - the list would still work,
it would just never shrink. That is exactly the shape of thing nobody notices.

**Why it is a check and not a finding.** A layout where the game deliberately parks a loaded field
in a container's lock slot is strange enough to want confirming, and three readings are possible:
the collision is real and is a bug; `carrying` is not `0x10` here (some other list instantiation);
or one of the two offsets is a few bytes out despite both being instruction-anchored. Nothing
static separates them, because both claims rest on decoded instructions that are individually
sound.

**The test, in one session.** Load a save with a fleet at sea carrying at least one unit, then
watch `CUnit +0x2E4`'s `count` (`+0x2EC`) across an unload:

- if the count **decreases**, the lock is not being set and the collision is not real;
- if the count **stays** while the carried units are plainly gone, the lock is set and the nodes
  are being marked rather than unlinked - the bug;
- and `+0x2F0` can be read directly at the same time: non-zero after loading an at-sea fleet is
  the lock being set, zero means `at_sea` is not landing where it looks like it does.

A second, cheaper angle: compare a fleet that was **at sea in the save** against one that put to
sea during play. Only the first goes through `LoadKey`, so only the first should show the symptom.

The record carries the open question on both fields - `CList +0xC no_unlink` and
`CNavy +0x2F0 at_sea` - rather than a claim, and `at_sea`'s type was corrected from `uint8_t` to
`int` at the same time, since the write is four bytes wide.

## Does only the host run the AI in multiplayer? - 2026-10-13 `[both]`

**The maintainer's understanding is that only the host runs the AI's Lua; the record cannot say,
and one thing it does say argues against it.** Raised while OpenHOI3 made the hour's trading run
side by side, which it had built to give the same result on every machine on the assumption that
every peer runs the AI.

What is established:

- `CCountry::RunHourlyAITrade` (rva `0xDC410`) runs the Lua only where the country has a `CEU3AI`
  (`CCountry +0x1D8`), and **draws on the game state's generator (`+0x124`) only then** - one draw in
  six, then one in ten (`findings/FINDINGS-tradeaid.md`, B1). `CAIForeignMinister::ExecuteDiploDecisions`
  draws on the same generator once a pass (`findings/FINDINGS-eventfire.md`, the table of draws).
- `FireEvent` has no host test, so every peer with a `CEU3AI` for a country would post the AI's
  command - "whether those objects exist only on the host was not read" (`FINDINGS-eventfire.md`, 1.9).
- On a client the hour is advanced by the host's `CHourlyTickCommand` arriving, not by its own frame
  loop (`findings/FINDINGS-commands.md`, the session modes - inferred from strings, nothing run).

So if a client has no `CEU3AI`, it skips draws the host makes, and its generator leaves the host's at
the first one. One of these holds: **the AI objects exist on every peer** (and the maintainer's
"host only" is about something else - what is shown, or who sends); **`+0x124` is not the generator
the peers keep in step**; or **the original desynced there** - its multiplayer was known for going out
of sync.

The reading:

1. **Who creates a country's `CEU3AI`**, and on what condition - whether the session mode (host,
   client, single player; `[session+0x34]`, `FINDINGS-commands.md`) or the local player gates it, and
   whether a client's `+0x1D8` is null.
2. **Whether `+0x124` is the generator the commands' `Execute` draw on** - the one a battle rolls on -
   or a second one kept apart for the AI.
3. If the AI is the host's alone: **how its results reach the clients** - the offers, the event options
   and the trades as commands, presumably, which `FINDINGS-commands.md`'s ordered loop would carry.

A live check would settle 1 at once: two machines in one game, and `+0x1D8` read on the client.

**For OpenHOI3** the answer decides where its AI goes when multiplayer comes: inside the hourly tick
on every machine as now, or out of it into a host-side step that only posts commands, with its draws
kept off the shared generator. **For BiceLib** it decides whether a hook on an AI function fires on
every peer or on the host alone, which the multiplayer-safe command framework has to know.

## Two questions the politics wave left, both against the start save - 2026-10-14 `[both]`

`findings/FINDINGS-government.md` read the politics whole and left two things the bytes and the start save
(`Germany1936_01_01_00.hoi3`) disagree on. Each would be settled by a live read at a new game's first
screen.

1. **The minister pool at a new game** (section A.6). `SetUpCountryForNewGame` appends a historical minister
   only where `start_date <= now < death_date` (`0x4D67D3`..`0x4D67E0`), and a minister with no death date
   keeps the constructor's `g_NullDate`, 1.1.1 (`0x52C3E6`) - so the bytes leave out every minister with no
   death date. The save pools all of them, in file order: 1,998 ids, Hitler among them. No other writer of
   `CCountry +0x160` explains it (swept). **Read live**: a minister with no death date's `+0x58`, and a
   country's pool count straight after `SetUpCountryForNewGame`.
2. **What runs the AI's `Laws()` more than once** (section E.1). The only call of the `Laws` global is in
   `SetUpCountryForNewGame`, once per country, but the start save holds the point that repeated passes reach
   (Germany two laws up in two groups, Japan three in one), with the posted commands executed in between.
   **Read live**: a hook on `PrepareLuaCall_Laws`, counting calls per country before the first hour.

OpenHOI3 follows the save on both until they are settled.

## What the espionage wave left - 2026-10-14 `[both]`

`findings/FINDINGS-espionage.md` sections A to E read the spies whole. What they left, none of it in the way of
building:

1. **What drains an AI's posted command an hour later** (E.1, E.9). Every AI intelligence minister's `spy_date`
   stamp in the saves falls at the hour after the minister's own `(id + 1) mod 24` - Paraguay's home record alone
   in its own hour. Read off the saves, not the bytes. **Read**: the command queue's drain against `ProcessAI`'s
   hour, which would also say when the politics minister's commands land.
2. **Whether `CUnit::UpdateDaily` (slot 32, `0x5BAF70`) runs daily** (B.3, C.4): a unit's intel grant counts down
   once a call, so military intel's 32 and `local_intel_boost`'s 15 are days only if it does. **Read**: its callers.
3. **Two new games from one start differ in 27 priority-0 presences** (A.7): the 9 October saves' start and the 7
   October start save, each one higher, where nothing can raise a priority-0 presence after setup.
   `SetUpCountryForNewGame`'s allocation score is deterministic but for the Lua `AI_GenerateNonHistoricalRelation`;
   why the two came out differently was not found. **Likely answered, 2026-10-14, by OpenHOI3's check**: the Lua
   function is deterministic too, and counter-espionage at home rolls on the two days a new game runs, catching one
   spy at a time in other presences each game - OpenHOI3's own new game differs from the start save in 47 presences,
   each by one spy, all of them catches (`OpenHOI3/docs/mechanics/espionage.md`, section 14). Not checked against
   the 9 October saves.
4. **The covert-operations window** (B.14): what the province view shows of `common/covert_ops.txt`, in what
   order, and who asks a `CCovertOpsMission`'s `is_valid` (`+0x48`). Frontier `0x2E1DB0`, `0x2E2C10`,
   `0x2E1FF0`, `0x44B40`.
5. ~~**The coup's tooltip** `0x4F7EE0` (D.6, D.8)~~ - read 2026-10-14, D.9 (`CoupTooltip`). Left: who raises an alert
   named `intel` (D.1).
6. **Readers through another holder** (C.1): `PEACE_OFFMAP_INTEL` and `OFFMAP_POLITICAL_INTEL` have no reader
   through a country's modifier values, so three minister types do nothing; a reader through another holder or a
   computed offset would have been missed.
7. ~~**What `counter_espionage` really does**~~ - **settled 2026-10-14**, `FINDINGS-occupation.md` section F: the
   reading stands - 55 helps at home only - and the observation describes `espionage_bonus` (42), which BlackICE
   labels "Domestic Counterespionage Difficulty": the target's own, lowering every catch in its land, written green.
   The 22-to-33 gap lies within the rolls' spread (24.9 expected, sd 5.0). As queued: it "works more as a
   'Domestic Counterespionage Difficulty' modifier", with no effect on the player's missions abroad, and its tooltip
   reads inverted in the original. The reading (`FINDINGS-espionage.md`, CatchSpies) has it **added to the base
   chance in the home arm only** - which agrees that it does nothing abroad, and says it helps at home - while
   `espionage_bonus`, read off the target, **lowers** the home chance. **Read**: every reader of modifier 55
   (`+0x1B8`) and 42 (`+0x150`), the modifier tooltip's sign for both (`CModifierKinds` more-is-better), and
   whether the two were swapped somewhere between the definition and CatchSpies. A save pair with counter-espionage
   laws changed would settle the direction. **A measure, 2026-10-14**: with triggered modifiers built in OpenHOI3, so
   that the ninety countries in no faction carry `neutrality`'s +0.1 of each, its start-save check catches 22 spies
   in the two days where it caught 18 without them and the save has 33 - so the reading's formula accounts for part
   of the original's catches and not all of them.

## What the occupation and revolt wave left - 2026-10-14 `[both]`

`findings/FINDINGS-occupation.md` sections A to F (six readers; 131 address entries landed, 13 structs declared, 71
fields; one hand edit, `CRebelFaction`'s size 0xA4; apply 199 `failed: 0`, `struct fields: 0`). It read occupation
policies, a province's whole modifier, revolt risk with suppression's units settled against a save to the
thousandth, how rebels are made and what they do each day and month, undergrounds whole, and settled item 7 above.
What it left, none of it in the way of building:

1. **The AI's undergrounds** (E.9): `0x47FD90`, the area gate, and unit slot 27, the strength the AI sums - its score
   is read by its shape. And `CCountry::GetRandomUnderGroundTarget` (`0x509920`), where the Lua production minister
   builds them.
2. **The province view's refresh** (`0x6DE5F0`) and its `underground` window's gate (`0x6EA920`), read in part;
   which mouse button steps `underground_mission` which way (`0x6EA380`, `0x6EA490`).
3. ~~**`CheckForCombat`'s rebel capture** (D.4, inferred): what it does with the tag it picks after `0x430BFC`, and
   whether the independence branch that reads inverted is ever live.~~ Read on the listing 2026-10-15: the tag is what
   `TakeControl` is called with once no enemy of it stands there (D.4).
4. **The two AI readers of the effective revolt risk**, `0x8B9D46` and `0x8E1AA6` (B).
5. **`ProvinceHistory_LatestControllerDate`'s order** (D.5): "latest" assumes the history list is in date order.
6. **The four lower Ethiopian revolt risks of 20 April** (B.2) cannot be reproduced without saves between January and
   April; a save of the next game with an occupation in progress would check the step day by day.

## What the building-queue wave left - 2026-10-15 `[both]`

`findings/FINDINGS-buildingqueue.md` sections A and B (two readers; 52 address entries landed and 9 revised, 3 structs
declared, 26 fields; apply 206). It read a building line whole - the command and who posts it (the production
screen's confirm dialog, the province view, the AI's Lua), the price (`cost` and `time` scaled by one category
discount, 159 of 171 lines in seven saves to the thousandth and the rest explained), the day's work and the line's own
cancel test, the line on the screen, the delivery (a built level that the day's repair fills), the building waiting to
be placed, where each building may go and the placing map. What it left, none of it in the way of building:

1. **The province view's building button** - `CBuildingMember`'s update and enabling (`0x6DC380`), its constructor
   (`0x6DB560`), and which buildings get a member.
2. **`CCountry::GetRandomUnderGroundTarget`** (`0x509920`), where the AI's production minister puts an underground.
3. **A building at nought working level after it is finished**, and the repair that fills it, against a running game:
   no save catches one part built.
4. **The confirm dialog's small things**: the Ctrl key's slot, the steppers' repeat and their floor, how a close byte
   destroys the dialog.
5. **The in-game screen's slot 78** (`0x64AB10`), a province message's Goto, and the rest of `CInGameIdler_HandleInput`.
6. **When a new building's picture appears** - the two callers of `ProvinceGraphics_UpdatePictures` (`0x63F56E`,
   `0x8558BC`).

## What the province-view wave left - 2026-10-15 `[both]`

`findings/FINDINGS-provinceview.md` sections A, B and C (three readers; 56 address entries landed and 3 revised, 4
structs declared, 37 fields; apply 208 `failed: 0`, `struct fields: 0`). It read the view whole: it follows the
selection (a listener on every province), its refresh and its every-frame update, each element with its figure, gate and
tooltip, the weather strip, the building columns with their pips and keyboard shortcuts, the `underground` window to its
end, the covert-operations panel and the allied-objectives panel with `CSetAlliedObjectiveCommand`. Corrected:
`BuildProvinceViewTooltip`'s argument order, `CSendCovertOpsMission`'s row offsets, `FINDINGS-aifields.md`'s slot of
`CSetAlliedObjectiveCommand::GetTypeId`. What it left, none of it in the way of building:

1. **What a click picks** where a counter and a province overlap (`0x6416D0`), and the click-or-drag test (`0x64D850`).
2. **Input slots 10, 11 and 12 of in-game-screen `+0x1C`** as Shift, Alt(?) and Ctrl - slot 10 = Shift is borrowed.
3. **The glue's slot 1** as a left press (*inferred*).
4. **What the asked ally sees of an allied objective**: `CAlliedObjectiveMember` (`0x2B5A40`, `0x2B68A0`, `0x2B69E0`),
   alert 15 `alert_allied_objectives`, the `allied_objective` map object.
5. **The `flag` tooltips** of the allied-objectives rows, which hang on the `province_view` group's recursion
   (`0x6C3620`).
6. **`CBuildingMember`'s size**, 0xA0, not in its struct record (a hand edit `mergeFindings.py` does not make).
7. **The custom game's helpers** `0x4208B0`, `0x41B700`, `0x41B370`, `0x6E3D90`.

## What the convoy-line wave left - 2026-10-15 `[both]`

`findings/FINDINGS-convoylines.md` sections A and B (two readers; 12 address entries landed and 9 revised, 1 struct
declared, 5 fields; apply `failed: 0`, `struct fields: 0`). It read the convoy line whole: the command with its amount in
EDI, `Execute`, the four price getters, the line's slots (slot 14 empty, so a convoy line is never priced again),
`Deliver` (ten ships an item), loading and saving, the Lua constructor; and the production screen's two buttons, the
confirm dialog's convoy modes, the `(+N)` counts and the queue line. Corrected: `Deliver` is slot 9 and answers a `bool`;
the command reserves `1 + 2 x amount` ids; `OnAccept` passes `serial` as the amount; `CBuildQueueEntry::Update` picks a
category icon only for a unit line. What it left, none of it in the way of building:

1. **Two screenshots**: the transports dialog (is `on_complete_icon` drawn?) and a queue with a convoy line beside a unit
   line (which category background?); and a save with a part-built transport line loaded paused (share 0?).
2. **`CInGameIdler` slot 60** (`0x274ED0`) and its callee `0x3C1D30`, which an order calls for the played country.
3. **The per-ship prices** `0x1A9D0`, `0x1AA50`, `0x635B0`, and the AI's counters `0x4A24D0`, `0x4A25E0`.
4. **The build-queue list sync** `0x406460` and its caller `0x3FCF60`, with its cap of 128 entries a call.
5. **`counter_type`'s slot 73**, called on every queue line.

## What the weather wave left - 2026-10-15 `[both]`

`findings/FINDINGS-weathersim.md` sections A, B and C (three readers; 55 address entries landed and 23 revised, 1
struct declared, 35 fields; apply `failed: 0`, `struct fields: 0`). It consolidated the three earlier weather files into
one implementable account and checked it against two saves an hour apart and the base game's adjacency cache.
Corrected: the frozen branch between -5 and 0 C under rain, the front's over-100 test, `IsAngleWithinArc`'s arguments,
the bearing's lack of a wrap and the naval-base default, `ComputeProvinceClimate`'s band D, `CProvinceTemplate +0xA2` as
the **northern** hemisphere, the new-game caller (`0x3DC89` is the console command), the weather mode's map style (0, not
0xB), and `0x33D460` (an arrival estimate, not a tooltip). What it left, none of it in the way of building:

1. **Three screenshots**: the weather mode zoomed out (do clouds draw?), a province colder than -5 C beside a warmer
   one at border zoom (the strips), and a province's tooltip in the weather mode (no name?).
2. **The generator's seed during a new game's pre-roll** (`0x311EA0`, `0x2D7AD0`), and whether anything between the
   hourly reseed and the weather tick draws.
3. **Whether a single-player game ever sees the in-game lobby** (`Session +0x236`, `CIngameLobby` `0x2913F0`).
4. **`FINDINGS-mapmode.md`'s style table**: other rows look wrong (`0x667920` writes 0xE, `0x667B50` 0xF, `0x6678A4` 0xD).
5. **`CMapProvince +0xC`**, which decides the style-0 texture's green; the clock's slot 5 units; the `+0x64` map object
   group.
6. **`PropagateHighPressure`'s record name**: `this` is the seed province, not the manager.

## The planned next wave is in `WAVE.md`

**It is not in this file any more.** `WAVE.md` holds the wave that is planned and has not launched,
on its own, because finding the plan in five hundred lines of queue and archive was a search rather
than a glance. This file keeps the standing backlog and every landed wave's result.

**Wave 13 has landed** - its result is two sections down. **Wave 14 is written into `WAVE.md`
and has not launched**: four briefs, the first of which teaches the pipeline to create a struct and
lands the 37 classes blocked behind that, and the other three take the evaluation half of the
script language and the faction layer. So `WAVE.md` is current, not stale, and the paragraph here
that said otherwise was itself stale within a day of being written - which is the drift the
two-file contract at the top of `WAVE.md` exists to prevent. The AI collector has now been held out
of four waves running.

### 2026-10-05, from `TODO.md`: the air defence stat, and it is not a scale bug

**`air_defence` has no consumer in any combat path.** `findings/FINDINGS-airdefence.md` has it in
full. The TODO asked whether the stat misses the fixed point system or is a magnitude too low;
neither. It is parsed by the same `TokenToFixedPoint` as 42 of its 44 siblings (`air_attack` is the
positive control, byte-for-byte the same four instructions), and divided by the same `1000.0` in
all three unit stat panels. The one combat function in the image that reads it,
`CBomberCombatant::FireUnit` (`0x160B90`, named this session), multiplies it by the target's
`combat_defend_product` and writes it back to its own frame slot, where **nothing ever reads it** -
five accesses to the slot, no esp alias, decode verified by recursive descent reaching 829 of 829
instructions. MSVC kept the store because the `imul` reads it on the next iteration: a dead cycle,
not a dead store.

Every air and bombing roll instead uses a flat `CHANCE_TO_AVOID_HIT_AT_NO_DEF` - four sites, all
clamped to 99000, none of them reading `BASE_CHANCE_TO_AVOID_HIT`. `CUnit::RollToHit`, which is
where a defence stat buys anything, has **exactly one caller in the image** and it is
`CLandCombatant::FireUnit`. So the mechanic is land-only by construction. In BlackICE that means a
flat 30% chance to be hit per shot for every brigade, ship and wing under air attack, whatever its
air defence; an AA brigade's `air_defence = 25` is inert and its `air_attack = 22` is the live half.

**And the same question about `sea_defence`, asked by a player a few hours later, has the same
answer only cleaner**: neither `sea_defence` (+0x160) nor `surface_defence` (+0x174) is read
in any combat function - 3 definition-pointer reads each, none in the combat classes, and a
654-function closure from the naval roots with no `+0x160` read in it. The positive control is
in the same function: the identical filter finds `sea_attack` twice and `hull` three times in
`CNavalCombatant::Attack`. `hull` is the ship survivability dial, as a straight divisor on
both kinds of damage. That also closes `findings/FINDINGS-combatmods.md` §9's open question -
naval does **not** have the land `defences_used` structure, because `CUnit::RollToHit` has one
caller and it is `CLandCombatant::FireUnit`. All five stats now carry comments on
`CSubUnitDefinition`, which had none.

Two corrections to the record came out of it, both now in `project.json`:

- **`CSubUnit + 0x54`'s "read at 0x56645E and nowhere else" is false** - there is a second reader at
  `0x160E5B` - and the conclusion built on it survives, because that second reader's result is the
  discarded air defence value.
- **`CCombatant + 0xB0` `front_line` is the land family's layout, not the base's.** The air and
  bombing combatants use the same offset as a count with an inline `CSubUnit* targets[1024]` at
  `+0xB4`. The allocation sizes settle it: `CLandCombatant` is **0xE4**, `CAirCombatant` and the
  `CBombTargetCombatant` family **0x10B4**, `CBomberCombatant` **0x10E8**, and `0x10B4 - 0xB4` is
  exactly 0x1000. So `sizeof(CCombatant)` is 0xB0 and the field belongs on `CLandCombatant` - which
  has no struct record to move it to. **That is a third live instance of wave 14 brief A's
  blocker.**

What it left open, and none of it is urgent:

- **`0x346260` and `0x499770`**, the two `air_defence` readers named only by address.
- **`0x163110`**, the other half of what `CGroundTargetCombatant::Attack` forwards to, unread.
- **`StaticAntiAirTerm` (`0x162370`, `likely`)** read only as far as `STATIC_AA_SCALE` and the
  `[side+0x114]`/`+0x258` value it scales. The province's anti-air is a third channel and reading
  it through would close the anti-air picture.
- **The two live checks** in the findings file: a hook on `0x160D44` to prove the path is reached at
  all, and one on `0x160FDE` to show the threshold never moves with the target's air defence.
- **Whether this is worth a mod-side answer.** If the stat is inert, every `air_defence` line in
  `units/*.txt` is documentation rather than balance, and the AA that does work is `air_attack` plus
  the province's static AA. That is the maintainer's call, not a reversing question.

### Wave 13, landed 2026-10-05 - four agents, and the headline was that a measurement was misleading

**The wave's shape: brief A's own premise did not survive brief A.** The wave was planned around
"713 fields the generated record holds that `project.json` has no field for", read as a measure of
unread layout. It is not one. **386 are inheritance copies** - Ghidra has no struct inheritance, so
`buildFindings` stamps a base's fields onto every derived struct - and **216 are generated `CList`
plumbing**. `CAir` 60, `CNavy` 60, `CArmy` 59 are `CUnit`'s fields counted three times. The
actionable set is **111**, and the unit classes were never the hole they looked like. *Taking that
count for unread layout is how `CAir` got onto a queue.*

| agent | what it settled | what it overturned |
| --- | --- | --- |
| A | 111 actionable fields triaged, 67 landed; 108 name disagreements classified; `reconcileFacts.py` and `crossFragments.py` written; `--check` taught to compare `struct_fields` across fragments | `CCountry +0x604` is **`TotalIC`**, not `base_ic`; `+0xF34`/`+0xF38` are **`isSubject`/`Overlord`**, not `has_faction`/`faction_leader_tag`; trap 4's holder check had only ever been run against the vftables |
| B | there is **no `CEffect` slot 12** - five sibling middles each declare their own, and one slot index carries two unrelated signatures; a government in exile reads **its own** pool | the plan's replacement reading of the resource-trigger branch, which said the branch does not select a different pool. It does |
| C | the war-goal chain end to end; `0xF50A0` is a **breadth-first spread**, not an adder; `CDiplomacyStatus::LoadKey` gives ten keys to ten offsets | "adding a war goal consumes the casus belli" is no longer inference - the function's own key is `WELOSECB`; `0xF50A0` has seven call sites, not four; trap 2's prologue set needs `0xC6` |
| D | `+0x59` has **no reader**, from a 60-site census of the whole image; `check_variable`'s side effect is **erased by the next save**; every regiment has a name | **`surrender_progress` was inverted in the record** - high means about to surrender; `CEffect +0x14` is a byte written 41 times by `LoadKey`, where the record said nothing touched it; `CTernaryNode`'s three links |

**Counts:** 2,478 -> 2,504 functions, 2,232 -> 2,260 signatures, `project.json` 2,232 -> 2,311
fields. `checkSignatures` 1,573 entries none disagreeing, `checkrefs` 658 all resolving, headless
apply `failed: 0`. Write-ups: `findings/FINDINGS-factbase.md` (new) plus sections appended to
`FINDINGS-effects.md`, `FINDINGS-numtriggers.md`, `FINDINGS-diploaction.md` and
`FINDINGS-negatives.md`.

**Two results were overwrites and both were verified off the bytes by the collecting session**
rather than taken on the agent's word, because a wrong new name costs little and a wrong overwrite
costs a published claim. `0xFCC60` really is `1000 - clamp(controlled*1000/owned)` and the caller
really does take the occupied share as the multiplicand with unity as the divisor, so the direction
reverses; and `CCountry::UpdateIC` really does write `+0x604` and `+0x60C` from one register and then
scale, floor and re-read only `+0x604`. That check is now a standing rule - see the report format in
`CLAUDE.md`'s subagent section.

#### What the wave changed about how a wave is run

- **Agent reports now have a required shape**: a 2-5 sentence synopsis, then a table of every
  function the fragment touches marked `new` or `revised`. Wave 13 came back in four different
  shapes and finding "what actually changed in the record" was four separate searches. In
  `CLAUDE.md` and in `WAVE.md`'s standing rules.
- **The `revised` rows are the ones to verify.** See above.
- `mergeFindings --check` now refuses a cross-fragment `struct_fields` disagreement, and
  `scripts/crossFragments.py` reports agreements as corroboration. Running it over
  `fragments/merged/` found **six field disagreements that had already landed**, one pair resolved
  by merge order rather than by anything checking.

#### Mod-facing, for the maintainer rather than for the record

1. **Fifteen `remove_brigade` lines in the mod are dead because of case.** Fourteen are one
   systematic typo - `Kampfgruppe` for `KampfGruppe` - all in `events/KampfGruppen.txt`; the
   fifteenth is `Thomas Mcguire` for `Thomas McGuire` in `events/battlecommanders.txt:2740`.
   `events/KampfGruppen.txt:712` also has `brigade_in_combat = "Kampfgruppe Bock"`, which will have
   the same problem if that trigger compares the same way - **that trigger was not read**.
2. **`enemy_ic_ratio` compares MaxIC**, i.e. raw province IC before the global and technology
   scaling, before the resource cap and before lend-lease. It is not a ratio of the IC either
   country runs on. `total_ic` reads the scaled total.
3. **`money = 0.5` means half a unit as a trigger and zero as an effect.** All seven `*PoolEffect`
   classes are `CIntEffect` heirs, whose scalar is `atoi(text) * 1000`; the six triggers are
   `CValueTrigger` heirs, whose scalar keeps the decimal. Nothing in the script shows the difference.
4. **There is no `fuel` trigger**, though `CFuelPoolEffect` exists - a script can set a country's
   fuel and cannot test it.
5. **`surrender_progress = 0.05` is "any loss at all", not "always true"** - and it measures occupied
   **claimed** territory, so a mod-made country whose claims list holds no province it owns can never
   surrender by this measure.
6. **`war`, `war_goal`, `undeclared_war_region` and `modify_spies` with no country named** fall
   through to the scoped province's **controller**, not its owner. Occupation, not ownership.
7. **Flag and variable names are case-insensitive** (the tree folds the key through `tolower`), which
   is the exact opposite of `remove_brigade`.

#### Open, from wave 13, in rough order of value

1. [game] **`0x4F5F30`, the faction mutation** - a ~0x950-byte `__thiscall` where `CFactionAction`'s real
   effect lives, since slot 7's only country write is the influence charge. Agent C named this the
   single highest-value thing it left.
2. [dll] **Four duplicate field records, where the `void*` wins.** `CDiplomacyStatus +0x14` and `+0x1C`
   hold both `void*` and `CAlliance*`/`CGuarantee*`; `merge_fields` keeps the `void*` and demotes the
   typed one into its comment, **so the decompilation gets `void*`** - confirmed in the generated
   record. `CCountry +0xA8C` and `+0x10B8` are the same shape but harmless (same name and type
   twice). Deliberately not fixed: the pairs are *not* identical - each carries a different comment
   from a different findings file - so deleting one loses a reading and merging them is a content
   call. Four hand edits.
3. **Five recorded names sit on a body another luabind registration claims** - `0x16000`, `0x944C0`,
   `0xC8920`, `0x4E9090`, `0x2EF70`. Three contain an explicit, now-false negative such as "nothing
   outside it holds the body at all". `reconcileFacts.py` prints them in one command. Renaming is the
   maintainer's call because the names are load-bearing in a lot of prose.
4. [dll] **44 Lua fields cannot land**, because `mergeFindings` refuses a field on a struct `project.json`
   has no record for and a fragment cannot create one. 18 structs; the 13 `def_readwrite` ones among
   them are the **strongest** records in the whole Lua half. Either `mergeFindings` grows a `structs`
   key or the 18 stubs go in by hand. `CGoodsValues`, `CResourceValues` and `CStrategicWarfare` are
   the ones worth having.
5. [dll] **`CCasusBelliType`'s 22 loader offsets** - the table is derived and written out in
   `FINDINGS-diploaction.md` section 27; the struct holds one field. A hand-add.
6. [dll] **`CRelation` and eleven sibling structs still do not exist** in `project.json`, so nine
   subclasses write through a layout recorded nowhere. The layouts are prose in the same section.
7. [game] **When does a casus belli expire?** `CCasusBelli` slot 11 (`0x647D20`) is the only path that
   raises `WELOSECB` to the player and has **zero direct callers** - reached virtually.
8. [dll] **`CEventScope +0x10`** - the record has `char[4] country_tag`, the Lua half types it
   `CCountryTag&`. If the Lua half is right there is an unrecorded `+0x14` and the scope's tag
   comparisons read the id half, which is how every other tag comparison in the image works.
9. **A tooling limitation worth fixing**: `vftable_slots` is keyed by class with no way to say
   *which* of a class's two tables a slot belongs to, which is why `CVariables::SaveContents`
   (`0x77060`) and `CVariables::LoadKey` (`0x77080`) are described inside other entries' comments
   and recorded as neither.
10. **The 963 `remove_brigade` values that match no declared name at all** - counted, not audited,
    mostly `events/SpanishCivilWar.txt`.

### Wave 12, landed 2026-10-04 - four agents, and the fact base turned out to have three halves

**The wave's shape: the two sharpest findings were both already in the repository**, in places the
standing rule did not say to look. Wave 11 asked whether `ally = { ... }` scopes to a *bordering*
country; the answer was `Allies`, sitting in `ghidra/bicelib_findings.json` under the decimal offset
`3976`. That is trap 14 for the fifth time and it is now written into the trap with its own clause.

| agent | what it settled | what it overturned |
| --- | --- | --- |
| A `findings/FINDINGS-numtriggers.md` | **the units question, mechanically**: a leaf's scale is decided by which of **five** slot-7 bodies its base gives it, not by its own loader, so the answer is a table rather than a reading per trigger. `manpower_percentage` and `revolt_percentage` are **fractions, not percentages** - `= 50` demands fifty times the country's own ceiling. `enemy_ic_ratio` is the only one testing `<=`. `check_variable` **creates** the variable it cannot find, and compares `>=`, so a condition on a never-set variable is true whenever the threshold is `<= 0` | **the plan's own example.** `strength_ratio` **does not exist in this build** - no class, not among the 152 keywords, and the only occurrences anywhere under the mod root are in `WAVE.md` and this file. Also `max_manpower_greater_than` tests **current** manpower: its slot 6 is a linker fold of `CManpowerTrigger`'s body and has never read `+0xBD0` |
| B `findings/FINDINGS-scopetriggers.md` | **`ally = { ... }` scopes to a random *allied* country** - `CCountry +0xF88` is `Allies`, five agreeing witnesses, and `CCountry::GetAllies` (rva `0xE6A20`) is the whole of `lea eax,[ecx+0xF88]; ret`. `Allies` is every bilateral alliance **plus every faction member**, which `alliance_with` does not consult. **Every region name in `map/region.txt` is a trigger keyword**, resolved before the `CContextTrigger` arm. `CEventScope +0x40` is the `CCombatant`, so eight combat conditions are silently false outside a combat | the record's description of `RebuildNeighbours` as filling "two neighbour sets and the two `CCountryList`" - **it fills nine lists**. `CCountry +0xD00` and `+0xD10`, whose comments claimed open questions that two Lua accessors had already answered. And the brief's own route in: the five `GetBlockText` renderers were not needed, because the vftables were cheaper |
| C `findings/FINDINGS-effects.md` | **the whole `CEffect` slot map**, 12 slots, from a record that held none - slot 11 `Execute`, 9 `GetText`, 8 `GetBlockText`, 10 `GetTargetText`, 6 `GetKeywordToken`, and `CEffect` is `0x20` bytes. **`Execute`'s mystery second argument is read by nothing** in all 111 classes (11 of 100 bodies pass it through, two replace it with 0), with a positive control that the same scan sees the scope in 98 of 100. `country_event` **re-tests the target event's own trigger** and fires nothing, silently, if it is false. `add_country_modifier` is **idempotent** and a misspelt name is a silent no-op | **`flags` was recorded at the wrong offset on four structs** - `CGameState`/`CCurrentGameState +0xE8` and `CProvince`/`CMapProvince +0xC4` are the `CPersistent` *second base* of a `CFlags`, `0x24` into it. Three constructors settle it and `CCountry +0x180`, already recorded correctly, is the control. The headers carried the same error and nothing read them, which is why it survived |
| D `findings/FINDINGS-diploaction.md` §11-20 | **slot 7, the step where an agreement happens**, closed with a stated remainder. One shape twenty times: charge the influence **on PROPOSE**, build a `CRelation` subclass on ACCEPT, call its slot 10 to hang it on **both** parties, append to the one global list, move the relation. **`CCountry::ChangeRelation` (rva `0xE65C0`) is `CDiplomacyStatus +0x38`'s missing writer** - relation is symmetric *by construction* and is thousandths on a ±200.000 scale, with `EMBARGO_RELATION_CHANGE = -200.0` hitting the clamp floor exactly. **A guarantee and an embargo take effect when offered and are never answered** | §9's "`0x00A435F0` is the war-goal base" - `CWarGoalBaseAction` slot 7 is `_purecall` and that body is its two derived classes', folded. The class count: **21 tables, 20 distinct bodies**, not twenty-four |

**The numbers.** 2,352 -> **2,462** functions, 2,806 -> **2,863** fields, 2,110 -> **2,220**
signatures, 1,412 -> **1,517** signature entries checked with **none disagreeing**, classes `read`
66 -> **67**. 113 addresses and 58 struct fields landed off 115 submitted. The headless apply
reported **`failed: 0`**, not the documented `failed: 2` - and chasing that down corrected a
"known issue" that was never real. See the note below.

**Four fields were named twice, by two agents each, and all four agreed**: `CCountry +0x10B8
national_unity` and `+0xA8C neutrality` (A from the trigger side, C from the effect side), and
`CDiplomacyStatus +0x14 alliance` and `+0x1C guarantee` (B from the scopes, D from the actions).
That is four independent corroborations rather than four collisions, and it is the first wave where
the overlap was checked mechanically.

**A gap in the tooling, found by agent A reading another agent's fragment by hand.**
`mergeFindings.py --check` compares `struct_fields` against `project.json` but **not against the
other fragments in `incoming/`**, so two agents naming one offset differently is neither refused nor
reported and both records land - which `mergeFindings.py`'s own documentation calls worse than being
dropped. A withdrew three of its own entries that way. There is now a cross-fragment checker in the
session scratchpad; **promoting it to `scripts/` is on the queue and not done.**

**A second tooling gap, from agent C**: `checkSignatures.py --only` can check a signature that is
already in `project.json`, which leaves an agent unable to check its own new entries before
submitting them. C wrote its own and recommends a `--candidates` flag. Also on the queue.

**`failed: 0`, and chasing down why corrected a documented "known issue" that was never real.**
`CLAUDE.md` had excused two failures since wave 7 as Ghidra giving a function a body that runs past
its real end and swallowing the next one: `MT19937Next` (`0xAA2B90`) inside
`CSimpleRandom::GetInteger` (`0xAA2B10`), and `TernarySearchTreeFind` (`0xA7E030`) inside
`GuiTypeTree_Find` (`0xA7DEE0`). This apply reported `failed: 0` with no `!` lines and neither name
in the log. The first guess - that the maintainer had split the bodies themselves - was **wrong,
they had not**, so it was probed: a read-only Ghidra script over a copy, printing exactly what the
apply tests (`getFunctionAt` against `getFunctionContaining`).

**Both predecessors are thunks that tail-jump into the function below them.**
`CSimpleRandom::GetInteger` is the whole of `mov eax, ecx; jmp 0xAA2B90` followed by `int3`;
`GuiTypeTree_Find` is a null check, `xor eax,eax; ret 4` on one arm and `pop ebp; jmp 0xA7E030` on
the other, then `int3`. Ghidra's 7- and 24-byte bodies for them are **correct**. There was never an
over-long body to arbitrate: what Ghidra had done was **merge each thunk with its tail-call target
into one function**, which is ordinary behaviour on a tail call.

**And the byte-level argument the old text rested on was about a different function.** It said
"`0xA7DEE0` ends `ret 0xc` at `0xA7E028`, then five `int3`, then a clean `push ebp` - two functions,
properly padded apart". That `ret 0xc` is real and so is the padding, but `functionStart(0xA7E020)`
answers **`0xA7DF60`**. Two functions were conflated, and the conclusion that the record's names
were right was true for an unrelated reason.

In the current project all four addresses are proper entries, so the names land. **`CLAUDE.md` and
`ghidra/README.md` now say `failed: 0` is the pass mark and any failure is a real one**, with the
bytes and the note that if the pair ever returns, the repair belongs on the **thunk**, not the
target. *The lesson is trap 2's own: a `ret`, a padding run and a clean prologue prove a boundary
between the two functions they sit between, and say nothing about a third one named in the same
sentence.*

### Wave 11, landed 2026-10-03 - four agents, and two premises refuted

**The wave's shape: two of the four briefs were wrong about the thing they were built on, and both
agents said so and answered the better question instead.** That is the second wave running where
the plan's own reasoning needed correcting by the bytes.

| agent | what it settled | what it overturned |
| --- | --- | --- |
| A `FINDINGS-triggereval.md` | **there is no cache anywhere** in trigger evaluation - no memo, no dirty bit, no tick stamp - so `RunDailyEventPass` re-walks every tree every day, doubled wherever a tooltip is open because slot 11 re-evaluates rather than reading slot 6's answer. `CEventScope` taken from 2 named dwords to 12. The four composites' slot 6 read, and `CContextTrigger` **narrows** a scope by copying it, it does not build one | the plan's "clean boundaries on both sides" (trap 2, three times); `CEventScope`'s recorded **size**, where the struct said `0x38` and its own field comment said `0x48`; slot 10's recorded signature, whose 4th argument is an int **weight** divided among branches, not an `int* total`; and `CNotTrigger` is a **NOR** |
| B `FINDINGS-history.md` | the history is a **reversible do/undo transaction log** keyed on dates, `AddEntry` its only public way in; **~3 MB** for 48,998 entries, with the arithmetic and its assumptions; `g_NullDate` promoted and explained as **year zero** on the engine's own calendar | **the brief's premise.** The history *is* read after load - three ways, one of them **every single day** for every leader of every country. And `CLeaderHistory +0x40 trait_gain` is not a field of a 0x24-byte struct: those four bytes are `CLeader +0xC4`, which **the record already held**, so it carried one field twice under two owners |
| C `FINDINGS-mappoint.md` | **879,780 = 14,190 x (60 + 2), exactly** - one point per building type per province plus two embedded. 0x10 bytes from six independent strides; a **flat** vector with an exact `reserve`, so zero per-element and zero slack overhead; **13.5-13.6 MiB**, half of it vftable and a word nothing reads; built once at database load, freed only in `CEU3Application`'s destructor | the record's "one key, `y`" - **it is two, `x` and `y`** - and with it the plan's hypothesis that `x` was implied by position. Also the brief's "plus small-object allocator overhead": the allocation is **per vector, not per point**, so per-point allocator cost is zero |
| D `FINDINGS-diploaction.md` | the offer lifecycle end to end, Lua `Create` to the entry in a save; `value` is a **bool**, not thousandths; the null action is a **static singleton** whose `IsValid()` is `xor al,al; ret`, used as "am I still empty" | **`type` has three values, not two** - `ACCEPT = 2` is registered eight instructions after the other pair, and 21 of 56 save blocks carry it. And **`CCountry +0xF24` is not `declarewar`**: it is the pending-action list of *any* kind, and `declarewar` is the one of nineteen tokens the compiler emitted a literal for |

**Landed:** 84 addresses and 36 struct fields offered, **80 addresses and 36 fields merged**. Record
**2,292 -> 2,352 functions**, 2,777 -> **2,806 fields**, signatures 2,051 -> **2,110**, labels
563 -> 567, virtual tables 206 -> **207**. Headless apply **`failed: 2`** - the pass mark, both
documented over-long bodies. `checkSignatures.py` **1,412 entries, none disagree** - the zero
baseline wave 10 reached held through all 80 new entries.

**The actionable mod figure of the wave**, from C: one building type costs 16 + 4 = **20 bytes per
province**, present from database load to process exit whether any province has that building or
not. That is 0.27 MiB each, so **BlackICE's 48 extra building types cost 12.99 MiB** over vanilla -
and the same multiplier sits in front of `CProvinceBuilding`'s 1,702,800 instances, which is
14,190 x 2 x 60 exactly. Two independent census figures landing on one multiplier.

**And the methodological one**, from D: **`CDiplomaticAction`'s 22,113 "live" is not an object
count.** The class is abstract - ten of its 22 slots are `_purecall` - and every destructor in the
family writes the *base* vftable into the object as it unwinds, so freed-and-unreused memory still
answers to it. `census.py`'s own docstring warns about exactly this. Any census number for an
abstract base wants that check before it is believed.

**Four new trap cases went into `TRAPS.md`**, including a genuinely new third cause for
`functionStart`: it can stop on a `0xCC` that is **the low byte of a `call rel32` displacement**,
and `retsBefore` does *not* catch it because x86 resynchronises and the decode looks clean. Requiring
a run of three `int3` fixes it.

## Away from the AI: where else there is to go

Surveyed 2026-10-03 at the maintainer's request, after wave 10, by reading `PROGRESS.md`'s own table back
rather than by taste. **Every loader grammar in the image has already been read** - `PROGRESS.md`
says so and it is right - so what is left everywhere is *layout and behaviour*, not grammar.

The arithmetic that frames the choice: of 1,141 classes, **858 have no `read` class anywhere in
their ancestry**, and those hold **2.1 million living objects**. Counting ancestry is the whole
trick, and getting it wrong is how this survey nearly went to the wrong place - see the two dead
ends at the end.

### 1. The evaluation half of the event script language - the strongest candidate `[game]`

**The grammar is read, the tooltips are read, and the answers are not.**
`findings/FINDINGS-script.md` has all **152 trigger keywords and 91 effect keywords**, one class
each. `CTrigger` slot 9 `GetBlockText` and slot 8 `GetText` - how a condition *draws itself in a
tooltip* - are read in detail, including `CAndTrigger`'s and `CContextTrigger`'s overrides.

But slot **6** is `Evaluate`, `bool __thiscall (CTrigger*, CEventScope*)`, and a grep of the whole
record finds **7 named `Evaluate` bodies in the image**, four of them narrow leaves
(`CPureRevoltRiskTrigger`, `CRevoltRiskTrigger`, `CCombatModifierTrigger`, `CCombatIsConvoyTrigger`,
`CCombatIsWinnerTrigger`). So for ~152 trigger classes **the record knows how a condition displays
itself and not how it answers.** `CEffect` has no vftable slots recorded at all.

> **Re-measured 2026-10-05, and the two sentences above are stale: there are now 64 named
> `Evaluate` bodies, not 7, and `CEffect`'s slot map is fully recorded.** Waves 11, 12 and 13 landed
> after this survey was written and wave 13 alone added six. The area is still the strongest
> candidate away from the AI, but what is left in it is the **spine** - how `CContextTrigger`
> rebinds a scope, and what walking a forest costs - rather than a hundred unread leaves. Wave 14's
> briefs B and C are built on the re-measured picture; `WAVE.md` carries the arithmetic. **This is
> trap 14's open-list clause: a survey is a claim about the record as it stood when it was written,
> and the next wave is what invalidates it.** The three most populous trigger classes
> (`CAndTrigger` 100,464 live, `CNotTrigger` 28,006, `CContextTrigger` 10,974) have named
> `Evaluate` bodies and **no struct records at all**, which is brief A's problem rather than this
> section's.

The live population backs it: `CAndTrigger` **100,464**, `CTechnologyTrigger` 33,204, `CEffect`
28,627, `CNotTrigger` 28,006, `CHasCountryFlagTrigger` 18,966, `CVariableTrigger` 12,815,
`CTrigger` 11,343, `CTagTrigger` 11,196, `CContextTrigger` 10,974 - **over 260,000 live objects**,
nearly all `RTTI`-only.

Why it matters for this mod specifically: BlackICE is an enormous event and decision mod, and these
are the semantics behind every condition in it. Concrete questions with concrete answers:

- **`CContextTrigger` derives from `CAndTrigger`** and has 10,974 instances - it is the scope
  switch (`owner = { ... }`, `controller = { ... }`, a bare country tag). Only **2 of 153** keys
  placed. How it rebinds the scope is the difference between a condition meaning what the modder
  thinks and not.
- **`CVariableTrigger`** - variables are a modding feature and nothing is known about it.
- **Is evaluation cached, and what is the cost of a trigger forest?** Slots 10 and 11 are
  `WalkChildren` and `CountEvaluation`, both recorded with signatures and neither read. If every
  decision re-walks its tree on a schedule, that is a measurable cost in a mod with thousands.
- **What a comparison actually compares.** `strength_ratio`, "controlled", "in combat" - the kind
  of thing that is guessed at in mod forums and is sitting in the bytes.

### 2. The retained-history question - a memory finding waiting to happen `[dll]`

`CLeaderHistory` **24,138** live, `CRankChange` **24,547**, `CTraitGainTracker` **24,137**,
`CCountryDecisionChange` 15,755, `CProvinceHistory` 14,190 - **about 103,000 live objects** of
*history*, and `CRankChange` and `CCountryDecisionChange` are `RTTI` with no field and no function
named.

The question that makes this more than a layout exercise: **does the engine keep every leader's and
province's full history in memory for the whole game, and does anything ever read it after load?**
HoI3 dies of address space, not of leaks (`hoi3-crash-dump-diagnosis`), so a hundred thousand
retained objects nobody reads is worth knowing about. It also lands next to a mechanic the maintainer already
has: the dormant no-leader-skill-loss work, and `CTraitGainTracker` already has 4 fields and 6 named
functions, so it is the cheapest way in.

### 3. `CMapPoint` - 879,780 live, the single biggest population in the game `[dll]`

`CMapPoint::LoadKey` takes **one key, `y`**, so each is a coordinate and there are **879,780 of
them** - more than every other unread class combined, and nothing is recorded but that loader. At a
plausible 8-16 bytes plus small-object allocator overhead this is on the order of ten megabytes of
map geometry, in a process that runs out of address space.

**This is the biggest unanswered memory question in the image** and it is pure plumbing - no mod
semantics, no AI. It extends the measured work in `hoi3-memory-where-it-goes` rather than starting
something new. Best paired with the Memory page, which can count them live.

### 4. Diplomacy's action layer - smaller, self-contained `[game]`

`CDiplomaticAction` 22,113 live (`placed`, 2 fields, 2 functions) plus `CNullDiplomaticAction`
13,669. `findings/FINDINGS-diplomacy.md` covers the save's diplomacy block and the agreement kinds;
the **action** object - what an offer *is* while it is in flight - is not read. A contained job with
a clear boundary, and the one of these four that could be done in a single pass.

### Two candidates that died on inspection, recorded so nobody re-proposes them

- **`CRegiment` / `CWing` are not unread.** `PROGRESS.md` shows `CRegiment` with **1** field at
  `0xD8` bytes and 27,277 live, which reads like virgin territory - but its base **`CSubUnit` is
  `read` with 28 fields at the same `0xD8`**, and the table's `fields` column is each class's *own*
  named fields by design. The layout is largely known; only the derived slice is not. Same for
  `CWing` (0 own fields, 2,298 live). **Rank on ancestry, not on the `fields` column.**
- **The modifier system is better covered than its `RTTI` marks suggest.** `CStaticModifier` is
  31,318 live with no struct and no named function, which looks like the mod's main lever lying
  untouched - but `CModifier` is `placed` with a header, and **`CModifierValues` already has 143
  fields named at `0x478` bytes**, which is the whole modifier value table. What `CStaticModifier`
  adds over its base is a thin slice. `ActiveModifier`, `CModifierDefinition`, `CModifierEntry` and
  `CMTTHModifier` are all recorded too.

### The live queue - when a game is running `[both]`

Wave 9 was entirely static and generated a long list of things that one session with a game would
close in minutes. **Worth doing all of these in one sitting rather than briefing an agent per item.**

| what to read | what it settles | from |
| --- | --- | --- |
| `plan_air_stance` across AI air formations, looking for a **2** | whether five air missions are dead for the AI | `FINDINGS-airnaval4.md` |
| `CGuiObject +0x44` with a text field focused | `has_focus`, currently `likely` | `FINDINGS-guistatic.md` |
| `CFixedWindow +0x60` on all 206 windows, and on one being shown and hidden | the window-wide flag every descendant mirrors at `+0x48` | `FINDINGS-guistatic.md` |
| `provinces[10535..10538]` | what the four province ids hard-coded out of convoy raiding are | `FINDINGS-airnaval4.md` |
| `CRegion +0x6D` after a war has run on | whether war sets the byte `ScoreOpsAreaProvinces` adds +100 for | the open list above |
| the debt pools after a war with debts allowed | `repaid_away` / `income_from_debt`, still "not established" | the open list above |
| a hook on `EstimateAttackOdds`'s return for one province | the damage-ratio formula, outright | `FINDINGS-attackodds.md` |
| `state->tick` between `CInGameIdler::Leave` and `CFrontEnd::Enter` | which instruction wrote the 60759360 | `FINDINGS-session2.md` |
| the `+0x2FC` vector's 46 buttons, by type name and who called slot 22 | whether `attached_children_head` is the right name | `FINDINGS-guistatic.md` |
| **AI agent units' `plan_air_stance`, on an AI country** | whether anything clears stance 2 faster than `ProcessAI` restores it - agent D's one remaining open item, and the last thing between "the strategic air war is live" and certainty | `FINDINGS-airstance.md` |
| **`CUnit +0x2DC` across an attack decision onto an opposed amphibious landing** | the **amphibious sign bug**. If real, the estimate *rises* where it should fall. Currently the whole claim rests on one opcode byte (`subsd` where the river arm has `addsd`) | `FINDINGS-aihelpers.md` |
| a **bombing** combat with the slot 11 probe still installed | the one arm of the slot 11 result that rests on static reading alone | the open list above |
| **`CCountry +0x678[resource index]`** for a country before and after it loses a province that has a strategic resource, and once more after saving and loading | whether **a strategic resource level is ever lowered**. The one routine that writes it only raises it and a scan found no other writer but the session reset - a negative, currently `likely`. OpenHOI3 copies the behaviour on that strength. Added 2026-10-08 at the maintainer's word: keep the note, check later | `FINDINGS-countrymodifier.md`, section 4 |

### Deferred, at the maintainer's call

- [dll] **Finding the outliner leak in the code.** The symptom is quantified and reproducible - every
  open/close of a full-screen window permanently leaks 30 widgets, ten each of `outliner_header`,
  `outliner_header_entry` and `entry_text`, while six sibling outliner names tear down correctly -
  and the difference between those two paths is where the answer is. **Not needed yet**; the new
  widget counter on the Memory page will say whether it matters over a long game before anyone
  spends an agent on it.

### Open, not scheduled `[dll]`

**Two leader-assignment flags the Ctrl-unassign feature passes without knowing what they do.**
Both are small, both are self-contained, and neither blocks anything - the feature has been tested
in single player and in **multiplayer** and works. They are here so that whoever next touches
leader assignment does not have to re-derive them.

1. **`CAssignLeaderCommand +0x8C`**, the fourth argument of its constructor (rva `0x1D7430`).
   The two swap sites in one function at rva `0x33ACAC` and `0x33ADA2` pass **0**; the two
   single-assignment sites at `0x3665A4` and `0x36955C` pass **1**. BiceLib passes 1, matching the
   site that builds the same command it builds - an assign-the-empty-leader - but *why* the swap
   passes 0 is unread. The field is written by the constructor and read somewhere in `Execute`
   (rva `0x1D7570`) or in the command's save path; one scan for readers of `+0x8C` settles it.
   **The cheap guess to test first** is that it is "announce this to the player", since the swap
   is one user action that posts two commands and would otherwise report itself twice.

2. **`CUnit::SetLeader`'s two trailing ints** (rva `0x1BFC10`, `ret 0xc`). Four call sites read,
   three distinct combinations: `(CLeader::null(), 1, 0)` from `CRemoveAllLeadersCommand::Execute`,
   `(leader, 1, 1)` and `(CLeader::null(), 0, 0)` from `CAssignLeaderCommand::Execute`, and
   `(CLeader::null(), 0, 0)` at rva `0x1D7DA7`. So the first is **not** "is there a leader" - the
   remove-all path passes 1 with the empty leader - and the pattern that fits what is read is
   first = "this is the assignment that counts", second = "a leader is arriving rather than
   leaving". **That is a reading of three call sites, not of the body**, which is the thing to do:
   23 callers makes it worth reading properly once.

**The one reversing dependency left in the BiceCommand framework: a persistent reference both
ways.** Added 2026-10-05. The framework (`BiceLib/Commands/CBiceCommands.hpp`) carries `int32`
arguments, which is already enough for ids, enums and flags - but a command that names a *unit*, a
*leader* or a *province* has to carry it the way `CAssignLeaderCommand` does, as a `CPersistent`
**id pair**, because that is what makes it mean the same object on every peer. A pair is two
`int32`s, so the payload format already holds one; what is missing is the conversion.

3. **`0x42DD70`** turns an object pointer into the pair, and **`FindPersistentById`
   (`0x69DA00`)** resolves it back, choosing the registry `[0x1A857F0]` or `[0x1A857F4]` on
   whether the id exceeds `0x1268` - all three read already, from
   `CAssignLeaderCommand::Execute` (rva `0x1D7570`), which does exactly this for both of its
   ends. What is **not** read is `0x42DD70`'s own signature and convention, or whether it is
   general or unit-specific. One function, and it unblocks every command that names a game
   object rather than a number. Worth a small helper on the framework once it is read, because
   every such command will want the same two calls.

---


**The one that would change a published claim.** Everything else here is an addition; this is a
subtraction, and it is what is left of the slot 11 question after the live run closed the main part
of it.

1. **`CCombat` slot 17's receivers outside the combat module** - `findings/FINDINGS-combat3.md`'s own open
   item 1, and it is **not** closed. `findings/FINDINGS-slot11.md` §7 says why the method that closed slot
   11 cannot close this one: the filters cut slot 11 from 1,033 call sites to 14, but slot 17 only
   from 1,871 to 573, because the discriminating power came from the receiver's production site and
   a `CCombat` pointer is reachable from too many places. A different method is needed, not more of
   the same sweep.
2. **The bombing arm of the slot 11 result rests on the static reading alone.** No bombing combat
   ran in the session that produced 39,414 hooked calls, so for naval, air and land the demotion in
   `findings/FINDINGS-combatmods.md` is backed live and for bombing it is not. One bombing combat would
   settle it, and the probe hook still exists for exactly that.
3. ~~**Whether `CCountry +0x824` `repaid_away` and `+0x848` `income_from_debt` are ever written.**~~
   **Settled 2026-10-13** (`findings/FINDINGS-tradeaid.md`, C.1): they are, money only, by the debt
   repayment loop at the end of `CCountry::CollectDailyProduction` - which runs only once a debt exists,
   hence the zeros at peace. The entry below is kept as history.
   Non-zero in **0 of 108** live countries at a scenario start, with `home_produced` and `usage`
   populated in 106 of them and four sibling trade pools populated too, through the identical read
   path - so the zero is the field's and not the reader's. **That is not the same as inert**, and an
   earlier version of this entry overclaimed it as such. the maintainer's own recall of the *allow debts
   during war* trading mechanic is what corrected it, and it is corroborated in the image:
   `CDebtAction` exists and has **zero live instances**, which is exactly what predicts these zeros
   at peace. So the honest status is "not established", and what would settle it is a game run on
   through a war with debts allowed - not more reading. The savegame is the cheap oracle: neither
   key should appear while it holds.
4. **What `CRegion +0x6D` means.** Now a question about one named 0.1 KB class rather than an
   unknown one: `CMapProvince +0x358` is a `vector<CRegion*>`, `classNameForVftable` answers
   `CRegion` on 8 of 8 provinces tried, and `hoi3.instances` finds 400+ at a **uniform 0x78
   stride**, which is the trap-15 check for real objects rather than a table of vftable pointers.
   The byte reads **0 on all 400 regions** at a scenario start, so `ScoreOpsAreaProvinces`'s
   "+100 per region whose `+0x6D` is set" never fires there. Whether that is because the AI is not
   running yet or because war sets the byte is the remaining question, and running the game on
   answers it.
5. **The game's own name for `GuiTooltipText`.** No vftable, so RTTI cannot name it; 114 callers of
   its destructor and 86 producers, but no consumer was found, and a consumer is what would name
   it. The struct is in the record under our name, flagged as ours.
6. **The five diplomatic actions** whose slot 17 neither pushes a literal nor calls the bridge -
   `CCallAllyAction` (`0xA2AC80`), `CEmbargoAction` (`0xA438F0`), `CLicenceTechnologyAction`
   (`0xA3D3F0`), `CRequestLendLeaseAction` (`0xA0FE20`), `CTradeAction` (`0xA38B00`) - against the
   five Lua wrappers around `0xA444xx`-`0xA44Cxx` that do, each with one caller. `FINDINGS-
   convoys.md` got one step further on the last of them without closing it: `CEU3AI` has two
   registered methods taking a `CTradeRoute&` and returning `bool` (mangled names at `0x15F02C8`
   and `0x15F02E8`), which is the right shape for the untraced route - the AI handed a route and
   asked yes or no - but the wrapper was not followed to its caller.
7. **`0x4FA0B0`** recomputes all seven alignment terms and would confirm every formula in
   `findings/FINDINGS-politics.md` cheaply.
8. **The force-needs half's remaining 2 KB** (`findings/FINDINGS-forceneeds.md`).
9. **`0x4AF580`** (`CTheatre::AddFront` as proposed), read only to its first ~60 instructions.
10. **Two front headings in the maintainer's savegame that do not fit the 0.125 lattice**
    (`findings/FINDINGS-weatherfront.md`). Both are facts in the file and neither is accounted for.

### Two decisions that are the maintainer's, not findable by reading

- **`CTradeRoute +0x34` and `+0x44`.** Six independent readings, including the engine's own
  `GetTradedFromOf`, say the record has the two the wrong way round. Both are still marked
  `inferred`, not `proven`, and swapping a published field on six readings without a live
  confirmation is the kind of change that should be asked for rather than made.
- **Whether the slot 11 probe hook comes out.** Its own header says it should be deleted now that
  it has answered. The one reason to keep it is item 2 above - a bombing combat.

### Wording to fix while passing

- `findings/FINDINGS-techdecay.md` calls `slack` spare capacity. It is the **sum of two slider positions**,
  which is what is *requested*, so the word is actively misleading there.

## What has already been read

161 findings files, which is where the evidence for anything in `project.json` or a `GameClasses`
header lives. This replaces the `Done` archive: the archive restated each file's headline and named
only 40 of the 67 there were then, so it was both longer and less useful than a complete list.

**`python scripts/checkindex.py` checks that this list is complete** and that the count above
is right. It was neither until 2026-10-07: 79 of 85 listed, and a count 18 out, because a
write-up reaches `findings/` and this page is updated by hand afterwards or not at all. Four of
the six it was missing were wave 15's.

**The engine's own flow**

| | |
| --- | --- |
| `findings/FINDINGS-tick.md` | the tick: the clock, the command it posts, the five periodic passes and the TBB fan-out |
| `findings/FINDINGS-schedule.md` | when each unit-level update runs, and on which thread |
| `findings/FINDINGS-scrollbar.md` | **a scrollbar's end buttons**: a press's step (a declared thousandth counts as ten), the input object's two keys that multiply it by ten and by a hundred - slot 12 likely Ctrl - and **the hold that repeats it**, each frame counting the whole time held in 0.15 s repeats, so it speeds up the longer it is held and with the frame rate; the platform clock's `Start` and `Reset` |
| `findings/FINDINGS-commands.md` | the command queue, the four channel classes, and the one `Execute` caller |
| `findings/FINDINGS-session.md` | the session lifecycle: what `in_game` means, and what creates and destroys a game |
| `findings/FINDINGS-session2.md` | the startup reset's second half, and what `CInGameIdler +0x1790` really is |
| `findings/FINDINGS-resetpath.md` | the deferred session-exit path, and whether `Update` can reach the reset with `in_game` set |
| `findings/FINDINGS-startup.md` | how the engine boots, stage by stage, and which loader claims each `common/` file |
| `findings/FINDINGS-mappoint.md` | 879,780 map points: 14,190 x 62 exactly, and the 13 MiB they cost |
| `findings/FINDINGS-mapbuild.md` | the map build, its cache, and how the frontend is reached |
| `findings/FINDINGS-allocator.md` | the allocator, and what a call site gives away |
| `findings/FINDINGS-save.md` | how the game writes a save |
| `findings/FINDINGS-autosave.md` | how the game decides to autosave |

**The AI**

| | |
| --- | --- |
| `findings/FINDINGS-ai.md` | the AI: slot 9/slot 10, the per-country hour stagger, the five minister ticks |
| `findings/FINDINGS-aisched.md` | how often the AI runs - hourly, by latch handshake - and what a year change does |
| `findings/FINDINGS-aiunit.md` | `CAIUnit`: 90 slots, theatres, fronts and battle plans |
| `findings/FINDINGS-aiplans.md` | how the AI decides where its armies go, and the fair-share ops area |
| `findings/FINDINGS-aitheatre.md` | the AI's theatre layer, and `CAIInvasion` |
| `findings/FINDINGS-theatre2.md` | the six theatre sites, and `CAIInvasion`'s stage machine |
| `findings/FINDINGS-setarea.md` | how an ops area is drawn, and how it reaches subordinates |
| `findings/FINDINGS-subdivide.md` | slot 83: how an area is sliced, and the proof nobody ever asks for it |
| `findings/FINDINGS-opsarea.md` | what scores an operations area, and what finds the way out of it |
| `findings/FINDINGS-reorganise.md` | the two bodies behind slot 73's air and naval halves |
| `findings/FINDINGS-aihelpers.md` | the AI's own combat modifier model, and how far it agrees with the battle's |
| `findings/FINDINGS-attackodds.md` | the AI's land attack odds: `ourDamage / theirDamage`, read end to end |
| `findings/FINDINGS-airstance.md` | who sets air stance 2, and who fills the air target lists |
| `findings/FINDINGS-airnaval4.md` | air phase 4's mission assignment, and the naval convoy raid and rebase |
| `findings/FINDINGS-aiconsumer.md` | slot 73's land half: who spends the ops-area and front scores |
| `findings/FINDINGS-power.md` | what the AI thinks it can win: strength x org x a per-brigade stat sum |
| `findings/FINDINGS-forceneeds.md` | what the AI thinks it needs built, and that an AI country asks only for aircraft |
| `findings/FINDINGS-invasion.md` | where the AI comes ashore: `PickInvasionLandingProvince` end to end |
| `findings/FINDINGS-aifields.md` | six fields the AI reads that nothing named, including `CMapProvince +0x5C` |
| `findings/FINDINGS-trade2.md` | the AI's trade predicates, the two gates, and who counts as a neighbour |
| `findings/FINDINGS-negatives.md` | four load-bearing negatives, and what a positive control did to each |
| `findings/FINDINGS-survivors.md` | the three leads that kept surviving |

**Combat, units and supply**

| | |
| --- | --- |
| `findings/FINDINGS-combat.md` | combat: the standing account, and the five things later files corrected in it |
| `findings/FINDINGS-combatmods.md` | combat modifiers: the whole census, two adders, 69 sites, 30 ids |
| `findings/FINDINGS-combat3.md` | the leftovers: land surprise as a half-removed feature, `BM_ARMOR_ADVANTAGE` |
| `findings/FINDINGS-slot11.md` | does anything outside `CCombat` slot 17 call `CCombatant` slot 11? - settled live, no |
| `findings/FINDINGS-navaldetection.md` | naval detection, positioning and fleet disengagement |
| `findings/FINDINGS-airnaval.md` | air and naval missions, and that a naval row's `+0x84` counts ships |
| `findings/FINDINGS-unitdef.md` | what a division's stats are made of - sum, cap, mean |
| `findings/FINDINGS-unitstart.md` | what a brigade starts a new game with: its historical model's levels and where a default model comes from, strength and the reserve penalty, organisation, the experience a training law gives, the officers a country's units bring - and all 3706 starting brigades reproduced against a save |
| `findings/FINDINGS-unitdaily.md` | what a unit draws each day: supply and fuel consumption (a hundredth more a technology level), the draw and when in the day it falls, `CDistributeReinforcement::Distribute` and `CDistributeUpgrade::Distribute` read through, the build discount with `ic_efficiency` in it, the supply slider's need - with brigade strength, doctrines and Germany's 1,469 upgrade lines reproduced from a savegame |
| `findings/FINDINGS-organisation.md` | the officer ratio and where it is capped, the hourly return of organisation (`CUnit::RegainOrganisation`, `CSubUnit::RegainOrganisation`), what a crowded base has room for, and that a change of law holds every brigade to its ceilings - with 2676 of 2676 brigades' organisation reproduced from a savegame, and what three Waffen-SS brigades say about the two days before the first screen |
| `findings/FINDINGS-leaders.md` | leaders: experience, skill, traits, and that promotion skill loss does not exist |
| `findings/FINDINGS-landbattle.md` | a land battle from its first hour to its last: the hourly look that starts one and the unit that fights from next door; `CheckForCombat`'s joining, starting and **taking a province**, with who gets it (`CMapProvince::TakeControl`); which side a bystander joins; the combat width by the attacker's directions and a unit's own; the front set up in order and kept each hour, with the reserve's roll and score; the hour of `CCombat::Tick` in order and **that it answers whether the battle is over**; the two generators of a round; **a brigade's damage divided by a hundred** and the strength clamp `FINDINGS-combat.md` denied; `HasLost` and the empty front; `Conclude`, the retreat of an attacker that stays where it is, the buildings damaged by a pushback; the four figures the tactics give a battle; the attack delay - 168 hours and more, cut by how long the attack lasted; **read, not watched** |
| `findings/FINDINGS-combatview.md` | a battle on screen: selecting a battle and `CInGameIdler::ShowCombatView`; the `CCombatView` window of `interface/combat.gui`, element by element - the share bar, the width, the counter arrow, the modifier icons `CMOD_...`, and each side's flag, leader, tactic and two lists of `CUnitOption`; the retreat button; the unit panel's `CCombatEntry` and the battle's name; the marker's frame, number and place; **the share's arithmetic for a land battle**; and **tactics**: the `CCombatTactic` layout (correcting which offset is the tactic's own number), `CCombatant::PickTactic`'s weights and its two draws, who picks first, the six battle conditions of a `trigger`, and a technology's `tactic_` keys |
| `findings/FINDINGS-supply.md` | how supply reaches a unit |
| `findings/FINDINGS-supplynetwork.md` | the network that pass runs on: **`COwnerArea`** - who is in one (controlled, touching, more than one level of infrastructure), its ports, its links to its neighbours and its two flags; **supply groups** of areas on one side and `CSupplyGroup::PickDepot`'s score; `CProvince::UpdateSupplyDepot` and `CCountry::FindSupplyDepot` read through as the fallback it is; `CProvinceTemplate +0x24` as a size class of 1 to 4; what `SupplyCapacity`, `SupplyLoss` and `SupplyNeed` compute; the `capital` byte as "the capital or beside it"; and the whole of it set against three savegames - the same 4400 provinces out of supply and the same 402 beside a capital - and against what the maintainer watched the running game do with the depot of Manchukuo and Korea as he released one Korea and then the other, which the score gives case for case |
| `findings/FINDINGS-supplypass.md` | **the daily supply pass, step for step**: the sort it is ordered by (the C runtime's `qsort`, whose order among equals is part of the rule), the three phases with what `FINDINGS-supply.md` had loosely - the loss is an amount asked for on top, `last_pool` makes goods move a province a day, a share once cut stays cut, a surplus goes one province inward a day; `CUnit::ConsumeSuppliesAndFuel`'s network arm, with the unit's share of a short pool and what a friend's unit pays; **`CUnit::CarrySupplies`**, by which a marching unit takes its days of supplies along; where a day's supplies and fuel are made; and **what a new game runs before its first hour** - a day, the filling with the stockpiles put back each pass, a day. A replay reproduces 124 of 234 networks of a start-date savegame in every figure |
| `findings/FINDINGS-supplyconvoys.md` | **convoys as supply uses them**: `CCountry::MaintainSupplyConvoys` - at peace every port of a network across the sea gets a convoy, the depot first and then the furthest, at war only what the day's `drawn` asks - and its unmaking; **the route** (`FindConvoyPath`, a best-first search that settles a province on first reach, with the binary heap it pops from read test for test); the home harbour by a straight line between two sea provinces; `CCountry::DistributeConvoyShips`, which shares transports out supply convoys first and gives escorts only to a convoy attacked within 99 days; **what a new game gives for nothing** - each convoy its transports and an escort, each country free transports to half its IC; `CCountry::CollectDailyProduction`, where the resources of land cut off from the capital are swept into a loading port's pool each day; and **the supply map mode's colours**, branch by branch. Corrects `FINDINGS-convoys.md` on what the headroom is summed over and `FINDINGS-mapmode.md` on the mode's map style |
| `findings/FINDINGS-manpower.md` | manpower: what the drain is made of |
| `findings/FINDINGS-countrymodifier.md` | everything a country's modifier is rebuilt from, in order: ministers and their `decay`, laws, government, strategic resources and who shares them, province modifiers, the scaled statics, event and triggered modifiers, difficulty |
| `findings/FINDINGS-manpowergain.md` | manpower: what a day adds, what `max_manpower` is, what a new game starts with, and that a country's modifier takes in its provinces' |
| `findings/FINDINGS-redeploy.md` | strategic redeployment and the route finder |
| `findings/FINDINGS-movement.md` | movement: the click and the move command, the order the route search really runs in, the hourly march - speed, every term of its modifier, progress against the distance, arrival and cancelling - whose ground a unit may enter, and what an edge's distance is: the terrain `movement_cost` summed along a pixel walk, checked against all 83,596 edges of the game's own cache. Also how adjacencies are ordered, the four edge kinds, and the rule that gives a province its terrain |
| `findings/FINDINGS-unitpaneltooltips.md` | **the unit panel's tooltips**, entry by entry: the header's activity, strength and bars, the status line's fourteen elements, the order's, the brigades', a headquarters' row and the buttons; with **the leader's own tooltip**, a brigade's summary, the names of a level of equipment, a historical model and a unit level, the attrition, speed and combined arms breakdowns, and **what every kind of order calls itself** (the idle order nothing). Corrects a brigade row's slot 4 and `BuildUnitStatsTooltip` - a click and a window, not tooltips |
| `findings/FINDINGS-battletooltips.md` | **the battle window's tooltips and a battle's row in a unit's panel**: the dispatcher's test by the element's group, the router read whole, a land unit's whole - leader, attack and defence, each combat modifier, the side's tactic as it feels it, piercing and armour - an attacker's reserve's chance, a ship's (its target, positioning, firing range) and a wing's, a tactic's own text, the modifier icons' name and description, and a side's names and counts. **A side of one fleet runs its ships' names together** |
| `findings/FINDINGS-techtext.md` | **a technology's requirements and effects as text**: the trigger renderers' exact rules - the base draws an asterisk only at depth 0, an `and` at the top draws no header - and **BiceLib's corrected indentation in prose**; the leaves' words, turned round inside a `not`; `BuildEffectsText` read whole - what a first level allows, each unit type's figures times the levels folded onto one line - `BuildStatsTooltip`'s 42 lines and `AppendStatLine`'s layout, and `BuildEffectsTooltip` read whole from the listing, 46 scalars, two flags, tactics, groups, missions and decay |
| `findings/FINDINGS-leadertooltips.md` | **the leader window's tooltips**: `CLeaderAssignmentPanel::ElementTooltip` read whole - the trait filter first and final, then a row, then by name - a row's, the traits to gain, **a trait's name and a line per effect** (`TraitEffectLine`: label, colour, sign, percentage), a filter row's checkbox; what is left falls to the unit panel header's names, so a row's button says "Assign new leader."; **corrects the leader's own tooltip**: the command line only where he commands a fleet or an air unit. That the window's elements reach the routine is shown by the maintainer's screenshot, not by the bytes |
| `findings/FINDINGS-orderstooltips.md` | **the deploy menu's and the two orders windows' tooltips**: how the open side menu and the orders view are asked, a finished unit's and a target's line (its brigades by their counters), and the fleet's and the air window's elements read whole - `accept` only while switched off, a row's description with the fleet's `OUT_OF_RANGE` and its two figures, the air window's day readout - and **the priority buttons that say nothing**, both windows asking twice for a name no element has. Also the unconditional `closebutton` - `CLOSE` |
| `findings/FINDINGS-unitpanel.md` | the unit panel: the list `CSingleUnitPanel::Rebuild` fills for a selected unit and the eighteen entry classes it is made of; what the header, the status, the order, the brigades', the subordinates' and the buttons' rows write into each element - the activity strip's frames, the strength as men, the two bars, the speed without `LAND_SPEED_MODIFIER`, the supply bars as the province's, `CUnit::DescribeOrder` and its `WHERE` being the next province; the tooltips and seven of the entries not read |
| `findings/FINDINGS-hierarchy.md` | the hierarchy lines of a selected unit: the `render_hierarchy` setting and the H key that flips it, the whole of `CMapRenderingOptions`' block in the settings, which units get a line and to where, a line's five colours and its width by rank, the picture and `hierarchy.fx`, when the mesh is made again and when it is drawn; and the rings: white on the selected counter or green where an AI commands it, and `color2` on every unit under it, given by `CUnit::OnSelected` |
| `findings/FINDINGS-seaair.md` | fleets and air units on the move: the right click's branches for both and the three orders views; the naval window's list and the air one's; `CMoveOrder`, `CRebaseOrder` and `CRebaseAirOrder` slot by slot, with the base changed the first hour and an air unit landing on half its organisation; **the correction that `AdvanceMovement` is called from `CheckOrderAndCombat`, not `UpdateHourly`**; `IsTargetInRange`, the sea index, ports as `naval_base` positions on sea pixels, lakes, and `CMap::BuildNavalDistances` - checked against `navaldist.bin` in all 17,621,016 cells; `CNavy::MayStandIn`, the five waters of the defines' `map` section, the fleet's rule in `MayStep`; building pictures on the map, the port's and the air base's frames, and `CPort::OnSelected`; checked against savegames for 17 fleets and an air unit |
| `findings/FINDINGS-seabattle.md` | **a battle between fleets, end to end**: `StartCombat`'s naval arm and `DefenderAcceptsBattle`; what the intelligence level of a sea province is for a fleet that is merely there (2) and one on patrol (9); **every ship's own distance** - where `CNavalCombatant::AddUnit` puts it and how `CNavalCombatant::Attack` closes or opens it; the shot, with the two dice widened by five and three times the enemy's stacking penalty; **who a ship shoots at** (`CSubUnit::PickTarget`: the remembered target, friendly fire, range as two distances added, the best target by `priority`); sinking; `CNavalCombat::MayLeave` and the four hours a fleet counts before it leaves; how a side loses and where a beaten fleet runs to. Corrects the record on `CNavalCombat::Tick` and on combat slot 12 |
| `findings/FINDINGS-navalmissions.md` | **a fleet's six missions, each one's hour**: the frame they share - `CNavalOrder::IsActive` made out, the stance's limit that sends a player's worn fleet to the nearest harbour, and **the return-to-base byte no naval order code clears**; the reserve's daily exchange of sound ships for worn ones; the patrol's round of the neighbouring sea provinces, its shadowing (the writer of `CUnit +0x95`) and **its try at the convoys every twelve hours**; intercept, sortie and the escort's beat along a convoy's route; and **the battle a convoy raid fights** - a throwaway fleet of destroyers and transport ships, five rounds at once, which is the writer of `CCombat +0x2B`. `reduction_modifier` is read and thrown away. Corrects `ResolveConvoyRaid`'s callers |
| `findings/FINDINGS-airbattle.md` | **the battle in the air**: the frame every air order shares - the day and night gate that makes `time` 0 day, 1 night, else both; `CAirOrder::IsActive`, by which an order outlives its sorties until its end date and a unit out of range loses it; how a mission's provinces are made. Air superiority's hour (`CAirPatrol`): the round of its provinces and the target it flies ahead of. The intercept's: the watch set two steps out, the meeting province, and its return once it has caught its target. The score both pick by, and the three wings that are enough for one enemy. **`CUnit::CanEngage`'s air arm corrected**: orders count only at a base. The one hour in which an air unit out of a battle cannot be fought (`CUnit +0xA0`). `CAirCombatant::Attack` whole: the shots, the five draws, the dice, the critical hit; the target a wing keeps, the random one and the best. Where a beaten air unit goes - out to sea, where there is any. And **what every country knows of every province**, `UpdateIntelFunctor_SerialBody` read to its end: 9 for the holder and its friends and for a unit's owner on land, 2 at sea, radar's two rings |
| `findings/FINDINGS-airorders.md` | **the air orders window whole**: what it holds and what it remembers from the last one; the ladder that ticks the first row, by fighters, sea attack, strategic and tactical bombers and the province's buildings. The four shapes - point, circle, cone, region - with `CAirOrder::SetSecondTarget`, the cone's bearing and arc test (whose `fmod` loses the part west of north), and a province's first region from `CMap::AssignRegions`. The sliders and the twentieth they must move by; the right click on the map that aims an area and the shift that adds to it; day, night and both as one choice; the two date widgets held to the defines' dates; accept, which sends no priority; the map's colours while the window is up |
| `findings/FINDINGS-airmap.md` | **the air map mode**: its setter, and its colours - grey, green under the player's intercepts, red under its air superiority, striped under both - made when the mode is chosen and when such an order of the player's starts or is destroyed, never daily; the circles of range round the player's air bases, one to each range of aircraft, coloured by strength through `circle.fx` and dimmed while another air unit is selected; the large air base and anti-aircraft pictures, sized by the built level; the three battle icons, with **the test of `UpdateAirMapIcons` corrected** (the player's co-belligerent, not a country that "exists"); the tooltip's two lines; and **the list of finished battles keeps a week** (`CCombatHistory::Prune`), with how a side's country is chosen for an entry |
| `findings/FINDINGS-leaderassign.md` | **who commands what at the start, and the choice of a leader**: every leader with a rank put in service as a game starts (`CCountry::ActivateRankedLeaders`); an order of battle's `leader` taken from the whole game with nothing checked; **every leaderless unit given the best free leader of its country as the game is entered**, in the order the units were made - `CUnit::AssignBestLeader`'s score, skill + 1 in thousands and a set amount per suitable trait effect, the first of equals winning, with `paradrop_mission` never counting; the exact rank a land unit takes (`CUnit::MayTakeLeader`), the looser one that counts (`LeaderHasRankForCommand`, read whole) and a fleet's or air unit's command size; placing, joining and a new headquarters gated by `auto_assign_leaders` (`CCountry +0x74B`); **`CUnit::SetLeader`'s two flags named**. Reproduces the start save's 1555 unit leaders and 101 lists of active leaders |
| `findings/FINDINGS-commandreach.md` | **how far a command reaches**: a headquarters' radius (its first brigade's `radio_strength` times `RADIO_*_LEADER_DISTANCE` by level), all of it within, the radius over the distance out to twice that, none beyond (`CUnit::CommandReachFrom`); the links multiplied up the chain (`CUnit::CommandReach`) and the walk to the top that is "out of radio range"; **a trait's effect down the chain, halved at every step** (`CUnit::CommandEffect`); the army commander's skill in the organisation ceiling and the hourly return, the army group commander's twentieth off what a unit uses; `ProvinceDistanceSquared` new; a new game's stockpile reckoned before leaders are chosen. **Corrects `FINDINGS-unitstart.md` section 8's call.** With it OpenHOI3 has 764 of 764 commanded brigades' organisation |
| `findings/FINDINGS-battleleaders.md` | **leaders in a land battle**, gathered and checked: a side's highest ranked leader, first of equals; **`CTraitTrigger::Evaluate` read** - the leader's own traits only; `BM_LEADER_BONUS` gated whole on rank and skill, so an unled unit gets none of its commanders' offence or defence traits; the trait in every other modifier, with all 63 `CommandEffect` call sites by kind; the theatre commander off crowding at any distance; **`fort_defence` dead** from the one caller; **the defender's front order confirmed off the instructions (`hard_attack` was the lost term)**; a corps in reserve counting its own commander |
| `findings/FINDINGS-seaairleaders.md` | **leaders at sea and in the air**, gathered and checked: `BM_LEADER_BONUS` behind `LeaderHasRankForCommand` **inlined in all four modifier passes**, with no trait; the unit's own leader, **with no rank test**, in drawing a fleet up, in `TargetingSkill` (the ten a static of 10.5) and in a bomber's list of ships; the side's highest ranked leader in positioning and **friendly fire** (the record had the admiral); eleven trait kinds by site; the disengage count cut to a whole number; **`CTechnologyStatus +0x70`/`+0x74` are `targeting_chance`/`targeting_choice`**; an admiral of skill 5 draws up at half the reach **or one further** |
| `findings/FINDINGS-battlegains.md` | **what a battle gives**: `GrantCombatExperience`'s enemy term - the other side's average organisation times its sub units, by the country list at `+0x54` - and **a ship gains nothing without a target**; the gainable-trait database filed once per allowed leader type in file order; **`CHasCombinedArmsBonus` and `CCombatTerrainTrigger` read** (the first never reads its value); **`is_winner` holds where the side has not lost**; the convoy raid's battle **never ended**, so its raider's trait hours are not counted against it |
| `findings/FINDINGS-leaderwindow.md` | **the window a leader is chosen in**, `CLeaderAssignmentPanel`: made fresh by the unit panel's `leader_button`, ended once hidden; **the list** - the owner's leaders in service of the unit's kind, commanding nothing or this unit, through a per-type trait filter kept in `CCurrentGameState +0xD6C` - sorted by name ascending or skill, traits or rank descending by the runtime's unstable `std::sort`, reversed on a second click, the key process-wide; a row's button disabled unless `MayTakeLeader`; what each button posts; `CAssignLeaderCommand::IsValid` and `CToggleAutoAssignLeadersCommand::Execute`; **corrects `FINDINGS-unitpanel.md`'s rule for the leader button** |
| `findings/FINDINGS-bombing.md` | **bombing**: the eight missions and the eleven slots that tell them apart - what each may be given for, which provinces it lists, which buildings, stockpile and production it bombs. The two frames an hour runs by: the strike frame, which keeps its province from sortie to sortie, and the bombing frame, which forgets it once a bombing has it. How each picks its province (slot 39), ground attack going round its list and interdiction taking the last one it knows. What starts a bombing and its three kinds; who is offered to it, and why a second bomber unit joins only a defender with units and no aircraft. The bombers' hour: the two lists of targets, the roll that puts a ship on one, `FireUnit` with its order's attack and its dice, and **`CSubUnit::BombProvince`, the reader of `strategic_attack`** - whole runs, never fewer than one. The fire that comes back: `StaticAntiAirTerm` read to its end, the ships' and the land units' own. Both sides' modifiers read through. A carrier's aircraft. **The daily repair** of production and buildings in `RunDailyProvincePass`. Five technology effects named, and three of the radar's |
| `findings/FINDINGS-topbar.md` | the top bar: what `CTopBar` writes into each element, in what format and colour, the buttons it wires, and the orientation keywords |
| `findings/FINDINGS-countryviews.md` | the production and technology screens: `CCountryView` and its country skin, the slider both share and what a `CDistributionSetting` tells it, the resource and research figures, where a technology goes in the tree, and the three entry classes |
| `findings/FINDINGS-textdraw.md` | where a text box puts its text: the font's slot 8, what `borderSize`, `format` and `orientation` do, the half pixel every glyph is drawn off by, and the `colorcodes` the colour escapes come from |
| `findings/FINDINGS-shatter.md` | shattering, and being removed from the game |
| `findings/FINDINGS-airdefence.md` | the three defence stats: parsed, stored, displayed - and never used to defend |

**The country: economy, politics, diplomacy**

| | |
| --- | --- |
| `findings/FINDINGS-ic.md` | how a country's IC is worked out |
| `findings/FINDINGS-production.md` | the build queue, and how IC and leadership are split |
| `findings/FINDINGS-buildqueue.md` | what `FINDINGS-production.md` left of the queue: a unit of several brigades' cost and days, the hundredth a level a queued brigade costs more, `CMilitaryConstruction::Deliver`, the order, cancel, move and place commands, how a new game turns an order of battle's `duration` into work done, and that a change of law prices the queue again - with all thirty starting lines' cost and days, and Germany's queue over four months, reproduced from savegames |
| `findings/FINDINGS-buildingqueue.md` | **the building-queue wave (2026-10-15)**: a building line ordered (`CConstructBuildingCommand`, the production screen's confirm dialog with its parallel and serial, the province view's one level a click, the AI's Lua), priced (`cost` and `time` by one category discount, 159 of 171 saved lines), worked and cancelled by its own slot 12, shown in the queue; finished as a built level the day's repair fills, or as a building waiting to be placed; where each building may go (`IsBuildingAllowed`, `CBuildingDeployment::CanDeployIn`), the placing map mode 14 and its click |
| `findings/FINDINGS-buildertooltips.md` | **the four builder windows' tooltips**, each window's slot 6 read whole: every column header's short name and description, the step buttons' "Ctrl + LMB" line, the designer's combined arms icons and **terrain summary** - its brigades' terrain, river, night, fort and landing adjusters averaged with the terrain's own figures and the defines' penalties - and **the practical icon's discount** from the in-game screen's own arm. Corrects `BuildBuilderSortColumnLabel`, which is the ledger's and has no builder caller |
| `findings/FINDINGS-builders.md` | the four windows a unit is ordered from - the division designer and its brigade picker, the ship, air and brigade builders: which types each lists and what rations an elite brigade, every column and total with its decimals, the order panel they share (serial and parallel, the three cost figures, the traffic light), what disables `accept`, the choice of a level for each of a ship's technologies, `CConstructSingleUnitCommand`, and how a new unit is named |
| `findings/FINDINGS-distribute.md` | the daily loop over the IC shares, the army term of consumer goods demand, the supply share, and crude oil into fuel |
| `findings/FINDINGS-leadership.md` | how leadership is worked out, the officer, diplomacy and espionage shares, when a province is overseas or non-core, the static modifier slots, and what a country starts a game with |
| `findings/FINDINGS-politics.md` | alignment, the seven drift terms, and the country's daily pass |
| `findings/FINDINGS-research.md` | research speed, the practical bonus, and tech decay |
| `findings/FINDINGS-researchshare.md` | how the research share's leadership reaches the queue, what finishing a level does, and the gain, cost and square root to the bit |
| `findings/FINDINGS-techdecay.md` | where practical and theory decay is actually applied |
| `findings/FINDINGS-occupation.md` | occupation, revolt risk, partisans and rebels; **the occupation and revolt wave (2026-10-14), sections A to F**: occupation policies set on a first capture keyed by the old controller and only by the player after, a province's whole modifier with nationalism, revolt risk's day with suppression over two edges settled against a save, the revolt map mode and tooltip, rebels made (one army of 1 to 4 brigades, equipped from the occupier) and their day and month (movement, hand-back, 15% independence; defection and demands dead), undergrounds whole, and `counter_espionage` settled |
| `findings/FINDINGS-revolt.md` | what consumes revolt risk: the roll, the rebel type, the underground |
| `findings/FINDINGS-convoys.md` | convoys and trade, and that the AI drives a route through the mod's Lua |
| `findings/FINDINGS-weathersim.md` | **the weather wave (2026-10-15)**: weather whole for a reimplementation - where it falls in the hour, a new game's 96 hours with the clock stopped and its temperature seed, the three draws on the shared generator, what a save keeps; every formula of the province hour, the fronts, the high pressure, the season and the edge bearing in instruction order (the bearing reproduces all 83,596 of the base game's cache); the weather map mode, its tooltip, and the cloud, rain and snow pictures on the map |
| `findings/FINDINGS-convoylines.md` | **the convoy-line wave (2026-10-15)**: transports and escorts in the build queue - `CConstructConvoyCommand` with its amount, priced once by the four defines and technology fields and never again, an item of `CONVOY_CONSTRUCTION_SIZE` ships at a time, the history's and the save's lines; the production screen's `convoy` and `escort` buttons, the confirm dialog in modes 1 and 2, the `(+N)` counts and the line on the queue |
| `findings/FINDINGS-espionage.md` | spies, intelligence, and what the espionage sliders buy; **the espionage wave (2026-10-14), sections A to E**: spies placed by priority bands and never decayed, what each mission does (a tech theft takes the target's whole level; covert ops a thirtieth of its define a day; province covert operations), what a country knows (the spies alone, less counter-intelligence) and of a province (the whole daily rebuild and hourly raise, radar), the intelligence screen with every estimate and tooltip, and the AI's spying in Lua, matching the saves pair for pair |
| `findings/FINDINGS-events.md` | events, and why a loaded save fires none until the month turns |
| `findings/FINDINGS-diploaction.md` | a diplomatic offer in flight: three stages, the lifecycle, the null singleton |
| `findings/FINDINGS-diplomacy.md` | how the engine asks the mod's Lua whether the AI accepts |
| `findings/FINDINGS-oob.md` | the order of battle, key by key |
| `findings/FINDINGS-faction.md` | the faction layer: one gateway, no alliances, and a leader you cannot set |

**Weather and the map**

| | |
| --- | --- |
| `findings/FINDINGS-weather.md` | weather, and what it actually does to combat and movement |
| `findings/FINDINGS-weatherfront.md` | `CWeatherFront`: the source of every weather number |
| `findings/FINDINGS-temperature.md` | temperature, and the one missing `abs()` that gives the south no winter |
| `findings/FINDINGS-mapmode.md` | the VP map mode, and where to take it over |
| `findings/FINDINGS-camera.md` | the map camera, and what moves it; and how high it is - its lens of 0.785 radians, its heights from 40 to 1000, and the two heights the map changes at: `counter_distance` for the near view and 500 for the far one |
| `findings/FINDINGS-counters.md` | a unit's counter on the map: the four textures and the colour its quad is made of, its size by rank, the flag and the two texts on the top one, the five stacks a province keeps and which units have no counter at all - a fleet in port, a wing at its base - and that `CUnit +0x1F8` is the player's intel level |

**The interface, and text**

| | |
| --- | --- |
| `findings/FINDINGS-gui.md` | the GUI framework: finding a thing by name, and what the combat-status window is |
| `findings/FINDINGS-guilive.md` | the live GUI: from a window name to the object holding the number |
| `findings/FINDINGS-history.md` | the history subsystem: a do/undo replay log, read every day, and what it costs |
| `findings/FINDINGS-guicontainers.md` | the subwindow map, and every `CWindowType::LoadKey` token's container |
| `findings/FINDINGS-guistatic.md` | the GUI read statically: the child lists, the empty registries, the ledger's class |
| `findings/FINDINGS-listbox.md` | how a list box lays out what is in it: rows, as many as go whole into the box's height, an entry with no row hidden and none cut off, `spacing` unused, scrolling by the row - and the two lists that go by their entries' heights instead |
| `findings/FINDINGS-deploymenu.md` | how a finished unit gets to the map: the sixteen alerts and the one that opens the deploy menu, the menu's two lists - the units waiting, then the units one of them may join - what a click on a line of each posts, and what joining is: one brigade moved into the target, anything larger put under it |
| `findings/FINDINGS-textureload.md` | which file a texture's name loads: a `.tga` is its `.dds` wherever one exists on the search path, one way only, and the three pictures the install holds as both |
| `findings/FINDINGS-uinumbers.md` | what the interface already computes |
| `findings/FINDINGS-uinumbers2.md` | what the interface already computes, part two |
| `findings/FINDINGS-messages.md` | the message system |
| `findings/FINDINGS-effecttext.md` | how an event option's effect text is built |
| `findings/FINDINGS-text.md` | how the game measures text |
| `findings/FINDINGS-provinceview.md` | **the province-view wave (2026-10-15)**: the window a selected province opens - it follows the selection, its refresh and every-frame update, each element's figure, intelligence gate and tooltip, the weather strip, the `adj` list and the cores box; the building columns (`show_for_province`, split at the database's middle), the pips (working, damaged, queued), a row's shortcut letter and tooltip; the `underground` window and which mouse button steps its mission; the covert-operations panel and the allied-objectives panel with `CSetAlliedObjectiveCommand` |
| `findings/FINDINGS-provincetooltip.md` | **the tooltip of a province**, `ProvinceTooltip_Build` read whole: a selected army's `UTM_*` line, the name and the owner, the terrain mode's flags, terrain and figures, the political mode's, the supply mode's lines put together with their colours and the line on infrastructure, the tail's distances; **the `@TAG` flag icon** in text, 23 by 11 below the line's top; `CArmy +0x300` the fleet carrying it |
| `findings/FINDINGS-topbartooltip.md` | **the top bar's tooltips**, `CTopBar::BuildTooltip` read whole by element name: the goods ledger's lines and colours, IC, dissent, diplomacy, national unity, officers and manpower; **how a modifier lists its contributors** (`CModifier` slots 6 to 9), and each modifier kind's two flags, percent and more-is-better; **corrects `BuildModifierEffectsText`, which is the definitions' initialiser** |
| `findings/FINDINGS-productiontooltip.md` | **the production screen's tooltips**, `CProductionView::BuildTooltip` read whole by element name: the resources' ledgers, a strategic resource's provinces by their infrastructure, the bombs, the escort, convoy, underground, theatre and building buttons; **what each of the ten shares' sliders says** at the slider's position (`CDistributionSetting` slot 5); a build queue line's; and **what `£name` draws in a text**, the middle of `GFX_counter_` + name. Corrects `BuildProductionPenaltyTooltip`, the whole line's tooltip with its arguments the other way round |
| `findings/FINDINGS-techtooltip.md` | **the technology screen's tooltips**, `CTechnologyView` slot 10 read whole: where leadership comes from, a tree entry's heading and double-click line, a theory's sharer, a queue line's priority buttons and research efficiency, a category icon's speed, and **the start button's days at full funding, carried over the year's end**. Its effects text and the `allow` trigger's account are not read |
| `findings/FINDINGS-tooltips.md` | **how a tooltip is shown**: `core.gui`'s `ToolTip` box, made by `CEU3Idler::Enter`; each frame `CEU3Idler::UpdateTooltip` asks slot 20 for it, adds the `delayed` halves under fourteen dashes once the clock is past the next whole second after the mouse stopped, trims, wraps at `maxWidth - 3 * border`, grows the box to fit and keeps it inside the right and bottom edges; an element's tooltip hangs 64 below its corner, or stands on it in the lowest fifth; a province's stands above the mouse; the console's `tooltips`; a button's shortcut line; `GuiTooltipText`'s fields named; **corrects `g_random_object`, which is the platform factory**; no `.gui` file sets a tooltip key |

**The record itself**

| | |
| --- | --- |
| `findings/FINDINGS-factbase.md` | the three halves of the fact base, and what disagreed between them |
| `findings/FINDINGS-sigaudit.md` | the signature audit: 87 disagreements down to 1, and the string size |

**The event script language, and the loaders**

| | |
| --- | --- |
| `findings/FINDINGS-definitions.md` | every loader's grammar, key by key |
| `findings/FINDINGS-triggereval.md` | how a condition **answers**: slot 6, `CEventScope`, and the absence of any cache |
| `findings/FINDINGS-script.md` | the event script language: 152 trigger keywords and 91 effect keywords |
| `findings/FINDINGS-fieldmap.md` | which field each key lands in |
| `findings/FINDINGS-effects.md` | the effect half: what each of the 91 effect keywords does when it fires |
| `findings/FINDINGS-numtriggers.md` | the 78 numeric leaves, what they compare, and the three scales their operands are on |
| `findings/FINDINGS-scopetriggers.md` | the scope and set triggers, and what `ally` really scopes to |
| `findings/FINDINGS-triggergrammar.md` | **how a key in a condition block becomes a condition**: the default branch's six databases, an ideology, a region and a scope; **an unknown key is reported only directly inside a block the engine made** and queued and dropped inside one the script wrote, which only a technology's `allow` replays; the 15 slot-7 bodies, the block triggers' own keys, every keyword's value form, case rules and the tag's three-character match |
| `findings/FINDINGS-effectgrammar.md` | **how a key in an effect block becomes an effect**: the lexer, the scalar and block tails and how a wrong value form leaks structure, the default branch's seven databases and then a scope, `limit` doing nothing inside a scope, every effect keyword's value form; **`CFaction +0xC` is a string** |
| `findings/FINDINGS-eventfiles.md` | **the containers**: how the event and decision folders are layered, an event's, an option's and a decision's keys, the MTTH and its modifiers, duplicate ids, and the two decision groups of which only one is ever listed |
| `findings/FINDINGS-triggerleaves.md` | **what every trigger leaf answers**, the 78 with no recorded `Evaluate` before 2026-10-12: which part of the scope each reads, what a missing part gives, the comparison, THIS and FROM, an unknown name. `month` is zero-based, `<unit type> = N` never holds, `faction_progress` is unscaled, the six `last_*_losses` are world-wide and never saved, `is_blockaded` is refreshed only with a controller, `has_building` crashes on an unknown name; `active_leaders` is a list |
| `findings/FINDINGS-effectrun.md` | **what every effect does when it runs**, the 68 with no recorded `Execute` before 2026-10-12 and the 31 that had one checked: what each changes, its scale, `this`/`from`, a missing scope part, side effects; the iterating scopes and `limit`; **the draw** `ally`, `local_enemy` and `random_*` make. `CCasusBelli::Activate`'s gate was backwards; `war`, `undeclared_war`, `add_wargoal` and `practical` never run their children; `change_manpower` and `leadership` change a province; `duration = -1` is for ever on a country; an election has no chance in it |
| `findings/FINDINGS-scripttext.md` | **every effect and every condition as words**, by a wave of five: all 78 effect `GetText` and 146 trigger `GetText` bodies word for word with both wordings, the scope blocks' headers, the effect renderer's indent that doubles with depth, a context's one-line form, and **a missing key shows as itself** (the record had `NO_TEXT_FOR_KEY`); about fifty keys the base game lacks |
| `findings/FINDINGS-onactions.md` | **the 13 on_actions site by site**: when each fires, its scope and who answers - a battle's pair once per country of each side, wins first, no combatant; `on_encirclement` on a landlocked pocket's first day without a depot, the owner answering; a coup a person's order only; a fired `fire_only_once` event shadowing those after it |
| `findings/FINDINGS-messageshow.md` | **how a message reaches the player**: each `messagetypes.txt` key (`idle` does nothing), the twelve copies of the post, the popup's text, layout, buttons and cascade, the log of 200 messages and 100 rows, the map's text, the variables looked up as keys, the categories, and the player's `messagetypes_custom.txt` |
| `findings/FINDINGS-diplostate.md` | **relation, threat and neutrality**: a new game's relations from the history one side at a time and then **the mod's Lua `AI_GenerateNonHistoricalRelation`** where still 0, made equal by the month - the start save 7,878 pairs of 7,878; the month's relation drift; every relation change with its define; **threat's two spreaders**, every source and **no decay**; the most-threatening country; neutrality's day, war exhaustion paid back at peace, the ceiling for war; and **the install's executable carrying BiceLib's patches** (trap 19) |
| `findings/FINDINGS-luahost.md` | **how the exe hosts Lua**: a state per thread with all eight libraries, luabind 0.9, a PhysicsFS searcher at `package.loaders[2]` (mod, TFH, base), autoexec; a new game's `AI_GenerateNonHistoricalRelation` - the country by pointer, the tag a copy, `lua_tointeger` rounding to even, **25 on an error** - and **`Laws(country)` for every country, the player's included**; `==` on governments and factions by save token; the device made without `D3DCREATE_FPU_PRESERVE`, so the main thread's Lua ran at 24 bits |
| `findings/FINDINGS-luaapi.md` | **the Lua API the AI answers offers with**: the bridge pushes the recipient's AI and three tag copies and **answers 0 on a Lua error**; `SpyMission` the only engine global read as autoexec loads; the fourteen `DiploScore_*` reach 76 methods, each read; `CFixedPoint:Get()` a float, the arithmetic with a number on the left **reversed** for `-` and `/`, division by nought -1; the clausewitz iterators, **an array's loop ending at its first null**; `==` on tags, groups, continents; `IsLandSafeToJoin` true only at peace; the alignment distance by way of single precision; `CAIIntel` reading espionage |
| `findings/FINDINGS-tradeaid.md` | **trade and aid**: a trade route's two blocks and its price `goods_cost x amount x (1 - 1/2 x (relation+200)/400)`, fixed at the offer, reproducing all 582 saved routes; the trade window, the day's exchange in the proposer's pass, the convoy and when one is needed, how a route ends; the AI's trading through `ProposeTrades` / `EvalutateExistingTrades` and every method the trade and aid scripts reach; debt (never reduced, repaid for ever), licences (the seller's model built in the buyer's queue), lend-lease (IC through a convoy that carries nothing), shared technology; corrects `CTradeRoute +0x34/+0x44`, the debt's direction and `SetTrading`'s sign |
| `findings/FINDINGS-tradeui.md` | **the trade interface**: the production screen's trade list (`CTradeItem`) - a line is the partner's flag and name and an icon a good, the player's gives under Export and gets under Import, no figures - its tooltips and `CTradeCancelConfirm`; the trade messages' `ACT_TRADE` / `REC_TRADE` / `ACTORS`, all filled; Automate Trade a local flag, no command; an offer to the player in `eu3dialog.gui`'s `DefaultDialog` for all twelve `CAsk*`; the bar of offer icons, ten 40 apart, blinking from 120 h, declined at 168 h or by a right click; the request dialogs at the screen's centre plus `diplo_request_pos`; corrects `FINDINGS-tradeaid.md` A.6. **D**: the lend-lease window (sliders kept at 100 by equal parts, the set posted once a second), the licence dialog's rows (the seller's model, "+*"), the share-technology dialog; corrects the licence row tooltip and the slider limit marker (strictly above nought). **E**: lend-lease's IC to the thousandth - the giver's share, the receiver's whole IC after the cap, the free pool in each of the five other shares, the lend-lease convoy's manning; corrects `+0x608`'s source and finds reinforcement and upgrades never ask the stockpile |
| `findings/FINDINGS-war.md` | **war and peace**, four briefs. **A**: `CDeclareWarAction::Apply` in 21 steps - a fresh `CWar` or one widened, puppets, guarantors (a call built already accepted) and factions in at once, the overlord and allies only asked, threat, name and `limited` for a fresh war only, the war's name, its messages; `CWar` whole; `at_war` and mobilisation; a declaration needs a valid war goal. **B**: the call to arms both kinds (the screen's only in a limited war), declining breaks the alliance; the declare-war dialog `CWarGoalDialog` and the add-war-goal cooldown; every casus belli made in play is the null type, nothing grants one, `mutual`/`months`/`prerequisites`/`truce_months` unread. **C**: peace has no terms - provinces to the occupying side's core holders, the whole war ended, no goal enforced, nothing charged; only a person offers one; `DiploScore_PeaceAction` down to `CAIIntel`; nothing removes a war. **D**: surrender progress over owned cores against national unity; the capitulation enforcing every enemy's goals in `peace_order`, annexing last, `conquer` as the fallback, exile, vassals; `CWarGoal::Enforce` per peace option. Corrects `last_war` (not hourly: a truce counts from the last load or membership change), `CCasusBelliType +0x1F4` (`months`, not `truce_months`), `+0xBE0`/`+0xBE4` (cores, nested), `CWarGoal::IsValid`'s name |
| `findings/FINDINGS-surrender.md` | **the surrender wave**, what peace and the capitulation call, read whole on the listing and raised to confirmed. **A**: `AnnexCountry` both modes - `ANNEX` to everyone, the faction left, land to its occupier or the annexer, constructions deleted, units destroyed or (surrender mode) gone over on an even draw, wars left, other countries' statuses reset, threat -9999; the `surrender` console command. **B**: `MakeVassal` in thirteen steps - the puppet joins its faction leader's wars, its own puppets freed, relation +200, the overlord's government - and `CCountry_AfterDiplomacyChange`. **C**: `SetGovernmentInExile` both ways, the puppet swap, and every reader of `+0x95`. **D**: `Province_SetController` and `ChangeOwner` - pushback damage, production zeroed, a fallen capital's 25% loot, rebasing - and the acting capital (`UpdateActingCapital`). **E**: `CAIIntel`'s draw is never negative. Corrects `+0xA08` (`pool_in_exile.money`), `+0xA64` (`received_from_exiles`), the loot, the rebasing, `UpdateOwnerAreaOfProvince`'s caller |
| `findings/FINDINGS-factionplay.md` | **the faction wave**, three briefs. **A**: `CFactionAction` whole - `value` is the direction (1 join, 0 invite), not a gate; validity, the greyed row and its tooltip; nothing on a proposal, the charge on acceptance to the actor; the joiner and every country whose overlord it is into the faction, its alliances with the members ended; the messages and who is told; `DiploScore_InviteToFaction` with the tags swapped for a join; the dialog printing the alliance costs; `CJoinFactionGoalAction` a vestige nothing creates. **B**: no leave in a normal game - the leave button is the custom game's (`Cgm_*`), a toggled intention applied at the stage's confirmation; `CFaction::RemoveMember` confirmed; every way out; **the faction rules are written** - `CCountry::RebuildRules` through `CRule::Merge`'s disp8 stores - so the Allies' faction-wide guarantee and call to arms are live and the Axis AI declares limited wars; the strategic bonus distance is to the faction's corner. **C**: a faction's progress is the victory points its members **control**, made hourly; the share cut to a tenth of a percent; the null faction's never reset; the victory conditions of `common/faction_aims.txt`, each faction's 15 primaries, tested daily and not latched; 12 met ends the game (`VCConfirm`, slot 75; a scenario's slot 76); `game_finished` saved from `+0x40`, loaded into `+0x41`. Corrects `FINDINGS-agreements.md` C.3, `FINDINGS-war.md` C.10, `FINDINGS-trade2.md` §11, `FINDINGS-diploaction.md` (`Apply`'s gate) and settles `FINDINGS-diplomacyview.md` F.10 (met / chosen) |
| `findings/FINDINGS-capitalreaders.md` | **which capital each reader reads**, for OpenHOI3's acting capital: every one of its reads of a country's capital set against the original's - the acting capital the default (economy, supply, convoys, trade, threat, alignment, placement, `capital_scope`), the declared capital a short list (script's `capital`/`is_capital`/`continent`/`$CAPITAL$`, the neutrality ceiling's and lend-lease's continent, a NAP broken, a trade convoy's reference harbour, possible vassals, the division designer); history's `capital =` sets both (`CCountryCapitalChange::Apply`), a history goods line sets the pool (`CGoodsChange::Apply`), and the puppet's tribute (`CCountry_PayTributeToOverlord`), which stops while its government has fled |
| `findings/FINDINGS-agreements.md` | **the agreements**: an AI answers its offers **every hour** - `GetAIAcceptance` 30 or less declines, else a roll of the game state's generator below the score accepts, one trade a call (the accept-all loop is the **tutorial's**, correcting `FINDINGS-diploaction.md` §5); the player's icon and dialog, lapsing in seven days unopened and two months opened; the diplomacy screen's action list row by row, slots 10-14, 20, 21 of every kind, the dialog and its chance band, the seven-day diplomat en route (`next_offer_allowed`'s reader); each pact's slot 7 arm by arm, the daily end of agreements (a NAP after 45 months, a guarantee after twenty years), the NAP's border balance, embargo cancelling trade, influence and align, the relation list's save and load |
| `findings/FINDINGS-alignment.md` | **the alignment triangle**: a country starts at its history's point, unclamped, and **steps once on a new game's first day** - the start save 93 of 101 to the thousandth; the step every `ALIGNMENT_INTERVAL` + 1 days, not saved; the seven terms with the two floors (0.1, 0.25); **revanchism 5 x (1 - s)**, the clamp to the triangle with its sign slip; the acting capital, the distance and the day's order threat's spread needs |
| `findings/FINDINGS-diplomacyview.md` | **the diplomacy screen element by element**: the five tabs and who each lists, one sort flag for nine buttons, a row with its threat and seven tinted icons and their tooltip, choosing a country; the chosen country's panel, its 19 kinds of status line, the relation list with its colours and the drift tooltip, the war goals, the influences, and every tooltip; the triangle's markers and where they stand, the faction boxes, a marker's drift tooltip sorted by faction, a faction's rules and modifier, the relation's breakdown and the war ceiling's lines |
| `findings/FINDINGS-eventfire.md` | **an event firing, a decision taken, and the two windows**: `FireEvent` read whole - who answers, `immediate` first, the AI's option drawn on a wall-clock-seeded MT19937, a person's window answering itself with option 0 after four months - the option and decision commands, the already-fired registry, the on_actions (unweighted; the only way a province event fires), decisions (no taken-marker, `ai_will_do` never read, the AI's chance in Lua, only the diplomatic group offered), the event window by element and its `$VARIABLES$`, and the decision list |
| `findings/FINDINGS-government.md` | **the politics wave**, five briefs. **A**: `CChangeLawCommand` and `CChangeMinisterCommand` whole - nothing checked in `Execute`, whoever posts is responsible; a law change charges `cost x 30 days of money at MaxIC` to a country a person plays, tells `LAW_APPOINTED`, rebuilds the modifier and cuts every brigade to its new ceiling; a minister change only writes the post and tells `MINISTER_APPOINTED`; `CCountry_FillMinisterPosts` (the **last** group-mate wins, 220/220 posts), the pool and the peace-time revert of disallowed laws; no minister ever dies. **B**: `CIdeologyData` and its five-slot tally; the **monthly** party drift (a tenth of the gap to organisation, `ruling_party_support`, a random 0..999 draw, the minister dissent penalty) - 101/101 null parties; `CCountry_AllotCabinetSeats` whole, 606/606 cabinets; the election's schedule (`g_NullDate` means "hold one now", elections never forced); the coup. **C**: dissent has no decay - consumer goods and script only; **national unity moves daily** by a thirtieth of a monthly figure, damped by the square root of the distance from 50, through `ChangeNationalUnity`'s three callers; strategic warfare's three lists; what both do elsewhere; the daily pass's unread helpers named. **D**: `CPoliticsView` element by element - the pie, the organisation bars, the legend, the elections line, the cabinet rows and the minister choice, the law rows, the cost and the confirmation, mobilisation, puppets and liberation, every tooltip, the top bar's button; the seven `C*Change` history classes, replayed at start and never in play. **E**: the AI's politics - `CAIPoliticsMinister` daily in hour `(id + 17) mod 24`, a C++ refill of empty posts on the 1st, 8th, 15th, 22nd and 29th, `PoliticsMinister_Tick`'s draws on the game state's own generator, `Laws()` run for every country (the player's too) while a new game is set up, free and silent, and the Lua API it reaches. Corrects `FINDINGS-politics.md` (phase 4's sentinel and forced election, `0x4F72F0`, `+0xBCC`'s call, the database names), `FINDINGS-luaapi.md` (`GetRulingIdeology`), `FINDINGS-ai.md` (the politics minister's constructor) and `RandomThousandths` |

## A method worth reusing

**`definesMap.py` backwards.** Scan for `call GetDefines (0x445D90)` followed within a few
instructions by `[reg + <block>]`, then read which `+<field>` comes next. A define is read from only
one or two places in the image, so this turns a name in `defines.lua` straight into a function
address with no guessing. Four of the politics candidates came from it, and **it has not been
pointed at the economy or combat defines yet**, which is the live part of this note.

**A negative result from it is not evidence** - three different things hide a define, and all three
are written up as trap 8 in `TRAPS.md` with the check for each. That text used to be duplicated
here; it is not any more.
