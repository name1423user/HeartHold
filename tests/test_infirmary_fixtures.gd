extends GutTest

var village: Village
var infirmary: Building


func before_each() -> void:
	village = Village.create(12345)
	infirmary = village.add_building("infirmary", village.world.start + Vector2i(-6, 4), true)


func test_extra_bed_adds_one_treatment_slot_up_to_four() -> void:
	assert_eq(HealthState.slots(infirmary), 2, "最初から2台")
	var storage: Building = village.add_building("storage", village.world.start + Vector2i(4, 4), true)
	storage.inventory = {"plank": 6, "fur": 2}
	var builder: Villager = village.add_villager("ベルント")
	Job.assign(village, builder, "builder")
	assert_true(BuildingFixture.order(village, infirmary, "infirmary_bed")["ok"])
	for i in 36:
		village.tick(10.0)
		if HealthState.slots(infirmary) == 3:
			break
	assert_eq(HealthState.slots(infirmary), 3, "ベッドを1台足すと同時に治療できる人数が1人増える")
	infirmary.fixtures.append("infirmary_bed")
	assert_false(BuildingFixture.order(village, infirmary, "infirmary_bed")["ok"], "上限4台")


func test_medical_kit_shortens_treatment_by_quarter_including_chief() -> void:
	var patient: Villager = village.add_villager("ハンス")
	var chief_v: Villager = village.chief.spawn()
	var normal: float = HealthState.treatment_minutes(village, patient, infirmary)
	var chief_normal: float = HealthState.treatment_minutes(village, chief_v, infirmary)
	infirmary.fixtures.append("stone_medical_kit")
	assert_almost_eq(HealthState.treatment_minutes(village, patient, infirmary), normal * 0.75, 0.001)
	assert_almost_eq(HealthState.treatment_minutes(village, chief_v, infirmary), chief_normal * 0.75, 0.001)
	assert_almost_eq(village.clock.minutes_to_real(HealthState.treatment_minutes(village, chief_v, infirmary)), 135.0, 0.01, "村長の3分 → 2分15秒")
