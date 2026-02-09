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
	battle_hud.drag_drop_requested.connect(_on_drag_drop)
	battle_hud.drag_hover_updated.connect(_on_drag_hover)
	grid_container.target_selected.connect(_on_target_selected)
	BattleManager.summon_added.connect(_on_summon_added)

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

	# Dynamic tile size: fit grid to available screen area with 2:1 ratio
	var available_w: float = 1280.0 - 90.0  # right margin for graveyard/end turn
	var available_h: float = 720.0 - 50.0 - 180.0  # top bar + bottom UI
	var tile_h: float = floorf(available_h / grid_h)
	var tile_w: float = tile_h * 2.0  # enforce 2:1 ratio
	# Clamp if grid exceeds available width
	if tile_w * grid_w > available_w:
		tile_w = floorf(available_w / grid_w)
		tile_h = tile_w / 2.0
	GridManager.tile_size = Vector2(tile_w, tile_h)

	# Center grid horizontally
	var grid_pixel_w: float = tile_w * grid_w
	var center_x: float = (1280.0 - grid_pixel_w) / 2.0
	grid_container.position = Vector2(center_x, 50.0)

	# Top 2 rows are decorative wall tiles
	for x: int in grid_w:
		GridManager.set_tile_type(Vector2i(x, 0), Enums.TileType.WALL)
		GridManager.set_tile_type(Vector2i(x, 1), Enums.TileType.WALL)

	# Add some obstacle tiles
	_place_obstacles(grid_w, grid_h)

	# Place players on left side (skip wall rows 0-1)
	var player_start_col: int = 1
	for i: int in players.size():
		var row: int = (grid_h / 2) - (players.size() / 2) + i
		row = clampi(row, 2, grid_h - 1)
		# Reset grid position for battle
		GridManager.place_character(players[i], Vector2i(player_start_col, row))
		grid_container.ensure_character_sprite(players[i])

	# Place enemies on right side (skip wall rows 0-1)
	var enemy_start_col: int = grid_w - 2
	for i: int in enemies.size():
		_apply_difficulty_modifiers(enemies[i])
		var row: int = (grid_h / 2) - (enemies.size() / 2) + i
		row = clampi(row, 2, grid_h - 1)
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
		var y: int = rng.randi_range(2, grid_h - 2)
		GridManager.set_tile_type(Vector2i(x, y), Enums.TileType.WALL)
	# Add a hazard tile
	var hx: int = rng.randi_range(3, grid_w - 3)
	var hy: int = rng.randi_range(2, grid_h - 2)
	GridManager.set_tile_type(Vector2i(hx, hy), Enums.TileType.HAZARD)


func _exit_tree() -> void:
	if BattleManager.character_damaged.is_connected(_on_character_damaged):
		BattleManager.character_damaged.disconnect(_on_character_damaged)
	if BattleManager.character_healed.is_connected(_on_character_healed):
		BattleManager.character_healed.disconnect(_on_character_healed)
	if BattleManager.character_died.is_connected(_on_character_died):
		BattleManager.character_died.disconnect(_on_character_died)
	if BattleManager.summon_added.is_connected(_on_summon_added):
		BattleManager.summon_added.disconnect(_on_summon_added)


func _on_summon_added(summon: CharacterData, _owner: CharacterData) -> void:
	grid_container.ensure_character_sprite(summon)


func _apply_difficulty_modifiers(enemy: CharacterData) -> void:
	var mods: Dictionary = GameManager.get_difficulty_modifiers()
	enemy.max_hp = int(enemy.max_hp * mods.enemy_hp_mult)
	enemy.current_hp = enemy.max_hp


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


func _on_drag_drop(card: CardData, source: CharacterData, drop_pos: Vector2) -> void:
	grid_container.exit_targeting_mode()

	# Convert screen position to grid local, then to grid coordinates
	var local_pos: Vector2 = grid_container.to_local(drop_pos)
	var grid_pos: Vector2i = GridManager.world_to_grid(local_pos)

	# Auto-target cards: play only when dropped above the card hand area
	match card.target_type:
		Enums.TargetType.SELF, Enums.TargetType.NONE, Enums.TargetType.ALL_ALLIES, Enums.TargetType.ALL_ENEMIES:
			var viewport_h: float = get_viewport_rect().size.y
			if drop_pos.y < viewport_h * 0.6:
				var targets: Array = BattleManager.get_valid_targets(card, source)
				if not targets.is_empty():
					BattleManager.play_card(card, source, targets[0])
			return

	# Manual target cards: check if drop landed on a valid target
	if not GridManager.grid.has(grid_pos):
		return

	# Check range
	var in_range_tiles: Array[Vector2i] = GridManager.get_tiles_in_range(
		source.grid_position, card.range_min, card.range_max
	)
	if grid_pos not in in_range_tiles:
		return

	var tile: GridTile = GridManager.get_tile(grid_pos)
	var target: Variant = null

	match card.target_type:
		Enums.TargetType.SINGLE_ENEMY:
			if tile and tile.occupant and tile.occupant.faction == Enums.Faction.ENEMY and tile.occupant.is_alive():
				target = tile.occupant
		Enums.TargetType.SINGLE_ALLY:
			if tile and tile.occupant and tile.occupant.faction == Enums.Faction.PLAYER and tile.occupant.is_alive():
				target = tile.occupant
		Enums.TargetType.TILE, Enums.TargetType.AREA:
			target = grid_pos

	if target != null:
		BattleManager.play_card(card, source, target)


func _on_drag_hover(screen_pos: Vector2) -> void:
	grid_container.update_drag_hover(screen_pos)


func _spawn_damage_popup(character: CharacterData, amount: int, is_damage: bool) -> void:
	var popup := DamagePopup.new()
	var world_pos: Vector2 = GridManager.grid_to_world(character.grid_position)
	popup.setup(amount, is_damage, world_pos)
	grid_container.add_child(popup)
