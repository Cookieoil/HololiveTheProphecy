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
