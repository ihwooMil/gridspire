## BattleManager — Autoload singleton that drives battle flow.
## Coordinates the timeline, turn phases, card playing, and win/loss checks.
## Uses TimelineSystem for turn order, CardEffectResolver for effects,
## and CombatAction for action queuing.
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
signal energy_changed(current: int, max_energy: int)
signal hand_updated(hand: Array[CardData])
signal action_resolved(action: CombatAction)
signal summon_added(summon: CharacterData, owner: CharacterData)

var state: BattleState = null
var current_energy: int = 0
var max_energy: int = 0
var hand: Array[CardData] = []
var has_moved_this_turn: bool = false

var _timeline: TimelineSystem = null
var _effect_resolver: CardEffectResolver = null
var _action_queue: CombatAction.ActionQueue = null


func _ready() -> void:
	_timeline = TimelineSystem.new()
	_effect_resolver = CardEffectResolver.new()
	_action_queue = CombatAction.ActionQueue.new()

	_effect_resolver.damage_dealt.connect(_on_damage_dealt)
	_effect_resolver.healing_done.connect(_on_healing_done)
	_effect_resolver.character_killed.connect(_on_character_killed)
	_effect_resolver.cards_drawn_by_effect.connect(_on_cards_drawn_by_effect)
	_effect_resolver.summon_created.connect(_on_summon_created)


# --- Battle lifecycle ---

## Start a new battle with given player characters and enemies.
func start_battle(players: Array[CharacterData], enemies: Array[CharacterData]) -> void:
	state = BattleState.new()
	state.player_characters = players
	state.enemy_characters = enemies
	state.battle_active = true

	# Initialize timeline
	var all_chars: Array[CharacterData] = []
	all_chars.append_array(players)
	all_chars.append_array(enemies)
	_timeline.initialize(all_chars)

	# Sync BattleState timeline from TimelineSystem
	state.timeline = _timeline.entries

	# Initialize decks for all characters
	DeckManager.initialize_all_decks(all_chars)

	# Initialize runtime combat state for players
	for ch: CharacterData in players:
		ch.element_stacks.clear()
		ch.cards_played_this_turn.clear()
		ch.active_summons.clear()

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

	var character: CharacterData = _timeline.advance()
	if character == null:
		return

	# Sync BattleState
	state.current_entry = _timeline.current_entry

	state.turn_phase = Enums.TurnPhase.DRAW
	timeline_updated.emit()
	turn_started.emit(character)

	# Check for stun — skip the turn entirely
	if character.get_status_stacks(Enums.StatusEffect.STUN) > 0:
		character.modify_status(Enums.StatusEffect.STUN, -1)
		_finish_turn(character)
		return

	# Apply start-of-turn status effects (poison, regen)
	_apply_start_of_turn_effects(character)

	if not character.is_alive():
		character_died.emit(character)
		_finish_turn(character)
		return

	# Apply hazard damage if standing on a hazard tile
	_apply_hazard_damage(character)

	if not character.is_alive():
		character_died.emit(character)
		_finish_turn(character)
		return

	if character.is_summon:
		_start_summon_turn(character)
	elif character.faction == Enums.Faction.PLAYER:
		_start_player_turn(character)
	else:
		_start_enemy_turn(character)


func _start_player_turn(character: CharacterData) -> void:
	max_energy = character.get_total_energy()
	current_energy = max_energy
	has_moved_this_turn = false
	character.cards_played_this_turn.clear()
	character.tick_status_effects()

	# Draw cards
	state.turn_phase = Enums.TurnPhase.DRAW
	turn_phase_changed.emit(Enums.TurnPhase.DRAW)
	hand = DeckManager.draw_cards(character, 5)

	state.turn_phase = Enums.TurnPhase.ACTION
	turn_phase_changed.emit(Enums.TurnPhase.ACTION)
	energy_changed.emit(current_energy, max_energy)
	hand_updated.emit(hand)
	# Now we wait for player input via play_card(), move_character(), or end_turn()


