extends GutTest

var village: Village


func before_each() -> void:
	village = Village.create(12345)


func test_brave_hits_harder_coward_weaker() -> void:
	var brave: Villager = village.add_villager("勇者")
	brave.traits = ["brave"]
	var coward: Villager = village.add_villager("臆病者")
	coward.traits = ["coward"]
	assert_gt(Combat.attack_damage(village, brave), Combat.attack_damage(village, coward))


func test_villagers_say_lines_sometimes() -> void:
	var v: Villager = village.add_villager("おしゃべり")
	v.traits = ["cheerful"]
	var said: bool = false
	for i in 48:
		village.tick(60.0)
		if not v.line.is_empty():
			said = true
			break
	assert_true(said, "一言セリフを言う")


func test_new_game_villagers_have_traits() -> void:
	var game_village: Village = Village.new_game(12345)
	for v in game_village.villagers:
		if not v.is_chief:
			assert_between(v.traits.size(), 1, 2)
