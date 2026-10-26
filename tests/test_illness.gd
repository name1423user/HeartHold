extends GutTest

var village: Village
var illness: Illness


func before_each() -> void:
	village = Village.create(12345)
	illness = village.system("illness") as Illness


func test_dirty_and_cold_villager_catches_cold_eventually() -> void:
	var v: Villager = village.add_villager("ハンス")
	v.needs.set_value("hygiene", 0.0)
	v.needs.set_value("warmth", 0.0)
	for i in 500:
		illness.update_villager(v, 60.0)
		if Illness.disease_of(v) != "":
			break
	assert_eq(Illness.disease_of(v), "cold")


func test_sick_villager_works_slower_rests_and_recovers() -> void:
	var v: Villager = village.add_villager("アンナ")
	village.add_building("house", village.world.start + Vector2i(-8, -8), true)
	var normal: float = village.work_speed(v, "chop")
	illness.infect(v, "cold")
	assert_almost_eq(village.work_speed(v, "chop"), normal * 0.6, 0.0001)
	village.tick(5.0)
	assert_eq(v.plan_kind, "rest", "休む")
	village.tick(40.0 * 60.0)
	assert_eq(Illness.disease_of(v), "", "休めば48時間より早く治る")


func test_medicine_cabinet_cures_faster() -> void:
	var infirmary: Building = village.add_building("infirmary", village.world.start + Vector2i(-8, 4), true)
	infirmary.fixtures.append("medicine_cabinet")
	var v: Villager = village.add_villager("クララ")
	illness.infect(v, "cold")
	village.tick(20.0 * 60.0)
	assert_eq(Illness.disease_of(v), "")


func test_injury_after_recovery_slows_work_for_days() -> void:
	var infirmary: Building = village.add_building("infirmary", village.world.start + Vector2i(-8, 4), true)
	var v: Villager = village.add_villager("オットー")
	var normal: float = village.work_speed(v, "dig")
	v.state = Villager.State.UNCONSCIOUS
	HealthState.admit(village, v, infirmary)
	HealthState.recover(village, v)
	assert_true(Illness.is_injured(village, v))
	assert_almost_eq(village.work_speed(v, "dig"), normal * 0.7, 0.0001)
	village.clock.minutes += 3.0 * 1440.0 + 1.0
	assert_false(Illness.is_injured(village, v))
