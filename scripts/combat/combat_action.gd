## CombatAction — Represents a queued combat action and manages action resolution.
## Actions are queued during a turn and resolved in order.
## Supports cards, movement, and end-turn actions.
class_name CombatAction
extends RefCounted

enum ActionType {
	PLAY_CARD,
	MOVE,
	END_TURN,
}

var action_type: ActionType = ActionType.PLAY_CARD
var source: CharacterData = null
var target: Variant = null  ## CharacterData, Vector2i, or null
var card: CardData = null  ## Only for PLAY_CARD actions


static func create_card_action(p_card: CardData, p_source: CharacterData, p_target: Variant) -> CombatAction:
	var action := CombatAction.new()
	action.action_type = ActionType.PLAY_CARD
	action.card = p_card
	action.source = p_source
	action.target = p_target
	return action


static func create_move_action(p_source: CharacterData, p_target: Vector2i) -> CombatAction:
	var action := CombatAction.new()
	action.action_type = ActionType.MOVE
	action.source = p_source
	action.target = p_target
	return action


static func create_end_turn_action(p_source: CharacterData) -> CombatAction:
	var action := CombatAction.new()
	action.action_type = ActionType.END_TURN
	action.source = p_source
	return action


func get_description() -> String:
	match action_type:
		ActionType.PLAY_CARD:
			var card_name: String = card.card_name if card else "?"
			return "%s plays %s" % [source.character_name, card_name]
		ActionType.MOVE:
			return "%s moves to %s" % [source.character_name, str(target)]
		ActionType.END_TURN:
			return "%s ends turn" % source.character_name
		_:
			return "Unknown action"


## ActionQueue — Manages a queue of CombatActions for ordered resolution.
class ActionQueue extends RefCounted:
	var queue: Array[CombatAction] = []

	func enqueue(action: CombatAction) -> void:
		queue.append(action)

	func dequeue() -> CombatAction:
		if queue.is_empty():
			return null
		return queue.pop_front()

	func peek() -> CombatAction:
		if queue.is_empty():
			return null
		return queue[0]

	func is_empty() -> bool:
		return queue.is_empty()

	func clear() -> void:
		queue.clear()

	func size() -> int:
		return queue.size()
