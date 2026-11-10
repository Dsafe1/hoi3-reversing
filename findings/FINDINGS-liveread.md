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
