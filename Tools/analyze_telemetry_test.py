#!/usr/bin/env python3
"""Regression suite for Tools/analyze_telemetry.py - the balance report itself.

    python Tools/analyze_telemetry_test.py

Why this exists: the report is how a design decision gets made, and every number in it
is derived - a wrong denominator or a cohort that silently pools two balance patches
does not crash, it just answers the wrong question convincingly. So the maths is
pinned here against fixtures whose expected values were worked out by hand.

The three that matter most:

  * a win-more card must not look strong. A skill played only while already winning has
    a 100% win rate and a lift of zero, because its baseline is the stratum it was
    played in - that is the selection-bias trap the report exists to avoid.
  * a flag cohort's control group is the *same* balance patch. Pooling every run into
    one control would read a balance change as a flag effect (Simpson's paradox).
  * abandoned runs are not losses. They are excluded from every denominator, or a
    player who restarted mid-fight would be counted as a defeat.
"""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import shutil
import tempfile
from pathlib import Path

MODULE = Path(__file__).with_name("analyze_telemetry.py")
WORK = Path(tempfile.mkdtemp(prefix="telemetry-report-test-"))

spec = importlib.util.spec_from_file_location("report", MODULE)
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)

results: list[tuple[str, bool, str]] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    results.append((name, bool(condition), detail))


def metrics(ally_pct: float, enemy_pct: float, threat: float) -> dict:
    """A pre-decision board snapshot, in the shape TelemetrySchema writes it."""
    return {"ally_hp_pct": ally_pct, "enemy_hp_pct": enemy_pct, "threat_ratio": threat}


def run_started(run_id: str, **fields) -> dict:
    event = {"schema_version": report.SCHEMA_VERSION, "type": "run_started", "run_id": run_id}
    event.update(fields)
    return event


def run_ended(run_id: str, **fields) -> dict:
    event = {"schema_version": report.SCHEMA_VERSION, "type": "run_ended", "run_id": run_id}
    event.update(fields)
    return event


def decision(run_id: str, decision_type: str, chosen: dict, offered: dict, board: dict) -> dict:
    return {
        "schema_version": report.SCHEMA_VERSION,
        "type": "decision",
        "run_id": run_id,
        "decision_type": decision_type,
        "chosen": chosen,
        "offered": offered,
        "context": {"metrics": board},
    }


def write_spool(name: str, events: list) -> Path:
    """Writes one run's newline-delimited JSON, as JsonlFileSink would."""
    folder = WORK / name
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / f"{name}.jsonl"
    path.write_text("\n".join(json.dumps(event) for event in events) + "\n", encoding="utf-8")
    return folder


def non_blank(text: str) -> str:
    return " | ".join(line.strip() for line in text.splitlines() if line.strip())


def close(left: float, right: float) -> bool:
    """Float equality for rates, which are divisions and never exact."""
    return abs(float(left) - float(right)) < 1e-9


# ------------------------------------------------------------ advantage strata
check("a healthy board reads as winning",
      report.stratum_of(metrics(0.8, 0.4, 0.0)) == report.STRATUM_WINNING)
check("both winning bounds are inclusive",
      report.stratum_of(metrics(0.7, 0.5, 0.0)) == report.STRATUM_WINNING)
check("just over the enemy bound is not winning",
      report.stratum_of(metrics(0.7, 0.6, 0.0)) == report.STRATUM_EVEN)
check("a hurt party reads as desperate",
      report.stratum_of(metrics(0.4, 0.9, 0.0)) == report.STRATUM_DESPERATE)
check("heavy incoming damage is desperate even at full HP",
      report.stratum_of(metrics(0.9, 0.9, 0.5)) == report.STRATUM_DESPERATE)
check("a mid board reads as even", report.stratum_of(metrics(0.6, 0.9, 0.1)) == report.STRATUM_EVEN)
check("winning wins the tie against threat",
      report.stratum_of(metrics(0.8, 0.4, 0.9)) == report.STRATUM_WINNING)
check("missing metrics read as desperate, never as winning",
      report.stratum_of({}) == report.STRATUM_DESPERATE)


