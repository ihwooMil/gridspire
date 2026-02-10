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

## Stat upgrades (permanent bonuses)
@export var bonus_max_hp: int = 0
@export var bonus_strength: int = 0
@export var bonus_energy: int = 0
@export var bonus_move_range: int = 0
@export var bonus_speed: int = 0
@export var max_summons: int = 2

## Runtime (combat)
var element_stacks: Dictionary = {}           ## {"fire": 3, "ice": 1}
var cards_played_this_turn: Array[CardData] = []
var active_summons: Array[CharacterData] = []
## Owner reference (for summons)
var summon_owner: CharacterData = null
var is_summon: bool = false


func is_alive() -> bool:
	return current_hp > 0


func take_damage(amount: int) -> int:
	# EVASION check: 15% per stack, max 75%
	var evasion_stacks: int = get_status_stacks(Enums.StatusEffect.EVASION)
	if evasion_stacks > 0:
		var dodge_chance: int = mini(evasion_stacks * 15, 75)
		if randi_range(1, 100) <= dodge_chance:
			modify_status(Enums.StatusEffect.EVASION, -1)
			return 0  # Dodged
	var shield: int = get_status_stacks(Enums.StatusEffect.SHIELD)
	var remaining: int = amount
	if shield > 0:
		var absorbed: int = mini(shield, remaining)
		modify_status(Enums.StatusEffect.SHIELD, -absorbed)
		remaining -= absorbed
	current_hp = maxi(current_hp - remaining, 0)
	return remaining


func heal(amount: int) -> int:
	if get_status_stacks(Enums.StatusEffect.UNHEALABLE) > 0:
		return 0
	var before: int = current_hp
	current_hp = mini(current_hp + amount, max_hp)
	return current_hp - before


func get_status_stacks(effect: Enums.StatusEffect) -> int:
	if status_effects.has(effect):
		return status_effects[effect].stacks
	return 0


func modify_status(effect: Enums.StatusEffect, stacks: int, duration: int = -1) -> void:
	# BERSERK blocks shield gain
	if effect == Enums.StatusEffect.SHIELD and stacks > 0:
		if get_status_stacks(Enums.StatusEffect.BERSERK) > 0:
			return
	if not status_effects.has(effect):
		status_effects[effect] = {"stacks": 0, "duration": 0}
	status_effects[effect].stacks += stacks
	if duration >= 0:
		status_effects[effect].duration = maxi(status_effects[effect].duration, duration)
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
	var spd: int = speed + bonus_speed
	if get_status_stacks(Enums.StatusEffect.HASTE) > 0:
		spd = int(spd * 0.75)
	if get_status_stacks(Enums.StatusEffect.SLOW) > 0:
		spd = int(spd * 1.5)
	return maxi(spd, 1)


func get_total_max_hp() -> int:
	return max_hp + bonus_max_hp


func get_total_energy() -> int:
	return energy_per_turn + bonus_energy


func get_total_move_range() -> int:
	return move_range + bonus_move_range


func get_tags_played_this_turn() -> PackedStringArray:
	var all_tags: PackedStringArray = []
	for card: CardData in cards_played_this_turn:
		for tag: String in card.tags:
			if tag not in all_tags:
				all_tags.append(tag)
	return all_tags


func has_tag_played(tag: String) -> bool:
	for card: CardData in cards_played_this_turn:
		if tag in card.tags:
			return true
	return false


func get_total_element_stacks() -> int:
	var total: int = 0
	for element: String in element_stacks:
		total += element_stacks[element]
	return total


func get_dominant_element() -> String:
	var best_element: String = ""
	var best_count: int = 0
	for element: String in element_stacks:
		if element_stacks[element] > best_count:
			best_count = element_stacks[element]
			best_element = element
	return best_element


func apply_stat_upgrade(upgrade: Resource) -> void:
	match upgrade.stat_type:
		0:  # MAX_HP
			bonus_max_hp += upgrade.value
			max_hp += upgrade.value
			current_hp += upgrade.value
		1:  # STRENGTH
			bonus_strength += upgrade.value
		2:  # ENERGY
			bonus_energy += upgrade.value
		3:  # MOVE_RANGE
			bonus_move_range += upgrade.value
		4:  # SPEED
			bonus_speed += upgrade.value
		5:  # MAX_SUMMONS
			max_summons += upgrade.value
