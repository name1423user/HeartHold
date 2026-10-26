extends GutTest
## M3 の確認手順: シード固定でゲーム内7日を進め、審査1回・襲撃1回が起きる。


func test_seven_days_bring_one_inspection_and_one_raid() -> void:
	var village: Village = Village.new_game(12345)
	village.add_building("storage", village.world.start + Vector2i(4, 4), true)
	village.add_building("house", village.world.start + Vector2i(-8, -8), true)
	village.add_building("infirmary", village.world.start + Vector2i(-8, 4), true)
	Job.assign(village, village.villagers[1], "guard")
	Job.assign(village, village.villagers[2], "hunter")
	var raids: Array = [0]
	village.raids.raid_started.connect(func(_count: int) -> void: raids[0] += 1)
	var inspections: Array = [0]
	village.inspection.inspection_finished.connect(func(_result: Dictionary) -> void: inspections[0] += 1)
	for hour in 7 * 24:
		village.tick(60.0)
	gut.p("審査 %d 回、襲撃 %d 回、生存 %d 人" % [inspections[0], raids[0], village.living_villagers().size()])
	assert_gte(inspections[0], 1, "移住審査が1回起きる")
	assert_gte(raids[0], 1, "襲撃が1回起きる")
	assert_gte(village.living_villagers().size(), 4, "狩人がいれば飢えない")
	village.dispose()
