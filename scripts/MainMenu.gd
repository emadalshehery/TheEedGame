extends Node2D
# ──────────────────────────────────────────────
#  MainMenu.gd
#
#  Background: 384x128 pixel-art scene scaled to
#  fill 1280x720, three copies laid side-by-side
#  and scrolled right-to-left in a seamless loop.
#
#  Menu sprites from menu_sheet.png (1024x128, 4 frames of 256x128):
#    Frame 0 – Title  "The Diems Fight"
#    Frame 1 – "Start Fighting"
#    Frame 2 – "Options"
#    Frame 3 – "Exit"
#
#  All sprites are centred on screen and scaled up.
#  Hovering highlights the button. Click or Enter confirms.
# ──────────────────────────────────────────────

const VIEWPORT_W: int = 1280
const VIEWPORT_H: int = 720

# Background scroll speed (pixels/sec in screen-space)
const SCROLL_SPEED: float = 80.0

# Scale for the pixel-art background (384x128 → fills 1280x720)
const BG_SCALE: float = 720.0 / 128.0          # 5.625
const BG_SCALED_W: float = 384.0 * BG_SCALE     # 2160 px

# How many copies we need so scrolling never gaps: ceil(1280 / 2160) + 1 = 2 is enough
# but let's use 3 for safety
const BG_COPIES: int = 3

# Menu sprite scale — each frame is 256x128, display at 3×
const MENU_SCALE: float = 3.0
const FRAME_W:    int   = 256
const FRAME_H:    int   = 128
const MENU_DISPLAY_W: float = FRAME_W * MENU_SCALE   # 768
const MENU_DISPLAY_H: float = FRAME_H * MENU_SCALE   # 384

# Vertical positions of each element (centred group)
# Total height of all 4 items with gaps: 4*384 would be too tall; use smaller scale for buttons
const TITLE_SCALE:  float = 3.0
const BTN_SCALE:    float = 2.0
const TITLE_H:      float = FRAME_H * TITLE_SCALE   # 384
const BTN_H:        float = FRAME_H * BTN_SCALE     # 256
const BTN_W:        float = FRAME_W * BTN_SCALE     # 512
const GAP:          float = 10.0

# Vertical layout — centred in 720px
# Total block: title_h + gap + 3*(btn_h + gap) = 384 + 10 + 3*(256+10) = 392 + 798 = 1190 too tall
# Use smaller scales:
const T_SCALE: float = 2.5   # title
const B_SCALE: float = 1.8   # buttons
const TH: float = FRAME_H * T_SCALE   # 320
const BH: float = FRAME_H * B_SCALE   # 230 (but content is only ~40px tall in the frame)
const BW: float = FRAME_W * B_SCALE   # 460
const VGAP: float = 8.0

# Since each 128px frame has lots of empty black space around the text,
# we use a tighter "stride" for layout rather than the full BH
const BTN_STRIDE: float = 70.0    # vertical distance between button centres
const TITLE_BTN_GAP: float = 20.0 # gap between bottom of title and first button

# ── State ──
var bg_sprites: Array = []
var bg_offset:  float = 0.0

# Menu item nodes
var title_node:  Sprite2D
var btn_nodes:   Array = []    # [start, options, exit]
var btn_hovered: int = 0       # which button is highlighted (0,1,2)
var btn_rects:   Array = []    # Rect2 for each button in screen coords

var winner_lbl: Label

func _ready() -> void:
	_build_background()
	_build_menu()
	_build_winner_label()
	_build_controls_hint()

