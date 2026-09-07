extends CanvasLayer

@onready var panel_root: Control = $Root
@onready var tab_container: TabContainer = $Root/Panel/TabContainer

# Tab 1: Spawner
@onready var chk_auto_spawning: CheckBox = $Root/Panel/TabContainer/Spawner/VBox/HBoxSpawnToggle/ChkAutoSpawn
@onready var btn_clear_enemies: Button = $Root/Panel/TabContainer/Spawner/VBox/HBoxClear/BtnClearEnemies
@onready var btn_clear_props: Button = $Root/Panel/TabContainer/Spawner/VBox/HBoxClear/BtnClearProps
@onready var opt_entity_type: OptionButton = $Root/Panel/TabContainer/Spawner/VBox/HBoxSelect/OptEntity
@onready var spin_count: SpinBox = $Root/Panel/TabContainer/Spawner/VBox/HBoxSelect/SpinCount
@onready var chk_spawn_mouse: CheckBox = $Root/Panel/TabContainer/Spawner/VBox/HBoxSpawnAction/ChkMouse
@onready var btn_spawn: Button = $Root/Panel/TabContainer/Spawner/VBox/HBoxSpawnAction/BtnSpawn
@onready var btn_quick_dummy: Button = $Root/Panel/TabContainer/Spawner/VBox/BtnQuickDummy

# Tab 2: Upgrades
@onready var btn_max_all: Button = $Root/Panel/TabContainer/Upgrades/VBox/HBoxPresets/BtnMaxAll
@onready var btn_reset_all: Button = $Root/Panel/TabContainer/Upgrades/VBox/HBoxPresets/BtnResetAll
@onready var weapons_container: VBoxContainer = $Root/Panel/TabContainer/Upgrades/VBox/ScrollWeapons/VBoxWeapons
@onready var passives_container: VBoxContainer = $Root/Panel/TabContainer/Upgrades/VBox/ScrollPassives/VBoxPassives

# Tab 3: Timeline
@onready var timeline_grid: GridContainer = $Root/Panel/TabContainer/Timeline/VBox/GridJumps
@onready var spin_custom_time: SpinBox = $Root/Panel/TabContainer/Timeline/VBox/HBoxCustom/SpinTime
@onready var btn_jump_custom: Button = $Root/Panel/TabContainer/Timeline/VBox/HBoxCustom/BtnJump
@onready var chk_godmode: CheckBox = $Root/Panel/TabContainer/Timeline/VBox/ChkGodmode
@onready var btn_restart_game: Button = $Root/Panel/TabContainer/Timeline/VBox/BtnRestart
@onready var btn_exit_menu: Button = $Root/Panel/TabContainer/Timeline/VBox/BtnExitMenu

# Tab 4: DPS Meter
@onready var chk_show_dps: CheckBox = $Root/Panel/TabContainer/DPS/VBox/ChkShowDPS
@onready var btn_reset_dps: Button = $Root/Panel/TabContainer/DPS/VBox/BtnResetDPS
@onready var lbl_dps_info: Label = $Root/Panel/TabContainer/DPS/VBox/LblDPSInfo

var is_open: bool = false
var main_ref: Node2D = null
var player_ref: CharacterBody2D = null
var dps_meter_ref: Control = null

const ENTITY_KEYS = [
	"crawler", "scout", "brute", "spitter", "exploder",
	"elite_tier1", "elite_tier2", "boss_leviathan", "boss_dreadnought",
	"target_dummy", "crate", "gem_regular", "gem_super",
	"pickup_nuke", "pickup_vacuum", "pickup_medkit", "pickup_overclock"
]

const ENTITY_NAMES = [
	"👾 Crawler (Fast Swarm)",
	"⚡ Scout (Flanker)",
	"🌋 Brute (Heavy Tank)",
	"☣️ Spitter (Acid Ranged)",
	"💥 Exploder (Kamikaze)",
	"👑 Elite Tier 1 (Golden Champion)",
	"🔮 Elite Tier 2 (Dread Champion)",
	"🦖 Boss 1: Apex Leviathan (5x)",
	"🛸 Boss 2: Cyber Dreadnought (5x)",
	"🎯 Target Dummy (Immortal)",
	"📦 Wooden Crate",
	"💎 Regular EXP Gem",
	"🌟 Super EXP Gem (60 XP)",
	"☢️ EMP Nuke Pickup",
	"🧲 Magnet Vacuum Pickup",
	"💊 Medkit Heal Pickup",
	"⚡ Overclock Powerup"
]

const WEAPON_KEYS = [
	{"id": "railgun", "name": "Hyperion Railgun", "evo": "Hyperion Beam"},
	{"id": "flame", "name": "Sunstorm Flamethrower", "evo": "Sunstorm Plasma"},
	{"id": "shockwave", "name": "Supernova Pulse", "evo": "Supernova Blackhole"},
	{"id": "missile", "name": "Magic Missile", "evo": "Barrage Volley"},
	{"id": "blade", "name": "Blade Orbit", "evo": "Vortex Razor"},
	{"id": "tesla", "name": "Tesla Coil", "evo": "Mjolnir Arc"},
	{"id": "mortar", "name": "Bio Mortar", "evo": "Chernobyl Shell"}
]

