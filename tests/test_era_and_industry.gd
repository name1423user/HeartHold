extends GutTest
## M8: 時代の進行・鉱石と鍛冶・役職の解放・全建物・設備・壊れる建物と修理・隣接ボーナスと象徴・手押し車

var village: Village
var storage: Building


func before_each() -> void:
	village = Village.create(12345)
	storage = village.add_building("storage", village.world.start + Vector2i(4, 4), true)
	storage.inventory = {"smoked_meat": 100}


func _era() -> EraSystem:
	return village.system("era") as EraSystem


func test_mountains_hold_ore_within_dig_depth() -> void:
	var world: WorldData = village.world
	var ore: int = world.block_id("iron_ore")
	var found: bool = false
	for z in world.size.z:
		for x in world.size.x:
			var cell := Vector2i(x, z)
			if world.biome_at(cell) != WorldData.Biome.MOUNTAIN:
				continue
			for y in range(world.top_y(cell) - 3, world.top_y(cell)):
				if world.get_block(Vector3i(x, y, z)) == ore:
					found = true
	assert_true(found, "岩山の掘れる深さに鉄鉱石")


func test_era_advances_when_requirements_met_and_unlocks_things() -> void:
	assert_eq(village.era(), "stone")
	assert_ne(village.building_lock("smithy", 5), "", "鉄の時代まで鍛冶屋は建てられない")
	assert_eq(Crafting.order(village, "iron_ingot"), 0)
	village.level.level = 2
	village.add_building("workbench", village.world.start + Vector2i(-6, 4), true)
	for i in 3:
		village.add_building("house", village.world.start + Vector2i(-12 + i * 4, -10), true)
	for i in 5:
		village.add_villager("住人%d" % i)
	watch_signals(village)
	_era().update(60.0)
	assert_eq(village.era(), "iron")
	assert_signal_emitted(village, "alert_raised")
	assert_eq(village.building_lock("smithy", 2), "")
	assert_true(Equipment.is_available("iron_axe", village.era()))


func test_smithing_chain_ore_to_ingot() -> void:
	_era().current = "iron"
	village.add_building("charcoal_kiln", village.world.start + Vector2i(-6, 4), true)
	village.add_building("smithy", village.world.start + Vector2i(-6, -6), true)
	storage.inventory = {"smoked_meat": 100, "log": 4, "iron_ore": 2}
	var smith: Villager = village.add_villager("鍛冶師")
	assert_true(Job.assign(village, smith, "smith"), "鍛冶屋があれば鍛冶師になれる")
	assert_eq(Crafting.order(village, "charcoal"), 1)
	assert_eq(Crafting.order(village, "iron_ingot"), 1)
	for i in 36:
		village.tick(10.0)
		if int(storage.inventory.get("iron_ingot", 0)) > 0:
			break
	assert_eq(int(storage.inventory.get("iron_ingot", 0)), 1, "鉄鉱石+木炭 → 鉄の延べ棒")


func test_jobs_unlock_with_buildings() -> void:
	var v: Villager = village.add_villager("見習い")
	assert_false(Job.available(village).has("miner"))
	assert_false(Job.assign(village, v, "miner"))
	_era().current = "iron"
	var mountain := Vector2i(-1, -1)
	for z in range(0, 256, 2):
		for x in range(0, 256, 2):
			var c := Vector2i(x, z)
			if mountain.x < 0 and village.world.biome_at(c) == WorldData.Biome.GRASSLAND and village._near_mountain(c, 5) and village.building_error("mine", c).is_empty():
				mountain = c
	assert_ne(mountain, Vector2i(-1, -1))
	assert_eq(village.building_error("mine", village.world.start), "need_mountain", "炭鉱は岩山の近く")
	village.add_building("mine", mountain, true)
	assert_true(Job.assign(village, v, "miner"))
	v.place_at(mountain + Vector2i(-1, 0))
	storage.inventory["smoked_meat"] = 100
	for i in 48:
		village.tick(10.0)
		if int(storage.inventory.get("iron_ore", 0)) + int(storage.inventory.get("coal", 0)) > 0:
			break
	assert_gt(int(storage.inventory.get("iron_ore", 0)) + int(storage.inventory.get("coal", 0)), 0, "炭鉱から鉱石")


