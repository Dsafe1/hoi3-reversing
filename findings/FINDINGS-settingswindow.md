# The game options window: `menu_settings_ingame` and `settings.txt`

*The game options wave, 2026-11-04: three readers, read statically out of `hoi3_tfh.exe` with `scripts/disasm.py`,
`scripts/findRefs.py`, `scripts/vtable.py` and copies of the Ghidra project. Only valid for this build. Set against the
maintainer's `settings.txt`, which the original wrote. For OpenHOI3, whose in-game menu greys Game Options until this
window is built, and whose maintainer decided the same day that its Apply writes the original's `settings.txt`.*

**The wave in one paragraph.** **The window** (`interface/settings.gui`'s `menu_settings_ingame`, `CSettingsScreen` and
`CIngameSettingsScreen`, section A) has four tabs that are plain buttons, opens first on **Video** and afterwards on
the tab last chosen, pauses nothing of its own, and has no tooltips. **Apply** copies every tab into the settings
singleton and writes `settings.txt`; with a changed resolution, refresh rate or multisampling it shows `RESTART_REQ` and
goes back to the menu's six buttons, and otherwise **closes the whole in-game menu** (its Close called twice). **Back**
puts the volumes back and drops what was not applied - all but the autosave choice, which survives to a later Apply.
**The Game tab** is the autosave frequency, wrapping both ways. **The Video tab** (section B) lists the adapter's own
modes and their rates, steps multisampling through the counts the card supports, previews gamma at once (and Back does
not undo it), and holds the counter sliders and five checkboxes until Apply; only resolution, refresh rate and
multisampling need a restart. **The Audio tab** (section C) is heard as its sliders move; **the Controls tab**'s speeds
and legacy camera wait for Apply - and the legacy camera box is never set from the settings, so Apply turns the setting
off unless it is ticked again. **The writer** (`CSystemSettings_SaveToFile`, section C.4) writes 21 keys in a fixed order
and format, the maintainer's file's exactly, on Apply, whenever a game is left, and at three other places.

**Corrected in the record**: `SettingsMustRestartWindow` is dead file content - the restart notice is a
`DefaultInfoDialog`; Ghidra's RTTI label `CSettingsScreen::CSettingsScreen` on VA `0x6FB500` is
`~CFrontendSettingsScreen`; `CInGameIdler +0x1D2C` is typed `CIngameSettingsScreen*`; and `GraphicsSettings_DetectDevice`
also fills the multisampling table. **Raised and not settled**: the 16 bytes `GameSettings_GetTextColours` copies begin
with the gui block's language, so that record's "text colours" reading is suspect (section C, synopsis).

| section | reader | fragment |
| --- | --- | --- |
| A, the window, Apply, Back and the Game tab | A | `fragments/merged/settings-window.json` |
| B, the Video tab | B | `fragments/merged/settings-video.json` |
| C, the Audio and Controls tabs, and the writer of `settings.txt` | C | `fragments/merged/settings-audio-controls.json` |

## A. The window (`menu_settings_ingame`)

*Reader A. Read 2026-11-04, statically, partly from a copy of the Ghidra project with the record applied. Addresses are
VAs unless marked rva. **[exe]** is hardcoded in the executable, **[mod: file]** a file may change it.*

**Synopsis.** The aim was the in-game settings window, `menu_settings_ingame` - `CSettingsScreen` and
`CIngameSettingsScreen` (construction, the six slots, the tabs, Apply, Back and closing, the Game tab) and how
`CFrontendSettingsScreen` differs. All of it is settled off the bytes. The tabs are four plain buttons, not checkboxes;
the window opens first on the **Video** tab and afterwards on whichever was last chosen; Apply copies every tab into the
settings singleton and calls the `settings.txt` writer inside a try. **Corrected rather than added**: settings.gui's
`SettingsMustRestartWindow` is never named by the executable - the restart notice is a `DefaultInfoDialog` with
`RESTART_REQ` / `RESTART_REQ_DESC`; Ghidra's RTTI label `CSettingsScreen::CSettingsScreen` on VA `0x6FB500` is wrong -
it is `~CFrontendSettingsScreen`; and Apply with no restart needed **closes the whole in-game menu**, not just the
window. One field revised: `CInGameIdler +0x1D2C`'s type.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| 0x2F5C00 | CSettingsScreen::CSettingsScreen | new | confirmed | the shared base constructor (`__stdcall`, `ret 0xC`): 19 glues, makes the window, attaches Back/Apply/tabs/the six video buttons/the two autosave buttons, current tab = VIDEO, then the four tab inits and Refresh |
| 0x2FB710 | CIngameSettingsScreen::CIngameSettingsScreen | new | confirmed | this@ESI, idler@EDI (`no_signature`); base ctor with "menu_settings_ingame", idler at +0x3DC |
| 0x2FB790 | CSettingsScreen::ScalarDeletingDestructor | new | confirmed | slot 0 of CSettingsScreen and CIngameSettingsScreen |
| 0x2FB880 | CSettingsScreen::Show | new | confirmed | slot 1: shows the window, hides its subwindows, shows the current tab, runs Refresh, +4 = 1 |
| 0x2FB5E0 | CSettingsScreen::Hide | new | confirmed | slot 2: hides the window and its subwindows, +4 = 0 |
| 0x2F6860 | CSettingsScreen::IsShown | new | confirmed | slot 3: `mov al,[ecx+4]`; held only by the 3 settings tables |
| 0x2F6870 | CSettingsScreen::UpdateVolumes | new | confirmed | slot 4: the 3 volume sliders into settings +0x80/+0x84/+0x88, every frame while shown |
| 0x2FB8D0 | CIngameSettingsScreen::Close | new | confirmed | slot 5 (BackButton): restores the saved volumes, then CloseMenu(custom-game-setup ? 1 : 0) |
| 0x2FB620 | CFrontendSettingsScreen::Close | new | inferred | slot 5: Hide, restore volumes, settings +0x174 = 0, front end back to view 0 |
| 0x2FB4D0 | CFrontendSettingsScreen::ScalarDeletingDestructor | new | confirmed | slot 0 |
| 0x2FB500 | CFrontendSettingsScreen::~CFrontendSettingsScreen | new | confirmed | destructor body; Ghidra's RTTI label (CSettingsScreen::CSettingsScreen) is wrong |
| 0x2F68F0 | CSettingsScreen::InitGameTab | new | confirmed | +0x36C = settings +0x15C, once, at construction; `autosave_value` text set |
| 0x2FB0B0 | CSettingsScreen::OnIncreaseAutosave | new | confirmed | +0x36C + 1, 5 wraps to 0, text set |
| 0x2FB2C0 | CSettingsScreen::OnDecreaseAutosave | new | confirmed | +0x36C - 1, 0 wraps to 5, text set |
| 0x2FADF0 | CSettingsScreen::OnGameTab | new | confirmed | tab 1: hides the current tab, menu_settings_GAME becomes current and is shown |
| 0x2FAEA0 | CSettingsScreen::OnVideoTab | new | confirmed | tab 2 -> menu_settings_VIDEO |
| 0x2FAF50 | CSettingsScreen::OnAudioTab | new | confirmed | tab 3 -> menu_settings_AUDIO |
| 0x2FB000 | CSettingsScreen::OnControlsTab | new | confirmed | tab 4 -> menu_settings_CONTROLS |
| 0x2F7300 | CSettingsScreen::OnApply | new | confirmed | ApplyButton: StoreChoices, display-mode/multisample restart test, writer in a try, restart or error dialog, slot 5 (twice when no restart is needed) |
| 0x2F80A0 | CSettingsScreen::StoreChoices | new | confirmed | every tab's choices into the settings singleton (+0x15C = +0x36C among them) |
| 0x2F8540 | CSettingsScreen::EnableButtons | new | confirmed | enables Back and Apply (slot 46); also the handler of glue +0x184, which nothing attaches |
| 0x2F9370 | CSettingsScreen_Refresh | new | confirmed | this@EDI: Video/Audio/Controls controls re-read from settings, saved volumes stored; never touches the Game tab |

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| CSettingsScreen (declared 0x3DC, vftable 0x11D4AF0) | 0x4 | shown | bool | new |
| CSettingsScreen | 0x8 / 0x34 | decrease_/increase_resolution_observer | void* | new |
| CSettingsScreen | 0x60 / 0x8C | decrease_/increase_refreshrate_observer | void* | new |
| CSettingsScreen | 0xB8 / 0xE4 | decrease_/increase_multisample_observer | void* | new |
| CSettingsScreen | 0x120 | parent | void* | new |
| CSettingsScreen | 0x124 | graphics | void* | new |
| CSettingsScreen | 0x128 | gui | void* | new |
| CSettingsScreen | 0x12C | apply_observer | void* | new |
| CSettingsScreen | 0x158 | back_observer | void* | new |
| CSettingsScreen | 0x184 | enable_buttons_observer | void* | new |
| CSettingsScreen | 0x1B0 / 0x1DC / 0x208 / 0x234 | game_/video_/audio_/controls_tab_observer | void* | new |
| CSettingsScreen | 0x358 | current_tab | void* | new |
| CSettingsScreen | 0x368 | window | void* | new |
| CSettingsScreen | 0x36C | autosave_choice | int | new |
| CSettingsScreen | 0x370 / 0x39C | decrease_/increase_autosave_observer | void* | new |
| CSettingsScreen | 0x3C8 / 0x3CC / 0x3D0 | saved_master_/effect_/music_volume | float | new |
| CIngameSettingsScreen (declared 0x3E0, inherits CSettingsScreen, vftable 0x11D4BC8) | 0x3DC | idler | CInGameIdler* | new |
| CFrontendSettingsScreen (declared 0x3E8, inherits CSettingsScreen, vftable 0x11D4B70) | 0x3E4 | front_end | CFrontEnd* | new |
| CInGameIdler | 0x1D2C | settings_screen | CIngameSettingsScreen* | revised: type only, was `void*`; comment adds slot 4 per frame and Leave's delete |

