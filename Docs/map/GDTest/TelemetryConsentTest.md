<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/TelemetryConsentTest.gd` — `class_name TelemetryConsentTest` extends `GdUnitTestSuite`

`284` lines · [back to the map](../../CODEBASE_MAP.md)

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
- L83-88 `test_undecided_by_default_and_needs_prompt() -> void`
- L91-100 `test_agree_grants_and_persists_across_a_reload() -> void`
- L103-110 `test_decline_persists_and_never_grants() -> void`
- L113-117 `test_a_new_disclosure_version_re_asks_everyone() -> void`
- L120-127 `test_a_corrupt_file_needs_the_prompt_and_never_grants() -> void`
- L140-155 `test_popup_agree_writes_consent_and_emits_true() -> void`
- L159-177 `test_popup_shows_the_required_wording_and_button_order() -> void` — Locks the disclosure wording and the button order the mock-up asks for.
- L184-214 `test_popup_fills_and_centres_on_a_canvas_layer() -> void` — BattleScene mounts the popup on a CanvasLayer. A top-level Control gets no parent rect from a CanvasLayer, so a FULL_RECT preset used to collapse to zero and le…
- L217-227 `test_popup_decline_writes_consent_and_emits_false() -> void`
- L232-249 `test_declined_consent_records_nothing() -> void`
- L252-267 `test_granted_consent_opens_a_run_and_writes_events() -> void`
- L273-282 `test_a_default_recorder_never_collects_headless() -> void` — Regression lock: a recorder with no test sink must never collect in a headless run, even when the player has agreed - that is what keeps the CI gates, the valid…

Private:
- L55-62 `_remove_tree`
- L65-69 `_write_consent_file`
- L72-79 `_make_state`
- L132-137 `_make_popup`

Uses: EnemyIntent, GameState, TelemetryConsent, TelemetryConsentPopup, TelemetryManager, TelemetrySchema, TelemetrySink, UnitData
Used by: —
Loads: —

