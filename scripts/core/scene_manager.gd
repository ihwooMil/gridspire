## SceneManager — Autoload singleton for scene transitions.
## Listens to GameManager.game_state_changed and swaps scenes in SceneContainer.
extends Node

var _scene_map: Dictionary = {}
var _scene_container: Node = null
var _transition_overlay: ColorRect = null
var _current_scene: Node = null
var _transitioning: bool = false

const FADE_DURATION: float = 0.25


func _ready() -> void:
	_scene_map = {
		Enums.GameState.MAIN_MENU: "res://scenes/menu/title_screen.tscn",
		Enums.GameState.CHARACTER_SELECT: "res://scenes/menu/character_select.tscn",
		Enums.GameState.MAP: "res://scenes/map/overworld_map.tscn",
		Enums.GameState.BATTLE: "res://scenes/battle/battle_scene.tscn",
		Enums.GameState.REWARD: "res://scenes/ui/reward_screen.tscn",
		Enums.GameState.SHOP: "res://scenes/ui/shop_screen.tscn",
		Enums.GameState.EVENT: "res://scenes/menu/event_screen.tscn",
		Enums.GameState.GAME_OVER: "res://scenes/menu/title_screen.tscn",
	}
	GameManager.game_state_changed.connect(_on_game_state_changed)


func _on_game_state_changed(new_state: Enums.GameState) -> void:
	if not _scene_map.has(new_state):
		return
	var scene_path: String = _scene_map[new_state]
	_transition_to_scene(scene_path)


func _transition_to_scene(scene_path: String) -> void:
	if _transitioning:
		return
	_ensure_references()
	if _scene_container == null:
		push_warning("SceneManager: SceneContainer not found")
		return

	_transitioning = true

	if _transition_overlay:
		# Fade out
		var tween := create_tween()
		tween.tween_property(_transition_overlay, "color:a", 1.0, FADE_DURATION)
		await tween.finished
		_swap_scene(scene_path)
		# Fade in
		var tween_in := create_tween()
		tween_in.tween_property(_transition_overlay, "color:a", 0.0, FADE_DURATION)
		await tween_in.finished
	else:
		_swap_scene(scene_path)

	_transitioning = false


func _swap_scene(scene_path: String) -> void:
	# Remove current scene
	if _current_scene:
		_current_scene.queue_free()
		_current_scene = null

	# Load and instantiate new scene
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_warning("SceneManager: Failed to load scene: " + scene_path)
		return

	_current_scene = packed.instantiate()

	# If the scene root is a Control under a Node2D container,
	# set its size to fill the viewport
	if _current_scene is Control:
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		_current_scene.size = viewport_size

	_scene_container.add_child(_current_scene)


func _ensure_references() -> void:
	if _scene_container:
		return
	var main: Node = get_tree().current_scene
	if main == null:
		return
	_scene_container = main.get_node_or_null("SceneContainer")
	_transition_overlay = main.get_node_or_null("PersistentUI/TransitionOverlay")
