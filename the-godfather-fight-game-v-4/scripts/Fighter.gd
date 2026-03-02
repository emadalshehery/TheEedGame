## ================================================================
##  Fighter.gd  —  The Godfather  (Summoner / Technician)
##
##  SPRITE SHEET: TheGodFatherCharacter-Sheet.png
##  42 frames × 32×32 px (0-based indices)
##
##  FRAME MAP:
##   Idle       0–3     Walk      4–7
##   Punch      8–14    Jump     15–17
##   Sheep     18–24    Drill    25–29
##   Block     30–36    Kick     37–39
##   Extra     40–41
##
##  CONTROLLER (same layout both players):
##   D-pad left/right  → move
##   X (Cross)         → jump
##   Square            → punch  (works in air too)
##   Circle            → kick   (works in air too)
##   Square + Triangle → Sheep Summon special
##   Circle + Triangle → Drill Attack special
##   R2 (hold)         → block (ground only)
## ================================================================

extends CharacterBody2D

@export var player_id:  int   = 1
@export var max_health: float = 100.0
@export var move_speed: float = 210.0
@export var jump_force: float = -530.0
@export var gravity:    float = 1150.0

# ── Asset paths ───────────────────────────────────────────────────────────────
const SHEET_PATH := "res://assets/TheGodFatherCharacter-Sheet.png"
const SHEEP_PATH := "res://assets/Sheep.png"

# ── Sheet layout ──────────────────────────────────────────────────────────────
const FRAME_W    := 32
const FRAME_H    := 32
const CHAR_SCALE := 3.0

# ── Animation frame arrays (0-based) ─────────────────────────────────────────
const ANIM_IDLE        := [0, 1, 2, 3]
const ANIM_WALK        := [4, 5, 6, 7]
const ANIM_PUNCH       := [8, 9, 10, 11, 12, 13, 14]
const ANIM_JUMP        := [15, 16, 17]
const ANIM_SHEEP_GEST  := [18, 19, 20, 21, 22, 23, 24]
const ANIM_DRILL       := [25, 26]
const ANIM_DRILL_LOOP  := [27, 28, 29]   # 0-based 27-29 = user frames 28-30, loops 5s
const ANIM_BLOCK       := [30, 31, 32, 33, 34, 35, 36]
const ANIM_KICK        := [38, 39, 40, 41]
const ANIM_AIR_PUNCH   := [8, 9, 10, 11, 12, 13, 14]  # same as punch
const ANIM_AIR_KICK    := [38, 39, 40, 41]              # same as kick

# ── Animation speeds (seconds per frame) ─────────────────────────────────────
const SPD_IDLE        := 0.20
const SPD_WALK        := 0.09
const SPD_PUNCH       := 0.07
const SPD_JUMP        := 0.10
const SPD_SHEEP_GEST  := 0.09
const SPD_DRILL_SETUP := 0.25
const SPD_DRILL_LOOP  := 0.10
const SPD_BLOCK       := 0.06
const SPD_KICK        := 0.10

# ── Damage values ─────────────────────────────────────────────────────────────
const DMG_PUNCH      := 12.0
const DMG_PUNCH_AIR  := 10.0
const DMG_KICK       := 20.0
const DMG_KICK_AIR   := 16.0
const DMG_SHEEP      := 10.0
const DMG_DRILL_TICK := 5.0
const BLOCK_REDUCE   := 0.85

# ── Drill timing ──────────────────────────────────────────────────────────────
const DRILL_DURATION  := 5.0
const DRILL_TICK_RATE := 0.22

# ── World bounds ─────────────────────────────────────────────────────────────
const FLOOR_Y     := 430.0
const LEFT_BOUND  := 55.0
const RIGHT_BOUND := 905.0
const DEADZONE    := 0.25

# ── State enum ────────────────────────────────────────────────────────────────
enum State {
	IDLE, WALK, JUMP, FALL,
	PUNCH, AIR_PUNCH,
	KICK,  AIR_KICK,
	SHEEP_SUMMON,
	DRILL_SETUP, DRILL_WALK,
	BLOCK,
	HURT, KNOCKDOWN, DEAD
}

