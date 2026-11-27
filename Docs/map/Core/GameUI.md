<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/GameUI.gd` — `class_name GameUI` extends `Node`

`106` lines · [back to the map](../../CODEBASE_MAP.md)

> Abstract UI interface the GameManager talks to. Implemented by the graphical BattleScene; GameManager only talks to this interface. Every input methods are asyn…

Sections: Display (fire-and-forget) · Player Input (async)

Public API:
- L15-17 `show_message(_msg: String) -> void` — Print a single message line to the player.
- L19-21 `show_enemy_intents(_intents: Array[EnemyIntent]) -> void` — Display enemy intent previews for the coming turn.
- L23-25 `show_game_state(_state: GameState) -> void` — Refresh the full board / hand / resource display.
- L26-28 `focus_input() -> void`
- L34-36 `play_unit_skill(_unit: Unit, _skill_index: int, _rank: int = 0, _lead: float = 1.0) -> void` — Plays the unit's skill animation and waits for the caller's turn to continue. `lead` is the fraction of the animation the caller waits for: 1.0 (default) waits…
- L37-39 `play_unit_ultimate(_unit: Unit) -> void`
- L42-44 `clear_unit_intent(_unit: Unit) -> void` — Presentation cue: an enemy is about to act (or is skipped because it's dead), so its intent preview should disappear.
- L46-47 `on_card_played(_card: Card, _state: GameState) -> void` — Presentation cue: a card was accepted and left the hand.
- L54-60 `on_cards_merged(_source_a: Card, _source_b: Card, _result: Card, _state: GameState) -> void` — Presentation cue: two cards in hand were fused into `result` by a merge. `source_a` is the card that was dragged and `source_b` the card it was dropped on; `res…
- L68-69 `flash_auto_selected_cards(_cards: Array[Card], _hostile: bool = false) -> void` — Presentation cue: the game picked these cards out of the hand on its own (auto_top_n / auto_highest), so no prompt was shown. Briefly highlight them so the play…
- L74-75 `show_battle_result(_victory: bool) -> void` — Presentation cue: the battle is over. Plays the Victory / Defeat cutscene and keeps the result on screen until the player restarts. Callers may `await` this; im…
- L85-89 `get_player_action(_state: GameState) -> Dictionary` — Ask the player for their next action. Returns a Dictionary with at minimum a key "type": "play"		-> { type, card: Card, target_ally: Unit } "merge"		-> { type,…
- L92-95 `ask_pick_targets(_units: Array[Unit], _count: int) -> Array[Unit]` — Ask the player to pick 'count' unit from 'units'. returns the chosen units (fewer if not enough).
- L98-101 `ask_pick_cards(_cards: Array[Card], _count: int) -> Array[Card]` — Ask the player to pick 'count' cards from 'cards'. Returns the chosen cards.
- L103-104 `show_hand_and_resources(_state: GameState) -> void` — Refresh hand and resource counters (Actions, Merges, Deck, Discard).

Uses: Card, EnemyIntent, GameState, Unit
Used by: GDTest/BattleEndTest.gd, GDTest/CardFlashPolicyTest.gd, GDTest/DebugMenuTest.gd, GDTest/EnemyTurnOverlapTest.gd, GDTest/TelemetryTest.gd, Managers/GameManager.gd, Scenes/BattleScene/BattleScene.gd
Loads: —

