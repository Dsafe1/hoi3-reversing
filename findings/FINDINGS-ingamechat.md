# The chat during play

Read 2026-11-20, statically, off the listings (no Ghidra, nothing set against a running game), for OpenHOI3. Fragment `ingamechat.json`. Addresses are rvas unless marked VA (VA = rva + 0x400000); only valid for this build. **[exe]** hardcoded in the executable, **[mod: file]** what a file may change. `confirmed` unless marked *likely* or *inferred*. The texts quoted are Their Finest Hour's.

**There are two chats in play, and the one `menubar.gui` declares is not the one players type into.**

| | the menubar chat | the channel chat |
| --- | --- | --- |
| declared in | `interface/menubar.gui`: `chat_window`, `chat_entry`, `chat_entry_other`, `chat_list`, `player_entry`, `short_player_entry`, `chat_shield_*` | `interface/chat.gui`: `chat_window`, `chat_item`, `chat_inbox_window`, `channel_window`, `user_item` |
| code | `CInGameIdler` | an object with no RTTI name, here **BaseChat** (0x120 bytes, table VA `0x15FF524`), one in the global at VA `0x1A857E8` |
| typing | `chat_window` with `chat_message`: **never shown, dead** | `chat_window` with `chat_input`: **the chat players use** |
| showing | `chat_list` rows top left and a CHATMESSAGE message: **live** | its own `chat` list inside its window |
| carried by | chat-line commands to a chat buffer | its own commands (token names `chat_message`, `chat_user_joined`, ...) |
| single player | the buffer and `chat_list` exist; nothing writes to them | **not made** |

Both files declare a window called `chat_window`. The string is one address (VA `0x15CDB7C`) with 24 references: 22 in `CInGameIdler` look it up as a child of `menubar`, 2 in BaseChat (VA `0xA927AD`, `0xA9333A`) look it up as a top-level type through the gui factory - so the two never meet [mod: both files].

**Most of the channel chat was read in filtered listings** (calls, compares, strings); the fragment's `evidence` says "brief listing" where so, and section 9 lists what was not read.

## 1. Opening and closing

**The channel chat** [exe unless marked]:

- **Made** by `CInGameIdler::Update` (VA `0x65627D`..`0x65644A`) on the first frame where `CInGameIdler +0x68` (multiplayer) is set and the global is null, through `BaseChat_Create` (`0x694D20`). **In single player it is never made**: no window, no icon, no key.
- **As made, it is closed**: `chat_window` hidden and `chat_inbox_window` shown (VA `0x6563D6`..`0x6563ED`). The inbox is the "chat icon" `cgm.gui`'s comment means: a window at (9, 67) from the upper left with one button, `open`, sprite `GFX_chat_message_alert` [mod: chat.gui, chat.gfx].
- **Opens**: a click on `open` (`BaseChat_Open`, `0x6932A0`), or **Tab** while the window is hidden (`BaseChat_HandleInput`, VA `0xA951FF`..`0xA95219`: key event, code 9). Opening hides the inbox, clears the current channel's unread mark and fills the three lists again.
- **Closes**: the `close` button (`BaseChat_Close`, `0x6932E0`), whose shortcut is **TAB** [mod: chat.gui]; or **Escape** while the window is shown (VA `0xA952BC`). Closing shows the inbox again. Enter does not close it.
- **Tab while open** is taken by the chat's own routine first as completion or, with Ctrl, as "next channel" (section 3). Whether the `close` button's TAB shortcut then also fires was not established: the order of this routine against the interface's own input pass was not read.
- **Pause, map keys**: opening does not pause and posts nothing. Keys the chat's routine takes are marked handled; keys typed into `chat_input` are consumed by the edit box as `FINDINGS-editbox.md` has it. Nothing else blocks the map (*inferred*: no test of the chat was found in `CInGameIdler_HandleInput`'s record, and the chat sets no flag the screen reads).
- **The icon** (`BaseChat_Update`, `0x6935F0`, *inferred*): the `open` button shows frame 1; frame 2 while a channel the player is in has unread lines; and with the alert byte (+0x106) set it blinks between 1 and 2 with a period of about a second. Who sets the alert was not read.

