// Behaviour tests for the telemetry-ingest HTTP handler (./handler.ts).
//
// They drive the real `Request`/`Response` path with a fake environment and a stateful
// in-memory database, so the whole server-side contract is executable offline with no
// Deno, no network and no database:
//
// - every status code (405 / 400 / 413 / 500 / 200),
// - the exact table and conflict order, and which halves are insert-only,
// - and the bug the ordering exists for: one run split across two batches must come
//   out with *both* halves of its record intact.
//
// Run with:  node --test "Server/supabase/functions/telemetry-ingest/*.test.ts"

import assert from "node:assert/strict";
import { test } from "node:test";
import { createIngestHandler, MAX_BATCH } from "./handler.ts";
import type { DbClient, IngestDeps, UpsertOptions } from "./handler.ts";
import { SCHEMA_VERSION } from "./rows.ts";
import type { Event, Row } from "./rows.ts";

const RUN_ID = "11111111-2222-3333-4444-555555555555";
const URL = "https://fn.invalid/functions/v1/telemetry-ingest";

const runStarted = (): Event => ({
  type: "run_started",
  schema_version: SCHEMA_VERSION,
  run_id: RUN_ID,
  player_anon_id: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
  balance_hash: "hash-a",
  game_version: "0.1.0",
  is_debug_build: false,
  ally_lineup: ["striker", "healer", "buff"],
  decklist: [[2, 7]],
  config: { hand_size: 7 },
  flags: { exp: true },
  run_seed: 4242,
  player_run_number: 3,
  t: 100,
});

const runEnded = (): Event => ({
  type: "run_ended",
  schema_version: SCHEMA_VERSION,
  run_id: RUN_ID,
  victory: true,
  abandoned: false,
  was_debug_tainted: false,
  end_reason: "final_wave_cleared",
  final_wave: 1,
  total_turns: 5,
  total_decisions: 12,
  killed_by: null,
  t: 200,
});

const turnStarted = (turn: number): Event => ({
  type: "turn_started",
  schema_version: SCHEMA_VERSION,
  run_id: RUN_ID,
  turn_number: turn,
  wave_index: 0,
  dice_sides: 6,
  active_enemy_ids: ["normal_enemy"],
  metrics: { ally_hp_pct: 0.8, enemy_hp_pct: 1.0, threat_ratio: 0.2, incoming_intent_damage: 3 },
  intents: [{ enemy_id: "normal_enemy" }],
  hand: [{ key: "3" }],
});

const turnEnded = (turn: number): Event => ({
  type: "turn_ended",
  schema_version: SCHEMA_VERSION,
  run_id: RUN_ID,
  turn_number: turn,
  unused_actions: 1,
  unused_merges: 0,
  outcome: {
    damage_dealt: 9,
    hp_lost: 2,
    shield_gained: 4,
    merges_made: 1,
    converts_made: 0,
    player_skills_used: ["striker_1"],
    player_ultimates_cast: [],
    enemy_damage_events: [{ enemy_id: "normal_enemy" }],
  },
});

const decision = (): Event => ({
  type: "decision",
  schema_version: SCHEMA_VERSION,
  run_id: RUN_ID,
  turn_number: 0,
  event_id: "99999999-8888-7777-6666-555555555555",
  decision_type: "play_card",
  context: { metrics: { ally_hp_pct: 0.8 } },
  offered: { playable_skill_ids: ["striker_1"], offered_card_keys: ["3"], active_enemy_ids: ["normal_enemy"] },
  chosen: { skill_id: "striker_1", card: { key: "3", parity: "odd" } },
  outcome: {},
  t: 150,
});

/** One recorded write, so a test can assert the order and the options. */
type Call = { table: string; options: UpsertOptions; rows: Row[] };

/**
 * An in-memory stand-in for the two conflict behaviours the real database provides:
 * ON CONFLICT DO NOTHING for an insert-only write, and a column-level DO UPDATE
 * otherwise. Without that distinction a test could not tell the two halves of a record
 * apart, which is exactly the bug the ordering in handler.ts exists to prevent.
 */
class FakeDb {
  calls: Call[] = [];
  tables: Record<string, Map<string, Row>> = {};
  /** When set to a table name, that table's write fails, so the abort path is reachable. */
  failOn: string | null = null;

  private keys: Record<string, string[]> = {
    balance_versions: ["balance_hash"],
    telemetry_runs: ["run_id"],
    telemetry_turns: ["run_id", "turn_number"],
    telemetry_decisions: ["event_id"],
  };

  asClient(): DbClient {
    return {
      from: (table: string) => ({
        upsert: async (rows: Row[], options: UpsertOptions) => {
          this.calls.push({ table, options, rows });
          if (this.failOn === table) return { error: { message: `write failed: ${table}` } };
          const store = this.tables[table] ?? (this.tables[table] = new Map<string, Row>());
          for (const row of rows) {
            const key = this.keyOf(table, row);
            const existing = store.get(key);
            if (!existing) {
              store.set(key, { ...row });
            } else if (!options.ignoreDuplicates) {
              // ON CONFLICT DO UPDATE: only the columns this write actually carries.
              store.set(key, { ...existing, ...row });
            }
          }
          return { error: null };
        },
      }),
    };
  }

  keyOf(table: string, row: Row): string {
    return (this.keys[table] ?? ["run_id"]).map((column) => String(row[column])).join("|");
  }

  row(table: string, key: string): Row {
    return this.tables[table]?.get(key) ?? {};
  }
}

const CONFIGURED: Record<string, string | undefined> = {
  SUPABASE_URL: "https://db.invalid",
  SUPABASE_SERVICE_ROLE_KEY: "service-role-key",
};

