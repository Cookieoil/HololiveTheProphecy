# Skill Wording Guide

How to write `description` / `merged_description` text in `Data/json/skills.json` so a
player understands a skill in one glance. The goal is the clarity of **Slay the Spire**,
**Legends of Runeterra**, **Hearthstone** and **Balatro** tooltips — never an algebra quiz.

This file is hand-authored. It is **not** part of the generated `Docs/` index (that folder
belongs to `Tools/gen_code_index.gd` alone), so keep authoring notes here.

---

## The 6 Golden Rules

1. **Imperative verb first, exact execution order.**
   Start every effect with a command verb — `Deal`, `Gain`, `Give`, `Heal`, `Draw`,
   `Discard`, `Apply`, `Break`, `Reduce`. Write effects in the order they actually happen.
   Never write "Do B before A"; write "Break X Shield on an enemy, then deal Y damage to it."

2. **One canonical term per mechanic.**
   Use the glossary below and nothing else. `HP` (never "Health"), `Value` (never bare "V"),
   `Shield`, `Gain Shield`, `Break Shield`, `next roll`. Reusing one word keeps the tooltip
   instantly scannable and lets `TooltipIconCatalog` auto-link the keyword icon.

3. **Show the resolved number, hide the math.**
   When the player is holding a `4`-Value card, the tooltip shows `Give a card in hand +3 Value`,
   **not** `3 (4/2+1)`. `SkillPreviewFormatter` substitutes the final gold number at hover time.
   Scaling rules are explained in plain words, not formulas.

4. **Teach the scaling even when it is zero — at the end of the sentence.**
   Keep the resolved number glued to the word it modifies and tuck the short rule at the
   end of the sentence (Style A, Slay the Spire):
   `Deal 9 damage to an enemy (+4 from Shield)`, and `Deal 5 damage to an enemy (+Shield)`
   at 0 Shield. Never split the sentence: not `Deal 9 (+4 from Shield) damage ...`.

5. **Clean merge / roll prefixes.**
   `Merged:` for an added effect, `Merged (Instead):` for a replacement, `Roll ≥ X:` for an
   enemy skill's boosted branch. Never "And if Merged:" / "Or if Merged: Instead,".

6. **Short scannable lines, second-person voice.**
   One or two clauses per sentence. Ally skills speak to the player ("your Shield", "in hand",
   "Your next skill"). Enemy skills narrate their own action ("Lose 1 HP. Deal 5 damage to an
   ally."). Never hard-code a unit name (`"Boss"`) or say "the player's hand".

---

## Glossary (use these words exactly)

| Concept | Canonical wording | Avoid |
| --- | --- | --- |
| Hit points | `HP` | Health, Life |
| Add shield to a unit | `Gain X Shield` (self) / `Give all allies X Shield` / `Give an ally X Shield` | Shield for X, add shield |
| Strip enemy shield | `Break X Shield` | Remove, Reduce shield |
| Card / skill magnitude | `Value` (`+2 Value`, `[Value]`, `[Value - 1]`) | V, value, card value |
| Damage that ignores Shield | `True Damage` (tooltip keyword explains "ignores Shield") | pure damage, direct damage |
| Damage over time debuff | `apply X Gloom` | inflict gloom, add gloom |
| Healing over time buff | `Grant X Regeneration` | give regen, X rounds of regen |
| Enemy dice debuff | `Reduce its next roll by X` / `Reduce all enemies' next roll by X` | decrease value, -X value |
| Target (single) | `an enemy` / `an ally` | 1 enemy, target enemy, that enemy (before it is named) |
| Target (chosen N) | `2 enemies` / `2 cards in hand` | 2 random enemies |
| Target (everyone) | `all enemies` / `all allies` | all 3 enemies |
| Buff/debuff a card | `Give a card in hand +X Value` / `Give the 2 highest cards in hand -1 Value` | Buff, boost, modify |
| Next-skill carry-over | `Your next skill this turn gains +X Value` | grant +X to next skill |

---

## Merge & threshold prefixes

| Case | `merged_mode` | Prefix | Example |
| --- | --- | --- | --- |
| Merged adds an effect | `and_base_first` / `and_merged_first` | `Merged:` | `Merged: Heal an ally for 6 HP.` |
| Merged replaces the base | `or` | `Merged (Instead):` | `Merged (Instead): Deal 4 damage to all enemies.` |
| Enemy skill, boosted branch | (enemy) | `Roll ≥ X:` | `Roll ≥ X: Give the 2 highest cards in hand -1 Value.` |

---

## Dynamic bracket tokens (what `SkillPreviewFormatter` resolves)

Write the **base formula** in the JSON; the formatter fills in the live number on hover.

| Token | Renders as | Use for |
| --- | --- | --- |
| `[Value]` | gold number | plain card-value scaling |
| `[Value + N]` / `[Value - N]` | gold number | fixed offset |
| `[Value * N]` / `[Value / N]` | gold number | multiplier / divisor |
| `[Value / N + M]` | gold number | scaled then offset (e.g. `[Value / 2 + 1]`) |
| `[Value + Shield]` | number, rule at sentence end: `Deal 9 damage to an enemy (+4 from Shield)` / `(+Shield)` | shield-slam scaling |
| `[Value + Highest Card / N]` | number, rule at sentence end: `Deal 7 damage to an enemy (+half of highest card in hand)` | hand-scaling |
| `[N + Highest Card]` | number, rule at sentence end: `Deal 13 damage to an enemy (+highest card in hand)` | fixed + hand scaling |

Rules:
- Never hand-write a resolved number into the JSON — always use a token so the tooltip stays live.
- Never write raw algebra (`(4/2+1)`, `(5x2)`) into the JSON; the formatter prints only the total.
- Scaling hints are placed by `_place_clause_hint` at the **end of the sentence**, so the
  number never splits from the word it modifies (`Deal 7 damage`, never `Deal 7 (+rule) damage`).
- During a drag hover the card being dragged is excluded from hand-based tokens, so the preview
  always matches the number the player will actually get.

---

## Templates

**Ally base skill**
```
Deal [Value] damage to an enemy. Gain 2 Shield.
```

**Ally merged add-on** (`and_*`)
```
Merged: Apply 2 Gloom.
```

**Ally merged replacement** (`or`)
```
Merged (Instead): Deal [Value - 2] damage to all enemies.
```

**Enemy skill with a threshold**
```
Deal [Value] damage to an ally. Apply 1 Gloom.
Roll ≥ 6: Deals +1 damage per the target's missing HP (max 5) if it has no Shield.
```

**Ultimate (multi-beat)**
```
Draw 2 cards. Give the 3 highest cards in hand +3 Value. Your next skill this turn gains +4 Value.
```

---

## Do / Don't

| Don't | Do |
| --- | --- |
| `Deal [Value + Caster's Shield] damage to 1 enemy.` | `Deal [Value + Shield] damage to an enemy.` |
| `Buff 1 card in hand by [Value / 2 + 1] ...` | `Give a card in hand +[Value / 2 + 1] Value.` |
| `... deal [Value - 2] damage to all 3 enemies.` | `... deal [Value - 2] damage to all enemies.` |
| `Boss loses 1 Health.` | `Lose 1 HP.` |
| `Reduce 1 value to two highest-value cards in the player's hand.` | `Give the 2 highest cards in hand -1 Value.` |
| `boost the 3 highest cards in hand by +3 V` | `Give the 3 highest cards in hand +3 Value.` |
| `And if Merged: Discard a card ...` | `Merged: Discard a card ...` |
| `Or if Merged: Instead, deal ...` | `Merged (Instead): Deal ...` |