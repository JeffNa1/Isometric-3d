class_name Knight2DController
extends CharacterBody2D

## 2.5D Medieval Dark Knight Character Controller
## Features:
## - 8-Directional Movement (E, SE, S, SW, W, NW, N, NE)
## - Grounded Sabatons (Boots) anchored at (0, 0) with Dual Contact Shadow
## - LMB: Broadsword 3-Hit Slash Combo with glowing weapon trails
## - F (Hold): Directional Heater Shield Guard (55% speed)
## - RMB: Precise Timed Parry Deflect with golden sparks
## - SPACE: Tactical Dodge Burst with dark iron afterimages
## - SHIFT: Heavy Sprint | WASD: 8-Way Locomotion

const KnightVisualRendererClass = preload("res://scripts/player/knight_2d_visual_renderer.gd")
const KnightCombatVFX = preload("res://scripts/player/knight_combat_vfx.gd")
const IsoUtils = preload("res://scripts/core/iso_utils.gd")

enum Dir8 { E = 0, SE = 1, S = 2, SW = 3, W = 4, NW = 5, N = 6, NE = 7 }

const DIR_NAMES = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
signal hp_changed(current_hp: float, max_hp: float)

@export var max_hp: float = 100.0
var hp: float = 100.0
var is_god_mode: bool = false

@export var move_speed: float = 270.0
@export var sprint_speed: float = 430.0
@export var guard_speed: float = 150.0
@export var acceleration: float = 2200.0
@export var friction: float = 2000.0
@export var dash_speed: float = 720.0
@export var dash_duration: float = 0.20
@export var dash_cooldown: float = 0.60

# 8-Direction State
var current_dir: Dir8 = Dir8.S
var facing_vector: Vector2 = Vector2.DOWN
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.DOWN
var ghost_trail_timer: float = 0.0

# Combat State
var is_guarding: bool = false
var is_parrying: bool = false
const PARRY_DURATION: float = 0.38
var parry_duration: float = 0.38
var parry_timer: float = 0.0
var parry_apex_triggered: bool = false
var _prev_parry_key: bool = false
var attack_cooldown: float = 0.0
var attack_combo: int = 0
var combo_reset_timer: float = 0.0
var is_attacking: bool = false
var attack_anim_timer: float = 0.0
var current_attack_duration: float = 0.35
var mouse_aim_active: bool = false
var slow_timer: float = 0.0
var slow_factor: float = 1.0

# Visual Rig & VFX Nodes
var visual_renderer: Node2D = null
var pixel_viewport: SubViewport = null
var pixel_sprite: Sprite2D = null
var dust_emitter: CPUParticles2D = null
var parry_emitter: CPUParticles2D = null
var cyclone_dust_emitter: CPUParticles2D = null
var cyclone_sparks_emitter: CPUParticles2D = null
var poison_emitter: CPUParticles2D = null
var collision_shape: CollisionShape2D = null

