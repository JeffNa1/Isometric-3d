class_name DungeonRoomInstance
extends Node2D

## Visual & Physics Instance for a Single Dungeon Room in 2.5D Isometric Space
## - Authentic Stone Flagstone Floor rendered with medieval_dungeon_floor.gdshader
## - Towering 2.5D Isometric Walls with native Godot Y-Sorting per segment
## - Active Room Isolation: Can show/hide room floors, walls, and colliders
## - Open doorways with golden threshold runes and collision gaps

const TemplateClass = preload("res://scripts/dungeon/dungeon_room_template.gd")
const WallSegmentClass = preload("res://scripts/dungeon/dungeon_wall_segment.gd")
const DungeonDoorClass = preload("res://scripts/dungeon/dungeon_door.gd")
const DungeonTorchClass = preload("res://scripts/dungeon/dungeon_torch.gd")

const CELL_WIDTH: float = 720.0
const CELL_HEIGHT: float = 360.0

const DOOR_WIDTH_RATIO: float = 0.45 # Central 45% is open (approx 181px wide doorway)
const DOOR_SIDE_RATIO: float = (1.0 - DOOR_WIDTH_RATIO) * 0.5 # 0.275 flank on each side

var room_index: int = 0
var room_name: String = ""
var template_type: int = 0
var room_color: Color = Color(0.2, 0.25, 0.35)
var grid_origin: Vector2i = Vector2i.ZERO
var local_cells: Array = []
var global_cells: Array = []
var doors: Array = []

# Node References
var floor_parent_node: Node2D = null
var ysort_parent_node: Node2D = null
var shared_material: ShaderMaterial = null
var shared_wall_mat_ne: ShaderMaterial = null
var shared_wall_mat_nw: ShaderMaterial = null
var shared_curb_mat: ShaderMaterial = null

var floor_nodes: Array[Node2D] = []
var wall_nodes: Array[Node2D] = []
var door_nodes: Array[Node2D] = []
var torch_nodes: Array[Node2D] = []
var static_body: StaticBody2D = null
var center_world_pos: Vector2 = Vector2.ZERO

var is_currently_active: bool = false
var is_currently_peek: bool = false

static func cell_to_world(cell: Vector2i) -> Vector2:
	var wx = (cell.x - cell.y) * (CELL_WIDTH * 0.5)
	var wy = (cell.x + cell.y) * (CELL_HEIGHT * 0.5)
	return Vector2(wx, wy)

func setup(
	idx: int,
	t_type: int,
	origin: Vector2i,
	door_list: Array,
	floor_parent: Node2D,
	ysort_parent: Node2D,
	shared_mat: ShaderMaterial,
	shared_w_ne: ShaderMaterial = null,
	shared_w_nw: ShaderMaterial = null,
	shared_c_mat: ShaderMaterial = null
) -> void:
	room_index = idx
	template_type = t_type
	grid_origin = origin
	floor_parent_node = floor_parent
	ysort_parent_node = ysort_parent
	shared_material = shared_mat
	shared_wall_mat_ne = shared_w_ne
	shared_wall_mat_nw = shared_w_nw
	shared_curb_mat = shared_c_mat
	
	var tmpl = TemplateClass.get_template(template_type as TemplateClass.ShapeType)
	room_name = tmpl.get("name", "Room")
	room_color = tmpl.get("color", Color(0.2, 0.25, 0.35))
	
	local_cells.clear()
	global_cells.clear()
	for c in tmpl.get("cells", []):
		local_cells.append(c)
		global_cells.append(grid_origin + c)
		
	doors.clear()
	for d in door_list:
		doors.append(d)
	
	_calculate_center()
	_build_floor()
	_build_collision_and_walls()
	
	# Default to inactive (hidden) until activated
	set_room_active(false)

func _calculate_center() -> void:
	if global_cells.is_empty():
		return
	var sum = Vector2.ZERO
	for c in global_cells:
		sum += cell_to_world(c)
	center_world_pos = sum / float(global_cells.size())

