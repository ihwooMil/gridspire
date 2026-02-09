## Shop screen — buy cards and remove cards from decks.
extends Control

@onready var gold_label: Label = %ShopGoldLabel
@onready var buy_container: HBoxContainer = %BuyContainer
@onready var remove_tabs: HBoxContainer = %RemoveTabs
@onready var remove_container: HBoxContainer = %RemoveContainer
@onready var leave_button: Button = %LeaveButton

var _shop_cards: Array[Dictionary] = []  # [{card: CardData, price: int}]
var _selected_remove_character: CharacterData = null

const RARITY_PRICES: Dictionary = {
	0: 50,   # Common
	1: 75,   # Uncommon
	2: 150,  # Rare
}
const REMOVE_COST: int = 75
const ALL_CARD_PATHS: Array = [
	"res://resources/cards/warrior/",
	"res://resources/cards/mage/",
	"res://resources/cards/rogue/",
]
const UPGRADE_PATH: String = "res://resources/upgrades/"
var _upgrade_offers: Array[Dictionary] = []  # [{upgrade: StatUpgrade, price: int}]


func _ready() -> void:
	leave_button.pressed.connect(_on_leave)
	GameManager.gold_changed.connect(_update_gold_display)
	_update_gold_display(GameManager.gold)
	_generate_shop_inventory()
	_generate_upgrade_offers()
	_display_shop_cards()
	_display_upgrade_offers()
	_build_remove_tabs()


func _update_gold_display(_amount: int) -> void:
	if gold_label:
		gold_label.text = "Gold: %d" % GameManager.gold


func _generate_shop_inventory() -> void:
	_shop_cards.clear()
	var all_cards: Array[CardData] = []

	for card_path: String in ALL_CARD_PATHS:
		var dir := DirAccess.open(card_path)
		if dir:
			dir.list_dir_begin()
			var file_name: String = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".tres"):
					var card: CardData = load(card_path + file_name) as CardData
					if card:
						all_cards.append(card)
				file_name = dir.get_next()
			dir.list_dir_end()

	all_cards.shuffle()

	# Pick 6 unique cards
	var seen: Dictionary = {}
	for card: CardData in all_cards:
		if seen.has(card.card_name):
			continue
		seen[card.card_name] = true
		var price: int = RARITY_PRICES.get(card.rarity, 50)
		_shop_cards.append({"card": card, "price": price})
		if _shop_cards.size() >= 6:
			break


func _display_shop_cards() -> void:
	for child: Node in buy_container.get_children():
		child.queue_free()

	var card_scene: PackedScene = load("res://scenes/ui/card_ui.tscn")
	for i: int in _shop_cards.size():
		var entry: Dictionary = _shop_cards[i]
		var card: CardData = entry["card"]
		var price: int = entry["price"]

		var wrapper := VBoxContainer.new()
		wrapper.alignment = BoxContainer.ALIGNMENT_CENTER

		var card_ui: CardUI = card_scene.instantiate()
		wrapper.add_child(card_ui)
		card_ui.setup(card, GameManager.gold >= price)

		var price_btn := Button.new()
		price_btn.text = "%dg" % price
		price_btn.custom_minimum_size = Vector2(80, 30)
		price_btn.disabled = GameManager.gold < price
		price_btn.pressed.connect(_on_buy_card.bind(i))
		wrapper.add_child(price_btn)

		buy_container.add_child(wrapper)


func _on_buy_card(index: int) -> void:
	if index >= _shop_cards.size():
		return
	var entry: Dictionary = _shop_cards[index]
	var card: CardData = entry["card"]
	var price: int = entry["price"]

	if not GameManager.spend_gold(price):
		return

	# Add to first alive party member (or selected character)
	# For simplicity, add to the first alive party member
	var target: CharacterData = null
	for ch: CharacterData in GameManager.party:
		if ch.is_alive():
			# Match class if possible
			if card.card_name.begins_with(ch.id.split("_")[0] if "_" in ch.id else ch.id):
				target = ch
				break
	if target == null:
		for ch: CharacterData in GameManager.party:
			if ch.is_alive():
				target = ch
				break
	if target == null:
		return

	var copy: CardData = card.duplicate(true)
	copy.id = "%s_%s_%d" % [target.id, card.card_name, target.starting_deck.size()]
	DeckManager.add_card_to_deck(target, copy)

	# Remove from shop
	_shop_cards.remove_at(index)
	_display_shop_cards()


