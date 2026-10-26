extends GutTest


func test_complaint_for_low_need_or_no_home() -> void:
	var village: Village = Village.create(12345)
	var v: Villager = village.add_villager("ハンス")
	assert_eq(SpeechBubble.complaint(village, v), "寝る場所がない", "家がない")
	village.add_building("house", village.world.start + Vector2i(-8, -8), true)
	assert_eq(SpeechBubble.complaint(village, v), "")
	v.needs.set_value("food", 10.0)
	assert_eq(SpeechBubble.complaint(village, v), "腹が減った")
	village.tick(0.5)
	assert_eq(v.complaint, "腹が減った", "村人パネルと頭上に出す値")
	v.needs.set_value("food", 80.0)
	v.needs.set_value("sleep", 5.0)
	assert_eq(SpeechBubble.complaint(village, v), "眠い…")
