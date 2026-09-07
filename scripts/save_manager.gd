class_name SaveManager
extends RefCounted

const SAVE_PATH: String = "user://save_data.json"

static var nanites: int = 0
static var selected_operative: String = "vex"
static var unlocked_operatives: Array = ["vex", "pyro", "volt", "colossus"]

static var meta_upgrades: Dictionary = {
	"max_health": 0,    # Max 10: +10 HP each
	"armor": 0,         # Max 5: -1 damage taken each
	"regen": 0,         # Max 5: +0.5 HP/s each
	"move_speed": 0,    # Max 5: +5% speed each
	"magnet": 0,        # Max 5: +15% radius each
	"damage": 0,        # Max 10: +3% damage each
	"cooldown": 0,      # Max 5: -2.5% CD each
	"crit": 0,          # Max 5: +3% crit chance each
	"rerolls": 0,       # Max 3: +1 reroll per run
	"banishes": 0,      # Max 3: +1 banish per run
	"nanite_gain": 0    # Max 5: +10% nanite gain
}

static var max_upgrade_levels: Dictionary = {
	"max_health": 10,
	"armor": 5,
	"regen": 5,
	"move_speed": 5,
	"magnet": 5,
	"damage": 10,
	"cooldown": 5,
	"crit": 5,
	"rerolls": 3,
	"banishes": 3,
	"nanite_gain": 5
}

static var base_upgrade_costs: Dictionary = {
	"max_health": 100,
	"armor": 200,
	"regen": 250,
	"move_speed": 150,
	"magnet": 100,
	"damage": 200,
	"cooldown": 300,
	"crit": 250,
	"rerolls": 500,
	"banishes": 500,
	"nanite_gain": 200
}

const I18nClass = preload("res://scripts/i18n.gd")

static var language: String = "vi"

static var upgrade_defs: Dictionary = {}
static var operative_defs: Dictionary = {}

static func refresh_definitions() -> void:
	upgrade_defs = {
		"max_health": {"name": I18nClass.loc("up_max_health_name"), "desc": I18nClass.loc("up_max_health_desc"), "icon": "hp", "unit": I18nClass.loc("up_max_health_unit")},
		"armor": {"name": I18nClass.loc("up_armor_name"), "desc": I18nClass.loc("up_armor_desc"), "icon": "armor", "unit": I18nClass.loc("up_armor_unit")},
		"regen": {"name": I18nClass.loc("up_regen_name"), "desc": I18nClass.loc("up_regen_desc"), "icon": "regen", "unit": I18nClass.loc("up_regen_unit")},
		"move_speed": {"name": I18nClass.loc("up_move_speed_name"), "desc": I18nClass.loc("up_move_speed_desc"), "icon": "speed", "unit": I18nClass.loc("up_move_speed_unit")},
		"magnet": {"name": I18nClass.loc("up_magnet_name"), "desc": I18nClass.loc("up_magnet_desc"), "icon": "magnet", "unit": I18nClass.loc("up_magnet_unit")},
		"damage": {"name": I18nClass.loc("up_damage_name"), "desc": I18nClass.loc("up_damage_desc"), "icon": "damage", "unit": I18nClass.loc("up_damage_unit")},
		"cooldown": {"name": I18nClass.loc("up_cooldown_name"), "desc": I18nClass.loc("up_cooldown_desc"), "icon": "cooldown", "unit": I18nClass.loc("up_cooldown_unit")},
		"crit": {"name": I18nClass.loc("up_crit_name"), "desc": I18nClass.loc("up_crit_desc"), "icon": "crit", "unit": I18nClass.loc("up_crit_unit")},
		"rerolls": {"name": I18nClass.loc("up_rerolls_name"), "desc": I18nClass.loc("up_rerolls_desc"), "icon": "reroll", "unit": I18nClass.loc("up_rerolls_unit")},
		"banishes": {"name": I18nClass.loc("up_banishes_name"), "desc": I18nClass.loc("up_banishes_desc"), "icon": "banish", "unit": I18nClass.loc("up_banishes_unit")},
		"nanite_gain": {"name": I18nClass.loc("up_nanite_gain_name"), "desc": I18nClass.loc("up_nanite_gain_desc"), "icon": "nanite", "unit": I18nClass.loc("up_nanite_gain_unit")}
	}

	operative_defs = {
		"vex": {
			"name": I18nClass.loc("op_vex_name"),
			"title": I18nClass.loc("op_vex_title"),
			"weapon": "Railgun",
			"desc": I18nClass.loc("op_vex_desc"),
			"color": Color(0.2, 0.9, 1.0)
		},
		"pyro": {
			"name": I18nClass.loc("op_pyro_name"),
			"title": I18nClass.loc("op_pyro_title"),
			"weapon": "Flamethrower",
			"desc": I18nClass.loc("op_pyro_desc"),
			"color": Color(1.0, 0.45, 0.15)
		},
		"volt": {
			"name": I18nClass.loc("op_volt_name"),
			"title": I18nClass.loc("op_volt_title"),
			"weapon": "Tesla Coil",
			"desc": I18nClass.loc("op_volt_desc"),
			"color": Color(0.9, 0.85, 0.2)
		},
		"colossus": {
			"name": I18nClass.loc("op_colossus_name"),
			"title": I18nClass.loc("op_colossus_title"),
			"weapon": "Blade Orbit",
			"desc": I18nClass.loc("op_colossus_desc"),
			"color": Color(0.3, 1.0, 0.5)
		}
	}