func _start_enemy_turn(character: CharacterData) -> void:
	character.tick_status_effects()

	# Simple enemy AI: draw cards, then try to play them
	var enemy_hand: Array[CardData] = DeckManager.draw_cards(character, 3)
	var energy: int = character.energy_per_turn

	# Try to move toward nearest player if not adjacent
	_enemy_try_move(character)

	# Try to play each card
	for card: CardData in enemy_hand:
		if energy < card.energy_cost:
			continue
		var target: Variant = _find_ai_target(card, character)
		if target != null:
			energy -= card.energy_cost
			_effect_resolver.resolve_card(card, character, target)
			card_played.emit(card, character, target)

			var battle_result: String = state.check_battle_result()
			if battle_result != "ongoing":
				DeckManager.discard_hand(character, enemy_hand)
				_end_battle(battle_result)
				return

	DeckManager.discard_hand(character, enemy_hand)
	_finish_turn(character)


# --- Player actions ---

## Called by UI when the player plays a card.
func play_card(card: CardData, source: CharacterData, target: Variant) -> bool:
	if state == null or not state.battle_active:
		return false
	if state.turn_phase != Enums.TurnPhase.ACTION:
		return false
	if current_energy < card.energy_cost:
		return false
	if not card in hand:
		return false

	# Validate range
	if not _is_target_in_range(card, source, target):
		return false

	# Check requires_berserk
	if card.requires_berserk and source.get_status_stacks(Enums.StatusEffect.BERSERK) <= 0:
		return false

	# Check element_cost
	if card.element_cost > 0 and card.element != "":
		var stacks: int = source.element_stacks.get(card.element, 0)
		if stacks < card.element_cost:
			return false

	current_energy -= card.energy_cost
	hand.erase(card)

	var action: CombatAction = CombatAction.create_card_action(card, source, target)
	_resolve_action(action)

	# Exhaust or discard
	if card.exhaust_on_play:
		DeckManager.exhaust_card(source, card)
	else:
		DeckManager.discard_card(source, card)
	card_played.emit(card, source, target)
	energy_changed.emit(current_energy, max_energy)
	hand_updated.emit(hand)

	# Recalculate timeline in case speed buffs/debuffs were applied
	_timeline.recalculate()
	timeline_updated.emit()

	var result: String = state.check_battle_result()
	if result != "ongoing":
		_end_battle(result)

	return true


## Called by UI when the player moves their character.
func move_character(character: CharacterData, target_pos: Vector2i) -> bool:
	if state == null or not state.battle_active:
		return false
	if state.turn_phase != Enums.TurnPhase.ACTION:
		return false
	if has_moved_this_turn:
		return false
	if character.get_status_stacks(Enums.StatusEffect.ROOT) > 0:
		return false

	var success: bool = GridManager.move_character(character, target_pos)
	if success:
		has_moved_this_turn = true
		var action: CombatAction = CombatAction.create_move_action(character, target_pos)
		action_resolved.emit(action)
	return success


## Called by UI or AI to end the current turn.
func end_turn() -> void:
	if state == null or not state.battle_active:
		return

	var character: CharacterData = _timeline.get_active_character()
	if character == null:
		return

	state.turn_phase = Enums.TurnPhase.DISCARD
	turn_phase_changed.emit(Enums.TurnPhase.DISCARD)

	# Discard remaining hand
	if character.faction == Enums.Faction.PLAYER:
		DeckManager.discard_hand(character, hand)
		hand.clear()
		hand_updated.emit(hand)

	_finish_turn(character)


## Get a preview of the next N turns on the timeline.
func get_timeline_preview(count: int = 10) -> Array[CharacterData]:
	if _timeline:
		return _timeline.get_preview(count)
	return []


## Get the raw timeline entries (for the timeline bar UI).
func get_timeline_entries() -> Array[TimelineEntry]:
	if _timeline:
		return _timeline.entries
	return []


## Get the currently active character.
func get_active_character() -> CharacterData:
	if _timeline:
		return _timeline.get_active_character()
	return null


