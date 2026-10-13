# War and peace: declaring a war, calls to arms and war goals, peace, the capitulation

Read out of the executable on 2026-10-13 by the war and peace wave (`WAVE.md`), four briefs, one
section each: **A** declaring a war, **B** calls to arms, war goals and casus belli, **C** peace,
**D** the capitulation. For OpenHOI3's fifth piece of diplomacy. Addresses are **virtual**, based
`0x400000`, with the rva beside anything named. Nothing needed the game running.

What this builds on and does not repeat: `FINDINGS-diploaction.md` sections 21-30 (the war-goal
chain, `SpreadThreat`, the slot-7 writes, `CCasusBelliType`'s loader offsets),
`FINDINGS-agreements.md` B.2, B.8, C.1, C.3 and E, `FINDINGS-diplostate.md` (a war's relation and
threat, war exhaustion), `FINDINGS-triggerleaves.md` (a truce), `FINDINGS-onactions.md` 2.2 (when a
surrender is tried) and `FINDINGS-effectrun.md` (the `war` effect, `AnnexCountry`, `MakeVassal`).

## A. Declaring a war (brief A)

Fragment `fragments/merged/declare-war.json`. S is the actor's status towards the recipient,
`actor->+0xE28[recipient]`; "real faction" means `CFaction` slot 7 is true.

### A.1 In one line

`CDeclareWarAction::Apply` (`0xA12030`, rva `0x612030`) makes a **new** `CWar` or **widens** an existing
one. It brings in **at once** the victim's puppets and the declarer's, the victim's guarantors (by a call
to arms built already accepted), and both sides' faction members - the attacking faction only where the
war is not limited; it **asks**, by offered calls to arms, the victim's overlord and both sides'
bilateral allies - the declarer's only where the war is not limited. It charges influence
(`WARDEC_INFLUENCE_COST`, 0 in Their Finest Hour) and relation (`WARDEC_WAR_DIPLOMACY_HIT`, -100),
spreads threat (`WARDEC_BELIGERENCY`, 33) **for a fresh war only**, ends the pair's alliance, NAP,
undeclared war, access, debt agreement and (without deleting it) guarantee, and tells the local player.
**A limited war is `value` 0**: it sets `CWar +0x70`, and its declarer's allies are not called and its
faction does not join; the defending side comes in as in any war.

### A.2 The order

1. **The faction leader's preamble** (`0xA12030`-`0xA121D3`, recorded 2026-10-06), only where the actor
   is in a real faction: the first enemy E on the actor's `enemies` (`+0x1008`) that leads its own real
   faction, where the recipient's faction is not real or is E's; `actor->diplomacy[E]->war` is kept; and
   where the recipient is in no real faction, `CFaction::AddCountry(E.faction, recipient, 0, 0)` - **the
   victim is put into the enemy's faction and the declaration widens that war.**
2. **The alliance and the NAP between the two** (S `+0x14`, `+0x28`), where there: slot 11
   (deactivate), unlinked from `CCurrentGameState +0xB2C`, deleted - no message and no relation change
   of their own (`0xA121FC`-`0xA12390`).
3. **The undeclared war** (S `+0x24`): `S+0x24 = 0` on **the actor's side only** (`0xA1239F`), unlinked
   from `+0xC10`, deleted through slot 0, which only frees vectors.
4. **The AI**: where `actor->strategy.IsPreparingWarWith(recipient)` (`0x8ADE10`),
   `CancelPrepareWar(recipient)` (`0x8AD650`).
5. **The war** (A.3).
6. **The goal**: `CWarGoal::AddToWar(&this->war_goal, war, actor)` and `RunCasusBelliOnAdd`; then the
   first casus belli on S of the goal's type is spent silently - `RemoveFromStatus` with notify false,
   unlinked from `+0xB2C`, deleted.
7. `war->action (+0xC) = tick`, fresh or widened (`0xA127F3`).
8. **Fresh only** (`cmp [esp+0x1F]` at `0xA127F6`): `CWar::GenerateName(war, 0)`, and where
   `this->value == 0`, `war->is_limited = 1` (`0xA1280C`).
9. `ChangeRelation(actor, recipient, -WARDEC_WAR_DIPLOMACY_HIT)`, -100, fresh or widened (`0xA12849`).
10. The action's join lists `+0x54` and `+0x64` emptied.
11. **Fresh only** (`0xA12892`): `SpreadThreat(actor, &WARDEC_BELIGERENCY, &1000, the recipient's acting
    capital)`. **Widening a war spreads no threat.**
12. `actor->diplo_influence -= WARDEC_INFLUENCE_COST` (0), floored at 0.
13. **Every country c, in database order, but the actor** (A.4 a-c).
14. Military access cleared both ways (`SetMilitaryAccess(0)`); `changed = 1` and `guarantee = 0` both
    ways, the `CGuarantee` not unlinked; `allowDebts = 0` both ways.
15. `CCountry::OnDiplomacyChanged` on the actor, then the recipient (A.9).
16. **The message and the sound** (A.7).
17. **The recipient's overlord** (A.4 d).
18. `CDeclareWarAction::BringInFactions` (A.4 e).
19. `CDeclareWarAction::CallAllies`: for the actor against the recipient **only if not limited**, then
    for the recipient against the actor always (A.4 f).
20. In a running game, `in_game_screen (+0xBE8) +0x84 |= 0x100`, and -1 pushed onto
    `CCurrentGameState +0xCF8`, the hourly intelligence refresh.
21. `CCountry::RebuildNeighbours` and `CCountry_AfterDiplomacyChange` (rva `0xE39C0`): the actor, then
    the recipient.

### A.3 New or widened

**With no war kept by the preamble**, a new one: `new(0xAC)`, `CWar::CWar` (rva `0x64D6D0`), appended to
`active_war` (`CCurrentGameState +0xC00`), `CWar::AddAttacker(war, 1, 0, actor)` and then
`AddDefender(war, 1, 0, recipient)`. **With a kept war**, the recipient joins on the side opposite the
declarer - a defender where the actor is among the attackers, otherwise an attacker, setting a flag
`recipientAttacks`. Everything later done "by side" follows that flag: which side the puppets join, and
which country `BringInFactions` is given as the attacking side.

### A.4 Who joins at once, and who is only asked

**(a) The victim's puppets, at once**: every c whose `Overlord (+0xF3C)` is the recipient and which is
not already a defender joins the recipient's side (`AddDefender`, or `AddAttacker` under
`recipientAttacks`), with history, and is listed on `+0x64` (or `+0x54`).

**(b) The declarer's puppets, at once**, the same way: every c whose overlord is the actor and which is
not already an attacker joins the actor's side.

