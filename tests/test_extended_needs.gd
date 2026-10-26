extends GutTest

var village: Village


func before_each() -> void:
	village = Village.create(12345)


func test_all_nine_needs_exist_and_save() -> void:
	var v: Villager = village.add_villager("ハンス")
	for key in Needs.ALL_KEYS:
		assert_true(v.needs.values.has(key), key)
	var restored: Villager = Villager.from_dict(v.to_dict())
	assert_eq(restored.needs.values.size(), 9)


func test_winter_cold_lowers_warmth_and_coat_helps() -> void:
	village.clock.minutes = 21.0 * 1440.0 + 12.0 * 60.0
	village.calendar().weather = "snow"
	var bare: Villager = village.add_villager("寒がり")
	var coat: Villager = village.add_villager("毛皮の人")
	Equipment.equip(coat, "fur_coat")
	var system: ExtendedNeeds = village.system("extended_needs") as ExtendedNeeds
	assert_gt(system.felt_temperature(coat), system.felt_temperature(bare))
	for i in 60:
		system.update_villager(bare, 1.0)
		system.update_villager(coat, 1.0)
	assert_lt(bare.needs.get_value("warmth"), 80.0, "寒いと体温が下がる")
	assert_gt(coat.needs.get_value("warmth"), bare.needs.get_value("warmth"), "服で寒さに強い")


func test_hypothermia_hurts() -> void:
	var v: Villager = village.add_villager("凍える人")
	v.needs.set_value("warmth", 0.0)
	village.clock.minutes = 21.0 * 1440.0 + 2.0 * 60.0
	var health: float = v.needs.get_value("health")
	(village.system("extended_needs") as ExtendedNeeds).update_villager(v, 60.0)
	assert_lt(v.needs.get_value("health"), health)


func test_dirty_villager_washes_at_well_or_river() -> void:
	var v: Villager = village.add_villager("アンナ")
	village.add_building("house", village.world.start + Vector2i(-8, -8), true)
	v.needs.set_value("hygiene", 10.0)
	var water: Vector2i = village.nearest_water(v.cell(), 60)
	assert_ne(water, Village.NO_CELL)
	for i in 120:
		village.tick(2.0)
		if v.needs.get_value("hygiene") > 30.0:
			break
	assert_gt(v.needs.get_value("hygiene"), 30.0, "川で体を洗う")


func test_company_raises_social_and_raid_lowers_calm() -> void:
	var a: Villager = village.add_villager("ハンス")
	var b: Villager = village.add_villager("アンナ")
	a.needs.set_value("social", 20.0)
	b.place_at(a.cell() + Vector2i(1, 0))
	var system: ExtendedNeeds = village.system("extended_needs") as ExtendedNeeds
	system.update_villager(a, 60.0)
	assert_gt(a.needs.get_value("social"), 20.0)
	village.raid_alarm = true
	var calm: float = a.needs.get_value("calm")
	system.update_villager(a, 60.0)
	assert_lt(a.needs.get_value("calm"), calm, "襲撃中は不安になる")
	village.raid_alarm = false


func test_bored_villager_relaxes() -> void:
	var v: Villager = village.add_villager("クララ")
	v.needs.set_value("fun", 10.0)
	village.tick(30.0)
	assert_gt(v.needs.get_value("fun"), 10.0)


func test_traits_change_speed_and_are_exclusive() -> void:
	var v: Villager = village.add_villager("オットー")
	v.traits = ["diligent"]
	assert_almost_eq(village.work_speed(v, "chop"), 1.1, 0.0001)
	var rng := RandomNumberGenerator.new()
	for i in 50:
		rng.seed = i
		var picked: Array = Traits.roll(rng)
		assert_false(picked.has("lazy") and picked.has("diligent"))
