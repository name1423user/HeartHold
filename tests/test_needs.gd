extends GutTest

var village: Village


func before_each() -> void:
	village = Village.create(12345)


func test_needs_decay_and_sleep_recovers() -> void:
	var needs := Needs.new()
	needs.set_value("food", 50.0)
	needs.set_value("sleep", 50.0)
	needs.tick(60.0, false)
	assert_lt(needs.get_value("food"), 50.0)
	assert_lt(needs.get_value("sleep"), 50.0)
	needs.tick(60.0, true)
	assert_gt(needs.get_value("sleep"), 50.0)


func test_starving_villager_loses_health_and_faints_within_a_day() -> void:
	var v: Villager = village.add_villager("ハンス")
	v.needs.set_value("food", 0.0)
	var last_health: float = v.needs.get_value("health")
	watch_signals(village)
	for hour in 24:
		village.tick(60.0)
		if v.state != Villager.State.NORMAL:
			break
		assert_lt(v.needs.get_value("health"), last_health, "体力が減り続ける")
		last_health = v.needs.get_value("health")
	assert_eq(v.state, Villager.State.UNCONSCIOUS, "体力0で気絶")
	assert_signal_emitted_with_parameters(village, "alert_raised", ["faint", "ハンスが倒れました", v.cell()])


func test_hungry_villager_eats_on_their_own() -> void:
	var v: Villager = village.add_villager("アンナ")
	village.drop_on_ground(world_start_offset(3), "meal", 3)
	v.needs.set_value("food", 20.0)
	village.tick(30.0)
	assert_gt(v.needs.get_value("food"), 50.0)
	assert_eq(int(village.ground_items[world_start_offset(3)]["meal"]), 2)


func test_tired_villager_sleeps() -> void:
	var v: Villager = village.add_villager("クララ")
	v.needs.set_value("sleep", 10.0)
	village.tick(120.0)
	assert_gt(v.needs.get_value("sleep"), 10.0)


func world_start_offset(dx: int) -> Vector2i:
	return village.world.start + Vector2i(dx, 0)
