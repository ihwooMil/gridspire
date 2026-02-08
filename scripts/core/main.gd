## Main scene script — entry point and top-level scene coordinator.
extends Node2D

@onready var end_turn_button: Button = $UI/BattleUI/EndTurnButton
@onready var turn_label: Label = $UI/BattleUI/TopBar/TurnLabel
@onready var hand_container: HBoxContainer = $UI/BattleUI/HandContainer
@onready var timeline_label: Label = $UI/BattleUI/TimelinePanel/TimelineLabel
@onready var grid_container: Node2D = $GridContainer


func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	BattleManager.turn_started.connect(_on_turn_started)
	BattleManager.battle_ended.connect(_on_battle_ended)
	BattleManager.timeline_updated.connect(_on_timeline_updated)

	# For now, start a test battle
	_start_test_battle()


func _start_test_battle() -> void:
	# Create test characters
	var warrior := CharacterData.new()
	warrior.id = "warrior"
	warrior.character_name = "Warrior"
	warrior.max_hp = 60
	warrior.current_hp = 60
	warrior.speed = 100
	warrior.energy_per_turn = 3
	warrior.move_range = 3
	warrior.faction = Enums.Faction.PLAYER

	var mage := CharacterData.new()
	mage.id = "mage"
	mage.character_name = "Mage"
	mage.max_hp = 40
	mage.current_hp = 40
	mage.speed = 80
	mage.energy_per_turn = 3
	mage.move_range = 2
	mage.faction = Enums.Faction.PLAYER

	var enemy_a := CharacterData.new()
	enemy_a.id = "goblin_1"
	enemy_a.character_name = "Goblin"
	enemy_a.max_hp = 30
	enemy_a.current_hp = 30
	enemy_a.speed = 90
	enemy_a.energy_per_turn = 2
	enemy_a.move_range = 2
	enemy_a.faction = Enums.Faction.ENEMY

	# Create some test cards
	_add_basic_cards(warrior, "Strike", Enums.CardEffectType.DAMAGE, 6, 1)
	_add_basic_cards(warrior, "Defend", Enums.CardEffectType.SHIELD, 5, 1)
	_add_basic_cards(mage, "Fireball", Enums.CardEffectType.DAMAGE, 8, 1)
	_add_basic_cards(mage, "Heal", Enums.CardEffectType.HEAL, 6, 1)

	# Initialize grid
	GridManager.initialize_grid(10, 8)
	GridManager.place_character(warrior, Vector2i(1, 3))
	GridManager.place_character(mage, Vector2i(1, 5))
	GridManager.place_character(enemy_a, Vector2i(8, 4))

	# Initialize decks
	var players: Array[CharacterData] = [warrior, mage]
	var enemies: Array[CharacterData] = [enemy_a]
	DeckManager.initialize_all_decks(players + enemies)

	# Start battle
	BattleManager.start_battle(players, enemies)


func _add_basic_cards(character: CharacterData, card_name: String, effect_type: Enums.CardEffectType, value: int, cost: int) -> void:
	for i: int in 4:
		var card := CardData.new()
		card.id = "%s_%s_%d" % [character.id, card_name.to_lower(), i]
		card.card_name = card_name
		card.energy_cost = cost
		card.range_max = 3 if effect_type == Enums.CardEffectType.DAMAGE else 0
		card.target_type = Enums.TargetType.SINGLE_ENEMY if effect_type == Enums.CardEffectType.DAMAGE else Enums.TargetType.SELF
		var eff := CardEffect.new()
		eff.effect_type = effect_type
		eff.value = value
		card.effects.append(eff)
		card.description = "%s: %d" % [card_name, value]
		character.starting_deck.append(card)


func _on_end_turn_pressed() -> void:
	BattleManager.end_turn()


func _on_turn_started(character: CharacterData) -> void:
	turn_label.text = "%s's Turn | HP: %d/%d | Energy: %d" % [
		character.character_name,
		character.current_hp,
		character.max_hp,
		BattleManager.current_energy,
	]


func _on_battle_ended(result: String) -> void:
	turn_label.text = "Battle %s!" % result.to_upper()


func _on_timeline_updated() -> void:
	var preview: Array[CharacterData] = BattleManager.get_timeline_preview(8)
	var lines: PackedStringArray = ["Timeline:"]
	for i: int in preview.size():
		var ch: CharacterData = preview[i]
		var marker: String = " >> " if i == 0 else "    "
		lines.append("%s%s (SPD:%d)" % [marker, ch.character_name, ch.get_effective_speed()])
	timeline_label.text = "\n".join(lines)
