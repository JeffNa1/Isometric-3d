class_name OrcEnemy
extends CharacterBody2D

## Heavy Meaty Orc Warrior
## - 180 HP, Slow 110 px/s lumbering movement
## - Giant Cleaver Overhead Slam (45 DMG)
## - 0.45s Windup Telegraph & 0.35s Cleaver-stuck Recovery
## - Parryable (1.8s Stun & Counter Opening)

const OrcVisualRendererClass = preload("res://scripts/enemies/orc/orc_2d_visual_renderer.gd")
const FloatingDamage = preload("res://scripts/combat/floating_damage.gd")
const IsoUtils = preload("res://scripts/core/iso_utils.gd")

enum Dir8 { E = 0, SE = 1, S = 2, SW = 3, W = 4, NW = 5, N = 6, NE = 7 }
enum State { IDLE, CHASE, ATTACK, RECOVERY, STAGGER, STUNNED, DEAD }

@export var is_dummy: bool = false

var max_hp: float = 180.0
var hp: float = 180.0
var move_speed: float = 110.0
var current_dir: Dir8 = Dir8.S
var facing_vector: Vector2 = Vector2.DOWN
var state: State = State.IDLE

# Combat Timers
var attack_cooldown: float = 0.0
var attack_timer: float = 0.0
var attack_duration: float = 0.50
var recovery_timer: float = 0.0
var recovery_duration: float = 0.35
var has_dealt_damage: bool = false

var stun_timer: float = 0.0
var stun_halo_node: Node2D = null
var stagger_timer: float = 0.0

# Node References
var visual_renderer: Node2D = null
var pixel_viewport: SubViewport = null
var pixel_sprite: Sprite2D = null
var collision_shape: CollisionShape2D = null
var hp_bar_node: Node2D = null
var target_player: CharacterBody2D = null

func _ready() -> void:
	add_to_group("enemies")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 4 # Enemies
	collision_mask = 1 | 2 | 4 # Walls, Player, Other Enemies

	collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 16.0 # Bigger body
	collision_shape.shape = circle
	collision_shape.position = Vector2(0.0, -4.0)
	add_child(collision_shape)

	# 2.5D SubViewport & Procedural Pixel Renderer
	pixel_viewport = SubViewport.new()
	pixel_viewport.name = "OrcPixelViewport"
	pixel_viewport.size = Vector2i(160, 160)
	pixel_viewport.transparent_bg = true
	pixel_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(pixel_viewport)

	visual_renderer = OrcVisualRendererClass.new()
	visual_renderer.name = "Orc2DVisualRenderer"
	visual_renderer.position = Vector2(80.0, 115.0)
	pixel_viewport.add_child(visual_renderer)

	pixel_sprite = Sprite2D.new()
	pixel_sprite.name = "PixelatedOrcSprite"
	pixel_sprite.texture = pixel_viewport.get_texture()
	pixel_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pixel_sprite.position = Vector2(0.0, -35.0)
	add_child(pixel_sprite)

	_setup_hp_bar()

func _setup_hp_bar() -> void:
	hp_bar_node = Node2D.new()
	hp_bar_node.position = Vector2(0.0, -56.0)
	hp_bar_node.visible = false
	add_child(hp_bar_node)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	_find_player()

	if is_dummy:
		velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
		move_and_slide()
		_update_visuals(delta, false, 0.0, false, 0.0, 0.50)
		return

	match state:
		State.IDLE, State.CHASE:
			_process_locomotion(delta)
		State.ATTACK:
			_process_attack(delta)
		State.RECOVERY:
			_process_recovery(delta)
		State.STAGGER:
			stagger_timer -= delta
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			move_and_slide()
			_update_visuals(delta, false, 0.0, false, 0.0, 0.50)
			if stagger_timer <= 0.0:
				state = State.IDLE
		State.STUNNED:
			_process_stun(delta)

func _process_stun(delta: float) -> void:
	stun_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
	move_and_slide()
	_update_visuals(delta, false, 0.0, false, 0.0, 0.50)

	if stun_timer <= 0.0:
		state = State.IDLE
		if is_instance_valid(stun_halo_node):
			stun_halo_node.queue_free()
			stun_halo_node = null

func _find_player() -> void:
	if not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0 and players[0] is CharacterBody2D:
			target_player = players[0] as CharacterBody2D
		else:
			var cur = get_tree().current_scene
			if cur:
				target_player = cur.get_node_or_null("Player") as CharacterBody2D