# ── Runtime ───────────────────────────────────────────────────────────────────
var state:               State = State.IDLE
var health:              float = 100.0
var facing_right:        bool  = true
var opponent:            CharacterBody2D = null

var attack_cooldown:     float = 0.0
var attack_duration:     float = 0.0
var hurt_timer:          float = 0.0
var knockdown_timer:     float = 0.0
var is_blocking:         bool  = false
var has_hit:             bool  = false
var combo_count:         int   = 0
var combo_timer:         float = 0.0

var drill_timer:         float = 0.0
var drill_tick_timer:    float = 0.0
var sheep_spawned:       bool  = false

# Animation
var anim_frame:  int   = 0
var anim_timer:  float = 0.0
var anim_frames: Array = ANIM_IDLE
var anim_speed:  float = SPD_IDLE
var anim_loop:   bool  = true

# "just pressed" tracking
var _prev: Dictionary = {}

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var sprite:  Sprite2D = $Sprite2D
@onready var hitbox:  Area2D   = $Hitbox
@onready var hurtbox: Area2D   = $Hurtbox

# ═════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	health              = max_health
	sprite.texture      = load(SHEET_PATH)
	sprite.region_enabled = true
	sprite.scale        = Vector2(CHAR_SCALE, CHAR_SCALE)
	_set_frame(0)
	if player_id == 2:
		facing_right  = false
		sprite.flip_h = true
	hurtbox.area_entered.connect(_on_hurtbox_entered)
	_hitbox_enable(false)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_face_opponent()
	_gravity(delta)
	_handle_input(delta)
	_timers(delta)
	_animate(delta)
	_hitbox_side()
	move_and_slide()
	# Floor clamp
	if position.y > FLOOR_Y:
		position.y = FLOOR_Y
		velocity.y = 0
		if state in [State.JUMP, State.FALL, State.AIR_PUNCH, State.AIR_KICK]:
			_change(State.IDLE)
	position.x = clamp(position.x, LEFT_BOUND, RIGHT_BOUND)
	_save_prev(player_id - 1)

# ── Gravity ───────────────────────────────────────────────────────────────────
func _gravity(delta: float) -> void:
	if position.y < FLOOR_Y:
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
	if velocity.y > 80 and state == State.JUMP:
		_change(State.FALL)

# ── Input ─────────────────────────────────────────────────────────────────────
func _handle_input(delta: float) -> void:
	var dev := player_id - 1
	var on_floor := position.y >= FLOOR_Y - 2.0

	# ── States that fully lock movement ──────────────────────────────────────
	match state:
		State.HURT, State.KNOCKDOWN:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			return
		State.SHEEP_SUMMON, State.DRILL_SETUP:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			return
		State.DRILL_WALK:
			# Auto-advance toward enemy
			velocity.x = (1.0 if facing_right else -1.0) * move_speed * 0.7
			return
		State.PUNCH, State.KICK:
			velocity.x = move_toward(velocity.x, 0.0, 1000.0 * delta)
			return
		State.BLOCK:
			velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
			# Release block
			if not _btn("r2", dev):
				_change(State.IDLE)
			return

	# ── Air attacks (can attack while jumping/falling) ────────────────────
	if state in [State.JUMP, State.FALL, State.AIR_PUNCH, State.AIR_KICK]:
		if attack_cooldown <= 0:
			if _just("punch", dev) and not _just("triangle", dev):
				_start_air_punch()
				return
			if _just("kick", dev) and not _just("triangle", dev):
				_start_air_kick()
				return
		# Allow horizontal movement in air
		var adir := int(_btn("right", dev)) - int(_btn("left", dev))
		velocity.x = adir * move_speed * 0.8 if adir != 0 \
				   else move_toward(velocity.x, 0.0, 400.0 * delta)
		return

	# ── Ground ────────────────────────────────────────────────────────────
	# Block (R2, ground only)
	if _btn("r2", dev) and on_floor and attack_cooldown <= 0:
		_change(State.BLOCK)
		return

	# Special combos (Triangle held + attack button)
	if attack_cooldown <= 0 and on_floor:
		# Square + Triangle → Sheep Summon
		if _just("punch", dev) and _btn("triangle", dev):
			_start_sheep()
			return
		# Circle + Triangle → Drill Attack
		if _just("kick", dev) and _btn("triangle", dev):
			_start_drill()
			return
		# Square → Punch
		if _just("punch", dev):
			_start_punch()
			return
		# Circle → Kick
		if _just("kick", dev):
			_start_kick()
			return

	# Jump (X)
	if _just("jump", dev) and on_floor:
		velocity.y = jump_force
		_change(State.JUMP)
		return

	# Move
	var dir := int(_btn("right", dev)) - int(_btn("left", dev))
	if dir != 0:
		velocity.x = dir * move_speed
		if on_floor: _change(State.WALK)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 650.0 * delta)
		if on_floor: _change(State.IDLE)

