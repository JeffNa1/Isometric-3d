class_name DungeonGenerator
extends Node2D

## Procedural Dungeon Generator for 10 Distinct Room Shapes
## Features:
## - Socket-based Snapping with O(1) Grid Collision / Overlap Checking
## - Room-by-Room Isolation: Only the player's active room is visible; peeks into adjacent rooms near doors
## - Native Godot Y-Sorting across player, monsters, and tall 2.5D isometric walls
## - Authentic Medieval Stone Flagstone Floor with dynamic player torchlight
## - Runtime Seed Generation & Instant Reset via UI Button or [R] Key
## - Integrated Isometric Minimap Overview with Fog-of-War

signal dungeon_generated(room_count: int)

const TemplateClass = preload("res://scripts/dungeon/dungeon_room_template.gd")
const RoomInstanceClass = preload("res://scripts/dungeon/dungeon_room_instance.gd")
const WallSegmentClass = preload("res://scripts/dungeon/dungeon_wall_segment.gd")
const DungeonDoorClass = preload("res://scripts/dungeon/dungeon_door.gd")
const FloorShader = preload("res://shaders/medieval_dungeon_floor.gdshader")
const WallShader = preload("res://shaders/medieval_dungeon_wall.gdshader")

@export var target_room_count: int = 10
@export var custom_seed: int = 0

var current_seed: int = 0
var occupied_cells: Dictionary = {} # Vector2i -> room_index
var spawned_rooms: Array[Node2D] = []
var raw_rooms: Array[Dictionary] = []
var all_doors: Array = []

var active_room_index: int = 0
var visited_rooms: Dictionary = {} # int -> bool

var player_ref: CharacterBody2D = null
var floor_container: Node2D = null
var ysort_entities: Node2D = null
var shared_floor_material: ShaderMaterial = null
var shared_wall_mat_ne: ShaderMaterial = null
var shared_wall_mat_nw: ShaderMaterial = null
var shared_curb_mat: ShaderMaterial = null

# Minimap & HUD
var hud_layer: CanvasLayer = null
var minimap_control: Control = null
var stats_label: Label = null
var regen_button: Button = null

func _ready() -> void:
	_setup_materials()
	_setup_hud()
	regenerate_dungeon()

func _setup_materials() -> void:
	# 1. Medieval Flagstone Floor Material
	shared_floor_material = ShaderMaterial.new()
	shared_floor_material.shader = FloorShader
	shared_floor_material.set_shader_parameter("tile_width", 72.0)
	shared_floor_material.set_shader_parameter("tile_height", 36.0)
	shared_floor_material.set_shader_parameter("mortar_width", 2.4)
	shared_floor_material.set_shader_parameter("torch_radius", 560.0)
	shared_floor_material.set_shader_parameter("torch_intensity", 1.45)
	shared_floor_material.set_shader_parameter("ambient_light", 0.28)
	shared_floor_material.set_shader_parameter("torch_color", Vector3(1.0, 0.78, 0.45))
	
	# 2. Medieval Stone Wall Materials (Tall North Walls: NE exposure vs NW exposure)
	shared_wall_mat_ne = ShaderMaterial.new()
	shared_wall_mat_ne.shader = WallShader
	shared_wall_mat_ne.set_shader_parameter("wall_full_height", 200.0)
	shared_wall_mat_ne.set_shader_parameter("wall_light_mult", 1.08)
	shared_wall_mat_ne.set_shader_parameter("torch_radius", 560.0)
	shared_wall_mat_ne.set_shader_parameter("torch_intensity", 1.45)
	shared_wall_mat_ne.set_shader_parameter("ambient_light", 0.28)
	shared_wall_mat_ne.set_shader_parameter("torch_color", Vector3(1.0, 0.78, 0.45))

	shared_wall_mat_nw = ShaderMaterial.new()
	shared_wall_mat_nw.shader = WallShader
	shared_wall_mat_nw.set_shader_parameter("wall_full_height", 200.0)
	shared_wall_mat_nw.set_shader_parameter("wall_light_mult", 0.90)
	shared_wall_mat_nw.set_shader_parameter("torch_radius", 560.0)
	shared_wall_mat_nw.set_shader_parameter("torch_intensity", 1.45)
	shared_wall_mat_nw.set_shader_parameter("ambient_light", 0.28)
	shared_wall_mat_nw.set_shader_parameter("torch_color", Vector3(1.0, 0.78, 0.45))

	# 3. South Wall Curb Material (24px low balustrade)
	shared_curb_mat = ShaderMaterial.new()
	shared_curb_mat.shader = WallShader
	shared_curb_mat.set_shader_parameter("wall_full_height", 24.0)
	shared_curb_mat.set_shader_parameter("wall_light_mult", 0.82)
	shared_curb_mat.set_shader_parameter("torch_radius", 560.0)
	shared_curb_mat.set_shader_parameter("torch_intensity", 1.45)
	shared_curb_mat.set_shader_parameter("ambient_light", 0.28)
	shared_curb_mat.set_shader_parameter("torch_color", Vector3(1.0, 0.78, 0.45))

