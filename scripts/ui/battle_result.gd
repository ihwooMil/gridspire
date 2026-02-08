## Shown after a battle ends. Displays victory or defeat and a continue button.
class_name BattleResultScreen
extends Control

@onready var result_label: Label = %ResultLabel
@onready var detail_label: Label = %DetailLabel
@onready var continue_button: Button = %ContinueButton

var _result: String = ""


func _ready() -> void:
	continue_button.pressed.connect(_on_continue)
	BattleManager.battle_ended.connect(_on_battle_ended)
	visible = false


func _on_battle_ended(result: String) -> void:
	_result = result
	visible = true

	if result == "win":
		result_label.text = "VICTORY"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		detail_label.text = "All enemies defeated!"
		continue_button.text = "Continue"
	else:
		result_label.text = "DEFEAT"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		detail_label.text = "Your party has fallen..."
		continue_button.text = "Return to Menu"


func _on_continue() -> void:
	visible = false
	if _result == "win":
		GameManager.change_state(Enums.GameState.MAP)
	else:
		GameManager.change_state(Enums.GameState.MAIN_MENU)