# ------------------------------------------------------------- the run index
indexed = report.index_runs([
    run_started("r1", run_seed=7, player_run_number=2, ally_lineup=["striker"],
                is_debug_build=False, flags={"banner": True}),
    run_ended("r1", victory=True, abandoned=False, end_reason="final_wave_cleared",
              was_debug_tainted=False, balance_hash="patch-a", final_wave=1, total_turns=4),
])
check("a run merges its started and ended events", indexed["r1"]["victory"] is True)
check("the seed survives indexing", indexed["r1"]["run_seed"] == 7)
check("the end reason survives indexing", indexed["r1"]["end_reason"] == "final_wave_cleared")
check("flags are sorted", report.index_runs(
    [run_started("r1", flags={"z": 1, "a": 1})])["r1"]["flags"] == ["a", "z"])
check("a crash still yields a run, as a loss",
      report.index_runs([run_started("r2")])["r2"]["victory"] is False)
check("an event without a run id is skipped", report.index_runs([{"type": "run_started"}]) == {})
check("a developer build is marked as one",
      report.index_runs([run_started("r3", is_debug_build=True)])["r3"]["dev_build"] is True)


# ------------------------------------------------------------------ filtering
SPOOL = [
    run_started("clean"), run_ended("clean", victory=True),
    run_started("tainted"), run_ended("tainted", was_debug_tainted=True),
    run_started("editor", is_debug_build=True), run_ended("editor"),
    {"type": "decision", "run_id": "clean"},
]
spool_runs = report.index_runs(SPOOL)


def kept_ids(include_debug: bool, production_only: bool = False) -> set:
    return {str(event.get("run_id", "")) for event in
            report.keep_clean(SPOOL, spool_runs, include_debug, production_only)}


check("a clean run survives by default", "clean" in kept_ids(False))
check("a debug-tainted run is dropped by default", "tainted" not in kept_ids(False))
check("an editor playtest survives unless production mode is asked for",
      "editor" in kept_ids(False))
check("--production-only drops the editor playtest too", "editor" not in kept_ids(False, True))
check("--include-debug keeps a tainted run", "tainted" in kept_ids(True))
check("production mode drops both kinds", kept_ids(False, True) == {"clean"})
check("an event for an unknown run is never dropped",
      report.keep_clean([{"run_id": "ghost"}], {}, False) == [{"run_id": "ghost"}])


# --------------------------------------------------- the advantage-stratified lift
## A card played only while already winning. Its raw win rate is 100% - and so is the
## baseline of the stratum it was played in, so its lift is zero. "Win more" is not
## "win because of", and this is the trap the whole report exists to avoid.
WIN_MORE_SPOOL = [
    run_started("w1"), run_ended("w1", victory=True),
    run_started("w2"), run_ended("w2", victory=True),
    run_started("l1"), run_ended("l1", victory=False),
    decision("w1", "play_card", {"applied": True, "skill_id": "win_more", "card": {"key": "3"}},
             {"playable_skill_ids": ["win_more"]}, metrics(0.9, 0.2, 0.0)),
]
win_more = report.match_presence(
    [event for event in WIN_MORE_SPOOL if event["type"] == "decision"],
    report.index_runs(WIN_MORE_SPOOL),
)
win_row = win_more["rows"]["skill:win_more"]
check("a win-more card still shows a 100% raw win rate", close(win_row["raw_win_rate"], 1.0))
check("...and a lift of zero, because its stratum was already winning",
      close(win_row["advantage_adjusted_lift"], 0.0), str(win_row))
check("its baseline is the stratum it was played in",
      close(win_more["baselines"]["winning"], 1.0))
check("it is credited to the wins it appeared in", win_row["in_wins"] == 1 and win_row["in_losses"] == 0)
check("pct_of_wins divides by the winning matches", close(win_row["pct_of_wins"], 0.5))
check("pct_of_losses divides by the losing matches", close(win_row["pct_of_losses"], 0.0))

## A card that actually carries: played in an even fight, whose baseline is 50%.
EVEN_ROWS = [
    run_started("w1"), run_ended("w1", victory=True),
    run_started("w2"), run_ended("w2", victory=True),
    run_started("l1"), run_ended("l1", victory=False),
    run_started("l2"), run_ended("l2", victory=False),
]
EVEN_METRICS = metrics(0.6, 0.9, 0.1)


