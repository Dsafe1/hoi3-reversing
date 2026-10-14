# The government: laws, ministers, parties, dissent and unity, the screen, and the AI's politics

Read 2026-10-14 by the politics wave (`WAVE.md` at the time), for OpenHOI3's stage 4. Five readers,
five sections: **A** a law or a minister changed, **B** the parties over time, **C** dissent and
national unity, **D** the politics screen, **E** the AI's politics. Addresses are virtual (based
`0x400000`), with the rva beside anything named. What was already known is not repeated:
`FINDINGS-politics.md` (the country's daily pass, the election schedule, where laws and ministers are
kept), `FINDINGS-effectrun.md` 1.4 and 1.5 (the party effects, `coup_by`, `do_election`, the minister
effects), `FINDINGS-triggerleaves.md` (the government conditions).

---

## A. A law or a minister changed

### A.1 In short

- **Two commands carry every change**, `CChangeLawCommand` and `CChangeMinisterCommand`; script effects
  write the arrays themselves and go through neither.
- **Nothing is checked when they run.** The post, and again the session's drain just before `Execute`,
  ask slot 14 `IsValid`, which asks only that the country id is not 0 and that the law and group, or the
  minister and post, are real objects and not the null singletons - not the law's `allow`, whether the
  law belongs to the group, the cost, war or peace, the pool, `CanTakePosition`, the post's `changeable`,
  ideology, dates, nor whether the man already holds a post. **Whoever posts is responsible**: the
  politics screen, the AI's Lua, or the peace-time revert.
- **A law change** writes the law, charges money where `pay_cost` is set, tells the local player where
  `post_message` is set and the country is his, then rebuilds the country's modifier, reprices the whole
  build queue, and cuts every brigade to its new strength and organisation ceilings, the excess men going
  back to manpower. No history entry, no dissent or unity change, no delay, no cooldown.
- **A minister change** writes the post and tells the local player; nothing else - his modifier arrives
  at the next daily `RebuildStaticModifiers`.
- **The price** is `cost x money from 30 days at full MaxIC` - 0.75 money a point of MaxIC with the
  shipped numbers - charged **only to a country a person plays**.

### A.2 `CChangeLawCommand` (vftable VA `0x15C3D24`, 0x50 bytes)

| | |
| --- | --- |
| `+0x3C` / `+0x40` | the country's tag and id |
| `+0x44` | the law |
| `+0x48` | the law group |
| `+0x4C` | `pay_cost` |
| `+0x4D` | `post_message` |

Saved and loaded as `law` (an index into the law vector), `position` (an index into the group vector),
`country`, `is_law_change_costs` and `postMessage`, so the two flags survive the loopback post, which
serialises the command and rebuilds it from the prototype (`0x54ED80`, both flags 1).

**The constructor** `0x54EE30` (`ret 0x1C`) takes `(law, group, payCost, postMessage, tag)` and **keeps
the two flags only while `CCurrentGameState +0xDA4` `in_game` is set; otherwise it writes both as 0.**
`in_game` is set once, at `0x65D126`, after a new game's two first days.

**Who posts one** - all four constructor callers; `findRefs --vftable` finds exactly two vftable
writers, so the list is complete:

| poster | flags | which law |
| --- | --- | --- |
| the politics screen, `CLawChangeConfirmDialog` slot 5 (`0x6B8650`) | 1, 1 | the law's own group (`law +0x50`), the player's country |
| Lua `CChangeLawCommand(law, group, tag)` (`0x989BF0`) | 1, 1 | as the script passes them: the AI's script, and `Laws(country)` in a new game |
| `CCountry_RevertDisallowedLaws` (`0x4D57D0`) | `pay_cost` 0, `post_message` 1 | A.7 |
| `Clone` | copies them | the flags pass through the constructor again |

**An effect never posts one**, and no script effect sets a law. So `Laws(country)`, run inside
`SetUpCountryForNewGame` before `in_game` is set, changes laws **free and silent for every country, the
player's included**; the AI's changes in play carry flags 1, 1 but cost nothing, no person playing the
country, and tell nobody, the country not being the local player's.

**`Execute` (`0x54EF60`)**, in order:

1. `laws (+0x628)[group->index (+0x50)] = law`.
2. With `pay_cost`: `cost = CCountry_GetLawChangeCost(law, country)` subtracted from the money
   (`CGoodsPool +0x10`) of `pool_in_exile` (`+0x9F8`) for a government in exile, else of the acting
   capital's pool - a plain `add`, so the money can go below nought.
3. Where the country is the local player's (`CCurrentGameState +0xC34`) and `post_message` is set: the
   message `LAW_APPOINTED`, actor the country, target `---`, with **LAWNAME** the text of `<law>_<TAG>`
   where the localisation has one, else the law's name; **DESC** `<law>_desc` with every `§b` turned into
   `§W`; **EFFECT** the law's modifier lines; **POSITION** the group's localised name. The texts:
   `LAW_APPOINTED_HEADER` "New law Enacted", `_1` "$LAWNAME$", `_2` "has been enacted as our new
   $POSITION$", `_4` "$EFFECT$\n$DESC$", `_LOG` "We enacted $LAWNAME$ as our $POSITION$."; in
   `messagetypes.txt` `popup=yes`, `log=no`, `onmap=no`, `pausepopup=no`.
4. Always: `RebuildStaticModifiers`; slot 14 on every build-queue line; for every brigade, strength above
   its slot-12 maximum cut to it, `excess x 1000 / max_strength x build_cost_manpower / 1000` going back
   to manpower, floored at 0, and `strength_ceiling` restarting at the new strength; organisation above
   `GetMaxOrganisation` cut to it (`FINDINGS-organisation.md` section 5).

**So the original does act on a country's brigades when a law changes.**

**`CCountry_GetLawChangeCost` (`0x4F0570`, rva `0xF0570`)**: 0 for a country with no human player;
otherwise `law.cost (+0x94) x GetMoneyIncome(setting, 30000, MaxIC x 1000) / 1000`, `GetMoneyIncome` being
`MaxIC x 30 x IC_TO_MONEY x (1 + MODIFIER_GLOBAL_MONEY)`, every division truncating. With TFH's
`IC_TO_MONEY = 0.05` and every law's `cost = 0.5`, **0.75 money per point of MaxIC**. The politics screen
calls it too (D.4).

### A.3 `CChangeMinisterCommand` (vftable VA `0x15C3C24`, 0x4C bytes)

`+0x3C`/`+0x40` the country, `+0x44` the minister (a pointer, saved as the object reference `id`),
`+0x48` the post (`position`). The constructor `0x54E230` (`ret 0x14`) has no flags.

Posters: the politics screen's minister list (`0x6C1A60`, from `CMinisterItem` slot 4); the AI's weekly
filling of empty posts (`0x8A1D40`, E.2); the Lua `CChangeMinisterCommand(minister, position, tag)`;
`Clone`.

**`Execute` (`0x54E2D0`)**: `ministers (+0x618)[position->index (+0x4C)] = minister`; and where the
country is the local player's, the message `MINISTER_APPOINTED` with **MINISTERNAME** his `name`,
**PERSONALITY_DESC** the minister type he holds in that post (`CMinister::GetPersonality`) described,
**POSITION** the post's localised name - `_HEADER` "A new minister", `_1` "$MINISTERNAME$", `_2` "has been
appointed to the position of $POSITION$", `_3` "$PERSONALITY_DESC$", `_LOG` "$MINISTERNAME$ appointed role
as $POSITION$."; `popup=yes`, `log=no`. **Nothing else**: he stays in the pool, the replaced man stays in
the pool, he may keep other posts, no history entry, no rebuild - the modifier changes at the next day's
`RebuildStaticModifiers` (`RunCountryDailyPass`, `0x4DA5E3`).

### A.4 Which minister a post may take

- **`CMinister` slot 8, the "IsValid", is not about dates**: the shared `mov al,1` on `CMinister` and
  `xor al,al` on `CNullMinister` - "a real minister". An empty post holds the null minister.
- **`CMinister::CanTakePosition` (`0x52CC70`)**: the post is among his postings, the `<post> = <type>`
  lines of his block. Nothing more.
