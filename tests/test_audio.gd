extends GutTest

var game: Game


func before_each() -> void:
	Game.pending_seed = 12345
	Game.pending_save = ""
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child_autofree(game)


func test_each_alert_kind_has_its_own_sound() -> void:
	var sounds: Dictionary = {}
	for kind in ["raid", "applicant", "faint", "hunger", "death"]:
		var sound: String = game.alerts.sound(kind)
		assert_true(ResourceLoader.exists(str(AudioDirector.cfg()["sounds"][sound])), kind)
		sounds[sound] = true
	assert_eq(sounds.size(), 5, "種類ごとに違う音")
	game.village.raise_alert("raid", "テスト", game.village.world.start)
	assert_eq(game.audio.last_sound, "raid", "警告で鳴る")


func test_work_sounds() -> void:
	var village: Village = game.village
	for sound in ["chop", "dig", "build_done"]:
		village.sound_event.emit(sound)
		assert_eq(game.audio.last_sound, sound)
	var house: Building = village.plan_building("house", village.world.start + Vector2i(-8, 6))["building"]
	var storage: Building = village.add_building("storage", village.world.start + Vector2i(6, 6), true)
	storage.inventory = {"plank": 8, "log": 4}
	watch_signals(village)
	for i in 60:
		village.tick(10.0)
		if house.is_complete():
			break
	assert_signal_emitted_with_parameters(village, "sound_event", ["build_done"])


func test_bgm_switches_between_day_and_night() -> void:
	game.village.clock.minutes = 12.0 * 60.0
	game.audio.update_bgm()
	assert_eq(game.audio.current_bgm, "day")
	game.village.clock.minutes = 22.0 * 60.0
	game.audio.update_bgm()
	assert_eq(game.audio.current_bgm, "night")
	assert_true(game.audio.bgm_player.playing)


func test_volume_settings_change_buses() -> void:
	var before: Dictionary = Settings.volumes.duplicate()
	Settings.volumes["BGM"] = 0.5
	Settings.volumes["SFX"] = 0.25
	Settings.volumes["Master"] = 1.0
	AudioDirector.apply_volumes()
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM")), linear_to_db(0.5), 0.01)
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), linear_to_db(0.25), 0.01)
	Settings.volumes = before
	AudioDirector.apply_volumes()
