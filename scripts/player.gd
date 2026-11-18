extends CharacterBody2D
# Lapin joueur (étape 1 : déplacement, saut, carotte, patte, pluie de carottes).

const Gfx = preload("res://scripts/gfx.gd")
const CarrotScript = preload("res://scripts/carrot.gd")

const SPEED := 340.0
const ACCEL_GROUND := 4200.0
const ACCEL_AIR := 2600.0
const JUMP_V := -740.0
const GRAVITY := 1900.0
const MAX_FALL := 1500.0
const COYOTE := 0.1
const BUFFER := 0.12

var controls = null
var start_pos := Vector2.ZERO
var facing := 1.0
var stage := 1
var _coyote := 0.0
var _buffer := 0.0
var _t := 0.0
var _attack_t := 0.0
var _throw_cd := 0.0

func _ready() -> void:
	start_pos = position
	var cs := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 20.0
	shape.height = 60.0
	cs.shape = shape
	cs.position = Vector2(0, -30)
	add_child(cs)

func _physics_process(delta: float) -> void:
	_t += delta
	var dir := Input.get_axis("ui_left", "ui_right")
	var jump_pressed := Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")
	var jump_held := Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_up")
	var throwing := false
	if controls != null:
		if absf(controls.move_x) > 0.0:
			dir = controls.move_x
		if controls.consume("jump"):
			jump_pressed = true
		if controls.is_held("jump"):
			jump_held = true
		if controls.consume("attack"):
			_attack_t = 0.25
		if controls.consume("special"):
			_special()
		throwing = controls.is_held("throw")

	if dir != 0.0:
		facing = signf(dir)
	var accel := ACCEL_AIR
	if is_on_floor():
		accel = ACCEL_GROUND
	velocity.x = move_toward(velocity.x, dir * SPEED, accel * delta)

	var g := GRAVITY
	if velocity.y < 0.0 and not jump_held:
		g *= 2.2
	velocity.y = minf(velocity.y + g * delta, MAX_FALL)

	if is_on_floor():
		_coyote = COYOTE
	else:
		_coyote -= delta
	if jump_pressed:
		_buffer = BUFFER
	else:
		_buffer -= delta
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_V
		_buffer = 0.0
		_coyote = 0.0

	_throw_cd -= delta
	_attack_t = maxf(_attack_t - delta, 0.0)
	if throwing and _throw_cd <= 0.0:
		_throw_cd = 0.3
		_throw()

	move_and_slide()
	if global_position.y > 1100.0:
		position = start_pos
		velocity = Vector2.ZERO
	queue_redraw()

func _throw() -> void:
	var c = CarrotScript.new()
	c.setup(global_position + Vector2(facing * 30.0, -46.0), Vector2(facing * 720.0, -120.0), 700.0)
	get_parent().add_child(c)

func _special() -> void:
	for i in 14:
		var c = CarrotScript.new()
		var x := global_position.x - 330.0 + float(i) * 52.0 + facing * 160.0
		c.setup(Vector2(x, global_position.y - 620.0 - randf() * 220.0), Vector2(0, 450.0 + randf() * 150.0), 900.0)
		c.life = 2.5
		get_parent().add_child(c)

func _draw() -> void:
	var s := 0.9 + 0.1 * float(stage)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing * s, s))
	var fur := Color(0.99, 0.96, 0.91)
	var line := Color(0.55, 0.47, 0.42)
	var pink := Color(1.0, 0.70, 0.78)
	var bob := 0.0
	if is_on_floor() and absf(velocity.x) > 20.0:
		bob = absf(sin(_t * 14.0)) * 4.0
	var air := clampf(velocity.y / 900.0, -1.0, 1.0)
	var ear_tilt := -air * 0.35
	# queue
	Gfx.ell_o(self, Vector2(-26, -24 - bob), 9, 9, Color(1, 1, 1), line)
	# pieds
	Gfx.ell_o(self, Vector2(-10, -4), 13, 7, fur, line)
	Gfx.ell_o(self, Vector2(14, -4), 13, 7, fur, line)
	# oreilles
	Gfx.ell_o(self, Vector2(-2, -76 - bob), 8, 21, fur, line, 2.5, -0.15 + ear_tilt)
	Gfx.ell(self, Vector2(-2, -75 - bob), 4, 15, pink, -0.15 + ear_tilt)
	Gfx.ell_o(self, Vector2(14, -78 - bob), 8, 21, fur, line, 2.5, 0.12 + ear_tilt)
	Gfx.ell(self, Vector2(14, -77 - bob), 4, 15, pink, 0.12 + ear_tilt)
	# corps
	Gfx.ell_o(self, Vector2(0, -26 - bob), 24, 22, fur, line)
	# tête
	Gfx.ell_o(self, Vector2(8, -50 - bob), 21, 19, fur, line)
	# visage
	draw_circle(Vector2(18, -50 - bob), 4.5, Color(0.12, 0.1, 0.12))
	draw_circle(Vector2(19.5, -51.5 - bob), 1.6, Color(1, 1, 1))
	draw_circle(Vector2(19, -41 - bob), 5.0, Color(1.0, 0.65, 0.72, 0.65))
	Gfx.ell(self, Vector2(27, -45 - bob), 3.5, 2.8, Color(1.0, 0.45, 0.6))
	# patte d'attaque
	if _attack_t > 0.0:
		var k := 1.0 - _attack_t / 0.25
		draw_arc(Vector2(30, -30 - bob), 30.0, -1.3 + k, 1.3 * k, 14, Color(1, 1, 1, 0.9), 6.0)
		Gfx.ell_o(self, Vector2(34.0 + 10.0 * k, -28 - bob), 9, 7, fur, line)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
