class_name Knight2DVisualRenderer
extends Node2D

## 2.5D Medieval Dark Knight Visual Renderer (Pixel-Art Masterclass)
## Features:
## - Full-Body Kinetic Combat Animations adapted for ALL 8 DIRECTIONS:
##   * Direction-relative kinematics (lunge, torso twist, hilt trajectory, and wind arc)
##   * Combo 0: Heavy Horizontal Cleave (150° forward sweep relative to aim)
##   * Combo 1: Rising Diagonal Backhand (reverse rising crescent relative to aim)
##   * Combo 2: Titanic Wide-Area Sweeping Cleave (260° massive whirlwind sweep)
## - Massive, Bold Curved Wind Crescent ("Đường cong gió to, cực kì LỰC"):
##   * Single thick, tapered aerodynamic crescent blade with luminous core & razor cutting edge
##   * Scaled up to 52px radius with 18px thick belly on wide-area finisher
## - Isometric 2:1 perspective foreshortening on all arcs and lunges
## - 8 Distinct Directional Angles (E, SE, S, SW, W, NW, N, NE)
## - Sabatons grounded strictly at y=0 with expanding contact shadow during lunges
## - Greathelm with Incandescent Glowing Soul-Slit Visor (cyan HDR)
## - Heater Shield with Golden Cross Emblem & Directional Guard / Parry
## - Cloth-simulated Crimson Cape reacting to body rotation and momentum
## - Pixel-grid quantized coordinates for authentic retro pixel-art aesthetic

enum Dir8 { E = 0, SE = 1, S = 2, SW = 3, W = 4, NW = 5, N = 6, NE = 7 }

var current_dir: Dir8 = Dir8.S
var is_moving: bool = false
var speed_ratio: float = 0.0
var is_guarding: bool = false
var is_parrying: bool = false
var is_attacking: bool = false
var attack_combo: int = 0
var attack_timer: float = 0.0
var current_attack_duration: float = 0.35

# Animation Cycles & Blends
var walk_cycle: float = 0.0
var idle_timer: float = 0.0
var cape_phase: float = 0.0
var guard_blend: float = 0.0
var parry_blend: float = 0.0
var attack_progress: float = 0.0
var parry_timer: float = 0.0
var current_parry_duration: float = 0.35
var parry_progress: float = 0.0
var base_attack_dir: Dir8 = Dir8.S
var prev_attacking: bool = false
var current_move_vec: Vector2 = Vector2.ZERO

# Kinetic Body Parameters (computed during attack)
var body_twist: float = 0.0       # Torso rotation angle (radians)
var body_lunge: Vector2 = Vector2.ZERO # Body translation offset
var body_crouch: float = 0.0      # Vertical compression
var cape_whip: Vector2 = Vector2.ZERO  # Cape momentum offset

# Equipment & Trail Transform Caches for 2.5D Layered Drawing
var shield_pos: Vector2 = Vector2.ZERO
var shield_ang: float = 0.0
var shield_scale_x: float = 1.0
var shield_is_facing_away: bool = false
var shield_in_front: bool = true

var sword_pos: Vector2 = Vector2.ZERO
var sword_ang: float = 0.0
var blade_len: float = 25.0
var sword_in_front: bool = true

var has_trail: bool = false
var trail_center: Vector2 = Vector2.ZERO
var trail_blade_ang: float = 0.0
var trail_sweep_dir: float = 1.0
var trail_span: float = 0.0
var trail_r_hilt: float = 13.0
var trail_r_tip: float = 39.0
var trail_is_finisher: bool = false
var trail_in_front: bool = true

var has_parry_arc: bool = false
var parry_arc_center: Vector2 = Vector2.ZERO
var parry_arc_radius: float = 21.0
var parry_arc_start_ang: float = 0.0
var parry_arc_sweep_dir: float = 1.0
var parry_arc_span: float = 0.0
var parry_arc_alpha: float = 0.0

# 16-Color Dark Knight Palette
const COL_ARMOR_BASE = Color(0.14, 0.16, 0.20)
const COL_ARMOR_MID  = Color(0.24, 0.27, 0.33)
const COL_ARMOR_HI   = Color(0.44, 0.49, 0.58)
const COL_ARMOR_DARK = Color(0.07, 0.08, 0.11)
const COL_GOLD_TRIM  = Color(0.88, 0.74, 0.30)
const COL_GOLD_SHINE = Color(1.0, 0.94, 0.62)
const COL_CAPE_DARK  = Color(0.32, 0.05, 0.08)
const COL_CAPE_MID   = Color(0.58, 0.09, 0.14)
const COL_CAPE_HI    = Color(0.78, 0.18, 0.22)
const COL_VISOR_CORE = Color(0.85, 1.0, 1.0, 1.0)
const COL_VISOR_GLOW = Color(0.20, 0.88, 1.0, 0.90)
const COL_STEEL_BLADE= Color(0.84, 0.88, 0.95)
const COL_STEEL_EDGE = Color(1.0, 1.0, 1.0)
const COL_LEATHER    = Color(0.22, 0.14, 0.08)
const COL_SHIELD_BG  = Color(0.10, 0.12, 0.18)

func _ready() -> void:
	z_as_relative = true
	z_index = 1

func update_state(
	delta: float,
	dir: int,
	moving: bool,
	speed_rat: float,
	guarding: bool,
	parrying: bool,
	attacking: bool,
	combo: int,
	att_timer: float,
	att_duration: float = 0.35,
	move_vec: Vector2 = Vector2.ZERO,
	p_timer: float = 0.0,
	p_duration: float = 0.35
) -> void:
	current_move_vec = move_vec
	if attacking and not prev_attacking:
		base_attack_dir = dir as Dir8
	prev_attacking = attacking

	if not attacking or combo != 2:
		current_dir = dir as Dir8
	is_moving = moving
	speed_ratio = speed_rat
	is_guarding = guarding
	is_parrying = parrying
	is_attacking = attacking
	attack_combo = combo
	attack_timer = att_timer
	current_attack_duration = maxf(att_duration, 0.01)
	parry_timer = p_timer
	current_parry_duration = maxf(p_duration, 0.01)

	# Update idle and walk frequencies
	idle_timer += delta * 2.2
	if idle_timer > TAU * 10.0:
		idle_timer = 0.0

	var walk_freq = 9.0 + (speed_ratio * 5.0)
	if is_moving and not is_attacking and not is_parrying:
		walk_cycle += delta * walk_freq
		if walk_cycle > TAU * 100.0:
			walk_cycle = 0.0
	else:
		walk_cycle = lerpf(walk_cycle, 0.0, delta * 10.0)

	var cape_speed = 3.5 if not is_moving else (7.0 + speed_ratio * 6.0)
	cape_phase += delta * cape_speed
	if cape_phase > TAU * 100.0:
		cape_phase = 0.0

	guard_blend = move_toward(guard_blend, 1.0 if is_guarding else 0.0, delta * 12.0)
	parry_blend = move_toward(parry_blend, 1.0 if is_parrying else 0.0, delta * 16.0)

	# COMPUTE FULL-BODY KINETIC TRAJECTORIES (ATTACK & PARRY ADAPTED TO 8 DIRECTIONS)
	if is_attacking:
		attack_progress = clampf(1.0 - (attack_timer / current_attack_duration), 0.0, 1.0)
		_compute_attack_kinetics(attack_progress, attack_combo)
	elif is_parrying:
		parry_progress = clampf(1.0 - (parry_timer / current_parry_duration), 0.0, 1.0)
		_compute_parry_kinetics(parry_progress)
	else:
		attack_progress = 0.0
		parry_progress = 0.0
		body_twist = move_toward(body_twist, 0.0, delta * 14.0)
		body_lunge = body_lunge.move_toward(Vector2.ZERO, delta * 30.0)
		body_crouch = move_toward(body_crouch, 0.0, delta * 14.0)
		cape_whip = cape_whip.move_toward(Vector2.ZERO, delta * 18.0)

	queue_redraw()

func _compute_attack_kinetics(t: float, combo: int) -> void:
	var aim_dir = _get_dir_vector(current_dir)
	var aim_ang = _get_dir_angle(current_dir)

	match combo:
		0: # HORIZONTAL CLEAVE
			if t < 0.22: # Windup Coil
				var p = t / 0.22
				body_twist = lerpf(0.0, 0.42, p)
				body_crouch = lerpf(0.0, 2.0, p)
				body_lunge = -aim_dir * lerpf(0.0, 2.5, p)
				cape_whip = -aim_dir * lerpf(0.0, 4.0, p)
			elif t < 0.62: # Release / Forward Drive & Cut
				var p = (t - 0.22) / 0.40
				var s = 1.0 - pow(1.0 - p, 2.6)
				body_twist = lerpf(0.42, -0.55, s)
				body_crouch = lerpf(2.0, 1.0, s)
				body_lunge = aim_dir * lerpf(-2.5, 9.0, s)
				cape_whip = -aim_dir * lerpf(-4.0, 8.0, s)
			else: # Follow-through & Recovery
				var p = (t - 0.62) / 0.38
				var r = p * p
				body_twist = lerpf(-0.55, 0.0, r)
				body_crouch = lerpf(1.0, 0.0, r)
				body_lunge = aim_dir * lerpf(9.0, 0.0, r)
				cape_whip = cape_whip.lerp(Vector2.ZERO, r)

		1: # RISING DIAGONAL BACKHAND
			if t < 0.20: # Low Coil
				var p = t / 0.20
				body_twist = lerpf(0.0, -0.45, p)
				body_crouch = lerpf(0.0, 3.5, p)
				body_lunge = -aim_dir * lerpf(0.0, 1.5, p)
				cape_whip = Vector2(0, 3.0 * p)
			elif t < 0.58: # Rising Uppercut Slash
				var p = (t - 0.20) / 0.38
				var s = 1.0 - pow(1.0 - p, 2.5)
				body_twist = lerpf(-0.45, 0.50, s)
				body_crouch = lerpf(3.5, -2.5, s)
				body_lunge = aim_dir * lerpf(-1.5, 8.0, s)
				cape_whip = -aim_dir * lerpf(0.0, 7.0, s)
			else: # Recovery
				var p = (t - 0.58) / 0.42
				var r = p * p
				body_twist = lerpf(0.50, 0.0, r)
				body_crouch = lerpf(-2.5, 0.0, r)
				body_lunge = aim_dir * lerpf(8.0, 0.0, r)
				cape_whip = cape_whip.lerp(Vector2.ZERO, r)

		2: # 360° WHIRLWIND TEMPEST CLEAVE (FINISHER)
			var base_vec = _get_dir_vector(base_attack_dir)
			var base_ang = _get_dir_angle(base_attack_dir)

			if t < 0.18: # Deep Coiled Windup: Knight gathers centrifugal kinetic energy
				var p = t / 0.18
				body_twist = lerpf(0.0, -0.65, p) # Coil counter-clockwise
				body_crouch = lerpf(0.0, 3.2, p)  # Crouch low
				body_lunge = -base_vec * lerpf(0.0, 3.5, p)
				cape_whip = -base_vec * lerpf(0.0, 5.0, p)
				current_dir = base_attack_dir
			elif t < 0.70: # 360° EXPLOSIVE WHIRLWIND SPIN!
				var p = (t - 0.18) / 0.52
				var s = 1.0 - pow(1.0 - p, 2.4)

				# Spin character visual direction through all 8 isometric angles
				var octant_spin = int(floor(s * 8.0))
				current_dir = ((int(base_attack_dir) + octant_spin) % 8) as Dir8

				# Micro torque between discrete octants
				var octant_frac = (s * 8.0) - float(octant_spin)
				body_twist = lerpf(-0.35, 0.35, octant_frac)
				body_crouch = lerpf(3.2, 1.0, s)

				# Centrifugal lunge momentum along base facing direction
				body_lunge = base_vec * lerpf(-3.5, 11.0, sin(p * PI * 0.65))

				# Cape flutters out in dynamic centrifugal ring
				var spin_rad = base_ang + s * TAU
				cape_whip = Vector2(-cos(spin_rad), -sin(spin_rad) * 0.70) * (14.0 * sin(p * PI))
			else: # Follow-through & Grounded Recovery
				var p = (t - 0.70) / 0.30
				var r = p * p
				current_dir = base_attack_dir
				body_twist = lerpf(0.35, 0.0, r)
				body_crouch = lerpf(1.0, 0.0, r)
				body_lunge = base_vec * lerpf(11.0, 0.0, r)
				cape_whip = cape_whip.lerp(Vector2.ZERO, r)

