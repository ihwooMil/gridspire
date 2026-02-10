## Displays the turn order as a horizontal race bar.
## Character markers move left → right in real-time based on their speed stat.
## When a character reaches the right edge, the race pauses for their turn.
## After acting, the marker resets to the far left and the race resumes.
class_name TimelineBar
extends Control

const BAR_HEIGHT: float = 40.0
const MARKER_RADIUS: float = 16.0
const BAR_MARGIN: float = 20.0

## Race speed factor. Characters advance at RACE_SPEED / effective_speed per second.
## Lower speed stat (e.g. 70) = faster marker; higher speed stat (e.g. 100) = slower.
const RACE_SPEED: float = 30.0

## When queued events pile up (e.g. multiple enemy turns), speed up the race.
const CATCH_UP_MULTIPLIER: float = 5.0

## Threshold: when the next-to-act character reaches this position, snap to 1.0.
const SNAP_THRESHOLD: float = 0.95

enum Phase { RACING, PAUSED }

## Current race state
var _phase: Phase = Phase.PAUSED

## Visual positions: CharacterData → float (0.0 = far left, 1.0 = right edge)
var _positions: Dictionary = {}

## Currently acting character (highlighted at finish line)
var _active_character: CharacterData = null

## Queued game events — processed in order with visual animation between them.
## Each entry: { "type": "start" or "end", "character": CharacterData }
var _event_queue: Array = []


func _ready() -> void:
	custom_minimum_size = Vector2(200, 48)
	BattleManager.battle_started.connect(_on_battle_started)
	BattleManager.turn_started.connect(_on_turn_started)
	BattleManager.turn_ended.connect(_on_turn_ended)
	BattleManager.character_died.connect(_on_character_died)
	resized.connect(queue_redraw)


func _exit_tree() -> void:
	if BattleManager.battle_started.is_connected(_on_battle_started):
		BattleManager.battle_started.disconnect(_on_battle_started)
	if BattleManager.turn_started.is_connected(_on_turn_started):
		BattleManager.turn_started.disconnect(_on_turn_started)
	if BattleManager.turn_ended.is_connected(_on_turn_ended):
		BattleManager.turn_ended.disconnect(_on_turn_ended)
	if BattleManager.character_died.is_connected(_on_character_died):
		BattleManager.character_died.disconnect(_on_character_died)


func _on_battle_started() -> void:
	_positions.clear()
	_event_queue.clear()
	_active_character = null
	# Initialize all characters at the starting line
	var entries: Array[TimelineEntry] = BattleManager.get_timeline_entries()
	for entry: TimelineEntry in entries:
		if entry.character.is_alive():
			_positions[entry.character] = 0.0
	_phase = Phase.RACING
	queue_redraw()


func _on_turn_started(character: CharacterData) -> void:
	_event_queue.append({"type": "start", "character": character})


func _on_turn_ended(character: CharacterData) -> void:
	_event_queue.append({"type": "end", "character": character})


func _on_character_died(character: CharacterData) -> void:
	_positions.erase(character)
	# Remove queued events for dead character
	var cleaned: Array = []
	for e: Dictionary in _event_queue:
		if e["character"] != character:
			cleaned.append(e)
	_event_queue = cleaned
	queue_redraw()


func _process(delta: float) -> void:
	if _positions.is_empty():
		return

	match _phase:
		Phase.RACING:
			_process_racing(delta)
		Phase.PAUSED:
			_process_paused()


func _process_racing(delta: float) -> void:
	# Speed multiplier: fast-forward when many events are queued (enemy turn chains)
	var speed_mult: float = 1.0
	if _event_queue.size() > 2:
		speed_mult = CATCH_UP_MULTIPLIER

	# Advance all characters based on their speed
	var any_moved: bool = false
	for ch: CharacterData in _positions.keys():
		var effective_speed: float = maxf(float(ch.get_effective_speed()), 1.0)
		var advance: float = (RACE_SPEED / effective_speed) * speed_mult * delta
		var old_pos: float = _positions[ch]
		_positions[ch] = minf(old_pos + advance, 1.0)
		if absf(_positions[ch] - old_pos) > 0.0001:
			any_moved = true

	# Check if the next turn_started event's character has reached the finish line
	if not _event_queue.is_empty() and _event_queue[0]["type"] == "start":
		var ch: CharacterData = _event_queue[0]["character"]
		if not _positions.has(ch):
			_positions[ch] = 0.0
		if _positions[ch] >= SNAP_THRESHOLD:
			_event_queue.pop_front()
			_positions[ch] = 1.0
			_active_character = ch
			_phase = Phase.PAUSED
			any_moved = true

	if any_moved:
		queue_redraw()


func _process_paused() -> void:
	if _event_queue.is_empty():
		return

	var event: Dictionary = _event_queue[0]
	if event["type"] == "end":
		# Turn ended → reset character to far left, resume racing
		_event_queue.pop_front()
		var ch: CharacterData = event["character"]
		if _positions.has(ch):
			_positions[ch] = 0.0
		_active_character = null
		_phase = Phase.RACING
		queue_redraw()
	elif event["type"] == "start":
		# Back-to-back turn_started (e.g. stunned character skipped immediately)
		_event_queue.pop_front()
		var ch: CharacterData = event["character"]
		if not _positions.has(ch):
			_positions[ch] = 0.0
		_positions[ch] = 1.0
		_active_character = ch
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
	for ch: CharacterData in _positions.keys():
		if not ch.is_alive():
			continue
		var t: float = _positions[ch]
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
