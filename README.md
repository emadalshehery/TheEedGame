# The Diems Fight 🥊
### Godot 4.2+ Project  —  2D Family Fighting Game

---

## 🚀 How to Open

1. Install **Godot 4.2+** from https://godotengine.org
2. Open Godot → **Import** → select `TheDiemsFight/project.godot`
3. Press **F5** (or ▶) to play

---

## 🎮 Controls

| Action  | Player 1 | Player 2      |
|---------|----------|---------------|
| Move ◄► | A / D    | ← / → Arrows  |
| Jump    | W        | ↑ Arrow       |
| Punch   | F        | Numpad 1      |
| Kick    | G        | Numpad 2      |
| Special | H        | Numpad 3      |
| Block   | V        | Numpad 0      |
| Back    | ESC (on char select) | |

---

## ⚔️ Game Flow

```
Main Menu  →  Character Select  →  Fight  →  Main Menu
```

- **Best of 3 rounds**, 99-second timer per round
- Highest HP when timer expires wins the round
- **Block** reduces damage by 90%
- **Special** deals 2× damage
- **Kick** deals 1.3× damage
- Taking a hit ≥14 damage causes a full **knockdown** (1 second)

---

## 👥 Roster

| Character     | HP  | Speed | Damage | Special                   |
|---------------|-----|-------|--------|---------------------------|
| Middle        | 100 | 200   | 10     | Big swing (frames 19-21)  |
| Millennial    | 95  | 210   | 9      | Magic blast (frames 19-23)|
| Om Yosef      | 110 | 180   | 13     | Power move + angel victory|
| The American  | 100 | 220   | 10     | Fast combo                |
| The Aunty     | 90  | 215   | 9      | Agile attacks             |
| The Godfather | 120 | 170   | 14     | Slow but devastating      |
| The Godmother | 105 | 195   | 12     | Magic bolt (frames 27-31) |

---

## 📁 Structure

```
project.godot          ← open this
scripts/
  GameData.gd          ← AutoLoad: all character + frame data
  Fighter.gd           ← character controller (state machine)
  FightScene.gd        ← arena, HUD, round manager
  MainMenu.gd          ← title screen
  CharSelect.gd        ← character selection
scenes/
  MainMenu.tscn
  CharSelect.tscn
  FightScene.tscn      ← each scene is just a Node2D + script
assets/
  sprites/             ← all character sheets (32×32 frames)
  ui/                  ← background, menu, health bar, char select
  maps/                ← environment sheet
```

---

## 🔧 Tweaking Frame Data

All animation frame numbers are in `scripts/GameData.gd`.
Each entry looks like:
```gdscript
"punch": {"start": 9, "count": 3, "fps": 12, "loop": false},
```
- `start` = first frame index on the sheet (0-based, left to right)
- `count` = number of frames in this animation
- `fps`   = playback speed
- `loop`  = whether it loops

All sheets are a single horizontal row of **32×32 pixel** frames.
