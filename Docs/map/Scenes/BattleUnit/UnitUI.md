<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/BattleUnit/UnitUI.gd` — `class_name UnitUI` extends `PanelContainer`

`1341` lines · [back to the map](../../../CODEBASE_MAP.md)

> extends PanelContainer, 6 signal(s), 12 export(s), 58 function(s)

Sections: Health Bar State · Lifecycle · Setup & Binding · Intent Label · Outline Glow & Highlights · Drag & Drop · Character Animation · Skill HUD fade · (+4 more)

Signals:
- L4 `card_dropped_on_unit(card: Card, unit: Unit)`
- L5 `unit_clicked(unit: Unit)`
- L6 `card_hover_started(unit: Unit, card: Card, anchor_rect: Rect2)`
- L7 `card_hover_ended(unit: Unit)`
- L8 `intent_hover_started(unit: Unit, anchor_rect: Rect2)`
- L9 `intent_hover_ended(unit: Unit)`

Constants:
- L11 `PLACEHOLDER_ICON: Texture2D`
- L12 `STAGGER_OFFSET_Y: float = 65.0`
- L13 `SPINE_BASE_DIR = "res://Scenes/BattleUnit/Spine/"`
- L89 `HIT_FLASH_TIME: float = 0.4`
- L90 `CHIP_HOLD_TIME: float`
- L91 `CHIP_DRAIN_SPEED: float = 9.0`
- L92 `HEAL_FILL_SPEED: float = 10.0`
- L93 `SHIELD_GAIN_SPEED: float = 14.0`
- L94 `SHIELD_DECAY_SPEED: float = 9.0  ## Expiry shrink (not a hit)`
- L95 `SHIELD_FLASH_TIME: float = 0.28`
- L96 `CAP_EXPAND_SPEED: float = 18.0`
- L97 `CAP_SHRINK_SPEED: float = 6.0`
- L99 `SHATTER_DURATION: float = 0.28`
- L100 `SHATTER_WAVE_TIME: float = 0.14`
- L101 `SHATTER_SHARD_LIFE: float = 0.16`
- L708 `SHOW_STATUS_ICONS: bool = true` — Status badge strip above the portrait (buff/debuff icons + counter).
- L710 `SHOW_SKILL_PREVIEW_STRIP: bool = false` — Legacy skill-category preview rows in the same section (kept off).
- L714 `BADGE_SIZE: float = 24.0` — Square size of one status badge. The grid has 4 columns, so four badges fit inside the 114px strip without resizing the UnitUI.
- L716 `ICON_INSET: float = 3.0` — Inset that keeps the icon art away from the badge frame.
- L718 `COUNT_FONT_SIZE: int = 11` — Counter label styling (bottom-right corner, outlined white).
- L719 `COUNT_OUTLINE_SIZE: int = 4`
- L721 `COUNT_OVERHANG: float = 3.0` — How far the counter overhangs the badge corner (matches the reference art).
- L723 `COUNT_DISPLAY_MAX: int = 99` — Counts above this are shown as "99+".
- L725 `BUFF_TILE_COLOR: Color = Color(0.10, 0.26, 0.42, 0.95)` — Badge tile tint: buffs are royal blue, debuffs crimson (LoR/R1999 style).
- L726 `BUFF_FRAME_COLOR: Color = Color(0.36, 0.78, 1.0, 0.95)`
- L727 `DEBUFF_TILE_COLOR: Color = Color(0.34, 0.09, 0.12, 0.95)`
- L728 `DEBUFF_FRAME_COLOR: Color = Color(1.0, 0.34, 0.32, 0.95)`