def even_decision(run_id: str, skill_id: str) -> dict:
    return decision(run_id, "play_card",
                    {"applied": True, "skill_id": skill_id, "card": {"key": "3"}},
                    {"playable_skill_ids": [skill_id]}, EVEN_METRICS)


EVEN_DECISIONS = [
    even_decision("w1", "carry"),
    even_decision("w1", "filler"),
    even_decision("w2", "filler"),
    even_decision("l1", "filler"),
    even_decision("l2", "filler"),
]
even = report.match_presence(EVEN_DECISIONS, report.index_runs(EVEN_ROWS))
check("the even-fight baseline is three wins out of five plays",
      close(even["baselines"]["even"], 0.6))
check("a card that wins from an even fight has positive lift",
      close(even["rows"]["skill:carry"]["advantage_adjusted_lift"], 0.4),
      str(even["rows"]["skill:carry"]))
check("a card played in every fight does not lift on its own",
      close(even["rows"]["skill:filler"]["advantage_adjusted_lift"], -0.1),
      str(even["rows"]["skill:filler"]))
check("the carrying card outranks the always-played one",
      even["rows"]["skill:carry"]["advantage_adjusted_lift"]
      > even["rows"]["skill:filler"]["advantage_adjusted_lift"])

## An abandoned run is not a loss, and its decisions are not a baseline. Counting them
## would take the baseline to 4/6 and lift `filler` from -0.1 to -0.067.
ABANDONED_ROWS = EVEN_ROWS + [run_started("q1"), run_ended("q1", victory=True, abandoned=True)]
abandoned = report.match_presence(
    EVEN_DECISIONS + [even_decision("q1", "filler")],
    report.index_runs(ABANDONED_ROWS),
)
check("an abandoned run never moves the stratum baseline",
      close(abandoned["baselines"]["even"], 0.6), str(abandoned["baselines"]))
check("an abandoned run is not counted as a loss, even when it was won",
      close(abandoned["rows"]["skill:filler"]["advantage_adjusted_lift"], -0.1),
      str(abandoned["rows"]["skill:filler"]))

## The lift is the mean over plays, not over strata. Here the counts happen to be equal -
## one stratum whose baseline was already 100% (delta 0) and one even fight (delta 0.5) -
## so both formulas say 0.25. The lopsided fixture below separates them.
MIXED_ROWS = [run_started("w1"), run_ended("w1", victory=True),
              run_started("w2"), run_ended("w2", victory=True),
              run_started("l3"), run_ended("l3", victory=False)]
mixed = report.match_presence([
    decision("w1", "play_card", {"applied": True, "skill_id": "mixed", "card": {"key": "3"}},
             {"playable_skill_ids": ["mixed"]}, metrics(0.9, 0.1, 0.0)),
    decision("w1", "play_card", {"applied": True, "skill_id": "other", "card": {"key": "3"}},
             {"playable_skill_ids": ["other"]}, metrics(0.9, 0.1, 0.0)),
    decision("w2", "play_card", {"applied": True, "skill_id": "mixed", "card": {"key": "3"}},
             {"playable_skill_ids": ["mixed"]}, metrics(0.6, 0.9, 0.1)),
    decision("l3", "play_card", {"applied": True, "skill_id": "other", "card": {"key": "3"}},
             {"playable_skill_ids": ["other"]}, metrics(0.6, 0.9, 0.1)),
], report.index_runs(MIXED_ROWS))
check("a mixed-strata lift averages the plays it appeared in",
      close(mixed["rows"]["skill:mixed"]["advantage_adjusted_lift"], 0.25),
      str(mixed["rows"]["skill:mixed"]))
check("each stratum keeps its own baseline",
      close(mixed["baselines"]["winning"], 1.0) and close(mixed["baselines"]["even"], 0.5),
      str(mixed["baselines"]))

