# res://Skills/SkillPreviewFormatter.gd
class_name SkillPreviewFormatter
extends RefCounted

const COL_NUM := "#FFD966"
const COL_MOXIE := "#C77DFF"
const COL_ULT := "#FF6B6B"
const COL_OK := "#6EE7B7"
const COL_MUTED := "#9CA3AF"
## Slightly smaller inline icons for the dimmed "Merged" reminder line (font_size=12).
const MUTED_ICON_SIZE: int = 14

## Returns structured data for the Sketch-2 callout when dragging a Card onto an Ally.
static func build_card_on_ally_data(
	ally: Unit, card: Card, state: GameState, tooltip_catalog: TooltipIconCatalog = null
) -> Dictionary:
	if ally == null or card == null or ally.data == null:
		return {}

	var is_odd := card.is_odd()
	var is_merged := card.is_merged or card.is_double_merged
	var skill: SkillData = ally.data.skill_1 if is_odd else ally.data.skill_2
	if skill == null:
		return {}

	var slot_idx := 1 if is_odd else 2
	var parity_txt := "Odd" if is_odd else "Even"
	var merge_txt := "Unmerged"
	if card.is_double_merged:
		merge_txt = "Double Merged (0 Act)"
	elif card.is_merged:
		merge_txt = "Merged"

	var header := "Skill %d (%s)" % [slot_idx, parity_txt]
	var card_val := card.get_effective_value()
	var bonus := state.next_skill_bonus if state != null else 0
	var skill_val := card_val + bonus

	var subtitle: String
	if bonus != 0:
		subtitle = "%s  •  %d (%d%+d) Value" % [merge_txt, skill_val, card_val, bonus]
	else:
		subtitle = "%s  •  %d Value" % [merge_txt, skill_val]

	var body_lines := _resolve_description_lines(
		skill, ally, skill_val, is_merged, state, tooltip_catalog, card
	)

	# Helpful memory aid: when dragging an unmerged card, dimly remind what Merged does
	if not is_merged and skill.merged_description.strip_edges() != "":
		var no_blocks: Array[SkillEffect] = []
		var merged_preview := _substitute_tokens(
			skill.merged_description, skill_val, state, no_blocks, ally,
			tooltip_catalog, MUTED_ICON_SIZE
		)
		body_lines.append("\n[color=%s][font_size=12]%s[/font_size][/color]" % [COL_MUTED, merged_preview])

	var next_moxie := mini(ally.max_moxie, ally.moxie + card_val)
	var ready_tag := "  [b][color=%s]ULT READY![/color][/b]" % COL_OK if next_moxie >= ally.max_moxie else ""
	var footer := "[color=%s]Moxie: %d → %d/%d (+%d)[/color]%s" % [
		COL_MOXIE, ally.moxie, next_moxie, ally.max_moxie, card_val, ready_tag
	]

	# Accent reflects the hovered unit's side only (ally = blue, enemy = red),
	# never the card's merge/parity state.
	var accent := Color(0.49, 0.83, 0.99) if ally.is_ally else Color(0.95, 0.55, 0.45)

	return {
		"header": header,
		"subtitle": subtitle,
		"categories": skill.get_active_categories(is_merged),
		"body": "%s" % ["\n".join(body_lines)],
		"footer": footer,
		"accent": accent,
	}


