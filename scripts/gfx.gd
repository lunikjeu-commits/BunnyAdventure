extends RefCounted
# Petites fonctions de dessin vectoriel partagées (style cartoon).

static func ell(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry).rotated(rot) + c)
	ci.draw_colored_polygon(pts, col)

static func ell_o(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, outline: Color, w: float = 2.5, rot: float = 0.0) -> void:
	ell(ci, c, rx + w, ry + w, outline, rot)
	ell(ci, c, rx, ry, col, rot)
