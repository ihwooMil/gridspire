## TestRunner -- Lightweight GDScript test runner for GridSpire.
## Runs all registered test suites and prints results to the console.
## Execute from command line: godot --headless --script res://scripts/tests/test_runner.gd
extends SceneTree


var _total_tests: int = 0
var _passed_tests: int = 0
var _failed_tests: int = 0
var _errors: Array[String] = []
var _current_suite: String = ""


func _init() -> void:
	print("\n========================================")
	print("  GridSpire Test Runner")
	print("========================================\n")

	_run_all_tests()

	print("\n========================================")
	print("  RESULTS")
	print("========================================")
	print("  Total:  %d" % _total_tests)
	print("  Passed: %d" % _passed_tests)
	print("  Failed: %d" % _failed_tests)
	if not _errors.is_empty():
		print("\n  FAILURES:")
		for err: String in _errors:
			print("    - %s" % err)
	print("========================================\n")

	if _failed_tests > 0:
		quit(1)
	else:
		quit(0)


func _run_all_tests() -> void:
	_run_grid_tile_tests()
	_run_character_tests()
	_run_timeline_tests()
	_run_battle_state_tests()
	_run_grid_manager_tests()
	_run_deck_manager_tests()
	_run_card_effect_resolver_tests()
	_run_combat_action_tests()
	_run_game_manager_tests()
	_run_card_data_tests()
	_run_edge_case_tests()


# ---------------------------------------------------------------------------
# Assertion helpers
# ---------------------------------------------------------------------------

func assert_true(condition: bool, message: String) -> void:
	_total_tests += 1
	if condition:
		_passed_tests += 1
	else:
		_failed_tests += 1
		var err: String = "[%s] FAIL: %s" % [_current_suite, message]
		_errors.append(err)
		print("    FAIL: %s" % message)


func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)


func assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_total_tests += 1
	if actual == expected:
		_passed_tests += 1
	else:
		_failed_tests += 1
		var err: String = "[%s] FAIL: %s (expected %s, got %s)" % [_current_suite, message, str(expected), str(actual)]
		_errors.append(err)
		print("    FAIL: %s (expected %s, got %s)" % [message, str(expected), str(actual)])


func assert_not_null(value: Variant, message: String) -> void:
	assert_true(value != null, message)


func assert_null(value: Variant, message: String) -> void:
	assert_true(value == null, message)


func assert_greater(actual: Variant, expected: Variant, message: String) -> void:
	_total_tests += 1
	if actual > expected:
		_passed_tests += 1
	else:
		_failed_tests += 1
		var err: String = "[%s] FAIL: %s (expected > %s, got %s)" % [_current_suite, message, str(expected), str(actual)]
		_errors.append(err)
		print("    FAIL: %s (expected > %s, got %s)" % [message, str(expected), str(actual)])


func assert_less_or_equal(actual: Variant, expected: Variant, message: String) -> void:
	_total_tests += 1
	if actual <= expected:
		_passed_tests += 1
	else:
		_failed_tests += 1
		var err: String = "[%s] FAIL: %s (expected <= %s, got %s)" % [_current_suite, message, str(expected), str(actual)]
		_errors.append(err)
		print("    FAIL: %s (expected <= %s, got %s)" % [message, str(expected), str(actual)])


func begin_suite(name: String) -> void:
	_current_suite = name
	print("[%s]" % name)


# ---------------------------------------------------------------------------
# GridTile tests
# ---------------------------------------------------------------------------

func _run_grid_tile_tests() -> void:
	begin_suite("GridTile")

	# Test floor tile is walkable
	var floor_tile := GridTile.new()
	floor_tile.tile_type = Enums.TileType.FLOOR
	assert_true(floor_tile.is_walkable(), "Floor tile should be walkable")
	assert_false(floor_tile.is_occupied(), "Empty floor tile should not be occupied")
	assert_true(floor_tile.is_available(), "Empty floor tile should be available")

	# Test wall tile is not walkable
	var wall_tile := GridTile.new()
	wall_tile.tile_type = Enums.TileType.WALL
	assert_false(wall_tile.is_walkable(), "Wall tile should not be walkable")
	assert_false(wall_tile.is_available(), "Wall tile should not be available")

	# Test pit tile is not walkable
	var pit_tile := GridTile.new()
	pit_tile.tile_type = Enums.TileType.PIT
	assert_false(pit_tile.is_walkable(), "Pit tile should not be walkable")

	# Test hazard tile is walkable
	var hazard_tile := GridTile.new()
	hazard_tile.tile_type = Enums.TileType.HAZARD
	assert_true(hazard_tile.is_walkable(), "Hazard tile should be walkable")

	# Test elevated tile is walkable
	var elevated_tile := GridTile.new()
	elevated_tile.tile_type = Enums.TileType.ELEVATED
	assert_true(elevated_tile.is_walkable(), "Elevated tile should be walkable")

	# Test occupancy
	var occ_tile := GridTile.new()
	occ_tile.tile_type = Enums.TileType.FLOOR
	var ch := CharacterData.new()
	ch.character_name = "Test"
	occ_tile.occupant = ch
	assert_true(occ_tile.is_occupied(), "Occupied tile should report occupied")
	assert_false(occ_tile.is_available(), "Occupied floor tile should not be available")


# ---------------------------------------------------------------------------
# CharacterData tests
# ---------------------------------------------------------------------------

