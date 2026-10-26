extends GutTest

var village: Village


func before_each() -> void:
	village = Village.create(12345)


func test_weighted_average_and_pass_line() -> void:
	var weights: Dictionary = {"food": 0.5, "housing": 0.2, "safety": 0.1, "facilities": 0.1, "satisfaction": 0.1}
	var scores: Dictionary = {"food": 80.0, "housing": 50.0, "safety": 30.0, "facilities": 40.0, "satisfaction": 60.0}
	assert_almost_eq(ScoreCard.weighted_total(scores, weights), 63.0, 0.0001)
	scores["food"] = 60.0
	assert_almost_eq(ScoreCard.weighted_total(scores, weights), 53.0, 0.0001)


func test_weak_items_are_largest_weighted_losses_max_two() -> void:
	var weights: Dictionary = {"food": 0.5, "housing": 0.2, "safety": 0.1, "facilities": 0.1, "satisfaction": 0.1}
	var scores: Dictionary = {"food": 60.0, "housing": 20.0, "safety": 0.0, "facilities": 100.0, "satisfaction": 90.0}
	# 失点: food 20, housing 16, safety 10, satisfaction 1
	assert_eq(ScoreCard.weak_items(scores, weights), ["food", "housing"])


func test_pass_adds_villager_and_fail_excludes_applicant_forever() -> void:
	village.add_building("house", village.world.start + Vector2i(-8, -8), true)
	village.add_building("house", village.world.start + Vector2i(-8, 4), true)
	var storage: Building = village.add_building("storage", village.world.start + Vector2i(6, -8), true)
	village.add_building("workbench", village.world.start + Vector2i(6, 4), true)
	village.add_building("infirmary", village.world.start + Vector2i(6, 8), true)
	village.add_villager("ハンス")

	# 食料なしで料理人を審査 → 不合格
	var cook := Applicant.from_data(Applicant.find("a02"))
	cook.body.place_at(village.world.start)
	village.inspection.current = cook
	village.inspection.finish()
	assert_false(village.inspection.results[-1]["passed"])
	assert_true(village.inspection.rejected.has("a02"))
	for entry: Dictionary in village.inspection.candidates():
		assert_ne(entry["id"], "a02", "同じ人は二度と来ない")
	assert_true(village.inspection.results[-1]["weak"].has("food"), "足りなかった項目に食料")

	# 食料を十分に置いて別の料理人 → 合格して住人が1人増える
	storage.inventory = {"meal": 100}
	var count: int = village.villagers.size()
	var cook2 := Applicant.from_data(Applicant.find("a10"))
	cook2.body.place_at(village.world.start)
	village.inspection.current = cook2
	village.inspection.finish()
	assert_true(village.inspection.results[-1]["passed"], str(village.inspection.results[-1]))
	assert_eq(village.villagers.size(), count + 1)


func test_no_free_bed_means_zero_housing() -> void:
	village.add_building("house", village.world.start + Vector2i(-8, -8), true)
	village.add_villager("ハンス")
	village.add_villager("アンナ")
	assert_eq(ScoreCard.housing_score(village), 0.0, "住居が足りなければ0点")
