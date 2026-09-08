class_name Orc2DVisualRenderer
extends Node2D

## 2.5D Masterclass Volumetric Orc Berserker Renderer (Dark Fantasy Ironfang Marauder)
## - True 8-Directional Isometric 2:1 Projections (Specialized for S, SW, W, NW, N):
##   * S (Down): Pure front isometric view (symmetrical horns, centered visor & twin eyes, twin tusks, broad pectorals)
##   * SW (Down-Left): 3/4 front isometric view (near spiked pauldron in foreground, near horn & tusk prominent)
##   * W (Left): True sharp side-profile silhouette (jutting lower jaw, single massive upward tusk, single forward eye slit,
##               occiput nape on right, near horn curving forward-up, pauldron & cleaver in foreground)
##   * NW (Up-Left): 3/4 rear isometric view (lobster-tail nape lames, rear latissimus, dorsal straps, cleaver behind body)
##   * N (Up): Pure rear isometric view (symmetrical helmet backplate, central vertical bronze dorsal spine, back kilt)
## - 3D-to-Isometric Kinematics:
##   * Unified ground plane (forward, right) and elevation Z projected via (X_g, Y_g * 0.5 - Z)
##   * 0 popping/stutter on impact; hilt and ground shockwave align with exact mathematical precision
## - Two-Handed Muscular Inverse Kinematics (IK):
##   * Both arms articulate with biceps, triceps, elbows, spiked bracers, and fists dynamically attached to shoulders
## - 5-Phase Overhead Cleaver Slam & 2:1 Ground Impact Shockwave:
##   * Windup -> Apex Tremor -> Explosive Cleave -> Ground Impact Fissures -> Levered Recovery

enum Dir8 { E = 0, SE = 1, S = 2, SW = 3, W = 4, NW = 5, N = 6, NE = 7 }

var current_dir: Dir8 = Dir8.S
var is_moving: bool = false
var speed_ratio: float = 0.0
var is_attacking: bool = false
var attack_timer: float = 0.0
var attack_duration: float = 0.92
var attack_progress: float = 0.0
var current_move_vec: Vector2 = Vector2.ZERO

var walk_cycle: float = 0.0
var idle_time: float = 0.0

# Kinetic Body Transforms
var body_twist: float = 0.0
var body_lunge_g: Vector2 = Vector2.ZERO
var body_lunge_screen: Vector2 = Vector2.ZERO
var body_crouch: float = 0.0

# 3D Skeletal Transforms Cache
var shoulder_l_pos: Vector2 = Vector2.ZERO
var shoulder_r_pos: Vector2 = Vector2.ZERO
var hip_l_pos: Vector2 = Vector2.ZERO
var hip_r_pos: Vector2 = Vector2.ZERO
var foot_l_pos: Vector2 = Vector2.ZERO
var foot_r_pos: Vector2 = Vector2.ZERO
var foot_l_lift: float = 0.0
var foot_r_lift: float = 0.0

# 2.5D Attack Kinematics Cache
var cleaver_tip_pos: Vector2 = Vector2.ZERO
var cleaver_guard_pos: Vector2 = Vector2.ZERO
var cleaver_pommel_pos: Vector2 = Vector2.ZERO
var hand_lead_pos: Vector2 = Vector2.ZERO
var hand_off_pos: Vector2 = Vector2.ZERO
var cleaver_blade_dir: Vector2 = Vector2.ZERO
var cleaver_is_embedded: bool = false
var impact_ground_pos: Vector2 = Vector2.ZERO
var impact_progress: float = 0.0

# Swept Wind Trail Caches
var has_cleave_trail: bool = false
var trail_progress: float = 0.0
var trail_tip_history: Array[Vector2] = []
var trail_guard_history: Array[Vector2] = []

# Gritty Dark Fantasy Orc Palette
const COL_SHADOW       = Color(0.0, 0.0, 0.0, 0.46)
const COL_SKIN_DARK    = Color(0.12, 0.18, 0.10) # Deep shadow muscle contours
const COL_SKIN_BASE    = Color(0.22, 0.32, 0.16) # Weathered orc flesh
const COL_SKIN_HI      = Color(0.35, 0.48, 0.25) # Lit muscular striations
const COL_SKIN_SPEC    = Color(0.50, 0.65, 0.38) # Specular muscle glint

const COL_WAR_ASH      = Color(0.78, 0.76, 0.70, 0.85) # Ritual bone-ash war paint
const COL_WAR_BLOOD    = Color(0.55, 0.12, 0.10, 0.90) # Dried war blood runes

const COL_IRON_DARK    = Color(0.08, 0.09, 0.12) # Blackened forged iron
const COL_IRON_MID     = Color(0.22, 0.26, 0.32) # Pitted armor plates
const COL_IRON_HI      = Color(0.48, 0.54, 0.64) # Beveled steel highlights
const COL_IRON_SPEC    = Color(0.85, 0.90, 0.98) # Razor cutting edge & glint

const COL_BRONZE_DARK  = Color(0.35, 0.22, 0.10)
const COL_BRONZE_MID   = Color(0.68, 0.48, 0.20) # Horn reinforcement bands
const COL_BRONZE_HI    = Color(0.90, 0.72, 0.35)

const COL_LEATHER_DK   = Color(0.14, 0.09, 0.06)
const COL_LEATHER_MID  = Color(0.28, 0.18, 0.11)
const COL_FUR_TRIM     = Color(0.45, 0.38, 0.30)

const COL_TUSK_DARK    = Color(0.42, 0.38, 0.25)
const COL_TUSK_IVORY   = Color(0.88, 0.84, 0.68)
const COL_EYE_RED      = Color(2.5, 0.25, 0.12, 1.0) # Burning feral red eyes

func update_state(
	delta: float,
	dir: Dir8,
	moving: bool,
	spd_rat: float,
	attacking: bool,
	att_timer: float,
	att_dur: float,
	move_vec: Vector2 = Vector2.ZERO
) -> void:
	current_dir = dir
	is_moving = moving
	speed_ratio = spd_rat
	is_attacking = attacking
	attack_timer = att_timer
	attack_duration = att_dur
	attack_progress = 1.0 - (att_timer / att_dur) if att_dur > 0.0 else 0.0
	current_move_vec = move_vec.normalized() if move_vec != Vector2.ZERO else _get_screen_dir_vector(dir)

	idle_time += delta
	if is_moving:
		walk_cycle += delta * 6.5 * spd_rat

	_compute_kinetics()
	queue_redraw()

func _get_ground_vectors(dir: Dir8) -> Dictionary:
	var fwd: Vector2
	match dir:
		Dir8.E:  fwd = Vector2(1.0, 0.0)
		Dir8.SE: fwd = Vector2(0.7071, 0.7071)
		Dir8.S:  fwd = Vector2(0.0, 1.0)
		Dir8.SW: fwd = Vector2(-0.7071, 0.7071)
		Dir8.W:  fwd = Vector2(-1.0, 0.0)
		Dir8.NW: fwd = Vector2(-0.7071, -0.7071)
		Dir8.N:  fwd = Vector2(0.0, -1.0)
		Dir8.NE: fwd = Vector2(0.7071, -0.7071)
		_:       fwd = Vector2(0.0, 1.0)
	var right = Vector2(-fwd.y, fwd.x) # 90° clockwise in ground plane
	return {"fwd": fwd, "right": right}

func _to_screen(ground_pos: Vector2, elevation_z: float = 0.0) -> Vector2:
	return Vector2(ground_pos.x, ground_pos.y * 0.5 - elevation_z)

