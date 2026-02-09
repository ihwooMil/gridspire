## TimelineSystem — Dedicated speed-based turn order system (FFX CTB-style).
## Manages timeline entries, tick advancement, and turn order preview.
## Used by BattleManager to determine who acts next.
class_name TimelineSystem
extends RefCounted

var entries: Array[TimelineEntry] = []
var current_entry: TimelineEntry = null


## Build the initial timeline from a list of characters.
func initialize(characters: Array[CharacterData]) -> void:
	entries.clear()
	current_entry = null
	for ch: CharacterData in characters:
		if ch.is_alive():
			entries.append(TimelineEntry.new(ch))
	_sort()


## Remove dead characters from the timeline.
func remove_dead() -> void:
	entries = entries.filter(func(e: TimelineEntry) -> bool:
		return e.character.is_alive()
	)


## Get the next character to act (lowest tick value).
## Returns null if no characters remain.
func advance() -> CharacterData:
	remove_dead()
	_sort()
	if entries.is_empty():
		return null
	current_entry = entries[0]
	return current_entry.character


## End the current character's turn by advancing their tick.
func end_current_turn() -> void:
	if current_entry:
		current_entry.advance()
		current_entry = null


## Get the character currently acting.
func get_active_character() -> CharacterData:
	if current_entry:
		return current_entry.character
	return null


## Get a preview of the next N turns for the timeline UI.
## Simulates future ticks without modifying actual state.
func get_preview(count: int = 10) -> Array[CharacterData]:
	var preview: Array[CharacterData] = []
	var alive_entries: Array[TimelineEntry] = entries.filter(
		func(e: TimelineEntry) -> bool: return e.character.is_alive()
	)
	if alive_entries.is_empty():
		return preview

	# Create temporary tick copies for simulation
	var temp_ticks: Dictionary = {}
	for entry: TimelineEntry in alive_entries:
		temp_ticks[entry] = entry.current_tick

	for _i: int in count:
		var best_entry: TimelineEntry = null
		var best_tick: int = 999999
		for entry: TimelineEntry in temp_ticks.keys():
			if temp_ticks[entry] < best_tick:
				best_tick = temp_ticks[entry]
				best_entry = entry
		if best_entry == null:
			break
		preview.append(best_entry.character)
		temp_ticks[best_entry] += best_entry.character.get_effective_speed()

	return preview


## Recalculate timeline order. Call after speed buffs/debuffs change.
func recalculate() -> void:
	remove_dead()
	_sort()


## Get the entry for a specific character, or null.
func get_entry(character: CharacterData) -> TimelineEntry:
	for entry: TimelineEntry in entries:
		if entry.character == character:
			return entry
	return null


## Add a new character to the timeline (e.g. summons).
func add_entry(character: CharacterData) -> void:
	# Insert at current tick + character speed so they act next cycle
	var entry := TimelineEntry.new(character)
	if current_entry:
		entry.current_tick = current_entry.current_tick + character.get_effective_speed()
	entries.append(entry)
	_sort()


## Remove a specific character from the timeline.
func remove_entry(character: CharacterData) -> void:
	entries = entries.filter(func(e: TimelineEntry) -> bool:
		return e.character != character
	)


## Sort entries by tick value ascending (lowest acts first).
func _sort() -> void:
	entries.sort_custom(func(a: TimelineEntry, b: TimelineEntry) -> bool:
		return a.current_tick < b.current_tick
	)
