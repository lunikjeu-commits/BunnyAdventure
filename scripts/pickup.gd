extends Node2D
# Objets à ramasser : pièces et légumes (carotte, tomate, laitue).

const Gfx = preload("res://scripts/gfx.gd")

signal collected(kind)

var kind := "coin"
var _t := 0.0
var _taken := false

func setup(k: String, p: Vector2) -> void:
	kind = k
	position = p
	_t = randf() * 6.0

func _physics_process(d: float) -> void:
	_t += d
	queue_redraw()
	if _taken:
		return
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null:
		return
	if Rect2(global_position - Vector2(18, 18), Vector2(36, 36)).intersects(pl.rect()):
		_taken = true
		collected.emit(kind)
		queue_free()

func _draw() -> void:
	var y := sin(_t * 3.0) * 4.0
	match kind:
		"coin":
			var rx := 4.0 + 8.0 * absf(cos(_t * 3.0))
			Gfx.ell_o(self, Vector2(0, y), rx, 12.0, Color(1.0, 0.82, 0.2), Color(0.7, 0.5, 0.1), 2.0)
			Gfx.ell(self, Vector2(0, y), rx * 0.45, 7.0, Color(1.0, 0.93, 0.55))
		"carrot":
			draw_colored_polygon(PackedVector2Array([Vector2(-9, y - 10), Vector2(9, y - 10), Vector2(0, y + 18)]), Color(1.0, 0.55, 0.1))
			draw_colored_polygon(PackedVector2Array([Vector2(0, y - 10), Vector2(-10, y - 24), Vector2(-3, y - 10)]), Color(0.3, 0.75, 0.25))
			draw_colored_polygon(PackedVector2Array([Vector2(0, y - 10), Vector2(10, y - 24), Vector2(3, y - 10)]), Color(0.25, 0.65, 0.2))
		"tomato":
			Gfx.ell_o(self, Vector2(0, y), 13, 12, Color(0.9, 0.2, 0.2), Color(0.5, 0.1, 0.1), 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-8, y - 10), Vector2(0, y - 6), Vector2(8, y - 10), Vector2(0, y - 16)]), Color(0.3, 0.7, 0.25))
		"lettuce":
			Gfx.ell_o(self, Vector2(0, y), 14, 12, Color(0.45, 0.78, 0.3), Color(0.2, 0.5, 0.15), 2.0)
			Gfx.ell(self, Vector2(-3, y - 2), 9, 8, Color(0.62, 0.88, 0.42))
			Gfx.ell(self, Vector2(3, y - 3), 5, 5, Color(0.78, 0.94, 0.55))
