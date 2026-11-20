<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/Cards/CardUI.gd` — `class_name CardUI` extends `PanelContainer`

`1381` lines · [back to the map](../../../CODEBASE_MAP.md)

> Visual representation of one Card in hand. Drag source (play / merge) and drop target (merge only). The card is rendered into an offscreen SubViewport and that…

Sections: Fake-3D rig · Draw animation · Merge animation · Card frame · Card back · Consumed guard · Hover Animation · Fake-3D rig · (+9 more)

Signals:
- L13 `play_requested(card: Card)`

Constants:
- L15 `DRAG_PREVIEW_SIZE: Vector2 = Vector2(100, 145)`
- L16 `DRAG_PREVIEW_SCALE: float = 1.04`
- L17 `DRAG_SOURCE_ALPHA: float = 0.0 # Hide the source card`
- L18 `RETURN_TWEEN_TIME: float = 0.18`
- L19 `RETURN_CANVAS_LAYER: int = 100`
- L20 `PLACEHOLDER_ICON: Texture2D`
- L22 `HOVER_SCALE: float = 1.12`
- L23 `HOVER_LIFT: float = 18.0`
- L24 `HOVER_TWEEN_TIME: float = 0.12`
- L25 `HOVER_Z_INDEX: int = 20`
- L28 `CARD_SIZE: Vector2 = Vector2(100, 145)`
- L29 `CARD_CORNER_RADIUS: float = 6.0`
- L32 `CARD_PADDING: Vector2 = Vector2(20, 20)` — Transparent padding around the card body, so a strongly tilted card has room to stretch its near corners inside the quad instead of being clipped.
- L34 `QUAD_SIZE: Vector2 = Vector2(140, 185)` — Padded quad (and matching SubViewport logical size) in logical pixels.
- L37 `RENDER_SUPERSAMPLE: float = 2.0` — Offscreen supersampling used only while the deal is in flight, so the text and borders stay crisp under the perspective warp. A resting card renders 1:1.
- L38 `FAKE_3D_SHADER: Shader`
- L45 `DRAW_FLIGHT_TIME: float = 0.42` — A drawn card is dealt in from beyond the right edge of the hand and flips from back to front in mid-air, landing straight in its slot: it never stops in the mid…
- L47 `DRAW_ROTATION_DELAY: float = 0.22` — Fraction of the flight spent face down before the flip begins.
- L48 `DRAW_START_YAW: float = 168.0`
- L49 `DRAW_START_PITCH: float = 20.0`
- L50 `DRAW_MID_PITCH: float = -7.0`
- L51 `DRAW_START_BANK: float = 15.0`
- L52 `DRAW_START_SCALE: float = 0.74`
- L53 `DRAW_POP_SCALE: float = 0.035`
- L54 `DRAW_FADE_IN: float = 0.12`
- L55 `DRAW_ARC_BASE: float = 78.0`
- L56 `DRAW_ARC_STEP: float = 10.0`
- L58 `DRAW_ARC_SWING: float = 0.34` — How far along the straight line the Bezier control point is pulled.
- L59 `DRAW_Z_BASE: int = 30`
- L62 `SETTLE_FREQUENCY: float = 7.0` — Critically damped settle, so the flip arrives with a small natural overshoot instead of a dead stop.
- L63 `SETTLE_DAMPING: float = 6.5`
- L79 `FORGE_PLATE_A: String = "ForgePlateA"` — Two cards are merged where the player let go of them. The card they were carrying picks up from the exact point it was released at, the card it was dropped on p…
- L80 `FORGE_PLATE_B: String = "ForgePlateB"`
- L84 `MERGE_CONVERGE_TIME: float = 0.30` — How long the two cards take to drift into each other. Deliberately unhurried: the merge is meant to read as the two cards becoming one, not as an impact.
- L86 `MERGE_REVEAL_TIME: float = 0.26` — How long the card they became takes to swing open out of that fold.
- L89 `MERGE_FOLD_YAW: float = 88.0` — How far each card folds over as it arrives. All the way to edge on, because that is what makes the fold read as the two cards closing.
- L92 `MERGE_FOLD_PITCH: float = 12.0` — A lean into the fold, so it reads as a card rolling over rather than a page being closed. It is back to flat by the time the cards reach the fold.
- L95 `MERGE_UNFOLD_PITCH: float = 10.0` — A lean through the unfold, on top of the yaw. Zero at both ends, so the card starts from the pose the two cards finished in and lands dead flat.
- L101 `MERGE_FADE_FROM_YAW: float = 70.0` — The angle past which a folded card stops being drawn and is faded out instead. A card near edge on has nothing left facing the viewer but its own pale border an…
- L103 `MERGE_POP_SCALE: float = 0.10` — How far past full size the card swells as it settles flat.
- L104 `MERGE_BRAND_SCALE: float = 1.32`
- L105 `MERGE_BRAND_DELAY: float = 0.06`
- L106 `MERGE_BRAND_TIME: float = 0.16`
- L107 `MERGE_Z_INDEX: int = 45`
- L114 `CARD_BG_COLOR: Color = Color(0.16, 0.18, 0.22, 0.96)` — Every card wears the same frame, whatever it has been through. Merging used to repaint the frame (gilded for a merge, cyan for a free-play card), which made a m…
- L115 `CARD_BORDER_COLOR: Color = Color(0.75, 0.78, 0.85, 1.0)`
- L116 `CARD_BORDER_WIDTH: int = 2`
- L117 `CARD_BOX_RADIUS: int = 6`
- L126 `CARD_BACK_LOGO: Texture2D = preload(` — Emblem painted in the middle of the card back - the side a card shows while it flips over on its way out of the deck. The back itself is drawn by res://Shaders/…
- L130 `CARD_BACK_LOGO_SIZE: float = 34.0` — Side of the square, in card pixels, the emblem is fitted into.

