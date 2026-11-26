#!/usr/bin/env python3
"""Local game-balance report over the telemetry spool.

Reads the newline-delimited JSON files that Core/Telemetry/JsonlFileSink.gd
writes (one event per line, one file per run) and prints the three human-centric
questions from the Mega Crit approach:

  1. Pick rate        - what players choose when offered a choice
  2. Win correlation  - raw win rate next to an advantage-stratified lift, so a
                        card that only appears in already-winning games does not
                        look overpowered (the "Madness" selection-bias trap)
  3. Situational      - how much HP is lost against each specific enemy when a
                        given skill was used

No third-party dependencies: standard library only.

Usage:
    python Tools/analyze_telemetry.py                     # auto-detect the spool
    python Tools/analyze_telemetry.py path/to/spool ...
    python Tools/analyze_telemetry.py --include-debug
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections import Counter, defaultdict
from pathlib import Path

SCHEMA_VERSION = 1

# Advantage strata used to de-bias win correlation.
STRATUM_WINNING = "winning"
STRATUM_EVEN = "even"
STRATUM_DESPERATE = "desperate"


def default_spool_dirs() -> list[Path]:
    """The Godot user:// telemetry spool for this project, best effort."""
    candidates: list[Path] = []
    appdata = os.environ.get("APPDATA")
    if appdata:
        candidates.append(Path(appdata) / "Godot" / "app_userdata")
    home = Path.home()
    for base in (home / "Library" / "Application Support" / "Godot" / "app_userdata",
                 home / ".local" / "share" / "godot" / "app_userdata"):
        candidates.append(base)
    dirs: list[Path] = []
    for base in candidates:
        if not base.is_dir():
            continue
        for project in base.iterdir():
            spool = project / "telemetry" / "spool"
            if spool.is_dir():
                dirs.append(spool)
    return dirs


def load_events(paths: list[Path]) -> list[dict]:
    events: list[dict] = []
    for path in paths:
        path = path.resolve()
        files = sorted(path.glob("*.jsonl")) if path.is_dir() else [path]
        for file in files:
            with file.open("r", encoding="utf-8") as handle:
                for line in handle:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        event = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if isinstance(event, dict):
                        events.append(event)
    return events


def stratum_of(metrics: dict) -> str:
    """Buckets a pre-decision board snapshot into an advantage stratum."""
    ally = float(metrics.get("ally_hp_pct", 0.0))
    enemy = float(metrics.get("enemy_hp_pct", 0.0))
    threat = float(metrics.get("threat_ratio", 0.0))
    if ally >= 0.7 and enemy <= 0.5:
        return STRATUM_WINNING
    if ally <= 0.4 or threat >= 0.5:
        return STRATUM_DESPERATE
    return STRATUM_EVEN


def index_runs(events: list[dict]) -> dict[str, dict]:
    runs: dict[str, dict] = {}
    for event in events:
        if event.get("type") != "run_ended":
            continue
        run_id = str(event.get("run_id", ""))
        if not run_id:
            continue
        runs[run_id] = {
            "victory": bool(event.get("victory", False)),
            "end_reason": str(event.get("end_reason", "")),
            "tainted": bool(event.get("was_debug_tainted", False)),
            "balance_hash": str(event.get("balance_hash", "")),
        }
    return runs


def keep_clean(events: list[dict], runs: dict[str, dict], include_debug: bool) -> list[dict]:
    """Drops every run a tester tool touched, so dev experiments never mix in."""
    if include_debug:
        return events
    tainted = {rid for rid, run in runs.items() if run["tainted"]}
    return [e for e in events if str(e.get("run_id", "")) not in tainted]