func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1 | 4

	collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12.0
	collision_shape.shape = circle
	collision_shape.position = Vector2(0.0, -4.0)
	add_child(collision_shape)

	# Medieval Stone Footstep Dust
	dust_emitter = CPUParticles2D.new()
	dust_emitter.emitting = false
	dust_emitter.amount = 14
	dust_emitter.lifetime = 0.35
	dust_emitter.explosiveness = 0.1
	dust_emitter.direction = Vector2(0, -1)
	dust_emitter.spread = 160.0
	dust_emitter.gravity = Vector2(0, 30)
	dust_emitter.initial_velocity_min = 15.0
	dust_emitter.initial_velocity_max = 45.0
	dust_emitter.scale_amount_min = 1.5
	dust_emitter.scale_amount_max = 3.0
	dust_emitter.color = Color(0.55, 0.50, 0.42, 0.40)
	add_child(dust_emitter)

	# Parry Deflection Golden Spark Emitter
	parry_emitter = CPUParticles2D.new()
	parry_emitter.emitting = false
	parry_emitter.one_shot = true
	parry_emitter.amount = 28
	parry_emitter.lifetime = 0.40
	parry_emitter.explosiveness = 0.95
	parry_emitter.spread = 180.0
	parry_emitter.gravity = Vector2(0, 80)
	parry_emitter.initial_velocity_min = 120.0
	parry_emitter.initial_velocity_max = 280.0
	parry_emitter.scale_amount_min = 2.0
	parry_emitter.scale_amount_max = 4.5
	parry_emitter.color = Color(1.3, 0.95, 0.35, 1.0)
	add_child(parry_emitter)

	# 360° Cyclone Dust Burst Emitter
	cyclone_dust_emitter = CPUParticles2D.new()
	cyclone_dust_emitter.emitting = false
	cyclone_dust_emitter.one_shot = true
	cyclone_dust_emitter.amount = 36
	cyclone_dust_emitter.lifetime = 0.45
	cyclone_dust_emitter.explosiveness = 0.90
	cyclone_dust_emitter.spread = 180.0
	cyclone_dust_emitter.gravity = Vector2(0, 50)
	cyclone_dust_emitter.initial_velocity_min = 80.0
	cyclone_dust_emitter.initial_velocity_max = 220.0
	cyclone_dust_emitter.scale_amount_min = 2.0
	cyclone_dust_emitter.scale_amount_max = 4.5
	cyclone_dust_emitter.color = Color(0.65, 0.60, 0.52, 0.65)
	add_child(cyclone_dust_emitter)

	# 360° Cyclone Golden Spark Flare Emitter
	cyclone_sparks_emitter = CPUParticles2D.new()
	cyclone_sparks_emitter.emitting = false
	cyclone_sparks_emitter.one_shot = true
	cyclone_sparks_emitter.amount = 45
	cyclone_sparks_emitter.lifetime = 0.40
	cyclone_sparks_emitter.explosiveness = 0.95
	cyclone_sparks_emitter.spread = 180.0
	cyclone_sparks_emitter.gravity = Vector2(0, 60)
	cyclone_sparks_emitter.initial_velocity_min = 140.0
	cyclone_sparks_emitter.initial_velocity_max = 320.0
	cyclone_sparks_emitter.scale_amount_min = 1.8
	cyclone_sparks_emitter.scale_amount_max = 4.0
	cyclone_sparks_emitter.color = Color(1.4, 1.2, 0.5, 1.0)
	add_child(cyclone_sparks_emitter)

	# Toxic Poison Slow Drip Emitter
	poison_emitter = CPUParticles2D.new()
	poison_emitter.emitting = false
	poison_emitter.amount = 16
	poison_emitter.lifetime = 0.55
	poison_emitter.direction = Vector2(0, 1)
	poison_emitter.spread = 40.0
	poison_emitter.gravity = Vector2(0, 90)
	poison_emitter.initial_velocity_min = 20.0
	poison_emitter.initial_velocity_max = 50.0
	poison_emitter.scale_amount_min = 2.0
	poison_emitter.scale_amount_max = 3.5
	poison_emitter.color = Color(0.35, 1.2, 0.25, 0.85)
	poison_emitter.position = Vector2(0, -18)
	add_child(poison_emitter)

	# 2.5D Directional Visual Renderer with Pixel-Art Rasterization
	pixel_viewport = SubViewport.new()
	pixel_viewport.name = "KnightPixelViewport"
	pixel_viewport.size = Vector2i(144, 144)
	pixel_viewport.transparent_bg = true
	pixel_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(pixel_viewport)

	visual_renderer = KnightVisualRendererClass.new()
	visual_renderer.name = "Knight2DVisualRenderer"
	# Position in viewport so that sabatons at y=0 are placed at y=106, x=72
	visual_renderer.position = Vector2(72.0, 106.0)
	pixel_viewport.add_child(visual_renderer)

	pixel_sprite = Sprite2D.new()
	pixel_sprite.name = "PixelatedKnightSprite"
	pixel_sprite.texture = pixel_viewport.get_texture()
	pixel_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Center of 144x144 is (72, 72). Feet at (72, 106) -> offset is (0, +34) from center.
	# Setting sprite position to (0, -34) aligns the feet strictly at (0, 0) world space!
	pixel_sprite.position = Vector2(0.0, -34.0)
	add_child(pixel_sprite)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not is_guarding and not is_parrying and not is_dashing and attack_cooldown <= 0.0:
				_trigger_attack(true)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if not is_parrying and not is_dashing:
				_trigger_parry(true)
	elif event is InputEventKey and event.pressed:
		var key_num = -1
		if event.unicode >= 49 and event.unicode <= 56:
			key_num = event.unicode - 49
		elif event.keycode >= KEY_1 and event.keycode <= KEY_8:
			key_num = event.keycode - KEY_1
		elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_8:
			key_num = event.physical_keycode - KEY_1

		if key_num >= 0:
			current_dir = key_num as Dir8
			facing_vector = _get_vector_from_dir8(current_dir)
		elif event.keycode == KEY_J or event.unicode == 106 or event.unicode == 74:
			if not is_guarding and not is_parrying and not is_dashing and attack_cooldown <= 0.0:
				_trigger_attack(false)

