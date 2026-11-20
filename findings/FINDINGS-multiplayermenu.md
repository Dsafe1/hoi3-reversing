# The front end's multiplayer menu

Read 2026-11-20, statically, off the listings (no Ghidra), for OpenHOI3's front end. Fragment `multiplayer-menu.json`. Addresses are rvas unless marked VA (VA = rva + 0x400000); only valid for this build. **[exe]** hardcoded in the executable, **[mod: file]** what a file may change. `confirmed` unless marked.

The view is `CMultiplayerMenuView`, view 4 of `FINDINGS-frontend.md`, A.1: 0x350 bytes, RTTI bases `CFrontEndView` at +0 and `CSessionInfoObserver` at +8, tables VA `0x15D5054` (14 slots) and `0x15D5090`. Slot 1 (Prepare) is the shared empty stub; slots 2, 3 and 4 are its Show, Hide and per-frame Update.

**Not wanted and not read**: the lobby, the network protocol, the metaserver view. The session channel's slots this view calls (2, 3, 9, 11, 12, 14) are named here only by what the view does around them, each *inferred*.

**Noticed and left alone**: the session's name is compared at `Session +0xBC`, which lies inside the span the record gives `Session +0xAC address` (a 0x1C-byte string). One of the two is misplaced; that the session holds a whole `CSessionConfiguration` at +0xB4 would explain +0xBC (*inferred*, not checked in the constructor).

## 1. What is built, and where the windows live

**Two of the three windows are sub-windows of the backdrop** [exe]. `CFrontEnd::Reload` finds `multiplayer_menu` and `multiplayer_connect_menu` inside `country_selection_panel` (the front-end window's slot 27) and hands both to the constructor (`0x2FD190`, the object new'd at VA `0x6F39A2`). So the backdrop, logo and version label stay behind the menu as behind the main menu. Reload then hides the view like every view but 0.

**`naming_window` is made by the view itself** [exe], as a window of its own from the gui's factory, kept at +0x334 and hidden at once. It is not a child of `multiplayer_menu`, and the view's Hide does not touch it.

**The constructor binds buttons and nothing else.** Ten `CButtonObserverGlue<CMultiplayerMenuView>` are made by value (0x50 bytes each, from +0x10); eight are attached:

| window | element | handler |
| --- | --- | --- |
| `multiplayer_menu` | `host` | OnHost `0x2FE5E0` |
| | `join` | OnJoin `0x2FEAE0` |
| | `join_direct` | OnJoinDirect `0x300B80` |
| | `scan` | OnScan `0x3020F0` |
| | `metaserver` | OnMetaserver `0x301870` |
| | `Back`, asked for as `back` | OnBack `0x3014C0` |
| `multiplayer_connect_menu` | `back` | OnConnectBack `0x300820` |
| `naming_window` | `ok_host_button` | OnHostOk `0x301C20`, swapped with OnJoinDirectOk `0x301140` (section 4) |
| | `back_button` | OnNamingBack `0x3020C0` |

- The file's button is `Back` and the code asks for `back`; the lookup evidently matches without case (*inferred* from it working in the shipped game).
- **`scan`'s text is overwritten at construction** with the localised key **SCAN** ("Scan"), over the file's FE_SCAN ("scan").
- **Named by no code**: `bg_multiplayer_menu`, `name_label`, `frontend_connectlog_bg`, the naming window's `Background`. They are simply part of their windows, with the file's texts (FE_PLAYER_NAME "Player name:").
- **No edit box is given a listener** - not `playername`, not `edit`. The constructor, Show and all ten handlers were read whole; none calls an edit box's listener list.
- **No tooltips**: the `.gui` entries carry none and `FINDINGS-frontend.md` A.2 has the front end's tooltip routine answering only for `gamesetup` and `micro`.

## 2. `playername`

- **At open** [exe]: Show (`0x2FDC00`) writes the settings' `last_player` (settings.txt `lastplayer` [mod: settings.txt]) into the box only where it is not empty. Otherwise the box keeps its file text, FE_PLAYER localised ("Player") [mod: temp_frontend.gui, localisation].
- In that same non-empty arm Show also sets the keyboard-focus request (`+0x40` word = 1) on the naming window's hidden `edit`. Odd, and the original's.
- **Read, never validated**: its text is taken as it stands when Host's OK, Join or the address window's OK is pressed, and written to the front end's `local_player_name` (+0xC0). No trim, no test for empty, no test of length.
- **Stored**: this view never writes `lastplayer`. The lobby's CONNECTED handler (VA `0x708190`, `FINDINGS-settingswindow.md` C.4) copies the lobby's own player name to `lastplayer` where it differs and writes the file. So the name reaches settings.txt only once a lobby is actually entered. That the lobby's name is the front end's +0xC0 is *inferred*.
- **Length and characters**: the edit box's own rules, nothing added here - 250 bytes, and the seven bytes refused under a font with `effect` set (`FINDINGS-editbox.md`).
- **The only check on a name is after connecting**: NAME_TAKEN, section 5.

