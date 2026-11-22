class_name EnemyAI
extends RefCounted
## Choix des actions ennemies. Volontairement simple pour l'instant.


static func choose_skill(unit: BattleUnit, rng: RandomNumberGenerator) -> SkillData:
	var skills := unit.skills
	if not skills.is_empty() and rng.randf() < unit.data.skill_chance:
		return skills[rng.randi_range(0, skills.size() - 1)]
	return unit.data.basic_attack


static func choose_target(candidates: Array[BattleUnit], rng: RandomNumberGenerator) -> BattleUnit:
	return candidates[rng.randi_range(0, candidates.size() - 1)]
