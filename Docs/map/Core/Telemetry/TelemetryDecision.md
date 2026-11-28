<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/Telemetry/TelemetryDecision.gd` — `class_name TelemetryDecision` extends `RefCounted`

`220` lines · [back to the map](../../../CODEBASE_MAP.md)

> Pure shapers for one recorded decision: what the player could have done (`offered`) and what they actually did (`chosen`). Split out of Managers/TelemetryManage…

Sections: Public Methods · Private Methods

Public API:
- L23-44 `static offered(state: GameState, intents: Array[EnemyIntent]) -> Dictionary` — Everything the player could have done at this instant: the full hand, every legal (ally, card) play, every legal merge pair, the ready Ultimates, the living ene…
- L50-75 `static playable_skill_options(state: GameState) -> Array` — Every (ally, card) play the player could legally make right now. This is the true denominator behind a skill pick rate: "striker_1 was playable on N decisions a…
- L80-101 `static legal_merge_pairs(state: GameState) -> Array` — Every pair in hand that could legally be merged, with the value the result would have. Capped at MAX_ROWS, so a wide hand cannot bloat the event.
- L107-121 `static chosen_play(action: Dictionary, state: GameState) -> Dictionary` — What one played card did: which card left the hand, which ally it went on and which skill that unlocked. `applied` is false when the play was rejected, which th…
- L126-134 `static chosen_merge(action: Dictionary, merge_result: Dictionary) -> Dictionary` — What one merge produced. `merge_result` is the recorder's note of the forged card, empty when the merge was rejected.
- L138-147 `static chosen_ultimate(action: Dictionary) -> Dictionary` — What one cast Ultimate did: which ally spent it and which skill it was.

Private:
- L154-175 `_ally_readiness`
- L179-185 `_card_keys`
- L189-195 `_playable_skill_ids`
- L199-218 `_intent_threat`

Uses: Card, EnemyIntent, GameState, SkillData, TelemetrySchema, Unit
Used by: Managers/TelemetryManager.gd
Loads: —

