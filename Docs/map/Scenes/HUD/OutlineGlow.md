<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/OutlineGlow.gd` — `class_name OutlineGlow` extends `ColorRect`

`236` lines · [back to the map](../../../CODEBASE_MAP.md)

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
- L34-46 `static attach_to(target_control: Control, p_corner_radius: float = 8.0, p_bleed: float = 15.0) -> OutlineGlow` — A glow framed around `target_control`. Attaching is what knows the control, so the attach call also owns the resize link: the glow follows the frame it was hung…
- L63-75 `bind_canvas_group(group: CanvasGroup) -> void`
- L124-146 `set_active(enabled: bool, preset: Preset = Preset.RUNETERRA_BLUE) -> void`
- L149-162 `apply_preset(preset: Preset) -> void`
- L165-167 `set_custom_flow_texture(tex: Texture2D) -> void`
- L224-235 `set_silhouette(tex: Texture2D) -> void`

Private:
- L49-60 `_init`
- L78-92 `_ready`
- L95-98 `_exit_tree`
- L101-106 `_apply_group_active_margins`
- L109-116 `_on_fade_out_finished`
- L119-121 `_sync_size`
- L170-172 `_set_intensity`
- L175-180 `_get_intensity`
- L183-199 `_ensure_shared_resources`
- L202-221 `_ensure_mipmapped_silhouette`

Uses: —
Used by: GDTest/CardUITest.gd, Scenes/BattleUnit/UnitUI.gd, Scenes/Cards/CardUI.gd, Scenes/HUD/MoxieOrbUI.gd
Loads: res://Scenes/HUD/OutlineGlow.gdshader, res://Scenes/HUD/OutlineGlowGroup.gdshader

