extends Node2D

const PylonScene = preload("res://scenes/pylon.tscn")
const GemScene = preload("res://scenes/gem.tscn")
const CrateScene = preload("res://scenes/crate.tscn")
const BossScene = preload("res://scenes/boss.tscn")
const BossDreadnoughtScene = preload("res://scenes/boss_dreadnought.tscn")
const EliteScene = preload("res://scenes/elite_enemy.tscn")
const TargetDummyScene = preload("res://scenes/target_dummy.tscn")
const FieldPickupScene = preload("res://scenes/field_pickup.tscn")
const I18nClass = preload("res://scripts/i18n.gd")
const MainMenuClass = preload("res://scripts/ui/main_menu.gd")

@onready var arena: Node2D = $Arena
@onready var swarm_mgr: Node2D = $SwarmManager
@onready var player: CharacterBody2D = $Entities/Player
@onready var pylons_container: Node2D = $Entities/Pylons
@onready var entities_container: Node2D = $Entities
@onready var camera: Camera2D = $Camera2D
@onready var hud: CanvasLayer = $HUD
@onready var sound_mgr: Node = $SoundManager
@onready var post_process_rect: ColorRect = get_node_or_null("PostProcessLayer/PostProcessRect")
var post_material: ShaderMaterial = null

var shockwave_active: bool = false
var shockwave_progress: float = 0.0
var shockwave_speed: float = 2.4

var chromatic_timer: float = 0.0
var chromatic_duration: float = 0.0
var chromatic_max_intensity: float = 0.0

var vignette_timer: float = 0.0
var vignette_duration: float = 0.0
var vignette_max_intensity: float = 0.0

var total_kills: int = 0
var elapsed_time: float = 0.0
var spawn_timer: float = 0.0
var supply_drop_timer: float = 0.0

# Scripted Wave Director Flags
var surge_triggered: bool = false
var titans_triggered: bool = false
var spitters_triggered: bool = false
var exploders_triggered: bool = false
var boss_spawned: bool = false
var boss2_spawned: bool = false
var elite1_spawned: bool = false
var elite2_spawned: bool = false
var victory_triggered: bool = false
var is_endless_overtime: bool = false
var enrage_level: int = 0
var is_spawning_enabled: bool = true

# Combo Multikill System
var combo_count: int = 0
var combo_timer: float = 0.0
const COMBO_TIMEOUT: float = 2.2
var next_combo_milestone: int = 50

# Gem Object Pooling & Vampire Survivors Consolidation System
const MAX_GEM_POOL: int = 160
const MAX_ACTIVE_GEMS: int = 120
var gem_pool: Array[Node2D] = []
var active_gems: Array[Node2D] = []
var consolidated_super_gem: Node2D = null

func _ready() -> void:
	if post_process_rect and post_process_rect.material is ShaderMaterial:
		post_material = post_process_rect.material
	_setup_inputs_if_needed()
	_connect_signals()
	_spawn_pylons()
	_init_gem_pool()

	if MainMenuClass.is_sandbox_mode:
		_setup_sandbox_mode()
	else:
		_setup_normal_mode()

func _init_gem_pool() -> void:
	if not entities_container:
		return
	for i in range(MAX_GEM_POOL):
		var gem = GemScene.instantiate()
		gem.is_pooled = true
		gem.is_active = false
		gem.visible = false
		gem.set_process(false)
		entities_container.add_child(gem)
		gem.collected.connect(_on_gem_collected)
		gem_pool.append(gem)