**(c) The victim's guarantors, at once**: every other c where
`recipient->diplomacy[c]->guarantee->first == c`, c is not on `+0x64`, and c is not at war with the
recipient - a `CCallAllyAction(actor = recipient, recipient = c, third = the declarer)` is built with
`value` 1, `date` the tick and **`type` 2 (ACCEPT)**, made into a command (slot 6) and **executed on the
spot** (`0xA12D19`-`0xA12D2C`), so the guarantor joins inside this call, subject to
`CCallAllyAction::IsValid` (B.1). c is listed on `+0x64` whatever the call did. A guarantee made by a
faction (`CGuarantee +0x24` `via_faction`, which `FINDINGS-agreements.md` C.3 showed as never set - *corrected 2026-10-13: it is set for an Allies
member's guarantee, `FINDINGS-factionplay.md` B.3*) gets
no call, unless c is the declarer's puppet. *Corrected 2026-10-13, off the instructions: nothing here tests
`+0x24`. The block (`0xA12B40`-`0xA12BB3`) asks only that the recipient's status towards c holds a
guarantee (`+0x1C`) whose first is c, that c is not on `+0x64`, and that c is not at war with the
recipient; a by-faction guarantee's first is the member, so **the member is called like any guarantor**.
`CCallAllyAction::IsValid` tests no `+0x24` either. A declarer's puppet takes the puppet arm
(`0xA12AA6`) before this block is reached, which is all "unless" can mean.*

**(d) The victim's overlord is asked**: where the recipient `isSubject` and its overlord is not on
`+0x64`, `CCallAllyAction(recipient, overlord, declarer)`, PROPOSE, `value` 1, `date` the tick, executed
at once - which queues the offer on the overlord - and the overlord listed on `+0x64`.

**(e) The factions join at once**, in `CDeclareWarAction::BringInFactions` (`0xA16D00`, rva
`0x616D00`): on the attacking side, the attacking country's faction members but the two and those
already attacking - only where the faction is real **and the war not limited** - each by
`AddAttacker(war, 1, 0, m)`; on the defending side, the defending country's members but the two and
those already defending, **with no limited test**, each by `AddDefender(war, 1, 0, m)`. A member that is
the played country is told `FACTIONWAROFF`. No relation change for them and no `OnDiplomacyChanged`.

**(f) Bilateral allies are asked**, in `CDeclareWarAction::CallAllies` (`0xA147C0`, rva `0x6147C0`): for
every country c not on the caller's side list and not already in the war, where
`caller->diplomacy[c]->alliance` is set (`0xA148FC`) and c is not at war with the enemy,
`CCallAllyAction(caller, c, enemy)`, PROPOSE, `date` the tick, executed at once - its **`value` the
war's `is_limited`**. A PROPOSE of `value` 0 costs the caller `CALLALLY_INFLUENCE_COST` (1, B.1), so in
a full war the calling side pays 1 influence for each ally called. Faction members are already in the
war and skipped. A second arm tests the caller's own overlord against the declarer, which is reachable
only when a country declares war on its own puppet.

**Joining** (`CWar::AddAttacker`/`AddDefender`) does, for each country newly opposed: `SetPairWar` both
ways, which also ends the pair's influence and trade routes; `UpdateAtWarAndEnemies` on both; the
co-belligerent flags; a dated history entry where `recordHistory` is set; and the AI's broadcast (A.9).

### A.5 Limited war (`value` 0, the row "Declare Limited War", `war = { limited = yes }`)

Only a **fresh** war becomes limited; a limited declaration that widens a war leaves its flag as it was.
Once set, `+0x70` skips `CallAllies` for the declarer; skips the attacking faction in `BringInFactions`
and in `CFaction::AddCountry`'s war sweep (`0x4F6260`) for a leader on the attacking side; puts
`DECLWAR_LIMITED` "This war is a limited war." into LIM, but only where the declarer is in a real
faction; gives every call `CallAllies` makes `value` 1; and is **required** by `CCallAllyAction` slot 14
(`0xA2A58B`). So the screen's Call to Arms row exists only in limited wars, a full war having called the
allies already. `LIMITED_WARDESC` reads "A limited war won't force your allies to also declare war."
The history's wars are `limited=no`; in the BlackICE saves all 274 wars made in play are
`limited=yes`, and who declares them limited was not read.

### A.6 The name

`CWar::GenerateName(war, normalName)` (`0xA4DB50`, rva `0x64DB50`): the key `AGRESSION_WAR_NAME`
"$ORDER$War of $FIRST$ Aggression" for a declaration, `NORMAL_WAR_NAME` "$ORDER$$FIRST$-$SECOND$ War"
for the revolt war (`0x4BEB75`); FIRST and SECOND the adjectives of the first attacker and the first
defender. For n = 1, 2, ...: ORDER is empty for n = 1, else n + the localised suffix + " " - the suffix
key TH, ST, ND or RD by n % 10, 11 to 13 taking TH - and the first n whose name is on neither
`active_war` nor `previous_war` is taken (`CGameState_IsWarNameTaken`, rva `0x283EE0`). **No casus
belli's `war_name` is read.** The saves agree: "2nd War of German Aggression", "3rd War of Japanese
Aggression".

### A.7 The messages, and who is told

Only the local player (`played_country_id +0xC34`). **The declaration's** variables: the player's
`BuildMessageVariables`, AGRESSOR the actor's name, DEFENDER the recipient's, MESSENGER
`MESSAGE_HEAD_MARS` "The General Staff reports", BADWORD `MESS_BADWORDS1`-`3` by `actor.id % 3` ("the
fools" / "the traitors" / "the warmongers" - `MESS_BADWORDS4` "the imbeciles" cannot be reached), and LIM
(A.5).

| the player is | sound | key | province | messagetypes |
| --- | --- | --- | --- | --- |
| the declarer | `declarewar` | `WEDECLWAR` "We declared war on $DEFENDER$." | the recipient's acting capital | log |
| the recipient | `declarewar_onus` | `DECLWAR` "$AGRESSOR$ declared war on us!" (popup: "WAR!" / $MONARCHTITLE$, $BADWORD$ in / $AGRESSOR$ declared war / upon us! Prepare for battle... / $LIM$) | the declarer's acting capital | popup and log |
| anyone else | - | `DECLWAROTHER` "$AGRESSOR$ declared war on $DEFENDER$." | the declarer's acting capital | log |

A sound plays when the sound system's slot 25 answers false - that this means "not already playing" is
inferred.

**`FACTIONWAROFF`** goes to a faction member brought in (A.4 e) that is the player, popup and log, at
the recipient's capital: "$ACTOR$s aggression against $VICTIM$ brought the $FACTION$ into war!", the
popup having the $FACTION$ "join in this epic struggle for truth, justice and the $COUNTRY$ way"; ACTOR
the declarer, VICTIM the recipient, FACTION that loop's faction, COUNTRY the member's adjective, with
BADWORD, MESSENGER and MONARCHTITLE.

**`ALLYTAKEOVER` / `ALLYTAKEOVERWE`**, posted through `PostMessage_CWar` with the war as receiver and no
callback, only when a joiner is put at the **front** of a side - with `Apply`'s arguments, a faction
leader joining the attackers: `ALLYTAKEOVER` to the player who was leading, "$ACTOR$ assumed leadership
in our war against $TARGETLIST$."; `ALLYTAKEOVERWE` to the joining player, "We assumed leadership in the
war against $TARGETLIST$."; TARGETLIST the other side's names joined with ", ". Calls to arms raise
their own keys (B.1).

### A.8 `CWar`

**Its layout**, 0xAC bytes: `+8` `revolutionary_war`; `+0xC` `action` (a tick); `+0x10` `name`;
`+0x2C`/`+0x30`/`+0x34` the attackers; `+0x3C`/`+0x40`/`+0x44` the defenders; `+0x4C` a `CWarHistory`
by value; `+0x70` `is_limited`; `+0x74`/`+0x78`/`+0x7C` the call map (B.1); `+0x84` `target`; `+0x8C`
`original_attacker`; `+0x94` `original_defender`; `+0x9C`/`+0xA0`/`+0xA4` the war goals by actor id.

**`CWar::LoadKey`** (rva `0x64E610`), every key:

| key | token | goes to |
| --- | --- | --- |
| `name` | 0x1A | `+0x10` |
| `target` | 0x6A | `+0x84` |
| `history` | 0x1E1 | `+0x4C`, through its own load |
| `attacker` | 0x2B1 | `AddAttacker(this, 0, 0, tag)` |
| `defender` | 0x2B2 | `AddDefender(this, 0, 0, tag)` |
| `action` | 0x2ED | `+0xC` |
| `revolutionary_war` | 0x622 | `+8` = the value is `yes` |
| `limited` | 0x6C3 | `ParseBool` into `+0x70` |
| `war_goal` | 0x7A0 | filed under its actor **without** `CWarGoal::IsValid` |
| `original_attacker` | 0x7AD | `+0x8C` |
| `original_defender` | 0x7AE | `+0x94` |

An unknown tag is logged and skipped, the defender case's line saying "attacker". **`SaveContents`
never writes `target` or `history`** - neither key is in any of 490 saved wars - so after a load
`CWar::GetStartDate` (rva `0x651D20`) answers the null date and `GetCurrentRunningTimeInMonths` 0.
`target` and the two originals are `---` from the constructor, and nothing that makes or joins a war
writes them: the store census found only the constructor and `LoadKey`.

**`action`**: `Apply` sets it to now on every declaration, as does the revolt war. In the BlackICE saves
it equals the save's hour on every war with both sides filled, and stays frozen on one with an empty
side, so something refreshes it while a war is fought; that writer was not found.

**`CWar::AddAttacker(war, recordHistory, mayTakeLead, tag)`**: return if already there; `mayTakeLead` is
cleared where the side's first attacker is not a subject; the joiner goes to the **front** where it
leads a real faction or `mayTakeLead` survives, otherwise to the back; the co-belligerent flags; a
history entry where `recordHistory` is set; then for each defender `SetPairWar` both ways,
`UpdateAtWarAndEnemies` on both, and the broadcast on channel 0x15. **`AddDefender`** is the same
**without the faction leader's test**: the front only with `mayTakeLead` and an empty side, or an
unplayed or subject first defender. Every caller passes `mayTakeLead` 0 but `CCallAllyAction::Apply`;
`recordHistory` is 1 from `Apply`, `BringInFactions` and `CCallAllyAction`, 0 from the loader, the
history replay, the revolt war and `CFaction::AddCountry`.

**`RemoveAttacker`/`RemoveDefender`**: C.9. They never end a war whose side empties, and the saves hold
wars with no attackers or no defenders.

**Where the wars are kept**: `CCurrentGameState +0xC00` (active), a `CListNode<CWar*>` chain, payload
`+0`, next `+8`, and `+0xC20` (previous). A pair's war is `countries[a]->diplomacy[b]->war (+0x20)`.

### A.9 What a new war does outside `Apply`

**`at_war` (`CCountry +0xACC`)** is made by `CCountry::UpdateAtWarAndEnemies` and nothing else, and
`CCountry::IsAtWar` reads it. That runs on both countries at every change of a war's membership and as a
session is entered, and for every pair at war sets `+0xACC`, appends to `enemies`, and stamps
**`this->diplomacy[it]->last_war = tick`** - not hourly and not at a war's end (C.11, which reaches the
same correction independently): the remove functions clear the pair's war first, so the stamp skips them;
no pair at war in 47 saves carries the save's own hour; and each save's latest stamp is its session's
load or a change of membership.

**Mobilisation**, in the same function: on becoming at war and not yet mobilised, the timed static
modifier `initial_mobilization` (`reinforcement_bonus = 1.0`) for `MOBILIZATION_BONUS_DAYS` (30) days,
and `+0x94 = 1`; at peace (flags 0, 0) it is taken off a country nobody plays only. In a running game it
also rebuilds the AI's strategy and theatres.

**Units and battles.** `OnDiplomacyChanged` on the two principals runs `CCombatManager_RecheckCountry`
(rva `0x30050`), which finishes battles no longer live and runs `CheckForCombat` for every idle unit not
retreating - **battles start at once, and a unit alone in an enemy province takes control of it at
once** (CheckForCombat's step 5); then `UnitList_MarkTrespassers` (rva `0x1D6230`) sets `CUnit +0x1A8` on
units standing where their owner may not go - no attacking, no capture, full speed, may walk through,
and the AI pulls them home. **Nothing moves them**, and war is itself leave to enter, so a declaration
makes no trespassers among the belligerents; `CUnit::UpdateHourly` works the flag out again every hour.
Joiners other than the two principals get no `OnDiplomacyChanged`; their units fight in their next
hour, when `CheckOrderAndCombat` runs `CheckForCombat`. A country not at war has
`CCountry_RevertDisallowedLaws` (inferred) post law changes for laws whose `allow` fails.

**The AI's broadcast.** Each new pair goes out on listener channel 0x15 to slot 41 of every subscriber
(`BroadcastToListeners2`): `CAIForeignMinister` (OnWar -> Lua `ForeignMinister_OnWar`, **empty in Their
Finest Hour**) and `CAIEspionageMinister` (an empty stub). `CGameState::StartAI` replays it for every
active war.

**The undeclared war** (`UpdateUndeclaredWars`): a declaration replacing one does not run it, so
`in_undeclared_war (+0xACD)` and the list at `+0x1018` go stale, and the recipient's `+0x24` dangles.

### A.10 Slots 13 and 14

**Slot 13** (`IsValid`): no war, no alliance, not one real faction, then
`CWarGoal::IsValidForWar(&war_goal, null)` (`0x47BF70`, rva `0x7BF70`) - the goal's casus belli a real
type, its receiver owning a province, the type's `allowed_countries`/`allowed_regions` holding. So **a
declaration posted as a command needs a valid war goal**; the `war` effect calls `Apply` directly and is
not gated. **Slot 14** calls nothing unread: `IsRebelTag`, `HasDiplomatEnroute`, `HasTruce`,
`CanBreakNap` four times, `GetMaxNeutralityForWarWith`. The unrecorded `0x4EA9F0` sits in the next
function, slot 11's text.

### A.11 What looks wrong and is what the bytes do

1. The guarantors' call to arms is built already accepted and executed inside `Apply`; the victim's
   allies and overlord are only asked.
2. A widened war gets no threat, no name and no limited flag; the -100 and the influence still apply.
3. `DECLWAR_LIMITED` shows only where the declarer is in a real faction.
4. `MESS_BADWORDS4` can never be chosen (`id % 3`).
5. The undeclared war is nulled on the actor's side only and its object freed, so the recipient's
   `+0x24` dangles.
6. The guarantee between the belligerents is nulled but not unlinked (`FINDINGS-agreements.md` C.3).
7. `AddDefender` lacks `AddAttacker`'s faction-leader rule, so a faction leader joining as a defender
   never takes the lead.
8. `CallAllies`' second arm tests the caller's own overlord against the declarer.
9. A guarantor whose call failed is still listed as joined, so it is not asked again as an ally.
10. `last_war`, and so the truce, counts from the last change of membership or load, not from the
    war's end.
11. A war's history is never saved: after a load its start date is null and its running months 0.
12. `target` and `original_*` are loaded and never set in play, and `target` never saved.
13. The loader's defender error says "attacker".

### A.12 Not settled

- Who refreshes `CWar +0xC` `action` while a war is fought: the saves show it, and no writer was found
  but `Apply` and the revolt war.
- Why every war made in play in a BlackICE game is limited: the AI's or the mod's declaring path was not
  read.
- The `CCountry +0x44` gate in `CCountry_AfterDiplomacyChange`, and the law slot and trigger in
  `CCountry_RevertDisallowedLaws` (both inferred).
- Whether anything reads the recipient's dangling `undeclared_war` before it is next made.

### A.13 Frontier (rvas)

`0x651F40` (a war's last dated history entry), `0x4BE590` (the revolt war's making), `0x430140` (a
country's battles gathered), `0x47C280` (the equal-goal find), `0x600870` and `0x600D50` (history change
setters), `0x49E490` (`CAIForeignMinister::OnWar`, recorded `likely`), `0x6995D0`, `0x652750` (the war
goal map's find-or-insert).

## B. Calls to arms, war goals and casus belli (brief B)

Fragment `fragments/merged/war-goals.json`. `type` is the action's `+0x18` (0 PROPOSE, 1 DECLINE, 2
ACCEPT), `value` the bool at `+0x24`; figures are thousandths; the defines are Their Finest Hour's.

### B.0 In one line

- **A call to arms comes in two kinds, by `value`.** **0** is the screen's "A Call to Arms!" row:
  offered only in a limited war, it costs the caller influence, and a person called is joined without
  being asked. **1** is what `CDeclareWarAction::Apply` makes (already ACCEPT, executed on the spot)
  and Lua's `CCallAllyAction.Create` makes by default: it costs nothing, and a person called gets the
  `CALLREQDESC` dialog.
- **The declare-war and add-war-goal rows both open `CWarGoalDialog`**, which lists the casus belli
  types whose `is_valid` holds against the recipient, that the player holds or that are `always`, and
  whose goal is still to be had; it asks for a third country or a region where the type needs one,
  and posts the action as ACCEPT with that goal in it.
- **A casus belli made in play does nothing.** Every one is type 0, the null type, which no typed test
  sees. In Their Finest Hour 11 of the 12 types are `always = yes`, so holding one changes nothing in
  practice; `prerequisites` and `months`, which the file says make and time casus belli, are read by
  nothing.
- **`CWar +0x70` is `limited`**: set on a war declared with `value` 0, and a call to arms can be chosen
  from the screen only in such a war - both earlier readings were right.

### B.1 `CCallAllyAction`

The parties: the actor `+0x8` (the caller), the recipient `+0x10` (the ally called) and `Versus`
`+0x28` (the enemy). W is the caller's war with Versus.

**The war's call map, `CWar +0x74`** - a `std::map<int,int>` keyed by country id, set to 1 when a
PROPOSE runs, to 0 when the call is answered either way, and read by `IsValid`. It is neither saved nor
loaded (`CWar::SaveContents` `0xA4EC90` and `CWar::LoadKey` `0xA4E610` have no `+0x74`; their `+0x70`
is the control), so a reload forgets which calls are pending. The subscript (`WarCallMap_Subscript`
`0xA526D0`, rva `0x6526D0`, and the same template as `IntIntMap_Subscript` `0x421340`, rva `0x21340`)
inserts a 0 where the key is missing.

**`IsValid`** (slot 13, `0xA2A3C0`), all of: the recipient is not at war with Versus; the caller is (W);
not (Versus is in a real faction the recipient is in too); the recipient is on neither of W's sides
(`+0x2C`, `+0x3C`); and W's call map for the recipient is 0 **or** `type` is not PROPOSE. So a second
call to one country before it answers is invalid, and the answers always pass.

**`IsSelectable`** (slot 14, `0xA2A4E0`) - what greys the row: actor = recipient; the caller not at war
with Versus; Versus in a real faction shared with the recipient; **W not `limited` (`+0x70`)**;
influence under `CALLALLY_INFLUENCE_COST` (diplomacy `+0x1C`, 1.0); a side of W empty; the puppet
rules - a recipient that is no subject needs the caller to be **the first country of its side**
(`attackers[0]` or `defenders[0]`), the caller's own puppet needs only the caller in W, someone else's
puppet needs the caller to lead its side and the puppet's overlord already on that side; and the
recipient holding a NAP with any real country on the side the caller fights.

**`GetDescription`** (slot 11, `0xA29D40`), the row's tooltip, the first line that applies: `ENROUTE`
"We have a diplomat enroute, and he will arrive on $DATE$"; `DIP_NO_INFL` "You do not have the
§Y$INF$§W diplomatic influence required" (INF to 2 decimals); only where the caller is at war with
Versus **and leads its side**, `CAN_NOT_JOIN_WAR_NAP` "They can not be called to our war because of a
non-aggression pact with §Y$COUNTRY$§!", the first such country in country-database order; otherwise
`CALLDESC` "Call on your partner to aid you in this conflict."

**`GetDialogText`** (slot 12, `0xA2A810`), the standard request dialog's description: `CALLNEWDESC`
"Do you wish to call upon your Allies in these times of war?" (its COUNTRY variable unused) + "\n" +
`DIP_INFLUENCECOST` "This will cost us §Y$COST$§W diplomatic influence points.", COST to 2 decimals.
Slot 18 (`NeedsAnswer`) is `type == PROPOSE`, so the dialog shows the AI's chance word
(`FINDINGS-agreements.md` B.5). Slot 15, the token, is `0x309` `callaction`.

**The screen's row** (`GetDiplomaticActionsToward`, `0x4E422C`): the enemy is the first of the
player's enemies (`+0x1008`) the player is at war with, the recipient is not, and whose war is limited;
the recipient must be allied with the player (status `+0x14`) or in the same real faction; the row's
action is made with **value 0** (`mov byte [ebx+0x24], 0` at `0x4E426F`).

**`Apply`** (slot 7, `0xA27BA0`, rva `0x627BA0`), in order, after the message variables - the
player's standard list, ACTOR, RECIPIENT, MESSENGER = `MESSAGE_HEAD_CHAN`, VERSUS = the enemy's name:

*PROPOSE:* W's call map for the recipient = 1; **only where `value` is 0**, the caller's influence -=
`CALLALLY_INFLUENCE_COST` (1.0), clamped at 0.

*ACCEPT:*

1. call map for the recipient = 0;
2. on the recipient's status towards Versus the alliance, the guarantee and the NAP are each
   deactivated, unlinked and deleted, and an undeclared war between them is taken off the game
   state's list (`+0xC10`) and deleted;
3. the side joined is the caller's - attackers if the caller attacks, otherwise defenders;
4. a flag `lead`: set where the side's first country owns fewer provinces (`+0xCF8`) than the
   recipient, cleared where the recipient is a subject, set where the recipient is the caller's
   overlord;
5. `SetMilitaryAccess(0)` both ways between the recipient and Versus;
6. **defenders**: `CWar::AddDefender(W, 1, lead, recipient)`; **attackers**:
   `CWar::AddAttacker(W, 1, lead, recipient)`, then, unless the recipient is the caller's puppet,
   `AddCasusBelli(recipient, Versus)` (`0xA2893C`) at once followed by `ClearCasusBelli` on that same
   status (`0xA28958`) - which unlinks the new casus belli and any others from the status, the objects
   staying in the relation list;
7. `ChangeRelation(Versus, recipient, -WARDEC_WAR_DIPLOMACY_HIT)`, -100;
8. `OnDiplomacyChanged` on the caller, the recipient and Versus;
9. TARGETLIST = the names of the side the recipient now fights, joined with ", ";
10. a branch behind the recipient's `+0xDE4` (the ALLIANCE_GUARANTEE faction rule) would call in each
    of its faction's members not already defending, as accepted calls executed on the spot - **nothing
    writes `+0xDE4`** (`FINDINGS-agreements.md` C.3), so it is dead; *corrected 2026-10-13: `CCountry::RebuildRules` writes it for every Allies member (`FINDINGS-factionplay.md` B.3), so the branch is live;*
11. messages: the caller played, the `diplomaticsuccess` sound and `MILALLHONOUR` (popup); the
    recipient played, `WEMILALLHONOUR` where `value` is set (log only), or where it is 0
    `FACTIONWAROFF` (joined the attackers) or `FACTIONWARDEF` (the defenders), "§Y$ACTOR$s§W aggression
    against §Y$VICTIM$§W brought the §Y$FACTION$§W into war!", VICTIM = Versus and FACTION the caller's
    faction (popup); anybody else, `OTHERMILALLHONOUR` (log);
12. `DeleteAreaGroups` (`0x47FFF0`), `RebuildAreaGroups`, `DeleteSupplyGroups` (`0x4807F0`),
    `RebuildSupplyGroups`.

*DECLINE:*

1. call map for the recipient = 0;
2. `ChangeRelation(recipient, caller, ALLIANCE_REJECT_RELATION_CHANGE)`, -50;
3. `AddCasusBelli(caller, recipient)` - a type 0 casus belli for the caller on the refuser;
4. **the caller-recipient alliance, where there is one, is deactivated, unlinked and deleted**;
5. TARGETLIST = the side the caller fights;
6. messages, **only where an alliance was broken**: the caller played, `diplomaticfailure` and
   `MILALLDISHONOUR` (popup); the recipient played, `WEMILALLDISHONOUR`; anybody else,
   `OTHERMILALLDISHONOUR` (log).

**Asking the player.** A value-0 PROPOSE to the player is accepted for him unasked. A value-1 PROPOSE
opens `CAskJoinWar` (`CALLREQDESC` "The nation of $COUNTRY$, your faithful ally, is requesting that
you come to their aid in the conflict against $LIST$.", with the `WCRD_*` and `CW_WARN*` lines;
recorded before), which closes after two months; **where the caller's war has ended while it is open,
its `IsStillOpen` reads the war's sides through a null pointer** (`0x615F06`). An AI's answer is
`DiploScore_CallAlly` (`CCallAllyAction::GetAIAcceptance`, rva `0x62AC80`), not read here.

### B.2 The declare-war dialog and the add-war-goal action

**The window** is `DeclareWarDialog` in `interface/wardialog.gui` (520x500 at x=300), opened by
`DiplomacyView_OpenActionDialog` for tokens `0x2F5` (declarewar), limited war and `0x7A4`
(add_war_goal). Its elements: `bg_diplo_new`, `WarBackground` (`GFX_bg_declare_war`),
`diplo_popup_banner_red`; `Title`, the action's slot 10 - `WARTITLE` "Declare War", `LIMWARTITLE`
"Declare Limited War" or `WARGOALTITLE` "Add war goal"; `LeftShield` the actor's flag, `RightShield`
the recipient's; `Description` (instantTextBox, Arial14_black, centred, 200x275 at 275,135) =
`CWarGoal::BuildSetupText` of the goal being made, refreshed every frame; three overlapping windows at
(50,128) - `wargoal_setup` with the `wargoal_list` listbox, `wargoal_state_select` with `state_list`
and `cancel_select` "Cancel" (ESCAPE), `wargoal_country_select` with `country_list` and
`cancel_select`; and `AgreeButton` "I do" (`PW_I_DO`) and `DeclineButton` "Rather not"
(`PW_RUN_AWAY`).

**The constructor** (`CWarGoalDialog_Construct`, `0x4775D0`, 0xA8 bytes) **clones the row's action**,
the clone at `+0x6C` and the same pointer at `+0x78`; the dialog fills the clone's own `CWarGoal` at
action `+0x28` (type `+0x34`, third country `+0x38`, actor `+0x40`, recipient `+0x48`, region `+0x50`),
binds both `cancel_select` buttons and builds the goal list.

**The goal list** (`CWarGoalDialog_BuildGoalList`, `0x477B30`): each casus belli type in database order
(`cb_types.txt`'s, the null type first) for which all hold -

1. the type's `is_valid` passes in a scope whose country is the recipient, THIS the player's country;
2. the player's status towards the recipient holds a casus belli of that index, **or** the type is
   `always`;
3. `CWarGoal_IsAvailable` holds for {type, actor, recipient, no third country, no region};
4. where `allowed_regions` has conditions, `CWarGoalDialog_HasPeaceRegionFor` holds too (a province
   of a `useForPeace` region passes `allowed_regions` with THIS the player and FROM the recipient).

Each becomes a `wargoal_item` row (`CGoalEntry`): `select_goal`'s text is the type's localised name
("Retake our cores"), `wargoal_icon`'s frame its `sprite_index`; no tooltip is set. Neither
`is_triggered_only`, `months`, `prerequisites` and `mutual`, nor the war's `limited` flag and
influence, are tested here.

**Choosing.** **A goal clicked** (`CWarGoalDialog_SelectGoal`): in a tutorial the hook
`wargoal_selected_<key>` fires first; the goal is set to {type, no third country, the action's actor
and recipient, no region} and `wargoal_setup` hidden; where `allowed_countries` has conditions the
country list opens - every country of the game state for which `allowed_countries` passes in the
recipient's scope, THIS the player and THIS's FROM the candidate; else, where `allowed_regions` has
conditions, the state list - every `useForPeace` region with a province passing in {province, THIS the
player, FROM the recipient} whose goal with that region is to be had, in map order, each row the
region's name; else `wargoal_setup` comes back. **A country picked** sets the third country, then opens
the state list where regions are needed, else goes back to the setup. **A state picked** sets the
region and goes back. **Cancel**, in either list, resets the goal to the static null type and goes back.

**Every frame** (`CWarGoalDialog::Update`) the description is refreshed and `AgreeButton` enabled
exactly while the action's `IsValid` (slot 13) holds.

**What it posts.** **Accept** sets the clone's `type = 2` (ACCEPT), makes the command, posts it through
the idler and closes - it stamps no date and rebuilds no list (the standard dialog's Accept stamps the
date); being ACCEPT, `Execute` writes no `next_offer_allowed` and queues the clone on the actor's own
pending list, where it is deleted unshown. **Decline** rebuilds the action list if the recipient is
still selected, and closes. **`IsStillOpen`** keeps the dialog while the diplomacy view is shown and
its `action_dialog` (`+0x518`) is null or this dialog; the action is not tested again.

**The dialog shows no costs.** It never calls the action's slot 12, so `CDeclareWarAction`'s slot 12
text (`DECWARREQDESC2` "Declare war on $COUNTRY$.", `LIM_WARDESC`, `CW_WARNALLIES`,
`CW_WARNGUARANTEED`, `DIP_INFLUENCECOST`, `DIP_THREAT`) is never shown for a declaration - no `+0x30`
slot call anywhere in `0x4775D0`-`0x479620`.

**`CWarGoal_IsAvailable`** (`0x47BC60`) - whether a goal can still be chosen: false if the type is not
real; false if `allowed_countries` has conditions and no third country is set; **needing a region with
none set**, true where a province of any map region passes `allowed_regions` in {province, THIS the
actor} (FROM empty) and the war, if any, holds no identical goal with that region; **otherwise, where
`allowed_province` has conditions**, the recipient's owned provinces are tried in {province, THIS the
actor, FROM the recipient} - none passing, false; one passing, true where there is no war, else true
unless the goal is already among the war's goals for the actor (`0x47C280`, not read); **else** true
unless the same goal is already in the war.

**`0x47BF70`** (brief A records it): the goal in EDI, the war on the stack; whether the goal is
complete - the type real and the recipient owning a province; where `allowed_countries` has
conditions, the third country passes; where `allowed_regions` has conditions, a region set and one of
its provinces passing; and the same goal not already in the war. Called by
`CAddWarGoalAction::IsValid`, `CWarGoalBaseAction` slot 13 (JoinFactionGoal), `CDeclareWarAction` slot
13 (`0xA15E3F`) and the capitulation.

**The add-war-goal action.** `IsValid`: the pair at war, the cooldown past, `0x47BF70(goal, war)`.
`IsSelectable`: at war and the cooldown past. **The cooldown** (`Country_CanAddWarGoal`, `0x4E67D0`):
`next_wargoal_date < tick`, strictly, stamped by `CWarGoal::AddToWar` as now + `WARGOAL_ADD_COOLDOWN`
(1 month); a bypass global at `0x1A855A0` is read there only and written nowhere. **Tooltip** (slot 11):
`DIPL_NOT_AT_WAR` with no war (it has no text, so the key shows); else `CAN_NOT_ADD_WARGOAL_UNTIL`
"Can not add a new war goal until §Y$DATE$§W" while the cooldown runs; else empty. Slot 12,
`WARGOALDESC` "Add another war goal against $COUNTRY$", is never shown, the row opening
`CWarGoalDialog`. Slot 21 is ReturnTrue, so the row also greys while a diplomat is on his way, with no
tooltip line saying so. **`Apply`** is `CWarGoalBaseAction::Apply` (recorded): the goal added, `on_add`
run, one casus belli of the goal's type spent.

### B.3 Where a casus belli comes from, and what each type key does

**Every source found:**

- **the history** (`history/diplomacy` `casus_belli` blocks, through `ReadDiplomaticHistoryFile`) and
  **the save** (`CDiplomacy::LoadKey`), carrying a type and dates - Their Finest Hour's history has
  none and the 12 saves none;
- **`AddCasusBelli`** (rva `0xE6640`), which always makes **type 0**, permanent, from five callers:
  `casus_belli = TAG` and `add_casus_belli = TAG` (31 uses in the base game's events and decisions);
  the call to arms, twice (B.1); and the rebels' defection (`0x4C0B50`, from `0x4BA6E1` after a
  faction's `defect_delay`) - the province's old owner gains one on the country it defected to, with
  `THEYDEFECT` "$PROV$ defected to us." / `WEDEFECT` / `OTHERDEFECT`;
- **nothing else.** `prerequisites` ("automatically activates a CB") has no evaluator: a `.text` sweep
  for `lea`/`add +0xB0` followed by a virtual call finds only the loader, where the same sweep finds
  all five `allowed_regions` evaluations. `months` (`+0x1F4`, default 12) has no reader. And every type
  of Their Finest Hour's is `is_triggered_only = yes`, which the file says turns `prerequisites` off
  anyway.

**Type 0 is the `CNullCasusBelliType`**, whose slot 7 is false: `DiplomacyStatus_HasUsableCasusBelli`
skips it, the dialog's held-test matches by index so it never makes a goal available, and **the
`casus_belli = TAG` trigger never sees what the `casus_belli = TAG` effect gives**. In Their Finest Hour
every type but `civil_war` is `always = yes`, so the trigger and the goal list come down to "some
always-type's `is_valid` holds", and a held casus belli matters only for `civil_war`, which nothing in
play can make.

**Its life.** `Activate` (slot 10, recorded): an undated one attaches at once, a dated one only before
its end date. `IsOver` (slot 6): true only for a dated one past its end, which the daily
`CDiplomacyStatus_ExpireRelations` removes silently. `CCasusBelli::Deactivate` (slot 11, `0xA47D20`):
`RemoveFromStatus(notify = true)`, the only way to `WELOSECB` - which has no message type in either
`messagetypes.txt` and no text; its one caller found is the history replay's take-back arm
(`CCasusBelliChange` slot 7, `0x5F3110`), which runs before play with `in_game` clear.
`CCasusBelli::SaveContents` (slot 2): `type` = the type's key, then `CRelation`'s keys.

**Each `CCasusBelliType` key and where it is read.** The loader re-derived from its jump table; "none
found" means a `.text` sweep of memory operands and `lea`/`add` at that offset found nothing outside the
loader and the constructor.

| key | offset | default | read by |
| --- | --- | --- | --- |
| `is_valid` | `+0x30` | | `CanUseCasusBelliType`, `IsValidWithTrigger`, the dialog's goal list |
| `is_valid_join` | `+0x70` | | none found |
| `prerequisites` | `+0xB0` | | **none** |
| `allowed_regions` | `+0xF0` (child count `+0x100`) | | `IsAvailable`, `0x47BF70`, the dialog's region checks |
| `allowed_province` | `+0x130` (`+0x140`) | | `IsAvailable`; `CWarGoal::Enforce` (D.4) |
| `allowed_countries` | `+0x170` (`+0x180`) | | `IsAvailable` (whether present), `0x47BF70`, the country list |
| `peace_cost_factor` | `+0x1B8` | 1.000 | none found |
| `penalty_factor` | `+0x1BC` | 1.000 | none found |
| `threat` | `+0x1C0` | 0 | `CWarGoal::Enforce` `0x47B24F` (D.4) |
| `truce_months` | `+0x1D0` | 60 | none found (C.11) |
| `po_*` | list at `+0x1E0` | | `CWarGoal::Enforce` (D.4); `po_concede_defeat` (`0x79B`) is no case and is reported as an unknown key |
| `is_triggered_only` | `+0x1F0` | | none found |
| `mutual` | `+0x1F1` | | **never read** (the byte sweep's control finds `+0x1F2` three times and `+0x1F3`) |
| `always` | `+0x1F2` | | `CanUseCasusBelliType`, `CasusBelliTypeIsAlways`, the goal list |
| `handles_peace` | `+0x1F3` | | `CWarGoal::Enforce` `0x47A976` (D.4) |
| `months` | `+0x1F4` | 12 | **none** |
| `war_name` | `+0x1F8` | | none found here (brief A, the war's name) |
| `country_desc`, `prov_desc` | `+0x214`, `+0x230` | | none found |
| `on_add` | `+0x24C` | | `CWarGoal::RunCasusBelliOnAdd` |
| `is_civil_war` | `+0x26C` | | only Lua's `CWarGoal::IsCivilWar` (`0x47C1F0`) |
| `on_completion` | `+0x270` | | `CWarGoal::Enforce` `0x47B288` (D.4) |
| `sprite_index` | `+0xC` | | the goal rows' icon |

**`FINDINGS-diploaction.md` section 27 had `+0x1F4` as `truce_months`; it is `months`.** The loader's
switch, read again by the collecting session (`scripts/switchmap.py` over `0x4165F0`, each case's first
store): token `0x792` `truce_months` stores at `+0x1D0` (`0x4167BC`), token `0x32A` `months` at
`+0x1F4` (`0x416650`).

**Declaring with a casus belli and without.** Everything read here makes holding one change three
things and no cost: **the neutrality ceiling** - `CCountry::GetMaxNeutralityForWarWith` adds
`NEUT_REDUCTION_AT_CLAIMS` (20) where the `aquire_all_cores` type is usable and its goal is to be had,
which, the type being `always`, is really "its `is_valid` holds"; **which goals the dialog offers**;
and **the casus belli of the goal's type is spent** (`CDeclareWarAction::Apply` `0xA126AF`, as for an
added goal). The declaration's influence and threat (`WARDEC_INFLUENCE_COST` 0.0, `WARDEC_BELIGERENCY`
33.0) carry no casus belli term in the record's reading of `Apply` (brief A); a goal's own `threat` is
paid when the goal is enforced (D.4).

### B.4 `CWarGoal`

**The object** is 0x2C bytes (Lua's size 44): `+0x0` vftable `0x15BDB34`; `+0x4` persistent id 0x18D;
`+0x8` a dword no constructor sets and the copy constructor copies; `+0xC` `casus_belli`
(`CCasusBelliType*`); `+0x10` `Country` (the third country); `+0x18` `Actor`; `+0x20` `Recipient`;
`+0x28` `Region`. Made by `CWarGoal_Construct` (`0x4797C0`, from a type), `CWarGoal_Make` (`0x479810`,
from a name, an unknown name giving the null type) and `CWarGoal_CopyInto` (`0x4798E0`).

**`CWarGoal::LoadKey`** (rva `0x79A90`) reads five keys: `actor`, `receiver`, `country` by tag;
`region`, a map region by name; `casus_belli` by name - where the name gives the null type it is read
again as a number and used as a database index (`atoi`), falling back to element 0.
**`SaveContents`** writes `region` when set, `casus_belli` (the type's key) when the type is real, then
`country`, `actor`, `receiver`, each when its id is not 0. The start save's Italy-Ethiopia goal is
exactly `casus_belli="puppet" actor="ITA" receiver="ETH"`.

**`CWarGoal::BuildSetupText`** (rva `0x79D40`): the text `<key>_setup`, ACTOR and RECIPIENT as "§Y name
§W"; the text's own replacement keys are scanned for THIRD and STATE; a third country set fills THIRD,
and with none while the text uses THIRD the whole answer is `WARDIALOG_SELECT_COUNTRY`, which has no
text; a region set fills STATE, and with none while the text uses STATE the whole answer is
`WARDIALOG_SELECT_STATE` "Select a §Yregion claim§W."; otherwise "§W" + the text, and empty for a null
or unreal type.

**Lua's names.** Lua's `CWarGoal::IsValid` (`0x479930`) is the "type is real" test alone;
`IsValidWithTrigger` (rva `0x79950`, recorded until now as `CWarGoal::IsValid`) adds the `is_valid`
block, and is what `AddToWar` gates on.

### B.5 What looks wrong and is what the bytes do

1. A call to arms can be chosen from the screen only in a **limited** war; a full war brings allies in
   through `CDeclareWarAction`.
2. A value-0 call from an AI to the person playing is **accepted for him unasked**; value-1 calls are
   the ones that ask.
3. Influence is charged for a value-0 call only; the dialog's cost line shows regardless.
4. Declining a call **breaks the alliance** with the caller, and only then are the DISHONOUR messages
   sent; with no alliance, no message, though the -50 and the casus belli still come.
5. An ally joining as attacker is given a casus belli on the enemy and loses it, with every other, in
   the next call; the objects stay in the relation list, are saved, and **attach again on load**
   (`CDiplomacy::LoadKey` activates each).
6. Every casus belli made in play is the null type; the `casus_belli` trigger never matches what the
   `casus_belli` effect gives.
7. `prerequisites`, `months`, `mutual`, and as far as was swept `truce_months`, `peace_cost_factor` and
   `penalty_factor`, are read and never used; `po_concede_defeat` is an unknown key to the loader.
8. `FINDINGS-diploaction.md` section 27 mislabelled `+0x1F4`: it is `months`, and `+0x1D0` is
   `truce_months`.
9. The declare-war dialog never shows the influence cost, the threat or the ally warnings the action's
   slot 12 builds.
10. The war-goal dialog posts as **ACCEPT**, so no seven-day stamp is written.
11. The add-war-goal row greys while a diplomat is on his way without saying so.
12. `IsStillOpen` for a call to arms reads through a null war pointer if the caller's war ends while
    the dialog is open.
13. `CALLNEWDESC` has a COUNTRY its text does not use; `WARDIALOG_SELECT_COUNTRY`, `DIPL_NOT_AT_WAR`
    and `WELOSECB` have no text, and `WELOSECB` no message type.
14. The cooldown has a bypass flag at `0x1A855A0` nothing can set.

### B.6 Not settled

- What `0x47C280` compares, and so exactly what "the same goal" means in `IsAvailable`'s two finds.
- `CWar::AddAttacker`/`AddDefender`'s second and third arguments, passed as 1 and `lead`: that `lead`
  makes the joiner its side's leader is inferred from how it is worked out (brief A).
- Whether `0x47BF70` makes a goal compulsory for declaring war (brief A).
- The `CWarGoalDialog` constructor's `message_dialog` call on the window (slot `+0x78`), and whether a
  screen-level tooltip covers `select_goal`, `select_state` or `select_country`.
- The description before any goal is chosen is presumably empty, the row's action carrying the null
  type; that rests on the cancel path and was not read on the rows' constructors.
- The negatives for `is_valid_join`, `peace_cost_factor`, `penalty_factor` and `truce_months` cover only
  the swept areas: war, war goals, the declaration, diplomacy, the AI `0x89D000`-`0x8AA000`, script,
  the daily pass.
- `CWar +0x70` "set on all 19 wars" in the record's live reading disagrees with Their Finest Hour's
  saves, which all have `limited=no`; that reading was probably of a BlackICE game. Not checked.

### B.7 Frontier (rvas)

`0x7C280` (the war-goal vector find), `0x647D60` (called twice by `RemoveFromStatus`), `0xC0B50` (the
rebels' defection; its `AddCasusBelli` at VA `0x4C0C30`), `0xBC800` (the defection's target),
`0x1F3110` (`CCasusBelliChange` slot 7), `0x160B0` (`CCasusBelliType`'s constructor, where the defaults
come from), `0x44CB60` (the date formatter), `0x7BF70` (brief A's).

## C. Peace (brief C)

Fragment `fragments/merged/peace.json`. Texts are Their Finest Hour's English.

### C.1 In one line

A peace offer is a bare `CPeaceAction` - actor, recipient and nothing else. Only the leaders may make
it (C.3), and only a person does: the AI's Lua never builds one. `DiploScore_PeaceAction` answers on a
spy-dependent, randomly blurred comparison of strength (C.6). Accepted, occupied provinces change hands
where the occupying side has a core there; the first attacker and every defender hand back the rest
of what they hold of each other, and the daily province pass returns the remainder; every
attacker-defender pair stops being at war. It costs nothing, moves no relation and enforces no war
goal, and the `CWar` stays in `active_war` for good with whatever members were not removed. **The truce
is 2400 hours from a `last_war` stamp that is refreshed only on a load and on a change of a war's
membership** - not every hour of a war, which corrects the record.

### C.2 The action has no terms, and the AI never offers one

`sizeof(CPeaceAction)` is 0x28, the base's. `CPeaceAction::Clone` (`0xA41CE0`, rva `0x641CE0`)
allocates 0x28 and copies the base fields only, the source's `date` into both `date` and
`last_command_date`. `CPeaceAction::CPeaceAction` (`0xA3F430`, rva `0x63F430`) writes only the base -
type 0, value 1, both dates now - and its one caller is the luabind `__init` at `0x98A210`, so Lua's
`CPeaceAction(actor, recipient)` exists. **No script of the base game or of Their Finest Hour calls
it**: a grep of `script/` and `tfh/script/` finds nothing, where `CAllianceAction` is found in
`ai_foreign_minister.lua` (the positive control); the foreign minister's `ForeignMinister_HandlePeace`
is about agreements in peacetime. The screen's row is `CDiplomaticAction::Create` with token `0x729`
`peace_action` (`CPeaceAction::GetToken`, slot 15). **So only a person offers peace**, and a war
between AIs ends only by capitulation, annexation or script.

### C.3 Who may offer it (slots 13, 14, 11)

**Slot 13 `IsValid`**: the actor's status toward the recipient has a war.

**Slot 14 `IsSelectable`** (`0xA41370`, rva `0x641370`) is false where actor == recipient,
`HasDiplomatEnroute(actor, recipient)`, both are in real factions, or they are not at war. Then, for
each party X in turn (actor, then recipient), Y the other, A the attacker count and D the defender
count:

- **X in a real faction, not its faction leader (first member), on a side of two or more** (an
  attacker with A > 1, a defender with D > 1): false where X's faction leader has a war with Y (an
  empty faction's leader is the null tag `---`), and false where X is not the first country of its
  side (`attackers[0]` or `defenders[0]`);
- **X in no real faction**: false where X is not the first of its side.

So a faction leader may negotiate from anywhere on its side, a faction member alone on its side may
too, and a country in no faction must lead its side.

**Slot 11** (`0xA40AA0`, rva `0x640AA0`, the row's tooltip) makes the same tests in the same order and
shows the first that holds: `ACT_NO_SELF` "You cannot negotiate with yourself.", `ENROUTE` "We have a
diplomat enroute, and he will arrive on $DATE$", `PEACE_FACTION` "You are both in factions, and
factions fight until they surrender", `PEACE_NOT_LEADER` "You can only negotiate with the leader of
your enemy"; otherwise `PEACEDESC` "Offer peace with minimal border adjustments." It does not test for
a null war.

### C.4 The player's own dialog

`FINDINGS-agreements.md` B.2 is confirmed: Peace opens the standard dialog. Title `PEACETITLE`
"Peace"; slot 18 is ReturnTrue, so the dialog shows a `DIPCHANCE` word from `GetAIAcceptance`; the
description is slot 12, `CPeaceAction::GetDialogText` (`0xA416A0`, rva `0x6416A0`): `PEACENEWDESC`
"Do you wish to request peace with $COUNTRY$. $SELF$?\nIf they accept, the war will end. $RESULT$",
COUNTRY the recipient's name, SELF `PEACENEWALLY` "They are negotiating for their allies." where the
recipient is `attackers[0]` or `defenders[0]` and otherwise `PEACESELF` "They are negotiating for
themselves.", RESULT as C.5. **Nothing is chosen: the player is shown the result and cannot set
terms.**

### C.5 What changes hands: the transfer rule and the result text

**`CCountry_ListPeaceTransfers(C, party)`** (`0x5038A0`, rva `0x1038A0`) decides it for one country
C, `party` being the negotiator on the other side and E the side of the war C is not on. It walks C's
owned provinces in list order, skipping any C controls itself. For each core holder X of the province,
in core-list order, it skips X == C and takes X only where X is `party` or a member of E; then:

- **the controller is `party`**: the new owner is `party`;
- **the controller is another member of E**: the new owner is **the first qualifying core holder**,
  who need not be the occupier;
- **the controller is anyone else** (an ally, a neutral): nothing.

The answer goes to the province's scratch field `peace_new_owner` (`+0x33C`). One province can be
listed more than once, always with the same owner.

**`CollectPeaceTransfers`** (`0xA3F530`, rva `0x63F530`) runs that over one side: the defenders against
A, the party on the attacking side, and the attackers against D, the party on the defending side. A is
the actor unless the actor is among the defenders, when A and D swap.

**`CPeaceAction_BuildResultText`** (`0xA41E30`, rva `0x641E30`) is $RESULT$ in both dialogs. With both
lists empty, `PEACENEWWITHE` "All territory will revert to its prewar owner." Otherwise the attackers'
losses first, then the defenders': for each new owner (in the order first met), for each losing
country (in side order), one line - `PEACENEWPROVUS` "§Y$NATION$§W will cede §R" for the actor's own
side or `PEACENEWPROVTHEM` "...§G" for the other side, the provinces joined by `FormatProvinceList`
as "A, B and C" (`AND` "and "), then "§W " + `PEACETO` "to §Y$REC$§W" + "\n".

### C.6 The AI's answer, and what the rewrite must build for it

`GetAIAcceptance` (slot 17) calls the bridge as `GetDiploScoreFromLua("DiploScore_PeaceAction", actor,
recipient, recipient)`: the recipient's AI answers, and the observer is the recipient. The base game's
and Their Finest Hour's Lua are the same:

    intel = CAIIntel(recipient, actor)
    score = 0
    if intel:GetFactor() > 0.1:
        score = 100 * (intel:CalculateOurMilitaryStrength() / intel:CalculateTheirPercievedMilitaryStrengh() - 0.5)
    score += min((actor:GetNumberOfControlledProvinces() / recipient:GetNumberOfControlledProvinces() - 1) * 100, 100)
    score += recipient:GetSurrenderLevel():Get() * 100 - actor:GetSurrenderLevel():Get() * 100
    s = recipient:GetStrategy();  score += s:GetFriendliness(actor)/2 - s:GetAntagonism(actor)/2

The script's local names are swapped - "recipientStrength" is the actor's strength as the recipient
sees it, "actorStrength" the recipient's own - so **a recipient that thinks itself the stronger is the
readier to accept**. `AnswerPendingOffers` then applies its usual rule: 30 or less declined, otherwise
accepted on a draw under the score.

**What it reaches in the engine**: `CAIIntel(tag, tag)`, `GetFactor`,
`CalculateTheirPercievedMilitaryStrengh`, `CalculateOurMilitaryStrength`; `CCountryTag:GetCountry`;
`CCountry:GetNumberOfControlledProvinces`, `GetSurrenderLevel`, `GetStrategy`; `CFixedPoint:Get`;
`CAIStrategy:GetFriendliness`, `GetAntagonism`; `math.min`.

**`CAIIntel(us, them)`** (`0x89F240`, rva `0x49F240`; Lua's first argument goes to `+0`, the second to
`+4`):

- **Factor** = `(float)(CSpyPresence_GetIntelFactor / 1000.0)`, the intel factor being
  `us->espionage[them].level * 1000 / MAX_SPY_LEVEL (10000) - them's COUNTER_INTELLIGENCE`, in
  thousandths - ten spies and no counter-intelligence give 1.0, and `GetFactor() > 0.1` needs more than
  one spy's worth;
- **UncertaintyFactor** = `clamp((float)(1 - Factor + 0.2), 0.2, 1.0)`.

**`CalculateOurMilitaryStrength`** (rva `0x49F8C0`): the sum of every regiment's strength (`+0x5C`) of
every unit of `us`, / 1000, as a float.

**`CalculateTheirPercievedMilitaryStrengh`** (rva `0x49F4B0`), all in thousandths:

1. bonus = `SPY_INTEL_MISSION_BONUS` (0.5) x `us->espionage[them].mission_share[1]` (the military
   mission) / 1000;
2. f = floor(((float)(bonus/1000 + Factor) + 0.0005) x 1000);
3. chance% = trunc(trunc(f x trunc(100000 x `SPY_UNIT_DETECTION_CHANCE` (0.5) / 1000) / 1000) / 1000) -
   50 at Factor 1;
4. land% = trunc(100 x us's `OFFMAP_LAND_INTEL` / 1000), and sea% likewise with `OFFMAP_NAVAL_INTEL`;
5. for each unit of `them`, in list order: **one draw of the game's generator** (state `+0x124`,
   `MT19937Next`) first; the unit is seen where `us`'s intelligence of its province is at least 2, or
   where `draw % 100 < (land% or sea%) + chance%` - the draw never negative (`FINDINGS-surrender.md` E,
   which corrects "signed" here); its strength goes to *seen* or *hidden*;
6. the answer = (seen + max(hidden + trunc(k x scale / 1000), 0)) / 1000 as a float - scale exactly in
   `FINDINGS-surrender.md` E, about hidden x (1+U) - where k =
   floor(((u - 0.5) x U + 0.0005) x 1000) and u is one more draw, through `RandomPerturbAtLeast`
   (`0x62D940`): `(draw & 0x7FFFFFFF) x 2^-31`.

So **the AI's answer takes (the actor's units + 1) draws of the game's own generator** whenever Factor
is above 0.1.

### C.7 An offer to the player: `CAskPeace` (`0x618320`, rva `0x218320`)

`CPeaceAction::AskPlayer` makes it for a PROPOSE with `value` set, as icon kind 1, its tooltip
`ICON_PEACE`, which has no text and shows the key. The window is `eu3dialog.gui`'s `DefaultDialog`:
LeftShield the actor's flag, RightShield the recipient's; title `PEACETITLE` "Peace"; description
`PEACEREQDESC` "$COUNTRY$ is requesting an end to hostilities. If we accept, the war will end.\n$RESULT$\nDo
you wish to accept their offer?", COUNTRY the proposer, FACTION filled with the player's faction's name
and never used, RESULT from C.5 coloured from the proposer's side; buttons `ACCEPT` "Accept" and
`DECLINE` "Decline". Where the title's and the description's heights sum to more than 400 the window
grows by (sum - 170) and both buttons move down as much. The icon lapses after 7 days unopened, an
opened dialog after 2 months or as soon as the pair are no longer at war
(`CDiplomacyDialog::IsStillOpen`). With the AI never offering peace, it appears only for another
player's offer.

### C.8 `CPeaceAction::Apply` (`0xA3F710`, rva `0x63F710`), in order

Every arm first builds the message variables: the local player's standard set, then ACTOR and
RECIPIENT as names.

**ACCEPT (type 2):**

1. war = `actor->diplomacy[recipient]->war`; none, return.
2. A and D as in C.5.
3. The transfers, the defenders' list first, then the attackers': each province
   `CMapProvince::ChangeOwner(province, peace_new_owner, now, applyConsequences 1, rebuildAreas 0,
   peaceful 0)`.
4. The attackers and the defenders copied, in side order.
5. **For the first attacker only**, and each defender, `CCountry_ReturnOccupiedProvincesTo` both ways:
   every province X controls that Y owns gets `Province_SetController(..., Y, now, 1, 0, 0)`, then the
   area and supply groups are rebuilt. The defender-list iterator is never reset after the first
   attacker, so the other attackers are not paired.
6. The removals, all with recordHistory 1: where **both sides have two or more**, every defender
   (`RemoveDefender`) and then every attacker (`RemoveAttacker`); **otherwise** the lone attacker if
   there is exactly one and the lone defender if there is exactly one. Either way every
   attacker-defender pair loses its war.
7. For each attacker of the copy (defenders are not visited): `CCountry::OnDiplomacyChanged`,
   `CAIStrategy::Rebuild`, `CAIStrategy::BuildTheatres(1)`.
8. Where the local player is the actor, or is still in `war->attackers` after the removals: the
   `diplomaticsuccess` sound and `PEACEACCEPT`, placed at the recipient's acting capital.

**DECLINE (type 1):** only where the actor is the local player, the `diplomaticfailure` sound and
`PEACEDECLINE` at the recipient's capital. Nothing else - no relation, no cost.

**PROPOSE (type 0):** nothing beyond the generic `Execute`, which sets the seven-day
`next_offer_allowed`.

**What a peace leaves alone**: **war goals** are not enforced - `CWar::RemoveWarGoalsOf` deletes every
goal of a leaver and every goal against it - which confirms `FINDINGS-diplostate.md`'s "only a
surrender enforces war goals"; the **casus belli** between the two are kept; **relation, threat,
neutrality and influence** do not move; **war exhaustion** is paid back at the next monthly update
once `at_war` is clear (`FINDINGS-diplostate.md` C.3); and `UpdateAtWarAndEnemies` takes
`initial_mobilization` off a country that leaves its last war, unless a person plays it.

### C.9 Leaving a war: `CWar::RemoveAttacker` / `RemoveDefender`

`void __stdcall (CWar* war, bool recordHistory, char tag[4], int id)`, `ret 0x10` (brief A records
them; read whole here too). In order: the tag is erased from its side;
`ClearWarSideCoBelligerentFlags` against the members who remain; `CWar::RemoveWarGoalsOf`; with the
flag set a `CRemoveAttackerChange` or `CRemoveDefenderChange` {war, tag, date now} is filed in
`war->history (+0x4C)`; then for each member of the other side, `SetPairWar(null)` both ways (which
also ends their influence and trade routes), `UpdateAtWarAndEnemies` on both, and observer channel
0x14 told (leaver, other). `RemoveDefender` logs "Illegal RemoveDefender: X is not at war with Y in
<war>" where the pair's war is not this one, and clears it anyway; `RemoveAttacker` has no such check.

### C.10 Occupied land after a peace

At the peace provinces move by C.5, and control comes back at once between the first attacker and
each defender (C.8 step 5). Everything else is returned the next day by `RunDailyProvincePass`
(`0x49F144`-`0x49F1C5`): any province whose controller is not at war with its owner, except where the
owner is a government in exile or REB is either party.

### C.11 The truce, corrected

`HasTruce` = not at war, and `last_war <= now < last_war + 2400 h`; the 2400 is hard-coded.

**`last_war` (`+0x54`) is written only by `CCountry::UpdateAtWarAndEnemies`**, for the pairs still at
war when it runs, and its nine callers are `CInGameIdler::Enter` (a session coming up) and the four
add/remove functions - none of them hourly. The evidence: `findRefs` gives the nine callers and no
other reference in code or data; a store sweep over every chunk mentioning `0xE28` finds no other
writer but a new-game reset, `ReleaseProvinces` and one site in `CDeclareWarAction::Apply`'s chunk
(the positive control finds the known write at `0x4E6C32`); and the saves have ITA->ETH
`last_war="1936.1.1.0"` on 1 January, 8 January, 1 February and 1 March 1936, the war going on. A
peace clears the war before the update runs, so **the truce is 100 days from the last load or the last
change of membership in a war between the pair, and a long unchanged war leaves no truce at all.**
`FINDINGS-triggerleaves.md` 2.6 ("refreshed every hour of a war") is corrected by this.

The casus belli type's `truce_months` (`+0x1D0`, default 60; B.3) has no reader either: the truce is
the hard-coded 2400 hours whatever the type. (Reader C took `+0x1F4` for `truce_months`, as
`FINDINGS-diploaction.md` section 27 had it; the loader's switch puts token `0x792` `truce_months` at
`+0x1D0` and `0x32A` `months` at `+0x1F4`, so C's "default 12, no reader" is `months`'s.)

### C.12 Who is told which key

| arm | who | key | where |
| --- | --- | --- | --- |
| accepted | the local player, if he is the actor or still among the war's attackers | `PEACEACCEPT` | the recipient's acting capital |
| declined | the local player, if he is the actor | `PEACEDECLINE` | the recipient's acting capital |

Both are popup, log and on the map, not pausepopup. `PEACEACCEPT`: `_HEADER` "$foreign_minister$
reports"; `_1`..`_5` "Peace!", "$MONARCHTITLE$", "§Y$RECIPIENT$§W", "have ACCEPTED", "an end to the
war with $ACTOR$."; `_LOG` "$RECIPIENT$ has accepted the peace offer from $ACTOR$."; `_MAP` "Peace!".
`PEACEDECLINE`: `_1`..`_6` "War Continues!", "$MONARCHTITLE$", "§Y$RECIPIENT$§W", "have DECLINED",
"our generous offer of peace.", "When we march into their last village, they will finally come to
their senses!"; `_LOG` "$RECIPIENT$ revoked our right to go into debt with them." (sic).
`PEACEACCEPT_CONT` and `_END` are not in the image (`findBytes`; `PEACENEWALLY` found as the positive
control). **No message marks a war's end**: `PostMessage_CWar`'s four callers are all in
`AddAttacker`/`AddDefender`, and `messagetypes.txt` has no war-ended type.

### C.13 A war's end

**Nothing removes a war in play.** `previous_war` (`+0xC20`) is appended only by the save loader
(`0x6800C3`) and the history replay (`0x5F5690`); `CWar`'s destructor runs only at
`CGameState::ResetSession`. A war whose side has emptied stays in `active_war` - the 20 April save has
"Second Italo-Abyssinian War" with ITA alone and no goals.

**`RemoveLandlessCountriesFromWars`** (`0x689EA0`) runs only as a session is entered: every country
owning no province and not in exile leaves every war (flag 0) and its faction.

**`CWar::SaveContents` writes no history** (nor `target`), so after a load `GetStartDate` is the null
date and `GetCurrentRunningTimeInMonths` 0.

### C.14 `CWarHistory`

**`CWarHistory::LoadEntry`** (`0x600250`, slot 9) is the grammar of `history/wars/*.txt`: `name`,
`limited_war`, and dated blocks of `add_attacker`, `rem_attacker`, `add_defender`, `rem_defender` and
`war_goal`. Each block becomes an entry whose slot 7 applies it forward or undoes it, with flag 0
(`CAddAttackerChange::Apply` and its three siblings). `CWar::GetStartDate` is the first dated entry
and `CWar_GetLastHistoryDate` the last, from which a new game counts war exhaustion for historical
wars; `CWar_DropFutureHistory` prunes the entries dated after the start, for wars put on `active_war`
at setup. In the base game the ITA-ETH war's history ends with a peace dated 1936.5.9
(`rem_attacker = ITA`, `rem_defender = ETH`).

### C.15 The casus belli's keys at a peace

`handles_peace` (`+0x1F3`) has one reader, `CWarGoal::Enforce` (`0x47A976`, D.4), which a peace never
calls. **`mutual` (`+0x1F1`) has none** - the file's header says it is "used by the defender in peace
treaties"; nothing reads it (a whole-image sweep of `[reg+0x1F1]` and `add reg, 0x1F1` finds the
loader and an unrelated GUI sorter; the same sweep finds `always`'s two known readers at `+0x1F2`, the
positive control). `truce_months` (`+0x1D0`): C.11 and B.3.

### C.16 What looks wrong and is what the bytes do

1. Only the first attacker hands control back to the defenders at the peace; the rest wait for the
   daily pass.
2. Returned provinces go through `SetController` with `peaceful` 0 while the war is still set, so
   (confirmed by `FINDINGS-surrender.md` D.6, which read the setter)
   buildings may take `COMBAT_PUSHBACK_DAMAGE` (1.0, a 50% chance) as if retaken - inferred from the
   setter's record.
3. A side of two or more facing a lone enemy stays in the `CWar` for good, and `PEACEACCEPT` then
   reaches that side's player though he took no part.
4. A province can go to a core holder who never occupied it.
5. `PEACESELF` "negotiating for themselves" is shown, and the whole war ends either way.
6. In `CAskPeace` the RESULT colours are the proposer's - the player's own losses in green - and
   FACTION is filled and never shown.
7. **Corrected by `FINDINGS-surrender.md` E: the draw is never negative**, so the remainder is 0 to 99. Was:
   The sighting roll takes the generator's draw as signed, so about half of all units are seen
   whatever the odds; the AI's answer, and the dialog's chance word, take draws of the game's
   generator.
8. The Lua's strength names are swapped; the stronger recipient accepts the readier.
9. `PEACEDECLINE_LOG`'s English is about debt.
10. `GetDescription` does not test for a null war.

### C.17 Not settled

- What `0x5FA7E0`'s object, which every war-history entry is handed at `+0x34`, is for.
- Settled by `FINDINGS-surrender.md` D.3: a repeated `ChangeOwner` to the same owner resets nationalism and
  wipes the province's modifiers again, and is otherwise harmless. Was:
- Whether `ChangeOwner` twice with the same owner (a duplicated transfer) is harmless; `0x4A2180` was
  not read.
- The tail of `FormatProvinceList`.
- Whether `BuildChanceText` asks slot 17 once or every frame - it draws on the generator each time.
- `months` (`+0x1F4`): the 350 `[reg+0x1F4]` sites in the image were not triaged one by one, so its
  negative covers the war, peace and casus belli code only (B.3 reaches the same negative by its own
  sweep).
- The war's `action` date (`CWar +0xC`): it moved to 1936.3.4.2 at Ethiopia's capitulation; no writer
  was found in the add/remove functions.

### C.18 Frontier (rvas)

`0x1F5450` (the history replay of wars), `0x283EE0` (a war name already used), `0x1FA7E0`,
`0x64D920` (`~CWar`), `0x94700` (`CProvince`'s constructor), `0x21D498`/`0x226154`/`0x227A17` (the
other `RandomPerturbAtLeast` callers), `0xA2180` (the owner setter).

## D. The capitulation (brief D)

Fragment `fragments/merged/capitulation.json`.

### D.1 In one line

- **A country surrenders once the occupied share of its owned cores' victory points reaches its
  national unity** - at 70% unity, 70% occupied. A government in exile never surrenders.
- **The capitulation enforces every enemy's war goals against it from the war with the victor**, in
  `peace_order` with the victor's own goals first among equals, and **annexing goals always last**.
  With no goal enforceable, a `conquer` goal is made up and enforced.
- **Whether the country leaves the war depends on the goals.** If every enforced goal made peace it
  leaves, and its vassals are released or puppeted to the victor. If any goal "handles peace", or the
  country went into exile, it stays in the war and every goal by it or against it is deleted.
- **Each enforced goal annexes or makes an exile, takes a region, takes provinces, puppets** - in that
  fixed order - then spreads its threat, runs `on_completion` and tells the player.

### D.2 Surrender progress - `CCountry::GetSurrenderProgress` (`0x4FCB80`, rva `0xFCB80`)

The game's Lua calls it `GetSurrenderLevel`. It answers 0 to 1000, and **1000 means on the brink**.

    if government_in_exile (+0x95)            -> 0
    if controls no province (+0xD08 == 0)     -> 1000
    u = national_unity * 1000 / 100000         ; unity in thousandths, so u = unity/100, 10..1000; truncated
    if u == 0                                  -> 1000
    -> clamp(occ * 1000 / u, 0, 1000)          ; truncated (64-bit __allmul/__alldiv)

`occ` is `CCountry::GetOccupiedVictoryPointShare` (`0x4FCC60`):

    owned = sum of VP*1000 over the cores (CoreProvinces +0xD10) the country owns       (+0xBE0)
    held  = sum of VP*1000 over those same cores it also controls                       (+0xBE4)
    occ   = owned <= 0 ? 0 : 1000 - clamp(held*1000/owned, 0, 1000)

The two sums are rebuilt daily by `CCountry::RebuildNeighbours` (`0x4E3030`-`0x4E307E`). **The
controller test is nested inside the owner test**, so a core owned by someone else counts in neither
sum and `held` never exceeds `owned` - which corrects `FINDINGS-negatives.md`, whose account had two
independent tests.

**The threshold.** `progress >= 1000` holds exactly when `occ >= u`: the occupied share of the owned
cores' victory points, in tenths of a percent, is at least national unity in tenths of a percent.

**The surrender level is the constant 1000.** `RunCountryDailyPass` compares the answer with `0x3E8`
at `0x4DBCE3` and with nothing else; laws and modifiers reach it only through national unity.

**The daily gate** (`FINDINGS-onactions.md` 2.2): the country owns a province, progress is at least
1000, `at_war` is set, and 30 days or more have passed since `last_surrender`. Then the victor is
scored, `on_surrender` fires, and `CCountry_Capitulate` runs.

**Odd arms.** A country owning no core answers 0 however much it has lost; one that owns land but
controls none answers 1000.

**Savegames.** None keeps the progress. Each country carries only `last_surrender` (`"1.1.1.0"`,
never, in all 101 countries of the latest autosave), so nothing here is checkable against a save.

### D.3 The capitulation - `CCountry_Capitulate` (`0x4E9220`, rva `0xE9220`)

`void __stdcall (CCountry* country, CCountryTag* victor)`, called from `0x4E9182` only. Its two
`ret 8` are in one frame: the second, `0x4EA082`, is the early exit at `0x4EA055`/`0x4EA062`, reached
by jumps from `0x4E9286`, `0x4E92C7` and `0x4E92DE` - the trap 3 the record owed, settled.

1. **The war** is the victor's status toward the country, its `war`. With none, nothing happens.
2. **The goals.** A defender has every attacker's goals collected (`CWar::CollectAttackerGoals`, in
   attacker order, each attacker's whole vector); an attacker every defender's
   (`CollectDefenderGoals`). Neither: nothing happens.
3. **The sort** (`SortWarGoalsByPeaceOrder`, `std::sort`, not stable): goal `a` before `b` when both
   have a type and a's rank (`CCasusBelliType +0x10`) is lower, or the ranks are equal and a's actor
   is the victor and b's is not.
4. **Pass 1**, over the goals whose type has no `po_annex` and whose recipient is the surrendering
   country - goals against its allies are ignored:
   - each must pass the gate `0x47BF70`, called with no war: the type is real, the recipient owns a
     province, and the type's `allowed_countries` and `allowed_regions` hold;
   - one that passes is counted and `Enforce` runs;
   - `Enforce` true: the goal's actor joins list A ("made peace") unless already on A or B;
   - `Enforce` false: the actor joins list B ("fights on") and is taken off A.
5. **Pass 2**, the same over the goals that do have `po_annex`. **Annexation is always enforced
   last**, whatever its `peace_order` rank.
6. **No goal passed the gate:** a `conquer` goal is built - actor the victor, recipient the country,
   no region, the type looked up by name (type 0 if absent) - and enforced **without the gate and
   without `is_valid`**. In Their Finest Hour conquer's `is_valid` would refuse a government in exile
   and a country with a puppet casus belli; neither is asked. The victor joins A or B as above.
7. **B is empty:** the country leaves the war (`CWar::RemoveAttacker`/`RemoveDefender`, flag 0;
   leaving also deletes its goals and the goals against it). Then each of its vassals in the war, from
   a copy of `Vassals`:
   - **if any goal in the war names the vassal as recipient** (`CWar::IsWarGoalRecipient`), it is
     **released**: the alliance and the dependency between it and its overlord are deactivated,
     unlinked from the relation list and deleted; military access is cleared both ways, the guarantee
     pointers nulled both ways (the `CGuarantee` is not deleted), `allowDebts` cleared both ways. **It
     stays in the war.** No message;
   - **otherwise** a `puppet` goal (victor -> vassal) is built with `CWarGoal_Make` and enforced if the
     type is real, with no gate and no `is_valid` - Their Finest Hour's `is_subject = no` would have
     refused it: `MakeVassal`, threat 5 and the message. The vassal then leaves the war;
   - every vassal, in the war or not, gets `CCountry_RefreshDiplomacy` and `OnDiplomacyChanged`.
8. **B is not empty:** the country stays in the war. `CWar::RemoveWarGoalsOf(war, country)` deletes
   its goals and every goal against it, the same is done for each vassal, which is then refreshed.
9. **Refreshes:** every country on A, then the country itself.
10. **Occupied land goes back.** Each province the country controls but does not own is returned to
    its owner (`Province_SetController(p, owner, now, 1, 0, 0)`) when the owner is no longer at war
    with it, or the owner is a government in exile whose war with it is this one.
11. **Rebuilds.** If step 7 released a vassal or step 10 moved a province, the area groups and supply
    groups are deleted and rebuilt.
12. **In a running game** the in-game screen's `+0x84 |= 0xF`, and -1 is queued for a refresh.

The country's units, capital, faction and relations are not touched here directly; they change only
inside `Enforce`'s callees - `AnnexCountry`, `SetGovernmentInExile`, `MakeVassal`, all still
`inferred` from the decompiler (`FINDINGS-effectrun.md` 2.7, 2.8, 2.12). In outline: **annexation**
gives each province to whoever occupies it, otherwise to the annexer, removes every remaining unit,
takes the annexed out of its faction and every war, drops threat both ways to 0, and sends `ANNEX`
("$ACTOR$ annexed $RECIPIENT$."); **exile** cuts manpower and officers to a tenth, removes units on
unfriendly ground and moves the acting capital toward the faction leader's; **a puppet** has relation
set to +200, leaves every war and takes the overlord's government.

### D.4 A war goal enforced - `CWarGoal::Enforce` (`0x47A950`, rva `0x7A950`)

Reached only by the capitulation's four direct calls (`0x4E9378`, `0x4E94CC`, `0x4E9727`,
`0x4E9C75`); no table or data reference holds it.

The answer starts as **`!handles_peace`** (type `+0x1F3`). The actor's acting capital is taken on
entry. The type's peace options (`+0x1E0`, a list of the tokens the six `po_*` keys load) are then
looked for in a fixed order, **not the file's**:

1. **`po_annex`** (token `0x79C`):
   - **the host**: the first member of the recipient's real faction that is not the recipient, not
     `REB`, is major or has max IC above 100, owns a province and is not in exile;
   - **the roll**: `Random() % 100 < 80`, **drawn every time**, host or none. Where it fails the
     recipient still qualifies when it is a subject whose overlord owns a province, or when it is
     **Belgium or the Netherlands** (tags cached at `CCountryDataBase +0x88`/`+0x98`);
   - **a host and a qualifying recipient: a government in exile.** If the actor is real it takes
     control (not ownership) of every province the recipient controls on the continent of the
     actor's *capital*, or whose area borders ground the actor controls; the area and supply groups
     are rebuilt; then `SetGovernmentInExile(recipient, true)`. **The answer becomes false**, so the
     victor goes on list B and the exile stays in the war with every goal by or against it deleted;
   - **otherwise annexation**: `AnnexCountry(actor, false, recipient)` - `inherit`'s mode. The
     surrender mode's candidate controllers and halved unit hand-overs **never happen in a
     capitulation**; only the `surrender_inherit` effect and a console command at `0x440522` use
     them. With no host and a real faction, every government in exile among its members is annexed
     by the actor too.
2. **`po_demand_region`** (`0x798`), from the goal's region (`+0x28`). With none it logs "CB error:
   po_demand_region has no specified region for CB type ..."; otherwise every province of the region
   the recipient owns changes owner to the actor (`ChangeOwner(p, actor, now, 1, 0, 0)`), in the
   region's order.
3. **`po_demand_provinces`** (`0x7AB`): each province the recipient owns, in `OwnedProvinces` order,
   for which `allowed_province` (`+0x130`) holds - scope the recipient, THIS the actor, the province -
   is collected, then each changes owner to the actor.
4. **`po_puppet`** (`0x7AF`): `MakeVassal(actor, recipient)`.
5. **Threat**: where the type's `threat` (`+0x1C0`) is above 0, `SpreadThreat(actor, &threat, &1000,
   the acting capital taken on entry)` - conquer 5, puppet 5, vichy 10, barbarossa 20 in Their
   Finest Hour.
6. **`on_completion`** (`+0x270`), where it has children (`+0x280` is its child count), run with the
   country the recipient, FROM the actor and THIS the actor.
7. **The message**, every time, to the local player: the player's country's variables plus `AGRESSOR`
   (the actor's name), `TARGET` (the recipient's) and `WARGOAL` (the type's localised name); the
   recipient's tag fills the message's country; posted through `PostMessage_CInGameIdler`. All three
   types are log, popup, not on the map, `cat_diplomacy`:

| when | key | what it says |
| --- | --- | --- |
| the player is the recipient | `WESURRENDER` (pausepopup) | "$foreign_minister$ reports / $AGRESSOR$ enforced / $WARGOAL$ / on us"; log "We surrendered to $AGRESSOR$" |
| the player is the actor | `THEYSURRENDERUS` | "We enforced / $WARGOAL$ / on $TARGET$"; log "$TARGET$ surrendered to us" |
| anyone else | `THEYSURRENDER` | "$AGRESSOR$ enforced / $WARGOAL$ / on $TARGET$"; log "$TARGET$ surrendered" |

All three show "Surrender!" on the map.

**`po_install_government` (`0x799`) and `po_change_government` (`0x79A`) do nothing.** Every 32-bit
immediate of either value in `.text` was decoded - 3 and 6 hits, none a comparison against a
peace-option node; the positive control is that the same scan finds all four of `Enforce`'s and both
of the capitulation's comparisons against `0x79C`. A jump table keyed on the token would escape it.
Their Finest Hour's `install_democracy` and `install_communism` do their work in `on_completion`
(`coup_by = FROM`, relation +200, leaving factions).

**`peace_order`.** `LoadCasusBelliTypes` reads the block with `ParseStringListBlock` (`0x416C0F`);
after loading, each type's 0-based place in that list is written to `CCasusBelliType +0x10`
(`0x416DE0`). A real type the list leaves out logs "Could not find peace execution order for casus
belli: " and keeps rank 0, the same as `civil_war`. Their Finest Hour's list names two commented-out
types, which match nothing.

**Worked example (start-date save).** Italy holds a `puppet` goal on Ethiopia. Were Ethiopia to
surrender to Italy: the goal passes the gate, `MakeVassal(ITA, ETH)`, Italy spreads threat 5, the
player is told `THEYSURRENDER`; puppet is not `handles_peace`, so Ethiopia leaves the war and the
occupied land goes back to its owners as in D.3.

### D.5 The nearest candidate - `COwnerArea_DistanceToProvince` (`0x47E590`, rva `0x7E590`)

`FINDINGS-effectrun.md`'s "`0x47E590`" was a **VA**; the rva is `0x7E590`. Area in EAX, province in
ECX; it answers the smallest `CMap::DistanceBetweenProvinces` from the province to any province of
the area (the map's distance, four times the straight line), starting from 1,000,000. Its one caller
is `AnnexCountry`'s surrender arm (`0x4E8523`): where neighbouring areas of a province are held by
several candidates the nearest takes control, a strictly nearer one replacing, so of equals the first
in the area's neighbour list wins. **The capitulation does not reach it.**

### D.6 What looks wrong and is what the bytes do

1. Annexing goals run after all others, whatever their `peace_order` rank.
2. Every enemy's goals on the surrendering country are enforced, not only the victor's, each actor
   taking its own spoils.
3. The fallback `conquer` and the vassals' `puppet` goals skip both the gate and the type's
   `is_valid`.
4. The 80% roll is drawn even with no host, so it moves the game's generator every time.
5. Belgium and the Netherlands are hard-coded to go into exile.
6. A subject whose overlord still owns land goes into exile rather than being annexed, given a host.
7. Where the annexed country had no host, every other government in exile in its faction is annexed
   with it.
8. A vassal named by any goal in the war is released and **stays in the war**; one that is not is
   puppeted to the victor, `is_subject = no` notwithstanding.
9. `handles_peace` goals (vichy, barbarossa, china) still run every peace option, the threat and
   `on_completion`, yet the country stays at war.
10. `po_install_government` and `po_change_government` do nothing in the engine.
11. A type missing from `peace_order` ranks with `civil_war`, first.
12. A government in exile's progress is always 0, so it is out of the 30-day surrender cycle for good.
13. A country owning land but controlling none sits at 1000; one owning no core at 0.
14. The player is told once per enforced goal, of capitulations anywhere in the world.

### D.7 Not settled

- `0x47BF70`'s exact scopes for `allowed_countries` and `allowed_regions` (brief A's function; read
  here only for its gates).
- What `CCasusBelliType::GetLocalisedName` returns for `$WARGOAL$`.
- Whether the message's country slot changes who is shown it.
- `0xE39C0` (the refresh), `0x481CC0` and `0x481D70` (the group rebuilds).
- `AnnexCountry`, `SetGovernmentInExile` and `MakeVassal` stay `inferred`; `AnnexCountry` was checked
  only for its candidate-controller arm and the bool `Enforce` passes it.
- The seven unread callers of `GetSurrenderProgress` (`0x5003C5`, `0x77E99B`, `0x7851A1`,
  `0x893F67`, `0x896540`, `0x8B45AA`, `0x8B8AD9`).
- No savegame holds a capitulation, so none of this is checked against one.

### D.8 Frontier (rvas)

`0x7BF70` (the gate; brief A), `0x113B30`, `0x114A40`, `0x114AF0`, `0x115750` (the sort's partition,
heap and shift), `0x652D00`, `0x654480`, `0x652750`, `0x646550`, `0x6543A0`, `0x5BE9B0` (vector and
map helpers), `0x7C280`, `0xE39C0`, `0x81930`, `0x81980`, `0x81CC0`, `0x81D70`, `0x279590`,
`0x10E950`, `0x5F300`, `0x32F70`, `0x2F070`, `0x709E20`, and the console annex command near
`0x440522`.

**Traps met**: trap 2 at `0x4798DD`/`0x4798E0`, a `ret 0x2C` running straight into
`CWarGoal_CopyInto` with no padding; trap 3, the capitulation's second `ret 8`, settled above; trap 1,
`findRefs --callers` given rvas answers 0 and wants VAs; trap 14, `FINDINGS-negatives.md`'s two
independent tests for `+0xBE0`/`+0xBE4` are nested on the bytes.
