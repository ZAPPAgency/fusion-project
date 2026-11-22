class_name DamageCalculator
extends RefCounted
## Formules de dégâts et de soin, regroupées ici pour faciliter l'équilibrage.


## `multiplier` servira aux QTE (ex. 1.5 pour un timing parfait). 1.0 = normal.
static func damage(attacker: BattleUnit, defender: BattleUnit, skill: SkillData, multiplier := 1.0) -> int:
	var raw := attacker.attack * skill.power * multiplier
	# La défense réduit les dégâts sans jamais les annuler : 50 de défense = dégâts divisés par 2.
	var reduced := raw * 50.0 / (50.0 + defender.defense)
	return maxi(1, roundi(reduced))


static func heal(healer: BattleUnit, skill: SkillData) -> int:
	return maxi(1, roundi(healer.attack * skill.power))
