extends GutTest

var village: Village


func before_each() -> void:
	village = Village.create(12345)


func test_seasons_cycle_every_seven_days() -> void:
	var cal: Calendar = village.calendar()
	assert_eq(cal.season_id(), "spring")
	village.clock.minutes = 7.0 * 1440.0 + 60.0
	assert_eq(cal.season_id(), "summer")
	village.clock.minutes = 21.0 * 1440.0 + 60.0
	assert_eq(cal.season_id(), "winter")
	village.clock.minutes = 28.0 * 1440.0 + 60.0
	assert_eq(cal.season_id(), "spring")
	assert_eq(cal.year(), 2)


func test_winter_is_cold_and_night_colder() -> void:
	var cal: Calendar = village.calendar()
	village.clock.minutes = 21.0 * 1440.0 + 12.0 * 60.0
	cal.weather = "clear"
	var noon: float = cal.temperature()
	assert_lt(noon, 5.0)
	village.clock.minutes = 21.0 * 1440.0 + 23.0 * 60.0
	assert_lt(cal.temperature(), noon)


func test_weather_changes_and_slows_outdoor_work() -> void:
	var seen: Dictionary = {}
	for i in 40:
		village.tick(360.0)
		seen[village.calendar().weather] = true
	assert_gt(seen.size(), 1, "天候が変わる")
	village.calendar().weather = "rain"
	var v: Villager = village.add_villager("ハンス")
	assert_almost_eq(village.calendar().work_speed(v, "chop"), 0.9, 0.0001)
	assert_eq(village.calendar().work_speed(v, "craft"), 1.0, "屋内の仕事は変わらない")


func test_season_alert() -> void:
	village.tick(1.0)
	watch_signals(village)
	village.clock.minutes = 7.0 * 1440.0 + 1.0
	village.tick(1.0)
	assert_eq(AlertsHelper.find(self, village, "season"), ["season", "夏になりました", village.world.start])