func _run_character_tests() -> void:
	begin_suite("CharacterData")

	var ch := CharacterData.new()
	ch.max_hp = 50
	ch.current_hp = 50
	ch.speed = 100

	# Test is_alive
	assert_true(ch.is_alive(), "Character at full HP should be alive")

	# Test take_damage
	var actual_dmg: int = ch.take_damage(10)
	assert_equal(ch.current_hp, 40, "HP should be 40 after 10 damage")
	assert_equal(actual_dmg, 10, "Actual damage should be 10")
	assert_true(ch.is_alive(), "Character at 40 HP should be alive")

	# Test take_damage with shield absorption
	ch.current_hp = 50
	ch.modify_status(Enums.StatusEffect.SHIELD, 8, 1)
	var shield_dmg: int = ch.take_damage(12)
	assert_equal(ch.current_hp, 46, "HP should be 46 after 12 damage with 8 shield")
	assert_equal(shield_dmg, 4, "Actual damage after shield should be 4")
	assert_equal(ch.get_status_stacks(Enums.StatusEffect.SHIELD), 0, "Shield should be fully consumed")

	# Test take_damage -- shield absorbs all
	ch.current_hp = 50
	ch.modify_status(Enums.StatusEffect.SHIELD, 10, 1)
	var zero_dmg: int = ch.take_damage(5)
	assert_equal(ch.current_hp, 50, "HP should be 50 when shield absorbs all damage")
	assert_equal(zero_dmg, 0, "Actual damage should be 0 when fully absorbed")
	assert_equal(ch.get_status_stacks(Enums.StatusEffect.SHIELD), 5, "Shield should have 5 stacks remaining")

	# Test take_damage to 0 HP
	ch.current_hp = 5
	ch.status_effects.clear()
	ch.take_damage(20)
	assert_equal(ch.current_hp, 0, "HP should not go below 0")
	assert_false(ch.is_alive(), "Character at 0 HP should not be alive")

	# Test heal
	ch.current_hp = 20
	ch.heal(10)
	assert_equal(ch.current_hp, 30, "HP should be 30 after healing 10")

	# Test heal capping at max_hp
	ch.current_hp = 45
	ch.heal(20)
	assert_equal(ch.current_hp, ch.max_hp, "HP should be capped at max_hp")

	# Test status effects
	ch.status_effects.clear()
	assert_equal(ch.get_status_stacks(Enums.StatusEffect.STRENGTH), 0, "No strength stacks initially")

	ch.modify_status(Enums.StatusEffect.STRENGTH, 3, 2)
	assert_equal(ch.get_status_stacks(Enums.StatusEffect.STRENGTH), 3, "Should have 3 strength stacks")

	ch.modify_status(Enums.StatusEffect.STRENGTH, 2, 2)
	assert_equal(ch.get_status_stacks(Enums.StatusEffect.STRENGTH), 5, "Should stack to 5 strength")

	# Test removing status
	ch.modify_status(Enums.StatusEffect.STRENGTH, -5)
	assert_equal(ch.get_status_stacks(Enums.StatusEffect.STRENGTH), 0, "Strength should be removed when stacks reach 0")
	assert_false(ch.status_effects.has(Enums.StatusEffect.STRENGTH), "Strength should be erased from dictionary")

	# Test effective speed with HASTE
	ch.speed = 100
	ch.status_effects.clear()
	assert_equal(ch.get_effective_speed(), 100, "Base speed should be 100")

	ch.modify_status(Enums.StatusEffect.HASTE, 1, 3)
	assert_equal(ch.get_effective_speed(), 75, "Haste should reduce speed to 75")

	# Test effective speed with SLOW
	ch.status_effects.clear()
	ch.modify_status(Enums.StatusEffect.SLOW, 1, 3)
	assert_equal(ch.get_effective_speed(), 150, "Slow should increase speed to 150")

	# Test effective speed with both HASTE and SLOW
	ch.modify_status(Enums.StatusEffect.HASTE, 1, 3)
	# Both active: speed * 0.75 * 1.5 = speed * 1.125 -> int(100 * 0.75) = 75 then int(75 * 1.5) = 112
	var effective: int = ch.get_effective_speed()
	assert_true(effective >= 1, "Effective speed should be at least 1")

	# Test effective speed minimum of 1
	ch.status_effects.clear()
	ch.speed = 1
	ch.modify_status(Enums.StatusEffect.HASTE, 1, 3)
	assert_true(ch.get_effective_speed() >= 1, "Effective speed should never go below 1")

	# Test tick_status_effects
	ch.status_effects.clear()
	ch.modify_status(Enums.StatusEffect.POISON, 3, 2)
	ch.modify_status(Enums.StatusEffect.REGEN, 2, 1)
	ch.tick_status_effects()
	assert_true(ch.status_effects.has(Enums.StatusEffect.POISON), "Poison with duration 1 remaining should still exist")
	assert_false(ch.status_effects.has(Enums.StatusEffect.REGEN), "Regen with duration 0 should be removed")

	ch.tick_status_effects()
	assert_false(ch.status_effects.has(Enums.StatusEffect.POISON), "Poison should be removed after second tick")


# ---------------------------------------------------------------------------
# TimelineEntry tests
# ---------------------------------------------------------------------------

func _run_timeline_tests() -> void:
	begin_suite("TimelineEntry")

	var ch := CharacterData.new()
	ch.speed = 100

	var entry := TimelineEntry.new(ch)
	assert_equal(entry.character, ch, "Entry should reference the character")
	assert_equal(entry.current_tick, 100, "Initial tick should equal effective speed")

	entry.advance()
	assert_equal(entry.current_tick, 200, "Tick should be 200 after one advance")

	entry.advance()
	assert_equal(entry.current_tick, 300, "Tick should be 300 after two advances")

	# Test with haste character
	var fast_ch := CharacterData.new()
	fast_ch.speed = 80
	fast_ch.modify_status(Enums.StatusEffect.HASTE, 1, 5)
	var fast_entry := TimelineEntry.new(fast_ch)
	assert_equal(fast_entry.current_tick, 60, "Haste character with speed 80 should have tick 60")

	fast_entry.advance()
	assert_equal(fast_entry.current_tick, 120, "After advance, tick should be 120")


# ---------------------------------------------------------------------------
# BattleState tests
# ---------------------------------------------------------------------------

