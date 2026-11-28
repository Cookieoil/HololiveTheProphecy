// Unit tests for the pure row-building layer behind the telemetry ingest.
//
// They exist because of one bug class: a run's events are POSTed in batches of at
// most MAX_EVENTS, so one batch can carry only half a run. If either half built a
// whole row, the upsert would blank the other half's columns - an end-only batch
// erasing the balance hash (detaching the run from its balance patch), or a
// start-only batch recording a still-running battle as `victory = false`.
//
// Run with:  node --test "Server/supabase/functions/telemetry-ingest/*.test.ts"

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  collectBatch,
  decisionRow,
  runEndRow,
  runStartRow,
  SCHEMA_VERSION,
  turnEndRow,
  turnStartRow,
} from "./rows.ts";
import type { Event } from "./rows.ts";

const RUN_ID = "11111111-2222-3333-4444-555555555555";

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
  offered: {
    playable_skill_ids: ["striker_1"],
    offered_card_keys: ["3"],
    active_enemy_ids: ["normal_enemy"],
  },
  chosen: { skill_id: "striker_1", card: { key: "3", parity: "odd" } },
  outcome: {},
  t: 150,
});

test("a run start row carries no result column", () => {
  const row = runStartRow(RUN_ID, runStarted());
  assert.equal(row.balance_hash, "hash-a");
  assert.equal(row.run_seed, 4242);
  assert.equal(row.flags && (row.flags as Event).exp, true);
  // The result half must be absent, so an insert-only upsert cannot blank it later.
  for (const column of ["victory", "abandoned", "was_debug_tainted", "end_reason", "ended_at"]) {
    assert.equal(column in row, false, `start row must not own ${column}`);
  }
});

test("a run end row carries no start column", () => {
  const row = runEndRow(RUN_ID, runEnded());
  assert.equal(row.victory, true);
  assert.equal(row.end_reason, "final_wave_cleared");
  // These are the columns the old whole-row upsert used to blank on an end-only batch.
  for (const column of ["balance_hash", "player_anon_id", "run_seed", "flags", "started_at"]) {
    assert.equal(column in row, false, `end row must not own ${column}`);
  }
});

test("an end-only batch never rewrites the run's start columns", () => {
  const rows = collectBatch([runEnded()]);
  assert.equal(rows.runStarts.length, 0);
  assert.equal(rows.runEnds.length, 1);
});

test("a start-only batch never records a result", () => {
  const rows = collectBatch([runStarted()]);
  assert.equal(rows.runStarts.length, 1);
  assert.equal(rows.runEnds.length, 0);
  assert.equal("victory" in rows.runStarts[0], false);
});

test("a batch carrying both halves writes both", () => {
  const rows = collectBatch([runStarted(), runEnded()]);
  assert.equal(rows.runStarts.length, 1);
  assert.equal(rows.runEnds.length, 1);
  assert.equal(rows.balance.length, 1);
});

test("a turn split across two batches keeps both halves", () => {
  const startOnly = collectBatch([turnStarted(0)]);
  assert.equal(startOnly.turnStarts.length, 1);
  assert.equal(startOnly.turnEnds.length, 0);

  const endOnly = collectBatch([turnEnded(0)]);
  assert.equal(endOnly.turnStarts.length, 0);
  assert.equal(endOnly.turnEnds.length, 1);
});

test("a turn's two events merge onto one row", () => {
  const rows = collectBatch([turnStarted(0), turnEnded(0)]);
  assert.equal(rows.turnStarts.length, 1);
  assert.equal(rows.turnEnds.length, 1);
  assert.equal(rows.turnStarts[0].turn_number, 0);
  assert.equal(rows.turnStarts[0].ally_hp_pct_start, 0.8);
  assert.equal(rows.turnEnds[0].turn_number, 0);
  assert.equal(rows.turnEnds[0].damage_dealt, 9);
  // The end half owns no start column, so the merged row keeps the snapshot.
  assert.equal("ally_hp_pct_start" in rows.turnEnds[0], false);
});

test("a turn start row carries no outcome column", () => {
  const row = turnStartRow(RUN_ID, turnStarted(0));
  assert.equal(row.dice_sides, 6);
  assert.equal("damage_dealt" in row, false);
  assert.equal("unused_actions" in row, false);
});

test("a turn end row carries no start column", () => {
  const row = turnEndRow(RUN_ID, turnEnded(0));
  assert.equal(row.damage_dealt, 9);
  assert.equal("ally_hp_pct_start" in row, false);
  assert.equal("hand_start_json" in row, false);
});

test("events from another schema version are ignored", () => {
  const rows = collectBatch([
    { ...runStarted(), schema_version: 99 },
    { ...decision(), schema_version: 99 },
  ]);
  assert.equal(rows.runStarts.length, 0);
  assert.equal(rows.runEnds.length, 0);
  assert.equal(rows.decisions.length, 0);
});

test("a decision carries its event id and the offered set", () => {
  const rows = collectBatch([decision()]);
  assert.equal(rows.decisions.length, 1);
  assert.equal(rows.decisions[0].event_id, "99999999-8888-7777-6666-555555555555");
  assert.equal(rows.decisions[0].decision_type, "play_card");
  assert.deepEqual(rows.decisions[0].offered_skills, ["striker_1"]);
  assert.equal(rows.decisions[0].card_is_odd, true);
});

test("a turn-only batch produces the run skeleton its rows point at", () => {
  // No run_started and no run_ended in this batch: telemetry_turns.run_id would have
  // nothing to reference, so the parent key is inserted first (see writesFor).
  const rows = collectBatch([turnStarted(0), decision()]);
  assert.deepEqual(rows.runSkeletons, [{ run_id: RUN_ID }]);
  assert.equal(rows.runStarts.length, 0);
  assert.equal(rows.runEnds.length, 0);
});

test("a batch that starts or ends the run needs no skeleton", () => {
  // Those writes create the row themselves, so a skeleton would only add a no-op insert.
  assert.equal(collectBatch([runStarted()]).runSkeletons.length, 0);
  assert.equal(collectBatch([runEnded()]).runSkeletons.length, 0);
  assert.equal(collectBatch([runStarted(), runEnded(), turnStarted(0)]).runSkeletons.length, 0);
});

test("sub_prompts travel with the offer, at the path the views read", () => {
  // v_target_priority reads `offered_options -> 'sub_prompts'`, while the recorder writes
  // `sub_prompts` beside `offered` - dropping the sibling left that view empty.
  const prompt = {
    prompt: "pick_target",
    candidates: [{ unit_id: "boss_enemy" }],
    picked: [{ unit_id: "boss_enemy" }],
  };
  const row = decisionRow({ ...decision(), sub_prompts: [prompt] });
  const offered = row.offered_options as Event;

  assert.deepEqual(offered.sub_prompts, [prompt]);
  // ...and the offered set is still there beside it.
  assert.deepEqual(offered.playable_skill_ids, ["striker_1"]);
});

test("a decision with no prompts keeps an empty list, never a missing key", () => {
  const offered = decisionRow(decision()).offered_options as Event;
  assert.deepEqual(offered.sub_prompts, []);
});

test("a decision with neither an offer nor prompts stores nothing", () => {
  const bare: Event = {
    type: "decision",
    schema_version: SCHEMA_VERSION,
    run_id: RUN_ID,
    event_id: "eeeeeeee-0000-0000-0000-000000000000",
  };
  assert.equal(decisionRow(bare).offered_options, null);
});
