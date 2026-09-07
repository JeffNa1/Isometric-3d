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
	att_duration: float = 0.35
) -> void:
	current_dir = dir as Dir8
	is_moving = moving
	speed_ratio = speed_rat
	is_guarding = guarding
	is_parrying = parrying
	is_attacking = attacking
	attack_combo = combo
	attack_timer = att_timer
	current_attack_duration = maxf(att_duration, 0.01)

	# Update idle and walk frequencies
	idle_timer += delta * 2.2
	if idle_timer > TAU * 10.0:
		idle_timer = 0.0

	var walk_freq = 9.0 + (speed_ratio * 5.0)
	if is_moving and not is_attacking:
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

	# COMPUTE FULL-BODY KINETIC ATTACK TRAJECTORY (ADAPTED TO 8 DIRECTIONS)
	if is_attacking:
		attack_progress = clampf(1.0 - (attack_timer / current_attack_duration), 0.0, 1.0)
		_compute_attack_kinetics(attack_progress, attack_combo)
	else:
		attack_progress = 0.0
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

		2: # WIDE-AREA SWEEPING CLEAVE (MASSIVE 260° WHIRLWIND SWIPE)
			if t < 0.22: # Deep Coiled Windup
				var p = t / 0.22
				body_twist = lerpf(0.0, 0.60, p)
				body_crouch = lerpf(0.0, 2.8, p)
				body_lunge = -aim_dir * lerpf(0.0, 3.5, p)
				cape_whip = -aim_dir * lerpf(0.0, 6.0, p)
			elif t < 0.65: # TITANIC ROTATIONAL CLEAVE (260° SWIPE)
				var p = (t - 0.22) / 0.43
				var s = 1.0 - pow(1.0 - p, 2.8)
				body_twist = lerpf(0.60, -0.85, s)
				body_crouch = lerpf(2.8, 0.5, s)
				body_lunge = aim_dir * lerpf(-3.5, 13.0, s)
				cape_whip = -aim_dir * lerpf(-6.0, 15.0, s)
			else: # Follow-through & Grounded Recovery
				var p = (t - 0.65) / 0.35
				var r = p * p
				body_twist = lerpf(-0.85, 0.0, r)
				body_crouch = lerpf(0.5, 0.0, r)
				body_lunge = aim_dir * lerpf(13.0, 0.0, r)
				cape_whip = cape_whip.lerp(Vector2.ZERO, r)

func _draw() -> void:
	# 1. DUAL GROUND CONTACT SHADOW (Expands with lunge, feet anchored at y=0)
	_draw_contact_shadow()

	# Compute all 8-directional weapon transforms & depth-sorting layers
	_compute_equipment_transforms()

	var is_rear = (current_dir == Dir8.N or current_dir == Dir8.NE or current_dir == Dir8.NW)

	# 2. BACKGROUND WEAPONS & TRAIL (BEHIND BODY)
	# When looking North / NE / NW, sword, shield, and slash trail are strictly drawn here (UNDERNEATH the body)!
	if has_trail and not trail_in_front:
		_draw_blade_wind_trail(trail_center, trail_blade_ang, trail_sweep_dir, trail_span, trail_r_hilt, trail_r_tip, trail_is_finisher)
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
	if has_trail and trail_in_front:
		_draw_blade_wind_trail(trail_center, trail_blade_ang, trail_sweep_dir, trail_span, trail_r_hilt, trail_r_tip, trail_is_finisher)
	if shield_in_front:
		_draw_heater_shield(shield_pos, shield_ang, shield_scale_x, shield_is_facing_away)
	if sword_in_front:
		_draw_broadsword(sword_pos, sword_ang, blade_len)

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

