## CardEffectResolver — Resolves card effects during combat.
## Extracted from BattleManager to keep effect resolution logic modular.
## Handles damage, healing, shields, buffs, debuffs, push/pull, draw, and area effects.
class_name CardEffectResolver
extends RefCounted

## Emitted when a character takes damage. Args: character, actual damage dealt.
signal damage_dealt(character: CharacterData, amount: int)
## Emitted when a character is healed. Args: character, amount healed.
signal healing_done(character: CharacterData, amount: int)
## Emitted when a character dies.
signal character_killed(character: CharacterData)
## Emitted when cards are drawn as a card effect.
signal cards_drawn_by_effect(character: CharacterData, cards: Array[CardData])
## Emitted when a summon is created.
signal summon_created(summon: CharacterData, owner: CharacterData)


## Resolve all effects on a card.
func resolve_card(card: CardData, source: CharacterData, target: Variant) -> void:
	# Element stacking: add element stacks before resolving effects
	if card.element == "all":
		# Add stacks to all element types
		for elem: String in ["fire", "ice", "lightning"]:
			if not source.element_stacks.has(elem):
				source.element_stacks[elem] = 0
			source.element_stacks[elem] += card.element_count
	elif card.element != "":
		if not source.element_stacks.has(card.element):
			source.element_stacks[card.element] = 0
		source.element_stacks[card.element] += card.element_count

	# Resolve each effect with combo/element scaling
	for effect: CardEffect in card.effects:
		apply_effect(effect, source, target)

	# Record card tags for combo system
	source.cards_played_this_turn.append(card)

	# Consume all element stacks if card has consumes_stacks
	if card.consumes_stacks:
		source.element_stacks.clear()


## Apply a single card effect. The target can be CharacterData or Vector2i
## depending on the card's target_type.
func apply_effect(effect: CardEffect, source: CharacterData, target: Variant) -> void:
	# Combo gate: if combo_only, skip effect if combo condition not met
	if effect.combo_only and effect.combo_tag != "":
		if not source.has_tag_played(effect.combo_tag):
			return

	match effect.effect_type:
		Enums.CardEffectType.DAMAGE:
			_apply_damage(effect, source, target)

		Enums.CardEffectType.HEAL:
			_apply_heal(effect, target)

		Enums.CardEffectType.MOVE:
			_apply_move(effect, source, target)

		Enums.CardEffectType.SHIELD:
			_apply_shield(effect, source, target)

		Enums.CardEffectType.BUFF:
			_apply_status(effect, target)

		Enums.CardEffectType.DEBUFF:
			_apply_status(effect, target)

		Enums.CardEffectType.PUSH:
			_apply_push(effect, source, target)

		Enums.CardEffectType.PULL:
			_apply_pull(effect, source, target)

		Enums.CardEffectType.DRAW:
			_apply_draw(effect, source)

		Enums.CardEffectType.AREA_DAMAGE:
			_apply_area_damage(effect, source, target)

		Enums.CardEffectType.AREA_BUFF:
			_apply_area_buff(effect, source, target)

		Enums.CardEffectType.AREA_DEBUFF:
			_apply_area_debuff(effect, source, target)

		Enums.CardEffectType.SHIELD_STRIKE:
			_apply_shield_strike(effect, source, target)

		Enums.CardEffectType.SUMMON:
			_apply_summon(effect, source, target)


## Calculate damage with strength bonus, berserk bonus, and weakness reduction.
func calculate_damage(base_value: int, source: CharacterData) -> int:
	var dmg: int = base_value
	dmg += source.get_status_stacks(Enums.StatusEffect.STRENGTH)
	dmg += source.bonus_strength
	dmg += source.get_status_stacks(Enums.StatusEffect.BERSERK) * 2
	if source.get_status_stacks(Enums.StatusEffect.WEAKNESS) > 0:
		dmg = int(dmg * 0.75)
	return maxi(dmg, 0)


func _apply_damage(effect: CardEffect, source: CharacterData, target: Variant) -> void:
	if target is CharacterData:
		var base: int = effect.roll() + _get_scaling_bonus(effect, source) + _get_combo_bonus(effect, source)
		var dmg: int = calculate_damage(base, source)
		var actual: int = target.take_damage(dmg)
		damage_dealt.emit(target, actual)
		if not target.is_alive():
			character_killed.emit(target)


