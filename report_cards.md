# Card Validation Report

Generated: 2026-02-09

## Data Model Reference

- **CardData** (`scripts/core/card_resource.gd`): id, card_name, description, energy_cost, range_min/max, target_type, effects[], element, element_count, consumes_stacks, tags, exhaust_on_play, requires_berserk, rarity
- **CardEffect** (`scripts/core/card_effect_resource.gd`): effect_type (enum), value, duration, status_effect, area_radius, push_pull_distance, dice_count/sides/bonus, shield_damage_multiplier, summon_id, scale_element, scale_per_stack, combo_tag, combo_bonus, combo_only
- **Enums** (`scripts/core/enums.gd`): CardEffectType { DAMAGE=0, HEAL=1, MOVE=2, BUFF=3, DEBUFF=4, PUSH=5, PULL=6, AREA_DAMAGE=7, AREA_BUFF=8, AREA_DEBUFF=9, DRAW=10, SHIELD=11, SHIELD_STRIKE=12, SUMMON=13 }
- **Resolver** (`scripts/combat/card_effect_resolver.gd`): Lines 22-31 element stacking, 49-51 combo_only gate, 185-193 SHIELD_STRIKE, 212-218 scale_element/scale_per_stack, 222-227 combo_tag/combo_bonus

---

## 1. Warrior Archetype (Shield -> Counter)

### Cards Audited (25 total)

| Card | File | Effect Types | Status |
|------|------|-------------|--------|
| Strike | warrior_strike.tres | DAMAGE | OK |
| Defend | warrior_defend.tres | SHIELD | OK |
| Shield Bash | warrior_shield_bash.tres | DAMAGE + SHIELD | OK |
| Shield Wall | warrior_shield_wall.tres | SHIELD + BUFF(ROOT) | OK |
| Charge | warrior_charge.tres | DAMAGE + PUSH | OK |
| Cleave | warrior_cleave.tres | AREA_DAMAGE | OK |
| Heavy Blow | warrior_heavy_blow.tres | DAMAGE | OK |
| Ground Slam | warrior_ground_slam.tres | AREA_DAMAGE + AREA_DEBUFF(ROOT) | OK |
| Fortify | warrior_fortify.tres | SHIELD + BUFF(REGEN) | OK |
| Iron Will | warrior_iron_will.tres | SHIELD | OK |
| Pommel Strike | warrior_pommel_strike.tres | DAMAGE + DEBUFF(STUN) | OK |
| Second Wind | warrior_second_wind.tres | HEAL + SHIELD | OK |
| Whirlwind | warrior_whirlwind.tres | AREA_DAMAGE | OK |
| Executioner's Swing | warrior_executioners_swing.tres | DAMAGE | OK |
| Unstoppable Force | warrior_unstoppable_force.tres | DAMAGE + PUSH + DEBUFF(STUN) | OK |
| Battle Cry | warrior_battle_cry.tres | BUFF(STRENGTH) | OK |
| Rallying Shout | warrior_rallying_shout.tres | BUFF(STRENGTH) | OK |
| Bloodlust | warrior_bloodlust.tres | BUFF(STRENGTH) + BUFF(HASTE) | OK |
| War Stomp | warrior_war_stomp.tres | AREA_DEBUFF(STUN) | OK |
| Berserker Rage | warrior_berserker_rage.tres | BUFF(STRENGTH) + DEBUFF(WEAKNESS) | OK |
| Body Slam | warrior_body_slam.tres | SHIELD_STRIKE (1.0x) | OK |
| Iron Defense | warrior_iron_defense.tres | SHIELD (1d6+3) | OK |
| Bulwark Slam | warrior_bulwark_slam.tres | SHIELD (1d6+2) + SHIELD_STRIKE (1.0x) | OK |
| Aegis Charge | warrior_aegis_charge.tres | SHIELD_STRIKE (1.5x) + PUSH | OK |
| Phalanx | warrior_phalanx.tres | SHIELD (2d6+2) + DRAW | OK |
| Shield Crusher | warrior_shield_crusher.tres | SHIELD_STRIKE (2.0x), Exhaust | OK |
| Rage | warrior_rage.tres | BUFF(BERSERK) | OK |
| Reckless Strike | warrior_reckless_strike.tres | DAMAGE (1d8+3), requires_berserk | OK |
| **Shield Strike** | **warrior_shield_strike.tres** | **SHIELD_STRIKE (1.0x)** | **CREATED** |

### Changes Made