## Check if a card can be played (enough energy, valid target, in range).
func can_play_card(card: CardData, source: CharacterData, target: Variant) -> bool:
	if state == null or not state.battle_active:
		return false
	if state.turn_phase != Enums.TurnPhase.ACTION:
		return false
	if current_energy < card.energy_cost:
		return false
	if not card in hand:
		return false
	if card.requires_berserk and source.get_status_stacks(Enums.StatusEffect.BERSERK) <= 0:
		return false
	if card.element_cost > 0 and card.element != "":
		var stacks: int = source.element_stacks.get(card.element, 0)
		if stacks < card.element_cost:
			return false
	return _is_target_in_range(card, source, target)


## Get valid targets for a card from the current character's position.
func get_valid_targets(card: CardData, source: CharacterData) -> Array:
	var targets: Array = []
	match card.target_type:
		Enums.TargetType.SELF:
			targets.append(source)
		Enums.TargetType.SINGLE_ALLY:
			for ch: CharacterData in state.player_characters:
				if ch.is_alive() and _in_card_range(card, source, ch.grid_position):
					targets.append(ch)
		Enums.TargetType.SINGLE_ENEMY:
			for ch: CharacterData in state.enemy_characters:
				if ch.is_alive() and _in_card_range(card, source, ch.grid_position):
					targets.append(ch)
		Enums.TargetType.ALL_ALLIES:
			targets.append(source)  # No specific target needed
		Enums.TargetType.ALL_ENEMIES:
			targets.append(source)  # No specific target needed
		Enums.TargetType.TILE, Enums.TargetType.AREA:
			var tiles: Array[Vector2i] = GridManager.get_tiles_in_range(
				source.grid_position, card.range_min, card.range_max
			)
			targets.append_array(tiles)
		Enums.TargetType.NONE:
			targets.append(source)
	return targets


# --- Internal helpers ---

func _resolve_action(action: CombatAction) -> void:
	match action.action_type:
		CombatAction.ActionType.PLAY_CARD:
			_effect_resolver.resolve_card(action.card, action.source, action.target)
		CombatAction.ActionType.MOVE:
			if action.target is Vector2i:
				GridManager.move_character(action.source, action.target)
	action_resolved.emit(action)


func _finish_turn(character: CharacterData) -> void:
	state.turn_phase = Enums.TurnPhase.END
	turn_phase_changed.emit(Enums.TurnPhase.END)

	_timeline.end_current_turn()
	state.current_entry = null
	state.turn_number += 1

	turn_ended.emit(character)
	timeline_updated.emit()
	_next_turn()


func _is_target_in_range(card: CardData, source: CharacterData, target: Variant) -> bool:
	match card.target_type:
		Enums.TargetType.SELF, Enums.TargetType.NONE:
			return true
		Enums.TargetType.ALL_ALLIES, Enums.TargetType.ALL_ENEMIES:
			return true
		Enums.TargetType.SINGLE_ALLY, Enums.TargetType.SINGLE_ENEMY:
			if target is CharacterData:
				return _in_card_range(card, source, target.grid_position)
		Enums.TargetType.TILE, Enums.TargetType.AREA:
			if target is Vector2i:
				return _in_card_range(card, source, target)
	return false


func _in_card_range(card: CardData, source: CharacterData, target_pos: Vector2i) -> bool:
	var dist: int = GridManager.manhattan_distance(source.grid_position, target_pos)
	return dist >= card.range_min and dist <= card.range_max


func _apply_start_of_turn_effects(character: CharacterData) -> void:
	# Poison: deal damage equal to stacks
	var poison: int = character.get_status_stacks(Enums.StatusEffect.POISON)
	if poison > 0:
		var actual: int = character.take_damage(poison)
		character_damaged.emit(character, actual)

	# Regen: heal equal to stacks
	var regen: int = character.get_status_stacks(Enums.StatusEffect.REGEN)
	if regen > 0:
		var actual_regen: int = character.heal(regen)
		character_healed.emit(character, actual_regen)


func _apply_hazard_damage(character: CharacterData) -> void:
	var tile: GridTile = GridManager.get_tile(character.grid_position)
	if tile and tile.tile_type == Enums.TileType.HAZARD:
		var hazard_damage: int = 5
		var actual: int = character.take_damage(hazard_damage)
		character_damaged.emit(character, actual)


