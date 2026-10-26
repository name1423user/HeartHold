extends GutTest

var village: Village


func before_each() -> void:
	village = Village.create(12345)
	village.clock.minutes = 6.0 * 1440.0 + 10.0 * 60.0


## 魔物を1体出して、警告が出るまでの距離(村の中心から)を返す
func _warning_distance(v: Village) -> float:
	var m := Monster.new()
	m.setup("goblin")
	m.pos = Vector2(v.world.start + Vector2i(45, 0))
	v.raids.monsters.append(m)
	v.raids.active = true
	v.raids.last_raid_at = v.clock.minutes
	var alerts: Array = []
	v.alert_raised.connect(func(kind: String, _message: String, _cell: Vector2i) -> void:
		if kind == "raid":
			alerts.append(m.pos.distance_to(Vector2(v.world.start))))
	for i in 120:
		v.tick(1.0)
		if not alerts.is_empty():
			break
	return alerts[0] if not alerts.is_empty() else -1.0


func test_tower_warns_before_monsters_reach_the_border() -> void:
	var plain: float = _warning_distance(village)
	var with_tower: Village = Village.create(12345)
	with_tower.clock.minutes = village.clock.minutes - 120.0
	with_tower.add_building("watchtower", with_tower.world.start + Vector2i(14, -1), true)
	var early: float = _warning_distance(with_tower)
	assert_gt(early, with_tower.raids.village_radius(), "境界に着く前に警告")
	assert_gt(early, plain, "見張り台がないときより早い")


func test_tower_widens_vision() -> void:
	var tower: Building = village.add_building("watchtower", village.world.start + Vector2i(10, 10), true)
	village.fog.refresh()
	assert_true(village.fog.is_visible(Vector2i(tower.center()) + Vector2i(20, 0)))


func test_sling_guard_on_tower_shoots_with_longer_range() -> void:
	var tower: Building = village.add_building("watchtower", village.world.start + Vector2i(8, 0), true)
	var guard: Villager = village.add_villager("カール")
	Job.assign(village, guard, "guard")
	Equipment.equip(guard, "sling")
	assert_true(Watchtower.station(village, tower, guard)["ok"])
	village.tick(10.0)
	assert_true(Watchtower.is_on_tower(village, guard), "台に上がる")
	var m := Monster.new()
	m.setup("goblin")
	m.pos = tower.center() + Vector2(11.0, 0.0)
	village.raids.monsters.append(m)
	village.raids.active = true
	village.raids.last_raid_at = village.clock.minutes
	village.raid_alarm = true
	guard.plan = [{"op": "fight"}]
	guard.plan_kind = "fight"
	var hp: float = m.hp
	village.run_plan(guard, 1.0)
	assert_lt(m.hp, hp, "射程12(8の1.5倍)で台の上から当たる")
	assert_true(Watchtower.is_on_tower(village, guard), "台から降りない")


func test_only_guards_can_be_stationed() -> void:
	var tower: Building = village.add_building("watchtower", village.world.start + Vector2i(8, 0), true)
	var worker: Villager = village.add_villager("アンナ")
	assert_false(Watchtower.station(village, tower, worker)["ok"])
