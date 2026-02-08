## GridVisual — Renders the battle grid, tile highlights, character sprites,
## and handles click input for tile selection and movement.
## Attach this script to the GridContainer Node2D in the battle scene.
extends Node2D

signal tile_clicked(pos: Vector2i)
signal tile_hovered(pos: Vector2i)
signal character_selected(character: CharacterData)
signal character_deselected()
signal movement_animation_finished(character: CharacterData)

## Tile colors
const COLOR_FLOOR := Color(0.2, 0.22, 0.25)
const COLOR_FLOOR_ALT := Color(0.18, 0.20, 0.23)
const COLOR_WALL := Color(0.12, 0.12, 0.14)
const COLOR_PIT := Color(0.05, 0.05, 0.08)
const COLOR_HAZARD := Color(0.35, 0.15, 0.1)
const COLOR_ELEVATED := Color(0.25, 0.28, 0.22)
const COLOR_GRID_LINE := Color(0.3, 0.32, 0.35, 0.4)

## Highlight colors
const COLOR_MOVE_RANGE := Color(0.2, 0.5, 0.9, 0.3)
const COLOR_ATTACK_RANGE := Color(0.9, 0.2, 0.2, 0.25)
const COLOR_PATH_PREVIEW := Color(0.3, 0.7, 1.0, 0.5)
const COLOR_SELECTED_TILE := Color(1.0, 0.9, 0.3, 0.4)
const COLOR_HOVER := Color(1.0, 1.0, 1.0, 0.15)

## Character colors
const COLOR_PLAYER := Color(0.3, 0.7, 1.0)
const COLOR_ENEMY := Color(0.9, 0.3, 0.3)
const COLOR_NEUTRAL := Color(0.7, 0.7, 0.7)
const COLOR_HP_BAR_BG := Color(0.15, 0.15, 0.15)
const COLOR_HP_BAR_FILL := Color(0.2, 0.8, 0.3)
const COLOR_HP_BAR_LOW := Color(0.9, 0.3, 0.2)

## Movement animation speed (pixels per second).
var move_speed: float = 250.0

## Current state
var selected_character: CharacterData = null
var hovered_tile: Vector2i = Vector2i(-1, -1)
var highlighted_move_tiles: Array[Vector2i] = []
var highlighted_attack_tiles: Array[Vector2i] = []
var path_preview_tiles: Array[Vector2i] = []
var selected_tile: Vector2i = Vector2i(-1, -1)

## Character sprite nodes: CharacterData -> Node2D
var character_sprites: Dictionary = {}

## Movement animation state
var _animating: bool = false
var _anim_character: CharacterData = null
var _anim_sprite: Node2D = null
var _anim_path: Array[Vector2i] = []
var _anim_step: int = 0
var _anim_from: Vector2
var _anim_to: Vector2
var _anim_progress: float = 0.0


func _ready() -> void:
	GridManager.grid_initialized.connect(_on_grid_initialized)
	GridManager.character_moved.connect(_on_character_moved)
	GridManager.tile_changed.connect(_on_tile_changed)
	GridManager.movement_started.connect(_on_movement_started)


func _on_grid_initialized(_width: int, _height: int) -> void:
	_rebuild_character_sprites()
	queue_redraw()


func _on_tile_changed(_pos: Vector2i, _tile: GridTile) -> void:
	queue_redraw()


func _on_character_moved(character: CharacterData, _from: Vector2i, to: Vector2i) -> void:
	# Update sprite position (unless animation is handling it)
	if not _animating or _anim_character != character:
		_update_sprite_position(character, to)
	queue_redraw()


func _on_movement_started(character: CharacterData, path: Array[Vector2i]) -> void:
	_start_movement_animation(character, path)


## Build sprite nodes for all characters currently on the grid.
func _rebuild_character_sprites() -> void:
	# Clear old sprites
	for sprite: Node2D in character_sprites.values():
		sprite.queue_free()
	character_sprites.clear()

	# Create sprites for occupants
	for pos: Vector2i in GridManager.grid.keys():
		var tile: GridTile = GridManager.get_tile(pos)
		if tile and tile.occupant:
			_create_character_sprite(tile.occupant)


## Create a simple visual representation for a character.
func _create_character_sprite(character: CharacterData) -> Node2D:
	var sprite := Node2D.new()
	sprite.position = GridManager.grid_to_world(character.grid_position)
	sprite.z_index = 1
	add_child(sprite)
	character_sprites[character] = sprite
	return sprite


## Ensure a sprite exists for the character, creating one if needed.
func ensure_character_sprite(character: CharacterData) -> void:
	if not character_sprites.has(character):
		_create_character_sprite(character)
	else:
		_update_sprite_position(character, character.grid_position)


func _update_sprite_position(character: CharacterData, grid_pos: Vector2i) -> void:
	if character_sprites.has(character):
		character_sprites[character].position = GridManager.grid_to_world(grid_pos)


