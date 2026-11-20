<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/BattleScene/BattleScene.tscn` — root `Main` (`Node`), 46 nodes

[back to the map](../../../CODEBASE_MAP.md)

Root script: `Scenes/BattleScene/BattleScene.gd`

## Node tree

- Main `Node` — script `Scenes/BattleScene/BattleScene.gd`
  - Background `CanvasLayer`
    - ColorRect `ColorRect`
  - EntityOverlay `CanvasLayer`
    - EnemiesRow `HBoxContainer`
    - AlliesRow `HBoxContainer`
  - HUD `CanvasLayer`
    - TopBar `PanelContainer`
      - Margin `MarginContainer`
        - HBox `HBoxContainer`
          - LeftGroup `HBoxContainer`
            - WaveStat `HBoxContainer` — script `Scenes/HUD/HudTooltip.gd`
              - Icon `TextureRect`
              - Value `Label`
            - DiceStat `HBoxContainer` — script `Scenes/HUD/HudTooltip.gd`
              - Icon `TextureRect`
              - Value `Label`
          - CenterGroup `HBoxContainer`
            - ActionsStat `HBoxContainer` — script `Scenes/HUD/HudTooltip.gd`
              - Icon `TextureRect`
              - Value `Label`
            - MergesStat `HBoxContainer` — script `Scenes/HUD/HudTooltip.gd`
              - Icon `TextureRect`
              - Value `Label`
          - RightGroup `HBoxContainer`
            - DeckStat `HBoxContainer` — script `Scenes/HUD/HudTooltip.gd`
              - Icon `TextureRect`
              - Value `Label`
            - DiscardStat `HBoxContainer` — script `Scenes/HUD/HudTooltip.gd`
              - Icon `TextureRect`
              - Value `Label`
            - ConvertButton `Button` — script `Scenes/HUD/HudTooltip.gd`
            - EndTurnButton `Button` — script `Scenes/HUD/HudTooltip.gd`
    - MessageLog `Label`
    - HandBar `PanelContainer` — script `Scenes/Cards/HandBar.gd`
      - MarginContainer `MarginContainer`
        - VBox `VBoxContainer`
          - CardsBracketHeader `HBoxContainer`
            - LeftLine `ColorRect`
            - CardsTitle `Label`
            - RightLine `ColorRect`
          - CardsRow `HBoxContainer`
  - DebugLayer `CanvasLayer`
    - DebugButton `Button` — script `Scenes/HUD/HudTooltip.gd`
  - BattleOverlay `Node` — script `Scenes/HUD/BattleOverlayController.gd`
  - WorldEnvironment `WorldEnvironment`
