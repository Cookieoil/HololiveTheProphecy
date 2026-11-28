// Pure row-building layer behind the telemetry-ingest Edge Function.
//
// It is separate from index.ts (which owns Deno, HTTP and the Supabase client) for
// the same reason Tools/CodeIndexParser.gd is separate from Tools/gen_code_index.gd:
// turning an event into a database row is the part with the rules in it, so it is a
// pure function of its input and can be unit tested with no server and no network.
//
// The rule that matters: a run's events are POSTed in batches of at most MAX_EVENTS,
// so one batch can carry only the `run_started` half of a run while a later batch
// carries only its `run_ended` half. Each half therefore writes *only the columns it
// owns*. Writing a whole row from either half would blank the other half's columns on
// conflict - a batch carrying `run_ended` alone would erase the run's balance hash,
// seed, flags and player id, detaching it from its balance patch, and a batch
// carrying `run_started` alone would record `victory = false` for a battle that is
// still being played (which is how `v_flag_cohorts` tells a finished run from an
// abandoned one).
//
// Run with:  node --test Server/supabase/functions/telemetry-ingest/

export const SCHEMA_VERSION = 1;
export const MAX_EVENTS = 500;

export type Event = Record<string, unknown>;
export type Row = Record<string, unknown>;

export const num = (value: unknown, fallback = 0): number =>
  typeof value === "number" ? value : Number.isFinite(Number(value)) ? Number(value) : fallback;

export const bool = (value: unknown, fallback = false): boolean =>
  typeof value === "boolean" ? value : fallback;

export const str = (value: unknown, fallback = ""): string =>
  typeof value === "string" ? value : fallback;

export const obj = (value: unknown): Record<string, unknown> =>
  value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};

export const list = (value: unknown): unknown[] => (Array.isArray(value) ? value : []);

/** "enemy / skill" (or "status: id") for what ended a defeat; null otherwise. */
export const killedByLabel = (cause: unknown): string | null => {
  const row = obj(cause);
  const kind = str(row.kind);
  if (kind === "enemy_skill") {
    return `${str(row.source_unit_id) || "?"} / ${str(row.source_skill_id) || "?"}`;
  }
  if (kind === "status") {
    return `status: ${str(row.status_id) || "?"}`;
  }
  return null;
};

/** The columns a `run_started` event owns. Immutable, so it is insert-only. */
export const runStartRow = (runId: string, started: Event): Row => ({
  run_id: runId,
  player_anon_id: str(started.player_anon_id) || null,
  balance_hash: str(started.balance_hash) || null,
  game_version: str(started.game_version) || null,
  is_debug_build: bool(started.is_debug_build),
  ally_lineup: list(started.ally_lineup),
  starting_deck: started.decklist ?? null,
  config_snapshot: started.config ?? null,
  // {} keeps the column's default when a client from before the flag registry uploads.
  flags: started.flags && typeof started.flags === "object" ? started.flags : {},
  run_seed: started.run_seed ?? null,
  player_run_number: started.player_run_number ?? null,
  started_at: started.t ?? null,
});

/** The columns a `run_ended` event owns. Deliberately no start column here. */
export const runEndRow = (runId: string, ended: Event): Row => ({
  run_id: runId,
  was_debug_tainted: bool(ended.was_debug_tainted),
  abandoned: bool(ended.abandoned),
  victory: bool(ended.victory),
  end_reason: str(ended.end_reason) || null,
  final_wave: ended.final_wave ?? null,
  total_turns: ended.total_turns ?? null,
  total_decisions: ended.total_decisions ?? null,
  killed_by: killedByLabel(ended.killed_by),
  ended_at: ended.t ?? null,
});

/** The columns a `turn_started` event owns, for its (run, turn) row. */
export const turnStartRow = (runId: string, started: Event): Row => {
  const metrics = obj(started.metrics);
  return {
    run_id: runId,
    turn_number: num(started.turn_number, -1),
    wave_index: started.wave_index ?? null,
    dice_sides: started.dice_sides ?? null,
    active_enemy_ids: list(started.active_enemy_ids),
    ally_hp_pct_start: metrics.ally_hp_pct ?? null,
    enemy_hp_pct_start: metrics.enemy_hp_pct ?? null,
    incoming_intent_damage: metrics.incoming_intent_damage ?? null,
    threat_ratio: metrics.threat_ratio ?? null,
    intents_json: started.intents ?? null,
    hand_start_json: started.hand ?? null,
  };
};

/** The columns a `turn_ended` event owns, for its (run, turn) row. */
export const turnEndRow = (runId: string, ended: Event): Row => {
  const outcome = obj(ended.outcome);
  return {
    run_id: runId,
    turn_number: num(ended.turn_number, -1),
    unused_actions: ended.unused_actions ?? null,
    unused_merges: ended.unused_merges ?? null,
    damage_dealt: outcome.damage_dealt ?? null,
    hp_lost: outcome.hp_lost ?? null,
    shield_blocked: outcome.shield_gained ?? null,
    merges_made: outcome.merges_made ?? null,
    converts_made: outcome.converts_made ?? null,
    player_skills_used: list(outcome.player_skills_used),
    player_ultimates_cast: list(outcome.player_ultimates_cast),
    enemy_damage_json: Array.isArray(outcome.enemy_damage_events) ? outcome.enemy_damage_events : null,
  };
};