func _physics_process(delta: float) -> void:
	if slow_timer > 0.0:
		slow_timer -= delta
		if poison_emitter:
			poison_emitter.emitting = true
		if slow_timer <= 0.0:
			slow_factor = 1.0
			if poison_emitter:
				poison_emitter.emitting = false
			if pixel_sprite:
				pixel_sprite.modulate = Color.WHITE

	_handle_combat_inputs(delta)
	_handle_dash(delta)
	_handle_movement(delta)
	_update_visuals(delta)

func _handle_combat_inputs(delta: float) -> void:
	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta

	if attack_anim_timer > 0.0:
		attack_anim_timer -= delta
		if attack_anim_timer <= 0.0:
			is_attacking = false

	if parry_timer > 0.0:
		parry_timer -= delta
		if parry_timer <= 0.0:
			is_parrying = false

	# 1. PARRIED DEFLECT (Right Mouse Button, L Key, or parry action)
	var curr_parry_raw = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_key_pressed(KEY_L)
	var parry_just_pressed = (InputMap.has_action("parry") and Input.is_action_just_pressed("parry")) or (curr_parry_raw and not _prev_parry_key)
	_prev_parry_key = curr_parry_raw

	if parry_just_pressed:
		if not is_parrying and not is_dashing and not is_attacking:
			_trigger_parry(true)

	# 2. DIRECTIONAL HEATER SHIELD GUARD (Hold F Key, K Key, or block action)
	var guard_pressed = Input.is_key_pressed(KEY_F) or Input.is_key_pressed(KEY_K) or (InputMap.has_action("block") and Input.is_action_pressed("block"))
	if is_parrying or is_dashing:
		guard_pressed = false
	is_guarding = guard_pressed

	# 3. BROADSWORD SLASH COMBO (Left Mouse Button, J Key, or attack action)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or (InputMap.has_action("attack") and Input.is_action_just_pressed("attack")):
		if not is_guarding and not is_parrying and not is_dashing and attack_cooldown <= 0.0:
			_trigger_attack(true)

