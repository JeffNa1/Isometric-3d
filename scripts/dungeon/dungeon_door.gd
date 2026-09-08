class_name DungeonDoor
extends Node2D

## Medieval Reinforced Dungeon Door
## - Heavy double oak planks with forged iron bands, studs, and ring handle
## - Walk into door: Swings open smoothly in 2.5D perspective, unlocks passage, activates connected room
## - Dash through door: Shatters violently into bursting wood splinters and iron chunks, screen shake, disappears!

signal door_opened(door_instance: DungeonDoor)
signal door_shattered(door_instance: DungeonDoor)

enum State { CLOSED, OPENING, OPEN, SHATTERED }

const DOOR_HEIGHT: float = 144.0 # Fits cleanly under the 145px arch clearance

var room_a_idx: int = 0
var room_b_idx: int = 0
var door_dir: Vector2i = Vector2i.ZERO # DIR_NE, DIR_NW, DIR_SE, DIR_SW

var half_span: Vector2 = Vector2.ZERO
var door_base_center: Vector2 = Vector2.ZERO
var door_leaf_width: float = 85.0
var door_axis_vector: Vector2 = Vector2.ZERO
var room_forward_dir: Vector2 = Vector2.ZERO

var current_state: State = State.CLOSED
var open_progress: float = 0.0 # 0.0 = closed, 1.0 = fully swung open

var static_body: StaticBody2D = null
var sensor_area: Area2D = null
var collision_shape: CollisionShape2D = null

func setup(
	p_a: Vector2,
	p_b: Vector2,
	p_dir: Vector2i,
	p_room_a: int,
	p_room_b: int
) -> void:
	door_dir = p_dir
	room_a_idx = p_room_a
	room_b_idx = p_room_b
	
	# Match wall segment anchor for precision ground Y-sorting
	var anchor_x = (p_a.x + p_b.x) * 0.5
	var anchor_y = minf(p_a.y, p_b.y) - 40.0
	position = Vector2(anchor_x, anchor_y)
	
	var loc_a = p_a - position
	var loc_b = p_b - position
	door_base_center = (loc_a + loc_b) * 0.5
	
	half_span = (loc_b - loc_a) * 0.5
	door_leaf_width = half_span.length()
	door_axis_vector = half_span.normalized()
	
	# Isometric direction vector pointing into connected room
	var wx = float(door_dir.x - door_dir.y) * 360.0
	var wy = float(door_dir.x + door_dir.y) * 180.0
	room_forward_dir = Vector2(wx, wy).normalized()
	
	_setup_collision_and_sensor(loc_a, loc_b)
	queue_redraw()

func _setup_collision_and_sensor(loc_a: Vector2, loc_b: Vector2) -> void:
	# 1. Physics Blocker (closed door blocks movement)
	static_body = StaticBody2D.new()
	static_body.name = "DoorCollider"
	static_body.collision_layer = 1
	static_body.collision_mask = 0
	add_child(static_body)
	
	collision_shape = CollisionShape2D.new()
	var seg = SegmentShape2D.new()
	seg.a = loc_a
	seg.b = loc_b
	collision_shape.shape = seg
	static_body.add_child(collision_shape)
	
	# 2. Proximity & Dash Sensor Area
	sensor_area = Area2D.new()
	sensor_area.name = "DoorSensor"
	sensor_area.collision_layer = 0
	sensor_area.collision_mask = 2 # Detect player
	sensor_area.monitorable = false
	sensor_area.position = door_base_center
	add_child(sensor_area)
	
	var sensor_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 56.0
	sensor_shape.shape = circle
	sensor_area.add_child(sensor_shape)
	
	sensor_area.body_entered.connect(_on_body_entered)

func _process(_delta: float) -> void:
	if current_state != State.SHATTERED and is_instance_valid(sensor_area):
		for body in sensor_area.get_overlapping_bodies():
			if body.is_in_group("player"):
				_check_player_interaction(body)
				break

func _on_body_entered(body: Node2D) -> void:
	if current_state != State.SHATTERED and body.is_in_group("player"):
		_check_player_interaction(body)

func _check_player_interaction(player: Node2D) -> void:
	if current_state == State.SHATTERED:
		return
		
	# Check if player is dashing
	var is_dashing = player.get("is_dashing") == true
	if is_dashing:
		var dash_dir = player.get("dash_direction")
		if not (dash_dir is Vector2):
			dash_dir = player.velocity.normalized()
		if dash_dir == Vector2.ZERO:
			dash_dir = (position - player.global_position).normalized()
		shatter_door(dash_dir)
	elif current_state == State.CLOSED:
		open_door()