## Returns structured data when hovering an Enemy's Dice IntentLabel.
static func build_enemy_intent_data(
	intent: EnemyIntent, state: GameState, tooltip_catalog: TooltipIconCatalog = null
) -> Dictionary:
	if intent == null or intent.enemy == null or intent.skill == null:
		return {}

	var enemy := intent.enemy
	var skill := intent.skill
	var val := intent.effective_value
	var is_odd := (val % 2 == 1)
	var slot_idx := 1 if is_odd else 2
	var parity_txt := "Odd" if is_odd else "Even"

	var header := "Skill %d (%s)" % [slot_idx, parity_txt]

	var cond_txt := ""
	if skill.condition_threshold > 0:
		cond_txt = "≥%d Active" % skill.condition_threshold if intent.condition_met \
			else "<%d Base" % skill.condition_threshold

	var mod_txt := ""
	if enemy.value_modifier != 0:
		mod_txt = " (Roll %d %+d)" % [intent.raw_dice_value, enemy.value_modifier]

	var value_txt := "%d Value%s" % [val, mod_txt]
	var subtitle := "%s  •  %s" % [cond_txt, value_txt] if cond_txt != "" else value_txt

	var body_lines := _resolve_description_lines(
		skill, enemy, val, intent.condition_met, state, tooltip_catalog
	)

	if intent.will_trigger_ultimate() and enemy.data.ultimate != null:
		var ult := enemy.data.ultimate
		var ult_lines := _resolve_description_lines(ult, enemy, 0, false, state, tooltip_catalog)
		body_lines.append("\n[b][color=%s]CHAINS ULTIMATE — %s:[/color][/b]" % [COL_ULT, ult.skill_name])
		body_lines.append_array(ult_lines)

	var next_moxie := mini(enemy.max_moxie, enemy.moxie + val)
	var ult_warn := "  [b][color=%s]CASTS ULT![/color][/b]" % COL_ULT if intent.will_trigger_ultimate() else ""
	var footer := "[color=%s]Moxie after roll: %d → %d/%d (+%d)[/color]%s" % [
		COL_MOXIE, enemy.moxie, next_moxie, enemy.max_moxie, val, ult_warn
	]

	return {
		"header": header,
		"subtitle": subtitle,
		"categories": skill.get_active_categories(intent.condition_met),
		"body": "%s" % "\n".join(body_lines),
		"footer": footer,
		"accent": Color(1.0, 0.36, 0.36) if intent.will_trigger_ultimate() else Color(0.95, 0.55, 0.45),
	}


## Returns structured data when hovering an Ally or Enemy Moxie/Ultimate Orb (A1-A3 / E1-E3).
static func build_orb_ultimate_data(
	unit: Unit,
	badge_code: String,
	state: GameState,
	intent: EnemyIntent = null,
	tooltip_catalog: TooltipIconCatalog = null
) -> Dictionary:
	if unit == null or unit.data == null:
		return {}

	var ult: SkillData = unit.data.ultimate
	var header := "%s • %s Ultimate" % [badge_code, unit.data.display_name]
	if ult == null:
		return {
			"header": header,
			"subtitle": "Moxie %d / %d" % [unit.moxie, unit.max_moxie],
			"categories": PackedStringArray(),
			"body": "[color=%s]No Ultimate configured in res://Data/json/skills.json.[/color]" % COL_MUTED,
			"footer": "",
			"accent": Color(0.6, 0.65, 0.75),
		}

	var subtitle := "%s  •  %d Moxie" % [ult.skill_name, unit.max_moxie]
	var body_lines := _resolve_description_lines(ult, unit, 0, false, state, tooltip_catalog)

	var footer: String
	var accent: Color
	if unit.is_ally:
		if unit.ult_used_this_turn:
			footer = "[color=%s]Already unleashed this turn (%d/%d Moxie)[/color]" % [COL_MUTED, unit.moxie, unit.max_moxie]
			accent = Color(0.55, 0.60, 0.70)
		elif unit.can_cast_ultimate:
			footer = "[b][color=%s]READY — Click orb to unleash (0 Action)![/color][/b]" % COL_OK
			accent = Color(1.0, 0.84, 0.32)
		else:
			var need := maxi(0, unit.max_moxie - unit.moxie)
			footer = "[color=%s]Moxie: %d / %d (Play +%d Card Value to charge)[/color]" % [COL_MOXIE, unit.moxie, unit.max_moxie, need]
			accent = Color(0.72, 0.52, 0.98)
	else:
		if intent != null and intent.will_trigger_ultimate():
			footer = "[b][color=%s]DANGER: Roll %d fills %d/%d → Casts this turn![/color][/b]" % [
				COL_ULT, intent.effective_value, unit.max_moxie, unit.max_moxie
			]
			accent = Color(1.0, 0.32, 0.36)
		else:
			footer = "[color=%s]Enemy Moxie: %d / %d (Casts immediately at %d)[/color]" % [
				COL_MOXIE, unit.moxie, unit.max_moxie, unit.max_moxie
			]
			accent = Color(0.90, 0.38, 0.44)

	return {
		"header": header,
		"subtitle": subtitle,
		"categories": ult.get_active_categories(false),
		"body": "%s" % "\n".join(body_lines),
		"footer": footer,
		"accent": accent,
	}


# --- Internal Resolution Helpers ---------------------------------------------

