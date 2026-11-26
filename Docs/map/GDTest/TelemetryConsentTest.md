<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/TelemetryConsentTest.gd` — `class_name TelemetryConsentTest` extends `GdUnitTestSuite`

`362` lines · [back to the map](../../CODEBASE_MAP.md)

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
- L43-48 `after() -> void`
- L51-54 `before_test() -> void`
- L86-91 `test_undecided_by_default_and_needs_prompt() -> void`
- L94-103 `test_agree_grants_and_persists_across_a_reload() -> void`
- L106-113 `test_decline_persists_and_never_grants() -> void`
- L116-120 `test_a_new_disclosure_version_re_asks_everyone() -> void`
- L123-130 `test_a_corrupt_file_needs_the_prompt_and_never_grants() -> void`
- L143-158 `test_popup_agree_writes_consent_and_emits_true() -> void`
- L162-180 `test_popup_shows_the_required_wording_and_button_order() -> void` — Locks the disclosure wording and the button order the mock-up asks for.
- L187-217 `test_popup_fills_and_centres_on_a_canvas_layer() -> void` — BattleScene mounts the popup on a CanvasLayer. A top-level Control gets no parent rect from a CanvasLayer, so a FULL_RECT preset used to collapse to zero and le…
- L223-233 `test_the_prompt_comes_back_on_a_new_launch() -> void` — The disclosure is asked once per *launch*, not once ever: a stored "Allow" from a previous session must not silence it, while the reload behind "Play Again" (sa…
- L238-251 `test_a_battle_started_after_the_answer_uses_it() -> void` — A battle starts after the disclosure is answered, so the recorder must use the answer given this launch, not the one it loaded when it was constructed.
- L256-272 `test_a_stale_granted_file_cannot_start_collection() -> void` — A stored "granted" left over from an earlier launch must not authorise collection on its own: the player has to be asked in the session that is running.
- L277-292 `test_dim_is_translucent_and_the_header_is_lifted() -> void` — The stage must stay translucent enough to see the battle, and the header plate must be lifted so its border sits centred on the window's top edge.
- L295-305 `test_popup_decline_writes_consent_and_emits_false() -> void`
- L310-327 `test_declined_consent_records_nothing() -> void`
- L330-345 `test_granted_consent_opens_a_run_and_writes_events() -> void`
- L351-360 `test_a_default_recorder_never_collects_headless() -> void` — Regression lock: a recorder with no test sink must never collect in a headless run, even when the player has agreed - that is what keeps the CI gates, the valid…

Private:
- L58-65 `_remove_tree`
- L68-72 `_write_consent_file`
- L75-82 `_make_state`
- L135-140 `_make_popup`

Uses: EnemyIntent, GameState, TelemetryConsent, TelemetryConsentPopup, TelemetryManager, TelemetrySchema, TelemetrySink, UnitData
Used by: —
Loads: —