static func set_language(new_lang: String) -> void:
	language = new_lang
	I18nClass.set_language(new_lang)
	refresh_definitions()
	save_game()

static var total_kills: int = 0
static var best_time: float = 0.0
static var total_runs: int = 0

static var _loaded: bool = false

static func refund_all_upgrades() -> void:
	var total_refund = 0
	for k in meta_upgrades.keys():
		var lvl = meta_upgrades[k]
		var base = base_upgrade_costs.get(k, 100)
		for i in range(lvl):
			total_refund += int(base * pow(1.65, i))
		meta_upgrades[k] = 0
	nanites += total_refund
	save_game()

static func init_and_load() -> void:
	if _loaded:
		return
	_loaded = true
	load_game()

static func get_upgrade_cost(id: String) -> int:
	var lvl = meta_upgrades.get(id, 0)
	var max_lvl = max_upgrade_levels.get(id, 5)
	if lvl >= max_lvl:
		return -1
	var base = base_upgrade_costs.get(id, 100)
	return int(base * pow(1.65, lvl))

static func buy_upgrade(id: String) -> bool:
	var cost = get_upgrade_cost(id)
	if cost == -1 or nanites < cost:
		return false
	nanites -= cost
	meta_upgrades[id] = meta_upgrades.get(id, 0) + 1
	save_game()
	return true

static func get_bonus(id: String) -> float:
	var lvl = float(meta_upgrades.get(id, 0))
	match id:
		"max_health": return lvl * 10.0
		"armor": return lvl * 1.0
		"regen": return lvl * 0.5
		"move_speed": return lvl * 0.05
		"magnet": return lvl * 0.15
		"damage": return lvl * 0.03
		"cooldown": return lvl * 0.025
		"crit": return lvl * 0.03
		"rerolls": return lvl
		"banishes": return lvl
		"nanite_gain": return lvl * 0.10
		_: return 0.0

static func add_nanites(amount: int) -> void:
	var mult = 1.0 + get_bonus("nanite_gain")
	nanites += int(amount * mult)
	save_game()

static func record_run_stats(run_time: float, run_kills: int) -> void:
	total_runs += 1
	total_kills += run_kills
	if run_time > best_time:
		best_time = run_time
	save_game()

static func save_game() -> void:
	var data = {
		"language": language,
		"nanites": nanites,
		"selected_operative": selected_operative,
		"unlocked_operatives": unlocked_operatives,
		"meta_upgrades": meta_upgrades,
		"total_kills": total_kills,
		"best_time": best_time,
		"total_runs": total_runs
	}
	var tmp_path = SAVE_PATH + ".tmp"
	var file = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file:
		var json = JSON.stringify(data, "\t")
		file.store_string(json)
		file.close()
		DirAccess.rename_absolute(tmp_path, SAVE_PATH)

static func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		refresh_definitions()
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		refresh_definitions()
		return
	var content = file.get_as_text()
	file.close()
	var test_json_conv = JSON.new()
	var error = test_json_conv.parse(content)
	if error != OK:
		refresh_definitions()
		return
	var data = test_json_conv.data
	if typeof(data) == TYPE_DICTIONARY:
		language = str(data.get("language", "vi"))
		I18nClass.set_language(language)
		refresh_definitions()
		nanites = int(data.get("nanites", 0))
		selected_operative = str(data.get("selected_operative", "vex"))
		if data.has("unlocked_operatives"):
			unlocked_operatives = data["unlocked_operatives"]
		if data.has("meta_upgrades"):
			for k in data["meta_upgrades"].keys():
				if meta_upgrades.has(k):
					meta_upgrades[k] = int(data["meta_upgrades"][k])
		total_kills = int(data.get("total_kills", 0))
		best_time = float(data.get("best_time", 0.0))
		total_runs = int(data.get("total_runs", 0))
	else:
		refresh_definitions()
		total_runs = int(data.get("total_runs", 0))
