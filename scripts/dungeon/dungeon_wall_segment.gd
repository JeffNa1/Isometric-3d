class_name DungeonWallSegment
extends Node2D

## 2.5D Isometric Wall Segment with Precision Ground Y-Sorting
## - Sliced sub-segments provide monotonic Y-sorting: zero clipping against player & monsters
## - North walls anchor at min(Y) - 40px: 100% guarantees player/monsters never clip under walls even in apex corners!
## - South walls anchor at max(Y) + 40px: 100% guarantees 24px low curb is always in front of feet
## - Continuous stone block masonry courses calculated from full-edge coordinates (no barcode seams)
## - Outer borders only drawn on edge endpoints; internal slice seams are 100% borderless
## - Doorway Pillars: 3D return jambs giving authentic stone wall thickness
## - Doorway Arch: Overhead Gothic stone lintel connecting North doorway pillars with 145px clearance

var pt_a: Vector2 = Vector2.ZERO
var pt_b: Vector2 = Vector2.ZERO
var dir: Vector2i = Vector2i.ZERO
var is_north_wall: bool = false
var room_index: int = 0
var wall_height: float = 200.0

var slice_start_dist: float = 0.0
var is_first_slice: bool = true
var is_last_slice: bool = true

var is_door_pillar_a: bool = false
var is_door_pillar_b: bool = false
var is_door_arch: bool = false

var local_a: Vector2 = Vector2.ZERO
var local_b: Vector2 = Vector2.ZERO

func setup(
	p_a: Vector2,
	p_b: Vector2,
	p_dir: Vector2i,
	p_is_north: bool,
	p_room_idx: int,
	p_start_dist: float = 0.0,
	p_is_first: bool = true,
	p_is_last: bool = true,
	p_material: Material = null
) -> void:
	pt_a = p_a
	pt_b = p_b
	dir = p_dir
	is_north_wall = p_is_north
	room_index = p_room_idx
	slice_start_dist = p_start_dist
	is_first_slice = p_is_first
	is_last_slice = p_is_last
	if p_material:
		self.material = p_material
	set_meta("room_index", room_index)
	
	wall_height = 200.0 if is_north_wall else 24.0
	
	# Precision Ground Y-Sorting:
	# - North walls: anchor placed at northern-most base point - 40px
	#   Guarantees that ANY entity inside the room (including in acute apex corners)
	#   always has Y_entity > Y_anchor, so the entity is ALWAYS drawn IN FRONT of the 200px wall!
	# - South walls: anchor placed at southern-most base point + 40px
	#   Guarantees that the 24px low curb is always drawn IN FRONT of entity feet!
	var anchor_x = (pt_a.x + pt_b.x) * 0.5
	var anchor_y = 0.0
	if is_north_wall:
		anchor_y = minf(pt_a.y, pt_b.y) - 40.0
	else:
		anchor_y = maxf(pt_a.y, pt_b.y) + 40.0
		
	position = Vector2(anchor_x, anchor_y)
	
	local_a = pt_a - position
	local_b = pt_b - position
	
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	queue_redraw()

func _draw() -> void:
	if is_door_arch:
		_draw_door_arch()
	elif is_north_wall:
		_draw_north_wall()
	else:
		_draw_south_wall()

func _draw_north_wall() -> void:
	var up = Vector2(0.0, -wall_height)
	var seg_len = (local_b - local_a).length()
	var is_ne = (dir == Vector2i(0, -1))
	
	# 1. Main vertical stone facade rendered with authentic stone masonry shader
	var facade_pts = PackedVector2Array([
		local_a,
		local_b,
		local_b + up,
		local_a + up
	])
	var facade_uvs = PackedVector2Array([
		Vector2(slice_start_dist, 0.0),
		Vector2(slice_start_dist + seg_len, 0.0),
		Vector2(slice_start_dist + seg_len, wall_height),
		Vector2(slice_start_dist, wall_height)
	])
	draw_colored_polygon(facade_pts, Color.WHITE, facade_uvs)
	
	# 2. Door Jamb (3D return face at doorway opening)
	if is_door_pillar_a:
		var jamb_w = Vector2(-12.0, 6.0) if is_ne else Vector2(12.0, 6.0)
		var jamb_pts = PackedVector2Array([
			local_b,
			local_b + jamb_w,
			local_b + jamb_w + up,
			local_b + up
		])
		var jamb_uvs = PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(14.0, 0.0),
			Vector2(14.0, wall_height),
			Vector2(0.0, wall_height)
		])
		draw_colored_polygon(jamb_pts, Color(0.48, 0.48, 0.52), jamb_uvs)
		draw_polyline(jamb_pts, Color(0.03, 0.04, 0.06, 0.95), 1.8, true)
	elif is_door_pillar_b:
		var jamb_w = Vector2(12.0, -6.0) if is_ne else Vector2(-12.0, -6.0)
		var jamb_pts = PackedVector2Array([
			local_a,
			local_a + jamb_w,
			local_a + jamb_w + up,
			local_a + up
		])
		var jamb_uvs = PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(14.0, 0.0),
			Vector2(14.0, wall_height),
			Vector2(0.0, wall_height)
		])
		draw_colored_polygon(jamb_pts, Color(0.48, 0.48, 0.52), jamb_uvs)
		draw_polyline(jamb_pts, Color(0.03, 0.04, 0.06, 0.95), 1.8, true)
		
	# 3. Outer edge vertical borders (only at room corners or doorway edges)
	if is_first_slice:
		draw_line(local_a, local_a + up, Color(0.03, 0.04, 0.06, 0.98), 2.2)
	if is_last_slice:
		draw_line(local_b, local_b + up, Color(0.03, 0.04, 0.06, 0.98), 2.2)

