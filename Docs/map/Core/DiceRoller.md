<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Core/DiceRoller.gd` — `class_name DiceRoller` extends `RefCounted`

`23` lines · [back to the map](../../CODEBASE_MAP.md)

> Static utility for dice rolls. Separated for easy mocking/seeding in tests.

Public API:
- L10-11 `static roll(sides: int) -> int` — Roll a single die with the given number of sides.
- L15-22 `static roll_target(units: Array[Unit]) -> Unit` — Roll a targeting die among living allies. Returns a random living ally. Returns null if no allies are alive.

Uses: Unit
Used by: Managers/GameManager.gd
Loads: —

