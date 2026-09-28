extends CharacterBody2D
class_name Fighter

# ──────────────────────────────────────────────
#  Fighter.gd
#
#  Key feature: when hit by a KICK the fighter
#  enters the FLYING state and plays the air-sheet
#  "fly" animation while soaring through the air.
#  They land when they touch the floor again.
#
#  States:
#    IDLE / WALK / JUMP / FALL
#    PUNCH / KICK / SPECIAL
#    BLOCK
#    HURT       – small hit (punch/special), short stun on ground
#    FLYING     – kicked into the air, plays air sheet
#    LANDING    – brief landing recovery after FLYING
#    KNOCKDOWN  – heavy hit while already on ground
#    VICTORY / DEAD
# ──────────────────────────────────────────────

signal health_changed(new_hp: float)
signal died()

@export var player_id: int = 1
@export var character_name: String = "Middle"

# ── Physics ──
const GRAVITY:      float = 1400.0
const PUSH_FORCE:   float = 320.0
const KICK_LAUNCH_X: float = 480.0   # horizontal launch speed from kick
const KICK_LAUNCH_Y: float = -420.0  # upward launch speed from kick

# ── Controller buttons ──
const BTN_CROSS     = 0
const BTN_CIRCLE    = 1
const BTN_SQUARE    = 2
const BTN_TRIANGLE  = 3
const BTN_L1        = 9
const BTN_R1        = 10
const BTN_DPAD_UP   = 11
const BTN_DPAD_LEFT = 13
const BTN_DPAD_RIGHT= 14
const AXIS_LX       = 0
const STICK_DEAD    = 0.25

# ── Combat timing ──
const T_STARTUP:   float = 0.07
const T_ACTIVE:    float = 0.12
const T_RECOVER:   float = 0.18
const T_HURT:      float = 0.35
const T_LANDING:   float = 0.40   # recovery frames after landing from fly
const T_KNOCKDOWN: float = 1.0

# ── State machine ──
enum St {
	IDLE, WALK, JUMP, FALL,
	PUNCH, KICK, SPECIAL,
	BLOCK,
	HURT,
	FLYING,    # kicked into the air – air sheet plays
	LANDING,   # just landed after flying
	KNOCKDOWN,
	VICTORY, DEAD
}
var state: St = St.IDLE

var opponent:     Fighter = null
var facing_right: bool    = true
var is_dead:      bool    = false

var max_health: float = 100.0
var health:     float = 100.0
var dmg_base:   float = 10.0
var spd:        float = 200.0
var j_force:    float = -500.0

var atk_phase: int   = 0
var atk_timer: float = 0.0
var atk_hit:   bool  = false

var hurt_t:    float = 0.0
var landing_t: float = 0.0
var kd_t:      float = 0.0

var pfx:    String = "p1_"
var joy_id: int    = 0
var _joy_prev: Dictionary = {}

var sprite:  AnimatedSprite2D
var hitbox:  Area2D
var hurtbox: Area2D

# ── Track whether air sheet animation has finished playing ──
var _fly_anim_done: bool = false

# ─────────────────────────────────
func _ready() -> void:
	pfx    = "p" + str(player_id) + "_"
	joy_id = player_id - 1
	_load_stats()
	_make_nodes()
	_build_frames()
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")

func _load_stats() -> void:
	var d = GameData.get_char(character_name)
	var s = d["stats"]
	max_health = s["max_health"]
	health     = max_health
	spd        = s["speed"]
	j_force    = s["jump_force"]
	dmg_base   = s["damage"]

func _make_nodes() -> void:
	sprite          = AnimatedSprite2D.new()
	sprite.scale    = Vector2(3.0, 3.0)
	sprite.position = Vector2(0, -16)
	add_child(sprite)
	# Connect animation_finished so we know when the fly anim ends
	sprite.animation_finished.connect(_on_sprite_animation_finished)

	var col      = CollisionShape2D.new()
	var cap      = CapsuleShape2D.new()
	cap.radius   = 10.0
	cap.height   = 28.0
	col.shape    = cap
	col.position = Vector2(0, -16)
	add_child(col)

	hitbox                  = Area2D.new()
	hitbox.name             = "Hitbox"
	hitbox.collision_layer  = 2
	hitbox.collision_mask   = 4
	hitbox.monitoring       = false
	var hbs                 = CollisionShape2D.new()
	var hbr                 = RectangleShape2D.new()
	hbr.size                = Vector2(28, 22)
	hbs.shape               = hbr
	hbs.position            = Vector2(22, 0)
	hitbox.add_child(hbs)
	hitbox.position         = Vector2(0, -16)
	add_child(hitbox)
	hitbox.area_entered.connect(_on_hitbox_area_entered)

	hurtbox                 = Area2D.new()
	hurtbox.name            = "Hurtbox"
	hurtbox.collision_layer = 4
	hurtbox.collision_mask  = 2
	hurtbox.monitoring      = false
	hurtbox.monitorable     = true
	var hub                 = CollisionShape2D.new()
	var hur                 = CapsuleShape2D.new()
	hur.radius              = 12.0
	hur.height              = 26.0
	hub.shape               = hur
	hurtbox.add_child(hub)
	hurtbox.position        = Vector2(0, -16)
	add_child(hurtbox)

