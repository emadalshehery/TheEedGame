extends Node2D
# ──────────────────────────────────────────────
#  CharSelect.gd — character selection screen
#  Builds everything in code.
#  P1: A/D browse, F confirm
#  P2: ←/→ browse, Num1 confirm
# ──────────────────────────────────────────────

const CHAR_LIST: Array = GameData.CHARACTER_ORDER

# Portrait layout — the Character_select-Sheet.png
# Width=576, Height=32 → 18 frames at 32x32
# Each character occupies 2 frames (idle pose + highlighted)
# We'll treat frame 0,2,4,6,8,10,12 as the 7 character portraits.
const SELECT_SHEET_W: int = 576
const SELECT_FRAME_W: int = 32
const SELECT_FRAME_H: int = 32
const PORTRAIT_SCALE: int = 4   # display at 4× size

# ── State ──
var p1_idx:       int  = 0
var p2_idx:       int  = 5  # default P2 = TheDeveloper
var p1_confirmed: bool = false
var p2_confirmed: bool = false

# ── Nodes built at runtime ──
var p1_cursor:    ColorRect
var p2_cursor:    ColorRect
var p1_name_lbl:  Label
var p2_name_lbl:  Label
var p1_ready_lbl: Label
var p2_ready_lbl: Label
var portraits:    Array = []   # array of TextureRect per character

const PORTRAIT_Y: float = 280.0
const PORTRAIT_SPACING: float = 112.0
const PORTRAITS_START_X: float = 60.0

var _bg_tex_cs: Texture2D
var _bg_offset_cs: float = 0.0
const BG_SCROLL_CS: float = 60.0
const BG_SCALE_CS: float  = 720.0 / 128.0

func _draw() -> void:
	if _bg_tex_cs == null:
		return
	var tile_w = _bg_tex_cs.get_width() * BG_SCALE_CS
	var num_tiles = int(ceil(1280.0 / tile_w)) + 2
	var offset = fmod(_bg_offset_cs, tile_w)
	for i in range(num_tiles):
		draw_texture_rect(_bg_tex_cs, Rect2(i * tile_w - offset, 0, tile_w, 720.0), false)

func _ready() -> void:
	# Scrolling background
	_bg_tex_cs = load("res://assets/ui/background.png") as Texture2D

	# Dark overlay
	var ov = ColorRect.new()
	ov.color    = Color(0, 0, 0, 0.5)
	ov.size     = Vector2(1280, 720)
	ov.position = Vector2.ZERO
	add_child(ov)

	# Title
	_make_label("── SELECT YOUR FIGHTER ──", Vector2(290, 30),
				Vector2(700, 60), 36, Color(1, 0.85, 0.1, 1), true)

	# "VS" text
	_make_label("VS", Vector2(590, 180), Vector2(100, 70),
				52, Color(1, 0.5, 0, 1), true)

	# Build portrait grid
	var sel_tex = load("res://assets/ui/Character_select-Sheet.png") as Texture2D
	_build_portraits(sel_tex)

	# Cursor rects
	p1_cursor = ColorRect.new()
	p1_cursor.color = Color(0.2, 0.9, 0.3, 0.35)
	p1_cursor.size  = Vector2(SELECT_FRAME_W * PORTRAIT_SCALE + 8,
							  SELECT_FRAME_H * PORTRAIT_SCALE + 8)
	add_child(p1_cursor)

	p2_cursor = ColorRect.new()
	p2_cursor.color = Color(0.9, 0.25, 0.25, 0.35)
	p2_cursor.size  = Vector2(SELECT_FRAME_W * PORTRAIT_SCALE + 8,
							  SELECT_FRAME_H * PORTRAIT_SCALE + 8)
	add_child(p2_cursor)

	# Name / ready labels
	p1_name_lbl  = _make_label("", Vector2(60,  460), Vector2(460, 36), 22, Color(0.3,1,0.4,1), false)
	p2_name_lbl  = _make_label("", Vector2(760, 460), Vector2(460, 36), 22, Color(1,0.4,0.4,1), true)
	p1_ready_lbl = _make_label("Press Square or F to confirm",    Vector2(60,  500), Vector2(460, 28), 15, Color(0.7,0.7,0.7,1), false)
	p2_ready_lbl = _make_label("Press Square or Num1 to confirm", Vector2(760, 500), Vector2(460, 28), 15, Color(0.7,0.7,0.7,1), true)

	_make_label("D-pad L/R  or  A / D  or  ◄ / ►  to browse     ESC = back to menu",
				Vector2(290, 560), Vector2(700, 26), 15, Color(0.6,0.6,0.6,1), true)

	_refresh_ui()

