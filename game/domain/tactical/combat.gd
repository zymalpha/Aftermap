class_name Combat extends RefCounted

## Semi-automatic combat resolver. Players issue commands (move, attack,
## cover, etc.); the agent auto-executes while the player can pause.
##
## Hit chance model (per spec §10.2):
##   hit_chance = clamp(
##     attacker.skill * 0.06            # 6% per skill level (策划09 §4)
##     + weapon_base_accuracy
##     + stance_aim_modifier
##     - distance_penalty
##     - target_move_penalty
##     - cover_penalty
##     - light_penalty
##     - fatigue_penalty
##     + 0.0,                           # placeholder for future mods
##     0.05, 0.95,
##   )
##
## Damage roll uses weapon damage ± 25%, infection dose from weapon class.

const _PATH: String = "res://game/domain/tactical/combat.gd"

const WEAPON_KNIFE: StringName = &"wpn_knife"
const WEAPON_PIPE: StringName = &"wpn_pipe"
const WEAPON_HATCHET: StringName = &"wpn_hatchet"
const WEAPON_SLEDGE: StringName = &"wpn_sledge"
const WEAPON_CROSSBOW: StringName = &"wpn_crossbow"
const WEAPON_PISTOL_9MM: StringName = &"wpn_pistol_9mm"
const WEAPON_SHOTGUN: StringName = &"wpn_shotgun"
const WEAPON_RIFLE: StringName = &"wpn_rifle"

# Weapon stats from 策划 09 §10.2.
# damage, stopping_power, attack_interval, sound, infection_dose.
const WEAPONS: Dictionary = {
	WEAPON_KNIFE:      {"damage": 14, "stop": 8,  "interval": 1.0, "sound": 7,  "dose": 12, "base_acc": 0.78},
	WEAPON_PIPE:       {"damage": 16, "stop": 18, "interval": 1.4, "sound": 12, "dose": 6,  "base_acc": 0.72},
	WEAPON_HATCHET:    {"damage": 24, "stop": 22, "interval": 1.7, "sound": 15, "dose": 14, "base_acc": 0.70},
	WEAPON_SLEDGE:     {"damage": 28, "stop": 32, "interval": 2.2, "sound": 18, "dose": 8,  "base_acc": 0.62},
	WEAPON_CROSSBOW:   {"damage": 32, "stop": 26, "interval": 4.0, "sound": 15, "dose": 10, "base_acc": 0.85},
	WEAPON_PISTOL_9MM: {"damage": 26, "stop": 22, "interval": 2.2, "sound": 65, "dose": 8,  "base_acc": 0.70},
	WEAPON_SHOTGUN:    {"damage": 48, "stop": 55, "interval": 0.9, "sound": 90, "dose": 12, "base_acc": 0.55},
	WEAPON_RIFLE:      {"damage": 38, "stop": 35, "interval": 3.0, "sound": 85, "dose": 10, "base_acc": 0.80},
}

const DISTANCE_PENALTY_PER_CELL: float = 0.04
const MOVE_PENALTY: float = 0.10
const FULL_COVER_PENALTY: float = 0.60
const HALF_COVER_PENALTY: float = 0.25
const DARKNESS_PENALTY: float = 0.10
const FATIGUE_PENALTY_MAX: float = 0.15
const SKILL_HIT_PER_LEVEL: float = 0.06
const HIT_MIN: float = 0.05
const HIT_MAX: float = 0.95

# Resolve an attack.
# attacker / target: Dictionaries with at least:
#   { skill_combat: int (0..5), fatigue: int (0..100), stance: int (0..3) }
# weapon: StringName (one of WEAPON_*)
# distance: int (cells, 0 = adjacent)
# cover: int (0 = none, 1 = half, 2 = full)
# target_moving: bool
# dark: bool
# rng: RngService (or any object exposing get_float(stream, lo, hi))
# Returns Dictionary:
#   { hit: bool, dmg: int, infection_dose: int, side_effects: Array[String] }
static func resolve_attack(attacker: Dictionary, target: Dictionary, weapon: StringName, distance: int, cover: int, target_moving: bool, dark: bool, rng: RefCounted) -> Dictionary:
	var stats: Dictionary = WEAPONS.get(weapon, {})
	if stats.is_empty():
		return {"hit": false, "dmg": 0, "infection_dose": 0, "side_effects": ["unknown_weapon"]}
	var skill: int = int(attacker.get("skill_combat", 0))
	var fatigue: int = clampi(int(attacker.get("fatigue", 0)), 0, 100)
	var stance: int = int(attacker.get("stance", 0))  # 0 standing, 1 crouch, 2 aim

	var hit_chance: float = stats.get("base_acc", 0.5)
	hit_chance += float(skill) * SKILL_HIT_PER_LEVEL
	# Stance/aim bonus: aiming (stance=2) gives +0.08; crouch (1) gives +0.04.
	if stance == 2:
		hit_chance += 0.08
	elif stance == 1:
		hit_chance += 0.04

	hit_chance -= float(max(0, distance)) * DISTANCE_PENALTY_PER_CELL
	if target_moving:
		hit_chance -= MOVE_PENALTY
	if cover == 2:
		hit_chance -= FULL_COVER_PENALTY
	elif cover == 1:
		hit_chance -= HALF_COVER_PENALTY
	if dark:
		hit_chance -= DARKNESS_PENALTY
	# Fatigue: up to FATIGUE_PENALTY_MAX when fatigue = 100.
	hit_chance -= float(fatigue) / 100.0 * FATIGUE_PENALTY_MAX
	hit_chance = clamp(hit_chance, HIT_MIN, HIT_MAX)

	# RNG draw in [0, 1).
	var roll: float = 0.5
	if rng != null:
		roll = rng.call("get_float", &"combat_resolve", 0.0, 1.0)
	var hit: bool = roll < hit_chance

	var dmg: int = 0
	var dose: int = 0
	var side_effects: Array = []
	if hit:
		var base_dmg: int = int(stats.get("damage", 0))
		# ±25% damage variance.
		var var_pct: float = -0.25
		if rng != null:
			var_pct = rng.call("get_float", &"combat_damage", -0.25, 0.25)
		dmg = int(round(float(base_dmg) * (1.0 + var_pct)))
		if dmg < 0:
			dmg = 0
		dose = int(stats.get("dose", 0))
		# Cover reduces damage on half/full cover hits.
		if cover == 2:
			dmg = int(round(float(dmg) * 0.3))
		elif cover == 1:
			dmg = int(round(float(dmg) * 0.6))
		# Shotgun falls off fast past 2 cells.
		if weapon == WEAPON_SHOTGUN and distance > 2:
			dmg = int(round(float(dmg) * 0.5))
		side_effects.append("hit")
	else:
		side_effects.append("miss")

	# Side effects
	if hit and weapon == WEAPON_SHOTGUN and distance <= 2:
		side_effects.append("close_quarters_stop")
	if weapon in [WEAPON_PISTOL_9MM, WEAPON_SHOTGUN, WEAPON_RIFLE]:
		side_effects.append("loud")

	return {
		"hit": hit,
		"dmg": dmg,
		"infection_dose": dose if hit else 0,
		"side_effects": side_effects,
		"hit_chance": hit_chance,
	}

static func weapon_stats(weapon: StringName) -> Dictionary:
	var s: Dictionary = WEAPONS.get(weapon, {})
	return s.duplicate()

static func list_weapons() -> Array:
	var out: Array = []
	for k in WEAPONS.keys():
		out.append(StringName(k))
	return out