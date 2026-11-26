-- Telemetry storage for Hololive: The Prophecy.
--
-- The client writes one JSON object per line (Core/Telemetry/JsonlFileSink.gd)
-- and Stage 2 uploads those events in batches. Hot, queryable dimensions are
-- promoted to real columns; the rich, verbose context (offered alternatives,
-- intents, damage rows) stays in JSONB so a new metric never needs a migration.
--
-- Idempotent by design: every event carries an `event_id` (UUIDv4) and every
-- insert is `ON CONFLICT DO NOTHING`, so a retried batch can never double count.
--
-- Apply with: supabase db push   (or psql -f 001_telemetry_tables.sql)

create extension if not exists "pgcrypto";

-- One row per balance fingerprint (GameDatabase.balance_hash).
create table if not exists balance_versions (
    balance_hash      text primary key,
    game_version      text,
    first_seen_at     timestamptz not null default now(),
    config_snapshot   jsonb
);

-- One row per battle (run).
create table if not exists telemetry_runs (
    run_id            uuid primary key,
    player_anon_id    uuid,
    balance_hash      text references balance_versions (balance_hash) on delete set null,
    game_version      text,
    is_debug_build    boolean not null default false,
    was_debug_tainted boolean not null default false,
    ally_lineup       text[] not null default '{}',
    starting_deck     jsonb,
    config_snapshot   jsonb,
    victory           boolean,
    end_reason        text,
    final_wave        int,
    total_turns       int,
    total_decisions   int,
    started_at        timestamptz,
    ended_at          timestamptz
);

create index if not exists telemetry_runs_balance_idx on telemetry_runs (balance_hash);
create index if not exists telemetry_runs_player_idx  on telemetry_runs (player_anon_id);
create index if not exists telemetry_runs_clean_idx   on telemetry_runs (was_debug_tainted, victory);

-- One row per turn.
create table if not exists telemetry_turns (
    run_id                  uuid not null references telemetry_runs (run_id) on delete cascade,
    turn_number             int  not null,
    wave_index              int,
    dice_sides              int,
    ally_hp_pct_start       real,
    enemy_hp_pct_start      real,
    incoming_intent_damage  int,
    threat_ratio            real,
    unused_actions          int,
    unused_merges           int,
    damage_dealt            int,
    hp_lost                 int,
    shield_blocked          int,
    intents_json            jsonb,
    hand_start_json         jsonb,
    primary key (run_id, turn_number)
);

-- The core human-decision table: one row per player choice, with the board state
-- *before* it (so a metric can be stratified by who was already winning).
create table if not exists telemetry_decisions (
    event_id            uuid primary key,
    run_id              uuid not null references telemetry_runs (run_id) on delete cascade,
    turn_number         int,
    wave_index          int,
    decision_index      int,
    decision_type       text not null,
    thinking_time_ms    int,
    actor_unit_id       text,
    skill_id            text,
    card_effective_value int,
    card_is_odd         boolean,
    card_merge_rank     smallint,
    ally_hp_pct_before  real,
    enemy_hp_pct_before real,
    threat_ratio_before real,
    offered_options     jsonb,   -- the full hand, legal merges, ready ultimates
    chosen_payload      jsonb,   -- what was picked and the skill it unlocked
    immediate_outcome   jsonb,   -- damage / heal / shield / kills / card changes
    recorded_at         timestamptz not null default now()
);

create index if not exists telemetry_decisions_run_idx    on telemetry_decisions (run_id, turn_number, decision_index);
create index if not exists telemetry_decisions_skill_idx  on telemetry_decisions (skill_id);
create index if not exists telemetry_decisions_type_idx   on telemetry_decisions (decision_type);
create index if not exists telemetry_decisions_actor_idx  on telemetry_decisions (actor_unit_id);

-- Locked down: the ingest function writes with the service role, players never
-- read each other's data.
alter table telemetry_runs        enable row level security;
alter table telemetry_turns       enable row level security;
alter table telemetry_decisions   enable row level security;
alter table balance_versions      enable row level security;