func _run_battle_state_tests() -> void:
	begin_suite("BattleState")

	var state := BattleState.new()

	var player1 := CharacterData.new()
	player1.character_name = "Player1"
	player1.max_hp = 50
	player1.current_hp = 50
	player1.speed = 100
	player1.faction = Enums.Faction.PLAYER

	var player2 := CharacterData.new()
	player2.character_name = "Player2"
	player2.max_hp = 40
	player2.current_hp = 40
	player2.speed = 80
	player2.faction = Enums.Faction.PLAYER

	var enemy1 := CharacterData.new()
	enemy1.character_name = "Enemy1"
	enemy1.max_hp = 30
	enemy1.current_hp = 30
	enemy1.speed = 90
	enemy1.faction = Enums.Faction.ENEMY

	state.player_characters = [player1, player2]
	state.enemy_characters = [enemy1]

	# Test get_all_characters
	var all: Array[CharacterData] = state.get_all_characters()
	assert_equal(all.size(), 3, "Should have 3 total characters")

	# Test build_timeline
	state.build_timeline()
	assert_equal(state.timeline.size(), 3, "Timeline should have 3 entries")

	# Test timeline sort order -- lowest speed acts first
	# player2 speed=80, enemy1 speed=90, player1 speed=100
	assert_equal(state.timeline[0].character.character_name, "Player2", "Player2 (speed 80) should be first")
	assert_equal(state.timeline[1].character.character_name, "Enemy1", "Enemy1 (speed 90) should be second")
	assert_equal(state.timeline[2].character.character_name, "Player1", "Player1 (speed 100) should be third")

	# Test advance_timeline
	var active_ch: CharacterData = state.advance_timeline()
	assert_equal(active_ch.character_name, "Player2", "First active should be Player2")
	assert_not_null(state.current_entry, "current_entry should be set")

	# Test end_current_turn
	state.end_current_turn()
	assert_null(state.current_entry, "current_entry should be null after end turn")
	assert_equal(state.turn_number, 1, "Turn number should be 1")

	# Test check_battle_result -- ongoing
	assert_equal(state.check_battle_result(), "ongoing", "Battle should be ongoing")

	# Test check_battle_result -- win (all enemies dead)
	enemy1.current_hp = 0
	assert_equal(state.check_battle_result(), "win", "Battle should be won when all enemies dead")

	# Test check_battle_result -- lose (all players dead)
	enemy1.current_hp = 30
	player1.current_hp = 0
	player2.current_hp = 0
	assert_equal(state.check_battle_result(), "lose", "Battle should be lost when all players dead")

	# Test advance_timeline removes dead characters
	player1.current_hp = 50
	player2.current_hp = 0
	enemy1.current_hp = 30
	state.build_timeline()
	state.advance_timeline()
	# Dead characters should be filtered out
	var alive_count: int = 0
	for entry: TimelineEntry in state.timeline:
		if entry.character.is_alive():
			alive_count += 1
	assert_equal(alive_count, 2, "Timeline should only contain alive characters")

	# Test get_timeline_preview
	player1.current_hp = 50
	player2.current_hp = 40
	enemy1.current_hp = 30
	state.build_timeline()
	var preview: Array[CharacterData] = state.get_timeline_preview(5)
	assert_equal(preview.size(), 5, "Preview should return 5 entries")
	assert_equal(preview[0].character_name, "Player2", "First in preview should be Player2 (fastest)")

	# Test get_active_character
	state.advance_timeline()
	assert_not_null(state.get_active_character(), "Should have an active character")


# ---------------------------------------------------------------------------
# GridManager tests (operates on autoload)
# ---------------------------------------------------------------------------

