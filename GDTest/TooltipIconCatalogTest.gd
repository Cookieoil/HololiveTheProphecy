class_name TooltipIconCatalogTest
extends GdUnitTestSuite
## Tests for the inline tooltip icon system (TooltipIconCatalog + TooltipIconEntry).
## Covers: left-of-keyword icons (LoR style), pure glyphs (Riftbound style),
## explicit {icon:...} tokens, unknown-token stripping and BBCode safety.
##
## @author TheGreatJellyfish
## @version 11/16/2026

const CATALOG_PATH: String = "res://Scenes/BattleScene/Assets/TooltipIcons.tres"

## Fresh (uncached) catalog so a test can safely mutate entries.
func _fresh_catalog() -> TooltipIconCatalog:
	return TooltipIconCatalog.new()


## Catalog authored in TooltipIcons.tres (wired into BattleScene.tscn).
func _authored_catalog() -> TooltipIconCatalog:
	return load(CATALOG_PATH) as TooltipIconCatalog


func test_authored_catalog_resolves_both_sample_statuses() -> void:
	var catalog: TooltipIconCatalog = _authored_catalog()
	assert_bool(catalog != null).is_true()
	if catalog == null:
		return

	var gloom: TooltipIconEntry = catalog.find_entry("gloom")
	var regeneration: TooltipIconEntry = catalog.find_entry("regeneration")
	assert_bool(gloom != null).is_true()
	assert_bool(regeneration != null).is_true()
	if gloom == null or regeneration == null:
		return

	# Samples ship with a left icon + colored keyword, not a bare word.
	assert_bool(gloom.display_mode == TooltipIconEntry.DisplayMode.ICON_AND_KEYWORD).is_true()
	assert_bool(regeneration.display_mode == TooltipIconEntry.DisplayMode.ICON_AND_KEYWORD).is_true()
	assert_bool(gloom.icon != null).is_true()
	assert_bool(regeneration.icon != null).is_true()
	assert_bool(catalog.has_entry("not_a_registered_keyword")).is_false()


func test_gloom_icon_is_placed_left_of_the_keyword() -> void:
	var catalog: TooltipIconCatalog = _fresh_catalog()
	var out: String = catalog.format_description(
		"Deal 4 damage to 1 enemy and inflict 2 Gloom on it."
	)
	assert_str(out).contains("[img=")
	assert_str(out).contains("[/img]")
	assert_bool(out.find("Gloom") > out.find("[img=")).is_true()
	assert_bool(out.contains("{icon:")).is_false()


func test_regeneration_icon_is_placed_left_of_the_keyword() -> void:
	var catalog: TooltipIconCatalog = _fresh_catalog()
	var out: String = catalog.format_description(
		"Shield all allies for 4. Grant all allies 3 rounds of Regeneration."
	)
	var icon_at: int = out.find("[img=")
	var keyword_at: int = out.find("Regeneration")
	assert_bool(icon_at >= 0).is_true()
	assert_bool(keyword_at > icon_at).is_true()


func test_keyword_matching_ignores_case_but_not_partial_words() -> void:
	var catalog: TooltipIconCatalog = _fresh_catalog()
	var lowercase: String = catalog.format_description("inflict 2 gloom on it.")
	assert_str(lowercase).contains("[img=")
	# The authored display name wins, so prose casing stays consistent.
	assert_str(lowercase).contains("Gloom")

	var partial: String = catalog.format_description("A Gloomiest shadow.")
	assert_str(partial).is_equal("A Gloomiest shadow.")


func test_icon_only_mode_replaces_the_keyword_with_a_pure_glyph() -> void:
	var catalog: TooltipIconCatalog = _fresh_catalog()
	var entry: TooltipIconEntry = catalog.find_entry("gloom")
	assert_bool(entry != null).is_true()
	if entry == null:
		return

	entry.display_mode = TooltipIconEntry.DisplayMode.ICON_ONLY
	var out: String = catalog.format_description("Inflict 2 Gloom.")
	assert_str(out).contains("[img=")
	assert_bool(out.contains("Gloom")).is_false()


func test_explicit_tokens_honor_the_requested_mode() -> void:
	var catalog: TooltipIconCatalog = _fresh_catalog()

	var forced_keyword: String = catalog.format_description("Inflict {kw:gloom}.")
	assert_str(forced_keyword).contains("[img=")
	assert_str(forced_keyword).contains("Gloom")

	var forced_icon: String = catalog.format_description("Inflict {icon_only:gloom}.")
	assert_str(forced_icon).contains("[img=")
	assert_bool(forced_icon.contains("Gloom")).is_false()


func test_unknown_token_is_stripped_instead_of_leaking_raw_text() -> void:
	var catalog: TooltipIconCatalog = _fresh_catalog()
	var out: String = catalog.format_description("Deal {icon:not_a_status} 4 damage to 1 enemy.")
	assert_bool(out.contains("{icon:")).is_false()
	assert_str(out).contains("Deal 4 damage to 1 enemy")


func test_card_category_token_falls_back_to_a_pure_glyph() -> void:
	var catalog: TooltipIconCatalog = _authored_catalog()
	assert_bool(catalog != null).is_true()
	if catalog == null:
		return

	# "damage" is not authored here; the CardIconCatalog bridge supplies the art
	# and renders ICON_ONLY, so the sentence keeps its own wording.
	var out: String = catalog.format_description("Deal {icon:damage} 4 damage to 1 enemy.")
	assert_bool(out.contains("{icon:")).is_false()
	assert_str(out).contains("[img=")
	assert_str(out).contains("4 damage to 1 enemy")


func test_existing_bbcode_and_image_paths_are_never_rewritten() -> void:
	var catalog: TooltipIconCatalog = _fresh_catalog()
	# A keyword inside an [img] path must not be expanded to a second image.
	var input: String = (
		"[color=#9CA3AF]And if Merged: gain "
		+ "[img=16x16,valign=center]res://art/gloom.png[/img] power.[/color]"
	)
	var out: String = catalog.format_description(input)
	assert_str(out).is_equal(input)


func test_output_is_consumed_by_a_rich_text_label() -> void:
	var catalog: TooltipIconCatalog = _fresh_catalog()
	var formatted: String = catalog.format_description("Inflict 2 Gloom on it.")

	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = formatted
	var parsed: String = label.get_parsed_text()
	label.free()

	# Tags were consumed by the parser (no raw BBCode left in the visible text).
	assert_bool(parsed.contains("[img")).is_false()
	assert_str(parsed).contains("Gloom")


func test_formatter_threads_the_catalog_into_the_tooltip_body() -> void:
	var skill: SkillData = SkillData.new()
	skill.skill_name = "Test Skill"
	skill.description = "Deal 3 damage and inflict 2 Gloom on it."

	var unit_data: UnitData = UnitData.new()
	unit_data.display_name = "Test Unit"
	unit_data.max_hp = 20
	unit_data.skill_1 = skill
	unit_data.skill_2 = skill
	var ally: Unit = Unit.new(unit_data, 0)
	var card: Card = Card.new(3)

	var with_catalog: Dictionary = SkillPreviewFormatter.build_card_on_ally_data(
		ally, card, null, _fresh_catalog()
	)
	var body: String = str(with_catalog.get("body", ""))
	assert_str(body).contains("[img=")
	assert_str(body).contains("Gloom")

	# Callers that pass no catalog keep the previous text-only output.
	var without_catalog: Dictionary = SkillPreviewFormatter.build_card_on_ally_data(ally, card, null)
	assert_bool(str(without_catalog.get("body", "")).contains("[img=")).is_false()
