class_name AlertLog
extends RefCounted
## 警告マークと警告履歴(AC-023)。村の警告を受け取り、同じ警告の連発はまとめる。
## 画面側は added を受けてマークを出し、クリックで cell へカメラを動かす。

signal added(entry: Dictionary)

var village: Village
var history: Array[Dictionary] = []
var cfg: Dictionary = {}


func _init(target: Village) -> void:
	village = target
	cfg = GameData.get_dict("alerts")
	village.alert_raised.connect(_on_alert)


func _on_alert(kind: String, message: String, cell: Vector2i) -> void:
	var now: float = village.clock.minutes
	for entry in history:
		if now - float(entry["minutes"]) > float(cfg["dedupe_minutes"]):
			break
		if entry["kind"] == kind and entry["message"] == message:
			return
	var entry: Dictionary = {"kind": kind, "message": message, "cell": cell, "minutes": now, "time": village.clock.label(), "icon": icon(kind)}
	history.push_front(entry)
	if history.size() > int(cfg["max_history"]):
		history.pop_back()
	added.emit(entry)


func icon(kind: String) -> String:
	var kinds: Dictionary = cfg["kinds"]
	return str(kinds.get(kind, kinds["default"])["icon"])


func sound(kind: String) -> String:
	var kinds: Dictionary = cfg["kinds"]
	return str(kinds.get(kind, kinds["default"])["sound"])
