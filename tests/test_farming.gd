extends GutTest

var village: Village
var farming: Farming
var storage: Building


func before_each() -> void:
	village = Village.create(12345)
	farming = village.system("farming") as Farming
	storage = village.add_building("storage", village.world.start + Vector2i(4, 4), true)
	storage.inventory = {"smoked_meat": 60}


func test_field_sow_grow_harvest() -> void:
	var field: Building = village.add_building("field", village.world.start + Vector2i(-8, 4), true)
	assert_true(village.world.is_walkable(field.cell), "畑の上は歩ける")
	var farmer: Villager = village.add_villager("農夫")
	Job.assign(village, farmer, "farmer")
	for i in 24:
		village.tick(30.0)
		if farming.fields[field.id]["stage"] == "growing":
			break
	assert_eq(farming.fields[field.id]["stage"], "growing", "種をまく")
	for i in 10 * 24:
		village.tick(60.0)
		if int(storage.inventory.get("wheat", 0)) > 0:
			break
	assert_eq(int(storage.inventory.get("wheat", 0)), 8, "実って収穫し、倉庫へ")
	assert_eq(int(storage.inventory.get("hay", 0)), 4)


func test_winter_kills_growing_crops() -> void:
	var field: Building = village.add_building("field", village.world.start + Vector2i(-8, 4), true)
	farming.fields[field.id]["stage"] = "growing"
	village.clock.minutes = 21.0 * 1440.0 + 60.0
	watch_signals(village)
	farming.update(1.0)
	assert_eq(farming.fields[field.id]["stage"], "empty")
	assert_signal_emitted(village, "alert_raised")


func test_barn_animals_need_hay_and_give_eggs_and_wool() -> void:
	var barn: Building = village.add_building("barn", village.world.start + Vector2i(-10, -8), true)
	storage.inventory["hay"] = 40
	var herder: Villager = village.add_villager("牧夫")
	Job.assign(village, herder, "herder")
	for i in 8 * 24:
		village.tick(60.0)
	assert_gt(int(storage.inventory.get("egg", 0)) + int(storage.inventory.get("wool", 0)), 0, "卵や羊毛が倉庫へ")
	assert_lt(int(storage.inventory.get("hay", 0)), 40, "干し草を食べる")


func test_unfed_animals_die() -> void:
	var barn: Building = village.add_building("barn", village.world.start + Vector2i(-10, -8), true)
	var before: int = int(farming.barns[barn.id]["animals"]["chicken"])
	village.tick(6.0 * 1440.0)
	assert_lt(int(farming.barns[barn.id]["animals"]["chicken"]), before)
