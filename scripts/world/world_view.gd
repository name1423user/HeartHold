class_name WorldView
extends Node3D
## WorldData を VoxelTerrain と木のメッシュで表示する。

const TREE_TRUNK_HEIGHT: float = 3.0

var world: WorldData
var terrain: VoxelTerrain
var _trees: MultiMeshInstance3D
var _tree_cells: Array = []


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
	terrain.bounds = AABB(Vector3.ZERO, Vector3(world.size))
	terrain.max_view_distance = 512
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	terrain.material_override = material
	add_child(terrain)
	_build_trees()


## 表示側のブロックを書き換える(WorldData は TerrainEditor が更新済み)
func set_block_visual(pos: Vector3i, id: int) -> void:
	if terrain != null:
		var tool: VoxelTool = terrain.get_voxel_tool()
		tool.channel = VoxelBuffer.CHANNEL_TYPE
		tool.set_voxel(pos, id)
	var generator := terrain.generator as WorldVoxelGenerator
	generator.source.set_voxel(id, pos.x, pos.y, pos.z, VoxelBuffer.CHANNEL_TYPE)


func refresh_trees() -> void:
	_build_trees()


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
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.6, TREE_TRUNK_HEIGHT, 0.6)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(GameData.get_dict("terrain").get("tree_color", "#2f5d2a"))
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	_tree_cells = world.trees.keys()
	multimesh.instance_count = _tree_cells.size()
	for i in _tree_cells.size():
		var cell: Vector2i = _tree_cells[i]
		var base_y: float = world.top_y(cell) + 1.0
		multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(cell.x + 0.5, base_y + TREE_TRUNK_HEIGHT * 0.5, cell.y + 0.5)))
	_trees.multimesh = multimesh
