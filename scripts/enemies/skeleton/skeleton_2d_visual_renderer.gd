class_name Skeleton2DVisualRenderer
extends Node2D

## 2.5D High-Fidelity Necrotic Skeleton Visual Renderer (True 3D Illusion & Masterclass Pixel-Art)
## Supports both Skeleton Swordsman and Skeleton Archer:
## - Full 8-Directional Isometric 2:1 Projections (E, SE, S, SW, W, NW, N, NE)
## - True 3D Volumetric Skeletal Anatomy:
##   * Anatomical Cranium with Suture Lines, Brow Ridge, Zygomatic Arches, and Ancient Tarnished Warlord Circlet
##   * Deep 3D Hollow Orbital Sockets with Twin Pulsing Soulfire Emerald Eyes & White-Hot Cores
##   * Articulated Maxilla & Mandible with Delineated Upper/Lower Jagged Teeth & Dark Oral Cavity
##   * Full Cervical, Thoracic & Lumbar Spine with Individual Vertebral Bodies & Discs
##   * True 3D Cylindrical Ribcage (Interior Shaded Back Ribs behind spine + Curved Front Ribs wrapping to Sternum)
##   * Pulsing Necrotic Soul Core floating inside the dark thoracic cavity
##   * Detailed Pelvic Girdle (Iliac Crests, Sacrum with foramina, Pubic Arch) with Tattered Rags
##   * Dual-Bone Limbs (Femur with Trochanter, Knee Poleyn, Tibia + Fibula with Interosseous Space)
##   * Articulated Skeletal Feet for All 8 Directions with 4 Delineated Clawed Toes anchored at y=0
## - Dynamic Multi-Fold Grave Shroud with Wind Simulation & Corroded Clasps
## - Swordsman: Rusted Jagged Scimitar/Broadsword with Runic Fullers, Articulated Gripping Claws,
##   Battered Heavy Oak-and-Iron Buckler with Spiked Umbo & Interior Straps,
##   and Solid 3-Tone Aerodynamic Necrotic Blade Wind Trails for Combo 0 & Combo 1
## - Archer: Curved Horn & Yew Recurve Bow, Bone Bandolier Quiver with Protruding Fletched Arrows,
##   and Dynamic Bowstring Draw Animation with Barbed Broadhead Arrow

enum Type { SWORDSMAN, ARCHER, MAGE }
enum Dir8 { E = 0, SE = 1, S = 2, SW = 3, W = 4, NW = 5, N = 6, NE = 7 }

@export var skeleton_type: Type = Type.SWORDSMAN

var current_dir: Dir8 = Dir8.S
var is_moving: bool = false
var speed_ratio: float = 0.0
var is_attacking: bool = false
var attack_combo: int = 0
var attack_timer: float = 0.0
var current_attack_duration: float = 0.35
var is_aiming_bow: bool = false
var bow_draw_progress: float = 0.0

# Animation Timers & Phase
var walk_cycle: float = 0.0
var idle_timer: float = 0.0
var shroud_phase: float = 0.0
var attack_progress: float = 0.0
var current_move_vec: Vector2 = Vector2.ZERO

# Kinetic Body Parameters
var body_twist: float = 0.0
var body_lunge: Vector2 = Vector2.ZERO
var body_crouch: float = 0.0
var shroud_whip: Vector2 = Vector2.ZERO

# Equipment Transforms & Layering
var shield_pos: Vector2 = Vector2.ZERO
var shield_ang: float = 0.0
var shield_scale_x: float = 1.0
var shield_in_front: bool = true

var weapon_pos: Vector2 = Vector2.ZERO
var weapon_ang: float = 0.0
var blade_length: float = 26.0
var weapon_in_front: bool = true

# Trail Parameters for Slashes
var has_trail: bool = false
var trail_center: Vector2 = Vector2.ZERO
var trail_blade_ang: float = 0.0
var trail_sweep_dir: float = 1.0
var trail_span_angle: float = 0.0
var trail_r_hilt: float = 13.0
var trail_r_tip: float = 38.0
var trail_in_front: bool = true

# Master Palette (18 Tones: Aged Ivory, Deep Cavities, Soulfire Emerald, Tarnished Iron & Bronze)
const COL_BONE_SPEC  = Color(1.00, 0.98, 0.94)  # Specular ivory light
const COL_BONE_HI    = Color(0.92, 0.88, 0.78)  # Lit bone surface
const COL_BONE_BASE  = Color(0.78, 0.73, 0.62)  # Weathered ivory bone
const COL_BONE_MID   = Color(0.56, 0.50, 0.40)  # Shadowed bone
const COL_BONE_DARK  = Color(0.32, 0.26, 0.20)  # Bone crevices & sutures
const COL_VOID       = Color(0.06, 0.05, 0.05)  # Pitch black hollow sockets
const COL_SOUL_CORE  = Color(0.92, 1.00, 0.94)  # White-hot soul core
const COL_SOUL_MID   = Color(0.30, 0.96, 0.45, 0.95) # Vibrant emerald soulfire
const COL_SOUL_GLOW  = Color(0.12, 0.75, 0.30, 0.40) # Outer soul aura
const COL_CROWN_GOLD = Color(0.76, 0.60, 0.22)  # Tarnished burial circlet
const COL_CROWN_DARK = Color(0.35, 0.25, 0.12)
const COL_SHROUD_DARK= Color(0.13, 0.11, 0.14)  # Ragged burial shroud shadow
const COL_SHROUD_MID = Color(0.24, 0.19, 0.23)  # Weathered shroud weave
const COL_SHROUD_HI  = Color(0.40, 0.34, 0.38)  # Frayed thread edge
const COL_RUST_IRON  = Color(0.42, 0.34, 0.30)  # Pitted rusted steel
const COL_RUST_EDGE  = Color(0.76, 0.72, 0.65)  # Sharpened jagged steel
const COL_WOOD_DARK  = Color(0.20, 0.14, 0.09)  # Decayed ash wood
const COL_WOOD_MID   = Color(0.40, 0.26, 0.16)  # Carved stave/buckler wood
const COL_WOOD_HI    = Color(0.58, 0.38, 0.24)  # Scratched wood grain
const COL_TRAIL_CORE = Color(0.55, 1.00, 0.70)  # Soulfire crescent body
const COL_TRAIL_SHADE= Color(0.12, 0.32, 0.20)  # Dark shadow crescent edge

func _ready() -> void:
	z_as_relative = true
	z_index = 1

func update_state(
	delta: float,
	dir: int,
	moving: bool,
	speed_rat: float,
	attacking: bool,
	combo: int,
	att_timer: float,
	att_duration: float = 0.35,
	move_vec: Vector2 = Vector2.ZERO,
	aiming_bow: bool = false,
	bow_draw: float = 0.0
) -> void:
	current_move_vec = move_vec
	current_dir = dir as Dir8
	is_moving = moving
	speed_ratio = speed_rat
	is_attacking = attacking
	attack_combo = combo
	attack_timer = att_timer
	current_attack_duration = maxf(att_duration, 0.01)
	is_aiming_bow = aiming_bow
	bow_draw_progress = bow_draw

	# Frequencies
	idle_timer += delta * 2.5
	if idle_timer > TAU * 100.0:
		idle_timer = 0.0

	var walk_freq = 9.0 + (speed_ratio * 4.5)
	if is_moving and not is_attacking and not is_aiming_bow:
		walk_cycle += delta * walk_freq
		if walk_cycle > TAU * 100.0:
			walk_cycle = 0.0
	else:
		walk_cycle = lerpf(walk_cycle, 0.0, delta * 12.0)

	var shroud_speed = 3.2 if not is_moving else (7.0 + speed_ratio * 5.5)
	shroud_phase += delta * shroud_speed
	if shroud_phase > TAU * 100.0:
		shroud_phase = 0.0

	# Full-body kinetic attack animation calculations
	if is_attacking and skeleton_type == Type.SWORDSMAN:
		attack_progress = clampf(1.0 - (attack_timer / current_attack_duration), 0.0, 1.0)
		_compute_swordsman_kinetics(attack_progress, attack_combo)
	elif is_aiming_bow and skeleton_type == Type.ARCHER:
		attack_progress = bow_draw_progress
		_compute_archer_kinetics(bow_draw_progress)
	elif is_aiming_bow and skeleton_type == Type.MAGE:
		attack_progress = bow_draw_progress
		_compute_mage_kinetics(bow_draw_progress)
	else:
		attack_progress = 0.0
		body_twist = move_toward(body_twist, 0.0, delta * 15.0)
		body_lunge = body_lunge.move_toward(Vector2.ZERO, delta * 28.0)
		body_crouch = move_toward(body_crouch, 0.0, delta * 15.0)
		shroud_whip = shroud_whip.move_toward(Vector2.ZERO, delta * 20.0)

	queue_redraw()

