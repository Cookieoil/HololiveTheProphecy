<!-- GENERATED FILE: do not edit by hand. Produced by Tools/gen_code_index.gd. -->
# `Scenes/BattleUnit/UnitUI.tscn` — root `UnitUI` (`PanelContainer`), 19 nodes

[back to the map](../../../CODEBASE_MAP.md)

Root script: `Scenes/BattleUnit/UnitUI.gd`

## Node tree

- UnitUI `PanelContainer` — script `Scenes/BattleUnit/UnitUI.gd`
  - VBox `VBoxContainer`
  - IntentLabel `Label`
  - StatusSection `VBoxContainer`
    - StatusIconsGrid `GridContainer`
    - SkillPreview `VBoxContainer`
      - Skill1Row `HBoxContainer`
        - Icons `HBoxContainer`
      - Skill2Row `HBoxContainer`
        - Icons `HBoxContainer`
  - HealthShieldContainer `Control`
    - BarCanvas `Control`
    - HpBar `ProgressBar`
    - ShieldBar `ProgressBar`
  - OvalBody `PanelContainer`
    - BodyVBox `VBoxContainer`
      - CharacterSprite `Control` — script `Scenes/BattleUnit/SpinePortrait.gd`
      - NameLabel `Label`
  - HoverGlow `Panel`
