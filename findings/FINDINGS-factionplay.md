# Factions in play: joining, leaving, and what a faction is worth

Read 2026-10-13 by the faction wave (`WAVE.md`), for OpenHOI3, whose diplomacy ends with factions. Three
briefs: **A**, joining a faction and inviting to one; **B**, leaving a faction and what a member gets;
**C**, a faction's progress and the victory conditions. It builds on `FINDINGS-faction.md`, which has
`CFaction::AddCountry`, its war sweep and the rest of the membership change, and does not redo it.
Addresses are virtual (based 0x400000), with the rva beside named functions.

---

## A. Joining a faction and inviting to one

Read by brief A, on the listing. It builds on `FINDINGS-agreements.md` A, which has how an offer is
answered, and says only what differs from the other actions. The collecting session checked the three
corrections to `Apply` on the bytes: the direction branch at `0xA30E9D`, the war walk taken only where the
joiner is at war (`0xA30EBB`), the `type == 2` test before the charge (`0xA314A7`), and the alliance loop
(`0xA31B30`-`0xA31C1F`).

### A.1 In one line

**One class, `CFactionAction`, serves both directions, and `value` says which.**
- Value 1 is **Join Faction**: the actor asks to join the recipient's faction.
- Value 0 is **Invite to Faction**: the actor asks the recipient to join the actor's faction.

The country that moves is the **joiner** (the actor for a join, the recipient for an invite). The other
country is the **owner**, whose faction is joined.

What happens, in order:
1. A proposal costs nothing and does nothing.
2. The recipient's AI scores it with `DiploScore_InviteToFaction` and answers with the usual roll. A player
   recipient gets the `CAskFaction` dialog instead.
3. On acceptance, the actor pays the faction influence cost (0 in Their Finest Hour).
4. The joiner enters the owner's faction, together with its ongoing wars.
5. Every country whose overlord is the joiner follows it in.
6. The joiner's bilateral alliances with every member are ended.
7. One message is raised, chosen by who the player is.

### A.2 The object

`CFactionAction` is 0x28 bytes (`Clone`, `0xA347F0`, rva `0x6347F0`, allocates 0x28). It is the
`CDiplomaticAction` header and nothing more:

| offset | field |
| --- | --- |
| +8 / +0xC | actor (tag, id) |
| +0x10 / +0x14 | recipient (tag, id) |
| +0x18 | type: 0 PROPOSE, 1 DECLINE, 2 ACCEPT |
| +0x1C | date |
| +0x24 | `value` |

There is no extra field.

**Who makes one:**
- **The diplomacy screen.** `CCountry::GetDiplomaticActionsToward` makes "Invite to Faction" (value 0) where
  the player leads a real faction and the recipient is in none. It makes "Join Faction" (value 1) where the
  player is in none and the recipient leads a real one (`FINDINGS-agreements.md` B.2).
- **Lua.** `CFactionAction(actor, recipient)` (`CFactionAction::Create`, `0x8E8E30`, rva `0x4E8E30`)
  defaults to **value 1, a join request**. The date is now; the type is PROPOSE.
- **The shipped AI only ever invites.** `tfh/script/ai_foreign_minister.lua` (around line 530):
  - A **major** that `HasFaction` builds the action, calls `SetValue(false)`, and checks `IsSelectable`.
  - It proposes where its own `DiploScore_InviteToFaction` score for the target is above 50.
  - A major that is a member but **not the leader** passes those Lua checks, but `IsValid` then fails in
    `CDiplomaticActionCommand::Execute`, so the command does nothing at all - not even the seven-day
    diplomat stamp is set. *Inferred* from the Lua and `IsValid`.

Key prefix (slot 20): `JOINFACTION` / `INVITEFACTION`. Titles: "Join Faction" / "Invite to Faction".
Token 1748 `faction_action` (slot 15, `0xA33F00`).

### A.3 `IsValid` (slot 13, `0xA33BF0`, rva `0x633BF0`)

Execute checks this on every peer before slot 7, and the player's dialog checks it every frame. It answers
false where:
- **either country is a government in exile** (+0x95); or
- **for a join:** the recipient's faction is not real (`CFaction` slot 7), or the recipient is not its first
  member, or the actor's own faction is real;
- **for an invite:** the actor's faction is not real, or the actor is not its first member, or the
  recipient's faction is real.

It answers true otherwise. "First member" is `GetFactionLeader` inlined; a real faction with no members
answers the `'---'` tag, whose id is 0.

It tests nothing about war, neutrality, distance or influence. **So none of those is re-checked when the
offer is accepted**, except the war test inside `Apply` (A.6).

### A.4 `IsSelectable` (slot 14, `0xA33CD0`, rva `0x633CD0`): what greys the row

The row is greyed on the first of these that holds:

1. Actor id equals recipient id.
2. `CCountry::HasDiplomatEnroute(actor, recipient)`: within seven days of any proposal to them.
3. The **recipient** is a subject (`isSubject` +0xF34). The actor's own subject status is not tested.
4. Influence is below the cost. Influence is `diplo_influence` (+0xA88), or 100.000 while
   `g_UnlimitedDiploInfluence` is set. The cost is JOIN_FACTION_INFLUENCE_COST (diplomacy +0x8C) for a join
   and INVITE_FACTION_INFLUENCE_COST (+0x90) for an invite; **both are 0 in Their Finest Hour.** Equal
   passes.
5. Neutrality, where equal passes:
   - **Join:** the actor's effective neutrality (+0xA90) is above JOIN_FACTION_NEUTRALITY (+0x94, **25**).
   - **Invite:** the recipient's effective neutrality is above INVITE_FACTION_NEUTRALITY (+0x98, **25**).
6. Distance, through `CAlignment::IsWithinFactionJoinDistance` (rva `0xC4CD0`):
   - **Join:** the actor's alignment (+0xDC) is not within reach of the recipient's faction.
   - **Invite:** the recipient's alignment is not within reach of the actor's faction.
   - "Within reach" is a straight-line distance on the triangle below FACTION_JOIN_DIST (**50**), strictly.
7. War:
   - **Join:** if the actor is at war (+0xACC), any member of the recipient's faction it is at war with greys
     the row. Then, if the recipient is at war, the same test is run against the members of the actor's
     faction; that list is empty for any join `IsValid` allows.
   - **Invite:** if the recipient is at war, any member of the actor's faction it is at war with greys the
     row.

Being at war with nobody skips the war test.

### A.5 The tooltip (`GetDescription`, slot 11, `0xA32FD0`, rva `0x632FD0`) and the dialog (slot 12)

The tooltip is the first of these that holds, in the same order as A.4:

