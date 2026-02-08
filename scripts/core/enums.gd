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
}

## High-level game states.
enum GameState {
	MAIN_MENU,
	MAP,
	BATTLE,
	REWARD,
	SHOP,
	EVENT,
	GAME_OVER,
}

## Phases within a single character's turn in battle.
enum TurnPhase {
	DRAW,
	ACTION,
	DISCARD,
	END,
}
