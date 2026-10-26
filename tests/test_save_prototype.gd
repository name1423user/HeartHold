extends GutTest

const PATH: String = "user://test_save_prototype"


func after_all() -> void:
	DirAccess.remove_absolute(PATH + ".terrain")
	DirAccess.remove_absolute(PATH + ".json")


func test_round_trip_1000_edits_and_30_villagers() -> void:
	var world: WorldData = TerrainGenerator.generate(12345)
	var editor := TerrainEditor.new(world)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var edits: int = 0
	while edits < 1000:
		var cell := Vector2i(rng.randi_range(0, 255), rng.randi_range(0, 255))
		var top: int = world.top_y(cell)
		var result: Dictionary
		if rng.randf() < 0.5:
			result = editor.break_block(Vector3i(cell.x, top, cell.y))
		else:
			result = editor.place_block(Vector3i(cell.x, top + 1, cell.y), world.block_id("stone"))
		if result["ok"]:
			edits += 1
	var villagers: Array = []
	for i in 30:
		villagers.append({"id": i, "cell": [rng.randi_range(0, 255), rng.randi_range(0, 255)], "needs": {"food": rng.randf(), "sleep": rng.randf(), "mood": rng.randf(), "health": rng.randf()}})

	assert_eq(SavePrototype.save(PATH, world, villagers), OK)
	var started: int = Time.get_ticks_msec()
	var loaded: Dictionary = SavePrototype.load_game(PATH)
	var load_ms: int = Time.get_ticks_msec() - started
	gut.p("ロード時間: %d ms" % load_ms)
	assert_lt(load_ms, 10000, "ロードは10秒以内")
	var restored: WorldData = loaded["world"]
	assert_true(restored.blocks == world.blocks, "全ブロックが一致")
	assert_true(restored.top == world.top, "地表の高さが一致")
	assert_eq(restored.trees.size(), world.trees.size())
	var restored_villagers: Array = loaded["villagers"]
	assert_eq(restored_villagers.size(), 30)
	for i in villagers.size():
		var a: Dictionary = villagers[i]
		var b: Dictionary = restored_villagers[i]
		assert_eq(int(b["id"]), a["id"])
		assert_eq(Vector2i(int(b["cell"][0]), int(b["cell"][1])), Vector2i(a["cell"][0], a["cell"][1]), "位置が一致")
		for key: String in a["needs"]:
			assert_almost_eq(float(b["needs"][key]), float(a["needs"][key]), 1e-9, "欲求 %s が一致" % key)
