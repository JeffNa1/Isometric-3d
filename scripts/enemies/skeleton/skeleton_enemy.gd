class_name SkeletonEnemy
extends CharacterBody2D

## Skeleton Monster Controller (Swordsman & Archer)
## - 8-Directional Locomotion & Visuals via SubViewport & Skeleton2DVisualRenderer
## - Swordsman: Pursues player and executes exact 2-Hit Combo (Horizontal Cleave & Rising Slash)
## - Archer: Kites player, aims and shoots bone arrows from long range
## - Reactive Hit Flash, Knockback, Overhead Mini HP Bar, and Bone Crumble Death VFX

const SkeletonVisualRendererClass = preload("res://scripts/enemies/skeleton/skeleton_2d_visual_renderer.gd")
const ArrowProjectileClass = preload("res://scripts/combat/projectiles/arrow_projectile.gd")
const FireballProjectileClass = preload("res://scripts/combat/projectiles/fireball_projectile.gd")
const FloatingDamage = preload("res://scripts/combat/floating_damage.gd")
const IsoUtils = preload("res://scripts/core/iso_utils.gd")

enum Type { SWORDSMAN, ARCHER, MAGE }
enum Dir8 { E = 0, SE = 1, S = 2, SW = 3, W = 4, NW = 5, N = 6, NE = 7 }
enum State { IDLE, CHASE, KITE, ATTACK, AIM_SHOOT, CAST_FIREBALL, TELEPORTING, STAGGER, STUNNED, DEAD }

@export var skeleton_type: Type = Type.SWORDSMAN
@export var is_dummy: bool = false # Passive practice mode

var max_hp: float = 60.0
var hp: float = 60.0
var move_speed: float = 190.0
var current_dir: Dir8 = Dir8.S
var facing_vector: Vector2 = Vector2.DOWN
var state: State = State.IDLE

# Combat Timers
var attack_cooldown: float = 0.0
var attack_timer: float = 0.0
var current_attack_duration: float = 0.34
var attack_combo: int = 0
var has_dealt_damage_in_swing: bool = false
var bow_draw_timer: float = 0.0
var bow_draw_duration: float = 0.45
var shoot_cooldown: float = 0.0
var cast_timer: float = 0.0
var cast_duration: float = 0.55
var cast_cooldown: float = 0.0
var teleport_cooldown: float = 0.0
var teleport_pause_timer: float = 0.0
var fireballs_cast_count: int = 0
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

	if skeleton_type == Type.ARCHER:
		max_hp = 40.0
		hp = 40.0
		move_speed = 155.0
	elif skeleton_type == Type.MAGE:
		max_hp = 45.0
		hp = 45.0
		move_speed = 160.0
	else:
		max_hp = 60.0
		hp = 60.0
		move_speed = 190.0

	# Collision Capsule/Circle
	collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12.0
	collision_shape.shape = circle
	collision_shape.position = Vector2(0.0, -4.0)
	add_child(collision_shape)

	# 2.5D SubViewport & Procedural Pixel Renderer
	pixel_viewport = SubViewport.new()
	pixel_viewport.name = "SkeletonPixelViewport"
	pixel_viewport.size = Vector2i(144, 144)
	pixel_viewport.transparent_bg = true
	pixel_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(pixel_viewport)

	visual_renderer = SkeletonVisualRendererClass.new()
	visual_renderer.name = "Skeleton2DVisualRenderer"
	visual_renderer.skeleton_type = skeleton_type
	visual_renderer.position = Vector2(72.0, 106.0)
	pixel_viewport.add_child(visual_renderer)

	pixel_sprite = Sprite2D.new()
	pixel_sprite.name = "PixelatedSkeletonSprite"
	pixel_sprite.texture = pixel_viewport.get_texture()
	pixel_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pixel_sprite.position = Vector2(0.0, -34.0)
	add_child(pixel_sprite)

	# Overhead Health Bar
	_setup_hp_bar()

