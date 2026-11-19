<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/Cards/ForgePlate.gd` — `class_name ForgePlate` extends `Control`

`140` lines · [back to the map](../../../CODEBASE_MAP.md)

> One of the two cards in a merge, drawn as a real fake-3D quad. A merge has to show two cards banking and folding into each other, so a flat copy of a card face…

Sections: Constants · Private Variables · Lifecycle Methods · Public Methods

Constants:
- L20 `CARD_SIZE: Vector2 = Vector2(100, 145)`
- L21 `CARD_PADDING: Vector2 = Vector2(20, 20)`
- L22 `QUAD_SIZE: Vector2 = Vector2(140, 185)`
- L23 `CARD_CORNER_RADIUS: float = 6.0`
- L24 `FAKE_3D_SHADER: Shader`

State:
- L28 `_material: ShaderMaterial`
- L29 `_surface: SubViewport`
- L30 `_quad: TextureRect`

Public API:
- L61-107 `setup(face: Control) -> void` — Builds the warp around a flat copy of one card's face. The face is reparented into the offscreen surface, so the caller must not keep using the node it passes i…
- L112-113 `set_centre(centre: Vector2) -> void` — Puts this card's centre at `centre` in viewport coordinates, whatever size the card is currently drawn at.
- L119-120 `centre() -> Vector2` — Where this card's centre is on screen, whatever size it is drawn at. With no pivot the card is scaled about its drawn corner, so the centre sits half a card awa…
- L124-127 `set_tilt(yaw: float, pitch: float) -> void` — Banks and folds the card in fake 3D, the same way a card being dealt does.
- L131-138 `tilt() -> Vector2` — How far the card is banked and folded right now, in degrees.

Private:
- L34-43 `_init`
- L46-49 `_ready`
- L52-54 `_exit_tree`

Uses: —
Used by: GDTest/CardMergeAnimationTest.gd, Scenes/Cards/CardUI.gd, Scenes/Cards/HandBar.gd
Loads: res

