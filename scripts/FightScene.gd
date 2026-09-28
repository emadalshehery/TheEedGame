extends Node2D
# ──────────────────────────────────────────────
#  FightScene.gd
#
#  Stage: The_fighting_scene_background.png
#  tiled to fill the full 1280x720 viewport.
#  No env sheet — just the background image,
#  the floor physics body, fighters, and HUD.
# ──────────────────────────────────────────────

const FIGHTER_SCRIPT = preload("res://scripts/Fighter.gd")

const VIEWPORT_W: int   = 1280
const VIEWPORT_H: int   = 720
const FLOOR_Y:    float = 590.0
const ROUND_TIME: float = 99.0
const ROUNDS_WIN: int   = 2

var round_time: float = ROUND_TIME
var active:     bool  = false
var round_num:  int   = 1
var p1_wins:    int   = 0
var p2_wins:    int   = 0
var p1: Fighter = null
var p2: Fighter = null

var hud:          CanvasLayer
var timer_lbl:    Label
var round_lbl:    Label
var announce_lbl: Label
var fight_lbl:    Label
var p1_win_box:   HBoxContainer
var p2_win_box:   HBoxContainer

func _ready() -> void:
	_build_stage()
	_build_hud()
	_spawn_fighters()
	_start_intro()

# ═══════════════════════════════════
#  STAGE
# ═══════════════════════════════════
func _build_stage() -> void:
	# ── Background image tiled to fill screen ──
	var bg_tex = load("res://assets/ui/The_fighting_scene_background.png") as Texture2D
	if bg_tex:
		# Scale so height fills viewport exactly
		var bg_scale  = float(VIEWPORT_H) / float(bg_tex.get_height())
		var tile_w    = bg_tex.get_width() * bg_scale
		var num_tiles = int(ceil(float(VIEWPORT_W) / tile_w)) + 1
		for i in range(num_tiles):
			var sp       = Sprite2D.new()
			sp.texture   = bg_tex
			sp.scale     = Vector2(bg_scale, bg_scale)
			sp.position  = Vector2(tile_w * i + tile_w * 0.5, VIEWPORT_H * 0.5)
			add_child(sp)
	else:
		# Fallback solid colour
		var cr       = ColorRect.new()
		cr.color     = Color(0.53, 0.81, 0.92)
		cr.size      = Vector2(VIEWPORT_W, VIEWPORT_H)
		cr.position  = Vector2.ZERO
		add_child(cr)

	# ── Floor physics body ──
	var floor_body      = StaticBody2D.new()
	floor_body.position = Vector2(VIEWPORT_W * 0.5, FLOOR_Y + 8)
	var floor_col       = CollisionShape2D.new()
	floor_col.shape     = WorldBoundaryShape2D.new()
	floor_body.add_child(floor_col)
	add_child(floor_body)

