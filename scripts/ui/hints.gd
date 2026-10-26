class_name Hints
extends RefCounted
## 最初の家を建てるまでの短いヒント(AC-030)。手順を満たすと次へ進む。文言は data/hints.json。

var village: Village
var step: int = 0


func _init(target: Village) -> void:
	village = target


func steps() -> Array:
	return GameData.get_dict("hints")["steps"]


func is_finished() -> bool:
	return step >= steps().size()


func current_text() -> String:
	return "" if is_finished() else str(steps()[step]["text"])


func update() -> void:
	while not is_finished() and _is_done(str(steps()[step]["id"])):
		step += 1


func _is_done(id: String) -> bool:
	match id:
		"chop":
			return not village.tasks.of_type("chop").is_empty() or village.stock_count("log") > 0 and _has("storage", false)
		"storage":
			return _has("storage", false)
		"workbench":
			return _has("workbench", false)
		"plank":
			return village.stock_count("plank") >= 8 or _has("house", false)
		"house":
			return _has("house", true)
	return true


func _has(type: String, complete: bool) -> bool:
	for b: Building in village.buildings.values():
		if b.type == type and (b.is_complete() or not complete):
			return true
	return false
