extends GutTest

var village: Village
var storage: Building


func before_each() -> void:
	village = Village.create(12345)
	storage = village.add_building("storage", village.world.start + Vector2i(4, 4), true)


func test_meat_spoils_preserved_lasts() -> void:
	storage.inventory = {"meat": 30, "smoked_meat": 30, "log": 30}
	village.tick(3.0 * 1440.0)
	assert_lt(int(storage.inventory.get("meat", 0)), 15, "肉は3日で半分以上傷む")
	assert_gt(int(storage.inventory.get("smoked_meat", 0)), 25, "燻製肉は長持ち")
	assert_eq(int(storage.inventory["log"]), 30, "食べ物でない物は傷まない")


func test_barrels_and_winter_slow_spoilage() -> void:
	var cellar: Building = village.add_building("storage", village.world.start + Vector2i(-8, 4), true)
	cellar.fixtures = ["barrel"]
	storage.inventory = {"meat": 30}
	cellar.inventory = {"meat": 30}
	village.tick(1440.0)
	assert_gt(int(cellar.inventory["meat"]), int(storage.inventory["meat"]), "樽で長持ち")


func test_variety_raises_mood_monotony_lowers() -> void:
	var v: Villager = village.add_villager("ハンス")
	v.needs.set_value("mood", 50.0)
	for item in ["meal", "bread", "egg"]:
		village.ate.emit(v, item)
	assert_gt(v.needs.get_value("mood"), 50.0, "いろいろ食べると気分が上がる")
	var w: Villager = village.add_villager("アンナ")
	w.needs.set_value("mood", 50.0)
	for i in 3:
		village.ate.emit(w, "meat")
	assert_lt(w.needs.get_value("mood"), 50.0, "同じ物ばかりだと下がる")
