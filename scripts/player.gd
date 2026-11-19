extends CharacterBody2D
# Lapin joueur : déplacement, saut, combat, élément, vie, jauge spéciale.

signal died

const RabbitGfx = preload("res://scripts/rabbit_gfx.gd")
const GS = preload("res://scripts/game_state.gd")
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
var hp := 60.0
var max_hp := 60.0
var gauge := 0.0
var element := ""

var _cs: CollisionShape2D
var _shape: CapsuleShape2D
var _stage := 0
var _s := 1.0
var _coyote := 0.0
var _buffer := 0.0
var _t := 0.0
var _inv := 0.0
var _dead := false
var _attack_t := 0.0
var _attack_cd := 0.0
var _throw_cd := 0.0

func _ready() -> void:
	add_to_group("player")
	collision_layer = 4
	collision_mask = 1
	start_pos = position
	element = GS.element
	_cs = CollisionShape2D.new()
	_shape = CapsuleShape2D.new()
	_cs.shape = _shape
	add_child(_cs)
	max_hp = GS.max_hp()
	hp = max_hp
	_apply_stage()

func _apply_stage() -> void:
	var st := GS.stage()
	if st == _stage:
		return
	_stage = st
	_s = RabbitGfx.scale_for(st)
	_shape.radius = 20.0 * _s
	_shape.height = 60.0 * _s
	_cs.position = Vector2(0, -30.0 * _s)

func _refresh_stats() -> void:
	var m := GS.max_hp()
	if absf(m - max_hp) > 0.01:
		hp += maxf(m - max_hp, 0.0)
		max_hp = m
	_apply_stage()

func rect() -> Rect2:
	return Rect2(global_position + Vector2(-18.0 * _s, -60.0 * _s), Vector2(36.0 * _s, 60.0 * _s))

func stomp_damage() -> float:
	return GS.melee_damage() * 1.2

func on_hit_dealt() -> void:
	gauge = minf(gauge + 8.0, 100.0)

func heal(n: float) -> void:
	hp = minf(hp + n, max_hp)

func full_heal() -> void:
	hp = max_hp

func bounce() -> void:
	velocity.y = -480.0
	_inv = maxf(_inv, 0.35)

func hurt(dmg: float, from_x: float) -> void:
	if _inv > 0.0 or _dead:
		return
	hp -= dmg
	_inv = 1.0
	var dir := signf(global_position.x - from_x)
	if dir == 0.0:
		dir = -facing
	velocity = Vector2(dir * 320.0, -380.0)
	if hp <= 0.0:
		hp = 0.0
		_dead = true
		died.emit()

func _physics_process(delta: float) -> void:
	_t += delta
	_refresh_stats()
	if _dead:
		velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		move_and_slide()
		queue_redraw()
		return
	_inv = maxf(_inv - delta, 0.0)
	_attack_t = maxf(_attack_t - delta, 0.0)
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_throw_cd -= delta
	gauge = minf(gauge + 4.0 * delta, 100.0)

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
			_melee()
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

	if throwing and _throw_cd <= 0.0:
		_throw_cd = 0.35
		_throw()

	move_and_slide()
	if global_position.y > 1100.0:
		_fall_penalty()
	if _inv > 0.0 and int(_t * 18.0) % 2 == 0:
		modulate.a = 0.4
	else:
		modulate.a = 1.0
	queue_redraw()

func _fall_penalty() -> void:
	hp -= 15.0
	velocity = Vector2.ZERO
	position = start_pos
	_inv = 1.5
	if hp <= 0.0:
		hp = 0.0
		_dead = true
		died.emit()

func _melee() -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = 0.25
	_attack_t = 0.25
	var rx := global_position.x - 78.0
	if facing > 0.0:
		rx = global_position.x + 8.0
	var r := Rect2(Vector2(rx, global_position.y - 70.0 * _s), Vector2(70.0, 70.0 * _s))
	for e in get_tree().get_nodes_in_group("enemies"):
		if r.intersects(e.rect()):
			e.take_hit(GS.melee_damage(), "", facing)

func _throw() -> void:
	var c = CarrotScript.new()
	c.setup(global_position + Vector2(facing * 34.0, -46.0 * _s), Vector2(facing * 780.0, 0.0), 0.0, element, GS.carrot_damage(), false)
	c.life = 0.85
	get_parent().add_child(c)

func _special() -> void:
	if gauge < 100.0:
		return
	gauge = 0.0
	for i in 14:
		var c = CarrotScript.new()
		var x := global_position.x + facing * (60.0 + float(i) * 40.0) + randf_range(-15.0, 15.0)
		c.setup(Vector2(x, global_position.y - 650.0 - randf() * 220.0), Vector2(0.0, 400.0 + randf() * 150.0), 900.0, element, GS.carrot_damage() * 1.8, true)
		c.life = 2.2
		get_parent().add_child(c)

func _draw() -> void:
	var bob := 0.0
	if is_on_floor() and absf(velocity.x) > 20.0:
		bob = absf(sin(_t * 14.0)) * 4.0
	var air := clampf(velocity.y / 900.0, -1.0, 1.0)
	RabbitGfx.draw(self, Vector2.ZERO, facing, _stage, _t, bob, air, _attack_t, element)