# ── Attack launchers ──────────────────────────────────────────────────────────
func _start_punch() -> void:
	_change(State.PUNCH)
	attack_duration = ANIM_PUNCH.size() * SPD_PUNCH   # ~0.49 s
	attack_cooldown = 0.40
	has_hit = false
	_hitbox_enable(true)
	get_tree().create_timer(attack_duration * 0.6).timeout.connect(
		func(): if is_instance_valid(self): _hitbox_enable(false))

func _start_kick() -> void:
	_change(State.KICK)
	# 4 frames × 0.10s = 0.40s total; hitbox active during extended frames
	attack_duration = ANIM_KICK.size() * 0.10
	attack_cooldown = 0.55
	has_hit = false
	_hitbox_enable(true)
	# Close hitbox after 0.32s (frames 40+41 have played)
	get_tree().create_timer(0.32).timeout.connect(
		func(): if is_instance_valid(self): _hitbox_enable(false))

func _start_air_punch() -> void:
	_change(State.AIR_PUNCH)
	attack_duration = ANIM_AIR_PUNCH.size() * SPD_PUNCH
	attack_cooldown = 0.30
	has_hit = false
	_hitbox_enable(true)
	get_tree().create_timer(attack_duration * 0.6).timeout.connect(
		func(): if is_instance_valid(self): _hitbox_enable(false))

func _start_air_kick() -> void:
	_change(State.AIR_KICK)
	attack_duration = ANIM_AIR_KICK.size() * 0.10
	attack_cooldown = 0.45
	has_hit = false
	_hitbox_enable(true)
	get_tree().create_timer(0.32).timeout.connect(
		func(): if is_instance_valid(self): _hitbox_enable(false))

func _start_sheep() -> void:
	_change(State.SHEEP_SUMMON)
	attack_cooldown = 4.0
	sheep_spawned   = false
	_hitbox_enable(false)
	var dur := ANIM_SHEEP_GEST.size() * SPD_SHEEP_GEST
	get_tree().create_timer(dur).timeout.connect(func():
		if is_instance_valid(self) and state == State.SHEEP_SUMMON:
			_spawn_sheep()
			await get_tree().create_timer(0.2).timeout
			if is_instance_valid(self): _change(State.IDLE))

func _start_drill() -> void:
	_change(State.DRILL_SETUP)
	attack_cooldown  = 9.0
	drill_timer      = 0.0
	drill_tick_timer = 0.0
	_hitbox_enable(false)
	# 2 setup frames then transition to drill loop
	var setup_dur := ANIM_DRILL.size() * SPD_DRILL_SETUP
	get_tree().create_timer(setup_dur).timeout.connect(func():
		if is_instance_valid(self):
			_change(State.DRILL_WALK)
			drill_timer      = DRILL_DURATION
			drill_tick_timer = DRILL_TICK_RATE
			_hitbox_enable(true))

# ── Sheep spawn ────────────────────────────────────────────────────────────────
func _spawn_sheep() -> void:
	if sheep_spawned: return
	sheep_spawned = true
	var tex: Texture2D = load(SHEEP_PATH)
	# Direction always toward the enemy
	var toward := 1.0 if (opponent and opponent.position.x > position.x) else -1.0
	for i in 5:
		get_parent().add_child(_make_sheep(tex, i, toward))

