## Manages the fan-shaped arc of cards at the bottom of the battle screen.
## Cards are positioned on an arc and support click-to-select, click-to-confirm.
class_name CardHandUI
extends Control

signal card_selected(card: CardData)

const CARD_UI_SCENE_PATH: String = "res://scenes/ui/card_ui.tscn"
const ARC_RADIUS: float = 600.0
const MAX_SPREAD_ANGLE: float = 30.0  # degrees total spread
const CARD_WIDTH: float = 120.0

var card_ui_scene: PackedScene = null
var _selected_index: int = -1
var _card_uis: Array[CardUI] = []


func _ready() -> void:
	card_ui_scene = load(CARD_UI_SCENE_PATH)
	BattleManager.turn_started.connect(_on_turn_started)
	BattleManager.card_played.connect(_on_card_played)
	BattleManager.turn_ended.connect(_on_turn_ended)
	BattleManager.battle_ended.connect(_on_battle_ended)


func _on_turn_started(character: CharacterData) -> void:
	if character.faction != Enums.Faction.PLAYER:
		clear_hand()
		return
	await get_tree().process_frame
	refresh_hand()


func _on_card_played(_card: CardData, _source: CharacterData, _target: Variant) -> void:
	refresh_hand()


func _on_turn_ended(_character: CharacterData) -> void:
	clear_hand()


func _on_battle_ended(_result: String) -> void:
	clear_hand()


func refresh_hand() -> void:
	clear_hand()
	var hand: Array[CardData] = BattleManager.hand
	var energy: int = BattleManager.current_energy

	for card: CardData in hand:
		var card_ui: CardUI = card_ui_scene.instantiate() as CardUI
		add_child(card_ui)
		var can_play: bool = card.energy_cost <= energy
		card_ui.setup(card, can_play)
		card_ui.card_clicked.connect(_on_card_clicked)
		_card_uis.append(card_ui)

	_selected_index = -1
	_layout_cards()


func clear_hand() -> void:
	_selected_index = -1
	_card_uis.clear()
	for child: Node in get_children():
		child.queue_free()


func _layout_cards() -> void:
	var count: int = _card_uis.size()
	if count == 0:
		return

	# Arc center is below the bottom-center of this control
	var arc_center := Vector2(size.x / 2.0, size.y + ARC_RADIUS - 80.0)

	# Calculate angle per card, clamped to max spread
	var angle_per_card: float = 5.0  # degrees between cards
	var total_angle: float = minf(angle_per_card * (count - 1), MAX_SPREAD_ANGLE) if count > 1 else 0.0
	var start_angle: float = -total_angle / 2.0  # centered

	for i: int in count:
		var card_ui: CardUI = _card_uis[i]

		if i == _selected_index:
			# Selected card: centered, scaled up, no rotation
			card_ui.position = Vector2(size.x / 2.0 - CARD_WIDTH / 2.0, -20.0)
			card_ui.rotation = 0.0
			card_ui.scale = Vector2(1.3, 1.3)
			card_ui.z_index = 20
			card_ui.pivot_offset = card_ui.size / 2.0
			continue

		# Calculate angle for this card (in radians)
		var card_angle_deg: float = start_angle + (total_angle * i / maxi(count - 1, 1))
		var card_angle_rad: float = deg_to_rad(card_angle_deg - 90.0)  # -90 because arc goes up

		var pos := Vector2(
			arc_center.x + ARC_RADIUS * cos(card_angle_rad),
			arc_center.y + ARC_RADIUS * sin(card_angle_rad)
		)

		card_ui.pivot_offset = Vector2(CARD_WIDTH / 2.0, card_ui.size.y)
		card_ui.position = Vector2(pos.x - CARD_WIDTH / 2.0, pos.y - card_ui.size.y)
		card_ui.rotation = deg_to_rad(card_angle_deg)
		card_ui.scale = Vector2.ONE
		card_ui.z_index = i


func _on_card_clicked(card: CardData) -> void:
	var clicked_index: int = -1
	for i: int in _card_uis.size():
		if _card_uis[i].card_data == card:
			clicked_index = i
			break

	if clicked_index < 0:
		return

	if _selected_index == clicked_index:
		# Second click on same card: confirm selection
		card_selected.emit(card)
		_deselect()
	else:
		# First click: select this card
		_selected_index = clicked_index
		_layout_cards()


func _deselect() -> void:
	if _selected_index >= 0:
		_selected_index = -1
		_layout_cards()


func _input(event: InputEvent) -> void:
	if _selected_index < 0:
		return

	if event is InputEventKey:
		var key: InputEventKey = event
		if key.pressed and key.keycode == KEY_ESCAPE:
			_deselect()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_deselect()
			get_viewport().set_input_as_handled()


func update_playability() -> void:
	var energy: int = BattleManager.current_energy
	for card_ui: CardUI in _card_uis:
		if card_ui.card_data:
			card_ui.set_playable(card_ui.card_data.energy_cost <= energy)
