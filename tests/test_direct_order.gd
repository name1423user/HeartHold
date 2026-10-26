extends GutTest

var village: Village


func before_each() -> void:
	village = Village.create(12345)


func test_order_interrupts_job_and_returns_after_arrival() -> void:
	var a: Villager = village.add_villager("ハンス")
	var tree: Vector2i = village.world.start + Vector2i(8, 0)
	village.world.trees[tree] = true
	village.pathing.update_cell(tree)
	Designation.chop_area(village, Rect2i(tree, Vector2i(1, 1)))
	village.tick(1.0)
	assert_eq(a.plan_kind, "task", "伐採を始めている")
	var task: JobTask = village.tasks.of_type("chop")[0]

	var x: Vector2i = village.world.start + Vector2i(-6, -6)
	assert_true(DirectOrder.move(village, a, x)["ok"])
	assert_eq(task.assigned, -1, "仕事は中断されてキューに戻る")
	assert_eq(a.plan_kind, "order")
	for i in 30:
		village.tick(0.5)
		if a.plan_kind != "order":
			break
	assert_eq(a.cell(), x, "Xに着いた")
	village.tick(0.5)
	assert_eq(a.plan_kind, "task", "着いたら役職の仕事へ戻る")
	assert_eq(a.task_id, task.id)


func test_unreachable_order_is_refused() -> void:
	var a: Villager = village.add_villager("アンナ")
	var river := Vector2i(-1, -1)
	for z in village.world.size.z:
		for x in village.world.size.x:
			if village.world.biome_at(Vector2i(x, z)) == WorldData.Biome.RIVER:
				river = Vector2i(x, z)
				break
		if river.x >= 0:
			break
	var result: Dictionary = DirectOrder.move(village, a, river)
	assert_false(result["ok"])
	assert_eq(result["message"], "そこへは行けません")
	assert_ne(a.plan_kind, "order")