1. **CREATED `warrior_shield_strike.tres`** -- New dedicated Shield Strike card.
   - effect_type = SHIELD_STRIKE (12), shield_damage_multiplier = 1.0
   - Energy cost 1, melee range (1-1), targets single enemy
   - Rarity 1 (uncommon)
   - Rationale: Body Slam already existed with the same mechanic but the archetype lacked a card explicitly named "Shield Strike" as a clear entry point for the shield->counter gameplay pattern.

### Shield -> Counter Card Chain Summary

The warrior Shield -> Counter archetype now has a complete card chain:
- **Build shield**: Defend, Iron Will, Iron Defense, Shield Wall, Fortify, Phalanx, Second Wind, Bulwark Slam
- **Convert shield to damage**: Shield Strike (1.0x), Body Slam (1.0x), Bulwark Slam (shield + 1.0x strike), Aegis Charge (1.5x + push), Shield Crusher (2.0x, exhaust)

---

## 2. Mage Archetype (Element Stacking)

### Cards Audited (28 total)

| Card | File | Element | element_count | consumes_stacks | scale_element | scale_per_stack | Status |
|------|------|---------|--------------|----------------|--------------|----------------|--------|
| Spark | mage_spark.tres | lightning | 1 | - | - | - | **FIXED** |
| Fireball | mage_fireball.tres | fire | 1 | - | - | - | **FIXED** |
| Frost Bolt | mage_frost_bolt.tres | ice | 1 | - | - | - | **FIXED** |
| Pyroblast | mage_pyroblast.tres | fire | 2 | - | - | - | **FIXED** |
| Searing Ray | mage_searing_ray.tres | fire | 1 | - | - | - | **FIXED** |
| Chain Lightning | mage_chain_lightning.tres | lightning | 1 | - | - | - | **FIXED** |
| Blizzard | mage_blizzard.tres | ice | 2 | - | - | - | **FIXED** |
| Meteor | mage_meteor.tres | fire | 2 | - | - | - | **FIXED** |
| Flame Jet | mage_flame_jet.tres | fire | 1 | - | fire | 1 | OK |
| Ice Shard | mage_ice_shard.tres | ice | 1 | - | ice | 1 | OK |
| Volt Bolt | mage_volt_bolt.tres | lightning | 1 | - | lightning | 1 | OK |
| Inferno | mage_inferno.tres | fire | 2 | - | fire | 2 | OK |
| Storm Surge | mage_storm_surge.tres | lightning | 2 | - | lightning | 1 | OK |
| Glacial Barrier | mage_glacial_barrier.tres | ice | 1 | - | ice | 2 | OK |
| Convergence | mage_convergence.tres | - | - | true | all | 3 | OK |
| Elemental Mastery | mage_elemental_mastery.tres | all | 3 | - | - | - | OK |
| Arcane Bolt | mage_arcane_bolt.tres | - | - | - | - | - | OK (neutral) |
| Arcane Torrent | mage_arcane_torrent.tres | - | - | - | - | - | OK (neutral) |
| Healing Light | mage_healing_light.tres | - | - | - | - | - | OK (neutral) |
| Mana Shield | mage_mana_shield.tres | - | - | - | - | - | OK (neutral) |
| Arcane Intellect | mage_arcane_intellect.tres | - | - | - | - | - | OK (neutral) |
| Enfeeble | mage_enfeeble.tres | - | - | - | - | - | OK (neutral) |
| Ice Wall | mage_ice_wall.tres | - | - | - | - | - | OK (utility) |
| Arcane Barrier | mage_arcane_barrier.tres | - | - | - | - | - | OK (neutral) |
| Time Warp | mage_time_warp.tres | - | - | - | - | - | OK (neutral) |
| Mass Heal | mage_mass_heal.tres | - | - | - | - | - | OK (neutral) |
| Toxic Cloud | mage_toxic_cloud.tres | - | - | - | - | - | OK (neutral) |
| Gravity Well | mage_gravity_well.tres | - | - | - | - | - | OK (neutral) |

### Changes Made

