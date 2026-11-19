extends RefCounted
# Chargement des images générées (assets/*.png), avec mipmaps pour un rendu lisse.

static var _cache := {}

static func tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := "res://assets/%s.png" % name
	var out: Texture2D = null
	if ResourceLoader.exists(path):
		var t = load(path)
		if t != null:
			out = t
			var img: Image = t.get_image()
			if img != null:
				img.generate_mipmaps()
				out = ImageTexture.create_from_image(img)
	_cache[name] = out
	return out

# Dessine l'image n° idx d'une planche (cols x rows) dans le rectangle dest.
static func frame(ci: CanvasItem, name: String, idx: int, cols: int, rows: int, dest: Rect2) -> void:
	var t := tex(name)
	if t == null:
		return
	var fw := float(t.get_width()) / float(cols)
	var fh := float(t.get_height()) / float(rows)
	var col := idx % cols
	var row := floori(float(idx) / float(cols))
	ci.draw_texture_rect_region(t, dest, Rect2(float(col) * fw, float(row) * fh, fw, fh))

# Ombre douce au sol.
static func shadow(ci: CanvasItem, pos: Vector2, rx: float, ry: float, a: float) -> void:
	var t := tex("glow")
	if t == null:
		return
	ci.draw_texture_rect(t, Rect2(pos - Vector2(rx, ry), Vector2(rx * 2.0, ry * 2.0)), false, Color(0, 0, 0, a))
