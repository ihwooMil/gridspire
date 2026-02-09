## Procedural Slay the Spire-style map generator.
class_name MapGenerator


## Generate a full map for a run.
static func generate(map_seed: int = 0) -> MapData:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed if map_seed != 0 else randi()

	var map := MapData.new()
	map.total_rows = 15
	var next_id: int = 0

	# Row 0: single START node
	var start_node := MapNode.new()
	start_node.id = next_id
	start_node.row = 0
	start_node.column = 0
	start_node.node_type = Enums.MapNodeType.START
	next_id += 1
	map.nodes.append(start_node)

	# Rows 1..14: generated nodes
	for row: int in range(1, 15):
		var count: int = rng.randi_range(2, 4)
		var row_nodes: Array[MapNode] = []
		for col: int in count:
			var node := MapNode.new()
			node.id = next_id
			node.row = row
			node.column = col
			node.node_type = _pick_node_type(row, rng)
			next_id += 1
			row_nodes.append(node)
			map.nodes.append(node)

	# Row 15: single BOSS node
	var boss_node := MapNode.new()
	boss_node.id = next_id
	boss_node.row = 15
	boss_node.column = 0
	boss_node.node_type = Enums.MapNodeType.BOSS
	next_id += 1
	map.nodes.append(boss_node)

	# Force row 12 to be REST
	for node: MapNode in map.get_nodes_in_row(12):
		node.node_type = Enums.MapNodeType.REST

	# Generate connections between adjacent rows (no crossing constraint)
	for row: int in range(0, 15):
		var current_row: Array[MapNode] = map.get_nodes_in_row(row)
		var next_row: Array[MapNode] = map.get_nodes_in_row(row + 1)
		if current_row.is_empty() or next_row.is_empty():
			continue
		_connect_rows(current_row, next_row, rng)

	# Connect row 14 to boss
	var row_14: Array[MapNode] = map.get_nodes_in_row(14)
	for node: MapNode in row_14:
		node.connections.append(boss_node.id)

	# Assign visual positions
	_assign_positions(map)

	return map


static func _pick_node_type(row: int, rng: RandomNumberGenerator) -> Enums.MapNodeType:
	# Early rows (1-4): mostly battles
	if row <= 4:
		var roll: int = rng.randi_range(0, 9)
		if roll < 7:
			return Enums.MapNodeType.BATTLE
		if roll < 9:
			return Enums.MapNodeType.EVENT
		return Enums.MapNodeType.ELITE

	# Mid rows (5-9): mixed
	if row <= 9:
		var roll: int = rng.randi_range(0, 9)
		if roll < 3:
			return Enums.MapNodeType.BATTLE
		if roll < 5:
			return Enums.MapNodeType.ELITE
		if roll < 7:
			return Enums.MapNodeType.EVENT
		if roll < 8:
			return Enums.MapNodeType.SHOP
		return Enums.MapNodeType.REST

	# Late rows (10-14): harder fights, pre-boss
	if row <= 11:
		var roll: int = rng.randi_range(0, 9)
		if roll < 3:
			return Enums.MapNodeType.BATTLE
		if roll < 6:
			return Enums.MapNodeType.ELITE
		if roll < 8:
			return Enums.MapNodeType.REST
		return Enums.MapNodeType.SHOP

	# Row 12 is forced to REST (handled after generation)
	# Rows 13-14: elites and battles
	var roll: int = rng.randi_range(0, 9)
	if roll < 4:
		return Enums.MapNodeType.ELITE
	if roll < 8:
		return Enums.MapNodeType.BATTLE
	return Enums.MapNodeType.REST


## Connect two adjacent rows without crossing paths.
## Sorted by column, each node connects to nearby column(s) in the next row.
static func _connect_rows(current: Array[MapNode], next_row: Array[MapNode], rng: RandomNumberGenerator) -> void:
	# Ensure every current node connects to at least one next node,
	# and every next node is reachable from at least one current node.
	var next_covered: Dictionary = {}  # next node id -> bool

	for i: int in current.size():
		# Map the current node's relative position to the next row
		var ratio: float = float(i) / float(maxi(current.size() - 1, 1))
		var target_idx: int = roundi(ratio * float(next_row.size() - 1))

		# Connect to the closest node, plus maybe one neighbor
		var min_idx: int = maxi(target_idx - 1, 0)
		var max_idx: int = mini(target_idx + 1, next_row.size() - 1)

		# Always connect to the primary target
		current[i].connections.append(next_row[target_idx].id)
		next_covered[next_row[target_idx].id] = true

		# Randomly connect to one adjacent node for branching
		if rng.randi_range(0, 1) == 1 and min_idx != target_idx:
			current[i].connections.append(next_row[min_idx].id)
			next_covered[next_row[min_idx].id] = true
		elif rng.randi_range(0, 1) == 1 and max_idx != target_idx:
			current[i].connections.append(next_row[max_idx].id)
			next_covered[next_row[max_idx].id] = true

	# Ensure all next row nodes are reachable
	for node: MapNode in next_row:
		if not next_covered.has(node.id):
			# Connect from the nearest current node
			var best_idx: int = 0
			var best_dist: float = 999.0
			for i: int in current.size():
				var dist: float = absf(float(current[i].column) - float(node.column))
				if dist < best_dist:
					best_dist = dist
					best_idx = i
			current[best_idx].connections.append(node.id)


## Assign visual positions to all nodes for rendering.
static func _assign_positions(map: MapData) -> void:
	var col_width: float = 140.0
	var map_height: float = 600.0

	for node: MapNode in map.nodes:
		var row_nodes: Array[MapNode] = map.get_nodes_in_row(node.row)
		var count: int = row_nodes.size()
		var idx: int = row_nodes.find(node)

		# Left-to-right layout (row 0 on left, boss on right)
		var x: float = float(node.row) * col_width

		var y: float
		if count == 1:
			y = map_height * 0.5
		else:
			var spacing: float = map_height / float(count + 1)
			y = spacing * float(idx + 1)

		node.position = Vector2(x, y)
