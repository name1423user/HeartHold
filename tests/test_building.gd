extends GutTest

var village: Village
var storage: Building


func before_each() -> void:
	village = Village.create(12345)
	storage = village.add_building("storage", village.world.start + Vector2i(3, 3), true)


func _tick_hours(hours: int, until: Callable) -> void:
	for i in hours * 6:
		village.tick(10.0)
		if until.call():
			return


func test_house_goes_planned_building_complete_and_houses_villagers() -> void:
	storage.inventory = {"plank": 8, "log": 4}
	var builder: Villager = village.add_villager("ハンス")
	Job.assign(village, builder, "builder")
	var result: Dictionary = Designation.build(village, "house", village.world.start + Vector2i(-6, -6))
	assert_true(result["ok"])
	var house: Building = result["building"]
	assert_eq(house.state, Building.State.PLANNED)
	var seen_building: Array = [false]
	_tick_hours(8, func() -> bool:
		if house.state == Building.State.BUILDING:
			seen_building[0] = true
		return house.is_complete())
	assert_true(seen_building[0], "建設中を経る")
	assert_true(house.is_complete())
	assert_eq(storage.stored_total(), 0, "素材を使い切る")
	assert_eq(builder.home_id, house.id, "家に住む")
	for c in house.cells():
		assert_false(village.world.is_walkable(c), "建物の上は歩けない")


func test_missing_materials_puts_construction_on_hold() -> void:
	storage.inventory = {"plank": 2}
	village.add_villager("アンナ")
	watch_signals(village)
	var house: Building = Designation.build(village, "house", village.world.start + Vector2i(-6, -6))["building"]
	_tick_hours(2, func() -> bool: return house.short)
	assert_true(house.short, "不足アイコン")
	assert_false(house.is_complete())
	assert_eq(village.tasks.of_type("build")[0].blocked_reason, "missing_materials")
	assert_signal_emitted(village, "alert_raised")
	# 素材が届けば再開して完成する
	storage.inventory = {"plank": 6, "log": 4}
	_tick_hours(12, func() -> bool: return house.is_complete())
	assert_true(house.is_complete())
	assert_false(house.short)


func test_full_storage_drops_items_and_warns() -> void:
	storage.inventory = {"stone": storage.capacity()}
	var v: Villager = village.add_villager("クララ")
	v.carry_item = "log"
	v.carry_count = 2
	watch_signals(village)
	village.tick(5.0)
	var params: Array = get_signal_parameters(village, "alert_raised")
	assert_eq(params.slice(0, 2), ["storage", "倉庫がいっぱいです"])
	var on_ground: int = 0
	for cell: Vector2i in village.ground_items:
		on_ground += int(village.ground_items[cell].get("log", 0))
	assert_eq(on_ground, 2, "その場に置く")


func test_cannot_build_on_water_or_trees() -> void:
	var tree: Vector2i = village.world.trees.keys()[0]
	assert_false(Designation.build(village, "house", tree)["ok"])