1. **FIXED `mage_spark.tres`** -- Added `element = "lightning"`, `element_count = 1`. Spark is a lightning spell and should contribute to lightning element stacking.
2. **FIXED `mage_fireball.tres`** -- Added `element = "fire"`, `element_count = 1`. Fireball is a fire spell.
3. **FIXED `mage_frost_bolt.tres`** -- Added `element = "ice"`, `element_count = 1`. Frost Bolt is an ice spell.
4. **FIXED `mage_pyroblast.tres`** -- Added `element = "fire"`, `element_count = 2`. Pyroblast is described as a "massive fireball".
5. **FIXED `mage_searing_ray.tres`** -- Added `element = "fire"`, `element_count = 1`. Searing Ray is a fire spell.
6. **FIXED `mage_chain_lightning.tres`** -- Added `element = "lightning"`, `element_count = 1`. Chain Lightning is a lightning spell.
7. **FIXED `mage_blizzard.tres`** -- Added `element = "ice"`, `element_count = 2`. Blizzard is a major ice spell.
8. **FIXED `mage_meteor.tres`** -- Added `element = "fire"`, `element_count = 2`. Meteor is a major fire spell.

### Element Mapping Summary

- **Fire**: Spark -> N/A; Flame Jet, Fireball, Searing Ray, Inferno, Pyroblast, Meteor, Summon Fire Elemental
- **Ice**: Frost Bolt, Ice Shard, Glacial Barrier, Blizzard, Summon Ice Elemental
- **Lightning**: Spark, Volt Bolt, Chain Lightning, Storm Surge, Summon Lightning Elemental
- **All**: Elemental Mastery (adds 3 of each)
- **Consumers**: Convergence (consumes_stacks = true, scales by all stacks)

---

## 3. Rogue Archetype (Combo Chains)

### Cards Audited (28 total)

| Card | File | Tags | combo_tag | combo_bonus | combo_only | Status |
|------|------|------|-----------|-------------|-----------|--------|
| Quick Slash | rogue_quick_slash.tres | quick, strike | - | - | - | **FIXED** |
| Backstab | rogue_backstab.tres | strike, finisher | quick | 5 | - | **FIXED** |
| Shiv | rogue_shiv.tres | strike | - | - | - | OK |
| Opening Strike | rogue_opening_strike.tres | strike | - | - | - | OK |
| Throwing Knife | rogue_throwing_knife.tres | strike | - | - | - | OK |
| Flurry | rogue_flurry.tres | strike | - | - | - | OK |
| Poison Blade | rogue_poison_blade.tres | poison | - | - | - | OK |
| Crippling Strike | rogue_crippling_strike.tres | strike, poison | - | - | - | OK |
| Fan of Knives | rogue_fan_of_knives.tres | strike | movement | 2 | - | OK |
| Envenom | rogue_envenom.tres | poison | strike | 3 | - | OK |
| Dash Strike | rogue_dash_strike.tres | movement, strike | setup | 4 | - | OK |
| Toxic Cascade | rogue_toxic_cascade.tres | poison, finisher | poison | 5 | - | OK |
| Coup de Grace | rogue_coup_de_grace.tres | finisher | strike | 6 / poison | 4 | effect_2: true | OK |
| Dodge | rogue_dodge.tres | setup | - | - | - | OK |
| Sprint | rogue_sprint.tres | movement | - | - | - | OK |
| Shadow Step | rogue_shadow_step.tres | movement | - | - | - | OK |
| Preparation | rogue_preparation.tres | setup | - | - | - | OK |
| Feint | rogue_feint.tres | setup | - | - | - | OK |
| Expose Weakness | rogue_expose_weakness.tres | setup, poison | - | - | - | OK |
| Smoke Bomb | rogue_smoke_bomb.tres | setup, movement | - | - | - | OK |
| Shadow Chain | rogue_shadow_chain.tres | setup, movement | - | - | - | OK (exhaust) |
| Toxic Shuriken | rogue_toxic_shuriken.tres | strike, poison | - | - | - | OK |
| Venomous Fang | rogue_venomous_fang.tres | poison, finisher | - | - | - | OK |
| Blade Dance | rogue_blade_dance.tres | strike, finisher | - | - | - | OK |
| Death Mark | rogue_death_mark.tres | setup, finisher | - | - | - | OK |
| Assassinate | rogue_assassinate.tres | strike, finisher | - | - | - | OK |
| Phantom Strike | rogue_phantom_strike.tres | movement, strike | - | - | - | OK |
| Thousand Cuts | rogue_thousand_cuts.tres | strike, poison, finisher | - | - | - | OK |

### Changes Made

1. **FIXED `rogue_quick_slash.tres`** -- Added "quick" to tags (now `["quick", "strike"]`). Quick Slash needs the "quick" tag to enable the Quick Slash -> Backstab combo chain.
2. **FIXED `rogue_backstab.tres`** -- Added `combo_tag = "quick"` and `combo_bonus = 5` to its DAMAGE effect. Backstab now deals +5 bonus damage when played after Quick Slash (or any card with the "quick" tag).

