## BattleScene — Self-contained battle coordinator.
## Reads GameManager.current_encounter to configure enemies and grid.
## Contains BattleHUD, GridContainer, and manages damage popups.
extends Node2D

@onready var battle_hud: BattleHUD = $UI/BattleHUD
@onready var grid_container: Node2D = $GridContainer
@onready var battle_result: BattleResultScreen = $UI/BattleResult


func _ready() -> void:
	BattleManager.character_damaged.connect(_on_character_damaged)
	BattleManager.character_healed.connect(_on_character_healed)
	BattleManager.character_died.connect(_on_character_died)

	# Wire up card targeting
	battle_hud.targeting_requested.connect(_on_targeting_requested)
	grid_container.target_selected.connect(_on_target_selected)

	# Start the battle from encounter data
	_start_battle()


func _start_battle() -> void:
	var encounter: EncounterData = GameManager.current_encounter
	var players: Array[CharacterData] = GameManager.get_party_alive()

	if players.is_empty():
		push_warning("BattleScene: No alive party members")
		return

	# Build enemies from encounter data
	var enemies: Array[CharacterData] = []
	if encounter:
		for enemy_id: String in encounter.enemy_ids:
			var enemy := _create_enemy(enemy_id)
			if enemy:
				enemies.append(enemy)

	# Fallback: if no encounter data, create a test goblin
	if enemies.is_empty():
		var goblin := CharacterData.new()
		goblin.id = "goblin_1"
		goblin.character_name = "Goblin"
		goblin.max_hp = 30
		goblin.current_hp = 30
		goblin.speed = 90
		goblin.energy_per_turn = 2
		goblin.move_range = 2
		goblin.faction = Enums.Faction.ENEMY
		_load_deck(goblin, "res://resources/cards/warrior/", [
			"warrior_strike", "warrior_strike", "warrior_strike",
			"warrior_cleave",
			"warrior_heavy_blow",
		])
		enemies.append(goblin)

	# Initialize grid
	var grid_w: int = encounter.grid_width if encounter else 10
	var grid_h: int = encounter.grid_height if encounter else 8
	GridManager.initialize_grid(grid_w, grid_h)

	# Add some obstacle tiles
	_place_obstacles(grid_w, grid_h)

	# Place players on left side
	var player_start_col: int = 1
	for i: int in players.size():
		var row: int = (grid_h / 2) - (players.size() / 2) + i
		row = clampi(row, 0, grid_h - 1)
		# Reset grid position for battle
		GridManager.place_character(players[i], Vector2i(player_start_col, row))
		grid_container.ensure_character_sprite(players[i])

	# Place enemies on right side
	var enemy_start_col: int = grid_w - 2
	for i: int in enemies.size():
		var row: int = (grid_h / 2) - (enemies.size() / 2) + i
		row = clampi(row, 0, grid_h - 1)
		GridManager.place_character(enemies[i], Vector2i(enemy_start_col, row))
		grid_container.ensure_character_sprite(enemies[i])

	BattleManager.start_battle(players, enemies)


func _create_enemy(enemy_id: String) -> CharacterData:
	# Load enemy template from resources
	var path: String = "res://resources/characters/" + enemy_id + ".tres"
	var template: CharacterData = load(path) as CharacterData
	if template == null:
		push_warning("BattleScene: Failed to load enemy: " + path)
		return null

	# Duplicate so we have a fresh instance
	var enemy: CharacterData = template.duplicate(true)
	enemy.current_hp = enemy.max_hp
	enemy.faction = Enums.Faction.ENEMY
	enemy.status_effects.clear()

	# If enemy has no starting deck, load one based on their id
	if enemy.starting_deck.is_empty():
		_load_enemy_deck(enemy)

	return enemy


func _load_enemy_deck(enemy: CharacterData) -> void:
	var base: String = "res://resources/cards/enemies/"
	match enemy.id:
		"goblin":
			_load_deck(enemy, base, [
				"goblin_slash", "goblin_slash",
				"goblin_stab", "goblin_dodge", "goblin_throw",
			])
		"slime":
			_load_deck(enemy, base, [
				"slime_acid_touch", "slime_acid_touch",
				"slime_shield", "slime_toxic_splash", "slime_ooze",
			])
		"skeleton_archer":
			_load_deck(enemy, base, [
				"archer_bone_arrow", "archer_bone_arrow", "archer_bone_arrow",
				"archer_piercing_shot", "archer_quick_shot",
			])
		"bandit":
			_load_deck(enemy, base, [
				"bandit_slash", "bandit_slash",
				"bandit_cheap_shot", "bandit_ambush", "bandit_evade",
			])
		"orc_warchief":
			_load_deck(enemy, base, [
				"warchief_heavy_strike", "warchief_heavy_strike",
				"warchief_cleave", "warchief_war_cry",
				"warchief_iron_hide", "warchief_ground_slam",
			])
		"dark_knight":
			_load_deck(enemy, base, [
				"dark_knight_slash", "dark_knight_slash",
				"dark_knight_shield_wall", "dark_knight_crushing_blow",
				"dark_knight_taunt", "dark_knight_fortify",
			])
		"necromancer":
			_load_deck(enemy, base, [
				"necro_shadow_bolt", "necro_shadow_bolt",
				"necro_curse", "necro_dark_wave",
				"necro_bone_shield", "necro_soul_sap",
			])
		"dragon_whelp":
			_load_deck(enemy, base, [
				"dragon_claw", "dragon_claw",
				"dragon_fire_breath", "dragon_tail_swipe",
				"dragon_wing_buffet", "dragon_scale_armor", "dragon_intimidate",
			])
		"lich_king":
			_load_deck(enemy, base, [
				"lich_death_bolt", "lich_death_bolt",
				"lich_frost_nova", "lich_curse_of_agony",
				"lich_dark_ritual", "lich_necrotic_wave",
				"lich_bone_armor", "lich_stun_gaze",
			])
		_:
			# Legacy fallback for old monsters (orc, skeleton_mage)
			if "mage" in enemy.id or "skeleton" in enemy.id:
				_load_deck(enemy, "res://resources/cards/mage/", [
					"mage_arcane_bolt", "mage_arcane_bolt", "mage_arcane_bolt",
					"mage_frost_bolt", "mage_fireball",
				])
			else:
				_load_deck(enemy, "res://resources/cards/warrior/", [
					"warrior_strike", "warrior_strike", "warrior_strike",
					"warrior_cleave", "warrior_heavy_blow",
				])


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


func _place_obstacles(grid_w: int, grid_h: int) -> void:
	# Simple obstacle placement
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(GameManager.current_floor)
	var wall_count: int = rng.randi_range(2, 4)
	for i: int in wall_count:
		var x: int = rng.randi_range(3, grid_w - 3)
		var y: int = rng.randi_range(1, grid_h - 2)
		GridManager.set_tile_type(Vector2i(x, y), Enums.TileType.WALL)
	# Add a hazard tile
	var hx: int = rng.randi_range(3, grid_w - 3)
	var hy: int = rng.randi_range(1, grid_h - 2)
	GridManager.set_tile_type(Vector2i(hx, hy), Enums.TileType.HAZARD)


func _on_character_damaged(character: CharacterData, amount: int) -> void:
	_spawn_damage_popup(character, amount, true)


func _on_character_healed(character: CharacterData, amount: int) -> void:
	_spawn_damage_popup(character, amount, false)


func _on_character_died(character: CharacterData) -> void:
	grid_container.remove_character_sprite(character)
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