func _setup_sandbox_mode() -> void:
	is_spawning_enabled = false
	_spawn_crates()
	if is_instance_valid(player):
		var dummy = TargetDummyScene.instantiate()
		dummy.global_position = player.global_position + Vector2(160.0, 0.0)
		entities_container.add_child(dummy)

	var dps = get_node_or_null("SandboxLayer/DPSMeter")
	if dps:
		dps.visible = true

	if hud:
		var btn = hud.get_node_or_null("TopBar/BtnSandbox")
		if btn:
			btn.visible = true

	var sb_menu = get_node_or_null("SandboxMenu")
	if sb_menu:
		var chk = sb_menu.get_node_or_null("Root/Panel/TabContainer/Spawner/VBox/HBoxSpawnToggle/ChkAutoSpawn")
		if chk:
			chk.button_pressed = false

	var ftm = get_node_or_null("FloatingTextManager")
	if ftm and is_instance_valid(player):
		ftm.spawn_text(player.global_position + Vector2(0, -60), "PHÒNG THÍ NGHIỆM: BẤM [F1] / [~]", Color(0.2, 3.8, 1.4, 1.0))

func _setup_normal_mode() -> void:
	is_spawning_enabled = true
	_spawn_crates()
	_spawn_initial_horde()

	var dps = get_node_or_null("SandboxLayer/DPSMeter")
	if dps:
		dps.visible = false

	if hud:
		var btn = hud.get_node_or_null("TopBar/BtnSandbox")
		if btn:
			btn.visible = false

func _spawn_pylons() -> void:
	if not pylons_container:
		return
	var count = 40
	for i in range(count):
		var pylon = PylonScene.instantiate()
		var p_pos = Vector2.ZERO
		while true:
			p_pos = Vector2(
				randf_range(-4400.0, 4400.0),
				randf_range(-4400.0, 4400.0)
			)
			if p_pos.length() > 380.0:
				break
		pylon.position = p_pos
		pylons_container.add_child(pylon)

func _spawn_crates() -> void:
	if not entities_container:
		return

	# 1. Starting Sector Crates (14 crates immediately visible around player)
	for i in range(14):
		var crate = CrateScene.instantiate()
		var angle = randf() * TAU
		var dist = randf_range(160.0, 600.0)
		crate.position = Vector2(cos(angle) * dist, sin(angle) * dist * 0.65)
		entities_container.add_child(crate)

	# 2. Arena Exploration Crates (85 crates across active radius)
	for i in range(85):
		var crate = CrateScene.instantiate()
		var angle = randf() * TAU
		var dist = randf_range(650.0, 3600.0)
		crate.position = Vector2(cos(angle) * dist, sin(angle) * dist * 0.7)
		entities_container.add_child(crate)

func vacuum_all_gems() -> void:
	if not is_instance_valid(player):
		return
	for g in active_gems:
		if is_instance_valid(g) and g.is_active and g.has_method("attract_to"):
			g.attract_to(player)

func _setup_inputs_if_needed() -> void:
	var bindings = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN]
	}
	for action in bindings.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for k in bindings[action]:
				var ev = InputEventKey.new()
				ev.keycode = k
				InputMap.action_add_event(action, ev)

func _connect_signals() -> void:
	player.health_changed.connect(hud.update_health)
	player.xp_changed.connect(hud.update_xp)
	player.leveled_up.connect(hud.show_level_up)
	player.player_died.connect(_on_player_died)
	hud.upgrade_selected.connect(player.apply_upgrade)

	swarm_mgr.enemy_killed.connect(_on_enemy_killed)
	swarm_mgr.swarm_count_changed.connect(hud.set_swarm_count)

func _spawn_initial_horde() -> void:
	for i in range(8):
		var angle = (TAU / 8.0) * float(i)
		var offset = Vector2(cos(angle) * 500.0, sin(angle) * 300.0)
		swarm_mgr.spawn_cluster(player.global_position + offset, 8, 0)

