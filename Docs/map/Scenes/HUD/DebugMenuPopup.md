<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/DebugMenuPopup.gd` — `class_name DebugMenuPopup` extends `PanelContainer`

`563` lines · [back to the map](../../../CODEBASE_MAP.md)

> Tester-only tool palette for the battle scene. Every button here is a *request*: it emits `debug_command_requested` upward and the turn loop performs the mutati…

Sections: Signals · Enums · Constants · Private Variables · Lifecycle Methods · Public Methods · Private Methods · Signal Handlers
- L28 `enum Scope` = ALLIES, ENEMIES, ALL
- L30 `enum CardTier` = BASE, MERGED, DOUBLE_MERGED

Signals:
- L20 `debug_command_requested(command: String, args: Dictionary)` — A tester pressed a tool. `command` is one of the CMD_* ids below and `args` is that tool's payload, documented next to its CMD_* constant.
- L23 `menu_closed` — The panel closed itself (its own close button), so the owner can re-label the button that toggles it.

Constants:
- L36 `CMD_SPAWN_RANDOM: String`
- L37 `CMD_SPAWN_CUSTOM: String`
- L38 `CMD_DRAW: String`
- L39 `CMD_DRAW_TO_MAX: String = "draw_to_max"             # {}`
- L40 `CMD_BUFF_HAND: String`
- L41 `CMD_DISCARD_RANDOM: String = "discard_random"       # {}`
- L42 `CMD_CLEAR_HAND: String = "clear_hand"               # {}`
- L43 `CMD_GRANT_ACTIONS: String`
- L44 `CMD_GRANT_MERGES: String`
- L45 `CMD_STEP_MAX_HAND: String = "step_max_hand"         # { delta: int }`
- L46 `CMD_GRANT_NEXT_BONUS: String = "grant_next_bonus"   # { amount: int }`
- L47 `CMD_STEP_DICE: String`
- L48 `CMD_FILL_MOXIE: String`
- L49 `CMD_DRAIN_MOXIE: String`
- L50 `CMD_HEAL_FULL: String`
- L51 `CMD_DAMAGE: String`
- L52 `CMD_TRUE_DAMAGE: String`
- L53 `CMD_ADD_SHIELD: String`
- L54 `CMD_CLEAR_SHIELD: String`
- L55 `CMD_KILL: String`
- L56 `CMD_APPLY_STATUS: String`
- L57 `CMD_CLEAR_STATUSES: String`
- L58 `CMD_REROLL_INTENTS: String = "reroll_intents"       # {}`
- L59 `CMD_RESPAWN_WAVE: String = "respawn_wave"           # {}`
- L60 `CMD_CLEAR_WAVE: String = "clear_wave"               # {}`
- L63 `DAMAGE_STEP: int = 5` — Amounts the quick action buttons apply.
- L64 `SHIELD_STEP: int = 10`
- L65 `REGEN_STEP: int = 2`
- L66 `GLOOM_STEP: int = 3`
- L69 `PANEL_WIDTH: float = 336.0` — Where the panel sits: bottom-left, directly above the button that opens it.
- L70 `PANEL_HEIGHT: float = 404.0`
- L71 `SEAT_LEFT: float = 18.0`
- L72 `SEAT_BOTTOM: float = 50.0`
- L73 `PADDING: int = 10`
- L75 `CORNER_RADIUS: int = 0` — Square corners (0 px): the panel and the hover tooltip slabs are one flat surface.
- L77 `BORDER_WIDTH: int = 2` — Accent border width, shared with the hover tooltip slab (HudTooltipTheme.tres).
- L78 `ROW_SEPARATION: int = 5`
- L79 `BUTTON_MIN_SIZE: Vector2 = Vector2(0.0, 26.0)`
- L82 `PANEL_BG: Color = Color(0.07, 0.08, 0.11, 0.97)` — Palette lifted from SkillTooltipPopup so the tools read as part of the HUD.
- L83 `PANEL_BORDER: Color = Color(0.45, 0.78, 0.95, 0.5)`
- L84 `TITLE_COLOR: Color = Color(0.55, 0.86, 1.0)`
- L85 `SECTION_COLOR: Color = Color(0.62, 0.72, 0.85)`
- L86 `READOUT_COLOR: Color = Color(0.80, 0.85, 0.93)`
- L87 `OVERFLOW_COLOR: Color = Color(1.0, 0.55, 0.45)`
- L88 `READY_COLOR: Color = Color(0.55, 1.0, 0.68)`
- L89 `LOCKED_COLOR: Color = Color(1.0, 0.72, 0.35)`

State:
- L93 `_status_label: Label`
- L94 `_hand_label: Label`
- L95 `_deck_label: Label`
- L96 `_turn_label: Label`
- L97 `_hand_cap_label: Label`
- L98 `_target_selector: OptionButton`
- L99 `_tier_selector: OptionButton`
- L100 `_value_spin: SpinBox`
- L101 `_close_button: Button`
- L103 `_header: HBoxContainer` — Header row: the drag handle for the whole panel.
- L105 `_dragging: bool = false` — True while the header is held down and dragging the panel.
- L108 `_gated_buttons: Array[Button] = []` — Buttons that mutate battle state. They stay disabled while the turn loop is not waiting for a player action, because that is the only moment it can accept one.
- L110 `_target_entries: Array[Dictionary] = []` — Payload (scope/slot) of each entry in `_target_selector`, in the same order.
- L112 `_target_labels: PackedStringArray = PackedStringArray()` — Labels currently in `_target_selector`, so an unchanged unit list is not rebuilt.

Public API:
- L137-158 `refresh(snapshot: Dictionary, targets: Array[Dictionary]) -> void` — Pushes live readouts and the unit list down from the scene. Called whenever the state changes (every action, every turn), never by this panel itself. turn/wave/…
- L163-172 `set_gameplay_enabled(enabled: bool) -> void` — Enables or greys out every state-mutating tool. The scene locks the panel while the game is animating and unlocks it as soon as it waits for a player action.
- L175-176 `is_open() -> bool`
- L179-180 `open_menu() -> void`
- L183-185 `close_menu() -> void`
- L188-192 `toggle_menu() -> void`

Private:
- L117-128 `_init`
- L198-206 `_seat_above_bottom_left`
- L212-222 `_move_by`
- L227-237 `_apply_chrome`
- L240-277 `_build_layout`
- L282-329 `_build_cards_tab`
- L332-367 `_build_resources_tab`
- L370-421 `_build_units_tab`
- L424-429 `_make_tab`
- L432-438 `_make_label`
- L441-442 `_make_section`
- L445-450 `_make_row`
- L454-462 `_make_gated_button`
- L466-467 `_make_button`
- L471-472 `_make_unit_button`
- L476-480 `_current_target_args`
- L485-499 `_rebuild_targets`
- L504-519 `_snap_int`
- L526-533 `_on_header_gui_input`
- L536-537 `_on_close_pressed`
- L540-541 `_on_action_pressed`
- L546-552 `_on_unit_action_pressed`
- L555-559 `_on_spawn_custom_pressed`

Uses: Card
Used by: GDTest/DebugMenuTest.gd, GDTest/HudTooltipTest.gd, Scenes/BattleScene/BattleScene.gd
Loads: —

