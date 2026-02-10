## Defines a single card that can be played during battle.
## Each card belongs to a character's deck and has energy cost, range,
## target type, and one or more effects.
class_name CardData
extends Resource

@export var id: String = ""
@export var card_name: String = ""
@export_multiline var description: String = ""
@export var energy_cost: int = 1
@export var range_min: int = 0
@export var range_max: int = 1
@export var target_type: Enums.TargetType = Enums.TargetType.SINGLE_ENEMY
@export var effects: Array[CardEffect] = []
@export var icon: Texture2D = null
@export var rarity: int = 0  ## 0=common, 1=uncommon, 2=rare

## Combo tags for rogue chain system
@export var tags: PackedStringArray = []
## Element attribute ("fire","ice","lightning")
@export var element: String = ""
## Element stack count to add when played
@export var element_count: int = 1
## If true, card is exhausted (removed from battle) after play
@export var exhaust_on_play: bool = false
## If true, consumes all element stacks when played
@export var consumes_stacks: bool = false
## If true, can only be played while BERSERK is active
@export var requires_berserk: bool = false
## Consume this many element stacks when played (0 = none)
@export var element_cost: int = 0


func get_display_text() -> String:
	var parts: PackedStringArray = []
	for effect: CardEffect in effects:
		var text: String = ""
		match effect.effect_type:
			Enums.CardEffectType.DAMAGE:
				text = "Deal %s damage" % effect.get_dice_notation()
			Enums.CardEffectType.HEAL:
				text = "Heal %s HP" % effect.get_dice_notation()
			Enums.CardEffectType.MOVE:
				text = "Move %d tiles" % effect.value
			Enums.CardEffectType.SHIELD:
				text = "Gain %s shield" % effect.get_dice_notation()
			Enums.CardEffectType.DRAW:
				text = "Draw %d cards" % effect.value
			Enums.CardEffectType.SHIELD_STRIKE:
				var mult: String = ""
				if effect.shield_damage_multiplier != 1.0:
					mult = " (x%.1f)" % effect.shield_damage_multiplier
				text = "Deal shield as damage%s" % mult
			Enums.CardEffectType.SUMMON:
				text = "Summon %s" % effect.summon_id.replace("_", " ").capitalize()
			Enums.CardEffectType.SACRIFICE:
				text = "Sacrifice %s HP" % effect.get_dice_notation()
			_:
				text = description
		if effect.stack_multiplier and effect.scale_element != "":
			text = text.replace("Deal %s" % effect.get_dice_notation(), "Deal [%s] x %s" % [effect.scale_element, effect.get_dice_notation()])
		elif effect.scale_element != "" and effect.scale_per_stack > 0:
			text += " (+%d/%s stack)" % [effect.scale_per_stack, effect.scale_element]
		if effect.combo_tag != "" and effect.combo_bonus > 0:
			text += " [Combo: %s +%d]" % [effect.combo_tag, effect.combo_bonus]
		parts.append(text)
	if element != "" and element_count > 0:
		parts.append("+%d %s" % [element_count, element.capitalize()])
	if element_cost > 0:
		parts.append("-%d %s" % [element_cost, element.capitalize()])
	if consumes_stacks:
		parts.append("Consume all %s" % element.capitalize())
	if exhaust_on_play:
		parts.append("Exhaust")
	if requires_berserk:
		parts.append("Requires Berserk")
	return "\n".join(parts)
