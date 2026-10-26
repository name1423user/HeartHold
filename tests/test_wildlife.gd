extends GutTest

var village: Village
var storage: Building


func before_each() -> void:
	village = Village.create(12345)
	storage = village.add_building("storage", village.world.start + Vector2i(3, 3), true)


func test_rabbits_roam() -> void:
	assert_eq(village.wildlife.animals.size(), int(GameData.get_dict("wildlife")["rabbit"]["count"]))
	var id: int = village.wildlife.animals.keys()[0]
	var before: Vector2 = village.wildlife.animals[id]["pos"]
	village.tick(120.0)
	assert_ne(village.wildlife.animals[id]["pos"], before, "うろつく")


func test_hunter_brings_meat_and_fur_then_meal_is_cooked() -> void:
	village.add_building("workbench", village.world.start + Vector2i(-4, 3), true)
	var hunter: Villager = village.add_villager("ルーカス")
	Job.assign(village, hunter, "hunter")
	var rabbits_before: int = village.wildlife.animals.size()
	for i in 72:
		village.tick(10.0)
		if storage.inventory.get("meat", 0) > 0 and storage.inventory.get("fur", 0) > 0:
			break
	assert_lt(village.wildlife.animals.size(), rabbits_before, "ウサギを狩った")
	assert_gt(int(storage.inventory.get("meat", 0)), 0, "肉が倉庫に入る")
	assert_gt(int(storage.inventory.get("fur", 0)), 0, "毛皮が倉庫に入る")

	var meat: int = int(storage.inventory["meat"])
	Job.assign(village, hunter, "gatherer")
	Crafting.order(village, "meal")
	for i in 36:
		village.tick(10.0)
		if storage.inventory.get("meal", 0) > 0:
			break
	assert_eq(int(storage.inventory.get("meal", 0)), 1, "肉 → 料理")
	assert_eq(int(storage.inventory.get("meat", 0)), meat - 1)
