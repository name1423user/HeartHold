extends GutTest

const DIR: String = "user://test_saves"


func before_each() -> void:
	SaveGame.directory_override = DIR
	_clean()


func after_each() -> void:
	_clean()
	SaveGame.directory_override = ""


func _clean() -> void:
	var dir := DirAccess.open(DIR)
	if dir != null:
		for file in dir.get_files():
			dir.remove(file)


## いろいろ進めた村
func _played_village() -> Village:
	var village: Village = Village.new_game(12345)
	var storage: Building = village.add_building("storage", village.world.start + Vector2i(4, 4), true)
	storage.inventory = {"log": 7, "meal": 12}
	village.add_building("house", village.world.start + Vector2i(-8, -8), true)
	village.plan_building("infirmary", village.world.start + Vector2i(-8, 4))
	Job.assign(village, village.villagers[1], "guard")
	Job.assign(village, village.villagers[2], "hunter")
	Designation.dig_area(village, Rect2i(village.world.start + Vector2i(2, -6), Vector2i(3, 3)))
	village.tick(180.0)
	village.inspection.rejected.append("a05")
	village.level.level = 1
	village.clock.minutes = 6.0 * 1440.0
	village.raids.start_raid()
	village.tick(5.0)
	return village


func test_save_then_load_restores_everything() -> void:
	var village: Village = _played_village()
	assert_eq(SaveGame.save_village(village, "slot", {"hints_step": 3}), OK)
	var loaded: Village = SaveGame.load_village("slot")
	assert_not_null(loaded, SaveGame.last_error)
	assert_true(loaded.world.blocks == village.world.blocks, "地形")
	assert_eq(loaded.world.trees.size(), village.world.trees.size())
	assert_eq(loaded.buildings.size(), village.buildings.size(), "建物")
	for id: int in village.buildings:
		var a: Building = village.buildings[id]
		var b: Building = loaded.buildings[id]
		assert_eq(b.type, a.type)
		assert_eq(b.state, a.state)
		assert_eq(b.inventory, a.inventory, "資源")
		assert_eq(b.fixtures, a.fixtures)
	assert_eq(loaded.villagers.size(), village.villagers.size())
	for i in village.villagers.size():
		var a: Villager = village.villagers[i]
		var b: Villager = loaded.villagers[i]
		assert_almost_eq(b.pos.x, a.pos.x, 0.0001, "位置")
		assert_almost_eq(b.pos.y, a.pos.y, 0.0001)
		assert_eq(b.job, a.job, "役職")
		for key in Needs.KEYS:
			assert_almost_eq(b.needs.get_value(key), a.needs.get_value(key), 1e-6, "欲求 " + key)
	assert_eq(loaded.raids.monsters.size(), village.raids.monsters.size(), "魔物")
	assert_gt(loaded.raids.monsters.size(), 0)
	assert_eq(loaded.clock.minutes, village.clock.minutes, "時刻")
	assert_true(loaded.fog.explored == village.fog.explored, "霧")
	assert_eq(loaded.inspection.rejected, village.inspection.rejected, "審査済み希望者")
	assert_eq(loaded.level.level, 1, "村レベル")
	assert_eq(loaded.chief.villager.display_name, village.chief.villager.display_name)
	assert_eq(int(loaded.loaded_extra["hints_step"]), 3)
	assert_eq(loaded.tasks.tasks.size(), village.tasks.tasks.size())
	loaded.tick(30.0)
	village.dispose()
	loaded.dispose()


func test_corrupt_save_is_refused_and_others_survive() -> void:
	var village: Village = Village.new_game(12345)
	assert_eq(SaveGame.save_village(village, "good"), OK)
	assert_eq(SaveGame.save_village(village, "bad"), OK)
	# JSON を壊す
	var file := FileAccess.open(SaveGame.path("bad", "json"), FileAccess.WRITE)
	file.store_string("{\"format_version\": 1, \"seed\": ")
	file.close()
	assert_null(SaveGame.load_village("bad"))
	assert_eq(SaveGame.last_error, "このセーブは読み込めません")
	assert_true(SaveGame.exists("good"), "他のセーブは消えない")
	assert_not_null(SaveGame.load_village("good"))


func test_wrong_version_missing_field_or_bad_terrain_are_refused() -> void:
	var village: Village = Village.new_game(12345)
	SaveGame.save_village(village, "v")
	var state: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveGame.path("v", "json")))
	for broken: Dictionary in [_with(state, "format_version", 99), _without(state, "villagers"), _with(state, "buildings", [{"id": 1}])]:
		var file := FileAccess.open(SaveGame.path("v", "json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(broken))
		file.close()
		assert_null(SaveGame.load_village("v"))
	SaveGame.save_village(village, "t")
	var terrain := FileAccess.open(SaveGame.path("t", "terrain"), FileAccess.READ_WRITE)
	terrain.seek(4)
	terrain.store_8(255)
	terrain.close()
	assert_null(SaveGame.load_village("t"), "地形が壊れていたら読まない")


func test_list_and_delete() -> void:
	var village: Village = Village.new_game(12345)
	SaveGame.save_village(village, "a")
	SaveGame.save_village(village, "b")
	assert_eq(SaveGame.list_saves().size(), 2)
	SaveGame.delete_save("a")
	assert_eq(SaveGame.list_saves(), ["b"] as Array[String])


func _with(state: Dictionary, key: String, value: Variant) -> Dictionary:
	var copy: Dictionary = state.duplicate(true)
	copy[key] = value
	return copy


func _without(state: Dictionary, key: String) -> Dictionary:
	var copy: Dictionary = state.duplicate(true)
	copy.erase(key)
	return copy
