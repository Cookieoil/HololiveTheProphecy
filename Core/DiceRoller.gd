class_name DiceRoller
extends RefCounted
## Static utility for dice rolls.
##
## Every roll takes the run's generator, so a battle is reproducible from its
## `run_seed`. There is deliberately no global-RNG fallback: a roll that reached for
## the global generator would silently make a run unreplayable, which is the one thing
## the seed exists to prevent. Tooling that wants an arbitrary die passes a fresh
## `RandomNumberGenerator`.
##
## @author TheGreatJellyfish
## @version 11/28/2026

## Roll a single die with the given number of sides.
## @param sides how many sides the die has (clamped to at least 1)
## @param rng the run's generator (GameState.rng), never the global RNG
static func roll(sides: int, rng: RandomNumberGenerator) -> int:
	return rng.randi_range(1, maxi(1, sides))
