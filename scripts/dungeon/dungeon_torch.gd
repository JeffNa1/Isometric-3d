class_name DungeonTorch
extends Node2D

## 2.5D Medieval Wall Torch / Sconce
## - Hand-forged wrought iron wall bracket mounted on stone masonry
## - Charred wooden torch in iron sconce cup
## - Animated multi-layer flickering flame with organic motion
## - Glowing ember spark particle emitter rising upwards
## - Provides dynamic warm illumination to floor and walls

@export var is_lit: bool = true
@export var flame_scale: float = 1.0

var flame_time: float = 0.0
var spark_emitter: CPUParticles2D = null

# Sconce mounting height on wall face
const MOUNT_HEIGHT: float = 118.0

func _ready() -> void:
	z_index = 0 # Y-sorted with wall segment
	_setup_particles()

func _setup_particles() -> void:
	spark_emitter = CPUParticles2D.new()
	spark_emitter.name = "Sparks"
	spark_emitter.position = Vector2(0.0, -MOUNT_HEIGHT - 12.0)
	spark_emitter.emitting = is_lit
	spark_emitter.amount = 8
	spark_emitter.lifetime = 0.8
	spark_emitter.lifetime_randomness = 0.4
	spark_emitter.spread = 45.0
	spark_emitter.direction = Vector2(0.0, -1.0)
	spark_emitter.gravity = Vector2(0.0, -15.0) # Floats up like heat
	spark_emitter.initial_velocity_min = 18.0
	spark_emitter.initial_velocity_max = 42.0
	spark_emitter.scale_amount_min = 1.2
	spark_emitter.scale_amount_max = 2.4
	spark_emitter.color = Color(1.3, 0.85, 0.35, 0.9)
	add_child(spark_emitter)

func _process(delta: float) -> void:
	if is_lit:
		flame_time += delta
		queue_redraw()

func get_light_world_pos() -> Vector2:
	return global_position + Vector2(0.0, -MOUNT_HEIGHT)

func _draw() -> void:
	var mount_pt = Vector2(0.0, -MOUNT_HEIGHT)
	
	# 1. Wrought-Iron Wall Mounting Plate
	var plate_w = 6.0
	var plate_h = 14.0
	var plate_pts = PackedVector2Array([
		mount_pt + Vector2(-plate_w, -plate_h),
		mount_pt + Vector2(plate_w, -plate_h),
		mount_pt + Vector2(plate_w, plate_h),
		mount_pt + Vector2(-plate_w, plate_h)
	])
	draw_colored_polygon(plate_pts, Color(0.12, 0.13, 0.16))
	draw_polyline(plate_pts, Color(0.03, 0.04, 0.06, 0.95), 1.5, true)
	# Wall iron rivets
	draw_circle(mount_pt + Vector2(0.0, -9.0), 1.5, Color(0.4, 0.44, 0.52))
	draw_circle(mount_pt + Vector2(0.0, 9.0), 1.5, Color(0.4, 0.44, 0.52))
	
	# 2. Curved Forged Iron Arm & Cup
	var arm_pts = PackedVector2Array([
		mount_pt + Vector2(0.0, 4.0),
		mount_pt + Vector2(7.0, 8.0),
		mount_pt + Vector2(12.0, 3.0),
		mount_pt + Vector2(10.0, -4.0)
	])
	draw_polyline(arm_pts, Color(0.14, 0.15, 0.19), 3.0)
	draw_polyline(arm_pts, Color(0.04, 0.04, 0.06), 1.4)
	
	# Iron Sconce Cup
	var cup_pos = mount_pt + Vector2(10.0, -4.0)
	var cup_pts = PackedVector2Array([
		cup_pos + Vector2(-6.0, 0.0),
		cup_pos + Vector2(6.0, 0.0),
		cup_pos + Vector2(4.0, 8.0),
		cup_pos + Vector2(-4.0, 8.0)
	])
	draw_colored_polygon(cup_pts, Color(0.16, 0.17, 0.22))
	draw_polyline(cup_pts, Color(0.04, 0.04, 0.06), 1.5, true)
	
	# 3. Charred Wooden Torch Head
	var torch_pos = cup_pos + Vector2(0.0, -3.0)
	var torch_pts = PackedVector2Array([
		torch_pos + Vector2(-3.5, 0.0),
		torch_pos + Vector2(3.5, 0.0),
		torch_pos + Vector2(2.5, -12.0),
		torch_pos + Vector2(-2.5, -12.0)
	])
	draw_colored_polygon(torch_pts, Color(0.18, 0.12, 0.08))
	draw_polyline(torch_pts, Color(0.05, 0.04, 0.03), 1.2, true)
	
	if not is_lit:
		return
		
	# 4. Animated Multi-Layer Medieval Torch Flame
	var flame_tip = torch_pos + Vector2(0.0, -12.0)
	var f1 = sin(flame_time * 14.2) * 2.2
	var f2 = cos(flame_time * 19.7) * 1.8
	var h_flicker = 1.0 + sin(flame_time * 11.5) * 0.14
	
	# Layer A: Soft Crimson-Orange Glow Halo
	draw_circle(flame_tip + Vector2(f1 * 0.3, -8.0 * h_flicker), 14.0 * flame_scale, Color(1.0, 0.35, 0.08, 0.18))
	
	# Layer B: Outer Fiery Orange Body
	var outer_pts = PackedVector2Array([
		flame_tip + Vector2(-5.0, 0.0),
		flame_tip + Vector2(5.0, 0.0),
		flame_tip + Vector2(4.0 + f1 * 0.5, -9.0 * h_flicker),
		flame_tip + Vector2(f1 + f2 * 0.5, -20.0 * h_flicker),
		flame_tip + Vector2(-4.0 + f1 * 0.5, -9.0 * h_flicker)
	])
	draw_colored_polygon(outer_pts, Color(1.1, 0.48, 0.12, 0.95))
	
	# Layer C: Inner Glowing Gold-Yellow Core
	var inner_pts = PackedVector2Array([
		flame_tip + Vector2(-2.5, -1.0),
		flame_tip + Vector2(2.5, -1.0),
		flame_tip + Vector2(2.0 + f1 * 0.3, -7.0 * h_flicker),
		flame_tip + Vector2(f1 * 0.6, -14.0 * h_flicker),
		flame_tip + Vector2(-2.0 + f1 * 0.3, -7.0 * h_flicker)
	])
	draw_colored_polygon(inner_pts, Color(1.3, 0.88, 0.32, 0.98))
	
	# Layer D: White-Hot Center Spark
	draw_circle(flame_tip + Vector2(f1 * 0.2, -4.0), 2.2, Color(1.5, 1.4, 1.0, 1.0))
