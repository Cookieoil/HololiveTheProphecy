<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/OutlineGlow.gd` — `class_name OutlineGlow` extends `ColorRect`

`233` lines · [back to the map](../../../CODEBASE_MAP.md)

> outer light border with scrolling sub-surface energy texture.
- L6-10 `enum Preset` = RUNETERRA_BLUE

Constants:
- L12 `GLOW_SHADER: Shader = preload(`
- L15 `GROUP_GLOW_SHADER: Shader = preload(`

State:
- L19 `_shared_flow_tex: NoiseTexture2D`
- L20 `_silhouette_mipmap_cache: Dictionary[Variant, Texture2D] = {}`
- L22 `glow_bleed: float = 15.0`
- L23 `frame_corner_radius: float = 8.0`
- L25 `_mat: ShaderMaterial`
- L26 `_canvas_group: CanvasGroup`
- L27 `_fade_tween: Tween`
- L28 `_active: bool = false`

Public API:
- L31-41 `static attach_to(target_control: Control, p_corner_radius: float = 8.0, p_bleed: float = 15.0) -> OutlineGlow`
- L58-70 `bind_canvas_group(group: CanvasGroup) -> void`
- L121-143 `set_active(enabled: bool, preset: Preset = Preset.RUNETERRA_BLUE) -> void`
- L146-159 `apply_preset(preset: Preset) -> void`
- L162-164 `set_custom_flow_texture(tex: Texture2D) -> void`
- L221-232 `set_silhouette(tex: Texture2D) -> void`

Private:
- L44-55 `_init`
- L73-89 `_ready`
- L92-95 `_exit_tree`
- L98-103 `_apply_group_active_margins`
- L106-113 `_on_fade_out_finished`
- L116-118 `_sync_size`
- L167-169 `_set_intensity`
- L172-177 `_get_intensity`
- L180-196 `_ensure_shared_resources`
- L199-218 `_ensure_mipmapped_silhouette`

Uses: —
Used by: GDTest/CardUITest.gd, Scenes/BattleUnit/UnitUI.gd, Scenes/Cards/CardUI.gd, Scenes/HUD/MoxieOrbUI.gd
Loads: res://Scenes/HUD/OutlineGlow.gdshader, res://Scenes/HUD/OutlineGlowGroup.gdshader

