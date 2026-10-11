# Leaders: who is put in service, and who is given to which unit

Static reading of `hoi3_tfh.exe` (image base `0x400000`), 2026-10-11, for OpenHOI3's leaders.
**Addresses are rvas**, with the VA in brackets where a listing is quoted. Only valid for this
build. `FINDINGS-leaders.md` is the companion: experience, skill, traits and promotion.

Set against one savegame written two days into an unmodded game (`Germany1936_01_01_00.hoi3`)
and the files that game was started from, by OpenHOI3's `SaveCheck`: **every country's leaders
in service, in order, and every unit's leader agree** - 101 of 101 countries, 3303 of 3303
leaders' rank, experience and traits, and 1555 of 1555 units (65 of the player's, 1490 of
countries the AI runs). The base game's 1936 orders of battle name a leader for **8** units;
the save has **1355** with one. The rest are the rule in section 4.

---

## 1. In short

- **In service at the start: every leader of the country whose rank its history makes more
  than 0 by the start date**, in the order the country keeps its leaders. `confirmed`
- **An order of battle's `leader = N` puts leader N on the unit, whoever he is** - any
  country, any rank, any kind. `confirmed`
- **Every unit left without a leader is then given the best free leader of its own
  country**, in the order the country's units were made, as the game is entered. Not gated
  by `auto_assign_leaders`. `confirmed`, and reproduced unit for unit.
- **"Best" is skill + 1 in thousands, plus a set amount for each of his traits' effects that
  suits the unit**; the first of equals wins. A land unit takes only the exact rank for its
  level. `confirmed`
- **During play** a unit placed, a unit that a brigade joins, and a new headquarters are
  given one the same way, where the country's `auto_assign_leaders` (`CCountry +0x74B`) is
  set. `confirmed` for the gate and the calls.

## 2. In service at the start: `CCountry::ActivateRankedLeaders` (`0xDDCD0`)

`CInGameIdler::Enter`, in its per-country block, calls it at `0x25B276` (`0x65B276`) only when
the session was not loaded from a save (`[0x1A89790] +0xD9C == 0`). The country in `esi`, bare
`ret`:

    for each leader in country->leaders (+0xE10), in order:
        if leader->rank (+0x6C) != 0: append him to country->active_leaders (+0xE00)

The list is a `CList` - first `+0xE00`, last `+0xE04`, count `+0xE08` - not a vector. The rank
is whatever the leader's history has made it by the start date. Experience is the floor of
his skill (`CLeader::PostLoad`, section 9).

**Checked**: folding every leader's `history` to 1936.1.1 and taking those with a rank gives
each of the save's 101 `active_leaders` lists exactly, order included, with every leader's
`rank`, `current_experience` and `trait`s.

`CCountry::AddActiveLeader` (`0xDDB80`, `ret 0xC`: the country, the leader, a flag) is the
other way into the list: it appends, and with the flag set files a `CLeaderChange` dated now in
the country's history (`+0xCCC`, slot 6). Its callers are leader creation (`0x1D6E6A`) and
`0x1EF1B2`, not read. `CCountry::RemoveActiveLeader` (`0xDDCA0`: the country in `eax`, the
leader in `edx`, bare `ret`) unlinks one.

## 3. The order of battle's `leader`

`CUnit::LoadKey`, the `leader` case (token `0x268`, from `0x1B7747`): where the value is a plain
number (`type == 0xC`) it is `atoi`ed and looked up as the persistent `{id = N, type = 0x25}` -
the same pair a save writes a leader under - **across the whole game**, and the unit's leader is
set with `CUnit::SetLeader(leader, 0, 0)`. Nothing compares his country, his rank or his kind
with the unit's. A block value (a save's `{ id type }`) goes through `ParseObjectReference`
to the same setter. An unknown number jumps to `0x1B7F4E`, not read.

## 4. The start's assignment

`CInGameIdler::Enter`, the loop over a country's units at `0x25B661` - the one that adds up
the country's officers (`FINDINGS-unitstart.md`, section 7) - ends each unit with

    0x65B71D  ecx = unit->leader (+0x12C)
              call [vftable + 0x20]             slot 8: "is a real leader"
              jne  next
    0x65B732  edi = unit
    0x65B736  call 0x5CD5B0                     CUnit::AssignBestLeader

so every unit that holds the null leader is given one, **in the order of `country->Units`
(`+0xBAC`)** - the order the units were made, which is the order of their numbers. It is
inside the same new-game branch as the order of battle's loading, after it, and **it does not
look at `auto_assign_leaders`**.

## 5. `CUnit::AssignBestLeader` (`0x1CD5B0`)

The unit in `edi`, nothing on the stack, bare `ret`. Over the unit's country's
`active_leaders`, in order:

    skip a leader with a unit (+0x40)
    skip him unless MayTakeLeader(unit, him, onlyFree = 1)            section 6
    score = (skill + 1) * 1000
    if the unit is not land and CommandSize(him, unit) < its brigade count (+0x40):
        score = score * 1000 / 100000                                   a hundredth
    for each trait (+0x30), for each of its effects (count +0x2A8, kinds +0xA8):
        score += what the kind is worth to this unit (table below)
    if score > best: best = score, chosen = him                        strictly greater
    then, if anyone was chosen: CUnit::SetLeader(unit, chosen, 0, 0)

