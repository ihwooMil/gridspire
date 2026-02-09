## GameManager — Global autoload singleton.
## Manages high-level game state, party roster, and scene transitions.
extends Node

signal game_state_changed(new_state: Enums.GameState)
signal party_updated()
signal gold_changed(new_amount: int)

var current_state: Enums.GameState = Enums.GameState.MAIN_MENU
var party: Array[CharacterData] = []
var current_floor: int = 1
var gold: int = 0
var run_seed: int = 0

## Map and encounter state for the current run
var current_map: MapData = null
var current_encounter: EncounterData = null

## Difficulty / Ascension system
var difficulty: int = 0  # 0 = Normal, 1-20 = Ascension levels
var max_unlocked_difficulty: int = 0


func _ready() -> void:
	run_seed = randi()


func change_state(new_state: Enums.GameState) -> void:
	current_state = new_state
	game_state_changed.emit(new_state)


func start_new_run() -> void:
	party.clear()
	current_floor = 1
	var mods: Dictionary = get_difficulty_modifiers()
	gold = mods.starting_gold
	run_seed = randi()
	current_encounter = null

	change_state(Enums.GameState.CHARACTER_SELECT)
	party_updated.emit()
	gold_changed.emit(gold)


func start_new_run_with_character(id: String) -> void:
	party.clear()
	current_floor = 1
	var mods: Dictionary = get_difficulty_modifiers()
	gold = mods.starting_gold
	run_seed = randi()

	_create_character(id)

	# Apply starting HP penalty from difficulty
	if mods.starting_hp_penalty > 0:
		for ch: CharacterData in party:
			ch.current_hp = maxi(ch.current_hp - mods.starting_hp_penalty, 1)

	current_map = MapGenerator.generate(run_seed)
	current_encounter = null

	change_state(Enums.GameState.MAP)
	party_updated.emit()
	gold_changed.emit(gold)


func _create_character(id: String) -> void:
	var character := CharacterData.new()
	character.id = id
	character.faction = Enums.Faction.PLAYER

	match id:
		"warrior":
			character.character_name = "Warrior"
			character.max_hp = 60
			character.current_hp = 60
			character.speed = 100
			character.energy_per_turn = 3
			character.move_range = 3
			_load_deck(character, "res://resources/cards/warrior/", [
				"warrior_strike", "warrior_strike",
				"warrior_defend", "warrior_defend",
				"warrior_cleave",
				"warrior_heavy_blow",
				"warrior_shield_bash",
				"warrior_battle_cry",
				"warrior_iron_will",
				"warrior_pommel_strike",
			])
		"mage":
			character.character_name = "Mage"
			character.max_hp = 40
			character.current_hp = 40
			character.speed = 80
			character.energy_per_turn = 3
			character.move_range = 2
			_load_deck(character, "res://resources/cards/mage/", [
				"mage_arcane_bolt", "mage_arcane_bolt",
				"mage_mana_shield", "mage_mana_shield",
				"mage_fireball",
				"mage_frost_bolt",
				"mage_healing_light",
				"mage_arcane_intellect",
				"mage_spark",
				"mage_chain_lightning",
			])
		"rogue":
			character.character_name = "Rogue"
			character.max_hp = 45
			character.current_hp = 45
			character.speed = 70
			character.energy_per_turn = 3
			character.move_range = 4
			_load_deck(character, "res://resources/cards/rogue/", [
				"rogue_quick_slash", "rogue_quick_slash",
				"rogue_dodge", "rogue_dodge",
				"rogue_backstab",
				"rogue_poison_blade",
				"rogue_shiv",
				"rogue_shadow_step",
				"rogue_sprint",
				"rogue_throwing_knife",
			])
		_:
			push_warning("Unknown character id: " + id)
			return

	add_to_party(character)


func _load_deck(character: CharacterData, base_path: String, card_ids: Array) -> void:
	for card_id: String in card_ids:
		var path: String = base_path + card_id + ".tres"
		var card: CardData = load(path) as CardData
		if card:
			var copy: CardData = card.duplicate(true)
			copy.id = "%s_%s_%d" % [character.id, card_id, character.starting_deck.size()]
			character.starting_deck.append(copy)
		else:
			push_warning("Failed to load card: " + path)


func add_to_party(character: CharacterData) -> void:
	if party.size() >= 3:
		push_warning("Party is full (max 3 members)")
		return
	party.append(character)
	party_updated.emit()


func remove_from_party(character: CharacterData) -> void:
	party.erase(character)
	party_updated.emit()


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		return true
	return false


func get_party_alive() -> Array[CharacterData]:
	return party.filter(func(c: CharacterData) -> bool: return c.is_alive())


func is_party_dead() -> bool:
	return get_party_alive().is_empty()


## Get companion choices: character classes not yet in party.
func get_companion_choices() -> Array[String]:
	var all_classes: Array[String] = ["warrior", "mage", "rogue"]
	var party_ids: Array[String] = []
	for ch: CharacterData in party:
		party_ids.append(ch.id)
	var choices: Array[String] = []
	for cls: String in all_classes:
		if cls not in party_ids:
			choices.append(cls)
	return choices


## Recruit a companion and add to party.
func recruit_companion(id: String) -> void:
	_create_character(id)


## Unlock next difficulty on run completion.
func on_run_complete() -> void:
	max_unlocked_difficulty = mini(difficulty + 1, 20)


## Get difficulty modifiers based on current ascension level.
func get_difficulty_modifiers() -> Dictionary:
	var mods: Dictionary = {
		"enemy_hp_mult": 1.0,
		"enemy_damage_mult": 1.0,
		"starting_gold": 100,
		"starting_hp_penalty": 0,
		"elite_count_bonus": 0,
		"boss_hp_mult": 1.0,
	}
	if difficulty >= 1: mods.enemy_hp_mult = 1.1
	if difficulty >= 3: mods.enemy_damage_mult = 1.1
	if difficulty >= 5: mods.starting_gold = 80
	if difficulty >= 7: mods.starting_hp_penalty = 5
	if difficulty >= 10: mods.elite_count_bonus = 1
	if difficulty >= 13: mods.enemy_hp_mult = 1.25
	if difficulty >= 16: mods.enemy_damage_mult = 1.25
	if difficulty >= 18: mods.boss_hp_mult = 1.5
	if difficulty >= 20: mods.starting_hp_penalty = 10
	return mods
