class_name WorldData
extends RefCounted
## ブロック地形の中身。VoxelBuffer と同じ並び(y が最も速く、次に x、最後に z)で持つ。

enum Biome { GRASSLAND, FOREST, MOUNTAIN, RIVER }

var seed: int = 0
var size: Vector3i = Vector3i.ZERO
var blocks: PackedByteArray = PackedByteArray()
var biomes: PackedByteArray = PackedByteArray()
## 列ごとの一番上の空気でないブロックの y
var top: PackedInt32Array = PackedInt32Array()
## 生成直後の top。掘れる深さの基準(AS-003)
var original_top: PackedInt32Array = PackedInt32Array()
## 木が立っている列。Vector2i(x, z) -> true
var trees: Dictionary = {}
var start: Vector2i = Vector2i.ZERO

var air_id: int = 0
var water_id: int = 0


func _init() -> void:
	var data: Dictionary = GameData.get_dict("terrain")
	var ids: Dictionary = data.get("blocks", {})
	air_id = int(ids.get("air", 0))
	water_id = int(ids.get("water", 0))


func block_id(name: String) -> int:
	var ids: Dictionary = GameData.get_dict("terrain").get("blocks", {})
	return int(ids.get(name, air_id))


func column_index(x: int, z: int) -> int:
	return z * size.x + x


func in_bounds(pos: Vector3i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.z >= 0 and pos.x < size.x and pos.y < size.y and pos.z < size.z


func in_bounds_2d(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.z


func get_block(pos: Vector3i) -> int:
	if not in_bounds(pos):
		return air_id
	return blocks[column_index(pos.x, pos.z) * size.y + pos.y]


func set_block(pos: Vector3i, id: int) -> void:
	var column: int = column_index(pos.x, pos.z)
	blocks[column * size.y + pos.y] = id
	if id != air_id and pos.y > top[column]:
		top[column] = pos.y
	elif id == air_id and pos.y == top[column]:
		var y: int = pos.y
		while y > 0 and blocks[column * size.y + y] == air_id:
			y -= 1
		top[column] = y


func top_y(cell: Vector2i) -> int:
	return top[column_index(cell.x, cell.y)]


func original_top_y(cell: Vector2i) -> int:
	return original_top[column_index(cell.x, cell.y)]


func biome_at(cell: Vector2i) -> int:
	return biomes[column_index(cell.x, cell.y)]


## 村人が立てる列か(一番上が水でない)。木の列も立てない
func is_walkable(cell: Vector2i) -> bool:
	if not in_bounds_2d(cell) or trees.has(cell):
		return false
	return get_block(Vector3i(cell.x, top_y(cell), cell.y)) != water_id
