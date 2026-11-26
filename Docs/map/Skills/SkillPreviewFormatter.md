<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Skills/SkillPreviewFormatter.gd` — `class_name SkillPreviewFormatter` extends `RefCounted`

`400` lines · [back to the map](../../CODEBASE_MAP.md)

> extends RefCounted, 9 function(s)

Constants:
- L5 `COL_NUM = "#FFD966"`
- L6 `COL_MOXIE = "#C77DFF"`
- L7 `COL_ULT = "#FF6B6B"`
- L8 `COL_OK = "#6EE7B7"`
- L9 `COL_MUTED = "#9CA3AF"`
- L11 `MUTED_ICON_SIZE: int = 14` — Slightly smaller inline icons for the dimmed "Merged" reminder line (font_size=12).

Public API:
- L14-75 `static build_card_on_ally_data(ally: Unit, card: Card, state: GameState, tooltip_catalog: TooltipIconCatalog = null) -> Dictionary` — Returns structured data for the Sketch-2 callout when dragging a Card onto an Ally.
- L79-129 `static build_enemy_intent_data(intent: EnemyIntent, state: GameState, tooltip_catalog: TooltipIconCatalog = null) -> Dictionary` — Returns structured data when hovering an Enemy's Dice IntentLabel.
- L133-190 `static build_orb_ultimate_data(unit: Unit, badge_code: String, state: GameState, intent: EnemyIntent = null, tooltip_catalog: TooltipIconCatalog = null) -> Dictionary` — Returns structured data when hovering an Ally or Enemy Moxie/Ultimate Orb (A1-A3 / E1-E3).

Private:
- L195-239 `_resolve_description_lines`
- L242-252 `_estimate_post_blocks_value`
- L255-361 `_substitute_tokens`
- L370-388 `_place_clause_hint`
- L391-395 `_pick_sample_target`
- L398-399 `_num_bb`

Uses: Card, EffectBlock, EnemyIntent, GameState, SkillData, SkillEffect, TooltipIconCatalog, Unit
Used by: GDTest/AllyKitTest.gd, GDTest/EnemySkillBalanceTest.gd, GDTest/TooltipIconCatalogTest.gd, Scenes/HUD/BattleOverlayController.gd, Tools/check_navigation.gd
Loads: res://Data/json/skills.json.