# ── Build portrait display for each character ──
func _build_portraits(sel_tex: Texture2D) -> void:
	var data = GameData.CHARACTERS
	var n    = CHAR_LIST.size()

	for i in range(n):
		var char_name: String = CHAR_LIST[i]
		var cdata = data[char_name]
		var px = PORTRAITS_START_X + i * PORTRAIT_SPACING
		var py = PORTRAIT_Y

		# Use the character's own sprite sheet — frame 0 = idle pose
		var char_tex = load(cdata["sprite_sheet"]) as Texture2D
		var tr = TextureRect.new()
		if char_tex:
			var atlas        = AtlasTexture.new()
			atlas.atlas      = char_tex
			atlas.region     = Rect2(0, 0, 32, 32)   # first frame
			tr.texture       = atlas
			tr.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.size          = Vector2(SELECT_FRAME_W * PORTRAIT_SCALE,
									  SELECT_FRAME_H * PORTRAIT_SCALE)
		tr.position = Vector2(px, py)
		add_child(tr)
		portraits.append(tr)

		# Character name below portrait
		_make_label(cdata["display_name"],
					Vector2(px - 20, py + SELECT_FRAME_H * PORTRAIT_SCALE + 6),
					Vector2(SELECT_FRAME_W * PORTRAIT_SCALE + 40, 22),
					11, Color(0.85,0.85,0.85,1), true)

# ── Joy state for char select (just-pressed detection) ──
var _joy_prev_cs: Array = [{}, {}]   # index 0 = P1 device, 1 = P2 device

const CS_BTN_LEFT   = 13
const CS_BTN_RIGHT  = 14
const CS_BTN_SQUARE = 2
const CS_AXIS_X     = 0
const CS_DEAD       = 0.5

func _joy_just_cs(device: int, btn: int) -> bool:
	var now  = Input.is_joy_button_pressed(device, btn)
	var prev = _joy_prev_cs[device].get(btn, false)
	return now and not prev

func _joy_axis_just_cs(device: int, negative: bool) -> bool:
	var val  = Input.get_joy_axis(device, CS_AXIS_X)
	var key  = "axis_neg" if negative else "axis_pos"
	var now  = (val < -CS_DEAD) if negative else (val > CS_DEAD)
	var prev = _joy_prev_cs[device].get(key, false)
	return now and not prev

func _snapshot_cs() -> void:
	for device in [0, 1]:
		for btn in [CS_BTN_LEFT, CS_BTN_RIGHT, CS_BTN_SQUARE]:
			_joy_prev_cs[device][btn] = Input.is_joy_button_pressed(device, btn)
		var val = Input.get_joy_axis(device, CS_AXIS_X)
		_joy_prev_cs[device]["axis_neg"] = val < -CS_DEAD
		_joy_prev_cs[device]["axis_pos"] = val >  CS_DEAD

