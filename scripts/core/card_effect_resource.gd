## A single effect that a card applies when played.
## Cards can contain multiple CardEffects to create combo cards.
class_name CardEffect
extends Resource

@export var effect_type: Enums.CardEffectType = Enums.CardEffectType.DAMAGE
@export var value: int = 0
@export var duration: int = 0  ## For buffs/debuffs: number of turns
@export var status_effect: Enums.StatusEffect = Enums.StatusEffect.STRENGTH
@export var area_radius: int = 0  ## For area effects: radius in tiles
@export var push_pull_distance: int = 1  ## For push/pull effects

## Dice fields — when dice_count > 0, the effect uses dice rolls instead of flat value.
@export var dice_count: int = 0
@export var dice_sides: int = 0
@export var dice_bonus: int = 0

## Shield Strike multiplier (for SHIELD_STRIKE effect type)
@export var shield_damage_multiplier: float = 1.0
## Summon creature ID (for SUMMON effect type)
@export var summon_id: String = ""
## Element scaling target ("fire","ice","lightning","all")
@export var scale_element: String = ""
## Additional value per element stack
@export var scale_per_stack: int = 0
## Combo activation tag — bonus triggers if this tag was played this turn
@export var combo_tag: String = ""
## Bonus value when combo condition is met
@export var combo_bonus: int = 0
## If true, effect only activates when combo condition is met
@export var combo_only: bool = false
## If true, multiply dice roll by element stacks instead of additive scaling
@export var stack_multiplier: bool = false


## Returns true if this effect uses dice instead of a flat value.
func uses_dice() -> bool:
	return dice_count > 0 and dice_sides > 0


## Returns dice notation string like "2d6+3", or flat value as string if no dice.
func get_dice_notation() -> String:
	if not uses_dice():
		return str(value)
	var notation: String = "%dd%d" % [dice_count, dice_sides]
	if dice_bonus > 0:
		notation += "+%d" % dice_bonus
	return notation


## Roll the dice and return the result. Falls back to flat value if no dice set.
func roll() -> int:
	if not uses_dice():
		return value
	var total: int = dice_bonus
	for i: int in dice_count:
		total += randi_range(1, dice_sides)
	return total


## Returns the average roll value for display/AI purposes.
func get_average() -> float:
	if not uses_dice():
		return float(value)
	return dice_count * (dice_sides + 1.0) / 2.0 + dice_bonus
