<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/DiceRoller.gd` — `class_name DiceRoller` extends `RefCounted`

`19` lines · [back to the map](../../CODEBASE_MAP.md)

> Static utility for dice rolls. Every roll takes the run's generator, so a battle is reproducible from its `run_seed`. There is deliberately no global-RNG fallba…

Public API:
- L17-18 `static roll(sides: int, rng: RandomNumberGenerator) -> int` — Roll a single die with the given number of sides.

Uses: —
Used by: GDTest/DeterminismTest.gd, GDTest/TelemetryTest.gd, Managers/GameManager.gd
Loads: —