Vftable slots recorded: CSettingsScreen 0-5 (5 is `_purecall` in the base, recorded as Close), CIngameSettingsScreen 5,
CFrontendSettingsScreen 0 and 5.

### A.1 Construction

- **Who makes it.** `CInGameIdler::Enter` allocates 0x3E0 bytes and calls `CIngameSettingsScreen::CIngameSettingsScreen`
  (`0x6FB710`, this in ESI, idler in EDI). It stores the result at idler `+0x1D2C` and **hides it at once** through slot
  2 (`0x660627`) - it has to: the base constructor leaves the window shown.
- **The base constructor** (`0x6F5C00`, stack this/parent/name, `ret 0xC`) does, in order:
  - builds 19 embedded observer glues (fields above);
  - keeps the parent at +0x120, the parent's slot 17 (graphics) at +0x124 and slot 14 (gui) at +0x128;
  - makes the window by name through the gui's slot 11, kept at +0x368;
  - attaches by name, on the outer window: `BackButton` (+0x158), `ApplyButton` (+0x12C) and `settings_tab_1`-`_4`
    (+0x1B0, +0x1DC, +0x208, +0x234);
  - sets **+0x358 = `menu_settings_VIDEO`**;
  - attaches the six resolution/refresh/multisample buttons on `menu_settings_VIDEO`, and `decrease_`/
    `increase_autosave_button` (+0x370 / +0x39C) on `menu_settings_GAME`;
  - shows the window, hides its subwindows (window slot 28) and shows the Video tab;
  - runs InitGameTab, the Video, Audio and Controls inits, and Refresh.
- **Layout.** In both settings.gui copies, ApplyButton and BackButton are children of the outer window, not of
  `menu_settings_GAME` (brace depth 2) - so one Apply serves every tab [mod: interface/settings.gui]. Base and TFH
  settings.gui differ only in three empty tooltip keys on the dead `SettingsMustRestartWindow`. BlackICE ships its own
  settings.gui.
- **Never named by the executable** (string search for each over the whole image: no hits, while the same search finds
  every name the code uses): `settings_label` (SM_SETTINGS "Settings"), `settings_bg`, the four `*settings_label`s
  (SM_GAME "Game", SM_VIDEO "Video", SM_AUDIO "Audio", SM_CONTROLS "Controls"), `autosave_label` (SM_AUTOSAVE_INTERVAL
  "Autosave Interval") and the whole `SettingsMustRestartWindow` (`MustRestartTextBox`, `MustRestart_OK_Button`). They
  show their file text [mod: settings.gui, localisation/frontend.csv].
- **Destroyed** by `CInGameIdler::Leave` (`0x662257`, slot 0 with 1).

### A.2 The six slots

| slot | function | what it does |
| --- | --- | --- |
| 0 | ScalarDeletingDestructor | shared by CSettingsScreen and CIngameSettingsScreen |
| 1 | Show | shows the window, hides its subwindows, shows the **current tab**, Refresh, window slot 11, +4 = 1 |
| 2 | Hide | hides the window and its subwindows, +4 = 0; nothing applied or restored |
| 3 | IsShown | answers +4 |
| 4 | UpdateVolumes | the three volume sliders into settings +0x80/+0x84/+0x88 |
| 5 | Close | in game: CIngameSettingsScreen::Close |

Callers through idler +0x1D2C: the menu's Game Options (`OnMenuOptionsButton`): slot 1; `CloseMenu`: slots 3 and 2;
**`UpdateTutorialAndAuxWindows`, every frame**: slot 3, then slot 4 while the window is up (`0x64FD51`-`0x64FD71`). So
moving a volume slider changes the settings at once, before Apply; what the sound does with that is section C's.

### A.3 Show, and what is reset on opening

Each Show runs `CSettingsScreen_Refresh`, which sets the Video, Audio and Controls controls again from the settings
singleton, and saves the three volumes at +0x3C8/+0x3CC/+0x3D0 - what Back restores. **Refresh never touches the Game
tab**: no reference to `autosave_value` or +0x36C. The autosave choice is read from settings only once, at
construction. **No pause of its own** [exe]: the menu has already paused a single-player game (`FINDINGS-ingamemenu.md`,
A.2), and nothing in these slots touches the pause. The menu window and its picture stay up behind it.

### A.4 The four tabs

- `settings_tab_1` -> `menu_settings_GAME`, `_2` -> `_VIDEO`, `_3` -> `_AUDIO`, `_4` -> `_CONTROLS` [exe: the names are
  literals in each handler].
- They are `guiButtonType`s with `GFX_settings_tab_button`, **not checkboxes or radio buttons**. Each handler hides the
  current tab window (+0x358), looks up its own window (window slot 27), stores it at +0x358 and shows it. Nothing marks
  the chosen tab, and nothing is applied or reset by changing tab. Each tab name has exactly one reference in the image,
  in the constructor.
- **Up first: Video** [exe], at construction. Later the window reopens on whichever tab was last chosen: +0x358 survives
  Hide, and Show shows it again.

### A.5 Volumes live, the rest on Apply

Only the volumes reach the settings before Apply, through slot 4 each frame. Everything else stays in the screen's
fields until Apply. What the Video/Audio/Controls controls do on their own is sections B and C. Seen in passing: Refresh
disables the effect and music sliders when the master volume is below a constant.

