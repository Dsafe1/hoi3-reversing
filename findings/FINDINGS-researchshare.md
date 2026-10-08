# The research share: how leadership reaches the queue, and the arithmetic to the bit

Static reading of `hoi3_tfh.exe`, image base `0x400000`, on 2026-10-08. Addresses are given
as `VA / rva`. The game was not running. Written because the rewrite's research spec needed
the one function `FINDINGS-research.md` and `FINDINGS-production.md` both leave unread -
`CDistributeResearch::Distribute` - and the exact order of every multiply and divide in the
three it leans on, since a technology's progress is the sum of hundreds of days of them.

Where savegames are quoted they are four of one vanilla Their Finest Hour game, written on
1 February, 1 March, 1 April and 20 April 1936, and the figure is marked **measured**.

**What this settles that was open or wrong:**

- `CDistributeResearch::Distribute` is read, and is `confirmed` where it was `inferred`.
- **`CTechnology::CheckResearchAllowed` answers true when the level may be researched.** Its
  polarity was recorded as unresolved, with a note that both use sites "branch past the
  research when it answers true". They do not: section 1.
- **`FixedPointSqrt` is evaluated, and it is a much rougher root than its shape suggests.**
  Its stopping test compares the error with the *number itself*, so it runs one or two steps.
  Section 4.
- `0x4E02F0`, quoted in three write-ups by address, is named and entered: section 5.

## 1. `CDistributeResearch::Distribute` - `0x51F620 / 0x11F620`

Slot 0, `this` in `ecx`, `ret 0x10` at `0x520EDE`: 0x18C1 bytes, of which about 0x1300 are
the `tech_discovered` message. Decoded from its own entry.

    remaining = ((base_percentage * available) >> 15 * factor) >> 15          ; fixed 15, 64-bit
    status    = country->technology_status (+0xDF8)
    CTechnologyStatus::ClearResearchLeadership(status)                        ; 0x51F6BA
    for each node of country->CurrentResearch (+0x638; technology at +0, next at +8):
        if (remaining <= 0) break                                             ; 0x51F6DD
        level = status->level_by_technology[technology->index] + 1
        if (!technology->CheckResearchAllowed(country tag, level))            ; 0x51F721
            AdvanceResearch(status, technology, 0)                            ; 0x51F73F
            continue
        give = min(remaining, 1.0)                                            ; 0x8000, 0x51F74B
        remaining -= give
        leadership = (give * (1000 << 15)) >> 30                              ; thousandths, 0x51F9BA
        if (AdvanceResearch(status, technology, leadership))                  ; 0x51F9DB
            CCountry::GainTechAbility(country, technology->on_completion (+0x28C), 1000)   ; 0x51FA04
            ... the message, for the player's own country ...
            remove the technology's node from CurrentResearch                 ; 0x520D76
            if (technology->additional_offset (+0x2C0) != 0)
                append it to a local list of finished technologies
    for each technology in the finished list:                                 ; 0x520E10
        if (technology->CheckResearchAllowed(country tag, -1))
            append it to the END of CurrentResearch                           ; +0x63C, count at +0x640
        0x8A3040(country)
    *out = 0

So, for a modder:

- **Every project in the queue takes one point of leadership, in queue order, until the
  research share's leadership runs out.** The last one reached takes the remainder; anything
  after it gets nothing that day. There is no splitting and no priority beyond order.
- **A technology whose next level is not allowed stays in the queue and takes no
  leadership.** It is handed zero, which makes no progress.
- **A finished level's leftover progress is kept** (`AdvanceResearch`,
  `FINDINGS-research.md` section 4), **the technology is taken off the queue, and - if it has
  more levels and the next is allowed - it is put back at the end**, after every other
  project has had its day. A single-level technology is simply removed.
- **Finishing a level raises the `on_completion` category by one point**, scaled as section 5
  says.

The message block is entered through `gamestate->+0xC34 == country id`, which is the test for
the player's own country; inside it the function also lists, before the level is gained,
every technology the country could *not* research, so that it can name the ones the new level
unlocked (`ENABLE_TECH`). None of that changes the game state.