func _build_floor() -> void:
	var target_parent = floor_parent_node if floor_parent_node else self
	var hw = CELL_WIDTH * 0.5
	var hh = CELL_HEIGHT * 0.5
	
	# 1. Tile Polygon for each cell using authentic medieval stone shader
	for c in global_cells:
		var c_world = cell_to_world(c)
		var p_top    = c_world + Vector2(0.0, -hh)
		var p_right  = c_world + Vector2(hw, 0.0)
		var p_bottom = c_world + Vector2(0.0, hh)
		var p_left   = c_world + Vector2(-hw, 0.0)
		
		var poly = Polygon2D.new()
		poly.name = "FloorCell_%d_%d" % [c.x, c.y]
		poly.polygon = PackedVector2Array([p_top, p_right, p_bottom, p_left])
		if shared_material:
			poly.material = shared_material
		poly.color = Color(1.0, 1.0, 1.0, 1.0)
		poly.z_index = -10
		poly.set_meta("room_index", room_index)
		target_parent.add_child(poly)
		floor_nodes.append(poly)
	
	# 2. Room 0 Spawn Altar (Sanctuary dais where player spawns)
	if room_index == 0:
		var altar = _create_spawn_altar()
		if altar:
			target_parent.add_child(altar)
			floor_nodes.append(altar)

func _create_spawn_altar() -> Node2D:
	var node = Node2D.new()
	node.name = "SpawnAltar"
	node.position = center_world_pos
	node.z_index = -3
	node.set_meta("room_index", room_index)
	
	# 1. Tier 1 (Base Stepped Dais): 150px wide x 75px tall isometric diamond
	var t1_w = 150.0
	var t1_h = 75.0
	var t1_poly = Polygon2D.new()
	t1_poly.polygon = PackedVector2Array([
		Vector2(0, -t1_h * 0.5),
		Vector2(t1_w * 0.5, 0),
		Vector2(0, t1_h * 0.5),
		Vector2(-t1_w * 0.5, 0)
	])
	t1_poly.color = Color(0.11, 0.12, 0.15) # Deep basalt stone
	node.add_child(t1_poly)
	
	# Step 1 Front Riser (vertical 3D stone drop face 10px)
	var riser1 = Polygon2D.new()
	riser1.polygon = PackedVector2Array([
		Vector2(-t1_w * 0.5, 0),
		Vector2(0, t1_h * 0.5),
		Vector2(0, t1_h * 0.5 + 10.0),
		Vector2(-t1_w * 0.5, 10.0)
	])
	riser1.color = Color(0.06, 0.07, 0.09)
	node.add_child(riser1)
	
	var riser1_r = Polygon2D.new()
	riser1_r.polygon = PackedVector2Array([
		Vector2(0, t1_h * 0.5),
		Vector2(t1_w * 0.5, 0),
		Vector2(t1_w * 0.5, 10.0),
		Vector2(0, t1_h * 0.5 + 10.0)
	])
	riser1_r.color = Color(0.08, 0.09, 0.12)
	node.add_child(riser1_r)
	
	# Tier 1 Rim outline
	var t1_line = Line2D.new()
	t1_line.points = PackedVector2Array([
		Vector2(0, -t1_h * 0.5),
		Vector2(t1_w * 0.5, 0),
		Vector2(0, t1_h * 0.5),
		Vector2(-t1_w * 0.5, 0),
		Vector2(0, -t1_h * 0.5)
	])
	t1_line.width = 2.2
	t1_line.default_color = Color(0.32, 0.36, 0.45, 0.85)
	node.add_child(t1_line)
	
	# 2. Tier 2 (Upper Altar Platform): 110px wide x 55px tall raised by 8px
	var t2_w = 110.0
	var t2_h = 55.0
	var t2_poly = Polygon2D.new()
	t2_poly.polygon = PackedVector2Array([
		Vector2(0, -t2_h * 0.5 - 6.0),
		Vector2(t2_w * 0.5, -6.0),
		Vector2(0, t2_h * 0.5 - 6.0),
		Vector2(-t2_w * 0.5, -6.0)
	])
	t2_poly.color = Color(0.18, 0.20, 0.26) # Polished gothic granite
	node.add_child(t2_poly)
	
	# Tier 2 Riser
	var riser2 = Polygon2D.new()
	riser2.polygon = PackedVector2Array([
		Vector2(-t2_w * 0.5, -6.0),
		Vector2(0, t2_h * 0.5 - 6.0),
		Vector2(0, t2_h * 0.5),
		Vector2(-t2_w * 0.5, 0)
	])
	riser2.color = Color(0.09, 0.10, 0.13)
	node.add_child(riser2)
	
	var riser2_r = Polygon2D.new()
	riser2_r.polygon = PackedVector2Array([
		Vector2(0, t2_h * 0.5 - 6.0),
		Vector2(t2_w * 0.5, -6.0),
		Vector2(t2_w * 0.5, 0),
		Vector2(0, t2_h * 0.5)
	])
	riser2_r.color = Color(0.12, 0.13, 0.17)
	node.add_child(riser2_r)
	
	# Tier 2 Rim line
	var t2_line = Line2D.new()
	t2_line.points = PackedVector2Array([
		Vector2(0, -t2_h * 0.5 - 6.0),
		Vector2(t2_w * 0.5, -6.0),
		Vector2(0, t2_h * 0.5 - 6.0),
		Vector2(-t2_w * 0.5, -6.0),
		Vector2(0, -t2_h * 0.5 - 6.0)
	])
	t2_line.width = 1.8
	t2_line.default_color = Color(0.48, 0.54, 0.65, 0.9)
	node.add_child(t2_line)
	
	# 3. Central Inlaid Golden Arcane Rune (where player spawns)
	var crest = Node2D.new()
	crest.position = Vector2(0.0, -6.0)
	node.add_child(crest)
	
	var rune_w = 64.0
	var rune_h = 32.0
	var rune_line = Line2D.new()
	rune_line.points = PackedVector2Array([
		Vector2(0, -rune_h * 0.5),
		Vector2(rune_w * 0.5, 0),
		Vector2(0, rune_h * 0.5),
		Vector2(-rune_w * 0.5, 0),
		Vector2(0, -rune_h * 0.5)
	])
	rune_line.width = 2.0
	rune_line.default_color = Color(0.92, 0.78, 0.35, 0.75) # Warm gold rune
	crest.add_child(rune_line)
	
	var star_h = Line2D.new()
	star_h.points = PackedVector2Array([Vector2(-24, 0), Vector2(24, 0)])
	star_h.width = 1.8
	star_h.default_color = Color(1.0, 0.88, 0.45, 0.85)
	crest.add_child(star_h)
	
	var star_v = Line2D.new()
	star_v.points = PackedVector2Array([Vector2(0, -14), Vector2(0, 14)])
	star_v.width = 1.8
	star_v.default_color = Color(1.0, 0.88, 0.45, 0.85)
	crest.add_child(star_v)
	
	# 4. Four Corner Stone Pedestals with Mystical Braziers
	var corner_offsets = [
		Vector2(0.0, -t1_h * 0.5 + 4.0),
		Vector2(t1_w * 0.5 - 6.0, 0.0),
		Vector2(0.0, t1_h * 0.5 - 4.0),
		Vector2(-t1_w * 0.5 + 6.0, 0.0)
	]
	
	for c_pos in corner_offsets:
		var brazier = _create_brazier_pedestal(c_pos)
		node.add_child(brazier)
		
	return node

