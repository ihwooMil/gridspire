## Manages the fan-shaped arc of cards at the bottom of the battle screen.
## Cards are positioned on an arc. Single tap selects, drag drops.
class_name CardHandUI
extends Control

signal card_selected(card: CardData)
signal card_drag_started(card: CardData)
signal card_drag_dropped(card: CardData, drop_pos: Vector2)
signal card_drag_moved(card: CardData, screen_pos: Vector2)

const CARD_UI_SCENE_PATH: String = "res://scenes/ui/card_ui.tscn"
const ARC_RADIUS: float = 600.0
const MAX_SPREAD_ANGLE: float = 30.0  # degrees total spread
const CARD_WIDTH: float = 120.0
const CARD_HEIGHT: float = 170.0
## Draw animation origin (local coords, pointing toward CharInfo at bottom-left)
const DRAW_ORIGIN := Vector2(-130.0, -30.0)

var card_ui_scene: PackedScene = null
var _card_uis: Array[CardUI] = []
## Track last known positions of cards for discard animation
var _last_card_positions: Dictionary = {}


func _ready() -> void:
	card_ui_scene = load(CARD_UI_SCENE_PATH)
	BattleManager.turn_started.connect(_on_turn_started)
	BattleManager.turn_ended.connect(_on_turn_ended)
	BattleManager.battle_ended.connect(_on_battle_ended)


func _exit_tree() -> void:
	if BattleManager.turn_started.is_connected(_on_turn_started):
		BattleManager.turn_started.disconnect(_on_turn_started)
	if BattleManager.turn_ended.is_connected(_on_turn_ended):
		BattleManager.turn_ended.disconnect(_on_turn_ended)
	if BattleManager.battle_ended.is_connected(_on_battle_ended):
		BattleManager.battle_ended.disconnect(_on_battle_ended)


func _on_turn_started(character: CharacterData) -> void:
	if character.faction != Enums.Faction.PLAYER:
		clear_hand()
		return
	await get_tree().process_frame
	refresh_hand(true)


func _on_turn_ended(_character: CharacterData) -> void:
	clear_hand()


func _on_battle_ended(_result: String) -> void:
	clear_hand()


func refresh_hand(animate_draw: bool = false) -> void:
	clear_hand()
	var hand: Array[CardData] = BattleManager.hand
	var energy: int = BattleManager.current_energy

	for card: CardData in hand:
		var card_ui: CardUI = card_ui_scene.instantiate() as CardUI
		add_child(card_ui)
		var can_play: bool = card.energy_cost <= energy
		card_ui.setup(card, can_play)
		card_ui.card_clicked.connect(_on_card_clicked)
		card_ui.card_drag_started.connect(_on_card_drag_started)
		card_ui.card_drag_ended.connect(_on_card_drag_ended)
		card_ui.card_drag_moved.connect(_on_card_drag_moved)
		_card_uis.append(card_ui)

	_layout_cards()

	if animate_draw and not _card_uis.is_empty():
		_animate_draw()


func clear_hand() -> void:
	# Save last known positions before clearing
	for card_ui: CardUI in _card_uis:
		if card_ui.card_data:
			_last_card_positions[card_ui.card_data] = card_ui.position
	_card_uis.clear()
	for child: Node in get_children():
		child.queue_free()


func _layout_cards() -> void:
	var count: int = _card_uis.size()
	if count == 0:
		return

	# Use viewport size as fallback when control size is not yet resolved
	var width: float = size.x
	if width <= 0.0:
		width = get_viewport_rect().size.x

	var height: float = size.y
	if height <= 0.0:
		height = 180.0

	# Arc center is below the bottom-center of this control
	var arc_center := Vector2(width / 2.0, height + ARC_RADIUS - 80.0)

	# Calculate angle per card, clamped to max spread
	var angle_per_card: float = 5.0  # degrees between cards
	var total_angle: float = minf(angle_per_card * (count - 1), MAX_SPREAD_ANGLE) if count > 1 else 0.0
	var start_angle: float = -total_angle / 2.0  # centered

	for i: int in count:
		var card_ui: CardUI = _card_uis[i]

		# Calculate angle for this card (in radians)
		var card_angle_deg: float = start_angle + (total_angle * i / maxi(count - 1, 1))
		var card_angle_rad: float = deg_to_rad(card_angle_deg - 90.0)  # -90 because arc goes up

		var pos := Vector2(
			arc_center.x + ARC_RADIUS * cos(card_angle_rad),
			arc_center.y + ARC_RADIUS * sin(card_angle_rad)
		)

		card_ui.pivot_offset = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT)
		card_ui.position = Vector2(pos.x - CARD_WIDTH / 2.0, pos.y - CARD_HEIGHT)
		card_ui.rotation = deg_to_rad(card_angle_deg)
		card_ui.scale = Vector2.ONE
		card_ui.z_index = i

		# Store home transform for snap-back
		card_ui.set_home(card_ui.position, card_ui.rotation, card_ui.scale)

		# Track position for discard animation
		if card_ui.card_data:
			_last_card_positions[card_ui.card_data] = card_ui.position


func _animate_draw() -> void:
	for i: int in _card_uis.size():
		var card_ui: CardUI = _card_uis[i]
		var target_pos: Vector2 = card_ui.position
		var target_rot: float = card_ui.rotation
		var target_scale: Vector2 = card_ui.scale

		# Start from draw origin (CharInfo direction)
		card_ui.position = DRAW_ORIGIN
		card_ui.rotation = 0.0
		card_ui.scale = Vector2(0.3, 0.3)
		card_ui.modulate.a = 0.0

		var delay: float = i * 0.1
		var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.set_parallel(true)
		tween.tween_property(card_ui, "position", target_pos, 0.35).set_delay(delay)
		tween.tween_property(card_ui, "rotation", target_rot, 0.35).set_delay(delay)
		tween.tween_property(card_ui, "scale", target_scale, 0.35).set_delay(delay)
		tween.tween_property(card_ui, "modulate:a", 1.0, 0.2).set_delay(delay)


## Get the last known position of a card (for discard animation).
func get_last_card_position(card: CardData) -> Vector2:
	if _last_card_positions.has(card):
		return _last_card_positions[card]
	# Fallback: center of card hand area
	return Vector2(size.x / 2.0, size.y / 2.0) + global_position - get_parent().global_position


func _on_card_clicked(card: CardData) -> void:
	# Single tap immediately confirms selection
	card_selected.emit(card)


func _on_card_drag_started(card: CardData) -> void:
	card_drag_started.emit(card)


func _on_card_drag_ended(card: CardData, drop_pos: Vector2) -> void:
	card_drag_dropped.emit(card, drop_pos)


func _on_card_drag_moved(card: CardData, screen_pos: Vector2) -> void:
	card_drag_moved.emit(card, screen_pos)


func update_playability() -> void:
	var energy: int = BattleManager.current_energy
	var active: CharacterData = BattleManager.get_active_character()
	for card_ui: CardUI in _card_uis:
		if card_ui.card_data:
			var card: CardData = card_ui.card_data
			var playable: bool = card.energy_cost <= energy
			# Check element_cost requirement
			if playable and card.element_cost > 0 and card.element != "" and active:
				var stacks: int = active.element_stacks.get(card.element, 0)
				if stacks < card.element_cost:
					playable = false
			card_ui.set_playable(playable)
