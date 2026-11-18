extends StaticBody2D
# Plateforme / sol herbeux avec collision rectangulaire.

var size := Vector2(400, 40)

func setup(p: Vector2, s: Vector2) -> void:
	position = p
	size = s
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = s
	cs.shape = r
	cs.position = s / 2.0
	add_child(cs)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.45, 0.30, 0.18))
	if size.y > 60.0:
		draw_rect(Rect2(0, 16, size.x, 26), Color(0.40, 0.26, 0.15))
	var gh := minf(16.0, size.y)
	draw_rect(Rect2(0, 0, size.x, gh), Color(0.36, 0.72, 0.28))
	draw_rect(Rect2(0, gh - 4.0, size.x, 4.0), Color(0.28, 0.58, 0.22))
	var x := 12.0
	while x < size.x:
		draw_line(Vector2(x, 1), Vector2(x + 3, -6), Color(0.36, 0.72, 0.28), 3.0)
		x += 28.0