func _process(delta: float) -> void:
	if get_tree().paused:
		return

	elapsed_time += delta

	# Post-processing shader animations
	if shockwave_active and post_material:
		shockwave_progress += shockwave_speed * delta
		if shockwave_progress >= 1.0:
			shockwave_active = false
			shockwave_progress = 0.0
		post_material.set_shader_parameter("shockwave_progress", shockwave_progress)

	if chromatic_timer > 0.0 and post_material:
		chromatic_timer -= delta
		var p = clamp(chromatic_timer / max(0.001, chromatic_duration), 0.0, 1.0)
		post_material.set_shader_parameter("chromatic_aberration_intensity", chromatic_max_intensity * p)

	if vignette_timer > 0.0 and post_material:
		vignette_timer -= delta
		var p = clamp(vignette_timer / max(0.001, vignette_duration), 0.0, 1.0)
		post_material.set_shader_parameter("damage_vignette_intensity", vignette_max_intensity * p)

	# Combo decay
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_count = 0
			next_combo_milestone = _get_initial_combo_milestone()
			if hud and hud.has_method("update_combo"):
				hud.update_combo(0)

	# Periodic supply crate airdrop (Vampire Survivors paced supply cadence)
	supply_drop_timer += delta
	if supply_drop_timer >= 60.0:
		supply_drop_timer = 0.0
		_drop_supply_crate()

	# Camera follows player smoothly
	if is_instance_valid(player):
		camera.global_position = camera.global_position.lerp(player.global_position, 8.0 * delta)

	# --- 15-MINUTE EXPANDED WAVE DIRECTOR ---
	_process_spawn_director(delta)

func _drop_supply_crate() -> void:
	if not entities_container or not is_instance_valid(player):
		return
	var crate = CrateScene.instantiate()
	var angle = randf() * TAU
	var offset = Vector2(cos(angle) * 350.0, sin(angle) * 220.0)
	crate.position = player.global_position + offset
	entities_container.add_child(crate)
	if hud and hud.has_method("show_surge_warning"):
		hud.show_surge_warning(I18nClass.loc("alert_crate"))

