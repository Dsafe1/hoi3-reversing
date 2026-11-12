# FINDINGS-soundeffects.md: sound effects

*Read statically on 2026-11-12, for OpenHOI3's question of how the original plays its sound effects. Fragment
`sound-effects-2026-11-12.json`. Addresses are VAs unless a line says rva. `CEU3SoundConfigurator::LoadKey`'s call to the
base loader, the literal `interface/sound.sfx` and `SetEffectsVolume`'s arithmetic were checked again off the bytes by the
collecting session the same day.*

*The census behind section 6 is every direct `call 0xAAC690` (GetSound) in `.text`, an E8 scan, 86 sites; with all 34
references to `g_Sound` (VA 0x1B167C4), where the getter is inlined, and a census of code references to every sound name
string. Positive control: the method finds every play site already in the record - `CProvince::OnSelected`,
`CDiplomacyDialog::PlayOfferSound`, `CAlertManager_Show`, `CEventWindow::CEventWindow`, `CDeclareWarAction::Apply`, the
diplomatic actions, `CUnit::OrderToProvince`, `CCombatView::Update`. `click` alone has 55 references, so its silence about
anything else means something.*

**It corrects the record**: `CEU3SoundConfigurator::LoadKey` was recorded as knowing only `file` and dropping every other key
silently; its default case hands the key to a base loader that knows four more - `pitch`, `pan`, `voicetype` and `volume`
(`definitions.py` reads only the derived switch, and other rows of `FINDINGS-definitions.md`'s table may share the blind
spot). `LoadSoundEffects` goes from `likely` to `confirmed`, its interior read. It settles `FINDINGS-alerts.md`'s open item
and `FINDINGS-factionplay.md`'s "+0x64 / +0x24 inferred" - slot 25 is IsPlaying, slot 26 IsFading, slot 9 Play - and
`FINDINGS-selection.md`'s "whether an already-playing sound restarts": it is skipped.

## 1. The object

`g_Sound` holds a `CSound`; two classes derive from it, both with 29 slots and full RTTI: `CNullSound`, and
`CEU3DirectSound` (via `CDirectSound`). It is reached through `GetSound` (0xAAC690), which installs a `CNullSound` if the
global is null. `CEU3Application::LoadEverything` picks one of two arms: **the arm that installs `CNullMusic`** also installs
`CNullSound` (the store at 0x630B4A) - taken when settings.txt's `master_volume` is negative; **otherwise** it builds a
`CEU3DirectSound` (`CEU3DirectSound_Construct`, 0x632CF0), whose `CDirectSound` part (0xABC8C0) logs `Init DirectSound` and
`Sound initialised with result <hr>` (DirectSound.cpp) and creates the device. A string says "Failed to initialize sound.
Sound card not installed."; LoadEverything catches `CSoundException` (`FINDINGS-combat`); that a failed DirectSound start
falls back to the null object is *inferred*. The null object plays nothing: its Play slot is an empty stub and its IsPlaying
answers false.

## 2. interface/sound.sfx

**Which file.** `LoadSoundEffects` (rva 0x23A190, *confirmed*) reads exactly one file, the literal `interface/sound.sfx`,
through `Tokenizer::Tokenizer` and `VirtualFile_Open`, so the layered copy is used - a mod's overriding the install's
(*inferred*, as for music). Neither TFH nor the base game has a second .sfx file. The parse context is handed to the sound
object's slot 1.

**One key, one sound.** `CEU3DirectSound::LoadSounds` (slot 1, rva 0x4CE90) treats every top-level key as one sound, the key
its name, each built as a `CEU3SoundConfigurator` with `file` empty, `pitch` -1, `pan` 0, multi-voice 1 and `volume` 100, and
loaded by its LoadKey for each key and AfterLoad at the end.

| key | how it is read | effect |
| --- | --- | --- |
| `file` | a string | made into a path: the sound folder, `/`, the file; the folder by `CDirectorySettings` slot 7's mode - 1, the mod's; 2, the mod's if `<mod>/<file>` exists, else the base's; other, the base's. How tfh/ fits into the "base" is *not established* |
| `pitch` | ParseInt | `SetFrequency` on every voice, clamped 100..100000 - **a playback rate in Hz, not a ratio**; applied only when not -1 |
| `pan` | `%i` | `SetPan`, clamped -10000..10000; applied only when not 0; fixed per sound |
| `voicetype` | a string | **exactly `single`** (case-sensitive) gives one voice; **anything else, or no key, 64 voices** |
| `volume` | `%i` | base volume = volume × 0.01 (float); default 100 |

