extends Node2D
# Projectile carotte : tout droit, marqué par l'élément du lapin.

const GS = preload("res://scripts/game_state.gd")
const Art = preload("res://scripts/art.gd")

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
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	var r := Rect2(global_position - Vector2(16, 12), Vector2(32, 24))
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
	var key := "n"
	match element:
		"fire":
			key = "f"
		"ice":
			key = "i"
		"electric":
			key = "e"
	var g := Art.tex("glow")
	if element != "" and g != null:
		draw_texture_rect(g, Rect2(-58, -44, 116, 88), false, Color(c.r, c.g, c.b, 0.55))
		for i in 3:
			var a := 0.4 - float(i) * 0.1
			draw_texture_rect(g, Rect2(-52.0 - float(i) * 24.0, -15.0 + randf_range(-3.0, 3.0), 30, 30), false, Color(c.r, c.g, c.b, a))
	var t := Art.tex("carrot_" + key)
	if t != null:
		draw_texture_rect(t, Rect2(-32, -12, 64, 24), false)
