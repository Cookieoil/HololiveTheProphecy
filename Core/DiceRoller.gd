class_name DiceRoller
extends RefCounted
## Static utility for dice rolls.
## Separated for easy mocking/seeding in tests.
##
## @author TheGreatJellyfish
## @version 5/18/2026

## Roll a single die with the given number of sides.
static func roll(sides: int) -> int:
	return randi_range(1, maxi(1, sides))

## Roll a targeting die among living allies. Returns a random living ally.
## Returns null if no allies are alive.
static func roll_target(units: Array[Unit]) -> Unit:
	var living: Array[Unit] = []
	for u in units:
		if not u.is_dead:
			living.append(u)
	if living.is_empty():
		return null
	return living[randi_range(0, living.size() - 1)]