# ═══════════════════════════════════
#  HUD
# ═══════════════════════════════════
func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	# Load health bar sheet (256x16: left 128px = green fill, right 128px = brown empty)
	var bar_tex = load("res://assets/ui/HealthBar-Sheet.png") as Texture2D

	# ── P1 health bar (fills left → right) ──
	_make_health_bar(hud, Vector2(20, 20), Vector2(450, 36), bar_tex, false)

	# ── P2 health bar (fills right → left, mirrored) ──
	_make_health_bar(hud, Vector2(810, 20), Vector2(450, 36), bar_tex, true)

	# Timer
	_rect(hud, Rect2(575, 8, 130, 60), Color(0, 0, 0, 0.7))
	timer_lbl = _lbl(hud, "99",      Vector2(575, 8),  Vector2(130, 60), 44, Color.WHITE,           true)
	round_lbl = _lbl(hud, "ROUND 1", Vector2(480, 72), Vector2(320, 28), 18, Color(1, 0.9, 0.2, 1), true)

	var d1 = GameData.get_char(GameData.player1_char)
	var d2 = GameData.get_char(GameData.player2_char)
	_lbl(hud, "P1  " + d1["display_name"], Vector2(20,  58), Vector2(300, 22), 14, Color(0.3, 1, 0.4, 1), false)
	_lbl(hud, d2["display_name"] + "  P2", Vector2(960, 58), Vector2(300, 22), 14, Color(1, 0.4, 0.4, 1), true)

	p1_win_box          = HBoxContainer.new()
	p1_win_box.position = Vector2(20, 82)
	hud.add_child(p1_win_box)
	p2_win_box          = HBoxContainer.new()
	p2_win_box.position = Vector2(1100, 82)
	hud.add_child(p2_win_box)

	announce_lbl = _lbl(hud, "", Vector2(240, 270), Vector2(800, 90), 64, Color(1, 0.9, 0.1, 1), true)
	announce_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	announce_lbl.add_theme_constant_override("shadow_offset_x", 4)
	announce_lbl.add_theme_constant_override("shadow_offset_y", 4)

	fight_lbl = _lbl(hud, "", Vector2(340, 360), Vector2(600, 90), 76, Color(1, 0.3, 0.1, 1), true)
	fight_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	fight_lbl.add_theme_constant_override("shadow_offset_x", 5)
	fight_lbl.add_theme_constant_override("shadow_offset_y", 5)

	_lbl(hud, "Controller: D-pad/Stick Move  ✕ Jump  □ Punch  ○ Kick  R1 Special  L1 Block",
		Vector2(10, 692), Vector2(1260, 20), 12, Color(0.7, 0.85, 1.0, 0.9), true)
	_lbl(hud, "Keyboard — P1: A/D W F G H V     |     P2: Arrows Num1 Num2 Num3 Num0",
		Vector2(10, 708), Vector2(1260, 20), 10, Color(0.5, 0.5, 0.5, 0.7), true)

# ── Build a TextureProgressBar health bar from the sprite sheet ──
# bar_tex: 256x16 (left 128 = green fill, right 128 = brown bg)
# mirrored: P2 bar fills right-to-left
func _make_health_bar(parent: Node, pos: Vector2, size: Vector2,
					  bar_tex: Texture2D, mirrored: bool) -> void:
	if bar_tex == null:
		# Fallback plain ColorRects
		_rect(parent, Rect2(pos, size), Color(0.4, 0, 0, 1))
		var fill = TextureRect.new()
		fill.position = pos
		fill.size     = size
		parent.add_child(fill)
		_store_bar(fill, mirrored)
		return

	# Background (brown right half of sheet)
	var bg_atlas        = AtlasTexture.new()
	bg_atlas.atlas      = bar_tex
	bg_atlas.region     = Rect2(128, 0, 128, 16)

	var bg              = TextureRect.new()
	bg.texture          = bg_atlas
	bg.stretch_mode     = TextureRect.STRETCH_SCALE
	bg.position         = pos
	bg.size             = size
	parent.add_child(bg)

	# Fill (green left half of sheet) — we scale width to show HP %
	var fill_atlas      = AtlasTexture.new()
	fill_atlas.atlas    = bar_tex
	fill_atlas.region   = Rect2(0, 0, 128, 16)

	var fill            = TextureRect.new()
	fill.texture        = fill_atlas
	fill.stretch_mode   = TextureRect.STRETCH_SCALE
	fill.size           = size
	fill.position       = pos
	if mirrored:
		fill.flip_h     = true
	parent.add_child(fill)

	# We store the fill TextureRect in the ColorRect variable slot via a wrapper
	# Return a dummy ColorRect so existing _on_p1_hp / _on_p2_hp still compile.
	# The real update is done via the stored TextureRect references below.
	_store_bar(fill, mirrored)

func _rect(parent: Node, r: Rect2, color: Color) -> ColorRect:
	var cr      = ColorRect.new()
	cr.color    = color
	cr.position = r.position
	cr.size     = r.size
	parent.add_child(cr)
	return cr

func _lbl(parent: Node, text: String, pos: Vector2, sz: Vector2,
		  font_size: int, color: Color, center: bool) -> Label:
	var lbl = Label.new()
	lbl.text     = text
	lbl.position = pos
	lbl.size     = sz
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	if center:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(lbl)
	return lbl

# ═══════════════════════════════════
#  FIGHTERS
# ═══════════════════════════════════
# ── Store actual TextureRect fill bars ──
var _p1_fill: TextureRect = null
var _p2_fill: TextureRect = null
var _p1_full_w: float = 450.0
var _p2_full_w: float = 450.0

