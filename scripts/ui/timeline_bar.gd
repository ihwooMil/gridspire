## Displays the turn order timeline as a horizontal bar at the top of the screen.
## Character markers are positioned proportionally by tick value.
## Left = acts soon (low tick), Right = acts later (high tick).
class_name TimelineBar
extends Control

const BAR_HEIGHT: float = 40.0
const MARKER_RADIUS: float = 16.0
const BAR_MARGIN: float = 20.0


func _ready() -> void:
	custom_minimum_size = Vector2(200, 48)
	BattleManager.timeline_updated.connect(_on_update)
	BattleManager.turn_started.connect(func(_c: CharacterData) -> void: _on_update())
	BattleManager.battle_started.connect(_on_update)
	resized.connect(queue_redraw)


func _exit_tree() -> void:
	if BattleManager.timeline_updated.is_connected(_on_update):
		BattleManager.timeline_updated.disconnect(_on_update)
	if BattleManager.battle_started.is_connected(_on_update):
		BattleManager.battle_started.disconnect(_on_update)


func _on_update() -> void:
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

	var entries: Array[TimelineEntry] = BattleManager.get_timeline_entries()
	if entries.is_empty():
		return

	# Find min/max tick for proportional positioning
	var min_tick: int = entries[0].current_tick
	var max_tick: int = entries[0].current_tick
	for entry: TimelineEntry in entries:
		if entry.character.is_alive():
			min_tick = mini(min_tick, entry.current_tick)
			max_tick = maxi(max_tick, entry.current_tick)

	var tick_range: int = max_tick - min_tick
	if tick_range == 0:
		tick_range = 1  # Avoid division by zero

	var active_char: CharacterData = BattleManager.get_active_character()

	for entry: TimelineEntry in entries:
		if not entry.character.is_alive():
			continue

		# Position marker proportionally along the bar
		var t: float = float(entry.current_tick - min_tick) / float(tick_range)
		var x: float = BAR_MARGIN + MARKER_RADIUS + t * (bar_width - MARKER_RADIUS * 2.0)
		var center := Vector2(x, bar_y)

		# Faction color
		var fill_color: Color
		if entry.character.faction == Enums.Faction.PLAYER:
			fill_color = Color(0.15, 0.3, 0.6)
		else:
			fill_color = Color(0.5, 0.12, 0.12)

		# Draw filled circle
		draw_circle(center, MARKER_RADIUS, fill_color)

		# Highlight current acting character with yellow border
		var border_color: Color
		if active_char and entry.character == active_char:
			border_color = Color(1.0, 0.9, 0.2)
			draw_arc(center, MARKER_RADIUS, 0.0, TAU, 32, border_color, 2.5)
		else:
			border_color = Color(0.5, 0.5, 0.6, 0.6)
			draw_arc(center, MARKER_RADIUS, 0.0, TAU, 32, border_color, 1.0)

		# Draw initial letter
		var initial: String = entry.character.character_name.left(1).to_upper()
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 14
		var text_size: Vector2 = font.get_string_size(initial, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos := Vector2(center.x - text_size.x / 2.0, center.y + text_size.y / 4.0)
		draw_string(font, text_pos, initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

		# Draw tick number below marker
		var tick_str: String = str(entry.current_tick)
		var tick_size: Vector2 = font.get_string_size(tick_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 9)
		var tick_pos := Vector2(center.x - tick_size.x / 2.0, center.y + MARKER_RADIUS + 12.0)
		draw_string(font, tick_pos, tick_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6, 0.6, 0.6))
