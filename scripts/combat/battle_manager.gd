## BattleManager — Autoload singleton that drives battle flow.
## Coordinates the timeline, turn phases, card playing, and win/loss checks.
extends Node

signal battle_started()
signal battle_ended(result: String)
signal turn_started(character: CharacterData)
signal turn_ended(character: CharacterData)
signal turn_phase_changed(phase: Enums.TurnPhase)
signal card_played(card: CardData, source: CharacterData, target: Variant)
signal character_damaged(character: CharacterData, amount: int)
signal character_healed(character: CharacterData, amount: int)
signal character_died(character: CharacterData)
signal timeline_updated()

var state: BattleState = null
var current_energy: int = 0
var hand: Array[CardData] = []


## Start a new battle with given player characters and enemies.
func start_battle(players: Array[CharacterData], enemies: Array[CharacterData]) -> void:
	state = BattleState.new()
	state.player_characters = players
	state.enemy_characters = enemies
	state.battle_active = true
	state.build_timeline()

	GameManager.change_state(Enums.GameState.BATTLE)
	battle_started.emit()
	_next_turn()


## Advance to the next turn on the timeline.
func _next_turn() -> void:
	if not state.battle_active:
		return

	var result: String = state.check_battle_result()
	if result != "ongoing":
		_end_battle(result)
		return

	var character: CharacterData = state.advance_timeline()
	if character == null:
		return

	state.turn_phase = Enums.TurnPhase.DRAW
	timeline_updated.emit()
	turn_started.emit(character)

	if character.faction == Enums.Faction.PLAYER:
		_start_player_turn(character)
	else:
		_start_enemy_turn(character)


func _start_player_turn(character: CharacterData) -> void:
	current_energy = character.energy_per_turn
	character.tick_status_effects()

	# Draw cards
	state.turn_phase = Enums.TurnPhase.DRAW
	turn_phase_changed.emit(Enums.TurnPhase.DRAW)
	hand = DeckManager.draw_cards(character, 5)

	state.turn_phase = Enums.TurnPhase.ACTION
	turn_phase_changed.emit(Enums.TurnPhase.ACTION)
	# Now we wait for player input via play_card() or end_turn()


func _start_enemy_turn(character: CharacterData) -> void:
	character.tick_status_effects()
	# TODO: AI decision-making will be implemented in Task #3
	end_turn()


## Called by UI when the player plays a card.
func play_card(card: CardData, source: CharacterData, target: Variant) -> bool:
	if state.turn_phase != Enums.TurnPhase.ACTION:
		return false
	if current_energy < card.energy_cost:
		return false

	current_energy -= card.energy_cost
	hand.erase(card)
	_resolve_card(card, source, target)
	card_played.emit(card, source, target)

	var result: String = state.check_battle_result()
	if result != "ongoing":
		_end_battle(result)

	return true


## Resolve all effects on a card.
func _resolve_card(card: CardData, source: CharacterData, target: Variant) -> void:
	for effect: CardEffect in card.effects:
		_apply_effect(effect, source, target)


## Apply a single card effect.
func _apply_effect(effect: CardEffect, source: CharacterData, target: Variant) -> void:
	match effect.effect_type:
		Enums.CardEffectType.DAMAGE:
			if target is CharacterData:
				var dmg: int = effect.value + source.get_status_stacks(Enums.StatusEffect.STRENGTH)
				var actual: int = target.take_damage(dmg)
				character_damaged.emit(target, actual)
				if not target.is_alive():
					character_died.emit(target)

		Enums.CardEffectType.HEAL:
			if target is CharacterData:
				target.heal(effect.value)
				character_healed.emit(target, effect.value)

		Enums.CardEffectType.MOVE:
			if target is CharacterData:
				# Movement is handled by GridManager; this signals the intent
				pass

		Enums.CardEffectType.SHIELD:
			if target is CharacterData:
				target.modify_status(Enums.StatusEffect.SHIELD, effect.value, 1)

		Enums.CardEffectType.BUFF:
			if target is CharacterData:
				target.modify_status(effect.status_effect, effect.value, effect.duration)

		Enums.CardEffectType.DEBUFF:
			if target is CharacterData:
				target.modify_status(effect.status_effect, effect.value, effect.duration)

		Enums.CardEffectType.PUSH:
			if target is CharacterData:
				GridManager.push_character(source, target, effect.push_pull_distance)

		Enums.CardEffectType.PULL:
			if target is CharacterData:
				GridManager.pull_character(source, target, effect.push_pull_distance)

		Enums.CardEffectType.DRAW:
			var active: CharacterData = state.get_active_character()
			if active:
				var drawn: Array[CardData] = DeckManager.draw_cards(active, effect.value)
				hand.append_array(drawn)

		Enums.CardEffectType.AREA_DAMAGE:
			if target is Vector2i:
				var targets: Array[CharacterData] = GridManager.get_characters_in_radius(target, effect.area_radius)
				for t: CharacterData in targets:
					var dmg: int = effect.value + source.get_status_stacks(Enums.StatusEffect.STRENGTH)
					var actual: int = t.take_damage(dmg)
					character_damaged.emit(t, actual)
					if not t.is_alive():
						character_died.emit(t)

		Enums.CardEffectType.AREA_BUFF:
			if target is Vector2i:
				var targets: Array[CharacterData] = GridManager.get_characters_in_radius(target, effect.area_radius)
				for t: CharacterData in targets:
					if t.faction == source.faction:
						t.modify_status(effect.status_effect, effect.value, effect.duration)

		Enums.CardEffectType.AREA_DEBUFF:
			if target is Vector2i:
				var targets: Array[CharacterData] = GridManager.get_characters_in_radius(target, effect.area_radius)
				for t: CharacterData in targets:
					if t.faction != source.faction:
						t.modify_status(effect.status_effect, effect.value, effect.duration)


## Called by UI or AI to end the current turn.
func end_turn() -> void:
	if state == null or not state.battle_active:
		return

	var character: CharacterData = state.get_active_character()
	state.turn_phase = Enums.TurnPhase.DISCARD
	turn_phase_changed.emit(Enums.TurnPhase.DISCARD)

	# Discard remaining hand
	if character and character.faction == Enums.Faction.PLAYER:
		DeckManager.discard_hand(character, hand)
		hand.clear()

	state.turn_phase = Enums.TurnPhase.END
	turn_phase_changed.emit(Enums.TurnPhase.END)
	state.end_current_turn()
	turn_ended.emit(character)
	timeline_updated.emit()
	_next_turn()


func _end_battle(result: String) -> void:
	state.battle_active = false
	battle_ended.emit(result)
	if result == "win":
		GameManager.change_state(Enums.GameState.REWARD)
	else:
		GameManager.change_state(Enums.GameState.GAME_OVER)


func get_timeline_preview(count: int = 10) -> Array[CharacterData]:
	if state:
		return state.get_timeline_preview(count)
	return []