/** One player decision row, with the board state *before* it happened. */
export const decisionRow = (event: Event): Row => {
  const metrics = obj(obj(event.context).metrics);
  const offered = obj(event.offered);
  const chosen = obj(event.chosen);
  const card = obj(chosen.card);
  return {
    event_id: str(event.event_id),
    run_id: str(event.run_id),
    turn_number: num(event.turn_number),
    wave_index: event.wave_index ?? null,
    decision_index: event.decision_index ?? null,
    decision_type: str(event.decision_type),
    thinking_time_ms: event.thinking_time_ms ?? null,
    actor_unit_id: str(chosen.target_ally_id || chosen.caster_id) || null,
    skill_id: str(chosen.skill_id || chosen.ultimate_skill_id) || null,
    card_key: str(card.key) || null,
    card_effective_value: card.effective_value ?? null,
    card_is_odd: card.parity ? str(card.parity) === "odd" : null,
    card_merge_rank: card.merge_rank ?? null,
    offered_skills: list(offered.playable_skill_ids),
    offered_card_keys: list(offered.offered_card_keys),
    ready_ultimate_skills: list(offered.ready_ultimate_skills),
    active_enemy_ids: list(offered.active_enemy_ids),
    intent_max_roll: offered.intent_max_roll ?? null,
    intent_condition_met: bool(offered.intent_condition_met),
    intent_ult_imminent: bool(offered.intent_ultimate_imminent),
    ally_hp_pct_before: metrics.ally_hp_pct ?? null,
    enemy_hp_pct_before: metrics.enemy_hp_pct ?? null,
    threat_ratio_before: metrics.threat_ratio ?? null,
    offered_options: event.offered ?? null,
    chosen_payload: event.chosen ?? null,
    immediate_outcome: event.outcome ?? null,
    recorded_at: event.t ?? null,
  };
};

export type BatchRows = {
  balance: Row[];
  runStarts: Row[];
  runEnds: Row[];
  turnStarts: Row[];
  turnEnds: Row[];
  decisions: Row[];
};

/**
 * Every row one POST batch produces, grouped by the half of the record that owns it.
 *
 * `runStarts` / `turnStarts` are insert-only (start metadata never changes), while
 * `runEnds` / `turnEnds` update the result columns of the row the earlier batch
 * inserted. A batch that carries only one half therefore leaves the other half of
 * the record exactly as it was.
 */
export const collectBatch = (events: Event[]): BatchRows => {
  const balance = new Map<string, Row>();
  const runs = new Map<string, { started?: Event; ended?: Event }>();
  const turns = new Map<string, { started?: Event; ended?: Event }>();
  const decisions: Row[] = [];

  for (const event of events) {
    if (num(event.schema_version, 0) !== SCHEMA_VERSION) continue;
    const runId = str(event.run_id);
    if (!runId) continue;
    const type = str(event.type);
    if (type === "run_started") {
      const hash = str(event.balance_hash);
      if (hash) {
        balance.set(hash, {
          balance_hash: hash,
          game_version: str(event.game_version),
          config_snapshot: event.config ?? null,
        });
      }
      runs.set(runId, { ...(runs.get(runId) ?? {}), started: event });
    } else if (type === "run_ended") {
      runs.set(runId, { ...(runs.get(runId) ?? {}), ended: event });
    } else if (type === "turn_started" || type === "turn_ended") {
      // One cell per (run, turn): the two events are merged onto a single row.
      const key = `${runId}|${num(event.turn_number, -1)}`;
      const cell = turns.get(key) ?? {};
      if (type === "turn_started") {
        cell.started = event;
      } else {
        cell.ended = event;
      }
      turns.set(key, cell);
    } else if (type === "decision") {
      decisions.push(decisionRow(event));
    }
  }

  const runStarts: Row[] = [];
  const runEnds: Row[] = [];
  for (const [runId, group] of runs.entries()) {
    if (group.started) runStarts.push(runStartRow(runId, group.started));
    if (group.ended) runEnds.push(runEndRow(runId, group.ended));
  }

  const turnStarts: Row[] = [];
  const turnEnds: Row[] = [];
  for (const cell of turns.values()) {
    const runId = str(cell.started?.run_id ?? cell.ended?.run_id);
    if (!runId) continue;
    if (cell.started) turnStarts.push(turnStartRow(runId, cell.started));
    if (cell.ended) turnEnds.push(turnEndRow(runId, cell.ended));
  }

  return {
    balance: [...balance.values()],
    runStarts,
    runEnds,
    turnStarts,
    turnEnds,
    decisions,
  };
};
