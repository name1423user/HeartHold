extends Node
## M6-T02 の計測シーン。本番の Game(村人・魔物・UI)で村人30人+魔物10体の場面を作り、
## 平均・最低fpsを user://logs/bench_game.log に追記して終了する。`-- --duration=秒` で計測時間を変えられる。

@export var world_seed: int = 12345
@export var villager_count: int = 30
@export var monster_count: int = 10
@export var warmup_seconds: float = 3.0
@export var duration_seconds: float = 60.0

var game: Game
var _elapsed: float = 0.0
var _frames: int = 0
var _measure_time: float = 0.0
var _min_fps: float = INF
var _second_frames: int = 0
var _second_time: float = 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--duration="):
			duration_seconds = float(arg.get_slice("=", 1))
	Game.pending_seed = world_seed
	Game.pending_save = ""
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	var village: Village = game.village
	var start: Vector2i = village.world.start
	var storage: Building = village.add_building("storage", start + Vector2i(4, 4), true)
	storage.inventory = {"meal": 150, "log": 40}
	for i in 4:
		village.add_building("house", start + Vector2i(-12 + i * 4, -10), true)
	village.add_building("infirmary", start + Vector2i(-10, 6), true)
	village.add_building("workbench", start + Vector2i(8, -4), true)
	var jobs: Array[String] = Job.ids()
	while village.villagers.size() < villager_count:
		var v: Villager = village.add_villager("村人%d" % village.villagers.size())
		Job.assign(village, v, jobs[village.villagers.size() % jobs.size()])
	Designation.chop_area(village, Rect2i(start - Vector2i(60, 60), Vector2i(120, 120)))
	village.clock.minutes = 6.0 * 1440.0 + 9.0 * 60.0
	village.raids.monsters.clear()
	for i in monster_count:
		var m := Monster.new()
		m.id = i + 1
		m.setup("goblin")
		m.hp = 1.0e6
		m.pos = Vector2(start + Vector2i(30 + i % 4, -6 + i))
		village.raids.monsters.append(m)
	village.raids.active = true
	village.raids.last_raid_at = village.clock.minutes
	game.hud.show_panel(0)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < warmup_seconds:
		return
	_frames += 1
	_measure_time += delta
	_second_frames += 1
	_second_time += delta
	if _second_time >= 1.0:
		_min_fps = minf(_min_fps, _second_frames / _second_time)
		_second_frames = 0
		_second_time = 0.0
	if _measure_time >= duration_seconds:
		_finish()


func _finish() -> void:
	var line: String = "BENCH bench_game renderer=%s/%s villagers=%d monsters=%d seconds=%.1f avg_fps=%.1f min_fps=%.1f" % [
		RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name(),
		game.village.living_villagers().size(), game.village.raids.monsters.size(), _measure_time, _frames / _measure_time, _min_fps]
	print(line)
	DirAccess.make_dir_recursive_absolute("user://logs")
	var path: String = "user://logs/bench_game.log"
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file != null:
		file.seek_end()
		file.store_line(Time.get_datetime_string_from_system() + " " + line)
	get_tree().quit()