func _store_bar(fill: TextureRect, mirrored: bool) -> void:
	if not mirrored:
		_p1_fill = fill
	else:
		_p2_fill = fill

func _spawn_fighters() -> void:
	if p1: p1.queue_free()
	if p2: p2.queue_free()

	p1                 = Fighter.new()
	p1.player_id       = 1
	p1.character_name  = GameData.player1_char
	p1.global_position = Vector2(320, FLOOR_Y)
	add_child(p1)

	p2                 = Fighter.new()
	p2.player_id       = 2
	p2.character_name  = GameData.player2_char
	p2.global_position = Vector2(960, FLOOR_Y)
	add_child(p2)

	p1.opponent = p2
	p2.opponent = p1

	p1.health_changed.connect(_on_p1_hp)
	p2.health_changed.connect(_on_p2_hp)
	p1.died.connect(_on_died)
	p2.died.connect(_on_died)
	_refresh_bars()

func _on_p1_hp(hp: float) -> void:
	if p1 == null or _p1_fill == null: return
	var pct = hp / p1.max_health
	_p1_fill.size.x = _p1_full_w * pct

func _on_p2_hp(hp: float) -> void:
	if p2 == null or _p2_fill == null: return
	var pct = hp / p2.max_health
	var filled = _p2_full_w * pct
	_p2_fill.size.x = filled
	# Right-align: shift position so bar shrinks from the right
	_p2_fill.position.x = 810.0 + (_p2_full_w - filled)

func _refresh_bars() -> void:
	if p1: _on_p1_hp(p1.health)
	if p2: _on_p2_hp(p2.health)

func _update_win_icons() -> void:
	for c in p1_win_box.get_children(): c.queue_free()
	for c in p2_win_box.get_children(): c.queue_free()
	for _i in range(p1_wins):
		var ic = ColorRect.new(); ic.color = Color(1, 0.8, 0, 1)
		ic.custom_minimum_size = Vector2(18, 18); p1_win_box.add_child(ic)
	for _i in range(p2_wins):
		var ic = ColorRect.new(); ic.color = Color(1, 0.8, 0, 1)
		ic.custom_minimum_size = Vector2(18, 18); p2_win_box.add_child(ic)

# ═══════════════════════════════════
#  ROUND LOGIC
# ═══════════════════════════════════
func _start_intro() -> void:
	active = false
	round_lbl.text    = "ROUND " + str(round_num)
	announce_lbl.text = "ROUND " + str(round_num)
	fight_lbl.text    = ""
	await get_tree().create_timer(1.2).timeout
	announce_lbl.text = ""
	fight_lbl.text    = "FIGHT!"
	await get_tree().create_timer(0.7).timeout
	fight_lbl.text = ""
	active     = true
	round_time = ROUND_TIME

func _process(delta: float) -> void:
	if not active: return
	round_time -= delta
	round_time  = maxf(round_time, 0.0)
	timer_lbl.text = str(int(round_time))
	if round_time <= 0.0:
		active = false
		_time_out()

func _on_died() -> void:
	if not active: return
	active = false
	_eval_round()

func _time_out() -> void:
	if p1 == null or p2 == null: return
	if   p1.health > p2.health: _end_round(1)
	elif p2.health > p1.health: _end_round(2)
	else:                       _end_round(0)

func _eval_round() -> void:
	if p1 == null or p2 == null: return
	if   p1.is_dead: _end_round(2)
	elif p2.is_dead: _end_round(1)

func _end_round(winner: int) -> void:
	match winner:
		1:
			p1_wins += 1
			announce_lbl.text = GameData.get_char(GameData.player1_char)["display_name"] + " WINS!"
			if p1: p1.play_victory()
		2:
			p2_wins += 1
			announce_lbl.text = GameData.get_char(GameData.player2_char)["display_name"] + " WINS!"
			if p2: p2.play_victory()
		_:
			announce_lbl.text = "DRAW!"

	_update_win_icons()
	await get_tree().create_timer(2.5).timeout

	if p1_wins >= ROUNDS_WIN or p2_wins >= ROUNDS_WIN:
		GameData.winner = 1 if p1_wins >= ROUNDS_WIN else 2
		await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	else:
		round_num += 1
		announce_lbl.text = ""
		_spawn_fighters()
		_start_intro()
