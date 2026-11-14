# A new game against the start save: its shares, its laws' timing, a minister's type, its history's decisions

Static reading of `hoi3_tfh.exe`, image base `0x400000`, on 2026-11-14, by the OpenHOI3 agent `startsave`. Addresses are
VAs, with the rva where an entry is made. The game was not running, so the one claim resting on where a queue is drained
is `inferred`. Measured figures are against `Germany1936_01_01_00.hoi3` (Their Finest Hour, no mods) through
`OpenHOI3.SaveCheck` (the start-date run, `firstdays`, `politics`, `diplomacy`).

Written because OpenHOI3's readme carried two Loose ends about the start save: four unexplained figures (home production
for three countries, governments for countries that do not exist, the shares of IC at the start, nine untouched countries
making 10% more supplies than their laws give) and six countries' build-queue lines starting somewhere else. Canada's and
Australia's metal, the governments and the queue lines were already answered by earlier work (the capital's area, the
filling of empty posts, the engine's new-game pass in `FINDINGS-starttech.md`).

## 1. The shares of IC at a new game - `Enter_SetNewGameShares` (VA `0x65B505`, rva `0x25B505`)

`confirmed`. Nothing in `SetUpCountryForNewGame` (`0x4D6230`) writes a share: its decompile has neither `+0x5F4` nor
`GetConsumerGoodsNeeded`. `findRefs --callers 0x4FA020` gives four callers: `0x518FBA`, `0x519044` and `0x51926F` in
`CDistributeConsumerGoods`, and **`0x65B505` in `CInGameIdler::Enter`'s new-game block**:

    0x65B4E6  SetUpCountryLawsAndTechnologyForNewGame(country)
    0x65B4EC  CCountry::LoadOobFile(country)
    0x65B4F2  SetUpCountryForNewGame(country)
    0x65B4F7  CCountry::RecountUnitTotals                      ; land_brigades_in_service (+0x108C)
    0x65B505  demand = GetConsumerGoodsNeeded(country)         ; thousandths
              cg   = (demand << 30) / 0x1F40000                 ; thousandths -> 48.15, truncated
              rest = ((0x8000 - cg) << 15) / 0x28000            ; a fifth of the rest, truncated
              for i in 0..5: ProductionDistribution[i]->base_percentage = rest  ; slot 4 where changed
              ProductionDistribution[1]->base_percentage = cg                   ; consumer goods
    0x65B651  the officers the units come with
    0x65B749  the build queue's lines priced and started

So each of the six is first set to a fifth of what consumer goods leave, then consumer goods to the demand. The demand is
the one at that moment: under the laws the engine's pass brought forward (the Lua's posts have not run, section 2), with
the standing-army term (`0x4F9F10`) over the units just read, and without the ministers the set-up's
`CCountry_FillMinisterPosts(country, 0, 0)` adds (measured, not read).

Measured: all 24 countries nothing has moved (the 23 that do not exist, and Germany) have exactly these shares.

- Germany: war economy and mixed industry give 0.200; 33 brigades on 201 IC at neutrality 60 add 0.024 (33000/201 =
  164; x 250/1000 = 41; x 600/1000 = 24). The result is 0.22400 and five of 0.15518.
- East Germany: 0.09998 and five of 0.17999.
- Counting the filled ministers would leave seven short by 0.02 or 0.025 each: VIC, DDR, RSI, LEB, SYR, MEN, GUY
  (`laissez_faires_capitalist` / `political_protege` -0.025, `happy_amateur` -0.02).

This answers `FINDINGS-distribute.md`'s "what sets a country's shares at the start" and its note that the standing-army
term was not seen working. Its 0.252 used the save's laws, which the Lua changed after the days.

## 2. When a new game's Lua changes of law take effect - `SetUpCountryForNewGame_CallLaws` (VA `0x4D734B`, rva `0xD734B`)

`inferred` (likely). `SetUpCountryForNewGame` calls `Laws(country)` at `0x4D734B`..`0x4D7375`. Its `CChangeLawCommand`s
go through `CCurrentGameState.Post` (rva `0x4E9BB0`): the command's copy, through `in_game_screen` slot 18, to the queue
at `+0x38` slot 6. That is the route every command takes, the hourly tick's included (`FINDINGS-tick.md`, *The clock*),
and the drain asks `IsValid` again before `Execute`. `Enter` runs the two first days itself (`0x65CB2E`, `0x65CC64`),
after the per-country loop that holds `0x65B4F2`. So unless the post executes at once while `in_game` is clear, the
changes run after the two days, when the session first drains its queue, and before the first hourly tick. The drain
loop was not traced.