const PASSIVE_KEYS = [
	{"id": "energy_core", "name": "Energy Core (Cooldown Reduction)"},
	{"id": "nano_armor", "name": "Nano Armor (+Max HP & Armor)"},
	{"id": "thrusters", "name": "Ion Thrusters (+Move Speed)"},
	{"id": "magnet", "name": "Quantum Magnet (+Pickup Radius)"},
	{"id": "amp", "name": "Damage Amplifier (+20% Damage)"}
]

func _ready() -> void:
	layer = 60
	panel_root.visible = false
	_find_main_and_player()
	_setup_spawner_tab()
	_setup_upgrades_tab()
	_setup_timeline_tab()
	_setup_dps_tab()

func _find_main_and_player() -> void:
	var cur = get_tree().current_scene
	if cur:
		main_ref = cur
		player_ref = cur.get_node_or_null("Entities/Player")
		dps_meter_ref = cur.get_node_or_null("SandboxLayer/DPSMeter")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Toggle Sandbox on Tilde (` / ~) or F1
		if event.keycode == KEY_QUOTELEFT or event.keycode == KEY_F1 or event.keycode == KEY_ASCIITILDE:
			toggle_menu()

func toggle_menu() -> void:
	is_open = not is_open
	panel_root.visible = is_open
	if is_open:
		_find_main_and_player()
		_refresh_ui_from_state()

func _setup_spawner_tab() -> void:
	if opt_entity_type:
		opt_entity_type.clear()
		for n in ENTITY_NAMES:
			opt_entity_type.add_item(n)

	if chk_auto_spawning:
		chk_auto_spawning.toggled.connect(func(val):
			if main_ref and main_ref.has_method("toggle_spawning"):
				main_ref.toggle_spawning(val)
		)

	if btn_clear_enemies:
		btn_clear_enemies.pressed.connect(func():
			if main_ref and main_ref.has_method("clear_all_enemies"):
				main_ref.clear_all_enemies()
		)

	if btn_clear_props:
		btn_clear_props.pressed.connect(func():
			if main_ref and main_ref.has_method("clear_all_pickups_and_crates"):
				main_ref.clear_all_pickups_and_crates()
		)

	if btn_spawn:
		btn_spawn.pressed.connect(func():
			var sel = opt_entity_type.selected
			if sel >= 0 and sel < ENTITY_KEYS.size():
				var e_id = ENTITY_KEYS[sel]
				var count = int(spin_count.value)
				var at_mouse = chk_spawn_mouse.button_pressed
				if main_ref and main_ref.has_method("spawn_sandbox_entity"):
					main_ref.spawn_sandbox_entity(e_id, count, at_mouse)
		)

	if btn_quick_dummy:
		btn_quick_dummy.pressed.connect(func():
			if main_ref and main_ref.has_method("spawn_sandbox_entity"):
				main_ref.spawn_sandbox_entity("target_dummy", 1, false)
		)

func _setup_upgrades_tab() -> void:
	if btn_max_all:
		btn_max_all.pressed.connect(func():
			if player_ref and player_ref.has_method("max_all_upgrades"):
				player_ref.max_all_upgrades()
				_refresh_ui_from_state()
		)

	if btn_reset_all:
		btn_reset_all.pressed.connect(func():
			if player_ref and player_ref.has_method("reset_all_upgrades"):
				player_ref.reset_all_upgrades()
				_refresh_ui_from_state()
		)

	# Build weapon rows
	if weapons_container:
		for child in weapons_container.get_children():
			child.queue_free()

		for w in WEAPON_KEYS:
			var row = HBoxContainer.new()
			row.set_meta("w_id", w.id)

			var lbl = Label.new()
			lbl.text = w.name
			lbl.custom_minimum_size = Vector2(170, 0)
			row.add_child(lbl)

			var spin = SpinBox.new()
			spin.min_value = 0
			spin.max_value = 5
			spin.step = 1
			spin.custom_minimum_size = Vector2(65, 0)
			row.add_child(spin)

			var chk_evo = CheckBox.new()
			chk_evo.text = "⚡ Evo"
			row.add_child(chk_evo)

			spin.value_changed.connect(func(v):
				if player_ref and player_ref.has_method("set_weapon_level"):
					player_ref.set_weapon_level(w.id, int(v), chk_evo.button_pressed)
			)

			chk_evo.toggled.connect(func(v):
				if player_ref and player_ref.has_method("set_weapon_level"):
					player_ref.set_weapon_level(w.id, int(spin.value), v)
			)

			weapons_container.add_child(row)

	# Build passive rows
	if passives_container:
		for child in passives_container.get_children():
			child.queue_free()

		for p in PASSIVE_KEYS:
			var row = HBoxContainer.new()
			row.set_meta("p_id", p.id)

			var lbl = Label.new()
			lbl.text = p.name
			lbl.custom_minimum_size = Vector2(230, 0)
			row.add_child(lbl)

			var spin = SpinBox.new()
			spin.min_value = 0
			spin.max_value = 5
			spin.step = 1
			spin.custom_minimum_size = Vector2(65, 0)
			spin.value_changed.connect(func(v):
				if player_ref and player_ref.has_method("set_passive_level"):
					player_ref.set_passive_level(p.id, int(v))
			)
			row.add_child(spin)

			passives_container.add_child(row)

func _setup_timeline_tab() -> void:
	var jumps = [
		{"t": 0.0, "lbl": "00:00 Start"},
		{"t": 60.0, "lbl": "01:00 Scout Surge"},
		{"t": 105.0, "lbl": "01:45 Elite 1 (Gold)"},
		{"t": 120.0, "lbl": "02:00 Spitters/Brutes"},
		{"t": 210.0, "lbl": "03:30 Boss 1: Leviathan"},
		{"t": 300.0, "lbl": "05:00 Exploders Surge"},
		{"t": 330.0, "lbl": "05:30 Elite 2 (Purple)"},
		{"t": 420.0, "lbl": "07:00 Boss 2: Dreadnought"},
		{"t": 510.0, "lbl": "08:30 Apocalypse"},
		{"t": 600.0, "lbl": "10:00 Endless Mode"}
	]

	if timeline_grid:
		for child in timeline_grid.get_children():
			child.queue_free()

		for j in jumps:
			var btn = Button.new()
			btn.text = j.lbl
			btn.custom_minimum_size = Vector2(145, 32)
			btn.pressed.connect(func():
				if main_ref and main_ref.has_method("jump_to_time"):
					main_ref.jump_to_time(j.t)
			)
			timeline_grid.add_child(btn)

	if btn_jump_custom:
		btn_jump_custom.pressed.connect(func():
			if main_ref and main_ref.has_method("jump_to_time"):
				main_ref.jump_to_time(float(spin_custom_time.value))
		)

	if chk_godmode:
		chk_godmode.toggled.connect(func(v):
			if player_ref and player_ref.has_method("toggle_godmode"):
				player_ref.toggle_godmode(v)
		)

	if btn_restart_game:
		btn_restart_game.pressed.connect(func():
			if main_ref and main_ref.has_method("restart_match"):
				main_ref.restart_match()
				_refresh_ui_from_state()
		)

	if btn_exit_menu:
		btn_exit_menu.pressed.connect(func():
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		)

func _setup_dps_tab() -> void:
	if chk_show_dps:
		chk_show_dps.toggled.connect(func(v):
			if dps_meter_ref:
				dps_meter_ref.visible = v
		)

	if btn_reset_dps:
		btn_reset_dps.pressed.connect(func():
			if dps_meter_ref and dps_meter_ref.has_method("reset_stats"):
				dps_meter_ref.reset_stats()
		)

func _process(_delta: float) -> void:
	if is_open and tab_container.current_tab == 3: # DPS tab
		_update_dps_tab_info()

func _update_dps_tab_info() -> void:
	if not dps_meter_ref or not lbl_dps_info:
		return
	var cur_dps = dps_meter_ref.get("current_dps")
	var peak_dps = dps_meter_ref.get("peak_dps")
	var tot_dmg = dps_meter_ref.get("total_damage")
	var c_time = dps_meter_ref.get("combat_time")

	if cur_dps != null and peak_dps != null:
		lbl_dps_info.text = "⚡ Realtime DPS: %d\n🏆 Peak DPS: %d\n💥 Total Damage: %d\n⏱️ Combat Time: %.1fs" % [
			int(cur_dps), int(peak_dps), int(tot_dmg), c_time
		]

func _refresh_ui_from_state() -> void:
	if not player_ref:
		return

	# Refresh weapons UI
	if weapons_container and player_ref.get("weapon_levels"):
		var w_lvls = player_ref.weapon_levels
		var w_evos = player_ref.evolved_weapons
		for child in weapons_container.get_children():
			var w_id = child.get_meta("w_id", "")
			if w_lvls.has(w_id):
				var spin = child.get_node_or_null("@SpinBox@2") if not child.get_node_or_null("SpinBox") else child.get_node_or_null("SpinBox")
				if not spin:
					for c in child.get_children():
						if c is SpinBox: spin = c
				if spin: spin.set_value_no_signal(w_lvls[w_id])

				var chk = null
				for c in child.get_children():
					if c is CheckBox: chk = c
				if chk: chk.set_pressed_no_signal(w_evos.get(w_id, false))

	# Refresh passives UI
	if passives_container and player_ref.get("passive_levels"):
		var p_lvls = player_ref.passive_levels
		for child in passives_container.get_children():
			var p_id = child.get_meta("p_id", "")
			if p_lvls.has(p_id):
				var spin = null
				for c in child.get_children():
					if c is SpinBox: spin = c
				if spin: spin.set_value_no_signal(p_lvls[p_id])

	if chk_godmode:
		chk_godmode.set_pressed_no_signal(player_ref.is_invulnerable)

	if chk_auto_spawning and main_ref:
		chk_auto_spawning.set_pressed_no_signal(main_ref.is_spawning_enabled)
