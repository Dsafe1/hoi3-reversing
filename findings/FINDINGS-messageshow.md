# How a message reaches the player

*Read on 2026-10-12, statically, for OpenHOI3's messages, by one brief of the text wave (`WAVE.md`,
brief G), from a copy of the Ghidra project with the record applied. Addresses are rvas unless they say
VA. `FINDINGS-messages.md` - the registry, and how a message is raised - stays as it is; this is what
happens after the post. The tables are in `fragments/merged/message-display.json`.*

**Synopsis.** What each key of `messagetypes.txt` does, the post read whole, the popup, the log, the
map's text, how the variables are filled, the categories and where a player's settings are kept are
settled; the election popup's builder and how long a map text lasts are not. **Corrected**:
`CMessageHandler::FindType` does not answer null for an unknown name - it answers a `NULL_MESSAGE` type,
whose defaults log a line; 0xA6040 is no popup builder but **a province's member**, which selects a
battle there and centres the map on it, now `CProvince::SelectBattleForMessage`; `PostMessage` is **one
of twelve copies of a template**, one per class called back, the "event message helper" at VA 0xA0C4D0
being `CSelectEventOptionCommand`'s; **`nopopup` blanks every message**, the log too, not the event ones
alone; and `BuildMessagePopupText` runs **once, from the dialog's constructor**, not from its update.
New: a text that renders to exactly `*` is empty, everywhere; and `idle` is read, kept, saved and acted
on by nothing.

## 1. A type's settings

`CMessageType::LoadKey` (0x29A770) takes seven keys; any other is reported as unknown.

| key | field | default | what it does when a message of the type is posted |
| --- | --- | --- | --- |
| `log` | +0xD | **yes** | a line in the log (section 4) |
| `onmap` | +0xC | no | `<TYPE>_MAP` drawn as text on the map (section 5) |
| `popup` | +0xE | no | a popup (section 3) |
| `pausepopup` | +0x10 | no | a popup **too** - it does not need `popup` - and in single player the game paused |
| `option` | +0x34 | no | the popup's buttons: one (`_BTN1`), or two (`_BTN2`, and `_BTN3`, the "Goto") |
| `idle` | +0xF | no | **nothing**: read, kept, saved to the player's file, and read by none of the posters, the settings window, the settings panel or the log - a byte compare over all twelve posters, which does find the tests of +0xC, +0xD, +0xE and +0x10. `LOG_SETTING_IDLE` is in the localisation and no `.gui` shows it |
| `categories` | +0x8 | 5 | the index of an exact match among cat_combat 0, cat_diplomacy 1, cat_units 2, cat_province 3, cat_events 4, cat_other 5; anything else, a misspelling too, is 5. For the log's filters and the settings panel's tabs (section 7) |

Read from no key: **`popup_kind`** (+0x30) - 0 DefaultPopup, 3 ElectionResultPopup, anything else no
popup at all - set only by code, `CCountry_HoldElection` setting ELECTIONRESULTS to 3 each time it
posts (VA 0x4FC9C2); and a byte at +0x11, default 1, copied on an override, read by nothing found.

**A type loaded twice is overwritten whole by the second** - the category, the five flags, +0x11,
`popup_kind` and `option` (`LoadMessageTypes`, 0x298EE0). `interface/messagetypes.txt` is read first
and then `messagetypes_custom.txt`, so the player's file wins for every type it names (section 8).

**An undeclared type is not free**: `FindType` logs `Failed to find message type: X` and answers the
`NULL_MESSAGE` type (`CNullMessageType`, the defaults above), so the message is **logged**, as the key
`NULL_MESSAGE_LOG`, which no table has.

## 2. The post, read whole

**Twelve instances of one template `PostMessage<T>`**, one for each class T whose member function the
message calls back, told apart by the `CMessageDialog<T>` table each one's dialog writes:

