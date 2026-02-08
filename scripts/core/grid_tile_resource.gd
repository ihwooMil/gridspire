## Represents a single tile on the battle grid.
class_name GridTile
extends Resource

@export var position: Vector2i = Vector2i.ZERO
@export var tile_type: Enums.TileType = Enums.TileType.FLOOR

## Reference to the CharacterData occupying this tile, or null.
var occupant: CharacterData = null


func is_walkable() -> bool:
	return tile_type == Enums.TileType.FLOOR or tile_type == Enums.TileType.ELEVATED


func is_occupied() -> bool:
	return occupant != null


func is_available() -> bool:
	return is_walkable() and not is_occupied()
