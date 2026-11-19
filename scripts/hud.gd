extends Control
# Interface en jeu : vie, expérience, jauge spéciale, pièces, légumes, bouton menu.

signal pause_pressed

const GS = preload("res://scripts/game_state.gd")

var player = null
var _toast := ""
var _toast_t := 0.0
var _menu_rect := Rect2()
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var sz := get_viewport_rect().size
	_menu_rect = Rect2(sz.x - 150.0, 74.0, 130.0, 54.0)
	queue_redraw()

func toast(t: String) -> void:
	_toast = t
	_toast_t = 2.4

func _process(d: float) -> void:
	_t += d
	_toast_t = maxf(_toast_t - d, 0.0)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if _menu_rect.has_point(event.position):
			pause_pressed.emit()

func _bar(r: Rect2, ratio: float, col: Color) -> void:
	draw_rect(r, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0.0, 1.0), r.size.y)), col)
	draw_rect(r, Color(1, 1, 1, 0.7), false, 2.0)

func _txt(font: Font, text: String, pos: Vector2, width: float, size: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string_outline(font, pos, text, align, width, size, 6, Color(0, 0, 0, 0.8))
	draw_string(font, pos, text, align, width, size, col)

func _draw() -> void:
	var sz := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	if player != null:
		var x := 20.0
		var y := 62.0
		var bw := 300.0
		var ec := GS.element_color(player.element)
		draw_circle(Vector2(x + 24.0, y + 30.0), 26.0, Color(0.12, 0.12, 0.18, 0.9))
		draw_arc(Vector2(x + 24.0, y + 30.0), 26.0, 0.0, TAU, 32, ec, 4.0)
		_txt(font, str(GS.player_level()), Vector2(x, y + 40.0), 48.0, 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		_bar(Rect2(x + 60.0, y, bw, 26.0), player.hp / player.max_hp, Color(0.9, 0.2, 0.25))
		_txt(font, "%d / %d" % [int(ceil(player.hp)), int(player.max_hp)], Vector2(x + 60.0, y + 21.0), bw, 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		_bar(Rect2(x + 60.0, y + 32.0, bw, 12.0), GS.xp_fraction(), Color(0.3, 0.6, 1.0))
		var gr: float = player.gauge / 100.0
		var gc := ec
		if gr >= 1.0 and int(_t * 6.0) % 2 == 0:
			gc = Color.WHITE
		_bar(Rect2(x + 60.0, y + 50.0, bw, 12.0), gr, gc)
	# pièces
	var cx := sz.x - 290.0
	draw_circle(Vector2(cx, 34.0), 14.0, Color(1.0, 0.82, 0.2))
	draw_circle(Vector2(cx, 34.0), 8.0, Color(1.0, 0.93, 0.55))
	_txt(font, str(GS.coins), Vector2(cx + 24.0, 44.0), 120.0, 30, Color.WHITE)
	# légumes
	var vx := sz.x - 140.0
	draw_colored_polygon(PackedVector2Array([Vector2(vx - 9, 20), Vector2(vx + 9, 20), Vector2(vx, 48)]), Color(1.0, 0.55, 0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(vx, 20), Vector2(vx - 9, 8), Vector2(vx - 2, 20)]), Color(0.3, 0.75, 0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(vx, 20), Vector2(vx + 9, 8), Vector2(vx + 2, 20)]), Color(0.25, 0.65, 0.2))
	_txt(font, str(GS.vegs), Vector2(vx + 24.0, 44.0), 100.0, 30, Color.WHITE)
	# bouton menu
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.15, 0.6)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.7)
	draw_style_box(sb, _menu_rect)
	_txt(font, "MENU", Vector2(_menu_rect.position.x, _menu_rect.position.y + 36.0), _menu_rect.size.x, 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	# message
	if _toast_t > 0.0:
		var a := clampf(_toast_t, 0.0, 1.0)
		_txt(font, _toast, Vector2(0, 170.0), sz.x, 44, Color(1.0, 0.9, 0.3, a), HORIZONTAL_ALIGNMENT_CENTER)