func _process_spawn_director(delta: float) -> void:
	if not is_spawning_enabled:
		return
	spawn_timer += delta

	# Phase 1: 00:00 - 01:00 | Early Fast Swarm (Crawlers)
	if elapsed_time < 60.0:
		if elapsed_time < 30.0:
			if spawn_timer >= 0.65:
				spawn_timer = 0.0
				if swarm_mgr.active_count < 350:
					_spawn_wave_cluster(randi_range(20, 35), 0)
		else:
			if spawn_timer >= 0.50:
				spawn_timer = 0.0
				if swarm_mgr.active_count < 550:
					_spawn_wave_cluster(randi_range(30, 50), 0)

	# Phase 2: 01:00 - 02:00 | Scout Swarm Flankers & Surge & Elite 1
	elif elapsed_time < 120.0:
		if not surge_triggered:
			surge_triggered = true
			_trigger_swarm_surge()

		# Elite 1: 01:45 Giant Champion (Drops Treasure Chest 1)
		if elapsed_time >= 105.0 and not elite1_spawned:
			elite1_spawned = true
			_spawn_elite_enemy(1)

		if spawn_timer >= 0.45:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 1200:
				var e_type = 1 if randf() < 0.4 else 0
				_spawn_wave_cluster(randi_range(45, 80), e_type)

	# Phase 3: 02:00 - 03:30 | Toxic Spitters & Brutes
	elif elapsed_time < 210.0:
		if not spitters_triggered:
			spitters_triggered = true
			if hud.has_method("show_surge_warning"):
				hud.show_surge_warning(I18nClass.loc("alert_spitters"))

		if spawn_timer >= 0.40:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 2800:
				var roll = randf()
				var e_type = 3 if roll < 0.25 else (2 if roll < 0.35 else (1 if roll < 0.6 else 0))
				_spawn_wave_cluster(randi_range(80, 160), e_type)

	# Phase 4: 03:30 - 05:00 | Boss 1: Apex Leviathan
	elif elapsed_time < 300.0:
		if not boss_spawned:
			boss_spawned = true
			_spawn_boss_leviathan()

		if spawn_timer >= 0.38:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 3400:
				var roll = randf()
				var e_type = 3 if roll < 0.2 else (2 if roll < 0.35 else (1 if roll < 0.6 else 0))
				_spawn_wave_cluster(randi_range(100, 180), e_type)

	# Phase 5: 05:00 - 07:00 | Kamikaze Exploders Surge & Elite 2
	elif elapsed_time < 420.0:
		if not exploders_triggered:
			exploders_triggered = true
			if hud.has_method("show_surge_warning"):
				hud.show_surge_warning(I18nClass.loc("alert_exploders"))
			if sound_mgr and sound_mgr.has_method("play_alarm"):
				sound_mgr.play_alarm()

		# Elite 2: 05:30 Dread Champion (Drops Treasure Chest 3)
		if elapsed_time >= 330.0 and not elite2_spawned:
			elite2_spawned = true
			_spawn_elite_enemy(2)

		if spawn_timer >= 0.35:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 4000:
				var roll = randf()
				var e_type = 4 if roll < 0.35 else (3 if roll < 0.55 else (2 if roll < 0.7 else 0))
				_spawn_wave_cluster(randi_range(110, 200), e_type)

	# Phase 6: 07:00 - 08:30 | Boss 2: Cyber Dreadnought
	elif elapsed_time < 510.0:
		if not boss2_spawned:
			boss2_spawned = true
			_spawn_boss_dreadnought()

		if spawn_timer >= 0.32:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 4400:
				var e_type = randi() % 5
				_spawn_wave_cluster(randi_range(130, 230), e_type)

	# Phase 7: 08:30 - 10:00 | Full Apocalypse Swarm (All 5 Enemy Types)
	elif elapsed_time < 600.0:
		if not titans_triggered:
			titans_triggered = true
			_trigger_titan_wave()

		if spawn_timer >= 0.30:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 4800:
				var e_type = randi() % 5
				_spawn_wave_cluster(randi_range(150, 260), e_type)

	# Phase 8: 10:00+ | Victory / Endless Overtime Mode
	else:
		if not victory_triggered:
			victory_triggered = true
			is_endless_overtime = true
			if hud.has_method("show_surge_warning"):
				hud.show_surge_warning(I18nClass.loc("alert_win_15"))

		# Ramp Enrage level every 60 seconds in overtime
		var current_enrage = int((elapsed_time - 600.0) / 60.0) + 1
		if current_enrage > enrage_level:
			enrage_level = current_enrage
			if hud.has_method("show_surge_warning"):
				hud.show_surge_warning(I18nClass.loc("alert_enrage") % enrage_level)

		if spawn_timer >= 0.28:
			spawn_timer = 0.0
			if swarm_mgr.active_count < 5000:
				var e_type = randi() % 5
				_spawn_wave_cluster(randi_range(160, 280), e_type)

func _spawn_boss_leviathan() -> void:
	if not entities_container or not is_instance_valid(player):
		return
	if sound_mgr and sound_mgr.has_method("play_alarm"):
		sound_mgr.play_alarm()
	if hud and hud.has_method("show_surge_warning"):
		hud.show_surge_warning(I18nClass.loc("alert_leviathan"))
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.65)

	var boss = BossScene.instantiate()
	boss.global_position = player.global_position + Vector2(650.0, -100.0)
	entities_container.add_child(boss)

func _spawn_boss_dreadnought() -> void:
	if not entities_container or not is_instance_valid(player):
		return
	if sound_mgr and sound_mgr.has_method("play_alarm"):
		sound_mgr.play_alarm()
	if hud and hud.has_method("show_surge_warning"):
		hud.show_surge_warning(I18nClass.loc("alert_dreadnought"))
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.75)

	var boss = BossDreadnoughtScene.instantiate()
	boss.global_position = player.global_position + Vector2(-650.0, 100.0)
	entities_container.add_child(boss)

