-- Executes migrations 001-006 against a real PostgreSQL and asserts what the views
-- answer, so "the SQL was read" becomes "the SQL was run".
--
-- Why this file exists: the hosted views and Tools/analyze_telemetry.py are two
-- implementations of the same four questions, and 006 exists precisely because the two
-- had drifted. Reading a diff cannot tell you that a CASE falls through to ELSE on a
-- NULL snapshot, or that a re-created CTE changed a denominator - only executing the
-- view against a row that exercises it can. Every fixture below is therefore a row
-- shape the local report already covers in Tools/analyze_telemetry_test.py, and the
-- numbers asserted here are the numbers that report produced.
--
-- Run it with:
--   for f in Server/supabase/migrations/*.sql; do psql -v ON_ERROR_STOP=1 -d "$DB" < "$f"; done
--   psql -v ON_ERROR_STOP=1 -d "$DB" -f Server/supabase/tests/migrations_test.sql
-- `.github/workflows/validate_game_data.yml` and Tools/preflight.ps1 both do exactly
-- that against a scratch database; ON_ERROR_STOP is what turns a failed assertion into
-- a non-zero exit code. The migrations are fed in on stdin rather than with `-f` so the
-- shell that can read the checkout is also the one that opens the file.
--
-- Everything happens inside one transaction that is rolled back, so the test leaves the
-- database exactly as the migrations made it and can be re-run without cleaning up.
-- Each scenario truncates first, so one scenario's numbers cannot be moved by the one
-- before it (`v_win_loss_presence` pools every run, deliberately).

begin;

-- ===========================================================================
-- 1. The migrations ran, and every view executes against the schema they made.
--
-- A view is only shape-checked where it is used: a dropped column, or a `->>` path
-- into a key that no longer exists, is a *runtime* error rather than a creation error.
-- The per-view `count(*)` below is that use, so a view that stopped resolving fails
-- here instead of the first time somebody opens the dashboard.
-- ===========================================================================
do $$
declare
    view_name text;
begin
    foreach view_name in array array[
        'v_skill_pick_rates', 'v_ultimate_rates', 'v_card_rates', 'v_chose_instead',
        'v_win_loss_presence', 'v_run_overview', 'v_situational_matchup',
        'v_enemy_strategy', 'v_target_priority', 'v_roster_coverage',
        'v_wasted_resources', 'v_cohort_pick_rates', 'v_defeat_causes',
        'v_replayable_runs', 'v_flag_cohorts'
    ] loop
        if to_regclass('public.' || view_name) is null then
            raise exception 'migrations 001-006 did not create the view %', view_name;
        end if;
        execute format('select count(*) from public.%I', view_name);
    end loop;

    -- 003 adds the per-run flag column every flag cohort is built from.
    if not exists (
        select 1 from information_schema.columns
        where table_schema = 'public'
          and table_name = 'telemetry_runs'
          and column_name = 'flags'
    ) then
        raise exception '003_run_flags.sql did not add telemetry_runs.flags';
    end if;
end $$;

-- ===========================================================================
-- 2. Every balance view is production-only, and the "clean" set is exactly the one
--    Tools/analyze_telemetry.py calls --production-only plus its abandoned rule.
--
-- Seven runs, each a different way to be in or out of the set:
--
--   a1  clean, won
--   a2  clean, lost            (killed_by is set)
--   a3  a developer build      (is_debug_build)
--   a4  a tester tool touched  (was_debug_tainted)
--   a5  restarted mid-battle   (abandoned, victory = false)
--   a6  still in flight        (victory is null, no run_seed)
--   b1  clean, won, other balance patch
-- ===========================================================================
insert into balance_versions (balance_hash, game_version)
values ('bal_a', '0.1'), ('bal_b', '0.1'), ('bal_c', '0.1');

insert into telemetry_runs (
    run_id, balance_hash, game_version, is_debug_build, was_debug_tainted, abandoned,
    ally_lineup, victory, end_reason, final_wave, total_turns, total_decisions,
    run_seed, player_run_number, killed_by, started_at, flags
) values
    ('00000000-0000-4000-8000-0000000000a1', 'bal_a', '0.1', false, false, false,
     '{striker,buff,healer}', true, 'final_wave_cleared', 3, 12, 40,
     101, 1, null, now() - interval '3 hours', '{"exp": true}'),
    ('00000000-0000-4000-8000-0000000000a2', 'bal_a', '0.1', false, false, false,
     '{striker}', false, 'defeat', 2, 9, 30,
     102, 5, 'boss_enemy / boss_enemy_ult', now() - interval '2 hours', '{}'),
    ('00000000-0000-4000-8000-0000000000a3', 'bal_a', '0.1', true, false, false,
     '{striker}', true, 'final_wave_cleared', 3, 11, 33,
     103, 1, null, now() - interval '1 hour', '{"exp": true}'),
    ('00000000-0000-4000-8000-0000000000a4', 'bal_a', '0.1', false, true, false,
     '{striker}', true, 'final_wave_cleared', 3, 10, 31,
     104, 1, null, now() - interval '50 minutes', '{"exp": true}'),
    ('00000000-0000-4000-8000-0000000000a5', 'bal_a', '0.1', false, false, true,
     '{striker}', false, 'abandoned', 2, 4, 12,
     105, 1, null, now() - interval '40 minutes', '{"exp": true}'),
    ('00000000-0000-4000-8000-0000000000a6', 'bal_c', '0.1', false, false, false,
     '{striker}', null, null, null, null, null,
     null, 1, null, now() - interval '30 minutes', '{}'),
    ('00000000-0000-4000-8000-0000000000b1', 'bal_b', '0.1', false, false, false,
     '{healer}', true, 'final_wave_cleared', 3, 14, 44,
     107, 2, null, now() - interval '20 minutes', '{"exp": true}');

-- One decision per run, every one of them an applied play: `s_live` is taken by the two
-- clean `bal_a` runs while `s_other` is offered beside it in a1 and passed over, and
-- `s_debug` / `s_tainted` / `s_abandoned` only ever exist on the runs that must be
-- dropped. b1 carries its own skill so it cannot move the `s_live` denominator.
insert into telemetry_decisions (
    event_id, run_id, turn_number, decision_type, skill_id,
    offered_skills, chosen_payload
) values
    ('10000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000a1', 1,
     'play_card', 's_live', '{s_live,s_other}',
     '{"applied": true, "skill_id": "s_live"}'),
    ('10000000-0000-4000-8000-0000000000a2', '00000000-0000-4000-8000-0000000000a2', 1,
     'play_card', 's_live', '{s_live}',
     '{"applied": true, "skill_id": "s_live"}'),
    ('10000000-0000-4000-8000-0000000000a3', '00000000-0000-4000-8000-0000000000a3', 1,
     'play_card', 's_debug', '{s_debug}',
     '{"applied": true, "skill_id": "s_debug"}'),
    ('10000000-0000-4000-8000-0000000000a4', '00000000-0000-4000-8000-0000000000a4', 1,
     'play_card', 's_tainted', '{s_tainted}',
     '{"applied": true, "skill_id": "s_tainted"}'),
    ('10000000-0000-4000-8000-0000000000a5', '00000000-0000-4000-8000-0000000000a5', 1,
     'play_card', 's_abandoned', '{s_abandoned}',
     '{"applied": true, "skill_id": "s_abandoned"}'),
    ('10000000-0000-4000-8000-0000000000b1', '00000000-0000-4000-8000-0000000000b1', 1,
     'play_card', 's_b', '{s_b}',
     '{"applied": true, "skill_id": "s_b"}');

-- ---------------------------------------------------------- v_replayable_runs
-- 006 was written because this was the one view that was not production-only: it
-- listed developer builds, tester-tainted runs and battles a player restarted, so a
-- "replay this outlier" seed could reproduce a run no other number in the report had
-- seen. It is also the one view whose order is part of its contract - newest first,
-- because that is how it is read.
do $$
declare
    ids text;
    newest text;
begin
    select string_agg(run_id::text, ',' order by run_id) into ids from v_replayable_runs;
    if ids is distinct from '00000000-0000-4000-8000-0000000000a1'
                          || ',00000000-0000-4000-8000-0000000000a2'
                          || ',00000000-0000-4000-8000-0000000000b1' then
        raise exception 'v_replayable_runs should hold exactly a1, a2 and b1, got %',
            coalesce(ids, '(nothing)');
    end if;

    select run_id::text into newest from v_replayable_runs limit 1;
    if newest is distinct from '00000000-0000-4000-8000-0000000000b1' then
        raise exception 'v_replayable_runs must list the newest run first, got %', newest;
    end if;
end $$;

-- ------------------------------------------------------------ v_flag_cohorts
-- One row per flag *per balance patch*, so the flag-off side of a comparison is always
-- the same patch as the flag-on side (004) - and an abandoned run is not a loss (005).
-- Both bugs show up in one number: `exp` won every run it was on.
do $$
declare
    on_rate numeric;
    row_count bigint;
    off_runs bigint;
begin
    select count(*) into row_count from v_flag_cohorts;
    if row_count <> 2 then
        raise exception 'v_flag_cohorts must be scoped per balance_hash (2 patches carry the flag), got % row(s)', row_count;
    end if;

    select win_rate_on, runs_off into on_rate, off_runs
      from v_flag_cohorts where flag = 'exp' and balance_hash = 'bal_a';
    if on_rate is distinct from 100.0 then
        raise exception 'v_flag_cohorts: exp on bal_a won 100%% of its runs, got % (an abandoned run counted as a loss?)', on_rate;
    end if;
    if off_runs <> 1 then
        raise exception 'v_flag_cohorts: exp on bal_a should have 1 run off, got %', off_runs;
    end if;
end $$;

-- -------------------------------------------------------- v_skill_pick_rates
-- The honest denominator: `picked / offered`, where offered is the times the skill was
-- actually legal. `s_live` was offered twice and taken twice; `s_other` was offered
-- once and never taken. The three skills that only exist on an excluded run must not
-- appear at all - the production-only filter, expressed as a denominator.
do $$
declare
    offered_count bigint;
    picked_count bigint;
    other_rate numeric;
    leaked text;
begin
    select offered, picked into offered_count, picked_count
      from v_skill_pick_rates where skill_id = 's_live';
    if offered_count <> 2 or picked_count <> 2 then
        raise exception 'v_skill_pick_rates: s_live should be 2 of 2 offers, got % of %',
            picked_count, offered_count;
    end if;

    select pick_rate into other_rate from v_skill_pick_rates where skill_id = 's_other';
    if other_rate is distinct from 0.0 then
        raise exception 'v_skill_pick_rates: s_other was never taken, its pick_rate must be 0, got %', other_rate;
    end if;

    -- A developer build or a run a tester tool touched is not evidence about players.
    select string_agg(skill_id, ', ') into leaked from v_skill_pick_rates
    where skill_id in ('s_debug', 's_tainted');
    if leaked is not null then
        raise exception 'v_skill_pick_rates leaked a non-production skill: %', leaked;
    end if;

    -- ...but an abandoned run's decision *is* a decision: the player really did make it
    -- before quitting, and Tools/analyze_telemetry.py counts it in exactly the same
    -- place. Only the views that turn a run into a win or a loss drop abandoned runs.
    select offered, picked into offered_count, picked_count
      from v_skill_pick_rates where skill_id = 's_abandoned';
    if offered_count <> 1 or picked_count <> 1 then
        raise exception 'v_skill_pick_rates: a decision made before a player quit still counts, got % of %',
            picked_count, offered_count;
    end if;

    -- v_cohort_pick_rates is the deliberate exception: it exists to show how experience
    -- changes a pick rate, and an unfinished run has no experience to attribute, so it
    -- drops them - the same asymmetry the local report draws.
    if exists (select 1 from v_cohort_pick_rates where skill_id = 's_abandoned') then
        raise exception 'v_cohort_pick_rates must not count a run that was never finished';
    end if;
end $$;

-- ------------------------------------------------------------ v_chose_instead
-- The opportunity cost of passing `s_other` over: the player played `s_live` instead.
-- The skill that *was* taken gets no row here, because "chose instead" of itself is
-- not a question.
do $$
declare
    instead text;
    taken_itself bigint;
begin
    select instead_action into instead from v_chose_instead where offered_skill = 's_other';
    if instead is distinct from 'play:s_live' then
        raise exception 'v_chose_instead: passing s_other should read as play:s_live, got %',
            coalesce(instead, '(no row)');
    end if;

    select count(*) into taken_itself from v_chose_instead where offered_skill = 's_live';
    if taken_itself <> 0 then
        raise exception 'v_chose_instead must not answer for a skill that was taken (% row(s))', taken_itself;
    end if;
end $$;

-- ------------------------------------------------------------- v_run_overview
-- Finished battles and abandoned ones are counted separately, and the averages only
-- ever see finished battles - quitting must not look like losing.
do $$
declare
    finished bigint;
    abandoned bigint;
    win_rate_value numeric;
    turns numeric;
    abandon_wave numeric;
begin
    select finished_runs, abandoned_runs, win_rate, avg_turns, avg_abandon_wave
      into finished, abandoned, win_rate_value, turns, abandon_wave
      from v_run_overview where balance_hash = 'bal_a';

    if finished <> 2 or abandoned <> 1 then
        raise exception 'v_run_overview: bal_a should be 2 finished / 1 abandoned, got %/%', finished, abandoned;
    end if;
    if win_rate_value is distinct from 0.5 then
        raise exception 'v_run_overview: bal_a win_rate should be 0.5, got %', win_rate_value;
    end if;
    if turns is distinct from 10.5 then
        raise exception 'v_run_overview: avg_turns over the two finished runs should be 10.5 (the abandoned run''s 4 turns must not be pooled), got %', turns;
    end if;
    if abandon_wave is distinct from 2.0 then
        raise exception 'v_run_overview: avg_abandon_wave should be 2.0, got %', abandon_wave;
    end if;
end $$;

-- ------------------------------------------------------------ v_defeat_causes
-- The abandoned run lost as well, so a view that filtered on `not victory` alone would
-- report an abandon as a defeat cause.
do $$
declare
    causes bigint;
    killer text;
begin
    select count(*) into causes from v_defeat_causes;
    if causes <> 1 then
        raise exception 'v_defeat_causes: exactly one run was a real defeat, got % row(s)', causes;
    end if;

    select killed_by into killer from v_defeat_causes;
    if killer is distinct from 'boss_enemy / boss_enemy_ult' then
        raise exception 'v_defeat_causes: killed_by should be the enemy/skill pair, got %', coalesce(killer, '(null)');
    end if;
end $$;

truncate telemetry_decisions, telemetry_turns, telemetry_runs, balance_versions;

-- ===========================================================================
-- 3. The lift is the mean over *plays*, not over strata.
--
-- The same fixture Tools/analyze_telemetry_test.py calls "lopsided": `heavy` is played
-- three times on an already-winning board (baseline 100%, so delta 0) and once in an
-- even fight (baseline 50%, so delta 0.5). Weighting the two strata equally reports
-- 0.25; averaging per play reports 0.125, and 0.125 is what the view must produce -
-- a card played 99 times in an even fight and once while already winning must not read
-- as a 50/50 blend.
--
--   a, b  won        c, d, e  lost
--   even board     ally 0.6 / enemy 0.9 / threat 0.1
--   winning board  ally 0.9 / enemy 0.1 / threat 0.0
-- ===========================================================================
insert into balance_versions (balance_hash, game_version) values ('bal_lift', '0.1');

insert into telemetry_runs (run_id, balance_hash, game_version, victory, run_seed, started_at)
values
    ('00000000-0000-4000-8000-00000000003a', 'bal_lift', '0.1', true,  201, now() - interval '9 minutes'),
    ('00000000-0000-4000-8000-00000000003b', 'bal_lift', '0.1', true,  202, now() - interval '8 minutes'),
    ('00000000-0000-4000-8000-00000000003c', 'bal_lift', '0.1', false, 203, now() - interval '7 minutes'),
    ('00000000-0000-4000-8000-00000000003d', 'bal_lift', '0.1', false, 204, now() - interval '6 minutes'),
    ('00000000-0000-4000-8000-00000000003e', 'bal_lift', '0.1', false, 205, now() - interval '5 minutes');

-- Five even-fight fillers, three winning-board `heavy` plays and one even-fight
-- `heavy`: six even-fight decisions of which three were won, so the even baseline is
-- 0.5, and three winning-board decisions all won, so that baseline is 1.0.
insert into telemetry_decisions (
    event_id, run_id, decision_type, skill_id,
    ally_hp_pct_before, enemy_hp_pct_before, threat_ratio_before, chosen_payload
)
select gen_random_uuid(), run_id::uuid, 'play_card', skill, ally, enemy, threat,
       jsonb_build_object('applied', true, 'skill_id', skill,
                          'card', jsonb_build_object('key', '3'))
from (values
    ('00000000-0000-4000-8000-00000000003a', 'filler', 0.6, 0.9, 0.1),
    ('00000000-0000-4000-8000-00000000003b', 'filler', 0.6, 0.9, 0.1),
    ('00000000-0000-4000-8000-00000000003c', 'filler', 0.6, 0.9, 0.1),
    ('00000000-0000-4000-8000-00000000003d', 'filler', 0.6, 0.9, 0.1),
    ('00000000-0000-4000-8000-00000000003e', 'filler', 0.6, 0.9, 0.1),
    ('00000000-0000-4000-8000-00000000003a', 'heavy',  0.9, 0.1, 0.0),
    ('00000000-0000-4000-8000-00000000003a', 'heavy',  0.9, 0.1, 0.0),
    ('00000000-0000-4000-8000-00000000003b', 'heavy',  0.9, 0.1, 0.0),
    ('00000000-0000-4000-8000-00000000003a', 'heavy',  0.6, 0.9, 0.1)
) as plays(run_id, skill, ally, enemy, threat);

do $$
declare
    play_count bigint;
    raw_rate numeric;
    lift_value numeric;
begin
    select casts, round(raw_win_rate::numeric, 6), round(advantage_adjusted_lift::numeric, 6)
      into play_count, raw_rate, lift_value
      from v_win_loss_presence where choice = 'skill:heavy';

    if play_count <> 4 then
        raise exception 'v_win_loss_presence: skill:heavy was played 4 times, got %', play_count;
    end if;
    if raw_rate is distinct from 1.0 then
        raise exception 'v_win_loss_presence: skill:heavy raw win rate should stay 100%% - the trap the lift removes - got %', raw_rate;
    end if;
    if lift_value is distinct from 0.125 then
        raise exception 'v_win_loss_presence: skill:heavy lift should be 0.125 (mean over plays), got %; 0.25 means the strata are being weighted equally', lift_value;
    end if;

    -- The always-played filler is the control: it appears in every even fight and in
    -- neither winning one, so its lift is exactly minus the even baseline (-0.5).
    select round(advantage_adjusted_lift::numeric, 6) into lift_value
      from v_win_loss_presence where choice = 'skill:filler';
    if lift_value is distinct from -0.1 then
        raise exception 'v_win_loss_presence: skill:filler lift should be -0.1 (2 wins of 5 plays minus the 0.5 even baseline), got %', lift_value;
    end if;

    -- The same plays also carry a card key, so the card row must agree with the skill
    -- rows: 6 wins of 9 plays, and a lift of zero because the wins are exactly the
    -- ones the two baselines already predicted.
    select casts, round(raw_win_rate::numeric, 6), round(advantage_adjusted_lift::numeric, 6)
      into play_count, raw_rate, lift_value
      from v_win_loss_presence where choice = 'card:3';
    if play_count <> 9 or raw_rate is distinct from 0.666667 or lift_value is distinct from 0.0 then
        raise exception 'v_win_loss_presence: card:3 should be 9 plays / 0.666667 / 0 lift, got % / % / %',
            play_count, raw_rate, lift_value;
    end if;
end $$;

truncate telemetry_decisions, telemetry_turns, telemetry_runs, balance_versions;

-- ===========================================================================
-- 4. A decision with no board snapshot is 'desperate', never 'winning'.
--
-- Every comparison against a NULL is NULL, so the first version of the CASE fell
-- through to ELSE and bucketed an unknown board as 'even'. That is the one reading the
-- local report refuses to make: an unknown board must never be treated as a winning
-- one, and Tools/analyze_telemetry.py buckets it 'desperate'. 006 coalesces the three
-- metrics so the two agree.
--
-- The number that exposes it is the *baseline* the snapshot-less play is measured
-- against, and the fixture makes the three strata disagree on purpose:
--
--   n1  won,  no snapshot at all  -> 'desperate' (baseline 0.5, shared with n3)
--   n2  won,  already winning     -> 'winning'   (baseline 1.0)
--   n3  lost, hurt and threatened -> 'desperate'
--
-- Under 006 the snapshot-less win lifts 0.5 (it was played in a 50/50 stratum); if it
-- were read as 'even' it would be alone in that stratum, so its baseline would be its
-- own 100% and it would lift 0.0 - a win-more card that looks like it never helped.
-- ===========================================================================
insert into balance_versions (balance_hash, game_version) values ('bal_null', '0.1');

insert into telemetry_runs (run_id, balance_hash, game_version, victory, run_seed, started_at)
values
    ('00000000-0000-4000-8000-00000000004a', 'bal_null', '0.1', true,  301, now() - interval '4 minutes'),
    ('00000000-0000-4000-8000-00000000004b', 'bal_null', '0.1', true,  302, now() - interval '3 minutes'),
    ('00000000-0000-4000-8000-00000000004c', 'bal_null', '0.1', false, 303, now() - interval '2 minutes');

insert into telemetry_decisions (
    event_id, run_id, decision_type, skill_id,
    ally_hp_pct_before, enemy_hp_pct_before, threat_ratio_before, chosen_payload
) values
    -- No snapshot at all: the turn event that would have carried the metrics never
    -- arrived, so all three columns are NULL.
    ('10000000-0000-4000-8000-00000000004a', '00000000-0000-4000-8000-00000000004a',
     'play_card', 's_null', null, null, null,
     '{"applied": true, "skill_id": "s_null"}'),
    ('10000000-0000-4000-8000-00000000004b', '00000000-0000-4000-8000-00000000004b',
     'play_card', 's_winning', 0.9, 0.1, 0.0,
     '{"applied": true, "skill_id": "s_winning"}'),
    ('10000000-0000-4000-8000-00000000004c', '00000000-0000-4000-8000-00000000004c',
     'play_card', 's_desperate', 0.2, 0.9, 0.1,
     '{"applied": true, "skill_id": "s_desperate"}');

do $$
declare
    lift numeric;
begin
    select round(advantage_adjusted_lift::numeric, 6) into lift
      from v_win_loss_presence where choice = 'skill:s_null';
    if lift is distinct from 0.5 then
        raise exception 'v_win_loss_presence: a snapshot-less win must be bucketed with the hurt half of the board (lift 0.5), got %; 0.0 means the NULL row fell through to ELSE and became its own 100%% stratum', lift;
    end if;

    select round(advantage_adjusted_lift::numeric, 6) into lift
      from v_win_loss_presence where choice = 'skill:s_desperate';
    if lift is distinct from -0.5 then
        raise exception 'v_win_loss_presence: the real desperate loss must share a stratum with the snapshot-less win (lift -0.5), got %', lift;
    end if;

    select round(advantage_adjusted_lift::numeric, 6) into lift
      from v_win_loss_presence where choice = 'skill:s_winning';
    if lift is distinct from 0.0 then
        raise exception 'v_win_loss_presence: a win on an already-winning board lifts nothing, got %', lift;
    end if;
end $$;

truncate telemetry_decisions, telemetry_turns, telemetry_runs, balance_versions;

-- ===========================================================================
-- 5. Sub-prompts (a skill that asked which enemy to hit) survive the ingest.
--
-- `decision.sub_prompts` is where the target a skill asked for is recorded, and
-- `v_target_priority` reads it out of `offered_options`. The ingest used to drop it
-- on the floor while serialising the decision, so the view was correct and always
-- empty - a bug no local report could see, because the local report reads the spool
-- file rather than the database.
--
--   p1  clean    -- a pick_target prompt (boss, mob / took boss) and a pick_card one
--   p2  a developer build -- the same prompt, offering mob; not evidence
--   p3  clean    -- no sub_prompts at all
-- ===========================================================================
insert into balance_versions (balance_hash, game_version) values ('bal_prompt', '0.1');

insert into telemetry_runs (run_id, balance_hash, game_version, is_debug_build, victory, run_seed, started_at)
values
    ('00000000-0000-4000-8000-00000000005a', 'bal_prompt', '0.1', false, true, 401, now() - interval '3 minutes'),
    ('00000000-0000-4000-8000-00000000005b', 'bal_prompt', '0.1', true,  true, 402, now() - interval '2 minutes'),
    ('00000000-0000-4000-8000-00000000005c', 'bal_prompt', '0.1', false, true, 403, now() - interval '1 minute');

insert into telemetry_decisions (
    event_id, run_id, decision_type, skill_id, offered_options, chosen_payload
) values
    ('10000000-0000-4000-8000-00000000005a', '00000000-0000-4000-8000-00000000005a',
     'play_card', 's_pick',
     '{"sub_prompts": [
         {"prompt": "pick_target",
          "candidates": [{"unit_id": "boss"}, {"unit_id": "mob"}],
          "picked": [{"unit_id": "boss"}]},
         {"prompt": "pick_card",
          "candidates": [{"key": "3"}],
          "picked": [{"key": "3"}]}
      ]}',
     '{"applied": true, "skill_id": "s_pick"}'),
    ('10000000-0000-4000-8000-00000000005b', '00000000-0000-4000-8000-00000000005b',
     'play_card', 's_pick',
     '{"sub_prompts": [
         {"prompt": "pick_target",
          "candidates": [{"unit_id": "mob"}],
          "picked": [{"unit_id": "mob"}]}
      ]}',
     '{"applied": true, "skill_id": "s_pick"}'),
    ('10000000-0000-4000-8000-00000000005c', '00000000-0000-4000-8000-00000000005c',
     'play_card', 's_plain', '{}',
     '{"applied": true, "skill_id": "s_plain"}');

do $$
declare
    row_count bigint;
    offered_count bigint;
    picked_count bigint;
    null_candidates bigint;
begin
    select count(*) into row_count from v_target_priority;
    if row_count <> 2 then
        raise exception 'v_target_priority: the one production prompt offers 2 candidates, got % row(s) - 0 means sub_prompts never reached offered_options', row_count;
    end if;

    select count(*) into null_candidates from v_target_priority where candidate_unit_id is null;
    if null_candidates <> 0 then
        raise exception 'v_target_priority: a pick_card prompt leaked in as a NULL candidate (% row(s))', null_candidates;
    end if;

    select offered, picked into offered_count, picked_count
      from v_target_priority where candidate_unit_id = 'mob';
    if offered_count <> 1 or picked_count <> 0 then
        raise exception 'v_target_priority: mob was offered once and never picked, got % of % (a developer build must not count)', picked_count, offered_count;
    end if;

    select offered, picked into offered_count, picked_count
      from v_target_priority where candidate_unit_id = 'boss';
    if offered_count <> 1 or picked_count <> 1 then
        raise exception 'v_target_priority: boss was offered once and taken, got % of %', picked_count, offered_count;
    end if;
end $$;

-- The test reverts its own fixtures: the database is left exactly as 001-006 made it.
rollback;
