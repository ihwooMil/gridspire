## Main battle HUD overlay. Contains character info, card hand, timeline, and end turn button.
## Acts as the coordinator for all battle UI sub-components.
class_name BattleHUD
extends Control

@onready var character_info: CharacterInfoPanel = %CharacterInfo
@onready var card_hand: CardHandUI = %CardHand
@onready var timeline_bar: TimelineBar = %TimelineBar
@onready var end_turn_button: Button = %EndTurnButton
@onready var turn_label: Label = %BattleTurnLabel
@onready var graveyard_button: Button = %GraveyardButton
@onready var graveyard_popup: PanelContainer = %GraveyardPopup
@onready var graveyard_card_grid: GridContainer = %GraveyardCardGrid
@onready var graveyard_close_button: Button = %CloseButton

signal targeting_requested(card: CardData, source: CharacterData)
signal drag_drop_requested(card: CardData, source: CharacterData, drop_pos: Vector2)
signal drag_hover_updated(screen_pos: Vector2)

var _active_character: CharacterData = null
var _card_ui_scene: PackedScene = null


func _ready() -> void:
	_card_ui_scene = load("res://scenes/ui/card_ui.tscn")

	end_turn_button.pressed.connect(_on_end_turn_pressed)
	card_hand.card_selected.connect(_on_card_selected)
	card_hand.card_drag_started.connect(_on_card_drag_started)
	card_hand.card_drag_dropped.connect(_on_card_drag_dropped)
	card_hand.card_drag_moved.connect(_on_card_drag_moved)

	graveyard_button.pressed.connect(_on_graveyard_pressed)
	graveyard_close_button.pressed.connect(_on_graveyard_close_pressed)

	BattleManager.turn_started.connect(_on_turn_started)
	BattleManager.turn_ended.connect(_on_turn_ended)
	BattleManager.card_played.connect(_on_card_played)
	BattleManager.battle_started.connect(_on_battle_started)
	BattleManager.battle_ended.connect(_on_battle_ended)
	BattleManager.energy_changed.connect(_on_energy_changed)
	BattleManager.hand_updated.connect(_on_hand_updated)
	DeckManager.cards_discarded.connect(_on_cards_discarded)

	_set_battle_visible(false)


func _on_battle_started() -> void:
	_set_battle_visible(true)


func _on_battle_ended(_result: String) -> void:
	_set_battle_visible(false)


func _set_battle_visible(vis: bool) -> void:
	visible = vis


func _on_turn_started(character: CharacterData) -> void:
	_active_character = character
	character_info.setup(character)

	var is_player: bool = character.faction == Enums.Faction.PLAYER
	end_turn_button.visible = is_player
	end_turn_button.disabled = not is_player
	graveyard_button.visible = is_player

	if turn_label:
		turn_label.text = "%s's Turn" % character.character_name

	_update_pile_counts()


func _on_turn_ended(_character: CharacterData) -> void:
	_active_character = null


func _on_card_played(card: CardData, _source: CharacterData, _target: Variant) -> void:
	_update_pile_counts()
	card_hand.update_playability()
	# Animate card flying to graveyard
	_animate_discard_to_graveyard(card)


func _on_card_selected(card: CardData) -> void:
	if _active_character == null:
		return
	if _active_character.faction != Enums.Faction.PLAYER:
		return

	match card.target_type:
		Enums.TargetType.SELF, Enums.TargetType.NONE, Enums.TargetType.ALL_ALLIES, Enums.TargetType.ALL_ENEMIES:
			pass
		_:
			targeting_requested.emit(card, _active_character)


func _on_card_drag_started(card: CardData) -> void:
	if _active_character and _active_character.faction == Enums.Faction.PLAYER:
		match card.target_type:
			Enums.TargetType.SELF, Enums.TargetType.NONE, Enums.TargetType.ALL_ALLIES, Enums.TargetType.ALL_ENEMIES:
				pass
			_:
				targeting_requested.emit(card, _active_character)


func _on_card_drag_dropped(card: CardData, drop_pos: Vector2) -> void:
	if _active_character == null or _active_character.faction != Enums.Faction.PLAYER:
		return
	drag_drop_requested.emit(card, _active_character, drop_pos)


func _on_card_drag_moved(_card: CardData, screen_pos: Vector2) -> void:
	drag_hover_updated.emit(screen_pos)


func _on_end_turn_pressed() -> void:
	BattleManager.end_turn()


func _on_energy_changed(_current: int, _max_energy: int) -> void:
	card_hand.update_playability()


func _on_hand_updated(_hand: Array[CardData]) -> void:
	card_hand.refresh_hand()
	_update_pile_counts()


func _on_cards_discarded(_character: CharacterData, _cards: Array[CardData]) -> void:
	_update_pile_counts()


func _update_pile_counts() -> void:
	if _active_character == null:
		return
	var discard_count: int = DeckManager.get_discard_count(_active_character)
	if graveyard_button:
		graveyard_button.text = "Grave\n(%d)" % discard_count


func _on_graveyard_pressed() -> void:
	if _active_character == null:
		return

	# Clear old children
	for child: Node in graveyard_card_grid.get_children():
		child.queue_free()

	# Populate with discard pile cards
	var pile: Array[CardData] = DeckManager.get_discard_pile(_active_character)
	for card: CardData in pile:
		var card_ui: CardUI = _card_ui_scene.instantiate() as CardUI
		graveyard_card_grid.add_child(card_ui)
		card_ui.setup(card, false)
		card_ui.custom_minimum_size = Vector2(120, 170)

	graveyard_popup.visible = true


func _on_graveyard_close_pressed() -> void:
	graveyard_popup.visible = false
	for child: Node in graveyard_card_grid.get_children():
		child.queue_free()


func _animate_discard_to_graveyard(card: CardData) -> void:
	if _card_ui_scene == null or graveyard_button == null:
		return
	# Create a temporary card UI that flies to the graveyard button
	var temp_card: CardUI = _card_ui_scene.instantiate() as CardUI
	add_child(temp_card)
	temp_card.setup(card, false)
	temp_card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Get last card position from card_hand, or use center of hand area
	var start_pos: Vector2 = card_hand.get_last_card_position(card)
	var target_pos: Vector2 = graveyard_button.global_position - global_position

	temp_card.position = start_pos
	temp_card.scale = Vector2(0.7, 0.7)

	var tween: Tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(true)
	tween.tween_property(temp_card, "position", target_pos, 0.4)
	tween.tween_property(temp_card, "scale", Vector2(0.1, 0.1), 0.4)
	tween.tween_property(temp_card, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(temp_card.queue_free)
