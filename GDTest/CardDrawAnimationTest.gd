class_name CardDrawAnimationTest
extends GdUnitTestSuite
## Locks in the fake-3D card draw:
##   - every CardUI owns its own warp material, so tilting one card can never
##     tilt the rest of the hand
##   - a dealt card leaves the deck showing its back and lands perfectly flat
##   - the hand reconciles incrementally, so a deal that is still in flight is
##     never torn down by the refresh BattleScene fires after every action
##   - a card resting in hand is never warped, so its size and the spacing of the
##     hand stay exactly as laid out
##
## @author TheGreatJellyfish
## @version 11/17/2026

const CARD_UI_SCENE_PATH: String = "res://Scenes/GameUI/GraphicalUI/Cards/CardUI.tscn"
## Comfortably longer than CardUI.DRAW_FLIGHT_TIME plus the largest deal stagger.
const FLIGHT_SETTLE_MILLIS: int = 900


## Instantiates a real CardUI for a card and puts it in the test scene tree.
func _make_card_ui(card: Card) -> CardUI:
	var scene: PackedScene = load(CARD_UI_SCENE_PATH) as PackedScene
	var node: Node = scene.instantiate()
	add_child(node)
	var ui: CardUI = node as CardUI
	ui.setup(card, null)
	return ui


## Minimal HandBar: the real one lives inside BattleScene, which would start a
## whole game, so only the node path HandBar actually needs is built here.
func _make_hand_bar() -> HandBar:
	var bar: HandBar = HandBar.new()
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "MarginContainer"
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "VBox"
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "CardsRow"
	bar.add_child(margin)
	margin.add_child(column)
	column.add_child(row)
	add_child(bar)
	return bar


func _row(bar: HandBar) -> Array[CardUI]:
	var result: Array[CardUI] = []
	for child: Node in bar.cards_row.get_children():
		var ui: CardUI = child as CardUI
		if ui != null:
			result.append(ui)
	return result


## Reads one of the fake-3D uniforms, so a test can assert on the card's pose.
func _tilt(ui: CardUI, param: StringName) -> float:
	var material: ShaderMaterial = ui._card_material
	assert_object(material).is_not_null()
	var raw: Variant = material.get_shader_parameter(param)
	assert_bool(raw is float).is_true()
	var value: float = raw
	return value


func test_every_card_owns_its_fake_3d_material() -> void:
	var first: CardUI = _make_card_ui(Card.new(3))
	var second: CardUI = _make_card_ui(Card.new(4))

	assert_object(first._card_material).is_not_null()
	assert_object(second._card_material).is_not_null()
	# A shared material would tilt every card in hand at once.
	assert_object(first._card_material).is_not_same(second._card_material)
	# Resting cards stay dead flat, so the warp cannot change how they look.
	assert_float(_tilt(first, "y_rot")).is_equal_approx(0.0, 0.001)
	assert_float(_tilt(second, "x_rot")).is_equal_approx(0.0, 0.001)


func test_dealt_card_starts_face_down_and_lands_flat() -> void:
	var ui: CardUI = _make_card_ui(Card.new(5))
	ui.play_draw_animation(Vector2(740.0, 42.0), 0.0, 0)

	assert_bool(ui.is_drawing()).is_true()
	# It leaves the deck showing its back, i.e. past the 90 degree flip point.
	assert_float(absf(_tilt(ui, "y_rot"))).is_greater(90.0)
	# ...and it starts beyond the right edge of the hand instead of on screen.
	assert_float(ui._visual_root.position.x).is_greater(100.0)

	await await_millis(FLIGHT_SETTLE_MILLIS)

	assert_bool(ui.is_drawing()).is_false()
	assert_float(_tilt(ui, "y_rot")).is_equal_approx(0.0, 0.01)
	assert_float(_tilt(ui, "x_rot")).is_equal_approx(0.0, 0.01)
	assert_float(ui._visual_root.position.x).is_equal_approx(0.0, 0.01)
	assert_float(ui.modulate.a).is_equal_approx(1.0, 0.001)


func test_grabbing_a_card_mid_flight_snaps_it_flat() -> void:
	var ui: CardUI = _make_card_ui(Card.new(6))
	ui.play_draw_animation(Vector2(740.0, 42.0), 0.0, 0)
	# What a fast player does by dragging the card before it has settled.
	ui._finish_draw_immediate()

	assert_bool(ui.is_drawing()).is_false()
	assert_float(_tilt(ui, "y_rot")).is_equal_approx(0.0, 0.001)
	assert_float(ui._visual_root.position.x).is_equal_approx(0.0, 0.001)
	assert_float(ui.modulate.a).is_equal_approx(1.0, 0.001)