func _spawn_elite_enemy(tier: int) -> void:
	if not entities_container or not is_instance_valid(player):
		return
	if sound_mgr and sound_mgr.has_method("play_alarm"):
		sound_mgr.play_alarm()
	if hud and hud.has_method("show_surge_warning"):
		hud.show_surge_warning(I18nClass.loc("alert_elite"))
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.55)

	var elite = EliteScene.instantiate()
	var angle = randf() * TAU
	var spawn_pos = player.global_position + Vector2(cos(angle) * 700.0, sin(angle) * 450.0)
	spawn_pos.x = clamp(spawn_pos.x, -4700.0, 4700.0)
	spawn_pos.y = clamp(spawn_pos.y, -4700.0, 4700.0)
	elite.global_position = spawn_pos
	entities_container.add_child(elite)
	elite.setup(tier)

func _trigger_swarm_surge() -> void:
	if sound_mgr and sound_mgr.has_method("play_alarm"):
		sound_mgr.play_alarm()
	if hud.has_method("show_surge_warning"):
		hud.show_surge_warning(I18nClass.loc("alert_swarm"))
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.4)

	var ring_count = 350
	var player_pos = player.global_position if is_instance_valid(player) else Vector2.ZERO
	for i in range(ring_count):
		var angle = (TAU / float(ring_count)) * float(i)
		var spawn_pos = player_pos + Vector2(cos(angle) * 950.0, sin(angle) * 550.0)
		spawn_pos.x = clamp(spawn_pos.x, -4700.0, 4700.0)
		spawn_pos.y = clamp(spawn_pos.y, -4700.0, 4700.0)
		swarm_mgr.spawn_enemy(spawn_pos, 0)

func _trigger_titan_wave() -> void:
	if sound_mgr and sound_mgr.has_method("play_alarm"):
		sound_mgr.play_alarm()
	if hud.has_method("show_surge_warning"):
		hud.show_surge_warning(I18nClass.loc("alert_behemoth"))
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.45)

	var player_pos = player.global_position if is_instance_valid(player) else Vector2.ZERO
	for i in range(8):
		var angle = (TAU / 8.0) * float(i)
		var d = Vector2(cos(angle) * 750.0, sin(angle) * 450.0)
		swarm_mgr.spawn_enemy(player_pos + d, 2)

func _spawn_wave_cluster(count: int, enemy_type: int) -> void:
	if not is_instance_valid(player):
		return

	var angle = randf() * TAU
	var spawn_pos = player.global_position + Vector2(
		cos(angle) * randf_range(750.0, 950.0),
		sin(angle) * randf_range(420.0, 520.0)
	)
	spawn_pos.x = clamp(spawn_pos.x, -4700.0, 4700.0)
	spawn_pos.y = clamp(spawn_pos.y, -4700.0, 4700.0)

	swarm_mgr.spawn_cluster(spawn_pos, count, enemy_type)

func _on_gem_collected(gem: Node2D) -> void:
	if gem == consolidated_super_gem:
		consolidated_super_gem = null
	active_gems.erase(gem)
	if not gem_pool.has(gem):
		gem_pool.append(gem)

func register_gem(gem: Node2D) -> void:
	if not active_gems.has(gem):
		active_gems.append(gem)
	if not gem.collected.is_connected(_on_gem_collected):
		gem.collected.connect(_on_gem_collected)

