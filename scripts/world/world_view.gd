class_name WorldView
extends Node3D
## WorldData を VoxelTerrain と木のメッシュで表示する。

const TREE_TRUNK_HEIGHT: float = 3.0

const FOG_SHADER: Shader = preload("res://scripts/world/terrain_fog.gdshader")

var world: WorldData
var terrain: VoxelTerrain
var _trees: MultiMeshInstance3D
var _tree_cells: Array = []
var _fog: Fog
var _fog_texture: ImageTexture
var _terrain_material: ShaderMaterial
var _tree_material: ShaderMaterial


func setup(new_world: WorldData) -> void:
	world = new_world
	if terrain != null:
		terrain.queue_free()
	terrain = VoxelTerrain.new()
	terrain.name = "VoxelTerrain"
	terrain.generator = WorldVoxelGenerator.new(world)
	var mesher := VoxelMesherBlocky.new()
	mesher.library = _build_library()
	terrain.mesher = mesher
	if world.infinite:
		terrain.bounds = AABB(Vector3(-world.limit, 0, -world.limit), Vector3(world.limit * 2, world.size.y, world.limit * 2))
	else:
		terrain.bounds = AABB(Vector3.ZERO, Vector3(world.size))
	terrain.max_view_distance = 512
	_terrain_material = _fog_material(true, Color.WHITE)
	_tree_material = _fog_material(true, Color.WHITE)
	terrain.material_override = _terrain_material
	add_child(terrain)
	_build_trees()


## 霧を表示に反映する。fog が null なら全部見える
func set_fog(fog: Fog) -> void:
	_fog = fog
	if fog != null:
		fog.explored_changed.connect(update_fog)
	update_fog()


## 無限の地図では、カメラのまわりの window×window だけを霧のテクスチャにする
var fog_window: int = 512
var fog_origin: Vector2i = Vector2i.ZERO


## カメラが窓の端に近づいたら、窓を動かして霧を描き直す
func follow_camera(center: Vector3) -> void:
	if not world.infinite:
		return
	var c := Vector2i(floori(center.x), floori(center.z))
	var mid: Vector2i = fog_origin + Vector2i(fog_window / 2, fog_window / 2)
	if absi(c.x - mid.x) > fog_window / 4 or absi(c.y - mid.y) > fog_window / 4:
		fog_origin = c - Vector2i(fog_window / 2, fog_window / 2)
		update_fog()


func update_fog() -> void:
	var data := PackedByteArray()
	var w: int = fog_window if world.infinite else world.size.x
	var h: int = fog_window if world.infinite else world.size.z
	if _fog != null:
		data = _fog.explored_window(fog_origin, w) if world.infinite else _fog.explored
	else:
		data.resize(w * h)
		data.fill(1)
	var image := Image.create_from_data(w, h, false, Image.FORMAT_R8, data)
	if _fog_texture == null:
		_fog_texture = ImageTexture.create_from_image(image)
	else:
		_fog_texture.update(image)
	if _fog_texture.get_width() != w:
		_fog_texture = ImageTexture.create_from_image(image)
	for material in [_terrain_material, _tree_material]:
		material.set_shader_parameter("fog_mask", _fog_texture)
		material.set_shader_parameter("fog_origin", Vector2(fog_origin))
		material.set_shader_parameter("map_size", Vector2(w, h))


## 木: 幹と葉の2つの箱(頂点色つき)。足元が原点
func _tree_mesh() -> ArrayMesh:
	var cfg: Dictionary = GameData.get_dict("terrain")
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(tool, Vector3(0, TREE_TRUNK_HEIGHT * 0.35, 0), Vector3(0.35, TREE_TRUNK_HEIGHT * 0.7, 0.35), Color(cfg.get("trunk_color", "#6e4b2a")))
	_add_box(tool, Vector3(0, TREE_TRUNK_HEIGHT * 0.85, 0), Vector3(1.4, TREE_TRUNK_HEIGHT * 0.6, 1.4), Color(cfg.get("tree_color", "#2f5d2a")))
	tool.generate_normals()
	var mesh: ArrayMesh = tool.commit()
	mesh.surface_set_material(0, _tree_material)
	return mesh


func _add_box(tool: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays: Array = box.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		tool.set_color(color)
		tool.add_vertex(vertices[index] + center)


func set_snow(amount: float) -> void:
	for material in [_terrain_material, _tree_material]:
		material.set_shader_parameter("snow", amount)


func _fog_material(vertex_color: bool, base: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FOG_SHADER
	material.set_shader_parameter("map_size", Vector2(world.size.x, world.size.z))
	material.set_shader_parameter("use_vertex_color", vertex_color)
	material.set_shader_parameter("base_color", base)
	return material


## 表示側のブロックを書き換える(WorldData は TerrainEditor が更新済み)
func set_block_visual(pos: Vector3i, id: int) -> void:
	if terrain != null:
		var tool: VoxelTool = terrain.get_voxel_tool()
		tool.channel = VoxelBuffer.CHANNEL_TYPE
		tool.set_voxel(pos, id)
	var generator := terrain.generator as WorldVoxelGenerator
	if generator.source != null:
		generator.source.set_voxel(id, pos.x, pos.y, pos.z, VoxelBuffer.CHANNEL_TYPE)


func refresh_trees() -> void:
	_build_trees()


## 画面上の点から地形のブロックを探す。当たらなければ null
func pick_block(camera: Camera3D, screen_pos: Vector2) -> Variant:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var hit: VoxelRaycastResult = terrain.get_voxel_tool().raycast(origin, direction, 600.0)
	if hit != null:
		return hit.position
	# 読み込み前などで当たらないときは、地表の高さの面で近似する
	if absf(direction.y) < 0.0001:
		return null
	var t: float = (float(world.top_y(world.start)) + 1.0 - origin.y) / direction.y
	if t < 0.0:
		return null
	var p: Vector3 = origin + direction * t
	var cell := Vector2i(floori(p.x), floori(p.z))
	if not world.in_bounds_2d(cell):
		return null
	return Vector3i(cell.x, world.top_y(cell), cell.y)


func _build_library() -> VoxelBlockyLibrary:
	var cfg: Dictionary = GameData.get_dict("terrain")
	var ids: Dictionary = cfg["blocks"]
	var colors: Dictionary = cfg["block_colors"]
	var by_id: Dictionary = {}
	for block_name: String in ids:
		by_id[int(ids[block_name])] = block_name
	var library := VoxelBlockyLibrary.new()
	var models: Array[VoxelBlockyModel] = []
	for id in range(by_id.keys().max() + 1):
		var block_name: String = by_id.get(id, "air")
		if block_name == "air" or not colors.has(block_name):
			models.append(VoxelBlockyModelEmpty.new())
			continue
		var cube := VoxelBlockyModelCube.new()
		cube.color = Color(colors[block_name])
		if block_name == "water":
			cube.transparency_index = 1
			cube.culls_neighbors = false
		models.append(cube)
	library.models = models
	return library


func _build_trees() -> void:
	if _trees == null:
		_trees = MultiMeshInstance3D.new()
		_trees.name = "Trees"
		add_child(_trees)
	var mesh: ArrayMesh = _tree_mesh()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	_tree_cells = world.trees.keys()
	multimesh.instance_count = _tree_cells.size()
	for i in _tree_cells.size():
		var cell: Vector2i = _tree_cells[i]
		var base_y: float = world.top_y(cell) + 1.0
		multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(cell.x + 0.5, base_y, cell.y + 0.5)))
	_trees.multimesh = multimesh
