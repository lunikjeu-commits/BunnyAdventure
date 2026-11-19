extends CharacterBody2D
# Ennemi générique piloté par des données : chien, renard, oiseau.
# IA : patrouille -> détection -> poursuite/attaque -> retour au poste.

signal killed(enemy)

const Art = preload("res://scripts/art.gd")
const GS = preload("res://scripts/game_state.gd")
const GRAVITY := 1900.0
const MAX_FALL := 1500.0

const KINDS := {
	"dog": {"hp": 30.0, "dmg": 10.0, "speed": 110.0, "chase": 200.0, "detect": 340.0,
		"xp": 10, "coins": 3, "w": 70.0, "h": 50.0, "fly": false, "lvx": 440.0, "lvy": -120.0, "dodge": false},
	"fox": {"hp": 50.0, "dmg": 14.0, "speed": 150.0, "chase": 270.0, "detect": 400.0,
		"xp": 18, "coins": 5, "w": 74.0, "h": 50.0, "fly": false, "lvx": 500.0, "lvy": -340.0, "dodge": true},
	"bird": {"hp": 20.0, "dmg": 8.0, "speed": 130.0, "chase": 210.0, "detect": 420.0,
		"xp": 12, "coins": 4, "w": 52.0, "h": 44.0, "fly": true, "lvx": 0.0, "lvy": 0.0, "dodge": false},
}

enum State { PATROL, CHASE, RETURN }

var kind := "dog"
var data: Dictionary = {}
var hp := 30.0
var max_hp := 30.0
var damage := 10.0
var speed := 110.0
var chase_speed := 200.0
var detect := 340.0
var fly := false
var w := 58.0
var h := 44.0
var xp_reward := 10
var coin_reward := 3
var home := Vector2.ZERO
var patrol_range := 150.0
var state := State.PATROL
var facing := 1.0

var _t := 0.0
var _pdir := 1.0
var _cd := 0.0
var _dodge_cd := 0.0
var _lunge_t := 0.0
var _chase_t := 0.0
var _hit_t := 0.0
var _burn_t := 0.0
var _burn_tick := 0.0
var _slow_t := 0.0
var _freeze_t := 0.0
var _stun_t := 0.0
var _dead := false

func setup(k: String, pos: Vector2, rng: float, hp_mult: float = 1.0) -> void:
	kind = k
	data = KINDS[k]
	max_hp = float(data["hp"]) * hp_mult
	hp = max_hp
	damage = float(data["dmg"])
	speed = float(data["speed"])
	chase_speed = float(data["chase"])
	detect = float(data["detect"])
	fly = bool(data["fly"])
	w = float(data["w"])
	h = float(data["h"])
	xp_reward = int(data["xp"])
	coin_reward = int(data["coins"])
	position = pos
	home = pos
	patrol_range = rng

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	collision_layer = 2
	collision_mask = 1
	add_to_group("enemies")
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(w, h)
	cs.shape = r
	cs.position = Vector2(0, -h * 0.5)
	add_child(cs)

func rect() -> Rect2:
	return Rect2(global_position + Vector2(-w * 0.5, -h), Vector2(w, h))

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	_hit_t = maxf(_hit_t - delta, 0.0)
	_cd = maxf(_cd - delta, 0.0)
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_lunge_t = maxf(_lunge_t - delta, 0.0)
	_tick_status(delta)
	if _dead:
		return
	var pl = get_tree().get_first_node_in_group("player")
	var alive := false
	if pl != null and pl.hp > 0.0:
		alive = true
	var frozen := _freeze_t > 0.0 or _stun_t > 0.0
	if fly:
		_move_fly(delta, pl, alive, frozen)
	else:
		_move_ground(delta, pl, alive, frozen)
	move_and_slide()
	if global_position.y > 1300.0:
		queue_free()
		return
	if alive:
		_contact(pl, frozen)
	_update_tint()
	queue_redraw()

func _tick_status(delta: float) -> void:
	_freeze_t = maxf(_freeze_t - delta, 0.0)
	_stun_t = maxf(_stun_t - delta, 0.0)
	_slow_t = maxf(_slow_t - delta, 0.0)
	if _burn_t > 0.0:
		_burn_t -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			_hurt_raw(3.0, Color(1.0, 0.5, 0.1))