The save fits this and nothing else tried:

- **Supplies.** 16 of the 23 untouched countries (GER ICL VIC CRO DDR DFR SLO RSI SPA JOR PAL PAK KOR MEN IDC EGY) made
  their last day's supplies under mixed industry, 10% more than the consumer goods orientation the save shows - the
  Lua's "at peace" choice.
- **Organisation.** 74 countries' brigades are held to the running game's ceilings, which only a change of law after
  the days does: Germany's reserves at 28.000, its regulars at their figure.
- **Manpower.** The pool is `max_manpower`, set after `Laws` in the same function; Germany's 882 is the two-year
  draft's, which the engine's pass gave it.

Built so in OpenHOI3: organisation 962 to 3,792 of 3,792, dissent 85 to 101 of 101, national unity 101 of 101,
alignment 80 to 100 of 101, and the 86 theatre headquarters' brigades the save's in experience and organisation.

A live probe would settle it: a logging breakpoint on `CChangeLawCommand::Execute` (VA `0x54EF60`) while a new game is
entered, read against the tick counter (`+0xBDC`) and whether `RunDailyPass` has been hit. The same breakpoint counts
how often `Laws()` runs for a country (`FINDINGS-government.md` E.9).

## 3. A minister's type in a post is the first his block gives - `CMinister_LoadKey_AppendPosting` (VA `0x52C844`, rva `0x12C844`)

`confirmed`. `CMinister::LoadKey` appends each `post = type` line as a 0x14-byte node {position, type, prev, next, byte}
at the **tail** of the postings list (`+0x5C` head, `+0x60` tail, `+0x64` count): `0x52C828`..`0x52C833` fill the node
with prev = the old tail, `0x52C844` / `0x52C847` make it the tail and count it, `0x52C852` links the old tail's next to
it, and `0x52C86C` sets the head where the list was empty. `CMinister::GetPersonality` (`0x52CBE0`) walks from the head
and returns the first match, so a second line for the same post is never used.

Measured: Honduras's 79004 is `laissez_faires_capitalist`, then `resource_industrialist`. The save's energy is 17.500
(10 + 10 x 0.75 under basic mobilisation); the second type would give 18.000. That the country's modifier finds the type
the same way is inferred from this figure: taking the last, or applying both, gives 18.000. Brazil's starting manpower
also fits only with first types. The base game repeats a post 270 times, 71 of them with a different type (Germany's
111, `prince_of_terror` then `efficient_sociopath`). **Fault: the second line is dropped silently.**

## 4. The decisions a history has taken (the record's reading, gathered)

`confirmed` by the record's comment on `SetUpCountryForNewGame` (VA `0x4D6342`..`0x4D668A`). After `UpdateIC(country,
0)` it builds one `CEventScope` - this country, FROM `---`, province 0, the random state, copy and seed 0 - and walks the
taken list (`+0x128`): the history's `decision = <name>` lines, less any `remove_decision`, through
`CCountryDecisionChange::Apply`.

- Each name is looked up in the political table first, then the diplomatic.
- An unknown name logs `<TAG> has unknown decision '<name>'`.
- A known one has its effect run (`CEffect::Execute`, slot 11, with (scope, 0)).
- No `potential` or `allow` is asked, no message raised, no history entry made, and the random state is not reset
  between decisions.

Measured: the United States' history takes `new_deal` on 1936.1.1, the only history decision dated by the start. The
save has the flag `nd`, the modifier `us_new_deal` and manpower 254.936 (its most less 40%).

## 5. Built from the record alone

`SetUpCountryForNewGame`'s stockpile amount is held to 1000 for a subject (`+0xF34`). OpenHOI3's spec had this,
measured on Manchukuo (1000 / 500 / 2.5 in place of 1890 / 945 / 4.725), but its code did not.

## What was not settled

- Where the session drains the command queue, read off the bytes.
- What runs `Laws()` more than once (`FINDINGS-government.md` E.9).
- Whether `CCountry_FillMinisterPosts`'s `CChangeMinisterCommand`s ("on the country's channel") also wait on the queue:
  the shares and Brazil say the filled ministers are absent at set-up; the money and officers of countries that do not
  exist count them over the two days.
- When the AI production minister first sets the shares of AI countries (before hour 0, by the save).

Index: `findRefs --callers 0x4FA020`; `disasm.py 0x65B4D4`, `0x52C80A`, `0x52CBE0`, `0x4D7346`; the decompile of
`0x4D6230`. Fragment: `fragments/merged/startsave-shares-laws.json`.
