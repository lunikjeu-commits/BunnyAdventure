extends Node2D
# Niveau 1 « Découverte du jardin » : données + construction du niveau.

signal finished(stats)
signal failed
signal pause_requested

const Art = preload("res://scripts/art.gd")
const GS = preload("res://scripts/game_state.gd")
const PlayerScript = preload("res://scripts/player.gd")
const PlatformScript = preload("res://scripts/platform.gd")
const BackgroundScript = preload("res://scripts/background.gd")
const ControlsScript = preload("res://scripts/touch_controls.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const HudScript = preload("res://scripts/hud.gd")

const LEVEL_W := 4300.0
const GROUND_Y := 560.0
const CAVE_X := 4150.0
# [début, fin] des tronçons de sol (les vides sont des fossés)
const GROUNDS := [[0, 1400], [1600, 2600], [2800, 4300]]
# [x, y, largeur] des plateformes flottantes
const PLATFORMS := [[500, 440, 160], [780, 360, 160], [1150, 440, 160], [1900, 430, 200], [2150, 340, 200], [3200, 440, 160]]
# [type, x, y, rayon de patrouille]
const ENEMIES := [
	["dog", 850.0, 560.0, 220.0],
	["bird", 1250.0, 330.0, 200.0],
	["dog", 1800.0, 560.0, 260.0],
	["bird", 2300.0, 300.0, 220.0],
	["fox", 3050.0, 560.0, 300.0],
	["dog", 3500.0, 560.0, 260.0],
	["bird", 3750.0, 330.0, 200.0],
]
# [type, x, y]
const PICKUPS := [
	["carrot", 350.0, 520.0], ["coin", 500.0, 400.0], ["coin", 580.0, 400.0],
	["coin", 830.0, 320.0], ["coin", 880.0, 320.0], ["tomato", 1000.0, 520.0],
	["coin", 1230.0, 400.0], ["coin", 1450.0, 470.0], ["coin", 1500.0, 430.0],
	["coin", 1550.0, 470.0], ["lettuce", 1700.0, 520.0], ["coin", 1960.0, 390.0],
	["coin", 2040.0, 390.0], ["carrot", 2250.0, 300.0], ["coin", 2650.0, 470.0],
	["coin", 2700.0, 430.0], ["coin", 2750.0, 470.0], ["tomato", 3000.0, 520.0],
	["coin", 3280.0, 400.0], ["lettuce", 3600.0, 520.0], ["carrot", 3900.0, 520.0],
	["coin", 3950.0, 520.0], ["coin", 4000.0, 520.0],
]

var player
var cam: Camera2D
var hud
var center_label: Label
var stats := {"coins": 0, "xp": 0, "kills": 0, "vegs": 0}
var _done := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
		p.setup(Vector2(px, py), Vector2(pw, 56))
		add_child(p)

	for pk in PICKUPS:
		var it = PickupScript.new()
		it.setup(str(pk[0]), Vector2(float(pk[1]), float(pk[2])))
		it.collected.connect(_on_pickup)
		add_child(it)

	for e in ENEMIES:
		var en = EnemyScript.new()
		en.setup(str(e[0]), Vector2(float(e[1]), float(e[2])), float(e[3]), 1.0)
		en.killed.connect(_on_enemy_killed)
		add_child(en)

	var cave := Area2D.new()
	cave.position = Vector2(CAVE_X, GROUND_Y)
	cave.collision_mask = 4
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
	controls.process_mode = Node.PROCESS_MODE_ALWAYS
	ui.add_child(controls)
	controls.apply_settings(GS.ui_scale, GS.ui_opacity)

	player = PlayerScript.new()
	player.position = Vector2(120, GROUND_Y)
	player.controls = controls
	player.died.connect(_on_died)
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

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 9
	add_child(hud_layer)
	hud = HudScript.new()
	hud.player = player
	hud.pause_pressed.connect(func(): pause_requested.emit())
	hud_layer.add_child(hud)

	var title := Label.new()
	title.text = "Niveau 1 · Découverte du jardin"
	title.position = Vector2(20, 10)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("outline_size", 6)
	ui.add_child(title)

	center_label = Label.new()
	center_label.visible = false
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.add_theme_font_size_override("font_size", 56)
	center_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	center_label.add_theme_constant_override("outline_size", 10)
	ui.add_child(center_label)
	center_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var tm := Timer.new()
	tm.wait_time = 15.0
	tm.autostart = true
	tm.timeout.connect(func(): GS.save_game())
	add_child(tm)

func _award_xp(n: int) -> void:
	stats["xp"] += n
	var r := GS.add_xp(n)
	if r == "stage":
		hud.toast("Ton lapin grandit !")
		player.full_heal()
		GS.save_game()
	elif r == "level":
		hud.toast("Niveau %d !" % GS.player_level())
		player.full_heal()
		GS.save_game()

func _on_enemy_killed(e) -> void:
	stats["kills"] += 1
	stats["coins"] += e.coin_reward
	GS.coins += e.coin_reward
	_award_xp(e.xp_reward)

func _on_pickup(kind) -> void:
	if kind == "coin":
		GS.coins += 1
		stats["coins"] += 1
	else:
		GS.vegs += 1
		stats["vegs"] += 1
		player.heal(10.0)
		_award_xp(8)

func _on_cave(body: Node) -> void:
	if body != player or _done:
		return
	_done = true
	stats["coins"] += 20
	GS.coins += 20
	_award_xp(30)
	GS.level_reached = maxi(GS.level_reached, 2)
	GS.save_game()
	center_label.text = "Grotte atteinte !"
	center_label.visible = true
	await get_tree().create_timer(1.4).timeout
	finished.emit(stats)

func _on_died() -> void:
	if _done:
		return
	_done = true
	center_label.text = "Oh non..."
	center_label.visible = true
	GS.save_game()
	await get_tree().create_timer(1.2).timeout
	failed.emit()

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var items := []
	for g in GROUNDS:
		var x: float = float(g[0]) + 220.0
		var xe: float = float(g[1]) - 160.0
		while x < xe:
			items.append([rng.randi_range(0, 3), x])
			x += rng.randf_range(190.0, 330.0)
	_sprite("cave", CAVE_X, 0.85)
	for order in [3, 1, 0, 2]:
		for it in items:
			if int(it[0]) == order:
				var x: float = it[1]
				match order:
					0:
						_sprite("fence", x, 0.75)
					1:
						_sprite("bush", x, 0.7)
					2:
						_sprite("flowers", x, 0.7)
					3:
						_sprite("tree", x, 0.7)

func _sprite(name: String, x: float, k: float) -> void:
	var t := Art.tex(name)
	if t == null:
		return
	var sz := Vector2(float(t.get_width()), float(t.get_height())) * k
	draw_texture_rect(t, Rect2(Vector2(x - sz.x * 0.5, GROUND_Y + 8.0 - sz.y), sz), false)
