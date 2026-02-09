## Draws connection lines between map nodes.
extends Control

const LINE_COLOR := Color(0.5, 0.5, 0.6, 0.6)
const LINE_COLOR_VISITED := Color(0.3, 0.3, 0.35, 0.4)
const LINE_WIDTH: float = 2.0
const MAP_MARGIN: float = 100.0


func _draw() -> void:
	var map: MapData = GameManager.current_map
	if map == null:
		return

	for node: MapNode in map.nodes:
		for conn_id: int in node.connections:
			var target: MapNode = map.get_node_by_id(conn_id)
			if target == null:
				continue
			var from_pos: Vector2 = node.position + Vector2(MAP_MARGIN, MAP_MARGIN)
			var to_pos: Vector2 = target.position + Vector2(MAP_MARGIN, MAP_MARGIN)
			var color: Color = LINE_COLOR_VISITED if node.visited and target.visited else LINE_COLOR
			draw_line(from_pos, to_pos, color, LINE_WIDTH, true)
