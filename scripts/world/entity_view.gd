class_name EntityView
extends Node3D
## 村人・魔物・ウサギ・建物・地面の物・遺跡・移住希望者・予約の印を表示する(仮の箱。M6-T01 で置き換え)。
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
		if node == null:
			var job_key: String = "chief" if v.is_chief else v.job
			node = _figure(Vector3(0.6, 1.6, 0.6), _ui_color("villager_colors", job_key))
			add_child(node)
			_villagers[v.id] = node
		node.visible = v.state != Villager.State.DEAD and v.state != Villager.State.IN_TREATMENT
		node.position = surface(v.pos) + Vector3(0, 0.8, 0)
		var body: MeshInstance3D = node.get_child(0)
		body.rotation.z = PI * 0.5 if v.state == Villager.State.UNCONSCIOUS else 0.0
		var label: Label3D = node.get_child(1)
		label.text = v.display_name + ("\n「%s」" % v.complaint if not v.complaint.is_empty() else "")


func _sync_monsters() -> void:
	var alive: Dictionary = {}
	for m in village.raids.monsters:
		alive[m.id] = true
		var node: Node3D = _monsters.get(m.id)
		if node == null:
			node = _figure(Vector3(0.7, 1.1, 0.7), _ui_color("entity_colors", "monster"), str(m.def()["name"]))
			add_child(node)
			_monsters[m.id] = node
		node.position = surface(m.pos) + Vector3(0, 0.55, 0)
		node.visible = village.fog.is_monster_visible(m)
	_remove_missing(_monsters, alive)


func _sync_rabbits() -> void:
	var alive: Dictionary = {}
	for id: int in village.wildlife.animals:
		alive[id] = true
		var node: Node3D = _rabbits.get(id)
		if node == null:
			node = _box(Vector3(0.4, 0.35, 0.5), _ui_color("entity_colors", "rabbit"))
			add_child(node)
			_rabbits[id] = node
		var pos: Vector2 = village.wildlife.animals[id]["pos"]
		node.position = surface(pos) + Vector3(0, 0.2, 0)
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
			node = _figure(Vector3(size.x - 0.1, height, size.y - 0.1), _ui_color("building_colors", b.type), "")
			add_child(node)
			_buildings[b.id] = node
		var ground: float = village.world.top_y(b.cell) + 1.0
		var mesh_node: MeshInstance3D = node.get_child(0)
		var built: float = 1.0 if b.is_complete() else 0.25
		mesh_node.scale = Vector3(1.0, built, 1.0)
		mesh_node.transparency = 0.0 if b.is_complete() else 0.5
		node.position = Vector3(b.cell.x + size.x * 0.5, ground + height * built * 0.5, b.cell.y + size.y * 0.5)
		var label: Label3D = node.get_child(1)
		label.text = Texts.t("building_short") if b.short else ""
		label.position.y = height * 0.5 + 0.8
	_remove_missing(_buildings, alive)


func _sync_piles() -> void:
	var alive: Dictionary = {}
	for cell: Vector2i in village.ground_items:
		alive[cell] = true
		var node: Node3D = _piles.get(cell)
		if node == null:
			node = _box(Vector3(0.6, 0.3, 0.6), _ui_color("entity_colors", "pile"))
			add_child(node)
			_piles[cell] = node
		node.position = surface(Vector2(cell) + Vector2(0.5, 0.5)) + Vector3(0, 0.15, 0)
	_remove_missing(_piles, alive)


func _sync_ruins() -> void:
	for site: Dictionary in village.ruins.sites:
		var id: int = int(site["id"])
		var node: Node3D = _ruins.get(id)
		if node == null:
			node = _figure(Vector3(1.2, 2.0, 1.2), _ui_color("entity_colors", "ruin"), Texts.t("ruin_label"))
			add_child(node)
			_ruins[id] = node
		node.position = surface(Vector2(site["cell"]) + Vector2(0.5, 0.5)) + Vector3(0, 1.0, 0)
		node.visible = village.fog.is_explored(site["cell"])
		(node.get_child(0) as MeshInstance3D).transparency = 0.6 if site["looted"] else 0.0


func _sync_applicant() -> void:
	var current: Applicant = village.inspection.current
	if current == null:
		if _applicant != null:
			_applicant.visible = false
		return
	if _applicant == null:
		_applicant = _figure(Vector3(0.6, 1.6, 0.6), _ui_color("entity_colors", "applicant"), "")
		add_child(_applicant)
	_applicant.visible = true
	_applicant.position = surface(current.body.pos) + Vector3(0, 0.8, 0)
	(_applicant.get_child(1) as Label3D).text = Texts.t("applicant_label", {"name": current.display_name})


func _sync_marks() -> void:
	var cells: Array[Vector3] = []
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


## 箱1つとラベル1つの組
func _figure(size: Vector3, color: Color, text: String = "") -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = _box_mesh(size, color)
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
	label.position = Vector3(0, size.y * 0.5 + 0.5, 0)
	label.text = text
	root.add_child(label)
	return root


func _box(size: Vector3, color: Color) -> Node3D:
	var body := MeshInstance3D.new()
	body.mesh = _box_mesh(size, color)
	return body


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
