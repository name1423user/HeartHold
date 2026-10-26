extends GutTest

var village: Village
var storage: Building
var house: Building


func before_each() -> void:
	village = Village.create(12345)
	storage = village.add_building("storage", village.world.start + Vector2i(3, 3), true)
	house = village.add_building("house", village.world.start + Vector2i(-6, -6), true)


func _run_until(hours: int, done: Callable) -> void:
	for i in hours * 6:
		village.tick(10.0)
		if done.call():
			return


func test_new_house_has_straw_beds_and_infirmary_two_cots() -> void:
	assert_eq(house.fixtures, ["straw_bed", "straw_bed"])
	var infirmary: Building = village.add_building("infirmary", village.world.start + Vector2i(6, -6), true)
	assert_eq(infirmary.fixtures.count("infirmary_bed"), 2)


func test_options_list_materials_and_limits() -> void:
	var options: Array[Dictionary] = BuildingFixture.options(house)
	var by_id: Dictionary = {}
	for o in options:
		by_id[o["id"]] = o
	assert_eq(by_id["wooden_bed"]["materials"], {"plank": 6.0, "fur": 2.0})
	assert_true(by_id["wooden_bed"]["ok"])
	assert_false(by_id["straw_bed"]["ok"], "わら寝床は住人数まで埋まっている")
	assert_eq(by_id["straw_bed"]["reason"], "これ以上は置けません")


func test_builder_installs_wooden_bed_and_sleep_recovers_faster() -> void:
	storage.inventory = {"plank": 6, "fur": 2}
	var v: Villager = village.add_villager("ハンス")
	Job.assign(village, v, "builder")
	assert_eq(v.home_id, house.id)
	assert_true(BuildingFixture.order(village, house, "wooden_bed")["ok"])
	_run_until(6, func() -> bool: return house.fixtures.has("wooden_bed"))
	assert_true(house.fixtures.has("wooden_bed"))
	assert_eq(house.fixtures.count("straw_bed"), 1, "わら寝床1つを置き換える")
	assert_eq(storage.stored_total(), 0, "素材を運んで使った")
	assert_almost_eq(BuildingFixture.bed_multiplier_for(village, house, v), 1.3, 0.0001, "睡眠の回復が1.3倍")


func test_decoration_raises_mood_rate_and_housing_bonus_with_limit() -> void:
	var v: Villager = village.add_villager("アンナ")
	var before: float = village.mood_rate(v)
	house.fixtures.append("wall_decoration")
	assert_almost_eq(village.mood_rate(v), before + 0.1, 0.0001, "気分の回復 +10%")
	assert_eq(BuildingFixture.sum_effect(house, "housing_score"), 5.0, "審査の住居点 +5")
	house.fixtures.append("wall_decoration")
	assert_false(BuildingFixture.order(village, house, "wall_decoration")["ok"], "上限2")
