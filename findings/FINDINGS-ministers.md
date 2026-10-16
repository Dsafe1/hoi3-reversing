# The tech and production ministers

Read statically on 2026-10-16, for OpenHOI3's stage 5, the AI: the ministers wave (`WAVE.md` until it landed, then
`CANDIDATES.md`). Both ministers are the install's Lua - `TechMinister_Tick` in `script/ai_tech_minister.lua`,
`ProductionMinister_Tick` and `BalanceProductionSliders` in `script/ai_production_minister.lua`, with
`ai_support_functions.lua`, `utils.lua` and the countries' files - so this is what the engine does around them: when it
calls them, for whom and with what, what each engine method they reach answers, and what the commands they post do.
`FINDINGS-ai.md` has the ministers, their objects and their schedule; `FINDINGS-luaapi.md` and `FINDINGS-luahost.md` the
bridge. Addresses are **virtual**, based `0x400000`, with the rva beside a named one.

Four sections, one a reader:

- **A. The tech minister** - the exe's side, what the script reaches, the research and leadership commands, `math.random`.
- **B. The production minister** - the exe's side, the daily `BalanceProductionSliders`, `FastNormalizeByPriority`, the
  investment command, `PrioritizeBuildQueue`, an AI country's finished unit.
- **C. Units and constructions, as the production script reads them.**
- **D. Provinces and buildings, as the production script reads them.**

## A. The tech minister

The script is Their Finest Hour's `tfh/script/ai_tech_minister.lua`, with `utils.lua` and `script/country/*.lua` for the
countries' own hooks.

**In one line.** A country nobody plays has a tech minister whose two arguments are always true, so every day in its hour
the script both sets the four leadership shares and fills the free research slots. The exe's monthly re-plan decides
nothing; a finished level of a technology of several levels takes it off an AI country's queue; `CStartResearchCommand`
appends and refuses only a duplicate; and `math.random` is MSVCR80's `rand`, one sequence a thread, from seed 1.

**Corrections.** `CEU3AI::CreateMinisters` makes the player's tech minister on `GetLocalPlayer()+0x30 != 0` - the
four-way `automate_tech_sliders` - and not on flags[2] as `FINDINGS-ai.md` had it (checked: `cmp [eax+0x30], ebx` at
`0x888C6F` before `CAITechMinister::CAITechMinister` at `0x888C89`). Slot 47, recorded as `OnCountryEvent` (`likely`), is
the notice that a level was researched (A.3). `Lua_TechMinister_Tick`'s signature lacked its two register inputs.
`CCountry +0x105C`/`+0x1060` mean something narrower than recorded (A.6). `GetInfluencedCountryCount` is raised to
`confirmed`, and `CTechnologyView::SendDistribution`, "not read", is read (A.4).

### A.1 Who has one, and what it is handed

**Its making and the two bytes.** A country nobody plays always gets one (`CAITechMinister::CAITechMinister`, 0x80 bytes,
`CEU3AI +0x6C`), with **`vbSliders` (`+0x5C`) = 1 and `vbResearch` (`+0x5D`) = 1**, which nothing changes for it again.
For the local player it is made only where `GetLocalPlayer()+0x30 != 0`, the save's numeric `automate_tech_sliders`
(Germany's April save: `=1`), which sets the bytes (`0x888D66`-`0x888DA3`; `ApplyPlayerDelegation`, rva `0x488F30`, the
same switch):

| `automate_tech_sliders` | vbSliders | vbResearch |
| --- | --- | --- |
| 1 | 1 | 1 |
| 2 | 0 | 1 |
| 3 | 1 | 0 |
| other | 0 | 0 |

**Enabling.** `CAITechMinister::Enable` (slot 52, rva `0x4AE880`), called at once: `+0x3C = 1`; the minister goes on
`CAISubscriber` channel 0x22 (`g_AISubscriberList_TechResearched`, VA `0x1B14FE0`); `countdown = AIrand % 3 + 1`, one
MT19937 draw on the game state's `+0x124` generator.

**The tick.** `CAITechMinister::DoWork` (slot 10, rva `0x4AEAD0`) runs every AI pass, hourly, since it sets its countdown
back to 1: first the **monthly re-plan** (A.2) where either array is empty or the month has turned (`+0x58 > dayOfMonth`,
-1 at construction); then, in the hour `(country_id + 3) mod 24`, **`TechMinister_Tick(minister, vbSliders,
vbResearch)`** - the minister as its most derived class and the two bytes as Lua booleans, `+0x5C` first
(`LuaPushArgs_TechMinister`, rva `0x4AF2E0`), by `pcall(L, 3, 0)`. A Lua error or a missing function is caught
(`luabind::error` -> `LUA Error:` in the log) and the day's work ends. So for a country nobody plays, **every day in its
hour the script sets the leadership shares (posting `CChangeLeadershipCommand`) and fills free research slots**.
`ProcessAI` gives no hour to a country with no provinces that is not in exile.

### A.2 The monthly re-plan feeds nothing in Their Finest Hour

