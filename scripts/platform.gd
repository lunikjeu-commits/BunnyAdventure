extends StaticBody2D
# Sol / plateforme avec collision rectangulaire et texture d'herbe et de terre.

const Art = preload("res://scripts/art.gd")
const U := 0.75

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

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _strip(name: String, y: float) -> void:
	var t := Art.tex(name)
	if t == null:
		return
	var tw := float(t.get_width()) * U
	var th := float(t.get_height()) * U
	var x := 0.0
	while x < size.x:
		var w := minf(tw, size.x - x)
		draw_texture_rect_region(t, Rect2(x, y, w, th), Rect2(0.0, 0.0, w / U, float(t.get_height())))
		x += tw

func _draw() -> void:
	if size.y > 100.0:
		var t := Art.tex("soil")
		if t != null:
			var tw := float(t.get_width()) * U
			var y := 70.0
			while y < size.y:
				var h := minf(tw, size.y - y)
				var x := 0.0
				while x < size.x:
					var w := minf(tw, size.x - x)
					draw_texture_rect_region(t, Rect2(x, y, w, h), Rect2(0.0, 0.0, w / U, h / U))
					x += tw
				y += tw
		_strip("ground_top", -15.0)
	else:
		_strip("plat_m", -15.0)
