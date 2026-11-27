# Telemetry — metric server

Human-centric gameplay analytics for *Hololive: The Prophecy*, in the spirit of
Mega Crit's Slay the Spire metric server: collect what **real players** decide,
not what a bot would, so balancing reflects human behaviour while still being
immune to selection bias (the "Madness" trap below).

## The four questions this answers

1. **Pick rate** — when a player is offered a choice (a hand, a merge, a ready
   Ultimate), what do they actually pick? Every decision event carries the full
   *offered* set — the skills that were legally castable, the cards in hand, the
   ready Ultimates — so the denominator is real: `picked / offered`.
2. **What players chose instead** — the opportunity cost. For every offer that was
   passed over, what did they do: attack with another skill, merge, convert an
   action, hold the Ultimate, or end the turn with actions left?
3. **Winning vs losing matches, de-biased** — how often each skill / Ultimate /
   card tier appeared in a *win* and in a *loss*, next to an
   **advantage-adjusted lift**. Each decision is bucketed by the board state
   *before* it happened (`winning` / `even` / `desperate`), and the lift subtracts
   that bucket's baseline win rate. A play that only ever shows up in
   already-winning games scores near zero instead of looking overpowered — the
   exact trap that made *Madness* look broken in Slay the Spire.
4. **Strategy against specific enemies** — what players do while facing a given
   enemy and under a threatening intent (action mix, preferred skills, focus
   fire), and how much HP that enemy's skill actually takes off them, joined with
   the strategy used that turn.

## Two stages

### Stage 1 — local spool + offline report (works today)

The game writes every event to a per-run JSONL file under
`user://telemetry/spool/` (`Core/Telemetry/JsonlFileSink.gd`). Nothing leaves the
machine, and each line is flushed as it is written, so a crash loses at most the
event being written.

```powershell
# auto-detects the Godot user:// spool, or pass a directory of *.jsonl files
python Tools/analyze_telemetry.py
python Tools/analyze_telemetry.py path\to\spool --json report.json
python Tools/analyze_telemetry.py --include-debug   # include tainted runs
```

The report prints run outcomes (including abandoned runs), true pick rates for
skills / Ultimates / cards, the prompt pick rates, the "chose instead" table, the
win/loss presence + de-biased lift table, the enemy strategy breakdown, the
situational damage matrix, plus:

- **Roster coverage** — was each ally ever used at all? (healer and buff sat at
  **0%** in the first real session while striker was used in every run)
- **Wasted resources** — turns ended with actions unspent while skills were still
  playable, and how often `convert` was used at all
- **Experience cohorts** — the same pick rates for a player's first 3 runs vs run 4
  onward, which separates "this kit is weak" from "nobody has found it yet"
- **Defeat causes** — which enemy skill or status actually killed an ally / ended
  the run
- **Replayable seeds** — every run records its `run_seed`, so a flagged outlier
  can be reloaded and reproduced exactly

Standard library only.

```powershell
python Tools/analyze_telemetry.py --production-only   # real players only
```

`--production-only` drops developer-build runs (`is_debug_build`), which is the
default the hosted views use: an editor playtest must never land in a player
balance number.

### Stage 2 — hosted ingest (Supabase / PostgreSQL)

```
Server/supabase/
  migrations/001_telemetry_tables.sql    # tables + indexes + RLS
  migrations/002_analytics_views.sql     # v_skill_pick_rates, v_ultimate_rates,
                                         # v_card_rates, v_chose_instead,
                                         # v_win_loss_presence, v_enemy_strategy,
                                         # v_situational_matchup, v_target_priority,
                                         # v_roster_coverage, v_wasted_resources,
                                         # v_cohort_pick_rates, v_defeat_causes,
                                         # v_replayable_runs, v_run_overview
  migrations/003_run_flags.sql           # telemetry_runs.flags + v_flag_cohorts
  functions/telemetry-ingest/index.ts    # validated, idempotent batch ingest
```

`telemetry_runs.flags` holds the staged flags that were ON for a run (see
`Core/FeatureFlags.gd` and `Data/json/features.json`), and `v_flag_cohorts` reports
each flag's win rate next to the runs that never had it — so an experiment is read
before it is rolled out to everyone. Flags do not enter `balance_hash`: they are
recorded per run, so raising a rollout does not re-partition earlier balance data.

Every view is **production only**: runs from a developer build or touched by a
tester tool are excluded.

Deploy:

```powershell
cd Server
supabase link --project-ref <ref>
supabase db push                                     # applies both migrations
supabase functions deploy telemetry-ingest
supabase functions deploy telemetry-ingest --no-verify-jwt   # if you gate client-side
```

Point the client at it by setting the project settings `telemetry/endpoint` and
`telemetry/anon_key` (the `[telemetry]` section of `project.godot`). With an
endpoint set, runs spool into `user://telemetry/outbox/` via
`Core/Telemetry/HttpBatchSink.gd` and `Managers/TelemetryUploader.gd` drains
them in background batches; with no endpoint the game stays entirely local.
Connect Metabase / Grafana / Supabase Studio straight to the views above.

## Privacy

- Collection is **opt-in only**. Every launch shows
  `Scenes/HUD/TelemetryConsentPopup.gd` before the first battle; nothing is
  recorded — no run id, no player id, no file, no request — until the player
  presses **Allow**. "Play Again" (a scene reload in the same launch) is not asked
  again.
- The answer is recorded in `user://telemetry_consent.json` and re-read when a
  battle starts, so the answer given this launch is the one that applies.
  `TelemetryConsent.CONSENT_VERSION` marks which disclosure wording the stored
  answer belongs to.
- The only identifier is a random local UUID in `user://telemetry/player_id.txt`.
  No name, email, account, IP address or device identifier is ever collected.
- Headless runs never collect, and any run touched by the tester debug tools is
  flagged `was_debug_tainted` and excluded from every balance view by default.
- A run the player restarts or quits mid-battle is closed as `abandoned` and
  reported separately, so quitting does not look like a loss.

## Event schema (v1)

`Core/Telemetry/TelemetrySchema.gd` is the single source of truth for the shape.
Every event carries: `type`, `schema_version`, `event_id`, `run_id`,
`player_anon_id`, `balance_hash`, `t`.

| type           | carries                                                                    |
| -------------- | -------------------------------------------------------------------------- |
| `run_started`  | game/balance version, **run seed**, player run number, ally lineup, decklist, config |
| `wave_started` | wave index, enemy and ally snapshots                                       |
| `turn_started` | dice, intents, hand, board, battlefield metrics, **active enemy ids**       |
| `decision`     | decision type, thinking time, before-context, **offered** (playable skills,
|                | in-hand card keys, ready Ultimates, legal merges, active enemies), **chosen**, outcome |
| `turn_ended`   | unused actions/merges, board, the turn's strategy (skills / Ultimates used,
|                | merges, converts) and **enemy damage rows tagged with the enemy + skill**, plus
|                | directional totals (`ally_hp_lost` / `enemy_hp_lost`)                       |
| `run_ended`    | victory, `abandoned`, end reason, final wave, survivors, `was_debug_tainted`,
|                | **`killed_by`** and every ally death with its cause                         |

Ids are always stable (`unit_id` / `skill_id`), never display names, so renaming
or localising content cannot break a historical metric. `balance_hash` is a
SHA-256 of the five JSON data files, so metrics split per balance patch with no
manual version bump.