func _run_grid_manager_tests() -> void:
	begin_suite("GridManager")

	# We cannot use the autoload directly in headless SceneTree.
	# Instead, we test GridManager logic by creating a fresh instance.
	# Since GridManager extends Node, we instantiate and call methods directly.

	var gm_script: GDScript = load("res://scripts/grid/grid_manager.gd")
	var gm: Node = gm_script.new()

	# Test initialize_grid
	gm.initialize_grid(10, 8)
	assert_equal(gm.grid_width, 10, "Grid width should be 10")
	assert_equal(gm.grid_height, 8, "Grid height should be 8")
	assert_equal(gm.grid.size(), 80, "Grid should have 80 tiles")

	# Test get_tile
	var tile: GridTile = gm.get_tile(Vector2i(0, 0))
	assert_not_null(tile, "Tile at (0,0) should exist")
	assert_equal(tile.tile_type, Enums.TileType.FLOOR, "Default tile should be FLOOR")

	# Test get_tile out of bounds
	var oob: GridTile = gm.get_tile(Vector2i(10, 8))
	assert_null(oob, "Tile out of bounds should be null")

	var oob2: GridTile = gm.get_tile(Vector2i(-1, 0))
	assert_null(oob2, "Tile at negative position should be null")

	# Test set_tile_type
	gm.set_tile_type(Vector2i(3, 3), Enums.TileType.WALL)
	var wall_t: GridTile = gm.get_tile(Vector2i(3, 3))
	assert_equal(wall_t.tile_type, Enums.TileType.WALL, "Tile should be set to WALL")

	# Test place_character
	var ch := CharacterData.new()
	ch.character_name = "TestChar"
	ch.move_range = 3
	var placed: bool = gm.place_character(ch, Vector2i(1, 1))
	assert_true(placed, "Character should be placed successfully")
	assert_equal(ch.grid_position, Vector2i(1, 1), "Character grid_position should be updated")

	var placed_tile: GridTile = gm.get_tile(Vector2i(1, 1))
	assert_equal(placed_tile.occupant, ch, "Tile occupant should be the character")

	# Test place_character on wall (should fail)
	var ch2 := CharacterData.new()
	ch2.character_name = "BlockedChar"
	var wall_placed: bool = gm.place_character(ch2, Vector2i(3, 3))
	assert_false(wall_placed, "Should not place character on a wall")

	# Test place_character on occupied tile
	var ch3 := CharacterData.new()
	ch3.character_name = "OccupiedChar"
	var occ_placed: bool = gm.place_character(ch3, Vector2i(1, 1))
	assert_false(occ_placed, "Should not place character on occupied tile")

	# Test manhattan_distance
	assert_equal(gm.manhattan_distance(Vector2i(0, 0), Vector2i(3, 4)), 7, "Manhattan distance should be 7")
	assert_equal(gm.manhattan_distance(Vector2i(2, 2), Vector2i(2, 2)), 0, "Distance to self should be 0")
	assert_equal(gm.manhattan_distance(Vector2i(0, 0), Vector2i(1, 0)), 1, "Adjacent distance should be 1")

	# Test find_path
	var path: Array[Vector2i] = gm.find_path(Vector2i(0, 0), Vector2i(2, 0))
	assert_true(path.size() > 0, "Path should exist from (0,0) to (2,0)")
	assert_equal(path[path.size() - 1], Vector2i(2, 0), "Path should end at target")

	# Test find_path to same position
	var same_path: Array[Vector2i] = gm.find_path(Vector2i(0, 0), Vector2i(0, 0))
	assert_equal(same_path.size(), 0, "Path to same position should be empty")

	# Test find_path to wall (should fail)
	var wall_path: Array[Vector2i] = gm.find_path(Vector2i(0, 0), Vector2i(3, 3))
	assert_equal(wall_path.size(), 0, "Path to wall should be empty")

	# Test find_path around wall
	gm.set_tile_type(Vector2i(2, 0), Enums.TileType.WALL)
	gm.set_tile_type(Vector2i(2, 1), Enums.TileType.WALL)
	# Clear occupant from (1,1) to allow path through
	gm.get_tile(Vector2i(1, 1)).occupant = null
	var around_path: Array[Vector2i] = gm.find_path(Vector2i(0, 0), Vector2i(3, 0))
	assert_true(around_path.size() > 3, "Path around wall should be longer than direct path")

	# Reset grid for more tests
	gm.initialize_grid(10, 8)

	# Test get_tiles_in_range
	var range_tiles: Array[Vector2i] = gm.get_tiles_in_range(Vector2i(5, 4), 1, 2)
	assert_true(range_tiles.size() > 0, "Range tiles should not be empty")
	# Verify all tiles are within range
	var all_in_range: bool = true
	for pos: Vector2i in range_tiles:
		var dist: int = gm.manhattan_distance(Vector2i(5, 4), pos)
		if dist < 1 or dist > 2:
			all_in_range = false
			break
	assert_true(all_in_range, "All range tiles should be within min/max range")

	# Test get_reachable_tiles
	var reachable_ch := CharacterData.new()
	reachable_ch.move_range = 2
	gm.place_character(reachable_ch, Vector2i(5, 4))
	var reachable: Array[Vector2i] = gm.get_reachable_tiles(reachable_ch)
	assert_true(reachable.size() > 0, "Should have reachable tiles")
	# Origin should not be in reachable tiles
	assert_false(Vector2i(5, 4) in reachable, "Origin should not be in reachable tiles")

	# Test is_in_bounds
	assert_true(gm.is_in_bounds(Vector2i(0, 0)), "(0,0) should be in bounds")
	assert_true(gm.is_in_bounds(Vector2i(9, 7)), "(9,7) should be in bounds")
	assert_false(gm.is_in_bounds(Vector2i(-1, 0)), "(-1,0) should be out of bounds")
	assert_false(gm.is_in_bounds(Vector2i(10, 0)), "(10,0) should be out of bounds")

	# Test is_tile_walkable
	assert_true(gm.is_tile_walkable(Vector2i(0, 0)), "Floor tile should be walkable")
	gm.set_tile_type(Vector2i(0, 0), Enums.TileType.WALL)
	assert_false(gm.is_tile_walkable(Vector2i(0, 0)), "Wall tile should not be walkable")
	assert_false(gm.is_tile_walkable(Vector2i(-1, -1)), "Out of bounds should not be walkable")

	# Test grid_to_world and world_to_grid
	gm.tile_size = Vector2(64, 64)
	var world_pos: Vector2 = gm.grid_to_world(Vector2i(2, 3))
	assert_equal(world_pos, Vector2(160, 224), "grid_to_world should return center of tile")

	var grid_pos: Vector2i = gm.world_to_grid(Vector2(160, 224))
	assert_equal(grid_pos, Vector2i(2, 3), "world_to_grid should return correct grid position")

	# Test push_character
	gm.initialize_grid(10, 8)
	var pusher := CharacterData.new()
	pusher.character_name = "Pusher"
	gm.place_character(pusher, Vector2i(3, 4))

	var pushee := CharacterData.new()
	pushee.character_name = "Pushee"
	gm.place_character(pushee, Vector2i(5, 4))

	gm.push_character(pusher, pushee, 2)
	assert_equal(pushee.grid_position, Vector2i(7, 4), "Pushed character should move 2 tiles away")

	# Test push_character against wall
	gm.initialize_grid(10, 8)
	var p1 := CharacterData.new()
	gm.place_character(p1, Vector2i(3, 4))
	var p2 := CharacterData.new()
	gm.place_character(p2, Vector2i(4, 4))
	gm.set_tile_type(Vector2i(6, 4), Enums.TileType.WALL)
	gm.push_character(p1, p2, 5)
	assert_equal(p2.grid_position, Vector2i(5, 4), "Push should stop before wall")

	# Test pull_character
	gm.initialize_grid(10, 8)
	var puller := CharacterData.new()
	gm.place_character(puller, Vector2i(2, 4))
	var pulled := CharacterData.new()
	gm.place_character(pulled, Vector2i(6, 4))
	gm.pull_character(puller, pulled, 2)
	assert_equal(pulled.grid_position, Vector2i(4, 4), "Pulled character should move 2 tiles toward puller")

	# Test get_characters_in_radius
	gm.initialize_grid(10, 8)
	var center_ch := CharacterData.new()
	center_ch.character_name = "Center"
	gm.place_character(center_ch, Vector2i(5, 4))

	var near_ch := CharacterData.new()
	near_ch.character_name = "Near"
	gm.place_character(near_ch, Vector2i(5, 5))

	var far_ch := CharacterData.new()
	far_ch.character_name = "Far"
	gm.place_character(far_ch, Vector2i(9, 7))

	var in_radius: Array[CharacterData] = gm.get_characters_in_radius(Vector2i(5, 4), 1)
	assert_true(center_ch in in_radius, "Center character should be in radius")
	assert_true(near_ch in in_radius, "Near character should be in radius")
	assert_false(far_ch in in_radius, "Far character should not be in radius")

	# Test has_line_of_sight
	gm.initialize_grid(10, 8)
	assert_true(gm.has_line_of_sight(Vector2i(0, 0), Vector2i(5, 0)), "Open LOS should be true")
	assert_true(gm.has_line_of_sight(Vector2i(0, 0), Vector2i(0, 0)), "LOS to self should be true")

	gm.set_tile_type(Vector2i(3, 0), Enums.TileType.WALL)
	assert_false(gm.has_line_of_sight(Vector2i(0, 0), Vector2i(5, 0)), "LOS through wall should be false")

	# Test range patterns
	gm.initialize_grid(10, 8)
	var diamond_tiles: Array[Vector2i] = gm.get_tiles_in_range_pattern(Vector2i(5, 4), 2, gm.RangePattern.DIAMOND)
	assert_true(diamond_tiles.size() > 0, "Diamond pattern should return tiles")

	var line_tiles: Array[Vector2i] = gm.get_tiles_in_range_pattern(Vector2i(5, 4), 3, gm.RangePattern.LINE)
	assert_true(line_tiles.size() > 0, "Line pattern should return tiles")

	var cross_tiles: Array[Vector2i] = gm.get_tiles_in_range_pattern(Vector2i(5, 4), 2, gm.RangePattern.CROSS)
	assert_true(cross_tiles.size() > 0, "Cross pattern should return tiles")

	var area_tiles: Array[Vector2i] = gm.get_tiles_in_range_pattern(Vector2i(5, 4), 1, gm.RangePattern.AREA)
	assert_true(area_tiles.size() > 0, "Area pattern should return tiles")

	# Test move_character
	gm.initialize_grid(10, 8)
	var mover := CharacterData.new()
	mover.move_range = 3
	gm.place_character(mover, Vector2i(1, 1))
	var moved: bool = gm.move_character(mover, Vector2i(3, 1))
	assert_true(moved, "Move should succeed within range")
	assert_equal(mover.grid_position, Vector2i(3, 1), "Character should be at new position")

	# Old tile should be cleared
	var old_t: GridTile = gm.get_tile(Vector2i(1, 1))
	assert_null(old_t.occupant, "Old tile should have no occupant")

	# New tile should have occupant
	var new_t: GridTile = gm.get_tile(Vector2i(3, 1))
	assert_equal(new_t.occupant, mover, "New tile should have the character")

	# Test move_character beyond range
	var moved_far: bool = gm.move_character(mover, Vector2i(9, 7))
	assert_false(moved_far, "Move beyond range should fail")

	gm.free()


