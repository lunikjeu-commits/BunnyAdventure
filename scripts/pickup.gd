extends Node2D
# Objets à ramasser : pièces et légumes (carotte, tomate, laitue).

const Art = preload("res://scripts/art.gd")

signal collected(kind)

var kind := "coin"
var _t := 0.0
var _taken := false

func setup(k: String, p: Vector2) -> void:
	kind = k
	position = p
	_t = randf() * 6.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _physics_process(d: float) -> void:
	_t += d
	queue_redraw()
	if _taken:
		return
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null:
		return
	if Rect2(global_position - Vector2(20, 20), Vector2(40, 40)).intersects(pl.rect()):
		_taken = true
		collected.emit(kind)
		queue_free()

func _draw() -> void:
	var y := sin(_t * 3.0) * 4.0
	var g := Art.tex("glow")
	if g != null:
		draw_texture_rect(g, Rect2(-34, y - 34, 68, 68), false, Color(1.0, 0.95, 0.6, 0.35))
	var t := Art.tex(kind)
	if t == null:
		return
	var sx := 1.0
	if kind == "coin":
		sx = maxf(absf(cos(_t * 3.0)), 0.18)
	draw_set_transform(Vector2(0.0, y), 0.0, Vector2(sx, 1.0))
	draw_texture_rect(t, Rect2(-24, -24, 48, 48), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