**The menubar chat's window**: `CInGameIdler::Enter` shows `menubar` and then hides its `chat_window` (VA `0x66025C`); `ReloadMenubar` does the same (VA `0x65949D`). **No instruction shows it again.** Negative, and what produced it: all 22 `CInGameIdler` references to the name were read (close, the per-frame raise, the observers' registration, the five buttons twice, two hides, two tests in `ShowCombatView`, two in the Enter handler) and none calls Show; the menubar's own Show is called twice, both in Enter, both before the hide (scan of all 124 loads of `+0x134C`); no code gives `chat_message` the keyboard (the word stores at `+0x40` in the screen's code are the console's and the save dialog's). Positive control: the same census finds the two hides. So `closebutton`'s ESCAPE shortcut, the four recipient buttons and `chat_message` are unreachable.

`UpdateTutorialAndAuxWindows` raises `chat_window` every frame it is shown (VA `0x64FCDC`..`0x64FD3A`) - which is never.

## 2. Recipients

**In the channel chat a line goes to a channel**, not to chosen players:

- **Five channels**, made by the constructor (`0x692780`): **CHAT_CHANNEL_GENERAL** "General", then **CHAT_AXIS** "Axis", **CHAT_ALLIES** "Allies", **CHAT_COMINTERN** "Comintern", **CHAT_NEUTRAL** "Neutral" [mod: localisation; the five and their order exe].
- **The faction channel follows the player's country** (`CInGameIdler_UpdateChat`, `0x2554C0`, *inferred*): each frame the local country's faction is compared with the one last seen; on a change the player is put in channel 1, 2 or 3 where the faction's tag is `axis`, `allies` or `comintern`, and **in channel 4, Neutral, for no faction or any other tag** [exe: the three tags]. Nothing in that routine takes him out of the former faction's channel (the commands' Execute bodies were not read).
- **Ctrl+Tab** (Shift for the other way) makes the next channel the player is in the current one; a line typed goes to the current channel.
- **`/whisper <username> <message>`** and **`/reply <message>`** are the private line; `/create <channel name>`, `/invite <username>`, `/kick <username>`, `/ban` make and police further channels (CHAT_BETWEEN_X_AND_Y "Chat between $X$ and $Y$" names one). The eleven commands [exe]: `/slap`, `/me`, `/whisper`, `/reply`, `/invite`, `/create`, `/ban`, `/kick`, `/roll`, `/?`, `/help`. **Their bodies were not read**; the error texts they raise are in section 5.
- **The `users` list** shows a row `user_item` a user, with `whisper` and `kick` buttons and **`country_icon`, the flag of that player's country** (`BaseChat_UserRowFlagCallback`, `0x255380`, *inferred*).

**The menubar design, which is dead** (all `confirmed` as code, none of it reachable):

- A row per human player was meant - menubar.gui's `player_entry` (a `name` button, a `shield` checkbox on `GFX_minishield_greydown`, a `minishield_strikeout` icon) or `short_player_entry` - laid out from `chat_shield_start` by `chat_shield_offset` or `chat_shield_offset_long`. **None of those five names is in the image**, and the list the rows would live in (`CInGameIdler +0x1320`) is only ever zeroed, cleared and read. So nothing is drawn at `chat_shield_start`, and which offset was meant for which case cannot be read out of this build.
- In that design **a checked shield is a struck-out player**: unchecked = recipient, `minishield_strikeout` hidden.
- `none` (`0x275200`): everyone struck out. `all` (`0x24D260`): everyone a recipient. `allies` (`0x24CCE0`): the same country, or an alliance (the diplomacy status' +0x14 not null), or the same valid faction. `enemies` (`0x24CFB0`, text CHAT_FOES): the same country, or at war (status +0x20 not null). A click on a player's `name` toggles him.
- `none`, `allies` and `enemies` walk the humans and the rows side by side and stop when either runs out, so **with no rows they do nothing at all**; `all` sets every human's `CHuman +0x29` in a loop of its own. No reader of that byte was found.
- **No default selection** is set when the window opens; none was needed, see section 3.

## 3. Sending

**Channel chat, Enter in `chat_input`** (`BaseChat_OnInputEnter`, `0x6942B0`, *inferred*):

1. The text is trimmed of white space. **An empty line does nothing.**
2. A line starting `/` goes to the slash commands; an unknown one writes **CHAT_ERROR_UNKNOWNSLASH** into the current channel on this machine only.
3. Any other line is posted as a command (0x6C bytes, `0x6988B0`) with the local user's id, the current channel's id and the text.
4. **The box is emptied and the window stays open.** The line goes into an input history; **Up** and **Down** recall sent lines.
5. **Tab** completes the last word: a lone word starting `/` to a slash command, any other to a user's name plus a space.
6. With the box empty and a last whisperer known, a key puts `/reply ` in the box once (which key was not settled).

Length: the edit box's own 250 bytes and its refused bytes (`FINDINGS-editbox.md`); `chat_input`'s font is `chat_input_font` [mod: chat.gui, chatfonts.gfx], so whether the seven effect bytes are refused depends on that font's `effect`. No further rule was seen in the Enter routine. Whether the sender sees its own line only when the command comes back was not read.

**Menubar chat, Enter in `chat_message`** (`CInGameIdler::OnChatEditEnter`, `0x274730`, unreachable): trimmed, empty does nothing; the recipients are the players whose shield is unchecked; **to_all = recipients >= rows, which with no rows is 0 >= 0, always true**; a country chat message (text, the sender's name, the recipients' names, to_all, the sender's country tag and name) goes out in a chat-line command to every machine; the box is emptied, the window left open. **Privacy would have been the receiver's doing**: the command reaches everyone and `OnChatMessage` drops a line that is not to all unless the local player sent it or is named in it.

## 4. Showing

**In the channel chat** (*inferred*): each channel keeps its own lines; `BaseChat_RebuildList` (`0x693B90`) fills the `chat` list box (225 x 330, with a scrollbar [mod: chat.gui]) with a `chat_item` row for every wrapped piece of every line of the current channel, wrapped to the `text` box's width. A line carries the local clock, `[%H:%M]`, and its sender: **CHAT_SYSTEM** "System" for a system line, the user's name, or **CHAT_WHISPER_TO** "To $NAME$" for one's own whisper. The exact order of clock and name, the row limit and any colour were not read. A line arriving in a channel that is not on screen sets its unread mark.

**In `chat_list`** (`CInGameIdler::OnChatMessage`, `0x273690`) - every chat-line command executed while the screen listens:

- **Where**: `chat_list` is a list box at (5, 120), 265 x 246, in `menubar` [mod: menubar.gui]; while units are selected the screen moves it to x 350 (`FINDINGS-selection.md`). Rows are **added at the end**: newest at the bottom.
- **Which window**: the first wrapped line of a message is a **`chat_entry`**; every further line of the same message a **`chat_entry_other`** (the same two texts, no shield). The wrap is `CGameSetup::AddChatLine`'s: the `text` box's width less 10 [exe], its font.
- **`shield`** (an icon on `GFX_flag_tiny`): the flag of the message's country - the sender's.
- **`text`**: the line. **`text_shadow`**: `§b` + the line + `§W` [exe].
- **The text** (`ChatCountryMessage_GetText`, `0x6CA520`): **`Name (Country): text`**; **`Name (Country)*: text`** for a line not to all [exe]. No colour code is added; the lobby's player line, `§Y`name`§!: `text, is a different message class.
- **How many, how long** (`CInGameIdler_ExpireChatRows`, `0x274E20`, every frame): at most **10 rows** [exe, set in Enter]; the oldest row is taken away when there are more, **or when more than 10 whole seconds have passed since the last line arrived or the last row went** - so one row every 11 seconds, oldest first. No fade.
- **The message**: one message of type **CHATMESSAGE** per chat message (not per row), with **TEXT** the whole text, raised through the ordinary message handler - so its popup and log settings apply [mod: messagetypes.txt; CHATMESSAGE_LOG is `$TEXT$`, CHATMESSAGE_3 `$TEXT$`]. `FINDINGS-messagegoto.md` has it with no goto.
- **When the screen listens**: `CInGameIdler_UpdateOpenView` registers the screen with its chat buffer once - on the first frame in single player, and in multiplayer only once the in-game lobby (`CInGameIdler +0x1CD0`, a `CIngameLobby` given the same buffer) reports itself done.

## 5. Lines the game writes in play

**Into `chat_list` and CHATMESSAGE** (chat-line commands; every machine):

| line | key and text | when | confidence |
| --- | --- | --- | --- |
| lag, pause | **LAG_PAUSE** "$PLAYER$ is lagging behind, pausing game." | `CClientPingCommand::Execute` (`0x2DAA30`) on the authority: a client more than 10 days behind; the game's pause is toggled | *inferred* (the day arithmetic read in outline) |
| lag, slower | **LAG_DECREASE_SPEED** "$PLAYER$ is lagging behind, decreasing speed." | the same, more than 5 days behind; speed decreased | *inferred* |
| player lost | the text of the lost-player dialog: **PLAYER_LOST_DESC** "Player(s) $playername$ disconnected. Choose your action." | `CMultiplayerHandler::OnSessionInfo` (`0x245900`), event 5 | *likely* (which text is rendered) |
| typed in the in-game lobby | the lobby's own player line | `CIngameLobby`'s `lobby_chat_edit` (VA `0x695E6E`) | *inferred*: the call was found, the routine not read |

PLAYER is the lagging player's name + ` (@` + his tag + `)`, so the line draws his flag. Each lag line is signed by the authority's own player and country, to all, and is written at most once a game day; the first day over the threshold only arms it.

**Not chat lines in play**: a lost player raises the window `player_lost_window` (Title PLAYER_LOST_TITLE, `continue_button` / `save_button` / `quit_button`) and pauses the game; a lost host and a hot-join request (SERVER_LOST_TITLE / SERVER_LOST_DESC, INITIAL_HOTJOIN_REQUEST / HOTJOIN_TITLE in a `DefaultDialog`) are dialogs in the same handler, not read. **None of the front-end lobby's keys - PLR_CONNECT, PLR_DISC, LOST_PLR, PLAYER_KICKED, PLAYER_BANNED, YOUKICKED, SERVER_LOST, CONNECTED - is referenced by the in-play screen's code**; each has only its lobby references (string cross-references; `SERVER_LOST` and `CONNECTED` also in `CIngameLobby`, which writes them into its own `chatlog`). No line for pausing or changing speed by hand was found (negative from the callers of `ChatLineCommand_Construct`: ten, of which five are the front-end lobby's and the other five the ones above plus the dead Enter handler).

**Into the channel chat** (strings of the chat's own code; when each is raised was not read): CHAT_USERJOINEDCHANNEL "$NAME$ joined channel", CHAT_USERLEFTCHANNEL "$NAME$ left channel", CHAT_USERDISCONNECTED "$NAME$ disconnected", CHAT_USERWASBANNED "$NAME$ was kicked by $OP$", CHAT_YOUWEREBANNED "You were kicked by $OP$ from $CHANNEL$", CHAT_SLAP, CHAT_ROLL "$USER$ rolls a d$DIE$, Computer says '$NUMBER$'" with CHAT_YES / CHAT_NO, and the errors CHAT_ERROR_UNKNOWNSLASH, _UNKNOWNUSER, _UNKNOWNCHANNELUSER, _SLAP_MISSINGARG, _ME_MISSINGARG, _CREATE_MISSINGARG, _INVITE_MISSINGARG, _INVITE_ALREADYTHERE, _KICK_MISSINGARG, _KICK_NOTOPERATOR, _KICK_NOTTHERE, _WHISPER_MISSINGARG, _REPLY_MISSINGARG, _REPLY_MISSINGUSER. `CHAT_ERROR_INVITE_NOTOPERATOR` is in the localisation and not in the image.

## 6. `tfh/interface/chat.gui`

**It is the in-play multiplayer chat's file, and live.** `BaseChat_Build` (`0x693300`) and the routines beside it look up, by name: `chat_window` (with `close`, `channels`, `chat`, `users`, `chat_input`), `chat_inbox_window` (`open`), `chat_item` (`text`), `channel_window` (`select`, `name`, `close`), `user_item` (`name`, `whisper`, `kick`, `country_icon`). Named by no code: `chatback` and `chat_player_entry` (plain icons). It is not the metaserver's: that chat is `CChatMessagehandler` with `MetaserverChatWindow`, `ChatSendButton`, `ChatWindowEditBox`, `ChatMemberText` (VA `0x7C6D8F`..`0x7C812E`, not read). Nothing in the front end uses chat.gui (its only maker is `CInGameIdler::Update`).

## 7. What looks wrong and is the original's

1. `menubar.gui`'s `chat_window` - background, four recipient buttons, close button with ESCAPE, `chat_message` - is built, wired and hidden, and nothing ever shows it.
2. `player_entry`, `short_player_entry`, `chat_shield_start`, `chat_shield_offset`, `chat_shield_offset_long` are declared and named by no code; the recipient row list is never filled.
3. `none`, `allies` and `enemies` would do nothing even if the window were shown; `all` alone writes its bytes, which nothing reads.
4. A line from the dead window would always go to all: 0 recipients >= 0 rows.
5. Had the recipients worked, a private line would still be sent to every machine and only hidden by the receiver.
6. The star means opposite things in two message classes: `*: ` marks a private country line, `*> ` a public addressed line.
7. The lag lines are signed with the host's name and country, as if the host had typed them.
8. LAG_PAUSE toggles the pause (*inferred* from the slot's recorded name): a lag on an already paused game would unpause it.
9. A lost player is told three ways: a window, a pause, and a chat line reading "Choose your action." on every machine.
10. A row leaves `chat_list` only after more than 10 whole seconds (11), counted from the last arrival or removal, so a burst of ten lines takes 110 seconds to clear.
11. `closebutton` in the dead window and `close` in the live one have different shortcuts (ESCAPE, TAB); the live chat also closes on Escape by its own code.
12. After an interface reload `chat_message` is made again and its Enter listener is not attached again (it is attached once, behind a flag).
13. A player who leaves a faction is put in Neutral; nothing seen takes him out of the old faction's channel (*inferred*).
14. Any faction whose tag is not `axis`, `allies` or `comintern` shares the Neutral channel [mod: a mod's faction].
15. `CHAT_NONE`, `CHAT_FOES`, `CHAT_ALL` and the menubar's use of `CHAT_ALLIES` are localised labels of buttons nobody sees; `CHAT_ERROR_INVITE_NOTOPERATOR` has a text and no code.

## 8. Corrections to the record

- **`ChatLineCommand_Construct` / `ChatLineCommand_Execute`** (`0x6CB210`, `0x6CB500`) and `FINDINGS-multiplayerlobby.md` section 8: "the chat-line command's ... real name (no RTTI record in the export)". The export does name **`CChatBuffer::CWriteToChatBuffer`**, but at a different table (VA `0x15E3FE4`, type 0x149, Execute VA `0xACAF40`); the lobby's command is table VA `0x16024F4`, type 0x14B, token name `chatmessage`. They are two classes; the second was not read. Not changed by the fragment - a hand edit of the comment if wanted.
- **`CInGameIdler_UpdateOpenView`** (`0x251D30`): "Then the chat window (+0x1CD0, +0x134C): not read". Read: +0x1CD0 is the in-game lobby; the tail registers the screen's chat observer and `chat_message`'s Enter listener once. Not changed by the fragment (it adds the fields).
- **`UpdateTutorialAndAuxWindows`** (`0x24FC70`): "shows or hides `chat_window`" - it raises it while shown (window slot 11), nothing more.
- **`FINDINGS-editbox.md`**: "If the chat or console input (`app +0x80`) is open, it takes both kinds of event first" - not confirmed as either in-play chat; the channel chat reads the screen's own event list.
- **`FINDINGS-console.md`**: "the chat box was not read for slash commands" - the channel chat has eleven; none is a console command.
- The player chat message is persistent type 0xCF (token `standardchatmessage`), the system message 0x12D, the addressed message 0x12E, the country message 0x152 (`countrychat`).

## 9. Not established

- **Every slash command's body** (`0x6950F0` and `0x695B80`..`0x696D40`), and so `/whisper`, `/me`, `/roll`, `/create`, `/invite`, `/kick`, `/ban` in detail, including who may kick.
- **The channel chat's commands**: their Execute bodies, the sync on joining (`chat_sync`, `chat_request_sync`), who sets `synced` (+0xDC) and `alert` (+0x106), and whether a sender sees its own line before the command returns.
- **The channel chat's line format in full**: order of clock and name, colours, the row limit of `chat`, how `channels` and `users` are laid out and what a click on `select`, `close`, `whisper` and `kick` does (`0x6937F0`, `0x693A10`, `0x697800`..`0x6986F4`).
- **Whether Tab on `close` also fires** after the chat's own Tab handling, and the order of the chat's input routine against the interface's input pass (`0x251B00`).
- Which key prefills `/reply `, and the Backspace arm of `BaseChat_HandleInput`.
- `BaseChat_Create`'s second and fourth arguments (the screen's slots 16 and 17).
- **`CMultiplayerHandler::OnSessionInfo`** beyond event 5; the day arithmetic of `CClientPingCommand::Execute`; that screen slot 27 toggles rather than sets the pause.
- **`CIngameLobby`** (`0x2915D0`): its chat, its `chatlog`, what its +0xF5 means exactly, and whether its typed lines reach players already in the game.
- Why the lag lines find the chat buffer by a fixed id pair (VA `0x17103FC`) while the dead Enter handler uses `CInGameIdler +0x1CE4`; that they are the same buffer is *inferred*.
- A reader of `CHuman +0x29`: none in the functions read; no image-wide scan was made.
- Nothing here was set against a running multiplayer game. Screenshots that would settle the most: the inbox icon and the open window in a two-player game; a lag line in `chat_list`; Tab and Ctrl+Tab in the open window.

## 10. Addresses

| rva | name | confidence | one line |
| --- | --- | --- | --- |
| `0x24CBA0` | CInGameIdler::CloseChatWindow | confirmed | `chat_window` `closebutton` handler; never reached |
| `0x24C8C0` | CInGameIdler::ToggleMessageLog | confirmed | `messagelog_window` `closebutton` / `OPENbutton` handler |
| `0x24CCE0` | CInGameIdler::OnChatAlliesButton | confirmed | `allies`: same country, alliance or same faction; no rows, so nothing |
| `0x24CFB0` | CInGameIdler::OnChatEnemiesButton | confirmed | `enemies`: own country or at war; no rows, so nothing |
| `0x24D260` | CInGameIdler::OnChatAllButton | confirmed | `all`: every human's recipient byte set, rows or not |
| `0x275200` | CInGameIdler::OnChatNoneButton | confirmed | `none`: clears per row; no rows, so nothing |
| `0x24D380` | CInGameIdler::OnChatPlayerNameClicked | confirmed | toggles one player's shield; never attached |
| `0x24D5D0` | CInGameIdler::OnChatShieldToggled | confirmed | shows or hides `minishield_strikeout`; never attached |
| `0x273690` | CInGameIdler::OnChatMessage | confirmed | a chat line into `chat_list` rows plus one CHATMESSAGE |
| `0x274730` | CInGameIdler::OnChatEditEnter | confirmed | Enter in `chat_message`; unreachable, its window is never shown |
| `0x274E20` | CInGameIdler_ExpireChatRows | confirmed | oldest row removed after more than 10 whole seconds, or past 10 rows |
| `0x2554C0` | CInGameIdler_UpdateChat | inferred | the in-play chat's frame on the game's side: join, keys, faction channel |
| `0x255380` | BaseChat_UserRowFlagCallback | inferred | a user row's `country_icon` gets the player's flag |
| `0x2DAA30` | CClientPingCommand::Execute | inferred | LAG_PAUSE / LAG_DECREASE_SPEED chat lines (slot 6) |
| `0x245900` | CMultiplayerHandler::OnSessionInfo | inferred | event 5 only: `player_lost_window` and a chat line (slot 1) |
| `0x694D20` | BaseChat_Create | confirmed | makes the 0x120-byte chat object into the global at VA `0x1A857E8` |
| `0x692780` | BaseChat_Construct | confirmed | eleven slash commands, five channels |
| `0x693300` | BaseChat_Build | confirmed | builds `chat_window` and `chat_inbox_window` from chat.gui |
| `0x6932A0` | BaseChat_Open | confirmed | `open` button and Tab |
| `0x6932E0` | BaseChat_Close | confirmed | `close` button (shortcut TAB) |
| `0x6935F0` | BaseChat_Update | inferred | the inbox button's frame and blink |
| `0x6951D0` | BaseChat_HandleInput | inferred | Tab, Escape, Up/Down history, Ctrl+Tab, completion |
| `0x6942B0` | BaseChat_OnInputEnter | inferred | Enter in `chat_input`: slash command or a line to the current channel |
| `0x6971A0` | BaseChat_AddSystemLine | inferred | `[%H:%M]`, CHAT_SYSTEM, unread mark |
| `0x697370` | BaseChat_AddLine | inferred | a user's line, CHAT_WHISPER_TO for one's own whisper |
| `0x693B90` | BaseChat_RebuildList | inferred | fills `chat` with `chat_item` rows |
| `0x6C9A20` | ChatAddressedMessage_Construct | confirmed | text, to_all, sender, recipients |
| `0x6CA260` | ChatCountryMessage_Construct | confirmed | adds the country's tag and name |
| `0x6CA520` | ChatCountryMessage_GetText | confirmed | `Name (Country): text`, `*: ` where not to all |
| `0x6C9FC0` | ChatAddressedMessage_GetText | confirmed | `Name> text` / `Name*> text` |

Struct fields recorded: `CHuman +0x29` chat_recipient; `CInGameIdler` +0x6C8, +0x718, +0x788, +0x7D8, +0x828, +0x878, +0x8C8 (the chat's observers), +0xA30 message_log_toggle_observer, +0x1320 chat_player_rows, +0x1CD0 ingame_lobby, +0x1CE4 chat_buffer, +0x1CE8 chat_observer, +0x1CF8 chat_edit_observer, +0x1D18 chat_observers_attached, +0x1D20 chat_row_timer, +0x1D8A message_log_open, +0x1DEC chat_faction; `BaseChat` (declared, no size) +0x20 session, +0x30 window, +0x34 inbox_window, +0xA4 local_user_id, +0xA8 slash_commands, +0xB8 users, +0xC8 channels, +0xD8 current_channel_id, +0xDC synced, +0xFC history_index, +0x106 alert, +0x108 user_row_callback, +0x11C blink_timer. Slot records: `CClientPingCommand` 6 Execute, `CMultiplayerHandler` 1 OnSessionInfo.

Frontier (rvas): `0x6950F0`, `0x694AB0`, `0x6937F0`, `0x693A10`, `0x6959A0`, `0x694680`, `0x694E00`, `0x694C90`, `0x6988B0`, `0x698DD0`, `0x699010`, `0x699210`, `0x699510`, `0x69A480`, `0x697DC0`, `0x697FA0`, `0x2915D0`, `0x2927E0`, `0x2926F0`, `0x295D00`, `0x295400`, `0x6CAC30`, `0x6CAF40`, `0x2D7F10`, `0x285E10`, `0x251B00`.
