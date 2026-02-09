## Visual representation of a single card in the hand.
## Displays card name, cost, description, and handles hover/click/drag interactions.
class_name CardUI
extends PanelContainer

signal card_clicked(card_data: CardData)
signal card_hovered(card_data: CardData)
signal card_unhovered(card_data: CardData)
signal card_drag_started(card_data: CardData)
signal card_drag_ended(card_data: CardData)

@onready var name_label: Label = %NameLabel
@onready var cost_label: Label = %CostLabel
@onready var description_label: Label = %DescriptionLabel
@onready var icon_rect: TextureRect = %IconRect
@onready var rarity_bar: ColorRect = %RarityBar

var card_data: CardData = null
var playable: bool = true
var _base_scale: Vector2 = Vector2.ONE
var _hover_scale: Vector2 = Vector2(1.15, 1.15)
var _is_hovered: bool = false
var _is_dragging: bool = false
var _press_position: Vector2 = Vector2.ZERO
var _drag_offset: Vector2 = Vector2.ZERO

const DRAG_THRESHOLD: float = 10.0

const RARITY_COLORS: Array[Color] = [
	Color(0.6, 0.6, 0.6),    # Common: grey
	Color(0.3, 0.7, 1.0),    # Uncommon: blue
	Color(1.0, 0.8, 0.2),    # Rare: gold
]


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size / 2.0


func setup(data: CardData, is_playable: bool = true) -> void:
	card_data = data
	playable = is_playable

	if name_label:
		name_label.text = data.card_name
	if cost_label:
		cost_label.text = str(data.energy_cost)
	if description_label:
		description_label.text = data.get_display_text()
	if icon_rect and data.icon:
		icon_rect.texture = data.icon
	if rarity_bar:
		var idx: int = clampi(data.rarity, 0, RARITY_COLORS.size() - 1)
		rarity_bar.color = RARITY_COLORS[idx]

	_update_playable_visual()


func set_playable(is_playable: bool) -> void:
	playable = is_playable
	_update_playable_visual()


func _update_playable_visual() -> void:
	if playable:
		modulate = Color.WHITE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		modulate = Color(0.5, 0.5, 0.5, 0.8)
		mouse_default_cursor_shape = Control.CURSOR_ARROW


func _on_mouse_entered() -> void:
	if _is_dragging:
		return
	_is_hovered = true
	z_index = 10
	pivot_offset = size / 2.0
	var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", _hover_scale, 0.15)
	card_hovered.emit(card_data)


func _on_mouse_exited() -> void:
	if _is_dragging:
		return
	_is_hovered = false
	z_index = 0
	var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", _base_scale, 0.15)
	card_unhovered.emit(card_data)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_position = mb.global_position
			else:
				# Mouse released
				if _is_dragging:
					_is_dragging = false
					card_drag_ended.emit(card_data)
				else:
					# No drag occurred, treat as click
					if playable and card_data:
						card_clicked.emit(card_data)

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and playable and card_data:
			if not _is_dragging:
				var dist: float = mm.global_position.distance_to(_press_position)
				if dist > DRAG_THRESHOLD:
					_is_dragging = true
					_drag_offset = global_position - mm.global_position
					card_drag_started.emit(card_data)
			if _is_dragging:
				global_position = mm.global_position + _drag_offset
