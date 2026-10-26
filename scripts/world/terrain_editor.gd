class_name TerrainEditor
extends RefCounted
## 1ブロック単位の破壊・設置。元の地表から max_dig_depth 段より深くは壊せない(AS-003, AC-004)。

signal block_changed(pos: Vector3i, id: int)

var world: WorldData
var max_dig_depth: int = 4


func _init(target: WorldData) -> void:
	world = target
	max_dig_depth = int(GameData.get_dict("terrain").get("max_dig_depth", 4))


## 壊せない理由の文言キー。壊せるなら空文字
func break_error(pos: Vector3i) -> String:
	if not world.in_bounds(pos):
		return "cannot_break"
	var id: int = world.get_block(pos)
	if id == world.air_id or id == world.water_id:
		return "cannot_break"
	if pos.y <= world.original_top_y(Vector2i(pos.x, pos.z)) - max_dig_depth:
		return "dig_too_deep"
	return ""


func break_block(pos: Vector3i) -> Dictionary:
	var error: String = break_error(pos)
	if not error.is_empty():
		return {"ok": false, "message": Texts.t(error)}
	var id: int = world.get_block(pos)
	world.set_block(pos, world.air_id)
	block_changed.emit(pos, world.air_id)
	return {"ok": true, "block": id}


func place_error(pos: Vector3i, id: int) -> String:
	if not world.in_bounds(pos) or id == world.air_id:
		return "cannot_place"
	if world.get_block(pos) != world.air_id or world.trees.has(Vector2i(pos.x, pos.z)):
		return "cannot_place"
	return ""


func place_block(pos: Vector3i, id: int) -> Dictionary:
	var error: String = place_error(pos, id)
	if not error.is_empty():
		return {"ok": false, "message": Texts.t(error)}
	world.set_block(pos, id)
	block_changed.emit(pos, id)
	return {"ok": true}
