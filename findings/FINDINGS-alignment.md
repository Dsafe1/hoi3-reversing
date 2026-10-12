# The alignment triangle: where a country starts and how it drifts

Read out of the executable on 2026-10-12 for OpenHOI3's threat, whose two spreaders scale by an
ideology factor between alignments (`FINDINGS-diplostate.md`, B). One brief (G) of the Lua slice's
wave. It builds on `FINDINGS-politics.md` sections 1 to 3 - the classes, the three distance functions
and the seven terms - and does not redo them. Addresses are **virtual**, based `0x400000`, unless a
line says rva. Figures are thousandths unless a line says otherwise, and every division truncates
toward nought (64-bit `__alldiv`) unless it says otherwise.

## In one line

A country starts at its history's `alignment = { x y }`, unclamped (REB, with none, at (0,0)); **on
the new game's first day every country takes one drift step**, the schedule's field starting at the
null date - a faction's leader stays, a member is put on its leader, an unaligned country moves - and
that reproduces the start save's position for **93 countries of 101 to the thousandth**. The step
comes every **`ALIGNMENT_INTERVAL` + 1 days** (25), the schedule is not saved, the move is clamped to
the **triangle** (with a sign slip on one arm), the two unread globals are **0.1** and **0.25**, and
**revanchism weighs 5 x (1 - s) per core**, not 5 x (0.5 - s).

## 1. The mechanics, in order

### 1.1 The corners and the gates

Their Finest Hour's `common/ideologies.txt` (no `tfh` copy) has three groups, taken in file order:
fascism (200, 200), faction `axis`; democracy (0, -146), `allies`; communism (-200, 200),
`comintern`. **A group's slot 6 and an ideology's slot 17 are "is it real"**: `ReturnTrue` (rva
`0x692590`) on `CIdeologyGroup` and `CIdeology`, `ReturnFalse` (rva `0x192360`) on
`CNullIdeologyGroup` and `CNullIdeology`, and `CFaction` slot 7 the same. So all three groups always
count, and a country whose ruling ideology is the null one gets no ideology term and no repulsion IC
factor.

### 1.2 The triangle (`CAlignment::RebuildBounds`, rva `0xC46C0`, built once)

The bounds start as a zero box at (0, 0) - the constructor zeroed them - and grow to take in every
group's position: min x `+0x28`, min y `+0x2C`, width `+0x30`, height `+0x34`;
`mid = minX + width - width x 1000 / 2000`; left slope (`+0x3C`) `= -height x 1000 / (mid - minX)`,
right slope (`+0x38`) `= -height x 1000 / (mid - maxX)` (-1 for a zero divisor); the apex's y
(`+0x40` = `+0x44`) is min y. Their Finest Hour gives the box -200..200 by -146..200, slopes -1730 and
+1730, the apex (0, -146): **the apex at the bottom middle, the two upper corners at the top**.

### 1.3 Where a country starts in a new game

1. `CAlignment::CAlignment` (rva `0xC3050`, from `CCountry::CCountry`, at country + `0xDC`) puts it
   at (0, 0).
2. The history's `alignment = { x = X y = Y }` - undated, in `history/countries`, `tfh` over the
   root by file name - becomes a `CAlignmentPosition` (rva `0x1F0B40`, `0x20` bytes), whose `Apply`
   (slot 7, rva `0x1F0BA0`) sets the position through `CCountry::SetAlignmentCord` (rva `0xF6CE0`)
   **with no clamp**. 100 of the start's 101 countries have one; REB has none and stays at (0, 0).
3. A faction's first member is its leader; the history's joins only append.
4. **The new game's first day** - the first of the two days run before the first hour - reaches the
   alignment phase of the country's daily pass with `CCountry +0x124` still the constructor's null
   date, so **every country takes one step** (1.5).
5. The second day: the clock has not moved, `today` is not greater than `today + 24 x 24`, no step.

