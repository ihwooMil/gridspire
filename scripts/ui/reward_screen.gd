## Reward screen shown after winning a battle.
## Displays gold earned and 3 card offers for the selected character.
extends Control

const CardRegistry = preload("res://scripts/core/card_registry.gd")

@onready var title_label: Label = %TitleLabel
@onready var gold_label: Label = %GoldRewardLabel
@onready var character_tabs: HBoxContainer = %CharacterTabs
@onready var card_container: HBoxContainer = %CardContainer
@onready var skip_button: Button = %SkipButton

var _selected_character: CharacterData = null
var _card_offers: Array[CardData] = []
var _gold_awarded: bool = false


func _ready() -> void:
	skip_button.pressed.connect(_on_skip)
	_award_gold()
	_build_character_tabs()
	if GameManager.party.size() > 0:
		_select_character(GameManager.party[0])


func _award_gold() -> void:
	if _gold_awarded:
		return
	_gold_awarded = true
	var encounter: EncounterData = GameManager.current_encounter
	var gold_amount: int = encounter.gold_reward if encounter else 25
	GameManager.add_gold(gold_amount)
	if title_label:
		title_label.text = "VICTORY"
	if gold_label:
		gold_label.text = "+%d Gold" % gold_amount


func _build_character_tabs() -> void:
	# Clear existing tabs
	for child: Node in character_tabs.get_children():
		child.queue_free()

	for ch: CharacterData in GameManager.party:
		if not ch.is_alive():
			continue
		var btn := Button.new()
		btn.text = ch.character_name
		btn.custom_minimum_size = Vector2(120, 35)
		btn.pressed.connect(_select_character.bind(ch))
		character_tabs.add_child(btn)


func _select_character(character: CharacterData) -> void:
	_selected_character = character
	_generate_card_offers(character)
	_display_card_offers()


func _generate_card_offers(character: CharacterData) -> void:
	_card_offers.clear()
	var class_prefix: String = character.id.split("_")[0] if "_" in character.id else character.id

	# Load all cards from static registry (web build compatible)
	var all_cards: Array[CardData] = CardRegistry.get_class_cards(class_prefix)

	# Shuffle and pick 3 (weighted by rarity — common more likely)
	all_cards.shuffle()

	# Weight: rarity 0 (common) appears more often
	var weighted: Array[CardData] = []
	for card: CardData in all_cards:
		var weight: int = 3 - card.rarity  # common=3, uncommon=2, rare=1
		for i: int in maxi(weight, 1):
			weighted.append(card)
	weighted.shuffle()

	# Pick up to 3 unique cards
	var seen_names: Dictionary = {}
	for card: CardData in weighted:
		if seen_names.has(card.card_name):
			continue
		seen_names[card.card_name] = true
		_card_offers.append(card)
		if _card_offers.size() >= 3:
			break


func _display_card_offers() -> void:
	# Clear existing cards
	for child: Node in card_container.get_children():
		child.queue_free()

	var card_scene: PackedScene = load("res://scenes/ui/card_ui.tscn")
	for card: CardData in _card_offers:
		var card_ui: CardUI = card_scene.instantiate()
		card_container.add_child(card_ui)
		card_ui.setup(card, true)
		card_ui.card_clicked.connect(_on_card_chosen)


func _on_card_chosen(card: CardData) -> void:
	if _selected_character == null:
		return
	# Add a duplicate to the character's deck
	var copy: CardData = card.duplicate(true)
	copy.id = "%s_%s_%d" % [_selected_character.id, card.card_name, _selected_character.starting_deck.size()]
	DeckManager.add_card_to_deck(_selected_character, copy)
	_return_to_map()


func _on_skip() -> void:
	_return_to_map()


func _return_to_map() -> void:
	var encounter: EncounterData = GameManager.current_encounter
	GameManager.current_encounter = null
	GameManager.current_floor += 1
	# If boss was defeated, unlock next difficulty
	if encounter and encounter.is_boss:
		GameManager.on_run_complete()
	GameManager.change_state(Enums.GameState.MAP)