func test_fence_damaged_and_destroyed_and_house_repaired() -> void:
	var damage: BuildingDamage = village.system("building_damage") as BuildingDamage
	var fence: Building = village.add_building("fence", village.world.start + Vector2i(8, 0), true)
	damage.damage(fence, 1000.0)
	assert_false(village.buildings.has(fence.id), "柵は壊されて消える")
	assert_true(village.world.is_walkable(fence.cell))
	var house: Building = village.add_building("house", village.world.start + Vector2i(-8, -8), true)
	var builder: Villager = village.add_villager("ベルント")
	Job.assign(village, builder, "builder")
	storage.inventory["plank"] = 10
	storage.inventory["log"] = 10
	damage.damage(house, 1000.0)
	assert_true(house.broken)
	assert_false(house.is_complete(), "壊れた家は使えない")
	for i in 48:
		village.tick(10.0)
		if not house.broken:
			break
	assert_false(house.broken, "建築係が直す")
	assert_eq(house.current_hp(), house.max_hp())


func test_goblin_breaks_through_fence_ring() -> void:
	var start: Vector2i = village.world.start
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			if absi(dx) == 3 or absi(dz) == 3:
				village.add_building("fence", start + Vector2i(dx, dz), true)
	var hidden: Villager = village.add_villager("中の人")
	hidden.place_at(start)
	var m := Monster.new()
	m.setup("goblin")
	m.pos = Vector2(start + Vector2i(6, 0))
	village.raids.monsters.append(m)
	var fences: int = village.buildings.values().filter(func(b: Building) -> bool: return b.type == "fence").size()
	for i in 600:
		m.update(village, 1.0)
		if village.buildings.values().filter(func(b: Building) -> bool: return b.type == "fence").size() < fences:
			break
	assert_lt(village.buildings.values().filter(func(b: Building) -> bool: return b.type == "fence").size(), fences, "囲いを壊して入る")


func test_fixture_skill_limit_and_shelves_and_tool_rack() -> void:
	_era().current = "iron"
	var house: Building = village.add_building("house", village.world.start + Vector2i(-8, -8), true)
	var novice: Villager = village.add_villager("見習い")
	Job.assign(village, novice, "builder")
	assert_true(BuildingFixture.order(village, house, "fireplace")["ok"])
	var task: JobTask = village.tasks.of_type("fixture")[0]
	assert_false(village.can_take(novice, task), "熟練度2未満は暖炉を置けない")
	village.gain_experience(novice, "build", float(Proficiency.cfg()["minutes_per_level"]) * 2)
	assert_true(village.can_take(novice, task))
	var cap: int = storage.capacity()
	storage.fixtures.append("wooden_shelf")
	assert_eq(storage.capacity(), int(cap * 1.5), "棚で置ける量 +50%")


func test_adjacency_and_landmark() -> void:
	var house: Building = village.add_building("house", village.world.start + Vector2i(-8, -8), true)
	var v: Villager = village.add_villager("ハンス")
	var before: float = village.mood_rate(v)
	village.add_building("campfire", village.world.start + Vector2i(-4, -8), true)
	assert_almost_eq(village.mood_rate(v), before * 1.1, 0.0001, "焚き火の近くの家は気分の回復 +10%")
	_era().current = "iron"
	var rep: Reputation = village.system("reputation") as Reputation
	var rep_before: float = rep.value
	var scores_before: Dictionary = ScoreCard.score_village(village)
	village.add_building("village_monument", village.world.start + Vector2i(8, -8), true)
	assert_gt(rep.value, rep_before, "評判が上がる")
	assert_gt(float(ScoreCard.score_village(village)["facilities"]), float(scores_before["facilities"]), "審査に効く")
	assert_ne(village.building_lock("clock_tower", 9), "", "象徴は1つだけ")


func test_handcart_carries_more() -> void:
	var v: Villager = village.add_villager("運び屋")
	assert_eq(village.carry_capacity(v), 10)
	Equipment.equip(v, "handcart")
	assert_eq(village.carry_capacity(v), 30)
