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
## 無限の地図(M11-T04)では、チャンクごとの印と、いま見えている列の集まりで持つ
var infinite: bool = false
var explored_chunks: Dictionary = {}
var visible_cells: Dictionary = {}
var chunk_size: int = 32


func _init(target: Village) -> void:
	village = target
	cfg = GameData.get_dict("fog")
	infinite = village.world.infinite
	chunk_size = village.world.chunk_size
	width = village.world.size.x
	height = village.world.size.z
	if not infinite:
		explored.resize(width * height)
		visible.resize(width * height)
	_reveal_circle(village.world.start, int(cfg["start_revealed_radius"]), false)


func is_explored(cell: Vector2i) -> bool:
	if infinite:
		var chunk: PackedByteArray = explored_chunks.get(village.world.chunk_of(cell), PackedByteArray())
		return not chunk.is_empty() and chunk[posmod(cell.y, chunk_size) * chunk_size + posmod(cell.x, chunk_size)] == 1
	return village.world.in_bounds_2d(cell) and explored[cell.y * width + cell.x] == 1


func is_visible(cell: Vector2i) -> bool:
	if infinite:
		return visible_cells.has(cell)
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
	visible_cells.clear()
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
	if infinite:
		return _reveal_circle_chunks(center, radius, mark_visible)
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


func _reveal_circle_chunks(center: Vector2i, radius: int, mark_visible: bool) -> bool:
	var changed: bool = false
	var r2: int = radius * radius
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dz * dz > r2:
				continue
			var cell: Vector2i = center + Vector2i(dx, dz)
			if mark_visible:
				visible_cells[cell] = true
			var key: Vector2i = village.world.chunk_of(cell)
			var chunk: PackedByteArray = explored_chunks.get(key, PackedByteArray())
			if chunk.is_empty():
				chunk.resize(chunk_size * chunk_size)
			var i: int = posmod(cell.y, chunk_size) * chunk_size + posmod(cell.x, chunk_size)
			if chunk[i] == 0:
				chunk[i] = 1
				explored_chunks[key] = chunk
				changed = true
	return changed


## 霧の表示用: origin から size×size の範囲の探索済みの印(1行ずつ z、x の順)
func explored_window(origin: Vector2i, window: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(window * window)
	if not infinite:
		for z in window:
			for x in window:
				var cell: Vector2i = origin + Vector2i(x, z)
				if village.world.in_bounds_2d(cell):
					out[z * window + x] = explored[cell.y * width + cell.x]
		return out
	for key: Vector2i in explored_chunks:
		var chunk_origin: Vector2i = key * chunk_size
		if chunk_origin.x + chunk_size <= origin.x or chunk_origin.y + chunk_size <= origin.y or chunk_origin.x >= origin.x + window or chunk_origin.y >= origin.y + window:
			continue
		var chunk: PackedByteArray = explored_chunks[key]
		for lz in chunk_size:
			var wz: int = chunk_origin.y + lz - origin.y
			if wz < 0 or wz >= window:
				continue
			for lx in chunk_size:
				var wx: int = chunk_origin.x + lx - origin.x
				if wx >= 0 and wx < window:
					out[wz * window + wx] = chunk[lz * chunk_size + lx]
	return out


func explored_count() -> int:
	if infinite:
		var total: int = 0
		for key: Vector2i in explored_chunks:
			total += (explored_chunks[key] as PackedByteArray).count(1)
		return total
	return explored.count(1)


func to_dict() -> Dictionary:
	if infinite:
		var out: Dictionary = {}
		for key: Vector2i in explored_chunks:
			out["%d,%d" % [key.x, key.y]] = Marshalls.raw_to_base64(explored_chunks[key])
		return {"chunks": out}
	return {"explored": Marshalls.raw_to_base64(explored.compress(FileAccess.COMPRESSION_ZSTD)), "size": explored.size()}


func from_dict(data: Dictionary) -> void:
	if infinite:
		explored_chunks.clear()
		for key: String in data.get("chunks", {}):
			var parts: PackedStringArray = key.split(",")
			explored_chunks[Vector2i(int(parts[0]), int(parts[1]))] = Marshalls.base64_to_raw(str(data["chunks"][key]))
	else:
		explored = Marshalls.base64_to_raw(str(data["explored"])).decompress(int(data["size"]), FileAccess.COMPRESSION_ZSTD)
	refresh()