| # | condition | key | text and variables |
| --- | --- | --- | --- |
| 1 | self | ACT_NO_SELF | "You cannot negotiate with yourself." |
| 2 | diplomat en route | ENROUTE | "We have a diplomat enroute, and he will arrive on $DATE$" (DATE is the actor's `next_offer_allowed` toward the recipient) |
| 3 | the recipient is a subject | DIP_THEY_PUPPET | "They are a puppet state of §Y$OVERLORD$§W" (OVERLORD is the recipient's overlord) |
| 4 | influence below the cost | DIP_NO_INFL | "You do not have the §Y$INF$§W diplomatic influence required"; INF is the cost with 0 decimals |
| 5 | join, actor's effective neutrality above +0x94 | DIP_TO_NEUTR_THREAT | "The difference between our neutrality and the highest threat against us is too high. This value is §Y$VAL$§W while it needs to be lower than §Y$LIM$§W"; VAL is the effective neutrality with 2 decimals; **LIM is INVITE_FACTION_NEUTRALITY**, trimmed |
| 6 | invite, recipient's effective neutrality above +0x98 | DIP_THEY_TO_NEUTR_THREAT | the same with "their"; **LIM is JOIN_FACTION_NEUTRALITY** (swapped; both 25) |
| 7 | join, distance fails | FACTION_DISTANCE | "Our alignment needs to be less than §Y$VAL$§W from the §Y$FACTION$§W. Our alignment towards them is currently §Y$VALC$§W." |
| 8 | invite, distance fails | FACTION_DISTANCE_2 | "Their alignment needs to be less than … Their alignment is currently …" |
| 9 | otherwise | JOINFACTIONDESC / INVITEFACTIONDESC | "Request to join their faction." / "Invite them to join our faction" |

For rows 7 and 8:
- VAL is FACTION_JOIN_DIST with 2 decimals, so "50.00".
- FACTION is the faction's localised name: the recipient's faction for a join, the actor's for an invite.
- VALC is worked out by `CAlignment_DistanceTo` (`0x4C4E20`, rva `0xC4E20`): the squared distance in
  thousandths, made single precision, divided by 1000.0, back to single, square-rooted. It is printed with
  `FormatFloat` to 2 decimals.

**There is no text for the war test.** A row greyed because of a war with a member shows the plain
description.

**The dialog body (slot 12, `GetDialogText`, `0xA33F10`, rva `0x633F10`):**
- **Join:** JOINFACTIONNEWDESC, "Do you wish to request being accepted into the $FACTION$?", where FACTION
  is the recipient's faction.
- **Invite:** INVITEFACTIONNEWDESC, "Do you wish to invite $COUNTRY$ to join the $FACTION$?", where COUNTRY
  is the recipient and FACTION is the actor's faction.
- Then a line break and DIP_INFLUENCECOST, "This will cost us §Y$COST$§W diplomatic influence points.", with
  COST to 2 decimals.

**COST is read from the alliance defines:** JOIN_ALLIANCE_INFLUENCE_COST (+0xC, **5.00**) for a join and
LEAVE_ALLIANCE_INFLUENCE_COST (+0x10, **1.00**) for an invite. The action actually charges the faction
costs, which are 0. The chance line under the body is the standard dialog's (`FINDINGS-agreements.md` B.5).
Slot 18 is `ReturnTrue`, so the chance line is always shown.

### A.6 `Apply` (slot 7, `0xA30E70`, rva `0x630E70`)

Execute runs it on every peer for every type: for the proposal, for the answer, and for a lapsed or
declined dialog.

**1. The one gate, whatever the type.** If the joiner is at war, it must not be at war with any member of
the owner's faction (`joiner->diplomacy[member]->war` must be null for each member). Any such war ends
`Apply` at once: no charge, no message, nothing. *This corrects `FINDINGS-diploaction.md`, which read
`value` as a gate and "at war" as a failure: `value` is the direction (`0xA30E9D`, 0 to the invite arm at
`0xA30F18`), and the joiner being at war is what runs the member walk (`0xA30EBB`).*

**2. Message variables:** the player's standard list, then `ACTOR` and `RECIPIENT` (names).

**3. PROPOSE: nothing else happens.**

**4. ACCEPT** (`type == 2`, `0xA314A7`):
1. **Charge.** The actor's `diplo_influence` loses JOIN_FACTION_INFLUENCE_COST (join) or
   INVITE_FACTION_INFLUENCE_COST (invite), floored at 0 (`0xA31545`-`0xA31553`). *The family rule that
   slot 7 charges on PROPOSE does not hold here.*
2. **Variables.** `JOINER` (the joiner's name), `FACTION` (the owner's faction's name), and `COMMENT`,
   whose value is the key `FACTIONCOMMENT_<faction tag>`:
   - `FACTIONCOMMENT_axis`: "Together we shall crush the Bolsheviks!"
   - `FACTIONCOMMENT_allies`: "The global alliance for freedom grows stronger!"
   - `FACTIONCOMMENT_comintern`: "The global revolution is one step closer!"
3. **The join.** `CFaction::AddCountry(owner's faction, joiner, recordInHistory 0, joinOngoingWars 1)` at
   VA `0xA319B2`. So the joiner is appended at the tail of the member list and enters every war of the
   faction leader that `FINDINGS-faction.md` §1.2 describes. **No `CFactionJoin` history entry is
   written.**
4. **The subjects follow.** For every country in the game state's country list, in id order, whose
   `overlord_id` (+0xF3C) equals the joiner's id: `AddCountry(owner's faction, that country, 0, 1)` at VA
   `0xA31AF5`. `isSubject` is not tested. A non-subject holds 0 there (`UpdateSubjectStatus`), which would
   match only a joiner of id 0 - REB's, going by file order (*inferred*).
5. **Alliances end.** For every member of the faction as it now stands (the joiner and its subjects
   included), where the **joiner's** status toward that member holds an alliance (+0x14): the alliance's
   slot 11 (`CAlliance::Deactivate`), then removal from the game state's relation list (+0xB2C,
   `0x5D49D0`) and deletion (`0xA31B30`-`0xA31C1F`). No message, no relation change. The subjects' own
   alliances with members are left to the daily pass, which ends an alliance inside one faction
   (`FINDINGS-agreements.md` C).
6. **One message,** chosen by the player:

| who the player is | key | location ("Go to") | text |
| --- | --- | --- | --- |
| the actor, on an invite | FACTIONINVITEACCEPT, sound `diplomaticsuccess` | the recipient's acting capital | "Pact Concluded!" / "$MONARCHTITLE$" / "$JOINER$" / "have accepted an invitation to join the" / "$FACTION$" / "$COMMENT$"; log "$JOINER$ accepted membership in the $FACTION$." |
| any member of the faction after the join, on a join (the requester, the leader who accepted, and any other member alike) | FACTIONJOINACCEPT, sound `diplomaticsuccess` | the recipient's acting capital | "…$RECIPIENT$ / have accepted us into the / $FACTION$ / $COMMENT$"; log "$RECIPIENT$ accepted our membership in the $FACTION$." |
| anyone else who is not the recipient | FACTIONJOINACCEPTOTHER | the actor's acting capital | "…$JOINER$ / have been accepted into the / $FACTION$ / We shall watch these developments carefully."; log "$JOINER$ joins $FACTION$." |
| the recipient (who has just pressed Accept) | nothing | | |

The "anyone else" row also covers the members of the inviting faction when the invite was not the player's
own.

**5. DECLINE:** only the actor is told, and only when the actor is the player.
- **Join refused:** FACTIONJOINDECLINCE, "Pact Refused!" / "$RECIPIENT$" / "have refused us entry into the"
  / "$FACTION$" / "$BAD_COMMENT$". FACTION is the recipient's faction. Log "$RECIPIENT$ refused our
  membership in the $FACTION$."
- **Invite refused:** FACTIONINVITEDECLINCE, "…$RECIPIENT$ / have foolishly declined entry into the /
  $FACTION$ / $COMMENT_BAD$". FACTION is the actor's faction.
- Both set `BAD_COMMENT` **and** `COMMENT_BAD` to `FACTIONCOMMENTBAD_<that faction's tag>`, because the two
  texts name the variable differently. For example, axis: "When the Bolsheviks kick down their door, they
  will regret this!"
- Location: the actor's acting capital. Sound: `diplomaticfailure`.

All five keys are `log=yes onmap=yes popup=yes`, `cat_diplomacy`, in both `interface/messagetypes.txt`
files.

**6. Last, for any type,** where `in_game` (+0xDA4) is set: `GameState_RequestIntelRefresh(-1)` and bit
0x100 on the in-game screen's +0x84. For an answer, Execute then rebuilds both countries' neighbours, which
is what puts the new members into `Allies` (`FINDINGS-faction.md` §4).

### A.7 The AI's answer (`GetAIAcceptance`, slot 17, `0xA34860`, rva `0x634860`)

Both directions ask **`DiploScore_InviteToFaction`** through `GetDiploScoreFromLua`. **A join swaps the two
tags**, so that Lua always receives (the faction's owner, the country that would join):

| direction | voActorTag | voRecipientTag | voObserverTag |
| --- | --- | --- | --- |
| invite | actor | recipient | recipient |
| join | recipient | actor | recipient |

The by-value tag is the action's recipient in both cases, so **the recipient's CEU3AI answers**. A join also
returns 100 where the recipient is the player and the `yesmen` cheat is set.

This matches the script. `tfh/script/ai_diplomacy.lua:100` reads the faction from its actor
(`ministerCountry:GetFaction()`) and judges its recipient as the target:
- 50 if the target is at war with someone the faction side also fights;
- plus `(100 − target's effective neutrality)² × 300 / 10000`;
- 0 for a small (total IC under 50) very neutral country (neutrality above 89) being asked into the Allies;
- for the same ideology group and a score above 40: +25 where the target's IC is above 50 or
  `IsLandSafeToJoin`, else −100;
- for a different ideology group: −80;
- then the joiner's country override (`Utils.CallGetScoreAI(voRecipientTag, …)`).

The engine uses the answer as for any action (`FINDINGS-agreements.md` A2): 30 or less declines, otherwise a
roll of the game state's generator below the score accepts.

### A.8 The player asked (`AskPlayer`, slot 19, `0xA34990`, and `CAskFaction`, `0x6107B0`, rva `0x2107B0`)

Both were already `confirmed` and were not re-read past what is cited here.
- Any PROPOSE becomes a `CAskFaction`, offer kind 8. `value` chooses only the text.
- **Invite to the player:** INVITEFACTIONREQDESC, "§Y$ACTOR$§W is inviting us to join the §Y$FACTION$§W.
  Accepting would mean we closely link the fate of our nation to their side. Do you wish to accept?"
  FACTION is the inviter's faction.
- **Request to the player's faction:** ASKFACTIONREQDESC, "§Y$ACTOR$§W is requesting to join the
  §Y$FACTION$§W. Allowing them to join would closely align them to us for a long time. Do you deem them
  worthy?" FACTION is the player's faction.
- The title is the action's own.
- `AgreeButton` "Accept" and `DeclineButton` "Decline" are `CDiplomacyDialog::Accept` / `Decline`. They set
  type 2 or 1 and post the command.
- The dialog uses the base `IsStillOpen`: it **declines itself** two months after the offer's date, or as
  soon as `IsValid` fails (for example, the inviter stops leading). An unopened icon declines after seven
  days.

### A.9 `CJoinFactionGoalAction`: what it is, and that nothing makes one

Token 1983 `join_with_war_goal`, prefix `JOIN_WARGOAL`, which has no localisation in either game. It derives
from `CWarGoalBaseAction` and is 0x5C bytes: a `CWarGoal` at +0x28, and `leader` at +0x54.

**It is a war-goal action, not a faction join:**
- Slot 7 is the body it shares with Add War Goal (`0xA435F0`). It adds the carried war goal to the
  actor–recipient war and spends the matching casus belli. Slot 7 has no type test, so this happens on the
  proposal (`FINDINGS-war.md`).
- Slot 13 is `CWarGoalBaseAction::IsValid` (`0xA43520`): `CWarGoal::IsValidForWar(goal, actor→recipient
  war)`.
- Slots 14 and 18 answer true; slot 19 is the empty stub, so a player is never asked.
- Slot 17 asks `DiploScore_JoinFactionGoal(ai, actor, recipient, observer = recipient, the war goal at
  +0x28)` through `GetJoinFactionGoalScoreFromLua` (`0xA44B60`, already recorded). The base script returns 0
  plus country overrides; Germany's returns 0 for AUS and FIN.

**`leader` is never read by the game.** The constructor sets it to the first member of the faction
literally named `'axis'`. It is saved and loaded as `leader` and copied by `Clone`, and nothing else touches
it.

**Nothing creates one in a game:**
- The constructor (`0xA43C40`, rva `0x643C40`) has one caller: `CDiplomaticAction::Create`'s token case.
- The class's vftable is written only there and in `Clone`.
- The only `0x7BF` immediate in the code is `GetToken` itself.
- Lua has no registration for the class.
- So an instance can come only from a save or a received command that already holds one. None of the 12
  saves on this machine contains `join_with_war_goal`; the same grep finds `trade_action` 8 times.

**For a reimplementation:** a vestige; reproduce nothing of it.

### A.10 What else puts a country into a faction during a game

Taken from `FINDINGS-faction.md` §10 and not redone; all 14 `AddCountry` call sites are joins.
- **The diplomatic action:** the joiner and its subjects (A.6).
- **`join_faction`:** `CJoinFactionEffect`.
- **A declaration of war:** the victim into the enemy leader's faction.
- **`release_vassal`:** `CReleaseVassalEffect`; the released country joins the releaser's faction.
- **`MakeVassal`:** every new puppet joins its overlord's faction. It is reached from `create_vassal`, a
  `po_puppet` peace goal, and the government-in-exile swap.
- **`CCreateVassalCommand` and `CLiberateCountryCommand`:** posted by slot 5 of
  `CPuppetCreationDialogDialogue` (`0x6B7540`) and `CLiberateCreationDialogDialogue` (`0x6B8D50`), and also
  built by two unnamed functions (rva `0x589E90`, `0x589DB0`). Only found by vftable writes; none was read.
- **History replay:** `CFactionJoin::Apply`.

The save loader and the lobby setting are not in-game joins.

### A.11 What looks wrong but is what the bytes do

1. The proposer's dialog prints the alliance influence costs (5.00 to join, 1.00 to invite). The action
   charges the faction costs (0).
2. The neutrality tooltips print the other direction's limit (both are 25).
3. A row greyed because of a war with a member says only "Request to join their faction." / "Invite them to
   join our faction".
4. FACTIONJOINACCEPT ("have accepted us into the") goes to **every** member after a join, the leader who
   accepted included. When an invite is accepted, members other than the inviter get
   FACTIONJOINACCEPTOTHER, whose setup text is "a faction we are not part of".
5. A proposal costs nothing even if it is never answered. The cost falls on the proposer at acceptance.
6. The subject sweep keys on `overlord_id` alone, not `isSubject`.
7. A join ends the joiner's alliances with its new co-members, its own puppets included. It ends no one
   else's.
8. A war with a member at acceptance time silently drops the answer: no message to anyone.
9. Lua's `CFactionAction(...)` defaults to a join request. The shipped AI only ever invites, and a
   non-leader member's invitation does nothing.
10. `CJoinFactionGoalAction` hard-codes `'axis'` and can never be created.

### A.12 Not settled

- Whether a message variable holding a key (`COMMENT` = `FACTIONCOMMENT_axis`) is shown as that key's text.
  *Inferred* from the MESSENGER/MESSAGE_HEAD_CHAN precedent; the substitution was not read.
- Which sound-object slots (+0x64, +0x24) mean "is playing" and "play". *Inferred* from the shape.
- That REB holds id 0 rests on `countries.txt` order and is *inferred*.
- Who decides to open the puppet and liberate dialogs, and what rva `0x589E90` / `0x589DB0` are. Not read.

Frontier: `0x2F070` (`CMessageVariable` pair constructor), `0x32F70` (its copy into a list node),
`0x2B7540` (`CPuppetCreationDialogDialogue` slot 5), `0x2B8D50` (`CLiberateCreationDialogDialogue` slot 5),
`0x589E90`, `0x589DB0` (unnamed constructors of the two vassal commands).

Fragment `fragments/merged/faction-join.json`.

---

## B. Leaving a faction, and what a member gets

Read by brief B. Text keys are quoted with their English text from `localisation`/`tfh/localisation`;
defines are Their Finest Hour's. The collecting session checked the correction in B.3 on the bytes:
`CCountry::RebuildRules` sets ESI to `country + 0xDBC` (`0x4FBC1B`) and `CRule::Merge` ORs the bytes at
ESI `+0x18`, `+0x20`, `+0x28` and `+0x30` (`0x45E343`-`0x45E3A4`).

### B.1 A player cannot leave a faction in the one canonical game; the leave button is the custom game's

**"Cgm" is Their Finest Hour's Custom Game Mode**: the scenarios under `tfh/cgm/` (AttackOnTheWest,
Blitzkrieg and others, with `cgm_settings.txt`), played in confirmed setup stages.
`CGM_TOOLTIP_DIPLOMACY_STAGE` says: "In this stage you can edit your diplomacy. You can spend your diplomacy
points on leaving a faction (and their wars), aligning toward another faction, or even change your neutrality
level." The `cgm_leave_faction` button is view widget `+0x530`, one of the custom-game widgets
`ClearCgmWidgets` destroys. Every `Cgm_*` helper first tests the settings' first byte
(`GetCustomGameSettings`, rva `0x1C4E0`) and answers false or null outside a custom game.

**Outside the custom game there is no leave at all**, for the player, for the AI, or from Lua:
- The diplomacy screen's faction rows are only Invite and Join (`FINDINGS-agreements.md` B).
- No Lua registration names a leave. The luabind faction names are `GetFaction`, `HasFaction`,
  `IsFactionLeader`, `GetFactionLeader`, `HasNeighborInFaction` and similar.
- A string search for `LEAVE_FACTION` finds only the custom-game keys (`0x4F67BB`, `0x4F68B4`, `0x4F69F8`,
  `0x77F7F5`, `0x78F5D4`), `LEAVE_FACTION_INTENTION`, and the effect's `LEAVE_FACTION_EFFECT` (`0x9A243B`).
  The positive control is that the same search finds every custom-game key the screen code uses.
- The ways out of a faction in a normal game are the ones in B.2's table, and none of them is a choice the
  player makes.

**How the custom game's leave works**, for completeness:

1. **The click.** `CDiplomacyView::OnCgmLeaveFaction` (`0x77C030`, rva `0x37C030`) finds the player's record
   in the settings' record vector (`+0x2C..+0x30`, matched on record `+4` against the player id). It builds a
   `CCgmLeaveFactionCommand` with `is_leave = !record->+0x54`. **It is a toggle.** The button reads
   `LEAVE_FACTION` "Leave Faction" while the flag is clear and `REJOIN_FACTION` "Rejoin Faction" while it is
   set. The command is posted on the command channel. There is **no confirmation dialog**.
2. **The command.** `Execute` (`0x42A130`) writes the flag into the country's record and into the record of
   each vassal that has one, then refreshes the diplomacy screen (in-game screen slot 101). **Nothing about
   the faction changes here.** The screen shows the intention: the faction icon is hidden, and the status
   list starts with `LEAVE_FACTION_INTENTION` "§Y$COUNTRY$§! §Ris going to leave the faction.§!"
   (`Cgm_IsLeavingFaction`, `0x78F900`). A puppet with no record of its own shows as leaving whenever its
   overlord is.
3. **The gate** is `CCountry_CanLeaveFaction` (`0x4F6A60`). It says no when the country is in no real
   faction, is the faction's leader (its first member), or is a subject whose overlord is in *any* real
   faction. **There is no at-war test.** The refusal is the tooltip from
   `CCountry_DescribeCannotLeaveFaction`: `CGM_TOOLTIP_LEAVE_FACTION_NON_FACTIONED` "You are not a faction
   member.", `CGM_TOOLTIP_LEAVE_FACTION_LEADER` "You cannot leave the faction because you are the Leader.",
   `CGM_TOOLTIP_LEAVE_FACTION_PUPPET` "You are a puppet of §Y$COUNTRY$§R which is a faction member.\nWe will
   automatically leave the faction if they do." Otherwise the tooltip is `CGM_TOOLTIP_LEAVE_FACTION` "Click
   to leave the faction.\nAll common wars will end in a white peace.\n§G(By confirming this setup stage you
   will leave the current faction.)§!" or `CGM_TOOLTIP_REJOIN_FACTION` "Click to rejoin the
   faction.\n§GPoints will be retrieved.§!", followed by `CGM_TOOLTIP_COST` "Points cost: $COST$". The cost
   arithmetic was not read. The button is also disabled where the player is not yet leaving and the
   settings' points are below that cost (decompiler only).
4. **The leave waits until the stage is confirmed.** `ApplyCustomGameSettings` (rva `0x1D560`), called with
   stage 0 and the settings' `+0x18` non-zero (`0x41D823`), calls for each record `CustomGame_ApplyFactionLeave`
   (`0x4192C0`) and then the join, `ApplyCustomGameSettingFaction` (rva `0x19360`). The leave applies first to
   each vassal that has no record of its own, then to the country. Each runs `CustomGame_LeaveFaction`
   (`0x418BC0`). With L the faction's first member:
   1. Every war in which the country stands on a side whose first-listed country is L: `RemoveAttacker` or
      `RemoveDefender` with no history; then, for each country on the other side,
      `CCountry_ReturnOccupiedProvincesTo` **both ways** - the "white peace".
   2. `OnDiplomacyChanged`.
   3. The inline faction leave: `RemoveMember`, `faction = null()`, `RebuildStaticModifiers`,
      `RebuildRules`, the dirty byte. No history.
   4. `RebuildNeighbours` and `CCountry_AfterDiplomacyChange`, on the country and then on L.
   5. Unless it is a government in exile, every unit standing on ground it does not control is brought home:
      a land unit to the capital; a fleet or air unit to the capital if it has the right base, else to the
      first controlled province that has one; with none anywhere, the unit is disbanded and its manpower
      refunded in proportion to its strength (decompiler only).

   No message is raised.
5. **The join counterpart** is `Cgm_GetFactionJoining` (`0x78F790`). It returns the first real faction, in
   ideology-group order, whose entry in the settings' join map at `+0x88` holds the country. The screen shows
   `JOIN_FACTION_INTENTION` "§Y$COUNTRY$§! is going to join the §Y$FACTION$§!.", and the button's hint is
   `CGM_TOOLTIP_FACTION_ALIGN` "You can spend your diplomacy points to align toward another faction." The
   join is applied at the same confirmation by `ApplyCustomGameSettingFaction`, which copies the leader's
   alignment and calls `AddCountry(faction, country, 0, 0)` for the country and its vassals
   (`FINDINGS-faction.md` §10).

### B.2 What leaving does: `RemoveMember`, `LeaveFaction`, and every way out

**`CFaction::RemoveMember`** (`0x522700`, rva `0x122700`, read whole):
1. Walk `Members (+0x28)` for the first node whose **id** matches the member's. The tag characters are not
   compared.
2. Unlink the node with `CList_CCountryTag_RemoveNode`. A non-member is a no-op. Where the list's no-unlink
   byte (`+0x34`) is set, the node is only marked.
3. Set `members_changed (+0x38)` to 1, **unconditionally**.
4. `CGameState_ClearAlliedObjectivesForCountry(state, id)`, also unconditionally: every allied objective set
   for that country or requested by it is cancelled (`FINDINGS-aifields.md`).

It touches nothing of the country. Since leadership is positional, removing the leader makes the next member
the leader. Seven callers, all named in the record now.

**`CCountry::LeaveFaction`** (`0x4F6B20`, rva `0xF6B20`; `FINDINGS-faction.md` §8, re-read on the listing).
If the faction is real:
1. `RemoveMember`.
2. `faction = CFaction::null()`.
3. The optional `CFactionLeave` history entry, stamped with the tick.
4. `RebuildStaticModifiers`, which drops the faction's modifier, and for a subject also step 19's
   `align_towards_*` (`FINDINGS-countrymodifier.md` §2).
5. `RebuildRules`, which clears the rules (B.3).
6. The display dirty byte.

**All four callers pass `recordInHistory = 0`** (`0x4A37E9`, `0x4DBE64` with EDI 0, `0x5F0A99`,
`0x9A236C`), and nothing references the function as data. So **no `CFactionLeave` history entry is ever
written in play.**

What it does **not** do: wars are untouched; no alliances exist from a faction (`FINDINGS-faction.md` §4);
the Allies list (`+0xF88`) keeps the old faction-mates until the country's next daily `RebuildNeighbours`;
influence, threat and relations are untouched; the alignment position stays at the leader's, where member
steps put it (`FINDINGS-alignment.md` §1.5), and drifts from there at its next `ALIGNMENT_INTERVAL` step;
no AI strategy rebuild and no `OnDiplomacyChanged`; puppets stay in the faction; no message.

**Every way out, and what each adds:**

| how | where | beyond the membership |
| --- | --- | --- |
| `leave_faction = <faction>` | `CLeaveFactionEffect::Execute` (rva `0x5A21C0`) | leaves each war whose side lists the faction leader first, then `OnDiplomacyChanged`, then `LeaveFaction(false)`; nothing if not a member (`FINDINGS-effectrun.md` 2.6) |
| last province lost | `CMapProvince::ChangeOwner` step 5 | `LeaveFaction(false)` (`FINDINGS-surrender.md` D.3) |
| leader in exile, daily | `ExileDaily_ReturnWhenFactionLeader` | `LeaveFaction(false)`, then `SetGovernmentInExile(0)` (`FINDINGS-surrender.md` C.5) |
| annexed | `0x4E81AD` | inline leave, no history (`FINDINGS-surrender.md` A.3) |
| made a puppet | `MakeVassal` `0x4D9664` | inline leave, then joins the overlord's faction (`FINDINGS-surrender.md` B) |
| landless as a session is entered | `RemoveLandlessCountriesFromWars` `0x68A041` | every war, then the inline leave |
| joining another faction | `AddCountry` step 2 | `RemoveMember` only (`FINDINGS-faction.md` §1.1) |
| leader goes into exile | `FactionLeaderPromotion` | re-orders only (`FINDINGS-faction.md` §3) |
| custom game | `CustomGame_LeaveFaction` | B.1 |

### B.3 The faction rules: what each one does, and a correction

A faction's `rule = { ... }` block in `common/ideologies.txt` is read by `CRule::LoadKey` (`0x45D920`, rva
`0x5D920`). It is not a switch: it searches the four rule definitions `InitRuleDefinitions` makes (`NONE`,
`RULE_LIMITED_WAR` "Limited war", `RULE_ALLIANCE_GUARANTEE` "Alliance-wide guarantees",
`RULE_FREE_RESOURCE_GIFTS` "Free resources gifts"), whose file keys are **`limited_war`,
`allience_wide_guarantee` (so spelled) and `free_resource_gifts`**.
- `yes` sets the bool at `+0x18 + i*8`; `no` clears it; anything else is complained about (`0xA7A960`) and
  clears it.
- An unmatched key is logged from rule.cpp as "unknown rule '<key>' in file <file>".
- In Their Finest Hour (and BlackICE): the Axis has `limited_war`, the Allies `allience_wide_guarantee`, the
  Comintern `free_resource_gifts`.

**`CCountry::RebuildRules`** (`0x4FBC10`, rva `0xFBC10`, now `confirmed`):
1. Clears the four bools of the country's `Rules (+0xDBC)`: `+0xDD4` NONE, `+0xDDC` LIMITED_WAR, `+0xDE4`
   ALLIANCE_GUARANTEE, `+0xDEC` FREE_RESOURCE_GIFTS.
2. Frees the merged-rule list.
3. If the faction is real, runs `CRule::Merge(&Rules, &faction->rule)`, an OR.

So **a member holds exactly its faction's rules, and a non-member holds none.** It runs for every country as
a session is entered (`0x65B2B2`), every month (`CCountry::UpdateMonthly`, `0x4DCB9E`), on an in-game join
(`AddCountry` step 8), and on every leave path in B.2.

**Correction.** `FINDINGS-agreements.md` C.3 and B.9/B.10, `FINDINGS-war.md` C (item 10) and
`FINDINGS-trade2.md` §11 say that nothing writes `+0xDDC`/`+0xDE4`, and the record called two branches dead.
`Merge` writes them as `mov byte [esi+0x20/0x28], al`, with ESI = `&country->Rules`. Those are disp8 stores,
which a disp32 scan of CCountry cannot see. `FINDINGS-tradeaid.md` A.11 had already found this route for
`+0xDEC`; the other two bytes use the same instructions. What each rule does:

- **limited_war** (`+0xDDC`, the Axis):
  - The action list offers "Declare Limited War" (`0x4E40D5`, `FINDINGS-agreements.md` B).
  - **The AI's war plans use it** (`0x89D9A1`, inside `CAIForeignMinister::DoWork`'s prepared-war walk). For
    a target with no decision, the AI builds a `CDeclareWarAction` (constructor `0xA11DF0`, `value` 1) with
    war goal `conquer`. It sets `value = 0`, a limited war, where the target entry's `+0x14` byte is clear and
    the AI's own country holds the rule.
  - A limited war sets `CWar +0x70`, does not call the declarer's allies (`FINDINGS-war.md`), and does not
    pull a new faction member in as an attacker (`FINDINGS-faction.md` §1.2).