# ── Build SpriteFrames ──
func _build_frames() -> void:
	var data    = GameData.get_char(character_name)
	var gnd_tex = load(data["sprite_sheet"]) as Texture2D
	if gnd_tex == null:
		push_error("Fighter: missing ground sheet for " + character_name)
		return

	var fw  = int(data["frame_size"].x)
	var fh  = int(data["frame_size"].y)

	var air_path = data.get("air_sheet", "") as String
	var air_tex: Texture2D = null
	if air_path != "" and air_path != data["sprite_sheet"]:
		air_tex = load(air_path) as Texture2D

	var afw = int(data["air_frame_size"].x)
	var afh = int(data["air_frame_size"].y)

	var sf = SpriteFrames.new()

	# Ground animations
	for anim_name in data["animations"]:
		var info: Dictionary = data["animations"][anim_name]
		if not sf.has_animation(anim_name):
			sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, bool(info["loop"]))
		sf.set_animation_speed(anim_name, float(info["fps"]))
		for i in range(int(info["count"])):
			var atlas    = AtlasTexture.new()
			atlas.atlas  = gnd_tex
			atlas.region = Rect2((int(info["start"]) + i) * fw, 0, fw, fh)
			sf.add_frame(anim_name, atlas)

	# Air animations — stored WITHOUT "air_" prefix in SpriteFrames
	# because we reference them as "fly" and "air_jump" directly
	if air_tex != null:
		for anim_name in data["air_animations"]:
			var info: Dictionary = data["air_animations"][anim_name]
			# Store as "air_<name>" so it doesn't conflict with ground anims
			var stored_name = "air_" + anim_name
			if not sf.has_animation(stored_name):
				sf.add_animation(stored_name)
			sf.set_animation_loop(stored_name, bool(info["loop"]))
			sf.set_animation_speed(stored_name, float(info["fps"]))
			for i in range(int(info["count"])):
				var atlas    = AtlasTexture.new()
				atlas.atlas  = air_tex
				atlas.region = Rect2((int(info["start"]) + i) * afw, 0, afw, afh)
				sf.add_frame(stored_name, atlas)

	sprite.sprite_frames = sf

# ─────────────────────────────────
#  CONTROLLER HELPERS
# ─────────────────────────────────
func _joy_held(btn: int) -> bool:
	return Input.is_joy_button_pressed(joy_id, btn)

func _joy_just(btn: int) -> bool:
	return Input.is_joy_button_pressed(joy_id, btn) and not _joy_prev.get(btn, false)

func _joy_lx() -> float:
	var stick = Input.get_joy_axis(joy_id, AXIS_LX)
	if absf(stick) > STICK_DEAD: return stick
	if _joy_held(BTN_DPAD_LEFT):  return -1.0
	if _joy_held(BTN_DPAD_RIGHT): return  1.0
	return 0.0

func _snapshot_joy() -> void:
	for b in [BTN_CROSS, BTN_CIRCLE, BTN_SQUARE, BTN_L1, BTN_R1,
			  BTN_DPAD_UP, BTN_DPAD_LEFT, BTN_DPAD_RIGHT]:
		_joy_prev[b] = Input.is_joy_button_pressed(joy_id, b)

# ─────────────────────────────────
#  PHYSICS LOOP
# ─────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_apply_gravity(delta)
	_tick_timers(delta)

	# Check if FLYING character has just landed
	if state == St.FLYING and is_on_floor():
		_on_landed()

	if _can_act():
		_read_input()

	_face_opponent()
	_clamp_x()
	move_and_slide()
	_sync_anim()
	_sync_hitbox_side()
	_snapshot_joy()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		if velocity.y > 0:
			velocity.y = 0.0
		# Normal jump/fall → idle transition
		if state == St.JUMP or state == St.FALL:
			_set_state(St.IDLE)
		# FLYING lands are handled separately in _on_landed()

func _on_landed() -> void:
	# Character just hit the floor after being kick-launched
	velocity.x = 0.0
	velocity.y = 0.0
	if health <= 0.0:
		_set_state(St.DEAD)
	else:
		_set_state(St.LANDING)
		landing_t = T_LANDING

