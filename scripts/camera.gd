extends Camera2D

const MainMenuClass = preload("res://scripts/ui/main_menu.gd")

@export var max_offset: Vector2 = Vector2(6.5, 4.0)
@export var max_roll: float = 0.008
@export var trauma_decay: float = 3.6
@export var max_trauma_cap: float = 0.38

var trauma: float = 0.0
var trauma_added_this_frame: float = 0.0
var punch_impulse: Vector2 = Vector2.ZERO

var noise: FastNoiseLite
var noise_sample_pos: float = 0.0
var base_zoom: Vector2 = Vector2(1.0, 1.0)
var zoom_punch_tween: Tween

func _ready() -> void:
	add_to_group("camera")
	base_zoom = zoom
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 4.5
	noise.fractal_octaves = 2

func add_trauma(amount: float) -> void:
	var intensity = MainMenuClass.screen_shake_intensity if "screen_shake_intensity" in MainMenuClass else 1.0
	amount *= intensity * 0.70
	if amount <= 0.001:
		return
	# Balanced trauma blending (50% punch of original)
	var capped_amount = min(amount, 0.20)
	trauma_added_this_frame = max(trauma_added_this_frame, capped_amount)
	var blended = max(trauma, trauma_added_this_frame) + (trauma_added_this_frame * 0.10)
	trauma = clamp(blended, 0.0, max_trauma_cap)

func add_directional_trauma(amount: float, dir: Vector2) -> void:
	add_trauma(amount)
	var intensity = MainMenuClass.screen_shake_intensity if "screen_shake_intensity" in MainMenuClass else 1.0
	punch_impulse += dir.normalized() * (min(amount, 0.18) * 8.0 * intensity)
	punch_impulse = punch_impulse.limit_length(6.5)

func trigger_zoom_punch(factor: float = 0.04, duration: float = 0.20) -> void:
	if zoom_punch_tween and zoom_punch_tween.is_valid():
		zoom_punch_tween.kill()
	var intensity = MainMenuClass.screen_shake_intensity if "screen_shake_intensity" in MainMenuClass else 1.0
	var capped_factor = min(factor, 0.020) * intensity
	zoom_punch_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	zoom = base_zoom * (1.0 + capped_factor)
	zoom_punch_tween.tween_property(self, "zoom", base_zoom, duration).set_ease(Tween.EASE_IN_OUT)

func _process(delta: float) -> void:
	trauma_added_this_frame = 0.0
	noise_sample_pos += delta * 60.0

	punch_impulse = punch_impulse.move_toward(Vector2.ZERO, 95.0 * delta)

	if trauma > 0.0 or punch_impulse != Vector2.ZERO:
		trauma = max(0.0, trauma - trauma_decay * delta)
		var shake = trauma * trauma # Non-linear quadratic falloff
		
		# Organic FastNoiseLite multi-axis shake
		var n_x = noise.get_noise_2d(noise_sample_pos, 0.0)
		var n_y = noise.get_noise_2d(noise_sample_pos, 150.0)
		var n_r = noise.get_noise_2d(noise_sample_pos, 300.0)
		
		var shake_x = max_offset.x * shake * n_x + punch_impulse.x
		var shake_y = max_offset.y * shake * n_y + punch_impulse.y
		offset = Vector2(shake_x, shake_y)
		rotation = max_roll * shake * n_r
	else:
		offset = Vector2.ZERO
		rotation = 0.0

