<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/Unit.gd` — `class_name Unit` extends `RefCounted`

`387` lines · [back to the map](../../CODEBASE_MAP.md)

> Runtime instance of a unit on the board. Mutable HP/Shield state. This is all just data

Sections: Signals · Constants · Public Variables · Lifecycle Methods · Public Methods · Private Methods

Signals:
- L10 `damaged(hp_lost: int, shield_lost: int)`
- L11 `moxie_changed(current: int, maximum: int)`
- L13 `statuses_changed` — Fired whenever the status dictionary changes (applied / stacked / ticked / cleared).

Constants:
- L22 `COUNT_MODE_DURATION: String = "duration"` — Known buff/debuff definitions keyed by the status id used in skills.json ("apply_status" effects). "count_mode" decides what the icon counter means: duration ->…
- L23 `COUNT_MODE_STACKS: String = "stacks"`
- L24 `DEFAULT_COUNT_MODE: String = COUNT_MODE_STACKS`
- L25 `STATUS_REGENERATION: String = "regeneration"`
- L26 `STATUS_GLOOM: String = "gloom"`
- L27 `REGENERATION_HEAL_PER_TICK: int = 3`
- L28 `GLOOM_DAMAGE_PER_STACK: int = 1`
- L29 `STATUS_DEFS: Dictionary = {`

State:
- L44 `data: UnitData`
- L45 `current_hp: int`
- L46 `max_hp: int`
- L47 `shield: int = 0`
- L48 `moxie: int = 0`
- L49 `max_moxie: int = 20`
- L50 `ult_used_this_turn: bool = false`
- L51 `value_modifier: int`
- L52 `slot_index: int = -1 ## Board position (0,1,2)`
- L53 `is_ally: bool = true`
- L58 `statuses: Dictionary = {}` — Active statuses: status_id (String) -> { "count": int, "count_mode": String, "is_debuff": bool }
- L60 `can_cast_ultimate: bool:`
- L67 `is_dead: bool: #true if hp < = 0, false otherwise`
- L71 `missing_hp: int: #return the unit missing HP from max HP`

Public API:
- L93-101 `gain_moxie(amount: int) -> int`
- L103-106 `consume_moxie() -> void`
- L113-118 `clear_moxie() -> void` — Empties the Moxie gauge and releases the once-per-turn Ultimate lock, without pretending an Ultimate was cast. Used when a unit dies and when the battle ends, s…
- L125-129 `set_moxie(value: int) -> void` — Tester/debug hook: forces the Moxie gauge to `value` and clears the once-per-turn Ultimate lock, so a tester can fire an Ultimate on demand instead of waiting f…
- L136-158 `take_damage(amount: int, ignore_shield: bool = false) -> int` — Absorbs via shield, then applies the remainder to HP. Emits `damaged` after both values have been updated so UnitUI can react (flinch + bar drop). Also fires wh…
- L160-164 `heal(amount: int) -> int` — Capped at max_hp. Returns actual HP restored.
- L165-173 `gain_shield(amount: int) -> int`
- L174-176 `reset_shield() -> void`
- L180-184 `reduce_shield(amount: int) -> int` — Directly reduce shield (e.g. Buff merged skill 1). Can't go below 0.
- L189-191 `deal_true_damage(amount: int) -> int` — Deal damage to HP directly, bypassing shields. Can't go below 0.
- L194-195 `apply_value_modifier(amount: int) -> void` — Modify the value based on the amount
- L198-199 `clear_value_modifier() -> void` — Reset the value modifer to 0
- L203-206 `raise_max_hp(new_max: int) -> void` — raise the unit max HP based on the new max HP
- L212-226 `apply_status(status_id: String, amount: int = 1) -> int` — Applies (or stacks) a status. Duration statuses add to their remaining rounds, stack statuses add to their stack count.
- L230-234 `get_status_count(status_id: String) -> int`
- L237-238 `has_status(status_id: String) -> bool`
- L242-246 `clear_statuses() -> void` — Removes every status (used when a unit dies so no badge lingers).
- L254-310 `tick_round_end_statuses() -> Array[Dictionary]` — Runs every active status once, at the end of a round. "duration" statuses fire their effect then lose 1 round (expiring at 0), "stacks" statuses fire their effe…

Private:
- L81-89 `_init`
- L315-319 `_to_string`
- L323-324 `_normalize_status_id`
- L328-335 `_status_def`
- L338-341 `_def_int`
- L344-351 `_def_bool`
- L354-357 `_def_string`
- L361-365 `_entry_count`
- L369-385 `_coerce_int`

Uses: UnitData
Used by: Core/DiceRoller.gd, Core/EnemyIntent.gd, Core/GameState.gd, Core/GameUI.gd, Core/Telemetry/TelemetryDecision.gd, Core/Telemetry/TelemetrySchema.gd, GDTest/AllyKitTest.gd, GDTest/BattleEndTest.gd, GDTest/CardFlashPolicyTest.gd, GDTest/DebugCommandRunnerTest.gd, GDTest/DebugMenuTest.gd, GDTest/EffectBlockMessageTest.gd, GDTest/EnemySkillBalanceTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/EnemyUltAuraTest.gd, GDTest/StatusCatalogTest.gd, GDTest/TelemetryDecisionTest.gd, GDTest/TelemetryTest.gd, GDTest/TooltipIconCatalogTest.gd, Managers/DebugCommandRunner.gd, Managers/EventBus.gd, Managers/GameManager.gd, Managers/TelemetryManager.gd, Scenes/BattleScene/BattleScene.gd, Scenes/BattleUnit/StatusIconCatalog.gd, Scenes/BattleUnit/UnitUI.gd, Scenes/Cards/HandBar.gd, Scenes/HUD/BattleOverlayController.gd, Scenes/HUD/MoxieOrbUI.gd, Scenes/HUD/TooltipIconCatalog.gd, Skills/EffectBlock.gd, Skills/SkillContext.gd, Skills/SkillPreviewFormatter.gd, Tools/validate_gameData.gd
Loads: —

