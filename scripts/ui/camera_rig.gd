class_name CameraRig
extends Node3D
## 斜め上からのカメラ(AC-029)。右ドラッグ/Q・E で回転、ホイールでズーム、WASD/中ドラッグで平行移動。
## キーは入力マップの cam_* で、設定から変えられる(M11-T03)。
## ズームと俯角は data/camera.json の範囲に制限し、カメラが地面より下に入らないようにする。

var world: WorldData
var yaw: float = 0.0
var pitch: float = 0.0
var distance: float = 60.0
var cfg: Dictionary = {}
var _camera: Camera3D


func _ready() -> void:
	cfg = GameData.get_dict("camera")
	distance = float(cfg["start_distance"])
	pitch = deg_to_rad(float(cfg["start_pitch_degrees"]))
	_camera = Camera3D.new()
	_camera.far = 1000.0
	add_child(_camera)
	_apply()


func setup(new_world: WorldData, focus: Vector3) -> void:
	world = new_world
	position = focus
	_apply()


func get_camera() -> Camera3D:
	return _camera


func focus_on(target: Vector3) -> void:
	position = target
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			yaw -= motion.relative.x * float(cfg["rotate_speed"])
			pitch += motion.relative.y * float(cfg["rotate_speed"])
			_apply()
		elif motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			_pan(Vector2(-motion.relative.x, -motion.relative.y) * distance * 0.002)
	elif event is InputEventMouseButton and event.pressed:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(1.0 / float(cfg["zoom_step"]))
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(float(cfg["zoom_step"]))


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_action_pressed("cam_forward"):
		move.y -= 1.0
	if Input.is_action_pressed("cam_back"):
		move.y += 1.0
	if Input.is_action_pressed("cam_left"):
		move.x -= 1.0
	if Input.is_action_pressed("cam_right"):
		move.x += 1.0
	if move != Vector2.ZERO:
		_pan(move.normalized() * float(cfg["pan_speed"]) * delta * (distance / float(cfg["start_distance"])))
	var turn: float = 0.0
	if Input.is_action_pressed("cam_rotate_left"):
		turn += 1.0
	if Input.is_action_pressed("cam_rotate_right"):
		turn -= 1.0
	if turn != 0.0:
		yaw += turn * float(cfg["key_rotate_speed"]) * delta
		_apply()


func zoom(factor: float) -> void:
	distance *= factor
	_apply()


func _pan(offset: Vector2) -> void:
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	position += right * offset.x + forward * offset.y
	_apply()


func _apply() -> void:
	if cfg.is_empty() or _camera == null:
		return
	distance = clampf(distance, float(cfg["min_distance"]), float(cfg["max_distance"]))
	pitch = clampf(pitch, deg_to_rad(float(cfg["min_pitch_degrees"])), deg_to_rad(float(cfg["max_pitch_degrees"])))
	if world != null:
		if not world.infinite:
			position.x = clampf(position.x, 0.0, world.size.x)
			position.z = clampf(position.z, 0.0, world.size.z)
		position.y = _ground(position) + 1.0
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	var eye: Vector3 = position + offset
	if world != null:
		# 地面の下を見せない: カメラは常に真下の地表より上に置く
		eye.y = maxf(eye.y, _ground(eye) + float(cfg["ground_clearance"]))
	_camera.global_position = eye if is_inside_tree() else offset
	if is_inside_tree():
		_camera.look_at(position)


func _ground(at: Vector3) -> float:
	var cell := Vector2i(floori(at.x), floori(at.z))
	if world.infinite:
		# まだ作っていない所でも、地形の形から高さが分かる
		return (world.top_y(cell) if world.has_column(cell) else int(world.shape.column(cell.x, cell.y)["h"])) + 1.0
	cell = Vector2i(clampi(cell.x, 0, world.size.x - 1), clampi(cell.y, 0, world.size.z - 1))
	return world.top_y(cell) + 1.0
