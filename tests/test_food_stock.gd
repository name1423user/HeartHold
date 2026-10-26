extends GutTest


func test_days_left_is_total_food_over_daily_use_rounded_down() -> void:
	var village: Village = Village.create(12345)
	var storage: Building = village.add_building("storage", village.world.start + Vector2i(4, 4), true)
	for i in 2:
		village.add_villager("村人%d" % i)
	# 1人1日 4×24 = 96、2人で 192。料理 50×10 = 500 → 2.6日 → 2日
	storage.inventory = {"meal": 10}
	assert_eq(FoodStock.days_left(village), 2)
	storage.inventory = {"meal": 10, "meat": 4, "log": 50}
	assert_eq(FoodStock.days_left(village), 3, "(500+100)/192 = 3.1")
	assert_eq(ScoreCard.food_score(village), 30.0, "審査の食料は日数から(10日で満点)")
