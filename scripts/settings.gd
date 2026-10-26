class_name Settings
extends RefCounted
## 設定(文字サイズ・音量)。user://settings.cfg に保存する。

const PATH: String = "user://settings.cfg"

static var text_scale_index: int = 0
static var volumes: Dictionary = {"Master": 1.0, "BGM": 0.8, "SFX": 0.8}
static var loaded: bool = false


static func load_settings() -> void:
	if loaded:
		return
	loaded = true
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	text_scale_index = int(config.get_value("ui", "text_scale_index", 0))
	for bus: String in volumes:
		volumes[bus] = float(config.get_value("audio", bus, volumes[bus]))


static func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("ui", "text_scale_index", text_scale_index)
	for bus: String in volumes:
		config.set_value("audio", bus, volumes[bus])
	config.save(PATH)


static func text_scale() -> float:
	var scales: Array = GameData.get_dict("ui")["text_scales"]
	return float(scales[clampi(text_scale_index, 0, scales.size() - 1)])