func open_door() -> void:
	if current_state != State.CLOSED:
		return
		
	current_state = State.OPENING
	
	# Disable physics blocker
	if is_instance_valid(static_body):
		static_body.set_collision_layer_value(1, false)
		
	# Smooth 2.5D swing open animation with guaranteed per-frame redraw
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(val: float):
		open_progress = val
		queue_redraw()
	, 0.0, 1.0, 0.42)
	tween.chain().tween_callback(func():
		current_state = State.OPEN
		queue_redraw()
	)
	
	door_opened.emit(self)

func shatter_door(dash_dir: Vector2) -> void:
	if current_state == State.SHATTERED:
		return
		
	current_state = State.SHATTERED
	
	# 1. Immediately disable collision
	if is_instance_valid(static_body):
		static_body.queue_free()
		static_body = null
	if is_instance_valid(sensor_area):
		sensor_area.queue_free()
		sensor_area = null
		
	# 2. Camera Trauma Shake
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.48)
	if cam and cam.has_method("trigger_zoom_punch"):
		cam.trigger_zoom_punch(0.045, 0.28)
		
	# 3. Spawn Bursting Wood Splinters & Iron Debris
	_spawn_shatter_debris(dash_dir)
	
	door_shattered.emit(self)
	
	# 4. Hide visual door immediately without destroying node so state persists
	visible = false
	queue_redraw()

func _spawn_shatter_debris(impact_dir: Vector2) -> void:
	var root = get_parent()
	if not root:
		root = self
		
	var debris_origin = global_position + door_base_center
	
	# Create wood splinter particle emitter
	var wood_emitter = CPUParticles2D.new()
	wood_emitter.global_position = debris_origin + Vector2(0.0, -DOOR_HEIGHT * 0.45)
	wood_emitter.emitting = false
	wood_emitter.one_shot = true
	wood_emitter.explosiveness = 0.96
	wood_emitter.amount = 32
	wood_emitter.lifetime = 0.65
	wood_emitter.spread = 110.0
	wood_emitter.direction = impact_dir.normalized()
	wood_emitter.gravity = Vector2(0.0, 360.0)
	wood_emitter.initial_velocity_min = 160.0
	wood_emitter.initial_velocity_max = 380.0
	wood_emitter.angular_velocity_min = -720.0
	wood_emitter.angular_velocity_max = 720.0
	wood_emitter.scale_amount_min = 3.5
	wood_emitter.scale_amount_max = 8.0
	wood_emitter.color = Color(0.38, 0.26, 0.16, 1.0) # Dark oak wood splinters
	root.add_child(wood_emitter)
	wood_emitter.restart()
	
	# Create iron stud & hinge shrapnel emitter
	var iron_emitter = CPUParticles2D.new()
	iron_emitter.global_position = debris_origin + Vector2(0.0, -DOOR_HEIGHT * 0.5)
	iron_emitter.emitting = false
	iron_emitter.one_shot = true
	iron_emitter.explosiveness = 0.98
	iron_emitter.amount = 18
	iron_emitter.lifetime = 0.55
	iron_emitter.spread = 160.0
	iron_emitter.direction = impact_dir.normalized()
	iron_emitter.gravity = Vector2(0.0, 480.0)
	iron_emitter.initial_velocity_min = 120.0
	iron_emitter.initial_velocity_max = 320.0
	iron_emitter.angular_velocity_min = -900.0
	iron_emitter.angular_velocity_max = 900.0
	iron_emitter.scale_amount_min = 2.0
	iron_emitter.scale_amount_max = 4.5
	iron_emitter.color = Color(0.65, 0.68, 0.75, 1.0) # Forged iron chunks
	root.add_child(iron_emitter)
	iron_emitter.restart()
	
	# White-hot kinetic impact shockwave ring
	var flash_ring = Node2D.new()
	flash_ring.global_position = debris_origin + Vector2(0.0, -DOOR_HEIGHT * 0.5)
	root.add_child(flash_ring)
	
	var tween = flash_ring.create_tween()
	var radius_tracker = {"r": 12.0, "alpha": 1.0}
	flash_ring.draw.connect(func():
		flash_ring.draw_circle(Vector2.ZERO, radius_tracker["r"], Color(1.4, 1.2, 0.8, radius_tracker["alpha"] * 0.75))
		flash_ring.draw_arc(Vector2.ZERO, radius_tracker["r"] * 1.5, 0.0, TAU, 28, Color(1.0, 0.85, 0.4, radius_tracker["alpha"]), 3.0)
	)
	
	tween.parallel().tween_method(func(val):
		radius_tracker["r"] = val
		flash_ring.queue_redraw()
	, 12.0, 95.0, 0.32)
	tween.parallel().tween_method(func(val):
		radius_tracker["alpha"] = val
		flash_ring.queue_redraw()
	, 1.0, 0.0, 0.32)
	tween.chain().tween_callback(flash_ring.queue_free)
	
	# Cleanup emitters after finished
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(wood_emitter):
			wood_emitter.queue_free()
		if is_instance_valid(iron_emitter):
			iron_emitter.queue_free()
	)

