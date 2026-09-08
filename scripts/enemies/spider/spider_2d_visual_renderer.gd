class_name Spider2DVisualRenderer
extends Node2D

## 2.5D Masterclass Volumetric Toxic Spider Renderer (True 8-Way Arachnid Kinematics)
## - Full 8-Directional Projections with True Isometric 2:1 Floor Kinematics:
##   * Canonical predatory hunting stance (L1..L4, R1..R4) rotated onto 2:1 isometric ground plane
##   * Eliminates the clamping bug that warped legs when facing North, NW, and NE
##   * High 3D knee elevation (-13px) with articulated chitin spurs and tarsus claws
##   * Automatic depth sorting: background legs -> bulbous toxic abdomen -> cephalothorax & fangs -> foreground legs
## - Bioluminescent Toxic Abdomen with pulsating venom vein network & dripping acid droplets
## - 8-Ruby Eye Cluster with parallax tracking, predatory pedipalps & snapping chelicerae fangs
## - 4-Phase Alternating Tetrapod Gait & Threat Rearing kinematics

enum Dir8 { E = 0, SE = 1, S = 2, SW = 3, W = 4, NW = 5, N = 6, NE = 7 }

var current_dir: Dir8 = Dir8.S
var is_moving: bool = false
var speed_ratio: float = 0.0
var is_spitting: bool = false
var spit_timer: float = 0.0
var spit_duration: float = 0.45
var is_biting: bool = false
var bite_timer: float = 0.0
var bite_duration: float = 0.32
var current_move_vec: Vector2 = Vector2.ZERO

var walk_phase: float = 0.0
var idle_time: float = 0.0

# Kinetic Body Offsets
var body_recoil: Vector2 = Vector2.ZERO
var front_legs_lift: float = 0.0
var abdomen_elevation: float = 0.0
var fangs_spread: float = 0.0

# Dark Fantasy Toxic Arachnid Palette
const COL_SHADOW        = Color(0.0, 0.0, 0.0, 0.42)
const COL_LEG_SHADOW    = Color(0.0, 0.0, 0.0, 0.28)

const COL_CHITIN_DARK   = Color(0.08, 0.06, 0.12) # Deep obsidian chitin
const COL_CHITIN_BASE   = Color(0.16, 0.13, 0.24) # Carapace base
const COL_CHITIN_MID    = Color(0.26, 0.22, 0.36) # Chitinous ridge
const COL_CHITIN_HI     = Color(0.44, 0.38, 0.56) # Rim specular
const COL_CHITIN_SPEC   = Color(0.72, 0.65, 0.82) # Sharp glint

const COL_TOXIC_DARK    = Color(0.05, 0.24, 0.08) # Deep venom vein
const COL_TOXIC_BASE    = Color(0.22, 0.75, 0.16) # Pulsing acid gland
const COL_TOXIC_BRIGHT  = Color(0.48, 1.10, 0.28) # Incandescent bioluminescence
const COL_TOXIC_GLOW    = Color(0.68, 1.40, 0.35, 0.85)

const COL_EYE_CORE      = Color(2.5, 0.25, 0.15, 1.0) # Burning ruby eyes
const COL_EYE_GLINT     = Color(1.0, 1.0, 1.0, 0.95)
const COL_FANG_IVORY    = Color(0.88, 0.85, 0.72)
const COL_FANG_TIP      = Color(0.35, 1.05, 0.20) # Venom dripping tip

func update_state(
	delta: float,
	dir: Dir8,
	moving: bool,
	spd_rat: float,
	spitting: bool,
	s_timer: float,
	s_dur: float,
	biting: bool = false,
	b_timer: float = 0.0,
	b_dur: float = 0.32,
	move_vec: Vector2 = Vector2.ZERO
) -> void:
	current_dir = dir
	is_moving = moving
	speed_ratio = spd_rat
	is_spitting = spitting
	spit_timer = s_timer
	spit_duration = s_dur
	is_biting = biting
	bite_timer = b_timer
	bite_duration = b_dur
	current_move_vec = move_vec.normalized() if move_vec != Vector2.ZERO else _get_dir_vector(dir)

	idle_time += delta
	if is_moving:
		walk_phase += delta * 14.0 * spd_rat

	_compute_attack_kinetics(delta)
	queue_redraw()

