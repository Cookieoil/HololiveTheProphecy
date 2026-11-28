<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/Telemetry/TelemetrySchema.gd` — `class_name TelemetrySchema` extends `RefCounted`

`313` lines · [back to the map](../../../CODEBASE_MAP.md)

> Pure serialisers that turn live game objects into the plain Dictionaries the telemetry spool stores. Every function is static and side-effect free, so the shape…

Sections: Constants · Public Methods · Private Methods

Constants:
- L15 `SCHEMA_VERSION: int = 1`
- L16 `PARITY_ODD: String = "odd"`
- L17 `PARITY_EVEN: String = "even"`
- L20 `MAX_ROWS: int = 40` — Cap on how many cards/damage rows a single event may carry, so a pathological debug hand cannot bloat the spool.

Public API:
- L25-32 `static new_id() -> String` — A random RFC-4122-shaped id built from engine-grade entropy (no extra deps).
- L35-36 `static now_unix() -> float`
- L40-55 `static card_snapshot(card: Card) -> Dictionary` — One card as offered/held, keyed on its merge state instead of its slot.
- L59-66 `static merge_rank(card: Card) -> int` — 0 = base, 1 = merged (MV), 2 = double merged (DMV).
- L69-72 `static parity_of(card: Card) -> String`
- L79-87 `static card_key(card: Card) -> String` — A stable identity for one offered card, independent of its slot: the effective value plus its merge tier ("3", "5_merged", "9_double_merged"). Two copies of the…
- L90-96 `static cards_snapshot(cards: Array[Card]) -> Array`
- L100-116 `static unit_snapshot(unit: Unit) -> Dictionary` — One unit as it stands right now (HP, shield, Moxie, statuses, Ultimate ready).
- L120-131 `static unit_ref(unit: Unit) -> Dictionary` — Lightweight unit reference for offered/picked candidate lists.
- L134-140 `static unit_refs(units: Array[Unit]) -> Array`
- L143-149 `static units_snapshot(units: Array[Unit]) -> Array`
- L153-156 `static unit_id_of(unit: Unit) -> String` — The stable unit id behind a runtime unit (never the display name).
- L160-163 `static skill_id_of(skill: SkillData) -> String` — The stable skill id behind a skill resource (never the display name).
- L166-176 `static statuses_of(unit: Unit) -> Dictionary`
- L180-193 `static intent_snapshot(intent: EnemyIntent) -> Dictionary` — One enemy's pre-rolled intent for the current turn.
- L196-202 `static intents_snapshot(intents: Array[EnemyIntent]) -> Array`
- L206-210 `static board_snapshot(state: GameState) -> Dictionary` — Full board: every ally and enemy with its current stats.
- L216-245 `static battlefield_metrics(state: GameState, intents: Array[EnemyIntent]) -> Dictionary` — The "how is the fight going" numbers that de-bias win-rate correlation: they are recorded *before* the decision, so a metric can be stratified by whether the pl…
- L248-251 `static ratio(numerator: int, denominator: int) -> float`
- L254-259 `static living_count(units: Array[Unit]) -> int`
- L266-290 `static run_started_snapshot(state: GameState, game_version: String, balance_hash: String, player_run_number: int, ally_lineup: Array) -> Dictionary` — The values a run opens with, stored on `run_started`. Built here for the same reason every other event is: the recorder routes, this file decides what an event…
- L295-311 `static to_int(value: Variant, fallback: int = 0) -> int` — Coerces any Variant into an int (dictionaries read back from JSON are floats).

Uses: Card, EnemyIntent, GameState, SkillData, Unit
Used by: Core/Telemetry/TelemetryDecision.gd, GDTest/SkillContextFactoryTest.gd, GDTest/TelemetryConsentTest.gd, GDTest/TelemetryDecisionTest.gd, GDTest/TelemetryTest.gd, GDTest/TelemetryUploaderTest.gd, GDTest/TurnLoopTest.gd, Managers/GameManager.gd, Managers/TelemetryManager.gd, Tools/BattleSimulator.gd
Loads: —

