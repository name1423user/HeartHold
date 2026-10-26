class_name EntityView
extends Node3D
## 村人・魔物・ウサギ・建物・地面の物・遺跡・移住希望者・予約の印を表示する。
## 見た目は assets/voxel/*.vox(tools/make_vox.py で作る自作素材)。なければ色の箱で代わりに出す。
## 霧の中の魔物とウサギは表示しない(AC-022)。

var village: Village
var _villagers: Dictionary = {}
var _monsters: Dictionary = {}
var _rabbits: Dictionary = {}
var _buildings: Dictionary = {}
var _piles: Dictionary = {}
var _ruins: Dictionary = {}
var _applicant: Node3D
var _marks: MultiMeshInstance3D
var _materials: Dictionary = {}
var _meshes: Dictionary = {}


func setup(target: Village) -> void:
	village = target
	_marks = MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var mark := BoxMesh.new()
	mark.size = Vector3(0.25, 0.6, 0.25)
	mark.material = _material(_ui_color("entity_colors", "task"))
	multimesh.mesh = mark
	_marks.multimesh = multimesh
	add_child(_marks)


func update_view() -> void:
	_sync_villagers()
	_sync_monsters()
	_sync_rabbits()
	_sync_buildings()
	_sync_piles()
	_sync_ruins()
	_sync_applicant()
	_sync_marks()


func surface(pos: Vector2) -> Vector3:
	var cell := Vector2i(floori(pos.x), floori(pos.y))
	if not village.world.in_bounds_2d(cell):
		return Vector3(pos.x, 0.0, pos.y)
	return Vector3(pos.x, village.world.top_y(cell) + 1.0, pos.y)


func _sync_villagers() -> void:
	for v in village.villagers:
		var node: Node3D = _villagers.get(v.id)
		var job_key: String = "chief" if v.is_chief else v.job
		if node == null or node.get_meta("job") != job_key:
			if node != null:
				node.queue_free()
			var model: String = "chief" if v.is_chief else "villager_" + v.job
			node = _figure(model, Vector3(0.6, 1.6, 0.6), _ui_color("villager_colors", job_key))
			node.set_meta("job", job_key)
			add_child(node)
			_villagers[v.id] = node
		node.visible = v.state != Villager.State.DEAD and v.state != Villager.State.IN_TREATMENT
		_move(node, surface(v.pos))
		var body: Node3D = node.get_child(0)
		body.rotation.z = PI * 0.5 if v.state == Villager.State.UNCONSCIOUS else 0.0
		var label: Label3D = node.get_child(1)
		var said: String = v.complaint if not v.complaint.is_empty() else v.line
		label.text = v.display_name + ("\n「%s」" % said if not said.is_empty() else "")


func _sync_monsters() -> void:
	var alive: Dictionary = {}
	for m in village.raids.monsters:
		alive[m.id] = true
		var node: Node3D = _monsters.get(m.id)
		if node == null:
			node = _figure(m.type, Vector3(0.7, 1.1, 0.7), _ui_color("entity_colors", "monster"), str(m.def()["name"]))
			add_child(node)
			_monsters[m.id] = node
		_move(node, surface(m.pos))
		node.visible = village.fog.is_monster_visible(m)
	_remove_missing(_monsters, alive)


func _sync_rabbits() -> void:
	var alive: Dictionary = {}
	for id: int in village.wildlife.animals:
		alive[id] = true
		var node: Node3D = _rabbits.get(id)
		if node == null:
			node = _figure("rabbit", Vector3(0.4, 0.35, 0.5), _ui_color("entity_colors", "rabbit"))
			add_child(node)
			_rabbits[id] = node
		var pos: Vector2 = village.wildlife.animals[id]["pos"]
		_move(node, surface(pos))
		node.visible = village.fog.is_visible(village.wildlife.cell_of(id))
	_remove_missing(_rabbits, alive)


func _sync_buildings() -> void:
	var heights: Dictionary = GameData.get_dict("ui")["building_heights"]
	var alive: Dictionary = {}
	for b: Building in village.buildings.values():
		alive[b.id] = true
		var node: Node3D = _buildings.get(b.id)
		var size: Vector2i = b.size()
		var height: float = float(heights.get(b.type, 2.0))
		if node == null:
			node = _figure(b.type, Vector3(size.x - 0.1, height, size.y - 0.1), _ui_color("building_colors", b.type), "", size)
			add_child(node)
			_buildings[b.id] = node
		var ground: float = village.world.top_y(b.cell) + 1.0
		var body: Node3D = node.get_child(0)
		# 建設中は低く半透明に見せる
		body.scale = Vector3(1.0, 1.0 if b.is_complete() else 0.3, 1.0)
		_set_transparency(body, 0.0 if b.is_complete() else 0.5)
		node.position = Vector3(b.cell.x + size.x * 0.5, ground, b.cell.y + size.y * 0.5)
		var label: Label3D = node.get_child(1)
		label.text = Texts.t("building_short") if b.short else ""
	_remove_missing(_buildings, alive)


func _sync_piles() -> void:
	var alive: Dictionary = {}
	for cell: Vector2i in village.ground_items:
		alive[cell] = true
		var node: Node3D = _piles.get(cell)
		if node == null:
			node = _figure("", Vector3(0.6, 0.3, 0.6), _ui_color("entity_colors", "pile"))
			add_child(node)
			_piles[cell] = node
		node.position = surface(Vector2(cell) + Vector2(0.5, 0.5))
	_remove_missing(_piles, alive)


