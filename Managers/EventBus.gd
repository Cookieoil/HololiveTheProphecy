extends Node
## This is used as a global signal bus. Add as an Autoload.
## Used for UI logging and passive hooks, not game logic.
## depend on these signals — they are fire-and-forget.
##
## @author TheGreatJellyfish
## @version 7/1/2026

#region Turn / Wave
signal turn_started(turn_number: int)
signal wave_started(wave_index: int)
signal game_over(victory: bool)
#endregion

#region Card Events
signal card_played(card: Card, ally: Unit)
signal card_drawn(card: Card)
signal card_discarded(card: Card)
signal card_value_changed(card: Card, old_value: int, new_value: int)
#endregion

#region Combat Events
signal damage_dealt(source: Unit, target: Unit, amount: int, hp_lost: int)
signal shield_gained(target: Unit, amount: int)
signal shield_reduced(target: Unit, amount: int)
signal unit_healed(target: Unit, amount: int)
signal unit_died(target: Unit)

#region Skill Events
signal skill_resolved(caster: Unit, skill_name: String)
#endregion