func _make_sheep(tex: Texture2D, idx: int, toward: float) -> CharacterBody2D:
	var node := CharacterBody2D.new()
	node.name = "Sheep_P%d_%d" % [player_id, idx]

	var cs    := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size = Vector2(22, 14)
	cs.shape  = rect; cs.position = Vector2(0, -7)
	node.add_child(cs)

	# Hit area — detects enemy hurtbox (layer 2)
	var ha  := Area2D.new(); ha.name = "HitArea"
	ha.collision_layer = 4; ha.collision_mask = 2
	var hs  := CollisionShape2D.new()
	var hr  := RectangleShape2D.new()
	hr.size = Vector2(24, 28); hs.shape = hr; hs.position = Vector2(0, -14)
	ha.add_child(hs); node.add_child(ha)

	var sp      := Sprite2D.new()
	sp.texture  = tex
	sp.scale    = Vector2(2.2, 2.2)
	sp.flip_h   = (toward < 0)
	node.add_child(sp)

	# Embed direction and owner_pid as literals so they are never wrong
	var dir_val  := "1.0" if toward > 0 else "-1.0"
	var pid_val  := str(player_id)
	var scr := GDScript.new()
	scr.source_code = """
extends CharacterBody2D
var speed     := 165.0
var direction := """ + dir_val + """
var lifetime  := 7.0
var grav      := 1100.0
var hit       := false
var owner_pid := """ + pid_val + """
const FLOOR_Y := 430.0
const DAMAGE  := 10.0
func _ready():
	$HitArea.area_entered.connect(_on_hit)
func _physics_process(delta):
	lifetime -= delta
	if lifetime <= 0: queue_free(); return
	velocity.y = 0.0 if position.y >= FLOOR_Y else velocity.y + grav * delta
	velocity.x = direction * speed
	move_and_slide()
	position.y = min(position.y, FLOOR_Y)
	if position.x < 20 or position.x > 940: queue_free()
func _on_hit(area: Area2D):
	if hit: return
	var t = area.get_parent()
	if t == null: return
	if t.has_method("take_damage") and t.get("player_id") != owner_pid:
		hit = true
		t.take_damage(DAMAGE, Vector2(direction * 160.0, -50.0), 1)
		queue_free()
"""
	node.set_script(scr)

	# Stagger spawn: all behind summoner, spread out slightly
	var spacing := 38.0
	var behind  := -60.0 * toward + (idx - 2) * spacing * 0.5
	node.position = Vector2(position.x + behind, FLOOR_Y)
	return node

# ── Timers ────────────────────────────────────────────────────────────────────
func _timers(delta: float) -> void:
	if attack_cooldown > 0: attack_cooldown -= delta
	if combo_timer     > 0:
		combo_timer -= delta
		if combo_timer <= 0: combo_count = 0

	if attack_duration > 0:
		attack_duration -= delta
		if attack_duration <= 0:
			match state:
				State.PUNCH, State.KICK:        _change(State.IDLE)
				State.AIR_PUNCH, State.AIR_KICK: _change(State.FALL)

	if hurt_timer > 0:
		hurt_timer -= delta
		if hurt_timer <= 0 and state == State.HURT: _change(State.IDLE)

	if knockdown_timer > 0:
		knockdown_timer -= delta
		if knockdown_timer <= 0 and state == State.KNOCKDOWN: _change(State.IDLE)

	# Drill: periodic damage ticks
	if state == State.DRILL_WALK:
		drill_timer -= delta
		if drill_timer <= 0:
			_hitbox_enable(false)
			_change(State.IDLE)
			return
		drill_tick_timer -= delta
		if drill_tick_timer <= 0:
			drill_tick_timer = DRILL_TICK_RATE
			_drill_tick()

func _drill_tick() -> void:
	if opponent == null: return
	var dist    = abs(opponent.position.x - position.x)
	var in_front := (opponent.position.x > position.x) == facing_right
	if dist < 95.0 and in_front and opponent.position.y >= FLOOR_Y - 50.0:
		opponent.take_damage(DMG_DRILL_TICK, Vector2((1.0 if facing_right else -1.0) * 55.0, 0.0), 0)