func _compute_parry_kinetics(t: float) -> void:
	var aim_dir = _get_dir_vector(current_dir)

	# Twist factor depending on 8-directional perspective:
	# Driving the shield forward in a sweep rotates the torso dynamically into the blow
	var twist_sign = -1.0
	match current_dir:
		Dir8.N:  twist_sign = 0.75
		Dir8.NE: twist_sign = 0.95
		Dir8.E:  twist_sign = 0.70
		Dir8.SE: twist_sign = -0.85
		Dir8.S:  twist_sign = -1.0
		Dir8.SW: twist_sign = -1.15
		Dir8.W:  twist_sign = -0.70
		Dir8.NW: twist_sign = 0.85

	if t < 0.18: # Phase 1: Rapid Elastic Coil (Inward tuck)
		var p = t / 0.18
		var s = sin(p * PI * 0.5)
		body_twist = twist_sign * lerpf(0.0, -0.16, s)
		body_crouch = lerpf(0.0, 1.8, s)
		body_lunge = -aim_dir * lerpf(0.0, 1.5, s)
		cape_whip = aim_dir * lerpf(0.0, 2.5, s)
	elif t < 0.60: # Phase 2: Explosive Outward Deflective Sweep Arc
		var p = (t - 0.18) / 0.42
		var s = 1.0 - pow(1.0 - p, 2.6)
		body_twist = twist_sign * lerpf(-0.16, 0.42, s)
		body_crouch = lerpf(1.8, 2.6, sin(p * PI * 0.8))
		body_lunge = aim_dir * lerpf(-1.5, 6.5, s)
		cape_whip = -aim_dir * lerpf(2.5, 8.0, s)
	elif t < 0.76: # Phase 3: Braced Impact Apex (Solid deflection lock)
		body_twist = twist_sign * 0.42
		body_crouch = 2.4
		body_lunge = aim_dir * 6.5
		cape_whip = -aim_dir * lerpf(8.0, 5.0, (t - 0.60) / 0.16)
	else: # Phase 4: Fluid Smoothstep Recovery back to combat stance
		var p = (t - 0.76) / 0.24
		var r = p * p * (3.0 - 2.0 * p)
		body_twist = twist_sign * lerpf(0.42, 0.0, r)
		body_crouch = lerpf(2.4, 0.0, r)
		body_lunge = aim_dir * lerpf(6.5, 0.0, r)
		cape_whip = cape_whip.lerp(Vector2.ZERO, r)

func _draw() -> void:
	# 1. DUAL GROUND CONTACT SHADOW (Expands with lunge, feet anchored at y=0)
	_draw_contact_shadow()

	# Compute all 8-directional weapon transforms & depth-sorting layers
	_compute_equipment_transforms()

	var is_rear = (current_dir == Dir8.N or current_dir == Dir8.NE or current_dir == Dir8.NW)

	# 2. BACKGROUND WEAPONS & TRAIL (BEHIND BODY)
	# When looking North / NE / NW or during rear-arc of 360° whirlwind, trail & sword are drawn here (UNDERNEATH the body)!
	if has_trail:
		if trail_is_finisher:
			_draw_blade_wind_trail(trail_center, trail_blade_ang, trail_sweep_dir, trail_span, trail_r_hilt, trail_r_tip, true, 1)
		elif not trail_in_front:
			_draw_blade_wind_trail(trail_center, trail_blade_ang, trail_sweep_dir, trail_span, trail_r_hilt, trail_r_tip, false, 0)
	if has_parry_arc and not shield_in_front:
		_draw_parry_crescent_arc(parry_arc_center, parry_arc_radius, parry_arc_start_ang, parry_arc_sweep_dir, parry_arc_span, parry_arc_alpha)
	if not shield_in_front:
		_draw_heater_shield(shield_pos, shield_ang, shield_scale_x, shield_is_facing_away)
	if not sword_in_front:
		_draw_broadsword(sword_pos, sword_ang, blade_len)

	# 3. CAPE (for front angles: behind torso; for rear angles: draped over backplate)
	if not is_rear:
		_draw_cape()

	# 4. LEGS & SABATONS (Full martial lunge stance during attacks)
	_draw_legs_and_sabatons(is_rear)

	# 5. TORSO, CUIRASS & PAULDRONS (Twists and lunges with kinetic torque)
	_draw_torso(is_rear)

	if is_rear:
		_draw_cape()

	# 6. GREATHELM & GLOWING SOUL-SLIT VISOR
	_draw_greathelm(is_rear)

	# 7. FOREGROUND WEAPONS & TRAIL (IN FRONT OF BODY)
	if has_trail:
		if trail_is_finisher:
			_draw_blade_wind_trail(trail_center, trail_blade_ang, trail_sweep_dir, trail_span, trail_r_hilt, trail_r_tip, true, 2)
		elif trail_in_front:
			_draw_blade_wind_trail(trail_center, trail_blade_ang, trail_sweep_dir, trail_span, trail_r_hilt, trail_r_tip, false, 0)
	if has_parry_arc and shield_in_front:
		_draw_parry_crescent_arc(parry_arc_center, parry_arc_radius, parry_arc_start_ang, parry_arc_sweep_dir, parry_arc_span, parry_arc_alpha)
	if shield_in_front:
		_draw_heater_shield(shield_pos, shield_ang, shield_scale_x, shield_is_facing_away)
	if sword_in_front:
		_draw_broadsword(sword_pos, sword_ang, blade_len)

func _get_vertical_bob() -> float:
	if is_moving and not is_attacking:
		return (absf(sin(walk_cycle)) * 1.6 - 0.8) * speed_ratio
	return sin(idle_timer) * 0.4

# --- CONTACT SHADOW ---
func _draw_contact_shadow() -> void:
	var lunge_dist = body_lunge.length()
	var shadow_rx = 13.0 + (lunge_dist * 0.4) + (speed_ratio * 3.0)
	var shadow_ry = shadow_rx * 0.42

	var center = Vector2(body_lunge.x * 0.4, 0.0)

	var outer_pts = PackedVector2Array()
	for i in range(16):
		var a = i * TAU / 16.0
		outer_pts.append(Vector2(roundf(cos(a) * shadow_rx), roundf(sin(a) * shadow_ry)) + center + Vector2(2, 1))
	draw_colored_polygon(outer_pts, Color(0.0, 0.0, 0.0, 0.38))

	var inner_pts = PackedVector2Array()
	var inner_rx = 9.0 + (lunge_dist * 0.3)
	var inner_ry = inner_rx * 0.40
	for i in range(16):
		var a = i * TAU / 16.0
		inner_pts.append(Vector2(roundf(cos(a) * inner_rx), roundf(sin(a) * inner_ry)) + center)
	draw_colored_polygon(inner_pts, Color(0.0, 0.0, 0.0, 0.68))

# --- CAPE (CLOTH & MOMENTUM SIMULATION WITH GOLDEN BROOCHES) ---
func _draw_cape() -> void:
	var anchor_y = -29.5 + body_crouch + body_lunge.y
	var anchor_l = Vector2(-5.5 + body_lunge.x, anchor_y)
	var anchor_r = Vector2(5.5 + body_lunge.x, anchor_y)

	var trail = Vector2.ZERO
	match current_dir:
		Dir8.E:  trail = Vector2(-11.0, -2.5)
		Dir8.SE: trail = Vector2(-7.5, -3.5)
		Dir8.S:  trail = Vector2(0.0, -4.5)
		Dir8.SW: trail = Vector2(7.5, -3.5)
		Dir8.W:  trail = Vector2(11.0, -2.5)
		Dir8.NW: trail = Vector2(5.5, 2.0)
		Dir8.N:  trail = Vector2(0.0, 2.5)
		Dir8.NE: trail = Vector2(-5.5, 2.0)

	trail += cape_whip

	var billow = speed_ratio * 7.5 + (body_lunge.length() * 0.75)
	var wave1 = sin(cape_phase) * (2.2 + billow * 0.35)
	var wave2 = cos(cape_phase * 1.3) * (1.8 + billow * 0.28)

	var hem_y = -8.5 + body_crouch + body_lunge.y
	var bottom_left = Vector2(-9.0 + trail.x - wave1, hem_y + trail.y)
	var bottom_mid_l= Vector2(-3.0 + trail.x + wave2 * 0.5, hem_y + trail.y + 1.2)
	var bottom_mid  = Vector2(trail.x + wave2, hem_y + trail.y + 2.0)
	var bottom_mid_r= Vector2(3.0 + trail.x - wave2 * 0.5, hem_y + trail.y + 1.2)
	var bottom_right= Vector2(9.0 + trail.x + wave1, hem_y + trail.y)

	# 1. Base shadow mantle
	var cape_poly = PackedVector2Array([anchor_l, anchor_r, bottom_right, bottom_mid_r, bottom_mid, bottom_mid_l, bottom_left])
	draw_colored_polygon(cape_poly, COL_CAPE_DARK)

	# 2. Lit main velvet folds
	var fold_poly = PackedVector2Array([
		Vector2(-2.2 + body_lunge.x, anchor_y + 1.5),
		Vector2(2.2 + body_lunge.x, anchor_y + 1.5),
		Vector2(bottom_mid_r.x, bottom_mid_r.y),
		Vector2(bottom_mid.x, bottom_mid.y + 0.5),
		Vector2(bottom_mid_l.x, bottom_mid_l.y)
	])
	draw_colored_polygon(fold_poly, COL_CAPE_MID)

	# 3. Crest highlight folds
	draw_line(Vector2(-1.5 + body_lunge.x, anchor_y + 2.0), bottom_mid_l, COL_CAPE_HI, 1.2, false)
	draw_line(Vector2(1.5 + body_lunge.x, anchor_y + 2.0), bottom_mid_r, COL_CAPE_HI, 1.0, false)

	# 4. Golden embroidered hemline
	var trim = PackedVector2Array([bottom_left, bottom_mid_l, bottom_mid, bottom_mid_r, bottom_right])
	draw_polyline(trim, COL_GOLD_TRIM, 1.4, false)
	draw_polyline(trim, COL_GOLD_SHINE, 0.7, false)

	# 5. Golden lion shoulder clasps
	draw_circle(anchor_l, 1.6, COL_GOLD_TRIM)
	draw_circle(anchor_l, 0.9, COL_GOLD_SHINE)
	draw_circle(anchor_r, 1.6, COL_GOLD_TRIM)
	draw_circle(anchor_r, 0.9, COL_GOLD_SHINE)

