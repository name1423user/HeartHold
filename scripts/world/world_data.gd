class_name WorldData
extends RefCounted
## ブロック地形の中身。VoxelBuffer と同じ並び(y が最も速く、次に x、最後に z)で持つ。
## 決まった大きさの地図は配列ひとつで持つ。無限の地図(M11-T04)はチャンク(chunk_size×chunk_size の列)ごとに持ち、
## ensure_chunk で必要になった所だけ作る。作っていない所は空気で、歩けない。

enum Biome { GRASSLAND, FOREST, MOUNTAIN, RIVER }

## チャンクができた(経路探索・木の表示が追いかける)
signal chunk_generated(chunk: Vector2i)

var seed: int = 0
## 決まった大きさの地図の大きさ。無限の地図では最初に作る範囲
var size: Vector3i = Vector3i.ZERO
var blocks: PackedByteArray = PackedByteArray()
var biomes: PackedByteArray = PackedByteArray()
## 列ごとの一番上の空気でないブロックの y
var top: PackedInt32Array = PackedInt32Array()
## 生成直後の top。掘れる深さの基準(AS-003)
var original_top: PackedInt32Array = PackedInt32Array()
## 木が立っている列。Vector2i(x, z) -> true
var trees: Dictionary = {}
## 建物などでふさがれた列。Vector2i(x, z) -> 建物ID
var blocked: Dictionary = {}
var start: Vector2i = Vector2i.ZERO
var shape: TerrainShape

var air_id: int = 0
var water_id: int = 0

## 無限の地図か
var infinite: bool = false
var chunk_size: int = 32
## 座標の上限(絶対値)
var limit: int = 65536
## チャンク: Vector2i -> {"blocks", "biomes", "top", "original_top"}
var chunks: Dictionary = {}
## 無限の地図で変えたブロック(表示の生成スレッドが読むので mutex で守る)。Vector2i(チャンク) -> {Vector3i: id}
var edits: Dictionary = {}
var edit_mutex := Mutex.new()


func _init() -> void:
	var data: Dictionary = GameData.get_dict("terrain")
	var ids: Dictionary = data.get("blocks", {})
	air_id = int(ids.get("air", 0))
	water_id = int(ids.get("water", 0))
	var inf: Dictionary = data.get("infinite", {})
	chunk_size = int(inf.get("chunk", 32))
	limit = int(inf.get("limit", 65536))


func block_id(name: String) -> int:
	var ids: Dictionary = GameData.get_dict("terrain").get("blocks", {})
	return int(ids.get(name, air_id))


## 列の番号(経路探索の点の ID にも使う)。無限の地図では座標から決まる大きな数
func column_index(x: int, z: int) -> int:
	if infinite:
		return (z + limit) * (limit * 2) + (x + limit)
	return z * size.x + x


func in_bounds(pos: Vector3i) -> bool:
	return in_bounds_2d(Vector2i(pos.x, pos.z)) and pos.y >= 0 and pos.y < size.y


func in_bounds_2d(cell: Vector2i) -> bool:
	if infinite:
		return absi(cell.x) < limit and absi(cell.y) < limit
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.z


# --- チャンク(無限の地図) ---------------------------------------------------

func chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / chunk_size), floori(float(cell.y) / chunk_size))


func has_chunk(chunk: Vector2i) -> bool:
	return chunks.has(chunk)


## その列のデータがあるか(決まった大きさの地図では範囲内なら常にある)
func has_column(cell: Vector2i) -> bool:
	if not infinite:
		return in_bounds_2d(cell)
	return chunks.has(chunk_of(cell))


func ensure_chunk(chunk: Vector2i) -> bool:
	if not infinite or chunks.has(chunk):
		return false
	var count: int = chunk_size * chunk_size
	var chunk_blocks := PackedByteArray()
	var chunk_biomes := PackedByteArray()
	var chunk_top := PackedInt32Array()
	chunk_biomes.resize(count)
	chunk_top.resize(count)
	var origin: Vector2i = chunk * chunk_size
	for lz in chunk_size:
		for lx in chunk_size:
			var x: int = origin.x + lx
			var z: int = origin.y + lz
			var info: Dictionary = shape.column(x, z)
			chunk_blocks.append_array(shape.column_bytes(info))
			var i: int = lz * chunk_size + lx
			chunk_biomes[i] = int(info["biome"])
			chunk_top[i] = maxi(int(info["h"]), int(info["water_top"]))
			if info["tree"]:
				trees[Vector2i(x, z)] = true
	var data: Dictionary = {"blocks": chunk_blocks, "biomes": chunk_biomes, "top": chunk_top, "original_top": chunk_top.duplicate()}
	chunks[chunk] = data
	# 前に変えたブロック(ロードしたセーブ)があればかけ直す
	edit_mutex.lock()
	var changed: Dictionary = (edits.get(chunk, {}) as Dictionary).duplicate()
	edit_mutex.unlock()
	for pos: Vector3i in changed:
		_set_in_chunk(data, pos, int(changed[pos]))
	chunk_generated.emit(chunk)
	return true