Exports:
- L15 `icon_catalog: CardIconCatalog`
- L16 `status_icon_catalog: StatusIconCatalog`
- L20 `use_override_spine: bool = false` — Toggle this on to manually assign a .tres file below.
- L21 `override_spine_data: Resource`
- L24 `hit_flash_delay: float = 0.0`
- L31 `status_apply_delay: float = -1.0` — How long the badge strip waits before showing a new/stacked status, so it lands together with the hit reaction. -1 = reuse the damage delay above (hit_flash_del…
- L34 `hud_fade_out_time: float = 0.12`
- L35 `hud_fade_in_time: float = 0.25`
- L41 `intent_fade_in_time: float = 0.25`
- L42 `intent_fade_out_time: float = 0.2`
- L50 `intro_extra_delay: float = 0.0` — Extra wait after the born animation ends. Negative = start fading before born ends.
- L51 `intro_fade_in_time: float = 0.35`

Onready:
- L60 `intent_label: Label`
- L61 `status_section: VBoxContainer`
- L62 `status_icons_grid: GridContainer`
- L63 `skill_preview_box: VBoxContainer`
- L64 `skill_1_row: HBoxContainer`
- L65 `skill_1_icons: HBoxContainer`
- L66 `skill_2_row: HBoxContainer`
- L67 `skill_2_icons: HBoxContainer`
- L69 `health_bar_canvas: Control`
- L70 `health_shield_container: Control`
- L71 `hp_bar: ProgressBar`
- L72 `shield_bar: ProgressBar`
- L74 `oval_body: PanelContainer`
- L75 `sprite: Control`
- L76 `name_label: Label`
- L77 `hover_glow: Panel`

State:
- L37 `_hud_tween: Tween`
- L38 `_hud_hidden: bool = false`
- L44 `_intent_tween: Tween`
- L46 `_intent_visible: bool = false` — Whether the label should end up shown, even mid-fade
- L53 `_intro_active: bool = false`
- L54 `_intro_tween: Tween`
- L55 `_pending_intent: Dictionary = {}`
- L56 `_skill_hud_active: bool = false`
- L58 `unit: Unit`
- L79 `_stagger_style: StyleBoxEmpty`
- L80 `_is_target_highlighted: bool = false`
- L81 `_is_drag_hovering: bool = false`
- L82 `_is_orb_linked_highlighted: bool = false`
- L83 `_hovered_drag_card: Card = null`
- L84 `_intent_style: StyleBoxEmpty`
- L85 `_glow: OutlineGlow`
- L86 `_ult_warning_active: bool = false`
- L104 `_display_hp: float = 0.0` — What the bar currently shows (lags behind the Unit on purpose).
- L105 `_display_shield: float = 0.0`
- L107 `_target_hp: float = 0.0` — Where the bar is heading: real values + damage that hasn't landed yet.
- L108 `_target_shield: float = 0.0`
- L109 `_prev_target_shield: float = 0.0`
- L112 `_chip_total: float = 0.0` — Right edge of the "recently lost" chip, in HP units (HP + shield).
- L113 `_chip_hold_timer: float = 0.0`
- L114 `_display_max_cap: float = 1.0`
- L116 `_hit_flash_timer: float = 0.0`
- L117 `_shield_flash_timer: float = 0.0`
- L120 `_pending_hits: Array[Dictionary] = []` — Hits that already happened in the model but haven't landed visually.
- L122 `_withheld_hp: float = 0.0` — Sum of pending losses. Added back so the bar keeps showing pre-hit values.
- L123 `_withheld_shield: float = 0.0`
- L125 `_was_dead: bool = false`
- L126 `_pending_death_timer: float = -1.0`
- L127 `_shatter_timer: float = 0.0`
- L128 `_shatter_shards: Array[Dictionary] = []`
- L130 `_last_status_signature: String = ""`
- L131 `_manual_statuses: Array[Dictionary] = []`
- L133 `_statuses_dirty: bool = true` — Set whenever the unit's status list changes, so the strip only rebuilds then.
- L135 `_pending_status_timer: float = -1.0` — Counts down to the moment a pending status change becomes visible (-1 = none).

Public API:
- L208-237 `setup(p_unit: Unit, p_card_catalog: CardIconCatalog, p_status_catalog: StatusIconCatalog = null) -> void`
- L260-269 `set_staggered(is_lower: bool) -> void`
- L289-292 `set_intent_ult_warning(warn: bool) -> void`
- L306-335 `show_intent(text: String, _categories: PackedStringArray, delay: float = 0.0) -> void` — delay: seconds to wait before fading in (used to stagger enemies).
- L339-357 `clear_intent(animated: bool = false) -> void` — animated = true fades out; false hides instantly.
- L385-387 `set_target_highlight(highlight: bool) -> void`
- L390-392 `set_orb_linked_highlight(highlight: bool) -> void`
- L528-539 `play_skill_animation(skill_index: int, rank: int = 0, lead: float = 1.0) -> void` — skill_index: 1 for odd, 2 for even. rank: 0 normal, 1 merged/condition met, 2 double merged. lead: fraction of the skill animation to wait for before returning.…
- L541-550 `play_ultimate_animation() -> void`
- L567-569 `play_character_animation(anim_name: StringName) -> void`
- L645-665 `play_intro(extra_delay: float = 0.0) -> void` — Hides HUD + intent, then fades them in once the born animation ends. Called automatically by setup(). Call again with extra_delay to stagger units.
- L730-735 `set_manual_statuses(statuses: Array[Dictionary]) -> void`

Private:
- L141-182 `_ready`
- L185-201 `_process`
- L240-257 `_bind_unit`
- L276-286 `_setup_intent_badge_style`
- L295-297 `_on_intent_mouse_entered`
- L300-302 `_on_intent_mouse_exited`
- L360-363 `_kill_intent_tween`
- L370-382 `_setup_glow_style`
- L395-406 `_refresh_outline_glow`
- L412-413 `_enemy_holds_full_gauge`
- L419-424 `_on_unit_moxie_changed`
- L426-444 `_update_glow_visibility`
- L451-454 `_gui_input`
- L457-486 `_can_drop_data`
- L489-495 `_drop_data`
- L498-500 `_notification`
- L503-515 `_reset_preview`
- L553-564 `_play_skill_animation_for_card`
- L576-580 `_is_skill_anim`
- L583-586 `_on_sprite_action_started`
- L589-592 `_on_sprite_action_finished`
- L595-601 `_get_hud_nodes`
- L605-606 `_update_hud_visibility`
- L611-636 `_set_hud_hidden`
- L668-682 `_finish_intro`
- L685-688 `_cancel_intro`
- L691-694 `_kill_intro_tween`
- L697-701 `_get_intro_duration`
- L740-747 `_on_unit_statuses_changed`
- L750-777 `_refresh_status_icons`
- L781-789 `_status_signature`
- L792-848 `_create_e7_status_badge`
- L855-992 `_refresh_display`
- L995-1032 `_trigger_death_shatter`
- L1035-1159 `_draw_health_bar`
- L1163-1166 `_bar_rect`
- L1169-1173 `_get_tick_step`
- L1176-1187 `_reset_bar_state`
- L1190-1193 `_clear_pending_hits`
- L1198-1214 `_on_unit_damaged`
- L1217-1228 `_get_effective_hit_flash_delay`
- L1233-1236 `_get_effective_status_delay`
- L1239-1248 `_get_effective_death_delay`
- L1255-1272 `_render_skill_preview_icons`
- L1275-1331 `_load_unit_texture`
- L1334-1338 `_ignore_mouse_recursively`

Uses: BattleScene, Card, CardDrag, CardIconCatalog, OutlineGlow, SkillData, SpinePortrait, StatusIconCatalog, Unit
Used by: GDTest/EnemyUltAuraTest.gd, Scenes/BattleScene/BattleScene.gd, Scenes/HUD/BattleOverlayController.gd
Loads: res://Scenes/BattleScene/Assets/icon.svg, res://Scenes/BattleUnit/Spine/, res://Scenes/Textures/sampleUnits/

