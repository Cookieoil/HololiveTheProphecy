<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/BattleUnit/SpinePortrait.gd` — `class_name SpinePortrait` extends `Control`

`649` lines · [back to the map](../../../CODEBASE_MAP.md)

> extends Control, 3 signal(s), 28 export(s), 37 function(s)

Sections: Helper methods
- L88-92 `enum ActionBeat` = REACTION, transformation, buff preparation, etc. ATTACK

Signals:
- L4 `action_finished(anim_name: StringName)`
- L5 `action_started(anim_name: StringName)`
- L10 `action_lead_reached(anim_name: StringName)` — Emitted once per lead-armed action when the caller may hand control to the next actor, i.e. the action played far enough to overlap with it. It also fires when…

Constants:
- L12 `FALLBACK_ICON: Texture2D`
- L13 `PORTRAIT_SHADER: Shader`
- L14 `BASE_TRACK: int = 0`
- L15 `ACTION_COMPLETION_GRACE: float = 0.25`
- L16 `FALLBACK_ACTION_DURATION: float = 2.0`

Exports:
- L18 `skeleton_data: Resource`
- L20 `anim_idle: StringName = &"idle"`
- L21 `anim_sleep: StringName = &"sleep"`
- L22 `anim_born: StringName = &"born"`
- L23 `anim_change: StringName = &"change"`
- L24 `anim_die: StringName = &"die"`
- L25 `anim_freeze: StringName = &"freeze"`
- L26 `anim_giddy: StringName = &"giddy"`
- L27 `anim_hit: StringName = &"hit"`
- L28 `anim_idle_special: StringName = &"idle_special1"`
- L29 `anim_posture: StringName = &"posture"`
- L30 `anim_skill1: StringName = &"skill1"`
- L31 `anim_skill1_1: StringName = &"skill1_1"`
- L32 `anim_skill1_2: StringName = &"skill1_2"`
- L33 `anim_skill2_1: StringName = &"skill2_1"`
- L34 `anim_unique: StringName = &"unique"`
- L35 `anim_unique_1: StringName = &"unique_1"`
- L38 `source_art_bounds: Vector2 = Vector2(220.0, 420.0)`
- L39 `viewport_fill: float = 0.96`
- L40 `bottom_padding: float = 2.0`
- L41 `horizontal_offset: float = 0.0`
- L44 `bloom_intensity: float = 1.0`
- L45 `bloom_threshold: float = 0.35`
- L46 `bloom_tint: float = 0.0`
- L48 `hdr_bloom: bool = false` — Enable only if a WorldEnvironment glow + HDR 2D is set up (see below).
- L50 `bloom_debug_view: int = 0` — 0 normal, 1 R, 2 G, 3 B, 4 mask
- L53 `hit_reaction_delay: float = 0.35`
- L54 `death_animation_delay: float = 0.35`

State:
- L56 `_canvas_group: CanvasGroup`
- L57 `_spine: Node2D`
- L58 `_animation_state: Object`
- L59 `_material: ShaderMaterial`
- L60 `_fallback: TextureRect`
- L61 `_facing_left: bool = false`
- L62 `_dead: bool = false`
- L64 `_action_queue: Array[Dictionary] = []`
- L65 `_action_running: bool = false`
- L66 `_action_pump_scheduled: bool = false`
- L67 `_active_action: StringName = &""`
- L68 `_next_action_order: int = 0`
- L69 `_action_watchdog: float = 0.0`
- L72 `_action_lead: float = 0.0` — Seconds left until the running action reaches its overlap beat.
- L76 `_action_lead_armed: bool = false` — True while an overlap wait is armed for the running action. Kept separate from the counter so "already elapsed" (negative time) can never be confused with "no l…
- L79 `_hit_cancel_token: int = 0` — Cancels pending hit reactions when the queue is cleared (death/reload).
- L83 `_pending_hit_delay: float = -1.0` — Seconds left before a delayed hit reaction fires. Negative means "not scheduled"; _clear_action_queue() cancels it.
- L86 `_pending_death_delay: float = -1.0` — Seconds left before a delayed death animation fires. Negative means "not scheduled"; _clear_action_queue() cancels it.

Public API:
- L128-131 `set_skeleton_data(new_data: Resource) -> void` — Dynamically update the skeleton data (e.g., if assigned at runtime)
- L142-144 `configure_from_unit(_display_name: String, is_enemy: bool) -> void`
- L146-148 `set_hit_flash(strength: float) -> void`
- L155-188 `request_action(anim_name: StringName, beat: ActionBeat = ActionBeat.ATTACK, lead_seconds: float = -1.0) -> bool` — Requests an animation without immediately interrupting another action. Lower beat values play first. Requests with the same beat remain FIFO. fires. -1 (default…
- L191-196 `play_hit(delay: float = -1.0) -> void`
- L215-216 `play_skill(skill_index: int, rank: int = 0) -> void`
- L224-234 `play_skill_and_wait(skill_index: int, rank: int = 0, lead: float = 1.0) -> void` — Plays a skill action and waits for the caller's turn to continue. waits for the whole animation plus its blend back to idle, which is what the player's own turn…
- L245-248 `static lead_wait_seconds(duration: float, lead_fraction: float) -> float` — Seconds the caller waits before the next actor may start, for an action that lasts `duration` and an overlap request of `lead_fraction`. -1.0 means "wait for th…
- L256-262 `play_ultimate_and_wait() -> void`
- L353-363 `has_animation(anim_name: StringName) -> bool` — Check if the current skeleton actually has the animation
- L367-376 `play_animation(anim_name: StringName, loop: bool = false) -> void` — Plays a one-shot by default, then automatically returns to idle. Pass loop = true for persistent states such as sleep, freeze, or giddy.
- L429-447 `set_dead(value: bool) -> void`
- L623-628 `is_skill_animation(anim_name: StringName) -> bool` — True for animations where the character leaves its idle spot.
- L630-633 `get_intro_duration() -> float` — How long the spawn animation lasts. UnitUI fades its HUD in after this.
- L636-637 `get_canvas_group() -> CanvasGroup`

Private:
- L94-98 `_ready`
- L100-126 `_process`
- L133-140 `_reload_spine`
- L198-200 `_schedule_delayed_hit`
- L203-214 `_get_skill_anim`
- L250-254 `_get_ultimate_anim`
- L263-268 `_schedule_action_pump`
- L271-303 `_pump_action_queue`
- L306-328 `_on_spine_animation_completed`
- L331-351 `_clear_action_queue`
- L379-413 `_play_base_animation`
- L415-426 `_play_death_animation`
- L449-450 `_schedule_delayed_death`
- L454-472 `_tick_pending_delays`
- L474-519 `_create_spine_sprite`
- L522-537 `_create_material`
- L540-552 `_fit_sprite`
- L557-573 `_show_fallback`
- L574-594 `_get_animation_duration`
- L597-610 `_finish_active_action`
- L615-620 `_emit_action_lead`
- L640-647 `_ensure_canvas_group`

Uses: —
Used by: GDTest/EnemyTurnOverlapTest.gd, Scenes/BattleUnit/UnitUI.gd
Loads: res://Scenes/BattleScene/Assets/icon.svg, res://Scenes/BattleUnit/SpinePortrait.gdshader