# ── Animation ─────────────────────────────────────────────────────────────────
func _animate(delta: float) -> void:
	anim_timer -= delta
	if anim_timer > 0: return
	anim_timer = anim_speed
	anim_frame = (anim_frame + 1) % anim_frames.size() if anim_loop \
			   else min(anim_frame + 1, anim_frames.size() - 1)
	_set_frame(anim_frames[anim_frame])

func _set_frame(idx: int) -> void:
	sprite.region_rect = Rect2(idx * FRAME_W, 0, FRAME_W, FRAME_H)

func _play(frames: Array, speed: float, loop: bool) -> void:
	anim_frames = frames; anim_speed = speed; anim_loop = loop
	anim_frame  = 0; anim_timer = 0.0
	_set_frame(frames[0])

# ── State machine ─────────────────────────────────────────────────────────────
func _change(ns: State) -> void:
	if state == ns: return
	state = ns
	match ns:
		State.IDLE:        _play(ANIM_IDLE,       SPD_IDLE,        true)
		State.WALK:        _play(ANIM_WALK,       SPD_WALK,        true)
		State.JUMP:        _play(ANIM_JUMP,       SPD_JUMP,        false)
		State.FALL:        _play(ANIM_JUMP,       SPD_JUMP,        false)
		State.PUNCH:       _play(ANIM_PUNCH,      SPD_PUNCH,       false)
		State.KICK:        _play(ANIM_KICK,       SPD_KICK,        false)
		State.AIR_PUNCH:   _play(ANIM_AIR_PUNCH,  SPD_PUNCH,       false)
		State.AIR_KICK:    _play(ANIM_AIR_KICK,   SPD_KICK,        false)
		State.SHEEP_SUMMON:_play(ANIM_SHEEP_GEST, SPD_SHEEP_GEST,  false)
		State.DRILL_SETUP: _play(ANIM_DRILL,      SPD_DRILL_SETUP, false)
		State.DRILL_WALK:  _play(ANIM_DRILL_LOOP, SPD_DRILL_LOOP,  true)
		State.BLOCK:       _play(ANIM_BLOCK,      SPD_BLOCK,       false)
		State.HURT:
			_play(ANIM_IDLE, SPD_IDLE, false)
			sprite.modulate = Color(1.0, 0.25, 0.25)
		State.KNOCKDOWN:
			_play(ANIM_IDLE, SPD_IDLE, false)
			sprite.modulate = Color(1.0, 0.15, 0.15)
		State.DEAD:
			_play(ANIM_IDLE, SPD_IDLE, false)
			sprite.modulate = Color(0.35, 0.35, 0.35)

# ── Visual tint (called by GameManager each frame) ────────────────────────────
func update_visuals() -> void:
	match state:
		State.PUNCH, State.AIR_PUNCH:
			sprite.modulate = Color(1.0, 0.88, 0.2)
		State.KICK, State.AIR_KICK:
			sprite.modulate = Color(1.0, 0.55, 0.1)
		State.SHEEP_SUMMON:
			sprite.modulate = Color(0.5, 1.0, 0.5)
		State.DRILL_SETUP:
			sprite.modulate = Color(0.7, 0.7, 1.0)
		State.DRILL_WALK:
			var p = abs(sin(Time.get_ticks_msec() * 0.009))
			sprite.modulate = Color(1.0, 0.3 + p * 0.5, 0.0)
		State.BLOCK:
			sprite.modulate = Color(0.5, 0.7, 1.0)
		State.HURT, State.KNOCKDOWN:
			pass  # set in _change
		State.DEAD:
			sprite.rotation_degrees = 90.0 if facing_right else -90.0
		_:
			sprite.modulate = Color.WHITE

# ── Facing ────────────────────────────────────────────────────────────────────
func _face_opponent() -> void:
	if opponent and state in [State.IDLE, State.WALK, State.JUMP, State.FALL]:
		facing_right = opponent.position.x > position.x
	sprite.flip_h = not facing_right

func _hitbox_side() -> void:
	hitbox.position.x = 30.0 if facing_right else -30.0

