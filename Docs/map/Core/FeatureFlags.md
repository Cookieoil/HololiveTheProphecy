<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/FeatureFlags.gd` — `class_name FeatureFlags` extends `RefCounted`

`232` lines · [back to the map](../../CODEBASE_MAP.md)

> Registry and deterministic evaluator for staged feature flags. A flag lives in `res://Data/json/features.json` and is switched on for a *share* of runs, not for…

Sections: Constants · Public Methods · Private Methods

Constants:
- L24 `KEY_FLAGS: String = "flags"`
- L25 `KEY_ENABLED: String = "enabled"`
- L26 `KEY_ROLLOUT: String = "rollout_percent"`
- L27 `KEY_DESCRIPTION: String = "description"`
- L29 `BUCKETS: int = 100` — Rollout buckets. `rollout_percent` is the number of buckets that have it on.
- L31 `DEFAULT_ROLLOUT: int = 100` — A flag with no `rollout_percent` is fully rolled out once `enabled` is true.
- L33 `SOURCE_OVERRIDE: String = "override"` — Where a flag's value came from, for the report and any future debug panel.
- L34 `SOURCE_OFF: String = "off"`
- L35 `SOURCE_ROLLOUT: String = "rollout"`
- L36 `SOURCE_UNKNOWN: String = "unknown"`
- L40 `FNV_OFFSET: int = 2166136261` — FNV-1a, 32-bit: the engine's String hash is not promised stable across versions, and an experiment assignment silently moving between releases would invalidate…
- L41 `FNV_PRIME: int = 16777619`
- L42 `UINT32_MASK: int = 4294967295`
- L43 `NAME_PATTERN: String = "^[a-z][a-z0-9_]*$"`
- L47 `ALLOWED_ROOT_KEYS: Array[String] = [KEY_FLAGS]` — Keys the registry reads, and nothing else. An unknown key is a typo: with a permissive parser `"rollout_pct": 5` would silently read as `rollout_percent` unset,…
- L48 `ALLOWED_ENTRY_KEYS: Array[String]`

Public API:
- L55-90 `static normalize(root: Variant) -> Dictionary` — Normalises the parsed features.json root into `{flags, errors}` where `flags` is `{name: {enabled, rollout_percent, description}}`. Problems are collected inste…
- L95-96 `static bucket_for(rollout_key: String, flag_name: String) -> int` — The bucket (0 .. BUCKETS-1) a flag falls in for this run key. Deterministic on every platform and engine version, which is what makes a rollout reproducible.
- L101-122 `static resolve(flag_name: String, definitions: Dictionary, overrides: Dictionary, rollout_key: String) -> Dictionary` — How one flag resolves for this run: `{enabled, source, rollout_percent}`. `source` is one of SOURCE_OVERRIDE / SOURCE_OFF / SOURCE_ROLLOUT / SOURCE_UNKNOWN.
- L128-136 `static evaluate(definitions: Dictionary, overrides: Dictionary, rollout_key: String) -> Dictionary` — The flags this run has on, as `{name: true}` in name order. Only the active ones are listed: the report is asking which runs saw the experiment, not which flags…
- L140-141 `static is_active(flags: Dictionary, flag_name: String) -> bool` — True when a run's evaluated flag set has this flag on.

Private:
- L148-192 `_normalize_entry`
- L195-199 `_is_valid_name`
- L203-208 `_fnv1a`
- L211-222 `_to_int`
- L225-229 `_to_bool`

Uses: —
Used by: Core/DataLoader.gd, Core/GameState.gd, GDTest/FeatureFlagsTest.gd
Loads: —

