extends GutTest

var village: Village
var storage: Building


func before_each() -> void:
	village = Village.create(12345)
	storage = village.add_building("storage", village.world.start + Vector2i(3, 3), true)
	village.add_building("workbench", village.world.start + Vector2i(-4, 3), true)
	village.add_villager("ハンス")


func after_each() -> void:
	GameData._cache.erase("recipes")


func _run_until_idle(max_hours: int) -> void:
	for i in max_hours * 6:
		village.tick(10.0)
		if village.tasks.of_type("craft").is_empty() and village.villagers[0].carry_count == 0:
			return


func test_one_log_becomes_four_planks() -> void:
	storage.inventory["log"] = 1
	assert_eq(Crafting.order(village, "plank"), 1)
	_run_until_idle(4)
	assert_eq(int(storage.inventory.get("log", 0)), 0)
	assert_eq(int(storage.inventory.get("plank", 0)), 4)


func test_three_step_chain_from_data_only() -> void:
	# コードを変えずにデータだけで3段目のレシピを足す
	var recipes: Dictionary = GameData.get_dict("recipes").duplicate(true)
	recipes["fence_bundle"] = {"name": "柵の束", "station": "workbench", "inputs": {"fence_post": 2}, "outputs": {"fence_bundle": 1}, "work": 5.0}
	GameData._cache["recipes"] = recipes
	var items: Dictionary = GameData.get_dict("items").duplicate(true)
	items["fence_bundle"] = {"name": "柵の束", "category": "material"}
	GameData._cache["items"] = items

	storage.inventory["log"] = 1
	Crafting.order(village, "plank")
	_run_until_idle(4)
	Crafting.order(village, "fence_post", 2)
	_run_until_idle(4)
	Crafting.order(village, "fence_bundle")
	_run_until_idle(4)
	assert_eq(int(storage.inventory.get("fence_bundle", 0)), 1, "原木 → 木材 → 柵の杭 → 柵の束")
	assert_eq(int(storage.inventory.get("plank", 0)), 0)
	GameData._cache.erase("items")


func test_missing_input_puts_task_on_hold() -> void:
	Crafting.order(village, "plank")
	village.tick(5.0)
	var task: JobTask = village.tasks.of_type("craft")[0]
	assert_eq(task.blocked_reason, "missing_materials")
