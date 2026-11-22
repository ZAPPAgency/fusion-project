class_name MaterialIcon
extends Control
## Petite icône de matériau dessinée en code (éclat, minerai, cristal, larme).

const SIZE := Vector2(14, 14)

var material_data: MaterialData


func _init(data: MaterialData) -> void:
	material_data = data
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := SIZE / 2
	var color := material_data.color
	var dark := color.darkened(0.45)
	var light := color.lightened(0.45)
	match material_data.shape:
		MaterialData.Shape.SHARD:  # éclat de cendre : triangle incandescent
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 5), c + Vector2(-1, -6), c + Vector2(5, 3)]), dark)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-3, 4), c + Vector2(-1, -4), c + Vector2(3, 3)]), color)
			draw_rect(Rect2(c + Vector2(-1, -2), Vector2(1, 3)), light)
		MaterialData.Shape.ORE:  # pierre avec des paillettes de métal
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 2), c + Vector2(-3, -5), c + Vector2(4, -4), c + Vector2(6, 3), c + Vector2(0, 6)]), Color(0.32, 0.28, 0.26))
			draw_rect(Rect2(c + Vector2(-2, -2), Vector2(2, 2)), light)
			draw_rect(Rect2(c + Vector2(2, 0), Vector2(2, 2)), color)
			draw_rect(Rect2(c + Vector2(-3, 2), Vector2(1, 1)), light)
		MaterialData.Shape.CRYSTAL:  # éclat de cloche : cristal doré
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(5, -1), c + Vector2(0, 7), c + Vector2(-5, -1)]), dark)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(3, -1), c + Vector2(0, 5), c + Vector2(-3, -1)]), color)
			draw_rect(Rect2(c + Vector2(-1, -4), Vector2(1, 4)), light)
		_:  # larme de lune : goutte claire
			draw_circle(c + Vector2(0, 2), 4.5, dark)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 1), c + Vector2(0, -7), c + Vector2(4, 1)]), dark)
			draw_circle(c + Vector2(0, 2), 3.2, color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-3, 1), c + Vector2(0, -5), c + Vector2(3, 1)]), color)
			draw_rect(Rect2(c + Vector2(-2, 0), Vector2(1, 2)), Color.WHITE)