func _ensure_layers() -> void:
	var root = get_parent()
	if not root:
		root = self
		
	floor_container = root.get_node_or_null("FloorContainer") as Node2D
	if not floor_container:
		floor_container = Node2D.new()
		floor_container.name = "FloorContainer"
		floor_container.z_index = -10
		root.add_child(floor_container)
		
	ysort_entities = root.get_node_or_null("YSortEntities") as Node2D
	if not ysort_entities:
		ysort_entities = Node2D.new()
		ysort_entities.name = "YSortEntities"
		ysort_entities.y_sort_enabled = true
		root.add_child(ysort_entities)
		
	if not is_instance_valid(player_ref):
		player_ref = root.find_child("Player", true, false) as CharacterBody2D
		
	if is_instance_valid(player_ref) and player_ref.get_parent() != ysort_entities:
		player_ref.reparent(ysort_entities)
		player_ref.y_sort_enabled = true

func _setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 95
	add_child(hud_layer)
	
	# Top-Center Control Panel
	var top_panel = PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_panel.position = Vector2(-220, 16)
	top_panel.custom_minimum_size = Vector2(440, 76)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.13, 0.92)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.92, 0.78, 0.35, 0.9)
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	top_panel.add_theme_stylebox_override("panel", style)
	hud_layer.add_child(top_panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	top_panel.add_child(vbox)
	
	stats_label = Label.new()
	stats_label.text = "🏛️ PROCEDURAL DUNGEON (ROOM ISOLATION & SHADER FLOOR)"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	vbox.add_child(stats_label)
	
	regen_button = Button.new()
	regen_button.text = "🎲 REGENERATE DUNGEON MAP (Phím R)"
	regen_button.custom_minimum_size = Vector2(260, 32)
	regen_button.focus_mode = Control.FOCUS_NONE
	regen_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.18, 0.22, 0.32, 1.0)
	btn_style.border_width_bottom = 1
	btn_style.border_width_top = 1
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_color = Color(0.35, 0.85, 0.95)
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	regen_button.add_theme_stylebox_override("normal", btn_style)
	
	regen_button.pressed.connect(func():
		regenerate_dungeon()
	)
	vbox.add_child(regen_button)
	
	# Top-Right Minimap Container
	_setup_minimap()

func _setup_minimap() -> void:
	var mm_panel = PanelContainer.new()
	mm_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mm_panel.position = Vector2(-230, 16)
	mm_panel.custom_minimum_size = Vector2(210, 210)
	
	var m_style = StyleBoxFlat.new()
	m_style.bg_color = Color(0.06, 0.07, 0.10, 0.88)
	m_style.border_width_bottom = 2
	m_style.border_width_top = 2
	m_style.border_width_left = 2
	m_style.border_width_right = 2
	m_style.border_color = Color(0.35, 0.75, 0.95, 0.7)
	m_style.corner_radius_bottom_left = 8
	m_style.corner_radius_bottom_right = 8
	m_style.corner_radius_top_left = 8
	m_style.corner_radius_top_right = 8
	mm_panel.add_theme_stylebox_override("panel", m_style)
	hud_layer.add_child(mm_panel)
	
	var mm_vbox = VBoxContainer.new()
	mm_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	mm_panel.add_child(mm_vbox)
	
	var mm_title = Label.new()
	mm_title.text = "DUNGEON OVERVIEW"
	mm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mm_title.add_theme_font_size_override("font_size", 10)
	mm_title.add_theme_color_override("font_color", Color(0.65, 0.75, 0.90))
	mm_vbox.add_child(mm_title)
	
	minimap_control = Control.new()
	minimap_control.custom_minimum_size = Vector2(200, 180)
	minimap_control.draw.connect(_on_minimap_draw)
	mm_vbox.add_child(minimap_control)