func _compute_attack_kinetics(delta: float) -> void:
	var aim_dir = _get_dir_vector(current_dir)

	if is_spitting:
		# Multi-Phase Venom Spit
		var t = clampf(spit_timer / maxf(spit_duration, 0.01), 0.0, 1.0)

		if t < 0.38:
			# Phase 1: Threat Rearing
			var p = t / 0.38
			var s = p * p
			body_recoil = -aim_dir * (5.5 * s)
			front_legs_lift = lerpf(0.0, 16.0, s)
			abdomen_elevation = lerpf(0.0, -4.5, s)
			fangs_spread = lerpf(0.0, 4.5, s)

		elif t < 0.62:
			# Phase 2: Hydraulic Recoil Snap
			var p = (t - 0.38) / 0.24
			var s = 1.0 - pow(1.0 - p, 2.5)
			body_recoil = aim_dir * lerpf(-5.5, 4.2, s)
			front_legs_lift = lerpf(16.0, -2.0, s)
			abdomen_elevation = lerpf(-4.5, 3.5, s)
			fangs_spread = lerpf(4.5, -2.0, s)

		else:
			# Phase 3: Settle
			var p = (t - 0.62) / 0.38
			var r = p * p
			body_recoil = body_recoil.lerp(Vector2.ZERO, delta * 12.0)
			front_legs_lift = lerpf(-2.0, 0.0, r)
			abdomen_elevation = lerpf(3.5, 0.0, r)
			fangs_spread = lerpf(-2.0, 0.0, r)

	elif is_biting:
		# Rapid Melee Fang Snap
		var t = clampf(bite_timer / maxf(bite_duration, 0.01), 0.0, 1.0)
		if t < 0.40:
			var p = t / 0.40
			body_recoil = aim_dir * (6.5 * p)
			front_legs_lift = 5.0 * p
			fangs_spread = 5.0 * p
		else:
			var p = (t - 0.40) / 0.60
			body_recoil = body_recoil.lerp(Vector2.ZERO, delta * 14.0)
			front_legs_lift = lerpf(5.0, 0.0, p)
			fangs_spread = lerpf(5.0, 0.0, p)

	else:
		body_recoil = body_recoil.move_toward(Vector2.ZERO, delta * 20.0)
		front_legs_lift = move_toward(front_legs_lift, 0.0, delta * 28.0)
		abdomen_elevation = move_toward(abdomen_elevation, 0.0, delta * 15.0)
		fangs_spread = move_toward(fangs_spread, 0.0, delta * 18.0)

func _draw() -> void:
	var is_rear = (current_dir == Dir8.N or current_dir == Dir8.NW or current_dir == Dir8.NE)
	var is_profile = (current_dir == Dir8.E or current_dir == Dir8.W)
	var flip_x = 1.0 if (current_dir == Dir8.E or current_dir == Dir8.SE or current_dir == Dir8.NE) else -1.0

	var crawl_bob = sin(walk_phase * 2.0) * 1.2 if is_moving else sin(idle_time * 3.0) * 0.6
	var cen_body = Vector2(0.0, -11.0 + crawl_bob) + body_recoil
	var cen_ground = Vector2(0.0, 0.0) + (body_recoil * 0.6)

	var facing_ang = _get_dir_vector(current_dir).angle()

	# 1. 2:1 Isometric Ground Shadow
	_draw_spider_shadows(cen_ground, facing_ang)

	# 2. Gather All 8 Legs with True 2:1 Isometric Projections
	var legs = _calculate_8_legs(cen_body, cen_ground, facing_ang)

	# 3. Draw Background Legs (legs on the far side: foot.y < cen_ground.y)
	for leg in legs:
		if leg.is_background:
			_draw_single_articulated_leg(leg)

	# 4. Bulbous Opisthosoma (Abdomen)
	var abd_offset = Vector2(-cos(facing_ang) * 9.5, -sin(facing_ang) * 5.0)
	abd_offset.y -= abdomen_elevation

	if not is_rear:
		_draw_toxic_abdomen(cen_body + abd_offset, is_rear)

	# 5. Cephalothorax Carapace & Fangs
	_draw_cephalothorax(cen_body, is_rear, is_profile)
	_draw_eyes_and_fangs(cen_body, facing_ang, is_rear, is_profile, flip_x)

	if is_rear:
		_draw_toxic_abdomen(cen_body + abd_offset, is_rear)

	# 6. Draw Foreground Legs (legs on near side: foot.y >= cen_ground.y)
	for leg in legs:
		if not leg.is_background:
			_draw_single_articulated_leg(leg)

