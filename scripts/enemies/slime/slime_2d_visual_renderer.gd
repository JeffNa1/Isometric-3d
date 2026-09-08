class_name Slime2DVisualRenderer
extends Node2D

## 2.5D High-Fidelity Caustic Acid Ooze Renderer (Dark Fantasy Necrotic Slime)
## - Replaces cartoon blob with terrifying Dark Fantasy Living Caustic Ooze
## - Suspended within the murky viscous acid is a partially dissolved adventurer's skull,
##   floating rib shards, and a broken rusted iron dagger, rotating with 8-way 3D perspective.
## - Murky multi-layered caustic gradients with boiling toxic pustules and dragging pseudo-pods.
## - 5-Phase Visceral Leap Tackle: predatory acid spear surge with bone thrust & caustic splash.

enum Dir8 { E = 0, SE = 1, S = 2, SW = 3, W = 4, NW = 5, N = 6, NE = 7 }

var current_dir: Dir8 = Dir8.S
var is_moving: bool = false
var speed_ratio: float = 0.0
var is_leaping: bool = false
var leap_progress: float = 0.0
var jump_height: float = 0.0
var wobble_energy: float = 0.0
var move_direction: Vector2 = Vector2.DOWN

var idle_time: float = 0.0
var attack_windup: bool = false
var windup_progress: float = 0.0

# Dynamic Deformation Parameters
var deform_angle: float = 0.0
var stretch_primary: float = 1.0
var stretch_secondary: float = 1.0

# 3D Fluid Inertia
var skull_offset: Vector2 = Vector2.ZERO
var bone_offsets: Array[Vector2] = [Vector2(-7.0, -2.0), Vector2(7.0, 1.0), Vector2(-1.0, 5.0)]

# Dark Medieval Dungeon Caustic Acid Palette
const COL_SHADOW         = Color(0.0, 0.0, 0.0, 0.45)
const COL_OUTER_SLUDGE   = Color(0.04, 0.12, 0.05, 0.98) # Dark blackened rim
const COL_ACID_BODY      = Color(0.08, 0.28, 0.12, 0.90) # Murky toxic bile
const COL_ACID_MID       = Color(0.16, 0.52, 0.22, 0.85) # Viscous emerald body
const COL_ACID_HI        = Color(0.32, 0.82, 0.38, 0.78) # Subsurface radioactive glow
const COL_ACID_LUM       = Color(0.55, 1.00, 0.48, 0.85) # Caustic crest light
const COL_SPECULAR_HI    = Color(0.88, 1.00, 0.92, 0.88)
const COL_SPECULAR_DOT   = Color(1.0, 1.0, 1.0, 0.95)

# Dissolved Skeletal Remains Palette
const COL_BONE_IVORY     = Color(0.86, 0.82, 0.70, 0.92) # Weathered skull bone
const COL_BONE_SHADE     = Color(0.55, 0.48, 0.36, 0.90) # Cavity bone shadow
const COL_BONE_DARK      = Color(0.18, 0.15, 0.10, 0.95) # Hollow eye sockets
const COL_SOUL_GLOW      = Color(0.20, 2.2, 0.65, 0.90)  # Eerie necrotic eye fire
const COL_RUST_IRON      = Color(0.38, 0.26, 0.18, 0.88) # Corroded iron blade
const COL_RUST_EDGE      = Color(0.68, 0.58, 0.45, 0.88)

# Boiling Acid Pustules
const COL_PUSTULE_DARK   = Color(0.06, 0.22, 0.08, 0.95)
const COL_PUSTULE_BRIGHT = Color(0.45, 0.95, 0.35, 0.90)

func update_state(
	delta: float,
	dir: Dir8,
	moving: bool,
	spd_rat: float,
	leaping: bool,
	leap_prog: float,
	z_height: float,
	wobble: float,
	move_vec: Vector2 = Vector2.ZERO,
	windup: bool = false,
	w_prog: float = 0.0
) -> void:
	current_dir = dir
	is_moving = moving
	speed_ratio = spd_rat
	is_leaping = leaping
	leap_progress = leap_prog
	jump_height = z_height
	wobble_energy = wobble
	move_direction = move_vec.normalized() if move_vec != Vector2.ZERO else _get_dir_vector(dir)
	attack_windup = windup
	windup_progress = w_prog
	idle_time += delta

	_compute_deformation(delta)
	queue_redraw()