func _setup_hp_bar() -> void:
	hp_bar_node = Node2D.new()
	hp_bar_node.position = Vector2(0.0, -48.0)
	hp_bar_node.visible = false
	add_child(hp_bar_node)

func _draw_hp_bar() -> void:
	if not hp_bar_node:
		return
	hp_bar_node.queue_redraw()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	# Timers
	if attack_cooldown > 0.0:
		attack_cooldown -= delta
	if shoot_cooldown > 0.0:
		shoot_cooldown -= delta
	if cast_cooldown > 0.0:
		cast_cooldown -= delta
	if teleport_cooldown > 0.0:
		teleport_cooldown -= delta

	_find_player()

	# AI Logic (Skipped if is_dummy)
	if is_dummy:
		velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
		move_and_slide()
		_update_visuals(delta, false, 0.0, false, 0, 0.0, 0.35, Vector2.ZERO, false, 0.0)
		return

	match state:
		State.IDLE, State.CHASE, State.KITE:
			_process_locomotion(delta)
		State.ATTACK:
			_process_swordsman_attack(delta)
		State.AIM_SHOOT:
			_process_archer_aim_shoot(delta)
		State.CAST_FIREBALL:
			_process_mage_cast(delta)
		State.TELEPORTING:
			_process_teleporting(delta)
		State.STAGGER:
			stagger_timer -= delta
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			move_and_slide()
			_update_visuals(delta, false, 0.0, false, 0, 0.0, 0.35, Vector2.ZERO, false, 0.0)
			if stagger_timer <= 0.0:
				state = State.IDLE
		State.STUNNED:
			_process_stun(delta)

