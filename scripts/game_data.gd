class_name GameData
extends RefCounted
## data/*.json の読み込み口。読み込んだ結果はキャッシュする。

static var _cache: Dictionary = {}


static func load_json(name: String) -> Variant:
	if _cache.has(name):
		return _cache[name]
	var path: String = "res://data/%s.json" % name
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("データを読めません: " + path)
		return null
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("JSONの形式が不正です: " + path)
		return null
	_cache[name] = parsed
	return parsed


static func get_dict(name: String) -> Dictionary:
	var value: Variant = load_json(name)
	return value if value is Dictionary else {}
