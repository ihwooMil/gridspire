## Holds the complete state of an ongoing battle.
## Used by BattleManager to track characters, timeline, and turn flow.
class_name BattleState
extends Resource

var player_characters: Array[CharacterData] = []
var enemy_characters: Array[CharacterData] = []
var timeline: Array[TimelineEntry] = []
var current_entry: TimelineEntry = null
var turn_phase: Enums.TurnPhase = Enums.TurnPhase.DRAW
var turn_number: int = 0
var battle_active: bool = false


func get_all_characters() -> Array[CharacterData]:
	var all: Array[CharacterData] = []
	all.append_array(player_characters)
	all.append_array(enemy_characters)
	return all


func get_active_character() -> CharacterData:
	if current_entry:
		return current_entry.character
	return null


## Build the initial timeline from all characters sorted by speed.
func build_timeline() -> void:
	timeline.clear()
	for ch: CharacterData in get_all_characters():
		if ch.is_alive():
			timeline.append(TimelineEntry.new(ch))
	sort_timeline()


## Sort timeline so the character with the lowest tick goes first.
func sort_timeline() -> void:
	timeline.sort_custom(func(a: TimelineEntry, b: TimelineEntry) -> bool:
		return a.current_tick < b.current_tick
	)


## Get the next character to act and advance the timeline.
func advance_timeline() -> CharacterData:
	sort_timeline()
	# Remove dead characters
	timeline = timeline.filter(func(e: TimelineEntry) -> bool:
		return e.character.is_alive()
	)
	if timeline.is_empty():
		return null
	current_entry = timeline[0]
	return current_entry.character


## After the current character finishes their turn, push them forward.
func end_current_turn() -> void:
	if current_entry:
		current_entry.advance()
		current_entry = null
	turn_number += 1


## Check win/loss conditions. Returns "win", "lose", or "ongoing".
func check_battle_result() -> String:
	var players_alive: bool = player_characters.any(func(c: CharacterData) -> bool:
		return c.is_alive()
	)
	var enemies_alive: bool = enemy_characters.any(func(c: CharacterData) -> bool:
		return c.is_alive()
	)
	if not enemies_alive:
		return "win"
	if not players_alive:
		return "lose"
	return "ongoing"


## Get a preview of the next N turns for the timeline UI.
func get_timeline_preview(count: int = 10) -> Array[CharacterData]:
	var preview: Array[CharacterData] = []
	# Create temporary copies of tick values
	var temp_ticks: Dictionary = {}
	for entry: TimelineEntry in timeline:
		if entry.character.is_alive():
			temp_ticks[entry] = entry.current_tick

	for i: int in count:
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