func _compute_swordsman_kinetics(t: float, combo: int) -> void:
	var aim_dir = _get_dir_vector(current_dir)

	match combo:
		0: # FOREHAND HORIZONTAL CLEAVE (Mirroring Dark Knight Hit 1)
			if t < 0.22:
				var p = t / 0.22
				var ease_p = p * p
				body_twist = lerpf(0.0, 0.44, ease_p)
				body_crouch = lerpf(0.0, 2.2, ease_p)
				body_lunge = -aim_dir * lerpf(0.0, 3.0, ease_p)
				shroud_whip = -aim_dir * lerpf(0.0, 4.2, ease_p)
			elif t < 0.62:
				var p = (t - 0.22) / 0.40
				var s = 1.0 - pow(1.0 - p, 3.0)
				body_twist = lerpf(0.44, -0.54, s)
				body_crouch = lerpf(2.2, 0.8, s)
				body_lunge = aim_dir * lerpf(-3.0, 9.2, s)
				shroud_whip = -aim_dir * lerpf(-4.2, 8.2, s)
			else:
				var p = (t - 0.62) / 0.38
				var r = 1.0 - (1.0 - p) * (1.0 - p)
				body_twist = lerpf(-0.54, 0.0, r)
				body_crouch = lerpf(0.8, 0.0, r)
				body_lunge = aim_dir * lerpf(9.2, 0.0, r)
				shroud_whip = shroud_whip.lerp(Vector2.ZERO, r)

		1: # RISING DIAGONAL BACKHAND SLASH (Mirroring Dark Knight Hit 2)
			if t < 0.20:
				var p = t / 0.20
				var ease_p = p * p
				body_twist = lerpf(0.0, -0.48, ease_p)
				body_crouch = lerpf(0.0, 3.5, ease_p)
				body_lunge = -aim_dir * lerpf(0.0, 2.2, ease_p)
				shroud_whip = Vector2(0.0, 3.2 * ease_p)
			elif t < 0.58:
				var p = (t - 0.20) / 0.38
				var s = 1.0 - pow(1.0 - p, 3.0)
				body_twist = lerpf(-0.48, 0.50, s)
				body_crouch = lerpf(3.5, -2.4, s)
				body_lunge = aim_dir * lerpf(-2.2, 8.4, s)
				shroud_whip = -aim_dir * lerpf(0.0, 7.2, s)
			else:
				var p = (t - 0.58) / 0.42
				var r = 1.0 - (1.0 - p) * (1.0 - p)
				body_twist = lerpf(0.50, 0.0, r)
				body_crouch = lerpf(-2.4, 0.0, r)
				body_lunge = aim_dir * lerpf(8.4, 0.0, r)
				shroud_whip = shroud_whip.lerp(Vector2.ZERO, r)

func _compute_archer_kinetics(draw_prog: float) -> void:
	var aim_dir = _get_dir_vector(current_dir)
	var tension = draw_prog * draw_prog
	body_twist = (0.32 if current_dir in [Dir8.E, Dir8.SE, Dir8.S, Dir8.NE] else -0.32) * tension
	body_crouch = 2.0 * tension
	body_lunge = -aim_dir * (3.2 * tension)
	shroud_whip = -aim_dir * (4.0 * tension) + (Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4)) if draw_prog > 0.85 else Vector2.ZERO)

func _compute_mage_kinetics(cast_prog: float) -> void:
	var aim_dir = _get_dir_vector(current_dir)
	var float_wave = sin(cast_prog * PI)
	body_twist = sin(cast_prog * PI * 2.0) * 0.18
	body_crouch = -3.2 * float_wave # Hover off ground
	if cast_prog > 0.72:
		var thrust = (cast_prog - 0.72) / 0.28
		var s = 1.0 - pow(1.0 - thrust, 2.5)
		body_lunge = aim_dir * (4.8 * s)
	else:
		body_lunge = -aim_dir * (1.5 * float_wave)
	shroud_whip = Vector2(sin(idle_timer * 7.0) * 3.5, 2.5 + float_wave * 2.0)

func _draw() -> void:
	# 1. Dual Ground Contact Shadow (Expanding with lunge, grounded at y=0)
	_draw_contact_shadow()

	# 2. Equipment Transforms & Depth Sorting
	_compute_equipment_transforms()

	var is_rear = (current_dir == Dir8.N or current_dir == Dir8.NE or current_dir == Dir8.NW)

	# 3. Background Weapon & Trail (Drawn behind body when facing away)
	if has_trail and not trail_in_front:
		_draw_blade_wind_trail()
	if not shield_in_front and skeleton_type == Type.SWORDSMAN:
		_draw_battered_buckler(shield_pos, shield_ang, shield_scale_x, true)
	if not weapon_in_front:
		_draw_weapon()

	# 4. Tattered Burial Shroud (Draped behind torso when facing front)
	if not is_rear:
		_draw_shroud()

	# 5. Articulated Skeletal Legs & 8-Directional Clawed Feet
	_draw_skeletal_legs(is_rear)

	# 6. Volumetric 3D Thoracic Cage, Spine & Pelvis
	_draw_volumetric_torso(is_rear)

	# 7. Shroud (Draped over back when facing rear)
	if is_rear:
		_draw_shroud()

	# 8. Anatomical Skull with Crown & Soulfire Eyes
	_draw_skull(is_rear)

	# 9. Foreground Weapon & Trail (In front of body)
	if has_trail and trail_in_front:
		_draw_blade_wind_trail()
	if shield_in_front and skeleton_type == Type.SWORDSMAN:
		_draw_battered_buckler(shield_pos, shield_ang, shield_scale_x, false)
	if weapon_in_front:
		_draw_weapon()

func _get_vertical_bob() -> float:
	if is_moving and not is_attacking and not is_aiming_bow:
		return (absf(sin(walk_cycle)) * 1.6 - 0.8) * speed_ratio
	return sin(idle_timer) * 0.38

# --- DUAL GROUND CONTACT SHADOW ---
func _draw_contact_shadow() -> void:
	var lunge_dist = body_lunge.length()
	var shadow_rx = 12.5 + (lunge_dist * 0.38) + (speed_ratio * 2.8)
	var shadow_ry = shadow_rx * 0.42
	var center = Vector2(body_lunge.x * 0.4, 0.0)

	# Outer soft ambient occlusion
	var outer_pts = PackedVector2Array()
	for i in range(16):
		var a = i * TAU / 16.0
		outer_pts.append(Vector2(roundf(cos(a) * shadow_rx), roundf(sin(a) * shadow_ry)) + center + Vector2(1, 1))
	draw_colored_polygon(outer_pts, Color(0.0, 0.0, 0.0, 0.35))

	# Inner dense contact shadow directly beneath feet
	var inner_pts = PackedVector2Array()
	var inner_rx = 8.5 + (lunge_dist * 0.28)
	var inner_ry = inner_rx * 0.40
	for i in range(16):
		var a = i * TAU / 16.0
		inner_pts.append(Vector2(roundf(cos(a) * inner_rx), roundf(sin(a) * inner_ry)) + center)
	draw_colored_polygon(inner_pts, Color(0.0, 0.0, 0.0, 0.65))

# --- DYNAMIC TATTERED GRAVE SHROUD ---
func _draw_shroud() -> void:
	var anchor_y = -30.0 + body_crouch + body_lunge.y
	var anchor_l = Vector2(-6.0 + body_lunge.x, anchor_y)
	var anchor_r = Vector2(6.0 + body_lunge.x, anchor_y)

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

	trail += shroud_whip
	var billow = speed_ratio * 7.0 + (body_lunge.length() * 0.75)
	var wave1 = sin(shroud_phase) * (2.2 + billow * 0.35)
	var wave2 = cos(shroud_phase * 1.4) * (1.8 + billow * 0.28)

	var hem_y = -9.0 + body_crouch + body_lunge.y
	var b_l   = Vector2(-9.0 + trail.x - wave1, hem_y + trail.y)
	var b_ml  = Vector2(-3.0 + trail.x + wave2 * 0.5, hem_y + trail.y + 1.2)
	var b_m   = Vector2(trail.x + wave2, hem_y + trail.y + 2.0)
	var b_mr  = Vector2(3.0 + trail.x - wave2 * 0.5, hem_y + trail.y + 1.2)
	var b_r   = Vector2(9.0 + trail.x + wave1, hem_y + trail.y)

	# 1. Dark backing shroud
	var shroud_poly = PackedVector2Array([anchor_l, anchor_r, b_r, b_mr, b_m, b_ml, b_l])
	draw_colored_polygon(shroud_poly, COL_SHROUD_DARK)

	# 2. Midtone weave folds
	var fold_poly = PackedVector2Array([
		Vector2(-2.2 + body_lunge.x, anchor_y + 1.5),
		Vector2(2.2 + body_lunge.x, anchor_y + 1.5),
		Vector2(b_mr.x, b_mr.y),
		Vector2(b_m.x, b_m.y + 0.5),
		Vector2(b_ml.x, b_ml.y)
	])
	draw_colored_polygon(fold_poly, COL_SHROUD_MID)

	# 3. Frayed edge highlights & ragged tear cuts
	draw_line(b_l, b_ml, COL_SHROUD_HI, 1.2, false)
	draw_line(b_ml, b_m, COL_SHROUD_HI, 1.2, false)
	draw_line(b_m, b_mr, COL_SHROUD_HI, 1.2, false)
	draw_line(b_mr, b_r, COL_SHROUD_HI, 1.2, false)

	# Jagged tear slits
	draw_line(b_ml + Vector2(1, -2), b_ml + Vector2(1, -6), COL_VOID, 1.0, false)
	draw_line(b_mr + Vector2(-1, -1), b_mr + Vector2(-1, -5), COL_VOID, 1.0, false)

	# Corroded ancient bronze fibula pin on shoulder
	var pin_pos = anchor_l + Vector2(2.0, 1.5)
	draw_circle(pin_pos, 1.6, COL_CROWN_GOLD)
	draw_circle(pin_pos, 0.8, COL_CROWN_DARK)

