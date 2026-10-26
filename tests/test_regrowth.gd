extends GutTest

var village: Village
var regrowth: Regrowth


func before_each() -> void:
	village = Village.create(12345)
	regrowth = village.system("regrowth") as Regrowth


func test_planted_saplings_grow_into_trees_and_stop_in_winter() -> void:
	village.add_villager("ハンス")
	var area := Rect2i(village.world.start + Vector2i(4, 4), Vector2i(4, 4))
	var planned: int = regrowth.plant_area(area)
	assert_gt(planned, 0)
	village.tick(240.0)
	assert_eq(regrowth.saplings.size(), planned, "植えた")
	var trees_before: int = village.world.trees.size()
	village.tick(5.0 * 1440.0)
	assert_gte(village.world.trees.size(), trees_before + planned, "5日で木になる")
	village.clock.minutes = 21.0 * 1440.0 + 60.0
	regrowth.saplings[village.world.start + Vector2i(-5, -5)] = 0.5
	regrowth.update(1440.0)
	assert_eq(float(regrowth.saplings[village.world.start + Vector2i(-5, -5)]), 0.5, "冬は育たない")


func test_rabbits_breed_up_to_max_and_vanish_when_overhunted() -> void:
	var cfg: Dictionary = GameData.get_dict("wildlife")["rabbit"]
	village.tick(5.0 * 1440.0)
	assert_gt(village.wildlife.animals.size(), int(cfg["count"]), "増える")
	assert_lte(village.wildlife.animals.size(), int(cfg["max"]))
	village.wildlife.animals.clear()
	village.wildlife.respawn_timer = 0.0
	village.tick(1440.0)
	assert_eq(village.wildlife.animals.size(), 0, "狩り尽くすと増えない")
	village.tick(3.0 * 1440.0)
	assert_eq(village.wildlife.animals.size(), 1, "数日に1匹だけ入ってくる")