func _process_stun(delta: float) -> void:
	stun_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
	move_and_slide()
	_update_visuals(delta, false, 0.0, false, 0, 0.0, 0.35, Vector2.ZERO, false, 0.0)

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
	# Separate from player if closer than 34.0 px (prevents sticking to player)
	if is_instance_valid(target_player):
		var diff = global_position - target_player.global_position
		var d = diff.length()
		if d < 34.0 and d > 0.001:
			sep += (diff / d) * ((34.0 - d) / 34.0) * 160.0

	# Separate from fellow skeleton enemies if closer than 30.0 px
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
		_update_visuals(delta, false, 0.0, false, 0, 0.0, 0.35, Vector2.ZERO, false, 0.0)
		return

	var to_player = target_player.global_position - global_position
	var dist = to_player.length()
	var dir_to_player = to_player.normalized()
	var sep_vel = _get_separation_velocity()

	current_dir = _get_dir8_from_vector(dir_to_player)
	facing_vector = _get_vector_from_dir8(current_dir)

	if skeleton_type == Type.SWORDSMAN:
		# Swordsman Melee Spacing Behavior:
		# Weapon reach is 50px, ideal attack trigger distance is 44px
		var melee_range = 44.0
		var min_standoff = 32.0

		if dist <= melee_range and attack_cooldown <= 0.0:
			_start_swordsman_combo(0)
			return

		var target_vel = Vector2.ZERO
		if dist < min_standoff:
			# Too close to player: back up smoothly to maintain weapon reach
			var back_dir = -dir_to_player
			target_vel = (back_dir * (move_speed * 0.70)) + sep_vel
			velocity = velocity.move_toward(target_vel, 1600.0 * delta)
		elif dist <= melee_range:
			# In melee range but on cooldown: do NOT ram forward into player!
			# Strafe tangentially / orbit to keep tactical pressure without sticking
			var tangent = Vector2(-dir_to_player.y, dir_to_player.x)
			var orbit_dir = tangent if (get_instance_id() % 2 == 0) else -tangent
			target_vel = (orbit_dir * (move_speed * 0.45)) + sep_vel
			velocity = velocity.move_toward(target_vel, 1200.0 * delta)
		else:
			# Advance closer to player
			target_vel = (dir_to_player * move_speed) + sep_vel
			velocity = velocity.move_toward(target_vel, 1400.0 * delta)

		move_and_slide()

		var is_moving = velocity.length_squared() > 100.0
		var speed_rat = clampf(velocity.length() / move_speed, 0.0, 1.0)
		_update_visuals(delta, is_moving, speed_rat, false, 0, 0.0, 0.35, velocity.normalized(), false, 0.0)

	elif skeleton_type == Type.ARCHER:
		# Archer Ranged & Kiting Behavior
		var min_kite_dist = 130.0
		var max_shoot_dist = 330.0

		if dist < min_kite_dist:
			# Kite away
			state = State.KITE
			var kite_dir = -dir_to_player
			var target_vel = (kite_dir * move_speed) + sep_vel
			velocity = velocity.move_toward(target_vel, 1300.0 * delta)
			move_and_slide()

			var is_moving = velocity.length_squared() > 100.0
			var speed_rat = clampf(velocity.length() / move_speed, 0.0, 1.0)
			_update_visuals(delta, is_moving, speed_rat, false, 0, 0.0, 0.35, velocity.normalized(), false, 0.0)

		elif dist <= max_shoot_dist:
			# In shooting sweet spot
			var target_vel = sep_vel
			velocity = velocity.move_toward(target_vel, 1600.0 * delta)
			move_and_slide()

			if shoot_cooldown <= 0.0:
				_start_archer_shoot()
				return
			else:
				_update_visuals(delta, false, 0.0, false, 0, 0.0, 0.35, Vector2.ZERO, false, 0.0)

		else:
			# Advance closer
			state = State.CHASE
			var target_vel = (dir_to_player * move_speed) + sep_vel
			velocity = velocity.move_toward(target_vel, 1200.0 * delta)
			move_and_slide()

			var is_moving = velocity.length_squared() > 100.0
			var speed_rat = clampf(velocity.length() / move_speed, 0.0, 1.0)
			_update_visuals(delta, is_moving, speed_rat, false, 0, 0.0, 0.35, velocity.normalized(), false, 0.0)

	elif skeleton_type == Type.MAGE:
		# Mage Ranged Fireball & Teleportation Behavior
		var min_kite_dist = 140.0
		var max_cast_dist = 300.0

		# Panic teleport if player gets dangerously close in melee range
		if dist < 95.0 and teleport_cooldown <= 0.0:
			_teleport()
			return

		if dist < min_kite_dist:
			# Kite away
			state = State.KITE
			var kite_dir = -dir_to_player
			var target_vel = (kite_dir * move_speed) + sep_vel
			velocity = velocity.move_toward(target_vel, 1300.0 * delta)
			move_and_slide()

			var is_moving = velocity.length_squared() > 100.0
			var speed_rat = clampf(velocity.length() / move_speed, 0.0, 1.0)
			_update_visuals(delta, is_moving, speed_rat, false, 0, 0.0, 0.35, velocity.normalized(), false, 0.0)

		elif dist <= max_cast_dist:
			# In casting sweet spot
			var target_vel = sep_vel
			velocity = velocity.move_toward(target_vel, 1600.0 * delta)
			move_and_slide()

			if cast_cooldown <= 0.0:
				_start_mage_cast()
				return
			else:
				_update_visuals(delta, false, 0.0, false, 0, 0.0, 0.35, Vector2.ZERO, false, 0.0)

		else:
			# Advance closer
			state = State.CHASE
			var target_vel = (dir_to_player * move_speed) + sep_vel
			velocity = velocity.move_toward(target_vel, 1200.0 * delta)
			move_and_slide()

			var is_moving = velocity.length_squared() > 100.0
			var speed_rat = clampf(velocity.length() / move_speed, 0.0, 1.0)
			_update_visuals(delta, is_moving, speed_rat, false, 0, 0.0, 0.35, velocity.normalized(), false, 0.0)

