## Title screen with New Game, Continue, Settings, and Difficulty selection.
class_name TitleScreen
extends Control

@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var settings_button: Button = %SettingsButton
@onready var title_label: Label = %TitleLabel

var _difficulty_label: Label
var _difficulty_slider: HSlider


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game)
	continue_button.pressed.connect(_on_continue)
	settings_button.pressed.connect(_on_settings)

	# Disable continue if no save exists
	continue_button.disabled = true

	# Build difficulty selector UI dynamically
	_build_difficulty_ui()


func _build_difficulty_ui() -> void:
	# Find the parent container of the buttons to add difficulty selector
	var parent: Node = new_game_button.get_parent()
	if parent == null:
		return

	var separator := HSeparator.new()
	parent.add_child(separator)

	_difficulty_label = Label.new()
	_difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_difficulty_label.add_theme_font_size_override("font_size", 16)
	_update_difficulty_label()
	parent.add_child(_difficulty_label)

	_difficulty_slider = HSlider.new()
	_difficulty_slider.min_value = 0
	_difficulty_slider.max_value = GameManager.max_unlocked_difficulty
	_difficulty_slider.step = 1
	_difficulty_slider.value = GameManager.difficulty
	_difficulty_slider.custom_minimum_size = Vector2(200, 20)
	_difficulty_slider.value_changed.connect(_on_difficulty_changed)
	parent.add_child(_difficulty_slider)

	# If no difficulty unlocked yet, hide slider
	if GameManager.max_unlocked_difficulty <= 0:
		_difficulty_slider.visible = false
		_difficulty_label.text = "Difficulty: Normal"


func _update_difficulty_label() -> void:
	if GameManager.difficulty == 0:
		_difficulty_label.text = "Difficulty: Normal"
	else:
		_difficulty_label.text = "Ascension Level: %d" % GameManager.difficulty


func _on_difficulty_changed(value: float) -> void:
	GameManager.difficulty = int(value)
	_update_difficulty_label()


func _on_new_game() -> void:
	GameManager.start_new_run()


func _on_continue() -> void:
	# TODO: Load saved game
	pass


func _on_settings() -> void:
	# TODO: Open settings menu
	pass