def pick_rates(decisions: list[dict]) -> tuple[Counter, Counter]:
    """Returns (applied action counts, offered-position counts)."""
    applied: Counter = Counter()
    offered: Counter = Counter()
    for decision in decisions:
        chosen = decision.get("chosen") or {}
        dtype = str(decision.get("decision_type", ""))
        if chosen.get("applied"):
            applied[dtype] += 1
        if dtype == "play_card":
            offer = decision.get("offered") or {}
            for card in offer.get("cards_in_hand") or []:
                offered["hand_parity:" + str(card.get("parity", ""))] += 1
            offered["merge_pairs_available"] += len(offer.get("legal_merge_pairs") or [])
            if chosen.get("applied"):
                applied["skill:" + str(chosen.get("skill_id", ""))] += 1
                applied["parity:" + str((chosen.get("card") or {}).get("parity", ""))] += 1
        elif dtype == "merge_cards" and chosen.get("applied"):
            result = chosen.get("result") or {}
            if result:
                applied["merge_rank:%d" % int(result.get("merge_rank", 0))] += 1
    return applied, offered


def win_correlation(decisions: list[dict], runs: dict[str, dict]) -> tuple[dict, dict]:
    """Per skill: raw win rate and the advantage-stratified lift.

    The lift is the mean of `P(win | skill) - P(win | that stratum)`, so a skill
    that only shows up in already-winning games scores near zero instead of
    looking like a win button (the selection-bias trap).
    """
    stratum_wins: Counter = Counter()
    stratum_total: Counter = Counter()
    skill_stratum_wins: dict[str, Counter] = defaultdict(Counter)
    skill_stratum_total: dict[str, Counter] = defaultdict(Counter)
    skill_wins: Counter = Counter()
    skill_total: Counter = Counter()

    for decision in decisions:
        if decision.get("decision_type") != "play_card":
            continue
        chosen = decision.get("chosen") or {}
        if not chosen.get("applied"):
            continue
        run = runs.get(str(decision.get("run_id", "")))
        if run is None:
            continue
        context = decision.get("context") or {}
        stratum = stratum_of(context.get("metrics") or {})
        won = 1 if run["victory"] else 0
        stratum_wins[stratum] += won
        stratum_total[stratum] += 1

        skill = str(chosen.get("skill_id", "")) or "unknown"
        skill_total[skill] += 1
        skill_wins[skill] += won
        skill_stratum_wins[skill][stratum] += won
        skill_stratum_total[skill][stratum] += 1

    summaries: dict[str, dict] = {}
    for skill, total in skill_total.items():
        lift = 0.0
        strata = 0
        for stratum, count in skill_stratum_total[skill].items():
            if count <= 0:
                continue
            baseline = stratum_wins[stratum] / stratum_total[stratum]
            lift += (skill_stratum_wins[skill][stratum] / count) - baseline
            strata += 1
        summaries[skill] = {
            "casts": total,
            "raw_win_rate": (skill_wins[skill] / total) if total else 0.0,
            "advantage_adjusted_lift": (lift / strata) if strata else 0.0,
        }
    baselines = {
        stratum: (stratum_wins[stratum] / stratum_total[stratum])
        for stratum in stratum_total
    }
    return summaries, baselines


def situational_damage(decisions: list[dict]) -> dict[tuple[str, str], dict]:
    """(skill_id, enemy_unit_id) -> HP the player took while that skill resolved."""
    table: dict[tuple[str, str], dict] = {}
    for decision in decisions:
        chosen = decision.get("chosen") or {}
        skill = str(chosen.get("skill_id", "")) or "unknown"
        outcome = decision.get("outcome") or {}
        for row in outcome.get("damage_events") or []:
            if not bool(row.get("target_is_ally", False)):
                continue
            key = (skill, str(row.get("target_id", "")))
            entry = table.setdefault(key, {"hits": 0, "hp_lost": 0})
            entry["hits"] += 1
            entry["hp_lost"] += int(row.get("hp_lost", 0))
    return table



def _bar(value: int, scale: int) -> str:
    return "#" * max(0, min(40, int(round(value / scale * 40)))) if scale else ""


