-- Parity between the hosted views and Tools/analyze_telemetry.py.
--
-- 002 says "these mirror Tools/analyze_telemetry.py so the local report and the hosted
-- dashboard agree", and two of them did not:
--
-- 1. `v_replayable_runs` was the one view that was not production-only. It filtered
--    `was_debug_tainted` but not `is_debug_build`, and it listed abandoned runs, while
--    the local report's "Replayable seeds" section excludes both. Reloading a seed from a
--    developer build, or from a battle a player restarted mid-fight, reproduces a run that
--    is not in any other number here.
-- 2. `v_win_loss_presence` bucketed a decision with no board snapshot as 'even', because
--    every comparison against NULL is NULL and the CASE fell through to ELSE. The local
--    report reads a missing snapshot as 'desperate' instead - deliberately, since an
--    unknown board must never be treated as a winning one. `coalesce(..., 0)` on the three
--    metrics makes the two agree on the rare row that has no snapshot.
--
-- The lift itself is unchanged here: `avg(win - baseline)` is already the mean over
-- *plays*, which is what the report now computes (`lift / casts`). The report was the one
-- that moved, in the other direction, so its per-stratum mean could not let a single play
-- in a rare stratum carry half the answer.
--
-- Replaces the views rather than editing 002: a pushed migration is history.

create or replace view v_win_loss_presence as
with played as (
    select
        d.run_id,
        r.victory,
        d.decision_type,
        d.skill_id,
        d.chosen_payload -> 'card' ->> 'key' as card_key,
        d.chosen_payload ->> 'ultimate_skill_id' as ultimate_id,
        case
            when coalesce(d.ally_hp_pct_before, 0) >= 0.7
                 and coalesce(d.enemy_hp_pct_before, 0) <= 0.5 then 'winning'
            when coalesce(d.ally_hp_pct_before, 0) <= 0.4
                 or coalesce(d.threat_ratio_before, 0) >= 0.5 then 'desperate'
            else 'even'
        end as stratum
    from telemetry_decisions d
    join telemetry_runs r on r.run_id = d.run_id
    where not r.was_debug_tainted
      and not r.is_debug_build
      and not r.abandoned
      and coalesce((d.chosen_payload ->> 'applied')::boolean, false)
),
baselines as (
    select stratum, avg(case when victory then 1.0 else 0.0 end) as baseline
    from played group by 1
),
labelled as (
    select run_id, victory, stratum, 'skill:' || skill_id as choice from played
        where decision_type = 'play_card' and skill_id is not null
    union all
    select run_id, victory, stratum, 'ultimate:' || ultimate_id from played
        where decision_type = 'cast_ultimate' and ultimate_id is not null
    union all
    select run_id, victory, stratum, 'card:' || card_key from played
        where decision_type = 'play_card' and card_key is not null
)
select
    l.choice,
    count(*)                                                          as casts,
    avg(case when l.victory then 1.0 else 0.0 end)                    as raw_win_rate,
    avg((case when l.victory then 1.0 else 0.0 end) - b.baseline)     as advantage_adjusted_lift,
    count(distinct l.run_id)                                          as matches,
    count(distinct l.run_id) filter (where l.victory)                  as in_wins,
    count(distinct l.run_id) filter (where not l.victory)              as in_losses
from labelled l
join baselines b on b.stratum = l.stratum
group by 1;

create or replace view v_replayable_runs as
select
    r.run_id,
    r.run_seed,
    r.player_run_number,
    r.victory,
    r.end_reason,
    r.total_turns,
    r.ally_lineup,
    r.killed_by
from telemetry_runs r
where not r.was_debug_tainted
  and not r.is_debug_build
  and not r.abandoned
  and r.run_seed is not null
order by r.started_at desc;
