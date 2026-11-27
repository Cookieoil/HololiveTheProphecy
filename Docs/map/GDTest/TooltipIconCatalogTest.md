<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/TooltipIconCatalogTest.gd` — `class_name TooltipIconCatalogTest` extends `GdUnitTestSuite`

`171` lines · [back to the map](../../CODEBASE_MAP.md)

> Tests for the inline tooltip icon system (TooltipIconCatalog + TooltipIconEntry). Covers: left-of-keyword icons (LoR style), pure glyphs (Riftbound style), expl…

Constants:
- L10 `CATALOG_PATH: String`

Public API:
- L22-40 `test_authored_catalog_resolves_both_sample_statuses() -> void`
- L43-51 `test_gloom_icon_is_placed_left_of_the_keyword() -> void`
- L54-62 `test_regeneration_icon_is_placed_left_of_the_keyword() -> void`
- L65-73 `test_keyword_matching_ignores_case_but_not_partial_words() -> void`
- L76-86 `test_icon_only_mode_replaces_the_keyword_with_a_pure_glyph() -> void`
- L89-98 `test_explicit_tokens_honor_the_requested_mode() -> void`
- L101-105 `test_unknown_token_is_stripped_instead_of_leaking_raw_text() -> void`
- L108-119 `test_card_category_token_falls_back_to_a_pure_glyph() -> void`
- L122-130 `test_existing_bbcode_and_image_paths_are_never_rewritten() -> void`
- L133-145 `test_output_is_consumed_by_a_rich_text_label() -> void`
- L148-170 `test_formatter_threads_the_catalog_into_the_tooltip_body() -> void`

Private:
- L13-14 `_fresh_catalog`
- L18-19 `_authored_catalog`

Uses: Card, SkillData, SkillPreviewFormatter, TooltipIconCatalog, TooltipIconEntry, Unit, UnitData
Used by: —
Loads: res://Scenes/BattleScene/Assets/TooltipIcons.tres, res://art/gloom.png

