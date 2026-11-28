<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Tools/BattleSimulator.gd` — `class_name BattleSimulator` extends `Node`

`374` lines · [back to the map](../../CODEBASE_MAP.md)

> Drives a whole battle headlessly through the GameUI contract and reports the board at every decision, so a run seed can be replayed and a sweep can assert the b…

Sections: Public Variables · Lifecycle Methods · Public Methods
- L25 `class Recorder extends GameUI` (members are not indexed)

State:
- L329 `manager: GameManager = null` — The battle that was run, once `run()` has returned.
- L332 `recorder: Recorder = null` — The policy/observer that drove it. Its `trace`, `decisions`, `violation`, `card_leak` and `diverged` are the result of the run.

Public API:
- L349-351 `run(allies: Array[UnitData], waves: Array, config: Dictionary, plan: Array = []) -> void` — Runs one whole battle to its end. `plan` replays a recorded run instead of playing the policy, which is what makes a replay check possible.
- L359-370 `run_shipped(seed_value: int, flag_overrides: Dictionary = {}) -> void` — Runs the battle the game itself ships, from `Data/json` through DataLoader, with the run seed pinned: the path BattleScene takes, minus the view. This is what m…

Private:
- L337-342 `_ready`

Uses: Card, DataLoader, EnemyIntent, GameDatabase, GameManager, GameState, GameUI, TelemetrySchema, Unit, UnitData
Used by: GDTest/DeterminismTest.gd, Tools/simulate_runs.gd
Loads: —

