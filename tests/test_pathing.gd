extends GutTest

var world: WorldData
var pathing: Pathing


func before_all() -> void:
	world = TerrainGenerator.generate(12345)
	pathing = Pathing.new(world)


func test_path_inside_start_area() -> void:
	var path: Array[Vector2i] = pathing.find_path(world.start, world.start + Vector2i(10, 5))
	assert_eq(path.size(), 16, "マンハッタン距離15 + 始点")
	assert_eq(path[-1], world.start + Vector2i(10, 5))


func test_wall_blocks_and_reopens() -> void:
	var editor := TerrainEditor.new(world)
	editor.block_changed.connect(func(pos: Vector3i, _id: int) -> void: pathing.update_cell(Vector2i(pos.x, pos.z)))
	var target: Vector2i = world.start + Vector2i(3, 0)
	var top: int = world.top_y(target)
	# 高さ2の柱を立てると、その列には登れない
	editor.place_block(Vector3i(target.x, top + 1, target.y), world.block_id("stone"))
	editor.place_block(Vector3i(target.x, top + 2, target.y), world.block_id("stone"))
	assert_false(pathing.is_reachable(world.start, target))
	editor.break_block(Vector3i(target.x, top + 2, target.y))
	editor.break_block(Vector3i(target.x, top + 1, target.y))
	assert_true(pathing.is_reachable(world.start, target))


func test_water_is_not_walkable() -> void:
	for z in world.size.z:
		for x in world.size.x:
			if world.biome_at(Vector2i(x, z)) == WorldData.Biome.RIVER:
				assert_false(pathing.is_reachable(world.start, Vector2i(x, z)))
				return
