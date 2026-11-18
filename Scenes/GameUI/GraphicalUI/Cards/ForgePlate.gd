class_name ForgePlate
extends Control
## One of the two cards in a merge, drawn as a real fake-3D quad.
##
## A merge has to show two cards banking and folding into each other, so a flat
## copy of a card face is not enough. This wraps a copy of one card's face in the
## same perspective-warped rig a resting card uses (see
## res://Shaders/FakeCard3D.gdshader): a SubViewport holding the face, and a quad
## that samples it through the warp.
##
## It only poses: the owner drives its centre and tilt and frees it when the
## merge is over. It is drawn in viewport space (`top_level`), because a merge
## glides between the point a card was released at and the slot it lands in,
## neither of which is this node's own position in the hand.
##
## @author TheGreatJellyfish
## @version 11/18/2026

#region Constants
const CARD_SIZE: Vector2 = Vector2(100, 145)
const CARD_PADDING: Vector2 = Vector2(20, 20)
const QUAD_SIZE: Vector2 = Vector2(140, 185)
const CARD_CORNER_RADIUS: float = 6.0
const FAKE_3D_SHADER: Shader = preload("res://Shaders/FakeCard3D.gdshader")
#endregion

#region Private Variables
var _material: ShaderMaterial
var _surface: SubViewport
var _quad: TextureRect
#endregion

#region Lifecycle Methods
func _init() -> void:
	name = "ForgePlate"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = CARD_SIZE
	custom_minimum_size = CARD_SIZE
	# No pivot. The card is scaled about the corner it is drawn from, so
	# `position` is always that corner and the centre maths below never has to
	# guess how the engine folds a pivot into `global_position`.
	pivot_offset = Vector2.ZERO


func _ready() -> void:
	# Set here rather than in `_init`, because a control can only be detached
	# from its parent transform once it is in the tree.
	top_level = true


func _exit_tree() -> void:
	if _surface != null:
		_surface.render_target_update_mode = SubViewport.UPDATE_DISABLED
#endregion

#region Public Methods
## Builds the warp around a flat copy of one card's face. The face is reparented
## into the offscreen surface, so the caller must not keep using the node it
## passes in.
func setup(face: Control) -> void:
	_material = ShaderMaterial.new()
	_material.shader = FAKE_3D_SHADER
	_material.set_shader_parameter("quad_size", QUAD_SIZE)
	_material.set_shader_parameter("card_size", CARD_SIZE)
	_material.set_shader_parameter("corner_radius", CARD_CORNER_RADIUS)
	# The two cards fold edge on and are done at that point, so the printed back
	# has no part to play: drawing it would flash a card back at the seam the
	# merged card is about to come out of.
	_material.set_shader_parameter("draw_back", false)
	_material.set_shader_parameter("x_rot", 0.0)
	_material.set_shader_parameter("y_rot", 0.0)

	# Always, not once: a plate only lives for one merge and a blank surface would
	# show as a hole where a card should be. Two small offscreen passes for a few
	# tenths of a second cost nothing.
	_surface = SubViewport.new()
	_surface.name = "PlateSurface"
	_surface.transparent_bg = true
	_surface.gui_disable_input = true
	_surface.disable_3d = true
	_surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_surface.size = Vector2i(int(QUAD_SIZE.x), int(QUAD_SIZE.y))
	add_child(_surface)

	face.set_anchors_preset(Control.PRESET_TOP_LEFT)
	face.position = CARD_PADDING
	face.size = CARD_SIZE
	face.pivot_offset = Vector2.ZERO
	face.scale = Vector2.ONE
	face.rotation = 0.0
	_surface.add_child(face)

	# The quad maps the surface back onto the card's own pixels: the face sits at
	# CARD_PADDING inside quad space, so a quad at -CARD_PADDING lines the card up
	# exactly with the slot it is posing over.
	_quad = TextureRect.new()
	_quad.name = "PlateQuad"
	_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_quad.stretch_mode = TextureRect.STRETCH_SCALE
	_quad.texture = _surface.get_texture()
	_quad.material = _material
	_quad.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_quad.position = -CARD_PADDING
	_quad.size = QUAD_SIZE
	add_child(_quad)


## Puts this card's centre at `centre` in viewport coordinates, whatever size the
## card is currently drawn at.
func set_centre(centre: Vector2) -> void:
	global_position = centre - CARD_SIZE * 0.5 * scale


## Where this card's centre is on screen, whatever size it is drawn at. With no
## pivot the card is scaled about its drawn corner, so the centre sits half a
## card away from it at the card's current size.
func centre() -> Vector2:
	return global_position + CARD_SIZE * 0.5 * scale


## Banks and folds the card in fake 3D, the same way a card being dealt does.
func set_tilt(yaw: float, pitch: float) -> void:
	if _material != null:
		_material.set_shader_parameter("y_rot", yaw)
		_material.set_shader_parameter("x_rot", pitch)


## How far the card is banked and folded right now, in degrees.
func tilt() -> Vector2:
	if _material == null:
		return Vector2.ZERO
	var raw_yaw: Variant = _material.get_shader_parameter("y_rot")
	var raw_pitch: Variant = _material.get_shader_parameter("x_rot")
	var yaw: float = raw_yaw
	var pitch: float = raw_pitch
	return Vector2(yaw, pitch)
#endregion