# --- SWORDSMAN ATTACK (COMBO 0 & COMBO 1) ---
func _start_swordsman_combo(combo_index: int) -> void:
	state = State.ATTACK
	attack_combo = combo_index
	has_dealt_damage_in_swing = false

	if is_instance_valid(target_player):
		var dir_to_p = (target_player.global_position - global_position).normalized()
		current_dir = _get_dir8_from_vector(dir_to_p)
		facing_vector = _get_vector_from_dir8(current_dir)

	var dist_to_p = (target_player.global_position - global_position).length() if is_instance_valid(target_player) else 40.0
	var lunge_pwr = 160.0 if dist_to_p > 38.0 else 40.0
	if attack_combo == 0:
		current_attack_duration = 0.34
		attack_timer = 0.34
		velocity = facing_vector * lunge_pwr
	else:
		current_attack_duration = 0.32
		attack_timer = 0.32
		velocity = facing_vector * (lunge_pwr * 1.1)

func _process_swordsman_attack(delta: float) -> void:
	attack_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()

	# Active strike hit window (at t ~ 0.30 - 0.60 of swing)
	var progress = 1.0 - (attack_timer / current_attack_duration)
	if not has_dealt_damage_in_swing and progress >= 0.30 and progress <= 0.60:
		_check_swordsman_hit()

	_update_visuals(delta, false, 0.0, true, attack_combo, attack_timer, current_attack_duration, Vector2.ZERO, false, 0.0)

	if attack_timer <= 0.0:
		if attack_combo == 0 and is_instance_valid(target_player):
			var dist = (target_player.global_position - global_position).length()
			if dist <= 54.0:
				# Trigger Combo 1 (Rising Backhand Slash)
				_start_swordsman_combo(1)
				return

		# Recovery & Cooldown
		state = State.IDLE
		attack_cooldown = 1.25
		attack_combo = 0

func _check_swordsman_hit() -> void:
	if not is_instance_valid(target_player):
		return

	var to_player = target_player.global_position - global_position
	var dist = to_player.length()
	var reach = 50.0

	if dist <= reach:
		var dot = facing_vector.dot(to_player.normalized())
		if dot >= 0.30: # 140° frontal arc
			has_dealt_damage_in_swing = true
			var dmg = 20.0 if attack_combo == 0 else 25.0
			var hit_res = target_player.take_damage(dmg, facing_vector, true, self)
			if hit_res == "PARRIED":
				# Parried: combo interrupted and stunned!
				state = State.STUNNED
				attack_combo = 0
				velocity = -facing_vector * 140.0

# --- ARCHER AIM & SHOOT ---
func _start_archer_shoot() -> void:
	state = State.AIM_SHOOT
	bow_draw_timer = 0.0
	velocity = Vector2.ZERO

	if is_instance_valid(target_player):
		var dir_to_p = (target_player.global_position - global_position).normalized()
		current_dir = _get_dir8_from_vector(dir_to_p)
		facing_vector = _get_vector_from_dir8(current_dir)

func _process_archer_aim_shoot(delta: float) -> void:
	bow_draw_timer += delta
	var draw_prog = clampf(bow_draw_timer / bow_draw_duration, 0.0, 1.0)

	if is_instance_valid(target_player):
		var dir_to_p = (target_player.global_position - global_position).normalized()
		current_dir = _get_dir8_from_vector(dir_to_p)
		facing_vector = _get_vector_from_dir8(current_dir)

	_update_visuals(delta, false, 0.0, false, 0, 0.0, 0.35, Vector2.ZERO, true, draw_prog)

	if bow_draw_timer >= bow_draw_duration:
		_release_arrow()
		state = State.IDLE
		shoot_cooldown = 1.85