# --- CAPE (CLOTH & MOMENTUM SIMULATION) ---
func _draw_cape() -> void:
	var anchor_y = -31.0 + body_crouch + body_lunge.y
	var anchor_l = Vector2(-7.0 + body_lunge.x, anchor_y)
	var anchor_r = Vector2(7.0 + body_lunge.x, anchor_y)

	var trail = Vector2.ZERO
	match current_dir:
		Dir8.E:  trail = Vector2(-12.0, -3.0)
		Dir8.SE: trail = Vector2(-8.0, -4.0)
		Dir8.S:  trail = Vector2(0.0, -5.0)
		Dir8.SW: trail = Vector2(8.0, -4.0)
		Dir8.W:  trail = Vector2(12.0, -3.0)
		Dir8.NW: trail = Vector2(6.0, 2.0)
		Dir8.N:  trail = Vector2(0.0, 3.0)
		Dir8.NE: trail = Vector2(-6.0, 2.0)

	trail += cape_whip

	var billow = speed_ratio * 8.0 + (body_lunge.length() * 0.8)
	var wave1 = sin(cape_phase) * (2.5 + billow * 0.4)
	var wave2 = cos(cape_phase * 1.3) * (2.0 + billow * 0.3)

	var hem_y = -9.0 + body_crouch + body_lunge.y
	var bottom_left = Vector2(-10.0 + trail.x - wave1, hem_y + trail.y)
	var bottom_mid  = Vector2(trail.x + wave2, hem_y + trail.y + 2.0)
	var bottom_right= Vector2(10.0 + trail.x + wave1, hem_y + trail.y)

	var cape_poly = PackedVector2Array([anchor_l, anchor_r, bottom_right, bottom_mid, bottom_left])
	draw_colored_polygon(cape_poly, COL_CAPE_DARK)

	var fold_poly = PackedVector2Array([
		Vector2(-2.0 + body_lunge.x, anchor_y + 1.0),
		Vector2(2.0 + body_lunge.x, anchor_y + 1.0),
		Vector2(bottom_mid.x + 3.0, bottom_mid.y),
		Vector2(bottom_mid.x - 3.0, bottom_mid.y)
	])
	draw_colored_polygon(fold_poly, COL_CAPE_MID)

	var trim = PackedVector2Array([bottom_left, bottom_mid, bottom_right])
	draw_polyline(trim, COL_GOLD_TRIM, 1.2, false)

# --- LEGS & SABATONS (GROUNDED LUNGE & STRIDE) ---
func _draw_legs_and_sabatons(is_rear: bool) -> void:
	var l_foot = Vector2.ZERO
	var r_foot = Vector2.ZERO
	var l_hip = Vector2(-5.0, -16.0 + body_crouch) + body_lunge
	var r_hip = Vector2(5.0, -16.0 + body_crouch) + body_lunge

	if is_attacking:
		var lunge_dist = body_lunge.length()
		var aim_x = _get_dir_vector(current_dir).x

		if aim_x >= 0.0:
			r_foot = Vector2(5.0 + lunge_dist * 0.9, 0.0)
			l_foot = Vector2(-5.0 - lunge_dist * 0.4, 0.0)
		else:
			l_foot = Vector2(-5.0 - lunge_dist * 0.9, 0.0)
			r_foot = Vector2(5.0 + lunge_dist * 0.4, 0.0)
	elif is_moving:
		var step_swing = sin(walk_cycle) * (7.0 + speed_ratio * 4.0)
		var l_lift = maxf(0.0, -cos(walk_cycle)) * (3.5 + speed_ratio * 2.0)
		var r_lift = maxf(0.0, cos(walk_cycle)) * (3.5 + speed_ratio * 2.0)
		l_foot = Vector2(-5.0 + step_swing * 0.5, -l_lift)
		r_foot = Vector2(5.0 - step_swing * 0.5, -r_lift)
	else:
		l_foot = Vector2(-5.0, 0.0)
		r_foot = Vector2(5.0, 0.0)

	_draw_single_leg(l_hip, l_foot, false, is_rear)
	_draw_single_leg(r_hip, r_foot, true, is_rear)

