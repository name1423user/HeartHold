extends GutTest
## M6-T03 の通し確認(自動でできる部分)。SPEC 4章 MVP の完成条件1〜3を、村人の実際の仕事で進める。
## 何日も待つところ(狩りで食料がたまる・希望者が来る日)だけは時間を飛ばしたり物を足したりして早める。

const DIR: String = "user://test_e2e_saves"

var village: Village


func before_each() -> void:
	SaveGame.directory_override = DIR
	village = Village.new_game(12345)


func after_each() -> void:
	var dir := DirAccess.open(DIR)
	if dir != null:
		for file in dir.get_files():
			dir.remove(file)
	SaveGame.directory_override = ""
	village.dispose()


func _run_until(hours: int, done: Callable) -> bool:
	for i in hours * 6:
		village.tick(10.0)
		if done.call():
			return true
	return false


## 完成条件1: 木を伐る → 家を建てる → 移住審査で1人合格
func test_chop_build_house_and_one_applicant_passes() -> void:
	var start: Vector2i = village.world.start
	var gatherer: Villager = village.villagers[1]
	var builder: Villager = village.villagers[2]
	var hunter: Villager = village.villagers[3]
	Job.assign(village, builder, "builder")
	Job.assign(village, hunter, "hunter")
	Job.assign(village, gatherer, "gatherer")
	assert_true(village.plan_building("storage", start + Vector2i(4, 4))["ok"])
	assert_true(_run_until(12, func() -> bool: return village.stockpiles().size() > 0), "倉庫が建つ")
	var nearest: Vector2i = village.world.trees.keys()[0]
	for cell: Vector2i in village.world.trees:
		if cell.distance_squared_to(start) < nearest.distance_squared_to(start):
			nearest = cell
	assert_gt(Designation.chop_area(village, Rect2i(nearest - Vector2i(6, 6), Vector2i(12, 12))), 0)
	assert_true(village.plan_building("workbench", start + Vector2i(-6, 4))["ok"])
	assert_true(_run_until(24, func() -> bool: return village.stock_count("log") >= 8), "原木が倉庫に入る")
	Crafting.order(village, "plank", 2)
	assert_true(_run_until(24, func() -> bool: return village.stock_count("plank") >= 8), "木材ができる")
	var house: Building = village.plan_building("house", start + Vector2i(-8, -8))["building"]
	assert_true(_run_until(48, func() -> bool: return house.is_complete()), "最初の家が完成")
	# 4人(村長+3人)と新しい1人ぶんの寝床がいるので、家はあと2軒。救護室と衛兵も用意する
	village.plan_building("house", start + Vector2i(-3, -9))
	village.plan_building("house", start + Vector2i(2, -9))
	village.plan_building("infirmary", start + Vector2i(7, -8))
	Job.assign(village, hunter, "guard")
	Equipment.equip(hunter, "wooden_spear")
	# 安全を重く見る希望者にも備えて、見張り台も建てる
	village.add_building("watchtower", start + Vector2i(10, 2), true)
	# ここから数日分の狩りの成果を足して、希望者の来る日まで進める
	village.stockpiles()[0].inventory["smoked_meat"] = int(village.stockpiles()[0].inventory.get("smoked_meat", 0)) + 100
	village.stockpiles()[0].inventory["plank"] = int(village.stockpiles()[0].inventory.get("plank", 0)) + 30
	village.stockpiles()[0].inventory["stone"] = int(village.stockpiles()[0].inventory.get("stone", 0)) + 10
	assert_true(_run_until(72, func() -> bool: return village.houses().size() >= 3), "家が3軒")
	var before: int = village.living_villagers().size()
	village.inspection.next_visit_at = village.clock.minutes
	var results: Array = village.inspection.results
	assert_true(_run_until(12, func() -> bool: return not results.is_empty()), "審査がある")
	gut.p("審査: %s" % str(results[-1]))
	assert_true(results[-1]["passed"], "1人合格")
	assert_eq(village.living_villagers().size(), before + 1)


## 完成条件2: 襲撃が1回起き、村人が迎撃し、倒れた村人を救護室へ運ぶ
func test_raid_is_fought_and_fallen_villager_reaches_infirmary() -> void:
	var start: Vector2i = village.world.start
	var infirmary: Building = village.add_building("infirmary", start + Vector2i(-8, 4), true)
	village.add_building("house", start + Vector2i(-8, -8), true)
	var guard: Villager = village.villagers[1]
	Job.assign(village, guard, "guard")
	Equipment.equip(guard, "wooden_spear")
	var victim: Villager = village.villagers[2]
	victim.needs.set_value("health", 4.0)
	victim.place_at(start + Vector2i(12, 0))
	village.clock.minutes = 6.0 * 1440.0 + 10.0 * 60.0
	village.raids.start_raid()
	assert_true(village.raids.active, "襲撃が起きる")
	# 1体を倒れる人のすぐそばへ
	village.raids.monsters[0].pos = victim.pos + Vector2(1.0, 0.0)
	village.raids.monsters[0].update(village, 1.0)
	assert_eq(victim.state, Villager.State.UNCONSCIOUS)
	var fought: Array = [false]
	_run_until(24, func() -> bool:
		if guard.plan_kind == "fight":
			fought[0] = true
		return not village.raids.active and victim.state != Villager.State.UNCONSCIOUS)
	assert_true(fought[0], "衛兵が迎撃した")
	assert_false(village.raids.active, "襲撃を退けた")
	assert_ne(victim.state, Villager.State.DEAD, "救護室へ運ばれて助かった")
	assert_true(victim.state == Villager.State.IN_TREATMENT or victim.state == Villager.State.NORMAL)
	assert_eq(HealthState.slots(infirmary), 2)


## 完成条件3: セーブして終了し、ロードすると地形・建物・村人・時刻が戻る
func test_save_quit_load_restores_world() -> void:
	village.add_building("house", village.world.start + Vector2i(-8, -8), true)
	Designation.dig_area(village, Rect2i(village.world.start + Vector2i(3, 3), Vector2i(2, 2)))
	village.tick(240.0)
	assert_eq(SaveGame.save_village(village, "e2e"), OK)
	var loaded: Village = SaveGame.load_village("e2e")
	assert_not_null(loaded)
	assert_true(loaded.world.blocks == village.world.blocks, "地形")
	assert_eq(loaded.buildings.size(), village.buildings.size(), "建物")
	assert_eq(loaded.villagers.size(), village.villagers.size(), "村人")
	assert_eq(loaded.clock.minutes, village.clock.minutes, "時刻")
	loaded.dispose()
