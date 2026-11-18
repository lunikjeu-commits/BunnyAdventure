extends Node2D
# Ciel, soleil, nuages et collines en parallaxe (dessinés, sans image).

const Gfx = preload("res://scripts/gfx.gd")
var cam: Camera2D = null

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var sz := get_viewport_rect().size
	var top := Color(0.40, 0.72, 0.98)
	var bot := Color(0.86, 0.96, 1.0)
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(sz.x, 0), Vector2(sz.x, sz.y), Vector2(0, sz.y)]),
		PackedColorArray([top, top, bot, bot]))
	draw_circle(Vector2(sz.x * 0.82, 110), 70, Color(1, 0.96, 0.7, 0.35))
	draw_circle(Vector2(sz.x * 0.82, 110), 46, Color(1, 0.95, 0.55))
	var cx := 0.0
	if cam != null:
		cx = cam.get_screen_center_position().x
	for i in 6:
		var x := fposmod(float(i) * 380.0 - cx * 0.1, sz.x + 400.0) - 200.0
		var y := 90.0 + float(i % 3) * 50.0
		Gfx.ell(self, Vector2(x, y), 70, 24, Color(1, 1, 1, 0.9))
		Gfx.ell(self, Vector2(x - 40, y + 8), 40, 18, Color(1, 1, 1, 0.9))
		Gfx.ell(self, Vector2(x + 42, y + 8), 44, 18, Color(1, 1, 1, 0.9))
	_hills(sz, cx * 0.2, 0.60, Color(0.58, 0.82, 0.50), 80.0, 0.004)
	_hills(sz, cx * 0.45, 0.70, Color(0.42, 0.72, 0.36), 60.0, 0.006)

func _hills(sz: Vector2, off: float, base: float, col: Color, amp: float, freq: float) -> void:
	var pts := PackedVector2Array()
	var x := 0.0
	while x <= sz.x + 20.0:
		pts.append(Vector2(x, sz.y * base + sin((x + off) * freq) * amp))
		x += 20.0
	pts.append(Vector2(sz.x + 20.0, sz.y))
	pts.append(Vector2(0, sz.y))
	draw_colored_polygon(pts, col)