# --- LEGS & SABATONS (GROUNDED 8-DIRECTIONAL STRIDE & SABATONS) ---
func _draw_legs_and_sabatons(is_rear: bool) -> void:
	# 1. Base hip & foot coordinates configured per isometric direction
	var base_l_hip = Vector2(-4.5, -16.0)
	var base_r_hip = Vector2(4.5, -16.0)
	var base_l_foot = Vector2(-4.5, 0.0)
	var base_r_foot = Vector2(4.5, 0.0)

	match current_dir:
		Dir8.S, Dir8.N:
			base_l_hip = Vector2(-4.5, -16.0)
			base_r_hip = Vector2(4.5, -16.0)
			base_l_foot = Vector2(-4.5, 0.0)
			base_r_foot = Vector2(4.5, 0.0)
		Dir8.E:
			base_l_hip = Vector2(-1.5, -17.5) # Far hip (higher in Y)
			base_r_hip = Vector2(1.5, -14.5)  # Near hip (lower in Y)
			base_l_foot = Vector2(-1.5, -1.5)
			base_r_foot = Vector2(1.5, 1.5)
		Dir8.W:
			base_r_hip = Vector2(1.5, -17.5)  # Far hip
			base_l_hip = Vector2(-1.5, -14.5) # Near hip
			base_r_foot = Vector2(1.5, -1.5)
			base_l_foot = Vector2(-1.5, 1.5)
		Dir8.SE:
			base_l_hip = Vector2(-3.5, -17.0)
			base_r_hip = Vector2(4.0, -15.0)
			base_l_foot = Vector2(-3.5, -1.0)
			base_r_foot = Vector2(4.0, 1.0)
		Dir8.SW:
			base_r_hip = Vector2(3.5, -17.0)
			base_l_hip = Vector2(-4.0, -15.0)
			base_r_foot = Vector2(3.5, -1.0)
			base_l_foot = Vector2(-4.0, 1.0)
		Dir8.NE:
			base_l_hip = Vector2(-4.0, -15.0)
			base_r_hip = Vector2(3.5, -17.0)
			base_l_foot = Vector2(-4.0, 1.0)
			base_r_foot = Vector2(3.5, -1.0)
		Dir8.NW:
			base_r_hip = Vector2(4.0, -15.0)
			base_l_hip = Vector2(-3.5, -17.0)
			base_r_foot = Vector2(4.0, 1.0)
			base_l_foot = Vector2(-3.5, -1.0)

	var l_hip = base_l_hip + Vector2(0.0, body_crouch) + body_lunge
	var r_hip = base_r_hip + Vector2(0.0, body_crouch) + body_lunge

	var l_foot = base_l_foot
	var r_foot = base_r_foot
	var l_lift = 0.0
	var r_lift = 0.0

	var stride_dir = current_move_vec if (is_moving and current_move_vec != Vector2.ZERO) else _get_dir_vector(current_dir)

	if is_attacking:
		var lunge_dist = body_lunge.length()
		r_foot = base_r_foot + (stride_dir * lunge_dist * 0.85)
		l_foot = base_l_foot - (stride_dir * lunge_dist * 0.35)
	elif is_parrying:
		var p_dir = _get_dir_vector(current_dir)
		var p_lunge = body_lunge.length()
		l_foot = base_l_foot + (p_dir * p_lunge * 0.65)
		r_foot = base_r_foot - (p_dir * p_lunge * 0.25)
		l_lift = 0.0
		r_lift = 0.0
	elif is_moving:
		# Dynamic stride along the actual movement vector
		var stride_len = 4.5 + speed_ratio * 4.5
		var lift_height = 3.0 + speed_ratio * 2.2
		var swing = sin(walk_cycle)

		if swing > 0.0:
			# Right leg swinging forward along stride_dir
			var r_disp = stride_dir * (swing * stride_len)
			r_lift = sin(walk_cycle) * lift_height
			r_foot = base_r_foot + r_disp + Vector2(0.0, -r_lift)

			# Left leg planted on ground in stance phase
			var l_disp = -stride_dir * (swing * stride_len * 0.75)
			l_foot = base_l_foot + l_disp
		else:
			# Left leg swinging forward along stride_dir
			var l_disp = -stride_dir * (swing * stride_len)
			l_lift = -sin(walk_cycle) * lift_height
			l_foot = base_l_foot + l_disp + Vector2(0.0, -l_lift)

			# Right leg planted on ground in stance phase
			var r_disp = stride_dir * (swing * stride_len * 0.75)
			r_foot = base_r_foot + r_disp
	else:
		l_foot = base_l_foot
		r_foot = base_r_foot

	# Depth-sorting: draw the far leg first (behind), then the near leg (in front)
	var left_in_front = (l_foot.y > r_foot.y) or (l_foot.y == r_foot.y and l_hip.y >= r_hip.y)
	if left_in_front:
		_draw_single_leg(r_hip, r_foot, true, is_rear, r_lift, stride_dir, true)
		_draw_single_leg(l_hip, l_foot, false, is_rear, l_lift, stride_dir, false)
	else:
		_draw_single_leg(l_hip, l_foot, false, is_rear, l_lift, stride_dir, true)
		_draw_single_leg(r_hip, r_foot, true, is_rear, r_lift, stride_dir, false)

func _draw_single_leg(
	hip: Vector2,
	foot: Vector2,
	is_right: bool,
	is_rear: bool,
	lift: float,
	stride_dir: Vector2,
	is_shaded: bool = false
) -> void:
	var col_base = COL_ARMOR_DARK if is_shaded else COL_ARMOR_BASE
	var col_mid  = COL_ARMOR_BASE if is_shaded else COL_ARMOR_MID
	var col_hi   = COL_ARMOR_MID  if is_shaded else COL_ARMOR_HI

	# Knee bends naturally in direction of stride
	var knee = (hip + foot) * 0.5
	if lift > 0.2:
		knee += (stride_dir * 1.6) + Vector2(0.0, -1.2)
	else:
		knee += Vector2(0.0, -0.5)

	# Cuisse (thigh) & Greave (shin)
	var thigh_poly = PackedVector2Array([
		hip + Vector2(-2.5, 0.0),
		hip + Vector2(2.5, 0.0),
		knee + Vector2(2.5, 0.0),
		knee + Vector2(-2.5, 0.0)
	])
	draw_colored_polygon(thigh_poly, col_base)

	var shin_poly = PackedVector2Array([
		knee + Vector2(-2.4, 0.0),
		knee + Vector2(2.4, 0.0),
		foot + Vector2(2.2, -2.0),
		foot + Vector2(-2.2, -2.0)
	])
	draw_colored_polygon(shin_poly, col_base)

	# Poleyn (Knee Cap Armor)
	draw_rect(Rect2(knee + Vector2(-2.0, -1.5), Vector2(4.0, 3.0)), col_mid)
	if not is_shaded:
		draw_line(knee + Vector2(-1.5, -1.5), knee + Vector2(1.5, -1.5), col_hi, 1.0, false)

	# Greave shin ridge
	draw_line(knee + Vector2(0.0, 1.0), foot + Vector2(0.0, -2.0), col_hi if not is_shaded else col_mid, 1.0, false)

	# --- 8-DIRECTIONAL SABATONS (BOOTS) ---
	var sabaton = PackedVector2Array()
	var toe_pt = Vector2.ZERO

	match current_dir:
		Dir8.S:
			# South: Gothic pointed sabaton facing directly forward (+Y)
			toe_pt = foot + Vector2(0.0, 3.5)
			sabaton.append(foot + Vector2(-2.8, -2.0))
			sabaton.append(foot + Vector2(2.8, -2.0))
			sabaton.append(foot + Vector2(2.2, 0.5))
			sabaton.append(toe_pt)
			sabaton.append(foot + Vector2(-2.2, 0.5))

		Dir8.N:
			# North: Heel cup seen from behind
			sabaton.append(foot + Vector2(-2.8, -2.0))
			sabaton.append(foot + Vector2(2.8, -2.0))
			sabaton.append(foot + Vector2(2.2, 0.5))
			sabaton.append(foot + Vector2(-2.2, 0.5))
			if lift > 0.4:
				toe_pt = foot + Vector2(0.0, -2.5)

		Dir8.E:
			# East: Profile pointing right (+X)
			toe_pt = foot + Vector2(5.5, 0.0)
			sabaton.append(foot + Vector2(-2.8, -2.0))
			sabaton.append(foot + Vector2(1.5, -2.0))
			sabaton.append(toe_pt)
			sabaton.append(foot + Vector2(1.5, 0.5))
			sabaton.append(foot + Vector2(-2.8, 0.5))

		Dir8.W:
			# West: Profile pointing left (-X)
			toe_pt = foot + Vector2(-5.5, 0.0)
			sabaton.append(foot + Vector2(2.8, -2.0))
			sabaton.append(foot + Vector2(-1.5, -2.0))
			sabaton.append(toe_pt)
			sabaton.append(foot + Vector2(-1.5, 0.5))
			sabaton.append(foot + Vector2(2.8, 0.5))

		Dir8.SE:
			# South-East: Pointing down-right
			toe_pt = foot + Vector2(4.2, 2.5)
			sabaton.append(foot + Vector2(-2.8, -2.0))
			sabaton.append(foot + Vector2(2.0, -2.0))
			sabaton.append(toe_pt)
			sabaton.append(foot + Vector2(1.0, 1.0))
			sabaton.append(foot + Vector2(-2.8, 0.5))

		Dir8.SW:
			# South-West: Pointing down-left
			toe_pt = foot + Vector2(-4.2, 2.5)
			sabaton.append(toe_pt)
			sabaton.append(foot + Vector2(-2.0, -2.0))
			sabaton.append(foot + Vector2(2.8, -2.0))
			sabaton.append(foot + Vector2(2.8, 0.5))
			sabaton.append(foot + Vector2(-1.0, 1.0))

		Dir8.NE:
			# North-East: Pointing up-right
			toe_pt = foot + Vector2(3.8, -2.5)
			sabaton.append(foot + Vector2(-2.8, -1.0))
			sabaton.append(toe_pt)
			sabaton.append(foot + Vector2(2.5, -0.5))
			sabaton.append(foot + Vector2(2.0, 1.0))
			sabaton.append(foot + Vector2(-2.5, 1.0))

		Dir8.NW:
			# North-West: Pointing up-left
			toe_pt = foot + Vector2(-3.8, -2.5)
			sabaton.append(toe_pt)
			sabaton.append(foot + Vector2(2.8, -1.0))
			sabaton.append(foot + Vector2(2.5, 1.0))
			sabaton.append(foot + Vector2(-2.0, 1.0))
			sabaton.append(foot + Vector2(-2.5, -0.5))

	draw_colored_polygon(sabaton, col_mid)

	# Sabaton top plate highlight / ridge
	if toe_pt != Vector2.ZERO:
		draw_line(foot + Vector2(0.0, -1.5), toe_pt, col_hi, 1.2, false)
	elif current_dir == Dir8.N:
		draw_line(foot + Vector2(-2.0, -1.5), foot + Vector2(2.0, -1.5), col_hi, 1.0, false)