Nothing else writes the position in a game started here: the writers are the history's `Apply`,
`UpdateDaily`, `CAlignment::LoadKey` and the custom game's `CCgmAlignmentChangeCommand::Execute`
(rva `0x29B50`, which also clamps with `CAlignment::ClampPosition`, rva `0xC49F0`).

### 1.4 The schedule

In the country's daily pass at `0x4DB864`:

    if today (gameState +0xBDC) > country +0x124:
        CAlignment::UpdateDaily
        +0x124 = today + (ALIGNMENT_INTERVAL / 1000) x 24

`+0x124` starts at the null date `[0x170C2B8]` = 43,800,000 (`CCountry::CCountry`, `CCountry_Reset`)
and is **neither saved nor loaded**, so after a load every unaligned country steps at the first daily
pass and the schedule starts again from that day. The daily pass runs at hour 0 of the new day and the
test is strict, so **a step comes every `ALIGNMENT_INTERVAL` + 1 days** - 25 for Their Finest Hour's
and BlackICE's 24: a new game steps on 1 January (before the first hour), 26 January, 20 February,
17 March, 11 April, 6 May...

### 1.5 One step (`UpdateDaily`, the alignment in ESI, the country in EDI)

In a real faction: its leader (the first member) does nothing, a member's position is set to the
leader's. Otherwise `drift = ComputeDrift`, `move = ClampMove(drift)`, `position += move`.

### 1.6 `ComputeDrift`: a weight for each group, then a vector

For each group g, with M the members of g's faction (the shared null faction where g has none):

    w_g  = Relation + Ideology + Proximity
    if ((dy^2/1000 + dx^2/1000) / 1000) < 40000:      dx, dy = g - position: a distance under 200
        w_g -= Revanchism + Threat + Repulsion
    w_g += Influence (AlignTowards)