## 3. The menu's list and buttons

**`games`** is kept by Update (`0x2FDE10`, *inferred* in its middle):

- **A row** is a `CGameNameMember` (0x140 bytes, `0x2FCD40`): window **`local_game_entry`**, whose checkbox **`game`** gets the game's name as its text (the configuration's `game_name`), over the file's "...". Ticking it selects the row through the list item's own slots (*inferred*). `local_game_text` and FE_LOCAL_GAMES are used by nothing in this view.
- **While a scan runs**, each frame the sessions found are copied to the view's own list (+0x33C); rows whose session is gone are removed and new sessions get a row.
- **With no session known and no row in the list, one row saying FE_NONE_FOUND ("None")** is added. This is so from the first frame the menu is open, before any scan. Its configuration's `status` is 0.

**`join` is enabled or greyed every frame** [exe]: enabled only while `games` has a selected row whose configuration's `status` is not 0. With nothing selected, or only the None row, Join Lan Game is greyed (button slots 46 / 47, the same enable / disable pair as `FINDINGS-frontend.md` C.4). No other button of the menu is ever greyed.

| button | does |
| --- | --- |
| `host` (FE_HOST "Host") | opens the naming window for a game name (section 4). Needs nothing: no test of the player name |
| `join` (FE_JOIN_LAN_GAME "Join Lan Game") | with a selected row: that row's configuration and the player name go to the front end, session mode 2, Connect (section 5). No naming window. With no selected row the handler returns |
| `join_direct` (FE_JOIN_INTERNET_GAME "Join Internet Game") | opens the naming window for an address (section 4) |
| `scan` | **a toggle.** Not scanning: `games` emptied, a scanning session made (name `LobbySession`, address a single space, **port 0x666**, game name `scaning_session`, so spelt), the scan started, the text set to **STOP_SCAN** ("Stop Scan"). Scanning: the text back to **SCAN** ("Scan"), the scan stopped, the startup session put back; the list stays as it was |
| `metaserver` (FE_METASERVER) | stops a running scan as above, then view 5, the store window hidden |
| `Back` (FE_BACK) | stops a running scan as above, then section 6 |

## 4. `naming_window`: one window, two uses

**The maintainer's "second panel that opens once you choose internet game" is this window**; Host opens the same one. Its file comment, "used for both player and game name", is not what the code does: it is used for the **game name** and for an **address**, never for the player's name.

| | Host (`host`) | Join Internet Game (`join_direct`) |
| --- | --- | --- |
| `Title` | localised **HOST_TITLE**, "Enter the name of your game..." | localised **JOIN_IP_TITLE**, "Enter IP address..." |
| `ok_host_button`'s text | localised **HOST_BUTTON**, "Host" | localised **JOIN_BUTTON**, "Join" |
| `ok_host_button`'s handler | OnHostOk | OnJoinDirectOk |
| `edit`'s text | **not touched** | set to settings.txt's `lasthost`, empty or not |
| `back_button` (FE_CANCEL "Cancel") | the same for both | |

Both openers [exe] do, in order: `Title`; on `ok_host_button` remove both OK glues and add the one wanted; set the button's text (the file's FE_HOST is always overwritten); ask the keyboard focus for `edit`; show the naming window; hide `multiplayer_menu`. Keys [mod: localisation/frontend.csv].

**What `edit` starts with.** For Host: the file's FE_MY_GAME localised ("My Game") the first time, and afterwards whatever the box last held - a name typed before, or the address the join panel put there. Open Join Internet Game, cancel, open Host, and the game-name box holds the last host's address. The original's; do not tidy it.

**`back_button`** (OnNamingBack): the naming window hidden, `multiplayer_menu` shown. Nothing else; the typed text stays.

**OK, hosting** (OnHostOk):
- the game name is `edit`'s text exactly as typed - **not trimmed, not tested, empty allowed**;
- a configuration is made: session name `LobbySession`, address `localhost`, **port 0x666 (1638)** [exe], type 6, basic type 1, status 1, the application's version;
- the player name (`playername`), the configuration and "host" = 1 go to the front end (+0xC0, +0xDC, +0x180);
- the session is made and becomes the application's;
- session mode 1, the naming window hidden, then **the lobby** (section 5).

