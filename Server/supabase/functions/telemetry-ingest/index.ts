// Supabase Edge Function: telemetry batch ingest.
//
// The Godot client (Core/Telemetry/HttpBatchSink.gd, Stage 2) POSTs the batches
// it spooled locally:
//
//   POST /functions/v1/telemetry-ingest
//   { "events": [ { "type": "run_started", ... }, ... ] }
//
// The function validates the envelope, materialises the rows the SQL views need
// and upserts them. Every insert is idempotent, so a retried batch after a
// dropped connection can never double count a decision.
//
// Deploy:  supabase functions deploy telemetry-ingest

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SCHEMA_VERSION = 1;
const MAX_EVENTS = 500;

type Event = Record<string, unknown>;

const json = (body: unknown, status = 200): Response =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const num = (value: unknown, fallback = 0): number =>
  typeof value === "number" ? value : Number.isFinite(Number(value)) ? Number(value) : fallback;

const bool = (value: unknown, fallback = false): boolean =>
  typeof value === "boolean" ? value : fallback;

const str = (value: unknown, fallback = ""): string =>
  typeof value === "string" ? value : fallback;

const obj = (value: unknown): Record<string, unknown> =>
  value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};

/** "enemy / skill" (or "status: id") for what ended a defeat; null otherwise. */
const killedByLabel = (cause: unknown): string | null => {
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

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return json({ error: "POST only" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return json({ error: "server not configured" }, 500);

  let payload: { events?: unknown };
  try {
    payload = await request.json();
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }

  const events = Array.isArray(payload.events) ? payload.events as Event[] : [];
  if (events.length === 0) return json({ stored: { decisions: 0 } });
  if (events.length > MAX_EVENTS) return json({ error: "batch too large" }, 413);

  const db = createClient(url, key, { auth: { persistSession: false } });

  const balance = new Map<string, Event>();
  const runs = new Map<string, Event[]>();
  // One cell per (run, turn): `turn_started` and `turn_ended` are merged so a
  // single row carries both the start-of-turn state and the turn's outcome.
  const turns = new Map<string, { started: Event | null; ended: Event | null }>();
  const decisions: Event[] = [];

  for (const event of events) {
    if (num(event.schema_version, 0) !== SCHEMA_VERSION) continue;
    const runId = str(event.run_id);
    if (!runId) continue;
    const turnKey = `${runId}|${num(event.turn_number, -1)}`;
    switch (str(event.type)) {
      case "run_started": {
        const hash = str(event.balance_hash);
        if (hash) {
          balance.set(hash, {
            balance_hash: hash,
            game_version: str(event.game_version),
            config_snapshot: event.config ?? null,
          });
        }
        runs.set(runId, [...(runs.get(runId) ?? []), event]);
        break;
      }
      case "turn_started": {
        const cell = turns.get(turnKey) ?? { started: null, ended: null };
        cell.started = event;
        turns.set(turnKey, cell);
        break;
      }
      case "turn_ended": {
        const cell = turns.get(turnKey) ?? { started: null, ended: null };
        cell.ended = event;
        turns.set(turnKey, cell);
        break;
      }
      case "decision":
        decisions.push(event);
        break;
      case "run_ended":
        runs.set(runId, [...(runs.get(runId) ?? []), event]);
        break;
      default:
        break;
    }
  }

  if (balance.size > 0) {
    const { error } = await db.from("balance_versions")
      .upsert([...balance.values()], { onConflict: "balance_hash", ignoreDuplicates: true });
    if (error) return json({ error: error.message }, 500);
  }

  const runRows = [...runs.entries()].map(([run_id, group]) => {
    const started = group.find((e) => str(e.type) === "run_started") ?? {};
    const ended = group.find((e) => str(e.type) === "run_ended") ?? {};
    return {
      run_id,
      player_anon_id: str(started.player_anon_id) || null,
      balance_hash: str(started.balance_hash) || null,
      game_version: str(started.game_version) || null,
      is_debug_build: bool(started.is_debug_build),
      was_debug_tainted: bool(ended.was_debug_tainted),
      abandoned: bool(ended.abandoned),
      ally_lineup: Array.isArray(started.ally_lineup) ? started.ally_lineup : [],
      starting_deck: started.decklist ?? null,
      config_snapshot: started.config ?? null,
      // The staged flags that were ON for this run; {} keeps the column's default
      // when a client from before the flag registry uploads.
      flags: started.flags && typeof started.flags === "object" ? started.flags : {},
      victory: bool(ended.victory),
      end_reason: str(ended.end_reason) || null,
      final_wave: ended.final_wave ?? null,
      total_turns: ended.total_turns ?? null,
      total_decisions: ended.total_decisions ?? null,
      run_seed: started.run_seed ?? null,
      player_run_number: started.player_run_number ?? null,
      killed_by: killedByLabel(ended.killed_by),
      started_at: started.t ?? null,
      ended_at: ended.t ?? null,
    };
  });
  if (runRows.length > 0) {
    const { error } = await db.from("telemetry_runs").upsert(runRows, { onConflict: "run_id" });
    if (error) return json({ error: error.message }, 500);
  }

  const turnRows = [...turns.values()].map((cell) => {
    const started = cell.started ?? {};
    const ended = cell.ended ?? {};
    const runId = str(started.run_id || ended.run_id);
    const metrics = obj(started.metrics);
    const outcome = obj(ended.outcome);
    return {
      run_id: runId,
      turn_number: num(started.turn_number ?? ended.turn_number),
      wave_index: started.wave_index ?? ended.wave_index ?? null,
      dice_sides: started.dice_sides ?? null,
      active_enemy_ids: Array.isArray(started.active_enemy_ids) ? started.active_enemy_ids : [],
      ally_hp_pct_start: metrics.ally_hp_pct ?? null,
      enemy_hp_pct_start: metrics.enemy_hp_pct ?? null,
      incoming_intent_damage: metrics.incoming_intent_damage ?? null,
      threat_ratio: metrics.threat_ratio ?? null,
      unused_actions: ended.unused_actions ?? null,
      unused_merges: ended.unused_merges ?? null,
      damage_dealt: outcome.damage_dealt ?? null,
      hp_lost: outcome.hp_lost ?? null,
      shield_blocked: outcome.shield_gained ?? null,
      merges_made: outcome.merges_made ?? null,
      converts_made: outcome.converts_made ?? null,
      player_skills_used: Array.isArray(outcome.player_skills_used) ? outcome.player_skills_used : [],
      player_ultimates_cast: Array.isArray(outcome.player_ultimates_cast) ? outcome.player_ultimates_cast : [],
      intents_json: started.intents ?? null,
      hand_start_json: started.hand ?? null,
      enemy_damage_json: Array.isArray(outcome.enemy_damage_events) ? outcome.enemy_damage_events : null,
    };
  });
  if (turnRows.length > 0) {
    const { error } = await db.from("telemetry_turns")
      .upsert(turnRows, { onConflict: "run_id,turn_number" });
    if (error) return json({ error: error.message }, 500);
  }

  const decisionRows = decisions.map((event) => {
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
      offered_skills: Array.isArray(offered.playable_skill_ids) ? offered.playable_skill_ids : [],
      offered_card_keys: Array.isArray(offered.offered_card_keys) ? offered.offered_card_keys : [],
      ready_ultimate_skills: Array.isArray(offered.ready_ultimate_skills)
        ? offered.ready_ultimate_skills : [],
      active_enemy_ids: Array.isArray(offered.active_enemy_ids) ? offered.active_enemy_ids : [],
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
  });
  if (decisionRows.length > 0) {
    const { error } = await db.from("telemetry_decisions")
      .upsert(decisionRows, { onConflict: "event_id", ignoreDuplicates: true });
    if (error) return json({ error: error.message }, 500);
  }

  return json({
    stored: {
      balance_versions: balance.size,
      runs: runRows.length,
      turns: turnRows.length,
      decisions: decisionRows.length,
    },
  });
});