# --- TORSO, CUIRASS & PAULDRONS (SLENDER ATHLETIC V-TAPER & 3D VOLUMETRIC PLATES) ---
func _draw_torso(is_rear: bool) -> void:
	var bob = _get_vertical_bob()
	var base_y = -16.0 + bob + body_crouch + body_lunge.y
	var waist_y = -19.5 + bob + body_crouch + body_lunge.y
	var mid_chest_y = -24.5 + bob + body_crouch + body_lunge.y
	var chest_y = -29.0 + bob + body_crouch + body_lunge.y
	var center_x = body_lunge.x

	var walk_twist = sin(walk_cycle) * 0.08 * speed_ratio if (is_moving and not is_attacking) else 0.0
	var twist_offset = (body_twist + walk_twist) * 5.0

	var is_profile = (current_dir == Dir8.E or current_dir == Dir8.W)

	# -------------------------------------------------------------
	# 1. FAULD, CHAINMAIL SKIRT & GOTHIC TASSETS (Hips to Waist Y: [-16, -19.5])
	# -------------------------------------------------------------
	# Base chainmail underpinning matching hip connection at Y = -16.0
	var mail_skirt = PackedVector2Array([
		Vector2(center_x - 4.2 + twist_offset * 0.2, waist_y),
		Vector2(center_x + 4.2 + twist_offset * 0.2, waist_y),
		Vector2(center_x + 4.6, base_y),
		Vector2(center_x - 4.6, base_y)
	])
	draw_colored_polygon(mail_skirt, COL_ARMOR_DARK)

	if not is_rear and not is_profile:
		# Two distinct pointed Gothic Tassets over the thighs with a visible center chainmail slit
		# Left Tasset (facing viewer's left)
		var tasset_l = PackedVector2Array([
			Vector2(center_x - 4.6 + twist_offset * 0.2, waist_y + 0.5),
			Vector2(center_x - 1.0 + twist_offset * 0.2, waist_y + 0.5),
			Vector2(center_x - 1.1 + twist_offset * 0.1, base_y - 0.5),
			Vector2(center_x - 2.8 + twist_offset * 0.1, base_y + 1.2),
			Vector2(center_x - 4.7 + twist_offset * 0.1, base_y - 0.5)
		])
		draw_colored_polygon(tasset_l, COL_ARMOR_MID)
		draw_line(Vector2(center_x - 2.8 + twist_offset * 0.1, waist_y + 0.5), Vector2(center_x - 2.8 + twist_offset * 0.1, base_y + 1.2), COL_ARMOR_HI, 1.0, false)
		draw_circle(Vector2(center_x - 3.8 + twist_offset * 0.2, waist_y + 1.4), 0.7, COL_GOLD_TRIM)

		# Right Tasset (facing viewer's right - shaded)
		var tasset_r = PackedVector2Array([
			Vector2(center_x + 1.0 + twist_offset * 0.2, waist_y + 0.5),
			Vector2(center_x + 4.6 + twist_offset * 0.2, waist_y + 0.5),
			Vector2(center_x + 4.7 + twist_offset * 0.1, base_y - 0.5),
			Vector2(center_x + 2.8 + twist_offset * 0.1, base_y + 1.2),
			Vector2(center_x + 1.1 + twist_offset * 0.1, base_y - 0.5)
		])
		draw_colored_polygon(tasset_r, COL_ARMOR_BASE)
		draw_line(Vector2(center_x + 2.8 + twist_offset * 0.1, waist_y + 0.5), Vector2(center_x + 2.8 + twist_offset * 0.1, base_y + 1.2), COL_ARMOR_MID, 1.0, false)
		draw_circle(Vector2(center_x + 3.8 + twist_offset * 0.2, waist_y + 1.4), 0.7, COL_GOLD_TRIM)
	elif is_profile:
		# Profile tasset: angled thigh plate
		var p_sign = 1.0 if current_dir == Dir8.E else -1.0
		var tasset_prof = PackedVector2Array([
			Vector2(center_x - 2.5 * p_sign, waist_y + 0.5),
			Vector2(center_x + 3.5 * p_sign, waist_y + 0.5),
			Vector2(center_x + 3.0 * p_sign, base_y - 0.2),
			Vector2(center_x + 0.5 * p_sign, base_y + 1.5),
			Vector2(center_x - 2.8 * p_sign, base_y - 0.2)
		])
		draw_colored_polygon(tasset_prof, COL_ARMOR_BASE if p_sign > 0 else COL_ARMOR_MID)
		draw_line(Vector2(center_x + 0.5 * p_sign, waist_y + 0.5), Vector2(center_x + 0.5 * p_sign, base_y + 1.5), COL_ARMOR_HI, 1.0, false)
	else:
		# Rear culet: horizontal lames
		draw_line(Vector2(center_x - 4.2, waist_y + 1.2), Vector2(center_x + 4.2, waist_y + 1.2), COL_ARMOR_BASE, 1.4, false)
		draw_line(Vector2(center_x - 4.4, waist_y + 2.8), Vector2(center_x + 4.4, waist_y + 2.8), COL_ARMOR_DARK, 1.2, false)

	# -------------------------------------------------------------
	# 2. STUDDED LEATHER BELT & GOLD BUCKLE (Waist Y: ~ -19.5)
	# -------------------------------------------------------------
	var belt_w = 4.4 if not is_profile else 3.2
	draw_line(Vector2(center_x - belt_w + twist_offset * 0.2, waist_y), Vector2(center_x + belt_w + twist_offset * 0.2, waist_y), COL_LEATHER, 1.8, false)
	if not is_rear:
		var buckle_shift = 0.0
		if current_dir == Dir8.SE or current_dir == Dir8.E:
			buckle_shift = 1.2
		elif current_dir == Dir8.SW or current_dir == Dir8.W:
			buckle_shift = -1.2
		var buckle_pos = Vector2(center_x + buckle_shift + twist_offset * 0.2, waist_y)
		draw_rect(Rect2(buckle_pos - Vector2(1.5, 1.2), Vector2(3.0, 2.4)), COL_GOLD_TRIM)
		draw_rect(Rect2(buckle_pos - Vector2(0.6, 0.6), Vector2(1.2, 1.2)), COL_GOLD_SHINE)
		# Gold belt rivets
		if not is_profile:
			draw_circle(Vector2(center_x - 3.4 + twist_offset * 0.2, waist_y), 0.6, COL_GOLD_TRIM)
			draw_circle(Vector2(center_x + 3.4 + twist_offset * 0.2, waist_y), 0.6, COL_GOLD_TRIM)

	# -------------------------------------------------------------
	# 3. CUIRASS / BREASTPLATE (SLENDER V-TAPER WITH GOTHIC FLUTING & 3D ARÊTE)
	# -------------------------------------------------------------
	if not is_rear and not is_profile:
		# 3D Bi-Facet Gothic Breastplate
		var ridge_x = center_x + twist_offset * 0.6
		if current_dir == Dir8.SE:
			ridge_x += 1.4
		elif current_dir == Dir8.SW:
			ridge_x -= 1.4

		var left_w_waist = 4.2
		var right_w_waist = 4.2
		var left_w_chest = 5.8
		var right_w_chest = 5.8
		var left_w_neck = 3.8
		var right_w_neck = 3.8

		if current_dir == Dir8.SE:
			left_w_chest = 6.2
			right_w_chest = 4.4
		elif current_dir == Dir8.SW:
			left_w_chest = 4.4
			right_w_chest = 6.2

		# Left Pectoral Facet (Illuminated by key light)
		var facet_l = PackedVector2Array([
			Vector2(center_x - left_w_waist + twist_offset * 0.2, waist_y - 0.5),
			Vector2(ridge_x, waist_y - 0.5),
			Vector2(ridge_x, chest_y + 1.0),
			Vector2(center_x - left_w_neck + twist_offset, chest_y),
			Vector2(center_x - left_w_chest + twist_offset * 0.8, mid_chest_y),
			Vector2(center_x - left_w_chest * 0.95 + twist_offset * 0.4, mid_chest_y + 2.5)
		])
		draw_colored_polygon(facet_l, COL_ARMOR_MID)

		# Right Pectoral Facet (In isometric under-shadow)
		var facet_r = PackedVector2Array([
			Vector2(ridge_x, waist_y - 0.5),
			Vector2(center_x + right_w_waist + twist_offset * 0.2, waist_y - 0.5),
			Vector2(center_x + right_w_chest * 0.95 + twist_offset * 0.4, mid_chest_y + 2.5),
			Vector2(center_x + right_w_chest + twist_offset * 0.8, mid_chest_y),
			Vector2(center_x + right_w_neck + twist_offset, chest_y),
			Vector2(ridge_x, chest_y + 1.0)
		])
		draw_colored_polygon(facet_r, COL_ARMOR_BASE)

		# Gothic Fluting Grooves (Embossed diagonal chiseled ridges)
		draw_line(
			Vector2(ridge_x - 1.2, waist_y - 1.0),
			Vector2(center_x - left_w_chest * 0.65 + twist_offset * 0.8, mid_chest_y + 0.5),
			COL_ARMOR_HI, 0.9, false
		)
		draw_line(
			Vector2(ridge_x + 1.2, waist_y - 1.0),
			Vector2(center_x + right_w_chest * 0.65 + twist_offset * 0.8, mid_chest_y + 0.5),
			COL_ARMOR_DARK, 0.9, false
		)

		# Central Gothic Arête (Specular Steel Keel)
		draw_line(Vector2(ridge_x, chest_y + 1.0), Vector2(ridge_x, waist_y - 0.5), COL_ARMOR_HI, 1.4, false)

		# Collar rim highlight
		draw_line(
			Vector2(center_x - left_w_neck + twist_offset, chest_y),
			Vector2(center_x + right_w_neck + twist_offset, chest_y),
			COL_ARMOR_HI, 1.2, false
		)

	elif is_profile:
		# Profile Torso: Convex anterior chest arc, concave dorsal back curve
		var p_sign = 1.0 if current_dir == Dir8.E else -1.0
		var prof_poly = PackedVector2Array([
			Vector2(center_x - 3.2 * p_sign, waist_y - 0.5),
			Vector2(center_x + 3.4 * p_sign, waist_y - 0.5),
			Vector2(center_x + 4.8 * p_sign + twist_offset * 0.5, mid_chest_y),
			Vector2(center_x + 3.2 * p_sign + twist_offset, chest_y),
			Vector2(center_x - 2.8 * p_sign + twist_offset, chest_y),
			Vector2(center_x - 3.6 * p_sign + twist_offset * 0.5, mid_chest_y)
		])
		draw_colored_polygon(prof_poly, COL_ARMOR_MID if p_sign > 0 else COL_ARMOR_BASE)
		# Side articulation hinge / leather buckle
		draw_line(Vector2(center_x, waist_y - 1.0), Vector2(center_x, mid_chest_y), COL_ARMOR_DARK, 1.0, false)
		draw_circle(Vector2(center_x, mid_chest_y), 0.9, COL_GOLD_TRIM)
		# Front chest rim specular line
		draw_line(
			Vector2(center_x + 4.8 * p_sign + twist_offset * 0.5, mid_chest_y),
			Vector2(center_x + 3.2 * p_sign + twist_offset, chest_y),
			COL_ARMOR_HI, 1.2, false
		)

	else:
		# Rear Backplate (Dorsal Spine & Shoulder Harness)
		var back_poly = PackedVector2Array([
			Vector2(center_x - 4.2 + twist_offset * 0.2, waist_y - 0.5),
			Vector2(center_x + 4.2 + twist_offset * 0.2, waist_y - 0.5),
			Vector2(center_x + 5.6 + twist_offset * 0.8, mid_chest_y),
			Vector2(center_x + 4.0 + twist_offset, chest_y),
			Vector2(center_x - 4.0 + twist_offset, chest_y),
			Vector2(center_x - 5.6 + twist_offset * 0.8, mid_chest_y)
		])
		draw_colored_polygon(back_poly, COL_ARMOR_BASE)

		# Dorsal spine ridge
		draw_line(Vector2(center_x + twist_offset * 0.5, chest_y + 1.0), Vector2(center_x + twist_offset * 0.3, waist_y - 0.5), COL_ARMOR_DARK, 1.4, false)
		# Scapular contour lines
		draw_line(Vector2(center_x - 2.5 + twist_offset * 0.6, mid_chest_y), Vector2(center_x - 4.2 + twist_offset * 0.8, chest_y + 2.0), COL_ARMOR_MID, 1.0, false)
		draw_line(Vector2(center_x + 2.5 + twist_offset * 0.6, mid_chest_y), Vector2(center_x + 4.2 + twist_offset * 0.8, chest_y + 2.0), COL_ARMOR_DARK, 1.0, false)
		# Harness leather cross straps
		draw_line(Vector2(center_x - 3.8 + twist_offset, chest_y + 1.5), Vector2(center_x + 3.6 + twist_offset * 0.2, waist_y - 0.5), COL_LEATHER, 1.2, false)
		draw_line(Vector2(center_x + 3.8 + twist_offset, chest_y + 1.5), Vector2(center_x - 3.6 + twist_offset * 0.2, waist_y - 0.5), COL_LEATHER, 1.2, false)

	# -------------------------------------------------------------
	# 4. ARTICULATED LAMINAR PAULDRONS (Shoulder cops with layered lames)
	# -------------------------------------------------------------
	var pauldron_y = chest_y + 1.5
	var p_l_center = Vector2(center_x - 5.8 + twist_offset, pauldron_y)
	var p_r_center = Vector2(center_x + 5.8 + twist_offset, pauldron_y)

	if current_dir == Dir8.SE or current_dir == Dir8.NE:
		p_l_center += Vector2(-0.4, 0.4)
		p_r_center += Vector2(-0.8, -0.6)
	elif current_dir == Dir8.SW or current_dir == Dir8.NW:
		p_r_center += Vector2(0.4, 0.4)
		p_l_center += Vector2(0.8, -0.6)

	if not is_profile:
		_draw_single_pauldron(p_l_center, true, current_dir)
		_draw_single_pauldron(p_r_center, false, current_dir)
	elif current_dir == Dir8.E:
		_draw_single_pauldron(Vector2(center_x + 3.8 + twist_offset, pauldron_y + 0.5), false, current_dir)
	elif current_dir == Dir8.W:
		_draw_single_pauldron(Vector2(center_x - 3.8 + twist_offset, pauldron_y + 0.5), true, current_dir)

