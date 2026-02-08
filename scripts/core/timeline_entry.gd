## An entry in the speed-based timeline that determines turn order.
## Characters with lower tick values act first (like FFX's CTB system).
class_name TimelineEntry
extends Resource

var character: CharacterData = null
var current_tick: int = 0  ## Accumulates; lowest tick acts next


func _init(p_character: CharacterData = null) -> void:
	if p_character:
		character = p_character
		current_tick = p_character.get_effective_speed()


## After a character takes their turn, advance their tick by their speed.
func advance() -> void:
	current_tick += character.get_effective_speed()
