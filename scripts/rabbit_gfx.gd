extends RefCounted
# Dessin du lapin (3 stades, 3 éléments) partagé par le jeu et les menus.

const Gfx = preload("res://scripts/gfx.gd")
const GS = preload("res://scripts/game_state.gd")
const SCALES := [0.85, 1.05, 1.3]

static func scale_for(stage: int) -> float:
	return float(SCALES[clampi(stage - 1, 0, 2)])

static func draw(ci: CanvasItem, origin: Vector2, facing: float, stage: int, t: float, bob: float, air: float, attack_t: float, element: String, zoom: float = 1.0) -> void:
	var s := scale_for(stage) * zoom
	ci.draw_set_transform(origin, 0.0, Vector2(facing * s, s))
	var fur := Color(0.99, 0.96, 0.91)
	var line := Color(0.55, 0.47, 0.42)
	var pink := Color(1.0, 0.70, 0.78)
	var ear_tilt := -air * 0.35

	if element != "":
		var c := GS.element_color(element)
		Gfx.ell(ci, Vector2(0, -40), 42, 56, Color(c.r, c.g, c.b, 0.16))
		Gfx.ell(ci, Vector2(0, -40), 32, 46, Color(c.r, c.g, c.b, 0.12))
		match element:
			"fire":
				_fire(ci, t)
			"ice":
				_ice(ci, t)
			"electric":
				_elec(ci, t)

	Gfx.ell_o(ci, Vector2(-26, -24 - bob), 9, 9, Color(1, 1, 1), line)
	Gfx.ell_o(ci, Vector2(-10, -4), 13, 7, fur, line)
	Gfx.ell_o(ci, Vector2(14, -4), 13, 7, fur, line)
	Gfx.ell_o(ci, Vector2(-2, -76 - bob), 8, 21, fur, line, 2.5, -0.15 + ear_tilt)
	Gfx.ell(ci, Vector2(-2, -75 - bob), 4, 15, pink, -0.15 + ear_tilt)
	Gfx.ell_o(ci, Vector2(14, -78 - bob), 8, 21, fur, line, 2.5, 0.12 + ear_tilt)
	Gfx.ell(ci, Vector2(14, -77 - bob), 4, 15, pink, 0.12 + ear_tilt)
	Gfx.ell_o(ci, Vector2(0, -26 - bob), 24, 22, fur, line)
	Gfx.ell_o(ci, Vector2(8, -50 - bob), 21, 19, fur, line)
	if stage >= 2:
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(0, -38 - bob), Vector2(20, -36 - bob),
			Vector2(14, -27 - bob), Vector2(2, -29 - bob)]), Color(0.85, 0.2, 0.2))
	if stage >= 3:
		ci.draw_line(Vector2(-6, -61 - bob), Vector2(22, -62 - bob), Color(1.0, 0.8, 0.2), 5.0)
	ci.draw_circle(Vector2(18, -50 - bob), 4.5, Color(0.12, 0.1, 0.12))
	ci.draw_circle(Vector2(19.5, -51.5 - bob), 1.6, Color(1, 1, 1))
	ci.draw_circle(Vector2(19, -41 - bob), 5.0, Color(1.0, 0.65, 0.72, 0.65))
	Gfx.ell(ci, Vector2(27, -45 - bob), 3.5, 2.8, Color(1.0, 0.45, 0.6))
	if attack_t > 0.0:
		var k := 1.0 - attack_t / 0.25
		ci.draw_arc(Vector2(30, -30 - bob), 30.0, -1.3 + k, 1.3 * k, 14, Color(1, 1, 1, 0.9), 6.0)
		Gfx.ell_o(ci, Vector2(34.0 + 10.0 * k, -28 - bob), 9, 7, fur, line)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _fire(ci: CanvasItem, t: float) -> void:
	for i in 6:
		var x := -30.0 + float(i) * 12.0
		var h := 26.0 + sin(t * 11.0 + float(i) * 1.7) * 9.0
		var base := -8.0 - float(i % 2) * 6.0
		var tip := x + sin(t * 9.0 + float(i)) * 3.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 7, base), Vector2(tip, base - h), Vector2(x + 7, base)]), Color(1.0, 0.45, 0.1, 0.75))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 4, base), Vector2(tip, base - h * 0.6), Vector2(x + 4, base)]), Color(1.0, 0.85, 0.25, 0.85))

static func _ice(ci: CanvasItem, t: float) -> void:
	for i in 5:
		var a := t * 1.4 + float(i) * TAU / 5.0
		var p := Vector2(cos(a) * 40.0, -42.0 + sin(a) * 52.0)
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -9), p + Vector2(5, 0), p + Vector2(0, 9), p + Vector2(-5, 0)]), Color(0.75, 0.95, 1.0, 0.9))

static func _elec(ci: CanvasItem, t: float) -> void:
	var xs := [-36.0, 36.0, -26.0]
	for k in 3:
		var pts := PackedVector2Array()
		var ph := floorf(t * 14.0) + float(k) * 7.0
		var bx: float = xs[k]
		for j in 6:
			var y := -4.0 - float(j) * 15.0
			pts.append(Vector2(bx + sin(ph * 12.9898 + float(j) * 78.233) * 7.0, y))
		ci.draw_polyline(pts, Color(1.0, 0.95, 0.4, 0.9), 3.0)
