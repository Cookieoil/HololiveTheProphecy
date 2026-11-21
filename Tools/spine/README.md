# Spine ↔ Godot workflow

How to author a character rig in Spine and get it into the game.

This file lives next to the export settings (`binary.json`, `pack.json`) it documents.
It is hand-written, unlike everything under `Docs/`, which is generated.

## Version rule (read this first)

The project ships the **spine-godot 4.3** runtime (`bin/spine_godot_extension.gdextension`,
verified by `Tools/check_spine_runtime.gd`). Spine requires the **editor version to match the
runtime version**: the runtime refuses to load a skeleton exported from another version, and
logs `Skeleton version X does not match runtime version Y`. So:

| You have | Result |
| --- | --- |
| Spine 4.3.xx editor | ✅ works with this project |
| Spine 4.2.xx editor | ❌ the 4.3 runtime rejects the data |

`Tools/prepare_spine_portrait.py` and `Tools/check_spine_runtime.gd` both enforce `4.3`.
Any `4.3.xx` patch works; 4.3.26 is the current stable release.

The installed launcher is **Spine Launcher 4.3.08**, and this machine runs **Spine 4.3.26
Professional** (`%USERPROFILE%\Spine\updates\4.3.26`), which matches the runtime. The launcher
must be **activated** (your Spine account / activation code) before it will download an editor
version; an unactivated launcher prints `An activation code is required.` See
[Troubleshooting the launcher](#troubleshooting-the-launcher) if it refuses to start.

> **Upgrading from 4.2:** the two rigs that shipped with the 4.2 runtime
> (`300101_zhujue`, `300402_hongnujian`) were removed because a Spine 4.2 export cannot be
> converted without the Spine editor. Re-create them from their `SpineSource/` projects with
> the 4.3 editor: open the project, then export with the script below. Until a rig exists for a
> unit, `SpinePortrait` falls back to the placeholder icon art.

## One-time setup

1. Launch Spine from the Start menu and activate it with your license.
2. Download the 4.3 editor once (any 4.3 patch works; 4.3.26 is the current stable):
   ```powershell
   & 'C:\Program Files\Spine\Spine.com' -u 4.3.xx
   ```

## Per character

1. Put the source project at `SpineSource/<char_id>.spine` (gitignored) with the images in
   `SpineSource/images/`. Use the unit keys from `Data/json/allies.json` and
   `Data/json/enemies.json` as `<char_id>`: `striker`, `healer`, `buff`, `normal_enemy`,
   `boss_enemy`.
2. Add the combat rig in Spine:
   - **Bones:** `Center_Hit_Point` (torso/hip) and `Cast_Origin_Point` (weapon tip / casting
     hand). Both must exist in every skin — do not mark them "Skin required".
   - **Events:** `event_vfx_spawn` and `event_hit_frame`, created under the Events node and
     **not** in a folder (a folder prefixes the exported name). Key `event_vfx_spawn` then
     `event_hit_frame` at the impact frame of every attack animation.
3. Export straight into the Godot project:
   ```powershell
   pwsh -File Tools/export_spine_to_godot.ps1 -CharId striker
   ```
   This runs the Spine CLI with `Tools/spine/binary.json` (binary + nonessential) and
   `Tools/spine/pack.json`, then normalizes the atlas and writes the `.tres` through
   `Tools/prepare_spine_portrait.py`. Output lands in
   `res://Scenes/BattleUnit/Spine/<char_id>/`.
4. Open the Godot editor once so it imports the new files, then verify:
   ```powershell
   godot --headless --path . --script res://Tools/check_spine_runtime.gd
   ```
   The gate discovers every rig under `res://Scenes/BattleUnit/Spine/` automatically, so a new
   `<char_id>/` folder is covered without editing the script.

## Adding the combat rig from a JSON export

Spine has **no scripting, macro or automation API**, so nothing here can drive the editor UI.
What a script *can* do is patch the data: `Tools/rig_combat_actor.py` takes a Spine JSON export
and writes a copy with the whole I-1 combat rig in it.

- adds the bones `Center_Hit_Point` and `Cast_Origin_Point`,
- adds the events `event_vfx_spawn` and `event_hit_frame`,
- keys both events into the attack animations you choose.

```powershell
# report only, nothing written
python Tools/rig_combat_actor.py --input rig.json --dry-run

# key every animation whose name looks like an attack, with default timings
python Tools/rig_combat_actor.py --input rig.json --output rig_combat.json --all-attacks

# explicit parents and timings: a fraction of the animation, seconds, or frames at 30 fps
python Tools/rig_combat_actor.py --input rig.json --output rig_combat.json `
    --torso hip --cast-parent hand --anim skill1:0.3:0.55 --anim unique:0.75s:12f
```

- **Parents.** Without `--torso` the bone with the most children is used, and the top candidates
  are printed — check that line, because a rig with a multi-bone prop can pick the prop.
- **Bone placement.** New bones sit at 50% (`--hit-bone-offset`) and 100%
  (`--cast-bone-offset`) along their parent bone's length; a parent without a length puts them on
  its origin and says so.
- **Timings.** `0.55` is a fraction of the animation, `0.75s` is seconds, `12f` is a frame at
  `--fps`. A bare number above 1 is rejected as ambiguous. Defaults are 30% and 55%.
- **Ranges are checked.** `--spawn-fraction`, `--hit-fraction`, `--hit-bone-offset` and
  `--cast-bone-offset` must be between 0 and 1, the hit key may not land before the spawn key, and
  a key that lands past the end of the animation is flagged because it would lengthen it.
- **`--all-attacks` skips pose-only matches.** An animation with no keyed times (a single-frame
  pose, or an empty placeholder) cannot take a fraction of its duration, so it is skipped with a
  note instead of failing the whole run. Key it explicitly, `--anim name:0.2s:0.5s`, if you want it.
- **Idempotent.** An existing bone, event or event key is left alone, so the script can be re-run
  after an artist has adjusted the rig. `--force` re-times keys it wrote before.
- **Output style.** The writer reproduces Spine's own pretty-printed JSON byte for byte
  (indentation, inline objects, and Java's `Double.toString` numbers such as `5.4E-4`), so a
  re-export from the editor produces no spurious diff.

Turn the patched JSON into an editable project, then refine and export:

```powershell
& 'C:\Program Files\Spine\Spine.com' -i SpineSource/<char_id>_combat.json `
    -o SpineSource/<char_id>.spine --to <char_id> -r
```

Placing the two bones exactly where the art wants them, and re-timing the hit keys to the impact
frame, is still an editor job — the script only removes the mechanical part.

`python Tools/rig_combat_actor_test.py` covers every behaviour above: it builds its own rigs in a
scratch folder and exits non-zero on the first failed check. Add `--samples <dir>` pointing at
Spine's own `*-pro.json` example exports to also assert that the writer reproduces those files byte
for byte.

## Why the exports look the way they do

- **Binary `.skel`, not JSON.** Smaller and faster to load. Use `Tools/spine/binary.json`.
- **No premultiplied alpha.** `prepare_spine_portrait.py` rejects `pma: true` atlases because
  the portrait shader does its own blending.
- **The atlas page is named `<char_id>.png`.** The normalizer checks this and rescales the
  atlas rectangles if the PNG on disk differs from the packed size.
- **`_bloom.png` is optional.** Drop `<char_id>_bloom.png` next to the atlas to light up the
  glow mask in `SpinePortrait.gdshader`.

## Troubleshooting the launcher

**Symptom:** launching Spine shows a dialog titled *"Unable to start Spine"* with the hint
*"Other software has interfered with Spine's operation. Please disable any antivirus or other
software that manipulates Spine."*

That text is the launcher's anti-tamper hint: Spine refuses to run when another process has
injected code into it, or when its own state folder is inconsistent. Both happened on this machine
and both produce the *same* dialog, so check them in this order.

### 1. Antivirus injection (check this first)

Bitdefender Antivirus Free 27 is installed here, and its hooks manager injects `bdhkm64.dll` and
`atcuf64.dll` into processes started from the desktop shell. Spine sees those injected modules and
refuses to start. Confirm it while the failing dialog is on screen:

```powershell
Get-Process Spine | ForEach-Object { $_.Modules } |
    Where-Object FileName -match 'bitdefender' | Select-Object ModuleName
# bdhkm64.dll, atcuf64.dll  =>  Bitdefender is the cause
```

The injection is inherited by children, so *every* user-facing launch fails: the Start-menu and
desktop shortcuts, `explorer.exe <link>`, a `cmd.exe` wrapper, a scheduled task and a WMI
`Win32_Process.Create` all end in this dialog — while the same command run from a shell Bitdefender
did not hook (a VS Code terminal here) starts the editor. That is exactly the "it opens when you
run it, but not when I click it" symptom. Fix it in Bitdefender, not in the launcher:

- Protection → Antivirus → Settings → **Manage Exclusions** → add the folders
  `C:\Program Files\Spine` and `%USERPROFILE%\Spine`.
- Protection → Advanced Threat Defense → Settings → **Manage Applications** → add
  `C:\Program Files\Spine\Spine.exe` as *Allowed*.
- Still failing? Pause Bitdefender for 5 minutes and click the shortcut: if the editor appears, the
  exclusion did not land in the right list (or Bitdefender has to go).

### 2. The launcher's own state folder, `%USERPROFILE%\Spine`

1. `version.txt` pinned Spine **3.8.75**, while `updates\3.8.75` held the editor payload of a
   *third-party* 3.8 install (file dated 2019-12-24) instead of one this launcher downloaded
   itself. The launcher could not start it and reported interference; deleting the pin and the
   payload is what made it start. `Spine -u <version>` / `--update <version>` records the version
   in `version.txt`, so `-u 4.2.xx` also pins the launcher to 4.2.xx — which fails the same way,
   because that editor was never downloaded.
2. `prefs.json`, `views.json`, `recent.json` and `hotkeys.txt` still described a 3.8 session.

Note that `updates\<version>` is a single *file* — the downloaded editor payload (~15 MB for
4.3.26), not a `<version>\` folder. Do not "tidy" it into a directory.

**Fix** (back up `%USERPROFILE%\Spine` first): drop the pinned version and the stale payload,
then relaunch. The launcher opens, asks for an activation code, and downloads a current editor:

```powershell
$s = "$env:USERPROFILE\Spine"
Remove-Item -LiteralPath "$s\version.txt"                                  # let the launcher choose
Remove-Item -LiteralPath "$s\updates\3.8.75"                               # stale third-party payload
Remove-Item -LiteralPath "$s\prefs.json", "$s\views.json", "$s\recent.json", "$s\hotkeys.txt"
& 'C:\Program Files\Spine\Spine.com' --no-auto-start
```

After activation the launcher logged `Downloading: Spine 4.3.26 Professional` and
`Starting: Spine 4.3.26 Professional`, leaving `updates\4.3.26` in place. Related notes:

- A stale `.lock` in the same folder (left by a crashed session) can also block startup — delete
  it too. To confirm the launcher itself is healthy, run `Spine.com -v`; it prints
  `Spine Launcher <version> … Complete.` and exits 0.
- `%USERPROFILE%\Spine\spine.log` holds the launcher's own output. A start failure leaves the
  "Other software has interfered" text there with no further detail.
- Only the launcher lives in `C:\Program Files\Spine` (`launcher\1` and `launcher\2` are its
  bundled Java runtime).

### Clicking the shortcut still fails after that fix

Deleting a wrong pin fixes the launcher, but on this machine the *argument-less* start stayed
broken: `Spine.exe` (what the Start-menu and Desktop shortcuts run) came up as the launcher
window (`Spine Launcher`), never switched to the editor, and then reported *Unable to start
Spine* — while `Spine.com -u 4.3.26` started the editor every time. `Spine -h` documents the flag:
*`-u, --update  The version number of the Spine update to load or "project"`*. Both shortcuts
therefore pass `-u 4.3.26`:

```powershell
$ws = New-Object -ComObject WScript.Shell
foreach ($lnk in "$env:USERPROFILE\Desktop\Spine.lnk",
                "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Spine\Spine.lnk") {
    $s = $ws.CreateShortcut($lnk)
    $s.TargetPath = 'C:\Program Files\Spine\Spine.exe'
    $s.Arguments = '-u 4.3.26'
    $s.WorkingDirectory = 'C:\Program Files\Spine'
    $s.Save()
}
```

A healthy click shows the launcher window for a second, then a window titled `Spine 4.3.26`;
`%USERPROFILE%\Spine\spine.log` ends with `Starting: Spine 4.3.26 Professional` and `Started.`,
with no interference text.

**Do not hand-write `version.txt`.** Deleting a wrong pin is the fix; writing one by hand is not:
`Set-Content "$env:USERPROFILE\Spine\version.txt" '4.3.26'` — a version this launcher *did*
download — brought the interference dialog straight back, because the pin has to match the
launcher's own update record. Pick the editor with `-u <version>` instead.

### The third-party 3.8.75 repack

A cracked "Spine 2D Pro 3.8.75 made by MKS" install sits in `%USERPROFILE%\Downloads\gAME\`.
Its `install.bat` is the source of the original mess:

```bat
reg import spine.reg
xcopy Spine %USERPROFILE%\Spine\ /e /y
Shortcut.exe /f:"%USERPROFILE%\Desktop\Spine.lnk" /a:c /t:"%~dp0\Spine.exe"
```

It copies its own 3.8.75 state (the 2019-12-24 payload plus a `version.txt` pin) into the shared
state folder, imports Java prefs pinning the launcher to 3.8.75, and rewrites the Desktop
shortcut to point at its own 2019 launcher. That shortcut always ends in the interference dialog,
and running it can re-pin `%USERPROFILE%\Spine` to 3.8.75 — which breaks the installed launcher
again. The repack folder is deleted (121 MB); the original shortcut is kept in
`Documents\SpineRepair-2026-11-20\Spine-repack-3.8.75.lnk.bak`.

One detail worth keeping: `install.bat` hardcodes `%USERPROFILE%\Desktop`, but this machine's
desktop is **redirected to OneDrive** (`HKCU\...\Explorer\User Shell Folders\Desktop` =
`%USERPROFILE%\OneDrive\Desktop`), so that shortcut never actually appeared on the visible
desktop — only the Start-menu entry did. Create desktop shortcuts on the *effective* desktop
(`[Environment]::GetFolderPath('Desktop')`), which is where the working `Spine.lnk` lives now; a
second copy sits in the stale `%USERPROFILE%\Desktop` folder.