func _draw_spider_shadows(cen_ground: Vector2, facing_ang: float) -> void:
	var cos_a = cos(facing_ang)
	var sin_a = sin(facing_ang)

	# Thorax shadow
	var th_pts = PackedVector2Array()
	for i in range(12):
		var a = i * TAU / 12.0
		th_pts.append(cen_ground + Vector2(cos(a) * 14.0, sin(a) * 7.0))
	draw_colored_polygon(th_pts, COL_SHADOW)

	# Abdomen shadow trailing behind
	var abd_g_cen = cen_ground - Vector2(cos_a * 9.0, sin_a * 4.5)
	var abd_pts = PackedVector2Array()
	for i in range(14):
		var a = i * TAU / 14.0
		abd_pts.append(abd_g_cen + Vector2(cos(a) * 17.5, sin(a) * 8.5))
	draw_colored_polygon(abd_pts, COL_SHADOW)

# --- TRUE 2:1 ISOMETRIC 8-LEG KINEMATICS ---
class LegKinematicsData:
	var root: Vector2
	var knee: Vector2
	var foot: Vector2
	var is_background: bool
	var is_front_pair: bool

func _calculate_8_legs(cen_body: Vector2, cen_ground: Vector2, facing_ang: float) -> Array[LegKinematicsData]:
	var cos_a = cos(facing_ang)
	var sin_a = sin(facing_ang)

	# Canonical Arachnid Stance [local_fwd, local_lat, leg_len, is_front_pair, is_phase_A]
	# lat > 0 = Right side, lat < 0 = Left side
	var leg_configs = [
		# Front Pair: Reach far forward and angled out
		[ 22.0, -16.0, 26.0, true,  true],   # L1
		[  9.0, -25.0, 28.0, false, false],  # L2
		[ -6.0, -23.0, 27.0, false, false],  # L3
		[-20.0, -15.0, 25.0, false, true],   # L4
		[ 22.0,  16.0, 26.0, true,  false],  # R1
		[  9.0,  25.0, 28.0, false, true],   # R2
		[ -6.0,  23.0, 27.0, false, true],   # R3
		[-20.0,  15.0, 25.0, false, false],  # R4
	]

	var result: Array[LegKinematicsData] = []

	for i in range(8):
		var cfg = leg_configs[i]
		var fwd = cfg[0] as float
		var lat = cfg[1] as float
		var is_front_pair = cfg[3] as bool
		var is_phase_A = cfg[4] as bool

		# 1. Rotate canonical coordinates by facing angle on the ground plane
		var floor_x = fwd * cos_a - lat * sin_a
		var floor_y = fwd * sin_a + lat * cos_a

		# 2. Isometric 2:1 Projection on floor
		var foot_pos = cen_ground + Vector2(floor_x, floor_y * 0.5)

		# 3. Coxa attachment point on cephalothorax margin
		var root_fwd = fwd * 0.35
		var root_lat = lat * 0.35
		var root_wx = root_fwd * cos_a - root_lat * sin_a
		var root_wy = root_fwd * sin_a + root_lat * cos_a
		var root_pos = cen_body + Vector2(root_wx, root_wy * 0.5)

		# 4. Stepping displacement & 2.5D knee lift
		var knee_lift = 0.0
		var step_disp = Vector2.ZERO

		if is_moving:
			var p = walk_phase if is_phase_A else (walk_phase + PI)
			var cycle_sin = sin(p)
			var stride = 5.5 * speed_ratio
			step_disp = current_move_vec * (cycle_sin * stride)
			if cycle_sin > 0.0:
				knee_lift = sin(cycle_sin * PI) * 5.5

		# Threat rearing on front pair
		if is_front_pair and front_legs_lift > 0.0:
			knee_lift += front_legs_lift * 0.85
			foot_pos += Vector2(cos_a * front_legs_lift * 0.4, -front_legs_lift * 0.65)

		foot_pos += step_disp

		# 5. Arched 3D Knee Joint (Elevated strictly along 2.5D visual Y axis)
		var knee_mid = (root_pos + foot_pos) * 0.5
		var knee_pos = knee_mid + Vector2(0.0, -12.5 - knee_lift)

		# 6. Depth Determination
		# A leg is in background if its foot and knee are behind the body center
		var is_bg = (foot_pos.y < cen_ground.y - 1.0) and (knee_pos.y < cen_body.y - 2.0)

		var leg_data = LegKinematicsData.new()
		leg_data.root = root_pos
		leg_data.knee = knee_pos
		leg_data.foot = foot_pos
		leg_data.is_background = is_bg
		leg_data.is_front_pair = is_front_pair
		result.append(leg_data)

	return result

