class_name SpiderEnemy
extends CharacterBody2D

## Fast Skittering Toxic Spider Enemy
## - 50 HP, 215 px/s rapid 8-legged crawl
## - Ranged Venom Spit (Slows player 50% & leaves toxic acid puddle)
## - Parryable projectile & melee bite
## - Bioluminescent toxic markings & 2.5D articulated legs

const SpiderVisualRendererClass = preload("res://scripts/enemies/spider/spider_2d_visual_renderer.gd")
const VenomSpitProjectileClass = preload("res://scripts/combat/projectiles/venom_spit_projectile.gd")
const FloatingDamage = preload("res://scripts/combat/floating_damage.gd")
const IsoUtils = preload("res://scripts/core/iso_utils.gd")

enum Dir8 { E = 0, SE = 1, S = 2, SW = 3, W = 4, NW = 5, N = 6, NE = 7 }
enum State { IDLE, CHASE, KITE, SPIT, BITE, STAGGER, STUNNED, DEAD }

@export var is_dummy: bool = false

var max_hp: float = 50.0
var hp: float = 50.0
var move_speed: float = 215.0
var current_dir: Dir8 = Dir8.S
var facing_vector: Vector2 = Vector2.DOWN
var state: State = State.IDLE

# Combat Timers
var spit_cooldown: float = 0.0
var spit_timer: float = 0.0
var spit_duration: float = 0.45
var bite_cooldown: float = 0.0
var bite_timer: float = 0.0
var bite_duration: float = 0.32
var bite_has_hit: bool = false

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
	circle.radius = 14.0
	collision_shape.shape = circle
	collision_shape.position = Vector2(0.0, -3.0)
	add_child(collision_shape)

	# 2.5D SubViewport & Procedural Pixel Renderer
	pixel_viewport = SubViewport.new()
	pixel_viewport.name = "SpiderPixelViewport"
	pixel_viewport.size = Vector2i(144, 144)
	pixel_viewport.transparent_bg = true
	pixel_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(pixel_viewport)

	visual_renderer = SpiderVisualRendererClass.new()
	visual_renderer.name = "Spider2DVisualRenderer"
	visual_renderer.position = Vector2(72.0, 102.0)
	pixel_viewport.add_child(visual_renderer)

	pixel_sprite = Sprite2D.new()
	pixel_sprite.name = "PixelatedSpiderSprite"
	pixel_sprite.texture = pixel_viewport.get_texture()
	pixel_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pixel_sprite.position = Vector2(0.0, -32.0)
	add_child(pixel_sprite)

	_setup_hp_bar()

func _setup_hp_bar() -> void:
	hp_bar_node = Node2D.new()
	hp_bar_node.position = Vector2(0.0, -44.0)
	hp_bar_node.visible = false
	add_child(hp_bar_node)

func _update_visuals(
	delta: float,
	moving: bool,
	speed_rat: float,
	spitting: bool,
	s_tim: float,
	s_dur: float,
	biting: bool = false,
	b_tim: float = 0.0,
	b_dur: float = 0.32
) -> void:
	if visual_renderer:
		visual_renderer.update_state(
			delta, current_dir, moving, speed_rat,
			spitting, s_tim, s_dur,
			biting, b_tim, b_dur,
			velocity
		)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if spit_cooldown > 0.0:
		spit_cooldown -= delta
	if bite_cooldown > 0.0:
		bite_cooldown -= delta

	_find_player()

	if is_dummy:
		velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
		move_and_slide()
		_update_visuals(delta, false, 0.0, false, 0.0, 0.45)
		return

	match state:
		State.IDLE, State.CHASE, State.KITE:
			_process_locomotion(delta)
		State.SPIT:
			_process_spit(delta)
		State.BITE:
			_process_bite(delta)
		State.STAGGER:
			stagger_timer -= delta
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			move_and_slide()
			_update_visuals(delta, false, 0.0, false, 0.0, 0.45)
			if stagger_timer <= 0.0:
				state = State.IDLE
		State.STUNNED:
			_process_stun(delta)