- **allience_wide_guarantee** (`+0xDE4`, the Allies):
  - `CGuaranteeAction::Apply` (`0xA1BDF4`): **a guarantee by any Allies member is also made by every other
    member of the faction**, each a `CGuarantee(1)` of its own over the same country.
  - The offer dialog adds `ALLIES_GUARANT` "Should we need to come to their aid, all members of our faction
    will follow us." (`0xA1DE77`).
  - `CCallAllyAction::Apply` (`0xA28CA0`): when a member answers a call to arms, **every member of its faction
    not already defending is called and accepts at once**. Each is a new `CCallAllyAction` at ACCEPT, made
    into its command and executed on the spot.
- **free_resource_gifts** (`+0xDEC`, the Comintern): two members trade goods for goods, or for nothing
  (`FINDINGS-tradeaid.md` A.11). `CEU3AI::CanTradeFreeResources` (`0x89B730`) is now read and is exactly that
  test on both countries.
- **NONE** (`+0xDD4`): no reader.

The faction box's tooltip lists the rules that are set (`CRule::DescribeSetRules`,
`FINDINGS-diplomacyview.md` F.5).

### B.4 The strategic-resource bonus behind `IsWithinFactionStratBonusDistance`

`CAlignment::IsWithinFactionStratBonusDistance` (rva `0xC4D20`) has exactly two callers: 
`CCountry::GetsStrategicResourcesFrom` (`0x68BFBC`), the bonus itself, and `CAlignment::BuildDriftTooltip`
(`0x4FAC8C`), its tooltip.