func _sync_ruins() -> void:
	for site: Dictionary in village.ruins.sites:
		var id: int = int(site["id"])
		var node: Node3D = _ruins.get(id)
		if node == null:
			node = _figure("ruin", Vector3(1.2, 2.0, 1.2), _ui_color("entity_colors", "ruin"), Texts.t("ruin_label"))
			add_child(node)
			_ruins[id] = node
		node.position = surface(Vector2(site["cell"]) + Vector2(0.5, 0.5))
		node.visible = village.fog.is_explored(site["cell"])
		_set_transparency(node.get_child(0), 0.6 if site["looted"] else 0.0)


func _sync_applicant() -> void:
	var current: Applicant = village.inspection.current
	if current == null:
		if _applicant != null:
			_applicant.visible = false
		return
	if _applicant == null:
		_applicant = _figure("applicant", Vector3(0.6, 1.6, 0.6), _ui_color("entity_colors", "applicant"), "")
		add_child(_applicant)
	_applicant.visible = true
	_move(_applicant, surface(current.body.pos))
	(_applicant.get_child(1) as Label3D).text = Texts.t("applicant_label", {"name": current.display_name})


func _sync_marks() -> void:
	var cells: Array[Vector3] = []
	var regrowth: Regrowth = village.system("regrowth") as Regrowth
	for cell: Vector2i in regrowth.saplings:
		cells.append(Vector3(cell.x + 0.5, village.world.top_y(cell) + 1.3, cell.y + 0.5))
	for task: JobTask in village.tasks.tasks.values():
		if task.type == "chop" or task.type == "dig":
			cells.append(Vector3(task.cell.x + 0.5, village.world.top_y(task.cell) + 1.3, task.cell.y + 0.5))
	var multimesh: MultiMesh = _marks.multimesh
	multimesh.instance_count = cells.size()
	for i in cells.size():
		multimesh.set_instance_transform(i, Transform3D(Basis(), cells[i] + Vector3(0, 1.5 if village.world.trees.has(Vector2i(floori(cells[i].x), floori(cells[i].z))) else 0.0, 0)))


func _remove_missing(nodes: Dictionary, alive: Dictionary) -> void:
	for key: Variant in nodes.keys():
		if not alive.has(key):
			(nodes[key] as Node3D).queue_free()
			nodes.erase(key)


## 足元を原点にした体(.vox のモデルか色の箱)とラベルの組。footprint を渡すと向きを合わせる
func _figure(model: String, size: Vector3, color: Color, text: String = "", footprint: Vector2i = Vector2i.ZERO) -> Node3D:
	var root := Node3D.new()
	var body: Node3D = _model(model, footprint)
	var height: float = size.y
	if body == null:
		var box := MeshInstance3D.new()
		box.mesh = _box_mesh(size, color)
		box.position.y = size.y * 0.5
		body = Node3D.new()
		body.add_child(box)
	else:
		height = float(body.get_meta("height"))
	root.add_child(body)
	var label := Label3D.new()
	label.font = UiTheme.font()
	label.font_size = 64
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 8
	label.modulate = Color.WHITE
	label.outline_modulate = UiTheme.color("ink")
	label.position = Vector3(0, height + 0.5, 0)
	label.text = text
	root.add_child(label)
	return root


## .vox のモデルを、足元の中心が原点になるように包む
func _model(model: String, footprint: Vector2i) -> Node3D:
	var path: String = str(GameData.get_dict("ui")["models"].get(model, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	var instance: Node3D = scene.instantiate()
	var meshes: Array[Node] = instance.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		instance.free()
		return null
	var aabb: AABB = (meshes[0] as MeshInstance3D).get_aabb()
	var wrapper := Node3D.new()
	var pivot := Node3D.new()
	wrapper.add_child(pivot)
	pivot.add_child(instance)
	instance.position = Vector3(-aabb.size.x * 0.5, 0.0, -aabb.size.z * 0.5) - Vector3(aabb.position.x, aabb.position.y, aabb.position.z)
	# 建物の向きを敷地(幅×奥行き)に合わせる
	if footprint != Vector2i.ZERO and (aabb.size.x > aabb.size.z) != (footprint.x > footprint.y) and footprint.x != footprint.y:
		pivot.rotation.y = PI * 0.5
	wrapper.set_meta("height", aabb.size.y)
	return wrapper


## 動いた向きに体を向ける
func _move(node: Node3D, target: Vector3) -> void:
	var delta: Vector3 = target - node.position
	if Vector2(delta.x, delta.z).length() > 0.01:
		(node.get_child(0) as Node3D).rotation.y = atan2(delta.x, delta.z)
	node.position = target


func _set_transparency(body: Node, value: float) -> void:
	for mesh in body.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).transparency = value


func _box_mesh(size: Vector3, color: Color) -> BoxMesh:
	var key: String = "%s|%s" % [size, color.to_html()]
	if not _meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh.material = _material(color)
		_meshes[key] = mesh
	return _meshes[key]


func _material(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		_materials[key] = material
	return _materials[key]


func _ui_color(group: String, key: String) -> Color:
	return Color(str(GameData.get_dict("ui")[group].get(key, "#ffffff")))
