extends GutTest

var world: WorldData


func before_all() -> void:
	world = TerrainGenerator.generate(12345)


func test_zoom_and_pitch_are_clamped_and_camera_stays_above_ground() -> void:
	var rig := CameraRig.new()
	add_child_autofree(rig)
	rig.setup(world, Vector3(world.start.x, 0, world.start.y))
	rig.zoom(1000.0)
	assert_eq(rig.distance, float(rig.cfg["max_distance"]))
	rig.zoom(0.0001)
	assert_eq(rig.distance, float(rig.cfg["min_distance"]))
	rig.pitch = -1.0
	rig.zoom(1.0)
	assert_almost_eq(rig.pitch, deg_to_rad(float(rig.cfg["min_pitch_degrees"])), 0.0001, "地面の下を見上げない")
	# 山の方へ向けても、カメラは地表より上
	for i in 16:
		rig.yaw = TAU * i / 16.0
		rig.zoom(1.0)
		var eye: Vector3 = rig.get_camera().global_position
		var cell := Vector2i(clampi(int(eye.x), 0, 255), clampi(int(eye.z), 0, 255))
		assert_gt(eye.y, float(world.top_y(cell)) + 1.0)