func _process(_delta: float) -> void:
	if not is_instance_valid(player_ref):
		var cur = get_tree().current_scene
		if cur:
			player_ref = cur.find_child("Player", true, false) as CharacterBody2D
			
	if is_instance_valid(player_ref):
		var p_pos = player_ref.global_position
		
		# 1. Update dynamic player torchlight in floor and wall shaders
		if shared_floor_material:
			shared_floor_material.set_shader_parameter("player_pos", p_pos)
		if shared_wall_mat_ne:
			shared_wall_mat_ne.set_shader_parameter("player_pos", p_pos)
		if shared_wall_mat_nw:
			shared_wall_mat_nw.set_shader_parameter("player_pos", p_pos)
		if shared_curb_mat:
			shared_curb_mat.set_shader_parameter("player_pos", p_pos)
			
		# 1b. Collect active wall torches from visible rooms
		var active_torches: Array[Vector2] = []
		for r in spawned_rooms:
			if is_instance_valid(r) and r.visible and r.has_method("get_active_torch_positions"):
				active_torches.append_array(r.get_active_torch_positions())
				
		if active_torches.size() > 8:
			active_torches.sort_custom(func(a, b): return p_pos.distance_squared_to(a) < p_pos.distance_squared_to(b))
			active_torches = active_torches.slice(0, 8)
			
		var torch_pos_array: Array[Vector2] = []
		var torch_int_array: Array[float] = []
		for tp in active_torches:
			torch_pos_array.append(tp)
			torch_int_array.append(1.0)
		while torch_pos_array.size() < 8:
			torch_pos_array.append(Vector2.ZERO)
			torch_int_array.append(0.0)
			
		for mat in [shared_floor_material, shared_wall_mat_ne, shared_wall_mat_nw, shared_curb_mat]:
			if mat:
				mat.set_shader_parameter("wall_torch_positions", torch_pos_array)
				mat.set_shader_parameter("wall_torch_intensities", torch_int_array)
				mat.set_shader_parameter("wall_torch_count", active_torches.size())
			
		# 2. Check current room grid cell
		var u = p_pos.x / (RoomInstanceClass.CELL_WIDTH * 0.5)
		var v = p_pos.y / (RoomInstanceClass.CELL_HEIGHT * 0.5)
		var gx = roundi((u + v) * 0.5)
		var gy = roundi((v - u) * 0.5)
		var cur_cell = Vector2i(gx, gy)
		
		if occupied_cells.has(cur_cell):
			var r_idx = occupied_cells[cur_cell]
			if r_idx != active_room_index:
				_set_active_room(r_idx)
			
	if minimap_control:
		minimap_control.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			regenerate_dungeon()

func regenerate_dungeon(seed_val: int = -1) -> void:
	if seed_val == -1:
		current_seed = randi()
	else:
		current_seed = seed_val
	seed(current_seed)
	
	_clear_existing_dungeon()
	_generate_layout()
	_build_room_instances()
	_reposition_player()
	
	if stats_label:
		stats_label.text = "🏛️ %d ROOMS GENERATED  |  ACTIVE: #%d  |  SEED: #%d" % [spawned_rooms.size(), active_room_index, current_seed]
	dungeon_generated.emit(spawned_rooms.size())

func _clear_existing_dungeon() -> void:
	occupied_cells.clear()
	raw_rooms.clear()
	visited_rooms.clear()
	all_doors.clear()
	for r in spawned_rooms:
		if is_instance_valid(r):
			r.cleanup()
			r.queue_free()
	spawned_rooms.clear()
	
	if floor_container:
		for c in floor_container.get_children():
			c.queue_free()
			
	if ysort_entities:
		for c in ysort_entities.get_children():
			if c != player_ref:
				c.queue_free()