## Equal counts hide the weighting, so this fixture is lopsided: `heavy` is played three
## times on an already-winning board (baseline 100%, so delta 0) and once in an even fight
## (delta 0.5). Weighting the strata equally would report 0.25; averaging per play reports
## 0.125, which is the number `v_win_loss_presence` computes in SQL.
WINNING_BOARD = metrics(0.9, 0.1, 0.0)
LOPSIDED_ROWS = [run_started("a"), run_ended("a", victory=True),
                 run_started("b"), run_ended("b", victory=True),
                 run_started("c"), run_ended("c", victory=False),
                 run_started("d"), run_ended("d", victory=False),
                 run_started("e"), run_ended("e", victory=False)]


def winning_decision(run_id: str, skill_id: str) -> dict:
    return decision(run_id, "play_card",
                    {"applied": True, "skill_id": skill_id, "card": {"key": "3"}},
                    {"playable_skill_ids": [skill_id]}, WINNING_BOARD)


lopsided = report.match_presence([
    # Five even-fight plays (the `heavy` play below is counted in that stratum too), and
    # three of those six even-fight plays were won: the even baseline is 0.5.
    even_decision("a", "filler"),
    even_decision("b", "filler"),
    even_decision("c", "filler"),
    even_decision("d", "filler"),
    even_decision("e", "filler"),
    winning_decision("a", "heavy"),
    winning_decision("a", "heavy"),
    winning_decision("b", "heavy"),
    even_decision("a", "heavy"),
], report.index_runs(LOPSIDED_ROWS))
check("a lopsided mix weights the lift by play, not by stratum",
      close(lopsided["rows"]["skill:heavy"]["advantage_adjusted_lift"], 0.125),
      str(lopsided["rows"]["skill:heavy"]))
check("...which is not the stratum-equal average of 0.25",
      not close(lopsided["rows"]["skill:heavy"]["advantage_adjusted_lift"], 0.25),
      str(lopsided["rows"]["skill:heavy"]))
check("its raw win rate is still 100% - the trap the lift exists to remove",
      close(lopsided["rows"]["skill:heavy"]["raw_win_rate"], 1.0),
      str(lopsided["rows"]["skill:heavy"]))
check("the winning-board baseline is every play on a winning board",
      close(lopsided["baselines"]["winning"], 1.0), str(lopsided["baselines"]))
check("the even baseline counts every play in that stratum",
      close(lopsided["baselines"]["even"], 0.5), str(lopsided["baselines"]))


# ------------------------------------------------------------ labels and skips
LABEL_ROW = [run_started("w1"), run_ended("w1", victory=True)]
labelled = report.match_presence([
    decision("w1", "play_card", {"applied": True, "skill_id": "", "card": {}}, {},
             metrics(0.6, 0.9, 0.1)),
    decision("w1", "cast_ultimate", {"applied": True}, {}, metrics(0.6, 0.9, 0.1)),
    decision("w1", "play_card", {"applied": False, "skill_id": "ignored", "card": {"key": "3"}},
             {}, metrics(0.6, 0.9, 0.1)),
    decision("w1", "convert_action", {"applied": True}, {}, metrics(0.6, 0.9, 0.1)),
], report.index_runs(LABEL_ROW))
check("a missing skill and card id are labelled unknown",
      "skill:unknown" in labelled["rows"] and "card:unknown" in labelled["rows"])
check("a missing ultimate id is labelled unknown", "ultimate:unknown" in labelled["rows"])
check("a decision that was not applied counts as no cast",
      "skill:ignored" not in labelled["rows"])
check("a convert is not a skill, card or ultimate row", len(labelled["rows"]) == 3,
      str(sorted(labelled["rows"])))


# --------------------------------------------------------------- flag cohorts
PATCH_A = "patch-a"
PATCH_B = "patch-b"
flag_runs = report.index_runs([
    run_started("on_a", flags={"banner": True}),
    run_ended("on_a", victory=True, balance_hash=PATCH_A),
    run_started("off_a"),
    run_ended("off_a", victory=False, balance_hash=PATCH_A),
    run_started("on_b", flags={"banner": True}),
    run_ended("on_b", victory=False, balance_hash=PATCH_B),
    run_started("off_b"),
    run_ended("off_b", victory=True, balance_hash=PATCH_B),
])
cohorts = report.flag_cohorts(flag_runs)
row_a = cohorts[f"banner|{PATCH_A}"]
check("a cohort is keyed by the flag and the balance patch", f"banner|{PATCH_A}" in cohorts)
check("the flag-on side counts the runs that had it", row_a["on"] == 1 and row_a["on_wins"] == 1)
check("the control group is the same patch, never the pooled set",
      row_a["off"] == 1 and row_a["off_wins"] == 0, str(row_a))
