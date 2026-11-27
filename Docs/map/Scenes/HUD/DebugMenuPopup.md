<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/HUD/DebugMenuPopup.gd` — `class_name DebugMenuPopup` extends `PanelContainer`

`704` lines · [back to the map](../../../CODEBASE_MAP.md)

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
- L61 `CMD_SHOW_VICTORY: String = "show_victory"           # {}`
- L62 `CMD_SHOW_DEFEAT: String = "show_defeat"             # {}`
- L63 `CMD_SET_FLAG: String`
- L66 `DAMAGE_STEP: int = 5` — Amounts the quick action buttons apply.
- L67 `SHIELD_STEP: int = 10`
- L68 `REGEN_STEP: int = 2`
- L69 `GLOOM_STEP: int = 3`
- L72 `PANEL_WIDTH: float = 336.0` — Where the panel sits: bottom-left, directly above the button that opens it.
- L73 `PANEL_HEIGHT: float = 404.0`
- L74 `SEAT_LEFT: float = 18.0`
- L75 `SEAT_BOTTOM: float = 50.0`
- L76 `PADDING: int = 10`
- L78 `CORNER_RADIUS: int = 0` — Square corners (0 px): the panel and the hover tooltip slabs are one flat surface.
- L80 `BORDER_WIDTH: int = 2` — Accent border width, shared with the hover tooltip slab (HudTooltipTheme.tres).
- L81 `ROW_SEPARATION: int = 5`
- L82 `BUTTON_MIN_SIZE: Vector2 = Vector2(0.0, 26.0)`
- L85 `PANEL_BG: Color = Color(0.07, 0.08, 0.11, 0.97)` — Palette lifted from SkillTooltipPopup so the tools read as part of the HUD.
- L86 `PANEL_BORDER: Color = Color(0.45, 0.78, 0.95, 0.5)`
- L87 `TITLE_COLOR: Color = Color(0.55, 0.86, 1.0)`
- L88 `SECTION_COLOR: Color = Color(0.62, 0.72, 0.85)`
- L89 `READOUT_COLOR: Color = Color(0.80, 0.85, 0.93)`
- L90 `OVERFLOW_COLOR: Color = Color(1.0, 0.55, 0.45)`
- L91 `READY_COLOR: Color = Color(0.55, 1.0, 0.68)`
- L92 `LOCKED_COLOR: Color = Color(1.0, 0.72, 0.35)`

State:
- L96 `_status_label: Label`
- L97 `_hand_label: Label`
- L98 `_deck_label: Label`
- L99 `_turn_label: Label`
- L100 `_hand_cap_label: Label`
- L101 `_target_selector: OptionButton`
- L102 `_tier_selector: OptionButton`
- L103 `_value_spin: SpinBox`
- L104 `_close_button: Button`
- L106 `_header: HBoxContainer` — Header row: the drag handle for the whole panel.
- L108 `_dragging: bool = false` — True while the header is held down and dragging the panel.
- L111 `_gated_buttons: Array[Button] = []` — Buttons that mutate battle state. They stay disabled while the turn loop is not waiting for a player action, because that is the only moment it can accept one.
- L113 `_target_entries: Array[Dictionary] = []` — Payload (scope/slot) of each entry in `_target_selector`, in the same order.
- L115 `_target_labels: PackedStringArray = PackedStringArray()` — Labels currently in `_target_selector`, so an unchanged unit list is not rebuilt.
- L118 `_flags_hint: Label` — Flags tab: one toggle per staged flag (Core/FeatureFlags.gd), rebuilt only when the flag set changes so a refresh does not churn the node tree.
- L119 `_flags_list: VBoxContainer`
- L120 `_flag_labels: PackedStringArray = PackedStringArray()`
- L121 `_flag_toggles: Dictionary[String, CheckButton] = {}`

Public API:
- L146-168 `refresh(snapshot: Dictionary, targets: Array[Dictionary]) -> void` — Pushes live readouts and the unit list down from the scene. Called whenever the state changes (every action, every turn), never by this panel itself. turn/wave/…
- L173-182 `set_gameplay_enabled(enabled: bool) -> void` — Enables or greys out every state-mutating tool. The scene locks the panel while the game is animating and unlocks it as soon as it waits for a player action.
- L185-186 `is_open() -> bool`
- L189-190 `open_menu() -> void`
- L193-195 `close_menu() -> void`
- L198-202 `toggle_menu() -> void`
- L207-218 `show_tab(title: String) -> bool` — Selects a tab by its title. Tooling seam: the UI snapshot runner captures each tab, and a tester can jump straight to one.

Private:
- L126-137 `_init`
- L224-232 `_seat_above_bottom_left`
- L238-248 `_move_by`
- L253-263 `_apply_chrome`
- L266-305 `_build_layout`
- L310-357 `_build_cards_tab`
- L360-395 `_build_resources_tab`
- L398-449 `_build_units_tab`
- L455-462 `_build_screen_tab`
- L468-476 `_build_flags_tab`
- L481-496 `_rebuild_flags`
- L499-523 `_build_flag_rows`
- L526-530 `_sync_flag_values`
- L533-542 `_flag_enabled`
- L547-555 `_flag_tooltip`
- L558-562 `_on_flag_toggled`
- L565-570 `_make_tab`
- L573-579 `_make_label`
- L582-583 `_make_section`
- L586-591 `_make_row`
- L595-603 `_make_gated_button`
- L607-608 `_make_button`
- L612-613 `_make_unit_button`
- L617-621 `_current_target_args`
- L626-640 `_rebuild_targets`
- L645-660 `_snap_int`
- L667-674 `_on_header_gui_input`
- L677-678 `_on_close_pressed`
- L681-682 `_on_action_pressed`
- L687-693 `_on_unit_action_pressed`
- L696-700 `_on_spawn_custom_pressed`

Uses: Card
Used by: GDTest/DebugFlagsTest.gd, GDTest/DebugMenuTest.gd, GDTest/HudTooltipTest.gd, Scenes/BattleScene/BattleScene.gd
Loads: —

