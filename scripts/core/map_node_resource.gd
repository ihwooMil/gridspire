## A single node on the overworld map.
class_name MapNode
extends Resource

@export var id: int = 0
@export var row: int = 0
@export var column: int = 0
@export var node_type: Enums.MapNodeType = Enums.MapNodeType.BATTLE
@export var connections: Array[int] = []  ## IDs of nodes this connects to (in the next row)
@export var visited: bool = false
@export var position: Vector2 = Vector2.ZERO  ## Visual position on the map