func spawn_gem(pos: Vector2, xp_val: int, is_boss: bool) -> void:
	# 1. Fast reverse check on recent gems to merge clusters within 65px
	var check_count = min(active_gems.size(), 20)
	for i in range(active_gems.size() - 1, active_gems.size() - 1 - check_count, -1):
		var g = active_gems[i]
		if is_instance_valid(g) and g.is_active and g.target == null:
			if g.global_position.distance_squared_to(pos) <= 4225.0: # 65px
				g.xp_value += xp_val
				if is_boss:
					g.is_super_gem = true
				g.queue_redraw()
				return

	# 2. Vampire Survivors style Gem Consolidation if active gems hit cap (120 gems)
	if active_gems.size() >= MAX_ACTIVE_GEMS:
		if not is_instance_valid(consolidated_super_gem) or not consolidated_super_gem.is_active or consolidated_super_gem.target != null:
			# Pick the gem furthest from player to become the red super gem
			var best_idx = 0
			var max_dist_sq = 0.0
			var p_pos = player.global_position if is_instance_valid(player) else Vector2.ZERO
			for i in range(min(active_gems.size(), 20)):
				var cand = active_gems[i]
				if is_instance_valid(cand) and cand.is_active and cand.target == null:
					var d_sq = cand.global_position.distance_squared_to(p_pos)
					if d_sq > max_dist_sq:
						max_dist_sq = d_sq
						best_idx = i
			if best_idx < active_gems.size():
				consolidated_super_gem = active_gems[best_idx]
				consolidated_super_gem.is_super_gem = true

		if is_instance_valid(consolidated_super_gem) and consolidated_super_gem.is_active:
			consolidated_super_gem.xp_value += xp_val
			consolidated_super_gem.queue_redraw()
			return

	# 3. Pull from pre-allocated Gem Object Pool (zero instantiate overhead)
	var gem: Node2D = null
	while not gem_pool.is_empty():
		var cand = gem_pool.pop_back()
		if is_instance_valid(cand):
			gem = cand
			break

	if not gem:
		gem = GemScene.instantiate()
		gem.is_pooled = true
		entities_container.add_child(gem)
		gem.collected.connect(_on_gem_collected)

	gem.activate(pos, xp_val, is_boss)
	active_gems.append(gem)

func _get_initial_combo_milestone() -> int:
	if elapsed_time < 90.0:
		return 50
	elif elapsed_time < 240.0:
		return 100
	else:
		return 200

func _on_enemy_killed(xp_val: int, pos: Vector2, is_boss: bool) -> void:
	total_kills += 1
	hud.set_kills(total_kills)

	combo_count += 1
	combo_timer = COMBO_TIMEOUT
	if hud and hud.has_method("update_combo"):
		hud.update_combo(combo_count)

	if combo_count >= next_combo_milestone:
		_trigger_combo_announcement(combo_count)
		if combo_count >= 2000:
			next_combo_milestone += 1000
		elif combo_count >= 1000:
			next_combo_milestone += 500
		elif combo_count >= 500:
			next_combo_milestone = 1000
		elif combo_count >= 250:
			next_combo_milestone = 500
		elif combo_count >= 100:
			next_combo_milestone = 250
		elif combo_count >= 50:
			next_combo_milestone = 100
		else:
			next_combo_milestone = 50

	# Spawn Gem with cluster consolidation
	if randf() < 0.45 or is_boss:
		spawn_gem(pos, xp_val, is_boss)

func _trigger_combo_announcement(streak: int) -> void:
	var title = I18nClass.loc("streak_50", "⚡ %d COMBO! ⚡") % streak
	var col = Color(0.4, 0.85, 1.0, 1.0)

	if streak >= 3000:
		title = I18nClass.loc("streak_3000", "🌌 %d TRANSCENDENCE! 🌌") % streak
		col = Color(0.9, 0.4, 1.0, 1.0)
	elif streak >= 2000:
		title = I18nClass.loc("streak_2000", "⚡ %d EXTINCTION EVENT! ⚡") % streak
		col = Color(0.2, 1.0, 0.85, 1.0)
	elif streak >= 1000:
		title = I18nClass.loc("streak_1000", "👑 %d GODLIKE MASSACRE! 👑") % streak
		col = Color(1.0, 0.85, 0.2, 1.0)
	elif streak >= 500:
		title = I18nClass.loc("streak_500", "💀 %d UNSTOPPABLE! 💀") % streak
		col = Color(1.0, 0.2, 0.6, 1.0)
	elif streak >= 250:
		title = I18nClass.loc("streak_250", "💥 %d RAMPAGE! 💥") % streak
		col = Color(1.0, 0.4, 0.15, 1.0)
	elif streak >= 100:
		title = I18nClass.loc("streak_100", "🔥 %d ULTRA KILL! 🔥") % streak
		col = Color(0.3, 0.9, 1.0, 1.0)

	if hud and hud.has_method("show_combo_milestone"):
		hud.show_combo_milestone(title, col)

