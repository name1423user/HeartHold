extends Node3D
## POC-001 のベンチ。仮の村人(箱)が別々の目的地へ歩き続け、毎秒 edits_per_second 個のブロックを壊す・置く。
## 計測後に平均・最低fpsをログに出して終了する。`-- --duration=秒` で計測時間を変えられる。

@export var world_seed: int = 12345
@export var villager_count: int = 30
@export var walk_speed: float = 3.0
@export var edits_per_second: int = 10
@export var warmup_seconds: float = 3.0
@export var duration_seconds: float = 60.0
@export var roam_radius: int = 60

var world: WorldData
var pathing: Pathing
var editor: TerrainEditor
var rng := RandomNumberGenerator.new()
var walkers: Array[Dictionary] = []
var _elapsed: float = 0.0
var _edit_timer: float = 0.0
var _frames: int = 0
var _measure_time: float = 0.0
var _min_fps: float = INF
var _second_frames: int = 0
var _second_time: float = 0.0

@onready var view: WorldView = $WorldView


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--duration="):
			duration_seconds = float(arg.get_slice("=", 1))
	rng.seed = world_seed
	world = TerrainGenerator.generate(world_seed)
	pathing = Pathing.new(world)
	editor = TerrainEditor.new(world)
	editor.block_changed.connect(_on_block_changed)
	view.setup(world)
	var viewer := VoxelViewer.new()
	viewer.view_distance = 256
	viewer.position = _surface(world.start)
	add_child(viewer)
	var camera: Camera3D = $Camera3D
	camera.position = _surface(world.start) + Vector3(-50, 60, 50)
	camera.look_at(_surface(world.start))
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.6, 1.6, 0.6)
	for i in villager_count:
		var body := MeshInstance3D.new()
		body.mesh = mesh
		add_child(body)
		var cell: Vector2i = world.start + Vector2i(i % 6, i / 6)
		body.position = _surface(cell)
		walkers.append({"body": body, "cell": cell, "path": [] as Array[Vector2i]})


func _process(delta: float) -> void:
	_elapsed += delta
	_update_walkers(delta)
	_edit_timer += delta
	var interval: float = 1.0 / edits_per_second
	while _edit_timer >= interval:
		_edit_timer -= interval
		_random_edit()
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


func _update_walkers(delta: float) -> void:
	for walker in walkers:
		var path: Array[Vector2i] = walker["path"]
		if path.is_empty():
			var target: Vector2i = world.start + Vector2i(rng.randi_range(-roam_radius, roam_radius), rng.randi_range(-roam_radius, roam_radius))
			walker["path"] = pathing.find_path(walker["cell"], target)
			continue
		var body: MeshInstance3D = walker["body"]
		var next: Vector3 = _surface(path[0])
		var step: float = walk_speed * delta
		if body.position.distance_to(next) <= step:
			body.position = next
			walker["cell"] = path.pop_front()
		else:
			body.position = body.position.move_toward(next, step)


func _random_edit() -> void:
	var cell: Vector2i = world.start + Vector2i(rng.randi_range(-roam_radius, roam_radius), rng.randi_range(-roam_radius, roam_radius))
	if not world.in_bounds_2d(cell) or not world.is_walkable(cell):
		return
	var top: int = world.top_y(cell)
	if top >= world.original_top_y(cell):
		editor.break_block(Vector3i(cell.x, top, cell.y))
	else:
		editor.place_block(Vector3i(cell.x, top + 1, cell.y), world.block_id("dirt"))


func _on_block_changed(pos: Vector3i, id: int) -> void:
	view.set_block_visual(pos, id)
	pathing.update_cell(Vector2i(pos.x, pos.z))


func _surface(cell: Vector2i) -> Vector3:
	return Vector3(cell.x + 0.5, world.top_y(cell) + 1.8, cell.y + 0.5)


func _finish() -> void:
	var average: float = _frames / _measure_time
	var line: String = "BENCH bench_30 renderer=%s villagers=%d edits/s=%d seconds=%.1f avg_fps=%.1f min_fps=%.1f" % [
		RenderingServer.get_current_rendering_method() + "/" + RenderingServer.get_current_rendering_driver_name(), villager_count, edits_per_second,
		_measure_time, average, _min_fps]
	print(line)
	DirAccess.make_dir_recursive_absolute("user://logs")
	var file := FileAccess.open("user://logs/bench_30.log", FileAccess.READ_WRITE if FileAccess.file_exists("user://logs/bench_30.log") else FileAccess.WRITE)
	if file != null:
		file.seek_end()
		file.store_line(Time.get_datetime_string_from_system() + " " + line)
	get_tree().quit()