# ─────────────────────────────────
#  BACKGROUND — 3 tiling copies
# ─────────────────────────────────
func _build_background() -> void:
	var tex = load("res://assets/ui/background.png") as Texture2D
	if tex == null:
		push_error("MainMenu: missing background.png")
		# Fallback solid colour
		var cr = ColorRect.new()
		cr.color = Color(0.08, 0.06, 0.04)
		cr.size  = Vector2(VIEWPORT_W, VIEWPORT_H)
		add_child(cr)
		return

	for i in range(BG_COPIES):
		var sp       = Sprite2D.new()
		sp.texture   = tex
		sp.scale     = Vector2(BG_SCALE, BG_SCALE)
		# Sprite origin is centre; position so left edge starts at i * BG_SCALED_W
		sp.position  = Vector2(BG_SCALED_W * i + BG_SCALED_W * 0.5, VIEWPORT_H * 0.5)
		add_child(sp)
		bg_sprites.append(sp)

# ─────────────────────────────────
#  MENU SPRITES
# ─────────────────────────────────
func _build_menu() -> void:
	var tex = load("res://assets/ui/menu_sheet.png") as Texture2D
	if tex == null:
		push_error("MainMenu: missing menu_sheet.png")
		_build_fallback_menu()
		return

	# Semi-transparent dark panel behind everything so text is readable
	var panel = ColorRect.new()
	panel.color    = Color(0, 0, 0, 0.52)
	panel.size     = Vector2(700, 380)
	panel.position = Vector2((VIEWPORT_W - 700) * 0.5, (VIEWPORT_H - 380) * 0.5)
	add_child(panel)

	# Total visible block height: title content (~50px at T_SCALE) + gap + 3 buttons at stride
	# Centre the whole group on screen
	var title_content_h: float = 50.0 * T_SCALE   # approx visible text height
	var total_h: float = title_content_h + TITLE_BTN_GAP + 3.0 * BTN_STRIDE
	var start_y: float = (VIEWPORT_H - total_h) * 0.5
	var cx: float = VIEWPORT_W * 0.5

	# ── Title (frame 0) ──
	title_node          = Sprite2D.new()
	title_node.texture  = tex
	title_node.region_enabled = true
	title_node.region_rect    = Rect2(0, 0, FRAME_W, FRAME_H)
	title_node.scale          = Vector2(T_SCALE, T_SCALE)
	title_node.position       = Vector2(cx, start_y + title_content_h * 0.5)
	add_child(title_node)

	# ── Buttons (frames 1, 2, 3) ──
	var btn_y: float = start_y + title_content_h + TITLE_BTN_GAP
	btn_rects.clear()
	btn_nodes.clear()

	for i in range(3):
		var sp              = Sprite2D.new()
		sp.texture          = tex
		sp.region_enabled   = true
		sp.region_rect      = Rect2((i + 1) * FRAME_W, 0, FRAME_W, FRAME_H)
		sp.scale            = Vector2(B_SCALE, B_SCALE)
		var sy: float       = btn_y + BTN_STRIDE * 0.5 + i * BTN_STRIDE
		sp.position         = Vector2(cx, sy)
		add_child(sp)
		btn_nodes.append(sp)

		# Clickable rect — use a tight hit area, not the full frame height
		btn_rects.append(Rect2(
			cx - BW * 0.5,
			sy - BTN_STRIDE * 0.5,
			BW,
			BTN_STRIDE
		))

	_refresh_hover()

# ── Fallback text buttons if sheet fails to load ──
func _build_fallback_menu() -> void:
	var items = ["START FIGHTING", "OPTIONS", "EXIT"]
	var cx    = VIEWPORT_W * 0.5
	var start_y = 320.0
	for i in range(3):
		var lbl      = Label.new()
		lbl.text     = items[i]
		lbl.position = Vector2(cx - 200, start_y + i * 70)
		lbl.size     = Vector2(400, 60)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 32)
		lbl.add_theme_color_override("font_color", Color(1, 0.6, 0.1))
		add_child(lbl)
		btn_nodes.append(lbl)
		btn_rects.append(Rect2(cx - 200, start_y + i * 70, 400, 60))

