## GridVisual — Renders the battle grid, tile highlights, character sprites,
## and handles click input for tile selection and movement.
## Attach this script to the GridContainer Node2D in the battle scene.
extends Node2D

signal tile_clicked(pos: Vector2i)
signal tile_hovered(pos: Vector2i)
signal character_selected(character: CharacterData)
signal character_deselected()
signal movement_animation_finished(character: CharacterData)
signal target_selected(card: CardData, source: CharacterData, target: Variant)
signal targeting_cancelled()

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
const COLOR_AOE_PREVIEW := Color(1.0, 0.5, 0.1, 0.35)

## Character colors
const COLOR_PLAYER := Color(0.3, 0.7, 1.0)
const COLOR_ENEMY := Color(0.9, 0.3, 0.3)
const COLOR_NEUTRAL := Color(0.7, 0.7, 0.7)
const COLOR_HP_BAR_BG := Color(0.15, 0.15, 0.15)
const COLOR_HP_BAR_FILL := Color(0.2, 0.8, 0.3)
const COLOR_HP_BAR_LOW := Color(0.9, 0.3, 0.2)

## Sprite sheet definitions: character_name -> { path, cols, rows, frame_count, fps }
var sprite_sheets: Dictionary = {
	"Mage": {
		"walk": {
			"path": "res://res/Seo-A-walk.png",
			"cols": 5,
			"rows": 5,
			"frame_count": 25,
			"fps": 12.0,
		},
		"cast": {
			"path": "res://res/mage-cast.png",
			"cols": 5,
			"rows": 5,
			"frame_count": 25,
			"fps": 12.0,
		},
		"kneel": {
			"path": "res://res/mage-kneel.png",
			"cols": 5,
			"rows": 5,
			"frame_count": 25,
			"fps": 12.0,
		},
	},
}

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

## Card targeting state
var _targeting: bool = false
var _targeting_card: CardData = null
var _targeting_source: CharacterData = null
var _aoe_preview_tiles: Array[Vector2i] = []

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


func _exit_tree() -> void:
	if GridManager.grid_initialized.is_connected(_on_grid_initialized):
		GridManager.grid_initialized.disconnect(_on_grid_initialized)
	if GridManager.character_moved.is_connected(_on_character_moved):
		GridManager.character_moved.disconnect(_on_character_moved)
	if GridManager.tile_changed.is_connected(_on_tile_changed):
		GridManager.tile_changed.disconnect(_on_tile_changed)
	if GridManager.movement_started.is_connected(_on_movement_started):
		GridManager.movement_started.disconnect(_on_movement_started)


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


## Create a visual representation for a character.
## If a sprite sheet is defined for this character, uses AnimatedSprite2D.
func _create_character_sprite(character: CharacterData) -> Node2D:
	var sprite := Node2D.new()
	sprite.position = GridManager.grid_to_world(character.grid_position)
	sprite.z_index = 1
	add_child(sprite)
	character_sprites[character] = sprite

	# Check if this character has sprite sheets
	if sprite_sheets.has(character.character_name):
		var sheets: Dictionary = sprite_sheets[character.character_name]
		var anim_sprite := _create_animated_sprite(sheets)
		if anim_sprite:
			sprite.add_child(anim_sprite)
			anim_sprite.play("idle")

	return sprite


