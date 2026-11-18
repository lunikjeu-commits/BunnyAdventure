extends RefCounted
# État du jeu + sauvegarde locale (avec copie de secours).

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save_backup.json"
const SETTINGS_PATH := "user://settings.json"
const XP_PER_LEVEL := 40

static var element := ""
static var xp := 0
static var coins := 0
static var vegs := 0
static var level_reached := 1
static var ui_scale := 1.0
static var ui_opacity := 0.6

static func player_level() -> int:
	return 1 + int(float(xp) / float(XP_PER_LEVEL))

static func stage() -> int:
	var l := player_level()
	if l >= 8:
		return 3
	if l >= 4:
		return 2
	return 1

static func xp_fraction() -> float:
	return float(xp % XP_PER_LEVEL) / float(XP_PER_LEVEL)

static func max_hp() -> float:
	return 60.0 + 6.0 * float(player_level() - 1) + 20.0 * float(stage() - 1)

static func melee_damage() -> float:
	return 12.0 + 2.0 * float(player_level() - 1) + 6.0 * float(stage() - 1)

static func carrot_damage() -> float:
	return 8.0 + 1.0 * float(player_level() - 1) + 4.0 * float(stage() - 1)

# Renvoie "stage" si le lapin grandit, "level" s'il monte de niveau, sinon "".
static func add_xp(n: int) -> String:
	var l0 := player_level()
	var s0 := stage()
	xp += n
	if stage() > s0:
		return "stage"
	if player_level() > l0:
		return "level"
	return ""

static func element_color(el: String) -> Color:
	match el:
		"fire":
			return Color(1.0, 0.45, 0.1)
		"ice":
			return Color(0.45, 0.85, 1.0)
		"electric":
			return Color(1.0, 0.9, 0.2)
	return Color(1, 1, 1)

static func element_name(el: String) -> String:
	match el:
		"fire":
			return "FEU"
		"ice":
			return "GLACE"
		"electric":
			return "ÉLECTRIQUE"
	return ""

static func new_game() -> void:
	element = ""
	xp = 0
	coins = 0
	vegs = 0
	level_reached = 1

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)

static func _write(path: String, txt: String) -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(txt)
	f.close()
	if FileAccess.file_exists(path) and path == SAVE_PATH:
		DirAccess.copy_absolute(path, BACKUP_PATH)
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		var f2 := FileAccess.open(path, FileAccess.WRITE)
		if f2 != null:
			f2.store_string(txt)
			f2.close()

static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if typeof(data) == TYPE_DICTIONARY:
		return data
	return null

static func save_game() -> void:
	if element == "":
		return
	var data := {
		"v": 1, "element": element, "xp": xp, "coins": coins,
		"vegs": vegs, "level_reached": level_reached}
	_write(SAVE_PATH, JSON.stringify(data))

static func load_game() -> bool:
	var d = _read(SAVE_PATH)
	if d == null:
		d = _read(BACKUP_PATH)
	if d == null:
		return false
	element = str(d.get("element", ""))
	xp = int(d.get("xp", 0))
	coins = int(d.get("coins", 0))
	vegs = int(d.get("vegs", 0))
	level_reached = int(d.get("level_reached", 1))
	return true

static func save_settings() -> void:
	_write(SETTINGS_PATH, JSON.stringify({"ui_scale": ui_scale, "ui_opacity": ui_opacity}))

static func load_settings() -> void:
	var d = _read(SETTINGS_PATH)
	if d == null:
		return
	ui_scale = clampf(float(d.get("ui_scale", 1.0)), 0.7, 1.4)
	ui_opacity = clampf(float(d.get("ui_opacity", 0.6)), 0.2, 1.0)
