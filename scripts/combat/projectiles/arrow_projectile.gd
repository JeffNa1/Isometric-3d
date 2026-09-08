class_name ArrowProjectile
extends Area2D

## 2.5D Isometric Bone Arrow Projectile
## Shot by Skeleton Archer:
## - Flies along isometric trajectory with grounded shadow
## - Can be blocked (LMB) or parried (F) by Player
## - Spawns impact dust/sparks upon hit

@export var speed: float = 520.0
@export var damage: float = 18.0
@export var lifetime: float = 2.5

var direction: Vector2 = Vector2.DOWN
var flight_timer: float = 0.0
var has_hit: bool = false
var is_reflected: bool = false

# Visual properties
const COL_WOOD     = Color(0.38, 0.28, 0.18)
const COL_BONE_TIP = Color(0.92, 0.88, 0.80)
const COL_FLETCH   = Color(0.18, 0.15, 0.16)

func _ready() -> void:
	collision_layer = 4 # Projectiles layer
	collision_mask = 2 | 1 # Player (2) and Arena boundaries (1)
	body_entered.connect(_on_body_entered)

	var shape = CircleShape2D.new()
	shape.radius = 6.0
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
	if flight_timer >= lifetime:
		queue_free()
		return

	global_position += direction * speed * delta
	queue_redraw()

func _draw() -> void:
	# 1. Ground Shadow (projected 14px down)
	var shadow_pos = Vector2(0.0, 14.0).rotated(-rotation)
	var shadow_pts = PackedVector2Array()
	for i in range(8):
		var a = i * TAU / 8.0
		shadow_pts.append(shadow_pos + Vector2(cos(a) * 8.0, sin(a) * 3.5))
	draw_colored_polygon(shadow_pts, Color(0.0, 0.0, 0.0, 0.35))

	# 2. Arrow Shaft
	var tail = Vector2(-12.0, 0.0)
	var head = Vector2(10.0, 0.0)
	draw_line(tail, head, COL_WOOD, 2.0, false)

	# 3. Bone Arrowhead (Glows gold if reflected)
	var tip_col = Color(2.0, 1.6, 0.4, 1.0) if is_reflected else COL_BONE_TIP
	var head_poly = PackedVector2Array([
		head + Vector2(4.0, 0.0),
		head + Vector2(-3.0, -3.0),
		head + Vector2(-1.5, 0.0),
		head + Vector2(-3.0, 3.0)
	])
	draw_colored_polygon(head_poly, tip_col)

	# 4. Fletchings
	draw_line(tail, tail + Vector2(-3.0, -3.5), COL_FLETCH, 1.4, false)
	draw_line(tail, tail + Vector2(-3.0, 3.5), COL_FLETCH, 1.4, false)
	draw_line(tail + Vector2(4.0, 0.0), tail + Vector2(1.0, -3.0), COL_FLETCH, 1.2, false)
	draw_line(tail + Vector2(4.0, 0.0), tail + Vector2(1.0, 3.0), COL_FLETCH, 1.2, false)

	# 5. Reflected golden aura streak
	if is_reflected:
		draw_line(tail - Vector2(8.0, 0.0), head + Vector2(4.0, 0.0), Color(2.2, 1.8, 0.5, 0.70), 3.0, false)
		draw_line(tail - Vector2(12.0, 0.0), head + Vector2(4.0, 0.0), Color(1.0, 1.0, 1.0, 0.9), 1.2, false)

func _on_body_entered(body: Node2D) -> void:
	if has_hit:
		return

	# If reflected, ignore player
	if body.is_in_group("player"):
		if is_reflected:
			return
		if body.has_method("take_damage"):
			var hit_result = body.take_damage(damage, direction, false, self) # is_melee = false, attacker = self
			_spawn_impact_particles(hit_result)
			if hit_result == "PARRIED":
				_reflect()
				return
			has_hit = true
			queue_free()

	elif is_reflected and body.is_in_group("enemies") and body.has_method("take_damage"):
		has_hit = true
		body.take_damage(damage * 1.5, direction)
		_spawn_impact_particles("HIT")
		queue_free()

	elif body is StaticBody2D: # Arena wall
		has_hit = true
		_spawn_impact_particles("WALL")
		queue_free()

func _reflect() -> void:
	is_reflected = true
	# Reverse direction 180 degrees back along incoming trajectory
	direction = -direction
	rotation = direction.angle()
	speed *= 1.35
	flight_timer = 0.0 # Reset lifetime for full return trip
	lifetime = 3.0

	# Switch collision mask to detect Enemies (layer 4) and Arena walls (layer 1)
	collision_layer = 2 # Player-side projectile
	collision_mask = 4 | 1

	# Deflection golden burst ring
	_spawn_deflect_burst()
	queue_redraw()

func _spawn_deflect_burst() -> void:
	var root = get_parent()
	if not root:
		return
	var ring = Line2D.new()
	ring.width = 2.5
	ring.default_color = Color(2.0, 1.6, 0.5, 1.0)
	var pts = PackedVector2Array()
	for i in range(13):
		var a = i * TAU / 12.0
		pts.append(Vector2(cos(a) * 8.0, sin(a) * 8.0))
	ring.points = pts
	ring.position = global_position
	root.add_child(ring)

	var tween = create_tween()
	tween.tween_property(ring, "scale", Vector2(2.2, 2.2), 0.16)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.16)
	tween.tween_callback(ring.queue_free)

func _spawn_impact_particles(result: String) -> void:
	var root = get_parent()
	if not root:
		return

	var emitter = CPUParticles2D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.lifetime = 0.30
	emitter.explosiveness = 0.95
	emitter.spread = 160.0
	emitter.initial_velocity_min = 60.0
	emitter.initial_velocity_max = 180.0
	emitter.scale_amount_min = 1.5
	emitter.scale_amount_max = 3.5
	emitter.position = global_position

	match result:
		"PARRIED":
			emitter.amount = 24
			emitter.color = Color(1.5, 1.3, 0.4, 1.0)
		"BLOCKED":
			emitter.amount = 16
			emitter.color = Color(0.9, 0.85, 0.6, 1.0)
		_:
			emitter.amount = 12
			emitter.color = Color(0.85, 0.80, 0.70, 1.0)

	root.add_child(emitter)
	emitter.restart()
	emitter.emitting = true

	emitter.finished.connect(emitter.queue_free)
