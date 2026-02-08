## Unit tests for TimelineSystem -- tests for the dedicated timeline manager.
## This file is imported by test_runner.gd but can also be reviewed standalone.
class_name TestTimelineSystem
extends RefCounted


static func run(runner: Node) -> void:
	runner.begin_suite("TimelineSystem")

	var ts := TimelineSystem.new()

	# Create test characters with different speeds
	var fast := CharacterData.new()
	fast.character_name = "Fast"
	fast.max_hp = 50
	fast.current_hp = 50
	fast.speed = 60

	var medium := CharacterData.new()
	medium.character_name = "Medium"
	medium.max_hp = 50
	medium.current_hp = 50
	medium.speed = 100

	var slow := CharacterData.new()
	slow.character_name = "Slow"
	slow.max_hp = 50
	slow.current_hp = 50
	slow.speed = 120

	var chars: Array[CharacterData] = [fast, medium, slow]

	# Test initialize
	ts.initialize(chars)
	runner.assert_equal(ts.entries.size(), 3, "Timeline should have 3 entries")
	runner.assert_null(ts.current_entry, "Current entry should be null after init")

	# Test sort order after init
	runner.assert_equal(ts.entries[0].character.character_name, "Fast", "Fast should be first (lowest tick)")
	runner.assert_equal(ts.entries[1].character.character_name, "Medium", "Medium should be second")
	runner.assert_equal(ts.entries[2].character.character_name, "Slow", "Slow should be third")

	# Test advance
	var first: CharacterData = ts.advance()
	runner.assert_equal(first.character_name, "Fast", "First to act should be Fast")
	runner.assert_not_null(ts.current_entry, "Current entry should be set after advance")

	# Test end_current_turn
	ts.end_current_turn()
	runner.assert_null(ts.current_entry, "Current entry should be null after end turn")
	# Fast's tick should now be 60 + 60 = 120
	var fast_entry: TimelineEntry = ts.get_entry(fast)
	runner.assert_equal(fast_entry.current_tick, 120, "Fast's tick should be 120 after end turn")

	# Test second advance -- Medium should be next (tick 100)
	var second: CharacterData = ts.advance()
	runner.assert_equal(second.character_name, "Medium", "Second to act should be Medium")
	ts.end_current_turn()
	# Medium's tick should now be 100 + 100 = 200

	# Test third advance -- Slow (120) and Fast (120) both at 120, either is valid
	var third: CharacterData = ts.advance()
	runner.assert_true(
		third.character_name == "Slow" or third.character_name == "Fast",
		"Third should be Slow or Fast (both at tick 120)"
	)
	ts.end_current_turn()

	# Test get_active_character when no entry is current
	runner.assert_null(ts.get_active_character(), "No active character when current_entry is null")

	# Test get_active_character during a turn
	ts.advance()
	runner.assert_not_null(ts.get_active_character(), "Should have active character during turn")
	ts.end_current_turn()

	# Test remove_dead
	medium.current_hp = 0  # Kill medium
	ts.remove_dead()
	var found_medium: bool = false
	for entry: TimelineEntry in ts.entries:
		if entry.character == medium:
			found_medium = true
	runner.assert_false(found_medium, "Dead character should be removed from timeline")

	# Test advance skips dead
	fast.current_hp = 50
	slow.current_hp = 50
	var after_dead: CharacterData = ts.advance()
	runner.assert_true(after_dead != medium, "Dead character should not be returned by advance")
	ts.end_current_turn()

	# Test get_preview
	medium.current_hp = 50  # Revive for preview test
	ts.initialize(chars)
	var preview: Array[CharacterData] = ts.get_preview(6)
	runner.assert_equal(preview.size(), 6, "Preview should return 6 entries")
	runner.assert_equal(preview[0].character_name, "Fast", "First in preview should be Fast")

	# Verify preview doesn't modify actual tick values
	var fast_tick_before: int = ts.entries[0].current_tick
	ts.get_preview(10)
	var fast_tick_after: int = ts.entries[0].current_tick
	runner.assert_equal(fast_tick_before, fast_tick_after, "Preview should not modify actual ticks")

	# Test get_entry
	var entry: TimelineEntry = ts.get_entry(fast)
	runner.assert_not_null(entry, "Should find entry for existing character")
	runner.assert_equal(entry.character, fast, "Entry should reference correct character")

	var missing_ch := CharacterData.new()
	var missing_entry: TimelineEntry = ts.get_entry(missing_ch)
	runner.assert_null(missing_entry, "Should return null for character not in timeline")

	# Test recalculate
	ts.initialize(chars)
	medium.current_hp = 0
	ts.recalculate()
	runner.assert_equal(ts.entries.size(), 2, "Recalculate should remove dead characters")

	# Test with empty character list
	var empty_ts := TimelineSystem.new()
	empty_ts.initialize([] as Array[CharacterData])
	runner.assert_equal(empty_ts.entries.size(), 0, "Empty init should have 0 entries")
	var null_advance: CharacterData = empty_ts.advance()
	runner.assert_null(null_advance, "Advance on empty timeline should return null")
	var empty_preview: Array[CharacterData] = empty_ts.get_preview(5)
	runner.assert_equal(empty_preview.size(), 0, "Preview of empty timeline should be empty")