## cell のまわり radius ブロックぶんのチャンクを作る。作った数を返す
func ensure_area(cell: Vector2i, radius: int) -> int:
	if not infinite:
		return 0
	var made: int = 0
	var lo: Vector2i = chunk_of(cell - Vector2i(radius, radius))
	var hi: Vector2i = chunk_of(cell + Vector2i(radius, radius))
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			if ensure_chunk(Vector2i(cx, cz)):
				made += 1
	return made


func _local(cell: Vector2i) -> int:
	return posmod(cell.y, chunk_size) * chunk_size + posmod(cell.x, chunk_size)


func _set_in_chunk(data: Dictionary, pos: Vector3i, id: int) -> void:
	var column: int = _local(Vector2i(pos.x, pos.z))
	var b: PackedByteArray = data["blocks"]
	b[column * size.y + pos.y] = id
	data["blocks"] = b
	var t: PackedInt32Array = data["top"]
	if id != air_id and pos.y > t[column]:
		t[column] = pos.y
	elif id == air_id and pos.y == t[column]:
		var y: int = pos.y
		while y > 0 and b[column * size.y + y] == air_id:
			y -= 1
		t[column] = y
	data["top"] = t


## 無限の地図で変えたブロックの一覧(セーブ用): [[x, y, z, id]]
func edit_list() -> Array:
	var out: Array = []
	edit_mutex.lock()
	for chunk: Vector2i in edits:
		for pos: Vector3i in edits[chunk]:
			out.append([pos.x, pos.y, pos.z, int(edits[chunk][pos])])
	edit_mutex.unlock()
	return out


## セーブから: 変えたブロックを戻す(できているチャンクにはすぐかけ、まだのチャンクは作るときにかける)
func apply_edit_list(list: Array) -> void:
	for entry: Array in list:
		var pos := Vector3i(int(entry[0]), int(entry[1]), int(entry[2]))
		var chunk: Vector2i = chunk_of(Vector2i(pos.x, pos.z))
		edit_mutex.lock()
		if not edits.has(chunk):
			edits[chunk] = {}
		edits[chunk][pos] = int(entry[3])
		edit_mutex.unlock()
		if chunks.has(chunk):
			_set_in_chunk(chunks[chunk], pos, int(entry[3]))


## 表示の生成スレッドから: そのチャンクで変えたブロック
func edits_in_chunk(chunk: Vector2i) -> Dictionary:
	edit_mutex.lock()
	var copy: Dictionary = (edits.get(chunk, {}) as Dictionary).duplicate()
	edit_mutex.unlock()
	return copy


# --- ブロック -------------------------------------------------------------

func get_block(pos: Vector3i) -> int:
	if not in_bounds(pos):
		return air_id
	if infinite:
		var data: Dictionary = chunks.get(chunk_of(Vector2i(pos.x, pos.z)), {})
		if data.is_empty():
			return air_id
		return (data["blocks"] as PackedByteArray)[_local(Vector2i(pos.x, pos.z)) * size.y + pos.y]
	return blocks[column_index(pos.x, pos.z) * size.y + pos.y]


func set_block(pos: Vector3i, id: int) -> void:
	if infinite:
		var chunk: Vector2i = chunk_of(Vector2i(pos.x, pos.z))
		ensure_chunk(chunk)
		_set_in_chunk(chunks[chunk], pos, id)
		edit_mutex.lock()
		if not edits.has(chunk):
			edits[chunk] = {}
		edits[chunk][pos] = id
		edit_mutex.unlock()
		return
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
	if infinite:
		var data: Dictionary = chunks.get(chunk_of(cell), {})
		return 0 if data.is_empty() else (data["top"] as PackedInt32Array)[_local(cell)]
	return top[column_index(cell.x, cell.y)]


func original_top_y(cell: Vector2i) -> int:
	if infinite:
		var data: Dictionary = chunks.get(chunk_of(cell), {})
		return 0 if data.is_empty() else (data["original_top"] as PackedInt32Array)[_local(cell)]
	return original_top[column_index(cell.x, cell.y)]


func biome_at(cell: Vector2i) -> int:
	if infinite:
		var data: Dictionary = chunks.get(chunk_of(cell), {})
		return Biome.GRASSLAND if data.is_empty() else (data["biomes"] as PackedByteArray)[_local(cell)]
	return biomes[column_index(cell.x, cell.y)]


## 村人が立てる列か(一番上が水でない)。木の列も立てない。無限の地図のまだ作っていない所も立てない
func is_walkable(cell: Vector2i) -> bool:
	if not in_bounds_2d(cell) or trees.has(cell) or blocked.has(cell) or not has_column(cell):
		return false
	return get_block(Vector3i(cell.x, top_y(cell), cell.y)) != water_id
