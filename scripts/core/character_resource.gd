## Defines a character (player or enemy) with stats, position, and a deck.
## Used as both a data template and runtime state during battle.
class_name CharacterData
extends Resource

@export var id: String = ""
@export var character_name: String = ""
@export var faction: Enums.Faction = Enums.Faction.PLAYER

## Base stats
@export var max_hp: int = 50
@export var current_hp: int = 50
@export var speed: int = 100  ## Lower = acts sooner on the timeline
@export var energy_per_turn: int = 3
@export var move_range: int = 3  ## Tiles the character can move per turn

## Grid position (set at runtime)
@export var grid_position: Vector2i = Vector2i.ZERO

## Deck composition — array of CardData resources
@export var starting_deck: Array[CardData] = []

## Runtime status effects: Dictionary mapping StatusEffect enum -> {stacks: int, duration: int}
var status_effects: Dictionary = {}

## Visual
@export var portrait: Texture2D = null
@export var battle_sprite: Texture2D = null


func is_alive() -> bool:
	return current_hp > 0


func take_damage(amount: int) -> int:
	var shield: int = get_status_stacks(Enums.StatusEffect.SHIELD)
	var remaining: int = amount
	if shield > 0:
		var absorbed: int = mini(shield, remaining)
		modify_status(Enums.StatusEffect.SHIELD, -absorbed)
		remaining -= absorbed
	current_hp = maxi(current_hp - remaining, 0)
	return remaining


func heal(amount: int) -> void:
	current_hp = mini(current_hp + amount, max_hp)


func get_status_stacks(effect: Enums.StatusEffect) -> int:
	if status_effects.has(effect):
		return status_effects[effect].stacks
	return 0


func modify_status(effect: Enums.StatusEffect, stacks: int, duration: int = -1) -> void:
	if not status_effects.has(effect):
		status_effects[effect] = {"stacks": 0, "duration": 0}
	status_effects[effect].stacks += stacks
	if duration >= 0:
		status_effects[effect].duration = duration
	if status_effects[effect].stacks <= 0:
		status_effects.erase(effect)


func tick_status_effects() -> void:
	var to_remove: Array[Enums.StatusEffect] = []
	for effect: Enums.StatusEffect in status_effects.keys():
		status_effects[effect].duration -= 1
		if status_effects[effect].duration <= 0:
			to_remove.append(effect)
	for effect: Enums.StatusEffect in to_remove:
		status_effects.erase(effect)


func get_effective_speed() -> int:
	var spd: int = speed
	if get_status_stacks(Enums.StatusEffect.HASTE) > 0:
		spd = int(spd * 0.75)
	if get_status_stacks(Enums.StatusEffect.SLOW) > 0:
		spd = int(spd * 1.5)
	return maxi(spd, 1)