func _draw_single_pauldron(pos: Vector2, is_left: bool, _dir: Dir8) -> void:
	var cop_w = 4.4
	var cop_h = 4.8
	var col_main = COL_ARMOR_MID if is_left else COL_ARMOR_BASE
	var col_rim  = COL_ARMOR_HI if is_left else COL_ARMOR_MID

	# 1. Lower articulated lame (protecting upper bicep)
	var lame_poly = PackedVector2Array([
		pos + Vector2(-cop_w * 0.7, cop_h * 0.4),
		pos + Vector2(cop_w * 0.7, cop_h * 0.4),
		pos + Vector2(cop_w * 0.55, cop_h * 0.9),
		pos + Vector2(-cop_w * 0.55, cop_h * 0.9)
	])
	draw_colored_polygon(lame_poly, COL_ARMOR_BASE)
	draw_line(pos + Vector2(-cop_w * 0.55, cop_h * 0.9), pos + Vector2(cop_w * 0.55, cop_h * 0.9), col_rim, 0.9, false)

	# 2. Main dome cop (spherical shoulder cup)
	var cop_poly = PackedVector2Array([
		pos + Vector2(-cop_w * 0.85, -cop_h * 0.3),
		pos + Vector2(0.0, -cop_h * 0.55),
		pos + Vector2(cop_w * 0.85, -cop_h * 0.3),
		pos + Vector2(cop_w, cop_h * 0.4),
		pos + Vector2(-cop_w, cop_h * 0.4)
	])
	draw_colored_polygon(cop_poly, col_main)

	# 3. Specular rim highlight on top curve
	draw_line(pos + Vector2(-cop_w * 0.85, -cop_h * 0.3), pos + Vector2(0.0, -cop_h * 0.55), col_rim, 1.2, false)
	draw_line(pos + Vector2(0.0, -cop_h * 0.55), pos + Vector2(cop_w * 0.85, -cop_h * 0.3), col_rim if is_left else COL_ARMOR_BASE, 1.0, false)

	# 4. Golden pivot rivet on shoulder crest
	draw_circle(pos + Vector2(0.0, -cop_h * 0.15), 0.7, COL_GOLD_TRIM)