func _compute_kinetics() -> void:
	var g_vecs = _get_ground_vectors(current_dir)
	var g_fwd: Vector2 = g_vecs["fwd"]
	var g_right: Vector2 = g_vecs["right"]
	var is_prof = (current_dir == Dir8.W or current_dir == Dir8.E)

	if is_attacking:
		var t = attack_progress

		if t < 0.38:
			# Phase 1: Heavy Coiling Windup
			var p = t / 0.38
			var s = p * p
			body_twist = lerpf(0.0, -0.48, s)
			body_crouch = lerpf(0.0, 5.0, s)
			body_lunge_g = -g_fwd * (4.0 * s)

			var reach = lerpf(0.0, -12.0, s)
			var lateral = lerpf(0.0, 14.0, s) # Shifted to character's right side
			var elevation_z = lerpf(24.0, 56.0, s)

			var hand_g = body_lunge_g + (g_fwd * reach) + (g_right * lateral)
			var hilt_screen = _to_screen(hand_g, elevation_z)

			# Blade angled back-upward behind right shoulder
			var blade_g = -g_fwd * lerpf(0.20, 0.40, s) + g_right * lerpf(0.10, 0.20, s)
			var z_comp = lerpf(0.60, 0.92, s)
			cleaver_blade_dir = Vector2(blade_g.x, blade_g.y * 0.5 - z_comp).normalized()

			hand_lead_pos = hilt_screen
			hand_off_pos = hand_lead_pos - cleaver_blade_dir * 8.0
			cleaver_guard_pos = hand_lead_pos + cleaver_blade_dir * 4.0
			cleaver_pommel_pos = hand_off_pos - cleaver_blade_dir * 5.0
			cleaver_tip_pos = cleaver_guard_pos + cleaver_blade_dir * 38.0

			has_cleave_trail = false
			cleaver_is_embedded = false
			impact_progress = 0.0
			trail_tip_history.clear()
			trail_guard_history.clear()

		elif t < 0.44:
			# Phase 2: Apex Tension Hold & Tremor
			var p = (t - 0.38) / 0.06
			var tremble = sin(p * TAU * 3.0) * 0.8
			body_twist = -0.48 + (tremble * 0.02)
			body_crouch = 5.0
			body_lunge_g = -g_fwd * 4.0

			var reach = -12.0
			var lateral = 14.0
			var elevation_z = 56.0 + tremble

			var hand_g = body_lunge_g + (g_fwd * reach) + (g_right * lateral)
			var hilt_screen = _to_screen(hand_g, elevation_z)

			var blade_g = -g_fwd * 0.40 + g_right * 0.20
			var z_comp = 0.92
			cleaver_blade_dir = Vector2(blade_g.x, blade_g.y * 0.5 - z_comp).normalized()

			hand_lead_pos = hilt_screen
			hand_off_pos = hand_lead_pos - cleaver_blade_dir * 8.0
			cleaver_guard_pos = hand_lead_pos + cleaver_blade_dir * 4.0
			cleaver_pommel_pos = hand_off_pos - cleaver_blade_dir * 5.0
			cleaver_tip_pos = cleaver_guard_pos + cleaver_blade_dir * 38.0

			has_cleave_trail = false
			cleaver_is_embedded = false
			impact_progress = 0.0
			trail_tip_history.clear()
			trail_guard_history.clear()

		elif t < 0.62:
			# Phase 3: Explosive Downward Diagonal Cleave (True 2.5D Isometric Arc!)
			var p = (t - 0.44) / 0.18
			var s = 1.0 - pow(1.0 - p, 3.4)

			body_twist = lerpf(-0.48, 0.50, s)
			body_crouch = lerpf(5.0, 7.5, s)
			body_lunge_g = g_fwd * lerpf(-4.0, 16.0, s)

			var reach = lerpf(-12.0, 28.0, s)
			var lateral = lerpf(14.0, -4.0, s) # Sweeps across to character's left side
			var elevation_z = lerpf(56.0, 0.0, s) # Crashes down to ground!

			var hand_g = body_lunge_g + (g_fwd * reach) + (g_right * lateral)
			var hilt_screen = _to_screen(hand_g, elevation_z + 16.0)

			# Blade sweeps from high upward angle down into ground impact angle
			var fwd_comp = lerpf(-0.35, 0.95, s)
			var lat_comp = lerpf(0.20, -0.15, s)
			var z_comp   = lerpf(0.92, -0.32, s)
			var blade_g = g_fwd * fwd_comp + g_right * lat_comp
			cleaver_blade_dir = Vector2(blade_g.x, blade_g.y * 0.5 - z_comp).normalized()

			hand_lead_pos = hilt_screen
			hand_off_pos = hand_lead_pos - cleaver_blade_dir * 8.0
			cleaver_guard_pos = hand_lead_pos + cleaver_blade_dir * 4.0
			cleaver_pommel_pos = hand_off_pos - cleaver_blade_dir * 5.0
			cleaver_tip_pos = cleaver_guard_pos + cleaver_blade_dir * 38.0

			has_cleave_trail = (p > 0.10)
			trail_progress = p * 0.6
			trail_tip_history.clear()
			trail_guard_history.clear()

			if has_cleave_trail:
				var arc_start_p = maxf(0.0, p - 0.18)
				var steps = 8
				for i in range(steps):
					var sample_p = lerpf(arc_start_p, p, float(i) / float(steps - 1))
					var s_i = 1.0 - pow(1.0 - sample_p, 3.4)
					var lunge_i = g_fwd * lerpf(-4.0, 16.0, s_i)
					var reach_i = lerpf(-12.0, 28.0, s_i)
					var lat_i   = lerpf(14.0, -4.0, s_i)
					var el_i    = lerpf(56.0, 0.0, s_i)
					var h_g_i   = lunge_i + (g_fwd * reach_i) + (g_right * lat_i)
					var hilt_i  = _to_screen(h_g_i, el_i + 16.0)
					var f_c_i   = lerpf(-0.35, 0.95, s_i)
					var l_c_i   = lerpf(0.20, -0.15, s_i)
					var z_c_i   = lerpf(0.92, -0.32, s_i)
					var b_g_i   = g_fwd * f_c_i + g_right * l_c_i
					var b_dir_i = Vector2(b_g_i.x, b_g_i.y * 0.5 - z_c_i).normalized()
					var guard_i = hilt_i + b_dir_i * 4.0
					var tip_i   = guard_i + b_dir_i * 38.0
					trail_tip_history.append(tip_i)
					trail_guard_history.append(guard_i)

			cleaver_is_embedded = (p >= 0.92)
			var impact_g = body_lunge_g + (g_fwd * 28.0) + (g_right * -4.0)
			impact_ground_pos = _to_screen(impact_g, 0.0)

		elif t < 0.78:
			# Phase 4: Ground Embedded Impact & Shockwave
			var p = (t - 0.62) / 0.16
			body_twist = 0.50
			body_crouch = 7.5
			body_lunge_g = g_fwd * 16.0

			var impact_g = body_lunge_g + (g_fwd * 28.0) + (g_right * -4.0)
			impact_ground_pos = _to_screen(impact_g, 0.0)
			cleaver_is_embedded = true
			impact_progress = p

			var hilt_screen = _to_screen(impact_g, 16.0) # Exactly 16px above impact point
			var blade_g = g_fwd * 0.95 - g_right * 0.15
			var z_comp = -0.32
			cleaver_blade_dir = Vector2(blade_g.x, blade_g.y * 0.5 - z_comp).normalized()

			hand_lead_pos = hilt_screen
			hand_off_pos = hand_lead_pos - cleaver_blade_dir * 8.0
			cleaver_guard_pos = hand_lead_pos + cleaver_blade_dir * 4.0
			cleaver_pommel_pos = hand_off_pos - cleaver_blade_dir * 5.0
			cleaver_tip_pos = cleaver_guard_pos + cleaver_blade_dir * 38.0

			has_cleave_trail = (p < 0.38)
			trail_progress = 0.55 + (p / 0.38) * 0.45
			trail_tip_history.clear()
			trail_guard_history.clear()

			if has_cleave_trail:
				var fade_ratio = p / 0.38
				var arc_start_p = lerpf(0.82, 0.96, fade_ratio)
				var steps = 8
				for i in range(steps):
					var sample_p = lerpf(arc_start_p, 1.0, float(i) / float(steps - 1))
					var s_i = 1.0 - pow(1.0 - sample_p, 3.4)
					var lunge_i = g_fwd * lerpf(-4.0, 16.0, s_i)
					var reach_i = lerpf(-12.0, 28.0, s_i)
					var lat_i   = lerpf(14.0, -4.0, s_i)
					var el_i    = lerpf(56.0, 0.0, s_i)
					var h_g_i   = lunge_i + (g_fwd * reach_i) + (g_right * lat_i)
					var hilt_i  = _to_screen(h_g_i, el_i + 16.0)
					var f_c_i   = lerpf(-0.35, 0.95, s_i)
					var l_c_i   = lerpf(0.20, -0.15, s_i)
					var z_c_i   = lerpf(0.92, -0.32, s_i)
					var b_g_i   = g_fwd * f_c_i + g_right * l_c_i
					var b_dir_i = Vector2(b_g_i.x, b_g_i.y * 0.5 - z_c_i).normalized()
					var guard_i = hilt_i + b_dir_i * 4.0
					var tip_i   = guard_i + b_dir_i * 38.0
					trail_tip_history.append(tip_i)
					trail_guard_history.append(guard_i)

		else:
			# Phase 5: Two-Handed Levered Pull-Out & Recovery
			var p = (t - 0.78) / 0.22
			var r = 1.0 - (1.0 - p) * (1.0 - p)

			cleaver_is_embedded = (p < 0.28)
			impact_progress = lerpf(1.0, 1.5, p)
			has_cleave_trail = false
			trail_tip_history.clear()
			trail_guard_history.clear()

			body_twist = lerpf(0.50, 0.0, r)
			body_crouch = lerpf(7.5, 0.0, r)
			body_lunge_g = g_fwd * lerpf(16.0, 0.0, r)

			var reach   = lerpf(28.0, 4.0, r)
			var lateral = lerpf(-4.0, 12.0, r)
			var elevation_z = lerpf(0.0, 18.0, r)

			var hand_g = body_lunge_g + (g_fwd * reach) + (g_right * lateral)
			var hilt_screen = _to_screen(hand_g, elevation_z + 14.0)

			var fwd_comp = lerpf(0.95, 0.35, r)
			var lat_comp = lerpf(-0.15, 0.20, r)
			var z_comp   = lerpf(-0.32, -0.75, r)
			var blade_g = g_fwd * fwd_comp + g_right * lat_comp
			cleaver_blade_dir = Vector2(blade_g.x, blade_g.y * 0.5 - z_comp).normalized()

			hand_lead_pos = hilt_screen
			hand_off_pos = hand_lead_pos - cleaver_blade_dir * 8.0
			cleaver_guard_pos = hand_lead_pos + cleaver_blade_dir * 4.0
			cleaver_pommel_pos = hand_off_pos - cleaver_blade_dir * 5.0
			cleaver_tip_pos = cleaver_guard_pos + cleaver_blade_dir * 38.0

	else:
		# Idle & Locomotion Swagger
		has_cleave_trail = false
		cleaver_is_embedded = false
		impact_progress = 0.0
		trail_tip_history.clear()
		trail_guard_history.clear()
		body_lunge_g = Vector2.ZERO

		# In profile, hold cleaver slightly forward in foreground (-g_right brings it south toward camera)
		var idle_lateral = -2.5 if is_prof else 12.0
		var idle_reach = 6.0 if is_prof else 4.0

		if is_moving:
			body_twist = sin(walk_cycle) * 0.16
			body_crouch = absf(sin(walk_cycle)) * 1.5
			var sway_z = sin(walk_cycle * 2.0) * 1.2

			var reach = idle_reach
			var lateral = idle_lateral
			var elevation_z = 18.0 + sway_z

			var hand_g = (g_fwd * reach) + (g_right * lateral)
			var hilt_screen = _to_screen(hand_g, elevation_z)

			var blade_g = g_fwd * (0.40 + sin(walk_cycle) * 0.06) + (g_right * (0.15 if not is_prof else -0.15))
			var z_comp = -0.75
			cleaver_blade_dir = Vector2(blade_g.x, blade_g.y * 0.5 - z_comp).normalized()

			hand_lead_pos = hilt_screen
			hand_off_pos = hand_lead_pos - cleaver_blade_dir * 8.0
			cleaver_guard_pos = hand_lead_pos + cleaver_blade_dir * 4.0
			cleaver_pommel_pos = hand_off_pos - cleaver_blade_dir * 5.0
			cleaver_tip_pos = cleaver_guard_pos + cleaver_blade_dir * 38.0
		else:
			body_twist = 0.0
			body_crouch = sin(idle_time * 2.5) * 0.6

			var reach = idle_reach
			var lateral = idle_lateral
			var elevation_z = 18.0 - body_crouch

			var hand_g = (g_fwd * reach) + (g_right * lateral)
			var hilt_screen = _to_screen(hand_g, elevation_z)

			var blade_g = g_fwd * 0.40 + (g_right * (0.15 if not is_prof else -0.15))
			var z_comp = -0.75
			cleaver_blade_dir = Vector2(blade_g.x, blade_g.y * 0.5 - z_comp).normalized()

			hand_lead_pos = hilt_screen
			hand_off_pos = hand_lead_pos - cleaver_blade_dir * 8.0
			cleaver_guard_pos = hand_lead_pos + cleaver_blade_dir * 4.0
			cleaver_pommel_pos = hand_off_pos - cleaver_blade_dir * 5.0
			cleaver_tip_pos = cleaver_guard_pos + cleaver_blade_dir * 38.0

	body_lunge_screen = _to_screen(body_lunge_g, 0.0)

	# Compute 3D Shoulders (Orc's Left Shoulder has pauldron at -g_right, Right Shoulder at +g_right)
	var tw_right = g_right.rotated(body_twist)
	var sh_w = 9.0 if is_prof else 13.5
	var sh_l_g = body_lunge_g - tw_right * sh_w
	var sh_r_g = body_lunge_g + tw_right * sh_w
	shoulder_l_pos = _to_screen(sh_l_g, 33.0 - body_crouch)
	shoulder_r_pos = _to_screen(sh_r_g, 33.0 - body_crouch)

	# Compute 3D Hips
	var hip_w = 4.5 if is_prof else 6.5
	var hip_l_g = body_lunge_g - g_right * hip_w
	var hip_r_g = body_lunge_g + g_right * hip_w
	hip_l_pos = _to_screen(hip_l_g, 18.5 - body_crouch)
	hip_r_pos = _to_screen(hip_r_g, 18.5 - body_crouch)

	# Compute 3D Feet Stance
	var base_foot_l_g: Vector2
	var base_foot_r_g: Vector2

	match current_dir:
		Dir8.S:
			base_foot_l_g = Vector2(7.0, 0.0)
			base_foot_r_g = Vector2(-7.0, 0.0)
		Dir8.N:
			base_foot_l_g = Vector2(-7.0, 0.0)
			base_foot_r_g = Vector2(7.0, 0.0)
		Dir8.W:
			# Left profile: near foot (left) forward-left, far foot (right) back-right
			base_foot_l_g = Vector2(-3.0, 4.5)
			base_foot_r_g = Vector2(3.0, -4.5)
		Dir8.E:
			base_foot_l_g = Vector2(-3.0, -4.5)
			base_foot_r_g = Vector2(3.0, 4.5)
		Dir8.SW:
			base_foot_l_g = Vector2(3.5, 4.0)
			base_foot_r_g = Vector2(-4.5, -4.0)
		Dir8.NW:
			base_foot_l_g = Vector2(-4.5, 2.0)
			base_foot_r_g = Vector2(3.5, -2.0)
		Dir8.SE:
			base_foot_l_g = Vector2(-3.5, 4.0)
			base_foot_r_g = Vector2(4.5, -4.0)
		Dir8.NE:
			base_foot_l_g = Vector2(4.5, 2.0)
			base_foot_r_g = Vector2(-3.5, -2.0)
		_:
			base_foot_l_g = Vector2(7.0, 0.0)
			base_foot_r_g = Vector2(-7.0, 0.0)

	var cur_foot_l_g = base_foot_l_g + body_lunge_g
	var cur_foot_r_g = base_foot_r_g + body_lunge_g
	foot_l_lift = 0.0
	foot_r_lift = 0.0

	if is_attacking:
		var lunge_dist = body_lunge_g.length()
		cur_foot_l_g += g_fwd * (lunge_dist * 0.40)
		cur_foot_r_g -= g_fwd * (lunge_dist * 0.25)
		if lunge_dist > 6.0:
			foot_r_lift = 3.0
	elif is_moving:
		var stride = sin(walk_cycle)
		var s_len = 5.0 * speed_ratio
		if stride > 0.0:
			cur_foot_l_g += g_fwd * (stride * s_len)
			foot_l_lift = sin(stride * PI) * 4.0
			cur_foot_r_g -= g_fwd * (stride * s_len * 0.65)
		else:
			cur_foot_r_g -= g_fwd * (stride * s_len)
			foot_r_lift = sin(absf(stride) * PI) * 4.0
			cur_foot_l_g += g_fwd * (stride * s_len * 0.65)

	foot_l_pos = _to_screen(cur_foot_l_g, foot_l_lift)
	foot_r_pos = _to_screen(cur_foot_r_g, foot_r_lift)