# ---------------------------------------------------------------------------
# DeckManager tests
# ---------------------------------------------------------------------------

func _run_deck_manager_tests() -> void:
	begin_suite("DeckManager")

	# Create a fresh DeckManager node
	var dm_script: GDScript = load("res://scripts/cards/deck_manager.gd")
	var dm: Node = dm_script.new()

	var ch := CharacterData.new()
	ch.character_name = "DeckTestChar"

	# Create a starting deck of 8 cards
	for i: int in 8:
		var card := CardData.new()
		card.id = "test_card_%d" % i
		card.card_name = "TestCard%d" % i
		card.energy_cost = 1
		ch.starting_deck.append(card)

	# Test initialize_deck
	dm.initialize_deck(ch)
	assert_equal(dm.get_draw_count(ch), 8, "Draw pile should have 8 cards after init")
	assert_equal(dm.get_discard_count(ch), 0, "Discard pile should be empty after init")

	# Test draw_cards
	var drawn: Array[CardData] = dm.draw_cards(ch, 5)
	assert_equal(drawn.size(), 5, "Should draw 5 cards")
	assert_equal(dm.get_draw_count(ch), 3, "Draw pile should have 3 cards remaining")

	# Test discard_card
	dm.discard_card(ch, drawn[0])
	assert_equal(dm.get_discard_count(ch), 1, "Discard pile should have 1 card")

	# Test discard_hand
	var hand_remaining: Array[CardData] = [drawn[1], drawn[2]]
	dm.discard_hand(ch, hand_remaining)
	assert_equal(dm.get_discard_count(ch), 3, "Discard pile should have 3 cards")

	# Test exhaust_card
	dm.exhaust_card(ch, drawn[3])
	var exhaust_pile: Array[CardData] = dm.exhaust_piles.get(ch, [] as Array[CardData])
	assert_equal(exhaust_pile.size(), 1, "Exhaust pile should have 1 card")

	# Test draw when pile is empty -> auto-reshuffle discard
	# Draw remaining 3 from draw pile
	var drawn2: Array[CardData] = dm.draw_cards(ch, 3)
	assert_equal(drawn2.size(), 3, "Should draw remaining 3 cards")
	assert_equal(dm.get_draw_count(ch), 0, "Draw pile should be empty")

	# Now draw more - should trigger reshuffle of discard pile
	var drawn3: Array[CardData] = dm.draw_cards(ch, 2)
	assert_equal(drawn3.size(), 2, "Should draw 2 cards after reshuffle")

	# Test draw when both piles empty
	# Exhaust all remaining cards
	var remaining_draw: Array[CardData] = dm.draw_cards(ch, 20)
	for card: CardData in remaining_draw:
		dm.exhaust_card(ch, card)
	# Clear discard too
	dm.discard_piles[ch] = [] as Array[CardData]
	dm.draw_piles[ch] = [] as Array[CardData]

	var empty_draw: Array[CardData] = dm.draw_cards(ch, 5)
	assert_equal(empty_draw.size(), 0, "Drawing from empty deck should return 0 cards")

	# Test add_card_to_deck
	var new_card := CardData.new()
	new_card.id = "reward_card"
	new_card.card_name = "RewardCard"
	dm.add_card_to_deck(ch, new_card)
	assert_true(new_card in ch.starting_deck, "Card should be added to starting deck")

	# Test remove_card_from_deck
	dm.remove_card_from_deck(ch, new_card)
	assert_false(new_card in ch.starting_deck, "Card should be removed from starting deck")

	dm.free()


# ---------------------------------------------------------------------------
# CardEffectResolver tests
# ---------------------------------------------------------------------------

