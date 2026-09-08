class_name VenomPuddle
extends Area2D

## 2.5D Lingering Toxic Acid Puddle
## - Spawns on ground where Venom Spit lands
## - 2:1 isometric bubbling toxic sludge pool
## - Deals poison damage and slows player (50% speed penalty + green drip)
## - Dissipates after 3.5 seconds

@export var duration: float = 3.5
@export var damage_per_sec: float = 8.0

var life_timer: float = 0.0
var dot_tick_timer: float = 0.0
var bubble_phase: float = 0.0
var radius_x: float = 24.0
var radius_y: float = 12.0 # 2:1 isometric

const COL_ACID_DARK  = Color(0.08, 0.28, 0.08, 0.70)
const COL_ACID_MID   = Color(0.18, 0.75, 0.15, 0.85)
const COL_ACID_BRIGHT= Color(0.55, 0.98, 0.20, 0.90)

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2 # Player

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 18.0
	col.shape = shape
	add_child(col)

func _physics_process(delta: float) -> void:
	life_timer += delta
	bubble_phase += delta * 8.0
	dot_tick_timer += delta

	if life_timer >= duration:
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)
		set_physics_process(false)
		return

	# Damage & slow check every 0.35s
	if dot_tick_timer >= 0.35:
		dot_tick_timer = 0.0
		var bodies = get_overlapping_bodies()
		for b in bodies:
			if b.is_in_group("player"):
				if b.has_method("take_damage"):
					b.take_damage(damage_per_sec * 0.35, Vector2.ZERO, false, self)
				if b.has_method("apply_slow"):
					b.apply_slow(0.5, 2.5)

	queue_redraw()

func _draw() -> void:
	var alpha_fade = 1.0
	if life_timer > duration - 0.5:
		alpha_fade = clampf((duration - life_timer) / 0.5, 0.0, 1.0)

	# Outer Dark Slime
	var pts_outer = PackedVector2Array()
	for i in range(16):
		var a = i * TAU / 16.0
		var r_mod = 1.0 + sin(bubble_phase + i * 1.5) * 0.08
		pts_outer.append(Vector2(cos(a) * radius_x * r_mod, sin(a) * radius_y * r_mod))
	var c_dark = COL_ACID_DARK
	c_dark.a *= alpha_fade
	draw_colored_polygon(pts_outer, c_dark)

	# Inner Luminous Acid
	var pts_inner = PackedVector2Array()
	for i in range(12):
		var a = i * TAU / 12.0
		pts_inner.append(Vector2(cos(a) * (radius_x - 4.0), sin(a) * (radius_y - 2.5)))
	var c_mid = COL_ACID_MID
	c_mid.a *= alpha_fade
	draw_colored_polygon(pts_inner, c_mid)

	# Bubbles rising and popping
	for k in range(3):
		var b_a = bubble_phase * 0.7 + (k * TAU / 3.0)
		var b_dist = sin(bubble_phase * 0.5 + k) * 9.0
		var b_pos = Vector2(cos(b_a) * b_dist, sin(b_a) * (b_dist * 0.5))
		var b_size = 1.5 + sin(bubble_phase * 2.0 + k) * 0.8
		if b_size > 0.6:
			var c_bright = COL_ACID_BRIGHT
			c_bright.a *= alpha_fade
			draw_circle(b_pos, b_size, c_bright)
			draw_circle(b_pos - Vector2(0.3, 0.3), b_size * 0.4, Color.WHITE)