# --- SKELETAL LEGS & 8-WAY CLAWED TOES ---
func _draw_skeletal_legs(is_rear: bool) -> void:
	var base_l_hip = Vector2(-4.2, -15.5)
	var base_r_hip = Vector2(4.2, -15.5)
	var base_l_foot = Vector2(-4.2, 0.0)
	var base_r_foot = Vector2(4.2, 0.0)

	match current_dir:
		Dir8.S, Dir8.N:
			base_l_hip = Vector2(-4.2, -15.5); base_r_hip = Vector2(4.2, -15.5)
			base_l_foot = Vector2(-4.2, 0.0);  base_r_foot = Vector2(4.2, 0.0)
		Dir8.E:
			base_l_hip = Vector2(-1.5, -17.0); base_r_hip = Vector2(1.5, -14.0)
			base_l_foot = Vector2(-1.5, -1.2); base_r_foot = Vector2(1.5, 1.2)
		Dir8.W:
			base_r_hip = Vector2(1.5, -17.0);  base_l_hip = Vector2(-1.5, -14.0)
			base_r_foot = Vector2(1.5, -1.2);  base_l_foot = Vector2(-1.5, 1.2)
		Dir8.SE:
			base_l_hip = Vector2(-3.2, -16.5); base_r_hip = Vector2(3.8, -14.5)
			base_l_foot = Vector2(-3.2, -1.0); base_r_foot = Vector2(3.8, 1.0)
		Dir8.SW:
			base_r_hip = Vector2(3.2, -16.5);  base_l_hip = Vector2(-3.8, -14.5)
			base_r_foot = Vector2(3.2, -1.0);  base_l_foot = Vector2(-3.8, 1.0)
		Dir8.NE:
			base_l_hip = Vector2(-3.8, -14.5); base_r_hip = Vector2(3.2, -16.5)
			base_l_foot = Vector2(-3.8, 1.0);  base_r_foot = Vector2(3.2, -1.0)
		Dir8.NW:
			base_r_hip = Vector2(3.8, -14.5);  base_l_hip = Vector2(-3.2, -16.5)
			base_r_foot = Vector2(3.8, 1.0);   base_l_foot = Vector2(-3.2, -1.0)

	var l_hip = base_l_hip + Vector2(0.0, body_crouch) + body_lunge
	var r_hip = base_r_hip + Vector2(0.0, body_crouch) + body_lunge

	var l_foot = base_l_foot
	var r_foot = base_r_foot
	var l_lift = 0.0
	var r_lift = 0.0

	var stride_dir = current_move_vec if (is_moving and current_move_vec != Vector2.ZERO) else _get_dir_vector(current_dir)

	if is_attacking:
		var lunge_dist = body_lunge.length()
		var lunge_disp = Vector2(stride_dir.x * lunge_dist * 0.85, stride_dir.y * lunge_dist * 0.45)
		r_foot = base_r_foot + lunge_disp
		l_foot = base_l_foot - (lunge_disp * 0.45)
	elif is_moving:
		var stride_len = 4.2 + speed_ratio * 4.2
		var lift_h = 3.0 + speed_ratio * 2.4
		var swing = sin(walk_cycle)
		var fwd_disp = Vector2(stride_dir.x * (absf(swing) * stride_len), stride_dir.y * (absf(swing) * stride_len * 0.45))
		if swing > 0.0:
			r_lift = swing * lift_h
			r_foot = base_r_foot + fwd_disp + Vector2(0.0, -r_lift)
			l_foot = base_l_foot - (fwd_disp * 0.70)
		else:
			l_lift = -swing * lift_h
			l_foot = base_l_foot + fwd_disp + Vector2(0.0, -l_lift)
			r_foot = base_r_foot - (fwd_disp * 0.70)

	var left_in_front = (l_foot.y > r_foot.y) or (l_foot.y == r_foot.y and l_hip.y >= r_hip.y)
	if left_in_front:
		_draw_single_skeletal_leg(r_hip, r_foot, r_lift, stride_dir, true, is_rear)
		_draw_single_skeletal_leg(l_hip, l_foot, l_lift, stride_dir, false, is_rear)
	else:
		_draw_single_skeletal_leg(l_hip, l_foot, l_lift, stride_dir, true, is_rear)
		_draw_single_skeletal_leg(r_hip, r_foot, r_lift, stride_dir, false, is_rear)

func _draw_single_skeletal_leg(
	hip: Vector2,
	foot: Vector2,
	lift: float,
	stride_dir: Vector2,
	is_shaded: bool,
	_is_rear: bool
) -> void:
	var col_bone = COL_BONE_BASE if not is_shaded else COL_BONE_MID
	var col_hi   = COL_BONE_HI   if not is_shaded else COL_BONE_BASE
	var col_spec = COL_BONE_SPEC if not is_shaded else COL_BONE_HI
	var col_dark = COL_BONE_DARK

	# Knee joint placement
	var knee = (hip + foot) * 0.5
	if lift > 0.2:
		knee += (stride_dir * 1.6) + Vector2(0.0, -1.2)
	else:
		knee += Vector2(0.0, -0.6)

	# 1. Femur Bone with Greater Trochanter & Condyles
	draw_circle(hip, 1.8, col_dark)
	draw_line(hip, knee, col_bone, 2.2, false)
	draw_line(hip - Vector2(0.6, 0.2), knee - Vector2(0.6, 0.2), col_hi, 1.0, false)

	# 2. Multi-Tiered Knee Joint (Patella & Condylar Notch)
	draw_circle(knee, 2.0, col_bone)
	draw_circle(knee, 1.4, col_hi)
	draw_circle(knee - Vector2(0.5, 0.5), 0.7, col_spec)

	# 3. Dual Lower Leg Bones: Main Tibia & Lateral Fibula
	var ankle = foot + Vector2(0.0, -2.0)
	var leg_dir = (ankle - knee).normalized()
	var leg_perp = Vector2(-leg_dir.y, leg_dir.x)

	# Tibia (thick anterior shin bone with light ridge)
	draw_line(knee, ankle, col_bone, 2.0, false)
	draw_line(knee - leg_perp * 0.5, ankle - leg_perp * 0.5, col_hi, 1.0, false)

	# Fibula (thin lateral strut bone with gap in between)
	var fibula_offset = leg_perp * 1.5
	draw_line(knee + fibula_offset, ankle + fibula_offset * 0.8, col_dark, 1.0, false)

	# Malleolus Ankle Knobs
	draw_circle(ankle - leg_perp * 1.2, 1.1, col_bone)
	draw_circle(ankle + leg_perp * 1.2, 1.1, col_dark)

	# 4. 8-Directional Articulated Skeletal Feet (4 Clawed Toes)
	_draw_skeletal_foot(ankle, col_bone, col_hi, col_dark)

func _draw_skeletal_foot(ankle: Vector2, col_bone: Color, col_hi: Color, col_dark: Color) -> void:
	var toe_fwd = Vector2.ZERO
	var toe_spread = Vector2.ZERO

	match current_dir:
		Dir8.S:
			toe_fwd = Vector2(0.0, 3.8); toe_spread = Vector2(1.2, 0.0)
		Dir8.N:
			toe_fwd = Vector2(0.0, -2.0); toe_spread = Vector2(1.2, 0.0)
		Dir8.E:
			toe_fwd = Vector2(5.2, 0.0); toe_spread = Vector2(0.0, 1.0)
		Dir8.W:
			toe_fwd = Vector2(-5.2, 0.0); toe_spread = Vector2(0.0, 1.0)
		Dir8.SE:
			toe_fwd = Vector2(4.0, 2.4); toe_spread = Vector2(-0.8, 1.1)
		Dir8.SW:
			toe_fwd = Vector2(-4.0, 2.4); toe_spread = Vector2(0.8, 1.1)
		Dir8.NE:
			toe_fwd = Vector2(3.8, -2.0); toe_spread = Vector2(0.8, 1.0)
		Dir8.NW:
			toe_fwd = Vector2(-3.8, -2.0); toe_spread = Vector2(-0.8, 1.0)

	# Calcaneus (Heel Bone cup behind)
	var heel = ankle - toe_fwd * 0.35
	draw_circle(heel, 1.4, col_dark)

	# Tarsal & Metatarsal Arch
	var ball = ankle + toe_fwd * 0.55
	draw_line(ankle, ball, col_bone, 2.0, false)
	draw_line(ankle - toe_spread * 0.5, ball - toe_spread * 0.5, col_hi, 1.0, false)

	# 4 Delineated Skeletal Phalanges (Clawed Toes) gripping the floor
	for t in range(4):
		var frac = float(t) - 1.5 # -1.5, -0.5, 0.5, 1.5
		var t_start = ball + toe_spread * (frac * 0.9)
		var t_len = 1.0 if absf(frac) < 1.0 else 0.75
		var t_tip = t_start + toe_fwd * (0.55 * t_len)

		# Knuckle node
		draw_circle(t_start, 0.8, col_bone)
		# Claw phalanx
		draw_line(t_start, t_tip, col_hi, 1.1, false)
		# Dark sharp claw tip
		draw_line(t_tip, t_tip + toe_fwd * 0.25, col_dark, 1.0, false)