- **The ideology rule exists only in the fillers** (`FillMinisterPosts`, the AI's weekly filler).
  `Execute`, `IsValid` and the `<post> = id` effect never ask ideology.
- **Dates are asked only when the pool is made** (A.6), and by the trigger `minister_alive`.
- **One man may hold several posts**; nothing that writes a post asks what else he holds. The start save
  shows it: Croatia's 30004 holds four.
- **Fixed posts**: `changeable = no` (`head_of_state` and `head_of_government` in
  `government_positions.txt`) is read only by `remove_minister`, `has_removable_minister`, the Lua and the
  screen. The fillers refill fixed posts like any other; with `electedOnly` the government's elected bit
  decides.

### A.5 `CCountry_FillMinisterPosts` (`0x4F06D0`, rva `0xF06D0`), and when it runs

For each post `i >= 1`:

1. skip it unless `refillAll` is set or it holds the null minister;
2. with `electedOnly`, skip it unless the government's `elected_positions` bit for it is set;
3. walk `PossibleMinisters` in order: the **first** minister of the ruling ideology who lists the post is
   taken at once; else the **last** of the ruling ideology's group who lists it; else the **first** of
   anyone who lists it;
4. if nobody qualifies, the post keeps its holder.

No draw, no generator. A null ruling party with a pool that is not empty faults. Replayed on the saved
pool and ruling ideology it gives **220 of 220** posts for the 22 countries whose history names nobody.

| caller | `refillAll`, `electedOnly` | when |
| --- | --- | --- |
| `SetUpCountryForNewGame` | 0, 0 | a new game; empty posts only. Afterwards a null ruling party takes the head of state's ideology |
| `CCountry_HoldElection` | 1, 1 | an election |
| `coup_by` | 1, 0 | |
| the `government =` effect | 1, 0 | |
| `MakeVassal` | 1, 0 | |
| `CCreateVassalCommand` | 1, 0 | |
| `CLiberateCountryCommand` | 1, 0 | |
| `ReleaseProvinces` | 1, 0 | |
| `release_vassal` | 1, 0 | |

**Never** on a death, a law change, daily, or a load.

### A.6 The pool and ministers over time

- **The country file's `ministers` block** goes to `HistoricalMinisters (+0x170)` in file order
  (`CCountry_LoadHistoricalMinisters`); a missing `start_date` or `death_date` stays `g_NullDate`, which is
  1.1.1 at run time.
- **A save's `ministers = { ids }`** rebuilds the pool in order (`CCountry_LoadPossibleMinisterIds`); the
  save writes it with `CCountry_SaveMinisterIds`.
- **A new game** (`SetUpCountryForNewGame`, `0x4D6741`): each historical minister is appended **where
  `start_date <= now < death_date`**.
- **Daily** (`RunCountryDailyPass`, `0x4DA9CA`): a minister whose `start_date` **equals** today's tick
  (hour 0 of the day) and who is not already in the pool is appended - gated on idler slot 57, which in
  single player asks whether the top bar exists, which it does only once `Enter` has finished; so the step
  does **not** run during a new game's first two days.
- **Death: nothing takes a dead minister out of his post or the pool.** The only removal from the pool is
  `remove_minister`; the only count decrement in the image is its own. `MINISTER_DEATH` is declared in
  `messagetypes.txt` and localised ("has died. We no longer have the possibility of having $NAME$ in our
  cabinet.") but **the string does not exist in the executable** - the positive control: the one
  reference to `MINISTER_APPOINTED` is found.
- **What fills an emptied post**: the AI's weekly filler for an AI country, one of the fillers above, or
  the player through the screen.

**Open, and contradicted by the data.** In the start save (`Germany1936_01_01_00`): every TFH minister
whose `start_date` is 1936.1.1 is in its country's pool, in file order - 1,998 ids, none twice - Hitler,
who has no death date, among them; Britain's pool is `1001 1002 1003 ...`, where only 1002 and 1003 have
death dates; Iceland's posts were filled by the posting rule with a full pool. That fits only "a new game
pools everyone with `start <= now`". The bytes (`cmp eax,[esi+0x58]; jge` at `0x4D67DD`) leave out every
minister without a death date. Neither the start-date step (not running yet, and it would put Britain's
1002 and 1003 first) nor any other writer of `+0x160` (swept over the whole image; these are all of them)
explains it. TFH has no minister starting before 1936, so for TFH the save's rule is the safe one to
reimplement. **A live read would settle it**: a minister with no death date's `+0x58`, and a country's
pool count just after `SetUpCountryForNewGame`.

### A.7 `CCountry_RevertDisallowedLaws` (`0x4D57D0`, rva `0xD57D0`)

Called from `CCountry::OnDiplomacyChanged`, **only where the country is not at war**. One scope -
country this country, FROM `---`, province 0, THIS the scope itself, random state 0. For each law group
from index 1: where the current law is real and its `allow` (`CLaw +0x54`, slot 6) fails, it walks the
group's list (`+0xC`) in order and posts `CChangeLawCommand(law, group, 0, 1, country)` for the **first
other real law whose `allow` holds**; where none holds, the law stays. The player's own country included:
he gets a free `LAW_APPOINTED` for a law he did not pick.

### A.8 What looks wrong and is what the bytes do

- `Execute` checks neither the law's `allow`, its group nor the money: a law change can drive money below
  nought, and a command can put a law in another group's slot.
- A minister can be posted twice; nothing removes a holder from the pool, and no command asks that a
  holder be in it.
- `FillMinisterPosts` prefers the **last** group-mate in the pool but the **first** of anyone else.
- `FillMinisterPosts` and the AI's filler fault on a null ruling party; in `SetUpCountryForNewGame` the
  head-of-state fallback runs **after** the fill.
- The AI's law changes are free; changes made while a new game is set up, the player's included, are free
  and silent.
- The peace-time revert changes the player's laws without asking, and tells him.
- No minister ever dies; `MINISTER_DEATH` is never raised.
- New ministers join the pool only on their exact start day, and only once the top bar exists.

### A.9 What was not settled

- The pool at a new game against the start save (A.6).
- Idler slot 57 in multiplayer: it answers through `+0x1CD0`'s `+0xF5` byte; whether that can differ
  between peers, and so desynchronise the daily start-date step, was not read.
- `CLaw` slot 14's lookup (`0x529120`), read only in outline.
- The order of `CLawGroup +0xC` - the file's, likely.
- Traps met: trap 14 (`GetMinister`, `CanTakePosition` and `GetPersonality` already existed as Lua names;
  `switchmap`/`definitions.py` missed `LoadKey`'s `sub`/`dec` arm); trap 19 (the bytes at `0x4D67D3`,
  `0x4DA9CA`, `0x4F06D0` and `0x54EF60` compared with `hoi3_tfh_imperium.exe` and identical); trap 4
  (`CMinister` slot 8 and `CLaw` slot 16 are the folded `ReturnTrue`/`ReturnFalse`, left unnamed).

**Corrections made by this section:** the law command's message is `LAW_APPOINTED`, `LAWNAME` being only
one of its variables; `CChangeMinisterCommand +0x44` is a `CMinister*`, not an id; `FillMinisterPosts`'
preference was incomplete - among ministers of the group the **last** in the pool wins - and the
corrected rule reproduces 220 of 220 posts in the start save; `CChangeLawCommand::LoadKey` has five keys,
not three; `g_NullDate` is set at startup from `"1.1.1"`, the 43800000 in the file being only its
starting value; `GetMoneyIncome`'s second caller is the law's price, not the daily IC pass.

**Frontier (rvas):** `0x129120` (`CLaw`/`CIdeology` slot 14, the `<key>_<TAG>` name), `0x262FA0`
(`CInGameIdler` slot 57), `0x2052CB` (the fourth caller of the law's cost), `0x8A8230` (the `9999.1.1`
global's initialiser).

---

## B. The parties over time

### B.1 `CIdeologyData`: a country's figures for each party

A country holds two, embedded: **organisation** at `CCountry +0x10BC` and **popularity** at `+0x10F4` -
the game's own names, from the Lua accessors `AccessIdeologyOrganization`/`AccessIdeologyPopularity`
(rvas `0xC8820`/`0xC8830`). The cabinet's vector follows them at `+0x112C`. The constructor `0x528300`
(rva `0x128300`) builds a 0x38-byte object:

| offset | |
| --- | --- |
| `+0x8` | `values`: one int per ideology, indexed by `CIdeology +0x4C`, in thousandths of a percentage point. Index 0 is the null ideology (`CNullIdeology`, whose slot 17 answers false) |
| `+0x18` | `tallies`: one 16-byte entry per ideology, each a `vector<int>` of **five** slots - this month's record of what set each figure, by source (B.3) |
| `+0x28` | `last_change`: one int per ideology, the total change the last monthly drift made |

Only `values` is saved (`popularity = { data = { ... } }`, slot 2 at `0x528520`). Lua can read through
`GetValue` (`0x128480`) and `CalculateTotalSum` (`0x1284E0`), and cannot write.

The setter `0x5284A0` (rva `0x1284A0`), `CIdeologyData_SetValue` - the ideology in ECX, the data in EDX,
the value and the slot on the stack: **a value below 0 does nothing**; otherwise
`tallies[i][slot] += value` and `values[i] = value`. No clamp, no renormalising of the other parties.

Two normalisers, **both leaving index 0 (the null party) out of every sum and every scaling**:

- `0x528560` (rva `0x128560`), `CIdeologyData_NormaliseToOne`: `v_i = v_i x 1000 / sum`;
- `0x5285E0` (rva `0x1285E0`), `CIdeologyData_NormaliseToHundred`:
  `v_i = (v_i x 1000 / sum) x 100000 / 1000`, two truncations - so every figure comes out a multiple of
  0.1 and the total a little under 100. Every party figure for parties 1..10 in all six saves is a
  multiple of 0.100.

### B.2 Where they come from on a new game

The history's `popularity = { national_socialist = 65 ... }` and `organization = { ... }` (the
`tfh/history/countries` file) become one history entry per ideology. `CPopularityChange::Apply`
(`0x5F0EF0`, rva `0x1F0EF0`) and `COrganizationChange::Apply` (`0x5F0CC0`, rva `0x1F0CC0`) are slot 7 of
those entries (`this +0xC` the country, `+0x10` the ideology, `+0x14` the figure, `+0x18` the figure it
replaced): going forward they keep the old figure and call the setter with **tally slot 2**;
popularity's then calls `CCountry_AllotCabinetSeats`, organisation's does not. So the history's numbers
go in raw, x1000; a party the history does not name keeps the constructor's **0**; a negative figure is
ignored; and **nothing normalises at that point** - Germany's organisation history sums to 230.

Then, as the game is entered, `SetUpCountryForNewGame` allots the seats again (B.5), and
`RunSupplyAndConvoyIterations` runs one `RunMonthlyPass`, which runs **one drift** (B.3); the drift
normalises both figures to 100 and allots the seats once more.

Checked against `Germany1936_01_01_00.hoi3`. **Exactly one drift ran**: the 42 non-zero null parties in
that save are all whole multiples of 0.010, which is what one draw from 0 gives; two would leave others.
Organisation in that save is the history normalised by `NormaliseToHundred` **once** for 8 countries that
do not exist on that date (CRO, IDC, LEB, MEN, PAK, PRK, RSI, SYR), **twice** for 26 that do (GER among
them: 39.2 / 13.0 / 13.0 / 13.0 / 17.3 / 4.3 from 90/30/30/30/40/10), and either for 66 where the two
results coincide. **The second normalisation of an existing country was not found** (B.8).

### B.3 What moves them: the monthly drift, `CCountry_UpdatePartyPopularity` (`0x4F6D00`, rva `0xF6D00`)

Called once a month by `CCountry::UpdateMonthly` (`0x4DCD3E`), for every country, existing or not. For
every ideology i in index order, **index 0 included**:

    drift   = (organisation[i] - popularity[i]) x 1000 / PARTY_POP_CHANGE_RATE              (64-bit, truncated)
    ruling  = i is the ruling party (+0x1140) ? floor((mod[RULING_PARTY_SUPPORT]/1000 + 0.0005) x 1000) : 0
    random  = RandomThousandths() x POPULARITIY_RANDOMNESS / 1000 - POPULARITIY_RANDOMNESS x 1000 / 2000
    penalty = n >= 2 ? (dissent x n) x ELECTION_MINISTER_DISSENT_PENALTY / 1000 : 0
              n = cabinet posts 1.. whose minister's ideology (CMinister +0x6C) is i,
                  a minister holding two posts counted twice
    last_change[i] = drift + ruling + random + penalty
    new = popularity[i] + last_change[i]
    if new >= 0:  tallies[i][4] += new;  popularity[i] = new          (a negative result is NOT applied)

After the loop: `NormaliseToHundred` on popularity, then on organisation, then
`CCountry_AllotCabinetSeats`. Back in `UpdateMonthly`, `CIdeologyData_ClearTallies` (`0x528770`) empties
organisation's tallies and popularity's.

Their Finest Hour's `tfh/common/defines.lua`, `country` block:

- `PARTY_POP_CHANGE_RATE = 10` - a party closes **a tenth** of its gap to its organisation each month;
- `POPULARITIY_RANDOMNESS = 10` (sic) - the draw runs from -5.000 to +4.990 in steps of 0.010;
  `RandomThousandths` is the global MT19937 and answers 0..999;
- `ELECTION_MINISTER_DISSENT_PENALTY = -0.1` - a party holding two or more posts loses
  dissent x posts / 10 a month.

`mod[RULING_PARTY_SUPPORT]` is modifier 69, `ruling_party_support`: the laws `repression` 0.1 and
`totalitarian_system` 0.3 (`tfh/common/laws.txt`), the minister types `iron_fisted_brute` 0.1,
`prince_of_terror` 0.15 and `undistinguished_suit` 0.05, and event modifiers. **0.3 is +0.300 points of
popularity a month.** There is no term for the press laws, for war, or for anything daily.

Every writer of a party figure - from a displacement sweep of `.text` for
`+0x10BC`/`+0x10C4`/`+0x10D4`/`+0x10F4`/`+0x10FC`/`+0x110C`/`+0x111C` and the callers of the setter and
the normalisers, the positive control being that it finds the effects and triggers already recorded on
those offsets:

| writer | figure | tally slot |
| --- | --- | --- |
| the history (B.2) | both | 2 |
| the drift (above) | popularity | 4 |
| the normalisers (the drift, `CCountry::AfterLoad`) | both | - |
| the effects `organisation`, `popularity` and an ideology's block (`FINDINGS-effectrun.md` 1.4) | as there | 1 |
| espionage, `BOOST_RULING_PARTY`: the target's own ruling party | organisation | 3 |
| espionage, `BOOST_OUR_PARTY`: the target's figure for the actor's ruling party | organisation | 3 |
| loading a save | both | - |

The two espionage missions (`CSpyPresence::RunDailyMissions`, `0x53010C`/`0x530182`) add
`level x SPY_PARTY_ORGANIZATION_BOOST (0.01) x share` a day; a negative result is skipped, there is no
upper clamp. Everywhere **the tally gets the new figure, not the change**.

**Against the saves.** The null party is drifted every month and never normalised, which makes it a
sharp test: from `oldautosave.hoi3` (1 February 1936) to `autosave.hoi3` (1 March), one game, **101 of
101** countries' null parties move exactly as `old + trunc(-old/10) + (10k - 5000)`, or stay put where a
negative result was possible; with the rate 5 or 20 instead, 45 and 46 fail. For parties 1..10, leaving
out the ruling party (whose modifier the save does not keep) and countries with dissent, one
pre-normalisation sum fits every party in 97 of 97 countries. From 1 to 20 April (no month boundary)
nothing moved but organisation by the spies. By their file times the saves of 1 and 8 January and of 1
and 20 April are of other games than the February/March pair.

### B.4 The cabinet: `CCountry_AllotCabinetSeats` (`0x4F72F0`, rva `0xF72F0`)

Read whole on the listing. On a copy of popularity:

1. `NormaliseToOne`.
2. `seats` = the government positions whose slot 14 is true and whose `isChangeable` (`+0x50`) is set -
   8 in Their Finest Hour, the head of state and the head of government being `changeable = no`.
3. Every party under `PARTY_POPULARITY_CUTOFF` (0.1, against the 1.000-scaled share - under 10%) set to 0.
4. `NormaliseToOne` again.
5. For each real ideology: `q = share x seats x 1000 / 1000` (truncated),
   `n = round-to-nearest(float q / 1000)` (`fistp`).
6. The pairs sorted greatest first - with ten pairs the runtime's insertion sort, which keeps index order
   among equals.
7. Handed out in that order: `cabinet[i] = min(n, seats left)`.

**Seats the rounding leaves over go to nobody.** The cabinet is saved as `cabinet = { ... }`, whole
seats; rebuilt from the saved popularity it equals the saved cabinet for **606 of 606** country-saves
(all 101 countries in each of the six saves). Germany: 8 of 8 to `national_socialist`, every other party
being under 10%.

It runs after every drift; after every history popularity entry; in `AfterLoad`; at the end of
`SetUpCountryForNewGame`; after `coup_by` and after an election; and **on every daily pass on which the
ruling party holds no seat** (`0x4DBCBB`) - not, as `FINDINGS-politics.md` had it, when "the ruling
party has no support left".

Who reads the cabinet: `CCountry_HasFracturedGovernment` (rva `0xF7160`, section C.4) - true when a party
of another ideology group holds a seat, which gates the static `fractured_government`
(`national_unity = -0.05`) and the coup; `CoupCabinetSeats`; the espionage view's tooltip (`0x6200F2`) and
the politics view (`0x6C0444`).

`CIdeologyData::GetLeading` (`0x528690`) is confirmed as recorded, the first entry taken even when
negative; its one caller is the election.

**What the player sees of the tallies.** `CIdeologyData_BuildChangeTooltip` (`0x5287D0`), the tallies'
only reader, writes up to three lines, each only where its figure is not nought, green with `+` above
nought and red otherwise: `POL_PARTY_POP_FACTORS` "Internal Factors: " with `last_change`; `POL_EVENTS`
"Events: " with tally slot 1; `POL_SPIES` "Spies: " with tally slot 3. The politics view (D) shows
`PO_NO_CHANGE` "No changes this month" when it is empty.

### B.5 The election's schedule (completing `FINDINGS-politics.md` phase 4)

- **Elections and the term.** `CGovernment +0x7C` is the government's `election = yes` (its `LoadKey` at
  `0x5248DE`); `+0x2C` is `duration` by `atoi`, in **months** - 48 on every elective government in
  `common/governments.txt` (no `tfh/` copy). A country's own `duration` (`+0x98`) overrides it where not
  nought.
- **`[0x170C2B8]` is `g_NullDate`** - 1.1.1 at run time (43,808,760), set from `"1.1.1"` by its static
  initialiser `NullDate_Init` (`0xCA8210`); the 43,800,000 in the file is only its starting value (A.6;
  the collector checked the initialiser). With no last election `due` is `g_NullDate`, earlier than any
  real date, so **an election is held on the next daily pass** - not "never".
- **`[0x1BEA40C]`** (`g_ForceElections`) has one reference in the whole image, the read at `0x4DBC7D`; it
  lies in zero-filled `.data` and nothing writes it, so an election happens exactly when it is due. The
  positive control: the same scan finds `g_AiYesmen`'s writer.
- **On a new game** (the head of `SetUpCountryForNewGame`, `0x4D6230..0x4D633B`): a `last_election` set
  and earlier than now is moved forward by whole terms to the last election date on or before today; at
  the tail, a `last_election` before year 3 (null) becomes **today**. The dates come from
  `last_election =` in `common/countries/<Country>.txt` (34 countries in the start save) and in two OOB
  files (`SWE_1936`, `USA_1936`); the other 67 read `1936.1.1`. In the saves Greece's 1932.1.26 was held
  on 1936.1.26, Costa Rica's 1932.2.9 on 1936.2.9, Republican Spain's 1932.2.16 on 1936.2.16, each
  stamped on the anniversary at hour 0, and in each the most popular party won.
- **The player is told** only `ELECTIONRESULTS` - a popup with a pause and no log entry
  (`messagetypes.txt`): header "Election $ELECTION_YEAR$", "$WINNING_PARTY$" / "Won the election", log
  text "$WINNING_PARTY$ won the election of $ELECTION_YEAR$." Only to the played country.
- `CCountry_HoldElection`'s record says "`t % 15` is within +-14"; the draw is never negative, so it is
  0..14. Its conclusion stands: every factor is 1000 and the most popular party wins.

### B.6 The coup: `CPerformCoupCommand` (`from`, `to`)

| slot | what |
| --- | --- |
| 2 | `SaveContents`, folded with two other commands |
| 6 | `Execute`, already confirmed |
| 7 | `GetTypeId` = `perform_coup` (0x7C1) |
| 13 | `Clone` |
| 14 | `CountryPairCommand_IsValid` (rva `0x158D20`): both ids not nought, nothing more |

The constructor `0x554280`: `from` = (`+0x3C`, `+0x40`), `to` = (`+0x44`, `+0x48`).

**Who posts one**: only the espionage view, when the player presses `attempt_coup_button` (callback
`0x629A30`), with the viewed country as `from` and the player as `to` - **`from` is the target**. The
button shows only when the view's spy figure for the target is above 0 (inferred), the player's
covert-operations points about the target (`+0xF4`) are at least `COUP_COVERT_OPS_COST` (20), and
`CanAttemptCoup` (`0x4F7A60`) holds: the two ruling ideology groups differ, the target's government is
fractured, and the instigator's group holds at least one seat in the target's cabinet. Its tooltip
(`0x4F7EE0`, read only for its keys) uses `COUP_DESC` "Attempt a coup. This will remove all your spies
from $TARGET$", `COUP_NOT_ENOUGH_SUPPORT`, `COUP_DESC_DISABLED` "Their party position is too strong", and
`COV_OPS_COST` / `COV_OPS_COST_LACKING`. No AI path and no Lua path posts one.

**What happens**: `Execute` -> `PerformCoup` (already confirmed): the spies go to 0, covert operations
lose 20 (floored at 0), and the attempt succeeds when `RandomThousandths() < CoupChance` (`0x4F7AD0`):

    chance = seats x COUP_CHANCE_PER_POSITION (0.2) x (1 - national_unity/100)   in thousandths
    the target leads a real faction: 0;   the target is any other faction member: chance / 3

Success fires `on_coup_success` - event 5057 in both the base game and TFH: leave the factions,
**`coup_by = FROM`** (the hand-over to `CCoupEffect`, `FINDINGS-effectrun.md` 1.5), relation +200,
`organisation = 20`, `popularity = 20`, `national_unity = -30`. Failure fires `on_coup_fail` (5058).

### B.7 What looks wrong and is what the bytes do

- The null party is drifted every month and never normalised nor seated; it gathers figures like 2.170
  in the saves.
- A drift whose result would be negative is **not applied at all** - the party keeps its old figure,
  rather than going to 0.
- Every tally slot records **new figures, not changes**, so "Events:" shows the sum of the party's
  figures after each event.
- Seats the rounding leaves over go to nobody.
- Organisation's `last_change` is never written, so its "Internal Factors" line never shows.
- Loading a save appends the saved `cabinet` to a vector already sized, so a reloaded game saves 22
  figures (inferred from `0x45F450` and the saves).
- `CCountry +0x113C` `election` is loaded inverted and read by nothing.
- `CPerformCoupCommand`'s `IsValid` and `Execute` re-check neither the coup's conditions nor the
  covert-operations points.
- `SetUpCountryForNewGame`'s catch-up loop would never end for a past `last_election` with a term of 0 -
  a non-elective government with a past date; no Their Finest Hour file has that (inference).

### B.8 What was not settled

- **Why existing countries' start organisation is normalised twice** where one drift ran. The only
  in-place normalisers are `AfterLoad` and the drift; whether `AfterLoad` runs for existing countries in a
  new game was not found.
- How many decimals the tooltip's figures print (`0xA5ABC0` not read).
- What the espionage view's `[esp+0x58]` gate is (taken to be the spy level).
- The partition step of `StdSort_IdeologySeats` (`0x514360`).

**Corrections made by this section:** `[0x1BEA40C]` is never written, so elections are never forced;
`[0x170C2B8]` is `g_NullDate`, meaning "no election yet, hold one now", not "never"; the `0x4F72F0` call
at the end of phase 4 runs when the ruling party holds **no cabinet seat**; `RandomThousandths`'s recorded
arithmetic gave 0 for every draw, and it answers 0..999; `AllotCabinetSeats`' order of steps was recorded
wrongly; and `CCountry +0x113C` (`election`) is no has-elections flag - nothing reads it.

**Frontier (rvas):** `0xF7EE0` (the coup tooltip), `0xF8490` (the politics screen's party tooltip,
`POL_PARTY_MINISTER_DISSENT`, `POL_PARTY_DISTANCE_FROM_ORG` - section D's), `0x21F490` (the espionage
view's update with the coup button), `0x229A30` (the coup button's callback), `0x14D970` (from/to
`SaveContents` folded over three commands), `0x1541D0` (`CPerformCoupCommand`'s prototype constructor),
`0xF7940` (`CIdeologyData`'s copy constructor), `0x514360`, `0x45F450`, `0xA5ABC0`, `0x2BE790` (the
politics view's party panel).

---

## C. Dissent and national unity

Both are thousandths: `dissent=2.356`, `national_unity=89.991` in a save.

### C.1 Dissent: every writer

Dissent is `CCountry +0x10B4`, never below 0 and with **no upper bound**. A scan for the 32-bit
displacement over `.text` finds 56 sites; its positive control is that it finds the two known writers,
the effect and the consumer goods share. Read site by site, the writers are:

| writer | what it does |
| --- | --- |
| `CCountry::CCountry` (`0x4C9A20`) and `CCountry_Reset` (`0x4D2EB4`) | sets 0 |
| `CCountry::LoadKey` (`0x4CEA29`) | the save's `dissent`, taken raw |
| **`CDistributeConsumerGoods::Distribute`** (`0x518EC2`, rva `0x118C50`), once a day from the share loop at `0x4DB4F3` | `dissent += GetConsumerGoodsNeeded - share x factor + MODIFIER_DISSENT`, floored at 0. Skipped in a scenario (`gamestate +0xD0C`); the loop skips REB and countries with no tag (`FINDINGS-production.md`, `FINDINGS-distribute.md`) |
| `RunCountryDailyPass` `0x4DB691` | `dissent = 0` for REB, every day |
| `CDissentEffect::Execute` (rva `0x5BA0B0`) | the `dissent = N` effect: `+= N`, floored at 0 |
| `CCountry::SetDissent` (`0x4F8B00`, rva `0xF8B00`) | sets it, floored at 0. Its only caller is `CDissentChange` slot 7, a history `dissent = N` (Sweden's history has `dissent = 0.05`) |
| `CMakePrideCommand::Execute` (rva `0x1DB530`) | `+= GetPrideRedesignationDissent(new ship, old pride)` when a country that has a pride of the fleet names a new one |

`GetPrideRedesignationDissent` (`0x4E6500`, rva `0xE6500`): `PRIDE_BASE_REDESIGNATION_DISSENT`
(military `+0x6C`, 1 in Their Finest Hour); where the new ship's `extra_consumption` (the sum of its
technology levels) is above the old one's, divided by the difference + 1; halved where the new ship's
hull is greater; each step truncating. **`PRIDE_SUNK_DISSENT_IMPACT` (2) is never read**: a pride sunk
only fires on_actions (`FINDINGS-supply.md`).

So **there is no daily decay or drift** but the consumer goods share, and **laws and ministers move
dissent only through `MODIFIER_DISSENT`** ("Daily Dissent Change", a figure per day), which that same
formula adds - `consumer_product_orientation` -0.2, `back_stabber` +0.01, `ambitious_union_boss` -0.05,
one triggered modifier -0.1. **A law change, a minister change, a war, an occupation or a lost province
writes nothing** - no writer exists in the command range; the positive control is that the scan finds
`CMakePrideCommand::Execute`, which is a command.

### C.2 Dissent against the saves

The maintainer's saves of 1 January, 4 January 12h, 7 January 14h and 8 January 2h and 7h are one game
(of 9 October); the 1 February and 1 March autosaves are of that game too; 1 April and 20 April are of
another (8 October) - Germany's unity is 92.3 on 1 March and 89.97 on 1 April, which tells them apart.

- Germany goes from 0.000 to **3.000** by 4 January 12h: event 5022's `dissent = 3` (it carries the flag
  `illegal_printing_discovered`).
- It then falls by **exactly 0.161 a day** - 3.000 to 2.517 over three daily passes, 2.517 to 2.356 over
  one, 0 by 1 February: a constant, one-for-one rate (Germany holds `consumer_product_orientation`'s
  -0.2), with no curve.
- The rest are jumps (El Salvador 3.063, Panama 4.831, the United Kingdom 4.116, Communist China 1.787 on
  20 April) and residues of 0.003 to 0.171 gone by the next save, which fit the AI moving its sliders.

So the rules explain the shape of every movement. The 0.161 itself was not reproduced: that needs
Germany's need and effective share to the thousandth.

### C.3 National unity on a new game

National unity is `CCountry +0x10B8`, held between 1000 and 100000. **A new game takes it from the
country's history**: a `national_unity = N` entry is a `CNationalUnityChange`, whose slot 7 sets the
value through `CCountry::SetNationalUnity` (`0x4F8B40`, rva `0xF8B40`), which clamps to 1..100 and **does
not** apply `national_unity_effect`. No define and nothing of the government is involved. A country whose
history has no figure keeps the constructor's 0, and its first daily pass lifts it to the 1.0 floor - REB
is 1.000 in every save. `CCountry_Reset` zeroes dissent and **leaves unity alone**. The save's
`national_unity` is loaded raw. The console command `setnationalunity` (rva `0x3F650`) - "Sets the
national unity of the provided country to the given value" - uses the setter, and so do the history's
own dated changes (Romania's in 1940).

### C.4 The daily change: `RunCountryDailyPass` `0x4DA727`-`0x4DA895`

For every country, every day, unconditionally, straight after `RebuildStaticModifiers`:

    prune the three strategic-warfare lists of entries dated before now - 168 hours   (C.5)
    convoy, allies, bombing = each list's sum, held to -2.000 .. 2.000
    fp15(x) = trunc(x * 32768 / 1000)
    month = fp15(convoy + allies + bombing)
          + max(fp15(values[MODIFIER_NATIONAL_UNITY]), -1.0)     ; id 44, the national_unity key
    day   = trunc(month / 30)
    u = national_unity
    if u < 49000 and day < 0:  day = trunc(day / isqrt(50 - trunc(u / 1000)))
    if u > 51000 and day > 0:  day = trunc(day / isqrt(trunc(u / 1000) - 50))
    delta = floor(day * 1000 / 32768)                              ; an arithmetic shift
    ChangeNationalUnity(delta)

and `CCountry::ChangeNationalUnity` (`0x4F8B80`, rva `0xF8B80`):

    u += trunc(delta * (1000 + values[MODIFIER_NATIONAL_UNITY_EFFECT]) / 1000)    ; id 68
    u = clamp(u, 1000, 100000)

So **every `national_unity` modifier is per month** - which is what the tooltip says: `STRMONTHLY_CHANGE`
"Monthly Change:", with `STW_CONV` "Convoy/ASW Warfare:", `STW_ALLIES` "Allied Help:", `STW_BOMB`
"Strategic Bombing:", and `EFFECT_SIZE_MOD_NU` "The size of changes is modified by:". `isqrt` is
`IntegerSqrt` (`0x46C2E0`), Newton's method, floored. The damping slows only movement **away from 50**,
past 49 or 51, the distance in whole points; movement towards 50 is never slowed.

The monthly `national_unity` modifier's sources in Their Finest Hour: static `fractured_government`
-0.05; the spy modifiers `spy_lower_national_unity` -0.1 and `spy_raise_national_unity` +0.15, scaled by
the spies' level and mission share (`FINDINGS-espionage.md`); event modifiers (+0.1 and the like).
`national_unity_effect` comes from the press laws (`free_press` +0.2, `state_press` -0.05,
`propaganda_press` -0.1) and minister types (`compassionate_gentleman` +0.1, `power_hungry_demagogue`
-0.1, `ruthless_powermonger` -0.2, `barking_buffoon` +0.1).

**`CCountry_HasFracturedGovernment`** (`0x4F7160`, rva `0xF7160`) attaches `fractured_government`, in
`RebuildStaticModifiers` step 22: true when any ideology of **another ideology group than the ruling
party's** holds a cabinet seat (`CCountry +0x112C[index] > 0`, the counts `CCountry_AllotCabinetSeats`
writes). No null test on the ruling ideology. The coup code calls it twice more.

### C.5 Strategic warfare: the three lists and their writers

`CCountry +0x1184` is an embedded `CStrategicWarfare` of three lists of `{date in hours, value}` - convoy
`+0x18`, alliance `+0x28`, ground bombing `+0x38` - with their impacts at `+0x8`/`+0xC`/`+0x10`
(`CCountry +0x118C`/`+0x1190`/`+0x1194`). Saved as `strategic_warfare = { alliance convoy
ground_bombing }`; every save examined has them empty.

Each adder multiplies the value by `StrategicWarfare_GetICScale` - **the owner's total IC / 100, held to
0.1..10** (the floor is `floor(100.5f)`) - appends the entry, and adds it to the impact, held to +-2.0
(a constant, not a define). The bombing adder alone also multiplies a negative value by
`1 + sw_national_unity_effect` (modifier 101, "Strategic Warfare Penalty"; `the_finest_hour` sets -0.5).

| list | where | value |
| --- | --- | --- |
| convoy | `ResolveConvoyRaid`, a raid beaten off (`CONVOY_TOO_STRONG`) | `-(STRAT_CONVOY_DAMAGE -0.5 / victim's convoys) / 10`, to the victim, so positive (`FINDINGS-convoys.md`) |
| convoy | `ResolveConvoyRaid`, ships sunk | `(transports + escorts lost) x STRAT_CONVOY_DAMAGE / victim's convoys / 1000`, halved with an escort, to the victim (`FINDINGS-navalmissions.md`) |
| convoy | `CCombat::Tick`, a naval convoy battle's first hour, a defending unit under `convoy_raid` or `patrol` | `STRAT_RAIDER_FOUGHT_IMPACT` 0.015, to the attacker's first country |
| convoy | `CCombat::Tick`, an air battle's first hour, a defender under `air_convoy_raid` | the attacker's wings x `STRAT_AIR_RAIDER_FOUGHT_IMPACT` 0.02 / 5 |
| bombing | `CCombat::Tick`, an air battle's first hour, a defender under `strategic_bomb` | the attacker's wings x `STRAT_BOMBER_FOUGHT_IMPACT` 0.1 / 5, times `STRAT_BOMBER_NONCRIT_IMPACT_FRACTION` 0.25 where the province is land controlled by one of the **defender's** countries and not its core |
| bombing | `CCombatManager::StartBombing`, a strategic bombing creating a bombing | `STRAT_BOMBING_PENALTY` -0.05, to the target unit's owner, else the province's controller |
| alliance | `CLandCombatant::Attack`, once a day per side (`(tick - 43800000) % 24 == 0`) | below |

The alliance writer works out a country C - the battle province's controller, or, for an attacking side
whose first unit's owner is a friend of the province's owner, the controller of the province that unit
stands in - and acts only where the province lies in the area of C's acting capital, C is a friend of the
province's owner, and C has strong allies at war. Then for each unit of the side: one of C's adds
`brigades x STRAT_NO_ALLIES_HELP_PENALTY` (-0.001); one of those allies' adds `brigades x
STRAT_ALLIES_HELP` (0.1).

### C.6 The other changes to unity

- **The nuke** (`CNukeMission::IsActive`, rva `0x193C30`): the province's controller loses
  `NUKE_UNITY_IMPACT` (1.0, country `+0x4C`) x factor / 1000, the factor 1000, or `1000 + the province's
  modifier IC` where it is one of the controller's cores, doubled at its acting capital; through
  `ChangeNationalUnity`, so scaled.
- **The `national_unity = N` effect** (rva `0x5B19D0`): `ChangeNationalUnity(N x 1000)` - scaled by
  `national_unity_effect`, not divided by 30 nor damped.

**Nothing touches unity on a declaration of war, a lost province or capital, an occupation or a
surrender.**

### C.7 Unity against the saves

Between 4 January 12h and 8 January 7h (four daily passes), over 100 countries: **all 23 countries with
no seat held by another group stand still**, but Chile (+1 a day) and Paraguay (+3); the United Kingdom
and the United States are at 80.000 in every save of that game. **All 54 that fell are fractured.**
Fractured gives -2 a day before scaling (-0.05 -> fp15 -1638 -> /30 = -54 -> floor(-1.65) = -2); with
`free_press` (x1.2 -> -2.4 -> -2) East Germany, Greece and Romania lose 0.002 a day; with
`propaganda_press` (x0.9 -> -1.8 -> -1) Germany 0.001; with `state_press` (x0.95 -> -1) Afghanistan and
China 0.001. France (-1 with `free_press`) and 19 fractured countries that stand still need minister
terms or offsetting modifiers not computed here. February moves by 28 days' steps - no 29 February.

### C.8 What the two do elsewhere

**Dissent:**

- **IC**: the static `dissent` modifier, scaled by dissent / 1000, enters the country's modifier in
  `RebuildStaticModifiers` - in the base game `global_ic = -0.01`, 1% of IC a point.
- **Production**: `CCountry::GetSpareICIn` gives the consumer goods share no spare IC while there is any
  dissent.
- **Combat**: every combatant's `ApplyCombatModifiers` applies `-COMBAT_DISSENT_IMPACT` (0.02) x dissent
  / 100; on land the `dissent_impact` trait too.
- **The AI**: its two attack-odds estimates use it, and the production Lua adds 0.1 to consumer goods
  above 0.01 dissent.
- **The parties, monthly** (`0xF6D00`, section B): each party whose ministers hold two or more posts gets
  `ELECTION_MINISTER_DISSENT_PENALTY` (-0.1) x dissent x posts - tooltip `POL_PARTY_MINISTER_DISSENT`,
  "Dissent penalty from ministers:".
- The trigger, the top bar, `BuildDissentTooltip` (`DISSENTV_IRO`/`2`/`3`), the intelligence screen
  (VA `0x625E68`).
- **Revolts: nothing.** Neither `GetProvinceEffectiveRevoltRisk` nor `RunDailyRevoltRoll` reads it; it
  would reach them only if a mod put revolt-risk keys in the static `dissent` block. That is the door.

**National unity:**

- **The surrender level**: `CCountry::GetSurrenderProgress` reaches 1000 when the occupied share of the
  owned cores' victory points reaches unity.
- **The coup chance** (`0xF7AD0`, section B): `COUP_CHANCE_PER_POSITION` (0.2) x positions x
  (1 - unity / 100), a third in a faction, 0 for a faction leader.
- **The laws' `allow` blocks**, through the trigger.
- **The AI's intelligence Lua** raises its own unity by spies below 70, 80 or 95.
- The top bar, its tooltip, the intelligence screen.
- **Nothing reads it for IC, leadership, organisation or revolts.**

### C.9 The rest of the daily pass

The nineteen calls `FINDINGS-politics.md` left unread, named:

| call at (VA) | callee (VA) | name (rva) | politics? |
| --- | --- | --- | --- |
| `0x4DA5D7` | `0x4DD8D0` | `CCountry::EnsureCapital` (`0xDD8D0`) | no |
| `0x4DA5DD` | `0x4D8070` | `UpdateTriggeredModifiers` (`0xD8070`) | through modifiers only (one carries dissent) |
| `0x4DA5E3` | `0x4DDD80` | `CCountry::RebuildStaticModifiers` (`0xDDD80`) | **yes**: ministers, laws, government, scaled `dissent`, `fractured_government`, spies' unity |
| `0x4DA722` | `0x50C0B0` | `CCountry_ReplaceExileWithPuppet` (`0x10C0B0`) | no |
| `0x4DA734`/`40`/`4C` | `0x530950` | `StrategicWarfare_PruneList` (`0x130950`) | **unity** |
| `0x4DA751` | `0x530CA0` | `CStrategicWarfare::RecomputeImpacts` (`0x130CA0`) | **unity** |
| `0x4DA83F` | `0x46C2E0` | `IntegerSqrt` (`0x6C2E0`) | unity's damping |
| `0x4DA890` | `0x4F8B80` | `CCountry::ChangeNationalUnity` (`0xF8B80`) | **unity** |
| `0x4DA89A` | `0x4E1DA0` | `GetMonthlyManpowerGain` (`0xE1DA0`) | no; the `+0xBCC` one |
| `0x4DAEA2` | `0x507DF0` | `CCountry::CheckTechSharing` (`0x107DF0`) | no |
| `0x4DAF35` | `0xA48B20` | `CDiplomacyStatus_ExpireRelations` (`0x648B20`) | no |
| `0x4DB2C0` | `0x5BB950` | `CUnit::ConsumeSuppliesAndFuel` (`0x1BB950`) | no |
| `0x4DB78C`-`AA` | `0x4FDF40`, `0x4FE7E0`, `0x4FD750` | `CCountry::MaintainSupplyConvoys`, `MaintainResourceConvoys`, `DistributeConvoyShips` | no |
| `0x4DB7C4` | `0x8A5C90` | `CAIStrategy::Rebuild` (`0x4A5C90`) | no |
| `0x4DB7EE` | `0x4EE860` | `CCountry_UpdateActiveMission` (`0xEE860`) | no |
| `0x4DB93E` | `0x4FFD10` | `CCountry::DailyEspionagePass` (`0xFFD10`) | through spy missions; espionage's |
| `0x4DBBC2` | `0x4C07C0` | `RunDailyRevoltRoll` (`0xC07C0`) | no; does not read dissent |
| `0x4DBCC7` | `0x4F72F0` | `CCountry_AllotCabinetSeats` (`0xF72F0`) | **yes**, section B; runs when the ruling party has no seat |
| `0x4DBE8C` | `0x49DD00` | `SupplyCapacity` (`0x9DD00`) | no |
| `0x4DBEA3` | `0x4DCD70` | `CCountry::UpdateManpowerAfterMobilising` (`0xDCD70`) | no |
| `0x4DC138` | `0x685F00` | `CGameState::GetLocalPlayer` (`0x285F00`) | no |
| `0x4DC1BA`-`0x4DC20B` | `0x8EACA0`, `0x510160`, `0x50D570` | `GetThreadLuaState`; `LuaProxy_BalanceProductionSliders` and its `_Call` | no |

### C.10 What looks wrong and is what the bytes do

- The floor at the end means any negative monthly figure costs at least 0.001 a day, while a positive one
  below about 0.031 a month does nothing: unity drifts down by default.
- The damping slows only movement away from 50, and only past 49 or 51.
- `MODIFIER_NATIONAL_UNITY` is floored at -1.0 a month; the strategic-warfare impacts are not (+-2.0
  each).
- `STRAT_BOMBER_NONCRIT_IMPACT_FRACTION` tests the province against the bombers' countries, not the
  interceptors'.
- A country at war with no strong allies gets no alliance entries at all, good or bad.
- `sw_national_unity_effect` scales negative bombing entries only.
- `setnationalunity` and the history skip `national_unity_effect`; the effect and the nuke do not.
- The top bar's colour (impacts + modifier) ignores the floor, the /30, the damping and the scaling.
- `CCountry_Reset` zeroes dissent and not unity. A redesignation never lowers dissent, and a better ship
  costs less.
- `StrategicWarfare_PruneList`'s list-flag branch would free the same data twice; nothing was seen to
  reach it.

### C.11 What was not settled

- Germany's 0.161 a day was not reproduced to the thousandth (its need and share were not computed), nor
  the per-country minister terms of national unity.
- `CStrategicWarfare +0x1198` has another store at VA `0x649A1A` (rva `0x249791`) and two `lea`s
  (`0x647FE8`, `0x65E4BF`) - probably other classes; not checked.
- `CCountry_UpdateActiveMission`'s choice of a new mission (`0x9C7260`, `0x9C7510`) is read only in the
  decompiler; the intelligence screen's reader at VA `0x624970` was not read.
- Traps met: trap 2 (`0x53088F` is one `int3` between `AddBombingImpact` and `GetICScale`); the
  decompiler dropped `PruneList`'s loop; `GetICScale`'s `ret 4` consumes the caller's prologue
  `push edi`.

**Corrections made by this section:** `CCountry::ChangeNationalUnity` has three callers (the daily
change, the nuke, the effect), not one, and is not the only writer of `+0x10B8`; `FINDINGS-politics.md`'s
table put "result accumulates into `+0xBCC`" on `0x4F8B80`, which is the unity change - the `+0xBCC` line
belongs to `0x4E1DA0`; `0x4F72F0` is `CCountry_AllotCabinetSeats`, not "ruling-party support", gated on
the ruling party holding no cabinet seat; `CCountry +0x1184` is not only a series the strategic-warfare
screen draws but the three lists that feed national unity.

**Frontier (rvas):** `0xF6D00` (the party drift, B), `0xF7A10` and `0xF7AD0` (the coup, B), `0x224970`
(the intelligence screen), `0x5D6670` (`CUnitList::SumSubUnitCounts`), `0x9C7260`, `0x9C7510`,
`0x5119D0`.

---

## D. The politics screen

The interface files are `interface/country_politics.gui` and `.gfx` (Their Finest Hour's `tfh/` copies
differ only in `horisontal = 0` lines and `norefcount` keys). Section A has the commands this screen
posts; B what the party figures are; C dissent and unity. This is what the screen shows of them and what
it sends.

Conventions, as in `FINDINGS-diplomacyview.md`: "the country" is the played country - the idler's slot
23, game state `+0xC30/+0xC34` in a single-player game. A window finds an element by its slots - 13 a
button, 15 an instant text box, 17 an icon, 27 a child window, 31 a list box. On a button, slots 13 and
14 show and hide, 46 (`+0xB8`) enables, 47 (`+0xBC`) disables, 51 (`+0xCC`) sets the label; on an icon,
slot 18 sets the frame and slot 65 is a *sticky* hide (`0xAA2AB0` hides it and sets `+0xEA = 1`); on a
drawable, slot 68 (`+0x110`) tints it with a `CColor`; on a list, slot 20 shows it, 21 hides it, 23
empties it and 4 adds a row. FFP is `FormatFixedPoint`, which truncates. Texts are Their Finest Hour's
English.

### D.1 The view, and when things happen

**Construction.** `CPoliticsView::CPoliticsView` (`0x6BADA0`, rva `0x2BADA0`) runs from the in-game
screen's view list at `0x659B79` after `new 0x258`; it is the **fourth view, index 3**. The base
`CCountryView` makes `country_politics` and `topcolor_politics`. The view's automation setting is entry
3 of the local player's list, so the arrows and `automation_setting` are the base's
(`FINDINGS-diplomacyview.md` D.7); under "Ai Control" the base slot 14 is inherited unchanged (that it
greys the whole window is inferred). Then `BuildWidgets` (`0x6BCD10`) hooks the buttons and makes the ten
cabinet rows; `BindPopularityChart` keeps the pie's drawable and fills it; `UpdateOrganisationBars`, then
`FillPartyLegend`; the law window's `cancel` is hooked.

**Rebuild** (slot 0, `0x6BB240`) does the same after the base remakes the windows, and sets the
organisation bars twice.

**Show** (slot 2, `0x6BC0E0`), every time the screen opens:

1. shows both windows and refreshes the automation line;
2. refreshes the cabinet rows, refills the pie, sets the bars;
3. hides `minister_select_win`, `law_selection_window`, `policy_selection_window`, `puppet_select` and
   `liberate_select`;
4. sets the government labels and refills the laws and the occupied countries;
5. `faction_symbol_icon` gets frame `CFaction +0x3C` where the country's faction is real, and is hidden
   otherwise (in TFH 1 comintern, 2 axis, 3 allies);
6. tags the main window with the group string `politics_view`, which is how the in-game screen routes an
   element's tooltip to this view's slot 10.

**The legend is not refilled by Show.**

**Update** (slot 6, `0x6BB350`) runs every frame through `CInGameIdler_UpdateOpenView` (every frame is
inferred, as in diplomacy D.1), and does nothing unless `CCountryView::IsOpen` (slot 7, `0x6EB4E0`, the
main window's visibility byte) holds. Then, in order:

1. where `minister_list1` is visible, refreshes every cabinet row (cheap: D.3);
2. where any `laws_listbox` row's law is no longer the country's law of that group, refills the law list;
3. calls `policies_listbox`'s slot 31 (that the rows' own refresh rewrites `which` is inferred);
4. **the three buttons stacked on one spot (767,610)**: a government in exile (`CCountry +0x95`) shows
   `revolt` alone, enabled where `0x50AE40` (not read) answers yes; otherwise `revolt` is hidden,
   `demobilize` shows when mobilised (`+0x94`) and `mobilize` when not, **both disabled while at war
   (`+0xACC`)** and enabled at peace;
5. `convoys_val`, `allies_val` and `bombs_val` in `strat_warfare`: `FormatStratWarfareImpact` of
   `CCountry +0x118C`, `+0x1190` and `+0x1194` - `§R` + FFP(v,2) below 0, `§G+` above, `§Y` at 0;
6. `create_puppet` and `liberate_country` (D.5).

**Not refreshed while open: the pie, the bars, the legend, the government labels** - only on Show or
Rebuild.

**Elements no code looks up** keep the file's text: `headline_politics` ("POLITICS"),
`popularity_label` ("Popularity"), `organization_label` ("Organisation"), `policies_label` ("Occupied
Countries"), the strategic-warfare `label` ("Strategic Warfare"), the six scale texts "100".."0" beside
the bars, the backgrounds - none of their names is a string in the image (searched in `.rdata`; the
positive controls `org_chart` and `minister_position` are found). `close_button` is the base's glue,
whose handler `0x6EB290` was not read.

### D.2 The parties

**The government block** (`FillGovernmentLabels`, `0x6BE470`, from Show):

| element | text |
| --- | --- |
| `government_type` | `CCountry_GetGovernmentName`: the government's slot 13 (`0x524260`) with the country's isSubject byte (`+0xF34`) - the localised government key, or its `<key>_vassal` text for a subject where that exists |
| `government_desc` | **the elections line**, the government's slot 16 (`0x524950`), below |
| `ruling_ideology` | the ruling party's (`+0x1140`) slot 14: `<ideology>_<TAG>` where the localisation has it, else the ideology's name. **No null test** |
| `ruling_ideology_icon` | tinted with the ruling party's colour (`CIdeology +0x54`, the `CColor` its `color` key loads) |

**`government_desc`, the elections line**: a government with `duration` 0 gives `TERM_FOR_LIFE` "This
government has no elections." and a newline. Otherwise `TERM_DURATION` "Elections are held every
§Y$YEARS$§W months." and a newline - YEARS the country's own `duration` (`+0x98`) where not 0, else the
government's, a count of months despite its name. Where the government has `election = yes` (`+0x7C`)
there follows `NEXT_ELECTION` "Next Election" + ": §Y" + month name + " " + day + ", " + year - the date
`last_election` (`+0xAB0`) plus that many months, the year (date - 43,800,000) / 24 / 365 truncated, the
day `Date_DayOfMonth` + 1 - **with no closing §W and no newline**. Then the government's modifier, one
value a line (`DescribeAllValues`).

**The pie** (`political_popularity_chart`, a `PieChartType` of size 50 at scale 0.5;
`FillPopularityChart`, `0x6BDFD0`): total = the sum of the country's popularity (`CCountry +0x10FC`) from
index 1 - the null party left out. **Where total is 1.000 or less the pie gets no slices.** Otherwise
every ideology from index 1, in database order, gets a slice in its colour of size
`p x 100000 / 1000 x 1000 / total`, floored at 0, converted to single precision / 1000 and stored with
`fistp` - **the whole percent, rounded half to even**. A party at 0 gets a 0 slice.

**The legend** (`political_legend`, rows `political_legend_item`; `FillPartyLegend`, `0x6BD730`,
constructor and Rebuild only): one row per ideology from index 1 in database order - `title` the
ideology's slot 14 for the country, `legend_color` tinted with its colour. Plain `CStandardlistboxItem`s.

**The organisation bars** (window `org_chart`; `UpdateOrganisationBars`, `0x6BE220`): for each ideology
from index 1, the icon named `<ideology key>_org` - the file declares exactly TFH's ten,
`national_socialist_org` .. `stalinist_org`, 25 apart - an `org_bar` progress bar of 20x100, filled to
organisation (`CCountry +0x10C4`) / 1000 cut towards 0 (a whole percent), its colour copied from the
ideology's `CColor`. **The icon is not null-tested**, so a mod ideology without a bar in the `.gui`
faults (inferred: window slot 17 answers null for a missing name).

**The ruling party is not marked in the pie, the legend or the bars**; it appears only as
`ruling_ideology` and its icon. The parties' tooltips are in D.6.

### D.3 The cabinet

**Rows.** `BuildWidgets` takes the government-position database (index 0 its null post) and, with
n = (entries - 1) / 2, puts posts 1..n into `minister_list1` and n+1.. into `minister_list2`, in file
order, each a `CMinisterItem("minister_entry", idler, view, post, 0, cabinetRow = true)`. With TFH's ten
posts that is `head_of_state` .. `minister_of_security` on the left and `minister_of_intelligence` ..
`chief_of_air` on the right; BlackICE's eleven give 5 and 6.

**What a row shows** (`CMinisterItem::Refresh`, slot 8, `0x6C2430`; from Show, and every frame while the
list is visible): the minister is the row's own (`+0xD4`), or for a cabinet row the country's holder of
the post, `ministers[post->index]`. **Nothing is redone while he is the one already drawn (`+0xD8`)**,
unless the global `[0x1BEA49C]` is set.

- `title`, cabinet rows only, set once by the constructor: the post's localised name ("Head of State").
- No minister, or one failing his slot 8 (`IsValid`): `name` "???", `personality` "???", `ability` "",
  `legend_color` hidden; the photo is left as it was.
- Otherwise: `name` his name (`+0x30`); `personality` the display name of
  `CMinister::GetPersonality(post)` - the type of his posting for this post, or the null type; `ability`
  that personality's modifier values, one a line (`DescribeAllValues`), gated on the post's slot 14
  (true on a real post); `legend_color` his ideology's colour, shown; `photo` a new sprite of
  `gfx/pictures/portraits/<picture>.tga` (`CMinister +0x74`, defaulting to `empty_position`) on the
  `GFX_empty_position` sprite type, shown.
- **The Replace button** (`replace_minister`, `REPLACE_MINISTER_B` "Replace") is disabled, then enabled
  where some minister of the country's pool (`PossibleMinisters`, `CCountry +0x160`, section A) has his
  ideology in the government's accepted list (`CGovernment +0x30`), the post is changeable (`+0x50`;
  `head_of_state` and `head_of_government` are `changeable = no` in `common/government_positions.txt`),
  he has a posting for the post, and he is not its holder. **Because of the "already drawn" gate this is
  worked out again only when the post's holder changes**, or on the constructor's own test.
- Last, the row's window is tagged `politics_view`.

**Choosing a minister.** Replace (glue `+0x78`, `CMinisterItem::OnReplace`, `0x6C31E0`) runs
`OpenMinisterSelection(view, post)` (`0x6C14E0`): `minister_list1` and `minister_list2` are hidden;
`minister_position` is set to the post's name (the file's `MINISTER_POSITION` placeholder overwritten);
`minister_list_select_new` is emptied and refilled with **every minister of the pool, in the pool's
order, whose ideology the government accepts and who has a posting for the post** - each a
`CMinisterItem("minister_select_entry", ..., minister, cabinetRow = false)`, refreshed at once;
`minister_select_win` is shown. **No test here of the post being changeable, of the holder, or of
dates** - the holder appears too if he is in the pool. A choice row shows the same `name`,
`personality`, `ability`, `legend_color` and `photo`; its button is labelled `SELECT` "SELECT" and is
disabled where the post is not changeable; it has no `title`.

**SELECT** (glue `+0x28`, slot 4, `CMinisterItem::OnSelect`, `0x6C3220`) runs
`CPoliticsView::ChooseMinister` (`0x6C1A60`): hides the window, **posts
`CChangeMinisterCommand(country tag, id, minister, post)`** (constructor `0x54E230`) through the idler's
slot 18, `+0x38`, slot 6, and shows the two lists again - no other check, no cost. `cancel`
(`OnMinisterSelectCancel`) hides the window and shows the lists.

### D.4 The laws

**Rows** (`laws_listbox`; `FillLawList`, `0x6BDB50`, from Show and from Update whenever a row's law is
stale): one `CLawEntry` per law group from index 1 to the end of the law database's group vector,
holding the country's law at that position of `+0x628` - in TFH civil, conscription, economic, education
investment, industrial policy, press and training. Each row (window `current_law_entry`): `category` the
group's localised name; `which` the law's slot 14 for the country (`<law>_<TAG>` where it exists, else
the law's name); `select_button` (`GFX_law_button`) runs `OpenLawSelection(view, group)`.

**The law window** (`law_selection_window`; `OpenLawSelection`, `0x6C0E00`): `category` the group's name;
`law_list` holds **every law of the group in the group's list order, unfiltered** (that the list keeps
the file's order is inferred), each a `CPossibleLawEntry` (`0x6B9610`, window `possible_law_entry`).

**The cost**: `0x4F0570(law, country)` (section A; the command charges it) - **0 unless a person plays
the country** (game state `+0xBCC[id]`); otherwise the law's `cost` (`+0x94`, the `cost = 0.5` of
`common/laws.txt`) x `CDistributeConsumerGoods::GetMoneyIncome(the country's production setting,
fraction 30000, maxIC x 1000)` / 1000.

**A possible law's row**, with money the stockpile's money (the exile pool `+0x9F8`, or the acting
capital's pool, field `+0x10`):

- `name` = the law's name for the country + " (" + (`§G` where money >= cost, else `§R`) +
  FFP(cost, 1) + "§W)" - "Volunteer Army (§G12.3§W)";
- `effect` = the law's modifier values, one a line;
- the current law hides `possible_indicator` and any other hides `current_indicator`, so the current
  law's row wears `GFX_bg_selected_law`;
- **`select_button` is disabled unless** the law's `allow` (`+0x54`) holds for the country, money >=
  cost, and it is not the current law.

**The confirmation.** `select_button` (slot 4) makes a `CLawChangeConfirmDialog` (`0x6B81E0`), a
`DefaultDialog`, through `CEU3Idler::AddDialog`: both shields the player's flag; title
`CONFIRM_CHANGE_LAW_TITLE` "Change Law"; description `CONFIRM_CHANGE_LAW_DESC` "Are you sure you wish to
enact the new law §Y$LAW$§W?", LAW the law's display name; moved to its own position + (150, 150).
**Agree** (slot 5, `0x6B8650`) **posts `CChangeLawCommand(law, law->group, 1, 1, country tag, id)`**
(constructor `0x54EE30`), hides the law window and closes; it re-tests neither allow nor cost. Decline is
`CEU3Dialog`'s Close. **StaysOpen** (slot 7, `0x6B8700`) is the law's `allow` asked again, so the dialog
goes when the law stops being allowed (that false closes it is the record's inference); affordability is
not asked.

### D.5 Mobilisation, revolt, puppets, liberation, occupation

- `mobilize` posts `CToggleMobilizationCommand(tag, id, 1)`, `demobilize` the same with 0; `revolt`
  posts `CSpawnFullRevoltCommand` (decompile only). Section E reads the commands.
- `create_puppet` opens `puppet_select` with a `CPuppetEntry` per `GetPossibleVassals`;
  `liberate_country` opens `liberate_select` with a `CLiberateEntry` per `GetPossibleLiberations`
  (`0x4EDED0`); the two `back_button`s run the view's Show (decompile only).
- When the release dialog accepts it calls `NoteNewPuppet`, which keeps the country at `+0x218` and
  disables `create_puppet`; Update keeps the button disabled until that country owns a province, then
  clears the tag. Otherwise each button is enabled where its list of candidates is not empty. **The
  liberation dialog's `NoteLiberation` writes the same `+0x218`** (D.9).
- `policies_listbox` lists every country that owns a province, is not the country, is at war with it (or
  REB either side), and has a province the country controls; each `current_policy_entry` row shows the
  flag, the name and `which` (the occupation policy's name), and its button opens
  `policy_selection_window`, which lists every valid policy as name / effect / indicator, a policy's
  button greyed where its `allow` fails (THIS the country, FROM the occupied one), posting
  `CChangeOccupationPolicyCommand`. All from the decompile, and outside the brief.

### D.6 Tooltips (`CPoliticsView::BuildTooltip`, slot 10, `0x6BE790`)

By the element's name, in this order:

| element | text | delayed |
| --- | --- | --- |
| `convoys_icon` | `POL_SW_CON_IRO` "Impact from Convoys" | `POL_SW_CON_DRO` "Convoys being attacked will lower this, ..." |
| `convoys_val` | `POL_SW_CON` "In the last 7 days we've had §Y$EVIL$§W attacks on our convoys, impacting national unity by §R$ESC$§W per month. We attacked convoy raiders §Y$GOOD$§W times with an impact of §G+$GSC$§W per month." - built by `0x530D40` on `CCountry +0x1184 + 0x18` | - |
| `allies_icon` / `allies_val` | `POL_SW_ALL_IRO` "Impact from Allies" / `POL_SW_ALL` | `POL_SW_ALL_DRO` |
| `bombs_icon` / `bombs_val` | `POL_SW_BOM_IRO` "Impact from Bombing" / `POL_SW_BOM` | `POL_SW_BOM_DRO` |
| `liberate_country` | with candidates `POL_LIB_COUNTRY_YES`; else `POL_LIB_C_NO_FACTION` (no real faction), `POL_LIB_C_WE_EXILE` (we are in exile), `POL_LIB_C_NO_EXILES`, or `POL_LIB_C_POSSIBLE` + a line per exiled faction member owning provinces and not our enemy (flag, name, its capital's controller) | - |
| `create_puppet` | `POL_PUPPET_YES` / `POL_PUPPET_NO` | - |
| `mobilize` | at war `POL_MOBILIZE_WAR_IRO` "You are automatically mobilised when at war."; else `POL_MOBILIZE_IRO` "This will mobilise your reserve divisions into regular divisions." | `POL_MOBILIZE_DRO_V2` with DAYS = `MOBILIZATION_BONUS_DAYS` / 1000 (30 in TFH), then `POL_MOBILIZE_DRO_V3` "To fully mobilise our reserves we need §Y$MP$§W manpower.", MP = FFP(sum over reserve regiments of (max_strength - strength) x 1000 / max_strength x build_cost_manpower / 1000, 1) (`0x4DD060`, inferred) |
| `demobilize` | at war `POL_DEMOBILIZE_WAR_IRO`; else `POL_DEMOBILIZE_IRO` | `POL_DEMOBILIZE_DRO` |
| `revolt` | `GetMobilizeUndergroundsAvailability` (recorded) | - |
| `faction_symbol_icon` | the faction's name (a real faction only) | `CFaction_DescribeRulesAndModifier` (diplomacy F.5) |
| `political_popularity_chart` | the slice under the mouse (`0xAA3270`; slices are whole percents): the ideology's slot 15 for the player - the name for the country plus " (<own name>)" where those differ - + " - §Y" + the slice's percent + "%§W" | below |
| `ruling_ideology_icon` | the ruling party's slot 14 for the player | - |
| `<ideology>_org` (each bar) | slot 15 name + ": " + FFP(organisation, 2) | organisation's change factors, or `PO_NO_CHANGE` "No changes this month" |
| rows of `minister_list1/2` | `CMinisterItem::BuildTooltip`: on `legend_color` the minister's ideology's slot 15 name; on `replace_minister` **only while disabled** `NO_REPLACE_MINISTER` "No other candidates." | - |
| rows of `laws_listbox` | `CLawEntry::BuildTooltip`: on `which` or `select_button`, the law's modifier values | - |
| rows of `policies_listbox` | `0x6BA5A0`, not read | |
| rows of `law_list` | `CPossibleLawEntry::BuildTooltip`, `select_button` only: the current law `POL_CURRENT_LAW` "This is the law currently enacted"; allow false - the allow block's text (`GetBlockText`, red-when 0, depth 0); allow true but too poor - `CANNOT_AFFORD` "We cannot afford the associated costs of enacting this law"; else the allow block's text | - |
| rows of `policy_list` | the policy's allow text (`0x6BABC0`, decompile) | |

**The pie's delayed half**, in order:

1. the **change factors** of popularity (`CIdeologyData_BuildChangeTooltip`, B.4), or `PO_NO_CHANGE`:
   `POL_PARTY_POP_FACTORS` "Internal Factors: " + (`§R` at or below 0, else `§G+`) +
   FormatFixedPointTrimmed(last change) + "§W\n"; `POL_EVENTS` "Events: " + (`§G` above 0, else `§R`) +
   FormatFixedPointTrimmed(tally slot 1) + **"+\n"**; `POL_SPIES` "Spies: ", the same with tally slot 3 -
   each only where its figure is not 0;
2. `"\n--------------\n"`;
3. **`CCountry_DescribePartyDrift`** (`0x4F8490`): for the ruling party, the contributors to
   `RULING_PARTY_SUPPORT` (modifier 69); where **two or more** cabinet posts hold ministers of this
   ideology, "\n" + `POL_PARTY_MINISTER_DISSENT` "Dissent penalty from ministers: " +
   FFP(n x dissent x `ELECTION_MINISTER_DISSENT_PENALTY` (-0.1), 2); always
   `POL_PARTY_DISTANCE_FROM_ORG` "Distance from organisation value: " +
   FFP((organisation - popularity) x 1000 / `PARTY_POP_CHANGE_RATE` (10), 2), shown as -1 where the
   define is 0 - the terms of the monthly drift (B.3) without the random one;
4. "\n";
5. `QUALIFIES_FOR_CABINET` "Qualifies §Y$COUNT$§W for cabinet positions", COUNT = `CCountry +0x112C[ideology]`.

**No tooltip** on `government_type`, `government_desc`, `ruling_ideology`, the legend, the scale texts,
the minister choice rows (the dispatch does not walk `minister_list_select_new`), a row's `name`,
`personality`, `ability` or `photo`, nor the puppet and liberation rows. `CMinisterItem::BuildTooltip`
has a second caller at `0x6761BB`, not read.

### D.7 What opens the screen

`topbarbutton_politics` (the top bar's observer `+0xB8`) runs `CTopBar::OnPoliticsButton` (`0x6CEF70`),
`CInGameIdler::OpenCountryView(3)` (`0x6656D0`): if any view is open, all open views are closed (slots 5
and 4); if the politics view was the open one, the map's three side objects come back and **nothing
opens - the button toggles**; otherwise the view's slot 8 and then slot 2 (Show) run. The six top-bar
screen buttons are views 0..5 in the order diplomacy, production, technology, politics, intelligence,
theatre. **F4 is the button's own `shortcut = "F4"`** in `topbar.gui`; no code names it. An alert named
`politics` also opens view 3 (`CInGameIdler::OnAlertClicked`, `0x64B563`), only when it is not already
open.

### D.8 The `C*Change` history classes

All seven derive `CCountryHistoryEntry` (country `+0xC`, date `+8`); slot 2 is SaveContents, slot 6
GetSaveToken, slot 7 Apply(bool forward).

| class | layout | made by | Apply forward (backward restores the kept value) | slot 6 |
| --- | --- | --- | --- | --- |
| `CLawChange` (0x1C) | `+0x10` law, `+0x14` previous, `+0x18` group | **only** `CCountryHistory::LoadEntry` (`0x5EE62D`) | keep `GetLaw(group)`; `SetLaw(group, law)` | `law` (`0x5EC790`, shared) |
| `CMinisterChange` (0x1C) | `+0x10` minister, `+0x14` previous, `+0x18` post | **only** the history loader (`0x5EE533`) | keep `GetMinister(post)`; `0x4F06B0`: `ministers[post->index] = minister` | `ministers` |
| `CIdeologyChange` (0x18) | `+0x10` ideology, `+0x14` previous | the loader (`0x5ECECB`) and `CCountry_SetRulingIdeology(..., log = true)` | keep the ruling party; `SetRulingIdeology(x, false)` | **`law`** (`0x5EC790`) |
| `CGovernmentChange` (0x18) | `+0x10`, `+0x14` | the loader (`0x5ECE1B`) and `CCountry_SetGovernment(..., log = true)` | keep; `SetGovernment(x, false)`, which writes `+0xDFC` only | `government` |
| `CPopularityChange` | `+0x10` ideology, `+0x14` value, `+0x18` previous | the loader (`0x5EDA02`) | B.2: keep; the setter (tally 2); then **`CCountry_AllotCabinetSeats`** both ways | `popularity` |
| `CDissentChange` | `+0x10`, `+0x14` | the loader (`0x5EE255`) | keep; `0x4F8B00`: `+0x10B4 = v`, floored at 0 | `dissent` |
| `CNationalUnityChange` | `+0x10`, `+0x14` | the loader (`0x5EDAFE`) | keep; `0x4F8B40`: `+0x10B8 = v`, held to 1000..100000 | `national_unity` |

**Who reads them**: slot 7 is called by `CHistoryContainer::ApplyRange`, whose only driver is
`ExecuteHistory` - at load-everything, at reset-to-start-date, from `CSetHistoryDate` and from the
lobby, **never on the tick**: they are the history files replayed to the start date. **The screen reads
none of them** - nothing in `0x6B6000`-`0x6C3600` references their vftables or the history list. **No
savegame holds them** - the country blocks of the 1 January and 20 April 1936 saves have no `history`
key (the positive control: provinces' `history=` blocks appear in the same save, line 159245). So the
entries a running game adds (an effect's `government`, a coup, with log = true) are never applied and are
lost at a save, and **a law or minister change in play files no history at all** - only the loader makes
`CLawChange` and `CMinisterChange`. SaveContents writes the history-file grammar (`<group> = <law>` only
for a real law, `<post> = <minister id>` only for a valid minister, `ideology = `, `government = `,
`popularity = { <ideology> = <value> ... }`, `dissent = `, `national_unity = `). Who calls slot 6 was not
found; that `CIdeologyChange` answers `law` is harmless unless something does. `COrganizationChange`
(vftable `0x15C99E8`), the eighth sibling, is section B's.

### D.9 What looks wrong and is what the bytes do

1. **Liberating a country stores it in the puppet's pending slot** (`+0x218`); the liberation slot
   `+0x24C` is written by nothing but the constructor and Update. So after a liberation
   `liberate_country` is enabled again the next frame, and `create_puppet` stays disabled until the
   liberated country owns a province.
2. **The Events and Spies lines end in "+\n"**: the figure, then a literal `+`; they take `§G` with no
   `+` before the figure and have no `§W`; only "Internal Factors" has `§G+` and `§W\n`. They also show
   the sum of the new values the effects wrote, not the change (B.7).
3. `TERM_DURATION`'s variable is `$YEARS$` and its figure a number of months; the text says "months".
4. The next-election line has no closing `§W` and no newline, so the government's first modifier line
   runs on in yellow.
5. A cabinet row's Replace button is worked out again only when the post's holder changes; ministers
   entering the pool do not enable it until then, or until `[0x1BEA49C]` is set.
6. The minister choice lists the holder too (when he is in the pool) and does not test whether the post
   is changeable; SELECT is greyed instead.
7. The law window lists every law of the group; the confirmation checks neither allow nor money at Agree,
   and only closes when allow fails.
8. The law cost is 0 for a country no person plays.
9. The pie, the bars, the legend and the government labels do not refresh while the screen is open; the
   legend is built only at construction and Rebuild, under the played country's names then.
10. With total popularity at or below 1.000 the pie is empty; the null party is never in it.
11. An `<ideology>_org` icon missing from the `.gui` is used without a test; a mod ideology with no bar
    faults (inferred).
12. Rebuild sets the organisation bars twice.
13. `ruling_ideology` and `government_desc` read the ruling party and the government with no null test.
14. The code asks for `possible_Policy_entry` where the file names `possible_policy_entry`; it works only
    because the gui-type tree is case-insensitive.
15. A minister with no valid record shows "???" twice and keeps the previous minister's photo.
16. `CMinisterItem::OnReplace` asks the idler for the played country and throws the answer away.
17. Mobilise and demobilise are both greyed during a war, not hidden.

### D.10 What was not settled

`0x50AE40` (when `revolt` is enabled); `[0x1BEA49C]` (the forced redraw of minister rows);
`CInGameIdler::OpenCountryView` past `0x665854` and its `+0x1914`..`+0x1920` objects; who calls Rebuild;
list box slot 31 on `policies_listbox`; the second callers of `CMinisterItem`'s constructor (`0x453E0C`,
`0xA54FAC`) and of its tooltip (`0x6761BB`); `0x530D40` (the strategic-warfare variables); the
occupation-policy rows and the puppet and liberation dialogs (`0x6B6FD0`, `0x6B87C0`), read from the
decompile only; whether the law groups' and the minister pool's orders are the files'; what reads slot 6
of a history entry; `CGovernmentPosition` slot 14 taken as true on a real post from its body
`0xA92590`, the null post's not read.

**Corrections made by this section:** `CCountry::SetNationalUnity` (`0x4F8B40`) is a second writer of
`+0x10B8` (also section C); `CDistributeConsumerGoods::GetMoneyIncome`'s record puts its caller
`0x4F065A` in "the daily IC pass" - it is inside `0x4F0570`, the law's cost; and liberating a country
writes the puppet's pending slot.

**Frontier (rvas):** `0x10AE40` (revolt enabled), `0x130D40` (the strategic-warfare text), `0x1513F0`,
`0x2BA170`, `0x2BA770`, `0x2BA5A0`, `0x2BABC0` (the policy rows), `0x2B87C0`, `0x2B6FD0` (the release
dialogs), `0x6A3270`, `0x6A37D0` (the pie's hit test and setter), `0x6BA9A0` (the portrait sprite),
`0x2EB290` (`close_button`).

---

## E. The AI's politics

The AI's politics is two programs: a C++ refill of empty posts inside the politics minister, and the
install's Lua, `PoliticsMinister_Tick`, which changes laws, appoints ministers, mobilises and
liberates by posting commands. Their Finest Hour's `tfh/script/ai_politics_minister.lua` is the one a
TFH game runs (the searcher's order: mod, TFH, base game - `FINDINGS-luahost.md` section 2).

### E.1 Who has a politics minister, and when it acts

**Creation.** `CEU3AI::CreateMinisters` (rva `0x4888C0`) makes it for every country the local player
does not play, and for the player's own only when `GetLocalPlayer()[+0x38][3] == 1` - politics
delegated. In a scenario (`gamestate +0xD0C`) it makes no ministers at all. The test is against
`gamestate +0xC34` alone, so another human's country in a multiplayer game would get a minister on this
machine; that consequence was not followed.

**Enabling.** The minister is built by `CAIPoliticsMinister::CAIPoliticsMinister` (`0x8A1920`, rva
`0x4A1920`), appended to the CEU3AI's agent list, and given slot 52 at once,
`CAIPoliticsMinister::Enable` (`0x8A1980`, rva `0x4A1980`). This answers the "biggest hole" in
`FINDINGS-ai.md`: `CreateMinisters` makes every minister live itself, through `[vftable+0xD0]` at
`0x8889EF`, `0x888AE8`, `0x888BE1`, `0x888CDD` and `0x888E8F`. `Enable` sets `+0x3C enabled = 1` and
`+0x30 countdown = AIrand % 3 + 1` - one draw on the AI's generator. `ApplyPlayerDelegation` (rva
`0x488F30`) builds and enables one again when the player delegates politics.

**The schedule.**

- `ProcessAI` must pass its own gates - `CEU3AI +0x128`, `CCountry +0x580`, and the country owning a
  province or being in exile - and then calls slot 9, `CAIAgent::Update`, on each enabled agent. That
  decrements the countdown and calls slot 10, `DoWork`, when it reaches 0.
- `DoWork` (`0x8A1A40`, rva `0x4A1A40`) first sets the countdown back to 1, so after its first time it
  is entered on every AI pass, which is hourly on TBB workers (`FINDINGS-aisched.md`).
- It acts only when `(country_id + 17) % 24 == (tick - 0x29C55C0) % 24`: once a game day, in the hour
  `(id + 17) mod 24`.
- In that hour:
  1. if `GetDayOfMonth(today) % 7 == 0` - the day of the month counted from 0, so **the 1st, 8th, 15th,
     22nd and 29th** - it runs `CAIPoliticsMinister_FillVacantPosts` (E.2);
  2. it calls the Lua global `PoliticsMinister_Tick(minister)`, the minister handed over as a
     `CAIPoliticsMinister`, one argument and no result, inside a try block. A Lua error or a missing
     function is caught and logged as `LUA Error: <message>`, and the day's work ends.
- The body tests nothing about who plays the country, nor `in_game`.

**What runs as a new game starts.** Three things.

1. **`Laws(country)` for every country, the player's included**, from `SetUpCountryForNewGame` on the
   main thread, after the order of battle is read (`FINDINGS-luahost.md` section 3). It is the only
   direct call of the `Laws` global in the image: `"Laws"` at `0x15C0F34` is referenced once and
   `PrepareLuaCall_Laws` has one caller. **While it runs, `in_game` is still 0** - it is set at
   `0x65D126`, after `SetUpCountryForNewGame` at `0x65B4F2` - so the commands it builds carry
   `payCost = 0` and `postMessage = 0` (E.4); TFH's script then calls `SetEnablePostMessage(true)`, so
   the message byte ends up 1. `in_game_screen` is already the `CInGameIdler`
   (`FINDINGS-session.md` section 6), so `CCurrentGameState.Post` reaches its session.
2. `ProcessAI` from `CInGameIdler::Enter` and from the one-shot in `CInGameIdler::Update`, then the
   first hourly pass. `DoWork` can act in these only for a minister whose countdown has run out and whose
   hour gate matches hour 0 - **not** how every country's laws moved.
3. **`Laws()` ran more than once.** The start save `Germany1936_01_01_00.hoi3` holds the point that
   repeating `Laws()` reaches, not one pass of it:
   - Germany's conscription and economy are each two laws up (`two_year_draft`, `war_economy`), where
     one pass moves one;
   - Japan's economy is three up (`full_civilian_economy` to `war_economy`) and its civil law two up;
   - Italy's conscription is two up;
   - every group stops exactly where the next law's `allow` fails;
   - the saves of 1936.1.4, 1.7 and 4.20 are unchanged from it.

   `CInGameIdler::Enter` calls `SetUpCountryForNewGame` in a single per-country loop: the only back
   edges across `0x65B4F2` go to `0x65B152`, and there is no outer loop. **What runs `Laws` the second
   and third time, with the posted commands executed in between, was not found** (E.9).

   As inference, this settles one half of `FINDINGS-unitstart.md`'s puzzle: reserves fit the save's
   conscription law because `CChangeLawCommand::Execute`'s tail cuts each brigade to the new ceiling,
   while starting experience is fixed when a unit is made, so the training law the units show is the
   history's.

### E.2 `CAIPoliticsMinister_FillVacantPosts` (`0x8A1D40`, rva `0x4A1D40`)

C++, no Lua, no draw. It goes through the cabinet posts 1 to 10 in `common/government_positions.txt`
order (post 0 is the null position). A post is vacant when it holds the **null minister** - slot 8
answers false for `CNullMinister` and `mov al,1` for `CMinister`. For each vacant post it walks the
country's pool of possible ministers (`+0x160`) in list order, with R the ruling party:

1. the **first** minister whose ideology **is** R and who can take the post - stop;
2. else the **last** minister whose ideology is in R's **group** and who can take the post;
3. else the **first** minister of any ideology who can take the post.

"Can take the post" means the post is among the postings his `ministers` block lists - **except for
the head of state, where it is not asked**: the first minister of the ruling ideology in the pool
becomes head of state whatever his block says. The one found is posted at once as a
`CChangeMinisterCommand(country, minister, post)` on the country's channel. Nothing checks whether he
already holds a post, his dates, or whether the post may be changed.

### E.3 `PoliticsMinister_Tick` (TFH)

    if     GetAIRand() % 7  == 0  Mobilization        1/7      = 14.3%
    elseif GetAIRand() % 10 == 0  Laws                6/70     =  8.6%
    elseif GetAIRand() % 11 == 0  OfficeManagement    54/770   =  7.0%
    elseif GetAIRand() % 12 == 0  Puppets, Liberation 540/9240 =  5.8%
    (nothing)                                         54/84    = 64.3%

**Each `elseif` draws again**, so a tick costs one to four draws. `math.mod` is Lua 5.1's
compatibility alias of `fmod`; the original's `lua5.1.dll` has `"mod"` beside `"fmod"` among the math
library's names. `GetAIRand` is never negative, so the remainders are plain. A mobilised country still
spends the 1-in-7 slot and does nothing with it.

**`Laws(minister)`** walks `CLawDataBase.GetGroups()` in storage order - the null group `noLawgroup`
first, then `common/laws.txt`'s seven groups. For each group: a country's `CallLaw_<group>` override if
it has one, else that group's own rule, else "the next law up, if it is in the same group". A proposal
that differs from the current law and whose `ValidFor(tag)` holds is posted as
`CChangeLawCommand(tag, law, group)`, with `SetEnablePostMessage(true)`, through
`CCurrentGameState.Post`.

The script's law numbers are database positions; `GetLaw(0)` is the null law:

| law | index |
| --- | --- |
| `open_society` | 1 |
| `limited_restrictions` | 2 |
| `legalistic_restrictions` | 3 |
| `repression` | 4 |
| `totalitarian_system` | 5 |
| `volunteer_army` .. `service_by_requirement` | 6 .. 10 |
| `full_civilian_economy` .. `total_economic_mobilisation` | 11 .. 15 |
| `minimal` .. `big_education_investment` | 16 .. 19 |
| `consumer_product_orientation`, `mixed_industry`, `heavy_industry_emphasis` | 20 .. 22 |
| `free_press` .. `propaganda_press` | 23 .. 26 |
| `minimal` .. `specialist_training` | 27 .. 30 |

The group rules:

| group | rule |
| --- | --- |
| civil | a democracy at peace: `open_society`; else the next up |
| conscription, economic | the next up |
| education | `big_education_investment` |
| industrial | **at peace, `consumer_product_orientation` for everyone**; at war, heavy if allowed, else mixed |
| press | a democracy at peace: `free_press`; else the next up |
| training | `basic_training`, unless overridden |

Training overrides: GER, FIN and SCH want `specialist_training`; ENG and USA `advanced_training`; CGX,
CHI, CSX, CXB, CYN, MAN, MEN, SIA, SIK and TIB `minimal_training`; SOV `basic_training`, or
`minimal_training` at war with Germany unless it is 1942 or later and it still holds Moscow (province
1409).

The null group falls into the generic branch: `laws[0] + 1` is `open_society`, in another group, so
nothing is proposed. Inferred: this holds only if `laws[0]` is the null-law object and not a null
pointer (E.9).

**`OfficeManagement`** covers posts 3 to 10; the head of state and the head of government are never
touched. A candidate is a pool minister whose ideology's group `==` the ruling party's group
(`CIdeologyGroup ==` compares the group index) and who can take the post. The script's table scores
each candidate's personality in that post, and the **first strict maximum** wins; a personality not in
the table is never chosen. A country's `Call_<post>` override replaces the scoring; none of TFH's
country files has one. The pick is posted only when `GetMinister(pos) ~= picked`, which compares
minister ids, through `ai:Post(CChangeMinisterCommand(tag, minister, pos))`. **Nothing stops one man
taking two posts.**

**`Mobilization`**, only when not mobilised:

1. in a faction whose leader is at war: toggle on, and return;
2. else if `GetStrategy():IsPreparingWar()`: the first real, existing country X with
   `IsPreparingWarWith(X)` and `0.9 x neutrality < GetMaxNeutralityForWarWith(X)` - toggle on, and stop;
3. else a country's `HandleMobilization` override (TFH: FIN, FRA, GER, POL, SCH, SOV, VIC);
4. else, for every neighbour with `0.9 x neutrality - threat < 10`: the threat is multiplied by
   `CalculateAlignmentFactor`, and halved where this country has more than 50 IC and the neighbour less
   IC than it; if it is then over 30 and `CalculateWarDesirability > 70`, a toggle is posted - **once
   per such neighbour, with no break** (E.6).

**`Puppets`** calls a country's `HandlePuppets` (TFH: ITA, which releases ETH through
`CCreateVassalCommand`) when `CanCreatePuppet()` holds. **`Liberation`** posts
`CLiberateCountryCommand(exile, us)` for each `GetPossibleLiberations()` entry that
`IsCapitalSafeToLiberate` passes.

**The base game's own script differs**: its `Laws` and `Mobilization` call `minister:GetCountry()`,
which `CCountry` has no method for, so a new game's `Laws(country)` would fail with a Lua error there
(inferred: a missing luabind method). TFH's `ministerTag:GetCountry()` works with either receiver.

### E.4 What each method answers

| method | answers |
| --- | --- |
| `CCurrentGameState.GetAIRand()` (rva `0x4E9950`) | one MT19937 draw on **the game state's own generator, `+0x124`** - shared with `CAIIntel`, the AI's decision scopes, the hourly trade roll, the wolfpack chooser and `Enable`, and never reseeded hourly as `g_random_seed` is. Range 0 to 2^31-1 (`MT19937Next`'s arithmetic shifts). **No lock**, while ministers tick on TBB workers, so which country gets which draw follows the threads (inferred from the absence of a lock in this body) |
| `CCurrentGameState.Post(cmd)` (rva `0x4E9BB0`) | posts the command's slot-13 **copy** through `in_game_screen` slot 18, then `+0x38` slot 6 |
| `ai:Post(cmd)` (rva `0x49A790`) | the same, through the AI's country's `interface_host` (`+0xF1C`) |
| `CChangeLawCommand(tag, law, group)` | the constructor (rva `0x14EE30`) with **payCost 1, postMessage 1** (thunk rva `0x589BF0`); the constructor keeps both bytes only while `in_game` is set, otherwise 0. `SetEnablePostMessage(b)` is the folded one-instruction setter of `+0x4D` (`SetByte_0x4d`, in 16 classes' tables) |
| `CChangeMinisterCommand(tag, minister, pos)` | `+0x3C` tag, `+0x44` minister, `+0x48` position (rva `0x14E230`) |
| `CToggleMobilizationCommand(tag, b)` | `+0x3C` tag, `+0x44` flag (rva `0x1513F0`) |
| `CLiberateCountryCommand(a, b)` | `+0x3C` a, the liberated; `+0x44` b, the liberator (rva `0x14C8E0`). Which Lua argument lands in which stack slot follows luabind's invoke, which was not read (the thunks are `inferred`) |
| `CLawDataBase.GetGroups()` | the groups (DB `+0x28`), **the null group first**; a Lua loop over it stops at a null pointer (`FINDINGS-luaapi.md` section 4) |
| `CLawDataBase.GetNumberOfLaws()` | 31 in TFH, the null law included |
| `CLawDataBase.GetLaw(i)` | `laws[i]`, unchecked |
| `CLaw:ValidFor(tag)` (rva `0x12A4E0`) | its **`allow` block** (`+0x54`, a `CAndTrigger`) in a scope of that country: FROM `---`, province 0, random state and seed 0. Nothing else is asked |
| `CLaw:GetIndex()`, `GetGroup()`, `GetKey()` | `+0x4C`, `+0x50`, `+0x30` (already recorded) |
| `CLawGroup:GetIndex()`, `GetKey()` | `+0x50`, `+0x18` (already recorded) |
| `CCountry:GetLaw(g)` | `laws[g->index]` |
| `CCountry:GetMinister(p)` | `ministers[p->index]`; a vacant post answers the null minister, not nil |
| `CCountry:GetPossibleMinisters()` | `+0x160`. The registered body (`0xB50630`, `lea eax,[ecx+0x160]`) is a folded getter in no table, so it was left without a record |
| `CCountry:GetRulingIdeology()` | **`+0x1140`**, the ruling party |
| `CCountry:IsMobilized()` | `+0x94` |
| `CCountry:MayLiberateCountries()`, `GetPossibleLiberations()` | E.5 |
| `CCountry:CanCreatePuppet()` (`MayReleaseVassals`, rva `0xEE550`) | `GetPossibleVassals()` not empty - the list already recorded: countries owning nothing, with a core on a non-capital province this country owns and controls, and whose capital this country owns |
| `CGovernmentPositionDataBase.GetGovernmentPositionByIndex(i)` | `positions[i]`, unchecked; 0 is the null position |
| `CMinister:CanTakePosition(p)` | `p` is among his postings |
| `CMinister:GetPersonality(p)` | his type in that post, or the null minister type |
| `CMinister:GetIdeology()` | `+0x6C` |
| `CMinister` `==` | compares ids (`+0xC`) |
| `CAIStrategy:IsPreparingWar()` | some war target owns land or is in exile, and is neither our puppet nor in our real faction |
| `CAIStrategy:IsPreparingWarWith(t)` | `t` is a war target, not already our enemy, owns land and is not in exile |
| `CAIStrategy:IsMilitarist()` | personality `+0x18 == 1` |
| `CDiplomacyStatus:HasNap()` | `+0x28 != 0`, a folded body |

### E.5 Liberation

`GetPossibleLiberations` (rva `0xEDED0`) rebuilds `+0x11E0` from nothing on every call - **the same
list `GetPossibleVassals` fills**, so each call throws the other's answer away. In the game state's
country order it lists every country that is a government in exile, owns at least one province, has its
**capital** (not its acting capital) controlled by us, is not us, and is not our enemy
(`IsEnemy(it, us)`).

`IsCapitalSafeToLiberate(exile)` (rva `0x4A1B20`), C the exile's capital province, answers **false**
when we are at war and an enemy not in exile, owning land and with an acting capital, has that acting
capital on C's continent; or when a province beside C that the exile owns is controlled by a country at
war with the exile. Otherwise true.

`CLiberateCountryCommand::Execute` is already recorded (rva `0x14C980`): the exile's provinces held by
the liberator's faction are handed back; across factions it becomes the liberator's vassal with
relation +500 and joins its faction. Messages: `WE_RETURN_EXILE` ("We have liberated" / "$TITLE$, we
can report that our liberation of $FREE$ has been a major success...") to the liberator's player,
`RETURN_EXILE` otherwise.

### E.6 Mobilisation

`CToggleMobilizationCommand::Execute` (rva `0x151490`, already recorded) first calls
`CCountry_SetMobilised(flag@CL, country@EDX)` (`0x507A20`, rva `0x107A20`):

- not mobilised, mobilise: the timed modifier `initial_mobilization` for
  `(int)(MOBILIZATION_BONUS_DAYS / 1000.0)` days (30 in TFH), and `+0x94 = 1`;
- mobilised, demobilise: the static modifier removed, and `+0x94 = 0`;
- the other two cases: nothing.

**Then, unconditionally**, `RebuildNeighbours`, `0x4E39C0`, and
`SpreadThreat(country, MOBILIZE_THREAT_IMPACT, +-1000, acting capital)`, `MOBILIZE_THREAT_IMPACT` being
2.5 in TFH (5.0 in the base game). So a second toggle posted in the same pass mobilises nothing more but
spreads the threat again.

### E.7 Germany on 1 January 1936 (inference from the files; the laws match the save)

History: `totalitarian_system`, `volunteer_army`, `basic_mobilisation`,
`medium_large_education_investment`, `mixed_industry`, `propaganda_press`, `advanced_training`;
national socialist; neutrality 60 (effective 60 in the save); national unity 90; at peace; in the Axis.
The `neutrality` condition is "at least" effective neutrality, and `national_unity` is "at least"
(`FINDINGS-numtriggers.md`).

**`Laws`, pass 1**, proposes:

- civil: nothing - `totalitarian_system + 1` is in another group;
- `one_year_draft` - allowed through NOT neutrality 65 and unity 60;
- `full_mobilisation` - not a democracy, NOT neutrality 75, unity 60;
- `big_education_investment`;
- **`consumer_product_orientation`** - at peace;
- press: nothing - `propaganda_press + 1` is `minimal_training`, another group;
- `specialist_training` - GER's override.

**Pass 2** adds `two_year_draft` (not a democracy, NOT neutrality 65, unity 70) and `war_economy` (not a
democracy, NOT neutrality 70, unity 60). **Pass 3** adds nothing: `three_year_draft` needs NOT
neutrality 60, and `total_economic_mobilisation` needs war. The start save has exactly this, and so do
the later saves.

**`OfficeManagement`**, were it to run with the pool taken as every minister in
`tfh/common/countries/Germany.txt` whose start date has come and who is not dead (the pool is section
A's), would make the minister of security Goebbels (`man_of_the_people`, 70), the chief of staff
Bayerlein (`logistics_specialist`), the chief of army Blomberg (`guns_and_butter_doctrine`, while he
stays armament minister), the chief of air Siemens (`air_superiority_doctrine`), and the armament
minister Schacht (`administrative_genius`) - or Seldte (`military_entrepreneur`) when short of
resources - and would keep Neurath (`great_compromiser`, Axis), Canaris and Raeder. The saves show no
minister change, which fits Germany being the human player with politics not delegated, so with no
politics minister.

The rest: mobilisation - GER's `HandleMobilization` posts nothing without a NAP with SOV or a
neighbour's threat above 44 (inferred); no `HandlePuppets` for Germany; no exiles to liberate; the
cabinet refill finds every post set by the history (inferred).

### E.8 What looks wrong and is what the bytes do

- Every branch test of `PoliticsMinister_Tick` draws a fresh number, and a mobilised country still
  spends the 1-in-7 slot.
- One `Laws` pass moves a group one step at most; at peace every AI country without an override heads
  for `consumer_product_orientation`.
- A law change made while `in_game` is clear pays nothing and posts no message unless its maker sets the
  byte afterwards, which TFH's script does.
- `OfficeManagement` can put one man in two posts; its `~=` compares ids.
- The cabinet refill never asks the head-of-state candidate whether his block lists the post; a group
  match keeps the **last** candidate, an exact-ideology match the **first**.
- `GetPossibleLiberations` and `GetPossibleVassals` share one list.
- `IsCapitalSafeToLiberate` looks at the exile's real capital, not its acting one.
- The default `Mobilization` branch posts one toggle per qualifying neighbour, and each `Execute`
  spreads `MOBILIZE_THREAT_IMPACT` again.
- `GetAIRand` mutates one generator from several worker threads without a lock.
- The base game's script cannot run the new-game `Laws(country)` call (`GetCountry` on a `CCountry`).

### E.9 What was not settled

- **What runs `Laws()` more than once before the start save**, with command execution between the
  passes. It is not a second call site, and not a loop around `SetUpCountryForNewGame`.
- Whether every country's `laws[0]` is the null-law object; if it were a null pointer, `Laws` would
  error on its first group (the null group) and post nothing.
- luabind's invoke layout - which Lua argument goes to which thunk slot. The command fields are
  consistent with each `Execute`; the luabind thunks are left `inferred` for that reason.
- What the pool `+0x160` holds and when (section A).
- When the posted law commands execute before the first screen; that they do rests on the save.
- What only `CalculateWarDesirability` reaches: `CAI:CanDeclareWar` (`0x89B110`),
  `CAIIntel:CalculateOurMilitaryStrength` (`0x89F8C0`), `CalculateTheirPercievedMilitaryStrengh`
  (`0x89F4B0`), `GetFactor` (`0x89F3A0`). Not read.
- Germany's country id, and so its hour.
- Multiplayer: `CreateMinisters` compares only the local player's id (see `CANDIDATES.md`, *Does only
  the host run the AI in multiplayer?*).
- `CGameState +0xAE4` is recorded as `ai_draws`, "counts what has been drawn". It sits exactly at the
  AI generator's MT index (`+0x124 + 0x9C0`), so it wraps at 624 rather than counting. Left for whoever
  owns that field.

**Corrections made by this section:** `GetRulingIdeology` reads `+0x1140`, where `FINDINGS-luaapi.md`
had `+0xDFC`'s ideology; the politics minister has its own constructor (rva `0x4A1920`), where
`FINDINGS-ai.md` had it inlined; and `FINDINGS-politics.md` section 6 named two databases wrongly -
`0x1A87990` is the government-position database, not the minister one, and the law database keeps its
laws at `+0x18`, `+0x28` being the law groups.

**Frontier (rvas):** `0x5BD30` (the government-position database's constructor), `0x12CD00` (its
installer), `0x129400` (the null law), `0x129920`, `0x12A580` and `0x1299E0` (the law database's
constructor, installer and destructor), `0x128F60` (`CLaw`'s constructor), `0x14ECC0`, `0x152400` and
`0x14DA70` (slot-13 copies of the minister, mobilisation and liberation commands), `0x5C55F0`, and
`0x25A2B0` (`CInGameIdler::Enter`'s caller structure, for the repeated passes).
