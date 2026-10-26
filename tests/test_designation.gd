extends GutTest

var village: Village


func before_each() -> void:
	village = Village.create(12345)


func _forest_area() -> Rect2i:
	# 開始地点から一番近い木の周り 8×8
	var nearest: Vector2i = village.world.trees.keys()[0]
	for cell: Vector2i in village.world.trees:
		if cell.distance_squared_to(village.world.start) < nearest.distance_squared_to(village.world.start):
			nearest = cell
	return Rect2i(nearest - Vector2i(4, 4), Vector2i(8, 8))


func test_chop_area_cuts_every_tree_and_logs_reach_storage() -> void:
	var storage: Building = village.add_building("storage", village.world.start + Vector2i(4, 4), true)
	village.add_villager("ハンス").job = "gatherer"
	var area: Rect2i = _forest_area()
	var trees_in_area: int = 0
	for cell: Vector2i in village.world.trees:
		if area.has_point(cell):
			trees_in_area += 1
	assert_eq(Designation.chop_area(village, area), trees_in_area)
	for i in 72:
		village.tick(60.0)
		if village.tasks.of_type("chop").is_empty() and storage.stored_total() >= trees_in_area * 2:
			break
	for cell: Vector2i in village.world.trees:
		assert_false(area.has_point(cell), "範囲内の木が残っている: %s" % cell)
	var logs_per_tree: int = int(GameData.get_dict("resources")["logs_per_tree"])
	assert_eq(int(storage.inventory.get("log", 0)), trees_in_area * logs_per_tree, "原木が倉庫に入る")


func test_digging_fifth_level_is_rejected_with_message() -> void:
	var cell: Vector2i = village.world.start
	var top: int = village.world.top_y(cell)
	var result: Dictionary = Designation.dig_block(village, Vector3i(cell.x, top - 4, cell.y))
	assert_false(result["ok"])
	assert_eq(result["message"], "これ以上は掘れません")
	assert_true(Designation.dig_block(village, Vector3i(cell.x, top, cell.y))["ok"])


func test_dig_area_is_carried_out() -> void:
	village.add_villager("アンナ")
	var area := Rect2i(village.world.start + Vector2i(2, 2), Vector2i(2, 2))
	var before: int = village.world.top_y(area.position)
	assert_eq(Designation.dig_area(village, area)["created"], 4)
	village.tick(240.0)
	assert_eq(village.world.top_y(area.position), before - 1)
	assert_true(village.tasks.of_type("dig").is_empty())


func test_dig_area_too_deep_reports_message() -> void:
	var cell: Vector2i = village.world.start
	for i in 4:
		village.editor.break_block(Vector3i(cell.x, village.world.top_y(cell), cell.y))
	var result: Dictionary = Designation.dig_area(village, Rect2i(cell, Vector2i(1, 1)))
	assert_eq(result["created"], 0)
	assert_eq(result["message"], "これ以上は掘れません")


func test_unreachable_task_is_put_on_hold() -> void:
	village.add_villager("クララ")
	var target: Vector2i = village.world.start + Vector2i(6, 0)
	village.world.trees[target] = true
	# 木の周りを全部ふさぐ
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c: Vector2i = target + Vector2i(dx, dz)
			if c != target:
				village.world.blocked[c] = 999
				village.pathing.update_cell(c)
	Designation.chop_area(village, Rect2i(target, Vector2i(1, 1)))
	village.tick(5.0)
	var task: JobTask = village.tasks.of_type("chop")[0]
	assert_eq(Designation.status_text(task), "行けません")
	assert_eq(task.assigned, -1)
