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


func get_display_text() -> String:
	var parts: PackedStringArray = []
	for effect: CardEffect in effects:
		match effect.effect_type:
			Enums.CardEffectType.DAMAGE:
				parts.append("Deal %d damage" % effect.value)
			Enums.CardEffectType.HEAL:
				parts.append("Heal %d HP" % effect.value)
			Enums.CardEffectType.MOVE:
				parts.append("Move %d tiles" % effect.value)
			Enums.CardEffectType.SHIELD:
				parts.append("Gain %d shield" % effect.value)
			Enums.CardEffectType.DRAW:
				parts.append("Draw %d cards" % effect.value)
			_:
				parts.append(description)
	return "\n".join(parts)
