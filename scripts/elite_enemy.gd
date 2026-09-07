extends CharacterBody2D

const SpriteFactory = preload("res://scripts/sprite_factory.gd")
const TREASURE_CHEST_SCENE = preload("res://scenes/treasure_chest.tscn")
const GEM_SCENE = preload("res://scenes/gem.tscn")

signal elite_defeated()

@export var tier: int = 1
@export var max_health: float = 1200.0
var current_health: float = 1200.0
var hit_radius: float = 36.0
var move_speed: float = 160.0
var contact_damage: float = 28.0

var hurt_flash_timer: float = 0.0
var walk_anim: float = 0.0
var pulse_time: float = 0.0

var player_ref: CharacterBody2D = null
var sound_mgr: Node = null
var particle_mgr: Node2D = null
var camera_node: Camera2D = null

static var elite_tex: ImageTexture = null

func _ready() -> void:
	add_to_group("boss") # Allows all weapons and targeting systems to lock on and damage it
	if not elite_tex:
		elite_tex = SpriteFactory.create_brute_texture()
	_get_managers()
	queue_redraw()

func setup(p_tier: int) -> void:
	tier = p_tier
	if tier == 1:
		max_health = 1200.0 # 20x+ regular monster HP
		move_speed = 165.0
		contact_damage = 25.0
	else:
		max_health = 3500.0 # 20x+ late-game monster HP
		move_speed = 185.0
		contact_damage = 35.0
	current_health = max_health

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		player_ref = cur.get_node_or_null("Entities/Player")
		sound_mgr = cur.get_node_or_null("SoundManager")
		particle_mgr = cur.get_node_or_null("ParticleManager")
		camera_node = cur.get_node_or_null("Camera2D")

func _physics_process(delta: float) -> void:
	pulse_time += delta
	walk_anim += delta * 6.0

	if hurt_flash_timer > 0.0:
		hurt_flash_timer -= delta

	if not player_ref or not is_instance_valid(player_ref):
		_get_managers()
		if not player_ref:
			return

	var p_pos = player_ref.global_position
	var to_player = p_pos - global_position
	var dist = to_player.length()

	var move_dir = Vector2(to_player.x, to_player.y * 0.75).normalized()
	velocity = velocity.move_toward(move_dir * move_speed, 900.0 * delta)
	move_and_slide()

	# Contact damage to player
	if dist < 42.0 and player_ref.has_method("take_damage"):
		player_ref.take_damage(contact_damage * delta * 2.0)

	queue_redraw()

func take_damage(amount: float) -> void:
	current_health = max(0.0, current_health - amount)
	hurt_flash_timer = 0.12

	var cur = get_tree().current_scene
	var txt_mgr = cur.get_node_or_null("FloatingTextManager") if cur else null
	if txt_mgr and randf() < 0.35:
		txt_mgr.spawn_damage(global_position + Vector2(randf_range(-15, 15), randf_range(-40, -10)), amount, true)

	if current_health <= 0.0:
		_die()

var is_dead: bool = false

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	elite_defeated.emit()

	if sound_mgr and sound_mgr.has_method("play_crate_break"):
		sound_mgr.play_crate_break()
	if sound_mgr and sound_mgr.has_method("play_nuke"):
		sound_mgr.play_nuke()

	if camera_node and camera_node.has_method("add_trauma"):
		camera_node.add_trauma(0.45)

	if particle_mgr:
		particle_mgr.spawn_shockwave_ring(global_position, Color(3.8, 2.5, 0.4, 1.0), 90.0)
		particle_mgr.spawn_shockwave_debris(global_position, 80.0, 24)
		particle_mgr.spawn_blood_burst(global_position, Color(3.8, 1.8, 0.2, 1.0), 20)

	var entities = get_parent()

	# 100% GUARANTEED TREASURE CHEST DROP
	var chest = TREASURE_CHEST_SCENE.instantiate()
	chest.global_position = global_position
	entities.call_deferred("add_child", chest)

	# Super EXP Gems
	var cur = get_tree().current_scene
	if cur and cur.has_method("spawn_gem"):
		for g in range(6):
			var a = (TAU / 6.0) * float(g)
			cur.spawn_gem(global_position + Vector2(cos(a) * 45.0, sin(a) * 30.0), 60, true)
	else:
		for g in range(6):
			var gem = GEM_SCENE.instantiate()
			gem.xp_value = 60
			gem.is_super_gem = true
			var a = (TAU / 6.0) * float(g)
			gem.global_position = global_position + Vector2(cos(a) * 45.0, sin(a) * 30.0)
			entities.call_deferred("add_child", gem)

	queue_free()

func _draw() -> void:
	# 1. Radiant Golden / Neon Pulsating Aura (Signifies Elite Champion)
	var pulse = sin(pulse_time * 5.0) * 0.25 + 0.75
	var aura_col = Color(3.8 * pulse, 2.4 * pulse, 0.3 * pulse, 0.35) if tier == 1 else Color(3.0 * pulse, 0.4 * pulse, 3.8 * pulse, 0.35)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, 48.0 * pulse, 0.0, TAU, 32, aura_col, 4.0)
	draw_circle(Vector2.ZERO, 45.0 * pulse, Color(aura_col.r, aura_col.g, aura_col.b, 0.08))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 2. 3x Sized Hull / Sprite
	if elite_tex:
		var col = Color(4.0, 4.0, 4.0, 1.0) if hurt_flash_timer > 0.0 else Color.WHITE
		var flip = 1.0 if (player_ref and player_ref.global_position.x > global_position.x) else -1.0
		var wobble = sin(walk_anim) * 2.5
		draw_set_transform(Vector2(0.0, wobble), 0.0, Vector2(flip * 1.8, 1.8))
		draw_texture(elite_tex, Vector2(-36.0, -54.0), col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 3. Floating Health Bar
	var bar_w = 64.0
	var bar_h = 6.0
	var bar_pos = Vector2(-bar_w * 0.5, -95.0)
	var hp_pct = clamp(current_health / max(1.0, max_health), 0.0, 1.0)

	# Bar Background & Border
	draw_rect(Rect2(bar_pos.x - 1, bar_pos.y - 1, bar_w + 2, bar_h + 2), Color(0.0, 0.0, 0.0, 0.75))
	draw_rect(Rect2(bar_pos.x, bar_pos.y, bar_w, bar_h), Color(0.2, 0.05, 0.05, 0.85))
	# Bar Fill (Golden / Neon)
	var fill_col = Color(3.5, 2.2, 0.2, 1.0) if tier == 1 else Color(2.8, 0.5, 3.5, 1.0)
	draw_rect(Rect2(bar_pos.x, bar_pos.y, bar_w * hp_pct, bar_h), fill_col)
