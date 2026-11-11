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