The test is `distance² < FACTION_STRAT_BONUS_DIST² / 1000`, everything in thousandths, **strictly less**.
FACTION_STRAT_BONUS_DIST is **100**, so a distance of 100 or more fails. The distance runs from the country's
alignment position to **the faction's ideology group's position** (`CFaction +0x8`) - its corner of the
triangle (Axis (200, 200), Allies (0, -146), Comintern (-200, 200)) - **not the leader's position**.

**What the bonus is** (`FINDINGS-countrymodifier.md`, "Who is given whose", already confirmed): a faction's
**leader, while at war**, receives the strategic resources held by any country **outside** the faction whose
position passes that test. The usual link condition still applies: capitals on continents of the same name,
or naval bases on the same sea entry. Separately, a member that is a major or has more than 100 max IC
receives what any member holds. Each resource adds its modifier times its level (`RebuildStaticModifiers`
step 9). This is reckoned at the top of every daily pass, and not on entering a new game.

The tooltip lines: `RESOURCE_BONUS_ALIGNMENT_TT` "If close to a faction they could provide §Y$RESOURCES$§W
to a faction leader."; `CAN_GIVE_STRAT_BONUS` "Closely enough aligned to provide §Y$RESOURCES$§W to
§Y$WHO$§W."; `CAN_GIVE_STRAT_BONUS_BUT_NONE` "...strategic resources to §Y$WHO$§W, but they have none.."
(`FINDINGS-diplomacyview.md` F.4).