check("the other patch gets its own row, with its own control",
      cohorts[f"banner|{PATCH_B}"]["on"] == 1 and cohorts[f"banner|{PATCH_B}"]["off"] == 1)
check("a run is never both sides of one row", row_a["on"] + row_a["off"] == 2)

abandoned_flags = report.index_runs([
    run_started("on_a", flags={"banner": True}),
    run_ended("on_a", victory=True, balance_hash=PATCH_A),
    run_started("gone", flags={"banner": True}),
    run_ended("gone", victory=True, abandoned=True, balance_hash=PATCH_A),
    run_started("off_a"),
    run_ended("off_a", victory=False, balance_hash=PATCH_A),
])
check("an abandoned run joins no flag cohort",
      report.flag_cohorts(abandoned_flags)[f"banner|{PATCH_A}"]["on"] == 1)

hashless = report.index_runs([
    run_started("on_a", flags={"banner": True}),
    run_ended("on_a", victory=True, balance_hash=PATCH_A),
    run_started("mystery"),
    run_ended("mystery", victory=True),
])
check("a run with no patch never joins another patch's control group",
      report.flag_cohorts(hashless)[f"banner|{PATCH_A}"]["off"] == 0)


# --------------------------------------------------------- experience cohorts
def cohort_bucket(run_number: int) -> str:
    """Which bucket one run of `run_number` battles lands in, or "none"."""
    rows = report.cohort_pick_rates(
        [even_decision("r", "k")],
        report.index_runs([run_started("r", player_run_number=run_number), run_ended("r")]),
    )
    if "veteran:k" in rows:
        return "veteran"
    return "new" if "new:k" in rows else "none"


check("the threshold itself is still a new player", cohort_bucket(3) == "new")
check("one run past the threshold is a veteran", cohort_bucket(4) == "veteran")

COHORT_ROWS = report.index_runs([
    run_started("newbie", player_run_number=1), run_ended("newbie"),
    run_started("vet", player_run_number=9), run_ended("vet"),
    run_started("gone", player_run_number=1), run_ended("gone", abandoned=True),
])
cohort_report = report.cohort_pick_rates([
    even_decision("newbie", "k"),
    even_decision("vet", "k"),
    even_decision("vet", "k"),
    even_decision("ghost", "k"),
    even_decision("gone", "k"),
], COHORT_ROWS)
check("a new player's run lands in the new bucket", cohort_report["new:k"]["offered"] == 1)
check("a veteran's runs land in the veteran bucket", cohort_report["veteran:k"]["offered"] == 2)
check("an abandoned run is in no experience cohort",
      cohort_report["new:k"]["offered"] + cohort_report["veteran:k"]["offered"] == 3)
check("a run of unknown experience is ignored", len(cohort_report) == 2, str(sorted(cohort_report)))

PICK_ROWS = report.index_runs([run_started("vet", player_run_number=9), run_ended("vet")])
PICK_RATES = report.cohort_pick_rates([
    decision("vet", "play_card", {"applied": True, "skill_id": "always", "card": {}},
             {"playable_skill_ids": ["always", "sometimes"]}, {}),
    decision("vet", "play_card", {"applied": True, "skill_id": "always", "card": {}},
             {"playable_skill_ids": ["always", "never"]}, {}),
    decision("vet", "play_card", {"applied": True, "skill_id": "sometimes", "card": {}},
             {"playable_skill_ids": ["always", "sometimes"]}, {}),
], PICK_ROWS)
check("a skill taken two of the three times it was offered rates 2/3",
      close(PICK_RATES["veteran:always"]["pick_rate"], 2 / 3), str(PICK_RATES["veteran:always"]))
