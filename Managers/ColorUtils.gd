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
#endregion
