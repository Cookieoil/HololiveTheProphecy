<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/MoxieOrbUI.gd` — `class_name MoxieOrbUI` extends `Control`

`605` lines · [back to the map](../../../CODEBASE_MAP.md)

> extends Control, 3 signal(s), 1 export(s), 22 function(s)

Sections: Helper Methods

Signals:
- L5 `orb_activated(unit: Unit)`
- L6 `orb_hover_started(orb: MoxieOrbUI, unit: Unit)`
- L7 `orb_hover_ended(orb: MoxieOrbUI, unit: Unit)`

Constants:
- L9 `ORB_SCALE: float = 1.3`
- L11 `MEDALLION_SIZE = Vector2(64.0, 64.0) * ORB_SCALE`
- L12 `ORB_RADIUS: float = 25.5 * ORB_SCALE`
- L13 `INNER_RADIUS: float = 18.0 * ORB_SCALE`
- L14 `ORB_GLOW_BLEED: float = 13.0 * ORB_SCALE`
- L15 `SEGMENT_DIVIDERS: int`
- L17 `PORTRAIT_SHADER: Shader = preload(`
- L20 `RING_SHADER: Shader = preload(`
- L23 `PLACEHOLDER_PORTRAIT: Texture2D = preload(`
- L28 `ENEMY_GLOW_CORE = Color(0.976, 0.408, 0.0, 1.0)`
- L29 `ENEMY_GLOW_MID = Color(0.96, 0.26, 0.18, 1.0)`
- L30 `ENEMY_GLOW_DEEP = Color(0.52, 0.05, 0.08, 1.0)`
- L33 `SOCKET_GROOVE_COLOR`
- L34 `ALLY_SOCKET_FLOOR_COLOR`
- L35 `ENEMY_SOCKET_FLOOR_COLOR`
- L38 `ALLY_CRYSTAL_CHARGING_DEEP = Color("#0A2463") # Midnight sapphire rim`
- L39 `ALLY_CRYSTAL_CHARGING_MID = Color("#1D70E8") # Royal Hextech cobalt`
- L40 `ALLY_CRYSTAL_CHARGING_CORE`
- L42 `ALLY_CRYSTAL_READY_DEEP`
- L43 `ALLY_CRYSTAL_READY_MID = Color("#2ED4FF") # Blazing electric cyan`
- L44 `ALLY_CRYSTAL_READY_CORE`
- L47 `ENEMY_CRYSTAL_NORMAL_DEEP = Color("#420711") # Dark blood-garnet rim`
- L48 `ENEMY_CRYSTAL_NORMAL_MID = Color("#BD1928") # Rich crimson-ruby`
- L49 `ENEMY_CRYSTAL_NORMAL_CORE`
- L51 `ENEMY_CRYSTAL_WARN_DEEP = Color("#6E0F14") # Molten ruby rim`
- L52 `ENEMY_CRYSTAL_WARN_MID = Color("#FA3D22") # Blazing vermilion`
- L53 `ENEMY_CRYSTAL_WARN_CORE = Color("#FFE6B8") # White-hot ember core`
- L56 `ALLY_PREVIEW_DEEP = Color("#1F4B85")`
- L57 `ALLY_PREVIEW_COLOR = Color("#8EC5F5")`
- L58 `ALLY_PREVIEW_CORE = Color("#EEFAFF")`
- L60 `ENEMY_PREVIEW_DEEP = Color("#6B222C")`
- L61 `ENEMY_PREVIEW_COLOR = Color("#E89BA0")`
- L62 `ENEMY_PREVIEW_CORE = Color("#FFF0F2")`
- L65 `ALLY_BEZEL_DEFAULT`
- L66 `ALLY_BEZEL_HOVER`
- L67 `ALLY_BEZEL_READY`
- L68 `ENEMY_BEZEL_DEFAULT`
- L69 `ENEMY_BEZEL_HOVER`
- L70 `ENEMY_BEZEL_WARNING`
- L72 `BEZEL_DEFAULT_ALPHA = 0.94`
- L75 `ALLY_SPARK_HALO`
- L76 `ALLY_SPARK_MID = Color(0.68, 0.95, 1.00)   # cyan body`
- L77 `ALLY_SPARK_CORE`
- L79 `ENEMY_SPARK_HALO`
- L80 `ENEMY_SPARK_MID = Color(1.00, 0.68, 0.44)   # orange body`
- L81 `ENEMY_SPARK_CORE`
- L84 `PREVIEW_SPARK_HALO_DARKEN = 0.18`
- L85 `PREVIEW_SPARK_MID_LIGHTEN = 0.28`
- L86 `PREVIEW_SPARK_CORE = Color(0.97, 0.99, 1.00)`
- L89 `SPARK_HALO_ALPHA = 0.45`
- L90 `SPARK_MID_ALPHA = 0.88`
- L91 `SPARK_HALO_RADIUS = 5.6 * ORB_SCALE`
- L92 `SPARK_MID_RADIUS = 3.1 * ORB_SCALE`
- L93 `SPARK_CORE_RADIUS = 1.5 * ORB_SCALE`
- L94 `SPARK_PULSE_BASE = 0.85`
- L95 `SPARK_PULSE_AMP = 0.15`
- L96 `SPARK_PULSE_SPEED = 5.0`

Exports:
- L98 `ready_glow_preset: OutlineGlow.Preset = OutlineGlow.Preset.RUNETERRA_BLUE`

State:
- L100 `unit: Unit`
- L101 `badge_code: String = "A1"`
- L102 `interactable: bool = true`
- L104 `_orb_bounds: Control`
- L105 `_glow: OutlineGlow`
- L106 `_glow_active: bool = false`
- L107 `_glow_is_ally: bool = true`
- L108 `_has_cached_ally_colors: bool = false`
- L109 `_enemy_colors_applied: bool = false`
- L110 `_ally_glow_core: Color`
- L111 `_ally_glow_mid: Color`
- L112 `_ally_glow_deep: Color`
- L114 `_portrait_rect: ColorRect`
- L115 `_portrait_mat: ShaderMaterial`
- L116 `_has_portrait: bool = false`
- L118 `_ring_rect: ColorRect`
- L119 `_ring_mat: ShaderMaterial`
- L121 `_display_moxie: float = 0.0`
- L122 `_ready_blend: float = 0.0`
- L123 `_hover_blend: float = 0.0`
- L124 `_preview_gain: int = 0`
- L125 `_was_dead: bool = false`
- L126 `_is_hovered: bool = false`
- L127 `_is_pressed: bool = false`
- L128 `_burst_timer: float = 0.0`
- L129 `_anim_time: float = 0.0`

Public API:
- L222-245 `bind_unit(p_unit: Unit, p_badge_code: String, p_portrait: Texture2D = null) -> void`
- L248-275 `set_portrait(tex: Texture2D = null) -> void`
- L278-284 `set_preview_gain(amount: int) -> void`
- L287-291 `set_interactable(enabled: bool) -> void`
- L294-296 `play_cast_burst() -> void`

Private:
- L132-141 `_init`
- L144-148 `_ready`
- L151-156 `_build_glow_node`
- L159-170 `_build_portrait_node`
- L173-186 `_build_ring_node`
- L189-203 `_notification`
- L206-219 `_layout_subrects`
- L299-310 `_on_unit_moxie_changed`
- L313-314 `_can_click_cast`
- L317-323 `_should_show_glow`
- L326-377 `_sync_ring_shader`
- L380-414 `_sync_glow`
- L417-418 `_update_cursor`
- L421-436 `_gui_input`
- L439-495 `_process`
- L498-599 `_draw`
- L602-603 `_tint`

Uses: OutlineGlow, Unit
Used by: GDTest/BattleEndTest.gd, GDTest/EnemyUltAuraTest.gd, Scenes/HUD/BattleOverlayController.gd, Tools/SnapshotRunner.gd
Loads: res://Scenes/HUD/MoxieOrbPortrait.gdshader, res://Scenes/HUD/MoxieOrbRing.gdshader, res://Scenes/BattleScene/Assets/icon.svg