func _create_brazier_pedestal(pos: Vector2) -> Node2D:
	var b_node = Node2D.new()
	b_node.position = pos
	
	# Pedestal column (16px high)
	var col_pts = PackedVector2Array([
		Vector2(-5, 0),
		Vector2(5, 0),
		Vector2(4, -14),
		Vector2(-4, -14)
	])
	var col_poly = Polygon2D.new()
	col_poly.polygon = col_pts
	col_poly.color = Color(0.18, 0.20, 0.25)
	b_node.add_child(col_poly)
	
	# Iron bowl
	var bowl_pts = PackedVector2Array([
		Vector2(-7, -14),
		Vector2(7, -14),
		Vector2(5, -10),
		Vector2(-5, -10)
	])
	var bowl_poly = Polygon2D.new()
	bowl_poly.polygon = bowl_pts
	bowl_poly.color = Color(0.10, 0.11, 0.14)
	b_node.add_child(bowl_poly)
	
	# Mystical animated sanctuary flame
	var flame_node = Node2D.new()
	flame_node.position = Vector2(0.0, -14.0)
	var f_timer = randf() * 10.0
	flame_node.draw.connect(func():
		var time = Time.get_ticks_msec() * 0.001 + f_timer
		var f_x = sin(time * 12.0) * 1.5
		var f_h = 1.0 + cos(time * 9.0) * 0.2
		# Halo
		flame_node.draw_circle(Vector2(0, -4 * f_h), 7.0, Color(0.3, 0.8, 1.0, 0.2))
		# Outer Cyan/Blue mystical sanctuary flame
		var f_pts = PackedVector2Array([
			Vector2(-3.5, 0),
			Vector2(3.5, 0),
			Vector2(2.5 + f_x * 0.5, -6 * f_h),
			Vector2(f_x, -12 * f_h),
			Vector2(-2.5 + f_x * 0.5, -6 * f_h)
		])
		flame_node.draw_colored_polygon(f_pts, Color(0.35, 0.85, 1.2, 0.95))
		# Inner white core
		flame_node.draw_circle(Vector2(f_x * 0.3, -3), 2.0, Color(1.2, 1.4, 1.6, 1.0))
	)
	
	var anim_timer = Timer.new()
	anim_timer.wait_time = 0.04
	anim_timer.autostart = true
	anim_timer.timeout.connect(flame_node.queue_redraw)
	b_node.add_child(anim_timer)
	
	b_node.add_child(flame_node)
	return b_node

