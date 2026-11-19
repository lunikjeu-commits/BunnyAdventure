extends Control
# Menus tactiles dessinés à la main : principal, élément, paramètres, pause, victoire, défaite.

signal action(id)

const Gfx = preload("res://scripts/gfx.gd")
const GS = preload("res://scripts/game_state.gd")
const RabbitGfx = preload("res://scripts/rabbit_gfx.gd")

const DESC := {
	"fire": ["Brûlure progressive", "Dégâts sur la durée"],
	"ice": ["Ralentit et gèle", "Réduit l'attaque ennemie"],
	"electric": ["Paralyse brièvement", "Interrompt les attaques"],
}

var screen := "main"
var has_save := false
var stats := {}

var _items := []
var _pressed := -1
var _t := 0.0
var _dim := false
var _title := ""
var _sub := ""
var _title_y := 150.0
var _title_size := 72
var _title_col := Color.WHITE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_build)
	_build()

func set_screen(s: String) -> void:
	screen = s
	_build()

func _add(id: String, text: String, rect: Rect2, col: Color, enabled: bool = true) -> void:
	_items.append({"id": id, "text": text, "rect": rect, "col": col, "enabled": enabled, "card": false, "el": ""})

func _add_card(id: String, rect: Rect2, el: String) -> void:
	_items.append({"id": id, "text": "", "rect": rect, "col": Color.WHITE, "enabled": true, "card": true, "el": el})

func _build() -> void:
	_items.clear()
	_pressed = -1
	var sz := get_viewport_rect().size
	var cx := sz.x * 0.5
	var bw := 500.0
	var bh := 76.0
	var gap := 16.0
	var green := Color(0.30, 0.70, 0.30)
	var blue := Color(0.25, 0.55, 0.90)
	var brown := Color(0.55, 0.45, 0.35)
	_dim = false
	_title = ""
	_sub = ""
	_title_y = sz.y * 0.22
	_title_size = 72
	_title_col = Color.WHITE
	match screen:
		"main":
			_title = "BUNNY ADVENTURE"
			_sub = "Un petit lapin, un grand destin"
			var y := sz.y * 0.40
			_add("new", "Nouvelle partie", Rect2(cx - bw * 0.5, y, bw, bh), green)
			_add("continue", "Continuer", Rect2(cx - bw * 0.5, y + bh + gap, bw, bh), blue, has_save)
			_add("settings", "Paramètres", Rect2(cx - bw * 0.5, y + 2.0 * (bh + gap), bw, bh), brown)
		"element":
			_title = "Choisis ton élément"
			_title_y = 70.0
			_title_size = 48
			var cw := minf(360.0, (sz.x - 120.0) / 3.0)
			var ch := sz.y * 0.64
			var top := 100.0
			var els := ["fire", "ice", "electric"]
			for i in 3:
				var rx := cx + (float(i) - 1.0) * (cw + 24.0) - cw * 0.5
				_add_card("pick_" + str(els[i]), Rect2(rx, top, cw, ch), str(els[i]))
			_add("back", "Retour", Rect2(cx - 150.0, top + ch + 16.0, 300.0, 56.0), brown)
		"settings":
			_title = "Paramètres"
			_title_y = 90.0
			_title_size = 56
			var y0 := 170.0
			_add("scale_minus", "-", Rect2(cx + 20.0, y0, 90.0, 64.0), blue)
			_add("scale_plus", "+", Rect2(cx + 230.0, y0, 90.0, 64.0), blue)
			_add("op_minus", "-", Rect2(cx + 20.0, y0 + 90.0, 90.0, 64.0), blue)
			_add("op_plus", "+", Rect2(cx + 230.0, y0 + 90.0, 90.0, 64.0), blue)
			_add("back", "Retour", Rect2(cx - 150.0, y0 + 200.0, 300.0, 64.0), brown)
		"pause":
			_dim = true
			_title = "Pause"
			var y := sz.y * 0.38
			_add("resume", "Reprendre", Rect2(cx - bw * 0.5, y, bw, bh), green)
			_add("to_menu", "Menu principal", Rect2(cx - bw * 0.5, y + bh + gap, bw, bh), brown)
		"defeat":
			_dim = true
			_title = "Défaite"
			_title_col = Color(1.0, 0.45, 0.45)
			_sub = "Ne baisse pas les oreilles, réessaie !"
			var y := sz.y * 0.45
			_add("retry", "Rejouer", Rect2(cx - bw * 0.5, y, bw, bh), green)
			_add("to_menu", "Menu principal", Rect2(cx - bw * 0.5, y + bh + gap, bw, bh), brown)
		"victory":
			_dim = true
			_title = "Niveau terminé !"
			_title_y = sz.y * 0.17
			_title_col = Color(1.0, 0.9, 0.3)
			var y := sz.y * 0.66
			_add("retry", "Rejouer le niveau", Rect2(cx - bw * 0.5, y, bw, bh), green)
			_add("to_menu", "Menu principal", Rect2(cx - bw * 0.5, y + bh + gap, bw, bh), brown)
	queue_redraw()