Any other key goes to ReportUnknownKey, an unparsable value to ReportParseError. **The base install uses only `file`.**

**AfterLoad** (rva 0x6AC4A0), in order: id = `g_SoundNextId` (0, 1, 2, … in file order); the sample loaded with that id
(`LoadSample`), its answer ignored; the name registered; the base volume set; frequency and pan, where given; the id advanced
- **even where the file failed to load**; `Loaded sound <path>` logged (sound.cpp).

**Names** (*confirmed*): matching is **case-insensitive** (a ternary search tree applying tolower on insertion and query); **on
a duplicate the first wins** (`Sound_RegisterName` logs `Duplicate sound: <name>` and changes nothing, the duplicate's sample
still loaded and using a slot); **a missing name gives id -1** (`Sound_NameToId` logs `Sound <name> not found.`, but for the
battle window, which logs `Attempting bad sound <name>` itself); **playing -1 does nothing**. Widgets resolve their names once,
when built (section 5), so a missing name is logged then and the widget stays silent.

**Faults found while reading** (*inferred* from the failure path, 0xABDA61..0xABDA96; neither can happen with the shipped
files): a sound whose wav fails to load leaves its id unmapped in a zeroed map, so it would play **sample 0**; and slots 15,
16 and 22 take the id as a sample index directly while only successful loads advance the sample count, so **every sound after
a missing file gets its neighbour's volume, pitch and pan**.

## 3. Voices and playing

**Samples.** `LoadSample` (slot 2) accepts at most **512 samples**; a path already loaded is shared through
DuplicateSoundBuffer, and a 64-voice sample gets copies 1-63 the same way.

**Starting a sound.** `PlayEx` (slot 4, rva 0x6BD030), the only function that starts one, *confirmed*: nothing where sound is
disabled, the id negative or the sample has no buffer; else (1) a voice - a 64-voice sample takes the first copy not playing,
**copy 0 restarting** when all 64 are busy; a `single` sample restarts its one voice; (2) volume = (int)(the voice's effective
volume × 10000) − 10000, in hundredths of a dB; (3) rewind to 0 and play, looping only with loop = 1. `Play` (slot 9) is
PlayEx(id, loop 0, 10000, 0x80), the 0x80 unused. **No call site in the game loops a sound.**

**"Unless already playing."** IsPlaying (slot 25) is true while **any** voice of the sample plays, and almost every play site
is "IsPlaying, else Play" (section 6): a sound triggered while still playing is **skipped**, not restarted and not overlapped
- a box-select of 20 units plays `army_selected` once. The exceptions call Play directly and overlap, up to 64 voices: the
event window's `message`, the window up/down sounds and a button's up/down/over sounds. **Different sounds always mix freely.**

**Variants.** `CSound::PlayRandomOf2..5` (CRT rand() % N) exist and nothing calls them. **Fading**: IsFading (slot 26) is
asked first by CAlertManager_Show and CDiplomacyDialog::PlayOfferSound, which play when it is true; it can only be true after
FadeOutSample (slot 12), which nothing calls; UpdateFades (slot 28) runs every frame over a list that stays empty (*inferred*
from the census).

**When sound is disabled.** SetEnabled(0) (slot 27) stops every sample and blocks PlayEx; it is called with 0/1 around a lost
Direct3D device (CFrontEnd_Render, CInGameIdler_Render, OnResetDevice), and `CInGameIdler::Enter` disables it at 0x65ACB1 and
0x65D284 and re-enables it at 0x66062C - **nothing is heard while a game's screen is being built**.

## 4. Volume

