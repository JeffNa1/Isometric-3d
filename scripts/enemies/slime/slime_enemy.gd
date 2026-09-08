class_name SlimeEnemy
extends CharacterBody2D

## Small Translucent Caustic Slime Enemy
## - Squishy squash-and-stretch hopping locomotion
## - 2.5D jumping physics with height-dependent ground shadow
## - High-speed Leap Tackle attack (parryable)
## - Translucent caustic visuals & gelatinous wobble physics

const SlimeVisualRendererClass = preload("res://scripts/enemies/slime/slime_2d_visual_renderer.gd")
const FloatingDamage = preload("res://scripts/combat/floating_damage.gd")
const IsoUtils = preload("res://scripts/core/iso_utils.gd")

enum Dir8 { E = 0, SE = 1, S = 2, SW = 3, W = 4, NW = 5, N = 6, NE = 7 }
enum State { IDLE, HOPPING, WINDUP, LEAP_TACKLE, STAGGER, STUNNED, DEAD }

@export var is_dummy: bool = false

var max_hp: float = 30.0
var hp: float = 30.0
var move_speed: float = 140.0
var current_dir: Dir8 = Dir8.S
var facing_vector: Vector2 = Vector2.DOWN
var state: State = State.IDLE

# Locomotion & Leap Timers
var hop_timer: float = 0.0
var hop_interval: float = 0.65
var hop_progress: float = 0.0
var is_in_hop: bool = false
var hop_dir: Vector2 = Vector2.DOWN

var leap_cooldown: float = 0.0
var windup_timer: float = 0.0
var windup_duration: float = 0.35
var leap_timer: float = 0.0
var leap_duration: float = 0.45
var leap_dir: Vector2 = Vector2.DOWN
var has_hit_in_leap: bool = false

var z_height: float = 0.0
var wobble_energy: float = 0.0
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

	# Collision Capsule
	collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 11.0
	collision_shape.shape = circle
	collision_shape.position = Vector2(0.0, -3.0)
	add_child(collision_shape)

	# 2.5D SubViewport & Procedural Pixel Renderer
	pixel_viewport = SubViewport.new()
	pixel_viewport.name = "SlimePixelViewport"
	pixel_viewport.size = Vector2i(128, 128)
	pixel_viewport.transparent_bg = true
	pixel_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(pixel_viewport)

	visual_renderer = SlimeVisualRendererClass.new()
	visual_renderer.name = "Slime2DVisualRenderer"
	visual_renderer.position = Vector2(64.0, 92.0)
	pixel_viewport.add_child(visual_renderer)

	pixel_sprite = Sprite2D.new()
	pixel_sprite.name = "PixelatedSlimeSprite"
	pixel_sprite.texture = pixel_viewport.get_texture()
	pixel_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pixel_sprite.position = Vector2(0.0, -28.0)
	add_child(pixel_sprite)

	_setup_hp_bar()

func _setup_hp_bar() -> void:
	hp_bar_node = Node2D.new()
	hp_bar_node.position = Vector2(0.0, -36.0)
	hp_bar_node.visible = false
	add_child(hp_bar_node)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if leap_cooldown > 0.0:
		leap_cooldown -= delta
	if wobble_energy > 0.0:
		wobble_energy = move_toward(wobble_energy, 0.0, delta * 2.2)

	_find_player()

	if is_dummy:
		velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
		move_and_slide()
		_update_visuals(delta, false, 0.0, false, 0.0, 0.0)
		return

	match state:
		State.IDLE, State.HOPPING:
			_process_locomotion(delta)
		State.WINDUP:
			_process_windup(delta)
		State.LEAP_TACKLE:
			_process_leap(delta)
		State.STAGGER:
			stagger_timer -= delta
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			move_and_slide()
			_update_visuals(delta, false, 0.0, false, 0.0, 0.0)
			if stagger_timer <= 0.0:
				state = State.IDLE
		State.STUNNED:
			_process_stun(delta)