func _draw() -> void:
	var is_rear = (current_dir == Dir8.N or current_dir == Dir8.NW or current_dir == Dir8.NE)
	var is_pure_front = (current_dir == Dir8.S)
	var is_pure_rear  = (current_dir == Dir8.N)
	var is_profile    = (current_dir == Dir8.E or current_dir == Dir8.W)
	var dir_sign_x    = _get_dir_sign_x(current_dir)

	# 1. 2:1 Isometric Ground Contact Shadow
	_draw_heavy_shadow()

	# 2. Ground Impact Fissure Cracks & Expanding 2:1 Shockwave Ring
	if impact_progress > 0.0 and impact_progress <= 1.2:
		_draw_ground_impact_shockwave()

	var root_pos = body_lunge_screen + Vector2(0.0, body_crouch)

	# Cleaver in front for S, SW, W, SE, E; behind for N, NW, NE
	var cleaver_in_front = not is_rear

	# 3. Background Cleaver Wind Trail
	if has_cleave_trail and not cleaver_in_front:
		_draw_swept_cleaver_trail()

	# 4. Background Arms & Cleaver (if attacking away into depth)
	if not cleaver_in_front:
		_draw_two_handed_cleaver_and_arms(root_pos, dir_sign_x, is_rear, is_profile)

	# 5. Muscular Contoured Legs & Steel Sabatons (Depth Sorted)
	_draw_contoured_legs(is_rear)

	# 6. Studded Leather War-Kilt & Fur Pelts
	_draw_war_kilt(root_pos, is_rear, is_profile)

	# 7. Sculpted Muscular Torso
	_draw_sculpted_torso(root_pos, is_rear, is_profile, is_pure_front, is_pure_rear, dir_sign_x)

	# 8. Horned War-Mask & Savage Tusked Head
	_draw_horned_head(root_pos, is_rear, is_profile, is_pure_front, is_pure_rear, dir_sign_x)

	# 9. Foreground Arms, Cleaver & Spiked Pauldron
	if cleaver_in_front:
		_draw_two_handed_cleaver_and_arms(root_pos, dir_sign_x, is_rear, is_profile)

	# 10. Foreground Cleaver Wind Trail
	if has_cleave_trail and cleaver_in_front:
		_draw_swept_cleaver_trail()

func _draw_heavy_shadow() -> void:
	var l_mag = body_lunge_screen.length()
	var rx = 20.0 + (l_mag * 0.30)
	var ry = rx * 0.46
	var cen = Vector2(body_lunge_screen.x * 0.5, 0.0)

	var p_outer = PackedVector2Array()
	for i in range(16):
		var a = i * TAU / 16.0
		p_outer.append(cen + Vector2(roundf(cos(a) * (rx + 2.0)), roundf(sin(a) * (ry + 1.2))))
	draw_colored_polygon(p_outer, Color(0.0, 0.0, 0.0, 0.28))

	var p_inner = PackedVector2Array()
	for i in range(16):
		var a = i * TAU / 16.0
		p_inner.append(cen + Vector2(roundf(cos(a) * (rx * 0.68)), roundf(sin(a) * (ry * 0.68))))
	draw_colored_polygon(p_inner, Color(0.0, 0.0, 0.0, 0.44))

