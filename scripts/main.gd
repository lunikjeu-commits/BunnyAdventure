extends Node2D
# Chef d'orchestre : menus, démarrage du niveau, pause, victoire, défaite, sauvegarde.

const GS = preload("res://scripts/game_state.gd")
const MenuScript = preload("res://scripts/menu.gd")
const LevelScript = preload("res://scripts/level.gd")
const BackgroundScript = preload("res://scripts/background.gd")

var menu = null
var level = null
var _ui_layer: CanvasLayer
var _bg_layer: CanvasLayer = null

func _ready() -> void:
	GS.load_settings()
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 50
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_layer)
	show_menu("main")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		GS.save_game()

func _set_menu_bg(on: bool) -> void:
	if on and _bg_layer == null:
		_bg_layer = CanvasLayer.new()
		_bg_layer.layer = -10
		add_child(_bg_layer)
		_bg_layer.add_child(BackgroundScript.new())
	elif (not on) and _bg_layer != null:
		_bg_layer.queue_free()
		_bg_layer = null

func _close_menu() -> void:
	if menu != null:
		menu.queue_free()
		menu = null

func _free_level() -> void:
	if level != null:
		level.queue_free()
		level = null

func _open_menu(screen: String, st: Dictionary = {}) -> void:
	_close_menu()
	menu = MenuScript.new()
	menu.has_save = GS.has_save()
	menu.stats = st
	menu.action.connect(_on_action)
	_ui_layer.add_child(menu)
	menu.set_screen(screen)

func show_menu(screen: String) -> void:
	get_tree().paused = false
	_free_level()
	_set_menu_bg(true)
	_open_menu(screen)

func start_level() -> void:
	get_tree().paused = false
	_free_level()
	_close_menu()
	_set_menu_bg(false)
	level = LevelScript.new()
	level.finished.connect(_on_finished)
	level.failed.connect(_on_failed)
	level.pause_requested.connect(_on_pause)
	add_child(level)

func _on_pause() -> void:
	get_tree().paused = true
	_open_menu("pause")

func _on_finished(st) -> void:
	get_tree().paused = true
	_open_menu("victory", st)

func _on_failed() -> void:
	get_tree().paused = true
	_open_menu("defeat")

func _on_action(id: String) -> void:
	match id:
		"new":
			GS.new_game()
			_open_menu("element")
		"continue":
			GS.load_game()
			if GS.element == "":
				_open_menu("element")
			else:
				start_level()
		"settings":
			_open_menu("settings")
		"back":
			show_menu("main")
		"pick_fire", "pick_ice", "pick_electric":
			GS.element = id.substr(5)
			GS.save_game()
			start_level()
		"scale_minus", "scale_plus":
			var step := 0.1
			if id == "scale_minus":
				step = -0.1
			GS.ui_scale = clampf(snappedf(GS.ui_scale + step, 0.1), 0.7, 1.4)
			GS.save_settings()
			menu.set_screen("settings")
		"op_minus", "op_plus":
			var step2 := 0.1
			if id == "op_minus":
				step2 = -0.1
			GS.ui_opacity = clampf(snappedf(GS.ui_opacity + step2, 0.1), 0.2, 1.0)
			GS.save_settings()
			menu.set_screen("settings")
		"resume":
			get_tree().paused = false
			_close_menu()
		"retry":
			start_level()
		"to_menu":
			GS.save_game()
			show_menu("main")
