extends GutTest

var village: Village
var level: VillageLevel


func before_each() -> void:
	village = Village.create(12345)
	level = VillageLevel.new(village)


func test_house_and_storage_reach_level_one_and_unlock_watchtower() -> void:
	assert_eq(level.level, 0)
	assert_false(village.plan_building_checked("watchtower", village.world.start + Vector2i(8, 8), level.level)["ok"])
	village.add_building("house", village.world.start + Vector2i(-8, -8), true)
	village.add_building("storage", village.world.start + Vector2i(6, -8), true)
	level.update()
	assert_eq(level.level, 1)
	assert_true(village.plan_building_checked("watchtower", village.world.start + Vector2i(8, 8), level.level)["ok"], "村レベル1で見張り台")


func test_three_houses_five_residents_mood_sixty_levels_up_with_notice() -> void:
	level.level = 1
	for i in 3:
		village.add_building("house", village.world.start + Vector2i(-10 + i * 5, -10), true)
	for i in 4:
		village.add_villager("住人%d" % i)
	level.update()
	assert_eq(level.level, 1, "住人が4人ではまだ")
	var fifth: Villager = village.add_villager("住人5")
	for v in village.villagers:
		v.needs.set_value("mood", 60.0)
	watch_signals(village)
	level.update()
	assert_eq(level.level, 2)
	assert_signal_emitted_with_parameters(village, "alert_raised", ["level", "村レベルが2(小さな村)になりました", village.world.start])
	fifth.needs.set_value("mood", 0.0)


func test_era_is_data_only_for_now() -> void:
	assert_eq(level.current_era(), "stone")
	assert_eq(level.era_name(), "石と木の時代")
	assert_false(bool(level.cfg["eras"]["iron"]["playable"]))