func _draw_single_articulated_leg(leg: LegKinematicsData) -> void:
	# Claw contact shadow on ground
	if not leg.is_front_pair or front_legs_lift <= 0.5:
		draw_circle(leg.foot, 1.8, COL_LEG_SHADOW)

	var col_chitin = COL_CHITIN_DARK if leg.is_background else COL_CHITIN_BASE
	var col_hi     = COL_CHITIN_MID  if leg.is_background else COL_CHITIN_HI
	var col_spec   = COL_CHITIN_HI   if leg.is_background else COL_CHITIN_SPEC

	# 1. Coxa-Femur Segment (Thick Arched Thigh)
	draw_line(leg.root, leg.knee, col_chitin, 3.2, false)
	draw_line(leg.root, leg.knee, col_hi, 1.2, false)

	# 2. Knee Joint Armor Spur (High Arched Peak)
	draw_circle(leg.knee, 2.2, col_chitin)
	draw_circle(leg.knee - Vector2(0.6, 0.6), 1.2, col_spec)

	# 3. Tibia-Tarsus Segment (Tapered Lower Leg)
	draw_line(leg.knee, leg.foot, col_chitin, 2.2, false)
	draw_line(leg.knee - Vector2(0.4, 0.0), leg.foot - Vector2(0.4, 0.0), col_hi, 0.9, false)

	# 4. Sharp Curved Claw Tip
	draw_circle(leg.foot, 1.3, COL_CHITIN_DARK)

