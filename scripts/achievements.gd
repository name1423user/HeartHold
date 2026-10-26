class_name Achievements
extends VillageSystem
## 実績(M11-T01)。条件を満たすと解除され、警告で知らせる。解除した実績はゲームをまたいで
## user://achievements.cfg に残る。出来事の回数(襲撃を退けた回数など)は村ごとに数える。

const PATH: String = "user://achievements.cfg"

signal unlocked_achievement(entry: Dictionary)

var counters: Dictionary = {}
var unlocked: Array = []
var _timer: float = 0.0
## テストでファイルに書かないようにする口
static var persist: bool = true


func _init(target: Village) -> void:
	super(target)
	village.alert_raised.connect(_on_alert)


func key() -> String:
	return "achievements"


static func list() -> Array:
	return GameData.get_dict("achievements")["achievements"]


## ゲームをまたいで解除済みの実績
static func global_unlocked() -> Array:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return []
	return config.get_value("achievements", "unlocked", [])


func _on_alert(kind: String, _message: String, _cell: Vector2i) -> void:
	counters[kind] = int(counters.get(kind, 0)) + 1
	if kind == "built":
		for b: Building in village.buildings.values():
			if bool(b.def().get("landmark", false)) and b.is_complete():
				counters["landmark"] = 1


func update(dt: float) -> void:
	_timer -= dt
	if _timer > 0.0:
		return
	_timer = 10.0
	for entry: Dictionary in list():
		if unlocked.has(entry["id"]) or not Conditions.check(village, entry["cond"], counters):
			continue
		unlocked.append(entry["id"])
		_save_global(str(entry["id"]))
		village.raise_alert("achievement", Texts.t("alert_achievement", {"name": entry["name"]}), village.world.start)
		unlocked_achievement.emit(entry)


func _save_global(id: String) -> void:
	if not persist:
		return
	var config := ConfigFile.new()
	config.load(PATH)
	var all: Array = config.get_value("achievements", "unlocked", [])
	if not all.has(id):
		all.append(id)
	config.set_value("achievements", "unlocked", all)
	config.save(PATH)


func to_dict() -> Dictionary:
	return {"counters": counters.duplicate(), "unlocked": unlocked.duplicate()}


func from_dict(data: Dictionary) -> void:
	counters = (data.get("counters", {}) as Dictionary).duplicate()
	unlocked = (data.get("unlocked", []) as Array).duplicate()