static func _resolve_description_lines(
	skill: SkillData,
	caster: Unit,
	initial_val: int,
	is_merged: bool,
	state: GameState,
	tooltip_catalog: TooltipIconCatalog = null,
	exclude_card: Card = null
) -> PackedStringArray:
	var out: PackedStringArray = []
	var base_val := initial_val
	var merged_val := initial_val

	# Account for MergedMode value boosts (e.g. merged block modifies base block's skill value)
	if is_merged and skill.merged_mode == SkillData.MergedMode.AND_MERGED_FIRST:
		base_val = _estimate_post_blocks_value(skill.merged_effects, initial_val, state)

	var base_txt := _substitute_tokens(
		skill.description.strip_edges(), base_val, state, skill.base_effects, caster, tooltip_catalog, 0, exclude_card
	)
	var merged_txt := _substitute_tokens(
		skill.merged_description.strip_edges(), merged_val, state, skill.merged_effects, caster,
		tooltip_catalog, 0, exclude_card
	)

	if not is_merged:
		if base_txt != "":
			out.append(base_txt)
	else:
		# Merged tooltips always read top-to-bottom: the main effect first, then the
		# merged add-on / replacement in gold. The "Merged:" / "Merged (Instead):"
		# prefix carries the semantics, so the eye never has to reorder the lines.
		match skill.merged_mode:
			SkillData.MergedMode.OR:
				out.append(merged_txt if merged_txt != "" else base_txt)
			SkillData.MergedMode.AND_MERGED_FIRST, SkillData.MergedMode.AND_BASE_FIRST:
				if base_txt != "":
					out.append(base_txt)
				if merged_txt != "":
					var sep := "\n" if not out.is_empty() else ""
					out.append(sep + "[color=#FDE68A]%s[/color]" % merged_txt)

	if out.is_empty():
		out.append("No description.")
	return out


static func _estimate_post_blocks_value(blocks: Array[SkillEffect], start_val: int, state: GameState) -> int:
	var v := start_val
	for se in blocks:
		var eb := se as EffectBlock
		if eb != null and str(eb.get("action")) != "" and eb.has_method("compute_value_from_inputs"):
			# If a block adds a fixed offset to skill value (like normal_enemy_1 / buff_1)
			if eb.target_mode == 0 and eb.fixed_amount != 0 and eb.value_source == EffectBlock.ValueSource.FIXED:
				# Only apply if this block is a skill-value modifier (safe check via method/property)
				if eb.get("store_as") == "":
					pass
	return v