## Create an AnimatedSprite2D from a multi-animation sprite sheet dictionary.
## sheets: { "walk": {path, cols, rows, frame_count, fps}, "cast": {...}, ... }
func _create_animated_sprite(sheets: Dictionary) -> AnimatedSprite2D:
	if sheets.is_empty():
		return null

	var frames := SpriteFrames.new()
	var ref_frame_w: int = 0
	var ref_frame_h: int = 0

	# Build idle animation from the first frame of the "walk" sheet (or first available)
	var idle_sheet_key: String = "walk" if sheets.has("walk") else sheets.keys()[0]
	var idle_info: Dictionary = sheets[idle_sheet_key]
	var idle_texture: Texture2D = load(idle_info["path"])
	if idle_texture:
		var cols: int = idle_info["cols"]
		var rows: int = idle_info["rows"]
		ref_frame_w = int(idle_texture.get_width()) / cols
		ref_frame_h = int(idle_texture.get_height()) / rows

		frames.add_animation("idle")
		frames.set_animation_speed("idle", 1.0)
		frames.set_animation_loop("idle", false)
		var idle_tex := AtlasTexture.new()
		idle_tex.atlas = idle_texture
		idle_tex.region = Rect2(0, 0, ref_frame_w, ref_frame_h)
		frames.add_frame("idle", idle_tex)

	# Build each named animation from its sprite sheet
	for anim_name: String in sheets.keys():
		var sheet_info: Dictionary = sheets[anim_name]
		var texture: Texture2D = load(sheet_info["path"])
		if not texture:
			continue

		var cols: int = sheet_info["cols"]
		var rows: int = sheet_info["rows"]
		var frame_count: int = sheet_info["frame_count"]
		var fps: float = sheet_info["fps"]
		var frame_w: int = int(texture.get_width()) / cols
		var frame_h: int = int(texture.get_height()) / rows

		if ref_frame_w == 0:
			ref_frame_w = frame_w
			ref_frame_h = frame_h

		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, fps)
		frames.set_animation_loop(anim_name, true)
		for i: int in frame_count:
			var col: int = i % cols
			var row: int = i / cols
			var atlas_tex := AtlasTexture.new()
			atlas_tex.atlas = texture
			atlas_tex.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
			frames.add_frame(anim_name, atlas_tex)

	# Remove default animation if it exists
	if frames.has_animation("default"):
		frames.remove_animation("default")

	if ref_frame_w == 0:
		return null

	var anim_sprite := AnimatedSprite2D.new()
	anim_sprite.sprite_frames = frames
	anim_sprite.centered = true
	# Scale based on tile height so character stands on top of tile
	var scale_factor: float = GridManager.tile_size.y / float(ref_frame_h) * 1.6
	anim_sprite.scale = Vector2(scale_factor, scale_factor)
	# Offset upward so character appears to stand on the tile surface
	anim_sprite.offset = Vector2(0, -ref_frame_h * 0.35)

	return anim_sprite


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

	# Start walk animation if character has AnimatedSprite2D
	_play_character_anim(character, "walk")

	# Start position is the character's pre-move position (first path entry's predecessor)
	var start_pos: Vector2i = character.grid_position
	if _anim_path.size() > 0:
		# The character has already been moved in data; animate from old visual position
		_anim_from = _anim_sprite.position
		_anim_to = GridManager.grid_to_world(_anim_path[0])

		# Flip sprite based on movement direction
		_flip_sprite_towards(character, _anim_path[0])


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
			# Animation complete — switch to idle
			_animating = false
			_anim_sprite.position = GridManager.grid_to_world(_anim_character.grid_position)
			_play_character_anim(_anim_character, "idle")
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
			# Flip sprite for new direction
			_flip_sprite_towards(_anim_character, _anim_path[_anim_step])

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

	# AOE preview (orange)
	for pos: Vector2i in _aoe_preview_tiles:
		var rect := Rect2(Vector2(pos) * ts, ts)
		draw_rect(rect, COLOR_AOE_PREVIEW, true)
		draw_rect(rect, Color(1.0, 0.5, 0.1, 0.5), false, 1.5)

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
		var has_sprite_sheet: bool = sprite_sheets.has(character.character_name)
		# Standing offset — characters appear above the tile center
		var stand_offset := Vector2(0, -ts.y * 0.3)

		if not has_sprite_sheet:
			var draw_center: Vector2 = center + stand_offset
			# Draw circle placeholder for characters without sprite sheets
			var body_color: Color = _get_faction_color(character.faction)
			if character == selected_character:
				body_color = body_color.lightened(0.3)
			var radius: float = minf(half.x, half.y) * 0.7
			draw_circle(draw_center, radius, body_color)
			draw_arc(draw_center, radius, 0, TAU, 32, body_color.lightened(0.2), 2.0)

			# Character initial
			var font: Font = ThemeDB.fallback_font
			var font_size: int = int(ts.y * 0.35)
			var ch_text: String = character.character_name.left(1)
			var text_size: Vector2 = font.get_string_size(ch_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(
				font,
				draw_center + Vector2(-text_size.x * 0.5, text_size.y * 0.3),
				ch_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				Color.WHITE,
			)

		# Selection highlight for sprite-sheet characters
		if has_sprite_sheet and character == selected_character:
			draw_arc(center + stand_offset, minf(half.x, half.y) * 0.85, 0, TAU, 32, Color(1.0, 1.0, 0.3, 0.6), 2.0)

		# HP bar at tile bottom area
		var bar_width: float = ts.x * 0.7
		var bar_height: float = 4.0
		var bar_y_offset: float = ts.y * 0.35
		var bar_start: Vector2 = center + Vector2(-bar_width * 0.5, bar_y_offset)
		var bg_rect := Rect2(bar_start, Vector2(bar_width, bar_height))
		draw_rect(bg_rect, COLOR_HP_BAR_BG, true)

		var hp_ratio: float = float(character.current_hp) / float(character.max_hp)
		var hp_color: Color = COLOR_HP_BAR_FILL if hp_ratio > 0.3 else COLOR_HP_BAR_LOW
		var fill_rect := Rect2(bar_start, Vector2(bar_width * hp_ratio, bar_height))
		draw_rect(fill_rect, hp_color, true)


## Play an animation on a character's AnimatedSprite2D (if it has one).
func _play_character_anim(character: CharacterData, anim_name: String) -> void:
	if not character_sprites.has(character):
		return
	var sprite: Node2D = character_sprites[character]
	for child: Node in sprite.get_children():
		if child is AnimatedSprite2D:
			var anim: AnimatedSprite2D = child
			if anim.sprite_frames and anim.sprite_frames.has_animation(anim_name):
				anim.play(anim_name)
			return


## Flip sprite horizontally based on movement direction.
func _flip_sprite_towards(character: CharacterData, target_pos: Vector2i) -> void:
	if not character_sprites.has(character):
		return
	var sprite: Node2D = character_sprites[character]
	var current_world: Vector2 = sprite.position
	var target_world: Vector2 = GridManager.grid_to_world(target_pos)
	for child: Node in sprite.get_children():
		if child is AnimatedSprite2D:
			# Flip if moving left
			child.flip_h = target_world.x < current_world.x
			return


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

		# AOE preview during card targeting
		if _targeting and _targeting_card and GridManager.grid.has(grid_pos):
			if grid_pos in highlighted_attack_tiles:
				_aoe_preview_tiles = _get_aoe_tiles(grid_pos, _targeting_card)
			else:
				_aoe_preview_tiles = []
		elif not _targeting:
			_aoe_preview_tiles = []

		# Update path preview if a character is selected and tile is in move range
		if selected_character and GridManager.grid.has(grid_pos):
			if grid_pos in highlighted_move_tiles:
				path_preview_tiles = GridManager.find_path(selected_character.grid_position, grid_pos)
			else:
				path_preview_tiles = []
		queue_redraw()


func _handle_mouse_click(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# Right-click cancels targeting
		if _targeting:
			exit_targeting_mode()
			return
		if selected_character:
			deselect_character()
			return
		return

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

	# Card targeting mode: clicking selects a target
	if _targeting:
		_handle_targeting_click(grid_pos, tile)
		return

	# Only allow selecting/moving the currently active character
	var active_char: CharacterData = BattleManager.get_active_character()
	var is_player_turn: bool = active_char != null and active_char.faction == Enums.Faction.PLAYER

	if selected_character:
		# If clicking a valid movement tile, move there
		if grid_pos in highlighted_move_tiles:
			var character: CharacterData = selected_character
			deselect_character()
			BattleManager.move_character(character, grid_pos)
		else:
			deselect_character()
			# If clicking the active character again, re-select
			if is_player_turn and tile and tile.occupant == active_char:
				select_character(active_char)
	else:
		# Only allow selecting the active character on their turn
		if is_player_turn and tile and tile.occupant == active_char:
			select_character(active_char)
		else:
			selected_tile = grid_pos
			queue_redraw()


## Select a character and show their movement range.
func select_character(character: CharacterData) -> void:
	selected_character = character
	selected_tile = character.grid_position
	# Only show movement range if the character hasn't moved yet and isn't rooted
	if not BattleManager.has_moved_this_turn and character.get_status_stacks(Enums.StatusEffect.ROOT) <= 0:
		highlighted_move_tiles = GridManager.get_reachable_tiles(character)
	else:
		highlighted_move_tiles = []
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


## Update the hovered tile during a card drag (screen-space position).
func update_drag_hover(screen_pos: Vector2) -> void:
	var local_pos: Vector2 = to_local(screen_pos)
	var grid_pos: Vector2i = GridManager.world_to_grid(local_pos)
	if grid_pos != hovered_tile:
		hovered_tile = grid_pos
		queue_redraw()


## Enter card targeting mode: show attack range and wait for target click.
func enter_targeting_mode(card: CardData, source: CharacterData) -> void:
	deselect_character()
	_targeting = true
	_targeting_card = card
	_targeting_source = source
	# Show attack range from source position
	highlighted_attack_tiles = GridManager.get_tiles_in_range(
		source.grid_position, card.range_min, card.range_max
	)
	queue_redraw()


## Exit card targeting mode.
func exit_targeting_mode() -> void:
	_targeting = false
	_targeting_card = null
	_targeting_source = null
	highlighted_attack_tiles = []
	_aoe_preview_tiles = []
	targeting_cancelled.emit()
	queue_redraw()


## Handle a click during targeting mode.
func _handle_targeting_click(grid_pos: Vector2i, tile: GridTile) -> void:
	if not _targeting or _targeting_card == null:
		return

	var card: CardData = _targeting_card
	var source: CharacterData = _targeting_source

	# Check if clicked position is in attack range
	if grid_pos not in highlighted_attack_tiles:
		exit_targeting_mode()
		return

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
		# Clear targeting state before emitting signal
		_targeting = false
		_targeting_card = null
		_targeting_source = null
		highlighted_attack_tiles = []
		_aoe_preview_tiles = []
		queue_redraw()
		target_selected.emit(card, source, target)
	else:
		# Invalid target, cancel
		exit_targeting_mode()


## Get the tiles that would be affected by a card's area effect at the given position.
func _get_aoe_tiles(center: Vector2i, card: CardData) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var radius: int = 0

	# Get the largest area_radius from the card's effects
	if card.target_type == Enums.TargetType.AREA:
		for effect in card.effects:
			if effect.area_radius > radius:
				radius = effect.area_radius

	if radius <= 0:
		# Single tile target — just highlight the center tile
		tiles.append(center)
		return tiles

	# Get all tiles within the AOE radius (manhattan distance)
	tiles = GridManager.get_tiles_in_range(center, 0, radius)
	return tiles
