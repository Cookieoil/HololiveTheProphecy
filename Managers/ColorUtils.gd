extends Node
# Autoload (singleton)

## Color definitions for BBCode
const COLOR_ALLY	:= "#00FF00"
const COLOR_ENEMY	:= "#FF4444"
const COLOR_HP		:= "#FFA500"
const COLOR_SHIELD	:= "#00BFFF"
const COLOR_CARD	:= "#FFFF00"
const COLOR_DEAD	:= "#7A7A7A"
const COLOR_HEADER	:= "#FFFFFF"

## Wrap text in a BBCode color tag.
static func colorize(text: String, color: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]

## Wrap a unit's display name in its side's colour: allies green, enemies red.
static func unit_name(display_name: String, is_ally: bool) -> String:
	return colorize(display_name, COLOR_ALLY if is_ally else COLOR_ENEMY)


## Wrap a stat number in its colour: "hp" orange, anything else (shield) blue.
static func stat_value(value: int, kind: String = "hp") -> String:
	return colorize(str(value), COLOR_HP if kind == "hp" else COLOR_SHIELD)


## Wrap a card's effective value in the card colour.
static func card_value(value: int) -> String:
	return colorize(str(value), COLOR_CARD)
#endregion