func _hitbox_enable(on: bool) -> void:
	hitbox.get_node("CollisionShape2D").disabled = not on

# ── Take damage ───────────────────────────────────────────────────────────────
func take_damage(amount: float, knockback: Vector2, attacker_combo: int) -> void:
	if state == State.DEAD: return
	var dmg := amount * (1.0 - BLOCK_REDUCE) if is_blocking else amount
	health   = max(0.0, health - dmg)
	SignalBus.health_changed.emit(player_id, health, max_health)
	if health <= 0.0:
		state = State.DEAD; velocity = Vector2.ZERO
		_change(State.DEAD)
		SignalBus.fighter_died.emit(player_id)
		return
	if not is_blocking:
		velocity = knockback
		if knockback.y < -200.0:
			knockdown_timer = 1.0; _change(State.KNOCKDOWN)
		else:
			hurt_timer = 0.36; _change(State.HURT)
	if attacker_combo >= 2:
		SignalBus.combo_hit.emit(player_id, attacker_combo)

# ── Hurtbox signal ────────────────────────────────────────────────────────────
func _on_hurtbox_entered(area: Area2D) -> void:
	var atk := area.get_parent() as CharacterBody2D
	if atk == null or atk == self: return
	if not atk.has_method("take_damage"): return
	if atk.state == State.DRILL_WALK: return   # drill uses tick damage
	if atk.has_hit: return

	atk.has_hit      = true
	atk.combo_count += 1
	atk.combo_timer  = 1.5

	var in_air = atk.state in [State.AIR_PUNCH, State.AIR_KICK]
	var is_kick = atk.state in [State.KICK, State.AIR_KICK]
	var dmg  := (DMG_KICK_AIR if in_air else DMG_KICK) if is_kick \
			 else (DMG_PUNCH_AIR if in_air else DMG_PUNCH)
	var kb_x := 310.0 if atk.facing_right else -310.0
	var kb_y := -620.0 if is_kick else -90.0   # kick launches enemy airborne

	take_damage(dmg, Vector2(kb_x, kb_y), atk.combo_count)

# ── Controller helpers ────────────────────────────────────────────────────────
func _btn(action: String, dev: int) -> bool:
	match action:
		"left":      return Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT)  \
						 or Input.get_joy_axis(dev, JOY_AXIS_LEFT_X) < -DEADZONE
		"right":     return Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT) \
						 or Input.get_joy_axis(dev, JOY_AXIS_LEFT_X) > DEADZONE
		"jump":      return Input.is_joy_button_pressed(dev, JOY_BUTTON_A)       # X / Cross
		"punch":     return Input.is_joy_button_pressed(dev, JOY_BUTTON_X)       # Square
		"kick":      return Input.is_joy_button_pressed(dev, JOY_BUTTON_B)       # Circle
		"triangle":  return Input.is_joy_button_pressed(dev, JOY_BUTTON_Y)       # Triangle
		"r2":        return Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > DEADZONE \
						 or Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_SHOULDER)
	return false

func _just(action: String, dev: int) -> bool:
	var key := "%d_%s" % [dev, action]
	var now  := _btn(action, dev)
	return now and not _prev.get(key, false)

func _save_prev(dev: int) -> void:
	for a in ["left","right","jump","punch","kick","triangle","r2"]:
		_prev["%d_%s" % [dev, a]] = _btn(a, dev)

# ── Reset ─────────────────────────────────────────────────────────────────────
func reset(pos: Vector2, face_right: bool) -> void:
	position = pos; health = max_health; velocity = Vector2.ZERO
	facing_right = face_right
	attack_cooldown = 0.0; attack_duration = 0.0
	hurt_timer = 0.0; knockdown_timer = 0.0
	drill_timer = 0.0; drill_tick_timer = 0.0
	sheep_spawned = false; has_hit = false
	combo_count = 0; combo_timer = 0.0; is_blocking = false
	sprite.modulate = Color.WHITE; sprite.rotation_degrees = 0.0
	_hitbox_enable(false); _prev.clear()
	_change(State.IDLE)

func get_health_ratio() -> float:
	return health / max_health
