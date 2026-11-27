class_name FeatureFlags
extends RefCounted
## Registry and deterministic evaluator for staged feature flags.
##
## A flag lives in `res://Data/json/features.json` and is switched on for a *share*
## of runs, not for everyone at once, so an experiment can be measured on real
## players before it ships. The bucket is derived from the run seed, which makes an
## assignment reproducible (the same seed always lands in the same bucket, so a
## flagged run can be replayed) and needs no player identifier, so the privacy
## posture of the telemetry gate is untouched.
##
## Pure on purpose: text in, plain Dictionaries out, no file system, no nodes. That
## keeps bucketing, precedence and the unknown-flag rule unit-testable in
## GDTest/FeatureFlagsTest.gd.
##
## Precedence, highest first: an explicit override (a tester tool or a test) wins;
## then the `enabled` kill switch; then the rollout percentage. An unknown flag is
## always off, so a typo can never switch something on.
##
## @author TheGreatJellyfish
## @version 11/27/2026

#region Constants
const KEY_FLAGS: String = "flags"
const KEY_ENABLED: String = "enabled"
const KEY_ROLLOUT: String = "rollout_percent"
const KEY_DESCRIPTION: String = "description"
## Rollout buckets. `rollout_percent` is the number of buckets that have it on.
const BUCKETS: int = 100
## A flag with no `rollout_percent` is fully rolled out once `enabled` is true.
const DEFAULT_ROLLOUT: int = 100
## Where a flag's value came from, for the report and any future debug panel.
const SOURCE_OVERRIDE: String = "override"
const SOURCE_OFF: String = "off"
const SOURCE_ROLLOUT: String = "rollout"
const SOURCE_UNKNOWN: String = "unknown"
## FNV-1a, 32-bit: the engine's String hash is not promised stable across versions,
## and an experiment assignment silently moving between releases would invalidate
## the comparison it exists to make.
const FNV_OFFSET: int = 2166136261
const FNV_PRIME: int = 16777619
const UINT32_MASK: int = 4294967295
const NAME_PATTERN: String = "^[a-z][a-z0-9_]*$"
#endregion

#region Public Methods
## Normalises the parsed features.json root into
## `{flags, errors}` where `flags` is `{name: {enabled, rollout_percent, description}}`.
## Problems are collected instead of aborting, so tooling can report them all at once.
static func normalize(root: Variant) -> Dictionary:
	var flags: Dictionary = {}
	var errors: PackedStringArray = PackedStringArray()
	if not (root is Dictionary):
		errors.append("features.json: the root must be an object")
		return {"flags": flags, "errors": errors}
	var root_object: Dictionary = root
	if not root_object.has(KEY_FLAGS):
		errors.append("features.json: missing the 'flags' object")
		return {"flags": flags, "errors": errors}
	var raw_flags: Variant = root_object.get(KEY_FLAGS, {})
	if not (raw_flags is Dictionary):
		errors.append("features.json: 'flags' must be an object")
		return {"flags": flags, "errors": errors}
	var entries: Dictionary = raw_flags
	var names: Array = entries.keys()
	names.sort()
	for key: Variant in names:
		var flag_name: String = str(key)
		if not _is_valid_name(flag_name):
			errors.append("features.json: '%s' is not a snake_case flag name" % flag_name)
			continue
		var raw_entry: Variant = entries[key]
		if not (raw_entry is Dictionary):
			errors.append("features.json: '%s' must be an object" % flag_name)
			continue
		var entry: Dictionary = raw_entry
		flags[flag_name] = _normalize_entry(flag_name, entry, errors)
	return {"flags": flags, "errors": errors}


## The bucket (0 .. BUCKETS-1) a flag falls in for this run key. Deterministic on
## every platform and engine version, which is what makes a rollout reproducible.
static func bucket_for(rollout_key: String, flag_name: String) -> int:
	return _fnv1a("%s:%s" % [flag_name, rollout_key]) % BUCKETS


