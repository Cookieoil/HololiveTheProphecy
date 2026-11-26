class_name TelemetrySchema
extends RefCounted
## Pure serialisers that turn live game objects into the plain Dictionaries the
## telemetry spool stores. Every function is static and side-effect free, so the
## shape of one event can be asserted without a running battle.
##
## The vocabulary is deliberately opinionated: a snapshot always carries stable
## ids (unit_id / skill_id) rather than display names, so renamed or localised
## content never breaks a historical metric.
##
## @author TheGreatJellyfish
## @version 11/26/2026

#region Constants
const SCHEMA_VERSION: int = 1
const PARITY_ODD: String = "odd"
const PARITY_EVEN: String = "even"
## Cap on how many cards/damage rows a single event may carry, so a pathological
## debug hand cannot bloat the spool.
const MAX_ROWS: int = 40
#endregion

#region Public Methods
## A random RFC-4122-shaped id built from engine-grade entropy (no extra deps).
static func new_id() -> String:
	var crypto: Crypto = Crypto.new()
	var bytes: PackedByteArray = crypto.generate_random_bytes(16)
	var hex: String = bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4),
		hex.substr(16, 4), hex.substr(20, 12),
	]


static func now_unix() -> float:
	return Time.get_unix_time_from_system()


## One card as offered/held, keyed on its merge state instead of its slot.
static func card_snapshot(card: Card) -> Dictionary:
	if card == null:
		return {}
	return {
		"card_id": card.id,
		"base_value": card.base_value,
		"effective_value": card.get_effective_value(),
		"parity": parity_of(card),
		"merge_rank": merge_rank(card),
		"is_merged": card.is_merged,
		"is_double_merged": card.is_double_merged,
		"value_buff": card.value_buff,
		"value_debuff": card.value_debuff,
		"costs_action": card.costs_action(),
	}


## 0 = base, 1 = merged (MV), 2 = double merged (DMV).
static func merge_rank(card: Card) -> int:
	if card == null:
		return 0
	if card.is_double_merged:
		return 2
	if card.is_merged:
		return 1
	return 0


static func parity_of(card: Card) -> String:
	if card == null:
		return ""
	return PARITY_ODD if card.is_odd() else PARITY_EVEN


static func cards_snapshot(cards: Array[Card]) -> Array:
	var rows: Array = []
	for card: Card in cards:
		rows.append(card_snapshot(card))
		if rows.size() >= MAX_ROWS:
			break
	return rows


## One unit as it stands right now (HP, shield, Moxie, statuses, Ultimate ready).
static func unit_snapshot(unit: Unit) -> Dictionary:
	if unit == null:
		return {}
	return {
		"unit_id": unit_id_of(unit),
		"slot": unit.slot_index,
		"is_ally": unit.is_ally,
		"hp": unit.current_hp,
		"max_hp": unit.max_hp,
		"shield": unit.shield,
		"moxie": unit.moxie,
		"max_moxie": unit.max_moxie,
		"is_dead": unit.is_dead,
		"value_modifier": unit.value_modifier,
		"statuses": statuses_of(unit),
		"ultimate_ready": unit.can_cast_ultimate,
	}


## Lightweight unit reference for offered/picked candidate lists.
static func unit_ref(unit: Unit) -> Dictionary:
	if unit == null:
		return {}
	return {
		"unit_id": unit_id_of(unit),
		"slot": unit.slot_index,
		"is_ally": unit.is_ally,
		"hp": unit.current_hp,
		"max_hp": unit.max_hp,
		"shield": unit.shield,
		"is_dead": unit.is_dead,
	}


static func unit_refs(units: Array[Unit]) -> Array:
	var rows: Array = []
	for unit: Unit in units:
		rows.append(unit_ref(unit))
		if rows.size() >= MAX_ROWS:
			break
	return rows


static func units_snapshot(units: Array[Unit]) -> Array:
	var rows: Array = []
	for unit: Unit in units:
		rows.append(unit_snapshot(unit))
		if rows.size() >= MAX_ROWS:
			break
	return rows


## The stable unit id behind a runtime unit (never the display name).
static func unit_id_of(unit: Unit) -> String:
	if unit == null or unit.data == null:
		return ""
	return unit.data.unit_id