# ─────────────────────────────────
func _process(_delta: float) -> void:
	# Scroll background
	_bg_offset_cs += BG_SCROLL_CS * _delta
	queue_redraw()
	if p1_confirmed and p2_confirmed:
		return

	# ── P1 input ──
	if not p1_confirmed:
		var go_left  = Input.is_action_just_pressed("p1_left")  or _joy_just_cs(0, CS_BTN_LEFT)  or _joy_axis_just_cs(0, true)
		var go_right = Input.is_action_just_pressed("p1_right") or _joy_just_cs(0, CS_BTN_RIGHT) or _joy_axis_just_cs(0, false)
		var confirm  = Input.is_action_just_pressed("p1_punch") or _joy_just_cs(0, CS_BTN_SQUARE)
		if go_left:
			p1_idx = (p1_idx - 1 + CHAR_LIST.size()) % CHAR_LIST.size()
			_refresh_ui()
		if go_right:
			p1_idx = (p1_idx + 1) % CHAR_LIST.size()
			_refresh_ui()
		if confirm:
			p1_confirmed = true
			GameData.player1_char = CHAR_LIST[p1_idx]
			p1_ready_lbl.text = "✔  READY!"
			p1_ready_lbl.add_theme_color_override("font_color", Color(0.2,1,0.3,1))
			_check_both()

	# ── P2 input ──
	if not p2_confirmed:
		var go_left  = Input.is_action_just_pressed("p2_left")  or _joy_just_cs(1, CS_BTN_LEFT)  or _joy_axis_just_cs(1, true)
		var go_right = Input.is_action_just_pressed("p2_right") or _joy_just_cs(1, CS_BTN_RIGHT) or _joy_axis_just_cs(1, false)
		var confirm  = Input.is_action_just_pressed("p2_punch") or _joy_just_cs(1, CS_BTN_SQUARE)
		if go_left:
			p2_idx = (p2_idx - 1 + CHAR_LIST.size()) % CHAR_LIST.size()
			_refresh_ui()
		if go_right:
			p2_idx = (p2_idx + 1) % CHAR_LIST.size()
			_refresh_ui()
		if confirm:
			p2_confirmed = true
			GameData.player2_char = CHAR_LIST[p2_idx]
			p2_ready_lbl.text = "✔  READY!"
			p2_ready_lbl.add_theme_color_override("font_color", Color(1,0.4,0.3,1))
			_check_both()

	# Back
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

	_snapshot_cs()

func _check_both() -> void:
	if p1_confirmed and p2_confirmed:
		_make_label("GET READY TO FIGHT!", Vector2(390, 590), Vector2(500, 50),
					28, Color(1, 0.9, 0.1, 1), true)
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://scenes/FightScene.tscn")

func _refresh_ui() -> void:
	# Move cursors
	if p1_cursor and portraits.size() > p1_idx:
		var pr: TextureRect = portraits[p1_idx]
		p1_cursor.position = Vector2(pr.position.x - 4, pr.position.y - 4)

	if p2_cursor and portraits.size() > p2_idx:
		var pr: TextureRect = portraits[p2_idx]
		p2_cursor.position = Vector2(pr.position.x - 4, pr.position.y - 4)

	# Update name labels
	if p1_name_lbl:
		p1_name_lbl.text = "P1 ▶  " + GameData.get_char(CHAR_LIST[p1_idx])["display_name"]
	if p2_name_lbl:
		p2_name_lbl.text = GameData.get_char(CHAR_LIST[p2_idx])["display_name"] + "  ◀ P2"

	# Highlight selected portrait
	for i in range(portraits.size()):
		var tr: TextureRect = portraits[i]
		if i == p1_idx or i == p2_idx:
			tr.modulate = Color(1.4, 1.4, 1.4, 1)
		else:
			tr.modulate = Color(0.7, 0.7, 0.7, 1)

# ─── Helper ──────────────────────────────────
func _make_label(text: String, pos: Vector2, sz: Vector2,
				 font_size: int, color: Color, center: bool) -> Label:
	var lbl = Label.new()
	lbl.text     = text
	lbl.position = pos
	lbl.size     = sz
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	if center:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)
	return lbl
