<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/BattleScene/BattleScene.tscn` — root `Main` (`Node`), 41 nodes

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
            - WaveStat `HBoxContainer`
              - Icon `TextureRect`
              - Value `Label`
            - DiceStat `HBoxContainer`
              - Icon `TextureRect`
              - Value `Label`
          - CenterGroup `HBoxContainer`
            - ActionsStat `HBoxContainer`
              - Icon `TextureRect`
              - Value `Label`
            - MergesStat `HBoxContainer`
              - Icon `TextureRect`
              - Value `Label`
          - RightGroup `HBoxContainer`
            - ResourceLabel `Label`
            - ConvertButton `Button`
            - EndTurnButton `Button`
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
    - DebugButton `Button`
  - BattleOverlay `Node` — script `Scenes/HUD/BattleOverlayController.gd`
  - WorldEnvironment `WorldEnvironment`