func _update_tint() -> void:
	if _hit_t > 0.0:
		modulate = Color(1.7, 1.7, 1.7)
	elif _freeze_t > 0.0:
		modulate = Color(0.6, 0.85, 1.25)
	elif _stun_t > 0.0:
		modulate = Color(1.3, 1.3, 0.6)
	elif _burn_t > 0.0:
		modulate = Color(1.3, 0.8, 0.7)
	else:
		modulate = Color(1, 1, 1)

func _ledge(dir: float) -> bool:
	var from := Transform2D(0.0, global_position + Vector2(dir * (w * 0.5 + 6.0), 0.0))
	return not test_move(from, Vector2(0.0, 28.0))

func _lunge(dir: float) -> void:
	_cd = 2.2
	_lunge_t = 0.45
	velocity.x = dir * float(data["lvx"])
	velocity.y = float(data["lvy"])

func _move_ground(delta: float, pl, alive: bool, frozen: bool) -> void:
	var dx := 0.0
	var dy := 0.0
	var dist := 9999.0
	if pl != null:
		dx = pl.global_position.x - global_position.x
		dy = pl.global_position.y - global_position.y
		dist = absf(dx)
	var mult := 1.0
	if _slow_t > 0.0:
		mult = 0.5
	match state:
		State.PATROL:
			if alive and dist < detect and absf(dy) < 200.0:
				state = State.CHASE
		State.CHASE:
			if (not alive) or dist > detect * 1.7 or absf(global_position.x - home.x) > patrol_range + 450.0:
				state = State.RETURN
		State.RETURN:
			if absf(global_position.x - home.x) < 14.0:
				state = State.PATROL
			elif alive and dist < detect * 0.7 and absf(dy) < 200.0:
				state = State.CHASE
	var want := 0.0
	if not frozen:
		match state:
			State.PATROL:
				if global_position.x > home.x + patrol_range:
					_pdir = -1.0
				elif global_position.x < home.x - patrol_range:
					_pdir = 1.0
				want = _pdir * speed * 0.6 * mult
			State.CHASE:
				want = signf(dx) * chase_speed * mult
				if _cd <= 0.0 and is_on_floor() and dist < 200.0 and dist > 70.0:
					_lunge(signf(dx))
				if bool(data["dodge"]) and _dodge_cd <= 0.0 and is_on_floor():
					for c in get_tree().get_nodes_in_group("carrots"):
						if absf(c.global_position.x - global_position.x) < 150.0 and absf(c.global_position.y - (global_position.y - h * 0.5)) < 40.0:
							velocity.y = -480.0
							_dodge_cd = 1.2
							break
			State.RETURN:
				want = signf(home.x - global_position.x) * speed * mult
	if want != 0.0 and is_on_floor() and _lunge_t <= 0.0 and _ledge(signf(want)):
		want = 0.0
		if state == State.PATROL:
			_pdir = -_pdir
	if _lunge_t <= 0.0:
		velocity.x = move_toward(velocity.x, want, 2400.0 * delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	if state == State.CHASE and alive and not frozen and dx != 0.0:
		facing = signf(dx)
	elif absf(velocity.x) > 15.0:
		facing = signf(velocity.x)

func _move_fly(delta: float, pl, alive: bool, frozen: bool) -> void:
	var dx := 0.0
	var dist := 9999.0
	if pl != null:
		dx = pl.global_position.x - global_position.x
		dist = global_position.distance_to(pl.global_position)
	var target := home
	var sp := speed
	var slow := 1.0
	if _slow_t > 0.0:
		slow = 0.5
	match state:
		State.PATROL:
			target = home + Vector2(sin(_t * 1.1) * patrol_range, sin(_t * 2.3) * 14.0)
			sp = speed * 0.6 * slow
			if alive and _cd <= 0.0 and absf(dx) < detect and dist < detect * 1.2:
				state = State.CHASE
				_chase_t = 0.0
		State.CHASE:
			_chase_t += delta
			if pl != null:
				target = pl.global_position + Vector2(0.0, -26.0)
			sp = chase_speed * slow
			if (not alive) or dist < 24.0 or _chase_t > 1.6:
				state = State.RETURN
				_cd = 2.2
		State.RETURN:
			target = home
			sp = speed * slow
			if global_position.distance_to(home) < 16.0:
				state = State.PATROL
	if frozen:
		velocity = velocity.move_toward(Vector2(0.0, 300.0), 900.0 * delta)
	else:
		var dir_v := target - global_position
		var want := Vector2.ZERO
		if dir_v.length() > 4.0:
			want = dir_v.normalized() * sp
		velocity = velocity.move_toward(want, 800.0 * delta)
	if state == State.CHASE and alive and not frozen and dx != 0.0:
		facing = signf(dx)
	elif absf(velocity.x) > 15.0:
		facing = signf(velocity.x)

func _contact(pl, frozen: bool) -> void:
	if _dead:
		return
	if not rect().intersects(pl.rect()):
		return
	var stomp: bool = pl.velocity.y > 60.0 and pl.global_position.y < global_position.y - h * 0.45
	if stomp:
		take_hit(pl.stomp_damage(), "", 0.0)
		if not _dead:
			_stun_t = maxf(_stun_t, 0.5)
		pl.bounce()
	elif not frozen:
		pl.hurt(damage, global_position.x)

func take_hit(dmg: float, el: String, dir: float) -> void:
	if _dead:
		return
	_hit_t = 0.12
	var col := Color.WHITE
	if el != "":
		col = GS.element_color(el)
	_hurt_raw(dmg, col)
	if _dead:
		return
	if fly:
		velocity += Vector2(dir * 200.0, -60.0)
	else:
		velocity.x = dir * 220.0
		velocity.y = minf(velocity.y, -140.0)
		_lunge_t = 0.0
	match el:
		"fire":
			_burn_t = 3.0
		"ice":
			_slow_t = 3.0
			if randf() < 0.25:
				_freeze_t = 1.2
		"electric":
			if randf() < 0.4:
				_stun_t = 1.0
				_lunge_t = 0.0
	var pl = get_tree().get_first_node_in_group("player")
	if pl != null:
		pl.on_hit_dealt()

func _hurt_raw(amount: float, col: Color) -> void:
	hp -= amount
	_pop(str(int(round(amount))), col)
	if hp <= 0.0:
		_die()

func _die() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("enemies")
	killed.emit(self)
	queue_free()

func _pop(text: String, col: Color) -> void:
	var par := get_parent()
	if par == null:
		return
	var l := Label.new()
	l.text = text
	l.position = global_position + Vector2(-10.0, -h - 34.0)
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.z_index = 20
	par.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 44.0, 0.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)