func _process_stun(delta: float) -> void:
	stun_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
	move_and_slide()
	_update_visuals(delta, false, 0.0, false, 0.0, 0.0)

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
		if d < 30.0 and d > 0.001:
			sep += (diff / d) * ((30.0 - d) / 30.0) * 140.0

	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == self or not is_instance_valid(enemy):
			continue
		var diff = global_position - enemy.global_position
		var d = diff.length()
		if d < 24.0 and d > 0.001:
			sep += (diff / d) * ((24.0 - d) / 24.0) * 120.0

	return sep

func _process_locomotion(delta: float) -> void:
	if not is_instance_valid(target_player):
		velocity = velocity.move_toward(Vector2.ZERO, 1000.0 * delta)
		move_and_slide()
		_update_visuals(delta, false, 0.0, false, 0.0, 0.0)
		return

	var to_player = target_player.global_position - global_position
	var dist = to_player.length()
	var dir_to_player = to_player.normalized()
	var sep_vel = _get_separation_velocity()

	current_dir = _get_dir8_from_vector(dir_to_player)
	facing_vector = _get_vector_from_dir8(current_dir)

	# Trigger Leap Tackle when within 85px
	if dist <= 85.0 and leap_cooldown <= 0.0:
		_start_leap_windup()
		return

	# Hopping locomotion
	hop_timer += delta
	if not is_in_hop and hop_timer >= hop_interval:
		# Start a new hop
		is_in_hop = true
		hop_progress = 0.0
		hop_dir = (dir_to_player * move_speed) + sep_vel

	if is_in_hop:
		hop_progress += delta * 2.8
		var arc = sin(clampf(hop_progress, 0.0, 1.0) * PI)
		z_height = arc * 14.0

		if hop_progress < 1.0:
			velocity = hop_dir * (0.6 + arc * 0.7)
			move_and_slide()
			_update_visuals(delta, true, 1.0, false, 0.0, z_height, hop_dir)
		else:
			# Finished hop, land on ground
			is_in_hop = false
			hop_timer = 0.0
			z_height = 0.0
			wobble_energy = 0.75
			velocity = Vector2.ZERO
			_update_visuals(delta, false, 0.0, false, 0.0, 0.0)
	else:
		z_height = 0.0
		velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
		move_and_slide()
		_update_visuals(delta, false, 0.0, false, 0.0, 0.0)

func _start_leap_windup() -> void:
	state = State.WINDUP
	windup_timer = 0.0
	velocity = Vector2.ZERO
	z_height = 0.0
	wobble_energy = 1.0

	if is_instance_valid(target_player):
		var dir_to_p = (target_player.global_position - global_position).normalized()
		current_dir = _get_dir8_from_vector(dir_to_p)
		facing_vector = _get_vector_from_dir8(current_dir)
		leap_dir = dir_to_p

func _process_windup(delta: float) -> void:
	windup_timer += delta
	velocity = Vector2.ZERO
	z_height = 0.0
	var w_prog = clampf(windup_timer / windup_duration, 0.0, 1.0)
	_update_visuals(delta, false, 0.0, false, 0.0, 0.0, leap_dir, true, w_prog)

	if windup_timer >= windup_duration:
		_start_leap()

func _start_leap() -> void:
	state = State.LEAP_TACKLE
	leap_timer = 0.0
	has_hit_in_leap = false
	if is_instance_valid(target_player):
		leap_dir = (target_player.global_position - global_position).normalized()
		current_dir = _get_dir8_from_vector(leap_dir)
		facing_vector = _get_vector_from_dir8(current_dir)
	velocity = leap_dir * 330.0

func _process_leap(delta: float) -> void:
	leap_timer += delta
	var prog = clampf(leap_timer / leap_duration, 0.0, 1.0)
	var arc = sin(prog * PI)
	z_height = arc * 28.0 # High jump arc

	move_and_slide()

	# Damage collision check during mid-flight
	if not has_hit_in_leap and prog >= 0.25 and prog <= 0.85:
		_check_leap_hit()

	_update_visuals(delta, false, 0.0, true, prog, z_height, leap_dir, false, 0.0)

	if leap_timer >= leap_duration:
		# Landing
		state = State.IDLE
		z_height = 0.0
		wobble_energy = 1.2
		leap_cooldown = 1.65
		velocity = Vector2.ZERO

