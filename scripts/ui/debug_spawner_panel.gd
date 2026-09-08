class_name DebugSpawnerPanel
extends PanelContainer

## Debug Spawner Panel for All Dungeon Monsters
## Supports Swordsman, Archer, Mage, Slime, Orc, and Spider.
## Provides individual spawn buttons, hotkeys (1-6, V, C, G, H), AI toggles, and live stats.

const SkeletonEnemyClass = preload("res://scripts/enemies/skeleton/skeleton_enemy.gd")
const SlimeEnemyClass = preload("res://scripts/enemies/slime/slime_enemy.gd")
const OrcEnemyClass = preload("res://scripts/enemies/orc/orc_enemy.gd")
const SpiderEnemyClass = preload("res://scripts/enemies/spider/spider_enemy.gd")

@onready var count_label: Label = $Margin/VBox/CountLabel
@onready var spawn_cursor_check: CheckBox = $Margin/VBox/OptionsHBox/SpawnAtCursorCheck
@onready var passive_dummy_check: CheckBox = $Margin/VBox/OptionsHBox2/PassiveDummyCheck
@onready var god_mode_check: CheckBox = $Margin/VBox/OptionsHBox2/GodModeCheck
@onready var player_hp_bar: ProgressBar = $Margin/VBox/PlayerHPHBox/ProgressBar
@onready var player_hp_label: Label = $Margin/VBox/PlayerHPHBox/HPValueLabel

var player_ref: CharacterBody2D = null

func _ready() -> void:
	_disable_focus_recursive(self)

	var btn_vbox = $Margin/VBox/ButtonsVBox
	if btn_vbox.has_node("BtnSwordsman"):
		btn_vbox.get_node("BtnSwordsman").pressed.connect(_on_spawn_swordsman_pressed)
	if btn_vbox.has_node("BtnArcher"):
		btn_vbox.get_node("BtnArcher").pressed.connect(_on_spawn_archer_pressed)
	if btn_vbox.has_node("BtnMage"):
		btn_vbox.get_node("BtnMage").pressed.connect(_on_spawn_mage_pressed)
	if btn_vbox.has_node("BtnSlime"):
		btn_vbox.get_node("BtnSlime").pressed.connect(_on_spawn_slime_pressed)
	if btn_vbox.has_node("BtnOrc"):
		btn_vbox.get_node("BtnOrc").pressed.connect(_on_spawn_orc_pressed)
	if btn_vbox.has_node("BtnSpider"):
		btn_vbox.get_node("BtnSpider").pressed.connect(_on_spawn_spider_pressed)
	if btn_vbox.has_node("BtnHorde"):
		btn_vbox.get_node("BtnHorde").pressed.connect(_on_spawn_horde_pressed)
	if btn_vbox.has_node("BtnClear"):
		btn_vbox.get_node("BtnClear").pressed.connect(_on_clear_all_pressed)

	god_mode_check.toggled.connect(_on_god_mode_toggled)

	_hook_player()

func _disable_focus_recursive(node: Node) -> void:
	if node is Control:
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_disable_focus_recursive(child)

func _hook_player() -> void:
	if not is_instance_valid(player_ref):
		var cur = get_tree().current_scene
		if cur:
			player_ref = cur.get_node_or_null("Player") as CharacterBody2D
		if is_instance_valid(player_ref) and player_ref.has_signal("hp_changed"):
			if not player_ref.hp_changed.is_connected(_on_player_hp_changed):
				player_ref.hp_changed.connect(_on_player_hp_changed)
			if "hp" in player_ref and "max_hp" in player_ref:
				_update_hp_display(player_ref.hp, player_ref.max_hp)