func _apply_heal(effect: CardEffect, target: Variant) -> void:
	if target is CharacterData:
		var hp_before: int = target.current_hp
		target.heal(effect.roll())
		var actual_heal: int = target.current_hp - hp_before
		healing_done.emit(target, actual_heal)


func _apply_move(effect: CardEffect, source: CharacterData, target: Variant) -> void:
	if target is Vector2i:
		GridManager.move_character(source, target)


func _apply_shield(effect: CardEffect, source: CharacterData, _target: Variant) -> void:
	var shield_amount: int = effect.roll() + _get_scaling_bonus(effect, source) + _get_combo_bonus(effect, source)
	var dur: int = effect.duration if effect.duration > 0 else 1
	source.modify_status(Enums.StatusEffect.SHIELD, shield_amount, dur)


func _apply_status(effect: CardEffect, target: Variant) -> void:
	if target is CharacterData:
		target.modify_status(effect.status_effect, effect.value, effect.duration)


func _apply_push(effect: CardEffect, source: CharacterData, target: Variant) -> void:
	if target is CharacterData:
		GridManager.push_character(source, target, effect.push_pull_distance)


func _apply_pull(effect: CardEffect, source: CharacterData, target: Variant) -> void:
	if target is CharacterData:
		GridManager.pull_character(source, target, effect.push_pull_distance)


func _apply_draw(effect: CardEffect, source: CharacterData) -> void:
	var drawn: Array[CardData] = DeckManager.draw_cards(source, effect.roll())
	cards_drawn_by_effect.emit(source, drawn)


func _apply_area_damage(effect: CardEffect, source: CharacterData, target: Variant) -> void:
	if target is Vector2i:
		var targets: Array[CharacterData] = GridManager.get_characters_in_radius(target, effect.area_radius)
		var bonus: int = _get_scaling_bonus(effect, source) + _get_combo_bonus(effect, source)
		for t: CharacterData in targets:
			var dmg: int = calculate_damage(effect.roll() + bonus, source)
			var actual: int = t.take_damage(dmg)
			damage_dealt.emit(t, actual)
			if not t.is_alive():
				character_killed.emit(t)


func _apply_area_buff(effect: CardEffect, source: CharacterData, target: Variant) -> void:
	if target is Vector2i:
		var targets: Array[CharacterData] = GridManager.get_characters_in_radius(target, effect.area_radius)
		for t: CharacterData in targets:
			if t.faction == source.faction:
				t.modify_status(effect.status_effect, effect.value, effect.duration)


func _apply_area_debuff(effect: CardEffect, source: CharacterData, target: Variant) -> void:
	if target is Vector2i:
		var targets: Array[CharacterData] = GridManager.get_characters_in_radius(target, effect.area_radius)
		for t: CharacterData in targets:
			if t.faction != source.faction:
				t.modify_status(effect.status_effect, effect.value, effect.duration)


func _apply_shield_strike(effect: CardEffect, source: CharacterData, target: Variant) -> void:
	if target is CharacterData:
		var shield_stacks: int = source.get_status_stacks(Enums.StatusEffect.SHIELD)
		var base: int = int(shield_stacks * effect.shield_damage_multiplier)
		var dmg: int = calculate_damage(base, source)
		var actual: int = target.take_damage(dmg)
		damage_dealt.emit(target, actual)
		if not target.is_alive():
			character_killed.emit(target)


func _apply_summon(effect: CardEffect, source: CharacterData, target: Variant) -> void:
	if source.active_summons.size() >= source.max_summons:
		return  # At summon cap
	var summon: CharacterData = SummonManager.create_summon(effect.summon_id, source)
	if summon == null:
		return
	# Place summon on the grid
	var place_pos: Vector2i = source.grid_position
	if target is Vector2i:
		place_pos = target
	summon.grid_position = place_pos
	source.active_summons.append(summon)
	summon_created.emit(summon, source)


## Calculate element scaling bonus.
func _get_scaling_bonus(effect: CardEffect, source: CharacterData) -> int:
	if effect.scale_element == "" or effect.scale_per_stack == 0:
		return 0
	if effect.scale_element == "all":
		return source.get_total_element_stacks() * effect.scale_per_stack
	var stacks: int = source.element_stacks.get(effect.scale_element, 0)
	return stacks * effect.scale_per_stack


## Calculate combo bonus.
func _get_combo_bonus(effect: CardEffect, source: CharacterData) -> int:
	if effect.combo_tag == "" or effect.combo_bonus == 0:
		return 0
	if source.has_tag_played(effect.combo_tag):
		return effect.combo_bonus
	return 0
