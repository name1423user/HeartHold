extends GutTest


func test_same_seed_gives_same_blocks() -> void:
	var a: WorldData = TerrainGenerator.generate(12345)
	var b: WorldData = TerrainGenerator.generate(12345)
	assert_eq(a.blocks.size(), 256 * 256 * 64)
	assert_true(a.blocks == b.blocks, "全ブロックが一致する")
	assert_eq(a.trees.keys(), b.trees.keys())


func test_different_seed_differs() -> void:
	var a: WorldData = TerrainGenerator.generate(12345)
	var b: WorldData = TerrainGenerator.generate(54321)
	assert_false(a.blocks == b.blocks)


func test_has_all_biomes_and_flat_start() -> void:
	for seed in [1, 12345, 999999]:
		var world: WorldData = TerrainGenerator.generate(seed)
		var counts: Dictionary = {}
		for b in world.biomes:
			counts[b] = int(counts.get(b, 0)) + 1
		for biome in WorldData.Biome.values():
			assert_gt(int(counts.get(biome, 0)), 0, "seed %d biome %d" % [seed, biome])
		assert_gt(world.trees.size(), 0)

		var radius: int = int(GameData.get_dict("terrain")["start_radius"])
		var start_height: int = world.top_y(world.start)
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if dx * dx + dz * dz > radius * radius:
					continue
				var cell: Vector2i = world.start + Vector2i(dx, dz)
				assert_true(world.is_walkable(cell))
				if world.top_y(cell) != start_height:
					fail_test("開始地点が平らでない: %s" % cell)
					return