# --- GREATHELM / ARMET (SLENDER CONTOUR, 3D VISOR SNOUT, SOUL-SLIT & VENT HOLES) ---
func _draw_greathelm(is_rear: bool) -> void:
	var bob = _get_vertical_bob()
	var walk_twist = sin(walk_cycle) * 0.08 * speed_ratio if (is_moving and not is_attacking) else 0.0
	var head_twist_offset = (body_twist + walk_twist) * 3.5
	var center = Vector2(body_lunge.x + head_twist_offset, -35.5 + bob + body_crouch + body_lunge.y)

	var is_profile = (current_dir == Dir8.E or current_dir == Dir8.W)

	# -------------------------------------------------------------
	# 1. GORGET & AVENTAIL (Steel collar & neck chainmail)
	# -------------------------------------------------------------
	var gorget_pts = PackedVector2Array([
		center + Vector2(-4.2, 6.0),
		center + Vector2(4.2, 6.0),
		center + Vector2(3.4, 3.2),
		center + Vector2(-3.4, 3.2)
	])
	draw_colored_polygon(gorget_pts, COL_ARMOR_DARK)
	draw_line(center + Vector2(-3.8, 5.5), center + Vector2(3.8, 5.5), COL_ARMOR_BASE, 1.0, false)

	# -------------------------------------------------------------
	# 2. SKULL DOME (Calva - Slender 8.2px width, aerodynamic egg-dome)
	# -------------------------------------------------------------
	var hw = 4.1
	var helm_pts: PackedVector2Array

	if not is_profile:
		helm_pts = PackedVector2Array([
			center + Vector2(-hw * 0.7, -7.5),
			center + Vector2(0.0, -8.5),
			center + Vector2(hw * 0.7, -7.5),
			center + Vector2(hw, -2.5),
			center + Vector2(hw * 0.9, 2.5),
			center + Vector2(0.0, 4.2),
			center + Vector2(-hw * 0.9, 2.5),
			center + Vector2(-hw, -2.5)
		])
	else:
		var p_sign = 1.0 if current_dir == Dir8.E else -1.0
		helm_pts = PackedVector2Array([
			center + Vector2(-2.5 * p_sign, -8.0),
			center + Vector2(0.5 * p_sign, -8.5),
			center + Vector2(3.2 * p_sign, -7.0),
			center + Vector2(4.8 * p_sign, -1.0),
			center + Vector2(2.8 * p_sign, 3.8),
			center + Vector2(-2.0 * p_sign, 3.2),
			center + Vector2(-3.8 * p_sign, 1.0),
			center + Vector2(-3.5 * p_sign, -3.5)
		])

	# Dome base shading (Left lit, Right shadowed)
	draw_colored_polygon(helm_pts, COL_ARMOR_MID)
	if not is_profile:
		var shadow_facet = PackedVector2Array([
			center + Vector2(0.0, -8.5),
			center + Vector2(hw * 0.7, -7.5),
			center + Vector2(hw, -2.5),
			center + Vector2(hw * 0.9, 2.5),
			center + Vector2(0.0, 4.2)
		])
		draw_colored_polygon(shadow_facet, COL_ARMOR_BASE)

	# Central Gothic Sagittal Crest / Keel along crown
	if not is_profile:
		draw_line(center + Vector2(0.0, -8.5), center + Vector2(0.0, -1.5), COL_ARMOR_HI, 1.2, false)
	else:
		var p_sign = 1.0 if current_dir == Dir8.E else -1.0
		draw_line(center + Vector2(-2.5 * p_sign, -8.0), center + Vector2(0.5 * p_sign, -8.5), COL_ARMOR_HI, 1.2, false)
		draw_line(center + Vector2(0.5 * p_sign, -8.5), center + Vector2(3.2 * p_sign, -7.0), COL_ARMOR_HI, 1.2, false)

	# -------------------------------------------------------------
	# 3. REAR VIEW vs FRONT/PROFILE VISOR
	# -------------------------------------------------------------
	if is_rear:
		var nape_pts = PackedVector2Array([
			center + Vector2(-hw * 0.85, 0.5),
			center + Vector2(hw * 0.85, 0.5),
			center + Vector2(hw * 0.75, 4.5),
			center + Vector2(-hw * 0.75, 4.5)
		])
		draw_colored_polygon(nape_pts, COL_ARMOR_DARK)
		draw_line(center + Vector2(-hw * 0.8, 2.5), center + Vector2(hw * 0.8, 2.5), COL_ARMOR_BASE, 1.0, false)
		draw_circle(center + Vector2(-2.2, 3.8), 0.6, COL_GOLD_TRIM)
		draw_circle(center + Vector2(0.0, 3.8), 0.6, COL_GOLD_TRIM)
		draw_circle(center + Vector2(2.2, 3.8), 0.6, COL_GOLD_TRIM)
	else:
		var slit_x = 0.0
		var slit_w = 5.2
		var slit_y = center.y - 0.8

		match current_dir:
			Dir8.S:
				slit_x = 0.0
				slit_w = 5.2
			Dir8.SE:
				slit_x = 1.5
				slit_w = 4.2
			Dir8.SW:
				slit_x = -1.5
				slit_w = 4.2
			Dir8.E:
				slit_x = 2.8
				slit_w = 2.8
			Dir8.W:
				slit_x = -2.8
				slit_w = 2.8

		# Recessed Dark Eye Slit
		var v1 = Vector2(center.x + slit_x - slit_w * 0.5, slit_y)
		var v2 = Vector2(center.x + slit_x + slit_w * 0.5, slit_y)
		draw_line(v1 - Vector2(0.8, 0), v2 + Vector2(0.8, 0), COL_ARMOR_DARK, 2.6, false)

		# Soul-Slit Incandescent Glow (cyan HDR)
		var glow_col = COL_VISOR_GLOW if not is_attacking else Color(0.4, 1.1, 1.4, 1.0)
		draw_line(v1, v2, glow_col, 1.8, false)
		draw_line(v1 + Vector2(0.4, 0), v2 - Vector2(0.4, 0), COL_VISOR_CORE, 1.0, false)

		# Brow ridge above visor
		draw_line(v1 - Vector2(1.0, 1.2), v2 + Vector2(1.0, 1.2), COL_ARMOR_HI, 1.0, false)

		# Ventilation Grille Breath Holes
		if not is_profile:
			var vent_y1 = center.y + 1.6
			var vent_y2 = center.y + 2.8
			var vx = center.x + slit_x * 0.6
			draw_circle(Vector2(vx - 1.6, vent_y1), 0.5, COL_ARMOR_DARK)
			draw_circle(Vector2(vx - 1.6, vent_y2), 0.5, COL_ARMOR_DARK)
			draw_circle(Vector2(vx + 1.6, vent_y1), 0.5, COL_ARMOR_DARK)
			draw_circle(Vector2(vx + 1.6, vent_y2), 0.5, COL_ARMOR_DARK)
		else:
			var p_sign = 1.0 if current_dir == Dir8.E else -1.0
			draw_circle(center + Vector2(2.5 * p_sign, 1.4), 0.5, COL_ARMOR_DARK)
			draw_circle(center + Vector2(2.5 * p_sign, 2.5), 0.5, COL_ARMOR_DARK)
			draw_circle(center + Vector2(3.5 * p_sign, 0.5), 0.5, COL_ARMOR_DARK)

		# Visor Pivot Bolt
		if not is_profile:
			draw_circle(center + Vector2(-3.4, -0.8), 0.7, COL_GOLD_TRIM)
			draw_circle(center + Vector2(3.4, -0.8), 0.7, COL_GOLD_TRIM)
		else:
			var p_sign = 1.0 if current_dir == Dir8.E else -1.0
			draw_circle(center + Vector2(-0.8 * p_sign, -1.0), 0.8, COL_GOLD_TRIM)

