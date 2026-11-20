# card_drag.gd
class_name CardDrag
extends RefCounted
## Payload for all card drag operations.
## Consumed by: CardUI (merge), UnitDropZone (skill activation).

var card: Card
var source: HandBar

func _init(p_card: Card, p_source: HandBar) -> void:
	card = p_card
	source = p_source
