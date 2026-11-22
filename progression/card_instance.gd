class_name CardInstance
extends RefCounted
## Un exemplaire de carte possédé par le joueur, avec son rang.
## Deux exemplaires de la même carte sont deux CardInstance différentes (uid différent).

const STAT_KEYS := {"max_hp": "HP_SHORT", "attack": "STAT_ATK", "defense": "STAT_DEF", "speed": "STAT_SPD"}
const PASSIVE_KEYS := {
	CardData.Passive.PARRY_AP: "PASSIVE_PARRY_AP",
	CardData.Passive.PERFECT_AP: "PASSIVE_PERFECT_AP",
	CardData.Passive.COUNTER_POWER: "PASSIVE_COUNTER_POWER",
	CardData.Passive.PERFECT_POWER: "PASSIVE_PERFECT_POWER",
	CardData.Passive.START_AP: "PASSIVE_START_AP",
}

var uid: int
var data: CardData
var rank := 1


func _init(card_data: CardData, card_uid: int, card_rank := 1) -> void:
	data = card_data
	uid = card_uid
	rank = card_rank


func stat(stat_name: String) -> int:
	return data.stat_at_rank(stat_name, rank)


func timing_bonus_ms() -> float:
	return data.timing_bonus_at_rank(rank)


func is_max_rank() -> bool:
	return rank >= CardData.MAX_RANK


## Lignes d'effet à afficher, ex. ["+5 ATQ", "Compétence : Tourbillon", "+1 PA par parade"].
func effect_lines() -> Array[String]:
	var lines: Array[String] = []
	var parts: Array[String] = []
	for stat_name in CardData.STATS:
		var value := stat(stat_name)
		if value != 0:
			parts.append("%+d %s" % [value, TranslationServer.translate(STAT_KEYS[stat_name])])
	if not parts.is_empty():
		lines.append("  ".join(parts))
	if data.skill:
		lines.append(TranslationServer.translate("CARD_SKILL").format({"skill": TranslationServer.translate(data.skill.display_name)}))
	if data.passive != CardData.Passive.NONE:
		var value := data.passive_value
		# Les puissances sont stockées en fraction (0.5) et affichées en pourcentage (50).
		if data.passive in [CardData.Passive.COUNTER_POWER, CardData.Passive.PERFECT_POWER]:
			value *= 100.0
		lines.append(TranslationServer.translate(PASSIVE_KEYS[data.passive]).format({"value": roundi(value)}))
	if timing_bonus_ms() > 0:
		lines.append(TranslationServer.translate("CARD_TIMING").format({"ms": roundi(timing_bonus_ms())}))
	return lines


func to_dict() -> Dictionary:
	return {"uid": uid, "id": String(data.id), "rank": rank}


static func from_dict(saved: Dictionary) -> CardInstance:
	var card_data: CardData = load("res://data/cards/%s.tres" % saved.id)
	return CardInstance.new(card_data, int(saved.uid), int(saved.get("rank", 1)))
