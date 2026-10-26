extends Node3D
## 地形の確認用シーン。シードから生成して表示する。

@export var world_seed: int = 12345


func _ready() -> void:
	var world: WorldData = TerrainGenerator.generate(world_seed)
	var view: WorldView = $WorldView
	view.setup(world)
	var viewer := VoxelViewer.new()
	viewer.view_distance = 256
	viewer.position = Vector3(world.start.x, world.top_y(world.start), world.start.y)
	add_child(viewer)
	var camera: Camera3D = $Camera3D
	camera.position = Vector3(world.start.x - 40, world.top_y(world.start) + 50, world.start.y + 60)
	camera.look_at(Vector3(world.start.x, world.top_y(world.start), world.start.y))
