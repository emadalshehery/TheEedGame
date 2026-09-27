extends Node2D

@onready var press_lbl: Label = $CanvasLayer/PressLabel
@onready var title_lbl: Label = $CanvasLayer/TitleLabel
@onready var sub_lbl:   Label = $CanvasLayer/SubLabel

var blink_timer: float = 0.0
var blink_on:    bool  = true
var ready_input: bool  = false

func _ready() -> void:
	title_lbl.modulate = Color(1, 1, 1, 0)
	sub_lbl.modulate   = Color(1, 1, 1, 0)
	press_lbl.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(title_lbl, "modulate", Color.WHITE, 1.2)
	tw.tween_property(sub_lbl,   "modulate", Color.WHITE, 0.8)
	tw.tween_property(press_lbl, "modulate", Color.WHITE, 0.6)
	tw.tween_callback(func(): ready_input = true)

func _process(delta: float) -> void:
	blink_timer += delta
	if blink_timer >= 0.55:
		blink_timer = 0.0
		blink_on = not blink_on
		press_lbl.modulate.a = 1.0 if blink_on else 0.25

	if not ready_input:
		return

	if Input.is_action_just_pressed("ui_accept") \
	or Input.is_joy_button_pressed(0, JOY_BUTTON_START) \
	or Input.is_joy_button_pressed(1, JOY_BUTTON_START) \
	or Input.is_joy_button_pressed(0, JOY_BUTTON_A) \
	or Input.is_joy_button_pressed(1, JOY_BUTTON_A):
		_go_to_game()

func _go_to_game() -> void:
	ready_input = false
	var tw := create_tween()
	tw.tween_property($CanvasLayer, "modulate", Color(0, 0, 0, 1), 0.5)
	tw.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
