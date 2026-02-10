## Displays character info: name, HP bar, energy, draw/discard counts, and active status effects.
class_name CharacterInfoPanel
extends PanelContainer

@onready var name_label: Label = %CharNameLabel
@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_label: Label = %HPLabel
@onready var energy_label: Label = %EnergyLabel
@onready var draw_count_label: Label = %DrawCountLabel
@onready var discard_count_label: Label = %DiscardCountLabel
@onready var status_container: HBoxContainer = %StatusContainer

var tracked_character: CharacterData = null

const STATUS_COLORS: Dictionary = {
	Enums.StatusEffect.STRENGTH: Color(1.0, 0.3, 0.3),
	Enums.StatusEffect.WEAKNESS: Color(0.7, 0.4, 0.1),
	Enums.StatusEffect.HASTE: Color(0.3, 1.0, 0.3),
	Enums.StatusEffect.SLOW: Color(0.5, 0.5, 0.8),
	Enums.StatusEffect.SHIELD: Color(0.4, 0.7, 1.0),
	Enums.StatusEffect.POISON: Color(0.2, 0.8, 0.2),
	Enums.StatusEffect.REGEN: Color(0.3, 1.0, 0.7),
	Enums.StatusEffect.STUN: Color(1.0, 1.0, 0.2),
	Enums.StatusEffect.ROOT: Color(0.6, 0.4, 0.2),
	Enums.StatusEffect.BERSERK: Color(1.0, 0.2, 0.2),
	Enums.StatusEffect.EVASION: Color(0.8, 0.8, 1.0),
	Enums.StatusEffect.UNHEALABLE: Color(0.5, 0.0, 0.5),
}

const STATUS_NAMES: Dictionary = {
	Enums.StatusEffect.STRENGTH: "STR",
	Enums.StatusEffect.WEAKNESS: "WEAK",
	Enums.StatusEffect.HASTE: "HASTE",
	Enums.StatusEffect.SLOW: "SLOW",
	Enums.StatusEffect.SHIELD: "SHLD",
	Enums.StatusEffect.POISON: "PSN",
	Enums.StatusEffect.REGEN: "REGEN",
	Enums.StatusEffect.STUN: "STUN",
	Enums.StatusEffect.ROOT: "ROOT",
	Enums.StatusEffect.BERSERK: "BSRK",
	Enums.StatusEffect.EVASION: "EVA",
	Enums.StatusEffect.UNHEALABLE: "CURSE",
}


func _ready() -> void:
	BattleManager.character_damaged.connect(_on_character_changed)
	BattleManager.character_healed.connect(_on_character_changed)
	BattleManager.energy_changed.connect(_on_energy_changed)
	BattleManager.hand_updated.connect(_on_hand_updated)
	BattleManager.card_played.connect(func(_c: CardData, _s: CharacterData, _t: Variant) -> void: refresh())


func _exit_tree() -> void:
	if BattleManager.character_damaged.is_connected(_on_character_changed):
		BattleManager.character_damaged.disconnect(_on_character_changed)
	if BattleManager.character_healed.is_connected(_on_character_changed):
		BattleManager.character_healed.disconnect(_on_character_changed)
	if BattleManager.energy_changed.is_connected(_on_energy_changed):
		BattleManager.energy_changed.disconnect(_on_energy_changed)
	if BattleManager.hand_updated.is_connected(_on_hand_updated):
		BattleManager.hand_updated.disconnect(_on_hand_updated)


func setup(character: CharacterData) -> void:
	tracked_character = character
	refresh()


func refresh() -> void:
	if tracked_character == null:
		return

	if name_label:
		name_label.text = tracked_character.character_name
	if hp_bar:
		hp_bar.max_value = tracked_character.max_hp
		hp_bar.value = tracked_character.current_hp
	if hp_label:
		hp_label.text = "%d / %d" % [tracked_character.current_hp, tracked_character.max_hp]
	if energy_label:
		energy_label.text = "Energy: %d / %d" % [BattleManager.current_energy, BattleManager.max_energy]
	if draw_count_label:
		draw_count_label.text = "Draw: %d" % DeckManager.get_draw_count(tracked_character)
	if discard_count_label:
		discard_count_label.text = "Discard: %d" % DeckManager.get_discard_count(tracked_character)

	_refresh_status_effects()


func _refresh_status_effects() -> void:
	if status_container == null:
		return
	for child: Node in status_container.get_children():
		child.queue_free()

	for effect: Enums.StatusEffect in tracked_character.status_effects.keys():
		var info: Dictionary = tracked_character.status_effects[effect]
		var badge := Label.new()
		var effect_name: String = STATUS_NAMES.get(effect, "???")
		badge.text = "%s %d" % [effect_name, info.stacks]
		badge.add_theme_color_override("font_color", STATUS_COLORS.get(effect, Color.WHITE))
		badge.add_theme_font_size_override("font_size", 12)
		status_container.add_child(badge)


func _on_character_changed(character: CharacterData, _amount: int) -> void:
	if character == tracked_character:
		refresh()


func _on_energy_changed(_current: int, _max_energy: int) -> void:
	refresh()


func _on_hand_updated(_hand: Array[CardData]) -> void:
	refresh()