func _release_arrow() -> void:
	var root = get_parent()
	if not root or not is_instance_valid(target_player):
		return

	var spawn_pos = global_position + Vector2(0.0, -18.0)
	var shoot_dir = (target_player.global_position - global_position).normalized()

	var arrow = ArrowProjectileClass.new()
	root.add_child(arrow)
	arrow.setup(spawn_pos, shoot_dir, 18.0)

# --- MAGE CAST FIREBALL & TELEPORT ---
func _start_mage_cast() -> void:
	state = State.CAST_FIREBALL
	cast_timer = 0.0
	velocity = Vector2.ZERO

	if is_instance_valid(target_player):
		var dir_to_p = (target_player.global_position - global_position).normalized()
		current_dir = _get_dir8_from_vector(dir_to_p)
		facing_vector = _get_vector_from_dir8(current_dir)

func _process_mage_cast(delta: float) -> void:
	cast_timer += delta
	var cast_prog = clampf(cast_timer / cast_duration, 0.0, 1.0)

	if is_instance_valid(target_player):
		var dir_to_p = (target_player.global_position - global_position).normalized()
		current_dir = _get_dir8_from_vector(dir_to_p)
		facing_vector = _get_vector_from_dir8(current_dir)

	_update_visuals(delta, false, 0.0, false, 0, 0.0, 0.35, Vector2.ZERO, true, cast_prog)

	if cast_timer >= cast_duration:
		_release_fireball()
		fireballs_cast_count += 1
		cast_cooldown = 1.9

		# Teleport after 2 fireballs or if player is closing in
		var dist_to_p = (target_player.global_position - global_position).length() if is_instance_valid(target_player) else 200.0
		if fireballs_cast_count >= 2 or dist_to_p < 140.0:
			fireballs_cast_count = 0
			_teleport()
		else:
			state = State.IDLE

func _release_fireball() -> void:
	var root = get_parent()
	if not root or not is_instance_valid(target_player):
		return

	var spawn_pos = global_position + Vector2(0.0, -22.0)
	var shoot_dir = (target_player.global_position - global_position).normalized()

	var fb = FireballProjectileClass.new()
	root.add_child(fb)
	fb.setup(spawn_pos, shoot_dir, 26.0)

func _teleport() -> void:
	var root = get_parent()
	if not root:
		return

	# Smoke burst at departure point
	_spawn_arcane_poof(global_position + Vector2(0.0, -16.0))

	# Pick new position away from player
	var p_pos = target_player.global_position if is_instance_valid(target_player) else Vector2.ZERO
	var away_angle = (global_position - p_pos).angle()
	var new_angle = away_angle + randf_range(-PI * 0.45, PI * 0.45)
	var new_dist = randf_range(180.0, 270.0)
	var target_pos = p_pos + Vector2(cos(new_angle), sin(new_angle)) * new_dist

	# Clamp within arena boundaries (radius roughly 360px)
	if target_pos.length() > 350.0:
		target_pos = target_pos.normalized() * 330.0

	global_position = target_pos

	# Smoke burst at arrival point
	_spawn_arcane_poof(global_position + Vector2(0.0, -16.0))

	state = State.TELEPORTING
	teleport_pause_timer = 0.18
	teleport_cooldown = 4.5
	velocity = Vector2.ZERO

func _process_teleporting(delta: float) -> void:
	teleport_pause_timer -= delta
	velocity = Vector2.ZERO
	_update_visuals(delta, false, 0.0, false, 0, 0.0, 0.35, Vector2.ZERO, false, 0.0)

	if teleport_pause_timer <= 0.0:
		state = State.IDLE

func _spawn_arcane_poof(pos: Vector2) -> void:
	var root = get_parent()
	if not root:
		return
	var emitter = CPUParticles2D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.amount = 22
	emitter.lifetime = 0.40
	emitter.explosiveness = 0.90
	emitter.spread = 180.0
	emitter.gravity = Vector2(0, -20)
	emitter.initial_velocity_min = 40.0
	emitter.initial_velocity_max = 120.0
	emitter.scale_amount_min = 2.5
	emitter.scale_amount_max = 5.0
	emitter.color = Color(0.68, 0.22, 0.95, 0.90) # Arcane violet
	emitter.position = pos
	root.add_child(emitter)
	emitter.finished.connect(emitter.queue_free)
	emitter.restart()
	emitter.emitting = true

