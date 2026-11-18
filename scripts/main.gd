extends Node2D
# Niveau 1 de démonstration : « Découverte du jardin » (socle de l'étape 1).

const Gfx = preload("res://scripts/gfx.gd")
const PlayerScript = preload("res://scripts/player.gd")
const PlatformScript = preload("res://scripts/platform.gd")
const BackgroundScript = preload("res://scripts/background.gd")
const ControlsScript = preload("res://scripts/touch_controls.gd")

const LEVEL_W := 4300.0
const GROUND_Y := 560.0
const CAVE_X := 4150.0
# [début, fin] des tronçons de sol (les vides sont des fossés)
const GROUNDS := [[0, 1400], [1600, 2600], [2800, 4300]]
# [x, y, largeur] des plateformes flottantes
const PLATFORMS := [[500, 440, 160], [780, 360, 160], [1150, 440, 160], [1900, 430, 200], [2150, 340, 200], [3200, 440, 160]]

var player: CharacterBody2D
var cam: Camera2D
var center_label: Label
var _done := false

func _ready() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var bg = BackgroundScript.new()
	bg_layer.add_child(bg)

	for g in GROUNDS:
		var p = PlatformScript.new()
		var x0: float = g[0]
		var x1: float = g[1]
		p.setup(Vector2(x0, GROUND_Y), Vector2(x1 - x0, 400))
		add_child(p)
	for pf in PLATFORMS:
		var p = PlatformScript.new()
		var px: float = pf[0]
		var py: float = pf[1]
		var pw: float = pf[2]
		p.setup(Vector2(px, py), Vector2(pw, 24))
		add_child(p)

	var cave := Area2D.new()
	cave.position = Vector2(CAVE_X, GROUND_Y)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(80, 120)
	cs.shape = r
	cs.position = Vector2(0, -60)
	cave.add_child(cs)
	cave.body_entered.connect(_on_cave)
	add_child(cave)

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var controls = ControlsScript.new()
	ui.add_child(controls)

	player = PlayerScript.new()
	player.position = Vector2(120, GROUND_Y)
	player.controls = controls
	add_child(player)

	cam = Camera2D.new()
	cam.position = Vector2(0, -120)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.limit_left = 0
	cam.limit_right = int(LEVEL_W)
	cam.limit_bottom = 800
	player.add_child(cam)
	cam.make_current()
	bg.cam = cam

	var hud := Label.new()
	hud.text = "Niveau 1 · Découverte du jardin"
	hud.position = Vector2(20, 12)
	hud.add_theme_font_size_override("font_size", 26)
	hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	hud.add_theme_constant_override("outline_size", 6)
	ui.add_child(hud)

	center_label = Label.new()
	center_label.visible = false
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.add_theme_font_size_override("font_size", 56)
	center_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	center_label.add_theme_constant_override("outline_size", 10)
	ui.add_child(center_label)
	center_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _on_cave(body: Node) -> void:
	if body != player or _done:
		return
	_done = true
	center_label.text = "Grotte atteinte !\nNiveau terminé"
	center_label.visible = true
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for g in GROUNDS:
		var x: float = float(g[0]) + 220.0
		var xe: float = float(g[1]) - 160.0
		while x < xe:
			match rng.randi_range(0, 3):
				0:
					_fence(x)
				1:
					_bush(x)
				2:
					_flowers(x)
				3:
					_tree(x)
			x += rng.randf_range(170.0, 320.0)
	_cave()

func _fence(x: float) -> void:
	var wood := Color(0.62, 0.42, 0.24)
	var dark := Color(0.45, 0.30, 0.17)
	draw_rect(Rect2(x, GROUND_Y - 40, 110, 8), wood)
	draw_rect(Rect2(x, GROUND_Y - 22, 110, 8), wood)
	for i in 3:
		var px := x + float(i) * 50.0
		draw_rect(Rect2(px, GROUND_Y - 54, 12, 54), dark)
		draw_colored_polygon(PackedVector2Array([Vector2(px, GROUND_Y - 54), Vector2(px + 6, GROUND_Y - 64), Vector2(px + 12, GROUND_Y - 54)]), dark)

func _bush(x: float) -> void:
	Gfx.ell(self, Vector2(x, GROUND_Y - 18), 48, 28, Color(0.22, 0.55, 0.25))
	Gfx.ell(self, Vector2(x - 30, GROUND_Y - 12), 30, 20, Color(0.27, 0.62, 0.28))
	Gfx.ell(self, Vector2(x + 32, GROUND_Y - 12), 32, 20, Color(0.27, 0.62, 0.28))

func _flowers(x: float) -> void:
	var cols := [Color(1, 0.4, 0.5), Color(1, 0.85, 0.3), Color(0.8, 0.5, 1)]
	for i in 5:
		var fx := x + float(i) * 18.0
		var fh := 22.0 + float((i * 7) % 12)
		draw_line(Vector2(fx, GROUND_Y), Vector2(fx, GROUND_Y - fh), Color(0.25, 0.6, 0.25), 3.0)
		draw_circle(Vector2(fx, GROUND_Y - fh), 7.0, cols[i % 3])
		draw_circle(Vector2(fx, GROUND_Y - fh), 3.0, Color(1, 0.95, 0.5))

func _tree(x: float) -> void:
	draw_rect(Rect2(x - 12, GROUND_Y - 120, 24, 120), Color(0.50, 0.33, 0.20))
	Gfx.ell(self, Vector2(x, GROUND_Y - 160), 76, 62, Color(0.25, 0.60, 0.27))
	Gfx.ell(self, Vector2(x - 40, GROUND_Y - 135), 46, 38, Color(0.30, 0.66, 0.30))
	Gfx.ell(self, Vector2(x + 42, GROUND_Y - 138), 46, 38, Color(0.30, 0.66, 0.30))
	draw_circle(Vector2(x - 20, GROUND_Y - 170), 7.0, Color(0.9, 0.2, 0.2))
	draw_circle(Vector2(x + 28, GROUND_Y - 150), 7.0, Color(0.9, 0.2, 0.2))

func _cave() -> void:
	var c := Vector2(CAVE_X, GROUND_Y)
	Gfx.ell(self, c + Vector2(0, -50), 120, 110, Color(0.45, 0.45, 0.50))
	Gfx.ell(self, c + Vector2(-70, -20), 50, 40, Color(0.52, 0.52, 0.57))
	Gfx.ell(self, c + Vector2(0, -42), 62, 74, Color(0.08, 0.06, 0.10))
	draw_rect(Rect2(c.x - 70, c.y - 8, 140, 10), Color(0.36, 0.72, 0.28))
