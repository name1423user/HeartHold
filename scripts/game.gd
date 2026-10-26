class_name Game
extends Node3D
## プレイ画面。村のシミュレーションを進め、地形・村人・HUD を表示し、マウス操作を指示に変える。

## タイトル画面から渡す新規ゲームのシード、またはロードするセーブ名
static var pending_seed: int = 12345
static var pending_save: String = ""
## タイトルで「チュートリアルで始める」を選んだ
static var pending_tutorial: bool = false

var village: Village
var world_view: WorldView
var entities: EntityView
var camera: CameraRig
var hud: Hud
var alerts: AlertLog
var level: VillageLevel
var hints: Hints
var tutorial: Tutorial
var autosave: Autosave
var audio: AudioDirector
## 今の操作: "select" / "chop" / "dig" / "build:<種類>" / "move"
var tool: String = "select"
var selected_villager: int = -1
var selected_building: int = -1
## 視察隊に入れる村人
var expedition_members: Array = []
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
	_setup_weather()
	alerts = AlertLog.new(village)
	level = village.level
	hints = Hints.new(village)
	hints.step = int(village.loaded_extra.get("hints_step", 0))
	tutorial = Tutorial.new(village)
	tutorial.active = bool(village.loaded_extra.get("tutorial_active", pending_tutorial and pending_save.is_empty()))
	tutorial.step = int(village.loaded_extra.get("tutorial_step", 0))
	autosave = Autosave.new(village)
	autosave.extra_source = func() -> Dictionary: return extra_state()
	audio = AudioDirector.new()
	add_child(audio)
	audio.setup(village, alerts)
	village.inspection.require_decision = true
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)


func _process(delta: float) -> void:
	if village == null:
		return
	village.tick(village.clock.real_to_minutes(delta))
	autosave.update(delta)
	hints.update()
	tutorial.update()
	entities.update_view()
	_viewer.position = camera.position
	_rain.position = camera.position + Vector3(0, 25, 0)


var _rain: GPUParticles3D


## 冬の雪と、雨・雪の粒(カメラのまわりに降らせる)
func _setup_weather() -> void:
	var cal: Calendar = village.calendar()
	_rain = GPUParticles3D.new()
	_rain.amount = 800
	_rain.lifetime = 1.5
	_rain.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(35, 1, 35)
	process.direction = Vector3(0, -1, 0)
	process.initial_velocity_min = 18.0
	process.initial_velocity_max = 22.0
	process.gravity = Vector3(0, -9.8, 0)
	_rain.process_material = process
	var drop := BoxMesh.new()
	drop.size = Vector3(0.03, 0.4, 0.03)
	var drop_material := StandardMaterial3D.new()
	drop_material.albedo_color = Color(0.75, 0.82, 0.95, 0.6)
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material = drop_material
	_rain.draw_pass_1 = drop
	add_child(_rain)
	cal.weather_changed.connect(func(_w: String) -> void: _apply_weather())
	cal.season_changed.connect(func(_s: String) -> void: _apply_weather())
	_apply_weather()


func _apply_weather() -> void:
	var cal: Calendar = village.calendar()
	world_view.set_snow(1.0 if cal.season_id() == "winter" else 0.0)
	_rain.emitting = cal.weather in ["rain", "storm", "snow"]
	var process := _rain.process_material as ParticleProcessMaterial
	process.initial_velocity_min = 3.0 if cal.weather == "snow" else 18.0
	process.initial_velocity_max = 4.0 if cal.weather == "snow" else 22.0


func load_save(save_name: String) -> void:
	var loaded: Village = SaveGame.load_village(save_name)
	if loaded == null:
		hud.toast(SaveGame.last_error)
		return
	start(loaded)


## セーブに入れる画面側の状態
func extra_state() -> Dictionary:
	return {"hints_step": hints.step, "tutorial_active": tutorial.active, "tutorial_step": tutorial.step}


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
	elif tool == "plant":
		var planted: int = (village.system("regrowth") as Regrowth).plant_area(area)
		hud.toast(Texts.t("plant_created", {"count": planted}))
	elif tool == "dig":
		var result: Dictionary = Designation.dig_area(village, area)
		hud.toast(Texts.t("dig_created", {"count": result["created"]}) if int(result["created"]) > 0 else str(result["message"]))
	elif tool.begins_with("build:"):
		var type: String = tool.get_slice(":", 1)
		var result: Dictionary = village.plan_building_checked(type, end, level.level)
		hud.toast(Texts.t("build_planned", {"name": GameData.get_dict("buildings")[type]["name"]}) if result["ok"] else str(result["message"]))
		if result["ok"] and not Input.is_key_pressed(KEY_SHIFT):
			set_tool("select")
	elif tool == "expedition":
		var members: Array[Villager] = []
		for id: int in expedition_members:
			var member: Villager = village.get_villager(id)
			if member != null:
				members.append(member)
		var sent: Dictionary = (village.system("expeditions") as Expeditions).send(members, end)
		hud.toast(str(sent.get("message", "")) if not sent["ok"] else Texts.t("alert_expedition_sent", {"count": members.size()}))
		if sent["ok"]:
			expedition_members.clear()
		set_tool("select")
	elif tool == "farsight":
		var mage: Villager = null
		for v in village.living_villagers():
			if Magic.is_mage(v):
				mage = v
		var cast: Dictionary = (village.system("magic") as Magic).cast(mage, "farsight", end) if mage != null else {"ok": false, "message": Texts.t("magic_not_mage")}
		hud.toast(str(cast.get("message", "")))
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