func _draw_ground_impact_shockwave() -> void:
	var cen = impact_ground_pos
	var alpha = clampf(1.0 - (impact_progress / 1.15), 0.0, 1.0)
	if alpha <= 0.01:
		return

	# Radial Stone Fracture Fissure Cracks
	var f_dirs = [
		Vector2(1.0, 0.45), Vector2(-1.0, 0.45), Vector2(0.9, -0.42), Vector2(-0.9, -0.42),
		Vector2(0.0, 0.95), Vector2(0.0, -0.95), Vector2(1.35, 0.1), Vector2(-1.35, 0.1)
	]
	for i in range(f_dirs.size()):
		var d = f_dirs[i].normalized()
		var d_len = lerpf(8.0, 24.0, clampf(impact_progress * 1.5, 0.0, 1.0)) * (0.8 + (i % 3) * 0.2)
		var p1 = cen + Vector2(d.x * d_len * 0.45, d.y * d_len * 0.22)
		var p2 = cen + Vector2(d.x * d_len, d.y * d_len * 0.48)
		draw_line(cen, p1, Color(0.05, 0.05, 0.06, alpha * 0.95), 3.2, false)
		draw_line(p1, p2, Color(0.85, 0.25, 0.10, alpha * 0.85), 1.8, false)
		draw_line(cen, p1, Color(1.0, 0.85, 0.45, alpha * 0.70), 1.0, false)

	# Expanding 2:1 Isometric Shockwave Ring
	var r_curr = lerpf(6.0, 32.0, clampf(impact_progress, 0.0, 1.0))
	var wave_pts = PackedVector2Array()
	for i in range(20):
		var a = i * TAU / 20.0
		wave_pts.append(cen + Vector2(cos(a) * r_curr, sin(a) * (r_curr * 0.48)))
	wave_pts.append(wave_pts[0])

	draw_polyline(wave_pts, Color(0.85, 0.18, 0.10, alpha * 0.75), 5.5, false)
	draw_polyline(wave_pts, Color(1.0, 0.60, 0.20, alpha * 0.92), 2.6, false)
	draw_polyline(wave_pts, Color(1.0, 1.0, 1.0, alpha), 1.2, false)

	for i in range(5):
		var a = i * TAU / 5.0 + (impact_progress * 2.0)
		var sp_dist = lerpf(8.0, 26.0, impact_progress)
		var sp_pt = cen + Vector2(cos(a) * sp_dist, sin(a) * sp_dist * 0.5 - (sin(impact_progress * PI) * 12.0))
		draw_circle(sp_pt, 1.5, Color(1.0, 0.75, 0.30, alpha))
		draw_circle(sp_pt, 0.7, Color(1.0, 1.0, 1.0, alpha))

# --- CONTOURED MUSCULAR LEGS & STEEL SABATONS ---
func _draw_contoured_legs(is_rear: bool) -> void:
	# Depth sorting: Draw far leg first (behind), then near leg (in front)
	var left_in_front = (foot_l_pos.y > foot_r_pos.y) or (foot_l_pos.y == foot_r_pos.y and hip_l_pos.y >= hip_r_pos.y)

	if left_in_front:
		# Right leg is far (draw first)
		_draw_single_muscular_leg(hip_r_pos, foot_r_pos, foot_r_lift, 1.0, true, is_rear)
		_draw_single_muscular_leg(hip_l_pos, foot_l_pos, foot_l_lift, -1.0, false, is_rear)
	else:
		# Left leg is far (draw first)
		_draw_single_muscular_leg(hip_l_pos, foot_l_pos, foot_l_lift, -1.0, true, is_rear)
		_draw_single_muscular_leg(hip_r_pos, foot_r_pos, foot_r_lift, 1.0, false, is_rear)

func _draw_single_muscular_leg(hip: Vector2, foot: Vector2, lift_y: float, side: float, is_far: bool, is_rear: bool) -> void:
	var knee = (hip + foot) * 0.5 + Vector2(side * 2.2, -2.5 - lift_y)
	var foot_ground = foot + Vector2(0.0, -lift_y)

	var col_dark = COL_SKIN_DARK
	var col_base = COL_SKIN_DARK if is_far else COL_SKIN_BASE
	var col_hi   = COL_SKIN_BASE if is_far else COL_SKIN_HI

	# Quadricep / Thigh
	var quad_poly = PackedVector2Array([
		hip + Vector2(-3.5, 0.0),
		hip + Vector2(3.5, 0.0),
		knee + Vector2(4.2, 0.0),
		knee + Vector2(-4.2, 0.0)
	])
	draw_colored_polygon(quad_poly, col_dark)

	var quad_hi = PackedVector2Array([
		hip + Vector2(-1.2, 0.0),
		hip + Vector2(1.8, 0.0),
		knee + Vector2(2.0, 0.0),
		knee + Vector2(-1.8, 0.0)
	])
	draw_colored_polygon(quad_hi, col_base)

	# Calf & Shin
	var calf_poly = PackedVector2Array([
		knee + Vector2(-4.0, 0.0),
		knee + Vector2(4.0, 0.0),
		foot_ground + Vector2(3.2, 0.0),
		foot_ground + Vector2(-3.2, 0.0)
	])
	draw_colored_polygon(calf_poly, col_dark)

	var calf_hi = PackedVector2Array([
		knee + Vector2(-1.5, 0.0),
		knee + Vector2(1.8, 0.0),
		foot_ground + Vector2(1.5, 0.0),
		foot_ground + Vector2(-1.5, 0.0)
	])
	draw_colored_polygon(calf_hi, col_base)

	# Knee Armor Plate (Poleyn)
	draw_circle(knee, 3.4, COL_IRON_DARK)
	draw_circle(knee, 2.4, COL_IRON_MID if not is_far else COL_IRON_DARK)
	if not is_far:
		draw_circle(knee - Vector2(0.8, 0.8), 1.1, COL_IRON_HI)

	# Banded Iron Sabaton
	var boot_w = 4.8
	var sabaton_poly = PackedVector2Array([
		foot_ground + Vector2(-boot_w, -3.5),
		foot_ground + Vector2(boot_w, -3.5),
		foot_ground + Vector2(boot_w + 1.0, 0.5),
		foot_ground + Vector2(-boot_w - 1.0, 0.5)
	])
	draw_colored_polygon(sabaton_poly, COL_IRON_DARK)
	draw_line(foot_ground + Vector2(-boot_w, -3.5), foot_ground + Vector2(boot_w, -3.5), COL_IRON_MID, 1.4, false)
	if not is_far:
		draw_line(foot_ground + Vector2(-boot_w, -1.8), foot_ground + Vector2(boot_w, -1.8), COL_IRON_HI, 1.2, false)

# --- STUDDED LEATHER WAR-KILT & FUR TRIM ---
func _draw_war_kilt(root: Vector2, is_rear: bool, is_profile: bool) -> void:
	var kilt_top_y = root.y - 20.0
	var kilt_bot_y = root.y - 9.0
	var w_top = 7.0 if is_profile else 12.5
	var w_bot = 8.8 if is_profile else 15.5

	var fur_poly = PackedVector2Array([
		Vector2(root.x - w_top - 1.5, kilt_top_y - 2.5),
		Vector2(root.x + w_top + 1.5, kilt_top_y - 2.5),
		Vector2(root.x + w_top + 2.0, kilt_top_y + 3.0),
		Vector2(root.x - w_top - 2.0, kilt_top_y + 3.0)
	])
	draw_colored_polygon(fur_poly, COL_FUR_TRIM)

	var kilt_poly = PackedVector2Array([
		Vector2(root.x - w_top, kilt_top_y),
		Vector2(root.x + w_top, kilt_top_y),
		Vector2(root.x + w_bot, kilt_bot_y),
		Vector2(root.x - w_bot, kilt_bot_y)
	])
	draw_colored_polygon(kilt_poly, COL_LEATHER_DK)

	var slits = [-6.0, 0.0, 6.0] if not is_profile else [-2.0, 2.5]
	for s in slits:
		draw_line(Vector2(root.x + s, kilt_top_y + 2.0), Vector2(root.x + (s * 1.2), kilt_bot_y - 1.0), COL_LEATHER_MID, 1.4, false)
		draw_circle(Vector2(root.x + (s * 1.1), kilt_top_y + 5.5), 1.1, COL_BRONZE_HI)
		draw_circle(Vector2(root.x + (s * 1.15), kilt_bot_y - 2.5), 1.1, COL_BRONZE_HI)

	if not is_rear:
		draw_circle(Vector2(root.x, kilt_top_y), 3.2, COL_IRON_DARK)
		draw_circle(Vector2(root.x, kilt_top_y), 2.2, COL_IRON_HI)
		draw_circle(Vector2(root.x, kilt_top_y), 1.0, COL_BRONZE_MID)

