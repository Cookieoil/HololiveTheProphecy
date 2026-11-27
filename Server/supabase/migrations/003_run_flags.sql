-- Staged feature flags, per run.
--
-- `run_started` records the flags that were ON for that battle (Core/FeatureFlags.gd
-- buckets them on the run seed), so an experiment can be read next to the runs that
-- did not have it. Deliberately not folded into `config_snapshot`: the config is
-- balance, a flag is an experiment, and only one of the two should invalidate the
-- comparison it is used for.

alter table telemetry_runs
    add column if not exists flags jsonb not null default '{}'::jsonb;

-- One row per flag: how the runs that had it did next to the runs that never did.
-- Production only, like every other view: a developer build or a run touched by the
-- tester tools is not evidence. A run with no flags contributes to the "off" side of
-- every flag, which is what makes the control group real.
create or replace view v_flag_cohorts as
with clean as (
    select run_id, victory, jsonb_object_keys(flags) as flag
    from telemetry_runs
    where not is_debug_build
      and not was_debug_tainted
      and victory is not null
),
totals as (
    select count(*) as runs_all, count(*) filter (where victory) as wins_all
    from telemetry_runs
    where not is_debug_build
      and not was_debug_tainted
      and victory is not null
)
select
    c.flag                                             as flag,
    count(*)                                           as runs_on,
    count(*) filter (where c.victory)                  as wins_on,
    t.runs_all - count(*)                              as runs_off,
    t.wins_all - count(*) filter (where c.victory)     as wins_off,
    round(100.0 * (count(*) filter (where c.victory))
          / nullif(count(*), 0), 1)                    as win_rate_on,
    round(100.0 * (t.wins_all - (count(*) filter (where c.victory)))
          / nullif(t.runs_all - count(*), 0), 1)       as win_rate_off
from clean c
cross join totals t
group by c.flag, t.runs_all, t.wins_all
order by c.flag;
