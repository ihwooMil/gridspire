## Shown after a battle ends in defeat. Victory is handled by the reward screen.
class_name BattleResultScreen
extends Control

@onready var result_label: Label = %ResultLabel
@onready var detail_label: Label = %DetailLabel
@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	continue_button.pressed.connect(_on_continue)
	BattleManager.battle_ended.connect(_on_battle_ended)
	visible = false


func _on_battle_ended(result: String) -> void:
	if result == "win":
		# Victory handled by reward screen via SceneManager
		return

	# Show defeat overlay
	visible = true
	result_label.text = "DEFEAT"
	result_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	detail_label.text = "Your party has fallen..."
	continue_button.text = "Return to Menu"


func _on_continue() -> void:
	visible = false
	GameManager.change_state(Enums.GameState.MAIN_MENU)