# --- SCULPTED MUSCULAR TORSO ---
func _draw_sculpted_torso(root: Vector2, is_rear: bool, is_profile: bool, is_pure_front: bool, is_pure_rear: bool, dir_sign_x: float) -> void:
	var chest_y = root.y - 33.0
	var waist_y = root.y - 19.5

	if is_profile:
		# Authentic Profile Torso: Convex anterior chest arc on left, concave dorsal back on right (for W)
		var p_sign = dir_sign_x if dir_sign_x != 0.0 else -1.0 # -1 for W, +1 for E
		var prof_poly = PackedVector2Array([
			Vector2(root.x - 5.0 * p_sign, waist_y),
			Vector2(root.x + 5.0 * p_sign, waist_y),
			Vector2(root.x + 6.8 * p_sign, chest_y + 4.0),
			Vector2(root.x + 5.5 * p_sign, chest_y - 1.5),
			Vector2(root.x - 7.0 * p_sign, chest_y - 1.5),
			Vector2(root.x - 6.5 * p_sign, chest_y + 4.0)
		])
		draw_colored_polygon(prof_poly, COL_SKIN_DARK)

		# Muscular lateral rib & oblique contour
		draw_line(Vector2(root.x - 4.5 * p_sign, chest_y + 2.0), Vector2(root.x - 1.0 * p_sign, waist_y - 2.0), COL_SKIN_HI, 2.2, false)
		draw_line(Vector2(root.x + 3.5 * p_sign, chest_y + 1.0), Vector2(root.x + 1.5 * p_sign, waist_y - 2.0), COL_SKIN_BASE, 1.8, false)
		draw_line(Vector2(root.x - 5.5 * p_sign, chest_y + 1.0), Vector2(root.x - 2.5 * p_sign, chest_y + 4.5), COL_WAR_ASH, 1.6, false)
		return

	# Front / 3/4 / Rear Torso
	var w_chest = 17.5
	var w_waist = 13.0

	var torso_poly = PackedVector2Array([
		Vector2(root.x - w_chest, chest_y),
		Vector2(root.x + w_chest, chest_y),
		Vector2(root.x + w_waist, waist_y),
		Vector2(root.x - w_waist, waist_y)
	])
	draw_colored_polygon(torso_poly, COL_SKIN_DARK)

	var torso_hi = PackedVector2Array([
		Vector2(root.x - (w_chest * 0.75), chest_y + 1.5),
		Vector2(root.x + (w_chest * 0.75), chest_y + 1.5),
		Vector2(root.x + (w_waist * 0.65), waist_y - 1.5),
		Vector2(root.x - (w_waist * 0.65), waist_y - 1.5)
	])
	draw_colored_polygon(torso_hi, COL_SKIN_BASE)

	if not is_rear:
		if is_pure_front:
			# Symmetrical front pectorals
			draw_line(Vector2(root.x - 12.0, chest_y + 2.0), Vector2(root.x - 1.0, chest_y + 7.0), COL_SKIN_DARK, 2.0, false)
			draw_line(Vector2(root.x + 1.0, chest_y + 7.0), Vector2(root.x + 12.0, chest_y + 2.0), COL_SKIN_DARK, 2.0, false)
			draw_line(Vector2(root.x, chest_y + 2.0), Vector2(root.x, waist_y), COL_SKIN_DARK, 1.8, false)
			draw_line(Vector2(root.x - 10.0, chest_y + 4.0), Vector2(root.x - 2.0, chest_y + 5.5), COL_SKIN_HI, 2.2, false)
			draw_line(Vector2(root.x + 2.0, chest_y + 5.5), Vector2(root.x + 10.0, chest_y + 4.0), COL_SKIN_HI, 2.2, false)
			draw_line(Vector2(root.x - 11.0, chest_y + 1.0), Vector2(root.x - 3.0, chest_y + 4.0), COL_WAR_ASH, 1.6, false)
			draw_line(Vector2(root.x + 3.0, chest_y + 4.0), Vector2(root.x + 11.0, chest_y + 1.0), COL_WAR_ASH, 1.6, false)
			draw_circle(Vector2(root.x, chest_y + 9.5), 1.8, COL_WAR_ASH)
		else:
			# 3/4 Front View (SW / SE)
			var off_x = dir_sign_x * 4.0
			draw_line(Vector2(root.x - 8.0 + off_x, chest_y + 3.0), Vector2(root.x + off_x, chest_y + 7.5), COL_SKIN_DARK, 2.0, false)
			draw_line(Vector2(root.x + off_x, chest_y + 7.5), Vector2(root.x + 8.0 + off_x, chest_y + 3.0), COL_SKIN_DARK, 2.0, false)
			draw_line(Vector2(root.x + off_x, chest_y + 2.0), Vector2(root.x + off_x, waist_y), COL_SKIN_DARK, 1.8, false)
			draw_line(Vector2(root.x - 6.0 + off_x, chest_y + 4.5), Vector2(root.x + 6.0 + off_x, chest_y + 4.5), COL_SKIN_HI, 2.0, false)
			draw_line(Vector2(root.x - 7.0 + off_x, chest_y + 2.0), Vector2(root.x + 7.0 + off_x, chest_y + 2.0), COL_WAR_ASH, 1.6, false)
	else:
		if is_pure_rear:
			# Rear view: Central spine groove & symmetrical latissimus dorsi
			draw_line(Vector2(root.x, chest_y - 2.0), Vector2(root.x, root.y - 19.0), COL_SKIN_DARK, 1.8, false)
			draw_line(Vector2(root.x - 7.0, chest_y + 3.0), Vector2(root.x, chest_y + 9.0), COL_SKIN_DARK, 2.0, false)
			draw_line(Vector2(root.x + 7.0, chest_y + 3.0), Vector2(root.x, chest_y + 9.0), COL_SKIN_DARK, 2.0, false)
			draw_line(Vector2(root.x - 6.0, chest_y + 4.5), Vector2(root.x - 1.0, chest_y + 9.0), COL_SKIN_BASE, 1.6, false)
			draw_line(Vector2(root.x + 6.0, chest_y + 4.5), Vector2(root.x + 1.0, chest_y + 9.0), COL_SKIN_BASE, 1.6, false)
		else:
			# 3/4 Rear View (NW / NE)
			var off_x = dir_sign_x * 3.0
			draw_line(Vector2(root.x + off_x, chest_y - 2.0), Vector2(root.x + off_x, root.y - 19.0), COL_SKIN_DARK, 1.8, false)
			draw_line(Vector2(root.x - 6.0 + off_x, chest_y + 3.0), Vector2(root.x + off_x, chest_y + 9.0), COL_SKIN_DARK, 2.0, false)
			draw_line(Vector2(root.x + 6.0 + off_x, chest_y + 3.0), Vector2(root.x + off_x, chest_y + 9.0), COL_SKIN_DARK, 2.0, false)

func _draw_spiked_pauldron_chains(pos: Vector2, out_dir: Vector2, is_profile: bool = false) -> void:
	var r_p = 5.8 if is_profile else 7.2
	draw_circle(pos, r_p, COL_IRON_DARK)
	draw_circle(pos, r_p - 1.0, COL_IRON_MID)
	draw_circle(pos - Vector2(1.2 * out_dir.x, 1.2), r_p * 0.65, COL_IRON_HI)
	draw_circle(pos - Vector2(1.8 * out_dir.x, 1.8), 1.8, COL_IRON_SPEC)

	# Twin Iron Spikes pointing along out_dir
	var sp1 = pos + (out_dir * (r_p + 1.5)) + Vector2(0.0, -4.5)
	var sp2 = pos + (out_dir * (r_p + 2.5)) + Vector2(0.0, 2.0)
	draw_line(pos, sp1, COL_IRON_SPEC, 2.4, false)
	draw_line(pos, sp2, COL_IRON_HI, 2.4, false)

	# Hanging chain links
	for c in range(2):
		var cy = pos.y + r_p + 1.0 + (float(c) * 2.6)
		var cx = pos.x + (out_dir.x * 1.5) + (sin(idle_time * 4.0 + c) * 0.6)
		draw_circle(Vector2(cx, cy), 1.1, COL_IRON_MID)
		draw_circle(Vector2(cx, cy), 0.5, COL_IRON_HI)

# --- TWO-HANDED CLEAVER & ARTICULATED MUSCULAR ARMS (IK) ---
func _draw_two_handed_cleaver_and_arms(_root: Vector2, _dir_sign_x: float, _is_rear: bool, is_profile: bool = false) -> void:
	# Determine depth sorting between Left and Right arms
	var left_in_front = shoulder_l_pos.y >= shoulder_r_pos.y

	# Calculate pauldron spike normal
	var g_vecs = _get_ground_vectors(current_dir)
	var tw_right: Vector2 = g_vecs["right"].rotated(body_twist)
	var pauldron_out_g = -tw_right # Outward from left shoulder
	var pauldron_out_screen = Vector2(pauldron_out_g.x, pauldron_out_g.y * 0.5).normalized()
	if pauldron_out_screen == Vector2.ZERO:
		pauldron_out_screen = Vector2.RIGHT

	if left_in_front:
		# Far Arm (Right arm, grasps lead hand)
		_draw_single_muscular_arm(shoulder_r_pos, hand_lead_pos, 1.0, true, true)

		# Massive Cleaver Blade, Crossguard & Wrapped Shaft
		_draw_cleaver_blade_and_hilt()

		# Near Arm (Left arm, grasps off hand)
		_draw_single_muscular_arm(shoulder_l_pos, hand_off_pos, -1.0, false, false)

		# Spiked Pauldron on Left Shoulder (in foreground)
		_draw_spiked_pauldron_chains(shoulder_l_pos, pauldron_out_screen, is_profile)
	else:
		# Far Arm (Left arm, grasps off hand)
		_draw_single_muscular_arm(shoulder_l_pos, hand_off_pos, -1.0, false, true)

		# Spiked Pauldron on Left Shoulder (in background)
		_draw_spiked_pauldron_chains(shoulder_l_pos, pauldron_out_screen, is_profile)

		# Massive Cleaver Blade, Crossguard & Wrapped Shaft
		_draw_cleaver_blade_and_hilt()

		# Near Arm (Right arm, grasps lead hand)
		_draw_single_muscular_arm(shoulder_r_pos, hand_lead_pos, 1.0, true, false)