# --- BULBOUS TOXIC OPISTHOSOMA (ABDOMEN) ---
func _draw_toxic_abdomen(pos: Vector2, is_rear: bool) -> void:
	var pulse = sin(idle_time * 5.0) * 0.06
	var rx = 16.5 * (1.0 + pulse)
	var ry = 13.5 * (1.0 + pulse)

	# 1. Dark Chitinous Abdomen Dome
	var abd_pts = PackedVector2Array()
	for i in range(16):
		var a = i * TAU / 16.0
		abd_pts.append(pos + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(abd_pts, COL_CHITIN_DARK)

	# 2. Segmented Chitin Tergite Plates
	for s in range(3):
		var sy = pos.y - 6.0 + (float(s) * 5.5)
		var sw = rx * (1.0 - (float(s) * 0.18))
		draw_line(Vector2(pos.x - sw * 0.75, sy), Vector2(pos.x + sw * 0.75, sy), COL_CHITIN_MID, 1.6, false)

	# 3. Pulsing Bioluminescent Venom Gland & Vein Network
	var gland_pulse = (sin(idle_time * 6.0) * 0.5 + 0.5)
	var g_pos = pos + Vector2(0.0, 1.5)

	# Toxic core aura
	draw_circle(g_pos, 7.5 + (gland_pulse * 1.5), COL_TOXIC_DARK)
	draw_circle(g_pos, 4.5 + (gland_pulse * 1.0), COL_TOXIC_BASE)
	draw_circle(g_pos - Vector2(1.0, 1.0), 2.2, COL_TOXIC_BRIGHT)
	draw_circle(g_pos - Vector2(1.5, 1.5), 1.0, Color.WHITE)

	# Branching Bioluminescent Acid Veins
	draw_line(g_pos, g_pos + Vector2(-7.5, -4.5), COL_TOXIC_BRIGHT, 1.2, false)
	draw_line(g_pos, g_pos + Vector2(7.5, -4.5), COL_TOXIC_BRIGHT, 1.2, false)
	draw_line(g_pos, g_pos + Vector2(-6.0, 5.5), COL_TOXIC_BASE, 1.0, false)
	draw_line(g_pos, g_pos + Vector2(6.0, 5.5), COL_TOXIC_BASE, 1.0, false)

	# Spherical Specular Glint
	draw_circle(pos - Vector2(rx * 0.35, ry * 0.35), 1.6, COL_CHITIN_SPEC)

# --- CEPHALOTHORAX CARAPACE & RUBY EYES ---
func _draw_cephalothorax(cen: Vector2, is_rear: bool, is_profile: bool) -> void:
	var rx = 10.5 if not is_profile else 9.0
	var ry = 7.5

	var car_pts = PackedVector2Array()
	for i in range(14):
		var a = i * TAU / 14.0
		car_pts.append(cen + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(car_pts, COL_CHITIN_BASE)
	draw_polyline(car_pts, COL_CHITIN_DARK, 1.2, true)

	# Central Thoracic Fovea Depression & Armor Grooves
	draw_line(cen - Vector2(0.0, 2.5), cen + Vector2(0.0, 2.5), COL_CHITIN_DARK, 2.0, false)
	draw_line(cen - Vector2(rx * 0.6, 0.0), cen - Vector2(2.0, 0.0), COL_CHITIN_HI, 1.2, false)
	draw_line(cen + Vector2(2.0, 0.0), cen + Vector2(rx * 0.6, 0.0), COL_CHITIN_HI, 1.2, false)

# --- 8-RUBY EYES & DRIPPING VENOM FANGS ---
func _draw_eyes_and_fangs(cen: Vector2, facing_ang: float, is_rear: bool, is_profile: bool, flip_x: float) -> void:
	if is_rear:
		return

	var fwd = Vector2(cos(facing_ang), sin(facing_ang) * 0.5).normalized()
	var perp = Vector2(-fwd.y, fwd.x).normalized()

	var head_pt = cen + fwd * 8.5

	# 1. 8-Ruby Eye Cluster
	if not is_profile:
		# Front Cluster: 2 Principal Median Eyes + 6 Lateral Ocelli
		var e_cen = head_pt - fwd * 2.5
		# Principal Eyes
		draw_circle(e_cen - perp * 2.6, 1.8, COL_EYE_CORE)
		draw_circle(e_cen - perp * 2.6 - Vector2(0.4, 0.4), 0.7, COL_EYE_GLINT)
		draw_circle(e_cen + perp * 2.6, 1.8, COL_EYE_CORE)
		draw_circle(e_cen + perp * 2.6 - Vector2(0.4, 0.4), 0.7, COL_EYE_GLINT)
		# Lateral Secondary Eyes
		draw_circle(e_cen - perp * 5.2 - fwd * 1.0, 1.2, COL_EYE_CORE)
		draw_circle(e_cen + perp * 5.2 - fwd * 1.0, 1.2, COL_EYE_CORE)
		draw_circle(e_cen - perp * 4.0 + fwd * 1.2, 1.0, COL_EYE_CORE)
		draw_circle(e_cen + perp * 4.0 + fwd * 1.2, 1.0, COL_EYE_CORE)
	else:
		# Profile Cluster (4 eyes visible on profile side)
		var e_cen = head_pt + fwd * 1.5
		draw_circle(e_cen, 2.0, COL_EYE_CORE)
		draw_circle(e_cen - Vector2(0.5, 0.5), 0.8, COL_EYE_GLINT)
		draw_circle(e_cen - perp * 2.8 * flip_x - fwd * 1.5, 1.3, COL_EYE_CORE)
		draw_circle(e_cen - perp * 4.5 * flip_x - fwd * 1.5, 1.0, COL_EYE_CORE)

	# 2. Articulated Chelicerae & Dripping Venom Fangs
	var f_spread = fangs_spread
	var l_fang_base = head_pt - perp * (2.8 + f_spread * 0.5) + fwd * 1.5
	var r_fang_base = head_pt + perp * (2.8 + f_spread * 0.5) + fwd * 1.5

	var l_fang_tip = l_fang_base + fwd * 5.5 - perp * 1.2
	var r_fang_tip = r_fang_base + fwd * 5.5 + perp * 1.2

	# Left fang
	draw_line(l_fang_base, l_fang_tip, COL_FANG_IVORY, 2.4, false)
	draw_line(l_fang_tip - fwd * 1.5, l_fang_tip, COL_FANG_TIP, 2.0, false)
	draw_circle(l_fang_tip, 1.0, COL_TOXIC_BRIGHT)

	# Right fang
	draw_line(r_fang_base, r_fang_tip, COL_FANG_IVORY, 2.4, false)
	draw_line(r_fang_tip - fwd * 1.5, r_fang_tip, COL_FANG_TIP, 2.0, false)
	draw_circle(r_fang_tip, 1.0, COL_TOXIC_BRIGHT)

	# Dripping Venom Droplet when idle or biting
	var drip = fmod(idle_time * 4.0, 1.5)
	if drip < 1.0:
		var d_pos = lerp(l_fang_tip, l_fang_tip + Vector2(0.0, 5.0), drip)
		draw_circle(d_pos, 0.9 * (1.0 - drip * 0.5), COL_TOXIC_BRIGHT)

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
