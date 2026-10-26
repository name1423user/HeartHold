extends Node3D
## 地形の確認用シーン。シードから生成して表示する。

@export var world_seed: int = 12345


func _ready() -> void:
	var world: WorldData = TerrainGenerator.generate(world_seed)
	var view: WorldView = $WorldView
	view.setup(world)
	var focus := Vector3(world.start.x, world.top_y(world.start) + 1, world.start.y)
	var viewer := VoxelViewer.new()
	viewer.view_distance = 256
	viewer.position = focus
	add_child(viewer)
	var rig: CameraRig = $CameraRig
	rig.setup(world, focus)
