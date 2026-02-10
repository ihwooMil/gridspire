## Global enumerations used throughout GridSpire.
class_name Enums


## The type of effect a card produces.
enum CardEffectType {
	DAMAGE,
	HEAL,
	MOVE,
	BUFF,
	DEBUFF,
	PUSH,
	PULL,
	AREA_DAMAGE,
	AREA_BUFF,
	AREA_DEBUFF,
	DRAW,
	SHIELD,
	SHIELD_STRIKE,  ## Deal damage equal to current shield stacks
	SUMMON,         ## Summon a creature onto the grid
	SACRIFICE,      ## Direct HP loss ignoring shield/evasion, min 1 HP
}

## Who or what a card can target.
enum TargetType {
	SELF,
	SINGLE_ALLY,
	SINGLE_ENEMY,
	ALL_ALLIES,
	ALL_ENEMIES,
	TILE,
	AREA,
	NONE,
}

## The terrain type of a grid tile.
enum TileType {
	FLOOR,
	WALL,
	PIT,
	HAZARD,
	ELEVATED,
}

## Which faction a character belongs to.
enum Faction {
	PLAYER,
	ENEMY,
	NEUTRAL,
}

## Status effect identifiers.
enum StatusEffect {
	STRENGTH,
	WEAKNESS,
	HASTE,
	SLOW,
	SHIELD,
	POISON,
	REGEN,
	STUN,
	ROOT,
	BERSERK,   ## +2 damage per stack, cannot gain shield
	EVASION,   ## 15% dodge per stack (max 75%), consumes 1 stack on dodge
	UNHEALABLE,  ## Blocks all healing (card heal, REGEN) while stacks > 0
}

## High-level game states.
enum GameState {
	MAIN_MENU,
	CHARACTER_SELECT,
	MAP,
	BATTLE,
	REWARD,
	SHOP,
	EVENT,
	GAME_OVER,
}

## Map node types for the overworld map.
enum MapNodeType {
	BATTLE,
	ELITE,
	SHOP,
	REST,
	EVENT,
	BOSS,
	START,
	COMPANION,
}

## Event subtypes for EVENT map nodes.
enum EventType { COMPANION, REST, TREASURE, MYSTERY }

## Phases within a single character's turn in battle.
enum TurnPhase {
	DRAW,
	ACTION,
	DISCARD,
	END,
}
