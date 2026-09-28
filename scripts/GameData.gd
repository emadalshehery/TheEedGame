extends Node
# ─────────────────────────────────────────────
#  GameData.gd  –  AutoLoad Singleton
#
#  GROUND SHEET layout (32x32 per frame):
#    idx  0– 3  idle   (4)
#    idx  4– 7  walk   (4)
#    idx  8–11  punch  (4)
#    idx 12–14  jump   (3)
#    idx 15     SKIP
#    idx 16–19  block  (4)
#    idx 20–22  kick   (3)
#
#  AIR SHEET layout (32x32 per frame, 3 frames for most, 5 for TheGodmother):
#    frame 1 (idx 0) – upright, just launched
#    frame 2 (idx 1) – tumbling through the air  ← main fly frame
#    frame 3 (idx 2) – landing/crash
#    (TheGodmother frames 4-5 extend the crash sequence)
#
#  "fly" animation = air sheet frames 0-2 (or 0-4 for TheGodmother)
#    Played when hit by a KICK (launched into the air).
# ─────────────────────────────────────────────

var player1_char: String = "Middle"
var player2_char: String = "TheDeveloper"
var winner: int = 0

# ── Shared ground animations (23-frame characters) ──
const ANIM_23 = {
	"idle":      {"start": 0,  "count": 4, "fps": 6,  "loop": true},
	"walk":      {"start": 4,  "count": 4, "fps": 8,  "loop": true},
	"run":       {"start": 4,  "count": 4, "fps": 12, "loop": true},
	"punch":     {"start": 8,  "count": 4, "fps": 12, "loop": false},
	"jump":      {"start": 12, "count": 3, "fps": 10, "loop": false},
	# idx 15 = skipped
	"block":     {"start": 16, "count": 4, "fps": 6,  "loop": true},
	"kick":      {"start": 20, "count": 3, "fps": 12, "loop": false},
	# Fallbacks using existing frames:
	"hurt":      {"start": 12, "count": 1, "fps": 6,  "loop": false},
	"knockdown": {"start": 14, "count": 1, "fps": 6,  "loop": false},
	"special":   {"start": 20, "count": 3, "fps": 14, "loop": false},
	"victory":   {"start": 0,  "count": 4, "fps": 5,  "loop": true},
}

# ── Shared air animations (3-frame air sheets) ──
# "fly"  = the launched-by-kick tumbling sequence (all 3 frames)
# "air_jump" = optional separate jump arc (same frames reused)
const AIR_ANIM_3 = {
	"fly":  {"start": 0, "count": 3, "fps": 8, "loop": false},
	"jump": {"start": 0, "count": 3, "fps": 8, "loop": false},
}

