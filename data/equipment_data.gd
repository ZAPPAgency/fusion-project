class_name EquipmentData
extends Resource
## Une pièce d'équipement : arme, armure ou accessoire, avec ses bonus de stats.

enum Slot { WEAPON, ARMOR, ACCESSORY }

@export var id: StringName
@export var display_name := ""  ## Clé de traduction, ex. "EQUIP_EPEE_ACIER"
@export var slot := Slot.WEAPON
@export var for_hero: StringName  ## Réservé à un héros (id), vide = tout le monde
@export var price := 50  ## Prix chez la marchande, en or

@export_group("Bonus")
@export var attack := 0
@export var defense := 0
@export var max_hp := 0
@export var speed := 0


func can_be_used_by(hero_id: StringName) -> bool:
	return for_hero == &"" or for_hero == hero_id


## Résumé des bonus, ex. "+4 ATQ  +10 PV".
func bonus_text() -> String:
	var parts: Array[String] = []
	for bonus in [[attack, "STAT_ATK"], [defense, "STAT_DEF"], [max_hp, "HP_SHORT"], [speed, "STAT_SPD"]]:
		if bonus[0] != 0:
			parts.append("%+d %s" % [bonus[0], TranslationServer.translate(bonus[1])])
	return "  ".join(parts)
