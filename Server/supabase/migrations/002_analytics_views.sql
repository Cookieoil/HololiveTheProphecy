-- Analytical views: the three human-centric questions, answered in SQL.
--
-- These mirror Tools/analyze_telemetry.py so the local report and the hosted
-- dashboard agree. Connect Metabase / Grafana / Supabase Studio directly to them.

-- 1. Pick rate. How often each skill is the choice when a player acts, split by
--    how the fight was going at the moment of the decision.
create or replace view v_skill_pick_rates as
select
    d.skill_id,
    d.actor_unit_id,
    case
        when d.ally_hp_pct_before >= 0.7 and d.enemy_hp_pct_before <= 0.5 then 'winning'
        when d.ally_hp_pct_before <= 0.4 or d.threat_ratio_before >= 0.5 then 'desperate'
        else 'even'
    end                                        as stratum,
    count(*)                                   as picks,
    avg(d.thinking_time_ms)                    as avg_thinking_ms,
    count(distinct d.run_id)                   as runs
from telemetry_decisions d
join telemetry_runs r on r.run_id = d.run_id
where d.decision_type = 'play_card'
  and not r.was_debug_tainted
  and coalesce((d.chosen_payload ->> 'applied')::boolean, false)
group by 1, 2, 3;

-- 2. Win-rate correlation WITHOUT the selection-bias trap.
--
-- `raw_win_rate` is the naive number that made a card look overpowered; `lift`
-- subtracts the win rate of the exact stratum the decision happened in, so a
-- play that only ever appears in already-winning games scores near zero.
create or replace view v_debiased_win_correlation as
with strata as (
    select
        case
            when d.ally_hp_pct_before >= 0.7 and d.enemy_hp_pct_before <= 0.5 then 'winning'
            when d.ally_hp_pct_before <= 0.4 or d.threat_ratio_before >= 0.5 then 'desperate'
            else 'even'
        end as stratum,
        avg(case when r.victory then 1.0 else 0.0 end) as baseline_win_rate
    from telemetry_decisions d
    join telemetry_runs r on r.run_id = d.run_id
    where not r.was_debug_tainted
    group by 1
)
select
    d.skill_id,
    count(*)                                                        as casts,
    avg(case when r.victory then 1.0 else 0.0 end)                  as raw_win_rate,
    avg((case when r.victory then 1.0 else 0.0 end) - s.baseline_win_rate) as advantage_adjusted_lift
from telemetry_decisions d
join telemetry_runs r on r.run_id = d.run_id
join strata s on s.stratum = case
        when d.ally_hp_pct_before >= 0.7 and d.enemy_hp_pct_before <= 0.5 then 'winning'
        when d.ally_hp_pct_before <= 0.4 or d.threat_ratio_before >= 0.5 then 'desperate'
        else 'even'
    end
where d.decision_type = 'play_card'
  and d.skill_id is not null
  and not r.was_debug_tainted
group by 1;

-- 3. Situational performance: HP the player lost against a specific enemy while
--    a given skill was resolving. Unnests the JSONB damage rows.
create or replace view v_situational_matchup as
select
    d.skill_id,
    row ->> 'source_id'                                  as enemy_unit_id,
    row ->> 'target_id'                                  as ally_unit_id,
    count(*)                                             as hits,
    sum(coalesce((row ->> 'hp_lost')::int, 0))           as hp_lost,
    sum(coalesce((row ->> 'damage')::int, 0))            as damage
from telemetry_decisions d
join telemetry_runs r on r.run_id = d.run_id
cross join lateral jsonb_array_elements(coalesce(d.immediate_outcome -> 'damage_events', '[]'::jsonb)) as row
where not r.was_debug_tainted
  and coalesce((row ->> 'target_is_ally')::boolean, false)
group by 1, 2, 3;

-- Per-run overview used by the dashboards.
create or replace view v_run_overview as
select
    r.balance_hash,
    r.game_version,
    count(*)                                              as runs,
    avg(case when r.victory then 1.0 else 0.0 end)        as win_rate,
    avg(r.total_turns)                                    as avg_turns,
    avg(r.total_decisions)                                as avg_decisions
from telemetry_runs r
where not r.was_debug_tainted
group by 1, 2;
