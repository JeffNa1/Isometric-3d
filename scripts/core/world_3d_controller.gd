class_name World3DController
extends Node2D

## World Controller for Medieval Dungeon Floor + 3D Dark Knight
## Feeds dynamic player torchlight to the dungeon floor shader,
## manages camera tracking, and displays clean control guides.

@onready var player: CharacterBody2D = find_child("Player", true, false) as CharacterBody2D
@onready var camera: Camera2D = $Camera2D
@onready var ground_rect: ColorRect = get_node_or_null("Arena/GroundRect") as ColorRect

func _ready() -> void:
	DisplayServer.window_move_to_foreground()

	if ground_rect and ground_rect.material:
		var mat = ground_rect.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("torch_radius", 520.0)
			mat.set_shader_parameter("torch_intensity", 1.40)
			mat.set_shader_parameter("torch_color", Vector3(1.0, 0.75, 0.42))
			mat.set_shader_parameter("ambient_light", 0.35)
			mat.set_shader_parameter("tile_width", 72.0)
			mat.set_shader_parameter("tile_height", 36.0)
			mat.set_shader_parameter("mortar_width", 2.2)

func _process(delta: float) -> void:
	if is_instance_valid(player):
		# Feed player position to dungeon floor shader for dynamic torchlight illumination
		if ground_rect and ground_rect.material:
			var mat = ground_rect.material as ShaderMaterial
			if mat:
				mat.set_shader_parameter("player_pos", player.global_position)

		# Smooth Camera follow
		if is_instance_valid(camera):
			camera.global_position = camera.global_position.lerp(player.global_position, 10.0 * delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
