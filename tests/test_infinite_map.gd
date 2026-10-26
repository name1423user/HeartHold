extends GutTest
## M11-T04: マップの無限生成(チャンク単位)

const DIR: String = "user://test_infinite_saves"


func after_each() -> void:
	var dir := DirAccess.open(DIR)
	if dir != null:
		for file in dir.get_files():
			dir.remove(file)
	SaveGame.directory_override = ""


func test_same_terrain_regardless_of_chunk_order() -> void:
	var finite: WorldData = TerrainGenerator.generate(12345)
	var a: WorldData = TerrainGenerator.generate_infinite(12345)
	for cell in [Vector2i(5, 7), Vector2i(128, 128), Vector2i(200, 31), Vector2i(255, 255)]:
		for y in range(0, 40, 3):
			var pos := Vector3i(cell.x, y, cell.y)
			assert_eq(a.get_block(pos), finite.get_block(pos), "決まった大きさの地図と同じ %s" % pos)
	var b: WorldData = TerrainGenerator.generate_infinite(12345)
	b.ensure_chunk(Vector2i(12, -3))
	a.ensure_chunk(Vector2i(11, -3))
	a.ensure_chunk(Vector2i(12, -3))
	for x in range(384, 416, 5):
		for z in range(-96, -64, 5):
			assert_eq(a.top_y(Vector2i(x, z)), b.top_y(Vector2i(x, z)), "作る順番によらない")


func test_world_grows_where_villagers_walk_and_paths_cross_chunks() -> void:
	var village: Village = Village.create(12345, true)
	var before: int = village.world.chunks.size()
	assert_eq(before, 64, "最初は 256×256 ぶん")
	var outside := Vector2i(300, 128)
	assert_false(village.world.has_column(outside))
	var v: Villager = village.add_villager("探検家")
	v.place_at(Vector2i(250, 128) if village.world.is_walkable(Vector2i(250, 128)) else village.pathing.nearest_standable(Vector2i(250, 128), Vector2i(250, 128)))
	village.tick(10.0)
	assert_gt(village.world.chunks.size(), before, "村人のまわりが広がる")
	assert_true(village.world.has_column(outside))
	var far: Vector2i = village.pathing.nearest_standable(v.cell(), outside)
	if far != Village.NO_CELL:
		assert_false(village.pathing.find_path(v.cell(), far).is_empty(), "チャンクの境目をまたいで歩ける")
	village.dispose()


func test_far_lands_have_noise_features() -> void:
	var world: WorldData = TerrainGenerator.generate_infinite(777)
	var seen: Dictionary = {}
	for cz in range(-12, 12, 3):
		for cx in range(-12, 12, 3):
			world.ensure_chunk(Vector2i(cx, cz))
	for key: Vector2i in world.chunks:
		var origin: Vector2i = key * world.chunk_size
		for i in range(0, world.chunk_size, 4):
			for j in range(0, world.chunk_size, 4):
				seen[world.biome_at(origin + Vector2i(i, j))] = true
	for biome in WorldData.Biome.values():
		assert_true(seen.has(biome), "遠くにも地形の種類がある %d" % biome)


func test_infinite_save_and_load() -> void:
	SaveGame.directory_override = DIR
	var village: Village = Village.new_game(12345, true)
	village.world.ensure_chunk(Vector2i(10, 4))
	var cell := Vector2i(330, 140)
	var top: int = village.world.top_y(cell)
	village.editor.break_block(Vector3i(cell.x, top, cell.y))
	village.fog.refresh()
	assert_eq(SaveGame.save_village(village, "inf"), OK)
	var loaded: Village = SaveGame.load_village("inf")
	assert_not_null(loaded)
	assert_true(loaded.world.infinite)
	assert_true(loaded.world.has_chunk(Vector2i(10, 4)), "作ったチャンクが戻る")
	assert_eq(loaded.world.top_y(cell), top - 1, "変えたブロックが戻る")
	assert_eq(loaded.fog.explored_count(), village.fog.explored_count(), "霧が戻る")
	village.dispose()
	loaded.dispose()
