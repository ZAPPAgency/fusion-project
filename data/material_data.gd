class_name MaterialData
extends Resource
## Matériau de forge (fragments, minerai, éclats...) : sert à améliorer et faire évoluer.

## Forme de l'icône dessinée en code (voir MaterialIcon).
enum Shape { SHARD, ORE, CRYSTAL, TEAR }

@export var id: StringName
@export var display_name := ""  ## Clé de traduction, ex. "MAT_FRAGMENT_CENDRE"
@export var rarity := CardData.Rarity.COMMON
@export var shape := Shape.SHARD
@export var color := Color.WHITE
@export var price := 0  ## Prix chez la marchande (0 = pas en vente)