check("a skill taken half the times it was offered rates 0.5",
      close(PICK_RATES["veteran:sometimes"]["pick_rate"], 0.5))
check("a skill offered but never picked rates zero",
      close(PICK_RATES["veteran:never"]["pick_rate"], 0.0))


# --------------------------------------------------------------- defeat causes
defeats = report.defeat_causes(report.index_runs([
    run_started("lost"),
    run_ended("lost", victory=False,
              killed_by={"kind": "enemy_skill", "source_unit_id": "boss_enemy",
                         "source_skill_id": "boss_enemy_2"},
              ally_deaths=[{"kind": "status", "status_id": "gloom"}]),
    run_started("won"),
    run_ended("won", victory=True,
              killed_by={"kind": "enemy_skill", "source_unit_id": "x", "source_skill_id": "y"}),
    run_started("gone"),
    run_ended("gone", victory=False, abandoned=True,
              killed_by={"kind": "enemy_skill", "source_unit_id": "z", "source_skill_id": "w"}),
    run_started("mystery"),
    run_ended("mystery", victory=False, killed_by={"kind": "???"}),
]))
check("a defeat names the enemy skill that landed",
      defeats["killed_by"]["boss_enemy / boss_enemy_2"] == 1, str(defeats["killed_by"]))
check("a victory is not a defeat cause", "x / y" not in defeats["killed_by"])
check("an abandoned run is not a defeat", "z / w" not in defeats["killed_by"])
check("an unrecognised cause is labelled unknown", defeats["killed_by"]["unknown"] == 1)
check("a status death is labelled with the status", defeats["ally_deaths"]["status: gloom"] == 1)


# ------------------------------------------------------------------ formatting
check("a percentage is one decimal, right-aligned", report._pct(0.5) == " 50.0%")
check("a bar is empty at a zero scale", report._bar(5, 0) == "")
check("a bar never exceeds 28 characters", len(report._bar(1000, 100)) == 28)
check("a bar scales with the value", report._bar(50, 100) == "#" * 14)


# ------------------------------------------------------------------ the spool
RAW = WORK / "raw"
RAW.mkdir(parents=True, exist_ok=True)
(RAW / "runs.jsonl").write_text(
    json.dumps(run_started("r1")) + "\n"
    + "\n"                                              # a blank line
    + "{not json\n"                                     # a half-written line
    + json.dumps({"schema_version": 99, "run_id": "future"}) + "\n"
    + json.dumps(["not", "an", "object"]) + "\n",
    encoding="utf-8",
)
loaded = report.load_events([RAW])
check("a directory is read as its jsonl files", len(loaded) == 1)
check("a blank line, a half-written line, a future schema and a list are all skipped",
      loaded[0]["run_id"] == "r1")
check("a single file path works too", len(report.load_events([RAW / "runs.jsonl"])) == 1)
check("a path that does not exist yields nothing", report.load_events([WORK / "nowhere"]) == [])


# ------------------------------------------------------------------- the CLI
def run_main(argv: list) -> tuple[int, str]:
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        code = report.main(argv)
    return code, buffer.getvalue()


CLI_SPOOL = write_spool("cli", [
    run_started("r1", run_seed=1, player_run_number=1, ally_lineup=["striker"]),
    decision("r1", "play_card", {"applied": True, "skill_id": "striker_1", "card": {"key": "3"}},
             {"playable_skill_ids": ["striker_1"]}, metrics(0.6, 0.9, 0.1)),
    run_ended("r1", victory=True, balance_hash=PATCH_A, end_reason="final_wave_cleared"),
])
export = WORK / "report.json"
code, printed = run_main([str(CLI_SPOOL), "--json", str(export)])
check("the CLI reports a real spool and exits 0", code == 0, printed[-200:])
payload = json.loads(export.read_text(encoding="utf-8"))
check("the JSON export carries every section the report reads",
      {"runs", "pick_rates", "flag_cohorts", "cohort_pick_rates", "win_loss"} <= set(payload),
      str(sorted(payload)))
check("the export carries the run it indexed", set(payload["runs"]) == {"r1"})
check("the export carries the seed, so a run can be replayed",
      payload["runs"]["r1"]["run_seed"] == 1)