### Combo Chain Summary

The rogue combo system uses tags on cards and combo_tag/combo_bonus on effects:

- **Quick Slash** (tag: "quick") -> **Backstab** (combo_tag: "quick", +5 dmg)
- **Any Setup card** (tag: "setup") -> **Dash Strike** (combo_tag: "setup", +4 dmg)
- **Any Movement card** (tag: "movement") -> **Fan of Knives** (combo_tag: "movement", +2 dmg)
- **Any Strike card** (tag: "strike") -> **Envenom** (combo_tag: "strike", +3 dmg)
- **Any Poison card** (tag: "poison") -> **Toxic Cascade** (combo_tag: "poison", +5 dmg)
- **Any Strike card** (tag: "strike") -> **Coup de Grace** (combo_tag: "strike", +6 dmg)
- **Any Poison card** (tag: "poison") -> **Coup de Grace** effect_2 (combo_tag: "poison", +4 dmg, combo_only: true -- this effect ONLY fires if combo met)

---

## 4. Summon Cards

### Mage Summon Cards

| Card | File | summon_id | Element | Status |
|------|------|-----------|---------|--------|
| Summon Fire Elemental | mage_summon_fire.tres | fire_elemental | fire (1) | **FIXED** (added element) |
| Summon Ice Elemental | mage_summon_ice.tres | ice_elemental | ice (1) | **FIXED** (added element) |
| Summon Lightning Elemental | mage_summon_lightning.tres | lightning_elemental | lightning (1) | OK (already had element) |
| Arcane Familiar | mage_arcane_familiar.tres | arcane_familiar | - | OK (neutral summon) |
| Elemental Army | mage_elemental_army.tres | fire_elemental + ice_elemental | - | OK (exhaust) |

### Summon Creature Cards (in resources/cards/summons/)

| Card | File | Effect | Status |
|------|------|--------|--------|
| Fire Touch | fire_touch.tres | DAMAGE (1d6+2) | OK |
| Frost Touch | frost_touch.tres | DAMAGE (1d4+1) + DEBUFF(SLOW) | OK |
| Ice Shield | ice_shield.tres | SHIELD (1d4+1) | OK |
| Arcane Zap | arcane_zap.tres | DAMAGE (1d6+2) at range 2-3 | OK |

### Changes Made

1. **FIXED `mage_summon_fire.tres`** -- Added `element = "fire"`, `element_count = 1`. Summoning a fire elemental should contribute to fire stacking.
2. **FIXED `mage_summon_ice.tres`** -- Added `element = "ice"`, `element_count = 1`. Summoning an ice elemental should contribute to ice stacking.

All summon_id values are valid: "fire_elemental", "ice_elemental", "lightning_elemental", "arcane_familiar".

---

## Summary of All Changes

| # | File | Change Type | Description |
|---|------|-------------|-------------|
| 1 | warrior/warrior_shield_strike.tres | CREATED | New Shield Strike card with SHIELD_STRIKE effect (1.0x multiplier) |
| 2 | mage/mage_spark.tres | FIXED | Added element = "lightning", element_count = 1 |
| 3 | mage/mage_fireball.tres | FIXED | Added element = "fire", element_count = 1 |
| 4 | mage/mage_frost_bolt.tres | FIXED | Added element = "ice", element_count = 1 |
| 5 | mage/mage_pyroblast.tres | FIXED | Added element = "fire", element_count = 2 |
| 6 | mage/mage_searing_ray.tres | FIXED | Added element = "fire", element_count = 1 |
| 7 | mage/mage_chain_lightning.tres | FIXED | Added element = "lightning", element_count = 1 |
| 8 | mage/mage_blizzard.tres | FIXED | Added element = "ice", element_count = 2 |
| 9 | mage/mage_meteor.tres | FIXED | Added element = "fire", element_count = 2 |
| 10 | mage/mage_summon_fire.tres | FIXED | Added element = "fire", element_count = 1 |
| 11 | mage/mage_summon_ice.tres | FIXED | Added element = "ice", element_count = 1 |
| 12 | rogue/rogue_quick_slash.tres | FIXED | Added "quick" tag to enable Quick Slash -> Backstab combo |
| 13 | rogue/rogue_backstab.tres | FIXED | Added combo_tag = "quick", combo_bonus = 5 to DAMAGE effect |

**Total: 1 card created, 12 cards fixed, 0 issues remaining.**