func _draw_single_leg(hip: Vector2, foot: Vector2, is_right: bool, is_rear: bool) -> void:
	var knee = (hip + foot) * 0.5 + Vector2(0.0, -1.0)
	
	var leg_poly = PackedVector2Array([
		hip + Vector2(-2.5, 0.0),
		hip + Vector2(2.5, 0.0),
		knee + Vector2(2.5, 0.0),
		foot + Vector2(2.5, -2.0),
		foot + Vector2(-2.5, -2.0),
		knee + Vector2(-2.5, 0.0)
	])
	draw_colored_polygon(leg_poly, COL_ARMOR_BASE)
	draw_rect(Rect2(knee + Vector2(-2.0, -1.5), Vector2(4.0, 3.0)), COL_ARMOR_MID)

	var sabaton = PackedVector2Array()
	var toe_pt = Vector2.ZERO
	if is_rear:
		# Seen from behind: armor heel guard
		sabaton.append(foot + Vector2(-3.0, -2.0))
		sabaton.append(foot + Vector2(3.0, -2.0))
		sabaton.append(foot + Vector2(2.5, 0.0))
		sabaton.append(foot + Vector2(-2.5, 0.0))
	elif current_dir == Dir8.E or (is_right and current_dir != Dir8.W):
		var tx = 5.5 if current_dir == Dir8.E else 4.0
		toe_pt = foot + Vector2(tx, 0.0)
		sabaton.append(foot + Vector2(-3.0, -2.0))
		sabaton.append(foot + Vector2(2.0, -2.0))
		sabaton.append(toe_pt)
		sabaton.append(foot + Vector2(-3.0, 0.0))
	elif current_dir == Dir8.W or (not is_right and current_dir != Dir8.E):
		var tx = -5.5 if current_dir == Dir8.W else -4.0
		toe_pt = foot + Vector2(tx, 0.0)
		sabaton.append(toe_pt)
		sabaton.append(foot + Vector2(-2.0, -2.0))
		sabaton.append(foot + Vector2(3.0, -2.0))
		sabaton.append(foot + Vector2(3.0, 0.0))
	else:
		sabaton.append(foot + Vector2(-3.0, -2.0))
		sabaton.append(foot + Vector2(3.0, -2.0))
		sabaton.append(foot + Vector2(3.0, 0.0))
		sabaton.append(foot + Vector2(-3.0, 0.0))

	draw_colored_polygon(sabaton, COL_ARMOR_MID)
	if toe_pt != Vector2.ZERO:
		draw_line(foot + Vector2(0.0, -1.5), toe_pt, COL_ARMOR_HI, 1.2, false)

# --- TORSO, CUIRASS & PAULDRONS ---
func _draw_torso(is_rear: bool) -> void:
	var bob = sin(walk_cycle * 2.0) * (1.2 if is_moving else 0.4)
	var base_y = -16.0 + bob + body_crouch + body_lunge.y
	var chest_y = -29.0 + bob + body_crouch + body_lunge.y
	var center_x = body_lunge.x

	var tasset_pts = PackedVector2Array([
		Vector2(center_x - 7.0, base_y - 3.0),
		Vector2(center_x + 7.0, base_y - 3.0),
		Vector2(center_x + 8.5, base_y),
		Vector2(center_x - 8.5, base_y)
	])
	draw_colored_polygon(tasset_pts, COL_ARMOR_BASE)

	draw_line(Vector2(center_x - 7.0, base_y - 2.5), Vector2(center_x + 7.0, base_y - 2.5), COL_LEATHER, 2.0, false)
	if not is_rear:
		draw_rect(Rect2(Vector2(center_x - 2.0, base_y - 4.0), Vector2(4.0, 3.0)), COL_GOLD_TRIM)

	var twist_offset = body_twist * 6.0
	var cuirass_pts = PackedVector2Array([
		Vector2(center_x - 6.5 + twist_offset * 0.3, base_y - 2.5),
		Vector2(center_x + 6.5 + twist_offset * 0.3, base_y - 2.5),
		Vector2(center_x + 9.0 + twist_offset, chest_y + 4.0),
		Vector2(center_x + 8.0 + twist_offset, chest_y),
		Vector2(center_x - 8.0 + twist_offset, chest_y),
		Vector2(center_x - 9.0 + twist_offset, chest_y + 4.0)
	])
	draw_colored_polygon(cuirass_pts, COL_ARMOR_MID)
	if not is_rear:
		draw_line(Vector2(center_x + twist_offset, chest_y + 1.0), Vector2(center_x + twist_offset * 0.3, base_y - 2.5), COL_ARMOR_HI, 1.4, false)
	else:
		draw_line(Vector2(center_x + twist_offset, chest_y + 2.0), Vector2(center_x + twist_offset * 0.3, base_y - 2.5), COL_ARMOR_DARK, 1.4, false)

	var pauldron_l = Vector2(center_x - 10.0 + twist_offset, chest_y + 2.0)
	var pauldron_r = Vector2(center_x + 10.0 + twist_offset, chest_y + 2.0)
	draw_rect(Rect2(pauldron_l - Vector2(3.5, 3.5), Vector2(7.0, 7.0)), COL_ARMOR_BASE)
	draw_rect(Rect2(pauldron_l - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), COL_ARMOR_HI)
	draw_rect(Rect2(pauldron_r - Vector2(3.5, 3.5), Vector2(7.0, 7.0)), COL_ARMOR_BASE)
	draw_rect(Rect2(pauldron_r - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), COL_ARMOR_HI)

