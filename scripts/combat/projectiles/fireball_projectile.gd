class_name FireballProjectile
extends Area2D

## 2.5D Isometric Blazing Fireball Projectile
## Cast by Skeleton Mage:
## - Arcing 2.5D flight path with vibrating heat shadow on ground
## - Layered multi-tone flame sphere (White-hot core, Amber plasma, Crimson corona)
## - Dynamic flame wake embers and smoke
## - Can be Parried (F) within the parry window to reflect back at 1.4x speed as Holy Fire!

@export var speed: float = 440.0
@export var damage: float = 26.0
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.DOWN
var flight_timer: float = 0.0
var has_hit: bool = false
var is_reflected: bool = false
var anim_phase: float = 0.0

# Visual Palette
const COL_CORE_WHITE  = Color(1.0, 1.0, 0.95, 1.0)
const COL_FIRE_YELLOW = Color(1.0, 0.85, 0.25, 1.0)
const COL_FIRE_ORANGE = Color(1.0, 0.45, 0.10, 0.95)
const COL_FIRE_RED    = Color(0.85, 0.15, 0.05, 0.85)
const COL_SMOKE_DARK  = Color(0.20, 0.12, 0.14, 0.45)

# Reflected Holy Fire Palette
const COL_HOLY_CORE   = Color(1.0, 1.0, 1.0, 1.0)
const COL_HOLY_GOLD   = Color(2.5, 2.1, 0.6, 1.0)
const COL_HOLY_AMBER  = Color(1.8, 1.3, 0.3, 0.9)

func _ready() -> void:
	collision_layer = 4 # Enemy projectile
	collision_mask = 2 | 1 # Player and Arena walls
	body_entered.connect(_on_body_entered)

	var shape = CircleShape2D.new()
	shape.radius = 9.0
	var col = CollisionShape2D.new()
	col.shape = shape
	add_child(col)

func setup(start_pos: Vector2, target_dir: Vector2, dmg: float = 26.0) -> void:
	global_position = start_pos
	direction = target_dir.normalized()
	damage = dmg
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	if has_hit:
		return

	flight_timer += delta
	anim_phase += delta * 16.0
	if flight_timer >= lifetime:
		_explode("TIMEOUT")
		return

	global_position += direction * speed * delta
	queue_redraw()

func _draw() -> void:
	var wobble = sin(anim_phase) * 1.5
	var wobble_cos = cos(anim_phase * 1.3) * 1.2

	# 1. Ground Shadow (projected 16px down, isometric 2:1 ratio)
	var shadow_pos = Vector2(0.0, 16.0).rotated(-rotation)
	var shadow_pts = PackedVector2Array()
	for i in range(10):
		var a = i * TAU / 10.0
		var r_x = 10.0 + wobble * 0.5
		var r_y = 4.5 + wobble * 0.25
		shadow_pts.append(shadow_pos + Vector2(cos(a) * r_x, sin(a) * r_y))
	draw_colored_polygon(shadow_pts, Color(0.0, 0.0, 0.0, 0.38))

	# 2. Flame Wake / Trailing Plasma Tendrils
	for k in range(4):
		var trail_offset = -Vector2(6.0 + k * 5.0, sin(anim_phase + k * 1.2) * (2.5 + k))
		var trail_rad = maxf(1.5, 5.5 - k * 1.1)
		var trail_col = (COL_HOLY_AMBER if is_reflected else COL_FIRE_RED)
		trail_col.a = 0.65 - (k * 0.13)
		draw_circle(trail_offset, trail_rad, trail_col)

	# 3. Outer Corona
	var corona_col = COL_HOLY_GOLD if is_reflected else COL_FIRE_ORANGE
	draw_circle(Vector2(0, 0), 8.5 + wobble * 0.6, corona_col)

	# 4. Mid Solar Flares (4 pulsating diamond tongues)
	var mid_col = COL_HOLY_CORE if is_reflected else COL_FIRE_YELLOW
	var flare_poly = PackedVector2Array([
		Vector2(11.0 + wobble, 0.0),
		Vector2(1.0, -4.5 - wobble_cos),
		Vector2(-9.0, 0.0),
		Vector2(1.0, 4.5 + wobble_cos)
	])
	draw_colored_polygon(flare_poly, mid_col)

	# 5. Core
	var core_col = Color.WHITE
	draw_circle(Vector2(1.5, 0.0), 4.2, core_col)

func _on_body_entered(body: Node2D) -> void:
	if has_hit:
		return

	if body.is_in_group("player"):
		if is_reflected:
			return
		if body.has_method("take_damage"):
			var hit_result = body.take_damage(damage, direction, false, self)
			if hit_result == "PARRIED":
				_reflect()
				return
			has_hit = true
			_explode("HIT")

	elif is_reflected and body.is_in_group("enemies"):
		has_hit = true
		if body.has_method("take_damage"):
			body.take_damage(damage * 1.6, direction)
		if body.has_method("apply_stun"):
			body.apply_stun(1.5)
		_explode("REFLECT_HIT")

	elif body is StaticBody2D:
		has_hit = true
		_explode("WALL")

func _reflect() -> void:
	is_reflected = true
	direction = -direction
	rotation = direction.angle()
	speed *= 1.40
	flight_timer = 0.0
	lifetime = 3.0

	collision_layer = 2 # Player projectile
	collision_mask = 4 | 1 # Hit enemies & walls

	_spawn_reflect_blast()
	queue_redraw()

func _explode(reason: String) -> void:
	has_hit = true
	var root = get_parent()
	if not root:
		queue_free()
		return

	# 1. Fireball Detonation Shockwave Ring
	var ring = Line2D.new()
	ring.width = 3.2
	ring.default_color = Color(2.5, 1.8, 0.5, 1.0) if is_reflected else Color(2.2, 0.8, 0.2, 1.0)
	var pts = PackedVector2Array()
	for i in range(17):
		var a = i * TAU / 16.0
		pts.append(Vector2(cos(a) * 12.0, sin(a) * 7.0))
	ring.points = pts
	ring.position = global_position
	root.add_child(ring)

	var tween = create_tween()
	tween.tween_property(ring, "scale", Vector2(3.2, 3.2), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.24)
	tween.tween_callback(ring.queue_free)

	# 2. Sparks and Ember Burst
	var emitter = CPUParticles2D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.amount = 24
	emitter.lifetime = 0.35
	emitter.explosiveness = 0.95
	emitter.spread = 180.0
	emitter.gravity = Vector2(0, 40)
	emitter.initial_velocity_min = 70.0
	emitter.initial_velocity_max = 200.0
	emitter.scale_amount_min = 2.0
	emitter.scale_amount_max = 4.5
	emitter.color = Color(2.4, 2.0, 0.5, 1.0) if is_reflected else Color(2.2, 0.6, 0.1, 1.0)
	emitter.position = global_position
	root.add_child(emitter)
	emitter.restart()
	emitter.emitting = true
	emitter.finished.connect(emitter.queue_free)

	queue_free()

func _spawn_reflect_blast() -> void:
	var root = get_parent()
	if not root:
		return
	var ring = Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(2.5, 2.2, 0.6, 1.0)
	var pts = PackedVector2Array()
	for i in range(13):
		var a = i * TAU / 12.0
		pts.append(Vector2(cos(a) * 9.0, sin(a) * 5.0))
	ring.points = pts
	ring.position = global_position
	root.add_child(ring)

	var tween = create_tween()
	tween.tween_property(ring, "scale", Vector2(2.5, 2.5), 0.18)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.18)
	tween.tween_callback(ring.queue_free)