func _compute_deformation(delta: float) -> void:
	var heading_angle = move_direction.angle()

	if attack_windup:
		# Windup Tremor: Ooze collapses flat against the floor, shivering intensely with acidic boils
		deform_angle = 0.0
		var shiver = sin(idle_time * 42.0) * 0.09 * (1.0 + windup_progress)
		stretch_primary = lerpf(1.0, 1.48, windup_progress) + shiver
		stretch_secondary = lerpf(1.0, 0.52, windup_progress) - shiver * 0.7
		skull_offset = skull_offset.lerp(Vector2(0.0, 4.0), delta * 12.0)

	elif is_leaping:
		# Directional Predatory Spear Leap:
		deform_angle = heading_angle - (PI * 0.5)
		var t = leap_progress

		if t < 0.20:
			var p = t / 0.20
			stretch_primary = lerpf(1.45, 0.62, p)
			stretch_secondary = lerpf(0.55, 1.52, p)
		elif t < 0.75:
			# Aerodynamic acid spear flight
			var p = (t - 0.20) / 0.55
			var arc = sin(p * PI)
			stretch_primary = lerpf(0.65, 0.78, arc)
			stretch_secondary = lerpf(1.50, 1.30, arc)
		else:
			# Visceral impact splash
			var p = (t - 0.75) / 0.25
			var splash = sin(p * PI * 2.8) * exp(-p * 3.2) * 0.45
			stretch_primary = lerpf(1.50, 1.0, p) + splash
			stretch_secondary = lerpf(0.50, 1.0, p) - splash * 0.6

		var target_skull = move_direction * (3.8 * sin(leap_progress * PI))
		skull_offset = skull_offset.lerp(target_skull, delta * 14.0)

	elif is_moving:
		# Undulating viscous crawling & slithering
		deform_angle = heading_angle - (PI * 0.5)
		var hop_phase = fmod(idle_time * 7.5 * speed_ratio, TAU)
		var hop_sin = sin(hop_phase)

		if hop_sin > 0.0:
			stretch_primary = 1.0 - (hop_sin * 0.20)
			stretch_secondary = 1.0 + (hop_sin * 0.26)
		else:
			stretch_primary = 1.0 + (absf(hop_sin) * 0.22)
			stretch_secondary = 1.0 - (absf(hop_sin) * 0.18)

		skull_offset = skull_offset.lerp(-move_direction * 2.2, delta * 8.0)

	else:
		# Idle viscous breathing & bubbling
		deform_angle = 0.0
		var breath = sin(idle_time * 3.0) * 0.05
		var w_damp = sin(idle_time * 14.0) * wobble_energy * 0.25
		stretch_primary = 1.0 + breath + w_damp
		stretch_secondary = 1.0 - breath - w_damp
		skull_offset = skull_offset.lerp(Vector2.ZERO, delta * 6.0)

func _draw() -> void:
	var is_rear = (current_dir == Dir8.N or current_dir == Dir8.NW or current_dir == Dir8.NE)
	var is_side = (current_dir == Dir8.E or current_dir == Dir8.W)

	# 1. Sprawling Corrosive Acid Floor Shadow with Droplets
	_draw_corrosive_shadow()

	# 2. 2.5D Slime Center
	var center_y = -14.0 * stretch_secondary - jump_height
	var center = Vector2(0.0, center_y)

	var base_rx = 18.5
	var base_ry = 15.0

	# 3. Outer Caustic Sludge Hull (Layered Refractive Viscous Fluid)
	_draw_caustic_hull(center, base_rx, base_ry, is_rear)

	# 4. Trapped Suspended Skeleton Remains (Dissolved Skull, Ribs, Rusted Dagger)
	_draw_suspended_remains(center, is_rear, is_side)

	# 5. Boiling Surface Pustules & Corrosive Sizzle Particles
	_draw_acid_pustules(center, base_rx, base_ry)

	# 6. Wet Gloss Highlights & Refraction Sheen
	_draw_wet_specular(center, base_rx, base_ry, is_rear)

