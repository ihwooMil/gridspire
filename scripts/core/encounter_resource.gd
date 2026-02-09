## Configuration for a single battle encounter.
class_name EncounterData
extends Resource

## Paths to enemy character .tres resources
@export var enemy_ids: Array[String] = []
## Grid dimensions for this encounter
@export var grid_width: int = 10
@export var grid_height: int = 8
## Gold rewarded on victory
@export var gold_reward: int = 25
## Whether this is an elite/boss fight
@export var is_elite: bool = false
@export var is_boss: bool = false
