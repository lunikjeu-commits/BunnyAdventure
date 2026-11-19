extends RefCounted
# Dessin du lapin : images animées (3 stades) + aura élémentaire.

const Gfx = preload("res://scripts/gfx.gd")
const GS = preload("res://scripts/game_state.gd")
const Art = preload("res://scripts/art.gd")
const SCALES := [0.85, 1.05, 1.3]
const KS := [0.32, 0.40, 0.50]

static func scale_for(stage: int) -> float:
	return float(SCALES[clampi(stage - 1, 0, 2)])

static func draw(ci: CanvasItem, origin: Vector2, facing: float, stage: int, t: float, bob: float, air: float, attack_t: float, element: String, zoom: float = 1.0, pose: String = "idle") -> void:
	var k := float(KS[clampi(stage - 1, 0, 2)]) * zoom
	var s := scale_for(stage) * zoom
	Art.shadow(ci, origin + Vector2(0.0, 2.0 * zoom), 46.0 * s, 9.0 * s, 0.28)
	if element != "":
		var c := GS.element_color(element)
		ci.draw_set_transform(origin, 0.0, Vector2(facing * s, s))
		Gfx.ell(ci, Vector2(0, -44), 48, 62, Color(c.r, c.g, c.b, 0.14))
		Gfx.ell(ci, Vector2(0, -44), 34, 48, Color(c.r, c.g, c.b, 0.12))
	var fr := 0
	match pose:
		"run":
			fr = 2 + int(t * 12.0) % 4
		"jump":
			fr = 6
		"fall":
			fr = 7
		"attack":
			fr = 8
		"hurt":
			fr = 9
		_:
			fr = int(t * 2.2) % 2
	ci.draw_set_transform(origin, 0.0, Vector2(facing, 1.0))
	Art.frame(ci, "rabbit%d" % stage, fr, 5, 2, Rect2(Vector2(-150.0 * k, -300.0 * k), Vector2(320.0 * k, 320.0 * k)))
	if element != "" or attack_t > 0.0:
		ci.draw_set_transform(origin, 0.0, Vector2(facing * s, s))
		match element:
			"fire":
				_fire(ci, t)
			"ice":
				_ice(ci, t)
			"electric":
				_elec(ci, t)
		if attack_t > 0.0:
			var a := 1.0 - attack_t / 0.25
			ci.draw_arc(Vector2(52, -46), 36.0, -1.2 + a, 1.2 * a, 14, Color(1, 1, 1, 0.85), 6.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _fire(ci: CanvasItem, t: float) -> void:
	for i in 6:
		var x := -30.0 + float(i) * 12.0
		var h := 26.0 + sin(t * 11.0 + float(i) * 1.7) * 9.0
		var base := -8.0 - float(i % 2) * 6.0
		var tip := x + sin(t * 9.0 + float(i)) * 3.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 7, base), Vector2(tip, base - h), Vector2(x + 7, base)]), Color(1.0, 0.45, 0.1, 0.7))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 4, base), Vector2(tip, base - h * 0.6), Vector2(x + 4, base)]), Color(1.0, 0.85, 0.25, 0.8))

static func _ice(ci: CanvasItem, t: float) -> void:
	for i in 5:
		var a := t * 1.4 + float(i) * TAU / 5.0
		var p := Vector2(cos(a) * 42.0, -46.0 + sin(a) * 54.0)
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -9), p + Vector2(5, 0), p + Vector2(0, 9), p + Vector2(-5, 0)]), Color(0.75, 0.95, 1.0, 0.9))

static func _elec(ci: CanvasItem, t: float) -> void:
	var xs := [-38.0, 38.0, -28.0]
	for k in 3:
		var pts := PackedVector2Array()
		var ph := floorf(t * 14.0) + float(k) * 7.0
		var bx: float = xs[k]
		for j in 6:
			var y := -4.0 - float(j) * 15.0
			pts.append(Vector2(bx + sin(ph * 12.9898 + float(j) * 78.233) * 7.0, y))
		ci.draw_polyline(pts, Color(1.0, 0.95, 0.4, 0.9), 3.0)