func test_set_hand_reuses_the_cards_already_in_the_row() -> void:
	var bar: HandBar = _make_hand_bar()
	var hand: Array[Card] = [Card.new(2), Card.new(3), Card.new(5)]
	bar.set_hand(hand)
	var before: Array[CardUI] = _row(bar)
	assert_int(before.size()).is_equal(3)

	# This refresh runs twice per turn (show_game_state, then
	# show_hand_and_resources) and after every action: it must never tear the row
	# down, or a deal in flight and a hover would both be lost.
	bar.set_hand(hand)

	var after: Array[CardUI] = _row(bar)
	assert_int(after.size()).is_equal(3)
	for index: int in before.size():
		assert_object(after[index]).is_same(before[index])
		assert_bool(after[index].is_drawing()).is_true()


func test_set_hand_only_deals_the_new_cards() -> void:
	var bar: HandBar = _make_hand_bar()
	var kept: Card = Card.new(2)
	bar.set_hand([kept])
	var original: CardUI = _row(bar)[0]

	var drawn: Card = Card.new(6)
	bar.set_hand([kept, drawn])

	var row: Array[CardUI] = _row(bar)
	assert_int(row.size()).is_equal(2)
	assert_object(row[0]).is_same(original)
	# The new card is dealt in from beyond the right edge of the hand.
	assert_bool(row[1].is_drawing()).is_true()
	assert_float(row[1]._visual_root.position.x).is_greater(100.0)


func test_merged_card_pops_in_place_instead_of_flying_in() -> void:
	var bar: HandBar = _make_hand_bar()
	var merged: Card = Card.new(5)
	merged.is_merged = true

	bar.set_hand([merged])

	var ui: CardUI = _row(bar)[0]
	assert_bool(ui.is_drawing()).is_true()
	# Forged in hand: it never leaves its slot for the deck.
	assert_float(absf(ui._visual_root.position.x)).is_less(0.01)
	assert_float(absf(ui._visual_root.position.y)).is_less(0.01)


func test_removed_card_collapses_out_of_the_row() -> void:
	var bar: HandBar = _make_hand_bar()
	var kept: Card = Card.new(2)
	var dropped: Card = Card.new(3)
	bar.set_hand([kept, dropped])
	var kept_ui: CardUI = _row(bar)[0]
	var dropped_ui: CardUI = _row(bar)[1]

	bar.set_hand([kept])

	var row: Array[CardUI] = _row(bar)
	assert_int(row.size()).is_equal(2)
	assert_object(row[0]).is_same(kept_ui)
	# The dropped card is consumed at once and collapses away on its own.
	assert_bool(dropped_ui.is_consumed()).is_true()


func test_the_card_footprint_matches_its_layout_slot() -> void:
	# The fake-3D rig must not change how big a card is, or the hand spacing
	# would drift. The padded quad has to be exactly the card plus its padding,
	# so the visible card body lines up with the 100x145 layout slot.
	var ui: CardUI = _make_card_ui(Card.new(3))
	assert_vector(ui._card_quad.size).is_equal(CardUI.QUAD_SIZE)
	assert_vector(ui._card_quad.position).is_equal(-CardUI.CARD_PADDING)
	assert_vector(CardUI.QUAD_SIZE).is_equal(CardUI.CARD_SIZE + CardUI.CARD_PADDING * 2.0)


func test_hover_scales_the_card_without_warping_it() -> void:
	# Hovering may only scale and lift the card. Any 3D tilt would stretch the
	# near edge past the card's own footprint and make the size and spacing of
	# the hand look wrong, so the warp has to stay flat.
	var ui: CardUI = _make_card_ui(Card.new(4))
	ui._animate_hover(true)

	# Mouse motion across the card - including right at its edge - must be inert.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(2.0, 2.0)
	ui._gui_input(motion)

	assert_float(_tilt(ui, "y_rot")).is_equal_approx(0.0, 0.001)
	assert_float(_tilt(ui, "x_rot")).is_equal_approx(0.0, 0.001)

	await await_millis(300)

	assert_float(ui._visual_root.scale.x).is_equal_approx(CardUI.HOVER_SCALE, 0.01)
	assert_float(ui._visual_root.scale.y).is_equal_approx(CardUI.HOVER_SCALE, 0.01)
	assert_float(ui._visual_root.position.y).is_equal_approx(-CardUI.HOVER_LIFT, 0.5)
	assert_float(_tilt(ui, "y_rot")).is_equal_approx(0.0, 0.001)
	assert_float(_tilt(ui, "x_rot")).is_equal_approx(0.0, 0.001)
