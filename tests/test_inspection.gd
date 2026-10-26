extends GutTest

var village: Village


func before_each() -> void:
	village = Village.create(12345)


func _build_village() -> Dictionary:
	var house: Building = village.add_building("house", village.world.start + Vector2i(-8, -8), true)
	var storage: Building = village.add_building("storage", village.world.start + Vector2i(6, -8), true)
	var infirmary: Building = village.add_building("infirmary", village.world.start + Vector2i(6, 6), true)
	return {"house": house, "storage": storage, "infirmary": infirmary}


func test_first_visit_comes_within_seven_days() -> void:
	assert_between(village.inspection.next_visit_at - village.clock.minutes, 5.0 * 1440.0, 7.0 * 1440.0)


func test_applicant_tours_house_storage_infirmary_in_order_then_scores() -> void:
	var b: Dictionary = _build_village()
	watch_signals(village.inspection)
	village.inspection.next_visit_at = village.clock.minutes
	village.tick(1.0)
	var applicant: Applicant = village.inspection.current
	assert_not_null(applicant)
	for i in 600:
		village.tick(1.0)
		if village.inspection.current == null:
			break
	var visited: Array = village.inspection.tour_log
	assert_eq(visited, ["house", "storage", "infirmary"], "家・倉庫・救護室を順に見る")
	assert_signal_emitted(village.inspection, "inspection_finished", "見回りのあとに採点表")


func test_introduction_shows_job_personality_and_specialty_but_not_weights() -> void:
	var a: Applicant = Applicant.from_data(Applicant.find("a01"))
	var text: String = a.introduction()
	assert_string_contains(text, "元兵士")
	assert_string_contains(text, "無口だが頼りになる")
	assert_string_contains(text, "槍の心得")
	assert_false(text.contains("0.4"), "重みは来訪前に出さない")


func test_former_soldier_weighs_safety_most() -> void:
	var weights: Dictionary = Applicant.from_data(Applicant.find("a01")).weights()
	var best: String = ""
	for key: String in weights:
		if best.is_empty() or float(weights[key]) > float(weights[best]):
			best = key
	assert_eq(best, "safety")


func test_applicant_waits_outside_during_raid() -> void:
	_build_village()
	var raid: Array = [true]
	village.inspection.is_raid_active = func() -> bool: return raid[0]
	village.inspection.next_visit_at = village.clock.minutes
	village.tick(1.0)
	var body: Villager = village.inspection.current.body
	var waiting_at: Vector2 = body.pos
	village.tick(60.0)
	assert_eq(body.pos, waiting_at, "襲撃中は村の外で待つ")
	raid[0] = false
	village.tick(30.0)
	assert_ne(body.pos, waiting_at, "襲撃が終わったら見回りを始める")


func test_master_builder_specialty_speeds_up_building() -> void:
	var a: Applicant = Applicant.from_data(Applicant.find("a03"))
	assert_eq(a.specialty_name(), "建築上手")
	var v: Villager = village.add_villager(a.display_name)
	v.specialty = a.specialty
	var plain: Villager = village.add_villager("比較用")
	assert_almost_eq(village.work_speed(v, "build"), village.work_speed(plain, "build") * 1.3, 0.0001)
