extends CharacterBody2D

signal damage_taken_event(amount: float)

@export var max_health: float = 999999999.0
var current_health: float = 999999999.0
var hit_radius: float = 45.0

var hurt_flash_timer: float = 0.0
var total_damage_taken: float = 0.0
var recent_hits: Array[Dictionary] = [] # [{time: float, dmg: float}]
var current_dps: float = 0.0
var peak_dps: float = 0.0
var combat_active: bool = false
var combat_timer: float = 0.0
var idle_timer: float = 0.0

var sound_mgr: Node = null
var particle_mgr: Node2D = null
var txt_mgr: Node2D = null

func _ready() -> void:
	z_as_relative = false
	z_index = 4
	add_to_group("boss") # Ensures all automated weapon targeting attacks lock onto it
	add_to_group("target_dummies")
	_get_managers()
	queue_redraw()

func _get_managers() -> void:
	var cur = get_tree().current_scene
	if cur:
		sound_mgr = cur.get_node_or_null("SoundManager")
		particle_mgr = cur.get_node_or_null("ParticleManager")
		txt_mgr = cur.get_node_or_null("FloatingTextManager")

func _process(delta: float) -> void:
	if hurt_flash_timer > 0.0:
		hurt_flash_timer -= delta

	var now = Time.get_ticks_msec() * 0.001

	# Prune damage older than 1.0 second
	var i = 0
	var sum_dmg = 0.0
	while i < recent_hits.size():
		if (now - recent_hits[i].time) > 1.0:
			recent_hits.remove_at(i)
		else:
			sum_dmg += recent_hits[i].dmg
			i += 1

	current_dps = sum_dmg
	if current_dps > peak_dps:
		peak_dps = current_dps

	if combat_active:
		combat_timer += delta
		if sum_dmg <= 0.0:
			idle_timer += delta
			if idle_timer >= 4.0:
				combat_active = false
		else:
			idle_timer = 0.0

	queue_redraw()

func take_damage(amount: float) -> void:
	combat_active = true
	idle_timer = 0.0
	total_damage_taken += amount
	hurt_flash_timer = 0.12

	var now = Time.get_ticks_msec() * 0.001
	recent_hits.append({"time": now, "dmg": amount})
	damage_taken_event.emit(amount)

	if not txt_mgr:
		_get_managers()
	if txt_mgr and randf() < 0.45:
		txt_mgr.spawn_damage(global_position + Vector2(randf_range(-18, 18), randf_range(-65, -30)), amount, true)

	if particle_mgr and randf() < 0.35:
		particle_mgr.spawn_sparks(global_position + Vector2(0, -35), Color(3.5, 2.5, 0.4, 1.0), 3)

	var cur = get_tree().current_scene
	var dps_meter = cur.get_node_or_null("SandboxLayer/DPSMeter") if cur else null
	if dps_meter and dps_meter.has_method("record_damage"):
		dps_meter.record_damage(amount)

func reset_stats() -> void:
	total_damage_taken = 0.0
	recent_hits.clear()
	current_dps = 0.0
	peak_dps = 0.0
	combat_active = false
	combat_timer = 0.0
	idle_timer = 0.0
	queue_redraw()

func _draw() -> void:
	# 1. Ground Shadow (Isometric 2:1 Ellipse)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 38.0, Color(0.0, 0.0, 0.0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 2. Heavy Reinforced Steel Base
	draw_circle(Vector2(0, -8), 24.0, Color(0.18, 0.20, 0.25, 1.0))
	draw_arc(Vector2(0, -8), 24.0, 0.0, TAU, 24, Color(0.4, 0.45, 0.55, 1.0), 3.0)

	# 3. Dummy Torso / Hull (Flashes bright white on hit)
	var body_col = Color(4.0, 4.0, 4.0, 1.0) if hurt_flash_timer > 0.0 else Color(0.85, 0.35, 0.15, 1.0)
	var trim_col = Color(4.0, 4.0, 4.0, 1.0) if hurt_flash_timer > 0.0 else Color(0.15, 0.18, 0.22, 1.0)

	# Pillar Post
	draw_rect(Rect2(-8, -48, 16, 40), trim_col)

	# Target Torso (Armor Plate)
	draw_rect(Rect2(-24, -68, 48, 36), body_col)
	draw_rect(Rect2(-24, -68, 48, 36), trim_col, false, 2.5)

	# High-Visibility Bullseye Target on Torso
	draw_circle(Vector2(0, -50), 12.0, Color(1.0, 1.0, 1.0, 0.9))
	draw_circle(Vector2(0, -50), 8.0, Color(0.9, 0.1, 0.1, 1.0))
	draw_circle(Vector2(0, -50), 4.0, Color(1.0, 0.9, 0.1, 1.0))

	# Dummy Head
	draw_circle(Vector2(0, -78), 11.0, trim_col)
	draw_arc(Vector2(0, -78), 11.0, 0.0, TAU, 16, body_col, 2.0)
	# Glowing Cyan Visor
	draw_line(Vector2(-6, -78), Vector2(6, -78), Color(0.2, 3.5, 4.0, 1.0), 3.0)

	# 4. Floating Overhead DPS & Damage Display
	var font = ThemeDB.fallback_font
	var font_size = 11

	var dps_str = "DPS: %d" % int(current_dps)
	var tot_str = "TOTAL: %s" % _format_number(total_damage_taken)
	var peak_str = "PEAK: %d" % int(peak_dps)

	# Overhead banner background
	var box_w = 140.0
	var box_h = 36.0
	var box_pos = Vector2(-box_w * 0.5, -135.0)

	draw_rect(Rect2(box_pos.x, box_pos.y, box_w, box_h), Color(0.05, 0.08, 0.12, 0.85))
	draw_rect(Rect2(box_pos.x, box_pos.y, box_w, box_h), Color(0.3, 2.5, 3.5, 0.9), false, 1.5)

	# Text lines
	draw_string(font, box_pos + Vector2(8, 14), dps_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(3.5, 2.5, 0.2, 1.0))
	draw_string(font, box_pos + Vector2(72, 14), peak_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.7, 0.8, 0.9, 0.8))
	draw_string(font, box_pos + Vector2(8, 28), tot_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.9, 0.95, 1.0, 0.9))

func _format_number(val: float) -> String:
	if val >= 1000000.0:
		return "%.2fM" % (val / 1000000.0)
	elif val >= 1000.0:
		return "%.1fK" % (val / 1000.0)
	return "%d" % int(val)