# --- GREATHELM & GLOWING SOUL-SLIT VISOR ---
func _draw_greathelm(is_rear: bool) -> void:
	var bob = sin(walk_cycle * 2.0) * (1.2 if is_moving else 0.4)
	var center = Vector2(body_lunge.x + body_twist * 4.0, -36.0 + bob + body_crouch + body_lunge.y)

	var gorget_pts = PackedVector2Array([
		center + Vector2(-5.5, 6.0),
		center + Vector2(5.5, 6.0),
		center + Vector2(4.0, 3.0),
		center + Vector2(-4.0, 3.0)
	])
	draw_colored_polygon(gorget_pts, COL_ARMOR_DARK)

	var helm_pts = PackedVector2Array([
		center + Vector2(-6.0, 4.0),
		center + Vector2(6.0, 4.0),
		center + Vector2(6.5, -4.0),
		center + Vector2(4.0, -9.0),
		center + Vector2(-4.0, -9.0),
		center + Vector2(-6.5, -4.0)
	])
	draw_colored_polygon(helm_pts, COL_ARMOR_BASE)

	draw_line(center + Vector2(0.0, -9.0), center + Vector2(0.0, 4.0), COL_ARMOR_HI, 1.4, false)
	draw_rect(Rect2(center + Vector2(-3.5, -7.5), Vector2(2.0, 2.0)), COL_GOLD_TRIM)
	draw_rect(Rect2(center + Vector2(2.5, -7.5), Vector2(2.0, 2.0)), COL_GOLD_TRIM)

	if is_rear:
		var mail_pts = PackedVector2Array([
			center + Vector2(-5.0, 0.0),
			center + Vector2(5.0, 0.0),
			center + Vector2(5.5, 6.0),
			center + Vector2(-5.5, 6.0)
		])
		draw_colored_polygon(mail_pts, COL_ARMOR_DARK)
	else:
		var slit_x = 0.0
		var slit_w = 6.0
		match current_dir:
			Dir8.S:  slit_x = 0.0; slit_w = 6.0
			Dir8.SE: slit_x = 2.0; slit_w = 5.0
			Dir8.SW: slit_x = -2.0; slit_w = 5.0
			Dir8.E:  slit_x = 3.5; slit_w = 3.5
			Dir8.W:  slit_x = -3.5; slit_w = 3.5

		var vy = center.y + 0.5
		var v1 = Vector2(center.x + slit_x - slit_w * 0.5, vy)
		var v2 = Vector2(center.x + slit_x + slit_w * 0.5, vy)

		draw_line(v1 - Vector2(1, 0), v2 + Vector2(1, 0), COL_ARMOR_DARK, 3.0, false)
		var glow_col = COL_VISOR_GLOW if not is_attacking else Color(0.4, 1.0, 1.3, 1.0)
		draw_line(v1, v2, glow_col, 2.0, false)
		draw_line(v1 + Vector2(0.5, 0), v2 - Vector2(0.5, 0), COL_VISOR_CORE, 1.0, false)

