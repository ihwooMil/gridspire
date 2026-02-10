## Static registry of all card and upgrade resource paths.
## Replaces DirAccess-based file scanning for web build compatibility.
class_name CardRegistry

const CLASS_CARDS: Dictionary = {
	"warrior": [
		"res://resources/cards/warrior/warrior_strike.tres",
		"res://resources/cards/warrior/warrior_defend.tres",
		"res://resources/cards/warrior/warrior_cleave.tres",
		"res://resources/cards/warrior/warrior_heavy_blow.tres",
		"res://resources/cards/warrior/warrior_shield_bash.tres",
		"res://resources/cards/warrior/warrior_battle_cry.tres",
		"res://resources/cards/warrior/warrior_iron_will.tres",
		"res://resources/cards/warrior/warrior_pommel_strike.tres",
		"res://resources/cards/warrior/warrior_charge.tres",
		"res://resources/cards/warrior/warrior_fortify.tres",
		"res://resources/cards/warrior/warrior_ground_slam.tres",
		"res://resources/cards/warrior/warrior_second_wind.tres",
		"res://resources/cards/warrior/warrior_shield_wall.tres",
		"res://resources/cards/warrior/warrior_whirlwind.tres",
		"res://resources/cards/warrior/warrior_rallying_shout.tres",
		"res://resources/cards/warrior/warrior_bloodlust.tres",
		"res://resources/cards/warrior/warrior_war_stomp.tres",
		"res://resources/cards/warrior/warrior_berserker_rage.tres",
		"res://resources/cards/warrior/warrior_executioners_swing.tres",
		"res://resources/cards/warrior/warrior_unstoppable_force.tres",
		"res://resources/cards/warrior/warrior_body_slam.tres",
		"res://resources/cards/warrior/warrior_iron_defense.tres",
		"res://resources/cards/warrior/warrior_bulwark_slam.tres",
		"res://resources/cards/warrior/warrior_aegis_charge.tres",
		"res://resources/cards/warrior/warrior_phalanx.tres",
		"res://resources/cards/warrior/warrior_shield_crusher.tres",
		"res://resources/cards/warrior/warrior_rage.tres",
		"res://resources/cards/warrior/warrior_reckless_strike.tres",
		"res://resources/cards/warrior/warrior_savage_leap.tres",
		"res://resources/cards/warrior/warrior_blood_frenzy.tres",
		"res://resources/cards/warrior/warrior_berserker_cleave.tres",
		"res://resources/cards/warrior/warrior_undying_fury.tres",
	],
	"mage": [
		"res://resources/cards/mage/mage_fire_bolt.tres",
		"res://resources/cards/mage/mage_magic_intellect.tres",
		"res://resources/cards/mage/mage_magic_barrier.tres",
		"res://resources/cards/mage/mage_dark_arrow.tres",
		"res://resources/cards/mage/mage_magic_explosion.tres",
		"res://resources/cards/mage/mage_magic_bullet.tres",
	],
	"rogue": [
		"res://resources/cards/rogue/rogue_quick_slash.tres",
		"res://resources/cards/rogue/rogue_dodge.tres",
		"res://resources/cards/rogue/rogue_backstab.tres",
		"res://resources/cards/rogue/rogue_poison_blade.tres",
		"res://resources/cards/rogue/rogue_shiv.tres",
		"res://resources/cards/rogue/rogue_shadow_step.tres",
		"res://resources/cards/rogue/rogue_sprint.tres",
		"res://resources/cards/rogue/rogue_throwing_knife.tres",
		"res://resources/cards/rogue/rogue_preparation.tres",
		"res://resources/cards/rogue/rogue_crippling_strike.tres",
		"res://resources/cards/rogue/rogue_flurry.tres",
		"res://resources/cards/rogue/rogue_expose_weakness.tres",
		"res://resources/cards/rogue/rogue_smoke_bomb.tres",
		"res://resources/cards/rogue/rogue_toxic_shuriken.tres",
		"res://resources/cards/rogue/rogue_venomous_fang.tres",
		"res://resources/cards/rogue/rogue_blade_dance.tres",
		"res://resources/cards/rogue/rogue_death_mark.tres",
		"res://resources/cards/rogue/rogue_assassinate.tres",
		"res://resources/cards/rogue/rogue_phantom_strike.tres",
		"res://resources/cards/rogue/rogue_thousand_cuts.tres",
		"res://resources/cards/rogue/rogue_opening_strike.tres",
		"res://resources/cards/rogue/rogue_envenom.tres",
		"res://resources/cards/rogue/rogue_fan_of_knives.tres",
		"res://resources/cards/rogue/rogue_feint.tres",
		"res://resources/cards/rogue/rogue_dash_strike.tres",
		"res://resources/cards/rogue/rogue_toxic_cascade.tres",
		"res://resources/cards/rogue/rogue_coup_de_grace.tres",
		"res://resources/cards/rogue/rogue_shadow_chain.tres",
	],
	"cleric": [
		"res://resources/cards/cleric/cleric_holy_light.tres",
		"res://resources/cards/cleric/cleric_divine_shield.tres",
		"res://resources/cards/cleric/cleric_smite.tres",
		"res://resources/cards/cleric/cleric_blessing.tres",
		"res://resources/cards/cleric/cleric_prayer.tres",
		"res://resources/cards/cleric/cleric_purifying_flame.tres",
		"res://resources/cards/cleric/cleric_radiance.tres",
		"res://resources/cards/cleric/cleric_divine_judgment.tres",
		"res://resources/cards/cleric/cleric_sanctuary.tres",
		"res://resources/cards/cleric/cleric_haste_prayer.tres",
		"res://resources/cards/cleric/cleric_greater_heal.tres",
		"res://resources/cards/cleric/cleric_holy_wrath.tres",
		"res://resources/cards/cleric/cleric_mass_blessing.tres",
		"res://resources/cards/cleric/cleric_retribution.tres",
		"res://resources/cards/cleric/cleric_divine_light.tres",
		"res://resources/cards/cleric/cleric_condemn.tres",
		"res://resources/cards/cleric/cleric_divine_storm.tres",
	],
	"necromancer": [
		"res://resources/cards/necromancer/necro_dark_bolt.tres",
		"res://resources/cards/necromancer/necro_bone_shield.tres",
		"res://resources/cards/necromancer/necro_life_tap.tres",
		"res://resources/cards/necromancer/necro_soul_bolt.tres",
		"res://resources/cards/necromancer/necro_shadow_grasp.tres",
		"res://resources/cards/necromancer/necro_dark_pact.tres",
		"res://resources/cards/necromancer/necro_hex.tres",
		"res://resources/cards/necromancer/necro_soul_explosion.tres",
		"res://resources/cards/necromancer/necro_mass_sacrifice.tres",
		"res://resources/cards/necromancer/necro_death_coil.tres",
		"res://resources/cards/necromancer/necro_necrotic_wave.tres",
		"res://resources/cards/necromancer/necro_soul_shield.tres",
		"res://resources/cards/necromancer/necro_wither.tres",
		"res://resources/cards/necromancer/necro_soul_harvest.tres",
		"res://resources/cards/necromancer/necro_blood_ritual.tres",
		"res://resources/cards/necromancer/necro_reaper.tres",
	],
}

const UPGRADES: Array = [
	"res://resources/upgrades/upgrade_hp_small.tres",
	"res://resources/upgrades/upgrade_hp_large.tres",
	"res://resources/upgrades/upgrade_str.tres",
	"res://resources/upgrades/upgrade_energy.tres",
	"res://resources/upgrades/upgrade_move.tres",
	"res://resources/upgrades/upgrade_speed.tres",
	"res://resources/upgrades/upgrade_summon.tres",
]


static func get_class_cards(class_id: String) -> Array[CardData]:
	var paths: Array = CLASS_CARDS.get(class_id, [])
	var cards: Array[CardData] = []
	for path: String in paths:
		var card: CardData = load(path) as CardData
		if card:
			cards.append(card)
	return cards


static func get_all_player_cards() -> Array[CardData]:
	var all: Array[CardData] = []
	for class_id: String in CLASS_CARDS.keys():
		all.append_array(get_class_cards(class_id))
	return all


static func get_upgrades() -> Array[StatUpgrade]:
	var upgrades: Array[StatUpgrade] = []
	for path: String in UPGRADES:
		var u: StatUpgrade = load(path) as StatUpgrade
		if u:
			upgrades.append(u)
	return upgrades
