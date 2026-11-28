class_name BattleOverlayControllerTest
extends GdUnitTestSuite
## Locks how the overlay finds the scene it belongs to. `BattleOverlay` is a node in
## BattleScene.tscn, so the scene root owns it and the entity rows
## (`EntityOverlay/AlliesRow` and `EntityOverlay/EnemiesRow`) are resolved from that
## root: `owner` by default, or the `scene_root` a test injects.
##
## What it must never do is walk up into whatever happens to be its parent. A node that
## merely contains the controller does not get to decide which rows the battle binds, so
## the rows are resolved from an owned scene root or not at all.
##
## @author TheGreatJellyfish
## @version 11/27/2026


## A stand-in for the battle scene root: it holds the two rows at the path the
## controller resolves and nothing else.
func _make_scene_root() -> Node:
	var root: Node = Node.new()
	var overlay: CanvasLayer = CanvasLayer.new()
	overlay.name = "EntityOverlay"
	for row_name: String in ["AlliesRow", "EnemiesRow"]:
		var row: HBoxContainer = HBoxContainer.new()
		row.name = row_name
		overlay.add_child(row)
	root.add_child(overlay)
	add_child(root)
	return root


## A controller inside the test tree: adding it runs `_ready`, which builds the rails
## and the tooltip layer exactly like the real scene does.
func _make_controller() -> BattleOverlayController:
	var controller: BattleOverlayController = BattleOverlayController.new()
	add_child(controller)
	return controller


## A texture with a visible size, so an AtlasTexture can be told apart from its source.
func _texture(width: int = 8, height: int = 8) -> Texture2D:
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 0.5, 0.25, 1.0))
	return ImageTexture.create_from_image(image)


## A stand-in for the battle row: the lookup reads the children of the node it is handed,
## because the portrait is a child of the UnitUI rather than the UnitUI itself.
func _row_holder() -> Node:
	var holder: Node = Node.new()
	add_child(holder)
	return holder


## The orb rails borrow the portrait the battle row already draws, because the unit list
## carries no art of its own. Whatever the row holds, this is what it can find: an
## animation frame, a slice of a sprite sheet, a plain sprite or a big enough TextureRect,
## and a plain texture is handed over as-is rather than copied into an atlas.
func test_the_portrait_lookup_understands_every_row_shape() -> void:
	var controller: BattleOverlayController = _make_controller()
	var source: Texture2D = _texture(16, 16)

	var animated_row: Node = _row_holder()
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(&"idle")
	frames.add_frame(&"idle", source)
	var animated: AnimatedSprite2D = AnimatedSprite2D.new()
	animated.sprite_frames = frames
	animated.animation = &"idle"
	animated_row.add_child(animated)
	assert_object(controller._find_character_texture_in_node(animated_row)).is_equal(source)

	# A sprite sheet is sliced: the orb gets one frame, not the whole strip.
	var sheet_row: Node = _row_holder()
	var sheet: Sprite2D = Sprite2D.new()
	sheet.texture = _texture(16, 8)
	sheet.hframes = 2
	sheet_row.add_child(sheet)
	var sliced: Texture2D = controller._find_character_texture_in_node(sheet_row)
	assert_bool(sliced is AtlasTexture).is_true()
	if sliced is AtlasTexture:
		var atlas: AtlasTexture = sliced
		assert_object(atlas.atlas).is_equal(sheet.texture)
		assert_float(atlas.region.size.x).is_equal_approx(8.0, 0.01)

	var plain_row: Node = _row_holder()
	var plain: Sprite2D = Sprite2D.new()
	plain.texture = source
	plain_row.add_child(plain)
	assert_object(controller._find_character_texture_in_node(plain_row)).is_equal(source)


func test_the_portrait_lookup_ignores_the_intent_and_status_chrome() -> void:
	var controller: BattleOverlayController = _make_controller()
	var chrome: Texture2D = _texture(64, 64)
	var row: Node = _row_holder()
	for name_value: String in ["IntentIcon", "ShieldBar", "StatusGrid", "IconRow"]:
		var decoy: TextureRect = TextureRect.new()
		decoy.name = name_value
		decoy.texture = chrome
		decoy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		decoy.size = Vector2(64.0, 64.0)
		row.add_child(decoy)
	# Only chrome in the row: there is no portrait to find, and a big status icon is not
	# mistaken for one.
	assert_object(controller._find_character_texture_in_node(row)).is_null()

	# A small image inside a nested wrapper is not a portrait either, which is how the
	# real row's skill-category icons are laid out.
	var wrapper: MarginContainer = MarginContainer.new()
	wrapper.name = "BodyVBox"
	row.add_child(wrapper)
	var small: TextureRect = TextureRect.new()
	small.texture = chrome
	small.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	small.size = Vector2(16.0, 16.0)
	wrapper.add_child(small)
	assert_object(controller._find_character_texture_in_node(row)).is_null()

	var portrait: TextureRect = TextureRect.new()
	portrait.texture = chrome
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.size = Vector2(40.0, 40.0)
	wrapper.add_child(portrait)
	assert_object(controller._find_character_texture_in_node(row)).is_equal(chrome)


func test_injected_scene_root_binds_both_entity_rows() -> void:
	var root: Node = _make_scene_root()
	var controller: BattleOverlayController = _make_controller()
	controller.scene_root = root

	controller._auto_bind_scene_rows()

	assert_object(controller._allies_row).is_equal(root.get_node("EntityOverlay/AlliesRow"))
	assert_object(controller._enemies_row).is_equal(root.get_node("EntityOverlay/EnemiesRow"))


## The rows sit one node up in this tree - exactly where the removed upward walk used to
## look - and they are still not taken: row binding comes from an owned scene root,
## never from the parent a node happens to be dropped under.
func test_an_unowned_parent_does_not_supply_the_rows() -> void:
	var host: Node = _make_scene_root()
	var controller: BattleOverlayController = BattleOverlayController.new()
	host.add_child(controller)

	controller._auto_bind_scene_rows()

	assert_object(controller._allies_row).is_null()
	assert_object(controller._enemies_row).is_null()