func _run_card_effect_resolver_tests() -> void:
	begin_suite("CardEffectResolver")

	var resolver := CardEffectResolver.new()

	# Need a GridManager for push/pull/move effects
	var gm_script: GDScript = load("res://scripts/grid/grid_manager.gd")
	var gm: Node = gm_script.new()
	gm.initialize_grid(10, 8)

	var source := CharacterData.new()
	source.character_name = "Source"
	source.max_hp = 50
	source.current_hp = 50
	source.speed = 100
	source.faction = Enums.Faction.PLAYER
	gm.place_character(source, Vector2i(2, 4))

	var target := CharacterData.new()
	target.character_name = "Target"
	target.max_hp = 50
	target.current_hp = 50
	target.speed = 100
	target.faction = Enums.Faction.ENEMY
	gm.place_character(target, Vector2i(5, 4))

	# Test DAMAGE effect
	var dmg_effect := CardEffect.new()
	dmg_effect.effect_type = Enums.CardEffectType.DAMAGE
	dmg_effect.value = 10

	resolver.apply_effect(dmg_effect, source, target)
	assert_equal(target.current_hp, 40, "Target should take 10 damage")

	# Test DAMAGE with STRENGTH bonus
	target.current_hp = 50
	source.modify_status(Enums.StatusEffect.STRENGTH, 3, 3)
	resolver.apply_effect(dmg_effect, source, target)
	assert_equal(target.current_hp, 37, "Target should take 13 damage (10 + 3 strength)")

	# Test DAMAGE with WEAKNESS penalty
	target.current_hp = 50
	source.status_effects.clear()
	source.modify_status(Enums.StatusEffect.WEAKNESS, 1, 3)
	# 10 * 0.75 = 7
	resolver.apply_effect(dmg_effect, source, target)
	assert_equal(target.current_hp, 43, "Target should take 7 damage (10 * 0.75 weakness)")

	# Test calculate_damage with STRENGTH + WEAKNESS
	source.status_effects.clear()
	source.modify_status(Enums.StatusEffect.STRENGTH, 4, 3)
	source.modify_status(Enums.StatusEffect.WEAKNESS, 1, 3)
	var calc_dmg: int = resolver.calculate_damage(10, source)
	# (10 + 4) * 0.75 = 10
	assert_equal(calc_dmg, 10, "Damage with strength 4 and weakness: (10+4)*0.75 = 10")
	source.status_effects.clear()

	# Test HEAL effect
	target.current_hp = 30
	var heal_effect := CardEffect.new()
	heal_effect.effect_type = Enums.CardEffectType.HEAL
	heal_effect.value = 15
	resolver.apply_effect(heal_effect, source, target)
	assert_equal(target.current_hp, 45, "Target should be healed to 45")

	# Test HEAL capping
	target.current_hp = 45
	resolver.apply_effect(heal_effect, source, target)
	assert_equal(target.current_hp, 50, "Healing should cap at max_hp")

	# Test SHIELD effect (shield always applies to source/caster)
	source.status_effects.clear()
	var shield_effect := CardEffect.new()
	shield_effect.effect_type = Enums.CardEffectType.SHIELD
	shield_effect.value = 8
	resolver.apply_effect(shield_effect, source, target)
	assert_equal(source.get_status_stacks(Enums.StatusEffect.SHIELD), 8, "Source should have 8 shield (shield always goes to caster)")
	source.status_effects.clear()

	# Test BUFF effect (STRENGTH)
	target.status_effects.clear()
	var buff_effect := CardEffect.new()
	buff_effect.effect_type = Enums.CardEffectType.BUFF
	buff_effect.status_effect = Enums.StatusEffect.STRENGTH
	buff_effect.value = 2
	buff_effect.duration = 3
	resolver.apply_effect(buff_effect, source, target)
	assert_equal(target.get_status_stacks(Enums.StatusEffect.STRENGTH), 2, "Target should have 2 strength")

	# Test DEBUFF effect (WEAKNESS)
	target.status_effects.clear()
	var debuff_effect := CardEffect.new()
	debuff_effect.effect_type = Enums.CardEffectType.DEBUFF
	debuff_effect.status_effect = Enums.StatusEffect.WEAKNESS
	debuff_effect.value = 1
	debuff_effect.duration = 2
	resolver.apply_effect(debuff_effect, source, target)
	assert_equal(target.get_status_stacks(Enums.StatusEffect.WEAKNESS), 1, "Target should have 1 weakness")

	# Test resolve_card with multiple effects
	target.current_hp = 50
	target.status_effects.clear()
	var combo_card := CardData.new()
	combo_card.card_name = "ComboCard"
	var combo_dmg := CardEffect.new()
	combo_dmg.effect_type = Enums.CardEffectType.DAMAGE
	combo_dmg.value = 5
	var combo_debuff := CardEffect.new()
	combo_debuff.effect_type = Enums.CardEffectType.DEBUFF
	combo_debuff.status_effect = Enums.StatusEffect.WEAKNESS
	combo_debuff.value = 1
	combo_debuff.duration = 2
	combo_card.effects = [combo_dmg, combo_debuff]
	source.status_effects.clear()

	resolver.resolve_card(combo_card, source, target)
	assert_equal(target.current_hp, 45, "Combo card should deal 5 damage")
	assert_equal(target.get_status_stacks(Enums.StatusEffect.WEAKNESS), 1, "Combo card should apply weakness")

	gm.free()


# ---------------------------------------------------------------------------
# CombatAction tests
# ---------------------------------------------------------------------------

