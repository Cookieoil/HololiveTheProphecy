<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/BattleUnit/StatusIconCatalog.gd` — `class_name StatusIconCatalog` extends `Resource`

`331` lines · [back to the map](../../../CODEBASE_MAP.md)

> Catalog for character buff/debuff status icons (separate from CardIconCatalog). Provides lookup and automatic inspection of Unit buff/debuff state. Two dictiona…

Sections: Constants · Exports · Lifecycle Methods · Public Methods · Private Methods

Constants:
- L17 `PLACEHOLDER_ICON: Texture2D`
- L21 `SAMPLE_ICON_SVG: Texture2D` — Sample icons shipped with the project. icon.svg is 128x128 and icon2.png is 1000x1000; the UI badge scales both into the same square, so mismatched dimensions (…
- L22 `SAMPLE_ICON_PNG: Texture2D`
- L26 `DEBUFF_KEYWORDS: PackedStringArray = [` — Keyword heuristics: a status id containing one of these counts as a debuff even before it is registered in `debuff_icons`.

Exports:
- L33 `default_icon: Texture2D = PLACEHOLDER_ICON`
- L34 `buff_icons: Dictionary[String, Texture2D] = {}   # status_id (String) -> Texture2D`
- L35 `debuff_icons: Dictionary[String, Texture2D] = {} # status_id (String) -> Texture2D`

Public API:
- L48-52 `register_default_icons() -> void` — Adds the sample status mappings without overwriting authored entries.
- L56-64 `get_status_icon(status_id: String) -> Texture2D` — Never returns null: unknown ids (and empty slots) fall back to the default.
- L68-77 `is_debuff_id(status_id: String) -> bool` — Registered buff ids win over the keyword heuristics.
- L82-211 `extract_unit_statuses(unit: Object) -> Array[Dictionary]` — Extracts active buffs/debuffs from a Unit instance. Returns Array[Dictionary] with keys: { "id": String, "count": int, "is_debuff": bool, "icon": Texture2D }

Private:
- L42-43 `_init`
- L220-227 `_entry_is_debuff`
- L231-238 `_object_bool`
- L241-267 `_extract_count`
- L270-280 `_extract_scalar_int`
- L283-329 `_parse_status_object`

Uses: BattleScene, Unit
Used by: GDTest/StatusCatalogTest.gd, Scenes/BattleScene/BattleScene.gd, Scenes/BattleUnit/UnitUI.gd, Scenes/HUD/TooltipIconCatalog.gd
Loads: res://Scenes/BattleScene/Assets/icon.svg, res://Scenes/BattleScene/Assets/icon2.png

