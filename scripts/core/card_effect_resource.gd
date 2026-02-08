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