# --- 8-DIRECTIONALLY ADAPTED WEAPONS & SOLID FILLED WIND CLEAVE ---
func _compute_equipment_transforms() -> void:
	var bob = sin(walk_cycle * 2.0) * (1.2 if is_moving else 0.4)
	var body_pos = body_lunge + Vector2(0.0, bob + body_crouch)
	var chest_pos = Vector2(0.0, -22.0) + body_pos

	var f_ang = _get_forward_sword_angle(current_dir)
	var f_dir = Vector2(sin(f_ang), -cos(f_ang) * 0.70).normalized()

	# Defaults
	var base_shield_pos = Vector2(-11.0, 0.0)
	var base_sword_pos  = Vector2(11.0, 1.0)
	var base_shield_ang = -0.15
	var base_sword_ang  = 0.55
	shield_scale_x = 1.0
	shield_is_facing_away = false
	blade_len = 25.0
	has_trail = false

	# Configure per-direction perspective, hand placements, and depth sorting:
	match current_dir:
		Dir8.S: # South (Direct Front)
			base_shield_pos = Vector2(-11.0, 0.0)
			base_sword_pos  = Vector2(11.0, 1.0)
			base_shield_ang = -0.15
			base_sword_ang  = 0.55
			shield_scale_x = 1.0
			shield_is_facing_away = false
			shield_in_front = true
			sword_in_front = true
			trail_in_front = true

		Dir8.SE: # South-East (3/4 Front-Right)
			base_shield_pos = Vector2(-6.0, 1.0)
			base_sword_pos  = Vector2(14.0, 3.0)
			base_shield_ang = 0.15
			base_sword_ang  = 0.85
			shield_scale_x = 0.85
			shield_is_facing_away = false
			shield_in_front = true
			sword_in_front = true
			trail_in_front = true

		Dir8.E: # East (Right Profile)
			base_shield_pos = Vector2(-1.0, -3.0) # Far side of torso
			base_sword_pos  = Vector2(14.0, 4.0)  # Near side of torso
			base_shield_ang = 0.35
			base_sword_ang  = 1.10
			shield_scale_x = 0.55 # Side foreshortening
			shield_is_facing_away = false
			shield_in_front = false # Behind torso!
			sword_in_front = true   # In front of torso!
			trail_in_front = true

		Dir8.NE: # North-East (3/4 Back-Right)
			base_shield_pos = Vector2(7.0, -4.0)
			base_sword_pos  = Vector2(13.0, -2.0)
			base_shield_ang = 0.30
			base_sword_ang  = 0.45
			shield_scale_x = 0.80
			shield_is_facing_away = true # Inside straps visible
			shield_in_front = false # Behind torso & head!
			sword_in_front = false  # Behind torso & head!
			trail_in_front = false  # Behind torso & head!

		Dir8.N: # North (Rear View)
			base_shield_pos = Vector2(11.0, -4.0)
			base_sword_pos  = Vector2(-11.0, -4.0)
			base_shield_ang = 0.15
			base_sword_ang  = -0.45
			shield_scale_x = 1.0
			shield_is_facing_away = true # Interior straps visible, no front cross!
			shield_in_front = false # Strictly underneath/behind body & head!
			sword_in_front = false  # Strictly underneath/behind body & head!
			trail_in_front = false  # Strictly underneath/behind body & head!

		Dir8.NW: # North-West (3/4 Back-Left)
			base_shield_pos = Vector2(-7.0, -4.0)
			base_sword_pos  = Vector2(-13.0, -2.0)
			base_shield_ang = -0.30
			base_sword_ang  = -0.45
			shield_scale_x = 0.80
			shield_is_facing_away = true # Interior straps
			shield_in_front = false # Behind body!
			sword_in_front = false  # Behind body!
			trail_in_front = false  # Behind body!

		Dir8.W: # West (Left Profile)
			base_shield_pos = Vector2(-14.0, 4.0) # Near side
			base_sword_pos  = Vector2(1.0, -3.0)   # Far side
			base_shield_ang = -0.35
			base_sword_ang  = -1.10
			shield_scale_x = 0.55 # Side foreshortening
			shield_is_facing_away = false
			shield_in_front = true  # Shield in front of torso!
			sword_in_front = false # Sword behind torso!
			trail_in_front = false # Trail behind torso!

		Dir8.SW: # South-West (3/4 Front-Left)
			base_shield_pos = Vector2(-10.0, 2.0)
			base_sword_pos  = Vector2(-14.0, 1.0)
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

	# 3. PARRY MODIFIERS
	if parry_blend > 0.01:
		var parry_shield_pos = chest_pos + f_dir * 16.0
		shield_pos = shield_pos.lerp(parry_shield_pos, parry_blend)
		shield_ang = lerp_angle(shield_ang, f_ang - PI * 0.5 + 0.1, parry_blend)

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

			2: # COMBO 2: TITANIC WIDE-AREA SWEEPING CLEAVE (ĐÒN SWIPE DIỆN RỘNG CỰC ĐẠI)
				var arc_start = f_ang - deg_to_rad(105.0)
				var arc_end   = f_ang + deg_to_rad(105.0)
				blade_len = 32.0 # Extended reach

				if t < 0.22: # Deep coiled windup
					var p = t / 0.22
					sword_ang = lerp_angle(base_sword_ang, arc_start, p)
					var s_dir = Vector2(sin(sword_ang), -cos(sword_ang) * 0.70).normalized()
					sword_pos = chest_pos + s_dir * 14.0
				elif t < 0.65: # Massive 210° full-body horizontal cleave!
					var p = (t - 0.22) / 0.43
					var s = 1.0 - pow(1.0 - p, 2.8)
					sword_ang = lerp_angle(arc_start, arc_end, s)
					var s_dir = Vector2(sin(sword_ang), -cos(sword_ang) * 0.70).normalized()
					sword_pos = chest_pos + s_dir * 15.0

					has_trail = true
					trail_center = chest_pos
					trail_blade_ang = sword_ang
					trail_sweep_dir = 1.0
					trail_span = deg_to_rad(125.0) * minf(p * 2.8, 1.0) * (1.0 - p * 0.30)
					trail_r_hilt = 14.0
					trail_r_tip = 15.0 + blade_len
					trail_is_finisher = true # Solid 3-tone storm cleave & outer shockwave!
				else: # Recovery
					var p = (t - 0.65) / 0.35
					var r = p * p
					sword_ang = lerp_angle(arc_end, base_sword_ang, r)
					var s_dir = Vector2(sin(sword_ang), -cos(sword_ang) * 0.70).normalized()
					sword_pos = chest_pos + s_dir * lerpf(15.0, 11.0, r)