# --- VOLUMETRIC 3D SKELETAL TORSO (RIBCAGE, SPINE, SOUL CORE & PELVIS) ---
func _draw_volumetric_torso(is_rear: bool) -> void:
	var bob = _get_vertical_bob()
	var base_y = -15.5 + bob + body_crouch + body_lunge.y
	var chest_y = -27.5 + bob + body_crouch + body_lunge.y
	var center_x = body_lunge.x

	var walk_twist = sin(walk_cycle) * 0.08 * speed_ratio if (is_moving and not is_attacking) else 0.0
	var twist_offset = (body_twist + walk_twist) * 5.5

	# 1. Pelvic Girdle (Sacrum, Iliac Crests & Pubic Arch)
	var pelvis_y = base_y - 1.5
	var pelvis_poly = PackedVector2Array([
		Vector2(center_x - 6.0 + twist_offset * 0.3, pelvis_y - 2.0),
		Vector2(center_x + 6.0 + twist_offset * 0.3, pelvis_y - 2.0),
		Vector2(center_x + 4.5 + twist_offset * 0.3, pelvis_y + 2.0),
		Vector2(center_x - 4.5 + twist_offset * 0.3, pelvis_y + 2.0)
	])
	draw_colored_polygon(pelvis_poly, COL_BONE_BASE)
	draw_line(pelvis_poly[0], pelvis_poly[1], COL_BONE_HI, 1.4, false) # Iliac crest light
	# Sacral foramina (hollow holes in sacrum)
	draw_circle(Vector2(center_x + twist_offset * 0.3 - 1.5, pelvis_y), 0.8, COL_VOID)
	draw_circle(Vector2(center_x + twist_offset * 0.3 + 1.5, pelvis_y), 0.8, COL_VOID)

	# Tattered Grave Loincloth Remnants hanging from pelvis
	var rag_y = pelvis_y + 2.0
	var rag_poly = PackedVector2Array([
		Vector2(center_x - 4.0 + twist_offset * 0.3, rag_y),
		Vector2(center_x + 4.0 + twist_offset * 0.3, rag_y),
		Vector2(center_x + 2.5 + twist_offset * 0.3 + sin(shroud_phase) * 1.2, rag_y + 6.0),
		Vector2(center_x - 2.5 + twist_offset * 0.3 + sin(shroud_phase) * 1.2, rag_y + 6.0)
	])
	draw_colored_polygon(rag_poly, COL_SHROUD_DARK)
	draw_line(rag_poly[0], rag_poly[3], COL_SHROUD_MID, 1.0, false)

	# 2. Dark Internal Thoracic Cavity
	var thoracic_poly = PackedVector2Array([
		Vector2(center_x - 5.5 + twist_offset * 0.4, pelvis_y - 2.0),
		Vector2(center_x + 5.5 + twist_offset * 0.4, pelvis_y - 2.0),
		Vector2(center_x + 7.5 + twist_offset, chest_y + 3.0),
		Vector2(center_x - 7.5 + twist_offset, chest_y + 3.0)
	])
	draw_colored_polygon(thoracic_poly, COL_VOID)

	# 3. True 3D Depth: Back Ribs (Inside Cavity, Drawn in Shadow)
	for r in range(5):
		var frac = float(r) / 4.0
		var ry = lerpf(chest_y + 3.0, pelvis_y - 3.0, frac)
		var rx = lerpf(center_x + twist_offset, center_x + twist_offset * 0.3, frac)
		var r_span = lerpf(7.0, 4.8, frac) * 0.90
		# Back ribs curve inwards into deep shadow
		draw_line(Vector2(rx - r_span, ry - 0.6), Vector2(rx, ry), COL_BONE_DARK, 1.0, false)
		draw_line(Vector2(rx, ry), Vector2(rx + r_span, ry - 0.6), COL_BONE_DARK, 1.0, false)

	# 4. Central Articulated Vertebral Spine Column (T1 - L5)
	draw_line(
		Vector2(center_x + twist_offset * 0.3, pelvis_y - 1.0),
		Vector2(center_x + twist_offset, chest_y),
		COL_BONE_BASE, 2.6, false
	)
	for v in range(6):
		var frac = float(v) / 5.0
		var vy = lerpf(pelvis_y - 1.0, chest_y + 1.0, frac)
		var vx = lerpf(center_x + twist_offset * 0.3, center_x + twist_offset, frac)
		# Vertebral body block + spinous process
		draw_rect(Rect2(Vector2(vx - 1.5, vy - 0.8), Vector2(3.0, 1.6)), COL_BONE_HI if is_rear else COL_BONE_MID)
		if is_rear:
			# Spinous ridge
			draw_circle(Vector2(vx, vy), 0.8, COL_BONE_SPEC)

	# 5. Pulsing Necrotic Heart / Soulfire Flame inside chest cavity
	var heart_y = chest_y + 7.0
	var heart_x = center_x + twist_offset * 0.7
	var pulse = (sin(idle_timer * 3.5) * 0.5 + 0.5)
	draw_circle(Vector2(heart_x, heart_y), 2.2 + pulse * 1.0, COL_SOUL_GLOW)
	draw_circle(Vector2(heart_x, heart_y), 1.2 + pulse * 0.5, COL_SOUL_MID)
	draw_circle(Vector2(heart_x, heart_y), 0.6, COL_SOUL_CORE)

	# 6. Front Cylindrical 3D Ribs (5 Pairs wrapping around the chest)
	for r in range(5):
		var frac = float(r) / 4.0
		var ry = lerpf(chest_y + 3.0, pelvis_y - 3.0, frac)
		var rx = lerpf(center_x + twist_offset, center_x + twist_offset * 0.3, frac)
		var r_span = lerpf(7.5, 4.8, frac)

		var l_pt = Vector2(rx - r_span, ry + sin(frac * PI) * 1.6)
		var r_pt = Vector2(rx + r_span, ry + sin(frac * PI) * 1.6)

		# Shaded bottom edge of rib
		draw_line(Vector2(rx, ry + 0.4), l_pt + Vector2(0, 0.4), COL_BONE_MID, 1.2, false)
		draw_line(Vector2(rx, ry + 0.4), r_pt + Vector2(0, 0.4), COL_BONE_MID, 1.2, false)
		# Specular lit top edge of rib
		draw_line(Vector2(rx, ry - 0.4), l_pt - Vector2(0, 0.4), COL_BONE_HI, 1.2, false)
		draw_line(Vector2(rx, ry - 0.4), r_pt - Vector2(0, 0.4), COL_BONE_HI, 1.2, false)

	# 7. Sternal Plate (Breastbone in Front)
	if not is_rear:
		var st_top = Vector2(center_x + twist_offset, chest_y + 2.0)
		var st_bot = Vector2(center_x + twist_offset * 0.4, pelvis_y - 3.5)
		# Manubrium
		draw_circle(st_top, 1.6, COL_BONE_SPEC)
		# Gladiolus body
		draw_line(st_top, st_bot, COL_BONE_HI, 1.8, false)
		# Xiphoid process tip
		draw_circle(st_bot, 1.0, COL_BONE_BASE)

	# 8. Clavicles & Scapulae / Shoulders
	var shoulder_l = Vector2(center_x - 8.5 + twist_offset, chest_y + 1.2)
	var shoulder_r = Vector2(center_x + 8.5 + twist_offset, chest_y + 1.2)

	# Clavicles (S-curved collarbones)
	draw_line(Vector2(center_x + twist_offset, chest_y + 2.0), shoulder_l, COL_BONE_HI, 1.6, false)
	draw_line(Vector2(center_x + twist_offset, chest_y + 2.0), shoulder_r, COL_BONE_HI, 1.6, false)

	# Scapulae in rear view
	if is_rear:
		var scap_l = PackedVector2Array([
			shoulder_l,
			shoulder_l + Vector2(2.0, 5.0),
			shoulder_l + Vector2(4.0, 1.0)
		])
		var scap_r = PackedVector2Array([
			shoulder_r,
			shoulder_r + Vector2(-2.0, 5.0),
			shoulder_r + Vector2(-4.0, 1.0)
		])
		draw_colored_polygon(scap_l, COL_BONE_BASE)
		draw_colored_polygon(scap_r, COL_BONE_BASE)

	# Acromion shoulder knobs
	draw_circle(shoulder_l, 2.2, COL_BONE_BASE)
	draw_circle(shoulder_l - Vector2(0.5, 0.5), 1.2, COL_BONE_SPEC)
	draw_circle(shoulder_r, 2.2, COL_BONE_BASE)
	draw_circle(shoulder_r - Vector2(0.5, 0.5), 1.2, COL_BONE_SPEC)

	# Quiver on Archer's back / Robes on Mage
	if skeleton_type == Type.ARCHER:
		_draw_detailed_quiver(center_x + twist_offset, chest_y, is_rear)
	elif skeleton_type == Type.MAGE:
		_draw_mage_robes(center_x + twist_offset, chest_y, is_rear)

# --- DETAILED ARCHER QUIVER & ARROWS ---
func _draw_detailed_quiver(cx: float, cy: float, is_rear: bool) -> void:
	var q_pos = Vector2(cx + 4.5, cy + 3.5)
	var q_ang = -0.65
	var q_dir = Vector2(cos(q_ang), sin(q_ang))
	var q_perp = Vector2(-q_dir.y, q_dir.x)

	# Bandolier leather strap wrapping across ribs
	draw_line(Vector2(cx - 7.0, cy + 2.0), Vector2(cx + 6.0, cy + 8.0), COL_WOOD_DARK, 1.8, false)
	draw_rect(Rect2(Vector2(cx - 1.0, cy + 4.0), Vector2(2.4, 2.4)), COL_CROWN_GOLD)

	# Quiver body: Hardened hide with bone reinforcing ribs
	var q_poly = PackedVector2Array([
		q_pos - q_perp * 2.8 - q_dir * 11.0,
		q_pos + q_perp * 2.8 - q_dir * 11.0,
		q_pos + q_perp * 2.2 + q_dir * 7.0,
		q_pos - q_perp * 2.2 + q_dir * 7.0
	])
	draw_colored_polygon(q_poly, COL_WOOD_DARK if not is_rear else COL_WOOD_MID)
	draw_polyline(q_poly, COL_CROWN_DARK, 1.0, true)

	# Bone ribs on quiver
	draw_line(q_pos - q_dir * 8.0 - q_perp * 2.4, q_pos - q_dir * 8.0 + q_perp * 2.4, COL_BONE_HI, 1.2, false)
	draw_line(q_pos - q_dir * 2.0 - q_perp * 2.2, q_pos - q_dir * 2.0 + q_perp * 2.2, COL_BONE_HI, 1.2, false)

	# 4 Individual Arrows with Raven Feather Fletchings
	for a in range(4):
		var frac = float(a) - 1.5
		var f_origin = q_pos - q_dir * 11.0 + q_perp * (frac * 1.4)
		var sway = sin(walk_cycle + float(a)) * 1.0 if is_moving else 0.0
		var f_tip = f_origin - q_dir * 7.5 + q_perp * sway

		# Ash wood shaft
		draw_line(f_origin, f_tip, COL_BONE_BASE, 1.4, false)
		# Vane feathers
		draw_line(f_tip, f_tip - q_perp * 1.6 + q_dir * 2.2, COL_VOID, 1.2, false)
		draw_line(f_tip, f_tip + q_perp * 1.6 + q_dir * 2.2, COL_VOID, 1.2, false)
		# Sinew thread wrap
		draw_circle(f_origin - q_dir * 2.0, 0.7, COL_CROWN_GOLD)

