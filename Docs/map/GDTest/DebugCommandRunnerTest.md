<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/DebugCommandRunnerTest.gd` — `class_name DebugCommandRunnerTest` extends `GdUnitTestSuite`

`152` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the seams of Managers/DebugCommandRunner.gd that the turn-loop suite cannot reach. GDTest/DebugMenuTest.gd drives every tool through GameManager, so what…
- L18 `class SilentUI extends GameUI` (members are not indexed)

Public API:
- L52-61 `test_a_malformed_payload_can_never_sweep_the_whole_board() -> void` — The doc comment on `_targets` promises this: a malformed command must never sweep the whole board. An unparsable `args` therefore resolves to the ally row only.
- L66-76 `test_a_slot_beyond_the_row_selects_nothing() -> void` — slot >= 0 means one specific slot of its own row, so a slot past the end of the row is simply nothing - it must not fall through to "the whole row".
- L79-91 `test_scope_all_selects_both_rows() -> void`
- L96-106 `test_arguments_arrive_as_floats_bools_and_strings() -> void` — A UI control hands its value over as a float, a bool or a string, depending on the widget, so the runner has to coerce all three.
- L109-114 `test_the_hand_cap_stepper_clamps_at_the_limit() -> void`
- L119-134 `test_reroll_and_respawn_are_requests_not_calls() -> void` — The runner cannot re-roll the intents or re-spawn a wave itself without desyncing the loop, so it raises a request and GameManager connects the handler.
- L137-142 `test_a_result_preview_is_remembered_for_the_turn_loop() -> void`
- L145-151 `test_an_unknown_command_is_reported_instead_of_crashing() -> void`

Private:
- L25-31 `_unit`
- L34-40 `_state`
- L43-47 `_ui`

Uses: DebugCommandRunner, GameState, GameUI, Unit, UnitData
Used by: —
Loads: —

