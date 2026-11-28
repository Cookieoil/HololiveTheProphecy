// Supabase Edge Function: telemetry batch ingest.
//
// The Godot client (Core/Telemetry/HttpBatchSink.gd, Stage 2) POSTs the batches
// it spooled locally:
//
//   POST /functions/v1/telemetry-ingest
//   { "events": [ { "type": "run_started", ... }, ... ] }
//
// This file is only the Deno entrypoint. The HTTP rules and the write order live in
// ./handler.ts and the row shapes in ./rows.ts, so both can be exercised offline with
// no Deno, no network and no database:
//
//   node --test "Server/supabase/functions/telemetry-ingest/*.test.ts"  # behaviour
//   deno check  Server/supabase/functions/telemetry-ingest/index.ts     # types
//
// Deploy:  supabase functions deploy telemetry-ingest

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createIngestHandler } from "./handler.ts";
import type { DbClient } from "./handler.ts";

Deno.serve(
  createIngestHandler({
    getEnv: (name: string) => Deno.env.get(name),
    // The handler uses `from(...).upsert(...)` and nothing else, so it depends on that
    // narrow shape instead of on the whole client. Asserting it here keeps this file
    // free of supabase-js generics and the rest of the function testable with a fake.
    createDb: (url: string, key: string) =>
      createClient(url, key, { auth: { persistSession: false } }) as unknown as DbClient,
  }),
);