Exports:
- L135 `icon_catalog: CardIconCatalog`
- L141 `value_change_delay: float = 0.35` — How long the value label waits before it re-renders after a runtime value change (e.g. an enemy card debuff), mirroring the unit hit-reaction delay so the numbe…

Onready:
- L191 `hover_visual: PanelContainer`
- L192 `icon_row: HBoxContainer`
- L193 `art: TextureRect`
- L194 `value_label: Label`
- L195 `merge_glow: Panel`
- L196 `bounds: Control`

State:
- L132 `_back_logo_texture: Texture2D = null` — Built once and shared by every card: the emblem is the same picture for all.
- L143 `card: Card`
- L144 `hand_bar: HandBar`
- L146 `_hover_tween: Tween`
- L147 `_slide_tween: Tween`
- L148 `_draw_tween: Tween`
- L149 `_is_hovered: bool = false`
- L152 `_hover_wanted: bool = false` — True while the cursor sits inside the slot, even if the card is still flying in from the deck. The hover is applied the moment it lands.
- L154 `_is_drawing: bool = false` — True while the fake-3D deal animation owns the card transform.
- L155 `_pick_selectable: bool = false`
- L156 `_flash_active: bool = false`
- L158 `_flash_hostile: bool = false` — True when the flash was caused by an enemy, so the glow turns red.
- L160 `_drag_in_progress: bool = false`
- L161 `_is_consumed: bool = false`
- L162 `_return_tween: Tween`
- L163 `_return_layer: CanvasLayer`
- L164 `_glow: OutlineGlow`
- L166 `_value_tween: Tween` — Pending delayed re-render of the value label after a runtime value change.
- L170 `_is_merging: bool = false` — Merge state. The merge owns the card transform while it plays, the same way `_is_drawing` owns it during a deal.
- L171 `_merge_tween: Tween`
- L172 `_brand_tween: Tween`
- L176 `_merge_plate_a: ForgePlate` — The two cards in the merge, each a fake-3D copy of one card's face. They are children of this card only so that they are drawn along with it; they are posed in…
- L177 `_merge_plate_b: ForgePlate`
- L181 `_merge_start_a: Vector2 = Vector2.ZERO` — Where each of the two cards set off from, and how big it was, in viewport coordinates. The card the player was carrying starts at the point it was released at,…
- L182 `_merge_start_b: Vector2 = Vector2.ZERO`
- L183 `_merge_start_scale_a: float = 1.0`
- L186 `_visual_root: Control` — Fake-3D rig, built in _ready() so CardUI.tscn stays a plain flat layout.
- L187 `_card_quad: TextureRect`
- L188 `_card_surface: SubViewport`
- L189 `_card_material: ShaderMaterial`