Every term but Repulsion is 0 for a country in a real faction (and the aggregator never runs for one).
SUSC is the country's `SUSEPTIBILITY` modifier, S its `suseptibility_<g's faction>`, maxIC
`CCountry +0x60C` in whole IC - 5 (`base_values`) and its controlled provinces' IC x (1 + LOCAL_IC),
floored (`FINDINGS-ic.md`). The defines are thousandths; Their Finest Hour's: RELATION 20, IDEOLOGY
2000, PROXIMITY 30, REVANCHISM 100, THREAT 150, REPULSION 10, LARGE_COUNTRY_IC 300000,
REPULSION_IC_FACTOR 8000.

**Relation**: `mean = SUM over m of country->diplomacy[m].relation x 1000 / (|M| x 1000)`, then
`mean x 20 / 1000 x (1000 + SUSC) / 1000 x (1000 + S) / 1000`; 0 for an empty M.

**Ideology**: `2000 x (1000 + DRIFT_SPEED) / 1000` where the ruling ideology (`+0x1140`) is real and
its group (`+0x50`) is g; else 0.

**Proximity** (rva `0xC3C00`), for each m:

    d = DistanceBetweenProvinces(m's acting capital, country's acting capital)
    t = max((5000000 - 1000 x d) x 1000 / 500000, 100)        ; 10 - d / 500, at least 0.1
    r = m.maxIC / country.maxIC                                ; an integer division
    v = r x 1000 x t / 1000
    best = the largest v (from 0);   best x 30 / 1000 x (1000 + SUSC) / 1000 x (1000 + S) / 1000

`d = isqrt(16 x (dx^2 + dy^2))` on the two provinces' **bounding-box centres** (`CProvinceTemplate
+0x2C/+0x30` = min + (max - min + 1) / 2, y north-up), dx replaced by `width - |dx|` where |dx| is
more than half the map's width (5616): four per map pixel, the game's kilometres. With
`country.maxIC` 0, r would be `m.maxIC` undivided; a base of 5 makes that unreachable. **The floor of
0.1 is `g_AlignmentProximityFloor`**, `floor(100.5f)`, set by a runtime initialiser
(`InitAlignmentProximityFloor`, rva `0x8B5860`).

**Revanchism** (rva `0xC3E40`; **this corrects the record's 5 x (0.5 - s)**):

    s = the faction's share of victory points (CFaction::GetVictoryPointShare) x 1000 / 100000
      = trunc(progress / total VP) in thousandths
    if s >= 500:  0
    else:
        per = (1000 - s) x 5000 / 1000
        n   = the country's cores (+0xD10) whose owner is not the country and is in g's faction
        n x per x 100 / 1000 x (1000 + SUSC) / 1000 x (1000 + S) / 1000

Total VP is the sum of every map province's `+0x34`, 1172 at the start.

**Threat**: `t` = the largest `country->diplomacy[m].threat` over M, counting only one above 0; none,
0; else `t x 150 / 1000 x (1000 + SUSC) / 1000 x (1000 + S) / 1000 x min(TotalIC x 1000 x 1000 /
300000, 1000) / 1000`, TotalIC `+0x604` in whole IC.

**Repulsion**:

    v    = (dy^2/1000 + dx^2/1000) / 1000                      ; whole units squared
    r    = Newton's isqrt: x = v/2, x = (v/x + x)/2 while it falls; v <= 1 -> v
    base = max(200000 - 1000 x r, 0) x 10 / 1000
    if base > 0 and the ruling ideology is real and its group is not g:
        lead = M's first member's maxIC;   w = lead + (SUM over M of maxIC - lead) / 4
        f    = 100000                                          where w <= 0
        f    = (floorf((maxIC + 0.0005f) x 1000) x 8000 / 1000) x 1000 / (w x 1000)   otherwise
        if f > 1000:  base = base x f / 1000

**Influence** (`GetAlignTowardsTerm`, rva `0xC3790`): 0 unless the country has the static modifier
g's faction's `influence` names (`align_towards_axis`, `_allies`, `_comintern`; `CountryHasModifier`);
`v` = that modifier's `ALIGN_TOWARDS` (entry 47), 20000 in Their Finest Hour;
`a = (100000 - max(leader's effN, 0)) x 1000 / 100000`; `b = max((100000 - country's effN) x 1000 /
100000 + 250, 250)`; `out = b x (a x v / 1000) / 1000`, effN effective neutrality (`+0xA90`), the
leader M's first member. **The 0.25 is `g_AlignmentInfluenceFloor`**, `floor(250.5f)`
(`InitAlignmentInfluenceFloor`, rva `0x8B5920`). The record's signature is corrected to `out@stack:4,
country@stack:8, group@EDI`, returning `out` in EAX.

**The vector**, for each group with (dx, dy) not (0, 0):

    s   = dy^2/1000 + dx^2/1000
    len = floor( float( float( sqrtf( float(float(s) / 1000.0) ) + 0.0005 ) x 1000.0 ) )
    inv = 1000000 / len                                         ; -1 where len is 0
    ux  = dx x inv / 1000;   uy = dy x inv / 1000
    out.x += ux x w_g / 1000;   out.y += uy x w_g / 1000

A group the country stands exactly on is skipped - so Italy at (200, 200) is moved only by democracy
and communism.

### 1.7 `ClampMove` - the move kept inside the triangle (rva `0xC4B00`)

`out = drift`, every test on the **original** drift:

    pos.x + drift.x > maxX:  out.x = maxX - pos.x
    pos.x + drift.x < minX:  out.x = pos.x - minX          (sic: the sign is reversed)
    pos.y + drift.y > maxY:  out.y = maxY - pos.y
    pos.y + drift.y < minY:  out.y = minY - pos.y

then, at `y' = pos.y + out.y`, with `left = (y' - apexY) x 1000 / leftSlope` and `right = (y' - apexY)
x 1000 / rightSlope`, both measured from x 0: `pos.x + out.x < left` gives `out.x = left - pos.x`,
else `pos.x + out.x > right` gives `out.x = right - pos.x`. `CAlignment::UpdateCentroid` (rva
`0xC48E0`) runs last. **This corrects the record**, which had the clamp to the bounding box. It is
what puts history points outside the triangle onto it: the USA and Canada at (20, -128.7) land on the
right edge on the first day.

### 1.8 What feeds `DRIFT_SPEED` and the susceptibilities in Their Finest Hour

From the country's modifier (`CCountry::RebuildStaticModifiers`): **press laws** - free +0.1, censored
+0.05, state -0.05, propaganda -0.1; **minister types** - `ideological_crusader` and
`flamboyant_tough_guy` +0.05, `apologetic_clerk` -0.05; **`SUSEPTIBILITY`** - `benevolent_gentleman`
-0.05, `weary_stiff_neck` +0.05, `pig_headed_isolationist` -0.5; **`suseptibility_<faction>`** -
`great_compromiser`, `the_cloak_n_dagger_schemer` and `biased_intellectual`, +0.1 each; the static
`neutrality` modifier, +0.05 x effective neutrality / 100; and five event modifiers
(`communist_manifestation` and others, -0.08 / -0.05). **Each of the ten posts adds the type its
minister has for that post**, one minister in two posts counting twice: taking his first-listed type
instead gives 57 of 101, his last 44.

### 1.9 The ruling ideology in a new game (`CCountry +0x1140`)

The history's `ideology =` sets it (`CIdeologyChange::Apply` -> `CCountry_SetRulingIdeology`, the call
at `0x5F1DEE`). At the end of `SetUpCountryForNewGame` (`0x4D7543`-`0x4D7564`), where it is null or
not real, it becomes the ideology (`CMinister +0x6C`) of the minister in cabinet post index 1, after
`CCountry_FillMinisterPosts(country, 0, 0)` and `CCountry_AllotCabinetSeats`; `CCountry::AfterLoad`
does the same on a load (`0x4D26B6`-`0x4D26D7`). All 100 of Their Finest Hour's histories carry
`ideology`, each the start save's.

## 2. Checked against the saves

### 2.1 The start save: 93 of 101

A rebuild of section 1 - the history's position, then one step - gives `alignment.position` in
`Germany1936_01_01_00.hoi3` for **93 of 101 countries to the thousandth**: all 11 faction countries
(GER, ENG and SOV where they were; FRA, IRQ, OMN, YEM, BHU, NEP on ENG's (0, -146); MON and TAN on
SOV's (-200, 200)) and 82 of the 90 unaligned, ITA (199.502, 199.673) and USA (9.788, -129.066) among
them. Its inputs: the history's positions; the save's factions in member order, ruling ideology,
ministers, effective neutrality, acting capitals and event modifiers; the relations of each country to
the members from the save in whole points, but ITA->GER and CHI->SOV, which are 0 on the first day -
the month after the two days copied the history's one-sided GER->ITA 200 and SOV->CHI 100 over them
(`FINDINGS-diplostate.md`, A); threat 0; maxIC = 5 + the controlled provinces' industry x (1 - 0.5
where the country has no core), floored, a reconstruction that leaves revolt risk out; the
bounding-box centres from `tfh/map/provinces.bmp`; and **faction progress 0** on the first day (2.3).

One control for each choice of model, against the 93:

| change | agree |
| --- | --- |
| `positions.txt`'s `unit` points for the box centres | 54 (26 more within 0.003) |
| the save's progress (263/173/115) for 0 | 84 |
| revanchism as `(0.5 - s) x 5` | 84 |
| every press law from the save | 79 |
| the Lua's "same government +10" in the relations | 89 - JOR, KOR, IDC and PAL are puppets whose save relation to the allies' five absolute monarchies is 0 |

Not reproduced, the save less the rebuild in thousandths: REB (-583, -343); JAP (-1, +1); EGY (+458,
+725); NZL (+2, -96); DOM (+21, -11); HON (+6, -5); PAN (-32, -194); ECU (-56, -69). HON and DOM fit
only with their max IC doubled (10 and 12 against 5 and 6), not explained; EGY controls no province,
ENG controlling them all; PAN wants +0.1 drift speed and ECU -0.05 that nothing found gives. EGY, PAN,
ECU, DOM and HON miss by the same kind of amount in every later comparison, so an input of theirs is
missing from the reconstruction, not from the reading.

### 2.2 Press laws at the moment of the step - measured, not explained

57 countries' press law differs between the history and the start save, the AI changing laws before
the first screen. All 13 that go censored to free fit only with the **history's** censored at the
step, so that change came after it; 41 of the 42 that go censored to state, and both that go free to
state (ETH, ISR), fit only with the **save's** state press, so that one came before - LIT, censored to
state, fits with censored. When the AI's change lands against the country pass was not read. For
OpenHOI3, which keeps the player's history laws and has no AI, the rule is the laws in force that day.

### 2.3 Faction progress is 0 at the first step

IND, PAK, IRE, TIB and GUY agree only with s = 0 (IND's 276 cores held by the allies need 5.0 a core x
0.1: its first move is 68 units). By 26 January progress is the save's 263/173/115 (2.4 fits with it),
the same in every later save of both games. **Its writer was not found**: a sweep of every direct store
to a `+0xAC` displacement finds `CFaction`'s constructor zeroing it (`0x522539`) - the positive control
- and nothing else in faction code, and `GetProgress` (rva `0x122BC0`) has no direct caller. That it is
worked out some time after the first day's alignment phase is inferred from the fit.

### 2.4 One step between saves of one game

All eight January saves of the 9 October game hold the start's positions: no step between 1 and 8
January. One step, with the earlier save's state and the later save's `align_towards_*` modifiers:

| window | the step | exact | within 0.003 | of |
| --- | --- | --- | --- | --- |
| 8 January - 1 February | 26 January | 32 | 41 | 101 (73) |
| 1 February - 1 March (autosaves) | 20 February | 67 | 15 | 101 (82) |
| 1 - 20 April (the 8 October game) | 11 April | 62 | 19 | 101 (81) |

The misses of 1 to 3 thousandths fit the save cutting relations to whole points while memory keeps
the month's fractions (`FINDINGS-diplostate.md` A.4) - inferred. The larger misses are the five
countries above and countries whose laws, ministers or influence changed inside the window (FIN, SWE,
SCH, BEL, TUR, LIT, HUN, ROM...); the saves do not record when an `align_towards_*` modifier began or
ended. The threat term used max IC for TotalIC; threat towards faction members is under 0.3 in all
these saves. 1 March - 1 April spans two games and was not used.

## 3. The geometry threat's spread uses

**The acting capital** (`+0xE24`, `CCountry::GetActingCapitalLocation`) is the capital (`+0xE20`) but
where a history capital change sets both, `SetGovernmentInExile` moves it toward the faction leader's,
and, each hour (`0x4D913A`), a country for which `0x42F1B0` answers true, in a real faction and not its
leader, takes the leader's acting capital - `0x42F1B0` unread, plausibly "no capital of its own". So it
differs from the capital only for a government in exile or in that hourly case.

**The distance** in `SpreadThreatToAll` and `ThreatFactorTowards` is `CMap::DistanceBetweenProvinces`
between the two acting capitals - the same `isqrt(16 x (dx^2 + dy^2))` on bounding-box centres, x
wrapped - and `reach = min(28 x provinces, 4000)` is in that unit.

**The neighbour list** (`+0xFD8`, `CCountry::RebuildNeighbours`): for each province the country owns,
the owner of each province beside it whose owner is also its controller, kept unique by the byte at
`+0xF58` (recorded, not read again).

**The order of a day**: `RunDailyPass` runs the parallel pre-daily update (spawned at `0x682DDD`:
`RebuildNeighbours` for every country with `+0x44` set) to its end before its serial loop
(`0x682E03`-`0x682E2A`) calls `0x4E39C0` and `RunCountryDailyPass` for each country - so the neighbour
list and the most-threatening country are fresh when the day reads them.

## 4. What looks wrong and is what the bytes do

- The period is 25 days, not 24, and a load starts it again with a step for everyone.
- The history's positions are not clamped: a country outside the triangle is put onto its edge by the
  first step's clamp, not by a drift.
- `ClampMove`'s arm below the minimum x has its sign reversed - hidden in Their Finest Hour, anything
  left of -200 being left of the left edge too, which overwrites it.
- Both edges are measured from x 0: the clamp takes the apex to be at x 0.
- The box always holds the origin, growing from a zero box at (0, 0).
- The "unit vector" uses `trunc(1000000 / len)`: about 5% short at a distance of 95, a quarter at 374,
  half beyond 500 - so far corners pull less than their weight.
- Revanchism falls from 0.5 a core to 0.25 as a faction nears half the world's victory points, then
  to nothing.
- An integer IC ratio makes a member no larger than the country worth nothing, and a country of five
  IC beside Germany's 144 worth 28 times the distance factor.
- The ideology term counts each post's own minister type, one minister in two posts twice.
- The centroid (`+0x10`/`+0x14`) is made after every clamp and read by nothing found.
- The proximity term reads the bounding-box centre, which `positions.txt` does not move: Berlin's
  `unit` is y 1729 and its box centre y 1728.

## 5. Evidence

The initialisers: `findRefs --address 0x1A87334` and `0x1A8732C` find two references each; the
runtime initialisers at `0xCB5860` and `0xCB5920` load `[0x160A684]` (100.5f) and `[0x160A688]`
(250.5f), floor them (`0x401FD0`), `_ftol2_sse`, and store; the readers are `0x4C3D17` and `0x4C38FA`.
Revanchism: `0x4C3FCE` `sub esi, eax` (s - 500), `jns` to the zero arm; `0x4C3FD8` `sub eax, esi`
with eax 500 gives 1000 - s; `push 0x1388`, the 5000. `ClampMove` decoded `0x4C4B00`-`0x4C4CC8`, the
sign slip at `0x4C4B7A` (`mov eax, [esi+8]` ... `sub eax, edi`). `RebuildBounds` `0x4C46C0`-
`0x4C48D4`, `UpdateCentroid` `0x4C48E0`-`0x4C49E7`, `ClampPosition` `0x4C49F0`-`0x4C4AFD`, whose only
caller is `0x429BA4`. The gates: `CIdeologyGroup` slot 6 and `CIdeology` slot 17 are `0xA92590` (`mov
al, 1; ret`); the null classes hold `0x592360`. The history: `CCountryHistory::LoadEntry` allocates
`0x20` at `0x5ED617`, then the constructor `0x5F0B40`, `ParsePoint` `0x5ED687`, `SetPosition`
`0x5ED693`; `Apply` `0x5F0BA0` calls `0x4F6CD0` (`lea eax, [ecx+0xE4]`, a fold) and `0x4F6CE0`, whose
only callers are `0x5F0BD7` and `0x5F0BEA`. `+0x124`: the store sweep finds `0x4C8BBD` (the
constructor), `0x4D3214` (the reset) and `0x4DB8FA`/`0x4DB925` (the pass) and no other; the gate is
`0x4DB86A` `cmp eax, [ebx+0x124]; jle`; the same sweep finds `LoadKey`'s `+0x98` and `+0xA8C`. The
ruling ideology's writers are the constructor, `LoadKey`, `AfterLoad`, `SetUpCountryForNewGame`
`0x4D7564` and `CCountry_SetRulingIdeology`. The vector decoded `0x4C3450`-`0x4C3550`. The day's
order decoded `0x682DDD`-`0x682E2A`. `0x4FA0B0` is already `CAlignment::BuildDriftTooltip`
(`FINDINGS-survivors.md`).

## 6. Not established

When the AI's law changes land against the first day's country pass (2.2); the writer of `CFaction
+0xAC` and when it is first set (2.3); which post cabinet index 1 is (head of government, by the file's
order - inferred); which list `CountryHasModifier` tests, which decides whether an unaligned subject's
automatic `align_towards_*` makes the influence term fire; `0x42F1B0`; the nearest-group search for a
country in no faction (recorded inside `ThreatFactorTowards` and `SpreadThreat`, not read again); why
REB, JAP, EGY, NZL, DOM, HON, PAN and ECU miss.
