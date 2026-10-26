extends GutTest


func after_each() -> void:
	KeyBindings.reset()


func test_rebind_and_swap_and_persist() -> void:
	assert_eq(KeyBindings.current_key("toggle_pause"), KEY_SPACE)
	KeyBindings.rebind("toggle_pause", KEY_P)
	assert_eq(KeyBindings.current_key("toggle_pause"), KEY_P)
	var p := InputEventKey.new()
	p.physical_keycode = KEY_P
	p.pressed = true
	assert_true(p.is_action_pressed("toggle_pause"), "新しいキーで動く")
	KeyBindings.rebind("panel_1", KEY_P)
	assert_eq(KeyBindings.current_key("toggle_pause"), KEY_1, "同じキーの操作とは入れ替える")
	KeyBindings._set_key("panel_1", KEY_9)
	KeyBindings.load_bindings()
	assert_eq(KeyBindings.current_key("panel_1"), KEY_P, "保存したキーが読める")


func test_camera_keys_are_actions() -> void:
	for action in ["cam_forward", "cam_back", "cam_left", "cam_right", "cam_rotate_left", "cam_rotate_right"]:
		assert_true(InputMap.has_action(action))
	assert_eq(KeyBindings.current_key("cam_forward"), KEY_W)