func _generate_layout() -> void:
	var open_sockets: Array[Dictionary] = []
	
	# 1. Place Spawn Room at (0, 0)
	var starter_type = TemplateClass.ShapeType.HOLY_CROSS if randf() > 0.5 else TemplateClass.ShapeType.SQUARE_ATRIUM
	var tmpl_start = TemplateClass.get_template(starter_type)
	
	var r0_data = {
		"index": 0,
		"type": starter_type,
		"origin": Vector2i.ZERO,
		"doors": []
	}
	
	for c in tmpl_start.get("cells", []):
		occupied_cells[c] = 0
		
	for d in tmpl_start.get("doors", []):
		var d_info = {
			"local_cell": d["cell"],
			"global_cell": d["cell"],
			"dir": d["dir"],
			"is_connected": false,
			"connected_room_index": -1,
			"room_index": 0
		}
		r0_data["doors"].append(d_info)
		open_sockets.append(d_info)
		
	raw_rooms.append(r0_data)
	
	# 2. Grow dungeon by attaching matching rooms
	var all_shapes = TemplateClass.ShapeType.values()
	var attempts = 0
	var max_attempts = 350
	
	while raw_rooms.size() < target_room_count and open_sockets.size() > 0 and attempts < max_attempts:
		attempts += 1
		
		var socket_idx = randi() % open_sockets.size()
		var sock_A = open_sockets[socket_idx]
		var needed_dir = TemplateClass.get_opposite_dir(sock_A["dir"])
		
		var shuffled_shapes = all_shapes.duplicate()
		shuffled_shapes.shuffle()
		
		var placed = false
		for cand_shape in shuffled_shapes:
			if cand_shape == TemplateClass.ShapeType.VAULT_DEADEND and raw_rooms.size() < (target_room_count - 2):
				continue
				
			var cand_tmpl = TemplateClass.get_template(cand_shape as TemplateClass.ShapeType)
			var cand_doors = cand_tmpl.get("doors", [])
			
			var matching_doors = []
			for cd in cand_doors:
				if cd["dir"] == needed_dir:
					matching_doors.append(cd)
					
			if matching_doors.is_empty():
				continue
				
			matching_doors.shuffle()
			for sock_B in matching_doors:
				var target_cell = sock_A["global_cell"] + sock_A["dir"]
				var cand_origin = target_cell - sock_B["cell"]
				
				var has_overlap = false
				for cell in cand_tmpl.get("cells", []):
					var g_cell = cand_origin + cell
					if occupied_cells.has(g_cell):
						has_overlap = true
						break
						
				if has_overlap:
					continue
					
				var new_idx = raw_rooms.size()
				for cell in cand_tmpl.get("cells", []):
					occupied_cells[cand_origin + cell] = new_idx
					
				sock_A["is_connected"] = true
				sock_A["connected_room_index"] = new_idx
				open_sockets.remove_at(socket_idx)
				
				var new_doors: Array[Dictionary] = []
				for cd in cand_doors:
					var is_matching_sock_B = (cd["cell"] == sock_B["cell"] and cd["dir"] == sock_B["dir"])
					var d_info = {
						"local_cell": cd["cell"],
						"global_cell": cand_origin + cd["cell"],
						"dir": cd["dir"],
						"is_connected": is_matching_sock_B,
						"connected_room_index": sock_A["room_index"] if is_matching_sock_B else -1,
						"room_index": new_idx
					}
					new_doors.append(d_info)
					if not is_matching_sock_B:
						open_sockets.append(d_info)
						
				raw_rooms.append({
					"index": new_idx,
					"type": cand_shape,
					"origin": cand_origin,
					"doors": new_doors
				})
				
				placed = true
				break
				
			if placed:
				break
				
		if not placed:
			open_sockets.remove_at(socket_idx)

func _build_room_instances() -> void:
	_ensure_layers()
	all_doors.clear()
	for r_data in raw_rooms:
		var inst = RoomInstanceClass.new()
		inst.name = "DungeonRoom_%d" % r_data["index"]
		add_child(inst)
		inst.setup(
			r_data["index"],
			r_data["type"],
			r_data["origin"],
			r_data["doors"],
			floor_container,
			ysort_entities,
			shared_floor_material,
			shared_wall_mat_ne,
			shared_wall_mat_nw,
			shared_curb_mat
		)
		spawned_rooms.append(inst)
		all_doors.append_array(inst.door_nodes)
		
	for d in all_doors:
		d.door_opened.connect(_on_door_state_changed)
		d.door_shattered.connect(_on_door_state_changed)

func _on_door_state_changed(_door: Node2D) -> void:
	_update_room_visibilities()

func _set_active_room(r_idx: int) -> void:
	if r_idx < 0 or r_idx >= spawned_rooms.size():
		return
		
	active_room_index = r_idx
	visited_rooms[r_idx] = true
	
	_update_room_visibilities()
			
	if stats_label:
		stats_label.text = "🏛️ ROOM #%d ACTIVE  |  %d VISITED  |  SEED: #%d" % [
			active_room_index, visited_rooms.size(), current_seed
		]

