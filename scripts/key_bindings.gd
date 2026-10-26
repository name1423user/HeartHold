class_name KeyBindings
extends RefCounted
## キー割り当ての変更(M11-T03)。変えたキーは user://settings.cfg の [keys] に保存し、起動時に入力マップへかける。

const ACTIONS: Array[String] = ["toggle_pause", "panel_1", "panel_2", "panel_3", "panel_4", "panel_5", "cam_forward", "cam_back", "cam_left", "cam_right", "cam_rotate_left", "cam_rotate_right"]
## 初期の割り当て(project.godot の値)。最初に読んだときに覚える
static var _defaults: Dictionary = {}


static func current_key(action: String) -> Key:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).physical_keycode
	return KEY_NONE


static func key_name(action: String) -> String:
	return OS.get_keycode_string(current_key(action))


static func _remember_defaults() -> void:
	if not _defaults.is_empty():
		return
	for action in ACTIONS:
		if InputMap.has_action(action):
			_defaults[action] = current_key(action)


## キーを付け替える。同じキーを使っていたほかの操作とは入れ替える
static func rebind(action: String, key: Key, save: bool = true) -> void:
	_remember_defaults()
	if not InputMap.has_action(action):
		return
	var old: Key = current_key(action)
	for other in ACTIONS:
		if other != action and InputMap.has_action(other) and current_key(other) == key:
			_set_key(other, old)
	_set_key(action, key)
	if save:
		save_bindings()


static func _set_key(action: String, key: Key) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)


static func reset() -> void:
	_remember_defaults()
	for action: String in _defaults:
		_set_key(action, _defaults[action])
	save_bindings()


static func save_bindings() -> void:
	var config := ConfigFile.new()
	config.load(Settings.PATH)
	for action in ACTIONS:
		if InputMap.has_action(action):
			config.set_value("keys", action, int(current_key(action)))
	config.save(Settings.PATH)


static func load_bindings() -> void:
	_remember_defaults()
	var config := ConfigFile.new()
	if config.load(Settings.PATH) != OK or not config.has_section("keys"):
		return
	for action in ACTIONS:
		if InputMap.has_action(action) and config.has_section_key("keys", action):
			_set_key(action, int(config.get_value("keys", action)) as Key)
