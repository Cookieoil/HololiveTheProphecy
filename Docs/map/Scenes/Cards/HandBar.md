<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/Cards/HandBar.gd` — `class_name HandBar` extends `PanelContainer`

`430` lines · [back to the map](../../../CODEBASE_MAP.md)

> Bottom-edge hand of cards. View-only: it animates, GameManager validates.

Sections: Deal choreography · Lifecycle · Public API (called by GraphicalGameUI) · EventBus handlers

Signals:
- L6 `merge_requested(card_a: Card, card_b: Card)`
- L7 `drag_started(card: Card)`
- L8 `drag_ended(card: Card)`
- L9 `card_clicked(card: Card)`

Constants:
- L11 `CARD_SCENE: PackedScene`
- L12 `ENTER_TWEEN_TIME: float = 0.22`
- L14 `SLIDE_TIME: float = 0.22` — How long a card takes to glide to its new slot when the hand changes.
- L15 `CARD_WIDTH: float = 100.0`
- L16 `CARD_HEIGHT: float = 145.0`
- L18 `AUTO_FLASH_HOLD: float = 0.55` — How long auto-selected cards stay lit before the flash fades out.
- L23 `DEAL_STAGGER: float = 0.068` — Seconds between two cards of the same deal, so a full opening hand fans out in well under a second instead of arriving as one block.
- L27 `DECK_DROP: float = 42.0` — Deck origin as an offset from the card's own slot: beyond the right edge of the hand, so every drawn card is dealt in from off-screen straight to its place inst…
- L30 `DECK_STACK_STEP: Vector2 = Vector2(16.0, 8.0)` — Alternating deck position, so a multi-card deal looks like it comes off a small pile rather than a single point.

Onready:
- L57 `cards_row: HBoxContainer`

State:
- L33 `game_state: GameState`
- L37 `_pick_active: bool = false`
- L38 `_pick_candidates: Array[Card] = []`
- L44 `_release_card: Card` — Where the card the player was carrying was let go of, if the merge about to be played was driven by a real drag. Recorded by the card it was dropped on and cons…
- L45 `_release_centre: Vector2 = Vector2.ZERO`
- L46 `_has_merge_release: bool = false`
- L50 `_deal_slot: int = 0` — Stagger slot handed to each card dealt within the same frame. Reset once the frame is over, so a later, separate draw always starts at zero again.
- L51 `_deal_slot_queued: bool = false`
- L55 `_row_laid_out: bool = false` — True once the row has been laid out at least once. Until then a card's position is meaningless, so nothing may be animated away from it.

Public API:
- L76-82 `set_pick_candidates(candidates: Array[Card], active: bool) -> void`
- L90-111 `flash_auto_selected(cards: Array[Card], hostile: bool = false) -> void` — Briefly highlights cards the game picked on its own (auto_top_n / auto_highest) so the player can see which cards were affected even though no prompt was shown.…
- L133-152 `set_hand(cards: Array[Card]) -> void` — Rebuilds the row from the model, reusing every CardUI that is still valid. A deal that is still in flight, a hover, or a pick highlight therefore all survive th…
- L158-165 `add_card(card: Card) -> void` — Appends one newly drawn card to the right end of the row, matching the model (which also appends), and deals it in from the deck. Safe to call twice for the sam…
- L172-175 `note_merge_release(card: Card, global_centre: Vector2) -> void` — Records where a card was let go of, so the merge it triggers can start that card from that exact point on screen instead of from the slot it was dragged out of.…
- L188-245 `play_merge(card_a: Card, card_b: Card, merged_card: Card, new_hand: Array[Card]) -> void` — Merges two cards in hand where the player left them: the card they were carrying drifts out of the point they released it at into the card they dropped it on, t…
- L250-253 `remove_card(card: Card) -> void` — A card left the hand: it drops out of the row at once and the cards around it glide into the gap it left.
- L365-371 `can_merge(card_a: Card, card_b: Card) -> bool`

Private:
- L62-70 `_ready`
- L118-123 `_apply_pick_candidates`
- L258-268 `_consume_card`
- L272-276 `_snapshot_slots`
- L282-287 `_glide_to_new_slots`
- L290-303 `_apply_glide`
- L306-327 `_spawn_card`
- L332-338 `_next_deal_slot`
- L341-343 `_reset_deal_slots`
- L349-352 `_deck_offset`
- L356-362 `_live_card_uis`
- L376-398 `_get_game_state`
- L401-406 `_find_card_ui`
- L414-415 `_on_event_card_played`
- L420-421 `_on_event_card_drawn`
- L426-427 `_on_event_card_discarded`

Uses: BattleScene, Card, CardUI, ForgePlate, GameManager, GameState, Unit
Used by: GDTest/CardDrawAnimationTest.gd, GDTest/CardMergeAnimationTest.gd, Scenes/BattleScene/BattleScene.gd, Scenes/Cards/CardDrag.gd, Scenes/Cards/CardUI.gd, Scenes/HUD/DebugMenuPopup.gd
Loads: res

