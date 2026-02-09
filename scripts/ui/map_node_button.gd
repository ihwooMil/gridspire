## Clickable map node on the overworld map.
class_name MapNodeButton
extends Control

signal node_clicked(map_node: MapNode)

var map_node: MapNode = null
var reachable: bool = false

const NODE_SIZE: float = 48.0
const NODE_COLORS: Dictionary = {
	Enums.MapNodeType.BATTLE: Color(0.7, 0.3, 0.3),
	Enums.MapNodeType.ELITE: Color(0.9, 0.6, 0.1),
	Enums.MapNodeType.SHOP: Color(0.3, 0.7, 0.3),
	Enums.MapNodeType.REST: Color(0.3, 0.5, 0.8),
	Enums.MapNodeType.EVENT: Color(0.6, 0.4, 0.8),
	Enums.MapNodeType.BOSS: Color(0.9, 0.2, 0.2),
	Enums.MapNodeType.START: Color(0.5, 0.5, 0.5),
	Enums.MapNodeType.COMPANION: Color(0.2, 0.8, 0.6),
}
const NODE_ICONS: Dictionary = {
	Enums.MapNodeType.BATTLE: "!",
	Enums.MapNodeType.ELITE: "E",
	Enums.MapNodeType.SHOP: "$",
	Enums.MapNodeType.REST: "R",
	Enums.MapNodeType.EVENT: "?",
	Enums.MapNodeType.BOSS: "B",
	Enums.MapNodeType.START: "S",
	Enums.MapNodeType.COMPANION: "+",
}


func setup(node: MapNode, is_reachable: bool) -> void:
	map_node = node
	reachable = is_reachable
	custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	size = Vector2(NODE_SIZE, NODE_SIZE)
	position = node.position - Vector2(NODE_SIZE * 0.5, NODE_SIZE * 0.5)
	mouse_filter = Control.MOUSE_FILTER_STOP if (is_reachable and not node.visited) else Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	if map_node == null:
		return

	var center := Vector2(NODE_SIZE * 0.5, NODE_SIZE * 0.5)
	var radius: float = NODE_SIZE * 0.4
	var base_color: Color = NODE_COLORS.get(map_node.node_type, Color.GRAY)

	if map_node.visited:
		# Visited: grey, dimmed
		base_color = base_color.darkened(0.5)
		draw_circle(center, radius, base_color)
		draw_arc(center, radius, 0, TAU, 32, base_color.lightened(0.2), 1.5)
	elif reachable:
		# Reachable: bright with glow
		draw_circle(center, radius + 4, Color(1.0, 1.0, 0.5, 0.3))
		draw_circle(center, radius, base_color)
		draw_arc(center, radius, 0, TAU, 32, Color.WHITE, 2.0)
	else:
		# Locked: dim
		base_color = base_color.darkened(0.3)
		base_color.a = 0.5
		draw_circle(center, radius, base_color)
		draw_arc(center, radius, 0, TAU, 32, base_color.lightened(0.1), 1.0)

	# Draw icon letter
	var icon: String = NODE_ICONS.get(map_node.node_type, "?")
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 18
	var text_size: Vector2 = font.get_string_size(icon, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(
		font,
		center + Vector2(-text_size.x * 0.5, text_size.y * 0.3),
		icon,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.WHITE if not map_node.visited else Color(0.7, 0.7, 0.7),
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if reachable and map_node and not map_node.visited:
				node_clicked.emit(map_node)