(measured) On 1 February Germany has 0.97 of 29.687 leadership on research - 28.796 - and 29
projects: 28 show `1.000` assigned in the save and the last shows `0.796`. Between 1 and
20 April its `at_barrell_sights` finishes level 2, keeps `0.00439`, and is the last of the
save's `research` entries.

### The polarity of `CheckResearchAllowed`

`0x535760 / 0x135760`, read through. It answers **1 when the level may be researched**:

    if (level == -1) level = the country's level + 1
    if (additional_offset == 0 && (level > 1 || level < 0)) return 0          ; single-level
    if (level > max_level (+0x2C4)) return 0
    if (custom game settings are on and give this technology a ceiling above level) return 0
    return allow->Evaluate(scope of the country) == 1                         ; [this+0x248] slot 6

and in `Distribute` the `test al, al; jne 0x51f749` at `0x51F726` takes the **allowed** case
on to `0x51F749`, where the leadership is given. The fall-through, for a zero answer, is the
`AdvanceResearch(..., 0)` at `0x51F73F`. The earlier note read that fall-through as the
research.

## 2. `GetResearchGain`, in the order the bytes do it - `0x532C20 / 0x132C20`

`FINDINGS-research.md` has the formula. The arithmetic, all signed and every divide
`__alldiv` or `idiv` and so truncating toward zero:

    cost      = GetResearchCost(status, technology)                           ; thousandths
    cost15    = (cost << 30) / (1000 << 15)                                   ; to fixed 15
    if (cost15 <= 0) return 0
    penalty   = early > 0 ? (early * 1000) * TECHNOLOGY_YEAR_IMPACT / 1000 + 1000 : 1000
    eff       = max(1000 + countryValues[RESEARCH_EFFICIENCY] + status->research_efficiency, 100)
    gain      = eff * leadership / 1000
    gain      = penalty == 0 ? -1 : gain * 1000 / penalty
    gain15    = (gain << 30) / (1000 << 15)
    return (gain15 << 15) / cost15                                            ; fixed 15

`early` is the due year less the calendar year, `(tick - 43800000) / 24 / 365.0` truncated.
**Two truncations to fixed 15 happen before the final divide**, one of the gain and one of the
cost, and they are what the last digit of a month's progress depends on.

