-- Analytical views: the three human-centric questions, answered in SQL.
--
-- These mirror Tools/analyze_telemetry.py so the local report and the hosted
-- dashboard agree. Connect Metabase / Grafana / Supabase Studio directly to them.

-- 1. TRUE pick rate: how often a skill was chosen out of the times it was actually
--    legal to cast. `offered_skills` is the honest denominator (recorded before the
--    choice), so this is `picked / offered`, not "share of all actions".
create or replace view v_skill_pick_rates as
select
    s.skill_id,
    count(*)                                                          as offered,
    count(*) filter (
        where d.decision_type = 'play_card'
          and d.chosen_payload ->> 'skill_id' = s.skill_id
          and coalesce((d.chosen_payload ->> 'applied')::boolean, false)
    )                                                                 as picked,
    round(
        count(*) filter (
            where d.decision_type = 'play_card'
              and d.chosen_payload ->> 'skill_id' = s.skill_id
              and coalesce((d.chosen_payload ->> 'applied')::boolean, false)
        )::numeric / nullif(count(*), 0), 4
    )                                                                 as pick_rate,
    avg(d.thinking_time_ms) filter (where d.decision_type = 'play_card') as avg_thinking_ms,
    count(distinct d.run_id)                                          as runs
from telemetry_decisions d
join telemetry_runs r on r.run_id = d.run_id
cross join lateral unnest(d.offered_skills) as s(skill_id)
where not r.was_debug_tainted
group by 1;

-- 1b. Ultimate cast vs hold rate: a ready Ultimate that was not cast is a choice.
create or replace view v_ultimate_rates as
select
    u.ultimate_id,
    count(*)                                                          as offered,
    count(*) filter (where d.decision_type = 'cast_ultimate'
                       and d.chosen_payload ->> 'ultimate_skill_id' = u.ultimate_id)
                                                                      as cast,
    round(
        count(*) filter (where d.decision_type = 'cast_ultimate'
                           and d.chosen_payload ->> 'ultimate_skill_id' = u.ultimate_id)::numeric
        / nullif(count(*), 0), 4
    )                                                                 as cast_rate
from telemetry_decisions d
join telemetry_runs r on r.run_id = d.run_id
cross join lateral unnest(d.ready_ultimate_skills) as u(ultimate_id)
where not r.was_debug_tainted
group by 1;

-- 1c. Card-level rate: a card that was in hand and was neither played nor merged
--     was simply held, which is also a decision.
create or replace view v_card_rates as
select
    k.card_key,
    count(*)                                                          as in_hand,
    count(*) filter (where d.decision_type = 'play_card'
                       and d.chosen_payload -> 'card' ->> 'key' = k.card_key
                       and coalesce((d.chosen_payload ->> 'applied')::boolean, false))
                                                                      as played,
    count(*) filter (where d.decision_type = 'merge_cards'
                       and (d.chosen_payload -> 'card_a' ->> 'key' = k.card_key
                            or d.chosen_payload -> 'card_b' ->> 'key' = k.card_key))
                                                                      as merged,
    round(
        count(*) filter (where d.decision_type = 'play_card'
                           and d.chosen_payload -> 'card' ->> 'key' = k.card_key
                           and coalesce((d.chosen_payload ->> 'applied')::boolean, false))::numeric
        / nullif(count(*), 0), 4
    )                                                                 as play_rate
from telemetry_decisions d
join telemetry_runs r on r.run_id = d.run_id
cross join lateral unnest(d.offered_card_keys) as k(card_key)
where not r.was_debug_tainted
group by 1;

-- 2. What players chose instead: for every offer that was passed over, the action
--    they took. Answers "when healer_1 was available, did they heal or attack?".
create or replace view v_chose_instead as
select
    s.skill_id                                                        as offered_skill,
    case
        when d.decision_type = 'play_card'
             and coalesce((d.chosen_payload ->> 'applied')::boolean, false)
            then 'play:' || coalesce(d.chosen_payload ->> 'skill_id', 'unknown')
        when d.decision_type = 'cast_ultimate'
            then 'ultimate:' || coalesce(d.chosen_payload ->> 'ultimate_skill_id', 'unknown')
        when d.decision_type = 'end_turn'
             and coalesce((d.chosen_payload ->> 'unused_actions')::int, 0) > 0
            then 'end_turn_with_actions'
        else d.decision_type
    end                                                               as instead_action,
    count(*)                                                          as times
from telemetry_decisions d
join telemetry_runs r on r.run_id = d.run_id
cross join lateral unnest(d.offered_skills) as s(skill_id)
where not r.was_debug_tainted
  and not (d.decision_type = 'play_card'
           and d.chosen_payload ->> 'skill_id' = s.skill_id
           and coalesce((d.chosen_payload ->> 'applied')::boolean, false))