**OK, joining by address** (OnJoinDirectOk):
- the address is `edit`'s text with white space taken off both ends; **nothing else is tested - an empty address goes on to a failed connect**;
- a configuration is made: `LobbySession`, the address (also as the game name), **port 0x666**, type 7, basic type 0, status 1, a blank version;
- the naming window is hidden and the menu is not shown again;
- **`lasthost` is set to the address in memory** (the file is written by the lobby's CONNECTED handler, so only after a join that reaches the lobby);
- the player name and the configuration go to the front end, "host" = 0, session mode 2, Connect.

There is no port in the text's handling: the typed text is the whole address and the port is the constant.

**Enter does not confirm.** No listener is attached to `edit` (section 1) and the buttons carry no shortcut in the file, so Enter in the box is swallowed and does nothing (`FINDINGS-editbox.md`, section 7). OK is by mouse only.

## 5. Connecting, the connect log, and what comes next

**`CMultiplayerMenuView_Connect`** (`0x2FF760`, *inferred* where it meets the channel), called by Join, by the address window's OK, and by Show where the application's +0x130 is set:

1. the sound `ding` [exe name; mod: the sound's definition];
2. `multiplayer_menu` hidden, **`multiplayer_connect_menu` shown**;
3. **up to three attempts** [exe] with waits of 0.6, 2.1 and 3.6 (start 0.6, step 1.5, while under 4.0; seconds *inferred*); the first that succeeds is kept as the application's session. The window is already "shown" but no frame is drawn during the attempts - the routine is synchronous;
4. **a row saying CONNECTING ("Connecting...")** is added to `info_list` - always, after the attempts;
5. one more row by the outcome, or none:

| outcome | row added after CONNECTING |
| --- | --- |
| no attempt succeeded | **GAME_NOT_FOUND** "Game not found." |
| connected, session state 0xE | **BAD_VERSION** "The host has another version of the game!" |
| connected, the start refused, state 9 | **BANNED** "You have been banned from this game" |
| connected, the start refused otherwise | **CONNECTION_FAILED** "Connection failed!" |
| connected and started | none - the window stays on "Connecting..." until the session answers |

After any failure row the startup session is put back (`CMultiplayerMenuView_RestoreInitialSession`, `0x300990`); the connect window stays up until `back`.

**Then the session answers** (OnSessionInfo, `0x2FECE0`, *inferred* as to what the events mean):
- **event 0**: the player's name is compared byte for byte, case and all, with the name of every human already in the game state. **A match adds NAME_TAKEN** ("Your name is taken. Please leave and select another.") and drops the connection; the window stays. **No match switches to view 3, the lobby.**
- **event 0xC**: a row **HOTJOIN_ACCEPTED** ("Server has allowed entry") or **HOTJOIN_DECLINED** ("Server has declined entry"); a decline also has the next frame put the startup session back.

**A row of `info_list`** is a plain list item over the window **`connection_log_text`**, whose text box **`text`** is set to the localised key. Rows are added at the end. **Nothing ever clears `info_list`** (the list's clear call, which OnScan uses on `games`, appears nowhere in Connect, OnSessionInfo, OnConnectBack or Show), so the lines of earlier attempts stay until the front end is built again.

**`back`** of the connect window (OnConnectBack): `multiplayer_menu` shown, the connect window hidden, the game state's players cleared, the startup session put back - a connection under way is dropped. Where the application's +0x130 is set it goes to view 5, the metaserver, instead.

**What comes next, and what is handed over:**

| from | to | handed over |
| --- | --- | --- |
| Host's OK | **view 3, the lobby** (`CGameSetup`), at once: BuildBookmarkLists, the store window hidden, the camera's keep flag cleared, this view's Hide, the lobby's Prepare and Show - the same steps as `single_player_button`'s | session mode **1**; the front end's `local_player_name` (+0xC0), `session_configuration` (+0xDC, with the game name) and `is_host` 1 (+0x180); the application's session |
| a join that is acknowledged | **view 3, the lobby**, from OnSessionInfo's event 0 | session mode **2**; the same three fields with `is_host` 0; the connected session, this view registered as its observer |

The default port, **1638 (0x666)** [exe], is a pushed constant in OnHostOk, OnJoinDirectOk and OnScan and lands in the configuration's `port` (+0x68).

## 6. Coming in and going out

**In**, from `multi_player_button` (`FINDINGS-frontend.md` A.2): session mode 1; the main menu's Hide (`mainmenu_panel` hidden); this view's Show - **`multiplayer_menu` shown, `multiplayer_connect_menu` hidden**, `playername` filled (section 2); the store window hidden. `country_selection_panel` stays, so the backdrop is unchanged. The naming window is as it was left, which is hidden - its own buttons are the only way out of it. The None row appears on the first frame.

**Out**, by `Back` (OnBack): a running scan stopped and `scan`'s text back to SCAN; the settings' `simple` cleared; this view's Hide - **`multiplayer_menu` and `multiplayer_connect_menu` hidden**; current view 0; the main menu's Prepare and Show; the store window hidden. **The session mode global is not put back** - it stays at what the menu set until `single_player_button` writes 0. The player name typed is not saved (section 2). The `games` rows and the connect log's lines survive for the next visit.

## 7. What looks wrong and is the original's

1. One window asks for the game name and for the address, and Host does not reset its text: a cancelled Join Internet Game leaves the last host's address as the offered game name.
2. Nothing tests the game name, the address or the player name for being empty.
3. The connect log is never cleared.
4. "Connecting..." is written after the connection attempts, not before.
5. Enter does nothing in the naming window.
6. `scan`'s file text FE_SCAN ("scan") is never seen: the constructor writes SCAN ("Scan").
7. `ok_host_button`'s file text FE_HOST is never seen either: HOST_BUTTON or JOIN_BUTTON replaces it.
8. The None row is a selectable row; `join` is greyed for it by its status, not by its text.
9. Show asks the keyboard focus for the hidden naming box, and only when `lastplayer` is not empty.
10. Back leaves the session mode at multiplayer.
11. `lastplayer` and `lasthost` reach settings.txt only when a lobby is reached.

## 8. Not established

- What sets the application's +0x130 - the metaserver view's chosen game, *inferred*; its writer was not traced.
- What the application's +0xE4 object's slot 4 does, called with 0 after a failed connect and after a join.
- The session channel's slots and the meaning of events 0 and 0xC on the wire.
- Which rows Update keeps when a scan's list changes: the comparison helper at `0x302D30` was read in part.
- A `CGameNameMember`'s slots 4 and 5 (select and deselect, *inferred*).
- The destructor's middle.
- Whether the gui's name lookup is case-blind in general (`Back` / `back`).
- The readers of the front end's +0x180.
- In Connect, a second copy of the configuration has its port set to 0x661 (1633) and is then not used (*inferred* dead; the session is made from the first copy).

## 9. Addresses

| rva | name | confidence |
| --- | --- | --- |
| `0x2FD190` | CMultiplayerMenuView::CMultiplayerMenuView | confirmed |
| `0x2FD8A0` | CMultiplayerMenuView::~CMultiplayerMenuView | inferred |
| `0x2FDC00` | CMultiplayerMenuView::Show (slot 2) | confirmed |
| `0x2FDDE0` | CMultiplayerMenuView::Hide (slot 3) | confirmed |
| `0x2FDE10` | CMultiplayerMenuView::Update (slot 4) | inferred |
| `0x2FE5E0` | CMultiplayerMenuView::OnHost | confirmed |
| `0x2FEAE0` | CMultiplayerMenuView::OnJoin | confirmed |
| `0x2FECE0` | CMultiplayerMenuView::OnSessionInfo (table at +8, slot 1) | inferred |
| `0x2FF760` | CMultiplayerMenuView_Connect | inferred |
| `0x300820` | CMultiplayerMenuView::OnConnectBack | confirmed |
| `0x300990` | CMultiplayerMenuView_RestoreInitialSession | confirmed |
| `0x300B80` | CMultiplayerMenuView::OnJoinDirect | confirmed |
| `0x301140` | CMultiplayerMenuView::OnJoinDirectOk | confirmed |
| `0x3014C0` | CMultiplayerMenuView::OnBack | confirmed |
| `0x301870` | CMultiplayerMenuView::OnMetaserver | confirmed |
| `0x301C20` | CMultiplayerMenuView::OnHostOk | confirmed |
| `0x3020C0` | CMultiplayerMenuView::OnNamingBack | confirmed |
| `0x3020F0` | CMultiplayerMenuView::OnScan | confirmed |
| `0x302B80` | CMultiplayerMenuView_MakeButtonGlue | confirmed |
| `0x2FCD40` | CGameNameMember::CGameNameMember | inferred |
| `0x6CF1C0` | CSessionConfiguration::CSessionConfiguration | confirmed |

Structs declared: `CMultiplayerMenuView` (0x350), `CGameNameMember` (0x140), `CSessionConfiguration` (0xA4: `session_name` +8, `game_name` +0x24, `string_address` +0x40, `address` +0x5C, `type` +0x60, `status` +0x64, `port` +0x68, `basic_type` +0x6C, `version` +0x70). `CFrontEnd` gains `local_player_name` +0xC0, `session_configuration` +0xDC and `is_host` +0x180.

**Corrected by the apply, 2026-11-20.** The fragment also declared a field `session_info_observer` at `CMultiplayerMenuView +0x8`. That offset is the class's second table pointer, which the apply places itself as `vftable_at8`, and the two fought: the headless apply placed two struct fields on every pass and never settled. The field was deleted from `project.json` by hand; the apply then gave `failed: 0`, `replaced: 0` and `struct fields: 0` on its second pass. A secondary base's table pointer is not a field to declare.