func _get_separation_velocity() -> Vector2:
	var sep = Vector2.ZERO
	if is_instance_valid(target_player):
		var diff = global_position - target_player.global_position
		var d = diff.length()
		if d < 38.0 and d > 0.001:
			sep += (diff / d) * ((38.0 - d) / 38.0) * 160.0

	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == self or not is_instance_valid(enemy):
			continue
		var diff = global_position - enemy.global_position
		var d = diff.length()
		if d < 36.0 and d > 0.001:
			sep += (diff / d) * ((36.0 - d) / 36.0) * 140.0

	return sep

func _process_locomotion(delta: float) -> void:
	if not is_instance_valid(target_player):
		velocity = velocity.move_toward(Vector2.ZERO, 1000.0 * delta)
		move_and_slide()
		_update_visuals(delta, false, 0.0, false, 0.0, 0.50)
		return

	var to_player = target_player.global_position - global_position
	var dist = to_player.length()
	var dir_to_player = to_player.normalized()
	var sep_vel = _get_separation_velocity()

	current_dir = _get_dir8_from_vector(dir_to_player)
	facing_vector = _get_vector_from_dir8(current_dir)

	var slam_trigger_range = 56.0
	if dist <= slam_trigger_range and attack_cooldown <= 0.0:
		_start_cleaver_slam()
		return

	# March towards player
	var target_vel = (dir_to_player * move_speed) + sep_vel
	velocity = velocity.move_toward(target_vel, 1100.0 * delta)
	move_and_slide()

	var is_moving = velocity.length_squared() > 100.0
	var speed_rat = clampf(velocity.length() / move_speed, 0.0, 1.0)
	_update_visuals(delta, is_moving, speed_rat, false, 0.0, 0.50, velocity.normalized())

func _start_cleaver_slam() -> void:
	state = State.ATTACK
	attack_duration = 0.92
	attack_timer = 0.92
	has_dealt_damage = false

	if is_instance_valid(target_player):
		var dir_to_p = (target_player.global_position - global_position).normalized()
		current_dir = _get_dir8_from_vector(dir_to_p)
		facing_vector = _get_vector_from_dir8(current_dir)

	velocity = Vector2.ZERO

func _process_attack(delta: float) -> void:
	attack_timer -= delta
	var prog = 1.0 - (attack_timer / attack_duration)

	# Active slam impact window (at the exact moment the cleaver strikes floor, t = 0.54 - 0.64)
	if not has_dealt_damage and prog >= 0.54 and prog <= 0.64:
		_check_cleaver_hit()

	_update_visuals(delta, false, 0.0, true, attack_timer, attack_duration)

	if attack_timer <= 0.0:
		state = State.IDLE
		attack_cooldown = 1.8
		velocity = Vector2.ZERO

func _check_cleaver_hit() -> void:
	has_dealt_damage = true

	# Ground slam impact VFX
	_spawn_ground_slam_vfx()

	if not is_instance_valid(target_player):
		return

	var to_player = target_player.global_position - global_position
	var dist = to_player.length()
	var reach = 68.0

	if dist <= reach:
		var dot = facing_vector.dot(to_player.normalized())
		if dot >= 0.25: # Wide 150° frontal arc
			var hit_res = target_player.take_damage(45.0, facing_vector, true, self)
			if hit_res == "PARRIED":
				# Parried! Orc takes massive clang and gets stunned
				state = State.STUNNED
				apply_stun(1.8)
				velocity = -facing_vector * 160.0

func _process_recovery(delta: float) -> void:
	recovery_timer -= delta
	velocity = Vector2.ZERO
	_update_visuals(delta, false, 0.0, true, 0.0, attack_duration)

	if recovery_timer <= 0.0:
		state = State.IDLE
		attack_cooldown = 1.8

func _spawn_ground_slam_vfx() -> void:
	var root = get_parent()
	if not root:
		return

	var slam_pos = global_position + facing_vector * 26.0

	# Stone Debris particles
	var emitter = CPUParticles2D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.amount = 18
	emitter.lifetime = 0.40
	emitter.explosiveness = 0.95
	emitter.spread = 180.0
	emitter.gravity = Vector2(0, 160)
	emitter.initial_velocity_min = 60.0
	emitter.initial_velocity_max = 180.0
	emitter.scale_amount_min = 2.0
	emitter.scale_amount_max = 5.0
	emitter.color = Color(0.45, 0.42, 0.38, 1.0)
	emitter.position = slam_pos
	root.add_child(emitter)
	emitter.finished.connect(emitter.queue_free)
	emitter.restart()
	emitter.emitting = true

