## Main scene script — entry point and top-level scene coordinator.
extends Node2D

@onready var battle_hud: BattleHUD = $UI/BattleHUD
@onready var grid_container: Node2D = $GridContainer


func _ready() -> void:
	BattleManager.character_damaged.connect(_on_character_damaged)
	BattleManager.character_healed.connect(_on_character_healed)
	BattleManager.character_died.connect(_on_character_died)

	# Wire up card targeting: HUD requests targeting → grid shows range → grid returns target
	battle_hud.targeting_requested.connect(_on_targeting_requested)
	grid_container.target_selected.connect(_on_target_selected)

	# For now, start a test battle
	_start_test_battle()


func _start_test_battle() -> void:
	# Create test characters
	var warrior := CharacterData.new()
	warrior.id = "warrior"
	warrior.character_name = "Warrior"
	warrior.max_hp = 60
	warrior.current_hp = 60
	warrior.speed = 100
	warrior.energy_per_turn = 3
	warrior.move_range = 3
	warrior.faction = Enums.Faction.PLAYER

	var mage := CharacterData.new()
	mage.id = "mage"
	mage.character_name = "Mage"
	mage.max_hp = 40
	mage.current_hp = 40
	mage.speed = 80
	mage.energy_per_turn = 3
	mage.move_range = 2
	mage.faction = Enums.Faction.PLAYER

	var enemy_a := CharacterData.new()
	enemy_a.id = "goblin_1"
	enemy_a.character_name = "Goblin"
	enemy_a.max_hp = 30
	enemy_a.current_hp = 30
	enemy_a.speed = 90
	enemy_a.energy_per_turn = 2
	enemy_a.move_range = 2
	enemy_a.faction = Enums.Faction.ENEMY

	# Load card decks from .tres resources
	_load_deck(warrior, "res://resources/cards/warrior/", [
		"warrior_strike", "warrior_strike",
		"warrior_defend", "warrior_defend",
		"warrior_cleave",
		"warrior_heavy_blow",
		"warrior_shield_bash",
		"warrior_battle_cry",
		"warrior_iron_will",
		"warrior_pommel_strike",
	])
	_load_deck(mage, "res://resources/cards/mage/", [
		"mage_arcane_bolt", "mage_arcane_bolt",
		"mage_mana_shield", "mage_mana_shield",
		"mage_fireball",
		"mage_frost_bolt",
		"mage_healing_light",
		"mage_arcane_intellect",
		"mage_spark",
		"mage_chain_lightning",
	])
	_load_deck(enemy_a, "res://resources/cards/warrior/", [
		"warrior_strike", "warrior_strike", "warrior_strike",
		"warrior_cleave",
		"warrior_heavy_blow",
	])

	# Initialize grid
	GridManager.initialize_grid(10, 8)

	# Add some obstacle tiles for visual variety
	GridManager.set_tile_type(Vector2i(4, 2), Enums.TileType.WALL)
	GridManager.set_tile_type(Vector2i(4, 3), Enums.TileType.WALL)
	GridManager.set_tile_type(Vector2i(5, 5), Enums.TileType.WALL)
	GridManager.set_tile_type(Vector2i(6, 1), Enums.TileType.HAZARD)
	GridManager.set_tile_type(Vector2i(7, 6), Enums.TileType.ELEVATED)

	GridManager.place_character(warrior, Vector2i(1, 3))
	GridManager.place_character(mage, Vector2i(1, 5))
	GridManager.place_character(enemy_a, Vector2i(8, 4))

	# Create character sprites on the grid visual
	grid_container.ensure_character_sprite(warrior)
	grid_container.ensure_character_sprite(mage)
	grid_container.ensure_character_sprite(enemy_a)

	# Start battle (BattleManager initializes decks internally)
	var players: Array[CharacterData] = [warrior, mage]
	var enemies: Array[CharacterData] = [enemy_a]
	BattleManager.start_battle(players, enemies)


func _load_deck(character: CharacterData, base_path: String, card_ids: Array) -> void:
	for card_id: String in card_ids:
		var path: String = base_path + card_id + ".tres"
		var card: CardData = load(path) as CardData
		if card:
			# Duplicate so each card in deck is a unique instance
			var copy: CardData = card.duplicate(true)
			copy.id = "%s_%s_%d" % [character.id, card_id, character.starting_deck.size()]
			character.starting_deck.append(copy)
		else:
			push_warning("Failed to load card: " + path)


func _on_character_damaged(character: CharacterData, amount: int) -> void:
	_spawn_damage_popup(character, amount, true)


func _on_character_healed(character: CharacterData, amount: int) -> void:
	_spawn_damage_popup(character, amount, false)


func _on_character_died(character: CharacterData) -> void:
	grid_container.remove_character_sprite(character)
	# Clear occupant from tile
	var tile: GridTile = GridManager.get_tile(character.grid_position)
	if tile and tile.occupant == character:
		tile.occupant = null


func _on_targeting_requested(card: CardData, source: CharacterData) -> void:
	grid_container.enter_targeting_mode(card, source)


func _on_target_selected(card: CardData, source: CharacterData, target: Variant) -> void:
	BattleManager.play_card(card, source, target)


func _spawn_damage_popup(character: CharacterData, amount: int, is_damage: bool) -> void:
	var popup := DamagePopup.new()
	var world_pos: Vector2 = GridManager.grid_to_world(character.grid_position)
	popup.setup(amount, is_damage, world_pos)
	grid_container.add_child(popup)