| rva | T | callers |
| --- | --- | --- |
| 0x34290 | CMessageHandler | 91 |
| 0x4EEB0 | CInGameIdler | 14 |
| 0xC2200 | CCountry | 10 |
| 0x110A50 | CProvince (the record's `PostMessage`) | - |
| 0x1215C0 | CEU3Idler | 10 |
| 0x154430 | CLiberateCountryCommand | 2 |
| 0x15A7A0 | CChangeFoG | 2 |
| 0x15CC80 | CExecuteRebelAcceptanceCommand | 2 |
| 0x2D9360 | CCancelMissionCommand | 1 |
| 0x609B50 | CExecuteDecisionCommand | 2 |
| 0x60C4D0 | CSelectEventOptionCommand | 5 |
| 0x652F20 | CWar | 4 |

**Two shapes of frame**: where T's pointer to member is 4 bytes - the handler +8, the receiver +0xC,
the callback +0x10, the message (0x78 bytes, by value) +0x14, `ret 0x84`; for CProvince and
CInGameIdler, 8 bytes - the handler +8, the receiver +0xC, the message +0x10, the callback +0x88, the
adjustment of `this` +0x8C, `ret 0x88`. The callback is `bool (T::*)(CMessage*)` on the receiver, and
may be null: **events and decisions pass none** (`push ebx`, ebx 0, VA 0xA0BCA4 and 0xA0957F); a raise
like `ShatterUnit`'s passes `CProvince::SelectBattleForMessage` with the province as the receiver.

In order, alike in all twelve:

1. **`g_NoPopups` set: nothing at all** - no popup, no map text, no log line. It is the `nopopup`
   console command (VA 0x44194F), not a custom game's setting.
2. **No in-game screen, or the handler's `enabled` (+0x30) clear: nothing.** Its constructor sets it;
   it is cleared by the front end's constructor, by `MakeBackEndIdler` and at the start of
   `ApplyCustomGameSettings`, and set again at its end - so messages are muted while a game is made.
3. A null type: `Bad messagetype` to the game's log - which cannot happen through `FindType`.
4. **`popup` or `pausepopup`**: the dialog by the type's name and `popup_kind` - ATTACKTHEM,
   ATTACKUS, AIRATTACKTHEM, AIRATTACKUS, NAVALATTACKTHEM, NAVALATTACKUS **CombatStartPopup**; else kind
   0 **DefaultPopup**, kind 3 **ElectionResultPopup**, any other none. The dialog (`CMessageDialog<T>`,
   0x174 or 0x180 bytes, with its own copy of the message) goes on the screen's list of dialogs
   (`CEU3Idler::AddDialog`), its text made **in its constructor**. Then, in the same branch: single
   player (the screen's +0x68 clear), `pausepopup`, and the screen's slot 95 false (a byte at +0x12D8,
   "already paused" - `inferred`): a `CPauseGame(local player, 1)` command posted through the
   session's channel. **The game pauses through the command queue; unpausing is the player's.**
5. **`onmap`**: `<TYPE>_MAP` with the variables, rendered, then `ShowMessageMapText` (section 5) - only
   where the message has a first country, a second or a province.
6. **`log`**: with a callback a `CFunctionMessage<T>`, else a plain copy, to
   `CInGameIdler::AddMessageToLog` (slot 36, section 4).

**The post never asks whether the message is for the player**; every raise asks that before it makes
the message (`FINDINGS-messages.md`, "Only the player is told").

## 3. The popup

**The windows**, all in `interface/eu3dialog.gui` (the base game's; Their Finest Hour has no copy):
**DefaultPopup**, 500 x 280, centred at (-250, -280), moveable - Header, Line1 to Line6, LeftShield,
RightShield, AgreeButton (x 264, ENTER), DeclineButton (x 104, ESCAPE), CenterOK (x 184, ENTER);
**CombatStartPopup**, the same and `combatstart_divider`, Line_left_1 and _2, Line_right_1 and _2;
**ElectionResultPopup**, whose builder was not read. A type's window is chosen by its name and kind,
not its buttons; the file's other dialogs (DefaultDialog, AllyCallDialog...) are not messages'.

**The text** (`BuildMessagePopupText`, 0x355B0, for the ten 4-byte templates; its twin 0x505F0 for
CProvince and CInGameIdler; called from each dialog's constructor where `popup_kind` is 0):

1. **Variables**: `<TYPE>_HEADER` and `<TYPE>_1` to `_6` each get one replacement per variable,
   `$KEY$` -> `GetText(value)` - **each value is itself looked up as a key**, and shows as itself only
   where no key matches it.
2. **Header**: `_HEADER` rendered, its **first** `§W` turned to `§b`.
3. **Line1 to Line6**: each rendered with **every** `§W` turned to `§b` (VA 0x4366C4-0x43673C) -
   presumably white made dark for the parchment; what `b` is in the colour table was not read.
4. **`*`**: a line rendering to exactly `*` is **empty** - `CInternationalizedText::Render`'s own rule
   (a compare with VA 0x15BE4C4 at VA 0xA82E98), so it holds wherever a text is rendered.
5. **CombatStartPopup's columns**: a variable *named* ATTDETAIL, DEFDETAIL, ATTTOTAL or DEFTOTAL also
   sets Line_left_1, Line_right_1, Line_left_2 or Line_right_2 to its **raw** value, not looked up,
   its first `§W` turned to `§b`.
6. **Layout** (the `positionType`s at the end of `eu3dialog.gui`): y starts at Header's y plus its
   drawn height; for each of the six lines, an empty one is skipped, and the rest moved - keeping its
   own x - to y + 15 for Line2 (`popup_textline_dist_two`) or y + 0 for the others
   (`popup_textline_dist`, y 0), y growing by its drawn height; the combat divider and columns follow;
   the background is made **y + 70 + 50** high - `popup_bottom_button_pos.y` and
   `popup_textline_dist`'s **x**, a slip that is what the bytes do (VA 0x437674-0x4376ED); all three
   buttons stand 70 above that bottom.
7. **Buttons, by `option`**: **no** - AgreeButton and DeclineButton hidden, CenterOK shown with
   `<TYPE>_BTN1`, closing; **yes** - CenterOK hidden, AgreeButton `_BTN2` closing, DeclineButton `_BTN3`
   (the localisation's "Goto") running the callback where the post had one (`MessageDialog_PressGoto`),
   **the popup closing only where the callback answers false**; with no callback it closes. By the
   `.gui`'s shortcuts **Escape presses the Goto** of an `option = yes` popup.
8. **A province's Goto** (`CProvince::SelectBattleForMessage`): the province's battles (+0x2EC) - for
   AIRATTACKTHEM and AIRATTACKUS the first air battle (kind 3), for any other type the first - the
   selection cleared, that battle selected, the map centred on its province, and true answered, **so the
   popup stays up**; no such battle, false, and the popup closes.
9. **A right click** on its background, AgreeButton, DeclineButton or CenterOK opens **the settings
   window of its type** (`MessageDialog_OpenSettingWindow`), near the mouse (which event: `inferred`
   from the observer's slot 9, which the maintainer confirmed a right click in the leader window).
10. **Shields**: LeftShield the message's first country (+0x34), RightShield its second (+0x3C); with
    one of them, both show it; with neither, the file's stays.
11. **Placing and stacking: popups are not queued** - each is a dialog of its own, all live at once.
    Each new one moves the handler's count (+0x2C) on, back to 0 after 10, and stands 10 x count right
    and down of its base and 40 more down: **they cascade over 11 places**. A coordinate whose window
    would cross the right or bottom edge is set to the screen's size **less 10**, which leaves most of
    it off the screen. Which draws on top was not read.
12. **Shown**: a message's dialog is hidden while the custom game's settings' first byte is set (slot 4,
    0x113080) - the same unexplained gate as the event window's.
13. **Closed**, it is taken off the list of dialogs (`CEU3Dialog` slot 1).
14. **No tooltip** for a DefaultPopup; `CInGameIdler` slot 37 answers only for kind 3 (the election's
    chart and minister lists).
15. Four leftovers of EU3 - WECARDINALBRIBE, WEFCARDINABRIBE, CURIACONTROLLER, CARDINALBRIBE - get the
    window's slot 11 where every other type gets slot 44; what those do was not read.

## 4. The log

**Where**: `menubar.gui`, window `menubar` -> `messagelog_window` (720 x 100, at (-804, -156) from the
lower right), list box `messagelog` (411 x 115); with `closebutton`, six category checkboxes
`messagecat_combat`, `_diplomacy`, `_units`, `_provinces`, `_events`, `_others`, and `OPENbutton` to
open it again.

**A line** (`CMessage::BuildLogLine`): the message's **date**, a space, and `<TYPE>_LOG` with the
variables, rendered. The date is made with the message - `FormatHourDate`, ` %d:00, %d %s, %d`, which
begins with a space already. The line is wrapped to the `messagelogbutton`'s width less 10 (430 - 10)
and cut at breaks; **each piece is a row of its own**, a `logtext` window (700 x 16) with a copy of the
message, so a long message is several rows that act alike. **Rows go at the end**: the newest at the
bottom, the view following the end unless scrolled away (`inferred`).

**How many**: **200 messages** are kept, the oldest dropped past that; the list box is trimmed to **100
rows**, but **one row for each message added**, so messages of several rows let it grow past 100.

**Filters**: a message of a hidden category is kept and given no rows; a ticked category box hides its
category. On a change the log is made again **from the oldest kept, stopping after 101** - so with more
than 101 shown messages kept, a rebuild shows the oldest 101 and drops the newest (VA
0x64C7DF-0x64C7EC).

**Clicks**: a left click on a row calls the message's slot 2 - a `CFunctionMessage<T>`'s callback, a
province's Goto; a plain message's is an empty stub, so **clicking an event's or a decision's line does
nothing**. A right click opens the settings window of the row's type (the events `inferred` from the
observer's slots 1 and 9).

## 5. On the map

`onmap`: `<TYPE>_MAP` with the variables at the message's province - where it has none, at the first
country's acting capital, else the second's (its constructor fills the province so). An
`animatedmaptext` `MessageMapText` (`core.gfx`: speed 0.005, yellow 1 1 0, MaptextFont, 256 x 64,
centred, 40 up), made only where the map has an entity for the province. Nothing tests the text, so an
empty (`*`) `_MAP` still makes an empty one. How long it lasts is the animated text's (0xAC8AA0), not
read.

## 6. How the variables are filled

Each variable is a replacement `$KEY$` -> `GetText(value)` in every text made - `_HEADER`, `_1` to
`_6`, `_LOG`, `_MAP` - so **a value that is a key shows that key's text**. `CCountry::BuildMessageVariables`
gives, in order: `COUNTRY`, the country's name; `MONARCHTITLE` and `TITLE`, the same text, slot 15 of the
object at CCountry +0xDFC (the ruler's title, `inferred`); then, from the second entry of the government
positions on, **one variable per position, named by the position** (`$foreign_minister$`,
`$chief_of_army$`...), its value MINISTER_MESSAGE_ENTRY "$TITLE$ $NAME$" - the position's title and the
country's minister in it. Hence "$foreign_minister$ reports on". A raise adds its own after them
(`$UNIT$`, `$LOCATION$`...); an event's message makes its own list (`FINDINGS-eventfire.md`, section 2):
the local player's ministers, then COUNTRY, EVENT, EVENTDESC, OPTION.

## 7. The categories

Six, kept as an index, for **the log's filters** - six checkboxes, all on at the start, not saved - and
**the settings panel's tabs**, `messagecat_all` and the six, "all" being filter 6 (0x26DFC0 lists
`kind == 6 || type.category == kind`, read in the decompilation only).

## 8. A player's settings, and where they are kept

- **The settings window** (`messagesettings.gui`, `MessageSettingWindow`), opened by a right click on a
  popup or a log row, or from the panel: `title_text` is `<TYPE>_SETUP`; checkboxes for log
  (LOG_SETTING_LOG "Display in log."), popup ("Open popup window."), onmap ("Show on map.") and pause
  (LOG_SETTING_PAUSE "Popup and Pause", `pausepopup`). **Its constructor sets `onmap_button` twice; there
  is no `idle` box.** OK writes the four into the type and **writes `messagetypes_custom.txt` at once**;
  Cancel closes.
- **The settings panel** (`menubar.gui` `menu_message_settings`, list `settings`): a `message_entry` row
  for **every** type (`option` plays no part), in the registry's - the file's - order, each with its
  `_SETUP` text and four icon checkboxes (`messageicon_log`, `_dialog`, `_map`, `_pause`) **ticked where
  the setting is off**. A box writes the type at once; the file is written when the panel closes
  (`CloseMessageSettings`, `inferred` the close button). `reset` ("Reset  defaults") deletes the player's
  file and reads `interface/messagetypes.txt` again.
- **The file**, `messagetypes_custom.txt`: every type, whole (log, onmap, popup, idle, option,
  pausepopup, categories), in the user folder of the mod being played - here
  `Documents\Paradox Interactive\Hearts of Iron III\BlackICE GitHub\` and the two 16.x folders - and read
  over `messagetypes.txt` at every start. **Per player and per mod, not per save.** Looks wrong: once the
  file exists, **a mod's later change to a type's settings never reaches that player** until Reset; only
  types new to the mod take its values.

## 9. Events' and decisions' messages, as Their Finest Hour ships them

| type | log | popup | onmap | option | `_LOG` |
| --- | --- | --- | --- | --- | --- |
| EVENTHAPPENUS | yes | no | no | no | "Event: '$EVENT$' for player." |
| EVENTHAPPENOTHER, ...OPTION | no | no | no | no | "Event: '$EVENT$' in $COUNTRY$." / "Event: '$OPTION$' in '$EVENT$' for $COUNTRY$." |
| MAJOREVENTHAPPENOTHER, ...OPTION | yes | yes | no | no | "Major Event: $EVENT$ in $COUNTRY$." / "Major Event: $OPTION$ in $EVENT$ for $COUNTRY$." |
| DECISIONUS | no | yes | no | no | "Decision: $EVENT$ for player." |
| DECISIONOTHER | no | no | no | no | "Decision: $EVENT$ in $COUNTRY$." |
| MAJORDECISIONOTHER | yes | yes | no | no | as DECISIONOTHER |

All are cat_events, so their popups have one button, `_BTN1` "OK"; their `_MAP` and unused lines are
`*`. DECISIONUS is the header "$foreign_minister$ reports on", Line1 "$EVENT$!", Line2 "$DESC$", the
rest empty.

## 10. Looks wrong, and is what the bytes do

`nopopup` empties the log as well as the popups; an unknown type is logged as `NULL_MESSAGE_LOG`;
`idle` does nothing; the settings window sets `onmap_button` twice; the background's height takes
`popup_textline_dist`'s x (50); the clamp at the edges leaves a window mostly off the screen; Escape
presses the Goto; a Goto that succeeds keeps the popup up; the log is trimmed one row a message, and a
rebuild keeps the oldest 101; a header has only its first `§W` recoloured, a line all of its; the
combat columns are raw values; a variable's value is looked up as a key; the player's file hides a mod's
later changes; pausing is single player's only, and goes through the command queue.

## 11. Not read

The election popup's builders (0x654640, 0x534A0) and where `MessageDialog_PressSecond` is attached;
`CFunctionMessage<T>`'s fields; how long a map text lasts (0xAC8AA0); the screen's slot 95 byte
(+0x12D8), taken as "paused" by inference; a dialog's base position (the window's slot 26), the window's
slots 11 and 44, and which popup draws on top; what the custom game settings' first byte means; the
settings panel's tab code (0x26DFC0, 0x26F3F0) and the log window's toggle (0x24C8C0), decompiled only;
what colour `§b` is, and the user folder's flag in the file layer; whether index 0 of the government
positions is a placeholder.