func _process(_delta: float) -> void:
	if not is_instance_valid(player_ref):
		_hook_player()

	_update_counter()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B or event.keycode == KEY_QUOTELEFT:
			visible = not visible
		elif event.keycode == KEY_1 or event.keycode == KEY_Z:
			spawn_skeleton(SkeletonEnemyClass.Type.SWORDSMAN)
		elif event.keycode == KEY_2 or event.keycode == KEY_X:
			spawn_skeleton(SkeletonEnemyClass.Type.ARCHER)
		elif event.keycode == KEY_3:
			spawn_skeleton(SkeletonEnemyClass.Type.MAGE)
		elif event.keycode == KEY_4:
			spawn_slime()
		elif event.keycode == KEY_5:
			spawn_orc()
		elif event.keycode == KEY_6:
			spawn_spider()
		elif event.keycode == KEY_C:
			_on_clear_all_pressed()
		elif event.keycode == KEY_V:
			_on_spawn_horde_pressed()
		elif event.keycode == KEY_G:
			god_mode_check.button_pressed = not god_mode_check.button_pressed
		elif event.keycode == KEY_H:
			if is_instance_valid(player_ref):
				player_ref.hp = player_ref.max_hp
				player_ref.hp_changed.emit(player_ref.hp, player_ref.max_hp)

func _update_counter() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var swordsmen = 0
	var archers = 0
	var mages = 0
	var slimes = 0
	var orcs = 0
	var spiders = 0

	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e is SkeletonEnemyClass:
			if int(e.skeleton_type) == 0:
				swordsmen += 1
			elif int(e.skeleton_type) == 1:
				archers += 1
			elif int(e.skeleton_type) == 2:
				mages += 1
		elif e is SlimeEnemyClass:
			slimes += 1
		elif e is OrcEnemyClass:
			orcs += 1
		elif e is SpiderEnemyClass:
			spiders += 1

	if count_label:
		count_label.text = "Enemies: %d (⚔️%d 🏹%d 🔮%d 🟢%d 🪓%d 🕷️%d)" % [
			enemies.size(), swordsmen, archers, mages, slimes, orcs, spiders
		]

func _on_player_hp_changed(cur_hp: float, max_h: float) -> void:
	_update_hp_display(cur_hp, max_h)

func _update_hp_display(cur_hp: float, max_h: float) -> void:
	if player_hp_bar:
		player_hp_bar.max_value = max_h
		player_hp_bar.value = cur_hp
	if player_hp_label:
		player_hp_label.text = "%d / %d" % [int(round(cur_hp)), int(round(max_h))]

func _on_god_mode_toggled(toggled_on: bool) -> void:
	if is_instance_valid(player_ref) and "is_god_mode" in player_ref:
		player_ref.is_god_mode = toggled_on
		if toggled_on:
			player_ref.hp = player_ref.max_hp
			_update_hp_display(player_ref.hp, player_ref.max_hp)

func _get_spawn_position() -> Vector2:
	if spawn_cursor_check and spawn_cursor_check.button_pressed:
		var mouse_screen_pos = get_viewport().get_mouse_position()
		var panel_rect = get_global_rect()
		if not panel_rect.has_point(mouse_screen_pos):
			var cam = get_viewport().get_camera_2d()
			if cam:
				return cam.get_global_mouse_position()
			return get_global_mouse_position()

	if is_instance_valid(player_ref):
		var p_facing = player_ref.facing_vector if "facing_vector" in player_ref else Vector2.DOWN
		var offset = p_facing * randf_range(80.0, 130.0) + Vector2(randf_range(-35.0, 35.0), randf_range(-25.0, 25.0))
		return player_ref.global_position + offset
	return Vector2.ZERO

func _get_entity_parent() -> Node2D:
	var root = get_tree().current_scene
	if not root:
		return null
	var ysort = root.get_node_or_null("YSortEntities") as Node2D
	return ysort if ysort else root

func spawn_skeleton(type: int, pos: Vector2 = Vector2.ZERO) -> Node2D:
	var parent = _get_entity_parent()
	if not parent:
		return null
	if pos == Vector2.ZERO:
		pos = _get_spawn_position()

	var skeleton = SkeletonEnemyClass.new()
	skeleton.skeleton_type = type
	skeleton.is_dummy = passive_dummy_check.button_pressed if passive_dummy_check else false
	skeleton.global_position = pos
	parent.add_child(skeleton)
	_spawn_birth_vfx(pos, Color(0.25, 0.95, 0.45, 0.85) if type != 2 else Color(0.70, 0.30, 0.95, 0.85))
	return skeleton

