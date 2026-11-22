class_name ItemData
extends Resource
## Un objet utilisable en combat, toujours sur un allié.

@export var id: StringName
@export var display_name := ""  ## Clé de traduction, ex. "ITEM_POTION"
@export_multiline var description := ""
@export var heal_amount := 0  ## PV rendus
@export var ap_amount := 0  ## PA donnés
@export var price := 20  ## Prix chez la marchande, en or