### A.6 ApplyButton (`CSettingsScreen::OnApply`, `0x6F7300`)

Extent `0x6F7300`-`0x6F8095`. A catch funclet at `0x6F761D` resumes at `0x6F762E`, and **Ghidra splits the function
there** (`Catch_All@006f761d`, `FUN_006f7630`) - trap 3.

1. **StoreChoices** copies every tab into the settings singleton: the Video checkboxes (+0xE4/+0xE5/+0xE8/+0xE9),
   counter distance (+0xFC) and counter scale (+0x100 and global 0x170AF84); **the autosave choice into +0x15C**
   (`0x6F8189`); gamma into +0x5C, then 0xA76810 with the graphics; the three volumes into +0x80/+0x84/+0x88 and into the
   saved copy +0x3C8-+0x3D0; scroll speed (+0x90) and zoom speed (+0x98); `counters_checkbox` into +0xF9,
   `legacy_camera_checkbox` into +0x188; every province's weather picture marked changed.
2. **Display mode** (section B's meaning): it finds the current mode's index in the settings' mode list (+0x14,
   0x18-byte entries) by the graphics' +0x6B9BC/+0x6B9C0, and the current refresh rate's index. Multisampling (+0x54) is
   set to the choice where it differs, and **that asks for a restart**. Where the chosen mode or rate index differs from
   the current one, globals 0x170AEB0/0x170AEB4 = the chosen indices and **a restart is asked**; otherwise both are -1.
   Width +0x40, height +0x44 and rate +0x48 are set from the choice in every case. **No device reset is made** [exe].
   *Quirk*: the current-rate search walks **entry 0's** rate list (`0x6F7428`) over the chosen entry's count, which looks
   able to ask for a restart with nothing changed when the current mode is not the first in the list (*inferred*, not
   tried).
3. **The write, inside a try**: 0xAB1CE0 with the settings in ESI (section C). A throw clears the success flag.
4. **Back and Apply disabled** (slot 47) and re-enabled on every path within the same call, so nothing is seen greyed
   (*inferred*: no frame passes in between).
5. **Three endings:**
   - **Written, restart asked**: a `DefaultInfoDialog` (CEU3Dialog, 0x68 bytes, 0x63D4B0) with title `RESTART_REQ`
     "Restart Required" and description `RESTART_REQ_DESC` "You must restart the game for these changes to take effect."
     [mod: localisation/misc.csv], brought to the front and added to the current screen's dialog list. Then
     EnableButtons, Refresh, and **slot 5 once**: in game, back to the menu's six buttons with the dialog over them.
   - **Written, no restart**: EnableButtons, **slot 5**, Refresh, **slot 5 again** (`0x6F7BD7`, `0x6F7BB6`). The first
     CloseMenu goes back to the panel; the second finds no subwindow up and **closes the menu**, leaving the game paused
     (ToggleMenu's reopen re-read +0x1D3E while paused). The double call is confirmed off the bytes, and **the menu's
     going is confirmed by the maintainer in the original, 2026-11-04**: a checkbox changed and Apply pressed, "it goes
     away".
   - **Write failed**: a `DefaultInfoDialog` titled `SM_ALERT` "Alert", described `SM_WP` "Error writing to the
     settings-file. Check that the file is not write protected and try again" [mod: frontend.csv], through
     CEU3Idler::AddDialog. The buttons are re-enabled and **the window stays open**, but the choices are already in force
     for the session.
- **When the restart notice comes**: only for a changed resolution, refresh rate or multisampling [exe].
  `SettingsMustRestartWindow` (file text `SM_RESTART`) never appears.

### A.7 BackButton, closing, Escape

- **BackButton** goes through glue +0x158 -> the shared thunk `0x6FB9A0` (`jmp [[ecx]+0x14]`) -> slot 5. In game that is
  `CIngameSettingsScreen::Close`: it puts the saved volumes back (undoing an unapplied slider), then calls
  `CloseMenu(fromCustomGame)` - 1 only where a custom game's setup is under way (custom game settings byte 0 set and +0x18
  below 2; +0x18 as "stage" is inferred). CloseMenu finds the screen up, hides the menu and the screen, and reopens the
  menu on its six buttons.
- **What Back leaves behind**: unapplied Video/Audio/Controls choices are **dropped** - the next Show's Refresh re-reads
  them from settings. The **autosave choice is kept unapplied** and shown again next time; any later Apply commits it.
- **Escape** (*inferred*): settings.gui has no `shortcut` anywhere, so BackButton has none. Escape with the window up
  reaches CloseMenu(0) either through HandleInput -> ToggleMenu, or through the hidden `menu_close_button`'s ESCAPE.
  Either way it goes back to the six buttons **without** Close's volume restore; a moved volume then stays in settings
  and becomes the next Show's baseline.

### A.8 Tooltips and greying

- **No tooltips**: every `tooltip*` key in settings.gui is empty, and no tooltip routine names a settings element. The
  string search finds each settings name referenced only inside 0x6F5C00-0x6FB9B0; the positive control is that the
  same search finds `message_setting_item` in GetElementTooltip. GetElementTooltip has no arm for idler +0x1D2C (the
  0x1D2C reference census has none in it).
- **Greying**: none by the window's own code, except the transient disable of Back and Apply inside Apply. The autosave
  buttons are never greyed (each name has one reference, in the constructor).

### A.9 The Game tab whole

- **The values**: the autosave frequency enum (`FINDINGS-autosave.md`), 0 NEVER, 1 WEEKLY, 2 MONTHLY, 3 HALFYEAR, 4
  YEARLY, 5 FIVE_YEAR [exe].
- **The buttons**: `increase_autosave_button` steps up, **5 wraps to 0**; `decrease_autosave_button` steps down, **0
  wraps to 5** [exe: `cmp eax,6; cmovge` / `jns; mov eax,5`].
- **The text**: `autosave_value` shows `GetText(AutosaveFrequency_ToString(v))` in the settings' text colours. The keys
  are the enum's own names: NEVER "Never", WEEKLY "Weekly" (only in SemperFi.csv), MONTHLY "Monthly", HALFYEAR "Half
  Year", YEARLY "Yearly", FIVE_YEAR "Five Years" [mod: localisation/misc.csv, SemperFi.csv].
- **When the choice reaches settings `+0x15C`**: only on Apply (StoreChoices, `0x6F8189`); from then the daily autosave
  check uses it, and the writer puts it in `settings.txt`. Before Apply it lives only in the screen's +0x36C, read from
  +0x15C once, at construction.
- **The oracle**: the maintainer's settings.txt has `autosave="MONTHLY"`, `debug_saves=0`.

### A.10 What looks wrong and is the original's - do not tidy

- Apply without a restart calls slot 5 twice and closes the whole menu (confirmed in the original by the maintainer).
- An unapplied autosave choice survives Back and is applied by a later Apply.
- Escape skips the volume restore that Back does.
- The current-refresh search reads entry 0's rate list (inferred effect).
- Glue +0x184 (EnableButtons) is attached to nothing.
- `SettingsMustRestartWindow` is dead file content.

### A.11 Not established