### B.5 Everything else membership gives or forbids (already recorded)

| what | the rule | where |
| --- | --- | --- |
| the faction's modifier | `CFaction +0x7C`, from the file's `modifier`, added to every member. Their Finest Hour: Axis `territorial_pride` 0.1; Allies `war_consumer_goods_demand` -0.1, `peace_consumer_goods_demand` +0.1; Comintern `supply_consumption` -0.33, `espionage_bonus` 0.1 | `FINDINGS-countrymodifier.md` §2 step 3 |
| a subject in no faction | gets its overlord's faction's `align_towards_*` | the same, step 19 |
| alignment | members do not drift: each step sets them to the leader's position, and the leader does not move. Tooltip `DIP_ALIGNED_DRIFT` "$NAME$ is a $FACTION$ member and will not drift." | `FINDINGS-alignment.md` §1.5; `FINDINGS-diplomacyview.md` F.4 |
| the war ceiling | + the declarer's faction's `neutrality` (`CFaction +0xB0`; the Axis 25); line `WARNE_FACTION` | `FINDINGS-diplostate.md` C.3; `FINDINGS-diplomacyview.md` F.8 |
| wars | a join brings the leader's wars; declaring war can put the victim into the enemy's faction; a puppet joins its faction leader's wars | `FINDINGS-faction.md` §1.2, §7; `FINDINGS-surrender.md` B |
| `ally` / `Allies (+0xF88)` | every member, rebuilt daily | `FINDINGS-faction.md` §4 |
| `IsFriendly` (same real faction) | may enter each other's ground; land with no port or capital draws on a friend's depot | `FINDINGS-movement.md`; `FINDINGS-supplynetwork.md` |
| depot score | a faction leader's capital +10,000,000 | `FINDINGS-supplynetwork.md` |
| bases | a fleet that loses its base takes the nearest of its faction's naval bases | `FINDINGS-seaair.md`; `FINDINGS-navalmissions.md` |
| diplomacy rows | no war on a faction-mate; no alliance offer when both are in real factions; no military-access row within one faction; Influence needs the actor in a faction; Align needs the actor in none; `PEACE_FACTION` "You are both in factions, and factions fight until they surrender" | `FINDINGS-agreements.md` B |
| relations and threat | start relation +50 for the same faction, else -25; a faction-mate is never the most-threatening country | `FINDINGS-diplostate.md` A, B.5 |
| governments in exile | use the first member's technology; acting capital moves toward the leader's | `FINDINGS-unitdaily.md`; `FINDINGS-alignment.md` §3 |
| research | `triggered_modifiers.txt`'s `neutrality` takes 5% research efficiency off every country in no faction (script, not engine) | `FINDINGS-researchshare.md` |
| AI | allied objectives (cleared on leaving); front-worthiness tests | `FINDINGS-aifields.md`; `FINDINGS-invasion.md` |