func spawn_slime(pos: Vector2 = Vector2.ZERO) -> Node2D:
	var parent = _get_entity_parent()
	if not parent:
		return null
	if pos == Vector2.ZERO:
		pos = _get_spawn_position()

	var slime = SlimeEnemyClass.new()
	slime.is_dummy = passive_dummy_check.button_pressed if passive_dummy_check else false
	slime.global_position = pos
	parent.add_child(slime)
	_spawn_birth_vfx(pos, Color(0.25, 0.85, 0.45, 0.85))
	return slime

func spawn_orc(pos: Vector2 = Vector2.ZERO) -> Node2D:
	var parent = _get_entity_parent()
	if not parent:
		return null
	if pos == Vector2.ZERO:
		pos = _get_spawn_position()

	var orc = OrcEnemyClass.new()
	orc.is_dummy = passive_dummy_check.button_pressed if passive_dummy_check else false
	orc.global_position = pos
	parent.add_child(orc)
	_spawn_birth_vfx(pos, Color(0.40, 0.55, 0.25, 0.85))
	return orc

func spawn_spider(pos: Vector2 = Vector2.ZERO) -> Node2D:
	var parent = _get_entity_parent()
	if not parent:
		return null
	if pos == Vector2.ZERO:
		pos = _get_spawn_position()

	var spider = SpiderEnemyClass.new()
	spider.is_dummy = passive_dummy_check.button_pressed if passive_dummy_check else false
	spider.global_position = pos
	parent.add_child(spider)
	_spawn_birth_vfx(pos, Color(0.35, 0.95, 0.20, 0.85))
	return spider

func _spawn_birth_vfx(pos: Vector2, col: Color = Color(0.25, 0.95, 0.45, 0.85)) -> void:
	var root = get_tree().current_scene
	if not root:
		return

	var emitter = CPUParticles2D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.amount = 20
	emitter.lifetime = 0.40
	emitter.explosiveness = 0.90
	emitter.spread = 180.0
	emitter.gravity = Vector2(0, -30)
	emitter.initial_velocity_min = 40.0
	emitter.initial_velocity_max = 120.0
	emitter.scale_amount_min = 2.0
	emitter.scale_amount_max = 4.0
	emitter.color = col
	emitter.position = pos
	root.add_child(emitter)
	emitter.finished.connect(emitter.queue_free)
	emitter.restart()
	emitter.emitting = true

func _on_spawn_swordsman_pressed() -> void:
	spawn_skeleton(SkeletonEnemyClass.Type.SWORDSMAN)

func _on_spawn_archer_pressed() -> void:
	spawn_skeleton(SkeletonEnemyClass.Type.ARCHER)

func _on_spawn_mage_pressed() -> void:
	spawn_skeleton(SkeletonEnemyClass.Type.MAGE)

func _on_spawn_slime_pressed() -> void:
	spawn_slime()

func _on_spawn_orc_pressed() -> void:
	spawn_orc()

func _on_spawn_spider_pressed() -> void:
	spawn_spider()

func _on_spawn_horde_pressed() -> void:
	var base_p = _get_spawn_position()
	# Spawn a full monster encounter: 1 of each type
	spawn_skeleton(SkeletonEnemyClass.Type.SWORDSMAN, base_p + Vector2(-30, -20))
	spawn_skeleton(SkeletonEnemyClass.Type.ARCHER, base_p + Vector2(30, -20))
	spawn_skeleton(SkeletonEnemyClass.Type.MAGE, base_p + Vector2(0, -50))
	spawn_slime(base_p + Vector2(-40, 20))
	spawn_orc(base_p + Vector2(0, 30))
	spawn_spider(base_p + Vector2(40, 20))

func _on_clear_all_pressed() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()

	# Also clear any lingering projectiles or puddles
	var puddles = get_tree().get_nodes_in_group("puddles")
	for p in puddles:
		if is_instance_valid(p):
			p.queue_free()