# --- 8-DIRECTIONALLY ADAPTED WEAPONS & SOLID FILLED WIND CLEAVE ---
func _compute_equipment_transforms() -> void:
	var bob = _get_vertical_bob()
	var body_pos = body_lunge + Vector2(0.0, bob + body_crouch)
	var chest_pos = Vector2(0.0, -22.0) + body_pos

	var f_ang = _get_forward_sword_angle(current_dir)
	var f_dir = Vector2(sin(f_ang), -cos(f_ang) * 0.70).normalized()

	# Defaults
	var base_shield_pos = Vector2(-8.5, 0.0)
	var base_sword_pos  = Vector2(8.5, 1.0)
	var base_shield_ang = -0.15
	var base_sword_ang  = 0.55
	shield_scale_x = 1.0
	shield_is_facing_away = false
	blade_len = 25.0
	has_trail = false
	has_parry_arc = false

	# Configure per-direction perspective, hand placements, and depth sorting:
	match current_dir:
		Dir8.S: # South (Direct Front)
			base_shield_pos = Vector2(-8.5, 0.0)
			base_sword_pos  = Vector2(8.5, 1.0)
			base_shield_ang = -0.15
			base_sword_ang  = 0.55
			shield_scale_x = 1.0
			shield_is_facing_away = false
			shield_in_front = true
			sword_in_front = true
			trail_in_front = true

		Dir8.SE: # South-East (3/4 Front-Right)
			base_shield_pos = Vector2(-4.8, 1.0)
			base_sword_pos  = Vector2(11.0, 2.5)
			base_shield_ang = 0.15
			base_sword_ang  = 0.85
			shield_scale_x = 0.85
			shield_is_facing_away = false
			shield_in_front = true
			sword_in_front = true
			trail_in_front = true

		Dir8.E: # East (Right Profile)
			base_shield_pos = Vector2(-1.0, -3.0) # Far side of torso
			base_sword_pos  = Vector2(11.0, 3.5)  # Near side of torso
			base_shield_ang = 0.35
			base_sword_ang  = 1.10
			shield_scale_x = 0.55 # Side foreshortening
			shield_is_facing_away = false
			shield_in_front = false # Behind torso!
			sword_in_front = true   # In front of torso!
			trail_in_front = true

		Dir8.NE: # North-East (3/4 Back-Right)
			base_shield_pos = Vector2(5.5, -4.0)
			base_sword_pos  = Vector2(10.5, -2.0)
			base_shield_ang = 0.30
			base_sword_ang  = 0.45
			shield_scale_x = 0.80
			shield_is_facing_away = true # Inside straps visible
			shield_in_front = false # Behind torso & head!
			sword_in_front = false  # Behind torso & head!
			trail_in_front = false  # Behind torso & head!

		Dir8.N: # North (Rear View)
			base_shield_pos = Vector2(8.5, -4.0)
			base_sword_pos  = Vector2(-8.5, -4.0)
			base_shield_ang = 0.15
			base_sword_ang  = -0.45
			shield_scale_x = 1.0
			shield_is_facing_away = true # Interior straps visible, no front cross!
			shield_in_front = false # Strictly underneath/behind body & head!
			sword_in_front = false  # Strictly underneath/behind body & head!
			trail_in_front = false  # Strictly underneath/behind body & head!

		Dir8.NW: # North-West (3/4 Back-Left)
			base_shield_pos = Vector2(-5.5, -4.0)
			base_sword_pos  = Vector2(-10.5, -2.0)
			base_shield_ang = -0.30
			base_sword_ang  = -0.45
			shield_scale_x = 0.80
			shield_is_facing_away = true # Interior straps
			shield_in_front = false # Behind body!
			sword_in_front = false  # Behind body!
			trail_in_front = false  # Behind body!

		Dir8.W: # West (Left Profile)
			base_shield_pos = Vector2(-11.0, 3.5) # Near side
			base_sword_pos  = Vector2(1.0, -3.0)   # Far side
			base_shield_ang = -0.35
			base_sword_ang  = -1.10
			shield_scale_x = 0.55 # Side foreshortening
			shield_is_facing_away = false
			shield_in_front = true  # Shield in front of torso!
			sword_in_front = false # Sword behind torso!
			trail_in_front = false # Trail behind torso!

		Dir8.SW: # South-West (3/4 Front-Left)
			base_shield_pos = Vector2(-8.0, 2.0)
			base_sword_pos  = Vector2(-11.0, 1.0)
			base_shield_ang = -0.20
			base_sword_ang  = -0.85
			shield_scale_x = 0.85
			shield_is_facing_away = false
			shield_in_front = true
			sword_in_front = true
			trail_in_front = true

	shield_pos = chest_pos + base_shield_pos
	sword_pos  = chest_pos + base_sword_pos
	shield_ang = base_shield_ang
	sword_ang  = base_sword_ang

	# 2. GUARD MODIFIERS
	if guard_blend > 0.01:
		var target_shield_pos = chest_pos + f_dir * 12.0
		var target_shield_ang = f_ang - PI * 0.5
		shield_pos = shield_pos.lerp(target_shield_pos, guard_blend)
		shield_ang = lerp_angle(shield_ang, target_shield_ang, guard_blend)

		var target_sword_pos = chest_pos - f_dir * 3.0 + Vector2(-f_dir.y, f_dir.x * 0.70).normalized() * 7.0
		var target_sword_ang = f_ang - 0.35
		sword_pos = sword_pos.lerp(target_sword_pos, guard_blend)
		sword_ang = lerp_angle(sword_ang, target_sword_ang, guard_blend)

	# 3. PARRY MODIFIERS (AUTHENTIC MARTIAL DEFLECTIVE CRESCENT SWEEP ARC & RIPOSTE CHAMBER)
	if is_parrying or parry_blend > 0.01:
		var f_perp = Vector2(-f_dir.y, f_dir.x * 0.70).normalized()

		var rest_shield_pos = chest_pos + base_shield_pos
		var rest_shield_ang = base_shield_ang
		var rest_sword_pos  = chest_pos + base_sword_pos
		var rest_sword_ang  = base_sword_ang

		# Authentic HEMA Parry targets:
		# Coiled stance: shield pulls inward to center chest
		var coil_shield_pos = rest_shield_pos - (f_dir * 2.0) - (f_perp * 2.5) + Vector2(0.0, 1.2)
		var coil_shield_ang = base_shield_ang - 0.12

		# Deflection apex: shield sweeps outward across opponent's weapon trajectory
		var apex_shield_pos = chest_pos + (f_dir * 18.5) + (f_perp * 6.5) + Vector2(0.0, -2.5)
		var apex_shield_ang = f_ang - PI * 0.5 + 0.32

		# Broadsword Vom Tag High-Chamber (riposte counter-stance)
		var chamber_sword_pos = chest_pos - (f_dir * 4.0) - (f_perp * 7.0) + Vector2(0.0, -5.0)
		var chamber_sword_ang = f_ang - 0.22

		var cur_target_shield_pos = rest_shield_pos
		var cur_target_shield_ang = rest_shield_ang
		var cur_scale_x = 1.0
		var cur_target_sword_pos = rest_sword_pos
		var cur_target_sword_ang = rest_sword_ang

		if is_parrying:
			var t = parry_progress
			if t < 0.18: # Phase 1: Rapid Inward Coil (Windup)
				var p = t / 0.18
				var s = sin(p * PI * 0.5)
				cur_target_shield_pos = rest_shield_pos.lerp(coil_shield_pos, s)
				cur_target_shield_ang = lerp_angle(rest_shield_ang, coil_shield_ang, s)
				cur_scale_x = lerpf(1.0, 0.96, s)
				cur_target_sword_pos = rest_sword_pos.lerp(chamber_sword_pos, s * 0.45)
				cur_target_sword_ang = lerp_angle(rest_sword_ang, chamber_sword_ang, s * 0.45)
			elif t < 0.60: # Phase 2: Explosive Outward Deflective Crescent Sweep
				var p = (t - 0.18) / 0.42
				var s = 1.0 - pow(1.0 - p, 2.6)

				# Dynamic crescent arc bulge (sweeping outward & scooping upward)
				var arc_bulge = (f_perp * 4.5 + Vector2(0.0, -3.8)) * sin(p * PI)
				cur_target_shield_pos = coil_shield_pos.lerp(apex_shield_pos, s) + arc_bulge
				cur_target_shield_ang = lerp_angle(coil_shield_ang, apex_shield_ang, s)
				cur_scale_x = 1.0 + sin(p * PI) * 0.22
				cur_target_sword_pos = chamber_sword_pos
				cur_target_sword_ang = chamber_sword_ang

				# Golden Deflection Crescent Arc
				has_parry_arc = true
				parry_arc_center = chest_pos
				var s_vec = cur_target_shield_pos - chest_pos
				var c_vec = coil_shield_pos - chest_pos
				var head_a = atan2(s_vec.x, -s_vec.y / 0.70)
				var coil_a = atan2(c_vec.x, -c_vec.y / 0.70)
				var a_diff = wrapf(head_a - coil_a, -PI, PI)

				parry_arc_radius = s_vec.length() + 2.5
				parry_arc_start_ang = head_a
				parry_arc_sweep_dir = 1.0 if a_diff >= 0.0 else -1.0
				parry_arc_span = minf(absf(a_diff) * minf(p * 2.8, 1.0) + deg_to_rad(25.0), deg_to_rad(85.0))
				parry_arc_alpha = sin(p * PI) * 0.95
			elif t < 0.76: # Phase 3: Braced Impact Apex (Solid deflection lock)
				cur_target_shield_pos = apex_shield_pos
				cur_target_shield_ang = apex_shield_ang
				cur_scale_x = 1.15
				cur_target_sword_pos = chamber_sword_pos
				cur_target_sword_ang = chamber_sword_ang
			else: # Phase 4: Fluid Hermite Recovery (Smooth C1 continuity back to combat stance)
				var p = (t - 0.76) / 0.24
				var r = p * p * (3.0 - 2.0 * p)
				cur_target_shield_pos = apex_shield_pos.lerp(rest_shield_pos, r)
				cur_target_shield_ang = lerp_angle(apex_shield_ang, rest_shield_ang, r)
				cur_scale_x = lerpf(1.15, 1.0, r)
				cur_target_sword_pos = chamber_sword_pos.lerp(rest_sword_pos, r)
				cur_target_sword_ang = lerp_angle(chamber_sword_ang, rest_sword_ang, r)

		# Smooth blending into equipment positions
		var p_blend = parry_blend
		shield_pos = shield_pos.lerp(cur_target_shield_pos, p_blend)
		shield_ang = lerp_angle(shield_ang, cur_target_shield_ang, p_blend)
		shield_scale_x *= lerpf(1.0, cur_scale_x, p_blend)

		sword_pos = sword_pos.lerp(cur_target_sword_pos, p_blend)
		sword_ang = lerp_angle(sword_ang, cur_target_sword_ang, p_blend)

	# 4. ATTACK TRAJECTORY & SOLID FILLED BLADE WIND TRAIL
	if is_attacking:
		var t = attack_progress

		# Shield tucks back during attack
		var tuck_dir = -f_dir * 4.0 - Vector2(-f_dir.y, f_dir.x * 0.70).normalized() * 8.0
		shield_pos = chest_pos + tuck_dir
		shield_ang = f_ang - PI * 0.5 - 0.25

		match attack_combo:
			0: # COMBO 0: FOREHAND HORIZONTAL CLEAVE
				var arc_start = f_ang - deg_to_rad(65.0)
				var arc_end   = f_ang + deg_to_rad(70.0)
				blade_len = 26.0

				if t < 0.22: # Windup coil
					var p = t / 0.22
					sword_ang = lerp_angle(base_sword_ang, arc_start, p)
					var s_dir = Vector2(sin(sword_ang), -cos(sword_ang) * 0.70).normalized()
					sword_pos = chest_pos + s_dir * 12.0
				elif t < 0.62: # Active forehand slash
					var p = (t - 0.22) / 0.40
					var s = 1.0 - pow(1.0 - p, 2.6)
					sword_ang = lerp_angle(arc_start, arc_end, s)
					var s_dir = Vector2(sin(sword_ang), -cos(sword_ang) * 0.70).normalized()
					sword_pos = chest_pos + s_dir * 13.0

					has_trail = true
					trail_center = chest_pos
					trail_blade_ang = sword_ang
					trail_sweep_dir = 1.0
					trail_span = deg_to_rad(75.0) * minf(p * 2.6, 1.0) * (1.0 - p * 0.35)
					trail_r_hilt = 13.0
					trail_r_tip = 13.0 + blade_len
					trail_is_finisher = false
				else: # Recovery
					var p = (t - 0.62) / 0.38
					var r = p * p
					sword_ang = lerp_angle(arc_end, base_sword_ang, r)
					var s_dir = Vector2(sin(sword_ang), -cos(sword_ang) * 0.70).normalized()
					sword_pos = chest_pos + s_dir * lerpf(13.0, 11.0, r)

			1: # COMBO 1: RISING BACKHAND SLASH
				var arc_start = f_ang + deg_to_rad(60.0)
				var arc_end   = f_ang - deg_to_rad(65.0)
				blade_len = 26.0

				if t < 0.20: # Windup coil low
					var p = t / 0.20
					sword_ang = lerp_angle(base_sword_ang, arc_start, p)
					var s_dir = Vector2(sin(sword_ang), -cos(sword_ang) * 0.70).normalized()
					sword_pos = chest_pos + s_dir * 12.0 + Vector2(0.0, 3.0 * p)
				elif t < 0.58: # Active rising cut
					var p = (t - 0.20) / 0.38
					var s = 1.0 - pow(1.0 - p, 2.5)
					sword_ang = lerp_angle(arc_start, arc_end, s)
					var s_dir = Vector2(sin(sword_ang), -cos(sword_ang) * 0.70).normalized()
					var lift_y = lerpf(3.0, -5.0, s)
					sword_pos = chest_pos + s_dir * 13.0 + Vector2(0.0, lift_y)

					has_trail = true
					trail_center = chest_pos
					trail_blade_ang = sword_ang
					trail_sweep_dir = -1.0
					trail_span = deg_to_rad(70.0) * minf(p * 2.6, 1.0) * (1.0 - p * 0.35)
					trail_r_hilt = 13.0
					trail_r_tip = 13.0 + blade_len
					trail_is_finisher = false
				else: # Recovery
					var p = (t - 0.58) / 0.42
					var r = p * p
					sword_ang = lerp_angle(arc_end, base_sword_ang, r)
					var s_dir = Vector2(sin(sword_ang), -cos(sword_ang) * 0.70).normalized()
					sword_pos = chest_pos + s_dir * lerpf(13.0, 11.0, r)

			2: # COMBO 2: 360° WHIRLWIND SWEEPING CLEAVE (ĐÒN SWIPE 360° BÃO LỐC CỰC ĐẠI)
				var f_base_ang = _get_forward_sword_angle(base_attack_dir)
				var sweep_start = f_base_ang - deg_to_rad(120.0)
				var total_sweep = deg_to_rad(420.0)
				blade_len = 34.0 # Extended two-handed greatsword reach!

				if t < 0.18: # Deep coiled windup
					var p = t / 0.18
					sword_ang = lerp_angle(base_sword_ang, sweep_start, p)
					var s_dir = Vector2(sin(sword_ang), -cos(sword_ang) * 0.70).normalized()
					sword_pos = chest_pos + s_dir * 11.0
					sword_in_front = (s_dir.y >= -0.15)
				elif t < 0.70: # 360° Cyclone Cleave!
					var p = (t - 0.18) / 0.52
					var s = 1.0 - pow(1.0 - p, 2.4)
					sword_ang = sweep_start + s * total_sweep
					var s_dir = Vector2(sin(sword_ang), -cos(sword_ang) * 0.70).normalized()
					sword_pos = chest_pos + s_dir * 15.0
					sword_in_front = (s_dir.y >= -0.15)

					has_trail = true
					trail_center = chest_pos
					trail_blade_ang = sword_ang
					trail_sweep_dir = 1.0
					var span_curve = sin(p * PI)
					trail_span = deg_to_rad(330.0) * minf(p * 2.5, 1.0) * (0.4 + span_curve * 0.6)
					trail_r_hilt = 12.0
					trail_r_tip = 15.0 + blade_len # 49.0px radius
					trail_is_finisher = true
				else: # Recovery
					var p = (t - 0.70) / 0.30
					var r = p * p
					var sweep_end = sweep_start + total_sweep
					sword_ang = lerp_angle(sweep_end, base_sword_ang, r)
					var s_dir = Vector2(sin(sword_ang), -cos(sword_ang) * 0.70).normalized()
					sword_pos = chest_pos + s_dir * lerpf(15.0, 11.0, r)
					sword_in_front = (s_dir.y >= -0.15)

