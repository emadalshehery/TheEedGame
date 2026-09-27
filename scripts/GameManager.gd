extends Node2D

const ROUNDS_TO_WIN := 2
const ROUND_TIME    := 99.0
# Health bar sprite: 256x16, left 128 = red bg, right 128 = green fill
const HBAR_FULL_W   := 128.0   # green portion full width in source pixels
const HBAR_SCALE    := 3.0     # display scale

var p1_wins:      int   = 0
var p2_wins:      int   = 0
var round_num:    int   = 1
var round_time:   float = ROUND_TIME
var round_active: bool  = false
var round_ending: bool  = false

@onready var fighter1 = $Fighters/Fighter1
@onready var fighter2 = $Fighters/Fighter2

# HUD nodes
@onready var p1_bar_green: Sprite2D = $HUD/P1HealthGreen
@onready var p2_bar_green: Sprite2D = $HUD/P2HealthGreen
@onready var timer_lbl:    Label    = $HUD/TimerLabel
@onready var round_lbl:    Label    = $HUD/RoundLabel
@onready var announce_lbl: Label    = $HUD/AnnounceLabel
@onready var combo_lbl:    Label    = $HUD/ComboLabel
@onready var p1_wins_lbl:  Label    = $HUD/P1WinsLabel
@onready var p2_wins_lbl:  Label    = $HUD/P2WinsLabel

var _combo_hide: float = 0.0

func _ready() -> void:
	fighter1.opponent = fighter2
	fighter2.opponent = fighter1
	SignalBus.health_changed.connect(_on_health_changed)
	SignalBus.fighter_died.connect(_on_fighter_died)
	SignalBus.combo_hit.connect(_on_combo_hit)
	_start_round()

func _process(delta: float) -> void:
	if not round_active or round_ending: return
	round_time -= delta
	timer_lbl.text     = str(int(ceil(round_time)))
	timer_lbl.modulate = Color(1, 0.2, 0.2) if round_time < 10 else Color.WHITE
	if round_time <= 0.0: _timeout()
	fighter1.update_visuals()
	fighter2.update_visuals()
	if _combo_hide > 0:
		_combo_hide -= delta
		if _combo_hide <= 0: combo_lbl.visible = false

# ── Round flow ────────────────────────────────────────────────────────────────
func _start_round() -> void:
	round_active = false; round_ending = false; round_time = ROUND_TIME
	fighter1.reset(Vector2(200, 430), true)
	fighter2.reset(Vector2(760, 430), false)
	_reset_bars()
	_refresh_wins()
	round_lbl.text = "ROUND %d" % round_num
	_announce("ROUND %d" % round_num, 1.4,
		func(): _announce("FIGHT!", 0.9, func(): round_active = true))

func _timeout() -> void:
	round_active = false
	if   fighter1.health > fighter2.health: _end_round(2)
	elif fighter2.health > fighter1.health: _end_round(1)
	else: _end_round(0)

func _on_fighter_died(pid: int) -> void:
	if round_ending: return
	round_active = false; _end_round(pid)

func _end_round(loser: int) -> void:
	round_ending = true
	var ko = fighter1.state == fighter1.State.DEAD or fighter2.state == fighter2.State.DEAD
	var hdr := "K.O.!" if ko else "TIME!"
	match loser:
		1: p2_wins += 1; _announce(hdr, 0.9, func(): _announce("PLAYER 2\nWINS!", 1.8, _check_match))
		2: p1_wins += 1; _announce(hdr, 0.9, func(): _announce("PLAYER 1\nWINS!", 1.8, _check_match))
		_: _announce(hdr, 0.9, func(): _announce("DRAW!", 1.8, _check_match))

func _check_match() -> void:
	_refresh_wins()
	if p1_wins >= ROUNDS_TO_WIN:
		_announce("PLAYER 1\nWINS\nTHE MATCH!", 3.0, _show_rematch)
	elif p2_wins >= ROUNDS_TO_WIN:
		_announce("PLAYER 2\nWINS\nTHE MATCH!", 3.0, _show_rematch)
	else:
		round_num += 1
		await get_tree().create_timer(0.5).timeout
		_start_round()

func _show_rematch() -> void:
	announce_lbl.text = "Press START to rematch\nPress B to quit"
	announce_lbl.visible = true
	set_process(false)
	_await_rematch()

func _await_rematch() -> void:
	while true:
		await get_tree().process_frame
		var start := Input.is_joy_button_pressed(0, JOY_BUTTON_START) \
				  or Input.is_joy_button_pressed(1, JOY_BUTTON_START) \
				  or Input.is_action_just_pressed("ui_accept")
		var quit  := Input.is_action_just_pressed("ui_cancel")
		if start:
			p1_wins = 0; p2_wins = 0; round_num = 1
			set_process(true); announce_lbl.visible = false; _start_round(); break
		elif quit:
			get_tree().change_scene_to_file("res://scenes/StartMenu.tscn"); break

# ── Health bar (sprite-based) ─────────────────────────────────────────────────
func _on_health_changed(pid: int, hp: float, max_hp: float) -> void:
	var ratio := hp / max_hp
	var bar   := p1_bar_green if pid == 1 else p2_bar_green
	# Crop the green portion: region_rect.size.x scales with health
	var src_w := HBAR_FULL_W * ratio
	bar.region_rect = Rect2(128.0, 0, src_w, 16)
	# Also tint: yellow <50%, red <25%
	if ratio > 0.5:    bar.modulate = Color.WHITE
	elif ratio > 0.25: bar.modulate = Color(1.0, 0.9, 0.2)
	else:              bar.modulate = Color(1.0, 0.3, 0.3)

func _reset_bars() -> void:
	p1_bar_green.region_rect = Rect2(128, 0, HBAR_FULL_W, 16)
	p2_bar_green.region_rect = Rect2(128, 0, HBAR_FULL_W, 16)
	p1_bar_green.modulate    = Color.WHITE
	p2_bar_green.modulate    = Color.WHITE

func _refresh_wins() -> void:
	p1_wins_lbl.text = "★".repeat(p1_wins) + "☆".repeat(ROUNDS_TO_WIN - p1_wins)
	p2_wins_lbl.text = "★".repeat(p2_wins) + "☆".repeat(ROUNDS_TO_WIN - p2_wins)

func _on_combo_hit(_vid: int, count: int) -> void:
	combo_lbl.text     = "%d HIT COMBO!" % count
	combo_lbl.modulate = Color(1.0, max(0.0, 1.0 - count * 0.09), 0.0)
	combo_lbl.visible  = true; _combo_hide = 1.5

func _announce(text: String, dur: float, cb: Callable) -> void:
	announce_lbl.text = text; announce_lbl.visible = true
	await get_tree().create_timer(dur).timeout
	if is_instance_valid(announce_lbl): announce_lbl.visible = false
	cb.call()