func _draw_single_muscular_arm(shoulder: Vector2, hand: Vector2, side_dir: float, is_lead: bool, is_far: bool) -> void:
	var arm_vec = hand - shoulder
	var arm_dist = arm_vec.length()

	var elbow_mid = (shoulder + hand) * 0.5
	var perp = Vector2(-arm_vec.y, arm_vec.x).normalized()
	if perp == Vector2.ZERO:
		perp = Vector2.DOWN

	var elbow_bend = 4.5 * side_dir
	var elbow = elbow_mid + (perp * elbow_bend) + Vector2(0.0, 2.5)

	if arm_dist > 28.0:
		elbow = shoulder + (arm_vec * 0.5)

	var col_dark = COL_SKIN_DARK
	var col_base = COL_SKIN_DARK if is_far else COL_SKIN_BASE
	var col_hi   = COL_SKIN_BASE if is_far else COL_SKIN_HI

	# Bicep & Tricep (Upper Arm)
	draw_line(shoulder, elbow, col_dark, 8.5, false)
	draw_line(shoulder, elbow, col_base, 6.2, false)
	draw_line(shoulder, elbow, col_hi, 2.4, false)

	# Forearm (Lower Arm)
	draw_line(elbow, hand, col_dark, 7.8, false)
	draw_line(elbow, hand, col_base, 5.8, false)
	draw_line(elbow, hand, col_hi, 2.2, false)

	# Spiked Iron Wrist Bracer
	var bracer_dir = (hand - elbow).normalized()
	var bracer_pos = hand - (bracer_dir * 3.5)
	draw_circle(bracer_pos, 4.2, COL_IRON_DARK)
	draw_circle(bracer_pos, 3.2, COL_IRON_MID if not is_far else COL_IRON_DARK)
	if not is_far:
		draw_circle(bracer_pos, 1.5, COL_IRON_SPEC)

	# Heavy Green Orc Fist gripping the shaft
	draw_circle(hand, 3.8, col_dark)
	draw_circle(hand, 3.0, col_base)
	draw_circle(hand - Vector2(0.6, 0.6), 1.4, col_hi)
	if is_lead and not is_far:
		draw_circle(hand + Vector2(side_dir * 1.5, -1.0), 1.1, COL_SKIN_SPEC)

func _draw_cleaver_blade_and_hilt() -> void:
	var b_dir = cleaver_blade_dir
	var b_perp = Vector2(-b_dir.y, b_dir.x) # Normal perpendicular to blade length

	var pommel_pt = cleaver_pommel_pos
	var guard_pt  = cleaver_guard_pos
	var tip_pt    = cleaver_tip_pos

	# 1. Two-Handed Leather Cord Wrapped Shaft
	draw_line(pommel_pt, guard_pt, COL_LEATHER_DK, 5.2, false)
	draw_line(pommel_pt, guard_pt, COL_LEATHER_MID, 2.6, false)
	for w in range(5):
		var wp = pommel_pt + b_dir * (float(w) * 3.8)
		draw_line(wp - b_perp * 2.2, wp + b_perp * 2.2, COL_LEATHER_MID, 1.2, false)

	# Brass Skull Pommel & Chain Link
	draw_circle(pommel_pt, 3.8, COL_IRON_DARK)
	draw_circle(pommel_pt, 2.8, COL_BRONZE_MID)
	draw_circle(pommel_pt - Vector2(0.8, 0.8), 1.2, COL_BRONZE_HI)
	draw_circle(pommel_pt - b_dir * 3.2, 1.4, COL_IRON_MID)

	# Spiked Iron Crossguard
	draw_line(guard_pt - b_perp * 7.5, guard_pt + b_perp * 7.5, COL_IRON_DARK, 4.5, false)
	draw_line(guard_pt - b_perp * 7.0, guard_pt + b_perp * 7.0, COL_IRON_HI, 1.8, false)
	draw_circle(guard_pt - b_perp * 7.0, 1.5, COL_IRON_SPEC)
	draw_circle(guard_pt + b_perp * 7.0, 1.5, COL_IRON_SPEC)

	# 2. Massive Flared Cleaver Blade (Pitted Blackened Iron)
	var blade_w_base = 13.0
	var blade_w_tip  = 21.0

	var c_cut_base = guard_pt + b_perp * (blade_w_base * 0.55)
	var c_cut_tip  = tip_pt + b_perp * (blade_w_tip * 0.75)
	var c_back_tip = tip_pt - b_perp * (blade_w_tip * 0.25)
	var c_back_base= guard_pt - b_perp * (blade_w_base * 0.45)

	var blade_poly = PackedVector2Array([c_cut_base, c_cut_tip, c_back_tip, c_back_base])
	draw_colored_polygon(blade_poly, COL_IRON_DARK)

	# Inner Beveled Body
	var inner_poly = PackedVector2Array([
		c_cut_base + b_dir * 2.0 - b_perp * 1.5,
		c_cut_tip - b_dir * 2.0 - b_perp * 2.2,
		c_back_tip - b_dir * 2.0 + b_perp * 1.5,
		c_back_base + b_dir * 2.0 + b_perp * 1.5
	])
	draw_colored_polygon(inner_poly, COL_IRON_MID)

	# Heavy Reinforced Spine
	draw_line(c_back_base, c_back_tip, COL_IRON_DARK, 4.2, false)
	draw_line(c_back_base, c_back_tip, COL_IRON_HI, 1.6, false)

	# Razor Ground Cutting Edge
	draw_line(c_cut_base, c_cut_tip, COL_IRON_SPEC, 2.8, false)

	# Serrated Battle Notches along the cutting edge
	var n1 = lerp(c_cut_base, c_cut_tip, 0.35)
	var n2 = lerp(c_cut_base, c_cut_tip, 0.70)
	draw_line(n1, n1 - b_perp * 4.2 + b_dir * 1.5, COL_IRON_DARK, 2.0, false)
	draw_line(n2, n2 - b_perp * 3.5 + b_dir * 1.5, COL_IRON_DARK, 2.0, false)

	# Coagulated Blood Runic Fuller
	var f_start = guard_pt + b_dir * 5.0
	var f_end   = tip_pt - b_dir * 7.0
	draw_line(f_start, f_end, COL_WAR_BLOOD, 3.2, false)
	draw_line(f_start, f_end, Color(1.0, 0.25, 0.15, 0.92), 1.2, false)

# --- SWEPT AERODYNAMIC CLEAVER WIND SHOCKWAVE TRAIL ---
func _draw_swept_cleaver_trail() -> void:
	var trail_alpha = clampf((1.0 - trail_progress) * 0.95, 0.0, 1.0)
	if trail_tip_history.size() < 2:
		return

	var pts_tip = PackedVector2Array()
	var pts_guard = PackedVector2Array()

	for pt in trail_tip_history:
		pts_tip.append(pt)
	for pt in trail_guard_history:
		pts_guard.append(pt)

	var ribbon = PackedVector2Array()
	for p in pts_tip:
		ribbon.append(p)
	for i in range(pts_guard.size() - 1, -1, -1):
		ribbon.append(pts_guard[i])

	if ribbon.size() >= 3:
		draw_colored_polygon(ribbon, Color(0.75, 0.12, 0.08, trail_alpha * 0.40))

	draw_polyline(pts_tip, Color(0.85, 0.16, 0.10, trail_alpha * 0.78), 8.5, false)
	draw_polyline(pts_tip, Color(1.0, 0.58, 0.18, trail_alpha * 0.94), 4.4, false)
	draw_polyline(pts_tip, Color(1.0, 1.0, 1.0, trail_alpha), 1.8, false)

