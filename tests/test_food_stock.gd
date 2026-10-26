extends GutTest


func test_days_left_is_total_food_over_daily_use_rounded_down() -> void:
	var village: Village = Village.create(12345)
	var storage: Building = village.add_building("storage", village.world.start + Vector2i(4, 4), true)
	for i in 2:
		village.add_villager("村人%d" % i)
	var per_day: float = float(village.needs_cfg["decay_per_hour"]["food"]) * 24.0 * 2
	storage.inventory = {"meal": 10}
	assert_eq(FoodStock.days_left(village), floori(500.0 / per_day), "料理 50×10 ÷ 2人の1日ぶん")
	storage.inventory = {"meal": 10, "meat": 4, "log": 50}
	assert_eq(FoodStock.days_left(village), floori(600.0 / per_day), "食べ物でない物は数えない")
	assert_eq(ScoreCard.food_score(village), floori(600.0 / per_day) * 10.0, "審査の食料は日数から(10日で満点)")