func _trigger_attack(from_mouse: bool = false) -> void:
	match attack_combo:
		0:
			current_attack_duration = 0.34
			attack_cooldown = 0.36
		1:
			current_attack_duration = 0.32
			attack_cooldown = 0.34
		2:
			current_attack_duration = 0.52
			attack_cooldown = 0.54

	attack_anim_timer = current_attack_duration
	is_attacking = true

	# Update facing towards cursor on attack ONLY if triggered via mouse click
	if from_mouse:
		var mouse_dir = (get_global_mouse_position() - global_position).normalized()
		current_dir = _get_dir8_from_vector(mouse_dir)
		facing_vector = _get_vector_from_dir8(current_dir)

	# Kinetic Lunge: Knight hurls full body weight into the strike
	var lunge_speed = 220.0 if attack_combo < 2 else 320.0
	velocity = facing_vector * lunge_speed

	# Impact on Combo 2 360° Whirlwind Finisher
	if attack_combo == 2:
		var cam = get_viewport().get_camera_2d()
		if cam and cam.has_method("add_trauma"):
			cam.add_trauma(0.38)
		if cam and cam.has_method("trigger_zoom_punch"):
			cam.trigger_zoom_punch(0.035, 0.28)

		if cyclone_dust_emitter:
			cyclone_dust_emitter.restart()
			cyclone_dust_emitter.emitting = true

		if cyclone_sparks_emitter:
			cyclone_sparks_emitter.restart()
			cyclone_sparks_emitter.emitting = true

		_spawn_360_whirlwind_vfx(facing_vector)
	else:
		dust_emitter.direction = -facing_vector
		dust_emitter.restart()
		dust_emitter.emitting = true

	var strike_combo = attack_combo
	var strike_facing = facing_vector
	get_tree().create_timer(0.06).timeout.connect(func():
		if is_instance_valid(self):
			_check_melee_hit(strike_combo, strike_facing)
	)

	if combo_reset_timer > 0.0:
		attack_combo = (attack_combo + 1) % 3
	else:
		attack_combo = 0
	combo_reset_timer = 0.75

func take_damage(amount: float, from_dir: Vector2, is_melee: bool = true, attacker: Node2D = null) -> String:
	var cam = get_viewport().get_camera_2d()

	# TIMED PARRY CHECK:
	# Only succeeds if incoming attack connects during the active parry window (0.12 to 0.55 progress)
	# AND facing the incoming strike (frontal arc)
	if is_parrying:
		var progress = 1.0 - (parry_timer / maxf(parry_duration, 0.01))
		var in_active_window = progress >= 0.12 and progress <= 0.55
		var dot = facing_vector.dot(-from_dir.normalized())
		var facing_incoming = dot >= -0.25

		if in_active_window and facing_incoming:
			# --- SUCCESSFUL PARRY TIMING ---
			parry_apex_triggered = true
			is_parrying = false
			parry_timer = 0.0
			attack_cooldown = 0.0 # Instant counter-attack readiness!

			# 1. Golden deflection sparks at shield contact point
			if parry_emitter:
				parry_emitter.position = facing_vector * 19.0 + Vector2(0.0, -16.0)
				parry_emitter.restart()
				parry_emitter.emitting = true

			# 2. Deflection shockwave ring
			_spawn_deflection_ring(facing_vector)

			# 3. Camera impact punch
			if cam and cam.has_method("add_trauma"):
				cam.add_trauma(0.24)
			if cam and cam.has_method("trigger_zoom_punch"):
				cam.trigger_zoom_punch(0.035, 0.22)

			# 4. Golden deflection sheen on player
			if pixel_sprite:
				pixel_sprite.modulate = Color(2.6, 2.2, 0.7, 1.0)
				var tween = create_tween()
				tween.tween_property(pixel_sprite, "modulate", Color.WHITE, 0.18)

			# 5. Stun attacker (only on successful parry!)
			if is_melee:
				if is_instance_valid(attacker) and attacker.has_method("apply_stun"):
					attacker.apply_stun(1.35)
				_stun_frontal_attackers(facing_vector, 88.0, 1.35)
				_spawn_stun_shockwave(100.0)

			return "PARRIED"
		else:
			# Mistimed parry or hit from behind -> Parry broken, player takes normal damage!
			is_parrying = false
			parry_timer = 0.0

	if is_god_mode:
		return "IMMUNE"

	if is_guarding:
		var dot = facing_vector.dot(-from_dir.normalized())
		if dot >= 0.05:
			# Block reduces incoming damage by 60% (player takes 40% chip damage)
			var chip_dmg = amount * 0.40
			hp = maxf(0.0, hp - chip_dmg)
			hp_changed.emit(hp, max_hp)

			if parry_emitter:
				parry_emitter.position = facing_vector * 16.0 + Vector2(0.0, -14.0)
				parry_emitter.restart()
				parry_emitter.emitting = true
			velocity += from_dir.normalized() * 110.0

			if cam and cam.has_method("add_trauma"):
				cam.add_trauma(0.10)

			if pixel_sprite:
				pixel_sprite.modulate = Color(1.8, 1.3, 0.6, 1.0)
				var tween = create_tween()
				tween.tween_property(pixel_sprite, "modulate", Color.WHITE, 0.12)

			return "BLOCKED"

	hp = maxf(0.0, hp - amount)
	hp_changed.emit(hp, max_hp)

	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.25)

	if pixel_sprite:
		pixel_sprite.modulate = Color(2.4, 0.4, 0.4, 1.0)
		var tween = create_tween()
		tween.tween_property(pixel_sprite, "modulate", Color.WHITE, 0.15)

	velocity = from_dir.normalized() * 220.0
	return "HIT"