## 3. `GetResearchCost` and the category term - `0x5333F0`, `0x5332B0`

    base  = ((difficulty * 1000) * 100 / 1000 + 1000) * 125000 / 1000         ; 0x533403..0x533440
    bonus = 0
    for each node of research_bonus_from:
        bonus += GetCategoryResearchAbility(category) * weight / 1000         ; each truncated
    if (is_nuclear) bonus += countryValues[NUKE_RESEARCH]                     ; id 96, +0x300
    if (bonus > 900) bonus = 900
    cost  = base * (1000 - bonus) / 1000

    ability term:
    a = clamp(max(own level, the sharer's), 0, 20000) - 5000
    if (a > 1000) a = FixedPointSqrt(a)                                       ; skipped when negative
    return a * 100 / 1000

The `100` in both is `floorf(100.5f)` - the same float at `0x160A684` - once cached in the
global `0x1A87BB4` and once computed on entry.

## 4. `FixedPointSqrt`, evaluated - `0xA9CEC0 / 0x69CEC0`

`cdecl`, `(int* out, int value)`, thousandths, ends at the bare `ret` at `0xA9CFFE`:

    if (value <= 0) { *out = 0; return }
    guess = value * 1000 / 2000
    tolerance = value * 1000 / 1000                                           ; so: value
    do
        error = guess * guess / 1000 - value
        twice = guess * 2000 / 1000
        guess -= twice == 0 ? -1 : error * 1000 / twice
    while (error > tolerance || error < -tolerance)
    *out = guess

**The tolerance is the number itself.** `0xA9CF2C..0xA9CF49` multiplies `value` by 1000 and
divides by 1000 - a fixed-point multiply by `1.000` - and that is what the two compares at
`0xA9CFDA` and `0xA9CFE8` test the *previous* error against. So the loop ends as soon as the
square of the guess is within `value` of `value`, which is after one step for anything up to
about 8 and two above that:

| value | answer | true root |
| --- | --- | --- |
| 1.001 | 1.251 | 1.0005 |
| 2.5 | 1.625 | 1.581 |
| 5 | 2.25 | 2.236 |
| 10 | 3.179 | 3.162 |
| 15 | 3.954 | 3.873 |

Whether a tolerance of `0.001` was meant is not something the bytes say. It is what the game
does: an ability of 10 is worth 0.225 of weight, not 0.2236. (measured: with a true square
root in its place, ten of the 375 technologies that fit the savegames in section 6 stop
fitting - the ones whose categories are above 6.)

## 5. `CCountry::GainTechAbility` - `0x4E02F0 / 0xE02F0`

Three stack arguments, nothing in `ecx`, `ret 0xC` at `0x4E03AF`, `int3` after:

    ability = country->category_levels (+0x698)[category->index (+0x5C)]
    divisor = defines->country (+0xCC)->TECH_ABILITY_GAIN_DIVISOR (+0x48)
    scale   = divisor == 0 ? -1 : ability * 1000 / divisor
    if (scale < 1000) scale = 1000
    CCountry::SetTechAbility(country, category, ability + gain * 1000 / scale)

So **a gain counts in full while the ability is under `TECH_ABILITY_GAIN_DIVISOR`, and is
divided by `ability / divisor` above it**: at an ability of 20 with the divisor at 10, a point
is half a point. `SetTechAbility` then floors at 0 and caps at `MAX_TECH_ABILITY`.

Seven callers: `0x51FA04` here, with a gain of 1000; `0x484EE7` and `0x485C90` in the
construction classes, which is the practical a finished unit earns
(`FINDINGS-production.md`); `0x41FFA1`, `0x420157` and `0x42044A` in the start-of-game
recompute (`FINDINGS-research.md`, section 3); and `0x5654D7`, not read.

## 6. What the savegames say

**measured.** The rewrite's check tool gives each country the laws, government, technology
levels and abilities one save has, works out one day's gain for each technology that save
shows leadership on, and compares that times the days between with the next save's progress,
as the five decimals the save prints.

- **1 April to 20 April, 19 days: 375 of 376 technologies agree to the last digit.** The one
  that does not is Australia's, which moved about three quarters as far as a full nineteen
  days would take it; why was not followed.
- **1 February to 1 March, 28 days: 156 of 158. 1 March to 1 April, 31 days: 127 of 131.**
  The misses are countries whose queue or shares the AI moved in between.
- That is with one thing given by hand: **`triggered_modifiers.txt`'s `neutrality`, which
  takes 5% off the research efficiency of every country in none of the three factions.**
  Without it only the factions' members fit - Germany, the United Kingdom, France, the Soviet
  Union and their allies - and the other ninety are all 5% high. So triggered modifiers reach
  the country's modifier, as `FINDINGS-leadership.md` section 11 found from leadership.
- **The monthly decay** (`FINDINGS-techdecay.md`) agrees to the thousandth for 933 of 983
  abilities over the first month and 911 of 1084 over the second, taking the slack from the
  later save's shares. The misses are whole countries at a time - the Soviet Union, France -
  whose sliders the AI moved in the hour between the decay and the save.
- **A country's starting abilities are its history file's**, exactly: 1316 of 1316 in the
  1 January save.

## What is not established

- **`0x8A3040`**, called with the country for each finished technology after the queue has
  been walked. By its position it tells something that the queue changed.
- **The custom-game ceiling** in `CheckResearchAllowed` (`0x41F500`, its `+0x28`): which way
  the comparison cuts was read, what fills the table was not.
- **The triggers a technology's `allow` block is made of.** The base game's use six -
  a technology's level, a category's level, `num_of_ports`, `any_owned_province` with
  `has_building`, and `OR`/`AND` - and none of their evaluators was read here.
- **`0x5654D7`**, the seventh caller of `GainTechAbility`.

## In the record

Entered the same day through `fragments/merged/researchshare.json`:
`CDistributeResearch::Distribute` revised from `inferred` to `confirmed`,
`CTechnology::CheckResearchAllowed` and `FixedPointSqrt` revised from `likely` to `confirmed`
with the corrections above, and `CCountry::GainTechAbility` (`0xE02F0`) new. Applied headless
to a copy of the Ghidra project: `failed: 0`, and `struct fields: 0` on the second run.