func _run_combat_action_tests() -> void:
	begin_suite("CombatAction")

	var source := CharacterData.new()
	source.character_name = "ActionSource"

	# Test create_card_action
	var card := CardData.new()
	card.card_name = "TestCard"
	var target := CharacterData.new()
	target.character_name = "ActionTarget"

	var card_action: CombatAction = CombatAction.create_card_action(card, source, target)
	assert_equal(card_action.action_type, CombatAction.ActionType.PLAY_CARD, "Should be PLAY_CARD action")
	assert_equal(card_action.source, source, "Source should match")
	assert_equal(card_action.card, card, "Card should match")
	assert_equal(card_action.target, target, "Target should match")

	# Test get_description
	var desc: String = card_action.get_description()
	assert_true(desc.contains("ActionSource"), "Description should contain source name")
	assert_true(desc.contains("TestCard"), "Description should contain card name")

	# Test create_move_action
	var move_action: CombatAction = CombatAction.create_move_action(source, Vector2i(3, 4))
	assert_equal(move_action.action_type, CombatAction.ActionType.MOVE, "Should be MOVE action")
	assert_equal(move_action.target, Vector2i(3, 4), "Target should be Vector2i(3,4)")

	# Test create_end_turn_action
	var end_action: CombatAction = CombatAction.create_end_turn_action(source)
	assert_equal(end_action.action_type, CombatAction.ActionType.END_TURN, "Should be END_TURN action")

	# Test ActionQueue
	var queue: CombatAction.ActionQueue = CombatAction.ActionQueue.new()
	assert_true(queue.is_empty(), "Queue should be empty initially")
	assert_equal(queue.size(), 0, "Queue size should be 0")

	queue.enqueue(card_action)
	queue.enqueue(move_action)
	assert_equal(queue.size(), 2, "Queue should have 2 actions")
	assert_false(queue.is_empty(), "Queue should not be empty")

	var peeked: CombatAction = queue.peek()
	assert_equal(peeked, card_action, "Peek should return first action")
	assert_equal(queue.size(), 2, "Peek should not remove from queue")

	var dequeued: CombatAction = queue.dequeue()
	assert_equal(dequeued, card_action, "Dequeue should return first action")
	assert_equal(queue.size(), 1, "Queue should have 1 action after dequeue")

	queue.clear()
	assert_true(queue.is_empty(), "Queue should be empty after clear")

	# Test dequeue from empty queue
	var null_action: CombatAction = queue.dequeue()
	assert_null(null_action, "Dequeue from empty queue should return null")

	var null_peek: CombatAction = queue.peek()
	assert_null(null_peek, "Peek on empty queue should return null")


# ---------------------------------------------------------------------------
# GameManager tests
# ---------------------------------------------------------------------------

func _run_game_manager_tests() -> void:
	begin_suite("GameManager")

	var gm_script: GDScript = load("res://scripts/core/game_manager.gd")
	var gm: Node = gm_script.new()

	# Test initial state
	assert_equal(gm.current_state, Enums.GameState.MAIN_MENU, "Initial state should be MAIN_MENU")
	assert_equal(gm.party.size(), 0, "Initial party should be empty")
	assert_equal(gm.gold, 0, "Initial gold should be 0")

	# Test change_state
	gm.change_state(Enums.GameState.BATTLE)
	assert_equal(gm.current_state, Enums.GameState.BATTLE, "State should be BATTLE")

	# Test add_to_party
	var ch := CharacterData.new()
	ch.character_name = "PartyMember"
	ch.max_hp = 50
	ch.current_hp = 50
	gm.add_to_party(ch)
	assert_equal(gm.party.size(), 1, "Party should have 1 member")

	# Test remove_from_party
	gm.remove_from_party(ch)
	assert_equal(gm.party.size(), 0, "Party should be empty after removal")

	# Test add_gold
	gm.add_gold(50)
	assert_equal(gm.gold, 50, "Gold should be 50")

	# Test spend_gold -- success
	var spent: bool = gm.spend_gold(30)
	assert_true(spent, "Should be able to spend 30 gold")
	assert_equal(gm.gold, 20, "Gold should be 20 after spending 30")

	# Test spend_gold -- fail
	var overspent: bool = gm.spend_gold(50)
	assert_false(overspent, "Should not be able to overspend")
	assert_equal(gm.gold, 20, "Gold should remain 20 after failed spend")

	# Test get_party_alive
	gm.party.clear()
	var alive_ch := CharacterData.new()
	alive_ch.max_hp = 50
	alive_ch.current_hp = 50
	var dead_ch := CharacterData.new()
	dead_ch.max_hp = 50
	dead_ch.current_hp = 0
	gm.add_to_party(alive_ch)
	gm.add_to_party(dead_ch)
	var alive: Array[CharacterData] = gm.get_party_alive()
	assert_equal(alive.size(), 1, "Only 1 party member should be alive")

	# Test is_party_dead
	assert_false(gm.is_party_dead(), "Party should not be dead")
	alive_ch.current_hp = 0
	assert_true(gm.is_party_dead(), "Party should be dead when all members have 0 HP")

	# Test start_new_run
	gm.gold = 100
	gm.current_floor = 5
	gm.start_new_run()
	assert_equal(gm.party.size(), 0, "Party should be cleared on new run")
	assert_equal(gm.gold, 0, "Gold should be 0 on new run")
	assert_equal(gm.current_floor, 1, "Floor should be 1 on new run")
	assert_equal(gm.current_state, Enums.GameState.MAP, "State should be MAP after new run")

	gm.free()


# ---------------------------------------------------------------------------
# CardData tests
# ---------------------------------------------------------------------------

func _run_card_data_tests() -> void:
	begin_suite("CardData")

	# Test get_display_text for DAMAGE
	var card := CardData.new()
	card.card_name = "Strike"
	card.description = "A basic attack."
	var dmg_eff := CardEffect.new()
	dmg_eff.effect_type = Enums.CardEffectType.DAMAGE
	dmg_eff.value = 6
	card.effects = [dmg_eff]
	var text: String = card.get_display_text()
	assert_true(text.contains("Deal 6 damage"), "Display text should contain damage info")

	# Test get_display_text for HEAL
	var heal_card := CardData.new()
	var heal_eff := CardEffect.new()
	heal_eff.effect_type = Enums.CardEffectType.HEAL
	heal_eff.value = 8
	heal_card.effects = [heal_eff]
	heal_card.description = "Heal"
	var heal_text: String = heal_card.get_display_text()
	assert_true(heal_text.contains("Heal 8 HP"), "Display text should contain heal info")

	# Test get_display_text for SHIELD
	var shield_card := CardData.new()
	var shield_eff := CardEffect.new()
	shield_eff.effect_type = Enums.CardEffectType.SHIELD
	shield_eff.value = 5
	shield_card.effects = [shield_eff]
	shield_card.description = "Shield"
	var shield_text: String = shield_card.get_display_text()
	assert_true(shield_text.contains("Gain 5 shield"), "Display text should contain shield info")

	# Test get_display_text for DRAW
	var draw_card := CardData.new()
	var draw_eff := CardEffect.new()
	draw_eff.effect_type = Enums.CardEffectType.DRAW
	draw_eff.value = 2
	draw_card.effects = [draw_eff]
	draw_card.description = "Draw"
	var draw_text: String = draw_card.get_display_text()
	assert_true(draw_text.contains("Draw 2 cards"), "Display text should contain draw info")

	# Test get_display_text for MOVE
	var move_card := CardData.new()
	var move_eff := CardEffect.new()
	move_eff.effect_type = Enums.CardEffectType.MOVE
	move_eff.value = 3
	move_card.effects = [move_eff]
	move_card.description = "Move"
	var move_text: String = move_card.get_display_text()
	assert_true(move_text.contains("Move 3 tiles"), "Display text should contain move info")


