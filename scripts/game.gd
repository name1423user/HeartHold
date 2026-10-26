class_name Game
extends Node3D
## プレイ画面。村のシミュレーションを進め、地形・村人・HUD を表示し、マウス操作を指示に変える。

## タイトル画面から渡す新規ゲームのシード、またはロードするセーブ名
static var pending_seed: int = 12345
static var pending_save: String = ""

var village: Village
var world_view: WorldView
var entities: EntityView
var camera: CameraRig
var hud: Hud
var alerts: AlertLog
var level: VillageLevel
var hints: Hints
var autosave: Autosave
var audio: AudioDirector
## 今の操作: "select" / "chop" / "dig" / "build:<種類>" / "move"
var tool: String = "select"
var selected_villager: int = -1
var selected_building: int = -1
var _drag_start: Variant = null
var _viewer: VoxelViewer


func _ready() -> void:
	Settings.load_settings()
	var loaded: Village = null
	if not pending_save.is_empty():
		loaded = SaveGame.load_village(pending_save)
		if loaded == null:
			push_warning(Texts.t("save_corrupt"))
	start(loaded if loaded != null else Village.new_game(pending_seed))


func start(new_village: Village) -> void:
	if village != null:
		village.dispose()
	for child in get_children():
		child.queue_free()
	village = new_village
	world_view = WorldView.new()
	add_child(world_view)
	world_view.setup(village.world)
	world_view.set_fog(village.fog)
	village.block_changed.connect(world_view.set_block_visual)
	village.trees_changed.connect(world_view.refresh_trees)
	entities = EntityView.new()
	add_child(entities)
	entities.setup(village)
	var focus := Vector3(village.world.start.x, village.world.top_y(village.world.start) + 1, village.world.start.y)
	_viewer = VoxelViewer.new()
	_viewer.view_distance = 256
	_viewer.position = focus
	add_child(_viewer)
	camera = CameraRig.new()
	add_child(camera)
	camera.setup(village.world, focus)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#9cc3d9")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#f2e4c2")
	env.environment.ambient_light_energy = 0.5
	add_child(env)
	alerts = AlertLog.new(village)
	level = village.level
	hints = Hints.new(village)
	hints.step = int(village.loaded_extra.get("hints_step", 0))
	autosave = Autosave.new(village)
	autosave.extra_source = func() -> Dictionary: return {"hints_step": hints.step}
	audio = AudioDirector.new()
	add_child(audio)
	audio.setup(village, alerts)
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)


func _process(delta: float) -> void:
	if village == null:
		return
	village.tick(village.clock.real_to_minutes(delta))
	autosave.update(delta)
	hints.update()
	entities.update_view()
	_viewer.position = camera.position


func load_save(save_name: String) -> void:
	var loaded: Village = SaveGame.load_village(save_name)
	if loaded == null:
		hud.toast(SaveGame.last_error)
		return
	start(loaded)


func toggle_pause() -> void:
	village.clock.paused = not village.clock.paused


func set_tool(new_tool: String) -> void:
	tool = new_tool
	_drag_start = null
	hud.refresh_tool()


func focus_cell(cell: Vector2i) -> void:
	if village.world.in_bounds_2d(cell):
		camera.focus_on(Vector3(cell.x + 0.5, village.world.top_y(cell) + 1.0, cell.y + 0.5))


## キーボードの近道(AC-050)。ボタンに焦点があってもスペースは一時停止に使う
func _input(event: InputEvent) -> void:
	if village == null or not event is InputEventKey:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if event.is_action_pressed("toggle_pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		hud.toggle_pause_menu()
		get_viewport().set_input_as_handled()
	else:
		for i in 4:
			if event.is_action_pressed("panel_%d" % (i + 1)):
				hud.toggle_panel(i)
				get_viewport().set_input_as_handled()
				return


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var button := event as InputEventMouseButton
	if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed and tool != "select":
		set_tool("select")
		return
	if button.button_index != MOUSE_BUTTON_LEFT:
		return
	var hit: Variant = world_view.pick_block(camera.get_camera(), button.position)
	if hit == null:
		return
	var pos: Vector3i = hit
	var cell := Vector2i(pos.x, pos.z)
	if button.pressed:
		_drag_start = cell
		return
	if _drag_start == null:
		return
	var start: Vector2i = _drag_start
	_drag_start = null
	_apply_tool(start, cell)


func _apply_tool(start: Vector2i, end: Vector2i) -> void:
	var area := Rect2i(Vector2i(mini(start.x, end.x), mini(start.y, end.y)), (start - end).abs() + Vector2i.ONE)
	if tool == "chop":
		var count: int = Designation.chop_area(village, area)
		hud.toast(Texts.t("chop_created", {"count": count}) if count > 0 else Texts.t("nothing_to_chop"))
	elif tool == "dig":
		var result: Dictionary = Designation.dig_area(village, area)
		hud.toast(Texts.t("dig_created", {"count": result["created"]}) if int(result["created"]) > 0 else str(result["message"]))
	elif tool.begins_with("build:"):
		var type: String = tool.get_slice(":", 1)
		var result: Dictionary = village.plan_building_checked(type, end, level.level)
		hud.toast(Texts.t("build_planned", {"name": GameData.get_dict("buildings")[type]["name"]}) if result["ok"] else str(result["message"]))
		if result["ok"] and not Input.is_key_pressed(KEY_SHIFT):
			set_tool("select")
	elif tool == "move":
		var v: Villager = village.get_villager(selected_villager)
		if v == null:
			hud.toast(Texts.t("select_villager_first"))
		else:
			var result: Dictionary = DirectOrder.move(village, v, end)
			hud.toast(Texts.t("order_ok", {"name": v.display_name}) if result["ok"] else str(result["message"]))
		set_tool("select")
	else:
		_select_at(end)
	hud.refresh_now()


func _select_at(cell: Vector2i) -> void:
	var best: Villager = null
	var best_distance: float = 1.6
	for v in village.villagers:
		var distance: float = v.pos.distance_to(Vector2(cell) + Vector2(0.5, 0.5))
		if v.state != Villager.State.DEAD and distance < best_distance:
			best = v
			best_distance = distance
	if best != null:
		selected_villager = best.id
		hud.show_panel(0)
		return
	var building_id: int = int(village.world.blocked.get(cell, -1))
	if village.buildings.has(building_id):
		selected_building = building_id
		hud.show_panel(2)


## マウスの下にある建物(説明表示用)
func building_under_mouse() -> Building:
	var hit: Variant = world_view.pick_block(camera.get_camera(), get_viewport().get_mouse_position())
	if hit == null:
		return null
	var pos: Vector3i = hit
	return village.buildings.get(int(village.world.blocked.get(Vector2i(pos.x, pos.z), -1))) as Building