def report(events, runs, baselines, applied, offered, correlation, damage, paths) -> str:
    lines: list[str] = []
    add = lines.append
    victories = sum(1 for run in runs.values() if run["victory"])
    tainted = sum(1 for run in runs.values() if run["tainted"])
    decisions = [e for e in events if e.get("type") == "decision"]

    add("=== TELEMETRY BALANCE REPORT ===")
    add("spool:      " + ", ".join(str(p) for p in paths))
    add("events:     %d" % len(events))
    add("runs:       %d  (victories %d, win rate %.1f%%)"
        % (len(runs), victories, (victories / len(runs) * 100.0) if runs else 0.0))
    add("decisions:  %d   debug-tainted runs: %d" % (len(decisions), tainted))

    add("")
    add("-- Run outcomes --")
    reasons: Counter = Counter(run["end_reason"] for run in runs.values())
    for reason, count in reasons.most_common():
        add("  %-22s %d" % (reason or "unknown", count))
    hashes: Counter = Counter(run["balance_hash"][:12] for run in runs.values())
    for digest, count in hashes.most_common():
        add("  balance %s  %d run(s)" % (digest or "-", count))

    add("")
    add("-- Action pick rates (applied) --")
    for key, count in applied.most_common():
        share = (count / len(decisions) * 100.0) if decisions else 0.0
        add("  %-24s %4d  %5.1f%%  %s" % (key, count, share, _bar(count, max(applied.values() or [1]))))

    add("")
    add("-- Offered alternatives (the denominator) --")
    for key, count in offered.most_common():
        add("  %-24s %4d" % (key, count))

    add("")
    add("-- Win correlation, de-biased (selection-bias trap detector) --")
    add("  %-24s %5s %9s %10s" % ("skill", "casts", "raw win%", "adj lift%"))
    for skill, row in sorted(correlation.items(), key=lambda kv: -kv[1]["casts"]):
        add("  %-24s %5d %8.1f%% %+9.1f%%"
            % (skill, row["casts"], row["raw_win_rate"] * 100.0,
               row["advantage_adjusted_lift"] * 100.0))
    if baselines:
        add("  stratum baselines: " + "  ".join(
            "%s %.1f%%" % (name, value * 100.0) for name, value in sorted(baselines.items())))

    add("")
    add("-- Situational damage taken (player skill vs enemy) --")
    add("  %-24s %-24s %5s %9s %8s" % ("skill", "enemy", "hits", "hp_lost", "avg"))
    for (skill, enemy), row in sorted(damage.items(), key=lambda kv: -kv[1]["hp_lost"]):
        avg = row["hp_lost"] / row["hits"] if row["hits"] else 0.0
        add("  %-24s %-24s %5d %9d %8.1f" % (skill, enemy, row["hits"], row["hp_lost"], avg))

    return "\n".join(lines)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Local telemetry balance report.")
    parser.add_argument("paths", nargs="*", help="spool directories or .jsonl files")
    parser.add_argument("--include-debug", action="store_true",
                        help="include runs touched by the tester debug tools")
    parser.add_argument("--json", dest="json_out", default="",
                        help="also write the report data as JSON to this path")
    args = parser.parse_args(argv)

    paths = [Path(p) for p in args.paths] if args.paths else default_spool_dirs()
    if not paths:
        print("No telemetry spool found. Pass a directory containing *.jsonl files.")
        return 1
    events = load_events(paths)
    if not events:
        print("No telemetry events found in: " + ", ".join(str(p) for p in paths))
        return 1

    runs = index_runs(events)
    clean = keep_clean(events, runs, args.include_debug)
    decisions = [e for e in clean if e.get("type") == "decision"]
    applied, offered = pick_rates(decisions)
    correlation, baselines = win_correlation(decisions, runs)
    damage = situational_damage(decisions)

    print(report(clean, runs, baselines, applied, offered, correlation, damage, paths))

    if args.json_out:
        payload = {
            "runs": runs,
            "pick_rates": dict(applied),
            "offered": dict(offered),
            "win_correlation": correlation,
            "stratum_baselines": baselines,
            "situational_damage": {"%s|%s" % k: v for k, v in damage.items()},
        }
        Path(args.json_out).write_text(json.dumps(payload, indent=2), encoding="utf-8")
        print("\nWrote " + args.json_out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

