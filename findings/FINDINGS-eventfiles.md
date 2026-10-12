# Event and decision files

*Read out of the executable on 2026-10-12, statically, for OpenHOI3's loading of events and
decisions. Addresses are virtual (image base `0x400000`), with the rva where the record is cited.
This builds on `FINDINGS-events.md`, which has how events fire; this file is how they are loaded.
The trigger and effect grammars are `FINDINGS-triggergrammar.md` and `FINDINGS-effectgrammar.md`.*

**Synopsis.** Which files are read and in what order, the file-level keys, and every
non-trigger, non-effect key of an event, an option and a decision - all settled from the bytes. A
mod's folder replaces or extends the base folder per folder, and on `extend` a mod file with the
same name as a base file replaces it. `g_event_list` is two lists, country events at `+0x00` and
province events at `+0x10`. Decision files accept only `diplomatic_decisions` (the base game's)
and `political_decisions`; any other top-level key abandons the rest of that file. `ai_will_do`'s
`factor` is read with `atoi`, so `factor = 0.75` becomes 0. **Corrected:** `LoadEvents` (rva
`0x5C0430`) takes its list in ECX, not on the stack (checked at both call sites: `mov ecx, eax`
after `GetEventList`, a bare `ret`), and has a second caller, `CInGameIdler::Enter`, so events are
re-read on every game entry; `g_event_list`'s `+0x10` holds the province events, which
`FINDINGS-events.md` left open. Flagged, not changed: `CMeanTimeToHappen::GetDays`'s comment calls
`0x9C56B0` "decisions"; it is the mission chooser (it builds `CNullMission`).

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| `0x5C0430` | `LoadEvents` | **revised** | confirmed | was `__cdecl(void*)`, likely; now `__fastcall(CEventList* list@ECX)`, a second caller (`CInGameIdler::Enter`); a scenario's one file replaces the folders |
| `0x1715670` | `g_event_list` | **revised** | confirmed | a `CEventList`: country events at `+0x00`, province events at `+0x10` |
| `0x5BF720` | `ClearEventList` | new | confirmed | the list in EDI; deletes every event in both halves |
| `0x5BF7B0` | `LoadEventFile` | new | confirmed | one file: `country_event` / `province_event`; missing title, desc or options logged and kept |
| `0x5C0520` | `LoadEventFolder` | new | confirmed | the files by folder mode 0/1/2; base-only files first, then every override file |
| `0x5BED90` | `CEvent::CEvent` | new | confirmed | 0x174 bytes; `immediate` is a `CEventOption`; MTTH days default to 1 |
| `0x5BEF20` | `CEventOption::CEventOption` | new | confirmed | `this` in EAX; `ai_chance` factor defaults to 1.0f |
| `0x5BF300`, `0x5BF330`, `0x5BF360`, `0x5C1FE0` | `CEvent::GetTitle`, `GetSubtitle`, `GetDesc`, `GetPicture` | new | confirmed | the strings at `+0x100`, `+0x11C`, `+0x138`, `+0x154` |
| `0x5C14D0` | `CEventOption::GetName` | new | confirmed | `+0x48` |
| `0x598440` | `CDecision::CDecision` | new | confirmed | the name as a string by value; `ai_will_do` is a `CMeanTimeToHappen` |
| `0x598E30` | `LoadDecisions` | new | confirmed | two group keys; an unknown one abandons the file; every key inside a group is a decision's name |
| `0x598CF0`, `0x598BD0`, `0x598C30`, `0x599B50` | `DestroyDecisionDatabase`, `GetDecisionDatabase`, `ConstructDecisionDatabase`, `SetDecisionDatabase` | new | confirmed | the decision database's life |
| `0x4BA30` | `CDirectorySettings::CDirectorySettings` | new | confirmed | 15 folder slots and their order |
| `0x69D050`, `0x69D000` | `CReferenceObject::SetId`, `AssignNewId` (slots 6, 7) | new | confirmed | a duplicate id of type below 0x65 is logged and kept |
| `0x69D250` | `RegisterPersistentId` | new | confirmed | pushes on the bucket's head, so the later of two objects with one id is found |
| `0x1685558`, `0x17154C0` | `g_CDirectorySettings`, `g_decision_database` | new | confirmed | the path registry and the decision database |

The struct fields - `CEvent`, `CEventOption`, `CDecision`, `CMeanTimeToHappen`, `CAIMTTHChance`,
`CEventList`, `CDecisionDatabase`, `CDirectorySettings` - are all new and are in
`fragments/merged/event-decision-containers.json`.

## 1. Which files, in what order

**The path registry.** `g_CDirectorySettings` (rva `0x1685558`) points at a 0x3C8-byte
`CDirectorySettings` (vftable `0x15BB3D8`, base `CPersistent`). Its constructor `0x44BA30` lays
out 15 folder slots, each a base folder name at `+0x80 + 0x1C*i`, an override directory at
`+0x224 + 0x1C*i` and a mode at `+0x44 + 4*i`, in the order common 0, **events 1**, gfx 2,
history 3, interface 4, localisation 5, map 6, sound 7, **decisions 8**, missions 9, units 10,
technologies 11, script 12, cgm 13, battleplans 14. `confirmed` from the constructor; the live
strings in `FINDINGS-mapbuild.md` §10 agree.

**The three modes** (`confirmed`): `CDirectorySettings::LoadKey` (rva `0x4BCD0`) reads `name`,
`replace = "folder"` (mode 1) and `extend = "folder"` (mode 2); the folder is lower-cased and
matched against the base names, an unmatched one logging `Error in modfile. Token "x" is not
recognised.` Mode 0 is the default.

**`LoadEventFolder` `0x9C0520`** (rva `0x5C0520`, `__stdcall(list)`, `ret 4`), `confirmed` from
the disassembly:

- **mode 0:** every `*.txt` in the base folder;
- **mode 1:** every `*.txt` in the override directory, and none of the base folder;
- **mode 2:** the base files whose name is not in the override listing (a byte compare of the
  whole name), then every override file - **an override file of the same name replaces the base
  one; every other file of both is read**.

Base-only files first, then the override files, each in the order `ListFilesWithExtension`
(`0x66BCB0`) returns them - that this is `FindFirstFile`'s order, and so the name test
case-sensitive, is `inferred`. **Decisions** choose their files by the same code, inlined into
`LoadDecisions`, reading slot 8.

**When.** Events: `LoadEvents` `0x9C0430` at start-up (`LoadEverything`, under `LOAD_EVENTS`)
**and again on every game entry** (`CInGameIdler::Enter` `0x65AC0A`), first deleting every loaded
event (`ClearEventList`); with a scenario set (`CCurrentGameState +0xD0C`) it reads only the one
path at `scenario +0xB0` and no folder (`inferred` to be a scenario file's `events = "..."`).
Decisions: `LoadDecisions` `0x998E30` has one caller, in the database stage after the casus belli
types and the missions - read once per process.

*Not established:* how `tfh\` and a TFH-style mod's `replace_path` map onto base, override and
mode. The descriptor's `replace_path` token (`0x1A8`) has no compare in `.text` found by a scan
that does find the `path` token's (`0x19C`) as a positive control - a jump-table compare would be
invisible to it - and no code was found writing the override strings. In the install, `tfh/events`
shares 27 file names with `events/` and `tfh/decisions` 16 with `decisions/`.

## 2. An events file

`LoadEventFile` `0x9BF7B0` (rva `0x5BF7B0`, `__stdcall(CEventList*, Hoi3CString* path)`, `ret 8`,
logging under `eventmanager.cpp`):

    file := { (country_event | province_event) = { <event> } }*

- **`country_event` and `province_event`** each allocate a 0x174-byte `CEvent`, **append it to
  the list first** and then load it (`CPersistent::Load`). They build the same class; only the
  list differs - country events to `+0x00`, province events to `+0x10`.
- After loading it logs, **and keeps the event**, for a missing title, desc, or options (`Event
  #<id> is missing a title in <file>`, `... desc ...`, `... has no options in ...`). An event with
  no options is kept but never a candidate.
- **Any other top-level key** logs `Corrupt Event Table Entry - <key> in <file>` and the loop goes
  on. Its value is not stepped over, so a block after it is read as more top-level keys and a
  `country_event` nested in it would still load - `inferred`, from the reader taking only key,
  `=` and one token.
- At the end: `Events loaded <file>' #<count>`.

**A country and a province event differ in**: the list (`confirmed`); **which can fire by MTTH** -
only `+0x00` is walked by `RebuildCountryEventCandidates`, so only country events become monthly
candidates; the only reader of `+0x10` found is the console's `event` command (`0x43C2E0`), which
gives such an event a province scope (the capital if none is given). The search was all 19
references to the global and all 18 callers of `GetEventList`, which also find the `+0x00`
readers. So **a non-triggered `province_event` with an MTTH has no path to fire found**
(`inferred`); the base game has 8, BlackICE 1. The event window does not depend on the kind:
`CEventWindow` (`0x9C2010`) takes the province window where the *scope's* province is 1 or more
(`inferred` that it reads scope `+0x28`).

## 3. An event

`CEvent::LoadKey` `0x9BF420` (rva `0x5BF420`). `CEvent` is 0x174 bytes, base `CReferenceObject`,
vftable `0x15F5974`; defaults from `CEvent::CEvent` `0x9BED90`.

| key | value | where | default | notes |
| --- | --- | --- | --- | --- |
| `id` | integer, `atoi` | the id pair `{0x28, N}` at `+0x8/+0xC` | none | through `CReferenceObject::SetId` (slot 6); **a duplicate is logged (`Failed to create id 40 N`) and kept**, and the later one is what a lookup by id finds - `country_event = N` and the console; both stay in the list. Not a number: 0 |
| `title`, `desc` | string, kept raw | `+0x100`, `+0x138` | empty, logged | localisation keys, resolved at display with the scope's substitutions (`0x9C35E0`) |
| `subtitle` | string | `+0x11C` | empty | shown only when not empty |
| `picture` | string | `+0x154` | empty | `gfx/pictures/events/` + name + `.tga`; the order `inferred` |
| `is_triggered_only`, `major`, `fire_only_once` | **the `yes` token only**; anything else is 0 | `+0x170`, `+0x171`, `+0x172` | 0 | `fire_only_once` is tested by the id pair against `CCurrentGameState +0xC38` |
| `trigger` | block | a `CAndTrigger` at `+0x30` | empty | a second `trigger` loads into the same object, so the two are ANDed (`inferred`) |
| `mean_time_to_happen` | block, §5 | a `CMeanTimeToHappen` at `+0xE4` | **days 1** | with none, `GetChance` gives **half a chance a day** once the trigger holds; 29 non-triggered base game events have none |
| `immediate` | block | **a `CEventOption`** at `+0x70` | empty | so `name` and `ai_chance` are accepted in it too |
| `option` | block, §4 | a new 0x64-byte `CEventOption`, loaded, pushed on the vector at `+0xD4` | none | file order |

**Any other key** is dropped with no message: `CEvent::LoadKey` has no default case.

## 4. An option

`CEventOption::LoadKey` `0x9C15A0`; `CEventOption` is 0x64 bytes, base `CPersistent`, vftable
`0x15F5958`, constructor `0x9BEF20` with `this` in EAX.

| key | value | default |
| --- | --- | --- |
| `name` | string, a localisation key, `+0x48` | empty |
| `ai_chance` | a `CAIMTTHChance` at `+0x08`, §5 | days 1, factor 1.0 |
| **anything else** | handed as it comes to `CEffect::LoadKey` on the `CEffect` at `+0x28` | |

So **an option's body is one effect block**, in file order, but for the two keys above.
`confirmed`.

## 5. `mean_time_to_happen`, `ai_chance`, `ai_will_do`, `modifier`

**`CMeanTimeToHappen`** (0x1C bytes, vftable `0x15F5CB8`; days at `+0x8`, the modifiers a `CList`
at `+0xC`). `CMeanTimeToHappen::LoadKey` `0x9C4BF0`, `confirmed`:

| key | reading |
| --- | --- |
| `days = N` | `atoi(N)` days - whole numbers only, `1.5` is 1 |
| `factor = N` | **the same case as `days`** |
| `months = N` | `atoi(N) * 30` |
| `years = N` | `atoi(N) * 365` |
| `modifier = { ... }` | a new 0x44-byte `CMTTHModifier`, loaded and appended |
| anything else | logged: `unknown command '<key>' for MTTH in file <f> - line <n>` |

The last of `days`, `months`, `years` and `factor` written wins; the default is 1.

**`modifier`** is a `CMTTHModifier`, a `CAndTrigger`: `factor` through `ParseFixedPoint`, **in
thousandths** (`0.5` is 500), every other key to `CTrigger::LoadKey`, ANDed (`0x9C4A00`,
`confirmed`).

**`ai_chance`** is a `CAIMTTHChance` (0x20 bytes, base `CMeanTimeToHappen`): **`factor` read
with `sscanf("%f")`** into a float at `+0x1C` (a failure is a parse error), every other key to the
MTTH loader - so it takes `days`, `months`, `years` and `modifier` too (`0x9C4F20`, `confirmed`).

**`ai_will_do` is a plain `CMeanTimeToHappen`** (the `CDecision` constructor writes that vftable at
`+0xC4`, `confirmed`): its top-level `factor` is the `atoi` days, so **`factor = 0.75` becomes
0** - BlackICE writes `ai_will_do = { factor = 0.75 }` 18 times. A `modifier`'s factor inside it
is still thousandths. What the engine or the AI does with it was not read; the AI's decision pass
(`0x89DD50`) goes through Lua.

## 6. A decisions file

`LoadDecisions` `0x998E30` (rva `0x598E30`, `__stdcall(db)`, `ret 4`, logging under
`decision.cpp`), `confirmed` from `0x999564`..`0x9997C9`:

    file  := { group = { (<name> = { <decision> })* } }*
    group := diplomatic_decisions | political_decisions

- **`diplomatic_decisions`**: name table at `db +0x00`, vector at `+0x0C` - what the base game (42
  files) and BlackICE (99) write.
- **`political_decisions`**: table at `+0x1C`, vector at `+0x28`.
- **Any other top-level key** logs `Corrupt Decision Table Entry - <key> in <file>` and
  **abandons the rest of that file**. `country_decisions`, `province_decisions` and
  `religion_decisions` exist as tokens but this loader takes none of them.
- **Inside a group, every key is a decision's name**: copied into `CDecision::CDecision(name)`,
  put in the group's table (on the bucket's head), pushed on the vector, then loaded.
- **Two decisions of one name** are both kept; a lookup by name finds the later one (`inferred`).
- Logs `Decisions loaded <file>' #<n>`.

**Who uses which half** (all 32 references to `g_decision_database` and the 4 callers of
`GetDecisionDatabase`): every walk over a vector walks the diplomatic one - the
`decisions_listbox` code (`0x78C560`), the AI (`0x89DD50`), and `0x606D41`, which asks each
`potential`; lookups by name try both tables (`0x4D59D0`, `CExecuteDecisionCommand` slots 6 and
14), and `0x476701` the diplomatic one alone. So **a `political_decisions` decision loads and can
be reached by name, but nothing found lists it, shows it or offers it to the AI** (`inferred`; a
walker reached through a stored pointer would escape this census).

*2026-10-12, `FINDINGS-eventfire.md` section 2: the addresses above are VAs. `0x606D41` is the
decisions' alert (`CAlertManager_Update`), not a second AI walk; the lookups at `0x4D59D0` are in
`SetUpCountryForNewGame` (VA `0x4D6230`), the function at `0x4D59D0` ending just before it; and the
conclusion stands, now `confirmed` by a sweep of every piece of code that reaches the database.*

## 7. A decision

`CDecision::LoadKey` `0x998960`; `CDecision` is 0xE4 bytes, base `CPersistent`, vftable
`0x15F396C`, name at `+0x08`. `confirmed`:

| key | where | default |
| --- | --- | --- |
| `potential` | a `CAndTrigger` at `+0x24` | empty |
| `allow` | a `CAndTrigger` at `+0x64` | empty |
| `effect` | a `CEffect` at `+0xA4` | empty |
| `ai_will_do` | a `CMeanTimeToHappen` at `+0xC4`, §5 | days 1 |
| `major` | a byte at `+0xE0`, the `yes` token only | 0 |
| anything else | dropped silently | |

## 8. How they are held

- **`g_event_list`** (rva `0x1715670`): a 0x20-byte `CEventList`, two `CList`s of `CEvent*` in
  read order, country events at `+0x00`, province events at `+0x10`. Events are also in the
  persistent registry under `{0x28, id}`, which is how `country_event = N` finds one.
- **`g_decision_database`** (rva `0x17154C0`): a 0x38-byte `CDecisionDatabase`, two halves of a
  511-bucket name table and a vector, diplomatic at `+0x00` and political at `+0x1C`, made lazily
  by `GetDecisionDatabase`.

## Not established

- What writes the override directories, and how `tfh\` and a `replace_path` descriptor become
  base, override and mode (§1).
- What happens to an unknown top-level key's block in an events file (§2).
- Whether province events with an MTTH ever fire (§2).
- How the engine uses `ai_will_do` and `ai_chance`; the AI's path goes through Lua (`0x89E5B0`,
  `0x89E630`, `0x89E800`).
- `CEvent +0x14`, a string the constructor clears and nothing found writes.
- `0x69D310`, the registry's removal; and whether `FireEvent` takes the list in EAX.