func _process_stun(delta: float) -> void:
	stun_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
	move_and_slide()
	_update_visuals(delta, false, 0.0, false, 0.0, 0.45)

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
		if d < 34.0 and d > 0.001:
			sep += (diff / d) * ((34.0 - d) / 34.0) * 160.0

	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == self or not is_instance_valid(enemy):
			continue
		var diff = global_position - enemy.global_position
		var d = diff.length()
		if d < 30.0 and d > 0.001:
			sep += (diff / d) * ((30.0 - d) / 30.0) * 140.0

	return sep

func _process_locomotion(delta: float) -> void:
	if not is_instance_valid(target_player):
		velocity = velocity.move_toward(Vector2.ZERO, 1000.0 * delta)
		move_and_slide()
		_update_visuals(delta, false, 0.0, false, 0.0, 0.45)
		return

	var to_player = target_player.global_position - global_position
	var dist = to_player.length()
	var dir_to_player = to_player.normalized()
	var sep_vel = _get_separation_velocity()

	current_dir = _get_dir8_from_vector(dir_to_player)
	facing_vector = _get_vector_from_dir8(current_dir)

	var min_kite = 130.0
	var max_spit = 280.0

	# Melee bite defense if player rushes into spider
	if dist <= 38.0 and bite_cooldown <= 0.0:
		_start_bite()
		return

	if dist < min_kite:
		# Kite away skittering
		state = State.KITE
		var kite_dir = -dir_to_player
		var target_vel = (kite_dir * move_speed) + sep_vel
		velocity = velocity.move_toward(target_vel, 1400.0 * delta)
		move_and_slide()

		var is_moving = velocity.length_squared() > 100.0
		var speed_rat = clampf(velocity.length() / move_speed, 0.0, 1.0)
		_update_visuals(delta, is_moving, speed_rat, false, 0.0, 0.45)

	elif dist <= max_spit:
		# In spitting range
		var target_vel = sep_vel
		velocity = velocity.move_toward(target_vel, 1600.0 * delta)
		move_and_slide()

		if spit_cooldown <= 0.0:
			_start_spit()
			return
		else:
			_update_visuals(delta, false, 0.0, false, 0.0, 0.45)

	else:
		# Chase closer
		state = State.CHASE
		var target_vel = (dir_to_player * move_speed) + sep_vel
		velocity = velocity.move_toward(target_vel, 1300.0 * delta)
		move_and_slide()

		var is_moving = velocity.length_squared() > 100.0
		var speed_rat = clampf(velocity.length() / move_speed, 0.0, 1.0)
		_update_visuals(delta, is_moving, speed_rat, false, 0.0, 0.45)

func _start_bite() -> void:
	state = State.BITE
	bite_timer = 0.0
	bite_has_hit = false
	bite_cooldown = 1.4
	velocity = Vector2.ZERO
	if is_instance_valid(target_player):
		var dir_to_p = (target_player.global_position - global_position).normalized()
		current_dir = _get_dir8_from_vector(dir_to_p)
		facing_vector = _get_vector_from_dir8(current_dir)

func _process_bite(delta: float) -> void:
	bite_timer += delta
	velocity = Vector2.ZERO
	_update_visuals(delta, false, 0.0, false, 0.0, 0.45, true, bite_timer, bite_duration)

	if not bite_has_hit and bite_timer >= 0.14:
		bite_has_hit = true
		if is_instance_valid(target_player):
			var dist = (target_player.global_position - global_position).length()
			if dist <= 46.0:
				var hit_res = target_player.take_damage(14.0, facing_vector, true, self)
				if hit_res == "PARRIED":
					state = State.STUNNED
					apply_stun(1.3)
					velocity = -facing_vector * 150.0
					return
				else:
					if target_player.has_method("apply_slow"):
						target_player.apply_slow(0.5, 2.0)

	if bite_timer >= bite_duration:
		state = State.IDLE