# --- Enemy AI ---

func _enemy_try_move(character: CharacterData) -> void:
	if character.get_status_stacks(Enums.StatusEffect.ROOT) > 0:
		return

	# Find nearest player character
	var nearest: CharacterData = null
	var nearest_dist: int = 999
	for player: CharacterData in state.player_characters:
		if not player.is_alive():
			continue
		var dist: int = GridManager.manhattan_distance(character.grid_position, player.grid_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = player

	if nearest == null or nearest_dist <= 1:
		return

	# Get reachable tiles and find one closest to the nearest player
	var reachable: Array[Vector2i] = GridManager.get_reachable_tiles(character)
	var best_pos: Vector2i = character.grid_position
	var best_dist: int = nearest_dist
	for pos: Vector2i in reachable:
		var dist: int = GridManager.manhattan_distance(pos, nearest.grid_position)
		if dist < best_dist:
			best_dist = dist
			best_pos = pos

	if best_pos != character.grid_position:
		GridManager.move_character(character, best_pos)


func _find_ai_target(card: CardData, source: CharacterData) -> Variant:
	match card.target_type:
		Enums.TargetType.SELF, Enums.TargetType.NONE:
			return source

		Enums.TargetType.SINGLE_ENEMY:
			# Enemies target players
			for player: CharacterData in state.player_characters:
				if player.is_alive() and _in_card_range(card, source, player.grid_position):
					return player
			return null

		Enums.TargetType.SINGLE_ALLY:
			# Heal/buff the lowest-HP ally
			var best: CharacterData = null
			var lowest_hp: int = 999
			for ally: CharacterData in state.enemy_characters:
				if ally.is_alive() and ally.current_hp < lowest_hp:
					if _in_card_range(card, source, ally.grid_position):
						lowest_hp = ally.current_hp
						best = ally
			return best

		Enums.TargetType.ALL_ALLIES, Enums.TargetType.ALL_ENEMIES:
			return source

		Enums.TargetType.TILE, Enums.TargetType.AREA:
			# Target a tile near the most players
			var best_tile: Vector2i = source.grid_position
			var best_count: int = 0
			var tiles: Array[Vector2i] = GridManager.get_tiles_in_range(
				source.grid_position, card.range_min, card.range_max
			)
			for tile_pos: Vector2i in tiles:
				var count: int = 0
				for player: CharacterData in state.player_characters:
					if player.is_alive():
						var dist: int = GridManager.manhattan_distance(tile_pos, player.grid_position)
						var radius: int = 1
						if card.effects.size() > 0:
							radius = card.effects[0].area_radius
						if dist <= radius:
							count += 1
				if count > best_count:
					best_count = count
					best_tile = tile_pos
			if best_count > 0:
				return best_tile
			return null

	return null


# --- Summon turn ---

func _start_summon_turn(character: CharacterData) -> void:
	character.tick_status_effects()

	# Summon AI: similar to enemy AI but targets enemies (ally of owner)
	var summon_hand: Array[CardData] = DeckManager.draw_cards(character, 3)
	var energy: int = character.energy_per_turn

	# Move toward nearest enemy
	_summon_try_move(character)

	for card: CardData in summon_hand:
		if energy < card.energy_cost:
			continue
		var target: Variant = _find_summon_target(card, character)
		if target != null:
			energy -= card.energy_cost
			_effect_resolver.resolve_card(card, character, target)
			card_played.emit(card, character, target)

			var battle_result: String = state.check_battle_result()
			if battle_result != "ongoing":
				DeckManager.discard_hand(character, summon_hand)
				_end_battle(battle_result)
				return

	DeckManager.discard_hand(character, summon_hand)
	_finish_turn(character)


func _summon_try_move(character: CharacterData) -> void:
	if character.get_status_stacks(Enums.StatusEffect.ROOT) > 0:
		return
	var nearest: CharacterData = null
	var nearest_dist: int = 999
	for enemy: CharacterData in state.enemy_characters:
		if not enemy.is_alive():
			continue
		var dist: int = GridManager.manhattan_distance(character.grid_position, enemy.grid_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	if nearest == null or nearest_dist <= 1:
		return
	var reachable: Array[Vector2i] = GridManager.get_reachable_tiles(character)
	var best_pos: Vector2i = character.grid_position
	var best_dist: int = nearest_dist
	for pos: Vector2i in reachable:
		var dist: int = GridManager.manhattan_distance(pos, nearest.grid_position)
		if dist < best_dist:
			best_dist = dist
			best_pos = pos
	if best_pos != character.grid_position:
		GridManager.move_character(character, best_pos)


func _find_summon_target(card: CardData, source: CharacterData) -> Variant:
	match card.target_type:
		Enums.TargetType.SELF, Enums.TargetType.NONE:
			return source
		Enums.TargetType.SINGLE_ENEMY:
			# Summons target enemies (faction ENEMY)
			for enemy: CharacterData in state.enemy_characters:
				if enemy.is_alive() and _in_card_range(card, source, enemy.grid_position):
					return enemy
			return null
		Enums.TargetType.SINGLE_ALLY:
			# Heal/buff owner's allies (players)
			var best: CharacterData = null
			var lowest_hp: int = 999
			for ally: CharacterData in state.player_characters:
				if ally.is_alive() and ally.current_hp < lowest_hp:
					if _in_card_range(card, source, ally.grid_position):
						lowest_hp = ally.current_hp
						best = ally
			return best
		Enums.TargetType.ALL_ALLIES, Enums.TargetType.ALL_ENEMIES:
			return source
		Enums.TargetType.TILE, Enums.TargetType.AREA:
			# Target tile near most enemies
			var best_tile: Vector2i = source.grid_position
			var best_count: int = 0
			var tiles: Array[Vector2i] = GridManager.get_tiles_in_range(
				source.grid_position, card.range_min, card.range_max
			)
			for tile_pos: Vector2i in tiles:
				var count: int = 0
				for enemy: CharacterData in state.enemy_characters:
					if enemy.is_alive():
						var dist: int = GridManager.manhattan_distance(tile_pos, enemy.grid_position)
						var radius: int = 1
						if card.effects.size() > 0:
							radius = card.effects[0].area_radius
						if dist <= radius:
							count += 1
				if count > best_count:
					best_count = count
					best_tile = tile_pos
			if best_count > 0:
				return best_tile
			return null
	return null


func _on_summon_created(summon: CharacterData, owner: CharacterData) -> void:
	# Add summon to player characters list for battle state
	state.player_characters.append(summon)
	# Add to timeline
	_timeline.add_entry(summon)
	state.timeline = _timeline.entries
	# Initialize deck
	DeckManager.initialize_deck(summon)
	timeline_updated.emit()
	summon_added.emit(summon, owner)


# --- Signal callbacks from CardEffectResolver ---

func _on_damage_dealt(character: CharacterData, amount: int) -> void:
	character_damaged.emit(character, amount)


func _on_healing_done(character: CharacterData, amount: int) -> void:
	character_healed.emit(character, amount)


func _on_character_killed(character: CharacterData) -> void:
	# If it's a summon, clean up owner's summon list and timeline
	if character.is_summon and character.summon_owner:
		character.summon_owner.active_summons.erase(character)
		_timeline.remove_entry(character)
		state.player_characters.erase(character)
		timeline_updated.emit()
	character_died.emit(character)


func _on_cards_drawn_by_effect(character: CharacterData, cards: Array[CardData]) -> void:
	# If this is the active player character, add to hand
	var active: CharacterData = _timeline.get_active_character()
	if active == character and character.faction == Enums.Faction.PLAYER:
		hand.append_array(cards)
		hand_updated.emit(hand)


func _end_battle(result: String) -> void:
	state.battle_active = false
	battle_ended.emit(result)
	# Scene transitions are handled by:
	# - Win: SceneManager transitions to REWARD screen
	# - Lose: BattleResultScreen shows defeat overlay, player clicks to go to menu
	if result == "win":
		GameManager.change_state(Enums.GameState.REWARD)
