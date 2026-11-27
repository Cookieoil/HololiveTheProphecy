<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/BattleUnit/StatusIconCatalog.gd` — `class_name StatusIconCatalog` extends `Resource`

`363` lines · [back to the map](../../../CODEBASE_MAP.md)

> Catalog for character buff/debuff status icons (separate from CardIconCatalog). Provides lookup and automatic inspection of Unit buff/debuff state. Two dictiona…

Sections: Constants · Exports · Lifecycle Methods · Public Methods · Private Methods

Constants:
- L17 `PLACEHOLDER_ICON: Texture2D`
- L21 `SAMPLE_ICON_SVG: Texture2D` — Sample icons shipped with the project. icon.svg is 128x128 and icon2.png is 1000x1000; the UI badge scales both into the same square, so mismatched dimensions (…
- L22 `SAMPLE_ICON_PNG: Texture2D`
- L26 `DEBUFF_KEYWORDS: PackedStringArray = [` — Keyword heuristics: a status id containing one of these counts as a debuff even before it is registered in `debuff_icons`.
- L33 `CONTAINER_PROPS: Array[String] = [` — Status containers a unit may carry, scanned before any flat property: a dictionary of entries or a list of them.
- L40 `KNOWN_BUFF_PROPERTIES: Array[Dictionary] = [` — The known flat buff properties, each with the status id it maps to, the companion property holding its remaining charges (empty for none) and whether the value…

Exports:
- L57 `default_icon: Texture2D = PLACEHOLDER_ICON`
- L58 `buff_icons: Dictionary[String, Texture2D] = {}   # status_id (String) -> Texture2D`
- L59 `debuff_icons: Dictionary[String, Texture2D] = {} # status_id (String) -> Texture2D`

Public API:
- L72-76 `register_default_icons() -> void` — Adds the sample status mappings without overwriting authored entries.
- L80-88 `get_status_icon(status_id: String) -> Texture2D` — Never returns null: unknown ids (and empty slots) fall back to the default.
- L92-101 `is_debuff_id(status_id: String) -> bool` — Registered buff ids win over the keyword heuristics.
- L106-120 `extract_unit_statuses(unit: Object) -> Array[Dictionary]` — Extracts active buffs/debuffs from a Unit instance. Returns Array[Dictionary] with keys: { "id": String, "count": int, "is_debuff": bool, "icon": Texture2D }

Private:
- L66-67 `_init`
- L129-142 `_append_status`
- L148-169 `_collect_from_containers`
- L174-187 `_collect_from_known_properties`
- L191-201 `_variant_active`
- L205-212 `_variant_count`
- L216-227 `_charges_count`
- L231-247 `_collect_from_script_variables`
- L252-259 `_entry_is_debuff`
- L263-270 `_object_bool`
- L273-299 `_extract_count`
- L302-312 `_extract_scalar_int`
- L315-361 `_parse_status_object`

Uses: BattleScene, Unit
Used by: GDTest/StatusCatalogTest.gd, Scenes/BattleScene/BattleScene.gd, Scenes/BattleUnit/UnitUI.gd, Scenes/HUD/TooltipIconCatalog.gd
Loads: res://Scenes/BattleScene/Assets/icon.svg, res://Scenes/BattleScene/Assets/icon2.png