## How one flag resolves for this run: `{enabled, source, rollout_percent}`.
## `source` is one of SOURCE_OVERRIDE / SOURCE_OFF / SOURCE_ROLLOUT / SOURCE_UNKNOWN.
static func resolve(
	flag_name: String,
	definitions: Dictionary,
	overrides: Dictionary,
	rollout_key: String
) -> Dictionary:
	if not definitions.has(flag_name):
		return {"enabled": false, "source": SOURCE_UNKNOWN, "rollout_percent": 0}
	var entry: Dictionary = definitions[flag_name]
	var percent: int = _to_int(entry.get(KEY_ROLLOUT, DEFAULT_ROLLOUT), DEFAULT_ROLLOUT)
	if overrides.has(flag_name):
		var forced: bool = _to_bool(overrides.get(flag_name), false)
		return {"enabled": forced, "source": SOURCE_OVERRIDE, "rollout_percent": percent}
	if not _to_bool(entry.get(KEY_ENABLED, false), false) or percent <= 0:
		return {"enabled": false, "source": SOURCE_OFF, "rollout_percent": percent}
	if percent >= BUCKETS:
		return {"enabled": true, "source": SOURCE_ROLLOUT, "rollout_percent": percent}
	return {
		"enabled": bucket_for(rollout_key, flag_name) < percent,
		"source": SOURCE_ROLLOUT,
		"rollout_percent": percent,
	}


## The flags this run has on, as `{name: true}` in name order. Only the active ones
## are listed: the report is asking which runs saw the experiment, not which flags
## exist.
static func evaluate(definitions: Dictionary, overrides: Dictionary, rollout_key: String) -> Dictionary:
	var active: Dictionary = {}
	var names: Array = definitions.keys()
	names.sort()
	for key: Variant in names:
		var flag_name: String = str(key)
		if _to_bool(resolve(flag_name, definitions, overrides, rollout_key).get("enabled"), false):
			active[flag_name] = true
	return active


## True when a run's evaluated flag set has this flag on.
static func is_active(flags: Dictionary, flag_name: String) -> bool:
	return flags.has(flag_name)
#endregion

#region Private Methods
## Reads one flag entry, collecting a message per problem it finds. A missing
## description is an error on purpose: an undocumented experiment is a decision
## nobody can revisit.
static func _normalize_entry(flag_name: String, entry: Dictionary, errors: PackedStringArray) -> Dictionary:
	var enabled: bool = false
	if entry.has(KEY_ENABLED):
		var raw_enabled: Variant = entry.get(KEY_ENABLED)
		if raw_enabled is bool:
			enabled = raw_enabled
		else:
			errors.append("features.json: '%s.enabled' must be true or false" % flag_name)

	var percent: int = DEFAULT_ROLLOUT
	if entry.has(KEY_ROLLOUT):
		percent = _to_int(entry.get(KEY_ROLLOUT), DEFAULT_ROLLOUT)
		if percent < 0 or percent > BUCKETS:
			errors.append("features.json: '%s.rollout_percent' must be 0..%d (found %d)" % [
				flag_name,
				BUCKETS,
				percent,
			])
			percent = clampi(percent, 0, BUCKETS)

	var description: String = ""
	var raw_description: Variant = entry.get(KEY_DESCRIPTION, "")
	if raw_description is String:
		var text: String = raw_description
		description = text.strip_edges()
	if description.is_empty():
		errors.append("features.json: '%s' needs a 'description' saying what is being tried" % flag_name)

	return {KEY_ENABLED: enabled, KEY_ROLLOUT: percent, KEY_DESCRIPTION: description}


static func _is_valid_name(flag_name: String) -> bool:
	var regex: RegEx = RegEx.new()
	if regex.compile(NAME_PATTERN) != OK:
		return false
	return regex.search(flag_name) != null


## FNV-1a over the UTF-8 bytes, masked back to 32 bits.
static func _fnv1a(text: String) -> int:
	var hash_value: int = FNV_OFFSET
	for byte: int in text.to_utf8_buffer():
		hash_value = (hash_value ^ byte) & UINT32_MASK
		hash_value = (hash_value * FNV_PRIME) & UINT32_MASK
	return hash_value


static func _to_int(value: Variant, fallback: int) -> int:
	if value is int:
		var int_value: int = value
		return int_value
	if value is float:
		var float_value: float = value
		return int(float_value)
	if value is String:
		var text: String = value
		if text.is_valid_int():
			return text.to_int()
	return fallback


static func _to_bool(value: Variant, fallback: bool) -> bool:
	if value is bool:
		var bool_value: bool = value
		return bool_value
	return fallback
#endregion