func _build_remove_tabs() -> void:
	for child: Node in remove_tabs.get_children():
		child.queue_free()

	for ch: CharacterData in GameManager.party:
		if not ch.is_alive():
			continue
		var btn := Button.new()
		btn.text = "%s (%d cards)" % [ch.character_name, ch.starting_deck.size()]
		btn.custom_minimum_size = Vector2(150, 30)
		btn.pressed.connect(_select_remove_character.bind(ch))
		remove_tabs.add_child(btn)


func _select_remove_character(character: CharacterData) -> void:
	_selected_remove_character = character
	_display_removable_cards()


func _display_removable_cards() -> void:
	for child: Node in remove_container.get_children():
		child.queue_free()

	if _selected_remove_character == null:
		return

	var card_scene: PackedScene = load("res://scenes/ui/card_ui.tscn")
	var can_afford: bool = GameManager.gold >= REMOVE_COST

	for card: CardData in _selected_remove_character.starting_deck:
		var wrapper := VBoxContainer.new()
		wrapper.alignment = BoxContainer.ALIGNMENT_CENTER

		var card_ui: CardUI = card_scene.instantiate()
		wrapper.add_child(card_ui)
		card_ui.setup(card, can_afford)

		var remove_btn := Button.new()
		remove_btn.text = "Remove (%dg)" % REMOVE_COST
		remove_btn.custom_minimum_size = Vector2(100, 28)
		remove_btn.disabled = not can_afford
		remove_btn.pressed.connect(_on_remove_card.bind(card))
		wrapper.add_child(remove_btn)

		remove_container.add_child(wrapper)


func _on_remove_card(card: CardData) -> void:
	if _selected_remove_character == null:
		return
	if not GameManager.spend_gold(REMOVE_COST):
		return
	DeckManager.remove_card_from_deck(_selected_remove_character, card)
	_build_remove_tabs()
	_display_removable_cards()


func _generate_upgrade_offers() -> void:
	_upgrade_offers.clear()
	var all_upgrades: Array[StatUpgrade] = []
	var dir := DirAccess.open(UPGRADE_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var upgrade: StatUpgrade = load(UPGRADE_PATH + file_name) as StatUpgrade
				if upgrade:
					all_upgrades.append(upgrade)
			file_name = dir.get_next()
		dir.list_dir_end()

	all_upgrades.shuffle()
	for i: int in mini(3, all_upgrades.size()):
		var upgrade: StatUpgrade = all_upgrades[i]
		_upgrade_offers.append({"upgrade": upgrade, "price": upgrade.price})


func _display_upgrade_offers() -> void:
	if _upgrade_offers.is_empty():
		return

	# Add a separator label
	var sep_label := Label.new()
	sep_label.text = "STAT UPGRADES"
	sep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep_label.add_theme_font_size_override("font_size", 14)
	var sep_wrapper := VBoxContainer.new()
	sep_wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	sep_wrapper.add_child(sep_label)
	buy_container.add_child(sep_wrapper)

	for i: int in _upgrade_offers.size():
		var entry: Dictionary = _upgrade_offers[i]
		var upgrade: StatUpgrade = entry["upgrade"]
		var price: int = entry["price"]

		var wrapper := VBoxContainer.new()
		wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
		wrapper.custom_minimum_size = Vector2(140, 0)

		# Upgrade name and description
		var name_label := Label.new()
		name_label.text = upgrade.upgrade_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 14)
		wrapper.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = upgrade.description
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.add_theme_font_size_override("font_size", 11)
		wrapper.add_child(desc_label)

		# Character selection buttons
		for ch: CharacterData in GameManager.party:
			if not ch.is_alive():
				continue
			var btn := Button.new()
			btn.text = "%s (%dg)" % [ch.character_name, price]
			btn.custom_minimum_size = Vector2(130, 28)
			btn.disabled = GameManager.gold < price
			btn.pressed.connect(_on_buy_upgrade.bind(i, ch))
			wrapper.add_child(btn)

		buy_container.add_child(wrapper)


func _on_buy_upgrade(index: int, character: CharacterData) -> void:
	if index >= _upgrade_offers.size():
		return
	var entry: Dictionary = _upgrade_offers[index]
	var upgrade: StatUpgrade = entry["upgrade"]
	var price: int = entry["price"]

	if not GameManager.spend_gold(price):
		return

	character.apply_stat_upgrade(upgrade)

	# Remove from offers
	_upgrade_offers.remove_at(index)
	# Refresh the full buy section
	_display_shop_cards()
	_display_upgrade_offers()


func _on_leave() -> void:
	GameManager.change_state(Enums.GameState.MAP)