func remove_character_sprite(character: CharacterData) -> void:
	if character_sprites.has(character):
		character_sprites[character].queue_free()
		character_sprites.erase(character)


## Start animated movement along a path.
func _start_movement_animation(character: CharacterData, path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	if not character_sprites.has(character):
		_create_character_sprite(character)
	_animating = true
	_anim_character = character
	_anim_sprite = character_sprites[character]
	_anim_path = path
	_anim_step = 0
	_anim_progress = 0.0
	# Start position is the character's pre-move position (first path entry's predecessor)
	var start_pos: Vector2i = character.grid_position
	if _anim_path.size() > 0:
		# The character has already been moved in data; animate from old visual position
		_anim_from = _anim_sprite.position
		_anim_to = GridManager.grid_to_world(_anim_path[0])


func _process(delta: float) -> void:
	if not _animating:
		return

	var step_distance: float = GridManager.tile_size.length()
	if step_distance <= 0:
		step_distance = 64.0
	_anim_progress += (move_speed * delta) / step_distance

	if _anim_progress >= 1.0:
		_anim_sprite.position = _anim_to
		_anim_step += 1
		_anim_progress = 0.0

		if _anim_step >= _anim_path.size():
			# Animation complete
			_animating = false
			_anim_sprite.position = GridManager.grid_to_world(_anim_character.grid_position)
			var finished_character: CharacterData = _anim_character
			_anim_character = null
			_anim_sprite = null
			_anim_path = []
			GridManager.movement_finished.emit(finished_character)
			movement_animation_finished.emit(finished_character)
			queue_redraw()
			return
		else:
			_anim_from = _anim_to
			_anim_to = GridManager.grid_to_world(_anim_path[_anim_step])

	_anim_sprite.position = _anim_from.lerp(_anim_to, _anim_progress)
	queue_redraw()


func _draw() -> void:
	_draw_tiles()
	_draw_highlights()
	_draw_characters()


func _draw_tiles() -> void:
	var ts: Vector2 = GridManager.tile_size
	for pos: Vector2i in GridManager.grid.keys():
		var tile: GridTile = GridManager.get_tile(pos)
		if tile == null:
			continue
		var rect := Rect2(Vector2(pos) * ts, ts)
		var color: Color = _get_tile_color(tile)
		draw_rect(rect, color, true)
		# Grid lines
		draw_rect(rect, COLOR_GRID_LINE, false, 1.0)


func _get_tile_color(tile: GridTile) -> Color:
	match tile.tile_type:
		Enums.TileType.WALL:
			return COLOR_WALL
		Enums.TileType.PIT:
			return COLOR_PIT
		Enums.TileType.HAZARD:
			return COLOR_HAZARD
		Enums.TileType.ELEVATED:
			return COLOR_ELEVATED
		_:
			# Checkerboard pattern for floor
			if (tile.position.x + tile.position.y) % 2 == 0:
				return COLOR_FLOOR
			return COLOR_FLOOR_ALT


func _draw_highlights() -> void:
	var ts: Vector2 = GridManager.tile_size

	# Movement range (blue)
	for pos: Vector2i in highlighted_move_tiles:
		var rect := Rect2(Vector2(pos) * ts, ts)
		draw_rect(rect, COLOR_MOVE_RANGE, true)

	# Attack range (red)
	for pos: Vector2i in highlighted_attack_tiles:
		var rect := Rect2(Vector2(pos) * ts, ts)
		draw_rect(rect, COLOR_ATTACK_RANGE, true)

	# Path preview
	for pos: Vector2i in path_preview_tiles:
		var rect := Rect2(Vector2(pos) * ts, ts)
		draw_rect(rect, COLOR_PATH_PREVIEW, true)
		# Draw direction dots along path
		var center: Vector2 = Vector2(pos) * ts + ts * 0.5
		draw_circle(center, 4.0, Color(0.3, 0.7, 1.0, 0.8))

	# Selected tile
	if selected_tile != Vector2i(-1, -1) and GridManager.grid.has(selected_tile):
		var rect := Rect2(Vector2(selected_tile) * ts, ts)
		draw_rect(rect, COLOR_SELECTED_TILE, true)
		draw_rect(rect, Color(1.0, 0.9, 0.3, 0.6), false, 2.0)

	# Hover
	if hovered_tile != Vector2i(-1, -1) and GridManager.grid.has(hovered_tile):
		var rect := Rect2(Vector2(hovered_tile) * ts, ts)
		draw_rect(rect, COLOR_HOVER, true)


func _draw_characters() -> void:
	var ts: Vector2 = GridManager.tile_size
	for character: CharacterData in character_sprites.keys():
		if not character.is_alive():
			continue
		var sprite: Node2D = character_sprites[character]
		var center: Vector2 = sprite.position
		var half: Vector2 = ts * 0.4

		# Body shape
		var body_color: Color = _get_faction_color(character.faction)
		if character == selected_character:
			body_color = body_color.lightened(0.3)

		# Draw character as a filled circle with a border
		draw_circle(center, half.x * 0.7, body_color)
		draw_arc(center, half.x * 0.7, 0, TAU, 32, body_color.lightened(0.2), 2.0)

		# Character initial
		var font: Font = ThemeDB.fallback_font
		var font_size: int = int(ts.y * 0.35)
		var ch_text: String = character.character_name.left(1)
		var text_size: Vector2 = font.get_string_size(ch_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(
			font,
			center + Vector2(-text_size.x * 0.5, text_size.y * 0.3),
			ch_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.WHITE,
		)

		# HP bar
		var bar_width: float = ts.x * 0.7
		var bar_height: float = 4.0
		var bar_start: Vector2 = center + Vector2(-bar_width * 0.5, half.y * 0.8)
		var bg_rect := Rect2(bar_start, Vector2(bar_width, bar_height))
		draw_rect(bg_rect, COLOR_HP_BAR_BG, true)

		var hp_ratio: float = float(character.current_hp) / float(character.max_hp)
		var hp_color: Color = COLOR_HP_BAR_FILL if hp_ratio > 0.3 else COLOR_HP_BAR_LOW
		var fill_rect := Rect2(bar_start, Vector2(bar_width * hp_ratio, bar_height))
		draw_rect(fill_rect, hp_color, true)


func _get_faction_color(faction: Enums.Faction) -> Color:
	match faction:
		Enums.Faction.PLAYER:
			return COLOR_PLAYER
		Enums.Faction.ENEMY:
			return COLOR_ENEMY
		_:
			return COLOR_NEUTRAL


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_move(event as InputEventMouseMotion)
	elif event is InputEventMouseButton:
		_handle_mouse_click(event as InputEventMouseButton)


func _handle_mouse_move(event: InputEventMouseMotion) -> void:
	var local_pos: Vector2 = to_local(event.global_position)
	var grid_pos: Vector2i = GridManager.world_to_grid(local_pos)

	if grid_pos != hovered_tile:
		hovered_tile = grid_pos
		tile_hovered.emit(grid_pos)

		# Update path preview if a character is selected and tile is in move range
		if selected_character and GridManager.grid.has(grid_pos):
			if grid_pos in highlighted_move_tiles:
				path_preview_tiles = GridManager.find_path(selected_character.grid_position, grid_pos)
			else:
				path_preview_tiles = []
		queue_redraw()


func _handle_mouse_click(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	var local_pos: Vector2 = to_local(event.global_position)
	var grid_pos: Vector2i = GridManager.world_to_grid(local_pos)

	if not GridManager.grid.has(grid_pos):
		return

	tile_clicked.emit(grid_pos)
	var tile: GridTile = GridManager.get_tile(grid_pos)

	if _animating:
		return

	if selected_character:
		# If clicking a valid movement tile, move there
		if grid_pos in highlighted_move_tiles:
			var character: CharacterData = selected_character
			deselect_character()
			GridManager.move_character(character, grid_pos)
		else:
			deselect_character()
			# If clicking another character, select them
			if tile and tile.occupant and tile.occupant.faction == Enums.Faction.PLAYER:
				select_character(tile.occupant)
	else:
		# Select a character on this tile
		if tile and tile.occupant and tile.occupant.faction == Enums.Faction.PLAYER:
			select_character(tile.occupant)
		else:
			selected_tile = grid_pos
			queue_redraw()


## Select a character and show their movement range.
func select_character(character: CharacterData) -> void:
	selected_character = character
	selected_tile = character.grid_position
	highlighted_move_tiles = GridManager.get_reachable_tiles(character)
	path_preview_tiles = []
	character_selected.emit(character)
	queue_redraw()


## Deselect the currently selected character.
func deselect_character() -> void:
	selected_character = null
	selected_tile = Vector2i(-1, -1)
	highlighted_move_tiles = []
	highlighted_attack_tiles = []
	path_preview_tiles = []
	character_deselected.emit()
	queue_redraw()


## Show attack range overlay for a card being targeted.
func show_attack_range(origin: Vector2i, min_range: int, max_range: int) -> void:
	highlighted_attack_tiles = GridManager.get_tiles_in_range(origin, min_range, max_range)
	queue_redraw()


## Show attack range with a specific pattern.
func show_attack_range_pattern(origin: Vector2i, max_range: int, pattern: GridManager.RangePattern) -> void:
	highlighted_attack_tiles = GridManager.get_tiles_in_range_pattern(origin, max_range, pattern)
	queue_redraw()


## Clear the attack range overlay.
func clear_attack_range() -> void:
	highlighted_attack_tiles = []
	queue_redraw()


## Clear all highlights.
func clear_all_highlights() -> void:
	highlighted_move_tiles = []
	highlighted_attack_tiles = []
	path_preview_tiles = []
	selected_tile = Vector2i(-1, -1)
	queue_redraw()
