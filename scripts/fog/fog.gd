class_name Fog
extends RefCounted
## 霧(AC-021, AC-022)。未探索の場所は見えない。村人の視界に入ると晴れ、晴れた地形はその後も見える。
## 今だれの視界にも入っていない場所の魔物は表示しない。

signal explored_changed

var village: Village
var cfg: Dictionary = {}
var width: int = 0
var height: int = 0
## 探索済み(1)の印。列ごと
var explored := PackedByteArray()
## いま視界に入っている(1)の印
var visible := PackedByteArray()
var _timer: float = 0.0


func _init(target: Village) -> void:
	village = target
	cfg = GameData.get_dict("fog")
	width = village.world.size.x
	height = village.world.size.z
	explored.resize(width * height)
	visible.resize(width * height)
	_reveal_circle(village.world.start, int(cfg["start_revealed_radius"]), false)


func is_explored(cell: Vector2i) -> bool:
	return village.world.in_bounds_2d(cell) and explored[cell.y * width + cell.x] == 1


func is_visible(cell: Vector2i) -> bool:
	return village.world.in_bounds_2d(cell) and visible[cell.y * width + cell.x] == 1


func is_monster_visible(m: Monster) -> bool:
	return is_visible(m.cell())


func update(dt: float) -> void:
	_timer -= dt
	if _timer > 0.0:
		return
	_timer = float(cfg["update_minutes"])
	refresh()


## 視界を計算し直す。新しく晴れた場所があれば explored_changed を出す
func refresh() -> void:
	visible.fill(0)
	var changed: bool = false
	for source: Dictionary in vision_sources():
		changed = _reveal_circle(source["cell"], int(source["radius"]), true) or changed
	if changed:
		explored_changed.emit()


## 視界の元: 動ける村人と、完成した見張り台(M3-T08)
func vision_sources() -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	for v in village.villagers:
		if v.state == Villager.State.NORMAL:
			sources.append({"cell": v.cell(), "radius": roundi(float(cfg["vision_radius"]) * Traits.product(v, "vision"))})
	for b: Building in village.buildings.values():
		if b.is_complete() and b.def().has("vision"):
			sources.append({"cell": Vector2i(b.center()), "radius": roundi(float(b.def()["vision"]) * (1.0 + BuildingFixture.sum_effect(b, "vision_bonus")))})
	return sources


func _reveal_circle(center: Vector2i, radius: int, mark_visible: bool) -> bool:
	var changed: bool = false
	var r2: int = radius * radius
	for dz in range(-radius, radius + 1):
		var z: int = center.y + dz
		if z < 0 or z >= height:
			continue
		for dx in range(-radius, radius + 1):
			var x: int = center.x + dx
			if x < 0 or x >= width or dx * dx + dz * dz > r2:
				continue
			var i: int = z * width + x
			if mark_visible:
				visible[i] = 1
			if explored[i] == 0:
				explored[i] = 1
				changed = true
	return changed


func explored_count() -> int:
	return explored.count(1)


func to_dict() -> Dictionary:
	return {"explored": Marshalls.raw_to_base64(explored.compress(FileAccess.COMPRESSION_ZSTD)), "size": explored.size()}


func from_dict(data: Dictionary) -> void:
	explored = Marshalls.base64_to_raw(str(data["explored"])).decompress(int(data["size"]), FileAccess.COMPRESSION_ZSTD)
	refresh()
