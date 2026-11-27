<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `GDTest/TriageParserTest.gd` — `class_name TriageParserTest` extends `GdUnitTestSuite`

`198` lines · [back to the map](../../CODEBASE_MAP.md)

> Locks the task-intake rules (Tools/TriageParser.gd): every threshold, the ordering, the per-kind cap and the issue marker that makes filing idempotent.

Public API:
- L48-55 `test_every_signal_produces_its_task() -> void`
- L58-67 `test_the_evidence_carries_the_numbers_and_the_seeds() -> void`
- L70-74 `test_a_rarely_offered_skill_is_below_the_sample_floor() -> void`
- L77-81 `test_a_well_picked_skill_is_not_reported() -> void`
- L84-94 `test_a_nearly_unused_ally_is_reported_and_sorts_first() -> void`
- L97-101 `test_a_lift_inside_the_band_is_not_reported() -> void`
- L104-113 `test_an_abandon_spike_is_one_task() -> void`
- L116-120 `test_a_flag_with_too_few_runs_is_left_alone() -> void`
- L123-130 `test_a_marker_becomes_a_task() -> void`
- L133-140 `test_a_ratchet_warning_becomes_a_task() -> void`
- L143-153 `test_the_issue_marker_is_stable_and_embedded_in_the_body() -> void`
- L156-161 `test_the_per_kind_cap_holds() -> void`
- L164-179 `test_the_list_is_ordered_by_severity_then_name() -> void`
- L182-183 `test_an_empty_report_produces_nothing() -> void`
- L187-197 `test_only_a_real_marker_counts() -> void` — A leftover marker opens its comment; prose that merely mentions one is not a task.

Private:
- L9-13 `_kinds`
- L16-20 `_first_of`
- L24-45 `_report`

Uses: Card, CodeIndexParser, GameManager, TriageParser
Used by: —
Loads: —

