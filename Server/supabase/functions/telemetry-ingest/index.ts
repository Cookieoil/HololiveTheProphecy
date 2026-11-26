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
  const turns = new Map<string, Event[]>();
  const decisions: Event[] = [];

  for (const event of events) {
    if (num(event.schema_version, 0) !== SCHEMA_VERSION) continue;
    const runId = str(event.run_id);
    if (!runId) continue;
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
      case "turn_started":
        turns.set(runId, [...(turns.get(runId) ?? []), event]);
        break;
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
      ally_lineup: Array.isArray(started.ally_lineup) ? started.ally_lineup : [],
      starting_deck: started.decklist ?? null,
      config_snapshot: started.config ?? null,
      victory: bool(ended.victory),
      end_reason: str(ended.end_reason) || null,
      final_wave: ended.final_wave ?? null,
      total_turns: ended.total_turns ?? null,
      total_decisions: ended.total_decisions ?? null,
      started_at: started.t ?? null,
      ended_at: ended.t ?? null,
    };
  });
  if (runRows.length > 0) {
    const { error } = await db.from("telemetry_runs").upsert(runRows, { onConflict: "run_id" });
    if (error) return json({ error: error.message }, 500);
  }

  const turnRows = [...turns.entries()].flatMap(([run_id, group]) =>
    group.map((event) => {
      const metrics = obj(event.metrics);
      const outcome = obj(event.outcome);
      return {
        run_id,
        turn_number: num(event.turn_number),
        wave_index: event.wave_index ?? null,
        dice_sides: event.dice_sides ?? null,
        ally_hp_pct_start: metrics.ally_hp_pct ?? null,
        enemy_hp_pct_start: metrics.enemy_hp_pct ?? null,
        incoming_intent_damage: metrics.incoming_intent_damage ?? null,
        threat_ratio: metrics.threat_ratio ?? null,
        unused_actions: event.unused_actions ?? null,
        unused_merges: event.unused_merges ?? null,
        damage_dealt: outcome.damage_dealt ?? null,
        hp_lost: outcome.hp_lost ?? null,
        shield_blocked: outcome.shield_gained ?? null,
        intents_json: event.intents ?? null,
        hand_start_json: event.hand ?? null,
      };
    })
  );
  if (turnRows.length > 0) {
    const { error } = await db.from("telemetry_turns")
      .upsert(turnRows, { onConflict: "run_id,turn_number" });
    if (error) return json({ error: error.message }, 500);
  }

  const decisionRows = decisions.map((event) => {
    const metrics = obj(obj(event.context).metrics);
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
      card_effective_value: card.effective_value ?? null,
      card_is_odd: card.parity ? str(card.parity) === "odd" : null,
      card_merge_rank: card.merge_rank ?? null,
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

