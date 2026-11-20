# The lobby with several players

Read 2026-11-20, statically, off the listings (no Ghidra), for OpenHOI3's front end. Fragment `multiplayer-lobby.json`. Addresses are rvas unless marked VA (VA = rva + 0x400000); only valid for this build. **[exe]** hardcoded in the executable, **[mod: file]** what a file may change. `confirmed` unless marked *likely* or *inferred*.

This is `CGameSetup`, view 3, as `FINDINGS-frontend.md` sections B and C read it for one player, read again for what changes when the session mode global is 1 (host) or 2 (client) - reached as `FINDINGS-multiplayermenu.md`, section 5, has it. **Everything in sections B and C still holds unless this file says otherwise.** Where a claim rests on an existing record that was not read again, it says "(record)".

**Most of the multiplayer handlers were read in a filtered listing** (calls, compares, jumps, field accesses), not line by line; the fragment's `evidence` fields say "brief listing" where that is so.

**Two tests carry almost every difference** [exe]:

- **the session mode global** (VA `0x1A85618`): 0 single player, 1 host, 2 client;
- **`Session +0x34` `may_post_commands`**: 1 in single player and on the host, 0 on a client (the record's name; in the lobby it reads as "this machine is the authority"). A client still posts commands - a country choice, a chat line - through the same channel call.

**Not wanted and not read**: the network protocol, the large-file transfer layer, the metaserver ("online link", `CGameSetup +0x6C8`, null in a LAN or direct game - every routine here has a second arm for it, none of them read), and `CIngameLobby` (VA `0x69xxxx`, rows `CLobbyHumanItem`), the in-game hot-join lobby that shares several element names (`multiplayer_list`, `button_kick`, `lobby_chat_edit`, `chatlog`) and is a different class.

**Corrected**: `CGameSetup::OnBack`'s record had `0x70E3D0` run "on a client (mode not 0)" - the test is mode not 0, host and client both - and did not say its CAddPlayer is the removal. `FINDINGS-frontend.md` C.6's open item "whether OPTION_CHANGED stays local" is settled by how chat lines travel (section 5): it is local (*inferred*). `CSetCountryControllerCommand::Execute`'s "slot 11 ... read only in outline" is read (section 2). **Noticed and left alone**: the multiplayer menu's record calls the channel's slot 3 with 3000 "a disconnect with a wait"; `CGameSetup_StartGame` calls it in multiplayer and goes on with the same session, so it is more likely a flush with a wait (*inferred*, the slot was not read).

## 1. The players' box (`multiplayer`)

**What is in it** [mod: lobby.gui, temp_frontend.gui]: `frontend_players_bg`, the list `multiplayer_list`, and the texts `checksum` and `num_players`. No code hides or shows the `multiplayer` window: it is part of `lobby` in single player too, with one row (*inferred*: every reference to the name `multiplayer` in the image is a lookup of a child of it - 13 references, all read).

| element | shows | written |
| --- | --- | --- |
| `checksum` | the version label, `HoI3 v4.02 (XXXX)` and the mod (`FINDINGS-frontend.md` A.1) | once, by Prepare, as the lobby opens. It is this machine's own; nothing compares it on screen |
| `num_players` | **FE_NUM_PLAYERS**, "Number of Players: $NUM$", NUM the number of rows in `multiplayer_list` | whenever a row is added or removed. Until the first row the file's text shows ("Number of Players: 5") |
| `multiplayer_list` | a row a human | below |

**A row** is a `CHumanItem` (0xD0 bytes, `0x3095E0`), which keeps its own copy of the player's record:

- **Which window** [exe]: `multiplayer_entry_server` where **this machine is not a client and the row is not its own player's** - so on the host, for every other player; **`multiplayer_entry`** otherwise - the host's own row, every row on a client, and the one row of single player.
- **`name`**: the player's name alone when the row is made; **name + ` (` + the country's name + `)`** once the player has a country (section 2). File font and colour; no colour code is added.
- **`player_shield`**: no country when the row is made; the player's country once chosen (the button's slot 53 with the tag - that this sets the flag is *inferred*). **A left click centres the map on that country's capital** (`CHumanItem::OnShieldClicked`, `0x309B40`; "centres" *inferred* as for the `singleplayer` panel's shield); nothing where the player has no country. It selects nothing.
- **`save_progress`**: empty until a save is sent (section 3), then **`§Y`SAVE_PROG`§W`**, "Save progress: $VALUE$ %", VALUE a whole percentage, in **`§G` once done**. It is never emptied again: after a transfer the row keeps its last line until the row goes.
- **`button_kick`, `button_ban`** (server rows only): `CGameSetup::OnKickButton` / `OnBanButton` (`0x311840`, `0x311D20`), at once, with no question. Tooltips **TIP_KICK** "Kick player" and **TIP_BAN** "Ban player for the duration of this session" (the lobby's tooltip routine, by element name). The rows are put in the tooltip group `gamesetup`.
- **`frontend_player_entry`** is named by no code (not in the image).
- **Nothing else**: a row has one handler, the shield's. No right click, no ready mark, no ping, no host mark.

**Order**: rows are added at the end, in the order the add commands execute (*inferred*: the list's add slot was called with a flag, 1, that was not decoded). Nothing sorts the list.

**How a row comes and goes** - by one command, **CAddPlayer** (name, id, add or remove), executed on every machine (`CAddPlayer::Execute`, `0x2D6890`, *inferred* in part):

| the command | posted by | each machine then |
| --- | --- | --- |
| add | every machine for its own player as its lobby opens (`CGameSetup_AnnounceLocalPlayer`, `0x308190`, from Prepare) | adds the human to the game state; `CGameSetup::OnPlayerAdded` (`0x312C10`): the row, `num_players`, the chat line **PLR_CONNECT** |
| remove | the leaver's own Back; the host's kick or ban; the host on a lost connection (section 6) | unlinks the human; `CGameSetup::OnPlayerRemoved` (`0x313910`): the row taken out, **PLR_DISC**, `num_players` |

**As the lobby opens** (Prepare, then AnnounceLocalPlayer): the list and the chat log were emptied by BuildBookmarkLists (host and single player's path into the lobby); the lobby registers with the session, posts the add for its own player, says **CONNECTED** ("Connected.") in its own chat, and writes settings.txt where `lastplayer` differs from the player's name or, on a client, `lasthost` from the host's address.

**Kick** (`CGameSetup_KickPlayer`, `0x311500`), host only since only the host has the buttons: the player's connection dropped (the channel's slot 16, *inferred*), a CAddPlayer(remove) posted, and a chat line posted to everyone: **PLAYER_KICKED**, "$NAME$ was kicked by the host." **Ban** (`CGameSetup_BanPlayer`, `0x3119C0`) the same after the session's ban routine (*inferred*: for this session, by its tooltip), with **PLAYER_BANNED**, "$NAME$ was banned by the host." What the thrown-out machine sees is in section 6.

## 2. Choosing a country

**A map click is the same on the host and on a client** [exe]: `CGameSetup::OnProvinceClicked` (`0x30C0B0`) has no test of the session mode or of `may_post_commands`. For a province with an owner (and, in a scenario, an owner on the scenario's list) it posts **CSetCountryControllerCommand**(the owner, the state's current player country, this machine's human id) and plays `click`. The bookmark's shortcut shields do the same (record).

**Nothing refuses a country another player has** - not the click, and not the command: its Execute (record, not read again) takes the human off its old country - which goes back to the AI only where no other human holds it - and gives it the new one, marking the human "primary local" only where no other human of that country is. **So two players may share a country**, and the first there is its primary. No message is written for a taken country, a shared one or a change.

**No un-choosing**: nothing in the lobby posts the command with no country (a click on sea or unowned land is not handed to the lobby at all), and Execute stops on a country of nought (record). A player changes country by clicking another. `CClearAllControllersCommand` exists as a class; no caller of it was looked for.

**What each screen shows after the command runs** (`CGameSetup::OnPlayerCountryChanged`, `0x314100`, called from Execute's tail on every machine):

- **every machine**: that player's row - `player_shield` the country, `name` "player (Country)";
- **the chooser's machine only**: the provinces its previous country owns lose the selected mark and **the provinces the new one owns get it** (`CMapProvince +0xC` `is_selected`, which lifts the province's colour), the map's colours redrawn - the chosen country is lit; `CGameSetup +0x968` remembers it, and StartGame takes the mark off at launch;
- **the chooser's machine only**: the `singleplayer` panel (`FINDINGS-frontend.md` B.5), which is built from **the local player's** record alone (Update matches the human's id with `+0x42C`). **Another player's country never fills the panel**: what a player sees of the others is their rows.

No chat line is written when a country is chosen.

## 3. What is the host's alone, and what a client sees

| control | on a client | how |
| --- | --- | --- |
| the four tabs `newgame_tab`, `savedgame_tab`, `scenario_tab`, `cgm_tab` | **greyed** | Show: button slot 47 (disable) for each on mode 2, slot 46 otherwise |
| bookmark rows (`bookmark`) | **greyed** (state 3; the look *inferred*, record) | BuildBookmarkLists, for both lists, where the mode is neither 0 nor 1 |
| save rows | unreachable: the Saved Games tab is greyed and the lobby opens on Historical Start | no test of their own |
| `option_window`: `difficulty_prev/next`, `arcade_prev/next` | **greyed** | `CGameSetup_AttachOptionButtons` on mode 2 (record) |
| `option_window`: the five areas' arrows | **usable** - they are the player's own automation | never greyed; written to the local player record, not sent (record) |
| `victoryconditions_button` | as for anyone: enabled with no save loaded where the local player's country leads its faction | Update, every frame; no mode test |
| `play_button` | **greyed** | Update: enabled only where CanStart holds **and** `may_post_commands` (section 4) |
| `back_button` | usable | section 6 |
| the map, the shortcut shields, the players' shields, the chat | usable | |

"Greyed" is the button's disabled state (slots 46 / 47 / 48, `FINDINGS-frontend.md` C.4): drawn disabled and not pressable.

**What a client sees when the host changes something** - each is a command the host posts and every machine executes:

| the host | command | every machine's screen |
| --- | --- | --- |
| clicks a bookmark | CSelectBookmark, then **CSetHistoryDate posted by the host alone** (`SelectBookmark` posts it only where `may_post_commands`) | `CGameSetup::SelectBookmark` runs everywhere: the two chat lines (name in colour, description), the shortcut shields, `year_label`, the row's frame; the date command then moves every machine's world |
| changes difficulty or game mode | CSetGamePlayOptions | the state's two values written and the options panel drawn again (record). **No chat line on the clients**: OPTION_CHANGED is written by the pressing machine's own code (section 5) |
| changes an area's arrow | none | nothing: local to the host |
| chooses victory conditions | VictoryConditions_PostChosen, **at Play**, only where `may_post_commands` | not read |
| chooses a save | CClearBookmark, then the transfer | below |
| leaves a loaded save for Historical Start | CResetGame | `CGameSetup::RevertToStartDate` everywhere, chat **REVERT_SAVE_CAL** (record) |

**A save is sent in the lobby, the moment its row is chosen** - not at Play:

1. **Host** (`OnSaveRowChecked` -> `BeginSaveTransfer`, record): the file read, compressed and checksummed; chat **TRANSERING_SAVE** "Savegame transfer started..."; **one transfer made for each row of `multiplayer_list`** (`CHumanItem_SetTransfer`, `0x3097E0`, which also writes the row's first `save_progress`); load pending.
2. **Client** (`CGameSetup::OnTransferStarted`, `0x312580`): the transfer's file name becomes its chosen save; **its own `save games/` file of that name is checksummed, and where the checksum is the host's the bytes are not sent** - chat **LOADING_LOCAL_SAVE** "Loading local savegame copy..."; otherwise chat **TRANSERING_SAVE**. Load pending.
3. **Meanwhile**: `save_progress` on the rows moves (`CGameSetup::OnTransferProgress`, `0x312030`, *inferred*: yellow under way, green done). On the host, Play is greyed while the load is pending (CanStart); the tabs do nothing while it is. The client's screen is otherwise unchanged - no dialog, no bar but the rows' text.
4. **Client, transfer complete** (Update's client arm): with a matching local copy, that file is loaded; otherwise the received bytes are parsed, **the file is written to the client's own `save games/`** (log `failed to store game locally` on failure), and chat **SAVE_TRANSFER_DONE** "Savegame transfer done."; either way the options panel is filled from the save, every country refreshed and the map redrawn - the save's world is on the client's map.
5. **Host, every row's transfer complete** (Update's server arm): the save loaded once, chat SAVE_TRANSFER_DONE and **SAVE_LOADED** "Save Game Loaded...", load pending cleared. **The host does not load the save until every client has it.** In single player Update then chooses the save's `player` (B.3); **in multiplayer nobody's country is chosen by the load**.

**A player who joins after a save was chosen is sent it** (OnPlayerAdded's tail, on the host: a transfer for the new row, TRANSERING_SAVE again, load pending again; the host does not parse a second time).

## 4. Play

**Whether `play_button` is enabled**, each frame (Update, VA `0x70BE8D`..`0x70BFBA`):

- **ordinarily**: `CGameSetup_CanStart` **and** `may_post_commands` - so **greyed on every client, always**;
- where the session's `lobby_reopened` (+0x236) is set - a lobby re-entered for a hot-join - CanStart alone.

**CanStart** (`0x30DF80`, record, its head read again) fails, in order: a load pending; the victory conditions window open; no human; **any human with no country, or with a country owning no province**; then, on the host or in single player, the tab's own condition (B.6). **It does not count the players.**

**The tooltip** (`CGameSetup::GetElementTooltip`, record, read again) gives the first of:

1. **MP_FEW_PLAYERS** "You need more than one player to start a game." - where the mode is not 0 and the state has fewer than two humans;
2. **NOT_SELECT** "All players must select a country." - the first human with no country;
3. **NOT_EXIST** "$TAG$ does not exist at this time." - the first human whose country owns no province, TAG the country's name;
4. CanStart's reason, **CANT_START_REASON_SELECT_BOOKMARK** / `_CGM` / `_SCENARIO` / `_SAVE_GAME`; empty where Play may be pressed.

The reason is shown nowhere else: Play's tooltip is the only place. A client hovering its greyed Play gets the same routine's answer.

**Pressing Play on the host** (`CGameSetup::OnPlay`, record): exactly single player's - the victory conditions window hidden, for a new game the seed taken, the options panel hidden and its choices posted, the victory conditions posted, then **CSetRandomSeed and CLobbyStartGame**. No test of the mode and none of the player count.

**When the game starts**, on every machine alike: CLobbyStartGame's Execute sets the front end's start request; that machine's next lobby frame, where CanStart still holds - on a client it holds as soon as every human has a country with land - runs `CGameSetup_StartGame` (`0x30E9B0`): the lit country's provinces un-marked, the victory conditions checked once, **in multiplayer the session kept** (single player makes a fresh one named `Launch`), the launch flag set, and the front end's LaunchGame installs the in-game screen. **A client's screen shows nothing in between** - no line, no dialog; the lobby is replaced by the loading of the game.

`CGameSetup::PostStart` (`0x311EA0`, CLobbyInterface slot 8) posts the seed and CLobbyStartGame with no test at all; its caller was not found (*inferred* the online start).

## 5. The chat

**The pieces**: the list `chatlog`, rows `lobby_chat_text` with the text box `messagelogtext` (`FINDINGS-frontend.md` and the record's `CGameSetup::AddChatLine`: wrapped to the box's width less 10, a row a line, the oldest row dropped past the buffer's limit, scrolled to the end); the edit box **`lobby_chat_edit`**, **hidden in single player and shown in multiplayer** (Prepare and Show); and `frontend_chat_bg`, named by no code.

**Typing** (`CGameSetup::OnChatEditEnter`, `0x30DD00`, the box's listener, told on Enter - `FINDINGS-editbox.md`): the text with white space taken off both ends; **an empty line does nothing**; otherwise a chat-line command is posted with the text and the player's name, and **the box is emptied**. No slash commands, no private messages, no length rule beyond the edit box's own (250 bytes, and the seven bytes its font refuses).

**A player's line** is drawn **`§Y`name`§!: `text** - the name yellow, then the colour restored, a colon and a space (`ChatPlayerMessage_GetText`, `0x6C9830`). The typist sees their own line the same way, when the command comes back.

**Two ways a line gets into `chatlog`**, and they decide who sees it:

- **a chat-line command** (`ChatLineCommand_Construct`, `0x6CB210`; a command class the RTTI export does not name): executed on every machine, it hands the message to the lobby's chat buffer (`CGameSetup +0x3BC`), whose observer calls AddChatLine. **Everyone sees these.**
- **AddChatLine called directly**: only the machine whose code ran. Many of these run inside a command's Execute and so appear everywhere anyway.

| line | key and text | parameters | who sees it |
| --- | --- | --- | --- |
| a typed line | - | name, text | everyone (command) |
| entering | **CONNECTED** "Connected." | | that machine |
| a player added | **PLR_CONNECT** "Player §Y$NAME$§W joined the game." | NAME | everyone (CAddPlayer's Execute) - the joiner's own lobby included |
| a player removed | **PLR_DISC** "Player §Y$NAME$§W left the game." | NAME | everyone left |
| kicked | **PLAYER_KICKED** "$NAME$ was kicked by the host." | NAME | everyone (command) |
| banned | **PLAYER_BANNED** "$NAME$ was banned by the host." | NAME | everyone (command) |
| a connection lost | **LOST_PLR** "Lost Player" + a space + the name (no parameter: joined on) | | everyone (command, posted by the host) |
| thrown out | **YOUKICKED** "You were kicked by the host for your evil deeds!" | | the thrown-out machine |
| host gone | **SERVER_LOST** "The server was lost." | | each client |
| bookmark chosen | the bookmark's name in colour, then its description (B.2) | | everyone (SelectBookmark runs everywhere) |
| option changed | **OPTION_CHANGED** "$FROM$ has changed to: $TO$" | FROM, TO | the machine that pressed the arrow (*inferred*: the record has it call AddChatLine directly) |
| save chosen | **TRANSERING_SAVE** "Savegame transfer started..." | | the host; each client that needs the bytes |
| | **LOADING_LOCAL_SAVE** "Loading local savegame copy..." | | each client that already has the file |
| save arrived | **SAVE_TRANSFER_DONE** "Savegame transfer done." | | the host; each client that received bytes |
| save loaded | **SAVE_LOADED** "Save Game Loaded..." | | the host |
| back to the start date | **REVERT_SAVE_CAL** "Reverting to default database." | | everyone (record) |

**There is no line for a country chosen, for Play, or for victory conditions.** Keys [mod: localisation]; the texts above are Their Finest Hour's.

## 6. Leaving

**Back** (`CGameSetup::OnBack`, `0x30D010`, *inferred* in its online arm), host and client alike:

1. a **CAddPlayer(remove)** for its own player posted, and the commands pumped once;
2. the lobby taken off the session's observers; the channel's slot 3 with 3000 (a flush with a wait, *inferred*);
3. the options window hidden and its choices posted;
4. **in multiplayer, the startup session put back** (`CGameSetup_RestoreInitialSession`, `0x30E3D0`) - the game's session is deleted;
5. `ResetGameStateToStartDate(true)` - the world back to the start date, the players cleared;
6. **view 0, the main menu** [exe] - not view 4, the multiplayer menu the player came from. (View 5 with the online link.)

| who leaves, how | the leaver | the others |
| --- | --- | --- |
| a client, by Back | main menu | the row goes, PLR_DISC, `num_players` |
| a client drops | - | the host's `OnSessionInfo` event 5 posts a CAddPlayer(remove) and the chat line "Lost Player name": every machine drops the row and says PLR_DISC as well |
| a client is kicked or banned | event 9: chat YOUKICKED, and **a `DefaultInfoDialog` saying YOUKICKED, or BANNED** ("You have been banned from this game") where the session's state is 9; **the dialog's button is given the lobby's Back handler**, so answering it runs Back -> main menu (*inferred* which button: the dialog was not read) | the row goes, PLR_DISC, and PLAYER_KICKED or PLAYER_BANNED |
| the host, by Back | main menu | below |
| the host drops | - | below |

**The host gone** (`CGameSetup::OnSessionInfo`, `0x30C360`, event 3, *inferred* as to the event's meaning): each client's chat says **SERVER_LOST** once (the lobby's `connected`, +0x180, goes to 0 and guards it) - **and nothing else happens**. No dialog, no change of view: the client stays in a dead lobby with the rows as they were until it presses Back. Whether the host's own CAddPlayer(remove) reaches the clients before the session is deleted - so that they also see PLR_DISC for the host - was not established.

**Events the lobby ignores**: 0 and 8. Any other is logged `Unhandled network notification <n>`.

## 7. What looks wrong and is the original's

1. Play's tooltip says "You need more than one player to start a game." while Play is enabled and works: nothing but the tooltip counts the players.
2. Two players may choose the same country, silently.
3. A country cannot be un-chosen.
4. A client can open the victory conditions window where its country leads a faction, though only the host's choice is posted at Play.
5. The host's Back, or its loss, leaves the clients sitting in the lobby with one chat line.
6. Back from a multiplayer lobby goes to the main menu, not the multiplayer menu.
7. A kicked player is told so twice, in the chat and in a dialog; a banned one reads YOUKICKED in the chat and BANNED in the dialog.
8. A dropped player gets two lines on every screen: "Lost Player X" and "Player X left the game."
9. "Lost Player" is joined to the name by hand, where every other line uses a `$NAME$` parameter.
10. `save_progress` keeps its last text after the transfer.
11. A save is sent to everyone the moment the host ticks its row, and again for every other row it ticks.
12. A client that has a file of the same name and checksum loads its own copy; one that has not is given the file, which is written into its `save games/` unasked.
13. OPTION_CHANGED is seen only by the player who pressed the arrow; the others' panel changes silently.
14. No chat line says who chose which country.
15. `num_players` shows the file's "Number of Players: 5" until the first row is added (in practice at once).
16. The `multiplayer` box, with one row, is part of the single-player lobby too (*inferred*).
17. The chat keeps `TRANSERING_SAVE`'s spelling.

## 8. Not established

- **How a joining client learns of the players already there** and of their countries, the chosen bookmark and the date: the commands that would replay them were not traced (the session's join). The rows a client shows are whatever CAddPlayer commands it executes.
- Whether the name test of `FINDINGS-multiplayermenu.md` (NAME_TAKEN) is the only one; the lobby has none.
- The list's add slot's flag, and so the order of rows for certain.
- That the button's slot 53 sets the shield's flag; what state 3 and the disabled state look like.
- Who calls `OnTransferProgress`, how often, and whether a client sees other clients' rows move.
- The transfer object's slots 10 to 13, `0xAD34A0`, `0xAD35C0`; the online-link test in front of a late joiner's transfer.
- The channel's slots 3 and 16 and the session's `0xA8AC50` (the lost connections) and `0xA8AD10` (ban).
- The `DefaultInfoDialog` (`0x63D4B0`), its buttons and its title.
- Whether a client's victory conditions window posts anything (`CChooseVictoryConditionsCommand`'s constructor at VA `0x5536D0` has callers that were not looked at).
- `CClearAllControllersCommand`'s caller.
- `CAddPlayer +0x5D`, 0 at every lobby call.
- `0x3191C0`, called first thing by Update; the chat buffer's row limit (set by the constructor); `PostStart`'s caller.
- The chat-line command's and the two message classes' real names (no RTTI record in the export).
- The whole online-link arm of Prepare, Update, OnPlay, OnBack and OnSessionInfo.
- What a hot-join's re-entered lobby (`lobby_reopened`) does beyond enabling Play without the authority test.

## 9. Addresses

| rva | name | confidence |
| --- | --- | --- |
| `0x3095E0` | CHumanItem_Construct | confirmed |
| `0x309700` | CHumanItem::~CHumanItem | confirmed |
| `0x3097E0` | CHumanItem_SetTransfer | confirmed |
| `0x309B40` | CHumanItem::OnShieldClicked | inferred |
| `0x308190` | CGameSetup_AnnounceLocalPlayer | confirmed |
| `0x30C360` | CGameSetup::OnSessionInfo (table at +8, slot 1) | inferred |
| `0x30D010` | CGameSetup::OnBack (revised) | inferred |
| `0x30DD00` | CGameSetup::OnChatEditEnter | confirmed |
| `0x30E3D0` | CGameSetup_RestoreInitialSession | confirmed |
| `0x311500` | CGameSetup_KickPlayer | confirmed |
| `0x311840` | CGameSetup::OnKickButton | confirmed |
| `0x3119C0` | CGameSetup_BanPlayer | confirmed |
| `0x311D20` | CGameSetup::OnBanButton | confirmed |
| `0x311EA0` | CGameSetup::PostStart (table at +0xC, slot 8) | inferred |
| `0x312030` | CGameSetup::OnTransferProgress (table at +0x3C, slot 8) | inferred |
| `0x312580` | CGameSetup::OnTransferStarted (table at +0x3C, slot 9) | confirmed |
| `0x312C00` | CGameSetup::GetTransferSession (table at +0x3C, slot 10) | confirmed |
| `0x312C10` | CGameSetup::OnPlayerAdded (table at +0xC, slot 9) | confirmed |
| `0x313910` | CGameSetup::OnPlayerRemoved (table at +0xC, slot 10) | confirmed |
| `0x314100` | CGameSetup::OnPlayerCountryChanged (table at +0xC, slot 11) | confirmed |
| `0x2D6770` | CAddPlayer_Construct | confirmed |
| `0x2D6890` | CAddPlayer::Execute (slot 6) | inferred |
| `0x6CB210` | ChatLineCommand_Construct | inferred |
| `0x6CB500` | ChatLineCommand_Execute | inferred |
| `0x6C9830` | ChatPlayerMessage_GetText | confirmed |

Read again and unchanged: `CGameSetup::Prepare`, `Show`, `Update`, `BuildBookmarkLists`, `OnProvinceClicked`, `GetElementTooltip`, `OnPlay`, `CGameSetup_CanStart`, `CGameSetup_StartGame` (each in brief, for its multiplayer tests).

Struct declared: `CHumanItem` (0xD0: `window` +0x20, `human` +0x28, `transfer` +0x78, `shield_observer` +0x80). `CGameSetup` gains `kick_observer` +0x90, `ban_observer` +0xE0, `connected` +0x180, `chat_buffer` +0x3BC, `chat_observer` +0x3E0, `chat_edit_observer` +0x3F0, `save_data` +0x6B8, `online_link` +0x6C8, `incoming_transfer` +0x6D8, `lit_country` +0x968; `CHuman` gains `name` +0; `Session` gains `local_human_id` +0x6C.