func _build_collision_and_walls() -> void:
	if static_body:
		static_body.queue_free()
		
	static_body = StaticBody2D.new()
	static_body.name = "RoomWallColliders_R%d" % room_index
	static_body.collision_layer = 1
	static_body.collision_mask = 0
	add_child(static_body)
	
	# Check all 4 edges of every cell in the room
	for c in global_cells:
		var c_world = cell_to_world(c)
		var hw = CELL_WIDTH * 0.5
		var hh = CELL_HEIGHT * 0.5
		
		var p_top    = c_world + Vector2(0.0, -hh)
		var p_right  = c_world + Vector2(hw, 0.0)
		var p_bottom = c_world + Vector2(0.0, hh)
		var p_left   = c_world + Vector2(-hw, 0.0)
		
		# NE Edge: Top -> Right (Direction DIR_NE = (0, -1))
		var ne_is_tall = _is_edge_visually_tall(c, TemplateClass.DIR_NE)
		_process_cell_edge(c, TemplateClass.DIR_NE, p_top, p_right, ne_is_tall)
		
		# NW Edge: Left -> Top (Direction DIR_NW = (-1, 0))
		var nw_is_tall = _is_edge_visually_tall(c, TemplateClass.DIR_NW)
		_process_cell_edge(c, TemplateClass.DIR_NW, p_left, p_top, nw_is_tall)
		
		# SE Edge: Right -> Bottom (Direction DIR_SE = (1, 0), South Wall)
		_process_cell_edge(c, TemplateClass.DIR_SE, p_right, p_bottom, false)
		
		# SW Edge: Bottom -> Left (Direction DIR_SW = (0, 1), South Wall)
		_process_cell_edge(c, TemplateClass.DIR_SW, p_bottom, p_left, false)

func _is_edge_visually_tall(cell: Vector2i, dir: Vector2i) -> bool:
	if dir != TemplateClass.DIR_NW and dir != TemplateClass.DIR_NE:
		return false
		
	var c_world = cell_to_world(cell)
	var hw = CELL_WIDTH * 0.5
	var hh = CELL_HEIGHT * 0.5
	
	var pt_a = Vector2.ZERO
	var pt_b = Vector2.ZERO
	if dir == TemplateClass.DIR_NW:
		pt_a = c_world + Vector2(-hw, 0.0)
		pt_b = c_world + Vector2(0.0, -hh)
	else:
		pt_a = c_world + Vector2(0.0, -hh)
		pt_b = c_world + Vector2(hw, 0.0)
		
	var min_x = minf(pt_a.x, pt_b.x)
	var max_x = maxf(pt_a.x, pt_b.x)
	var min_y = minf(pt_a.y, pt_b.y) - 200.0
	var max_y = maxf(pt_a.y, pt_b.y)
	
	# Check if any OTHER room cell has walkable floor that would be occluded by this 200px wall
	for other in global_cells:
		if other == cell:
			continue
		var cw = cell_to_world(other)
		# Only cells situated behind/north of the wall can be occluded
		if cw.y >= max_y:
			continue
			
		var c_min_x = cw.x - hw * 0.75
		var c_max_x = cw.x + hw * 0.75
		var c_min_y = cw.y - hh * 0.75
		var c_max_y = cw.y + hh * 0.75
		
		var overlap_x = (c_min_x < max_x) and (c_max_x > min_x)
		var overlap_y = (c_min_y < max_y) and (c_max_y > min_y)
		
		if overlap_x and overlap_y:
			return false # Floor behind this wall would be blocked! Must be low 24px curb.
			
	return true # Pure perimeter back wall -> tall 200px rampart