Victory points and progress are C's. No faction term was found in what the record says about intelligence,
which was not read further.

### B.6 What looks wrong but is what the bytes do

1. **In a normal game no one can choose to leave a faction.** The leave button exists only in the custom
   game, and there it is a toggled intention that takes effect at the stage's confirmation.
2. `LeaveFaction`'s history arm is dead: all four callers pass 0, so `CFactionLeave` is never written in play.
3. `RemoveMember` sets `members_changed` and clears allied objectives even for a country that was not a
   member.
4. `leave_faction` on the leader takes it out of every war it heads (each side whose first-listed country is
   the leader). The next member becomes leader by position.
5. Leaving does not refresh the Allies list until the next daily `RebuildNeighbours`. `LeaveFaction` also
   skips `OnDiplomacyChanged` and the AI rebuild that `AddCountry` runs.
6. Puppets stay in a faction their overlord leaves. The custom game's leave alone takes vassals without
   records along.
7. The custom-game `CanLeaveFaction` refuses a puppet whose overlord is in *any* real faction, not only the
   same one.
8. `OnCgmLeaveFaction` and `CCgmLeaveFactionCommand::Execute` dereference a null record when the country has
   none (`0x77C103`, `0x42A18B`).
9. The strategic-resource distance is measured to the faction's triangle corner, not to its leader.
10. The rule key is spelled `allience_wide_guarantee`.

### B.7 Not settled

- What the AI war target's `+0x14` byte means; it decides whether an Axis AI's war is limited.
- Exactly which stage `ApplyCustomGameSettings(stage 0, settings+0x18 set)` is; *inferred* to be the
  confirmation of the diplomacy stage, from the tooltip text.
- The custom game's points cost (`0x41D3D0` +0x14, `0x41ED50`) and the meaning of `0x4208B0`.
- `CustomGame_LeaveFaction`'s unit recall (step 5) was read only through the decompiler.
- `CustomGame_ApplyCountryNeutrality` (rva `0x18990`) clears the leave flag where `CanLeaveFaction` answers
  **true**. That reads backwards, and why was not settled; the entry is left unrevised.
- No savegame contains a guarantee or call to arms made by the action (all 45 BlackICE saves and the Their
  Finest Hour saves hold only history guarantees), so the now-live Allies branches have no save oracle. They
  rest on the chain `LoadKey` → `Merge` → `RebuildRules`, read instruction by instruction, and on the existing
  record of the readers.
- No `CRule` struct was declared (`+0x8` list, bools at `+0x18 + i*8`, `+0x38` icon): doing so would fold the
  four CCountry rule fields into `Rules`, and is left for a decision.

Frontier: `0x37C180` (after the leave click), `0x1D470` and `0x1F300` (custom-game has-record / find-record),
`0x21660` (the join map lookup), `0x1D3D0`, `0x208B0`, `0x1ED50` (custom-game points and stage), `0x1F7C0`
(the caller of `CustomGame_ApplyCountryNeutrality`), `0x611DF0` (`CDeclareWarAction` constructor), `0x5D7B0`
(`CRule` constructor), `0x4ADEF0` (the AI war-target readiness test).

Fragment `fragments/merged/faction-leave.json`.

---

## C. A faction's progress and the victory conditions

Read by brief C. The defines are Their Finest Hour's `tfh/common/defines.lua`. The collecting session
checked `GetVictoryPointShare`'s arithmetic (`0x522D5D`-`0x522DCF`) and the two counters
(`0x543D70`, `0x543DB0`) on the bytes.

### C.1 Progress: the victory points the members control, made again every hour

`CFaction +0xAC Progress` (Lua's `GetProgress`) is written in exactly two places, both inside
`RunHourlyPass` (rva `0x282630`):

1. **The reset, at `0x6827B1`.** The pass walks the ideology database's groups (`[0x1A878BC] +0x1C..+0x20`).
   For each group it takes the group's faction (`+0x54`) - or, for a group with no faction, the null faction
   - and sets its Progress to 0.
2. **The sum, at `0x682A60..0x682A7D`.** For every province in the game state's vector whose template is
   simulated (`CProvinceTemplate +0x13D`, which is everywhere in a campaign and only the scenario's own
   provinces in a scenario), it calls `RunHourlyProvincePass` (`0x49E600`, rva `0x9E600`). That function
   begins:

       controller = CCountryTag::GetCountry(&province->controller (+0x334))
       controller->faction (+0xD8)->Progress   += province->victory_points (+0x34) * 1000
       controller->controlled_victory_points (+0x11CC) += province->victory_points * 1000

So **Progress is the sum of the victory points of the provinces whose controller is a member, at the hour it
was last made.** It is not ownership and not cores. The credit goes to whatever faction the controller is in
at that hour. Between the reset and the sum, the per-country hourly pass and the unit functors run; anything
reading Progress there would see a partial figure. Nothing in Their Finest Hour's or BlackICE's script does.

`CCountry +0x11CC` (new field) is the same sum per country. It is zeroed at the tail of
`RunCountryHourlyPass`, which runs earlier in the same hour.

**Checked against the saves.** In all twelve of the maintainer's 1936 saves the `faction` block gives
axis/allies/comintern `progress = 115/263/173`. These equal the summed `points` of the provinces whose
controller is a member, out of 1172 in the world. Owner gives the same figures in those saves, so the saves
cannot separate owner from controller; the instruction can, and it reads +0x334.

This is **not** the sum the surrender counts. `FINDINGS-surrender.md` D's `CountVictoryPoints` is per
country, over **cores**, owned against held (`CCountry +0xBE0/+0xBE4`). Faction progress is over every
province, by controller, per faction.

### C.2 `CFaction::GetVictoryPointShare` (`0x522CC0`, rva `0x122CC0`), and who agrees with it

`int* __stdcall (CFaction* faction, int* out)`, `ret 8`, read whole:

    TOTAL = sum over every province of the game state's vector (count from +0xB8C..+0xB90,
            pointer from g_CMap +0x2200) of victory_points * 1000
    out   = Progress
    if TOTAL != 0:  out = Progress * 1000 / TOTAL        (64-bit, truncating)
    out   = out * 100000 / 1000                           (64-bit, truncating)

- **The result is a percentage in thousandths, with only a tenth of a percent of resolution.** The first
  divide cuts the fraction to thousandths of one. So 115 of 1172 gives 9.800, not 9.812. The three factions
  in the start save give 9.800 / 22.400 / 14.700.
