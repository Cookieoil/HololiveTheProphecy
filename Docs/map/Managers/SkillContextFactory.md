<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Managers/SkillContextFactory.gd` — `class_name SkillContextFactory` extends `RefCounted`

`124` lines · [back to the map](../../CODEBASE_MAP.md)

> Builds the SkillContext a skill resolves against, with the async callables injected: the player's prompts go to the UI and are timed for telemetry, while the en…

Sections: Public Methods

Public API:
- L18-72 `static build_ally_context(ally: Unit, card: Card, state: GameState, ui: GameUI, telemetry: TelemetryManager) -> SkillContext` — The context for a player-cast skill. A turn-wide bonus from a merged Buff lands on the card value here and is spent by doing so, so the next card of the turn st…
- L79-122 `static build_enemy_context(enemy: Unit, intent: EnemyIntent, state: GameState, ui: GameUI) -> SkillContext` — The context for one enemy's action: its roll is the card value and the merged flag comes from the intent's condition. Enemies get no prompt - targeting is silen…

Uses: Card, EnemyIntent, GameState, GameUI, SkillContext, TelemetryManager, Unit
Used by: GDTest/SkillContextFactoryTest.gd, Managers/GameManager.gd
Loads: —

