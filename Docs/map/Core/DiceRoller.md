<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/DiceRoller.gd` — `class_name DiceRoller` extends `RefCounted`

`28` lines · [back to the map](../../CODEBASE_MAP.md)

> Static utility for dice rolls. Separated for easy mocking/seeding in tests.

Public API:
- L12-16 `static roll(sides: int, rng: RandomNumberGenerator = null) -> int` — Roll a single die with the given number of sides. Null falls back to the global RNG (used by tests and tooling).
- L20-27 `static roll_target(units: Array[Unit]) -> Unit` — Roll a targeting die among living allies. Returns a random living ally. Returns null if no allies are alive.

Uses: Unit
Used by: GDTest/TelemetryTest.gd, Managers/GameManager.gd
Loads: —

