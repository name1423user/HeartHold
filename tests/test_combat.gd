extends GutTest

var village: Village


func before_each() -> void:
	village = Village.create(12345)
	village.clock.minutes = 6.0 * 1440.0 + 10.0 * 60.0
	village.raids.last_raid_at = -1.0


func _spawn_goblin(at: Vector2i) -> Monster:
	var m := Monster.new()
	m.setup("goblin")
	m.pos = Vector2(at) + Vector2(0.5, 0.5)
	village.raids.monsters.append(m)
	village.raids.active = true
	village.raids.last_raid_at = village.clock.minutes
	return m


func test_guard_intercepts_and_others_take_shelter() -> void:
	var house: Building = village.add_building("house", village.world.start + Vector2i(-6, -6), true)
	var infirmary: Building = village.add_building("infirmary", village.world.start + Vector2i(-6, 4), true)
	var guard: Villager = village.add_villager("カール")
	Job.assign(village, guard, "guard")
	Equipment.equip(guard, "wooden_spear")
	var worker: Villager = village.add_villager("アンナ")
	var other: Villager = village.add_villager("ハンス")
	var goblin: Monster = _spawn_goblin(village.world.start + Vector2i(14, 0))
	watch_signals(village)
	village.tick(1.0)
	assert_true(village.raid_alarm, "境界に入ったら合図")
	assert_signal_emitted(village, "alert_raised")
	assert_eq(guard.plan_kind, "fight", "衛兵は迎撃へ")
	assert_eq(worker.plan_kind, "shelter", "他は避難")
	for i in 60:
		village.tick(1.0)
		if goblin.hp <= 0.0:
			break
	assert_lte(goblin.hp, 0.0, "衛兵がゴブリンを倒す")
	for v in [worker, other]:
		var shelter: Building = Combat.shelter_for(village, v)
		assert_true(shelter == house or shelter == infirmary)
		var near: bool = false
		for c in shelter.cells():
			if v.cell().distance_to(c) <= 1.0:
				near = true
		assert_true(near, "%s は家か救護室にいる" % v.display_name)
	village.tick(2.0)
	assert_false(village.raids.active, "全滅で襲撃が終わる")
	village.tick(1.0)
	assert_ne(worker.plan_kind, "shelter", "終われば仕事に戻る")


func test_goblin_knocks_out_unarmed_villager() -> void:
	var v: Villager = village.add_villager("グレタ")
	v.needs.set_value("health", 4.0)
	_spawn_goblin(v.cell() + Vector2i(1, 0))
	village.raids.monsters[0].update(village, 1.0)
	assert_eq(v.state, Villager.State.UNCONSCIOUS)


func test_ranged_guard_keeps_distance_and_hits() -> void:
	var guard: Villager = village.add_villager("オットー")
	Job.assign(village, guard, "guard")
	Equipment.equip(guard, "sling")
	var goblin: Monster = _spawn_goblin(guard.cell() + Vector2i(6, 0))
	var hp: float = goblin.hp
	village.raid_alarm = true
	guard.plan = [{"op": "fight"}]
	guard.plan_kind = "fight"
	village.run_plan(guard, 1.0)
	assert_lt(goblin.hp, hp, "射程8なので6ブロック先に当たる")
	assert_eq(hp - goblin.hp, 4.0, "投石紐の攻撃力")
