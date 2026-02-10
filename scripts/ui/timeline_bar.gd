## Displays the turn order timeline as a horizontal bar at the top of the screen.
## Markers race rightward at speeds proportional to their character's speed.
## When a marker reaches the right end, that character's turn starts
## and the marker resets to the left.
class_name TimelineBar
extends Control

const BAR_HEIGHT: float = 40.0
const MARKER_RADIUS: float = 16.0
const BAR_MARGIN: float = 20.0
## Linear movement speed: 0.22 means ~4.5 seconds to traverse the full bar (0→1).
const MOVE_SPEED: float = 0.22

## Smooth display positions: CharacterData -> float (0.0 = left, 1.0 = right)
var _display_positions: Dictionary = {}
## Target positions computed from tick data
var _target_positions: Dictionary = {}
## Track which character just acted (for reset-to-left animation)
var _just_acted: CharacterData = null
## When true, a turn is active — pause marker animation.
var _turn_active: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(200, 48)
	BattleManager.timeline_updated.connect(_on_timeline_updated)
	BattleManager.turn_started.connect(_on_turn_started)
	BattleManager.turn_ended.connect(_on_turn_ended)
	BattleManager.battle_started.connect(_on_battle_started)
	resized.connect(queue_redraw)


func _exit_tree() -> void:
	if BattleManager.timeline_updated.is_connected(_on_timeline_updated):
		BattleManager.timeline_updated.disconnect(_on_timeline_updated)
	if BattleManager.turn_started.is_connected(_on_turn_started):
		BattleManager.turn_started.disconnect(_on_turn_started)
	if BattleManager.turn_ended.is_connected(_on_turn_ended):
		BattleManager.turn_ended.disconnect(_on_turn_ended)
	if BattleManager.battle_started.is_connected(_on_battle_started):
		BattleManager.battle_started.disconnect(_on_battle_started)


func _on_battle_started() -> void:
	_display_positions.clear()
	_target_positions.clear()
	_just_acted = null
	_recalculate_targets()
	# Snap display positions to targets on battle start (no animation)
	for ch: CharacterData in _target_positions.keys():
		_display_positions[ch] = _target_positions[ch]


func _on_timeline_updated() -> void:
	_recalculate_targets()


func _on_turn_started(character: CharacterData) -> void:
	_just_acted = character
	_turn_active = true
	_recalculate_targets()


func _on_turn_ended(_character: CharacterData) -> void:
	_turn_active = false


## Compute target bar positions from timeline tick data.
## Right (1.0) = about to act (lowest tick). Left (0.0) = just acted (highest tick).
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

	var tick_range: int = max_tick - min_tick
	if tick_range == 0:
		tick_range = 1

	var active_char: CharacterData = BattleManager.get_active_character()

	for entry: TimelineEntry in entries:
		if not entry.character.is_alive():
			_target_positions.erase(entry.character)
			_display_positions.erase(entry.character)
			continue

		# Invert: lowest tick → rightmost (1.0), highest tick → leftmost (0.0)
		var t: float = 1.0 - float(entry.current_tick - min_tick) / float(tick_range)
		t = clampf(t, 0.0, 1.0)

		# The active character just acted → their tick jumped up → target is now left
		# But we want them at right edge first (they "crossed the finish line")
		if entry.character == _just_acted and entry.character == active_char:
			# Set display to 1.0 (right edge) immediately, target goes to left
			if not _display_positions.has(entry.character):
				_display_positions[entry.character] = 1.0
			else:
				# Flash to right then animate left
				_display_positions[entry.character] = 1.0

		_target_positions[entry.character] = t

		# Initialize display position for new characters
		if not _display_positions.has(entry.character):
			_display_positions[entry.character] = t

	# Clear acted flag after one frame of processing
	_just_acted = null

	# Remove dead characters
	for ch: CharacterData in _display_positions.keys():
		if not _target_positions.has(ch):
			_display_positions.erase(ch)


func _process(delta: float) -> void:
	if _target_positions.is_empty():
		return
	# Pause animation while a turn is active
	if _turn_active:
		return

	var any_moved: bool = false
	for ch: CharacterData in _target_positions.keys():
		if not _display_positions.has(ch):
			_display_positions[ch] = _target_positions[ch]
			any_moved = true
			continue

		var current: float = _display_positions[ch]
		var target: float = _target_positions[ch]
		if absf(current - target) > 0.002:
			_display_positions[ch] = move_toward(current, target, MOVE_SPEED * delta)
			any_moved = true
		else:
			_display_positions[ch] = target

	if any_moved:
		queue_redraw()


func _draw() -> void:
	# Ensure we have a valid width
	if size.x <= 0.0:
		var parent_size: Vector2 = get_parent_area_size()
		if parent_size.x > 0:
			size.x = parent_size.x - position.x
	var bar_width: float = size.x - BAR_MARGIN * 2.0
	if bar_width <= 0.0:
		return

	var bar_y: float = size.y / 2.0

	# Draw bar background
	var bar_rect := Rect2(BAR_MARGIN, bar_y - BAR_HEIGHT / 2.0, bar_width, BAR_HEIGHT)
	draw_rect(bar_rect, Color(0.12, 0.12, 0.18, 0.85), true)
	draw_rect(bar_rect, Color(0.3, 0.3, 0.4, 0.6), false, 1.0)

	# Draw finish line at right edge
	var finish_x: float = BAR_MARGIN + bar_width - 2.0
	draw_line(
		Vector2(finish_x, bar_y - BAR_HEIGHT / 2.0),
		Vector2(finish_x, bar_y + BAR_HEIGHT / 2.0),
		Color(1.0, 0.9, 0.2, 0.4), 2.0
	)

	var active_char: CharacterData = BattleManager.get_active_character()

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

		# Highlight current acting character with yellow border
		var border_color: Color
		if active_char and ch == active_char:
			border_color = Color(1.0, 0.9, 0.2)
			draw_arc(center, MARKER_RADIUS, 0.0, TAU, 32, border_color, 2.5)
		else:
			border_color = Color(0.5, 0.5, 0.6, 0.6)
			draw_arc(center, MARKER_RADIUS, 0.0, TAU, 32, border_color, 1.0)

		# Draw initial letter
		var initial: String = ch.character_name.left(1).to_upper()
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 14
		var text_size: Vector2 = font.get_string_size(initial, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos := Vector2(center.x - text_size.x / 2.0, center.y + text_size.y / 4.0)
		draw_string(font, text_pos, initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