`best` starts at 0, so anybody eligible is chosen over nobody, and **of two equal scores the
first in `active_leaders` keeps it**. The effect's own figure is never read.

The kinds, from the byte table at `0x1CD8FC` over `kind - 3` and the arms at `0x1CD8C4`
(kinds numbered as `FINDINGS-combatmods.md` settles them). "The unit's" figures are its own
definition (`CUnit +0xC8`, `FINDINGS-unitdef.md`): sums, the slowest brigade's speed, and the
mean adjusters.

| kind | adds | when |
| --- | --- | --- |
| 3 `defence_modifier` | 10000 | the unit's `max_speed` (`+0x108`) under 3.000 |
| 4 `offence_modifier`, 5 `combat_move_speed` | 10000 | its `max_speed` over 4.000, or else `base_ca_bonus` (`CUnit +0x1CC`) over 50 (`floorf(50.5f)`, the float at `0x120A7B4`) |
| 7 `river_attack` | 20000 | its river adjuster's attack (`+0x9C`) above 0 |
| 8 `fort_attack` | 20000 | its fort adjuster's attack (`+0x84`) above 0 |
| 9 `combined_arms_bonus` | 50000 | `base_ca_bonus` above 0 |
| 11 `submarine_attack` | 20000 | it has brigades and the first one's definition is a submarine (`+0x31`) |
| 15 `defender_softness` | 5000 | its `soft_attack` (`+0x134`) above its `hard_attack` (`+0x138`) |
| 16 `strategic_attack` | 10000 | its `strategic_attack` (`+0x17C`) above its `air_attack` (`+0x140`) |
| 17 `naval_attack` | 10000 | its `sea_attack` (`+0x168`) above its `air_attack` |
| 19 `tactical_attack` | 10000 | `soft_attack + hard_attack` above `air_attack` |
| 25 `amph_attack` | 20000 | its amphibious adjuster's attack (`+0xB4`) above 0 |
| 27 `paradrop_mission` | 50000 | the definition's `can_paradrop` byte (`+0x38`) - **never set**, below |
| every other kind | nothing | |

Every comparison is signed.

**`paradrop_mission` never counts.** The byte is read off the unit's own definition, and
nothing writes it there: `CUnit::RebuildDefinition` resets the definition by copying the
all-zero `---` entry, `CSubUnitDefinition::Add` (`0x1A7FC0`) starts at `+0xEC` and adds the
three adjuster blocks (`+0x6C`..`+0xBC`) and nothing in the flag bytes, and `Divide`
(`0x1A83B0`) touches none of them either. So a paratroopers' general is chosen on his skill
alone. Read off the three functions, not watched.

**`defence_modifier` suits almost nothing.** Under 3.000 is slower than every brigade of the
base game but `garrison_brigade` (1.00); militia is exactly 3.00 and does not count. So it
suits a unit with a garrison brigade in it.

## 6. Who may take a unit: `0x1BFB30` and `CUnit::MayTakeLeader` (`0x1BFBA0`)

`0x1BFB30`, the leader in `eax`, the unit in `edi`, a flag on the stack, `ret 4`:

    rank (+0x6C) == 0                         -> no
    the unit is land (slot 15) and type (+0x68) != 0  -> no
    the unit is naval (slot 16) and type != 1         -> no
    the unit is air (slot 17) and type != 2           -> no
    flag, and he has a unit, and it is not this one   -> no
    otherwise yes

`CUnit::MayTakeLeader` (`0x1BFBA0`), the unit in `ecx`, the leader in `esi`, the flag in `al`
(pushed as the stack argument above), bare `ret`, answers in `al`: no where `0x1BFB30` says
no; for a land unit, by `oob_level` (`+0x1F4`):

| level | wants |
| --- | --- |
| 4, a division | rank exactly 1, and `CUnit::GetCounterSize` not 0 - **more than one brigade** |
| 3, a corps | rank exactly 2 |
| 2, an army | rank exactly 3 |
| 1, an army group | rank exactly 4 |
| 0, a theatre | rank exactly 4 |

and a fleet or an air unit any rank. **A division of one brigade can never be given a leader
this way**, and nothing above it takes a leader of a different rank.

## 7. Rank enough to count: `CUnit::LeaderHasRankForCommand` and `0x1CD920`

What the unit panel writes a leader's name in red for, and what gates `BM_LEADER_BONUS`, is
looser than the choosing above: `CUnit::LeaderHasRankForCommand` (`0x1CD960`) by `oob_level` -
0 and 1 rank above 2, 2 above 1, 3 above 0, 4 and 7 always, 5 and 6 (fleet, air) asking
`0x1CD920`. That one (`CUnit::LeaderCommandsEnough`: the unit in `eax`, the leader on the stack,
`ret 4`, answers in `al`) is yes for a land unit, and otherwise yes where
`CLeader::CommandSize(leader, unit)` is at least the unit's brigade count.