const deps = (db: FakeDb, env: Record<string, string | undefined> = CONFIGURED): IngestDeps => ({
  getEnv: (name: string) => env[name],
  createDb: () => db.asClient(),
});

const post = (events: unknown): Request =>
  new Request(URL, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ events }),
  });

const stored = async (response: Response): Promise<Record<string, unknown>> => {
  const body: unknown = await response.json();
  return (body as { stored?: Record<string, unknown> }).stored ?? {};
};

const errorOf = async (response: Response): Promise<string> => {
  const body: unknown = await response.json();
  return (body as { error?: string }).error ?? "";
};

test("a non-POST request is refused without touching the database", async () => {
  const db = new FakeDb();
  const response = await createIngestHandler(deps(db))(new Request(URL, { method: "GET" }));
  assert.equal(response.status, 405);
  assert.equal(db.calls.length, 0);
});

test("a server with no configuration is reported", async () => {
  const db = new FakeDb();
  const response = await createIngestHandler(deps(db, {}))(post([runStarted()]));
  assert.equal(response.status, 500);
  assert.equal(await errorOf(response), "server not configured");
  assert.equal(db.calls.length, 0);
});

test("an unparsable body is refused", async () => {
  const db = new FakeDb();
  const request = new Request(URL, { method: "POST", body: "{" });
  const response = await createIngestHandler(deps(db))(request);
  assert.equal(response.status, 400);
  assert.equal(await errorOf(response), "invalid JSON body");
  assert.equal(db.calls.length, 0);
});

test("an empty batch short-circuits with no writes", async () => {
  const db = new FakeDb();
  const response = await createIngestHandler(deps(db))(post([]));
  assert.equal(response.status, 200);
  assert.deepEqual(await stored(response), { decisions: 0 });
  assert.equal(db.calls.length, 0);
});

test("an oversized batch is refused", async () => {
  const db = new FakeDb();
  const events = Array.from({ length: MAX_BATCH + 1 }, () => decision());
  const response = await createIngestHandler(deps(db))(post(events));
  assert.equal(response.status, 413);
  assert.equal(await errorOf(response), "batch too large");
  assert.equal(db.calls.length, 0);
});

test("the tables are written in the documented order", async () => {
  const db = new FakeDb();
  const response = await createIngestHandler(deps(db))(
    post([runStarted(), turnStarted(0), turnEnded(0), runEnded(), decision()]),
  );

  assert.equal(response.status, 200);
  assert.deepEqual(
    db.calls.map((call) => [call.table, call.options.onConflict, call.options.ignoreDuplicates]),
    [
      ["balance_versions", "balance_hash", true],
      // The start half is insert-only and must come before the end half, which updates
      // the row it inserted - otherwise the end half would blank the start columns.
      ["telemetry_runs", "run_id", true],
      ["telemetry_runs", "run_id", false],
      ["telemetry_turns", "run_id,turn_number", true],
      ["telemetry_turns", "run_id,turn_number", false],
      ["telemetry_decisions", "event_id", true],
    ],
  );
});

test("one run split across two batches keeps every column", async () => {
  const db = new FakeDb();
  const handler = createIngestHandler(deps(db));

  // Batch 1 stops at the MAX_EVENTS boundary: the run's start and its turn's start.
  const first = await handler(post([runStarted(), turnStarted(0)]));
  assert.equal(first.status, 200);
  // Batch 2 carries the other halves, a whole POST later.
  const second = await handler(post([turnEnded(0), runEnded()]));
  assert.equal(second.status, 200);

  const run = db.row("telemetry_runs", RUN_ID);
  // The start half survived the later write...
  assert.equal(run.balance_hash, "hash-a");
  assert.equal(run.run_seed, 4242);
  assert.equal(run.player_anon_id, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee");
  assert.deepEqual(run.flags, { exp: true });
  assert.equal(run.started_at, 100);
  // ...and the end half still landed.
  assert.equal(run.victory, true);
  assert.equal(run.end_reason, "final_wave_cleared");
  assert.equal(run.ended_at, 200);

  const turn = db.row("telemetry_turns", `${RUN_ID}|0`);
  assert.equal(turn.ally_hp_pct_start, 0.8);
  assert.deepEqual(turn.hand_start_json, [{ key: "3" }]);
  assert.equal(turn.damage_dealt, 9);
  assert.equal(turn.unused_actions, 1);
  assert.deepEqual(turn.enemy_damage_json, [{ enemy_id: "normal_enemy" }]);
});

test("a database error aborts the batch with a 500 and stops the pipeline", async () => {
  const db = new FakeDb();
  db.failOn = "telemetry_turns";
  const response = await createIngestHandler(deps(db))(
    post([runStarted(), turnStarted(0), runEnded(), decision()]),
  );

  assert.equal(response.status, 500);
  assert.equal(await errorOf(response), "write failed: telemetry_turns");
  // The writes before the failure ran; nothing after it did.
  assert.deepEqual(db.calls.map((call) => call.table), [
    "balance_versions",
    "telemetry_runs",
    "telemetry_runs",
    "telemetry_turns",
  ]);
});

test("the response reports what was stored", async () => {
  const db = new FakeDb();
  const response = await createIngestHandler(deps(db))(
    post([runStarted(), turnStarted(0), turnEnded(0), runEnded(), decision()]),
  );
  assert.deepEqual(await stored(response), {
    balance_versions: 1,
    run_starts: 1,
    run_ends: 1,
    turn_starts: 1,
    turn_ends: 1,
    decisions: 1,
  });
});
