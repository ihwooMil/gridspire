## GridManager — Autoload singleton for grid operations.
## Manages the tile grid, pathfinding, range calculations,
## movement validation, and spatial queries.
extends Node

signal grid_initialized(width: int, height: int)
signal character_moved(character: CharacterData, from: Vector2i, to: Vector2i)
signal tile_changed(position: Vector2i, tile: GridTile)

## The 2D grid stored as a flat dictionary keyed by Vector2i.
var grid: Dictionary = {}  # Vector2i -> GridTile
var grid_width: int = 0
var grid_height: int = 0

## Pixel size of each tile for rendering (set by the battle scene).
var tile_size: Vector2 = Vector2(64, 64)


## Create a rectangular grid of floor tiles.
func initialize_grid(width: int, height: int) -> void:
	grid.clear()
	grid_width = width
	grid_height = height
	for x: int in width:
		for y: int in height:
			var pos := Vector2i(x, y)
			var tile := GridTile.new()
			tile.position = pos
			tile.tile_type = Enums.TileType.FLOOR
			grid[pos] = tile
	grid_initialized.emit(width, height)


## Get tile at position, or null if out of bounds.
func get_tile(pos: Vector2i) -> GridTile:
	return grid.get(pos, null)


## Set tile type at a position.
func set_tile_type(pos: Vector2i, type: Enums.TileType) -> void:
	var tile: GridTile = get_tile(pos)
	if tile:
		tile.tile_type = type
		tile_changed.emit(pos, tile)


## Place a character on the grid.
func place_character(character: CharacterData, pos: Vector2i) -> bool:
	var tile: GridTile = get_tile(pos)
	if tile == null or not tile.is_available():
		return false
	# Remove from old tile if already placed
	var old_tile: GridTile = get_tile(character.grid_position)
	if old_tile and old_tile.occupant == character:
		old_tile.occupant = null
	tile.occupant = character
	character.grid_position = pos
	return true


## Move a character to a new position if the path is valid.
func move_character(character: CharacterData, target: Vector2i) -> bool:
	var path: Array[Vector2i] = find_path(character.grid_position, target)
	if path.is_empty():
		return false
	if path.size() > character.move_range:
		return false

	var old_pos: Vector2i = character.grid_position
	var old_tile: GridTile = get_tile(old_pos)
	var new_tile: GridTile = get_tile(target)

	if old_tile:
		old_tile.occupant = null
	if new_tile:
		new_tile.occupant = character
	character.grid_position = target
	character_moved.emit(character, old_pos, target)
	return true


## Get all tiles within move range of a character (for highlighting).
func get_reachable_tiles(character: CharacterData) -> Array[Vector2i]:
	return get_tiles_in_range_walkable(character.grid_position, character.move_range)


## Get tiles within a walking distance (respecting walls/obstacles).
func get_tiles_in_range_walkable(origin: Vector2i, max_range: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var visited: Dictionary = {}
	var queue: Array[Dictionary] = [{"pos": origin, "dist": 0}]
	visited[origin] = true

	while not queue.is_empty():
		var current: Dictionary = queue.pop_front()
		var pos: Vector2i = current.pos
		var dist: int = current.dist

		if dist > 0:
			result.append(pos)
		if dist >= max_range:
			continue

		for neighbor: Vector2i in get_orthogonal_neighbors(pos):
			if visited.has(neighbor):
				continue
			var tile: GridTile = get_tile(neighbor)
			if tile and tile.is_available():
				visited[neighbor] = true
				queue.append({"pos": neighbor, "dist": dist + 1})

	return result


## Get tiles within a straight-line (Manhattan) distance — for card range display.
func get_tiles_in_range(origin: Vector2i, min_range: int, max_range: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x: int in range(-max_range, max_range + 1):
		for y: int in range(-max_range, max_range + 1):
			var dist: int = absi(x) + absi(y)
			if dist >= min_range and dist <= max_range:
				var pos := origin + Vector2i(x, y)
				if grid.has(pos):
					result.append(pos)
	return result


## Manhattan distance between two grid positions.
func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Simple BFS pathfinding on the grid.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if from == to:
		return []
	var target_tile: GridTile = get_tile(to)
	if target_tile == null or not target_tile.is_walkable():
		return []

	var visited: Dictionary = {}
	var came_from: Dictionary = {}
	var queue: Array[Vector2i] = [from]
	visited[from] = true

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == to:
			return _reconstruct_path(came_from, from, to)
		for neighbor: Vector2i in get_orthogonal_neighbors(current):
			if visited.has(neighbor):
				continue
			var tile: GridTile = get_tile(neighbor)
			if tile == null:
				continue
			# Target tile can be occupied if it's our destination
			if not tile.is_walkable():
				continue
			if tile.is_occupied() and neighbor != to:
				continue
			visited[neighbor] = true
			came_from[neighbor] = current
			queue.append(neighbor)

	return []  # No path found


func _reconstruct_path(came_from: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current: Vector2i = to
	while current != from:
		path.push_front(current)
		current = came_from[current]
	return path


## Get the 4 orthogonal neighbors of a tile position.
func get_orthogonal_neighbors(pos: Vector2i) -> Array[Vector2i]:
	return [
		pos + Vector2i.UP,
		pos + Vector2i.DOWN,
		pos + Vector2i.LEFT,
		pos + Vector2i.RIGHT,
	]


## Push a character away from the source.
func push_character(source: CharacterData, target: CharacterData, distance: int) -> void:
	var dir: Vector2i = _get_direction(source.grid_position, target.grid_position)
	_slide_character(target, dir, distance)


## Pull a character toward the source.
func pull_character(source: CharacterData, target: CharacterData, distance: int) -> void:
	var dir: Vector2i = _get_direction(target.grid_position, source.grid_position)
	_slide_character(target, dir, distance)


## Slide a character in a direction, stopping at walls/edges/occupants.
func _slide_character(character: CharacterData, direction: Vector2i, distance: int) -> void:
	var current: Vector2i = character.grid_position
	for i: int in distance:
		var next: Vector2i = current + direction
		var tile: GridTile = get_tile(next)
		if tile == null or not tile.is_available():
			break
		current = next

	if current != character.grid_position:
		var old_pos: Vector2i = character.grid_position
		var old_tile: GridTile = get_tile(old_pos)
		if old_tile:
			old_tile.occupant = null
		var new_tile: GridTile = get_tile(current)
		if new_tile:
			new_tile.occupant = character
		character.grid_position = current
		character_moved.emit(character, old_pos, current)


func _get_direction(from: Vector2i, to: Vector2i) -> Vector2i:
	var diff: Vector2i = to - from
	# Use the dominant axis
	if absi(diff.x) >= absi(diff.y):
		return Vector2i(signi(diff.x), 0)
	else:
		return Vector2i(0, signi(diff.y))


## Get all characters within a radius of a tile (for area effects).
func get_characters_in_radius(center: Vector2i, radius: int) -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for x: int in range(-radius, radius + 1):
		for y: int in range(-radius, radius + 1):
			if absi(x) + absi(y) > radius:
				continue
			var pos := center + Vector2i(x, y)
			var tile: GridTile = get_tile(pos)
			if tile and tile.occupant:
				result.append(tile.occupant)
	return result


## Convert grid position to world pixel position.
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos) * tile_size + tile_size * 0.5


## Convert world pixel position to grid position.
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i((world_pos / tile_size).floor())


## Check if a position is within grid bounds.
func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height