# --- SOLID FILLED BLADE WIND TRAIL SYSTEM (ĐƯỜNG CONG GIÓ ĐẶC, 100% OPAQUE) ---
func _draw_blade_wind_trail(
	center: Vector2,
	blade_ang: float,
	sweep_dir: float,
	trail_span: float,
	r_hilt: float,
	r_tip: float,
	is_finisher: bool = false
) -> void:
	if trail_span < 0.04:
		return

	var num_segs = 16
	var pts_out = PackedVector2Array() # Outer cutting perimeter
	var pts_mid = PackedVector2Array() # Midline dividing outer bright and inner shade
	var pts_in  = PackedVector2Array() # Inner perimeter near hilt

	for i in range(num_segs + 1):
		var frac = float(i) / float(num_segs) # 0.0 at tail, 1.0 at blade
		var a = blade_ang - sweep_dir * trail_span * (1.0 - frac)

		var ro = r_tip
		var ri = lerpf(ro - 1.5, r_hilt, sin(frac * (PI * 0.5)))
		var rm = lerpf(ro - 1.0, (ro + ri) * 0.52, sin(frac * (PI * 0.5)))

		var dir_a = Vector2(sin(a), -cos(a) * 0.70).normalized()
		pts_out.append(center + dir_a * ro)
		pts_in.append(center + dir_a * ri)
		pts_mid.append(center + dir_a * rm)

	# 1. INNER SOLID SHADE BAND (Cel-shadow dark steel blue, 100% opaque)
	var poly_inner = PackedVector2Array()
	for p in pts_mid:
		poly_inner.append(p)
	for i in range(pts_in.size() - 1, -1, -1):
		poly_inner.append(pts_in[i])

	var col_shade = Color(0.20, 0.32, 0.48, 1.0) if not is_finisher else Color(0.18, 0.28, 0.46, 1.0)
	draw_colored_polygon(poly_inner, col_shade)

	# 2. MAIN SOLID LUMINOUS BODY (Solid bright silver/cyan white, 100% opaque)
	var poly_outer = PackedVector2Array()
	for p in pts_out:
		poly_outer.append(p)
	for i in range(pts_mid.size() - 1, -1, -1):
		poly_outer.append(pts_mid[i])

	var col_body = Color(0.92, 0.96, 1.0, 1.0) if not is_finisher else Color(0.88, 0.96, 1.0, 1.0)
	draw_colored_polygon(poly_outer, col_body)

	# 3. RAZOR-SHARP SOLID CUTTING CREST (Pure White, 2.2px)
	draw_polyline(pts_out, Color(1.0, 1.0, 1.0, 1.0), 2.2, false)

	# 4. CRISP INTERNAL VELOCITY STREAK (Pure White accent line along midline)
	draw_polyline(pts_mid, Color(1.0, 1.0, 1.0, 1.0), 1.2, false)

	# 5. INNER CONTOUR BOUNDARY
	draw_polyline(pts_in, Color(0.12, 0.18, 0.28, 1.0), 1.0, false)

	# 6. TITANIC FINISHER EXTRA SHOCKWAVE ARC (FOR HIT 3 WIDE-AREA CLEAVE)
	if is_finisher:
		var pts_shock = PackedVector2Array()
		for i in range(num_segs + 1):
			var frac = float(i) / float(num_segs)
			var a = blade_ang - sweep_dir * trail_span * (1.0 - frac)
			var dir_a = Vector2(sin(a), -cos(a) * 0.70).normalized()
			var r_shock = r_tip + 6.0 * sin(frac * PI)
			pts_shock.append(center + dir_a * r_shock)
		draw_polyline(pts_shock, Color(1.0, 1.0, 1.0, 1.0), 1.8, false)

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

	if parry_blend > 0.05:
		draw_polyline(rim_pts, Color(1.6, 1.3, 0.4, parry_blend), 2.0, false)


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