func _start_spit() -> void:
	state = State.SPIT
	spit_timer = 0.0
	velocity = Vector2.ZERO

	if is_instance_valid(target_player):
		var dir_to_p = (target_player.global_position - global_position).normalized()
		current_dir = _get_dir8_from_vector(dir_to_p)
		facing_vector = _get_vector_from_dir8(current_dir)

func _process_spit(delta: float) -> void:
	spit_timer += delta
	velocity = Vector2.ZERO

	if is_instance_valid(target_player):
		var dir_to_p = (target_player.global_position - global_position).normalized()
		current_dir = _get_dir8_from_vector(dir_to_p)
		facing_vector = _get_vector_from_dir8(current_dir)

	_update_visuals(delta, false, 0.0, true, spit_timer, spit_duration)

	if spit_timer >= spit_duration:
		_release_venom()
		state = State.IDLE
		spit_cooldown = 2.4

func _release_venom() -> void:
	var root = get_parent()
	if not root or not is_instance_valid(target_player):
		return

	var spawn_pos = global_position + Vector2(0.0, -12.0)
	var shoot_dir = (target_player.global_position - global_position).normalized()

	var venom = VenomSpitProjectileClass.new()
	root.add_child(venom)
	venom.setup(spawn_pos, shoot_dir, 18.0)

func take_damage(amount: float, knockback_dir: Vector2) -> void:
	if state == State.DEAD:
		return

	hp -= amount
	hp_bar_node.visible = true
	_update_hp_bar_visual()

	pixel_sprite.modulate = Color(2.5, 0.4, 0.4, 1.0)
	var tween = create_tween()
	tween.tween_property(pixel_sprite, "modulate", Color.WHITE, 0.14)

	velocity = knockback_dir * 240.0
	if state != State.STUNNED:
		state = State.STAGGER
		stagger_timer = 0.16

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
	halo.position = Vector2(0.0, -42.0)
	add_child(halo)
	stun_halo_node = halo

func _update_hp_bar_visual() -> void:
	for child in hp_bar_node.get_children():
		child.queue_free()

	var bg = ColorRect.new()
	bg.size = Vector2(24.0, 4.0)
	bg.position = Vector2(-12.0, 0.0)
	bg.color = Color(0.1, 0.1, 0.1, 0.85)
	hp_bar_node.add_child(bg)

	var fill = ColorRect.new()
	var pct = clampf(hp / max_hp, 0.0, 1.0)
	fill.size = Vector2(22.0 * pct, 2.0)
	fill.position = Vector2(-11.0, 1.0)
	fill.color = Color(0.35, 0.9, 0.2, 0.95)
	hp_bar_node.add_child(fill)

func _spawn_floating_damage(amount: float) -> void:
	FloatingDamage.spawn(get_parent(), global_position, amount, Color(1.0, 0.90, 0.35, 1.0), -50.0, 13)

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
	emitter.amount = 26
	emitter.lifetime = 0.48
	emitter.explosiveness = 0.92
	emitter.spread = 180.0
	emitter.gravity = Vector2(0, 130)
	emitter.initial_velocity_min = 50.0
	emitter.initial_velocity_max = 150.0
	emitter.scale_amount_min = 2.0
	emitter.scale_amount_max = 4.5
	emitter.color = Color(0.18, 0.55, 0.15, 1.0)
	emitter.position = global_position + Vector2(0.0, -12.0)
	get_parent().add_child(emitter)
	emitter.finished.connect(emitter.queue_free)
	emitter.restart()
	emitter.emitting = true

	var tween = create_tween()
	tween.tween_property(pixel_sprite, "modulate:a", 0.0, 0.30)
	tween.tween_callback(queue_free)

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
			var pt = Vector2(cos(a) * 12.0, sin(a) * 4.5)
			draw_circle(pt, 2.2, Color(2.4, 2.0, 0.4, 1.0))
			draw_circle(pt, 1.1, Color(1.0, 1.0, 1.0, 1.0))
