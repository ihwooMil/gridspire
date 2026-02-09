## Floating damage/heal number that pops up and fades away.
## Instantiate, call setup(), and add as a child of the scene.
class_name DamagePopup
extends Label

var _velocity: Vector2 = Vector2(0, -80)
var _lifetime: float = 0.8
var _elapsed: float = 0.0


func setup(amount: int, is_damage: bool = true, world_position: Vector2 = Vector2.ZERO, dice_notation: String = "") -> void:
	if dice_notation != "":
		text = "%d (%s)" % [amount, dice_notation]
	else:
		text = str(amount)
	position = world_position + Vector2(randf_range(-10, 10), -20)
	if is_damage:
		add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	else:
		add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	add_theme_font_size_override("font_size", 20)
	z_index = 100
	scale = Vector2(1.3, 1.3)


func _process(delta: float) -> void:
	_elapsed += delta
	position += _velocity * delta
	_velocity.y += 60.0 * delta  # gravity
	var progress: float = _elapsed / _lifetime
	modulate.a = 1.0 - progress
	if progress >= 1.0:
		queue_free()
