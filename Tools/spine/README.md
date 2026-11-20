# Spine ↔ Godot workflow

How to author a character rig in Spine and get it into the game.

This file lives next to the export settings (`binary.json`, `pack.json`) it documents.
It is hand-written, unlike everything under `Docs/`, which is generated.

## Version rule (read this first)

The project ships the **spine-godot 4.2** runtime (`bin/spine_godot_extension.gdextension`,
verified by `Tools/check_spine_runtime.gd`). Spine requires the **editor version to match the
runtime version**, and both committed rigs are Spine **4.2.36** exports. So:

| You have | Result |
| --- | --- |
| Spine 4.2.xx editor | ✅ works with this project |
| Spine 4.3 editor | ❌ the 4.2 runtime rejects the data |

`Tools/prepare_spine_portrait.py` enforces this and refuses anything that is not `4.2.x`.

The installed launcher is **Spine Launcher 4.3.08**, which can still run the 4.2 editor —
pass `-u 4.2.xx` (see below). The launcher must be **activated** (your Spine account /
activation code) before it will download an editor version; an unactivated launcher prints
`An activation code is required.`

## One-time setup

1. Launch Spine from the Start menu and activate it with your license.
2. Download the 4.2 editor once (any 4.2 patch is fine, the data records 4.2.36):
   ```powershell
   & 'C:\Program Files\Spine\Spine.com' -u 4.2.xx
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
   Add the new `.tres` to `SKELETON_RESOURCES` in that script so the gate covers it.

## Why the exports look the way they do

- **Binary `.skel`, not JSON.** Smaller and faster to load. `300101_zhujue` is the legacy
  `.spine-json` export; new characters use `.skel`.
- **No premultiplied alpha.** `prepare_spine_portrait.py` rejects `pma: true` atlases because
  the portrait shader does its own blending.
- **The atlas page is named `<char_id>.png`.** The normalizer checks this and rescales the
  atlas rectangles if the PNG on disk differs from the packed size.
- **`_bloom.png` is optional.** Drop `<char_id>_bloom.png` next to the atlas to light up the
  glow mask in `SpinePortrait.gdshader`.
