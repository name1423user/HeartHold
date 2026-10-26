extends GutTest

var village: Village


func before_each() -> void:
	village = Village.create(12345)


func test_no_raid_until_day_five_is_over() -> void:
	var raids: RaidDirector = village.raids
	village.clock.minutes = 5.0 * 1440.0 - 1.0
	assert_false(raids.can_start(), "5日目の終わりまでは来ない")
	raids.start_raid()
	assert_false(raids.active)
	village.clock.minutes = 5.0 * 1440.0
	assert_true(raids.can_start())


func test_random_raid_happens_eventually_after_grace() -> void:
	village.clock.minutes = 5.0 * 1440.0
	for i in 24 * 6:
		village.raids.update(10.0)
		if village.raids.active:
			break
	assert_true(village.raids.active, "猶予のあとは確率で起きる")


func test_cooldown_of_three_days() -> void:
	var raids: RaidDirector = village.raids
	village.clock.minutes = 6.0 * 1440.0
	raids.start_raid()
	assert_true(raids.active)
	raids.end_raid()
	village.clock.minutes += 3.0 * 1440.0 - 1.0
	assert_false(raids.can_start(), "前回から3日未満は起きない")
	for i in 100:
		raids.update(10.0)
	assert_false(raids.active)
	village.clock.minutes += 1.0
	assert_true(raids.can_start())


func test_double_wealth_means_more_monsters() -> void:
	var raids: RaidDirector = village.raids
	var storage: Building = village.add_building("storage", village.world.start + Vector2i(4, 4), true)
	storage.inventory = {"log": 150}
	var small: int = raids.monster_count_for(raids.wealth())
	storage.inventory = {"log": 150 + int(raids.wealth())}
	var big: int = raids.monster_count_for(raids.wealth())
	assert_gt(big, small, "豊かさが2倍なら魔物が増える")
	village.clock.minutes = 6.0 * 1440.0
	raids.start_raid()
	assert_eq(raids.monsters.size(), big)
	for m in raids.monsters:
		assert_gt(m.pos.distance_to(Vector2(village.world.start)), raids.village_radius(), "村の外から来る")
