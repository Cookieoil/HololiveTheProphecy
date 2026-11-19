<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/EventBus.gd` extends `Node`

`43` lines · [back to the map](../../CODEBASE_MAP.md)

> This is used as a global signal bus. Add as an Autoload. Used for UI logging and passive hooks, not game logic. depend on these signals — they are fire-and-forg…

Sections: Turn / Wave · Card Events · Combat Events · Skill Events · Moxie · Status Events

Signals:
- L10 `turn_started(turn_number: int)`
- L11 `wave_started(wave_index: int)`
- L12 `game_over(victory: bool)`
- L16 `card_played(card: Card, ally: Unit)`
- L17 `card_drawn(card: Card)`
- L18 `card_discarded(card: Card)`
- L19 `card_value_changed(card: Card, old_value: int, new_value: int)`
- L23 `damage_dealt(source: Unit, target: Unit, amount: int, hp_lost: int)`
- L24 `shield_gained(target: Unit, amount: int)`
- L25 `shield_reduced(target: Unit, amount: int)`
- L26 `unit_healed(target: Unit, amount: int)`
- L27 `unit_died(target: Unit)`
- L31 `skill_resolved(caster: Unit, skill_name: String)`
- L35 `moxie_changed(unit: Unit, current: int, maximum: int)`
- L36 `ultimate_cast(caster: Unit, skill_name: String)`
- L41 `unit_statuses_changed(unit: Unit)` — A unit's buff/debuff list changed (applied, stacked, ticked or expired).

Uses: Card, Unit
Used by: —
Loads: —