- **There is no cap and no floor, and nothing is cached.** TOTAL is summed on every call.
- **TOTAL is every map province, sea and land, with no test of the simulation flag.** In a scenario,
  Progress counts only the scenario's provinces while TOTAL counts the whole world.
- **When TOTAL is 0**, the share is Progress × 100.

Its callers agree:

- **`faction_progress = N`** (`CFactionProgressTrigger::Evaluate`, rva `0x5FD370`) is `share >= N`, with N in
  thousandths. So `= 50` means 50%. **The two agree**, which confirms `FINDINGS-triggerleaves.md` 1.4. Its
  text is `FACTION_PROGRESS_MORE` "Faction Progress at least " / `FACTION_PROGRESS_LESS` "Faction Progress
  less than " + §Y + the value to one place.
- **The diplomacy screen's faction box** (`0x7832F3`) sets `victory_progress` to share / 1000, which is whole
  percent, cut: 9, 22, 14.
- **The revanchism term** (`0x4C3F60`), which already uses ×1000/100000 in the record.
- **The box's tooltip**, `CFaction_BuildProgressTooltip` (rva `0x122E00`), does the same arithmetic written
  out again. So `FACTION_PROGRESS_DESC` "$WHO$ controls §Y$PERCENT$%§W of the victory points. (Currently
  $OUR$ out of $TOTAL$)." shows PERCENT = the same cut share to two places ("9.80"), OUR = Progress whole,
  TOTAL = the world's sum whole.

**What Lua can ask of a faction** about this: `GetProgress` (the raw Progress) and
**`GetNormalizedProgress`** (`0x522BD0`, rva `0x122BD0`, newly recorded). The latter takes the largest
Progress among the valid factions of the game state's list (`+0xCE4`), starting from -1000:
- largest under `floor(10.5f)` = 10 (0.010 of a point): 0;
- otherwise Progress × 1000 / largest, cut;
- its "largest is 0 → -1" arm can never run, because it comes after the "under 10" test.

Neither Their Finest Hour's Lua nor BlackICE's calls either function.

### C.3 The null faction's Progress is never reset (*inferred*, by the bytes)

The hourly reset zeroes the null faction **only for an ideology group that has no faction**.
`common/ideologies.txt` has three groups and all three have a faction. A country in no faction holds the
shared null faction, never a null pointer, so every province controlled by a factionless country adds to the
null faction's Progress each hour.

Of the 71 code references to the null-faction global `0x1A855A8`, the reset loop is the only `+0xAC` store
near any of them; the constructor's own store is at `0x522539`. The 36 stores to the global are all of the
lazy-construction shape (not checked one by one).

So in Their Finest Hour this figure grows by roughly 621 points × 1000 an hour and wraps a 32-bit integer
after about 144 days. **`faction_progress` asked of a country in no faction - or of a province scope, which
reads country 0 - reads that figure.** Its "share" runs into thousands of percent, then goes negative after
the wrap. No run was made. Neither the base game nor BlackICE uses `faction_progress`.

### C.4 The victory conditions: a file of named triggers, per faction

