## Manages the row of cards at the bottom of the battle screen.
## Listens to BattleManager signals to update the hand display.
class_name CardHandUI
extends HBoxContainer

signal card_selected(card: CardData)

const CARD_UI_SCENE_PATH: String = "res://scenes/ui/card_ui.tscn"
var card_ui_scene: PackedScene = null


func _ready() -> void:
	card_ui_scene = load(CARD_UI_SCENE_PATH)
	BattleManager.turn_started.connect(_on_turn_started)
	BattleManager.card_played.connect(_on_card_played)
	BattleManager.turn_ended.connect(_on_turn_ended)
	BattleManager.battle_ended.connect(_on_battle_ended)


func _on_turn_started(character: CharacterData) -> void:
	# Only show hand for player characters
	if character.faction != Enums.Faction.PLAYER:
		clear_hand()
		return
	# Small delay to let draw phase complete
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


func clear_hand() -> void:
	for child: Node in get_children():
		child.queue_free()


func _on_card_clicked(card: CardData) -> void:
	card_selected.emit(card)


func update_playability() -> void:
	var energy: int = BattleManager.current_energy
	for child: Node in get_children():
		if child is CardUI:
			var card_ui: CardUI = child
			if card_ui.card_data:
				card_ui.set_playable(card_ui.card_data.energy_cost <= energy)
