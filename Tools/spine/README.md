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

The installed launcher is **Spine Launcher 4.3.08**, so the default version it downloads is
already correct. The launcher must be **activated** (your Spine account / activation code)
before it will download an editor version; an unactivated launcher prints
`An activation code is required.`

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

That text is the launcher's generic start-failure hint, **not** an antivirus report, and on
this machine no antivirus was involved (Defender's real-time protection is off). The launcher
failed because of its own state folder, `%USERPROFILE%\Spine`:

1. `version.txt` pinned a Spine version that was not installed (`4.2.xx`), so there was nothing
   to start. Note that running `Spine -u <version>` (or `Spine --update <version>`) records that
   version there, so a one-off download attempt can leave the launcher stuck on a version you
   never installed.
2. `updates\3.8.75` was a 10.9 MB *file* left over from a third-party Spine 3.8 install — not a
   real `<version>/` editor folder.
3. `prefs.json`, `views.json`, `recent.json` and `hotkeys.txt` still described a 3.8 session.

**Fix** (back up `%USERPROFILE%\Spine` first):

```powershell
$s = "$env:USERPROFILE\Spine"
Remove-Item -LiteralPath "$s\version.txt"                                  # let the launcher choose
Remove-Item -LiteralPath "$s\updates\3.8.75"                               # bogus leftover
Remove-Item -LiteralPath "$s\prefs.json", "$s\views.json", "$s\recent.json", "$s\hotkeys.txt"
& 'C:\Program Files\Spine\Spine.com' --no-auto-start
```

The launcher then opens and asks for an activation code. Related notes:

- A stale `.lock` in the same folder (left by a crashed session) can also block startup — delete
  it too. To confirm the launcher itself is healthy, run `Spine.com -v`; it prints
  `Spine Launcher <version> … Complete.` and exits 0.
- `%USERPROFILE%\Spine\spine.log` holds the launcher's own output; on a failure it contains the
  "Other software has interfered" text with no further detail.
- Only the launcher lives in `C:\Program Files\Spine`. Editors are downloaded into
  `%USERPROFILE%\Spine\updates\<version>\` after activation.