# --- ANATOMICAL SKULL WITH WARLORD CROWN & SOULFIRE EYES ---
func _draw_skull(is_rear: bool) -> void:
	var bob = _get_vertical_bob()
	var walk_twist = sin(walk_cycle) * 0.08 * speed_ratio if (is_moving and not is_attacking) else 0.0
	var center = Vector2(body_lunge.x + (body_twist + walk_twist) * 3.6, -34.5 + bob + body_crouch + body_lunge.y)

	# 1. Cervical Vertebrae (C1 Atlas - C4)
	for c in range(3):
		var cy = center.y + 4.2 + float(c) * 1.5
		draw_rect(Rect2(Vector2(center.x - 1.4, cy), Vector2(2.8, 1.2)), COL_BONE_HI if is_rear else COL_BONE_BASE)

	# 2. Cranial Vault (3D Rounded Neurocranium)
	var cranium_pts = PackedVector2Array([
		center + Vector2(-6.0, 3.5),
		center + Vector2(6.0, 3.5),
		center + Vector2(6.5, -3.5),
		center + Vector2(4.8, -8.5),
		center + Vector2(-4.8, -8.5),
		center + Vector2(-6.5, -3.5)
	])
	draw_colored_polygon(cranium_pts, COL_BONE_BASE)
	# Cranium specular crest highlight
	draw_polyline(PackedVector2Array([
		center + Vector2(-4.8, -8.5),
		center + Vector2(0.0, -9.0),
		center + Vector2(4.8, -8.5)
	]), COL_BONE_SPEC, 1.4, false)

	if skeleton_type == Type.MAGE:
		_draw_mage_hood(center, is_rear)
	else:
		# 3. Ancient Tarnished Warlord Spiked Circlet / Crown (Embedded into skull!)
		var crown_y = center.y - 5.5
		var c_l = Vector2(center.x - 6.2, crown_y)
		var c_r = Vector2(center.x + 6.2, crown_y)
		draw_line(c_l, c_r, COL_CROWN_GOLD, 2.0, false)
		draw_line(c_l + Vector2(0, -0.6), c_r + Vector2(0, -0.6), Color(1.0, 0.9, 0.5), 0.9, false)

		# Crown Spikes
		for s in range(3):
			var sx = lerpf(center.x - 4.5, center.x + 4.5, float(s) / 2.0)
			var sp_pts = PackedVector2Array([
				Vector2(sx - 1.2, crown_y - 1.0),
				Vector2(sx, crown_y - (4.2 if s == 1 else 3.2)),
				Vector2(sx + 1.2, crown_y - 1.0)
			])
			draw_colored_polygon(sp_pts, COL_CROWN_GOLD)
			draw_line(sp_pts[0], sp_pts[1], Color(1.0, 0.9, 0.5), 0.8, false)
		# Center crown cursed red jewel
		draw_circle(Vector2(center.x, crown_y), 1.1, Color(0.85, 0.15, 0.15, 1.0))
		draw_circle(Vector2(center.x - 0.3, crown_y - 0.3), 0.5, Color(1.3, 0.6, 0.6, 1.0))

	if is_rear:
		# Occipital bone suture lines and back of head
		draw_line(center + Vector2(0.0, -8.0), center + Vector2(0.0, 2.5), COL_BONE_DARK, 1.2, false)
		draw_line(center + Vector2(-4.0, -1.8), center + Vector2(4.0, -1.8), COL_BONE_DARK, 1.2, false)
	else:
		# Front & 3/4 Perspective Facial Anatomy
		var eye_offset_x = 0.0
		match current_dir:
			Dir8.S:  eye_offset_x = 0.0
			Dir8.SE: eye_offset_x = 1.9
			Dir8.SW: eye_offset_x = -1.9
			Dir8.E:  eye_offset_x = 3.2
			Dir8.W:  eye_offset_x = -3.2

		# Supraorbital Brow Ridge (Heavy 3D shadow cast over sockets)
		var brow_l = center + Vector2(eye_offset_x - 5.0, -3.8)
		var brow_r = center + Vector2(eye_offset_x + 5.0, -3.8)
		var brow_m = center + Vector2(eye_offset_x, -3.2)
		draw_line(brow_l, brow_m, COL_BONE_SPEC, 1.5, false)
		draw_line(brow_m, brow_r, COL_BONE_SPEC, 1.5, false)
		draw_line(brow_l + Vector2(0, 1.0), brow_r + Vector2(0, 1.0), COL_BONE_DARK, 1.2, false)

		# Zygomatic Cheekbone Arches
		draw_line(center + Vector2(eye_offset_x - 5.5, -0.5), center + Vector2(eye_offset_x - 2.5, 1.0), COL_BONE_HI, 1.4, false)
		draw_line(center + Vector2(eye_offset_x + 5.5, -0.5), center + Vector2(eye_offset_x + 2.5, 1.0), COL_BONE_HI, 1.4, false)

		# Piriform Nasal Aperture (Inverted triangle with dark septum)
		var nose_pos = center + Vector2(eye_offset_x * 0.75, 0.8)
		draw_colored_polygon(PackedVector2Array([
			nose_pos + Vector2(0.0, -1.4),
			nose_pos + Vector2(1.2, 1.0),
			nose_pos + Vector2(-1.2, 1.0)
		]), COL_VOID)

		# Maxilla & Articulated Mandible (Upper & Lower Jagged Teeth with Gap)
		var jaw_x = center.x + eye_offset_x * 0.75
		var jaw_y = center.y + 2.8

		# Dark oral gap between teeth
		draw_rect(Rect2(Vector2(jaw_x - 3.5, jaw_y - 0.6), Vector2(7.0, 1.2)), COL_VOID)

		# Upper teeth row (4 ivory incisors)
		for t in range(4):
			var tx = lerpf(jaw_x - 2.8, jaw_x + 2.8, float(t) / 3.0)
			draw_line(Vector2(tx, jaw_y - 1.8), Vector2(tx, jaw_y - 0.4), COL_BONE_SPEC, 1.0, false)

		# Lower teeth row (4 interlocking teeth)
		for t in range(4):
			var tx = lerpf(jaw_x - 2.4, jaw_x + 2.4, float(t) / 3.0)
			draw_line(Vector2(tx, jaw_y + 0.4), Vector2(tx, jaw_y + 1.8), COL_BONE_HI, 1.0, false)

		# Chin bone tubercle
		draw_circle(Vector2(jaw_x, jaw_y + 2.4), 1.0, COL_BONE_BASE)

		# 3D Deep Hollow Eye Sockets with Soulfire Emerald Eyes
		var eye_l = center + Vector2(eye_offset_x - 3.0, -1.8)
		var eye_r = center + Vector2(eye_offset_x + 3.0, -1.8)

		if current_dir == Dir8.E:
			_draw_3d_eye_socket(eye_r, true)
		elif current_dir == Dir8.W:
			_draw_3d_eye_socket(eye_l, true)
		else:
			_draw_3d_eye_socket(eye_l, false)
			_draw_3d_eye_socket(eye_r, false)

func _draw_3d_eye_socket(pos: Vector2, is_profile: bool) -> void:
	var w = 1.9 if is_profile else 2.6
	var h = 2.6
	var pts = PackedVector2Array([
		pos + Vector2(-w, -h * 0.5),
		pos + Vector2(w, -h * 0.5),
		pos + Vector2(w * 0.8, h * 0.5),
		pos + Vector2(-w * 0.8, h * 0.5)
	])
	# Deep void socket floor
	draw_colored_polygon(pts, COL_VOID)
	# Bone rim contour
	draw_polyline(pts, COL_BONE_DARK, 1.0, true)

	# Eerie Soulfire Emerald Eyes with White-Hot Center & Dynamic Flicker
	var flicker = sin(idle_timer * 5.0 + pos.x * 2.0) * 0.35 + sin(idle_timer * 11.0) * 0.15
	var r_glow = 2.0 + flicker * 0.6
	draw_circle(pos, r_glow, COL_SOUL_GLOW)
	draw_circle(pos, 1.3 + flicker * 0.3, COL_SOUL_MID)
	draw_circle(pos, 0.6, COL_SOUL_CORE)

	# Subtle specular glint on the cheekbone right beneath socket
	draw_line(pos + Vector2(-w * 0.6, h * 0.55), pos + Vector2(w * 0.6, h * 0.55), COL_BONE_SPEC, 0.8, false)