func _process_cell_edge(cell: Vector2i, dir: Vector2i, pt_a: Vector2, pt_b: Vector2, is_north_wall: bool) -> void:
	var neighbor = cell + dir
	if neighbor in global_cells:
		return
		
	var has_open_door = false
	for d in doors:
		if d.get("global_cell", Vector2i(-999, -999)) == cell and d.get("dir", Vector2i.ZERO) == dir:
			if d.get("is_connected", false):
				has_open_door = true
				break
				
	var target_parent = ysort_parent_node if ysort_parent_node else self
	var full_len = (pt_b - pt_a).length()
	
	var wall_mat: ShaderMaterial = null
	if is_north_wall:
		wall_mat = shared_wall_mat_ne if dir == TemplateClass.DIR_NE else shared_wall_mat_nw
	else:
		wall_mat = shared_curb_mat
	
	if not has_open_door:
		# Solid continuous wall along the full edge divided into 8 sub-segments for monotonic Y-sorting
		_add_collision_segment(pt_a, pt_b)
		
		const SLICES_PER_EDGE = 8
		for s in range(SLICES_PER_EDGE):
			var t0 = float(s) / float(SLICES_PER_EDGE)
			var t1 = float(s + 1) / float(SLICES_PER_EDGE)
			var sa = pt_a.lerp(pt_b, t0)
			var sb = pt_a.lerp(pt_b, t1)
			
			var w_seg = WallSegmentClass.new()
			w_seg.name = "Wall_%d_%s_s%d" % [room_index, TemplateClass.get_dir_name(dir).replace("-", "_"), s]
			target_parent.add_child(w_seg)
			w_seg.setup(
				sa, sb, dir, is_north_wall, room_index,
				t0 * full_len,
				s == 0,
				s == SLICES_PER_EDGE - 1,
				wall_mat
			)
			wall_nodes.append(w_seg)
			
		# Spawn wall torch on tall north solid walls (at midpoint)
		if is_north_wall:
			var torch_inst = DungeonTorchClass.new()
			torch_inst.name = "Torch_%d_%d" % [room_index, torch_nodes.size()]
			torch_inst.position = pt_a.lerp(pt_b, 0.5)
			target_parent.add_child(torch_inst)
			torch_nodes.append(torch_inst)
	else:
		# Open doorway: Split wall into two pillars flanking the passage gap
		var p_mid_a = pt_a.lerp(pt_b, DOOR_SIDE_RATIO)
		var p_mid_b = pt_b.lerp(pt_a, DOOR_SIDE_RATIO)
		_add_collision_segment(pt_a, p_mid_a)
		_add_collision_segment(p_mid_b, pt_b)
		
		# Pillar A with 3D doorway return jamb
		const PILLAR_SLICES = 2
		var pillar_a_len = (p_mid_a - pt_a).length()
		for s in range(PILLAR_SLICES):
			var t0 = float(s) / float(PILLAR_SLICES)
			var t1 = float(s + 1) / float(PILLAR_SLICES)
			var sa = pt_a.lerp(p_mid_a, t0)
			var sb = pt_a.lerp(p_mid_a, t1)
			
			var w_seg1 = WallSegmentClass.new()
			w_seg1.name = "DoorPillarA_%d_%s_s%d" % [room_index, TemplateClass.get_dir_name(dir).replace("-", "_"), s]
			if s == PILLAR_SLICES - 1:
				w_seg1.is_door_pillar_a = true
			target_parent.add_child(w_seg1)
			w_seg1.setup(
				sa, sb, dir, is_north_wall, room_index,
				t0 * pillar_a_len,
				s == 0,
				s == PILLAR_SLICES - 1,
				wall_mat
			)
			wall_nodes.append(w_seg1)
		
		# Pillar B with 3D doorway return jamb
		var pillar_b_len = (pt_b - p_mid_b).length()
		for s in range(PILLAR_SLICES):
			var t0 = float(s) / float(PILLAR_SLICES)
			var t1 = float(s + 1) / float(PILLAR_SLICES)
			var sa = p_mid_b.lerp(pt_b, t0)
			var sb = p_mid_b.lerp(pt_b, t1)
			
			var w_seg2 = WallSegmentClass.new()
			w_seg2.name = "DoorPillarB_%d_%s_s%d" % [room_index, TemplateClass.get_dir_name(dir).replace("-", "_"), s]
			if s == 0:
				w_seg2.is_door_pillar_b = true
			target_parent.add_child(w_seg2)
			w_seg2.setup(
				sa, sb, dir, is_north_wall, room_index,
				(1.0 - DOOR_SIDE_RATIO) * full_len + t0 * pillar_b_len,
				s == 0,
				s == PILLAR_SLICES - 1,
				wall_mat
			)
			wall_nodes.append(w_seg2)
		
		# Overhead Gothic stone archway above North doorways (player walks under clearance)
		if is_north_wall:
			var w_arch = WallSegmentClass.new()
			w_arch.name = "DoorArch_%d_%s" % [room_index, TemplateClass.get_dir_name(dir).replace("-", "_")]
			w_arch.is_door_arch = true
			w_arch.z_index = 1 # Stone arch lintel and keystone sit proudly in front of door top
			target_parent.add_child(w_arch)
			w_arch.setup(p_mid_a, p_mid_b, dir, true, room_index, DOOR_SIDE_RATIO * full_len, true, true, wall_mat)
			wall_nodes.append(w_arch)
			
			# Flanking torches on doorway pillars
			var torch_a = DungeonTorchClass.new()
			torch_a.name = "TorchA_%d_%d" % [room_index, torch_nodes.size()]
			torch_a.position = pt_a.lerp(p_mid_a, 0.5)
			target_parent.add_child(torch_a)
			torch_nodes.append(torch_a)
			
			var torch_b = DungeonTorchClass.new()
			torch_b.name = "TorchB_%d_%d" % [room_index, torch_nodes.size()]
			torch_b.position = p_mid_b.lerp(pt_b, 0.5)
			target_parent.add_child(torch_b)
			torch_nodes.append(torch_b)
			
			# Spawn DungeonDoor inside the North doorway opening
			var connected_room_idx = -1
			for d in doors:
				if d.get("global_cell", Vector2i(-999, -999)) == cell and d.get("dir", Vector2i.ZERO) == dir:
					connected_room_idx = d.get("connected_room_index", -1)
					break
					
			var door_inst = DungeonDoorClass.new()
			door_inst.name = "Door_%d_to_%d" % [room_index, connected_room_idx]
			target_parent.add_child(door_inst)
			door_inst.setup(p_mid_a, p_mid_b, dir, room_index, connected_room_idx)
			door_nodes.append(door_inst)

