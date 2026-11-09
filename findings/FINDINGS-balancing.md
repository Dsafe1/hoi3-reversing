# What holds the balancing back

*2026-11-09. Static reading, the maintainer's saves, and the running game read through Cheat Engine. Addresses are VA against an image base of `0x400000` unless marked rva; the running game was loaded at `0x310000`. Status: settled. OpenHOI3 agrees with the 4 January save in all 106 theatres.*

## In one paragraph

`CAIUnit::DistanceToTheatreFronts` (`0x4B08C0`) looks for the least **square** of a distance, from a first best of 1,000,000, and takes the root only at the end. So anything over 1000 from a front (four times the map's pixels: 250 pixels), and any theatre with no fronts, answers exactly 1000. `CAIUnit_PickDivisionsToGive` scores a candidate `(1 - d / maxD)`, with maxD the greatest d among the candidates, and takes only a score above nought. Every candidate at the cap therefore scores 0 and is never picked, so a donor gives only divisions already within 1000 of the taker's fronts. The needs and n were right all along. This is the brake, it is hard-coded, and it looks accidental: nothing suggests the seed was meant as a range.

## The listing

```
0x4B08D2  mov edi, 0xF4240                 ; first best, 1,000,000
0x4B0966  imul ecx, ecx
0x4B0969  imul eax, esi
0x4B096C  add eax, ecx
0x4B096E  shl eax, 4                       ; 16 * (dx*dx + dy*dy), 32 bits
0x4B0971  cmp eax, [ebp-8]                 ; against the best: a square
0x4B0974  jge 0x4B0979
0x4B0976  mov [ebp-8], eax
...
0x4B098F  mov eax, edi                     ; Newton's root of the best, after both loops
0x4B0998  cmp edi, 1 / jg                  ; 1 or less returned as it stands
```

The sum is signed 32-bit. It overflows at about 11,585 pixels apart, the far side of the map, and a negative square beats every other and is returned as it stands (inference from the instructions; not seen happen).

The record had this function as "the smallest `DistanceBetweenProvinces`, seeded at 1000000", which reads as a seed that never bites. It also listed four callers, all in `GenerateUnitObjectives`. The pick calls it too, at `0x8BFC57` and in its scoring loop.

## The running game

A new game on 1 January 1936, BiceLib not loaded; that it was the base game is inferred from its needs agreeing with a base-game model run. Hardware execute breakpoints that only log, each reading the function's stack or registers: `CEU3AI_InsertAgentByShortage` (`0x49C140`, called for each agent right after its daily need refresh), the pick's entry and its `ret 0x1C` (`0x8C0154`), `CAttachUnitCommand`'s constructor, then for one day the return of `CAIUnit_UnitMayLeave` inside the pick (`0x8BFB5C`), the end of the candidate loop (`0x8BFC89`) and the score comparison (`0x8BFFA5`).

**Britain's needs, every day from 1 to 4 January:**

| theatre | areas | need | count, 1 January | count, 4 January |
| --- | --- | --- | --- | --- |
| Home (9) | 3 | 31 | 18 | 18 |
| Middle East (15) | 3 | 5 | 3 | 3 |
| Army of India (16) | 6 | 6 | 13 | 11 |
| Far East (21) | 8 | 8 | 2 | 3 |
| East Africa (28) | 9 | 11 | 4 | 5 |
| St. John's (7) | 9 | 9 | 0 | 0 |
| Port Harcourt (36) | 11 | 11 | 0 | 0 |

`+0x370` is 0 on all of them, so the aircraft want's "Home at about 31" stands. `their_power` is 115 on East Africa alone.

**Every country, the first pass, against OpenHOI3 two hours into a new game:** the needs of 104 of the 105 theatres that can be compared are the same (Germany, played in that run, has no agents there; one of Japan's is 34 live against 55). So `CTheatre +0x84` holds what the model has.

**Britain's picks on 1 January**, in order. maxCount is n; India's 8 for Home is what the arithmetic gave:

| from | to | asked | returned |
| --- | --- | --- | --- |
| India | Home | 8 | 0 |
| India | Port Harcourt | 8 | 0 |
| Middle East | Port Harcourt | 2 | 0 |
| Home | Port Harcourt | 4 | 0 |
| India | St. John's | 8 | 0 |
| Middle East | St. John's | 2 | 0 |
| Home | St. John's | 4 | 0 |
| India | East Africa | 7 | 1, 7th Indian Infantry |
| India | Far East | 6 | 1, 6th Indian Infantry |
| India | Middle East | 2 | 0 |

Over the four days, across every country, 98 of 102 picks returned fewer than asked.

**5 January, Britain's twelve picks.** Ten of India's divisions were candidates for every taker, all with `UnitMayLeave` true. The eleventh, the 25th, was not a candidate though `UnitMayLeave` answered yes. It stands in an area of its own, which fits have <= keep (inference; the maps were not read). maxD was **exactly 1000.0** for every taker, whether it had 2, 3, 4, 6, 7 or 16 fronts. Every score was 0.00000 and nothing was given, with one exception: on the way to the Far East the Ceylon Command, at sea province 12037, scored 2.15 (`(1 - 785 / 1000) x 10`) and was returned, the other nine scoring 0.

France shows the same maxD of 1000.0 wherever it has candidates. Some of its donors have an empty candidate list; why was not traced.

**Attaches.** 782 `CAttachUnitCommand`s in four days, from ten call sites. The site at rva `0x48F108` (returning to `0x48F10D`) is the balancing's, 56 of them. The site at `0x48EB58`, its whole-unit grab, did not fire, nor did the two this write-up had open, `0x48BD82` and `0x498016`. The other seven sites were not read, so another source of transfers is not excluded; the cap alone reproducing the saves makes one unnecessary.

## With the cap, set against the saves

OpenHOI3's `CTheatreBalance` had the same seed on the plain distance, so it never capped. With the square and the root at the end, `Germany1936_01_01_00` to `_01_04_12`, of 106 theatres:

| | before | after |
| --- | --- | --- |
| army groups under a theatre | 99 | 104 |
| armies | 91 | 100 |
| corps | 91 | 103 |
| divisions | 91 | 101 |
| fleets | 99 | 102 |

Every British theatre's divisions agree. The five left were then settled by what follows, and divisions came to 106 of 106, army groups 106, armies 105, corps 104.

**A third run, a new game from 1 January**, logged each theatre's divisions on the first day, every candidate and refusal, every score and each list returned. Set beside OpenHOI3 for the same four days, 93 of 102 picks are the same in place, divisions and order, all 44 of France's among them.

- **The USA's East and the Philippines were not the balancing.** Phillippine Force is a USA division in the 1 January save and in the Philippines' Manila HQ by 4 January, carrying `expeditionary_owner="USA"`, and the running game counts it there from the USA's first pass. `CAIUnit::ManageExpeditions` lends it: the Philippines has no faction and neither has the USA, and that test is a pointer compare on one shared null faction (`FINDINGS-agents.md` C.7). OpenHOI3 had not built it.
- **The Soviet theatres** came right with the pick done as the listing has it: ratios, scale and score in single precision, the roll-up putting a command on the end of the list and its commander noted on a second list tried once, the 0.25 not applied to a unit at sea, a garrison on its own depot and the agent's target provinces refused, and "have" counted by where a division is bound.
- **France's empty candidate lists** come out the same in OpenHOI3, whose only test able to empty them there is have <= keep (inference from that).
- **Left over, neither changing a theatre's total.** Eight of Britain's picks for Port Harcourt and St. John's come in another donor order, all returning nothing: OpenHOI3 finds the Middle East's headquarters a way there, and `CanUnitReach(..., true, true)` evidently does not. One Soviet pick on 2 January returns four divisions in OpenHOI3 and the whole 42nd Corps in the running game, because that corps has five divisions in OpenHOI3 and four there; the ladder's filling, not read.

The pace follows too. A division in India is given only once it stands within 1000 of the taker's fronts, which is why about one moves in ten days with a standing shortage, and why Home, whose nearest front is out of reach, gets none.

## At war: `Ireland1941_07_16_07`, loaded and run 51 hours

The save was loaded in the running game and in OpenHOI3, and each run forward with the picks logged, 57 of them in the running game across seven countries. This is where OpenHOI3 still differs.

- **Vichy France agrees on all 10.** The USA's theatres agree in need and count.
- **Needs at war.** On each country's first pass 20 of the 24 theatres that could be compared first agreed in need and count. The four that did not were Britain's Middle East (27 live against 26), India (18 against 17), the Soviet theatre 67 (**75 against 64**) and Germany's theatre 6.
- **What was wrong.** A probe of `EstimateAreaNeed`, per front province and per area, found every front province scoring the same on both sides. The difference was the focus recursion: theatre 67's 75 is 62 for its home area, 10 for Mongolia (a focus area in its region group) and the rest. OpenHOI3 had no focus areas at all, because its supply network, built while a load read the theatres and before the pacts, was never made again, so no puppet stood with its master. Made again once the save is read, and with the AI asking the region group (`FINDINGS-supplynetwork.md` section 8) rather than the supply group, **23 of 24 agree**, the Soviet Union's 75 and all of Britain's among them. Germany's theatre 6 is 73 and 118 against 72 and 119.
- **Picks.** Of 57, 43 are the same in place since the reach test below. Theatre 1350 gives 12 of 15 to theatre 61 where OpenHOI3 gives 10: the pick ranks by where divisions stand, and 21 hours of two AIs moving on their own stand between that and the save (inference, the positions then were not compared).
- **Which division is in which theatre.** On each country's first pass, 490 of the 491 divisions compared are in the same theatre on both sides, by name. The one that is not is Germany's 214. Infanterie-Division, which waits to be placed in the save (`it_deployment`), stands in province 1626 by 02:00 next day in the running game and is unplaced in OpenHOI3 then. When the original places a finished unit was not read.

## The land reach test

`CMapProvince::CanUnitReach` was recorded as ending in a path search, its flags not understood, and `FINDINGS-moving.md` A.4c had the line asking the safe finder. Read whole 2026-11-09: **a land unit (slot 15) asks no path.** After the enemy-in-the-province and failed-order refusals it calls `CMapProvince_LandReachByArea` (`0x5CE350`): one owner area; or a land edge to the goal; or, the unit trespassing or having a neighbour it may enter, an area beside its own or `CCountry_ProvincesConnectedByArea`. Only a fleet takes a finder. And the area path refuses more than enemies: `OwnerAreaCost_NoEnemy` also refuses a controller the country may not enter (`0xEFA50`), which is a neutral.

Built so for the balancing's "connected", **Britain's picks of 1936 come out in the running game's order, all 46, and France's stay all 44** once neutrals are refused: 101 of 102 in all, the one left being the Soviet 42nd Corps. Tried in OpenHOI3's line-filling as well, it changed neither check, so the line keeps the safe finder there.
- **A loaded game's first hour.** Italy and Portugal, whose pass falls on the first hour after the load (08:00), balance then in the running game and a day later in OpenHOI3. Setting `unit_pass_done` on a load changed nothing, so the cause there is something else, most likely agents not yet bound. Not read.

Which term of `EstimateAreaNeed` differs at war was not established.

## What the rest of the reading settles

- **No early stop.** The decompiler's `free(list); return` in `0x88E490` is the node-freeing loop (`0x88F243`-`0x88F253`), followed by `jne 0x88e5a0` to the next taker.
- **n** ends at the first count where `(countA+n)/needA < (countB-n)/needB - t2` fails, or at needA - countA (`0x88ED90`-`0x88EDF7`).
- **Constants**, hard-coded floats: 0.4 (`0x170AC10`), 0.15 (`0x160A894`), 0.3 (`0x15C05EC`), 0.1 (`0x15C05F8`), 0.35 (`0x160AA1C`), 0.125 (`0x160AA18`).
- **The pick's maps**: keep at `[ebp-0x98]`, have at `[ebp-0xC4]`, tested at `0x8BFBFE`-`0x8BFC0F` as have <= keep and keep > 0, both made once before any pick.
- **The score** must beat the best so far, from 0, strictly (`0x8BFFA5`).
- **The pick does not ask `CanUnitReach`.** In the balancing that only orders the donors.

## Withdrawn

An earlier draft of this file, written before the game was run, fitted the saves with needs of East Africa 5, Far East 3 and St. John's and Port Harcourt 0, and proposed that `+0x370` or a shorter area list reconciled them with the aircraft want. All of that was wrong: the needs were the model's and the pick was the brake. It is recorded here because the fit was exact, 208 solutions, and still false.

## Corrections to the record

- `CAIUnit::DistanceToTheatreFronts`: the seed is against the square, so the answer is capped at 1000; the pick is a caller.
- `FINDINGS-agents.md` F.2 and F.6 follow.
- Trap 2 again: `functionStart` attributes the attach calls at `0x88EB58` and `0x88F108`, in the balancing, to `0x88DCF0`.

## Not established

- Japan's one need of 34 against 55, and Germany's theatre 6 at war.
- Why a loaded game's first hour balances in the original and not in OpenHOI3.
- Why the 42nd Corps has four divisions and not five on 2 January.
- What the other attach sites are.
