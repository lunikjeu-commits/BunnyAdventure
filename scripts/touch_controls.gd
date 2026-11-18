extends Control
# Commandes tactiles : joystick à gauche, 4 boutons à droite, multi-touch.

const STICK_RADIUS := 110.0
const BTN_RADIUS := 62.0

var move_x := 0.0
var ui_scale := 1.0
var opacity := 0.6

var held := {}
var _just := {}
var _stick_touch := -1
var _stick_center := Vector2.ZERO
var _stick_knob := Vector2.ZERO
var _btn_pos := {}
var _btn_touch := {}
var _labels := {"jump": "SAUT", "attack": "PATTE", "throw": "CAROTTE", "special": "SPÉCIAL"}
var _colors := {
	"jump": Color(0.35, 0.75, 1.0),
	"attack": Color(1.0, 0.75, 0.3),
	"throw": Color(1.0, 0.5, 0.15),
	"special": Color(0.85, 0.4, 1.0)}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_layout)
	_layout()

func apply_settings(s: float, o: float) -> void:
	ui_scale = s
	opacity = o
	_layout()

func consume(n: String) -> bool:
	if _just.get(n, false):
		_just[n] = false
		return true
	return false

func is_held(n: String) -> bool:
	return held.get(n, false)

func _layout() -> void:
	var sz := get_viewport_rect().size
	var s := ui_scale
	_stick_center = Vector2(180.0 * s, sz.y - 170.0 * s)
	_stick_knob = _stick_center
	_btn_pos = {
		"jump": Vector2(sz.x - 120.0 * s, sz.y - 130.0 * s),
		"attack": Vector2(sz.x - 270.0 * s, sz.y - 85.0 * s),
		"throw": Vector2(sz.x - 250.0 * s, sz.y - 215.0 * s),
		"special": Vector2(sz.x - 110.0 * s, sz.y - 275.0 * s)}
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		if event.index == _stick_touch:
			_update_stick(event.position)

func _press(idx: int, pos: Vector2) -> void:
	var half := get_viewport_rect().size.x * 0.5
	if pos.x < half:
		if _stick_touch == -1:
			_stick_touch = idx
			_update_stick(pos)
		return
	for n in _btn_pos.keys():
		if pos.distance_to(_btn_pos[n]) <= BTN_RADIUS * ui_scale * 1.3:
			_btn_touch[idx] = n
			held[n] = true
			_just[n] = true
			queue_redraw()
			return

func _release(idx: int) -> void:
	if idx == _stick_touch:
		_stick_touch = -1
		move_x = 0.0
		_stick_knob = _stick_center
	if _btn_touch.has(idx):
		held[_btn_touch[idx]] = false
		_btn_touch.erase(idx)
	queue_redraw()

func _update_stick(pos: Vector2) -> void:
	var r := STICK_RADIUS * ui_scale
	var v := pos - _stick_center
	var m := clampf(v.x / r, -1.0, 1.0)
	if absf(m) < 0.25:
		m = 0.0
	move_x = m
	_stick_knob = _stick_center + v.limit_length(r)
	queue_redraw()

func _draw() -> void:
	var r := STICK_RADIUS * ui_scale
	draw_circle(_stick_center, r, Color(1, 1, 1, 0.18 * opacity))
	draw_arc(_stick_center, r, 0.0, TAU, 40, Color(1, 1, 1, opacity), 3.0)
	draw_circle(_stick_knob, r * 0.42, Color(1, 1, 1, 0.55 * opacity + 0.2))
	var font := ThemeDB.fallback_font
	for n in _btn_pos.keys():
		var p: Vector2 = _btn_pos[n]
		var br := BTN_RADIUS * ui_scale
		var c: Color = _colors[n]
		var pressed: bool = held.get(n, false)
		if pressed:
			br *= 1.08
		draw_circle(p, br, Color(c.r, c.g, c.b, (0.75 if pressed else 0.45) * opacity + 0.1))
		draw_arc(p, br, 0.0, TAU, 32, Color(1, 1, 1, opacity), 3.0)
		draw_string(font, p + Vector2(-br, 6.0), _labels[n], HORIZONTAL_ALIGNMENT_CENTER, br * 2.0, int(17.0 * ui_scale), Color(1, 1, 1, 1))
