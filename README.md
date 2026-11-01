# 🔮 Mathemancer 

A Roguelike Poker Puzzle Game built with **Godot 4.7+ (Forward+ / GDScript)**.

> Combine Kakuro grid logic, Minesweeper mine deduction, and Balatro-style Poker hand scoring with elemental synergies, relics (Jokers), and consumable scrolls (Tarots) to vanquish arithmetic bosses across 8 escalating Antes.

---

## 🎮 Core Gameplay Mechanics

1. **Deterministic Grid Deduction:**
   - Latin Square (Sudoku-style): Every row and column contains unique digits (1 to N).
   - Safe Kakuro Sums (`∑`): Sum of all safe numbers in a line.
   - Ordinal Mine Ranking (`Rank`): Relative mine count ordering (Rank 1 = lowest mines on the board).
   - Fog of War: Progressive unlocking per stage upon playing poker hands.
2. **Balatro-Style Poker Hands:**
   - Select 1 to 5 revealed numbers on the board into your bottom Hand Tray.
   - Hand combinations: *Straight Flush, Blackjack 21, Flush, Full House, Straight, Three of a Kind, Two Pair, One Pair, High Sum*.
   - Scoring formula: `Chips × Mult = Boss Damage`.
3. **Roguelike Progression & Shop:**
   - Defeat Bosses across 8 Antes.
   - Earn Gold to purchase **Relics (Jokers)** with passive score multipliers.
   - Buy **Scrolls (Tarots)** to transmute suits and restore plays.

---

## 🛠 Project Structure

```text
mathemancer/
├── assets/         # Kenney CC0 audio and Lilita One fonts
├── docs/           # Game design specification and implementation plans
├── scenes/
│   ├── main.tscn   # Core game battle arena & HUD
│   ├── test_runner.tscn # Headless automated test suite
│   └── components/ # Reusable UI components (Tile, Shop)
├── scripts/
│   ├── core/       # BoardGenerator, GameManager, HandEvaluator, Relics, Scrolls
│   └── ui/         # HUD, TileView, ShopView, ScreenShake
└── tests/          # Comprehensive unit & E2E gameplay tests
```

---

## 🧪 Running Automated Tests

Run the test suite headlessly via Godot CLI:

```bash
godot --headless --path . scenes/test_runner.tscn
```

---

## 📜 License
MIT License. Created by [Trần Đình Minh Trí (minhtridknj)](https://github.com/minhtridknj).