- What the window's slot 11 does (Show calls it).
- Custom game settings +0x18 as "stage" (inferred).
- Whether the interface marks Escape handled.
- Front end: settings +0x174, the views array (+0x750/+0x760) and what view 0 is.
- 0xA76810 (gamma) and 0x63D4B0 (CEU3Dialog's constructor) - not read.

### A.12 How `CFrontendSettingsScreen` differs

The same base class on the front end's `menu_settings` window [mod: settings.gui], built where the front end is made
(`0x6F3B98`, 0x3E8 bytes), with a second base `CFrontEndView` at +0x3DC whose slots 0, 2, 3 and 4 are thunks to the
destructor, Show, Hide and the volume copy. Its slot 5, `CFrontendSettingsScreen::Close` (`0x6FB620`), is its Back and
the end of its Apply: it hides itself and restores the saved volumes, clears settings `+0x174`, and switches the front
end (+0x3E4) back to view 0 (*inferred*: the main menu). There is no menu to return to, no CloseMenu and no pause. Tabs,
Apply, the restart and error dialogs, the Game tab and its wrapping are the same code. Apply's double slot 5 there only
hides twice (*inferred* harmless). Ghidra's RTTI label `CSettingsScreen::CSettingsScreen` on `0x6FB500` is in fact the
destructor body.

## B. The Video tab (`menu_settings_VIDEO`)

*Reader B. Read 2026-11-04: the handlers, `InitVideoTab`, `ShowDisplayMode`, StoreChoices, Refresh, the graphics
settings' loader, constructor and enumeration, and `CGraphics_SetGamma` decompiled headless from a copy of the Ghidra
project with the record applied, every number then checked in the listing; constants read with `image.read`,
`settings.txt` token ids resolved with `ghidra/saveTokens.json`. Addresses are VAs unless marked rva. **[exe]** is
hardcoded in the executable, **[mod: file]** a file may change it.*

**Synopsis.** The aim was the Video tab whole - where its three lists come from, what each button and slider does,
which setting and `settings.txt` key each control holds, and whether it applies at once, on Apply or after a restart. All
of it is settled. The resolutions and refresh rates are the adapter's own modes, enumerated at startup; multisampling
steps through a fixed table of sample counts 2 to 16, checked against the card at startup. Resolution, refresh rate and
multisampling need a restart; gamma changes on screen while the slider moves; the other two sliders and the five
checkboxes take effect at Apply. **Revised**: `GraphicsSettings_DetectDevice` (rva `0x6A3DD0`) now also says it fills
the multisampling table and holds the configured level to what the card supports, its old content kept whole. Two bugs
of the original's turned up: the opening refresh-rate search walks the wrong mode's list, and Back leaves an unapplied
gamma on screen.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| 0x2F6E00 | CSettingsScreen::InitVideoTab | new | confirmed | finds the 3 sliders and 4 checkboxes and hangs their observers on them; `counters_checkbox` gets none |
| 0x2F8620 | CSettingsScreen_ShowDisplayMode | new | confirmed | writes `1920x1080` / `1920x1080 (1600x900)` and `60 Hz` / `60 Hz (75 Hz)`; `ret 4` |
| 0x2FA5B0 | CSettingsScreen::OnDecreaseResolution | new | confirmed | mode index -1, wraps first to last, refresh index back to 0 |
| 0x2FA600 | CSettingsScreen::OnIncreaseResolution | new | confirmed | mode index +1, wraps last to first, refresh index back to 0 |
| 0x2FA650 | CSettingsScreen::OnDecreaseRefreshRate | new | confirmed | -1 within the chosen mode's own rates, wraps |
| 0x2FA690 | CSettingsScreen::OnIncreaseRefreshRate | new | confirmed | +1 within the chosen mode's rates, wraps |
| 0x2FA6D0 | CSettingsScreen::OnDecreaseMultisample | new | confirmed | next lower supported level; lowest goes to 0, 0 goes to the highest |
| 0x2FA890 | CSettingsScreen::OnIncreaseMultisample | new | confirmed | next higher supported level; 0 goes to the lowest, the highest goes to 0 |
| 0x2FAA40 | CSettingsScreen::OnWaterCheckbox | new | confirmed | flips +0x345 (advanced water) |
| 0x2FAA60 | CSettingsScreen::OnHierarchyCheckbox | new | confirmed | flips +0x346 |
| 0x2FAA80 | CSettingsScreen::OnUnitNameCheckbox | new | confirmed | flips +0x347 |
| 0x2FAAA0 | CSettingsScreen::OnTreesCheckbox | new | confirmed | flips +0x344 |
| 0x2FAAC0 | CSettingsScreen::OnGammaSlider | new | confirmed | clamps to 0..100 and calls SetGamma(v/50) at once; stores nothing |
| 0x2FABE0 | CSettingsScreen::OnCounterSlider | new | confirmed | 0..100 into +0x3D4 (distance = v x 5 at Apply) |
| 0x2FACF0 | CSettingsScreen::OnCounterScaleSlider | new | confirmed | 0..2 into +0x3D8 |
| 0x676810 | CGraphics_SetGamma | new | confirmed | linear ramp `i*trunc(g*65535)/255`, g clamped to 0.1..1.9, then SetGammaRamp; g in XMM0 (no_signature) |
| 0x6A6570 | GraphicsSettings_LoadKey | new | confirmed | the `graphics={}` block: keys, offsets, minimum 1024x768 |
| 0x6A3B70 | GraphicsSettings_Construct | new | confirmed | defaults: desktop size, 60 Hz, full screen, vsync, gamma 50, shadow size 2048 |
| 0x6A6D30 | GraphicsSettings_AddDisplayMode | new | confirmed | adds a mode, or appends a rate to an existing one; no sorting, no duplicate test |
| 0x6A6E10 | GraphicsSettings_EnumerateDisplayModes | new | confirmed | adapter 0, X8R8G8B8, only modes at least 1024x720 |
| 0x6A7010 | GraphicsSettings_ValidateResolution | new | inferred | device creation's check of the size against the list; full-screen fallback 1024x768 |
| 0x6A7960 | GraphicsSettings_SnapRefreshRate | new | confirmed | the refresh rate becomes the nearest the mode offers |
| 0x6A3DD0 | GraphicsSettings_DetectDevice | revised | inferred | adds: slot 6 of the no-RTTI table VA 0x1600624, the adapter clamp, the multisampling table fill and level clamp; ECX receiver in no_signature |

Globals, new and confirmed: rva `0x130A100` `g_MultisampleLevels` (MultisampleLevel[15]), `0x130AEB0`
`g_SettingsPendingDisplayMode`, `0x130AEB4` `g_SettingsPendingRefreshRate`, `0x130AF84` `g_CounterScale` (float).

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| DisplayMode (declared, 0x18) | 0x0 / 0x4 / 0x8 / 0xC | width / height / refresh_rates / refresh_rates_end | int / int / int* / int* | new |
| MultisampleLevel (declared, 0xC) | 0x0 / 0x4 / 0x8 | samples / supported / max_quality | int / bool / int | new |
| GameSettings | 0x14 / 0x18 | display_modes / display_modes_end | DisplayMode* | new |
| GameSettings | 0x40 / 0x44 | size_x / size_y | int | new |
| GameSettings | 0x48 | refresh_rate | int | new |
| GameSettings | 0x54 | multi_sampling | int | new |
| GameSettings | 0x5C | gamma | float | new |
| GameSettings | 0xE4 / 0xE5 / 0xE6 | render_trees / simple_water / waves | bool | new |
| GameSettings | 0xEA | unit_names_changed | bool | new |
| CGraphics | 0x60 / 0x64 / 0x6BC48 | d3d / d3d_device / graphics_settings | void* | new |
| CSettingsScreen | 0x110 / 0x114 / 0x118 | chosen_display_mode / chosen_refresh_rate / chosen_multisampling | int | new |
| CSettingsScreen | 0x328 / 0x32C / 0x330 / 0x334 | trees_checkbox / water_checkbox / hierarchy_checkbox / unit_name_checkbox | void* | new |
| CSettingsScreen | 0x338 / 0x33C / 0x340 | gamma_slider / counter_slider / counter_scale_slider | void* | new |
| CSettingsScreen | 0x344 / 0x345 / 0x346 / 0x347 | trees_ticked / advanced_water_ticked / hierarchy_ticked / unit_names_ticked | bool | new |
| CSettingsScreen | 0x3D4 / 0x3D8 | counter_distance_choice / counter_scale_choice | float | new |

**The oracle**: the maintainer's `settings.txt` has `size 1920x1080`, `refreshRate=144`, `multi_sampling=0`,
`gamma=50`, `renderTrees=no`, `simpleWater=yes`, `alwaysCounters=yes`, `counter_distance=500`, `counter_scale=2`,
`render_hierarchy=yes` and `show_unit_names=yes` - all within the ranges below, the two counter values at their sliders'
maximums. Nothing was run.

### B.1 Where the resolutions and refresh rates come from

- **The adapter's modes, not a fixed table.** CGraphics' constructor calls `GraphicsSettings_EnumerateDisplayModes`
  (`0xAA6E10`): `IDirect3D9::GetAdapterModeCount`, then `EnumAdapterModes`, always on **adapter 0** in **D3DFMT_X8R8G8B8**
  [exe] - the `adapter` key of `settings.txt` is ignored here - keeping every mode **at least 1024 wide and 720 high**
  [exe], each logged as `Usable res: `.
- `GraphicsSettings_AddDisplayMode` (`0xAA6D30`) builds the list: a new width-and-height pair is a new entry, a pair
  already there gets the rate appended to its rates. **No sorting and no duplicate test** [exe]: modes and rates come in
  the driver's order (that D3D9 drivers usually list them ascending is outside knowledge, not checked).
- The list lives at GameSettings +0x14/+0x18, each a 0x18-byte DisplayMode `{width, height, vector of rates}`; it is not
  saved.
- **A change of resolution narrows the refresh rates**: each mode carries only its own rates, and both resolution
  buttons reset the refresh choice to the new mode's first [exe].

### B.2 Resolution and refresh rate: buttons, text, Apply

- **Buttons.** `decrease_`/`increase_resolution_button` move the chosen mode (+0x110) by one and **wrap at both ends**
  [exe], setting the refresh choice (+0x114) to 0; `decrease_`/`increase_refreshrate_button` move +0x114 by one within
  the chosen mode's rates and **wrap** [exe]. None of the four is ever greyed [exe].
- **Text.** `CSettingsScreen_ShowDisplayMode` (`0x6F8620`) builds it with itoa and no localisation [exe]: `{w}x{h}` and
  `{r} Hz`; while a restart is pending a bracket is added - `1920x1080 (1600x900)`, `60 Hz (75 Hz)` - holding the last
  applied choice, kept in `g_SettingsPendingDisplayMode` / `g_SettingsPendingRefreshRate`, which start at -1, are written
  only by Apply and last the whole process.
- **Opening the window.** `CSettingsScreen_Refresh`, on every opening, sets +0x110 to the mode matching the running
  screen size (CGraphics +0x6B9BC/+0x6B9C0), else 0 - so a windowed screen of an unlisted size shows the first mode - and
  +0x114 to the saved `refreshRate`'s index, but **searched in the first mode's rate list while bounded by the chosen
  mode's count** (`0x6F949E`) [exe bug]: where the two lists differ, the rate shown is not the saved one. Apply's search
  for the running rate has the same slip (`0x6F7425`).
- **Apply** (`CSettingsScreen::OnApply`, section A) always writes the chosen width, height and rate to GameSettings
  +0x40/+0x44/+0x48 (`size x/y`, `refreshRate`); where the chosen mode or rate differs from the running one it sets the
  pending globals and asks for a restart. **Nothing resets the device: these take effect only at the next start** [exe].
- **At the next start**: `GraphicsSettings_LoadKey` raises a width under 1024 to 1024 and a height under 768 to 768
  [exe]; `GraphicsSettings_ValidateResolution` checks the size against the list - in full screen an unlisted size falls
  back to 1024x768 with a log line, windowed keeps it (*inferred* in part); `GraphicsSettings_SnapRefreshRate` replaces
  the refresh rate with the nearest the mode offers, first of equals [exe].
- The window has no full-screen, vsync, shadows or anisotropy control; those keys are only in `settings.txt`.

### B.3 Multisampling

- **A fixed table**: `g_MultisampleLevels` (VA `0x170A100`), sample counts 2..16, 15 entries `{samples, supported,
  max_quality}` [exe]. At startup `GraphicsSettings_DetectDevice` calls `CheckDeviceMultiSampleType` for each count (HAL,
  X8R8G8B8, windowed = not `fullScreen`), marking each that succeeds supported; a configured `multi_sampling` that is not
  supported is logged and set to 2, and after the loop held to the highest supported count [exe].
- **Buttons** step only through supported counts, 0 meaning off [exe]: increase 0 -> lowest -> ... -> highest -> 0;
  decrease the same backwards. A configured value not in the table counts as the first entry.
- **Text.** `multisample_value` is the bare number (`0`, `2`, `4`, `8`), no localisation and no "off" [exe].
- **Greying.** Where no count is supported, Refresh disables both buttons [exe], and never enables them again.
- **On opening** the choice is `multi_sampling` if that is >= 2 and supported, else 0; no bounds check above 16.
- **Apply** writes GameSettings +0x54 only where the choice differs, and that **asks for a restart** [exe].

### B.4 Gamma (`gamma_slider`)

- **Range and step**: 0-100, step 1 [mod: interface/settings.gui], also clamped to 0..100 in code [exe]; the
  `startValue` of 20 is overwritten on opening.
- **Setting**: `graphics.gamma` (GameSettings +0x5C, a float), default 50 [exe].
- **Meaning** (`CGraphics_SetGamma`, `0xA76810`): g = value / 50, clamped to 0.1..1.9; each of the 256 ramp entries of
  all three channels is `i * trunc(g * 65535) / 255`, held to 0..0xFFFF, sent to `IDirect3DDevice9::SetGammaRamp(0,
  D3DSGR_CALIBRATE, ...)` [exe]. So 50 is the identity, 0-5 all give 0.1 and 95-100 all give 1.9: **a linear brightness
  scale, not a power curve** [exe]. (D3D9 applies a gamma ramp only in full screen - Direct3D's documentation, not this
  image.)
- **Timing**: **on screen at once, at every change** [exe], but not stored; Apply stores it and sets it again. **Back
  does not undo it**: `CIngameSettingsScreen::Close` restores the volumes and not the gamma; the saved gamma comes back
  only when the window is next opened, Refresh setting the slider and so firing its observer [exe; that the preview
  otherwise stays is *inferred* from both close paths having no gamma call]. No restart.
- End buttons, Shift x10 and Ctrl x100 as `FINDINGS-scrollbar.md`; dragging was not read.

### B.5 Counter distance (`counter_slider`, labelled `slider_label`) and counter scale (`counter_scale_slider`)

- **`counter_slider` is the counter distance** (label `SM_COUNTER_SLIDER`, "Counter Dist.", static gui text [mod:
  localisation]). The bar is 0-100, step 1 [mod: gui], also clamped in code [exe]; **`counter_distance` = value / 100 x
  500** [exe] - so the bar covers 0-500, the default 100 at 20 (the file's `startValue`), the maintainer's 500 at the
  maximum. Key `mapRenderingOptions.counter_distance` (GameSettings +0xFC).
- **`counter_scale_slider`** ("Counter hierarchy scale") is 0-2, step 0.1 [mod: gui], clamped to 0..2 in code [exe]; it
  writes `counter_scale` (+0x100) and the global `g_CounterScale`, which every counter is drawn and hit-tested through.
- **Timing**: both held in the window until Apply, then shown the next frame (the drawing reads both each frame); no
  restart [exe].
- **Quirk**: Refresh writes the raw distance into +0x3D4 before the slider's observer puts the 0..100 value back, so a
  mod's `settings.gui` without `counter_slider` makes every Apply multiply the distance by 5 [exe].

### B.6 The five checkboxes

**Ticked** is the setting on - except `water_checkbox`, ticked meaning "Advanced Water", `simpleWater=no`. All five are
**applied at Apply, take effect at once, and need no restart**.

| checkbox (label) | key in `mapRenderingOptions` | GameSettings | what follows at Apply |
| --- | --- | --- | --- |
| `counters_checkbox` (SM_COUNTERS "Use Counters") | `alwaysCounters` | +0xF9 | read from the checkbox's own state (it has no observer); the camera notices the next frame (UpdateMapCamera compares its copy at `0x63C569`); every province's weather picture is marked to be made again |
| `hierarchy_checkbox` (SM_HIERARCHY) | `render_hierarchy` | +0xE8 | the frame routine reads it |
| `unit_name_checkbox` (SM_UNIT_NAMES) | `show_unit_names` | +0xE9 | where it changed, +0xEA is set, and the next frame (`0x641D00`) has every unit's counter name made again (`0x689E30` -> CUnit_RefreshCounterName) |
| `trees_checkbox` (SM_TREES) | `renderTrees` | +0xE4 | also sets or clears bit 0 of the layer mask +0xEC, read each frame |
| `water_checkbox` (SM_WATER "Advanced Water") | `simpleWater`, inverted | +0xE5 | read where the water is drawn (`0x85FB0F`); that this is each frame is inferred |

Constructor defaults [exe]: trees yes, simple water no, waves yes, hierarchy yes, unit names no, always counters no,
distance 100, scale 1.

### B.7 Which controls apply when

| control | setting | applied | needs a restart |
| --- | --- | --- | --- |
| resolution | `graphics.size` | written at Apply | **yes** |
| refresh rate | `graphics.refreshRate` | written at Apply | **yes** |
| multisampling | `graphics.multi_sampling` | written at Apply, only where it changed | **yes** |
| gamma | `graphics.gamma` | shown at once while moving; saved at Apply | no |
| counter distance, counter scale | `counter_distance`, `counter_scale` | at Apply | no |
| the five checkboxes | B.6 | at Apply | no |

Every opening drops choices not applied, Refresh setting every control from the settings. The restart notice is
section A's `DefaultInfoDialog` with RESTART_REQ / RESTART_REQ_DESC; `SettingsMustRestartWindow` is never used.

### B.8 Tooltips and labels

**The code sets no tooltip on any element of this tab** [exe]: every string referenced from `0x6F5B40`-`0x6FC000` was
listed, and it finds only element names, `DefaultInfoDialog`, `RESTART_REQ*`, `SM_ALERT`, `SM_WP`, `x` and the three
` Hz` strings - the positive control, the same scan finding all 25 element names the window is known to use. The gui
file's tooltip fields are all empty [mod: interface/settings.gui]. The labels (`SM_RESOLUTION`, `SM_REFRESH_RATE`,
`SM_MULTISAMPLE`, `SM_GAMMA`, `SM_COUNTER_SLIDER`, `SM_COUNTER_SCALE`, `SM_COUNTERS`, `SM_HIERARCHY`, `SM_UNIT_NAMES`,
`SM_TREES`, `SM_WATER`) come from the gui file [mod: localisation].

### B.9 What looks wrong and is the original's - do not tidy

1. The opening and Apply refresh-rate searches walk mode 0's rates.
2. A gamma preview survives Back.
3. Without `counter_slider` the counter distance multiplies by five at each Apply.
4. Modes come only from adapter 0, at least 1024x720, in driver order; the `adapter` key is ignored here.
5. Multisampling's text is a bare number, and there is no bounds check above 16 when reading the setting.
6. `InitVideoTab` dereferences the four checkboxes and the gamma slider without a null test, so a `settings.gui`
   missing one likely crashes (*inferred*).

### B.10 Not established

- Whether D3D9 drivers enumerate in ascending order (outside knowledge).
- What a scrollbar drag does to the step.
- `ValidateResolution`'s full-screen not-found branch past its log line (decompiler only), and which caller passes
  `lowestRefresh`.
- What the checkbox setter's test, used when unticking, means.
- Not recorded, for a later wave: the no-RTTI graphics-settings table at VA `0x1600624` (rva `0x1200624`; slots
  `0xAA3D70`, `0x45BB10`, `0xAA6AB0`, `0xA7C050`, `0xAA6570`, `0xABF890`, `0xAA3DD0`).

## C. The Audio and Controls tabs, and the writer of `settings.txt`

*Reader C. Read 2026-11-04, statically. Addresses are VAs unless marked rva. **[exe]** is hardcoded in the executable,
**[mod: file]** a file may change it.*

**Synopsis.** The aim was the Audio and Controls tabs whole and the writer of `settings.txt`; both are settled. The
three volume sliders reach the settings every frame the window is up, and `CEU3Application::Run` applies them every
frame, so a volume is heard as it moves; scroll speed, zoom speed and `legacy_camera_checkbox` reach the settings only on
Apply - and nothing ever sets the legacy-camera box from the settings, so Apply with the box as the .gui leaves it turns
`use_legacy_camera` off. The writer is `CSystemSettings_SaveToFile` (rva `0x6B1CE0`), through three SaveContents bodies
and the graphics and gui block writers, and the order of keys it writes is the maintainer's file's exactly. **A
correction raised and not made**: the 16 bytes `GameSettings_GetTextColours` copies (settings +0x6C..+0x7B, the record's
"text colours") begin with the **language enum** of the gui block, so `CInternationalizedText::Render` is handed the
language and the "colours" reading is suspect - not chased into Render.

| rva | name | new or revised | confidence | one line |
| --- | --- | --- | --- | --- |
| 0x2F6AB0 | CSettingsScreen::InitAudioTab | new | confirmed | finds the 3 volume sliders into +0x348/+0x34C/+0x350; attaches no observer |
| 0x2F6CA0 | CSettingsScreen::InitControlsTab | new | confirmed | finds scroll/zoom sliders into +0x35C/+0x364; the legacy checkbox is looked up nowhere but StoreChoices |
| 0x6B1CE0 | CSystemSettings_SaveToFile | new | confirmed | **the settings.txt writer**: VirtualFile_Open(+0xC0, write, text), CSaveWriter, this's slot 2; 5 callers |
| 0x6B19E0 | CSystemSettings::SaveContents | new | confirmed | gui, graphics, 8 floats `%f`, `pause_on_event=no` only when clear |
| 0x6B17D0 | CSystemSettings::LoadKey | new | confirmed | the 11 base keys (CSettings::LoadKey's default case) |
| 0x6B16A0 | CSystemSettings::CSystemSettings | new | confirmed | defaults: volumes 100, the other five floats 50, +0xC0 = `settings.txt` |
| 0x6B2710 | CSettings::ResetSoundAndControls | new | inferred | slot 6, resets the same defaults; no caller found |
| 0x60530 | CSettings::SaveContents | new | confirmed | the whole file: base, then mapRenderingOptions .. outliner |
| 0x5FA80 | CSettings::CSettings | new | confirmed | the singleton's constructor and its defaults |
| 0x5F770 | CMapRenderingOptions::SaveContents | new | confirmed | the 9 keys in file order; offsets agree with the record's fields |
| 0x6A6AB0 | GraphicsSettings_SaveContents | new | confirmed | the graphics block, plus `adapter`/`vsync`/`debugmonitor` only off their defaults (class name unknown) |
| 0x742050 | GuiSettings_SaveContents | new | confirmed | `language` from 13 l_* tokens, `has_set_language` only when set |
| 0x2496E0 | CInGameIdler::~CInGameIdler | new | confirmed | writes settings.txt every time a game is left (only its opening was read) |
| 0x601D0 | CSettings::LoadKey | revised | confirmed | comment only: the default case goes to the base, where each key lands, the serveradress `localhost` refusal (inferred) |
| 0x5FF30 | GetGameSettings | revised | confirmed | signature added (`CSettings* __cdecl ... @EAX`), lazy build through CSettings::CSettings |
| 0x23C520 | UpdateMapCamera | revised | confirmed | comment adds zoom/scroll speed arithmetic and the three use_legacy_camera branches; no_signature gains one sentence |
| 0x690F90 | CEU3Application::Run | revised | inferred (unchanged) | comment adds the per-frame effect/music volume and mouse_speed application |

| struct | offset | name | type | new or revised |
| --- | --- | --- | --- | --- |
| GameSettings | 0x6C | language | int | new |
| GameSettings | 0x7C | has_set_language | bool | new |
| GameSettings | 0x80 | master_volume | float | new |
| GameSettings | 0x84 | sound_fx_volume | float | new |
| GameSettings | 0x88 | music_volume | float | new |
| GameSettings | 0x8C | ambient_volume | float | new |
| GameSettings | 0x90 | scroll_speed | float | new |
| GameSettings | 0x94 | camera_rotation_speed | float | new |
| GameSettings | 0x98 | zoom_speed | float | new |
| GameSettings | 0x9C | mouse_speed | float | new |
| GameSettings | 0xA1 | pause_on_event | bool | new |
| GameSettings | 0xC0 | file_name | Hoi3CString | new |
| GameSettings | 0x104 | last_player | Hoi3CString | new |
| GameSettings | 0x120 | last_host | Hoi3CString | new |
| GameSettings | 0x13C | server_address | Hoi3CString | new |
| GameSettings | 0x174 | simple | bool | new |
| GameSettings | 0x178 | categories | std::vector<int> | new |
| GameSettings | 0x188 | use_legacy_camera | bool | new |
| CSettingsScreen | 0x348 | mastervolume_slider | CScrollbar* | new |
| CSettingsScreen | 0x34C | effectvolume_slider | CScrollbar* | new |
| CSettingsScreen | 0x350 | musicvolume_slider | CScrollbar* | new |
| CSettingsScreen | 0x35C | scrollspeed_slider | CScrollbar* | new |
| CSettingsScreen | 0x364 | zoomspeed_slider | CScrollbar* | new |

vftable_slots: CSettings 2 SaveContents and 6 ResetSoundAndControls; CMapRenderingOptions 2 SaveContents.

### C.1 The Audio tab: three volumes, heard as they move

`menu_settings_AUDIO` holds `mastervolume_slider`, `effectvolume_slider` and `musicvolume_slider`, each a scrollbar with
`minValue 0`, `maxValue 100`, `stepSize 1` and `startValue 20` [mod: interface/settings.gui]. The labels
`SM_MASTER_VOLUME`, `SM_EFFECT_VOLUME`, `SM_MUSIC_VOLUME` ("Master Volume", "Effect Volume", "Music Volume") are static
text [mod: interface/settings.gui, localisation]; the code never names them.

- **The setting each holds** [exe]: master settings `+0x80` (`master_volume`), effect `+0x84` (`sound_fx_volume`), music
  `+0x88` (`music_volume`) - each a float from 0 to 100, not thousandths.
- **Set-up.** `CSettingsScreen::InitAudioTab` (VA `0x6F6AB0`) finds the three sliders into +0x348/+0x34C/+0x350 and
  attaches **no observer** - unlike the Video tab's set-up, which attaches observers to `trees_checkbox` and
  `gamma_slider`.
- **When the window is filled**, `CSettingsScreen_Refresh` (`0x6F9370`) sets each slider to `floor((v + 0.0005) * 1000)`
  thousandths through the slider's +0x48 slot 7, and stores the three as the saved copies (+0x3C8..+0x3D0).
- **Greying** [exe]: where `master_volume < -0.01`, all three sliders are switched off (the scrollbar's byte +0x253 = 1
  and its +0xA0 slot 47). No writer of a negative value exists in the image, so only a hand-edited `settings.txt` does it.
- **At once.** While the window is up, `UpdateTutorialAndAuxWindows` calls slot 4, `CSettingsScreen::UpdateVolumes`,
  **every frame**, copying the three positions into +0x80/+0x84/+0x88.
- **Applied every frame.** `CEU3Application::Run` reads the settings every frame through the application's +0xEC
  (*inferred* to be the settings, by layout) and sends [exe]: effects at `master/100 x sound_fx/100` to the sound
  singleton (VA `0x1B167C4`, a CNullSound until a device replaces it; its slot 20); music at `master/100 x music/100` to
  the music singleton (VA `0x1B16808`, a CNullMusic until replaced; its slot 7) - each only when it differs from the last
  sent. **So a volume is heard the frame after the slider moves, before Apply.**
- **Music starts.** Where master is <= 0, four music-start sites skip starting a track (`0x60B9AC`, `0x630DDD`,
  `0x654046`, `0x6EDE6D` compare it with 0.0).
- **Apply** (`StoreChoices`, `0x6F80A0`) writes the three again and makes them the saved copies. **Back** (in-game
  Close, `0x6FB8D0`) puts the saved copies back, so an unapplied volume reverts.
- **Step.** A button press moves 1, Shift x10, Ctrl x100 (`FINDINGS-scrollbar.md`, whose keys are partly inferred there).
  Whether dragging gives fractions was not read; the maintainer's files hold whole numbers only.

### C.2 The Controls tab: scroll and zoom speed, on Apply only

`scrollspeed_slider` and `zoomspeed_slider` are 0..100, step 1, start 20 [mod: interface/settings.gui], with the labels
`SM_SCROLL_SPEED` and `SM_ZOOM_SPEED`.

- **Set-up.** `CSettingsScreen::InitControlsTab` (`0x6F6CA0`) keeps them at +0x35C/+0x364, with no observer. Refresh sets
  them from settings `+0x90` (`scroll_speed`) and `+0x98` (`zoom_speed`).
- **Apply only.** Only StoreChoices writes them back, raising scroll speed to **5** where it is <= 5 and zoom speed to
  **1** where it is <= 1 [exe] (`fcompi`/`jbe` against the floats at VA `0x160A2EC` and `0x171DBAC`). Moving them does
  nothing until Apply. Back leaves the settings untouched, and the sliders stay where they were dragged until the next
  Refresh.
- **What they do** (`UpdateMapCamera`, rva `0x23C520`) [exe]:
  - **zoom step** = `height / 60 x 0.8 x zoom_speed / 100`; a wheel notch in takes `step x 20 x 0.75` off the wanted
    height (floor 40), a notch out adds `step x 20 x 1.5` (ceiling 1000) - a notch out is twice a notch in;
  - **scroll step** = `min(t, 0.2) x scroll_speed / 100 x 12 x height / 40`, t the function's fourth stack argument,
    *inferred* the frame's seconds; which scrolls use it, `FINDINGS-camera.md` says all of them.

### C.3 `legacy_camera_checkbox` (`use_legacy_camera`, settings +0x188)

Ticked means `use_legacy_camera = yes`; at Apply the box's +0x60 == 1 is copied into +0x188 [exe]. Its three readers are
all in UpdateMapCamera:

- **unset (the new camera)**: a wheel zoom that changes the height also pulls the look point toward the map point under
  the mouse, by `1 - zoomstep x 20 / height` of the distance, when the mouse is more than 6 px inside the view; the
  camera's position eases toward its target, 0.197 of the way a frame (VA `0x160AA40`); the height eases the same way;
- **set (legacy)**: the zoom is straight down at the centre, and position and height jump to their targets at once
  [exe].

**The checkbox is never set from the setting.** Its name has exactly one reference in the image, in StoreChoices; the
positive control is `counters_checkbox`, which has a second, Refresh setting it from +0xF9. It starts unticked from the
.gui, so a player with `use_legacy_camera=yes` who opens Options and presses Apply without ticking it turns it off, and
the file then says so (by the reading, not tried). The label is `USE_LEGACY_CAMERA`, "Use legacy camera".

**Tooltips: none, for any of the six controls.** The .gui gives empty `tooltip`, `tooltipText` and `delayedTooltipText`;
in code each element's name has its single reference in the finder (or in StoreChoices), the screen's +0x348..+0x364
are read only in the window's own code, and none of the idler's eight uses of its +0x1D2C is a tooltip handler.

### C.4 The writer of `settings.txt`

`CSystemSettings_SaveToFile` (VA `0xAB1CE0`, settings in ESI):

1. opens the file named by settings `+0xC0` with VirtualFile_Open (write, text, mode "") - PHYSFS_openWrite under the
   write directory, truncating;
2. wraps it in a CSaveWriter;
3. calls the settings' **slot 2** (SaveContents), so the top level has no braces;
4. closes the file. A file that will not open throws; OnApply calls the writer inside a try.

**Where.** The write directory is `Documents\Paradox Interactive\Hearts of Iron III\`; with a mod, the mod's user folder -
the maintainer's disk has both `settings.txt` and `BlackICE GitHub\settings.txt`, each in the writer's format and dated
today. Which one is read at start under a mod was not traced.

**When** (the five direct callers): Apply, in game and in the front end (`0x6F760F`); **every time a game is left**
(`CInGameIdler::~CInGameIdler`, `0x649789`); the outliner configuration's close (`COutLiner::OnConfigurationClose`); the
multiplayer lobby's CONNECTED handler (VA `0x708190`, after copying lastplayer, and lasthost when the global at VA
`0x1A85618` is 2); the login dialog's handler (VA `0x7CC280`, lastplayer). **Not** on Back, and not when the game is quit
from the main menu.

**Format** [exe]: floats as `%f` (six decimals, `55.000000`; **not thousandths**); ints as `%d`; bools as `yes`/`no`;
strings quoted; blocks as `key=` / `{` / ... / `}`, inner keys indented by depth - 1 tabs (so only `size`'s x and y carry
a tab). The maintainer's file has CRLF line ends and a blank line after `size`'s `}` - both observed, not read.

**Every key in the order written**, with the settings offset and the default where there is no file:

| # | key | field | default |
| --- | --- | --- | --- |
| 1 | `gui={ language=... [has_set_language=yes] }` | +0x6C enum 1..13 (english, french, german, polish, spanish, italian, swedish, czech, hungarian, dutch, portugese, russian, finnish); +0x7C, written only when set | l_english |
| 2 | `graphics={ size={x y} refreshRate fullScreen shadows shadowSize multi_sampling anisotropic_filtering gamma [adapter] [vsync=no] [debugmonitor=yes] }` | +0x40, +0x44, +0x48, +0x4C, +0x58, +0x60, +0x54, +0x50, gamma +0x5C `%f`; adapter +0x3C only when not 0; vsync +0x3A only when off; debugmonitor +0x3B only when on with adapter 0 | 1024x768, 60, yes, ... |
| 3-10 | `sound_fx_volume`, `music_volume`, `scroll_speed`, `camera_rotation_speed`, `zoom_speed`, `mouse_speed`, `master_volume`, `ambient_volume` | +0x84, +0x88, +0x90, +0x94, +0x98, +0x9C, +0x80, +0x8C | 100, 100, 50, 50, 50, 50, 100, 50 |
| 11 | `pause_on_event=no` | +0xA1, written **only when clear** | 1 (so absent) |
| 12 | `mapRenderingOptions={ renderTrees onmap simpleWater alwaysCounters counter_distance waves counter_scale render_hierarchy show_unit_names }` | +0xE4, +0xF8, +0xE5, +0xF9, +0xFC, +0xE6, +0x100, +0xE8, +0xE9 | yes, yes, no, no, 100, yes, 1, yes, no |
| 13-15 | `lastplayer`, `lasthost`, `serveradress` | +0x104, +0x120, +0x13C | "", "", "diplomacy.valkyrienet.com" |
| 16 | `debug_saves` | +0x158 `%d` | 0 |
| 17 | `autosave="..."` | +0x15C via AutosaveFrequency_ToString | YEARLY |
| 18 | `simple` | +0x174 (meaning not read) | yes |
| 19 | `use_legacy_camera` | +0x188 | no |
| 20 | `categories={ ... }` | vector<int> +0x178, written only if not empty (meaning not read) | six 0s |
| 21 | `outliner={ ... }` | CList +0x164 | 10 4 5 6 |

**Against the oracle**: the maintainer's file has exactly these keys in this order, and none of the conditional ones -
consistent with pause_on_event set, adapter 0, vsync on, debugmonitor off and has_set_language clear. Every
map-rendering offset from `CMapRenderingOptions::SaveContents` (object at +0xDC) lands exactly on the record's existing
fields; the graphics block's +8 shift agrees with OnApply (width +0x40, height +0x44, rate +0x48). Key names, order,
format and the file name `settings.txt` are all [exe].

### C.5 The reader and its defaults

- `CSettings::LoadKey` reads 10 keys and hands anything else to `CSystemSettings::LoadKey`, which reads 11 - gui,
  graphics, the 8 floats, pause_on_event. No value read is clamped. A serveradress of `localhost` keeps the old value
  (*inferred*: the sense of the compare at `0x40C3C0` was not read).
- `CSettings::CSettings` and `CSystemSettings::CSystemSettings` give the defaults in the table above [exe].
- `main.cpp` loads the file at VA `0xA58E7C` through VA `0xAB1E80`, with the name `settings.txt` or, when not empty, a
  string held in a local of main (*inferred* from the command line; not traced).
- `camera_rotation_speed` and `ambient_volume` have **no reader outside load and save** - a scan of 40 instructions
  after every fetch of the settings (GetGameSettings, g_GameSettings, CEU3Application +0xEC); the positive control, the
  same scan finds master_volume's four readers and UpdateMapCamera's reads of +0x90, +0x98 and +0x188.
- `mouse_speed` has no control in the window; Run sends `(int)(mouse_speed/100 x 4 + 1)` to the application's +0xE4
  slot 9 each frame [exe].

### C.6 Not established

- The caller of CSettings slot 6.
- What `simple` and `categories` mean.
- Which settings.txt is read at start under a mod.
- Whether dragging a slider gives fractional values.
- What CInternationalizedText::Render does with the language dword (the suspect "text colours").

Trap 2 pairs found: `0x6F6AAF`/`0x6F6AB0` (InitGameTab's `ret`, then InitAudioTab with no padding) and
`0x649D7F`/`0x649D80`.
