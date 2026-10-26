class_name TerrainGenerator
extends RefCounted
## シードから草原・森・岩山・川のある地形を作る(AC-001, AC-002)。数値は data/terrain.json。
## 形は TerrainShape が列ごとに決める。決まった大きさ(256×256)の地図と、チャンク単位で広がる無限の地図(M11-T04)。


static func generate(seed: int) -> WorldData:
	var cfg: Dictionary = GameData.get_dict("terrain")
	var world := WorldData.new()
	world.seed = seed
	var s: Array = cfg["size"]
	world.size = Vector3i(int(s[0]), int(s[1]), int(s[2]))
	world.start = Vector2i(world.size.x / 2, world.size.z / 2)
	world.shape = TerrainShape.new(seed, world.start)
	var templates: Dictionary = {}
	var column_count: int = world.size.x * world.size.z
	world.biomes.resize(column_count)
	world.top.resize(column_count)
	for z in world.size.z:
		for x in world.size.x:
			var info: Dictionary = world.shape.column(x, z)
			var ores: Dictionary = info["ores"]
			if ores.is_empty():
				var key := Vector3i(int(info["h"]), int(info["top"]), int(info["water_top"]))
				if not templates.has(key):
					templates[key] = world.shape.column_bytes(info)
				world.blocks.append_array(templates[key])
			else:
				world.blocks.append_array(world.shape.column_bytes(info))
			var column: int = world.column_index(x, z)
			world.biomes[column] = int(info["biome"])
			world.top[column] = maxi(int(info["h"]), int(info["water_top"]))
			if info["tree"]:
				world.trees[Vector2i(x, z)] = true
	world.original_top = world.top.duplicate()
	return world


## 無限の地図。最初は開始地点のまわりの 256×256 ぶんのチャンクだけ作り、あとは村人やカメラが近づいたら作る
static func generate_infinite(seed: int) -> WorldData:
	var cfg: Dictionary = GameData.get_dict("terrain")
	var world := WorldData.new()
	world.infinite = true
	world.seed = seed
	var s: Array = cfg["size"]
	world.size = Vector3i(int(s[0]), int(s[1]), int(s[2]))
	world.start = Vector2i(world.size.x / 2, world.size.z / 2)
	world.shape = TerrainShape.new(seed, world.start)
	var chunk: int = world.chunk_size
	for cz in range(0, world.size.z / chunk):
		for cx in range(0, world.size.x / chunk):
			world.ensure_chunk(Vector2i(cx, cz))
	return world
