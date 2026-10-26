extends GutTest

var village: Village


func before_each() -> void:
	village = Village.create(12345)


func _carry_and_run(v: Villager, item: String, count: int) -> void:
	v.carry_item = item
	v.carry_count = count
	for i in 12:
		village.tick(2.0)
		if v.carry_count == 0:
			return


func test_food_only_storage_gets_only_food() -> void:
	var a: Building = village.add_building("storage", village.world.start + Vector2i(3, 3), true)
	var b: Building = village.add_building("storage", village.world.start + Vector2i(-6, 3), true)
	Stockpile.set_filter(a, ["food"])
	Stockpile.set_priority(a, 2)
	var v: Villager = village.add_villager("ハンス")
	_carry_and_run(v, "meat", 3)
	_carry_and_run(v, "log", 4)
	assert_eq(a.inventory, {"meat": 3}, "食料だけがAへ")
	assert_eq(b.inventory, {"log": 4}, "他の物は別の倉庫へ")
	assert_eq(Stockpile.filter_label(a), "食料")


func test_no_accepting_storage_warns() -> void:
	var a: Building = village.add_building("storage", village.world.start + Vector2i(3, 3), true)
	Stockpile.set_filter(a, ["food"])
	var v: Villager = village.add_villager("アンナ")
	watch_signals(village)
	_carry_and_run(v, "stone", 2)
	assert_eq(AlertsHelper.find(self, village, "storage").slice(0, 2), ["storage", "置き場所がありません"])
	assert_true(a.inventory.is_empty())


func test_higher_priority_fills_first() -> void:
	var low: Building = village.add_building("storage", village.world.start + Vector2i(3, 3), true)
	var high: Building = village.add_building("storage", village.world.start + Vector2i(-6, 3), true)
	Stockpile.set_priority(high, 3)
	assert_eq(village.best_stockpile_for("log", 1), high)
	high.inventory = {"stone": high.capacity()}
	assert_eq(village.best_stockpile_for("log", 1), low, "埋まったら次の倉庫")
