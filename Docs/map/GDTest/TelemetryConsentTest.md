<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/TelemetryConsentTest.gd` — `class_name TelemetryConsentTest` extends `GdUnitTestSuite`

`219` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the telemetry opt-in gate: - an unanswered consent is UNDECIDED and needs the prompt - "Agree" grants and persists; "Decline" persists and never grants -…

Sections: Consent record · Consent popup · No collection without consent
- L17 `class MemorySink extends TelemetrySink` (members are not indexed)

Constants:
- L13 `TEMP_ROOT: String = "user://telemetry_test"`

State:
- L34 `_temp_dir: String = ""`
- L35 `_consent_path: String = ""`
- L36 `_player_path: String = ""`

Public API:
- L39-40 `before() -> void`
- L43-45 `after() -> void`
- L48-51 `before_test() -> void`
- L54-56 `after_test() -> void`
- L88-93 `test_undecided_by_default_and_needs_prompt() -> void`
- L96-105 `test_agree_grants_and_persists_across_a_reload() -> void`
- L108-115 `test_decline_persists_and_never_grants() -> void`
- L118-122 `test_a_new_disclosure_version_re_asks_everyone() -> void`
- L125-132 `test_a_corrupt_file_needs_the_prompt_and_never_grants() -> void`
- L145-160 `test_popup_agree_writes_consent_and_emits_true() -> void`
- L163-173 `test_popup_decline_writes_consent_and_emits_false() -> void`
- L178-197 `test_declined_consent_records_nothing() -> void`
- L200-217 `test_granted_consent_opens_a_run_and_writes_events() -> void`

Private:
- L60-67 `_remove_tree`
- L70-74 `_write_consent_file`
- L77-84 `_make_state`
- L137-142 `_make_popup`

Uses: EnemyIntent, GameState, TelemetryConsent, TelemetryConsentPopup, TelemetryManager, TelemetrySchema, TelemetrySink, UnitData
Used by: —
Loads: —

