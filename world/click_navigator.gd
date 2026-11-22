class_name ClickNavigator
extends RefCounted
## Chemin pour le déplacement à la souris (comme dans Diablo) : la carte est découpée en cases
## de CELL pixels ; une case est bloquée si le joueur (un cercle) y touche un obstacle
## (eau, murs, arbres, maisons, PNJ...). Le chemin est calculé avec A* (AStarGrid2D),
## puis lissé : on va tout droit dès que la voie est libre.
## À utiliser pendant _physics_process (requêtes physiques).

const CELL := 16

var _grid := AStarGrid2D.new()
var _space: PhysicsDirectSpaceState2D
var _shape := CircleShape2D.new()
var _exclude: Array[RID] = []
var _mask := 1
var _shape_offset := Vector2.ZERO  ## Décalage du cercle de collision par rapport aux pieds


## `bounds` : la carte en pixels ; `body` : le joueur ; `radius` et `shape_offset` : son cercle
## de collision (un pixel de marge est ajouté pour ne pas frôler les coins).
func _init(bounds: Rect2, body: CharacterBody2D, radius: float, shape_offset: Vector2) -> void:
	_space = body.get_world_2d().direct_space_state
	_shape.radius = radius + 1.0
	_shape_offset = shape_offset
	_exclude = [body.get_rid()]
	_mask = body.collision_mask
	_grid.region = Rect2i(0, 0, ceili(bounds.size.x / CELL), ceili(bounds.size.y / CELL))
	_grid.cell_size = Vector2(CELL, CELL)
	_grid.offset = bounds.position + Vector2(CELL, CELL) / 2  # points au centre des cases
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	for y in _grid.region.size.y:
		for x in _grid.region.size.x:
			var cell := Vector2i(x, y)
			if _blocked(_grid.get_point_position(cell)):
				_grid.set_point_solid(cell)


## Points à suivre pour aller de `from` à `to` (vide si c'est impossible).
func path(from: Vector2, to: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var start := _free_cell_near(_cell_of(from))
	var goal := _free_cell_near(_cell_of(to))
	if start == Vector2i(-1, -1) or goal == Vector2i(-1, -1):
		return result
	var points := _grid.get_point_path(start, goal)
	if points.is_empty():
		return result
	var waypoints: Array[Vector2] = []
	waypoints.assign(points)
	if not _blocked(to):
		waypoints[-1] = to  # on va exactement là où le joueur a cliqué
	# Lissage : depuis chaque point, on saute directement au point le plus loin visible.
	var current := from
	var i := 0
	while i < waypoints.size():
		var farthest := i
		for j in range(waypoints.size() - 1, i, -1):
			if _clear_line(current, waypoints[j]):
				farthest = j
				break
		current = waypoints[farthest]
		result.append(current)
		i = farthest + 1
	return result


func _cell_of(point: Vector2) -> Vector2i:
	var local := (point - _grid.offset + Vector2(CELL, CELL) / 2) / CELL
	return Vector2i(clampi(floori(local.x), 0, _grid.region.size.x - 1), clampi(floori(local.y), 0, _grid.region.size.y - 1))


## La case elle-même si elle est libre, sinon la case libre la plus proche (ou (-1, -1)).
func _free_cell_near(cell: Vector2i) -> Vector2i:
	for radius in 6:
		var best := Vector2i(-1, -1)
		var best_distance := INF
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var candidate := cell + Vector2i(x, y)
				if _grid.is_in_boundsv(candidate) and not _grid.is_point_solid(candidate):
					var distance := Vector2(x, y).length()
					if distance < best_distance:
						best_distance = distance
						best = candidate
		if best != Vector2i(-1, -1):
			return best
	return Vector2i(-1, -1)


func _blocked(point: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0.0, point + _shape_offset)
	query.exclude = _exclude
	query.collision_mask = _mask
	query.collide_with_areas = false
	return not _space.intersect_shape(query, 1).is_empty()


## Vrai si le joueur peut aller tout droit de `from` à `to` sans toucher d'obstacle.
func _clear_line(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0.0, from + _shape_offset)
	query.motion = to - from
	query.exclude = _exclude
	query.collision_mask = _mask
	query.collide_with_areas = false
	var result := _space.cast_motion(query)
	return result.is_empty() or result[0] >= 1.0
