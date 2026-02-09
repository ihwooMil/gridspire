## Container for all map nodes in a run.
class_name MapData
extends Resource

@export var nodes: Array[MapNode] = []
@export var total_rows: int = 15
@export var current_node_id: int = -1  ## ID of the node the player is currently at


func get_nodes_in_row(row: int) -> Array[MapNode]:
	var result: Array[MapNode] = []
	for node: MapNode in nodes:
		if node.row == row:
			result.append(node)
	return result


func get_node_by_id(id: int) -> MapNode:
	for node: MapNode in nodes:
		if node.id == id:
			return node
	return null


## Returns nodes the player can currently travel to (connected from current node).
func get_reachable_nodes() -> Array[MapNode]:
	var result: Array[MapNode] = []
	if current_node_id < 0:
		# At start: can reach any node in row 1
		return get_nodes_in_row(1)
	var current_node: MapNode = get_node_by_id(current_node_id)
	if current_node == null:
		return result
	for conn_id: int in current_node.connections:
		var target: MapNode = get_node_by_id(conn_id)
		if target:
			result.append(target)
	return result
