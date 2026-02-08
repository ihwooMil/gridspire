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

	# Create cards for characters
	_add_basic_cards(warrior, "Strike", Enums.CardEffectType.DAMAGE, 6, 1)
	_add_basic_cards(warrior, "Defend", Enums.CardEffectType.SHIELD, 5, 1)
	_add_basic_cards(mage, "Fireball", Enums.CardEffectType.DAMAGE, 8, 1)
	_add_basic_cards(mage, "Heal", Enums.CardEffectType.HEAL, 6, 1)
	_add_basic_cards(enemy_a, "Slash", Enums.CardEffectType.DAMAGE, 5, 1)

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


func _add_basic_cards(character: CharacterData, card_name: String, effect_type: Enums.CardEffectType, value: int, cost: int) -> void:
	for i: int in 4:
		var card := CardData.new()
		card.id = "%s_%s_%d" % [character.id, card_name.to_lower(), i]
		card.card_name = card_name
		card.energy_cost = cost
		card.range_max = 3 if effect_type == Enums.CardEffectType.DAMAGE else 0
		card.target_type = Enums.TargetType.SINGLE_ENEMY if effect_type == Enums.CardEffectType.DAMAGE else Enums.TargetType.SELF
		var eff := CardEffect.new()
		eff.effect_type = effect_type
		eff.value = value
		card.effects.append(eff)
		card.description = "%s: %d" % [card_name, value]
		character.starting_deck.append(card)


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
