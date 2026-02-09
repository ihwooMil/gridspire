## SummonManager — Creates summon creatures for the Mage class.
## Each summon is a CharacterData with its own deck and stats.
class_name SummonManager
extends RefCounted


static func create_summon(summon_id: String, owner: CharacterData) -> CharacterData:
	var summon := CharacterData.new()
	summon.is_summon = true
	summon.summon_owner = owner
	summon.faction = Enums.Faction.PLAYER

	match summon_id:
		"fire_elemental":
			summon.id = "fire_elemental"
			summon.character_name = "Fire Elemental"
			summon.max_hp = 15
			summon.current_hp = 15
			summon.speed = 90
			summon.energy_per_turn = 2
			summon.move_range = 2
			_load_summon_deck(summon, ["fire_touch", "fire_touch", "fire_touch"])

		"ice_elemental":
			summon.id = "ice_elemental"
			summon.character_name = "Ice Elemental"
			summon.max_hp = 20
			summon.current_hp = 20
			summon.speed = 110
			summon.energy_per_turn = 2
			summon.move_range = 1
			_load_summon_deck(summon, ["frost_touch", "frost_touch", "ice_shield"])

		"lightning_elemental":
			summon.id = "lightning_elemental"
			summon.character_name = "Lightning Elemental"
			summon.max_hp = 12
			summon.current_hp = 12
			summon.speed = 75
			summon.energy_per_turn = 2
			summon.move_range = 3
			_load_summon_deck(summon, ["arcane_zap", "arcane_zap", "arcane_zap"])

		"arcane_familiar":
			summon.id = "arcane_familiar"
			summon.character_name = "Arcane Familiar"
			summon.max_hp = 10
			summon.current_hp = 10
			summon.speed = 70
			summon.energy_per_turn = 1
			summon.move_range = 3
			_load_summon_deck(summon, ["arcane_zap", "arcane_zap"])

		_:
			push_warning("Unknown summon id: " + summon_id)
			return null

	return summon


static func _load_summon_deck(summon: CharacterData, card_ids: Array) -> void:
	var base_path: String = "res://resources/cards/summons/"
	for card_id: String in card_ids:
		var path: String = base_path + card_id + ".tres"
		var card: CardData = load(path) as CardData
		if card:
			var copy: CardData = card.duplicate(true)
			copy.id = "%s_%s_%d" % [summon.id, card_id, summon.starting_deck.size()]
			summon.starting_deck.append(copy)
		else:
			push_warning("Failed to load summon card: " + path)