func _tick_timers(delta: float) -> void:
	# Attack phases
	if state in [St.PUNCH, St.KICK, St.SPECIAL]:
		atk_timer -= delta
		if atk_timer <= 0.0:
			match atk_phase:
				0:
					atk_phase = 1
					atk_timer = T_ACTIVE
					hitbox.monitoring = true
					atk_hit = false
				1:
					atk_phase = 2
					atk_timer = T_RECOVER
					hitbox.monitoring = false
				2:
					hitbox.monitoring = false
					_set_state(St.IDLE)

	# Hurt stun
	if state == St.HURT:
		hurt_t -= delta
		if hurt_t <= 0.0:
			_set_state(St.IDLE)

	# Landing recovery
	if state == St.LANDING:
		landing_t -= delta
		if landing_t <= 0.0:
			_set_state(St.IDLE)

	# Ground knockdown
	if state == St.KNOCKDOWN:
		kd_t -= delta
		if kd_t <= 0.0:
			_set_state(St.IDLE)

func _can_act() -> bool:
	return state not in [
		St.PUNCH, St.KICK, St.SPECIAL,
		St.HURT, St.FLYING, St.LANDING, St.KNOCKDOWN,
		St.VICTORY, St.DEAD
	]

# ─────────────────────────────────
#  INPUT
# ─────────────────────────────────
func _read_input() -> void:
	var kb_left  = Input.is_action_pressed(pfx + "left")
	var kb_right = Input.is_action_pressed(pfx + "right")
	var kb_jump  = Input.is_action_just_pressed(pfx + "jump")
	var kb_punch = Input.is_action_just_pressed(pfx + "punch")
	var kb_kick  = Input.is_action_just_pressed(pfx + "kick")
	var kb_spec  = Input.is_action_just_pressed(pfx + "special")
	var kb_block = Input.is_action_pressed(pfx + "block")

	var lx        = _joy_lx()
	var joy_left  = lx < -STICK_DEAD or _joy_held(BTN_DPAD_LEFT)
	var joy_right = lx >  STICK_DEAD or _joy_held(BTN_DPAD_RIGHT)
	var joy_jump  = _joy_just(BTN_CROSS)  or _joy_just(BTN_DPAD_UP)
	var joy_punch = _joy_just(BTN_SQUARE)
	var joy_kick  = _joy_just(BTN_CIRCLE)
	var joy_spec  = _joy_just(BTN_R1)
	var joy_block = _joy_held(BTN_L1)

	var go_left  = kb_left  or joy_left
	var go_right = kb_right or joy_right
	var do_jump  = kb_jump  or joy_jump
	var do_punch = kb_punch or joy_punch
	var do_kick  = kb_kick  or joy_kick
	var do_spec  = kb_spec  or joy_spec
	var do_block = kb_block or joy_block

	# Block
	if do_block and is_on_floor() and not go_left and not go_right:
		_set_state(St.BLOCK)
		velocity.x = move_toward(velocity.x, 0.0, 900.0)
		return
	elif state == St.BLOCK and not do_block:
		_set_state(St.IDLE)

	# Attacks
	if do_punch: _begin_attack(St.PUNCH);   return
	if do_kick:  _begin_attack(St.KICK);    return
	if do_spec:  _begin_attack(St.SPECIAL); return

	# Jump
	if do_jump and is_on_floor():
		velocity.y = j_force
		_set_state(St.JUMP)

	# Move
	if go_left and not go_right:
		var mag = clampf(absf(lx), 0.0, 1.0) if absf(lx) > STICK_DEAD else 1.0
		velocity.x = -spd * mag
		if is_on_floor() and state != St.JUMP:
			_set_state(St.WALK)
	elif go_right and not go_left:
		var mag = clampf(absf(lx), 0.0, 1.0) if absf(lx) > STICK_DEAD else 1.0
		velocity.x = spd * mag
		if is_on_floor() and state != St.JUMP:
			_set_state(St.WALK)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 900.0)
		if is_on_floor() and state == St.WALK:
			_set_state(St.IDLE)

	if not is_on_floor() and velocity.y > 50.0 and state != St.JUMP:
		_set_state(St.FALL)

func _begin_attack(new_st: St) -> void:
	_set_state(new_st)
	atk_phase = 0
	atk_timer = T_STARTUP
	atk_hit   = false
	hitbox.monitoring = false
	velocity.x = 60.0 if facing_right else -60.0

# ── Hitbox connected ──
func _on_hitbox_area_entered(area: Area2D) -> void:
	if atk_hit: return
	var parent = area.get_parent()
	if parent == self or not (parent is Fighter) or parent != opponent:
		return
	atk_hit = true
	var is_kick = (state == St.KICK)
	var mult = 2.0 if state == St.SPECIAL else (1.5 if is_kick else 1.0)
	var dir  = 1 if (opponent.global_position.x > global_position.x) else -1
	opponent.take_hit(dmg_base * mult, dir, is_kick)

