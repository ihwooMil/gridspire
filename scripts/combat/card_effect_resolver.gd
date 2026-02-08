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


## Resolve all effects on a card.
func resolve_card(card: CardData, source: CharacterData, target: Variant) -> void:
	for effect: CardEffect in card.effects:
		apply_effect(effect, source, target)


## Apply a single card effect. The target can be CharacterData or Vector2i
## depending on the card's target_type.
func apply_effect(effect: CardEffect, source: CharacterData, target: Variant) -> void:
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


## Calculate damage with strength bonus and weakness reduction.
func calculate_damage(base_value: int, source: CharacterData) -> int:
	var dmg: int = base_value
	dmg += source.get_status_stacks(Enums.StatusEffect.STRENGTH)
	if source.get_status_stacks(Enums.StatusEffect.WEAKNESS) > 0:
		dmg = int(dmg * 0.75)
	return maxi(dmg, 0)


func _apply_damage(effect: CardEffect, source: CharacterData, target: Variant) -> void:
	if target is CharacterData:
		var dmg: int = calculate_damage(effect.value, source)
		var actual: int = target.take_damage(dmg)
		damage_dealt.emit(target, actual)
		if not target.is_alive():
			character_killed.emit(target)


func _apply_heal(effect: CardEffect, target: Variant) -> void:
	if target is CharacterData:
		var hp_before: int = target.current_hp
		target.heal(effect.value)
		var actual_heal: int = target.current_hp - hp_before
		healing_done.emit(target, actual_heal)


func _apply_move(effect: CardEffect, source: CharacterData, target: Variant) -> void:
	if target is Vector2i:
		GridManager.move_character(source, target)


func _apply_shield(effect: CardEffect, source: CharacterData, _target: Variant) -> void:
	source.modify_status(Enums.StatusEffect.SHIELD, effect.value, 1)


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
	var drawn: Array[CardData] = DeckManager.draw_cards(source, effect.value)
	cards_drawn_by_effect.emit(source, drawn)


func _apply_area_damage(effect: CardEffect, source: CharacterData, target: Variant) -> void:
	if target is Vector2i:
		var targets: Array[CharacterData] = GridManager.get_characters_in_radius(target, effect.area_radius)
		for t: CharacterData in targets:
			var dmg: int = calculate_damage(effect.value, source)
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