func _on_player_died() -> void:
	hud.show_game_over(player.level, elapsed_time, total_kills)

func trigger_shockwave(world_pos: Vector2, force: float = 0.045) -> void:
	if not post_material or not is_instance_valid(camera):
		return
	var viewport = get_viewport()
	if not viewport: return
	var screen_pos = camera.get_screen_center_position()
	var vp_size = viewport.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	var diff = (world_pos - screen_pos) * camera.zoom
	var screen_uv = Vector2(0.5, 0.5) + (diff / vp_size)
	screen_uv.x = clamp(screen_uv.x, 0.0, 1.0)
	screen_uv.y = clamp(screen_uv.y, 0.0, 1.0)
	post_material.set_shader_parameter("shockwave_center", screen_uv)
	post_material.set_shader_parameter("shockwave_force", force)
	shockwave_active = true
	shockwave_progress = 0.01

func trigger_chromatic_aberration_pulse(intensity: float = 0.03, duration: float = 0.2) -> void:
	if not post_material: return
	chromatic_max_intensity = intensity
	chromatic_duration = max(0.001, duration)
	chromatic_timer = chromatic_duration

func trigger_damage_vignette(intensity: float = 0.65, duration: float = 0.25) -> void:
	if not post_material: return
	vignette_max_intensity = intensity
	vignette_duration = max(0.001, duration)
	vignette_timer = vignette_duration

# ==========================================
# 🛠️ SANDBOX MODE CONTROLLER API 🛠️
# ==========================================

func toggle_spawning(enabled: bool) -> void:
	is_spawning_enabled = enabled

func clear_all_enemies() -> void:
	if swarm_mgr and swarm_mgr.has_method("clear_all"):
		swarm_mgr.clear_all()

	# Free all bosses and elites (except immortal target dummies)
	var bosses = get_tree().get_nodes_in_group("boss")
	for b in bosses:
		if is_instance_valid(b) and not b.is_in_group("target_dummies"):
			b.queue_free()

func clear_all_pickups_and_crates() -> void:
	var crates = get_tree().get_nodes_in_group("crates")
	for c in crates:
		if is_instance_valid(c): c.queue_free()

	for g in active_gems:
		if is_instance_valid(g):
			if g.is_pooled:
				g.deactivate()
				if not gem_pool.has(g):
					gem_pool.append(g)
			else:
				g.queue_free()
	active_gems.clear()
	consolidated_super_gem = null

	var pickups = get_tree().get_nodes_in_group("field_pickups")
	for p in pickups:
		if is_instance_valid(p): p.queue_free()

	var chests = get_tree().get_nodes_in_group("treasure_chests")
	for ch in chests:
		if is_instance_valid(ch): ch.queue_free()

func jump_to_time(target_seconds: float) -> void:
	target_seconds = max(0.0, target_seconds)
	elapsed_time = target_seconds

	surge_triggered = (target_seconds >= 60.0)
	elite1_spawned = (target_seconds >= 105.0)
	spitters_triggered = (target_seconds >= 120.0)
	boss_spawned = (target_seconds >= 210.0)
	exploders_triggered = (target_seconds >= 300.0)
	elite2_spawned = (target_seconds >= 330.0)
	boss2_spawned = (target_seconds >= 420.0)
	titans_triggered = (target_seconds >= 510.0)
	victory_triggered = (target_seconds >= 600.0)
	is_endless_overtime = (target_seconds >= 600.0)

	if hud and hud.has_method("update_time"):
		hud.update_time(elapsed_time)