Public API:
- L267-273 `set_pick_selectable(active: bool) -> void` — Highlights this card while the game is asking the player to choose cards in hand. HandBar calls this for every candidate; candidates that have already been pick…
- L280-283 `set_flash_active(active: bool, hostile: bool = false) -> void` — Highlights this card while the game shows which cards it picked on its own (auto_top_n / auto_highest). HandBar times the flash and clears it again. `hostile` i…
- L291-310 `mark_consumed() -> void` — Permanently locks this card against further interaction. Called by HandBar immediately before the removal tween starts, so nothing (drag start, drop target, hov…
- L313-314 `is_consumed() -> bool`
- L363-364 `frame_style() -> StyleBoxFlat` — The frame this card is drawn with. The same one for every card: a merge is something a card has been through, not something that makes it a new object.
- L581-596 `slide_to(target: Vector2, duration: float) -> void` — Glides this card's layout slot to `target` (row-local), so the hand closes up or opens smoothly when another card leaves or arrives instead of snapping.
- L633-634 `is_drawing() -> bool` — True while the fake-3D deal animation owns the card transform.
- L641-665 `play_draw_animation(start_offset: Vector2, delay: float = 0.0, stagger_index: int = 0) -> void` — Deals this card in from the deck: one fast swoop from `start_offset` (CardUI-local pixels) straight into the slot, flipping from the card back to the printed fa…
- L771-772 `is_merging() -> bool` — True while the merge owns the card transform.
- L777-778 `centre() -> Vector2` — Where this card's own body sits on screen. A merge aims the two cards at this, so it is the one position the merge and the hand layout have to agree on.
- L785-788 `make_merge_plate() -> ForgePlate` — A fake-3D copy of this card's face, for use as one of the two cards in a merge. The caller owns the returned plate until `play_merge_animation` takes it over. O…
- L811-859 `play_merge_animation(plate_a: ForgePlate, plate_b: ForgePlate, start_centre_a: Vector2, start_centre_b: Vector2, start_scale_a: float) -> void` — Merges this card out of the two cards it was made from: the card the player was carrying at the point they released it, and the card it was dropped on. The two…
- L1059-1062 `setup(p_card: Card, p_hand_bar: HandBar = null) -> void`

Private:
- L199-231 `_ready`
- L234-241 `_process`
- L249-261 `_refresh_glow`
- L317-325 `_gui_input`
- L326-339 `_exit_tree`
- L342-358 `_style_card_panel`
- L367-382 `_style_merge_glow`
- L387-397 `_update_hover_pivot`
- L414-474 `_build_fake_3d_rig`
- L485-500 `_card_back_logo_texture`
- L505-514 `_on_card_mouse_entered`
- L517-522 `_on_card_mouse_exited`
- L525-558 `_animate_hover`
- L561-574 `_reset_hover_immediate`
- L599-602 `_stop_slide`
- L609-612 `_set_tilt`
- L618-627 `_set_surface_scale`
- L669-677 `_finish_draw_immediate`
- L680-686 `_stop_pose_tweens`
- L690-709 `_apply_draw_pose`
- L712-718 `_finish_draw`
- L721-732 `_apply_flat_pose`
- L737-742 `_settle`
- L745-747 `_ease_out_cubic`
- L751-755 `_ease_in_out_cubic`
- L758-760 `_ease_out_quart`
- L763-765 `_quadratic_bezier`
- L864-870 `_finish_merge_immediate`
- L873-878 `_finish_merge`
- L885-887 `_discard_merge_plate`
- L894-900 `_mount_merge_plate`
- L906-916 `_pose_converge`
- L921-940 `_pose_merge_plate`
- L949-950 `_fold_visibility`
- L962-980 `_on_merge_folded`
- L986-995 `_pose_reveal`
- L1001-1005 `_put_forge_plates_behind_card`
- L1010-1029 `_start_brand_pop`
- L1034-1047 `_end_forge_state`
- L1050-1054 `_clear_merge_plates`
- L1065-1074 `_refresh`
- L1077-1102 `_build_stars_and_indicators`
- L1107-1140 `_get_drag_data`
- L1143-1156 `_make_drag_preview`
- L1162-1181 `_make_visual_copy`
- L1184-1189 `_set_mouse_filter_recursive`
- L1194-1216 `_notification`
- L1219-1225 `_restore_if_unconsumed`
- L1228-1238 `_cancel_return_animation`
- L1241-1283 `_animate_return_to_hand`
- L1286-1297 `_on_return_finished`
- L1302-1321 `_can_drop_data`
- L1324-1345 `_drop_data`
- L1348-1359 `_find_hand_bar`
- L1368-1379 `_on_card_value_changed`

Uses: BattleScene, Card, CardDrag, CardIconCatalog, ForgePlate, GameState, HandBar, OutlineGlow
Used by: GDTest/CardDrawAnimationTest.gd, GDTest/CardMergeAnimationTest.gd, GDTest/CardUITest.gd, GDTest/CodeIndexTest.gd, Scenes/Cards/HandBar.gd, Tools/check_navigation.gd
Loads: res://Scenes/BattleScene/Assets/icon.svg, res://Shaders/FakeCard3D.gdshader, res://Scenes/BattleScene/Assets/icon2.png

