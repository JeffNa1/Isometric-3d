class_name FloatingDamage
extends RefCounted

## Reusable combat utility for floating combat text and damage numbers.

static func spawn(
	parent: Node,
	origin: Vector2,
	amount: float,
	color: Color = Color(1.0, 0.90, 0.35, 1.0),
	offset_y: float = -50.0,
	font_size: int = 14
) -> Label:
	if not parent or not is_instance_valid(parent):
		return null

	var label = Label.new()
	label.text = str(int(round(amount)))
	label.z_index = 250
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.06, 0.08, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", font_size)

	var jitter = Vector2(randf_range(-10.0, 10.0), randf_range(-5.0, 5.0))
	label.position = origin + Vector2(-12.0, offset_y) + jitter
	parent.add_child(label)

	var tween = label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 30.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)
	return label