func _draw_corrosive_shadow() -> void:
	var shadow_squash = clampf(stretch_primary, 0.65, 1.45)
	var height_fade = clampf(1.0 - (jump_height / 100.0), 0.35, 1.0)
	var s_rx = 21.0 * shadow_squash * height_fade
	var s_ry = 9.5 * shadow_squash * height_fade
	var s_alpha = clampf(0.46 * height_fade, 0.12, 0.46)

	var shadow_pts = PackedVector2Array()
	for i in range(16):
		var a = i * TAU / 16.0
		# Irregular acid puddle perimeter
		var wobble = sin(a * 4.0 + idle_time * 2.0) * 1.2
		shadow_pts.append(Vector2(cos(a) * (s_rx + wobble), sin(a) * (s_ry + wobble * 0.5)))
	draw_colored_polygon(shadow_pts, Color(0.0, 0.0, 0.0, s_alpha))

	# Secondary acid splatter dots on the stone tiles
	if jump_height < 5.0:
		draw_circle(Vector2(-s_rx * 0.85, 2.0), 1.6, Color(0.02, 0.08, 0.03, 0.65))
		draw_circle(Vector2(s_rx * 0.82, -1.5), 1.4, Color(0.02, 0.08, 0.03, 0.65))
		draw_circle(Vector2(s_rx * 0.30, 4.0), 1.2, Color(0.02, 0.08, 0.03, 0.65))

func _draw_caustic_hull(cen: Vector2, rx: float, ry: float, is_rear: bool) -> void:
	var rot = deform_angle if (is_leaping or (is_moving and not attack_windup)) else 0.0
	var cos_r = cos(rot)
	var sin_r = sin(rot)

	# 1. Dark Meniscus Sludge Boundary
	var rim_pts = _generate_deformed_contour(cen, rx * stretch_primary, ry * stretch_secondary, cos_r, sin_r, 20, 1.0)
	draw_colored_polygon(rim_pts, COL_OUTER_SLUDGE)

	# 2. Murky Viscous Bile Body (Subsurface Scattering)
	var body_pts = _generate_deformed_contour(cen + Vector2(0.0, 1.0), (rx - 1.8) * stretch_primary, (ry - 1.8) * stretch_secondary, cos_r, sin_r, 20, 0.98)
	var body_col = COL_ACID_BODY if not is_rear else COL_ACID_BODY.lerp(COL_OUTER_SLUDGE, 0.25)
	draw_colored_polygon(body_pts, body_col)

	# 3. Inner Acid Glow Core
	var glow_pts = _generate_deformed_contour(cen + Vector2(0.0, -1.2), (rx - 3.2) * stretch_primary, (ry - 3.4) * stretch_secondary, cos_r, sin_r, 16, 0.94)
	draw_colored_polygon(glow_pts, COL_ACID_MID)

	# 4. Upper Caustic Crest Layer
	var crest_pts = _generate_deformed_contour(cen + Vector2(0.0, -2.5), rx * 0.65 * stretch_primary, ry * 0.60 * stretch_secondary, cos_r, sin_r, 14, 0.90)
	draw_colored_polygon(crest_pts, COL_ACID_HI)

	# 5. Core Radioactive Luminescence
	var lum_pts = _generate_deformed_contour(cen + Vector2(0.0, 1.2), rx * 0.40 * stretch_primary, ry * 0.38 * stretch_secondary, cos_r, sin_r, 12, 0.88)
	draw_colored_polygon(lum_pts, COL_ACID_LUM)

func _generate_deformed_contour(
	cen: Vector2,
	rx: float,
	ry: float,
	cos_r: float,
	sin_r: float,
	segs: int,
	flatness_mod: float
) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(segs):
		var a = i * TAU / float(segs)
		var local_y_mod = flatness_mod
		if sin(a) > 0.0:
			local_y_mod *= 0.84 # Flatten on floor
		else:
			local_y_mod *= 1.12 # Arched dome

		# Organic bubbling undulation
		var undulate = sin(a * 5.0 + idle_time * 4.0) * 0.45
		var lx = cos(a) * (rx + undulate)
		var ly = sin(a) * (ry + undulate * 0.5) * local_y_mod

		var wx = cen.x + (lx * cos_r - ly * sin_r)
		var wy = cen.y + (lx * sin_r + ly * cos_r)
		pts.append(Vector2(wx, wy))
	return pts