func _update_room_visibilities() -> void:
	# Active room is always visible.
	# Any adjacent room whose connecting door is OPEN or SHATTERED is also made visible so player can look through!
	for r in spawned_rooms:
		var should_be_vis = (r.room_index == active_room_index)
		if not should_be_vis:
			for door in all_doors:
				if not is_instance_valid(door):
					continue
				if door.current_state == DungeonDoorClass.State.OPEN or door.current_state == DungeonDoorClass.State.SHATTERED:
					if (door.room_a_idx == active_room_index and door.room_b_idx == r.room_index) or \
					   (door.room_b_idx == active_room_index and door.room_a_idx == r.room_index):
						should_be_vis = true
						break
		r.set_room_active(should_be_vis, false)

func _reposition_player() -> void:
	_ensure_layers()
	if is_instance_valid(player_ref) and spawned_rooms.size() > 0:
		var target_pos = spawned_rooms[0].center_world_pos
		player_ref.global_position = target_pos
		player_ref.velocity = Vector2.ZERO
		
		active_room_index = 0
		visited_rooms.clear()
		_set_active_room(0)
		
		var cam = get_viewport().get_camera_2d()
		if cam:
			cam.global_position = player_ref.global_position
			
		call_deferred("_sync_player_spawn_pos", target_pos)

func _sync_player_spawn_pos(target_pos: Vector2) -> void:
	if is_instance_valid(player_ref):
		player_ref.global_position = target_pos
		player_ref.velocity = Vector2.ZERO
		var cam = get_viewport().get_camera_2d()
		if cam:
			cam.global_position = target_pos

func _on_minimap_draw() -> void:
	if raw_rooms.is_empty() or not minimap_control:
		return
		
	var min_c = Vector2i(9999, 9999)
	var max_c = Vector2i(-9999, -9999)
	for c in occupied_cells.keys():
		min_c.x = mini(min_c.x, c.x)
		min_c.y = mini(min_c.y, c.y)
		max_c.x = maxi(max_c.x, c.x)
		max_c.y = maxi(max_c.y, c.y)
		
	var span_x = maxf(1.0, float(max_c.x - min_c.x + 1))
	var span_y = maxf(1.0, float(max_c.y - min_c.y + 1))
	
	var mm_size = minimap_control.size
	var cell_draw_w = (mm_size.x - 20.0) / span_x
	var cell_draw_h = (mm_size.y - 20.0) / span_y
	var cell_draw_size = clampf(minf(cell_draw_w, cell_draw_h), 5.0, 16.0)
	
	var center_offset = mm_size * 0.5 - Vector2((span_x * 0.5), (span_y * 0.5)) * cell_draw_size
	
	# Draw rooms on minimap
	for c in occupied_cells.keys():
		var r_idx = occupied_cells[c]
		var px = center_offset.x + (c.x - min_c.x) * cell_draw_size
		var py = center_offset.y + (c.y - min_c.y) * cell_draw_size
		var cell_rect = Rect2(px, py, cell_draw_size - 1.0, cell_draw_size - 1.0)
		
		if r_idx == active_room_index:
			# Glowing emerald green for current room
			minimap_control.draw_rect(cell_rect, Color(0.25, 1.0, 0.55, 0.95))
		elif visited_rooms.has(r_idx):
			# Steel blue for visited rooms
			if raw_rooms[r_idx]["type"] == TemplateClass.ShapeType.VAULT_DEADEND:
				minimap_control.draw_rect(cell_rect, Color(0.95, 0.75, 0.25, 0.95))
			else:
				minimap_control.draw_rect(cell_rect, Color(0.35, 0.48, 0.70, 0.85))
		else:
			# Dark faint silhouette for undiscovered rooms
			minimap_control.draw_rect(cell_rect, Color(0.12, 0.15, 0.22, 0.40))
			minimap_control.draw_rect(cell_rect, Color(0.25, 0.30, 0.40, 0.50), false, 1.0)
		
	# Draw player dot on minimap
	if is_instance_valid(player_ref):
		var p_pos = player_ref.global_position
		var u = p_pos.x / (RoomInstanceClass.CELL_WIDTH * 0.5)
		var v = p_pos.y / (RoomInstanceClass.CELL_HEIGHT * 0.5)
		var p_gx = (u + v) * 0.5
		var p_gy = (v - u) * 0.5
		
		var p_mm_x = center_offset.x + (p_gx - min_c.x) * cell_draw_size
		var p_mm_y = center_offset.y + (p_gy - min_c.y) * cell_draw_size
		minimap_control.draw_circle(Vector2(p_mm_x, p_mm_y), 3.5, Color(1.0, 0.2, 0.2, 1.0))