# --- DAMAGE & DEATH ---
func take_damage(amount: float, knockback_dir: Vector2) -> void:
	if state == State.DEAD:
		return

	hp -= amount
	hp_bar_node.visible = true
	_update_hp_bar_visual()

	# White/Red Hit Flash
	pixel_sprite.modulate = Color(2.5, 0.4, 0.4, 1.0)
	var tween = create_tween()
	tween.tween_property(pixel_sprite, "modulate", Color.WHITE, 0.14)

	# Knockback impulse
	velocity = knockback_dir * 320.0
	if state != State.STUNNED:
		state = State.STAGGER
		stagger_timer = 0.20

	# Floating damage number
	_spawn_floating_damage(amount)

	if hp <= 0.0:
		_die()

func apply_stun(duration: float = 1.0) -> void:
	if state == State.DEAD:
		return

	state = State.STUNNED
	stun_timer = maxf(stun_timer, duration)
	velocity = Vector2.ZERO
	attack_combo = 0
	has_dealt_damage_in_swing = false
	bow_draw_timer = 0.0

	# Golden electric stun flash on skeleton
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
	halo.position = Vector2(0.0, -52.0)
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
	fill.color = Color(0.85, 0.2, 0.2, 0.95)
	hp_bar_node.add_child(fill)

func _spawn_floating_damage(amount: float) -> void:
	var is_crit = amount >= 50.0
	var col = Color(1.0, 0.38, 0.25, 1.0) if is_crit else Color(1.0, 0.90, 0.35, 1.0)
	var sz = 16 if is_crit else 13
	FloatingDamage.spawn(get_parent(), global_position, amount, col, -58.0, sz)

func _die() -> void:
	state = State.DEAD
	collision_shape.set_deferred("disabled", true)
	hp_bar_node.visible = false
	if is_instance_valid(stun_halo_node):
		stun_halo_node.queue_free()
		stun_halo_node = null

	# Bone Collapse & Shard Particles
	var emitter = CPUParticles2D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.amount = 26
	emitter.lifetime = 0.50
	emitter.explosiveness = 0.95
	emitter.spread = 180.0
	emitter.gravity = Vector2(0, 120)
	emitter.initial_velocity_min = 60.0
	emitter.initial_velocity_max = 160.0
	emitter.scale_amount_min = 2.0
	emitter.scale_amount_max = 4.5
	emitter.color = Color(0.88, 0.84, 0.74, 1.0)
	emitter.position = global_position + Vector2(0.0, -18.0)
	get_parent().add_child(emitter)
	emitter.restart()
	emitter.emitting = true

	# Fade out sprite & delete
	var tween = create_tween()
	tween.tween_property(pixel_sprite, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)

func _update_visuals(
	delta: float,
	moving: bool,
	speed_rat: float,
	attacking: bool,
	combo: int,
	att_timer: float,
	att_duration: float,
	move_vec: Vector2,
	aiming_bow: bool,
	bow_draw: float
) -> void:
	if visual_renderer:
		visual_renderer.update_state(
			delta, current_dir, moving, speed_rat,
			attacking, combo, att_timer, att_duration,
			move_vec, aiming_bow, bow_draw
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
		# Draw 3 orbiting golden dizzy stars around the head (isometric 2:1 ratio)
		for i in range(3):
			var a = t + (i * TAU / 3.0)
			var pt = Vector2(cos(a) * 12.0, sin(a) * 4.5)
			draw_circle(pt, 2.4, Color(2.4, 2.0, 0.4, 1.0))
			draw_circle(pt, 1.2, Color(1.0, 1.0, 1.0, 1.0))
