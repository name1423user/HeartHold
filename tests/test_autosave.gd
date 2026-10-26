extends GutTest

const DIR: String = "user://test_autosaves"


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


func test_every_five_minutes_and_keeps_latest_three() -> void:
	var village: Village = Village.create(12345)
	var autosave := Autosave.new(village)
	assert_false(autosave.update(299.0), "5分未満は保存しない")
	assert_true(autosave.update(1.0), "5分で保存")
	var clocks: Array[float] = []
	for i in 4:
		village.clock.minutes += 100.0
		clocks.append(village.clock.minutes)
		autosave.update(300.0)
	var saves: Array[String] = SaveGame.list_saves()
	assert_eq(saves.size(), 3, "直近3つ")
	assert_eq(SaveGame.load_village("auto_1").clock.minutes, clocks[3], "auto_1 が一番新しい")
	assert_eq(SaveGame.load_village("auto_3").clock.minutes, clocks[1])


func test_failed_write_warns_and_keeps_previous_save() -> void:
	var village: Village = Village.create(12345)
	var autosave := Autosave.new(village)
	assert_eq(autosave.save_now(), OK)
	var previous: float = village.clock.minutes
	# 保存先を「ファイル」にして書けなくする
	DirAccess.make_dir_recursive_absolute(DIR)
	var blocker := FileAccess.open(DIR + "/blocked", FileAccess.WRITE)
	blocker.close()
	SaveGame.directory_override = DIR + "/blocked"
	village.clock.minutes += 500.0
	watch_signals(village)
	assert_ne(autosave.save_now(), OK)
	assert_eq(AlertsHelper.find(self, village, "save_failed"), ["save_failed", "セーブに失敗しました", village.world.start])
	SaveGame.directory_override = DIR
	assert_eq(SaveGame.load_village("auto_1").clock.minutes, previous, "前のセーブは上書きしない")
