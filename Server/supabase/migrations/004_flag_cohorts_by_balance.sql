-- Scope each flag cohort to the balance patch it was observed on.
--
-- 003 pooled every run into a single control group, which reads a balance patch as a
-- flag effect: the flag-on runs of a new patch were compared against the flag-off runs
-- of the previous one (Simpson's paradox). Here the "off" side of every row is always
-- the same `balance_hash` as the "on" side, so the comparison is like for like.
--
-- Replaces the view rather than editing 003, because a migration that has been pushed
-- is part of the database's history.
--
-- `create or replace view` may only *append* columns, and this one inserts
-- `balance_hash` as the second one, so a plain replace is rejected outright:
--
--   ERROR:  cannot change name of view column "runs_on" to "balance_hash"
--
-- which means `supabase db push` stopped here, on a fresh database, before 005 or 006
-- ever ran - so this file has never been applied anywhere and can be corrected rather
-- than worked around. (`Server/supabase/tests/migrations_test.sql` is the gate that
-- applies the chain in order against a real server and catches exactly this.)
-- Dropping and re-creating is the supported way to change a view's shape; nothing
-- depends on the old one, and a re-run is still idempotent.

drop view if exists v_flag_cohorts;

create view v_flag_cohorts as
with clean as (
    select run_id, balance_hash, victory, jsonb_object_keys(flags) as flag
    from telemetry_runs
    where not is_debug_build
      and not was_debug_tainted
      and victory is not null
),
per_balance as (
    select balance_hash,
           count(*)                        as runs_all,
           count(*) filter (where victory) as wins_all
    from telemetry_runs
    where not is_debug_build
      and not was_debug_tainted
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