func take_damage(amount: float, knockback_dir: Vector2) -> void:
	if state == State.DEAD:
		return

	hp -= amount
	hp_bar_node.visible = true
	_update_hp_bar_visual()

	pixel_sprite.modulate = Color(2.5, 0.4, 0.4, 1.0)
	var tween = create_tween()
	tween.tween_property(pixel_sprite, "modulate", Color.WHITE, 0.14)

	# Orc has high poise, lower knockback
	velocity = knockback_dir * 160.0
	if state != State.STUNNED and state != State.ATTACK:
		state = State.STAGGER
		stagger_timer = 0.15

	_spawn_floating_damage(amount)

	if hp <= 0.0:
		_die()

func apply_stun(duration: float = 1.0) -> void:
	if state == State.DEAD:
		return

	state = State.STUNNED
	stun_timer = maxf(stun_timer, duration)
	velocity = Vector2.ZERO

	if pixel_sprite:
		pixel_sprite.modulate = Color(2.4, 2.0, 0.4, 1.0)
		var tween = create_tween()
		tween.tween_property(pixel_sprite, "modulate", Color.WHITE, 0.20)

	_spawn_stun_halo(duration)

func _spawn_stun_halo(_duration: float) -> void:
	if is_instance_valid(stun_halo_node):
		stun_halo_node.queue_free()
		stun_halo_node = null

	var halo = StunHaloEffect.new()
	halo.position = Vector2(0.0, -56.0)
	add_child(halo)
	stun_halo_node = halo

func _update_hp_bar_visual() -> void:
	for child in hp_bar_node.get_children():
		child.queue_free()

	var bg = ColorRect.new()
	bg.size = Vector2(30.0, 5.0)
	bg.position = Vector2(-15.0, 0.0)
	bg.color = Color(0.1, 0.1, 0.1, 0.85)
	hp_bar_node.add_child(bg)

	var fill = ColorRect.new()
	var pct = clampf(hp / max_hp, 0.0, 1.0)
	fill.size = Vector2(28.0 * pct, 3.0)
	fill.position = Vector2(-14.0, 1.0)
	fill.color = Color(0.9, 0.2, 0.15, 0.95)
	hp_bar_node.add_child(fill)

func _spawn_floating_damage(amount: float) -> void:
	FloatingDamage.spawn(get_parent(), global_position, amount, Color(1.0, 0.90, 0.35, 1.0), -68.0, 14)

func _die() -> void:
	state = State.DEAD
	collision_shape.set_deferred("disabled", true)
	hp_bar_node.visible = false
	if is_instance_valid(stun_halo_node):
		stun_halo_node.queue_free()
		stun_halo_node = null

	var emitter = CPUParticles2D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.amount = 32
	emitter.lifetime = 0.55
	emitter.explosiveness = 0.92
	emitter.spread = 180.0
	emitter.gravity = Vector2(0, 140)
	emitter.initial_velocity_min = 60.0
	emitter.initial_velocity_max = 160.0
	emitter.scale_amount_min = 3.0
	emitter.scale_amount_max = 6.0
	emitter.color = Color(0.35, 0.48, 0.25, 1.0)
	emitter.position = global_position + Vector2(0.0, -20.0)
	get_parent().add_child(emitter)
	emitter.finished.connect(emitter.queue_free)
	emitter.restart()
	emitter.emitting = true

	var tween = create_tween()
	tween.tween_property(pixel_sprite, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)

func _update_visuals(
	delta: float,
	moving: bool,
	speed_rat: float,
	attacking: bool,
	att_tim: float,
	att_dur: float,
	move_vec: Vector2 = Vector2.ZERO
) -> void:
	if visual_renderer:
		visual_renderer.update_state(
			delta, current_dir, moving, speed_rat,
			attacking, att_tim, att_dur, move_vec
		)

func _get_dir8_from_vector(v: Vector2) -> Dir8:
	return IsoUtils.get_dir8_from_vector(v) as Dir8

func _get_vector_from_dir8(dir: Dir8) -> Vector2:
	return IsoUtils.get_vector_from_dir8(dir as int)

class StunHaloEffect extends Node2D:
	var t: float = 0.0
	func _process(delta: float) -> void:
		t += delta * 7.5
		queue_redraw()
	func _draw() -> void:
		for i in range(3):
			var a = t + (i * TAU / 3.0)
			var pt = Vector2(cos(a) * 14.0, sin(a) * 5.0)
			draw_circle(pt, 2.5, Color(2.4, 2.0, 0.4, 1.0))
			draw_circle(pt, 1.2, Color(1.0, 1.0, 1.0, 1.0))
