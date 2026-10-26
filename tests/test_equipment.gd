extends GutTest

var village: Village
var storage: Building


func before_each() -> void:
	village = Village.create(12345)
	storage = village.add_building("storage", village.world.start + Vector2i(3, 3), true)


func test_axe_chops_faster_and_wears_out_then_breaks() -> void:
	var v: Villager = village.add_villager("ハンス")
	var bare: float = village.work_speed(v, "chop")
	Equipment.equip(v, "stone_axe")
	assert_eq(village.work_speed(v, "chop"), bare * float(Equipment.def("stone_axe")["speed"]), "素手より速い(倍率はデータ)")
	assert_eq(village.work_speed(v, "dig"), bare, "斧は掘る速さに効かない")
	village.wear_tool(v, "chop")
	assert_eq(int(v.equipment["tool"]["durability"]), 59, "使うたびに耐久が減る")
	v.equipment["tool"]["durability"] = 1
	watch_signals(village)
	village.wear_tool(v, "chop")
	assert_eq(Equipment.equipped(v, "tool"), "", "0で壊れて素手に戻る")
	assert_signal_emitted_with_parameters(village, "alert_raised", ["tool_broken", "ハンスの石の斧が壊れました", v.cell()])


func test_weapons_raise_attack_and_sling_has_range() -> void:
	var v: Villager = village.add_villager("オットー")
	assert_eq(Equipment.attack(v), 2.0, "素手")
	Equipment.equip(v, "wooden_spear")
	assert_eq(Equipment.attack(v), 8.0)
	assert_false(Equipment.is_ranged(v))
	Equipment.equip(v, "sling")
	assert_eq(Equipment.attack_range(v), 8.0)
	assert_eq(Equipment.attack_range(v, true), 12.0, "見張り台の上では射程+50%")
	assert_true(Equipment.is_ranged(v))


func test_spear_is_crafted_and_guard_fetches_it_from_storage() -> void:
	village.add_building("workbench", village.world.start + Vector2i(-4, 3), true)
	storage.inventory = {"plank": 3}
	var crafter: Villager = village.add_villager("アンナ")
	Crafting.order(village, "wooden_spear")
	for i in 30:
		village.tick(10.0)
		if storage.inventory.get("wooden_spear", 0) > 0:
			break
	assert_eq(int(storage.inventory.get("wooden_spear", 0)), 1, "作業台で作れる")
	var guard: Villager = village.add_villager("カール")
	Job.assign(village, guard, "guard")
	for i in 12:
		village.tick(5.0)
		if Equipment.equipped(guard, "weapon") != "":
			break
	assert_eq(Equipment.equipped(guard, "weapon"), "wooden_spear", "倉庫から自分で取りに行く")
	assert_eq(int(storage.inventory.get("wooden_spear", 0)), 0)
	assert_eq(Equipment.equipped(crafter, "weapon"), "", "採集係は槍を取らない")


func test_only_stone_tier_is_available_in_mvp() -> void:
	assert_true(Equipment.is_available("stone_axe"))
	assert_false(Equipment.is_available("iron_axe"))
	assert_false(Equipment.is_available("steel_pickaxe"))