**`RebuildTechModifiers`** (rva `0x4AECA0`, `this` on the stack) fills TechModifers (`+0x60`): sized to the number of
technologies plus one and zeroed; for every unit and every regiment in it, with `d` its definition, `size =
max((float)(d->completion_size / 1000.0), 1.0f)`, and for each technology T on `d->technologies` that
**`CTechnology::CanResearch(T, country, -1)`** allows, `mods[T->Index] += (T->canUpgrade ? 1.0f : 0.3f) * size` (added in
double, stored as float); then each entry over the total; and where `-0.01 < total < 0.01`, every entry **0**.
**`RebuildFolderModifiers`** (rva `0x4AEF40`, `this` in ECX) fills FolderModifers (`+0x70`), one entry a folder plus one
(the database's `+0x3C..+0x40`): the same loop with **no `CanResearch` filter**, weight `canUpgrade ? 1.0f : 0.2f` (the
record's `fAiCommitmentFactor_0_2`) at `T->Folder->Index`; a total under 0.01 sets every entry to **1.0**, not 0. All the
constants are the exe's.

**Who reads them: nothing in the exe.** A sweep of the whole of `.text` (resuming past decode stops) for a load from
`[x+0x6C]` (the `CEU3AI`'s minister) followed within 12 instructions by `+0x60/+0x64/+0x70/+0x74` finds **0**; its
positive control finds the 14 writes to `+0x5C/+0x5D`. Only the re-plan and the destructor touch the arrays. The two Lua
getters `GetTechModifers` and `GetFolderModifers` (VA `0x8E90B0`, `0x8E90C0`) have no callers and one registration each,
and no Their Finest Hour or base game script calls them - the install's grep finds them only in BlackICE's files. **So for
Their Finest Hour the re-plan can be left out**: it decides nothing, the exe keeps no queue of its own, and `CanResearch`
does not ask it.

### A.3 Slot 47: a finished level takes the technology off an AI country's queue

When `CDistributeResearch::Distribute` finishes a level of a technology with `additional_offset != 0`
(`FINDINGS-researchshare.md` section 1) it appends the technology to the end of `CurrentResearch` where
`CheckResearchAllowed(-1)` holds, and then, appended or not, calls `AISubscribers_NotifyTechnologyResearched(country,
tech@EDI)` (rva `0x4A3040`), which walks channel 0x22 and calls slot 47 of each subscriber through `VcallThunk_Slot47` (rva
`0x122410`) - only enabled tech ministers are on it. **`CAITechMinister::OnTechnologyLevelResearched`** (slot 47, rva
`0x4AE9B0`) returns unless `country->id == this->country_id`, and otherwise makes **`CStopResearchCommand(own tag,
technology)`** (`0x557E00`, checked: its `Execute` and `IsValid` are slots 6 and 14 of `CStopResearchCommand`'s table) and
posts it on the session (in-game screen slot 18 -> `+0x38` slot 6).

So **for a country with a tech minister, a technology of several levels never stays queued after a level finishes**: the
stop takes it off and the script chooses again in its hour. Where it was not appended again (its next level not allowed),
the stop fails `IsValid` as it is posted and is deleted. A player who does not delegate research has no tech minister, and
his technology stays at the end of the queue.

### A.4 The commands

**`CStartResearchCommand(tag, tech)`** - `LuaConstruct_CStartResearchCommand` (rva `0x589B10`), the constructor rva
`0x157920`. **`Execute`** (rva `0x1579C0`): `CCountry_AppendCurrentResearch` puts the technology **at the end of
`CurrentResearch`**, checking nothing - not `CanResearch`, not the slots, not a full queue - and then
`LeadershipDistribution[3]` slot 4 (`CDistributeResearch::ShareAmongProjects`) shares the projects' leadership again at
once. **The only refusal is `IsValid`** (slot 14, rva `0x157D10`): false where the technology is queued already, by
pointer; the loopback post and the session's command loop both ask it, so a second start of one technology in a day is
dropped. Nothing queued moves, and the player is told nothing. A technology whose next level is not allowed can sit in the
queue getting nothing from `Distribute`; the AI keeps clear of that only because the script asks `minister:CanResearch`
first.

**`CStopResearchCommand(tag, tech)`** (rva `0x157E00`), not made from Lua: `Execute` (rva `0x157EA0`) takes the node out,
its progress kept, then `ShareAmongProjects`; `IsValid` (rva `0x157FD0`) is true only while the technology is queued.

**`CChangeLeadershipCommand(tag, nco, diplomacy, espionage, research)`**: `LuabindInvoke_CChangeLeadershipCommand` (rva
`0x57EFA0`) hands **Lua index 3 to the constructor's first float, 4 to the second, 5 to the third, 6 to the fourth**, each
`lua_tonumber` stored as a float to the nearest; the thunk (rva `0x5896B0`) calls the float constructor (rva `0x157330`):

    x  = (arg < 0 or NaN) ? 0 : arg                       ; each of the four
    sum = (float)((double)a + b + c + d)
    q   = (float)((double)x / sum)
    share = trunc(q * 32768 + (q >= 0 ? 0.5 : -0.5))      ; 15 bits, half away from 0, as int64

nothing else normalised or clamped; a sum of 0 gives 0/0 (never from the script). **`Execute`** (rva `0x1575B0`) writes
**share i into `LeadershipDistribution[i].base_percentage`, in the order officers, diplomacy, espionage, research** - so
the script's NCO is the officers' share - running a setting's slot 4 only where its value changed (only research has a
real one), refreshing the screen for the local player only (in-game screen slot 94), and leaving each setting's `factor`
(`+0x10`) alone; `IsValid` is the shared `mov al,1`. **Measured**: England in the 20 April save holds `0.20001 0.07999
0.03000 0.69000` - 6554/2621/983/22610 over 32768, the script's (0.2, 0.08, 0.03, 0.69) through this rounding exactly;
Germany (`automate_tech_sliders=1`), the Netherlands, Sweden and Italy all fit the script's rules, NCO first.

**The player's sliders differ** (`CTechnologyView::SendDistribution`, rva `0x41D150`): nothing is sent while
`automate_tech_sliders` is 1 or 3; otherwise each knob's position over the view's `+0xCC` is rounded half away from 0 to
15 bits, the running total capped at `0x320000`, and `CChangeLeadershipCommand_FromSliders` (rva `0x157000`) normalises
again as **`(v << 15) / sum`, truncated** - so the player's four can sum a little under 32768, where the AI's come from
fractions summing to 1, rounded.

### A.5 `math.random`

The install's `lua5.1.dll` (the original is `lua5.1.dll.preBlackICE`) imports `rand` and `srand` from **MSVCR80.dll**;
the exe links its own CRT statically and imports no `rand`, so nothing the exe does touches Lua's generator.
`math_random` (DLL VA `0x100198A0`) is stock 5.1.4: `r = (rand() % 32767) / 32767.0`, and `math.random(m) = floor(r*m) +
1`. MSVCR80's `rand` (8.0.50727.9680) is `ptd->_holdrand = _holdrand*214013 + 2531011; return (_holdrand >> 16) &
0x7FFF`, its ptd in per-thread storage with `_initptd` setting `_holdrand = 1`. **Each OS thread has a sequence of its
own, from seed 1, never seeded again**: the only `srand` caller is `math.randomseed`, which no script calls, and no other
DLL of the install imports MSVCR80's `srand` (control: the same import check finds `lua5.1.dll`'s). Each thread has its own
Lua state too (`GetThreadLuaState`), and which TBB worker - or the main thread joining the `parallel_for` - runs which
country is TBB's scheduling, **so the draws a country gets are not the same from run to run**, and a reimplementation must
choose a seeding of its own.

### A.6 What each engine method the script reaches answers

| method | answers |
| --- | --- |
| `minister:GetOwnerAI()` | `+0x54`, the `CEU3AI` |
| `minister:GetCountryTag()` | `+0x34/+0x38`, a copy |
| `minister:CanResearch(tech)` (rva `0x4AF190`) | **true where** `tech` is a real technology (slot 9: `notech` false), `CTechnology::CanResearch(tech, country, -1)` holds, and `tech` **is not on the country's queue already**. No slots, no year |
| `CTechnology:CanResearch(tag, L)` (rva `0x135760`) | the level is real (a single-level technology only L 0 or 1), `<= max_level`, (custom game only) its figure, and the `allow` block holds for the country |
| `CTechnologyStatus:CanResearch(tech, L)` (rva `0x133950`) | the level arithmetic alone; no `allow`, no queue. Their Finest Hour does not use it |
| `CCountry:GetNumberOfCurrentResearch()` | `+0x640`, the queue's count |
| `CCountry:GetCurrentResearch()` | the queue (`+0x638`), head first - the order it is funded in |
| `CCountry:GetAllowedResearchSlots()` | recorded `confirmed` (`FINDINGS-leadership.md` section 6): research share x factor x TotalLeadership, rounded half to even. Asked only where vbSliders is false |
| `CCountry:GetTotalLeadership()` | `+0xBD8`, thousandths; `:Get()` a float |
| `CCountry:GetOfficerRatio()` | `+0xD4`, thousandths |
| `CCountry:GetDiplomaticInfluence()` | `+0xA88`, or 100.000 while `g_UnlimitedDiploInfluence` is set |
| `CCountry:CalculateNumberOfActiveInfluences()` (rva `0xFBEA0`) | how many countries this one is influencing now (`o->diplomacy[this]->influence_running`) |
| `CCountry:GetNumOfPorts()` | `+0x105C`: owned provinces with a real owner, a port on the map and a naval base built (`level_max > 0`), **in the acting capital's area only** |
| `CCountry:GetNumOfAirfields()` | `+0xD78`: the count of the air bases list - controlled provinces whose air base's `level_max > 0` |
| `CCountry:GetTechnologyStatus()` | `+0xDF8` |
| `CCountry:GetTotalIC()` / `IsMajor()` / `IsAtWar()` / `HasFaction()` | as `FINDINGS-luaapi.md` |
| `CTechnologyDataBase.GetTechnologies()` | the database's vector, in the order below |
| `CTechnologyDataBase.GetTechnology(name)` (rva `0x4EA1D0`) | exact, case-sensitive hash lookup; **an unknown name is nil** |
| `CTechnologyDataBase.GetLatestTechYear()` (rva `0x4EA290`) | `max(end_date's year, every technology's year due at its max_level)` (`+0x38`), set once at load |
| `tech:GetFolder()` / `tech:GetKey()` / `folder:GetKey()` | `+0x290`; the key `+0x20C`; the folder's key `+0x8` |
| `tech:IsValid()` | slot 9: true; `notech` false |
| `status:GetLevel(tech)` (rva `0x133130`) | `level_by_technology[Index]`, whole |
| `status:GetYear(tech, L)` (rva `0x133380`) | `start_year` where L <= 1; `first_offset` where L = 2; else `first_offset + (L-2) x additional_offset` - whole years, the country not asked |
| `status:IsBuildingAvailable(b)` (rva `0x133110`) | `building_available[b->index]`; a nil building is dereferenced |
| `status:IsUnitAvailable(d)` | recorded |
| `CBuildingDataBase.GetBuilding(name)` | section D.1; `industry`, `naval_base`, `air_base`, `infra` all exist in Their Finest Hour |
| `ai:Post(cmd)` | recorded (`FINDINGS-government.md` E.4) |

**`GetTechnologies`' order**: `notech` first, then each file of `technologies/` in the **byte order of its name**
(`PHYSFS_enumerateFiles`' sorted insertion), each in file order - **measured**: the start save's technology block is in
this order, 288 of 288. It matters, because `ResearchTech` picks with `math.random(n)` over arrays built in this order.

### A.7 What looks wrong and is what the bytes do

- The monthly re-plan makes two arrays nothing in Their Finest Hour reads; the technologies' goes to 0 where its total is
  tiny, the folders' to 1.0.
- `CStartResearchCommand` asks nothing but "queued already": the queue may run past the slots, and a technology not
  allowed may sit in it.
- An AI country loses every technology of several levels from its queue the moment a level finishes.
- The AI's leadership shares are rounded half away from 0; the player's truncated after a division.
- `GetNumOfPorts` counts the ports in the acting capital's area only, so a country whose ports are elsewhere is "not
  naval" to the script.
- `math.random` is a thread's, seeded 1, and its draws hang on TBB's assignment of threads.
- *The script's, not the exe's*: `Process_Tech` sets a **global** `lbInfra = true` in the thread's Lua state, which then
  holds for every later country run on that thread and changes whether the `IndustrialTechs` prefer list is wiped - which
  countries see it is the threads' scheduling.

### A.8 Not settled

- Whether a `CStopResearchCommand` posted in the daily pass runs before or after that hour's AI pass - if after, the
  minister sees the technology still queued and passes it over that day.
- Whether the TBB workers inherit the 24-bit x87 control word; it bears only on rare edges of `floor(r*m)`.
- The view's `+0xCC` in `SendDistribution`.
- Which of `CDirectorySettings +0x1B4`/`+0x358` is the base game's (no matter for Their Finest Hour, every name being in
  both); the loader's writes of the database's `+0x3C` (recorded as inferred from its use).
- Measured and not explained: the research counts in the April save (England 26, Germany 29) were not set against
  `ceil(TL x share)`, the total leadership not being in the save.
- Frontier (rvas): `0x44AFB0` (`CArray<float>` resize), `0x49C7C0` (`CAIAgent`'s destructor), `0x4CCDA0` (the other caller
  of `CCountry_AppendCurrentResearch`, the save loader likely), `0x423400`, `0x406700`, `0x5826F0` (luabind's invoke for
  `CStartResearchCommand`), `0x4836B0` (PhysFS's insertion search).

## B. The production minister

Oracles: `Germany1936_01_01_00.hoi3` and `Germany1936_04_20_03.hoi3`.

**In one line.** Each AI country's production minister fills three count arrays once a day, makes its country's
desperation again on the 1st, the 15th and the 29th, and calls `ProductionMinister_Tick` **every day**; separately, the
end of every country's daily pass calls `BalanceProductionSliders` with the share each slider needs as a fraction of all
the IC and a priority level - 0 for the AI, or the player's own 1 to 3. `CAI.FastNormalizeByPriority` serves the shares
in a hardcoded order, each 0.00005 more than asked while room is left, and the `CChangeInvestmentCommand` the script
posts normalises the six as it is made, **rounding half away from 0** where the player's own sliders truncate. An AI
country's finished units are placed by `CEU3AI::DeployFinishedUnits` once a day: a lone brigade, ship or wing joins a
fitting unit in the capital's area, anything else goes to that area's best province.

**Four corrections.** (1) `ProductionMinister_Tick` runs every day; `FINDINGS-ai.md` and the record had it on the 1st and
the 15th - the gate is the desperation's alone, and passes on the 29th too, the day of the month counting from 0. (2) The
save's `automate_sliders`, `automate_tech_sliders` and `automate_trade` are not delegation flags 0 to 2 (`FINDINGS-ai.md`
had that as inference): they are fields of their own of the local player's record (`+0x2C`, `+0x30`, `+0x34`), and the
flags are the save's `ai = { ... }` - **seven** of them, not five, flag 6 automatic deployment. (3) Only one of the four
sites of `LuaProxy_BalanceProductionSliders` is the AI's: rva `0xDC203` is the player's own automation, and VA
`0x805BAA`/`0x805FBB` are the production screen's `slider_arrow_left`/`slider_arrow_right`. (4) The AI's daily call has
an invoke half of its own (rva `0x10D470`); the recorded `_Call` serves the other three.

### B.1 The minister's day: `CAIProductionMinister::DoWork` (`0x8A22E0`, rva `0x4A22E0`)

`FINDINGS-ai.md`'s schedule stands: slot 10, once a game day, at the hour `(country id + 5) mod 24`. **Its first work**
comes one to three AI passes after it is made: its Enable, slot 52, is one body with the foreign minister's
(`CAIForeignMinister::Enable`, `0x89D360`, rva `0x49D360` - read by the collecting session) - `+0x3C = 1`, a node on
each of seven `CAISubscriber` channels at `0x1B14F00`..`0x1B14F88`, and `countdown = MT19937Next(&gamestate->+0x124) % 3
+ 1` (`0x89D5D3`-`0x89D5EA`), the draw the tech and politics ministers make. The day of the month is worked from the tick
and **counts from 0**, so the 1st is day 0. In order:

1. **`CEU3AI::UpdateSubUnitCounts(OwnerAI)`** (`0x899770`, rva `0x499770`; section C.2). Its only caller is this, so
   the counts the script reads are always the day's.
2. **The desperation** (`+0x5C`), made again only where `+0x5C < 0` or `dayOfMonth % 14 == 0` - the 1st, the 15th and
   the 29th: `+0x5C = (float)((double)(float)CCountry::CalcDesperation(country) / 1000.0)`. It is negative only before
   the first time: the inlined constructor writes -1.0f, and `CalcDesperation` never answers below 0.
3. **`ProductionMinister_Tick(minister)`, every day** - the `jne` at `0x8A2452` skips step 2 alone. A `luabind::error`
   is caught (`0x8A24B9` -> `ReportLuaError`) and the day's tick ends.

**`CCountry::CalcDesperation`** (`0x4EE560`, rva `0xEE560`), in thousandths:

    if not at_war (+0xACC): return 0
    total = controlled = 0
    for id in CoreProvinces (+0xD10):
        p = province id
        skip unless p's area is real, p->owner == this,
             and p's area is the acting capital's area or touches it (+0x34 links)
        w = GetProvinceWeight(p)
        total += w;  if p->controller == this: controlled += w
    total = max(total, 1)
    d = 1000 - controlled*1000*1000 / (total*1000)            ; integer, toward 0
    if CapitalLocation(this)->controller != this: d += 100    ; the real capital (+0xE20)
    return d                                                  ; 0 .. 1100

**`GetProvinceWeight`** (`0x4A6500`, rva `0xA6500`; the province in ESI):

    if p->owner_id == 0: return 1
    w = p->manpower / 1000 + 1
    if p is in its owner's acting-capital area or on its continent: w += FORT_LEVEL / 1000
    else: w = w / 5
    return max(w, 1)

The scripts read desperation through `CCountry:CalcDesperation():Get() > 0.4` (`ai_foreign_minister.lua`,
`country/GER.lua`, `ENG.lua`, `JAP.lua`); the engine reads the minister's cached copy only in `PrioritizeBuildQueue`
(B.5). `minister:GetDesperation()` (`0x8A2250`) answers `+0x5C`; no Their Finest Hour script calls it.

### B.2 The daily `BalanceProductionSliders` (the block at rva `0xDBEA8`)

The last block of `RunCountryDailyPass`, after that day's shares were distributed (rva `0xDB4F3`), so a command it posts
counts from the next day. It runs for every country that is not `REB`, owns a province (`+0xCF8 > 0`), has a `CEU3AI`
(`+0x1D8`), in an ordinary game (state `+0xD0C` clear) - **the two days a new game runs before its first hour
included**: the 1 January save already shows the script's shares (England's 0.00006 for lend-lease and reinforcement).
With `h = GetLocalPlayer()`:

| branch | when | level | lendLease | invoke |
| --- | --- | --- | --- | --- |
| **AI** | `h->country` is another country, or it is this one and `h->automation[1] == 1` (production delegated) | 0 | the lend-lease setting's need over TotalIC - **always 0**, its slot 3 being the shared stub that writes 0 | `_CallAi` (`0x50D470`), then `BalanceLendLeaseSliders` where the country gives lend-lease to anyone (`+0x6B8` not empty) |
| **player** | his own country, not delegated, `h->automate_sliders > 0` | 1, 2 or 3 | **his current lend-lease share** (`base_percentage x 2^-15`, at least 0) | `_Call` (`0x50D570`) |

The player's own country at level 0 gets no call. In both branches `consumer`, `production`, `supply`, `reinforce` and
`upgrade` are `max(0, (float)(GetNeeded x 2^-15) / (float)TotalIC)` - each share's need (slot 3, a 48.15 number in whole
IC) over the country's whole IC, in single precision - and `hasReinforceBonus` is `1000 +
modifier[MODIFIER_REINFORCEMENT_BONUS (86)] > 1000`. The script is handed `(ai, country, level, ll, consumer,
production, supply, reinforce, upgrade, bool)`: the AI as its most derived class, the level a Lua integer, the rest
numbers; `LuaProxy_BalanceProductionSliders` (rva `0x110160`) builds the call. A Lua error is caught (funclets
`0x4DC23C`/`0x4DC3E8`: `ReportLuaError`) and **the rest of that country's pass is skipped**, `BalanceLendLeaseSliders`
with it.

**The level** (`SLIDER_AUTOMATION_LEVEL`) is `CHuman +0x2C`, saved as `automate_sliders`: 0 `AUTOMATE_MANUAL` "Manual
Control", 1 `AUTOMATE_PRODUCTION` "Prioritize Production", 2 `AUTOMATE_UPGRADES` "Prioritize Upgrades", 3
`AUTOMATE_REINFORCEMENT` "Prioritize Reinforcement" (`GetSliderAutomationText`, `0x8053C0`). Level 4 is the script's own,
which turns 0 or 3 into 4 when `bHasReinforceBonus` is set. **The production screen's two arrows**:
`slider_arrow_left` (`CProductionView::CycleSliderAutomationUp`, `0x8057F0`) steps up, 0 after 3; `slider_arrow_right`
(`...Down`, `0x805C00`) steps down, 3 after 0; each stores the level and, unless it is 0, calls `BalanceProductionSliders`
at once with the player's arguments, then the view is refreshed (`0x806010`) and `view +0x320 = 2`.

**The player's record, `CHuman`**, which `CGameState::GetLocalPlayer` answers: `+0x20` the country played; `+0x2C`
`automate_sliders`; `+0x30` `automate_tech_sliders`; `+0x34` `automate_trade`; `+0x38` seven 0/1 flags indexed by
`CHuman::AUTOMATIONTYPE`, saved as `ai = { ... }` - 0 foreign, 1 production, 2 technology, 3 politics, 4 intelligence, 6
automatic deployment, 5 not read. `CGameState::LoadKey` fills them all, gated by state `+0xCF4`. The 20 April save has
`ai={ 0 0 1 0 0 7 0 }`, `automate_sliders=3`, `automate_tech_sliders=1`.

### B.3 `CAI.FastNormalizeByPriority` (`0x8E9250`, rva `0x4E9250`)

    s[0..5] = lendLease, consumer, production, supply, reinforce, upgrade      ; floats
    order   = g_SliderPrioritySettings[level]      ; 0x15EC688, 6 ints a row, no bounds check
    i = order[0]
    v = (float)((double)s[i] + 0.00005)            ; the double of (float)0.00005
    if !(1.0f > v): v = 1.0f                       ; NaN -> 1.0
    left = (float)(1.0 - (double)v);  if !(left > 0): left = 0
    s[i] = v
    for k in 1..5:
        i = order[k]
        v = (float)((double)s[i] + 0.00005)
        if !((double)left > (double)v): v = left   ; min(v, left)
        left = (float)((double)left - (double)v);  if !(left > 0): left = 0
        s[i] = v
    return to Lua: s[0], s[1], s[2], s[3], s[4], s[5], max(left, 0)   ; factor_left
    (and the C return value 7.0f, which luabind pushes as an eighth result - inferred from its source)

All of it SSE single and double precision, so the x87's state does not reach it. The table - the script's "PRIO_SETTING"
- is in `.rdata`, and no define reaches it (dumped from the image). **But it binds only a script that calls the
helper**: `BalanceProductionSliders` is Lua, and its own comment says a mod wanting another order "cant use this function
and [has] to roll the commented out code above" - the base game's `script/ai_production_minister.lua` still carries that
loop, commented out, over a `PRIO_SETTINGS` table of its own. Their Finest Hour's script and BlackICE's both call the
helper. So the order is mod-able by rewriting the script; what the engine fixes is when the call is made and what it is
handed (B.2).

    level 0 (AI)              consumer, lend-lease, supply, reinforce, production, upgrade
    level 1 Production        lend-lease, consumer, supply, production, reinforce, upgrade
    level 2 Upgrades          lend-lease, consumer, supply, upgrade, reinforce, production
    level 3 Reinforcement     lend-lease, consumer, supply, reinforce, production, upgrade
    level 4 (bonus)           lend-lease, reinforce, consumer, supply, production, upgrade

### B.4 `CChangeInvestmentCommand`, and the player's sliders beside it

**The Lua constructor** `CChangeInvestmentCommand(tag, ll, consumer, production, supply, reinforce, upgrade)` reaches
the body at `0x5569B0` (rva `0x1569B0`) through luabind's wrapper `0x989590`, which passes the six floats first and the tag
last. It normalises as it is made:

    x[i]     = arg[i] > 0 ? arg[i] : 0
    sum      = (float)(((((x0 + x1) + x2) + x3) + x4) + x5)          ; added up in double
    share[i] = (__int64)((float)(x[i] / sum) * 32768.0 + (f < 0 ? -0.5 : 0.5))   ; x87, _ftol2

so each share is rounded half away from 0, in 48.15, and the six need not sum to exactly 32768; a sum of 0 gives 0/0 and
`_ftol2`'s integer indefinite. **The 20 April save bears out the rounding**: Sweden's `0.00006 0.00006 0.35846 0.27975
0.00320 0.35846` is 2 + 2 + 11746 + 9167 + 105 + 11746 = 32768, in 32768ths, and
an empty share given 0.00005 comes out at 2 (1.64 rounded), where truncating would give 1.

**`Execute`** (`0x556D20`, slot 6) writes each share into `ProductionDistribution[i]->base_percentage` as it stands,
calling the setting's slot 4 where the value changed (empty for every IC setting) - no clamp, no normalising again, no
cost, no message. Slot 14 is `ReturnTrue`, so nothing refuses it. `CEU3AI::Post` clones it (slot 13) onto the channel, so
it runs when the queue drains.

**The player's sliders** (`CProductionView::SendDistribution`, `0x7FFA90`) differ in three ways: **nothing is sent while
production is delegated** (`automation[1] == 1`); the fractions come from the sliders' **IC amounts**, each
`actual_slider` value over `(float)TotalIC`, rounded half away from 0 to 15 bits (with a running total capped at 100.0,
which six fractions never reach); and the `_shares` constructor (`0x556760`) **truncates**: negatives zeroed,
`(s << 15) / sum` in 64 bits toward 0, so the player's six sum to 32768 or a little under, where the Lua's are rounded from
float fractions.

### B.5 `CAIProductionMinister:PrioritizeBuildQueue()` (`0x8A2720`, rva `0x4A2720`)

The script calls it at the end of `ProductionMinister_Tick` where `math.mod(GetAIRand(), 7) == 0` - not when the tick
returned early for `icAvailable < 0.1`.

    for line in country->Constructions (+0xF40), head to tail:
        if line->status (+0x3C) >= 980: continue          ; (int)floor(980.5f)
        if line is a convoy (slot 15):
            if line->escort (+0x58): continue
            if country->Transports * 2 < country->TotalNeededTransports:
                post CChangePriorityCommand(tag, line->id, -2)
        elif minister->Desperation > 0.6f and line is military (slot 17)
             and line->Brigades.first->Type->is_land:
            days = status == 0 ? -1 : (duration - progress) * 1000 / status   ; integer, toward 0
            if days / 1000 < 120:
                post CChangePriorityCommand(tag, line->id, -2)

A move of -2 is "unlink and push on the front" (`CChangePriorityCommand::CChangePriorityCommand`, rva `0x148940`, `(this,
tag, id, line type, line id, direction)`). The commands go to the session and run later in the order posted, so lines
moved in one call end at the front **in reverse order** (that the session runs them in posting order is inferred).
Building lines are never touched.

**`CountTransportsUnderConstruction` / `CountEscortsUnderConstruction`** (`0x8A24D0` / `0x8A25E0`) count **ships**, not
lines: over the convoy lines with the escort flag clear (or set), `CONVOY_CONSTRUCTION_SIZE / 1000 x Size` - ten ships an
item in Their Finest Hour, Size what is left of a serial run. `CountTotalDesiredEscorts` (`0x8A26F0`) sums each convoy's
`+0x94`; no Their Finest Hour script calls it.

### B.6 An AI country's finished unit

A finished unit waits in the country's deployments (`+0x688`; `FINDINGS-buildqueue.md` section 4). **Every waiting unit
draws its supplies and fuel each day** (`RunCountryDailyPass`, rva `0xDB29D` -> `CUnit::ConsumeSuppliesAndFuel`), every
country's.

**`CEU3AI::DeployFinishedUnits`** (`0x88B300`, rva `0x48B300`) places them. `ProcessAI` calls it on a worker: **once a day
at the hour `(id + 8) mod 24`** for every country whose units the AI runs, and **every hour** for the played country while
`automation[6] == 1` (automatic deployment). It walks the deployments in order, units' only.

**A deployment of exactly one brigade, ship or wing first tries to join a unit**, among the country's own units with no
expeditionary owner:

- **air**: a wing joins an air unit; a carrier air group only a unit based on a carrier with room; any other wing never
  joins a carrier's unit or an air group;
- **ships**: a ship joins a fleet, but a warship never joins a transport fleet, and a submarine only an all-submarine
  fleet;
- **land**: a brigade joins a land unit whose `army_role` takes the brigade's role (`SubUnitDefinition_GetRole`, rva
  `0x1A8540`: 0 HQ, 1 support, 2 infantry, 3 armour, 4 fast, 5 garrison, 6 mountain, 7 marine, 8 para): role 0 takes
  nothing; 1, 2 and above 8 anything (factor 1); 3 takes role 3 at x0.5 and role 4 at x3; 4 takes role 4 at x0.5 and role
  3 at x3; 5 to 8 only their own role;
- **size**, counting what this pass has sent already: a land unit takes one only while it holds at most 3, at most one
  narrow brigade (width below 1), and with 3 wide brigades only one of no width; an air unit only while it holds at most 2
  wings, an air group excepted.

The score is `brigades x 10 x factor - plan_subunit_difference[type]` (`CUnit +0x5C`); **the lowest under 100000 wins, the
first of equals**, and only where `CanDeployIn` holds on that unit's province - in practice **units in the acting capital's
area**. It posts `CDeployUnitCommand(province, deployment, target unit)`.

**Otherwise, and for anything larger**, it goes to a province of the acting capital's area: score `LOCAL_IC/1000 +
2 x trunc(FORT/1000) + 2 x trunc(COASTAL_FORT/1000)`, +10 for the acting capital itself; **the strictly highest wins**,
from -1; `CanDeployIn` must hold, so a fleet needs a naval base and an air unit an air base; placed there with no target.
For the played country only it also posts a `CAttachUnitCommand` to the headquarters of that province's theatre. An air
group goes instead to the province of the first fleet with a carrier that has no group aboard. A unit nothing suits stays
waiting and is tried again the next day; building deployments are left alone. Finished buildings and convoys are delivered
by the queue alike for every country (`CConvoyConstruction::Deliver`).

### B.7 What looks wrong and is what the bytes do

- `ProductionMinister_Tick` runs every day; the desperation is made again on the 29th as well as the 1st and the 15th.
- The AI's lend-lease argument is always 0, the lend-lease setting's need being the shared nought stub; so where the
  country gives lend-lease, the script always sets that share again to its "preferred" figure.
- `FastNormalizeByPriority` gives every share 0.00005 more while room is left, which is why empty shares read 0.00006 in
  saves. Under the player's own automation his lend-lease share is handed back in each day, so by the arithmetic it creeps
  up about 2/32768 a day - Germany's 0.00360 on 20 April fits, which is not a check.
- The Lua's normalising rounds; the player's truncates.
- A TotalIC of 0 sends inf or NaN to the script.
- `PrioritizeBuildQueue` leaves the lines it moves in one call at the front in reverse order, and a land line getting
  nothing (status 0) counts as "under 120 days" and jumps to the front when the country is desperate.
- `slider_arrow_left` steps the level up and `slider_arrow_right` down.
- The desperation's +0.1 asks of the real capital, while its provinces are the acting capital's.
- The AI joins brigades only to units standing in the capital's area; units elsewhere never get replacements this way.
- The 100.0 cap in `SendDistribution` can never bind.

### B.8 Not settled

- That the `auto_deployment_checkbox` sets `automation[6]` (its handler not read); what reads `automation[5]` and
  `CHuman +0x48` (the save's 7).
- In multiplayer, whether another person's country gets the AI's shares: the daily pass treats every country but the local
  player's as the AI's; the command channel was not read.
- That `RunCountryDailyPass` runs on the main thread, so that the constructor's x87 step and the script's own arithmetic
  run at 24 bits (`FINDINGS-luahost.md` section 6) - inferred.
- That the session runs posted commands in posting order (the reverse order rests on it); luabind's wrapper's stack
  mapping (the saves show the order works); "the base's slot 1 means a carrier" in the join rule; the eighth result.
- Not read: `0x890DB0`, called before the AI's deploying, and `0x4B09D0`, the theatre's headquarters for the player's
  attach.
- Frontier (rvas): `0x490DB0`, `0xB09D0`, `0x1DE890` (`CAttachUnitCommand`'s constructor), `0x406010`, `0x4056F0`,
  `0x4A2B40`, `0x28A6B0` (the automation flags' setter), `0x4ACE20` (the AI strategy's use of desperation),
  `0x589590`/`0x57EC60`, `0x474A30`.

## C. Units and constructions, as the production script reads them

What `ai_production_minister.lua` (`ProductionMinister_Tick`, `ConstructConvoys`, `GetEliteUnitBuildCount`) and
`ai_support_functions.lua` (`Support.CreateUnit`) get from each engine method they call, and what the one command they
post does. The arguments were set beside the maintainer's `Germany1936_04_20_03.hoi3`: 89 military lines, 71 of them
posted by commands (id type 4713) - every AI line in its own queue, of size 1 to 4, built by itself, with no target and
no location.

### C.1 When the script's figures are made

`CAIProductionMinister::DoWork` (`0x8A22E0`, rva `0x4A22E0`) acts once a game day, in the hour `(id + 5) mod 24`
(`FINDINGS-ai.md`), and each time does three things in order: it calls **`CEU3AI::UpdateSubUnitCounts`** (`0x899770`,
rva `0x499770`); where the cached desperation is negative or the day count is a multiple of 14, it makes that cache
again; and **every time** it calls `ProductionMinister_Tick` (`0x8A2483`-`0x8A249B`). **`FINDINGS-ai.md` and the record
had the whole block behind the 14-day gate; only the cache is** - checked on the listing: the `jne 0x8A2483` at
`0x8A2452` skips the cache and lands on the Lua call. So the counts by type are at most a day old when the script reads
them, and nothing the script posts in its tick moves them until the next day; everything else it reads, it reads live.
Section B.1 has the same from the other side.

### C.2 The counts by unit type

`CAI:GetDeployedSubUnitCounts` (`0x8E8180`) and `CAI:GetProductionSubUnitCounts` (`0x8E8190`) answer the `CArray<int>`s
at `CEU3AI +0xE8` and `+0xF8`, one entry a unit type, indexed by `CSubUnitDefinition::type_index`, sized and zeroed by the
AI's constructor (`0x888020`). **Only `UpdateSubUnitCounts` writes them** (a displacement scan, its positive control the
two getters and the constructor):

    zero deployed[], production[], theatre[]          (one entry a type)
    for each line of country.Constructions (+0xF40), in queue order:
        if line.IsMilitary (slot 17):
            for each brigade definition of the line (+0x7C):
                production[definition.Type.type_index] += line.Size (+0x40)
    for each deployment of country.deployments (+0x688):
        if it is a unit's (slot 8 == 0x4B4; a building's answers 0x4B7):
            for each brigade of the waiting unit:   deployed[brigade.type] += 1
    for each unit of country.units (+0xBAC):
        for each brigade of the unit (+0x38):      deployed[brigade.type] += 1
    for each unit agent (+0x40) with a unit (slot 74):
        theatre[i] += unit.plan_subunit_group_difference[i], held at 0 or more after each add
        (transport_ship left out where every area of the country is landlocked)
    hasFilledProdQueue (+0xAA) = 1

- **Brigades, not units**: a division of four adds four, each at its brigade's type.
- **Production is what is still to come**: a queued line counts every brigade it lists times its Size, the units of its
  series not yet delivered - `{infantry, infantry, anti_tank, artillery}` of Size 4 adds 8, 4 and 4. Lines side by side
  each count.
- **Deployed is every brigade the country has**: every unit of `CCountry +0xBAC`, every level, headquarters among them,
  and every finished unit waiting to be placed. Nothing asks where a unit is or what it does - in a battle, at sea, aboard
  alike. Units lent out as expeditionary forces sit in `+0xBBC` and are not counted; units received are in `+0xBAC` and
  are.
- **The theatre counts** (`GetTheatreSubUnitNeedCounts`, `+0x108`) are made here too; Their Finest Hour's script has
  that read commented out.

As Lua has them, `CArrayInt:GetAt(i)` (`0x8F1330`, shared with the `CFixedPoint` and `float` arrays) is `data[i]`, **from
0, unchecked**; `GetSize` (`0x421320`, shared) is `(end - begin) / 4`; `SetAt` (`0x8F12F0`) stores `data[i]`, unchecked.
The script always indexes by `GetIndex()`, so it stays in range.

### C.3 Unit types

- **`CSubUnitDataBase.GetSubUnitList()`** (`0x8E9D60`, recorded): the database's array (`+0x1C`) in `type_index` order,
  walked so by the iterator.
- **`GetSubUnit(name)`** (`0x8E9E40`, recorded): the name looked up in the database's string hash; **an unknown name is
  nil** - Their Finest Hour's support groups name types a mod may lack.
- **`GetIndex()`** (`0xA832A0`, the folded `GetDword_0x24`): `type_index`. **`GetKey()`** (`0x531190`): the type's block
  name in `units/*.txt`.
- **`IsRegiment()`** (`0x462D10`, rva `0x62D10`): `+0x2D`, which the loader sets for **`type = land`** - the other two
  values set `+0x2C` (`air`) and `+0x2E` (`naval`), at `0x5A3DAE`/`0x5A3DF6`/`0x5A3DD0`. So every land type is a
  "regiment" to the script, headquarters and militia among them.
- **`IsCag()`** (`0x4C8350`): `+0x32`, set by `is_cag = yes`; in Their Finest Hour only `cag`.
- **`CSubUnitDefinition:GetBuildCostMP()`** (`0x417A20`): the file's `build_cost_manpower` (`+0xFC`), none of the
  country's terms. What an order takes is `CCountry::GetBuildCostManpower` (`0x4E1880`, recorded):
  `build_cost_manpower x max(50, 1000 + technology's by-type term + RESERVES_PENALTY_SIZE if reserve) / 1000`.
- **`CCountry:GetBuildCostIC(type, 1, reserve)`** (`0x4E18F0`, recorded): its middle argument is the
  **`technologyBonus`**, the sum of the model's levels at one per cent a point, not a count - so the script's `1` makes
  its estimate one per cent dearer than the base, where a real line is priced at its model's levels (`FINDINGS-buildqueue.md`
  section 2).

### C.4 The queue as the script reads it

- **`CCountry:GetConstructions()`** (`0x4F56B0`): the list at `+0xF40` in **queue order** - the order the day's pay walks,
  which is the order of appending as `CChangePriorityCommand` has moved it; military, building and convoy lines alike.
- **`CConstruction:IsMilitary()`**: through `VirtualThunkSlot17` (`0x8A3120`); slot 17 is `ReturnTrue` in
  `CMilitaryConstruction`'s table and `ReturnFalse` in the building's and the convoy's. **`GetMilitary()`**: through
  `VirtualThunkSlot18` (`0x8A3150`), `ReturnThis` for a military line and `ReturnZero` - nil - for the others.
- **`CConstruction:GetCost()`** (`0x4837C0`, rva `0x837C0`): `cost` (`+0x30`), **one unit of the line's IC a day** - for a
  unit of several brigades, its summed IC-days over its slowest brigade's days. **Not times the series' Size**, and priced
  again only at the six moments `FINDINGS-buildqueue.md` section 2 lists. The save's AI divisions of Size 4 cost 2.6 to 16
  a day: one division's.
- **`GetSize()`** (`0x483E00`): `Size` (`+0x40`), the units of the series still to deliver.
- **`CMilitaryConstruction:IsLand / IsAir / IsNaval`** (`0x484840 / 0x484860 / 0x484880`): **the first brigade's type's**
  `+0x2D` / `+0x2C` / `+0x2E`; all false for a line of no brigades. A line is classed by its first brigade alone.
- **`GetBrigades()`** (`0x417D50`): the definitions at `+0x7C` in order; **`CBrigadeConstructionDefinition:GetType()`**
  (`0xB12990`): `+0x34`.

### C.5 The country's figures

- **`GetICPart(category)`** (`0x503D10`, rva `0x103D10`): of `ProductionDistribution[category]` (`+0x5F4`, unchecked),
  `TotalIC x base_percentage x factor` in the 48.15 kind, answered in thousandths, each shift flooring; `TotalIC`
  (`+0x604`) is **whole IC**. So it is the slider times all the IC - not what the share was paid, nor its need.
  `CDistributionSetting`'s constants: `_PRODUCTION_LENDLEASE_` 0, `_CONSUMER_` 1, `_PRODUCTION_` 2, `_SUPPLY_` 3,
  `_REINFORCEMENT_` 4, `_UPGRADE_` 5, `_numof_` 6; `_LEADERSHIP_NCO_` 0, `_DIPLOMACY_` 1, `_ESPIONAGE_` 2, `_RESEARCH_` 3,
  `_numof_` 4.
- **`GetUsedIC()`** (`0x4F4B60`, rva `0xF4B60`): **`cost` summed over every line of the queue**, buildings and convoys
  among them, paid or not. So the script's `icAvailable = GetICPart(production) - GetUsedIC()` is the production share less
  what the whole queue asks a day - the difference the production screen's traffic light shows.
- **`HasExtraManpowerLeft()`** (`0x8E81E0`, rva `0x4E81E0`): `CCountry +0x158 > 0`, which
  `CCountry::UpdateManpowerAfterMobilising` (`0x4DCD70`, rva `0xDCD70`) writes **every day in `RunCountryDailyPass`
  (`0x4DBEA3`)**, after every unit order, by the upgrade command and as a game starts - thousandths, every step truncating:

        spare  = manpower (+0xBCC)
        spare += max_manpower (+0xBD0) * 1000 / (1000 + GLOBAL_MANPOWER + manpower_gain)
                 * 1000 / MAX_MANPOWER * 1000 / 2000              ; half a year's, before its multipliers
        for each unit with reinforcement on (+0xA6), each brigade:
            spare -= ((max_strength - strength) * 1000 / max_strength + 250) * build_cost_manpower / 1000
        for each reserve line in the queue, each brigade once:
            spare -= (1000 + RESERVES_PENALTY_SIZE) * build_cost_manpower / 1000   ; its built strength's men

  `250` is a hardcoded `floor(250.5f)` (global `0x1A87470`): **every brigade on the map costs a quarter of its build
  manpower on top of what it lacks**. *Mod-able*: `MAX_MANPOWER` (the define, 10 in Their Finest Hour); `GLOBAL_MANPOWER`,
  `manpower_gain` and `RESERVES_PENALTY_SIZE` are modifiers and technology. The record's name for `+0x158`,
  `starting_manpower`, is kept because BiceLib's header uses it; it is the spare manpower.
- **`CountMaxUnitsStillBuildable(type)`** (`0x4E13A0`, rva `0xE13A0`, now `confirmed`): 0 where the type is not
  available to the country, not `usable_by` it, or its `available_trigger` fails; **1,000,000** where `minimum_of_type` and
  `max_percentage_of_type` are both 0 or less (`0x4E144C`) - every type without them; in Their Finest Hour only the five
  elite brigades have them, at 6 and 0.04; otherwise `max(minimum_of_type - have, all x max_percentage_of_type / 1000 -
  have)`, never below 0 (`0x4E15BD`-`0x4E15D2`). `all` is the country's brigades **on the map** whose type falls in this
  one's **group**; `have` is this type's brigades on the map, plus Size for each brigade of this type in each military line,
  plus those in units waiting to be placed - **the queue and the waiting add to `have` and not to `all`**.
  `minimum_of_type` is a plain count and `max_percentage_of_type` thousandths, both in the units files (mod-able). The
  group is **`SubUnitTypeGroup`** (`0x5ADF70`, rva `0x1ADF70`), hardcoded: a ship goes to the carrier if `carrier_size > 0`,
  the heavy cruiser stays itself, capital ships go to the battleship, transports and submarines stay themselves, the rest to
  the destroyer; aircraft, land types with no `combat_width`, `hq_brigade`, paradroppers, `bergsjaeger_brigade` and
  `marine_brigade` stay themselves; other land types with softness under 0.5 (`g_AiAirNavalPowerBase`, 500) go to the armour
  and the rest to the infantry.
- **`GetDissent()`** (`0x4F8AE0`): `dissent` (`+0x10B4`), thousandths (`FINDINGS-government.md` C).
- **`HasActiveLendLeaseToAnyone()`** (`0x5089A0`, rva `0x1089A0`): the receivers at `+0x6B8` hold any entry - **weight and
  effectiveness not asked**, so a receiver at weight 0 counts.
- **`GetEscorts()`** (`0x417C30`): `+0xB4`, **the escorts on no convoy** - finished escort lines add to it, and
  `CCountry::DistributeConvoyShips` (`0x4FD750`) deals from it and gives back each day; at peace no convoy wants escorts, so
  all are there, and at war a convoy's are not counted.
- **`GetTotalConvoyTransports()`** (`0x8E8200`): `+0xBC`, the free transports (`+0xB0`) and every convoy's, as
  `DistributeConvoyShips` found them at the start of the day's pass.
- **`GetTotalNeededConvoyTransports()`** (`0x8E8210`): `+0xC0`, **the transports already on convoys, as they stood before the
  sharing, plus `TotalNeededTransports`** (`+0xB8`, the `transports_wanted` of every convoy not idle). So the script's
  `needed - current` comes to `wanted - free`.
- **`CalcDesperation()`** (`0x4EE560`): section B.

### C.6 The order: `CConstructUnitCommand`

    loBuildOrder = SubUnitList()                 -- 0x989340: an empty CList<CSubUnitDefinition const*>
    SubUnitList.Append(loBuildOrder, type)       -- 0x8EAC10: at the tail, in the script's order; nil not refused
    CConstructUnitCommand(tag, loBuildOrder, CapitalPrvID, liBuildCount, lbReserve, CNullTag(), CID())

**`CNullTag()`** (`0x988010`) is the tag `---`, **id 0**; **`CID()`** (`0x987590`) is `(0, 0)`. The invoker (`0x97C9D0`,
`inferred` - which stack index each converter takes is mapped from the registration's declared order, and the save bears
out the first tag being the country) wants two numbers, a boolean, two tags, a `SubUnitList` and a `CID`, the numbers through
`lua_tointeger` (to the nearest), the boolean as `lua_toboolean == 1`; a wrong type is a Lua "no matching overload" error.
`LuaConstruct_CConstructUnitCommand` (`0x988E90`) calls the constructor (`0x545760`, rva `0x145760`) with **build-now 0**.

| argument | field | what the line does with it |
| --- | --- | --- |
| `tag` | `country` `+0x3C` | whose queue: `Execute` takes `countries[id]` |
| the list | `brigades` `+0x60` | one `CBrigadeConstructionDefinition` an entry, **in the list's order**, each with the **builder's** level of each of its type's technologies in the type's order - an exile building for itself the higher of its own and its faction's first member's. Each brigade is named; the unit only where it has two or more |
| `province` | `+0x4C` | `Execute` stores `provinces[id]` (unchecked) as the line's location and `CCountry::EnqueueConstruction` **zeroes it**: **ignored**, never tested against the country - 0, a province not held or any id give the same line. The save has no military line with a location |
| `count` | `amount` `+0x70`, the line's Size | **a series: that many units one after another from one line**, priced as one unit a day. `Execute` takes every unit's men at once, `count x` the brigades' men, the pool held at 0. Units side by side are several commands |
| `reserve` | `is_reserve` `+0x74` | the line's reserve flag: `reserves_factor = 1000 + RESERVES_PENALTY_SIZE` on IC and men, units delivered at that share of strength. Their Finest Hour passes `not IsAtWar and IsRegiment()` - every land line at peace, 43 of 89 in the save |
| `CNullTag()` | `builder` `+0x44` | id 0, so the constructor and `Execute` take the **country** as builder; the save writes `builder` as the own tag on every AI line but licences |
| `CID()` | `target` `+0x78` | `(0, 0)`, no target: the finished unit waits in `deployments` to be placed (`FINDINGS-buildqueue.md` sections 4 and 7) |
| (none) | `build_now` `+0x80` | always 0 from Lua: queued, never built at once |

Making the command **mints numbers whether or not it is posted**: the line's id, the unit's (`1 + 2 x count`), each
brigade's (`1 + count` each). **`IsValid`** (slot 14, `0x546AE0`) **is `brigade count != 0` and nothing else** - men, IC,
technology, the type's caps, the province and the count are not asked; a refused command is dropped in silence. `Execute`
is `FINDINGS-buildqueue.md` section 5.

**Beside the player's order** (`FINDINGS-builders.md`): the windows post `parallel` commands of `serial` each, the
designer naming the declared capital and the others the acting capital, ignored either way. The script's `count` is the
player's `serial` and its loop of commands his `parallel`. His `accept` is greyed for want of men and the window's other
reasons; the script's only gates are its own Lua - `HasExtraManpowerLeft`, `IsUnitAvailable` and its sums of men.

### C.7 What looks wrong and is what the bytes do

1. A count of 0 is not refused. `Support.CreateUnit` posts one when men run short (`math.floor(left / cost)`): the line
   takes no men, counts nothing in the production counts (Size 0), and still delivers one unit (`Deliver`: `size -= 1;
   return size <= 0`).
2. The province is thrown away; the declared and the acting capital give the same line.
3. `HasExtraManpowerLeft` charges a quarter of build manpower for every brigade on the map, and each reserve line's
   brigades the men of their *built* strength - men taken already when the line was ordered - once a series.
4. `CountMaxUnitsStillBuildable`'s `all` leaves out the queue and the waiting; its `have` counts them.
5. `GetEscorts` counts the escorts on no convoy only; `GetTotalNeededConvoyTransports` includes those on convoys.
6. `GetICPart` is the slider's share of all the IC, whatever the share needs or was paid.
7. `IsLand`/`IsAir`/`IsNaval` look at the first brigade only.
8. `HasActiveLendLeaseToAnyone` is true for a receiver at weight 0.
9. `SubUnitList.Append` takes nil, and the command's constructor then reads through it.

### C.8 Not settled

- Which Lua stack index each converter of the invoker `0x97C9D0` takes (above).
- The order the units' loader gives `type_index` in - `GetSubUnitList`'s order.
- Whether units aboard ships or in transit are always in `CCountry +0xBAC`; the walk does not ask.
- An exile building for itself in no faction: the constructor reads the faction's first member through a static empty
  node (`0x170CF48`); not run.
- Whether the string hash matches a type's key with case.
- Frontier (rvas): `0x58C7D0` (the tag converter), `0x58CF60` (the `CID` converter), `0x77E650` (luabind's class-object
  lookup), `0x58C560`.

## D. Provinces and buildings, as the production script reads them

The callers are `tfh/script/ai_production_minister.lua` (`BuildOtherUnits`, `CoreProvincesLoop`, `ConstructConvoys`,
`BuildTransportOrEscort`) and `ai_support_functions.lua` (`Build_Building`).

**In one line.** Every getter here reads the **built** level of a building, the owner's queue and a daily cache, and
`CCountry:GetRandomUnderGroundTarget` **is not random**: it weighs its candidates by infrastructure and picks the one at
`757147 mod (total weight)` (`mov eax, 0xB8D9B; cdq; idiv ecx` at `0x509F8F`), so it answers the same province for as long
as the map stands still.

### D.1 What each engine method answers

| method | answers |
| --- | --- |
| `CBuildingDataBase.GetBuilding(name)` (`0x8E9F80`, rva `0x4E9F80`) | The building whose key is **exactly** `name`, case and all (`StringHashFind_At1C` over the database). An unknown name gives **nil**. |
| `CBuilding:GetIndex()` (`0x8E90A0`) | `CBuilding +0x54`: its index, its place in `buildings.txt` plus one. In Their Finest Hour: air_base 1, naval_base 2, coastal_fort 3, land_fort 4, anti_air 5, radar_station 6, underground 7, nuclear_reactor 8, rocket_test 9, industry 10, infra 11. The body is folded with the five ministers' `GetOwnerAI` (trap 4). |
| `CProvince:GetBuilding(b)` (`0x4A3B60`, rva `0xA3B60`) | The province's own `CProvinceBuilding` for `b`, `+0x310[b->index]`. Every province holds one for every building, so one it has none of answers an object at level 0, **never nil**. A nil building is dereferenced. |
| `CProvinceBuilding:GetMax()` (`0x417A70`, rva `0x17A70`) | `level_max` (`+0x20`): the **built** level in thousandths (`:Get()` gives whole levels as a float). A level just delivered and still repairing counts; a bombed level counts whole. |
| `CProvince:HasBuilding(b)` (`0x4A3900`, rva `0xA3900`) | The built level above nought. A queued level does not count. |
| `CProvince:GetCurrentConstructionLevel(b)` (`0x4A3930`, rva `0xA3930`) | The `size` (a whole count) of the **first** building line for `b` placed in this province, in the queue of the province's **owner**; 0 where there is none. |
| `CProvince:IsFrontProvince(flag)` (`0x4A56B0`, rva `0xA56B0`) | D.3. |
| `CProvince:GetController()`, `GetOwner()`, `GetProvinceID()` (`0x417A90`, `0x42F030`, `0x417A80`) | The controller's tag (`+0x334`), the owner's tag (`+0x32C`), the id (`+0xD0`). |
| `CCountry:GetControlledProvinces()` (recorded, `0x417AE0`) | The province **ids** of `+0xD00` as Lua numbers, in the order the country came to control them: `CCountry_AddControlledProvince` (`0x4DD1D0`), whose one caller is `Province_SetController`, appends at the tail unless the id is there already. |
| `CCountry:GetTotalCoreBuildingLevels(i)` (`0x4E21A0`, rva `0xE21A0`) | D.4. |
| `CCountry:GetRandomUnderGroundTarget()` (`0x509920`, rva `0x109920`) | D.5. |
| `CCountry:IsBuildingAllowed(b, p)` (recorded `confirmed`, `0x4DFFC0`) | `FINDINGS-buildingqueue.md` B.3: in order, the building researched; the country controls the province (but for the underground); whole built levels plus the size of every queued line of `b` there below `max_level`; a port where `port = yes`; the `not_if` and prerequisite lists. |
| `CCountry:GetBuildCost(b)` (recorded `confirmed`, `0x4DFDA0`) | **One building's IC a day**: `cost x (1000 - GetCategoryBuildDiscount) / 1000` - the discount `RecalculateCost` prices a new line with, so a line's day if ordered now, not its whole price. |
| `CCountry:GetConvoyBuildCost()`, `GetEscortBuildCost()` (recorded `confirmed`) | `CONVOY_BUILD_COST` or `ESCORT_BUILD_COST` x `(1000 + technology) / 1000`, never under 0.010: one line's IC a day (`FINDINGS-convoylines.md` A.1). |

### D.2 The two commands

**`CConstructBuildingCommand(tag, building, province, count)`.** The invoker (`0x97F820`, rva `0x57F820`) takes exactly
four arguments: the tag; the building, **nil accepted** as a null building; the province and the count, each a number
through `lua_tointeger` (to the nearest). `LuaConstruct_CConstructBuildingCommand` (`0x989860`, rva `0x589860`) calls the
constructor every poster uses (`0x544E10`), the count in EDI. **Making the command mints the line's id** - the counter
moves by `1 + 3 x count` - whether or not the script then posts it.

**`IsValid`** (slot 14, `0x545540`, reached through `CCommand:IsValid`): a null building is false; a province below 0 is
false; province 0 is true; otherwise `CCountry::IsBuildingAllowed(country, building, province)`. That is **the test the
province view's building button makes** before it posts (`CBuildingMember::OnClick`, amount 1) - the AI asks it through
`IsValid`, the button directly. **`count` is not tested**: only the built and already queued levels must stay below
`max_level`.

`count` is the line's `size`: one line of `count` buildings delivered one after another, each priced as one building a
day. Where a line for the same building in the same province is queued already, `Execute` adds `count` to the **last**
such line instead, capped at `max_level`; a new line is not capped, and the delivery caps `level_max` at `max_level`.
**`Execute` refuses nothing**; the command pump asks `IsValid` again just before it, so a province that changed hands
between the post and the execution is refused there. The script always passes 1, and the 20 April 1936 save's 31
building lines are all of size 1, all placed, none two for one building in one province.

**`CConstructConvoyCommand(tag, escort, count)`.** The invoker (`0x9846B0`, rva `0x5846B0`) wants the second argument a
**Lua boolean** (`lua_type == 1`; a number matches no overload), **true for escorts**, read as `lua_toboolean == 1`;
`count` goes through `lua_tointeger` and is the line's size in items. The command is `FINDINGS-convoylines.md` A.1 and
A.8; its `IsValid` is the folded `true`, and the script does not ask it.

### D.3 `IsFrontProvince(requireLandUnits)`

The record's `CProvince::HasHostileLandNeighbour` (`likely`) under its Lua name, the reading unchanged and extended.

- False for a province nobody owns (owner id 0).
- Otherwise its edges in order, skipping an impassable one (kind 3 - **a kind 1 sea crossing counts**), a neighbour that
  is not land, one in no owner's area (land nobody owns), and one held by **this province's controller**.
- The first neighbour left whose controller is an enemy of this province's controller answers **true** - an enemy by
  `CCountry::IsEnemy` (rva `0x2F210`): at war; either side `REB`; or an undeclared war between the two whose regions
  include **this** province.
- With the flag set, that neighbour must also hold at least one land unit, anybody's (`CountLandUnitsInList`), or the walk
  goes on.

The script passes `false`, so to it a front province is one touching enemy-held land by land or by a strait, held or not.

### D.4 `GetTotalCoreBuildingLevels(index)`

Element `index` of a cache at `CCountry +0x1038`/`+0x103C`, or 0 past its end. `CCountry::RebuildNeighbours` makes it
whole, daily and on a change of hands: an entry per building at nought; every **owned** province where the country holds a
**core** adds each building's `level_max`; and **every building line in the queue adds 1000, whatever its size** - a line
with no province always, a placed one only where the country has a core. So the script's `RocketSites < 1` and
`ReactorSites < 2` count built levels and lines as of the last rebuild; a line ordered since is not in it. *Hardcoded*: the
1000 a line. *Mod-able*: the two caps, which are the Lua's.

### D.5 `GetRandomUnderGroundTarget()`

**Candidates**, in order: where the country is a major or its `MaxIC` is over 100, every province **owned** by each
country on its allies list, in the list's order; then its own owned provinces. **One qualifies** - `Underground_CanPlaceIn`
inlined - where its underground's `level_max` is 0 (a line queued there does **not** exclude it); its controller is not
this country and is at war with it or either is `REB`; this country is a friend of the owner (military access counts); and,
for a minor, the owner is this country.

**Weight**: `w = clamp(infra x (1000 + local_infra + global_infra) / 1000, 10, 1000) x 50 / 1000`, truncated - 0 to 50,
five a level of infrastructure, held in a byte. **Own provinces count `3w`**, an ally's `w`.

**Pick**: `757147 mod (the weights' sum)`, walked along the running sum; **0** where nothing qualifies or every weight is
0. *Hardcoded*: the 10 to 1000 clamp (the floor a static `floor(10.5f)`), the 50, the 3 and 757147. *Mod-able*:
infrastructure, through buildings and modifiers.

### D.6 For a reimplementation

- `GetBuilding("infrastructure")` - `Support.Build_Infrastructure`, in Their Finest Hour, the base game and BlackICE alike
  - is nil, every `buildings.txt` calling it `infra`. Their Finest Hour never reaches it: no country's file calls it and
  `Utils.GetFunctionReference` does not fall back to `Support`. Were it reached, `loProvince:GetBuilding(nil)` would be an
  access violation, not a Lua error.
- In a province the AI controls but does not own - the infrastructure loop takes those - `GetCurrentConstructionLevel`
  reads the enemy owner's queue, whose lines there are cancelled the next day, so it answers 0; the cap against stacking
  is then only `IsValid`'s `max_level`.

### D.7 What looks wrong and is what the bytes do

1. `GetRandomUnderGroundTarget` is fixed: `757147 mod total`.
2. A queued underground does not take its province out of the candidates, so with a fixed pick the AI keeps choosing it
   and `IsValid` keeps refusing it: one underground line at a time while the weights stand.
3. A province below a fifth of its infrastructure weighs 0 and is never chosen; one's own weigh three times.
4. `GetCurrentConstructionLevel` reads the owner's queue, and its first matching line only.
5. `GetMax` and `HasBuilding` read the built level, not the working one.
6. `GetTotalCoreBuildingLevels` counts a line as one level whatever its size, lags until the next rebuild, and counts an
   unplaced line whatever the cores.
7. `IsFrontProvince` is false for an unowned province; a strait is a border; its flag counts anybody's land units in the
   enemy's neighbour, one's own and allies' among them.
8. A command made in Lua uses up line ids even when it is never posted.
9. `IsValid` ignores `count`.
10. `GetBuilding` of an unknown key is nil, and a nil building handed to `CProvince:GetBuilding` crashes rather than
    raising a Lua error.

### D.8 Not settled

- That `CProvince:GetBuilding`'s own invoker accepts a nil argument and pushes a null return as nil: inferred from the
  building command's invoker and luabind 0.9's source. Whether an access violation there is caught anywhere was not
  searched.
- The order a new game's loader gives provinces their controllers in, which sets `GetControlledProvinces`' order at the
  start, and whether a removal keeps the order.
- What `0x4CA740` (rva `0xCA740`), the third writer of `CCountry +0x1038`, is - a copy or a load.
- Frontier (rvas): `0xCA740`; `0x58C840`, the `CBuilding*` converter; `0x58C560`, luabind's holder apply; `0x58C7D0`, the
  `CCountryTag` converter, cited by name in records and itself unrecorded.
