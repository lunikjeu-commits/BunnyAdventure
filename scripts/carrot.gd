extends Node2D
# Projectile carotte : tout droit, marqué par l'élément du lapin.

const GS = preload("res://scripts/game_state.gd")

var vel := Vector2.ZERO
var grav := 0.0
var life := 0.85
var element := ""
var damage := 8.0
var pierce := false
var _hit := []

func setup(p: Vector2, v: Vector2, g: float = 0.0, el: String = "", dmg: float = 8.0, pc: bool = false) -> void:
	position = p
	vel = v
	grav = g
	element = el
	damage = dmg
	pierce = pc

func _ready() -> void:
	add_to_group("carrots")

func _physics_process(d: float) -> void:
	var old := global_position
	vel.y += grav * d
	position += vel * d
	rotation = vel.angle()
	life -= d
	if life <= 0.0 or position.y > 1300.0:
		queue_free()
		return
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(old, global_position, 1)
	if not space.intersect_ray(q).is_empty():
		queue_free()
		return
	var r := Rect2(global_position - Vector2(16, 10), Vector2(32, 20))
	for e in get_tree().get_nodes_in_group("enemies"):
		if _hit.has(e):
			continue
		if r.intersects(e.rect()):
			_hit.append(e)
			e.take_hit(damage, element, signf(vel.x))
			if not pierce:
				queue_free()
				return
	queue_redraw()

func _draw() -> void:
	var c := GS.element_color(element)
	var body := Color(1.0, 0.55, 0.1)
	if element == "ice":
		body = Color(0.65, 0.92, 1.0)
	elif element == "electric":
		body = Color(1.0, 0.95, 0.35)
	if element != "":
		draw_circle(Vector2.ZERO, 22, Color(c.r, c.g, c.b, 0.25))
		draw_circle(Vector2.ZERO, 14, Color(c.r, c.g, c.b, 0.35))
		for i in 3:
			draw_circle(Vector2(-34.0 - float(i) * 12.0, randf_range(-3.0, 3.0)), 7.0 - float(i) * 2.0, Color(c.r, c.g, c.b, 0.4 - float(i) * 0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -8), Vector2(20, 0), Vector2(-14, 8)]), body)
	draw_line(Vector2(-6, -4), Vector2(-2, -1), Color(0.85, 0.4, 0.05), 2.0)
	draw_line(Vector2(4, 2), Vector2(8, 0), Color(0.85, 0.4, 0.05), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, 0), Vector2(-28, -9), Vector2(-22, 0)]), Color(0.3, 0.75, 0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(-14, 0), Vector2(-28, 9), Vector2(-22, 0)]), Color(0.25, 0.65, 0.2))