func restart_match() -> void:
	elapsed_time = 0.0
	total_kills = 0
	combo_count = 0
	combo_timer = 0.0
	next_combo_milestone = _get_initial_combo_milestone()
	supply_drop_timer = 0.0

	surge_triggered = false
	titans_triggered = false
	spitters_triggered = false
	exploders_triggered = false
	boss_spawned = false
	boss2_spawned = false
	elite1_spawned = false
	elite2_spawned = false
	victory_triggered = false
	is_endless_overtime = false
	enrage_level = 0

	clear_all_enemies()
	clear_all_pickups_and_crates()

	if is_instance_valid(player):
		player.global_position = Vector2.ZERO
		player.current_health = player.max_health
		player.is_invulnerable = false
		player.invuln_timer = 0.0
		player.health_changed.emit(player.current_health, player.max_health)

	if MainMenuClass.is_sandbox_mode:
		_setup_sandbox_mode()
	else:
		_spawn_crates()
		_spawn_initial_horde()

	if hud:
		if hud.has_method("set_kills"): hud.set_kills(0)
		if hud.has_method("update_time"): hud.update_time(0.0)
		if hud.has_method("update_combo"): hud.update_combo(0)

func spawn_sandbox_entity(e_type: String, count: int, at_mouse: bool = false) -> void:
	count = clampi(count, 1, 1000)
	var origin = get_global_mouse_position() if at_mouse else (player.global_position if is_instance_valid(player) else Vector2.ZERO)

	for i in range(count):
		var offset = Vector2.ZERO
		if count > 1 or not at_mouse:
			var angle = (TAU / float(count)) * float(i) if count > 1 else randf() * TAU
			var dist = randf_range(80.0, 240.0) if count > 1 else randf_range(120.0, 220.0)
			offset = Vector2(cos(angle) * dist, sin(angle) * dist * 0.65)
		var spawn_pos = origin + offset

		match e_type:
			"crawler":
				swarm_mgr.spawn_enemy(spawn_pos, 0)
			"scout":
				swarm_mgr.spawn_enemy(spawn_pos, 1)
			"brute":
				swarm_mgr.spawn_enemy(spawn_pos, 2)
			"spitter":
				swarm_mgr.spawn_enemy(spawn_pos, 3)
			"exploder":
				swarm_mgr.spawn_enemy(spawn_pos, 4)
			"elite_tier1":
				var elite = EliteScene.instantiate()
				elite.global_position = spawn_pos
				entities_container.add_child(elite)
				elite.setup(1)
			"elite_tier2":
				var elite = EliteScene.instantiate()
				elite.global_position = spawn_pos
				entities_container.add_child(elite)
				elite.setup(2)
			"boss_leviathan":
				var b = BossScene.instantiate()
				b.global_position = spawn_pos
				entities_container.add_child(b)
			"boss_dreadnought":
				var b = BossDreadnoughtScene.instantiate()
				b.global_position = spawn_pos
				entities_container.add_child(b)
			"target_dummy":
				var dummy = TargetDummyScene.instantiate()
				dummy.global_position = spawn_pos
				entities_container.add_child(dummy)
			"crate":
				var c = CrateScene.instantiate()
				c.global_position = spawn_pos
				entities_container.add_child(c)
			"gem_regular":
				spawn_gem(spawn_pos, 15, false)
			"gem_super":
				spawn_gem(spawn_pos, 80, true)
			"pickup_nuke", "pickup_vacuum", "pickup_medkit", "pickup_overclock":
				var p_name = e_type.replace("pickup_", "")
				var pickup = FieldPickupScene.instantiate()
				pickup.setup(p_name)
				pickup.global_position = spawn_pos
				entities_container.add_child(pickup)