func _draw_door_arch() -> void:
	# Overhead Gothic Lintel Arch above doorway opening (height 145px to 200px)
	var arch_bot_h = 145.0
	var arch_top_h = wall_height
	var seg_len = (local_b - local_a).length()
	
	var bot_a = local_a + Vector2(0.0, -arch_bot_h)
	var bot_b = local_b + Vector2(0.0, -arch_bot_h)
	var top_b = local_b + Vector2(0.0, -arch_top_h)
	var top_a = local_a + Vector2(0.0, -arch_top_h)
	
	var arch_pts = PackedVector2Array([bot_a, bot_b, top_b, top_a])
	var arch_uvs = PackedVector2Array([
		Vector2(slice_start_dist, arch_bot_h),
		Vector2(slice_start_dist + seg_len, arch_bot_h),
		Vector2(slice_start_dist + seg_len, arch_top_h),
		Vector2(slice_start_dist, arch_top_h)
	])
	# 1. Main arch lintel stone facade
	draw_colored_polygon(arch_pts, Color.WHITE, arch_uvs)
	
	# 2. Arch border and underside clearance line (drawn BEFORE keystone so it never cuts through!)
	draw_line(bot_a, bot_b, Color(0.03, 0.04, 0.06, 0.95), 2.5)
	draw_polyline(arch_pts, Color(0.03, 0.04, 0.06, 0.98), 2.0, true)
	
	# 3. Central Keystone (sculpted wedge stone proudly overlapping the arch)
	var mid_bot = bot_a.lerp(bot_b, 0.5)
	var mid_top = top_a.lerp(top_b, 0.5)
	var kw_bot = 12.0
	var kw_top = 16.0
	var key_pts = PackedVector2Array([
		mid_bot + Vector2(-kw_bot, 8.0),
		mid_bot + Vector2(kw_bot, 8.0),
		mid_top + Vector2(kw_top, -2.0),
		mid_top + Vector2(-kw_top, -2.0)
	])
	var key_uvs = PackedVector2Array([
		Vector2(slice_start_dist + seg_len * 0.5 - kw_bot, arch_bot_h - 8.0),
		Vector2(slice_start_dist + seg_len * 0.5 + kw_bot, arch_bot_h - 8.0),
		Vector2(slice_start_dist + seg_len * 0.5 + kw_top, arch_top_h + 2.0),
		Vector2(slice_start_dist + seg_len * 0.5 - kw_top, arch_top_h + 2.0)
	])
	draw_colored_polygon(key_pts, Color(1.22, 1.22, 1.28), key_uvs)
	draw_polyline(key_pts, Color(0.04, 0.04, 0.06, 0.95), 2.2, true)
	# Inner chiseled highlight on top and left edge of keystone
	draw_line(key_pts[3], key_pts[0], Color(1.5, 1.5, 1.6, 0.6), 1.5)
	draw_line(key_pts[3], key_pts[2], Color(1.5, 1.5, 1.6, 0.6), 1.5)

func _draw_south_wall() -> void:
	# South Wall: Low 24px stone balustrade curb
	var up = Vector2(0.0, -wall_height)
	var seg_len = (local_b - local_a).length()
	
	var facade_pts = PackedVector2Array([
		local_a,
		local_b,
		local_b + up,
		local_a + up
	])
	var facade_uvs = PackedVector2Array([
		Vector2(slice_start_dist, 0.0),
		Vector2(slice_start_dist + seg_len, 0.0),
		Vector2(slice_start_dist + seg_len, wall_height),
		Vector2(slice_start_dist, wall_height)
	])
	draw_colored_polygon(facade_pts, Color.WHITE, facade_uvs)
	
	# Only outer ends draw vertical borders, NEVER internal seams!
	if is_first_slice:
		draw_line(local_a, local_a + up, Color(0.03, 0.03, 0.05, 0.95), 1.8)
	if is_last_slice:
		draw_line(local_b, local_b + up, Color(0.03, 0.03, 0.05, 0.95), 1.8)