**Where they are.** `CCurrentGameState +0xD08` points to a **`CVictoryConditionManager`** (declared: `0x44`
bytes, CPersistent, vftable `0x15C35F8`, made by CGameState's constructor). It holds three parallel
per-faction vectors:

| | |
| --- | --- |
| `+0x8` | the factions, in the order the file names them |
| `+0x18` | **the conditions chosen for this game** - what is tested, counted, saved, and walked by the AI (`FINDINGS-triggereval.md` root 2, weight 200) |
| `+0x28` | **every** condition the file defines |
| `+0x38` | how many each faction picks |
| `+0x3C` | how many met conditions win |
| `+0x40` | `game_finished` |
| `+0x41` | `game_finished` as loaded |

**What a condition is.** A `CVictoryCondition` (`0x6C` bytes) is one block of the faction's section:

    axis = { operation_sealion = { trigger = { 1964 = { controller = { faction = axis } } ... } primary = yes } ... }

- `+0x8` is the name, `+0x24` an embedded `CAndTrigger` (the `trigger`), `+0x64` a date, `+0x68` met,
  `+0x69` chosen, `+0x6A` primary.
- Only `trigger` and `primary` are keys.
- The file is `common/faction_aims.txt` (`LoadFactionAims`, rva `0x143430`). It is identical in `tfh/`:
  - axis: 33 conditions, 15 of them primary;
  - allies: 22 conditions, 15 primary;
  - comintern: 30 conditions, 15 primary.
- **The conditions belong to a faction, not to a country.**

**The two counts.** They come from the defines, taken whole (`/1000`, cut), when the game state is made and
again whenever a scenario is left:
- `NUMBER_OF_VICTORY_CONDITIONS = 15` → `+0x38` ("The number of victory conditions each faction needs to
  pick");
- `VICTORY_CONDITIONS_TO_WIN = 12` → `+0x3C`.

`MarkSimulatedProvinces` (rva `0x285FB0`) reloads the file whenever the scenario changes:
- going **to** no scenario (from one): `common/faction_aims.txt` with the defines' counts;
- going **to** a scenario: the scenario's own `victory_conditions` file (e.g.
  `scenarios/fall_blau/faction_aims.txt`), then `victory_conditions_to_win` (`CScenario +0x104`) and
  `number_of_victory_conditions` (`+0x108`), each only where above 0 - Fall Blau's are 3 and 3.

Either way it clears both `game_finished` bytes.

### C.5 Choosing them, and `CChooseVictoryConditionsCommand`

**When the start date is set**, `CSetHistoryDate::Execute` (rva `0x2D60C0`, slot 6) clears both
`game_finished` bytes and then chooses:

- **In a scenario: `VictoryConditions_ChoosePrimaries`** (`0x544310`, rva `0x144310`). Chosen = primary,
  every one, with no count.
- **In a campaign: `VictoryConditions_ChooseRandomly`** (`0x544370`, rva `0x144370`). Per faction, with
  budget = `+0x38`:
  - walk the file's list in order; each primary costs one from the budget; each condition's chosen = its
    primary flag. **The walk stops when the budget reaches 0**, and later conditions keep the chosen byte
    they had.
  - then, `budget` more times while unchosen ones remain: draw from a Mersenne Twister of its own, **seeded
    from `_time64`** (the wall clock, not the game's generator), and take `r = draw % unchosen` signed. Walk
    back from the last condition, skipping chosen ones, and take the r-th. **A negative r takes the last
    condition whether or not it is already chosen.**
  - Their Finest Hour has exactly 15 primaries per faction against a count of 15, so the random part never
    runs: **every faction gets its 15 primaries.** The start save's `victory_conditions` block lists exactly
    those, each with the null date.

**The lobby's victory-condition window** (`CSelectVictoryConditionsView`, `vc_*`; accept at `0x71B9E0`, rva
`0x31B9E0`) lets a faction member tick conditions.
- `VictoryConditions_FitChoiceToCount` (`0x544500`) randomly removes or adds picks until there are exactly
  `+0x38` - `VC_ACCEPT_DISABLED` "$NUM$ conditions selected, will randomly add/remove to $TOTAL$.".
- It then posts a `CChooseVictoryConditionsCommand(faction, list)`.
- The texts `VC_BUTTON_DISABLED_INVALID` "Only countries that are faction leaders can select victory
  conditions." and `VC_BUTTON_DISABLED_SAVE` "Cannot reselect victory conditions when loading a saved game."
  exist, but where the window enforces them was not read. The accept itself only requires the player to be
  in a valid faction (decompiler only).

**At game start**, the front end (`0x70E89C`, inside the unnamed `0x70E5B0`, where a session byte `+0x34` is
set) calls `VictoryConditions_PostChosen` (`0x5440A0`). For each faction with any chosen condition, this
posts a `CChooseVictoryConditionsCommand` carrying each chosen condition's name and date.

**The command** (`0x50` bytes, CCommand, type `0x753`; faction at `+0x3C`, a vector of strings at `+0x40`):
- `Execute` (slot 6, `0x5537D0`) is `VictoryConditions_SetChosen(faction, state+0xD08, &list)`.
- `IsValid` (slot 14) is "the faction is valid".

`VictoryConditions_SetChosen` (`0x543E10`, rva `0x143E10`):
- **first clears `game_finished` (+0x40)**;
- empties `chosen[f]` and clears every chosen byte of `all[f]`;
- for each (name, date) pair in the list's order, finds the condition of that name in `all[f]`, appends it to
  `chosen[f]`, sets its chosen byte, parses the date into `+0x64`, and sets **met = date after the null
  date** (43800000).

An unknown name is dropped in silence. **The save** writes per faction `<name> <date> ... <faction>` plus
`game_finished`, and its `faction` key goes through this same function.

### C.6 The test, once a day

`VictoryConditions_DailyCheck` (`0x543AB0`, rva `0x143AB0`) is **the last thing `RunDailyPass` does**
(`0x683062`). The front end also calls it once at `0x70EB80`.

    scope = an empty CEventScope (country '---'/0)
    for each faction f, for each chosen condition c:
        held = c->trigger->Evaluate(&scope)          ; CAndTrigger, slot 6
        if held: count[f]++, and if c was not met: c->date = now (+0xBDC)
        c->met = held
    if neither game_finished byte is set:
        for f in the factions' order: if count[f] >= to_win (12):
            game_finished = 1
            in-game screen: slot 76 if a scenario is running, else slot 75
            stop

- **`met` is whether the trigger holds today.** A condition that was held and is lost stops counting. Its
  date is kept, and is overwritten only when it next starts to hold.
- **Of two factions reaching 12 on the same day, the first in the file's order wins.**
- The flags keep being updated after the game is finished.
- **No winner is recorded anywhere** - only the flag.

### C.7 What the player is shown of them

- **Diplomacy screen, faction symbol** (`CDiplomacyView::BuildTooltip`, `0x780CBA..0x780CD5`): the delayed
  half ends `"\n<met>/<chosen>"`, e.g. "\n0/15": `CountForFaction` (`0x780CBA`) is pushed first and so
  is the second `%d`, `CountMetForFaction` (`0x780CC2`) is pushed last and is the first (checked on the
  listing by the collecting session). This settles `FINDINGS-diplomacyview.md` F.10's open order.
- **In-game window `vc_window`** (`interface/vc_interface.gui`, update at `0x6D2990`): each day of the year
  it sets, for `axis`, `allies` and `comintern`:
  - `vc_<f>_progress_text` = "%d / %d" of met and **`NUMBER_OF_VICTORY_CONDITIONS` (15)**;
  - the bar `vc_<f>_progress` = met × 100 / 15.

  **It counts toward 15, while the game ends at 12.** (Decompiler; the window's list was not read.)
- **Alert 14, `alert_victory_conditions`** (`CAlertManager_Update`, `0x606C3E..0x606CD9`): shown while any
  faction **other than the player's** has met × 100 / `VICTORY_CONDITIONS_TO_WIN` ≥ 75, i.e. 9 or more met.
  Its title is `VC_ALERT` "§GVictory Conditions§W". Its tooltip uses `VC_DANGER` "§Y$FACTION$§W have
  completed §R$NUM$§W victory conditions." with the same 75% test (`0x607BA5..0x607C57`); that tooltip
  builder is not read whole.

### C.8 What the end does - identified, not read

- **A campaign won by the conditions, or the clock past the defines' `end_date` ('1948.1.1').**
  - The end-date test is at `0x655C19` in `CInGameIdler::Update`, strictly after (`jle` skips equality).
  - Either route calls **`CInGameIdler` slot 75, `ShowVictoryConfirmDialog`** (`0x671A10`, rva `0x271A10`).
    Once (byte `+0x12E1`), it makes the `VCConfirm` dialog (`0x670C20`):
    - title `CONFIRM_VC_VICTORY` "Victory!" / `CONFIRM_VC_DEFEAT` "Defeat!";
    - text `CONFIRM_VC_TEXT` "§Y$FACTION$§W has achieved their victory conditions.\nDo you want to continue
      playing or resign the current game?";
    - buttons `VC_RESIGN` "Resign" / `VC_CONTINUE` "Continue".
  - Then, every call, where slot 95 (byte `+0x12D8`) is clear, it calls slot 27, which posts a 0x5C-byte
    command - a pause, by all appearance.
  - **Not read:** how the dialog decides victory or defeat, and which $FACTION$ it names - the check passes
    it nothing. That is in `0x670C20`.
- **A scenario, by its conditions or its `enddate`** (`CScenario +0xAC`, read only at `0x655C29`): **slot 76,
  `ShowScenarioEndDialog`** (`0x671AA0`).
  - `endgame_dialog` gets `ENDGAMEHEADER_` / `ENDGAMEBODY_` / `ENDGAMEBUTTON_` + scenario name + `_` + the
    player's tag + **`_WIN` where the player's own faction has met ≥ to_win, else `_LOSS`** - e.g.
    `ENDGAMEHEADER_Fall_Blau_GER_WIN` "Victory!", `ENDGAMEBUTTON_Fall_Blau_GER_WIN` "Moscow will be next!".
  - It hides the `scenario_*_win` pictures and, on a win, shows one.
  - So in a scenario the result is the player's own faction's count, whoever triggered the end.
- **After loading a save written once the game had ended:** `game_finished = yes` loads into `+0x41`, so the
  game never ends again. But only `+0x40` is saved, so the next save says `game_finished = no` - and loading
  *that* save can end the game again.

### C.9 What the record had

- `CFaction::GetVictoryPointShare` was `likely`, with "divided ... then multiplied by 100". That is right in
  effect, but it did not mention the two-step truncation, the unfiltered total, or that nothing is cached.
  Now `confirmed`.
- `VictoryConditions_CountForFaction` / `CountMetForFaction` were `inferred`, with "that the object is the
  game state's victory conditions ... not read" and "met, inferred". Both are settled and now `confirmed`.
- `CCurrentGameState` / `CGameState +0xD08` were typed `void*`; they are now `CVictoryConditionManager*`.

### C.10 What looks wrong but is what the bytes do

1. The share is truncated to 0.1% before being made a percentage, so `faction_progress = 9.81` is false at
   9.812%.
2. The share's total counts provinces outside a scenario; the progress does not.
3. The null faction's Progress is never reset in Their Finest Hour, so `faction_progress` on a factionless
   country (or a province scope) reads a figure that only grows, then wraps (*inferred*).
4. "Met" is not sticky: a condition lost after being held stops counting, but keeps its date.
5. The random choice is seeded from the wall clock, so it is not replayable. A negative draw takes the last
   condition even if it is already chosen. The primary walk stops at budget 0 and leaves later conditions'
   chosen bytes as they were.
6. The window and its bar count toward 15; the game ends at 12; the alert fires at 9.
7. `game_finished` is saved from `+0x40` and loaded into `+0x41`.
8. Every `CChooseVictoryConditionsCommand` clears `game_finished`.
9. Ties between factions go to the first in the file's order. No winner is stored.
10. `GetNormalizedProgress`'s -1 arm can never run.

### C.11 Not settled

- The rest of `RunHourlyProvincePass` after `0x49E664` (an owned province's controller handed over at
  `0x49EA3D`).
- How the `VCConfirm` dialog (`0x670C20`) picks Victory or Defeat and its `$FACTION$`.
- What CInGameIdler slots 27 and 95 do.
- Whether the end-date block in `CInGameIdler::Update` sits behind a gate further up.
- Who may open the lobby VC window.
- The session byte `+0x34` that gates `PostChosen`.
- `CSetHistoryDate::Execute`'s history half, and whether the null-faction global is ever destroyed. All 36
  stores look lazy, but they were not checked one by one.

Frontier: `0x270C20` (the VCConfirm dialog's constructor and text), `0x262FD0` (CInGameIdler slot 27),
`0x2D2990` (the vc_window update), `0x2D20B0` (its list entries), `0x30E5B0` (the front end's game start),
`0x30E9B0` (the front end's other call into the daily check), `0x31C710` (the lobby VC window's refresh),
`0x207A74` (the victory-conditions alert's tooltip, whose start `functionStart` gives and is unverified).

Fragment `fragments/merged/faction-progress.json`.
