extends Node
## Global signal bus. Add as an Autoload named "EventBus".
## Used for UI logging and passive hooks. Game logic does NOT
## depend on these signals — they are fire-and-forget.
##
## @author TheGreatJellyfish
## @version 5/18/2026

signal damage_dealt(source: Unit, target: Unit, amount: int, hp_lost: int)
signal unit_healed(target: Unit, amount: int)
signal unit_died(unit: Unit)
signal shield_gained(unit: Unit, amount: int)
signal shield_reduced(unit: Unit, amount: int)
signal shield_reset(unit: Unit)
signal card_played(card: Card, ally: Unit)
signal card_drawn(card: Card)
signal card_discarded(card: Card)
signal card_value_changed(card: Card, old_value: int, new_value: int)
signal turn_started(turn_number: int)
signal wave_started(wave_number: int)
signal passive_triggered(unit: Unit, passive_id: String)
signal skill_resolved(caster: Unit, skill_name: String)
signal game_over(player_won: bool)
signal message_logged(text: String)
