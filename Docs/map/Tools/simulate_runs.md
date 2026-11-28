<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/simulate_runs.gd` extends `Node`

`180` lines · [back to the map](../../CODEBASE_MAP.md)

> Replays a run seed headlessly, or sweeps a range of seeds, and prints what happened. A seed is only worth recording if it can be re-run, and this is the command…

Sections: Constants · Private Variables · Lifecycle Methods · Private Methods

Constants:
- L31 `DEFAULT_SEED: int = 20260101` — The seed a run falls back to when the command line gives none.
- L33 `TRACE_LIMIT: int = 40` — The longest trace printed for a single seed, so one runaway run cannot flood a log.
- L36 `WATCHDOG_FRAMES: int = 600` — Frames one run may take before the command gives up, so a battle that cannot end (a balance bug) fails instead of hanging the shell.
- L38 `ARG_FLAG: String = "--flag"` — The flag that forces a staged feature flag on for the run.

State:
- L43 `_failures: PackedStringArray = PackedStringArray()`
- L45 `_watchdog: int = 0` — Frames left before the current run is declared stuck; 0 disarms the watchdog.
- L46 `_running_seed: int = 0`

Private:
- L51-58 `_ready`
- L61-67 `_process`
- L73-80 `_replay`
- L85-97 `_sweep`
- L101-108 `_run`
- L113-119 `_report`
- L123-133 `_print_trace`
- L137-143 `_flags`
- L147-154 `_arg_int`
- L158-163 `_arg_value`
- L166-167 `_fail`
- L170-178 `_finish`

Uses: BattleSimulator
Used by: —
Loads: —

