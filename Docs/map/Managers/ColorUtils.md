<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/ColorUtils.gd` extends `Node`

`31` lines · [back to the map](../../CODEBASE_MAP.md)

> Color definitions for BBCode

Constants:
- L5 `COLOR_ALLY = "#00FF00"`
- L6 `COLOR_ENEMY = "#FF4444"`
- L7 `COLOR_HP = "#FFA500"`
- L8 `COLOR_SHIELD = "#00BFFF"`
- L9 `COLOR_CARD = "#FFFF00"`
- L10 `COLOR_DEAD = "#7A7A7A"`
- L11 `COLOR_HEADER = "#FFFFFF"`

Public API:
- L14-15 `static colorize(text: String, color: String) -> String` — Wrap text in a BBCode color tag.
- L18-19 `static unit_name(display_name: String, is_ally: bool) -> String` — Wrap a unit's display name in its side's colour: allies green, enemies red.
- L23-24 `static stat_value(value: int, kind: String = "hp") -> String` — Wrap a stat number in its colour: "hp" orange, anything else (shield) blue.
- L28-29 `static card_value(value: int) -> String` — Wrap a card's effective value in the card colour.

Uses: —
Used by: —
Loads: —

