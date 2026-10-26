extends GutTest

var village: Village


func before_each() -> void:
	village = Village.create(12345)


func test_fainted_villager_carried_to_infirmary_recovers() -> void:
	var infirmary: Building = village.add_building("infirmary", village.world.start + Vector2i(-6, 4), true)
	var patient: Villager = village.add_villager("ハンス")
	var rescuer: Villager = village.add_villager("アンナ")
	patient.place_at(village.world.start + Vector2i(8, -6))
	village.knock_out(patient)
	assert_eq(village.tasks.of_type("rescue").size(), 1, "救護室へ運ぶ仕事ができる")
	for i in 120:
		village.tick(2.0)
		if patient.state == Villager.State.IN_TREATMENT:
			break
	assert_eq(patient.state, Villager.State.IN_TREATMENT, "半日以内に運ばれた")
	assert_eq(int(patient.timers["infirmary"]), infirmary.id)
	assert_lt(float(rescuer.timers.get("down_minutes", 0.0)), 1.0)
	village.tick(HealthState.cfg()["treatment_minutes"] + 5.0)
	assert_eq(patient.state, Villager.State.NORMAL, "回復する")
	assert_gt(patient.needs.get_value("health"), 0.0)


func test_villager_left_alone_dies_after_half_a_day_with_alert() -> void:
	var patient: Villager = village.add_villager("クララ")
	village.knock_out(patient)
	watch_signals(village)
	village.tick(719.0)
	assert_eq(patient.state, Villager.State.UNCONSCIOUS)
	village.tick(2.0)
	assert_eq(patient.state, Villager.State.DEAD, "運ばれなければ死亡")
	assert_eq(AlertsHelper.find(self, village, "death"), ["death", "クララが亡くなりました", patient.cell()])
	assert_true(village.tasks.of_type("rescue").is_empty())


func test_full_infirmary_patient_waits_without_dying() -> void:
	var infirmary: Building = village.add_building("infirmary", village.world.start + Vector2i(-6, 4), true)
	var waiting: Array[Villager] = []
	for i in 3:
		var p: Villager = village.add_villager("患者%d" % i)
		p.state = Villager.State.UNCONSCIOUS
		HealthState.admit(village, p, infirmary)
		waiting.append(p)
	assert_eq(waiting[2].state, Villager.State.UNCONSCIOUS, "寝台2台なので3人目は待つ")
	village.tick(800.0)
	assert_ne(waiting[2].state, Villager.State.DEAD, "救護室で待っている間は死なない")


func test_no_game_over_when_everyone_dies() -> void:
	var v: Villager = village.add_villager("オットー")
	village.knock_out(v)
	village.tick(800.0)
	assert_eq(v.state, Villager.State.DEAD)
	assert_true(village.living_villagers().is_empty())
	village.tick(60.0)
	assert_gt(village.inspection.next_visit_at, 0.0, "次の移住希望者を待てる")
