extends Node2D
# Projectile carotte (sera relié aux éléments feu / glace / électrique à l'étape 2).

var vel := Vector2.ZERO
var grav := 0.0
var life := 3.0

func setup(p: Vector2, v: Vector2, g: float = 0.0) -> void:
	position = p
	vel = v
	grav = g

func _process(d: float) -> void:
	vel.y += grav * d
	position += vel * d
	rotation = vel.angle()
	life -= d
	if life <= 0.0 or position.y > 1200.0:
		queue_free()

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -8), Vector2(20, 0), Vector2(-14, 8)]), Color(1.0, 0.55, 0.1))
	draw_line(Vector2(-6, -4), Vector2(-2, -1), Color(0.85, 0.4, 0.05), 2.0)
	draw_line(Vector2(4, 2), Vector2(8, 0), Color(0.85, 0.4, 0.05), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, 0), Vector2(-28, -9), Vector2(-22, 0)]), Color(0.3, 0.75, 0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(-14, 0), Vector2(-28, 9), Vector2(-22, 0)]), Color(0.25, 0.65, 0.2))