`CEU3Application::Run` sends v = master_volume × 0.01 × sound_fx_volume × 0.01 to slot 20, `SetEffectsVolume` (rva
0x6BE1B0), only where v differs from `g_LastEffectsVolumeSent`, which starts at -1.0, so the first frame always sends;
LoadEverything sends once too. Then (*confirmed*): **scale = 0.5·v + 0.5 when v > 0, held at 1.0; 0 when v ≤ 0**; for every
sample **not playing at that moment**, effective = base × scale; at its next play, SetVolume((int)(effective × 10000) − 10000).
With `volume = 100`: v 1.0 gives 0 dB, 0.5 gives -25 dB, just above 0 about -50 dB, and 0 silence (-100 dB). **Linear in
decibels, quite unlike the music's fourth-root curve.** A `volume` above 100 gives a positive figure, which DirectSound rejects:
logged (`Failed to set volume for sound`), the voice keeping its previous volume (*inferred* from the API's range). The
object's own scale (+4 = 10000) changes only through slot 18, which nothing calls; `ambient_volume` is read nowhere.

## 5. The interface

**guiButtonType** (`GuiButton_Construct`, rva 0x73FA50): the type's `oversound` +0x158, `clicksound` +0x174, `downsound`
+0x190 and `upsound` +0x1AC (switchmap and jump-table decoding of the type's LoadKey, 0xB2CE40, confirm them) become ids -
over +0x124, down +0x128, up +0x12C, click +0x130. The click id is, in order: **the button's own `clicksound`**; else **its
sprite's `clicksound`** (CSprite::GetClickSound, the .gfx spriteType's); else **the CGui's default click sound** (CGui +0x14),
which CInGameIdler::CInGameIdler and CFrontEnd::CFrontEnd both set to `click`. The choice goes by whether a string is empty,
not whether the name resolves: `clicksound = close_window` or `start_game`, neither in sound.sfx, logs once and stays silent -
5+3 close_window and 1+1 start_game buttons in the base and TFH files. That the third choice reads the CGui is *likely* (the
same constructor uses that argument's +0xA4 as CGui's recorded `keyboard`).

**When a button clicks** (`GuiButton_PlayClickSound`, slot 68, *confirmed*): unless the click sound is already playing, when
`GuiButton_HandleMouse` sees **the left button released over a pressed button**, after the click's listeners and hook have
run; or input sub-kind 5, running listener slots 8 then 7 - *likely* the double-click. No click sound for the right button, a
disabled button (state 3), a button taking no mouse, or a **keyboard shortcut**, which runs the listeners without the sound.

**Over, down and up sounds.** ShowOver plays the over sound on entering the over state; ShowDown and ShowUp play the down and
up sounds every time they run, with no is-playing check; how often ShowState runs them was *not established*. No vanilla
button sets any of the three.

**checkboxType** (the same type class; `CheckBox_Construct`, rva 0x680FA0): **tick** = `clicksound`, else the sprite's, else
the gui default; **untick** = **`upsound`**, else the sprite's `clicksound`, else the gui default; `oversound` loaded and never
played. `CCheckBox_HandleInput` (0x681D10) toggles **on the left button's press** and on the keyboard shortcut - unlike a
button; ticking plays the tick sound, unticking the untick sound, where the box is not locked (+0xD8); the right button makes
none. **Code also triggers them**: `CCheckBox_CheckNotify` and `CCheckBox_UncheckNotify` (7 and 9 callers across the screens)
play them too.

**windowType** `upsound` and `downsound` (CWindowType +0x26C/+0x288) become ids at CFixedWindow +0x498/+0x49C;
**`CFixedWindow::Show` plays upsound and `Hide` downsound**, where the byte at CGuiObject +0x42 is set (what it is, *not
established*), with no is-playing check. All 39 windows of the base and TFH files that carry the keys give empty strings, so
**no window sounds in vanilla**. **No other element kind** reads a sound key; scrollbars' and list boxes' arrow buttons are
guiButtonType widgets and follow the button rules (*inferred*).

## 6. Every effect the executable plays by name

Unless the line says otherwise, each is "play unless already playing", and every one is gated on the **played** country or on
the local player's own action. None is positional.

| sound | where | when |
| --- | --- | --- |
| click | button and checkbox fallbacks (section 5) | any widget click without its own sound |
| click | CProvince::OnSelected | a province selected on the map |
| click | the 16 MapMode_* setters | a map mode chosen, unless that mode is already on |
| click | CInGameIdler::ZoomIn / ZoomOut | the zoom buttons and keys |
| click | CInGameIdler::IncreaseSpeed / DecreaseSpeed | game speed changed |
| click | CInGameIdler::OnMergeButton | a merge posted |
| click | handler at rva 0x2697A0 (glue +0x1410) | posts CReinforceCommand; which button was not read |
| click | CReorgEntry::OnTransfer | a brigade moved in the reorganise window |
| click | CDisbandCommand::Execute | the player's unit disbanded |
| click | CGameSetup::OnProvinceClicked | a country chosen in the lobby |
| army_selected / navy_selected / air_selected | CUnit::OnSelected | per selected unit: fleet (slot 16), air (slot 17), else army |
| army_selected | CreateRebelsForFaction | a revolt in a province the player controls, with the REVOLT message |
| army_move / navy_move / air_move | CUnit::OrderToProvince | the player's right-click orders; a fleet only when ordered directly (shift, or in battle); an air unit after its order |
| error | CUnit::OrderToProvince (3 sites) | an illegal target |
| convoys_1 | CConvoy::LoseShips | ships lost from a convoy of the played country, with CONVOY_ATTACK_ON_US |
| convoys_2 | CConvoy::LoseShips | the played country the raider, with WE_ATTACK_CONVOY; once per raid hit |
| tech_discovered | CDistributeResearch::Distribute | the played country completes a level |
| declarewar | CDeclareWarAction::Apply | the player declares war |
| declarewar_onus | CDeclareWarAction::Apply | war declared on the player; nobody else hears either |
| diplomaticoffer | CDiplomacyDialog::PlayOfferSound | an offer's icon appears in the player's icon bar |
| diplomaticsuccess / diplomaticfailure | 12 actions' Apply | the answer reaches the country the news is addressed to - in the gated arms read, `played == actor`, the asker |
| message | CAlertManager_Show | each alert icon that appears |
| message | CEventWindow::CEventWindow / Update | the event window shown, and shown again by Update whenever found shut; **plain Play: it overlaps itself** |
| land_combat_1..6, air_combat_1..2, naval_combat_1..3, bomb_1..3 | CCombatView::Update | below |
| ding | rva 0x2FF760 (front end) | a line added to the connection log (`connection_log_text`), multiplayer; the trigger *inferred* |
| pong | CMetaserverInterface handler (rva 0x3CEF10) | metaserver message 0xB; `pong` is commented out of sound.sfx, so it logs `not found` and plays nothing |

The 12 actions: lend-lease request, alliance, military access, offer military access, call ally, NAP, faction, trade,
expeditionary force, licence, debt and peace; faction and trade route their news through further branches, trade gated on
delegation and automate_trade (`FINDINGS-tradeui`).

**Battle sounds (CCombatView::Update).** **Only while a battle's window is open**, and not with `sound_off` (+0x68) set: when the
sound last started (+0x84) has ended, a new variant starts - n = |MT19937Next(view +0x88)| % N + 1, from the window's own
generator seeded from the clock; N = 6 for land (kind 1), 2 for air (3), 3 for naval (2), 3 for anything else (`bomb_`);
played through PlayWithLoop(id, 0). A continuous chain of random variants; no pause check was seen, so they *likely* go on
while the game is paused.

**Never named by the executable:** `buzzbeep`, `nuke` and `unit_upgraded` (the last commented out) - a byte search for each
name in every section, the positive control the same search finding `land_combat_`, `bomb_` and `air_combat_`. **Not play
sites**: "message" in OnMessageSettingsRowClick is an element name; "declarewar" (token 0x2F5) and "message" (token 0xE1) are
in the save-token table's builder. **Messages have no sound**: CMessageType::LoadKey's 7 keys (its default an unknown key, not
a base loader) include none, and no CMessageDialog or log function is among the GetSound sites. **The settings window plays no
test sound.**

## 7. What looks wrong and is what the bytes do

Effect volume is linear in dB, with a floor of -50 dB just above zero, then silence; buttons click on release, checkboxes on
press; a misspelled `clicksound` silences a button rather than falling back, `close_window` and `start_game` being no sound
names; checkboxes play their *upsound* when unticked; the event window's `message` stacks where every other game sound is
skipped while playing; a missing wav plays sample 0 and shifts later samples' settings by one (*inferred*); `oversound` on a
checkbox is loaded and never played.

## 8. Not established

How often a button's ShowState runs, and so whether its `upsound`/`downsound` would repeat; CGuiObject +0x42, the gate on
window sounds; whether widgets built before a screen's constructor writes `click` into the gui miss the default; input
sub-kind 5; exactly when `ding` plays; how the tfh/ folder layers into the sound folder; the wav loader (0xABDD30); slots 13,
14, 3 and 17, read and not recorded.

## 9. Hardcoded or mod-able

The file and its keys, the wavs and every `clicksound`/`upsound`/`downsound`/`oversound` are mod-able (interface/sound.sfx,
sound/*.wav, the .gui and .gfx files); the effects volume curve, the voices, "unless playing", the button and checkbox rules,
the default `click`, the names the game's own events play and the battle chain's counts are [exe]; `master_volume` and
`sound_fx_volume` are the player's settings, a negative master disabling all sound.

In the record through `fragments/merged/sound-effects-2026-11-12.json`.