const CHARACTERS: Dictionary = {

	"Middle": {
		"display_name": "Middle",
		"sprite_sheet":   "res://assets/sprites/Middle-Sheet.png",
		"air_sheet":      "res://assets/sprites/Middle_in_the_air-Sheet.png",
		"frame_size":     Vector2(32, 32),
		"air_frame_size": Vector2(32, 32),
		"select_col": 0,
		"color": Color(0.4, 0.8, 0.4),
		"stats": {"max_health":100, "speed":200, "jump_force":-500, "damage":10},
		"animations": ANIM_23,
		"air_animations": AIR_ANIM_3,
	},

	"Millennial": {
		"display_name": "Millennial",
		"sprite_sheet":   "res://assets/sprites/Millennial-Sheet.png",
		"air_sheet":      "res://assets/sprites/Millennial_in_the_air-Sheet.png",
		"frame_size":     Vector2(32, 32),
		"air_frame_size": Vector2(32, 32),
		"select_col": 2,
		"color": Color(0.5, 0.6, 0.9),
		"stats": {"max_health":95, "speed":210, "jump_force":-510, "damage":9},
		"animations": {
			"idle":      {"start": 0,  "count": 4, "fps": 6,  "loop": true},
			"walk":      {"start": 4,  "count": 4, "fps": 8,  "loop": true},
			"run":       {"start": 4,  "count": 4, "fps": 12, "loop": true},
			"punch":     {"start": 8,  "count": 4, "fps": 12, "loop": false},
			"jump":      {"start": 12, "count": 3, "fps": 10, "loop": false},
			"block":     {"start": 16, "count": 4, "fps": 6,  "loop": true},
			"kick":      {"start": 20, "count": 3, "fps": 12, "loop": false},
			"hurt":      {"start": 12, "count": 1, "fps": 6,  "loop": false},
			"knockdown": {"start": 14, "count": 1, "fps": 6,  "loop": false},
			"special":   {"start": 23, "count": 3, "fps": 12, "loop": false},
			"victory":   {"start": 26, "count": 3, "fps": 8,  "loop": true},
		},
		"air_animations": AIR_ANIM_3,
	},

	"OmYosef": {
		"display_name": "Om Yosef",
		"sprite_sheet":   "res://assets/sprites/OmYosef-Sheet.png",
		"air_sheet":      "res://assets/sprites/OmYosef_in_the_air-Sheet.png",
		"frame_size":     Vector2(32, 32),
		"air_frame_size": Vector2(32, 32),
		"select_col": 4,
		"color": Color(0.85, 0.7, 0.5),
		"stats": {"max_health":110, "speed":180, "jump_force":-480, "damage":13},
		"animations": {
			"idle":      {"start": 0,  "count": 4, "fps": 6,  "loop": true},
			"walk":      {"start": 4,  "count": 4, "fps": 8,  "loop": true},
			"run":       {"start": 4,  "count": 4, "fps": 12, "loop": true},
			"punch":     {"start": 8,  "count": 4, "fps": 12, "loop": false},
			"jump":      {"start": 12, "count": 3, "fps": 10, "loop": false},
			"block":     {"start": 16, "count": 4, "fps": 6,  "loop": true},
			"kick":      {"start": 20, "count": 3, "fps": 12, "loop": false},
			"hurt":      {"start": 12, "count": 1, "fps": 6,  "loop": false},
			"knockdown": {"start": 14, "count": 1, "fps": 6,  "loop": false},
			"special":   {"start": 23, "count": 3, "fps": 12, "loop": false},
			"victory":   {"start": 26, "count": 6, "fps": 8,  "loop": true},
		},
		"air_animations": AIR_ANIM_3,
	},

	"TheAmerican": {
		"display_name": "The American",
		"sprite_sheet":   "res://assets/sprites/TheAmerican-Sheet.png",
		"air_sheet":      "res://assets/sprites/TheAmerican_in_the_air-Sheet.png",
		"frame_size":     Vector2(32, 32),
		"air_frame_size": Vector2(32, 32),
		"select_col": 6,
		"color": Color(0.2, 0.4, 0.9),
		"stats": {"max_health":100, "speed":220, "jump_force":-520, "damage":10},
		"animations": ANIM_23,
		"air_animations": AIR_ANIM_3,
	},

	"TheAunty": {
		"display_name": "The Aunty",
		"sprite_sheet":   "res://assets/sprites/TheAunty-Sheet.png",
		"air_sheet":      "res://assets/sprites/TheAunty_in_the_air-Sheet.png",
		"frame_size":     Vector2(32, 32),
		"air_frame_size": Vector2(32, 32),
		"select_col": 8,
		"color": Color(0.9, 0.4, 0.5),
		"stats": {"max_health":90, "speed":215, "jump_force":-500, "damage":9},
		"animations": ANIM_23,
		"air_animations": AIR_ANIM_3,
	},

	"TheDeveloper": {
		"display_name": "The Developer",
		"sprite_sheet":   "res://assets/sprites/TheDeveloper-Sheet.png",
		"air_sheet":      "res://assets/sprites/TheDeveloper_in_the_air-Sheet.png",
		"frame_size":     Vector2(32, 32),
		"air_frame_size": Vector2(32, 32),
		"select_col": 10,
		"color": Color(0.3, 0.5, 1.0),
		"stats": {"max_health":95, "speed":225, "jump_force":-530, "damage":9},
		"animations": ANIM_23,
		"air_animations": AIR_ANIM_3,
	},

	"TheGodfather": {
		"display_name": "The Godfather",
		"sprite_sheet":   "res://assets/sprites/TheGodfather-Sheet.png",
		"air_sheet":      "res://assets/sprites/TheGodfather_in_the_Air-Sheet.png",
		"frame_size":     Vector2(32, 32),
		"air_frame_size": Vector2(32, 32),
		"select_col": 12,
		"color": Color(0.3, 0.3, 0.3),
		"stats": {"max_health":120, "speed":170, "jump_force":-460, "damage":14},
		"animations": ANIM_23,
		"air_animations": AIR_ANIM_3,
	},

	"TheGodmother": {
		"display_name": "The Godmother",
		"sprite_sheet":   "res://assets/sprites/TheGodmother-Sheet.png",
		"air_sheet":      "res://assets/sprites/TheGodmother_in_the_Air-Sheet.png",
		"frame_size":     Vector2(32, 32),
		"air_frame_size": Vector2(32, 32),
		"select_col": 14,
		"color": Color(0.5, 0.3, 0.8),
		"stats": {"max_health":105, "speed":195, "jump_force":-490, "damage":12},
		"animations": ANIM_23,
		# TheGodmother has 5 air frames — longer fly sequence
		"air_animations": {
			"fly":  {"start": 0, "count": 5, "fps": 8, "loop": false},
			"jump": {"start": 0, "count": 5, "fps": 8, "loop": false},
		},
	},
	"Toddler": {
		"display_name": "Toddler",
		"sprite_sheet":   "res://assets/sprites/Toddler-Sheet.png",
		"air_sheet":      "res://assets/sprites/Toddler-Sheet.png",   # reuse ground sheet for air
		"frame_size":     Vector2(32, 32),
		"air_frame_size": Vector2(32, 32),
		"select_col": 16,
		"color": Color(1.0, 0.6, 0.8),
		"stats": {"max_health":75, "speed":240, "jump_force":-560, "damage":7},
		"animations": ANIM_23,
		"air_animations": {
			"fly":  {"start": 12, "count": 3, "fps": 8, "loop": false},
			"jump": {"start": 12, "count": 3, "fps": 8, "loop": false},
		},
	},
}

const CHARACTER_ORDER: Array = [
	"Middle", "Millennial", "OmYosef", "TheAmerican",
	"TheAunty", "TheDeveloper", "TheGodfather", "TheGodmother",
	"Toddler"
]

func get_char(char_name: String) -> Dictionary:
	return CHARACTERS.get(char_name, CHARACTERS["Middle"])
