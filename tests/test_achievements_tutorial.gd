extends GutTest

var village: Village


func before_all() -> void:
	Achievements.persist = false


func after_all() -> void:
	Achievements.persist = true


func before_each() -> void:
	village = Village.create(12345)


func test_achievement_unlocks_once_with_alert() -> void:
	var a: Achievements = village.system("achievements") as Achievements
	watch_signals(village)
	village.add_building("house", village.world.start + Vector2i(-8, -8), true)
	village.tick(15.0)
	assert_true(a.unlocked.has("first_house"))
	assert_eq(AlertsHelper.find(self, village, "achievement")[1], "実績「最初の灯り」を達成しました")
	village.tick(15.0)
	assert_eq(a.unlocked.count("first_house"), 1)


func test_counters_from_events() -> void:
	var a: Achievements = village.system("achievements") as Achievements
	village.raise_alert("raid_end", "x", village.world.start)
	village.tick(15.0)
	assert_true(a.unlocked.has("raid_repelled"))


func test_tutorial_advances_by_conditions_and_next_button() -> void:
	var t := Tutorial.new(village)
	t.active = true
	t.update()
	assert_eq(t.step, 0)
	assert_true(t.needs_next_button(), "説明だけの手順は「次へ」")
	t.next()
	t.next()
	t.update()
	assert_eq(t.step, 2)
	Designation.chop_area(village, Rect2i(Vector2i.ZERO, Vector2i(256, 256)))
	t.update()
	assert_eq(t.step, 3, "伐る予約で進む")
	t.stop()
	assert_true(t.is_finished())
