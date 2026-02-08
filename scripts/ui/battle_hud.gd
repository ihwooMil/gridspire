## Main battle HUD overlay. Contains character info, card hand, timeline, and end turn button.
## Acts as the coordinator for all battle UI sub-components.
class_name BattleHUD
extends Control

@onready var character_info: CharacterInfoPanel = %CharacterInfo
@onready var card_hand: CardHandUI = %CardHand
@onready var timeline_bar: TimelineBar = %TimelineBar
@onready var end_turn_button: Button = %EndTurnButton
@onready var energy_label: Label = %BattleEnergyLabel
@onready var turn_label: Label = %BattleTurnLabel
@onready var draw_count_label: Label = %DrawCountLabel
@onready var discard_count_label: Label = %DiscardCountLabel

var _active_character: CharacterData = null


func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	card_hand.card_selected.connect(_on_card_selected)

	BattleManager.turn_started.connect(_on_turn_started)
	BattleManager.turn_ended.connect(_on_turn_ended)
	BattleManager.card_played.connect(_on_card_played)
	BattleManager.battle_started.connect(_on_battle_started)
	BattleManager.battle_ended.connect(_on_battle_ended)
	BattleManager.energy_changed.connect(_on_energy_changed)
	BattleManager.hand_updated.connect(_on_hand_updated)

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

	if turn_label:
		turn_label.text = "%s's Turn" % character.character_name

	_update_energy_display()
	_update_pile_counts()


func _on_turn_ended(_character: CharacterData) -> void:
	_active_character = null


func _on_card_played(_card: CardData, _source: CharacterData, _target: Variant) -> void:
	_update_energy_display()
	_update_pile_counts()
	card_hand.update_playability()


func _on_card_selected(card: CardData) -> void:
	if _active_character == null:
		return
	if _active_character.faction != Enums.Faction.PLAYER:
		return
	# Use BattleManager's valid target system for auto-targeting
	var targets: Array = BattleManager.get_valid_targets(card, _active_character)
	if not targets.is_empty():
		BattleManager.play_card(card, _active_character, targets[0])


func _on_end_turn_pressed() -> void:
	BattleManager.end_turn()


func _on_energy_changed(current: int, _max_energy: int) -> void:
	if energy_label:
		energy_label.text = "Energy: %d / %d" % [current, _max_energy]
	card_hand.update_playability()


func _on_hand_updated(_hand: Array[CardData]) -> void:
	card_hand.refresh_hand()
	_update_pile_counts()


func _update_energy_display() -> void:
	if energy_label:
		energy_label.text = "Energy: %d / %d" % [BattleManager.current_energy, BattleManager.max_energy]


func _update_pile_counts() -> void:
	if _active_character == null:
		return
	if draw_count_label:
		draw_count_label.text = "Draw: %d" % DeckManager.get_draw_count(_active_character)
	if discard_count_label:
		discard_count_label.text = "Discard: %d" % DeckManager.get_discard_count(_active_character)
