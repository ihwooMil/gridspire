## GameManager — Global autoload singleton.
## Manages high-level game state, party roster, and scene transitions.
extends Node

signal game_state_changed(new_state: Enums.GameState)
signal party_updated()

var current_state: Enums.GameState = Enums.GameState.MAIN_MENU
var party: Array[CharacterData] = []
var current_floor: int = 1
var gold: int = 0
var run_seed: int = 0


func _ready() -> void:
	run_seed = randi()


func change_state(new_state: Enums.GameState) -> void:
	current_state = new_state
	game_state_changed.emit(new_state)


func start_new_run() -> void:
	party.clear()
	current_floor = 1
	gold = 0
	run_seed = randi()
	change_state(Enums.GameState.MAP)
	party_updated.emit()


func add_to_party(character: CharacterData) -> void:
	party.append(character)
	party_updated.emit()


func remove_from_party(character: CharacterData) -> void:
	party.erase(character)
	party_updated.emit()


func add_gold(amount: int) -> void:
	gold += amount


func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false


func get_party_alive() -> Array[CharacterData]:
	return party.filter(func(c: CharacterData) -> bool: return c.is_alive())


func is_party_dead() -> bool:
	return get_party_alive().is_empty()