**`CLeader::CommandSize` (`0x1800A0`)**, the leader in `eax`, the unit in `esi`, bare `ret`:
for a naval unit `NAVAL_RANK_2`, `_3` or `_4` by rank and `NAVAL_RANK_1` for any other rank, and
for an air unit `AIR_RANK_1`..`_4` the same way, each over 1000 - a whole number of ships or
wings. 0 for a land unit. Their Finest Hour: 6, 12, 18, 30 ships and 4, 8, 12, 16 wings.

## 8. During play, and the AI

`CUnit::AssignBestLeader` has nine callers. Where read, each is gated by the country's
**`auto_assign_leaders` (`CCountry +0x74B`)** - the byte `CCountry::SaveContents` writes under
that key (`movzx eax, byte [edi+0x74B]; mov ecx, 0x5A5; call SaveWriteBool` at `0xD12B6`), and
which the save has `yes` for all 101 countries:

| caller | when |
| --- | --- |
| `CInGameIdler::Enter` (`0x25B736`) | section 4; **not gated** |
| `CUnitDeployment::DeployAt` (`0x17DD73`) | a finished unit put on the map: the unit placed |
| `CUnitDeployment::JoinUnit` (`0x107024`) | below |
| `CCreateHigherCommand::Execute` (`0x1DFE71`) | the new headquarters |
| `0x1EB620` (`0x1EB6FC`) | a brigade added to a unit: the unit, where it is not land or has more than one brigade, and has no leader |
| `CTransferSubUnitCommand::Execute` (at `0x1DCD77`), `0x1DB9E0`, `0x1E0BB0`, `0x1BE20` | not read |

**`JoinUnit`**: the unit is placed first (slot 9, `DeployAt` - which gives it a leader); then a
unit of one brigade of the target's service gives its brigade to the target, the target is given
the best free leader **if it has none**, and only then is the emptied unit removed
(`CGameState::RemoveUnit`, which takes its leader off). So the joining unit's leader, if it got
one, is not free for the target. A unit that goes under the target instead gives the target
nothing.

**The AI** has a reshuffle of its own, `AI_ReassignLeaders` (`0x498EF0`, VA `0x898EF0`),
called once from `ProcessAI` (`0x4894E0`, at `0x489AD6`), one argument, `ret 4`: it
scores each of the country's units into a float at `CUnit +0x2C0` (`0x499500`), compares each
free leader's fit against the one in place, and posts a `CAssignLeaderCommand(unit, leader, 1)`
for each improvement. Read for its shape only. **The save's units all agree with section 4
alone**, so whatever it did in the first two days moved nobody the save shows - the 31 leaders
the AI's own new theatres hold apart.

## 9. `CUnit::SetLeader`'s two flags, and skill on load

`CUnit::SetLeader` (`0x1BFC10`) was recorded with its two trailing ints unexplained. Read whole:

    if the new leader is not the unit's:
        the old leader (if real): his unit's leader set to null, his unit cleared
        the new leader (if real): whatever he commanded set to null; his unit = this
        flag a, and he is real: his CTraitGainTracker's duration = 0, current = -1
        flag b, and he is real, and no custom game setting (GetCustomGameSettings()[0] == 0):
            every brigade's organisation *= NEW_LEADER_ORG_HIT / 1000, not below 0
        unit->leader = new
    then the counter's name: "???" under intelligence 5, else the leader's name, else ""
        (all of it skipped with the game setting at +0xE9)

So **a** throws away the hours the leader had banked towards a gainable trait, and **b** is
the organisation a unit loses on being given a new commander. The start and the automatic
choice pass `(0, 0)`; `CAssignLeaderCommand::Execute` passes `(1, 1)`.

**Skill on load** (`CLeader::PostLoad`, `0x17FF60`): the floor of skill `s` is the int at VA
`0x170AEE0 + 4s` - 0, 1000, 2000, 4000, 8000, 12000, 18000, 25000, 33000, 43000, 60000,
100000000 for 0 to 11 (so `g_LeaderSkillThresholds` at `0x130AEE4` is the same table from
skill 1) - and skill is raised while the experience is **strictly above** the next one
(`jle` out on equal). A history's `skill = 2` therefore loads as 2000 experience, which is
what the save's `current_experience=2000.00000` shows on every skill-2 leader.

## Not established

- `0x1B7F4E`, what an order of battle naming an unknown leader does.
- The other four callers of `CUnit::AssignBestLeader` in section 8.
- `AI_ReassignLeaders`'s scoring (`0x499500`) and when `ProcessAI` runs it.
- `CContainer::AddEntry`'s order for a leader's history - whether "the first `rank` entry" of
  the daily activation is the earliest dated or the first written. In the base game the two
  are the same for every leader (9313 read), so it does not show.
- Nothing here was watched in a running game.
