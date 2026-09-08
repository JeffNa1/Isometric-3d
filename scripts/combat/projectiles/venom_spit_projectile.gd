class_name VenomSpitProjectile
extends Area2D

## 2.5D Toxic Venom Spit Projectile
## Cast by Toxic Spider:
## - Arcing flight path with vibrating acidic ground shadow
## - Glowing toxic venom glob with noxious dripping tail
## - On hit: Deals damage, applies Slow (50%), and spawns VenomPuddle
## - Can be Parried (F) within parry window to reflect back at enemies!

const VenomPuddleClass = preload("res://scripts/combat/projectiles/venom_puddle.gd")

@export var speed: float = 420.0
@export var damage: float = 18.0
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.DOWN
var flight_timer: float = 0.0
var has_hit: bool = false
var is_reflected: bool = false
var anim_phase: float = 0.0

const COL_VENOM_CORE   = Color(0.90, 1.0, 0.40, 1.0)
const COL_VENOM_MID    = Color(0.35, 0.92, 0.15, 0.95)
const COL_VENOM_DARK   = Color(0.08, 0.42, 0.10, 0.85)

const COL_REFLECT_CORE = Color(1.0, 1.0, 1.0, 1.0)
const COL_REFLECT_MID  = Color(0.30, 0.85, 1.0, 0.95)
const COL_REFLECT_DARK = Color(0.10, 0.35, 0.70, 0.85)

func _ready() -> void:
	collision_layer = 4 # Enemy projectile
	collision_mask = 2 | 1 # Player and Walls
	body_entered.connect(_on_body_entered)

	var shape = CircleShape2D.new()
	shape.radius = 8.0
	var col = CollisionShape2D.new()
	col.shape = shape
	add_child(col)

func setup(start_pos: Vector2, target_dir: Vector2, dmg: float = 18.0) -> void:
	global_position = start_pos
	direction = target_dir.normalized()
	damage = dmg
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	if has_hit:
		return

	flight_timer += delta
	anim_phase += delta * 15.0
	if flight_timer >= lifetime:
		_explode(false)
		return

	global_position += direction * speed * delta
	queue_redraw()

func _draw() -> void:
	var wobble = sin(anim_phase) * 1.4

	# 1. Ground Shadow (14px below, isometric 2:1)
	var shadow_pos = Vector2(0.0, 14.0).rotated(-rotation)
	var shadow_pts = PackedVector2Array()
	for i in range(8):
		var a = i * TAU / 8.0
		shadow_pts.append(shadow_pos + Vector2(cos(a) * 8.0, sin(a) * 3.8))
	draw_colored_polygon(shadow_pts, Color(0.0, 0.0, 0.0, 0.35))

	# 2. Dripping Venom Wake Tail
	for k in range(3):
		var t_off = -Vector2(5.0 + k * 4.5, sin(anim_phase + k) * 2.0)
		var t_rad = maxf(1.2, 4.0 - k * 1.0)
		var t_col = COL_REFLECT_DARK if is_reflected else COL_VENOM_DARK
		t_col.a = 0.60 - (k * 0.15)
		draw_circle(t_off, t_rad, t_col)

	# 3. Outer Venom Body
	var col_dark = COL_REFLECT_DARK if is_reflected else COL_VENOM_DARK
	draw_circle(Vector2(0, 0), 7.0 + wobble * 0.5, col_dark)

	# 4. Mid Acid Plasma
	var col_mid = COL_REFLECT_MID if is_reflected else COL_VENOM_MID
	draw_circle(Vector2(1.0, 0.0), 4.8, col_mid)

	# 5. Glowing Core
	var col_core = COL_REFLECT_CORE if is_reflected else COL_VENOM_CORE
	draw_circle(Vector2(1.5, 0.0), 2.6, col_core)

func _on_body_entered(body: Node2D) -> void:
	if has_hit:
		return

	if body.is_in_group("player"):
		if is_reflected:
			return
		if body.has_method("take_damage"):
			var hit_res = body.take_damage(damage, direction, false, self)
			if hit_res == "PARRIED":
				_reflect()
				return
			has_hit = true
			if body.has_method("apply_slow"):
				body.apply_slow(0.5, 2.5)
			_explode(true)

	elif is_reflected and body.is_in_group("enemies"):
		has_hit = true
		if body.has_method("take_damage"):
			body.take_damage(damage * 1.5, direction)
		if body.has_method("apply_stun"):
			body.apply_stun(1.4)
		_explode(false)

	elif body is StaticBody2D:
		has_hit = true
		_explode(true)

func _reflect() -> void:
	is_reflected = true
	direction = -direction
	rotation = direction.angle()
	speed *= 1.4
	collision_mask = 4 | 1 # Enemies and Walls

	# Sparkle burst on parry
	var emitter = CPUParticles2D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.amount = 14
	emitter.lifetime = 0.28
	emitter.explosiveness = 0.9
	emitter.spread = 180.0
	emitter.gravity = Vector2.ZERO
	emitter.initial_velocity_min = 70.0
	emitter.initial_velocity_max = 140.0
	emitter.scale_amount_min = 2.0
	emitter.scale_amount_max = 4.0
	emitter.color = Color(0.4, 0.9, 1.0, 1.0)
	emitter.position = global_position
	get_parent().add_child(emitter)
	emitter.finished.connect(emitter.queue_free)
	emitter.restart()
	emitter.emitting = true

func _explode(spawn_puddle: bool) -> void:
	has_hit = true
	var root = get_parent()
	if root:
		if spawn_puddle:
			var puddle = VenomPuddleClass.new()
			puddle.global_position = global_position
			root.call_deferred("add_child", puddle)

		# Splash droplets
		var emitter = CPUParticles2D.new()
		emitter.emitting = false
		emitter.one_shot = true
		emitter.amount = 16
		emitter.lifetime = 0.35
		emitter.explosiveness = 0.92
		emitter.spread = 180.0
		emitter.gravity = Vector2(0, 120)
		emitter.initial_velocity_min = 40.0
		emitter.initial_velocity_max = 130.0
		emitter.scale_amount_min = 1.5
		emitter.scale_amount_max = 3.5
		emitter.color = Color(0.35, 0.92, 0.15, 0.85) if not is_reflected else Color(0.4, 0.85, 1.0, 0.85)
		emitter.position = global_position
		root.add_child(emitter)
		emitter.finished.connect(emitter.queue_free)
		emitter.restart()
		emitter.emitting = true

	queue_free()
