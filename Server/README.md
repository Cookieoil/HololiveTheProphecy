# Telemetry — metric server

Human-centric gameplay analytics for *Hololive: The Prophecy*, in the spirit of
Mega Crit's Slay the Spire metric server: collect what **real players** decide,
not what a bot would, so balancing reflects human behaviour while still being
immune to selection bias (the "Madness" trap below).

## The three questions this answers

1. **Pick rate** — when a player is offered a choice (a hand, a merge, a ready
   Ultimate), what do they actually pick? Every decision event carries the full
   *offered* set, so the denominator is real.
2. **Win-rate correlation, de-biased** — raw win rate is reported next to an
   **advantage-adjusted lift**. Each decision is bucketed by the board state
   *before* it happened (`winning` / `even` / `desperate`), and the lift subtracts
   that bucket's baseline win rate. A play that only ever shows up in
   already-winning games scores near zero instead of looking overpowered — the
   exact trap that made *Madness* look broken in Slay the Spire.
3. **Situational performance** — how much HP the player loses against a *specific
   enemy* while a *specific skill* is resolving, unnested from the damage rows
   each decision records.

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

The report prints run outcomes, applied pick rates, offered-alternative counts,
the de-biased win table and the situational damage matrix. Standard library only.

### Stage 2 — hosted ingest (Supabase / PostgreSQL)

```
Server/supabase/
  migrations/001_telemetry_tables.sql    # tables + indexes + RLS
  migrations/002_analytics_views.sql     # v_skill_pick_rates, v_debiased_win_correlation,
                                         # v_situational_matchup, v_run_overview
  functions/telemetry-ingest/index.ts    # validated, idempotent batch ingest
```

Deploy:

```powershell
cd Server
supabase link --project-ref <ref>
supabase db push                                     # applies both migrations
supabase functions deploy telemetry-ingest
supabase functions deploy telemetry-ingest --no-verify-jwt   # if you gate client-side
```

Point the client at it (Stage 2 `HttpBatchSink`, config keys
`telemetry_endpoint` / `telemetry_anon_key`) and it will drain the local
`outbox/` in batches. Connect Metabase / Grafana / Supabase Studio straight to the
views above.

## Privacy

- Collection is **opt-in only**. The first launch shows
  `Scenes/HUD/TelemetryConsentPopup.gd`; nothing is recorded — no run id, no
  player id, no file, no request — until the player presses **Agree**.
- The answer lives in `user://telemetry_consent.json` and can be re-asked by
  bumping `TelemetryConsent.CONSENT_VERSION`.
- The only identifier is a random local UUID in `user://telemetry/player_id.txt`.
  No name, email, account, IP address or device identifier is ever collected.
- Headless runs never collect, and any run touched by the tester debug tools is
  flagged `was_debug_tainted` and excluded from every balance view by default.

## Event schema (v1)

`Core/Telemetry/TelemetrySchema.gd` is the single source of truth for the shape.
Every event carries: `type`, `schema_version`, `event_id`, `run_id`,
`player_anon_id`, `balance_hash`, `t`.

| type           | carries                                                                    |
| -------------- | -------------------------------------------------------------------------- |
| `run_started`  | game/balance version, ally lineup, decklist, config                        |
| `wave_started` | wave index, enemy and ally snapshots                                       |
| `turn_started` | dice, intents, hand, board, battlefield metrics                            |
| `decision`     | decision type, thinking time, before-context, **offered**, **chosen**, outcome |
| `turn_ended`   | unused actions/merges, board, turn outcome totals                          |
| `run_ended`    | victory, end reason, final wave, survivors, `was_debug_tainted`             |

Ids are always stable (`unit_id` / `skill_id`), never display names, so renaming
or localising content cannot break a historical metric. `balance_hash` is a
SHA-256 of the five JSON data files, so metrics split per balance patch with no
manual version bump.
