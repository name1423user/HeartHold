class_name Schedule
extends VillageSystem
## 日課表(M7-T05)。1日24時間を「働く・休む・寝る」に分け、プレイヤーが変えられる。
## 村全体の表と、村人ごとの上書きを持つ。怠け者は休みの後の1時間も休む。

var table: Array = []
## 村人ID -> 24時間の表
var overrides: Dictionary = {}


func _init(target: Village) -> void:
	super(target)
	plan_stage = "need"
	table = (GameData.get_dict("schedule")["default"] as Array).duplicate()


func key() -> String:
	return "schedule"


func cfg() -> Dictionary:
	return GameData.get_dict("schedule")


func table_for(v: Villager) -> Array:
	return overrides.get(v.id, table)


func activity(v: Villager, hour: int = -1) -> String:
	var h: int = int(village.clock.hour()) if hour < 0 else hour
	var t: Array = table_for(v)
	var kind: String = str(t[h % 24])
	if kind == "work":
		# 怠け者は休みのすぐ後の時間も休む
		var extra: int = 0
		for trait_id: String in v.traits:
			extra += int(Traits.def(trait_id).get("rest_extra_hours", 0))
		for i in range(1, extra + 1):
			if str(t[(h - i + 24) % 24]) == "rest":
				return "rest"
	return kind


## 全体の表の1時間ぶんを変える
func set_slot(hour: int, kind: String) -> void:
	if cfg()["kinds"].has(kind):
		table[hour % 24] = kind


## 次の種類へ回す(画面のボタン用)
func cycle_slot(hour: int) -> void:
	var kinds: Array = cfg()["kinds"].keys()
	set_slot(hour, kinds[(kinds.find(table[hour % 24]) + 1) % kinds.size()])


func set_override(v: Villager, hours: Array) -> void:
	if hours.is_empty():
		overrides.erase(v.id)
	else:
		overrides[v.id] = hours.duplicate()


func choose_plan(v: Villager) -> bool:
	match activity(v):
		"sleep":
			if v.needs.get_value("sleep") >= float(cfg()["sleep_until"]):
				return false
			var home: Building = village.buildings.get(v.home_id) as Building
			var steps: Array[Dictionary] = []
			var at_home: bool = home != null and home.is_complete()
			if at_home:
				steps.append({"op": "goto", "target": home.cell, "adjacent": true, "building": home.id})
			steps.append({"op": "sleep", "building": home.id if at_home else -1})
			village.set_plan(v, "sleep", steps)
			return true
		"rest":
			var needs_system: ExtendedNeeds = village.system("extended_needs") as ExtendedNeeds
			return needs_system.plan_relax(v)
	return false


func to_dict() -> Dictionary:
	var o: Dictionary = {}
	for id: int in overrides:
		o[str(id)] = overrides[id]
	return {"table": table.duplicate(), "overrides": o}


func from_dict(data: Dictionary) -> void:
	table = (data.get("table", table) as Array).duplicate()
	overrides.clear()
	for id: String in data.get("overrides", {}):
		overrides[int(id)] = data["overrides"][id]
