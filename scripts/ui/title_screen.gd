## Title screen with New Game, Continue, and Settings buttons.
class_name TitleScreen
extends Control

@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var settings_button: Button = %SettingsButton
@onready var title_label: Label = %TitleLabel


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game)
	continue_button.pressed.connect(_on_continue)
	settings_button.pressed.connect(_on_settings)

	# Disable continue if no save exists
	continue_button.disabled = true


func _on_new_game() -> void:
	GameManager.start_new_run()


func _on_continue() -> void:
	# TODO: Load saved game
	pass


func _on_settings() -> void:
	# TODO: Open settings menu
	pass