func _draw() -> void:
	if current_state == State.SHATTERED:
		return
		
	var up = Vector2(0.0, -DOOR_HEIGHT)
	var mid_base = door_base_center
	var loc_a = mid_base - half_span
	var loc_b = mid_base + half_span
	
	# Normal vector perpendicular to wall edge in isometric projection
	var norm = Vector2(-door_axis_vector.y, door_axis_vector.x)
	if norm.y < 0.0:
		norm = -norm
		
	# Left door leaf (hinge at loc_a, free edge swings from mid_base to swung open position)
	var left_hinge = loc_a
	var left_open_target = loc_a + norm * (door_leaf_width * 0.72) - door_axis_vector * 8.0
	var left_edge = mid_base.lerp(left_open_target, open_progress)
	_draw_door_leaf(left_hinge, left_edge, up, true)
	
	# Right door leaf (hinge at loc_b, free edge swings from mid_base to swung open position)
	var right_hinge = loc_b
	var right_open_target = loc_b + norm * (door_leaf_width * 0.72) + door_axis_vector * 8.0
	var right_edge = mid_base.lerp(right_open_target, open_progress)
	_draw_door_leaf(right_edge, right_hinge, up, false)

func _draw_door_leaf(p_start: Vector2, p_end: Vector2, up: Vector2, is_left: bool) -> void:
	# Perspective quad for door leaf
	var pts = PackedVector2Array([
		p_start,
		p_end,
		p_end + up,
		p_start + up
	])
	
	# 1. Dark aged oak plank body
	var wood_base = Color(0.18, 0.13, 0.09)
	var wood_alt = Color(0.24, 0.17, 0.12)
	draw_colored_polygon(pts, wood_base)
	
	# 2. Vertical wooden planks
	var plank_count = 3
	for i in range(1, plank_count):
		var t = float(i) / float(plank_count)
		var b_pt = p_start.lerp(p_end, t)
		var t_pt = (p_start + up).lerp(p_end + up, t)
		draw_line(b_pt, t_pt, Color(0.08, 0.06, 0.04, 0.95), 1.8)
		# Faint wood grain highlight
		draw_line(b_pt + Vector2(1, 0), t_pt + Vector2(1, 0), Color(0.35, 0.25, 0.16, 0.35), 1.0)
		
	# 3. Heavy forged iron cross-straps (hinge bands)
	for strap_y in [0.22, 0.52, 0.82]:
		var s_bot = p_start.lerp(p_start + up, strap_y)
		var s_end = p_end.lerp(p_end + up, strap_y)
		var band_h = Vector2(0.0, -10.0)
		var iron_pts = PackedVector2Array([
			s_bot,
			s_end,
			s_end + band_h,
			s_bot + band_h
		])
		draw_colored_polygon(iron_pts, Color(0.12, 0.13, 0.16))
		draw_polyline(iron_pts, Color(0.04, 0.04, 0.06, 0.95), 1.6, true)
		# Top highlight on iron strap
		draw_line(s_bot + band_h, s_end + band_h, Color(0.42, 0.46, 0.55, 0.75), 1.5)
		
		# Iron rivets / studs on strap
		for r_idx in range(3):
			var rt = (float(r_idx) + 0.5) / 3.0
			var r_center = (s_bot + band_h * 0.5).lerp(s_end + band_h * 0.5, rt)
			draw_circle(r_center, 2.5, Color(0.48, 0.52, 0.62))
			draw_circle(r_center + Vector2(0.5, 0.5), 1.2, Color(0.05, 0.05, 0.08))
			
	# 4. Iron Ring Knocker / Handle near meeting edge
	var handle_y = 0.50
	var handle_pt = p_end.lerp(p_end + up, handle_y) if is_left else p_start.lerp(p_start + up, handle_y)
	var handle_offset = (p_start - p_end).normalized() * 12.0 if is_left else (p_end - p_start).normalized() * 12.0
	var h_pos = handle_pt + handle_offset
	
	# Iron mounting plate
	draw_circle(h_pos, 5.0, Color(0.10, 0.11, 0.14))
	# Hanging ring handle
	draw_arc(h_pos + Vector2(0.0, 5.0), 4.5, 0.0, TAU, 16, Color(0.45, 0.48, 0.56), 1.8)
	
	# 5. Outer door frame border
	draw_polyline(pts, Color(0.04, 0.04, 0.06, 0.98), 2.2, true)