group by 1, 2;


-- 3. Winning vs losing matches WITH the de-biased lift.
--
-- `raw_win_rate` is the naive number that made a card look overpowered; `lift`
-- subtracts the win rate of the exact advantage stratum the decision happened in,
-- so a play that only ever appears in already-winning games scores near zero.
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
            when d.ally_hp_pct_before >= 0.7 and d.enemy_hp_pct_before <= 0.5 then 'winning'
            when d.ally_hp_pct_before <= 0.4 or d.threat_ratio_before >= 0.5 then 'desperate'
            else 'even'
        end as stratum
    from telemetry_decisions d
    join telemetry_runs r on r.run_id = d.run_id
    where not r.was_debug_tainted
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

-- Per-run overview, separating finished battles from abandoned runs.
create or replace view v_run_overview as
select
    r.balance_hash,
    r.game_version,
    count(*) filter (where not r.abandoned)                            as finished_runs,
    count(*) filter (where r.abandoned)                                as abandoned_runs,
    avg(case when r.victory and not r.abandoned then 1.0 else 0.0 end)
        filter (where not r.abandoned)                                 as win_rate,
    avg(r.total_turns) filter (where not r.abandoned)                  as avg_turns,
    avg(r.total_decisions) filter (where not r.abandoned)              as avg_decisions,
    avg(r.final_wave) filter (where r.abandoned)                       as avg_abandon_wave
from telemetry_runs r
where not r.was_debug_tainted
group by 1, 2;


-- 4. Situational performance: HP the player lost to a specific enemy skill, joined
--    with the strategy the player used that same turn. Built from the turn-ending
--    enemy damage rows (enemies act in the enemy turn, not during a decision).
create or replace view v_situational_matchup as
select
    t.active_enemy_ids,
    row ->> 'enemy_unit_id'                                            as enemy_unit_id,
    row ->> 'enemy_skill_id'                                           as enemy_skill_id,
    t.player_skills_used,
    count(*)                                                           as hits,
    sum(coalesce((row ->> 'hp_lost')::int, 0))                         as hp_lost,
    sum(coalesce((row ->> 'damage')::int, 0))                          as damage,
    avg(coalesce((row ->> 'enemy_roll')::int, 0))                      as avg_enemy_roll
from telemetry_turns t
join telemetry_runs r on r.run_id = t.run_id
cross join lateral jsonb_array_elements(coalesce(t.enemy_damage_json, '[]'::jsonb)) as row
where not r.was_debug_tainted
group by 1, 2, 3, 4;

-- 4b. Strategy against a specific enemy: what players actually did while facing it,
--     and under a threatening intent roll.
create or replace view v_enemy_strategy as
select
    coalesce(array_to_string(d.active_enemy_ids, '+'), 'none')          as facing,
    d.decision_type,
    count(*)                                                           as decisions,
    round(
        count(*)::numeric / nullif(sum(count(*)) over (
            partition by coalesce(array_to_string(d.active_enemy_ids, '+'), 'none')), 0), 4
    )                                                                  as action_share,
    count(*) filter (where d.intent_condition_met)                      as with_condition_met,
    count(*) filter (where d.intent_ult_imminent)                       as with_ult_imminent
from telemetry_decisions d
join telemetry_runs r on r.run_id = d.run_id
where not r.was_debug_tainted
group by 1, 2;

-- 4c. Focus fire: who the player picked when a skill asked for a target.
create or replace view v_target_priority as
select
    p ->> 'unit_id'                                                    as candidate_unit_id,
    count(*)                                                           as offered,
    count(*) filter (where picked.picked_id is not null)                as picked,
    round(count(*) filter (where picked.picked_id is not null)::numeric
          / nullif(count(*), 0), 4)                                    as pick_rate
from telemetry_decisions d
join telemetry_runs r on r.run_id = d.run_id
cross join lateral jsonb_array_elements(coalesce(d.offered_options -> 'sub_prompts', '[]'::jsonb)) as prompt
cross join lateral jsonb_array_elements(coalesce(prompt -> 'candidates', '[]'::jsonb)) as p
left join lateral (
    select p2 ->> 'unit_id' as picked_id
    from jsonb_array_elements(coalesce(prompt -> 'picked', '[]'::jsonb)) as p2
    where p2 ->> 'unit_id' = p ->> 'unit_id'
) as picked on true
where not r.was_debug_tainted
  and prompt ->> 'prompt' = 'pick_target'
group by 1;

