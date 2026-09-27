# 🥊 The Godfather Fight Game — v4

**Godot 4.6 · 1v1 · Two wireless controllers · Living room arena**

## ▶️ Quick Start
1. Open **Godot 4.6** → Import → select `project.godot`
2. Connect **2 wireless controllers**
3. Press **Play ▶** — starts at the title screen

---

## 🎮 Controller Layout (same for both players)

| Button | Action |
|--------|--------|
| **D-Pad** left/right | Move |
| **X** (Cross) | Jump |
| **Square** □ | Punch  *(works in air!)* |
| **Circle** ○ | Kick   *(works in air!)* |
| **R2** (hold) | Block — absorbs 85% damage |
| **□ + △** (Square + Triangle) | 🐑 Sheep Summon |
| **○ + △** (Circle + Triangle) | 🔩 Drill Attack |
| **START** | Rematch / confirm |

> P1 = Controller port 0 · P2 = Controller port 1

---

## ⚔️ Move Details

### 👊 Punch (□)  — 12 dmg / 10 in air
7-frame combo. Works on ground and in the air.

### 🦵 Kick (○) — 20 dmg / 16 in air
3-frame strong kick with heavy knockback. Works on ground and in the air.

### 🛡️ Block (R2 hold) — ground only
7-frame block animation. Reduces incoming damage by 85%.

### 🐑 Sheep Summon (□+△)
Gesture animation (frames 19–25), then 5 sheep spawn and **always walk toward the enemy**.  
Each sheep: 10 damage, disappears on hit. 4 s cooldown.

### 🔩 Drill Attack (○+△)
- Setup phase (frames 26–27): equip drill + mask
- Walk phase (frames 28–30 looping): advance toward enemy for **5 seconds**, dealing **5 dmg every 0.22 s**
- 9 s cooldown

---

## 🗺️ Frame Map (0-based, sheet: 42 × 32×32 px)

| Animation | Frames | Frames (1-based) |
|-----------|--------|-----------------|
| Idle | 0–3 | 1–4 |
| Walk | 4–7 | 5–8 |
| Punch | 8–14 | 9–15 |
| Jump | 15–17 | 16–18 |
| Sheep gesture | 18–24 | 19–25 |
| Drill | 25–29 | 26–30 |
| Block | 30–36 | 31–37 |
| Kick | 37–39 | 38–40 |

---

## 📁 Structure
```
GFGame_v4/
├── project.godot          ← Open this
├── assets/
│   ├── TheGodFatherCharacter-Sheet.png
│   ├── HealthBar-Sheet.png
│   ├── Thelivingroom.png
│   └── Sheep.png
├── scenes/
│   ├── StartMenu.tscn     ← Title screen
│   └── Main.tscn          ← Fight scene
└── scripts/
    ├── SignalBus.gd
    ├── StartMenu.gd
    ├── Fighter.gd
    └── GameManager.gd
```
