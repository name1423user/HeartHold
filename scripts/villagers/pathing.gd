class_name Pathing
extends RefCounted
## 地表の上を歩く経路探索。列(x, z)を点にし、段差 max_step 以内の隣同士をつなぐ。

var world: WorldData
var astar := AStar2D.new()
var max_step: int = 1

const NEIGHBORS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _init(target: WorldData) -> void:
	world = target
	max_step = int(GameData.get_dict("terrain").get("max_step", 1))
	var count: int = world.size.x * world.size.z
	astar.reserve_space(count)
	for z in world.size.z:
		for x in world.size.x:
			var id: int = world.column_index(x, z)
			astar.add_point(id, Vector2(x, z))
			astar.set_point_disabled(id, not world.is_walkable(Vector2i(x, z)))
	for z in world.size.z:
		for x in world.size.x:
			var cell := Vector2i(x, z)
			_link(cell, cell + Vector2i(1, 0))
			_link(cell, cell + Vector2i(0, 1))


## ブロックや木が変わった列とその周りをつなぎ直す
func update_cell(cell: Vector2i) -> void:
	if not world.in_bounds_2d(cell):
		return
	astar.set_point_disabled(_id(cell), not world.is_walkable(cell))
	for offset in NEIGHBORS:
		_link(cell, cell + offset)


func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not world.in_bounds_2d(from) or not world.in_bounds_2d(to):
		return result
	for point in astar.get_point_path(_id(from), _id(to)):
		result.append(Vector2i(point))
	return result


func is_reachable(from: Vector2i, to: Vector2i) -> bool:
	if from == to:
		return world.is_walkable(to)
	return not find_path(from, to).is_empty()


## 目的地そのものに立てない(木・建物の中など)ときに、隣で一番近い立てる列
func nearest_standable(from: Vector2i, target: Vector2i) -> Vector2i:
	if world.is_walkable(target) and is_reachable(from, target):
		return target
	var best := Vector2i(-1, -1)
	var best_length: int = 1 << 30
	for offset in NEIGHBORS:
		var cell: Vector2i = target + offset
		if not world.is_walkable(cell):
			continue
		var path: Array[Vector2i] = find_path(from, cell)
		if (not path.is_empty() or cell == from) and path.size() < best_length:
			best = cell
			best_length = path.size()
	return best


func _id(cell: Vector2i) -> int:
	return world.column_index(cell.x, cell.y)


func _link(a: Vector2i, b: Vector2i) -> void:
	if not world.in_bounds_2d(b):
		return
	var ia: int = _id(a)
	var ib: int = _id(b)
	var ok: bool = world.is_walkable(a) and world.is_walkable(b) and absi(world.top_y(a) - world.top_y(b)) <= max_step
	if ok and not astar.are_points_connected(ia, ib):
		astar.connect_points(ia, ib)
	elif not ok and astar.are_points_connected(ia, ib):
		astar.disconnect_points(ia, ib)
