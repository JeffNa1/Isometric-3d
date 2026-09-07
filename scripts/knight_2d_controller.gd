class_name Knight2DController
extends CharacterBody2D

## 2.5D Medieval Dark Knight Character Controller
## Features:
## - 8-Directional Movement (E, SE, S, SW, W, NW, N, NE)
## - Grounded Sabatons (Boots) anchored at (0, 0) with Dual Contact Shadow
## - RMB: Broadsword 3-Hit Slash Combo with glowing weapon trails
## - LMB (Hold): Directional Heater Shield Guard (55% speed)
## - F: Precise Timed Parry Deflect with golden sparks
## - SPACE: Tactical Dodge Burst with dark iron afterimages
## - SHIFT: Heavy Sprint | WASD: 8-Way Locomotion

const KnightVisualRendererClass = preload("res://scripts/knight_2d_visual_renderer.gd")

enum Dir8 { E = 0, SE = 1, S = 2, SW = 3, W = 4, NW = 5, N = 6, NE = 7 }

const DIR_NAMES = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

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
var parry_timer: float = 0.0
var attack_cooldown: float = 0.0
var attack_combo: int = 0
var combo_reset_timer: float = 0.0
var is_attacking: bool = false
var attack_anim_timer: float = 0.0
var current_attack_duration: float = 0.35
var mouse_aim_active: bool = false

# Visual Rig & VFX Nodes
var visual_renderer: Node2D = null
var pixel_viewport: SubViewport = null
var pixel_sprite: Sprite2D = null
var dust_emitter: CPUParticles2D = null
var parry_emitter: CPUParticles2D = null
var collision_shape: CollisionShape2D = null

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1

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
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if not is_guarding and not is_parrying and not is_dashing and attack_cooldown <= 0.0:
				_trigger_attack(true)
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
		elif event.keycode == KEY_F or event.unicode == 102 or event.unicode == 70:
			if not is_parrying and not is_dashing:
				_trigger_parry(false)

func _physics_process(delta: float) -> void:
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

	# 1. PARRIED DEFLECT (L Key or parry action)
	if Input.is_key_pressed(KEY_L) or (InputMap.has_action("parry") and Input.is_action_just_pressed("parry")):
		if not is_parrying and not is_dashing:
			_trigger_parry(false)

	# 2. DIRECTIONAL HEATER SHIELD GUARD (Hold Left Mouse Button or K Key)
	var guard_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_K) or (InputMap.has_action("block") and Input.is_action_pressed("block"))
	if is_parrying or is_dashing:
		guard_pressed = false
	is_guarding = guard_pressed

	# 3. BROADSWORD SLASH COMBO (Right Mouse Button or action)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or (InputMap.has_action("attack") and Input.is_action_just_pressed("attack")):
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
			current_attack_duration = 0.44
			attack_cooldown = 0.48

	attack_anim_timer = current_attack_duration
	is_attacking = true

	# Update facing towards cursor on attack ONLY if triggered via mouse click
	if from_mouse:
		var mouse_dir = (get_global_mouse_position() - global_position).normalized()
		current_dir = _get_dir8_from_vector(mouse_dir)
		facing_vector = _get_vector_from_dir8(current_dir)

	# Kinetic Lunge: Knight hurls full body weight into the strike
	var lunge_speed = 220.0 if attack_combo < 2 else 380.0
	velocity = facing_vector * lunge_speed

	# Impact on Combo 2 Wide-Area Finisher
	if attack_combo == 2:
		var cam = get_viewport().get_camera_2d()
		if cam and cam.has_method("add_trauma"):
			cam.add_trauma(0.26)
		dust_emitter.direction = facing_vector
		dust_emitter.restart()
		dust_emitter.emitting = true
		_spawn_wind_shockwave(facing_vector)

	if combo_reset_timer > 0.0:
		attack_combo = (attack_combo + 1) % 3
	else:
		attack_combo = 0
	combo_reset_timer = 0.70

func _spawn_wind_shockwave(aim_dir: Vector2) -> void:
	var ring = Line2D.new()
	ring.width = 2.5
	ring.default_color = Color(1.2, 1.4, 1.8, 0.85)
	var pts = PackedVector2Array()
	for i in range(17):
		var a = i * TAU / 16.0
		pts.append(Vector2(cos(a) * 16.0, sin(a) * 9.0))
	ring.points = pts
	ring.position = global_position + (aim_dir * 16.0) + Vector2(0.0, -12.0)
	get_parent().add_child(ring)

	var tween = create_tween()
	tween.tween_property(ring, "scale", Vector2(2.8, 2.8), 0.24)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.24)
	tween.tween_callback(ring.queue_free)

func _trigger_parry(from_mouse: bool = false) -> void:
	is_parrying = true
	parry_timer = 0.22
	is_guarding = false

	if from_mouse:
		var mouse_dir = (get_global_mouse_position() - global_position).normalized()
		current_dir = _get_dir8_from_vector(mouse_dir)
		facing_vector = _get_vector_from_dir8(current_dir)

	# Golden spark burst at shield position
	parry_emitter.position = facing_vector * 18.0 + Vector2(0.0, -16.0)
	parry_emitter.restart()
	parry_emitter.emitting = true

	# Deflection ring
	_spawn_deflection_ring(facing_vector)

func _spawn_deflection_ring(aim_dir: Vector2) -> void:
	var ring = Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(1.5, 1.2, 0.6, 1.0)
	var pts = PackedVector2Array()
	for i in range(17):
		var a = i * TAU / 16.0
		pts.append(Vector2(cos(a) * 12.0, sin(a) * 8.0))
	ring.points = pts
	ring.position = global_position + (aim_dir * 18.0) + Vector2(0.0, -16.0)
	get_parent().add_child(ring)

	var tween = create_tween()
	tween.tween_property(ring, "scale", Vector2(2.4, 2.4), 0.20)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.20)
	tween.tween_callback(ring.queue_free)

func _handle_dash(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * dash_speed
		move_and_slide()

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

	var input_dir = _get_input_direction()
	var is_sprinting = Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT)

	var current_target_speed = move_speed
	if is_guarding:
		current_target_speed = guard_speed
	elif is_sprinting:
		current_target_speed = sprint_speed

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

	# If guarding with mouse, facing follows mouse
	if is_guarding and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
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
		visual_renderer.update_state(
			delta, current_dir, is_moving, speed_ratio,
			is_guarding, is_parrying, is_attacking, attack_combo, attack_anim_timer, current_attack_duration
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
	if v.length_squared() < 0.001:
		return current_dir

	# In isometric 2:1 projection, Y distances are visually foreshortened by ~0.70
	var iso_angle = atan2(v.y * 1.35, v.x)
	var octant = int(round(iso_angle / (TAU / 8.0)))
	if octant < 0:
		octant += 8
	octant = octant % 8

	# Octants: 0=E, 1=SE, 2=S, 3=SW, 4=W, 5=NW, 6=N, 7=NE
	return octant as Dir8

func _get_vector_from_dir8(dir: Dir8) -> Vector2:
	match dir:
		Dir8.E:  return Vector2(1.0, 0.0)
		Dir8.SE: return Vector2(0.894, 0.447).normalized()
		Dir8.S:  return Vector2(0.0, 1.0)
		Dir8.SW: return Vector2(-0.894, 0.447).normalized()
		Dir8.W:  return Vector2(-1.0, 0.0)
		Dir8.NW: return Vector2(-0.894, -0.447).normalized()
		Dir8.N:  return Vector2(0.0, -1.0)
		Dir8.NE: return Vector2(0.894, -0.447).normalized()
		_:       return Vector2.DOWN