func _process(d: float) -> void:
	_t += d
	queue_redraw()

func _hit(pos: Vector2) -> int:
	for i in range(_items.size() - 1, -1, -1):
		var r: Rect2 = _items[i]["rect"]
		if r.has_point(pos):
			return i
	return -1

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_pressed = _hit(event.position)
		else:
			var h := _hit(event.position)
			var was := _pressed
			_pressed = -1
			if h != -1 and h == was and bool(_items[h]["enabled"]):
				var id: String = _items[h]["id"]
				action.emit(id)

func _txt(font: Font, text: String, pos: Vector2, width: float, size: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	draw_string_outline(font, pos, text, align, width, size, 8, Color(0, 0, 0, 0.7))
	draw_string(font, pos, text, align, width, size, col)

func _draw() -> void:
	var sz := get_viewport_rect().size
	var cx := sz.x * 0.5
	var font := ThemeDB.fallback_font
	if _dim:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.6))
	if _title != "":
		_txt(font, _title, Vector2(0, _title_y), sz.x, _title_size, _title_col)
	if _sub != "":
		_txt(font, _sub, Vector2(0, _title_y + 50.0), sz.x, 28, Color(1, 1, 1, 0.9))
	if screen == "settings":
		var y0 := 170.0
		_txt(font, "Taille des commandes", Vector2(cx - 440.0, y0 + 44.0), 420.0, 30, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		_txt(font, "%d %%" % int(round(GS.ui_scale * 100.0)), Vector2(cx + 110.0, y0 + 44.0), 120.0, 30, Color.WHITE)
		_txt(font, "Opacité des commandes", Vector2(cx - 440.0, y0 + 134.0), 420.0, 30, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		_txt(font, "%d %%" % int(round(GS.ui_opacity * 100.0)), Vector2(cx + 110.0, y0 + 134.0), 120.0, 30, Color.WHITE)
		_txt(font, "Bunny Adventure v0.2 · lunikapp", Vector2(0, sz.y - 40.0), sz.x, 24, Color(1, 1, 1, 0.85))
	if screen == "main":
		_txt(font, "lunikapp", Vector2(0, sz.y - 30.0), sz.x, 22, Color(1, 1, 1, 0.7))
	if screen == "victory":
		var lines := [
			"Pièces obtenues : %d" % int(stats.get("coins", 0)),
			"Expérience gagnée : %d" % int(stats.get("xp", 0)),
			"Légumes récoltés : %d" % int(stats.get("vegs", 0)),
			"Ennemis vaincus : %d" % int(stats.get("kills", 0))]
		for i in lines.size():
			_txt(font, str(lines[i]), Vector2(0, sz.y * 0.30 + float(i) * 44.0), sz.x, 30, Color.WHITE)
	for i in _items.size():
		var it: Dictionary = _items[i]
		var r: Rect2 = it["rect"]
		var pressed := i == _pressed
		if bool(it["card"]):
			_draw_card(it, r, pressed, font)
		else:
			_draw_button(it, r, pressed, font)

func _draw_button(it: Dictionary, r: Rect2, pressed: bool, font: Font) -> void:
	var col: Color = it["col"]
	if not bool(it["enabled"]):
		col = Color(0.4, 0.4, 0.4)
	if pressed:
		col = col.lightened(0.25)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(4)
	sb.border_color = Color(1, 1, 1, 0.85)
	draw_style_box(sb, r)
	_txt(font, str(it["text"]), Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 11.0), r.size.x, 30, Color.WHITE)

func _draw_card(it: Dictionary, r: Rect2, pressed: bool, font: Font) -> void:
	var el: String = it["el"]
	var c := GS.element_color(el)
	var bg := Color(c.r * 0.35, c.g * 0.35, c.b * 0.35, 0.92)
	if pressed:
		bg = bg.lightened(0.2)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(26)
	sb.set_border_width_all(6)
	sb.border_color = c
	draw_style_box(sb, r)
	var center := Vector2(r.position.x + r.size.x * 0.5, r.position.y + 215.0)
	RabbitGfx.draw(self, center, 1.0, 1, _t, 0.0, 0.0, 0.0, el, 2.0)
	_txt(font, GS.element_name(el), Vector2(r.position.x, r.position.y + r.size.y - 120.0), r.size.x, 36, c)
	var d: Array = DESC[el]
	_txt(font, str(d[0]), Vector2(r.position.x, r.position.y + r.size.y - 78.0), r.size.x, 20, Color.WHITE)
	_txt(font, str(d[1]), Vector2(r.position.x, r.position.y + r.size.y - 50.0), r.size.x, 20, Color.WHITE)
