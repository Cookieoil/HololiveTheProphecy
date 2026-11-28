#!/usr/bin/env python3
"""Local game-balance report over the telemetry spool.

Reads the newline-delimited JSON that Core/Telemetry/JsonlFileSink.gd writes (one
event per line, one file per run) and answers the human-centric questions the
metric server exists for:

  1. Pick rate                 - how often a skill / card / Ultimate was the choice,
                                 out of the times it was actually offered
  2. What players chose instead - the opportunity cost of passing something over
  3. Winning vs losing matches  - how often it appeared in a win or a loss, next
                                 to an advantage-stratified lift (the "Madness"
                                 selection-bias trap)
  4. Enemy strategy             - what players do against a specific enemy, and
                                 how much HP that enemy takes off them
  5. Roster coverage            - whether each ally was ever used at all
  6. Wasted resources           - turns ended with actions still playable
  7. Experience cohorts         - the same pick rates for new vs veteran players
  8. Defeat causes              - which enemy or status actually killed the run
  9. Staged feature flags       - win rate with a flag on vs off *within the same
                                 balance patch*, so an experiment is read before it
                                 is rolled out to everyone

No third-party dependencies: standard library only.

Usage:
    python Tools/analyze_telemetry.py                     # auto-detect the spool
    python Tools/analyze_telemetry.py path/to/spool ...
    python Tools/analyze_telemetry.py --production-only   # real players only
    python Tools/analyze_telemetry.py --include-debug --json out.json
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
        if not path.exists():
            # A typo'd path is the same class of bad input as a half-written line: the
            # report should say it found nothing, not traceback on the way there.
            continue
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
                    if isinstance(event, dict) and event.get("schema_version") == SCHEMA_VERSION:
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
    """One entry per run, merged from its run_started and run_ended events.

    `run_started` carries the seed, the run number and the line-up; `run_ended`
    carries the result. Defaults are filled in so a run that never finished (a
    crash) still appears instead of being silently dropped.
    """
    runs: dict[str, dict] = {}
    for event in events:
        run_id = str(event.get("run_id", ""))
        if not run_id:
            continue
        entry = runs.setdefault(run_id, {})
        kind = str(event.get("type", ""))
        if kind == "run_started":
            entry["run_seed"] = event.get("run_seed")
            entry["player_run_number"] = int(event.get("player_run_number", 0) or 0)
            entry["ally_lineup"] = [str(ally) for ally in (event.get("ally_lineup") or [])]
            entry["dev_build"] = bool(event.get("is_debug_build", False))
            entry["flags"] = sorted(str(flag) for flag in (event.get("flags") or {}))
        elif kind == "run_ended":
            entry.update({
                "victory": bool(event.get("victory", False)),
                "abandoned": bool(event.get("abandoned", False)),
                "end_reason": str(event.get("end_reason", "")),
                "tainted": bool(event.get("was_debug_tainted", False)),
                "balance_hash": str(event.get("balance_hash", "")),
                "final_wave": int(event.get("final_wave", 0) or 0),
                "total_turns": int(event.get("total_turns", 0) or 0),
                "killed_by": event.get("killed_by") or {},
                "ally_deaths": event.get("ally_deaths") or [],
            })
    for entry in runs.values():
        entry.setdefault("victory", False)
        entry.setdefault("abandoned", False)
        entry.setdefault("end_reason", "")
        entry.setdefault("tainted", False)
        entry.setdefault("balance_hash", "")
        entry.setdefault("final_wave", 0)
        entry.setdefault("total_turns", 0)
        entry.setdefault("run_seed", None)
        entry.setdefault("player_run_number", 0)
        entry.setdefault("ally_lineup", [])
        entry.setdefault("dev_build", False)
        entry.setdefault("flags", [])
        entry.setdefault("killed_by", {})
        entry.setdefault("ally_deaths", [])
    return runs


def keep_clean(
    events: list[dict],
    runs: dict[str, dict],
    include_debug: bool,
    production_only: bool = False,
) -> list[dict]:
    """Drops tester-tainted runs (debug menu) and, in production mode, developer
    builds - so a playtest in the editor never lands in a player balance view."""
    drop: set[str] = set()
    for run_id, run in runs.items():
        if not include_debug and run["tainted"]:
            drop.add(run_id)
        elif production_only and run["dev_build"]:
            drop.add(run_id)
    return [e for e in events if str(e.get("run_id", "")) not in drop]



#region Pick rates: how often a choice was taken when it was on the table
def offer_and_pick(decisions: list[dict]) -> dict:
    """Counts, per skill / card / Ultimate, how often it was offered vs picked.

    `offered` is the honest denominator: a skill only counts when it was actually
    legal to cast at that moment (GameManager records `offered.playable_skills`).
    """
    skill_offered: Counter = Counter()
    skill_picked: Counter = Counter()
    card_offered: Counter = Counter()
    card_played: Counter = Counter()
    card_merged: Counter = Counter()
    card_merged_into: Counter = Counter()
    ult_offered: Counter = Counter()
    ult_cast: Counter = Counter()
    target_prompts: Counter = Counter()
    target_picks: Counter = Counter()
    card_prompts: Counter = Counter()
    card_picks: Counter = Counter()

    for decision in decisions:
        offer = decision.get("offered") or {}
        chosen = decision.get("chosen") or {}
        dtype = str(decision.get("decision_type", ""))
        applied = bool(chosen.get("applied", False))

        for skill_id in offer.get("playable_skill_ids") or []:
            skill_offered[str(skill_id)] += 1
        for key in offer.get("offered_card_keys") or []:
            card_offered[str(key)] += 1
        for ult_id in offer.get("ready_ultimate_skills") or []:
            ult_offered[str(ult_id)] += 1

        if applied and dtype == "play_card":
            skill_id = str(chosen.get("skill_id", ""))
            if skill_id:
                skill_picked[skill_id] += 1
            key = str((chosen.get("card") or {}).get("key", ""))
            if key:
                card_played[key] += 1
        elif applied and dtype == "cast_ultimate":
            ult_id = str(chosen.get("ultimate_skill_id", ""))
            if ult_id:
                ult_cast[ult_id] += 1
        elif applied and dtype == "merge_cards":
            for side in ("card_a", "card_b"):
                key = str((chosen.get(side) or {}).get("key", ""))
                if key:
                    card_merged[key] += 1
            result = str((chosen.get("result") or {}).get("key", ""))
            if result:
                card_merged_into[result] += 1

        for prompt in decision.get("sub_prompts") or []:
            kind = str(prompt.get("prompt", ""))
            if kind == "pick_target":
                target_prompts["prompts"] += 1
                for unit in prompt.get("candidates") or []:
                    target_prompts["candidate:" + str(unit.get("unit_id", ""))] += 1
                for unit in prompt.get("picked") or []:
                    target_picks[str(unit.get("unit_id", ""))] += 1
            elif kind == "pick_card":
                card_prompts["prompts"] += 1
                for card in prompt.get("candidates") or []:
                    card_prompts["candidate:" + str(card.get("key", ""))] += 1
                for card in prompt.get("picked") or []:
                    card_picks[str(card.get("key", ""))] += 1

    def rate(picked: Counter, offered: Counter) -> dict[str, dict]:
        rows: dict[str, dict] = {}
        for key, count in offered.items():
            taken = picked.get(key, 0)
            rows[key] = {
                "offered": count,
                "picked": taken,
                "pick_rate": (taken / count) if count else 0.0,
            }
        for key, taken in picked.items():
            if key not in rows:
                rows[key] = {"offered": 0, "picked": taken, "pick_rate": 0.0}
        return rows

    return {
        "skills": rate(skill_picked, skill_offered),
        "cards": rate(card_played, card_offered),
        "ultimates": rate(ult_cast, ult_offered),
        "card_merged_as_input": dict(card_merged),
        "card_merged_into": dict(card_merged_into),
        "targets": {
            "prompts": target_prompts.get("prompts", 0),
            "candidates": {k[len("candidate:"):]: v
                           for k, v in target_prompts.items() if k.startswith("candidate:")},
            "picked": dict(target_picks),
        },
        "card_prompts": {
            "prompts": card_prompts.get("prompts", 0),
            "candidates": {k[len("candidate:"):]: v
                           for k, v in card_prompts.items() if k.startswith("candidate:")},
            "picked": dict(card_picks),
        },
    }
#endregion



#region What players chose instead (opportunity cost)
def substitution(decisions: list[dict]) -> dict[str, dict]:
    """For every offer that was passed over, what the player did instead.

    Keyed by the skill / Ultimate that was available, e.g.
    `{"healer_1": {"chosen": 18, "play:striker_1": 12, "merge_cards": 4,
    "end_turn_with_actions": 3}}`. `chosen` counts the times it *was* taken, so the
    denominator is the reply count minus `chosen`.
    """
    table: dict[str, Counter] = defaultdict(Counter)
    for decision in decisions:
        offer = decision.get("offered") or {}
        chosen = decision.get("chosen") or {}
        dtype = str(decision.get("decision_type", ""))
        applied = bool(chosen.get("applied", False))
        chosen_skill = str(chosen.get("skill_id", "")) if dtype == "play_card" else ""
        chosen_ult = str(chosen.get("ultimate_skill_id", "")) if dtype == "cast_ultimate" else ""

        if applied and dtype == "play_card":
            action = "play:" + (chosen_skill or "unknown")
        elif applied and dtype == "cast_ultimate":
            action = "ultimate:" + (chosen_ult or "unknown")
        elif applied and dtype == "convert_action":
            action = "convert_action"
        elif applied and dtype == "merge_cards":
            action = "merge_cards"
        elif applied and dtype == "end_turn":
            unused = int(chosen.get("unused_actions", 0) or 0)
            action = "end_turn_with_actions" if unused > 0 else "end_turn"
        else:
            action = "rejected" if dtype == "play_card" else dtype

        for skill_id in offer.get("playable_skill_ids") or []:
            skill_id = str(skill_id)
            if dtype == "play_card" and chosen_skill == skill_id:
                table[skill_id]["chosen"] += 1
            else:
                table[skill_id][action] += 1

        for ult_id in offer.get("ready_ultimate_skills") or []:
            ult_id = str(ult_id)
            if dtype == "cast_ultimate" and chosen_ult == ult_id:
                table[ult_id]["chosen"] += 1
            else:
                table[ult_id]["held:" + action] += 1

    return {key: dict(counter) for key, counter in table.items()}
#endregion



#region Winning vs losing matches, with the de-biased lift
def match_presence(decisions: list[dict], runs: dict[str, dict]) -> dict:
    """How often each skill / card tier / Ultimate appeared in a win or a loss.

    Both views are needed: `presence` says "this showed up in X% of winning matches
    and Y% of losing ones", while `lift` subtracts the win rate of the exact
    advantage stratum the play happened in, so a win-more card does not look
    overpowered (the Madness trap).

    The subtraction is averaged over *plays*, never over strata, because that is what
    `v_win_loss_presence` in Server/supabase/migrations/002_analytics_views.sql computes
    (`avg(win - baseline)`) and the hosted dashboard and this report have to agree. It
    also keeps a rare stratum from carrying half the answer: a card played 99 times in an
    even fight and once while already winning should not read as a 50/50 blend.
    """
    kinds = ("skill", "ultimate", "card")
    played_matches = {"skill": 0, "ultimate": 0, "card": 0}
    lost_matches = {"skill": 0, "ultimate": 0, "card": 0}
    for run in runs.values():
        if run["abandoned"]:
            continue
        bucket = played_matches if run["victory"] else lost_matches
        for kind in kinds:
            bucket[kind] += 1

    match_ids: dict[str, dict[str, set]] = {k: defaultdict(set) for k in kinds}
    total: dict[str, Counter] = {k: Counter() for k in kinds}
    wins: dict[str, Counter] = {k: Counter() for k in kinds}
    stratum_wins: Counter = Counter()
    stratum_total: Counter = Counter()
    entry_wins: dict[str, dict[str, Counter]] = {k: defaultdict(Counter) for k in kinds}
    entry_total: dict[str, dict[str, Counter]] = {k: defaultdict(Counter) for k in kinds}

    for decision in decisions:
        run_id = str(decision.get("run_id", ""))
        run = runs.get(run_id)
        if run is None or run["abandoned"]:
            continue
        chosen = decision.get("chosen") or {}
        if not bool(chosen.get("applied", False)):
            continue
        dtype = str(decision.get("decision_type", ""))
        if dtype == "play_card":
            labels = [("skill", str(chosen.get("skill_id", "")) or "unknown"),
                      ("card", str((chosen.get("card") or {}).get("key", "")) or "unknown")]
        elif dtype == "cast_ultimate":
            labels = [("ultimate", str(chosen.get("ultimate_skill_id", "")) or "unknown")]
        else:
            continue

        stratum = stratum_of((decision.get("context") or {}).get("metrics") or {})
        won = 1 if run["victory"] else 0
        stratum_wins[stratum] += won
        stratum_total[stratum] += 1

        for kind, label in labels:
            total[kind][label] += 1
            wins[kind][label] += won
            entry_wins[kind][label][stratum] += won
            entry_total[kind][label][stratum] += 1
            match_ids[kind][label].add(run_id)

    rows: dict[str, dict] = {}
    for kind in kinds:
        for label, count in total[kind].items():
            lift = 0.0
            for stratum, sub in entry_total[kind][label].items():
                if sub <= 0:
                    continue
                baseline = stratum_wins[stratum] / stratum_total[stratum]
                # Weighted by the plays in that stratum, so `lift / count` is the mean
                # over plays - the same number v_win_loss_presence reports.
                lift += ((entry_wins[kind][label][stratum] / sub) - baseline) * sub
            ids = match_ids[kind][label]
            won_ids = sum(1 for rid in ids if rid in runs and runs[rid]["victory"] and not runs[rid]["abandoned"])
            lost_ids = sum(1 for rid in ids if rid in runs and not runs[rid]["victory"] and not runs[rid]["abandoned"])
            rows[kind + ":" + label] = {
                "casts": count,
                "raw_win_rate": (wins[kind][label] / count) if count else 0.0,
                "advantage_adjusted_lift": (lift / count) if count else 0.0,
                "matches": len(ids),
                "in_wins": won_ids,
                "in_losses": lost_ids,
                "pct_of_wins": (won_ids / played_matches[kind]) if played_matches[kind] else 0.0,
                "pct_of_losses": (lost_ids / lost_matches[kind]) if lost_matches[kind] else 0.0,
            }
    baselines = {s: (stratum_wins[s] / stratum_total[s]) for s in stratum_total}
    return {
        "rows": rows,
        "baselines": baselines,
        "win_matches": played_matches,
        "loss_matches": lost_matches,
    }
#endregion



#region Enemy strategy and situational damage
def enemy_strategy(decisions: list[dict]) -> dict:
    """What the player does against a specific enemy, and under threat.

    `by_enemy` keys on the enemy line-up the player was facing (`"boss_enemy"`,
    `"normal_enemy+normal_enemy"`); `by_threat` buckets the same action mix by
    whether a rolled intent was heavy (condition met / Ultimate imminent).
    """
    def new_mix() -> dict:
        return {"decisions": 0, "actions": Counter(), "skills": Counter(), "ultimates": Counter()}

    by_enemy: dict[str, dict] = defaultdict(new_mix)
    by_threat: dict[str, dict] = defaultdict(new_mix)
    for decision in decisions:
        offer = decision.get("offered") or {}
        chosen = decision.get("chosen") or {}
        dtype = str(decision.get("decision_type", ""))
        enemies = [str(e) for e in offer.get("active_enemy_ids") or []]
        keys = ["+".join(sorted(enemies)) if enemies else "none"]
        if bool(offer.get("intent_condition_met", False)):
            keys.append("threat:condition_met")
        if bool(offer.get("intent_ultimate_imminent", False)):
            keys.append("threat:ultimate_imminent")
        if int(offer.get("intent_max_roll", 0) or 0) >= 6:
            keys.append("threat:high_roll")

        for key in keys:
            for bucket in (by_enemy, by_threat):
                entry = bucket[key]
                entry["decisions"] += 1
                entry["actions"][dtype] += 1
                skill_id = str(chosen.get("skill_id", ""))
                if dtype == "play_card" and skill_id:
                    entry["skills"][skill_id] += 1
                ult_id = str(chosen.get("ultimate_skill_id", ""))
                if dtype == "cast_ultimate" and ult_id:
                    entry["ultimates"][ult_id] += 1

    def flatten(bucket: dict) -> dict:
        rows: dict[str, dict] = {}
        for key, entry in bucket.items():
            decisions_count = entry["decisions"] or 1
            rows[key] = {
                "decisions": entry["decisions"],
                "action_mix": {k: v / decisions_count for k, v in entry["actions"].items()},
                "action_counts": dict(entry["actions"]),
                "skills": dict(entry["skills"]),
                "ultimates": dict(entry["ultimates"]),
            }
        return rows

    return {"by_enemy": flatten(by_enemy), "by_threat": flatten(by_threat)}


def situational_damage(events: list[dict]) -> dict:
    """HP the player lost to a specific enemy skill, and by player strategy.

    Built from each turn's `enemy_damage_events`, which the recorder tags with the
    enemy and the skill that dealt the hit (enemies act in the enemy turn, not
    during a player decision), plus `player_skills_used` for the same turn.
    """
    by_enemy_skill: dict[tuple[str, str], dict] = {}
    by_strategy: dict[tuple[str, str], dict] = {}
    for event in events:
        if event.get("type") != "turn_ended":
            continue
        outcome = event.get("outcome") or {}
        rows = outcome.get("enemy_damage_events") or []
        if not rows:
            continue
        player_skills = [str(s) for s in outcome.get("player_skills_used") or []]
        strategy = "+".join(sorted(set(player_skills))) if player_skills else "no_skill"
        for row in rows:
            enemy = str(row.get("enemy_unit_id", "")) or "unknown"
            enemy_skill = str(row.get("enemy_skill_id", "")) or "unknown"
            hp_lost = int(row.get("hp_lost", 0) or 0)
            damage = int(row.get("damage", 0) or 0)
            entry = by_enemy_skill.setdefault((enemy, enemy_skill),
                                              {"hits": 0, "hp_lost": 0, "damage": 0})
            entry["hits"] += 1
            entry["hp_lost"] += hp_lost
            entry["damage"] += damage
            entry = by_strategy.setdefault((strategy, enemy), {"hits": 0, "hp_lost": 0})
            entry["hits"] += 1
            entry["hp_lost"] += hp_lost
    return {"by_enemy_skill": by_enemy_skill, "by_strategy": by_strategy}


def roster_coverage(decisions: list[dict], runs: dict[str, dict]) -> dict:
    """Which allies were actually used, per run and in total.

    A run that never casts a given ally's skills is the strongest single signal
    that a kit is unattractive, unreadable or simply not worth a slot - and it is
    invisible in a win rate.
    """
    casts: Counter = Counter()
    runs_used: dict[str, set] = defaultdict(set)
    for decision in decisions:
        chosen = decision.get("chosen") or {}
        if not bool(chosen.get("applied", False)):
            continue
        ally = str(chosen.get("target_ally_id") or chosen.get("caster_id") or "")
        if not ally:
            continue
        casts[ally] += 1
        runs_used[ally].add(str(decision.get("run_id", "")))

    offered_runs: Counter = Counter()
    used_runs: Counter = Counter()
    idle_runs: list[str] = []
    counted = 0
    for run_id, run in runs.items():
        # Abandoned runs contain no real play, so they would only add noise.
        if run["abandoned"]:
            continue
        counted += 1
        used_here: set = set()
        for ally in run.get("ally_lineup") or []:
            offered_runs[ally] += 1
            if run_id in runs_used.get(ally, set()):
                used_runs[ally] += 1
                used_here.add(ally)
        if not used_here:
            idle_runs.append(run_id)

    rows: dict[str, dict] = {}
    for ally, offered in offered_runs.items():
        used = used_runs[ally]
        rows[ally] = {
            "runs_in_lineup": offered,
            "runs_used": used,
            "casts": casts.get(ally, 0),
            "coverage": (used / offered) if offered else 0.0,
        }
    return {
        "allies": rows,
        "runs_counted": counted,
        "runs_with_no_ally_used": len(idle_runs),
    }


def wasted_resources(decisions: list[dict], events: list[dict]) -> dict:
    """Turns that ended with actions or merges unused, and whether skills were
    still playable at that moment.

    Ending a turn with actions unspent while a skill was available is either a
    player who disengaged or an affordance the UI failed to make legible. Both are
    worth knowing, and neither shows up in a win rate.
    """
    end_turns: dict[tuple, dict] = {}
    for decision in decisions:
        if decision.get("decision_type") == "end_turn":
            key = (str(decision.get("run_id", "")), int(decision.get("turn_number", -1)))
            end_turns[key] = decision

    summary = {
        "turns": 0,
        "unused_actions": 0,
        "unused_merges": 0,
        "turns_with_unused": 0,
        "turns_with_playable_ignored": 0,
        "converts": 0,
    }
    for event in events:
        if event.get("type") != "turn_ended":
            continue
        summary["turns"] += 1
        unused_actions = int(event.get("unused_actions", 0) or 0)
        unused_merges = int(event.get("unused_merges", 0) or 0)
        summary["unused_actions"] += unused_actions
        summary["unused_merges"] += unused_merges
        if unused_actions > 0 or unused_merges > 0:
            summary["turns_with_unused"] += 1
        key = (str(event.get("run_id", "")), int(event.get("turn_number", -1)))
        decision = end_turns.get(key)
        if decision is None or unused_actions <= 0:
            continue
        playable = (decision.get("offered") or {}).get("playable_skill_ids") or []
        if playable:
            summary["turns_with_playable_ignored"] += 1
    summary["converts"] = sum(
        1 for decision in decisions if decision.get("decision_type") == "convert_action"
    )
    return summary


def cohort_pick_rates(
    decisions: list[dict],
    runs: dict[str, dict],
    new_play_threshold: int = 3,
) -> dict[str, dict]:
    """Pick rates split by player experience.

    A beginner and a veteran value a setup/support kit completely differently, so
    pooling them hides the answer to "is this kit weak, or merely undiscovered?".
    Runs of unknown number are treated as new, which cannot flatter a kit.
    """
    buckets: dict[str, dict[str, Counter]] = {
        "new": {"offered": Counter(), "picked": Counter()},
        "veteran": {"offered": Counter(), "picked": Counter()},
    }
    for decision in decisions:
        run = runs.get(str(decision.get("run_id", "")))
        if run is None or run["abandoned"]:
            continue
        number = int(run.get("player_run_number", 0) or 0)
        bucket = "veteran" if number > new_play_threshold else "new"
        offer = decision.get("offered") or {}
        chosen = decision.get("chosen") or {}
        applied = bool(chosen.get("applied", False))
        for skill_id in offer.get("playable_skill_ids") or []:
            buckets[bucket]["offered"][str(skill_id)] += 1
        if applied and decision.get("decision_type") == "play_card":
            skill_id = str(chosen.get("skill_id", ""))
            if skill_id:
                buckets[bucket]["picked"][skill_id] += 1
        elif applied and decision.get("decision_type") == "cast_ultimate":
            ult_id = str(chosen.get("ultimate_skill_id", ""))
            if ult_id:
                buckets[bucket]["picked"][ult_id] += 1

    rows: dict[str, dict] = {}
    for bucket, counters in buckets.items():
        for skill_id, offered in counters["offered"].items():
            picked = counters["picked"].get(skill_id, 0)
            rows["%s:%s" % (bucket, skill_id)] = {
                "offered": offered,
                "picked": picked,
                "pick_rate": (picked / offered) if offered else 0.0,
            }
    return rows


def defeat_causes(runs: dict[str, dict]) -> dict:
    """What ended the lost runs, plus every ally death with its cause."""
    def label(cause: dict) -> str:
        kind = str(cause.get("kind", "unknown"))
        if kind == "enemy_skill":
            return "%s / %s" % (
                cause.get("source_unit_id", "") or "?",
                cause.get("source_skill_id", "") or "?",
            )
        if kind == "status":
            return "status: %s" % (cause.get("status_id", "") or "?")
        return "unknown"

    killed_by: Counter = Counter()
    ally_deaths: Counter = Counter()
    for run in runs.values():
        if run["abandoned"]:
            continue
        cause = run.get("killed_by") or {}
        if not run["victory"] and cause:
            killed_by[label(cause)] += 1
        for death in run.get("ally_deaths") or []:
            ally_deaths[label(death)] += 1
    return {"killed_by": killed_by, "ally_deaths": ally_deaths}


def flag_cohorts(runs: dict[str, dict]) -> dict[str, dict]:
    """Win rate with each staged flag on, next to runs on the *same* balance patch.

    Keyed by `flag|balance_hash` on purpose: pooling every run into one control group
    would compare the flag-on runs of a new patch against the flag-off runs of the old
    one, and read a balance change as a flag effect (Simpson's paradox). Both sides of
    a row are therefore always the same patch.
    """
    cohorts: dict[str, dict] = {}
    for run in runs.values():
        if run["abandoned"]:
            continue
        balance = str(run.get("balance_hash", ""))
        for flag in run.get("flags") or []:
            key = "%s|%s" % (flag, balance)
            row = cohorts.setdefault(key, {
                "flag": flag,
                "balance": balance,
                "on": 0,
                "on_wins": 0,
                "off": 0,
                "off_wins": 0,
            })
            row["on"] += 1
            row["on_wins"] += 1 if run["victory"] else 0
    for row in cohorts.values():
        for run in runs.values():
            if run["abandoned"] or str(run.get("balance_hash", "")) != row["balance"]:
                continue
            if row["flag"] in (run.get("flags") or []):
                continue
            row["off"] += 1
            row["off_wins"] += 1 if run["victory"] else 0
    return cohorts

#endregion



#region Report
def _pct(value: float) -> str:
    return "%5.1f%%" % (value * 100.0)


def _bar(value: int, scale: int) -> str:
    if scale <= 0:
        return ""
    return "#" * max(0, min(28, int(round(value / scale * 28))))


def report(events, runs, picks, instead, presence, strategy, damage, paths,
           coverage=None, waste=None, cohorts=None, deaths=None, excluded=None) -> str:
    lines: list[str] = []
    add = lines.append
    # Everything the header reports must describe the same set the sections do, or
    # `--production-only` would claim "1 finished run" above empty tables.
    visible_ids: set = {str(event.get("run_id", "")) for event in events}
    visible = {rid: run for rid, run in runs.items() if rid in visible_ids}
    finished = {rid: run for rid, run in visible.items() if not run["abandoned"]}
    abandoned = [run for run in visible.values() if run["abandoned"]]
    victories = sum(1 for run in finished.values() if run["victory"])
    decisions = [e for e in events if e.get("type") == "decision"]

    add("=== TELEMETRY BALANCE REPORT ===")
    add("spool:      " + ", ".join(str(p) for p in paths))
    add("events:     %d" % len(events))
    add("runs:       %d finished (victories %d, win rate %s) + %d abandoned"
        % (len(finished), victories,
           _pct(victories / len(finished)) if finished else "  0.0%", len(abandoned)))
    add("decisions:  %d" % len(decisions))
    # Named explicitly so a filtered number is never mistaken for the whole spool.
    if excluded:
        tainted = sum(1 for run in excluded.values() if run["tainted"])
        dev_builds = sum(1 for run in excluded.values() if run["dev_build"])
        add("excluded:   %d run(s) (debug-tainted %d, developer build %d)"
            % (len(excluded), tainted, dev_builds))

    add("")
    add("-- Run outcomes --")
    reasons: Counter = Counter(run["end_reason"] for run in runs.values())
    for reason, count in reasons.most_common():
        add("  %-24s %d" % (reason or "unknown", count))
    if abandoned:
        waves: Counter = Counter("wave %d" % run["final_wave"] for run in abandoned)
        add("  abandoned at: " + ", ".join("%s x%d" % kv for kv in waves.most_common()))
    hashes: Counter = Counter(run["balance_hash"][:12] for run in visible.values())
    for digest, count in hashes.most_common():
        add("  balance %s  %d run(s)" % (digest or "-", count))

    add("")
    add("-- 1. Pick rate (picked when offered) --")
    add("  %-26s %7s %7s %9s" % ("skill", "offered", "picked", "pick rate"))
    for key, row in sorted(picks["skills"].items(),
                           key=lambda kv: (-kv[1]["offered"], kv[0])):
        add("  %-26s %7d %7d %9s" % (key, row["offered"], row["picked"], _pct(row["pick_rate"])))
    add("  %-26s %7s %7s %9s" % ("Ultimate", "offered", "cast", "cast rate"))
    for key, row in sorted(picks["ultimates"].items(),
                           key=lambda kv: (-kv[1]["offered"], kv[0])):
        add("  %-26s %7d %7d %9s" % (key, row["offered"], row["picked"], _pct(row["pick_rate"])))
    add("  %-26s %7s %7s %9s" % ("card (in hand)", "offered", "played", "play rate"))
    for key, row in sorted(picks["cards"].items(),
                           key=lambda kv: (-kv[1]["offered"], kv[0])):
        merged = picks["card_merged_as_input"].get(key, 0)
        add("  %-26s %7d %7d %9s   merged %d" % (
            key, row["offered"], row["picked"], _pct(row["pick_rate"]), merged))

    add("")
    add("-- 1b. Prompt pick rates (inside a skill) --")
    targets = picks["targets"]
    if targets["prompts"]:
        add("  target prompts: %d" % targets["prompts"])
        for key, count in sorted(targets["candidates"].items(), key=lambda kv: -kv[1]):
            taken = targets["picked"].get(key, 0)
            rate = (taken / count) if count else 0.0
            add("    %-24s offered %4d  picked %4d  %s" % (key, count, taken, _pct(rate)))
    cards = picks["card_prompts"]
    if cards["prompts"]:
        add("  card prompts: %d" % cards["prompts"])
        for key, count in sorted(cards["candidates"].items(), key=lambda kv: -kv[1]):
            taken = cards["picked"].get(key, 0)
            rate = (taken / count) if count else 0.0
            add("    %-24s offered %4d  picked %4d  %s" % (key, count, taken, _pct(rate)))

    add("")
    add("-- 2. What players chose instead --")
    for key, replies in sorted(instead.items()):
        chosen = replies.get("chosen", 0)
        passed = sum(v for k, v in replies.items() if k != "chosen")
        if passed <= 0:
            continue
        add("  %s  (taken %d, passed over %d)" % (key, chosen, passed))
        for label, count in sorted(replies.items(), key=lambda kv: -kv[1]):
            if label == "chosen":
                continue
            add("      %-26s %4d  %s" % (label, count, _pct(count / passed)))

    add("")
    add("-- 3. Winning vs losing matches --")
    add("  %-26s %6s %8s %9s %9s %9s" % (
        "choice", "casts", "raw win", "adj lift", "in wins", "in losses"))
    for key, row in sorted(presence["rows"].items(), key=lambda kv: -kv[1]["casts"]):
        add("  %-26s %6d %8s %9s %9s %9s" % (
            key, row["casts"], _pct(row["raw_win_rate"]),
            "%+7.1f%%" % (row["advantage_adjusted_lift"] * 100.0),
            _pct(row["pct_of_wins"]), _pct(row["pct_of_losses"])))
    if presence["baselines"]:
        add("  stratum baselines: " + "  ".join(
            "%s %s" % (name, _pct(value))
            for name, value in sorted(presence["baselines"].items())))
    add("  (%d winning matches, %d losing matches)" % (
        presence["win_matches"]["skill"], presence["loss_matches"]["skill"]))

    add("")
    add("-- 4. Strategy against specific enemies --")
    for key, row in sorted(strategy["by_enemy"].items(), key=lambda kv: -kv[1]["decisions"]):
        add("  facing %s  (%d decisions)" % (key, row["decisions"]))
        for action, count in sorted(row["action_counts"].items(), key=lambda kv: -kv[1]):
            share = row["action_mix"].get(action, 0.0)
            add("      %-20s %4d  %s  %s" % (action, count, _pct(share), _bar(count, row["decisions"])))
        if row["skills"]:
            top = sorted(row["skills"].items(), key=lambda kv: -kv[1])[:4]
            add("      top skills: " + ", ".join("%s x%d" % kv for kv in top))
        if row["ultimates"]:
            top = sorted(row["ultimates"].items(), key=lambda kv: -kv[1])[:4]
            add("      ultimates:  " + ", ".join("%s x%d" % kv for kv in top))
    for key, row in sorted(strategy["by_threat"].items(), key=lambda kv: -kv[1]["decisions"]):
        if not key.startswith("threat:"):
            continue
        add("  under %s  (%d decisions)  actions: %s" % (
            key, row["decisions"],
            ", ".join("%s %s" % (a, _pct(s)) for a, s in sorted(row["action_mix"].items()))))
        if row["skills"]:
            top = sorted(row["skills"].items(), key=lambda kv: -kv[1])[:4]
            add("      top skills: " + ", ".join("%s x%d" % kv for kv in top))

    add("")
    add("-- 5. Situational damage taken --")
    add("  %-22s %-22s %5s %9s %8s" % ("enemy", "enemy skill", "hits", "hp_lost", "avg"))
    for (enemy, skill), row in sorted(damage["by_enemy_skill"].items(),
                                      key=lambda kv: -kv[1]["hp_lost"]):
        avg = row["hp_lost"] / row["hits"] if row["hits"] else 0.0
        add("  %-22s %-22s %5d %9d %8.1f" % (enemy, skill, row["hits"], row["hp_lost"], avg))
    add("  %-22s %-22s %5s %9s %8s" % ("player strategy", "enemy", "hits", "hp_lost", "avg"))
    for (strategy_name, enemy), row in sorted(damage["by_strategy"].items(),
                                              key=lambda kv: -kv[1]["hp_lost"]):
        avg = row["hp_lost"] / row["hits"] if row["hits"] else 0.0
        add("  %-22s %-22s %5d %9d %8.1f" % (
            strategy_name, enemy, row["hits"], row["hp_lost"], avg))

    add("")
    add("-- 6. Roster coverage (was each ally ever used?) --")
    if coverage and coverage["allies"]:
        add("  %-14s %12s %9s %7s %9s" % ("ally", "runs in kit", "runs used", "casts", "coverage"))
        for ally, row in sorted(coverage["allies"].items(),
                                key=lambda kv: kv[1]["coverage"]):
            add("  %-14s %12d %9d %7d %9s" % (
                ally, row["runs_in_lineup"], row["runs_used"], row["casts"],
                _pct(row["coverage"])))
        add("  %d finished runs counted; %d of them used no ally at all"
            % (coverage["runs_counted"], coverage["runs_with_no_ally_used"]))
    else:
        add("  (no finished runs to measure)")

    add("")
    add("-- 7. Wasted resources --")
    if waste and waste["turns"]:
        add("  turns recorded:              %d" % waste["turns"])
        add("  actions left unspent:        %d" % waste["unused_actions"])
        add("  merges left unspent:         %d" % waste["unused_merges"])
        add("  turns ending with leftovers: %d" % waste["turns_with_unused"])
        add("  ...of those, skills were still playable: %d"
            % waste["turns_with_playable_ignored"])
        add("  convert actions taken:       %d" % waste["converts"])
    else:
        add("  (no turns recorded)")

    add("")
    add("-- 8. Pick rate by player experience --")
    if cohorts:
        add("  %-26s %8s %7s %10s" % ("cohort:skill", "offered", "picked", "pick rate"))
        for key, row in sorted(cohorts.items(), key=lambda kv: (-kv[1]["offered"], kv[0])):
            if row["offered"] <= 0:
                continue
            add("  %-26s %8d %7d %10s" % (
                key, row["offered"], row["picked"], _pct(row["pick_rate"])))
        add("  ('new' = first 3 runs by that player; 'veteran' = run 4 onward)")
    else:
        add("  (no run numbers recorded)")

    add("")
    add("-- 9. What ended the lost runs / killed allies --")
    if deaths and (deaths["killed_by"] or deaths["ally_deaths"]):
        for cause, count in deaths["killed_by"].most_common():
            add("  killed the run:  %-30s %d" % (cause, count))
        for cause, count in deaths["ally_deaths"].most_common():
            add("  killed an ally:  %-30s %d" % (cause, count))
    else:
        add("  (no defeats and no ally deaths recorded)")

    seeds = [run.get("run_seed") for run in visible.values()
             if run.get("run_seed") is not None and not run["abandoned"]]
    if seeds:
        add("")
        add("-- 10. Replayable seeds (load one to reproduce a battle exactly) --")
        add("  " + ", ".join(str(seed) for seed in seeds))

    # Computed from the runs this report is actually describing, so a dev build or
    # an abandoned run cannot land in a cohort number.
    flags = flag_cohorts(finished)
    if flags:
        add("")
        add("-- 11. Staged feature flags (win rate on vs off, same balance patch) --")
        for _key, row in sorted(flags.items()):
            on_rate = _pct(row["on_wins"] / row["on"]) if row["on"] else "  0.0%"
            off_rate = _pct(row["off_wins"] / row["off"]) if row["off"] else "  0.0%"
            add("  %-26s %-12s on %4d run(s) win %s  off %4d run(s) win %s" % (
                row["flag"], row["balance"][:12] or "-", row["on"], on_rate,
                row["off"], off_rate))

    return "\n".join(lines)
#endregion


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Local telemetry balance report.")
    parser.add_argument("paths", nargs="*", help="spool directories or .jsonl files")
    parser.add_argument("--include-debug", action="store_true",
                        help="include runs touched by the tester debug tools")
    parser.add_argument("--production-only", action="store_true",
                        help="exclude developer-build runs (editor playtests)")
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
    clean = keep_clean(events, runs, args.include_debug, args.production_only)
    # One filtered set feeds every section *and* the JSON export. Passing the raw
    # `runs` to one of them is how a developer playtest ends up in a balance number.
    visible_ids: set = {str(event.get("run_id", "")) for event in clean}
    clean_runs = {run_id: run for run_id, run in runs.items() if run_id in visible_ids}
    excluded = {run_id: run for run_id, run in runs.items() if run_id not in visible_ids}
    decisions = [e for e in clean if e.get("type") == "decision"]
    picks = offer_and_pick(decisions)
    instead = substitution(decisions)
    presence = match_presence(decisions, clean_runs)
    strategy = enemy_strategy(decisions)
    damage = situational_damage(clean)
    coverage = roster_coverage(decisions, clean_runs)
    waste = wasted_resources(decisions, clean)
    cohorts = cohort_pick_rates(decisions, clean_runs)
    deaths = defeat_causes(clean_runs)

    print(report(clean, clean_runs, picks, instead, presence, strategy, damage, paths,
                 coverage, waste, cohorts, deaths, excluded))

    if args.json_out:
        payload = {
            "runs": clean_runs,
            "pick_rates": picks,
            "chose_instead": instead,
            "win_loss": presence["rows"],
            "stratum_baselines": presence["baselines"],
            "enemy_strategy": strategy,
            "roster_coverage": coverage,
            "wasted_resources": waste,
            "cohort_pick_rates": cohorts,
            "flag_cohorts": flag_cohorts(clean_runs),
            "defeat_causes": {
                "killed_by": dict(deaths["killed_by"]),
                "ally_deaths": dict(deaths["ally_deaths"]),
            },
            "situational_damage": {
                "by_enemy_skill": {"%s|%s" % k: v for k, v in damage["by_enemy_skill"].items()},
                "by_strategy": {"%s|%s" % k: v for k, v in damage["by_strategy"].items()},
            },
        }
        Path(args.json_out).write_text(json.dumps(payload, indent=2), encoding="utf-8")
        print("\nWrote " + args.json_out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

