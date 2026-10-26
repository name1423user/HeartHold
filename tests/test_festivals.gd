extends GutTest

var village: Village
var festivals: Festivals
var storage: Building


func before_each() -> void:
	village = Village.create(12345)
	festivals = village.system("festivals") as Festivals
	storage = village.add_building("storage", village.world.start + Vector2i(4, 4), true)


func test_feast_needs_place_and_food_then_raises_mood() -> void:
	var v: Villager = village.add_villager("ハンス")
	assert_false(festivals.hold_feast()["ok"], "焚き火か酒場が要る")
	village.add_building("campfire", village.world.start + Vector2i(-3, 0), true)
	assert_eq(festivals.hold_feast()["message"], "食べ物が足りません")
	storage.inventory = {"smoked_meat": 20}
	v.needs.set_value("mood", 30.0)
	assert_true(festivals.hold_feast()["ok"])
	assert_lt(int(storage.inventory["smoked_meat"]), 20, "食べ物を使う")
	village.tick(130.0)
	assert_gt(v.needs.get_value("mood"), 50.0, "気分が大きく上がる")
	assert_false(festivals.hold_feast()["ok"], "続けては開けない")


func test_chapel_festival_each_season() -> void:
	village.add_building("chapel", village.world.start + Vector2i(-10, -10), true)
	storage.inventory = {"smoked_meat": 40}
	watch_signals(village)
	village.clock.minutes = 7.0 * 1440.0 + 11.0 * 60.0
	festivals.update(1.0)
	assert_false(festivals.current.is_empty(), "祭りが始まる")
	var rep: Reputation = village.system("reputation") as Reputation
	var before: float = rep.value
	village.tick(200.0)
	assert_gt(rep.value, before, "評判が上がる")
