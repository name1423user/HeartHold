class_name SavePrototype
extends RefCounted
## POC-002 の試作。地形は生成し直した元と違うチャンクだけ VoxelBlockSerializer で圧縮して保存し、
## 村人などはJSONで保存する。

const CHUNK: int = 16


static func save(base_path: String, world: WorldData, villagers: Array) -> Error:
	var original: WorldData = TerrainGenerator.generate(world.seed)
	var chunks: Dictionary = {}
	for cz in ceili(world.size.z / float(CHUNK)):
		for cx in ceili(world.size.x / float(CHUNK)):
			for cy in ceili(world.size.y / float(CHUNK)):
				var origin := Vector3i(cx, cy, cz) * CHUNK
				var data: PackedByteArray = _chunk_bytes(world, origin)
				if data != _chunk_bytes(original, origin):
					var buffer := VoxelBuffer.new()
					buffer.create(CHUNK, CHUNK, CHUNK)
					buffer.set_channel_depth(VoxelBuffer.CHANNEL_TYPE, VoxelBuffer.DEPTH_8_BIT)
					buffer.set_channel_from_byte_array(VoxelBuffer.CHANNEL_TYPE, data)
					chunks[origin] = VoxelBlockSerializer.serialize_to_byte_array(buffer, VoxelBlockSerializer.COMPRESSION_ZSTD)
	var terrain_file := FileAccess.open(base_path + ".terrain", FileAccess.WRITE)
	if terrain_file == null:
		return FileAccess.get_open_error()
	terrain_file.store_var(chunks)
	terrain_file.close()

	var trees: Array = []
	for cell: Vector2i in world.trees:
		trees.append([cell.x, cell.y])
	var state: Dictionary = {"seed": world.seed, "trees": trees, "villagers": villagers}
	var json_file := FileAccess.open(base_path + ".json", FileAccess.WRITE)
	if json_file == null:
		return FileAccess.get_open_error()
	json_file.store_string(JSON.stringify(state, "", true, true))
	json_file.close()
	return OK


## 戻り値: {"world": WorldData, "villagers": Array}。読めなければ空の辞書
static func load_game(base_path: String) -> Dictionary:
	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string(base_path + ".json"))
	if not state is Dictionary:
		return {}
	var world: WorldData = TerrainGenerator.generate(int(state["seed"]))
	var terrain_file := FileAccess.open(base_path + ".terrain", FileAccess.READ)
	if terrain_file == null:
		return {}
	var chunks: Variant = terrain_file.get_var()
	if not chunks is Dictionary:
		return {}
	for origin: Vector3i in chunks:
		var buffer := VoxelBuffer.new()
		VoxelBlockSerializer.deserialize_from_byte_array(chunks[origin], buffer, true)
		_apply_chunk(world, origin, buffer.get_channel_as_byte_array(VoxelBuffer.CHANNEL_TYPE))
	world.trees.clear()
	for pair: Array in state["trees"]:
		world.trees[Vector2i(int(pair[0]), int(pair[1]))] = true
	return {"world": world, "villagers": state["villagers"]}


## チャンク内を VoxelBuffer と同じ並び(y、x、z の順)で取り出す
static func _chunk_bytes(world: WorldData, origin: Vector3i) -> PackedByteArray:
	var out := PackedByteArray()
	for z in range(origin.z, origin.z + CHUNK):
		for x in range(origin.x, origin.x + CHUNK):
			var start: int = world.column_index(x, z) * world.size.y + origin.y
			out.append_array(world.blocks.slice(start, start + CHUNK))
	return out


static func _apply_chunk(world: WorldData, origin: Vector3i, data: PackedByteArray) -> void:
	var i: int = 0
	for z in range(origin.z, origin.z + CHUNK):
		for x in range(origin.x, origin.x + CHUNK):
			var column: int = world.column_index(x, z)
			var start: int = column * world.size.y + origin.y
			for y in CHUNK:
				world.blocks[start + y] = data[i]
				i += 1
			var top: int = world.size.y - 1
			while top > 0 and world.blocks[column * world.size.y + top] == world.air_id:
				top -= 1
			world.top[column] = top
