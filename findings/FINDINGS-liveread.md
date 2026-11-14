# Short reads of the running game, 2026-11-10

Read through the Cheat Engine bridge, the method of `FINDINGS-balancing.md`. A new 1936 game was run for 36 hours, then
`Ireland1941_07_16_07.hoi3` was loaded and run for 3. Addresses are rvas unless marked VA. *Confirmed* here means seen in
the running game.

## 1. The generator is not re-seeded in play (confirmed)

The record and `FINDINGS-landbattle.md` section 3 said every hour starts a fresh stream. It does not, in single player:

- `ReseedGlobalRandom` (`0x6A2ED0`) was hit **no times** in 36 hours of a new game, with a breakpoint on its entry.
- `g_random_draws` (`0x134DA8C`) ran on from 7,771 to 25,530 over those hours, and the saves' `count` runs on as well
  (132,951 to 133,091 over one hour of January 1936; 20,622,004 to 20,623,449 over five of 1940).
- The dword at `0x134DA94` held 86 throughout: the figure `ReseedGlobalRandom` passes to the initialiser (`mov eax,[0x174DA94]`
  VA, then `0xAA2BF0` with the state array in ecx). This is the generator's real seed. The state array at `0x1310F80` is
  not a seed, whatever its record name says.

`RunHourlyTick`'s store of the seed and zeroing of the draws (VA `0x681C3E`-`0x681C79`) is a path single-player does not
reach. `SnapshotRandomState` pushes the draws and that seed into the hour's tick payload each hour, and this path takes them
back. That it is the multiplayer resynchronisation (a reader placed it under "Games out of sync") was **not checked**.

**How many draws.** An ordinary hour made 57 to 175 in the first days. The midnight of 2 January made 14,241, all between the
start of `RunHourlyPass` and the first `ProcessAI` of that hour.

**Replaying an hour** therefore needs the state array and its index (`0x1310F80`, `0x1311940`), dumped live at the start of
the hour. A save cannot supply them.

## 2. The order of the hour (confirmed)

Logged for 36 hours at `RunHourlyPass`, `ProcessAI` and the one execute site of the command queue (`0x689940`):

    CHourlyTickCommand runs -> RunHourlyPass -> the daily pass, on a new day -> ProcessAI x102 -> the commands posted, then the next tick

- **The AI runs after every pass of the hour**, the daily pass included: its 102 entries always came after the hour's draws
  were made. That agrees with the static reading, `CGameState::RunAIPass` being called from `CInGameIdler::Update`, a frame
  after the tick.
- **All 102 countries run in a different order each hour** (36 different orders in 36 hours), the TBB workers of
  `ProcessAIFunctor`. The first few to enter vary, for example `---`, `YEM`, `REB`.
- **The commands they post run after all 102 passes**, before the next tick: 4,264 executed, the last of each hour a
  `CHourlyTickCommand`. Their serials are nearly in order but not quite (34 of 37 hours have a swap, 1275 before 1274), the
  mark of posting from several threads.
- **Neither the AI passes nor the commands drew on the game's generator.** Every one of the 17,759 draws in the log came
  between `RunHourlyPass` and the first `ProcessAI`. A sample of 36 early hours of 1936; the claim is about those.

A loaded game's generator is left alone: at the moment `Ireland1938_08_03_14.hoi3` stands loaded and paused, `g_random_draws` is 2 and
`0x134DA94` is 0, whatever the save's `seed` and `count` say.

## 3. A unit's figures (confirmed)

`CUnit +0xC8` set beside the unit's brigades' `CSubUnit +0x58` definitions, 80 units of 2 or more brigades: **soft, hard, air
attack, defensiveness, air defence, width, strength, supply, fuel and officers are the sum; toughness is twice the sum; piercing
is the best brigade's; softness is the mean, truncated.** 80 of 80 on each.

## 4. List orders only memory holds (confirmed for a new game)

Paused on 2 January 1936 at 12:00, with nothing changed hands yet:

- `CCountry +0xCF0` (owned), `+0xD00` (controlled), `+0xD10` (cores) and `+0xD80` (naval bases) are **in province-number order**
  for every country of 2 or more: 76, 76, 90 and 40 of them.
- `CMapProvince +0x2B8` (the units in a province) is **in order of arrival**, at the end as a unit comes. A headquarters
  the AI makes in the first hours stands after the divisions already there, so the list is neither by id nor by order of battle:
  province 1964 holds its theatre, Eastern Command, Home Counties Area, 12th Division, London District, 1st London Division and
  then the new 2nd Army Group.

The factions held one member each on that date, so that list was not tested.

## 5. Italy's organisation in 1941 (confirmed)