# --- TRAPPED ADVENTURER'S SKELETON (DISSOLVED SKULL & BONES) ---
func _draw_suspended_remains(cen: Vector2, is_rear: bool, is_side: bool) -> void:
	var flip_x = 1.0 if (current_dir == Dir8.E or current_dir == Dir8.SE or current_dir == Dir8.NE) else -1.0
	var skull_cen = cen + Vector2(0.0, 1.5) + skull_offset
	var float_bob = sin(idle_time * 3.8) * 0.9
	skull_cen.y += float_bob

	# 1. Broken Corroded Dagger Floating at bottom left
	var dag_pos = cen + Vector2(-6.5 * flip_x, 4.0) + (skull_offset * 0.4)
	var dag_dir = Vector2(0.8 * flip_x, -0.6).normalized()
	var dag_perp = Vector2(-dag_dir.y, dag_dir.x)
	draw_line(dag_pos - dag_dir * 5.0, dag_pos + dag_dir * 6.0, COL_RUST_IRON, 2.2, false)
	draw_line(dag_pos - dag_dir * 5.0, dag_pos + dag_dir * 6.0, COL_RUST_EDGE, 0.9, false)
	draw_line(dag_pos - dag_dir * 2.0 - dag_perp * 2.5, dag_pos - dag_dir * 2.0 + dag_perp * 2.5, COL_RUST_IRON, 1.4, false)

	# 2. Floating Dissolved Rib Shard
	var rib_pos = cen + Vector2(7.0 * flip_x, -1.0) + (skull_offset * 0.6)
	var rib_pts = PackedVector2Array([
		rib_pos + Vector2(-2.0, -3.0),
		rib_pos + Vector2(1.5, 0.0),
		rib_pos + Vector2(-1.0, 3.5)
	])
	draw_polyline(rib_pts, COL_BONE_IVORY, 1.4, false)
	draw_polyline(rib_pts, COL_BONE_SHADE, 0.7, false)

	# 3. Partially Dissolved Adventurer's Cranium
	if is_rear:
		# Rear View: Occipital bone and cranial sutures seen through murky bile
		var cranium_rear = PackedVector2Array([
			skull_cen + Vector2(-4.2, -4.5),
			skull_cen + Vector2(4.2, -4.5),
			skull_cen + Vector2(4.8, 1.5),
			skull_cen + Vector2(-4.8, 1.5)
		])
		draw_colored_polygon(cranium_rear, COL_BONE_SHADE)
		# Sagittal suture line
		draw_line(skull_cen + Vector2(0.0, -4.5), skull_cen + Vector2(0.0, 1.5), COL_BONE_DARK, 1.0, false)
		# Green acidic glow illuminating the bone from within
		draw_circle(skull_cen, 3.2, Color(0.2, 0.85, 0.35, 0.35))

	elif is_side:
		# Profile Skull (E / W)
		var p_poly = PackedVector2Array([
			skull_cen + Vector2(-3.5 * flip_x, -5.0),
			skull_cen + Vector2(3.5 * flip_x, -4.0),
			skull_cen + Vector2(4.5 * flip_x, 0.0), # Brow
			skull_cen + Vector2(2.5 * flip_x, 2.5), # Maxilla
			skull_cen + Vector2(-2.5 * flip_x, 3.0), # Jaw
			skull_cen + Vector2(-4.5 * flip_x, 0.5)
		])
		draw_colored_polygon(p_poly, COL_BONE_IVORY)
		# Cheekbone ridge
		draw_line(skull_cen + Vector2(1.0 * flip_x, 0.5), skull_cen + Vector2(-3.0 * flip_x, 0.5), COL_BONE_SHADE, 1.2, false)

		# Deep Hollow Orbital Socket
		var eye_socket = skull_cen + Vector2(2.0 * flip_x, -1.0)
		draw_circle(eye_socket, 1.6, COL_BONE_DARK)
		# Eerie Soulfire Glint in socket
		draw_circle(eye_socket, 0.8, COL_SOUL_GLOW)
		draw_circle(eye_socket, 0.4, Color.WHITE)

	else:
		# Front Angles (S / SE / SW): Full Terrifying Skull Facing Knight
		var shift_x = 0.0
		if current_dir == Dir8.SE: shift_x = 2.0
		elif current_dir == Dir8.SW: shift_x = -2.0

		var sc = skull_cen + Vector2(shift_x, 0.0)

		# Cranium vault
		var cranium_poly = PackedVector2Array([
			sc + Vector2(-5.0, -5.0),
			sc + Vector2(5.0, -5.0),
			sc + Vector2(6.0, -1.0),
			sc + Vector2(4.2, 3.0),  # Upper jaw
			sc + Vector2(-4.2, 3.0),
			sc + Vector2(-6.0, -1.0)
		])
		draw_colored_polygon(cranium_poly, COL_BONE_IVORY)
		# Temporal shadow contours
		draw_line(sc + Vector2(-5.0, -5.0), sc + Vector2(-6.0, -1.0), COL_BONE_SHADE, 1.2, false)
		draw_line(sc + Vector2(5.0, -5.0), sc + Vector2(6.0, -1.0), COL_BONE_SHADE, 1.2, false)

		# Nasal Cavity (inverted dark triangle)
		var nose_pts = PackedVector2Array([
			sc + Vector2(0.0, 0.5),
			sc + Vector2(1.0, 2.0),
			sc + Vector2(-1.0, 2.0)
		])
		draw_colored_polygon(nose_pts, COL_BONE_DARK)

		# Twin Hollow Orbital Sockets with Necrotic Eye Fire
		var l_socket = sc + Vector2(-2.8, -1.0)
		var r_socket = sc + Vector2(2.8, -1.0)

		draw_circle(l_socket, 1.7, COL_BONE_DARK)
		draw_circle(r_socket, 1.7, COL_BONE_DARK)

		# Pulsing Soulfire emerald cores
		var eye_pulse = sin(idle_time * 6.0) * 0.25
		draw_circle(l_socket, 0.9 + eye_pulse, COL_SOUL_GLOW)
		draw_circle(l_socket, 0.4, Color.WHITE)
		draw_circle(r_socket, 0.9 + eye_pulse, COL_SOUL_GLOW)
		draw_circle(r_socket, 0.4, Color.WHITE)

		# Jagged upper teeth row
		for t in range(3):
			var tx = sc.x - 2.0 + (float(t) * 2.0)
			draw_line(Vector2(tx, sc.y + 2.5), Vector2(tx, sc.y + 3.8), COL_BONE_SHADE, 1.0, false)