# ── Receive a hit ──
# is_kick = true → launch into the air with fly animation
func take_hit(dmg: float, dir: int, is_kick: bool = false) -> void:
	if is_dead: return
	# Flying characters can be hit again mid-air but with reduced effect
	if state == St.FLYING:
		health -= dmg * 0.5
		health = maxf(health, 0.0)
		health_changed.emit(health)
		if health <= 0.0: _die()
		return

	if state == St.BLOCK:
		health -= dmg * 0.1
		velocity.x = dir * PUSH_FORCE * 0.4
		health = maxf(health, 0.0)
		health_changed.emit(health)
		_flash(Color(0.5, 0.5, 1.0))
		return

	health -= dmg
	health = maxf(health, 0.0)
	health_changed.emit(health)

	if is_kick:
		# ── KICK: launch into the air → FLYING state ──
		velocity.x = dir * KICK_LAUNCH_X
		velocity.y = KICK_LAUNCH_Y
		_fly_anim_done = false
		_set_state(St.FLYING)
		_flash(Color(1.0, 0.6, 0.1))
	elif dmg >= 14.0:
		# Heavy non-kick hit → ground knockdown
		velocity.x = dir * PUSH_FORCE
		velocity.y = -80.0
		_set_state(St.KNOCKDOWN)
		kd_t = T_KNOCKDOWN
		_flash(Color(1, 0.3, 0.3))
	else:
		# Normal hit → brief stun
		velocity.x = dir * PUSH_FORCE * 0.6
		velocity.y = -50.0
		_set_state(St.HURT)
		hurt_t = T_HURT
		_flash(Color(1, 0.3, 0.3))

	if health <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	_set_state(St.DEAD)
	hitbox.monitoring = false
	velocity = Vector2.ZERO
	died.emit()

func _flash(color: Color = Color(1, 0.3, 0.3)) -> void:
	sprite.modulate = color
	get_tree().create_timer(0.1).timeout.connect(func(): sprite.modulate = Color.WHITE)

# ── Called when the fly animation finishes playing ──
func _on_sprite_animation_finished() -> void:
	if state == St.FLYING:
		_fly_anim_done = true
		# Hold last frame until they land

func _face_opponent() -> void:
	if opponent == null: return
	# Don't flip while flying or stunned — keep the direction of travel
	if state in [St.FLYING, St.HURT, St.KNOCKDOWN, St.LANDING, St.DEAD]:
		return
	facing_right  = opponent.global_position.x >= global_position.x
	sprite.flip_h = not facing_right

func _clamp_x() -> void:
	global_position.x = clampf(global_position.x, 24.0, 1256.0)

func _set_state(new_st: St) -> void:
	if state == new_st: return
	if state in [St.PUNCH, St.KICK, St.SPECIAL]:
		hitbox.monitoring = false
	state = new_st

func _sync_hitbox_side() -> void:
	hitbox.position.x = 22.0 if facing_right else -22.0

# ─────────────────────────────────
#  ANIMATION SYNC
# ─────────────────────────────────
func _sync_anim() -> void:
	if sprite.sprite_frames == null: return
	var want = _desired_anim()
	# Fallback if animation doesn't exist
	if not sprite.sprite_frames.has_animation(want):
		want = "idle"
	if sprite.animation != want:
		sprite.play(want)

func _desired_anim() -> String:
	match state:
		St.IDLE:      return "idle"
		St.WALK:      return "walk"
		St.JUMP:
			# Prefer air sheet jump
			if sprite.sprite_frames.has_animation("air_jump"):
				return "air_jump"
			return "jump"
		St.FALL:
			if sprite.sprite_frames.has_animation("air_jump"):
				return "air_jump"
			return "jump"
		St.PUNCH:     return "punch"
		St.KICK:      return "kick"
		St.SPECIAL:   return "special"
		St.BLOCK:     return "block"
		St.HURT:      return "hurt"

		St.FLYING:
			# Play air_fly if available, fall back to air_jump, then jump
			if sprite.sprite_frames.has_animation("air_fly"):
				return "air_fly"
			if sprite.sprite_frames.has_animation("air_jump"):
				return "air_jump"
			return "jump"

		St.LANDING:   return "knockdown"
		St.KNOCKDOWN: return "knockdown"
		St.VICTORY:   return "victory"
		St.DEAD:      return "knockdown"
	return "idle"

func play_victory() -> void:
	hitbox.monitoring = false
	velocity = Vector2.ZERO
	_set_state(St.VICTORY)
