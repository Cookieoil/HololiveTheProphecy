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
// The row shapes live in ./rows.ts, so the mapping from an event to a row is a pure
// function that can be unit tested with no server and no network:
//   node --test Server/supabase/functions/telemetry-ingest/
//
// Deploy:  supabase functions deploy telemetry-ingest

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { collectBatch, MAX_EVENTS } from "./rows.ts";
import type { Event } from "./rows.ts";

const json = (body: unknown, status = 200): Response =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

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

  const rows = collectBatch(events);

  if (rows.balance.length > 0) {
    const { error } = await db.from("balance_versions")
      .upsert(rows.balance, { onConflict: "balance_hash", ignoreDuplicates: true });
    if (error) return json({ error: error.message }, 500);
  }

  // A run is written in two halves, each owning only its own columns, because a run's
  // events can straddle the MAX_EVENTS batch boundary. Insert-only start columns
  // first, then the result columns - so whichever half arrives later can never blank
  // the half that arrived earlier. (A full-row upsert from an end-only batch used to
  // erase the balance hash, seed, flags and player id, detaching the run from its
  // balance patch; from a start-only batch it used to record `victory = false` for a
  // battle still in progress.)
  if (rows.runStarts.length > 0) {
    const { error } = await db.from("telemetry_runs")
      .upsert(rows.runStarts, { onConflict: "run_id", ignoreDuplicates: true });
    if (error) return json({ error: error.message }, 500);
  }
  if (rows.runEnds.length > 0) {
    const { error } = await db.from("telemetry_runs")
      .upsert(rows.runEnds, { onConflict: "run_id" });
    if (error) return json({ error: error.message }, 500);
  }

  // The same two-halves rule for a turn: the start columns are insert-only and the
  // turn's outcome updates that row, so a turn split across two batches keeps both
  // its start-of-turn snapshot and its result.
  if (rows.turnStarts.length > 0) {
    const { error } = await db.from("telemetry_turns")
      .upsert(rows.turnStarts, { onConflict: "run_id,turn_number", ignoreDuplicates: true });
    if (error) return json({ error: error.message }, 500);
  }
  if (rows.turnEnds.length > 0) {
    const { error } = await db.from("telemetry_turns")
      .upsert(rows.turnEnds, { onConflict: "run_id,turn_number" });
    if (error) return json({ error: error.message }, 500);
  }

  if (rows.decisions.length > 0) {
    const { error } = await db.from("telemetry_decisions")
      .upsert(rows.decisions, { onConflict: "event_id", ignoreDuplicates: true });
    if (error) return json({ error: error.message }, 500);
  }

  return json({
    stored: {
      balance_versions: rows.balance.length,
      run_starts: rows.runStarts.length,
      run_ends: rows.runEnds.length,
      turn_starts: rows.turnStarts.length,
      turn_ends: rows.turnEnds.length,
      decisions: rows.decisions.length,
    },
  });
});

