extends GutTest

var village: Village


func before_each() -> void:
	village = Village.create(12345)


func test_level_rises_with_work_and_caps() -> void:
	var v: Villager = village.add_villager("ハンス")
	var per_level: float = float(Proficiency.cfg()["minutes_per_level"])
	assert_eq(Proficiency.level(v, "chop"), 0)
	village.gain_experience(v, "chop", per_level * 3)
	assert_eq(Proficiency.level(v, "chop"), 3)
	assert_eq(Proficiency.level(v, "dig"), 0, "作業の種類ごと")
	village.gain_experience(v, "chop", per_level * 100)
	assert_eq(Proficiency.level(v, "chop"), int(Proficiency.cfg()["max_level"]), "上限で止まる")


func test_speed_rises_with_level_and_stacks_with_tools() -> void:
	var v: Villager = village.add_villager("アンナ")
	var base: float = village.work_speed(v, "chop")
	village.gain_experience(v, "chop", float(Proficiency.cfg()["minutes_per_level"]) * 4)
	var skilled: float = village.work_speed(v, "chop")
	assert_almost_eq(skilled, base * (1.0 + 4 * float(Proficiency.cfg()["speed_per_level"])), 0.0001)
	Equipment.equip(v, "stone_axe")
	assert_almost_eq(village.work_speed(v, "chop"), skilled * 1.5, 0.0001, "道具と重なる")


func test_chopping_trees_gains_experience_and_is_listed() -> void:
	var v: Villager = village.add_villager("クララ")
	var tree: Vector2i = village.world.start + Vector2i(5, 0)
	village.world.trees[tree] = true
	village.pathing.update_cell(tree)
	Designation.chop_area(village, Rect2i(tree, Vector2i(1, 1)))
	village.tick(60.0)
	assert_gt(float(v.experience.get("chop", 0.0)), 0.0)
	var listed: Array[Dictionary] = Proficiency.summary(v)
	assert_eq(listed[0]["name"], "伐採", "村人パネルに出す内容")