# --- BOILING ACID PUSTULES ---
func _draw_acid_pustules(cen: Vector2, rx: float, ry: float) -> void:
	var p_offsets = [
		Vector2(-rx * 0.45, -ry * 0.25),
		Vector2(rx * 0.50, -ry * 0.35),
		Vector2(-rx * 0.20, ry * 0.35)
	]

	for i in range(3):
		var p_time = idle_time * 3.5 + (i * 2.1)
		var p_cycle = fmod(p_time, 2.0)
		var p_size = (p_cycle / 1.6) * 2.0 if p_cycle < 1.6 else (2.0 - (p_cycle - 1.6) * 5.0)
		if p_size > 0.3:
			var p_pos = cen + p_offsets[i]
			draw_circle(p_pos, p_size, COL_PUSTULE_DARK)
			draw_circle(p_pos - Vector2(0.3, 0.3), p_size * 0.65, COL_PUSTULE_BRIGHT)
			draw_circle(p_pos - Vector2(0.5, 0.5), p_size * 0.30, Color.WHITE)

func _draw_wet_specular(cen: Vector2, rx: float, ry: float, is_rear: bool) -> void:
	var gloss_cen = cen + Vector2(-rx * 0.36 * stretch_primary, -ry * 0.46 * stretch_secondary)
	if is_rear:
		gloss_cen = cen + Vector2(0.0, -ry * 0.56 * stretch_secondary)

	var g_w = 6.8 * stretch_primary
	var g_h = 2.4 * stretch_secondary

	var gloss_pts = PackedVector2Array([
		gloss_cen + Vector2(-g_w * 0.5, 0.0),
		gloss_cen + Vector2(-g_w * 0.2, -g_h),
		gloss_cen + Vector2(g_w * 0.5, -g_h * 0.3),
		gloss_cen + Vector2(g_w * 0.2, g_h * 0.5),
		gloss_cen + Vector2(-g_w * 0.3, g_h * 0.3)
	])
	draw_colored_polygon(gloss_pts, COL_SPECULAR_HI)
	draw_circle(cen + Vector2(rx * 0.34 * stretch_primary, -ry * 0.34 * stretch_secondary), 1.2, COL_SPECULAR_DOT)

func _get_dir_vector(dir: Dir8) -> Vector2:
	match dir:
		Dir8.E:  return Vector2(1.0, 0.0)
		Dir8.SE: return Vector2(0.894, 0.447).normalized()
		Dir8.S:  return Vector2(0.0, 1.0)
		Dir8.SW: return Vector2(-0.894, 0.447).normalized()
		Dir8.W:  return Vector2(-1.0, 0.0)
		Dir8.NW: return Vector2(-0.894, -0.447).normalized()
		Dir8.N:  return Vector2(0.0, -1.0)
		Dir8.NE: return Vector2(0.894, -0.447).normalized()
		_:       return Vector2.DOWN
