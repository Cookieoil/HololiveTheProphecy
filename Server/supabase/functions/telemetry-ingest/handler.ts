// HTTP handler for the telemetry-ingest Edge Function.
//
// index.ts is only the Deno entrypoint: it owns `Deno.serve` and the Supabase client
// import. Every rule - the status codes, the envelope validation and the exact order
// the tables are written in - lives here, behind a two-method dependency seam:
//
//   getEnv(name)       -> string | undefined   (Deno.env.get in production)
//   createDb(url, key) -> DbClient             (createClient in production)
//
// That seam is what lets handler.test.ts drive the real request/response path with
// `node --test`: every status code, the upsert order, and a stateful fake that
// replays two batches of one run to prove neither half erases the other. No Deno, no
// network, no database.
//
//   node --test "Server/supabase/functions/telemetry-ingest/*.test.ts"
//   deno check  Server/supabase/functions/telemetry-ingest/index.ts

import { collectBatch, MAX_EVENTS } from "./rows.ts";
import type { Event, Row } from "./rows.ts";

/** The options a write may carry; `ignoreDuplicates` false means "update on conflict". */
export type UpsertOptions = {
  onConflict: string;
  ignoreDuplicates: boolean;
};

/**
 * The only two methods of `SupabaseClient` this function uses, so a test can pass an
 * in-memory fake and production can pass the real client.
 */
export type DbClient = {
  from(table: string): {
    upsert(
      rows: Row[],
      options: UpsertOptions,
    ): PromiseLike<{ error: { message: string } | null }>;
  };
};

/** What the handler needs from its environment. */
export type IngestDeps = {
  getEnv: (name: string) => string | undefined;
  createDb: (url: string, key: string) => DbClient;
};

/** The batch size the Edge function accepts, re-exported so a test can pin it. */
export const MAX_BATCH: number = MAX_EVENTS;

/** One ordered write: the table, its conflict target, and whether a retry may update. */
export type Write = {
  table: string;
  rows: Row[];
  options: UpsertOptions;
};

const json = (body: unknown, status = 200): Response =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

/**
 * The exact order the tables must be written in.
 *
 * A run's events can straddle the batch boundary, so a batch may hold only one half of
 * a record. Start halves are therefore insert-only (`ignoreDuplicates`) and come
 * *before* the matching end half, which updates only its own columns - that is what
 * stops the later half blanking the earlier one. Writing the start half first also
 * means the row an end half updates always exists, so the foreign keys resolve.
 */
export const writesFor = (rows: ReturnType<typeof collectBatch>): Write[] => [
  {
    table: "balance_versions",
    rows: rows.balance,
    options: { onConflict: "balance_hash", ignoreDuplicates: true },
  },
  {
    table: "telemetry_runs",
    rows: rows.runStarts,
    options: { onConflict: "run_id", ignoreDuplicates: true },
  },
  {
    table: "telemetry_runs",
    rows: rows.runEnds,
    options: { onConflict: "run_id", ignoreDuplicates: false },
  },
  {
    table: "telemetry_turns",
    rows: rows.turnStarts,
    options: { onConflict: "run_id,turn_number", ignoreDuplicates: true },
  },
  {
    table: "telemetry_turns",
    rows: rows.turnEnds,
    options: { onConflict: "run_id,turn_number", ignoreDuplicates: false },
  },
  {
    table: "telemetry_decisions",
    rows: rows.decisions,
    options: { onConflict: "event_id", ignoreDuplicates: true },
  },
];

/**
 * Builds the request handler: validate the envelope, materialise the rows the SQL
 * views need, write them in order. A database error aborts the batch with a 500 so the
 * client keeps the file queued and retries it, which is safe because every write is
 * idempotent.
 */
export const createIngestHandler =
  (deps: IngestDeps) =>
  async (request: Request): Promise<Response> => {
    if (request.method !== "POST") return json({ error: "POST only" }, 405);

    const url = deps.getEnv("SUPABASE_URL");
    const key = deps.getEnv("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !key) return json({ error: "server not configured" }, 500);

    let payload: { events?: unknown };
    try {
      payload = await request.json();
    } catch {
      return json({ error: "invalid JSON body" }, 400);
    }

    const events = Array.isArray(payload.events) ? payload.events as Event[] : [];
    if (events.length === 0) return json({ stored: { decisions: 0 } });
    if (events.length > MAX_BATCH) return json({ error: "batch too large" }, 413);

    const db = deps.createDb(url, key);
    const rows = collectBatch(events);

    for (const write of writesFor(rows)) {
      if (write.rows.length === 0) continue;
      const { error } = await db.from(write.table).upsert(write.rows, write.options);
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
  };