# --- HORNED WAR-MASK & SAVAGE TUSKED HEAD ---
func _draw_horned_head(root: Vector2, is_rear: bool, is_profile: bool, is_pure_front: bool, is_pure_rear: bool, dir_sign_x: float) -> void:
	var head_cen = Vector2(root.x + (sin(body_twist) * 3.5), root.y - 44.5)

	# Neck (Trapezius)
	draw_line(Vector2(root.x, root.y - 33.0), head_cen, COL_SKIN_DARK, 12.0, false)

	# -------------------------------------------------------------
	# CASE 1: PURE PROFILE (Dir8.W or Dir8.E)
	# -------------------------------------------------------------
	if is_profile:
		var side = dir_sign_x if dir_sign_x != 0.0 else -1.0 # -1 for W, +1 for E
		var p_cen = head_cen + Vector2(side * 2.5, 0.0)

		# Skull Base (Occiput on -side, Brow on +side)
		var cran_prof = PackedVector2Array([
			p_cen + Vector2(-side * 5.0, -9.0),
			p_cen + Vector2(side * 3.0, -9.0),
			p_cen + Vector2(side * 7.5, -4.0),
			p_cen + Vector2(side * 7.0, 4.0),
			p_cen + Vector2(-side * 4.0, 6.0),
			p_cen + Vector2(-side * 6.5, 0.0)
		])
		draw_colored_polygon(cran_prof, COL_SKIN_BASE)

		# Forged Sallet Helmet Profile
		var helm_prof = PackedVector2Array([
			p_cen + Vector2(-side * 6.0, -10.5),
			p_cen + Vector2(side * 3.5, -10.5),
			p_cen + Vector2(side * 8.5, -5.0),
			p_cen + Vector2(side * 9.0, -1.0),
			p_cen + Vector2(side * 4.0, -1.0),
			p_cen + Vector2(-side * 6.5, 1.5)
		])
		draw_colored_polygon(helm_prof, COL_IRON_DARK)
		draw_polyline(helm_prof, COL_IRON_HI, 1.2, true)

		# Near Horn (prominently sweeping forward-upward like a savage warhorn)
		var h_near_b = p_cen + Vector2(side * 1.0, -8.0)
		var h_near_m = h_near_b + Vector2(side * 5.5, -5.5)
		var h_near_t = h_near_m + Vector2(side * 3.5, -8.5)
		draw_line(h_near_b, h_near_m, COL_IRON_DARK, 4.5, false)
		draw_line(h_near_m, h_near_t, COL_TUSK_DARK, 3.0, false)
		draw_line(h_near_m, h_near_t, COL_TUSK_IVORY, 1.4, false)
		draw_circle(h_near_m, 2.0, COL_BRONZE_MID)

		# Far Horn (partially occluded behind cranium, peeking over forward-up)
		var h_far_b = p_cen + Vector2(-side * 2.0, -9.5)
		var h_far_t = h_far_b + Vector2(side * 3.0, -6.5)
		draw_line(h_far_b, h_far_t, COL_IRON_DARK, 2.8, false)
		draw_line(h_far_b, h_far_t, COL_TUSK_DARK, 1.6, false)

		# Recessed Horizontal Visor Slit & Burning Red Eye
		var eye_pt = p_cen + Vector2(side * 6.5, -2.0)
		draw_line(eye_pt - Vector2(side * 3.5, 0.0), eye_pt + Vector2(side * 2.0, 0.0), COL_IRON_DARK, 3.2, false)
		draw_circle(eye_pt, 1.9, COL_EYE_RED)
		draw_circle(eye_pt, 0.7, Color.WHITE)

		# Prognathic Protruding Lower Jaw & Single Massive Upward Tusk
		var jaw_pt = p_cen + Vector2(side * 7.5, 4.5)
		var jaw_poly = PackedVector2Array([
			jaw_pt + Vector2(-side * 4.5, 0.0),
			jaw_pt + Vector2(side * 2.5, -1.0),
			jaw_pt + Vector2(side * 1.5, 3.5),
			jaw_pt + Vector2(-side * 4.0, 3.0)
		])
		draw_colored_polygon(jaw_poly, COL_SKIN_DARK)

		var tusk_b = jaw_pt + Vector2(side * 2.0, 1.0)
		var tusk_t = tusk_b + Vector2(side * 3.8, -9.5)
		draw_line(tusk_b, tusk_t, COL_TUSK_DARK, 3.4, false)
		draw_line(tusk_b, tusk_t, COL_TUSK_IVORY, 1.8, false)
		draw_circle(tusk_t, 0.8, Color.WHITE)
		return

	# -------------------------------------------------------------
	# CASE 2: PURE FRONT (Dir8.S)
	# -------------------------------------------------------------
	if is_pure_front:
		var cran_w = 10.0
		var cran_poly = PackedVector2Array([
			head_cen + Vector2(-cran_w, -9.0),
			head_cen + Vector2(cran_w, -9.0),
			head_cen + Vector2(cran_w + 1.2, 1.5),
			head_cen + Vector2(cran_w * 0.65, 8.0),
			head_cen + Vector2(-cran_w * 0.65, 8.0),
			head_cen + Vector2(-cran_w - 1.2, 1.5)
		])
		draw_colored_polygon(cran_poly, COL_SKIN_BASE)

		var helm_poly = PackedVector2Array([
			head_cen + Vector2(-cran_w - 1.0, -10.5),
			head_cen + Vector2(cran_w + 1.0, -10.5),
			head_cen + Vector2(cran_w + 1.5, -2.5),
			head_cen + Vector2(0.0, -1.0),
			head_cen + Vector2(-cran_w - 1.5, -2.5)
		])
		draw_colored_polygon(helm_poly, COL_IRON_DARK)
		draw_polyline(helm_poly, COL_IRON_HI, 1.2, true)

		# Symmetrical horns
		var horn_l_base = head_cen + Vector2(-cran_w, -8.0)
		var horn_l_mid  = horn_l_base + Vector2(-6.5, -5.0)
		var horn_l_tip  = horn_l_mid + Vector2(-4.0, -8.5)
		var horn_r_base = head_cen + Vector2(cran_w, -8.0)
		var horn_r_mid  = horn_r_base + Vector2(6.5, -5.0)
		var horn_r_tip  = horn_r_mid + Vector2(4.0, -8.5)

		draw_line(horn_l_base, horn_l_mid, COL_IRON_DARK, 4.2, false)
		draw_line(horn_l_mid, horn_l_tip, COL_TUSK_DARK, 2.8, false)
		draw_line(horn_l_mid, horn_l_tip, COL_TUSK_IVORY, 1.2, false)
		draw_circle(horn_l_mid, 2.0, COL_BRONZE_MID)

		draw_line(horn_r_base, horn_r_mid, COL_IRON_DARK, 4.2, false)
		draw_line(horn_r_mid, horn_r_tip, COL_TUSK_DARK, 2.8, false)
		draw_line(horn_r_mid, horn_r_tip, COL_TUSK_IVORY, 1.2, false)
		draw_circle(horn_r_mid, 2.0, COL_BRONZE_MID)

		# Twin glowing eyes
		var eye_y = head_cen.y - 1.8
		var ep_l = Vector2(head_cen.x - 3.8, eye_y)
		var ep_r = Vector2(head_cen.x + 3.8, eye_y)
		draw_line(ep_l - Vector2(2.0, 0.0), ep_r + Vector2(2.0, 0.0), COL_IRON_DARK, 3.5, false)
		draw_circle(ep_l, 1.8, COL_EYE_RED)
		draw_circle(ep_l, 0.7, Color.WHITE)
		draw_circle(ep_r, 1.8, COL_EYE_RED)
		draw_circle(ep_r, 0.7, Color.WHITE)

		# Symmetrical jaw and twin tusks
		var jaw_y = head_cen.y + 5.0
		var jaw_poly = PackedVector2Array([
			Vector2(head_cen.x - 6.5, jaw_y),
			Vector2(head_cen.x + 6.5, jaw_y),
			Vector2(head_cen.x + 4.5, jaw_y + 4.0),
			Vector2(head_cen.x - 4.5, jaw_y + 4.0)
		])
		draw_colored_polygon(jaw_poly, COL_SKIN_DARK)

		var tb_l = Vector2(head_cen.x - 5.0, jaw_y + 2.0)
		var tt_l = tb_l + Vector2(-3.2, -7.5)
		var tb_r = Vector2(head_cen.x + 5.0, jaw_y + 2.0)
		var tt_r = tb_r + Vector2(3.2, -7.5)
		draw_line(tb_l, tt_l, COL_TUSK_DARK, 3.0, false)
		draw_line(tb_l, tt_l, COL_TUSK_IVORY, 1.6, false)
		draw_circle(tt_l, 0.7, Color.WHITE)
		draw_line(tb_r, tt_r, COL_TUSK_DARK, 3.0, false)
		draw_line(tb_r, tt_r, COL_TUSK_IVORY, 1.6, false)
		draw_circle(tt_r, 0.7, Color.WHITE)
		return

	# -------------------------------------------------------------
	# CASE 3: PURE REAR (Dir8.N)
	# -------------------------------------------------------------
	if is_pure_rear:
		var cran_w = 10.0
		var cran_poly = PackedVector2Array([
			head_cen + Vector2(-cran_w, -9.0),
			head_cen + Vector2(cran_w, -9.0),
			head_cen + Vector2(cran_w + 1.2, 1.5),
			head_cen + Vector2(cran_w * 0.65, 8.0),
			head_cen + Vector2(-cran_w * 0.65, 8.0),
			head_cen + Vector2(-cran_w - 1.2, 1.5)
		])
		draw_colored_polygon(cran_poly, COL_SKIN_DARK)

		var helm_poly = PackedVector2Array([
			head_cen + Vector2(-cran_w - 1.0, -10.5),
			head_cen + Vector2(cran_w + 1.0, -10.5),
			head_cen + Vector2(cran_w + 1.5, 4.0),
			head_cen + Vector2(-cran_w - 1.5, 4.0)
		])
		draw_colored_polygon(helm_poly, COL_IRON_DARK)
		draw_polyline(helm_poly, COL_IRON_HI, 1.2, true)

		# Central vertical bronze spine crest
		draw_line(head_cen + Vector2(0.0, -10.5), head_cen + Vector2(0.0, 5.0), COL_BRONZE_MID, 2.8, false)
		draw_line(head_cen + Vector2(0.0, -10.5), head_cen + Vector2(0.0, 5.0), COL_BRONZE_HI, 1.2, false)

		# Symmetrical horns curving out-up from rear
		var horn_l_base = head_cen + Vector2(-cran_w, -8.0)
		var horn_l_mid  = horn_l_base + Vector2(-6.5, -5.0)
		var horn_l_tip  = horn_l_mid + Vector2(-4.0, -8.5)
		var horn_r_base = head_cen + Vector2(cran_w, -8.0)
		var horn_r_mid  = horn_r_base + Vector2(6.5, -5.0)
		var horn_r_tip  = horn_r_mid + Vector2(4.0, -8.5)

		draw_line(horn_l_base, horn_l_mid, COL_IRON_DARK, 4.2, false)
		draw_line(horn_l_mid, horn_l_tip, COL_TUSK_DARK, 2.8, false)
		draw_line(horn_l_mid, horn_l_tip, COL_TUSK_IVORY, 1.2, false)
		draw_circle(horn_l_mid, 2.0, COL_BRONZE_MID)

		draw_line(horn_r_base, horn_r_mid, COL_IRON_DARK, 4.2, false)
		draw_line(horn_r_mid, horn_r_tip, COL_TUSK_DARK, 2.8, false)
		draw_line(horn_r_mid, horn_r_tip, COL_TUSK_IVORY, 1.2, false)
		draw_circle(horn_r_mid, 2.0, COL_BRONZE_MID)

		# Lobster-tail neck lames
		draw_line(head_cen + Vector2(-6.0, 6.0), head_cen + Vector2(6.0, 6.0), COL_IRON_MID, 1.8, false)
		draw_line(head_cen + Vector2(-4.5, 8.5), head_cen + Vector2(4.5, 8.5), COL_IRON_MID, 1.6, false)
		return

	# -------------------------------------------------------------
	# CASE 4: 3/4 REAR (Dir8.NW or Dir8.NE)
	# -------------------------------------------------------------
	if is_rear:
		var side = dir_sign_x if dir_sign_x != 0.0 else -1.0 # -1 for NW
		var cran_w = 9.2
		var cran_poly = PackedVector2Array([
			head_cen + Vector2(-cran_w + side * 1.5, -9.0),
			head_cen + Vector2(cran_w + side * 1.5, -9.0),
			head_cen + Vector2(cran_w + 1.0 + side * 1.5, 2.0),
			head_cen + Vector2(cran_w * 0.6 + side * 1.5, 7.5),
			head_cen + Vector2(-cran_w * 0.6 + side * 1.5, 7.5),
			head_cen + Vector2(-cran_w - 1.0 + side * 1.5, 2.0)
		])
		draw_colored_polygon(cran_poly, COL_SKIN_DARK)

		var helm_poly = PackedVector2Array([
			head_cen + Vector2(-cran_w - 1.0 + side * 1.5, -10.5),
			head_cen + Vector2(cran_w + 1.0 + side * 1.5, -10.5),
			head_cen + Vector2(cran_w + 1.2 + side * 1.5, 4.0),
			head_cen + Vector2(-cran_w - 1.2 + side * 1.5, 4.0)
		])
		draw_colored_polygon(helm_poly, COL_IRON_DARK)
		draw_polyline(helm_poly, COL_IRON_HI, 1.2, true)

		# Rear horns
		var h_near_b = head_cen + Vector2(cran_w * side, -8.0)
		var h_near_m = h_near_b + Vector2(6.0 * side, -5.0)
		var h_near_t = h_near_m + Vector2(3.5 * side, -8.0)
		var h_far_b = head_cen + Vector2(-cran_w * 0.7 * side, -8.5)
		var h_far_m = h_far_b + Vector2(-4.0 * side, -4.5)
		var h_far_t = h_far_m + Vector2(-2.5 * side, -7.5)

		draw_line(h_far_b, h_far_m, COL_IRON_DARK, 3.6, false)
		draw_line(h_far_m, h_far_t, COL_TUSK_DARK, 2.2, false)
		draw_line(h_far_m, h_far_t, COL_TUSK_IVORY, 1.0, false)

		draw_line(h_near_b, h_near_m, COL_IRON_DARK, 4.5, false)
		draw_line(h_near_m, h_near_t, COL_TUSK_DARK, 3.0, false)
		draw_line(h_near_m, h_near_t, COL_TUSK_IVORY, 1.4, false)
		draw_circle(h_near_m, 2.2, COL_BRONZE_MID)
		return

	# -------------------------------------------------------------
	# CASE 5: 3/4 FRONT (Dir8.SW or Dir8.SE)
	# -------------------------------------------------------------
	var side = dir_sign_x if dir_sign_x != 0.0 else -1.0 # -1 for SW
	var cran_w = 9.5
	var cran_poly = PackedVector2Array([
		head_cen + Vector2(-cran_w + side * 1.5, -9.0),
		head_cen + Vector2(cran_w + side * 1.5, -9.0),
		head_cen + Vector2(cran_w + 1.2 + side * 1.5, 1.5),
		head_cen + Vector2(cran_w * 0.65 + side * 1.5, 8.0),
		head_cen + Vector2(-cran_w * 0.65 + side * 1.5, 8.0),
		head_cen + Vector2(-cran_w - 1.2 + side * 1.5, 1.5)
	])
	draw_colored_polygon(cran_poly, COL_SKIN_BASE)

	var helm_poly = PackedVector2Array([
		head_cen + Vector2(-cran_w - 1.0 + side * 1.5, -10.5),
		head_cen + Vector2(cran_w + 1.0 + side * 1.5, -10.5),
		head_cen + Vector2(cran_w + 1.5 + side * 1.5, -2.5),
		head_cen + Vector2(side * 1.5, -1.0),
		head_cen + Vector2(-cran_w - 1.5 + side * 1.5, -2.5)
	])
	draw_colored_polygon(helm_poly, COL_IRON_DARK)
	draw_polyline(helm_poly, COL_IRON_HI, 1.2, true)

	# 3/4 Horns: Near horn sweeps forward-left and up; Far horn foreshortened
	var h_near_b = head_cen + Vector2(cran_w * side, -8.0)
	var h_near_m = h_near_b + Vector2(7.0 * side, -5.5)
	var h_near_t = h_near_m + Vector2(4.0 * side, -9.0)

	var h_far_b = head_cen + Vector2(-cran_w * 0.65 * side, -8.5)
	var h_far_m = h_far_b + Vector2(-4.0 * side, -4.5)
	var h_far_t = h_far_m + Vector2(-2.5 * side, -7.5)

	draw_line(h_far_b, h_far_m, COL_IRON_DARK, 3.6, false)
	draw_line(h_far_m, h_far_t, COL_TUSK_DARK, 2.2, false)
	draw_line(h_far_m, h_far_t, COL_TUSK_IVORY, 1.0, false)

	draw_line(h_near_b, h_near_m, COL_IRON_DARK, 4.5, false)
	draw_line(h_near_m, h_near_t, COL_TUSK_DARK, 3.0, false)
	draw_line(h_near_m, h_near_t, COL_TUSK_IVORY, 1.4, false)
	draw_circle(h_near_m, 2.2, COL_BRONZE_MID)

	# 3/4 Eyes (Near eye larger, far eye smaller)
	var eye_y = head_cen.y - 1.8
	var ep_near = Vector2(head_cen.x + (4.5 * side), eye_y)
	var ep_far  = Vector2(head_cen.x - (1.5 * side), eye_y)
	draw_line(ep_far - Vector2(2.0 * side, 0.0), ep_near + Vector2(2.0 * side, 0.0), COL_IRON_DARK, 3.5, false)
	draw_circle(ep_near, 1.9, COL_EYE_RED)
	draw_circle(ep_near, 0.7, Color.WHITE)
	draw_circle(ep_far, 1.3, COL_EYE_RED)
	draw_circle(ep_far, 0.5, Color.WHITE)

	# 3/4 Jaw and Tusks
	var jaw_y = head_cen.y + 5.0
	var tb_near = Vector2(head_cen.x + (4.5 * side), jaw_y + 2.0)
	var tt_near = tb_near + Vector2(3.5 * side, -7.5)
	var tb_far  = Vector2(head_cen.x - (2.0 * side), jaw_y + 2.0)
	var tt_far  = tb_far + Vector2(1.5 * side, -6.0)

	draw_line(tb_far, tt_far, COL_TUSK_DARK, 2.4, false)
	draw_line(tb_far, tt_far, COL_TUSK_IVORY, 1.2, false)
	draw_line(tb_near, tt_near, COL_TUSK_DARK, 3.2, false)
	draw_line(tb_near, tt_near, COL_TUSK_IVORY, 1.8, false)
	draw_circle(tt_near, 0.7, Color.WHITE)

func _get_screen_dir_vector(dir: Dir8) -> Vector2:
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

func _get_dir_sign_x(dir: Dir8) -> float:
	match dir:
		Dir8.E, Dir8.SE, Dir8.NE: return 1.0
		Dir8.W, Dir8.SW, Dir8.NW: return -1.0
		_: return 0.0