## The stable skill id behind a skill resource (never the display name).
static func skill_id_of(skill: SkillData) -> String:
	if skill == null:
		return ""
	return skill.skill_id


static func statuses_of(unit: Unit) -> Dictionary:
	var rows: Dictionary = {}
	for key: Variant in unit.statuses:
		var id: String = str(key)
		var entry_raw: Variant = unit.statuses[key]
		if entry_raw is Dictionary:
			var entry: Dictionary = entry_raw
			rows[id] = to_int(entry.get("count", 0), 0)
		else:
			rows[id] = to_int(entry_raw, 0)
	return rows


## One enemy's pre-rolled intent for the current turn.
static func intent_snapshot(intent: EnemyIntent) -> Dictionary:
	if intent == null or intent.enemy == null:
		return {}
	return {
		"unit_id": unit_id_of(intent.enemy),
		"slot": intent.enemy.slot_index,
		"raw_roll": intent.raw_dice_value,
		"effective_value": intent.effective_value,
		"parity": PARITY_ODD if intent.effective_value % 2 == 1 else PARITY_EVEN,
		"skill_id": skill_id_of(intent.skill),
		"condition_met": intent.condition_met,
		"will_ultimate": intent.will_trigger_ultimate(),
		"incoming_damage": maxi(0, intent.effective_value),
	}


static func intents_snapshot(intents: Array[EnemyIntent]) -> Array:
	var rows: Array = []
	for intent: EnemyIntent in intents:
		rows.append(intent_snapshot(intent))
		if rows.size() >= MAX_ROWS:
			break
	return rows


## Full board: every ally and enemy with its current stats.
static func board_snapshot(state: GameState) -> Dictionary:
	return {
		"allies": units_snapshot(state.allies),
		"enemies": units_snapshot(state.enemies),
	}


## The "how is the fight going" numbers that de-bias win-rate correlation: they
## are recorded *before* the decision, so a metric can be stratified by whether
## the player was already winning, even, or desperate.
static func battlefield_metrics(state: GameState, intents: Array[EnemyIntent]) -> Dictionary:
	var ally_hp: int = 0
	var ally_max: int = 0
	var ally_shield: int = 0
	for unit: Unit in state.allies:
		ally_max += unit.max_hp
		ally_hp += maxi(0, unit.current_hp)
		ally_shield += maxi(0, unit.shield)
	var enemy_hp: int = 0
	var enemy_max: int = 0
	for unit: Unit in state.enemies:
		enemy_max += unit.max_hp
		enemy_hp += maxi(0, unit.current_hp)
	var incoming: int = 0
	for intent: EnemyIntent in intents:
		if intent.enemy != null and not intent.enemy.is_dead:
			incoming += maxi(0, intent.effective_value)
	return {
		"ally_hp": ally_hp,
		"ally_max_hp": ally_max,
		"ally_hp_pct": ratio(ally_hp, ally_max),
		"enemy_hp": enemy_hp,
		"enemy_max_hp": enemy_max,
		"enemy_hp_pct": ratio(enemy_hp, enemy_max),
		"total_ally_shield": ally_shield,
		"incoming_intent_damage": incoming,
		"threat_ratio": ratio(incoming, maxi(1, ally_hp + ally_shield)),
		"living_allies": living_count(state.allies),
		"living_enemies": living_count(state.enemies),
	}


static func ratio(numerator: int, denominator: int) -> float:
	if denominator <= 0:
		return 0.0
	return float(numerator) / float(denominator)


static func living_count(units: Array[Unit]) -> int:
	var living: int = 0
	for unit: Unit in units:
		if not unit.is_dead:
			living += 1
	return living
#endregion

#region Private Methods
## Coerces any Variant into an int (dictionaries read back from JSON are floats).
static func to_int(value: Variant, fallback: int = 0) -> int:
	if value is int:
		var int_value: int = value
		return int_value
	if value is float:
		var float_value: float = value
		return int(float_value)
	if value is bool:
		var bool_value: bool = value
		return 1 if bool_value else 0
	if value is String:
		var text: String = value
		if text.is_valid_int():
			return text.to_int()
		if text.is_valid_float():
			return int(text.to_float())
	return fallback
#endregion
