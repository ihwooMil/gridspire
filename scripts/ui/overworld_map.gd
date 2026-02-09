## Overworld map screen — displays procedural node graph, handles navigation.
extends Control

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var map_content: Control = $ScrollContainer/MapContent
@onready var node_container: Control = $ScrollContainer/MapContent/NodeContainer
@onready var line_drawer: Control = $ScrollContainer/MapContent/LineDrawer
@onready var floor_label: Label = %FloorLabel
@onready var gold_label: Label = %GoldLabel
@onready var party_info: Label = %PartyInfo

var _node_buttons: Array[MapNodeButton] = []

const MAP_MARGIN: float = 100.0


const SCROLL_STEP: int = 80


func _ready() -> void:
	_build_map()
	_update_top_bar()
	# Scroll to left (player starts on the left)
	await get_tree().process_frame
	scroll_container.scroll_horizontal = 0


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_LEFT:
				scroll_container.scroll_horizontal -= SCROLL_STEP
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
				scroll_container.scroll_horizontal += SCROLL_STEP
				get_viewport().set_input_as_handled()


func _build_map() -> void:
	var map: MapData = GameManager.current_map
	if map == null:
		return

	# Clear old nodes
	for btn: MapNodeButton in _node_buttons:
		btn.queue_free()
	_node_buttons.clear()

	# Calculate content width for horizontal layout
	var max_row: int = map.total_rows + 1
	var content_width: float = float(max_row + 1) * 140.0 + MAP_MARGIN * 2.0
	map_content.custom_minimum_size = Vector2(content_width, 700)

	var reachable_nodes: Array[MapNode] = map.get_reachable_nodes()
	var reachable_ids: Array[int] = []
	for n: MapNode in reachable_nodes:
		reachable_ids.append(n.id)

	# Create node buttons
	for node: MapNode in map.nodes:
		if node.node_type == Enums.MapNodeType.START:
			continue  # Don't show start node as clickable
		var btn := MapNodeButton.new()
		var is_reachable: bool = node.id in reachable_ids
		# Offset position by margin
		var adjusted_node := node
		btn.setup(adjusted_node, is_reachable)
		btn.position += Vector2(MAP_MARGIN, MAP_MARGIN)
		btn.node_clicked.connect(_on_node_clicked)
		node_container.add_child(btn)
		_node_buttons.append(btn)

	# Redraw connection lines
	line_drawer.queue_redraw()


func _update_top_bar() -> void:
	if floor_label:
		floor_label.text = "Floor %d" % GameManager.current_floor
	if gold_label:
		gold_label.text = "Gold: %d" % GameManager.gold
	if party_info:
		var parts: PackedStringArray = []
		for ch: CharacterData in GameManager.party:
			parts.append("%s %d/%d" % [ch.character_name, ch.current_hp, ch.max_hp])
		party_info.text = " | ".join(parts)


func _on_node_clicked(map_node: MapNode) -> void:
	var map: MapData = GameManager.current_map
	if map == null:
		return

	# Mark as visited and update current position
	map_node.visited = true
	map.current_node_id = map_node.id

	match map_node.node_type:
		Enums.MapNodeType.BATTLE, Enums.MapNodeType.ELITE, Enums.MapNodeType.BOSS:
			_start_encounter(map_node)
		Enums.MapNodeType.SHOP:
			GameManager.change_state(Enums.GameState.SHOP)
		Enums.MapNodeType.REST:
			_do_rest()
		Enums.MapNodeType.EVENT:
			GameManager.change_state(Enums.GameState.EVENT)
		Enums.MapNodeType.COMPANION:
			GameManager.set_meta("companion_event", true)
			GameManager.change_state(Enums.GameState.EVENT)


func _start_encounter(map_node: MapNode) -> void:
	var encounter := EncounterData.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(GameManager.current_floor * 1000 + map_node.id)

	match map_node.node_type:
		Enums.MapNodeType.BOSS:
			match rng.randi_range(0, 1):
				0:
					encounter.enemy_ids = ["dragon_whelp"]
				1:
					encounter.enemy_ids = ["lich_king", "skeleton_archer", "skeleton_archer"]
			encounter.gold_reward = 100
			encounter.is_boss = true
			encounter.grid_width = 12
			encounter.grid_height = 8
		Enums.MapNodeType.ELITE:
			if GameManager.current_floor <= 5:
				encounter.enemy_ids = ["orc_warchief"]
			elif GameManager.current_floor <= 9:
				match rng.randi_range(0, 1):
					0: encounter.enemy_ids = ["dark_knight"]
					1: encounter.enemy_ids = ["orc_warchief", "goblin"]
			else:
				match rng.randi_range(0, 1):
					0: encounter.enemy_ids = ["necromancer"]
					1: encounter.enemy_ids = ["dark_knight", "skeleton_archer"]
			encounter.gold_reward = 50
			encounter.is_elite = true
		_:
			# Normal battle - varies by floor
			if GameManager.current_floor <= 3:
				encounter.enemy_ids = ["goblin"]
			elif GameManager.current_floor <= 5:
				match rng.randi_range(0, 2):
					0: encounter.enemy_ids = ["goblin", "goblin"]
					1: encounter.enemy_ids = ["slime"]
					2: encounter.enemy_ids = ["goblin", "slime"]
			elif GameManager.current_floor <= 8:
				match rng.randi_range(0, 2):
					0: encounter.enemy_ids = ["bandit"]
					1: encounter.enemy_ids = ["skeleton_archer", "goblin"]
					2: encounter.enemy_ids = ["slime", "goblin"]
			elif GameManager.current_floor <= 11:
				match rng.randi_range(0, 2):
					0: encounter.enemy_ids = ["bandit", "skeleton_archer"]
					1: encounter.enemy_ids = ["bandit", "goblin"]
					2: encounter.enemy_ids = ["skeleton_archer", "skeleton_archer"]
			else:
				match rng.randi_range(0, 2):
					0: encounter.enemy_ids = ["bandit", "bandit"]
					1: encounter.enemy_ids = ["skeleton_archer", "slime"]
					2: encounter.enemy_ids = ["bandit", "skeleton_archer"]
			encounter.gold_reward = 25

	GameManager.current_encounter = encounter
	GameManager.change_state(Enums.GameState.BATTLE)


func _do_rest() -> void:
	# Heal all party members by 30% of max HP
	for ch: CharacterData in GameManager.party:
		if ch.is_alive():
			var heal_amount: int = int(float(ch.max_hp) * 0.3)
			ch.heal(heal_amount)
	_build_map()
	_update_top_bar()
