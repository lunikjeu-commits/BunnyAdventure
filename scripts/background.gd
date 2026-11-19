extends Node2D
# Ciel, nuages et deux plans de collines en parallaxe (images générées).

const Art = preload("res://scripts/art.gd")
var cam: Camera2D = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var sz := get_viewport_rect().size
	var sky := Art.tex("bg_sky")
	if sky != null:
		draw_texture_rect(sky, Rect2(Vector2.ZERO, sz), false)
	var cx := 0.0
	if cam != null:
		cx = cam.get_screen_center_position().x
	_layer("bg_far", sz, cx * 0.12, sz.y * 0.22, Color(0.56, 0.72, 0.70))
	_layer("bg_mid", sz, cx * 0.30, sz.y * 0.31, Color(0.25, 0.60, 0.29))

func _layer(name: String, sz: Vector2, off: float, y: float, fill: Color) -> void:
	var t := Art.tex(name)
	if t == null:
		return
	var w := float(t.get_width())
	var h := float(t.get_height())
	var x := -fposmod(off, w)
	while x < sz.x:
		draw_texture_rect(t, Rect2(x, y, w + 1.0, h), false)
		x += w
	draw_rect(Rect2(0.0, y + h - 1.0, sz.x, sz.y), fill)
