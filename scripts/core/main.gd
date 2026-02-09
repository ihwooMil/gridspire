## Main scene script — thin shell that manages persistent UI.
## Scene transitions are handled by SceneManager autoload.
extends Node2D

@onready var gold_display: Label = $PersistentUI/GoldDisplay


func _ready() -> void:
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.game_state_changed.connect(_on_state_changed)

	# Start at main menu
	GameManager.change_state(Enums.GameState.MAIN_MENU)


func _on_gold_changed(amount: int) -> void:
	if gold_display:
		gold_display.text = "Gold: %d" % amount
		gold_display.visible = GameManager.current_state != Enums.GameState.MAIN_MENU


func _on_state_changed(new_state: Enums.GameState) -> void:
	if gold_display:
		# Show gold display on map, battle, reward, shop — hide on menu/game over
		gold_display.visible = new_state in [
			Enums.GameState.MAP,
			Enums.GameState.BATTLE,
			Enums.GameState.REWARD,
			Enums.GameState.SHOP,
		]