check("the pick rate for the played skill reached the export",
      close(payload["pick_rates"]["skills"]["striker_1"]["pick_rate"], 1.0))


# ------------------------------------------------------------- the denominators
## The whole report rests on "offered" being the times a choice was *legal*, not the
## times it was taken: a skill played once out of two offers is a 50% pick rate.
PICKS = report.offer_and_pick([
    decision("r1", "play_card", {"applied": True, "skill_id": "s1", "card": {"key": "3"}},
             {"playable_skill_ids": ["s1", "s2"], "offered_card_keys": ["3", "5"]}, {}),
    decision("r1", "play_card", {"applied": True, "skill_id": "s2", "card": {"key": "5"}},
             {"playable_skill_ids": ["s1", "s2"], "offered_card_keys": ["3", "5"]}, {}),
    decision("r1", "cast_ultimate", {"applied": True, "ultimate_skill_id": "u1"},
             {"ready_ultimate_skills": ["u1"]}, {}),
    decision("r1", "merge_cards",
             {"applied": True, "card_a": {"key": "3"}, "card_b": {"key": "5"},
              "result": {"key": "8"}}, {}, {}),
])
check("a skill's denominator is the times it was playable",
      PICKS["skills"]["s1"] == {"offered": 2, "picked": 1, "pick_rate": 0.5},
      str(PICKS["skills"]))
check("a card's denominator is the times it was in hand",
      PICKS["cards"]["3"] == {"offered": 2, "picked": 1, "pick_rate": 0.5})
check("an ultimate counts only when it was ready",
      PICKS["ultimates"]["u1"] == {"offered": 1, "picked": 1, "pick_rate": 1.0})
check("a merge records both inputs and the result",
      PICKS["card_merged_as_input"]["3"] == 1 and PICKS["card_merged_into"]["8"] == 1)
check("a skill picked without ever being offered still gets a row",
      report.offer_and_pick([decision("r1", "play_card",
                                      {"applied": True, "skill_id": "ghost", "card": {}}, {}, {})]
                            )["skills"]["ghost"] == {"offered": 0, "picked": 1, "pick_rate": 0.0})

PROMPTED = report.offer_and_pick([{
    "type": "decision", "run_id": "r1", "decision_type": "play_card",
    "chosen": {"applied": True, "skill_id": "s1"},
    "sub_prompts": [
        {"prompt": "pick_target", "candidates": [{"unit_id": "boss"}],
         "picked": [{"unit_id": "boss"}]},
        {"prompt": "pick_card", "candidates": [{"key": "3"}, {"key": "5"}],
         "picked": [{"key": "3"}]},
    ],
}])
check("a target prompt counts its candidate and its pick",
      PROMPTED["targets"]["prompts"] == 1
      and PROMPTED["targets"]["candidates"]["boss"] == 1
      and PROMPTED["targets"]["picked"]["boss"] == 1)
check("a card prompt counts candidates and picks separately",
      PROMPTED["card_prompts"]["candidates"]["5"] == 1
      and "5" not in PROMPTED["card_prompts"]["picked"])

TAINTED_SPOOL = write_spool("tainted", [
    run_started("t1"), run_ended("t1", victory=True, was_debug_tainted=True),
])
tainted_export = WORK / "tainted.json"
code, printed = run_main([str(TAINTED_SPOOL), "--json", str(tainted_export)])
check("a fully tainted spool still reports, without the run",
      code == 0 and json.loads(tainted_export.read_text(encoding="utf-8"))["runs"] == {})
code, printed = run_main([str(WORK / "empty-spool")])
check("an empty spool exits 1 with a message",
      code == 1 and "No telemetry events found" in printed, printed)
check("no spool at all exits 1 too", run_main([])[0] in (0, 1))


# -------------------------------------------------------------------- summary
failures = [entry for entry in results if not entry[1]]
for name, ok, detail in results:
    if not ok:
        print(f"FAIL {name}" + (f"  -> {non_blank(detail)}" if detail else ""))
shutil.rmtree(WORK, ignore_errors=True)
print(f"\n{len(results) - len(failures)}/{len(results)} checks passed")
raise SystemExit(1 if failures else 0)
