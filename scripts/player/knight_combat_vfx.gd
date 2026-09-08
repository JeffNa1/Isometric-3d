class_name KnightCombatVFX
extends RefCounted

## Dedicated visual effects helper for Dark Knight combat & kinematics.

static func spawn_360_whirlwind(parent: Node, origin: Vector2) -> void:
	if not parent or not is_instance_valid(parent):
		return

	var center_ground = origin + Vector2(0.0, -4.0)

	# 1. PRIMARY EXPANDING ISOMETRIC SHOCKWAVE RING (Outer Blast)
	var ring_out = Line2D.new()
	ring_out.width = 3.2
	ring_out.default_color = Color(1.3, 1.6, 2.2, 0.95)
	var pts_out = PackedVector2Array()
	for i in range(33):
		var a = i * TAU / 32.0
		pts_out.append(Vector2(cos(a) * 20.0, sin(a) * 11.5))
	ring_out.points = pts_out
	ring_out.position = center_ground
	parent.add_child(ring_out)

	var tween_out = ring_out.create_tween()
	tween_out.tween_property(ring_out, "scale", Vector2(5.5, 5.5), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_out.parallel().tween_property(ring_out, "modulate:a", 0.0, 0.35)
	tween_out.parallel().tween_property(ring_out, "width", 1.0, 0.35)
	tween_out.tween_callback(ring_out.queue_free)

	# 2. SECONDARY GOLDEN CORE SHOCKWAVE RING (Inner Core)
	var ring_in = Line2D.new()
	ring_in.width = 2.4
	ring_in.default_color = Color(1.6, 1.4, 0.6, 0.9)
	var pts_in = PackedVector2Array()
	for i in range(25):
		var a = i * TAU / 24.0
		pts_in.append(Vector2(cos(a) * 14.0, sin(a) * 8.0))
	ring_in.points = pts_in
	ring_in.position = center_ground
	parent.add_child(ring_in)

	var tween_in = ring_in.create_tween()
	tween_in.tween_property(ring_in, "scale", Vector2(3.8, 3.8), 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_in.parallel().tween_property(ring_in, "modulate:a", 0.0, 0.26)
	tween_in.tween_callback(ring_in.queue_free)

	# 3. 6 RADIAL 360° WIND BLADE SLICES (Radial Wind Crescents)
	for k in range(6):
		var base_angle = k * TAU / 6.0
		var blade = Line2D.new()
		blade.width = 2.4
		blade.default_color = Color(1.2, 1.5, 2.2, 0.9)
		var b_pts = PackedVector2Array()
		var arc_span = deg_to_rad(45.0)
		for j in range(9):
			var a = base_angle - arc_span * 0.5 + (j * arc_span / 8.0)
			b_pts.append(Vector2(cos(a) * 22.0, sin(a) * 12.0))
		blade.points = b_pts
		blade.position = center_ground
		parent.add_child(blade)

		var flight_dir = Vector2(cos(base_angle), sin(base_angle) * 0.65).normalized()
		var target_pos = center_ground + flight_dir * 95.0

		var b_tween = blade.create_tween()
		b_tween.tween_property(blade, "position", target_pos, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		b_tween.parallel().tween_property(blade, "scale", Vector2(1.8, 1.8), 0.28)
		b_tween.parallel().tween_property(blade, "modulate:a", 0.0, 0.28)
		b_tween.tween_callback(blade.queue_free)

static func spawn_deflection_ring(parent: Node, origin: Vector2, aim_dir: Vector2) -> void:
	if not parent or not is_instance_valid(parent):
		return

	var ring = Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(1.5, 1.2, 0.6, 1.0)
	var pts = PackedVector2Array()
	for i in range(17):
		var a = i * TAU / 16.0
		pts.append(Vector2(cos(a) * 12.0, sin(a) * 8.0))
	ring.points = pts
	ring.position = origin + (aim_dir * 18.0) + Vector2(0.0, -16.0)
	parent.add_child(ring)

	var tween = ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(2.4, 2.4), 0.20)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.20)
	tween.tween_callback(ring.queue_free)

static func spawn_stun_shockwave(parent: Node, origin: Vector2, radius: float = 100.0) -> void:
	if not parent or not is_instance_valid(parent):
		return

	var ring = Line2D.new()
	ring.width = 3.5
	ring.default_color = Color(2.4, 2.0, 0.6, 1.0)
	var pts = PackedVector2Array()
	var num_pts = 24
	for i in range(num_pts + 1):
		var a = i * TAU / float(num_pts)
		pts.append(Vector2(cos(a) * (radius * 0.15), sin(a) * (radius * 0.15 * 0.70)))
	ring.points = pts
	ring.position = origin + Vector2(0.0, -12.0)
	parent.add_child(ring)

	var tween = ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(6.5, 6.5), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.28)
	tween.parallel().tween_property(ring, "width", 1.0, 0.28)
	tween.tween_callback(ring.queue_free)

static func spawn_ghost_trail(parent: Node, sprite: Sprite2D, z_idx: int) -> void:
	if not parent or not sprite or not sprite.texture:
		return

	var ghost = Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.global_position = sprite.global_position
	ghost.scale = sprite.scale
	ghost.modulate = Color(0.18, 0.35, 0.65, 0.55)
	ghost.z_index = z_idx - 1
	parent.add_child(ghost)

	var tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ghost.queue_free)