# --- SOLID FILLED BLADE WIND TRAIL SYSTEM (ĐƯỜNG CONG GIÓ ĐẶC, 100% OPAQUE) ---
func _draw_blade_wind_trail(
	center: Vector2,
	blade_ang: float,
	sweep_dir: float,
	trail_span: float,
	r_hilt: float,
	r_tip: float,
	is_finisher: bool = false,
	layer_mode: int = 0
) -> void:
	if trail_span < 0.04:
		return

	var num_segs = 32 if is_finisher else 16
	var col_shade = Color(0.18, 0.28, 0.46, 1.0) if is_finisher else Color(0.20, 0.32, 0.48, 1.0)
	var col_body = Color(0.88, 0.96, 1.0, 1.0) if is_finisher else Color(0.92, 0.96, 1.0, 1.0)

	var pts_out: Array[Vector2] = []
	var pts_mid: Array[Vector2] = []
	var pts_in: Array[Vector2] = []
	var pts_shock: Array[Vector2] = []
	var dirs_y: Array[float] = []

	for i in range(num_segs + 1):
		var frac = float(i) / float(num_segs) # 0.0 at tail, 1.0 at blade
		var a = blade_ang - sweep_dir * trail_span * (1.0 - frac)

		var ro = r_tip
		var ri = lerpf(ro - 2.0, r_hilt, sin(frac * (PI * 0.5)))
		var rm = lerpf(ro - 1.2, (ro + ri) * 0.52, sin(frac * (PI * 0.5)))

		var dir_a = Vector2(sin(a), -cos(a) * 0.70).normalized()
		pts_out.append(center + dir_a * ro)
		pts_in.append(center + dir_a * ri)
		pts_mid.append(center + dir_a * rm)
		dirs_y.append(dir_a.y)

		if is_finisher:
			var r_shock = r_tip + 6.0 * sin(frac * PI)
			pts_shock.append(center + dir_a * r_shock)

	for i in range(num_segs):
		var mid_y = (dirs_y[i] + dirs_y[i + 1]) * 0.5
		# layer_mode: 0 = all, 1 = background only (mid_y < 0), 2 = foreground only (mid_y >= 0)
		if layer_mode == 1 and mid_y >= 0.0:
			continue
		if layer_mode == 2 and mid_y < 0.0:
			continue

		var p_out0 = pts_out[i]
		var p_out1 = pts_out[i + 1]
		var p_mid0 = pts_mid[i]
		var p_mid1 = pts_mid[i + 1]
		var p_in0 = pts_in[i]
		var p_in1 = pts_in[i + 1]

		# 1. Inner solid shade band
		draw_colored_polygon(PackedVector2Array([p_mid0, p_mid1, p_in1, p_in0]), col_shade)
		# 2. Main solid luminous body
		draw_colored_polygon(PackedVector2Array([p_out0, p_out1, p_mid1, p_mid0]), col_body)

		# 3. Razor cutting crest
		draw_line(p_out0, p_out1, Color(1.0, 1.0, 1.0, 1.0), 2.2, false)
		# 4. Crisp internal velocity streak
		draw_line(p_mid0, p_mid1, Color(1.0, 1.0, 1.0, 1.0), 1.2, false)
		# 5. Inner contour boundary
		draw_line(p_in0, p_in1, Color(0.12, 0.18, 0.28, 1.0), 1.0, false)

		# 6. Finisher outer shockwave arc
		if is_finisher:
			draw_line(pts_shock[i], pts_shock[i + 1], Color(1.2, 1.4, 2.0, 0.95), 1.8, false)

# --- HEATER SHIELD (WITH PERSPECTIVE AND INTERIOR/EXTERIOR DETAIL) ---
func _draw_heater_shield(pos: Vector2, angle: float, scale_x: float = 1.0, is_facing_away: bool = false) -> void:
	var s_scale = 1.0 + (guard_blend * 0.16) + (parry_blend * 0.22)
	
	var base_pts = [
		Vector2(-6.0 * scale_x, -9.0),
		Vector2(6.0 * scale_x, -9.0),
		Vector2(6.5 * scale_x, 0.0),
		Vector2(4.0 * scale_x, 6.5),
		Vector2(0.0, 11.0),
		Vector2(-4.0 * scale_x, 6.5),
		Vector2(-6.5 * scale_x, 0.0)
	]

	var rim_pts = PackedVector2Array()
	var inner_pts = PackedVector2Array()
	for p in base_pts:
		var sp = p * s_scale
		rim_pts.append(pos + sp.rotated(angle))
		inner_pts.append(pos + (sp * 0.80).rotated(angle))

	# Dark steel rim
	draw_colored_polygon(rim_pts, COL_ARMOR_BASE)

	if is_facing_away:
		# Interior of the shield: dark wood/iron backing and leather forearm straps
		draw_colored_polygon(inner_pts, COL_ARMOR_DARK)
		var s_dir = Vector2(0.0, 1.0).rotated(angle)
		var s_perp = Vector2(-s_dir.y, s_dir.x)
		var strap1 = pos + s_dir * (-2.0 * s_scale)
		var strap2 = pos + s_dir * (3.0 * s_scale)
		draw_line(strap1 - s_perp * 3.5 * scale_x, strap1 + s_perp * 3.5 * scale_x, COL_LEATHER, 2.0 * s_scale, false)
		draw_line(strap2 - s_perp * 3.0 * scale_x, strap2 + s_perp * 3.0 * scale_x, COL_LEATHER, 2.0 * s_scale, false)
		draw_circle(strap1, 1.0, COL_ARMOR_HI)
	else:
		# Exterior heraldic shield face
		draw_colored_polygon(inner_pts, COL_SHIELD_BG)

		# Golden Chivalric Cross Emblem
		var cv1 = pos + (Vector2(0.0, -6.0) * s_scale).rotated(angle)
		var cv2 = pos + (Vector2(0.0, 7.0) * s_scale).rotated(angle)
		var ch1 = pos + (Vector2(-4.5 * scale_x, -2.5) * s_scale).rotated(angle)
		var ch2 = pos + (Vector2(4.5 * scale_x, -2.5) * s_scale).rotated(angle)

		draw_line(cv1, cv2, COL_GOLD_TRIM, 2.0 * s_scale, false)
		draw_line(ch1, ch2, COL_GOLD_TRIM, 2.0 * s_scale, false)
		draw_line(cv1, cv2, COL_GOLD_SHINE, 1.0 * s_scale, false)


# --- GOLDEN DEFLECTION CRESCENT ARC (MARTIAL DEFLECTIVE PARRY TRAIL) ---
func _draw_parry_crescent_arc(
	center: Vector2,
	radius: float,
	head_ang: float,
	sweep_dir: float,
	span: float,
	alpha: float
) -> void:
	if alpha <= 0.01 or span <= 0.01:
		return

	var num_segs = 16
	var pts_outer: Array[Vector2] = []
	var pts_inner: Array[Vector2] = []
	var pts_core: Array[Vector2] = []

	var col_glow = Color(1.8, 1.5, 0.5, alpha * 0.95)
	var col_gold = Color(1.3, 0.95, 0.35, alpha * 0.85)
	var col_amber = Color(0.85, 0.50, 0.15, alpha * 0.55)
	var col_edge = Color(2.2, 2.1, 1.6, alpha)

	for i in range(num_segs + 1):
		var frac = float(i) / float(num_segs) # 0.0 at tail, 1.0 at shield head
		var a = head_ang - sweep_dir * span * (1.0 - frac)

		# Aerodynamic crescent profile: tapered at tail, thickest at 65% chord, sharp at head
		var chord = sin(frac * PI)
		var thickness = 5.2 * chord

		var r_out = radius + thickness * 0.55
		var r_in  = radius - thickness * 0.45
		var r_mid = radius + thickness * 0.10

		var dir_out = Vector2(sin(a), -cos(a) * 0.70).normalized()
		pts_outer.append(center + dir_out * r_out)
		pts_inner.append(center + dir_out * r_in)
		pts_core.append(center + dir_out * r_mid)

	for i in range(num_segs):
		var p_out0 = pts_outer[i]
		var p_out1 = pts_outer[i + 1]
		var p_mid0 = pts_core[i]
		var p_mid1 = pts_core[i + 1]
		var p_in0 = pts_inner[i]
		var p_in1 = pts_inner[i + 1]

		# 1. Inner amber velocity band
		draw_colored_polygon(PackedVector2Array([p_mid0, p_mid1, p_in1, p_in0]), col_amber)
		# 2. Main golden deflecting blade body
		draw_colored_polygon(PackedVector2Array([p_out0, p_out1, p_mid1, p_mid0]), col_gold)
		# 3. Incandescent razor cutting edge
		draw_line(p_out0, p_out1, col_edge, 1.6, false)
		# 4. Luminous golden core streak
		draw_line(p_mid0, p_mid1, col_glow, 1.0, false)


# --- BROADSWORD (CRUCIFORM KNIGHTLY BLADE) ---
func _draw_broadsword(pos: Vector2, angle: float, blade_len: float = 25.0) -> void:
	var guard_w = 5.5

	var dir = Vector2(sin(angle), -cos(angle) * 0.70).normalized()
	var perp = Vector2(-dir.y, dir.x).normalized()

	var hilt = pos
	var pommel = hilt - (dir * 4.5)
	var guard  = hilt + (dir * 1.5)
	var tip    = guard + (dir * blade_len)

	draw_line(pommel, guard, COL_LEATHER, 1.8, false)
	draw_rect(Rect2(pommel - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), COL_GOLD_TRIM)

	var q1 = guard - (perp * guard_w)
	var q2 = guard + (perp * guard_w)
	draw_line(q1, q2, COL_ARMOR_HI, 2.0, false)

	var b_l = guard - (perp * 2.0)
	var b_r = guard + (perp * 2.0)
	var tip_l = guard + (dir * (blade_len - 3.0)) - (perp * 1.8)
	var tip_r = guard + (dir * (blade_len - 3.0)) + (perp * 1.8)

	var blade_pts = PackedVector2Array([b_l, tip_l, tip, tip_r, b_r])
	draw_colored_polygon(blade_pts, COL_STEEL_BLADE)
	draw_line(guard + (dir * 2.0), guard + (dir * (blade_len - 5.0)), COL_ARMOR_DARK, 1.0, false)
	draw_line(b_l, tip, COL_STEEL_EDGE, 1.0, false)

	# Articulated Armored Gauntlet gripping the sword hilt
	draw_circle(hilt, 2.0, COL_ARMOR_BASE)
	draw_circle(hilt, 1.3, COL_ARMOR_MID)
	draw_line(hilt - (perp * 1.5), hilt + (perp * 1.5), COL_ARMOR_HI, 1.0, false)

func _get_forward_sword_angle(dir: Dir8) -> float:
	match dir:
		Dir8.N:  return 0.0
		Dir8.NE: return deg_to_rad(45.0)
		Dir8.E:  return deg_to_rad(90.0)
		Dir8.SE: return deg_to_rad(135.0)
		Dir8.S:  return deg_to_rad(180.0)
		Dir8.SW: return deg_to_rad(225.0)
		Dir8.W:  return deg_to_rad(270.0)
		Dir8.NW: return deg_to_rad(315.0)
		_:       return deg_to_rad(180.0)

func _get_dir_angle(dir: Dir8) -> float:
	match dir:
		Dir8.E:  return 0.0
		Dir8.SE: return deg_to_rad(30.0)
		Dir8.S:  return deg_to_rad(90.0)
		Dir8.SW: return deg_to_rad(150.0)
		Dir8.W:  return deg_to_rad(180.0)
		Dir8.NW: return deg_to_rad(210.0)
		Dir8.N:  return deg_to_rad(270.0)
		Dir8.NE: return deg_to_rad(330.0)
		_:       return deg_to_rad(90.0)

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