func _check_melee_hit(combo_used: int, attack_dir: Vector2) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	var range_reach = 92.0 if combo_used == 2 else 62.0
	var min_dot = -1.0 if combo_used == 2 else 0.20
	var damage = 25.0
	if combo_used == 1:
		damage = 32.0
	elif combo_used == 2:
		damage = 65.0

	var hit_any = false
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue

		var to_enemy = enemy.global_position - global_position
		var dist = to_enemy.length()
		if dist <= range_reach:
			var dot = attack_dir.dot(to_enemy.normalized())
			if dot >= min_dot:
				hit_any = true
				var k_dir = to_enemy.normalized() if to_enemy != Vector2.ZERO else attack_dir
				enemy.take_damage(damage, k_dir)

	if hit_any:
		var cam = get_viewport().get_camera_2d()
		if cam and cam.has_method("add_trauma"):
			cam.add_trauma(0.12 if combo_used < 2 else 0.35)

func _spawn_360_whirlwind_vfx(_aim_dir: Vector2) -> void:
	KnightCombatVFX.spawn_360_whirlwind(get_parent(), global_position)
	for step in [0.06, 0.14, 0.22]:
		get_tree().create_timer(step).timeout.connect(func():
			if is_instance_valid(self):
				_spawn_ghost_trail()
		)

func _trigger_parry(_from_mouse: bool = false) -> void:
	is_parrying = true
	parry_duration = PARRY_DURATION
	parry_timer = parry_duration
	parry_apex_triggered = false
	is_guarding = false

	# Always orient toward mouse cursor for precision parrying
	var mouse_dir = (get_global_mouse_position() - global_position).normalized()
	if mouse_dir.length_squared() > 0.001:
		current_dir = _get_dir8_from_vector(mouse_dir)
		facing_vector = _get_vector_from_dir8(current_dir)
	elif velocity.length_squared() > 100.0:
		current_dir = _get_dir8_from_vector(velocity.normalized())
		facing_vector = _get_vector_from_dir8(current_dir)

	# Martial coil afterimage
	_spawn_ghost_trail()

func _spawn_deflection_ring(aim_dir: Vector2) -> void:
	KnightCombatVFX.spawn_deflection_ring(get_parent(), global_position, aim_dir)

func _stun_frontal_attackers(aim_dir: Vector2, reach: float = 90.0, duration: float = 1.35) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("apply_stun"):
			continue
		var to_enemy = enemy.global_position - global_position
		if to_enemy.length() <= reach:
			var dot = aim_dir.dot(to_enemy.normalized())
			if dot >= 0.10: # Frontal hemisphere
				enemy.apply_stun(duration)

func _stun_nearby_enemies(radius: float = 160.0, duration: float = 1.0) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= radius:
			if enemy.has_method("apply_stun"):
				enemy.apply_stun(duration)

	_spawn_stun_shockwave(radius)

func _spawn_stun_shockwave(radius: float) -> void:
	KnightCombatVFX.spawn_stun_shockwave(get_parent(), global_position, radius)