const SPR := {
	"dog": {"cols": 5, "cx": 180.0, "cy": 246.0, "cw": 360.0, "ch": 260.0},
	"fox": {"cols": 5, "cx": 190.0, "cy": 246.0, "cw": 380.0, "ch": 260.0},
	"bird": {"cols": 4, "cx": 150.0, "cy": 200.0, "cw": 300.0, "ch": 240.0},
}

func _draw() -> void:
	var d: Dictionary = SPR[kind]
	var u := 0.25
	var fr := 0
	if fly:
		fr = int(_t * 14.0) % 4
	elif _lunge_t > 0.0:
		fr = 4
	elif absf(velocity.x) > 15.0:
		fr = int(_t * 9.0) % 4
	if not fly:
		Art.shadow(self, Vector2(0.0, 2.0), w * 0.75, 7.0, 0.28)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0))
	var dest := Rect2(Vector2(-float(d["cx"]) * u, -float(d["cy"]) * u), Vector2(float(d["cw"]) * u, float(d["ch"]) * u))
	Art.frame(self, kind, fr, int(d["cols"]), 1, dest)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hp < max_hp:
		var bw := 46.0
		draw_rect(Rect2(-bw * 0.5, -h - 14.0, bw, 6.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-bw * 0.5, -h - 14.0, bw * clampf(hp / max_hp, 0.0, 1.0), 6.0), Color(0.9, 0.25, 0.25))