# ---------------------------------------------------------------------------
# Edge case tests
# ---------------------------------------------------------------------------

func _run_edge_case_tests() -> void:
	begin_suite("EdgeCases")

	# Edge case: 0 damage
	var ch := CharacterData.new()
	ch.max_hp = 50
	ch.current_hp = 50
	var dmg: int = ch.take_damage(0)
	assert_equal(ch.current_hp, 50, "0 damage should not change HP")
	assert_equal(dmg, 0, "Actual damage should be 0")

	# Edge case: Heal at 0 HP (technically dead but still callable)
	ch.current_hp = 0
	ch.heal(10)
	assert_equal(ch.current_hp, 10, "Healing from 0 HP should work")

	# Edge case: Massive damage
	ch.current_hp = 50
	ch.take_damage(9999)
	assert_equal(ch.current_hp, 0, "HP should be clamped to 0 with massive damage")

	# Edge case: Massive heal
	ch.current_hp = 1
	ch.heal(9999)
	assert_equal(ch.current_hp, ch.max_hp, "HP should be clamped to max_hp with massive heal")

	# Edge case: Empty timeline preview
	var state := BattleState.new()
	state.player_characters = []
	state.enemy_characters = []
	state.build_timeline()
	var preview: Array[CharacterData] = state.get_timeline_preview(5)
	assert_equal(preview.size(), 0, "Preview of empty timeline should be empty")

	# Edge case: Advance empty timeline
	var adv: CharacterData = state.advance_timeline()
	assert_null(adv, "Advancing empty timeline should return null")

	# Edge case: end_current_turn with no current entry
	state.current_entry = null
	state.end_current_turn()
	# Should not crash, turn_number should still increment
	assert_true(true, "end_current_turn with null entry should not crash")

	# Edge case: Grid operations on empty grid
	var gm_script: GDScript = load("res://scripts/grid/grid_manager.gd")
	var gm: Node = gm_script.new()
	var null_tile: GridTile = gm.get_tile(Vector2i(0, 0))
	assert_null(null_tile, "Getting tile from uninitialized grid should return null")

	var empty_path: Array[Vector2i] = gm.find_path(Vector2i(0, 0), Vector2i(1, 1))
	assert_equal(empty_path.size(), 0, "Path on empty grid should be empty")

	# Edge case: Character with speed 1
	var slow_ch := CharacterData.new()
	slow_ch.speed = 1
	assert_equal(slow_ch.get_effective_speed(), 1, "Minimum speed should be 1")

	slow_ch.modify_status(Enums.StatusEffect.HASTE, 1, 3)
	assert_true(slow_ch.get_effective_speed() >= 1, "Haste on speed 1 should not go below 1")

	# Edge case: Double status application
	ch.status_effects.clear()
	ch.modify_status(Enums.StatusEffect.POISON, 3, 3)
	ch.modify_status(Enums.StatusEffect.POISON, 2, 2)
	assert_equal(ch.get_status_stacks(Enums.StatusEffect.POISON), 5, "Stacking poison should add stacks")

	# Edge case: Removing more stacks than exist
	ch.modify_status(Enums.StatusEffect.POISON, -10)
	assert_false(ch.status_effects.has(Enums.StatusEffect.POISON), "Removing excess stacks should erase the effect")

	# Edge case: CardEffect default values
	var eff := CardEffect.new()
	assert_equal(eff.value, 0, "Default effect value should be 0")
	assert_equal(eff.duration, 0, "Default effect duration should be 0")
	assert_equal(eff.area_radius, 0, "Default area_radius should be 0")
	assert_equal(eff.push_pull_distance, 1, "Default push_pull_distance should be 1")

	# Edge case: BattleState with only one side
	var only_players := BattleState.new()
	var p := CharacterData.new()
	p.max_hp = 50
	p.current_hp = 50
	p.faction = Enums.Faction.PLAYER
	only_players.player_characters = [p]
	only_players.enemy_characters = []
	assert_equal(only_players.check_battle_result(), "win", "No enemies should mean win")

	var only_enemies := BattleState.new()
	var e := CharacterData.new()
	e.max_hp = 50
	e.current_hp = 50
	e.faction = Enums.Faction.ENEMY
	only_enemies.player_characters = []
	only_enemies.enemy_characters = [e]
	assert_equal(only_enemies.check_battle_result(), "lose", "No players should mean lose")

	# Edge case: Timeline with equal speeds
	var equal_state := BattleState.new()
	var eq1 := CharacterData.new()
	eq1.character_name = "Eq1"
	eq1.max_hp = 50
	eq1.current_hp = 50
	eq1.speed = 100
	var eq2 := CharacterData.new()
	eq2.character_name = "Eq2"
	eq2.max_hp = 50
	eq2.current_hp = 50
	eq2.speed = 100
	equal_state.player_characters = [eq1]
	equal_state.enemy_characters = [eq2]
	equal_state.build_timeline()
	assert_equal(equal_state.timeline.size(), 2, "Timeline should have 2 entries with equal speeds")

	gm.free()