func _handle_dash(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * dash_speed
		move_and_slide()

		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i)
			var collider = col.get_collider()
			if collider:
				var parent_door = collider.get_parent()
				if parent_door and parent_door.has_method("shatter_door"):
					parent_door.shatter_door(dash_direction)

		ghost_trail_timer -= delta
		if ghost_trail_timer <= 0.0:
			ghost_trail_timer = 0.035
			_spawn_ghost_trail()

		if dash_timer <= 0.0:
			is_dashing = false
			velocity = dash_direction * move_speed

	elif Input.is_action_just_pressed("dash") or Input.is_key_pressed(KEY_SPACE):
		if dash_cooldown_timer <= 0.0:
			var input_dir = _get_input_direction()
			dash_direction = input_dir if input_dir != Vector2.ZERO else facing_vector
			is_dashing = true
			is_guarding = false
			dash_timer = dash_duration
			dash_cooldown_timer = dash_cooldown
			dust_emitter.restart()
			dust_emitter.emitting = true

func _handle_movement(delta: float) -> void:
	if is_dashing:
		return

	if is_parrying:
		velocity = velocity.move_toward(Vector2.ZERO, friction * 2.2 * delta)
		dust_emitter.emitting = false
		move_and_slide()
		return

	var input_dir = _get_input_direction()
	var is_sprinting = Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT)

	var current_target_speed = move_speed
	if is_guarding:
		current_target_speed = guard_speed
	elif is_sprinting:
		current_target_speed = sprint_speed

	current_target_speed *= slow_factor

	if input_dir != Vector2.ZERO:
		var target_vel = input_dir * current_target_speed
		velocity = velocity.move_toward(target_vel, acceleration * delta)

		# If not aiming with mouse during guard/attack, facing follows 8-directional movement
		if not is_guarding and not is_attacking and not is_parrying:
			current_dir = _get_dir8_from_vector(input_dir)
			facing_vector = _get_vector_from_dir8(current_dir)

		dust_emitter.emitting = true
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		dust_emitter.emitting = false

	# If guarding, facing follows mouse
	if is_guarding:
		var mouse_dir = (get_global_mouse_position() - global_position).normalized()
		current_dir = _get_dir8_from_vector(mouse_dir)
		facing_vector = _get_vector_from_dir8(current_dir)

	move_and_slide()

func _get_input_direction() -> Vector2:
	var dir = Vector2.ZERO
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_action_pressed("move_up") or Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_action_pressed("move_down") or Input.is_key_pressed(KEY_S):
		dir.y += 1.0

	return dir.normalized()

func _update_visuals(delta: float) -> void:
	if visual_renderer:
		var is_moving = velocity.length_squared() > 80.0
		var speed_ratio = clampf(velocity.length() / sprint_speed, 0.0, 1.0)
		var move_vec = velocity.normalized() if is_moving else Vector2.ZERO
		visual_renderer.update_state(
			delta, current_dir, is_moving, speed_ratio,
			is_guarding, is_parrying, is_attacking, attack_combo, attack_anim_timer, current_attack_duration,
			move_vec,
			parry_timer, parry_duration
		)

func _spawn_ghost_trail() -> void:
	if not visual_renderer:
		return
	var ghost = Line2D.new()
	ghost.width = 18.0
	ghost.default_color = Color(0.35, 0.45, 0.65, 0.45)
	var pts = PackedVector2Array([Vector2(0, -28), Vector2(0, -6)])
	ghost.points = pts
	ghost.position = global_position
	get_parent().add_child(ghost)

	var tween = create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ghost.queue_free)

# 8-Direction Calculation: Snaps 360-degree input into the 8 canonical isometric angles
func _get_dir8_from_vector(v: Vector2) -> Dir8:
	return IsoUtils.get_dir8_from_vector(v) as Dir8

func _get_vector_from_dir8(dir: Dir8) -> Vector2:
	return IsoUtils.get_vector_from_dir8(dir as int)

func apply_slow(factor: float = 0.5, duration: float = 2.5) -> void:
	slow_timer = maxf(slow_timer, duration)
	slow_factor = minf(slow_factor, factor)
	if poison_emitter:
		poison_emitter.emitting = true
	if pixel_sprite:
		pixel_sprite.modulate = Color(0.70, 1.40, 0.65, 1.0) # Toxic greenish tint
