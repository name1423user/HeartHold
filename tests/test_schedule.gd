extends GutTest

var village: Village
var schedule: Schedule


func before_each() -> void:
	village = Village.create(12345)
	schedule = village.system("schedule") as Schedule


func test_default_table_and_villager_follows_sleep_hours() -> void:
	var v: Villager = village.add_villager("ハンス")
	village.add_building("house", village.world.start + Vector2i(-8, -8), true)
	village.clock.minutes = 23.0 * 60.0
	assert_eq(schedule.activity(v), "sleep")
	v.needs.set_value("sleep", 70.0)
	village.tick(30.0)
	assert_eq(v.plan_kind, "sleep", "寝る時間は寝る")


func test_rest_hour_relaxes_and_player_can_change_table() -> void:
	var v: Villager = village.add_villager("アンナ")
	village.clock.minutes = 1440.0 + 12.0 * 60.0
	assert_eq(schedule.activity(v), "rest")
	village.tick(1.0)
	assert_eq(v.plan_kind, "relax")
	schedule.set_slot(12, "work")
	assert_eq(schedule.activity(v, 12), "work")
	schedule.cycle_slot(12)
	assert_eq(schedule.table[12], "rest")


func test_lazy_rests_an_extra_hour_and_override() -> void:
	var v: Villager = village.add_villager("怠け者")
	v.traits = ["lazy"]
	assert_eq(schedule.activity(v, 13), "rest", "休みの後の1時間も休む")
	var plain: Villager = village.add_villager("普通")
	assert_eq(schedule.activity(plain, 13), "work")
	var custom: Array = []
	custom.resize(24)
	custom.fill("work")
	schedule.set_override(plain, custom)
	assert_eq(schedule.activity(plain, 2), "work", "村人ごとの表")
	var restored := Schedule.new(village)
	restored.from_dict(schedule.to_dict())
	assert_eq(restored.table_for(plain)[2], "work")