# --- EQUIPMENT TRANSFORMS ---
func _compute_equipment_transforms() -> void:
	var bob = _get_vertical_bob()
	var body_pos = body_lunge + Vector2(0.0, bob + body_crouch)
	var chest_pos = Vector2(0.0, -21.5) + body_pos

	var f_ang = _get_forward_angle(current_dir)
	var f_dir = Vector2(sin(f_ang), -cos(f_ang) * 0.70).normalized()

	var base_shield_pos = Vector2(-10.5, 0.0)
	var base_weapon_pos = Vector2(10.5, 1.0)
	var base_shield_ang = -0.15
	var base_weapon_ang = 0.55
	shield_scale_x = 1.0
	blade_length = 26.0
	has_trail = false

	match current_dir:
		Dir8.S:
			base_shield_pos = Vector2(-10.5, 0.0); base_weapon_pos = Vector2(10.5, 1.0)
			base_shield_ang = -0.15; base_weapon_ang = 0.55
			shield_scale_x = 1.0; shield_in_front = true; weapon_in_front = true; trail_in_front = true
		Dir8.SE:
			base_shield_pos = Vector2(-5.5, 1.0); base_weapon_pos = Vector2(13.5, 2.8)
			base_shield_ang = 0.15; base_weapon_ang = 0.85
			shield_scale_x = 0.85; shield_in_front = true; weapon_in_front = true; trail_in_front = true
		Dir8.E:
			base_shield_pos = Vector2(-1.2, -3.0); base_weapon_pos = Vector2(13.5, 3.8)
			base_shield_ang = 0.35; base_weapon_ang = 1.10
			shield_scale_x = 0.55; shield_in_front = false; weapon_in_front = true; trail_in_front = true
		Dir8.NE:
			base_shield_pos = Vector2(6.5, -4.0); base_weapon_pos = Vector2(12.5, -2.0)
			base_shield_ang = 0.30; base_weapon_ang = 0.45
			shield_scale_x = 0.80; shield_in_front = false; weapon_in_front = false; trail_in_front = false
		Dir8.N:
			base_shield_pos = Vector2(10.5, -4.0); base_weapon_pos = Vector2(-10.5, -4.0)
			base_shield_ang = 0.15; base_weapon_ang = -0.45
			shield_scale_x = 1.0; shield_in_front = false; weapon_in_front = false; trail_in_front = false
		Dir8.NW:
			base_shield_pos = Vector2(-6.5, -4.0); base_weapon_pos = Vector2(-12.5, -2.0)
			base_shield_ang = -0.30; base_weapon_ang = -0.45
			shield_scale_x = 0.80; shield_in_front = false; weapon_in_front = false; trail_in_front = false
		Dir8.W:
			base_shield_pos = Vector2(-13.5, 3.8); base_weapon_pos = Vector2(1.2, -3.0)
			base_shield_ang = -0.35; base_weapon_ang = -1.10
			shield_scale_x = 0.55; shield_in_front = true; weapon_in_front = false; trail_in_front = false
		Dir8.SW:
			base_shield_pos = Vector2(-9.5, 2.0); base_weapon_pos = Vector2(-13.5, 1.0)
			base_shield_ang = -0.20; base_weapon_ang = -0.85
			shield_scale_x = 0.85; shield_in_front = true; weapon_in_front = true; trail_in_front = true

	shield_pos = chest_pos + base_shield_pos
	weapon_pos = chest_pos + base_weapon_pos
	shield_ang = base_shield_ang
	weapon_ang = base_weapon_ang

	# Attack trajectory & solid blade wind calculations for Swordsman
	if is_attacking and skeleton_type == Type.SWORDSMAN:
		var t = attack_progress
		match attack_combo:
			0: # COMBO 0: HORIZONTAL CLEAVE (150° forward sweep)
				var arc_start = f_ang - deg_to_rad(65.0)
				var arc_end   = f_ang + deg_to_rad(70.0)
				blade_length = 26.0

				if t < 0.22:
					var p = t / 0.22
					weapon_ang = lerp_angle(base_weapon_ang, arc_start, p * p)
					var s_dir = Vector2(sin(weapon_ang), -cos(weapon_ang) * 0.70).normalized()
					weapon_pos = chest_pos + s_dir * 11.5
				elif t < 0.62:
					var p = (t - 0.22) / 0.40
					var s = 1.0 - pow(1.0 - p, 3.0)
					weapon_ang = lerp_angle(arc_start, arc_end, s)
					var s_dir = Vector2(sin(weapon_ang), -cos(weapon_ang) * 0.70).normalized()
					weapon_pos = chest_pos + s_dir * 12.5

					has_trail = true
					trail_center = chest_pos
					trail_blade_ang = weapon_ang
					trail_sweep_dir = 1.0
					trail_span_angle = deg_to_rad(85.0) * sin(clampf(p, 0.0, 1.0) * PI)
					trail_r_hilt = 13.0
					trail_r_tip = 13.0 + blade_length
				else:
					var p = (t - 0.62) / 0.38
					var r = 1.0 - (1.0 - p) * (1.0 - p)
					weapon_ang = lerp_angle(arc_end, base_weapon_ang, r)
					var s_dir = Vector2(sin(weapon_ang), -cos(weapon_ang) * 0.70).normalized()
					weapon_pos = chest_pos + s_dir * lerpf(12.5, 10.5, r)

			1: # COMBO 1: RISING BACKHAND SLASH
				var arc_start = f_ang + deg_to_rad(60.0)
				var arc_end   = f_ang - deg_to_rad(65.0)
				blade_length = 26.0

				if t < 0.20:
					var p = t / 0.20
					weapon_ang = lerp_angle(base_weapon_ang, arc_start, p * p)
					var s_dir = Vector2(sin(weapon_ang), -cos(weapon_ang) * 0.70).normalized()
					weapon_pos = chest_pos + s_dir * 11.5 + Vector2(0.0, 2.8 * p)
				elif t < 0.58:
					var p = (t - 0.20) / 0.38
					var s = 1.0 - pow(1.0 - p, 3.0)
					weapon_ang = lerp_angle(arc_start, arc_end, s)
					var s_dir = Vector2(sin(weapon_ang), -cos(weapon_ang) * 0.70).normalized()
					var lift_y = lerpf(2.8, -4.8, s)
					weapon_pos = chest_pos + s_dir * 12.5 + Vector2(0.0, lift_y)

					has_trail = true
					trail_center = chest_pos
					trail_blade_ang = weapon_ang
					trail_sweep_dir = -1.0
					trail_span_angle = deg_to_rad(80.0) * sin(clampf(p, 0.0, 1.0) * PI)
					trail_r_hilt = 13.0
					trail_r_tip = 13.0 + blade_length
				else:
					var p = (t - 0.58) / 0.42
					var r = 1.0 - (1.0 - p) * (1.0 - p)
					weapon_ang = lerp_angle(arc_end, base_weapon_ang, r)
					var s_dir = Vector2(sin(weapon_ang), -cos(weapon_ang) * 0.70).normalized()
					weapon_pos = chest_pos + s_dir * lerpf(12.5, 10.5, r)

	# Archer Bow Aiming & Elastic String Pull
	if skeleton_type == Type.ARCHER and is_aiming_bow:
		weapon_ang = f_ang
		var draw_pull = bow_draw_progress * 2.8
		weapon_pos = chest_pos + f_dir * (11.0 - draw_pull)
	# Mage Staff Aiming, Levitation & Arcane Forward Thrust
	elif skeleton_type == Type.MAGE and is_aiming_bow:
		var float_y = -6.0 * sin(bow_draw_progress * PI)
		var thrust_fwd = 0.0
		if bow_draw_progress > 0.72:
			var tr = (bow_draw_progress - 0.72) / 0.28
			thrust_fwd = (1.0 - pow(1.0 - tr, 2.5)) * 6.5
		weapon_ang = f_ang + (0.28 * sin(bow_draw_progress * TAU))
		weapon_pos = chest_pos + f_dir * (11.0 + thrust_fwd) + Vector2(0.0, float_y)

# --- WEAPON ROUTING ---
func _draw_weapon() -> void:
	if skeleton_type == Type.SWORDSMAN:
		_draw_ancient_jagged_sword(weapon_pos, weapon_ang, blade_length)
	elif skeleton_type == Type.ARCHER:
		_draw_composite_bow(weapon_pos, weapon_ang, is_aiming_bow, bow_draw_progress)
	elif skeleton_type == Type.MAGE:
		_draw_arcane_staff(weapon_pos, weapon_ang, is_aiming_bow, bow_draw_progress)