`CCountry +0xD90`'s entry 70 (`LAND_ORGANISATION`) for Italy is 50. It comes from one of its two `CTriggeredModifier`s at
`+0x658`; the file's only land-organisation entry that fits a country in that state is `veteran_army` (`land_battles_fought =
250`, `land_organisation = 0.05`), and the save gives Italy 251. Entries 71 and 72 (air and naval organisation) are 0, so the
5% is not on every kind of brigade, as was thought. The ratio is 1400, at its cap. The save check's 44.100 against 42.000 is
this modifier.

## 6. The AI's attack odds (confirmed)

`CAIUnit::EstimateAttackOdds` read at both of its value exits (`0x4D9E02`, `0x4D9E1E`) with its arguments, 232 calls, 16 July
1941 08:00 to 10:00, Germany and the Soviet Union. Each side's `D` is `toughness (theirs: defensiveness) x +0xF0 x +0xF8`, which
is `combat_defend_product` and `landing_defend_scale`, read at VA `0x7E9C34` in the live base.

Set beside OpenHOI3 from the same save, unit list for unit list: 81 estimates compare, and every one lies within 11%, half of them
within 4%. Germany's single-unit estimates are within 0.5% with one exception of 1.7%. The Soviet Union's stand about 4% high, by
a term not found. Of the other 151 calls, 18 repeat one already compared and 133 have a list of units OpenHOI3 did not try, its candidates coming in another order or its picks differing (the cause was not traced).

## 7. A land battle's hour, against OpenHOI3 (confirmed)

The first hour of `Ireland1938_08_03_14.hoi3`, loaded and run in both. The generator's whole state (the 624 words at `0x1310F80`, the index at
`0x1311940`, the draws) dumped at the entry of `CCombat::Tick` (`0x16EBE0`) for every battle, and put into OpenHOI3 at the same point; each battle's
fronts and reserves, then `CLandCombatant::FireUnit` (`0x16ADC0`) with its unit, the side's stream `*random`, the draws and the unit's four products, then
each brigade after the hour.

- Battle at 5597 and at 7510: **every figure the same** - the fronts and reserves, the streams `x`, the draws at every shot, and all brigades' strength and
  organisation to the thousandth.
- Battle at 5638: the same, but for one brigade of unit 4658, 26.789/22.065 against 26.804/22.154. The unit's product was the same, but the enemy's
  (850/1700 against 848/1698) was not: **experience, which is rolled in the unit's hour before the battles**, on draws not restored here.
- The modifiers on every unit, read off `CUnit +0xDC`: 6 experience, 8 territorial pride, 10 dug in, 1 leader, 5 stacking, 14 river, 18 combined arms,
  25 terrain, 26 weather, 27 night, 17 several battles. China's 8, +200, is the triggered modifier `desperate_defence` (`lost_national = 0.3`), which a load
  had been testing before the count that answers it; the rest are as OpenHOI3 makes them.
- A bombing is not yet the original's: from one generator, OpenHOI3 draws 33 and 75 where the original drew 32 and 86 (a third, 73, agrees).
- **Not shown**: the first front of a new battle, a reserve coming up, tactics chosen. No battle both games had going needed them: the two new ones (7511, 5596)
  came of a move only the original's AI made.

## 8. Controlling the running game from outside (confirmed)

Two bytes of `CInGameIdler`, written from Cheat Engine with the game in single player. **Pause**: `+0x12D8` = 1. **Unpause**: `+0x12D9` = 1 and `+0x12D8` = 0, what
`CInGameIdler::Unpause` stores. To stop on an exact hour, a breakpoint on `RunHourlyPass` (`0x282630`) sets the pause when the tick reaches the target; that hour
then finishes and no other starts. **Save**: `+0xAB0` = 1, the autosave request, which is honoured while paused: `autosave.hoi3` was written within ten seconds,
dated 1938.8.3.16 and complete.

That save's `seed` is -1514471307 and its `count` 885. `seed` in a save is **the first word of the generator's state array** (`0x1310F80`), which the paused game
held at the same value with its draws at 885, and not the figure the generator was made from (`0x134DA94`).

## 9. A land bombing's hour, against OpenHOI3 (confirmed)

The hour after the save of section 8, `CCombat::Tick` dumping the generator for each battle, `CBomberCombatant::FireUnit` and `CSubUnit::BombProvince` logged. Three
land bombings both games had going: at 5639, 5596 and 7514, seven wings in all. With two things mended in OpenHOI3 every wing's products and list of targets, every
draw up to the next battle, each wing's and each bombed unit's strength and organisation after the hour, and the province's goods and buildings are the same.

- **Mission efficiency**, modifier 7 on each wing (+200 here): OpenHOI3 had no name for the bombing orders, so a country's efficiency at them was never added.
- **An air group that has flown off its carrier**: section 4 of `FINDINGS-organisation.md` is right that room is then the air base of the province the carrier is in. Two
  carrier groups over China got their organisation back at a quarter, because the carrier was at sea with no air base; OpenHOI3 treated any group of a carrier as uncrowded.

A fourth bombing, at 5637, began only in the original: an order only its AI gave.

## 10. A battle in the air, against OpenHOI3 (confirmed)

No save held a battle in the air with both sides still in it, so the game was run on from `Ireland1936_02_02_04.hoi3` and stopped by itself on the first one, over
province 4475, and saved. Logged for the hour after: the generator at `CCombat::Tick`, each side at `CAirCombatant::Attack` (`0x16D750`) and each `CAirCombatant::PickTarget`
(`0x16D620`). **Every product, every draw of both sides, and every wing's strength and organisation after the hour are the same**, with no change to OpenHOI3's rules.

**The first attempt differed, and the difference is a load's.** A wing's remembered target (`CSubUnit +0xB8`/`+0xBC`, with `+0xC0`) is not in a save, so a game going on keeps
it and a game loaded picks again, spending two draws a wing, as the original's load does by `FINDINGS-savedbattle.md`, A.6. Carried across by hand for the test, it
matches.

## 11. A battle at sea, against OpenHOI3 (confirmed)

The game was run on from `Ireland1937_11_02_21.hoi3` to the first battle with ships on both sides, six Japanese against one Chinese in sea zone 11927, and saved. Logged for
the hour after, its third: the generator at `CCombat::Tick`, each side at `CNavalCombatant::Attack` (`0x167930`) with every ship's products, strength, organisation
and distance (`CSubUnit +0xC8`), and each `CSubUnit::PickTarget` (`0x1675D0`). **Every figure and every draw is the same**, and every ship after the hour, with no change to OpenHOI3's rules.

**The hour before differed for reasons of a load, not of a rule.** A load draws every ship up afresh about 100 out (`FINDINGS-savedbattle.md`, A.6, in the original and in OpenHOI3), so
a saved `current_distance` of 12 came up as 122 and two ships out of reach shot nothing. For the test each ship's target, distance and experience were carried across
by hand; experience because the roll for it comes before the battles, on draws not restored here.

**Not shown**: a battle's first hour, and breaking off.

## 12. A save started with nobody at the machine, and what a load runs before its first hour (confirmed)

Read and tried in the running game on 2026-11-10, the window behind everything else. `probes/hoi.lua`, `probes/hoiseries.lua` and `probes/game.ps1` are the working copy.

**A front-end button is its handler called on the main thread.** Input cannot be fed in: the DirectInput read (`CDirectInputMouse::Poll`, `0x74E780`) is not called at all with the window in the background, and a posted window message is ignored. A breakpoint at the top of `CFrontEnd::Update` (`0x2EDD60`) sets EIP to a small stub (`pushad`, `pushfd`, the arguments, `mov ecx, this`, the call, `popfd`, `popad`, `jmp` back to the top of `Update`). The view is `views[n]` from the frame's own ECX. In order: `CFrontEndState::OnSinglePlayerButton` on view 0, `CGameSetup::OnSavedGamesTab` on view 3, `CSavegameItem::OnClicked` on the row, wait for `load_pending` clear and `save_loaded` set, `CGameSetup::OnPlay` on view 3. A row is found by the table its `OnClicked` sits in and carries its file name at `+0x28`. From the main menu to a game standing paused at its hour took under 30 seconds on a save of 1941. `game_speed` (`+0xBEC`) written from outside is honoured at once: index 0 advances no hour, 2 about one a second, 4 about fifty.

**A breakpoint callback that returns 1 must continue the thread itself**, or the game stands frozen at the breakpoint. Cheat Engine's Lua state outlives the game, so what points into the old process has to be made again after a relaunch.

**Two AI passes before the first hour.** Counted on `Ireland1941_07_16_07` from before Play until the game stood paused: `ProcessAI` 204 times for 102 countries, every one at the save's own tick, two a country; `CAIUnit::Tick` 192 times for 96 agents, so each agent ticks in both; `CAIUnit_ManageLandUnits` 96 times, once an agent. **Every agent exists when the first pass begins.** `unit_pass_done` reads 0 and `theatres_changed` 1 at the first pass and 1 and 0 at the second, as the record's step 5 of `ProcessAI` says for a loaded game. Which pass runs the land block was not logged; that a new agent's full pass falls in the first is inferred from the agent's rule.

So a save written after entering already holds those passes' orders: set beside the save it was loaded from, the same units carry 167 new ways, by unit name, none of them walked. **The units' numbers change on a load**, so two saves either side of one are matched by country, name and level.

**Not shown**: where the agents are made before the first pass; a new game's count, only a load's was taken.

## 13. The order a load leaves the units in, and the garrison step (confirmed)

Read on 2026-11-10, on the game standing paused after a load of `Ireland1941_07_16_07`, and set beside OpenHOI3's first pass on the same save.

**A country's unit list after a load is the save's tree walked children first.** `CCountry +0xBAC`, read whole for every country, against the save: 65 of 71 countries the same, and the other six the same but for the units waiting to be placed, which the save lists at the end. So divisions come before their corps, a corps before its army. Everything built on the list follows it: `CAIUnit +0x11C` (land units) and `+0x12C` (committed divisions) are that order. In Chile the same positions are filled by the units taken in this order, so a different order gives every division a different province. That a unit made in play goes on the end is inferred: none was made between the load and the read.

**`CAIUnit_FillGarrisons`' candidate test**, on the listing:

- Each target wants the number of garrison divisions over the targets, the first remainder ones one more; that number is the vector's size, not the split's count.
- A candidate is judged by where it is **bound** - its destination, or where it stands with none. That province must be in the target's area (or the target's area be a focus area), not be the target, not be held by an enemy, the rebels or under an undeclared war, and not be threatened.
- Unless the target is threatened, where that province is itself a target of the list and scores above nought, the candidate is passed over when `have(target) + (1, none at a depot) >= standing(there) - (1, none where the target scores more or is a depot)`.
- Least squared distance x 16, in single precision, doubled for a role 5 army leaving a higher-scored target; a tie goes to the earlier unit; only one that can reach the target.
- The pick takes one off `have` where it was bound for a target, or off `have` and `standing` where it stood in one with no destination, and counts as sent whatever `MoveUnit` answers.

**`CountUnitsAtPositions`' callers**: the line passes every committed division, garrisons included; the garrison step its garrison divisions and any land unit; the reserve its held-back divisions and any land unit. A unit standing in a record and bound for a province no enemy holds is counted nowhere.

Set against the original's first pass on that save, with the order and the garrison step as read: of the 167 land units the original gave a way, 57 the same way in OpenHOI3 where it was 35; 77 ways the original did not give where it was 140.

**Not shown**: the rest of the 110 the original gave and OpenHOI3 does not match, most of them the Soviet Union's and Germany's; the allies' half of the count, which OpenHOI3 does not make.

## 14. The line's numbers and where headquarters go (confirmed unless marked)

Set beside OpenHOI3's first pass on `Ireland1941_07_16_07`, with the positions of the Soviet agents read from memory.

**`CAIUnit +0x13C` is the committed divisions before the reserve.** Smolensk's held 133, of which 110 are `+0x12C` and 23 `+0x15C`. The split of garrison and line, the allied-soil budget and the garrison vector are all made from it, so the reserve still counts: 133 less 31 garrisons is the 102 the line's wants add up to. With that, all 25 of Smolensk's wants agree.

**A region's `+0x6D` is `ai_prio` in `map/region.txt`** (inferred; the writer was not found). Each province of a marked region scores 100 more, by the province's scale. Mod-able. With it all 11 of Moskva's scores and wants agree.

**`army_combat_value`** counts a country's own units and what it has lent, and not what is lent to it. Manchukuo holds 94096 where counting every unit it has gives 2003691, Japanese units being on loan to it. The record already said so; OpenHOI3 did not.

**The area sum of the split** adds an area's size once per front-worthy front province. The list of areas the routine builds goes unread.

**`CAIUnit_PickProvinceAmongSubordinates`**, against the listing, as the record has it: a child's neighbours are candidates whether or not the child's own province could be reached, and where any child is no garrison the garrisons are left out of the mean. The sum and mean are in single precision. Corps then armies are walked, so each sees where the one below it has just been sent.

**Not shown**: the Far East agent's hold list, 21 where OpenHOI3 has 27.

## 15. The hold list (confirmed)

Every agent's hold list read from memory on the game standing paused after a load of `Ireland1941_07_16_07`, 96 agents, set beside OpenHOI3's: 87 the same, province, score and order, from 54.

- **A subject skips only its puppets' focus areas.** `isSubject` jumps past that block to the theatre's provinces, not past both. Bhutan and Iraq, both vassals, have lists; OpenHOI3 had none.
- **A province can come twice.** The set the objectives and focus provinces go into is asked of the puppets' and the theatre's provinces and not added to. Nanning HQ holds five provinces twice.
- **A rounded score** is `fistp`, so a half goes to the even.
- **The ships in a port's score** are those of the fleets based there, at sea or not.
- **A loaded theatre's `+0x60`** is its own provinces and then its fronts', though a save writes the fronts first. Two positions of one score keep that order.

- **Military access is in a save's pair block**, `military_access=yes`, after `threat`. The Soviet Union's status towards Sinkiang holds it, so Sinkiang is a friend and adds nothing to the threat its neighbouring provinces are scored by. OpenHOI3 dropped the key. With it the Soviet Far East's 21 agree, and 87 of the 96 lists.

**Not shown**: the other nine lists.

## 16. The reserve (confirmed)

`CAIUnit::ManageSubordinates` on the listing, and the three counts of the Soviet Union's and Germany's agents set beside OpenHOI3's: all agree.

- **A division held back by the test goes on `+0x13C` too.** The held-back branch joins the push and goes on to the second push, so `+0x13C` is every division that passed through.
- **At war a division already held back stays held back.** The branch at `0x8B27BA` takes it before any figure is read; the bar for its return further down is dead code.
- **The detach's frontier test was recorded the wrong way round.** Bound for a frontier province a division is passed over where a land battle is on there, or where **fewer than** two land units of more than one brigade stand: `jl` at `0x8B3017`. `FINDINGS-power.md` said `>= 2`, and corrected there.
- A plan's power ratio of nought for them is -1, the lowest bar but one; a negative one is 1.

On the save of July 1941, entering: of the 167 land units the original gave a way, OpenHOI3 gives 88 the same.

**The line's carry** leaves out a position scoring under 1.0 where the scores come to 1.0 or more, as the share does (`0x8C9480`). The Soviet Far East's wants agree with it.

## 17. Which division goes where (confirmed)

`CAIUnit_FillLinePositions`, the send and the pull, on the listing.

- **The send walks the positions in list order.** A position with a want and under its cap, where the division stands, is taken at once. A division bound for a target province away from the hostile routes looks only at positions beside one.
- **The key** is have/want x 100, with the excess over 1 counted again; at war the distance from where the division is **bound** x (have/want + 0.1), x 0.66 for a land battle; less 50 x the terrain figure; then x 0.66 at a depot and beside a hostile route. The order matters: the terrain comes between the multiplications. All single precision.
- **There is no test of have against want** in the send, only have against cap.
- **The pull's fill of the short position is worked out once**, so pulling a division to it does not raise the bar for the next.
- A candidate bound for its own depot under a blocking order is passed over, and the allied-soil budget applies to the pull too.
- `CAIUnit_SendReservesToPosition` sends the nearest fit division, one at a time while the position is short.

On the save of July 1941, entering: of the 167 land units the original gave a way, OpenHOI3 gives 107 the same.

## 18. The fronts on entering, and a division's role (confirmed unless marked)

- **Every theatre's fronts are made again as a loaded game is entered.** Set beside the save it was loaded from, the save written after entering has the same provinces in other orders of fronts and of provinces in them. The agent's area is walked from the fronts, so positions of one score come in that order. Which routine does it was not read. OpenHOI3 remaking its fronts alone puts all 17 of Germany's Ob.kdo positions and their wants at the running game's; running the whole refresh instead moved divisions between theatres and was worse.
- **`CArmy::ClassifyRole` averages the brigade's own softness and speed**, technology in them, and not the type's base figures: 1,324 of 1,327 divisions agree with the running game that way, against 1,289.

**Not shown**: why the reserve of the two largest agents differs by four and two divisions, the rest of their committed lists being the running game's in order.

## 19. Which divisions are held back (confirmed)

`CAIUnit::ManageSubordinates`' detach, on the listing, the committed and held-back lists of all 96 agents read from memory and set beside OpenHOI3's: 95 the same in order.

- **The counter is keyed by where a division stands.** It is read for the province a candidate is bound for and subtracted on a frontier; each division held back by the test or detached adds one to the province it stands in. `FINDINGS-power.md` had it per destination.
- **Below stance 3 the first brigade is not looked at.** The militia +2 and mountain -2 sit behind the stance-3 branch; the other branch jumps past them.
- Many candidates tie, at 2.005 for a whole Panzer division in the line, so the counter is what decides among them.

**Not shown**: the Soviet Smolensk agent's one division that differs.

## 20. Calling off (confirmed)

Phase 3 of `CAIUnit_ManageLandUnits`, on the listing.

- **A land battle always answers that it may be left.** So a defender falling back is called off a losing defence as one that is not.
- **A support attack is stood down when every attacker of its battle has an order that is neither a plain move nor none.** Slot 24 of the order is the test; `FINDINGS-moving.md` had "a blocking order".

**Not shown**: the attack itself, set beside the running game's over hours.

## 21. Who counts at a position, and who is a garrison (confirmed)

Read on 2026-11-10 on the game standing paused after a load of `Ireland1941_07_16_07`, with every key of Germany's line and all 96 agents' garrison marks read from memory.

- **`CAIUnit::CountUnitsAtPositions` counts allies.** For the line, with focus areas and the frontier at war, each other country on `non_hostile_countries` that controls the first province of a focus area has its whole unit list counted the same way. Germany's first position differed by these. With them, all 86 keys the send works out for `Ob.kdo. des Heeres` agree with OpenHOI3's.
- **The garrison targets are kept in descending score.** Both rounds insert through `CList_InsertByDescendingScore`, so a province let in by the second round stands in its place by score, not at the end. Of equals the earlier stays first.
- **A division is taken for a garrison by the agent's frontier, not the country's war.** Soviet tank and motorised divisions are garrisons in Moskva's agent, which borders no fighting.
- **It belongs to a block by where it stands or where it is bound**, and the neighbours looked at for a prepared war are its destination's, or where it stands with none.
- **The garrison step's distance is from where the candidate is bound**, as its other tests are.
- With these, 92 of the 96 agents mark the same divisions as the running game, and on that save OpenHOI3 gives 133 of the original's 167 land ways the same, where it gave 111, and 14 more go to the same province by another road.

**Not shown**: why twelve long Soviet redeployments out of the north take a road 3% longer than OpenHOI3's. Each differs from its first step, the two roads being all Soviet land with no battle on either. Refusing any one province of OpenHOI3's road does not give the original's. Seventy-seven other redeployments on that save agree step for step.

**Not built and not settled**: the test of `CAIUnit_SplitGarrisonAndLine` on CEU3AI `+0x2C`, which read 1 on the Soviet Union, so the walk it guards did not run there.

## 22. Hour by hour after entering, and the strategies (confirmed unless marked)

Read on 2026-11-10 by loading `Ireland1941_07_16_07` hands off, writing a save each hour for 48 hours, and logging the running game.

- **Every country's strategy is made again as a saved game is entered.** `CAIStrategy::Rebuild` is called 100 times at the save's own tick, every country but `---` and REB. `FINDINGS-aistrategy.md` had a loaded strategy kept until the first midnight, and is corrected there. At that midnight only countries owning no province reach the function, and each bails. No agent's `SetArea` runs at it either.
- **Each agent's `SetArea` runs twice on entering**: 192 calls for 96 agents, all at the save's tick.
- **Two runs of the original from one save differ.** After entering they agree on 294 of 298 ways. Over the next six hours, of the 69 land orders one run gave, the other gave 54 the same, and it gave 13 of its own. Nothing was changed between the runs but the breakpoints. In one run Germany attacked province 1750 in the first hour, at stance 2; in the other it did not, though the logged decision for 1750 in the run that did not was odds 1.395 on entering and 1.889 at each of the next two hours, against a bar of 3.0.
- **The attack set beside the running game's.** Germany's theatre goes to stance 3 at the fourteenth hour in both, and its attacks that hour are 1750, 2102 and 1577 in both, with 1395 too in the original: nine divisions in the original, ten in OpenHOI3, eight of them the same. The weights of the 20 target provinces agree in order, and within 1.1 in value.

So on a save of OpenHOI3's own loading the yardstick for hours after entering is the original against itself, not an exact match. Six hours: OpenHOI3 gives 44 of the 73 land orders the same and 20 of its own, against 54 of 69 and 13 between two runs of the original.

**Not shown**: what gave Germany's attack on 1750 in the first hour of that one run, it not being the attack decision logged in the other. And why OpenHOI3 gives 164 orders over 48 hours that the original does not, at least some of which follow a province changing hands at another hour.

## 23. The reserve's ring and the garrison step's records (confirmed)

Read on 2026-11-10 on the running game after a load of `Ireland1941_07_16_07`, from the orders the original gave Italy's Libyan divisions and OpenHOI3 did not: 108 of them in 45 hours, seven divisions sent between 9422 and 5626 every three hours.

- **The moves are the reserve's.** `CEU3AI::MoveUnit` logged with its return address: every one returns into `CAIUnit_PlaceReserves`.
- **The second ring holds only provinces in a real area.** `CAIUnit::RebuildAreaNeighbourProvinces` asks each province's owner area its slot 0 before anything else. Read from memory after entering: Italy's Libyan ring is 9422 and 5626, where five desert provinces out of every supply network would otherwise join it. With them, OpenHOI3 sent the reserve into the desert.
- **The ring's counts are `CountUnitsAtPositions`'**, so a division standing in one ring province and bound for another counts in neither. The busy test is the order's slot 24 alone, so a division on its way is looked at, and it is never sent where it is already bound. Over its room, it goes to the other province, and back again the next pass.
- **The garrison step keeps one record a target.** The hold list names 5484 twice, so the targets do too, and the second record wants a garrison while the first has one. The original sends the Friuli division to it on entering, and that move is why the reserve does not run then. A province is looked up as its last record.
- With these, on that save: entering 136 of the original's 173 land ways the same; six hours after, 53 of 73 against 54 of 69 between two runs of the original; 48 hours, 147 of 299.

**Not shown**: why OpenHOI3 still gives 178 orders over 48 hours that the original does not. Germany's and the Soviet Union's are the most, about two dozen each.

## 24. Falling back from a losing defence (confirmed)

Read on 2026-11-10 on the listing of `CAIUnit_FallBackFromLosingDefences`, with the moves logged with their return address after a fresh load of `Ireland1941_07_16_07`.

- **It ran at the second hour** in the logged run: Soviet 129, 112 and 108 out of 2390, to 2333, 2509 and 2449. The battle's share was 0.774. In the run whose saves the comparison uses it did not, so the comparison counted it as OpenHOI3's alone.
- **The defenders are sent from the back of the side's list.** They are gathered front to back and popped from the end, one to each scored neighbour in turn.
- **A river is a crossing as well as a river edge**, and only across one is a neighbour's holder asked whether it is at war with the country.
- **What keeps the defenders in is a friendly land unit standing beside the province and bound for it**, any country the agent's may operate in. `FINDINGS-moving.md`'s "nobody bound into the province" read as anyone anywhere.
- **A neighbour is scored only where the country may operate in it**: its own side, or a co-belligerent not at war with it.
- **The defenders are not filtered by owner**: an ally's division on the side is sent too. *Not built in OpenHOI3*, which sends only its own.
- The reserve's outnumbered test counts the idle divisions of any country it may operate in, not only its own.

With them OpenHOI3 sends the same three divisions to the same three provinces. Set against the other run's saves, 48 hours give 147 of 299 the same.

## 25. The fleets after entering (confirmed)

Read on 2026-11-10 on the running game after a load of `Ireland1941_07_16_07`: OpenHOI3 gave 24 fleet orders on entering that the original did not, 14 of them American, 7 British.

- **A war nobody declared counts as a war.** `CCountry +0xACD`, the undeclared-war flag, reads 1 for the United States and Germany. `CAIUnit_ManageNavalUnits` keeps a patrol, an escort and a raid when the country is at war or in an undeclared war. So the original keeps the American Pacific patrols at peace for 48 hours, where OpenHOI3 sent every one home. `CAIUnit::Tick`'s land pass every third hour also asks both, as its record already said.
- **The later naval phases run only on a forced pass.** After the split and merge, a pass that is not forced ends: the survey of enemy fleets, the per-fleet raids and rebases, the patrols and the intercepts wait for the agent's full pass or a replan of its fleets, at war as at peace. The British naval body was seen reaching the merge every hour and nothing after it. OpenHOI3 ran them every hour at war, sending British fleets out of port on patrol.
- With both: 7 fleet orders on entering that the original did not give, down from 24; over 48 hours 111 of the original's 159 fleet orders the same and 140 of OpenHOI3's own, down from 176; land 149 of 299 and 162 of its own, down from 190.

**Not shown**: the patrol's centre is drawn with the C runtime's `rand()` of whichever thread runs the AI, which OpenHOI3 does not repeat, so which fleet patrols where cannot be set beside the original's.

## 26. The air rebase on entering (confirmed)

Read on 2026-11-10 on the running game after a load of `Ireland1941_07_16_07`: OpenHOI3 rebased 18 air groups on entering that the original left where they were.

- **The rebase runs on entering**, with the pass forced. Brazil's three air bases are on all three of its lists at 10000 each, nothing to measure against, as OpenHOI3 has them.
- **What decides is the crowding.** A candidate's wings are those of every air unit on the list of its air base object, and the original's lists hold air groups nested under a headquarters as well as at the top. OpenHOI3 counted only top-level units, so a full base looked empty. Brazil's 7848, with four wings, looked like room for three more.
- With the count mended: on entering, the original's 5 air orders all the same and 4 of OpenHOI3's own, down from 18.

**Not shown**: why OpenHOI3 still sends three British groups and an Omani one a long way on entering, the RAF's strategic bomber command among them.

## 27. The air base lists and the air triage (confirmed)

Read on 2026-11-10 on the running game after a load of `Ireland1941_07_16_07`, for the four air groups OpenHOI3 still sent on entering: the RAF's strategic and Far East commands, its 11th Air wing, and an Omani dive bomber group.

- **Only the country's own air bases are held to the agent's theatre.** Its overlord's and its puppets' go on the lists wherever they lie. The United Kingdom's Home and Far East lists both carry Singapore (Iraq's) and an Omani base, and Oman's carries every British air base in the world. On the Far East list Singapore, the Far East groups' own base, scores best, so they stay; OpenHOI3's list lacked it and sent them to China.
- **The triage has two pairs of thresholds, each used for strength and organisation alike.** At air stance 2 a wing under 0.5 of either is unfit, and one under 0.75 of either damaged or tired; otherwise 0.7 and 0.85; halved for a carrier's or interceptor group. A group with any wing damaged or tired, idle at its own base, rests, so it is not a candidate for the rebase. `FINDINGS-reorganise.md` read the pair as strength and organisation, and is corrected there. The RAF's strategic bomber command has a wing at 0.53 strength, so it rests; OpenHOI3 sent it to the Shetlands.
- With both: on entering, the original's 5 air orders all the same and none of OpenHOI3's own; over 48 hours, 15 of the original's 24 the same and 11 of OpenHOI3's own, down from 20.

## 28. A land battle's hour, roll for roll (confirmed)

Read on 2026-11-10 on the running game after a load of `Ireland1941_07_16_07`, with a save every hour and, at the start of every battle's `CCombat::Tick`, the generator, each sub unit's remembered target, distance and experience, the fronts, reserves and tactics written out. OpenHOI3 loaded each hour's save, put in the generator dumped before each battle, played one hour and was set beside the next save and the log. Each land unit's shot (`CLandCombatant::FireUnit`) was logged with its side's stream and its two products, and each tactic pick (`CCombatant::PickTactic`) with its three arguments.

- **One aggressiveness serves the whole pick, and only the attacker is given it.** `CCombat::PickTactics` (`0x56E9B0`) keeps one local: the attacker's highest-ranked leader's unit's aggressiveness, then **overwritten by the defender's** where the defender has such a leader. Every branch then passes that local to the attacker's `PickTactic` and **nought to the defender's**. So the attacker picks with the defender's commander's aggressiveness when there is one, and the defender never with its own. Read on the instructions, and the twelve picks logged agree. `CCombat::PickTactics`' record said each side picked with its own.
- **Combined arms counts every brigade's group.** `CUnit::RebuildDefinition` marks `CUnit +0x1D0[unit_group]` after either path of its loop, the reduced one included (`FINDINGS-unitdef.md`, step 4), so a broken support brigade still counts towards the combined-arms bonus. OpenHOI3 counted only the brigades that count towards the unit, and gave Soviet 15465 no combined arms where the original gave it 200.
- With both, and sections 29 and 31, the land battles of four series of hourly saves (hours 875 to 948, 950 to 997, 999 to 1058 and 1067 to 1126 of the clock's last digits) are the original's in nearly every hour that can be played again. What is left is the first hour of a battle or bombing, whose making draws before the battles; battles beside a bombing only one game made, which is the AI's air orders and not the battle; and two single hours **not shown**: in battle 1529 at hour 958 and battle 2571 at hour 1107, one unit's single shot falls the other way, every figure and formula of it read the same in both games.

## 29. A broken support brigade and its unit's terrain (confirmed)

Read on 2026-11-10 on the same series. In battle 2572 the defender's product fell from 1702 to 1513 at hour 945. The save showed its engineer brigade's organisation down to 0.912 the hour before and 0 after.

- **A support brigade below one organisation or a tenth of strength drops out of every adjuster of its unit, and still divides it.** `FINDINGS-unitdef.md` has the rule: `CUnit::RebuildDefinition` takes such a brigade on its reduced path, which adds only softness, and `CSubUnitDefinition::Divide` divides every `CUnitAdjuster` by the whole count of brigades. The engineers' terrain defence went with them, 12.5% of the unit's figure, and the live modifier list for the unit lost its terrain entry. Seen live; it agrees with the reading and adds nothing to it.
- OpenHOI3 averaged each adjuster over every brigade, broken or not. With the rule, battle 2572 is the same in every hour of the series.

## 30. The province's fire at bombers at sea (confirmed)

Read on 2026-11-10 on a later series of the same game, with a breakpoint inside `StaticAntiAirTerm` just after it makes `n = guns + units x 1.5`, writing `n`, its two parts and every unit on the province's list.

- **The friend test counts military access.** `CUnitList_SumFriendlyAirAttack` calls `CCountry::IsFriend(owner, controller, 1)`, includeMilitaryAccess set.
- **In a province nobody holds, every unit of a country with no overlord counts.** A sea zone's controller is the null tag, id 0. `CCountry::IsFriend` compares ids, and its second test asks whether the asker's overlord is the other: a country with no overlord has the null tag for one, id 0, so the test holds for it. In sea zone 11448 at tick 60808036 the list held a British fleet (43.5 air attack), two British carrier air groups (4.5 each), a British fleet with none and three Italian fleets (2.0 between them), and `n` was 81.75, every one of them times 1.5. So **bombers at sea are fired at by their own side's ships and by themselves**. The original's, and it looks like a slip: the null tag was not meant to be anybody's friend.
- **A carrier's air group is on the province's list** with its carrier (525 and 527 above), as `CUnit::EnterProvince` puts it there (`FINDINGS-transport.md`).
- OpenHOI3 asked only alliances and factions and counted nobody at sea. With all three, the bombing of 11448 is the same in each of its hours. One earlier bombing at sea, of 10568, still fires a few shots fewer than the original's: its list was not logged, so which unit is missing is **not shown**.
- The ground bombings of 4549 and 3903, and every bombing of land units logged on land, are the original's in every hour after the first.

## 31. Encirclement (confirmed)

Read on 2026-11-10 on the running game: in battle 2571 the two Soviet defenders fired at 0.9 of what OpenHOI3 made of them, hour after hour. Their modifier lists, read off `CUnit +0xDC` while the battle went on, held id 3 at -0.1 beside id 4, envelopment, at -0.1: `BM_ENCIRCLEMENT_PENALTY`.

- **The penalty is put on as `FINDINGS-aihelpers.md` reads `ProvinceIsEncircled`**: a defender in a province whose owner area is of one province, not land with only sea beside it, and with no neighbouring area held by a friend of the unit's owner (`CCountry::IsFriend`, military access counted). `ENCIRCLED_PENALTY` times one and the `encirclement_bonus` trait, never below nothing. In the list it comes after envelopment.
- OpenHOI3 had not built it. With it, battle 2571 is the original's in every hour of the series but one (section 28).

**Not shown**: why six hours of air battles in the first two series still differ, all over the sea south of Italy with the British wing 578 in them. Those series logged no air fire. The fourth, logged with each side's wings and pending damage as it began to shoot, had two air battles, and both are the original's in every hour after their first.

## 32. Where a land unit may stand, and the railway roads (confirmed)

Read on 2026-11-10 on the running game. On entering the save of 16 July 1941, twelve Soviet divisions in the far north (provinces 45, 144 and 222) were sent west by a road ours did not take: the original's 292.8 km long and on infrastructure 6 most of the way, Murmansk's railway, ours 242.2 km over land of 1 and 2.

- **The original's own route search gave the railway road.** Every Soviet `CPathFind::Find` was logged with its finder, start and goal, and the road `SetUnitPath` handed over, over 36 hours of a series: one search from 59 to 88 with `CVerySafePathFind` returned the railway road. So the road is a finder's, and not some other planner's. Its step cost is the edge's distance alone (`CPathFind::StepCost`, read again), and its estimate, square root, edge order and open list are ours.
- **Its search never adds a province with one level of infrastructure.** Each province taken and added was logged inside `Find` for 89 Soviet very safe searches over 48 hours. From 47 to 658 it never added 73, 109, 58, 90, 61 or 93, which each have one level, and added all sixteen of two levels or more that it reached.
- **That is `CArmy::MayStandIn`'s owner-area test**, which `FINDINGS-movement.md` had left unread: the province's owner area answers slot 0, `ReturnTrue` for a `COwnerArea` and `ReturnFalse` for the `CNullOwnerArea` (`FINDINGS-aihelpers.md`). A province is in an area only when somebody holds it and it has more than one level of infrastructure built (OpenHOI3's `supply.md`, section 2). So **no land unit stands in, or passes through, land with one level of infrastructure or none**, whoever asks.
- OpenHOI3 let a land unit through any held land. With the rule, 57 of the 60 very safe searches logged give the original's road, the other three being units the check could not place at the search's start. On entering, the original's land orders are given the same 150 of 167 (136 before), 97 of 110 and 65 of 73. Over the 48 hours after entering, 155 of the original's 299 the same, 2 by another road where there were 11.
- It answers `FINDINGS-redeploy.md`'s third question: a redeploying unit keeps to the railways because the poor land beside them is closed to it, which is why changing the step cost changed nothing there.

**Not shown**: what the rest of OpenHOI3's own land orders over the 48 hours are. About 130 in the first 45 hours, Soviet 37, German 23, Italian 17 and Slovak 10, many of them headquarters moved, and a burst of 47 at the 46th hour that follows province 2390 changing hands in OpenHOI3 an hour before the original, a battle the series run does not restore the generator for.

## 33. Headquarters pulled in among their subordinates (confirmed)

Read on 2026-11-11 on the running game, for OpenHOI3's headquarters orders that the original does not give. A breakpoint at the start of `CAIUnit_PickProvinceAmongSubordinates` wrote each headquarters with every child's number, place, goal (`CUnit +0x2CC`) and garrison mark (`+0x2C9`), and one just after its call in `CAIUnit_PullHeadquartersIn` the province chosen, over three series of hourly saves (about 60 hours). OpenHOI3 played each hour from the save before and wrote the same.

- **The choice is the original's wherever its inputs are.** Of the choices both games made in the scheduled hours of Germany, the Soviet Union and Italy, every one made on the same children - the same places, goals and garrison marks - was the same, 72 of them; every one that differed, 25, had children that differed. The listing of the pick, read again end to end, is the record's: the mean `CMap::DistanceBetweenProvinces` to each land child's goal or place (garrisons left out where any child is none), skipped at 0, 6 off for the start, 1000 on bordering foreign land, 100000 on with `MaxInfrastructure` (`CMapProvince +0x5C`) under 200, the least under 100000.
- **"Destination" there is `CUnit::GetMovementDestinationProvince`, `+0x2CC`**, which `CEU3AI::MoveUnit` sets in the same pass: the children the land block has just sent count at their new goals. So a headquarters' move follows its divisions' orders of that hour, and OpenHOI3's own headquarters orders are mostly its own division orders seen one level up. A first comparison that took the end of each child's path for its goal had shown 18 differing choices on "the same" children; with `+0x2CC` there were none.
- **The garrison marks are kept from hour to hour and not saved**, so a game loaded from a save starts with none; a comparison that loads every hour's save cannot have the original's.
- OpenHOI3 read effective infrastructure for the 100000 and did not ask `CMapProvince::CanUnitReach` before the move or look at a headquarters in a battle it may leave; all three are as the original now. Over the 48 hours after entering they change OpenHOI3's own orders by one.

## 34. A garrison is picked by its strength, not its organisation (confirmed)

Read on 2026-11-11 on the running game. A breakpoint in `CAIUnit_SplitGarrisonAndLine`'s pick of a garrison, just after the call `FINDINGS-moving.md` read as the organisation share, wrote each candidate with the mean distance + 10, the score before that factor and the figure the call returned, 51 candidates over eight hours.

- **The figure is the division's mean strength share.** The call is `[vftable + 0x64]`, slot 25, which the record already names `GetMeanStrengthShare`; slot 26 is the organisation. On the save of the hour before, OpenHOI3's strength share was the original's figure for every candidate - 966 for Slovakia's 1. Pesi divize, whose organisation share is 670, and 926 for the SS-Verfügungstruppe, whose organisation is 378 - and its garrison rating agreed for all 39 it could place.
- So the pick is (10 x rating + (mean + 10) / 5) x 0.75 on a front x (1.5 - strength share): a worn-down division is one that has lost men, not one that has lost organisation. The arithmetic is in single and double precision, the mean's + 10 added only where the operations area is not empty.
- OpenHOI3 had used the organisation share, after this write-up's prose. Changed, on entering the three saves the original's land orders are given the same 153 of 167 (150 before), 95 of 110 (97) and 63 of 73 (65).

**Not shown**: why Japan's garrisons on the save of 16 July 1941 still go out in another order. OpenHOI3 marks the three Rikusentai and three infantry divisions at 5315 and sends 60 Nippon and the infantry first, as its committed list orders them; the original sends 60 Nippon and the three Rikusentai. Either the original's list of garrisons is ordered otherwise or it marks other divisions; its list on entering was not read.

## 35. The order the garrisons go out in (confirmed on the listing)

Read on 2026-11-11 on the listing, for Japan's garrisons on entering the save of 16 July 1941: OpenHOI3 marked the right divisions at 5315 - the three Rikusentai, then 60 Nippon - but sent two infantry divisions out where the original sent the Rikusentai.

- **The fill goes through a vector the split hands it, in the split's order.** `CAIUnit_FillGarrisons` copies its second argument and walks that, a tie in distance to the earlier. `CAIUnit_SplitGarrisonAndLine` fills it in two parts: walking the committed vector, each division with a garrison brigade (marked, at 0x4C7BE2) and each still marked from before and still in land the country holds (0x4C7BD2), in committed order; then, per region group, each one dropped is erased from it (0x4C89AE, `0x4ECDA0`) and each new pick appended as it is made (0x4C8E20). OpenHOI3 had walked the committed list for the marked divisions, which puts the new picks in committed order instead of the order they were picked in.
- **The pick compares in single and double precision.** `RateUnitAsGarrison`'s fill is each brigade's strength over its most as a single; the score is `(float)(rating x 10 + (float)(mean10 / 5))`, x 0.75 on a front, x (1.5 - share / 1000), compared as doubles, strictly. Japan's 7 and 10 Rikusentai are 29.995 and 29.973 strong: in thousandths of a share they tie and the earlier wins; as the original computes it the weaker rates higher, and goes first.
- With both, Japan's four garrisons from 5315 go where the original sends them, and on entering the three saves the land orders are the same 155 of 167 (153 before), 96 of 110 (95) and 67 of 73 (63). Over the 48 hours after entering, 158 of the original's 299 (155).

**Not shown**: Bulgaria's garrisons on the same save go to other targets - 4368 in the original, 4123, 4870, 5107 and 5077 in OpenHOI3 - which is the target list, made from the hold list, and not the order.

## 36. A province named twice on the hold list is two garrison targets (confirmed on the listing)

Read on 2026-11-11 on the listing, for Bulgaria's garrisons on entering the save of 16 July 1941: OpenHOI3 sent a second garrison to 4123, which already had one, where the original sent one to 4368 and two to 4555.

- **The top-up skips a record, not a province.** Round two of `CAIUnit_SplitGarrisonAndLine` (0x4C8190 to 0x4C82F8) walks the hold list +0x17C while the targets number fewer than the garrisons; each node's data is a pointer to a hold record, kept at [ebp+0C]. Where CEU3AI +0x2C is set it goes straight to 0x4C82D9, which walks the targets list comparing each node's data with that pointer (`cmp [eax],ecx` at 0x4C82E5) and calls `CList_InsertByDescendingScore` (0x4C82F8) only where none matches. So a record already taken is passed over, and a second record of the same province is not.
- Bulgaria's hold list names 4368, 4555 and 4870 twice. With both records of each taken, the 17 garrisons have 17 targets and each wants one: 4123 wants no second, 4368's second record takes the 9-ta Plevenska, and 4555's two take the 11-va zapasna and the 1-va Sofiiska - as the original does. OpenHOI3 had skipped a province already listed and made 15 targets, so the first two wanted two each.
- On entering the three saves the land orders are the same 160 of 167 (155 before), 96 of 110 and 67 of 73.

## 37. Slovakia's line: an ally's front taken in a war, and the allied-soil test (confirmed on the listing)

Read on 2026-11-11 on the listing, for Slovakia on entering the save of 16 July 1941: the original sent the 1. and 2. Pesi divize and the 1st Corps fifteen provinces east to the Soviet front, OpenHOI3 kept them at home.

- **The area.** Slovakia's one theatre faces only Germany and Hungary, yet its plan's area of operations is a front of Germany's against the Soviet Union - the same 17 provinces, 1306 to 2701 - before entering and after. `CAIUnit::SetArea` takes it through `AreaMayWidenFrontSearch`'s last arm, which the record already had whole (`FINDINGS-subdivide.md`, section 6, step 9): an area beside the focus area, of more than five provinces, held by a country we are at war with, the side we fight on led by a country nobody plays. OpenHOI3 had built only the subject and faction-leader arms. With the whole function, Slovakia's area and powers are the original's, 72.410 against 611.674.
- **The position cap** (`CAIUnit_GetPositionCap`, 0x4BF350, on the listing): the fort is the province's level in thousandths cut to whole levels (0x4BF5DC, `10624DD3`, `sar 6`), times two, cut by three (0x4BF5EF) - a level-1 fort takes nothing off. As the record has it.
- **The allied-soil test** (`CAIUnit_IsMoveFromHomeAreaToAlliedSoil`, 0x4C77C0, read whole): false unless the target's controller is neither us (0x4C77CF) nor id 0 nor `REB`, and is `IsSameSide` or a co-belligerent (`CDiplomacyStatus +0x58`) not `IsEnemyTag`. Then d = `CUnit::GetMovementDestinationProvince`, or the unit's own province with none (0x4C784C). With d ours, true where d's area is the acting capital's area (0x4C7874); otherwise, with d held by an enemy (`CCountry::IsEnemy`, 0x4C7895), true where the province the unit stands in is ours and in that area (0x4C78C2). **It asks where the unit is bound, not where it stands.** Its two callers are both in `CAIUnit_FillLinePositions`: the send (0x4C9E67) and the pull (0x4CA3FB); the send asks it only with the budget spent (0x4C9E57). OpenHOI3 had asked whether the unit stood in the capital's area and the target was not ours. The 1. Pesi divize stands at 3030, Hungary's, bound for 2830, Slovakia's: the send passes over every position, and it draws its second-ring province, 1574, as the original sends it - the same draw that gives the 2. Pesi divize 1575.
- On entering the three saves the land orders are the same 163 of 167 (160 before), 96 of 110 and 67 of 73.

## 38. A reserve's strength share is of its reduced most (confirmed)

Read on 2026-11-11 on the running game, for Germany on entering the save of 3 August 1938: the original sent 32., 28., 1. and 3. (mot) Infanterie-Division and three more of its divisions to positions, OpenHOI3 left them standing and sent the 3. Panzer-Division instead.

- **The split's counts were the same.** Logged at the end of its front loop and after the garrison count (`CAIUnit_SplitGarrisonAndLine`, 0x4C802A and 0x4C80BA) a day later: the Ob.kdo. des Heeres 24 front provinces, 23 enemies, area sum 4176, strong 5, 26 garrisons of 50; OB West 22, 30, 2909, 13 garrisons of 30 - OpenHOI3's figures, and on entering the same front lists and hold counts (logged at the function's entry). The enemy count asks `CCountry::IsFriend(owner, true)` of each land unit on a front-worthy province (0x4C7FF5) - military access making a friend.
- **The garrisons picked were not.** Logged at the pick's comparison (0x4C8DE9, the candidate's score in xmm1) and the mark (0x4C8E31): the original marked the 3. Panzer-Division, 31.539143, over the 11. and 21. Infanterie-Division, 24.954571 and 25.364914, where OpenHOI3 scored those two 37.406952 and 38.022057. They are reserve divisions, each brigade at 22.489 of a most of 22.497, the save's `highest`, which the reserve penalty holds under the type's figure - and the strength share is **of that reduced most**: `CUnit::GetMeanStrengthShare` calls slot 12, `CSubUnit::GetMaxStrength`, with both flags nought (0x1C6F6D), as `GetUnitAverageStrengthAndOrganisation` and `CAIUnit::RateUnitAsGarrison` already had it in the record. So a reserve at its ceiling counts as whole: 0.9996, not 0.75. OpenHOI3 had divided by the type's full strength. With the reduced most, all 63 German candidates' scores are the original's to six places, and the 3. Panzer-Division is marked as there.
- On entering the three saves the land orders are the same 165 of 167, 106 of 110 (96 before) and 69 of 73 (67).

## 39. A loaded game's agents are bound in its first pass and run their land block in the second (confirmed)

Read on 2026-11-11 on the running game, entering the save of 3 August 1938, 14:00 - Italy's own hour A6 (its id is 8), so both passes before the first hour are full passes for its agents and section 12's count of one land block an agent needed explaining. Breakpoints on `ProcessAI`, `CAIUnit::Tick` and `CAIUnit::PositionLandUnits` (the land block's first call), logging Italy's calls in order with a running count of `ProcessAI`:

- `ProcessAI` runs for Italy twice, the 9th call and the 187th, its theatres not marked dirty either time.
- **In the first pass Italy's two agents tick with no unit** - `CAIUnit +0x64` nought - so each returns at the tick's row 6 and runs no land block. **In the second they tick bound to Cdo. Sup. Metropolitana and Cdo. Sup. Africa, `full_pass_pending` set, and each runs the land block and `CAIUnit_FillLinePositions` once.** So the agents a load has made before its first pass are unbound then, and the first pass's unit step binds them; the land block comes in the second pass, whatever the hour. Section 12's "that a new agent's full pass falls in the first is inferred" is wrong: it falls in the second.
- OpenHOI3 had bound them as it made them, so a country entered on its own A6 hour ran its land block in both passes, and the second pass's garrison fill sent Italy's garrisons out where the original sent none. Made unbound, on entering the three saves the land orders are the same 165 of 167, 106 of 110 and 73 of 73, with those ours gave alone 5, 4 and 2 (6, 14 and 2 before); over the 48 hours after the save of July 1941, 211 of the original's 299 (163).

## 40. The attack on 1750: the same save entered twice, two answers (confirmed; the cause is not)

Read on 2026-11-11 on the running game, for the German attacks on 1750 that the series of July 1941 has the original give in its first hour and OpenHOI3 not. Logged in `CAIUnit_ManageLandUnits`: each target's phase-one score where it is written (0x4D6716), the odds at both calls of `CAIUnit::EstimateAttackOdds` (0x4D73A8, 0x4D78E8), and at the bar (0x4D798C) the friendly region groups `[ebp-0xAC]`, the odds and the stance.

- **The weights are OpenHOI3's.** Every German target scored on entering and in the first hour has the score OpenHOI3 gives it - 1750 447.435883, 1869 600.0 - so 1750 is no blitz and its bar is the stance 2 one.
- **The bars are the record's**: 3.0 at stance 2, 1.1 at 4, 1.5 otherwise (0x4D7966, the constants at 0x162DC88, 0x151A2F0, 0x16279AC), 0.8 to call off, both 0.2 and 0.01 where the friendly neighbours fall in more than one region group or the port flag is set. The region groups are counted over the target's land neighbours by an edge not of kind 3, held by a country on our side or a co-belligerent not our enemy, each owner area's region group (+0x6C) once - OpenHOI3's `SharedBoundary`.
- **Two runs, one save, two attacks.** Entering `Ireland1941_07_16_07` the first time, 1750's odds climbed 0.618, 1.080, 1.662, 1.890 as four units were added, and `CEU3AI::MoveUnit` was called for the 81. Infanterie-Division to 1750 from the attack (0x4D7AB3); entering it again, the odds at the bar were 1.395 with one region group, and the attack sent the 3. Gvardejskaya Strelkovaya into 1749 instead and nothing into 1750. The series' run, a third, has the 11., 81. and 57. bound for 1750 after the first hour. So the original's attacks on entering vary from run to run, and an attack that OpenHOI3 does not give is not necessarily a rule it lacks. What differs between the runs - the units each candidate set holds, or a draw in the odds - was not read.

**Likely, from section 2**: neither the AI passes nor their commands draw on the game's generator, so a generator left unrestored by a load cannot be it on entering, where no battle has been fought. What section 2 also shows is that the 102 countries' passes run on TBB workers **in a different order each hour**, and the AI writes some unit fields on the spot (a stood-down unit's destination is zeroed at once, `CUnit::AIStandDown`). The two runs fit that: in one the Soviet line fill sent the 117. Strelkovaya into 1750, in the other the Soviet attack took the 3. Gvardejskaya out of it into 1749 - so whether Germany's pass saw what 1750 would hold depends on which thread came first. Inference, not read.

## 41. Which friend each test asks, and which way round (confirmed on the listing)

Read on 2026-11-11 on the running game, for the six places in OpenHOI3 still counting only a country and its faction as a friend. Every call of `CCountry::IsFriend` (`0xEF7C0`, 75 call sites) was listed with the function it sits in and the access flag it pushes; the two places that do not call it were read where they decide.

- **`IsFriend` is not symmetric** - an alliance is read from the other country's record towards this one, military access from this one's towards the other - so which country asks matters. With military access counting (flag 1) at all of these:
  - `CCountry::MayEnterProvince` (`0xEFAE6`): the walking country asks of the province's controller and owner.
  - `CNavy::MayStandIn` (`0x1CEF1E`): the fleet's country asks of the port's controller.
  - `CRebaseOrder::MayBeGiven` (`0x19B25E`) and `CRebaseAirOrder::MayBeGiven` (`0x195D4D`): **the province's controller asks of the unit's country**, as the record already said.
  - `CUnit::HasFriendlyHoldIn` (`0x1C00CA`): **the standing land unit's country asks of the moving unit's**.
  - `CUnitStatusEntry::Update` (`0x359824`), the row's `unitbase`: **the supplying province's controller asks of the unit's owner**.
- **A beaten unit's way** (`CUnit::FindRetreatProvince`): a neighbour scores 1000 where the unit's owner controls it or `CCountry::CanOperateIn` (`0xEFA00`) answers yes - on one side with it, or a co-belligerent that is not its enemy - not `IsFriend`.
- **A patrol's shadow** (`CPatrolOrder::UpdateShadow`, `0x19D08E`) lets a fleet go when its country is of the patrol's real faction, or when **its** record towards the patrol's country answers `CDiplomacyStatus::HasFriendlyAgreement` (`0x64A680`, read whole): an alliance (+0x14), military access (+0x4C), a vassal bond with either at either end (`0x648A80`, `0x648AD0`), or a guarantee either way (`0x648730`, `0x648760`).

OpenHOI3 had the rebase orders, the hold test and the panel's capital asked the other way round, and all six by its own country-and-faction rule. Made the original's, on entering the three saves and over the 48 hours of July 1941 nothing changed (165 of 167, 106 of 110, 73 of 73; 211 of 299), nor the march check (301 of 301).

## 42. A fleet carrying a transport patrols nothing (confirmed on the listing)

Read on 2026-11-11 on the running game, for the seven fleet orders OpenHOI3 gave on entering the save of July 1941 that the original did not - four British, one each American, Greek and Canadian - the same in two runs of the original.

- **The free fleets.** Phase 7 of `CAIUnit_ManageNavalUnits`, per ready fleet, after the raid or the rebase, counts its ships with `CountShipsByRole` and goes on **only where it holds no transport** (`cmp [esp+0xA0], 1`, `jnl` past the rest, 0x4D3146): then its power is added to +0x280 unless its order is a rebase, a convoy raid or 0x6E9, and it goes on the free list (`[esp+0x154]`, appended at 0x4D3222) where it is not busy or its order is a patrol (0x42E) or 0x6E8. The patrol (phase 8) and the intercept (phase 9) take their fleets only from that list. **So a fleet with a transport in it is neither counted nor sent on a patrol or an intercept.**
- Logged on entering: the original reaches the patrol phase for the Home Command, Middle East and East Africa theatres, forced, and the British fleets OpenHOI3 sent out - each with a destroyer screen and a transport - get nothing. The Soviet Moskva HQ's free list on entering held eleven fleets and its patrol took the Red Banner Baltic Fleet.
- **The patrol's centre is the C runtime's `rand()` on the thread that ran** (FINDINGS-agents.md, D): the original's patrol of that fleet is centred on 10508, the Finnish Coast, behind the Baltic strait (10517) Germany's hold of the blocker (1482) closes to the Soviet Union - so its fleet at Port Vladimir finds no way and stands, the "0.916 all day" of FINDINGS-navalmissions.md; OpenHOI3's draw is 11393 in the Barents Sea, and its fleet sails. A different draw, not a different rule.
- OpenHOI3 had counted only the power behind the transport test. With the free list behind it too, the fleet orders it gave on entering that the original did not are 1 (7 before) on the save of July 1941 and none (2) on that of August 1938.

## 43. The sealift on entering: its flag, the embark port's order, and the tally by destination (confirmed)

Read on 2026-11-11 on the running game, for Australia's 1st Cavalry Division and Transport Flotilla, which the original sends to Cairns on entering the save of July 1941 in both runs and OpenHOI3 left standing.

- **It runs on entering.** `CAIUnit::AssignAreaTargetsAndSealift` was logged with `ProcessAI` on entering the save of April 1936: called once for each of Italy's two agents, after the second of its two passes, with `reassign_areas_now` (`CAIUnit +0x5C`) set - the constructor's seed - so not only at the daily hour. OpenHOI3 ran it only at the daily hour.
- **The embark port** (`CAIUnit_PickEmbarkPort`) walks the area's provinces in their order, as the record says, keeping the first of equal means. With the cavalry inland at Orange every port is as far, so the first, Cairns (7831), wins; OpenHOI3 walked the area's ports largest naval base first and took Sydney.
- **The embark tally** that keeps a plan's embark and debark: in step 4, the area compared with the embark's is that of **the unit's destination** (`CUnit::GetMovementDestinationProvince`, 0x4C5625), or of its province with none (0x4C5630), stored at `[esp+0x48]` (0x4C5680) and set beside embark's area at 0x4C59B7. Italy's III Corpo d'Armata dell'A.O.I. in April 1936, at 9807 and on its way to 9767, keeps the Africa command's embark 9767 and debark 5511; OpenHOI3 asked where the unit stood, cleared the pair, and voted another that shipped the 7a Divisione CCNN Cirene.
- The keep-or-release logged at the same time (after 0x4C584E): every Italian division of the Africa command with its saved `target` 5511 may still be shipped; the I Corpo's 9767, in its own region group, may not.
- With the three, entering the saves gives 166 of 167, 106 of 110 and 73 of 73, Australia's division and flotilla as the original's. **Not shown**: why the original sends no transport to Italy's Metropolitana embark (10731) on entering July 1941 where OpenHOI3 sends its 2nd Navy.

## 44. Entering also places provinces into theatres (confirmed in part)

Read on 2026-11-11 on the running game, for three theatre headquarters - China's Beiping HQ, Mongolia's Nungnain Sum HQ and Britain's East Africa Command Theatre - that OpenHOI3 marched on entering the save of July 1941 and the original left standing.

- **Slot 82's pick on entering** (logged after the call of `CAIUnit_PickCommandProvince` at 0x4C0775): for every British, Chinese and Mongol theatre agent, nine in all, the province picked is the one its headquarters stands in, each agent bound with its ops area (+0x90) filled and its theatre id set - so the path is `CTheatre_PickHQProvince`.
- **`CTheatre_PickHQProvince`'s scores** (logged at its comparison, 0xB0EEB): 7519 scores 253 against 5707's 257, 7338 63 against 4980's 71, 9889 498 against 9890's 549 - the mean distance to the theatre's front provinces and the factors as the record has them, and OpenHOI3's figures to the unit for every province both scored. **OpenHOI3 never scored 7519, 7338 or 9889: none was in its theatre.**
- **The theatre's own provinces grow on entering.** Beiping's theatre lists 124 provinces of its own in the save and 134 in the save the original wrote straight after entering, 7519 among the ten; its fronts are those it had. So entering places the provinces a country holds that no theatre of its has, as `RefreshTheatreProvinces` does, and not only remakes the fronts as section 18 had it. Which routine does it on entering was not read.
- With the refresh's placing, dropping, stamping, areas and fronts done on entering - its agents' and headquarters' upkeep left out - the land orders OpenHOI3 gave on entering the save of July 1941 that the original did not are 1 (5 before), the three headquarters and the 54a Divisione 'Napoli' among those gone; over the 48 hours after it, 212 of the original's 299 (211).

## 45. A change of stance releases the reserve (confirmed)

Read on 2026-11-11 on the running game, for Japan's Zhengzhou HQ on entering the save of August 1938, the same in two runs: the original held seven divisions back, OpenHOI3 six, and the 36. Hoheishidan, free in OpenHOI3, attacked 7528.

- **Two sorts on entering**, logged where `CAIUnit::ManageSubordinates` marks a division held back - by the test (0x4B298B, which is also the path of one already held) and by the reserve's detach (0x4B3243): the first marks the 20. by the test and the 13., 10., 19. and 9. by the detach; the second marks the 20. by the test again and then the 13., 10., 19., 9., 7. and 36. by the detach. The four of the first sort come to the second unmarked, and neither slot 69 (0x4D5510) nor the recall (0x4B2CAC) touched them.
- **What clears them is `CAIUnit::SetPlanStance`** (slot 77, the write at 0x4C386A), as the record already said: on a stance posted, every division on the held-back vector has its mark cleared and the vector is emptied. The agent's first sort runs at stance 3 as it is bound; the stance pass then posts 2, the reserve is released, and the second sort decides it again at stance 2 - the committed count c / 5 rather than c / 7, seven held rather than five. The scan of the image for writes to +0x2C8 finds eight, these and the line's reserve call (0x4CAC7B) and the two observer slots.
- OpenHOI3 had posted the stance without releasing the reserve, so its second sort kept the first sort's four held and counted them out of c. With the release, Zhengzhou's held-back divisions are the original's seven in order, and on entering the save the land orders are the same 107 of 110 (106), those OpenHOI3 gave alone 2 (4); over the 48 hours after the save of July 1941, 215 of 299 (212).

## 46. The AI's model caches are never initialised, so a loaded unit's first estimate is a matter of luck (confirmed)

Read on 2026-11-11 on the running game, after entering Ireland1938_08_03_14 gave Japan's 11. Hoheishidan odds of -1.358562 on 9381 where OpenHOI3 gave 4.621, and the 2 'Sendai' 2.210562 on 5596 where OpenHOI3 gave 2.777.

- **The negative odds are the attacker's weight going negative.** Logged at the comparison of their damage with nought (0x4D9D7B): our soft-attack sum (the stack slot multiplied by the defenders' softness) was -0.2392 and our hard -0.0874 against the defender's 0.1761 and 0.0336, softness 1.0 and defensiveness term 0 on both sides, so ourDamage / theirDamage = -0.2392 / 0.1761. `strength * organisation * (engagement + model)` is negative when the attack model term falls below -1, and the record's `their damage <= 0 -> 50` is the only guard; nothing clamps our side. On 5596 the defender's defensiveness term was 21.86 and the figures reproduce 2.2106 exactly.
- **The model term was missing its cached half.** Logged at the return of the attack helper (0x4D95A6; the float comes back in XMM0): for both Japanese units the cache `CUnit +0x2DC` read 0.0 with its dirty byte `+0x2E0` clear, so the helper used 0.0 for combined arms, experience, the leader, dissent, supplies and the difficulty, and only the per-target half counted.
- **Nothing sets those bytes on a load.** Over a load and entering of Ireland1941_07_16_07, CUnit::CheckOrderAndCombat (0x1BA313, the only writer of the dirty bytes found by scanning the image for byte, dword, SIB and vector stores to +0x2D4..+0x2E0) was not called once, and `CUnit::CUnit` (0x1B5010) touches none of the four fields. Logged at the attack helper's cache test (0x4D8C92), each unit's first look: 36 units had a **junk** dirty byte - 0x77, 0xB9, 0x3D, 0x1C, ... with junk beside it in the cache (0xFFFFDC8A and the like, the defence pair one less) - and so computed the real cached half; 17 had **zero** memory and so used 0.0; 23 were first looked at on worker threads the debug-register breakpoint did not reach, and carried a computed value by the time a hooked thread saw them. The split differs between runs: one run of the 1941 save had the 207. and 209. Infanterie-Division at 0.0 and the 95. computed (0.515), the next the reverse (0.613 for both, the 95. at 0.0).
- So **the first estimate after a load uses the unit's real cached half or nothing**, by what the allocator left in memory - a fault of the original, and the likeliest cause of the two answers on 1750 in section 40. After the unit's first hour (CheckOrderAndCombat sets both dirty bytes at its top, every hour, for every unit) it is the real value again. OpenHOI3 always counts the real value: it cannot reproduce uninitialised memory, and the real value is what three quarters of the 1941 units used. A trial with the half counted as nought for every loaded unit gave 110 of 110 land orders on entering the August 1938 save and 16 ways OpenHOI3 alone gave on entering July 1941, where counting it gives 107 of 110 and 1.

## 47. A headquarters trespassing on the move is left on its way (confirmed)

Read on 2026-11-11 on the running game entering Germany1936_04_20_03, where OpenHOI3 halted Guangxi's 2nd Corps in 5836 and the original left it marching to 5802.

- Logged after `CAIUnit_PickProvinceAmongSubordinates` returns in `CAIUnit_PullHeadquartersIn` (0x4CC3F9): `CGX 2nd Corps at 5836 trespassing 1: pick 5802 against 5802`. The corps stands in Chinese-held land its owner may not enter (`CUnit +0x1A8`), and the pick answers its destination at once, as the record has it; the pull-in then compares that with what it holds in EBX and does nothing.
- What EBX holds, on the listing: `0x7AAF00(unit)` - the destination, null where the unit is not moving (0x4CC38E); a moving unit goes straight to the pick with it; a standing one is tested (a child under full reach at 0x4CC3B7, `+0x1A8` at 0x4CC3C3, the front at 0x4CC3CF/0x4CC3E0) and EBX is then the unit's own province `+0x130` (0x4CC3E9). So a target equal to where the unit is going, or standing, is left alone, as OpenHOI3 had it.
- OpenHOI3 had no trespassing mark. With it asked as the unit stands - the original makes the mark again every hour and at a change of pact - the corps is left on its way, and the standing test takes trespassing too.

## 48. A land unit the sealift has claimed is on no list but land (confirmed)

Read on 2026-11-11 on the running game, entering Germany1936_04_20_03 and Ireland1941_07_16_07.

- Logged at the top of `CAIUnit_PullHeadquartersIn`'s loop over `+0x14C` (0x4CC367), for Italy: Cdo. Sup. Africa's list has II, I and IV Corpo dell'A.O.I., the Corpo Eritreo and Libico, the Armata dell'A.O.I., the 1st Army and the 1st Army Group - and **not III Corpo d'Armata dell'A.O.I.**, which stands under the Armata with no agent of its own (`+0x198` null) and carries the sealift's target 5511 (`CArmy +0x2E8`, read live); OpenHOI3 had it on the list and pulled it from its way to 9767 to 9749. For Britain in 1941 East Africa Command's list has the 5th, 6th and 9th Corps, the 4th Army, the 3rd Corps and the 6th Army Group and **not the 7th Army**, target 9578, bound for the embark 9664.
- On the listing of slot 78 (`CAIUnit::ManageSubordinates`): every land unit is pushed onto `+0x11C` at 0x4B230E, unconditionally, and slot 86 is asked at 0x4B2705, after it; a unit it claims gets `+0x2C8` cleared (0x4B2714) and goes on no further list. So a claimed headquarters is not pulled in, and **still counts** where slot 80 cuts its list to `+0x11C` minus `+0x14C`.
- That count made one more province on Britain's East Africa hold list in OpenHOI3, which the original's has too: read live from the agent (`+0x17C` head, `+0x180` tail, `+0x184` count 8; nodes `{record, prev, next}`; records `{province, 0, score as a float, 0, flag, flag}`, the two flags 1 for every province but 10004, which Britain holds and Italy owns, and Yemen's 9768): 10066 174, 10635 132, 10195 132, 9752 132, 10004 55, 9427 55, 9786 34, **9768 33**. OpenHOI3's eighth is 9664, 33: it never considers Yemen's 9768, which the original's theatre provinces evidently hold, considered before 9664, so with the scores equal 9664 is the one cut. Why the original's East Africa theatre holds a Yemeni province was not read.

## 49. The recall from the reserve is in single precision (confirmed)

Read on 2026-11-11 on the running game entering Ireland1941_07_16_07, where OpenHOI3 sent the Soviet 18. Tankovaya Diviziya from 1354 to 1487 and the original left it standing, the same in two runs.

- Read live after entering: the 18. Tankovaya is held back (`+0x2C8` 1), and Smolensk HQ's 23 held-back divisions are, in the country's unit order, the 29. 'Sibirskaya', the 18. Tankovaya, the 206., 100., 159., 73. Strelkovaya and on; OpenHOI3 held the 115. Strelkovaya in its place.
- OpenHOI3's second sort held 26 by the test, against a surplus of 21, and recalled three - the 10. Tankovaya, the 70. Strelkovaya and the 18. Tankovaya - each scoring 1999 thousandths, the first of equals winning.
- On the listing of slot 78's recall (0x4B2B70-0x4B2C12): each held-back division's shares come from `GetUnitAverageStrengthAndOrganisation` (0x1C7250) as floats; one under organisation 0.33f (0x120A958) or strength 0.75f (0x13179A8) is passed over; the score is strength + organisation added in double and stored as a float, + 1.0 where `CArmy +0x2FC` is 8; the best is kept on a strict `comisd` against a float starting at nought. So two divisions near full strength are told apart by their float shares, which thousandths cannot do. With the recall in single precision OpenHOI3's 23 are the original's in order, and the 18. Tankovaya stays.

## 50. The sealift weighs a unit by its rebuilt definition, so a worn headquarters weighs nothing (confirmed)

Read on 2026-11-11 on the running game entering Ireland1941_07_16_07, where OpenHOI3 sent Italy's 2nd Navy from 4487 to the Metropolitana's embark 10731 and the original left it in port, in both runs.

- Logged at the top of `CAIUnit::AssignAreaTargetsAndSealift`'s sending loop (0x4C71E3): `Cdo. Sup. Metropolitana: troops 0.000 capacity 0.000`, so no transport is sent. The plan is embark 10731, debark 4768 in both saves, and the 4a Armata waits at 10731 with `CArmy +0x2E8` = 4768, not aboard - the only unit there bound for debark. The 2nd Navy is on the agent's transport list (`+0xEC`) with the 29th Navy, as in OpenHOI3.
- Its definition (`CUnit +0xC8`) is all but empty: `+0x104` 50, `+0x108` 3000, `+0x124` 1000 and nothing else, transport weight `+0x10C` nought; the VII Corpo d'Armata's, with the same kind of headquarters brigade, has weight 10000, officers, defensiveness and toughness. The 4a Armata's one brigade is an `hq_brigade` at organisation 0.000. That is `CUnit::RebuildDefinition`'s reduced path as the record has it: a land unit's brigade of no combat width at under 1.000 organisation adds its softness alone. So the sealift's weight, the definition's transport weight / 1000 truncated per unit, is nought for it, and the troops it counts are nought.
- OpenHOI3 weighed the sealift's units by every brigade's transport weight. Weighed as the brigades that count towards the unit are, the 4a Armata weighs nought and the 2nd Navy stays in port.

## 51. A loaded join_air is dead to the AI (confirmed)

Read on 2026-11-11 on the running game entering Ireland1938_08_03_14, where the original gave Italy's 5th Comando Aerosiluranti 'Eolo' (2850, at its base 5138) a `join_air` onto the 2nd Squadra Aerea (2844) at 5445, and OpenHOI3 gave nothing.

- In the save the 2nd Squadra Aerea is the one joining: `join_air` with `target` 2850 written twice, COrder's pair and the join's own. In the save the original writes after entering, the 2nd Squadra Aerea's order is gone and the Eolo holds a `join_air` onto 2844.
- Logged in `CAIUnit_ManageAirUnits`' triage where a group under order type 0x717 has its target looked up by COrder's id pair (+0x10/+0x14, the call at 0x4CDAD8, its answer at 0x4CDAE0): `2nd Squadra Aerea: target id 0 type 0 -> 00000000`. The join is dead and called off, and the regrouping then pairs the Eolo, of one wing, with the 2nd Squadra Aerea.
- Why the pair is nought: `CJoinAirOrder::LoadKey` takes every `target` key into the join's own reference (+0x80), as the record already had it, so COrder's +0x10/+0x14 are never set by a load - and the triage asks those. The order would still merge, `CJoinAirOrder::IsActive` reading +0x80; it is the AI that sees it dead. A join_fleet's COrder target is loaded by `COrder::LoadKey`, so it is not affected.
- OpenHOI3 kept the loaded target where the AI looks. With the join_air's order target set only when the order is given, the triage calls the loaded one off and the Eolo is sent to join, as the original's.

## 52. A puppet's focus area is held province by province (confirmed)

Read on 2026-11-11 on the listing of slot 80 (`CAIUnit::RebuildHoldProvinces`), after section 48 found Yemen's 9768 eighth on Britain's East Africa hold list entering July 1941, where OpenHOI3 had 9664.

- Yemen is Britain's puppet (`vassal` ENG/YEM in the save), and its five-province area holding 9768 is one of the East Africa agent's focus areas (`+0x338`). Yemen's army and headquarters stand in 9750 and 9808, inside that area.
- The puppet arm walks the area **province by province** (0x4B3F70-0x4B4084): a province already listed is passed over; then over the puppet's unit list (`CCountry +0xBAC`), for each land unit (slot 15): one standing in the province (`+0x130`, 0x4B3FD2) or whose path's last node (`+0x13C`, 0x4B3FE7) is the province skips **that province**; the rest are scored (0x4B4200) and kept at 0.1 and above. So one Yemeni unit in 9750 keeps 9750 off the list and leaves 9768 on it.
- OpenHOI3 skipped the whole area where any of the puppet's land units stood or was bound in it. Province by province, the British 3rd Corps is pulled in to 9597 entering July 1941, as the original's; the agents check from the start save to 4 January 1936 is unchanged.

## 53. Whose `rand()` a patrol's centre is drawn on (measured)

Read on 2026-11-12 on the running game entering Ireland1941_07_16_07, for the two fleet orders still apart: Britain's 23rd Navy, patrolling round 10582 in the original and 10586 in OpenHOI3, and the Soviet Red Banner Baltic Fleet, standing in the original and sailing in OpenHOI3. Both runs of the original agree on both.

- Logged after the C runtime's `rand()` (0x7A7F3F: `holdrand = holdrand * 214013 + 2531011` in the thread's data at +0x14, bits 16-30) returns in `CAIUnit_ManageNavalUnits`' patrol phase (0x4D33EB), with |V|, the thread's data block (ECX) and V, for every agent that drew: twenty draws on five threads. Four blocks start at 41 and go on 18467, 6334 - a fresh thread's stream, seed 1 - one of them serving France's and Italy's agents, the others agents of countries not identified. The main thread's block serves, in this order, Germany's Berlin and Trondheim HQs, Britain's Home Command, Middle East Command, a one-province agent and East Africa Command, the Soviet Union's Smolensk and Moskva HQs and the United States' three theatres, and its stream is far on: Berlin HQ drew 13030 from a held 0x32E6E0C2.
- Britain's Middle East Command drew 1229 over V = 10583 10584 10573 10585 10586 10582: 1229 % 6 = 5, the centre 10582, the 23rd Navy's patrol. Moskva HQ drew 20857 over V = 10507 11396 10508 11393 10509: 20857 % 5 = 2, the centre 10508 - the Finnish Coast, behind the Baltic strait closed to the Soviet Union - so the Baltic Fleet given the patrol finds no way and stands, as section 42 had it.
- So which countries draw on the main thread and where its stream stands are what decide the two, and the main thread's stream carries every `rand()` it has made since the process began. Two fresh launches entering the same save gave the same two orders; nothing a game could carry reproduces the stream.

## 54. Which joining unit supports instead of marching (measured)

Read on 2026-11-12 on the running game, for the attacks the 48 hours after Ireland1941_07_16_07 differ on: OpenHOI3 had a third German division at 1576 marching on 1577 and a sixth attacker on 2102 where the original's saves show them standing, and lone British divisions attacking broken Italian defenders - the 12th at 5506 in the 14th hour, the 4th at 5484 the hour it reached 5485 - where the original's held back for the whole 48 hours.

- Logged in `CAIUnit_ManageLandUnits` for Germany's and Britain's agents, the save loaded and run 31 hours: each target's first odds (0x4D73A8, `[ebp-0x1C]`), each unit joined (0x4D78E8: the unit `[ebp-0x24]`, where it stands, the flag in `bl`, the odds after `[ebp-0x40]` and before `[ebp-0x1C]`) and the decision (0x4D7963: stance `[ebp-0x38]`, the friendly region groups `[ebp-0xAC]`, may attack `[ebp-0x1D]`, the odds, the second list's count `[ebp-0xBC]` and the attackers' `[ebp-0x50]`).
- The flag is the one FINDINGS-aiconsumer.md calls `mustStay`, and as that write-up warns the name is the wrong way round: a unit flagged 0 goes on the second list (0x4D7880-0x4D78C4), and the second list's units get the `support_attack` order while the rest march. At the 14th hour, 1577: the 31. and 183. Infanterie-Division at 1576 flagged 1, the 212. flagged 0, odds 1.390, 2.201, 2.418, two of three free to march - so the 212. supports, which is what the save shows as a division standing. 2102: SS-Verfügungstruppe, the 168., the 3. Panzer-Division and the 197. all flagged 1. 5506: the 12th 'Eastern' Division alone, flagged 0, odds 50 (the defenders two Italian headquarters at nought organisation) - one attacker and one on the second list, `movable.count < attackers.count` false, no attack; the same every three hours, and at the 29th hour the 4th Infantry Division, just arrived at 5485, offered 5506 and flagged 0 too.
- The flag, read off 0x4D764E-0x4D7852: 1 unless the unit's `ai_uncovered_enemy_neighbours` (`CUnit +0x2BC`) is above nought and its province's `supply_depot_id` (`+0x48`) is not nought - a province that **draws on** a depot, not one that is a depot, which FINDINGS-aiconsumer.md's pseudocode put as "has a supply depot". Then it walks the units of the province (`+0x2B8`) for a stand-in, which sets the flag to 1: a land unit (slot 15) of a country with an id, not the rebels; of the agent's own country, or else one whose `CDiplomacyStatus` (our `+0xE28` by its id) has `co_belligerent` (`+0x58`) set and no `war` (`+0x20`), neither tag `REB`; in no battle (`+0x11C`); not the unit itself; not refused by the agent's slot 86; its slot 9's `+0x2FC` not nought; bound nowhere (`CUnit_GetPendingDestinationProvince`); and **not already in the attackers list** (`[ebp-0x58]`, walked at 0x4D779E). With no stand-in, the flag is 1 where the unit's province is on the agent's `target_area_provinces` (`+0x1CC`, 0x4D7823), else 0.
- So of three units in one province the first two joined each have a stand-in in the units not yet joined and march, and the last supports; and a lone unit flagged 0 never attacks.
- OpenHOI3 had it as a depot province where the original asks for a supplied one, counted units already joined as stand-ins, and with a stand-in or none answered the target-area test the wrong way round. Mended there, the 48 hours give 221 of the original's 299 land orders the same where 214, and 110 of OpenHOI3's alone where about 142; the three entering saves are unchanged but for two orders of OpenHOI3's alone gone in August 1938.

## 55. The AI's per-unit combat modifiers, with their caches fresh (measured)

Read on 2026-11-12 on the running game, 31 hours after loading Ireland1941_07_16_07, for section 6's Soviet estimates that stood about 4% apart from OpenHOI3's - read then in the first hours after a load, where section 46 later found each unit's cached half uninitialised.

- `AICombatEstimateAttackValue` logged at its one call (0x4D95A1: the unit in ECX, the target, `ownBrigades` and `ownProvinceCount` at `[esp]`, `[esp+4]`, `[esp+8]`) and its answer after (0x4D95A6: XMM0, a float - the caller widens it with `cvtss2sd` at 0x4D95B1), keyed by ESP since the AI runs on several threads; `AICombatEstimateDefenceValue` the same at 0x4D9A2D/0x4D9A32 (the unit in EAX, the crowding less three a province at `[esp]` and the enemy's provinces at `[esp+4]`, signed - -1 and -2 occur). The game saved at 14:00 and the attackers logged in the 15:00 pass; saved at 17:00 and the defenders logged in the 18:00 pass.
- Set beside OpenHOI3's on each save as loaded (its `OpenHOI3.SaveCheck load ... model=`): the Soviet Union's 83 attackers' modifiers all the same, Germany's 100 all the same but where crowded, and there each 0.050 higher in the original. Germany's land doctrines give `unit_cooperation` 0.05, which both helpers take off the stacking as `country->technology_status->free_stacking_allowance` (FINDINGS-aihelpers.md); OpenHOI3 had left it out. With it, and the country taken as the lender's for a lent unit as the helpers do, 100 of 100 and 83 of 83 attackers, and 56, 53 and 21 defenders of Germany, the Soviet Union and Italy, 130 of 130 - every value to the thousandth.
- So nothing is missing from the per-unit modifier once the cache is fresh; the 4% of section 6 was, most likely, cached halves still nought in those first hours (inferred - it was not logged again in the first hours).
- The land battle's crowding takes `free_stacking_allowance` off too (FINDINGS-combatmods.md, BM_DIVISION_PENALTY), which OpenHOI3 had also left out and now takes off. That one was not logged here: over these 48 hours it changes nothing in OpenHOI3's run.

## 56. A new game's first air regrouping: who is a candidate, and what asks for a regroup (measured)

Read on 2026-11-12 on the running game, from a new game of the 1936 bookmark started as Germany with nobody at the machine (`probes/hoi.lua`'s `hoiNewGame`: Single Player, CGameSetup::OnProvinceClicked with Berlin, CGameSetup::OnPlay) and saved every hour to 4 January 12:00 (`hoiSeries`). The question was OpenHOI3's 4 January check: Japan seven air units where the save has six, Italy nine where it has ten, and Italy's three intercepts ending an hour early.

- **A new game's agents, as a load's (section 39).** Logged on `CAIUnit::Tick`, `CAIUnit_ManageAirUnits` and the write of `full_pass_pending` in `CAIUnit::SetArea` (0x4BBA17), for Japan (id 6) and Italy (id 8): nothing ticks while the game is entered; at 01:00 each agent ticks with no unit and is bound at the end of the pass - SetArea, full_pass_pending set; at 02:00 the full pass, the air body called with `force` 1 and every agent's `regroup_air_pending` still the constructor's 1; at 03:00 no force.
- **Attaching an air unit sets `regroup_air_pending`.** At 03:00 the Kwantung Army's flag was 1 again though its 02:00 regroup had cleared it (gate 0x4CE64F with 1, hinge 0x4CEDA8 with 0) and nothing in the air body had set it. A write breakpoint on the agent's +0x88 caught the writer: `CUnit_AttachToParent` at 0x1B9A0A. After the child is hung under its parent, the nearest agent above (`CUnit_FindNearestAgent`, 0x1B6E60) is asked its slot 65 - true for a unit agent - and given `replan_subordinates` (+0x86) = 1 (0x1B99F6); then, where the child answers CUnit slot 17 (`IsAir`), `regroup_air_pending` (+0x88) = 1 (0x1B9A0A). A scan for `mov byte [reg+0x88], 1` finds it beside the three in the air body - 0x4CEA1D and 0x4CEA30 in the split, and **0x4CEC0F in the merge**, which the record did not list - and the constructor's seed. So Japan's two Zerosen groups, orphans attached under the Kwantung Army at 02:00, are regrouped at 03:00: 1 Zerosen joins 2 Zerosen (logged at 0x4CEC0F: the group `[ebp-0x28]`, the partner `[ebp-0x3C]`), and at 04:00 the pair joins 3 Zerosen at 4691.
- **At peace every group is the triage's candidate.** At 0x4CDBCB the triage tests the country's `at_war` (+0xACC) and `in_undeclared_war` (+0xACD); with both clear, or with no base (+0x98), a group not joining a live partner goes straight onto the candidate list (0x4CE0EC) - no test of strength, organisation, rest or order. Only a country at war has its groups' wings measured (strength share against `[ebp-0x118]` and `[ebp-0x9C]`, organisation share against `[ebp-0x40]` and `[ebp-0x1C]`): an unfit busy group called off (0x4CDF76), a damaged or tired idle group at its own base left resting (0x4CE003), a blocked or fighting one passed over (0x4CE03B, 0x4CE062), the rest listed (0x4CE087).
- **The split and the merge walk the triage's candidates** (`[ebp-0xD0]`, taken into EDI at 0x4CE148), each passed over in a battle (+0x11C), away from its own base (`CUnit_IsAtOwnBase`), under a blocking order (`UnitHasBlockingOrder`) or on the handled list - no test of fitness of its own. A partner is any group of the agent's air list (+0xFC) not handled, neither with strategic attack above 50.
- So Japan, at peace, merges its bombers at the full pass of 12:00 though they landed at half their organisation (40 to 20 at 05:00 and 06:00); Italy, at war with Ethiopia, does not join Aeronautica AOI to the 1st Air wing at 15:00: the regroup walk logged at 0x4CE6C4, 0x4CE6E6 and 0x4CEA46 takes up the 3rd Air wing and the 4th Squadra Aerea and not AOI, whose tactical wing alone, its interceptor split off at 14:00 and with it the halving of the bars, rests.
- OpenHOI3 had neither: an attach set only replan-subordinates, and the regroup walked every air group with a fitness test of its own. With both built, its 4 January check against this new game's save of the hour gives air units 101 of 101 countries and the Italian intercepts' end hours 3 of 3; against the maintainer's save of the same hour Italy's count is the save's and Japan's 7 to 6 and the intercepts' hour are that game's own. The three entering saves and the 48 hours after July 1941 are unchanged.

## 57. A new game's fleet regrouping: a fleet that split is handled, and a fleet just sent is not ready (confirmed)

Read on 2026-11-12 on the running game's code beside section 56's hourly saves of a new game. At its third hour OpenHOI3's fleet counts were the original's for 99 of 101 countries; the two apart were New Zealand (two fleets where the original has one) and Canada (three where it has four).

- **Canada.** At the second hour both split two transports off the Canadian Transport Fleet; OpenHOI3 then had the Royal Canadian Navy, a lone destroyer, join the transport fleet, and the original left it alone. In `CAIUnit_ManageNavalUnits`' split and merge (0x4D19F6), each fleet walked is passed over when retreating (+0x158), in a battle (+0x11C), with no ship (+0x40), already on the handled vector (0x4D1A39), under a blocking order (`UnitHasBlockingOrder`, 0x4D1A9A) or away from its own base (`CUnit_IsAtOwnBase`, 0x4D1AA7); after its split loop, where a ship went (`[esp+0x1F]`), the fleet is pushed onto the handled vector (`std::vector_pushBackByAddress` at 0x4D1D29, the vector at `[esp+0x68]`) - so it is no partner for a later fleet's merge, though it goes on to look for one itself. The merge then asks no transport left by the split's count (`[esp+0xA0]`, 0x4D1D37) and **fewer than 6 ships by the fleet's own count** (+0x40, 0x4D1D45), the ships split off still aboard until their commands run. The Canadian Transport Fleet (5174) is walked before the Royal Canadian Navy (5176), splits, and is handled; the destroyer finds no partner.
- **New Zealand.** At the second hour the sealift sends HM New Zealand Navy, five transports, to the embark port 7990; the original keeps it whole, OpenHOI3 split a transport off. `CAIUnit::AssignAreaTargetsAndSealift` sends a transport fleet by `CEU3AI::MoveUnit(fleet, embark, 0, 0, 0, 0)` at 0x4C7396, and it runs before `CAIUnit_ManageNavalUnits` in the tick (row 18); `UnitHasBlockingOrder` reads the destination +0x2CC, which OpenHOI3 takes the AI's move to write at once (FINDINGS-moving.md A.4c). OpenHOI3's sealift had posted a bare move command, leaving no such mark, and its regroup asked the path.
- With the split fleet handled, the ship count as it stands, a fleet bound anywhere not ready, and the sealift's send made the AI's own move: the third hour's fleet counts 101 of 101 and every division where the original has it, 908 of 908; the 84th hour's fleets 99 of 101 (98); the three entering saves, the 48 hours after July 1941 and the maintainer's save of 4 January unchanged.

## 58. The attack's candidates: a garrison standing still is one (measured)

Read on 2026-11-12 on the running game, in a new game's second hour, for Italy's attack on 9987 in Ethiopia: the original sends the 6a Divisione CCNN Tevere and the Divisione Libia, OpenHOI3 had sent only Tevere - Libia was picked a garrison in the same hour, and its attack passed garrisons over.

- Logged in one run, in order: the garrison pick in `CAIUnit_SplitGarrisonAndLine` (0x4C8E31, `mov byte [eax+0x2C9], 1`), each unit joining an attack (0x4D78E8) with its `ai_garrison` (+0x2C9) at that moment, and each decision (0x4D7963). Libia is picked for Cdo. Sup. Africa, and three lines later added to the attack on 9987 **with +0x2C9 = 1**.
- The candidate gathering, read on the listing: `CUnit_GetPendingDestinationProvince` at 0x4D6C73; **with none it jumps to 0x4D6D1D**, past the test of the destination's controller (`IsEnemy`, 0x4D6CD3), the garrison test (0x4D6CE0) and the walk for the nearest agent above the unit (0x4D6CEC-0x4D6D17). So those three apply only to a unit already bound somewhere; a unit standing still is a candidate whether it is a garrison or another agent's - the latter scored / 10 (FINDINGS-aiconsumer.md has the score). FINDINGS-aiconsumer.md's pseudocode had the three unconditional.
- The candidate list is kept **ascending** by the score at +0x2B8: the walk at 0x4D7166 inserts a new candidate before the first whose score is greater (`ja` at 0x4D7186), equals after. FINDINGS-aiconsumer.md had "descending"; OpenHOI3 already took the lowest first.
- Built in OpenHOI3: neutral on every check it has - the three entering saves, the 48 hours after July 1941, both 4 January comparisons. At the new game's second hour Libia now joins the attack on 9987 as the original's does; Tevere, scored above it there, is then turned away as enough, where the original sends both - the original's Tevere is first, which its score at +0x2B8 would make so only bound somewhere already (/ 5) or with another neighbour count; not followed further here.

## 59. Italy's second hour in a new game: the dead end's sea, the sealift's records, and the AI's own generator (measured)

Read on 2026-11-12 on the running game, a new game's second hour, for Cdo. Sup. Africa and Cdo. Sup. Metropolitana, whose orders were the original's but for an attack on 9807, the line, and the sealift's targets.

- **The targets.** Each target record logged as `CAIUnit_ManageLandUnits` makes it (0x4D66E4: the province `[ebp-0x28]`, the weight `[ebp-0x18]`): 9959 501.84, 9979 550.00, 9987 503.46, 9825 129.33, 9785 238.53 - OpenHOI3's five to the thousandth, and no 9807, which OpenHOI3 also listed at 190.48.
- **The dead end's sea**, read on the listing (0x4D6104-0x4D625C): walking the single approach e's edges (kind 3 left out, simulated provinces only), a sea province counts only where p's template has its coast flag (+0xA0) and **p has an edge to that same sea province** (the count in EBX, 0x4D61C7); a land neighbour counts where `CCountry::CanOperateIn` answers for its controller; the rule goes on only with fewer than 3 of those and no shared sea (0x4D624C, 0x4D6259). FINDINGS-aiconsumer.md had "a sea-edge count via p->tmpl->+0xA0"; OpenHOI3 had counted any sea beside e. 9807 is inland behind Eritrea's coast, its single approach 9767 on the coast: no shared sea, the cul-de-sac is redundant, and below stance 3 it is dropped - so Pusteria is not sent.
- **Every AI move**, logged at `CEU3AI::MoveUnit`'s entry with its caller: the line (`CAIUnit_FillLinePositions` +0x13D3 and +0x1A6A), the headquarters pulled in, the sealift (+0x2DC6 for 23 Marzo to the embark port 9767, +0x302B for the 19a Squadra di Marina), the agent's own unit, and the attack (+0x22C3). The line's second call sends Tevere to 9960 before the attack, which is why the attack scores it a fifth and takes it first for 9987; not built in OpenHOI3 yet.
- **The sealift's targets**, logged at the fill's write of `CArmy +0x2E8` (0x4C6484: the unit in EAX, the province in ESI): Cacciatori delle Alpi to 4658 (Olbia), Livorno to 4171 (Zadar), 23 Marzo to 5138 (Rodos), 2a Divisione Eritrea to 10731 (Dodecanese). OpenHOI3 had the first two swapped and seven divisions for Xarardheere in Somaliland. Two things: the records of the country's own areas, read on the listing at 0x4C5AD7-0x4C5B4B - **a new record whose deficit equals the head's and whose area has more provinces (+0x2C) than the head's goes in front** (0x4C5AF1), otherwise the sorted insert `0x4DD740`, as FINDINGS-moving.md F.5 had and OpenHOI3 had not built; and FINDINGS-moving.md F.5 step 4's rule that no enemy area beside the candidate's own may touch the target area, with the +50 for each sibling anchored there, which OpenHOI3 also lacked - Eritrea's enemy neighbour Ethiopia touches Somaliland.
- **The AI's own generator.** The convoy raid's draw (`MT19937Next` at 0x4D2BBF) and the invasion ranking's (0x496A0B) both pass the game state's +0x124 (`mov eax,[g_CCurrentGameState]; add eax,0x124`), and `MT19937Next` keeps its 624 words and its index (+0x9C0) in the object it is handed - so that generator is a second stream beside the static one at 0x1310F80 that battles and espionage draw on, as the record's entries for the trading roll, the AI's answer to an offer, the ministers' countdowns, the foreign minister's scopes, `CAIIntel` and `GetAIRand` already said. The patrol's centre is the C runtime's `rand` (section 53). OpenHOI3 had one generator for all of it, so a change to the AI moved every later roll - the Spanish Civil War, one run, had broken out by 4 January.
- Built in OpenHOI3: the dead end's shared sea, the records' head rule, the enemy-area rule and siblings, and the AI's own generator. In the new game's second hour Italy's targets are the original's, its sealift's targets the original's but for 1a Divisione Eritrea where the original sends the 2a, and 23 Marzo marched to the embark port; at the third hour 103 of 106 plans have the original's embark and debark (99); at 4 January 102 of 106 (97), and no civil war in Spain.

## 60. Italy's line in a new game's second hour: the send's reach is the areas' (measured)

Read on 2026-11-13 on the running game, a new game of the 1936 bookmark started again (`probes/hoi.lua`'s `hoiNewGame`) and run to its second hour, for Cdo. Sup. Africa, whose line OpenHOI3 filled otherwise: the original sends four Eritrean divisions to 9734 and the 29a Divisione 'Piemonte' to 9980 and pulls the 6a Divisione CCNN Tevere to 9960, where OpenHOI3 sent two to 9734 and Piemonte to 10003 and pulled nobody.

- **What was logged**: every `CEU3AI::MoveUnit` (0x49A840) whose return address lies in `CAIUnit_FillLinePositions`, the unit's name (`CUnit +0x16C`) and the province (its id is the second argument), with the fill's position list as it stood. The list is the fill's second argument (`[ebp+0xC]`): a chain whose node holds the record at +0 and the next node at +8; a record holds its province at +0 (a `CMapProvince*`, id at +0xD0), the want at +0xC, the have at +0x10, the standing at +0x14 and the cap at +0x18. At the pull's call (0x4CA945) the unit is in EDI, the target province in ESI and the target's record at `[ebp-0x50]`.
- **Before the send** the records stood (want/have/standing/cap) 9767 5/5/5/5, 10003 2/1/1/5, 9960 1/0/0/5, 9734 1/0/0/5, 9980 1/0/0/5, 9995 1/2/2/5, 9749 1/7/7/5. The send (+0x13D3) took the 32a 'Marche', 19a 'Venezia', 24a 'Pinerolo' and 27a 'Brescia' to 9734, its have going 1 to 4 at a want of 1, and Piemonte to 9980; the pull (+0x1A6A) took Tevere from 9995 to 9960.
- **So the send's reach refuses 9960 and 9980 to the divisions in Eritrea**, though both were empty and by far the lowest key (the distance times have/want + 0.1, about 80 against 9734's 125 to 350): no land of Italy's joins Eritrea's areas to Somalia's, Ethiopia lying between. That is `CMapProvince::CanUnitReach`'s answer for a land unit, the areas joined and no way sought, as `FINDINGS-balancing.md` read it - for the send as for the pull. OpenHOI3 asked the safe way, which went through thinly held Ethiopian land: it chose 9960 for Venezia and 9980 for Pinerolo, its very safe move then found no way and posted nothing, and both positions counted filled, so the pull had nothing to fill.
- Built in OpenHOI3: the send's and the pull's reach asked by areas. The second hour's line is then the original's move for move, and the attack on 9987 takes Tevere first as the original's; on 4 January 857 of 908 divisions stand where the save has them (854) and 450 of 542 are bound for its province (447); entering and the 48 hours after July 1941 are unchanged.

## 61. The sealift's score: single precision, and the area of operations asked where a division is anchored (measured)

Read on 2026-11-13 on the running game, the same new game's second hour as section 60, for Cdo. Sup. Africa's sealift, which OpenHOI3 filled with the 1a Divisione Eritrea for the Dodecanese where the original takes the 2a.

- **What was logged**: each candidate at the fill's comparison in `CAIUnit::AssignAreaTargetsAndSealift` (0x4C63E6, before `comisd` at 0x4C63F6): the unit at `[esp+0x5C]`, the best score so far, a single at `[esp+0x54]` (the candidate's own is a single at `[esp+0x3C]`, in XMM0 at that point), and the province the x0.25 test asks of the agent's area of operations (`[esp+0x28]`, a `CMapProvince*`, looked up in the agent's +0x90/+0x94 vector at 0x4C63B0-0x4C63D4). x2 for a garrison is `mulsd` by a constant at 0x4C63A6, x0.25 at 0x4C63DA, both through double and back to a single.
- **The best so far**, for Rodos: 16.751 after the 32a 'Marche', 54.254 after the 4a CCNN '3 Gennaio', 434.042 after the 1a CCNN '23 Marzo'; for the Dodecanese: 54.004, 54.005, then 69.005 after the 1a Divisione Eritrea, which the 2a beat. Worked back through the score of `FINDINGS-moving.md` F.5 (surplus + the rating + twice the rating for an area with no neighbour, x0.25 or x2), the ratings are 70.007 for 23 Marzo and about 90.0067 for the 1a Eritrea: `RateUnitAsGarrison`'s mean strength share is a single, about 0.9999, where OpenHOI3 had it in thousandths (0.999), giving 70.070 and 90.090 to both Eritrean divisions alike - a tie the first in the list won. With the rating as the garrison pick already has it in single precision (section 35) and the score kept as a single, the 2a scores 69.0068 to the 1a's 69.0045.
- **The x0.25 asks where the division is anchored**, not where it stands: Marche, at 9721 and just sent to 9734 by the line, was quartered (16.751), and the province asked for it was not 23 Marzo's, which stands at 9721 too and was not quartered. F.5 step 5 has "if it stands on an ops-area province".
- Built in OpenHOI3: both. The second hour's sealift is then the original's, the Dodecanese's division the 2a Divisione Eritrea; entering, 4 January and the 48 hours after July 1941 are unchanged.

## 62. The sealift's debark vote: the hash map's walk, and what varies from run to run (measured)

Read on 2026-11-13 on the running game over three runs of the same new game, each to its second hour, where the plans' embark and debark are first chosen. OpenHOI3's 4 January check had four plans otherwise: Britain's Army of India, Japan's Imperial General Headquarters, Republican Spain's Madrid HQ and Australia's Home Forces Command.

- **What was logged**: the vote's walk in `CAIUnit::AssignAreaTargetsAndSealift` (0x4C6BF6: the target in EDX, its votes in ESI, the best so far in EDI - `cmp esi, edi; jle`, and only then the tried list at `[esp+0xA0]`, so a target already tried keeps its place and is passed over at the walk); each vote as it goes in (0x4C6BB8, just after the map's subscript `0x4DD0A0` - the map on the stack at `[esp+0xE8]`, `EDI` pointing at it, the key at `[esp+0x18]`, the target `CArmy +0x2E8` of the unit), with the map's list in its order from the sentinel at `[esp+0xEC]` (node +0 the next, +8 the key, +0xC the votes); and `CAIUnit_PickEmbarkPort`'s comparison (0x4C3C3C: the port in EBX, the best mean a single at `[ebp-0x1C]`; the mean is each naval distance / 1000 summed as singles and divided by the count of troops). **The AI runs countries on more than one thread**: the walks of two countries interleave in a log, and are told apart by where the best so far starts again from nought.
- **The walk's order**: in a run, Australia's votes went in as 6509, 6536, 10328, 10262, 10302, 6518, 6582, 6545, 6439 and the list read 6509, 6536, 10328, 6518, 6582, 10262, 10302, 6545, 6439. That is the runtime's `stdext::hash_map<int>`: the key scrambled by `hash_compare` - xor 0xDEADBEEF, `ldiv` by 127773, 16807 x rem - 2836 x quot, plus 2147483647 where below nought - and put in one of eight buckets by its low three bits; a key whose bucket is empty goes to the end of the list, any other into its bucket's run in ascending order (6536 and 10328 share bucket 1; 6518, 6582, 10262 and 10302 bucket 7). Another run's Australian walk, 6431, 6439, 5905, 5920, 6536, 6422, 10302, 6467, fits the same rule (6431 and 6439 bucket 0, 5920 and 6536 bucket 1, 6422 and 10302 bucket 7), as do Spain's, Britain's and Italy's. **Every count was 1** but Japan's five for Sapporo, so the first in the walk is the debark.
- **What varies between runs**: Australia's targets were 6509 ... 6439 in one run and 6431 ... 6467 in another; Spain's votes went in 9590, 9569, 5002 in one run - 9590 its debark - and 9569 first in another, as the hourly saves' run has it; the Dutch East Indies' second division was given 7780 (Ambon) in one run and 7744 (Mankowari) in another; and Japan's port pick saw only 10653 in one run where the hourly saves' run has 10651. So of the four plans the 4 January check had apart, three are the original's own run-to-run spread; OpenHOI3 matches one run or another on each.
- Built in OpenHOI3: the vote walks the hash map's order (`CStdHashMap`), a tried target kept in place. Australia's debark is then the hourly saves' 6431; the Dutch East Indies', 6420 there, becomes 6380, its second target being Tarakan where both runs of the original had another; entering and the 48 hours after July 1941 are unchanged.

## 63. Two runs of one new game to 4 January, and the sealift's boarding and sailing in one pass (measured)

Read on 2026-11-13. The new game of section 62's last run was taken on unwatched to 4 January 12:00 and saved, a second run beside the hourly saves' first; OpenHOI3's new game was then set beside both. **Where the two runs agree and OpenHOI3 does not, the difference is OpenHOI3's; where they disagree, it is the original's own spread.**

- **Shared by both runs**, with the same examples in each: the United States' fleets (42 here, 44 in both) and Republican Spain's (6, 5); Britain's Army of India plan (5762 and 9961 in both), with the 4th and 8th Indian divisions bound for 5762 and Ceylon Command's place; five Soviet divisions' places and ways; two British air units' bases the other way round and one Japanese; and the theatres' power figures. **Apart between the runs**: Australia's debark (6431 in one, 6509 in the other) - beside section 62's Spain, the Dutch East Indies and Japan's port.
- **The Army of India**: the 1st Transport Ship Squadron leaves Madras at the second hour in both games and is in Colombo by 2 January about 12:00 in both. The original's Ceylon Command is aboard at 3 January 09:00 - the theatre's pass - and the squadron's path to debark is set in the same hour (the hourly saves: aboard at 18:00 by the save's count, `path` 12050 ... at once, at sea at 20:00 of the save's count), so the load and the order to sail go out in one pass and the load runs first. OpenHOI3 boarded at that pass and sailed only at the next, a day later, its sailing waiting for passengers already aboard. With the plan cleared once nobody bound for debark was left at embark, the original chose 5762 and 9961 the day before OpenHOI3 could.
- Built in OpenHOI3: a fleet at embark taking troops aboard in the pass sails in the same pass. Ceylon Command is then where both runs have it on 1 January 20:00 and 4 January 12:00, the Army of India's plan is the original's, and on 4 January 453 of 542 divisions are bound for the hourly saves' province (449); entering and the 48 hours after July 1941 are unchanged. The original's own step after boarding - `0x4D4D40` (unload or merge) else `0x4D42D0` (the sailing), `FINDINGS-moving.md` F.7 step 6 - is still not read; this is what its result is in one case.

## 64. The naval body's rebase: a base outside the theatre, the commander's area and distance (measured, read on the listing)

Read on 2026-11-13 on the running game, a new game's first eleven hours, for the United States' fleets, one fewer in OpenHOI3 from 2 January in both runs of section 63: the 2nd USN Submarine Fleet, one submarine based at Manila, sails for Honolulu (5825) in the original from the eleventh hour and is merged into another fleet in OpenHOI3.

- **Who orders it**: `CEU3AI::IssueUnitOrder` (0x49ABD0) logged with its caller, the rebase token 0x6DE: all 62 rebases of the first eleven hours come from the naval body's rebase (the call at 0x4D313C), the submarine fleet's among them at 1936.1.1.11, to 5825.
- **The step's entry, read on the listing (0x4D2D8B-0x4D2EFA)**, which `FINDINGS-airnaval4.md` had as "skipped for any fleet holding a submarine, and skipped when the current port is not overcrowded": a fleet whose order blocks (slot 0x60) is passed over; a fleet on a vector at `[esp+0x244]` goes straight to the scoring (not followed); then, with the agent's theatre at `[esp+0x80]`: **a fleet with no base, or whose base province's theatre (`CMapProvince +0x380/+0x384`) is not the agent's theatre (`CTheatre +8/+0xC`, compared by `CObjectId_Differs` at 0x4D2E25), goes to the scoring whatever it holds**. Only past that does a submarine aboard (the count at `[esp+0x9C]`) end it; then a fleet whose base has no province, or whose base province lies in another area than its commander's province (`CUnit +0x1E0` -> `+0x130` -> `+0x2B4`), goes to the scoring; and otherwise only where its base is crowded (ships based there and arriving above level / 1000 + 2).
- **The scoring (0x4D2F07-0x4D3141)**: over the theatre's ports (`CTheatre +0x94`), each in the **commander's area**; the score is the distance from the port to the **commander's province** + 10.0 (a single), + 2000 x the ships over the port's level, x 0.75 for the fleet's own base, the least that `CMapProvince::CanUnitReach(port, fleet, 0, 0)` answers for winning. A fleet sent is added to its new port's arrivals and **taken off its old base's**. The record's comment said "DistanceBetweenProvinces(candidate, fleetParentProvince)" and OpenHOI3 had measured from the base instead, filtered by the base's area, and never subtracted the departure.
- Manila is the Philippines', in no theatre of the United States, so the submarine fleet is rebased to the Pacific Theater's port nearest its commander - Honolulu.
- Built in OpenHOI3: all of it. The United States' fleets are then the original's at every hour to 4 January; on 4 January 858 of 908 divisions stand where the save has them (856); entering is unchanged; over the 48 hours after July 1941 two fleet orders that were OpenHOI3's alone become the original's and two others of a British fleet's mission are new.

## 65. France's transport fleet: an empty transport's order cancelled, its fuel, and a join that catches a moving fleet (measured, read on the listing)

Read on 2026-11-13 on the running game, a new game's first fourteen hours, for France's fleets - one more in OpenHOI3 from 2 January in both runs of section 63: a light cruiser ordered to join the Flotte générale de transport, which in the original it caught and in OpenHOI3 chased to the end.

- **The hourly saves**: the transport fleet, rebasing from 4229 to Bordeaux (3479), **loses its rebase order at 1 January 13:00**, mid-voyage, and sails on with no order; at 2 January 00:00 its fuel is 0.191 and its supplies 0.855, and it then crawls - about 2 of movement an hour - so that it stands at 10562 until after 2 January 12:00, where the cruiser has joined it by then. The United States' submarine fleet of section 64 keeps its rebase order all the way.
- **Who cancels it**: `CEU3AI::MoveUnit` and `IssueUnitOrder` logged for that fleet: at 1936.1.1.13 the naval body issues the order token 0x18D (`none`, at 0x4D19A8) and then `MoveUnit(fleet, its base, 0, 0, 0, 0)` (0x4D19BD).
- **The step, read on the listing (0x4D14E5-0x4D19C2)**, over each fleet: one whose order does not block (slot 0x60) is passed over while it moves (`+0x2CC`), so a fleet the AI moved with no order is never turned back here; one whose order blocks goes to the checks at 0x4D1628. A `join_fleet` (0x6E5) is set aside with the fleet it joins. **Then any fleet holding a transport (a ship whose definition's +0x30 is set), carrying nothing (`+0x2EC`) and with `+0x2CA` clear is cancelled, whatever its order** (0x4D1822-0x4D1854); then a convoy raid (0x6E9) or escort (0x6E8) away from war or an undeclared war, an escort whose convoy no longer resolves, a patrol (0x42E) at peace; then, for a fleet not moving, an order standing at its base (`0xF1DC30`) or an intercept (0x6E6). **The cancel is an order of `none` and a plain move to the base**, which leaves the fleet no order. OpenHOI3 cancelled only an empty fleet's `transport` order, and by giving it a rebase to its base.
- **The fuel**: with no rebase order the fleet draws on its base, Bordeaux, and not on the capital as a rebasing fleet does (`FINDINGS-supplypass.md`, which had this) - OpenHOI3, still under its rebase, drew 1.000 on Paris. With the cancel built OpenHOI3 draws 0.191 at 2 January 00:00, the original's figure.
- **The join**: `CJoinFleetOrder::IsActive` merges as soon as the two fleets stand in the same province, the record's own account; OpenHOI3 also wanted the other fleet standing still, so a fleet joining one under way at sea never caught it.
- Built in OpenHOI3: all three. Every country's fleet count is then the original's at 2 January 12:00 and 4 January 12:00 - 101 of 101 against the hourly saves, the United States, France, Italy and Spain among them - and every theatre's fleets 106 of 106; entering and the 48 hours after July 1941 unchanged. `+0x2CA` (`ai_pass_scratch`) is still unexplained: clear in every case seen.

## 66. The air rebase's crowding leaves out a carrier's air groups (measured)

Read on 2026-11-13 off the hourly saves of a new game, for Britain's air units, two of which stood at each other's base on 4 January in OpenHOI3 in both runs of section 63.

- **The first new-game pass rebases them all**, every listed base at peace scoring the same 10,000, so the crowding and the groups' order decide. The original's 03:00 save: the 1st, 2nd and 3rd Fighter Wings and the 1st Tactical Wing to Scapa Flow (604, an air base of level 4), the 2nd Tactical Wing and RAF Strategic Bomber Command to 1127. OpenHOI3 took the same groups in the same order but found 604 crowded from the second group on - 3 wings counted based there - and sent the next three to 1127, which left 1127 crowded for the bombers, sent to 1521.
- **The 3 wings at Scapa Flow are the carriers' air groups** of the fleets based there (the Home Fleet's among them): no air unit of the save has `base=604` but on a carrier. For the original to send four groups of a wing each to 604 it can have counted at most 2 there before the fourth, so it counts none of them: a carrier's air group is on its carrier's list, not the air base's - consistent with section 26's "every air unit based at a base", the base being the airfield's own list.
- Built in OpenHOI3: a carrier's air group left out of the airfield's count. Every British air group then has the original's base and place at 03:00; on 4 January 60 of 61 air units stand where the hourly saves have them (58) and 58 of 59 where the played save has them (56); entering and the 48 hours after July 1941 unchanged. *Measured*, not read on the listing.

## 67. A join_air beyond its range turns home: `CJoinAirOrder::IsActive` read on the listing (confirmed)

Read on 2026-11-13 on the running game and off the hourly saves of a new game, for Japan's air units: on 4 January OpenHOI3 had one fewer, the 4. Nihon Koukuujieitai having merged into the 5th, and the 3rd at 5020 where the original's is at 4691.

- **The hourly saves**: at 1 January 23:00 the 4. Nihon Koukuujieitai (2222, one naval bomber wing, based at 4986) is given a `join_air` onto the 5th (2224) at 4691, `time=2`. At 2 January 00:00 it is at 11922 and its fuel falls to 0.074; at 01:00 at 11919, two provinces short; **at 02:00 the order is gone and its path runs home** (11918 4943 4986), where it lands at 04:00. The 5th and the other groups at 4691 have no order throughout. At 12:00 it, and not the 3rd, is the group rebased to 5020. A second new game did the same: at 03:00 the group stood at 4943 on its way home, fuel 0.074.
- **Nothing in the AI ends it**: `CEU3AI::MoveUnit` and `IssueUnitOrder` logged for the group from 1 January 00:00 to 2 January 03:00 caught only the rebase of 02:00 on 1 January (`IssueUnitOrder` token 0x574, caller 0x4CE5A0). The order ends itself.
- **`CJoinAirOrder::IsActive` (0x197BB0), read on the listing**: the unit (`order +0x08`) with no base (`+0x98`) answers false at once (`je 0x197D0C`), **without** `COrder::OrderReturnToBase`; the target (`+0x80`) not resolving, under a `join_air` itself (slot 16 == 0x717), or holding no brigades (`+0x40 regiments_count`), goes to 0x197D06: `OrderReturnToBase(order)` and false; a target standing in the unit's province (`+0x130` equal) is merged (`CUnit_MergeInto` at 0x197C4D, the unit queued for removal) and false - **the target's movement is not asked**; otherwise **`CAirOrder::IsActive` (0x18A5E0) decides** (0x197CE9): true goes on, false answers false, again without the join's own return - the base test's own return, ordered where the unit is beyond its range, is what turns the group home. The record had every failed test returning home.
- **Which test fired**: the group's targets all had brigades and no order and the base was there, so it is `CAirOrder::IsActive`'s range test - the naval bomber beyond its range from 4986 at 11919, not yet at 11922. *Inferred* from the elimination; the range figure itself was not read off the running game.
- Built in OpenHOI3: a join_air asks the air order's test while on its way, merges whatever the target is doing, and a target with no wings or a missing base ends it. The group then turns at 02:00, lands at 04:00 and is rebased to 5020 at 12:00, hour for hour with the original. **The fuel differs**: OpenHOI3's group holds 0.132 from midnight where the original's holds 0.074 - not followed up here.

## 68. The hold list's weekly rebuild falls on the 1st, 8th, 15th, 22nd and 29th (confirmed)

Read on 2026-11-13 on the running game, a new game's first twelve hours, for Britain's East Africa Command Theatre, whose Tanganyikan Colonial Army OpenHOI3 sent from 10066 to 10012 on 1 January at 09:00 and the original left where it stood, in the hourly saves of both runs.

- **The original's land block at 09:00 runs only the garrison fill**: `CAIUnit_FillLinePositions` (0x4C8EE0) was never called for the agent at 02:00 or 09:00; `CAIUnit_UnitMayLeave` was asked of the five divisions from `CAIUnit_FillGarrisons` (caller 0x4CB35A) and `CAIUnit_MayShipUnitToArea` (0x4C42D1) alone. So its line count was nought; OpenHOI3's was one.
- **The split's inputs, read at `CAIUnit_SplitGarrisonAndLine` (0x4C7AB0) on 2 and 3 January at 09:00**: five committed divisions on +0x13C and +0x12C, none held back - the 7th Indian Infantry, given to the theatre by the balancing while still in Karachi, among them, as OpenHOI3 has it - ten positions, eight front provinces and **five hold provinces**: 10066 at 160, 10130 at 134, and 9752, 9908 and 10635 (Mauritius) at 132. OpenHOI3 held four, its list cut to the four divisions the theatre had when it was first made at 02:00. With five holds every division is a garrison and the line is nought.
- **Why the original's list has five**: slot 80 (`CAIUnit::RebuildHoldProvinces`, 0x4B3A50) ran for the agent at 02:00 with `hold_provinces_built` (+0x82) clear - five land units, one not a division - and again at 09:00 with it **set** and nothing threatened (+0x1E4 = 0) - eight land units, three not divisions - so the third arm of the tick's gate: a full pass on a day the test passes. The test (0x4B0A71-0x4B0A84) is `Date_DayOfMonth(tick) % 7 == 0`, and `Date_DayOfMonth` (0x4C5C0) counts **from nought**: the 1st, 8th, 15th, 22nd and 29th. OpenHOI3 had taken the day of the month as written, so the 7th, 14th, 21st and 28th. The tick's other weekly test, the area's at 01:00, already counted the day of the year from nought.
- Built in OpenHOI3. On 4 January against the hourly saves 883 of 908 divisions stand where the original's do (871 before), 894 move or stay as its do (869) and 474 of 541 are bound for its province (454); against the played save 870, 893 and 473 of 542. Entering the three saves and the 48 hours after July 1941 unchanged. What differs on 4 January now is all the Soviet Union's.

## 69. The peace-time +20 is spread in single precision, and a line with no share gives every position one (confirmed)

Read on 2026-11-13 on the running game, for Czechoslovakia's Praha HQ: its 10. and 6. divize, sent at 1 January 02:00 to 2632 and 2889 in both the original and OpenHOI3, are stopped where they stand at 2 January 05:00 in the original's hourly saves of both runs and march on in OpenHOI3's.

- **Who stops them**: `CEU3AI::MoveUnit` logged for the two at 2 January 05:00 - each moved to the province it stands in (3030, 2825) with `(0, 1, 1, 0)`, from `CAIUnit_FillLinePositions` (caller 0x4CA94A).
- **The positions at the end of the line fill** (its `ret 0x14`, 0x4CA9BD), 3 January 05:00: line 23, 35 positions, and **every one wanting 1** - the scores 90 (13 of them), 80 (3), 70 (4), 50, 40, 30 (9) and 10 (4). That is the record's step (D): step (B) gave nothing, so every position wants one. Where a division stands on a position that wants one it is taken at once, so the two stop. OpenHOI3 handed out 23 and kept their positions wanted.
- **Why nothing was given**: +0x34C, read at the fill's entry, is the plain sum of the position scores - 2090 for Praha, 975 for Warszawa, 560 for Wien - so the divisor is the record's. The sum is what differs: OpenHOI3's came to 2070, and 23 x 90 = 2070 gives the best positions one each where the original's 2090 gives none. Nine provinces' scores differed by 20 each way, and the original had one more province with +20.
- **The spread of the +20, on the listing** (0x4BD2B4-0x4BD2E8 and 0x4BDAA5-0x4BDB33 in `CAIUnit::ScoreOpsAreaProvinces`): the fraction is `(float)((double)(float)(m mod n) / (double)(float)n)`, m the committed count (+0x130 - +0x12C) and n the area's provinces; per province the carry is `(float)((double)carry + (double)fraction)`, and where `carry >= 1.0f` (comiss with 1.0f at 0x206DBAC in the running image) it becomes `(float)((double)carry - 1.0)` and the score gains 20.0. OpenHOI3 held the fraction in thousandths - 714 for 25 of 35 - which reaches 25 only after 35.02 provinces, so it gave 24 and placed them differently.
- Built in OpenHOI3. On 4 January against the hourly saves 889 of 908 divisions stand where the original's do (883 before), 899 move or stay as its do (894) and 489 of 541 are bound for its province (474); against the played save 876, 898 and 488 of 542. Entering the three saves and the 48 hours after July 1941 unchanged.

## 70. The garrison dropped is scored by the garrison targets, 1 where it stands on none (confirmed)

Read on 2026-11-13 on the running game, for Poland's Warszawa HQ: at 1 January 10:00 the original sends its 9 Dywizja Piechoty from 1626 toward 1868 and leaves the 55 D. Piechoty (Rezerwowa) at 2158, sending it to 1928 two days later; OpenHOI3 did the reverse, in the hourly saves of both runs.

- **The split at 10:00**, read at `CAIUnit_SplitGarrisonAndLine`'s entry and return: the 9th, the 15th (both at 1626) and the 55th Reserve (at 2158) come in marked (+0x2C9) among 23 divisions, the marks of 02:00 kept; the garrison vector handed back holds the 55th Reserve and the 15th. **The 9th was dropped**, and so went to the line. OpenHOI3 dropped the 55th Reserve.
- **The drop, on the listing (0x4C8896-0x4C89B9)**: over the block's marked divisions in order, one holding a brigade of the garrison type is passed over; the score starts at **1.0** (the float at 0x206DBAC in the running image) and walks the **garrison targets** - the fourth argument, not the hold list - taking the score of each record whose province is where the division is bound (`CUnit_GetPendingDestinationProvince`) or else where it stands, so the last such record wins; +1000.0 with militia and +500.0 with police (doubles at 0x1F5A300 and 0x1F5A538, by the brigade types at the database's +0x54 and +0x4C); the least, from 10,000,000.0 (0x1F5A7CC) and strictly below, is unmarked (+0x2C9 = 0) and erased from both vectors. Neither 1626 nor 2158 being a target at 10:00, all three scored 1 and the first, the 9th, went. OpenHOI3 scored by the whole hold list with nought for a province not on it, where 1626 scored high and 2158 nought.
- Built in OpenHOI3. On 4 January against the hourly saves 892 of 908 divisions stand where the original's do (889 before), 902 move or stay as its do (899) and 499 of 541 are bound for its province (489); against the played save 879, 901 and 498 of 542. Entering the three saves unchanged; the 48 hours after July 1941 still 201 orders the same, one Soviet order taking another way and one more of OpenHOI3's alone.

## 71. The garrison dropped leaves both vectors by a swap with the last; Australia's sealift areas vary with the run (confirmed)

Read on 2026-11-13 on the running game, a new game of the 1936 bookmark (`probes/hoi.lua`'s `hoiNewGame`), for two differences both of the original's hourly-save runs had from OpenHOI3 on 4 January: China's 28. and 31. Jun, and Australia's 1st and 4th Australian Divisions.

- **China's Yan'an HQ at 1 January 15:00**, read at `CAIUnit_SplitGarrisonAndLine`'s entry and return, with every `CEU3AI::MoveUnit` for a Chinese unit: the marked divisions come in as 4. Jun (7410), 30. and 31. Jun (5335), 27. and 28. Jun (7391), in that order among fifteen; the targets are 7417, 7398 and 7410, and the garrison vector handed back reads **4. Jun, 27. Jun, 31. Jun** - the 30. and the 28. dropped. All four but the 4. stand on no target and score 1 (section 70), so a first-of-equals walk over a list closing up in order would drop the 30. and then the 31. The garrison fill (caller 0x4CB751) then sends the 4. to 7417, the 27. to 7398 and the 31. to 7410; OpenHOI3 dropped the 31. and sent the 28. to 7410.
- **Why, on the listing**: both removals of the dropped division (0x4C89A2 from the block's list at `[ebp-0x2C]`, 0x4C89AE from the garrison vector, the third argument) are `Vector_SwapRemoveValue` (0x4DCDA0), which writes the last entry over the one found and pops the last. 4, 30, 31, 27, 28 losing the 30. reads 4, 28, 31, 27, so the next first of equals is the 28.; losing it reads 4, 27, 31 - the vector logged. The record had that helper's callers as eight, all in `CAIUnit_ManageNavalUnits`; six are, and these two are the split's.
- **Australia's sealift is the original's own spread.** The fill's comparison (0x4C63E6) and its target writes (0x4C6484) logged at the second hour: the same ten candidates in the same order as OpenHOI3's, every score equal (9, then 208 down to 202), the first of each taken - but the areas came in as 6439, 6467, 10328, 5905, 10302, 6422, 5920, 6431, a third order beside the two runs of section 62. The debark became 6431, the 6th Military District's target, and the embark 10476 beside it; in both hourly-save runs it was the 1st Australian Division's, with the embark 7989. So which division goes to the sea varies with the run, and OpenHOI3's choice of the 4th and 7831 is one of the original's possible ones. The 2nd Australian Division, also listed (for 10328 here), keeps the redeployment to 8007 the line gave it the same pass, in the original as in OpenHOI3.
- Built in OpenHOI3: the drop's two removals by a swap with the last. On 4 January against the hourly saves 896 of 908 divisions stand where the original's do (892 before), 905 move or stay as its do (902) and 529 of 541 are bound for its province (499); against the played save 883, 904 and 528 of 542. Entering the three saves unchanged; the 48 hours after July 1941 still 201 orders the same, and two fewer of OpenHOI3's alone.

## 72. The naval body's handled fleets leave the ready vector by a swap with the last (confirmed)

Read on 2026-11-13 on the running game, a new game of the 1936 bookmark, for Japan's 7. Hoheishidan, which both hourly-save runs send from 4986 to 5478 at 1 January 12:00 and OpenHOI3 left where it stood.

- **The noon split**, read at `CAIUnit_SplitGarrisonAndLine`'s entry and return for the Imperial General Headquarters: 28 targets, and the garrison vector handed back without the **52. Hoheishidan** (on target 5543), the 5. Pacific Garrison Guards moved into its place (section 71's swap); the garrison fill (caller 0x4CB751) then sends the 7. Hoheishidan to 5478. OpenHOI3 dropped the 7., standing on target 4986.
- **The hold list's scores** (+0x17C, records {province, 0, score float}), read at the agent's next split: 5346 111, 5478 103, **4986 97**, 5218 97, 5425 94, **5543 85**. OpenHOI3 had 5346 115, 5218 105 and 4986 85 - tied with 5543, the first of equals the 7. Every other score agreed. The differences, +4, +8 and -12, are `CAIUnit_ProvinceHoldValue`'s 2 a ship based at the port (section 15): the transport fleets' bases.
- **The bases** come from the naval body's rebase at the second hour (section 64): the original's 14., 16. and 20. Kaigun to 5346, 19. to 5218 and 18. to 4986 - the bases its naval body sends them home to when it cancels their orders at noon (`MoveUnit` from 0x4D19BD). OpenHOI3 sent the 18. to 5346 and the 20. to 5218: the same scores in another order of fleets, 5346 reaching its level of 10 with the 18.
- **Why, on the listing (0x4D2039-0x4D2072)**: phase 6 walks the handled fleets' vector (`[esp+0x68]`-`[esp+0x6C]`) in the order they went on it and takes each out of the ready vector (`[esp+0xB0]`) by `Vector_SwapRemoveValue` (0x4DCDA0), the last ready fleet moved into its place each time. The ports of phase 7 are handed out in the order that leaves. OpenHOI3 took them out keeping the ready fleets' order.
- Built in OpenHOI3. The second hour's rebases and the noon split are then the original's for Japan, the 7. Hoheishidan sent to 5478; on 4 January 906 of 908 divisions move or stay as the hourly saves' (905) and 530 of 541 are bound for their province (529); against the played save 905 and 529 of 542. **Britain's fleet count is one over both hourly runs on 4 January** from then on (36 against 35): at 1 January 11:00 OpenHOI3's Far East Command, with troops listed for the sea, takes the 3rd Transport Ship Squadron, which the original hands East Africa Command. That is so with the old order too; only its lasting to 4 January is new. Entering the three saves unchanged; the 48 hours after July 1941 still 201 orders the same.

## 73. The transport gather's taken list is each agent's own; a joining fleet re-aimed by something not yet read (confirmed, and an open question)

Read on 2026-11-13 on the running game, a new game of the 1936 bookmark, for Britain's fleets, which from 1 January 11:00 parted from both hourly-save runs in OpenHOI3 once section 72 was built.

- **The gather at 11:00** (`CEU3AI_GatherTransportsForTheatres`), logged at its calls of `CAIUnit_SumTransportCapacity` (from 0x490E2D) and at the winner (0x491203, the fleet in EDI): the Army of India (port 6005, tonnage 63), **Far East Command (6394, 25), which takes the 3rd Transport Ship Squadron at 2078**, and **East Africa Command (10130, 35), which takes the same squadron again**. The attach commands run in order, so East Africa keeps it, as both hourly runs have it.
- **On the listing**: the list of fleets taken (`[ebp-0x4C]`, a list whose nodes hold the fleet at +0 and the next at +8, walked at 0x490F95-0x490FAD) is emptied at 0x490E30, right after each agent's capacity is summed - so it keeps one agent from taking a fleet twice and nothing more. A fleet another agent took is still its old agent's until the command runs, so it passes the test that its agent is not the taker. The record had "not moved already this pass" across the pass, and OpenHOI3 had built it so: Far East kept the squadron.
- **A joining fleet's re-aim, not read**: the 47th Navy, a light cruiser split off at Madras (6320) and given a join to the 1st Transport Ship Squadron as the two sail past each other, keeps its first path through 1 January in both hourly runs and in this one - it reaches 12102 and 12338 without a new one - and at 2 January 00:00, reaching 12350, has a path of one step to 11323, where the squadron stands; reaching 11323 after the squadron has gone on, it stays there with none, and never merges (still apart at 2 January 16:00). No `CEU3AI::MoveUnit` and no `IssueUnitOrder` was logged for it from 1 January 13:00 to 2 January 02:00, so the re-aim is not the AI's; `CJoinFleetOrder::IsActive` as the record reads it moves nothing. OpenHOI3 re-aims a join every hour at the target's place and merges the two by 1 January 22:00, which leaves Britain one fleet over both hourly runs on 4 January.
- Built in OpenHOI3: the taken list made again for each agent. Britain's fleets under each theatre are then the hourly saves' at 1 January 12:00 to 21:00, and part at 22:00 over the 47th Navy. The 4 January figures and entering are unchanged; the 48 hours after July 1941 still 201 orders the same.

## 74. A province's terrain is counted round its text point, which without a `text_position` is two pixels south of the centre (confirmed)

Read on 2026-11-13 on the running game, a new game of the 1936 bookmark, after Japan's 2. Independent Mixed Brigade and 1 Moukogo Kiheishidan were sent to each other's line positions by OpenHOI3 at the second hour: `CAIUnit::GetUnitTerrainModifier` logged for both gave the brigade's definition (`CUnit +0xC8`) the same adjuster, terrain 5 (plains), defence 166, at 8636 and 8748, where OpenHOI3 had 8636 forest.

- **Every province's terrain, read off the game**: the category id of each `CProvinceTemplate` (`CMap +0x2A60`, `+0xC` -> `+8`; `g_CMap` at rva 0x168557C) for all 14,168 provinces - the categories' order in `terrain.txt`, 0 ocean to 10 arctic. OpenHOI3's differed in 94 provinces, and **92 of those have no `text_position` in `positions.txt`**.
- **The count, read again on the listing** (rva 0x8A94D-0x8AE11; `FINDINGS-movement.md` section 8 gives the same block as 0x48A94D-0x48AE11, virtual addresses): x from the truncated text point's x - 10 and y from its y - 10, 20 of each (0x8ABB7-0x8AC8A); a pixel counts where the province raster (`CMap +0x20E0`) holds the province, by the category (`[ebx + index*4 + 0x2220]` -> `+0xC` -> `+8`) of the terrain raster's index (`CMap +0x20E4`); the strictly highest count wins (0x8ACA4-0x8ACBA), the first declared of equals; land on a water category takes the first that is not. That is section 8's rule. The point is the template's text position (`+0x3C`/`+0x40`, `cvttss2si` at 0x8AA3C/0x8AA41) - which, where the file gives none, is the bounding-box centre with y less 2.0, as the record's +0x40 already said. OpenHOI3 counted round the centre itself.
- With the point moved two pixels south, OpenHOI3's terrain is the running game's in all 14,168 provinces, and `OpenHOI3.SaveCheck weather` - whose 48 and 49 land provinces apart were each "agreeing given another terrain" - agrees in every province's eight figures in both pairs of saves. The near-map name is still drawn at the label, which keeps its own point.
- **The template's text position is not always the file's**: for 1692 provinces it reads otherwise in the running game (Porsangerhalvoya 3107, 2099 against the file's 3094.8, 2096.1; others at sixteenths, 3098.4375), so something writes `+0x3C`/`+0x40` after the terrain is counted. Not followed; the terrain is counted before it.
- Built in OpenHOI3. On 4 January 897 of 908 divisions stand where the hourly saves have them (896) and 533 of 541 are bound for their province (530); against the played save 884 and 532 of 542. Entering the three saves unchanged, the supply pass's 184 of 234 networks and every convoy unchanged, the map cache byte for byte.

## 75. A unit already redeploying is redeployed again; the 1 Moukogo's lag is the weather (confirmed, and measured)

Read on 2026-11-13 off the hourly saves and the listing, for five divisions both hourly-save runs had bound for the same province as OpenHOI3 on 4 January but standing elsewhere on the way.

- **The United States' 43rd 'Winged Victory' NG Division and 1st Cavalry Division**: both are re-aimed at 1 January 11:00 in both games - the 43rd from 3793 to 8080, the cavalry from 8080 to 3533 - while already under a strategic redeployment. In the hourly saves the order stays `strategic_redeployment` and the march goes on (the 43rd reaches 4083 at 21:00). OpenHOI3 posted a plain move: the unit lost its order, stood at nought progress for a day, and was redeployed only at the next day's pass - a day behind on 4 January.
- **On the listing**, `CEU3AI_ShouldRedeployStrategically` (0x499E50-0x499F37) asks the unit's province (land, +0xD4 -> +0x22), trespassing (+0x1A8), its battles (+0x11C), the target against its province and its neighbours, and the distance against max_speed (`CUnit +0xC8` -> `+0x108`) / 1000 x 0.25 x 200 or 600 - **and not the unit's order**. OpenHOI3's copy also answered no for a unit already redeploying, which was nobody's reading. Taken out.
- **Japan's 1 Moukogo Kiheishidan**, bound for 8748 in both games, marches 7234 to 7184 at 0.3 an hour in both until 3 January 10:00; then OpenHOI3 has a weather front over 7234 - precipitation 0.8 and climbing, the temperature below nought by 13:00 - and its pace falls to thousandths, while the hourly saves have only the temperature there and keep 0.3 to arrive at 3 January 03:00 the next day. The `march` check agrees in what an hour adds to every marching division from a save's state (400 of 400), so it is the new game's weather, whose fronts are born on the generator's draws, that parts - not the march.
- Built in OpenHOI3: the order clause taken out. On 4 January 901 of 908 divisions stand where the hourly saves have them (897) and 888 of 908 where the played save has them (884); moved or not and bound unchanged; entering unchanged; the 48 hours after July 1941 still 201 orders the same, and two fewer of OpenHOI3's alone.

## 76. An inactive plan's powers: refilled at midnight and by the plan commands, over each brigade's own maxima (confirmed)

Read on 2026-11-13 and 14 on the running game, new games of the 1936 bookmark, for the plans' `our_power`: on 4 January OpenHOI3 had 0 for 60 theatres - Denmark's, Estonia's, Australia's and most small countries' - where the hourly saves have the AI's figure, under one (Copenhagen HQ 0.188, Home Forces Command 0.606).

- **`CAIUnit::UpdatePlanPower` logged** (entry, agent in ECX; the plan at `CUnit +0x27C`/`+0x280`, active at `+0x204`): Australia's history theatre holds 59.093 and is inactive at its first call (01:00), and posts 0.606; Denmark's Copenhagen HQ, made by the AI as the game is entered, holds 0 and is inactive at its first call (01:00), works out 0.188 and posts nothing - the same whole number - and holds **77.195** at its next call (09:00), when it posts 0.188. The hourly saves have 77.195 from the 01:00 save.
- **Who writes 77.195**: data breakpoints on the HQ's `+0x27C` and `+0x204` from 02:00 caught only the 09:00 writes (the active byte by `CUnitPlan::SetActive` from `CSetPlanAttributesCommand`, then 0.188); so it is written inside the 01:00 hour, after the bind. `CUnit::UpdatePlanForceNeeds` logged for the HQ: called at midnight (2 January 00:00) from `CUnit::UpdateDaily` (return 0x1BB32B), whose caller is **`RunCountryDailyPass`** (return 0xDB293) - the caller the record did not have, which settles the "daily" - and an hour later from `CUnit::RefreshPlanForceNeeds` (return 0x1BD73C) under `Session::PumpCommands`: that is, from a command's execution. The record's callers of RefreshPlanForceNeeds are `CSetPlanForcesCommand`, `CSetPlanAttributesCommand` (a stance change) and `CSetPlanOpsAreaCommand`. The agent's bind posts the area before the activation, so the area command runs on a plan still inactive and refills it; the activation follows.
- **The gate, read on the listing (0x1BD429-0x1BD4C9)**: up `+0x1E0` to the top; where the top's plan is active and its `oob_level` (`+0x1F4`) is 0, nothing; otherwise, with no province list, the unit's own plan's powers are zeroed and `ComputePlanWantedSubUnits` writes them and its `min`. The record's account.
- **Each brigade's worth, on the listing (0x4E2175-0x4E229B)**: combat value x (strength `+0x5C` / slot 12, `CSubUnit::GetMaxStrength`) x (organisation `+0x60` / `CSubUnit::GetMaxOrganisation` 0x1AB700), each with no flags, in thousandths truncated, -1 over a zero. So a reserve brigade is whole at its reduced strength - Ireland's at 7.5 of 30 and its headquarters at 2.0 of 10, the penalty a quarter - and its organisation is set against its ceiling. OpenHOI3 had divided by the types' bare `max_strength` and `default_organisation`, which put Ireland's whole order of battle at 0.863, under one.
- Built in OpenHOI3: the refill each midnight and from the three commands, with the record's gate, over the brigades' own maxima. On 4 January the plans' own power is the hourly saves' in 93 of 106 theatres (44 before) and the enemy's in 97 (90); the 13 left are the AI's sums of division power, a few tenths apart. The divisions' figures, entering and the 48 hours after July 1941 unchanged.

## 77. A joining fleet is aimed again at midnight; the handled list puts the fleet joined first; three differences that are the original's spread (confirmed, and measured)

Read on 2026-11-14 on the running game, new games of the 1936 bookmark, for Britain's fleets - one over both hourly-save runs in OpenHOI3 on 4 January - and three divisions both runs had elsewhere than OpenHOI3.

- **The 47th Navy's way**: a light cruiser split off at Madras and joining the 1st Transport Ship Squadron as the two sail past each other keeps its first way through 1 January, is aimed at 11323 (where the squadron stands) at 2 January 00:00, at Madras (6320) at 3 January 00:00, and merges there by noon. A data breakpoint on its path count (`CUnit +0x140`) at 2 January 00:00 caught the path emptied (`CList_FreeAndClear`) and given (`SetUnitPath`) under 0x19C123 <- 0x19C210 <- `CUnit::UpdateDaily` (return 0x1BB086, just after its call of the order's slot 23) <- `RunCountryDailyPass`.
- **On the listing**: 0x19C140, in `CJoinFleetOrder`'s vftable (0x11C6E84, which its constructor at 0x19C220 writes) at slot 23, is **`CJoinFleetOrder::RunDaily`**: it resolves the fleet to join (+0x48/+0x4C); where it exists and the joiner's path ends (its last node, or nought with no path) elsewhere than that fleet's province (+0x130), it calls 0x19BFA0, which finds a way from the joiner's province to the other's (0x1F12B0), gives it with `SetUnitPath(unit, way, 1)` and writes the province to the order's +0xC. The record had slot 23 filled only by the reserve orders (`CReserveOrder::RunDaily`, `CAirReserveOrder::RunDaily`); `COrder`'s and `CNavalOrder`'s own slot 23 is 0x6BF890. `CJoinFleetOrder::IsActive`, hourly, aims nothing. OpenHOI3 aimed a joining fleet again every hour and merged the two by 1 January 22:00.
- **The handled list's order**, read at phase 6 (0x4D2039 and 0x4D2074; ready at `[esp+0xB0]`, handled at `[esp+0x68]`) for Home Command at 1 January 09:00: the ready vector in creation order as OpenHOI3's, and the handled vector with **the fleet joined before its joiner** in every pair - "1st Destroyer Squadron, HMS Argus", "2nd Navy, 1st Navy", "14th Navy, 7th Navy" - in phase 4 and in the merge alike. After the removals the ready vector reads Home Fleet, 27th, 2nd Submarine Squadron, 26th, 24th, 22nd, Reserve Fleet, 28th, 25th, 23rd, 21st Navy, and the rebases (`IssueUnitOrder` token 0x6DE from 0x4D3141, logged) go 27th, 26th, 24th, 22nd, 28th, 25th, 23rd, 21st. OpenHOI3 put the joiner first, which swapped every pair of the eight light cruisers' ports.
- **The original's own spread**: its new game's weather is not the same from run to run - the two hourly-save runs' provinces differ in their weather in 7,240 of 14,168 on 4 January - so Japan's 1 Moukogo Kiheishidan and Italy's 1a Divisione 'Superga', marching at both runs' pace in OpenHOI3 until a front of OpenHOI3's crosses their provinces (precipitation from 3 January 10:00 at 7234, 1 January 12:00 at 4039), stand where they do by the weather and not by the march. And the Dutch East Indies' second sealift target (`CArmy +0x2E8`, logged at 0x4C6484) came out 6434 in a third run, after 7780 and 7744 in two others (section 62), each moving the plan's debark and embark: the IIe Divisie 'Java's place follows it.
- Built in OpenHOI3: a joining fleet aimed again only at midnight, and the fleet joined first on the handled list. On 4 January every country's fleets are the hourly saves' (101 of 101) and every theatre's (106 of 106); divisions, entering and the 48 hours after July 1941 unchanged.

## 78. The naval score weighs a ship once; own fleets are handed out within the enemy's reach (confirmed)

Read on 2026-11-14 on the listing, for the plans' `min` - OpenHOI3 had 96 of 106 on 4 January against the hourly saves, every miss at index 39, the naval bomber, more negative than the save's (Home Command -5 against -3, the Imperial General Headquarters -7 against -4).

- **The weight, in `CAIUnit_ComputePlanForces`** (enemy fleets at 0x4B5BF2-0x4B5C29, the country's own at 0x4B5E38-0x4B5E63): per brigade, where the definition's type is the heavy cruiser's, +0.07 (or -0.07); **else** where its `is_capital` byte (+0x2F) is set, 0.15; **else** where it is not the submarine (enemy) or the transport ship (own), 0.02. One of the three. `heavy_cruiser.txt` carries `capital = yes`, so OpenHOI3, which added all three, counted a heavy cruiser 0.24 and any capital ship 0.17.
- **The hand-out of own fleets, in `CEU3AI_AssignSeaTargetsToAgents`**: the enemy's fleets (0x48C91D) and the country's own (0x48D340) both skip a port more than 2000.0 away (`comisd dist, 2000.0; ja`), so 2000 itself counts, and both need the ports' naval base levels to come to 1.0 or more (0x48C988, 0x48D3AB) - the record's account. OpenHOI3 applied neither test to its own fleets and left 2000 out for the enemy's.
- **Japan's Kwantung Army**, the one plan still apart (interceptors and tactical bombers 7 against the hourly save's 5): read at `CAIUnit_ComputePlanForces` on the running game, its agent held 124 brigades and a need (+0x354) of 57, 58 and 56 divisions at its passes of 2, 3 and 4 January - 7 each time, OpenHOI3's figure - and that run's save and the second hourly run both have 7. The first hourly run's 5 is its own.
- Built in OpenHOI3: both. On 4 January the plans' `min` is the hourly saves' in 105 of 106 and the played save's in 106 of 106; nothing else moved.

## 79. A lent unit is counted for its officers by neither country (confirmed, and measured)

Read on 2026-11-14 on the running game and off the hourly saves, for the plans' own power - 13 theatres apart in both runs on 4 January, CONUS East among them (4.950 against 5.104).

- **The sums at each pass**, logged at `CAIUnit::UpdatePlanPower` once both are made (0x4B50B3, the agent in ESI; +0x35C, +0x360, +0x358): CONUS East 7.563 and 6.203 on 1 January as OpenHOI3's, then **5.104 against OpenHOI3's 4.950** at 2 January 05:00 over the same 14 divisions; Bordeaux HQ 16.715 / 2.641 against 16.709 / 2.655, its enemy power falling to 1.735 on 4 January (OpenHOI3 2.200), which crosses a whole number and is posted.
- **Why CONUS East**: every US division's organisation in the hourly saves stands about 3% above OpenHOI3's (the 26th 'Yankee' NG Division 8.793 against 8.540 at 2 January 05:00). OpenHOI3's ceiling fell from 8.776 to 8.522 at 1 January 09:00, its officer ratio from 1.003 to 0.974, as its officer need rose 300 for the three armies (1st, 2nd and 3rd Army, a headquarters brigade each) its AI makes then. The original has the same three armies by 08:00 and its 26th's organisation reads 8.776, **8.932** (06:00), 8.776 (noon): its ceiling rose about 3% between the third and the eighth hour and fell back. That is the United States lending the Phillippine Force (three brigades, 300 officers) to the Philippines at the third hour and **no longer counting it**, until the armies' 300 bring the need back. OpenHOI3 went on counting a lent unit for its lender.
- **On the record**, `CCountry::RecountUnitTotals` makes its three passes over the country's own units with no expeditionary owner, the units of its faction's members lent to it, and its units waiting to be placed - so a unit lent to a country outside the lender's faction is counted by neither, as the Philippines' own brigades also show, their organisation unmoved by the lending.
- Built in OpenHOI3: the officer need and the land brigades in service counted so. The 26th's organisation is then the hourly saves' at 06:00, noon and 2 January 05:00 (8.932, 8.776, 8.793); on 4 January the plans' own power is the hourly saves' in 96 of 106 theatres (93), the rest the AI's sums still a little apart; divisions and entering unchanged.

## 80. The AI promotes a leader for a leaderless theatre, and the unit's organisation pays (confirmed)

Read on 2026-11-14 on the running game and off the hourly saves, for France's enemy power at Paris - 0.021 in both runs on 4 January against OpenHOI3's 0.030 - and at Strasbourg.

- **The term apart**: of Paris's two front provinces, 2137 holds Belgium's Commandement côtier, the same in both (organisation 8.268), and 2429 holds **Luxembourg's Force Publique**, its theatre headquarters - organisation 20.061 in the save against OpenHOI3's 32.910.
- **Why**: in the hourly saves its organisation climbs to 31.396 at 2 January 03:00 and is **halved** at 04:00 (15.724, half of the hour's 31.448), as it is given leader 400002, Felix Bourbon-Parma - `leader=` appears on it in the 04:00 save and not before. Read on the running game on 4 January: the unit's `oob_level` (+0x1F4) is 0, a theatre, and its leader (+0x12C) holds **rank 4** - where his history gives 1 and then 2 on one date. `CUnit::MayTakeLeader` asks the exact rank 4 for a theatre, so OpenHOI3's leader pass found nobody fit (every fit nought) and its organisation was never halved.
- **The promotion is `CEU3AI_PromoteLeadersForCommands`**, as the record reads it: at the country's hour + 16 the leaderless headquarters counted by level and, from the corps up to the theatre, the first free land leader promoted by (4 - rank) - max(level - 1, 0) ranks - Felix from 2 to 4 at 1 January 12:00, Luxembourg's hour + 16 - and at the hour + 8 of the next day the leader pass, finding him fit, puts him on with both costs (`CAssignLeaderCommand(unit, leader, 1)`), the organisation halved. OpenHOI3 had not built the promotion, and its command moved a leader one rank only.
- Built in OpenHOI3: the promotion, and the command a number of ranks. On 4 January the enemy power is the hourly saves' in 99 of 106 theatres (97 before), Paris and Strasbourg among them; divisions, entering and the 48 hours after July 1941 unchanged.

## 81. Three last differences on 4 January: a fuel pool, a played run and the sealift's run-to-run spread (measured)

Read on 2026-11-14 off the hourly saves, the played save and OpenHOI3's traces; nothing new read in the executable.

- **Japan's air groups at 4986**: their fuel received on 2 January is 0.074 and 0.060 in the hourly saves (2. Nihon Koukuujieitai, two tactical bombers; 4 Zerosen no Hikodan, one interceptor) and 0.072 and 0.058 in OpenHOI3 - unequal in both, by `CUnit::ConsumeSuppliesAndFuel`'s share truncated to thousandths of the need, which OpenHOI3 builds - and 0.129/0.128 against 0.125/0.124 on the 3rd, 0.165/0.164 against 0.159 on the 4th. Worked back from the 18. Kaigun's share at the same draw (0.103 against 0.099, its ask 5.242 of a need of 19.024), the province held about 1.962 fuel before the midnight draws in the original and 1.909 in OpenHOI3: the difference is in what the daily pass leaves in the province, not in the draw. Both the fleet and the 4. Nihon Koukuujieitai are moving at that midnight in both games, so both burn what they are given.
- **Italy's three intercepts** end at 1936.1.6.5 and .6 in the played save and an hour earlier in OpenHOI3 - as in both hourly-save runs, which OpenHOI3 matches 3 of 3. The played run's own.
- **The four plans whose embark or debark differ** - Australia's, the Dutch East Indies', Japan's Imperial General Headquarters' and Republican Spain's - all turn on the order the sealift's areas come in, which differs from run to run (sections 62 and 71): Spain's votes went in 9590, 9569, 5002 in one run and 9569 first in another, OpenHOI3's in 5002, 9569, 9590, so its debark is 5002 where a run taking that area first would have it; Japan's port was 10653 in a watched run, OpenHOI3's, and 10651 and 5966 in the hourly runs; Australia's and the Dutch cases are sections 71 and 77.

## 82. A command is scored by how far the unit is beyond *it*, and a unit with a sealift target keeps its commander (confirmed)

Read on 2026-11-14 on the running game and off the listing, for the first difference the July 1941 series showed once three runs of the original were set beside one another: OpenHOI3 moving headquarters - Italy's Gruppo d'Armata Ovest 22 provinces at the first 14:00, and corps and armies of Canada, Spain, China, Brazil, Argentina and the United States - where none of the three runs moved them.

- **Three runs of the original** from `Ireland1941_07_16_07.hoi3`, saved hourly for 48 hours, give each other the same new way for 228 land units and another for 18, and one alone gives a way 105 times. A difference of OpenHOI3's is taken as its own only where every run agrees.
- **What moved the army group**: at Italy's hour + 3 (11:00) OpenHOI3's `OrganiseCommands` put the 2nd Army and 2a Armata, both directly under the theatre Cdo. Sup. Metropolitana, under Gruppo d'Armata Ovest, which then walked to them. In all three runs they stay under the theatre for the 48 hours; read on the running game on 19 July at 11:00, `CAIUnit::AssignToNearestCommand` is handed both in its army list and attaches neither.
- **Why**: each carries `target=5445` (written after its brigades, below the unit's header), and the function's first test skips a unit whose `CArmy +0x2E8` is above 0, or whose parent's is (0x4C27D8-0x4C2805) - in the record, not built in OpenHOI3.
- **The score, off the listing** (0x4C29B3-0x4C2B73): for each candidate K, `beyond` = (distance(U's destination or place, K's destination or place) - reach(K)) x 1000 (0x4C29F1-0x4C2ABC); score = (float)distance(U's place, K's place) (`+0x130`, not the destinations), + beyond / 1000.0 where beyond > 0, x 0.85 where K is U's parent, single precision, the least strictly under 1000000.0 (constants at 0x120A598, 0x120A300 and 0x120A9D0: 1000000.0, 1000.0 and 0.85). **The added term is U's distance beyond K's reach**; OpenHOI3 had added K's own distance beyond *its* parent's, which the record's "over_K where K's own over is above 0" read as. At n = 5 a unit beyond its parent's reach may go only while its `ai_garrison` (`+0x2C9`) is clear (0x4C2AD8).
- The same pass moved 1a Divisione Eritrea from VI Corpo d'Armata to Corpo d'Armata Celere on 19 July at 11:00 in the original - the move OpenHOI3 made on the 16th; the reorganisation was otherwise empty for Italy, Canada and Spain.
- Built in OpenHOI3: the target skip, the score and the garrison test. The 48 hours after July 1941: of the moves no run of the original makes, 112 to 88 against two runs and 84 against three; Italy's, Canada's, Spain's, China's, Brazil's, Argentina's and the United States' gone. On 4 January the own power the hourly saves' in 99 of 106 theatres (96 before), the enemy power in 101 (99); entering the three saves unchanged.

## 83. A province changing hands sets off a full pass for every friend near, in the same hour (confirmed)

Read on 2026-11-14 on the running game and off the listing, for the second difference the three runs of the July 1941 series agreed on: at 17 July 12:00 every run gives Bulgaria's divisions in Serbia new places and moves the headquarters of Bulgaria, Britain, Iraq, Germany and Italy, and OpenHOI3 gave none of it.

- **What happened at 12:00**: Barce (5485) passed from Italy to Britain, in OpenHOI3 as in the original. Reproduced on the running game - the save reloaded, 28 hours run, `CEU3AI::MoveUnit` logged at 12:00 - the eight moves come from `CAIUnit_FillLinePositions` (0x4CA2B3: Bulgaria's three divisions) and `CAIUnit_PullHeadquartersIn` (0x4CC42E: the five headquarters), the second run only on an agent's full pass.
- **Why those agents had a full pass**: the capture marks the two countries' theatres; `CAIStrategy::RefreshTheatreProvinces` ends with `CAIStrategy_TellFriendsOfTheatres` (0x4AC390), read whole: nothing unless our country's `province_count` (`+0xD08`) is at least 1; then for each country of our `non_hostile_countries` (`+0xF98`) other than ourselves whose `ai` (`+0x1D8`) is set and whose `province_count` is above nought, `CEU3AI_MarkAgentsNearTheatres` (0x48C090) with our tag. That walks the friend's unit agents (`+0x40`): each whose unit (slot 74) has `oob_level` 0 gets `area_dirty` (`+0x87`) = 1 where any of our theatres (`CCountry +0x570`) is connected to the agent's theatre (CAIUnit::GetArea, 0x4BBAE0) - `CTheatre_IsConnectedTo` (0xB0710), our theatre in EDI and theirs pushed: an area in both `+0x84` lists, or both headquarters resolving and `CMapProvince::CanUnitReach(their headquarters' province, our headquarters, 1, 1)`. Italy's theatres reach Bulgaria's and Iraq's headquarters overland.
- **And why in the same hour**: `CAIUnit::Tick` asks for the full pass - `hour == A6`, or `full_pass_pending` (`+0x84`) - at 0x4B09D2-0x4B09EA, **after** row 1's `SetArea` (0x4B08BE), slot 85 and the A9 focus areas; `SetArea` sets `full_pass_pending` (0x4BBA17). So an agent marked `area_dirty` sets its area at the top of its next tick and that same tick is a full pass. OpenHOI3 had asked for it first thing in the tick, so a marked agent's full pass came an hour late, and it had never told the friends.
- Built in OpenHOI3: the friends told at the end of a theatre build and refresh, and the full pass asked after the area. The 48 hours after July 1941: the moves every run of the original gives and OpenHOI3 did not, 12 to 5, and the same 208 to 215; Bulgaria's divisions and its 1-va Armija at 12:00 as the original's. Britain's three headquarters still differ: OpenHOI3's pull-in finds them bound where the original re-aims them. Entering the three saves and the 4 January check unchanged.
- **Not a fault**: in OpenHOI3 Sinkiang then joins the Comintern at 17 July 18:00, the Soviet Union's invitation accepted, and its agent, told by its new friends' refresh, moves its divisions; no run of the original makes a faction offer between 12:00 and 20:00 (`CFactionAction` slot 17 and `Apply` watched on the running game). Majors invite in the install's `ForeignMinister_HandlePeace`, which `ForeignMinister_Tick` runs on `math.random(10) == 1`, so the invitation is the draw's.

## 84. Two runs of a new game to 31 January, and the AI's fleets held to no range (confirmed, read on the listing)

Read on 2026-11-14. Two runs of the original from a new game (Germany played) were saved daily to 31 January 1936, and OpenHOI3's new game set beside both on days 7, 14 and 30. The two runs give the same place to 902 of 908 divisions on day 7, 889 on day 14 and 856 of 892 on day 30; a place both share and OpenHOI3 misses is OpenHOI3's.

- **France's two sealifts, in both runs**: the Division de Tonkin is aboard by 7 January and at Luganville (6610) by day 14; the 85e and 182e Divisions d'Infanterie d'Afrique go from Alger to Nice by day 7. OpenHOI3's divisions waited at their ports.
- **The transport sent while under way**: France's Flotte generale de transport, rebased from Toulon to Bordeaux and on its way there on 2 January (`path` to 3479 in the save), has a path to Alger the next day in both runs. In `CAIUnit::AssignAreaTargetsAndSealift`'s sending loop (0x4C7230-0x4C7372) a fleet is passed over where `Unit_GetAnchorProvince(fleet, 0)` - its destination or place - is embark (0x4C7244), or where **its order's slot 24 answers true and then** `UnitHasBlockingOrder` (0x4C725E-0x4C726B); then CanMoveTo, organisation >= 0.01, and the least ((1-org)+(1-strength))x2+1 times the sea distance / 1000. So a fleet on a plain way is sent. OpenHOI3 had passed over any fleet under way.
- **Range is the player's, not the commands'**: Bordeaux to Alger is 2375 by sea, the fleet's range 2000. `CEU3AI::MoveUnit` posts a `CMoveCommand` once slot 35 accepts the province, and `CMoveCommand::RouteUnit` (its slot 6, the execute) asks no range; `CSetOrderCommand`'s slot 14 (0x1E2A90), which its execute asks first, asks only that the unit and the province resolve and that a fleet or wing (slots 17 and 16) has a base (+0x98) - no range either. `COrder::IsTargetInRange`'s twelve callers are the orders' own tests, the order windows, `CUnit::OrderToProvince` (the right click), the air intercept's hour and `CAIUnit_ManageNavalUnits`. So the AI's moves and orders go anywhere; OpenHOI3's commands had held a fleet to its range from base whoever sent it.
- **The sailing** (`0x4D42D0`, called with the agent and the first idle transport in embark's port where `0x4D4D40(agent)` answers false), read as far as its decision: it needs a positive count at the fleet's `+0x2EC` and a plan with both embark and debark; it tallies, over the agent's land units (`+0x11C`) whose `target` is debark and whose anchor is in embark's area, all their brigades and those aboard (`CArmy +0x300`), whether any not aboard would still fit the transports' room, and the least hours any not aboard that fits this fleet needs to reach embark (its march speed, or the strategic-redeployment speed under that order). **Everyone aboard: it sails.** Otherwise, with one who would fit, it waits unless the fleet cannot reach debark (then nothing) or that one is further off than a threshold (0x120A4C8); with none who fits, it sails where the fleet can reach debark. To sail it issues `CEU3AI::IssueUnitOrder` with `transport` (0x3A8), or `invasion` (0x3A5) where debark's area calls for it (0x4D4C89-0x4D4D19), for debark. The branch for a fleet that cannot reach debark (escorts, 0x4D470F on) is not read.
- Built in OpenHOI3: a fleet passed over by the sending loop only where its order is a busy one and it is blocked; the AI's moves and fleet missions held to no range. On days 7, 14 and 30 the divisions placed as run E's went 889 to 892, 857 to 869 and 825 to 831, as run F's 889 to 890, 858 to 867 and 834 to 850; France's sealifts sail, the Alger fleet at 10566 on day 7 as in run E. Entering the three saves, 4 January and the 48 hours after July 1941 unchanged.

## 85. A war's start: the uncovered count leaves out the province attacked (confirmed, read on the listing)

Read on 2026-11-14. Two runs of the original from `Ireland1939_09_06_18.hoi3` - Germany six days into Poland - saved hourly for 48 hours: they give each other the same new way for 122 land units and one run alone gives one 34 times. OpenHOI3 gave 54 of those the same, 52 of its own alone and missed 54 that both runs gave, nearly all Germany's and Poland's.

- **At 21:00 on 6 September**, reproduced on the running game (the save reloaded, two hours run, `CEU3AI::MoveUnit`, `CEU3AI::IssueUnitOrder` and `CUnit::AIStandDown` logged for Germany and Poland): the 36. Infanterie-Division (mot) at 2269 attacks 2213 (0x4D7AB3) and the 6. Panzer-Division at 2154 supports it (`support_attack`, 0x4D7ADB). OpenHOI3 left both standing: both flagged to stay, so `movable < attackers` and no attack.
- **The flag's count**, `ai_uncovered_enemy_neighbours` (`CUnit +0x2BC`), written at 0x4D715A from the int at `[ebp-0x34]` that the loop 0x4D6EF0-0x4D7061 counts for the unit and the province it is offered (`[ebp-0x18]`): over the edges of the unit's province (`[ebp-0x24]`), not of kind 3, each neighbour whose template is simulated (+0x22), whose area answers its slot 0, and whose holder (+0x334) is an enemy (0x2F210) - **the province attacked is skipped** (0x4D6F69) - counts where `units_count` (+0x2C0, every unit standing there) plus the land units beside it stepping into it as their next province of the holder or its friends (`CollectUnitsMovingIntoProvince` with `enemiesOnly` 0, 0x4D6FA8) is at least 1, or where the unit's area holds one province and the neighbour's more than five (0x4D6FC1-0x4D6FDA); and is covered - not counted - where a land unit of the country standing in the unit's province is bound for it (0x4D6FE4-0x4D7023), or, at stance 4, any land unit of the country (`+0xBAC`, 0x4D702B-0x4D705F). OpenHOI3 had counted the province attacked, asked only for a land unit standing there, and taken any unit of the country bound there as covering it whatever the stance. So a lone neighbour - the one attacked - kept every unit beside it supporting.
- `target_area_provinces` (`CAIUnit +0x1CC`) was empty for both German agents at 21:00, read on the running game; it played no part.
- Built in OpenHOI3. The 48 hours after the 1939 save: the same as both runs 54 to 77, both runs' ways missed 54 to 33, OpenHOI3's alone 52 to 46. Entering the three saves, 4 January and the July 1941 series unchanged but for one German attack an hour later there.

## 86. A change of stance scores the area at the stance it leaves (confirmed, read on the running game)

Read on 2026-11-14, for the war start's next difference: at 21:00 on 6 September 1939 OpenHOI3's Oberkommando des Heeres pulled five divisions into the line (2570, 2700, 2701) and so placed no garrison or reserve that hour, where both runs of the original pulled none and placed both.

- **Entering a load, in both**: logged at `CEU3AI::UpdateUnitStances` and `CAIUnit::SetPlanStance` for Germany while the save was loaded - the first pass finds both agents bound with `front_coverage` (`+0x368`, the constructor's 0.0, 0x4AF9DE) nought, and posts stance 2 for OB West and the Oberkommando, whose saved stance is 4; the second, with coverage 1.000 and 0.931, posts 4 again. OpenHOI3 did the same.
- **What the scores are made at**: `SetPlanStance` calls `CAIUnit::ScoreOpsAreaProvinces` and `UpdatePlanAxis`, both of which read the plan's stance off the unit (`CUnit +0x208`) - and the new stance has only been posted (`CSetPlanAttributesCommand`). So the scores are made at the stance being left: after entering, the plan stands at 4 and its area is scored at 2 until the area is next set. Read on the running game at the end of `CAIUnit_FillLinePositions` (0x4CA9AA) at 21:00, the Oberkommando's positions are the stance-2 scoring's - 2701, 2700, 2327, 2503 and 2095 wanting 3 each - and nothing moves. OpenHOI3 had scored at the new stance, wanting 5 at 2570, 2701 and 2700.
- Built in OpenHOI3: the scores and the axis made at the plan's stance as it stands. The war start's 48 hours: OpenHOI3's ways alone 46 to 37, both runs' missed 33 to 31; the July 1941 series' ways no run gives 102 to 77. Entering the three saves and 4 January unchanged.
- Left over: positions of equal score come out in another order (OpenHOI3 2327, 2503, 2701, 2700; the original 2701, 2700, 2327, 2503), the insert at 0x4DD4B0 not read for equals.