static func _substitute_tokens(
	text: String,
	val: int,
	state: GameState,
	blocks: Array[SkillEffect] = [],
	caster: Unit = null,
	tooltip_catalog: TooltipIconCatalog = null,
	icon_size: int = 0,
	exclude_card: Card = null
) -> String:
	if text == "":
		return ""

	var result := text

	# 1. If the skill has a primary EffectBlock, compute its exact value for single-number prose
	var primary_computed := val
	if not blocks.is_empty():
		var first_eb := blocks[0] as EffectBlock
		if first_eb != null and first_eb.has_method("compute_value_from_inputs"):
			var sample_target := _pick_sample_target(caster, state)
			primary_computed = first_eb.compute_value_from_inputs(val, 0, state, sample_target, caster)

	# 1b. Handle compound bracketed expressions before the generic single-operator pattern.
	#     These use words ("Shield", "Highest Card in Hand") or chained operators.
	#     Only the resolved total is printed; the rule is shown as a plain hint so the
	#     tooltip never reads like an algebra quiz.
	if caster != null:
		var shield_rx := RegEx.new()
		shield_rx.compile("\\[Value\\s*\\+\\s*(?:Caster's\\s+)?Shield\\]")
		var shield_match := shield_rx.search(result)
		if shield_match != null:
			var shield_val: int = caster.shield
			var total: int = val + shield_val
			var shield_hint: String = "(+%d from Shield)" % shield_val if shield_val > 0 else "(+1 per Shield)"
			result = result.replace(shield_match.get_string(0), "%s [color=%s]%s[/color]" % [_num_bb(total), COL_MUTED, shield_hint])

	var hand_rx := RegEx.new()
	hand_rx.compile("\\[Value\\s*\\+\\s*Highest\\s+Card(?:\\s+in\\s+Hand)?\\s*/\\s*(\\d+)\\]")
	var hand_match := hand_rx.search(result)
	if hand_match != null:
		var divisor: int = int(hand_match.get_string(1))
		var hand_val: int = 0
		if state != null:
			var hi_card: Card = state.get_highest_card_in_hand(exclude_card)
			if hi_card != null:
				hand_val = hi_card.get_effective_value()
		var bonus: int = maxi(1, hand_val / maxi(1, divisor)) if hand_val > 0 else 0
		var total: int = val + bonus
		var hand_hint: String = "(+%d from highest card)" % bonus if bonus > 0 \
			else "(+1 per %d highest card Value)" % divisor
		result = result.replace(hand_match.get_string(0), "%s [color=%s]%s[/color]" % [_num_bb(total), COL_MUTED, hand_hint])

	var div_add_rx := RegEx.new()
	div_add_rx.compile("\\[Value\\s*/\\s*(\\d+)\\s*\\+\\s*(\\d+)\\]")
	var div_add_match := div_add_rx.search(result)
	if div_add_match != null:
		var divisor: int = int(div_add_match.get_string(1))
		var add: int = int(div_add_match.get_string(2))
		var divided: int = maxi(1, val / maxi(1, divisor)) if val > 0 else 0
		var total: int = divided + add
		result = result.replace(div_add_match.get_string(0), _num_bb(total))

	var times_rx := RegEx.new()
	times_rx.compile("\\[Value\\s*(?:x|\\*)\\s*(\\d+)\\]")
	var times_match := times_rx.search(result)
	if times_match != null:
		var mult: int = int(times_match.get_string(1))
		result = result.replace(times_match.get_string(0), _num_bb(val * mult))

	# 2. Generic single-operator bracket expressions: [Value], [Value + N], [Value - N], [Value * N], [Value / N]
	#    Note: the 'x' variant and compound expressions are handled above, so this only catches '*'.
	var bracket_rx := RegEx.new()
	bracket_rx.compile("\\[\\s*[Vv]alue\\s*(?:([+\\-*/])\\s*(\\d+))?\\s*\\]")
	for m in bracket_rx.search_all(result):
		var op := m.get_string(1)
		var rhs := int(m.get_string(2)) if m.get_string(2) != "" else 0
		var n := val
		match op:
			"+": n = val + rhs
			"-": n = maxi(0, val - rhs)
			"*": n = val * rhs
			"/":
				@warning_ignore("integer_division")
				n = maxi(1, val / maxi(1, rhs))
		result = result.replace(m.get_string(0), _num_bb(n))

	# 3. Replace Highest / Lowest card tokens (for Ultimates like Striker's "8 + Highest Card")
	if state != null:
		var hi_card := state.get_highest_card_in_hand(exclude_card)
		var hi_val := hi_card.get_effective_value() if hi_card != null else 0
		var hi_math_rx := RegEx.new()
		hi_math_rx.compile("(\\d+)\\s*\\+\\s*Highest Card(?:\\s+in\\s+Hand)?")
		var hm := hi_math_rx.search(result)
		if hm != null:
			var total := int(hm.get_string(1)) + hi_val
			var hi_hint: String = "(+%d from highest card)" % hi_val if hi_val > 0 else "(+highest card in hand)"
			result = result.replace(hm.get_string(0), "%s [color=%s]%s[/color]" % [
				_num_bb(total), COL_MUTED, hi_hint
			])

	# 4. Replace common prose placeholders ({value}, card value, rolled value, standalone V)
	var phrase_rx := RegEx.new()
	phrase_rx.compile("(?i)(\\{value\\}|card's value|card value|dice value|rolled value)")
	for pm in phrase_rx.search_all(result):
		result = result.replace(pm.get_string(0), _num_bb(primary_computed if blocks.size() == 1 else val))

	# 5. Swap keywords/tokens for their inline icons (icon left of the keyword,
	#    or a pure glyph, depending on the TooltipIconCatalog entry).
	if tooltip_catalog != null:
		result = tooltip_catalog.format_description(result, icon_size)
	return result


static func _pick_sample_target(caster: Unit, state: GameState) -> Unit:
	if caster == null or state == null:
		return null
	var pool: Array[Unit] = state.get_living_enemies() if caster.is_ally else state.get_living_allies()
	return pool[0] if not pool.is_empty() else null


static func _num_bb(n: int) -> String:
	return "[color=%s]%d[/color]" % [COL_NUM, n]
