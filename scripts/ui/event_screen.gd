## Event screen — shown when the player visits an EVENT node on the map.
## Picks one of three random event types and presents choices.
extends Control

const UPGRADE_PATH: String = "res://resources/upgrades/"

enum EventType { BLACKSMITH, HEALING_FOUNTAIN, WANDERING_MERCHANT }

var _event_type: EventType = EventType.BLACKSMITH
var _upgrade_offer: StatUpgrade = null

# UI references (built dynamically)
var _title_label: Label
var _desc_label: RichTextLabel
var _button_container: VBoxContainer


func _ready() -> void:
	_event_type = EventType.values()[randi_range(0, 2)]
	if _event_type == EventType.WANDERING_MERCHANT:
		_load_random_upgrade()
	_build_event_ui()


func _load_random_upgrade() -> void:
	var upgrades: Array[StatUpgrade] = []
	var dir := DirAccess.open(UPGRADE_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var upgrade: StatUpgrade = load(UPGRADE_PATH + file_name) as StatUpgrade
				if upgrade:
					upgrades.append(upgrade)
			file_name = dir.get_next()
		dir.list_dir_end()
	if upgrades.size() > 0:
		upgrades.shuffle()
		_upgrade_offer = upgrades[0]


func _build_event_ui() -> void:
	# Root panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(600, 400)
	panel.position = -Vector2(300, 200)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_title_label)

	# Description
	_desc_label = RichTextLabel.new()
	_desc_label.bbcode_enabled = true
	_desc_label.fit_content = true
	_desc_label.custom_minimum_size = Vector2(0, 80)
	_desc_label.scroll_active = false
	vbox.add_child(_desc_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Button container
	_button_container = VBoxContainer.new()
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_button_container)

	match _event_type:
		EventType.BLACKSMITH:
			_setup_blacksmith()
		EventType.HEALING_FOUNTAIN:
			_setup_healing_fountain()
		EventType.WANDERING_MERCHANT:
			_setup_wandering_merchant()


func _setup_blacksmith() -> void:
	_title_label.text = "The Blacksmith"
	_desc_label.text = "A grizzled blacksmith offers to temper your weapons in exchange for a blood sacrifice.\n\n[i]\"Strength costs something, adventurer.\"[/i]"

	for ch: CharacterData in GameManager.party:
		if not ch.is_alive():
			continue
		var can_afford: bool = ch.current_hp > 5
		var btn := Button.new()
		btn.text = "%s: -5 HP, +1 Strength" % ch.character_name
		btn.custom_minimum_size = Vector2(350, 40)
		btn.disabled = not can_afford
		btn.pressed.connect(_on_blacksmith_choice.bind(ch))
		_button_container.add_child(btn)

	_add_leave_button()


func _on_blacksmith_choice(character: CharacterData) -> void:
	character.current_hp = maxi(character.current_hp - 5, 1)
	# Create a temporary strength upgrade
	var upgrade := StatUpgrade.new()
	upgrade.stat_type = StatUpgrade.StatType.STRENGTH
	upgrade.value = 1
	character.apply_stat_upgrade(upgrade)
	_return_to_map()


func _setup_healing_fountain() -> void:
	_title_label.text = "Healing Fountain"
	_desc_label.text = "Crystal-clear water flows from an ancient fountain, glowing with restorative magic.\n\nChoose a blessing:"

	var btn_heal := Button.new()
	btn_heal.text = "Drink Deep: Full HP restore (all party)"
	btn_heal.custom_minimum_size = Vector2(350, 40)
	btn_heal.pressed.connect(_on_fountain_heal)
	_button_container.add_child(btn_heal)

	for ch: CharacterData in GameManager.party:
		if not ch.is_alive():
			continue
		var btn := Button.new()
		btn.text = "%s: +5 Max HP (permanent)" % ch.character_name
		btn.custom_minimum_size = Vector2(350, 40)
		btn.pressed.connect(_on_fountain_max_hp.bind(ch))
		_button_container.add_child(btn)

	_add_leave_button()


func _on_fountain_heal() -> void:
	for ch: CharacterData in GameManager.party:
		if ch.is_alive():
			ch.current_hp = ch.max_hp
	_return_to_map()


func _on_fountain_max_hp(character: CharacterData) -> void:
	var upgrade := StatUpgrade.new()
	upgrade.stat_type = StatUpgrade.StatType.MAX_HP
	upgrade.value = 5
	character.apply_stat_upgrade(upgrade)
	_return_to_map()


func _setup_wandering_merchant() -> void:
	_title_label.text = "Wandering Merchant"
	if _upgrade_offer == null:
		_desc_label.text = "A hooded merchant appears... but has nothing to sell today."
		_add_leave_button()
		return

	var half_price: int = int(float(_upgrade_offer.price) * 0.5)
	_desc_label.text = "A hooded merchant offers a rare item at half price!\n\n[b]%s[/b]: %s\nPrice: [color=yellow]%dg[/color] (was %dg)" % [
		_upgrade_offer.upgrade_name,
		_upgrade_offer.description,
		half_price,
		_upgrade_offer.price,
	]

	for ch: CharacterData in GameManager.party:
		if not ch.is_alive():
			continue
		var can_afford: bool = GameManager.gold >= half_price
		var btn := Button.new()
		btn.text = "Buy for %s (%dg)" % [ch.character_name, half_price]
		btn.custom_minimum_size = Vector2(350, 40)
		btn.disabled = not can_afford
		btn.pressed.connect(_on_merchant_buy.bind(ch, half_price))
		_button_container.add_child(btn)

	_add_leave_button()


func _on_merchant_buy(character: CharacterData, cost: int) -> void:
	if not GameManager.spend_gold(cost):
		return
	character.apply_stat_upgrade(_upgrade_offer)
	_return_to_map()


func _add_leave_button() -> void:
	var btn := Button.new()
	btn.text = "Leave"
	btn.custom_minimum_size = Vector2(200, 40)
	btn.pressed.connect(_return_to_map)
	_button_container.add_child(btn)


func _return_to_map() -> void:
	GameManager.change_state(Enums.GameState.MAP)