# --- ANCIENT JAGGED SCIMITAR / BROADSWORD ---
func _draw_ancient_jagged_sword(pos: Vector2, angle: float, b_len: float) -> void:
	var dir = Vector2(sin(angle), -cos(angle) * 0.70).normalized()
	var perp = Vector2(-dir.y, dir.x).normalized()

	var hilt = pos
	var pommel = hilt - (dir * 4.5)
	var guard  = hilt + (dir * 1.6)
	var tip    = guard + (dir * b_len)

	# 1. Grip: Leather wrap with brass wire
	draw_line(pommel, guard, COL_WOOD_DARK, 2.0, false)
	draw_line(pommel + perp * 0.5, guard + perp * 0.5, COL_CROWN_GOLD, 0.8, false)

	# 2. Skull-Shaped Iron Pommel
	draw_circle(pommel, 1.8, COL_RUST_IRON)
	draw_circle(pommel - perp * 0.6, 0.5, COL_SOUL_MID)
	draw_circle(pommel + perp * 0.6, 0.5, COL_SOUL_MID)

	# 3. Demonic Curved Spiked Crossguard
	var q1 = guard - (perp * 5.2) + dir * 1.2
	var q2 = guard + (perp * 5.2) + dir * 1.2
	draw_line(guard - (perp * 5.0), guard + (perp * 5.0), COL_RUST_IRON, 2.4, false)
	draw_line(guard - (perp * 5.0), q1, COL_RUST_EDGE, 1.4, false)
	draw_line(guard + (perp * 5.0), q2, COL_RUST_EDGE, 1.4, false)

	# 4. Blade Body: Double-beveled notched steel with necrotic fuller
	var b_l = guard - (perp * 2.2)
	var b_r = guard + (perp * 2.2)
	var tip_l = guard + (dir * (b_len - 3.2)) - (perp * 1.8)
	var tip_r = guard + (dir * (b_len - 3.2)) + (perp * 1.8)

	var blade_pts = PackedVector2Array([b_l, tip_l, tip, tip_r, b_r])
	draw_colored_polygon(blade_pts, COL_RUST_IRON)

	# Razor cutting edge with battle notches
	draw_line(b_l, tip, COL_RUST_EDGE, 1.2, false)
	draw_line(b_r, tip, COL_RUST_EDGE, 0.9, false)

	# Serrated tooth notch cut into the steel
	var notch1 = guard + (dir * (b_len * 0.42)) - (perp * 2.2)
	draw_line(notch1, notch1 + dir * 1.8 + perp * 1.2, COL_VOID, 1.2, false)
	var notch2 = guard + (dir * (b_len * 0.70)) - (perp * 2.0)
	draw_line(notch2, notch2 + dir * 1.5 + perp * 1.0, COL_VOID, 1.2, false)

	# Necrotic Runic Fuller Groove (glowing green line down center)
	draw_line(guard + dir * 2.0, guard + dir * (b_len - 5.0), COL_VOID, 1.2, false)
	draw_line(guard + dir * 3.0, guard + dir * (b_len - 6.0), COL_SOUL_MID, 0.8, false)

	# 5. Skeletal Gripping Claw Hand with 3 Articulated Phalanges
	draw_circle(hilt, 2.2, COL_BONE_BASE)
	draw_circle(hilt - Vector2(0.4, 0.4), 1.2, COL_BONE_HI)
	# Knuckles wrapping around grip
	for k in range(3):
		var k_pos = hilt - dir * (float(k) * 1.3) + perp * 1.2
		draw_circle(k_pos, 0.9, COL_BONE_HI)
		draw_line(k_pos, k_pos - perp * 1.4, COL_BONE_SPEC, 0.9, false)

# --- BATTERED HEAVY OAK-AND-IRON BUCKLER ---
func _draw_battered_buckler(pos: Vector2, angle: float, scale_x: float, is_facing_away: bool) -> void:
	var r = 8.5
	var rim_pts = PackedVector2Array()
	var wood_pts = PackedVector2Array()
	for i in range(16):
		var a = i * TAU / 16.0
		rim_pts.append(pos + Vector2(cos(a) * r * scale_x, sin(a) * r).rotated(angle))
		wood_pts.append(pos + Vector2(cos(a) * (r - 1.5) * scale_x, sin(a) * (r - 1.5)).rotated(angle))

	# 1. Heavy Forged Iron Rim
	draw_colored_polygon(rim_pts, COL_RUST_IRON)

	if is_facing_away:
		# Interior: Decayed oak planking with leather arm straps and brass rivets
		draw_colored_polygon(wood_pts, COL_WOOD_DARK)
		var s_dir = Vector2(0.0, 1.0).rotated(angle)
		var s_perp = Vector2(-s_dir.y, s_dir.x)
		var strap1 = pos + s_dir * -2.5
		var strap2 = pos + s_dir * 2.5
		draw_line(strap1 - s_perp * 3.5 * scale_x, strap1 + s_perp * 3.5 * scale_x, COL_SHROUD_DARK, 2.0, false)
		draw_line(strap2 - s_perp * 3.0 * scale_x, strap2 + s_perp * 3.0 * scale_x, COL_SHROUD_DARK, 2.0, false)
		draw_circle(strap1, 1.0, COL_CROWN_GOLD)
		draw_circle(strap2, 1.0, COL_CROWN_GOLD)
	else:
		# Exterior: Weathered vertical oak planks
		draw_colored_polygon(wood_pts, COL_WOOD_MID)

		# Vertical Wood Plank Seams & Battle Scars
		var p_x1 = pos + (Vector2(-2.8 * scale_x, -5.5)).rotated(angle)
		var p_x2 = pos + (Vector2(-2.8 * scale_x, 5.5)).rotated(angle)
		var p_x3 = pos + (Vector2(2.8 * scale_x, -5.5)).rotated(angle)
		var p_x4 = pos + (Vector2(2.8 * scale_x, 5.5)).rotated(angle)
		draw_line(p_x1, p_x2, COL_WOOD_DARK, 1.2, false)
		draw_line(p_x3, p_x4, COL_WOOD_DARK, 1.2, false)

		# Deep Battle Axe Gouge on the wood face
		var g1 = pos + (Vector2(-1.5 * scale_x, -3.0)).rotated(angle)
		var g2 = pos + (Vector2(3.0 * scale_x, 1.0)).rotated(angle)
		draw_line(g1, g2, COL_VOID, 1.4, false)
		draw_line(g1 + Vector2(0, 0.5), g2 + Vector2(0, 0.5), COL_WOOD_HI, 0.8, false)

		# Massive Spiked Central Iron Umbo (Boss)
		draw_circle(pos, 2.8, COL_RUST_IRON)
		draw_circle(pos - Vector2(0.5, 0.5), 1.6, COL_RUST_EDGE)
		# Central Spike
		var spike_tip = pos + Vector2(0.0, 3.0).rotated(angle)
		draw_line(pos, spike_tip, COL_RUST_EDGE, 1.6, false)

		# Iron Rim Rivets (4 compass points)
		for k in range(4):
			var a = k * TAU / 4.0
			var riv = pos + Vector2(cos(a) * (r - 0.8) * scale_x, sin(a) * (r - 0.8)).rotated(angle)
			draw_circle(riv, 0.8, COL_RUST_EDGE)

# --- COMPOSITE BONE & HORN RECURVE BOW ---
func _draw_composite_bow(pos: Vector2, angle: float, aiming: bool, draw_prog: float) -> void:
	var dir = Vector2(sin(angle), -cos(angle) * 0.70).normalized()
	var perp = Vector2(-dir.y, dir.x).normalized()

	var bow_h = 17.0
	var flex = (draw_prog * 4.2) if aiming else 0.0
	var bow_curve = 6.0 + flex

	# Recurve horn tips that bend back under draw tension
	var tip_top = pos + perp * (bow_h - flex * 0.4) - dir * (bow_curve * 0.30)
	var tip_bot = pos - perp * (bow_h - flex * 0.4) - dir * (bow_curve * 0.30)
	var recurve_top = tip_top + perp * 2.2 + dir * (1.5 + flex * 0.35)
	var recurve_bot = tip_bot - perp * 2.2 + dir * (1.5 + flex * 0.35)
	var belly = pos + dir * bow_curve

	# 1. Dual-Laminate Horn & Bone Limbs
	var stave_pts = PackedVector2Array([
		recurve_top,
		tip_top,
		pos + perp * (bow_h * 0.5) + dir * (bow_curve * 0.6),
		belly,
		pos - perp * (bow_h * 0.5) + dir * (bow_curve * 0.6),
		tip_bot,
		recurve_bot
	])
	# Outer horn back
	draw_polyline(stave_pts, COL_WOOD_DARK, 2.6, false)
	# Inner bone belly
	draw_polyline(stave_pts, COL_BONE_HI, 1.4, false)

	# Carved bone nocks at tips
	draw_circle(recurve_top, 1.2, COL_BONE_SPEC)
	draw_circle(recurve_bot, 1.2, COL_BONE_SPEC)

	# Central Leather Handle Wrap & Bone Grip
	draw_line(belly - perp * 2.2, belly + perp * 2.2, COL_SHROUD_DARK, 3.0, false)
	draw_circle(belly, 1.4, COL_CROWN_GOLD)

	# 2. Twisted Silver Sinew Bowstring & Arrow
	var tremble = Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)) if (aiming and draw_prog > 0.85) else Vector2.ZERO
	var nock_pt = belly - dir * (1.5 + draw_prog * 9.0 if aiming else 1.5) + tremble
	draw_line(recurve_top, nock_pt, Color(0.95, 1.0, 0.95), 1.2, false)
	draw_line(recurve_bot, nock_pt, Color(0.95, 1.0, 0.95), 1.2, false)

	# 3. Notched Barbed Bone Arrow when aiming
	if aiming:
		var arrow_len = 24.0
		var arrow_tip = nock_pt + dir * arrow_len

		# Wood shaft
		draw_line(nock_pt, arrow_tip, COL_BONE_BASE, 1.6, false)
		draw_line(nock_pt, arrow_tip, COL_BONE_SPEC, 0.8, false)

		# Barbed Bone Broadhead
		var b_w = 2.4
		var head_poly = PackedVector2Array([
			arrow_tip + dir * 3.8,
			arrow_tip - dir * 2.5 + perp * b_w,
			arrow_tip - dir * 1.0,
			arrow_tip - dir * 2.5 - perp * b_w
		])
		draw_colored_polygon(head_poly, COL_BONE_SPEC)
		# Gleaming soulfire poison edge
		draw_line(arrow_tip + dir * 3.8, arrow_tip - dir * 2.5 + perp * b_w, COL_SOUL_MID, 1.2, false)
		draw_circle(arrow_tip + dir * 3.8, 0.9, Color.WHITE)

		# Skeletal drawing hand with 3 articulated fingers pulling the string
		draw_circle(nock_pt, 1.8, COL_BONE_BASE)
		draw_circle(nock_pt, 1.1, COL_BONE_SPEC)
		for f in range(3):
			var f_p = nock_pt - dir * 1.0 + perp * (float(f) - 1.0) * 1.2
			draw_circle(f_p, 0.8, COL_BONE_HI)

