## Displays the turn order as a horizontal race bar.
## Character markers move left → right. The first to reach the right edge acts.
## After acting, the marker resets to the far left and the race continues.
class_name TimelineBar
extends Control

const BAR_HEIGHT: float = 40.0
const MARKER_RADIUS: float = 16.0
const BAR_MARGIN: float = 20.0
## Base animation speed — actual speed is BASE_ANIM_SPEED * (100 / effective_speed).
const BASE_ANIM_SPEED: float = 2.0

## Smooth display positions: CharacterData → float (0.0 = left, 1.0 = right)
var _display_positions: Dictionary = {}
## Target positions computed from timeline tick data
var _target_positions: Dictionary = {}
## Currently acting character (shown at finish line)
var _active_character: CharacterData = null


func _ready() -> void:
	custom_minimum_size = Vector2(200, 48)
	BattleManager.battle_started.connect(_on_battle_started)
	BattleManager.timeline_updated.connect(_on_timeline_updated)
	BattleManager.turn_started.connect(_on_turn_started)
	BattleManager.turn_ended.connect(_on_turn_ended)
	BattleManager.character_died.connect(_on_character_died)
	resized.connect(queue_redraw)


func _exit_tree() -> void:
	if BattleManager.battle_started.is_connected(_on_battle_started):
		BattleManager.battle_started.disconnect(_on_battle_started)
	if BattleManager.timeline_updated.is_connected(_on_timeline_updated):
		BattleManager.timeline_updated.disconnect(_on_timeline_updated)
	if BattleManager.turn_started.is_connected(_on_turn_started):
		BattleManager.turn_started.disconnect(_on_turn_started)
	if BattleManager.turn_ended.is_connected(_on_turn_ended):
		BattleManager.turn_ended.disconnect(_on_turn_ended)
	if BattleManager.character_died.is_connected(_on_character_died):
		BattleManager.character_died.disconnect(_on_character_died)


func _on_battle_started() -> void:
	_display_positions.clear()
	_target_positions.clear()
	_active_character = null
	_recalculate_targets()
	# Snap display to targets on battle start (no animation needed)
	for ch: CharacterData in _target_positions.keys():
		_display_positions[ch] = _target_positions[ch]
	queue_redraw()


func _on_timeline_updated() -> void:
	_recalculate_targets()
	queue_redraw()


func _on_turn_started(character: CharacterData) -> void:
	_active_character = character
	# Snap active character to finish line (right edge)
	_display_positions[character] = 1.0
	_target_positions[character] = 1.0
	queue_redraw()


func _on_turn_ended(character: CharacterData) -> void:
	# Character finished acting → reset to far left
	_display_positions[character] = 0.0
	_active_character = null
	queue_redraw()


func _on_character_died(character: CharacterData) -> void:
	_display_positions.erase(character)
	_target_positions.erase(character)
	queue_redraw()


## Compute target positions from timeline tick data.
## Lowest tick → 1.0 (right, about to act). Highest tick → 0.0 (left, just acted).
func _recalculate_targets() -> void:
	var entries: Array[TimelineEntry] = BattleManager.get_timeline_entries()
	if entries.is_empty():
		_target_positions.clear()
		return

	# Find tick range among alive characters
	var min_tick: int = 999999
	var max_tick: int = 0
	for entry: TimelineEntry in entries:
		if entry.character.is_alive():
			min_tick = mini(min_tick, entry.current_tick)
			max_tick = maxi(max_tick, entry.current_tick)

	var tick_range: int = maxi(max_tick - min_tick, 1)

	for entry: TimelineEntry in entries:
		if not entry.character.is_alive():
			_target_positions.erase(entry.character)
			_display_positions.erase(entry.character)
			continue

		# Lowest tick = rightmost (1.0), highest tick = leftmost (0.0)
		var t: float = 1.0 - float(entry.current_tick - min_tick) / float(tick_range)
		_target_positions[entry.character] = clampf(t, 0.0, 1.0)

		# Initialize display position for newly added characters (e.g. summons)
		if not _display_positions.has(entry.character):
			_display_positions[entry.character] = _target_positions[entry.character]

	# Remove characters no longer in the timeline
	for ch: CharacterData in _display_positions.keys():
		if not _target_positions.has(ch):
			_display_positions.erase(ch)


func _process(delta: float) -> void:
	if _target_positions.is_empty():
		return

	var any_moved: bool = false
	for ch: CharacterData in _target_positions.keys():
		if not _display_positions.has(ch):
			_display_positions[ch] = _target_positions[ch]
			any_moved = true
			continue

		var current: float = _display_positions[ch]
		var target: float = _target_positions[ch]
		if absf(current - target) > 0.001:
			# Speed proportional to character speed: lower speed stat → faster marker
			var speed_factor: float = 100.0 / maxf(float(ch.get_effective_speed()), 1.0)
			var move_speed: float = BASE_ANIM_SPEED * speed_factor
			_display_positions[ch] = move_toward(current, target, move_speed * delta)
			any_moved = true
		else:
			_display_positions[ch] = target

	if any_moved:
		queue_redraw()


func _draw() -> void:
	var bar_width: float = size.x - BAR_MARGIN * 2.0
	if bar_width <= 0.0:
		return

	var bar_y: float = size.y / 2.0

	# Bar background
	var bar_rect := Rect2(BAR_MARGIN, bar_y - BAR_HEIGHT / 2.0, bar_width, BAR_HEIGHT)
	draw_rect(bar_rect, Color(0.12, 0.12, 0.18, 0.85), true)
	draw_rect(bar_rect, Color(0.3, 0.3, 0.4, 0.6), false, 1.0)

	# Finish line at right edge
	var finish_x: float = BAR_MARGIN + bar_width - 2.0
	draw_line(
		Vector2(finish_x, bar_y - BAR_HEIGHT / 2.0),
		Vector2(finish_x, bar_y + BAR_HEIGHT / 2.0),
		Color(1.0, 0.9, 0.2, 0.4), 2.0
	)

	# Draw markers
	for ch: CharacterData in _display_positions.keys():
		if not ch.is_alive():
			continue
		var t: float = _display_positions[ch]
		var x: float = BAR_MARGIN + MARKER_RADIUS + t * (bar_width - MARKER_RADIUS * 2.0)
		var center := Vector2(x, bar_y)

		# Faction color
		var fill_color: Color
		if ch.faction == Enums.Faction.PLAYER:
			fill_color = Color(0.15, 0.3, 0.6)
		else:
			fill_color = Color(0.5, 0.12, 0.12)

		# Draw filled circle
		draw_circle(center, MARKER_RADIUS, fill_color)

		# Border: yellow for active character, gray for others
		if _active_character and ch == _active_character:
			draw_arc(center, MARKER_RADIUS, 0.0, TAU, 32, Color(1.0, 0.9, 0.2), 2.5)
		else:
			draw_arc(center, MARKER_RADIUS, 0.0, TAU, 32, Color(0.5, 0.5, 0.6, 0.6), 1.0)

		# Character initial letter
		var initial: String = ch.character_name.left(1).to_upper()
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 14
		var text_size: Vector2 = font.get_string_size(initial, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos := Vector2(center.x - text_size.x / 2.0, center.y + text_size.y / 4.0)
		draw_string(font, text_pos, initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
