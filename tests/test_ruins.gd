extends GutTest


func test_three_to_five_ruins_hidden_in_fog_and_seeded() -> void:
	var a: Village = Village.create(12345)
	var b: Village = Village.create(12345)
	assert_between(a.ruins.sites.size(), 3, 5)
	for i in a.ruins.sites.size():
		assert_eq(a.ruins.sites[i]["cell"], b.ruins.sites[i]["cell"], "シードで決まる")
		assert_false(a.fog.is_explored(a.ruins.sites[i]["cell"]), "霧の中")


func test_discovery_alert_and_one_time_reward() -> void:
	var village: Village = Village.create(12345)
	var storage: Building = village.add_building("storage", village.world.start + Vector2i(4, 4), true)
	var site: Dictionary = village.ruins.sites[0]
	var v: Villager = village.add_villager("ハンス")
	watch_signals(village)
	v.place_at(village.pathing.nearest_standable(site["cell"], site["cell"]))
	village.tick(1.0)
	assert_true(site["discovered"])
	assert_signal_emitted_with_parameters(village, "alert_raised", ["ruin", "遺跡の跡を見つけました", site["cell"]])
	for i in 48:
		village.tick(10.0)
		if site["looted"] and village.ground_items.is_empty() and v.carry_count == 0:
			break
	assert_true(site["looted"])
	var reward: Dictionary = village.ruins.cfg["rewards"][int(site["reward"])]
	for item: String in reward:
		assert_eq(int(storage.inventory.get(item, 0)) + (1 if Equipment.equipped(v, "tool") == item else 0), int(reward[item]), item)
	village.ruins.loot(site["id"], v.cell())
	assert_true(village.ground_items.is_empty(), "2回目はない")