# --- 3-TONE SOLID BLADE WIND TRAIL (NECROTIC SOULFIRE EMERALD) ---
func _draw_blade_wind_trail() -> void:
	if trail_span_angle < 0.04:
		return

	var num_segs = 16
	var pts_out: Array[Vector2] = []
	var pts_mid: Array[Vector2] = []
	var pts_in: Array[Vector2] = []
	var dirs_y: Array[float] = []

	for i in range(num_segs + 1):
		var frac = float(i) / float(num_segs)
		var a = trail_blade_ang - trail_sweep_dir * trail_span_angle * (1.0 - frac)
		var ro = trail_r_tip
		var ri = lerpf(ro - 2.0, trail_r_hilt, sin(frac * (PI * 0.5)))
		var rm = lerpf(ro - 1.2, (ro + ri) * 0.52, sin(frac * (PI * 0.5)))

		var dir_a = Vector2(sin(a), -cos(a) * 0.70).normalized()
		pts_out.append(trail_center + dir_a * ro)
		pts_in.append(trail_center + dir_a * ri)
		pts_mid.append(trail_center + dir_a * rm)
		dirs_y.append(dir_a.y)

	for i in range(num_segs):
		var p_out0 = pts_out[i]
		var p_out1 = pts_out[i + 1]
		var p_mid0 = pts_mid[i]
		var p_mid1 = pts_mid[i + 1]
		var p_in0 = pts_in[i]
		var p_in1 = pts_in[i + 1]

		# 1. Inner dark cel-shade boundary
		draw_colored_polygon(PackedVector2Array([p_mid0, p_mid1, p_in1, p_in0]), COL_TRAIL_SHADE)
		# 2. Main solid luminous soulfire body
		draw_colored_polygon(PackedVector2Array([p_out0, p_out1, p_mid1, p_mid0]), COL_TRAIL_CORE)

		# 3. Pure White Razor-Sharp Cutting Crest (2.2px)
		draw_line(p_out0, p_out1, Color(1.0, 1.0, 1.0, 1.0), 2.2, false)
		# 4. Internal Velocity Streak along midline
		draw_line(p_mid0, p_mid1, Color(0.9, 1.0, 0.9, 1.0), 1.2, false)
		# 5. Inner Contour boundary
		draw_line(p_in0, p_in1, Color(0.08, 0.20, 0.12, 1.0), 1.0, false)

func _get_forward_angle(dir: Dir8) -> float:
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

# --- MAGE HOOD / COWL ---
func _draw_mage_hood(center: Vector2, is_rear: bool) -> void:
	var col_hood_dark = Color(0.12, 0.08, 0.16)
	var col_hood_mid  = Color(0.24, 0.16, 0.32)
	var col_hood_trim = Color(0.85, 0.70, 0.28)

	var tip = center + Vector2(0.0, -11.5)
	var l_shoulder = center + Vector2(-7.2, 3.5)
	var r_shoulder = center + Vector2(7.2, 3.5)
	var hood_pts = PackedVector2Array([
		tip,
		center + Vector2(6.5, -7.5),
		r_shoulder,
		center + Vector2(3.5, 5.0),
		center + Vector2(-3.5, 5.0),
		l_shoulder,
		center + Vector2(-6.5, -7.5)
	])
	draw_colored_polygon(hood_pts, col_hood_dark)

	var fold_pts = PackedVector2Array([
		tip,
		center + Vector2(2.5, -6.0),
		center + Vector2(4.5, 2.0),
		center + Vector2(0.0, 1.0),
		center + Vector2(-2.5, -6.0)
	])
	draw_colored_polygon(fold_pts, col_hood_mid)

	draw_polyline(PackedVector2Array([l_shoulder, center + Vector2(-3.5, 5.0), center + Vector2(3.5, 5.0), r_shoulder]), col_hood_trim, 1.4, false)

	if not is_rear:
		var face_shadow = PackedVector2Array([
			center + Vector2(0.0, -6.0),
			center + Vector2(4.5, -2.5),
			center + Vector2(3.5, 3.0),
			center + Vector2(-3.5, 3.0),
			center + Vector2(-4.5, -2.5)
		])
		draw_colored_polygon(face_shadow, Color(0.04, 0.03, 0.05, 0.85))

# --- MAGE ROBES ---
func _draw_mage_robes(cx: float, cy: float, _is_rear: bool) -> void:
	var col_robe_dark = Color(0.12, 0.08, 0.16)
	var col_robe_mid  = Color(0.22, 0.15, 0.30)
	var col_gold_trim = Color(0.85, 0.70, 0.28)

	var hem_y = cy + 24.0
	var robe_pts = PackedVector2Array([
		Vector2(cx - 7.5, cy + 2.0),
		Vector2(cx + 7.5, cy + 2.0),
		Vector2(cx + 10.0, hem_y),
		Vector2(cx - 10.0, hem_y)
	])
	draw_colored_polygon(robe_pts, col_robe_dark)

	draw_line(Vector2(cx - 2.5, cy + 3.0), Vector2(cx - 4.0, hem_y), col_robe_mid, 2.0, false)
	draw_line(Vector2(cx + 2.5, cy + 3.0), Vector2(cx + 4.0, hem_y), col_robe_mid, 2.0, false)

	draw_line(Vector2(cx - 10.0, hem_y), Vector2(cx + 10.0, hem_y), col_gold_trim, 1.6, false)

# --- ARCANE STAFF & FLOATING NETHERFIRE ORB ---
func _draw_arcane_staff(pos: Vector2, angle: float, casting: bool, cast_prog: float) -> void:
	var dir = Vector2(sin(angle), -cos(angle) * 0.70).normalized()
	var perp = Vector2(-dir.y, dir.x).normalized()

	var staff_len = 34.0
	var base_pt = pos - dir * 10.0
	var tip_pt  = pos + dir * (staff_len - 10.0)

	# 1. Gnarled Bone Staff Shaft
	draw_line(base_pt, tip_pt, COL_BONE_BASE, 2.4, false)
	draw_line(base_pt, tip_pt, COL_BONE_SPEC, 1.0, false)

	# Bone staff grip wrap
	var grip_mid = pos
	draw_line(grip_mid - dir * 3.5, grip_mid + dir * 3.5, Color(0.2, 0.12, 0.25), 3.2, false)
	draw_circle(grip_mid, 1.6, COL_CROWN_GOLD)

	# 2. Staff Head Talons (3 curved prongs cupping the orb)
	var prong_l = tip_pt + perp * 4.5 + dir * 3.0
	var prong_r = tip_pt - perp * 4.5 + dir * 3.0
	var prong_c = tip_pt + dir * 6.5
	draw_line(tip_pt, prong_l, COL_BONE_HI, 1.6, false)
	draw_line(tip_pt, prong_r, COL_BONE_HI, 1.6, false)
	draw_line(tip_pt, prong_c, COL_BONE_SPEC, 1.4, false)

	# 3. Floating Netherfire Arcane Orb & Rotating Glyphs
	var orb_center = tip_pt + dir * (5.5 + (1.5 * sin(idle_timer * 4.0)))
	var pulse = sin(idle_timer * 6.0) * 1.0 + (cast_prog * 2.5 if casting else 0.0)

	var outer_glow = Color(1.2, 0.4, 0.15, 0.55) if not casting else Color(2.4, 0.8, 0.25, 0.90)
	draw_circle(orb_center, 6.5 + pulse, outer_glow)

	var core_col = Color(1.8, 0.3, 0.1, 1.0) if not casting else Color(2.8, 1.8, 0.4, 1.0)
	draw_circle(orb_center, 4.0, core_col)
	draw_circle(orb_center - Vector2(0.8, 0.8), 1.8, Color.WHITE)

	# Energy filaments connecting prongs to core
	draw_line(prong_l, orb_center, Color(2.2, 1.2, 0.3, 0.75), 1.0, false)
	draw_line(prong_r, orb_center, Color(2.2, 1.2, 0.3, 0.75), 1.0, false)

	if casting:
		# Outer counter-rotating summoning rune rings
		var ring_r1 = 10.0 + cast_prog * 3.5
		var ring_r2 = 13.5 + cast_prog * 2.0
		var num_pts = 16
		var ring1_pts = PackedVector2Array()
		var ring2_pts = PackedVector2Array()
		for i in range(num_pts + 1):
			var a = i * TAU / float(num_pts)
			ring1_pts.append(orb_center + Vector2(cos(a) * ring_r1, sin(a) * ring_r1 * 0.70))
			ring2_pts.append(orb_center + Vector2(cos(a) * ring_r2, sin(a) * ring_r2 * 0.70))
		draw_polyline(ring1_pts, Color(2.4, 1.4, 0.4, 0.65), 1.0, false)
		draw_polyline(ring2_pts, Color(2.0, 0.7, 0.2, 0.45), 1.0, false)

		# Orbiting incandescent arcane glyph sparks
		for s in range(6):
			var s_ang = idle_timer * 12.0 + (s * TAU / 6.0)
			var s_pt = orb_center + Vector2(cos(s_ang) * ring_r1, sin(s_ang) * ring_r1 * 0.70)
			draw_circle(s_pt, 1.4, Color(2.8, 2.4, 0.8, 1.0))
			draw_circle(s_pt, 0.7, Color.WHITE)