func _build_winner_label() -> void:
	winner_lbl          = Label.new()
	winner_lbl.size     = Vector2(800, 50)
	winner_lbl.position = Vector2((VIEWPORT_W - 800) * 0.5, 60)
	winner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_lbl.add_theme_font_size_override("font_size", 30)
	winner_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.1))
	winner_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	winner_lbl.add_theme_constant_override("shadow_offset_x", 3)
	winner_lbl.add_theme_constant_override("shadow_offset_y", 3)
	add_child(winner_lbl)

	if GameData.winner != 0:
		var wname = GameData.get_char(
			GameData.player1_char if GameData.winner == 1 else GameData.player2_char
		)["display_name"]
		winner_lbl.text = "🏆  " + wname + "  IS THE WINNER!  🏆"
		GameData.winner = 0
	else:
		winner_lbl.visible = false

func _build_controls_hint() -> void:
	var lbl          = Label.new()
	lbl.text         = "Controller: D-pad/Stick Move  ✕ Jump  □ Punch  ○ Kick  R1 Special  L1 Block"
	lbl.size         = Vector2(VIEWPORT_W - 20, 22)
	lbl.position     = Vector2(10, VIEWPORT_H - 44)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0, 0.9))
	add_child(lbl)

	var lbl2         = Label.new()
	lbl2.text        = "Keyboard — P1: A/D W F G H V     |     P2: Arrows Num1 Num2 Num3 Num0"
	lbl2.size        = Vector2(VIEWPORT_W - 20, 22)
	lbl2.position    = Vector2(10, VIEWPORT_H - 22)
	lbl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl2.add_theme_font_size_override("font_size", 12)
	lbl2.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 0.8))
	add_child(lbl2)

# ─────────────────────────────────
#  UPDATE LOOP
# ─────────────────────────────────
func _process(delta: float) -> void:
	_scroll_background(delta)
	_handle_hover()
	_handle_keyboard()

func _scroll_background(delta: float) -> void:
	bg_offset -= SCROLL_SPEED * delta

	# Reset when first copy has fully scrolled off screen
	if bg_offset <= -BG_SCALED_W:
		bg_offset += BG_SCALED_W

	for i in range(bg_sprites.size()):
		var sp: Sprite2D = bg_sprites[i]
		sp.position.x = bg_offset + BG_SCALED_W * i + BG_SCALED_W * 0.5

# ─────────────────────────────────
#  HOVER & INPUT
# ─────────────────────────────────
func _handle_hover() -> void:
	if btn_rects.is_empty(): return
	var mp = get_viewport().get_mouse_position()
	var new_hover = btn_hovered
	for i in range(btn_rects.size()):
		if btn_rects[i].has_point(mp):
			new_hover = i
			break
	if new_hover != btn_hovered:
		btn_hovered = new_hover
		_refresh_hover()

func _handle_keyboard() -> void:
	if Input.is_action_just_pressed("ui_down"):
		btn_hovered = (btn_hovered + 1) % 3
		_refresh_hover()
	if Input.is_action_just_pressed("ui_up"):
		btn_hovered = (btn_hovered - 1 + 3) % 3
		_refresh_hover()
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("p1_punch"):
		_activate(btn_hovered)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mp = get_viewport().get_mouse_position()
			for i in range(btn_rects.size()):
				if btn_rects[i].has_point(mp):
					_activate(i)
					return

# ── Highlight hovered button, dim others ──
func _refresh_hover() -> void:
	for i in range(btn_nodes.size()):
		var node = btn_nodes[i]
		if node is Sprite2D:
			if i == btn_hovered:
				node.modulate = Color(1.35, 1.35, 0.6, 1.0)   # bright yellow tint
				node.scale    = Vector2(B_SCALE * 1.08, B_SCALE * 1.08)
			else:
				node.modulate = Color(0.75, 0.75, 0.75, 1.0)  # dimmed
				node.scale    = Vector2(B_SCALE, B_SCALE)

func _activate(idx: int) -> void:
	match idx:
		0: get_tree().change_scene_to_file("res://scenes/CharSelect.tscn")
		1: _toggle_fullscreen()
		2: get_tree().quit()

func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
