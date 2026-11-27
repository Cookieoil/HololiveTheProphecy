-- An abandoned run is not a loss.
--
-- A player who restarts or quits mid-battle writes `abandoned = true` together with
-- `victory = false`, so filtering on `victory is not null` alone counts every
-- abandoned run as a defeat. The rest of 002 already excludes them (`v_win_loss_presence`,
-- `v_run_overview`); `v_flag_cohorts` in 004 did not, which biased every win rate it
-- reported.
--
-- Replaces the view rather than editing 004: a pushed migration is history.

create or replace view v_flag_cohorts as
with clean as (
    select run_id, balance_hash, victory, jsonb_object_keys(flags) as flag
    from telemetry_runs
    where not is_debug_build
      and not was_debug_tainted
      and not abandoned
      and victory is not null
),
per_balance as (
    select balance_hash,
           count(*)                        as runs_all,
           count(*) filter (where victory) as wins_all
    from telemetry_runs
    where not is_debug_build
      and not was_debug_tainted
      and not abandoned
      and victory is not null
    group by balance_hash
)
select
    c.flag                                          as flag,
    c.balance_hash                                  as balance_hash,
    count(*)                                        as runs_on,
    count(*) filter (where c.victory)               as wins_on,
    b.runs_all - count(*)                           as runs_off,
    b.wins_all - count(*) filter (where c.victory)  as wins_off,
    round(100.0 * (count(*) filter (where c.victory))
          / nullif(count(*), 0), 1)                  as win_rate_on,
    round(100.0 * (b.wins_all - (count(*) filter (where c.victory)))
          / nullif(b.runs_all - count(*), 0), 1)     as win_rate_off
from clean c
-- `is not distinct from` so a run with no balance row still finds its own cohort.
join per_balance b on b.balance_hash is not distinct from c.balance_hash
group by c.flag, c.balance_hash, b.runs_all, b.wins_all
order by c.flag, c.balance_hash;