func _check_leap_hit() -> void:
	if not is_instance_valid(target_player):
		return

	var dist = (target_player.global_position - global_position).length()
	if dist <= 38.0:
		has_hit_in_leap = true
		var hit_res = target_player.take_damage(12.0, leap_dir, true, self)
		if hit_res == "PARRIED":
			# Parried: slime rebounds and is stunned!
			state = State.STUNNED
			velocity = -leap_dir * 180.0
			z_height = 0.0
			wobble_energy = 1.8
			apply_stun(1.3)

func take_damage(amount: float, knockback_dir: Vector2) -> void:
	if state == State.DEAD:
		return

	hp -= amount
	hp_bar_node.visible = true
	_update_hp_bar_visual()

	pixel_sprite.modulate = Color(2.5, 0.5, 0.5, 1.0)
	var tween = create_tween()
	tween.tween_property(pixel_sprite, "modulate", Color.WHITE, 0.14)

	velocity = knockback_dir * 280.0
	wobble_energy = 1.5
	if state != State.STUNNED:
		state = State.STAGGER
		stagger_timer = 0.18

	_spawn_floating_damage(amount)

	if hp <= 0.0:
		_die()

func apply_stun(duration: float = 1.0) -> void:
	if state == State.DEAD:
		return

	state = State.STUNNED
	stun_timer = maxf(stun_timer, duration)
	velocity = Vector2.ZERO
	z_height = 0.0
	wobble_energy = 1.2

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
	halo.position = Vector2(0.0, -32.0)
	add_child(halo)
	stun_halo_node = halo

func _update_hp_bar_visual() -> void:
	for child in hp_bar_node.get_children():
		child.queue_free()

	var bg = ColorRect.new()
	bg.size = Vector2(22.0, 4.0)
	bg.position = Vector2(-11.0, 0.0)
	bg.color = Color(0.1, 0.1, 0.1, 0.85)
	hp_bar_node.add_child(bg)

	var fill = ColorRect.new()
	var pct = clampf(hp / max_hp, 0.0, 1.0)
	fill.size = Vector2(20.0 * pct, 2.0)
	fill.position = Vector2(-10.0, 1.0)
	fill.color = Color(0.2, 0.85, 0.35, 0.95)
	hp_bar_node.add_child(fill)

func _spawn_floating_damage(amount: float) -> void:
	FloatingDamage.spawn(get_parent(), global_position, amount, Color(1.0, 0.90, 0.35, 1.0), -42.0, 13)

func _die() -> void:
	state = State.DEAD
	collision_shape.set_deferred("disabled", true)
	hp_bar_node.visible = false
	if is_instance_valid(stun_halo_node):
		stun_halo_node.queue_free()
		stun_halo_node = null

	# Slime Splatter Burst
	var emitter = CPUParticles2D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.amount = 24
	emitter.lifetime = 0.45
	emitter.explosiveness = 0.92
	emitter.spread = 180.0
	emitter.gravity = Vector2(0, 140)
	emitter.initial_velocity_min = 50.0
	emitter.initial_velocity_max = 140.0
	emitter.scale_amount_min = 2.0
	emitter.scale_amount_max = 5.0
	emitter.color = Color(0.22, 0.85, 0.42, 0.90)
	emitter.position = global_position + Vector2(0.0, -10.0)
	get_parent().add_child(emitter)
	emitter.finished.connect(emitter.queue_free)
	emitter.restart()
	emitter.emitting = true

	var tween = create_tween()
	tween.tween_property(pixel_sprite, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)

func _update_visuals(
	delta: float,
	moving: bool,
	speed_rat: float,
	leaping: bool,
	leap_prog: float,
	height: float,
	move_vec: Vector2 = Vector2.ZERO,
	windup: bool = false,
	w_prog: float = 0.0
) -> void:
	if visual_renderer:
		visual_renderer.update_state(
			delta, current_dir, moving, speed_rat,
			leaping, leap_prog, height, wobble_energy,
			move_vec, windup, w_prog
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
			var pt = Vector2(cos(a) * 10.0, sin(a) * 4.0)
			draw_circle(pt, 2.0, Color(2.4, 2.0, 0.4, 1.0))
			draw_circle(pt, 1.0, Color(1.0, 1.0, 1.0, 1.0))
