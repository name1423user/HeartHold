extends GutTest

var village: Village
var chief_v: Villager


func before_each() -> void:
	village = Village.create(12345)
	chief_v = village.chief.spawn()


func test_policy_buffs_apply_only_while_chief_is_well() -> void:
	var worker: Villager = village.add_villager("ハンス")
	var base: float = village.work_speed(worker, "chop")
	assert_eq(village.chief.policy, "diligent")
	assert_almost_eq(base, 1.1, 0.0001, "勤勉: 作業速度+10%")
	chief_v.state = Villager.State.IN_TREATMENT
	assert_almost_eq(village.work_speed(worker, "chop"), 1.0, 0.0001, "治療中はかからない")
	chief_v.state = Villager.State.NORMAL


func test_each_policy_raises_its_own_stat() -> void:
	var guard: Villager = village.add_villager("カール")
	Job.assign(village, guard, "guard")
	var worker: Villager = village.add_villager("アンナ")
	assert_true(village.chief.set_policy("defense")["ok"])
	assert_almost_eq(Combat.attack_damage(village, guard), 2.0 * 1.2, 0.0001, "守り: 衛兵の攻撃+20%")
	assert_almost_eq(Combat.attack_damage(village, worker), 2.0, 0.0001, "衛兵以外には効かない")
	village.clock.minutes += 1440.0
	assert_true(village.chief.set_policy("comfort")["ok"])
	assert_almost_eq(village.mood_rate(worker), 1.2, 0.0001, "安らぎ: 気分の回復+20%")


func test_policy_change_once_per_day() -> void:
	assert_true(village.chief.set_policy("defense")["ok"])
	var result: Dictionary = village.chief.set_policy("comfort")
	assert_false(result["ok"])
	assert_eq(result["message"], "方針の変更はゲーム内1日に1回までです")
	village.clock.minutes += 1440.0
	assert_true(village.chief.set_policy("comfort")["ok"])


func test_chief_cannot_be_ordered_directly() -> void:
	assert_false(DirectOrder.move(village, chief_v, village.world.start + Vector2i(3, 0))["ok"])
	assert_false(Job.assign(village, chief_v, "builder"))


func test_chief_does_not_die_and_returns_after_three_real_minutes() -> void:
	var infirmary: Building = village.add_building("infirmary", village.world.start + Vector2i(-6, 4), true)
	village.add_villager("アンナ")
	chief_v.place_at(village.world.start + Vector2i(6, -6))
	village.knock_out(chief_v)
	village.tick(2000.0)
	assert_ne(chief_v.state, Villager.State.DEAD, "死なずに瀕死")
	# 2000分のうちに救護室へ運ばれ、実時間3分(=ゲーム内216分)で復帰している
	assert_eq(chief_v.state, Villager.State.NORMAL)
	var c: Villager = village.chief.villager
	village.knock_out(c)
	HealthState.admit(village, c, infirmary)
	assert_almost_eq(float(c.timers["treatment_left"]), village.clock.real_to_minutes(180.0), 0.001)
	village.tick(village.clock.real_to_minutes(180.0) - 1.0)
	assert_eq(c.state, Villager.State.IN_TREATMENT)
	village.tick(2.0)
	assert_eq(c.state, Villager.State.NORMAL)


func test_dying_chief_alone_waits_without_dying() -> void:
	village.knock_out(chief_v)
	village.tick(3000.0)
	assert_eq(chief_v.state, Villager.State.UNCONSCIOUS)