func _add_collision_segment(a: Vector2, b: Vector2) -> void:
	var col = CollisionShape2D.new()
	var seg = SegmentShape2D.new()
	seg.a = a
	seg.b = b
	col.shape = seg
	static_body.add_child(col)
	
	# Solid corner vertex pins: prevents tunneling/slipping at corner vertex meeting points
	var col_a = CollisionShape2D.new()
	var circle_a = CircleShape2D.new()
	circle_a.radius = 8.0
	col_a.shape = circle_a
	col_a.position = a
	static_body.add_child(col_a)
	
	var col_b = CollisionShape2D.new()
	var circle_b = CircleShape2D.new()
	circle_b.radius = 8.0
	col_b.shape = circle_b
	col_b.position = b
	static_body.add_child(col_b)

func set_room_active(is_active: bool, _is_peek: bool = false) -> void:
	is_currently_active = is_active
	visible = is_active
	
	for f in floor_nodes:
		if is_instance_valid(f):
			f.visible = is_active
			f.modulate = Color(1.0, 1.0, 1.0, 1.0)
				
	for w in wall_nodes:
		if is_instance_valid(w):
			w.visible = is_active
			w.modulate = Color(1.0, 1.0, 1.0, 1.0)
			
	for d in door_nodes:
		if is_instance_valid(d):
			if d.get("current_state") == DungeonDoorClass.State.SHATTERED:
				d.visible = false
			else:
				d.visible = is_active
			
	for t in torch_nodes:
		if is_instance_valid(t):
			t.visible = is_active
			if is_instance_valid(t.spark_emitter):
				t.spark_emitter.emitting = is_active
				
	if static_body:
		static_body.set_collision_layer_value(1, true) # Keep collision on so player doesn't walk into void

func get_active_torch_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for t in torch_nodes:
		if is_instance_valid(t) and t.visible and t.is_lit:
			positions.append(t.get_light_world_pos())
	return positions

func cleanup() -> void:
	for f in floor_nodes:
		if is_instance_valid(f):
			f.queue_free()
	floor_nodes.clear()
	
	for w in wall_nodes:
		if is_instance_valid(w):
			w.queue_free()
	wall_nodes.clear()
	
	for d in door_nodes:
		if is_instance_valid(d):
			d.queue_free()
	door_nodes.clear()
	
	for t in torch_nodes:
		if is_instance_valid(t):
			t.queue_free()
	torch_nodes.clear()
	
	if static_body and is_instance_valid(static_body):
		static_body.queue_free()

func _exit_tree() -> void:
	cleanup()
