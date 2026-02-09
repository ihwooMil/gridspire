## Defines a stat upgrade that can be purchased from shops or events.
class_name StatUpgrade
extends Resource

enum StatType { MAX_HP, STRENGTH, ENERGY, MOVE_RANGE, SPEED, MAX_SUMMONS }

@export var id: String = ""
@export var upgrade_name: String = ""
@export_multiline var description: String = ""
@export var stat_type: StatType = StatType.MAX_HP
@export var value: int = 0
@export var price: int = 100
